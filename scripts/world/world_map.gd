extends Node2D

const DOT_SCENE: PackedScene = preload("res://scenes/world/dot_item.tscn")
const BATTLE_SCENE_PATH: String = "res://scenes/combat/battle_scene.tscn"

var _hud: CanvasLayer = null
var _inventory: Control = null
var _test_bridge: TestBridge = null
var _monster_push_timer: float = 0.0

func _ready() -> void:
	await get_tree().process_frame
	_hud = $HUD
	_inventory = $InventoryLayer/Inventory
	_init_test_bridge()
	_setup_monster_spawner()
	_spawn_light_valley_items()
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
	_test_bridge.update_player_position(BookwarConst.PLAYER_START.x, BookwarConst.PLAYER_START.y)
	_test_bridge.update_inventory()
	_test_bridge.update_hud(_hp_text(), _dots_text(), BookwarConst.LIGHT_VALLEY_NAME)
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

func _on_world_state_changed() -> void:
	if _test_bridge:
		_test_bridge.update_inventory()
		_test_bridge.update_hud(_hp_text(), _dots_text(), BookwarConst.LIGHT_VALLEY_NAME)

func _on_hp_changed(_current: int, _maximum: int) -> void:
	if _test_bridge:
		_test_bridge.update_hud(_hp_text(), _dots_text(), BookwarConst.LIGHT_VALLEY_NAME)

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
	return ".: " + str(InventoryManager.get_dots())

func _setup_monster_spawner() -> void:
	var spawner: Node = $MonsterSpawner
	if spawner and spawner.has_method("setup_light_valley"):
		spawner.setup_light_valley()

func _spawn_light_valley_items() -> void:
	var items: Node2D = $Items
	if items == null:
		return
	# Spawn dots in a grid pattern around player start
	for i: int in range(-3, 20):
		_spawn_item(items, "dot", "", BookwarConst.PLAYER_START + Vector2(i * 40.0, 0.0))
		_spawn_item(items, "dot", "", BookwarConst.PLAYER_START + Vector2(i * 40.0, 50.0))
		_spawn_item(items, "dot", "", BookwarConst.PLAYER_START + Vector2(i * 40.0, -50.0))
	# Spawn the three starting letters per AGENTS.md §4.5: А, О, М
	# А is placed AT the spawn point so it's auto-collected on game start —
	# the player must always have at least one letter to fight with (§2.4 start empty,
	# but aggressive ! monsters attack immediately, so a starting weapon is required).
	_spawn_letter(items, "А", BookwarConst.PLAYER_START + Vector2(20.0, 20.0))
	_spawn_letter(items, "О", BookwarConst.PLAYER_START + Vector2(-400.0, 250.0))
	_spawn_letter(items, "М", BookwarConst.PLAYER_START + Vector2(300.0, 400.0))

func _spawn_item(parent: Node2D, item_type: String, item_id: String, pos: Vector2) -> void:
	var item: Area2D = DOT_SCENE.instantiate()
	item.global_position = pos
	if item_type != "dot":
		item.item_type = item_type
		item.item_id = item_id
		item.interaction_name = item_id
		var label: Node = item.get_node_or_null("Label")
		if label:
			label.text = item_id
	parent.add_child(item)

func _spawn_letter(parent: Node2D, letter_char: String, pos: Vector2) -> void:
	_spawn_item(parent, "letter", letter_char, pos)

func _push_monster_states() -> void:
	if _test_bridge == null:
		return
	var snapshots: Array = []
	for child: Node in get_children():
		if child is MonsterBase:
			snapshots.append((child as MonsterBase).get_snapshot())
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameMonsterStates = " + JSON.stringify(snapshots) + ";")

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
			if m.can_dialogue():
				var d: float = player.global_position.distance_to(m.global_position)
				if d < best_dist:
					best_dist = d
					best = m
	if best != null:
		best.start_dialogue()

func _on_combat_requested(monster_id: String, monster_name: String, enemy_hp: int, enemy_letters: Array) -> void:
	# Transition to battle scene. Combat info is stashed on GameState for BattleManager to pick up.
	GameState.set_pending_combat(monster_id, monster_name, enemy_hp, enemy_letters)
	# Mark combat active before transition so HUD/world reflects it
	GameState.start_combat()
	get_tree().change_scene_to_file(BATTLE_SCENE_PATH)
