extends Control
class_name InventoryUI

var _is_open: bool = false

@onready var _letter_grid: GridContainer = $Panel/MarginContainer/VBoxContainer/LetterGrid
@onready var _punctuation_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/PunctuationList
@onready var _dots_label: Label = $Panel/MarginContainer/VBoxContainer/DotsInfo

func _ready() -> void:
	visible = false
	InventoryManager.inventory_changed.connect(_refresh)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_inventory"):
		if _is_open:
			close()
		else:
			open()

func open() -> void:
	_is_open = true
	visible = true
	_refresh()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameInventoryVisible = true;")
	_update_bridge()

func close() -> void:
	_is_open = false
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameInventoryVisible = false;")

func _refresh() -> void:
	if not _is_open:
		return
	_clear_grid()
	var letters: Dictionary = InventoryManager.get_all_letters()
	for letter_char: String in letters:
		var level: int = letters[letter_char]
		var data: Dictionary = AlphabetData.get_letter(letter_char)
		var card: Button = Button.new()
		card.text = letter_char + " Lv" + str(level)
		if not data.is_empty():
			var power: int = data["base_power"] * level
			card.tooltip_text = str(power) + " | " + data["role"]
		_letter_grid.add_child(card)
	_clear_punctuation()
	var punctuation: Dictionary = InventoryManager.get_all_punctuation()
	for char: String in punctuation:
		var count: int = punctuation[char]
		if count > 0:
			var label: Label = Label.new()
			label.text = char + ": " + str(count)
			_punctuation_list.add_child(label)
	if _dots_label:
		_dots_label.text = "Точки: " + str(InventoryManager.get_dots())
	_update_bridge()

func _update_bridge() -> void:
	if not OS.has_feature("web"):
		return
	var letters: Dictionary = InventoryManager.get_all_letters()
	var dots: int = InventoryManager.get_dots()
	var punct: Dictionary = InventoryManager.get_all_punctuation()
	JavaScriptBridge.eval("window.gameInventory = {letters: " + JSON.stringify(letters) + ", dots: " + str(dots) + ", punctuation: " + JSON.stringify(punct) + "};")

func _clear_grid() -> void:
	for child: Node in _letter_grid.get_children():
		child.queue_free()

func _clear_punctuation() -> void:
	for child: Node in _punctuation_list.get_children():
		child.queue_free()
