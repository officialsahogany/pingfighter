extends RefCounted

const Stage1ContextReader := preload("res://scripts/stages/stage1/stage1_context_reader.gd")


func draw(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var width: float = float(context.get("width", 760.0))
	var height: float = float(context.get("height", 750.0))
	var play_left: float = float(context.get("play_left", 0.0))
	var play_right: float = float(context.get("play_right", width))
	var bg_color: Color = _as_color(context.get("bg_color", Color(0.03, 0.03, 0.08)), Color(0.03, 0.03, 0.08))
	var line_color: Color = _as_color(context.get("line_color", Color(1.0, 1.0, 1.0, 0.10)), Color(1.0, 1.0, 1.0, 0.10))

	canvas.draw_rect(Rect2(0.0, 0.0, width, height), bg_color)

	canvas.draw_line(Vector2(play_left, height * 0.5) + shake_offset, Vector2(play_right, height * 0.5) + shake_offset, line_color, 1.0)
	canvas.draw_line(Vector2(play_left, 120.0) + shake_offset, Vector2(play_right, 120.0) + shake_offset, line_color, 1.0)
	canvas.draw_line(Vector2(play_left, 630.0) + shake_offset, Vector2(play_right, 630.0) + shake_offset, line_color, 1.0)


func draw_dash_trail(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	if not bool(context.get("dash_active", false)):
		return

	var player_pos: Vector2 = _as_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
	var paddle_size: Vector2 = _as_vector2(context.get("player_paddle_size", Vector2(84.0, 16.0)), Vector2(84.0, 16.0))
	var dash_direction: float = float(context.get("dash_direction", 0.0))
	var dash_trail_color: Color
	if bool(context.get("dash_is_half", false)):
		dash_trail_color = _as_color(context.get("half_dash_color", Color(0.60, 0.60, 1.0, 0.40)), Color(0.60, 0.60, 1.0, 0.40))
	else:
		dash_trail_color = _as_color(context.get("dash_trail_color", Color(0.30, 0.50, 1.0, 0.30)), Color(0.30, 0.50, 1.0, 0.30))
	for i in range(3):
		var offset: float = -dash_direction * float(i + 1) * 15.0
		var alpha: float = 0.30 - float(i) * 0.10
		canvas.draw_rect(
			Rect2(
				player_pos.x + offset + shake_offset.x,
				player_pos.y + shake_offset.y,
				paddle_size.x,
				paddle_size.y
			),
			Color(dash_trail_color.r, dash_trail_color.g, dash_trail_color.b, alpha)
		)


func _as_vector2(value, fallback: Vector2) -> Vector2:
	return Stage1ContextReader.as_vector2(value, fallback)


func _as_color(value, fallback: Color) -> Color:
	return Stage1ContextReader.as_color(value, fallback)
