extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")

const GRENADE_ICON_PATH := ActiveItemCatalog.GRENADE_ICON_PATH
const FLARE_ICON_PATH := ActiveItemCatalog.FLARE_ICON_PATH
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const GRENADE_THROW_WINDUP_MSEC := 600
const GRENADE_DRAW_SIZE := 36.0
const GRENADE_EXPLOSION_RADIUS := 190.0
const GRENADE_EXPLOSION_DURATION_FRAMES := 25.0
const FLARE_THROW_WINDUP_MSEC := 600
const FLARE_DRAW_SIZE := 34.0
const FLARE_RADIUS := 180.0

var grenade_icon_texture: Texture2D
var flare_icon_texture: Texture2D


func draw(
	canvas: CanvasItem,
	pending_throws: Array,
	grenades: Array,
	flares: Array,
	explosion_zones: Array,
	flare_zones: Array,
	shake_offset: Vector2 = Vector2.ZERO
) -> void:
	if canvas == null:
		return
	_draw_grenade_throw_windups(canvas, pending_throws, shake_offset)
	_draw_grenades(canvas, grenades, shake_offset)
	_draw_flares(canvas, flares, shake_offset)
	_draw_explosion_zones(canvas, explosion_zones, shake_offset)
	_draw_flare_zones(canvas, flare_zones, shake_offset)


func _draw_grenade_throw_windups(canvas: CanvasItem, pending_throws: Array, shake_offset: Vector2) -> void:
	if pending_throws.is_empty():
		return
	var now_msec: int = Time.get_ticks_msec()
	for pending_value in pending_throws:
		if not (pending_value is Dictionary):
			continue
		var pending_throw: Dictionary = pending_value
		var item_name: String = str(pending_throw.get("item_name", "grenade"))
		var fallback_duration_msec: int = FLARE_THROW_WINDUP_MSEC if item_name == "flare" else GRENADE_THROW_WINDUP_MSEC
		var start_msec: int = int(pending_throw.get("start_msec", now_msec))
		var release_msec: int = int(pending_throw.get("release_msec", start_msec + fallback_duration_msec))
		var duration_msec: int = max(1, release_msec - start_msec)
		var progress: float = clamp(float(now_msec - start_msec) / float(duration_msec), 0.0, 1.0)
		var start_pos: Vector2 = _get_vector2(pending_throw, "start_position", Vector2.ZERO) + shake_offset
		var target_pos: Vector2 = _get_vector2(pending_throw, "target_position", start_pos) + shake_offset
		var lift_pos: Vector2 = start_pos + Vector2(0.0, -34.0 - sin(progress * PI) * 12.0)
		var throw_pos: Vector2 = lift_pos.lerp(target_pos, max(0.0, (progress - 0.72) / 0.28) * 0.18)
		var angle: float = lerp(0.0, -35.0, progress)
		var texture: Texture2D = _get_throw_item_icon_texture(item_name)
		var draw_size: float = FLARE_DRAW_SIZE if item_name == "flare" else GRENADE_DRAW_SIZE
		if texture != null:
			_draw_rotated_texture_region(
				canvas,
				texture,
				Rect2(Vector2.ZERO, texture.get_size()),
				throw_pos,
				Vector2(draw_size, draw_size),
				angle
			)
		elif item_name == "flare":
			canvas.draw_circle(throw_pos, 11.0, Color(1.0, 1.0, 200.0 / 255.0, 1.0))
		else:
			canvas.draw_circle(throw_pos, 12.0, Color(80.0 / 255.0, 100.0 / 255.0, 80.0 / 255.0, 1.0))


func _draw_grenades(canvas: CanvasItem, grenades: Array, shake_offset: Vector2) -> void:
	if grenades.is_empty():
		return
	var texture: Texture2D = _get_grenade_icon_texture()
	for grenade_value in grenades:
		if not (grenade_value is Dictionary):
			continue
		var grenade: Dictionary = grenade_value
		var trail: Array = grenade.get("trail", [])
		for i in range(trail.size()):
			var trail_pos: Variant = trail[i]
			if not (trail_pos is Vector2):
				continue
			var alpha: float = float(i + 1) / float(max(1, trail.size())) * 0.28
			canvas.draw_circle(trail_pos + shake_offset, 3.0, Color(1.0, 190.0 / 255.0, 80.0 / 255.0, alpha))

		var center: Vector2 = _get_vector2(grenade, "position", Vector2.ZERO) + shake_offset
		var angle: float = float(grenade.get("rotation_degrees", 0.0))
		if texture != null:
			_draw_rotated_texture_region(
				canvas,
				texture,
				Rect2(Vector2.ZERO, texture.get_size()),
				center,
				Vector2(GRENADE_DRAW_SIZE, GRENADE_DRAW_SIZE),
				angle
			)
		else:
			canvas.draw_circle(center, 12.0, Color(80.0 / 255.0, 100.0 / 255.0, 80.0 / 255.0, 1.0))


func _draw_flares(canvas: CanvasItem, flares: Array, shake_offset: Vector2) -> void:
	if flares.is_empty():
		return
	var texture: Texture2D = _get_flare_icon_texture()
	for flare_value in flares:
		if not (flare_value is Dictionary):
			continue
		var flare: Dictionary = flare_value
		var center: Vector2 = _get_vector2(flare, "position", Vector2.ZERO) + shake_offset
		if bool(flare.get("arrived", false)) and not bool(flare.get("exploded", false)):
			var timer_frames: int = int(flare.get("timer_frames", 0.0))
			if timer_frames % 10 < 5:
				canvas.draw_circle(center, 12.0, Color(1.0, 1.0, 100.0 / 255.0, 0.95))
			canvas.draw_circle(center, 8.0, Color(1.0, 200.0 / 255.0, 0.0, 1.0), false, 2.0)
			continue

		var trail: Array = flare.get("trail", [])
		for i in range(trail.size()):
			var trail_pos: Variant = trail[i]
			if not (trail_pos is Vector2):
				continue
			var alpha: float = float(i + 1) / float(max(1, trail.size())) * 0.34
			canvas.draw_circle(trail_pos + shake_offset, 3.5, Color(1.0, 1.0, 180.0 / 255.0, alpha))

		var angle: float = float(flare.get("rotation_degrees", 0.0))
		if texture != null:
			_draw_rotated_texture_region(
				canvas,
				texture,
				Rect2(Vector2.ZERO, texture.get_size()),
				center,
				Vector2(FLARE_DRAW_SIZE, FLARE_DRAW_SIZE),
				angle
			)
		else:
			canvas.draw_circle(center, 10.0, Color(1.0, 1.0, 200.0 / 255.0, 1.0))


func _draw_explosion_zones(canvas: CanvasItem, explosion_zones: Array, shake_offset: Vector2) -> void:
	if explosion_zones.is_empty():
		return
	for zone_value in explosion_zones:
		if not (zone_value is Dictionary):
			continue
		var zone: Dictionary = zone_value
		if not bool(zone.get("active", true)):
			continue
		var center: Vector2 = _get_vector2(zone, "position", Vector2.ZERO) + shake_offset
		var radius: float = float(zone.get("radius", GRENADE_EXPLOSION_RADIUS))
		var max_duration: float = max(1.0, float(zone.get("max_duration_frames", GRENADE_EXPLOSION_DURATION_FRAMES)))
		var remaining: float = clamp(float(zone.get("duration_frames", max_duration)), 0.0, max_duration)
		var elapsed: float = max_duration - remaining
		var life: float = remaining / max_duration

		var shockwave_radius: float = radius + elapsed * 6.0
		if shockwave_radius < radius * 2.5:
			canvas.draw_arc(center, shockwave_radius, 0.0, TAU, 72, Color(1.0, 1.0, 1.0, 0.18 * life), 4.0)

		var fire_scale: float = min(1.0, (elapsed + 1.0) / 3.0) if elapsed < 4.0 else max(0.0, 1.0 - (elapsed - 4.0) / 21.0)
		var fire_radius: float = radius * fire_scale
		if fire_radius > 3.0:
			for step in range(0, 12):
				var ratio: float = 1.0 - float(step) / 12.0
				var ring_radius: float = max(2.0, fire_radius * ratio)
				var color: Color
				if remaining > max_duration * 0.65:
					color = Color(1.0, lerp(155.0 / 255.0, 1.0, ratio), lerp(50.0 / 255.0, 200.0 / 255.0, ratio), 0.78 * life * ratio)
				elif remaining > max_duration * 0.3:
					color = Color(1.0, lerp(50.0 / 255.0, 150.0 / 255.0, ratio), lerp(10.0 / 255.0, 50.0 / 255.0, ratio), 0.72 * life * ratio)
				else:
					color = Color(lerp(100.0 / 255.0, 200.0 / 255.0, ratio), lerp(10.0 / 255.0, 50.0 / 255.0, ratio), 30.0 / 255.0, 0.58 * life * ratio)
				canvas.draw_circle(center, ring_radius, color)

		var smoke_radius: float = radius * 0.6 + elapsed * 3.0
		for j in range(6):
			var angle: float = float(j) * TAU / 6.0 + elapsed * 0.09
			var distance: float = 16.0 + float((j * 17) % 31)
			var offset := Vector2(cos(angle), sin(angle)) * distance + Vector2(0.0, -elapsed * 1.5)
			var smoke_alpha: float = 0.22 * life
			var tone: float = 0.22 + float(j % 3) * 0.04
			canvas.draw_circle(center + offset, smoke_radius * (0.42 + float(j % 2) * 0.08), Color(tone, tone * 0.9, tone * 0.78, smoke_alpha))

		if elapsed < 6.0:
			var spark_alpha: float = 0.78 * (1.0 - elapsed / 6.0)
			for k in range(10):
				var angle: float = float(k) * TAU / 10.0 + sin(float(k) * 2.17 + elapsed) * 0.22
				var end_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * (radius * 0.7 + float((k * 11) % 21))
				canvas.draw_line(center, end_pos, Color(1.0, 1.0, 200.0 / 255.0, spark_alpha), 2.0)
				canvas.draw_circle(end_pos, 4.0, Color(1.0, 1.0, 220.0 / 255.0, spark_alpha * 0.6))

		if elapsed < 3.0:
			var flash_alpha: float = 0.78 * (1.0 - elapsed / 3.0)
			canvas.draw_circle(center, radius * 0.4, Color(1.0, 250.0 / 255.0, 230.0 / 255.0, flash_alpha))


func _draw_flare_zones(canvas: CanvasItem, flare_zones: Array, shake_offset: Vector2) -> void:
	if flare_zones.is_empty():
		return
	for zone_value in flare_zones:
		if not (zone_value is Dictionary):
			continue
		var zone: Dictionary = zone_value
		var center: Vector2 = _get_vector2(zone, "position", Vector2.ZERO) + shake_offset
		var radius: float = float(zone.get("radius", FLARE_RADIUS))
		var intensity: float = clamp(float(zone.get("intensity", 1.0)), 0.0, 1.0)
		if intensity <= 0.0:
			continue

		if bool(zone.get("flash", false)):
			canvas.draw_rect(Rect2(shake_offset, Vector2(FIELD_WIDTH, FIELD_HEIGHT)), Color(1.0, 1.0, 230.0 / 255.0, (180.0 / 255.0) * intensity))
			for i in range(5):
				var layer_radius: float = radius * (1.0 - float(i) * 0.15)
				var alpha: float = intensity * (1.0 - float(i) * 0.20)
				if alpha > 0.0 and layer_radius > 1.0:
					canvas.draw_circle(center, layer_radius, Color(1.0, 1.0, 240.0 / 255.0, alpha))
			if intensity > 0.7:
				var cross_length: float = radius * 2.0
				canvas.draw_line(center + Vector2(-cross_length, 0.0), center + Vector2(cross_length, 0.0), Color.WHITE, 5.0)
				canvas.draw_line(center + Vector2(0.0, -cross_length), center + Vector2(0.0, cross_length), Color.WHITE, 5.0)
		else:
			for i in range(3):
				var layer_radius: float = radius * (1.0 - float(i) * 0.2)
				var alpha: float = (100.0 / 255.0) * intensity * (1.0 - float(i) * 0.3)
				if alpha > 0.0 and layer_radius > 1.0:
					canvas.draw_circle(center, layer_radius, Color(1.0, 1.0, 200.0 / 255.0, alpha))


func _draw_rotated_texture_region(
	canvas: CanvasItem,
	texture: Texture2D,
	source_rect: Rect2,
	center: Vector2,
	draw_size: Vector2,
	angle_degrees: float
) -> void:
	var half_size: Vector2 = draw_size * 0.5
	var radians: float = deg_to_rad(angle_degrees)
	var cos_a: float = cos(radians)
	var sin_a: float = sin(radians)
	var offsets := [
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	]
	var points := PackedVector2Array()
	for offset in offsets:
		points.append(center + Vector2(
			offset.x * cos_a - offset.y * sin_a,
			offset.x * sin_a + offset.y * cos_a
		))

	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var uv_min := Vector2(source_rect.position.x / texture_size.x, source_rect.position.y / texture_size.y)
	var uv_max := Vector2(source_rect.end.x / texture_size.x, source_rect.end.y / texture_size.y)
	var uvs := PackedVector2Array([
		Vector2(uv_min.x, uv_min.y),
		Vector2(uv_max.x, uv_min.y),
		Vector2(uv_max.x, uv_max.y),
		Vector2(uv_min.x, uv_max.y),
	])
	var colors := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	canvas.draw_polygon(points, colors, uvs, texture)


func _get_grenade_icon_texture() -> Texture2D:
	if grenade_icon_texture == null:
		grenade_icon_texture = ProjectResourceLoader.load_texture(
			GRENADE_ICON_PATH,
			"Missing grenade icon at %s",
			"Failed to load grenade icon at %s"
		)
	return grenade_icon_texture


func _get_flare_icon_texture() -> Texture2D:
	if flare_icon_texture == null:
		flare_icon_texture = ProjectResourceLoader.load_texture(
			FLARE_ICON_PATH,
			"Missing flare icon at %s",
			"Failed to load flare icon at %s"
		)
	return flare_icon_texture


func _get_throw_item_icon_texture(item_name: String) -> Texture2D:
	if item_name == "flare":
		return _get_flare_icon_texture()
	return _get_grenade_icon_texture()


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
