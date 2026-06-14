extends CanvasLayer
class_name HUDUI

const DPAD_BTN_SIZE: float = 56.0

@onready var _hp_label: Label = $HPLabel
@onready var _dots_label: Label = $DotsLabel
@onready var _region_label: Label = $RegionLabel
@onready var _ellipsis_label: Label = $EllipsisLabel
@onready var _interaction_label: Label = $InteractionLabel
@onready var _dialogue_box: Panel = $DialogueBox
@onready var _dialogue_label: Label = $DialogueBox/DialogueLabel

func _ready() -> void:
	GameState.hp_changed.connect(_on_hp_changed)
	InventoryManager.dots_changed.connect(_on_dots_changed)
	InventoryManager.ellipsis_created.connect(_on_ellipsis_created)
	GameState.dialogue_started.connect(_on_dialogue_started)
	GameState.dialogue_ended.connect(_on_dialogue_ended)
	GameState.dialogue_text_set.connect(_on_dialogue_text_set)
	_on_hp_changed(GameState.player_hp, GameState.player_max_hp)
	_on_dots_changed(InventoryManager.get_dots())
	_interaction_label.visible = false
	if _dialogue_box:
		_dialogue_box.visible = false
	_build_touch_controls()
	_focus_canvas()

# --- On-screen controls so the game is playable by mouse/touch without keyboard focus ---
func _build_touch_controls() -> void:
	var vw: float = 1280.0
	var vh: float = 720.0
	# D-pad (bottom-left): up/down/left/right held buttons
	_make_dpad(vw * 0.06, vh * 0.72)
	# Action buttons (bottom-right): take(E), inventory(I), dialogue(T)
	_make_action_btn(vw * 0.78, vh * 0.74, "E", "interact", "Взять")
	_make_action_btn(vw * 0.86, vh * 0.74, "I", "open_inventory", "Сумка")
	_make_action_btn(vw * 0.78, vh * 0.62, "T", "open_dialogue", "Речь")
	# Persistent controls hint (top-center)
	var hint: Label = Label.new()
	hint.text = "WASD / кнопки — движение   |   E — взять   |   I — инвентарь   |   T — речь"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.95, 0.92, 0.80))
	hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	hint.add_theme_constant_override("shadow_offset_x", 1)
	hint.add_theme_constant_override("shadow_offset_y", 1)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hint.position = Vector2(0, 4)
	hint.size = Vector2(vw, 24)
	add_child(hint)

func _make_dpad(origin_x: float, origin_y: float) -> void:
	var s: float = DPAD_BTN_SIZE
	var gap: float = 4.0
	# up (W)
	_make_hold_btn(origin_x + s + gap, origin_y, s, s, "W", "move_up")
	# left (A)
	_make_hold_btn(origin_x, origin_y + s + gap, s, s, "A", "move_left")
	# right (D)
	_make_hold_btn(origin_x + 2.0 * (s + gap), origin_y + s + gap, s, s, "D", "move_right")
	# down (S)
	_make_hold_btn(origin_x + s + gap, origin_y + 2.0 * (s + gap), s, s, "S", "move_down")

func _make_hold_btn(x: float, y: float, w: float, h: float, label: String, action: String) -> void:
	var btn: Button = Button.new()
	btn.text = label
	btn.focus_mode = Control.FOCUS_NONE
	btn.modulate = Color(1, 1, 1, 0.85)
	btn.add_theme_font_size_override("font_size", 26)
	add_child(btn)
	btn.offset_left = x
	btn.offset_top = y
	btn.offset_right = x + w
	btn.offset_bottom = y + h
	btn.size = Vector2(w, h)
	btn.position = Vector2(x, y)
	var act: StringName = StringName(action)
	# parse_input_event dispatches a REAL InputEventAction through the full input pipeline,
	# so both Input.get_axis (state) and _unhandled_input (events) receive it.
	btn.button_down.connect(func() -> void:
		var ev: InputEventAction = InputEventAction.new()
		ev.action = act
		ev.pressed = true
		Input.parse_input_event(ev))
	btn.button_up.connect(func() -> void:
		var ev: InputEventAction = InputEventAction.new()
		ev.action = act
		ev.pressed = false
		Input.parse_input_event(ev))

func _make_action_btn(x: float, y: float, key: String, action: String, label: String) -> void:
	var w: float = DPAD_BTN_SIZE * 1.5
	var h: float = DPAD_BTN_SIZE
	var btn: Button = Button.new()
	btn.text = label + "\n[" + key + "]"
	btn.focus_mode = Control.FOCUS_NONE
	btn.modulate = Color(1, 1, 1, 0.9)
	btn.add_theme_font_size_override("font_size", 15)
	add_child(btn)
	btn.offset_left = x
	btn.offset_top = y
	btn.offset_right = x + w
	btn.offset_bottom = y + h
	btn.size = Vector2(w, h)
	btn.position = Vector2(x, y)
	var act: StringName = StringName(action)
	# Emit a real press+release InputEvent so _unhandled_input handlers (player, inventory) react.
	btn.pressed.connect(func() -> void:
		var press: InputEventAction = InputEventAction.new()
		press.action = act
		press.pressed = true
		Input.parse_input_event(press)
		await get_tree().create_timer(0.05).timeout
		var rel: InputEventAction = InputEventAction.new()
		rel.action = act
		rel.pressed = false
		Input.parse_input_event(rel))

func _focus_canvas() -> void:
	# HTML5: ensure the game canvas has keyboard focus so WASD works immediately
	if OS.has_feature("web"):
		JavaScriptBridge.eval("setTimeout(function(){var c=document.querySelector('canvas');if(c){c.focus();}},150);", true)

func _on_hp_changed(current: int, maximum: int) -> void:
	var text: String = "HP: " + str(current) + "/" + str(maximum)
	if _hp_label:
		_hp_label.text = text

func _on_dots_changed(count: int) -> void:
	var text: String = ".: " + str(count)
	if _dots_label:
		_dots_label.text = text

func _on_ellipsis_created(_count: int) -> void:
	if _ellipsis_label:
		_ellipsis_label.text = "...: " + str(InventoryManager.get_punctuation_count("..."))
		_ellipsis_label.visible = true

func show_interaction_hint(text: String) -> void:
	if _interaction_label:
		_interaction_label.text = text
		_interaction_label.visible = true

func hide_interaction_hint() -> void:
	if _interaction_label:
		_interaction_label.visible = false

func _on_dialogue_started() -> void:
	if _dialogue_box:
		_dialogue_box.visible = true

func _on_dialogue_ended() -> void:
	if _dialogue_box:
		_dialogue_box.visible = false

func _on_dialogue_text_set(text: String) -> void:
	if _dialogue_label:
		_dialogue_label.text = text
