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
		window.gameCombatLogAll = [];
		window.gameMonsterStates = [];
		return true;
	})()
"""

func _ready() -> void:
	if OS.has_feature("web"):
		_setup_js_bridge()

func _setup_js_bridge() -> void:
	JavaScriptBridge.eval(INITIAL_BRIDGE_JS)
	# Expose combat card selection + test drivers as JS callbacks so Puppeteer can drive them
	JavaScriptBridge.eval("""
		(function() {
			window.gameSelectCard = function(letter) {
				if (!window._godotSelectCardQueue) window._godotSelectCardQueue = [];
				window._godotSelectCardQueue.push(letter);
				return true;
			};
			window.gameStartTestCombat = function(name, hp, letters) {
				if (!window._godotTestCombatQueue) window._godotTestCombatQueue = [];
				window._godotTestCombatQueue.push({name: name, hp: hp, letters: letters});
				return true;
			};
			window.gameTestAddLetter = function(letter) {
				if (!window._godotTestLetterQueue) window._godotTestLetterQueue = [];
				window._godotTestLetterQueue.push(letter);
				return true;
			};
			window.gameResetCombatLog = function() {
				window.gameCombatLogAll = [];
				window.gameCombatLog = null;
				return true;
			};
			window.gameTestStartDialogue = function() {
				window._godotTestDialogue = true;
				return true;
			};
			window.gameUnlockSpell = function(word) {
				if (!window._godotSpellUnlockQueue) window._godotSpellUnlockQueue = [];
				window._godotSpellUnlockQueue.push(word);
				return true;
			};
			window.gameCastSpell = function(word) {
				if (!window._godotSpellCastQueue) window._godotSpellCastQueue = [];
				window._godotSpellCastQueue.push(word);
				return true;
			};
			window.gameTestAddDots = function(count) {
				if (!window._godotTestDotsQueue) window._godotTestDotsQueue = 0;
				window._godotTestDotsQueue += count;
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
	var json_str: Variant = JavaScriptBridge.eval("JSON.stringify(window._godotSelectCardQueue || [])")
	JavaScriptBridge.eval("window._godotSelectCardQueue = [];")
	return _parse_string_array(json_str)

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
	JavaScriptBridge.eval("window.gameCombatLogAll = window.gameCombatLogAll || []; window.gameCombatLogAll.push(" + JSON.stringify(entry) + ");")

func push_spell_snapshot() -> void:
	if not _is_web():
		return
	var spells: Array = SpellData.get_all_spells().values()
	var snapshot: Array = []
	for s: Dictionary in spells:
		var word: String = String(s.get("word", ""))
		snapshot.append({
			"word": word,
			"letters": s.get("letters", []),
			"multiplier": s.get("multiplier", 1.0),
			"effect": s.get("effect", ""),
			"type": s.get("type", ""),
			"unlock_cost": s.get("unlock_cost", 0),
			"unlocked": SpellData.is_unlocked(word),
			"can_cast": SpellData.can_cast(word),
			"power": SpellData.calculate_power(word)
		})
	JavaScriptBridge.eval("window.gameSpells = " + JSON.stringify(snapshot) + ";")

func drain_test_combat_queue() -> Array:
	"""Returns test-combat requests queued by Puppeteer via window.gameStartTestCombat."""
	if not _is_web():
		return []
	var json_str: Variant = JavaScriptBridge.eval("JSON.stringify(window._godotTestCombatQueue || [])")
	JavaScriptBridge.eval("window._godotTestCombatQueue = [];")
	var parsed: Array = _parse_json_array(json_str)
	var result: Array = []
	for item: Variant in parsed:
		var d: Dictionary = item
		result.append({
			"name": String(d.get("name", "TestFoe")),
			"hp": int(d.get("hp", BookwarConst.ENEMY_DEFAULT_HP)),
			"letters": _to_string_array(d.get("letters", []))
		})
	return result

func drain_test_letter_queue() -> Array:
	"""Returns letters queued by Puppeteer via window.gameTestAddLetter."""
	if not _is_web():
		return []
	var json_str: Variant = JavaScriptBridge.eval("JSON.stringify(window._godotTestLetterQueue || [])")
	JavaScriptBridge.eval("window._godotTestLetterQueue = [];")
	return _parse_string_array(json_str)

func drain_test_dots() -> int:
	"""Returns dots queued by Puppeteer via window.gameTestAddDots (cumulative)."""
	if not _is_web():
		return 0
	var queued: Variant = JavaScriptBridge.eval("window._godotTestDotsQueue || 0")
	JavaScriptBridge.eval("window._godotTestDotsQueue = 0;")
	if queued == null:
		return 0
	return int(queued)

func consume_test_dialogue() -> bool:
	"""Returns true if Puppeteer requested a forced dialogue via window.gameTestStartDialogue."""
	if not _is_web():
		return false
	var flag: Variant = JavaScriptBridge.eval("(window._godotTestDialogue === true) ? 1 : 0")
	JavaScriptBridge.eval("window._godotTestDialogue = false;")
	return int(flag) == 1

func drain_spell_unlock_queue() -> Array:
	if not _is_web():
		return []
	var json_str: Variant = JavaScriptBridge.eval("JSON.stringify(window._godotSpellUnlockQueue || [])")
	JavaScriptBridge.eval("window._godotSpellUnlockQueue = [];")
	return _parse_string_array(json_str)

func drain_spell_cast_queue() -> Array:
	if not _is_web():
		return []
	var json_str: Variant = JavaScriptBridge.eval("JSON.stringify(window._godotSpellCastQueue || [])")
	JavaScriptBridge.eval("window._godotSpellCastQueue = [];")
	return _parse_string_array(json_str)

func _escape_js(s: String) -> String:
	return s.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "\\n").replace("\r", "")

# --- JSON helpers for draining JS queues (eval cannot return JS arrays/objects directly) ---

func _parse_json_array(json_str: Variant) -> Array:
	if json_str == null:
		return []
	var s: String = str(json_str)
	if s == "" or s == "null":
		return []
	var json: JSON = JSON.new()
	if json.parse(s) != OK:
		return []
	var data: Variant = json.get_data()
	if data is Array:
		return data
	return []

func _parse_string_array(json_str: Variant) -> Array:
	var parsed: Array = _parse_json_array(json_str)
	var result: Array = []
	for item: Variant in parsed:
		result.append(str(item))
	return result

func _to_string_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item: Variant in value:
			result.append(str(item))
	return result
