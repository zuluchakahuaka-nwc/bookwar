extends Node

var _spells: Dictionary = {}
var _unlocked: Dictionary = {}  # word -> bool
var _is_loaded: bool = false

signal data_loaded
signal spell_unlocked(word: String)

func _ready() -> void:
	_load_spells()

func _load_spells() -> void:
	var file: FileAccess = FileAccess.open("res://data/spells.json", FileAccess.READ)
	if file == null:
		push_error("SpellData: spells.json not found")
		return
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("SpellData: parse error: " + json.get_error_message())
		return
	var data: Dictionary = json.get_data()
	for spell: Variant in data.get("spells", []):
		var d: Dictionary = spell
		var word: String = String(d.get("word", ""))
		if word != "":
			_spells[word] = d
	_is_loaded = true
	data_loaded.emit()

func is_loaded() -> bool:
	return _is_loaded

func get_spell(word: String) -> Dictionary:
	return _spells.get(word, {})

func get_all_spells() -> Dictionary:
	return _spells

func get_available_spells() -> Array:
	# Spells the player can cast right now (unlocked + has all letters)
	var result: Array = []
	for word: String in _spells.keys():
		if _unlocked.get(word, false) and can_cast(word):
			result.append(_spells[word])
	return result

func is_unlocked(word: String) -> bool:
	return _unlocked.get(word, false)

func unlock(word: String) -> bool:
	if not _spells.has(word):
		return false
	if _unlocked.get(word, false):
		return true
	var cost: int = int(_spells[word].get("unlock_cost", 0))
	if _currency() < cost:
		return false
	_unlocked[word] = true
	spell_unlocked.emit(word)
	return true

func can_cast(word: String) -> bool:
	if not _spells.has(word):
		return false
	var letters: Array = _spells[word].get("letters", [])
	for l: Variant in letters:
		if InventoryManager.get_letter_level(str(l)) < 1:
			return false
	return true

func get_unlock_cost(word: String) -> int:
	if not _spells.has(word):
		return 0
	return int(_spells[word].get("unlock_cost", 0))

func calculate_power(word: String) -> float:
	# spell_power = (sum base_power of letters) * multiplier * avg_level (AGENTS.md S16.3)
	if not _spells.has(word):
		return 0.0
	var letters: Array = _spells[word].get("letters", [])
	var mult: float = float(_spells[word].get("multiplier", 1.0))
	var total_power: float = 0.0
	var total_level: int = 0
	for l: Variant in letters:
		var data: Dictionary = AlphabetData.get_letter(str(l))
		total_power += float(data.get("base_power", 0))
		total_level += InventoryManager.get_letter_level(str(l))
	var count: int = max(1, letters.size())
	var avg_level: float = float(total_level) / float(count)
	return total_power * mult * avg_level

func get_effect(word: String) -> String:
	if not _spells.has(word):
		return ""
	return String(_spells[word].get("effect", ""))

func get_spell_type(word: String) -> String:
	if not _spells.has(word):
		return ""
	return String(_spells[word].get("type", ""))

func get_slowest_speed(word: String) -> int:
	# Spell acts at the speed of the slowest letter in the word (S16.4)
	if not _spells.has(word):
		return 0
	var letters: Array = _spells[word].get("letters", [])
	var min_speed: int = 999
	for l: Variant in letters:
		var s: int = AlphabetData.get_speed(str(l))
		if s < min_speed:
			min_speed = s
	return min_speed

func _currency() -> int:
	# wallet = sum(position * level) for all owned letters (S16.2)
	var total: int = 0
	for letter_char: String in InventoryManager.get_all_letters().keys():
		var data: Dictionary = AlphabetData.get_letter(letter_char)
		var pos: int = int(data.get("position", 0))
		var lvl: int = InventoryManager.get_letter_level(letter_char)
		total += pos * lvl
	return total

func get_currency() -> int:
	return _currency()
