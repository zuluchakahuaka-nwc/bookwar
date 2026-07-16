extends Node
# §7.2 §TODO#8 Voice chat (WebRTC) — client-side skeleton.
#
# Full voice chat requires: getUserMedia + RTCPeerConnection in JS bridge +
# signalling exchange (offer/answer/ICE) between peers via the multiplayer
# WebSocket server. This file implements the GDScript-facing skeleton:
#   - microphone permission state
#   - push-to-talk toggle (PTT)
#   - voice activity indicator
#   - per-peer mute/unmute
#   - JS bridge for the actual WebRTC work (window.gameVoice*)
#
# The WebRTC peer-connection setup is intentionally NOT implemented here —
# it requires extending the multiplayer WS server protocol with offer/answer/
# ice-candidate messages and a TURN server for NAT traversal. That is a
# separate 2-4 day project tracked in TODO.md.
#
# USAGE (any scene):
#   VoiceChat.start_microphone()        # request mic permission
#   VoiceChat.set_ptt_active(true)      # hold-to-talk or toggle
#   VoiceChat.connect("ptt_changed", ...)
#   VoiceChat.connect("mic_permission_changed", ...)

signal mic_permission_changed(granted: bool)
signal ptt_changed(active: bool)
signal peer_voice_state(peer_id: String, speaking: bool)

# Permission states
const PERM_UNKNOWN: String = "unknown"
const PERM_GRANTED: String = "granted"
const PERM_DENIED: String = "denied"
const PERM_PROMPT: String = "prompt"

var _mic_permission: String = PERM_UNKNOWN
var _ptt_active: bool = false
var _enabled: bool = false  # master switch — false until user opts in
var _muted_peers: Dictionary = {}  # peer_id -> true
# Tracks peers currently speaking (key = peer_id, value = bool). Updated from
# JS bridge via _process polling window.gameVoicePeers.
var _speaking_peers: Dictionary = {}

func _ready() -> void:
	if OS.has_feature("web"):
		# Install the JS bridge. The bridge now contains the full WebRTC
		# peer-connection setup so two clients can exchange audio.
		JavaScriptBridge.eval("""
			(function(){
				window.gameVoice = {
					micPermission: 'unknown',
					pttActive: false,
					enabled: false,
					peers: {},  // playerName -> {pc: RTCPeerConnection, remoteStream: MediaStream|null, speaking: bool, muted: bool}
					localStream: null,
					error: null,
					peerCount: 0,
					iceServers: [
						{ urls: 'stun:stun.l.google.com:19302' },
						{ urls: 'stun:stun1.l.google.com:19302' }
						// NOTE: TURN server not configured by default. For NAT'd peers
						// behind symmetric routers, add a TURN URL here in production.
					]
				};
				// Request microphone access via getUserMedia.
				window.gameVoiceRequestMic = function() {
					if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
						window.gameVoice.error = 'no_getUserMedia';
						window.gameVoice.micPermission = 'denied';
						return Promise.resolve(false);
					}
					return navigator.mediaDevices.getUserMedia({audio: true, video: false})
						.then(function(stream) {
							window.gameVoice.localStream = stream;
							window.gameVoice.micPermission = 'granted';
							window.gameVoice.enabled = true;
							return true;
						})
						.catch(function(err) {
							window.gameVoice.error = String(err.name || err.message || err);
							window.gameVoice.micPermission = 'denied';
							return false;
						});
				};
				window.gameVoiceStopMic = function() {
					if (window.gameVoice.localStream) {
						window.gameVoice.localStream.getTracks().forEach(function(t){ t.stop(); });
						window.gameVoice.localStream = null;
					}
					// Close all peer connections
					Object.values(window.gameVoice.peers).forEach(function(p) {
						try { if (p.pc) p.pc.close(); } catch(e){}
					});
					window.gameVoice.peers = {};
					window.gameVoice.peerCount = 0;
					window.gameVoice.enabled = false;
					window.gameVoice.pttActive = false;
				};
				window.gameVoiceSetPTT = function(active) {
					window.gameVoice.pttActive = !!active;
					if (window.gameVoice.localStream) {
						window.gameVoice.localStream.getAudioTracks().forEach(function(t){
							t.enabled = !!active;
						});
					}
				};
				window.gameVoiceMutePeer = function(peerName, muted) {
					var p = window.gameVoice.peers[peerName];
					if (!p || !p.remoteStream) return;
					p.muted = !!muted;
					p.remoteStream.getAudioTracks().forEach(function(t){ t.enabled = !muted; });
				};
				window.gameVoiceIsSupported = function() {
					return !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia && window.RTCPeerConnection);
				};
				// §7.2 full p2p audio — initiate a voice call to target peer.
				// Caller side: create PC, add local tracks, create offer, send via WS.
				window.gameVoiceCallPeer = function(peerName) {
					if (!window.gameVoice.localStream) return Promise.reject('no_mic');
					if (window.gameVoice.peers[peerName]) return Promise.resolve('existing');
					var pc = new RTCPeerConnection({ iceServers: window.gameVoice.iceServers });
					var entry = { pc: pc, remoteStream: null, speaking: false, muted: false };
					window.gameVoice.peers[peerName] = entry;
					// Add local audio tracks
					window.gameVoice.localStream.getAudioTracks().forEach(function(t){
						pc.addTrack(t, window.gameVoice.localStream);
					});
					// Receive remote audio
					pc.ontrack = function(ev) {
						entry.remoteStream = ev.streams[0];
						// Play the remote audio through an <audio> element
						var audioEl = document.getElementById('voice_remote_' + peerName);
						if (!audioEl) {
							audioEl = document.createElement('audio');
							audioEl.id = 'voice_remote_' + peerName;
							audioEl.autoplay = true;
							document.body.appendChild(audioEl);
						}
						audioEl.srcObject = entry.remoteStream;
					};
					// ICE candidates -> relay via WS to peer
					pc.onicecandidate = function(ev) {
						if (ev.candidate) {
							window._mpOut.push(JSON.stringify({ t: 'voice_ice', to: peerName, data: ev.candidate.toJSON() }));
						}
					};
					pc.onconnectionstatechange = function() {
						if (pc.connectionState === 'disconnected' || pc.connectionState === 'failed' || pc.connectionState === 'closed') {
							delete window.gameVoice.peers[peerName];
							window.gameVoice.peerCount = Object.keys(window.gameVoice.peers).length;
						}
					};
					// Create offer and send
					return pc.createOffer({ offerToReceiveAudio: true })
						.then(function(offer) { return pc.setLocalDescription(offer); })
						.then(function() {
							window._mpOut.push(JSON.stringify({ t: 'voice_offer', to: peerName, data: pc.localDescription }));
						});
				};
				// §7.2 callee side — handle incoming offer, create answer.
				window.gameVoiceHandleOffer = function(peerName, sdp) {
					if (!window.gameVoice.localStream) return Promise.reject('no_mic');
					var existing = window.gameVoice.peers[peerName];
					if (existing) { try { existing.pc.close(); } catch(e){} }
					var pc = new RTCPeerConnection({ iceServers: window.gameVoice.iceServers });
					var entry = { pc: pc, remoteStream: null, speaking: false, muted: false };
					window.gameVoice.peers[peerName] = entry;
					window.gameVoice.localStream.getAudioTracks().forEach(function(t){
						pc.addTrack(t, window.gameVoice.localStream);
					});
					pc.ontrack = function(ev) {
						entry.remoteStream = ev.streams[0];
						var audioEl = document.getElementById('voice_remote_' + peerName);
						if (!audioEl) {
							audioEl = document.createElement('audio');
							audioEl.id = 'voice_remote_' + peerName;
							audioEl.autoplay = true;
							document.body.appendChild(audioEl);
						}
						audioEl.srcObject = entry.remoteStream;
					};
					pc.onicecandidate = function(ev) {
						if (ev.candidate) {
							window._mpOut.push(JSON.stringify({ t: 'voice_ice', to: peerName, data: ev.candidate.toJSON() }));
						}
					};
					return pc.setRemoteDescription(new RTCSessionDescription(sdp))
						.then(function() { return pc.createAnswer(); })
						.then(function(answer) { return pc.setLocalDescription(answer); })
						.then(function() {
							window._mpOut.push(JSON.stringify({ t: 'voice_answer', to: peerName, data: pc.localDescription }));
						});
				};
				// §7.2 caller side — handle incoming answer.
				window.gameVoiceHandleAnswer = function(peerName, sdp) {
					var entry = window.gameVoice.peers[peerName];
					if (!entry || !entry.pc) return;
					entry.pc.setRemoteDescription(new RTCSessionDescription(sdp))
						.catch(function(e){ window.gameVoice.error = 'answer_failed: ' + e.message; });
				};
				// §7.2 both sides — handle incoming ICE candidate.
				window.gameVoiceHandleIce = function(peerName, candidate) {
					var entry = window.gameVoice.peers[peerName];
					if (!entry || !entry.pc) return;
					try {
						entry.pc.addIceCandidate(new RTCIceCandidate(candidate));
					} catch(e) {
						window.gameVoice.error = 'ice_failed: ' + e.message;
					}
				};
				window.gameVoiceHangup = function(peerName) {
					var entry = window.gameVoice.peers[peerName];
					if (!entry) return;
					try { entry.pc.close(); } catch(e){}
					delete window.gameVoice.peers[peerName];
					window.gameVoice.peerCount = Object.keys(window.gameVoice.peers).length;
					window._mpOut.push(JSON.stringify({ t: 'voice_bye', to: peerName }));
				};
			})();
		""", true)
		var supported: Variant = JavaScriptBridge.eval("window.gameVoiceIsSupported ? window.gameVoiceIsSupported() : false", true)
		if supported == false:
			_mic_permission = PERM_DENIED
		# Connect to NetworkManager signalling signals (server-relayed).
		NetworkManager.voice_offer_received.connect(_on_voice_offer)
		NetworkManager.voice_answer_received.connect(_on_voice_answer)
		NetworkManager.voice_ice_received.connect(_on_voice_ice)
		NetworkManager.voice_bye_received.connect(_on_voice_bye)
	set_process(true)

# §7.2 signalling handlers — bridge server-relayed WS messages into JS.
func _on_voice_offer(from_name: String, data: Variant) -> void:
	if not OS.has_feature("web") or data == null:
		return
	var json_text: String = JSON.stringify({"from": from_name, "sdp": data})
	JavaScriptBridge.eval("window.gameVoiceHandleOffer(" + JSON.stringify(from_name) + ", " + JSON.stringify(data) + ").catch(function(e){ window.gameVoice.error = 'offer_failed: ' + e.message; });", true)

func _on_voice_answer(from_name: String, data: Variant) -> void:
	if not OS.has_feature("web") or data == null:
		return
	JavaScriptBridge.eval("window.gameVoiceHandleAnswer(" + JSON.stringify(from_name) + ", " + JSON.stringify(data) + ");", true)

func _on_voice_ice(from_name: String, data: Variant) -> void:
	if not OS.has_feature("web") or data == null:
		return
	JavaScriptBridge.eval("window.gameVoiceHandleIce(" + JSON.stringify(from_name) + ", " + JSON.stringify(data) + ");", true)

func _on_voice_bye(from_name: String) -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("window.gameVoiceHangup(" + JSON.stringify(from_name) + ");", true)

func _process(_delta: float) -> void:
	if not OS.has_feature("web"):
		return
	# Poll JS bridge for permission/ptt/peer state changes
	var new_perm: String = String(JavaScriptBridge.eval("window.gameVoice ? window.gameVoice.micPermission : 'unknown'", true))
	if new_perm != _mic_permission:
		_mic_permission = new_perm
		mic_permission_changed.emit(_mic_permission == PERM_GRANTED)
	# Sync PTT from JS (user might have pressed a JS-side button)
	var js_ptt: bool = bool(JavaScriptBridge.eval("window.gameVoice && window.gameVoice.pttActive", true))
	if js_ptt != _ptt_active:
		_ptt_active = js_ptt
		ptt_changed.emit(_ptt_active)
	# Sync peers
	# (peer voice state requires actual RTCPeerConnection setup — stubbed for now)
	# Expose current state back for tests / Vision MCP screenshots
	JavaScriptBridge.eval("""
		if (window.gameVoice) {
			window.gameVoicePTT = window.gameVoice.pttActive;
			window.gameVoiceMicPerm = window.gameVoice.micPermission;
			window.gameVoiceEnabled = window.gameVoice.enabled;
			window.gameVoicePeerCount = Object.keys(window.gameVoice.peers || {}).length;
		}
	""", true)

# --- Public API ---

func is_supported() -> bool:
	if not OS.has_feature("web"):
		return false
	return _mic_permission != PERM_DENIED or _mic_permission == PERM_UNKNOWN

func get_mic_permission() -> String:
	return _mic_permission

func start_microphone() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("if (window.gameVoiceRequestMic) window.gameVoiceRequestMic();", true)

func stop_microphone() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("if (window.gameVoiceStopMic) window.gameVoiceStopMic();", true)

func set_ptt_active(active: bool) -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("if (window.gameVoiceSetPTT) window.gameVoiceSetPTT(" + ("true" if active else "false") + ");", true)

func is_ptt_active() -> bool:
	return _ptt_active

func is_enabled() -> bool:
	return _enabled

func mute_peer(peer_id: String, muted: bool) -> void:
	_muted_peers[peer_id] = muted
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if (window.gameVoiceMutePeer) window.gameVoiceMutePeer('" + peer_id + "', " + ("true" if muted else "false") + ");", true)

func is_peer_muted(peer_id: String) -> bool:
	return bool(_muted_peers.get(peer_id, false))

# §7.2 full p2p: initiate a voice call to a specific peer (by player name).
# Triggers RTCPeerConnection setup + offer dispatch via NetworkManager signalling.
func call_peer(peer_name: String) -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("window.gameVoiceCallPeer(" + JSON.stringify(peer_name) + ").catch(function(e){ window.gameVoice.error = 'call_failed: ' + e.message; });", true)

# §7.2 full p2p: hang up a specific peer.
func hangup_peer(peer_name: String) -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("window.gameVoiceHangup(" + JSON.stringify(peer_name) + ");", true)

# §7.2 full p2p: get active peer count (for UI display).
func get_peer_count() -> int:
	if not OS.has_feature("web"):
		return 0
	var c: Variant = JavaScriptBridge.eval("window.gameVoice ? Object.keys(window.gameVoice.peers || {}).length : 0", true)
	if c == null:
		return 0
	return int(c)
