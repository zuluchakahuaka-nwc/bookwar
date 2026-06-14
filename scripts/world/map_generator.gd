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

@onready var tile_map: TileMapLayer = $"../TileMapLayer"
@onready var items_node: Node2D = $"../Items"
@onready var monster_spawner: MonsterSpawner = $"../MonsterSpawner"

func _ready() -> void:
	_create_tileset()
	_generate_map()
	_spawn_dots()
	if monster_spawner:
		monster_spawner.setup_light_valley()

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
	]

	var sources: Array[TileSetAtlasSource] = []

	for i: int in range(tile_paths.size()):
		var source := TileSetAtlasSource.new()
		var img: Image = Image.load_from_file(tile_paths[i])
		if img == null:
			img = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
			img.fill(Color.MAGENTA)
		var tex: ImageTexture = ImageTexture.create_from_image(img)
		source.texture = tex
		source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
		source.create_tile(Vector2i(0, 0))
		tile_set.add_source(source)
		sources.append(source)

	tile_map.tile_set = tile_set

func _generate_map() -> void:
	for x: int in range(MAP_WIDTH):
		for y: int in range(MAP_HEIGHT):
			tile_map.set_cell(Vector2i(x, y), GRASS, Vector2i(0, 0))

	for x: int in range(MAP_WIDTH):
		tile_map.set_cell(Vector2i(x, 0), TREE, Vector2i(0, 0))
		tile_map.set_cell(Vector2i(x, 1), TREE, Vector2i(0, 0))
		tile_map.set_cell(Vector2i(x, MAP_HEIGHT - 1), TREE, Vector2i(0, 0))
		tile_map.set_cell(Vector2i(x, MAP_HEIGHT - 2), TREE, Vector2i(0, 0))
	for y: int in range(MAP_HEIGHT):
		tile_map.set_cell(Vector2i(0, y), TREE, Vector2i(0, 0))
		tile_map.set_cell(Vector2i(1, y), TREE, Vector2i(0, 0))
		tile_map.set_cell(Vector2i(MAP_WIDTH - 1, y), TREE, Vector2i(0, 0))
		tile_map.set_cell(Vector2i(MAP_WIDTH - 2, y), TREE, Vector2i(0, 0))

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

func _spawn_dots() -> void:
	if not items_node:
		return
	var dot_scene: PackedScene = load("res://scenes/world/dot_item.tscn")
	if not dot_scene:
		return
	var dot_positions: Array[Vector2] = [
		Vector2(5, 5), Vector2(10, 8), Vector2(15, 3), Vector2(20, 10),
		Vector2(25, 6), Vector2(30, 12), Vector2(35, 4), Vector2(40, 9),
		Vector2(45, 7), Vector2(50, 11), Vector2(8, 18), Vector2(12, 22),
		Vector2(18, 16), Vector2(22, 25), Vector2(28, 15), Vector2(33, 28),
		Vector2(38, 22), Vector2(42, 30), Vector2(48, 18), Vector2(52, 25),
		Vector2(55, 14), Vector2(60, 20), Vector2(65, 8), Vector2(70, 15),
	]
	for pos: Vector2 in dot_positions:
		var dot: Node2D = dot_scene.instantiate()
		dot.global_position = pos * TILE_SIZE
		items_node.add_child(dot)
