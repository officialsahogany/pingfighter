extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")

const DYNAMITE_ICON_PATH := ActiveItemCatalog.DYNAMITE_ICON_PATH
const DYNAMITE_DRAW_SIZE := 46.0
const DYNAMITE_PLACED_DRAW_SIZE := 48.0
const DYNAMITE_COUNTDOWN_FRAMES := 420.0
const DYNAMITE_EXPLOSION_RADIUS := 350.0
const DYNAMITE_PARTICLE_ALPHA_CUTOFF := 0.025

var dynamite_icon_texture: Texture2D


func prewarm_assets() -> void:
	_touch_texture(get_dynamite_icon_texture())


func draw_dynamites(canvas: CanvasItem, dynamites: Array, shake_offset: Vector2) -> void:
	if dynamites.is_empty():
		return
	var texture: Texture2D = get_dynamite_icon_texture()
	for dynamite_value in dynamites:
		if not (dynamite_value is Dictionary):
			continue
		var dynamite: Dictionary = dynamite_value
		_draw_projectile_trail(canvas, dynamite.get("trail", []), shake_offset, 3.0, Color(1.0, 120.0 / 255.0, 80.0 / 255.0, 1.0), 0.24)

		var center: Vector2 = _get_vector2(dynamite, "position", Vector2.ZERO) + shake_offset
		var angle: float = float(dynamite.get("rotation_degrees", 0.0))
		if texture != null:
			_draw_rotated_texture_region(
				canvas,
				texture,
				Rect2(Vector2.ZERO, texture.get_size()),
				center,
				Vector2(DYNAMITE_DRAW_SIZE, DYNAMITE_DRAW_SIZE),
				angle
			)
		else:
			draw_dynamite_fallback(canvas, center, angle, 1.0, false, 0.0)


func draw_placed_dynamites(canvas: CanvasItem, placed_dynamites: Array, shake_offset: Vector2) -> void:
	if placed_dynamites.is_empty():
		return
	var texture: Texture2D = get_dynamite_icon_texture()
	var font: Font = ThemeDB.fallback_font
	for placed_value in placed_dynamites:
		if not (placed_value is Dictionary):
			continue
		var placed: Dictionary = placed_value
		var center: Vector2 = _get_vector2(placed, "position", Vector2.ZERO) + shake_offset
		var countdown: float = float(placed.get("countdown_frames", DYNAMITE_COUNTDOWN_FRAMES))
		var pulse_timer: float = float(placed.get("pulse_timer", 0.0))
		var wobble: float = float(placed.get("wobble_angle", 0.0))
		if countdown < 180.0:
			var blink_speed: float = 0.2 if countdown < 60.0 else 0.1
			if int(pulse_timer * blink_speed) % 2 == 0:
				var warning_radius: float = 20.0 + 5.0 * sin(pulse_timer * 0.3)
				canvas.draw_circle(center, warning_radius, Color(1.0, 50.0 / 255.0, 50.0 / 255.0, 150.0 / 255.0), false, 3.0)

		if texture != null:
			_draw_rotated_texture_region(
				canvas,
				texture,
				Rect2(Vector2.ZERO, texture.get_size()),
				center,
				Vector2(DYNAMITE_PLACED_DRAW_SIZE, DYNAMITE_PLACED_DRAW_SIZE),
				wobble
			)
			_draw_dynamite_flame(canvas, center, wobble, DYNAMITE_PLACED_DRAW_SIZE / DYNAMITE_DRAW_SIZE, countdown)
		else:
			draw_dynamite_fallback(canvas, center, wobble, DYNAMITE_PLACED_DRAW_SIZE / DYNAMITE_DRAW_SIZE, true, countdown)

		if font != null:
			var count_text: String = str(int(floor(countdown / 60.0)) + 1)
			var font_size: int = 24
			var text_size: Vector2 = font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
			var text_pos := center + Vector2(-text_size.x * 0.5, -30.0 + text_size.y * 0.35)
			var bg_rect := Rect2(text_pos - Vector2(5.0, text_size.y - 2.0), text_size + Vector2(10.0, 6.0))
			canvas.draw_rect(bg_rect, Color(50.0 / 255.0, 50.0 / 255.0, 50.0 / 255.0, 200.0 / 255.0))
			canvas.draw_rect(bg_rect, Color(1.0, 100.0 / 255.0, 100.0 / 255.0, 1.0), false, 2.0)
			canvas.draw_string(font, text_pos, count_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color.WHITE)


func draw_dynamite_explosions(canvas: CanvasItem, dynamite_explosions: Array, shake_offset: Vector2) -> void:
	if dynamite_explosions.is_empty():
		return
	for explosion_value in dynamite_explosions:
		if not (explosion_value is Dictionary):
			continue
		var explosion: Dictionary = explosion_value
		var center: Vector2 = _get_vector2(explosion, "position", Vector2.ZERO) + shake_offset
		var progress: float = clamp(float(explosion.get("progress", 0.0)), 0.0, 1.0)
		var shockwave_radius: float = float(explosion.get("shockwave_radius", 0.0))
		if shockwave_radius > 5.0 and progress < 0.6:
			var shock_life: float = max(0.0, 1.0 - progress / 0.6)
			var width: float = max(2.0, 20.0 * (1.0 - progress))
			_draw_safe_circle_outline(canvas, center, shockwave_radius + 6.0, Color(1.0, 100.0 / 255.0, 30.0 / 255.0, 70.0 / 255.0 * shock_life), width + 5.0)
			_draw_safe_circle_outline(canvas, center, shockwave_radius - 18.0, Color(1.0, 220.0 / 255.0, 110.0 / 255.0, 150.0 / 255.0 * shock_life), max(2.0, width - 4.0))

		for wave_value in explosion.get("secondary_waves", []):
			if not (wave_value is Dictionary):
				continue
			var wave: Dictionary = wave_value
			var radius: float = float(wave.get("radius", 0.0))
			if radius > 0.0 and radius < DYNAMITE_EXPLOSION_RADIUS:
				var alpha: float = (150.0 / 255.0) * (1.0 - radius / DYNAMITE_EXPLOSION_RADIUS)
				_draw_safe_circle_outline(canvas, center, radius, Color(1.0, 180.0 / 255.0, 80.0 / 255.0, alpha), max(1.0, 8.0 - radius / 40.0))

		if progress < 0.25:
			var flash_progress: float = progress / 0.25
			var flash_radius: float = 150.0 * (1.0 - flash_progress * 0.7)
			var flash_alpha: float = 1.0 - flash_progress
			canvas.draw_circle(center, flash_radius, Color(1.0, 150.0 / 255.0, 50.0 / 255.0, 0.5 * flash_alpha))
			canvas.draw_circle(center, flash_radius * 0.35, Color(1.0, 1.0, 240.0 / 255.0, min(1.0, flash_alpha + 0.12)))

		_draw_dynamite_smoke_clouds(canvas, explosion.get("smoke_clouds", []), shake_offset)
		_draw_dynamite_sparks(canvas, explosion.get("sparks", []), shake_offset)
		_draw_dynamite_fire_particles(canvas, explosion.get("particles", []), shake_offset)


func draw_dynamite_fallback(
	canvas: CanvasItem,
	center: Vector2,
	angle_degrees: float,
	scale: float,
	fuse_lit: bool,
	countdown: float
) -> void:
	var angle: float = deg_to_rad(angle_degrees)
	var stick_offsets := [-9.0, 0.0, 9.0]
	var stick_lengths := [22.0, 26.0, 22.0]
	var stick_widths := [8.0, 10.0, 8.0]
	for i in range(stick_offsets.size()):
		var x_offset: float = float(stick_offsets[i]) * scale
		var half_len: float = float(stick_lengths[i]) * 0.5 * scale
		var width: float = float(stick_widths[i]) * scale
		var top: Vector2 = _rotated_local(center, Vector2(x_offset, -half_len), angle)
		var bottom: Vector2 = _rotated_local(center, Vector2(x_offset, half_len), angle)
		canvas.draw_line(top, bottom, Color(150.0 / 255.0, 30.0 / 255.0, 30.0 / 255.0, 1.0), width + 2.0)
		canvas.draw_circle(top, width * 0.5 + 1.0, Color(150.0 / 255.0, 30.0 / 255.0, 30.0 / 255.0, 1.0))
		canvas.draw_circle(bottom, width * 0.5 + 1.0, Color(150.0 / 255.0, 30.0 / 255.0, 30.0 / 255.0, 1.0))
		canvas.draw_line(top, bottom, Color(200.0 / 255.0, 50.0 / 255.0, 50.0 / 255.0, 1.0), width)
		var highlight_top: Vector2 = _rotated_local(center, Vector2(x_offset - width * 0.18, -half_len + 1.0 * scale), angle)
		var highlight_bottom: Vector2 = _rotated_local(center, Vector2(x_offset - width * 0.18, half_len - 1.0 * scale), angle)
		canvas.draw_line(highlight_top, highlight_bottom, Color(240.0 / 255.0, 80.0 / 255.0, 80.0 / 255.0, 0.75), max(1.0, width * 0.34))

	for y_offset in [-6.0, 6.0]:
		var left: Vector2 = _rotated_local(center, Vector2(-13.0 * scale, y_offset * scale), angle)
		var right: Vector2 = _rotated_local(center, Vector2(13.0 * scale, y_offset * scale), angle)
		canvas.draw_line(left, right, Color(139.0 / 255.0, 90.0 / 255.0, 43.0 / 255.0, 1.0), max(2.0, 4.0 * scale))

	var fuse_start: Vector2 = _rotated_local(center, Vector2(0.0, -14.0 * scale), angle)
	var fuse_end: Vector2 = _rotated_local(center, Vector2(0.0, -22.0 * scale), angle)
	canvas.draw_line(fuse_start, fuse_end, Color(60.0 / 255.0, 60.0 / 255.0, 60.0 / 255.0, 1.0), max(1.0, 2.0 * scale))
	if fuse_lit:
		_draw_dynamite_flame(canvas, center, angle_degrees, scale, countdown)


func get_dynamite_icon_texture() -> Texture2D:
	if dynamite_icon_texture == null:
		dynamite_icon_texture = ProjectResourceLoader.load_texture(
			DYNAMITE_ICON_PATH,
			"Missing dynamite icon at %s",
			"Failed to load dynamite icon at %s"
		)
	return dynamite_icon_texture


func _draw_projectile_trail(canvas: CanvasItem, trail: Array, shake_offset: Vector2, radius: float, color: Color, alpha_scale: float) -> void:
	var trail_count: int = trail.size()
	if trail_count <= 0:
		return
	var stride: int = 2 if trail_count > 5 else 1
	for i in range(0, trail_count, stride):
		var point_value: Variant = trail[i]
		if not (point_value is Vector2):
			continue
		var alpha: float = alpha_scale * float(i + 1) / float(trail_count)
		canvas.draw_circle(point_value + shake_offset, radius, Color(color.r, color.g, color.b, alpha))


func _draw_safe_circle_outline(canvas: CanvasItem, center: Vector2, radius: float, color: Color, width: float) -> void:
	if radius <= 1.0 or width <= 0.0 or color.a <= 0.0:
		return
	var safe_width: float = min(width, max(1.0, radius * 0.85))
	canvas.draw_circle(center, radius, color, false, safe_width)


func _draw_dynamite_smoke_clouds(canvas: CanvasItem, smoke_clouds: Array, shake_offset: Vector2) -> void:
	for cloud_value in smoke_clouds:
		if not (cloud_value is Dictionary):
			continue
		var cloud: Dictionary = cloud_value
		var life_frames: float = float(cloud.get("life_frames", 0.0))
		var max_life_frames: float = max(1.0, float(cloud.get("max_life_frames", 36.0)))
		var life: float = clamp(life_frames / max_life_frames, 0.0, 1.0)
		if life <= DYNAMITE_PARTICLE_ALPHA_CUTOFF:
			continue
		var center: Vector2 = _get_vector2(cloud, "position", Vector2.ZERO) + shake_offset
		var size: float = max(1.0, float(cloud.get("size", 20.0)))
		for i in range(2):
			var radius: float = max(1.0, size - float(i) * size / 2.5)
			var gray: float = (62.0 + float(i) * 32.0) / 255.0
			var alpha: float = (120.0 / 255.0) * life / float(i + 1)
			canvas.draw_circle(center, radius, Color(gray, gray, gray, alpha))


func _draw_dynamite_sparks(canvas: CanvasItem, sparks: Array, shake_offset: Vector2) -> void:
	for spark_value in sparks:
		if not (spark_value is Dictionary):
			continue
		var spark: Dictionary = spark_value
		var life_frames: float = float(spark.get("life_frames", 0.0))
		var max_life_frames: float = max(1.0, float(spark.get("max_life_frames", 20.0)))
		var life: float = clamp(life_frames / max_life_frames, 0.0, 1.0)
		if life <= DYNAMITE_PARTICLE_ALPHA_CUTOFF:
			continue
		var pos: Vector2 = _get_vector2(spark, "position", Vector2.ZERO) + shake_offset
		var vel: Vector2 = _get_vector2(spark, "velocity", Vector2.ZERO)
		var tail: Vector2 = pos - vel * 0.3
		var color := Color(1.0, 230.0 / 255.0, 180.0 / 255.0, life)
		canvas.draw_line(pos, tail, Color(color.r, color.g, color.b, color.a * 0.5), 1.0)
		canvas.draw_circle(pos, 2.5, color)


func _draw_dynamite_fire_particles(canvas: CanvasItem, particles: Array, shake_offset: Vector2) -> void:
	for particle_value in particles:
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		var life_frames: float = float(particle.get("life_frames", 0.0))
		var max_life_frames: float = max(1.0, float(particle.get("max_life_frames", 30.0)))
		var life: float = clamp(life_frames / max_life_frames, 0.0, 1.0)
		if life <= DYNAMITE_PARTICLE_ALPHA_CUTOFF:
			continue
		var center: Vector2 = _get_vector2(particle, "position", Vector2.ZERO) + shake_offset
		var size: float = max(1.0, float(particle.get("size", 3.0)))
		var color_type: String = str(particle.get("color_type", "fire"))
		var color := Color(1.0, 120.0 / 255.0 + 100.0 / 255.0 * life, 30.0 / 255.0 * life, life * life)
		if color_type == "spark":
			color = Color(1.0, 230.0 / 255.0 + 25.0 / 255.0 * life, 180.0 / 255.0 + 75.0 / 255.0 * life, life * life)
		elif color_type == "ember":
			color = Color(200.0 / 255.0 + 55.0 / 255.0 * life, 60.0 / 255.0 + 60.0 / 255.0 * life, 20.0 / 255.0 * life, life * life)
		if color.a > 0.08:
			canvas.draw_circle(center, size + 1.5, Color(color.r, color.g * 0.5, color.b * 0.5, color.a * 0.28))
		canvas.draw_circle(center, size, color)


func _draw_dynamite_flame(canvas: CanvasItem, center: Vector2, angle_degrees: float, scale: float, countdown: float) -> void:
	var fuse_progress: float = clamp(countdown / DYNAMITE_COUNTDOWN_FRAMES, 0.0, 1.0)
	var local_y: float = lerp(-14.0, -22.0, fuse_progress) * scale
	var flame_center: Vector2 = _rotated_local(center, Vector2(0.0, local_y), deg_to_rad(angle_degrees))
	var flame_intensity: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.02)
	canvas.draw_circle(flame_center, 4.0 * scale, Color(flame_intensity, 150.0 / 255.0 * flame_intensity, 50.0 / 255.0, 1.0))
	canvas.draw_circle(flame_center, 2.0 * scale, Color(1.0, 1.0, 150.0 / 255.0, 1.0))
	for i in range(1):
		var jitter := Vector2(sin(countdown * 0.31 + float(i)) * 2.4, cos(countdown * 0.27 + float(i)) * 1.6)
		canvas.draw_circle(
			flame_center + jitter * scale,
			max(1.0, scale),
			Color(1.0, 200.0 / 255.0, 100.0 / 255.0, 0.9)
		)


func _draw_rotated_texture_region(
	canvas: CanvasItem,
	texture: Texture2D,
	source_rect: Rect2,
	center: Vector2,
	draw_size: Vector2,
	angle_degrees: float
) -> void:
	if draw_size.x <= 0.0 or draw_size.y <= 0.0:
		return
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var angle: float = deg_to_rad(angle_degrees)
	var half_size: Vector2 = draw_size * 0.5
	var local_corners := [
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	]
	var points := PackedVector2Array()
	for corner in local_corners:
		points.append(_rotated_local(center, corner, angle))
	var uv_min := Vector2(source_rect.position.x / texture_size.x, source_rect.position.y / texture_size.y)
	var uv_max := Vector2(source_rect.end.x / texture_size.x, source_rect.end.y / texture_size.y)
	var uvs := PackedVector2Array([
		Vector2(uv_min.x, uv_min.y),
		Vector2(uv_max.x, uv_min.y),
		Vector2(uv_max.x, uv_max.y),
		Vector2(uv_min.x, uv_max.y),
	])
	canvas.draw_polygon(points, PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]), uvs, texture)


func _rotated_local(center: Vector2, local: Vector2, angle: float) -> Vector2:
	return center + Vector2(
		local.x * cos(angle) - local.y * sin(angle),
		local.x * sin(angle) + local.y * cos(angle)
	)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _touch_texture(texture: Texture2D) -> void:
	if texture != null:
		texture.get_width()
