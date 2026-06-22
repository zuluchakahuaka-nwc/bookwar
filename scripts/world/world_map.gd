extends Node2D

const DOT_SCENE: PackedScene = preload("res://scenes/world/dot_item.tscn")
const BATTLE_SCENE_PATH: String = "res://scenes/combat/battle_scene.tscn"

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
		elif GameState.current_map_id == BookwarConst.MAP_DARK_OAKS:
			player.global_position = BookwarConst.PLAYER_START_DARK_OAKS
		elif GameState.current_map_id == BookwarConst.MAP_TWO_LETTER_FOREST:
			player.global_position = BookwarConst.PLAYER_START_FOREST
		else:
			player.global_position = BookwarConst.PLAYER_START_VALLEY
	_init_test_bridge()
	_setup_monster_spawner()
	_spawn_map_items()
	_build_map_bounds()
	# Count totals (deferred — monsters spawn via call_deferred, so they aren't children yet)
	call_deferred("_count_totals")
	if _hud and _hud.has_method("set_region_name"):
		_hud.set_region_name(_region_name())
	# Per-map ambient tint: bright valley → green forest → cold dark wood
	_apply_ambient()
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
	var recruit_force: int = _test_bridge.consume_recruit_force()
	if recruit_force != -1:
		GameState.recruit_force_result = recruit_force
	if _test_bridge.consume_clear_region():
		for child: Node in get_children():
			if child is MonsterBase:
				(child as MonsterBase).force_neutralize()
	var test_map: String = _test_bridge.consume_test_map_switch()
	if test_map != "":
		GameState.current_map_id = test_map
		get_tree().change_scene_to_file("res://scenes/world/world_map.tscn")
		return
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

func _on_combat_ended(_player_won: bool) -> void:
	if _test_bridge:
		_test_bridge.set_in_combat(false)

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
	if GameState.current_map_id == BookwarConst.MAP_DARK_OAKS:
		return BookwarConst.DARK_OAKS_NAME
	if GameState.current_map_id == BookwarConst.MAP_TWO_LETTER_FOREST:
		return BookwarConst.FOREST_NAME
	return BookwarConst.LIGHT_VALLEY_NAME

func _apply_ambient() -> void:
	# CanvasModulate tints the whole rendered world — cheap mood shift per map.
	var tint: Color = Color(1.0, 0.98, 0.88)  # Light Valley: warm noon
	if GameState.current_map_id == BookwarConst.MAP_TWO_LETTER_FOREST:
		tint = Color(0.72, 0.82, 0.66)  # Forest: dim green shade
	elif GameState.current_map_id == BookwarConst.MAP_DARK_OAKS:
		tint = Color(0.46, 0.50, 0.64)  # Dark Oaks: cold blue gloom
	var ambient: CanvasModulate = CanvasModulate.new()
	ambient.name = "Ambient"
	ambient.color = tint
	add_child(ambient)

func _player_start() -> Vector2:
	if GameState.current_map_id == BookwarConst.MAP_DARK_OAKS:
		return BookwarConst.PLAYER_START_DARK_OAKS
	if GameState.current_map_id == BookwarConst.MAP_TWO_LETTER_FOREST:
		return BookwarConst.PLAYER_START_FOREST
	return BookwarConst.PLAYER_START_VALLEY

func _setup_monster_spawner() -> void:
	var spawner: Node = $MonsterSpawner
	if spawner == null:
		return
	if GameState.current_map_id == BookwarConst.MAP_DARK_OAKS:
		if spawner.has_method("setup_dark_oaks"):
			spawner.setup_dark_oaks()
	elif GameState.current_map_id == BookwarConst.MAP_TWO_LETTER_FOREST:
		if spawner.has_method("setup_two_letter_forest"):
			spawner.setup_two_letter_forest()
	else:
		if spawner.has_method("setup_light_valley"):
			spawner.setup_light_valley()

func _spawn_map_items() -> void:
	# Deterministic RNG per map: same seed → same random positions/letters/colors across
	# battle scene reloads, so collected-item keys (map:index) stay stable.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(GameState.current_map_id)
	if GameState.current_map_id == BookwarConst.MAP_DARK_OAKS:
		_spawn_dark_oaks_items(rng)
	elif GameState.current_map_id == BookwarConst.MAP_TWO_LETTER_FOREST:
		_spawn_forest_items(rng)
	else:
		_spawn_light_valley_items(rng)

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
	return Vector2(
		clampf(pos.x, MAP_BOUND_MIN_X, MAP_BOUND_MAX_X),
		clampf(pos.y, MAP_BOUND_MIN_Y, MAP_BOUND_MAX_Y)
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
	# Determine next map
	var next_map: String = ""
	if GameState.current_map_id == BookwarConst.MAP_LIGHT_VALLEY:
		next_map = BookwarConst.MAP_TWO_LETTER_FOREST
	elif GameState.current_map_id == BookwarConst.MAP_TWO_LETTER_FOREST:
		next_map = BookwarConst.MAP_DARK_OAKS
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
