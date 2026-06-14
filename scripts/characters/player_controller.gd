extends Node
class_name PlayerController

var _touch_active: bool = false
var _touch_position: Vector2 = Vector2.ZERO

@export var player: Player = null

func _process(_delta: float) -> void:
	if _touch_active and player != null:
		var direction: Vector2 = (_touch_position - player.global_position).normalized()
		if player.global_position.distance_to(_touch_position) < 10.0:
			_touch_active = false

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			_touch_active = true
			_touch_position = touch.position
		else:
			_touch_active = false
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		_touch_position = drag.position
