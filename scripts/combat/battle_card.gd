extends Control
class_name BattleCard

@export var letter_char: String = ""

var _letter_data: Dictionary = {}
var _level: int = 0

@onready var _char_label: Label = $CharLabel
@onready var _power_label: Label = $PowerLabel
@onready var _type_label: Label = $TypeLabel
@onready var _background: ColorRect = $Background

signal card_selected(letter_char: String)

func _ready() -> void:
	gui_input.connect(_on_gui_input)

func setup(char: String) -> void:
	letter_char = char
	_letter_data = AlphabetData.get_letter(char)
	_level = InventoryManager.get_letter_level(char)
	if _letter_data.is_empty():
		return
	if _char_label:
		_char_label.text = char
	if _power_label:
		var power: int = _letter_data.get("base_power", 0)
		_power_label.text = str(power * _level)
	if _type_label:
		_type_label.text = _letter_data.get("role", "")
	if _background:
		match _letter_data.get("type", ""):
			"vowel":
				_background.color = Color(0.8, 0.3, 0.2, 1.0)
			"consonant":
				_background.color = Color(0.3, 0.4, 0.7, 1.0)
			"sign":
				_background.color = Color(0.6, 0.5, 0.8, 1.0)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			card_selected.emit(letter_char)
