extends CanvasLayer
# ShopScreen — UI магазина. Открытие: диалог с NPC «Купец» (B-key shortcut нет).
# Покупка букв за буквицы. Цены зависят от позиции буквы в алфавите (§20 inverted):
#   поздние буквы (Я=33) дороже, ранние (А=1) дешевле.
#   цена = position * 5 буквиц (А=5, О=80, Я=165)

var _panel: Panel
var _title_label: Label
var _shop_grid: GridContainer
var _hint_label: Label
var _dots_label: Label
var _visible: bool = false

func _ready() -> void:
	layer = 92  # выше StatsScreen (91), QuestLog (90), HUD (80)
	_build_ui()
	visible = true
	_panel.visible = false
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameShopVisible = false;")
		JavaScriptBridge.eval("window.gameToggleShop = function() { window._godotToggleShop = true; };")
		JavaScriptBridge.eval("window.gameBuyLetter = function(letter) { if(!window._godotBuyQueue) window._godotBuyQueue=[]; window._godotBuyQueue.push(letter); return true; };")
	set_process(true)

func _build_ui() -> void:
	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = 180
	_panel.offset_right = -180
	_panel.offset_top = 80
	_panel.offset_bottom = -80
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.05, 0.08, 0.97)
	bg.border_color = Color(0.65, 0.55, 0.25, 1.0)
	bg.set_border_width_all(3)
	bg.set_content_margin_all(18)
	_panel.add_theme_stylebox_override("panel", bg)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)
	_title_label = Label.new()
	_title_label.text = "ЛАВКА КУПЦА"
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.30, 1))
	_title_label.add_theme_color_override("font_outline_color", Color(0.1, 0.04, 0.02, 1))
	_title_label.add_theme_constant_override("outline_size", 4)
	col.add_child(_title_label)
	_dots_label = Label.new()
	_dots_label.text = "Буквиц: 0"
	_dots_label.add_theme_font_size_override("font_size", 22)
	_dots_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	col.add_child(_dots_label)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	_shop_grid = GridContainer.new()
	_shop_grid.columns = 5
	_shop_grid.add_theme_constant_override("h_separation", 8)
	_shop_grid.add_theme_constant_override("v_separation", 8)
	_shop_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_shop_grid)
	_hint_label = Label.new()
	_hint_label.text = "[Esc] закрыть"
	_hint_label.add_theme_font_size_override("font_size", 18)
	_hint_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5, 1))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_hint_label)

func _process(_delta: float) -> void:
	if OS.has_feature("web"):
		if JavaScriptBridge.eval("typeof window._godotToggleShop !== 'undefined' && window._godotToggleShop"):
			JavaScriptBridge.eval("window._godotToggleShop = false;")
			_toggle()
		# Drain buy queue
		var q: Variant = JavaScriptBridge.eval("JSON.stringify(window._godotBuyQueue || [])")
		JavaScriptBridge.eval("window._godotBuyQueue = [];")
		var arr: Array = JSON.parse_string(str(q))
		if arr.size() > 0:
			for letter: String in arr:
				_do_buy(letter)
	if _visible:
		_refresh_dots()

func _toggle() -> void:
	_visible = not _visible
	_panel.visible = _visible
	if _visible:
		_refresh()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameShopVisible = " + str(_visible).to_lower() + ";")

func _refresh_dots() -> void:
	if _dots_label:
		_dots_label.text = "Буквиц: " + str(InventoryManager.get_dots())

func _refresh() -> void:
	for c: Node in _shop_grid.get_children():
		c.queue_free()
	_refresh_dots()
	# Каждая буква — карточка с ценой
	var alphabet: Array = AlphabetData.get_alphabet_snapshot()
	for letter: Dictionary in alphabet:
		var ch: String = String(letter.get("char", ""))
		var pos: int = int(letter.get("position", 0))
		var price: int = pos * 5  # §20: позже в алфавите = дороже
		var card: Button = Button.new()
		var lvl: int = InventoryManager.get_letter_level(ch)
		var have_str: String = (" (ур." + str(lvl) + ")") if lvl > 0 else ""
		card.text = ch + have_str + "\n" + str(price) + " буквиц"
		card.add_theme_font_size_override("font_size", 18)
		var can_afford: bool = InventoryManager.get_dots() >= price
		card.disabled = not can_afford
		if can_afford:
			card.modulate = Color(1.0, 0.95, 0.7)
		else:
			card.modulate = Color(0.6, 0.55, 0.45)
		card.custom_minimum_size = Vector2(120, 70)
		# Capture ch for closure
		var letter_to_buy: String = ch
		var price_for_buy: int = price
		card.pressed.connect(func() -> void:
			_buy_letter_js(letter_to_buy, price_for_buy))
		_shop_grid.add_child(card)

func _buy_letter_js(letter: String, price: int) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window._godotBuyQueue = window._godotBuyQueue || []; window._godotBuyQueue.push('" + letter + "');", true)

func _do_buy(letter: String) -> void:
	var pos: int = AlphabetData.get_letter(letter).get("position", 1)
	var price: int = pos * 5
	if InventoryManager.get_dots() < price:
		GameState.toast_requested.emit("✗ Недостаточно буквиц (нужно " + str(price) + ")")
		return
	if not InventoryManager.use_dots(price):
		return
	InventoryManager.add_letter(letter)
	GameState.toast_requested.emit("🛒 Куплена буква «" + letter + "» за " + str(price) + " буквиц")
	_refresh()
