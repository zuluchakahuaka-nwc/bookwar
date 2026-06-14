extends Control
class_name LetterCardUI

@export var letter_char: String = ""

@onready var _char_label: Label = $Background/CharLabel
@onready var _power_label: Label = $Background/PowerLabel
@onready var _level_label: Label = $Background/LevelLabel
@onready var _type_indicator: ColorRect = $Background/TypeIndicator

func setup(char: String) -> void:
	letter_char = char
	var data: Dictionary = AlphabetData.get_letter(char)
	var level: int = InventoryManager.get_letter_level(char)
	if data.is_empty():
		return
	if _char_label:
		_char_label.text = char
	if _power_label:
		_power_label.text = str(data["base_power"] * level)
	if _level_label:
		_level_label.text = "Lv" + str(level)
	if _type_indicator:
		match data["type"]:
			"vowel":
				_type_indicator.color = Color(0.9, 0.3, 0.2)
			"consonant":
				_type_indicator.color = Color(0.3, 0.4, 0.8)
			"sign":
				_type_indicator.color = Color(0.7, 0.5, 0.9)
