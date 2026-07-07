extends Node
# SaveManager (autoload) — persists game state to browser localStorage on web,
# or to user://save.json on native. Called by GameState/InventoryManager whenever
# state changes (pickup, combat end, dialogue, autosave every 5s).
#
# Save format: a single JSON blob covering all subsystems:
#   { "version": 1, "ts": 1234567890, "game": {...}, "inventory": {...} }
#
# Loading happens on boot — main_menu checks for a save and shows "Продолжить".

const SAVE_KEY: String = "bookwar_save_v1"
const SAVE_PATH: String = "user://save.json"
const AUTOSAVE_INTERVAL: float = 5.0
var _autosave_timer: float = 0.0

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		# Only autosave if we are actually in a game (not menu/intro).
		if GameState.selected_hero.size() > 0:
			save_game()

func has_save() -> bool:
	if OS.has_feature("web"):
		return JavaScriptBridge.eval("(function(){ try { return !!localStorage.getItem('" + SAVE_KEY + "'); } catch(e) { return false; } }())", true)
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	f.close()
	return true

func save_game() -> void:
	var data: Dictionary = {
		"version": 1,
		"ts": Time.get_unix_time_from_system(),
		"game": _serialize_game(),
		"inventory": _serialize_inventory()
	}
	var json_text: String = JSON.stringify(data)
	if OS.has_feature("web"):
		# Write via JS to avoid Godot HTML5 FileAccess quirks.
		var escaped: String = json_text.replace("\\", "\\\\").replace("'", "\\'")
		JavaScriptBridge.eval("(function(){ try { localStorage.setItem('" + SAVE_KEY + "', '" + escaped + "'); } catch(e) { console.warn('save failed:', e); } }());", true)
	else:
		var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f:
			f.store_string(json_text)
			f.close()

func load_game() -> Dictionary:
	var json_text: String = ""
	if OS.has_feature("web"):
		json_text = str(JavaScriptBridge.eval("(function(){ try { return localStorage.getItem('" + SAVE_KEY + "') || ''; } catch(e) { return ''; } }())", true))
	else:
		var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			json_text = f.get_as_text()
			f.close()
	if json_text == "" or json_text == "null":
		return {}
	var json: JSON = JSON.new()
	if json.parse(json_text) != OK:
		return {}
	return json.get_data()

func clear_save() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(function(){ try { localStorage.removeItem('" + SAVE_KEY + "'); } catch(e) {} }());", true)
	else:
		DirAccess.remove_absolute(SAVE_PATH)

# Apply a loaded save to GameState + InventoryManager. Called once on game start
# (either "Continue" from menu, or autosave-on-reload).
func apply_save(data: Dictionary) -> void:
	if data.is_empty():
		return
	var game: Dictionary = data.get("game", {})
	var inv: Dictionary = data.get("inventory", {})
	_apply_game(game)
	_apply_inventory(inv)

func _serialize_game() -> Dictionary:
	return {
		"player_hp": GameState.player_hp,
		"player_max_hp": GameState.player_max_hp,
		"current_map_id": GameState.current_map_id,
		"current_region": GameState.current_region,
		"story_flags": GameState.story_flags,
		"monster_overrides": GameState.monster_overrides,
		"collected_items": GameState.collected_items,
		"recruits": GameState.recruits,
		"selected_hero": GameState.selected_hero,
		"saved_player_position": { "x": GameState.saved_player_position.x, "y": GameState.saved_player_position.y },
		# Q6 (2026-07-07): persist quest progress so reload doesn't lose completed/half-done quests
		"completed_quest_ids": GameState.completed_quest_ids,
		"quest_defeat_progress": GameState.quest_defeat_progress,
		"completed_quests": GameState.completed_quests  # legacy single-quest map_ids
	}

func _serialize_inventory() -> Dictionary:
	return {
		"letters": InventoryManager.get_all_letters(),
		"dots": InventoryManager.get_dots(),
		"punctuation": InventoryManager.get_all_punctuation(),
		"spells_unlocked": InventoryManager.get_unlocked_spells() if InventoryManager.has_method("get_unlocked_spells") else []
	}

func _apply_game(g: Dictionary) -> void:
	if g.has("player_hp"):
		GameState.player_hp = int(g["player_hp"])
	if g.has("player_max_hp"):
		GameState.player_max_hp = int(g["player_max_hp"])
	if g.has("current_map_id"):
		GameState.current_map_id = String(g["current_map_id"])
	if g.has("current_region"):
		GameState.current_region = String(g["current_region"])
	if g.has("story_flags"):
		GameState.story_flags = g["story_flags"]
	if g.has("monster_overrides"):
		GameState.monster_overrides = g["monster_overrides"]
	if g.has("collected_items"):
		GameState.collected_items = g["collected_items"]
	if g.has("recruits"):
		GameState.recruits = g["recruits"]
	if g.has("selected_hero"):
		GameState.selected_hero = g["selected_hero"]
	if g.has("saved_player_position"):
		var p: Dictionary = g["saved_player_position"]
		GameState.saved_player_position = Vector2(float(p.get("x", -1.0)), float(p.get("y", -1.0)))
	# Q6 (2026-07-07): restore quest progress
	if g.has("completed_quest_ids"):
		var ids: Variant = g["completed_quest_ids"]
		if ids is Array:
			GameState.completed_quest_ids.clear()
			for qid: String in ids:
				GameState.completed_quest_ids.append(String(qid))
	if g.has("quest_defeat_progress"):
		var prog: Variant = g["quest_defeat_progress"]
		if prog is Dictionary:
			GameState.quest_defeat_progress = prog.duplicate()
	if g.has("completed_quests"):
		var cq: Variant = g["completed_quests"]
		if cq is Array:
			GameState.completed_quests.clear()
			for mid: String in cq:
				GameState.completed_quests.append(String(mid))

func _apply_inventory(i: Dictionary) -> void:
	# Letters
	var letters: Dictionary = i.get("letters", {})
	for letter_char: String in letters:
		var level: int = int(letters[letter_char])
		# Set directly to the saved level (set_letter_level if available, else add_letter repeatedly).
		if InventoryManager.has_method("set_letter_level"):
			InventoryManager.set_letter_level(letter_char, level)
		else:
			var current: int = InventoryManager.get_letter_level(letter_char)
			while current < level:
				InventoryManager.add_letter(letter_char)
				current += 1
	# Dots
	var dots: int = int(i.get("dots", 0))
	if dots > 0:
		InventoryManager.add_dots(dots)
	# Punctuation
	var punct: Dictionary = i.get("punctuation", {})
	for key: String in punct:
		var count: int = int(punct[key])
		for _n: int in range(count):
			InventoryManager.add_punctuation(key)
