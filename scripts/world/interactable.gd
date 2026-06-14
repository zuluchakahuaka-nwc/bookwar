extends Area2D
class_name Interactable

@export var interaction_name: String = ""
@export var item_type: String = ""
@export var item_id: String = ""

signal interacted(interactable: Interactable)

var _is_collected: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if _is_collected:
		return
	if body is Player:
		interacted.emit(self)
		interact()

func interact() -> void:
	if _is_collected:
		return
	_is_collected = true
	match item_type:
		"dot":
			InventoryManager.add_dots(1)
		"letter":
			InventoryManager.add_letter(item_id)
		"punctuation":
			InventoryManager.add_punctuation(item_id)
	queue_free()

func get_display_name() -> String:
	if interaction_name != "":
		return interaction_name
	match item_type:
		"dot":
			return "."
		"letter":
			return item_id
		"punctuation":
			return item_id
	return "???"
