extends Node
class_name TestBridge

var _select_card_callback: Callable = Callable()

const INITIAL_BRIDGE_JS: String = """
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
		window.gameAlphabet = null;
		window.gameMonsterState = null;
		window.gameCombatLog = null;
		return true;
	})()
"""

func _ready() -> void:
	if OS.has_feature("web"):
		_setup_js_bridge()

func _setup_js_bridge() -> void:
	JavaScriptBridge.eval(INITIAL_BRIDGE_JS)
	# Expose combat card selection as a JS callback so Puppeteer can drive it
	JavaScriptBridge.eval("""
		(function() {
			window.gameSelectCard = function(letter) {
				// The actual GDScript callback is registered via set_select_card_callback
				// and read by the world/battle scene each frame (see _process poll).
				if (!window._godotSelectCardQueue) window._godotSelectCardQueue = [];
				window._godotSelectCardQueue.push(letter);
				return true;
			};
			return true;
		})()
	""")

func _is_web() -> bool:
	return OS.has_feature("web")

func set_game_loaded(loaded: bool) -> void:
	if _is_web():
		JavaScriptBridge.eval("window.gameLoaded = " + str(loaded).to_lower() + ";")

func set_menu_visible(is_visible: bool) -> void:
	if _is_web():
		JavaScriptBridge.eval("window.gameMenuVisible = " + str(is_visible).to_lower() + ";")

func update_player_position(x: float, y: float) -> void:
	if _is_web():
		JavaScriptBridge.eval("window.gamePlayerPos = {x: " + str(x) + ", y: " + str(y) + "};")

func update_inventory() -> void:
	if not _is_web():
		return
	var inv_letters: Dictionary = InventoryManager.get_all_letters()
	var inv_dots: int = InventoryManager.get_dots()
	var inv_punct: Dictionary = InventoryManager.get_all_punctuation()
	JavaScriptBridge.eval("window.gameInventory = {letters: " + JSON.stringify(inv_letters) + ", dots: " + str(inv_dots) + ", punctuation: " + JSON.stringify(inv_punct) + "};")

func update_hud(hp_text: String, dots_text: String, region_text: String) -> void:
	if not _is_web():
		return
	# Escape single quotes / backslashes to keep JS string safe
	var safe_hp: String = _escape_js(hp_text)
	var safe_dots: String = _escape_js(dots_text)
	var safe_region: String = _escape_js(region_text)
	JavaScriptBridge.eval("window.gameHUD = {hp: '" + safe_hp + "', dots: '" + safe_dots + "', region: '" + safe_region + "'};")

func set_dialogue_active(active: bool, text: String = "") -> void:
	if not _is_web():
		return
	var safe_text: String = _escape_js(text)
	JavaScriptBridge.eval("window.gameDialogueActive = " + str(active).to_lower() + "; window.gameDialogueText = '" + safe_text + "';")

func set_in_combat(in_combat: bool) -> void:
	if _is_web():
		JavaScriptBridge.eval("window.gameInCombat = " + str(in_combat).to_lower() + ";")

func set_inventory_visible(is_visible: bool) -> void:
	if _is_web():
		JavaScriptBridge.eval("window.gameInventoryVisible = " + str(is_visible).to_lower() + ";")

func set_select_card_callback(callback: Callable) -> void:
	_select_card_callback = callback

func drain_select_card_queue() -> Array:
	"""Returns the list of letters queued by Puppeteer via window.gameSelectCard and clears it."""
	if not _is_web():
		return []
	var queued: Variant = JavaScriptBridge.eval("(window._godotSelectCardQueue || []).slice()")
	if queued == null:
		return []
	JavaScriptBridge.eval("window._godotSelectCardQueue = [];")
	var result: Array = []
	for item: Variant in queued:
		result.append(str(item))
	return result

func has_select_card_callback() -> bool:
	return _select_card_callback.is_valid()

func invoke_select_card(letter: String) -> void:
	if _select_card_callback.is_valid():
		_select_card_callback.call(letter)

func push_alphabet_snapshot(snapshot: Array) -> void:
	if not _is_web():
		return
	JavaScriptBridge.eval("window.gameAlphabet = " + JSON.stringify(snapshot) + ";")

func push_monster_state(snapshot: Dictionary) -> void:
	if not _is_web():
		return
	JavaScriptBridge.eval("window.gameMonsterState = " + JSON.stringify(snapshot) + ";")

func push_combat_log(entry: Dictionary) -> void:
	if not _is_web():
		return
	JavaScriptBridge.eval("window.gameCombatLog = " + JSON.stringify(entry) + ";")

func _escape_js(s: String) -> String:
	return s.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "\\n").replace("\r", "")
