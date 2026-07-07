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

# Data-driven spawner for levels 4–33 (escalating difficulty). The final level
# (33, "Колодец Букв") is a mass battle — a crowd of ? scouts vs an army of !
# enemies, plus the wizard's lieutenants (Знак, Звук) and the final boss
# Хранитель Запрета (evil wizard, keeper_of_ban). Counts and monster tiers
# scale with the level index, so difficulty ramps smoothly from 1 to 33.
func setup_generic(map_id: String) -> void:
	var p: Vector2 = BookwarConst.PLAYER_START_GENERIC
	var q_scene: PackedScene = preload("res://scenes/characters/monsters/question_monster.tscn")
	var e_scene: PackedScene = preload("res://scenes/characters/monsters/exclamation_monster.tscn")
	var idx: int = BookwarConst.get_level_index(map_id)
	if idx < 0:
		idx = 3
	var count: int = BookwarConst.get_map_enemy_count(map_id)
	var is_final: bool = BookwarConst.is_final_level(map_id)
	_spawn_points = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(map_id)
	var e_pool: Array[String] = _enemy_pool_for_level(idx)
	# More ? scouts early; late levels are mostly ! armies. Final level = crowd vs crowd.
	var q_ratio: float = clampf(0.35 - float(idx) * 0.008, 0.10, 0.35)
	if is_final:
		q_ratio = 0.45  # mass battle: big crowd of ? meets big army of !
	var ring: int = 0
	for i: int in range(count):
		var angle: float = rng.randf_range(0.0, TAU)
		var dist: float = 300.0 + float(ring) * 120.0 + rng.randf_range(-30.0, 70.0)
		var pos: Vector2 = Vector2(p.x + cos(angle) * dist, p.y + sin(angle) * dist)
		if rng.randf() < q_ratio:
			_spawn_points.append({"scene": q_scene, "pos": pos})
		else:
			var mid: String = String(e_pool[rng.randi() % e_pool.size()])
			_spawn_points.append({"scene": e_scene, "pos": pos, "monster_id": mid})
		ring = (ring + 1) % 9
	# Lieutenants (Знак + Звук) from the pre-final level onward.
	for lt: String in BookwarConst.get_lieutenants(map_id):
		var ang: float = rng.randf_range(0.0, TAU)
		var lt_pos: Vector2 = Vector2(p.x + cos(ang) * 950.0, p.y + sin(ang) * 950.0)
		_spawn_points.append({"scene": e_scene, "pos": lt_pos, "monster_id": lt})
	# Final boss: the evil wizard (Хранитель Запрета) — deep north of the start.
	if is_final:
		_spawn_points.append({"scene": e_scene, "pos": Vector2(p.x, p.y - 1050.0), "monster_id": BookwarConst.get_final_boss_id(), "boss": true, "boss_id": BookwarConst.get_final_boss_id()})
	_spawn_all()

# Monster-id pool for the ! army on a given 0-based level index. Tiers escalate:
# early = beasts, mid = shadow/dark wolves, late = elite + wizard's minions.
# §18.5: named creatures per region (longtongue/big_ears/big_eyes/big_mouth)
# are mixed in for levels 2-5 (idx 1-4) to give each map a unique feel.
static func _enemy_pool_for_level(idx: int) -> Array[String]:
	match idx:
		1:  # Карта 2: Лес Двубуквия — Longtongue
			return ["longtongue", "forest_creature", "exclamation"]
		2:  # Карта 3: Дремучие Дубы — Big Ears (Слушач)
			return ["big_ears", "forest_creature", "dark_wolf"]
		3:  # Карта 4: Мшистое Низовье — Big Eyes (Зрячий)
			return ["big_eyes", "shadow_lurker", "dark_wolf"]
		4:  # Карта 5: Гнилые Болота — Big Mouth (Жор)
			return ["big_mouth", "shadow_lurker", "forest_creature"]
	if idx <= 8:
		return ["forest_creature", "dark_wolf", "exclamation"]
	if idx <= 15:
		return ["dark_wolf", "shadow_lurker", "forest_creature"]
	if idx <= 22:
		return ["shadow_lurker", "dark_wolf", "forest_creature"]
	return ["shadow_lurker", "dark_wolf", "znak", "zvuk"]

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
			# Boss override: use the explicit boss_id when provided (final wizard),
			# otherwise fall back to the mid-game boss (two_tongue).
			var bid: String = String(spawn.get("boss_id", "two_tongue"))
			monster.set("monster_id", bid)
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
