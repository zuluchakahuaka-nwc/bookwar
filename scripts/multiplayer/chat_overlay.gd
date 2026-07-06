extends CanvasLayer
class_name ChatOverlay

# In-game chat overlay. Toggle with Enter key or Chat button.
# Auto-hides after few seconds of inactivity.

@onready var _panel: Panel = $Panel
@onready var _messages_label: RichTextLabel = $Panel/MessagesLabel
@onready var _input_edit: LineEdit = $Panel/InputEdit
@onready var _send_btn: Button = $Panel/SendBtn
@onready var _toggle_btn: Button = $ToggleBtn

var _visible_for: float = 0.0
var _auto_hide_after: float = 6.0
var _is_input_focused: bool = false

func _ready() -> void:
	layer = 50
	_panel.visible = false
	_toggle_btn.text = "💬"
	_send_btn.text = "→"
	_messages_label.bbcode_enabled = true
	_messages_label.text = ""
	if _send_btn:
		_send_btn.pressed.connect(_on_send)
	if _input_edit:
		_input_edit.text_submitted.connect(func(_t): _on_send())
	NetworkManager.chat_received.connect(_on_chat_received)
	NetworkManager.connected_to_server.connect(_on_connected)
	set_process(true)

func _on_connected(id: String, pname: String) -> void:
	_add_system_line("Подключено как [color=green]%s[/color]" % pname)

func _on_chat_received(id: String, pname: String, text: String) -> void:
	_add_chat_line(pname, text)
	_show_panel()

func _on_send() -> void:
	var t: String = _input_edit.text.strip_edges()
	if t.is_empty():
		return
	NetworkManager.send_chat(t)
	_add_chat_line(NetworkManager.get_my_name(), t)
	_input_edit.text = ""
	_input_edit.grab_focus()
	_is_input_focused = true

func _add_chat_line(pname: String, text: String) -> void:
	var colored := "[color=aqua]%s[/color]: %s" % [pname.replace("[", "").replace("]", ""), text.replace("[", "").replace("]", "")]
	var prev: String = _messages_label.text
	if prev.length() > 1500:
		prev = prev.substr(prev.length() - 1000)
	_messages_label.text = (prev + "\n" + colored) if not prev.is_empty() else colored

func _add_system_line(text: String) -> void:
	var prev: String = _messages_label.text
	_messages_label.text = (prev + "\n[color=gray]" + text + "[/color]") if not prev.is_empty() else ("[color=gray]" + text + "[/color]")

func _toggle_panel() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		_show_panel()
		_input_edit.grab_focus()
		_is_input_focused = true

func _show_panel() -> void:
	_panel.visible = true
	_visible_for = 0.0

func _process(delta: float) -> void:
	if _panel.visible and not _is_input_focused:
		_visible_for += delta
		if _visible_for > _auto_hide_after:
			_panel.visible = false
			_visible_for = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		_toggle_panel()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and _panel.visible:
		_panel.visible = false
		get_viewport().set_input_as_handled()

# Tap handler for the floating toggle button (Android-friendly).
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		if _toggle_btn != null and _toggle_btn.get_global_rect().has_point(event.position):
			_toggle_panel()
			get_viewport().set_input_as_handled()
			return
		if _panel.visible and _send_btn != null and _send_btn.get_global_rect().has_point(event.position):
			_on_send()
			get_viewport().set_input_as_handled()
			return
