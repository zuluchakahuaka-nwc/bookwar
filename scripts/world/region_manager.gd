extends Node
class_name RegionManager

var _current_region: String = "light_valley"
var _regions: Dictionary = {}

signal region_loaded(region_id: String)

func _ready() -> void:
	_load_regions()

func _load_regions() -> void:
	var file: FileAccess = FileAccess.open("res://data/regions.json", FileAccess.READ)
	if file == null:
		return
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data: Dictionary = json.get_data()
	for region: Dictionary in data["regions"]:
		_regions[region["id"]] = region

func get_region(region_id: String) -> Dictionary:
	return _regions.get(region_id, {})

func get_current_region() -> String:
	return _current_region

func set_current_region(region_id: String) -> void:
	_current_region = region_id
	GameState.set_region(region_id)
	region_loaded.emit(region_id)

func get_region_difficulty(region_id: String) -> int:
	var region: Dictionary = get_region(region_id)
	return region.get("difficulty", 0)
