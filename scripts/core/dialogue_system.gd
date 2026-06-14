extends Node
class_name DialogueSystem

const DIALOGUES_DIR: String = "res://data/dialogues/"

var _current_lines: Array = []
var _current_line_index: int = 0
var _current_npc_id: String = ""
var _current_npc_name: String = ""
var _is_active: bool = false

var _npcs: Dictionary = {}
var _responses: Dictionary = {}
var _loaded_region: String = ""

signal dialogue_line_shown(speaker: String, text: String)
signal dialogue_choices_shown(choices: Array)
signal dialogue_ended(npc_id: String)
signal dialogue_started(npc_id: String)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_region(BookwarConst.DEFAULT_REGION)

func load_region(region_id: String) -> void:
	var path: String = DIALOGUES_DIR + region_id + ".json"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("DialogueSystem: dialogue file not found: " + path)
		return
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("DialogueSystem: failed to parse " + path + ": " + json.get_error_message())
		return
	var data: Dictionary = json.get_data()
	_responses = data.get("responses", {})
	_npcs.clear()
	for npc: Variant in data.get("npcs", []):
		var npc_dict: Dictionary = npc
		var nid: String = npc_dict.get("id", "")
		if nid != "":
			_npcs[nid] = npc_dict
	_loaded_region = region_id

func get_npc(npc_id: String) -> Dictionary:
	return _npcs.get(npc_id, {})

func select_dialogue_for(npc_id: String) -> Array:
	# Pick the first dialogue whose trigger condition is satisfied.
	var npc: Dictionary = get_npc(npc_id)
	if npc.is_empty():
		return []
	for dlg: Variant in npc.get("dialogues", []):
		var dlg_dict: Dictionary = dlg
		var trigger: String = dlg_dict.get("trigger", "any")
		if _trigger_satisfied(trigger):
			return dlg_dict.get("lines", [])
	# Fallback: first dialogue's lines, if any
	var all: Array = npc.get("dialogues", [])
	if all.size() > 0:
		return (all[0] as Dictionary).get("lines", [])
	return []

func _trigger_satisfied(trigger: String) -> bool:
	match trigger:
		"any", "first_meeting":
			return true
		"has_ellipsis":
			return InventoryManager.has_ellipsis()
		"has_letter":
			return InventoryManager.has_any_letter()
		_:
			return true

func start_dialogue(npc_id: String) -> void:
	var lines: Array = select_dialogue_for(npc_id)
	if lines.is_empty():
		return
	start_dialogue_with_lines(npc_id, lines)

func start_dialogue_with_lines(npc_id: String, dialogue_data: Array) -> void:
	if _is_active:
		return
	var npc: Dictionary = get_npc(npc_id)
	_current_npc_id = npc_id
	_current_npc_name = npc.get("name", npc_id)
	_current_lines = dialogue_data.duplicate(true)
	_current_line_index = 0
	_is_active = true
	GameState.start_dialogue()
	dialogue_started.emit(npc_id)
	_show_current_line()

func _show_current_line() -> void:
	if _current_line_index >= _current_lines.size():
		end_dialogue()
		return
	var line: Dictionary = _current_lines[_current_line_index]
	if line.has("choices"):
		dialogue_choices_shown.emit(line["choices"])
		_push_dialogue_text(_current_npc_name + " ждёт ответа.")
		return
	var speaker: String = line.get("speaker", _current_npc_name)
	var text: String = line.get("text", "")
	dialogue_line_shown.emit(speaker, text)
	_push_dialogue_text(speaker + ": " + text)

func advance() -> void:
	if not _is_active:
		return
	_current_line_index += 1
	_show_current_line()

func select_choice(index: int) -> void:
	if not _is_active:
		return
	if _current_line_index >= _current_lines.size():
		advance()
		return
	var line: Dictionary = _current_lines[_current_line_index]
	if not line.has("choices"):
		advance()
		return
	var choices: Array = line["choices"]
	if index < 0 or index >= choices.size():
		advance()
		return
	var choice: Dictionary = choices[index]
	_handle_choice_result(String(choice.get("result", "")))

func _handle_choice_result(result: String) -> void:
	match result:
		"give_hint":
			# Spend dots, then show the data-driven hint line and finish.
			if InventoryManager.use_dots(BookwarConst.ELLIPSIS_COST + 2):
				var hint: String = _responses.get("give_hint", "...")
				dialogue_line_shown.emit(_current_npc_name, hint)
				_push_dialogue_text(_current_npc_name + ": " + hint)
				end_dialogue()
			else:
				var no_dots: String = _responses.get("no_dots", "...")
				dialogue_line_shown.emit(_current_npc_name, no_dots)
				_push_dialogue_text(_current_npc_name + ": " + no_dots)
				end_dialogue()
		"flee", "slow", "info", "enrage", "come_back":
			end_dialogue()
		_:
			end_dialogue()

func end_dialogue() -> void:
	if not _is_active:
		return
	_is_active = false
	_current_lines.clear()
	_current_line_index = 0
	GameState.end_dialogue()
	dialogue_ended.emit(_current_npc_id)
	_current_npc_id = ""
	_current_npc_name = ""

func is_active() -> bool:
	return _is_active

func _push_dialogue_text(text: String) -> void:
	if OS.has_feature("web"):
		var escaped: String = text.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "\\n")
		JavaScriptBridge.eval("window.gameDialogueText = '" + escaped + "';")

func try_use_ellipsis() -> bool:
	return InventoryManager.use_ellipsis()
