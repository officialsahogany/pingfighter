extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const BANANA_TEXTURE_PATH := "res://assets/sprites/items/banana.png"
const FLYING_DRAW_SIZE := 51.2
const LANDED_DRAW_SIZE := 72.0

var _banana_texture: Texture2D = null
var _ellipse_mesh: ArrayMesh = null


func prewarm() -> void:
	_ensure_banana_texture()
	_get_filled_ellipse_mesh()


func is_banana_texture_loaded() -> bool:
	return _banana_texture != null


func draw_banana_slice(
	canvas: CanvasItem,
	shake_offset: Vector2,
	prepare_active: bool,
	prepare_progress: float,
	prepare_pos: Vector2,
	projectiles: Array[Dictionary],
	landed_bananas: Array[Dictionary],
	particles: Array[Dictionary]
) -> void:
	if canvas == null:
		return
	_ensure_banana_texture()
	if prepare_active:
		_draw_banana(
			canvas,
			prepare_pos + shake_offset,
			FLYING_DRAW_SIZE,
			lerpf(-15.0, 15.0, clampf(prepare_progress, 0.0, 1.0))
		)
	for projectile in projectiles:
		if float(projectile.get("delay", 0.0)) > 0.0:
			continue
		_draw_projectile_trail(canvas, projectile.get("trail", []) as Array, shake_offset)
		_draw_banana(
			canvas,
			_get_vector2(projectile, "position", Vector2.ZERO) + shake_offset,
			FLYING_DRAW_SIZE,
			float(projectile.get("rotation_degrees", 0.0))
		)
	for landed in landed_bananas:
		var timer := float(landed.get("timer", 0.0))
		if timer < 1.0 and int(timer * 12.0) % 2 == 0:
			continue
		var pos := _get_vector2(landed, "position", Vector2.ZERO) + shake_offset
		_draw_filled_ellipse(canvas, Rect2(pos - Vector2(30.0, 5.0), Vector2(60.0, 10.0)), Color(1.0, 0.86, 0.18, 0.31))
		_draw_banana(canvas, pos, LANDED_DRAW_SIZE, 15.0)
	_draw_particles(canvas, particles, shake_offset)


func get_rotated_quad_for_tests(center: Vector2, draw_size: Vector2, angle_degrees: float) -> PackedVector2Array:
	if draw_size.x <= 0.0 or draw_size.y <= 0.0:
		return PackedVector2Array()
	var angle := deg_to_rad(angle_degrees)
	var half_size := draw_size * 0.5
	var local_corners := [
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	]
	var points := PackedVector2Array()
	for corner in local_corners:
		points.append(_rotated_local(center, corner, angle))
	return points


func _draw_projectile_trail(canvas: CanvasItem, trail: Array, shake_offset: Vector2) -> void:
	if trail.is_empty():
		return
	for index in range(trail.size()):
		var value: Variant = trail[index]
		if not (value is Vector2):
			continue
		var alpha := float(index + 1) / float(trail.size()) * 0.20
		canvas.draw_circle((value as Vector2) + shake_offset, 7.0, Color(1.0, 0.90, 0.18, alpha))


func _draw_banana(canvas: CanvasItem, center: Vector2, draw_size: float, angle_degrees: float) -> void:
	if _banana_texture == null:
		canvas.draw_circle(center, draw_size * 0.34, Color(1.0, 0.84, 0.10, 0.92))
		canvas.draw_arc(center, draw_size * 0.36, -0.9, 0.9, 16, Color(0.55, 0.32, 0.05, 0.95), 3.0)
		return
	_draw_rotated_texture_region(
		canvas,
		_banana_texture,
		Rect2(Vector2.ZERO, _banana_texture.get_size()),
		center,
		Vector2(draw_size, draw_size),
		angle_degrees
	)


func _draw_rotated_texture_region(
	canvas: CanvasItem,
	texture: Texture2D,
	source_rect: Rect2,
	center: Vector2,
	draw_size: Vector2,
	angle_degrees: float
) -> void:
	if texture == null or draw_size.x <= 0.0 or draw_size.y <= 0.0:
		return
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var points := get_rotated_quad_for_tests(center, draw_size, angle_degrees)
	var uv_min := Vector2(source_rect.position.x / texture_size.x, source_rect.position.y / texture_size.y)
	var uv_max := Vector2(source_rect.end.x / texture_size.x, source_rect.end.y / texture_size.y)
	var uvs := PackedVector2Array([
		Vector2(uv_min.x, uv_min.y),
		Vector2(uv_max.x, uv_min.y),
		Vector2(uv_max.x, uv_max.y),
		Vector2(uv_min.x, uv_max.y),
	])
	canvas.draw_polygon(points, PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]), uvs, texture)


func _draw_particles(canvas: CanvasItem, particles: Array[Dictionary], shake_offset: Vector2) -> void:
	for particle in particles:
		var max_life := maxf(0.001, float(particle.get("max_life", 0.67)))
		var alpha := clampf(float(particle.get("life", 0.0)) / max_life, 0.0, 1.0)
		var color: Color = particle.get("color", Color(1.0, 0.9, 0.2, 1.0))
		color.a *= alpha
		canvas.draw_circle(_get_vector2(particle, "position", Vector2.ZERO) + shake_offset, float(particle.get("size", 4.0)), color)


func _draw_filled_ellipse(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	if rect.size.x <= 1.0 or rect.size.y <= 1.0 or color.a <= 0.0:
		return
	var radius := rect.size * 0.5
	var center := rect.get_center()
	var transform := Transform2D(Vector2(radius.x, 0.0), Vector2(0.0, radius.y), center)
	canvas.draw_mesh(_get_filled_ellipse_mesh(), null, transform, color)


func _get_filled_ellipse_mesh() -> ArrayMesh:
	if _ellipse_mesh != null:
		return _ellipse_mesh
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	vertices.append(Vector3.ZERO)
	for step in range(24):
		var angle := TAU * float(step) / 24.0
		vertices.append(Vector3(cos(angle), sin(angle), 0.0))
	for step in range(24):
		indices.append(0)
		indices.append(step + 1)
		indices.append((step + 1) % 24 + 1)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_ellipse_mesh = mesh
	return _ellipse_mesh


func _rotated_local(center: Vector2, local: Vector2, angle: float) -> Vector2:
	return center + Vector2(
		local.x * cos(angle) - local.y * sin(angle),
		local.x * sin(angle) + local.y * cos(angle)
	)


func _ensure_banana_texture() -> Texture2D:
	if _banana_texture == null:
		_banana_texture = ProjectResourceLoader.load_texture(
			BANANA_TEXTURE_PATH,
			"Missing Banana Slice texture at %s",
			"Failed to load Banana Slice texture at %s"
		)
	return _banana_texture


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	return value as Vector2 if value is Vector2 else fallback
