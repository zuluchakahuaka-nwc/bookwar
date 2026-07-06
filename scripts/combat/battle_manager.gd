extends Node2D
class_name BattleManager

const WORLD_SCENE_PATH: String = "res://scenes/world/world_map.tscn"
const TURN_TIME_LIMIT: float = 10.0

var _combat_system: CombatSystem = null
var _enemy_name: String = ""
var _enemy_letters: Array = []
var _player_confirmed: bool = false
var _combat_resolved: bool = false

var _turn_timer: float = TURN_TIME_LIMIT
var _timer_active: bool = false
var _resolving: bool = false

@onready var _enemy_info_label: Label = $EnemyInfo
@onready var _enemy_hp_label: Label = $EnemyHP
@onready var _player_hp_label: Label = $PlayerHP
@onready var _message_label: Label = $MessageLabel
@onready var _action_log_label: Label = $ActionLogLabel
@onready var _card_container: HBoxContainer = $CardContainer
@onready var _confirm_button: Button = $ButtonRow/ConfirmButton
@onready var _flee_button: Button = $ButtonRow/FleeButton
@onready var _timer_label: Label = get_node_or_null("TimerLabel")
@onready var _player_letters_label: Label = get_node_or_null("PlayerLettersLabel")
@onready var _title_label: Label = get_node_or_null("TitleLabel")
@onready var _player_info_label: Label = get_node_or_null("PlayerInfo")
@onready var _hand_label: Label = get_node_or_null("HandLabel")

var _action_log_lines: Array = []

# Visual overlays (F2)
var _enemy_avatar: ColorRect = null
var _enemy_avatar_label: Label = null
var _player_avatar: ColorRect = null
var _player_avatar_label: Label = null
var _enemy_hp_bar: ProgressBar = null
var _player_hp_bar: ProgressBar = null
var _auto_battle: bool = false
var _auto_battle_btn: Button = null
var _letter_buttons: Dictionary = {}  # letter_char -> Button (to disable once played per turn)
var _spell_buttons: Dictionary = {}   # word -> Button

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
	_combat_system.turn_round_ended.connect(_on_turn_round_ended)
	if _confirm_button:
		_confirm_button.pressed.connect(confirm_turn)
	if _flee_button:
		_flee_button.pressed.connect(_flee_battle)
	battle_message.connect(_on_battle_message)
	_enemy_name = GameState.pending_combat_monster_name
	var enemy_hp: int = GameState.pending_combat_monster_hp
	if enemy_hp <= 0:
		enemy_hp = BookwarConst.ENEMY_DEFAULT_HP
	_enemy_letters = GameState.pending_combat_monster_letters.duplicate()
	if _enemy_letters.size() == 0:
		_enemy_letters = ["Я"] if GameState.pending_combat_monster_id == "question" else ["А", "Б"]
	GameState.clear_pending_combat()
	_apply_battle_texts()
	_setup_js_bridge()
	_build_hand_buttons()
	_build_visual_overlays()
	_update_player_letters_label()
	call_deferred("_start_combat", enemy_hp)

func _apply_battle_texts() -> void:
	if _title_label:
		_title_label.text = I18n.t("battle.title", "BATTLE")
	if _player_info_label:
		_player_info_label.text = I18n.t("battle.player", "Player")
	if _hand_label:
		_hand_label.text = I18n.t("battle.select_prompt", "Choose a letter or spell:")
	if _confirm_button:
		_confirm_button.text = I18n.t("battle.confirm", "Confirm Turn")
	if _flee_button:
		_flee_button.text = I18n.t("battle.flee", "Flee")

func _start_combat(enemy_hp: int) -> void:
	_combat_system.start_combat(_enemy_name, enemy_hp, _enemy_letters)
	battle_message.emit(I18n.t_fmt("battle.started", [_enemy_name], "Battle started: %s"))
	_start_turn_timer()

func _setup_js_bridge() -> void:
	if not OS.has_feature("web"):
		return
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
			window.gameAutoBattle = function() {
				if (!window._godotBattleQueue) window._godotBattleQueue = [];
				window._godotBattleQueue.push({action: 'autobattle'});
				return true;
			};
			return true;
		})()
	""")

func _process(delta: float) -> void:
	if OS.has_feature("web"):
		_drain_battle_queue()
	if _timer_active and not _resolving and not _combat_resolved:
		_turn_timer -= delta
		_update_timer_label()
		if _turn_timer <= 0.0:
			_auto_resolve_turn()
func _drain_battle_queue() -> void:
	var json_str: Variant = JavaScriptBridge.eval("JSON.stringify(window._godotBattleQueue || [])")
	JavaScriptBridge.eval("window._godotBattleQueue = [];")
	var spell_json: Variant = JavaScriptBridge.eval("JSON.stringify(window._godotSpellCastQueue || [])")
	JavaScriptBridge.eval("window._godotSpellCastQueue = [];")
	if spell_json != null:
		var sj: String = str(spell_json)
		if sj != "" and sj != "null":
			var sjson: JSON = JSON.new()
			if sjson.parse(sj) == OK:
				for w: Variant in (sjson.get_data() as Array):
					cast_spell(str(w))
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
			"autobattle":
				if not _auto_battle:
					_toggle_auto_battle()

func select_card(letter_char: String) -> void:
	if _combat_resolved or _resolving:
		return
	if _combat_system.play_card(letter_char):
		battle_message.emit(I18n.t_fmt("battle.card_played", [letter_char], "Played letter: %s"))
		# Disable the played letter's button: each letter once per battle
		var btn: Button = _letter_buttons.get(letter_char, null) as Button
		if btn:
			btn.disabled = true
			btn.modulate = Color(0.4, 0.4, 0.4, 0.6)
		_emit_state()
	else:
		battle_message.emit(I18n.t_fmt("battle.already_used", [letter_char], "Letter %s already used this battle."))
		_emit_state()

func confirm_turn() -> void:
	if _combat_resolved or _resolving:
		return
	if _combat_system.is_active() == false:
		return
	_resolving = true
	_timer_active = false
	_play_enemy_ai()
	_combat_system.resolve_turn()
	_emit_state()

func _auto_resolve_turn() -> void:
	if _combat_resolved or _resolving:
		return
	if _combat_system.is_active() == false:
		return
	battle_message.emit(I18n.t("battle.time_up", "Time's up! Auto-turn."))
	_resolving = true
	_timer_active = false
	_play_enemy_ai()
	_combat_system.resolve_turn()
	_emit_state()

func _play_enemy_ai() -> void:
	var chosen: String = ""
	if _enemy_letters.size() > 0:
		var enemy_hp: int = _combat_system.get_enemy_hp()
		var player_hp: int = _combat_system.get_player_hp()
		var aggressive: bool = enemy_hp < (GameState.player_max_hp / 3) or player_hp > (GameState.player_max_hp / 2)
		if aggressive:
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
	_timer_active = false
	_combat_system.end_combat_via_flee()
	battle_message.emit(I18n.t("battle.fled", "Fled the battle!"))
	_return_to_world(false)

func _start_turn_timer() -> void:
	_turn_timer = TURN_TIME_LIMIT
	_timer_active = true
	_resolving = false
	_update_timer_label()

func _update_timer_label() -> void:
	if _timer_label:
		var secs: int = max(0, int(ceil(_turn_timer)))
		_timer_label.text = str(secs)
		if secs <= 3:
			_timer_label.modulate = Color(1.0, 0.3, 0.2)
		else:
			_timer_label.modulate = Color(1.0, 0.85, 0.3)
	if OS.has_feature("web") and _timer_active:
		JavaScriptBridge.eval("window.gameTurnTimer = " + str(max(0, _turn_timer)) + ";")

func _update_player_letters_label() -> void:
	if not _player_letters_label:
		return
	var letters: Dictionary = InventoryManager.get_all_letters()
	if letters.is_empty():
		_player_letters_label.text = I18n.t("battle.your_letters_none", "Your letters: none")
		return
	var sorted_keys: Array = letters.keys()
	sorted_keys.sort()
	var parts: Array = []
	for k: String in sorted_keys:
		parts.append(k + "(" + str(letters[k]) + ")")
	_player_letters_label.text = I18n.t("battle.your_letters", "Your letters:") + " " + "  ".join(parts)

func _on_combat_started(enemy_name: String, enemy_hp: int) -> void:
	battle_message.emit(I18n.t_fmt("battle.opponent", [enemy_name, str(enemy_hp)], "Opponent: %s (HP %s)"))
	_emit_state()

func _on_card_played(card: Dictionary) -> void:
	_emit_state()

func _on_turn_order_resolved(order: Array) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameCombatTurnOrder = " + JSON.stringify(order) + ";")

func _on_damage_dealt(target: String, amount: float, letter_char: String) -> void:
	battle_message.emit(I18n.t_fmt("battle.damage", [letter_char, str(int(amount)), target], "%s dealt %s damage -> %s"))
	_spawn_damage_popup("-" + str(int(amount)), target == "player", Color(1, 0.4, 0.3))
	_emit_state()

func _on_shield_applied(target: String, amount: float, letter_char: String) -> void:
	battle_message.emit(I18n.t_fmt("battle.shield_msg", [letter_char, str(int(amount)), target], "%s raised shield %s -> %s"))
	_spawn_damage_popup(I18n.t_fmt("battle.shield_popup", [str(int(amount))], "+%s shield"), target == "player", Color(0.4, 0.7, 1))
	_emit_state()

func _on_buff_applied(target: String, buff_type: String, multiplier: float, letter_char: String) -> void:
	battle_message.emit(I18n.t_fmt("battle.buff", [letter_char, buff_type, str(multiplier), target], "%s boosted %s x%s -> %s"))
	_emit_state()

func _on_action_resolved(action: Dictionary) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameCombatLastAction = " + JSON.stringify(action) + ";")

func _on_turn_round_ended(turn: int) -> void:
	if _combat_resolved:
		return
	_build_hand_buttons()
	_update_player_letters_label()
	_start_turn_timer()
	_emit_state()
	if _auto_battle:
		_run_auto_battle_turn()

func _on_combat_ended(player_won: bool, loot: Array) -> void:
	if _combat_resolved:
		return
	_combat_resolved = true
	_timer_active = false
	if player_won:
		var loot_text: String = I18n.t("battle.victory", "Victory! Loot: ")
		if loot.size() > 0:
			loot_text += ", ".join(loot)
		else:
			loot_text += I18n.t("battle.nothing", "nothing")
		battle_message.emit(loot_text)
	else:
		battle_message.emit(I18n.t("battle.defeat", "Defeat..."))
	_emit_state()
	await get_tree().create_timer(1.5).timeout
	_return_to_world(player_won)

func _return_to_world(player_won: bool) -> void:
	GameState.is_in_combat = false
	# Record the outcome so world_map can finish off the monster on return.
	GameState.last_combat_won = player_won
	if not player_won:
		GameState.saved_player_position = Vector2(-1.0, -1.0)
		GameState.player_hp = max(GameState.player_hp, int(GameState.player_max_hp * 0.5))
		GameState.combat_cooldown = 5.0
		GameState.hp_changed.emit(GameState.player_hp, GameState.player_max_hp)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameInCombat = false;")
	get_tree().change_scene_to_file(WORLD_SCENE_PATH)

func _emit_state() -> void:
	var snapshot: Dictionary = _combat_system.get_state_snapshot()
	battle_state_changed.emit(snapshot)
	_update_ui(snapshot)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameCombatState = " + JSON.stringify(snapshot) + ";")

func _update_ui(snapshot: Dictionary) -> void:
	if _enemy_info_label:
		_enemy_info_label.text = I18n.t("battle.enemy", "Enemy:") + " " + String(snapshot.get("enemy_name", "?"))
	var hp_lbl: String = I18n.t("common.hp", "HP")
	var sh_lbl: String = I18n.t("common.shield", "Shield")
	if _enemy_hp_label:
		_enemy_hp_label.text = hp_lbl + ": " + str(snapshot.get("enemy_hp", 0)) + "/" + str(snapshot.get("enemy_max_hp", 0)) + "  " + sh_lbl + ": " + str(int(snapshot.get("enemy_shield", 0)))
	if _player_hp_label:
		_player_hp_label.text = hp_lbl + ": " + str(snapshot.get("player_hp", 0)) + "/" + str(snapshot.get("player_max_hp", 0)) + "  " + sh_lbl + ": " + str(int(snapshot.get("player_shield", 0)))
	if _enemy_hp_bar:
		_enemy_hp_bar.max_value = float(max(1, int(snapshot.get("enemy_max_hp", 1))))
		_enemy_hp_bar.value = float(int(snapshot.get("enemy_hp", 0)))
	if _player_hp_bar:
		_player_hp_bar.max_value = float(max(1, int(snapshot.get("player_max_hp", 1))))
		_player_hp_bar.value = float(int(snapshot.get("player_hp", 0)))
	if _enemy_avatar_label and _enemy_avatar_label.text == "?":
		_enemy_avatar_label.text = String(snapshot.get("enemy_name", "?")).substr(0, 2)
	if _confirm_button:
		_confirm_button.disabled = not bool(snapshot.get("is_active", false))

func _build_visual_overlays() -> void:
	# Enemy avatar (top-right)
	_enemy_avatar = ColorRect.new()
	_enemy_avatar.color = Color(0.45, 0.12, 0.12, 1)
	_enemy_avatar.offset_left = 950.0
	_enemy_avatar.offset_top = 55.0
	_enemy_avatar.offset_right = 1060.0
	_enemy_avatar.offset_bottom = 165.0
	add_child(_enemy_avatar)
	_enemy_avatar_label = Label.new()
	_enemy_avatar_label.text = "?"
	_enemy_avatar_label.offset_left = 950.0
	_enemy_avatar_label.offset_top = 75.0
	_enemy_avatar_label.offset_right = 1060.0
	_enemy_avatar_label.offset_bottom = 160.0
	_enemy_avatar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_avatar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_enemy_avatar_label.add_theme_font_size_override("font_size", 56)
	_enemy_avatar_label.add_theme_color_override("font_color", Color(1, 0.9, 0.9))
	add_child(_enemy_avatar_label)
	# Player avatar (bottom-left, blue hero)
	_player_avatar = ColorRect.new()
	_player_avatar.color = Color(0.15, 0.25, 0.55, 1)
	_player_avatar.offset_left = 220.0
	_player_avatar.offset_top = 415.0
	_player_avatar.offset_right = 330.0
	_player_avatar.offset_bottom = 505.0
	add_child(_player_avatar)
	_player_avatar_label = Label.new()
	_player_avatar_label.text = "Я"
	_player_avatar_label.offset_left = 220.0
	_player_avatar_label.offset_top = 420.0
	_player_avatar_label.offset_right = 330.0
	_player_avatar_label.offset_bottom = 505.0
	_player_avatar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_player_avatar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_player_avatar_label.add_theme_font_size_override("font_size", 48)
	_player_avatar_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1))
	add_child(_player_avatar_label)
	# HP bars
	_enemy_hp_bar = ProgressBar.new()
	_enemy_hp_bar.offset_left = 440.0
	_enemy_hp_bar.offset_top = 122.0
	_enemy_hp_bar.offset_right = 840.0
	_enemy_hp_bar.offset_bottom = 142.0
	_enemy_hp_bar.min_value = 0.0
	_enemy_hp_bar.show_percentage = false
	_enemy_hp_bar.modulate = Color(0.9, 0.3, 0.3)
	add_child(_enemy_hp_bar)
	_player_hp_bar = ProgressBar.new()
	_player_hp_bar.offset_left = 440.0
	_player_hp_bar.offset_top = 488.0
	_player_hp_bar.offset_right = 840.0
	_player_hp_bar.offset_bottom = 508.0
	_player_hp_bar.min_value = 0.0
	_player_hp_bar.show_percentage = false
	_player_hp_bar.modulate = Color(0.3, 0.8, 0.4)
	add_child(_player_hp_bar)
	# Auto-battle button (F1)
	_auto_battle_btn = Button.new()
	_auto_battle_btn.text = I18n.t("battle.autobattle", "Auto")
	_auto_battle_btn.offset_left = 850.0
	_auto_battle_btn.offset_top = 635.0
	_auto_battle_btn.offset_right = 1010.0
	_auto_battle_btn.offset_bottom = 685.0
	_auto_battle_btn.add_theme_font_size_override("font_size", 18)
	_auto_battle_btn.toggle_mode = true
	_auto_battle_btn.modulate = Color(0.9, 0.85, 0.5)
	_auto_battle_btn.pressed.connect(_toggle_auto_battle)
	add_child(_auto_battle_btn)

func _toggle_auto_battle() -> void:
	_auto_battle = not _auto_battle
	if _auto_battle_btn:
		_auto_battle_btn.text = I18n.t("battle.autobattle_on", "Auto ON") if _auto_battle else I18n.t("battle.autobattle", "Auto")
	if _auto_battle and not _combat_resolved and not _resolving:
		_run_auto_battle_turn()

func _run_auto_battle_turn() -> void:
	var reason: String = ""
	if not _auto_battle:
		reason = "not_auto"
	elif _combat_resolved:
		reason = "resolved"
	elif _resolving:
		reason = "resolving"
	elif not _combat_system.is_active():
		reason = "inactive"
	if reason != "":
		if OS.has_feature("web"):
			JavaScriptBridge.eval("window.gameAutoDebug = '" + reason + "';")
		return
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameAutoRounds = (window.gameAutoRounds || 0) + 1; window.gameAutoDebug = 'ran';")
	# Pick best available vowel (attack) not yet used this battle; fallback to any unused letter
	var best_letter: String = ""
	var best_power: int = -1
	var letters: Dictionary = InventoryManager.get_all_letters()
	for letter_char: String in letters:
		if _combat_system.is_letter_played(letter_char):
			continue
		var data: Dictionary = AlphabetData.get_letter(letter_char)
		if String(data.get("type", "")) == "vowel":
			var p: int = int(data.get("base_power", 0)) * int(letters[letter_char])
			if p > best_power:
				best_power = p
				best_letter = letter_char
	if best_letter == "":
		for letter_char: String in letters:
			if not _combat_system.is_letter_played(letter_char):
				best_letter = letter_char
				break
	if best_letter != "":
		_combat_system.play_card(best_letter)
	_emit_state()
	# Confirm after a short beat
	await get_tree().create_timer(0.25).timeout
	if _auto_battle and not _combat_resolved and _combat_system.is_active():
		_resolving = true
		_timer_active = false
		_play_enemy_ai()
		_combat_system.resolve_turn()
		_emit_state()

func _spawn_damage_popup(text: String, is_player_target: bool, color: Color) -> void:
	var popup: Label = Label.new()
	popup.text = text
	popup.add_theme_font_size_override("font_size", 30)
	popup.add_theme_color_override("font_color", color)
	popup.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	popup.add_theme_constant_override("outline_size", 5)
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var base_x: float = 985.0 if not is_player_target else 275.0
	var base_y: float = 60.0 if not is_player_target else 420.0
	popup.offset_left = base_x - 50.0
	popup.offset_top = base_y
	popup.offset_right = base_x + 50.0
	popup.offset_bottom = base_y + 40.0
	add_child(popup)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "offset_top", base_y - 70.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tween.chain().tween_callback(popup.queue_free)

func _build_hand_buttons() -> void:
	if not _card_container:
		return
	_letter_buttons.clear()
	_spell_buttons.clear()
	for child: Node in _card_container.get_children():
		child.queue_free()
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
		_letter_buttons[letter_char] = btn
		# Already used this battle → keep disabled (each letter once per battle)
		if _combat_system != null and _combat_system.is_letter_played(letter_char):
			btn.disabled = true
			btn.modulate = Color(0.35, 0.35, 0.35, 0.5)
	for spell: Dictionary in SpellData.get_available_spells():
		var word: String = String(spell.get("word", ""))
		var power: int = int(SpellData.calculate_power(word))
		var sbtn: Button = Button.new()
		sbtn.text = word + " " + str(power)
		sbtn.custom_minimum_size = Vector2(90, 80)
		sbtn.modulate = Color(1.0, 0.85, 0.4)
		sbtn.add_theme_font_size_override("font_size", 16)
		sbtn.pressed.connect(_on_spell_button_pressed.bind(word))
		_card_container.add_child(sbtn)
		_spell_buttons[word] = sbtn
		if _combat_system != null and _combat_system.is_spell_cast(word):
			sbtn.disabled = true
			sbtn.modulate = Color(0.35, 0.35, 0.35, 0.5)

func _on_spell_button_pressed(word: String) -> void:
	cast_spell(word)

func cast_spell(word: String) -> void:
	if _combat_resolved or _resolving:
		return
	if not SpellData.is_unlocked(word) or not SpellData.can_cast(word):
		battle_message.emit(I18n.t_fmt("battle.spell_unavailable", [word], "Spell %s unavailable!"))
		return
	var power: float = SpellData.calculate_power(word)
	var effect: String = SpellData.get_effect(word)
	var spell_type: String = SpellData.get_spell_type(word)
	var speed: int = SpellData.get_slowest_speed(word)
	if _combat_system.play_spell(word, power, effect, spell_type, speed):
		battle_message.emit(I18n.t_fmt("battle.spell_cast", [word, str(int(power))], "Spell %s! Power %s"))
		var sbtn: Button = _spell_buttons.get(word, null) as Button
		if sbtn:
			sbtn.disabled = true
			sbtn.modulate = Color(0.4, 0.4, 0.4, 0.6)
		_emit_state()
	else:
		battle_message.emit(I18n.t_fmt("battle.spell_used", [word], "Spell %s already cast this turn."))

func _sort_by_speed_desc(a: String, b: String) -> bool:
	return AlphabetData.get_speed(a) > AlphabetData.get_speed(b)

func _on_hand_button_pressed(letter_char: String) -> void:
	select_card(letter_char)

func _on_battle_message(text: String) -> void:
	if _message_label:
		_message_label.text = text
	_action_log_lines.append(text)
	if _action_log_lines.size() > 8:
		_action_log_lines = _action_log_lines.slice(-8)
	if _action_log_label:
		_action_log_label.text = "\n".join(_action_log_lines)
	if OS.has_feature("web"):
		var escaped: String = text.replace("\\", "\\\\").replace("'", "\\'")
		JavaScriptBridge.eval("window.gameBattleMessages = window.gameBattleMessages || []; window.gameBattleMessages.push('" + escaped + "');")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		confirm_turn()
