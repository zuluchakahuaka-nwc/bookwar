extends Control

const HERO_AVATAR_SCRIPT: Script = preload("res://scripts/ui/hero_avatar.gd")

const WORLD_SCENE_PATH: String = "res://scenes/world/world_map.tscn"

const SKIN_TONES: Array[Color] = [
	Color(0.95, 0.80, 0.62),
	Color(0.86, 0.68, 0.50),
	Color(0.72, 0.52, 0.36),
	Color(0.55, 0.38, 0.25),
	Color(0.40, 0.27, 0.17),
]

const HAIR_COLORS: Array[Color] = [
	Color(0.12, 0.07, 0.03),
	Color(0.30, 0.18, 0.07),
	Color(0.55, 0.36, 0.14),
	Color(0.78, 0.62, 0.22),
	Color(0.82, 0.78, 0.72),
	Color(0.50, 0.18, 0.12),
	Color(0.85, 0.40, 0.70),
	Color(0.30, 0.25, 0.55),
]

const HAT_TYPES: Array[String] = [
	"none", "cap", "hood", "helmet", "crown",
	"wizard", "bandana", "wide_hat", "pointy",
]

var _heroes: Array = []
var _selected_index: int = 0
var _grid: GridContainer = null
var _detail_name: Label = null
var _detail_title: Label = null
var _detail_desc: Label = null
var _detail_letters: Label = null
var _detail_hp: Label = null
var _start_button: Button = null
var _back_button: Button = null
var _hero_cells: Array = [] 

func _ready() -> void:
	_load_heroes()
	_grid = $ScrollCol/Scroll/HeroGrid
	_detail_name = $DetailPanel/DetailName
	_detail_title = $DetailPanel/DetailTitle
	_detail_desc = $DetailPanel/DetailDesc
	_detail_letters = $DetailPanel/DetailLetters
	_detail_hp = $DetailPanel/DetailHP
	_start_button = $DetailPanel/StartButton
	_back_button = $ScrollCol/BackButton
	_build_grid()
	_select_hero(0)
	if _start_button:
		_start_button.pressed.connect(_on_start)
	if _back_button:
		_back_button.pressed.connect(_on_back)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameCharSelectLoaded = true; window.gameMenuVisible = false;")
		JavaScriptBridge.eval("window.gameSelectHeroByIndex = function(i) { window._godotSelectHero = i; };")
		JavaScriptBridge.eval("window.gameConfirmHero = function() { window._godotConfirmHero = true; };")
		JavaScriptBridge.eval("window.gameHeroCount = " + str(_heroes.size()) + ";")
	set_process(true)

func _process(_delta: float) -> void:
	if not OS.has_feature("web"):
		return
	var idx: Variant = JavaScriptBridge.eval("typeof window._godotSelectHero !== 'undefined' ? window._godotSelectHero : -1")
	if idx != null and int(idx) >= 0:
		JavaScriptBridge.eval("window._godotSelectHero = -1;")
		_select_hero(int(idx))
	if JavaScriptBridge.eval("typeof window._godotConfirmHero !== 'undefined' && window._godotConfirmHero"):
		JavaScriptBridge.eval("window._godotConfirmHero = false;")
		_on_start()

func _load_heroes() -> void:
	var file: FileAccess = FileAccess.open("res://data/heroes.json", FileAccess.READ)
	if file == null:
		return
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data: Variant = json.get_data()
		if data is Dictionary:
			_heroes = (data as Dictionary).get("heroes", [])

func _build_grid() -> void:
	if _grid == null:
		return
	for child: Node in _grid.get_children():
		child.queue_free()
	_hero_cells.clear()
	for i: int in range(_heroes.size()):
		var hero: Dictionary = _heroes[i]
		var name_str: String = String(hero.get("name", "???"))
		var app: Dictionary = _gen_appearance(i, String(hero.get("archetype", "balanced")), hero.get("color", [0.5, 0.5, 0.5]))
		# Cell container
		var cell: Panel = Panel.new()
		cell.custom_minimum_size = Vector2(115, 150)
		var sty: StyleBoxFlat = StyleBoxFlat.new()
		sty.bg_color = Color(0.10, 0.08, 0.14, 0.9)
		sty.border_width_bottom = 2
		sty.border_width_top = 2
		sty.border_width_left = 2
		sty.border_width_right = 2
		sty.border_color = Color(0.25, 0.20, 0.15, 0.6)
		sty.set_content_margin_all(3)
		cell.add_theme_stylebox_override("panel", sty)
		cell.set_meta("hero_index", i)
		# Avatar
		var avatar: Control = Control.new()
		avatar.set_script(HERO_AVATAR_SCRIPT)
		avatar.custom_minimum_size = Vector2(100, 105)
		avatar.size = Vector2(100, 105)
		avatar.set_anchors_preset(Control.PRESET_TOP_WIDE)
		avatar.offset_top = 2.0
		avatar.offset_bottom = 107.0
		avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar.set_appearance(app)
		cell.add_child(avatar)
		# Name label
		var lbl: Label = Label.new()
		lbl.text = name_str
		lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		lbl.offset_top = -38.0
		lbl.offset_bottom = -4.0
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		lbl.add_theme_constant_override("outline_size", 3)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(lbl)
		# Click handling
		cell.gui_input.connect(_on_cell_input.bind(i))
		_grid.add_child(cell)
		_hero_cells.append(cell)

func _on_cell_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_hero(idx)

func _gen_appearance(index: int, archetype: String, base_color: Array) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = index * 7919 + 1337
	var bc: Color = Color(float(base_color[0]), float(base_color[1]), float(base_color[2]))
	# Hat type influenced by archetype
	var hat: String = "none"
	match archetype:
		"mage":
			hat = ["wizard", "pointy", "hood", "wide_hat"][rng.randi() % 4]
		"warrior":
			hat = ["helmet", "cap", "none", "wide_hat"][rng.randi() % 4]
		"tank":
			hat = ["helmet", "none", "cap"][rng.randi() % 3]
		"rogue":
			hat = ["hood", "bandana", "none"][rng.randi() % 3]
		_:
			hat = HAT_TYPES[rng.randi() % HAT_TYPES.size()]
	var hat_col: Color = Color(
		clampf(bc.r * rng.randf_range(0.5, 0.9), 0.1, 1.0),
		clampf(bc.g * rng.randf_range(0.5, 0.9), 0.1, 1.0),
		clampf(bc.b * rng.randf_range(0.5, 0.9), 0.1, 1.0)
	)
	return {
		"skin": SKIN_TONES[rng.randi() % SKIN_TONES.size()],
		"shirt": bc,
		"pants": Color(clampf(bc.r * 0.4, 0.05, 0.5), clampf(bc.g * 0.4, 0.05, 0.5), clampf(bc.b * 0.4, 0.05, 0.5)),
		"hat_type": hat,
		"hat_color": hat_col,
		"hair_color": HAIR_COLORS[rng.randi() % HAIR_COLORS.size()],
		"beard": rng.randf() < 0.35,
		"eye_color": Color(0.12, 0.10, 0.08) if rng.randf() < 0.6 else Color(0.20, 0.50, 0.30),
	}

func _select_hero(index: int) -> void:
	if index < 0 or index >= _heroes.size():
		return
	_selected_index = index
	var hero: Dictionary = _heroes[index]
	if _detail_name:
		_detail_name.text = String(hero.get("name", "???"))
	if _detail_title:
		_detail_title.text = String(hero.get("title", ""))
	if _detail_desc:
		_detail_desc.text = String(hero.get("description", ""))
	if _detail_letters:
		var letters: Array = hero.get("starting_letters", [])
		_detail_letters.text = "Буквы: " + ", ".join(letters)
	if _detail_hp:
		var hp_bonus: int = int(hero.get("hp_bonus", 0))
		var hp_text: String = "HP: " + str(BookwarConst.PLAYER_MAX_HP + hp_bonus)
		if hp_bonus > 0:
			hp_text += " (+" + str(hp_bonus) + ")"
		elif hp_bonus < 0:
			hp_text += " (" + str(hp_bonus) + ")"
		_detail_hp.text = hp_text
	# Highlight selected cell
	for i: int in range(_hero_cells.size()):
		var cell: Panel = _hero_cells[i]
		var sty: StyleBoxFlat = StyleBoxFlat.new()
		if i == index:
			sty.bg_color = Color(0.20, 0.16, 0.08, 0.95)
			sty.border_color = Color(0.95, 0.82, 0.25, 1.0)
		else:
			sty.bg_color = Color(0.10, 0.08, 0.14, 0.9)
			sty.border_color = Color(0.25, 0.20, 0.15, 0.6)
		sty.border_width_bottom = 2
		sty.border_width_top = 2
		sty.border_width_left = 2
		sty.border_width_right = 2
		sty.set_content_margin_all(3)
		cell.add_theme_stylebox_override("panel", sty)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameSelectedHeroIndex = " + str(index) + "; window.gameSelectedHeroName = " + JSON.stringify(String(hero.get("name", ""))) + ";")

func _on_start() -> void:
	if _selected_index < 0 or _selected_index >= _heroes.size():
		return
	var src: Dictionary = _heroes[_selected_index]
	var app: Dictionary = _gen_appearance(_selected_index, String(src.get("archetype", "balanced")), src.get("color", [0.5, 0.5, 0.5]))
	# Deep copy — don't mutate _heroes source
	var hero: Dictionary = src.duplicate(true)
	hero["appearance"] = app.duplicate(true)
	hero["_select_index"] = _selected_index
	GameState.reset()
	GameState.selected_hero = hero
	# Apply hero starting letters to inventory (once)
	var letters: Array = hero.get("starting_letters", [])
	for l: String in letters:
		InventoryManager.add_letter(l)
	# Apply HP bonus
	var hp_bonus: int = int(hero.get("hp_bonus", 0))
	GameState.player_max_hp = BookwarConst.PLAYER_MAX_HP + hp_bonus
	GameState.player_hp = GameState.player_max_hp
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameHeroConfirmed = true; window.gameMenuVisible = false;")
	get_tree().change_scene_to_file(WORLD_SCENE_PATH)

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
