extends Node2D

const DOT_SCENE: PackedScene = preload("res://scenes/world/dot_item.tscn")
const LETTER_A_SCENE: PackedScene = preload("res://scenes/world/dot_item.tscn")

var _hud: CanvasLayer = null
var _inventory: Control = null

func _ready() -> void:
	await get_tree().process_frame
	_hud = $HUD
	_inventory = $Inventory
	_init_js_bridge()
	_setup_monster_spawner()
	_spawn_light_valley_items()

func _init_js_bridge() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("window.gameLoaded = true; window.gameMenuVisible = false;")
	JavaScriptBridge.eval("window.gamePlayerPos = {x: 960, y: 640};")
	JavaScriptBridge.eval("window.gameInventory = {letters: {}, dots: 0, punctuation: {'.': 0}};")
	JavaScriptBridge.eval("window.gameHUD = {hp: 'HP: 100/100', dots: '.: 0', region: 'Светлая Долина'};")
	JavaScriptBridge.eval("window.gameDialogueActive = false; window.gameDialogueText = '';")
	JavaScriptBridge.eval("window.gameInCombat = false; window.gameInventoryVisible = false;")
	JavaScriptBridge.eval("window.gameAlphabetCount = 33;")
	_update_bridge_inventory()

func _process(_delta: float) -> void:
	if not OS.has_feature("web"):
		return
	var player: CharacterBody2D = $Player
	if player:
		var pos: Vector2 = player.global_position
		JavaScriptBridge.eval("window.gamePlayerPos = {x: " + str(pos.x) + ", y: " + str(pos.y) + "};")
	if _inventory:
		JavaScriptBridge.eval("window.gameInventoryVisible = " + str(_inventory.visible).to_lower() + ";")
	_update_bridge_inventory()
	_update_bridge_hud()
	_update_bridge_combat()

func _update_bridge_inventory() -> void:
	if not OS.has_feature("web"):
		return
	var letters: Dictionary = InventoryManager.get_all_letters()
	var dots: int = InventoryManager.get_dots()
	var punct: Dictionary = InventoryManager.get_all_punctuation()
	JavaScriptBridge.eval("window.gameInventory = {letters: " + JSON.stringify(letters) + ", dots: " + str(dots) + ", punctuation: " + JSON.stringify(punct) + "};")

func _update_bridge_hud() -> void:
	if not OS.has_feature("web"):
		return
	var hp: String = "HP: " + str(GameState.player_hp) + "/" + str(GameState.player_max_hp)
	var dots: String = ".: " + str(InventoryManager.get_dots())
	var region: String = "Светлая Долина"
	JavaScriptBridge.eval("window.gameHUD = {hp: '" + hp + "', dots: '" + dots + "', region: '" + region + "'};")

func _update_bridge_combat() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("window.gameInCombat = " + str(GameState.is_in_combat).to_lower() + ";")
	JavaScriptBridge.eval("window.gameDialogueActive = " + str(GameState.is_in_dialogue).to_lower() + ";")

func _setup_monster_spawner() -> void:
	var spawner: MonsterSpawner = $MonsterSpawner
	if spawner:
		spawner.setup_light_valley()

func _spawn_light_valley_items() -> void:
	var items: Node2D = $Items
	if not items:
		return
	var player_pos: Vector2 = Vector2(1216, 1536)
	var dot_positions: Array[Vector2] = []
	for i: int in range(-3, 20):
		dot_positions.append(Vector2(player_pos.x + i * 40, player_pos.y))
		dot_positions.append(Vector2(player_pos.x + i * 40, player_pos.y + 50))
		dot_positions.append(Vector2(player_pos.x + i * 40, player_pos.y - 50))
	for pos: Vector2 in dot_positions:
		var dot: Area2D = DOT_SCENE.instantiate()
		dot.global_position = pos
		items.add_child(dot)
	var letter_pos: Vector2 = Vector2(player_pos.x + 500, player_pos.y - 300)
	var letter: Area2D = LETTER_A_SCENE.instantiate()
	letter.global_position = letter_pos
	letter.item_type = "letter"
	letter.item_id = "А"
	letter.interaction_name = "А"
	letter.get_node("Label").text = "А"
	items.add_child(letter)
