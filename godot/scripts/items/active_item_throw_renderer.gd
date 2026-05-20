extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const GrenadeExplosionDrawer := preload("res://scripts/effects/grenade_explosion_drawer.gd")

const GRENADE_ICON_PATH := ActiveItemCatalog.GRENADE_ICON_PATH
const FLARE_ICON_PATH := ActiveItemCatalog.FLARE_ICON_PATH
const BOOMERANG_ICON_PATH := ActiveItemCatalog.BOOMERANG_ICON_PATH
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const GRENADE_THROW_WINDUP_MSEC := 600
const GRENADE_DRAW_SIZE := 36.0
const GRENADE_EXPLOSION_RADIUS := 190.0
const GRENADE_EXPLOSION_DURATION_FRAMES := 25.0
const FLARE_THROW_WINDUP_MSEC := 600
const FLARE_DRAW_SIZE := 34.0
const FLARE_RADIUS := 180.0
const FLARE_FLASH_LAYERS := 1
const FLARE_GLOW_LAYERS := 1
const BOOMERANG_DRAW_SIZE := 42.0

var grenade_icon_texture: Texture2D
var flare_icon_texture: Texture2D
var boomerang_icon_texture: Texture2D


func prewarm_assets() -> void:
	_touch_texture(_get_grenade_icon_texture())
	_touch_texture(_get_flare_icon_texture())
	_touch_texture(_get_boomerang_icon_texture())


func draw(
	canvas: CanvasItem,
	pending_throws: Array,
	grenades: Array,
	flares: Array,
	boomerangs: Array,
	boomerang_particles: Array,
	explosion_zones: Array,
	flare_zones: Array,
	shake_offset: Vector2 = Vector2.ZERO
) -> void:
	if canvas == null:
		return
	_draw_grenade_throw_windups(canvas, pending_throws, shake_offset)
	_draw_grenades(canvas, grenades, shake_offset)
	_draw_flares(canvas, flares, shake_offset)
	_draw_boomerang_particles(canvas, boomerang_particles, shake_offset)
	_draw_boomerangs(canvas, boomerangs, shake_offset)
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
		var draw_size: float = _get_throw_item_draw_size(item_name)
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
		elif item_name == "boomerang":
			_draw_boomerang_fallback(canvas, throw_pos, angle, 1.0)
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
		_draw_projectile_trail(canvas, grenade.get("trail", []), shake_offset, 3.0, Color(1.0, 190.0 / 255.0, 80.0 / 255.0, 1.0), 0.28)

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

		_draw_projectile_trail(canvas, flare.get("trail", []), shake_offset, 3.5, Color(1.0, 1.0, 180.0 / 255.0, 1.0), 0.34)

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


func _draw_projectile_trail(canvas: CanvasItem, trail: Array, shake_offset: Vector2, radius: float, color: Color, alpha_scale: float) -> void:
	var trail_count: int = trail.size()
	if trail_count <= 0:
		return
	var stride: int = 2 if trail_count > 5 else 1
	for i in range(0, trail_count, stride):
		var trail_pos: Variant = trail[i]
		if not (trail_pos is Vector2):
			continue
		var trail_point: Vector2 = trail_pos
		var alpha: float = float(i + 1) / float(trail_count) * alpha_scale
		canvas.draw_circle(trail_point + shake_offset, radius, Color(color.r, color.g, color.b, alpha))


func _draw_boomerangs(canvas: CanvasItem, boomerangs: Array, shake_offset: Vector2) -> void:
	if boomerangs.is_empty():
		return
	var texture: Texture2D = _get_boomerang_icon_texture()
	for boomerang_value in boomerangs:
		if not (boomerang_value is Dictionary):
			continue
		var boomerang: Dictionary = boomerang_value
		var trail: Array = boomerang.get("trail", [])
		for i in range(max(0, trail.size() - 1)):
			var p1_value: Variant = trail[i]
			var p2_value: Variant = trail[i + 1]
			if not (p1_value is Vector2) or not (p2_value is Vector2):
				continue
			var ratio: float = float(i + 1) / float(max(1, trail.size()))
			var alpha: float = 0.08 + ratio * 0.24
			canvas.draw_line(p1_value + shake_offset, p2_value + shake_offset, Color(220.0 / 255.0, 165.0 / 255.0, 85.0 / 255.0, alpha), max(1.0, ratio * 5.0))

		var center: Vector2 = _get_vector2(boomerang, "position", Vector2.ZERO) + shake_offset
		var angle: float = float(boomerang.get("angle_degrees", 0.0))
		if str(boomerang.get("phase", "outgoing")) == "returning":
			canvas.draw_circle(center, 39.0, Color(100.0 / 255.0, 200.0 / 255.0, 1.0, 0.14))
			canvas.draw_circle(center, 31.0, Color(150.0 / 255.0, 220.0 / 255.0, 1.0, 0.10))
		if texture != null:
			_draw_rotated_texture_region(
				canvas,
				texture,
				Rect2(Vector2.ZERO, texture.get_size()),
				center,
				Vector2(BOOMERANG_DRAW_SIZE, BOOMERANG_DRAW_SIZE),
				angle
			)
		else:
			_draw_boomerang_fallback(canvas, center, angle, 1.0)


func _draw_boomerang_particles(canvas: CanvasItem, boomerang_particles: Array, shake_offset: Vector2) -> void:
	if boomerang_particles.is_empty():
		return
	for particle_value in boomerang_particles:
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		var age: float = float(particle.get("age", 0.0))
		var lifetime: float = max(0.001, float(particle.get("lifetime", 0.6)))
		var life: float = clamp(1.0 - age / lifetime, 0.0, 1.0)
		if life <= 0.0:
			continue
		var center: Vector2 = _get_vector2(particle, "position", Vector2.ZERO) + shake_offset
		var radius: float = max(1.0, float(particle.get("radius", 3.0))) * (0.45 + life * 0.55)
		var color: Color = _get_color(particle.get("color", Color(200.0 / 255.0, 130.0 / 255.0, 60.0 / 255.0, 1.0)), Color(200.0 / 255.0, 130.0 / 255.0, 60.0 / 255.0, 1.0))
		canvas.draw_circle(center, radius, Color(color.r, color.g, color.b, color.a * life))


func _draw_boomerang_fallback(canvas: CanvasItem, center: Vector2, angle_degrees: float, scale: float) -> void:
	var angle: float = deg_to_rad(angle_degrees)
	var spread: float = deg_to_rad(75.0)
	var arm_length: float = 19.0 * scale
	var arm_width: float = max(2.0, 5.0 * scale)
	var a1: float = angle - spread * 0.5
	var a2: float = angle + spread * 0.5
	var end1: Vector2 = center + Vector2(cos(a1), sin(a1)) * arm_length
	var end2: Vector2 = center + Vector2(cos(a2), sin(a2)) * arm_length
	canvas.draw_line(center, end1, Color(90.0 / 255.0, 50.0 / 255.0, 20.0 / 255.0, 1.0), arm_width + 2.0)
	canvas.draw_line(center, end2, Color(90.0 / 255.0, 50.0 / 255.0, 20.0 / 255.0, 1.0), arm_width + 2.0)
	canvas.draw_line(center, end1, Color(170.0 / 255.0, 110.0 / 255.0, 55.0 / 255.0, 1.0), arm_width)
	canvas.draw_line(center, end2, Color(215.0 / 255.0, 165.0 / 255.0, 85.0 / 255.0, 1.0), arm_width)
	canvas.draw_circle(center, 4.0 * scale, Color(1.0, 210.0 / 255.0, 80.0 / 255.0, 1.0))


func _draw_explosion_zones(canvas: CanvasItem, explosion_zones: Array, shake_offset: Vector2) -> void:
	if explosion_zones.is_empty():
		return
	for zone_value in explosion_zones:
		if not (zone_value is Dictionary):
			continue
		var zone: Dictionary = zone_value
		GrenadeExplosionDrawer.draw_zone(canvas, zone, shake_offset)

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
			for i in range(FLARE_FLASH_LAYERS):
				var layer_radius: float = radius * (1.0 - float(i) * 0.18)
				var alpha: float = intensity * (1.0 - float(i) * 0.28)
				if alpha > 0.0 and layer_radius > 1.0:
					canvas.draw_circle(center, layer_radius, Color(1.0, 1.0, 240.0 / 255.0, alpha))
			if intensity > 0.85:
				var cross_length: float = radius * 2.0
				canvas.draw_line(center + Vector2(-cross_length, 0.0), center + Vector2(cross_length, 0.0), Color.WHITE, 5.0)
				canvas.draw_line(center + Vector2(0.0, -cross_length), center + Vector2(0.0, cross_length), Color.WHITE, 5.0)
		else:
			for i in range(FLARE_GLOW_LAYERS):
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


func _get_boomerang_icon_texture() -> Texture2D:
	if boomerang_icon_texture == null:
		boomerang_icon_texture = ProjectResourceLoader.load_texture(
			BOOMERANG_ICON_PATH,
			"Missing boomerang icon at %s",
			"Failed to load boomerang icon at %s"
		)
	return boomerang_icon_texture


func _get_throw_item_icon_texture(item_name: String) -> Texture2D:
	if item_name == "flare":
		return _get_flare_icon_texture()
	if item_name == "boomerang":
		return _get_boomerang_icon_texture()
	return _get_grenade_icon_texture()


func _touch_texture(texture: Texture2D) -> void:
	if texture != null:
		texture.get_size()


func _get_throw_item_draw_size(item_name: String) -> float:
	if item_name == "flare":
		return FLARE_DRAW_SIZE
	if item_name == "boomerang":
		return BOOMERANG_DRAW_SIZE
	return GRENADE_DRAW_SIZE


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _get_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is Array and value.size() >= 3:
		return Color(float(value[0]) / 255.0, float(value[1]) / 255.0, float(value[2]) / 255.0, 1.0)
	return fallback
