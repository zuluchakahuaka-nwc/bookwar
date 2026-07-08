extends Control
class_name InventoryUI

const LETTER_CARD_SCENE: PackedScene = preload("res://scenes/ui/letter_card.tscn")

var _is_open: bool = false
var _craft_source: String = ""
var _craft_modifier: String = ""

@onready var _letter_grid: GridContainer = $Panel/MarginContainer/VBoxContainer/LetterGrid
@onready var _punctuation_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/PunctuationList
@onready var _dots_label: Label = $Panel/MarginContainer/VBoxContainer/DotsInfo
@onready var _inv_title_label: Label = get_node_or_null("Panel/MarginContainer/VBoxContainer/Title")
@onready var _punct_header_label: Label = get_node_or_null("Panel/MarginContainer/VBoxContainer/PunctuationLabel")

var _craft_section: VBoxContainer = null
var _craft_toggle_btn: Button = null
var _craft_source_row: HBoxContainer = null
var _craft_mod_row: HBoxContainer = null
var _craft_result_label: Label = null
var _craft_transform_btn: Button = null
var _last_craft_toggle_time: float = 0.0
var _last_craft_action_time: float = 0.0

func _ready() -> void:
	visible = false
	if _inv_title_label:
		_inv_title_label.text = I18n.t("inv.title", "Inventory")
	if _punct_header_label:
		_punct_header_label.text = I18n.t("inv.punctuation", "Marks:")
	InventoryManager.inventory_changed.connect(_refresh)
	InventoryManager.craft_result.connect(_on_craft_result)
	_build_craft_section()
	_setup_craft_bridge()
	# Expose the toggle button rect immediately so tests/users can tap it.
	call_deferred("_export_craft_rects")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_inventory") or event.is_action_pressed("ui_cancel"):
		if _is_open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
		return
	# Touch/mouse handler for craft buttons. Default Button.pressed signal is
	# unreliable on HTML5 (see AGENTS.md §0.9 + main_menu.gd pattern), so we
	# hit-test all craft UI buttons explicitly and invoke handlers directly.
	if not _is_open:
		return
	var pos := Vector2(-1, -1)
	var is_press := false
	if event is InputEventScreenTouch:
		pos = event.position
		is_press = event.pressed
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		is_press = true
	if not is_press or pos.x < 0:
		return
	# 1. Craft toggle button (always visible when inventory open)
	if _craft_toggle_btn and _craft_toggle_btn.get_global_rect().has_point(pos):
		_toggle_craft()
		get_viewport().set_input_as_handled()
		return
	# 2. Transform button (only if craft section visible)
	if _craft_section and _craft_section.visible and _craft_transform_btn and _craft_transform_btn.get_global_rect().has_point(pos):
		var now2: float = Time.get_ticks_msec() / 1000.0
		if now2 - _last_craft_action_time >= 0.3:
			_last_craft_action_time = now2
			_do_craft()
		get_viewport().set_input_as_handled()
		return
	# 3. Source letter buttons
	if _craft_section and _craft_section.visible:
		var now3: float = Time.get_ticks_msec() / 1000.0
		if now3 - _last_craft_action_time >= 0.3:
			for child: Node in _craft_source_row.get_children():
				if child is Button:
					var b: Button = child as Button
					if b.get_global_rect().has_point(pos):
						_last_craft_action_time = now3
						_on_source_selected(b.text, b)
						get_viewport().set_input_as_handled()
						return
			# 4. Modifier buttons
			for child2: Node in _craft_mod_row.get_children():
				if child2 is Button:
					var b2: Button = child2 as Button
					if b2.get_global_rect().has_point(pos):
						_last_craft_action_time = now3
						_on_modifier_selected(b2.text, b2)
						get_viewport().set_input_as_handled()
						return

func open() -> void:
	_is_open = true
	visible = true
	_refresh()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameInventoryVisible = true;")
	_update_bridge()

# §16 — Кузнец Слов вызывает это чтобы открыть крафт сразу.
func open_craft_panel() -> void:
	if _craft_section and not _craft_section.visible:
		_toggle_craft()

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
		_dots_label.text = I18n.t("hud.tokens", "Tokens") + ": " + str(InventoryManager.get_dots())
	_update_bridge()
	if _craft_section and _craft_section.visible:
		_refresh_craft_options()
	# Re-export button rects AFTER the grid rebuilt — letter cards changed layout,
	# so craft_toggle / source / mod / transform buttons moved.
	call_deferred("_export_craft_rects")

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
	_craft_toggle_btn.text = I18n.t("craft.closed", "Craft [-]")
	_craft_toggle_btn.add_theme_font_size_override("font_size", 16)
	# NOTE: no pressed.connect — _input hit-test drives _toggle_craft (see §0.11).
	vbox.add_child(_craft_toggle_btn)

	_craft_section = VBoxContainer.new()
	_craft_section.add_theme_constant_override("separation", 6)
	_craft_section.visible = false
	vbox.add_child(_craft_section)

	var src_label: Label = Label.new()
	src_label.text = I18n.t("craft.source", "Source (letter):")
	_craft_section.add_child(src_label)
	_craft_source_row = HBoxContainer.new()
	_craft_section.add_child(_craft_source_row)

	var mod_label: Label = Label.new()
	mod_label.text = I18n.t("craft.modifier", "Modifier:")
	_craft_section.add_child(mod_label)
	_craft_mod_row = HBoxContainer.new()
	_craft_section.add_child(_craft_mod_row)

	var transform_btn: Button = Button.new()
	transform_btn.text = I18n.t("craft.transform", "Transform")
	transform_btn.add_theme_font_size_override("font_size", 18)
	# NOTE: no pressed.connect — _input hit-test drives _do_craft (see §0.11).
	_craft_section.add_child(transform_btn)
	_craft_transform_btn = transform_btn

	_craft_result_label = Label.new()
	_craft_result_label.text = ""
	_craft_result_label.add_theme_font_size_override("font_size", 15)
	_craft_result_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	_craft_section.add_child(_craft_result_label)

func _toggle_craft() -> void:
	if _craft_section == null:
		return
	# Debounce: same double-handling issue as main_menu (touch+emulate, or signal+handler).
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_craft_toggle_time < 0.3:
		return
	_last_craft_toggle_time = now
	_craft_section.visible = not _craft_section.visible
	if _craft_section.visible:
		_craft_toggle_btn.text = I18n.t("craft.open", "Craft [+]")
		_refresh_craft_options()
		if OS.has_feature("web"):
			JavaScriptBridge.eval("window.gameCraftVisible = true;")
	else:
		_craft_toggle_btn.text = I18n.t("craft.closed", "Craft [-]")
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
		# NOTE: no pressed.connect — _input hit-test handles selection (see §0.11).
		_craft_source_row.add_child(btn)
	# Modifiers
	if InventoryManager.get_letter_level("Ь") > 0:
		var mb: Button = Button.new()
		mb.text = "Ь"
		mb.add_theme_font_size_override("font_size", 18)
		mb.custom_minimum_size = Vector2(44, 44)
		mb.toggle_mode = true
		_craft_mod_row.add_child(mb)
	if InventoryManager.get_punctuation_count("'") > 0:
		var ab: Button = Button.new()
		ab.text = "'"
		ab.add_theme_font_size_override("font_size", 18)
		ab.custom_minimum_size = Vector2(44, 44)
		ab.toggle_mode = true
		_craft_mod_row.add_child(ab)
	if _craft_mod_row.get_child_count() == 0:
		var none: Label = Label.new()
		none.text = I18n.t("craft.no_modifiers", "no modifiers (need Ь)")
		_craft_mod_row.add_child(none)
	# Expose button rects so test harness can tap them at the right coords
	call_deferred("_export_craft_rects")

func _export_craft_rects() -> void:
	await get_tree().process_frame
	if not OS.has_feature("web"):
		return
	var parts: Array = []
	if _craft_toggle_btn:
		var r: Rect2 = _craft_toggle_btn.get_global_rect()
		parts.append("{\"name\":\"craft_toggle\",\"x\":%.1f,\"y\":%.1f,\"w\":%.1f,\"h\":%.1f}" % [r.position.x, r.position.y, r.size.x, r.size.y])
	if _craft_section and _craft_section.visible:
		if _craft_transform_btn:
			var r2: Rect2 = _craft_transform_btn.get_global_rect()
			parts.append("{\"name\":\"transform\",\"x\":%.1f,\"y\":%.1f,\"w\":%.1f,\"h\":%.1f}" % [r2.position.x, r2.position.y, r2.size.x, r2.size.y])
		for c: Node in _craft_source_row.get_children():
			if c is Button:
				var r3: Rect2 = (c as Button).get_global_rect()
				parts.append("{\"name\":\"src_" + (c as Button).text + "\",\"x\":%.1f,\"y\":%.1f,\"w\":%.1f,\"h\":%.1f}" % [r3.position.x, r3.position.y, r3.size.x, r3.size.y])
		for c2: Node in _craft_mod_row.get_children():
			if c2 is Button:
				var r4: Rect2 = (c2 as Button).get_global_rect()
				parts.append("{\"name\":\"mod_" + (c2 as Button).text + "\",\"x\":%.1f,\"y\":%.1f,\"w\":%.1f,\"h\":%.1f}" % [r4.position.x, r4.position.y, r4.size.x, r4.size.y])
	var vs: Vector2 = get_viewport().get_visible_rect().size
	JavaScriptBridge.eval("window.gameCraftButtons = [" + ",".join(parts) + "]; window.gameViewportSize = {w:" + str(int(vs.x)) + ",h:" + str(int(vs.y)) + "};")

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
			_craft_result_label.text = I18n.t("craft.select_both", "Select a letter and a modifier.")
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
	JavaScriptBridge.eval("window.gameToggleInventory = function() { window._godotToggleInventory = true; };")
	set_process(true)

func _process(_delta: float) -> void:
	if not OS.has_feature("web"):
		return
	# Toggle inventory from JS bridge (mobile users tap the HUD "Сумка" button which
	# triggers the open_inventory action via HUD._input; this bridge is for tests / fallback).
	if JavaScriptBridge.eval("typeof window._godotToggleInventory !== 'undefined' && window._godotToggleInventory"):
		JavaScriptBridge.eval("window._godotToggleInventory = false;")
		if _is_open:
			close()
		else:
			open()
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
