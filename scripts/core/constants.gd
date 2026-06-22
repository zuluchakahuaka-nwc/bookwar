extends Node
# BookwarConst — global constants autoload (registered in project.godot).
# Accessible everywhere as BookwarConst.CONST_NAME. Loads before other autoloads.

# --- Player (AGENTS.md §2.4, §4.5) ---
const PLAYER_MAX_HP: int = 100
const MOVE_SPEED: float = 200.0
const INTERACT_RANGE: float = 200.0
const PLAYER_START: Vector2 = PLAYER_START_VALLEY

# --- Regions (AGENTS.md §4.5, §18) ---
const DEFAULT_REGION: String = "light_valley"
const LIGHT_VALLEY_NAME: String = "Светлая Долина"
const FOREST_NAME: String = "Лес Двубуквия"

# --- Map progression (§18.1) ---
const MAP_LIGHT_VALLEY: String = "light_valley"
const MAP_TWO_LETTER_FOREST: String = "two_letter_forest"
const MAP_DARK_OAKS: String = "dark_oaks"

# --- Map names ---
const DARK_OAKS_NAME: String = "Дремучие Дубы"

# --- Player starts per map ---
const PLAYER_START_VALLEY: Vector2 = Vector2(1216.0, 1536.0)
const PLAYER_START_FOREST: Vector2 = Vector2(1216.0, 1536.0)
const PLAYER_START_DARK_OAKS: Vector2 = Vector2(1216.0, 1536.0)

# --- Portal (corridor transition §18.1) ---
const PORTAL_OFFSET: Vector2 = Vector2(0.0, -800.0)

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

# --- Monster allegiance & recruitment (§5, §17) ---
const MONSTER_LABEL_SIZE: int = 36
const RECRUIT_CHANCE: float = 0.5
const FOLLOW_DISTANCE: float = 80.0
const FOLLOW_SPEED_MULT: float = 1.0
const MONSTER_SCALE: float = 1.0

# --- Victory (§17.4) ---
const VICTORY_CHECK_INTERVAL: float = 1.0

# --- Hiding & search (§17.5) ---
const SEARCH_DURATION: float = 4.0
const HIDEABLE_TILES: Array[int] = [1, 2, 3, 5]
