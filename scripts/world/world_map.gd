extends Node2D

const DOT_SCENE: PackedScene = preload("res://scenes/world/dot_item.tscn")
const BATTLE_SCENE_PATH: String = "res://scenes/combat/battle_scene.tscn"
const CHAT_OVERLAY_SCENE: PackedScene = preload("res://scenes/ui/chat_overlay.tscn")
const QUEST_LOG_SCENE: PackedScene = preload("res://scenes/ui/quest_log.tscn")
const STATS_SCENE: PackedScene = preload("res://scenes/ui/stats_screen.tscn")
const SHOP_SCENE: PackedScene = preload("res://scenes/ui/shop_screen.tscn")
const WORLD_MP_SYNC_SCRIPT: Script = preload("res://scripts/multiplayer/world_mp_sync.gd")

const MAP_BOUND_MIN_X: float = 80.0
const MAP_BOUND_MAX_X: float = 2480.0
const MAP_BOUND_MIN_Y: float = 80.0
const MAP_BOUND_MAX_Y: float = 1840.0

var _hud: CanvasLayer = null
var _inventory: Control = null
var _test_bridge: TestBridge = null
var _monster_push_timer: float = 0.0
var _victory_timer: float = 0.0
var _victory_shown: bool = false
var _recruited_count: int = 0
var _total_items: int = 0
var _total_monsters: int = 0
var _portal_spawned: bool = false
const PORTAL_PROGRESS_THRESHOLD: float = 0.50

func _ready() -> void:
	await get_tree().process_frame
	_hud = $HUD
	_inventory = $InventoryLayer/Inventory
	# Set player start position based on current map
	var player: Node2D = $Player
	if player:
		if GameState.saved_player_position.x >= 0.0:
			player.global_position = GameState.saved_player_position
			GameState.saved_player_position = Vector2(-1.0, -1.0)
		else:
			player.global_position = BookwarConst.get_player_start(GameState.current_map_id)
	_init_test_bridge()
	_setup_monster_spawner()
	_spawn_map_items()
	_build_map_bounds()
	# Count totals (deferred — monsters spawn via call_deferred, so they aren't children yet)
	call_deferred("_count_totals")
	if _hud and _hud.has_method("set_region_name"):
		_hud.set_region_name(_region_name())
	# Per-map ambient tint
	_apply_ambient()
	# Atmospheric layer: dust motes + warm glow around player (dark-fantasy mood).
	# Procedural — no assets required. (Audit rec #5, 2026-07-07.)
	_apply_atmosphere()
	# §Polish (2026-07-08): decorative terrain — камни/грибы/кристаллы на карте
	_spawn_terrain_decor()
	# Start quest for this map (if not already completed)
	GameState.start_quest_for_map(GameState.current_map_id)
	# Show quest toast on map entry
	if not GameState.active_quest.is_empty():
		var qdesc: String = String(GameState.active_quest.get("description", ""))
		if qdesc != "":
			GameState.toast_requested.emit("📜 " + qdesc)
	# Start the background music playlist (loops for the whole game from level 1).
	Music.start()
	# Combat flow: monster requests → world transitions to battle scene
	GameState.combat_requested.connect(_on_combat_requested)
	# Signal-driven bridge: push state on change instead of every frame
	InventoryManager.inventory_changed.connect(_on_world_state_changed)
	GameState.hp_changed.connect(_on_hp_changed)
	GameState.combat_started.connect(_on_combat_started)
	GameState.combat_ended.connect(_on_combat_ended)
	GameState.dialogue_started.connect(_on_dialogue_started)
	GameState.dialogue_ended.connect(_on_dialogue_ended)
	# Журнал квестов (Q-key toggle) — всегда доступен в мире
	var quest_log: CanvasLayer = QUEST_LOG_SCENE.instantiate()
	quest_log.name = "QuestLog"
	add_child(quest_log)
	# Экран статистики (S-key / Tab toggle)
	var stats: CanvasLayer = STATS_SCENE.instantiate()
	stats.name = "StatsScreen"
	add_child(stats)
	# Экран магазина (через dialogue с merchant NPC)
	var shop: CanvasLayer = SHOP_SCENE.instantiate()
	shop.name = "ShopScreen"
	add_child(shop)
	# Multiplayer: spawn remote players layer + chat overlay (only if connected)
	if NetworkManager.is_connected_to_server():
		var mp_sync: Node2D = Node2D.new()
		mp_sync.set_script(WORLD_MP_SYNC_SCRIPT)
		mp_sync.name = "MpSync"
		add_child(mp_sync)
		var chat_overlay: CanvasLayer = CHAT_OVERLAY_SCENE.instantiate()
		chat_overlay.name = "ChatOverlay"
		add_child(chat_overlay)

func _init_test_bridge() -> void:
	# TestBridge is a child of this scene (added in tscn) OR created here
	if not has_node("TestBridge"):
		_test_bridge = TestBridge.new()
		_test_bridge.name = "TestBridge"
		add_child(_test_bridge)
	else:
		_test_bridge = $TestBridge
	# Initial bridge state
	_test_bridge.set_game_loaded(true)
	_test_bridge.set_menu_visible(false)
	_test_bridge.update_player_position(_player_start().x, _player_start().y)
	_test_bridge.update_inventory()
	_test_bridge.update_hud(_hp_text(), _dots_text(), _region_name())
	_test_bridge.set_dialogue_active(false, "")
	_test_bridge.set_in_combat(false)
	_test_bridge.set_inventory_visible(false)
	# Push real alphabet snapshot (replaces hardcoded gameAlphabetCount=33)
	_test_bridge.push_alphabet_snapshot(AlphabetData.get_alphabet_snapshot())

func _process(_delta: float) -> void:
	# Only continuous, cheap updates run per frame (player position). Everything else
	# is driven by signals (inventory/hud/combat/dialogue) or throttled.
	if _test_bridge == null:
		return
	if GameState.combat_cooldown > 0.0:
		GameState.combat_cooldown = max(0.0, GameState.combat_cooldown - _delta)
	var player: Node2D = $Player
	if player:
		_test_bridge.update_player_position(player.global_position.x, player.global_position.y)
		# Track live position so SaveManager autosave captures it for "Continue".
		GameState.saved_player_position = player.global_position
	if _test_bridge.has_select_card_callback():
		for letter: String in _test_bridge.drain_select_card_queue():
			_test_bridge.invoke_select_card(letter)
	# Test drivers (Puppeteer-initiated): add letters / dots / force combat / dialogue
	for letter: String in _test_bridge.drain_test_letter_queue():
		InventoryManager.add_letter(letter)
	var dots_to_add: int = _test_bridge.drain_test_dots()
	if dots_to_add > 0:
		InventoryManager.add_dots(dots_to_add)
	if _test_bridge.consume_test_dialogue():
		_force_nearest_dialogue()
	# §TODO#1: Buffer gameTriggerDialogue() across scenes. When e2e bot calls
	# window.gameTriggerDialogue() inside battle_scene, the flag stays set until
	# the player returns to world_map. _force_nearest_dialogue() then fires
	# reliably on the next _process tick (no physical proximity required, unlike
	# player.gd _try_dialogue which needs overlap with interaction area).
	# Use the same (X===true)?1:0 pattern as consume_test_dialogue for reliable
	# Variant->bool conversion (direct JS && expression returns unreliable type).
	if OS.has_feature("web"):
		var _dialogue_flag: int = int(JavaScriptBridge.eval("(window._godotDialogue === true) ? 1 : 0"))
		if _dialogue_flag == 1:
			JavaScriptBridge.eval("window._godotDialogue = false;")
			_force_nearest_dialogue()
	var recruit_force: int = _test_bridge.consume_recruit_force()
	if recruit_force != -1:
		GameState.recruit_force_result = recruit_force
	# Test driver: add recruited allies directly (bypass dialogue)
	for recruit: Dictionary in _test_bridge.drain_add_recruit_queue():
		var rname: String = String(recruit.get("name", "ТестСоюзник"))
		var rhp: int = int(recruit.get("hp", 30))
		var rletter: String = String(recruit.get("letter", "А"))
		GameState.add_recruit(rname, [rletter], rhp)
	if _test_bridge.consume_clear_region():
		for child: Node in get_children():
			if child is MonsterBase:
				(child as MonsterBase).force_neutralize()
	var test_map: String = _test_bridge.consume_test_map_switch()
	if test_map != "":
		GameState.current_map_id = test_map
		get_tree().change_scene_to_file("res://scenes/world/world_map.tscn")
		return
	# §16 — Кузнец Слов: открыть инвентарь + крафт-вкладку при диалоге
	if OS.has_feature("web"):
		if JavaScriptBridge.eval("typeof window._bookwarOpenCraft !== 'undefined' && window._bookwarOpenCraft"):
			JavaScriptBridge.eval("window._bookwarOpenCraft = false;")
			_open_inventory_and_craft()
	if _test_bridge.consume_test_goto_intro():
		get_tree().change_scene_to_file("res://scenes/ui/intro.tscn")
		return
	var teleport_pos: Vector2 = _test_bridge.consume_test_teleport()
	if teleport_pos != Vector2.ZERO:
		var player_node: Node2D = get_node_or_null("Player")
		if player_node:
			player_node.position = teleport_pos
	for combat: Dictionary in _test_bridge.drain_test_combat_queue():
		var letters: Array = combat.get("letters", [])
		GameState.request_combat("test", String(combat.get("name", "TestFoe")), int(combat.get("hp", BookwarConst.ENEMY_DEFAULT_HP)), letters)
	# Spell test drivers
	for word: String in _test_bridge.drain_spell_unlock_queue():
		SpellData.unlock(word)
	for word: String in _test_bridge.drain_spell_cast_queue():
		pass  # cast happens in battle scene; world just clears the queue
	_test_bridge.push_spell_snapshot()
	# Throttled monster-state snapshot (every ~0.4s) for monster-AI tests + Vision debug
	_monster_push_timer += _delta
	if _monster_push_timer >= 0.4:
		_monster_push_timer = 0.0
		_push_monster_states()
	# Check hiding (player on dark tiles)
	_check_player_hidden()
	# Victory check
	_victory_timer += _delta
	if _victory_timer >= BookwarConst.VICTORY_CHECK_INTERVAL:
		_victory_timer = 0.0
		_check_victory()

func _on_world_state_changed() -> void:
	if _test_bridge:
		_test_bridge.update_inventory()
		_test_bridge.update_hud(_hp_text(), _dots_text(), _region_name())

func _on_hp_changed(_current: int, _maximum: int) -> void:
	if _test_bridge:
		_test_bridge.update_hud(_hp_text(), _dots_text(), _region_name())

func _on_combat_started() -> void:
	if _test_bridge:
		_test_bridge.set_in_combat(true)

func _on_combat_ended(player_won: bool) -> void:
	if _test_bridge:
		_test_bridge.set_in_combat(false)
	# Quest progress: defeating an enemy counts toward the current map's quest.
	if player_won:
		GameState.quest_progress_defeat()

func _on_dialogue_started() -> void:
	if _test_bridge:
		_test_bridge.set_dialogue_active(true, "")

func _on_dialogue_ended() -> void:
	if _test_bridge:
		_test_bridge.set_dialogue_active(false, "")

func _hp_text() -> String:
	return "HP: " + str(GameState.player_hp) + "/" + str(GameState.player_max_hp)

func _dots_text() -> String:
	return "Буквицы: " + str(InventoryManager.get_dots())

func _region_name() -> String:
	return BookwarConst.get_map_name(GameState.current_map_id)

func _apply_ambient() -> void:
	# Ambient tint interpolated across the 33-level chain: level 1 = warm bright
	# noon, level 33 = cold abyssal dark. Per-map overrides kept for the first
	# three hand-tuned levels; everything else is driven by the chain index so
	# the world visibly darkens as difficulty climbs.
	var tint: Color = Color(1.0, 0.98, 0.92)  # default warm
	var idx: int = BookwarConst.get_level_index(GameState.current_map_id)
	if idx < 0:
		idx = 0
	match GameState.current_map_id:
		BookwarConst.MAP_TWO_LETTER_FOREST:    tint = Color(0.96, 0.98, 0.90)
		BookwarConst.MAP_DARK_OAKS:            tint = Color(0.92, 0.94, 1.00)
		_:
			# Smooth ramp from bright meadow (idx 0) to abyssal dark (idx 32).
			var t: float = float(idx) / 32.0
			var bright: Color = Color(1.00, 0.98, 0.90)
			var dark: Color = Color(0.42, 0.44, 0.58)
			tint = bright.lerp(dark, t)
	var ambient: CanvasModulate = CanvasModulate.new()
	ambient.name = "Ambient"
	ambient.color = tint
	add_child(ambient)

func _apply_atmosphere() -> void:
	# Dust-mote field + warm player glow. Procedural — sells the "мрачное
	# средневековье" art brief (AGENTS.md §11) without any asset work.
	# Both effects are children of the Player (which owns the Camera2D) so
	# they stay centered on screen as the camera scrolls.
	var player: Node2D = get_node_or_null("Player")
	if player == null:
		return
	var idx: int = BookwarConst.get_level_index(GameState.current_map_id)
	if idx < 0:
		idx = 0
	# Depth factor: 0 at level 1 (bright meadow), 1 at level 33 (deep dark).
	# In bright areas dust is barely visible (white motes, low alpha); in dark
	# regions it gets colder/grayer and the player glow becomes more pronounced.
	var depth: float = clamp(float(idx) / 32.0, 0.0, 1.0)
	# --- Dust motes -------------------------------------------------------
	# Slow-falling motes in screen-space — visible against the ambient tint.
	var dust: CPUParticles2D = CPUParticles2D.new()
	dust.name = "DustMotes"
	dust.amount = 40
	dust.lifetime = 9.0
	# NOTE: preprocess disabled — on weak web builds a 3s warm-up hangs the
	# first process frame and breaks regression_smoke movement timing.
	dust.preprocess = 0.0
	dust.explosiveness = 0.0
	dust.randomness = 0.6
	dust.fixed_fps = 30
	dust.emitting = true
	# Use local coords so the dust field stays centred on the player (which owns
	# the camera). World coords would make motes drift off-screen as the camera
	# scrolls, ruining the ambient feel.
	dust.local_coords = true
	# Local emission fills the viewport (player is at viewport center via camera).
	# Use the integer enum value (2 = EMISSION_SHAPE_BOX) — direct enum access
	# differs across Godot 4.x builds and can throw "Cannot find member".
	dust.emission_shape = 2  # CPUParticles2D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(720.0, 420.0, 0.0)
	# Motes drift downward and slightly sideways — looks like falling dust / pollen.
	dust.direction = Vector2(0.0, 1.0)
	dust.spread = 18.0
	dust.gravity = Vector2(0.0, 6.0)
	dust.initial_velocity_min = 4.0
	dust.initial_velocity_max = 14.0
	# Larger motes (4-7px) so they're clearly visible against any backdrop.
	dust.scale_amount_min = 3.5
	dust.scale_amount_max = 6.5
	# Bright meadow: warm cream motes. Deep maps: cold gray motes.
	var mote_color: Color = Color(1.0, 0.96, 0.82, 0.75).lerp(Color(0.62, 0.66, 0.78, 0.85), depth)
	dust.color = mote_color
	# Fade in/out across the particle lifetime so motes don't pop.
	dust.color_ramp = _build_dust_alpha_ramp()
	player.add_child(dust)
	# --- Player warm glow -------------------------------------------------
	# A soft radial sprite (no real Light2D — works on gl_compatibility without
	# a lighting pass). Sits behind the player sprite, scales with darkness.
	var glow_tex: GradientTexture2D = GradientTexture2D.new()
	# Integer enum (1 = FILL_RADIAL) — safer than the scoped name across builds.
	glow_tex.fill = 1  # GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from = Vector2(0.5, 0.5)
	glow_tex.fill_to = Vector2(1.0, 0.5)
	var g: Gradient = Gradient.new()
	g.clear()
	# Warm gold center fading to transparent. Slightly colder in deep levels.
	var warm_center: Color = Color(1.0, 0.85, 0.55, 0.85).lerp(Color(0.74, 0.82, 1.0, 0.85), depth * 0.7)
	g.add_point(0.0, warm_center)
	g.add_point(1.0, Color(1.0, 0.85, 0.55, 0.0))
	glow_tex.gradient = g
	glow_tex.width = 320
	glow_tex.height = 320
	var glow: Sprite2D = Sprite2D.new()
	glow.name = "AtmosphereGlow"
	glow.texture = glow_tex
	# In bright maps the glow is medium (alpha 0.6), in dark maps it's the
	# player's lifeline (alpha 1.0, larger radius).
	var glow_alpha: float = 0.6 + depth * 0.4
	glow.modulate = Color(1.0, 1.0, 1.0, glow_alpha)
	var glow_radius: float = 240.0 + depth * 180.0
	glow.scale = Vector2(glow_radius / 160.0, glow_radius / 160.0)
	# Sit BEHIND the player sprite (z_index lower) but above the tilemap.
	glow.z_index = -5
	glow.z_as_relative = false
	# Centre on the player's visual root (offset for wobble pivot).
	player.add_child(glow)

func _build_dust_alpha_ramp() -> Gradient:
	# Motes fade in (0→0.25), hold peak (0.25→0.75), fade out (0.75→1.0).
	# Use only the alpha channel — hue comes from `dust.color` above.
	var ramp: Gradient = Gradient.new()
	ramp.clear()
	ramp.add_point(0.0,  Color(1, 1, 1, 0.0))
	ramp.add_point(0.25, Color(1, 1, 1, 0.75))
	ramp.add_point(0.75, Color(1, 1, 1, 0.75))
	ramp.add_point(1.0,  Color(1, 1, 1, 0.0))
	return ramp

func _player_start() -> Vector2:
	return BookwarConst.get_player_start(GameState.current_map_id)

func _setup_monster_spawner() -> void:
	var spawner: Node = $MonsterSpawner
	if spawner == null:
		return
	# Use the appropriate spawner setup for the current map. For new maps (4-10)
	# we fall back to the forest spawner config which has a good mix of enemies.
	match GameState.current_map_id:
		BookwarConst.MAP_LIGHT_VALLEY:
			if spawner.has_method("setup_light_valley"):
				spawner.setup_light_valley()
		BookwarConst.MAP_DARK_OAKS:
			if spawner.has_method("setup_dark_oaks"):
				spawner.setup_dark_oaks()
		BookwarConst.MAP_TWO_LETTER_FOREST:
			if spawner.has_method("setup_two_letter_forest"):
				spawner.setup_two_letter_forest()
		_:
			# Levels 4–33: generic data-driven spawner (escalating counts/tiers,
			# final level = mass battle + evil wizard boss).
			if spawner.has_method("setup_generic"):
				spawner.setup_generic(GameState.current_map_id)
			elif spawner.has_method("setup_light_valley"):
				spawner.setup_light_valley()

# §Polish (2026-07-08): декоративные элементы окружения.
# Спавнит мелкие бесколлизионные объекты (камни, грибы, кристаллы) в случайных
# позициях карты — даёт визуальное разнообразие и атмосферу.
func _spawn_terrain_decor() -> void:
	var map_id: String = GameState.current_map_id
	var chain_idx: int = BookwarConst.MAP_CHAIN.find(map_id)
	if chain_idx < 0:
		chain_idx = 0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(map_id + "_decor")
	# Контейнер для декораций (z_index=1 — поверх тайлов, под предметами/монстрами)
	var decor_layer: Node2D = Node2D.new()
	decor_layer.name = "DecorLayer"
	decor_layer.z_index = 1
	add_child(decor_layer)
	# Тип и количество decor зависит от глубины карты
	var decor_count: int = 80 + chain_idx * 3  # 80 на карте 1, 176 на карте 33
	var max_x: float = BookwarConst.get_map_bound_max_x(map_id)
	var max_y: float = BookwarConst.get_map_bound_max_y(map_id)
	# Палитры декораций по биому
	var biome: String = "meadow"  # default
	if chain_idx >= 22:
		biome = "deep_dark"
	elif chain_idx >= 15:
		biome = "caves"
	elif chain_idx >= 8:
		biome = "swamp"
	elif chain_idx >= 4:
		biome = "dark_forest"
	elif chain_idx >= 1:
		biome = "forest"
	for i: int in range(decor_count):
		var pos := Vector2(
			rng.randf_range(BookwarConst.MAP_BOUND_MIN_X + 40, max_x - 40),
			rng.randf_range(BookwarConst.MAP_BOUND_MIN_Y + 40, max_y - 40)
		)
		var decor: Node2D = _build_one_decor(biome, rng)
		decor.global_position = pos
		decor_layer.add_child(decor)

func _build_one_decor(biome: String, rng: RandomNumberGenerator) -> Node2D:
	var parent: Node2D = Node2D.new()
	# Случайно выбираем тип в зависимости от биома
	var roll: float = rng.randf()
	match biome:
		"meadow":
			# Цветы +偶尔 stones
			if roll < 0.55:
				_build_flower(parent, rng)
			elif roll < 0.85:
				_build_grass_tuft(parent, rng)
			else:
				_build_small_stone(parent, rng)
		"forest":
			if roll < 0.40:
				_build_mushroom(parent, rng)
			elif roll < 0.70:
				_build_grass_tuft(parent, rng)
			else:
				_build_small_stone(parent, rng)
		"dark_forest":
			if roll < 0.50:
				_build_mushroom(parent, rng)
			elif roll < 0.75:
				_build_dead_leaf(parent, rng)
			else:
				_build_small_stone(parent, rng)
		"swamp":
			if roll < 0.60:
				_build_swamp_bubble(parent, rng)
			else:
				_build_dead_leaf(parent, rng)
		"caves":
			if roll < 0.50:
				_build_crystal(parent, rng)
			elif roll < 0.80:
				_build_small_stone(parent, rng)
			else:
				_build_bone(parent, rng)
		"deep_dark":
			if roll < 0.45:
				_build_crystal(parent, rng)
			elif roll < 0.75:
				_build_bone(parent, rng)
			else:
				_build_rune(parent, rng)
	parent.rotation = rng.randf_range(-0.3, 0.3)  # лёгкий случайный наклон
	parent.scale = Vector2(rng.randf_range(5.5, 7.5), rng.randf_range(5.5, 7.5))  # крупные декоры (видны на скриншоте)
	return parent

# === Конкретные декорации (через Polygon2D) ===

func _build_flower(parent: Node2D, rng: RandomNumberGenerator) -> void:
	# Стебель
	var stem: Polygon2D = Polygon2D.new()
	stem.polygon = PackedVector2Array([Vector2(-1, 6), Vector2(1, 6), Vector2(0, -3)])
	stem.color = Color(0.25, 0.50, 0.20)
	parent.add_child(stem)
	# Цветок (4 лепестка)
	var colors: Array[Color] = [Color(0.95, 0.65, 0.30), Color(0.95, 0.40, 0.40), Color(0.85, 0.75, 0.30), Color(0.65, 0.55, 0.95)]
	var pc: Color = colors[rng.randi() % colors.size()]
	for i: int in range(4):
		var angle: float = i * TAU / 4.0
		var petal: Polygon2D = Polygon2D.new()
		petal.polygon = PackedVector2Array([
			Vector2(0, -3),
			Vector2(cos(angle) * 4 - 1, sin(angle) * 4 - 3),
			Vector2(cos(angle) * 4 + 1, sin(angle) * 4 - 3),
		])
		petal.color = pc
		parent.add_child(petal)
	# Серединка
	var center: Polygon2D = Polygon2D.new()
	center.polygon = PackedVector2Array([Vector2(-1.5, -4), Vector2(1.5, -4), Vector2(1.5, -2), Vector2(-1.5, -2)])
	center.color = Color(0.95, 0.85, 0.30)
	parent.add_child(center)

func _build_grass_tuft(parent: Node2D, rng: RandomNumberGenerator) -> void:
	for i: int in range(3 + rng.randi() % 3):
		var blade: Polygon2D = Polygon2D.new()
		var x: float = (i - 1.5) * 2.0
		blade.polygon = PackedVector2Array([
			Vector2(x - 0.5, 6), Vector2(x + 0.5, 6),
			Vector2(x + rng.randf_range(-1, 1), -3 - rng.randf_range(0, 2))
		])
		blade.color = Color(0.30 + rng.randf() * 0.15, 0.55 + rng.randf() * 0.15, 0.20)
		parent.add_child(blade)

func _build_small_stone(parent: Node2D, rng: RandomNumberGenerator) -> void:
	var stone: Polygon2D = Polygon2D.new()
	var s: float = 2.5 + rng.randf() * 2.0
	stone.polygon = PackedVector2Array([
		Vector2(-s, 2), Vector2(s, 2), Vector2(s * 0.7, -s * 0.5), Vector2(-s * 0.7, -s * 0.5)
	])
	stone.color = Color(0.40 + rng.randf() * 0.10, 0.40 + rng.randf() * 0.10, 0.42)
	parent.add_child(stone)

func _build_mushroom(parent: Node2D, rng: RandomNumberGenerator) -> void:
	# Ножка
	var stalk: Polygon2D = Polygon2D.new()
	stalk.polygon = PackedVector2Array([Vector2(-1.5, 5), Vector2(1.5, 5), Vector2(1.0, -2), Vector2(-1.0, -2)])
	stalk.color = Color(0.85, 0.78, 0.65)
	parent.add_child(stalk)
	# Шляпка
	var cap: Polygon2D = Polygon2D.new()
	cap.polygon = PackedVector2Array([Vector2(-4, -2), Vector2(4, -2), Vector2(3, -5), Vector2(-3, -5)])
	var is_red: bool = rng.randf() < 0.6
	cap.color = Color(0.80, 0.20, 0.18) if is_red else Color(0.50, 0.40, 0.30)
	parent.add_child(cap)

func _build_dead_leaf(parent: Node2D, rng: RandomNumberGenerator) -> void:
	var leaf: Polygon2D = Polygon2D.new()
	leaf.polygon = PackedVector2Array([
		Vector2(-3, 2), Vector2(3, 2), Vector2(4, 0), Vector2(3, -2),
		Vector2(0, -3), Vector2(-3, -2), Vector2(-4, 0)
	])
	leaf.color = Color(0.45 + rng.randf() * 0.20, 0.30, 0.15)
	parent.add_child(leaf)

func _build_swamp_bubble(parent: Node2D, rng: RandomNumberGenerator) -> void:
	# Зелёный пузырь (болотный газ)
	var bubble: Polygon2D = Polygon2D.new()
	var r: float = 1.5 + rng.randf() * 1.5
	bubble.polygon = PackedVector2Array([
		Vector2(-r, 0), Vector2(0, -r), Vector2(r, 0), Vector2(0, r)
	])
	bubble.color = Color(0.35, 0.55, 0.30, 0.7)
	parent.add_child(bubble)

func _build_crystal(parent: Node2D, rng: RandomNumberGenerator) -> void:
	# Кристалл — гранёный
	var crystal: Polygon2D = Polygon2D.new()
	var h: float = 5.0 + rng.randf() * 4.0
	crystal.polygon = PackedVector2Array([
		Vector2(0, -h), Vector2(2, -2), Vector2(1.5, 3),
		Vector2(-1.5, 3), Vector2(-2, -2)
	])
	var colors: Array[Color] = [Color(0.55, 0.75, 0.95), Color(0.80, 0.55, 0.95), Color(0.55, 0.95, 0.75)]
	crystal.color = colors[rng.randi() % colors.size()]
	parent.add_child(crystal)

func _build_bone(parent: Node2D, rng: RandomNumberGenerator) -> void:
	# Кость (череп или берцо)
	var bone: Polygon2D = Polygon2D.new()
	bone.polygon = PackedVector2Array([
		Vector2(-4, 0), Vector2(4, 0), Vector2(4, 2), Vector2(-4, 2)
	])
	bone.color = Color(0.80, 0.78, 0.65)
	parent.add_child(bone)
	# Шарообразные концы
	for ex: float in [-4.0, 4.0]:
		var cap: Polygon2D = Polygon2D.new()
		cap.polygon = PackedVector2Array([Vector2(ex-2, -1), Vector2(ex+2, -1), Vector2(ex+2, 3), Vector2(ex-2, 3)])
		cap.color = Color(0.85, 0.82, 0.70)
		parent.add_child(cap)

func _build_rune(parent: Node2D, rng: RandomNumberGenerator) -> void:
	# Каменная плитка с руной
	var tile: Polygon2D = Polygon2D.new()
	tile.polygon = PackedVector2Array([Vector2(-4, 2), Vector2(4, 2), Vector2(3, -1), Vector2(-3, -1)])
	tile.color = Color(0.25, 0.20, 0.30)
	parent.add_child(tile)
	# Руна (горящая)
	var rune: Polygon2D = Polygon2D.new()
	rune.polygon = PackedVector2Array([
		Vector2(-1, 0), Vector2(1, 0), Vector2(1, -2),
		Vector2(0, -3), Vector2(-1, -2)
	])
	var rune_colors: Array[Color] = [Color(0.95, 0.30, 0.30), Color(0.30, 0.85, 0.95), Color(0.95, 0.85, 0.30)]
	rune.color = rune_colors[rng.randi() % rune_colors.size()]
	parent.add_child(rune)

func _spawn_map_items() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(GameState.current_map_id)
	match GameState.current_map_id:
		BookwarConst.MAP_DARK_OAKS:
			_spawn_dark_oaks_items(rng)
		BookwarConst.MAP_TWO_LETTER_FOREST:
			_spawn_forest_items(rng)
		BookwarConst.MAP_LIGHT_VALLEY:
			_spawn_light_valley_items(rng)
		_:
			# Maps 4-10: generic spawn using MAP_LETTERS for this region.
			_spawn_generic_items(rng)

func _spawn_generic_items(rng: RandomNumberGenerator) -> void:
	# Spawn dots + letters for any map. Uses MAP_LETTERS dict to pick which letters
	# are available on this map (progressive unlock).
	var items: Node2D = $Items
	if items == null:
		return
	var map_id: String = GameState.current_map_id
	var chain_idx: int = BookwarConst.MAP_CHAIN.find(map_id)
	if chain_idx < 0:
		chain_idx = 0
	# Smooth escalating ramp so richness climbs monotonically from level 1 to 33
	# with level 15 sitting at the midpoint. Anchored on level 3's hand-tuned 90
	# so there is no drop-off when the generic spawner takes over at level 4:
	#   lv4 ~97, lv15 ~174 (midpoint of 40..300), lv33 ~300 (max).
	var dot_count: int = 90 + maxi(0, chain_idx - 2) * 7
	# Source letter pool for this map. Some deep-game maps (catacombs/mines/etc.)
	# intentionally have an empty pool in MAP_LETTERS — fall back to the full
	# Russian alphabet so the spawn loop never divides by zero and the player
	# still gets *some* letter drops on every level (see LVL-1 audit, 2026-07-07).
	var fallback_letters: Array = ["А", "О", "М", "Б", "Я", "Е", "К", "Т", "Р", "Д"]
	var letters: Array = BookwarConst.MAP_LETTERS.get(map_id, fallback_letters)
	if letters == null or letters.is_empty():
		letters = fallback_letters
	var letter_count: int = 3 + chain_idx
	var idx: int = 0
	var spawn_max_x: float = BookwarConst.get_map_bound_max_x(map_id)
	var spawn_max_y: float = BookwarConst.get_map_bound_max_y(map_id)
	for i: int in range(dot_count):
		var x: float = rng.randf_range(BookwarConst.MAP_BOUND_MIN_X + 40, spawn_max_x - 40)
		var y: float = rng.randf_range(BookwarConst.MAP_BOUND_MIN_Y + 40, spawn_max_y - 40)
		_spawn_item(items, "dot", "", _clamp_pos(Vector2(x, y)), rng, map_id + ":d" + str(i))
		idx += 1
	for j: int in range(letter_count):
		var letter: String = String(letters[rng.randi() % letters.size()])
		var lx: float = rng.randf_range(BookwarConst.MAP_BOUND_MIN_X + 80, spawn_max_x - 80)
		var ly: float = rng.randf_range(BookwarConst.MAP_BOUND_MIN_Y + 80, spawn_max_y - 80)
		_spawn_item(items, "letter", letter, _clamp_pos(Vector2(lx, ly)), rng, map_id + ":l" + str(j))
		idx += 1

func _item_key(idx: int) -> String:
	return GameState.current_map_id + ":item:" + str(idx)

func _spawn_light_valley_items(rng: RandomNumberGenerator) -> void:
	var items: Node2D = $Items
	if items == null:
		return
	var p: Vector2 = BookwarConst.PLAYER_START_VALLEY
	var idx: int = 0
	# Level 1 baseline: ~40 буквиц (currency), 3 letters (А, О, М)
	for i: int in range(40):
		var px: float = p.x + rng.randf_range(-600.0, 600.0)
		var py: float = p.y + rng.randf_range(-350.0, 300.0)
		_spawn_item(items, "dot", "", _clamp_pos(Vector2(px, py)), rng, _item_key(idx))
		idx += 1
	# Spawn the three starting letters per AGENTS.md §4.5: А, О, М (big, weapons/armor)
	_spawn_letter(items, "А", _clamp_pos(p + Vector2(20.0, 20.0)), _item_key(idx)); idx += 1
	_spawn_letter(items, "О", _clamp_pos(p + Vector2(-400.0, 200.0)), _item_key(idx)); idx += 1
	_spawn_letter(items, "М", _clamp_pos(p + Vector2(300.0, 250.0)), _item_key(idx)); idx += 1

func _spawn_forest_items(rng: RandomNumberGenerator) -> void:
	var items: Node2D = $Items
	if items == null:
		return
	var p: Vector2 = BookwarConst.PLAYER_START_FOREST
	var idx: int = 0
	# Level 2 escalation: ~65 буквиц (currency) — MORE than Light Valley
	for i: int in range(65):
		var px: float = p.x + rng.randf_range(-650.0, 650.0)
		var py: float = p.y + rng.randf_range(-400.0, 300.0)
		_spawn_item(items, "dot", "", _clamp_pos(Vector2(px, py)), rng, _item_key(idx))
		idx += 1
	# Letters available in forest: Е, К, Т, Р, Д (5 letters — escalation per §18.2 map 2)
	_spawn_letter(items, "Е", _clamp_pos(p + Vector2(150.0, -200.0)), _item_key(idx)); idx += 1
	_spawn_letter(items, "К", _clamp_pos(p + Vector2(-300.0, 100.0)), _item_key(idx)); idx += 1
	_spawn_letter(items, "Т", _clamp_pos(p + Vector2(400.0, 200.0)), _item_key(idx)); idx += 1
	_spawn_letter(items, "Р", _clamp_pos(p + Vector2(-450.0, -250.0)), _item_key(idx)); idx += 1
	_spawn_letter(items, "Д", _clamp_pos(p + Vector2(500.0, -100.0)), _item_key(idx)); idx += 1

func _spawn_dark_oaks_items(rng: RandomNumberGenerator) -> void:
	var items: Node2D = $Items
	if items == null:
		return
	var p: Vector2 = BookwarConst.PLAYER_START_DARK_OAKS
	var idx: int = 0
	# Level 3 escalation: ~90 буквиц (currency) — the richest map (danger = reward)
	for i: int in range(90):
		var px: float = p.x + rng.randf_range(-700.0, 700.0)
		var py: float = p.y + rng.randf_range(-400.0, 300.0)
		_spawn_item(items, "dot", "", _clamp_pos(Vector2(px, py)), rng, _item_key(idx))
		idx += 1
	# Letters available in dark oaks: В, Г, Ж, Л, П, Н (6 letters per §18.2 map 3)
	_spawn_letter(items, "В", _clamp_pos(p + Vector2(200.0, -150.0)), _item_key(idx)); idx += 1
	_spawn_letter(items, "Г", _clamp_pos(p + Vector2(-350.0, 200.0)), _item_key(idx)); idx += 1
	_spawn_letter(items, "Ж", _clamp_pos(p + Vector2(400.0, 250.0)), _item_key(idx)); idx += 1
	_spawn_letter(items, "Л", _clamp_pos(p + Vector2(-500.0, -200.0)), _item_key(idx)); idx += 1
	_spawn_letter(items, "П", _clamp_pos(p + Vector2(550.0, -100.0)), _item_key(idx)); idx += 1
	_spawn_letter(items, "Н", _clamp_pos(p + Vector2(-200.0, 300.0)), _item_key(idx)); idx += 1

const CURRENCY_COLORS: Array[Color] = [
	Color(1.0, 0.80, 0.30), Color(0.90, 0.60, 0.90), Color(0.55, 0.90, 0.70),
	Color(0.65, 0.78, 1.00), Color(1.00, 0.65, 0.55), Color(0.95, 0.95, 0.60)
]
const CURRENCY_LETTERS: Array[String] = [
	"А","Б","В","Г","Д","Е","Ж","З","И","К","Л","М","Н","О","П","Р","С","Т","У","Ф","Х","Ц","Я","Ю","Э","Ы","Й"
]

func _clamp_pos(pos: Vector2) -> Vector2:
	# Q5: bounds динамические — зависят от текущей карты
	var max_x: float = BookwarConst.get_map_bound_max_x(GameState.current_map_id)
	var max_y: float = BookwarConst.get_map_bound_max_y(GameState.current_map_id)
	return Vector2(
		clampf(pos.x, MAP_BOUND_MIN_X, max_x),
		clampf(pos.y, MAP_BOUND_MIN_Y, max_y)
	)

func _spawn_item(parent: Node2D, item_type: String, item_id: String, pos: Vector2, rng: RandomNumberGenerator, key: String) -> void:
	# Already collected earlier (before a battle) — do NOT respawn
	if GameState.is_item_collected(key):
		return
	var item: Area2D = DOT_SCENE.instantiate()
	item.global_position = pos
	item.collected_key = key
	var label: Node = item.get_node_or_null("Label")
	var glow: Node = item.get_node_or_null("GlowBg")
	if item_type == "dot":
		# Currency pickup (Буквицы): a SMALL random letter of a random color, tilted at a random angle
		var ch: String = CURRENCY_LETTERS[rng.randi() % CURRENCY_LETTERS.size()]
		var col: Color = CURRENCY_COLORS[rng.randi() % CURRENCY_COLORS.size()]
		item.rotation = deg_to_rad(rng.randf_range(1.0, 180.0))
		if label:
			label.text = ch
			label.add_theme_font_size_override("font_size", 15)
			label.add_theme_color_override("font_color", col)
			label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			label.add_theme_constant_override("outline_size", 4)
		if glow:
			glow.color = Color(col.r, col.g, col.b, 0.18)
			glow.offset_left = -7.0
			glow.offset_top = -7.0
			glow.offset_right = 7.0
			glow.offset_bottom = 7.0
	else:
		item.item_type = item_type
		item.item_id = item_id
		item.interaction_name = item_id
		# BIG letter: red = vowel (attack), blue = consonant (armor), purple = sign
		if label:
			label.text = item_id
			label.add_theme_font_size_override("font_size", 36)
			var data: Dictionary = AlphabetData.get_letter(item_id)
			var t: String = String(data.get("type", ""))
			var lc: Color = Color(1.0, 0.32, 0.30)
			if t == "consonant":
				lc = Color(0.40, 0.62, 1.0)
			elif t == "sign":
				lc = Color(0.90, 0.55, 1.0)
			label.add_theme_color_override("font_color", lc)
			label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			label.add_theme_constant_override("outline_size", 6)
		if glow:
			glow.color = Color(1.0, 0.85, 0.4, 0.28)
			glow.offset_left = -16.0
			glow.offset_top = -16.0
			glow.offset_right = 16.0
			glow.offset_bottom = 16.0
	parent.add_child(item)

func _spawn_letter(parent: Node2D, letter_char: String, pos: Vector2, key: String) -> void:
	_spawn_item(parent, "letter", letter_char, pos, null, key)

func _push_monster_states() -> void:
	if _test_bridge == null:
		return
	var snapshots: Array = []
	for child: Node in get_children():
		if child is MonsterBase:
			snapshots.append((child as MonsterBase).get_snapshot())
	# Also expose the current count of uncollected map items (for persistence tests)
	var item_count: int = 0
	var item_positions: Array = []
	var items_node: Node = get_node_or_null("Items")
	if items_node:
		item_count = items_node.get_child_count()
		for item: Node in items_node.get_children():
			if item is Area2D:
				item_positions.append({"x": (item as Area2D).global_position.x, "y": (item as Area2D).global_position.y})
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameMonsterStates = " + JSON.stringify(snapshots) + "; window.gameItemCount = " + str(item_count) + "; window.gameTotalMonsters = " + str(_total_monsters) + "; window.gameTotalItems = " + str(_total_items) + "; window.gameItemPositions = " + JSON.stringify(item_positions) + ";")

# §16 — Кузнец Слов: открыть инвентарь + вкладку крафта.
func _open_inventory_and_craft() -> void:
	if _inventory == null:
		return
	if not _inventory.is_open():
		_inventory.open()
	# Открыть вкладку крафта (вызвать внутренний метод)
	if _inventory.has_method("open_craft_panel"):
		_inventory.open_craft_panel()
	elif _inventory.has_method("_toggle_craft"):
		_inventory._toggle_craft()

func _force_nearest_dialogue() -> void:
	# Test helper: ensure the player can speak, then start dialogue with the nearest
	# dialogue-capable monster regardless of physical proximity (reliable for e2e tests).
	var player: Node2D = $Player
	if player == null:
		return
	if not InventoryManager.has_ellipsis():
		InventoryManager.add_dots(BookwarConst.ELLIPSIS_COST)
	var best: MonsterBase = null
	var best_dist: float = 999999.0
	for child: Node in get_children():
		if child is MonsterBase:
			var m: MonsterBase = child as MonsterBase
			if m.can_dialogue() and m._allegiance != m.ALLEGIANCE_RECRUITED:
				var d: float = player.global_position.distance_to(m.global_position)
				if d < best_dist:
					best_dist = d
					best = m
	if best != null:
		best.start_dialogue()

func _on_combat_requested(monster_id: String, monster_name: String, enemy_hp: int, enemy_letters: Array) -> void:
	if monster_id != "test" and GameState.has_recruits():
		_auto_combat_recruit(monster_id, monster_name, enemy_hp, enemy_letters)
		return
	var p: Node2D = $Player
	if p:
		GameState.saved_player_position = p.global_position
	# Remember which monster (by spawn_id) the player is about to fight, so
	# when the world reloads after a player victory we can finish off that
	# monster (manual combat doesn't kill it in-place).
	var enemy: MonsterBase = _find_monster_by_id(monster_id)
	GameState.last_combat_monster_spawn_id = enemy.spawn_id if enemy != null else ""
	GameState.last_combat_won = false
	GameState.set_pending_combat(monster_id, monster_name, enemy_hp, enemy_letters)
	GameState.start_combat()
	get_tree().change_scene_to_file(BATTLE_SCENE_PATH)

func _auto_combat_recruit(monster_id: String, enemy_name: String, enemy_hp: int, enemy_letters: Array) -> void:
	if not GameState.has_recruits():
		var p2: Node2D = $Player
		if p2:
			GameState.saved_player_position = p2.global_position
		GameState.set_pending_combat(monster_id, enemy_name, enemy_hp, enemy_letters)
		GameState.start_combat()
		get_tree().change_scene_to_file(BATTLE_SCENE_PATH)
		return
	var army_power: int = 0
	for r: Dictionary in GameState.recruits:
		var r_power: int = 0
		for l: String in r.get("letters", []):
			r_power += AlphabetData.get_base_power(l)
		if r_power == 0:
			r_power = 15
		army_power += r_power
	var enemy_power: int = 0
	for l: String in enemy_letters:
		enemy_power += AlphabetData.get_base_power(l)
	if enemy_power == 0:
		enemy_power = 20
	var enemy: MonsterBase = _find_monster_by_id(monster_id)
	var army_won: bool = army_power >= enemy_power
	var recruit_names: String = ""
	for i: int in range(min(3, GameState.recruits.size())):
		recruit_names += GameState.recruits[i].get("name", "?")
		if i < min(3, GameState.recruits.size()) - 1:
			recruit_names += ", "
	if GameState.recruits.size() > 3:
		recruit_names += " +" + str(GameState.recruits.size() - 3)
	if army_won:
		# Victory: the enemy is destroyed. War has its price — a chance to lose the
		# weakest ally (more likely the closer the fight was). Defeats cost more.
		var margin: float = enemy_power / float(max(1, army_power))  # 0..1, higher = closer fight
		var loss_chance: float = clampf(0.20 + margin * 0.45, 0.20, 0.60)
		var fallen_name: String = ""
		if randf() < loss_chance:
			fallen_name = GameState.remove_weakest_recruit()
			if fallen_name != "":
				_kill_recruited_monster(fallen_name)
		var msg: String = "Армия (" + recruit_names + ") атакует " + enemy_name + "!\nСила армии " + str(army_power) + " против " + str(enemy_power) + ".\nПОБЕДА! " + enemy_name + " повержен!"
		if fallen_name != "":
			msg += "\nНо в бою пал " + fallen_name + "..."
		GameState.set_dialogue_text(msg)
		GameState.start_dialogue()
		if enemy != null:
			enemy.take_damage(enemy_hp)
		else:
			_drop_enemy_loot(monster_id)
	else:
		GameState.set_dialogue_text("Армия (" + recruit_names + ") атакует " + enemy_name + "!\nСила армии " + str(army_power) + " против " + str(enemy_power) + ".\nАрмия отступила с потерями...")
		GameState.start_dialogue()
		var fallen1: String = GameState.remove_strongest_recruit()
		_kill_recruited_monster(fallen1)
		if GameState.has_recruits():
			var fallen2: String = GameState.remove_strongest_recruit()
			_kill_recruited_monster(fallen2)
		if enemy != null:
			enemy.hp = max(1, enemy.hp - army_power / 2)
	get_tree().create_timer(3.5).timeout.connect(_close_auto_combat_dialogue)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameAutoCombat = {armyPower:" + str(army_power) + ", enemyPower:" + str(enemy_power) + ", won:" + str(army_won).to_lower() + ", recruits:" + str(GameState.recruits.size()) + "};")

func _close_auto_combat_dialogue() -> void:
	if GameState.is_in_dialogue:
		GameState.end_dialogue()
		if OS.has_feature("web"):
			JavaScriptBridge.eval("window.gameDialogueActive = false; window.gameDialogueText = '';")

func _find_monster_by_id(mid: String) -> MonsterBase:
	var player: Node2D = $Player
	var best: MonsterBase = null
	var best_dist: float = 999999.0
	for child: Node in get_children():
		if child is MonsterBase:
			var m: MonsterBase = child as MonsterBase
			if m.monster_id == mid and m.is_active():
				if player != null:
					var d: float = m.global_position.distance_to(player.global_position)
					if d < best_dist:
						best_dist = d
						best = m
				elif best == null:
					best = m
	return best

func _find_recruited_follower() -> MonsterBase:
	for child: Node in get_children():
		if child is MonsterBase:
			var m: MonsterBase = child as MonsterBase
			if m._allegiance == m.ALLEGIANCE_RECRUITED:
				return m
	return null

func _kill_recruited_monster(recruit_name: String) -> void:
	if recruit_name == "":
		return
	for child: Node in get_children():
		if child is MonsterBase:
			var m: MonsterBase = child as MonsterBase
			if m._allegiance == m.ALLEGIANCE_RECRUITED and m.monster_name == recruit_name:
				m.take_damage(9999)
				return

func _drop_enemy_loot(monster_id: String) -> void:
	var file: FileAccess = FileAccess.open("res://data/monsters.json", FileAccess.READ)
	if file == null:
		return
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data: Variant = json.get_data()
	if not data is Dictionary:
		return
	for monster: Variant in (data as Dictionary).get("monsters", []):
		var mdict: Dictionary = monster
		if str(mdict.get("id", "")) == monster_id:
			for drop: Dictionary in mdict.get("drop_table", []):
				if randf() <= float(drop.get("chance", 0.0)):
					var item: String = drop.get("item", "")
					var count: int = int(drop.get("count", 1))
					for i: int in range(count):
						match item:
							"dot":
								InventoryManager.add_dots(1)
							"letter":
								var letters: Array = mdict.get("letters", [])
								if letters.size() > 0:
									InventoryManager.add_letter(str(letters[randi() % letters.size()]))
			break

func _check_player_hidden() -> void:
	var player: Node2D = $Player
	if player == null:
		return
	var tile_map: TileMapLayer = $TileMapLayer
	if tile_map == null:
		return
	var cell: Vector2i = tile_map.local_to_map(player.global_position)
	var source_id: int = tile_map.get_cell_source_id(cell)
	var hidden: bool = BookwarConst.HIDEABLE_TILES.has(source_id)
	GameState.player_hidden = hidden
	if _test_bridge and OS.has_feature("web"):
		JavaScriptBridge.eval("window.gamePlayerHidden = " + str(hidden).to_lower() + ";")

func _count_totals() -> void:
	_total_monsters = _count_monsters()
	_total_items = _count_items()
	# Post-combat cleanup: if the player won a manual battle on the previous
	# scene visit, kill the monster they fought. Without this the spawner
	# recreates the monster fresh — making it look like combat was pointless.
	var post_debug: Dictionary = {"won": GameState.last_combat_won, "target_spawn_id": GameState.last_combat_monster_spawn_id, "found": false, "total": _total_monsters}
	if GameState.last_combat_won and GameState.last_combat_monster_spawn_id != "":
		var target_id: String = GameState.last_combat_monster_spawn_id
		for child: Node in get_children():
			if child is MonsterBase:
				var m: MonsterBase = child as MonsterBase
				if m.spawn_id == target_id and m.is_active():
					m.mark_killed_post_combat()
					post_debug["found"] = true
					post_debug["killed"] = m.monster_name
					break
	# Reset the flag so we don't re-kill on the next map transition.
	GameState.last_combat_won = false
	GameState.last_combat_monster_spawn_id = ""
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gamePostCombatDebug = " + JSON.stringify(post_debug))

func _build_map_bounds() -> void:
	# Invisible walls around the playable map so the player CANNOT leave into the gray void.
	const TS: int = 32
	const W: float = 80.0 * TS  # 2560
	const H: float = 60.0 * TS  # 1920
	const T: float = 64.0  # wall thickness
	_add_bound_wall(Vector2(W * 0.5, -T * 0.5), Vector2(W + T * 2.0, T))   # top
	_add_bound_wall(Vector2(W * 0.5, H + T * 0.5), Vector2(W + T * 2.0, T)) # bottom
	_add_bound_wall(Vector2(-T * 0.5, H * 0.5), Vector2(T, H + T * 2.0))   # left
	_add_bound_wall(Vector2(W + T * 0.5, H * 0.5), Vector2(T, H + T * 2.0)) # right

func _add_bound_wall(pos: Vector2, size: Vector2) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.collision_layer = 2  # World layer (player collides with it)
	body.collision_mask = 0
	body.position = pos
	var col: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = size
	col.shape = rect
	body.add_child(col)
	add_child(body)

func _count_monsters() -> int:
	var n: int = 0
	for child: Node in get_children():
		if child is MonsterBase:
			n += 1
	return n

func _count_items() -> int:
	var items_node: Node = get_node_or_null("Items")
	if items_node == null:
		return 0
	return items_node.get_child_count()

func _level_progress() -> float:
	# Composite completion: collected items + resolved monsters over weighted total.
	# A monster counts as "resolved" when it's no longer an active hostile
	# (recruited / killed / neutralized). Portal opens at >= 50%.
	const MONSTER_WEIGHT: int = 6
	var monsters: Array[MonsterBase] = []
	for child: Node in get_children():
		if child is MonsterBase:
			monsters.append(child as MonsterBase)
	var active_hostiles: int = 0
	for m: MonsterBase in monsters:
		if m.is_active() and m.get_allegiance() == 0:
			active_hostiles += 1
	var resolved_monsters: int = monsters.size() - active_hostiles
	var collected: int = GameState.collected_items.size()
	var denom: int = _total_items + _total_monsters * MONSTER_WEIGHT
	if denom <= 0:
		return 0.0
	var prog: float = float(collected + resolved_monsters * MONSTER_WEIGHT) / float(denom)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameProgressDebug = {resolved:" + str(resolved_monsters) + ", hostile:" + str(active_hostiles) + ", collected:" + str(collected) + ", denom:" + str(denom) + ", prog:" + str(prog) + "};")
	return prog

func _check_victory() -> void:
	# Portal opens at 75% completion (not full clear). Full victory message still fires at 100%.
	if not _portal_spawned:
		var progress: float = _level_progress()
		if _test_bridge and OS.has_feature("web"):
			JavaScriptBridge.eval("window.gameLevelProgress = " + str(snapped(progress * 100.0, 1.0)) + ";")
		if progress >= PORTAL_PROGRESS_THRESHOLD:
			_portal_spawned = true
			_spawn_portal()
			if _test_bridge and OS.has_feature("web"):
				JavaScriptBridge.eval("window.gamePortalSpawned = true;")
	# Full clear victory message (optional, only once)
	if _victory_shown:
		return
	var monsters2: Array[MonsterBase] = []
	for child: Node in get_children():
		if child is MonsterBase:
			monsters2.append(child as MonsterBase)
	var has_hostile: bool = false
	for m: MonsterBase in monsters2:
		if m.is_active() and m.get_allegiance() == 0:
			has_hostile = true
			break
	if monsters2.size() > 0 and not has_hostile:
		_victory_shown = true
		var recruited: int = 0
		for m: MonsterBase in monsters2:
			if m.get_allegiance() == 1:
				recruited += 1
		var msg: String = "ПОБЕДА! " + _region_name() + " зачищена. Союзников: " + str(recruited)
		GameState.set_dialogue_text(msg)
		GameState.start_dialogue()
		if _test_bridge and OS.has_feature("web"):
			JavaScriptBridge.eval("window.gameVictory = true;")

func _spawn_portal() -> void:
	var portal: Area2D = Area2D.new()
	portal.name = "Portal"
	# Spawn NEAR the hero's current position (on-screen, easy to reach), not far away
	var hero: Node2D = $Player
	var pos: Vector2 = _player_start() + BookwarConst.PORTAL_OFFSET
	if hero:
		pos = hero.global_position + Vector2(140.0, -40.0)
	portal.global_position = pos
	var col: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(64.0, 64.0)
	col.shape = rect
	portal.add_child(col)
	# Outer RIM (кайма) — dark-green frame
	var rim: ColorRect = ColorRect.new()
	rim.color = Color(0.05, 0.35, 0.12, 0.95)
	rim.offset_left = -50.0
	rim.offset_top = -50.0
	rim.offset_right = 50.0
	rim.offset_bottom = 50.0
	portal.add_child(rim)
	# Inner glow
	var glow: ColorRect = ColorRect.new()
	glow.color = Color(0.3, 1.0, 0.5, 0.35)
	glow.offset_left = -42.0
	glow.offset_top = -42.0
	glow.offset_right = 42.0
	glow.offset_bottom = 42.0
	portal.add_child(glow)
	# Visual marker: a RANDOM LETTER + RANDOM COLOR that changes fast (every 0.3s)
	var label: Label = Label.new()
	label.name = "PortalLetter"
	var pc0: Color = _random_portal_color()
	label.text = _random_portal_letter()
	label.add_theme_font_size_override("font_size", 52)
	label.add_theme_color_override("font_color", pc0)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 6)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(-40, -52)
	label.size = Vector2(80, 80)
	portal.add_child(label)
	# Small "портал" hint below
	var hint: Label = Label.new()
	hint.text = "портал"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(-40, 22)
	hint.size = Vector2(80, 20)
	portal.add_child(hint)
	# Timer: cycle the letter AND its color every 0.3 seconds
	var timer: Timer = Timer.new()
	timer.name = "PortalLetterTimer"
	timer.wait_time = 0.3
	timer.autostart = true
	timer.timeout.connect(func() -> void:
		if is_instance_valid(label):
			label.text = _random_portal_letter()
			label.add_theme_color_override("font_color", _random_portal_color()))
	portal.add_child(timer)
	# Collision: player enters portal → transition
	portal.body_entered.connect(_on_portal_entered)
	add_child(portal)
	if _test_bridge and OS.has_feature("web"):
		JavaScriptBridge.eval("window.gamePortalSpawned = true;")

const _PORTAL_LETTERS: Array[String] = [
	"А","Б","В","Г","Д","Е","Ж","З","И","К","Л","М","Н","О","П","Р","С","Т","У","Ф","Х","Ц","Ч","Ш","Щ","Ъ","Ы","Ь","Э","Ю","Я","Й","Ё"
]
func _random_portal_letter() -> String:
	return _PORTAL_LETTERS[randi() % _PORTAL_LETTERS.size()]

const _PORTAL_COLORS: Array[Color] = [
	Color(0.3, 1.0, 0.4), Color(1.0, 0.9, 0.3), Color(0.4, 0.8, 1.0),
	Color(1.0, 0.5, 0.3), Color(0.9, 0.5, 1.0), Color(0.95, 0.95, 0.6), Color(0.5, 1.0, 0.9)
]
func _random_portal_color() -> Color:
	return _PORTAL_COLORS[randi() % _PORTAL_COLORS.size()]

func _on_portal_entered(body: Node2D) -> void:
	if body.name != "Player":
		return
	# Defer the scene change — we're inside a physics body_entered callback.
	call_deferred("_do_portal_transition")

func _do_portal_transition() -> void:
	# Determine next map using the chain (supports all 10 maps).
	var next_map: String = BookwarConst.get_next_map(GameState.current_map_id)
	if next_map == "":
		return
	# Reset saved position so the hero spawns cleanly at the next map's start (no stuck)
	GameState.saved_player_position = Vector2(-1.0, -1.0)
	GameState.combat_cooldown = 0.0
	GameState.end_dialogue()
	GameState.current_map_id = next_map
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gamePortalSpawned = false; window.gameLevelProgress = 0;")
	# Reload same scene with new map
	get_tree().change_scene_to_file("res://scenes/world/world_map.tscn")
