extends Control
class_name Intro

const WORLD_SCENE_PATH: String = "res://scenes/world/world_map.tscn"
const SPLASH_DIR: String = "res://assets/sprites/splash/"

var _panels: Array = [
	{ "img": "intro_1_world", "text": "Когда-то в мире звучала речь.\nЛюди писали книги, называли вещи по имени, пели песни.\nБуквы жили в каждом доме, в каждом слове." },
	{ "img": "intro_1_world", "text": "Буквы — это оружие и защита.\nБуквы — это ценность.\nБуквы — это всё." },
	{ "img": "intro_2_wizard", "text": "Но пришёл Хранитель Запрета —\nдревняя сущность, рождённая из страха\nперед силой слова. Он наложил проклятье." },
	{ "img": "intro_3_scatter", "text": "Буквы были разбросаны по тёмным землям,\nза пределы Светлой Долины.\nСпособность говорить и писать была утрачена." },
	{ "img": "intro_4_chaos", "text": "Люди перестали понимать друг друга.\nНет языка, нет слов —\nтолько хаос и молчание." },
	{ "img": "intro_5_lies", "text": "Приспешники колдуна используют только\nвыгодные им буквы, придают им свои значения.\nПроверить невозможно — все книги разрушены." },
	{ "img": "intro_6_doom", "text": "Мир погрязнет во лжи —\nесли герой не соберёт буквы,\nпобеду одержат лицемеры и лжецы." },
	{ "img": "intro_7_hero", "text": "Ты — герой. Отправляешься вернуть алфавит,\nвосстановить правду.\n\nБУКВЫ — ЭТО ИСТИНА. Собери их все." }
]

var _index: int = 0
var _tex_rect: TextureRect = null
var _text_label: Label = null
var _hint_label: Label = null
var _skip_btn: Button = null

func _ready() -> void:
	_build_ui()
	_show_panel(0)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameIntroActive = true; window.gameIntroIndex = 0;")
		JavaScriptBridge.eval("window.gameAdvanceIntro = function() { window._godotIntroAdvance = true; };")
		JavaScriptBridge.eval("window.gameSkipIntro = function() { window._godotIntroSkip = true; };")

func _process(_delta: float) -> void:
	if not OS.has_feature("web"):
		return
	if JavaScriptBridge.eval("typeof window._godotIntroAdvance !== 'undefined' && window._godotIntroAdvance"):
		JavaScriptBridge.eval("window._godotIntroAdvance = false;")
		_advance()
	if JavaScriptBridge.eval("typeof window._godotIntroSkip !== 'undefined' && window._godotIntroSkip"):
		JavaScriptBridge.eval("window._godotIntroSkip = false;")
		_finish()

func _build_ui() -> void:
	_tex_rect = TextureRect.new()
	_tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(_tex_rect)

	var panel: Panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -260.0
	panel.offset_bottom = 0.0
	var sty: StyleBoxFlat = StyleBoxFlat.new()
	sty.bg_color = Color(0.03, 0.02, 0.04, 0.78)
	sty.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", sty)
	add_child(panel)

	_text_label = Label.new()
	_text_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_text_label.offset_left = 60.0
	_text_label.offset_right = -60.0
	_text_label.offset_top = 24.0
	_text_label.offset_bottom = -36.0
	_text_label.add_theme_font_size_override("font_size", 24)
	_text_label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.80))
	_text_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_text_label.add_theme_constant_override("outline_size", 5)
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_text_label)

	_skip_btn = Button.new()
	_skip_btn.text = "Пропустить >>"
	_skip_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_skip_btn.offset_left = -200.0
	_skip_btn.offset_right = -16.0
	_skip_btn.offset_top = 16.0
	_skip_btn.offset_bottom = 56.0
	_skip_btn.add_theme_font_size_override("font_size", 16)
	_skip_btn.modulate = Color(1, 1, 1, 0.85)
	_skip_btn.pressed.connect(_finish)
	add_child(_skip_btn)

	_hint_label = Label.new()
	_hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint_label.offset_top = -34.0
	_hint_label.offset_bottom = -8.0
	_hint_label.add_theme_font_size_override("font_size", 15)
	_hint_label.add_theme_color_override("font_color", Color(0.80, 0.74, 0.55))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint_label)

func _show_panel(idx: int) -> void:
	if idx >= _panels.size():
		_finish()
		return
	_index = idx
	var p: Dictionary = _panels[idx]
	var path: String = SPLASH_DIR + String(p.get("img", "")) + ".png"
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path) as Texture2D
		if tex:
			_tex_rect.texture = tex
	if _text_label:
		_text_label.text = String(p.get("text", ""))
	if _hint_label:
		_hint_label.text = "Сцена " + str(idx + 1) + "/" + str(_panels.size()) + "   [E / Пробел / клик] — далее"
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameIntroIndex = " + str(idx) + ";")

func _advance() -> void:
	_show_panel(_index + 1)

func _finish() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameIntroActive = false;")
	GameState.set_story_flag("intro_seen", true)
	get_tree().change_scene_to_file(WORLD_SCENE_PATH)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_advance()
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
		get_viewport().set_input_as_handled()
