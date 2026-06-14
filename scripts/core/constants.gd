extends Node
# BookwarConst — global constants autoload (registered in project.godot).
# Accessible everywhere as BookwarConst.CONST_NAME. Loads before other autoloads.

# --- Player (AGENTS.md §2.4, §4.5) ---
const PLAYER_MAX_HP: int = 100
const MOVE_SPEED: float = 200.0
const INTERACT_RANGE: float = 200.0
const PLAYER_START: Vector2 = Vector2(1216.0, 1536.0)

# --- Regions (AGENTS.md §4.5) ---
const DEFAULT_REGION: String = "light_valley"
const LIGHT_VALLEY_NAME: String = "Светлая Долина"

# --- Inventory (AGENTS.md §3) ---
const ELLIPSIS_COST: int = 3

# --- Combat balance (AGENTS.md §2.3) ---
const VOWEL_MULTIPLIER: float = 1.0
const CONSONANT_MULTIPLIER: float = 1.0
const SIGN_MULTIPLIER: float = 1.5

# --- Monster / combat tuning (AGENTS.md §5.3) ---
const COMBAT_COOLDOWN_SEC: float = 2.0
const MAX_LOOT_DROP: int = 3
const ENEMY_DEFAULT_HP: int = 30
const ENEMY_DEFAULT_LEVEL: int = 1

# --- Alphabet (AGENTS.md §2.1) ---
const EXPECTED_LETTER_COUNT: int = 33
