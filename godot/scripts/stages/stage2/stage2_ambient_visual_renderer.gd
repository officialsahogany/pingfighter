extends RefCounted

const DEFAULT_LEAF_PARTICLE_LIFE_SEC := 0.95


func draw_ambient_layers(
	canvas: CanvasItem,
	falling_leaves: Array,
	fireflies: Array,
	leaf_texture: Texture2D,
	leaf_source_regions: Array,
	ambient_game_offset: Vector2,
	ambient_game_size: Vector2,
	ambient_time: float,
	falling_leaf_render_limit: int = -1
) -> void:
	_draw_falling_leaves(canvas, falling_leaves, leaf_texture, leaf_source_regions, falling_leaf_render_limit)
	_draw_fireflies(canvas, fireflies, ambient_game_offset, ambient_game_size, ambient_time)


func draw_leaf_particles(
	canvas: CanvasItem,
	leaf_particles: Array,
	shake_offset: Vector2,
	leaf_particle_life_sec: float = DEFAULT_LEAF_PARTICLE_LIFE_SEC,
	render_limit: int = -1
) -> void:
	for particle_index in range(_recent_start(leaf_particles, render_limit), leaf_particles.size()):
		var particle_value: Variant = leaf_particles[particle_index]
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		_draw_leaf_particle(canvas, particle, shake_offset, leaf_particle_life_sec)


func draw_rustle_vegetation(
	canvas: CanvasItem,
	rustle_vines: Array,
	rustle_bushes: Array,
	shake_offset: Vector2
) -> void:
	_draw_rustle_vines(canvas, rustle_vines, shake_offset)
	for bush in rustle_bushes:
		_draw_rustle_bush(canvas, bush, shake_offset)


func _draw_falling_leaves(
	canvas: CanvasItem,
	falling_leaves: Array,
	leaf_texture: Texture2D,
	leaf_source_regions: Array,
	render_limit: int = -1
) -> void:
	for leaf_index in range(_recent_start(falling_leaves, render_limit), falling_leaves.size()):
		var leaf_value: Variant = falling_leaves[leaf_index]
		if not (leaf_value is Dictionary):
			continue
		var leaf: Dictionary = leaf_value
		var sway_x: float = sin(float(leaf.get("sway_offset", 0.0))) * 20.0
		var center := Vector2(float(leaf.get("x", 0.0)) + sway_x, float(leaf.get("y", 0.0)))
		var size: float = float(leaf.get("size", 10.0))
		var rotation_degrees: float = float(leaf.get("rotation", 0.0))
		if _draw_ambient_leaf_sprite(
			canvas,
			center,
			size,
			rotation_degrees,
			int(leaf.get("sprite_index", 0)),
			leaf_texture,
			leaf_source_regions
		):
			continue
		_draw_fallback_ambient_leaf(canvas, center, size, deg_to_rad(rotation_degrees))


func _draw_ambient_leaf_sprite(
	canvas: CanvasItem,
	center: Vector2,
	size: float,
	rotation_degrees: float,
	sprite_index: int,
	leaf_texture: Texture2D,
	leaf_source_regions: Array
) -> bool:
	if leaf_texture == null or leaf_source_regions.is_empty():
		return false
	var source: Rect2 = _get_rect2(leaf_source_regions[sprite_index % leaf_source_regions.size()])
	if source.size.x <= 0.0 or source.size.y <= 0.0:
		return false
	var max_size := Vector2(size * 4.0, size * 3.0)
	var scale_factor: float = min(max_size.x / source.size.x, max_size.y / source.size.y)
	var target_size: Vector2 = source.size * scale_factor
	canvas.draw_set_transform(center, deg_to_rad(rotation_degrees), Vector2.ONE)
	canvas.draw_texture_rect_region(
		leaf_texture,
		Rect2(-target_size * 0.5, target_size),
		source,
		Color.WHITE,
		false,
		true
	)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true


func _draw_fallback_ambient_leaf(canvas: CanvasItem, center: Vector2, size: float, angle: float) -> void:
	var forward := Vector2(cos(angle), sin(angle))
	var side := Vector2(-forward.y, forward.x)
	var points := PackedVector2Array([
		center + forward * size,
		center + side * size * 0.42,
		center - forward * size * 0.80,
		center - side * size * 0.42,
	])
	canvas.draw_colored_polygon(points, Color(0.22, 0.56, 0.18, 0.74))
	canvas.draw_line(center - forward * size * 0.48, center + forward * size * 0.62, Color(0.78, 0.92, 0.42, 0.28), 1.0)


func _draw_fireflies(
	canvas: CanvasItem,
	fireflies: Array,
	ambient_game_offset: Vector2,
	ambient_game_size: Vector2,
	ambient_time: float
) -> void:
	var game_rect := Rect2(ambient_game_offset, ambient_game_size)
	for fly in fireflies:
		var pos := Vector2(float(fly.get("x", 0.0)), float(fly.get("y", 0.0)))
		if game_rect.has_point(pos):
			continue
		var glow: float = (sin(ambient_time * 2.5 + float(fly.get("phase", 0.0))) + 1.0) * 0.5
		if glow <= 0.25:
			continue
		var alpha: float = 70.0 / 255.0 * glow
		var size: float = float(fly.get("size", 2.0)) + floor(glow * 3.0)
		canvas.draw_circle(pos, size * 2.0, Color(0.42, 1.0, 0.52, alpha * 0.5))
		canvas.draw_circle(pos, size, Color(220.0 / 255.0, 1.0, 200.0 / 255.0, alpha))


func _draw_leaf_particle(
	canvas: CanvasItem,
	particle: Dictionary,
	shake_offset: Vector2,
	leaf_particle_life_sec: float
) -> void:
	var life: float = clamp(float(particle.get("life", 0.0)), 0.0, float(particle.get("max_life", leaf_particle_life_sec)))
	if life <= 0.0:
		return
	var fade: float = clamp(life / max(0.001, float(particle.get("max_life", leaf_particle_life_sec))), 0.0, 1.0)
	var pos: Vector2 = _get_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var size: float = float(particle.get("size", 8.0))
	var angle: float = float(particle.get("rot", 0.0))
	var color: Color = particle.get("color", Color(0.20, 0.56, 0.18, 1.0))
	color.a = 0.78 * fade
	var forward := Vector2(cos(angle), sin(angle))
	var side := Vector2(-forward.y, forward.x)
	var points := PackedVector2Array([
		pos + forward * size,
		pos + side * size * 0.42,
		pos - forward * size * 0.80,
		pos - side * size * 0.42,
	])
	canvas.draw_colored_polygon(points, color)
	canvas.draw_line(pos - forward * size * 0.48, pos + forward * size * 0.62, Color(0.78, 0.92, 0.42, 0.30 * fade), 1.0)


func _draw_rustle_vines(canvas: CanvasItem, rustle_vines: Array, shake_offset: Vector2) -> void:
	for vine in rustle_vines:
		var x: float = float(vine.get("x", 0.0))
		var length: float = float(vine.get("length", 100.0))
		var amount: float = float(vine.get("amount", 0.0))
		var angle: float = float(vine.get("angle", 0.0))
		var phase: float = float(vine.get("phase", 0.0))
		var points := PackedVector2Array()
		for idx in range(7):
			var depth: float = float(idx) / 6.0
			var sway: float = sin(phase + depth * 2.2) * amount * 0.42 + angle * amount * depth
			points.append(Vector2(x + sway, -3.0 + length * depth) + shake_offset)
		for idx in range(points.size() - 1):
			var alpha: float = 0.22 + float(idx) * 0.035
			canvas.draw_line(points[idx], points[idx + 1], Color(0.05, 0.22, 0.08, alpha), 3.0, true)
			canvas.draw_line(points[idx], points[idx + 1], Color(0.26, 0.48, 0.15, alpha * 0.45), 1.0, true)
		for leaf_idx in range(3):
			var depth: float = 0.34 + float(leaf_idx) * 0.20
			var leaf_pos: Vector2 = points[clampi(int(round(depth * 6.0)), 0, points.size() - 1)]
			var side: float = -1.0 if leaf_idx % 2 == 0 else 1.0
			_draw_small_leaf(canvas, leaf_pos + Vector2(side * 5.0, 0.0), 7.0, side * 0.85 + phase * 0.08, Color(0.22, 0.50, 0.13, 0.26 + amount * 0.012))


func _draw_rustle_bush(canvas: CanvasItem, bush: Dictionary, shake_offset: Vector2) -> void:
	var pos: Vector2 = _get_vector2(bush.get("pos", Vector2.ZERO), Vector2.ZERO)
	var radius: float = float(bush.get("radius", 28.0))
	var amount: float = float(bush.get("amount", 0.0))
	var angle: float = float(bush.get("angle", 0.0))
	var phase: float = float(bush.get("phase", 0.0))
	var seed_value: float = float(bush.get("seed", 0.0))
	var rustle_x: float = sin(angle + phase * 0.9) * amount
	var rustle_y: float = cos(angle * 1.5 + phase) * amount * 0.22
	var center: Vector2 = pos + Vector2(rustle_x, rustle_y) + shake_offset
	var area: String = str(bush.get("area", "player"))
	var alpha_base: float = 0.34 if area == "player" else 0.28
	canvas.draw_circle(center + Vector2(4.0, radius * 0.28), radius * 0.72, Color(0.0, 0.0, 0.0, 0.10))
	for idx in range(5):
		var local_angle: float = TAU * float(idx) / 5.0 + seed_value * 0.03
		var cluster_pos := center + Vector2(cos(local_angle) * radius * 0.32, sin(local_angle) * radius * 0.18)
		var cluster_radius: float = radius * (0.43 + 0.08 * sin(seed_value + float(idx)))
		canvas.draw_circle(cluster_pos, cluster_radius, Color(0.04, 0.19 + float(idx % 2) * 0.03, 0.07, alpha_base))
		canvas.draw_circle(cluster_pos + Vector2(-cluster_radius * 0.22, -cluster_radius * 0.16), cluster_radius * 0.58, Color(0.13, 0.36, 0.12, alpha_base * 0.74))
	var leaf_count := 8
	for idx in range(leaf_count):
		var leaf_angle: float = TAU * float(idx) / float(leaf_count) + seed_value * 0.11 + phase * 0.06
		var leaf_pos := center + Vector2(cos(leaf_angle) * radius * 0.74, sin(leaf_angle) * radius * 0.36)
		var leaf_size: float = 5.5 + 1.8 * sin(seed_value + float(idx) * 1.4)
		_draw_small_leaf(canvas, leaf_pos, leaf_size, leaf_angle + amount * 0.025, Color(0.25, 0.56, 0.15, 0.28 + min(0.28, amount * 0.018)))


func _draw_small_leaf(canvas: CanvasItem, pos: Vector2, size: float, angle: float, color: Color) -> void:
	var forward := Vector2(cos(angle), sin(angle))
	var side := Vector2(-forward.y, forward.x)
	var points := PackedVector2Array([
		pos + forward * size,
		pos + side * size * 0.42,
		pos - forward * size * 0.72,
		pos - side * size * 0.42,
	])
	canvas.draw_colored_polygon(points, color)
	canvas.draw_line(pos - forward * size * 0.42, pos + forward * size * 0.54, Color(0.70, 0.88, 0.34, color.a * 0.45), 1.0)


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _recent_start(source: Array, render_limit: int) -> int:
	if render_limit <= 0:
		return 0 if render_limit < 0 else source.size()
	return max(0, source.size() - render_limit)


func _get_rect2(value: Variant) -> Rect2:
	if value is Rect2:
		return value
	return Rect2()
