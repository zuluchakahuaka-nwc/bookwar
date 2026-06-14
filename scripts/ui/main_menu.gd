extends Control
class_name MainMenu

@onready var _new_game_button: Button = $CenterCol/NewGameButton
@onready var _quit_button: Button = $CenterCol/QuitButton

func _ready() -> void:
	_new_game_button.pressed.connect(_on_new_game)
	_quit_button.pressed.connect(_on_quit)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameLoaded = true; window.gameMenuVisible = true;")
		JavaScriptBridge.eval("window.gameClickNewGame = function() { window._godotNewGame = true; };")
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

func _on_new_game() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameMenuVisible = false;")
	get_tree().change_scene_to_file("res://scenes/world/world_map.tscn")

func _on_quit() -> void:
	get_tree().quit()
