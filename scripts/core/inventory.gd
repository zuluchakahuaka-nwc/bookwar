extends Node

var _letter_levels: Dictionary = {}
var _punctuation: Dictionary = {}
var _dots: int = 0

signal inventory_changed
signal dots_changed(count: int)
signal ellipsis_created(count: int)
signal letter_acquired(letter_char: String, level: int)
signal letter_removed(letter_char: String, level: int)

func _ready() -> void:
	_punctuation["."] = 0

func get_dots() -> int:
	return _dots

func add_dots(count: int) -> void:
	if count == 0:
		return
	if count < 0:
		push_warning("Inventory.add_dots called with negative count, use use_dots instead")
		return
	_dots += count
	dots_changed.emit(_dots)
	_check_ellipsis()
	inventory_changed.emit()

func use_dots(count: int) -> bool:
	if count < 0:
		return false
	if _dots >= count:
		_dots -= count
		dots_changed.emit(_dots)
		inventory_changed.emit()
		return true
	return false

func has_ellipsis() -> bool:
	return _punctuation.get("...", 0) > 0

func _check_ellipsis() -> void:
	while _dots >= BookwarConst.ELLIPSIS_COST:
		_dots -= BookwarConst.ELLIPSIS_COST
		_punctuation["..."] = _punctuation.get("...", 0) + 1
		ellipsis_created.emit(_punctuation["..."])
	dots_changed.emit(_dots)

func use_ellipsis() -> bool:
	if _punctuation.get("...", 0) > 0:
		_punctuation["..."] -= 1
		inventory_changed.emit()
		return true
	return false

func add_letter(letter_char: String) -> void:
	if letter_char == "":
		return
	_letter_levels[letter_char] = _letter_levels.get(letter_char, 0) + 1
	letter_acquired.emit(letter_char, _letter_levels[letter_char])
	inventory_changed.emit()

func remove_letter(letter_char: String) -> bool:
	var current: int = _letter_levels.get(letter_char, 0)
	if current > 0:
		_letter_levels[letter_char] = current - 1
		if _letter_levels[letter_char] == 0:
			_letter_levels.erase(letter_char)
		letter_removed.emit(letter_char, _letter_levels.get(letter_char, 0))
		inventory_changed.emit()
		return true
	return false

func get_letter_level(letter_char: String) -> int:
	return _letter_levels.get(letter_char, 0)

func get_all_letters() -> Dictionary:
	return _letter_levels.duplicate()

func add_punctuation(punct_char: String, count: int = 1) -> void:
	if count <= 0:
		return
	_punctuation[punct_char] = _punctuation.get(punct_char, 0) + count
	inventory_changed.emit()

func use_punctuation(punct_char: String) -> bool:
	if _punctuation.get(punct_char, 0) > 0:
		_punctuation[punct_char] -= 1
		inventory_changed.emit()
		return true
	return false

func get_punctuation_count(punct_char: String) -> int:
	return _punctuation.get(punct_char, 0)

func get_all_punctuation() -> Dictionary:
	return _punctuation.duplicate()

func has_any_letter() -> bool:
	return _letter_levels.size() > 0
