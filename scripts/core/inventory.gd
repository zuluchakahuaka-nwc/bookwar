extends Node

var _letter_levels: Dictionary = {}
var _punctuation: Dictionary = {}
var _dots: int = 0

signal inventory_changed
signal dots_changed(count: int)
signal ellipsis_created
signal letter_acquired(letter_char: String, level: int)

func _ready() -> void:
	_punctuation["."] = 0

func get_dots() -> int:
	return _dots

func add_dots(count: int) -> void:
	_dots += count
	dots_changed.emit(_dots)
	_check_ellipsis()
	inventory_changed.emit()

func use_dots(count: int) -> bool:
	if _dots >= count:
		_dots -= count
		dots_changed.emit(_dots)
		inventory_changed.emit()
		return true
	return false

func has_ellipsis() -> bool:
	return _punctuation.get("...", 0) > 0

func _check_ellipsis() -> void:
	if _dots >= 3:
		_dots -= 3
		if not _punctuation.has("..."):
			_punctuation["..."] = 0
		_punctuation["..."] += 1
		ellipsis_created.emit()
		dots_changed.emit(_dots)

func use_ellipsis() -> bool:
	if _punctuation.get("...", 0) > 0:
		_punctuation["..."] -= 1
		inventory_changed.emit()
		return true
	return false

func add_letter(letter_char: String) -> void:
	if not _letter_levels.has(letter_char):
		_letter_levels[letter_char] = 0
	_letter_levels[letter_char] += 1
	letter_acquired.emit(letter_char, _letter_levels[letter_char])
	inventory_changed.emit()

func remove_letter(letter_char: String) -> bool:
	if _letter_levels.get(letter_char, 0) > 0:
		_letter_levels[letter_char] -= 1
		inventory_changed.emit()
		return true
	return false

func get_letter_level(letter_char: String) -> int:
	return _letter_levels.get(letter_char, 0)

func get_all_letters() -> Dictionary:
	return _letter_levels

func add_punctuation(char: String, count: int = 1) -> void:
	if not _punctuation.has(char):
		_punctuation[char] = 0
	_punctuation[char] += count
	inventory_changed.emit()

func use_punctuation(char: String) -> bool:
	if _punctuation.get(char, 0) > 0:
		_punctuation[char] -= 1
		inventory_changed.emit()
		return true
	return false

func get_punctuation_count(char: String) -> int:
	return _punctuation.get(char, 0)

func get_all_punctuation() -> Dictionary:
	return _punctuation

func has_any_letter() -> bool:
	return _letter_levels.size() > 0
