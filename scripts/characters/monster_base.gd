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

signal monster_died(monster: MonsterBase)
signal state_changed(new_state: String)

func _ready() -> void:
	_load_monster_data()
	_state = behavior
	_setup_patrol()

func _load_monster_data() -> void:
	var file: FileAccess = FileAccess.open("res://data/monsters.json", FileAccess.READ)
	if file == null:
		return
	var json: JSON = JSON.new()
	var err: int = json.parse(file.get_as_text())
	if err != OK:
		return
	var data: Dictionary = json.get_data()
	var monsters_arr: Variant = data.get("monsters", [])
	for monster: Dictionary in monsters_arr:
		var mid: String = str(monster.get("id", ""))
		if mid == monster_id:
			monster_name = monster.get("name", "")
			hp = monster.get("hp", 30)
			max_hp = hp
			move_speed = monster.get("speed", 50.0)
			detection_radius = monster.get("detection_radius", 100.0)
			attack_radius = monster.get("attack_radius", 50.0)
			behavior = monster.get("behavior", "patrol")
			is_aggressive_flag = behavior == "aggressive"
			_dialogue_data = monster.get("dialogue_options", [])
			_drop_table = monster.get("drop_table", [])
			_letters = []
			for l: String in monster.get("letters", []):
				_letters.append(l)
			break

func _setup_patrol() -> void:
	var center: Vector2 = global_position
	_patrol_points = [
		center + Vector2(-80, 0),
		center + Vector2(80, 0),
		center + Vector2(0, -80),
		center + Vector2(0, 80)
	]

func _physics_process(delta: float) -> void:
	match _state:
		"patrol":
			_process_patrol(delta)
		"chase":
			_process_chase(delta)
		"idle":
			_process_idle(delta)
		"dialogue":
			pass
		"dead":
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

func _process_chase(_delta: float) -> void:
	if _player_ref == null:
		_state = behavior
		state_changed.emit(_state)
		return
	var direction: Vector2 = (_player_ref.global_position - global_position).normalized()
	velocity = direction * move_speed * 1.5
	move_and_slide()
	if global_position.distance_to(_player_ref.global_position) <= attack_radius:
		_try_attack()

func _process_idle(_delta: float) -> void:
	velocity = Vector2.ZERO

func on_player_detected(player: Player) -> void:
	_player_ref = player
	if is_aggressive_flag:
		_state = "chase"
		state_changed.emit("chase")

func can_dialogue() -> bool:
	return _dialogue_data.size() > 0

func start_dialogue() -> void:
	if _dialogue_data.size() > 0 and InventoryManager.use_ellipsis():
		_state = "dialogue"
		state_changed.emit("dialogue")
		GameState.start_dialogue()
		if _dialogue_data.size() > 0:
			var first_line: Dictionary = _dialogue_data[0]
			var text: String = first_line.get("text", "")
			if OS.has_feature("web") and text != "":
				var escaped: String = text.replace("'", "\\'")
				JavaScriptBridge.eval("window.gameDialogueText = '" + escaped + "';")
				JavaScriptBridge.eval("window.gameDialogueActive = true;")

func _on_dialogue_ended(npc_id: String) -> void:
	if npc_id == monster_id:
		_state = "idle"
		state_changed.emit("idle")

func _try_attack() -> void:
	if _player_ref != null:
		GameState.start_combat()

func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		_die()

func _die() -> void:
	_state = "dead"
	state_changed.emit("dead")
	_drop_loot()
	monster_died.emit(self)
	queue_free()

func _drop_loot() -> void:
	for drop: Dictionary in _drop_table:
		if randf() <= drop.get("chance", 0.0):
			var item: String = drop.get("item", "")
			var count: int = drop.get("count", 1)
			for i: int in range(count):
				match item:
					"dot":
						InventoryManager.add_dots(1)
					"letter":
						if _letters.size() > 0:
							InventoryManager.add_letter(_letters[randi() % _letters.size()])

func get_state() -> String:
	return _state
