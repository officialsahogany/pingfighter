extends RefCounted

const PILLAR_GOLD := Color(0.76, 0.61, 0.31)
const PILLAR_GOLD_BRIGHT := Color(0.92, 0.79, 0.46)
const PILLAR_BROWN := Color(0.35, 0.24, 0.15)
const PILLAR_GREEN := Color(0.30, 0.44, 0.30)
const PILLAR_RED := Color(0.82, 0.74, 0.64)
const PILLAR_CREAM := Color(0.96, 0.92, 0.82)
const PILLAR_BUTTERFLY_BLUE := Color(0.36, 0.52, 0.78)
const PILLAR_BUTTERFLY_GOLD := Color(0.84, 0.68, 0.35)
const PILLAR_BUTTERFLY_RED := Color(0.72, 0.46, 0.42)


func draw(canvas: CanvasItem, rect: Rect2, mirrored: bool, t: float) -> void:
	var center_x: float = rect.position.x + rect.size.x * 0.5
	_draw_flower(canvas, Vector2(center_x, 108.0), 20.0, t * 12.0)
	_draw_flower(canvas, Vector2(center_x + (8.0 if mirrored else -8.0), rect.position.y + rect.size.y * 0.5), 18.0, -t * 10.0)
	_draw_flower(canvas, Vector2(center_x, rect.position.y + rect.size.y - 118.0), 22.0, t * 9.0)

	_draw_branch(canvas, rect, mirrored)
	_draw_butterflies(canvas, rect, mirrored, t)
	_draw_petals(canvas, rect, mirrored, t)


func _draw_flower(canvas: CanvasItem, center: Vector2, size: float, rotation_deg: float) -> void:
	canvas.draw_circle(center, size * 0.22, Color(PILLAR_GOLD.r, PILLAR_GOLD.g, PILLAR_GOLD.b, 0.95))
	canvas.draw_circle(center, size * 0.11, Color(PILLAR_GOLD_BRIGHT.r, PILLAR_GOLD_BRIGHT.g, PILLAR_GOLD_BRIGHT.b, 0.95))
	for i in range(6):
		var angle: float = deg_to_rad(rotation_deg + float(i) * 60.0)
		var petal_center: Vector2 = center + Vector2(cos(angle), sin(angle)) * size * 0.45
		canvas.draw_circle(petal_center, size * 0.23, Color(PILLAR_RED.r, PILLAR_RED.g, PILLAR_RED.b, 0.82))
		canvas.draw_circle(petal_center + Vector2(-1.0, -1.0), size * 0.10, Color(PILLAR_CREAM.r, PILLAR_CREAM.g, PILLAR_CREAM.b, 0.55))
	canvas.draw_circle(center, size * 0.60, Color(PILLAR_GOLD_BRIGHT.r, PILLAR_GOLD_BRIGHT.g, PILLAR_GOLD_BRIGHT.b, 0.18))


func _draw_branch(canvas: CanvasItem, rect: Rect2, mirrored: bool) -> void:
	var start_x: float = rect.position.x + (10.0 if not mirrored else rect.size.x - 10.0)
	var base_points: PackedVector2Array = PackedVector2Array()
	for i in range(7):
		var ratio: float = float(i) / 6.0
		var dir: float = 1.0 if not mirrored else -1.0
		var x: float = start_x + dir * (14.0 + sin(ratio * PI * 2.0) * 8.0)
		var y: float = rect.position.y + 60.0 + ratio * (rect.size.y - 120.0)
		base_points.append(Vector2(x, y))
	if base_points.size() >= 2:
		canvas.draw_polyline(base_points, Color(PILLAR_BROWN.r, PILLAR_BROWN.g, PILLAR_BROWN.b, 0.85), 2.0)
	for i in range(1, base_points.size() - 1):
		var p: Vector2 = base_points[i]
		var leaf_offset: float = 12.0 if i % 2 == 0 else -12.0
		var dir_mul: float = 1.0 if not mirrored else -1.0
		var leaf_center: Vector2 = p + Vector2(leaf_offset * dir_mul, -6.0 + float(i % 3) * 4.0)
		canvas.draw_circle(leaf_center, 4.5, Color(PILLAR_GREEN.r, PILLAR_GREEN.g, PILLAR_GREEN.b, 0.78))
		canvas.draw_circle(leaf_center + Vector2(-1.0 * dir_mul, -1.0), 2.0, Color(PILLAR_CREAM.r, PILLAR_CREAM.g, PILLAR_CREAM.b, 0.20))


func _draw_butterflies(canvas: CanvasItem, rect: Rect2, mirrored: bool, t: float) -> void:
	for i in range(2):
		var phase: float = t * (1.5 + float(i) * 0.22) + float(i) * 1.7
		var wing_open: float = sin(phase * 7.0) * 4.0
		var x_center: float = rect.position.x + rect.size.x * (0.48 + sin(phase * 0.8) * 0.12)
		var y_center: float = 165.0 + float(i) * 220.0 + sin(phase * 1.3) * 18.0
		if mirrored:
			x_center = rect.position.x + rect.size.x * (0.52 - sin(phase * 0.8) * 0.12)

		var wing_color: Color = PILLAR_BUTTERFLY_BLUE if i == 0 else PILLAR_BUTTERFLY_GOLD
		if mirrored and i == 1:
			wing_color = PILLAR_BUTTERFLY_RED

		var center: Vector2 = Vector2(x_center, y_center)
		canvas.draw_circle(center + Vector2(-6.0 - wing_open, -1.0), 5.0, Color(wing_color.r, wing_color.g, wing_color.b, 0.82))
		canvas.draw_circle(center + Vector2(6.0 + wing_open, -1.0), 5.0, Color(wing_color.r, wing_color.g, wing_color.b, 0.82))
		canvas.draw_circle(center + Vector2(-4.0 - wing_open * 0.6, 4.0), 3.8, Color(wing_color.r, wing_color.g, wing_color.b, 0.72))
		canvas.draw_circle(center + Vector2(4.0 + wing_open * 0.6, 4.0), 3.8, Color(wing_color.r, wing_color.g, wing_color.b, 0.72))
		canvas.draw_line(center + Vector2(0.0, -5.0), center + Vector2(0.0, 6.0), Color(0.20, 0.16, 0.12, 0.90), 1.2)
		canvas.draw_line(center + Vector2(-1.0, -4.0), center + Vector2(-4.0, -8.0), Color(0.20, 0.16, 0.12, 0.65), 1.0)
		canvas.draw_line(center + Vector2(1.0, -4.0), center + Vector2(4.0, -8.0), Color(0.20, 0.16, 0.12, 0.65), 1.0)
		canvas.draw_circle(center + Vector2(-6.0 - wing_open, -1.0), 1.2, Color(PILLAR_CREAM.r, PILLAR_CREAM.g, PILLAR_CREAM.b, 0.30))
		canvas.draw_circle(center + Vector2(6.0 + wing_open, -1.0), 1.2, Color(PILLAR_CREAM.r, PILLAR_CREAM.g, PILLAR_CREAM.b, 0.30))


func _draw_petals(canvas: CanvasItem, rect: Rect2, mirrored: bool, t: float) -> void:
	for i in range(4):
		var fall_progress: float = fmod(t * (0.14 + float(i) * 0.018) + float(i) * 0.23, 1.0)
		var y: float = rect.position.y - 24.0 + fall_progress * (rect.size.y + 48.0)
		var drift: float = sin(t * 1.8 + float(i) * 1.4) * 12.0
		var x: float = rect.position.x + rect.size.x * 0.5 + drift
		if mirrored:
			x = rect.position.x + rect.size.x * 0.5 - drift
		var petal_color: Color = Color(1.0, 0.86 - float(i) * 0.03, 0.90 - float(i) * 0.04, 0.58)
		canvas.draw_circle(Vector2(x, y), 3.0 + float(i % 2), petal_color)
		canvas.draw_circle(Vector2(x - 1.0, y - 1.0), 1.2, Color(PILLAR_CREAM.r, PILLAR_CREAM.g, PILLAR_CREAM.b, 0.20))
