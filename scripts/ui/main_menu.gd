extends Control
class_name MainMenu

const MANUAL_SCENE: PackedScene = preload("res://scenes/ui/manual.tscn")

@onready var _new_game_button: Button = $CenterCol/NewGameButton
@onready var _quit_button: Button = $CenterCol/QuitButton
@onready var _manual_button: Button = $CenterCol/ManualButton
@onready var _legend_button: Button = $CenterCol/LegendButton

var _manual: ManualUI = null

func _ready() -> void:
	_new_game_button.pressed.connect(_on_new_game)
	_quit_button.pressed.connect(_on_quit)
	if _manual_button:
		_manual_button.pressed.connect(_toggle_manual)
	if _legend_button:
		_legend_button.pressed.connect(_on_legend)
	_manual = MANUAL_SCENE.instantiate() as ManualUI
	add_child(_manual)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameLoaded = true; window.gameMenuVisible = true;")
		JavaScriptBridge.eval("window.gameClickNewGame = function() { window._godotNewGame = true; };")
		JavaScriptBridge.eval("window.gameClickManual = function() { window._godotToggleManual = true; };")
		JavaScriptBridge.eval("window.gameClickLegend = function() { window._godotLegend = true; };")
		JavaScriptBridge.eval("window.gameIsManualOpen = function() { return !!(window.gameManualVisible||false); };")
	_setup_js_poll()

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

func _toggle_manual() -> void:
	if _manual == null:
		return
	if _manual.is_open():
		_manual.hide_manual()
	else:
		_manual.show_manual()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_manual"):
		_toggle_manual()
		get_viewport().set_input_as_handled()

func _on_new_game() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameMenuVisible = false;")
	get_tree().change_scene_to_file("res://scenes/ui/character_select.tscn")

func _on_legend() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameMenuVisible = false;")
	get_tree().change_scene_to_file("res://scenes/ui/intro.tscn")

func _on_quit() -> void:
	get_tree().quit()
