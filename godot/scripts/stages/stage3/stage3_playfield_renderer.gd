extends RefCounted

const BattleRenderQuality := preload("res://scripts/core/battle_render_quality.gd")

const TILE_SIZE := 50
const BORDER_THICKNESS := 10.0
const HEART_PARTICLE_LIMIT := 34
const HEART_PARTICLE_DRAW_LIMIT_LOD := 24
const HEART_PARTICLE_DRAW_LIMIT_SEVERE_LOD := 18
const HEART_SPAWN_CHANCE_PER_60FPS := 0.010
const STADIUM_SPARK_MIN_INTERVAL_SEC := 12.0
const STADIUM_SPARK_MAX_INTERVAL_SEC := 25.0
const STADIUM_SPARK_BURST_SEC := 0.85
const DEFAULT_CACHE_WIDTH := 760
const DEFAULT_CACHE_HEIGHT := 750
const DEFAULT_PREWARM_STEP_COUNT := 7
const MAX_CHECKER_TEXTURE_CACHE_ENTRIES := 9
const MAX_BORDER_TEXTURE_CACHE_ENTRIES := 9
const MAX_ELLIPSE_POINTS_CACHE_ENTRIES := 128
const MAX_ELLIPSE_OUTLINE_POINTS_CACHE_ENTRIES := 128
const STADIUM_CIRCLE_SEGMENTS := 96
const STADIUM_CIRCLE_SEGMENTS_LOD := 72
const STADIUM_CIRCLE_SEGMENTS_SEVERE_LOD := 64
const STADIUM_INNER_SEGMENTS := 96
const STADIUM_INNER_SEGMENTS_LOD := 72
const STADIUM_INNER_SEGMENTS_SEVERE_LOD := 64
const STADIUM_FLOW_ARC_SEGMENTS := 22
const STADIUM_FLOW_ARC_SEGMENTS_LOD := 18
const STADIUM_FLOW_ARC_SEGMENTS_SEVERE_LOD := 14
const STADIUM_DASH_LENGTH := 20
const STADIUM_GAP_LENGTH := 15
const STADIUM_DASH_LENGTH_SEVERE_LOD := 20
const STADIUM_GAP_LENGTH_SEVERE_LOD := 15
const KUROMI_SHADOW_LAYERS := 10
const KUROMI_SHADOW_LAYERS_LOD := 10
const KUROMI_SHADOW_LAYERS_SEVERE_LOD := 8
const KUROMI_FACE_LAYER_COUNT := 5
const KUROMI_FACE_LAYER_COUNT_LOD := 5
const KUROMI_FACE_LAYER_COUNT_SEVERE_LOD := 4
const KUROMI_EAR_LAYER_COUNT := 5
const KUROMI_EAR_LAYER_COUNT_LOD := 5
const KUROMI_EAR_LAYER_COUNT_SEVERE_LOD := 4
const KUROMI_TONGUE_POINT_MIN := 18
const KUROMI_TONGUE_POINT_MAX := 42
const KUROMI_TONGUE_POINT_MAX_LOD := 34
const KUROMI_TONGUE_POINT_MAX_SEVERE_LOD := 28
const KUROMI_IDLE_TAIL_POINT_COUNT := 20
const KUROMI_IDLE_TAIL_POINT_COUNT_LOD := 20
const KUROMI_IDLE_TAIL_POINT_COUNT_SEVERE_LOD := 16
const KUROMI_PETRIFIED_TAIL_POINT_COUNT := 10
const KUROMI_PETRIFIED_TAIL_POINT_COUNT_LOD := 10
const KUROMI_PETRIFIED_TAIL_POINT_COUNT_SEVERE_LOD := 8
const KUROMI_AWAKENING_RING_SEGMENTS := 54
const KUROMI_AWAKENING_RING_SEGMENTS_LOD := 44
const KUROMI_AWAKENING_RING_SEGMENTS_SEVERE_LOD := 36
const KUROMI_AWAKENING_CRACK_LINE_COUNT := 5
const KUROMI_AWAKENING_CRACK_LINE_COUNT_LOD := 5
const KUROMI_AWAKENING_CRACK_LINE_COUNT_SEVERE_LOD := 4
const KUROMI_TONGUE_COIL_SEGMENTS := 24
const KUROMI_TONGUE_COIL_SEGMENTS_LOD := 20
const KUROMI_TONGUE_COIL_SEGMENTS_SEVERE_LOD := 16
const KUROMI_TONGUE_WRAP_ARC_SEGMENTS := 28
const KUROMI_TONGUE_WRAP_ARC_SEGMENTS_LOD := 24
const KUROMI_TONGUE_WRAP_ARC_SEGMENTS_SEVERE_LOD := 20
const KUROMI_AWAKE_SPARKLE_COUNT := 5
const KUROMI_AWAKE_SPARKLE_COUNT_LOD := 5
const KUROMI_AWAKE_SPARKLE_COUNT_SEVERE_LOD := 4
const KUROMI_SPIT_WARNING_MARK_COUNT := 4
const KUROMI_SPIT_WARNING_MARK_COUNT_LOD := 3
const KUROMI_SPIT_WARNING_MARK_COUNT_SEVERE_LOD := 2
const KUROMI_SPIT_WARNING_LINE_LENGTH := 166.0
const KUROMI_SPIT_WARNING_GLOW_WIDTH := 8.0
const KUROMI_SPIT_WARNING_CORE_WIDTH := 3.2
const KUROMI_CRACK_PARTICLE_DRAW_LIMIT := 36
const KUROMI_CRACK_PARTICLE_DRAW_LIMIT_LOD := 22
const KUROMI_CRACK_PARTICLE_DRAW_LIMIT_SEVERE_LOD := 10
const KUROMI_CRACK_PARTICLE_DETAILED_DRAW_LIMIT := 10
const KUROMI_CRACK_PARTICLE_DETAILED_DRAW_LIMIT_LOD := 6
const KUROMI_CRACK_PARTICLE_DETAILED_DRAW_LIMIT_SEVERE_LOD := 2
const KUROMI_CRACK_PARTICLE_SIMPLE_SIZE_THRESHOLD := 8.0
const KUROMI_SEVERE_RESTORE_QUALITY_SCALE := 0.84

const PASTEL_PINK := Color(1.0, 182.0 / 255.0, 193.0 / 255.0, 1.0)
const LAVENDER := Color(230.0 / 255.0, 190.0 / 255.0, 1.0, 1.0)
const BABY_BLUE := Color(137.0 / 255.0, 207.0 / 255.0, 240.0 / 255.0, 1.0)
const CRIMSON := Color(220.0 / 255.0, 20.0 / 255.0, 60.0 / 255.0, 1.0)
const WHITE := Color.WHITE
const SOFT_BLACK := Color(60.0 / 255.0, 60.0 / 255.0, 60.0 / 255.0, 1.0)
const STONE := Color(150.0 / 255.0, 150.0 / 255.0, 150.0 / 255.0, 1.0)
const STONE_DARK := Color(95.0 / 255.0, 95.0 / 255.0, 98.0 / 255.0, 1.0)
const STONE_LIGHT := Color(198.0 / 255.0, 198.0 / 255.0, 202.0 / 255.0, 1.0)

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var last_update_msec: int = 0
var time_sec: float = 0.0
var emotional_phase: int = 0
var heart_particles: Array = []
var stadium_spark_next_time: float = STADIUM_SPARK_MIN_INTERVAL_SEC
var stadium_spark_active_start: float = -1.0
var stadium_spark_cycle_index: int = 0
var stadium_spark_direction: float = 1.0
var checker_texture_cache: Dictionary = {}
var border_texture_cache: Dictionary = {}
var ellipse_unit_point_cache: Dictionary = {}
var ellipse_points_cache: Dictionary = {}
var ellipse_outline_points_cache: Dictionary = {}
var _prewarm_assets_done: bool = false
var _prewarm_step_index: int = 0
var _active_quality_scale: float = 1.0


func _init() -> void:
	rng.seed = 3303
	reset()


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if _prewarm_assets_done:
		return true
	if _prewarm_step_index < 6:
		@warning_ignore("integer_division")
		var phase: int = int(_prewarm_step_index / 2)
		if _prewarm_step_index % 2 == 0:
			_get_checker_texture(DEFAULT_CACHE_WIDTH, DEFAULT_CACHE_HEIGHT, phase)
		else:
			_get_border_texture(DEFAULT_CACHE_WIDTH, DEFAULT_CACHE_HEIGHT, phase)
	else:
		_prewarm_stadium_geometry(DEFAULT_CACHE_WIDTH, DEFAULT_CACHE_HEIGHT)
	_prewarm_step_index += 1
	if _prewarm_step_index >= DEFAULT_PREWARM_STEP_COUNT:
		_prewarm_assets_done = true
		_prewarm_step_index = 0
		return true
	return false


func reset() -> void:
	last_update_msec = 0
	time_sec = 0.0
	emotional_phase = 0
	heart_particles.clear()
	stadium_spark_next_time = rng.randf_range(STADIUM_SPARK_MIN_INTERVAL_SEC, STADIUM_SPARK_MAX_INTERVAL_SEC)
	stadium_spark_active_start = -1.0
	stadium_spark_cycle_index = 0
	stadium_spark_direction = 1.0
	for _idx in range(4):
		heart_particles.append(_make_heart_particle(760.0, 750.0, true))


func draw(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2, perf_logger: Object = null) -> void:
	if canvas == null:
		return
	var sample_start: int = _perf_begin(perf_logger)
	var width: float = float(context.get("width", 760.0))
	var height: float = float(context.get("height", 750.0))
	if width <= 0.0 or height <= 0.0:
		return
	var quality_scale: float = _get_playfield_quality_scale(context)
	_active_quality_scale = quality_scale
	var delta: float = _tick_delta()
	_sync_phase(context)
	_update_particles(delta, width, height)
	_perf_end(perf_logger, "stage3.playfield.prepare", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_background_pattern(canvas, width, height)
	_perf_end(perf_logger, "stage3.playfield.background", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_particles(canvas, shake_offset, quality_scale)
	_perf_end(perf_logger, "stage3.playfield.hearts", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_stadium_line(canvas, context, width, height, shake_offset, perf_logger, quality_scale)
	_perf_end(perf_logger, "stage3.playfield.stadium", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_kuromi_crack_particles(canvas, context, shake_offset, quality_scale)
	_perf_end(perf_logger, "stage3.playfield.crack_particles", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_border(canvas, width, height, shake_offset)
	_perf_end(perf_logger, "stage3.playfield.border", sample_start)


func _tick_delta() -> float:
	var now: int = Time.get_ticks_msec()
	if last_update_msec <= 0:
		last_update_msec = now
		return 1.0 / 60.0
	var delta: float = clampf(float(now - last_update_msec) / 1000.0, 0.0, 0.05)
	last_update_msec = now
	if delta <= 0.0:
		delta = 1.0 / 60.0
	time_sec += delta
	return delta


func _sync_phase(context: Dictionary) -> void:
	var phase_value: Variant = context.get("stage3_emotional_phase", null)
	if phase_value != null:
		emotional_phase = wrapi(int(phase_value), 0, 3)


func _update_particles(delta: float, width: float, height: float) -> void:
	var fps_scale: float = delta * 60.0
	if rng.randf() < HEART_SPAWN_CHANCE_PER_60FPS * fps_scale and heart_particles.size() < HEART_PARTICLE_LIMIT:
		heart_particles.append(_make_heart_particle(width, height, false))
	var write_idx: int = 0
	for idx in range(heart_particles.size()):
		var particle: Dictionary = heart_particles[idx]
		particle["x"] = float(particle.get("x", 0.0)) + float(particle.get("vx", 0.0)) * fps_scale
		particle["y"] = float(particle.get("y", 0.0)) + float(particle.get("vy", 0.0)) * fps_scale
		particle["life"] = float(particle.get("life", 0.0)) - fps_scale
		particle["twinkle"] = float(particle.get("twinkle", 0.0)) + 0.12 * fps_scale
		if float(particle.get("life", 0.0)) <= 0.0:
			continue
		heart_particles[write_idx] = particle
		write_idx += 1
	heart_particles.resize(write_idx)


func _make_heart_particle(width: float, height: float, initial: bool) -> Dictionary:
	return {
		"x": rng.randf_range(70.0, maxf(71.0, width - 70.0)),
		"y": rng.randf_range(90.0, maxf(91.0, height - 90.0)) if initial else height + 22.0,
		"vx": rng.randf_range(-0.30, 0.30),
		"vy": rng.randf_range(-1.50, -0.70),
		"size": rng.randi_range(8, 17),
		"broken": emotional_phase == 2 or rng.randf() < 0.30,
		"color_index": rng.randi_range(0, 2),
		"life": rng.randf_range(210.0, 420.0) if initial else rng.randf_range(260.0, 560.0),
		"twinkle": rng.randf_range(0.0, TAU),
	}


func _draw_background_pattern(canvas: CanvasItem, width: float, height: float) -> void:
	var cache_width: int = maxi(1, int(ceil(width)))
	var cache_height: int = maxi(1, int(ceil(height)))
	var texture: Texture2D = _get_checker_texture(cache_width, cache_height, emotional_phase)
	if texture != null:
		canvas.draw_texture_rect(texture, Rect2(0.0, 0.0, width, height), false)


func get_performance_snapshot() -> Dictionary:
	return {
		"checker_texture_cache_count": checker_texture_cache.size(),
		"border_texture_cache_count": border_texture_cache.size(),
		"ellipse_points_cache_count": ellipse_points_cache.size(),
		"ellipse_outline_points_cache_count": ellipse_outline_points_cache.size(),
		"heart_particle_limit": HEART_PARTICLE_LIMIT,
		"stadium_circle_segments": STADIUM_CIRCLE_SEGMENTS,
		"stadium_inner_segments": STADIUM_INNER_SEGMENTS,
		"stadium_flow_arc_segments": STADIUM_FLOW_ARC_SEGMENTS,
		"kuromi_shadow_layers": KUROMI_SHADOW_LAYERS,
		"kuromi_face_layer_count": KUROMI_FACE_LAYER_COUNT,
		"kuromi_ear_layer_count": KUROMI_EAR_LAYER_COUNT,
		"kuromi_tongue_point_max": KUROMI_TONGUE_POINT_MAX,
		"kuromi_idle_tail_point_count": KUROMI_IDLE_TAIL_POINT_COUNT,
		"kuromi_petrified_tail_point_count": KUROMI_PETRIFIED_TAIL_POINT_COUNT,
		"kuromi_awakening_ring_segments": KUROMI_AWAKENING_RING_SEGMENTS,
		"kuromi_awakening_crack_line_count": KUROMI_AWAKENING_CRACK_LINE_COUNT,
		"kuromi_spit_warning_mark_count": KUROMI_SPIT_WARNING_MARK_COUNT,
		"kuromi_spit_warning_line_length": KUROMI_SPIT_WARNING_LINE_LENGTH,
		"kuromi_spit_warning_core_width": KUROMI_SPIT_WARNING_CORE_WIDTH,
		"kuromi_spit_warning_contrast_stroke": true,
		"kuromi_crack_particle_draw_limit": KUROMI_CRACK_PARTICLE_DRAW_LIMIT,
		"kuromi_crack_particle_detailed_draw_limit": KUROMI_CRACK_PARTICLE_DETAILED_DRAW_LIMIT,
		"kuromi_crack_particle_polygon_guard": true,
		"viper_airborne_lod_supported": true,
		"heart_particle_draw_limit_lod": HEART_PARTICLE_DRAW_LIMIT_LOD,
		"heart_particle_draw_limit_severe_lod": HEART_PARTICLE_DRAW_LIMIT_SEVERE_LOD,
		"stadium_circle_segments_lod": STADIUM_CIRCLE_SEGMENTS_LOD,
		"stadium_circle_segments_severe_lod": STADIUM_CIRCLE_SEGMENTS_SEVERE_LOD,
		"stadium_dash_length_severe_lod": STADIUM_DASH_LENGTH_SEVERE_LOD,
		"stadium_gap_length_severe_lod": STADIUM_GAP_LENGTH_SEVERE_LOD,
		"stadium_severe_lod_skips_inner_arc": false,
		"stadium_severe_lod_skips_flow": false,
		"kuromi_tongue_point_max_lod": KUROMI_TONGUE_POINT_MAX_LOD,
		"kuromi_tongue_point_max_severe_lod": KUROMI_TONGUE_POINT_MAX_SEVERE_LOD,
		"kuromi_crack_particle_draw_limit_lod": KUROMI_CRACK_PARTICLE_DRAW_LIMIT_LOD,
		"kuromi_crack_particle_draw_limit_severe_lod": KUROMI_CRACK_PARTICLE_DRAW_LIMIT_SEVERE_LOD,
		"kuromi_crack_particle_detailed_draw_limit_lod": KUROMI_CRACK_PARTICLE_DETAILED_DRAW_LIMIT_LOD,
		"kuromi_crack_particle_detailed_draw_limit_severe_lod": KUROMI_CRACK_PARTICLE_DETAILED_DRAW_LIMIT_SEVERE_LOD,
		"shared_render_quality_lod_supported": true,
		"kuromi_severe_lod_simplified": true,
		"kuromi_severe_lod_restored": true,
		"kuromi_severe_lod_restore_quality_scale": KUROMI_SEVERE_RESTORE_QUALITY_SCALE,
	}


func _prewarm_stadium_geometry(width: float, height: float) -> void:
	var center := Vector2(width * 0.5, height * 0.5)
	var head_size: float = 60.0 * 0.6
	var face_rect := Rect2(center.x - head_size, center.y - head_size + 8.0, head_size * 2.0, head_size * 1.9)
	_ellipse_points(face_rect, 18)
	_ellipse_outline_points(face_rect, 18)
	_ellipse_points(face_rect.grow(-2.0), 18)
	_ellipse_points(face_rect.grow(-3.0), 18)
	for idx in range(5):
		var offset: float = float(idx) * 2.0
		_ellipse_points(Rect2(face_rect.position + Vector2(offset, offset), face_rect.size - Vector2(offset * 2.0, offset * 2.0)), 18)

	var eye_y: float = center.y - head_size * 0.1
	var eye_spacing: float = head_size / 2.2
	var eye_width: float = head_size * 0.5
	var eye_height: float = head_size * 0.6
	var pupil_width: float = eye_width * 0.3
	var pupil_height: float = eye_height * 0.35
	for side in [-1.0, 1.0]:
		var eye_rect := Rect2(center.x + side * eye_spacing - eye_width * 0.5, eye_y - eye_height * 0.5, eye_width, eye_height)
		_ellipse_points(eye_rect, 18)
		_ellipse_outline_points(eye_rect, 18)
		_ellipse_points(eye_rect.grow(-2.0), 20)
		_ellipse_points(eye_rect.grow(-3.0), 18)
		var pupil_rect := Rect2(center.x + side * eye_spacing - pupil_width * 0.5, eye_y - pupil_height * 0.5 + 2.0, pupil_width, pupil_height)
		_ellipse_points(pupil_rect, 18)

	var mouth_y: float = center.y + head_size * 0.43
	_ellipse_points(Rect2(center.x - head_size / 5.0, mouth_y - 5.0, head_size / 5.0, 15.0), 14)
	_ellipse_points(Rect2(center.x, mouth_y - 5.0, head_size / 5.0, 15.0), 14)


func _get_checker_texture(width: int, height: int, phase: int) -> Texture2D:
	var safe_width: int = maxi(1, width)
	var safe_height: int = maxi(1, height)
	var safe_phase: int = wrapi(phase, 0, 3)
	var cache_key: String = "%d:%d:%d" % [safe_width, safe_height, safe_phase]
	var cached: Variant = checker_texture_cache.get(cache_key, null)
	if cached is Texture2D:
		return cached

	var base: Color = _get_checker_base_color_for_phase(safe_phase)
	var alternate: Color = Color(
		minf(1.0, base.r + 10.0 / 255.0),
		minf(1.0, base.g + 8.0 / 255.0),
		minf(1.0, base.b + 10.0 / 255.0),
		1.0
	)
	var outline: Color = Color(
		maxf(0.0, base.r - 5.0 / 255.0),
		maxf(0.0, base.g - 5.0 / 255.0),
		maxf(0.0, base.b - 5.0 / 255.0),
		1.0
	)
	var image: Image = Image.create(safe_width, safe_height, false, Image.FORMAT_RGBA8)
	image.fill(base)
	for x in range(0, safe_width, TILE_SIZE):
		for y in range(0, safe_height, TILE_SIZE):
			var tile_w: int = mini(TILE_SIZE, safe_width - x)
			var tile_h: int = mini(TILE_SIZE, safe_height - y)
			if tile_w <= 0 or tile_h <= 0:
				continue
			var tile_rect: Rect2i = Rect2i(x, y, tile_w, tile_h)
			@warning_ignore("integer_division")
			if (int(x / TILE_SIZE) + int(y / TILE_SIZE)) % 2 != 0:
				image.fill_rect(tile_rect, alternate)
			image.fill_rect(Rect2i(x, y, tile_w, 1), outline)
			image.fill_rect(Rect2i(x, y + tile_h - 1, tile_w, 1), outline)
			image.fill_rect(Rect2i(x, y, 1, tile_h), outline)
			image.fill_rect(Rect2i(x + tile_w - 1, y, 1, tile_h), outline)
	var texture: Texture2D = ImageTexture.create_from_image(image)
	if checker_texture_cache.size() >= MAX_CHECKER_TEXTURE_CACHE_ENTRIES:
		checker_texture_cache.clear()
	checker_texture_cache[cache_key] = texture
	return texture


func _draw_particles(canvas: CanvasItem, shake_offset: Vector2, quality_scale: float) -> void:
	var draw_limit: int = _get_lod_count(
		heart_particles.size(),
		HEART_PARTICLE_DRAW_LIMIT_LOD,
		HEART_PARTICLE_DRAW_LIMIT_SEVERE_LOD,
		quality_scale
	)
	var drawn_count: int = 0
	for particle in heart_particles:
		if drawn_count >= draw_limit:
			break
		var life: float = clampf(float(particle.get("life", 0.0)) / 600.0, 0.0, 1.0)
		if life <= 0.0:
			continue
		var color: Color = _get_particle_color(int(particle.get("color_index", 0)))
		color.a = 0.58 * life
		var pos: Vector2 = Vector2(float(particle.get("x", 0.0)), float(particle.get("y", 0.0))) + shake_offset
		var size: float = float(particle.get("size", 10.0))
		canvas.draw_circle(pos, size * 1.55, Color(color.r, color.g, color.b, 0.08 * life))
		if bool(particle.get("broken", false)):
			_draw_broken_heart(canvas, pos, size, color)
		else:
			_draw_heart(canvas, pos, size, color)
		if sin(float(particle.get("twinkle", 0.0))) > 0.72:
			_draw_star(canvas, pos + Vector2(size * 1.2, -size * 0.7), maxf(2.0, size * 0.28), Color(1.0, 1.0, 1.0, 0.55 * life))
		drawn_count += 1


func _draw_stadium_line(
	canvas: CanvasItem,
	context: Dictionary,
	width: float,
	height: float,
	shake_offset: Vector2,
	perf_logger: Object = null,
	quality_scale: float = 1.0
) -> void:
	var center: Vector2 = Vector2(width * 0.5, height * 0.5) + shake_offset
	var circle_radius: float = 120.0
	var line_color: Color = _get_emotional_color()
	var severe_lod: bool = _is_severe_lod_active(quality_scale)
	var circle_segments: int = _get_lod_count(
		STADIUM_CIRCLE_SEGMENTS,
		STADIUM_CIRCLE_SEGMENTS_LOD,
		STADIUM_CIRCLE_SEGMENTS_SEVERE_LOD,
		quality_scale
	)
	var inner_segments: int = _get_lod_count(
		STADIUM_INNER_SEGMENTS,
		STADIUM_INNER_SEGMENTS_LOD,
		STADIUM_INNER_SEGMENTS_SEVERE_LOD,
		quality_scale
	)
	var sample_start: int = _perf_begin(perf_logger)
	canvas.draw_circle(center, circle_radius, Color(1.0, 1.0, 1.0, 0.10))
	canvas.draw_arc(center, circle_radius, 0.0, TAU, circle_segments, WHITE, 3.0, true)
	canvas.draw_arc(center, circle_radius - 5.0, 0.0, TAU, circle_segments, line_color, 2.0, true)
	canvas.draw_arc(center, circle_radius - 10.0, 0.0, TAU, inner_segments, Color(LAVENDER.r, LAVENDER.g, LAVENDER.b, 0.40), 1.0, true)

	var dash_length: int = STADIUM_DASH_LENGTH_SEVERE_LOD if severe_lod else STADIUM_DASH_LENGTH
	var gap_length: int = STADIUM_GAP_LENGTH_SEVERE_LOD if severe_lod else STADIUM_GAP_LENGTH
	for x in range(0, maxi(0, int(center.x - circle_radius)), dash_length + gap_length):
		var left_end_x: float = minf(float(x + dash_length), center.x - circle_radius)
		canvas.draw_line(Vector2(float(x), center.y), Vector2(left_end_x, center.y), line_color, 3.0, true)
	for x in range(int(center.x + circle_radius), int(width), dash_length + gap_length):
		var right_end_x: float = minf(float(x + dash_length), width)
		canvas.draw_line(Vector2(float(x), center.y), Vector2(right_end_x, center.y), line_color, 3.0, true)
	_perf_end(perf_logger, "stage3.playfield.stadium_lines", sample_start)

	sample_start = _perf_begin(perf_logger)
	_draw_stadium_electric_flow(canvas, width, center, circle_radius, dash_length, gap_length, quality_scale)
	_perf_end(perf_logger, "stage3.playfield.stadium_flow", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_kuromi(canvas, context, center, 60.0, quality_scale)
	_perf_end(perf_logger, "stage3.playfield.kuromi", sample_start)


func _draw_stadium_electric_flow(
	canvas: CanvasItem,
	width: float,
	center: Vector2,
	circle_radius: float,
	dash_length: int,
	gap_length: int,
	quality_scale: float
) -> void:
	var t: float = time_sec
	if stadium_spark_active_start < 0.0:
		if t < stadium_spark_next_time:
			return
		stadium_spark_active_start = t
		stadium_spark_cycle_index += 1
		stadium_spark_direction = -1.0 if stadium_spark_cycle_index % 2 == 1 else 1.0
	var burst_time: float = t - stadium_spark_active_start
	if burst_time >= STADIUM_SPARK_BURST_SEC:
		stadium_spark_active_start = -1.0
		stadium_spark_next_time = t + rng.randf_range(STADIUM_SPARK_MIN_INTERVAL_SEC, STADIUM_SPARK_MAX_INTERVAL_SEC)
		return

	var pulse: float = burst_time / STADIUM_SPARK_BURST_SEC
	var travel: float = pulse * pulse * (3.0 - 2.0 * pulse)
	if stadium_spark_direction < 0.0:
		travel = 1.0 - travel
	var head_x: float = width * travel
	var strength: float = sin(pulse * PI)
	var tail_len: float = float(dash_length + gap_length) * 5.8
	var start_x: float = maxf(0.0, head_x - tail_len) if stadium_spark_direction > 0.0 else maxf(0.0, head_x - 7.0)
	var end_x: float = minf(width, head_x + 7.0) if stadium_spark_direction > 0.0 else minf(width, head_x + tail_len)
	if end_x > start_x:
		canvas.draw_line(Vector2(start_x, center.y), Vector2(end_x, center.y), Color(38.0 / 255.0, 214.0 / 255.0, 224.0 / 255.0, 0.16 + 0.34 * strength), 7.0, true)
		canvas.draw_line(Vector2(start_x + 2.0, center.y + 2.0), Vector2(end_x - 2.0, center.y + 2.0), Color(224.0 / 255.0, 82.0 / 255.0, 142.0 / 255.0, 0.10 + 0.20 * strength), 3.0, true)
		canvas.draw_line(Vector2(start_x + 2.0, center.y - 1.0), Vector2(end_x - 2.0, center.y - 1.0), Color(1.0, 1.0, 1.0, 0.22 + 0.42 * strength), 1.0, true)
		canvas.draw_circle(Vector2(head_x, center.y), 2.2, Color(86.0 / 255.0, 240.0 / 255.0, 246.0 / 255.0, 0.40 + 0.35 * strength))

	var circle_offset: float = absf(head_x - center.x)
	if circle_offset <= circle_radius * 1.18:
		var flow_segments: int = _get_lod_count(
			STADIUM_FLOW_ARC_SEGMENTS,
			STADIUM_FLOW_ARC_SEGMENTS_LOD,
			STADIUM_FLOW_ARC_SEGMENTS_SEVERE_LOD,
			quality_scale
		)
		var circle_progress: float = clampf((head_x - (center.x - circle_radius)) / (circle_radius * 2.0), 0.0, 1.0)
		var upper_angle: float = PI - circle_progress * PI if stadium_spark_direction > 0.0 else (1.0 - circle_progress) * PI
		var lower_angle: float = PI + circle_progress * PI if stadium_spark_direction > 0.0 else -(1.0 - circle_progress) * PI
		for angle in [upper_angle, lower_angle]:
			canvas.draw_arc(center, circle_radius, angle - 0.22, angle + 0.28, flow_segments, Color(58.0 / 255.0, 226.0 / 255.0, 236.0 / 255.0, 0.22 + 0.34 * strength), 3.0, true)
			canvas.draw_arc(center, circle_radius - 6.0, angle - 0.12, angle + 0.15, flow_segments, Color(1.0, 1.0, 1.0, 0.18 + 0.32 * strength), 1.0, true)


func _draw_kuromi(canvas: CanvasItem, context: Dictionary, center: Vector2, size: float, quality_scale: float) -> void:
	var awakening: bool = bool(context.get("stage3_kuromi_awakening", false))
	var petrified: bool = bool(context.get("stage3_kuromi_petrified", not bool(context.get("stage3_kuromi_awakened", false))))
	if awakening:
		var progress: float = clampf(float(context.get("stage3_kuromi_awakening_progress", 0.0)), 0.0, 1.0)
		center += Vector2(sin(time_sec * 58.0) * progress * 2.6, cos(time_sec * 43.0) * progress * 1.8)
	if _is_severe_lod_active(quality_scale) and not awakening and not bool(context.get("stage3_kuromi_eating_active", false)):
		_draw_kuromi_severe_lod(canvas, context, center, size, petrified)
		return
	if bool(context.get("stage3_kuromi_awakened", false)) and not petrified and not awakening:
		_draw_awake_kuromi(canvas, context, center, size, quality_scale)
	else:
		_draw_petrified_kuromi(canvas, context, center, size, quality_scale)


func _draw_kuromi_severe_lod(canvas: CanvasItem, context: Dictionary, center: Vector2, size: float, petrified: bool) -> void:
	if petrified:
		_draw_petrified_kuromi(canvas, context, center, size, KUROMI_SEVERE_RESTORE_QUALITY_SCALE)
		return
	_draw_awake_kuromi(canvas, context, center, size, KUROMI_SEVERE_RESTORE_QUALITY_SCALE)


func _draw_petrified_kuromi(canvas: CanvasItem, context: Dictionary, center: Vector2, size: float, quality_scale: float) -> void:
	var head_size: float = size * 0.6
	var stone_base := Color(120.0 / 255.0, 120.0 / 255.0, 120.0 / 255.0, 1.0)
	var stone_dark := Color(80.0 / 255.0, 80.0 / 255.0, 80.0 / 255.0, 1.0)
	var stone_light := Color(150.0 / 255.0, 150.0 / 255.0, 150.0 / 255.0, 1.0)
	var stone_crack := Color(60.0 / 255.0, 60.0 / 255.0, 60.0 / 255.0, 1.0)

	var shadow_layers: int = _get_lod_count(KUROMI_SHADOW_LAYERS, KUROMI_SHADOW_LAYERS_LOD, KUROMI_SHADOW_LAYERS_SEVERE_LOD, quality_scale)
	for i in range(shadow_layers, 0, -1):
		canvas.draw_circle(center + Vector2(0.0, 10.0), head_size + float(i) * 2.0, Color(stone_dark.r, stone_dark.g, stone_dark.b, float(i) * 5.0 / 255.0))

	var face_rect := Rect2(center.x - head_size, center.y - head_size + 8.0, head_size * 2.0, head_size * 1.9)
	_draw_ellipse(canvas, face_rect, stone_dark)
	_draw_ellipse(canvas, face_rect.grow(-2.0), stone_base)

	var ear_height: float = head_size * 1.4
	var ear_width: float = head_size * 0.5
	var left_ear_points := PackedVector2Array([
		center + Vector2(-head_size * 0.5, -head_size * 0.5 + 5.0),
		center + Vector2(-head_size * 0.5 - ear_width * 0.5, -head_size - ear_height),
		center + Vector2(-head_size * 0.25, -head_size * 0.5 + 5.0),
	])
	var right_ear_points := PackedVector2Array([
		center + Vector2(head_size * 0.5, -head_size * 0.5 + 5.0),
		center + Vector2(head_size * 0.5 + ear_width * 0.5, -head_size - ear_height),
		center + Vector2(head_size * 0.25, -head_size * 0.5 + 5.0),
	])
	canvas.draw_colored_polygon(left_ear_points, stone_dark)
	canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-head_size * 0.5 + 4.0, -head_size * 0.5 + 5.0),
		center + Vector2(-head_size * 0.5 - ear_width * 0.5 + 8.0, -head_size - ear_height + 15.0),
		center + Vector2(-head_size / 3.0, -head_size * 0.5 + 5.0),
	]), stone_base)
	canvas.draw_colored_polygon(right_ear_points, stone_dark)
	canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(head_size * 0.5 - 4.0, -head_size * 0.5 + 5.0),
		center + Vector2(head_size * 0.5 + ear_width * 0.5 - 8.0, -head_size - ear_height + 15.0),
		center + Vector2(head_size / 3.0, -head_size * 0.5 + 5.0),
	]), stone_base)

	var skull_center := Vector2(center.x, center.y - head_size - ear_height * 0.5 + 5.0)
	var skull_size: float = ear_width * 0.7
	canvas.draw_circle(skull_center, skull_size, stone_dark)
	canvas.draw_circle(skull_center, maxf(1.0, skull_size - 2.0), stone_base)

	var eye_y: float = center.y - head_size * 0.1
	var eye_spacing: float = head_size / 2.2
	var eye_width: float = head_size * 0.5
	var eye_height: float = head_size * 0.6
	var pupil_width: float = eye_width * 0.3
	var pupil_height: float = eye_height * 0.35
	for side in [-1.0, 1.0]:
		var eye_rect := Rect2(center.x + side * eye_spacing - eye_width * 0.5, eye_y - eye_height * 0.5, eye_width, eye_height)
		_draw_ellipse_outline(canvas, eye_rect, stone_dark, 2.0)
		_draw_ellipse(canvas, eye_rect.grow(-3.0), stone_light)
		var pupil_rect := Rect2(center.x + side * eye_spacing - pupil_width * 0.5, eye_y - pupil_height * 0.5 + 2.0, pupil_width, pupil_height)
		_draw_ellipse(canvas, pupil_rect, stone_dark)
		canvas.draw_circle(pupil_rect.position + Vector2(pupil_width / 3.0, pupil_height / 3.0), 3.0, Color(160.0 / 255.0, 160.0 / 255.0, 160.0 / 255.0, 1.0))

	var nose_y: float = center.y + head_size / 6.0
	canvas.draw_circle(Vector2(center.x, nose_y), 2.0, stone_dark)
	var mouth_y: float = center.y + head_size / 4.0
	canvas.draw_polyline(PackedVector2Array([
		Vector2(center.x - head_size / 6.0, mouth_y),
		Vector2(center.x - head_size / 12.0, mouth_y + 4.0),
		Vector2(center.x, mouth_y - 2.0),
		Vector2(center.x + head_size / 12.0, mouth_y + 4.0),
		Vector2(center.x + head_size / 6.0, mouth_y),
	]), stone_dark, 2.0, true)
	canvas.draw_line(Vector2(center.x, nose_y + 2.0), Vector2(center.x, mouth_y - 3.0), stone_dark, 1.0, true)

	_draw_petrified_tail(canvas, center, head_size, quality_scale)
	_draw_petrified_stone_cracks(canvas, center, head_size, stone_crack, quality_scale)
	if bool(context.get("stage3_kuromi_awakening", false)):
		_draw_kuromi_awakening_cracks(canvas, center, head_size, clampf(float(context.get("stage3_kuromi_awakening_progress", 0.0)), 0.0, 1.0), quality_scale)


func _draw_kuromi_awakening_cracks(canvas: CanvasItem, center: Vector2, head_size: float, progress: float, quality_scale: float) -> void:
	var crack_alpha: float = clampf(0.20 + progress * 0.72, 0.0, 1.0)
	var glow_alpha: float = clampf(progress * 0.38, 0.0, 0.42)
	var ring_segments: int = _get_lod_count(KUROMI_AWAKENING_RING_SEGMENTS, KUROMI_AWAKENING_RING_SEGMENTS_LOD, KUROMI_AWAKENING_RING_SEGMENTS_SEVERE_LOD, quality_scale)
	var crack_line_count: int = _get_lod_count(KUROMI_AWAKENING_CRACK_LINE_COUNT, KUROMI_AWAKENING_CRACK_LINE_COUNT_LOD, KUROMI_AWAKENING_CRACK_LINE_COUNT_SEVERE_LOD, quality_scale)
	canvas.draw_arc(center, head_size * (0.92 + progress * 0.10), -0.3, TAU - 0.3, ring_segments, Color(1.0, 1.0, 1.0, glow_alpha), 2.0 + progress * 2.0, true)
	for idx in range(crack_line_count):
		@warning_ignore("shadowed_global_identifier")
		var seed: float = float(idx) * 1.713 + floor(time_sec * 12.0) * 0.071
		var start := center + Vector2(
			sin(seed * 4.1) * head_size * 0.74,
			cos(seed * 3.7) * head_size * 0.65
		)
		var angle: float = seed * 2.9 + progress * 1.4
		var mid := start + Vector2(cos(angle), sin(angle)) * (10.0 + progress * 10.0)
		var finish := mid + Vector2(cos(angle + 0.95), sin(angle + 0.95)) * (7.0 + progress * 9.0)
		var points := PackedVector2Array([start, mid, finish])
		canvas.draw_polyline(points, Color(1.0, 1.0, 1.0, crack_alpha * 0.62), 3.0, true)
		canvas.draw_polyline(points, Color(0.20, 0.20, 0.22, 0.68), 1.2, true)


func _draw_kuromi_crack_particles(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2, quality_scale: float) -> void:
	var particles: Array = _as_array(context.get("stage3_kuromi_crack_particles", []))
	if particles.is_empty():
		return
	var draw_particles: Array = _as_array(context.get("stage3_kuromi_crack_particles_draw_order", []))
	if draw_particles.is_empty():
		draw_particles = particles.duplicate(false)
		draw_particles.sort_custom(Callable(self, "_sort_kuromi_fragment_z"))
	var total_count: int = draw_particles.size()
	var draw_step: int = 1
	var draw_limit: int = _get_lod_count(KUROMI_CRACK_PARTICLE_DRAW_LIMIT, KUROMI_CRACK_PARTICLE_DRAW_LIMIT_LOD, KUROMI_CRACK_PARTICLE_DRAW_LIMIT_SEVERE_LOD, quality_scale)
	if total_count > draw_limit:
		draw_step = maxi(1, int(ceil(float(total_count) / float(draw_limit))))
	var drawn_count: int = 0
	var detail_budget: int = _get_lod_count(KUROMI_CRACK_PARTICLE_DETAILED_DRAW_LIMIT, KUROMI_CRACK_PARTICLE_DETAILED_DRAW_LIMIT_LOD, KUROMI_CRACK_PARTICLE_DETAILED_DRAW_LIMIT_SEVERE_LOD, quality_scale)
	for idx in range(total_count):
		if draw_step > 1 and idx % draw_step != 0:
			continue
		var value: Variant = draw_particles[idx]
		if value is Dictionary:
			var particle: Dictionary = value
			var detailed: bool = detail_budget > 0 and float(particle.get("size", 0.0)) >= KUROMI_CRACK_PARTICLE_SIMPLE_SIZE_THRESHOLD
			if detailed:
				detail_budget -= 1
			_draw_kuromi_stone_fragment(canvas, particle, shake_offset, detailed)
			drawn_count += 1
			if drawn_count >= draw_limit:
				break


func _sort_kuromi_fragment_z(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("z_pos", 0.0)) < float(b.get("z_pos", 0.0))


func _draw_kuromi_stone_fragment(canvas: CanvasItem, particle: Dictionary, shake_offset: Vector2, detailed: bool = true) -> void:
	var life: float = clampf(float(particle.get("life", 0.0)) / maxf(0.001, float(particle.get("max_life", 1.0))), 0.0, 1.0)
	if life <= 0.0:
		return
	var center := Vector2(float(particle.get("x", 0.0)), float(particle.get("y", 0.0))) + shake_offset
	var size: float = maxf(1.0, float(particle.get("size", 4.0)))
	var z_pos: float = float(particle.get("z_pos", 0.0))
	var alpha: float = clampf(life * (1.0 + z_pos / 100.0), 0.0, 1.0)
	var base_color: Color = _as_color(particle.get("color", STONE), STONE)
	if not detailed or size <= KUROMI_CRACK_PARTICLE_SIMPLE_SIZE_THRESHOLD:
		_draw_simple_kuromi_stone_fragment(canvas, center, size, z_pos, alpha, base_color)
		return
	@warning_ignore("shadowed_global_identifier")
	var seed: int = absi(int(particle.get("seed", 1)))
	var num_points: int = 5 + seed % 3
	var rotation: float = deg_to_rad(float(particle.get("rotation", 0.0)))
	var points: PackedVector2Array = _build_kuromi_stone_fragment_points(center, size, seed, rotation, num_points)
	if not _is_polygon_triangulable(points):
		_draw_simple_kuromi_stone_fragment(canvas, center, size, z_pos, alpha, base_color)
		return
	if z_pos > 20.0:
		var shadow_offset := Vector2(z_pos / 10.0, z_pos / 10.0)
		var shadow_points := PackedVector2Array()
		for point in points:
			shadow_points.append(point + shadow_offset)
		if _is_polygon_triangulable(shadow_points):
			canvas.draw_colored_polygon(shadow_points, Color(0.0, 0.0, 0.0, 0.30 * alpha))
	var body_color := Color(
		minf(1.0, base_color.r + minf(30.0, size / 2.0) / 255.0),
		minf(1.0, base_color.g + minf(30.0, size / 2.0) / 255.0),
		minf(1.0, base_color.b + minf(30.0, size / 2.0) / 255.0),
		alpha
	)
	canvas.draw_colored_polygon(points, body_color)
	if size > 6.0:
		@warning_ignore("integer_division")
		var highlight_count: int = max(3, int(points.size() / 3))
		var highlight_points := PackedVector2Array()
		for idx in range(highlight_count):
			highlight_points.append(points[idx])
		if _is_polygon_triangulable(highlight_points):
			canvas.draw_colored_polygon(highlight_points, Color(minf(1.0, base_color.r + 60.0 / 255.0), minf(1.0, base_color.g + 60.0 / 255.0), minf(1.0, base_color.b + 60.0 / 255.0), 0.48 * alpha))
	canvas.draw_polyline(points, Color(maxf(0.0, base_color.r - 70.0 / 255.0), maxf(0.0, base_color.g - 70.0 / 255.0), maxf(0.0, base_color.b - 70.0 / 255.0), alpha), 2.0, true)


func _build_kuromi_stone_fragment_points(
	center: Vector2,
	size: float,
	seed: int,
	rotation: float,
	num_points: int
) -> PackedVector2Array:
	var safe_count: int = clampi(num_points, 3, 8)
	var angle_step: float = TAU / float(safe_count)
	var angle_jitter_limit: float = minf(0.22, angle_step * 0.24)
	var points := PackedVector2Array()
	for idx in range(safe_count):
		var base_angle: float = rotation + float(idx) * angle_step
		var jitter_unit: float = float((seed + idx * 137) % 100) / 99.0 * 2.0 - 1.0
		var angle_variation: float = jitter_unit * angle_jitter_limit
		var radius_unit: float = float((seed + idx * 71) % 100) / 99.0
		var dist_factor: float = 0.74 + radius_unit * 0.22
		points.append(center + Vector2(cos(base_angle + angle_variation), sin(base_angle + angle_variation)) * size * dist_factor)
	return points


func _is_polygon_triangulable(points: PackedVector2Array) -> bool:
	return points.size() >= 3 and not Geometry2D.triangulate_polygon(points).is_empty()


func _draw_simple_kuromi_stone_fragment(canvas: CanvasItem, center: Vector2, size: float, z_pos: float, alpha: float, base_color: Color) -> void:
	var radius: float = maxf(1.0, size * (0.42 + minf(z_pos, 44.0) / 220.0))
	var shade: float = minf(34.0, size * 1.8) / 255.0
	canvas.draw_circle(center, radius, Color(
		minf(1.0, base_color.r + shade),
		minf(1.0, base_color.g + shade),
		minf(1.0, base_color.b + shade),
		alpha * 0.82
	))


func _draw_petrified_tail(canvas: CanvasItem, center: Vector2, head_size: float, quality_scale: float) -> void:
	var stone_base := Color(120.0 / 255.0, 120.0 / 255.0, 120.0 / 255.0, 1.0)
	var stone_dark := Color(80.0 / 255.0, 80.0 / 255.0, 80.0 / 255.0, 1.0)
	var points: Array[Vector2] = []
	var tail_base := center + Vector2(0.0, head_size)
	var point_count: int = _get_lod_count(KUROMI_PETRIFIED_TAIL_POINT_COUNT, KUROMI_PETRIFIED_TAIL_POINT_COUNT_LOD, KUROMI_PETRIFIED_TAIL_POINT_COUNT_SEVERE_LOD, quality_scale)
	for idx in range(point_count):
		var t: float = float(idx) / float(maxi(1, point_count - 1))
		points.append(tail_base + Vector2(sin(t * PI) * 20.0, t * 40.0))
	for idx in range(points.size() - 1):
		var thickness: float = maxf(1.0, 8.0 - float(idx) * 0.7)
		canvas.draw_line(points[idx], points[idx + 1], stone_base, thickness + 2.0, true)
		canvas.draw_line(points[idx], points[idx + 1], stone_dark, thickness, true)
	if not points.is_empty():
		_draw_kuromi_heart(canvas, points[points.size() - 1], 8.0, stone_dark, Color.TRANSPARENT, false)


func _draw_awake_kuromi(canvas: CanvasItem, context: Dictionary, center: Vector2, size: float, quality_scale: float) -> void:
	var head_size: float = size * 0.6
	var emotional: int = wrapi(int(context.get("stage3_emotional_phase", emotional_phase)), 0, 3)
	var ball_pos: Vector2 = _as_vector2(context.get("ball_pos", center), center)
	var frame_time: float = time_sec * 60.0

	var shadow_layers: int = _get_lod_count(KUROMI_SHADOW_LAYERS, KUROMI_SHADOW_LAYERS_LOD, KUROMI_SHADOW_LAYERS_SEVERE_LOD, quality_scale)
	for i in range(shadow_layers, 0, -1):
		canvas.draw_circle(center + Vector2(0.0, 10.0), head_size + float(i) * 2.0, Color(LAVENDER.r, LAVENDER.g, LAVENDER.b, float(i) * 3.0 / 255.0))

	var face_rect := Rect2(center.x - head_size, center.y - head_size + 8.0, head_size * 2.0, head_size * 1.9)
	var face_layer_count: int = _get_lod_count(KUROMI_FACE_LAYER_COUNT, KUROMI_FACE_LAYER_COUNT_LOD, KUROMI_FACE_LAYER_COUNT_SEVERE_LOD, quality_scale)
	for idx in range(face_layer_count):
		var offset: float = float(idx) * 2.0
		var tone: float = float(idx) * 2.0 / 255.0
		_draw_ellipse(
			canvas,
			Rect2(face_rect.position + Vector2(offset, offset), face_rect.size - Vector2(offset * 2.0, offset * 2.0)),
			Color(1.0 - tone, 250.0 / 255.0 - tone, 1.0 - float(idx) * 3.0 / 255.0, 1.0)
		)
	_draw_ellipse_outline(canvas, face_rect, Color(PASTEL_PINK.r, PASTEL_PINK.g, PASTEL_PINK.b, 200.0 / 255.0), 3.0)
	_draw_ellipse_outline(canvas, face_rect, SOFT_BLACK, 1.0)

	var ear_height: float = head_size * 1.4
	var ear_width: float = head_size * 0.5
	var ear_wiggle: float = sin(frame_time * 0.008) * 2.0
	var left_base := center + Vector2(-head_size * 0.5, -head_size * 0.5 + 5.0)
	var right_base := center + Vector2(head_size * 0.5, -head_size * 0.5 + 5.0)
	var left_tip := center + Vector2(-head_size * 0.5 - ear_width * 0.5 + ear_wiggle, -head_size - ear_height)
	var right_tip := center + Vector2(head_size * 0.5 + ear_width * 0.5 - ear_wiggle, -head_size - ear_height)
	var left_inner_base := center + Vector2(-head_size * 0.25, -head_size * 0.5 + 5.0)
	var right_inner_base := center + Vector2(head_size * 0.25, -head_size * 0.5 + 5.0)
	_draw_kuromi_ear(canvas, center, left_base, left_tip, left_inner_base, -1.0, quality_scale)
	_draw_kuromi_ear(canvas, center, right_base, right_tip, right_inner_base, 1.0, quality_scale)

	var skull_center := Vector2(center.x, center.y - head_size - ear_height * 0.5 + 5.0)
	var skull_size: float = ear_width * 0.7
	for idx in range(3):
		canvas.draw_circle(skull_center, skull_size + 3.0 - float(idx), Color(PASTEL_PINK.r, PASTEL_PINK.g, PASTEL_PINK.b, float(100 - idx * 20) / 255.0))
	canvas.draw_circle(skull_center, skull_size, PASTEL_PINK)
	canvas.draw_circle(skull_center, maxf(1.0, skull_size - 2.0), Color(1.0, 220.0 / 255.0, 230.0 / 255.0, 1.0))
	canvas.draw_circle(skull_center, maxf(1.0, skull_size - 4.0), WHITE)
	_draw_skull_heart_eye(canvas, skull_center + Vector2(-skull_size / 3.0, -2.0), SOFT_BLACK)
	_draw_skull_heart_eye(canvas, skull_center + Vector2(skull_size / 3.0, -2.0), SOFT_BLACK)
	_draw_kuromi_heart(canvas, skull_center + Vector2(0.0, 5.0), 2.0, Color(PASTEL_PINK.r, PASTEL_PINK.g, PASTEL_PINK.b, 0.58), Color.TRANSPARENT, false)
	_draw_ellipse(canvas, Rect2(skull_center + Vector2(-skull_size - 5.0, -3.0), Vector2(6.0, 8.0)), Color(1.0, 150.0 / 255.0, 200.0 / 255.0, 1.0), 14)
	_draw_ellipse(canvas, Rect2(skull_center + Vector2(skull_size - 1.0, -3.0), Vector2(6.0, 8.0)), Color(1.0, 150.0 / 255.0, 200.0 / 255.0, 1.0), 14)

	var eye_y: float = center.y - head_size / 6.0
	if emotional == 1:
		eye_y -= 2.0
	elif emotional == 2:
		eye_y += 3.0
	var eye_spacing: float = head_size / 2.2
	var eye_width: float = head_size * 0.25
	var eye_height: float = head_size * 0.3
	var left_eye_center := Vector2(center.x - eye_spacing, eye_y)
	var right_eye_center := Vector2(center.x + eye_spacing, eye_y)
	for eye_center in [left_eye_center, right_eye_center]:
		var eye_rect := Rect2(eye_center - Vector2(eye_width * 0.5, eye_height * 0.5), Vector2(eye_width, eye_height))
		_draw_ellipse_outline(canvas, eye_rect, SOFT_BLACK, 2.0, 20)
		_draw_ellipse(canvas, eye_rect.grow(-2.0), Color(1.0, 248.0 / 255.0, 1.0, 1.0), 20)
		var delta: Vector2 = ball_pos - eye_center
		var pupil_offset: Vector2 = Vector2.ZERO
		if delta.length() > 0.01:
			pupil_offset = Vector2(cos(delta.angle()) * eye_width * 0.1, sin(delta.angle()) * eye_height * 0.1)
		var pupil_center: Vector2 = eye_center + pupil_offset
		var pupil_size: float = eye_width * 0.6
		canvas.draw_circle(pupil_center, pupil_size, Color(80.0 / 255.0, 60.0 / 255.0, 100.0 / 255.0, 1.0))
		canvas.draw_circle(pupil_center, pupil_size * 0.8, Color(120.0 / 255.0, 90.0 / 255.0, 150.0 / 255.0, 1.0))
		canvas.draw_circle(pupil_center, pupil_size * 0.5, SOFT_BLACK)
		canvas.draw_circle(pupil_center + Vector2(-pupil_size / 3.0, -pupil_size / 3.0), pupil_size * 0.4, WHITE)
		canvas.draw_circle(pupil_center + Vector2(pupil_size / 4.0, -pupil_size / 4.0), pupil_size * 0.2, WHITE)
		canvas.draw_circle(pupil_center + Vector2(-pupil_size / 5.0, pupil_size / 4.0), pupil_size * 0.12, Color(1.0, 240.0 / 255.0, 250.0 / 255.0, 1.0))
	if emotional == 2:
		canvas.draw_circle(left_eye_center + Vector2(0.0, eye_height * 0.5 + 3.0), 3.0, BABY_BLUE)
		canvas.draw_circle(right_eye_center + Vector2(0.0, eye_height * 0.5 + 3.0), 3.0, BABY_BLUE)

	var nose_y: float = center.y + head_size / 6.0
	_draw_kuromi_heart(canvas, Vector2(center.x, nose_y), 3.0, Color(PASTEL_PINK.r, PASTEL_PINK.g, PASTEL_PINK.b, 200.0 / 255.0), Color.TRANSPARENT, false)
	var mouth_y: float = center.y + head_size / 4.0
	if bool(context.get("stage3_kuromi_eating_active", false)):
		_draw_kuromi_tongue_capture(canvas, context, center, mouth_y, quality_scale)
	_draw_kuromi_mouth(canvas, context, center, head_size, emotional, mouth_y)
	canvas.draw_line(Vector2(center.x, nose_y + 2.0), Vector2(center.x, mouth_y - 3.0), Color(SOFT_BLACK.r, SOFT_BLACK.g, SOFT_BLACK.b, 80.0 / 255.0), 1.0, true)

	if bool(context.get("stage3_kuromi_awakened", false)):
		var sparkle_time: float = frame_time * 0.01
		var sparkle_count: int = _get_lod_count(KUROMI_AWAKE_SPARKLE_COUNT, KUROMI_AWAKE_SPARKLE_COUNT_LOD, KUROMI_AWAKE_SPARKLE_COUNT_SEVERE_LOD, quality_scale)
		for idx in range(sparkle_count):
			var angle: float = sparkle_time + float(idx) * TAU / float(sparkle_count)
			var sparkle_dist: float = head_size * 1.5 + sin(sparkle_time * 2.0 + float(idx)) * 10.0
			var sparkle_pos := center + Vector2(cos(angle), sin(angle)) * sparkle_dist
			_draw_star(canvas, sparkle_pos, 3.0 + absf(sin(sparkle_time * 3.0 + float(idx))) * 2.0, Color(1.0, 245.0 / 255.0, 170.0 / 255.0, 0.78 * absf(sin(sparkle_time * 3.0 + float(idx)))))

	_draw_awake_kuromi_tail(canvas, context, center, head_size, ball_pos, quality_scale)

	var blush_y: float = center.y + head_size / 5.0
	var blush_intensity: float = (100.0 + absf(sin(frame_time * 0.006)) * 50.0) / 255.0
	for idx in range(3):
		var blush_size: float = 15.0 - float(idx) * 3.0
		var alpha: float = maxf(0.0, blush_intensity - float(idx) * 30.0 / 255.0)
		_draw_ellipse(canvas, Rect2(left_eye_center + Vector2(-blush_size * 0.5, blush_y - left_eye_center.y - blush_size / 3.0), Vector2(blush_size, blush_size * 0.5)), Color(PASTEL_PINK.r, PASTEL_PINK.g, PASTEL_PINK.b, alpha), 16)
		_draw_ellipse(canvas, Rect2(right_eye_center + Vector2(-blush_size * 0.5, blush_y - right_eye_center.y - blush_size / 3.0), Vector2(blush_size, blush_size * 0.5)), Color(PASTEL_PINK.r, PASTEL_PINK.g, PASTEL_PINK.b, alpha), 16)


func _draw_kuromi_ear(canvas: CanvasItem, center: Vector2, base: Vector2, tip: Vector2, inner_base: Vector2, side: float, quality_scale: float) -> void:
	var ear_layer_count: int = _get_lod_count(KUROMI_EAR_LAYER_COUNT, KUROMI_EAR_LAYER_COUNT_LOD, KUROMI_EAR_LAYER_COUNT_SEVERE_LOD, quality_scale)
	for idx in range(ear_layer_count):
		var scale: float = 1.0 - float(idx) * 0.15
		var color := Color(1.0 - float(idx) * 10.0 / 255.0, 250.0 / 255.0 - float(idx) * 10.0 / 255.0, 1.0 - float(idx) * 15.0 / 255.0, 1.0)
		canvas.draw_colored_polygon(PackedVector2Array([
			base,
			center + (tip - center) * scale,
			inner_base,
		]), color)
	var outline := PackedVector2Array([base, tip, inner_base, base])
	canvas.draw_polyline(outline, Color(LAVENDER.r, LAVENDER.g, LAVENDER.b, 150.0 / 255.0), 2.0, true)
	var inner_tip := tip + Vector2(-side * 8.0, 15.0)
	var inner_third := Vector2(center.x + side * absf(inner_base.x - center.x) * 4.0 / 3.0, base.y)
	canvas.draw_colored_polygon(PackedVector2Array([
		base + Vector2(-side * 4.0, 0.0),
		inner_tip,
		inner_third,
	]), Color(PASTEL_PINK.r, PASTEL_PINK.g, PASTEL_PINK.b, 180.0 / 255.0))
	canvas.draw_circle(tip + Vector2(-side * 10.0, 20.0), 3.0, Color(1.0, 1.0, 1.0, 150.0 / 255.0))


func _draw_skull_heart_eye(canvas: CanvasItem, center: Vector2, color: Color) -> void:
	canvas.draw_circle(center + Vector2(-1.0, 0.0), 2.0, color)
	canvas.draw_circle(center + Vector2(1.0, 0.0), 2.0, color)
	canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-2.0, 2.0),
		center + Vector2(0.0, 4.0),
		center + Vector2(2.0, 2.0),
	]), color)


func _draw_kuromi_tongue_capture(canvas: CanvasItem, context: Dictionary, center: Vector2, mouth_y: float, quality_scale: float) -> void:
	var extended: float = clamp(float(context.get("stage3_kuromi_tongue_extended", 0.0)), 0.0, 1.0)
	var ball_on_tongue: bool = bool(context.get("stage3_kuromi_ball_on_tongue", false))
	if extended <= 0.01 and not ball_on_tongue:
		return
	var source := Vector2(center.x, mouth_y + 3.0)
	var target: Vector2 = _as_vector2(context.get("stage3_kuromi_ball_tongue_pos", center), center)
	var timer: float = float(context.get("stage3_kuromi_eating_timer", 0.0))
	var tongue_angle: float = float(context.get("stage3_kuromi_tongue_angle", atan2(target.y - source.y, target.x - source.x)))
	var wrap_phase: float = clamp(float(context.get("stage3_kuromi_tongue_wrap_phase", 0.0)), 0.0, 1.0)
	var dir := Vector2(cos(tongue_angle), sin(tongue_angle))
	var to_target := target - source
	if to_target.length() > 1.0:
		dir = to_target.normalized()
	var side := Vector2(-dir.y, dir.x)
	var reach: float = 1.0 if wrap_phase > 0.0 else extended
	var visible_end: Vector2 = source.lerp(target, reach)
	if wrap_phase <= 0.0:
		visible_end += side * sin(timer * 0.55) * 10.0 * extended
		visible_end += dir * maxf(0.0, sin(timer * 0.70)) * 5.0 * extended
	else:
		visible_end += side * sin(timer * 0.40) * 5.0 * (1.0 - wrap_phase)
	var visible_distance: float = maxf(1.0, source.distance_to(visible_end))
	var curve_ratio: float = clamp(visible_distance / 150.0, 0.0, 1.0)
	var control := source.lerp(visible_end, 0.48)
	control += side * (sin(timer * 0.18) * 18.0 + sin(timer * 0.45) * 9.0 * (1.0 - wrap_phase))
	control += Vector2(0.0, 13.0 * curve_ratio)

	var tongue_point_max: int = _get_lod_count(KUROMI_TONGUE_POINT_MAX, KUROMI_TONGUE_POINT_MAX_LOD, KUROMI_TONGUE_POINT_MAX_SEVERE_LOD, quality_scale)
	var point_count: int = clampi(int(18.0 + visible_distance / 5.0), KUROMI_TONGUE_POINT_MIN, tongue_point_max)
	var tongue_points := PackedVector2Array()
	for idx in range(point_count):
		var t: float = float(idx) / float(max(1, point_count - 1))
		var point := _quadratic_point(source, control, visible_end, t)
		var envelope: float = sin(t * PI)
		var lash: float = sin(timer * 0.32 + t * TAU * 2.0) * (8.0 + 6.0 * extended) * envelope * (1.0 - wrap_phase * 0.45)
		var micro_lash: float = sin(timer * 0.76 + float(idx) * 0.9) * 2.4 * (1.0 - t)
		tongue_points.append(point + side * (lash + micro_lash))
	if tongue_points.size() >= 2:
		for idx in range(tongue_points.size() - 1):
			var t: float = float(idx) / float(max(1, tongue_points.size() - 2))
			var width: float = lerp(26.0, 10.0, pow(t, 1.35)) * (0.86 + 0.14 * extended)
			canvas.draw_line(tongue_points[idx] + Vector2(3.0, 3.0), tongue_points[idx + 1] + Vector2(3.0, 3.0), Color(0.36, 0.02, 0.11, 0.54), width + 5.0, true)
		for idx in range(tongue_points.size() - 1):
			var t: float = float(idx) / float(max(1, tongue_points.size() - 2))
			var width: float = lerp(24.0, 9.0, pow(t, 1.35)) * (0.88 + 0.12 * extended)
			var body_color := Color(
				lerp(1.0, 0.96, t),
				lerp(0.50, 0.30, t),
				lerp(0.59, 0.47, t),
				0.96
			)
			canvas.draw_line(tongue_points[idx], tongue_points[idx + 1], Color(0.70, 0.06, 0.20, 0.72), width + 3.0, true)
			canvas.draw_line(tongue_points[idx], tongue_points[idx + 1], body_color, width, true)
		for idx in range(tongue_points.size() - 1):
			var t: float = float(idx) / float(max(1, tongue_points.size() - 2))
			if t > 0.86:
				continue
			var width: float = maxf(2.0, lerp(4.5, 2.0, t))
			canvas.draw_line(tongue_points[idx], tongue_points[idx + 1], Color(0.64, 0.05, 0.18, 0.34 * (1.0 - t * 0.45)), width, true)
		for idx in range(0, tongue_points.size() - 1, 2):
			var t: float = float(idx) / float(max(1, tongue_points.size() - 2))
			var width: float = lerp(3.6, 1.6, t)
			var offset: Vector2 = side * -float(lerp(5.5, 2.0, t))
			canvas.draw_line(tongue_points[idx] + offset, tongue_points[idx + 1] + offset, Color(1.0, 0.78, 0.84, 0.45 * (1.0 - t * 0.45)), width, true)
		var tip: Vector2 = tongue_points[tongue_points.size() - 1]
		var tip_size: float = 7.0 + 4.0 * extended
		canvas.draw_circle(tip + Vector2(2.0, 2.0), tip_size + 2.0, Color(0.36, 0.02, 0.11, 0.38))
		canvas.draw_circle(tip, tip_size, Color(1.0, 0.36, 0.48, 0.96))
		canvas.draw_circle(tip - side * 2.2 - dir * 2.0, maxf(2.0, tip_size * 0.34), Color(1.0, 0.76, 0.82, 0.78))
		var fork_alpha: float = 0.32 + 0.28 * maxf(0.0, sin(timer * 0.60))
		canvas.draw_line(tip - dir * 1.0, tip - dir * 7.0 + side * 5.0, Color(1.0, 0.70, 0.78, fork_alpha), 2.0, true)
		canvas.draw_line(tip - dir * 1.0, tip - dir * 7.0 - side * 5.0, Color(1.0, 0.70, 0.78, fork_alpha), 2.0, true)
		if extended > 0.25:
			var sparkle_count: int = 4
			for idx in range(sparkle_count):
				var sparkle_t: float = 0.18 + float(idx) * 0.18
				var point_idx: int = clampi(int(sparkle_t * float(tongue_points.size() - 1)), 0, tongue_points.size() - 1)
				var sparkle_alpha: float = 0.25 + 0.22 * sin(timer * 0.33 + float(idx) * 1.7)
				var sparkle_pos: Vector2 = tongue_points[point_idx] - side * (5.0 - float(idx) * 0.55)
				canvas.draw_circle(sparkle_pos, 1.5 + float(idx % 2) * 0.5, Color(1.0, 1.0, 1.0, sparkle_alpha))
	if ball_on_tongue:
		var ball_radius: float = 14.5 + sin(time_sec * 15.0) * 1.2
		canvas.draw_circle(target + Vector2(2.0, 2.0), ball_radius + 3.0, Color(0.22, 0.02, 0.10, 0.35))
		canvas.draw_circle(target, ball_radius, Color(1.0, 0.95, 1.0, 0.96))
		canvas.draw_circle(target + Vector2(-4.0, -4.0), 3.8, Color(1.0, 1.0, 1.0, 0.74))
		if wrap_phase > 0.0:
			var coil_segments: int = _get_lod_count(KUROMI_TONGUE_COIL_SEGMENTS, KUROMI_TONGUE_COIL_SEGMENTS_LOD, KUROMI_TONGUE_COIL_SEGMENTS_SEVERE_LOD, quality_scale)
			for idx in range(3):
				var coil_angle: float = tongue_angle + timer * 0.12 + float(idx) * TAU / 3.0
				var coil_radius: float = ball_radius + 9.0 - wrap_phase * 5.0 + float(idx) * 1.6
				canvas.draw_arc(target, coil_radius, coil_angle, coil_angle + PI * 1.32, coil_segments, Color(1.0, 0.34, 0.54, (0.30 + 0.28 * wrap_phase) * (1.0 - float(idx) * 0.16)), 5.0 - float(idx), true)
				var knot_pos := target + Vector2(cos(coil_angle + PI * 1.25), sin(coil_angle + PI * 1.25)) * coil_radius
				canvas.draw_circle(knot_pos, 3.2 + wrap_phase * 2.0, Color(1.0, 0.60, 0.70, 0.48 + 0.24 * wrap_phase))
		var wrap_segments: int = _get_lod_count(KUROMI_TONGUE_WRAP_ARC_SEGMENTS, KUROMI_TONGUE_WRAP_ARC_SEGMENTS_LOD, KUROMI_TONGUE_WRAP_ARC_SEGMENTS_SEVERE_LOD, quality_scale)
		canvas.draw_arc(target, ball_radius + 5.0, tongue_angle - PI * 0.8, tongue_angle + PI * 0.8, wrap_segments, Color(1.0, 0.31, 0.54, 0.35 + 0.34 * wrap_phase), 3.0 + wrap_phase * 4.0, true)
		canvas.draw_arc(target, ball_radius + 11.0, tongue_angle + PI * 0.4, tongue_angle + PI * 1.7, wrap_segments, Color(1.0, 0.72, 0.84, 0.18 + 0.28 * wrap_phase), 2.0 + wrap_phase * 2.0, true)


func _quadratic_point(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var inv_t: float = 1.0 - t
	return a * inv_t * inv_t + b * 2.0 * inv_t * t + c * t * t


func _draw_kuromi_mouth(canvas: CanvasItem, context: Dictionary, center: Vector2, head_size: float, emotional: int, mouth_y: float) -> void:
	if bool(context.get("stage3_kuromi_eating_active", false)):
		_draw_kuromi_eating_mouth(canvas, context, center, head_size, mouth_y)
		return
	if emotional == 1:
		_draw_ellipse_arc(canvas, Rect2(center.x - head_size / 5.0, mouth_y - 5.0, head_size / 5.0, 15.0), 0.0, PI, SOFT_BLACK, 2.0)
		_draw_ellipse_arc(canvas, Rect2(center.x, mouth_y - 5.0, head_size / 5.0, 15.0), 0.0, PI, SOFT_BLACK, 2.0)
		_draw_ellipse_arc(canvas, Rect2(center.x - head_size / 5.0 + 2.0, mouth_y - 3.0, head_size / 5.0 - 4.0, 10.0), 0.0, PI, Color(PASTEL_PINK.r, PASTEL_PINK.g, PASTEL_PINK.b, 150.0 / 255.0), 6.0)
	elif emotional == 2:
		_draw_ellipse_arc(canvas, Rect2(center.x - head_size / 6.0, mouth_y + 2.0, head_size / 3.0, 10.0), PI * 0.2, PI * 0.8, SOFT_BLACK, 2.0)
	else:
		_draw_ellipse_arc(canvas, Rect2(center.x - head_size / 5.0, mouth_y - 5.0, head_size / 5.0, 12.0), 0.0, PI, SOFT_BLACK, 3.0)
		_draw_ellipse_arc(canvas, Rect2(center.x, mouth_y - 5.0, head_size / 5.0, 12.0), 0.0, PI, SOFT_BLACK, 3.0)
		canvas.draw_circle(Vector2(center.x, mouth_y), 2.0, Color(PASTEL_PINK.r, PASTEL_PINK.g, PASTEL_PINK.b, 150.0 / 255.0))


func _draw_kuromi_eating_mouth(canvas: CanvasItem, context: Dictionary, center: Vector2, head_size: float, mouth_y: float) -> void:
	var mouth_open: float = clamp(float(context.get("stage3_kuromi_mouth_open", 0.0)), 0.0, 1.0)
	var chewing: float = clamp(float(context.get("stage3_kuromi_chewing_phase", 0.0)), 0.0, 1.0)
	var timer: float = float(context.get("stage3_kuromi_eating_timer", 0.0))
	var direction: float = float(context.get("stage3_kuromi_mouth_direction", 0.0))
	var mouth_center := Vector2(center.x, mouth_y + 2.0)
	if timer >= 120.0:
		_draw_kuromi_spit_warning(canvas, mouth_center, direction, clampf((timer - 120.0) / 20.0, 0.0, 1.0))
		mouth_center += Vector2(cos(direction), sin(direction)) * head_size * 0.12
	var width: float = head_size * (0.22 + mouth_open * 0.30)
	var height: float = head_size * (0.10 + mouth_open * 0.36)
	if chewing > 0.0 and timer < 120.0:
		width *= 0.85 + chewing * 0.45
		height *= 1.05 - chewing * 0.35
		mouth_center.x += sin(timer * 0.45) * 3.0
	var rect := Rect2(mouth_center - Vector2(width * 0.5, height * 0.5), Vector2(width, height))
	_draw_ellipse(canvas, rect.grow(2.0), Color(0.12, 0.02, 0.08, 0.90), 16)
	_draw_ellipse(canvas, rect, Color(0.31, 0.02, 0.13, 0.96), 16)
	_draw_ellipse(canvas, rect.grow(-maxf(1.0, width * 0.16)), Color(0.88, 0.12, 0.34, 0.58 + mouth_open * 0.22), 14)
	if mouth_open > 0.55:
		var tongue_rect := Rect2(mouth_center + Vector2(-width * 0.25, height * 0.03), Vector2(width * 0.50, height * 0.34))
		_draw_ellipse(canvas, tongue_rect, Color(1.0, 0.46, 0.60, 0.82), 12)
	for side in [-1.0, 1.0]:
		var fang_top := mouth_center + Vector2(side * width * 0.25, -height * 0.43)
		canvas.draw_colored_polygon(PackedVector2Array([
			fang_top,
			fang_top + Vector2(side * width * 0.10, 0.0),
			fang_top + Vector2(side * width * 0.04, height * 0.35),
		]), Color(1.0, 0.94, 0.98, 0.9))


func _draw_kuromi_spit_warning(canvas: CanvasItem, mouth_center: Vector2, direction: float, alpha: float) -> void:
	if alpha <= 0.01:
		return
	var dir := Vector2(cos(direction), sin(direction))
	var side := Vector2(-dir.y, dir.x)
	var pulse: float = 0.78 + 0.22 * sin(time_sec * 18.0)
	var start: Vector2 = mouth_center + dir * 10.0
	var end: Vector2 = mouth_center + dir * KUROMI_SPIT_WARNING_LINE_LENGTH
	var mark_count: int = _get_lod_count(
		KUROMI_SPIT_WARNING_MARK_COUNT,
		KUROMI_SPIT_WARNING_MARK_COUNT_LOD,
		KUROMI_SPIT_WARNING_MARK_COUNT_SEVERE_LOD,
		_active_quality_scale
	)
	canvas.draw_line(start, end, Color(0.22, 0.02, 0.10, 0.48 * alpha), KUROMI_SPIT_WARNING_GLOW_WIDTH + 3.0, true)
	canvas.draw_line(start, end, Color(1.0, 0.10, 0.46, (0.40 + 0.12 * pulse) * alpha), KUROMI_SPIT_WARNING_GLOW_WIDTH, true)
	canvas.draw_line(start, end, Color(1.0, 0.88, 0.96, (0.66 + 0.16 * pulse) * alpha), KUROMI_SPIT_WARNING_CORE_WIDTH, true)
	for idx in range(1, mark_count + 1):
		var distance: float = 22.0 + float(idx) * 28.0
		var pos: Vector2 = mouth_center + dir * distance
		var radius: float = 4.4 + float(idx) * 0.75
		var mark_alpha: float = alpha * (0.64 - float(idx) * 0.055)
		canvas.draw_circle(pos, radius + 2.4, Color(0.22, 0.02, 0.10, 0.34 * alpha))
		canvas.draw_circle(pos, radius, Color(1.0, 0.18, 0.54, mark_alpha))
		canvas.draw_circle(pos - dir * 1.2 - side * 0.6, maxf(1.2, radius * 0.36), Color(1.0, 0.96, 1.0, 0.72 * alpha))
	var arrow_tip := end
	var left_arrow: Vector2 = arrow_tip - dir * 24.0 + side * 15.0
	var right_arrow: Vector2 = arrow_tip - dir * 24.0 - side * 15.0
	for arrow_end in [left_arrow, right_arrow]:
		canvas.draw_line(arrow_tip, arrow_end, Color(0.22, 0.02, 0.10, 0.54 * alpha), 7.0, true)
		canvas.draw_line(arrow_tip, arrow_end, Color(1.0, 0.12, 0.50, 0.72 * alpha), 4.5, true)
		canvas.draw_line(arrow_tip, arrow_end, Color(1.0, 0.88, 0.96, 0.76 * alpha), 2.0, true)


func _draw_awake_kuromi_tail(canvas: CanvasItem, context: Dictionary, center: Vector2, head_size: float, ball_pos: Vector2, quality_scale: float) -> void:
	if bool(context.get("stage3_tail_whip_active", false)):
		return
	var frame_time: float = time_sec * 60.0
	var angle_to_ball: float = atan2(ball_pos.y - center.y, ball_pos.x - center.x)
	var tail_orbit_radius: float = head_size * 0.9
	var tail_base_angle: float = angle_to_ball + PI
	var tail_base := center + Vector2(cos(tail_base_angle) * tail_orbit_radius, sin(tail_base_angle) * tail_orbit_radius * 0.7)
	var tail_points: Array[Vector2] = []
	var tail_point_count: int = _get_lod_count(KUROMI_IDLE_TAIL_POINT_COUNT, KUROMI_IDLE_TAIL_POINT_COUNT_LOD, KUROMI_IDLE_TAIL_POINT_COUNT_SEVERE_LOD, quality_scale)
	for idx in range(tail_point_count):
		var t: float = float(idx) / float(maxi(1, tail_point_count - 1))
		var spiral: float = t * TAU
		var wave_amplitude: float = 20.0 * (1.0 - t * 0.5)
		var wave: float = sin(spiral + frame_time * 0.01) * wave_amplitude
		var distance: float = 35.0 * t * t
		var depth_offset: float = cos(frame_time * 0.008 + t * 3.0) * 8.0 * (1.0 - t)
		var tail_angle: float = tail_base_angle + wave * 0.02
		tail_points.append(tail_base + Vector2(
			distance * cos(tail_angle) + depth_offset * sin(tail_angle),
			distance * sin(tail_angle) - depth_offset * cos(tail_angle)
		))
	if tail_points.size() < 2:
		return
	for idx in range(tail_points.size() - 1):
		var thickness: float = maxf(1.0, (8.0 - float(idx) * 0.3) * 1.5)
		canvas.draw_line(tail_points[idx] + Vector2(2.0, 2.0), tail_points[idx + 1] + Vector2(2.0, 2.0), Color(LAVENDER.r, LAVENDER.g, LAVENDER.b, 50.0 / 255.0), thickness + 2.0, true)
	for idx in range(tail_points.size() - 1):
		var progress: float = float(idx) / float(tail_points.size())
		var color := _lerp_color(SOFT_BLACK, LAVENDER, progress)
		canvas.draw_line(tail_points[idx], tail_points[idx + 1], color, maxf(1.0, 8.0 - float(idx) * 0.35), true)
	for idx in range(0, tail_points.size() - 1, 3):
		@warning_ignore("integer_division")
		if idx < tail_points.size() / 2:
			canvas.draw_circle(tail_points[idx], maxf(1.0, 3.0 - float(idx) / 4.0), Color(1.0, 1.0, 1.0, 80.0 / 255.0))
	var end_point: Vector2 = tail_points[tail_points.size() - 1]
	var heart_pulse: float = absf(sin(frame_time * 0.015)) * 2.0 + 8.0
	for idx in range(3):
		var glow_alpha: float = float(60 - idx * 15) / 255.0
		canvas.draw_circle(end_point, heart_pulse + float(idx) * 2.0, Color(PASTEL_PINK.r, PASTEL_PINK.g, PASTEL_PINK.b, glow_alpha))
	_draw_kuromi_heart(canvas, end_point, heart_pulse, PASTEL_PINK, SOFT_BLACK, true)


func _draw_petrified_stone_cracks(canvas: CanvasItem, center: Vector2, head_size: float, color: Color, quality_scale: float) -> void:
	var cracks: Array = [
		[Vector2(-0.72, -0.62), 0.55, 12.0],
		[Vector2(-0.32, -0.18), 1.75, 9.0],
		[Vector2(0.22, -0.46), -0.85, 14.0],
		[Vector2(0.62, -0.08), 2.20, 10.0],
		[Vector2(-0.12, 0.18), 0.90, 13.0],
		[Vector2(0.42, 0.36), -1.20, 9.0],
		[Vector2(-0.55, 0.48), 0.20, 11.0],
		[Vector2(0.04, -0.82), 1.30, 8.0],
	]
	var crack_count: int = _get_lod_count(cracks.size(), cracks.size(), 6, quality_scale)
	for crack_idx in range(crack_count):
		var crack: Array = cracks[crack_idx]
		var offset: Vector2 = _as_vector2(crack[0], Vector2.ZERO) * head_size
		var angle: float = float(crack[1])
		var length: float = float(crack[2])
		var start := center + offset
		var finish := start + Vector2(cos(angle), sin(angle)) * length
		canvas.draw_line(start, finish, color, 1.0, true)


func _draw_kuromi_heart(canvas: CanvasItem, center: Vector2, size: float, fill: Color, outline: Color, draw_outline: bool) -> void:
	canvas.draw_circle(center + Vector2(-size / 3.0, -size / 3.0), size * 0.5, fill)
	canvas.draw_circle(center + Vector2(size / 3.0, -size / 3.0), size * 0.5, fill)
	var bottom := PackedVector2Array([
		center + Vector2(-size, 0.0),
		center + Vector2(0.0, size),
		center + Vector2(size, 0.0),
	])
	canvas.draw_colored_polygon(bottom, fill)
	if draw_outline:
		canvas.draw_arc(center + Vector2(-size / 3.0, -size / 3.0), size * 0.5, 0.0, TAU, 10, outline, 1.0, true)
		canvas.draw_arc(center + Vector2(size / 3.0, -size / 3.0), size * 0.5, 0.0, TAU, 10, outline, 1.0, true)
		canvas.draw_polyline(PackedVector2Array([bottom[0], bottom[1], bottom[2]]), outline, 1.0, true)


func _draw_ellipse(canvas: CanvasItem, rect: Rect2, color: Color, segments: int = 32) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	canvas.draw_colored_polygon(_ellipse_points(rect, _get_lod_segment_count(segments)), color)


func _draw_ellipse_outline(canvas: CanvasItem, rect: Rect2, color: Color, width: float, segments: int = 32) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var points: PackedVector2Array = _ellipse_outline_points(rect, _get_lod_segment_count(segments))
	if points.size() > 0:
		canvas.draw_polyline(points, color, width, true)


func _draw_ellipse_arc(canvas: CanvasItem, rect: Rect2, start_angle: float, end_angle: float, color: Color, width: float, segments: int = 18) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var segment_count: int = _get_lod_segment_count(segments)
	var points := PackedVector2Array()
	var center: Vector2 = rect.get_center()
	var radius := rect.size * 0.5
	for idx in range(segment_count + 1):
		var t: float = float(idx) / float(segment_count)
		var angle: float = lerp(start_angle, end_angle, t)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	canvas.draw_polyline(points, color, width, true)


func _ellipse_points(rect: Rect2, segments: int) -> PackedVector2Array:
	var count: int = maxi(8, segments)
	var cache_key: String = "%d:%d:%d:%d:%d" % [
		int(round(rect.position.x * 10.0)),
		int(round(rect.position.y * 10.0)),
		int(round(rect.size.x * 10.0)),
		int(round(rect.size.y * 10.0)),
		count,
	]
	var cached: Variant = ellipse_points_cache.get(cache_key, null)
	if cached is PackedVector2Array:
		return cached
	var unit_points: PackedVector2Array = _get_ellipse_unit_points(count)
	var points := PackedVector2Array()
	var center: Vector2 = rect.get_center()
	var radius: Vector2 = rect.size * 0.5
	for point in unit_points:
		points.append(center + Vector2(point.x * radius.x, point.y * radius.y))
	if ellipse_points_cache.size() >= MAX_ELLIPSE_POINTS_CACHE_ENTRIES:
		ellipse_points_cache.clear()
	ellipse_points_cache[cache_key] = points
	return points


func _ellipse_outline_points(rect: Rect2, segments: int) -> PackedVector2Array:
	var count: int = maxi(8, segments)
	var cache_key: String = "%d:%d:%d:%d:%d" % [
		int(round(rect.position.x * 10.0)),
		int(round(rect.position.y * 10.0)),
		int(round(rect.size.x * 10.0)),
		int(round(rect.size.y * 10.0)),
		count,
	]
	var cached: Variant = ellipse_outline_points_cache.get(cache_key, null)
	if cached is PackedVector2Array:
		return cached
	var points: PackedVector2Array = _ellipse_points(rect, count)
	if points.is_empty():
		return PackedVector2Array()
	var closed_points := PackedVector2Array()
	for point in points:
		closed_points.append(point)
	closed_points.append(points[0])
	if ellipse_outline_points_cache.size() >= MAX_ELLIPSE_OUTLINE_POINTS_CACHE_ENTRIES:
		ellipse_outline_points_cache.clear()
	ellipse_outline_points_cache[cache_key] = closed_points
	return closed_points


func _get_ellipse_unit_points(segments: int) -> PackedVector2Array:
	if ellipse_unit_point_cache.has(segments):
		return ellipse_unit_point_cache[segments]
	var points := PackedVector2Array()
	for idx in range(segments):
		var angle: float = TAU * float(idx) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)))
	ellipse_unit_point_cache[segments] = points
	return points


func _lerp_color(a: Color, b: Color, weight: float) -> Color:
	var t: float = clampf(weight, 0.0, 1.0)
	return Color(lerp(a.r, b.r, t), lerp(a.g, b.g, t), lerp(a.b, b.b, t), lerp(a.a, b.a, t))


func _draw_border(canvas: CanvasItem, width: float, height: float, shake_offset: Vector2) -> void:
	var cache_width: int = maxi(1, int(ceil(width)))
	var cache_height: int = maxi(1, int(ceil(height)))
	var texture: Texture2D = _get_border_texture(cache_width, cache_height, emotional_phase)
	if texture != null:
		canvas.draw_texture_rect(texture, Rect2(shake_offset, Vector2(width, height)), false)


func _get_border_texture(width: int, height: int, phase: int) -> Texture2D:
	var safe_width: int = maxi(1, width)
	var safe_height: int = maxi(1, height)
	var safe_phase: int = wrapi(phase, 0, 3)
	var cache_key: String = "%d:%d:%d" % [safe_width, safe_height, safe_phase]
	var cached: Variant = border_texture_cache.get(cache_key, null)
	if cached is Texture2D:
		return cached

	var image: Image = Image.create(safe_width, safe_height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	_build_border_image(image, safe_width, safe_height, safe_phase)
	var texture: Texture2D = ImageTexture.create_from_image(image)
	if border_texture_cache.size() >= MAX_BORDER_TEXTURE_CACHE_ENTRIES:
		border_texture_cache.clear()
	border_texture_cache[cache_key] = texture
	return texture


func _build_border_image(image: Image, width: int, height: int, phase: int) -> void:
	var base_color: Color = _get_emotional_color_for_phase(phase)
	var border_px: int = maxi(1, int(round(BORDER_THICKNESS)))
	image.fill_rect(Rect2i(0, 0, width, mini(border_px, height)), base_color)
	image.fill_rect(Rect2i(0, maxi(0, height - border_px), width, mini(border_px, height)), base_color)
	image.fill_rect(Rect2i(0, 0, mini(border_px, width), height), base_color)
	image.fill_rect(Rect2i(maxi(0, width - border_px), 0, mini(border_px, width), height), base_color)

	var inner_px: int = 2
	var inner_offset: int = maxi(0, border_px - inner_px)
	var inner_width: int = maxi(0, width - 2 * inner_offset)
	var inner_height: int = maxi(0, height - 2 * inner_offset)
	if inner_width > 0 and inner_height > 0:
		image.fill_rect(Rect2i(inner_offset, inner_offset, inner_width, inner_px), WHITE)
		image.fill_rect(Rect2i(inner_offset, maxi(0, height - border_px), inner_width, inner_px), WHITE)
		image.fill_rect(Rect2i(inner_offset, inner_offset, inner_px, inner_height), WHITE)
		image.fill_rect(Rect2i(maxi(0, width - border_px), inner_offset, inner_px, inner_height), WHITE)

	var pattern_size: int = 15
	for i in range(0, width, pattern_size * 2):
		var top: Vector2 = Vector2(float(i) + float(pattern_size) * 0.5, BORDER_THICKNESS * 0.5)
		var bottom: Vector2 = Vector2(top.x, float(height) - BORDER_THICKNESS * 0.5)
		if i % (pattern_size * 4) == 0:
			_draw_image_heart(image, top, 4.0, WHITE)
			_draw_image_heart(image, bottom, 4.0, WHITE)
		else:
			_draw_image_star(image, top, 3.0, WHITE)
			_draw_image_star(image, bottom, 3.0, WHITE)
	for i in range(0, height, pattern_size * 2):
		var left: Vector2 = Vector2(BORDER_THICKNESS * 0.5, float(i) + float(pattern_size) * 0.5)
		var right: Vector2 = Vector2(float(width) - BORDER_THICKNESS * 0.5, left.y)
		if i % (pattern_size * 4) == 0:
			_draw_image_heart(image, left, 4.0, WHITE)
			_draw_image_heart(image, right, 4.0, WHITE)
		else:
			_draw_image_star(image, left, 3.0, WHITE)
			_draw_image_star(image, right, 3.0, WHITE)
	for corner in [
		Vector2(BORDER_THICKNESS * 0.5, BORDER_THICKNESS * 0.5),
		Vector2(float(width) - BORDER_THICKNESS * 0.5, BORDER_THICKNESS * 0.5),
		Vector2(BORDER_THICKNESS * 0.5, float(height) - BORDER_THICKNESS * 0.5),
		Vector2(float(width) - BORDER_THICKNESS * 0.5, float(height) - BORDER_THICKNESS * 0.5),
	]:
		_draw_image_bandage_ribbon(image, corner, 8.0)


func _draw_heart(canvas: CanvasItem, center: Vector2, size: float, color: Color) -> void:
	canvas.draw_circle(center + Vector2(-size * 0.45, -size * 0.34), size * 0.50, color)
	canvas.draw_circle(center + Vector2(size * 0.45, -size * 0.34), size * 0.50, color)
	canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-size, -size * 0.10),
		center + Vector2(0.0, size),
		center + Vector2(size, -size * 0.10),
	]), color)


func _draw_broken_heart(canvas: CanvasItem, center: Vector2, size: float, color: Color) -> void:
	_draw_heart(canvas, center, size, color)
	var crack: PackedVector2Array = PackedVector2Array([
		center + Vector2(-1.0, -size * 0.70),
		center + Vector2(size * 0.18, -size * 0.22),
		center + Vector2(-size * 0.02, size * 0.15),
		center + Vector2(size * 0.20, size * 0.68),
	])
	canvas.draw_polyline(crack, Color(0.18, 0.08, 0.11, color.a), 1.5, true)


func _draw_star(canvas: CanvasItem, center: Vector2, size: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(10):
		var radius: float = size if i % 2 == 0 else size * 0.5
		var angle: float = PI * float(i) / 5.0 - PI * 0.5
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	canvas.draw_colored_polygon(points, color)


func _draw_bandage_ribbon(canvas: CanvasItem, center: Vector2, size: float) -> void:
	canvas.draw_line(center + Vector2(-size, -size), center + Vector2(size, size), PASTEL_PINK, 2.0, true)
	canvas.draw_line(center + Vector2(-size, size), center + Vector2(size, -size), PASTEL_PINK, 2.0, true)
	canvas.draw_circle(center, size * 0.45, WHITE)


func _draw_image_heart(image: Image, center: Vector2, size: float, color: Color) -> void:
	_draw_image_circle(image, center + Vector2(-size * 0.45, -size * 0.34), size * 0.50, color)
	_draw_image_circle(image, center + Vector2(size * 0.45, -size * 0.34), size * 0.50, color)
	_draw_image_polygon(image, PackedVector2Array([
		center + Vector2(-size, -size * 0.10),
		center + Vector2(0.0, size),
		center + Vector2(size, -size * 0.10),
	]), color)


func _draw_image_star(image: Image, center: Vector2, size: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(10):
		var radius: float = size if i % 2 == 0 else size * 0.5
		var angle: float = PI * float(i) / 5.0 - PI * 0.5
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	_draw_image_polygon(image, points, color)


func _draw_image_bandage_ribbon(image: Image, center: Vector2, size: float) -> void:
	_draw_image_line(image, center + Vector2(-size, -size), center + Vector2(size, size), PASTEL_PINK, 2.0)
	_draw_image_line(image, center + Vector2(-size, size), center + Vector2(size, -size), PASTEL_PINK, 2.0)
	_draw_image_circle(image, center, size * 0.45, WHITE)


func _draw_image_line(image: Image, start: Vector2, finish: Vector2, color: Color, width: float) -> void:
	var delta: Vector2 = finish - start
	var steps: int = maxi(1, int(ceil(maxf(absf(delta.x), absf(delta.y)) * 2.0)))
	var radius: float = maxf(0.5, width * 0.5)
	for step in range(steps + 1):
		var t: float = float(step) / float(steps)
		_draw_image_circle(image, start.lerp(finish, t), radius, color)


func _draw_image_circle(image: Image, center: Vector2, radius: float, color: Color) -> void:
	if radius <= 0.0:
		return
	var min_x: int = maxi(0, int(floor(center.x - radius)))
	var max_x: int = mini(image.get_width() - 1, int(ceil(center.x + radius)))
	var min_y: int = maxi(0, int(floor(center.y - radius)))
	var max_y: int = mini(image.get_height() - 1, int(ceil(center.y + radius)))
	var radius_sq: float = radius * radius
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var dx: float = float(x) + 0.5 - center.x
			var dy: float = float(y) + 0.5 - center.y
			if dx * dx + dy * dy <= radius_sq:
				image.set_pixel(x, y, color)


func _draw_image_polygon(image: Image, points: PackedVector2Array, color: Color) -> void:
	if points.size() < 3:
		return
	var min_x: int = image.get_width() - 1
	var min_y: int = image.get_height() - 1
	var max_x: int = 0
	var max_y: int = 0
	for point in points:
		min_x = mini(min_x, int(floor(point.x)))
		min_y = mini(min_y, int(floor(point.y)))
		max_x = maxi(max_x, int(ceil(point.x)))
		max_y = maxi(max_y, int(ceil(point.y)))
	min_x = clampi(min_x, 0, image.get_width() - 1)
	min_y = clampi(min_y, 0, image.get_height() - 1)
	max_x = clampi(max_x, 0, image.get_width() - 1)
	max_y = clampi(max_y, 0, image.get_height() - 1)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if _point_in_polygon(Vector2(float(x) + 0.5, float(y) + 0.5), points):
				image.set_pixel(x, y, color)


func _point_in_polygon(point: Vector2, points: PackedVector2Array) -> bool:
	var inside: bool = false
	var previous_index: int = points.size() - 1
	for index in range(points.size()):
		var current: Vector2 = points[index]
		var previous: Vector2 = points[previous_index]
		if (current.y > point.y) != (previous.y > point.y):
			var denominator: float = previous.y - current.y
			if absf(denominator) < 0.0001:
				denominator = 0.0001
			var crossing_x: float = (
				(previous.x - current.x)
				* (point.y - current.y)
				/ denominator
				+ current.x
			)
			if point.x < crossing_x:
				inside = not inside
		previous_index = index
	return inside


func _get_checker_base_color() -> Color:
	return _get_checker_base_color_for_phase(emotional_phase)


func _get_checker_base_color_for_phase(phase: int) -> Color:
	match wrapi(phase, 0, 3):
		1:
			return _rgb255(65.0, 40.0, 55.0)
		2:
			return _rgb255(40.0, 50.0, 70.0)
		_:
			return _rgb255(55.0, 45.0, 65.0)


func _get_emotional_color() -> Color:
	return _get_emotional_color_for_phase(emotional_phase)


func _get_emotional_color_for_phase(phase: int) -> Color:
	match wrapi(phase, 0, 3):
		1:
			return PASTEL_PINK
		2:
			return BABY_BLUE
		_:
			return LAVENDER


func _get_particle_color(index: int) -> Color:
	match index % 3:
		1:
			return LAVENDER
		2:
			return CRIMSON
		_:
			return PASTEL_PINK


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _as_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback


func _get_playfield_quality_scale(context: Dictionary) -> float:
	return BattleRenderQuality.effect_scale(context)


func _is_lod_active(quality_scale: float) -> bool:
	return quality_scale < 0.85


func _is_severe_lod_active(quality_scale: float) -> bool:
	return quality_scale < 0.66


func _get_lod_count(base_count: int, lod_count: int, severe_lod_count: int, quality_scale: float) -> int:
	if base_count <= 0:
		return 0
	if _is_severe_lod_active(quality_scale):
		return clampi(severe_lod_count, 0, base_count)
	if _is_lod_active(quality_scale):
		return clampi(lod_count, 0, base_count)
	return base_count


func _get_lod_segment_count(base_segments: int) -> int:
	var safe_segments: int = maxi(8, base_segments)
	var lod_segments: int = maxi(8, int(ceil(float(safe_segments) * 0.75)))
	var severe_segments: int = maxi(8, int(ceil(float(safe_segments) * 0.55)))
	return _get_lod_count(safe_segments, lod_segments, severe_segments, _active_quality_scale)


func _rgb255(r: float, g: float, b: float) -> Color:
	return Color(r / 255.0, g / 255.0, b / 255.0, 1.0)


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
