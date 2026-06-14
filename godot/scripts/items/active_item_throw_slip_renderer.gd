extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")

const BANANA_ICON_PATH := ActiveItemCatalog.BANANA_ICON_PATH
const SOAP_ICON_PATH := ActiveItemCatalog.SOAP_ICON_PATH
const BANANA_DRAW_SIZE := 51.2
const BANANA_LANDED_DRAW_SIZE := 72.0
const BANANA_LAND_DURATION_FRAMES := 180.0
const SOAP_DRAW_SIZE := 48.0
const SOAP_LANDED_DRAW_SIZE := 56.0
const SOAP_LAND_DURATION_FRAMES := 240.0
const SOAP_PARTICLE_ALPHA_CUTOFF := 0.02
const FILLED_ELLIPSE_SEGMENTS := 32

static var _filled_ellipse_mesh: ArrayMesh = null

var banana_icon_texture: Texture2D
var soap_icon_texture: Texture2D


func prewarm_assets() -> void:
	_touch_texture(_get_banana_icon_texture())
	_touch_texture(_get_soap_icon_texture())
	_get_filled_ellipse_mesh()


func draw_bananas(canvas: CanvasItem, banana_projectiles: Array, shake_offset: Vector2) -> void:
	if banana_projectiles.is_empty():
		return
	var texture: Texture2D = _get_banana_icon_texture()
	for banana_value in banana_projectiles:
		if not (banana_value is Dictionary):
			continue
		var banana: Dictionary = banana_value
		_draw_projectile_trail(canvas, banana.get("trail", []), shake_offset, 3.0, Color(1.0, 225.0 / 255.0, 70.0 / 255.0, 1.0), 0.24)

		var center: Vector2 = _get_vector2(banana, "position", Vector2.ZERO) + shake_offset
		var angle: float = float(banana.get("rotation_degrees", 0.0))
		if texture != null:
			_draw_rotated_texture_region(
				canvas,
				texture,
				Rect2(Vector2.ZERO, texture.get_size()),
				center,
				Vector2(BANANA_DRAW_SIZE, BANANA_DRAW_SIZE),
				angle
			)
		else:
			draw_banana_fallback(canvas, center, angle, 1.0)


func draw_landed_bananas(canvas: CanvasItem, landed_bananas: Array, shake_offset: Vector2) -> void:
	if landed_bananas.is_empty():
		return
	var texture: Texture2D = _get_banana_icon_texture()
	for landed_value in landed_bananas:
		if not (landed_value is Dictionary):
			continue
		var landed: Dictionary = landed_value
		var timer_frames: int = int(landed.get("timer_frames", BANANA_LAND_DURATION_FRAMES))
		@warning_ignore("integer_division")
		if timer_frames < 60 and int(timer_frames / 5) % 2 == 0:
			continue
		var center: Vector2 = _get_vector2(landed, "position", Vector2.ZERO) + shake_offset
		if not bool(landed.get("slip_triggered", false)):
			_draw_filled_ellipse(canvas, Rect2(center + Vector2(-30.0, 5.0), Vector2(60.0, 10.0)), Color(1.0, 1.0, 0.0, 80.0 / 255.0))
		if texture != null:
			_draw_rotated_texture_region(
				canvas,
				texture,
				Rect2(Vector2.ZERO, texture.get_size()),
				center,
				Vector2(BANANA_LANDED_DRAW_SIZE, BANANA_LANDED_DRAW_SIZE),
				15.0
			)
		else:
			draw_banana_fallback(canvas, center, 15.0, BANANA_LANDED_DRAW_SIZE / BANANA_DRAW_SIZE)


func draw_banana_particles(canvas: CanvasItem, banana_particles: Array, shake_offset: Vector2) -> void:
	if banana_particles.is_empty():
		return
	for particle_value in banana_particles:
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		var life_frames: float = float(particle.get("life_frames", 0.0))
		var max_life_frames: float = max(1.0, float(particle.get("max_life_frames", 40.0)))
		var life: float = clamp(life_frames / max_life_frames, 0.0, 1.0)
		if life <= 0.0:
			continue
		var center: Vector2 = _get_vector2(particle, "position", Vector2.ZERO) + shake_offset
		var size: float = max(1.0, float(particle.get("size", 5.0)) * life)
		var color: Color = _get_color(particle.get("color", Color(1.0, 225.0 / 255.0, 50.0 / 255.0, 1.0)), Color(1.0, 225.0 / 255.0, 50.0 / 255.0, 1.0))
		canvas.draw_circle(center, size, Color(color.r, color.g, color.b, color.a * life))


func draw_soaps(canvas: CanvasItem, soap_projectiles: Array, shake_offset: Vector2) -> void:
	if soap_projectiles.is_empty():
		return
	var texture: Texture2D = _get_soap_icon_texture()
	for soap_value in soap_projectiles:
		if not (soap_value is Dictionary):
			continue
		var soap: Dictionary = soap_value
		_draw_projectile_trail(canvas, soap.get("trail", []), shake_offset, 3.0, Color(190.0 / 255.0, 230.0 / 255.0, 1.0, 1.0), 0.22)

		var center: Vector2 = _get_vector2(soap, "position", Vector2.ZERO) + shake_offset
		var angle: float = float(soap.get("rotation_degrees", 0.0))
		if texture != null:
			_draw_rotated_texture_region(
				canvas,
				texture,
				Rect2(Vector2.ZERO, texture.get_size()),
				center,
				Vector2(SOAP_DRAW_SIZE, SOAP_DRAW_SIZE),
				angle
			)
		else:
			draw_soap_fallback(canvas, center, angle, 1.0)


func draw_landed_soaps(canvas: CanvasItem, landed_soaps: Array, shake_offset: Vector2) -> void:
	if landed_soaps.is_empty():
		return
	var texture: Texture2D = _get_soap_icon_texture()
	for landed_value in landed_soaps:
		if not (landed_value is Dictionary):
			continue
		var landed: Dictionary = landed_value
		var timer_frames: int = int(landed.get("timer_frames", SOAP_LAND_DURATION_FRAMES))
		@warning_ignore("integer_division")
		if timer_frames < 60 and int(timer_frames / 5) % 2 == 0:
			continue
		var center: Vector2 = _get_vector2(landed, "position", Vector2.ZERO) + shake_offset
		var wobble: float = sin(float(landed.get("wobble_phase", 0.0))) * 3.0
		_draw_soap_puddle(canvas, center + Vector2(0.0, 8.0))
		if texture != null:
			_draw_rotated_texture_region(
				canvas,
				texture,
				Rect2(Vector2.ZERO, texture.get_size()),
				center + Vector2(wobble, 0.0),
				Vector2(SOAP_LANDED_DRAW_SIZE, SOAP_LANDED_DRAW_SIZE),
				wobble * 2.0
			)
		else:
			draw_soap_fallback(canvas, center + Vector2(wobble, 0.0), wobble * 2.0, SOAP_LANDED_DRAW_SIZE / SOAP_DRAW_SIZE)


func draw_soap_particles(canvas: CanvasItem, soap_particles: Array, shake_offset: Vector2) -> void:
	if soap_particles.is_empty():
		return
	for particle_value in soap_particles:
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		var age: float = float(particle.get("age", 0.0))
		var lifetime: float = max(0.001, float(particle.get("lifetime", 0.8)))
		var life: float = clamp(1.0 - age / lifetime, 0.0, 1.0)
		if life <= SOAP_PARTICLE_ALPHA_CUTOFF:
			continue
		var center: Vector2 = _get_vector2(particle, "position", Vector2.ZERO) + shake_offset
		var radius: float = max(1.0, float(particle.get("radius", 4.0))) * (0.65 + life * 0.35)
		var color: Color = _get_color(particle.get("color", Color(200.0 / 255.0, 230.0 / 255.0, 1.0, 1.0)), Color(200.0 / 255.0, 230.0 / 255.0, 1.0, 1.0))
		canvas.draw_circle(center, radius, Color(color.r, color.g, color.b, color.a * 0.55 * life), false, max(1.0, radius * 0.22))
		if life > 0.28:
			canvas.draw_circle(center + Vector2(-radius * 0.28, -radius * 0.28), max(1.0, radius * 0.24), Color(1.0, 1.0, 1.0, 0.38 * life))


func draw_soap_foam_trails(canvas: CanvasItem, soap_foam_trails: Array, shake_offset: Vector2) -> void:
	if soap_foam_trails.is_empty():
		return
	for foam_value in soap_foam_trails:
		if not (foam_value is Dictionary):
			continue
		var foam: Dictionary = foam_value
		var life_frames: float = float(foam.get("life_frames", 0.0))
		var max_life_frames: float = max(1.0, float(foam.get("max_life_frames", 45.0)))
		var life: float = clamp(life_frames / max_life_frames, 0.0, 1.0)
		if life <= SOAP_PARTICLE_ALPHA_CUTOFF:
			continue
		var center: Vector2 = _get_vector2(foam, "position", Vector2.ZERO) + shake_offset
		var radius: float = max(1.0, float(foam.get("size", 5.0))) * (0.6 + 0.4 * life)
		canvas.draw_circle(center, radius, Color(200.0 / 255.0, 230.0 / 255.0, 1.0, 0.46 * life), false, max(1.0, radius * 0.22))
		if life > 0.22:
			canvas.draw_circle(center, max(1.0, radius - 1.0), Color(220.0 / 255.0, 240.0 / 255.0, 1.0, 0.15 * life))


func draw_banana_fallback(canvas: CanvasItem, center: Vector2, angle_degrees: float, scale: float) -> void:
	var angle: float = deg_to_rad(angle_degrees)
	var cos_a: float = cos(angle)
	var sin_a: float = sin(angle)
	var points := PackedVector2Array()
	for i in range(16):
		var t: float = float(i) / 15.0
		var local_x: float = lerp(-20.0, 20.0, t) * scale
		var local_y: float = (-10.0 * sin(t * PI)) * scale
		points.append(center + Vector2(
			local_x * cos_a - local_y * sin_a,
			local_x * sin_a + local_y * cos_a
		))
	for i in range(15, -1, -1):
		var t: float = float(i) / 15.0
		var local_x: float = lerp(-20.0, 20.0, t) * scale
		var local_y: float = (-4.0 * sin(t * PI) + 8.0) * scale
		points.append(center + Vector2(
			local_x * cos_a - local_y * sin_a,
			local_x * sin_a + local_y * cos_a
		))
	if points.size() >= 3:
		canvas.draw_colored_polygon(points, Color(227.0 / 255.0, 189.0 / 255.0, 52.0 / 255.0, 1.0))
	var stem: Vector2 = center + Vector2(-20.0 * scale * cos_a, -20.0 * scale * sin_a)
	var tip: Vector2 = center + Vector2(20.0 * scale * cos_a - 2.0 * scale * sin_a, 20.0 * scale * sin_a + 2.0 * scale * cos_a)
	canvas.draw_circle(stem, 3.0 * scale, Color(154.0 / 255.0, 165.0 / 255.0, 67.0 / 255.0, 1.0))
	canvas.draw_circle(tip, 2.5 * scale, Color(89.0 / 255.0, 60.0 / 255.0, 31.0 / 255.0, 1.0))


func draw_soap_fallback(canvas: CanvasItem, center: Vector2, angle_degrees: float, scale: float) -> void:
	var body_size := Vector2(25.0, 17.0) * scale
	var angle: float = deg_to_rad(angle_degrees)
	var cos_a: float = cos(angle)
	var sin_a: float = sin(angle)
	var corners := [
		Vector2(-body_size.x * 0.5, -body_size.y * 0.5),
		Vector2(body_size.x * 0.5, -body_size.y * 0.5),
		Vector2(body_size.x * 0.5, body_size.y * 0.5),
		Vector2(-body_size.x * 0.5, body_size.y * 0.5),
	]
	var points := PackedVector2Array()
	for corner in corners:
		points.append(center + Vector2(
			corner.x * cos_a - corner.y * sin_a,
			corner.x * sin_a + corner.y * cos_a
		))
	canvas.draw_polygon(points, PackedColorArray([
		Color(140.0 / 255.0, 200.0 / 255.0, 240.0 / 255.0, 1.0),
		Color(180.0 / 255.0, 225.0 / 255.0, 1.0, 1.0),
		Color(110.0 / 255.0, 170.0 / 255.0, 220.0 / 255.0, 1.0),
		Color(140.0 / 255.0, 200.0 / 255.0, 240.0 / 255.0, 1.0),
	]))
	canvas.draw_line(points[0].lerp(points[1], 0.25), points[0].lerp(points[1], 0.75), Color(230.0 / 255.0, 250.0 / 255.0, 1.0, 0.95), max(1.0, 2.0 * scale))
	canvas.draw_circle(center + Vector2(13.0, -8.0) * scale, 3.0 * scale, Color(220.0 / 255.0, 240.0 / 255.0, 1.0, 0.75), false, max(1.0, scale))
	canvas.draw_circle(center + Vector2(-14.0, -5.0) * scale, 2.0 * scale, Color(220.0 / 255.0, 240.0 / 255.0, 1.0, 0.75), false, max(1.0, scale))


func _draw_soap_puddle(canvas: CanvasItem, center: Vector2) -> void:
	_draw_filled_ellipse(canvas, Rect2(center - Vector2(35.0, 8.0), Vector2(70.0, 16.0)), Color(180.0 / 255.0, 220.0 / 255.0, 1.0, 0.24))
	_draw_filled_ellipse(canvas, Rect2(center - Vector2(25.0, 5.0), Vector2(50.0, 10.0)), Color(200.0 / 255.0, 235.0 / 255.0, 1.0, 0.18))


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


func _draw_filled_ellipse(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	if color.a <= 0.0 or rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	var radius: Vector2 = rect.size * 0.5
	var center: Vector2 = rect.get_center()
	var transform := Transform2D(Vector2(radius.x, 0.0), Vector2(0.0, radius.y), center)
	canvas.draw_mesh(_get_filled_ellipse_mesh(), null, transform, color)


func _get_banana_icon_texture() -> Texture2D:
	if banana_icon_texture == null:
		banana_icon_texture = ProjectResourceLoader.load_texture(
			BANANA_ICON_PATH,
			"Missing banana icon at %s",
			"Failed to load banana icon at %s"
		)
	return banana_icon_texture


func _get_soap_icon_texture() -> Texture2D:
	if soap_icon_texture == null:
		soap_icon_texture = ProjectResourceLoader.load_texture(
			SOAP_ICON_PATH,
			"Missing soap icon at %s",
			"Failed to load soap icon at %s"
		)
	return soap_icon_texture


static func _get_filled_ellipse_mesh() -> ArrayMesh:
	if _filled_ellipse_mesh != null:
		return _filled_ellipse_mesh
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	vertices.append(Vector3.ZERO)
	for step in range(FILLED_ELLIPSE_SEGMENTS):
		var angle: float = TAU * float(step) / float(FILLED_ELLIPSE_SEGMENTS)
		vertices.append(Vector3(cos(angle), sin(angle), 0.0))
	for step in range(FILLED_ELLIPSE_SEGMENTS):
		indices.append(0)
		indices.append(step + 1)
		indices.append((step + 1) % FILLED_ELLIPSE_SEGMENTS + 1)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_filled_ellipse_mesh = mesh
	return _filled_ellipse_mesh


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
