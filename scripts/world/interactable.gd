extends Area2D
class_name Interactable

@export var interaction_name: String = ""
@export var item_type: String = ""
@export var item_id: String = ""
@export var collected_key: String = ""  # stable key for persistence across battle reloads

signal interacted(interactable: Interactable)

var _is_collected: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if _is_collected:
		return
	if body is Player:
		interacted.emit(self)
		interact()

func interact() -> void:
	if _is_collected:
		return
	_is_collected = true
	if collected_key != "":
		GameState.mark_item_collected(collected_key)
	match item_type:
		"dot":
			InventoryManager.add_dots(1)
		"letter":
			InventoryManager.add_letter(item_id)
			_emit_letter_toast(item_id)
		"punctuation":
			InventoryManager.add_punctuation(item_id)
	queue_free()

func _emit_letter_toast(letter_char: String) -> void:
	# Tell the player in plain words what they got: weapon (vowel) / armor (consonant) / buff (sign).
	# "class" = letter position in the alphabet (1=А ... 33=Я). 1st-class is strongest, 33rd is weakest.
	var data: Dictionary = AlphabetData.get_letter(letter_char)
	if data.is_empty():
		return
	var t: String = data.get("type", "")
	var klass: int = int(data.get("position", 0))
	var klass_str: String = ""
	if klass > 0:
		# Append ordinal: 1-й, 2-й, 3-й, 4-й ... 33-й
		var suffix: String = "-й"
		if klass == 2 or klass == 6 or (klass >= 22 and klass <= 26) or (klass >= 32 and klass <= 36):
			suffix = "-й"  # Godot: simplify, all use -й in this range
		klass_str = " (" + str(klass) + suffix + " класс)"
	var msg: String = ""
	match t:
		"vowel":
			msg = "Получено ОРУЖИЕ — " + letter_char + klass_str
		"consonant":
			msg = "Получена БРОНЯ — " + letter_char + klass_str
		"sign":
			var r: String = data.get("role", "")
			if r == "attack_buff":
				msg = "Получен бафф АТАКИ — " + letter_char + klass_str
			elif r == "defense_buff":
				msg = "Получен бафф ЗАЩИТЫ — " + letter_char + klass_str
			else:
				msg = "Получен знак — " + letter_char + klass_str
	if msg != "":
		GameState.toast_requested.emit(msg)

func get_display_name() -> String:
	if interaction_name != "":
		return interaction_name
	match item_type:
		"dot":
			return "."
		"letter":
			return item_id
		"punctuation":
			return item_id
	return "???"
