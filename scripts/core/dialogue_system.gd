extends Node
class_name DialogueSystem

var _current_dialogues: Array[Dictionary] = []
var _current_line_index: int = 0
var _current_npc_id: String = ""
var _is_active: bool = false

signal dialogue_line_shown(speaker: String, text: String)
signal dialogue_choices_shown(choices: Array)
signal dialogue_ended(npc_id: String)
signal dialogue_started(npc_id: String)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func start_dialogue(npc_id: String, dialogue_data: Array) -> void:
	if _is_active:
		return
	_is_active = true
	_current_npc_id = npc_id
	_current_dialogues = dialogue_data
	_current_line_index = 0
	GameState.start_dialogue()
	dialogue_started.emit(npc_id)
	_show_current_line()

func _show_current_line() -> void:
	if _current_line_index >= _current_dialogues.size():
		end_dialogue()
		return
	var line: Dictionary = _current_dialogues[_current_line_index]
	if line.has("choices"):
		dialogue_choices_shown.emit(line["choices"])
		_push_dialogue_text(str(line["choices"]))
		return
	var speaker: String = line.get("speaker", "")
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
	if _current_line_index < _current_dialogues.size():
		var line: Dictionary = _current_dialogues[_current_line_index]
		if line.has("choices"):
			var choices: Array = line["choices"]
			if index >= 0 and index < choices.size():
				var choice: Dictionary = choices[index]
				var result: String = choice.get("result", "")
				_handle_choice_result(result)
				return
	advance()

func _handle_choice_result(result: String) -> void:
	match result:
		"flee", "slow", "info":
			end_dialogue()
		"enrage":
			end_dialogue()
		"give_hint":
			if InventoryManager.use_dots(5):
				dialogue_line_shown.emit("wanderer", "Говорят, к северу от деревни спрятана буква А...")
				_current_line_index += 1
				call_deferred("advance")
			else:
				dialogue_line_shown.emit("wanderer", "У тебя не хватает точек. Приходи позже.")
				end_dialogue()
		"come_back":
			end_dialogue()
		_:
			end_dialogue()

func end_dialogue() -> void:
	_is_active = false
	_current_dialogues.clear()
	_current_line_index = 0
	GameState.end_dialogue()
	dialogue_ended.emit(_current_npc_id)
	_current_npc_id = ""

func is_active() -> bool:
	return _is_active

func _push_dialogue_text(text: String) -> void:
	if OS.has_feature("web"):
		var escaped: String = text.replace("'", "\\'")
		JavaScriptBridge.eval("window.gameDialogueText = '" + escaped + "';")

func try_use_ellipsis() -> bool:
	if InventoryManager.use_ellipsis():
		return true
	return false
