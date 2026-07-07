extends CanvasLayer
class_name HUDUI

const DPAD_BTN_SIZE: float = 110.0
const MANUAL_SCENE: PackedScene = preload("res://scenes/ui/manual.tscn")

@onready var _hp_label: Label = $HPLabel
@onready var _dots_label: Label = $DotsLabel
@onready var _region_label: Label = $RegionLabel
@onready var _ellipsis_label: Label = $EllipsisLabel
@onready var _interaction_label: Label = $InteractionLabel
@onready var _dialogue_box: Panel = $DialogueBox
@onready var _dialogue_label: Label = $DialogueBox/DialogueLabel

var _pause_label: Label = null
var _manual: ManualUI = null
var _toast_label: Label = null
var _toast_tween: Tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.hp_changed.connect(_on_hp_changed)
	InventoryManager.dots_changed.connect(_on_dots_changed)
	InventoryManager.ellipsis_created.connect(_on_ellipsis_created)
	InventoryManager.inventory_changed.connect(_on_inventory_changed)
	GameState.dialogue_started.connect(_on_dialogue_started)
	GameState.dialogue_ended.connect(_on_dialogue_ended)
	GameState.dialogue_text_set.connect(_on_dialogue_text_set)
	GameState.recruit_message.connect(_on_recruit_message)
	GameState.toast_requested.connect(_on_toast_requested)
	_on_hp_changed(GameState.player_hp, GameState.player_max_hp)
	_on_dots_changed(InventoryManager.get_dots())
	_interaction_label.visible = false
	if _dialogue_box:
		_dialogue_box.visible = false
	_build_toast_label()
	_build_touch_controls()
	_build_pause_overlay()
	_build_status_frame()  # Parchment panel behind the top-left label cluster.
	_manual = MANUAL_SCENE.instantiate() as ManualUI
	add_child(_manual)
	_focus_canvas()

# Transient toast at the top-center: "Получено ОРУЖИЕ — А" / "Получена БРОНЯ — Б".
func _build_toast_label() -> void:
	_toast_label = Label.new()
	_toast_label.name = "ToastLabel"
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_label.offset_left = -400.0
	_toast_label.offset_right = 400.0
	_toast_label.offset_top = 60.0
	_toast_label.offset_bottom = 110.0
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 26)
	_toast_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	_toast_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_toast_label.add_theme_constant_override("outline_size", 6)
	_toast_label.modulate = Color(1, 1, 1, 0)
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label.visible = false
	add_child(_toast_label)

func _build_status_frame() -> void:
	# Wrap the bare top-left labels (HP / dots / ellipsis / region) in a parchment
	# Panel so the HUD stops looking like a debug overlay. Matches the
	# letter-card aesthetic (audit rec #3, 2026-07-07). Procedural — no asset.
	var frame: Panel = Panel.new()
	frame.name = "StatusFrame"
	frame.offset_left = 6.0
	frame.offset_top = 4.0
	frame.offset_right = 332.0
	frame.offset_bottom = 116.0
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sty: StyleBoxFlat = StyleBoxFlat.new()
	sty.bg_color = Color(0.86, 0.76, 0.55, 0.92)          # cream parchment
	sty.border_color = Color(0.25, 0.16, 0.08, 1.0)       # dark brown border
	sty.set_border_width_all(3)
	sty.set_corner_radius_all(7)
	sty.set_content_margin_all(8)
	sty.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	sty.shadow_size = 5
	frame.add_theme_stylebox_override("panel", sty)
	add_child(frame)
	# Render BEHIND the labels (CanvasLayer draws children in order, so the
	# first child is the bottom of the stack).
	move_child(frame, 0)
	# Tint the labels' text dark brown on the cream background for contrast.
	for lbl: Label in [_hp_label, _dots_label, _ellipsis_label, _region_label]:
		if lbl:
			lbl.add_theme_color_override("font_color", Color(0.18, 0.10, 0.05))
			lbl.add_theme_color_override("font_outline_color", Color(0.95, 0.88, 0.65, 0.7))
			lbl.add_theme_constant_override("outline_size", 3)
			# Push the label ABOVE the new parchment frame (CanvasLayer children
			# stack in insertion order, so re-move each label to the end).
			move_child(lbl, -1)

func _on_toast_requested(text: String) -> void:
	if text == "" or _toast_label == null:
		return
	_toast_label.text = text
	_toast_label.visible = true
	if _toast_tween:
		_tween_kill_safe(_toast_tween)
	_toast_tween = create_tween()
	# Fade in fast, hold, fade out.
	_toast_tween.tween_property(_toast_label, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.6)
	_toast_tween.tween_callback(func(): _toast_label.visible = false)
	if OS.has_feature("web"):
		var escaped: String = text.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "\\n")
		JavaScriptBridge.eval("window.gameToast = '" + escaped + "'; window.gameToastTs = Date.now();")

func _tween_kill_safe(t: Tween) -> void:
	if is_instance_valid(t):
		t.kill()

# --- On-screen controls so the game is playable by mouse/touch without keyboard focus ---
func _build_touch_controls() -> void:
	var vw: float = 1280.0
	var vh: float = 720.0
	# D-pad (bottom-left): up/down/left/right held buttons
	_make_dpad(vw * 0.06, vh * 0.72)
	# Action buttons (bottom-right): take(E), inventory(I), dialogue(T)
	_make_action_btn(vw * 0.78, vh * 0.74, "E", "interact", I18n.t("hud.take", "Take"))
	_make_action_btn(vw * 0.86, vh * 0.74, "I", "open_inventory", I18n.t("hud.bag", "Bag"))
	_make_action_btn(vw * 0.78, vh * 0.62, "T", "open_dialogue", I18n.t("hud.speech", "Speech"))
	_make_manual_btn(vw * 0.86, vh * 0.62)
	_make_legend_btn(vw * 0.86, vh * 0.50)
	# Persistent controls hint (top-center)
	var hint: Label = Label.new()
	hint.text = I18n.t("hud.hint", "WASD / buttons — move | E — take | I — inventory | T — speech")
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

func _make_manual_btn(x: float, y: float) -> void:
	var w: float = DPAD_BTN_SIZE * 1.5
	var h: float = DPAD_BTN_SIZE
	var btn: Button = Button.new()
	btn.text = "?\n[H]"
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
	btn.pressed.connect(func() -> void:
		if _manual:
			if _manual.is_open():
				_manual.hide_manual()
			else:
				_manual.show_manual())

func _make_legend_btn(x: float, y: float) -> void:
	# "Легенда" — re-plays the intro story + legend melody from inside the game.
	var w: float = DPAD_BTN_SIZE * 1.5
	var h: float = DPAD_BTN_SIZE
	var btn: Button = Button.new()
	btn.text = I18n.t("hud.legend", "Legend")
	btn.focus_mode = Control.FOCUS_NONE
	btn.modulate = Color(1.0, 0.92, 0.6, 0.95)
	btn.add_theme_font_size_override("font_size", 14)
	add_child(btn)
	btn.offset_left = x
	btn.offset_top = y
	btn.offset_right = x + w
	btn.offset_bottom = y + h
	btn.size = Vector2(w, h)
	btn.position = Vector2(x, y)
	btn.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/ui/intro.tscn"))

func _focus_canvas() -> void:
	# HTML5: ensure the game canvas has keyboard focus so WASD works immediately
	if OS.has_feature("web"):
		JavaScriptBridge.eval("setTimeout(function(){var c=document.querySelector('canvas');if(c){c.focus();}},150);", true)

func _on_hp_changed(current: int, maximum: int) -> void:
	var text: String = I18n.t("common.hp", "HP") + ": " + str(current) + "/" + str(maximum)
	if _hp_label:
		_hp_label.text = text

func set_region_name(name: String) -> void:
	if _region_label:
		_region_label.text = name

func _on_dots_changed(count: int) -> void:
	var text: String = I18n.t("hud.tokens", "Tokens") + ": " + str(count)
	if _dots_label:
		_dots_label.text = text

func _on_ellipsis_created(_count: int) -> void:
	# Ellipsis is now derived from буквицы; not shown as a separate top-left counter.
	if _ellipsis_label:
		_ellipsis_label.visible = false

func _on_inventory_changed() -> void:
	# Subtle "можно говорить" hint only when the player has enough буквицы for speech
	if _ellipsis_label:
		var can_talk: bool = InventoryManager.has_ellipsis()
		_ellipsis_label.text = I18n.t("hud.can_speak", "Can speak (T)") if can_talk else ""
		_ellipsis_label.visible = can_talk

func show_interaction_hint(text: String) -> void:
	if _interaction_label:
		_interaction_label.text = text
		_interaction_label.visible = true

func hide_interaction_hint() -> void:
	if _interaction_label:
		_interaction_label.visible = false

func _on_dialogue_started() -> void:
	if _recruit_hide_tween:
		_recruit_hide_tween.kill()
		_recruit_hide_tween = null
	if _dialogue_box:
		_dialogue_box.visible = true
	if _interaction_label:
		_interaction_label.text = I18n.t("hud.close_move", "[E/T or move] — close")
		_interaction_label.visible = true

func _on_dialogue_ended() -> void:
	if _dialogue_box:
		_dialogue_box.visible = false
	if _interaction_label:
		_interaction_label.visible = false

func _on_dialogue_text_set(text: String) -> void:
	if _dialogue_label:
		_dialogue_label.text = text

# Recruit / hint message shown after a dialogue (e.g. where to find a letter)
var _recruit_hide_tween: Tween = null
func _on_recruit_message(text: String) -> void:
	if text == "":
		return
	if _dialogue_label:
		_dialogue_label.text = text
	if _dialogue_box:
		_dialogue_box.visible = true
	if _interaction_label:
		_interaction_label.text = I18n.t("hud.close", "[E/T] — close")
		_interaction_label.visible = true
	if OS.has_feature("web"):
		var escaped: String = text.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "\\n")
		JavaScriptBridge.eval("window.gameRecruitMsg = '" + escaped + "'; window.gameRecruitVisible = true;")
	# Auto-hide after 6 seconds if the player doesn't close it
	if _recruit_hide_tween:
		_recruit_hide_tween.kill()
	_recruit_hide_tween = create_tween()
	_recruit_hide_tween.tween_interval(6.0)
	_recruit_hide_tween.tween_callback(_hide_recruit_message)

func _hide_recruit_message() -> void:
	if GameState.is_in_dialogue:
		return
	if _dialogue_box and not GameState.is_in_dialogue:
		_dialogue_box.visible = false
	if _interaction_label and not GameState.is_in_dialogue:
		_interaction_label.visible = false
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameRecruitVisible = false;")

func _build_pause_overlay() -> void:
	_pause_label = Label.new()
	_pause_label.text = I18n.t("hud.paused", "[ PAUSED ]\nSpace — resume")
	_pause_label.add_theme_font_size_override("font_size", 48)
	_pause_label.add_theme_color_override("font_color", Color(1, 1, 0.8))
	_pause_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pause_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_label.visible = false
	add_child(_pause_label)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_manual"):
		if _manual:
			if _manual.is_open():
				_manual.hide_manual()
			else:
				_manual.show_manual()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		if GameState.is_in_combat:
			return
		GameState.is_paused = !GameState.is_paused
		get_tree().paused = GameState.is_paused
		if _pause_label:
			_pause_label.visible = GameState.is_paused
		get_viewport().set_input_as_handled()
