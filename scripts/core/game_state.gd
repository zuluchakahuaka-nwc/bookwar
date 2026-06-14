extends Node

var current_region: String = "light_valley"
var player_hp: int = 100
var player_max_hp: int = 100
var story_flags: Dictionary = {}
var is_in_combat: bool = false
var is_in_dialogue: bool = false

signal hp_changed(current: int, maximum: int)
signal region_changed(region_id: String)
signal combat_started
signal combat_ended
signal dialogue_started
signal dialogue_ended

func set_region(region_id: String) -> void:
	if current_region != region_id:
		current_region = region_id
		region_changed.emit(region_id)

func take_damage(amount: int) -> void:
	player_hp = max(0, player_hp - amount)
	hp_changed.emit(player_hp, player_max_hp)

func heal(amount: int) -> void:
	player_hp = min(player_max_hp, player_hp + amount)
	hp_changed.emit(player_hp, player_max_hp)

func set_story_flag(flag: String, value: Variant = true) -> void:
	story_flags[flag] = value

func has_story_flag(flag: String) -> bool:
	return story_flags.get(flag, false)

func start_combat() -> void:
	is_in_combat = true
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameInCombat = true;")
	combat_started.emit()

func end_combat() -> void:
	is_in_combat = false
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameInCombat = false;")
	combat_ended.emit()

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
	current_region = "light_valley"
	player_hp = player_max_hp
	story_flags.clear()
	is_in_combat = false
	is_in_dialogue = false
