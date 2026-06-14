extends Node
class_name CombatSystem

var _player_cards: Array[Dictionary] = []
var _enemy_cards: Array[Dictionary] = []
var _turn_order: Array[Dictionary] = []
var _current_turn_index: int = 0
var _player_hp: int = 100
var _enemy_hp: int = 0
var _enemy_max_hp: int = 0
var _is_active: bool = false

signal combat_started(enemy_name: String)
signal turn_started(card: Dictionary, is_player: bool)
signal damage_dealt(target: String, amount: float)
signal shield_applied(target: String, amount: float)
signal combat_ended(player_won: bool)
signal card_played(card: Dictionary)

func start_combat(enemy_name: String, enemy_hp: int, enemy_letters: Array[String]) -> void:
	_is_active = true
	_player_hp = GameState.player_hp
	_enemy_hp = enemy_hp
	_enemy_max_hp = enemy_hp
	_player_cards.clear()
	_enemy_cards.clear()
	GameState.start_combat()
	combat_started.emit(enemy_name)

func play_card(letter_char: String) -> void:
	if not _is_active:
		return
	var level: int = InventoryManager.get_letter_level(letter_char)
	if level <= 0:
		return
	var letter: Dictionary = AlphabetData.get_letter(letter_char)
	if letter.is_empty():
		return
	var card: Dictionary = {
		"char": letter_char,
		"type": letter["type"],
		"role": letter["role"],
		"speed": letter["speed"],
		"level": level
	}
	_player_cards.append(card)
	card_played.emit(card)

func play_enemy_card(letter_char: String, level: int) -> void:
	var letter: Dictionary = AlphabetData.get_letter(letter_char)
	if letter.is_empty():
		return
	var card: Dictionary = {
		"char": letter_char,
		"type": letter["type"],
		"role": letter["role"],
		"speed": letter["speed"],
		"level": level
	}
	_enemy_cards.append(card)

func resolve_turn() -> void:
	var all_cards: Array[Dictionary] = []
	for card: Dictionary in _player_cards:
		card["is_player"] = true
		all_cards.append(card)
	for card: Dictionary in _enemy_cards:
		card["is_player"] = false
		all_cards.append(card)
	all_cards.sort_custom(_compare_speed)
	_turn_order = all_cards
	_current_turn_index = 0
	_process_next_card()

func _compare_speed(a: Dictionary, b: Dictionary) -> bool:
	return a["speed"] > b["speed"]

func _process_next_card() -> void:
	if _current_turn_index >= _turn_order.size():
		_player_cards.clear()
		_enemy_cards.clear()
		if _enemy_hp <= 0:
			end_combat(true)
		elif _player_hp <= 0:
			end_combat(false)
		return
	var card: Dictionary = _turn_order[_current_turn_index]
	var is_player: bool = card["is_player"]
	turn_started.emit(card, is_player)
	match card["type"]:
		"vowel":
			var damage: float = AlphabetData.calculate_damage(card["char"], card["level"])
			if is_player:
				_enemy_hp -= int(damage)
				damage_dealt.emit("enemy", damage)
			else:
				_player_hp -= int(damage)
				damage_dealt.emit("player", damage)
				GameState.take_damage(int(damage))
		"consonant":
			var shield: float = AlphabetData.calculate_shield(card["char"], card["level"])
			if is_player:
				shield_applied.emit("player", shield)
			else:
				shield_applied.emit("enemy", shield)
		"sign":
			pass
	_current_turn_index += 1
	if _enemy_hp <= 0:
		end_combat(true)
	elif _player_hp <= 0:
		end_combat(false)
	else:
		call_deferred("_process_next_card")

func end_combat(player_won: bool) -> void:
	_is_active = false
	_player_cards.clear()
	_enemy_cards.clear()
	GameState.end_combat()
	combat_ended.emit(player_won)

func is_active() -> bool:
	return _is_active

func get_player_hp() -> int:
	return _player_hp

func get_enemy_hp() -> int:
	return _enemy_hp
