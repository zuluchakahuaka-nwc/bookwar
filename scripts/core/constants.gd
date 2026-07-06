extends Node
# BookwarConst — global constants autoload (registered in project.godot).
# Accessible everywhere as BookwarConst.CONST_NAME. Loads before other autoloads.

# --- Player ---
const PLAYER_MAX_HP: int = 100
const MOVE_SPEED: float = 200.0
const INTERACT_RANGE: float = 200.0
const PLAYER_START: Vector2 = PLAYER_START_VALLEY

# --- Regions ---
const DEFAULT_REGION: String = "light_valley"

# --- Map progression (§18.1) — 10 maps ---
const MAP_LIGHT_VALLEY: String = "light_valley"
const MAP_TWO_LETTER_FOREST: String = "two_letter_forest"
const MAP_DARK_OAKS: String = "dark_oaks"
const MAP_MOSSY_LOWLANDS: String = "mossy_lowlands"
const MAP_ROTTEN_SWAMPS: String = "rotten_swamps"
const MAP_SWAMP_LIGHTS: String = "swamp_lights"
const MAP_STONY_WASTES: String = "stony_wastes"
const MAP_ASH_PLAINS: String = "ash_plains"
const MAP_CRYSTAL_GROTTOS: String = "crystal_grottos"
const MAP_DARK_CATHEDRAL: String = "dark_cathedral"
# Levels 11–33 (extended progression chain).
const MAP_FORGOTTEN_RUINS: String = "forgotten_ruins"
const MAP_MISTY_GROVE: String = "misty_grove"
const MAP_GREY_FOREST: String = "grey_forest"
const MAP_WIND_PASS: String = "wind_pass"
const MAP_ICE_PINCERS: String = "ice_pincers"
const MAP_MOUNTAIN_CAVES: String = "mountain_caves"
const MAP_DEEP_MINES: String = "deep_mines"
const MAP_CATACOMBS_SILENCE: String = "catacombs_silence"
const MAP_VAULTS_OBLIVION: String = "vaults_oblivion"
const MAP_UNDERGROUND_RIVER: String = "underground_river"
const MAP_FLOODED_TEMPLE: String = "flooded_temple"
const MAP_RUINED_LIBRARY: String = "ruined_library"
const MAP_BROKEN_BRIDGE: String = "broken_bridge"
const MAP_ABANDONED_VILLAGE: String = "abandoned_village"
const MAP_OLD_CITADEL: String = "old_citadel"
const MAP_SHADOW_FORTRESS: String = "shadow_fortress"
const MAP_BLACK_TOWER: String = "black_tower"
const MAP_THRONE_VOID: String = "throne_void"
const MAP_HALL_MIRRORS: String = "hall_mirrors"
const MAP_LABYRINTH_FEAR: String = "labyrinth_fear"
const MAP_CHAMBERS_BAN: String = "chambers_ban"
const MAP_THRONE_KEEPER: String = "throne_keeper"
const MAP_WELL_OF_LETTERS: String = "well_of_letters"
const FINAL_BOSS_ID: String = "keeper_of_ban"

# --- Map names ---
const LIGHT_VALLEY_NAME: String = "Светлая Долина"
const FOREST_NAME: String = "Лес Двубуквия"
const DARK_OAKS_NAME: String = "Дремучие Дубы"
const MOSSY_LOWLANDS_NAME: String = "Мшистое Низовье"
const ROTTEN_SWAMPS_NAME: String = "Гнилые Болота"
const SWAMP_LIGHTS_NAME: String = "Болотные Огни"
const STONY_WASTES_NAME: String = "Каменистая Пустошь"
const ASH_PLAINS_NAME: String = "Пепельная Равнина"
const CRYSTAL_GROTTOS_NAME: String = "Кристальные Гроты"
const DARK_CATHEDRAL_NAME: String = "Тёмный Собор"
const FORGOTTEN_RUINS_NAME: String = "Руины Забытых Слов"
const MISTY_GROVE_NAME: String = "Туманная Роща"
const GREY_FOREST_NAME: String = "Серый Лес"
const WIND_PASS_NAME: String = "Перевал Ветров"
const ICE_PINCERS_NAME: String = "Ледяные Щипцы"
const MOUNTAIN_CAVES_NAME: String = "Горные Пещеры"
const DEEP_MINES_NAME: String = "Глубокие Шахты"
const CATACOMBS_SILENCE_NAME: String = "Катакомбы Молчания"
const VAULTS_OBLIVION_NAME: String = "Склепы Забвения"
const UNDERGROUND_RIVER_NAME: String = "Подземная Река"
const FLOODED_TEMPLE_NAME: String = "Затопленный Храм"
const RUINED_LIBRARY_NAME: String = "Руины Библиотеки"
const BROKEN_BRIDGE_NAME: String = "Разрушенный Мост"
const ABANDONED_VILLAGE_NAME: String = "Заброшенная Деревня"
const OLD_CITADEL_NAME: String = "Старая Цитадель"
const SHADOW_FORTRESS_NAME: String = "Крепость Теней"
const BLACK_TOWER_NAME: String = "Чёрная Башня"
const THRONE_VOID_NAME: String = "Тронный Зал Пустоты"
const HALL_MIRRORS_NAME: String = "Зал Отражений"
const LABYRINTH_FEAR_NAME: String = "Лабиринт Страха"
const CHAMBERS_BAN_NAME: String = "Палаты Запрета"
const THRONE_KEEPER_NAME: String = "Трон Хранителя Запрета"
const WELL_OF_LETTERS_NAME: String = "Колодец Букв"

# --- Map chain (order) — 33 levels of escalating difficulty ---
const MAP_CHAIN: Array[String] = [
	MAP_LIGHT_VALLEY, MAP_TWO_LETTER_FOREST, MAP_DARK_OAKS,
	MAP_MOSSY_LOWLANDS, MAP_ROTTEN_SWAMPS, MAP_SWAMP_LIGHTS,
	MAP_STONY_WASTES, MAP_ASH_PLAINS, MAP_CRYSTAL_GROTTOS, MAP_DARK_CATHEDRAL,
	MAP_FORGOTTEN_RUINS, MAP_MISTY_GROVE, MAP_GREY_FOREST, MAP_WIND_PASS,
	MAP_ICE_PINCERS, MAP_MOUNTAIN_CAVES, MAP_DEEP_MINES, MAP_CATACOMBS_SILENCE,
	MAP_VAULTS_OBLIVION, MAP_UNDERGROUND_RIVER, MAP_FLOODED_TEMPLE, MAP_RUINED_LIBRARY,
	MAP_BROKEN_BRIDGE, MAP_ABANDONED_VILLAGE, MAP_OLD_CITADEL, MAP_SHADOW_FORTRESS,
	MAP_BLACK_TOWER, MAP_THRONE_VOID, MAP_HALL_MIRRORS, MAP_LABYRINTH_FEAR,
	MAP_CHAMBERS_BAN, MAP_THRONE_KEEPER, MAP_WELL_OF_LETTERS
]

# --- Player starts per map (all share the same tile centre) ---
const PLAYER_START_VALLEY: Vector2 = Vector2(1216.0, 1536.0)
const PLAYER_START_FOREST: Vector2 = Vector2(1216.0, 1536.0)
const PLAYER_START_DARK_OAKS: Vector2 = Vector2(1216.0, 1536.0)
const PLAYER_START_GENERIC: Vector2 = Vector2(1216.0, 1536.0)

# --- Letters available per map (progressive unlock) ---
const MAP_LETTERS: Dictionary = {
	MAP_LIGHT_VALLEY: ["А", "О", "М"],
	MAP_TWO_LETTER_FOREST: ["Е", "К", "Т", "Р", "Д"],
	MAP_DARK_OAKS: ["В", "Г", "Ж", "Л", "П", "Н"],
	MAP_MOSSY_LOWLANDS: ["З", "С", "Ф"],
	MAP_ROTTEN_SWAMPS: ["Х", "Ц", "Ч"],
	MAP_SWAMP_LIGHTS: ["Ш", "Щ", "Й"],
	MAP_STONY_WASTES: ["Б", "Ъ"],
	MAP_ASH_PLAINS: ["Ы", "Ь"],
	MAP_CRYSTAL_GROTTOS: ["Э", "Ю", "Я"],
	MAP_DARK_CATHEDRAL: ["Ш"],
	MAP_FORGOTTEN_RUINS: ["Щ"],
	MAP_MISTY_GROVE: ["Й"],
	MAP_GREY_FOREST: ["Б"],
	MAP_WIND_PASS: ["Ё"],
	MAP_ICE_PINCERS: ["И"],
	MAP_MOUNTAIN_CAVES: ["У"],
	MAP_DEEP_MINES: [],
	MAP_CATACOMBS_SILENCE: [],
	MAP_VAULTS_OBLIVION: [],
	MAP_UNDERGROUND_RIVER: [],
	MAP_FLOODED_TEMPLE: [],
	MAP_RUINED_LIBRARY: [],
	MAP_BROKEN_BRIDGE: ["Ъ"],
	MAP_ABANDONED_VILLAGE: ["Ы"],
	MAP_OLD_CITADEL: ["Ь"],
	MAP_SHADOW_FORTRESS: ["Э"],
	MAP_BLACK_TOWER: ["Ю"],
	MAP_THRONE_VOID: ["Я"],
	MAP_HALL_MIRRORS: ["Я","Ю","Э","Ь","Ы","Ъ"],
	MAP_LABYRINTH_FEAR: ["Я","Ю","Э","Ь","Ы","Ъ"],
	MAP_CHAMBERS_BAN: ["Я","Ю","Э","Ь","Ы","Ъ"],
	MAP_THRONE_KEEPER: ["Я","Ю","Э","Ь","Ы","Ъ"],
	MAP_WELL_OF_LETTERS: ["Я","Ю","Э","Ь","Ы","Ъ","Щ","Ш","А","О"],
}

# --- Enemy count per map (escalating) ---
const MAP_ENEMY_COUNT: Dictionary = {
	MAP_LIGHT_VALLEY: 8, MAP_TWO_LETTER_FOREST: 12, MAP_DARK_OAKS: 16,
	MAP_MOSSY_LOWLANDS: 18, MAP_ROTTEN_SWAMPS: 20, MAP_SWAMP_LIGHTS: 22,
	MAP_STONY_WASTES: 24, MAP_ASH_PLAINS: 26, MAP_CRYSTAL_GROTTOS: 28,
	MAP_DARK_CATHEDRAL: 30,
}

# --- Map name resolver ---
# Non-static so it can read the I18n autoload (autoloads are singletons accessed
# via their global name). Falls back to the hardcoded Russian name if no key.
func get_map_name(map_id: String) -> String:
	var fallback: String = _map_name_fallback(map_id)
	return I18n.t("region." + map_id, fallback)

static func _map_name_fallback(map_id: String) -> String:
	match map_id:
		MAP_LIGHT_VALLEY: return LIGHT_VALLEY_NAME
		MAP_TWO_LETTER_FOREST: return FOREST_NAME
		MAP_DARK_OAKS: return DARK_OAKS_NAME
		MAP_MOSSY_LOWLANDS: return MOSSY_LOWLANDS_NAME
		MAP_ROTTEN_SWAMPS: return ROTTEN_SWAMPS_NAME
		MAP_SWAMP_LIGHTS: return SWAMP_LIGHTS_NAME
		MAP_STONY_WASTES: return STONY_WASTES_NAME
		MAP_ASH_PLAINS: return ASH_PLAINS_NAME
		MAP_CRYSTAL_GROTTOS: return CRYSTAL_GROTTOS_NAME
		MAP_DARK_CATHEDRAL: return DARK_CATHEDRAL_NAME
		MAP_FORGOTTEN_RUINS: return FORGOTTEN_RUINS_NAME
		MAP_MISTY_GROVE: return MISTY_GROVE_NAME
		MAP_GREY_FOREST: return GREY_FOREST_NAME
		MAP_WIND_PASS: return WIND_PASS_NAME
		MAP_ICE_PINCERS: return ICE_PINCERS_NAME
		MAP_MOUNTAIN_CAVES: return MOUNTAIN_CAVES_NAME
		MAP_DEEP_MINES: return DEEP_MINES_NAME
		MAP_CATACOMBS_SILENCE: return CATACOMBS_SILENCE_NAME
		MAP_VAULTS_OBLIVION: return VAULTS_OBLIVION_NAME
		MAP_UNDERGROUND_RIVER: return UNDERGROUND_RIVER_NAME
		MAP_FLOODED_TEMPLE: return FLOODED_TEMPLE_NAME
		MAP_RUINED_LIBRARY: return RUINED_LIBRARY_NAME
		MAP_BROKEN_BRIDGE: return BROKEN_BRIDGE_NAME
		MAP_ABANDONED_VILLAGE: return ABANDONED_VILLAGE_NAME
		MAP_OLD_CITADEL: return OLD_CITADEL_NAME
		MAP_SHADOW_FORTRESS: return SHADOW_FORTRESS_NAME
		MAP_BLACK_TOWER: return BLACK_TOWER_NAME
		MAP_THRONE_VOID: return THRONE_VOID_NAME
		MAP_HALL_MIRRORS: return HALL_MIRRORS_NAME
		MAP_LABYRINTH_FEAR: return LABYRINTH_FEAR_NAME
		MAP_CHAMBERS_BAN: return CHAMBERS_BAN_NAME
		MAP_THRONE_KEEPER: return THRONE_KEEPER_NAME
		MAP_WELL_OF_LETTERS: return WELL_OF_LETTERS_NAME
	return "Unknown region"

static func get_next_map(map_id: String) -> String:
	var idx: int = MAP_CHAIN.find(map_id)
	if idx < 0 or idx >= MAP_CHAIN.size() - 1:
		return ""
	return MAP_CHAIN[idx + 1]

# 0-based position of a map in the 33-level chain (0 if unknown).
static func get_level_index(map_id: String) -> int:
	return MAP_CHAIN.find(map_id)

# Human-readable 1-based level number for HUD/debug.
static func get_level_number(map_id: String) -> int:
	var idx: int = MAP_CHAIN.find(map_id)
	if idx < 0:
		return 1
	return idx + 1

# Escalating enemy count for a level. Levels 1–10 use the tuned MAP_ENEMY_COUNT
# table; levels 11–33 use a smooth ramp that ends in a mass battle on 33.
static func get_map_enemy_count(map_id: String) -> int:
	if MAP_ENEMY_COUNT.has(map_id):
		return int(MAP_ENEMY_COUNT[map_id])
	var idx: int = MAP_CHAIN.find(map_id)
	if idx < 0:
		return 8
	# idx here is >= 10 (maps 11..33). Ramp from 28 (level 11) up toward the finale.
	if map_id == MAP_WELL_OF_LETTERS:
		return 56  # mass battle: толпа на толпу (? vs !)
	return 28 + (idx - 10)  # 28, 29, 30, ... 48

static func is_final_level(map_id: String) -> bool:
	return map_id == MAP_WELL_OF_LETTERS

# Final boss (evil wizard) monster id — spawned on the last level.
static func get_final_boss_id() -> String:
	return FINAL_BOSS_ID

# Lieutenants of the wizard that appear from the pre-final level onward.
static func get_lieutenants(map_id: String) -> Array:
	var idx: int = MAP_CHAIN.find(map_id)
	if idx == MAP_CHAIN.find(MAP_THRONE_KEEPER):
		return ["znak", "zvuk"]
	if map_id == MAP_WELL_OF_LETTERS:
		return ["znak", "zvuk"]
	return []

static func get_player_start(map_id: String) -> Vector2:
	return PLAYER_START_GENERIC

# --- Portal (corridor transition §18.1) ---
const PORTAL_OFFSET: Vector2 = Vector2(0.0, -800.0)

# --- Inventory ---
const ELLIPSIS_COST: int = 3

# --- Combat balance ---
const VOWEL_MULTIPLIER: float = 1.0
const CONSONANT_MULTIPLIER: float = 1.0
const SIGN_MULTIPLIER: float = 1.5

# --- Monster / combat tuning ---
const COMBAT_COOLDOWN_SEC: float = 2.0
const MAX_LOOT_DROP: int = 3
const ENEMY_DEFAULT_HP: int = 30
const ENEMY_DEFAULT_LEVEL: int = 1

# --- Alphabet ---
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

# --- Map bounds (shared by world_map + monster_spawner + monster_base) ---
# Visible tilemap is 80×60 tiles × 32px = 2560×1920. Monsters, items and the
# hero are clamped inside this rect so nothing patrols/escapes off-map.
const MAP_BOUND_MIN_X: float = 80.0
const MAP_BOUND_MAX_X: float = 2480.0
const MAP_BOUND_MIN_Y: float = 80.0
const MAP_BOUND_MAX_Y: float = 1840.0
