extends CharacterBody2D
class_name Player

const DIALOGUE_MOVE_DELAY: float = 1.0

# Wobble (waddle) tuning — applies ONLY to _visual_root, so the camera,
# collision shape and interaction area stay rock-stable while the hero staggers.
const WOBBLE_AMP: float = 0.10      # max tilt in radians (~5.7°)
const WOBBLE_FREQ: float = 11.0     # step cadence (rad/s) — "немного, не быстро"
const WOBBLE_BOB: float = 1.6       # tiny vertical bob in px
# Alert (danger/treasure sense) — wobble doubles in amp+freq, see AGENTS.md §19.
const WOBBLE_ALERT_MULT: float = 2.0
const ALERT_SCAN_INTERVAL: float = 0.15   # throttle for the nearby-enemy/item scan
const ALERT_NEAR_DIST: float = 130.0      # closer than this = obvious danger → no alert wobble
const ALERT_SCREEN_DIST: float = 360.0    # camera zoom 2x → ~on-screen radius
const TREASURE_RADIUS: float = 200.0      # cluster radius for "залежи буквиц"
const TREASURE_THRESHOLD: int = 7         # ≥ this many буквиц nearby = treasure sense

var _nearest_interactable: Interactable = null
var _interactables_in_range: Array[Interactable] = []
var _visual_root: Node2D = null
var _walk_phase: float = 0.0
var _alert_scan_timer: float = 0.0
var _alert_mode: bool = false

signal player_interacted

@onready var _interaction_area: Area2D = $InteractionArea

func _ready() -> void:
	_interaction_area.body_entered.connect(_on_area_entered)
	_interaction_area.area_entered.connect(_on_interactable_entered)
	_interaction_area.area_exited.connect(_on_interactable_exited)
	# Visual pivot: holds every drawn body part. Wobbling it never tilts the camera.
	_visual_root = Node2D.new()
	_visual_root.name = "VisualRoot"
	add_child(_visual_root)
	_apply_hero_appearance()
	# Put the legacy sprite (if still visible — i.e. no procedural appearance)
	# under the visual root so it wobbles too.
	var legacy_sprite: Node = get_node_or_null("Sprite")
	if legacy_sprite:
		legacy_sprite.reparent(_visual_root)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
			window.gameTriggerDialogue = function() { window._godotDialogue = true; };
			window.gameAdvanceDialogue = function() { window._godotAdvanceDialogue = true; };
		""")

func _apply_hero_appearance() -> void:
	var hero: Dictionary = GameState.selected_hero
	var app: Variant = hero.get("appearance", null)
	if app == null or not (app is Dictionary) or (app as Dictionary).is_empty():
		if OS.has_feature("web"):
			JavaScriptBridge.eval("window.gameAppliedHeroName = ''; window.gameAppliedHeroIndex = -1;")
		return
	var a: Dictionary = app as Dictionary
	var sprite: Sprite2D = get_node_or_null("Sprite")
	if sprite:
		sprite.visible = false
	# Expose applied hero info for tests
	if OS.has_feature("web"):
		var hname: String = JSON.stringify(String(hero.get("name", "")))
		JavaScriptBridge.eval("window.gameAppliedHeroName = " + hname + "; window.gameAppliedHeroIndex = " + str(hero.get("_select_index", -1)) + "; window.gameAppliedShirt = '" + str(a.get("shirt", Color()).to_html()) + "';")
	# Build hero body via Polygon2D (same approach as monsters)
	var skin: Color = a.get("skin", Color(0.82, 0.65, 0.50))
	var shirt: Color = a.get("shirt", Color(0.50, 0.50, 0.55))
	var pants: Color = a.get("pants", Color(0.25, 0.22, 0.20))
	var hat_type: String = a.get("hat_type", "none")
	var hat_color: Color = a.get("hat_color", Color(0.30, 0.25, 0.20))
	var hair_color: Color = a.get("hair_color", Color(0.20, 0.12, 0.06))
	var beard: bool = a.get("beard", false)
	var eye_color: Color = a.get("eye_color", Color(0.15, 0.12, 0.08))
	# Scale: player sprite is ~32x40, draw proportionally
	var s: float = 0.6
	# Pants
	var p1: Polygon2D = Polygon2D.new()
	p1.polygon = PackedVector2Array([Vector2(-9, 12), Vector2(-1, 12), Vector2(-1, 25), Vector2(-9, 25)])
	p1.color = pants
	_visual_root.add_child(p1)
	var p2: Polygon2D = Polygon2D.new()
	p2.polygon = PackedVector2Array([Vector2(1, 12), Vector2(9, 12), Vector2(9, 25), Vector2(1, 25)])
	p2.color = pants
	_visual_root.add_child(p2)
	# Boots
	var boot_c: Color = Color(pants.r * 0.6, pants.g * 0.6, pants.b * 0.6)
	var b1: Polygon2D = Polygon2D.new()
	b1.polygon = PackedVector2Array([Vector2(-9, 22), Vector2(-1, 22), Vector2(-1, 26), Vector2(-9, 26)])
	b1.color = boot_c
	_visual_root.add_child(b1)
	var b2: Polygon2D = Polygon2D.new()
	b2.polygon = PackedVector2Array([Vector2(1, 22), Vector2(9, 22), Vector2(9, 26), Vector2(1, 26)])
	b2.color = boot_c
	_visual_root.add_child(b2)
	# Arms
	var arm_l: Polygon2D = Polygon2D.new()
	arm_l.polygon = PackedVector2Array([Vector2(-13, -5), Vector2(-9, -5), Vector2(-9, 12), Vector2(-13, 12)])
	arm_l.color = shirt
	_visual_root.add_child(arm_l)
	var arm_r: Polygon2D = Polygon2D.new()
	arm_r.polygon = PackedVector2Array([Vector2(9, -5), Vector2(13, -5), Vector2(13, 12), Vector2(9, 12)])
	arm_r.color = shirt
	_visual_root.add_child(arm_r)
	# Torso / shirt
	var torso: Polygon2D = Polygon2D.new()
	torso.polygon = PackedVector2Array([Vector2(-9, -5), Vector2(9, -5), Vector2(9, 14), Vector2(-9, 14)])
	torso.color = shirt
	_visual_root.add_child(torso)
	# Belt
	var belt: Polygon2D = Polygon2D.new()
	belt.polygon = PackedVector2Array([Vector2(-9, 11), Vector2(9, 11), Vector2(9, 15), Vector2(-9, 15)])
	belt.color = hat_color
	_visual_root.add_child(belt)
	# Neck
	var neck: Polygon2D = Polygon2D.new()
	neck.polygon = PackedVector2Array([Vector2(-3, -9), Vector2(3, -9), Vector2(3, -5), Vector2(-3, -5)])
	neck.color = skin
	_visual_root.add_child(neck)
	# Head (as polygon — roughly circular)
	var hr: float = 9.0
	for i in range(8):
		var ang1: float = i * PI / 4.0
		var ang2: float = (i + 1) * PI / 4.0
		var tri: Polygon2D = Polygon2D.new()
		tri.polygon = PackedVector2Array([
			Vector2(0, -15),
			Vector2(cos(ang1) * hr, -15 + sin(ang1) * hr),
			Vector2(cos(ang2) * hr, -15 + sin(ang2) * hr),
		])
		tri.color = skin
		_visual_root.add_child(tri)
	# Hair sides (if no helmet/hood)
	if hat_type != "helmet" and hat_type != "hood":
		var hair_l: Polygon2D = Polygon2D.new()
		hair_l.polygon = PackedVector2Array([Vector2(-hr, -15), Vector2(-hr - 2, -15), Vector2(-hr - 1, -10), Vector2(-hr, -10)])
		hair_l.color = hair_color
		_visual_root.add_child(hair_l)
		var hair_r: Polygon2D = Polygon2D.new()
		hair_r.polygon = PackedVector2Array([Vector2(hr, -15), Vector2(hr + 2, -15), Vector2(hr + 1, -10), Vector2(hr, -10)])
		hair_r.color = hair_color
		_visual_root.add_child(hair_r)
	# Eyes
	var eye_l: Polygon2D = Polygon2D.new()
	eye_l.polygon = PackedVector2Array([Vector2(-4, -16), Vector2(-2, -16), Vector2(-2, -14), Vector2(-4, -14)])
	eye_l.color = eye_color
	_visual_root.add_child(eye_l)
	var eye_r: Polygon2D = Polygon2D.new()
	eye_r.polygon = PackedVector2Array([Vector2(2, -16), Vector2(4, -16), Vector2(4, -14), Vector2(2, -14)])
	eye_r.color = eye_color
	_visual_root.add_child(eye_r)
	# Beard
	if beard:
		var bd: Polygon2D = Polygon2D.new()
		bd.polygon = PackedVector2Array([Vector2(-5, -12), Vector2(5, -12), Vector2(4, -8), Vector2(-4, -8)])
		bd.color = hair_color
		_visual_root.add_child(bd)
	# Hat
	match hat_type:
		"cap":
			var cap: Polygon2D = Polygon2D.new()
			cap.polygon = PackedVector2Array([Vector2(-hr, -22), Vector2(hr, -22), Vector2(hr, -18), Vector2(-hr, -18)])
			cap.color = hat_color
			_visual_root.add_child(cap)
		"hood":
			var hood: Polygon2D = Polygon2D.new()
			hood.polygon = PackedVector2Array([Vector2(-hr - 2, -10), Vector2(-hr - 2, -26), Vector2(0, -30), Vector2(hr + 2, -26), Vector2(hr + 2, -10)])
			hood.color = hat_color
			_visual_root.add_child(hood)
		"helmet":
			for i in range(8):
				var ang1: float = i * PI / 4.0
				var ang2: float = (i + 1) * PI / 4.0
				if sin((ang1 + ang2) * 0.5) < 0:
					var tri: Polygon2D = Polygon2D.new()
					tri.polygon = PackedVector2Array([
						Vector2(0, -15),
						Vector2(cos(ang1) * (hr + 1), -15 + sin(ang1) * (hr + 1)),
						Vector2(cos(ang2) * (hr + 1), -15 + sin(ang2) * (hr + 1)),
					])
					tri.color = hat_color
					_visual_root.add_child(tri)
		"crown":
			var crown_base: Polygon2D = Polygon2D.new()
			crown_base.polygon = PackedVector2Array([Vector2(-hr, -19), Vector2(hr, -19), Vector2(hr, -15), Vector2(-hr, -15)])
			crown_base.color = hat_color
			_visual_root.add_child(crown_base)
			for cx in [-hr * 0.6, 0.0, hr * 0.6]:
				var spike: Polygon2D = Polygon2D.new()
				spike.polygon = PackedVector2Array([Vector2(cx - 2, -19), Vector2(cx, -24), Vector2(cx + 2, -19)])
				spike.color = hat_color
				_visual_root.add_child(spike)
		"wizard":
			var wz: Polygon2D = Polygon2D.new()
			wz.polygon = PackedVector2Array([Vector2(-hr - 1, -16), Vector2(0, -34), Vector2(hr + 1, -16)])
			wz.color = hat_color
			_visual_root.add_child(wz)
		"bandana":
			var bnd: Polygon2D = Polygon2D.new()
			bnd.polygon = PackedVector2Array([Vector2(-hr, -21), Vector2(hr, -21), Vector2(hr, -17), Vector2(-hr, -17)])
			bnd.color = hat_color
			_visual_root.add_child(bnd)
		"wide_hat":
			var brim: Polygon2D = Polygon2D.new()
			brim.polygon = PackedVector2Array([Vector2(-hr * 1.8, -17), Vector2(hr * 1.8, -17), Vector2(hr * 1.8, -14), Vector2(-hr * 1.8, -14)])
			brim.color = hat_color
			_visual_root.add_child(brim)
			var top: Polygon2D = Polygon2D.new()
			top.polygon = PackedVector2Array([Vector2(-hr * 0.8, -17), Vector2(-hr * 0.6, -25), Vector2(hr * 0.6, -25), Vector2(hr * 0.8, -17)])
			top.color = hat_color
			_visual_root.add_child(top)
		"pointy":
			var pt: Polygon2D = Polygon2D.new()
			pt.polygon = PackedVector2Array([Vector2(-hr, -14), Vector2(0, -30), Vector2(hr, -14)])
			pt.color = hat_color
			_visual_root.add_child(pt)
		"none":
			pass

func _physics_process(_delta: float) -> void:
	var direction: Vector2 = Vector2.ZERO
	direction.x = Input.get_axis("move_left", "move_right")
	direction.y = Input.get_axis("move_up", "move_down")

	if direction != Vector2.ZERO and GameState.is_in_dialogue:
		var now: float = Time.get_ticks_msec() / 1000.0
		if now - GameState.dialogue_start_time >= DIALOGUE_MOVE_DELAY:
			GameState.end_dialogue()
			if OS.has_feature("web"):
				JavaScriptBridge.eval("window.gameDialogueActive = false;")

	if direction != Vector2.ZERO:
		direction = direction.normalized()

	velocity = direction * BookwarConst.MOVE_SPEED
	move_and_slide()
	# Waddle: tilt + tiny hop tied to actual movement (only the visuals, never the camera).
	var moving: bool = direction != Vector2.ZERO and velocity.length() > 5.0
	var alert: bool = _compute_alert(_delta)
	_update_wobble(_delta, moving, alert)
	_poll_js_bridge()

# Alert sense: hero wobbles 2x harder when danger is visible at the screen edge
# (but not point-blank) OR when a cluster of буквицы (≥7) is nearby (treasure).
func _compute_alert(delta: float) -> bool:
	_alert_scan_timer += delta
	if _alert_scan_timer < ALERT_SCAN_INTERVAL:
		return _alert_mode
	_alert_scan_timer = 0.0
	var parent: Node = get_parent()
	if parent == null:
		_alert_mode = false
		return false
	var nearest_hostile: float = 999999.0
	for child: Node in parent.get_children():
		if child is MonsterBase:
			var m: MonsterBase = child as MonsterBase
			if m.is_active() and m.get_allegiance() == MonsterBase.ALLEGIANCE_HOSTILE:
				var d: float = global_position.distance_to(m.global_position)
				if d < nearest_hostile:
					nearest_hostile = d
	var item_count: int = 0
	var items_node: Node = parent.get_node_or_null("Items")
	if items_node:
		for item: Node in items_node.get_children():
			if item is Area2D:
				if global_position.distance_to((item as Area2D).global_position) <= TREASURE_RADIUS:
					item_count += 1
	var enemy_at_edge: bool = nearest_hostile > ALERT_NEAR_DIST and nearest_hostile <= ALERT_SCREEN_DIST
	var enemy_close: bool = nearest_hostile <= ALERT_NEAR_DIST
	var treasure: bool = item_count >= TREASURE_THRESHOLD
	_alert_mode = (enemy_at_edge or treasure) and not enemy_close
	return _alert_mode

func _update_wobble(delta: float, moving: bool, alert: bool) -> void:
	if _visual_root == null:
		return
	var mult: float = WOBBLE_ALERT_MULT if alert else 1.0
	if moving or alert:
		_walk_phase += delta * WOBBLE_FREQ * mult
		_visual_root.rotation = sin(_walk_phase) * WOBBLE_AMP * mult
		_visual_root.position.y = -abs(sin(_walk_phase)) * WOBBLE_BOB * mult
	else:
		# Ease gently back to upright — "немного, но и не мгновенно"
		_walk_phase = 0.0
		_visual_root.rotation = lerp(_visual_root.rotation, 0.0, clampf(delta * 10.0, 0.0, 1.0))
		_visual_root.position.y = lerp(_visual_root.position.y, 0.0, clampf(delta * 10.0, 0.0, 1.0))

func _unhandled_input(event: InputEvent) -> void:
	if GameState.is_in_dialogue:
		if event.is_action_pressed("interact") or event.is_action_pressed("open_dialogue"):
			GameState.dialogue_advance.emit()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		_try_interact()
	if event.is_action_pressed("open_dialogue"):
		_try_dialogue()

func _try_interact() -> void:
	if _nearest_interactable != null:
		_nearest_interactable.interact()
		_nearest_interactable = null
		_update_nearest_interactable()

func _try_dialogue() -> void:
	for body: Node2D in _interaction_area.get_overlapping_bodies():
		if body is MonsterBase:
			var monster: MonsterBase = body as MonsterBase
			if monster.can_dialogue() and InventoryManager.has_ellipsis():
				monster.start_dialogue()
				return

func _on_area_entered(body: Node2D) -> void:
	if body is MonsterBase:
		var monster: MonsterBase = body as MonsterBase
		monster.on_player_detected(self)

func _on_interactable_entered(area: Area2D) -> void:
	if area is Interactable:
		_interactables_in_range.append(area)
		_update_nearest_interactable()

func _on_interactable_exited(area: Area2D) -> void:
	if area is Interactable:
		_interactables_in_range.erase(area)
		_update_nearest_interactable()

func _update_nearest_interactable() -> void:
	var closest: Interactable = null
	var closest_dist: float = BookwarConst.INTERACT_RANGE
	for interactable: Interactable in _interactables_in_range:
		var dist: float = global_position.distance_to(interactable.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = interactable
	_nearest_interactable = closest

func _poll_js_bridge() -> void:
	if not OS.has_feature("web"):
		return
	if JavaScriptBridge.eval("typeof window._godotDialogue !== 'undefined' && window._godotDialogue"):
		JavaScriptBridge.eval("window._godotDialogue = false;")
		_try_dialogue()
	if JavaScriptBridge.eval("typeof window._godotAdvanceDialogue !== 'undefined' && window._godotAdvanceDialogue"):
		JavaScriptBridge.eval("window._godotAdvanceDialogue = false;")
		GameState.dialogue_advance.emit()
