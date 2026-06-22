extends Control
class_name ManualUI

const CLOSE_KEY: String = "open_manual"

var _tabs: TabContainer = null
var _close_btn: Button = null

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_layout()

func _build_layout() -> void:
	# Full-screen dim background
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.06, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Centered panel
	var panel: Panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -560.0
	panel.offset_top = -340.0
	panel.offset_right = 560.0
	panel.offset_bottom = 340.0
	add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# Title
	var title: Label = Label.new()
	title.text = "КАК ИГРАТЬ"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.30))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	title.add_theme_constant_override("outline_size", 5)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Tabbed content
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_tabs)
	_populate_tabs()

	# Close button
	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)
	_close_btn = Button.new()
	_close_btn.text = "Закрыть  [?]"
	_close_btn.custom_minimum_size = Vector2(220, 44)
	_close_btn.add_theme_font_size_override("font_size", 18)
	_close_btn.pressed.connect(hide_manual)
	btn_row.add_child(_close_btn)

func _populate_tabs() -> void:
	_add_tab("Управление", _content_controls())
	_add_tab("Буквы", _content_letters())
	_add_tab("Бой", _content_combat())
	_add_tab("Диалог", _content_dialogue())
	_add_tab("Заклинания", _content_spells())
	_add_tab("Крафт", _content_crafting())
	_add_tab("Глоссарий", _content_glossary())

func _add_tab(tab_name: String, text: String) -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.90, 0.88, 0.82))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.custom_minimum_size = Vector2(980, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll.add_child(label)
	_tabs.add_child(scroll)
	scroll.name = tab_name

func _content_controls() -> String:
	return """ЦЕЛЬ ИГРЫ
Вернуть все 33 буквы русского алфавита, разбросанные по тёмным землям. Буквы — это оружие, защита и валюта одновременно.

УПРАВЛЕНИЕ
- WASD / стрелки — движение героя
- E — взять предмет (точки, буквы)
- I — открыть / закрыть сумку (инвентарь)
- T — заговорить (если рядом монстр и есть "...")
- Пробел — пауза
- ? (кнопка справа) — этот мануал

На экране также есть кнопки: D-pad слева внизу, кнопки действий справа (Взять/Сумка/Речь). Играется и мышью, и клавиатурой.

СВЕТЛАЯ ДОЛИНА
Вы начинаете без единой буквы. Ходите по долине, собираете точки "." на земле. Три точки комбинируются в многоточие "..." — ваш единственный способ заговорить с монстрами в начале."""

func _content_letters() -> String:
	return """33 БУКВЫ = ОРУЖИЕ И ЗАЩИТА
Каждая буква имеет позицию в алфавите = скорость (1 — самая медленная, 33 — молниеносная).

ГЛАСНЫЕ (А, Е, Ё, И, О, У, Ы, Э, Ю, Я) — АТАКА.
Наносят урон врагу. Чем медленнее буква, тем мощнее удар.

СОГЛАСНЫЕ (Б, В, Г, Д...) — ЗАЩИТА.
Создают щит, поглощающий урон. Сильные щиты у медленных букв.

Ъ (твёрдый знак) — усиливает следующую защиту согласной x1.5
Ь (мягкий знак) — усиливает следующую атаку гласной x1.5

УРОВЕНЬ БУКВЫ
Уровень = количество собранных копий этой буквы. Урон/щит = сила x уровень.
1 копия А = урон 33. 3 копии А = урон 99. Буквы при бое НЕ расходуются — уровень постоянен.

ПРИМЕР
А (скорость 1, урон 33) — мощная, но ходит последней.
Я (скорость 33, урон 1) — слабая, но ходит первой."""

func _content_combat() -> String:
	return """БОЙ — КАРТОЧНЫЙ
Когда агрессивный монстр "!" настигает вас — начинается бой.

ОДНА БУКВА — ОДИН РАЗ ЗА ВЕСЬ БОЙ
В одном бою каждую букву (и заклинание) можно применить ТОЛЬКО ОДИН РАЗ.
За один ход можно сыграть несколько РАЗНЫХ букв — но каждая сгорает до конца боя.
В новом ходе можно играть лишь те буквы, что ещё не использовали. В новом бою всё сбрасывается.
Это заставляет беречь буквы и строить тактику: мощные — на потом, слабые — сейчас.
(Буквы НЕ теряются навсегда — ваш уровень букв постоянен; расход — только внутри одного боя.)

ХОД БОЯ
1. Выберите буквы из своей сумки (гласная — атака, согласная — щит).
2. Нажмите "Подтвердить ход" (или Пробел).
3. Враг тоже выбирает букву.
4. Ходы разрешаются по СКОРОСТИ: быстрые буквы (Я, Ю...) ходят первыми, медленные (А, Б...) — последними, но бьют сильнее.

УРОН И ЩИТ
- Гласная бьёт по врагу. Если у врага есть щит — сначала его пробивает.
- Согласная добавляет щит вам. Щит поглощает входящий урон.
- HP <= 0 = поражение.

ЛОГ ХОДА
После каждого хода крупным текстом: "А нанёс 66 урона enemy", "Б создал щит 32 -> player".

ТАЙМЕР
На ход даётся 10 секунд. Не успели — авто-ход (враг бьёт вас). Есть кнопка "Автобой" — ИИ сам играет раунды.

ПОБЕДА -> дроп 1-3 букв врага в вашу сумку.
ПОРАЖЕНИЕ -> возврат в долину с половиной HP."""

func _content_dialogue() -> String:
	return """МНОГОТОЧИЕ "..." — РЕЧЬ
Соберите 3 точки "." -> они комбинируются в "..." (многоточие). Это ваша способность говорить.

ДИАЛОГ С МОНСТРОМ
- Подойдите к монстру.
- Нажмите T (или кнопку "Речь").
- Расходуется 1 многоточие.
- Появляется реплика монстра.

РЕКРУТИНГ (50/50)
Когда диалог закрывается (E/T или вы отошли) — бросок:
- Успех: монстр становится вашим союзником (зелёный), следует за вами.
- Провал: монстр становится нейтральным (серый) и отступает.

ВИДЫ МОНСТРОВ
- "?" (вопрос) — патрулирует, нейтрален. С ним можно говорить.
- "!" (восклицание) — агрессивен, преследует и атакует.

СКРЫТИЕ
Встаньте на тёмный тайл (дерево, вода, камень, забор) — монстр вас потеряет из виду и начнёт искать. На траве и тропе спрятаться нельзя."""

func _content_spells() -> String:
	return """ЗАКЛИНАНИЯ — СЛОВА ИЗ БУКВ
Буквы — компоненты заклинаний. Собрав нужные буквы, вы складываете слова — мощнее отдельных букв.

ОСНОВНОЙ РОСТЕР (по алфавиту)
- БАМ (Б+А+М) — усиленная атака, двойной урон.
- БАХ (Б+А+Х) — мощный одиночный удар.
- БУМ (Б+У+М) — взрыв, пробивает щит врага.
- БУХ (Б+У+Х) — глухой удар, оглушает.
- ВЖУХ (В+Ж+У+Х) — стремительный выпад, ходит первым.
- КРЯК (К+Р+Я+К) — звуковой залп по площади.
- ТРАХ (Т+Р+А+Х) — сокрушительный удар.

КАК КАСТОВАТЬ
В бою, кроме кнопок букв, появляются кнопки открытых заклинаний. Выберите заклинание вместо буквы.
КАЖДОЕ заклинание — тоже один раз за весь бой. Буквы при касте НЕ расходуются навсегда.

СКОРОСТЬ ЗАКЛИНАНИЯ = скорость самой медленной буквы в слове. Мощные слова медленные.
Открываются рецепты у Кузнеца Слов (в деревне/цитадели)."""

func _content_crafting() -> String:
	return """КРАФТ БУКВ — ТРАНСФОРМАЦИЯ
В сумке можно изменить одну букву в другую, добавив модификатор (Ь или апостроф).

РЕЦЕПТЫ
- Б + Ь -> П  (70% успеха)
- П + Ь -> Б  (70%)
- Ф + Ь -> В  (70%)
- В + Ь -> Ф  (70%)
- М + Ь -> Н  (70%)
- Н + Ь -> М  (70%)
- Щ + ' -> Ш  (70%)
- Ш + ' -> Щ  (70%)
- С + Ь -> З  (60%)
- Д + Ь -> Т  (60%)

ИСХОД
- Успех: модификатор расходуется, целевая буква добавляется (+1 уровень).
- Неудача: буква-донор (модификатор Ь/') ТЕРЯЕТСЯ без результата.

Откройте вкладку "Крафт" в сумке, выберите букву-источник и модификатор, нажмите "Трансформировать"."""

func _content_glossary() -> String:
	return """ГЛОССАРИЙ — ОСНОВНЫЕ ПОНЯТИЯ

БУКВЫ (33 буквы алфавита) — ЕДИНСТВЕННЫЙ ресурс. Одновременно:
- ВАЛЮТА — стоимость покупки/открытия заклинаний и обмена.
- ОРУЖИЕ — гласные (А, О, У...) наносят урон врагу.
- БРОНЯ — согласные (Б, В, М...) создают щит, поглощающий урон.
- КОМПОНЕНТ ЗАКЛИНАНИЯ — из букв складываются слова-заклинания.
Уровень буквы = число собранных копий. Буквы в бою НЕ расходуются.

ТОЧКИ "." — базовый ресурс. Лежат на земле в Светлой Долине.
МНОГОТОЧИЕ "..." — РЕЧЬ. Соберите 3 точки -> комбинируются в "...".
Это единственный способ заговорить с монстром в начале игры.

ДИАЛОГ И РЕКРУТИНГ
- "?" — патруль, нейтрален. С ним говорят (расход "...").
- "!" — агрессор, атакует.
- После диалога — бросок 50/50: монстр либо Союзник (зелёный, следует за вами),
  либо Нейтрален (серый, отступает). Завербованные монстры — ваша банда.

СКРЫТИЕ — встаньте на тёмный тайл (дерево/вода/камень/забор), и монстр потеряет вас.

ПОБЕДА В РЕГИОНЕ — каждый монстр убит, завербован ИЛИ нейтрализован.

ЗАКЛИНАНИЯ (основные, по алфавиту)
БАМ · БАХ · БУМ · БУХ · ВЖУХ · КРЯК · ТРАХ
(Подробности — на вкладке "Заклинания". Пока частично реализованы.)"""

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(CLOSE_KEY):
		hide_manual()
		get_viewport().set_input_as_handled()
	elif visible and event is InputEventKey and event.pressed:
		var k: int = event.keycode
		if k == KEY_ESCAPE:
			hide_manual()
			get_viewport().set_input_as_handled()

func show_manual() -> void:
	visible = true
	if _tabs:
		_tabs.current_tab = 0
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameManualVisible = true;")

func hide_manual() -> void:
	visible = false
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameManualVisible = false;")

func is_open() -> bool:
	return visible
