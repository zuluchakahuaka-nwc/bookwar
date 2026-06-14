extends Node2D
class_name BattleManager

const WORLD_SCENE_PATH: String = "res://scenes/world/world_map.tscn"

var _combat_system: CombatSystem = null
var _enemy_name: String = ""
var _enemy_letters: Array = []
var _player_confirmed: bool = false
var _combat_resolved: bool = false

@onready var _enemy_info_label: Label = $EnemyInfo
@onready var _enemy_hp_label: Label = $EnemyHP
@onready var _player_hp_label: Label = $PlayerHP
@onready var _message_label: Label = $MessageLabel
@onready var _card_container: HBoxContainer = $CardContainer
@onready var _confirm_button: Button = $ButtonRow/ConfirmButton
@onready var _flee_button: Button = $ButtonRow/FleeButton

signal battle_state_changed(snapshot: Dictionary)
signal battle_message(text: String)

func _ready() -> void:
	_combat_system = CombatSystem.new()
	add_child(_combat_system)
	_combat_system.combat_started.connect(_on_combat_started)
	_combat_system.combat_ended.connect(_on_combat_ended)
	_combat_system.card_played.connect(_on_card_played)
	_combat_system.turn_order_resolved.connect(_on_turn_order_resolved)
	_combat_system.damage_dealt.connect(_on_damage_dealt)
	_combat_system.shield_applied.connect(_on_shield_applied)
	_combat_system.buff_applied.connect(_on_buff_applied)
	_combat_system.action_resolved.connect(_on_action_resolved)
	# Wire UI buttons
	if _confirm_button:
		_confirm_button.pressed.connect(confirm_turn)
	if _flee_button:
		_flee_button.pressed.connect(_flee_battle)
	# Wire internal signal to message label
	battle_message.connect(_on_battle_message)
	# Pull combat info stashed by world_map
	_enemy_name = GameState.pending_combat_monster_name
	var enemy_hp: int = GameState.pending_combat_monster_hp
	if enemy_hp <= 0:
		enemy_hp = BookwarConst.ENEMY_DEFAULT_HP
	_enemy_letters = GameState.pending_combat_monster_letters.duplicate()
	if _enemy_letters.size() == 0:
		_enemy_letters = ["Я"] if GameState.pending_combat_monster_id == "question" else ["А", "Б"]
	GameState.clear_pending_combat()
	_setup_js_bridge()
	_build_hand_buttons()
	call_deferred("_start_combat", enemy_hp)

func _start_combat(enemy_hp: int) -> void:
	_combat_system.start_combat(_enemy_name, enemy_hp, _enemy_letters)
	battle_message.emit("Бой начался: " + _enemy_name)

func _setup_js_bridge() -> void:
	if not OS.has_feature("web"):
		return
	# Allow Puppeteer to play a card via window.gameSelectCard + window.gameConfirmTurn
	JavaScriptBridge.eval("""
		(function() {
			window.gameSelectCard = function(letter) {
				if (!window._godotBattleQueue) window._godotBattleQueue = [];
				window._godotBattleQueue.push({action: 'select', letter: letter});
				return true;
			};
			window.gameConfirmTurn = function() {
				if (!window._godotBattleQueue) window._godotBattleQueue = [];
				window._godotBattleQueue.push({action: 'confirm'});
				return true;
			};
			window.gameFleeBattle = function() {
				if (!window._godotBattleQueue) window._godotBattleQueue = [];
				window._godotBattleQueue.push({action: 'flee'});
				return true;
			};
			return true;
		})()
	""")

func _process(_delta: float) -> void:
	# The battle queue is input from Puppeteer — a pull that must stay per-frame.
	# Combat STATE is pushed on change (signal-driven) in _emit_state / _on_combat_started.
	if OS.has_feature("web"):
		_drain_battle_queue()

func _drain_battle_queue() -> void:
	var json_str: Variant = JavaScriptBridge.eval("JSON.stringify(window._godotBattleQueue || [])")
	JavaScriptBridge.eval("window._godotBattleQueue = [];")
	if json_str == null:
		return
	var s: String = str(json_str)
	if s == "" or s == "null":
		return
	var json: JSON = JSON.new()
	if json.parse(s) != OK:
		return
	var queue: Variant = json.get_data()
	if not queue is Array:
		return
	for item: Variant in queue:
		var item_dict: Dictionary = item
		var action: String = item_dict.get("action", "")
		match action:
			"select":
				var letter: String = item_dict.get("letter", "")
				if letter != "":
					select_card(letter)
			"confirm":
				confirm_turn()
			"flee":
				_flee_battle()

func select_card(letter_char: String) -> void:
	if _combat_resolved:
		return
	if _combat_system.play_card(letter_char):
		battle_message.emit("Сыграна буква: " + letter_char)
		_emit_state()

func confirm_turn() -> void:
	if _combat_resolved:
		return
	if _combat_system.is_active() == false:
		return
	# Enemy AI plays one card
	_play_enemy_ai()
	# Resolve the turn (sort by speed, apply effects)
	_combat_system.resolve_turn()
	_emit_state()

func _play_enemy_ai() -> void:
	# Use BattleAI heuristic if available, else simple random
	var chosen: String = ""
	if _enemy_letters.size() > 0:
		# Prefer vowels when player HP high, consonants when enemy HP low
		var enemy_hp: int = _combat_system.get_enemy_hp()
		var player_hp: int = _combat_system.get_player_hp()
		var aggressive: bool = enemy_hp < (GameState.player_max_hp / 3) or player_hp > (GameState.player_max_hp / 2)
		if aggressive:
			# Use vowels for attack
			for l: String in _enemy_letters:
				var data: Dictionary = AlphabetData.get_letter(l)
				if data.get("type", "") == "vowel":
					chosen = l
					break
		if chosen == "":
			chosen = _enemy_letters[randi() % _enemy_letters.size()]
	else:
		chosen = "Я"
	_combat_system.play_enemy_card(chosen, BookwarConst.ENEMY_DEFAULT_LEVEL)

func _flee_battle() -> void:
	if _combat_resolved:
		return
	_combat_resolved = true
	_combat_system.end_combat_via_flee()
	battle_message.emit("Бегство с поля боя!")
	_return_to_world(false)

func _on_combat_started(enemy_name: String, enemy_hp: int) -> void:
	battle_message.emit("Противник: " + enemy_name + " (HP " + str(enemy_hp) + ")")
	_emit_state()
func _on_card_played(card: Dictionary) -> void:
	_emit_state()

func _on_turn_order_resolved(order: Array) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameCombatTurnOrder = " + JSON.stringify(order) + ";")

func _on_damage_dealt(target: String, amount: float, letter_char: String) -> void:
	battle_message.emit(letter_char + " нанёс " + str(int(amount)) + " урона → " + target)

func _on_shield_applied(target: String, amount: float, letter_char: String) -> void:
	battle_message.emit(letter_char + " создал щит " + str(int(amount)) + " → " + target)

func _on_buff_applied(target: String, buff_type: String, multiplier: float, letter_char: String) -> void:
	battle_message.emit(letter_char + " усилил " + buff_type + " ×" + str(multiplier) + " → " + target)

func _on_action_resolved(action: Dictionary) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameCombatLastAction = " + JSON.stringify(action) + ";")

func _on_combat_ended(player_won: bool, loot: Array) -> void:
	if _combat_resolved:
		return  # already handled (flee)
	_combat_resolved = true
	if player_won:
		var loot_text: String = "Победа! Лут: "
		if loot.size() > 0:
			loot_text += ", ".join(loot)
		else:
			loot_text += "ничего"
		battle_message.emit(loot_text)
	else:
		battle_message.emit("Поражение...")
	_emit_state()
	# Return to world after short delay so message is visible
	await get_tree().create_timer(1.5).timeout
	_return_to_world(player_won)

func _return_to_world(player_won: bool) -> void:
	GameState.is_in_combat = false
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameInCombat = false;")
	get_tree().change_scene_to_file(WORLD_SCENE_PATH)

func _emit_state() -> void:
	var snapshot: Dictionary = _combat_system.get_state_snapshot()
	battle_state_changed.emit(snapshot)
	_update_ui(snapshot)
	# Push combat state to JS bridge on change (signal-driven, not per-frame)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameCombatState = " + JSON.stringify(snapshot) + ";")

func _update_ui(snapshot: Dictionary) -> void:
	if _enemy_info_label:
		_enemy_info_label.text = "Враг: " + String(snapshot.get("enemy_name", "?"))
	if _enemy_hp_label:
		_enemy_hp_label.text = "HP: " + str(snapshot.get("enemy_hp", 0)) + "/" + str(snapshot.get("enemy_max_hp", 0)) + "  Щит: " + str(int(snapshot.get("enemy_shield", 0)))
	if _player_hp_label:
		_player_hp_label.text = "HP: " + str(snapshot.get("player_hp", 0)) + "/" + str(snapshot.get("player_max_hp", 0)) + "  Щит: " + str(int(snapshot.get("player_shield", 0)))
	if _confirm_button:
		_confirm_button.disabled = not bool(snapshot.get("is_active", false))

func _build_hand_buttons() -> void:
	if not _card_container:
		return
	for child: Node in _card_container.get_children():
		child.queue_free()
	# Show one button per letter the player owns
	var letters: Dictionary = InventoryManager.get_all_letters()
	var sorted_letters: Array = letters.keys()
	sorted_letters.sort_custom(_sort_by_speed_desc)
	for letter_char: String in sorted_letters:
		var level: int = int(letters[letter_char])
		var btn: Button = Button.new()
		btn.text = letter_char + " Lv" + str(level)
		btn.custom_minimum_size = Vector2(80, 80)
		var data: Dictionary = AlphabetData.get_letter(letter_char)
		var type_str: String = String(data.get("type", ""))
		match type_str:
			"vowel":
				btn.modulate = Color(1.0, 0.7, 0.6)
			"consonant":
				btn.modulate = Color(0.6, 0.7, 1.0)
			"sign":
				btn.modulate = Color(0.9, 0.6, 1.0)
		btn.pressed.connect(_on_hand_button_pressed.bind(letter_char))
		_card_container.add_child(btn)

func _sort_by_speed_desc(a: String, b: String) -> bool:
	return AlphabetData.get_speed(a) > AlphabetData.get_speed(b)

func _on_hand_button_pressed(letter_char: String) -> void:
	select_card(letter_char)

func _on_battle_message(text: String) -> void:
	if _message_label:
		_message_label.text = text

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		confirm_turn()
