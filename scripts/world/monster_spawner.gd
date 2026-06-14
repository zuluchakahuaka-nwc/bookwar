extends Node2D
class_name MonsterSpawner

var _spawn_points: Array[Dictionary] = []

func setup_light_valley() -> void:
	var player_pos: Vector2 = Vector2(1216, 1536)
	_spawn_points = [
		{"scene": preload("res://scenes/characters/monsters/question_monster.tscn"), "pos": Vector2(player_pos.x + 600, player_pos.y)},
		{"scene": preload("res://scenes/characters/monsters/question_monster.tscn"), "pos": Vector2(player_pos.x + 800, player_pos.y - 100)},
		{"scene": preload("res://scenes/characters/monsters/question_monster.tscn"), "pos": Vector2(player_pos.x - 200, player_pos.y - 300)},
		{"scene": preload("res://scenes/characters/monsters/exclamation_monster.tscn"), "pos": Vector2(player_pos.x + 700, player_pos.y + 100)},
		{"scene": preload("res://scenes/characters/monsters/exclamation_monster.tscn"), "pos": Vector2(player_pos.x - 300, player_pos.y + 400)}
	]
	_spawn_all()

func _spawn_all() -> void:
	for spawn: Dictionary in _spawn_points:
		var scene: PackedScene = spawn["scene"]
		var monster: CharacterBody2D = scene.instantiate()
		monster.global_position = spawn["pos"]
		get_parent().call_deferred("add_child", monster)

func spawn_monster(scene: PackedScene, position: Vector2) -> void:
	var monster: CharacterBody2D = scene.instantiate()
	monster.global_position = position
	get_parent().call_deferred("add_child", monster)
