extends Node
class_name TestBridge

var _js_bridge: JavaScriptObject = null

func _ready() -> void:
	if OS.has_feature("web"):
		_setup_js_bridge()
	else:
		_setup_native_bridge()

func _setup_js_bridge() -> void:
	_js_bridge = JavaScriptBridge.eval("""
		(function() {
			window.gameLoaded = false;
			window.gameMenuVisible = true;
			window.gamePlayerPos = {x: 0, y: 0};
			window.gameInventory = {letters: {}, dots: 0, punctuation: {}};
			window.gameHUD = {hp: '', dots: '', region: ''};
			window.gameDialogueText = '';
			window.gameDialogueActive = false;
			window.gameInCombat = false;
			window.gameInventoryVisible = false;
			window.gameSelectCard = null;
			return true;
		})()
	""")

func _setup_native_bridge() -> void:
	JSBridge.game_loaded = false
	JSBridge.menu_visible = true
	JSBridge.player_pos = {x = 0.0, y = 0.0}
	JSBridge.inventory = {letters = {}, dots = 0, punctuation = {}}
	JSBridge.hud = {hp = "", dots = "", region = ""}
	JSBridge.dialogue_text = ""
	JSBridge.dialogue_active = false
	JSBridge.in_combat = false
	JSBridge.inventory_visible = false

func set_game_loaded(loaded: bool) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameLoaded = " + str(loaded).to_lower() + ";")
	else:
		JSBridge.game_loaded = loaded

func set_menu_visible(visible: bool) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameMenuVisible = " + str(visible).to_lower() + ";")
	else:
		JSBridge.menu_visible = visible

func update_player_position(x: float, y: float) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gamePlayerPos = {x: " + str(x) + ", y: " + str(y) + "};")
	else:
		JSBridge.player_pos = {x = x, y = y}

func update_inventory() -> void:
	var inv_letters: Dictionary = InventoryManager.get_all_letters()
	var inv_dots: int = InventoryManager.get_dots()
	var inv_punct: Dictionary = InventoryManager.get_all_punctuation()
	if OS.has_feature("web"):
		var letters_json: String = JSON.stringify(inv_letters)
		var punct_json: String = JSON.stringify(inv_punct)
		JavaScriptBridge.eval("window.gameInventory = {letters: " + letters_json + ", dots: " + str(inv_dots) + ", punctuation: " + punct_json + "};")
	else:
		JSBridge.inventory = {letters = inv_letters, dots = inv_dots, punctuation = inv_punct}

func update_hud(hp_text: String, dots_text: String, region_text: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameHUD = {hp: '" + hp_text + "', dots: '" + dots_text + "', region: '" + region_text + "'};")
	else:
		JSBridge.hud = {hp = hp_text, dots = dots_text, region = region_text}

func set_dialogue_active(active: bool, text: String = "") -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameDialogueActive = " + str(active).to_lower() + "; window.gameDialogueText = '" + text + "';")
	else:
		JSBridge.dialogue_active = active
		JSBridge.dialogue_text = text

func set_in_combat(in_combat: bool) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameInCombat = " + str(in_combat).to_lower() + ";")
	else:
		JSBridge.in_combat = in_combat

func set_inventory_visible(visible: bool) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameInventoryVisible = " + str(visible).to_lower() + ";")
	else:
		JSBridge.inventory_visible = visible

func set_select_card_callback(callback: Callable) -> void:
	pass
