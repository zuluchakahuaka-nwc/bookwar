extends Node

const VOWEL_MULTIPLIER: float = 1.0
const CONSONANT_MULTIPLIER: float = 1.0
const SIGN_MULTIPLIER: float = 1.5
const EXPECTED_LETTER_COUNT: int = 33

var _letters: Dictionary = {}
var _is_loaded: bool = false

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
	var data: Variant = json.get_data()
	if not data is Dictionary:
		push_error("AlphabetData: letters.json root is not a Dictionary")
		return
	var data_dict: Dictionary = data
	if not data_dict.has("letters"):
		push_error("AlphabetData: missing 'letters' key")
		return
	for letter_data: Variant in data_dict["letters"]:
		var letter_dict: Dictionary = letter_data
		var letter_char: String = letter_dict.get("char", "")
		if letter_char != "":
			_letters[letter_char] = letter_dict
	_is_loaded = true
	data_loaded.emit()

func is_loaded() -> bool:
	return _is_loaded

func get_count() -> int:
	return _letters.size()

func get_letter(letter_char: String) -> Dictionary:
	if _letters.has(letter_char):
		return _letters[letter_char]
	return {}

func get_all_letters() -> Dictionary:
	return _letters

func get_letters_by_type(letter_type: String) -> Array:
	var result: Array = []
	for letter: Dictionary in _letters.values():
		if letter.get("type", "") == letter_type:
			result.append(letter)
	return result

func get_alphabet_snapshot() -> Array:
	var snapshot: Array = []
	for letter: Dictionary in _letters.values():
		snapshot.append({
			"char": letter.get("char", ""),
			"position": letter.get("position", 0),
			"type": letter.get("type", ""),
			"role": letter.get("role", ""),
			"base_power": letter.get("base_power", 0),
			"speed": letter.get("speed", 0)
		})
	snapshot.sort_custom(_compare_position)
	return snapshot

func _compare_position(a: Dictionary, b: Dictionary) -> bool:
	return a.get("position", 0) < b.get("position", 0)

func calculate_damage(letter_char: String, level: int) -> float:
	var letter: Dictionary = get_letter(letter_char)
	if letter.is_empty():
		return 0.0
	var base_power: int = letter.get("base_power", 0)
	match letter.get("type", ""):
		"vowel":
			return float(base_power) * float(level) * VOWEL_MULTIPLIER
		"sign":
			if letter.get("role", "") == "attack_buff":
				return float(base_power) * float(level) * SIGN_MULTIPLIER
			return 0.0
	return 0.0

func calculate_shield(letter_char: String, level: int) -> float:
	var letter: Dictionary = get_letter(letter_char)
	if letter.is_empty():
		return 0.0
	var base_power: int = letter.get("base_power", 0)
	match letter.get("type", ""):
		"consonant":
			return float(base_power) * float(level) * CONSONANT_MULTIPLIER
		"sign":
			if letter.get("role", "") == "defense_buff":
				return float(base_power) * float(level) * SIGN_MULTIPLIER
			return 0.0
	return 0.0

func get_speed(letter_char: String) -> int:
	var letter: Dictionary = get_letter(letter_char)
	if letter.is_empty():
		return 0
	return letter.get("speed", 0)
