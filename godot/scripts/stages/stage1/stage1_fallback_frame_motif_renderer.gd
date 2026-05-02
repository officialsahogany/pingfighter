extends RefCounted

const PILLAR_GOLD := Color(0.76, 0.61, 0.31)
const PILLAR_GOLD_BRIGHT := Color(0.92, 0.79, 0.46)
const PILLAR_CREAM := Color(0.96, 0.92, 0.82)
const PILLAR_RED := Color(0.82, 0.74, 0.64)


func draw_frame_motifs(canvas: CanvasItem, game_rect: Rect2, t: float, source_game_height: float) -> void:
	var scale_factor: float = game_rect.size.y / max(1.0, source_game_height)
	var thunder_color: Color = Color(PILLAR_GOLD_BRIGHT.r, PILLAR_GOLD_BRIGHT.g, PILLAR_GOLD_BRIGHT.b, 0.42 + 0.08 * sin(t * 2.0))
	var thunder_dim: Color = Color(PILLAR_GOLD.r, PILLAR_GOLD.g, PILLAR_GOLD.b, 0.22)
	var thunder_size: float = 8.0 * scale_factor
	var spacing_x: float = max(28.0 * scale_factor, game_rect.size.x / 20.0)
	var spacing_y: float = max(28.0 * scale_factor, game_rect.size.y / 18.0)
	var start_x: float = game_rect.position.x + 28.0 * scale_factor
	var end_x: float = game_rect.end.x - 28.0 * scale_factor
	var start_y: float = game_rect.position.y + 28.0 * scale_factor
	var end_y: float = game_rect.end.y - 28.0 * scale_factor

	var x: float = start_x
	while x < end_x:
		_draw_thunder_symbol(canvas, Vector2(x, game_rect.position.y - 12.0 * scale_factor), thunder_size, false, thunder_color)
		_draw_thunder_symbol(canvas, Vector2(x, game_rect.end.y + 2.0 * scale_factor), thunder_size, false, thunder_dim)
		x += spacing_x

	var y: float = start_y
	while y < end_y:
		_draw_thunder_symbol(canvas, Vector2(game_rect.position.x - 12.0 * scale_factor, y), thunder_size, true, thunder_dim)
		_draw_thunder_symbol(canvas, Vector2(game_rect.end.x + 2.0 * scale_factor, y), thunder_size, true, thunder_color)
		y += spacing_y

	var corner_size: float = clamp(22.0 * scale_factor, 14.0, 28.0)
	_draw_flower(canvas, game_rect.position + Vector2(-18.0, -18.0) * scale_factor, corner_size, t * 18.0)
	_draw_flower(canvas, Vector2(game_rect.end.x + 18.0 * scale_factor, game_rect.position.y - 18.0 * scale_factor), corner_size, -t * 14.0)
	_draw_flower(canvas, Vector2(game_rect.position.x - 18.0 * scale_factor, game_rect.end.y + 18.0 * scale_factor), corner_size, -t * 16.0)
	_draw_flower(canvas, game_rect.end + Vector2(18.0, 18.0) * scale_factor, corner_size, t * 20.0)


func _draw_flower(canvas: CanvasItem, center: Vector2, size: float, rotation_deg: float) -> void:
	canvas.draw_circle(center, size * 0.22, Color(PILLAR_GOLD.r, PILLAR_GOLD.g, PILLAR_GOLD.b, 0.95))
	canvas.draw_circle(center, size * 0.11, Color(PILLAR_GOLD_BRIGHT.r, PILLAR_GOLD_BRIGHT.g, PILLAR_GOLD_BRIGHT.b, 0.95))
	for i in range(6):
		var angle: float = deg_to_rad(rotation_deg + float(i) * 60.0)
		var petal_center: Vector2 = center + Vector2(cos(angle), sin(angle)) * size * 0.45
		canvas.draw_circle(petal_center, size * 0.23, Color(PILLAR_RED.r, PILLAR_RED.g, PILLAR_RED.b, 0.82))
		canvas.draw_circle(petal_center + Vector2(-1.0, -1.0), size * 0.10, Color(PILLAR_CREAM.r, PILLAR_CREAM.g, PILLAR_CREAM.b, 0.55))
	canvas.draw_circle(center, size * 0.60, Color(PILLAR_GOLD_BRIGHT.r, PILLAR_GOLD_BRIGHT.g, PILLAR_GOLD_BRIGHT.b, 0.18))


func _draw_thunder_symbol(canvas: CanvasItem, origin: Vector2, size: float, vertical: bool, color: Color) -> void:
	var s: float = size
	var points: PackedVector2Array = PackedVector2Array()
	if not vertical:
		points = PackedVector2Array([
			origin + Vector2(0.0, 0.0),
			origin + Vector2(s, 0.0),
			origin + Vector2(s, s * 0.50),
			origin + Vector2(s * 0.50, s * 0.50),
			origin + Vector2(s * 0.50, s),
			origin + Vector2(0.0, s),
			origin + Vector2(0.0, s * 0.50),
			origin + Vector2(s * 0.50, s * 0.50),
			origin + Vector2(s * 0.50, 0.0),
		])
	else:
		points = PackedVector2Array([
			origin + Vector2(0.0, 0.0),
			origin + Vector2(0.0, s),
			origin + Vector2(s * 0.50, s),
			origin + Vector2(s * 0.50, s * 0.50),
			origin + Vector2(s, s * 0.50),
			origin + Vector2(s, 0.0),
			origin + Vector2(s * 0.50, 0.0),
			origin + Vector2(s * 0.50, s * 0.50),
			origin + Vector2(0.0, s * 0.50),
		])
	canvas.draw_polyline(points, color, max(1.0, size * 0.16))
