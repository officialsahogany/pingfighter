extends RefCounted

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const WEATHER_RENDER_PARTICLE_LIMIT := 72
const WIND_RENDER_PARTICLE_LIMIT := 32
const FIRE_RENDER_PARTICLE_LIMIT := 48
const FIRE_DETAILED_EXPLOSION_RENDER_LIMIT := 8
const FIRE_DETAILED_SPARK_RENDER_LIMIT := 8
const FIRE_OVERLAY_HEAT_LINE_COUNT := 4
const LOD_ACTIVE_THRESHOLD := 0.99
const SEVERE_LOD_ACTIVE_THRESHOLD := 0.66
const WEATHER_RENDER_PARTICLE_LIMIT_LOD := 36
const WEATHER_RENDER_PARTICLE_LIMIT_SEVERE_LOD := 24
# Wind is the cheapest weather effect (one textured rect per particle), so keep it
# near-full even under render LOD. Decimating wind to ~12 made the flow read as a few
# blinking streaks ("뚝뚝 끊김") for no measurable perf gain.
const WIND_RENDER_PARTICLE_LIMIT_LOD := 32
const WIND_RENDER_PARTICLE_LIMIT_SEVERE_LOD := 28
const FIRE_RENDER_PARTICLE_LIMIT_LOD := 24
const FIRE_RENDER_PARTICLE_LIMIT_SEVERE_LOD := 18
const FIRE_DETAILED_EXPLOSION_RENDER_LIMIT_LOD := 3
const FIRE_DETAILED_EXPLOSION_RENDER_LIMIT_SEVERE_LOD := 1
const FIRE_DETAILED_SPARK_RENDER_LIMIT_LOD := 3
const FIRE_DETAILED_SPARK_RENDER_LIMIT_SEVERE_LOD := 1
const FIRE_OVERLAY_HEAT_LINE_COUNT_LOD := 1
const FIRE_OVERLAY_HEAT_LINE_COUNT_SEVERE_LOD := 1
const ICE_OVERLAY_LINE_COUNT := 10
const ICE_OVERLAY_LINE_COUNT_LOD := 4
const ICE_OVERLAY_LINE_COUNT_SEVERE_LOD := 2
const PARTICLE_RENDER_STRIDE_LOD := 2
const PARTICLE_RENDER_STRIDE_SEVERE_LOD := 3
const SAND_POLYGON_STRIDE_LOD := 3
const SAND_POLYGON_STRIDE_SEVERE_LOD := 5
const SAND_RENDER_SEGMENT_BUCKET_SIZE := 4
const SAND_RENDER_SEGMENT_LIMIT_PER_SIDE := 18
const SAND_VERTICAL_START := 60.0
const SAND_HORIZONTAL_START := 40.0
const SAND_SEG_SIZE := 12.0
const SAND_BASE_COLOR := Color(0.804, 0.686, 0.451, 1.0)
const SAND_DARK_COLOR := Color(0.686, 0.580, 0.353, 1.0)
const SAND_OUTLINE_COLOR := Color(0.608, 0.510, 0.314, 1.0)
const SAND_HIGHLIGHT_COLOR := Color(0.902, 0.804, 0.588, 1.0)
const PREWARM_TEXTURE_KEYS := [
	"rain_streak",
	"wind_ribbon",
	"fire_ember",
	"hail_core",
	"ice_glint",
	"sand_grain",
	"message_scanline",
]

var _texture_cache: Dictionary = {}
var _prewarm_texture_index := 0


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if _prewarm_texture_index >= PREWARM_TEXTURE_KEYS.size():
		_prewarm_texture_index = 0
		return true
	_get_texture(str(PREWARM_TEXTURE_KEYS[_prewarm_texture_index]))
	_prewarm_texture_index += 1
	if _prewarm_texture_index >= PREWARM_TEXTURE_KEYS.size():
		_prewarm_texture_index = 0
		return true
	return false


func draw(weather: Object, canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO, effect_lod_scale: float = 1.0) -> void:
	if weather == null or canvas == null:
		return
	var context: Dictionary = _get_weather_context(weather)
	_draw_field_overlay(canvas, context, shake_offset, effect_lod_scale)
	_draw_sand_segments(weather, canvas, shake_offset, effect_lod_scale)
	_draw_particles(weather, canvas, shake_offset, effect_lod_scale)
	_draw_weather_message(canvas, context)


func build_visual_snapshot(weather: Object) -> Dictionary:
	var context: Dictionary = _get_weather_context(weather)
	var particles: Array = _get_particles(weather)
	var render_limit: int = _get_render_particle_limit(context)
	var sand_segments: Array = _get_sand_segments(weather)
	return {
		"type": str(context.get("type", "")),
		"active": bool(context.get("active", false)),
		"particle_count": particles.size(),
		"rendered_particle_count": min(particles.size(), render_limit),
		"render_particle_limit": render_limit,
		"fire_render_particle_limit": FIRE_RENDER_PARTICLE_LIMIT,
		"fire_detailed_explosion_render_limit": FIRE_DETAILED_EXPLOSION_RENDER_LIMIT,
		"fire_detailed_spark_render_limit": FIRE_DETAILED_SPARK_RENDER_LIMIT,
		"sand_segment_count": sand_segments.size(),
		"sand_draw_segment_count": _count_sand_draw_segments(sand_segments),
		"sand_render_segment_bucket_size": SAND_RENDER_SEGMENT_BUCKET_SIZE,
		"sand_render_segment_limit_per_side": SAND_RENDER_SEGMENT_LIMIT_PER_SIDE,
		"has_message": str(context.get("warning_text", context.get("end_text", ""))) != "",
	}


func _draw_field_overlay(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2, effect_lod_scale: float = 1.0) -> void:
	var weather_type: String = str(context.get("type", ""))
	if weather_type == "":
		return
	var rect: Rect2 = Rect2(shake_offset, Vector2(FIELD_WIDTH, FIELD_HEIGHT))
	match weather_type:
		"fire":
			canvas.draw_rect(rect, Color(1.0, 0.19, 0.04, 0.055))
			var heat_line_count: int = _get_lod_count(
				FIRE_OVERLAY_HEAT_LINE_COUNT,
				FIRE_OVERLAY_HEAT_LINE_COUNT_LOD,
				FIRE_OVERLAY_HEAT_LINE_COUNT_SEVERE_LOD,
				effect_lod_scale
			)
			for idx in range(heat_line_count):
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
			var ice_line_count: int = _get_lod_count(
				ICE_OVERLAY_LINE_COUNT,
				ICE_OVERLAY_LINE_COUNT_LOD,
				ICE_OVERLAY_LINE_COUNT_SEVERE_LOD,
				effect_lod_scale
			)
			for idx in range(ice_line_count):
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


func _draw_sand_segments(weather: Object, canvas: CanvasItem, shake_offset: Vector2, effect_lod_scale: float = 1.0) -> void:
	var depths_by_side: Dictionary = _collect_sand_wall_depths(weather)
	if depths_by_side.is_empty():
		return
	var dissolve_alpha: float = _get_sand_dissolve_alpha(weather)
	if dissolve_alpha <= 0.005:
		return
	for side_value in ["left", "right", "top", "bottom"]:
		var side := str(side_value)
		if not depths_by_side.has(side):
			continue
		var depths: Array = depths_by_side[side]
		if depths.is_empty():
			continue
		_draw_sand_wall_polygon(canvas, side, depths, shake_offset, dissolve_alpha, effect_lod_scale)


func _collect_sand_wall_depths(weather: Object) -> Dictionary:
	if weather == null:
		return {}
	if weather.has_method("get_sand_wall_depth_arrays"):
		var value: Variant = weather.get_sand_wall_depth_arrays()
		if value is Dictionary:
			return value
	return {}


func _get_sand_dissolve_alpha(weather: Object) -> float:
	if weather == null:
		return 1.0
	if weather.has_method("get_sand_dissolve_alpha"):
		return clamp(float(weather.get_sand_dissolve_alpha()), 0.0, 1.0)
	return 1.0


func _draw_sand_wall_polygon(
	canvas: CanvasItem,
	side: String,
	depths: Array,
	shake_offset: Vector2,
	dissolve_alpha: float,
	effect_lod_scale: float = 1.0
) -> void:
	var seg_count: int = depths.size()
	if seg_count <= 0:
		return
	var axis_start: float = SAND_VERTICAL_START if side == "left" or side == "right" else SAND_HORIZONTAL_START
	var span_end: float = axis_start + float(seg_count) * SAND_SEG_SIZE
	var stride: int = _get_sand_polygon_stride(effect_lod_scale)
	var sampled_indices: Array[int] = []
	for index in range(0, seg_count, stride):
		sampled_indices.append(index)
	if sampled_indices.is_empty() or sampled_indices[sampled_indices.size() - 1] != seg_count - 1:
		sampled_indices.append(seg_count - 1)
	var points: PackedVector2Array = PackedVector2Array()
	points.resize(sampled_indices.size() + 2)
	var has_visible := false
	match side:
		"left":
			points[0] = Vector2(0.0, axis_start) + shake_offset
			for sample_index in range(sampled_indices.size()):
				var index: int = sampled_indices[sample_index]
				var d: float = max(0.0, float(depths[index]))
				if d > 0.5:
					has_visible = true
				var y: float = axis_start + float(index) * SAND_SEG_SIZE + SAND_SEG_SIZE * 0.5
				points[sample_index + 1] = Vector2(d, y) + shake_offset
			points[sampled_indices.size() + 1] = Vector2(0.0, span_end) + shake_offset
		"right":
			points[0] = Vector2(FIELD_WIDTH, axis_start) + shake_offset
			for sample_index in range(sampled_indices.size()):
				var index: int = sampled_indices[sample_index]
				var d: float = max(0.0, float(depths[index]))
				if d > 0.5:
					has_visible = true
				var y: float = axis_start + float(index) * SAND_SEG_SIZE + SAND_SEG_SIZE * 0.5
				points[sample_index + 1] = Vector2(FIELD_WIDTH - d, y) + shake_offset
			points[sampled_indices.size() + 1] = Vector2(FIELD_WIDTH, span_end) + shake_offset
		"top":
			points[0] = Vector2(axis_start, 0.0) + shake_offset
			for sample_index in range(sampled_indices.size()):
				var index: int = sampled_indices[sample_index]
				var d: float = max(0.0, float(depths[index]))
				if d > 0.5:
					has_visible = true
				var x: float = axis_start + float(index) * SAND_SEG_SIZE + SAND_SEG_SIZE * 0.5
				points[sample_index + 1] = Vector2(x, d) + shake_offset
			points[sampled_indices.size() + 1] = Vector2(span_end, 0.0) + shake_offset
		_:
			points[0] = Vector2(axis_start, FIELD_HEIGHT) + shake_offset
			for sample_index in range(sampled_indices.size()):
				var index: int = sampled_indices[sample_index]
				var d: float = max(0.0, float(depths[index]))
				if d > 0.5:
					has_visible = true
				var x: float = axis_start + float(index) * SAND_SEG_SIZE + SAND_SEG_SIZE * 0.5
				points[sample_index + 1] = Vector2(x, FIELD_HEIGHT - d) + shake_offset
			points[sampled_indices.size() + 1] = Vector2(span_end, FIELD_HEIGHT) + shake_offset

	if not has_visible:
		return

	var fill_color := Color(SAND_BASE_COLOR.r, SAND_BASE_COLOR.g, SAND_BASE_COLOR.b, 0.92 * dissolve_alpha)
	canvas.draw_colored_polygon(points, fill_color)

	if not _is_severe_lod_active(effect_lod_scale):
		# Inner shadow band along the wall side to give depth read.
		var shadow_polygon: PackedVector2Array = _build_sand_shadow_polygon(side, points)
		if shadow_polygon.size() >= 3:
			var shadow_color := Color(SAND_DARK_COLOR.r, SAND_DARK_COLOR.g, SAND_DARK_COLOR.b, 0.42 * dissolve_alpha)
			canvas.draw_colored_polygon(shadow_polygon, shadow_color)

	# Outline only along the visible silhouette (skip the closing wall edges).
	var outline_points: PackedVector2Array = PackedVector2Array()
	outline_points.resize(sampled_indices.size())
	for index in range(sampled_indices.size()):
		outline_points[index] = points[index + 1]
	if outline_points.size() >= 2:
		var outline_color := Color(SAND_OUTLINE_COLOR.r, SAND_OUTLINE_COLOR.g, SAND_OUTLINE_COLOR.b, 0.82 * dissolve_alpha)
		canvas.draw_polyline(outline_points, outline_color, 1.4, true)

	if not _is_severe_lod_active(effect_lod_scale):
		# Crest highlight: skim a slightly inset bright ribbon along peaks for an organic dune feel.
		var highlight_points: PackedVector2Array = _build_sand_highlight_polyline(side, depths, shake_offset, axis_start, effect_lod_scale)
		if highlight_points.size() >= 2:
			var highlight_color := Color(SAND_HIGHLIGHT_COLOR.r, SAND_HIGHLIGHT_COLOR.g, SAND_HIGHLIGHT_COLOR.b, 0.42 * dissolve_alpha)
			canvas.draw_polyline(highlight_points, highlight_color, 1.0, true)


func _build_sand_shadow_polygon(side: String, surface_points: PackedVector2Array) -> PackedVector2Array:
	if surface_points.size() < 4:
		return PackedVector2Array()
	var inset: float = 4.0
	var result: PackedVector2Array = PackedVector2Array()
	# Walk the silhouette (skipping the wall closure endpoints) and offset slightly inward to form a thin band.
	for index in range(1, surface_points.size() - 1):
		result.append(surface_points[index])
	var inset_count: int = result.size()
	for back_index in range(inset_count - 1, -1, -1):
		var p: Vector2 = result[back_index]
		match side:
			"left":
				p.x = max(0.0, p.x - inset)
			"right":
				p.x = min(FIELD_WIDTH, p.x + inset)
			"top":
				p.y = max(0.0, p.y - inset)
			_:
				p.y = min(FIELD_HEIGHT, p.y + inset)
		result.append(p)
	return result


func _build_sand_highlight_polyline(side: String, depths: Array, shake_offset: Vector2, axis_start: float, effect_lod_scale: float = 1.0) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	var inset: float = 2.0
	var stride: int = _get_sand_polygon_stride(effect_lod_scale)
	for index in range(0, depths.size(), stride):
		var d: float = max(0.0, float(depths[index]))
		if d <= 6.0:
			# Only highlight reasonably tall peaks so we don't draw a long line through flat zones.
			if not result.is_empty():
				# Break the polyline by starting a new ribbon next time.
				pass
			continue
		var pos := Vector2.ZERO
		var axis_along: float = axis_start + float(index) * SAND_SEG_SIZE + SAND_SEG_SIZE * 0.5
		match side:
			"left":
				pos = Vector2(max(0.0, d - inset), axis_along)
			"right":
				pos = Vector2(min(FIELD_WIDTH, FIELD_WIDTH - d + inset), axis_along)
			"top":
				pos = Vector2(axis_along, max(0.0, d - inset))
			_:
				pos = Vector2(axis_along, min(FIELD_HEIGHT, FIELD_HEIGHT - d + inset))
		result.append(pos + shake_offset)
	return result


func _draw_particles(weather: Object, canvas: CanvasItem, shake_offset: Vector2, effect_lod_scale: float = 1.0) -> void:
	var particles: Array = _get_particles(weather)
	var context: Dictionary = _get_weather_context(weather)
	var particle_start: int = max(0, particles.size() - _get_render_particle_limit(context, effect_lod_scale))
	var particle_stride: int = _get_particle_render_stride_for_context(context, effect_lod_scale)
	var fire_explosion_drawn := 0
	var fire_spark_drawn := 0
	for particle_index in range(particle_start, particles.size()):
		if particle_stride > 1 and (particle_index - particle_start) % particle_stride != 0:
			continue
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
					fire_explosion_drawn <= _get_detailed_render_limit(
						FIRE_DETAILED_EXPLOSION_RENDER_LIMIT,
						FIRE_DETAILED_EXPLOSION_RENDER_LIMIT_LOD,
						FIRE_DETAILED_EXPLOSION_RENDER_LIMIT_SEVERE_LOD,
						effect_lod_scale
					)
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
					fire_spark_drawn <= _get_detailed_render_limit(
						FIRE_DETAILED_SPARK_RENDER_LIMIT,
						FIRE_DETAILED_SPARK_RENDER_LIMIT_LOD,
						FIRE_DETAILED_SPARK_RENDER_LIMIT_SEVERE_LOD,
						effect_lod_scale
					)
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


func _get_render_particle_limit(context: Dictionary, effect_lod_scale: float = 1.0) -> int:
	var weather_type: String = str(context.get("type", ""))
	if weather_type == "fire":
		return _get_lod_count(FIRE_RENDER_PARTICLE_LIMIT, FIRE_RENDER_PARTICLE_LIMIT_LOD, FIRE_RENDER_PARTICLE_LIMIT_SEVERE_LOD, effect_lod_scale)
	if weather_type == "breeze" or weather_type == "gust":
		return _get_lod_count(WIND_RENDER_PARTICLE_LIMIT, WIND_RENDER_PARTICLE_LIMIT_LOD, WIND_RENDER_PARTICLE_LIMIT_SEVERE_LOD, effect_lod_scale)
	return _get_lod_count(WEATHER_RENDER_PARTICLE_LIMIT, WEATHER_RENDER_PARTICLE_LIMIT_LOD, WEATHER_RENDER_PARTICLE_LIMIT_SEVERE_LOD, effect_lod_scale)


func _get_detailed_render_limit(base_count: int, lod_count: int, severe_lod_count: int, effect_lod_scale: float) -> int:
	return _get_lod_count(base_count, lod_count, severe_lod_count, effect_lod_scale)


func _get_particle_render_stride(effect_lod_scale: float) -> int:
	if _is_severe_lod_active(effect_lod_scale):
		return PARTICLE_RENDER_STRIDE_SEVERE_LOD
	if _is_lod_active(effect_lod_scale):
		return PARTICLE_RENDER_STRIDE_LOD
	return 1


func _get_particle_render_stride_for_context(context: Dictionary, effect_lod_scale: float) -> int:
	var weather_type: String = str(context.get("type", ""))
	if weather_type == "breeze" or weather_type == "gust":
		# Index-based stride drops a different subset of particles each frame as wind
		# ribbons spawn and expire, so the sparse wind flow visibly flickers. Wind is
		# cheap enough to always render every particle (no stride decimation).
		return 1
	return _get_particle_render_stride(effect_lod_scale)


func _get_sand_polygon_stride(effect_lod_scale: float) -> int:
	if _is_severe_lod_active(effect_lod_scale):
		return SAND_POLYGON_STRIDE_SEVERE_LOD
	if _is_lod_active(effect_lod_scale):
		return SAND_POLYGON_STRIDE_LOD
	return 1


func _get_lod_count(base_count: int, lod_count: int, severe_lod_count: int, effect_lod_scale: float) -> int:
	if base_count <= 0:
		return 0
	if _is_severe_lod_active(effect_lod_scale):
		return clampi(severe_lod_count, 0, base_count)
	if _is_lod_active(effect_lod_scale):
		return clampi(lod_count, 0, base_count)
	return base_count


func _is_lod_active(effect_lod_scale: float) -> bool:
	return effect_lod_scale < LOD_ACTIVE_THRESHOLD


func _is_severe_lod_active(effect_lod_scale: float) -> bool:
	return effect_lod_scale <= SEVERE_LOD_ACTIVE_THRESHOLD


func _get_sand_segments(weather: Object) -> Array:
	if weather != null and weather.has_method("get_sand_visual_segments"):
		var segments: Variant = weather.get_sand_visual_segments()
		if segments is Array:
			return segments
	return []


func _count_sand_draw_segments(segments: Array) -> int:
	# Polygon renderer coalesces every visible segment on a wall into a single draw call,
	# so the visible draw-segment count is the number of sides that contain any depth.
	var sides_with_content: Dictionary = {}
	for value in segments:
		var segment: Dictionary = _get_dict(value)
		var side: String = str(segment.get("side", ""))
		if side == "" or sides_with_content.has(side):
			continue
		var rect: Rect2 = _get_rect2(segment.get("rect", Rect2()), Rect2())
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		sides_with_content[side] = true
	return sides_with_content.size()


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
