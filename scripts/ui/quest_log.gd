extends CanvasLayer
# QuestLog — журнал квестов. Открывается на клавишу Q (toggle).
# Показывает активные и выполненные квесты текущей карты + прогресс.

var _panel: Panel
var _title_label: Label
var _content: VBoxContainer
var _scroll: ScrollContainer
var _hint_label: Label
var _visible: bool = false
var _last_input_time: float = 0.0
const DEBOUNCE_SEC: float = 0.25

func _ready() -> void:
	layer = 90  # выше HUD (HUD на 80)
	_build_ui()
	visible = true  # CanvasLayer всегда активен, прячем _panel
	_panel.visible = false
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameQuestLogVisible = false;")
		JavaScriptBridge.eval("window.gameToggleQuestLog = function() { window._godotToggleQuestLog = true; };")
	set_process(true)
	set_process_input(true)

func _build_ui() -> void:
	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = 100
	_panel.offset_right = -100
	_panel.offset_top = 60
	_panel.offset_bottom = -60
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.05, 0.09, 0.96)
	bg.border_color = Color(0.55, 0.45, 0.25, 1.0)
	bg.border_width_left = 3
	bg.border_width_right = 3
	bg.border_width_top = 3
	bg.border_width_bottom = 3
	bg.content_margin_left = 18
	bg.content_margin_right = 18
	bg.content_margin_top = 18
	bg.content_margin_bottom = 18
	_panel.add_theme_stylebox_override("panel", bg)
	add_child(_panel)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)

	_title_label = Label.new()
	_title_label.text = "ЖУРНАЛ КВЕСТОВ"
	_title_label.add_theme_font_size_override("font_size", 32)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.30, 1))
	_title_label.add_theme_color_override("font_outline_color", Color(0.1, 0.04, 0.02, 1))
	_title_label.add_theme_constant_override("outline_size", 4)
	col.add_child(_title_label)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	_scroll.add_child(_content)

	_hint_label = Label.new()
	_hint_label.text = "[Q] закрыть"
	_hint_label.add_theme_font_size_override("font_size", 18)
	_hint_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5, 1))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_hint_label)

func _process(_delta: float) -> void:
	if OS.has_feature("web"):
		if JavaScriptBridge.eval("typeof window._godotToggleQuestLog !== 'undefined' && window._godotToggleQuestLog"):
			JavaScriptBridge.eval("window._godotToggleQuestLog = false;")
			_toggle()
	if _visible:
		_refresh()

func _input(event: InputEvent) -> void:
	# Q — toggle. Только keyboard (touch — через кнопки UI позже)
	if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
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
		JavaScriptBridge.eval("window.gameQuestLogVisible = " + str(_visible).to_lower() + ";")

func _refresh() -> void:
	for c: Node in _content.get_children():
		c.queue_free()
	var active: Array = GameState.active_quests
	var completed_count: int = GameState.completed_quest_ids.size()
	# Заголовок с прогрессом
	_title_label.text = "ЖУРНАЛ КВЕСТОВ — " + BookwarConst.get_map_name(GameState.current_map_id)
	_title_label.text += "  (выполнено всего: " + str(completed_count) + ")"
	if active.is_empty():
		var empty := Label.new()
		empty.text = "Нет активных квестов на этой карте."
		empty.add_theme_font_size_override("font_size", 22)
		empty.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5, 1))
		_content.add_child(empty)
		return
	for q: Dictionary in active:
		var card := _build_quest_card(q)
		_content.add_child(card)

func _build_quest_card(q: Dictionary) -> Control:
	var panel := Panel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.10, 0.15, 0.95)
	sb.border_color = Color(0.45, 0.38, 0.22, 0.8)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)

	var type_label := Label.new()
	var qtype: String = String(q.get("type", ""))
	var npc: String = String(q.get("npc_name", ""))
	type_label.text = "[" + qtype.to_upper() + "]  " + npc
	type_label.add_theme_font_size_override("font_size", 18)
	type_label.add_theme_color_override("font_color", Color(0.85, 0.65, 0.30, 1))
	col.add_child(type_label)

	var desc := Label.new()
	desc.text = String(q.get("description", ""))
	desc.add_theme_font_size_override("font_size", 20)
	desc.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78, 1))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(desc)

	# Progress / status
	var status := Label.new()
	status.add_theme_font_size_override("font_size", 16)
	if qtype == "defeat":
		var qid: String = String(q.get("id", ""))
		var prog: int = int(GameState.quest_defeat_progress.get(qid, 0))
		var target: int = int(q.get("requirement", {}).get("count", 0))
		status.text = "Прогресс: " + str(prog) + " / " + str(target)
		status.add_theme_color_override("font_color", Color(0.6, 0.85, 0.55, 1))
	else:
		var can_now: bool = QuestData.can_complete(q)
		if can_now:
			status.text = "✓ Можно сдать у NPC"
			status.add_theme_color_override("font_color", Color(0.55, 0.95, 0.55, 1))
		else:
			status.text = "Условие ещё не выполнено"
			status.add_theme_color_override("font_color", Color(0.7, 0.55, 0.45, 1))
	col.add_child(status)

	# Reward
	var reward := Label.new()
	var r: Dictionary = q.get("reward", {})
	match String(r.get("type", "")):
		"letter":
			reward.text = "Награда: буква «" + String(r.get("letter", "")) + "»"
		"dots":
			reward.text = "Награда: " + str(int(r.get("amount", 0))) + " буквиц"
		_:
			reward.text = "Награда: ?"
	reward.add_theme_font_size_override("font_size", 16)
	reward.add_theme_color_override("font_color", Color(0.78, 0.75, 0.60, 1))
	col.add_child(reward)

	return panel
