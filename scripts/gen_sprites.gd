extends SceneTree

func _init() -> void:
	_gen_tiles()
	_gen_chars()
	_gen_monsters()
	_gen_letters()
	_gen_punct()
	_gen_ui()
	print("ALL DONE")
	quit()

func _save(img: Image, path: String) -> void:
	img.save_png("res://assets/generated/" + path)

func _gen_tiles() -> void:
	var s: int = 32
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	
	rng.seed = 42
	var grass: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	grass.fill(Color(0.35, 0.7, 0.25))
	for x in range(s):
		for y in range(s):
			if rng.randf() < 0.15:
				grass.set_pixel(x, y, Color(0.45, 0.8, 0.35))
			elif rng.randf() < 0.1:
				grass.set_pixel(x, y, Color(0.3, 0.6, 0.2))
	_save(grass, "tiles/grass.png")
	
	rng.seed = 100
	var dark_grass: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	dark_grass.fill(Color(0.2, 0.45, 0.15))
	for x in range(s):
		for y in range(s):
			if rng.randf() < 0.2:
				dark_grass.set_pixel(x, y, Color(0.25, 0.5, 0.2))
	_save(dark_grass, "tiles/grass_dark.png")
	
	rng.seed = 50
	var dirt: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	dirt.fill(Color(0.6, 0.45, 0.3))
	for x in range(s):
		for y in range(s):
			if rng.randf() < 0.15:
				dirt.set_pixel(x, y, Color(0.7, 0.55, 0.35))
			elif rng.randf() < 0.1:
				dirt.set_pixel(x, y, Color(0.5, 0.35, 0.2))
	_save(dirt, "tiles/dirt.png")
	
	rng.seed = 77
	var water: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	water.fill(Color(0.2, 0.4, 0.7))
	for x in range(s):
		for y in range(s):
			if rng.randf() < 0.2:
				water.set_pixel(x, y, Color(0.3, 0.5, 0.8))
			if absf(sin(float(x) * 0.5) + sin(float(y) * 0.3)) > 1.5:
				water.set_pixel(x, y, Color(0.7, 0.85, 0.95))
	_save(water, "tiles/water.png")
	
	rng.seed = 88
	var stone: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	stone.fill(Color(0.5, 0.5, 0.5))
	for x in range(s):
		for y in range(s):
			if rng.randf() < 0.15:
				stone.set_pixel(x, y, Color(0.6, 0.6, 0.6))
			elif rng.randf() < 0.15:
				stone.set_pixel(x, y, Color(0.4, 0.4, 0.4))
	_save(stone, "tiles/stone.png")
	
	rng.seed = 66
	var forest: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	forest.fill(Color(0.15, 0.35, 0.1))
	for x in range(s):
		for y in range(s):
			if rng.randf() < 0.08:
				forest.set_pixel(x, y, Color(0.3, 0.2, 0.05))
	_save(forest, "tiles/forest.png")
	
	print("tiles done")

func _gen_chars() -> void:
	var s: int = 32
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var body: Color = Color(0.2, 0.4, 0.8)
	var skin: Color = Color(0.9, 0.75, 0.6)
	var hair: Color = Color(0.4, 0.25, 0.1)
	var cape: Color = Color(0.7, 0.15, 0.15)
	var boots: Color = Color(0.3, 0.2, 0.1)
	for x in range(12, 20):
		for y in range(4, 10):
			img.set_pixel(x, y, hair)
	for x in range(13, 19):
		for y in range(7, 12):
			img.set_pixel(x, y, skin)
	img.set_pixel(14, 8, Color.BLACK)
	img.set_pixel(17, 8, Color.BLACK)
	for x in range(11, 21):
		for y in range(12, 22):
			img.set_pixel(x, y, body)
	for x in range(12, 20):
		for y in range(15, 22):
			img.set_pixel(x, y, cape)
	for x in range(11, 16):
		for y in range(22, 28):
			img.set_pixel(x, y, boots)
	for x in range(17, 21):
		for y in range(22, 28):
			img.set_pixel(x, y, boots)
	_save(img, "sprites/characters/player.png")
	
	var tree: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	tree.fill(Color.TRANSPARENT)
	for x in range(13, 19):
		for y in range(18, 30):
			tree.set_pixel(x, y, Color(0.4, 0.25, 0.1))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 55
	for dx in range(-7, 8):
		for dy in range(-9, 5):
			if sqrt(float(dx * dx + dy * dy)) < 8.0:
				var px: int = 16 + dx
				var py: int = 10 + dy
				if px >= 0 and px < s and py >= 0 and py < s:
					tree.set_pixel(px, py, Color(0.2, 0.55, 0.15) if rng.randf() > 0.3 else Color(0.3, 0.65, 0.2))
	_save(tree, "sprites/environment/tree.png")
	
	var house: Image = Image.create(48, 48, false, Image.FORMAT_RGBA8)
	house.fill(Color.TRANSPARENT)
	for x in range(4, 44):
		for y in range(20, 42):
			house.set_pixel(x, y, Color(0.75, 0.65, 0.45))
	for x in range(0, 48):
		for y in range(6, 22):
			var cx: float = float(x - 24)
			var cy: float = float(y - 22)
			if absf(cx) < (22.0 - cy * 1.2):
				house.set_pixel(x, y, Color(0.6, 0.25, 0.15))
	for x in range(20, 28):
		for y in range(32, 42):
			house.set_pixel(x, y, Color(0.4, 0.25, 0.1))
	for x in range(8, 17):
		for y in range(24, 32):
			house.set_pixel(x, y, Color(0.3, 0.2, 0.1))
			if x > 8 and x < 16 and y > 24 and y < 31:
				house.set_pixel(x, y, Color(0.6, 0.8, 0.9))
	for x in range(31, 40):
		for y in range(24, 32):
			house.set_pixel(x, y, Color(0.3, 0.2, 0.1))
			if x > 31 and x < 39 and y > 24 and y < 31:
				house.set_pixel(x, y, Color(0.6, 0.8, 0.9))
	_save(house, "sprites/environment/house.png")
	
	print("chars done")

func _gen_monsters() -> void:
	var s: int = 32
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	
	rng.seed = 33
	var qm: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	qm.fill(Color.TRANSPARENT)
	for dx in range(-10, 11):
		for dy in range(-12, 11):
			if sqrt(float(dx * dx + dy * dy * 64) / 100.0) < 10.0:
				var px: int = 16 + dx
				var py: int = 16 + dy
				if px >= 0 and px < s and py >= 0 and py < s:
					qm.set_pixel(px, py, Color(0.6, 0.6, 0.75) if rng.randf() > 0.15 else Color(0.45, 0.45, 0.6))
	qm.set_pixel(13, 13, Color(1.0, 1.0, 0.3))
	qm.set_pixel(18, 13, Color(1.0, 1.0, 0.3))
	qm.set_pixel(14, 13, Color.BLACK)
	qm.set_pixel(19, 13, Color.BLACK)
	for p in [Vector2i(14, 4), Vector2i(15, 4), Vector2i(16, 4), Vector2i(17, 4), Vector2i(18, 4),
			Vector2i(18, 5), Vector2i(17, 6), Vector2i(16, 7), Vector2i(16, 8), Vector2i(16, 9),
			Vector2i(16, 10), Vector2i(16, 12)]:
		if p.x < s and p.y < s:
			qm.set_pixel(p.x, p.y, Color(1.0, 1.0, 0.8))
	_save(qm, "sprites/monsters/question_monster.png")
	
	rng.seed = 44
	var em: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	em.fill(Color.TRANSPARENT)
	for dx in range(-10, 11):
		for dy in range(-12, 11):
			if sqrt(float(dx * dx + dy * dy * 64) / 100.0) < 10.0:
				var px: int = 16 + dx
				var py: int = 14 + dy
				if px >= 0 and px < s and py >= 0 and py < s:
					em.set_pixel(px, py, Color(0.75, 0.35, 0.3) if rng.randf() > 0.2 else Color(0.6, 0.25, 0.2))
	for spike in range(5):
		var bx: int = 8 + spike * 4
		for sy in range(3):
			em.set_pixel(bx, 4 - sy, Color(0.8, 0.2, 0.15))
	em.set_pixel(12, 11, Color(1.0, 0.3, 0.2))
	em.set_pixel(19, 11, Color(1.0, 0.3, 0.2))
	em.set_pixel(13, 11, Color.BLACK)
	em.set_pixel(20, 11, Color.BLACK)
	for p in [Vector2i(15, 5), Vector2i(16, 5), Vector2i(15, 6), Vector2i(16, 6),
			Vector2i(15, 7), Vector2i(16, 7), Vector2i(15, 8),
			Vector2i(15, 10), Vector2i(16, 10)]:
		if p.x < s and p.y < s:
			em.set_pixel(p.x, p.y, Color(1.0, 1.0, 0.5))
	_save(em, "sprites/monsters/exclamation_monster.png")
	
	print("monsters done")

func _gen_letters() -> void:
	var letters: Array = ["А","Б","В","Г","Д","Е","Ё","Ж","З","И","Й","К","Л","М","Н","О","П","Р","С","Т","У","Ф","Х","Ц","Ч","Ш","Щ","Ъ","Ы","Ь","Э","Ю","Я"]
	var vowels: Array = ["А","Е","Ё","И","О","У","Ы","Э","Ю","Я"]
	var signs: Array = ["Ъ","Ь"]
	for letter in letters:
		var bg: Color = Color(0.15, 0.3, 0.6)
		var tc: Color = Color(0.7, 0.85, 1.0)
		if letter in vowels:
			bg = Color(0.7, 0.2, 0.15)
			tc = Color(1.0, 0.85, 0.7)
		elif letter in signs:
			bg = Color(0.4, 0.2, 0.6)
			tc = Color(0.85, 0.7, 1.0)
		var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(Color.TRANSPARENT)
		for x in range(2, 30):
			for y in range(2, 30):
				var border: bool = x < 4 or x > 28 or y < 4 or y > 28
				img.set_pixel(x, y, Color(bg.r * 0.6, bg.g * 0.6, bg.b * 0.6) if border else bg)
		img.set_pixel(3, 3, Color(1, 1, 1, 0.4))
		img.set_pixel(28, 28, Color(0, 0, 0, 0.3))
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = hash(letter)
		for y in range(5):
			for x in range(4):
				if rng.randf() < 0.65:
					for ox in range(2):
						for oy in range(2):
							var px: int = 10 + x * 2 + ox
							var py: int = 8 + y * 2 + oy
							if px < 29 and py < 29:
								img.set_pixel(px, py, tc)
		_save(img, "sprites/letters/letter_" + letter + ".png")
	print("letters done (" + str(letters.size()) + ")")

func _gen_punct() -> void:
	var dot: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	dot.fill(Color.TRANSPARENT)
	for dx in range(-4, 5):
		for dy in range(-4, 5):
			var d: float = sqrt(float(dx * dx + dy * dy))
			if d < 2.0:
				dot.set_pixel(8 + dx, 8 + dy, Color(1.0, 0.95, 0.5))
			elif d < 4.0:
				dot.set_pixel(8 + dx, 8 + dy, Color(1.0, 1.0, 0.6, 0.4))
	_save(dot, "sprites/punctuation/dot.png")
	
	var ell: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	ell.fill(Color.TRANSPARENT)
	for c in [8, 16, 24]:
		for dx in range(-3, 4):
			for dy in range(-3, 4):
				var d: float = sqrt(float(dx * dx + dy * dy))
				if d < 1.5:
					ell.set_pixel(c + dx, 16 + dy, Color(1.0, 0.95, 0.5))
				elif d < 3.0:
					ell.set_pixel(c + dx, 16 + dy, Color(1.0, 1.0, 0.6, 0.4))
	_save(ell, "sprites/punctuation/ellipsis.png")
	print("punctuation done")

func _gen_ui() -> void:
	var btn: Image = Image.create(120, 36, false, Image.FORMAT_RGBA8)
	btn.fill(Color.TRANSPARENT)
	for x in range(120):
		for y in range(36):
			var b: bool = x < 3 or x >= 117 or y < 3 or y >= 33
			btn.set_pixel(x, y, Color(0.5, 0.4, 0.3) if b else Color(0.3, 0.25, 0.2))
	for x in range(3, 117):
		btn.set_pixel(x, 3, Color(1, 1, 1, 0.1))
	_save(btn, "ui/button.png")
	
	var panel: Image = Image.create(200, 150, false, Image.FORMAT_RGBA8)
	panel.fill(Color.TRANSPARENT)
	for x in range(200):
		for y in range(150):
			var b: bool = x < 3 or x >= 197 or y < 3 or y >= 147
			panel.set_pixel(x, y, Color(0.4, 0.35, 0.3) if b else Color(0.2, 0.18, 0.15, 0.9))
	_save(panel, "ui/panel.png")
	
	var slot: Image = Image.create(36, 36, false, Image.FORMAT_RGBA8)
	slot.fill(Color.TRANSPARENT)
	for x in range(36):
		for y in range(36):
			var b: bool = x < 2 or x > 33 or y < 2 or y > 33
			slot.set_pixel(x, y, Color(0.5, 0.4, 0.3) if b else Color(0.25, 0.22, 0.18, 0.8))
	_save(slot, "ui/slot.png")
	
	var hp: Image = Image.create(100, 12, false, Image.FORMAT_RGBA8)
	hp.fill(Color(0.2, 0.15, 0.1))
	for x in range(1, 70):
		for y in range(1, 11):
			hp.set_pixel(x, y, Color(0.7, 0.25, 0.1))
	for x in range(1, 99):
		hp.set_pixel(x, 0, Color(0.1, 0.1, 0.1))
		hp.set_pixel(x, 11, Color(0.1, 0.1, 0.1))
	for y in range(12):
		hp.set_pixel(0, y, Color(0.1, 0.1, 0.1))
		hp.set_pixel(99, y, Color(0.1, 0.1, 0.1))
	_save(hp, "ui/hp_bar.png")
	print("ui done")
