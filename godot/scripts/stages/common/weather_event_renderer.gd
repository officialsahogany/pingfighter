extends RefCounted

const WeatherEventRenderBudget := preload("res://scripts/stages/common/weather_event_render_budget.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const WEATHER_RENDER_PARTICLE_LIMIT := WeatherEventRenderBudget.WEATHER_RENDER_PARTICLE_LIMIT
const WIND_RENDER_PARTICLE_LIMIT := WeatherEventRenderBudget.WIND_RENDER_PARTICLE_LIMIT
const FIRE_RENDER_PARTICLE_LIMIT := 48
const FIRE_DETAILED_EXPLOSION_RENDER_LIMIT := 8
const FIRE_DETAILED_SPARK_RENDER_LIMIT := 8
const FIRE_OVERLAY_HEAT_LINE_COUNT := 4
const LOD_ACTIVE_THRESHOLD := WeatherEventRenderBudget.LOD_ACTIVE_THRESHOLD
const SEVERE_LOD_ACTIVE_THRESHOLD := WeatherEventRenderBudget.SEVERE_LOD_ACTIVE_THRESHOLD
const WEATHER_RENDER_PARTICLE_LIMIT_LOD := WeatherEventRenderBudget.WEATHER_RENDER_PARTICLE_LIMIT_LOD
const WEATHER_RENDER_PARTICLE_LIMIT_SEVERE_LOD := WeatherEventRenderBudget.WEATHER_RENDER_PARTICLE_LIMIT_SEVERE_LOD
# Wind is the cheapest weather effect (one textured rect per particle), so keep it
# near-full even under render LOD. Decimating wind to ~12 made the flow read as a few
# blinking streaks ("뚝뚝 끊김") for no measurable perf gain.
const WIND_RENDER_PARTICLE_LIMIT_LOD := WeatherEventRenderBudget.WIND_RENDER_PARTICLE_LIMIT_LOD
const WIND_RENDER_PARTICLE_LIMIT_SEVERE_LOD := WeatherEventRenderBudget.WIND_RENDER_PARTICLE_LIMIT_SEVERE_LOD
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
const PARTICLE_RENDER_STRIDE_LOD := WeatherEventRenderBudget.PARTICLE_RENDER_STRIDE_LOD
const PARTICLE_RENDER_STRIDE_SEVERE_LOD := WeatherEventRenderBudget.PARTICLE_RENDER_STRIDE_SEVERE_LOD
const SAND_POLYGON_STRIDE_LOD := WeatherEventRenderBudget.SAND_RENDER_STRIDE_LOD
const SAND_POLYGON_STRIDE_SEVERE_LOD := WeatherEventRenderBudget.SAND_RENDER_STRIDE_SEVERE_LOD
const SAND_RENDER_SEGMENT_BUCKET_SIZE := 4
const SAND_RENDER_SEGMENT_LIMIT_PER_SIDE := 18
const SAND_VERTICAL_START := 60.0
const SAND_HORIZONTAL_START := 40.0
const SAND_SEG_SIZE := 12.0
const SAND_BASE_COLOR := Color(0.804, 0.686, 0.451, 1.0)
const SAND_DARK_COLOR := Color(0.686, 0.580, 0.353, 1.0)
const SAND_OUTLINE_COLOR := Color(0.608, 0.510, 0.314, 1.0)
const SAND_HIGHLIGHT_COLOR := Color(0.902, 0.804, 0.588, 1.0)
const SAND_WALL_TEXTURE_WIDTH := 512
const SAND_WALL_TEXTURE_HEIGHT := 48
# Wall-base vertices sit this far outside the field line so a fully eroded column
# never collapses crest/base into coincident points (keeps the strip triangulable).
const SAND_WALL_BASE_OUTSET := 0.5
const SAND_CREST_JITTER_PX := 1.6
const SAND_SHADOW_MIN_DEPTH := 6.0
const PREWARM_TEXTURE_KEYS := [
	"rain_streak",
	"wind_ribbon",
	"fire_ember",
	"hail_core",
	"ice_glint",
	"sand_grain",
	"sand_wall",
	"message_scanline",
]

# Every generated texture here is deterministic (hash-based, no RNG), so bakes are
# shared process-wide: repeat stage entries and the PSO prewarmer's own renderer
# instance must not re-pay the sand_wall bake (~120ms) on a loading tick.
static var _shared_texture_cache: Dictionary = {}

var _texture_cache: Dictionary = {}
var _prewarm_texture_index := 0


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_wind_assets() -> void:
	_get_texture("wind_ribbon")


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


func draw_wind_particles(
	weather: Object,
	canvas: CanvasItem,
	shake_offset: Vector2 = Vector2.ZERO,
	effect_lod_scale: float = 1.0,
	clip_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(FIELD_WIDTH, FIELD_HEIGHT))
) -> int:
	if weather == null or canvas == null:
		return 0
	var context: Dictionary = _get_weather_context(weather)
	var weather_type: String = str(context.get("type", ""))
	if weather_type != "breeze" and weather_type != "gust":
		return 0
	var particles: Array = _get_particles(weather)
	var rendered_count: int = mini(particles.size(), _get_render_particle_limit(
		context,
		effect_lod_scale
	))
	_draw_particles(weather, canvas, shake_offset, effect_lod_scale, clip_rect)
	return rendered_count


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
	var span_length: float = max(1.0, span_end - axis_start)
	var stride: int = _get_sand_polygon_stride(effect_lod_scale)
	var sampled_indices: Array[int] = []
	for index in range(0, seg_count, stride):
		sampled_indices.append(index)
	if sampled_indices.is_empty() or sampled_indices[sampled_indices.size() - 1] != seg_count - 1:
		sampled_indices.append(seg_count - 1)
	var sample_count: int = sampled_indices.size()
	var side_salt: int = _get_sand_side_salt(side)
	# Corner-closed silhouette keeps feeding the shadow band / outline like before.
	var points: PackedVector2Array = PackedVector2Array()
	points.resize(sample_count + 2)
	# Crest->base strip carries per-column UV anchors so the granular fill keeps its
	# light-crest / dark-base gradient after triangulation (GRT-033: UVs stay in [0,1]).
	var strip_points: PackedVector2Array = PackedVector2Array()
	strip_points.resize(sample_count * 2)
	var strip_uvs: PackedVector2Array = PackedVector2Array()
	strip_uvs.resize(sample_count * 2)
	var has_visible := false
	for sample_index in range(sample_count):
		var index: int = sampled_indices[sample_index]
		var d: float = max(0.0, float(depths[index]))
		if d > 0.5:
			has_visible = true
			# Deterministic sub-pixel crest jitter keeps the ridge organic without RNG.
			d = max(0.5, d + (_bake_hash01(index * 7349 + side_salt) - 0.5) * SAND_CREST_JITTER_PX)
		var along: float = axis_start + float(index) * SAND_SEG_SIZE + SAND_SEG_SIZE * 0.5
		var u: float = clampf((along - axis_start) / span_length, 0.0, 1.0)
		var crest := Vector2.ZERO
		var base := Vector2.ZERO
		match side:
			"left":
				crest = Vector2(d, along)
				base = Vector2(-SAND_WALL_BASE_OUTSET, along)
			"right":
				crest = Vector2(FIELD_WIDTH - d, along)
				base = Vector2(FIELD_WIDTH + SAND_WALL_BASE_OUTSET, along)
			"top":
				crest = Vector2(along, d)
				base = Vector2(along, -SAND_WALL_BASE_OUTSET)
			_:
				crest = Vector2(along, FIELD_HEIGHT - d)
				base = Vector2(along, FIELD_HEIGHT + SAND_WALL_BASE_OUTSET)
		points[sample_index + 1] = crest + shake_offset
		strip_points[sample_index] = crest + shake_offset
		strip_uvs[sample_index] = Vector2(u, 0.0)
		strip_points[sample_count * 2 - 1 - sample_index] = base + shake_offset
		strip_uvs[sample_count * 2 - 1 - sample_index] = Vector2(u, 1.0)
	match side:
		"left":
			points[0] = Vector2(0.0, axis_start) + shake_offset
			points[sample_count + 1] = Vector2(0.0, span_end) + shake_offset
		"right":
			points[0] = Vector2(FIELD_WIDTH, axis_start) + shake_offset
			points[sample_count + 1] = Vector2(FIELD_WIDTH, span_end) + shake_offset
		"top":
			points[0] = Vector2(axis_start, 0.0) + shake_offset
			points[sample_count + 1] = Vector2(span_end, 0.0) + shake_offset
		_:
			points[0] = Vector2(axis_start, FIELD_HEIGHT) + shake_offset
			points[sample_count + 1] = Vector2(span_end, FIELD_HEIGHT) + shake_offset

	if not has_visible:
		return

	# Explicit per-column triangle pairs: ear-clipping the whole wall strip re-anchors
	# UVs onto far-away columns and erases the crest->base gradient (and can fail on
	# eroded valleys, GRT-006). Fixed topology needs no runtime triangulation at all.
	var sand_texture: Texture2D = _get_texture("sand_wall")
	if sand_texture != null and sample_count >= 2:
		var fill_modulate := Color(1.0, 1.0, 1.0, 0.94 * dissolve_alpha)
		var strip_colors: PackedColorArray = PackedColorArray()
		strip_colors.resize(sample_count * 2)
		strip_colors.fill(fill_modulate)
		var strip_indices: PackedInt32Array = PackedInt32Array()
		strip_indices.resize((sample_count - 1) * 6)
		for column_index in range(sample_count - 1):
			var crest_a: int = column_index
			var crest_b: int = column_index + 1
			var base_a: int = sample_count * 2 - 1 - column_index
			var base_b: int = base_a - 1
			var write: int = column_index * 6
			strip_indices[write] = crest_a
			strip_indices[write + 1] = base_a
			strip_indices[write + 2] = crest_b
			strip_indices[write + 3] = crest_b
			strip_indices[write + 4] = base_a
			strip_indices[write + 5] = base_b
		RenderingServer.canvas_item_add_triangle_array(
			canvas.get_canvas_item(),
			strip_indices,
			strip_points,
			strip_colors,
			strip_uvs,
			PackedInt32Array(),
			PackedFloat32Array(),
			sand_texture.get_rid()
		)
	else:
		var fill_color := Color(SAND_BASE_COLOR.r, SAND_BASE_COLOR.g, SAND_BASE_COLOR.b, 0.92 * dissolve_alpha)
		canvas.draw_colored_polygon(points, fill_color)

	if not _is_severe_lod_active(effect_lod_scale):
		# Inner shadow band under the crest lip keeps the dune depth read on the grain fill.
		var shadow_bands: Array[PackedVector2Array] = _build_sand_shadow_polygon(side, points, shake_offset)
		var shadow_color := Color(SAND_DARK_COLOR.r, SAND_DARK_COLOR.g, SAND_DARK_COLOR.b, 0.30 * dissolve_alpha)
		for shadow_band in shadow_bands:
			if shadow_band.size() >= 3:
				canvas.draw_colored_polygon(shadow_band, shadow_color)

	# Outline only along the visible silhouette (skip the closing wall edges).
	var outline_points: PackedVector2Array = PackedVector2Array()
	outline_points.resize(sample_count)
	for outline_index in range(sample_count):
		outline_points[outline_index] = points[outline_index + 1]
	if outline_points.size() >= 2:
		var outline_color := Color(SAND_OUTLINE_COLOR.r, SAND_OUTLINE_COLOR.g, SAND_OUTLINE_COLOR.b, 0.82 * dissolve_alpha)
		canvas.draw_polyline(outline_points, outline_color, 1.4, true)

	if not _is_severe_lod_active(effect_lod_scale):
		# Crest highlight: bright ribbons skim tall peaks; runs are split per contiguous
		# ridge so the highlight never bridges eroded gaps with a floating line.
		var highlight_runs: Array[PackedVector2Array] = _build_sand_highlight_polyline(side, depths, shake_offset, axis_start, effect_lod_scale)
		var highlight_color := Color(SAND_HIGHLIGHT_COLOR.r, SAND_HIGHLIGHT_COLOR.g, SAND_HIGHLIGHT_COLOR.b, 0.40 * dissolve_alpha)
		for highlight_run in highlight_runs:
			if highlight_run.size() >= 2:
				canvas.draw_polyline(highlight_run, highlight_color, 1.0, true)


func _build_sand_shadow_polygon(side: String, surface_points: PackedVector2Array, shake_offset: Vector2) -> Array[PackedVector2Array]:
	# One band per contiguous tall ridge: a single band spanning eroded zero-depth
	# valleys collapses crest onto wall points and fails triangulation (GRT-006 spam).
	var bands: Array[PackedVector2Array] = []
	if surface_points.size() < 4:
		return bands
	var inset: float = 4.0
	var current_run: PackedVector2Array = PackedVector2Array()
	for index in range(1, surface_points.size() - 1):
		var point: Vector2 = surface_points[index]
		if _get_sand_point_depth(side, point, shake_offset) <= SAND_SHADOW_MIN_DEPTH:
			_append_sand_shadow_band(bands, current_run, side, inset)
			current_run = PackedVector2Array()
			continue
		current_run.append(point)
	_append_sand_shadow_band(bands, current_run, side, inset)
	return bands


func _append_sand_shadow_band(bands: Array[PackedVector2Array], run_points: PackedVector2Array, side: String, inset: float) -> void:
	if run_points.size() < 2:
		return
	var run_size: int = run_points.size()
	var band: PackedVector2Array = PackedVector2Array()
	band.resize(run_size * 2)
	for index in range(run_size):
		band[index] = run_points[index]
		var p: Vector2 = run_points[index]
		match side:
			"left":
				p.x = max(0.0, p.x - inset)
			"right":
				p.x = min(FIELD_WIDTH, p.x + inset)
			"top":
				p.y = max(0.0, p.y - inset)
			_:
				p.y = min(FIELD_HEIGHT, p.y + inset)
		band[run_size * 2 - 1 - index] = p
	# GRT-006: decorative band must never reach the renderer as an untriangulable polygon.
	if Geometry2D.triangulate_polygon(band).is_empty():
		return
	bands.append(band)


func _get_sand_point_depth(side: String, point: Vector2, shake_offset: Vector2) -> float:
	match side:
		"left":
			return point.x - shake_offset.x
		"right":
			return FIELD_WIDTH - (point.x - shake_offset.x)
		"top":
			return point.y - shake_offset.y
	return FIELD_HEIGHT - (point.y - shake_offset.y)


func _build_sand_highlight_polyline(side: String, depths: Array, shake_offset: Vector2, axis_start: float, effect_lod_scale: float = 1.0) -> Array[PackedVector2Array]:
	var runs: Array[PackedVector2Array] = []
	var current_run: PackedVector2Array = PackedVector2Array()
	var inset: float = 2.0
	var stride: int = _get_sand_polygon_stride(effect_lod_scale)
	for index in range(0, depths.size(), stride):
		var d: float = max(0.0, float(depths[index]))
		if d <= 6.0:
			# Only highlight reasonably tall peaks; close the run so eroded gaps stay unlit.
			if current_run.size() >= 2:
				runs.append(current_run)
			current_run = PackedVector2Array()
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
		current_run.append(pos + shake_offset)
	if current_run.size() >= 2:
		runs.append(current_run)
	return runs


func _draw_particles(
	weather: Object,
	canvas: CanvasItem,
	shake_offset: Vector2,
	effect_lod_scale: float = 1.0,
	clip_rect: Rect2 = Rect2()
) -> void:
	var particles: Array = _get_particles(weather)
	var context: Dictionary = _get_weather_context(weather)
	var weather_type: String = str(context.get("type", ""))
	var particle_start: int = max(0, particles.size() - _get_render_particle_limit(context, effect_lod_scale))
	var particle_stride: int = _get_particle_render_stride_for_context(context, effect_lod_scale)
	var fire_explosion_drawn := 0
	var fire_spark_drawn := 0
	# Iterate from 0 (not particle_start): the window/stride cutoff is deferred to the
	# shared helper so core sparse particles (falling hail stones) are never evicted by
	# a transient debris burst. See WeatherEventRenderBudget.should_skip_windowed_particle.
	for particle_index in range(0, particles.size()):
		var value: Variant = particles[particle_index]
		var particle: Dictionary = _get_dict(value)
		var kind: String = str(particle.get("kind", "wind"))
		if WeatherEventRenderBudget.should_skip_windowed_particle(
			weather_type, kind, particle_index, particle_start, particle_stride
		):
			continue
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
				var sand_size: float = max(3.0, float(particle.get("size", 3.0)) * 2.4)
				var grain_hash: float = _get_particle_variation_hash(particle)
				var grain_tone: float = 0.78 + grain_hash * 0.44
				var grain_color := Color(
					clampf(color.r * grain_tone, 0.0, 1.0),
					clampf(color.g * grain_tone, 0.0, 1.0),
					clampf(color.b * grain_tone, 0.0, 1.0),
					color.a
				)
				_draw_texture_piece(canvas, "sand_grain", pos, Vector2(sand_size, sand_size), grain_color)
				# Trailing fleck breaks the single-quad read into a scattered grain puff.
				var fleck_offset := Vector2(
					(grain_hash - 0.5) * sand_size * 1.7,
					(fposmod(grain_hash * 7.31, 1.0) - 0.5) * sand_size * 1.7
				)
				_draw_texture_piece(
					canvas,
					"sand_grain",
					pos + fleck_offset,
					Vector2(sand_size, sand_size) * 0.55,
					Color(grain_color.r, grain_color.g, grain_color.b, grain_color.a * 0.72)
				)
			_:
				var width: float = max(18.0, abs(float(particle.get("vx", 0.0))) * 8.0 + 14.0)
				var wind_size := Vector2(
					width,
					max(3.0, float(particle.get("size", 2.0)) * 2.0)
				)
				if clip_rect.size.x > 0.0 and clip_rect.size.y > 0.0:
					_draw_texture_piece_clipped(
						canvas,
						"wind_ribbon",
						pos,
						wind_size,
						color,
						clip_rect
					)
				else:
					_draw_texture_piece(canvas, "wind_ribbon", pos, wind_size, color)


func _draw_texture_piece(canvas: CanvasItem, texture_key: String, center: Vector2, size: Vector2, color: Color) -> void:
	var texture: Texture2D = _get_texture(texture_key)
	if texture == null:
		return
	var rect: Rect2 = Rect2(center - size * 0.5, size)
	canvas.draw_texture_rect(texture, rect, false, color)


func _draw_texture_piece_clipped(
	canvas: CanvasItem,
	texture_key: String,
	center: Vector2,
	size: Vector2,
	color: Color,
	clip_rect: Rect2
) -> void:
	var texture := _get_texture(texture_key)
	if texture == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var target_rect := Rect2(center - size * 0.5, size)
	var clipped_rect := target_rect.intersection(clip_rect)
	if clipped_rect.size.x <= 0.0 or clipped_rect.size.y <= 0.0:
		return
	var source_size := Vector2(texture.get_size())
	var source_rect := Rect2(
		(clipped_rect.position - target_rect.position) / target_rect.size * source_size,
		clipped_rect.size / target_rect.size * source_size
	)
	canvas.draw_texture_rect_region(texture, clipped_rect, source_rect, color)


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
	if _shared_texture_cache.has(key):
		var shared_texture: Texture2D = _shared_texture_cache[key]
		_texture_cache[key] = shared_texture
		return shared_texture
	var texture: Texture2D = _build_texture(key)
	_texture_cache[key] = texture
	_shared_texture_cache[key] = texture
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
			return _make_sand_grain_cluster_texture(24)
		"sand_wall":
			return _make_sand_wall_texture(SAND_WALL_TEXTURE_WIDTH, SAND_WALL_TEXTURE_HEIGHT)
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


# Deterministic hash/noise for baked sand art: no global RNG draw, stable across boots.
func _bake_hash01(n: int) -> float:
	var h: int = (n * 374761393 + 668265263) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0


func _bake_value_noise(x: float, y: float, cell_x: float, cell_y: float, salt: int) -> float:
	var cx: float = x / max(0.001, cell_x)
	var cy: float = y / max(0.001, cell_y)
	var x0: int = int(floor(cx))
	var y0: int = int(floor(cy))
	var fx: float = cx - float(x0)
	var fy: float = cy - float(y0)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var n00: float = _bake_hash01(x0 * 73856093 + y0 * 19349663 + salt)
	var n10: float = _bake_hash01((x0 + 1) * 73856093 + y0 * 19349663 + salt)
	var n01: float = _bake_hash01(x0 * 73856093 + (y0 + 1) * 19349663 + salt)
	var n11: float = _bake_hash01((x0 + 1) * 73856093 + (y0 + 1) * 19349663 + salt)
	return lerpf(lerpf(n00, n10, fx), lerpf(n01, n11, fx), fy)


func _get_sand_side_salt(side: String) -> int:
	match side:
		"left":
			return 11
		"right":
			return 23
		"top":
			return 37
	return 53


func _get_particle_variation_hash(particle: Dictionary) -> float:
	# Stable per particle (spawn-time fields), unlike the array index which shifts
	# as sibling particles die and the array compacts.
	return fposmod(
		float(particle.get("size", 3.0)) * 91.17 + float(particle.get("max_life", 30.0)) * 13.31,
		1.0
	)


func _make_sand_wall_texture(width: int, height: int) -> Texture2D:
	var image: Image = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	var crest_color := Color(0.918, 0.822, 0.604, 1.0)
	var mid_color := SAND_BASE_COLOR
	var base_color := Color(0.648, 0.527, 0.331, 1.0)
	for y in range(height):
		var v: float = float(y) / max(1.0, float(height - 1))
		var ramp: Color
		if v < 0.5:
			ramp = crest_color.lerp(mid_color, v / 0.5)
		else:
			ramp = mid_color.lerp(base_color, (v - 0.5) / 0.5)
		for x in range(width):
			# The wall band is stretched far more along u than v at runtime, so the noise
			# cells are anisotropic here to come out roughly isotropic in world pixels.
			var fine: float = _bake_value_noise(float(x), float(y), 2.2, 5.5, 11)
			var clump: float = _bake_value_noise(float(x), float(y), 7.5, 19.0, 47)
			var band: float = _bake_value_noise(float(x), float(y), 23.0, 48.0, 89)
			var tone: float = 0.96 + (fine - 0.5) * 0.20 + (clump - 0.5) * 0.14 + (band - 0.5) * 0.10
			var pixel := Color(
				clampf(ramp.r * tone, 0.0, 1.0),
				clampf(ramp.g * tone, 0.0, 1.0),
				clampf(ramp.b * tone, 0.0, 1.0),
				1.0
			)
			var dark_roll: float = _bake_hash01(x * 977 + y * 331 + 7)
			var light_roll: float = _bake_hash01(x * 613 + y * 769 + 91)
			if dark_roll < 0.035:
				pixel = pixel.lerp(Color(0.36, 0.27, 0.16, 1.0), 0.62)
			elif light_roll < 0.05 * (0.35 + 0.65 * (1.0 - v)):
				pixel = pixel.lerp(Color(0.995, 0.936, 0.762, 1.0), 0.68)
			image.set_pixel(x, y, pixel)
	return ImageTexture.create_from_image(image)


func _make_sand_grain_cluster_texture(size: int) -> Texture2D:
	var image: Image = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var center: float = float(size - 1) * 0.5
	var palette: Array[Color] = [
		Color(0.933, 0.827, 0.588, 1.0),
		Color(0.855, 0.722, 0.459, 1.0),
		Color(0.749, 0.604, 0.361, 1.0),
		Color(0.584, 0.451, 0.263, 1.0),
	]
	for grain_index in range(6):
		var angle: float = _bake_hash01(grain_index * 611 + 3) * TAU
		var orbit: float = sqrt(_bake_hash01(grain_index * 421 + 17)) * center * 0.62
		var grain_center := Vector2(center + cos(angle) * orbit, center + sin(angle) * orbit)
		var grain_radius: float = 1.7 + _bake_hash01(grain_index * 233 + 29) * 1.8
		var grain_color: Color = palette[int(_bake_hash01(grain_index * 149 + 41) * 3.999)]
		var min_x: int = max(0, int(floor(grain_center.x - grain_radius)) - 1)
		var max_x: int = min(size - 1, int(ceil(grain_center.x + grain_radius)) + 1)
		var min_y: int = max(0, int(floor(grain_center.y - grain_radius)) - 1)
		var max_y: int = min(size - 1, int(ceil(grain_center.y + grain_radius)) + 1)
		for py in range(min_y, max_y + 1):
			for px in range(min_x, max_x + 1):
				var dist: float = Vector2(float(px), float(py)).distance_to(grain_center)
				if dist > grain_radius:
					continue
				# Light falls from the top-left so each grain reads as a lit speck, not a flat dot.
				var shade: float = clampf(
					1.04 - ((float(px) - grain_center.x) + (float(py) - grain_center.y)) / max(1.0, grain_radius) * 0.14,
					0.66,
					1.12
				)
				var edge: float = clampf(1.0 - (dist / max(0.001, grain_radius) - 0.72) / 0.28, 0.0, 1.0)
				image.set_pixel(px, py, Color(
					clampf(grain_color.r * shade, 0.0, 1.0),
					clampf(grain_color.g * shade, 0.0, 1.0),
					clampf(grain_color.b * shade, 0.0, 1.0),
					clampf(0.55 + 0.45 * edge, 0.0, 1.0)
				))
	for fleck_index in range(10):
		var fleck_x: int = int(_bake_hash01(fleck_index * 97 + 5) * float(size - 1))
		var fleck_y: int = int(_bake_hash01(fleck_index * 71 + 9) * float(size - 1))
		if image.get_pixel(fleck_x, fleck_y).a > 0.0:
			continue
		var fleck_color: Color = palette[fleck_index % palette.size()]
		image.set_pixel(fleck_x, fleck_y, Color(fleck_color.r, fleck_color.g, fleck_color.b, 0.5))
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
		return WeatherEventRenderBudget.get_lod_count(
			FIRE_RENDER_PARTICLE_LIMIT,
			FIRE_RENDER_PARTICLE_LIMIT_LOD,
			FIRE_RENDER_PARTICLE_LIMIT_SEVERE_LOD,
			effect_lod_scale
		)
	return WeatherEventRenderBudget.get_weather_particle_limit(weather_type, effect_lod_scale)


func _get_detailed_render_limit(base_count: int, lod_count: int, severe_lod_count: int, effect_lod_scale: float) -> int:
	return WeatherEventRenderBudget.get_lod_count(base_count, lod_count, severe_lod_count, effect_lod_scale)


func _get_particle_render_stride(effect_lod_scale: float) -> int:
	return WeatherEventRenderBudget.get_particle_render_stride(effect_lod_scale)


func _get_particle_render_stride_for_context(context: Dictionary, effect_lod_scale: float) -> int:
	return WeatherEventRenderBudget.get_particle_render_stride_for_context(context, effect_lod_scale)


func _get_sand_polygon_stride(effect_lod_scale: float) -> int:
	return WeatherEventRenderBudget.get_sand_render_stride(effect_lod_scale)


func _get_lod_count(base_count: int, lod_count: int, severe_lod_count: int, effect_lod_scale: float) -> int:
	return WeatherEventRenderBudget.get_lod_count(base_count, lod_count, severe_lod_count, effect_lod_scale)


func _is_lod_active(effect_lod_scale: float) -> bool:
	return WeatherEventRenderBudget.is_lod_active(effect_lod_scale)


func _is_severe_lod_active(effect_lod_scale: float) -> bool:
	return WeatherEventRenderBudget.is_severe_lod_active(effect_lod_scale)


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
