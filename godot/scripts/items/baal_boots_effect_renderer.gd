extends RefCounted


func draw(
	canvas: CanvasItem,
	shake_offset: Vector2,
	weather_state: Object,
	effect_state: Object,
	field_size: Vector2,
	weather_color: Color
) -> void:
	if canvas == null or weather_state == null or effect_state == null:
		return
	var center: Vector2 = weather_state.absorb_center + shake_offset
	if bool(weather_state.cinematic_active) and float(weather_state.cinematic_total_frames) > 0.0:
		var progress: float = 1.0 - clamp(float(weather_state.cinematic_timer_frames) / float(weather_state.cinematic_total_frames), 0.0, 1.0)
		var pulse: float = 0.5 + 0.5 * sin(progress * TAU * 5.0)
		canvas.draw_rect(Rect2(Vector2.ZERO, field_size), Color(0.05, 0.0, 0.0, 0.16))
		for ring_index in range(4):
			var ring_progress: float = fmod(progress + float(ring_index) * 0.18, 1.0)
			var radius: float = 34.0 + ring_progress * 145.0
			var alpha: float = 0.48 * (1.0 - ring_progress)
			canvas.draw_arc(center, radius, 0.0, TAU, 88, Color(weather_color.r, weather_color.g, weather_color.b, alpha), max(1.0, 5.0 * (1.0 - ring_progress)), true)
		canvas.draw_circle(center, 22.0 + pulse * 7.0, Color(weather_color.r, weather_color.g, weather_color.b, 0.20 + pulse * 0.18))
		_draw_absorb_text(canvas, center, progress, weather_color)
	elif bool(weather_state.round_effect_active):
		var phase: float = float(Time.get_ticks_msec()) / 1000.0
		var radius: float = 36.0 + sin(phase * 4.2) * 4.0
		canvas.draw_arc(center, radius, 0.0, TAU, 64, Color(weather_color.r, weather_color.g, weather_color.b, 0.46), 2.0, true)
		canvas.draw_arc(center, radius + 10.0, phase, phase + PI * 1.35, 36, Color(1.0, 0.92, 0.70, 0.34), 2.0, true)

	for particle_value in effect_state.absorb_particles:
		var particle: Dictionary = _as_dict(particle_value)
		var pos: Vector2 = _as_vector2(particle.get("position", center), center) + shake_offset
		var life: float = float(particle.get("life", 0.0))
		var max_life: float = max(1.0, float(particle.get("max_life", 1.0)))
		var alpha: float = clamp(life / max_life, 0.0, 1.0)
		var size: float = max(1.0, float(particle.get("size", 3.0))) * (0.7 + 0.3 * alpha)
		var color: Color = _as_color(particle.get("color", weather_color), weather_color)
		canvas.draw_line(pos, center, Color(color.r, color.g, color.b, 0.14 * alpha), max(1.0, size * 0.45), true)
		canvas.draw_circle(pos, size + 3.0, Color(color.r, color.g, color.b, 0.14 * alpha))
		canvas.draw_circle(pos, size, Color(color.r, color.g, color.b, 0.82 * alpha))

	for aura_value in effect_state.aura_particles:
		var aura: Dictionary = _as_dict(aura_value)
		var life: float = float(aura.get("life", 0.0))
		var max_life: float = max(1.0, float(aura.get("max_life", 1.0)))
		var alpha: float = clamp(life / max_life, 0.0, 1.0)
		var pos: Vector2 = _as_vector2(aura.get("position", center), center) + shake_offset
		var size: float = max(1.0, float(aura.get("size", 2.0)))
		var color: Color = _as_color(aura.get("color", weather_color), weather_color)
		canvas.draw_circle(pos, size + 2.0, Color(color.r, color.g, color.b, 0.15 * alpha))
		canvas.draw_circle(pos, size, Color(color.r, color.g, color.b, 0.72 * alpha))

	for projectile_value in effect_state.projectiles:
		var projectile: Dictionary = _as_dict(projectile_value)
		var pos: Vector2 = _as_vector2(projectile.get("position", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var vel: Vector2 = _as_vector2(projectile.get("velocity", Vector2.ZERO), Vector2.ZERO)
		var color: Color = _as_color(projectile.get("color", weather_color), weather_color)
		var size: float = max(2.0, float(projectile.get("size", 5.0)))
		var tail: Vector2 = pos - vel.normalized() * size * 3.2 if vel.length() > 0.01 else pos
		canvas.draw_line(tail, pos, Color(color.r, color.g, color.b, 0.42), size * 0.75, true)
		canvas.draw_circle(pos, size + 3.0, Color(color.r, color.g, color.b, 0.18))
		canvas.draw_circle(pos, size, Color(color.r, color.g, color.b, 0.86))


func _draw_absorb_text(canvas: CanvasItem, center: Vector2, progress: float, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var alpha: float = clamp(min(progress / 0.18, (1.0 - progress) / 0.18), 0.0, 1.0)
	if alpha <= 0.0:
		return
	var text := "바알의 부츠"
	var font_size := 25
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var pos := center + Vector2(-text_size.x * 0.5, -82.0)
	canvas.draw_string(font, pos + Vector2(2.0, 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, 0.76 * alpha))
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(color.r, color.g, color.b, alpha))


func _as_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _as_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback
