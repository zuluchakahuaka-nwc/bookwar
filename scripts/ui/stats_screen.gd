extends CanvasLayer
# StatsScreen — экран статистики игрока. Открытие: клавиша S (или Tab).
# Показывает: букв собрано / 33, карт пройдено / 33, квестов выполнено,
# текущий регион, число рекрутов, очков (буквиц).

var _panel: Panel
var _title_label: Label
var _content: VBoxContainer
var _hint_label: Label
var _visible: bool = false
var _last_input_time: float = 0.0
const DEBOUNCE_SEC: float = 0.25

func _ready() -> void:
	layer = 91  # выше HUD (80), чуть выше QuestLog (90)
	_build_ui()
	visible = true
	_panel.visible = false
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameStatsVisible = false;")
		JavaScriptBridge.eval("window.gameToggleStats = function() { window._godotToggleStats = true; };")
	set_process(true)
	set_process_input(true)

func _build_ui() -> void:
	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = 140
	_panel.offset_right = -140
	_panel.offset_top = 80
	_panel.offset_bottom = -80
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.04, 0.08, 0.97)
	bg.border_color = Color(0.55, 0.45, 0.25, 1.0)
	bg.set_border_width_all(3)
	bg.set_content_margin_all(18)
	_panel.add_theme_stylebox_override("panel", bg)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 12)
	_panel.add_child(col)
	_title_label = Label.new()
	_title_label.text = "СТАТИСТИКА ГЕРОЯ"
	_title_label.add_theme_font_size_override("font_size", 32)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.30, 1))
	_title_label.add_theme_color_override("font_outline_color", Color(0.1, 0.04, 0.02, 1))
	_title_label.add_theme_constant_override("outline_size", 4)
	col.add_child(_title_label)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	col.add_child(_content)
	_hint_label = Label.new()
	_hint_label.text = "[S] закрыть"
	_hint_label.add_theme_font_size_override("font_size", 18)
	_hint_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5, 1))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_hint_label)

func _process(_delta: float) -> void:
	if OS.has_feature("web"):
		if JavaScriptBridge.eval("typeof window._godotToggleStats !== 'undefined' && window._godotToggleStats"):
			JavaScriptBridge.eval("window._godotToggleStats = false;")
			_toggle()
	# Stats panel refreshes on _toggle (open) only — calling _refresh() every frame
	# while visible would rebuild ~25 children per frame and thrash Godot's tree.

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event.keycode == KEY_S or event.keycode == KEY_TAB):
		var now: float = Time.get_ticks_msec() / 1000.0
		if now - _last_input_time < DEBOUNCE_SEC:
			return
		_last_input_time = now
		_toggle()
		get_viewport().set_input_as_handled()

func _toggle() -> void:
	_visible = not _visible
	_panel.visible = _visible
	if _visible:
		_refresh()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameStatsVisible = " + str(_visible).to_lower() + ";")

func _refresh() -> void:
	for c: Node in _content.get_children():
		c.queue_free()
	# Считаем метрики
	var letters_collected: int = InventoryManager.get_all_letters().size()
	var letters_total: int = 33
	var completed_quests: int = GameState.completed_quest_ids.size()
	# Карт пройдено: считаем уникальные map_ids из completed_quest_ids + completed_quests
	var maps_done: Dictionary = {}
	for qid: String in GameState.completed_quest_ids:
		# qid формат: map_id + "_" + rest. Извлекаем map_id.
		for mid: String in BookwarConst.MAP_CHAIN:
			if qid.begins_with(mid + "_") or qid == mid:
				maps_done[mid] = true
				break
	for mid_legacy: String in GameState.completed_quests:
		maps_done[mid_legacy] = true
	var maps_passed: int = maps_done.size()
	var maps_total: int = BookwarConst.MAP_CHAIN.size()
	var recruit_count: int = GameState.recruits.size()
	var dots: int = InventoryManager.get_dots()
	var current_level: int = BookwarConst.get_level_number(GameState.current_map_id)
	var current_region: String = BookwarConst.get_map_name(GameState.current_map_id)
	# Считаем «сила букв» игрока — суммарный base_power всех букв
	var letter_power: int = 0
	for letter_char: String in InventoryManager.get_all_letters():
		letter_power += AlphabetData.get_base_power(letter_char) * InventoryManager.get_letter_level(letter_char)
	# Заполняем карточки
	_add_metric("Карта:", str(current_level) + " / " + str(maps_total) + " — " + current_region, Color(0.85, 0.75, 0.40))
	_add_metric("Карт пройдено:", str(maps_passed) + " / " + str(maps_total), Color(0.55, 0.95, 0.55) if maps_passed > 0 else Color(0.7, 0.65, 0.5))
	_add_metric("Букв собрано:", str(letters_collected) + " / " + str(letters_total), Color(0.55, 0.95, 0.55) if letters_collected >= letters_total else Color(0.85, 0.75, 0.40))
	_add_metric("Квестов выполнено:", str(completed_quests), Color(0.55, 0.95, 0.55) if completed_quests > 0 else Color(0.7, 0.65, 0.5))
	_add_metric("Союзников (банда):", str(recruit_count), Color(0.7, 0.85, 0.95))
	_add_metric("Буквиц (валюта):", str(dots), Color(0.95, 0.85, 0.40))
	_add_metric("Сила букв (Σ power×level):", str(letter_power), Color(0.95, 0.55, 0.40))
	# Подсказка про финал
	if maps_passed >= maps_total:
		var fin := Label.new()
		fin.text = "★ ФИНАЛ ДОСТИГНУТ — алфавит восстановлен!"
		fin.add_theme_font_size_override("font_size", 24)
		fin.add_theme_color_override("font_color", Color(1.0, 0.85, 0.30, 1))
		fin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content.add_child(fin)
	elif letters_collected >= letters_total:
		var full := Label.new()
		full.text = "★ Полный алфавит собран!"
		full.add_theme_font_size_override("font_size", 22)
		full.add_theme_color_override("font_color", Color(0.55, 0.95, 0.55))
		full.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content.add_child(full)

func _add_metric(label_text: String, value_text: String, value_color: Color) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.78, 0.75, 0.60))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var val := Label.new()
	val.text = value_text
	val.add_theme_font_size_override("font_size", 22)
	val.add_theme_color_override("font_color", value_color)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(val)
	_content.add_child(row)
