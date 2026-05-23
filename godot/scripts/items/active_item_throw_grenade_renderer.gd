extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const GrenadeExplosionDrawer := preload("res://scripts/effects/grenade_explosion_drawer.gd")

const GRENADE_ICON_PATH := ActiveItemCatalog.GRENADE_ICON_PATH
const GRENADE_DRAW_SIZE := 36.0

var grenade_icon_texture: Texture2D


func prewarm_assets() -> void:
	_touch_texture(get_grenade_icon_texture())


func draw_grenades(canvas: CanvasItem, grenades: Array, shake_offset: Vector2) -> void:
	if grenades.is_empty():
		return
	var texture: Texture2D = get_grenade_icon_texture()
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
			draw_grenade_fallback(canvas, center)


func draw_explosion_zones(canvas: CanvasItem, explosion_zones: Array, shake_offset: Vector2) -> void:
	if explosion_zones.is_empty():
		return
	for zone_value in explosion_zones:
		if not (zone_value is Dictionary):
			continue
		var zone: Dictionary = zone_value
		GrenadeExplosionDrawer.draw_zone(canvas, zone, shake_offset)


func draw_grenade_fallback(canvas: CanvasItem, center: Vector2) -> void:
	canvas.draw_circle(center, 12.0, Color(80.0 / 255.0, 100.0 / 255.0, 80.0 / 255.0, 1.0))


func get_grenade_icon_texture() -> Texture2D:
	if grenade_icon_texture == null:
		grenade_icon_texture = ProjectResourceLoader.load_texture(
			GRENADE_ICON_PATH,
			"Missing grenade icon at %s",
			"Failed to load grenade icon at %s"
		)
	return grenade_icon_texture


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
		texture.get_size()
