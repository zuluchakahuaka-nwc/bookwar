extends Node
# §20.3 §TODO#7: TacticalCombat — body-equipment combat mode (MVP).
#
# Player equips letters into body slots. Each slot accepts a letter type:
#   head:    consonant (helmet)        -> armor += base_power
#   torso:   consonant (chainmail)     -> armor += base_power
#   right_hand: vowel (weapon)         -> attack += base_power
#   left_hand:  consonant (shield) OR vowel (off-hand weapon)
#
# attack_power = sum(base_power * level) of vowels in hand slots
# armor_power  = sum(base_power * level) of consonants in body/hand slots
#
# This is a parallel mode to the card-based autobattle. The toggle is in
# battle_manager.gd (_tactical_mode). When on, the auto-resolve uses
# TacticalCombat.get_attack_power() / get_armor_power() instead of random.

signal equipment_changed

const SLOT_HEAD: String = "head"
const SLOT_TORSO: String = "torso"
const SLOT_RIGHT_HAND: String = "right_hand"
const SLOT_LEFT_HAND: String = "left_hand"

const ALL_SLOTS: Array[String] = [SLOT_HEAD, SLOT_TORSO, SLOT_RIGHT_HAND, SLOT_LEFT_HAND]

# slot -> {letter: String, level: int, type: String}
# Empty slot = null
var _slots: Dictionary = {
	SLOT_HEAD: null,
	SLOT_TORSO: null,
	SLOT_RIGHT_HAND: null,
	SLOT_LEFT_HAND: null,
}

func _ready() -> void:
	if OS.has_feature("web"):
		# Expose JS bridge for e2e tests
		JavaScriptBridge.eval("""
			window.gameTacticalEquip = function(slot, letter) {
				if (!window._godotTacticalEquip) window._godotTacticalEquip = [];
				window._godotTacticalEquip.push({slot: slot, letter: letter});
				return true;
			};
			window.gameTacticalUnequip = function(slot) {
				if (!window._godotTacticalUnequip) window._godotTacticalUnequip = [];
				window._godotTacticalUnequip.push(slot);
				return true;
			};
			window.gameTacticalClear = function() {
				window._godotTacticalClear = true;
				return true;
			};
		""", true)
		set_process(true)

func _process(_delta: float) -> void:
	if not OS.has_feature("web"):
		return
	# Drain equip queue from JS bridge
	var equip_q: Variant = JavaScriptBridge.eval("JSON.stringify(window._godotTacticalEquip || [])", true)
	JavaScriptBridge.eval("window._godotTacticalEquip = [];")
	if equip_q != null:
		var qs: String = str(equip_q)
		if qs != "" and qs != "null" and qs != "[]":
			var json: JSON = JSON.new()
			if json.parse(qs) == OK:
				for entry: Variant in json.get_data():
					var d: Dictionary = entry
					equip(String(d.get("slot", "")), String(d.get("letter", "")))
	# Drain unequip queue
	var unequip_q: Variant = JavaScriptBridge.eval("JSON.stringify(window._godotTacticalUnequip || [])", true)
	JavaScriptBridge.eval("window._godotTacticalUnequip = [];")
	if unequip_q != null:
		var qs2: String = str(unequip_q)
		if qs2 != "" and qs2 != "null" and qs2 != "[]":
			var json2: JSON = JSON.new()
			if json2.parse(qs2) == OK:
				for slot_name: Variant in json2.get_data():
					unequip(String(slot_name))
	# Clear
	if JavaScriptBridge.eval("(window._godotTacticalClear === true) ? 1 : 0", true) == 1:
		JavaScriptBridge.eval("window._godotTacticalClear = false;")
		clear_all()
	# Always expose current state for tests/Vision
	_push_state_to_js()

func _push_state_to_js() -> void:
	var snapshot: Dictionary = {}
	for slot: String in ALL_SLOTS:
		var entry: Variant = _slots[slot]
		if entry == null:
			snapshot[slot] = null
		else:
			snapshot[slot] = entry
	var json_text: String = JSON.stringify(snapshot)
	JavaScriptBridge.eval("window.gameTacticalSlots = " + json_text + ";", true)
	JavaScriptBridge.eval("window.gameTacticalAttack = " + str(get_attack_power()) + ";", true)
	JavaScriptBridge.eval("window.gameTacticalArmor = " + str(get_armor_power()) + ";", true)

# --- Public API ---

func equip(slot: String, letter: String) -> bool:
	if not ALL_SLOTS.has(slot):
		push_warning("[tactical] unknown slot: " + slot)
		return false
	if letter.length() == 0:
		unequip(slot)
		return true
	# Validate type per slot (use AlphabetData.get_letter(char).type).
	var letter_dict: Dictionary = AlphabetData.get_letter(letter)
	var letter_type: String = String(letter_dict.get("type", ""))
	if letter_type == "":
		push_warning("[tactical] unknown letter: " + letter)
		return false
	match slot:
		SLOT_HEAD, SLOT_TORSO:
			if letter_type != "consonant":
				push_warning("[tactical] " + slot + " requires consonant, got " + letter_type)
				return false
		SLOT_RIGHT_HAND:
			if letter_type != "vowel":
				push_warning("[tactical] right_hand requires vowel, got " + letter_type)
				return false
		SLOT_LEFT_HAND:
			# Accept either vowel or consonant (off-hand weapon OR shield)
			pass
	_slots[slot] = {
		"letter": letter,
		"level": InventoryManager.get_letter_level(letter),
		"type": letter_type,
	}
	equipment_changed.emit()
	return true

func unequip(slot: String) -> void:
	if not _slots.has(slot):
		return
	_slots[slot] = null
	equipment_changed.emit()

func clear_all() -> void:
	for slot: String in ALL_SLOTS:
		_slots[slot] = null
	equipment_changed.emit()

func get_attack_power() -> int:
	# Sum base_power * level of vowels in hand slots (right + left if vowel).
	var total: int = 0
	for slot: String in [SLOT_RIGHT_HAND, SLOT_LEFT_HAND]:
		var entry: Variant = _slots[slot]
		if entry == null:
			continue
		var d: Dictionary = entry
		if String(d.get("type", "")) == "vowel":
			total += AlphabetData.get_base_power(String(d.get("letter", ""))) * int(d.get("level", 1))
	return total

func get_armor_power() -> int:
	# Sum base_power * level of consonants in head, torso, left_hand (if shield).
	var total: int = 0
	for slot: String in [SLOT_HEAD, SLOT_TORSO, SLOT_LEFT_HAND]:
		var entry: Variant = _slots[slot]
		if entry == null:
			continue
		var d: Dictionary = entry
		if String(d.get("type", "")) == "consonant":
			total += AlphabetData.get_base_power(String(d.get("letter", ""))) * int(d.get("level", 1))
	return total

func get_slots_snapshot() -> Dictionary:
	return _slots.duplicate(true)

# §20.3 full: Auto-equip best letters from inventory into slots.
# Strategy: highest base_power * level available letter per slot's type constraint.
# Returns the number of slots successfully filled.
func auto_equip_best() -> int:
	var letters: Dictionary = InventoryManager.get_all_letters()
	# Build sorted pools: vowels and consonants, sorted by power desc.
	var vowels: Array = []      # [{letter, power}]
	var consonants: Array = []
	for letter: String in letters.keys():
		var lvl: int = int(letters[letter])
		if lvl < 1:
			continue
		var letter_dict: Dictionary = AlphabetData.get_letter(letter)
		var ltype: String = String(letter_dict.get("type", ""))
		if ltype == "":
			continue
		var power: int = AlphabetData.get_base_power(letter) * lvl
		if ltype == "vowel":
			vowels.append({"letter": letter, "power": power})
		elif ltype == "consonant":
			consonants.append({"letter": letter, "power": power})
	# Sort descending by power
	vowels.sort_custom(func(a, b): return int(a.power) > int(b.power))
	consonants.sort_custom(func(a, b): return int(a.power) > int(b.power))
	# Clear existing equipment first so we re-pick fresh
	clear_all()
	var filled: int = 0
	# right_hand = best vowel (weapon)
	if vowels.size() > 0:
		if equip(SLOT_RIGHT_HAND, String(vowels[0].letter)):
			filled += 1
			vowels.remove_at(0)
	# head = best consonant (helmet)
	if consonants.size() > 0:
		if equip(SLOT_HEAD, String(consonants[0].letter)):
			filled += 1
			consonants.remove_at(0)
	# torso = next best consonant (chainmail)
	if consonants.size() > 0:
		if equip(SLOT_TORSO, String(consonants[0].letter)):
			filled += 1
			consonants.remove_at(0)
	# left_hand = best remaining (vowel for dual-wield OR consonant for shield).
	# Prefer another vowel if available (more attack), else shield.
	if vowels.size() > 0:
		if equip(SLOT_LEFT_HAND, String(vowels[0].letter)):
			filled += 1
	elif consonants.size() > 0:
		if equip(SLOT_LEFT_HAND, String(consonants[0].letter)):
			filled += 1
	return filled

# §20.3 full: cycle a slot through available letters of its type.
# Used by tactical panel click handlers — click a slot to cycle to next letter.
# Returns the new letter (or "" if slot is now empty).
func cycle_slot(slot: String) -> String:
	if not ALL_SLOTS.has(slot):
		return ""
	# Determine allowed type(s) for this slot
	var allowed_types: Array[String] = []
	match slot:
		SLOT_HEAD, SLOT_TORSO:
			allowed_types = ["consonant"]
		SLOT_RIGHT_HAND:
			allowed_types = ["vowel"]
		SLOT_LEFT_HAND:
			allowed_types = ["vowel", "consonant"]
	# Build pool of available letters of allowed type
	var letters: Dictionary = InventoryManager.get_all_letters()
	var pool: Array = []
	for letter: String in letters.keys():
		var lvl: int = int(letters[letter])
		if lvl < 1:
			continue
		var letter_dict: Dictionary = AlphabetData.get_letter(letter)
		var ltype: String = String(letter_dict.get("type", ""))
		if allowed_types.has(ltype):
			pool.append(letter)
	if pool.is_empty():
		return ""
	pool.sort()  # deterministic alphabetical order
	# Current letter in this slot
	var current_idx: int = -1
	var entry: Variant = _slots[slot]
	if entry != null:
		var cur_letter: String = String((entry as Dictionary).get("letter", ""))
		current_idx = pool.find(cur_letter)
	# Next index (cycles through pool, then "empty" at end, then back to 0)
	var next_idx: int = current_idx + 1
	if next_idx >= pool.size():
		# Past the end -> unequip
		unequip(slot)
		return ""
	equip(slot, String(pool[next_idx]))
	return String(pool[next_idx])
