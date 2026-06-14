extends CharacterBody2D
class_name Player

const MOVE_SPEED: float = 200.0
const INTERACT_RANGE: float = 200.0

var _nearest_interactable: Interactable = null
var _interactables_in_range: Array[Interactable] = []

signal player_interacted

@onready var _interaction_area: Area2D = $InteractionArea

func _ready() -> void:
	_interaction_area.body_entered.connect(_on_area_entered)
	_interaction_area.area_entered.connect(_on_interactable_entered)
	_interaction_area.area_exited.connect(_on_interactable_exited)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameTriggerDialogue = function() { window._godotDialogue = true; };")

func _physics_process(_delta: float) -> void:
	var direction: Vector2 = Vector2.ZERO
	direction.x = Input.get_axis("move_left", "move_right")
	direction.y = Input.get_axis("move_up", "move_down")

	if direction != Vector2.ZERO:
		direction = direction.normalized()

	velocity = direction * MOVE_SPEED
	move_and_slide()
	_poll_js_bridge()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_try_interact()
	if event.is_action_pressed("open_dialogue"):
		_try_dialogue()

func _try_interact() -> void:
	if _nearest_interactable != null:
		_nearest_interactable.interact()
		_nearest_interactable = null
		_update_nearest_interactable()

func _try_dialogue() -> void:
	for body: Node2D in _interaction_area.get_overlapping_bodies():
		if body is MonsterBase:
			var monster: MonsterBase = body as MonsterBase
			if monster.can_dialogue() and InventoryManager.has_ellipsis():
				monster.start_dialogue()
				return

func _on_area_entered(body: Node2D) -> void:
	# Player entering monster's general area. Monsters have their own DetectionArea for vision,
	# but we also call on_player_detected for back-compat (covers scenes where DetectionArea is missing).
	if body is MonsterBase:
		var monster: MonsterBase = body as MonsterBase
		monster.on_player_detected(self)

func _on_interactable_entered(area: Area2D) -> void:
	if area is Interactable:
		_interactables_in_range.append(area)
		_update_nearest_interactable()

func _on_interactable_exited(area: Area2D) -> void:
	if area is Interactable:
		_interactables_in_range.erase(area)
		_update_nearest_interactable()

func _update_nearest_interactable() -> void:
	var closest: Interactable = null
	var closest_dist: float = INTERACT_RANGE
	for interactable: Interactable in _interactables_in_range:
		var dist: float = global_position.distance_to(interactable.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = interactable
	_nearest_interactable = closest

func _poll_js_bridge() -> void:
	if not OS.has_feature("web"):
		return
	if JavaScriptBridge.eval("typeof window._godotDialogue !== 'undefined' && window._godotDialogue"):
		JavaScriptBridge.eval("window._godotDialogue = false;")
		_try_dialogue()

