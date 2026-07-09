extends Node

var _letters: Dictionary = {}
var _is_loaded: bool = false
var _loaded_locale: String = ""

signal data_loaded

func _ready() -> void:
	_load_letters()
	# §I18N: reload when locale changes so MAP_CHAIN etc. reflect new alphabet
	if I18n != null:
		I18n.locale_changed.connect(_on_locale_changed)

func _on_locale_changed(_new_locale: String) -> void:
	_load_letters()

func _load_letters() -> void:
	# §I18N alphabet-dependence (AGENTS.md §2.0):
	# Default = letters.json (russian, 33 letters).
	# Other locales = letters_<locale>.json (e.g. letters_en.json = 26 letters).
	# Number of letters N → drives MAP_CHAIN length, balance, etc.
	var locale: String = ""
	if I18n != null:
		locale = I18n.get_locale()
	var path: String = "res://data/letters.json"
	if locale != "" and locale != "ru":
		var localized_path: String = "res://data/letters_" + locale + ".json"
		# §I18N: try open directly — ResourceLoader.exists() is unreliable for
		# .json on HTML5 export (only resources used in code are packed).
		var probe: FileAccess = FileAccess.open(localized_path, FileAccess.READ)
		if probe != null:
			probe.close()
			path = localized_path
		else:
			push_warning("AlphabetData: no letters_" + locale + ".json (FileAccess), falling back to letters.json (ru)")
	# Reset state
	_letters.clear()
	_is_loaded = false
	_loaded_locale = locale if locale != "" else "ru"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("AlphabetData: Failed to open " + path)
		return
	var json: JSON = JSON.new()
	var err: Error = json.parse(file.get_as_text())
	if err != OK:
		push_error("AlphabetData: Failed to parse " + path + ": " + json.get_error_message())
		return
	var data: Variant = json.get_data()
	if not data is Dictionary:
		push_error("AlphabetData: " + path + " root is not a Dictionary")
		return
	var data_dict: Dictionary = data
	if not data_dict.has("letters"):
		push_error("AlphabetData: missing 'letters' key in " + path)
		return
	for letter_data: Variant in data_dict["letters"]:
		var letter_dict: Dictionary = letter_data
		var letter_char: String = letter_dict.get("char", "")
		if letter_char != "":
			_letters[letter_char] = letter_dict
	_is_loaded = true
	data_loaded.emit()
	# §I18N: push fresh snapshot to JS bridge so tests/UI can read new alphabet
	# immediately after locale switch (not waiting for next world_map._ready).
	if OS.has_feature("web"):
		# AlphabetData loads before TestBridge in autoload order; check null.
		var tb = get_tree().get_root().get_node_or_null("/root/TestBridge")
		# TestBridge is not an autoload — it's instantiated per scene. Use a
		# direct eval to expose the count + a sample char.
		JavaScriptBridge.eval("window.gameAlphabetCount = " + str(_letters.size()) + ";", true)
		# Push full snapshot (replaces the one world_map sets).
		var snapshot: Array = get_alphabet_snapshot()
		JavaScriptBridge.eval("window.gameAlphabet = " + JSON.stringify(snapshot) + ";", true)
	print("[alphabet] loaded locale=" + _loaded_locale + " count=" + str(_letters.size()))

func get_loaded_locale() -> String:
	return _loaded_locale

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
			# §I18N §2.0: use per-locale vowel multiplier (compensates defense-heavy
			# locales like en/fr/pt with only 5 vowels vs 21 consonants).
			return float(base_power) * float(level) * BookwarConst.get_vowel_multiplier()
		"sign":
			if letter.get("role", "") == "attack_buff":
				return float(base_power) * float(level) * BookwarConst.SIGN_MULTIPLIER
			return 0.0
	return 0.0

func calculate_shield(letter_char: String, level: int) -> float:
	var letter: Dictionary = get_letter(letter_char)
	if letter.is_empty():
		return 0.0
	var base_power: int = letter.get("base_power", 0)
	match letter.get("type", ""):
		"consonant":
			return float(base_power) * float(level) * BookwarConst.CONSONANT_MULTIPLIER
		"sign":
			if letter.get("role", "") == "defense_buff":
				return float(base_power) * float(level) * BookwarConst.SIGN_MULTIPLIER
			return 0.0
	return 0.0

func get_speed(letter_char: String) -> int:
	var letter: Dictionary = get_letter(letter_char)
	if letter.is_empty():
		return 0
	return letter.get("speed", 0)

func get_base_power(letter_char: String) -> int:
	var letter: Dictionary = get_letter(letter_char)
	if letter.is_empty():
		return 0
	return letter.get("base_power", 0)

# Localized description: returns the translated text for the current locale if a
# key "letter.desc.<char>" exists, else the raw description from letters.json.
func get_description(letter_char: String) -> String:
	var letter: Dictionary = get_letter(letter_char)
	var raw: String = String(letter.get("description", ""))
	return I18n.t("letter.desc." + letter_char, raw)
