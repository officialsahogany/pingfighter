extends RefCounted


func build_activation_particles(particle_count: int) -> Array:
	var particles: Array = []
	for _i in range(particle_count):
		var angle: float = randf_range(0.0, TAU)
		var speed: float = randf_range(85.0, 300.0)
		particles.append({
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"life": randf_range(1.05, 1.85),
			"delay": randf_range(0.0, 0.24),
			"size": randf_range(1.8, 4.2),
			"color": [
				Color(1.0, 215.0 / 255.0, 0.0),
				Color(100.0 / 255.0, 180.0 / 255.0, 1.0),
				Color.WHITE,
			][randi() % 3],
		})
	return particles


func build_activation_bolts(bolt_count: int) -> Array:
	var bolts: Array = []
	for _i in range(bolt_count):
		var angle: float = randf_range(0.0, TAU)
		var length: float = randf_range(66.0, 190.0)
		var end_point := Vector2(cos(angle), sin(angle)) * length
		bolts.append({
			"birth": randf_range(0.0, 1.12),
			"life": randf_range(0.11, 0.28),
			"points": make_bolt_points(Vector2.ZERO, end_point, randi_range(5, 8), 22.0),
		})
	return bolts


func make_bolt_points(start: Vector2, end: Vector2, segments: int, jitter: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.append(start)
	for i in range(1, max(2, segments)):
		var f: float = float(i) / float(segments)
		var base: Vector2 = start.lerp(end, f)
		var normal: Vector2 = (end - start).orthogonal().normalized() if (end - start).length() > 0.01 else Vector2.RIGHT
		points.append(base + normal * randf_range(-jitter, jitter) + Vector2(randf_range(-jitter * 0.25, jitter * 0.25), randf_range(-jitter * 0.25, jitter * 0.25)))
	points.append(end)
	return points


func draw_activation_effect(
	canvas: CanvasItem,
	view_size: Vector2,
	elapsed: float,
	particles: Array,
	bolts: Array,
	duration: float
) -> void:
	if canvas == null:
		return
	var t: float = clamp(elapsed / duration, 0.0, 1.0)
	var center := Vector2(view_size.x * 0.5, view_size.y * 0.5 - 40.0)

	if t < 0.10:
		var flash_alpha: float = 0.62 * (1.0 - t / 0.10)
		canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(1.0, 1.0, 0.86, flash_alpha))

	draw_activation_rings(canvas, center, t)
	draw_activation_bolts(canvas, center, elapsed, bolts)
	draw_activation_particles(canvas, center, elapsed, particles)
	draw_activation_emblem(canvas, center, elapsed, t)
	draw_activation_text(canvas, center, t)


func draw_activation_rings(canvas: CanvasItem, center: Vector2, t: float) -> void:
	if t >= 0.78:
		return
	var progress: float = clamp(t / 0.78, 0.0, 1.0)
	var ring_radius: float = 20.0 + 210.0 * progress
	var ring_alpha: float = 0.78 * (1.0 - progress)
	canvas.draw_arc(center, ring_radius, 0.0, TAU, 96, Color(1.0, 215.0 / 255.0, 0.0, ring_alpha), max(1.0, 4.0 * (1.0 - progress)))
	if progress > 0.15:
		var second_progress: float = clamp((progress - 0.15) / 0.85, 0.0, 1.0)
		canvas.draw_arc(center, 18.0 + 160.0 * second_progress, 0.0, TAU, 88, Color(100.0 / 255.0, 180.0 / 255.0, 1.0, 0.56 * (1.0 - second_progress)), max(1.0, 3.0 * (1.0 - second_progress)))


func draw_activation_bolts(canvas: CanvasItem, center: Vector2, elapsed: float, bolts: Array) -> void:
	for bolt_value in bolts:
		var bolt: Dictionary = _get_dict(bolt_value)
		var age: float = elapsed - float(bolt.get("birth", 0.0))
		var life: float = max(0.01, float(bolt.get("life", 0.1)))
		if age < 0.0 or age > life:
			continue
		var alpha: float = clamp(1.0 - age / life, 0.0, 1.0)
		var local_points: PackedVector2Array = bolt.get("points", PackedVector2Array())
		if local_points.size() < 2:
			continue
		var points := PackedVector2Array()
		for local_point in local_points:
			points.append(center + local_point)
		canvas.draw_polyline(points, Color(70.0 / 255.0, 150.0 / 255.0, 1.0, 0.30 * alpha), 8.0)
		canvas.draw_polyline(points, Color(220.0 / 255.0, 240.0 / 255.0, 1.0, 0.94 * alpha), 3.0)
		canvas.draw_polyline(points, Color.WHITE, 1.0)


func draw_activation_particles(canvas: CanvasItem, center: Vector2, elapsed: float, particles: Array) -> void:
	for particle_value in particles:
		var particle: Dictionary = _get_dict(particle_value)
		var age: float = elapsed - float(particle.get("delay", 0.0))
		var life: float = max(0.01, float(particle.get("life", 0.8)))
		if age < 0.0 or age > life:
			continue
		var ratio: float = clamp(age / life, 0.0, 1.0)
		var alpha: float = 1.0 - ratio
		var velocity: Vector2 = _get_vector2(particle.get("velocity", Vector2.ZERO))
		var pos: Vector2 = center + velocity * age + Vector2(0.0, 70.0 * age * age)
		var color: Color = _get_color(particle.get("color", Color.WHITE))
		var size: float = max(1.0, float(particle.get("size", 2.0)) * (1.0 - ratio * 0.55))
		canvas.draw_circle(pos, size + 2.0, Color(color.r, color.g, color.b, 0.16 * alpha))
		canvas.draw_circle(pos, size, Color(color.r, color.g, color.b, 0.86 * alpha))


func draw_activation_emblem(canvas: CanvasItem, center: Vector2, elapsed: float, t: float) -> void:
	if t < 0.08 or t > 0.88:
		return
	var fade_in: float = clamp((t - 0.08) / 0.16, 0.0, 1.0)
	var fade_out: float = clamp((0.88 - t) / 0.18, 0.0, 1.0)
	var alpha: float = min(fade_in, fade_out)
	if alpha <= 0.0:
		return
	var scale: float = 0.74 + 0.26 * fade_in
	if t > 0.70:
		scale += (t - 0.70) / 0.18 * 0.12
	var radius: float = 54.0 * scale
	var rotation: float = elapsed * 1.75
	var pulse: float = 0.5 + 0.5 * sin(elapsed * 7.5)

	canvas.draw_circle(center, radius * 0.82, Color(1.0, 220.0 / 255.0, 80.0 / 255.0, 0.10 * alpha))
	canvas.draw_arc(center, radius, 0.0, TAU, 64, Color(1.0, 215.0 / 255.0, 0.0, 0.82 * alpha), 2.5)
	canvas.draw_arc(center, radius * 0.66, 0.0, TAU, 56, Color(100.0 / 255.0, 180.0 / 255.0, 1.0, (0.35 + 0.20 * pulse) * alpha), 2.0)

	for i in range(12):
		var rune_angle: float = rotation + float(i) * TAU / 12.0
		var rune_center: Vector2 = center + Vector2(cos(rune_angle), sin(rune_angle)) * radius
		var rune_size: float = 4.0 * scale
		var rune_points := PackedVector2Array([
			rune_center + Vector2(0.0, -rune_size),
			rune_center + Vector2(rune_size, 0.0),
			rune_center + Vector2(0.0, rune_size),
			rune_center + Vector2(-rune_size, 0.0),
		])
		var rune_color := Color(1.0, 225.0 / 255.0, 92.0 / 255.0, alpha) if i % 2 == 0 else Color(120.0 / 255.0, 190.0 / 255.0, 1.0, alpha)
		canvas.draw_colored_polygon(rune_points, rune_color)

	var bolt_height: float = radius * 1.10
	var bolt_width: float = radius * 0.34
	var bolt := PackedVector2Array([
		center + Vector2(-bolt_width * 0.22, -bolt_height * 0.50),
		center + Vector2(bolt_width * 0.44, -bolt_height * 0.14),
		center + Vector2(-bolt_width * 0.12, -bolt_height * 0.04),
		center + Vector2(bolt_width * 0.28, bolt_height * 0.18),
		center + Vector2(-bolt_width * 0.28, bolt_height * 0.10),
		center + Vector2(bolt_width * 0.06, bolt_height * 0.50),
	])
	canvas.draw_polyline(bolt, Color(80.0 / 255.0, 165.0 / 255.0, 1.0, 0.48 * alpha), 7.0 * scale, false)
	canvas.draw_polyline(bolt, Color.WHITE, 2.2 * scale, false)


func draw_activation_text(canvas: CanvasItem, center: Vector2, t: float) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var fade_in: float = clamp((t - 0.12) / 0.16, 0.0, 1.0)
	var fade_out: float = clamp((1.0 - t) / 0.28, 0.0, 1.0)
	var alpha: float = min(fade_in, fade_out)
	if alpha <= 0.0:
		return
	var text := "메긴교르드의 효과 발동!"
	var font_size := 27
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var box_rect := Rect2(center + Vector2(-text_size.x * 0.5 - 20.0, 68.0), Vector2(text_size.x + 40.0, 42.0))
	canvas.draw_rect(box_rect, Color(20.0 / 255.0, 15.0 / 255.0, 5.0 / 255.0, 0.54 * alpha))
	canvas.draw_rect(box_rect, Color(1.0, 200.0 / 255.0, 40.0 / 255.0, 0.72 * alpha), false, 2.0)
	var pos: Vector2 = center + Vector2(-text_size.x * 0.5, 98.0)
	for glow in range(4, 0, -1):
		canvas.draw_string(font, pos + Vector2(float(glow), float(glow)) * 0.55, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(1.0, 215.0 / 255.0, 0.0, alpha * 0.11 * float(glow)))
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(1.0, 240.0 / 255.0, 150.0 / 255.0, alpha))


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO


func _get_color(value: Variant) -> Color:
	if value is Color:
		return value
	return Color.WHITE
