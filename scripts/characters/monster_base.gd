extends CharacterBody2D
class_name MonsterBase

const ALLEGIANCE_HOSTILE: int = 0
const ALLEGIANCE_RECRUITED: int = 1
const ALLEGIANCE_NEUTRAL: int = 2

# Wobble (waddle) — applies to _visual_root only, so collision/detection/label
# position math stays stable while the body staggers like the hero.
const WOBBLE_AMP: float = 0.11      # max tilt in radians (~6.3°)
const WOBBLE_FREQ: float = 9.0      # step cadence (rad/s)
const WOBBLE_BOB: float = 1.5       # tiny vertical bob in px
# Alert (встрепенулся): when the monster noticed the hero (chase/suspicion/search)
# it wobbles IN PLACE at 2x amp+freq — a danger tell for the player. See §19.
const WOBBLE_ALERT_MULT: float = 2.0

@export var monster_id: String = ""
@export var monster_name: String = ""
@export var spawn_id: String = ""
@export var hp: int = 30
@export var max_hp: int = 30
@export var move_speed: float = 50.0
@export var detection_radius: float = 100.0
@export var attack_radius: float = 50.0
@export var behavior: String = "patrol"
@export var is_aggressive_flag: bool = false

var _state: String = "idle"
var _patrol_points: Array[Vector2] = []
var _current_patrol_index: int = 0
var _player_ref: Player = null
var _dialogue_data: Array = []
var _dialogue_index: int = 0
var _drop_table: Array = []
var _letters: Array = []
var _last_combat_time: float = -100.0
var _suspicion_decay: float = 0.0
var _search_timer: float = 0.0
var _allegiance: int = ALLEGIANCE_HOSTILE
var _approached: bool = false
var _follow_target: Node2D = null
var _follow_offset: Vector2 = Vector2.ZERO
var _label_ref: Label = null
var _drawn: bool = false
var _draw_type: String = ""
var _visual_root: Node2D = null
var _quest_marker: Label = null  # Q6: жёлтая '!' над '?' монстром с активным квестом
var _walk_phase: float = 0.0

signal monster_died(monster: MonsterBase)
signal monster_state_changed(monster: MonsterBase)
signal monster_recruited(monster: MonsterBase)
signal detected_player(player: Node2D)

func _ready() -> void:
	_load_monster_data()
	_state = behavior
	_setup_patrol()
	_set_initial_allegiance()
	_setup_visual()
	var detection: Area2D = get_node_or_null("DetectionArea")
	if detection:
		_ensure_detection_shape(detection)
		detection.body_entered.connect(_on_detection_body_entered)
		detection.body_exited.connect(_on_detection_body_exited)
	GameState.dialogue_ended.connect(_on_global_dialogue_ended)
	GameState.dialogue_advance.connect(_on_dialogue_advance)
	call_deferred("_apply_saved_state")

func _state_key() -> String:
	# Stable across battle reloads: prefer the spawn_id (assigned at spawn, position-independent)
	if spawn_id != "":
		return spawn_id
	return monster_id + "@" + str(int(round(global_position.x))) + "," + str(int(round(global_position.y)))

func _save_state() -> void:
	GameState.save_monster_override(_state_key(), _allegiance, _state != "dead")

func _apply_saved_state() -> void:
	var override: Dictionary = GameState.get_monster_override(_state_key())
	if override.is_empty():
		return
	var saved_allegiance: int = int(override.get("allegiance", -1))
	var saved_alive: bool = bool(override.get("alive", true))
	if not saved_alive:
		_die_silent()
		return
	if saved_allegiance == ALLEGIANCE_RECRUITED:
		_allegiance = ALLEGIANCE_RECRUITED
		_follow_target = _find_player()
		_follow_offset = Vector2(randf_range(-60.0, 60.0), randf_range(60.0, 120.0))
		collision_mask = 32
		_set_state("follow")
		_update_color()
	elif saved_allegiance == ALLEGIANCE_NEUTRAL:
		_allegiance = ALLEGIANCE_NEUTRAL
		_set_state("patrol")
		_update_color()

func _find_player() -> Node2D:
	var parent: Node = get_parent()
	if parent == null:
		return null
	for child: Node in parent.get_children():
		if child is Player:
			return child
	return null

func _die_silent() -> void:
	# Apply "already dead" state without emitting loot/die signals (restored from save)
	_set_state("dead")
	visible = false
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	var detection: Area2D = get_node_or_null("DetectionArea")
	if detection:
		detection.set_monitoring(false)
		detection.set_deferred("monitorable", false)

func mark_killed_post_combat() -> void:
	# Called by world_map on return from a player-won manual battle. The combat
	# scene already awarded loot via InventoryManager, so here we just hide +
	# persist death state — no double loot drop, no extra signals.
	_set_state("dead")
	_save_state()
	visible = false
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	var detection: Area2D = get_node_or_null("DetectionArea")
	if detection:
		detection.set_monitoring(false)
		detection.set_deferred("monitorable", false)

func _set_initial_allegiance() -> void:
	if is_aggressive_flag:
		_allegiance = ALLEGIANCE_HOSTILE
	else:
		_allegiance = ALLEGIANCE_NEUTRAL

func _setup_visual() -> void:
	# Visual pivot: holds the label + every drawn body part. Wobbling it tilts the
	# whole creature without swinging offset labels in a wide arc (the pivot sits
	# at the body's own origin, so reparenting is geometrically a no-op).
	_visual_root = Node2D.new()
	_visual_root.name = "VisualRoot"
	add_child(_visual_root)
	# Лесная тварь рисуется мельче — чтобы герой мог укрываться в зарослях рядом с ней.
	if monster_id == "forest_creature":
		_visual_root.scale = Vector2(0.75, 0.75)
	_label_ref = get_node_or_null("Label")
	if _label_ref:
		_label_ref.add_theme_font_size_override("font_size", BookwarConst.MONSTER_LABEL_SIZE)
		_label_ref.add_theme_constant_override("outline_size", 8)
		_label_ref.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		_label_ref.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		_label_ref.position = Vector2(-BookwarConst.MONSTER_LABEL_SIZE * 0.35, -BookwarConst.MONSTER_LABEL_SIZE * 0.8)
		_label_ref.reparent(_visual_root)
	# Q6: создать маркер квеста (пока невидимый) — жёлтая '!' над головой
	_build_quest_marker()
	scale = Vector2(BookwarConst.MONSTER_SCALE, BookwarConst.MONSTER_SCALE)
	if _draw_type == "znak":
		_build_evil_humanoid("znak")
		if _label_ref:
			_label_ref.text = I18n.t("monster.znak", "Sign")
			_label_ref.add_theme_font_size_override("font_size", 26)
			_label_ref.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
			_label_ref.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			_label_ref.add_theme_constant_override("outline_size", 8)
			_label_ref.position = Vector2(-35.0, -95.0)
			_label_ref.z_index = 50
			_label_ref.visible = true
	elif _draw_type == "zvuk":
		_build_evil_humanoid("zvuk")
		if _label_ref:
			_label_ref.text = I18n.t("monster.zvuk", "Sound")
			_label_ref.add_theme_font_size_override("font_size", 26)
			_label_ref.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
			_label_ref.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			_label_ref.add_theme_constant_override("outline_size", 8)
			_label_ref.position = Vector2(-35.0, -95.0)
			_label_ref.z_index = 50
			_label_ref.visible = true
	elif _draw_type in ["longtongue", "big_ears", "big_eyes", "big_mouth", "swamp_walker", "stone_chewer", "ash_priest", "crystaloid", "dark_monk"]:
		# §18.5 — named creatures per region (карта 2-10)
		_build_named_creature(_draw_type)
		if _label_ref:
			var nm: String = ""
			match _draw_type:
				"longtongue": nm = I18n.t("monster.longtongue", "Длинноязыкий")
				"big_ears":   nm = I18n.t("monster.big_ears", "Слушач")
				"big_eyes":   nm = I18n.t("monster.big_eyes", "Зрячий")
				"big_mouth":  nm = I18n.t("monster.big_mouth", "Жор")
				"swamp_walker":  nm = I18n.t("monster.swamp_walker", "Болотоход")
				"stone_chewer":  nm = I18n.t("monster.stone_chewer", "Камнегрыз")
				"ash_priest":    nm = I18n.t("monster.ash_priest", "Пепельный Жрец")
				"crystaloid":    nm = I18n.t("monster.crystaloid", "Кристалоид")
				"dark_monk":     nm = I18n.t("monster.dark_monk", "Тёмный Монах")
				"deep_miner":    nm = I18n.t("monster.deep_miner", "Шахтёр")
				"silence_wraith": nm = I18n.t("monster.silence_wraith", "Безмолвный")
				"river_horror":  nm = I18n.t("monster.river_horror", "Речной Ужас")
				"drowned_seer":  nm = I18n.t("monster.drowned_seer", "Утопленный Провидец")
				"bridge_troll":  nm = I18n.t("monster.bridge_troll", "Мостовой Тролль")
				"citadel_warden": nm = I18n.t("monster.citadel_warden", "Цитадельный Страж")
				"tower_specter": nm = I18n.t("monster.tower_specter", "Башенный Призрак")
				"void_thrall":   nm = I18n.t("monster.void_thrall", "Раб Пустоты")
				"mirror_shade":  nm = I18n.t("monster.mirror_shade", "Зеркальная Тень")
				"baneful_sage":  nm = I18n.t("monster.baneful_sage", "Зловещий Мудрец")
				"curse_knight":  nm = I18n.t("monster.curse_knight", "Рыцарь Проклятья")
				"alphabet_warden": nm = I18n.t("monster.alphabet_warden", "Хранитель Алфавита")
			_label_ref.text = nm
			_label_ref.add_theme_font_size_override("font_size", 18)
			_label_ref.add_theme_color_override("font_color", Color(0.95, 0.55, 0.30))
			_label_ref.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			_label_ref.add_theme_constant_override("outline_size", 6)
			_label_ref.position = Vector2(-50.0, -90.0)
			_label_ref.z_index = 50
			_label_ref.visible = true
	elif _draw_type == "wordsmith":
		# §16 — Кузнец Слов, friendly NPC
		_build_wordsmith()
		if _label_ref:
			_label_ref.text = I18n.t("monster.wordsmith", "Кузнец Слов")
			_label_ref.add_theme_font_size_override("font_size", 16)
			_label_ref.add_theme_color_override("font_color", Color(0.90, 0.75, 0.30))
			_label_ref.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			_label_ref.add_theme_constant_override("outline_size", 5)
			_label_ref.position = Vector2(-55.0, -100.0)
			_label_ref.z_index = 50
			_label_ref.visible = true
	elif _draw_type == "merchant":
		# §18.4 — Купец, friendly NPC, открывает магазин
		_build_merchant()
		if _label_ref:
			_label_ref.text = I18n.t("monster.merchant", "Купец")
			_label_ref.add_theme_font_size_override("font_size", 16)
			_label_ref.add_theme_color_override("font_color", Color(0.70, 0.90, 0.55))
			_label_ref.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			_label_ref.add_theme_constant_override("outline_size", 5)
			_label_ref.position = Vector2(-30.0, -100.0)
			_label_ref.z_index = 50
			_label_ref.visible = true
	elif _drawn or monster_id == "forest_creature":
		_build_creature_body()
	elif monster_id == "question" or monster_id == "exclamation":
		# Starter enemies used to be a bare "?" / "!" Label — looked like a debug
		# placeholder. Give them a small creature body (audit rec #4, 2026-07-07)
		# while keeping the punctuation glyph as a glowing "thought bubble" above
		# the head, so the player still recognises the patrol/aggression cue.
		_visual_root.scale = Vector2(0.70, 0.70)
		_build_creature_body()
		if _label_ref:
			_label_ref.visible = true
			_label_ref.position = Vector2(-22, -78)
			_label_ref.z_index = 50
			_label_ref.add_theme_font_size_override("font_size", 48)
			# Yellow "?" = curious/neutral; Red "!" = aggressive.
			var glyph_color: Color = Color(1.0, 0.95, 0.30) if monster_id == "question" else Color(1.0, 0.28, 0.20)
			_label_ref.add_theme_color_override("font_color", glyph_color)
			_label_ref.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			_label_ref.add_theme_constant_override("outline_size", 10)
	_update_color()

func _build_evil_humanoid(kind: String) -> void:
	# Hero-like but evil humanoid — sorcerer's lieutenant. Draws via Polygon2D (no external sprites).
	var body_color: Color = Color(0.18, 0.14, 0.28)
	var robe_color: Color = Color(0.12, 0.08, 0.20)
	var trim_color: Color = Color(0.80, 0.25, 0.20)
	if kind == "zvuk":
		body_color = Color(0.14, 0.18, 0.26)
		robe_color = Color(0.08, 0.10, 0.18)
		trim_color = Color(0.25, 0.60, 0.85)
	# Robe (lower body — flowing cloak)
	var robe: Polygon2D = Polygon2D.new()
	robe.polygon = PackedVector2Array([Vector2(-18, 25), Vector2(18, 25), Vector2(14, -5), Vector2(-14, -5)])
	robe.color = robe_color
	_visual_root.add_child(robe)
	# Torso
	var torso: Polygon2D = Polygon2D.new()
	torso.polygon = PackedVector2Array([Vector2(-14, -5), Vector2(14, -5), Vector2(11, -28), Vector2(-11, -28)])
	torso.color = body_color
	_visual_root.add_child(torso)
	# Trim (evil sigil stripe across chest)
	var stripe: Polygon2D = Polygon2D.new()
	stripe.polygon = PackedVector2Array([Vector2(-12, -14), Vector2(12, -14), Vector2(12, -10), Vector2(-12, -10)])
	stripe.color = trim_color
	_visual_root.add_child(stripe)
	# Head
	var head: Polygon2D = Polygon2D.new()
	head.polygon = PackedVector2Array([Vector2(-10, -28), Vector2(10, -28), Vector2(9, -48), Vector2(-9, -48)])
	head.color = Color(body_color.r * 1.15, body_color.g * 1.15, body_color.b * 1.15)
	_visual_root.add_child(head)
	# Hood (pointed — sorcerer aesthetic)
	var hood: Polygon2D = Polygon2D.new()
	hood.polygon = PackedVector2Array([Vector2(-11, -40), Vector2(0, -58), Vector2(11, -40)])
	hood.color = robe_color
	_visual_root.add_child(hood)
	# Glowing eyes (color differs per kind)
	var eye_color: Color = Color(1.0, 0.85, 0.2) if kind == "znak" else Color(0.3, 0.9, 1.0)
	for eye_offset: Vector2 in [Vector2(-4, -40), Vector2(4, -40)]:
		var eye: Polygon2D = Polygon2D.new()
		eye.polygon = PackedVector2Array([
			eye_offset + Vector2(-2.0, -1.0), eye_offset + Vector2(2.0, -1.0),
			eye_offset + Vector2(2.0, 1.0), eye_offset + Vector2(-2.0, 1.0)])
		eye.color = eye_color
		_visual_root.add_child(eye)
	# Arms (raised — menacing pose)
	for arm_x: float in [-14.0, 14.0]:
		var arm: Polygon2D = Polygon2D.new()
		var dir: float = -1.0 if arm_x < 0.0 else 1.0
		arm.polygon = PackedVector2Array([
			Vector2(arm_x, -8), Vector2(arm_x + dir * 5, -8),
			Vector2(arm_x + dir * 8, -20), Vector2(arm_x + dir * 3, -22)])
		arm.color = body_color
		_visual_root.add_child(arm)
	# Feet hint
	for foot_x: float in [-9.0, 9.0]:
		var foot: Polygon2D = Polygon2D.new()
		foot.polygon = PackedVector2Array([Vector2(foot_x - 5, 25), Vector2(foot_x + 5, 25), Vector2(foot_x + 5, 31), Vector2(foot_x - 5, 31)])
		foot.color = Color(0.05, 0.04, 0.08)
		_visual_root.add_child(foot)

# §18.5 — named creatures per region. Гуманоид + уникальная «фишка».
#   longtongue (карта 2) — длинный красный язык
#   big_ears   (карта 3) — огромные уши
#   big_eyes   (карта 4) — гигантские глаза
#   big_mouth  (карта 5) — огромный рот
# §16 — Кузнец Слов: friendly NPC, открывает крафт-UI при диалоге.
# Рисуется как гуманоид в фартуке с молотом и наковальней.
func _build_wordsmith() -> void:
	var robe_color: Color = Color(0.40, 0.30, 0.20)  # кожаный фартук
	var body_color: Color = Color(0.65, 0.55, 0.40)  # загорелая кожа
	# Ноги (видны из-под фартука)
	for fx: float in [-7.0, 7.0]:
		var leg: Polygon2D = Polygon2D.new()
		leg.polygon = PackedVector2Array([Vector2(fx-4, 18), Vector2(fx+4, 18), Vector2(fx+4, 32), Vector2(fx-4, 32)])
		leg.color = Color(0.25, 0.18, 0.10)
		_visual_root.add_child(leg)
	# Фартук (нижняя часть туловища)
	var apron: Polygon2D = Polygon2D.new()
	apron.polygon = PackedVector2Array([Vector2(-16, -5), Vector2(16, -5), Vector2(14, 22), Vector2(-14, 22)])
	apron.color = robe_color
	_visual_root.add_child(apron)
	# Торс
	var torso: Polygon2D = Polygon2D.new()
	torso.polygon = PackedVector2Array([Vector2(-13, -25), Vector2(13, -25), Vector2(11, -5), Vector2(-11, -5)])
	torso.color = body_color
	_visual_root.add_child(torso)
	# Голова
	var head: Polygon2D = Polygon2D.new()
	head.polygon = PackedVector2Array([Vector2(-9, -25), Vector2(9, -25), Vector2(8, -42), Vector2(-8, -42)])
	head.color = Color(0.80, 0.65, 0.50)
	_visual_root.add_child(head)
	# Борода (седая)
	var beard: Polygon2D = Polygon2D.new()
	beard.polygon = PackedVector2Array([Vector2(-7, -32), Vector2(7, -32), Vector2(5, -22), Vector2(-5, -22)])
	beard.color = Color(0.85, 0.85, 0.80)
	_visual_root.add_child(beard)
	# Глаза (дружелюбные, синие)
	for ex: float in [-3.5, 3.5]:
		var eye: Polygon2D = Polygon2D.new()
		eye.polygon = PackedVector2Array([Vector2(ex-1, -37), Vector2(ex+1, -37), Vector2(ex+1, -34), Vector2(ex-1, -34)])
		eye.color = Color(0.30, 0.55, 0.85)
		_visual_root.add_child(eye)
	# Молот в правой руке (золотой набалдашник)
	var hammer_handle: Polygon2D = Polygon2D.new()
	hammer_handle.polygon = PackedVector2Array([Vector2(13, -22), Vector2(16, -22), Vector2(18, -8), Vector2(15, -8)])
	hammer_handle.color = Color(0.30, 0.20, 0.10)
	_visual_root.add_child(hammer_handle)
	var hammer_head: Polygon2D = Polygon2D.new()
	hammer_head.polygon = PackedVector2Array([Vector2(11, -25), Vector2(20, -25), Vector2(19, -20), Vector2(12, -20)])
	hammer_head.color = Color(0.65, 0.55, 0.35)
	_visual_root.add_child(hammer_head)
	# Наковальня слева (серая, приземистая)
	var anvil: Polygon2D = Polygon2D.new()
	anvil.polygon = PackedVector2Array([Vector2(-22, 18), Vector2(-10, 18), Vector2(-12, 12), Vector2(-20, 12)])
	anvil.color = Color(0.30, 0.30, 0.32)
	_visual_root.add_child(anvil)
	var anvil_top: Polygon2D = Polygon2D.new()
	anvil_top.polygon = PackedVector2Array([Vector2(-24, 12), Vector2(-8, 12), Vector2(-10, 8), Vector2(-22, 8)])
	anvil_top.color = Color(0.40, 0.40, 0.42)
	_visual_root.add_child(anvil_top)

# §18.4 — Купец: friendly NPC, открывает shop UI при диалоге.
# Рисуется как гуманоид в ярком халате с мешком золота и весами.
func _build_merchant() -> void:
	var robe_color: Color = Color(0.45, 0.30, 0.55)  # яркий пурпурный халат
	# Ноги
	for fx: float in [-7.0, 7.0]:
		var leg: Polygon2D = Polygon2D.new()
		leg.polygon = PackedVector2Array([Vector2(fx-4, 18), Vector2(fx+4, 18), Vector2(fx+4, 32), Vector2(fx-4, 32)])
		leg.color = Color(0.20, 0.15, 0.10)
		_visual_root.add_child(leg)
	# Халат (длинный, до земли)
	var robe: Polygon2D = Polygon2D.new()
	robe.polygon = PackedVector2Array([Vector2(-15, -8), Vector2(15, -8), Vector2(18, 24), Vector2(-18, 24)])
	robe.color = robe_color
	_visual_root.add_child(robe)
	# Золотая оторочка халата
	var trim: Polygon2D = Polygon2D.new()
	trim.polygon = PackedVector2Array([Vector2(-15, -6), Vector2(15, -6), Vector2(15, -3), Vector2(-15, -3)])
	trim.color = Color(0.95, 0.80, 0.30)
	_visual_root.add_child(trim)
	# Торс
	var torso: Polygon2D = Polygon2D.new()
	torso.polygon = PackedVector2Array([Vector2(-12, -22), Vector2(12, -22), Vector2(11, -8), Vector2(-11, -8)])
	torso.color = Color(0.55, 0.40, 0.65)
	_visual_root.add_child(torso)
	# Голова
	var head: Polygon2D = Polygon2D.new()
	head.polygon = PackedVector2Array([Vector2(-9, -22), Vector2(9, -22), Vector2(8, -40), Vector2(-8, -40)])
	head.color = Color(0.80, 0.65, 0.50)
	_visual_root.add_child(head)
	# Тюрбан (зелёный с золотом)
	var turban: Polygon2D = Polygon2D.new()
	turban.polygon = PackedVector2Array([Vector2(-11, -38), Vector2(11, -38), Vector2(10, -46), Vector2(-10, -46)])
	turban.color = Color(0.30, 0.55, 0.35)
	_visual_root.add_child(turban)
	# Золотая капля на тюрбане
	var gem: Polygon2D = Polygon2D.new()
	gem.polygon = PackedVector2Array([Vector2(-2, -44), Vector2(2, -44), Vector2(0, -40)])
	gem.color = Color(1.0, 0.85, 0.20)
	_visual_root.add_child(gem)
	# Усы
	var mustache: Polygon2D = Polygon2D.new()
	mustache.polygon = PackedVector2Array([Vector2(-5, -30), Vector2(5, -30), Vector2(4, -27), Vector2(-4, -27)])
	mustache.color = Color(0.20, 0.10, 0.05)
	_visual_root.add_child(mustache)
	# Глаза (зелёные — символ торговца)
	for ex: float in [-3.5, 3.5]:
		var eye: Polygon2D = Polygon2D.new()
		eye.polygon = PackedVector2Array([Vector2(ex-1, -34), Vector2(ex+1, -34), Vector2(ex+1, -31), Vector2(ex-1, -31)])
		eye.color = Color(0.30, 0.65, 0.30)
		_visual_root.add_child(eye)
	# Мешок золота в левой руке (коричневый с золотыми краями)
	var sack: Polygon2D = Polygon2D.new()
	sack.polygon = PackedVector2Array([Vector2(-19, -5), Vector2(-12, -5), Vector2(-13, 6), Vector2(-18, 6)])
	sack.color = Color(0.45, 0.30, 0.15)
	_visual_root.add_child(sack)
	# Золотая монета сверху мешка
	var coin: Polygon2D = Polygon2D.new()
	coin.polygon = PackedVector2Array([Vector2(-18, -8), Vector2(-13, -8), Vector2(-13, -5), Vector2(-18, -5)])
	coin.color = Color(0.95, 0.80, 0.20)
	_visual_root.add_child(coin)

func _build_named_creature(kind: String) -> void:
	var body_color: Color = Color(0.22, 0.30, 0.20)  # зелёный болотный
	var accent: Color = Color(0.85, 0.25, 0.20)      # красный акцент
	match kind:
		"longtongue":
			body_color = Color(0.30, 0.35, 0.20)
			accent = Color(0.85, 0.20, 0.20)
		"big_ears":
			body_color = Color(0.28, 0.26, 0.20)
			accent = Color(0.65, 0.50, 0.30)
		"big_eyes":
			body_color = Color(0.20, 0.22, 0.28)
			accent = Color(0.95, 0.85, 0.30)
		"big_mouth":
			body_color = Color(0.35, 0.18, 0.18)
			accent = Color(0.30, 0.05, 0.05)
		"swamp_walker":
			body_color = Color(0.20, 0.32, 0.22)
			accent = Color(0.55, 0.75, 0.35)
		"stone_chewer":
			body_color = Color(0.40, 0.36, 0.30)
			accent = Color(0.20, 0.18, 0.16)
		"ash_priest":
			body_color = Color(0.32, 0.22, 0.20)
			accent = Color(0.95, 0.50, 0.20)
		"crystaloid":
			body_color = Color(0.30, 0.45, 0.65)
			accent = Color(0.75, 0.85, 1.0)
		"dark_monk":
			body_color = Color(0.15, 0.12, 0.20)
			accent = Color(0.55, 0.30, 0.85)
		"deep_miner":
			body_color = Color(0.32, 0.28, 0.22)
			accent = Color(0.95, 0.80, 0.30)  # фонарь на каске
		"silence_wraith":
			body_color = Color(0.55, 0.55, 0.60)
			accent = Color(0.85, 0.85, 0.95)
		"river_horror":
			body_color = Color(0.18, 0.30, 0.42)
			accent = Color(0.40, 0.70, 0.95)
		"drowned_seer":
			body_color = Color(0.20, 0.32, 0.28)
			accent = Color(0.50, 0.80, 0.55)
		"bridge_troll":
			body_color = Color(0.40, 0.32, 0.22)
			accent = Color(0.65, 0.40, 0.20)
		"citadel_warden":
			body_color = Color(0.45, 0.45, 0.48)
			accent = Color(0.85, 0.65, 0.30)  # золото на щите
		"tower_specter":
			body_color = Color(0.25, 0.18, 0.40)
			accent = Color(0.70, 0.45, 0.95)
		"void_thrall":
			body_color = Color(0.08, 0.06, 0.14)
			accent = Color(0.50, 0.30, 0.75)
		"mirror_shade":
			body_color = Color(0.70, 0.72, 0.78)
			accent = Color(0.95, 0.98, 1.0)
		"baneful_sage":
			body_color = Color(0.30, 0.10, 0.10)
			accent = Color(0.85, 0.20, 0.15)
		"curse_knight":
			body_color = Color(0.25, 0.20, 0.18)
			accent = Color(0.60, 0.30, 0.10)  # ржавчина
		"alphabet_warden":
			body_color = Color(0.50, 0.40, 0.15)
			accent = Color(1.0, 0.85, 0.20)  # золото финала
	# Torso
	var torso: Polygon2D = Polygon2D.new()
	torso.polygon = PackedVector2Array([Vector2(-16, 25), Vector2(16, 25), Vector2(12, -10), Vector2(-12, -10)])
	torso.color = body_color
	_visual_root.add_child(torso)
	# Head
	var head: Polygon2D = Polygon2D.new()
	head.polygon = PackedVector2Array([Vector2(-12, -10), Vector2(12, -10), Vector2(10, -36), Vector2(-10, -36)])
	head.color = Color(body_color.r * 1.1, body_color.g * 1.1, body_color.b * 1.1)
	_visual_root.add_child(head)
	# Уникальная деталь
	match kind:
		"longtongue":
			# Длинный язык свисает изо рта
			var tongue: Polygon2D = Polygon2D.new()
			tongue.polygon = PackedVector2Array([Vector2(-2, -28), Vector2(2, -28), Vector2(4, 20), Vector2(-4, 20)])
			tongue.color = Color(0.90, 0.20, 0.30)
			_visual_root.add_child(tongue)
			# Маленькие злые глаза
			for ex: float in [-5.0, 5.0]:
				var e: Polygon2D = Polygon2D.new()
				e.polygon = PackedVector2Array([Vector2(ex-2, -28), Vector2(ex+2, -28), Vector2(ex+2, -24), Vector2(ex-2, -24)])
				e.color = Color(1.0, 0.85, 0.20)
				_visual_root.add_child(e)
		"big_ears":
			# Огромные уши (2 больших треугольника по бокам головы)
			for ear_side: float in [-1.0, 1.0]:
				var ear: Polygon2D = Polygon2D.new()
				ear.polygon = PackedVector2Array([
					Vector2(ear_side * 10, -22),
					Vector2(ear_side * 38, -42),
					Vector2(ear_side * 28, -10),
				])
				ear.color = Color(body_color.r * 1.2, body_color.g * 1.2, body_color.b * 1.2)
				_visual_root.add_child(ear)
				# Внутреннее ухо (темнее)
				var inner: Polygon2D = Polygon2D.new()
				inner.polygon = PackedVector2Array([
					Vector2(ear_side * 13, -22),
					Vector2(ear_side * 30, -36),
					Vector2(ear_side * 24, -14),
				])
				inner.color = Color(0.45, 0.25, 0.18)
				_visual_root.add_child(inner)
			# Маленькие глаза
			for ex: float in [-4.0, 4.0]:
				var e: Polygon2D = Polygon2D.new()
				e.polygon = PackedVector2Array([Vector2(ex-1.5, -26), Vector2(ex+1.5, -26), Vector2(ex+1.5, -22), Vector2(ex-1.5, -22)])
				e.color = Color(0.30, 0.10, 0.10)
				_visual_root.add_child(e)
		"big_eyes":
			# Огромные глаза — занимают половину лица
			for ex: float in [-6.0, 6.0]:
				# Белок
				var sclera: Polygon2D = Polygon2D.new()
				sclera.polygon = PackedVector2Array([
					Vector2(ex-5, -32), Vector2(ex+5, -32),
					Vector2(ex+5, -20), Vector2(ex-5, -20)])
				sclera.color = Color(0.95, 0.92, 0.80)
				_visual_root.add_child(sclera)
				# Зрачок (жёлтый, светящийся)
				var pupil: Polygon2D = Polygon2D.new()
				pupil.polygon = PackedVector2Array([
					Vector2(ex-2, -30), Vector2(ex+2, -30),
					Vector2(ex+2, -22), Vector2(ex-2, -22)])
				pupil.color = Color(1.0, 0.75, 0.10)
				_visual_root.add_child(pupil)
		"big_mouth":
			# Огромный рот — поперёк всего лица
			var mouth: Polygon2D = Polygon2D.new()
			mouth.polygon = PackedVector2Array([
				Vector2(-14, -24), Vector2(14, -24),
				Vector2(12, -14), Vector2(-12, -14)])
			mouth.color = Color(0.10, 0.02, 0.02)
			_visual_root.add_child(mouth)
			# Зубы (маленькие треугольники)
			for tx: float in [-10.0, -5.0, 0.0, 5.0, 10.0]:
				var tooth: Polygon2D = Polygon2D.new()
				tooth.polygon = PackedVector2Array([
					Vector2(tx-1.5, -22), Vector2(tx+1.5, -22), Vector2(tx, -18)])
				tooth.color = Color(0.95, 0.92, 0.70)
				_visual_root.add_child(tooth)
			# Маленькие злые глаза над ртом
			for ex: float in [-5.0, 5.0]:
				var e: Polygon2D = Polygon2D.new()
				e.polygon = PackedVector2Array([Vector2(ex-1.5, -32), Vector2(ex+1.5, -32), Vector2(ex+1.5, -28), Vector2(ex-1.5, -28)])
				e.color = Color(1.0, 0.20, 0.10)
				_visual_root.add_child(e)
		"swamp_walker":
			# Длинные щупальца-ноги, болотный газ
			for tx: float in [-12.0, 0.0, 12.0]:
				var tentacle: Polygon2D = Polygon2D.new()
				tentacle.polygon = PackedVector2Array([
					Vector2(tx-2, 10), Vector2(tx+2, 10),
					Vector2(tx+1, 30), Vector2(tx-1, 30)
				])
				tentacle.color = Color(0.30, 0.50, 0.25)
				_visual_root.add_child(tentacle)
			# Светящийся газ на голове
			var gas: Polygon2D = Polygon2D.new()
			gas.polygon = PackedVector2Array([Vector2(-6, -42), Vector2(6, -42), Vector2(4, -50), Vector2(-4, -50)])
			gas.color = Color(0.65, 0.95, 0.55, 0.7)
			_visual_root.add_child(gas)
		"stone_chewer":
			# Огромные каменные челюсти (как капитальная арка)
			var jaw_top: Polygon2D = Polygon2D.new()
			jaw_top.polygon = PackedVector2Array([Vector2(-12, -32), Vector2(12, -32), Vector2(10, -26), Vector2(-10, -26)])
			jaw_top.color = Color(0.55, 0.50, 0.42)
			_visual_root.add_child(jaw_top)
			var jaw_bot: Polygon2D = Polygon2D.new()
			jaw_bot.polygon = PackedVector2Array([Vector2(-10, -22), Vector2(10, -22), Vector2(8, -16), Vector2(-8, -16)])
			jaw_bot.color = Color(0.45, 0.40, 0.32)
			_visual_root.add_child(jaw_bot)
			# Каменные зубы
			for tx: float in [-7.0, -3.0, 1.0, 5.0]:
				var tooth: Polygon2D = Polygon2D.new()
				tooth.polygon = PackedVector2Array([Vector2(tx-1, -28), Vector2(tx+1, -28), Vector2(tx, -24)])
				tooth.color = Color(0.75, 0.70, 0.60)
				_visual_root.add_child(tooth)
		"ash_priest":
			# Капюшон + посох
			var hood: Polygon2D = Polygon2D.new()
			hood.polygon = PackedVector2Array([Vector2(-12, -38), Vector2(12, -38), Vector2(8, -52), Vector2(-8, -52), Vector2(-14, -42)])
			hood.color = Color(0.18, 0.12, 0.10)
			_visual_root.add_child(hood)
			# Посох с огнём
			var staff: Polygon2D = Polygon2D.new()
			staff.polygon = PackedVector2Array([Vector2(14, -10), Vector2(16, -10), Vector2(16, 25), Vector2(14, 25)])
			staff.color = Color(0.30, 0.20, 0.10)
			_visual_root.add_child(staff)
			var flame: Polygon2D = Polygon2D.new()
			flame.polygon = PackedVector2Array([Vector2(11, -18), Vector2(19, -18), Vector2(17, -28), Vector2(15, -32), Vector2(13, -28)])
			flame.color = Color(0.95, 0.50, 0.15)
			_visual_root.add_child(flame)
		"crystaloid":
			# Кристаллы растут из спины
			for i: int in range(5):
				var spike: Polygon2D = Polygon2D.new()
				var sx: float = -10.0 + i * 5.0
				var sh: float = 8.0 + (i % 2) * 4.0
				spike.polygon = PackedVector2Array([
					Vector2(sx-1, -8), Vector2(sx+1, -8),
					Vector2(sx, -8 - sh)
				])
				spike.color = Color(0.55 + (i % 2) * 0.2, 0.75, 0.95, 0.85)
				_visual_root.add_child(spike)
			# Светящееся ядро в груди
			var core: Polygon2D = Polygon2D.new()
			core.polygon = PackedVector2Array([Vector2(-3, -15), Vector2(3, -15), Vector2(2, -10), Vector2(-2, -10)])
			core.color = Color(0.80, 0.95, 1.0, 0.9)
			_visual_root.add_child(core)
		"dark_monk":
			# Капюшон + свеча в руке
			var hood2: Polygon2D = Polygon2D.new()
			hood2.polygon = PackedVector2Array([Vector2(-13, -30), Vector2(13, -30), Vector2(10, -52), Vector2(-10, -52)])
			hood2.color = Color(0.08, 0.05, 0.12)
			_visual_root.add_child(hood2)
			# Свеча
			var candle: Polygon2D = Polygon2D.new()
			candle.polygon = PackedVector2Array([Vector2(13, 0), Vector2(16, 0), Vector2(16, 12), Vector2(13, 12)])
			candle.color = Color(0.85, 0.80, 0.65)
			_visual_root.add_child(candle)
			# Пламя свечи
			var flame2: Polygon2D = Polygon2D.new()
			flame2.polygon = PackedVector2Array([Vector2(13, -5), Vector2(16, -5), Vector2(15, -15), Vector2(14, -5)])
			flame2.color = Color(1.0, 0.75, 0.30)
			_visual_root.add_child(flame2)
			# Знак Запрета на груди (багровый)
			var sigil: Polygon2D = Polygon2D.new()
			sigil.polygon = PackedVector2Array([Vector2(-4, -18), Vector2(4, -18), Vector2(0, -10)])
			sigil.color = Color(0.70, 0.15, 0.40)
			_visual_root.add_child(sigil)
		"deep_miner":
			# Каска с фонарём
			var helmet: Polygon2D = Polygon2D.new()
			helmet.polygon = PackedVector2Array([Vector2(-12, -32), Vector2(12, -32), Vector2(10, -42), Vector2(-10, -42)])
			helmet.color = Color(0.55, 0.40, 0.20)
			_visual_root.add_child(helmet)
			# Светящийся фонарь на каске
			var lamp: Polygon2D = Polygon2D.new()
			lamp.polygon = PackedVector2Array([Vector2(-3, -44), Vector2(3, -44), Vector2(2, -50), Vector2(-2, -50)])
			lamp.color = Color(1.0, 0.90, 0.40)
			_visual_root.add_child(lamp)
			# Кирка в руке
			var pick: Polygon2D = Polygon2D.new()
			pick.polygon = PackedVector2Array([Vector2(14, 5), Vector2(20, 0), Vector2(22, 8), Vector2(16, 12)])
			pick.color = Color(0.45, 0.35, 0.20)
			_visual_root.add_child(pick)
		"silence_wraith":
			# Полупрозрачный капюшон-саван
			var shroud: Polygon2D = Polygon2D.new()
			shroud.polygon = PackedVector2Array([Vector2(-18, -40), Vector2(18, -40), Vector2(14, 25), Vector2(-14, 25)])
			shroud.color = Color(0.65, 0.65, 0.72, 0.55)
			_visual_root.add_child(shroud)
			# Без глаз — только тёмные провалы
			for ex: float in [-5.0, 5.0]:
				var socket: Polygon2D = Polygon2D.new()
				socket.polygon = PackedVector2Array([Vector2(ex-3, -28), Vector2(ex+3, -28), Vector2(ex+3, -22), Vector2(ex-3, -22)])
				socket.color = Color(0, 0, 0, 0.85)
				_visual_root.add_child(socket)
		"river_horror":
			# Спинные плавники
			for i: int in range(3):
				var fin: Polygon2D = Polygon2D.new()
				var fx: float = -6.0 + i * 6.0
				fin.polygon = PackedVector2Array([
					Vector2(fx-2, -22), Vector2(fx+2, -22),
					Vector2(fx, -22 - 12 + i * 2)
				])
				fin.color = Color(0.30, 0.55, 0.75)
				_visual_root.add_child(fin)
			# Жабры на шее
			for gx: float in [-8.0, 8.0]:
				var gill: Polygon2D = Polygon2D.new()
				gill.polygon = PackedVector2Array([Vector2(gx-2, -16), Vector2(gx+2, -16), Vector2(gx, -8)])
				gill.color = Color(0.55, 0.30, 0.45)
				_visual_root.add_child(gill)
		"drowned_seer":
			# Водоросли на голове
			for i: int in range(4):
				var weed: Polygon2D = Polygon2D.new()
				var wx: float = -9.0 + i * 6.0
				weed.polygon = PackedVector2Array([
					Vector2(wx-1, -36), Vector2(wx+1, -36),
					Vector2(wx+3, -36 - 10 - i * 2), Vector2(wx-3, -36 - 8 - i * 2)
				])
				weed.color = Color(0.20, 0.45, 0.30, 0.85)
				_visual_root.add_child(weed)
			# Третий глаз (провидец)
			var third: Polygon2D = Polygon2D.new()
			third.polygon = PackedVector2Array([Vector2(-2, -32), Vector2(2, -32), Vector2(2, -26), Vector2(-2, -26)])
			third.color = Color(0.30, 0.95, 0.60)
			_visual_root.add_child(third)
		"bridge_troll":
			# Большая нижняя челюсть с клыками
			var jaw: Polygon2D = Polygon2D.new()
			jaw.polygon = PackedVector2Array([Vector2(-14, -22), Vector2(14, -22), Vector2(10, -8), Vector2(-10, -8)])
			jaw.color = Color(0.30, 0.22, 0.16)
			_visual_root.add_child(jaw)
			# Два клыка
			for tx: float in [-5.0, 5.0]:
				var tusk: Polygon2D = Polygon2D.new()
				tusk.polygon = PackedVector2Array([Vector2(tx-1, -20), Vector2(tx+1, -20), Vector2(tx, -10)])
				tusk.color = Color(0.95, 0.90, 0.70)
				_visual_root.add_child(tusk)
			# Маленькие злые глаза
			for ex: float in [-7.0, 7.0]:
				var e: Polygon2D = Polygon2D.new()
				e.polygon = PackedVector2Array([Vector2(ex-2, -30), Vector2(ex+2, -30), Vector2(ex+2, -26), Vector2(ex-2, -26)])
				e.color = Color(0.95, 0.40, 0.15)
				_visual_root.add_child(e)
		"citadel_warden":
			# Шлем с гребнем
			var helm: Polygon2D = Polygon2D.new()
			helm.polygon = PackedVector2Array([Vector2(-12, -32), Vector2(12, -32), Vector2(10, -48), Vector2(-10, -48)])
			helm.color = Color(0.50, 0.50, 0.55)
			_visual_root.add_child(helm)
			# Гребень (красный)
			var crest: Polygon2D = Polygon2D.new()
			crest.polygon = PackedVector2Array([Vector2(-2, -48), Vector2(2, -48), Vector2(0, -56)])
			crest.color = Color(0.75, 0.20, 0.15)
			_visual_root.add_child(crest)
			# Щит с золотой каймой
			var shield: Polygon2D = Polygon2D.new()
			shield.polygon = PackedVector2Array([Vector2(-22, -10), Vector2(-12, -10), Vector2(-12, 15), Vector2(-22, 15)])
			shield.color = Color(0.70, 0.55, 0.25)
			_visual_root.add_child(shield)
		"tower_specter":
			# Полупрозрачное тело (летучий)
			var ecto: Polygon2D = Polygon2D.new()
			ecto.polygon = PackedVector2Array([Vector2(-14, -30), Vector2(14, -30), Vector2(18, 25), Vector2(-18, 25)])
			ecto.color = Color(0.45, 0.30, 0.65, 0.55)
			_visual_root.add_child(ecto)
			# Светящиеся лиловые глаза
			for ex: float in [-5.0, 5.0]:
				var ge: Polygon2D = Polygon2D.new()
				ge.polygon = PackedVector2Array([Vector2(ex-2, -30), Vector2(ex+2, -30), Vector2(ex+2, -24), Vector2(ex-2, -24)])
				ge.color = Color(0.85, 0.55, 1.0)
				_visual_root.add_child(ge)
			# Хвост вместо ног (призрак)
			var tail: Polygon2D = Polygon2D.new()
			tail.polygon = PackedVector2Array([Vector2(-8, 20), Vector2(8, 20), Vector2(4, 35), Vector2(0, 30), Vector2(-4, 35)])
			tail.color = Color(0.35, 0.20, 0.55, 0.6)
			_visual_root.add_child(tail)
		"void_thrall":
			# Тёмный капюшон с пурпурной каймой
			var vhood: Polygon2D = Polygon2D.new()
			vhood.polygon = PackedVector2Array([Vector2(-14, -30), Vector2(14, -30), Vector2(11, -55), Vector2(-11, -55)])
			vhood.color = Color(0.05, 0.03, 0.10)
			_visual_root.add_child(vhood)
			# Пурпурные глаза (2 пары)
			for ex: float in [-6.0, 6.0]:
				var ve: Polygon2D = Polygon2D.new()
				ve.polygon = PackedVector2Array([Vector2(ex-2, -32), Vector2(ex+2, -32), Vector2(ex+2, -26), Vector2(ex-2, -26)])
				ve.color = Color(0.65, 0.30, 0.95)
				_visual_root.add_child(ve)
			# Щупальца из спины
			for tx: float in [-8.0, 8.0]:
				var tent: Polygon2D = Polygon2D.new()
				tent.polygon = PackedVector2Array([Vector2(tx-2, -20), Vector2(tx+2, -20), Vector2(tx+8, -30), Vector2(tx+4, -32)])
				tent.color = Color(0.15, 0.10, 0.25)
				_visual_root.add_child(tent)
		"mirror_shade":
			# Серебристое тело с зеркальным отблеском
			var mirror_body: Polygon2D = Polygon2D.new()
			mirror_body.polygon = PackedVector2Array([Vector2(-15, 25), Vector2(15, 25), Vector2(12, -10), Vector2(-12, -10)])
			mirror_body.color = Color(0.85, 0.88, 0.95)
			_visual_root.add_child(mirror_body)
			# Зеркало на груди
			var disc: Polygon2D = Polygon2D.new()
			disc.polygon = PackedVector2Array([Vector2(-6, -8), Vector2(6, -8), Vector2(6, 4), Vector2(-6, 4)])
			disc.color = Color(1.0, 1.0, 1.0, 0.85)
			_visual_root.add_child(disc)
			# Два отражающих глаза
			for ex: float in [-5.0, 5.0]:
				var me: Polygon2D = Polygon2D.new()
				me.polygon = PackedVector2Array([Vector2(ex-2, -28), Vector2(ex+2, -28), Vector2(ex+2, -22), Vector2(ex-2, -22)])
				me.color = Color(0.95, 0.98, 1.0)
				_visual_root.add_child(me)
		"baneful_sage":
			# Капюшон мудреца (тёмно-красный)
			var bhood: Polygon2D = Polygon2D.new()
			bhood.polygon = PackedVector2Array([Vector2(-13, -30), Vector2(13, -30), Vector2(10, -54), Vector2(-10, -54)])
			bhood.color = Color(0.45, 0.10, 0.08)
			_visual_root.add_child(bhood)
			# Длинная седая борода
			var beard: Polygon2D = Polygon2D.new()
			beard.polygon = PackedVector2Array([Vector2(-5, -20), Vector2(5, -20), Vector2(3, 0), Vector2(-3, 0)])
			beard.color = Color(0.85, 0.82, 0.78)
			_visual_root.add_child(beard)
			# Светящийся красный глаз (один, циклоп)
			var beye: Polygon2D = Polygon2D.new()
			beye.polygon = PackedVector2Array([Vector2(-3, -30), Vector2(3, -30), Vector2(3, -22), Vector2(-3, -22)])
			beye.color = Color(1.0, 0.15, 0.10)
			_visual_root.add_child(beye)
			# Посох
			var staff: Polygon2D = Polygon2D.new()
			staff.polygon = PackedVector2Array([Vector2(15, -15), Vector2(17, -15), Vector2(17, 25), Vector2(15, 25)])
			staff.color = Color(0.30, 0.15, 0.10)
			_visual_root.add_child(staff)
		"curse_knight":
			# Закрытый шлем с прорезью
			var khelm: Polygon2D = Polygon2D.new()
			khelm.polygon = PackedVector2Array([Vector2(-12, -32), Vector2(12, -32), Vector2(10, -50), Vector2(-10, -50)])
			khelm.color = Color(0.30, 0.25, 0.20)
			_visual_root.add_child(khelm)
			# Прорезь для глаз
			var slit: Polygon2D = Polygon2D.new()
			slit.polygon = PackedVector2Array([Vector2(-6, -38), Vector2(6, -38), Vector2(6, -34), Vector2(-6, -34)])
			slit.color = Color(0.05, 0.02, 0.02)
			_visual_root.add_child(slit)
			# Ржавые пятна
			for i: int in range(3):
				var rust: Polygon2D = Polygon2D.new()
				var rx: float = -10.0 + i * 8.0
				rust.polygon = PackedVector2Array([Vector2(rx-2, 5), Vector2(rx+2, 5), Vector2(rx+1, 12), Vector2(rx-1, 12)])
				rust.color = Color(0.50, 0.25, 0.10)
				_visual_root.add_child(rust)
			# Меч
			var sword: Polygon2D = Polygon2D.new()
			sword.polygon = PackedVector2Array([Vector2(15, -5), Vector2(18, -5), Vector2(18, 30), Vector2(15, 30)])
			sword.color = Color(0.45, 0.40, 0.35)
			_visual_root.add_child(sword)
		"alphabet_warden":
			# Золотой капюшон-корона
			var crown: Polygon2D = Polygon2D.new()
			crown.polygon = PackedVector2Array([Vector2(-14, -32), Vector2(14, -32), Vector2(12, -50), Vector2(-12, -50)])
			crown.color = Color(0.85, 0.70, 0.20)
			_visual_root.add_child(crown)
			# Лучи короны
			for i: int in range(5):
				var ray: Polygon2D = Polygon2D.new()
				var rx: float = -10.0 + i * 5.0
				ray.polygon = PackedVector2Array([
					Vector2(rx-2, -50), Vector2(rx+2, -50),
					Vector2(rx, -50 - 8)
				])
				ray.color = Color(1.0, 0.85, 0.30)
				_visual_root.add_child(ray)
			# Светящиеся золотые глаза
			for ex: float in [-5.0, 5.0]:
				var ae: Polygon2D = Polygon2D.new()
				ae.polygon = PackedVector2Array([Vector2(ex-2, -28), Vector2(ex+2, -28), Vector2(ex+2, -22), Vector2(ex-2, -22)])
				ae.color = Color(1.0, 0.95, 0.50)
				_visual_root.add_child(ae)
			# Буквы на груди (3 буквы как амулет)
			for i: int in range(3):
				var amulet: Polygon2D = Polygon2D.new()
				var ax2: float = -6.0 + i * 6.0
				amulet.polygon = PackedVector2Array([Vector2(ax2-2, -8), Vector2(ax2+2, -8), Vector2(ax2+2, -2), Vector2(ax2-2, -2)])
				amulet.color = Color(1.0, 0.85, 0.20)
				_visual_root.add_child(amulet)
	# Arms (руки опущены)
	for ax: float in [-14.0, 14.0]:
		var arm: Polygon2D = Polygon2D.new()
		var dir: float = -1.0 if ax < 0.0 else 1.0
		arm.polygon = PackedVector2Array([
			Vector2(ax, -8), Vector2(ax + dir * 4, -8),
			Vector2(ax + dir * 4, 18), Vector2(ax, 18)])
		arm.color = Color(body_color.r * 0.85, body_color.g * 0.85, body_color.b * 0.85)
		_visual_root.add_child(arm)
	# Feet
	for fx: float in [-9.0, 9.0]:
		var foot: Polygon2D = Polygon2D.new()
		foot.polygon = PackedVector2Array([Vector2(fx-5, 25), Vector2(fx+5, 25), Vector2(fx+5, 31), Vector2(fx-5, 31)])
		foot.color = Color(0.08, 0.06, 0.10)
		_visual_root.add_child(foot)

func _build_creature_body() -> void:
	# Body (torso)
	var body: Polygon2D = Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(-20, 22), Vector2(20, 22), Vector2(16, -10), Vector2(-16, -10)])
	body.color = Color(0.16, 0.27, 0.15)
	_visual_root.add_child(body)
	# Shoulders/hump
	var hump: Polygon2D = Polygon2D.new()
	hump.polygon = PackedVector2Array([Vector2(-18, -8), Vector2(18, -8), Vector2(8, -22), Vector2(-8, -22)])
	hump.color = Color(0.12, 0.22, 0.12)
	_visual_root.add_child(hump)
	# Head
	var head: Polygon2D = Polygon2D.new()
	head.polygon = PackedVector2Array([Vector2(-11, -18), Vector2(11, -18), Vector2(9, -38), Vector2(-9, -38)])
	head.color = Color(0.20, 0.30, 0.17)
	_visual_root.add_child(head)
	# Snout
	var snout: Polygon2D = Polygon2D.new()
	snout.polygon = PackedVector2Array([Vector2(-5, -30), Vector2(5, -30), Vector2(4, -40), Vector2(-4, -40)])
	snout.color = Color(0.14, 0.22, 0.14)
	_visual_root.add_child(snout)
	# Glowing red eyes
	for eye_offset: Vector2 in [Vector2(-5, -30), Vector2(5, -30)]:
		var eye: Polygon2D = Polygon2D.new()
		eye.polygon = PackedVector2Array([eye_offset + Vector2(-2.5, -1.5), eye_offset + Vector2(2.5, -1.5), eye_offset + Vector2(2.5, 1.5), eye_offset + Vector2(-2.5, 1.5)])
		eye.color = Color(1.0, 0.18, 0.12)
		_visual_root.add_child(eye)
	# Claws (legs hint)
	for foot_x: float in [-13.0, 13.0]:
		var foot: Polygon2D = Polygon2D.new()
		foot.polygon = PackedVector2Array([Vector2(foot_x - 4, 22), Vector2(foot_x + 4, 22), Vector2(foot_x + 4, 30), Vector2(foot_x - 4, 30)])
		foot.color = Color(0.10, 0.18, 0.10)
		_visual_root.add_child(foot)
	# Hide the "!" symbol — the creature IS the enemy now
	if _label_ref:
		_label_ref.visible = false

func _update_color() -> void:
	match _allegiance:
		ALLEGIANCE_HOSTILE:
			modulate = Color(1.0, 0.3, 0.3)
		ALLEGIANCE_RECRUITED:
			modulate = Color(0.3, 1.0, 0.4)
		ALLEGIANCE_NEUTRAL:
			modulate = Color(0.7, 0.7, 0.7)

func _ensure_detection_shape(detection: Area2D) -> void:
	var shape_node: CollisionShape2D = detection.get_node_or_null("DetectionCollision")
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = "DetectionCollision"
		detection.add_child(shape_node)
	if shape_node.shape == null:
		shape_node.shape = CircleShape2D.new()
	if shape_node.shape is CircleShape2D:
		(shape_node.shape as CircleShape2D).radius = detection_radius

func _load_monster_data() -> void:
	var file: FileAccess = FileAccess.open("res://data/monsters.json", FileAccess.READ)
	if file == null:
		return
	var json: JSON = JSON.new()
	var err: int = json.parse(file.get_as_text())
	if err != OK:
		return
	var data: Variant = json.get_data()
	if not data is Dictionary:
		return
	var data_dict: Dictionary = data
	var monsters_arr: Variant = data_dict.get("monsters", [])
	for monster: Variant in monsters_arr:
		var monster_dict: Dictionary = monster
		var mid: String = str(monster_dict.get("id", ""))
		if mid == monster_id:
			var raw_name: String = String(monster_dict.get("name", monster_name))
			monster_name = I18n.t("monster.name." + mid, raw_name)
			hp = monster_dict.get("hp", hp)
			max_hp = hp
			move_speed = float(monster_dict.get("speed", move_speed))
			detection_radius = float(monster_dict.get("detection_radius", detection_radius))
			attack_radius = float(monster_dict.get("attack_radius", attack_radius))
			behavior = monster_dict.get("behavior", behavior)
			is_aggressive_flag = behavior == "aggressive"
			_dialogue_data = monster_dict.get("dialogue_options", [])
			_drawn = bool(monster_dict.get("drawn", false)) or monster_id == "forest_creature"
			_draw_type = str(monster_dict.get("draw_type", ""))
			# On level 2 (forest), use darker forest-themed lines for "?" and "!"
			if GameState.current_map_id == BookwarConst.MAP_TWO_LETTER_FOREST and (mid == "question" or mid == "exclamation"):
				_dialogue_data = _forest_dialogues(mid)
			_drop_table = monster_dict.get("drop_table", [])
			_letters = []
			for l: Variant in monster_dict.get("letters", []):
				_letters.append(str(l))
			break

func _forest_dialogues(mid: String) -> Array:
	if mid == "question":
		return [
			{"text": I18n.t("forest.q1", "Ты забрёл далеко, искатель букв. Здесь деревья помнят имена, которые ты забыл."), "result": "info"},
			{"text": I18n.t("forest.q2", "Я видел, как колдун резал слова на коре. Большие буквы — у корней старого дуба, к востоку."), "result": "info"},
			{"text": I18n.t("forest.q3", "Не доверяй теням. Они носят чужие лица и говорят чужими голосами."), "result": "info"}
		]
	return [
		{"text": I18n.t("forest.e1", "Стой! Этот лес — территория Хозяина. Разворачивайся и иди обратно."), "result": "slow"},
		{"text": I18n.t("forest.e2", "Хм. В тебе есть искра. Быть может, ты не добыча, а охотник. Пока живи."), "result": "slow"},
		{"text": I18n.t("forest.e3", "Когти острее любых гласных. Но слово... слово ранит глубже. Беги."), "result": "slow"}
	]

func _setup_patrol() -> void:
	var center: Vector2 = global_position
	# Clamp each patrol point inside the map so monsters never path off-map
	# (patrol drift was the main cause of "?" monsters wandering past the edge).
	_patrol_points = [
		_clamp_to_map(center + Vector2(-80.0, 0.0)),
		_clamp_to_map(center + Vector2(80.0, 0.0)),
		_clamp_to_map(center + Vector2(0.0, -80.0)),
		_clamp_to_map(center + Vector2(0.0, 80.0))
	]

func _clamp_to_map(pos: Vector2) -> Vector2:
	var max_x: float = BookwarConst.get_map_bound_max_x(GameState.current_map_id)
	var max_y: float = BookwarConst.get_map_bound_max_y(GameState.current_map_id)
	return Vector2(
		clampf(pos.x, BookwarConst.MAP_BOUND_MIN_X, max_x),
		clampf(pos.y, BookwarConst.MAP_BOUND_MIN_Y, max_y)
	)

func _physics_process(delta: float) -> void:
	match _state:
		"patrol", "idle":
			_process_patrol(delta)
		"aggressive":
			_process_patrol(delta)
		"suspicion":
			_process_suspicion(delta)
		"chase":
			_process_chase(delta)
		"search":
			_process_search(delta)
		"follow":
			_process_follow(delta)
		"dialogue", "dead":
			pass
	# Hard clamp to map bounds — patrol offsets and chase drift can otherwise
	# push monsters past the invisible boundary walls (their collision masks
	# don't all include the world layer). Keeps everyone inside the playable rect.
	# Q5: bounds динамические — зависят от текущей карты (ширина растёт 80→112).
	var _max_x: float = BookwarConst.get_map_bound_max_x(GameState.current_map_id)
	var _max_y: float = BookwarConst.get_map_bound_max_y(GameState.current_map_id)
	global_position = Vector2(
		clampf(global_position.x, BookwarConst.MAP_BOUND_MIN_X, _max_x),
		clampf(global_position.y, BookwarConst.MAP_BOUND_MIN_Y, _max_y)
	)
	# Q6: обновить видимость маркера квеста над '?' монстром
	_update_quest_marker()
	# Waddle tied to actual movement — every monster staggers like the hero.
	# Alerted monsters (noticed the hero) wobble 2x harder, even standing in place.
	var alerted: bool = _state == "chase" or _state == "suspicion" or _state == "search"
	_update_wobble(delta, velocity.length() > 5.0, alerted)

func _update_wobble(delta: float, moving: bool, alert: bool) -> void:
	if _visual_root == null:
		return
	var mult: float = WOBBLE_ALERT_MULT if alert else 1.0
	if moving or alert:
		_walk_phase += delta * WOBBLE_FREQ * mult
		_visual_root.rotation = sin(_walk_phase) * WOBBLE_AMP * mult
		_visual_root.position.y = -abs(sin(_walk_phase)) * WOBBLE_BOB * mult
	else:
		_walk_phase = 0.0
		_visual_root.rotation = lerp(_visual_root.rotation, 0.0, clampf(delta * 10.0, 0.0, 1.0))
		_visual_root.position.y = lerp(_visual_root.position.y, 0.0, clampf(delta * 10.0, 0.0, 1.0))

# Q6: построить маркер квеста над головой (пока невидимый).
# Показывается только у '?' монстров когда на карте есть активные квесты.
func _build_quest_marker() -> void:
	if _visual_root == null:
		return
	_quest_marker = Label.new()
	_quest_marker.name = "QuestMarker"
	_quest_marker.text = "!"
	_quest_marker.add_theme_font_size_override("font_size", 36)
	_quest_marker.add_theme_color_override("font_color", Color(1.0, 0.85, 0.20, 1))
	_quest_marker.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_quest_marker.add_theme_constant_override("outline_size", 6)
	_quest_marker.position = Vector2(-10.0, -110.0)
	_quest_marker.size = Vector2(40, 40)
	_quest_marker.z_index = 60
	_quest_marker.visible = false
	_visual_root.add_child(_quest_marker)

# Q6: показывать маркер если это '?' монстр и есть невыполненные квесты.
# Зелёная подсветка если квест готов к сдаче (can_complete).
func _update_quest_marker() -> void:
	if _quest_marker == null:
		return
	if monster_id != "question" or _allegiance != ALLEGIANCE_NEUTRAL:
		_quest_marker.visible = false
		return
	if GameState.active_quests.is_empty():
		_quest_marker.visible = false
		return
	_quest_marker.visible = true
	# Если хотя бы один квест готов к сдаче — зелёный, иначе жёлтый
	var any_ready: bool = false
	for q: Dictionary in GameState.active_quests:
		if QuestData.can_complete(q):
			any_ready = true
			break
	if any_ready:
		_quest_marker.add_theme_color_override("font_color", Color(0.40, 1.0, 0.40, 1))
		_quest_marker.text = "?"
	else:
		_quest_marker.add_theme_color_override("font_color", Color(1.0, 0.85, 0.20, 1))
		_quest_marker.text = "!"

func _process_patrol(_delta: float) -> void:
	if _patrol_points.size() == 0:
		return
	var target: Vector2 = _patrol_points[_current_patrol_index]
	var direction: Vector2 = (target - global_position).normalized()
	velocity = velocity.lerp(direction * move_speed, _delta * 5.0)
	move_and_slide()
	if global_position.distance_to(target) < 5.0:
		_current_patrol_index = (_current_patrol_index + 1) % _patrol_points.size()

func _process_suspicion(delta: float) -> void:
	velocity = Vector2.ZERO
	_suspicion_decay -= delta
	if _suspicion_decay <= 0.0:
		_set_state(behavior)

func _process_chase(_delta: float) -> void:
	if _player_ref == null or not is_instance_valid(_player_ref):
		_set_state(behavior)
		return
	if GameState.is_in_dialogue:
		return
	# Player hidden in dark tiles/water → lose track, enter search
	if GameState.player_hidden:
		_set_state("search")
		_search_timer = BookwarConst.SEARCH_DURATION
		return
	var direction: Vector2 = (_player_ref.global_position - global_position).normalized()
	velocity = velocity.lerp(direction * move_speed * 1.5, _delta * 6.0)
	move_and_slide()
	if global_position.distance_to(_player_ref.global_position) <= attack_radius:
		_try_attack()

func _process_search(delta: float) -> void:
	velocity = Vector2.ZERO
	_search_timer -= delta
	# If player revealed and in detection range → resume chase
	if not GameState.player_hidden and _player_ref != null and is_instance_valid(_player_ref):
		if global_position.distance_to(_player_ref.global_position) <= detection_radius:
			_set_state("chase")
			return
	if _search_timer <= 0.0:
		_player_ref = null
		_set_state(behavior)

func _process_follow(_delta: float) -> void:
	# Resolve the player dynamically (needed for recruited monsters restored after a battle reload)
	if _follow_target == null or not is_instance_valid(_follow_target):
		_follow_target = _find_player()
		if _follow_target == null:
			return
	# Recruited allies PROACTIVELY attack nearby hostile "!" monsters — but ONLY
	# when the enemy is close to the player too, so monsters never vanish from
	# the map for no visible reason. (Distant roaming kills were the bug.)
	var enemy: MonsterBase = _find_nearest_hostile(400.0)
	if enemy != null and _follow_target != null and is_instance_valid(_follow_target):
		var player_to_enemy: float = _follow_target.global_position.distance_to(enemy.global_position)
		if player_to_enemy > 220.0:
			enemy = null  # too far from the hero — don't hunt, keep following
	if enemy != null:
		var enemy_dist: float = global_position.distance_to(enemy.global_position)
		var now: float = Time.get_ticks_msec() / 1000.0
		if enemy_dist <= 70.0 and now - _last_combat_time >= 4.0 and not GameState.is_in_dialogue and not GameState.is_in_combat and GameState.combat_cooldown <= 0.0:
			_last_combat_time = now
			GameState.request_combat(enemy.monster_id, enemy.monster_name, enemy.hp, enemy._letters)
			velocity = Vector2.ZERO
			return
		# Move toward the enemy to engage
		var edir: Vector2 = (enemy.global_position - global_position).normalized()
		velocity = edir * move_speed * BookwarConst.FOLLOW_SPEED_MULT * 1.25
		move_and_slide()
		return
	# No enemy nearby: follow the hero
	var target_pos: Vector2 = _follow_target.global_position + _follow_offset
	var dist: float = global_position.distance_to(target_pos)
	if dist > 10.0:
		var direction: Vector2 = (target_pos - global_position).normalized()
		velocity = direction * move_speed * BookwarConst.FOLLOW_SPEED_MULT
		move_and_slide()
	else:
		velocity = Vector2.ZERO

func _find_nearest_hostile(range_px: float) -> MonsterBase:
	var parent: Node = get_parent()
	if parent == null:
		return null
	var best: MonsterBase = null
	var best_dist: float = range_px
	for child: Node in parent.get_children():
		if child is MonsterBase:
			var m: MonsterBase = child as MonsterBase
			if m._allegiance == ALLEGIANCE_HOSTILE and m.is_active():
				var d: float = global_position.distance_to(m.global_position)
				if d < best_dist:
					best_dist = d
					best = m
	return best

func _set_state(new_state: String) -> void:
	if _state == new_state:
		return
	_state = new_state
	monster_state_changed.emit(self)

func _on_detection_body_entered(body: Node2D) -> void:
	if body is Player:
		_approached = true
		_player_ref = body
		detected_player.emit(body)
		if GameState.is_in_dialogue:
			return
	if _allegiance == ALLEGIANCE_RECRUITED:
		return
	if _allegiance == ALLEGIANCE_NEUTRAL:
		_set_state("patrol")
		if can_dialogue() and InventoryManager.has_ellipsis():
			start_dialogue()
		return
	if is_aggressive_flag:
		_set_state("chase")
	else:
		_set_state("suspicion")
		_suspicion_decay = 2.5

func _on_detection_body_exited(body: Node2D) -> void:
	if body is Player:
		if _state == "dialogue":
			GameState.end_dialogue()
		elif _state == "chase":
			_set_state("search")
			_search_timer = BookwarConst.SEARCH_DURATION

func on_player_detected(player: Player) -> void:
	_on_detection_body_entered(player)

func can_dialogue() -> bool:
	if _allegiance == ALLEGIANCE_RECRUITED:
		return false
	return _dialogue_data.size() > 0

func start_dialogue() -> void:
	if _allegiance == ALLEGIANCE_RECRUITED:
		return
	if _dialogue_data.size() == 0:
		return
	if GameState.is_in_dialogue:
		return
	# Кузнец Слов — friendly, не требует буквиц для разговора.
	# При диалоге открывает крафт-UI.
	if _draw_type == "wordsmith" or monster_id == "wordsmith":
		_open_craft_via_npc()
		return
	# Купец — friendly, открывает магазин.
	if _draw_type == "merchant" or monster_id == "merchant":
		_open_shop_via_npc()
		return
	# Need at least 3 буквицы to speak (the 3 are consumed on recruit completion in _try_recruit)
	if not InventoryManager.has_ellipsis():
		return
	# Q4 (2026-07-07): если у этого "?" монстра есть невыполненный квест на карте,
	# пытаемся его сдать автоматически (MVP — без отдельного UI выбора квеста).
	# Это даёт рабочую RPG-механику: dialogue с NPC = сдача квеста.
	_try_hand_in_quest()
	_dialogue_index = 0
	_set_state("dialogue")
	GameState.start_dialogue()
	_show_dialogue_line(_dialogue_index)

# Q4: Автоматически сдать первый выполнимый квест из active_quests текущей карты.
# show_toast=true если квест сдан — для диагностического сообщения в dialogue.
# §16 — Кузнец Слов открывает крафт через JS bridge.
# world_map._process слушает флаг и открывает inventory+craft panel.
func _open_craft_via_npc() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window._bookwarOpenCraft = true;")
	# Также показываем первую реплику как toast
	if not _dialogue_data.is_empty():
		var text: String = String(_dialogue_data[0].get("text", ""))
		if text != "":
			GameState.toast_requested.emit("⚒ " + text.substr(0, 80))

# §18.4 — Купец открывает магазин через JS bridge.
func _open_shop_via_npc() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window._godotToggleShop = true;")
	if not _dialogue_data.is_empty():
		var text: String = String(_dialogue_data[0].get("text", ""))
		if text != "":
			GameState.toast_requested.emit("🛒 " + text.substr(0, 80))

func _try_hand_in_quest() -> void:
	if GameState.active_quests.is_empty():
		return
	# Копируем чтобы безопасно удалять из оригинала во время итерации
	var snapshot: Array = GameState.active_quests.duplicate()
	for q: Dictionary in snapshot:
		if QuestData.can_complete(q):
			# Для trade/buy — списать стоимость сейчас
			var qtype: String = String(q.get("type", ""))
			if qtype == "buy":
				var cost: int = int(q.get("cost", {}).get("amount", 0))
				if not InventoryManager.use_dots(cost):
					continue
			elif qtype == "trade":
				var give_letter: String = String(q.get("give", {}).get("letter", ""))
				if not InventoryManager.remove_letter(give_letter):
					continue
			# Сдать квест (выдаёт награду + снимает с active)
			GameState.try_complete_quest(q)

func _show_dialogue_line(index: int) -> void:
	if index >= _dialogue_data.size():
		GameState.end_dialogue()
		return
	var line: Dictionary = _dialogue_data[index]
	var text: String = line.get("text", "")
	if text == "":
		text = "..."
	GameState.set_dialogue_text(text)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameDialogueActive = true;")

func _on_dialogue_advance() -> void:
	if _state != "dialogue":
		return
	_dialogue_index += 1
	# The recruitment/speech cost (3 буквицы) was paid ONCE at start_dialogue.
	# Advancing through the remaining lines is free — no extra буквицы per line.
	if _dialogue_index < _dialogue_data.size():
		_show_dialogue_line(_dialogue_index)
	else:
		GameState.end_dialogue()

func _on_global_dialogue_ended() -> void:
	if _state == "dialogue":
		_try_recruit()

func _try_recruit() -> void:
	if _allegiance == ALLEGIANCE_RECRUITED:
		return
	# The recruitment costs exactly 3 буквицы (one speech), charged here on completion.
	InventoryManager.use_ellipsis()
	_approached = true
	var hint: String = _get_letter_direction_hint()
	var forced: int = GameState.recruit_force_result
	GameState.recruit_force_result = -1
	var roll: float
	if forced == 1:
		roll = 0.0
	elif forced == 0:
		roll = 1.0
	else:
		roll = randf()
	var msg: String = ""
	if roll < BookwarConst.RECRUIT_CHANCE:
		_allegiance = ALLEGIANCE_RECRUITED
		_follow_target = _player_ref
		_follow_offset = Vector2(randf_range(-60.0, 60.0), randf_range(60.0, 120.0))
		collision_mask = 32
		_set_state("follow")
		msg = I18n.t_fmt("recruit.success", [monster_name], "ALLY! %s: Perhaps you are no foe... I'm with you!")
		GameState.add_recruit(monster_name, _letters, hp)
		monster_recruited.emit(self)
	else:
		_allegiance = ALLEGIANCE_NEUTRAL
		_set_state("patrol")
		msg = I18n.t_fmt("recruit.fail", [monster_name], "FAIL! %s was not swayed — 3 tokens wasted.")
	if hint != "":
		msg += "\n" + hint
	_update_color()
	_save_state()
	monster_state_changed.emit(self)
	GameState.recruit_message.emit(msg)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameRecruitMsg = " + JSON.stringify(msg) + ";")

func _try_attack() -> void:
	if _player_ref == null or not is_instance_valid(_player_ref):
		return
	if GameState.is_in_dialogue:
		return
	if GameState.combat_cooldown > 0.0:
		return
	if _allegiance != ALLEGIANCE_HOSTILE:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_combat_time < BookwarConst.COMBAT_COOLDOWN_SEC:
		return
	if GameState.is_in_combat:
		return
	_last_combat_time = now
	var enemy_letters_copy: Array = _letters.duplicate()
	GameState.request_combat(monster_id, monster_name, hp, enemy_letters_copy)

func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	hp = max(0, hp - amount)
	if hp <= 0:
		_die()

func attack_me(player: Player) -> bool:
	# Player-initiated combat (F key). Works on ANY non-recruited monster —
	# including neutral "?". The target becomes hostile and combat starts,
	# so "?" monsters also "suffer losses" like "!" do (AGENTS.md §5).
	if _state == "dead":
		return false
	if _allegiance == ALLEGIANCE_RECRUITED:
		return false
	if GameState.is_in_combat:
		return false
	if GameState.combat_cooldown > 0.0:
		return false
	# F cancels any active dialogue with this monster — the player chose violence
	# over diplomacy. Flip state FIRST so the global dialogue_ended signal does
	# NOT trigger _try_recruit (no 50/50 roll when the player chose to attack).
	if _state == "dialogue":
		_set_state("patrol")
	if GameState.is_in_dialogue:
		GameState.end_dialogue()
		if OS.has_feature("web"):
			JavaScriptBridge.eval("window.gameDialogueActive = false; window.gameDialogueText = '';")
	# Turn neutral "?" hostile the moment the player attacks — no more diplomacy.
	if _allegiance != ALLEGIANCE_HOSTILE:
		_allegiance = ALLEGIANCE_HOSTILE
		_update_color()
	_approached = true
	_player_ref = player
	var now: float = Time.get_ticks_msec() / 1000.0
	_last_combat_time = now
	GameState.request_combat(monster_id, monster_name, hp, _letters.duplicate())
	return true

func _die() -> void:
	_set_state("dead")
	_save_state()
	_drop_loot()
	monster_died.emit(self)
	visible = false
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	var detection: Area2D = get_node_or_null("DetectionArea")
	if detection:
		detection.set_monitoring(false)
		detection.set_deferred("monitorable", false)

func _drop_loot() -> void:
	for drop: Dictionary in _drop_table:
		if randf() <= float(drop.get("chance", 0.0)):
			var item: String = drop.get("item", "")
			var count: int = int(drop.get("count", 1))
			for i: int in range(count):
				match item:
					"dot":
						InventoryManager.add_dots(1)
					"letter":
						if _letters.size() > 0:
							InventoryManager.add_letter(_letters[randi() % _letters.size()])

func get_allegiance() -> int:
	return _allegiance

func is_approached() -> bool:
	return _approached

func is_active() -> bool:
	return _state != "dead"

func force_neutralize() -> void:
	# Test/demo helper: turn a hostile monster neutral (counts as "resolved" for victory)
	if _state == "dead":
		return
	if _allegiance != ALLEGIANCE_NEUTRAL:
		_allegiance = ALLEGIANCE_NEUTRAL
		_set_state("patrol")
		_update_color()
		_save_state()

func get_state() -> String:
	return _state

func _get_letter_direction_hint() -> String:
	var parent: Node = get_parent()
	if parent == null:
		return ""
	var items_node: Node = parent.get_node_or_null("Items")
	if items_node == null:
		return ""
	var my_pos: Vector2 = global_position
	var best_letter: String = ""
	var best_dist: float = 999999.0
	var best_letter_pos: Vector2 = Vector2.ZERO
	for child: Node in items_node.get_children():
		if child is Area2D:
			var area: Area2D = child as Area2D
			if str(area.get("item_type")) != "letter":
				continue
			var letter_char: String = str(area.get("item_id"))
			if letter_char == "":
				continue
			var dist: float = my_pos.distance_to(area.global_position)
			if dist < best_dist:
				best_dist = dist
				best_letter = letter_char
				best_letter_pos = area.global_position
	if best_letter == "":
		return ""
	var diff: Vector2 = best_letter_pos - my_pos
	var angle: float = rad_to_deg(atan2(diff.y, diff.x))
	var dir_text: String = ""
	var landmark: String = ""
	if angle >= -45.0 and angle < 45.0:
		dir_text = I18n.t("dir.east", "to the east")
		if abs(diff.x) > 500.0:
			landmark = I18n.t("dir.edge", "at the very edge of the valley")
		else:
			landmark = I18n.t("dir.right", "just to the right")
	elif angle >= 45.0 and angle < 135.0:
		dir_text = I18n.t("dir.south", "to the south")
		if abs(diff.y) > 300.0:
			landmark = I18n.t("dir.water", "by the water, down below")
		else:
			landmark = I18n.t("dir.slope", "down the slope")
	elif angle >= -135.0 and angle < -45.0:
		dir_text = I18n.t("dir.north", "to the north")
		if abs(diff.y) > 400.0:
			landmark = I18n.t("dir.forest_edge", "toward the forest edge, up above")
		else:
			landmark = I18n.t("dir.trees", "a bit higher, by the trees")
	else:
		dir_text = I18n.t("dir.west", "to the west")
		if abs(diff.x) > 500.0:
			landmark = I18n.t("dir.thicket", "in the far thicket")
		else:
			landmark = I18n.t("dir.hill", "to the left, behind the hill")
	var dist_text: String = ""
	if best_dist < 200.0:
		dist_text = I18n.t("dir.close", "very close")
	elif best_dist < 500.0:
		dist_text = I18n.t("dir.near", "not far")
	else:
		dist_text = I18n.t("dir.far", "far, but I know the place")
	return I18n.t_fmt("dir.hint", [best_letter, dir_text, landmark, dist_text], "Listen! Seek the letter %s %s — %s. %s.")

func get_snapshot() -> Dictionary:
	return {
		"id": monster_id,
		"name": monster_name,
		"state": _state,
		"hp": hp,
		"max_hp": max_hp,
		"behavior": behavior,
		"is_aggressive": is_aggressive_flag,
		"allegiance": _allegiance,
		"approached": _approached,
		"drawn": _drawn,
		"letters": _letters.duplicate(),
		"position": {"x": global_position.x, "y": global_position.y}
	}
