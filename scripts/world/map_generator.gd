extends Node2D
class_name MapGenerator

const TILE_SIZE: int = 32
const MAP_WIDTH: int = 80
const MAP_HEIGHT: int = 60

const GRASS: int = 0
const TREE: int = 1
const WATER: int = 2
const HOUSE: int = 3
const PATH: int = 4
const FENCE: int = 5
const GRASS_DARK: int = 6

@onready var tile_map: TileMapLayer = $"../TileMapLayer"

func _ready() -> void:
	_create_tileset()
	var map_id: String = GameState.current_map_id
	if map_id == BookwarConst.MAP_TWO_LETTER_FOREST:
		_generate_forest()
	elif map_id == BookwarConst.MAP_DARK_OAKS:
		_generate_dark_oaks()
	else:
		_generate_map()
	# Note: dot/letter/monster spawning is owned by world_map.gd to avoid double-spawn.

func _create_tileset() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.shape = TileSet.TILE_SHAPE_SQUARE

	var tile_paths: Array[String] = [
		"res://assets/generated/tiles/grass.png",
		"res://assets/generated/tiles/forest.png",
		"res://assets/generated/tiles/water.png",
		"res://assets/generated/tiles/stone.png",
		"res://assets/generated/tiles/dirt.png",
		"res://assets/generated/tiles/stone.png",
		"res://assets/generated/tiles/grass_dark.png",
	]

	var sources: Array[TileSetAtlasSource] = []

	for i: int in range(tile_paths.size()):
		var source := TileSetAtlasSource.new()
		# load() works in exported builds (.pck); Image.load_from_file does NOT for res://
		var tex: Texture2D = load(tile_paths[i])
		if tex == null:
			# Procedural fallback so we never get a magenta void
			var img: Image = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
			img.fill(Color(0.35, 0.6, 0.25) if i == GRASS else Color(0.5, 0.45, 0.35))
			tex = ImageTexture.create_from_image(img)
		source.texture = tex
		source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
		source.create_tile(Vector2i(0, 0))
		tile_set.add_source(source)
		sources.append(source)

	tile_map.tile_set = tile_set

func _generate_map() -> void:
	# Entire map is green grass — no border, no gray zone
	for x: int in range(MAP_WIDTH):
		for y: int in range(MAP_HEIGHT):
			tile_map.set_cell(Vector2i(x, y), GRASS, Vector2i(0, 0))

	for x: int in range(25, 55):
		tile_map.set_cell(Vector2i(x, 25), WATER, Vector2i(0, 0))
		tile_map.set_cell(Vector2i(x, 26), WATER, Vector2i(0, 0))
		tile_map.set_cell(Vector2i(x, 27), WATER, Vector2i(0, 0))
	tile_map.set_cell(Vector2i(35, 24), WATER, Vector2i(0, 0))
	tile_map.set_cell(Vector2i(36, 24), WATER, Vector2i(0, 0))
	tile_map.set_cell(Vector2i(37, 28), WATER, Vector2i(0, 0))
	tile_map.set_cell(Vector2i(38, 28), WATER, Vector2i(0, 0))

	var scattered_trees: Array[Vector2i] = [
		Vector2i(8, 5), Vector2i(15, 8), Vector2i(22, 4), Vector2i(60, 7),
		Vector2i(70, 10), Vector2i(10, 35), Vector2i(65, 40), Vector2i(5, 45),
		Vector2i(72, 15), Vector2i(68, 50), Vector2i(12, 50), Vector2i(45, 8),
		Vector2i(55, 12), Vector2i(30, 45), Vector2i(50, 50), Vector2i(18, 15),
		Vector2i(75, 35), Vector2i(62, 20), Vector2i(7, 20), Vector2i(40, 50),
	]
	for pos: Vector2i in scattered_trees:
		if pos.x < MAP_WIDTH and pos.y < MAP_HEIGHT:
			tile_map.set_cell(pos, TREE, Vector2i(0, 0))

	var house_positions: Array[Vector2i] = [
		Vector2i(35, 40), Vector2i(39, 40), Vector2i(35, 44), Vector2i(39, 44),
	]
	for pos: Vector2i in house_positions:
		tile_map.set_cell(pos, HOUSE, Vector2i(0, 0))

	for x: int in range(33, 43):
		tile_map.set_cell(Vector2i(x, 42), PATH, Vector2i(0, 0))
	for y: int in range(40, 46):
		tile_map.set_cell(Vector2i(37, y), PATH, Vector2i(0, 0))
	for x: int in range(37, 50):
		tile_map.set_cell(Vector2i(x, 48), PATH, Vector2i(0, 0))
	tile_map.set_cell(Vector2i(49, 47), PATH, Vector2i(0, 0))

	var fence_positions: Array[Vector2i] = [
		Vector2i(33, 39), Vector2i(34, 39), Vector2i(41, 39), Vector2i(42, 39),
		Vector2i(33, 45), Vector2i(34, 45), Vector2i(41, 45), Vector2i(42, 45),
	]
	for pos: Vector2i in fence_positions:
		tile_map.set_cell(pos, FENCE, Vector2i(0, 0))

func _generate_forest() -> void:
	# Base: grass everywhere — no border
	for x: int in range(MAP_WIDTH):
		for y: int in range(MAP_HEIGHT):
			tile_map.set_cell(Vector2i(x, y), GRASS, Vector2i(0, 0))
	# Organic forest: noise-based tree clusters with clearings
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 42
	noise.frequency = 0.08
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var clearing_cx: int = 38
	var clearing_cy: int = 48
	for x: int in range(2, MAP_WIDTH - 2):
		for y: int in range(2, MAP_HEIGHT - 2):
			var dx: int = x - clearing_cx
			var dy: int = y - clearing_cy
			var dist_sq: int = dx * dx + dy * dy
			# Keep clearing around player start (radius ~7)
			if dist_sq < 49:
				continue
			# Noise determines tree density — patches of dense forest + open glades
			var n: float = noise.get_noise_2d(float(x), float(y))
			# n ranges roughly -1..1; trees where n > 0.15 (~40% coverage)
			if n > 0.15:
				tile_map.set_cell(Vector2i(x, y), TREE, Vector2i(0, 0))
	# Small pond (organic shape via noise threshold)
	var pond_cx: int = 22
	var pond_cy: int = 17
	for x: int in range(16, 30):
		for y: int in range(12, 24):
			var pd: float = sqrt((x - pond_cx) ** 2 + (y - pond_cy) ** 2)
			var pn: float = noise.get_noise_2d(float(x) * 2.0, float(y) * 2.0)
			if pd + pn * 2.0 < 5.0:
				tile_map.set_cell(Vector2i(x, y), WATER, Vector2i(0, 0))
	# Winding path from clearing northward
	for y: int in range(30, MAP_HEIGHT - 3):
		var px: int = clearing_cx + int(sin(y * 0.25) * 4.0)
		tile_map.set_cell(Vector2i(px, y), PATH, Vector2i(0, 0))
	# Path across clearing
	for x: int in range(15, MAP_WIDTH - 15):
		tile_map.set_cell(Vector2i(x, clearing_cy), PATH, Vector2i(0, 0))

func _generate_dark_oaks() -> void:
	# Base: DARK grass everywhere — moodier than the bright valley/forest
	for x: int in range(MAP_WIDTH):
		for y: int in range(MAP_HEIGHT):
			tile_map.set_cell(Vector2i(x, y), GRASS_DARK, Vector2i(0, 0))
	# Dense ancient forest: lower noise threshold → heavier canopy than the forest
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 137
	noise.frequency = 0.10
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var clearing_cx: int = 38
	var clearing_cy: int = 48
	for x: int in range(1, MAP_WIDTH - 1):
		for y: int in range(1, MAP_HEIGHT - 1):
			var dx: int = x - clearing_cx
			var dy: int = y - clearing_cy
			if dx * dx + dy * dy < 36:  # keep a small safe clearing at spawn
				continue
			# ~55% tree coverage → oppressive dark wood
			if noise.get_noise_2d(float(x), float(y)) > -0.05:
				tile_map.set_cell(Vector2i(x, y), TREE, Vector2i(0, 0))
	# Ruined stone clearings (scattered paving — echoes of a lost settlement)
	var ruin_noise: FastNoiseLite = FastNoiseLite.new()
	ruin_noise.seed = 911
	ruin_noise.frequency = 0.18
	for x: int in range(5, MAP_WIDTH - 5):
		for y: int in range(5, MAP_HEIGHT - 5):
			if noise.get_noise_2d(float(x), float(y)) <= -0.05:
				if ruin_noise.get_noise_2d(float(x), float(y)) > 0.55:
					tile_map.set_cell(Vector2i(x, y), HOUSE, Vector2i(0, 0))
	# Murky pond (organic shape)
	var pond_cx: int = 60
	var pond_cy: int = 14
	for x: int in range(54, 68):
		for y: int in range(9, 21):
			var pd: float = sqrt((x - pond_cx) ** 2 + (y - pond_cy) ** 2)
			var pn: float = noise.get_noise_2d(float(x) * 2.0, float(y) * 2.0)
			if pd + pn * 2.0 < 5.5:
				tile_map.set_cell(Vector2i(x, y), WATER, Vector2i(0, 0))
	# Winding dirt path northward through the wood
	for y: int in range(30, MAP_HEIGHT - 3):
		var px: int = clearing_cx + int(sin(y * 0.2) * 5.0)
		tile_map.set_cell(Vector2i(px, y), PATH, Vector2i(0, 0))
	# Path across the spawn clearing
	for x: int in range(20, MAP_WIDTH - 20):
		tile_map.set_cell(Vector2i(x, clearing_cy), PATH, Vector2i(0, 0))
