extends Node2D
class_name BattleManager

var _combat_system: CombatSystem = null
var _enemy_name: String = ""
var _enemy_letters: Array[String] = []
var _selected_card_index: int = -1

signal battle_ui_update(player_hp: int, enemy_hp: int, enemy_name: String)

func _ready() -> void:
	_combat_system = CombatSystem.new()
	add_child(_combat_system)
	_combat_system.damage_dealt.connect(_on_damage_dealt)
	_combat_system.combat_ended.connect(_on_combat_ended)
	_combat_system.card_played.connect(_on_card_played)

func start_battle(enemy_name: String, enemy_hp: int, enemy_letters: Array[String]) -> void:
	_enemy_name = enemy_name
	_enemy_letters = enemy_letters
	_combat_system.start_combat(enemy_name, enemy_hp, enemy_letters)

func select_card(letter_char: String) -> void:
	_combat_system.play_card(letter_char)

func confirm_turn() -> void:
	_play_enemy_ai()
	_combat_system.resolve_turn()

func _play_enemy_ai() -> void:
	if _enemy_letters.size() > 0:
		var letter: String = _enemy_letters[randi() % _enemy_letters.size()]
		_combat_system.play_enemy_card(letter, 1)
	else:
		_combat_system.play_enemy_card("Я", 1)

func _on_damage_dealt(target: String, amount: float) -> void:
	battle_ui_update.emit(
		_combat_system.get_player_hp(),
		_combat_system.get_enemy_hp(),
		_enemy_name
	)

func _on_combat_ended(player_won: bool) -> void:
	if player_won:
		pass
	battle_ui_update.emit(
		_combat_system.get_player_hp(),
		_combat_system.get_enemy_hp(),
		_enemy_name
	)

func _on_card_played(card: Dictionary) -> void:
	pass
