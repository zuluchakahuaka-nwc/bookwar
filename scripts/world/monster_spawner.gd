extends Node2D
class_name MonsterSpawner

var _spawn_points: Array[Dictionary] = []

func setup_light_valley() -> void:
	var p: Vector2 = BookwarConst.PLAYER_START
	var q_scene: PackedScene = preload("res://scenes/characters/monsters/question_monster.tscn")
	var e_scene: PackedScene = preload("res://scenes/characters/monsters/exclamation_monster.tscn")
	# Ring 1 — near start (300-600px): ? monsters only, safe zone
	_spawn_points = [
		{"scene": q_scene, "pos": Vector2(p.x + 350, p.y)},
		{"scene": q_scene, "pos": Vector2(p.x - 200, p.y - 250)},
		{"scene": q_scene, "pos": Vector2(p.x + 450, p.y - 150)},
	]
	# Ring 2 — mid (600-900px): more ? monsters, still safe
	_spawn_points.append_array([
		{"scene": q_scene, "pos": Vector2(p.x + 700, p.y)},
		{"scene": q_scene, "pos": Vector2(p.x + 650, p.y + 200)},
		{"scene": q_scene, "pos": Vector2(p.x - 350, p.y + 350)},
		{"scene": q_scene, "pos": Vector2(p.x - 500, p.y - 100)},
	])
	# Ring 3 — far (900-1300px): ! monsters start here
	_spawn_points.append_array([
		{"scene": e_scene, "pos": Vector2(p.x + 950, p.y - 100)},
		{"scene": e_scene, "pos": Vector2(p.x + 1000, p.y + 100)},
		{"scene": e_scene, "pos": Vector2(p.x - 700, p.y + 400)},
		{"scene": e_scene, "pos": Vector2(p.x - 750, p.y + 200)},
		{"scene": e_scene, "pos": Vector2(p.x + 1100, p.y - 300)},
	])
	# Ring 4 — deep (1300+px): heavy ! squads
	_spawn_points.append_array([
		{"scene": e_scene, "pos": Vector2(p.x + 1400, p.y)},
		{"scene": e_scene, "pos": Vector2(p.x + 1450, p.y + 200)},
		{"scene": e_scene, "pos": Vector2(p.x + 1350, p.y - 200)},
		{"scene": e_scene, "pos": Vector2(p.x - 1000, p.y + 500)},
		{"scene": e_scene, "pos": Vector2(p.x - 1050, p.y + 300)},
	])
	_spawn_all()

func setup_two_letter_forest() -> void:
	var p: Vector2 = BookwarConst.PLAYER_START_FOREST
	var q_scene: PackedScene = preload("res://scenes/characters/monsters/question_monster.tscn")
	var e_scene: PackedScene = preload("res://scenes/characters/monsters/exclamation_monster.tscn")
	var boss_scene: PackedScene = preload("res://scenes/characters/monsters/exclamation_monster.tscn")
	# Ring 1 — near start (250-500px): mix ? and !
	_spawn_points = [
		{"scene": q_scene, "pos": Vector2(p.x + 300, p.y)},
		{"scene": q_scene, "pos": Vector2(p.x - 250, p.y - 100)},
		{"scene": e_scene, "pos": Vector2(p.x + 400, p.y - 200), "monster_id": "forest_creature"},
	]
	# Ring 2 — mid (500-800px): more dense
	_spawn_points.append_array([
		{"scene": e_scene, "pos": Vector2(p.x + 600, p.y + 150), "monster_id": "forest_creature"},
		{"scene": e_scene, "pos": Vector2(p.x - 500, p.y + 250), "monster_id": "forest_creature"},
		{"scene": q_scene, "pos": Vector2(p.x - 350, p.y - 300)},
		{"scene": e_scene, "pos": Vector2(p.x + 550, p.y - 350)},
	])
	# Ring 3 — far (800-1100px): heavy — real beasts here
	_spawn_points.append_array([
		{"scene": e_scene, "pos": Vector2(p.x + 900, p.y - 100), "monster_id": "forest_creature"},
		{"scene": e_scene, "pos": Vector2(p.x + 950, p.y + 200), "monster_id": "forest_creature"},
		{"scene": e_scene, "pos": Vector2(p.x - 800, p.y + 400), "monster_id": "forest_creature"},
		{"scene": q_scene, "pos": Vector2(p.x - 750, p.y - 200)},
	])
	# Ring 4 — deep (1100+px): squads + BOSS + the sorcerer's henchman (Знак)
	_spawn_points.append_array([
		{"scene": e_scene, "pos": Vector2(p.x + 1200, p.y)},
		{"scene": e_scene, "pos": Vector2(p.x + 1250, p.y + 250)},
		{"scene": e_scene, "pos": Vector2(p.x - 1100, p.y + 500)},
		{"scene": boss_scene, "pos": Vector2(p.x + 1300, p.y - 400), "boss": true},
		{"scene": e_scene, "pos": Vector2(p.x - 1250, p.y - 350), "monster_id": "znak"},
	])
	_spawn_all()

func setup_dark_oaks() -> void:
	var p: Vector2 = BookwarConst.PLAYER_START_DARK_OAKS
	var q_scene: PackedScene = preload("res://scenes/characters/monsters/question_monster.tscn")
	var e_scene: PackedScene = preload("res://scenes/characters/monsters/exclamation_monster.tscn")
	# Ring 1 — near start (250-500px): forest creatures + ? scouts
	_spawn_points = [
		{"scene": e_scene, "pos": Vector2(p.x + 300, p.y - 100), "monster_id": "forest_creature"},
		{"scene": q_scene, "pos": Vector2(p.x - 280, p.y + 50)},
		{"scene": e_scene, "pos": Vector2(p.x + 420, p.y - 250), "monster_id": "forest_creature"},
	]
	# Ring 2 — mid (500-800px): denser beasts + dark wolves
	_spawn_points.append_array([
		{"scene": e_scene, "pos": Vector2(p.x + 600, p.y + 200), "monster_id": "dark_wolf"},
		{"scene": e_scene, "pos": Vector2(p.x - 550, p.y + 300), "monster_id": "forest_creature"},
		{"scene": e_scene, "pos": Vector2(p.x - 450, p.y - 350), "monster_id": "shadow_lurker"},
		{"scene": q_scene, "pos": Vector2(p.x + 500, p.y - 400)},
	])
	# Ring 3 — far (800-1100px): heavy squads
	_spawn_points.append_array([
		{"scene": e_scene, "pos": Vector2(p.x + 900, p.y - 150), "monster_id": "dark_wolf"},
		{"scene": e_scene, "pos": Vector2(p.x + 950, p.y + 250), "monster_id": "shadow_lurker"},
		{"scene": e_scene, "pos": Vector2(p.x - 800, p.y + 400), "monster_id": "forest_creature"},
		{"scene": e_scene, "pos": Vector2(p.x - 750, p.y - 200), "monster_id": "dark_wolf"},
	])
	# Ring 4 — deep (1100+px): ЗНАК and ЗВУК — the sorcerer's evil lieutenants
	_spawn_points.append_array([
		{"scene": e_scene, "pos": Vector2(p.x + 1250, p.y - 200), "monster_id": "znak"},
		{"scene": e_scene, "pos": Vector2(p.x + 1300, p.y + 300), "monster_id": "zvuk"},
		{"scene": e_scene, "pos": Vector2(p.x - 1100, p.y + 500), "monster_id": "shadow_lurker"},
		{"scene": e_scene, "pos": Vector2(p.x - 1150, p.y - 300), "monster_id": "dark_wolf"},
	])
	_spawn_all()

func _spawn_all() -> void:
	for spawn: Dictionary in _spawn_points:
		var scene: PackedScene = spawn["scene"]
		var monster: CharacterBody2D = scene.instantiate()
		var pos: Vector2 = _clamp_pos(spawn["pos"])
		monster.global_position = pos
		# Stable spawn id keyed by spawn position (survives battle scene reloads)
		monster.set("spawn_id", "spawn_" + str(int(pos.x)) + "_" + str(int(pos.y)))
		if spawn.has("monster_id"):
			monster.set("monster_id", spawn["monster_id"])
		if spawn.has("boss") and spawn["boss"]:
			monster.set("monster_id", "two_tongue")
		get_parent().call_deferred("add_child", monster)

func spawn_monster(scene: PackedScene, position: Vector2) -> void:
	var monster: CharacterBody2D = scene.instantiate()
	monster.global_position = _clamp_pos(position)
	monster.set("spawn_id", "spawn_" + str(int(position.x)) + "_" + str(int(position.y)))
	get_parent().call_deferred("add_child", monster)

const BOUND_MIN_X: float = 100.0
const BOUND_MAX_X: float = 2460.0
const BOUND_MIN_Y: float = 100.0
const BOUND_MAX_Y: float = 1820.0

func _clamp_pos(pos: Vector2) -> Vector2:
	return Vector2(
		clampf(pos.x, BOUND_MIN_X, BOUND_MAX_X),
		clampf(pos.y, BOUND_MIN_Y, BOUND_MAX_Y)
	)
