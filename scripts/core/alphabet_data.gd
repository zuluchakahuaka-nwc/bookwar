extends Node

const VOWEL_MULTIPLIER: float = 1.0
const CONSONANT_MULTIPLIER: float = 1.0
const SIGN_MULTIPLIER: float = 1.5

var _letters: Dictionary = {}

signal data_loaded

func _ready() -> void:
	_load_letters()

func _load_letters() -> void:
	var file: FileAccess = FileAccess.open("res://data/letters.json", FileAccess.READ)
	if file == null:
		push_error("AlphabetData: Failed to open letters.json")
		return
	var json: JSON = JSON.new()
	var err: Error = json.parse(file.get_as_text())
	if err != OK:
		push_error("AlphabetData: Failed to parse letters.json: " + json.get_error_message())
		return
	var data: Dictionary = json.get_data()
	for letter_data: Dictionary in data["letters"]:
		var letter_char: String = letter_data["char"]
		_letters[letter_char] = letter_data
	data_loaded.emit()

func get_letter(letter_char: String) -> Dictionary:
	if _letters.has(letter_char):
		return _letters[letter_char]
	return {}

func get_all_letters() -> Dictionary:
	return _letters

func get_letters_by_type(type: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for letter: Dictionary in _letters.values():
		if letter["type"] == type:
			result.append(letter)
	return result

func calculate_damage(letter_char: String, level: int) -> float:
	var letter: Dictionary = get_letter(letter_char)
	if letter.is_empty():
		return 0.0
	var base_power: int = letter["base_power"]
	match letter["type"]:
		"vowel":
			return base_power * level * VOWEL_MULTIPLIER
		"sign":
			if letter["role"] == "attack_buff":
				return base_power * level * SIGN_MULTIPLIER
			return 0.0
	return 0.0

func calculate_shield(letter_char: String, level: int) -> float:
	var letter: Dictionary = get_letter(letter_char)
	if letter.is_empty():
		return 0.0
	var base_power: int = letter["base_power"]
	match letter["type"]:
		"consonant":
			return base_power * level * CONSONANT_MULTIPLIER
		"sign":
			if letter["role"] == "defense_buff":
				return base_power * level * SIGN_MULTIPLIER
			return 0.0
	return 0.0

func get_speed(letter_char: String) -> int:
	var letter: Dictionary = get_letter(letter_char)
	if letter.is_empty():
		return 0
	return letter["speed"]
