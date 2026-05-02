extends RefCounted

const DEFAULT_DISPLAY_COLORS: Array[Color] = [
	Color(100.0 / 255.0, 180.0 / 255.0, 1.0),
	Color(80.0 / 255.0, 160.0 / 255.0, 1.0),
	Color(60.0 / 255.0, 140.0 / 255.0, 1.0),
]


func draw(canvas: Node2D, shake_offset: Vector2, context: Dictionary) -> void:
	var intensity: float = float(context.get("intensity", 0.0))
	if intensity < 0.05:
		return

	var intensity_trail: Array = context.get("ball_intensity_trail", [])
	var intensity_particles: Array = context.get("ball_intensity_particles", [])
	var display_colors: Array = context.get("ball_current_display_colors", DEFAULT_DISPLAY_COLORS)
	if display_colors.size() < 3:
		display_colors = DEFAULT_DISPLAY_COLORS

	_draw_trail(canvas, shake_offset, intensity, intensity_trail, display_colors)
	_draw_particles(canvas, shake_offset, intensity, intensity_particles)
	_draw_current_ball_glow(canvas, shake_offset, intensity, context)


func _draw_trail(
	canvas: Node2D,
	shake_offset: Vector2,
	intensity: float,
	intensity_trail: Array,
	display_colors: Array
) -> void:
	if intensity_trail.is_empty():
		return
	var total_points: int = intensity_trail.size()
	for i in range(total_points):
		var point: Dictionary = intensity_trail[i]
		var alpha: float = float(point["alpha"])
		if alpha < 5.0 / 255.0:
			continue

		var position_ratio: float = float(i) / max(1.0, float(total_points - 1))
		var size: float = float(point["size"]) * (0.3 + position_ratio * 0.7)
		if size < 1.0:
			continue

		var color_index: int = min(2, int((1.0 - position_ratio) * 3.0))
		var base_color: Color = display_colors[color_index]
		var draw_alpha: float = alpha * (0.5 + intensity * 0.5)
		var draw_pos: Vector2 = point["pos"] + shake_offset
		if size > 3.0:
			canvas.draw_circle(draw_pos, size, Color(base_color.r, base_color.g, base_color.b, draw_alpha * 0.33))
		var inner_color: Color = _brighten_color(base_color, 50.0 / 255.0)
		canvas.draw_circle(draw_pos, max(1.0, size * 0.6), Color(inner_color.r, inner_color.g, inner_color.b, draw_alpha))


func _draw_particles(canvas: Node2D, shake_offset: Vector2, intensity: float, intensity_particles: Array) -> void:
	for particle in intensity_particles:
		var life: float = float(particle["life"])
		var max_life: float = float(particle["max_life"])
		var base_size: float = float(particle["size"])
		if life <= 0.0 or base_size < 0.5:
			continue

		var alpha: float = (life / max_life) * (0.5 + intensity * 0.5)
		if alpha < 5.0 / 255.0:
			continue

		var size: float = max(1.0, base_size)
		var draw_pos: Vector2 = particle["pos"] + shake_offset
		if str(particle["type"]) == "flame":
			var base_color: Color = particle["color"]
			var inner_color: Color = _brighten_color(base_color, 80.0 / 255.0)
			canvas.draw_circle(draw_pos, size, Color(base_color.r, base_color.g, base_color.b, alpha * 0.5))
			canvas.draw_circle(draw_pos, max(1.0, size * 0.5), Color(inner_color.r, inner_color.g, inner_color.b, alpha))
		else:
			canvas.draw_circle(draw_pos, size, Color(1.0, 1.0, 200.0 / 255.0, alpha))


func _draw_current_ball_glow(canvas: Node2D, shake_offset: Vector2, intensity: float, context: Dictionary) -> void:
	if intensity <= 0.2:
		return
	var ball_size: float = float(context.get("ball_size", 22.0))
	var ball_pos: Vector2 = context.get("ball_pos", Vector2.ZERO)
	var glow_color: Color = context.get("ball_current_glow_color", Color(60.0 / 255.0, 100.0 / 255.0, 180.0 / 255.0, 30.0 / 255.0))
	var glow_size: float = (ball_size * 0.5) * (1.0 + intensity * 0.3)
	var glow_alpha: float = glow_color.a * 0.5 * intensity
	if glow_alpha > 5.0 / 255.0:
		canvas.draw_circle(ball_pos + shake_offset, glow_size, Color(glow_color.r, glow_color.g, glow_color.b, glow_alpha))


func _brighten_color(color: Color, amount: float) -> Color:
	return Color(
		clamp(color.r + amount, 0.0, 1.0),
		clamp(color.g + amount, 0.0, 1.0),
		clamp(color.b + amount, 0.0, 1.0),
		color.a
	)
