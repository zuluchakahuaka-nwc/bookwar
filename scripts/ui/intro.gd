extends Control
class_name Intro

const WORLD_SCENE_PATH: String = "res://scenes/world/world_map.tscn"
const SPLASH_DIR: String = "res://assets/sprites/splash/"

var _panels: Array = [
	{ "img": "intro_1_world", "key": "prologue.panel_0" },
	{ "img": "intro_1_world", "key": "prologue.panel_1" },
	{ "img": "intro_2_wizard", "key": "prologue.panel_2" },
	{ "img": "intro_3_scatter", "key": "prologue.panel_3" },
	{ "img": "intro_4_chaos", "key": "prologue.panel_4" },
	{ "img": "intro_5_lies", "key": "prologue.panel_5" },
	{ "img": "intro_6_doom", "key": "prologue.panel_6" },
	{ "img": "intro_7_hero", "key": "prologue.panel_7" }
]

var _index: int = 0
var _tex_rect: TextureRect = null
var _text_label: Label = null
var _hint_label: Label = null
var _skip_btn: Button = null
var _prev_btn: Button = null
var _next_btn: Button = null
var _last_input_time: float = 0.0
# --- Prologue title card (заставка) ---
var _title_phase: bool = true
var _title_card: Control = null
var _title_tween: Tween = null

func _ready() -> void:
	# Expose JS bridges FIRST so the intro is always controllable even if some UI
	# building step below fails. Tests and the menu rely on window.gameSkipIntro.
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameIntroActive = true; window.gameIntroIndex = 0;")
		JavaScriptBridge.eval("window.gameAdvanceIntro = function() { window._godotIntroAdvance = true; };")
		JavaScriptBridge.eval("window.gameSkipIntro = function() { window._godotIntroSkip = true; };")
	_build_ui()
	_show_panel(0)
	# Build the cinematic title splash (заставка). Guarded so a failure here never
	# blocks the legend itself.
	_build_title_card()
	# Legend overlay → switch to the legend melody while the story plays.
	# Now works on web too via HTML5 <audio> streaming (see music.gd).
	Music.play_legend()
	# Auto-dismiss the title card after a few seconds (player can also tap).
	get_tree().create_timer(3.2).timeout.connect(_dismiss_title_card)

func _build_title_card() -> void:
	# Cinematic title splash (заставка): BOOKWAR + tagline, fades in over the
	# first story splash. Any tap/key dismisses it and reveals the legend.
	_title_card = Control.new()
	_title_card.name = "TitleCard"
	_title_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_title_card.modulate.a = 0.0
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.03, 0.06, 1.0)
	_title_card.add_child(bg)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.offset_left = -360.0
	col.offset_right = 360.0
	col.offset_top = -140.0
	col.offset_bottom = 140.0
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	_title_card.add_child(col)
	var title := Label.new()
	title.text = I18n.t("prologue.title", "BOOKWAR")
	title.add_theme_font_size_override("font_size", 86)
	title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.30, 1))
	title.add_theme_color_override("font_outline_color", Color(0.12, 0.04, 0.02, 1))
	title.add_theme_constant_override("outline_size", 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var tag := Label.new()
	tag.text = I18n.t("prologue.tagline", "")
	tag.add_theme_font_size_override("font_size", 24)
	tag.add_theme_color_override("font_color", Color(0.80, 0.74, 0.55, 1))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tag)
	var rule := Label.new()
	rule.text = "—"
	rule.add_theme_font_size_override("font_size", 28)
	rule.add_theme_color_override("font_color", Color(0.6, 0.5, 0.3, 1))
	rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(rule)
	add_child(_title_card)
	_title_card.z_index = 10
	# Fade in.
	_title_tween = create_tween()
	_title_tween.tween_property(_title_card, "modulate:a", 1.0, 0.9)

func _dismiss_title_card() -> void:
	if not _title_phase or _title_card == null or not is_instance_valid(_title_card):
		_title_phase = false
		return
	_title_phase = false
	if _title_tween and _title_tween.is_valid():
		_title_tween.kill()
	var tw := create_tween()
	tw.tween_property(_title_card, "modulate:a", 0.0, 0.6)
	tw.tween_callback(_title_card.queue_free)

func _process(_delta: float) -> void:
	if not OS.has_feature("web"):
		return
	if JavaScriptBridge.eval("typeof window._godotIntroAdvance !== 'undefined' && window._godotIntroAdvance"):
		JavaScriptBridge.eval("window._godotIntroAdvance = false;")
		_advance()
	if JavaScriptBridge.eval("typeof window._godotIntroSkip !== 'undefined' && window._godotIntroSkip"):
		JavaScriptBridge.eval("window._godotIntroSkip = false;")
		_finish()

func _build_ui() -> void:
	_tex_rect = TextureRect.new()
	_tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(_tex_rect)

	# Legend text floats directly over the splash image — no dark panel behind it.
	_text_label = Label.new()
	_text_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_text_label.offset_left = 80.0
	_text_label.offset_right = -80.0
	_text_label.offset_top = -300.0
	_text_label.offset_bottom = -40.0
	# Decorative Old Slavonic calligraphy (RuslanDisplay) with flourishes.
	# A fallback covers any glyphs the display font may be missing.
	var primary: FontFile = ResourceLoader.load("res://assets/fonts/RuslanDisplay-Regular.ttf", "FontFile") as FontFile
	var fallback: FontFile = ResourceLoader.load("res://assets/fonts/RussoOne-Regular.ttf", "FontFile") as FontFile
	if primary:
		if fallback:
			primary.fallbacks = [fallback]
		_text_label.add_theme_font_override("font", primary)
	_text_label.add_theme_font_size_override("font_size", 44)
	_text_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82))
	_text_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_text_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	_text_label.add_theme_constant_override("outline_size", 8)
	_text_label.add_theme_constant_override("shadow_size", 3)
	_text_label.add_theme_constant_override("shadow_offset_x", 2)
	_text_label.add_theme_constant_override("shadow_offset_y", 2)
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_text_label)

	_skip_btn = Button.new()
	_skip_btn.text = I18n.t("prologue.skip", "Skip legend >>")
	# Big, centered at the top — impossible to miss on mobile.
	_skip_btn.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_skip_btn.offset_left = -180.0
	_skip_btn.offset_right = 180.0
	_skip_btn.offset_top = 18.0
	_skip_btn.offset_bottom = 68.0
	_skip_btn.add_theme_font_size_override("font_size", 22)
	_skip_btn.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	_skip_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_skip_btn.add_theme_constant_override("outline_size", 4)
	_skip_btn.modulate = Color(1, 1, 1, 0.95)
	# NOTE: do NOT connect `pressed` signal — on web, touch+emulate-mouse would
	# trigger BOTH the signal AND our _input hit-test, doubling the action
	# (1 tap = 2 advances, so legend jumped panel 1 → 3). Only _input drives
	# the handler now. See AGENTS.md §0.11 "1 action = 1 effect".
	add_child(_skip_btn)

	# Prev / Next nav buttons at the bottom — large tap targets on either side
	# of the text so users can flip panels without guessing where to tap.
	_prev_btn = Button.new()
	_prev_btn.text = I18n.t("prologue.back", "← Back")
	_prev_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_prev_btn.offset_left = 24.0
	_prev_btn.offset_top = -84.0
	_prev_btn.offset_right = 244.0
	_prev_btn.offset_bottom = -28.0
	_prev_btn.add_theme_font_size_override("font_size", 22)
	_prev_btn.modulate = Color(1, 1, 1, 0.9)
	add_child(_prev_btn)

	_next_btn = Button.new()
	_next_btn.text = "Вперёд →"
	_next_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_next_btn.offset_left = -244.0
	_next_btn.offset_top = -84.0
	_next_btn.offset_right = -24.0
	_next_btn.offset_bottom = -28.0
	_next_btn.add_theme_font_size_override("font_size", 22)
	_next_btn.modulate = Color(1, 1, 1, 0.9)
	add_child(_next_btn)

	_hint_label = Label.new()
	_hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint_label.offset_top = -34.0
	_hint_label.offset_bottom = -8.0
	_hint_label.add_theme_font_size_override("font_size", 15)
	_hint_label.add_theme_color_override("font_color", Color(0.80, 0.74, 0.55))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint_label)

func _show_panel(idx: int) -> void:
	if idx >= _panels.size():
		_finish()
		return
	_index = idx
	var p: Dictionary = _panels[idx]
	var path: String = SPLASH_DIR + String(p.get("img", "")) + ".png"
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path) as Texture2D
		if tex:
			_tex_rect.texture = tex
	if _text_label:
		_text_label.text = I18n.t(String(p.get("key", "")), String(p.get("text", "")))
	if _hint_label:
		_hint_label.text = I18n.t_fmt("prologue.scene_counter", [str(idx + 1), str(_panels.size())])
	# Update nav button state: "Назад" disabled on first page, "Вперёд" -> "Начать игру" on last.
	if _prev_btn:
		_prev_btn.disabled = (idx == 0)
		_prev_btn.modulate.a = 0.4 if idx == 0 else 0.95
	if _next_btn:
		if idx == _panels.size() - 1:
			_next_btn.text = I18n.t("prologue.start_game", "Start Game →")
		else:
			_next_btn.text = I18n.t("prologue.next", "Next →")
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameIntroIndex = " + str(idx) + ";")

func _advance() -> void:
	if _title_phase:
		_dismiss_title_card()
		return
	_show_panel(_index + 1)

func _go_prev() -> void:
	if _index > 0:
		_show_panel(_index - 1)

func _finish() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameIntroActive = false;")
	GameState.set_story_flag("intro_seen", true)
	# Persist intro_seen in browser localStorage so first-launch autolegend isn't repeated.
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(function(){ try { localStorage.setItem('bookwar_intro_seen','1'); } catch(e) {} }());", true)
	# Back to the level playlist (no-op if the game hadn't started it yet, e.g. first launch).
	Music.resume_level()
	# Route based on who invoked the legend (GameState.intro_return_to).
	# Default "world" preserves backward-compat.
	var dest: String = GameState.intro_return_to
	if dest == "":
		dest = "world"
	# Reset for next time
	GameState.intro_return_to = "world"
	match dest:
		"menu":        get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
		"char_select": get_tree().change_scene_to_file("res://scenes/ui/character_select.tscn")
		_:             get_tree().change_scene_to_file(WORLD_SCENE_PATH)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_advance()
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	# Universal handler — works on mobile (touch) and desktop (mouse).
	# Tap on Skip/Prev/Next buttons -> their handler; tap anywhere else -> _advance.
	# Direct call (no emit_signal) — reliable on web (see AGENTS.md §0.9).
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
	# During the title splash, any tap/key just dismisses it (doesn't advance panels).
	if _title_phase:
		_dismiss_title_card()
		get_viewport().set_input_as_handled()
		return
	# Debounce — touch+mouse-emulate can fire twice on a single tap.
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_input_time < 0.2:
		return
	_last_input_time = now
	if _skip_btn and _skip_btn.get_global_rect().has_point(pos):
		_finish()
	elif _prev_btn and _prev_btn.visible and not _prev_btn.disabled and _prev_btn.get_global_rect().has_point(pos):
		_go_prev()
	elif _next_btn and _next_btn.visible and _next_btn.get_global_rect().has_point(pos):
		_advance()
	else:
		_advance()
