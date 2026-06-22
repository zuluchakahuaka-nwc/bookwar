extends Control

var _appearance: Dictionary = {}

func set_appearance(app: Dictionary) -> void:
	_appearance = app
	queue_redraw()

func _draw() -> void:
	var skin: Color = _appearance.get("skin", Color(0.82, 0.65, 0.50))
	var shirt: Color = _appearance.get("shirt", Color(0.50, 0.50, 0.55))
	var pants: Color = _appearance.get("pants", Color(0.25, 0.22, 0.20))
	var hat_type: String = _appearance.get("hat_type", "none")
	var hat_color: Color = _appearance.get("hat_color", Color(0.30, 0.25, 0.20))
	var hair_color: Color = _appearance.get("hair_color", Color(0.20, 0.12, 0.06))
	var beard: bool = _appearance.get("beard", false)
	var eye_color: Color = _appearance.get("eye_color", Color(0.15, 0.12, 0.08))

	var w: float = size.x
	var h: float = size.y
	var cx: float = w * 0.5
	var scale_f: float = minf(w / 100.0, h / 120.0)

	# Layout (in unscaled space, then applied via manual scaling)
	var head_r: float = 16.0 * scale_f
	var head_cx: float = cx
	var head_cy: float = 28.0 * scale_f
	var torso_top: float = 44.0 * scale_f
	var torso_h: float = 34.0 * scale_f
	var torso_w: float = 30.0 * scale_f
	var pants_top: float = torso_top + torso_h - 2.0
	var pants_h: float = 22.0 * scale_f
	var arm_w: float = 6.0 * scale_f
	var arm_h: float = 26.0 * scale_f

	# --- Pants ---
	draw_rect(Rect2(head_cx - torso_w * 0.5 + 1.0, pants_top, torso_w * 0.45, pants_h), pants)
	draw_rect(Rect2(head_cx + 1.0, pants_top, torso_w * 0.45, pants_h), pants)

	# --- Boots ---
	var boot_color: Color = Color(pants.r * 0.6, pants.g * 0.6, pants.b * 0.6)
	draw_rect(Rect2(head_cx - torso_w * 0.5 + 1.0, pants_top + pants_h - 5.0, torso_w * 0.45, 5.0 * scale_f), boot_color)
	draw_rect(Rect2(head_cx + 1.0, pants_top + pants_h - 5.0, torso_w * 0.45, 5.0 * scale_f), boot_color)

	# --- Arms ---
	draw_rect(Rect2(head_cx - torso_w * 0.5 - arm_w - 1.0, torso_top + 2.0, arm_w, arm_h), shirt)
	draw_rect(Rect2(head_cx + torso_w * 0.5 + 1.0, torso_top + 2.0, arm_w, arm_h), shirt)
	# Hands
	draw_circle(Vector2(head_cx - torso_w * 0.5 - arm_w * 0.5 - 1.0, torso_top + arm_h + 2.0), arm_w * 0.5, skin)
	draw_circle(Vector2(head_cx + torso_w * 0.5 + arm_w * 0.5 + 1.0, torso_top + arm_h + 2.0), arm_w * 0.5, skin)

	# --- Torso / shirt ---
	draw_rect(Rect2(head_cx - torso_w * 0.5, torso_top, torso_w, torso_h), shirt)
	# Belt
	draw_rect(Rect2(head_cx - torso_w * 0.5, pants_top - 4.0 * scale_f, torso_w, 4.0 * scale_f), hat_color)

	# --- Neck ---
	draw_rect(Rect2(head_cx - 5.0 * scale_f, torso_top - 6.0 * scale_f, 10.0 * scale_f, 8.0 * scale_f), skin)

	# --- Hair (back layer, behind head) ---
	if hat_type != "helmet" and hat_type != "hood":
		var hair_r: float = head_r + 2.0
		draw_arc(Vector2(head_cx, head_cy + 2.0), hair_r, PI * 0.15, PI * 0.85, 16, hair_color, hair_r * 0.8)
	# Side hair
	if hat_type == "none" or hat_type == "bandana" or hat_type == "cap":
		draw_circle(Vector2(head_cx - head_r * 0.9, head_cy + head_r * 0.3), head_r * 0.35, hair_color)
		draw_circle(Vector2(head_cx + head_r * 0.9, head_cy + head_r * 0.3), head_r * 0.35, hair_color)

	# --- Head ---
	draw_circle(Vector2(head_cx, head_cy), head_r, skin)

	# --- Eyes ---
	draw_circle(Vector2(head_cx - head_r * 0.32, head_cy - head_r * 0.1), head_r * 0.13, eye_color)
	draw_circle(Vector2(head_cx + head_r * 0.32, head_cy - head_r * 0.1), head_r * 0.13, eye_color)
	# Eye glints
	draw_circle(Vector2(head_cx - head_r * 0.32 + 1.0, head_cy - head_r * 0.15), head_r * 0.05, Color(1, 1, 1))
	draw_circle(Vector2(head_cx + head_r * 0.32 + 1.0, head_cy - head_r * 0.15), head_r * 0.05, Color(1, 1, 1))

	# --- Beard ---
	if beard:
		draw_arc(Vector2(head_cx, head_cy + head_r * 0.4), head_r * 0.7, PI * 0.1, PI * 0.9, 12, hair_color, head_r * 0.5)

	# --- Hat ---
	match hat_type:
		"cap":
			draw_rect(Rect2(head_cx - head_r, head_cy - head_r - 2.0, head_r * 2.0, head_r * 0.65), hat_color)
			draw_rect(Rect2(head_cx - head_r, head_cy - head_r * 0.5, head_r * 2.2, head_r * 0.3), hat_color)
		"hood":
			draw_colored_polygon(PackedVector2Array([
				Vector2(head_cx - head_r - 4.0, head_cy + head_r * 0.5),
				Vector2(head_cx - head_r - 4.0, head_cy - head_r - 6.0),
				Vector2(head_cx, head_cy - head_r - 10.0),
				Vector2(head_cx + head_r + 4.0, head_cy - head_r - 6.0),
				Vector2(head_cx + head_r + 4.0, head_cy + head_r * 0.5),
			]), hat_color)
		"helmet":
			draw_arc(Vector2(head_cx, head_cy - 1.0), head_r + 1.5, PI, 0.0, 16, hat_color, head_r * 0.45)
			draw_rect(Rect2(head_cx - head_r - 1.0, head_cy - head_r * 0.3, (head_r + 1.0) * 2.0, 4.0), hat_color)
		"crown":
			draw_rect(Rect2(head_cx - head_r, head_cy - head_r * 0.4, head_r * 2.0, head_r * 0.4), hat_color)
			var spike_w: float = head_r * 0.35
			for i in range(3):
				var sx: float = head_cx - head_r + spike_w * 0.5 + i * spike_w * 1.8
				draw_colored_polygon(PackedVector2Array([
					Vector2(sx, head_cy - head_r * 0.4),
					Vector2(sx + spike_w * 0.5, head_cy - head_r * 1.1),
					Vector2(sx + spike_w, head_cy - head_r * 0.4),
				]), hat_color)
		"wizard":
			draw_colored_polygon(PackedVector2Array([
				Vector2(head_cx - head_r - 2.0, head_cy - head_r * 0.3),
				Vector2(head_cx, head_cy - head_r * 2.5),
				Vector2(head_cx + head_r + 2.0, head_cy - head_r * 0.3),
			]), hat_color)
			draw_rect(Rect2(head_cx - head_r - 3.0, head_cy - head_r * 0.5, (head_r + 3.0) * 2.0, head_r * 0.3), hat_color)
		"bandana":
			draw_rect(Rect2(head_cx - head_r, head_cy - head_r * 0.7, head_r * 2.0, head_r * 0.45), hat_color)
		"wide_hat":
			draw_rect(Rect2(head_cx - head_r * 1.8, head_cy - head_r * 0.5, head_r * 3.6, head_r * 0.35), hat_color)
			draw_colored_polygon(PackedVector2Array([
				Vector2(head_cx - head_r * 0.8, head_cy - head_r * 0.5),
				Vector2(head_cx - head_r * 0.6, head_cy - head_r * 1.3),
				Vector2(head_cx + head_r * 0.6, head_cy - head_r * 1.3),
				Vector2(head_cx + head_r * 0.8, head_cy - head_r * 0.5),
			]), hat_color)
		"pointy":
			draw_colored_polygon(PackedVector2Array([
				Vector2(head_cx - head_r, head_cy - head_r * 0.2),
				Vector2(head_cx - head_r * 0.3, head_cy - head_r * 1.8),
				Vector2(head_cx + head_r * 0.3, head_cy - head_r * 1.8),
				Vector2(head_cx + head_r, head_cy - head_r * 0.2),
			]), hat_color)
		"none":
			pass
		_:
			pass
