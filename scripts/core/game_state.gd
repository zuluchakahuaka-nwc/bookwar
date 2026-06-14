extends Node

const PLAYER_MAX_HP_DEFAULT: int = 100
const DEFAULT_REGION: String = "light_valley"

var current_region: String = DEFAULT_REGION
var player_hp: int = PLAYER_MAX_HP_DEFAULT
var player_max_hp: int = PLAYER_MAX_HP_DEFAULT
var story_flags: Dictionary = {}
var is_in_combat: bool = false
var is_in_dialogue: bool = false

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
signal combat_requested(monster_id: String, monster_name: String, enemy_hp: int, enemy_letters: Array)

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
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameDialogueActive = true;")
	dialogue_started.emit()

func end_dialogue() -> void:
	is_in_dialogue = false
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameDialogueActive = false;")
	dialogue_ended.emit()

func is_player_alive() -> bool:
	return player_hp > 0

func reset() -> void:
	current_region = DEFAULT_REGION
	player_hp = player_max_hp
	story_flags.clear()
	is_in_combat = false
	is_in_dialogue = false
	clear_pending_combat()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameInCombat = false; window.gameDialogueActive = false;")
