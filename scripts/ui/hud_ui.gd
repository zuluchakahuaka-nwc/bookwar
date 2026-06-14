extends CanvasLayer
class_name HUDUI

@onready var _hp_label: Label = $HPLabel
@onready var _dots_label: Label = $DotsLabel
@onready var _region_label: Label = $RegionLabel
@onready var _ellipsis_label: Label = $EllipsisLabel
@onready var _interaction_label: Label = $InteractionLabel

func _ready() -> void:
	GameState.hp_changed.connect(_on_hp_changed)
	InventoryManager.dots_changed.connect(_on_dots_changed)
	InventoryManager.ellipsis_created.connect(_on_ellipsis_created)
	_on_hp_changed(GameState.player_hp, GameState.player_max_hp)
	_on_dots_changed(InventoryManager.get_dots())
	_interaction_label.visible = false

func _on_hp_changed(current: int, maximum: int) -> void:
	var text: String = "HP: " + str(current) + "/" + str(maximum)
	if _hp_label:
		_hp_label.text = text
	

func _on_dots_changed(count: int) -> void:
	var text: String = ".: " + str(count)
	if _dots_label:
		_dots_label.text = text

func _on_ellipsis_created(_count: int) -> void:
	if _ellipsis_label:
		_ellipsis_label.text = "...: " + str(InventoryManager.get_punctuation_count("..."))
		_ellipsis_label.visible = true

func show_interaction_hint(text: String) -> void:
	if _interaction_label:
		_interaction_label.text = text
		_interaction_label.visible = true

func hide_interaction_hint() -> void:
	if _interaction_label:
		_interaction_label.visible = false
