extends Control
class_name MultiplayerUI

const MENU_PATH: String = "res://scenes/ui/main_menu.tscn"
const WORLD_PATH: String = "res://scenes/world/world_map.tscn"

@onready var _name_edit: LineEdit = $CenterCol/NameEdit
@onready var _connect_btn: Button = $CenterCol/ConnectBtn
@onready var _status_label: Label = $CenterCol/StatusLabel
@onready var _players_list: Label = $CenterCol/PlayersList
@onready var _chat_log: Label = $CenterCol/ChatScroll/ChatLog
@onready var _chat_input: LineEdit = $CenterCol/ChatInput
@onready var _send_btn: Button = $CenterCol/SendBtn
@onready var _enter_world_btn: Button = $CenterCol/EnterWorldBtn
@onready var _back_btn: Button = $CenterCol/BackButton
@onready var _player_select: OptionButton = $CenterCol/PlayerSelect
@onready var _trade_btn: Button = $CenterCol/TradeBtn
@onready var _battle_btn: Button = $CenterCol/BattleBtn

var _last_input_time: float = 0.0
var _pending_trade_from: String = ""
var _pending_battle_from: String = ""

func _ready() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameMenuVisible = false; window.gameMPVisible = true;")
		JavaScriptBridge.eval("window.gameMPSendChat = function(text) { if(!window._godotMPChatQueue) window._godotMPChatQueue=[]; window._godotMPChatQueue.push(text); return true; };")
		set_process(true)
	# Hook NetworkManager signals
	if NetworkManager.connected_to_server.is_connected(_on_connected):
		pass
	else:
		NetworkManager.connected_to_server.connect(_on_connected)
	NetworkManager.disconnected_from_server.connect(_on_disconnected)
	NetworkManager.player_joined.connect(_on_player_joined)
	NetworkManager.player_left.connect(_on_player_left)
	NetworkManager.chat_received.connect(_on_chat_received)
	# Trade + battle invite signals
	NetworkManager.trade_requested.connect(_on_trade_requested)
	NetworkManager.trade_accepted.connect(_on_trade_accepted)
	NetworkManager.battle_invited.connect(_on_battle_invited)
	# Default name from previously chosen hero if any
	var default_name: String = "Герой"
	if GameState.selected_hero.has("name"):
		default_name = String(GameState.selected_hero["name"])
	_name_edit.text = default_name
	_set_status("Не подключено")
	_refresh_players_list()
	if OS.has_feature("web"):
		# Expose tap-target rects for tests + show actual gameViewportSize
		call_deferred("_export_buttons")

func _export_buttons() -> void:
	await get_tree().process_frame
	if not OS.has_feature("web"):
		return
	var parts: Array = []
	for btn in [_connect_btn, _send_btn, _enter_world_btn, _back_btn, _trade_btn, _battle_btn]:
		if btn:
			var r: Rect2 = btn.get_global_rect()
			parts.append("{\"name\":\"%s\",\"x\":%.1f,\"y\":%.1f,\"w\":%.1f,\"h\":%.1f}" % [btn.name, r.position.x, r.position.y, r.size.x, r.size.y])
	var vs: Vector2 = get_viewport().get_visible_rect().size
	JavaScriptBridge.eval("window.gameMPButtons = [" + ",".join(parts) + "]; window.gameViewportSize = {w:" + str(int(vs.x)) + ",h:" + str(int(vs.y)) + "};")

func _input(event: InputEvent) -> void:
	# Accept pending trade/battle via keyboard (T / B)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_T and _pending_trade_from != "":
			_accept_trade()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_B and _pending_battle_from != "":
			var from: String = _pending_battle_from
			_pending_battle_from = ""
			_append_chat("", "⚔️ Бой с " + from + " принят! (заглушка — PvP арена в разработке)")
			get_viewport().set_input_as_handled()
			return
	# Universal tap handler (no pressed.connect — see main_menu.gd pattern).
	var pos := Vector2(-1, -1)
	var is_press := false
	if event is InputEventScreenTouch:
		pos = event.position
		is_press = event.pressed
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		is_press = true
	if not is_press or pos.x < 0:
		return
	# Don't intercept taps on LineEdit (typing).
	if _name_edit and _name_edit.get_global_rect().has_point(pos):
		return
	if _chat_input and _chat_input.get_global_rect().has_point(pos):
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_input_time < 0.2:
		return
	if _connect_btn and _connect_btn.get_global_rect().has_point(pos):
		_last_input_time = now
		_on_connect()
		get_viewport().set_input_as_handled()
		return
	if _send_btn and _send_btn.get_global_rect().has_point(pos):
		_last_input_time = now
		_on_send()
		get_viewport().set_input_as_handled()
		return
	if _enter_world_btn and _enter_world_btn.get_global_rect().has_point(pos):
		_last_input_time = now
		_on_enter_world()
		get_viewport().set_input_as_handled()
		return
	if _trade_btn and _trade_btn.get_global_rect().has_point(pos):
		_last_input_time = now
		_send_trade_request()
		get_viewport().set_input_as_handled()
		return
	if _battle_btn and _battle_btn.get_global_rect().has_point(pos):
		_last_input_time = now
		_send_battle_invite()
		get_viewport().set_input_as_handled()
		return
	if _back_btn and _back_btn.get_global_rect().has_point(pos):
		_last_input_time = now
		_on_back()
		get_viewport().set_input_as_handled()
		return

func _on_connect() -> void:
	var player_name: String = _name_edit.text.strip_edges()
	if player_name == "":
		player_name = "Герой"
	NetworkManager.set_my_name(player_name)
	var ok: bool = NetworkManager.connect_to_server()
	if ok:
		_set_status("Подключение...")
	else:
		_set_status("Не удалось подключиться (сеть)")

func _on_connected(id: String, name: String) -> void:
	_set_status("Подключён как: " + name + " (id " + id + ")")
	_refresh_players_list()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameMPConnected = true;")

func _on_disconnected() -> void:
	_set_status("Отключено от сервера")
	_refresh_players_list()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameMPConnected = false;")

func _on_player_joined(_pid: String, pname: String, _x: float, _y: float) -> void:
	_refresh_players_list()
	_append_chat("", "→ " + pname + " присоединился")

func _on_player_left(pid: String) -> void:
	var pname: String = pid
	if NetworkManager.get_players().has(pid):
		pname = String(NetworkManager.get_players()[pid].get("name", pid))
	_refresh_players_list()
	_append_chat("", "← " + pname + " покинул игру")

func _on_chat_received(_id: String, pname: String, text: String) -> void:
	_append_chat(pname, text)

func _on_send() -> void:
	var text: String = _chat_input.text.strip_edges()
	if text == "":
		return
	NetworkManager.send_chat(text)
	_chat_input.text = ""
	_append_chat(NetworkManager.get_my_name(), text)

func _on_send_chat_only(text: String) -> void:
	# Called from JS bridge (no LineEdit input reading).
	text = text.strip_edges()
	if text == "":
		return
	NetworkManager.send_chat(text)
	_append_chat(NetworkManager.get_my_name(), text)

func _on_enter_world() -> void:
	# Enter the world carrying the chosen hero — same path as main_menu._on_new_game
	# but skip the legend (the player came in via MP entry).
	GameState.intro_return_to = "world"
	get_tree().change_scene_to_file(WORLD_PATH)

func _on_back() -> void:
	if NetworkManager.is_connected_to_server():
		NetworkManager.disconnect_from_server()
	get_tree().change_scene_to_file(MENU_PATH)

func _set_status(text: String) -> void:
	if _status_label:
		_status_label.text = text

func _refresh_players_list() -> void:
	if not _players_list:
		return
	var players: Dictionary = NetworkManager.get_players()
	var lines: Array = []
	lines.append("Игроки онлайн: " + str(players.size() + (1 if NetworkManager.is_connected_to_server() else 0)))
	if NetworkManager.is_connected_to_server():
		lines.append("• " + NetworkManager.get_my_name() + " (вы)")
	for pid: String in players:
		lines.append("• " + String(players[pid].get("name", pid)))
	_players_list.text = "\n".join(lines)
	# Populate the player dropdown for trade/battle target selection
	if _player_select:
		_player_select.clear()
		for pid: String in players:
			_player_select.add_item(String(players[pid].get("name", pid)))
		_player_select.disabled = players.size() == 0
	if _trade_btn:
		_trade_btn.disabled = players.size() == 0
	if _battle_btn:
		_battle_btn.disabled = players.size() == 0
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameMPPlayersCount = " + str(players.size()) + ";")

# --- Trade + Battle invite handlers ---

func _on_trade_requested(from_name: String) -> void:
	_pending_trade_from = from_name
	_append_chat("", "🤝 " + from_name + " хочет обменяться буквами! [T] — принять")
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameTradeReq = '" + from_name + "';")

func _on_trade_accepted(from_name: String) -> void:
	_append_chat("", "✅ " + from_name + " принял обмен! Открываю окно торговли...")
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameTradeStarted = '" + from_name + "';")
	_open_trade_window(from_name)

func _on_battle_invited(from_name: String) -> void:
	_pending_battle_from = from_name
	_append_chat("", "⚔️ " + from_name + " вызывает на бой! [B] — принять")
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameBattleReq = '" + from_name + "';")

func _send_trade_request() -> void:
	var target: String = _get_selected_player_name()
	if target == "":
		return
	NetworkManager.send_trade_request(target)
	_append_chat("", "→ Предложение обмена отправлено: " + target)

func _send_battle_invite() -> void:
	var target: String = _get_selected_player_name()
	if target == "":
		return
	NetworkManager.send_battle_invite(target)
	_append_chat("", "→ Вызов на бой отправлен: " + target)

func _get_selected_player_name() -> String:
	if not _player_select or _player_select.get_item_count() == 0:
		return ""
	var idx: int = _player_select.selected
	if idx < 0:
		idx = 0
	return _player_select.get_item_text(idx)

func _accept_trade() -> void:
	if _pending_trade_from == "":
		return
	NetworkManager.send_trade_accept(_pending_trade_from)
	_open_trade_window(_pending_trade_from)
	_pending_trade_from = ""

func _open_trade_window(partner_name: String) -> void:
	# MVP: show inventory snapshot in chat so both players can see what to offer.
	var my_letters: Dictionary = InventoryManager.get_all_letters()
	var my_list: Array = []
	for letter_char: String in my_letters:
		my_list.append(letter_char + "(" + str(my_letters[letter_char]) + ")")
	_append_chat("", "📦 Ваши буквы: " + ", ".join(my_list))
	_append_chat("", "📦 Партнёр: " + partner_name + " — напишите в чат какие буквы хотите отдать/получить.")

func _process(_delta: float) -> void:
	if not OS.has_feature("web"):
		return
	# Drain chat send queue from JS bridge
	var q: Variant = JavaScriptBridge.eval("JSON.stringify(window._godotMPChatQueue || [])")
	JavaScriptBridge.eval("window._godotMPChatQueue = [];")
	if q != null:
		var qs: String = str(q)
		if qs != "" and qs != "null" and qs != "[]":
			var json: JSON = JSON.new()
			if json.parse(qs) == OK:
				for text: Variant in (json.get_data() as Array):
					_on_send_chat_only(String(text))

func _append_chat(pname: String, text: String) -> void:
	if not _chat_log:
		return
	var line: String = text if pname == "" else pname + ": " + text
	_chat_log.text += line + "\n"
	# Cap log size
	if _chat_log.text.length() > 1200:
		_chat_log.text = _chat_log.text.substr(_chat_log.text.length() - 1200)
	_chat_log.get_parent().call_deferred("set_v_scroll", 1.0)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameLastChat = " + JSON.stringify(line) + "; window.gameChatCount = (window.gameChatCount||0)+1;")
