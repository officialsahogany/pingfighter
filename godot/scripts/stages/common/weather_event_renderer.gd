extends RefCounted

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const WEATHER_RENDER_PARTICLE_LIMIT := 72
const WIND_RENDER_PARTICLE_LIMIT := 32
const FIRE_RENDER_PARTICLE_LIMIT := 48
const FIRE_DETAILED_EXPLOSION_RENDER_LIMIT := 8
const FIRE_DETAILED_SPARK_RENDER_LIMIT := 8
const FIRE_OVERLAY_HEAT_LINE_COUNT := 4

var _texture_cache: Dictionary = {}


func prewarm_assets() -> void:
	for texture_key in [
		"rain_streak",
		"wind_ribbon",
		"fire_ember",
		"hail_core",
		"ice_glint",
		"sand_grain",
		"message_scanline",
	]:
		_get_texture(str(texture_key))


func draw(weather: Object, canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if weather == null or canvas == null:
		return
	var context: Dictionary = _get_weather_context(weather)
	_draw_field_overlay(canvas, context, shake_offset)
	_draw_sand_segments(weather, canvas, shake_offset)
	_draw_particles(weather, canvas, shake_offset)
	_draw_weather_message(canvas, context)


func build_visual_snapshot(weather: Object) -> Dictionary:
	var context: Dictionary = _get_weather_context(weather)
	var particles: Array = _get_particles(weather)
	var render_limit: int = _get_render_particle_limit(context)
	return {
		"type": str(context.get("type", "")),
		"active": bool(context.get("active", false)),
		"particle_count": particles.size(),
		"rendered_particle_count": min(particles.size(), render_limit),
		"render_particle_limit": render_limit,
		"fire_render_particle_limit": FIRE_RENDER_PARTICLE_LIMIT,
		"fire_detailed_explosion_render_limit": FIRE_DETAILED_EXPLOSION_RENDER_LIMIT,
		"fire_detailed_spark_render_limit": FIRE_DETAILED_SPARK_RENDER_LIMIT,
		"sand_segment_count": _get_sand_segments(weather).size(),
		"has_message": str(context.get("warning_text", context.get("end_text", ""))) != "",
	}


func _draw_field_overlay(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var weather_type: String = str(context.get("type", ""))
	if weather_type == "":
		return
	var rect: Rect2 = Rect2(shake_offset, Vector2(FIELD_WIDTH, FIELD_HEIGHT))
	match weather_type:
		"fire":
			canvas.draw_rect(rect, Color(1.0, 0.19, 0.04, 0.055))
			for idx in range(FIRE_OVERLAY_HEAT_LINE_COUNT):
				var y: float = FIELD_HEIGHT - 108.0 + float(idx) * 24.0
				canvas.draw_line(
					Vector2(0.0, y) + shake_offset,
					Vector2(FIELD_WIDTH, y + sin(float(idx) * 0.9) * 6.0) + shake_offset,
					Color(1.0, 0.38, 0.04, 0.10),
					2.0
				)
		"ice":
			canvas.draw_rect(Rect2(Vector2(0.0, 0.0) + shake_offset, Vector2(FIELD_WIDTH, 54.0)), Color(0.45, 0.85, 1.0, 0.10))
			canvas.draw_rect(Rect2(Vector2(0.0, FIELD_HEIGHT - 54.0) + shake_offset, Vector2(FIELD_WIDTH, 54.0)), Color(0.45, 0.85, 1.0, 0.12))
			for idx in range(0, 10):
				var x: float = float(idx) * 83.0
				canvas.draw_line(Vector2(x, FIELD_HEIGHT - 46.0) + shake_offset, Vector2(x + 58.0, FIELD_HEIGHT - 12.0) + shake_offset, Color(0.75, 0.96, 1.0, 0.18), 1.0)
				canvas.draw_line(Vector2(x + 18.0, 11.0) + shake_offset, Vector2(x + 77.0, 42.0) + shake_offset, Color(0.75, 0.96, 1.0, 0.13), 1.0)
		"rain":
			canvas.draw_rect(rect, Color(0.08, 0.22, 0.38, 0.09))
		"hail":
			canvas.draw_rect(rect, Color(0.07, 0.11, 0.18, 0.16))
		"sand":
			canvas.draw_rect(rect, Color(0.48, 0.34, 0.11, 0.055))
		"breeze", "gust":
			var alpha: float = 0.045 if weather_type == "breeze" else 0.075
			canvas.draw_rect(rect, Color(0.55, 0.78, 1.0, alpha))


func _draw_sand_segments(weather: Object, canvas: CanvasItem, shake_offset: Vector2) -> void:
	for value in _get_sand_segments(weather):
		var segment: Dictionary = _get_dict(value)
		var rect: Rect2 = _get_rect2(segment.get("rect", Rect2()), Rect2())
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		rect.position += shake_offset
		var depth: float = float(segment.get("depth", max(rect.size.x, rect.size.y)))
		var alpha: float = clamp(0.33 + depth / 120.0, 0.36, 0.68)
		canvas.draw_texture_rect(_get_texture("sand_grain"), rect, true, Color(0.93, 0.76, 0.42, alpha))
		canvas.draw_rect(rect, Color(0.52, 0.36, 0.13, 0.18), false, 1.0)


func _draw_particles(weather: Object, canvas: CanvasItem, shake_offset: Vector2) -> void:
	var particles: Array = _get_particles(weather)
	var context: Dictionary = _get_weather_context(weather)
	var particle_start: int = max(0, particles.size() - _get_render_particle_limit(context))
	var fire_explosion_drawn := 0
	var fire_spark_drawn := 0
	for particle_index in range(particle_start, particles.size()):
		var value: Variant = particles[particle_index]
		var particle: Dictionary = _get_dict(value)
		var kind: String = str(particle.get("kind", "wind"))
		var pos: Vector2 = Vector2(float(particle.get("x", 0.0)), float(particle.get("y", 0.0))) + shake_offset
		var alpha: float = clamp(float(particle.get("life", 1.0)) / max(0.001, float(particle.get("max_life", 1.0))), 0.0, 1.0)
		var color: Color = _get_color(particle.get("color", Color.WHITE))
		color.a *= alpha
		match kind:
			"rain":
				_draw_texture_piece(canvas, "rain_streak", pos, Vector2(4.0, float(particle.get("length", 18.0))), color)
			"hail":
				var size: float = float(particle.get("size", 8.0))
				_draw_hail_particle(canvas, pos, size, alpha, color)
			"hail_impact":
				var s: float = float(particle.get("size", 4.0))
				_draw_hail_impact_particle(canvas, pos, s, alpha, color)
			"hail_burst":
				var burst_size: float = float(particle.get("size", 10.0))
				var burst_angle: float = float(particle.get("angle", 0.0))
				_draw_hail_burst_particle(canvas, pos, burst_size, burst_angle, alpha, color)
			"hail_shard":
				var shard_size: float = float(particle.get("size", 4.0))
				var shard_angle: float = float(particle.get("angle", 0.0))
				_draw_hail_shard_particle(canvas, pos, shard_size, shard_angle, alpha, color)
			"fire":
				var fire_size: float = float(particle.get("size", 4.0))
				_draw_texture_piece(canvas, "fire_ember", pos, Vector2(fire_size * 4.2, fire_size * 4.2), color)
			"fire_explosion":
				var explosion_size: float = float(particle.get("size", 5.0))
				fire_explosion_drawn += 1
				_draw_fire_explosion_particle(
					canvas,
					pos,
					explosion_size,
					alpha,
					color,
					fire_explosion_drawn <= FIRE_DETAILED_EXPLOSION_RENDER_LIMIT
				)
			"fire_spark":
				var spark_size: float = float(particle.get("size", 3.0))
				var spark_angle: float = float(particle.get("angle", 0.0))
				var spark_length: float = float(particle.get("length", 12.0))
				fire_spark_drawn += 1
				_draw_fire_spark_particle(
					canvas,
					pos,
					spark_size,
					spark_angle,
					spark_length,
					alpha,
					color,
					fire_spark_drawn <= FIRE_DETAILED_SPARK_RENDER_LIMIT
				)
			"ice":
				var ice_size: float = float(particle.get("size", 4.0))
				_draw_texture_piece(canvas, "ice_glint", pos, Vector2(ice_size * 3.0, ice_size * 3.0), color)
			"sand":
				var sand_size: float = max(2.0, float(particle.get("size", 3.0)) * 2.0)
				_draw_texture_piece(canvas, "sand_grain", pos, Vector2(sand_size, sand_size), color)
			_:
				var width: float = max(18.0, abs(float(particle.get("vx", 0.0))) * 8.0 + 14.0)
				_draw_texture_piece(canvas, "wind_ribbon", pos, Vector2(width, max(3.0, float(particle.get("size", 2.0)) * 2.0)), color)


func _draw_texture_piece(canvas: CanvasItem, texture_key: String, center: Vector2, size: Vector2, color: Color) -> void:
	var texture: Texture2D = _get_texture(texture_key)
	if texture == null:
		return
	var rect: Rect2 = Rect2(center - size * 0.5, size)
	canvas.draw_texture_rect(texture, rect, false, color)


func _draw_hail_particle(canvas: CanvasItem, center: Vector2, size: float, alpha: float, base_color: Color) -> void:
	var visible_alpha: float = clamp(alpha, 0.36, 1.0)
	var shadow_offset := Vector2(1.6, 2.0)
	canvas.draw_circle(center + shadow_offset, size + 3.2, Color(0.015, 0.035, 0.075, 0.48 * visible_alpha))
	canvas.draw_circle(center, size + 2.0, Color(0.10, 0.25, 0.42, 0.54 * visible_alpha))

	var body_color := Color(
		max(base_color.r, 0.80),
		max(base_color.g, 0.92),
		1.0,
		0.98 * visible_alpha
	)
	_draw_texture_piece(canvas, "hail_core", center, Vector2(size * 2.35, size * 2.35), body_color)

	canvas.draw_circle(
		center + Vector2(-size * 0.24, -size * 0.25),
		max(2.0, size * 0.35),
		Color(1.0, 1.0, 1.0, 0.78 * visible_alpha)
	)
	canvas.draw_line(
		center + Vector2(-size * 0.58, 0.0),
		center + Vector2(size * 0.50, 0.0),
		Color(1.0, 1.0, 1.0, 0.36 * visible_alpha),
		1.4
	)
	canvas.draw_line(
		center + Vector2(0.0, -size * 0.55),
		center + Vector2(0.0, size * 0.45),
		Color(0.76, 0.95, 1.0, 0.30 * visible_alpha),
		1.2
	)


func _draw_hail_impact_particle(canvas: CanvasItem, center: Vector2, size: float, alpha: float, base_color: Color) -> void:
	var visible_alpha: float = clamp(alpha, 0.30, 1.0)
	canvas.draw_circle(center, size * 1.65, Color(0.06, 0.16, 0.26, 0.36 * visible_alpha))
	_draw_texture_piece(
		canvas,
		"ice_glint",
		center,
		Vector2(size * 3.0, size * 3.0),
		Color(max(base_color.r, 0.78), max(base_color.g, 0.94), 1.0, 0.90 * visible_alpha)
	)
	canvas.draw_line(
		center + Vector2(-size * 1.9, 0.0),
		center + Vector2(size * 1.9, 0.0),
		Color(1.0, 1.0, 1.0, 0.46 * visible_alpha),
		1.2
	)


func _draw_hail_burst_particle(canvas: CanvasItem, center: Vector2, size: float, angle: float, alpha: float, base_color: Color) -> void:
	var visible_alpha: float = clamp(alpha, 0.0, 1.0)
	canvas.draw_circle(center, size * 1.28, Color(0.16, 0.38, 0.62, 0.20 * visible_alpha))
	canvas.draw_circle(center, size * 0.72, Color(max(base_color.r, 0.84), max(base_color.g, 0.97), 1.0, 0.36 * visible_alpha))
	_draw_texture_piece(
		canvas,
		"ice_glint",
		center,
		Vector2(size * 2.4, size * 2.4),
		Color(0.94, 1.0, 1.0, 0.58 * visible_alpha)
	)
	for line_idx in range(4):
		var line_angle: float = float(line_idx) * PI * 0.5 + angle
		var dir := Vector2(cos(line_angle), sin(line_angle))
		canvas.draw_line(
			center + dir * size * 0.30,
			center + dir * size * 1.55,
			Color(0.90, 0.99, 1.0, 0.54 * visible_alpha),
			1.4
		)


func _draw_hail_shard_particle(canvas: CanvasItem, center: Vector2, size: float, angle: float, alpha: float, base_color: Color) -> void:
	var visible_alpha: float = clamp(alpha, 0.0, 1.0)
	var dir := Vector2(cos(angle), sin(angle))
	var perp := Vector2(-dir.y, dir.x)
	canvas.draw_line(
		center - dir * size * 1.45 + Vector2(1.0, 1.2),
		center + dir * size * 1.90 + Vector2(1.0, 1.2),
		Color(0.08, 0.18, 0.30, 0.36 * visible_alpha),
		max(1.8, size * 0.46)
	)
	canvas.draw_line(
		center - dir * size * 1.35,
		center + dir * size * 1.75,
		Color(max(base_color.r, 0.78), max(base_color.g, 0.94), 1.0, 0.86 * visible_alpha),
		max(1.2, size * 0.30)
	)
	canvas.draw_line(
		center - dir * size * 0.65 + perp * size * 0.38,
		center + dir * size * 0.80,
		Color(1.0, 1.0, 1.0, 0.62 * visible_alpha),
		1.0
	)


func _draw_fire_explosion_particle(canvas: CanvasItem, center: Vector2, size: float, alpha: float, base_color: Color, detailed: bool = true) -> void:
	var visible_alpha: float = clamp(alpha, 0.0, 1.0)
	if not detailed:
		_draw_texture_piece(
			canvas,
			"fire_ember",
			center,
			Vector2(size * 3.8, size * 3.8),
			Color(max(base_color.r, 1.0), max(base_color.g, 0.32), max(base_color.b, 0.08), 0.72 * visible_alpha)
		)
		return
	canvas.draw_circle(center, size * 2.8, Color(0.78, 0.04, 0.01, 0.18 * visible_alpha))
	canvas.draw_circle(center, size * 1.75, Color(1.0, 0.18, 0.02, 0.30 * visible_alpha))
	_draw_texture_piece(
		canvas,
		"fire_ember",
		center,
		Vector2(size * 4.6, size * 4.6),
		Color(max(base_color.r, 1.0), max(base_color.g, 0.32), max(base_color.b, 0.08), 0.92 * visible_alpha)
	)
	canvas.draw_circle(
		center + Vector2(-size * 0.20, -size * 0.30),
		max(1.6, size * 0.48),
		Color(1.0, 0.88, 0.34, 0.78 * visible_alpha)
	)


func _draw_fire_spark_particle(
	canvas: CanvasItem,
	center: Vector2,
	size: float,
	angle: float,
	length: float,
	alpha: float,
	base_color: Color,
	detailed: bool = true
) -> void:
	var visible_alpha: float = clamp(alpha, 0.0, 1.0)
	var dir := Vector2(cos(angle), sin(angle))
	var start: Vector2 = center - dir * length * 0.35
	var end: Vector2 = center + dir * length * 0.65
	if not detailed:
		canvas.draw_line(
			start,
			end,
			Color(max(base_color.r, 1.0), max(base_color.g, 0.70), max(base_color.b, 0.16), 0.72 * visible_alpha),
			max(1.0, size * 0.26)
		)
		return
	canvas.draw_line(
		start + Vector2(1.0, 1.2),
		end + Vector2(1.0, 1.2),
		Color(0.20, 0.02, 0.0, 0.30 * visible_alpha),
		max(1.6, size * 0.42)
	)
	canvas.draw_line(
		start,
		end,
		Color(max(base_color.r, 1.0), max(base_color.g, 0.70), max(base_color.b, 0.16), 0.88 * visible_alpha),
		max(1.0, size * 0.30)
	)
	canvas.draw_circle(end, max(1.0, size * 0.45), Color(1.0, 0.94, 0.52, 0.68 * visible_alpha))


func _draw_weather_message(canvas: CanvasItem, context: Dictionary) -> void:
	var text: String = str(context.get("warning_text", ""))
	var timer: float = float(context.get("warning_timer_frames", 0.0))
	var weather_type: String = str(context.get("type", ""))
	var color: Color = _get_weather_color(weather_type)
	if timer <= 0.0 and float(context.get("end_timer_frames", 0.0)) > 0.0:
		text = str(context.get("end_text", ""))
		timer = float(context.get("end_timer_frames", 0.0))
		color = Color(0.55, 1.0, 0.62, 1.0)
	if timer <= 0.0 or text == "":
		return
	var alpha: float = 1.0
	if timer > 150.0:
		alpha = clamp((180.0 - timer) / 30.0, 0.0, 1.0)
	elif timer < 30.0:
		alpha = clamp(timer / 30.0, 0.0, 1.0)
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 22
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline: Vector2 = Vector2(FIELD_WIDTH * 0.5 - text_size.x * 0.5, FIELD_HEIGHT * 0.33)
	var panel: Rect2 = Rect2(baseline - Vector2(24.0, 28.0), Vector2(text_size.x + 48.0, text_size.y + 26.0))
	canvas.draw_rect(panel, Color(0.0, 0.0, 0.03, 0.58 * alpha))
	canvas.draw_texture_rect(_get_texture("message_scanline"), panel, true, Color(color.r, color.g, color.b, 0.14 * alpha))
	canvas.draw_rect(panel, Color(color.r, color.g, color.b, 0.72 * alpha), false, 2.0)
	canvas.draw_string(font, baseline + Vector2(1.5, 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, 0.72 * alpha))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(color.r, color.g, color.b, alpha))


func _get_texture(key: String) -> Texture2D:
	if _texture_cache.has(key):
		return _texture_cache[key]
	var texture: Texture2D = _build_texture(key)
	_texture_cache[key] = texture
	return texture


func _build_texture(key: String) -> Texture2D:
	match key:
		"rain_streak":
			return _make_soft_streak_texture(8, 36, Color(0.55, 0.80, 1.0, 0.0), Color(0.80, 0.95, 1.0, 1.0), true)
		"wind_ribbon":
			return _make_soft_streak_texture(48, 8, Color(0.62, 0.88, 1.0, 0.0), Color(0.78, 0.96, 1.0, 1.0), false)
		"fire_ember":
			return _make_radial_texture(32, Color(1.0, 0.15, 0.02, 0.0), Color(1.0, 0.85, 0.25, 1.0))
		"hail_core":
			return _make_hail_core_texture(32)
		"ice_glint":
			return _make_glint_texture(32)
		"sand_grain":
			return _make_noise_texture(24, Color(0.47, 0.31, 0.11, 1.0), Color(0.97, 0.78, 0.42, 1.0))
		"message_scanline":
			return _make_scanline_texture(16, 8)
	return _make_radial_texture(16, Color(1.0, 1.0, 1.0, 0.0), Color.WHITE)


func _make_soft_streak_texture(width: int, height: int, edge: Color, core: Color, vertical: bool) -> Texture2D:
	var image: Image = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	image.fill(edge)
	for y in range(height):
		for x in range(width):
			var axis: float = float(y) / max(1.0, float(height - 1)) if vertical else float(x) / max(1.0, float(width - 1))
			var cross: float = abs((float(x) / max(1.0, float(width - 1)) if vertical else float(y) / max(1.0, float(height - 1))) - 0.5) * 2.0
			var alpha: float = clamp((1.0 - cross) * sin(axis * PI), 0.0, 1.0)
			var pixel: Color = core
			pixel.a *= alpha
			image.set_pixel(x, y, pixel)
	return ImageTexture.create_from_image(image)


func _make_radial_texture(size: int, edge: Color, core: Color) -> Texture2D:
	var image: Image = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	image.fill(edge)
	var center: Vector2 = Vector2(float(size - 1) * 0.5, float(size - 1) * 0.5)
	var radius: float = max(1.0, float(size) * 0.5)
	for y in range(size):
		for x in range(size):
			var dist: float = Vector2(float(x), float(y)).distance_to(center) / radius
			var alpha: float = clamp(1.0 - dist, 0.0, 1.0)
			var pixel: Color = core
			pixel.a *= alpha * alpha
			image.set_pixel(x, y, pixel)
	return ImageTexture.create_from_image(image)


func _make_hail_core_texture(size: int) -> Texture2D:
	var image: Image = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var center: Vector2 = Vector2(float(size - 1) * 0.5, float(size - 1) * 0.5)
	var radius: float = max(1.0, float(size) * 0.5)
	for y in range(size):
		for x in range(size):
			var dist: float = Vector2(float(x), float(y)).distance_to(center) / radius
			if dist > 1.0:
				continue
			var radial: float = clamp(1.0 - dist, 0.0, 1.0)
			var rim: float = clamp((dist - 0.58) / 0.42, 0.0, 1.0)
			var pixel: Color = Color(0.58, 0.77, 0.92, 1.0).lerp(Color(0.95, 1.0, 1.0, 1.0), radial)
			pixel = pixel.lerp(Color(0.32, 0.52, 0.74, 1.0), rim * 0.42)
			pixel.a = clamp(0.46 + radial * 0.54, 0.0, 1.0)
			image.set_pixel(x, y, pixel)
	return ImageTexture.create_from_image(image)


func _make_glint_texture(size: int) -> Texture2D:
	var image: Image = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var center: float = float(size - 1) * 0.5
	for y in range(size):
		for x in range(size):
			var dx: float = abs(float(x) - center)
			var dy: float = abs(float(y) - center)
			var line_alpha: float = max(0.0, 1.0 - min(dx, dy) / 2.5)
			var radial: float = max(0.0, 1.0 - Vector2(dx, dy).length() / center)
			var alpha: float = clamp(max(line_alpha * radial, radial * 0.28), 0.0, 1.0)
			image.set_pixel(x, y, Color(0.84, 0.98, 1.0, alpha))
	return ImageTexture.create_from_image(image)


func _make_noise_texture(size: int, dark: Color, light: Color) -> Texture2D:
	var image: Image = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var checker: float = 0.35 if (x + y) % 3 == 0 else 0.0
			var t: float = clamp(0.35 + randf_range(-0.18, 0.28) + checker, 0.0, 1.0)
			var pixel: Color = dark.lerp(light, t)
			pixel.a = 0.82
			image.set_pixel(x, y, pixel)
	return ImageTexture.create_from_image(image)


func _make_scanline_texture(width: int, height: int) -> Texture2D:
	var image: Image = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0, 0.0))
	for y in range(0, height, 2):
		for x in range(width):
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, 0.6))
	return ImageTexture.create_from_image(image)


func _get_weather_context(weather: Object) -> Dictionary:
	if weather != null and weather.has_method("get_weather_context"):
		var context: Variant = weather.get_weather_context()
		if context is Dictionary:
			return context
	return {}


func _get_particles(weather: Object) -> Array:
	if weather != null and weather.has_method("get_render_particles"):
		var render_particles: Variant = weather.get_render_particles()
		if render_particles is Array:
			return render_particles
	if weather != null and weather.has_method("harvest_particles"):
		var particles: Variant = weather.harvest_particles()
		if particles is Array:
			return particles
	return []


func _get_render_particle_limit(context: Dictionary) -> int:
	var weather_type: String = str(context.get("type", ""))
	if weather_type == "fire":
		return FIRE_RENDER_PARTICLE_LIMIT
	if weather_type == "breeze" or weather_type == "gust":
		return WIND_RENDER_PARTICLE_LIMIT
	return WEATHER_RENDER_PARTICLE_LIMIT


func _get_sand_segments(weather: Object) -> Array:
	if weather != null and weather.has_method("get_sand_visual_segments"):
		var segments: Variant = weather.get_sand_visual_segments()
		if segments is Array:
			return segments
	return []


func _get_weather_color(weather_type: String) -> Color:
	match weather_type:
		"breeze":
			return Color(180.0 / 255.0, 230.0 / 255.0, 1.0, 1.0)
		"gust":
			return Color(1.0, 205.0 / 255.0, 110.0 / 255.0, 1.0)
		"fire":
			return Color(1.0, 95.0 / 255.0, 35.0 / 255.0, 1.0)
		"ice":
			return Color(145.0 / 255.0, 225.0 / 255.0, 1.0, 1.0)
		"rain":
			return Color(95.0 / 255.0, 180.0 / 255.0, 1.0, 1.0)
		"hail":
			return Color(215.0 / 255.0, 240.0 / 255.0, 1.0, 1.0)
		"sand":
			return Color(224.0 / 255.0, 190.0 / 255.0, 120.0 / 255.0, 1.0)
	return Color.WHITE


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_color(value: Variant) -> Color:
	if value is Color:
		return value
	return Color.WHITE


func _get_rect2(value: Variant, fallback: Rect2) -> Rect2:
	if value is Rect2:
		return value
	return fallback
