extends CharacterBody2D
class_name MonsterBase

@export var monster_id: String = ""
@export var monster_name: String = ""
@export var hp: int = 30
@export var max_hp: int = 30
@export var move_speed: float = 50.0
@export var detection_radius: float = 100.0
@export var attack_radius: float = 50.0
@export var behavior: String = "patrol"
@export var is_aggressive_flag: bool = false

var _state: String = "idle"
var _patrol_points: Array[Vector2] = []
var _current_patrol_index: int = 0
var _player_ref: Player = null
var _dialogue_data: Array = []
var _drop_table: Array = []
var _letters: Array = []
var _last_combat_time: float = -100.0
var _suspicion_decay: float = 0.0

signal monster_died(monster: MonsterBase)
signal state_changed(new_state: String)
signal detected_player(player: Node2D)

func _ready() -> void:
	_load_monster_data()
	_state = behavior
	_setup_patrol()
	# Wire DetectionArea if present in scene (currently missing in tscn — fallback to player area)
	var detection: Area2D = get_node_or_null("DetectionArea")
	if detection:
		# Resize the collision shape at runtime so we respect exported detection_radius
		_ensure_detection_shape(detection)
		detection.body_entered.connect(_on_detection_body_entered)
		detection.body_exited.connect(_on_detection_body_exited)

func _ensure_detection_shape(detection: Area2D) -> void:
	var shape_node: CollisionShape2D = detection.get_node_or_null("DetectionCollision")
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = "DetectionCollision"
		detection.add_child(shape_node)
	if shape_node.shape == null:
		shape_node.shape = CircleShape2D.new()
	if shape_node.shape is CircleShape2D:
		(shape_node.shape as CircleShape2D).radius = detection_radius

func _load_monster_data() -> void:
	var file: FileAccess = FileAccess.open("res://data/monsters.json", FileAccess.READ)
	if file == null:
		return
	var json: JSON = JSON.new()
	var err: int = json.parse(file.get_as_text())
	if err != OK:
		return
	var data: Variant = json.get_data()
	if not data is Dictionary:
		return
	var data_dict: Dictionary = data
	var monsters_arr: Variant = data_dict.get("monsters", [])
	for monster: Variant in monsters_arr:
		var monster_dict: Dictionary = monster
		var mid: String = str(monster_dict.get("id", ""))
		if mid == monster_id:
			monster_name = monster_dict.get("name", monster_name)
			hp = monster_dict.get("hp", hp)
			max_hp = hp
			move_speed = float(monster_dict.get("speed", move_speed))
			detection_radius = float(monster_dict.get("detection_radius", detection_radius))
			attack_radius = float(monster_dict.get("attack_radius", attack_radius))
			behavior = monster_dict.get("behavior", behavior)
			is_aggressive_flag = behavior == "aggressive"
			_dialogue_data = monster_dict.get("dialogue_options", [])
			_drop_table = monster_dict.get("drop_table", [])
			_letters = []
			for l: Variant in monster_dict.get("letters", []):
				_letters.append(str(l))
			break

func _setup_patrol() -> void:
	var center: Vector2 = global_position
	_patrol_points = [
		center + Vector2(-80.0, 0.0),
		center + Vector2(80.0, 0.0),
		center + Vector2(0.0, -80.0),
		center + Vector2(0.0, 80.0)
	]

func _physics_process(delta: float) -> void:
	match _state:
		"patrol", "idle":
			_process_patrol(delta)
		"aggressive":
			_process_patrol(delta)
		"suspicion":
			_process_suspicion(delta)
		"chase":
			_process_chase(delta)
		"dialogue", "dead":
			pass

func _process_patrol(_delta: float) -> void:
	if _patrol_points.size() == 0:
		return
	var target: Vector2 = _patrol_points[_current_patrol_index]
	var direction: Vector2 = (target - global_position).normalized()
	velocity = direction * move_speed
	move_and_slide()
	if global_position.distance_to(target) < 5.0:
		_current_patrol_index = (_current_patrol_index + 1) % _patrol_points.size()

func _process_suspicion(delta: float) -> void:
	# ? monster: pause and look around, decay back to patrol if player escapes
	velocity = Vector2.ZERO
	_suspicion_decay -= delta
	if _suspicion_decay <= 0.0:
		_set_state("patrol")

func _process_chase(_delta: float) -> void:
	if _player_ref == null or not is_instance_valid(_player_ref):
		_set_state(behavior)
		return
	var direction: Vector2 = (_player_ref.global_position - global_position).normalized()
	velocity = direction * move_speed * 1.5
	move_and_slide()
	if global_position.distance_to(_player_ref.global_position) <= attack_radius:
		_try_attack()

func _set_state(new_state: String) -> void:
	if _state == new_state:
		return
	_state = new_state
	state_changed.emit(_state)

func _on_detection_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_ref = body
		detected_player.emit(body)
		if is_aggressive_flag:
			# ! monster: enter chase immediately
			_set_state("chase")
		else:
			# ? monster: if the player can speak, auto-start dialogue (no need to press T)
			if can_dialogue() and InventoryManager.has_ellipsis() and not GameState.is_in_combat and not GameState.is_in_dialogue:
				start_dialogue()
			else:
				_set_state("suspicion")
				_suspicion_decay = 2.5

func _on_detection_body_exited(body: Node2D) -> void:
	if body is Player and _state == "chase":
		# Lost track — return to patrol
		_set_state(behavior)
		_player_ref = null

# Public entry point called by player.gd when the player's interaction area overlaps
func on_player_detected(player: Player) -> void:
	_on_detection_body_entered(player)

func can_dialogue() -> bool:
	return _dialogue_data.size() > 0

func start_dialogue() -> void:
	if _dialogue_data.size() > 0 and InventoryManager.use_ellipsis():
		_set_state("dialogue")
		GameState.start_dialogue()
		var first_line: Dictionary = _dialogue_data[0]
		var text: String = first_line.get("text", "")
		if text != "":
			GameState.set_dialogue_text(text)

func advance_dialogue() -> void:
	# Simplified: monster dialogue ends after first interaction
	end_dialogue()

func end_dialogue() -> void:
	GameState.end_dialogue()
	_set_state(behavior)

func _set_dialogue_text(text: String) -> void:
	GameState.set_dialogue_text(text)

func _try_attack() -> void:
	if _player_ref == null or not is_instance_valid(_player_ref):
		return
	# Throttle combat requests — don't fire 60/sec
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_combat_time < BookwarConst.COMBAT_COOLDOWN_SEC:
		return
	if GameState.is_in_combat:
		return
	_last_combat_time = now
	# Hand off to world_map via GameState.request_combat
	var enemy_letters_copy: Array = _letters.duplicate()
	GameState.request_combat(monster_id, monster_name, hp, enemy_letters_copy)

func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	hp = max(0, hp - amount)
	if hp <= 0:
		_die()

func _die() -> void:
	_set_state("dead")
	_drop_loot()
	monster_died.emit(self)
	queue_free()

func _drop_loot() -> void:
	for drop: Dictionary in _drop_table:
		if randf() <= float(drop.get("chance", 0.0)):
			var item: String = drop.get("item", "")
			var count: int = int(drop.get("count", 1))
			for i: int in range(count):
				match item:
					"dot":
						InventoryManager.add_dots(1)
					"letter":
						if _letters.size() > 0:
							InventoryManager.add_letter(_letters[randi() % _letters.size()])

func get_state() -> String:
	return _state

func get_snapshot() -> Dictionary:
	return {
		"id": monster_id,
		"name": monster_name,
		"state": _state,
		"hp": hp,
		"max_hp": max_hp,
		"behavior": behavior,
		"is_aggressive": is_aggressive_flag,
		"letters": _letters.duplicate(),
		"position": {"x": global_position.x, "y": global_position.y}
	}
