extends Node

# BOOKWAR multiplayer client. Connects to WebSocket server.
# Server: ANDROID_VERSION/server/server.js (Node + ws)
# Protocol: JSON-per-message

signal connected_to_server(id: String, name: String)
signal disconnected_from_server()
signal player_joined(id: String, name: String, x: float, y: float)
signal player_left(id: String)
signal player_moved(id: String, x: float, y: float)
signal chat_received(id: String, name: String, text: String)
signal letters_received(id: String, letters: Array)
signal trade_requested(from_name: String)
signal trade_accepted(from_name: String)
signal battle_invited(from_name: String)

var _peer: WebSocketPeer = null
# Resolved dynamically (see _resolve_ws_url). Direct IP fallback for native clients.
const DIRECT_FALLBACK_URL: String = "ws://<bookwar-server-ip>:4567"
var _url: String = ""
var _my_id: String = ""
var _my_name: String = "Hero"
var _is_connected: bool = false
var _players: Dictionary = {}

func is_connected_to_server() -> bool:
	if OS.has_feature("web"):
		# Use the JS-side WebSocket state (Godot's own WebSocketPeer is unreliable
		# on HTML5 — see БАГ-008). _mpState is one of: idle|connecting|open|closed.
		var st: String = str(JavaScriptBridge.eval("window._mpState || 'idle'", true))
		return st == "open"
	return _is_connected and _peer != null and _peer.get_ready_state() == WebSocketPeer.STATE_OPEN

func get_my_id() -> String:
	return _my_id

func get_my_name() -> String:
	return _my_name

func set_my_name(p_name: String) -> void:
	_my_name = p_name
	if is_connected_to_server():
		_send({"t": "hello", "name": _my_name})

func get_players() -> Dictionary:
	return _players

# Resolve the WebSocket URL from the page location so the same build works from any host
# (raw IP / Cloudflare tunnel / real domain) without mixed-content issues.
# Web build served over https → wss://<host>/ws (proxied by nginx -> relay server).
# Web build over http → ws://<host>/ws.
# Native (PC/Android APK) → direct IP fallback (no browser mixed-content rules).
func _resolve_ws_url() -> String:
	if OS.has_feature("web"):
		# Allow ?mp=ws://host:port override (for testing / direct connect).
		var override: String = str(JavaScriptBridge.eval("(function(){ try { var m = new RegExp('[?&]mp=([^&]+)').exec(window.location.search); return m ? decodeURIComponent(m[1]) : ''; } catch(e) { return ''; } })()", true))
		if override.length() > 0:
			return override
		var proto: String = String(JavaScriptBridge.eval("window.location.protocol === 'https:' ? 'wss' : 'ws'", true))
		var host: String = String(JavaScriptBridge.eval("window.location.host", true))
		if host.length() > 0:
			return "%s://%s/ws" % [proto, host]
	return DIRECT_FALLBACK_URL

func connect_to_server(url: String = "") -> bool:
	if is_connected_to_server():
		disconnect_from_server()
	if url.is_empty():
		url = _resolve_ws_url()
	_url = url
	if OS.has_feature("web"):
		# Polling-based bridge: set a flag the JS setInterval picks up.
		JavaScriptBridge.eval("window._mpWantConnect = " + JSON.stringify(url), true)
		set_process(true)
		return true
	_peer = WebSocketPeer.new()
	var err: int = _peer.connect_to_url(url)
	if err != OK:
		push_warning("[net] connect_to_url failed: %d" % err)
		return false
	print("[net] connecting to ", url)
	set_process(true)
	return true

func disconnect_from_server() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window._mpWantDisconnect = true;", true)
	else:
		if _peer:
			_peer.close()
			_peer = null
	_is_connected = false
	_players.clear()
	_my_id = ""
	emit_signal("disconnected_from_server()")
	set_process(false)

func send_position(x: float, y: float) -> void:
	_send({"t": "pos", "x": x, "y": y})

func send_chat(text: String) -> void:
	_send({"t": "chat", "text": text})

func send_letters(letters: Array) -> void:
	_send({"t": "letters", "letters": letters})

func send_trade_request(target_name: String) -> void:
	_send({"t": "trade_req", "to": target_name})

func send_trade_accept(from_name: String) -> void:
	_send({"t": "trade_accept", "from": from_name})

func send_battle_invite(target_name: String) -> void:
	_send({"t": "battle_invite", "to": target_name})

func _send(msg: Dictionary) -> void:
	if not is_connected_to_server():
		return
	var text: String = JSON.stringify(msg)
	if OS.has_feature("web"):
		# Push into outgoing queue — JS setInterval drains it every 50ms.
		# Single eval, single push (no function call overhead — bypasses Godot
		# HTML5 WebSocketPeer outgoing-drop bug, БАГ-008).
		JavaScriptBridge.eval("window._mpOut.push(" + JSON.stringify(text) + ")", true)
		return
	_peer.send_text(text)

func _process(_delta: float) -> void:
	if OS.has_feature("web"):
		_process_web()
		return
	if _peer == null:
		return
	_peer.poll()
	var state: int = _peer.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		while _peer.get_available_packet_count() > 0:
			var pkt: PackedByteArray = _peer.get_packet()
			var text: String = pkt.get_string_from_utf8()
			_handle_message(text)
		if not _is_connected:
			_is_connected = true
			print("[net] connected")
			_send({"t": "hello", "name": _my_name})
	elif state == WebSocketPeer.STATE_CLOSED:
		var code: int = _peer.get_close_code()
		var reason: String = _peer.get_close_reason()
		print("[net] closed code=", code, " reason=", reason)
		_is_connected = false
		_peer = null
		emit_signal("disconnected_from_server()")
		set_process(false)

# Web-only processing: drain the JS-side _mpIn, detect open/close transitions.
func _process_web() -> void:
	var st: String = str(JavaScriptBridge.eval("window._mpState || 'idle'", true))
	if st == "open":
		if not _is_connected:
			_is_connected = true
			print("[net] connected (JS bridge)")
			_send({"t": "hello", "name": _my_name})
		# Drain received messages.
		var q: Variant = JavaScriptBridge.eval("JSON.stringify(window._mpIn || [])", true)
		JavaScriptBridge.eval("window._mpIn = [];")
		if q != null:
			var qs: String = str(q)
			if qs != "" and qs != "null" and qs != "[]":
				var json: JSON = JSON.new()
				if json.parse(qs) == OK:
					var arr: Array = json.get_data()
					for msg_text: Variant in arr:
						_handle_message(String(msg_text))
	elif st == "closed":
		if _is_connected:
			_is_connected = false
			print("[net] closed (JS bridge)")
			emit_signal("disconnected_from_server()")
	elif st == "idle":
		if _is_connected:
			_is_connected = false
			emit_signal("disconnected_from_server())")

func _handle_message(text: String) -> void:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var msg: Dictionary = parsed
	var t: String = msg.get("t", "")
	match t:
		"welcome":
			_my_id = String(msg.get("id", ""))
			_my_name = String(msg.get("name", _my_name))
			emit_signal("connected_to_server", _my_id, _my_name)
		"player_join":
			var pid: String = String(msg.get("id", ""))
			_players[pid] = {
				"name": String(msg.get("name", "")),
				"x": float(msg.get("x", 0)),
				"y": float(msg.get("y", 0))
			}
			emit_signal("player_joined", pid, _players[pid].name, _players[pid].x, _players[pid].y)
		"player_leave":
			var pid2: String = String(msg.get("id", ""))
			_players.erase(pid2)
			emit_signal("player_left", pid2)
		"player_name":
			var pid3: String = String(msg.get("id", ""))
			if _players.has(pid3):
				_players[pid3].name = String(msg.get("name", ""))
		"pos":
			var pid4: String = String(msg.get("id", ""))
			if _players.has(pid4):
				_players[pid4].x = float(msg.get("x", 0))
				_players[pid4].y = float(msg.get("y", 0))
				emit_signal("player_moved", pid4, _players[pid4].x, _players[pid4].y)
		"chat":
			emit_signal("chat_received", String(msg.get("id", "")), String(msg.get("name", "")), String(msg.get("text", "")))
		"letters":
			emit_signal("letters_received", String(msg.get("id", "")), msg.get("letters", []))
		"trade_req":
			emit_signal("trade_requested", String(msg.get("from", "")))
		"trade_accept":
			emit_signal("trade_accepted", String(msg.get("from", "")))
		"battle_invite":
			emit_signal("battle_invited", String(msg.get("from", "")))
