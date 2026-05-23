extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")

const BOOMERANG_ICON_PATH := ActiveItemCatalog.BOOMERANG_ICON_PATH
const BOOMERANG_METAL_ICON_PATH := ActiveItemCatalog.BOOMERANG_METAL_ICON_PATH
const BOOMERANG_DRAW_SIZE := 42.0

var boomerang_icon_texture: Texture2D
var boomerang_metal_icon_texture: Texture2D


func prewarm_assets() -> void:
	_touch_texture(_get_boomerang_icon_texture())
	_touch_texture(_get_boomerang_icon_texture(true))


func draw_boomerangs(canvas: CanvasItem, boomerangs: Array, shake_offset: Vector2) -> void:
	if boomerangs.is_empty():
		return
	for boomerang_value in boomerangs:
		if not (boomerang_value is Dictionary):
			continue
		var boomerang: Dictionary = boomerang_value
		var gauntlet_equipped: bool = bool(boomerang.get("gauntlet_equipped", false))
		var texture: Texture2D = _get_boomerang_icon_texture(gauntlet_equipped)
		var trail: Array = boomerang.get("trail", [])
		for i in range(max(0, trail.size() - 1)):
			var p1_value: Variant = trail[i]
			var p2_value: Variant = trail[i + 1]
			if not (p1_value is Vector2) or not (p2_value is Vector2):
				continue
			var ratio: float = float(i + 1) / float(max(1, trail.size()))
			var alpha: float = (0.10 + ratio * 0.34) if gauntlet_equipped else (0.08 + ratio * 0.24)
			var trail_color := Color(120.0 / 255.0, 225.0 / 255.0, 1.0, alpha) if gauntlet_equipped else Color(220.0 / 255.0, 165.0 / 255.0, 85.0 / 255.0, alpha)
			canvas.draw_line(p1_value + shake_offset, p2_value + shake_offset, trail_color, max(1.0, ratio * (6.0 if gauntlet_equipped else 5.0)))

		var center: Vector2 = _get_vector2(boomerang, "position", Vector2.ZERO) + shake_offset
		var angle: float = float(boomerang.get("angle_degrees", 0.0))
		if gauntlet_equipped:
			canvas.draw_circle(center, 43.0, Color(80.0 / 255.0, 210.0 / 255.0, 1.0, 0.16))
			canvas.draw_circle(center, 28.0, Color(220.0 / 255.0, 1.0, 1.0, 0.08))
		elif str(boomerang.get("phase", "outgoing")) == "returning":
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
			draw_boomerang_fallback(canvas, center, angle, 1.0)


func draw_boomerang_particles(canvas: CanvasItem, boomerang_particles: Array, shake_offset: Vector2) -> void:
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


func draw_boomerang_fallback(canvas: CanvasItem, center: Vector2, angle_degrees: float, scale: float) -> void:
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


func _get_boomerang_icon_texture(use_metal: bool = false) -> Texture2D:
	if use_metal:
		if boomerang_metal_icon_texture == null:
			boomerang_metal_icon_texture = ProjectResourceLoader.load_texture(
				BOOMERANG_METAL_ICON_PATH,
				"Missing metal boomerang icon at %s",
				"Failed to load metal boomerang icon at %s"
			)
		if boomerang_metal_icon_texture != null:
			return boomerang_metal_icon_texture
	if boomerang_icon_texture == null:
		boomerang_icon_texture = ProjectResourceLoader.load_texture(
			BOOMERANG_ICON_PATH,
			"Missing boomerang icon at %s",
			"Failed to load boomerang icon at %s"
		)
	return boomerang_icon_texture


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


func _get_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is Array and value.size() >= 3:
		return Color(float(value[0]) / 255.0, float(value[1]) / 255.0, float(value[2]) / 255.0, 1.0)
	return fallback


func _touch_texture(texture: Texture2D) -> void:
	if texture != null:
		texture.get_width()
