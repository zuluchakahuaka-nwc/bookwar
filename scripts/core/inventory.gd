extends Node

var _letter_levels: Dictionary = {}
var _punctuation: Dictionary = {}
var _dots: int = 0
var _crafting_recipes: Array = []
var _craft_force: int = -1  # -1 = random, 0 = force fail, 1 = force success (test hook)

signal inventory_changed
signal dots_changed(count: int)
signal ellipsis_created(count: int)
signal letter_acquired(letter_char: String, level: int)
signal letter_removed(letter_char: String, level: int)
signal craft_result(source: String, modifier: String, target: String, success: bool, message: String)

func _ready() -> void:
	_punctuation["."] = 0
	_load_crafting_recipes()

func _load_crafting_recipes() -> void:
	var file: FileAccess = FileAccess.open("res://data/crafting.json", FileAccess.READ)
	if file == null:
		return
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data: Variant = json.get_data()
		if data is Dictionary:
			var arr: Variant = (data as Dictionary).get("recipes", [])
			if arr is Array:
				_crafting_recipes = arr

func get_dots() -> int:
	return _dots

func add_dots(count: int) -> void:
	# "dots" are now БУКВИЦЫ — the currency. They accumulate (no auto-conversion);
	# ellipsis/speech is derived: 3 буквицы = 1 speech (see has/use_ellipsis).
	if count == 0:
		return
	if count < 0:
		push_warning("Inventory.add_dots called with negative count, use use_dots instead")
		return
	_dots += count
	_punctuation["..."] = int(_dots / BookwarConst.ELLIPSIS_COST)
	dots_changed.emit(_dots)
	inventory_changed.emit()

func use_dots(count: int) -> bool:
	if count < 0:
		return false
	if _dots >= count:
		_dots -= count
		_punctuation["..."] = int(_dots / BookwarConst.ELLIPSIS_COST)
		dots_changed.emit(_dots)
		inventory_changed.emit()
		return true
	return false

func has_ellipsis() -> bool:
	return _dots >= BookwarConst.ELLIPSIS_COST

func _check_ellipsis() -> void:
	# Kept for signal compatibility; ellipsis is now derived from буквицы in add/use.
	_punctuation["..."] = int(_dots / BookwarConst.ELLIPSIS_COST)
	dots_changed.emit(_dots)

func use_ellipsis() -> bool:
	if _dots >= BookwarConst.ELLIPSIS_COST:
		_dots -= BookwarConst.ELLIPSIS_COST
		_punctuation["..."] = int(_dots / BookwarConst.ELLIPSIS_COST)
		dots_changed.emit(_dots)
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

# --- Crafting (C1): transform one letter into another using a modifier ---

func get_crafting_recipes() -> Array:
	return _crafting_recipes.duplicate(true)

func _has_modifier(modifier: String) -> bool:
	if modifier == "Ь":
		return get_letter_level("Ь") > 0
	if modifier == "'":
		return _punctuation.get("'", 0) > 0
	return false

func _consume_modifier(modifier: String) -> void:
	if modifier == "Ь":
		remove_letter("Ь")
	elif modifier == "'":
		if _punctuation.get("'", 0) > 0:
			_punctuation["'"] -= 1

func find_recipe(source: String, modifier: String) -> Dictionary:
	for r: Variant in _crafting_recipes:
		var rd: Dictionary = r
		if String(rd.get("from", "")) == source and String(rd.get("modifier", "")) == modifier:
			return rd
	return {}

func can_craft(source: String, modifier: String) -> bool:
	if get_letter_level(source) <= 0:
		return false
	if not _has_modifier(modifier):
		return false
	return find_recipe(source, modifier).size() > 0

func craft(source: String, modifier: String) -> Dictionary:
	# Returns {success: bool, target: String, message: String}
	var recipe: Dictionary = find_recipe(source, modifier)
	if recipe.is_empty():
		var msg0: String = "Нет такого рецепта: " + source + " + " + modifier
		craft_result.emit(source, modifier, "", false, msg0)
		return {"success": false, "target": "", "message": msg0}
	if get_letter_level(source) <= 0:
		var msg1: String = "Нет буквы " + source
		craft_result.emit(source, modifier, "", false, msg1)
		return {"success": false, "target": "", "message": msg1}
	if not _has_modifier(modifier):
		var msg2: String = "Нет модификатора " + modifier
		craft_result.emit(source, modifier, "", false, msg2)
		return {"success": false, "target": "", "message": msg2}
	var target: String = String(recipe.get("to", ""))
	var chance: float = float(recipe.get("chance", 0.0))
	# Consume the modifier donor regardless of outcome
	_consume_modifier(modifier)
	var roll: float
	if _craft_force == 1:
		roll = 0.0
	elif _craft_force == 0:
		roll = 1.0
	else:
		roll = randf()
	if roll < chance:
		add_letter(target)
		var msg_ok: String = "Успех! " + source + " + " + modifier + " -> " + target
		craft_result.emit(source, modifier, target, true, msg_ok)
		return {"success": true, "target": target, "message": msg_ok}
	else:
		var msg_fail: String = "Неудача! " + modifier + " потерян без результата."
		craft_result.emit(source, modifier, target, false, msg_fail)
		return {"success": false, "target": target, "message": msg_fail}

func set_craft_force(force: int) -> void:
	_craft_force = force
