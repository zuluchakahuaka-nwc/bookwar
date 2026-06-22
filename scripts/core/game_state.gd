extends Node

var current_region: String = BookwarConst.DEFAULT_REGION
var current_map_id: String = BookwarConst.MAP_LIGHT_VALLEY
var player_hp: int = BookwarConst.PLAYER_MAX_HP
var player_max_hp: int = BookwarConst.PLAYER_MAX_HP
var story_flags: Dictionary = {}
var is_in_combat: bool = false
var is_in_dialogue: bool = false
var is_paused: bool = false
var player_hidden: bool = false
var combat_cooldown: float = 0.0
var dialogue_text: String = ""
var dialogue_start_time: float = 0.0

var recruits: Array[Dictionary] = []
var selected_hero: Dictionary = {}  # chosen hero from character select screen
var saved_player_position: Vector2 = Vector2(-1.0, -1.0)
# Persisted monster state across battle scene reloads: key (monster_id@x,y) -> {allegiance, alive}
var monster_overrides: Dictionary = {}
# Persisted collected items across battle scene reloads: key (map:index) -> true
var collected_items: Dictionary = {}
var recruit_force_result: int = -1  # -1 random, 0 force fail, 1 force success (test hook)

# Combat transition state — set by request_combat, consumed by battle scene
var pending_combat_monster_id: String = ""
var pending_combat_monster_name: String = ""
var pending_combat_monster_hp: int = 0
var pending_combat_monster_letters: Array = []

signal hp_changed(current: int, maximum: int)
signal region_changed(region_id: String)
signal combat_started
signal combat_ended(player_won: bool)
signal dialogue_started
signal dialogue_ended
signal dialogue_text_set(text: String)
signal dialogue_advance
signal recruit_message(text: String)
signal combat_requested(monster_id: String, monster_name: String, enemy_hp: int, enemy_letters: Array)
signal recruit_added(recruit: Dictionary)
signal recruit_removed(index: int)

func _ready() -> void:
	_apply_custom_font()

func _apply_custom_font() -> void:
	# Clean, highly-readable font with full Cyrillic + Latin coverage (replaces the
	# hard-to-read decorative RuslanDisplay that also lacked many glyphs/emoji).
	var font_path: String = "res://assets/fonts/RussoOne-Regular.ttf"
	if not ResourceLoader.exists(font_path):
		if OS.has_feature("web"):
			JavaScriptBridge.eval("window.gameFontError = 'font_not_found: " + font_path + "';")
		return
	var font: Font = load(font_path) as Font
	if font == null:
		if OS.has_feature("web"):
			JavaScriptBridge.eval("window.gameFontError = 'load_failed_null';")
		return
	var theme: Theme = Theme.new()
	theme.set_font("font", "Label", font)
	theme.set_font("font", "Button", font)
	theme.set_font("font", "LineEdit", font)
	theme.set_font("font", "RichTextLabel", font)
	theme.set_font("font", "CheckBox", font)
	theme.set_font("font", "OptionButton", font)
	theme.set_font_size("font_size", "Label", 18)
	theme.set_font_size("font_size", "Button", 18)
	get_tree().root.set("theme", theme)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameFontApplied = true;")

func set_region(region_id: String) -> void:
	if current_region != region_id:
		current_region = region_id
		region_changed.emit(region_id)

func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	player_hp = max(0, player_hp - amount)
	hp_changed.emit(player_hp, player_max_hp)

func heal(amount: int) -> void:
	if amount <= 0:
		return
	player_hp = min(player_max_hp, player_hp + amount)
	hp_changed.emit(player_hp, player_max_hp)

func set_story_flag(flag: String, value: Variant = true) -> void:
	story_flags[flag] = value

func has_story_flag(flag: String) -> bool:
	return story_flags.get(flag, false)

func request_combat(monster_id: String, monster_name: String, enemy_hp: int, enemy_letters: Array) -> void:
	# Emit a request — world_map listens and transitions to battle scene
	if is_in_combat:
		return
	combat_requested.emit(monster_id, monster_name, enemy_hp, enemy_letters)

func set_pending_combat(monster_id: String, monster_name: String, enemy_hp: int, enemy_letters: Array) -> void:
	pending_combat_monster_id = monster_id
	pending_combat_monster_name = monster_name
	pending_combat_monster_hp = enemy_hp
	pending_combat_monster_letters = enemy_letters.duplicate()

func clear_pending_combat() -> void:
	pending_combat_monster_id = ""
	pending_combat_monster_name = ""
	pending_combat_monster_hp = 0
	pending_combat_monster_letters.clear()

func start_combat() -> void:
	is_in_combat = true
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameInCombat = true;")
	combat_started.emit()

func end_combat(player_won: bool = false) -> void:
	is_in_combat = false
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameInCombat = false;")
	combat_ended.emit(player_won)

func start_dialogue() -> void:
	is_in_dialogue = true
	dialogue_start_time = Time.get_ticks_msec() / 1000.0
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameDialogueActive = true;")
	dialogue_started.emit()

func end_dialogue() -> void:
	is_in_dialogue = false
	dialogue_text = ""
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameDialogueActive = false;")
	dialogue_ended.emit()

func set_dialogue_text(text: String) -> void:
	dialogue_text = text
	if OS.has_feature("web"):
		var escaped: String = text.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "\\n")
		JavaScriptBridge.eval("window.gameDialogueText = '" + escaped + "';")
	dialogue_text_set.emit(text)

func is_player_alive() -> bool:
	return player_hp > 0

func add_recruit(recruit_name: String, letters: Array, recruit_hp: int) -> void:
	var recruit: Dictionary = {
		"name": recruit_name,
		"letters": letters.duplicate(),
		"hp": recruit_hp,
		"max_hp": recruit_hp
	}
	recruits.append(recruit)
	recruit_added.emit(recruit)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameRecruitCount = " + str(recruits.size()) + ";")

func remove_recruit(index: int) -> void:
	if index >= 0 and index < recruits.size():
		recruits.remove_at(index)
		recruit_removed.emit(index)
		if OS.has_feature("web"):
			JavaScriptBridge.eval("window.gameRecruitCount = " + str(recruits.size()) + ";")

func has_recruits() -> bool:
	return recruits.size() > 0

func get_recruit_count() -> int:
	return recruits.size()

func get_strongest_recruit() -> Dictionary:
	if recruits.is_empty():
		return {}
	var best: Dictionary = recruits[0]
	var best_power: int = 0
	for r: Dictionary in recruits:
		var power: int = 0
		for l: String in r.get("letters", []):
			power += AlphabetData.get_base_power(l)
		if power > best_power:
			best_power = power
			best = r
	return best

func remove_strongest_recruit() -> String:
	if recruits.is_empty():
		return ""
	var best_idx: int = 0
	var best_power: int = -1
	for i: int in range(recruits.size()):
		var power: int = 0
		for l: String in recruits[i].get("letters", []):
			power += AlphabetData.get_base_power(l)
		if power > best_power:
			best_power = power
			best_idx = i
	var name: String = recruits[best_idx].get("name", "")
	recruits.remove_at(best_idx)
	recruit_removed.emit(best_idx)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameRecruitCount = " + str(recruits.size()) + ";")
	return name

func remove_weakest_recruit() -> String:
	# War attrition: the weakest ally falls. Returns their name, or "" if none.
	if recruits.is_empty():
		return ""
	var worst_idx: int = 0
	var worst_power: int = 999999
	for i: int in range(recruits.size()):
		var power: int = 0
		for l: String in recruits[i].get("letters", []):
			power += AlphabetData.get_base_power(l)
		if power < worst_power:
			worst_power = power
			worst_idx = i
	var wname: String = recruits[worst_idx].get("name", "")
	recruits.remove_at(worst_idx)
	recruit_removed.emit(worst_idx)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameRecruitCount = " + str(recruits.size()) + ";")
	return wname

func reset() -> void:
	current_region = BookwarConst.DEFAULT_REGION
	current_map_id = BookwarConst.MAP_LIGHT_VALLEY
	player_hp = player_max_hp
	story_flags.clear()
	is_in_combat = false
	is_in_dialogue = false
	recruits.clear()
	monster_overrides.clear()
	collected_items.clear()
	clear_pending_combat()
	# Keep selected_hero across resets (so restart uses same hero)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameInCombat = false; window.gameDialogueActive = false; window.gameRecruitCount = 0;")

# --- Monster state persistence across battle scene reloads ---
func save_monster_override(key: String, allegiance: int, alive: bool) -> void:
	monster_overrides[key] = {"allegiance": allegiance, "alive": alive}

func get_monster_override(key: String) -> Dictionary:
	return monster_overrides.get(key, {})

# --- Collected-item persistence across battle scene reloads ---
func mark_item_collected(key: String) -> void:
	collected_items[key] = true

func is_item_collected(key: String) -> bool:
	return collected_items.has(key)
