extends Node
class_name CombatSystem

# Player state (single source of truth: GameState.player_hp)
var _player_hp: int = BookwarConst.PLAYER_MAX_HP
var _player_max_hp: int = BookwarConst.PLAYER_MAX_HP
var _player_shield: float = 0.0
var _player_attack_buff_mult: float = 1.0   # multiplied on next vowel (set by Ь)
var _player_defense_buff_mult: float = 1.0  # multiplied on next consonant (set by Ъ)

# Enemy state (local to this combat)
var _enemy_name: String = ""
var _enemy_hp: int = 0
var _enemy_max_hp: int = 0
var _enemy_shield: float = 0.0
var _enemy_attack_buff_mult: float = 1.0
var _enemy_defense_buff_mult: float = 1.0
var _enemy_letters: Array = []  # for loot drop

# Turn state
var _player_cards: Array = []
var _enemy_cards: Array = []
var _turn_order: Array = []
var _current_index: int = 0
var _is_active: bool = false
var _turn_count: int = 0
var _combat_log: Array = []
# Each letter/spell may be played at most once PER BATTLE (rationing → strategy)
var _player_played_this_battle: Dictionary = {}
var _player_spells_this_battle: Dictionary = {}

signal combat_started(enemy_name: String, enemy_hp: int)
signal card_played(card: Dictionary)
signal turn_order_resolved(order: Array)
signal action_resolved(action: Dictionary)
signal damage_dealt(target: String, amount: float, letter_char: String)
signal shield_applied(target: String, amount: float, letter_char: String)
signal buff_applied(target: String, buff_type: String, multiplier: float, letter_char: String)
signal combat_ended(player_won: bool, loot: Array)
signal turn_round_ended(turn: int)

func _ready() -> void:
	# Sync HP from GameState on init
	_player_hp = GameState.player_hp
	_player_max_hp = GameState.player_max_hp

func start_combat(enemy_name: String, enemy_hp: int, enemy_letters: Array) -> void:
	_is_active = true
	_enemy_name = enemy_name
	_enemy_hp = enemy_hp
	_enemy_max_hp = enemy_hp
	_enemy_letters = enemy_letters.duplicate()
	_player_hp = GameState.player_hp
	_player_max_hp = GameState.player_max_hp
	_player_shield = 0.0
	_enemy_shield = 0.0
	_player_attack_buff_mult = 1.0
	_player_defense_buff_mult = 1.0
	_enemy_attack_buff_mult = 1.0
	_enemy_defense_buff_mult = 1.0
	_player_cards.clear()
	_enemy_cards.clear()
	_turn_order.clear()
	_current_index = 0
	_turn_count = 0
	_combat_log.clear()
	_player_played_this_battle.clear()
	_player_spells_this_battle.clear()
	GameState.start_combat()
	combat_started.emit(enemy_name, enemy_hp)
	_log({"event": "combat_start", "enemy_name": enemy_name, "enemy_hp": enemy_hp})
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameCombatLogAll = []; window.gameCombatTurnOrder = null; window.gameCombatLastAction = null;")

func play_card(letter_char: String) -> bool:
	if not _is_active:
		return false
	if _player_played_this_battle.has(letter_char):
		_log({"event": "play_card_fail", "reason": "already_played_this_battle", "letter": letter_char})
		return false
	var level: int = InventoryManager.get_letter_level(letter_char)
	if level <= 0:
		_log({"event": "play_card_fail", "reason": "no_letter", "letter": letter_char})
		return false
	var letter: Dictionary = AlphabetData.get_letter(letter_char)
	if letter.is_empty():
		return false
	var card: Dictionary = _build_card(letter_char, letter, level, true)
	_player_cards.append(card)
	_player_played_this_battle[letter_char] = true
	card_played.emit(card)
	_log({"event": "card_played", "side": "player", "letter": letter_char, "level": level})
	return true

func is_letter_played(letter_char: String) -> bool:
	return _player_played_this_battle.has(letter_char)

func is_spell_cast(word: String) -> bool:
	return _player_spells_this_battle.has(word)

func play_enemy_card(letter_char: String, level: int) -> void:
	if not _is_active:
		return
	var letter: Dictionary = AlphabetData.get_letter(letter_char)
	if letter.is_empty():
		return
	var card: Dictionary = _build_card(letter_char, letter, level, false)
	_enemy_cards.append(card)
	card_played.emit(card)
	_log({"event": "card_played", "side": "enemy", "letter": letter_char, "level": level})

func play_spell(word: String, power: float, effect: String, spell_type: String, speed: int) -> bool:
	# A spell acts as one combined card with computed power (AGENTS.md S16.3-S16.4)
	if not _is_active:
		return false
	if _player_spells_this_battle.has(word):
		_log({"event": "play_spell_fail", "reason": "already_cast_this_battle", "word": word})
		return false
	var card: Dictionary = {
		"char": word,
		"type": "spell",
		"role": spell_type,
		"speed": speed,
		"base_power": int(power),
		"level": 1,
		"is_player": true,
		"effect": effect,
		"spell_power": power
	}
	_player_cards.append(card)
	_player_spells_this_battle[word] = true
	card_played.emit(card)
	_log({"event": "spell_played", "word": word, "power": power, "effect": effect, "type": spell_type})
	return true

func _resolve_spell(card: Dictionary) -> void:
	var word: String = card.get("char", "")
	var power: float = float(card.get("spell_power", 0.0))
	var effect: String = card.get("effect", "")
	var spell_type: String = card.get("role", "")
	# Most spells deal damage to enemy (attack/pierce/mass/ranged); defense/heal are special
	match effect:
		"heal_40":
			var hp_gain: int = 40
			_player_hp = min(_player_max_hp, _player_hp + hp_gain)
			GameState.heal(hp_gain)
			damage_dealt.emit("player_heal", hp_gain, word)
			_log({"event": "spell_heal", "word": word, "amount": hp_gain})
		"double_shield":
			_player_shield += power
			shield_applied.emit("player", power, word)
			_log({"event": "spell_shield", "word": word, "amount": power})
		_:
			# Default: damage to enemy (ignore_shield pierces)
			var target: String = "enemy"
			if effect == "ignore_shield":
				var bypass: float = _enemy_shield
				_enemy_shield = 0.0
				_apply_damage(target, power, word, 1.0)
				_enemy_shield += bypass  # restore for future (already consumed by _apply_damage)
			else:
				_apply_damage(target, power, word, 1.0)
			_log({"event": "spell_damage", "word": word, "damage": power, "effect": effect})

func _build_card(letter_char: String, letter: Dictionary, level: int, is_player: bool) -> Dictionary:
	return {
		"char": letter_char,
		"type": String(letter.get("type", "")),
		"role": String(letter.get("role", "")),
		"speed": int(letter.get("speed", 0)),
		"base_power": int(letter.get("base_power", 0)),
		"level": level,
		"is_player": is_player
	}

func resolve_turn() -> void:
	if not _is_active:
		return
	_turn_count += 1
	# Combine + sort by speed desc (fast letters act first, AGENTS.md §2.3)
	_turn_order = (_player_cards.duplicate(true) + _enemy_cards.duplicate(true))
	_turn_order.sort_custom(_compare_speed)
	_current_index = 0
	turn_order_resolved.emit(_turn_order.duplicate(true))
	_log({"event": "turn_resolved_start", "turn": _turn_count, "order_size": _turn_order.size()})
	_process_next_card()

func _compare_speed(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("speed", 0)) > int(b.get("speed", 0))

func _process_next_card() -> void:
	if _current_index >= _turn_order.size():
		_end_turn_round()
		return
	var card: Dictionary = _turn_order[_current_index]
	_current_index += 1
	_resolve_card(card)
	# Check end conditions after each card
	if _enemy_hp <= 0:
		_end_combat(true)
		return
	if _player_hp <= 0:
		_end_combat(false)
		return
	call_deferred("_process_next_card")

func _resolve_card(card: Dictionary) -> void:
	var letter_char: String = card.get("char", "")
	var is_player: bool = bool(card.get("is_player", false))
	var level: int = int(card.get("level", 0))
	var card_type: String = card.get("type", "")
	match card_type:
		"vowel":
			_resolve_vowel(card, is_player, level, letter_char)
		"consonant":
			_resolve_consonant(card, is_player, level, letter_char)
		"sign":
			_resolve_sign(card, is_player, level, letter_char)
		"spell":
			_resolve_spell(card)
		_:
			_log({"event": "unknown_card_type", "type": card_type})

func _resolve_vowel(card: Dictionary, is_player: bool, level: int, letter_char: String) -> void:
	# damage = base_power * level * VOWEL_MULTIPLIER * active_attack_buff
	var base_damage: float = AlphabetData.calculate_damage(letter_char, level)
	var buff_mult: float = _player_attack_buff_mult if is_player else _enemy_attack_buff_mult
	var damage: float = base_damage * buff_mult
	# Consume the buff
	if is_player:
		_player_attack_buff_mult = 1.0
	else:
		_enemy_attack_buff_mult = 1.0
	# Apply to opponent: shield absorbs first, then HP
	var target: String = "enemy" if is_player else "player"
	_apply_damage(target, damage, letter_char, buff_mult)

func _resolve_consonant(card: Dictionary, is_player: bool, level: int, letter_char: String) -> void:
	# shield = base_power * level * CONSONANT_MULTIPLIER * active_defense_buff
	var base_shield: float = AlphabetData.calculate_shield(letter_char, level)
	var buff_mult: float = _player_defense_buff_mult if is_player else _enemy_defense_buff_mult
	var shield: float = base_shield * buff_mult
	# Consume the buff
	if is_player:
		_player_defense_buff_mult = 1.0
	else:
		_enemy_defense_buff_mult = 1.0
	# Add to owner's shield pool
	if is_player:
		_player_shield += shield
		shield_applied.emit("player", shield, letter_char)
	else:
		_enemy_shield += shield
		shield_applied.emit("enemy", shield, letter_char)
	var action: Dictionary = {
		"event": "shield",
		"side": "player" if is_player else "enemy",
		"letter": letter_char,
		"amount": shield,
		"buff_mult": buff_mult,
		"total_shield": _player_shield if is_player else _enemy_shield
	}
	action_resolved.emit(action)
	_combat_log.append(action)
	_log(action)

func _resolve_sign(card: Dictionary, is_player: bool, level: int, letter_char: String) -> void:
	# Ъ (defense_buff): next consonant shield × 1.5
	# Ь (attack_buff): next vowel attack × 1.5
	var role: String = card.get("role", "")
	var buff_value: float = AlphabetData.calculate_shield(letter_char, level) if role == "defense_buff" else AlphabetData.calculate_damage(letter_char, level)
	# The buff VALUE is computed for logging; the EFFECT multiplier is SIGN_MULTIPLIER
	var effect_mult: float = BookwarConst.SIGN_MULTIPLIER  # = 1.5
	if role == "defense_buff":
		if is_player:
			_player_defense_buff_mult = effect_mult
		else:
			_enemy_defense_buff_mult = effect_mult
		buff_applied.emit("player" if is_player else "enemy", "defense", effect_mult, letter_char)
	elif role == "attack_buff":
		if is_player:
			_player_attack_buff_mult = effect_mult
		else:
			_enemy_attack_buff_mult = effect_mult
		buff_applied.emit("player" if is_player else "enemy", "attack", effect_mult, letter_char)
	else:
		_log({"event": "unknown_sign_role", "role": role})
		return
	var action: Dictionary = {
		"event": "buff",
		"side": "player" if is_player else "enemy",
		"letter": letter_char,
		"buff_type": role,
		"multiplier": effect_mult,
		"buff_value": buff_value
	}
	action_resolved.emit(action)
	_combat_log.append(action)
	_log(action)

func _apply_damage(target: String, damage: float, letter_char: String, buff_mult: float) -> void:
	var remaining: float = damage
	var shield_absorbed: float = 0.0
	if target == "enemy":
		if _enemy_shield > 0.0:
			shield_absorbed = min(_enemy_shield, remaining)
			_enemy_shield -= shield_absorbed
			remaining -= shield_absorbed
		_enemy_hp = max(0, _enemy_hp - int(round(remaining)))
	else:
		if _player_shield > 0.0:
			shield_absorbed = min(_player_shield, remaining)
			_player_shield -= shield_absorbed
			remaining -= shield_absorbed
		var hp_loss: int = int(round(remaining))
		_player_hp = max(0, _player_hp - hp_loss)
		# Sync to GameState (single source of truth)
		GameState.take_damage(hp_loss)
	damage_dealt.emit(target, damage, letter_char)
	var action: Dictionary = {
		"event": "damage",
		"target": target,
		"letter": letter_char,
		"damage": damage,
		"shield_absorbed": shield_absorbed,
		"hp_loss": int(round(remaining)),
		"buff_mult": buff_mult,
		"target_hp": _enemy_hp if target == "enemy" else _player_hp,
		"target_shield": _enemy_shield if target == "enemy" else _player_shield
	}
	action_resolved.emit(action)
	_combat_log.append(action)
	_log(action)

func _end_turn_round() -> void:
	# Clear played cards for next round; buffs persist into next round (consumed on first use).
	# NOTE: _player_played_this_battle is NOT cleared here — each letter once PER BATTLE.
	_player_cards.clear()
	_enemy_cards.clear()
	_turn_order.clear()
	_current_index = 0
	turn_round_ended.emit(_turn_count)
	_log({"event": "turn_round_end", "turn": _turn_count})

func _end_combat(player_won: bool) -> void:
	if not _is_active:
		return
	_is_active = false
	var loot: Array = []
	if player_won:
		loot = _generate_loot()
		for letter_char: String in loot:
			InventoryManager.add_letter(letter_char)
	# Sync HP back to GameState (already done during damage, but be safe)
	if _player_hp <= 0:
		GameState.take_damage(GameState.player_hp)  # ensure 0
	GameState.end_combat(player_won)
	_log({"event": "combat_end", "player_won": player_won, "loot": loot, "player_hp": _player_hp, "enemy_hp": _enemy_hp})
	combat_ended.emit(player_won, loot)
	_player_cards.clear()
	_enemy_cards.clear()
	_turn_order.clear()

func _generate_loot() -> Array:
	# Drop 1-3 letters from enemy_letters (AGENTS.md §5.3)
	if _enemy_letters.size() == 0:
		return []
	var count: int = min(_enemy_letters.size(), randi_range(1, BookwarConst.MAX_LOOT_DROP))
	var loot: Array = []
	var pool: Array = _enemy_letters.duplicate()
	for i: int in range(count):
		if pool.size() == 0:
			break
		var idx: int = randi() % pool.size()
		loot.append(pool[idx])
		pool.remove_at(idx)
	return loot

func end_combat_via_flee() -> void:
	if not _is_active:
		return
	_is_active = false
	_player_cards.clear()
	_enemy_cards.clear()
	_turn_order.clear()
	GameState.end_combat(false)
	_log({"event": "combat_flee", "player_hp": _player_hp})
	combat_ended.emit(false, [])

func is_active() -> bool:
	return _is_active

func get_player_hp() -> int:
	return _player_hp

func get_enemy_hp() -> int:
	return _enemy_hp

func get_player_shield() -> float:
	return _player_shield

func get_enemy_shield() -> float:
	return _enemy_shield

func get_enemy_name() -> String:
	return _enemy_name

func get_combat_log() -> Array:
	return _combat_log.duplicate(true)

func get_state_snapshot() -> Dictionary:
	return {
		"is_active": _is_active,
		"turn_count": _turn_count,
		"player_hp": _player_hp,
		"player_max_hp": _player_max_hp,
		"player_shield": _player_shield,
		"player_attack_buff": _player_attack_buff_mult,
		"player_defense_buff": _player_defense_buff_mult,
		"enemy_name": _enemy_name,
		"enemy_hp": _enemy_hp,
		"enemy_max_hp": _enemy_max_hp,
		"enemy_shield": _enemy_shield,
		"enemy_attack_buff": _enemy_attack_buff_mult,
		"enemy_defense_buff": _enemy_defense_buff_mult,
		"player_cards": _player_cards.size(),
		"enemy_cards": _enemy_cards.size(),
		"turn_order_size": _turn_order.size(),
		"current_index": _current_index,
		"played_letters": _player_played_this_battle.keys()
	}

func _log(entry: Dictionary) -> void:
	# Emit to JS bridge if available (web build)
	if OS.has_feature("web"):
		var entry_with_turn: Dictionary = entry.duplicate()
		entry_with_turn["turn"] = _turn_count
		var dumped: String = JSON.stringify(entry_with_turn)
		JavaScriptBridge.eval("window.gameCombatLog = " + dumped + "; window.gameCombatLogAll = window.gameCombatLogAll || []; window.gameCombatLogAll.push(" + dumped + ");")
