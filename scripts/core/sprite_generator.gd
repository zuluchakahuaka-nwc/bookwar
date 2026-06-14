extends SceneTree

const SPRITES_DIR: String = "res://assets/generated/"
const TILE_SIZE: int = 32

func _init() -> void:
	_generate_all()
	print("All sprites generated!")
	DirAccess.make_dir_recursive_absolute(SPRITES_DIR + "done")
	quit()

func _generate_all() -> void:
	_generate_tiles()
	_generate_characters()
	_generate_monsters()
	_generate_letter_cards()
	_generate_punctuation()
	_generate_ui()

func _save_image(image: Image, filename: String) -> void:
	var path: String = SPRITES_DIR + filename
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)

func _create_filled(size: int, color: Color) -> Image:
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return img

func _generate_tiles() -> void:
	_generate_grass()
	_generate_grass_dark()
	_generate_dirt_path()
	_generate_water()
	_generate_stone()
	_generate_forest_floor()

func _generate_grass() -> void:
	var img: Image = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	var base: Color = Color(0.35, 0.7, 0.25)
	var light: Color = Color(0.45, 0.8, 0.35)
	var dark: Color = Color(0.3, 0.6, 0.2)
	img.fill(base)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	for x: int in range(TILE_SIZE):
		for y: int in range(TILE_SIZE):
			var r: float = rng.randf()
			if r < 0.15:
				img.set_pixel(x, y, light)
			elif r < 0.25:
				img.set_pixel(x, y, dark)
			if rng.randf() < 0.03:
				for dx: int in range(-1, 2):
					var gx: int = x + dx
					if gx >= 0 and gx < TILE_SIZE:
						img.set_pixel(gx, max(y - 1, 0), Color(0.3, 0.55, 0.15))
	_save_image(img, "tiles/grass.png")

func _generate_grass_dark() -> void:
	var img: Image = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	var base: Color = Color(0.2, 0.45, 0.15)
	var light: Color = Color(0.25, 0.5, 0.2)
	img.fill(base)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 100
	for x: int in range(TILE_SIZE):
		for y: int in range(TILE_SIZE):
			if rng.randf() < 0.2:
				img.set_pixel(x, y, light)
	_save_image(img, "tiles/grass_dark.png")

func _generate_dirt_path() -> void:
	var img: Image = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	var base: Color = Color(0.6, 0.45, 0.3)
	var light: Color = Color(0.7, 0.55, 0.35)
	var dark: Color = Color(0.5, 0.35, 0.2)
	img.fill(base)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 50
	for x: int in range(TILE_SIZE):
		for y: int in range(TILE_SIZE):
			var r: float = rng.randf()
			if r < 0.15:
				img.set_pixel(x, y, light)
			elif r < 0.25:
				img.set_pixel(x, y, dark)
			if rng.randf() < 0.04:
				img.set_pixel(x, y, Color(0.3, 0.2, 0.1))
	_save_image(img, "tiles/dirt_path.png")

func _generate_water() -> void:
	var img: Image = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	var base: Color = Color(0.2, 0.4, 0.7)
	var light: Color = Color(0.3, 0.5, 0.8)
	var foam: Color = Color(0.7, 0.85, 0.95)
	img.fill(base)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 77
	for x: int in range(TILE_SIZE):
		for y: int in range(TILE_SIZE):
			if rng.randf() < 0.2:
				img.set_pixel(x, y, light)
			if absf(sin(float(x) * 0.5) + sin(float(y) * 0.3)) > 1.5:
				img.set_pixel(x, y, foam)
	_save_image(img, "tiles/water.png")

func _generate_stone() -> void:
	var img: Image = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	var base: Color = Color(0.5, 0.5, 0.5)
	var light: Color = Color(0.6, 0.6, 0.6)
	var dark: Color = Color(0.4, 0.4, 0.4)
	img.fill(base)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 88
	for x: int in range(TILE_SIZE):
		for y: int in range(TILE_SIZE):
			var r: float = rng.randf()
			if r < 0.15:
				img.set_pixel(x, y, light)
			elif r < 0.3:
				img.set_pixel(x, y, dark)
			if x % 8 == 0 or y % 8 == 0:
				if rng.randf() < 0.5:
					img.set_pixel(x, y, dark)
	_save_image(img, "tiles/stone.png")

func _generate_forest_floor() -> void:
	var img: Image = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	var base: Color = Color(0.15, 0.35, 0.1)
	var leaf: Color = Color(0.3, 0.2, 0.05)
	img.fill(base)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 66
	for x: int in range(TILE_SIZE):
		for y: int in range(TILE_SIZE):
			if rng.randf() < 0.08:
				img.set_pixel(x, y, leaf)
			if rng.randf() < 0.03:
				img.set_pixel(x, y, Color(0.1, 0.25, 0.05))
	_save_image(img, "tiles/forest_floor.png")

func _generate_characters() -> void:
	_generate_player()
	_generate_tree()
	_generate_house()

func _generate_player() -> void:
	var size: int = 32
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var body: Color = Color(0.2, 0.4, 0.8)
	var skin: Color = Color(0.9, 0.75, 0.6)
	var hair: Color = Color(0.4, 0.25, 0.1)
	var boots: Color = Color(0.3, 0.2, 0.1)
	var cape: Color = Color(0.7, 0.15, 0.15)
	for x: int in range(12, 20):
		for y: int in range(4, 10):
			img.set_pixel(x, y, hair)
	for x: int in range(13, 19):
		for y: int in range(7, 12):
			img.set_pixel(x, y, skin)
	img.set_pixel(14, 8, Color(0.1, 0.1, 0.1))
	img.set_pixel(17, 8, Color(0.1, 0.1, 0.1))
	img.set_pixel(15, 9, Color(0.6, 0.3, 0.3))
	img.set_pixel(16, 9, Color(0.6, 0.3, 0.3))
	for x: int in range(11, 21):
		for y: int in range(12, 22):
			img.set_pixel(x, y, body)
	for x: int in range(12, 20):
		for y: int in range(15, 22):
			img.set_pixel(x, y, cape)
	for x: int in range(11, 16):
		for y: int in range(22, 28):
			img.set_pixel(x, y, boots)
	for x: int in range(17, 21):
		for y: int in range(22, 28):
			img.set_pixel(x, y, boots)
	_save_image(img, "sprites/characters/player.png")

func _generate_tree() -> void:
	var size: int = 32
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var trunk: Color = Color(0.4, 0.25, 0.1)
	var leaves: Color = Color(0.2, 0.55, 0.15)
	var leaves_light: Color = Color(0.3, 0.65, 0.2)
	for x: int in range(13, 19):
		for y: int in range(18, 30):
			img.set_pixel(x, y, trunk)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 55
	for dx: int in range(-7, 8):
		for dy: int in range(-9, 5):
			var dist: float = sqrt(float(dx * dx + dy * dy))
			if dist < 8.0:
				var px: int = 16 + dx
				var py: int = 10 + dy
				if px >= 0 and px < size and py >= 0 and py < size:
					img.set_pixel(px, py, leaves if rng.randf() > 0.3 else leaves_light)
	_save_image(img, "sprites/environment/tree.png")

func _generate_house() -> void:
	var size: int = 48
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var wall: Color = Color(0.75, 0.65, 0.45)
	var roof: Color = Color(0.6, 0.25, 0.15)
	var door: Color = Color(0.4, 0.25, 0.1)
	var window_c: Color = Color(0.6, 0.8, 0.9)
	var frame: Color = Color(0.3, 0.2, 0.1)
	for x: int in range(4, 44):
		for y: int in range(20, 42):
			img.set_pixel(x, y, wall)
	for x: int in range(0, 48):
		for y: int in range(6, 22):
	var cx: float = float(x - 24)
	var cy: float = float(y - 22)
			if absf(cx) < (22.0 - cy * 1.2):
				img.set_pixel(x, y, roof)
	for x: int in range(20, 28):
		for y: int in range(32, 42):
			img.set_pixel(x, y, door)
	for x: int in range(8, 17):
		for y: int in range(24, 32):
			img.set_pixel(x, y, frame)
	for x: int in range(9, 16):
		for y: int in range(25, 31):
			img.set_pixel(x, y, window_c)
	for x: int in range(31, 40):
		for y: int in range(24, 32):
			img.set_pixel(x, y, frame)
	for x: int in range(32, 39):
		for y: int in range(25, 31):
			img.set_pixel(x, y, window_c)
	_save_image(img, "sprites/environment/house.png")

func _generate_monsters() -> void:
	_generate_question_monster()
	_generate_exclamation_monster()

func _generate_question_monster() -> void:
	var size: int = 32
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var body_c: Color = Color(0.6, 0.6, 0.75)
	var eye: Color = Color(1.0, 1.0, 0.3)
	var pupil: Color = Color(0.1, 0.1, 0.1)
	var shadow: Color = Color(0.45, 0.45, 0.6)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 33
	for dx: int in range(-10, 11):
		for dy: int in range(-12, 11):
			var dist: float = sqrt(float(dx * dx + dy * dy * 0.8))
			if dist < 10.0:
				var px: int = 16 + dx
				var py: int = 16 + dy
				if px >= 0 and px < size and py >= 0 and py < size:
					img.set_pixel(px, py, body_c if rng.randf() > 0.15 else shadow)
	for dy: int in range(2, 5):
		for dx: int in range(-1, 2):
			var wave: int = 16 + dx + int(sin(float(dy) * 2.0) * 2.0)
			if wave >= 0 and wave < size and 16 + dy < size:
				img.set_pixel(wave, 16 + dy, Color(0.5, 0.5, 0.65))
	img.set_pixel(13, 13, eye)
	img.set_pixel(18, 13, eye)
	img.set_pixel(14, 13, pupil)
	img.set_pixel(19, 13, pupil)
	var q_color: Color = Color(1.0, 1.0, 0.8)
	var q_points: Array[Vector2i] = [
		Vector2i(14, 4), Vector2i(15, 4), Vector2i(16, 4), Vector2i(17, 4),
		Vector2i(18, 4), Vector2i(18, 5), Vector2i(17, 6), Vector2i(16, 7),
		Vector2i(16, 8), Vector2i(16, 9), Vector2i(16, 10),
		Vector2i(16, 12)
	]
	for p: Vector2i in q_points:
		if p.x >= 0 and p.x < size and p.y >= 0 and p.y < size:
			img.set_pixel(p.x, p.y, q_color)
	_save_image(img, "sprites/monsters/question_monster.png")

func _generate_exclamation_monster() -> void:
	var size: int = 32
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var body_c: Color = Color(0.75, 0.35, 0.3)
	var eye: Color = Color(1.0, 0.3, 0.2)
	var pupil: Color = Color(0.1, 0.1, 0.1)
	var dark: Color = Color(0.6, 0.25, 0.2)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 44
	for dx: int in range(-10, 11):
		for dy: int in range(-12, 11):
			var dist: float = sqrt(float(dx * dx + dy * dy * 0.8))
			if dist < 10.0:
				var px: int = 16 + dx
				var py: int = 14 + dy
				if px >= 0 and px < size and py >= 0 and py < size:
					img.set_pixel(px, py, body_c if rng.randf() > 0.2 else dark)
	for spike: int in range(5):
		var bx: int = 8 + spike * 4
		for sy: int in range(3):
			img.set_pixel(bx, 4 - sy, Color(0.8, 0.2, 0.15))
	img.set_pixel(12, 11, eye)
	img.set_pixel(19, 11, eye)
	img.set_pixel(13, 11, pupil)
	img.set_pixel(20, 11, pupil)
	var ex_color: Color = Color(1.0, 1.0, 0.5)
	var ex_points: Array[Vector2i] = [
		Vector2i(15, 5), Vector2i(16, 5),
		Vector2i(15, 6), Vector2i(16, 6),
		Vector2i(15, 7), Vector2i(16, 7),
		Vector2i(15, 8),
		Vector2i(15, 10), Vector2i(16, 10)
	]
	for p: Vector2i in ex_points:
		if p.x >= 0 and p.x < size and p.y >= 0 and p.y < size:
			img.set_pixel(p.x, p.y, ex_color)
	_save_image(img, "sprites/monsters/exclamation_monster.png")

func _generate_letter_cards() -> void:
	var vowels: Array[String] = ["А", "Е", "Ё", "И", "О", "У", "Ы", "Э", "Ю", "Я"]
	var consonants: Array[String] = ["Б", "В", "Г", "Д", "Ж", "З", "Й", "К", "Л", "М", "Н", "П", "Р", "С", "Т", "Ф", "Х", "Ц", "Ч", "Ш", "Щ"]
	var signs: Array[String] = ["Ъ", "Ь"]
	for letter: String in vowels:
		_generate_single_letter(letter, Color(0.7, 0.2, 0.15), Color(1.0, 0.85, 0.7))
	for letter: String in consonants:
		_generate_single_letter(letter, Color(0.15, 0.3, 0.6), Color(0.7, 0.85, 1.0))
	for letter: String in signs:
		_generate_single_letter(letter, Color(0.4, 0.2, 0.6), Color(0.85, 0.7, 1.0))

func _generate_single_letter(letter: String, bg: Color, text_c: Color) -> void:
	var size: int = 32
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for x: int in range(2, 30):
		for y: int in range(2, 30):
			var border: bool = x < 4 or x > 28 or y < 4 or y > 28
			img.set_pixel(x, y, Color(bg.r * 0.6, bg.g * 0.6, bg.b * 0.6) if border else bg)
	for x: int in range(3, 29):
		img.set_pixel(x, 3, Color(1.0, 1.0, 1.0, 0.3))
		img.set_pixel(x, 28, Color(0.0, 0.0, 0.0, 0.2))
	img.set_pixel(3, 3, Color(1.0, 1.0, 1.0, 0.4))
	img.set_pixel(28, 28, Color(0.0, 0.0, 0.0, 0.3))
	var cx: int = 10
	var cy: int = 8
	var bytes: PackedByteArray = letter.to_utf8_buffer()
	var char_val: int = bytes[0] if bytes.size() > 0 else 0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = char_val * 137
	var pattern: Array[Vector2i] = _get_letter_pixels(letter)
	for p: Vector2i in pattern:
		var px: int = cx + p.x
		var py: int = cy + p.y
		if px >= 2 and px < 30 and py >= 2 and py < 30:
			img.set_pixel(px, py, text_c)
			if px + 1 < 30:
				img.set_pixel(px + 1, py, Color(text_c.r * 0.7, text_c.g * 0.7, text_c.b * 0.7))
			if py + 1 < 30:
				img.set_pixel(px, py + 1, Color(text_c.r * 0.5, text_c.g * 0.5, text_c.b * 0.5))
	_save_image(img, "sprites/letters/letter_" + letter + ".png")

func _get_letter_pixels(letter: String) -> Array[Vector2i]:
	var pixels: Array[Vector2i] = []
	var hash_val: int = letter.hash()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash_val
	var rows: int = 5 + (hash_val % 3)
	var cols: int = 3 + (hash_val % 4)
	for y: int in range(rows):
		for x: int in range(cols):
			if rng.randf() < 0.65:
				pixels.append(Vector2i(x * 2, y * 2))
				pixels.append(Vector2i(x * 2 + 1, y * 2))
				pixels.append(Vector2i(x * 2, y * 2 + 1))
				pixels.append(Vector2i(x * 2 + 1, y * 2 + 1))
	return pixels

func _generate_punctuation() -> void:
	_generate_dot()
	_generate_ellipsis()

func _generate_dot() -> void:
	var size: int = 16
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var center: int = 8
	var glow_c: Color = Color(1.0, 1.0, 0.6, 0.4)
	var dot_c: Color = Color(1.0, 0.95, 0.5)
	for dx: int in range(-4, 5):
		for dy: int in range(-4, 5):
			var dist: float = sqrt(float(dx * dx + dy * dy))
			var px: int = center + dx
			var py: int = center + dy
			if px >= 0 and px < size and py >= 0 and py < size:
				if dist < 2.0:
					img.set_pixel(px, py, dot_c)
				elif dist < 4.0:
					img.set_pixel(px, py, glow_c)
	_save_image(img, "sprites/punctuation/dot.png")

func _generate_ellipsis() -> void:
	var size: int = 32
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var dot_c: Color = Color(1.0, 0.95, 0.5)
	var glow_c: Color = Color(1.0, 1.0, 0.6, 0.4)
	var centers: Array[int] = [8, 16, 24]
	for c: int in centers:
		for dx: int in range(-3, 4):
			for dy: int in range(-3, 4):
				var dist: float = sqrt(float(dx * dx + dy * dy))
				var px: int = c + dx
				var py: int = 16 + dy
				if px >= 0 and px < size and py >= 0 and py < size:
					if dist < 1.5:
						img.set_pixel(px, py, dot_c)
					elif dist < 3.0:
						img.set_pixel(px, py, glow_c)
	_save_image(img, "sprites/punctuation/ellipsis.png")

func _generate_ui() -> void:
	_generate_button_normal()
	_generate_button_hover()
	_generate_panel()
	_generate_hp_bar()
	_generate_inventory_slot()

func _generate_button_normal() -> void:
	var img: Image = _create_ui_rect(120, 36, Color(0.3, 0.25, 0.2), Color(0.5, 0.4, 0.3), Color(0.2, 0.15, 0.1))
	_save_image(img, "ui/button_normal.png")

func _generate_button_hover() -> void:
	var img: Image = _create_ui_rect(120, 36, Color(0.45, 0.35, 0.25), Color(0.65, 0.55, 0.4), Color(0.3, 0.2, 0.15))
	_save_image(img, "ui/button_hover.png")

func _generate_panel() -> void:
	var img: Image = _create_ui_rect(200, 150, Color(0.2, 0.18, 0.15, 0.9), Color(0.4, 0.35, 0.3), Color(0.15, 0.12, 0.1, 0.9))
	_save_image(img, "ui/panel.png")

func _generate_hp_bar() -> void:
	var img: Image = Image.create(100, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.15, 0.1))
	for x: int in range(1, 70):
		for y: int in range(1, 11):
			var g: float = 0.6 + float(x) / 200.0
			img.set_pixel(x, y, Color(0.7, g * 0.3, 0.1))
	for x: int in range(1, 99):
		img.set_pixel(x, 0, Color(0.1, 0.1, 0.1))
		img.set_pixel(x, 11, Color(0.1, 0.1, 0.1))
	for y: int in range(0, 12):
		img.set_pixel(0, y, Color(0.1, 0.1, 0.1))
		img.set_pixel(99, y, Color(0.1, 0.1, 0.1))
	_save_image(img, "ui/hp_bar.png")

func _generate_inventory_slot() -> void:
	var img: Image = Image.create(36, 36, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for x: int in range(36):
		for y: int in range(36):
			var border: bool = x < 2 or x > 33 or y < 2 or y > 33
			if border:
				img.set_pixel(x, y, Color(0.5, 0.4, 0.3))
			else:
				img.set_pixel(x, y, Color(0.25, 0.22, 0.18, 0.8))
	_save_image(img, "ui/inventory_slot.png")

func _create_ui_rect(w: int, h: int, fill: Color, border: Color, shadow: Color) -> Image:
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for x: int in range(w):
		for y: int in range(h):
			var is_border: bool = x < 3 or x >= w - 3 or y < 3 or y >= h - 3
			var is_shadow: bool = y >= h - 2 and x >= 2
			if is_border:
				img.set_pixel(x, y, border)
			elif is_shadow:
				img.set_pixel(x, y, shadow)
			else:
				img.set_pixel(x, y, fill)
	for x: int in range(3, w - 3):
		img.set_pixel(x, 3, Color(1.0, 1.0, 1.0, 0.1))
	return img
