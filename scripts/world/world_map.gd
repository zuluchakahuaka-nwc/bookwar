extends Node2D

const DOT_SCENE: PackedScene = preload("res://scenes/world/dot_item.tscn")
const BATTLE_SCENE_PATH: String = "res://scenes/combat/battle_scene.tscn"

const PLAYER_START: Vector2 = Vector2(1216, 1536)
const LIGHT_VALLEY_NAME: String = "Светлая Долина"

var _hud: CanvasLayer = null
var _inventory: Control = null
var _test_bridge: TestBridge = null

func _ready() -> void:
	await get_tree().process_frame
	_hud = $HUD
	_inventory = $Inventory
	_init_test_bridge()
	_setup_monster_spawner()
	_spawn_light_valley_items()
	# Combat flow: monster requests → world transitions to battle scene
	GameState.combat_requested.connect(_on_combat_requested)

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
	_test_bridge.update_player_position(PLAYER_START.x, PLAYER_START.y)
	_test_bridge.update_inventory()
	_test_bridge.update_hud(_hp_text(), _dots_text(), LIGHT_VALLEY_NAME)
	_test_bridge.set_dialogue_active(false, "")
	_test_bridge.set_in_combat(false)
	_test_bridge.set_inventory_visible(false)
	# Push real alphabet snapshot (replaces hardcoded gameAlphabetCount=33)
	_test_bridge.push_alphabet_snapshot(AlphabetData.get_alphabet_snapshot())

func _process(_delta: float) -> void:
	if _test_bridge == null:
		return
	var player: Node2D = $Player
	if player:
		_test_bridge.update_player_position(player.global_position.x, player.global_position.y)
	if _inventory:
		_test_bridge.set_inventory_visible(_inventory.visible)
	_test_bridge.update_inventory()
	_test_bridge.update_hud(_hp_text(), _dots_text(), LIGHT_VALLEY_NAME)
	_test_bridge.set_in_combat(GameState.is_in_combat)
	_test_bridge.set_dialogue_active(GameState.is_in_dialogue)
	# Drain any queued card selections from Puppeteer bridge
	if _test_bridge.has_select_card_callback():
		for letter: String in _test_bridge.drain_select_card_queue():
			_test_bridge.invoke_select_card(letter)

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
		_spawn_item(items, "dot", "", PLAYER_START + Vector2(i * 40.0, 0.0))
		_spawn_item(items, "dot", "", PLAYER_START + Vector2(i * 40.0, 50.0))
		_spawn_item(items, "dot", "", PLAYER_START + Vector2(i * 40.0, -50.0))
	# Spawn the three starting letters per AGENTS.md §4.5: А, О, М
	_spawn_letter(items, "А", PLAYER_START + Vector2(500.0, -300.0))
	_spawn_letter(items, "О", PLAYER_START + Vector2(-400.0, 250.0))
	_spawn_letter(items, "М", PLAYER_START + Vector2(300.0, 400.0))

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

func _on_combat_requested(monster_id: String, monster_name: String, enemy_hp: int, enemy_letters: Array) -> void:
	# Transition to battle scene. Combat info is stashed on GameState for BattleManager to pick up.
	GameState.set_pending_combat(monster_id, monster_name, enemy_hp, enemy_letters)
	# Mark combat active before transition so HUD/world reflects it
	GameState.start_combat()
	get_tree().change_scene_to_file(BATTLE_SCENE_PATH)
