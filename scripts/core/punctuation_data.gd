extends Node
class_name PunctuationData

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
	var data: Dictionary = json.get_data()
	for p: Dictionary in data["punctuation"]:
		_punctuation[p["char"]] = p
	data_loaded.emit()

func get_punctuation(char: String) -> Dictionary:
	return _punctuation.get(char, {})

func get_all_punctuation() -> Dictionary:
	return _punctuation
