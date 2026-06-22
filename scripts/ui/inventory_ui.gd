extends Control
class_name InventoryUI

const LETTER_CARD_SCENE: PackedScene = preload("res://scenes/ui/letter_card.tscn")

var _is_open: bool = false
var _craft_source: String = ""
var _craft_modifier: String = ""

@onready var _letter_grid: GridContainer = $Panel/MarginContainer/VBoxContainer/LetterGrid
@onready var _punctuation_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/PunctuationList
@onready var _dots_label: Label = $Panel/MarginContainer/VBoxContainer/DotsInfo

var _craft_section: VBoxContainer = null
var _craft_toggle_btn: Button = null
var _craft_source_row: HBoxContainer = null
var _craft_mod_row: HBoxContainer = null
var _craft_result_label: Label = null

func _ready() -> void:
	visible = false
	InventoryManager.inventory_changed.connect(_refresh)
	InventoryManager.craft_result.connect(_on_craft_result)
	_build_craft_section()
	_setup_craft_bridge()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_inventory"):
		if _is_open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()

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
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameInventoryVisible = false;")

func _refresh() -> void:
	if not _is_open:
		return
	_clear_grid()
	var letters: Dictionary = InventoryManager.get_all_letters()
	for letter_char: String in letters:
		var card: LetterCardUI = LETTER_CARD_SCENE.instantiate() as LetterCardUI
		card.setup(letter_char)
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
		_dots_label.text = "Буквицы: " + str(InventoryManager.get_dots())
	_update_bridge()
	if _craft_section and _craft_section.visible:
		_refresh_craft_options()

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

# --- Crafting UI (C1) ---

func _build_craft_section() -> void:
	var vbox: VBoxContainer = $Panel/MarginContainer/VBoxContainer
	_craft_toggle_btn = Button.new()
	_craft_toggle_btn.text = "Крафт [-]"
	_craft_toggle_btn.add_theme_font_size_override("font_size", 16)
	_craft_toggle_btn.pressed.connect(_toggle_craft)
	vbox.add_child(_craft_toggle_btn)

	_craft_section = VBoxContainer.new()
	_craft_section.add_theme_constant_override("separation", 6)
	_craft_section.visible = false
	vbox.add_child(_craft_section)

	var src_label: Label = Label.new()
	src_label.text = "Источник (буква):"
	_craft_section.add_child(src_label)
	_craft_source_row = HBoxContainer.new()
	_craft_section.add_child(_craft_source_row)

	var mod_label: Label = Label.new()
	mod_label.text = "Модификатор:"
	_craft_section.add_child(mod_label)
	_craft_mod_row = HBoxContainer.new()
	_craft_section.add_child(_craft_mod_row)

	var transform_btn: Button = Button.new()
	transform_btn.text = "Трансформировать"
	transform_btn.add_theme_font_size_override("font_size", 18)
	transform_btn.pressed.connect(_do_craft)
	_craft_section.add_child(transform_btn)

	_craft_result_label = Label.new()
	_craft_result_label.text = ""
	_craft_result_label.add_theme_font_size_override("font_size", 15)
	_craft_result_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	_craft_section.add_child(_craft_result_label)

func _toggle_craft() -> void:
	if _craft_section == null:
		return
	_craft_section.visible = not _craft_section.visible
	if _craft_section.visible:
		_craft_toggle_btn.text = "Крафт [+]"
		_refresh_craft_options()
		if OS.has_feature("web"):
			JavaScriptBridge.eval("window.gameCraftVisible = true;")
	else:
		_craft_toggle_btn.text = "Крафт [-]"
		if OS.has_feature("web"):
			JavaScriptBridge.eval("window.gameCraftVisible = false;")

func _refresh_craft_options() -> void:
	for child: Node in _craft_source_row.get_children():
		child.queue_free()
	for child: Node in _craft_mod_row.get_children():
		child.queue_free()
	_craft_source = ""
	_craft_modifier = ""
	var letters: Dictionary = InventoryManager.get_all_letters()
	for letter_char: String in letters:
		# Don't offer Ь as a source (it's a modifier, not transformable)
		if letter_char == "Ь":
			continue
		var btn: Button = Button.new()
		btn.text = letter_char
		btn.add_theme_font_size_override("font_size", 18)
		btn.custom_minimum_size = Vector2(44, 44)
		btn.toggle_mode = true
		btn.pressed.connect(_on_source_selected.bind(letter_char, btn))
		_craft_source_row.add_child(btn)
	# Modifiers
	if InventoryManager.get_letter_level("Ь") > 0:
		var mb: Button = Button.new()
		mb.text = "Ь"
		mb.add_theme_font_size_override("font_size", 18)
		mb.custom_minimum_size = Vector2(44, 44)
		mb.toggle_mode = true
		mb.pressed.connect(_on_modifier_selected.bind("Ь", mb))
		_craft_mod_row.add_child(mb)
	if InventoryManager.get_punctuation_count("'") > 0:
		var ab: Button = Button.new()
		ab.text = "'"
		ab.add_theme_font_size_override("font_size", 18)
		ab.custom_minimum_size = Vector2(44, 44)
		ab.toggle_mode = true
		ab.pressed.connect(_on_modifier_selected.bind("'", ab))
		_craft_mod_row.add_child(ab)
	if _craft_mod_row.get_child_count() == 0:
		var none: Label = Label.new()
		none.text = "нет модификаторов (нужен Ь)"
		_craft_mod_row.add_child(none)

func _on_source_selected(letter_char: String, btn: Button) -> void:
	_craft_source = letter_char
	for child: Node in _craft_source_row.get_children():
		if child is Button:
			(child as Button).set_pressed_no_signal(false)
	btn.set_pressed_no_signal(true)

func _on_modifier_selected(modifier: String, btn: Button) -> void:
	_craft_modifier = modifier
	for child: Node in _craft_mod_row.get_children():
		if child is Button:
			(child as Button).set_pressed_no_signal(false)
	btn.set_pressed_no_signal(true)

func _do_craft() -> void:
	if _craft_source == "" or _craft_modifier == "":
		if _craft_result_label:
			_craft_result_label.text = "Выберите букву и модификатор."
		return
	var result: Dictionary = InventoryManager.craft(_craft_source, _craft_modifier)
	if _craft_result_label:
		_craft_result_label.text = String(result.get("message", ""))
	_refresh_craft_options()
	_refresh()

func _on_craft_result(source: String, modifier: String, target: String, success: bool, message: String) -> void:
	if OS.has_feature("web"):
		var escaped: String = message.replace("\\", "\\\\").replace("'", "\\'")
		var res_json: String = "{\"source\":\"" + source + "\",\"modifier\":\"" + modifier + "\",\"target\":\"" + target + "\",\"success\":" + str(success).to_lower() + ",\"message\":\"" + escaped + "\"}"
		JavaScriptBridge.eval("window.gameCraftResult = " + res_json + ";")

# --- Test bridge for crafting ---

func _setup_craft_bridge() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("window.gameCraft = function(source, modifier) { if(!window._godotCraftQueue) window._godotCraftQueue=[]; window._godotCraftQueue.push({source:source, modifier:modifier}); return true; };")
	JavaScriptBridge.eval("window.gameCraftForce = function(success) { if(!window._godotCraftForceQueue) window._godotCraftForceQueue=[]; window._godotCraftForceQueue.push(success); return true; };")
	set_process(true)

func _process(_delta: float) -> void:
	if not OS.has_feature("web"):
		return
	var force_json: Variant = JavaScriptBridge.eval("JSON.stringify(window._godotCraftForceQueue || [])")
	JavaScriptBridge.eval("window._godotCraftForceQueue = [];")
	if force_json != null:
		var fs: String = str(force_json)
		if fs != "" and fs != "null":
			var fj: JSON = JSON.new()
			if fj.parse(fs) == OK:
				var arr: Array = fj.get_data() as Array
				if arr.size() > 0:
					InventoryManager.set_craft_force(int(arr[arr.size() - 1]))
	var craft_json: Variant = JavaScriptBridge.eval("JSON.stringify(window._godotCraftQueue || [])")
	JavaScriptBridge.eval("window._godotCraftQueue = [];")
	if craft_json == null:
		return
	var cs: String = str(craft_json)
	if cs == "" or cs == "null":
		return
	var cj: JSON = JSON.new()
	if cj.parse(cs) != OK:
		return
	var queue: Variant = cj.get_data()
	if not queue is Array:
		return
	for item: Variant in queue:
		var d: Dictionary = item
		var src: String = String(d.get("source", ""))
		var modi: String = String(d.get("modifier", ""))
		if src != "" and modi != "":
			InventoryManager.craft(src, modi)
	_update_bridge()
