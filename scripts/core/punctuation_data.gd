extends Node

var _punctuation: Dictionary = {}

signal data_loaded

func _ready() -> void:
	_load_punctuation()

func _load_punctuation() -> void:
	var file: FileAccess = FileAccess.open("res://data/punctuation.json", FileAccess.READ)
	if file == null:
		push_error("PunctuationData: Failed to open punctuation.json")
		return
	var json: JSON = JSON.new()
	var err: Error = json.parse(file.get_as_text())
	if err != OK:
		push_error("PunctuationData: Failed to parse punctuation.json: " + json.get_error_message())
		return
	var data: Variant = json.get_data()
	if not data is Dictionary:
		push_error("PunctuationData: punctuation.json root is not a Dictionary")
		return
	var data_dict: Dictionary = data
	if not data_dict.has("punctuation"):
		push_error("PunctuationData: missing 'punctuation' key")
		return
	for p: Variant in data_dict["punctuation"]:
		var p_dict: Dictionary = p
		_punctuation[p_dict.get("char", "")] = p_dict
	data_loaded.emit()

func get_punctuation(punct_char: String) -> Dictionary:
	return _punctuation.get(punct_char, {})

func get_all_punctuation() -> Dictionary:
	return _punctuation.duplicate(true)

func get_count() -> int:
	return _punctuation.size()
