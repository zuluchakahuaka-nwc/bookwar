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
		# Install the JS bridge. Actual getUserMedia / RTCPeerConnection calls
		# happen in JS land; GDScript only flips state + emits signals.
		JavaScriptBridge.eval("""
			(function(){
				window.gameVoice = {
					micPermission: 'unknown',
					pttActive: false,
					enabled: false,
					peers: {},  // peerId -> {speaking: bool, muted: bool, stream: MediaStream|null}
					localStream: null,
					error: null
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
							window.gameVoice.micPermission = (err.name === 'NotAllowedError') ? 'denied' : 'denied';
							return false;
						});
				};
				// Stop microphone (release the stream).
				window.gameVoiceStopMic = function() {
					if (window.gameVoice.localStream) {
						window.gameVoice.localStream.getTracks().forEach(function(t){ t.stop(); });
						window.gameVoice.localStream = null;
					}
					window.gameVoice.enabled = false;
					window.gameVoice.pttActive = false;
				};
				// Push-to-talk toggle. When active, mic stream is "live" (muted = false).
				window.gameVoiceSetPTT = function(active) {
					window.gameVoice.pttActive = !!active;
					if (window.gameVoice.localStream) {
						window.gameVoice.localStream.getAudioTracks().forEach(function(t){
							t.enabled = !!active;
						});
					}
				};
				// Mute a specific peer (so we don't hear them).
				window.gameVoiceMutePeer = function(peerId, muted) {
					if (!window.gameVoice.peers[peerId]) return;
					window.gameVoice.peers[peerId].muted = !!muted;
				};
				window.gameVoiceIsSupported = function() {
					return !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia && window.RTCPeerConnection);
				};
			})();
		""", true)
		# Detect support synchronously
		var supported: Variant = JavaScriptBridge.eval("window.gameVoiceIsSupported ? window.gameVoiceIsSupported() : false", true)
		if supported == false:
			_mic_permission = PERM_DENIED
	set_process(true)

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
