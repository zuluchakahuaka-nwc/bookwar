extends Control
class_name LetterCardUI

# Ornate manuscript palette per AGENTS.md §11.2 (parchment + type accents)
const PARCHMENT: Color = Color(0.86, 0.76, 0.55)
const FRAME_DARK: Color = Color(0.25, 0.16, 0.08)
const GOLD: Color = Color(0.72, 0.55, 0.18)
const INK: Color = Color(0.18, 0.10, 0.05)
const COLOR_VOWEL: Color = Color(0.72, 0.18, 0.14)
const COLOR_CONSONANT: Color = Color(0.18, 0.32, 0.60)
const COLOR_SIGN_DEFENSE: Color = Color(0.22, 0.28, 0.78)
const COLOR_SIGN_ATTACK: Color = Color(0.80, 0.22, 0.26)

@export var letter_char: String = ""
var _applied: bool = false

@onready var _glow: ColorRect = $Glow
@onready var _parchment: ColorRect = $Parchment
@onready var _outer_frame: ColorRect = $OuterFrame
@onready var _gold_frame: ColorRect = $GoldFrame
@onready var _type_bar: ColorRect = $TypeBar
@onready var _char_label: Label = $CharLabel
@onready var _corner_tl: Label = $CornerTL
@onready var _corner_br: Label = $CornerBR

func _ready() -> void:
	_apply()

func setup(char: String) -> void:
	letter_char = char
	_apply()

func _apply() -> void:
	if letter_char == "":
		return
	if not is_inside_tree():
		return  # @onready vars not ready yet; _ready will retry
	if _applied:
		return
	_applied = true
	var data: Dictionary = AlphabetData.get_letter(letter_char)
	var level: int = InventoryManager.get_letter_level(letter_char)
	if data.is_empty():
		return
	var base_power: int = int(data.get("base_power", 0))
	var letter_type: String = String(data.get("type", ""))
	var role: String = String(data.get("role", ""))
	# Glyph + playing-card corners (level top-left, power bottom-right)
	if _char_label:
		_char_label.text = letter_char
	if _corner_tl:
		_corner_tl.text = str(level)
	if _corner_br:
		_corner_br.text = str(base_power * level)
	# Type accent color (§11.2)
	var accent: Color = COLOR_CONSONANT
	var glow_color: Color = Color(0, 0, 0, 0)
	match letter_type:
		"vowel":
			accent = COLOR_VOWEL
		"consonant":
			accent = COLOR_CONSONANT
		"sign":
			if role == "attack_buff":
				accent = COLOR_SIGN_ATTACK
				glow_color = Color(0.95, 0.40, 0.30, 0.6)
			else:
				accent = COLOR_SIGN_DEFENSE
				glow_color = Color(0.40, 0.50, 1.00, 0.6)
	# Ornate double frame: dark outer + gold inner (visible on parchment)
	if _outer_frame:
		_outer_frame.color = FRAME_DARK
	if _gold_frame:
		_gold_frame.color = GOLD
	if _type_bar:
		_type_bar.color = accent
	# Level-scaled glow halo (signs glow strongly; leveled letters glow subtly)
	if _glow:
		if glow_color.a > 0.0:
			var intensity: float = clampf(0.35 + 0.12 * float(level), 0.35, 0.9)
			_glow.color = Color(glow_color.r, glow_color.g, glow_color.b, intensity)
		elif level > 1:
			_glow.color = Color(accent.r, accent.g, accent.b, clampf(0.10 + 0.06 * float(level), 0.10, 0.40))
		else:
			_glow.color = Color(0, 0, 0, 0)
