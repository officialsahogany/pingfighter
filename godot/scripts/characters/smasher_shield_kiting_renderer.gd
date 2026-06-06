extends RefCounted

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")

const STATE_WIND_UP := "wind_up"
const TRAIL_ALPHA_BASE := 0.34
const MAX_RENDERED_TRAIL_SHIELDS := 3
const MAX_RENDERED_HIT_SHARDS := 5
const SHIELD_RENDER_MODE := "procedural_pentagon_v2"
const CIRCUIT_PATH_COUNT := 8
const PROJECTILE_VISUAL_SCALE := 0.70
const CUTIN_SYMBOL_VISUAL_SCALE := 2.05
const OUTER_GLOW_LINE_WIDTH := 9.0
const OUTER_BEVEL_LINE_WIDTH := 4.8

const SHIELD_BLUE := Color(110.0 / 255.0, 210.0 / 255.0, 1.0)
const SHIELD_DEEP := Color(26.0 / 255.0, 68.0 / 255.0, 130.0 / 255.0)
const SHIELD_CORE := Color(230.0 / 255.0, 250.0 / 255.0, 1.0)
const SHIELD_PANEL := Color(48.0 / 255.0, 184.0 / 255.0, 238.0 / 255.0)
const SHIELD_SHADOW := Color(5.0 / 255.0, 22.0 / 255.0, 46.0 / 255.0)
const SHIELD_VIOLET := Color(172.0 / 255.0, 122.0 / 255.0, 1.0)
const PLASMA_GOLD := Color(1.0, 215.0 / 255.0, 90.0 / 255.0)
const SHIELD_BASE_POINTS: Array[Vector2] = [
	Vector2(0.0, -35.0),
	Vector2(32.0, -11.0),
	Vector2(20.0, 30.0),
	Vector2(-20.0, 30.0),
	Vector2(-32.0, -11.0),
]
const SHIELD_INNER_POINTS: Array[Vector2] = [
	Vector2(0.0, -20.0),
	Vector2(18.0, -5.0),
	Vector2(11.0, 18.0),
	Vector2(-11.0, 18.0),
	Vector2(-18.0, -5.0),
]


func _init() -> void:
	ImpactFlareTextureCache.prewarm()
	ImpactShockwaveTextureCache.prewarm()


func draw(canvas: CanvasItem, projectile: Dictionary, hit_effects: Array, shake_offset: Vector2) -> void:
	if canvas == null:
		return
	_draw_hit_effects(canvas, hit_effects, shake_offset)
	if not bool(projectile.get("active", false)):
		return
	var state: String = str(projectile.get("state", ""))
	var position: Vector2 = _as_vector2(projectile.get("position", Vector2.ZERO), Vector2.ZERO) + shake_offset
	if state == STATE_WIND_UP:
		_draw_wind_up_charge(canvas, projectile, position)
		return
	_draw_trail(canvas, projectile, shake_offset)
	_draw_shield(canvas, position, float(projectile.get("angle", 0.0)), 1.0)


func draw_cutin_symbol(
	canvas: CanvasItem,
	center: Vector2,
	progress: float,
	alpha: float,
	view_size: Vector2
) -> void:
	if canvas == null or alpha <= 0.02:
		return
	var symbol_alpha: float = alpha * (0.88 + 0.12 * sin(progress * TAU * 2.4))
	var angle: float = -18.0 + progress * 42.0 + sin(float(Time.get_ticks_msec()) * 0.006) * 6.0
	var scale: float = CUTIN_SYMBOL_VISUAL_SCALE * max(0.5, view_size.y / 750.0)
	_draw_shield(canvas, center, angle, symbol_alpha, scale)


func _draw_wind_up_charge(canvas: CanvasItem, projectile: Dictionary, position: Vector2) -> void:
	var strength: float = clamp(float(projectile.get("windup_strength", 0.0)), 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.022)
	var radius: float = 16.0 + 17.0 * strength + pulse * 4.0
	ImpactFlareTextureCache.draw_glow(canvas, position, radius + 8.0, SHIELD_BLUE, 0.18 + 0.20 * strength)
	ImpactShockwaveTextureCache.draw_full_ring(canvas, position, radius, SHIELD_CORE, 0.28 + 0.30 * strength)
	ImpactShockwaveTextureCache.draw_full_ring(canvas, position, radius + 6.0, SHIELD_BLUE, 0.20 + 0.28 * strength)


func _draw_trail(canvas: CanvasItem, projectile: Dictionary, shake_offset: Vector2) -> void:
	var trail: Array = _as_array(projectile.get("trail", []))
	var trail_start: int = max(0, trail.size() - MAX_RENDERED_TRAIL_SHIELDS)
	var visible_count: int = max(1, trail.size() - trail_start)
	for index in range(trail_start, trail.size()):
		var data: Variant = trail[index]
		if not (data is Dictionary):
			continue
		var t: float = float(index - trail_start + 1) / float(visible_count)
		var alpha: float = TRAIL_ALPHA_BASE * t
		var pos: Vector2 = _as_vector2(data.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		_draw_trail_ghost(canvas, pos, float(data.get("angle", 0.0)), alpha)


func _draw_trail_ghost(canvas: CanvasItem, center: Vector2, angle_deg: float, alpha: float) -> void:
	if alpha <= 0.02:
		return
	var angle: float = deg_to_rad(angle_deg)
	var c: float = cos(angle)
	var s: float = sin(angle)
	var rotation := Vector2(c, s)
	var points: PackedVector2Array = _build_rotated_points(SHIELD_BASE_POINTS, center, rotation, PROJECTILE_VISUAL_SCALE)
	var halo_points: PackedVector2Array = _build_rotated_points(SHIELD_BASE_POINTS, center, rotation, 1.13 * PROJECTILE_VISUAL_SCALE)
	canvas.draw_colored_polygon(halo_points, Color(SHIELD_BLUE.r, SHIELD_BLUE.g, SHIELD_BLUE.b, 0.075 * alpha))
	canvas.draw_colored_polygon(points, Color(SHIELD_SHADOW.r, SHIELD_SHADOW.g, SHIELD_SHADOW.b, 0.48 * alpha))
	canvas.draw_polyline(points, Color(SHIELD_BLUE.r, SHIELD_BLUE.g, SHIELD_BLUE.b, 0.92 * alpha), OUTER_BEVEL_LINE_WIDTH * PROJECTILE_VISUAL_SCALE, true)


func _draw_shield(
	canvas: CanvasItem,
	center: Vector2,
	angle_deg: float,
	alpha: float,
	visual_scale: float = PROJECTILE_VISUAL_SCALE
) -> void:
	if alpha <= 0.02:
		return
	var angle: float = deg_to_rad(angle_deg)
	var c: float = cos(angle)
	var s: float = sin(angle)
	var rotation := Vector2(c, s)
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.021 + angle * 1.7)
	var points: PackedVector2Array = _build_rotated_points(SHIELD_BASE_POINTS, center, rotation, visual_scale)
	var halo_points: PackedVector2Array = _build_rotated_points(SHIELD_BASE_POINTS, center, rotation, 1.13 * visual_scale)
	var bevel_points: PackedVector2Array = _build_rotated_points(SHIELD_BASE_POINTS, center, rotation, 0.90 * visual_scale)

	ImpactFlareTextureCache.draw_glow(canvas, center, (46.0 + pulse * 6.0) * visual_scale, SHIELD_BLUE, 0.10 * alpha)
	canvas.draw_colored_polygon(halo_points, Color(SHIELD_BLUE.r, SHIELD_BLUE.g, SHIELD_BLUE.b, 0.075 * alpha))
	canvas.draw_polyline(halo_points, Color(SHIELD_BLUE.r, SHIELD_BLUE.g, SHIELD_BLUE.b, 0.22 * alpha), OUTER_GLOW_LINE_WIDTH * visual_scale, true)
	canvas.draw_colored_polygon(points, Color(SHIELD_SHADOW.r, SHIELD_SHADOW.g, SHIELD_SHADOW.b, 0.48 * alpha))
	canvas.draw_colored_polygon(bevel_points, Color(SHIELD_DEEP.r, SHIELD_DEEP.g, SHIELD_DEEP.b, 0.62 * alpha))
	_draw_panel_facets(canvas, center, c, s, alpha, visual_scale)
	_draw_circuit_lines(canvas, center, c, s, alpha, pulse, visual_scale)

	var inner_points: PackedVector2Array = _build_rotated_points(SHIELD_INNER_POINTS, center, rotation, visual_scale)
	canvas.draw_polyline(points, Color(SHIELD_BLUE.r, SHIELD_BLUE.g, SHIELD_BLUE.b, 0.92 * alpha), OUTER_BEVEL_LINE_WIDTH * visual_scale, true)
	canvas.draw_polyline(points, Color(SHIELD_CORE.r, SHIELD_CORE.g, SHIELD_CORE.b, (0.70 + pulse * 0.18) * alpha), 1.45 * visual_scale, true)
	canvas.draw_polyline(bevel_points, Color(SHIELD_PANEL.r, SHIELD_PANEL.g, SHIELD_PANEL.b, 0.34 * alpha), 1.2 * visual_scale, true)
	canvas.draw_polyline(inner_points, Color(SHIELD_CORE.r, SHIELD_CORE.g, SHIELD_CORE.b, 0.54 * alpha), 1.35 * visual_scale, true)
	_draw_corner_nodes(canvas, points, center, alpha, pulse, visual_scale)
	_draw_center_core(canvas, center, c, s, alpha, pulse, visual_scale)


func _draw_hit_effects(canvas: CanvasItem, effects: Array, shake_offset: Vector2) -> void:
	for effect in effects:
		if not (effect is Dictionary):
			continue
		var age: float = float(effect.get("age", 0.0))
		var life: float = max(0.01, float(effect.get("life", 0.32)))
		var t: float = clamp(age / life, 0.0, 1.0)
		var alpha: float = 1.0 - t
		var pos: Vector2 = _as_vector2(effect.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var radius: float = 20.0 + 74.0 * t
		ImpactFlareTextureCache.draw_burst(
			canvas,
			pos,
			radius * 1.35,
			SHIELD_BLUE,
			0.30 * alpha
		)
		ImpactFlareTextureCache.draw_glow(
			canvas,
			pos,
			radius * 0.85,
			SHIELD_BLUE,
			0.24 * alpha
		)
		ImpactShockwaveTextureCache.draw_full_ring(
			canvas,
			pos,
			radius,
			SHIELD_BLUE,
			0.56 * alpha
		)
		ImpactShockwaveTextureCache.draw_full_ring(
			canvas,
			pos,
			radius * 0.62,
			SHIELD_CORE,
			0.38 * alpha
		)
		ImpactFlareTextureCache.draw_sparkle(
			canvas,
			pos,
			max(26.0, radius * 0.42),
			SHIELD_CORE,
			0.62 * alpha
		)
		var shards: Array = _as_array(effect.get("shards", []))
		var shard_count: int = min(shards.size(), MAX_RENDERED_HIT_SHARDS)
		for shard_index in range(shard_count):
			var shard: Variant = shards[shard_index]
			if not (shard is Dictionary):
				continue
			var shard_pos: Vector2 = _as_vector2(shard.get("pos", pos), pos) + shake_offset
			var vel: Vector2 = _as_vector2(shard.get("vel", Vector2.ZERO), Vector2.ZERO)
			var end_pos: Vector2 = shard_pos + vel.normalized() * max(5.0, float(shard.get("length", 14.0))) if vel.length_squared() > 0.001 else shard_pos
			var color: Color = SHIELD_CORE.lerp(PLASMA_GOLD, float(shard.get("warmth", 0.0)))
			canvas.draw_line(shard_pos, end_pos, Color(color.r, color.g, color.b, 0.82 * alpha), max(1.0, float(shard.get("width", 2.0)) * alpha), true)


func _draw_panel_facets(canvas: CanvasItem, center: Vector2, c: float, s: float, alpha: float, visual_scale: float) -> void:
	var rotation := Vector2(c, s)
	var outer: Array[Vector2] = []
	var inner: Array[Vector2] = []
	for point in SHIELD_BASE_POINTS:
		outer.append(center + _rotate_cached(point * 0.86 * visual_scale, c, s))
		inner.append(center + _rotate_cached(point * 0.38 * visual_scale, c, s))
	for index in range(outer.size()):
		var next_index: int = (index + 1) % outer.size()
		var shade: float = 0.78 + 0.22 * sin(float(index) * 1.73)
		var panel_color := Color(
			SHIELD_PANEL.r * shade,
			SHIELD_PANEL.g * shade,
			SHIELD_PANEL.b,
			0.13 * alpha
		)
		var facet := PackedVector2Array([
			inner[index],
			outer[index],
			outer[next_index],
			inner[next_index],
		])
		canvas.draw_colored_polygon(facet, panel_color)
		canvas.draw_line(inner[index], outer[index], Color(SHIELD_CORE.r, SHIELD_CORE.g, SHIELD_CORE.b, 0.18 * alpha), 1.0 * visual_scale, true)
	canvas.draw_colored_polygon(
		_build_rotated_points(SHIELD_INNER_POINTS, center, rotation, 0.72 * visual_scale),
		Color(SHIELD_BLUE.r, SHIELD_BLUE.g, SHIELD_BLUE.b, 0.20 * alpha)
	)


func _draw_circuit_lines(canvas: CanvasItem, center: Vector2, c: float, s: float, alpha: float, pulse: float, visual_scale: float) -> void:
	var paths: Array[Array] = [
		[Vector2(0.0, -7.0), Vector2(0.0, -19.0), Vector2(7.0, -24.0)],
		[Vector2(0.0, -7.0), Vector2(0.0, -19.0), Vector2(-7.0, -24.0)],
		[Vector2(8.0, -1.0), Vector2(18.0, -3.0), Vector2(23.0, -9.0)],
		[Vector2(8.0, 8.0), Vector2(17.0, 15.0), Vector2(15.0, 23.0)],
		[Vector2(0.0, 10.0), Vector2(0.0, 21.0), Vector2(7.0, 25.0)],
		[Vector2(0.0, 10.0), Vector2(0.0, 21.0), Vector2(-7.0, 25.0)],
		[Vector2(-8.0, 8.0), Vector2(-17.0, 15.0), Vector2(-15.0, 23.0)],
		[Vector2(-8.0, -1.0), Vector2(-18.0, -3.0), Vector2(-23.0, -9.0)],
	]
	var line_color := Color(SHIELD_CORE.r, SHIELD_CORE.g, SHIELD_CORE.b, (0.30 + pulse * 0.14) * alpha)
	var node_color := Color(SHIELD_BLUE.r, SHIELD_BLUE.g, SHIELD_BLUE.b, 0.40 * alpha)
	for path in paths:
		for segment_index in range(path.size() - 1):
			var local_a: Vector2 = path[segment_index]
			var local_b: Vector2 = path[segment_index + 1]
			var a: Vector2 = center + _rotate_cached(local_a * visual_scale, c, s)
			var b: Vector2 = center + _rotate_cached(local_b * visual_scale, c, s)
			canvas.draw_line(a, b, line_color, 0.9 * visual_scale, true)
		var local_node: Vector2 = path[path.size() - 1]
		var node: Vector2 = center + _rotate_cached(local_node * visual_scale, c, s)
		canvas.draw_circle(node, 1.6 * visual_scale, node_color)
		canvas.draw_circle(node, 0.7 * visual_scale, Color(SHIELD_CORE.r, SHIELD_CORE.g, SHIELD_CORE.b, 0.72 * alpha))


func _draw_corner_nodes(canvas: CanvasItem, points: PackedVector2Array, center: Vector2, alpha: float, pulse: float, visual_scale: float) -> void:
	for index in range(points.size()):
		var point: Vector2 = points[index]
		var outward: Vector2 = (point - center).normalized()
		var tangent := Vector2(-outward.y, outward.x)
		canvas.draw_circle(point, (4.2 + pulse * 0.8) * visual_scale, Color(SHIELD_BLUE.r, SHIELD_BLUE.g, SHIELD_BLUE.b, 0.24 * alpha))
		canvas.draw_circle(point, 1.9 * visual_scale, Color(SHIELD_CORE.r, SHIELD_CORE.g, SHIELD_CORE.b, 0.88 * alpha))
		if alpha < 0.45:
			continue
		var arc_a: Vector2 = point + outward * (5.0 + pulse * 2.0) * visual_scale
		var arc_b: Vector2 = arc_a + tangent * (6.0 if index % 2 == 0 else -6.0) * visual_scale + outward * 4.0 * visual_scale
		var arc_c: Vector2 = arc_b + tangent * (-4.5 if index % 2 == 0 else 4.5) * visual_scale + outward * 5.0 * visual_scale
		canvas.draw_line(point, arc_a, Color(SHIELD_CORE.r, SHIELD_CORE.g, SHIELD_CORE.b, 0.44 * alpha), 1.0 * visual_scale, true)
		canvas.draw_line(arc_a, arc_b, Color(SHIELD_BLUE.r, SHIELD_BLUE.g, SHIELD_BLUE.b, 0.34 * alpha), 0.9 * visual_scale, true)
		canvas.draw_line(arc_b, arc_c, Color(SHIELD_VIOLET.r, SHIELD_VIOLET.g, SHIELD_VIOLET.b, 0.28 * alpha), 0.8 * visual_scale, true)


func _draw_center_core(canvas: CanvasItem, center: Vector2, c: float, s: float, alpha: float, pulse: float, visual_scale: float) -> void:
	var core_points: PackedVector2Array = _build_rotated_points(SHIELD_INNER_POINTS, center, Vector2(c, s), (0.34 + pulse * 0.03) * visual_scale)
	canvas.draw_colored_polygon(core_points, Color(SHIELD_CORE.r, SHIELD_CORE.g, SHIELD_CORE.b, 0.18 * alpha))
	canvas.draw_polyline(core_points, Color(SHIELD_CORE.r, SHIELD_CORE.g, SHIELD_CORE.b, 0.62 * alpha), 1.0 * visual_scale, true)
	ImpactFlareTextureCache.draw_glow(canvas, center, (13.0 + pulse * 3.0) * visual_scale, SHIELD_CORE, 0.16 * alpha)
	ImpactFlareTextureCache.draw_sparkle(canvas, center, (7.0 + pulse * 2.0) * visual_scale, SHIELD_CORE, 0.52 * alpha)


func _rotate_cached(value: Vector2, c: float, s: float) -> Vector2:
	return Vector2(value.x * c - value.y * s, value.x * s + value.y * c)


func _build_rotated_points(source_points: Array[Vector2], center: Vector2, rotation: Vector2, scale: float = 1.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	var c: float = rotation.x
	var s: float = rotation.y
	for point in source_points:
		points.append(center + _rotate_cached(point * scale, c, s))
	return points


func get_asset_status() -> Dictionary:
	return {
		"shield_kiting_render_mode": SHIELD_RENDER_MODE,
		"shield_kiting_uses_imagegen_texture": false,
		"shield_kiting_projectile_png_slot": false,
		"shield_kiting_projectile_points": SHIELD_BASE_POINTS.size(),
		"shield_kiting_inner_panel_points": SHIELD_INNER_POINTS.size(),
		"shield_kiting_circuit_paths": CIRCUIT_PATH_COUNT,
		"shield_kiting_projectile_visual_scale": PROJECTILE_VISUAL_SCALE,
		"shield_kiting_outer_glow_line_width": OUTER_GLOW_LINE_WIDTH,
	}


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
