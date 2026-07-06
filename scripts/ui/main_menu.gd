extends Control
class_name MainMenu

const MANUAL_SCENE: PackedScene = preload("res://scenes/ui/manual.tscn")

@onready var _new_game_button: Button = $CenterCol/NewGameButton
@onready var _quit_button: Button = $CenterCol/QuitButton
@onready var _manual_button: Button = $CenterCol/ManualButton
@onready var _legend_button: Button = $CenterCol/LegendButton
@onready var _multiplayer_button: Button = $CenterCol/MultiplayerButton
@onready var _title_label: Label = $CenterCol/Title
@onready var _subtitle_label: Label = $CenterCol/Subtitle
@onready var _hint_label: Label = $CenterCol/HintLabel
var _continue_button: Button = null
var _lang_option: OptionButton = null

var _manual: ManualUI = null
# Touch zones: enlarged invisible rects around each button for easy tapping.
# Tap inside enlarged area triggers the button. Solves tap-coord issues across
# devices because we hit-test in screen-space using full viewport.
var _touch_zones: Array = []

func _ready() -> void:
	# DO NOT enable emulate_mouse_from_touch — it would cause double-handling:
	# touch -> _input (_dispatch_button -> handler) AND touch -> mouse -> Button
	# pressed signal -> handler. Two calls = toggle cancels itself.
	# Custom _input below handles touch directly on all platforms.
	Input.emulate_touch_from_mouse = true
	_apply_texts()
	_build_language_selector()
	I18n.locale_changed.connect(_on_locale_changed)
	_new_game_button.pressed.connect(_on_new_game)
	_quit_button.pressed.connect(_on_quit)
	if _manual_button:
		_manual_button.pressed.connect(_toggle_manual)
	if _legend_button:
		_legend_button.pressed.connect(_on_legend)
	if _multiplayer_button:
		_multiplayer_button.pressed.connect(_on_multiplayer)
	_manual = MANUAL_SCENE.instantiate() as ManualUI
	add_child(_manual)
	# Ensure Manual overlay starts hidden — its _ready sets visible=false, but the
	# scene's Control default is visible=true and a race can leave it shown.
	if _manual:
		_manual.visible = false
		_manual.hide_manual()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameLoaded = true; window.gameMenuVisible = true;")
		JavaScriptBridge.eval("window.gameClickNewGame = function() { window._godotNewGame = true; };")
		JavaScriptBridge.eval("window.gameClickManual = function() { window._godotToggleManual = true; };")
		JavaScriptBridge.eval("window.gameClickLegend = function() { window._godotLegend = true; };")
		JavaScriptBridge.eval("window.gameIsManualOpen = function() { return !!(window.gameManualVisible||false); };")
	_setup_js_poll()
	# Build enlarged touch zones after layout has settled.
	call_deferred("_build_touch_zones")
	# Web browsers block window.close() — the Quit button is meaningless in a
	# browser tab, so hide it on HTML5 exports.
	if _quit_button and OS.has_feature("web"):
		_quit_button.visible = false
	# Start background music in the menu. On web this streams via HTML5 <audio>
	# (see music.gd _play_current_web) — no createBuffer crash. Music.play_legend()
	# in intro switches to the legend playlist; resume_level switches back.
	call_deferred("_start_menu_music")
	# If a saved game exists, show a "Continue" button above "Новая игра".
	call_deferred("_setup_continue_button")

func _apply_texts() -> void:
	# Localize every menu label/button for the current locale.
	if _title_label:
		_title_label.text = I18n.t("menu.title", "BOOKWAR")
	if _subtitle_label:
		_subtitle_label.text = I18n.t("menu.subtitle", "")
	if _new_game_button:
		_new_game_button.text = I18n.t("menu.new_game", "New Game")
	if _legend_button:
		_legend_button.text = I18n.t("menu.legend", "Legend")
	if _manual_button:
		_manual_button.text = I18n.t("menu.how_to_play", "How to Play")
	if _multiplayer_button:
		_multiplayer_button.text = I18n.t("menu.multiplayer", "Multiplayer")
	if _quit_button:
		_quit_button.text = I18n.t("menu.quit", "Quit")
	if _hint_label:
		_hint_label.text = I18n.t("menu.hint", "")
	if _continue_button:
		_continue_button.text = I18n.t("menu.continue", "Continue")
	# Expose the actually-displayed texts so tests can verify localization applied
	# (not just that glyphs exist). Read after switching locale to confirm the
	# on-screen labels changed.
	if OS.has_feature("web"):
		var dump: Dictionary = {
			"locale": I18n.get_locale(),
			"title": _title_label.text if _title_label else "",
			"subtitle": _subtitle_label.text if _subtitle_label else "",
			"new_game": _new_game_button.text if _new_game_button else "",
			"legend": _legend_button.text if _legend_button else "",
			"manual": _manual_button.text if _manual_button else "",
			"multiplayer": _multiplayer_button.text if _multiplayer_button else "",
			"quit": _quit_button.text if _quit_button else ""
		}
		JavaScriptBridge.eval("window.gameMenuTexts = " + JSON.stringify(dump) + ";", true)

func _build_language_selector() -> void:
	# Top-right dropdown listing every supported locale by its native name.
	if _lang_option != null:
		return
	_lang_option = OptionButton.new()
	_lang_option.name = "LanguageOption"
	_lang_option.add_theme_font_size_override("font_size", 16)
	_lang_option.custom_minimum_size = Vector2(200, 40)
	var cur := I18n.get_locale()
	var sel_idx := 0
	for i in range(I18n.get_locales().size()):
		var loc: String = I18n.get_locales()[i]
		_lang_option.add_item(I18n.get_native_name(loc), i)
		_lang_option.set_item_metadata(i, loc)
		if loc == cur:
			sel_idx = i
	_lang_option.select(sel_idx)
	# Place at top-right corner.
	_lang_option.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_lang_option.offset_left = -230.0
	_lang_option.offset_right = -20.0
	_lang_option.offset_top = 20.0
	_lang_option.offset_bottom = 60.0
	_lang_option.item_selected.connect(_on_language_selected)
	add_child(_lang_option)

func _on_language_selected(idx: int) -> void:
	var loc: String = str(_lang_option.get_item_metadata(idx))
	I18n.set_locale(loc)

func _on_locale_changed(_locale: String) -> void:
	_apply_texts()
	call_deferred("_build_touch_zones")

func _setup_continue_button() -> void:
	await get_tree().process_frame
	if not SaveManager.has_save():
		return
	if _continue_button != null:
		return  # already added
	_continue_button = Button.new()
	_continue_button.name = "ContinueButton"
	_continue_button.text = I18n.t("menu.continue", "Continue")
	_continue_button.add_theme_font_size_override("font_size", 22)
	_continue_button.custom_minimum_size = Vector2(0, 50)
	# Insert above NewGameButton
	var idx: int = _new_game_button.get_index()
	$CenterCol.move_child(_new_game_button, idx + 1)
	$CenterCol.add_child(_continue_button)
	$CenterCol.move_child(_continue_button, idx)
	# Also add a "Reset save" small text-button next to it, so the player can wipe
	# the save and start fresh without manually clearing localStorage.
	var reset_btn: Button = Button.new()
	reset_btn.name = "ResetSaveButton"
	reset_btn.text = I18n.t("menu.reset_save", "Reset Save")
	reset_btn.add_theme_font_size_override("font_size", 13)
	reset_btn.modulate = Color(0.7, 0.6, 0.55, 0.85)
	reset_btn.custom_minimum_size = Vector2(0, 26)
	$CenterCol.add_child(reset_btn)
	# Wire reset to a one-shot direct handler (no signal-connect per §0.11).
	reset_btn.pressed.connect(func():
		SaveManager.clear_save()
		# Reload the menu so the Continue/Reset buttons disappear.
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	)
	# Repaint touch zones (now includes the new buttons)
	call_deferred("_build_touch_zones")
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameHasSave = true;")

func _on_continue() -> void:
	# Load saved game and jump straight into the world (no legend, no char_select).
	var saved: Dictionary = SaveManager.load_game()
	if saved.is_empty():
		return
	SaveManager.apply_save(saved)
	GameState.intro_return_to = "world"
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameMenuVisible = false;")
	get_tree().change_scene_to_file("res://scenes/world/world_map.tscn")

func _start_menu_music() -> void:
	await get_tree().process_frame
	Music.start()
	# NOTE: do NOT call Music.start() in the menu. Music is started only in
	# world_map._ready (after the player picks a hero). Reason: some MUSIC/*.mp3
	# tracks are large enough to fail AudioContext.createBuffer on mobile,
	# crashing the whole game before the menu even appears (see errors.md БАГ-001).
	# First launch: auto-show the Legend so new players see the story first.
	# Check both in-memory flag and browser localStorage (persists across reloads).
	if not _intro_already_seen():
		call_deferred("_auto_show_legend_first_launch")

func _intro_already_seen() -> bool:
	if GameState.has_story_flag("intro_seen"):
		return true
	if OS.has_feature("web"):
		return JavaScriptBridge.eval("(function(){ try { return localStorage.getItem('bookwar_intro_seen') === '1'; } catch(e) { return false; } }());", true)
	return false

func _build_touch_zones() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_touch_zones.clear()
	for btn in [_continue_button, _new_game_button, _legend_button, _manual_button, _multiplayer_button, _quit_button]:
		if btn == null or not btn.visible:
			continue
		var r: Rect2 = btn.get_global_rect()
		# Small padding only — large pads cause upper buttons to intercept taps meant
		# for lower buttons (scan showed Manual tap triggered Legend instead).
		var pad_x := 80.0
		var pad_y := 20.0
		var enlarged := Rect2(r.position.x - pad_x, r.position.y - pad_y, r.size.x + pad_x * 2.0, r.size.y + pad_y * 2.0)
		_touch_zones.append({rect = enlarged, button = btn})
	# Expose exact rects to JS for debugging/testing. Also expose the actual
	# Godot viewport size — under stretch/aspect=expand this differs from the
	# project's base 1280x720 (it grows horizontally to match the display aspect),
	# so test harnesses must map CSS coords -> Godot coords using THIS size.
	if OS.has_feature("web"):
		var vs: Vector2 = get_viewport().get_visible_rect().size
		var parts: Array = []
		for z in _touch_zones:
			var b: Button = z.button
			var r: Rect2 = b.get_global_rect()
			parts.append("{\"name\":\"%s\",\"x\":%.1f,\"y\":%.1f,\"w\":%.1f,\"h\":%.1f}" % [b.name, r.position.x, r.position.y, r.size.x, r.size.y])
		JavaScriptBridge.eval("window.gameButtonRects = [" + ",".join(parts) + "]; window.gameViewportSize = {w:" + str(int(vs.x)) + ",h:" + str(int(vs.y)) + "};")

func _auto_show_legend_first_launch() -> void:
	# Wait a couple of frames for layout + manual to settle, then trigger legend.
	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(_legend_button):
		# After the auto-shown legend, return to the menu (so the player can pick New Game).
		GameState.intro_return_to = "menu"
		_on_legend()

func _setup_js_poll() -> void:
	if not OS.has_feature("web"):
		return
	set_process(true)

func _process(_delta: float) -> void:
	if not OS.has_feature("web"):
		return
	if JavaScriptBridge.eval("typeof window._godotNewGame !== 'undefined' && window._godotNewGame"):
		JavaScriptBridge.eval("window._godotNewGame = false;")
		_on_new_game()
	if JavaScriptBridge.eval("typeof window._godotToggleManual !== 'undefined' && window._godotToggleManual"):
		JavaScriptBridge.eval("window._godotToggleManual = false;")
		_toggle_manual()
	if JavaScriptBridge.eval("typeof window._godotLegend !== 'undefined' && window._godotLegend"):
		JavaScriptBridge.eval("window._godotLegend = false;")
		_on_legend()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_manual"):
		_toggle_manual()
		get_viewport().set_input_as_handled()

# Universal tap handler — works on ALL platforms including HTML5 web exports.
# Default emulate_mouse_from_touch is unreliable in Godot 4.6 HTML5 (only the
# top-most buttons receive taps). This explicit hit-test catches every button.
func _input(event: InputEvent) -> void:
	var pos := Vector2(-1, -1)
	var is_press := false
	if event is InputEventScreenTouch:
		pos = event.position
		is_press = event.pressed
	elif event is InputEventMouseButton:
		pos = event.position
		is_press = event.pressed
	if not is_press or pos.x < 0:
		return
	# DEBUG
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameLastTap = {x:%.1f, y:%.1f};" % [pos.x, pos.y])
	# Direct hit on a button — invoke the handler directly (more reliable than
	# relying on Button.pressed signal connections, which can silently fail when
	# a child scene instantiate disturbs _ready's connection order).
	for btn in [_continue_button, _new_game_button, _legend_button, _manual_button, _multiplayer_button, _quit_button]:
		if btn == null:
			continue
		if btn.get_global_rect().has_point(pos):
			_dispatch_button(btn)
			get_viewport().set_input_as_handled()
			return
	# Fallback: enlarged touch zones — pick the NEAREST button (not first in list),
	# so a tap between two buttons doesn't always trigger the topmost one.
	var best_btn: Button = null
	var best_dist: float = 1e12
	for zone in _touch_zones:
		if zone.rect.has_point(pos):
			var c: Vector2 = zone.button.get_global_rect().get_center()
			var d: float = c.distance_squared_to(pos)
			if d < best_dist:
				best_dist = d
				best_btn = zone.button
	if best_btn != null:
		_dispatch_button(best_btn)
		get_viewport().set_input_as_handled()
		return

func _dispatch_button(btn: Button) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameDispatch = '" + btn.name + "';")
	if btn == _new_game_button:
		_on_new_game()
	elif btn == _continue_button:
		_on_continue()
	elif btn == _legend_button:
		_on_legend()
	elif btn == _manual_button:
		_toggle_manual()
	elif btn == _multiplayer_button:
		_on_multiplayer()
	elif btn == _quit_button:
		_on_quit()

var _last_toggle_time: float = 0.0

func _toggle_manual() -> void:
	if _manual == null:
		if OS.has_feature("web"):
			JavaScriptBridge.eval("window.gameToggleDebug = 'manual_is_null';")
		return
	# Debounce: touch + emulate_mouse can both fire on a single tap, causing
	# toggle+toggle = no-op. Ignore repeat calls within 300ms.
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_toggle_time < 0.3:
		if OS.has_feature("web"):
			JavaScriptBridge.eval("window.gameToggleDebug = 'debounced';")
		return
	_last_toggle_time = now
	var was_open: bool = _manual.is_open()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameToggleDebug = 'was_open=" + str(was_open) + " visible=" + str(_manual.visible) + "';")
	if was_open:
		_manual.hide_manual()
	else:
		_manual.show_manual()

func _on_new_game() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameMenuVisible = false;")
	# Wipe any previous save so the autosave doesn't merge new-game state with
	# the old run's letters/recruits. Player chose "New Game" → fresh start.
	SaveManager.clear_save()
	GameState.reset()
	# Always show the legend before character select. intro._finish reads this flag
	# and routes back here (char_select). The legend's "Пропустить" button is a real
	# touch+mouse target now, so mobile users can skip quickly.
	GameState.intro_return_to = "char_select"
	get_tree().change_scene_to_file("res://scenes/ui/intro.tscn")

func _on_legend() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameMenuVisible = false;")
	# Default route after the legend is the world (when invoked from the "Легенда" menu button
	# the user has already played before). _on_new_game / _auto_show_legend override this.
	if GameState.intro_return_to == "":
		GameState.intro_return_to = "world"
	get_tree().change_scene_to_file("res://scenes/ui/intro.tscn")

func _on_multiplayer() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameMenuVisible = false;")
	get_tree().change_scene_to_file("res://scenes/ui/multiplayer.tscn")

func _on_quit() -> void:
	# Web browsers block get_tree().quit() — reload to the menu instead.
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.location.href = window.location.pathname;")
		return
	get_tree().quit()
