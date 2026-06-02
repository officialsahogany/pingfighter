extends RefCounted

const Stage1ContextReader := preload("res://scripts/stages/stage1/stage1_context_reader.gd")
const BattleRenderQuality := preload("res://scripts/core/battle_render_quality.gd")

const DASH_AFTERIMAGE_MAX_COUNT := 3
const DASH_AFTERIMAGE_LOD_MAX_COUNT := 1
const DASH_AFTERIMAGE_SPAWN_INTERVAL_MSEC := 16
const DASH_AFTERIMAGE_LOD_SPAWN_INTERVAL_MSEC := 44
const DASH_AFTERIMAGE_LIFETIME_MSEC := 135.0
const DASH_AFTERIMAGE_MAX_ALPHA := 180.0 / 255.0
const DEFAULT_PLAYER_DIRECTIONAL_WALK_GRID_COLS := 4
const DEFAULT_PLAYER_DIRECTIONAL_WALK_FRAME_COUNT := 8
const DEFAULT_PLAYER_DIRECTIONAL_WALK_DRAW_SIZE := Vector2(160.0, 160.0)
const STADIUM_CIRCLE_RADIUS := 88.0
const STADIUM_GUIDE_ARC_SEGMENTS := 28
const STADIUM_GUIDE_ARC_SEGMENTS_LOD := 12
const STADIUM_GUIDE_ARC_SEGMENTS_SEVERE_LOD := 8
const STADIUM_SPARK_MIN_INTERVAL_SEC := 12.0
const STADIUM_SPARK_MAX_INTERVAL_SEC := 25.0
const STADIUM_SPARK_BURST_DURATION_SEC := 0.65
const STADIUM_SPARK_POINT_STEP := 16.0
const STADIUM_SPARK_POINT_STEP_LOD := 26.0
const STADIUM_SPARK_POINT_STEP_SEVERE_LOD := 36.0
const STADIUM_SPARK_BRANCH_COUNT := 3
const STADIUM_SPARK_BRANCH_COUNT_LOD := 1
const STADIUM_SPARK_BRANCH_COUNT_SEVERE_LOD := 1
const STADIUM_SPARK_TRAIL_SPARK_COUNT := 2
const STADIUM_SPARK_TRAIL_SPARK_COUNT_LOD := 1
const STADIUM_SPARK_TRAIL_SPARK_COUNT_SEVERE_LOD := 1
const GRID_PARTICLE_COUNT := 6
const GRID_PARTICLE_COUNT_LOD := 3
const GRID_PARTICLE_COUNT_SEVERE_LOD := 0
const GRID_PARTICLE_FPS_SPEED := 60.0
const STAGE1_BORDER_THICKNESS := 10.0
const STAGE1_WALL_FLASH_DURATION_SEC := 15.0 / 60.0
const STAGE1_WALL_FLASH_GRADIENT_STEPS := 4
const STAGE1_WALL_FLASH_GRADIENT_STEPS_LOD := 2
const STAGE1_WALL_FLASH_GRADIENT_STEPS_SEVERE_LOD := 2
const STAGE1_WALL_FLASH_SIDE_STRIP_STEPS := 4
const STAGE1_WALL_FLASH_SIDE_STRIP_STEPS_LOD := 2
const STAGE1_WALL_FLASH_SIDE_STRIP_STEPS_SEVERE_LOD := 2
const STAGE1_WALL_FLASH_SATELLITE_COUNT := 2
const STAGE1_WALL_FLASH_SATELLITE_COUNT_LOD := 1
const STAGE1_WALL_FLASH_SATELLITE_COUNT_SEVERE_LOD := 1
const FLOOR_CRACK_COUNT := 5
const FLOOR_CRACK_COUNT_LOD := 2
const FLOOR_CRACK_COUNT_SEVERE_LOD := 2
const FLOOR_MOSS_COUNT := 36
const FLOOR_MOSS_COUNT_LOD := 12
const FLOOR_MOSS_COUNT_SEVERE_LOD := 4
const FLOOR_SPECK_COUNT := 160
const FLOOR_SPECK_COUNT_LOD := 48
const FLOOR_SPECK_COUNT_SEVERE_LOD := 12
const FLOOR_TILE_DRAW_STRIDE_LOD := 3
const STAGE1_MOOD_GRADE_COLOR := Color(4.0 / 255.0, 9.0 / 255.0, 22.0 / 255.0, 84.0 / 255.0)
const STAGE1_MOOD_INK_COLOR := Color(0.0, 2.0 / 255.0, 7.0 / 255.0, 56.0 / 255.0)
const STAGE1_MOOD_EDGE_STEPS := 6
const STAGE1_MOOD_EDGE_STEPS_LOD := 3
const STAGE1_MOOD_EDGE_STEPS_SEVERE_LOD := 1
const STAGE1_MOOD_EDGE_ALPHA := 42.0 / 255.0
const STAGE1_CYBER_SCANLINE_COUNT := 5
const STAGE1_CYBER_SCANLINE_COUNT_LOD := 1
const STAGE1_CYBER_SCANLINE_COUNT_SEVERE_LOD := 0
const STAGE1_CYBER_GLITCH_BAND_COUNT := 3
const STAGE1_CYBER_GLITCH_BAND_COUNT_LOD := 1
const STAGE1_CYBER_GLITCH_BAND_COUNT_SEVERE_LOD := 0
const STAGE1_CYBER_CIRCUIT_TICK_COUNT := 4
const STAGE1_CYBER_CIRCUIT_TICK_COUNT_LOD := 1
const STAGE1_CYBER_CIRCUIT_TICK_COUNT_SEVERE_LOD := 0
const STAGE1_OMINOUS_SHADOW_STEPS := 7
const STAGE1_OMINOUS_SHADOW_STEPS_LOD := 3
const STAGE1_OMINOUS_SHADOW_STEPS_SEVERE_LOD := 1
const STAGE1_DEPTH_BAND_STEPS := 5
const STAGE1_DEPTH_BAND_STEPS_LOD := 3
const STAGE1_DEPTH_BAND_STEPS_SEVERE_LOD := 2
const STAGE1_DEPTH_FAR_ALPHA := 60.0 / 255.0
const STAGE1_DEPTH_NEAR_ALPHA := 45.0 / 255.0
const STAGE1_DEPTH_CENTER_LIGHT_ALPHA := 10.0 / 255.0
const STAGE1_FLOOR_VIGNETTE_STEPS := 8
const STAGE1_FLOOR_VIGNETTE_STEPS_LOD := 5
const STAGE1_FLOOR_VIGNETTE_STEPS_SEVERE_LOD := 3
const STAGE1_FLOOR_VIGNETTE_OUTER_ALPHA := 55.0 / 255.0
const STAGE1_FLOOR_VIGNETTE_INNER_ALPHA := 7.0 / 255.0
const STAGE1_FLOOR_VIGNETTE_CENTER_ALPHA := 6.0 / 255.0
const STAGE1_FLOOR_EDGE_VIGNETTE_STEPS := 8
const STAGE1_FLOOR_EDGE_VIGNETTE_STEPS_LOD := 4
const STAGE1_FLOOR_EDGE_VIGNETTE_STEPS_SEVERE_LOD := 2
const STAGE1_BORDER_MARK_SPACING := 18
const STAGE1_BORDER_MARK_SPACING_LOD := 40
const STAGE1_BORDER_MARK_SPACING_SEVERE_LOD := 60
const STAGE1_BORDER_CORNER_ARC_SEGMENTS := 16
const STAGE1_BORDER_CORNER_ARC_SEGMENTS_LOD := 10
const STAGE1_CYBER_CYAN := Color(0.0, 0.88, 1.0, 1.0)
const STAGE1_CYBER_MAGENTA := Color(1.0, 0.14, 0.76, 1.0)
const STAGE1_POST_BORDER_SHADOW := Color(0.0, 3.0 / 255.0, 10.0 / 255.0, 38.0 / 255.0)

var dash_afterimages: Array = []
var dash_afterimage_last_spawn_msec: int = -100000
var stadium_spark_next_time_sec: float = -1.0
var stadium_spark_active_start_sec: float = -1.0
var stadium_spark_cycle_index: int = 0
var stadium_spark_direction: float = 1.0
var grid_particles: Array[Vector4] = []
var grid_particle_layout_size := Vector2.ZERO
var floor_layout_size := Vector2.ZERO
var floor_tiles: Array = []
var floor_specks: Array = []
var floor_moss: Array = []
var floor_cracks: Array = []
var _prewarm_step_index := 0


func prewarm_runtime_assets() -> void:
	while not prewarm_runtime_assets_step():
		pass


func prewarm_runtime_assets_step() -> bool:
	match _prewarm_step_index:
		0:
			_ensure_floor_layout(760.0, 750.0)
		1:
			_ensure_grid_particles(760.0, 750.0)
		_:
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	return false


func draw(canvas: CanvasItem, context: Dictionary, _shake_offset: Vector2) -> void:
	var width: float = float(context.get("width", 760.0))
	var height: float = float(context.get("height", 750.0))
	var quality_scale: float = _get_playfield_quality_scale(context)
	var background_texture = context.get("stage1_center_background_texture", null)
	if background_texture is Texture2D:
		canvas.draw_texture_rect(background_texture, Rect2(0.0, 0.0, width, height), false)
	else:
		_draw_actual_stage1_center_background(canvas, width, height, quality_scale)
	_draw_stage1_floor_vignette(canvas, context, width, height, quality_scale)
	_draw_stage1_depth_layers(canvas, context, width, height, quality_scale)
	_draw_stage1_mood_grade(canvas, width, height, quality_scale)
	_draw_stage1_cyberpunk_atmosphere(canvas, width, height, quality_scale)
	_draw_stadium_electric_flow(canvas, width, height, quality_scale)
	_draw_grid_particles(canvas, width, height, quality_scale)
	_draw_stage1_border(canvas, context, width, height, quality_scale)
	canvas.draw_rect(Rect2(0.0, 0.0, width, height), STAGE1_POST_BORDER_SHADOW)
	_draw_stage1_wall_contact_flash(canvas, context, width, height, _shake_offset, quality_scale)


func _draw_stage1_border(canvas: CanvasItem, context: Dictionary, width: float, height: float, quality_scale: float) -> void:
	var border_texture = context.get("stage1_center_border_texture", null)
	if border_texture is Texture2D:
		canvas.draw_texture_rect(border_texture, Rect2(0.0, 0.0, width, height), false)
		return
	_draw_stage1_danjeong_border(canvas, width, height, quality_scale)


func _draw_actual_stage1_center_background(canvas: CanvasItem, width: float, height: float, quality_scale: float) -> void:
	_ensure_floor_layout(width, height)
	canvas.draw_rect(Rect2(0.0, 0.0, width, height), _rgb(72.0, 68.0, 62.0))

	var lod_active: bool = _is_lod_active(quality_scale)
	var tile_stride: int = FLOOR_TILE_DRAW_STRIDE_LOD if lod_active else 1
	var tile_index := 0
	for tile in floor_tiles:
		if lod_active and tile_index % tile_stride != 0:
			tile_index += 1
			continue
		var rect: Rect2 = _as_rect2(tile.get("rect", Rect2()), Rect2())
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			tile_index += 1
			continue
		canvas.draw_rect(rect, tile.get("fill", _rgba(72.0, 68.0, 62.0, 25.0)))
		canvas.draw_line(rect.position + Vector2(0.0, rect.size.y), rect.end, _rgba(34.0, 31.0, 28.0, 88.0), 1.0)
		canvas.draw_line(rect.position + Vector2(rect.size.x, 0.0), rect.end, _rgba(34.0, 31.0, 28.0, 72.0), 1.0)
		if not lod_active:
			canvas.draw_line(rect.position, rect.position + Vector2(rect.size.x, 0.0), _rgba(88.0, 84.0, 76.0, 24.0), 1.0)
			canvas.draw_line(rect.position, rect.position + Vector2(0.0, rect.size.y), _rgba(88.0, 84.0, 76.0, 22.0), 1.0)
		tile_index += 1

	var moss_count: int = _get_lod_count(FLOOR_MOSS_COUNT, FLOOR_MOSS_COUNT_LOD, FLOOR_MOSS_COUNT_SEVERE_LOD, quality_scale)
	for moss_idx in range(min(moss_count, floor_moss.size())):
		var moss: Dictionary = floor_moss[moss_idx]
		canvas.draw_circle(
			_as_vector2(moss.get("pos", Vector2.ZERO), Vector2.ZERO),
			float(moss.get("radius", 2.0)),
			moss.get("color", _rgba(46.0, 58.0, 35.0, 28.0))
		)

	var crack_count: int = _get_lod_count(FLOOR_CRACK_COUNT, FLOOR_CRACK_COUNT_LOD, FLOOR_CRACK_COUNT_SEVERE_LOD, quality_scale)
	for crack_idx in range(min(crack_count, floor_cracks.size())):
		var crack: Dictionary = floor_cracks[crack_idx]
		var points: Array = crack.get("points", [])
		if points.size() < 2:
			continue
		var dark_color: Color = crack.get("color", _rgba(31.0, 28.0, 25.0, 34.0))
		for idx in range(points.size() - 1):
			var start: Vector2 = _as_vector2(points[idx], Vector2.ZERO)
			var finish: Vector2 = _as_vector2(points[idx + 1], Vector2.ZERO)
			if not lod_active:
				canvas.draw_line(start + Vector2(0.0, 1.0), finish + Vector2(0.0, 1.0), _rgba(18.0, 16.0, 14.0, 18.0), 2.0)
			canvas.draw_line(start, finish, dark_color, 1.0)

	var speck_count: int = _get_lod_count(FLOOR_SPECK_COUNT, FLOOR_SPECK_COUNT_LOD, FLOOR_SPECK_COUNT_SEVERE_LOD, quality_scale)
	for speck_idx in range(min(speck_count, floor_specks.size())):
		var speck: Dictionary = floor_specks[speck_idx]
		var pos: Vector2 = _as_vector2(speck.get("pos", Vector2.ZERO), Vector2.ZERO)
		canvas.draw_rect(
			Rect2(pos, Vector2(float(speck.get("size", 1.0)), float(speck.get("size", 1.0)))),
			speck.get("color", _rgba(140.0, 135.0, 118.0, 36.0))
		)

	_draw_stadium_guide_marks(canvas, width, height, quality_scale)
	_draw_floor_edge_vignette(canvas, width, height, quality_scale)


func _draw_stage1_depth_layers(
	canvas: CanvasItem,
	context: Dictionary,
	width: float,
	height: float,
	quality_scale: float
) -> void:
	if not bool(context.get("stage1_depth_layers_enabled", false)):
		return
	var steps: int = _get_lod_count(
		STAGE1_DEPTH_BAND_STEPS,
		STAGE1_DEPTH_BAND_STEPS_LOD,
		STAGE1_DEPTH_BAND_STEPS_SEVERE_LOD,
		quality_scale
	)
	var far_height: float = height * 0.38
	var near_start_y: float = height * 0.68
	var near_height: float = height - near_start_y
	for idx in range(steps):
		var t: float = 1.0 - float(idx) / float(steps)
		var far_band_h: float = max(1.0, far_height / float(steps))
		var far_alpha: float = STAGE1_DEPTH_FAR_ALPHA * t * t
		canvas.draw_rect(
			Rect2(0.0, far_band_h * float(idx), width, far_band_h + 1.0),
			Color(0.02, 0.08, 0.105, far_alpha)
		)

		var near_band_h: float = max(1.0, near_height / float(steps))
		var near_y: float = near_start_y + near_band_h * float(idx)
		var near_ratio: float = float(idx + 1) / float(steps)
		var near_alpha: float = STAGE1_DEPTH_NEAR_ALPHA * near_ratio * near_ratio
		canvas.draw_rect(
			Rect2(0.0, near_y, width, near_band_h + 1.0),
			Color(0.82, 0.60, 0.28, near_alpha)
		)

	var center_h: float = height * 0.20
	var center_y: float = height * 0.5 - center_h * 0.5
	canvas.draw_rect(
		Rect2(width * 0.10, center_y, width * 0.80, center_h),
		Color(0.48, 0.72, 0.68, STAGE1_DEPTH_CENTER_LIGHT_ALPHA)
	)


func _draw_stage1_floor_vignette(
	canvas: CanvasItem,
	context: Dictionary,
	width: float,
	height: float,
	quality_scale: float
) -> void:
	if not bool(context.get("stage1_floor_vignette_enabled", true)):
		return
	var steps: int = _get_lod_count(
		STAGE1_FLOOR_VIGNETTE_STEPS,
		STAGE1_FLOOR_VIGNETTE_STEPS_LOD,
		STAGE1_FLOOR_VIGNETTE_STEPS_SEVERE_LOD,
		quality_scale
	)
	var ring_thickness: float = min(width, height) / 16.0
	for idx in range(steps):
		var inset: float = ring_thickness * float(idx)
		var outer_rect := Rect2(inset, inset, width - inset * 2.0, height - inset * 2.0)
		if outer_rect.size.x <= 1.0 or outer_rect.size.y <= 1.0:
			break
		var inner_inset: float = min(ring_thickness, min(outer_rect.size.x, outer_rect.size.y) * 0.5)
		var t: float = float(idx) / float(max(1, steps - 1))
		var alpha: float = lerp(STAGE1_FLOOR_VIGNETTE_OUTER_ALPHA, STAGE1_FLOOR_VIGNETTE_INNER_ALPHA, t)
		_draw_stage1_vignette_frame(
			canvas,
			outer_rect,
			inner_inset,
			Color(0.0, 0.02, 0.06, alpha)
		)
	canvas.draw_rect(
		Rect2(width * 0.14, height * 0.16, width * 0.72, height * 0.68),
		Color(0.95, 0.92, 0.84, STAGE1_FLOOR_VIGNETTE_CENTER_ALPHA)
	)


func _draw_stage1_vignette_frame(canvas: CanvasItem, outer_rect: Rect2, thickness: float, color: Color) -> void:
	if thickness <= 0.0:
		return
	var band: float = min(thickness, min(outer_rect.size.x, outer_rect.size.y) * 0.5)
	canvas.draw_rect(Rect2(outer_rect.position, Vector2(outer_rect.size.x, band)), color)
	canvas.draw_rect(
		Rect2(Vector2(outer_rect.position.x, outer_rect.end.y - band), Vector2(outer_rect.size.x, band)),
		color
	)
	var side_height: float = max(0.0, outer_rect.size.y - band * 2.0)
	if side_height <= 0.0:
		return
	canvas.draw_rect(
		Rect2(outer_rect.position + Vector2(0.0, band), Vector2(band, side_height)),
		color
	)
	canvas.draw_rect(
		Rect2(Vector2(outer_rect.end.x - band, outer_rect.position.y + band), Vector2(band, side_height)),
		color
	)


func _ensure_floor_layout(width: float, height: float) -> void:
	var layout_size := Vector2(width, height)
	if floor_layout_size == layout_size and not floor_tiles.is_empty():
		return

	floor_layout_size = layout_size
	floor_tiles.clear()
	floor_specks.clear()
	floor_moss.clear()
	floor_cracks.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = 500
	var y_pos := 18.0
	var row := 0
	while y_pos < height - 18.0:
		var tile_h := 42.0 + float(rng.randi_range(-6, 6))
		var x_pos := 18.0 + float(row % 2) * float(rng.randi_range(8, 18))
		while x_pos < width - 18.0:
			var tile_w := 52.0 + float(rng.randi_range(-10, 12))
			var tone := float(rng.randi_range(-12, 14))
			var warm := float(rng.randi_range(-8, 10))
			floor_tiles.append({
				"rect": Rect2(x_pos, y_pos, tile_w, tile_h),
				"fill": _rgba(72.0 + tone + warm, 68.0 + tone + warm * 0.4, 62.0 + tone - warm * 0.2, float(rng.randi_range(18, 42))),
			})
			x_pos += tile_w + float(rng.randi_range(2, 5))
		y_pos += tile_h + float(rng.randi_range(2, 5))
		row += 1

	rng.seed = 99
	for _i in range(FLOOR_CRACK_COUNT):
		var points: Array[Vector2] = []
		var current := Vector2(rng.randf_range(85.0, width - 85.0), rng.randf_range(65.0, height - 65.0))
		var angle := rng.randf_range(0.0, TAU)
		points.append(current)
		for _segment in range(rng.randi_range(4, 8)):
			angle += rng.randf_range(-0.62, 0.62)
			var length := rng.randf_range(7.0, 19.0)
			current += Vector2(cos(angle), sin(angle)) * length
			current.x = clamp(current.x, 14.0, width - 14.0)
			current.y = clamp(current.y, 14.0, height - 14.0)
			points.append(current)
		floor_cracks.append({
			"points": points,
			"color": _rgba(32.0, 29.0, 25.0, float(rng.randi_range(20, 42))),
		})

	rng.seed = 333
	for _i in range(FLOOR_MOSS_COUNT):
		floor_moss.append({
			"pos": Vector2(rng.randf_range(18.0, width - 18.0), rng.randf_range(18.0, height - 18.0)),
			"radius": rng.randf_range(1.0, 4.0),
			"color": _rgba(rng.randf_range(43.0, 62.0), rng.randf_range(54.0, 72.0), rng.randf_range(34.0, 46.0), rng.randf_range(12.0, 34.0)),
	})

	rng.seed = 42
	for _i in range(FLOOR_SPECK_COUNT):
		var shade := float(rng.randi_range(-18, 18))
		var bright := rng.randf() < 0.24
		var base := 148.0 if bright else 58.0
		floor_specks.append({
			"pos": Vector2(rng.randf_range(1.0, width - 2.0), rng.randf_range(1.0, height - 2.0)),
			"size": 1.0 if rng.randf() < 0.82 else 2.0,
			"color": _rgba(base + shade, base + shade * 0.9, base - 12.0 + shade * 0.6, rng.randf_range(14.0, 58.0)),
		})


func _draw_stadium_guide_marks(canvas: CanvasItem, width: float, height: float, quality_scale: float) -> void:
	var center := Vector2(width * 0.5, height * 0.5)
	var scale: float = min(width / 760.0, height / 750.0)
	var radius: float = STADIUM_CIRCLE_RADIUS * scale
	var shadow_color := _rgba(24.0, 22.0, 18.0, 95.0)
	var line_color := _rgba(112.0, 96.0, 68.0, 135.0)
	var highlight_color := _rgba(164.0, 146.0, 102.0, 55.0)
	var arc_segments: int = _get_lod_count(
		STADIUM_GUIDE_ARC_SEGMENTS,
		STADIUM_GUIDE_ARC_SEGMENTS_LOD,
		STADIUM_GUIDE_ARC_SEGMENTS_SEVERE_LOD,
		quality_scale
	)

	canvas.draw_line(Vector2(0.0, center.y + 1.0), Vector2(width, center.y + 1.0), shadow_color, 4.0)
	canvas.draw_line(Vector2(0.0, center.y), Vector2(width, center.y), line_color, 3.0)
	canvas.draw_line(Vector2(0.0, center.y - 1.0), Vector2(width, center.y - 1.0), highlight_color, 1.0)
	canvas.draw_arc(center, radius + 1.0, 0.0, TAU, arc_segments, shadow_color, 4.0)
	canvas.draw_arc(center, radius, 0.0, TAU, arc_segments, line_color, 3.0)
	canvas.draw_arc(center, max(1.0, radius - 1.0), 0.0, TAU, arc_segments, highlight_color, 1.0)
	canvas.draw_circle(center, 4.0 * scale, line_color)


func _draw_floor_edge_vignette(canvas: CanvasItem, width: float, height: float, quality_scale: float) -> void:
	var edge_steps: int = _get_lod_count(
		STAGE1_FLOOR_EDGE_VIGNETTE_STEPS,
		STAGE1_FLOOR_EDGE_VIGNETTE_STEPS_LOD,
		STAGE1_FLOOR_EDGE_VIGNETTE_STEPS_SEVERE_LOD,
		quality_scale
	)
	for idx in range(edge_steps):
		var t := 1.0 - float(idx) / float(edge_steps)
		var alpha := 7.0 * t * t
		var color := _rgba(13.0, 12.0, 10.0, alpha)
		canvas.draw_rect(Rect2(0.0, float(idx), width, 1.0), color)
		canvas.draw_rect(Rect2(0.0, height - 1.0 - float(idx), width, 1.0), color)
		canvas.draw_rect(Rect2(float(idx), 0.0, 1.0, height), color)
		canvas.draw_rect(Rect2(width - 1.0 - float(idx), 0.0, 1.0, height), color)


func _draw_stage1_mood_grade(canvas: CanvasItem, width: float, height: float, quality_scale: float) -> void:
	canvas.draw_rect(Rect2(0.0, 0.0, width, height), STAGE1_MOOD_GRADE_COLOR)
	canvas.draw_rect(Rect2(0.0, 0.0, width, height), STAGE1_MOOD_INK_COLOR)
	var edge_steps: int = _get_lod_count(STAGE1_MOOD_EDGE_STEPS, STAGE1_MOOD_EDGE_STEPS_LOD, STAGE1_MOOD_EDGE_STEPS_SEVERE_LOD, quality_scale)
	for idx in range(edge_steps):
		var t := 1.0 - float(idx) / float(edge_steps)
		var alpha := STAGE1_MOOD_EDGE_ALPHA * t * t
		var color := Color(4.0 / 255.0, 7.0 / 255.0, 11.0 / 255.0, alpha)
		var offset := float(idx)
		canvas.draw_rect(Rect2(0.0, offset, width, 1.0), color)
		canvas.draw_rect(Rect2(0.0, height - 1.0 - offset, width, 1.0), color)
		canvas.draw_rect(Rect2(offset, 0.0, 1.0, height), color)
		canvas.draw_rect(Rect2(width - 1.0 - offset, 0.0, 1.0, height), color)


func _draw_stage1_cyberpunk_atmosphere(canvas: CanvasItem, width: float, height: float, quality_scale: float) -> void:
	var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.0017)
	_draw_stage1_ominous_shadow(canvas, width, height, pulse, quality_scale)
	var cyan_alpha: float = 0.030 + pulse * 0.016
	var magenta_alpha: float = 0.020 + (1.0 - pulse) * 0.014
	canvas.draw_line(Vector2(14.0, 0.0), Vector2(14.0, height), _with_alpha(STAGE1_CYBER_CYAN, cyan_alpha), 1.0, true)
	canvas.draw_line(Vector2(width - 15.0, 0.0), Vector2(width - 15.0, height), _with_alpha(STAGE1_CYBER_MAGENTA, magenta_alpha), 1.0, true)
	canvas.draw_line(Vector2(0.0, height * 0.5), Vector2(width, height * 0.5), _with_alpha(STAGE1_CYBER_CYAN, 0.024 + pulse * 0.014), 1.0, true)
	canvas.draw_line(Vector2(0.0, height * 0.5 + 5.0), Vector2(width, height * 0.5 + 5.0), _with_alpha(STAGE1_CYBER_MAGENTA, 0.014 + (1.0 - pulse) * 0.010), 1.0, true)
	var scanline_count: int = _get_lod_count(
		STAGE1_CYBER_SCANLINE_COUNT,
		STAGE1_CYBER_SCANLINE_COUNT_LOD,
		STAGE1_CYBER_SCANLINE_COUNT_SEVERE_LOD,
		quality_scale
	)
	for idx in range(scanline_count):
		var ratio: float = (float(idx) + 1.0) / float(scanline_count + 1)
		var y: float = height * ratio
		var alpha: float = 0.007 + 0.006 * sin(float(idx) * 1.73 + pulse * TAU)
		canvas.draw_line(Vector2(0.0, y), Vector2(width, y), _with_alpha(STAGE1_CYBER_CYAN, alpha), 1.0, true)
	_draw_stage1_signal_glitches(canvas, width, height, pulse, quality_scale)
	_draw_stage1_circuit_ticks(canvas, width, height, pulse, quality_scale)


func _draw_stage1_ominous_shadow(canvas: CanvasItem, width: float, height: float, pulse: float, quality_scale: float) -> void:
	var steps: int = _get_lod_count(
		STAGE1_OMINOUS_SHADOW_STEPS,
		STAGE1_OMINOUS_SHADOW_STEPS_LOD,
		STAGE1_OMINOUS_SHADOW_STEPS_SEVERE_LOD,
		quality_scale
	)
	var top_span: float = height * 0.20
	var side_span: float = width * 0.16
	for idx in range(steps):
		var t: float = 1.0 - float(idx) / float(steps)
		var alpha: float = (0.040 + pulse * 0.010) * t * t
		var top_y: float = (top_span / float(steps)) * float(idx)
		var top_h: float = float(max(1.0, top_span / float(steps) + 1.0))
		var side_x: float = (side_span / float(steps)) * float(idx)
		var side_w: float = float(max(1.0, side_span / float(steps) + 1.0))
		var color := Color(0.0, 2.0 / 255.0, 8.0 / 255.0, alpha)
		canvas.draw_rect(Rect2(0.0, top_y, width, top_h), color)
		canvas.draw_rect(Rect2(0.0, height - top_y - top_h, width, top_h), color)
		canvas.draw_rect(Rect2(side_x, 0.0, side_w, height), color)
		canvas.draw_rect(Rect2(width - side_x - side_w, 0.0, side_w, height), color)


func _draw_stage1_signal_glitches(canvas: CanvasItem, width: float, height: float, pulse: float, quality_scale: float) -> void:
	var glitch_count: int = _get_lod_count(
		STAGE1_CYBER_GLITCH_BAND_COUNT,
		STAGE1_CYBER_GLITCH_BAND_COUNT_LOD,
		STAGE1_CYBER_GLITCH_BAND_COUNT_SEVERE_LOD,
		quality_scale
	)
	if glitch_count <= 0:
		return
	var now: float = float(Time.get_ticks_msec()) * 0.001
	for idx in range(glitch_count):
		var phase: float = now * (0.57 + float(idx) * 0.09) + float(idx) * 2.31
		var flicker: float = float(max(0.0, sin(phase * 3.0)))
		if flicker < 0.44:
			continue
		var x: float = fposmod(sin(phase) * 0.5 + 0.5 + float(idx) * 0.173, 1.0) * width
		var y: float = height * (0.16 + 0.68 * fposmod(cos(phase * 0.73) * 0.5 + 0.5, 1.0))
		var band_w: float = 18.0 + 10.0 * sin(phase * 1.7)
		var band_h: float = 2.0 + float(idx % 3)
		var dark_alpha: float = (0.040 + 0.025 * flicker) * clamp(quality_scale, 0.55, 1.0)
		canvas.draw_rect(Rect2(x - band_w * 0.5, y - band_h * 0.5, band_w, band_h), Color(0.0, 0.0, 0.0, dark_alpha))
		var neon_color := STAGE1_CYBER_CYAN if idx % 2 == 0 else STAGE1_CYBER_MAGENTA
		var offset: float = 2.0 + float(idx % 2)
		canvas.draw_line(
			Vector2(x - band_w * 0.55, y - offset),
			Vector2(x + band_w * 0.35, y - offset),
			_with_alpha(neon_color, (0.040 + pulse * 0.020) * flicker),
			1.0,
			true
		)


func _draw_stage1_circuit_ticks(canvas: CanvasItem, width: float, height: float, pulse: float, quality_scale: float) -> void:
	var tick_count: int = _get_lod_count(
		STAGE1_CYBER_CIRCUIT_TICK_COUNT,
		STAGE1_CYBER_CIRCUIT_TICK_COUNT_LOD,
		STAGE1_CYBER_CIRCUIT_TICK_COUNT_SEVERE_LOD,
		quality_scale
	)
	var alpha_cyan: float = 0.030 + pulse * 0.014
	var alpha_magenta: float = 0.024 + (1.0 - pulse) * 0.012
	for idx in range(tick_count):
		var ratio: float = (float(idx) + 1.0) / float(tick_count + 1)
		var y: float = height * ratio
		var tick_len: float = 11.0 + float(idx % 3) * 6.0
		var left_color := _with_alpha(STAGE1_CYBER_CYAN, alpha_cyan * (0.72 + 0.08 * float(idx % 2)))
		var right_color := _with_alpha(STAGE1_CYBER_MAGENTA, alpha_magenta * (0.68 + 0.10 * float((idx + 1) % 2)))
		canvas.draw_line(Vector2(20.0, y), Vector2(20.0 + tick_len, y), left_color, 1.0, true)
		canvas.draw_line(Vector2(width - 20.0 - tick_len, y + 3.0), Vector2(width - 20.0, y + 3.0), right_color, 1.0, true)
		if idx % 2 == 0:
			canvas.draw_line(Vector2(20.0 + tick_len, y), Vector2(20.0 + tick_len, y + 7.0), left_color, 1.0, true)
		else:
			canvas.draw_line(Vector2(width - 20.0 - tick_len, y - 4.0), Vector2(width - 20.0 - tick_len, y + 3.0), right_color, 1.0, true)


func _draw_stage1_danjeong_border(canvas: CanvasItem, width: float, height: float, quality_scale: float) -> void:
	var lod_active: bool = _is_lod_active(quality_scale)
	var bt := STAGE1_BORDER_THICKNESS
	var wood_deep := _rgb(35.0, 18.0, 8.0)
	var wood_dark := _rgb(55.0, 28.0, 14.0)
	var wood_mid := _rgb(75.0, 42.0, 22.0)
	var gold_dim := _rgb(130.0, 100.0, 35.0)
	var gold := _rgb(190.0, 150.0, 55.0)
	var gold_bright := _rgb(220.0, 185.0, 80.0)
	var red := _rgb(175.0, 45.0, 35.0)
	var red_dark := _rgb(120.0, 30.0, 25.0)
	var green := _rgb(35.0, 115.0, 65.0)
	var green_dark := _rgb(25.0, 80.0, 45.0)
	var blue := _rgb(40.0, 65.0, 145.0)
	var blue_dark := _rgb(30.0, 45.0, 100.0)
	var yellow := _rgb(200.0, 165.0, 55.0)

	_draw_border_bands(canvas, width, height, bt, wood_deep, wood_dark, wood_mid)
	canvas.draw_rect(Rect2(0.0, 0.0, width, height), gold_dim, false, 2.0)
	canvas.draw_rect(Rect2(bt - 2.0, bt - 2.0, width - 2.0 * (bt - 2.0), height - 2.0 * (bt - 2.0)), gold, false, 2.0)

	var color_pairs := [
		{"main": red, "dark": red_dark},
		{"main": green, "dark": green_dark},
		{"main": blue, "dark": blue_dark},
	]
	var spacing := STAGE1_BORDER_MARK_SPACING_SEVERE_LOD if _is_severe_lod_active(quality_scale) else STAGE1_BORDER_MARK_SPACING_LOD if lod_active else STAGE1_BORDER_MARK_SPACING
	var idx := 0
	for x in range(spacing, int(width) - spacing, spacing):
		var pair: Dictionary = color_pairs[idx % color_pairs.size()]
		_draw_thick_thunder(canvas, float(x), bt * 0.5, pair["main"], pair["dark"], true, lod_active)
		_draw_thick_thunder(canvas, float(x), height - bt * 0.5, pair["main"], pair["dark"], true, lod_active)
		if not lod_active and idx % 3 == 2 and x + spacing < width:
			var dx := float(x) + float(spacing) * 0.5
			canvas.draw_rect(Rect2(dx - 1.0, bt * 0.5 - 2.0, 2.0, 1.0), gold_bright)
			canvas.draw_rect(Rect2(dx - 1.0, height - bt * 0.5 + 1.0, 2.0, 1.0), gold_bright)
		idx += 1

	idx = 0
	for y in range(spacing, int(height) - spacing, spacing):
		var pair: Dictionary = color_pairs[idx % color_pairs.size()]
		_draw_thick_thunder(canvas, bt * 0.5, float(y), pair["main"], pair["dark"], false, lod_active)
		_draw_thick_thunder(canvas, width - bt * 0.5, float(y), pair["main"], pair["dark"], false, lod_active)
		if not lod_active and idx % 3 == 2 and y + spacing < height:
			var dy := float(y) + float(spacing) * 0.5
			canvas.draw_rect(Rect2(bt * 0.5 - 2.0, dy - 1.0, 1.0, 2.0), gold_bright)
			canvas.draw_rect(Rect2(width - bt * 0.5 + 1.0, dy - 1.0, 1.0, 2.0), gold_bright)
		idx += 1

	for corner in [Vector2(bt * 0.5, bt * 0.5), Vector2(width - bt * 0.5, bt * 0.5), Vector2(bt * 0.5, height - bt * 0.5), Vector2(width - bt * 0.5, height - bt * 0.5)]:
		canvas.draw_circle(corner, 5.0, _rgba(220.0, 185.0, 80.0, 45.0))
		canvas.draw_arc(
			corner,
			5.0,
			0.0,
			TAU,
			STAGE1_BORDER_CORNER_ARC_SEGMENTS_LOD if lod_active else STAGE1_BORDER_CORNER_ARC_SEGMENTS,
			gold_bright,
			2.0
		)
		if lod_active:
			canvas.draw_rect(Rect2(corner - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), yellow)
		else:
			for petal in [Vector2(-3.0, -1.0), Vector2(3.0, -1.0), Vector2(-1.0, -3.0), Vector2(-1.0, 3.0)]:
				canvas.draw_rect(Rect2(corner + petal, Vector2(2.0, 2.0)), red)
			for petal in [Vector2(-2.0, -2.0), Vector2(2.0, -2.0), Vector2(-2.0, 2.0), Vector2(2.0, 2.0)]:
				canvas.draw_rect(Rect2(corner + petal, Vector2(2.0, 2.0)), yellow)


func _draw_stage1_wall_contact_flash(canvas: CanvasItem, context: Dictionary, width: float, height: float, shake_offset: Vector2, quality_scale: float) -> void:
	var timer: float = float(context.get("stage1_wall_flash_timer", 0.0))
	if timer <= 0.0:
		return

	var duration: float = max(0.001, float(context.get("stage1_wall_flash_duration", STAGE1_WALL_FLASH_DURATION_SEC)))
	var ratio: float = clamp(timer / duration, 0.0, 1.0)
	if ratio <= 0.0:
		return

	var base_alpha: float = 0.105 * ratio
	var gradient_steps: int = _get_lod_count(
		STAGE1_WALL_FLASH_GRADIENT_STEPS,
		STAGE1_WALL_FLASH_GRADIENT_STEPS_LOD,
		STAGE1_WALL_FLASH_GRADIENT_STEPS_SEVERE_LOD,
		quality_scale
	)
	for i in range(gradient_steps):
		var edge_t: float = 1.0 - float(i) / float(gradient_steps)
		var edge_alpha: float = base_alpha * edge_t * edge_t
		if edge_alpha <= 0.001:
			continue
		var color := Color(140.0 / 255.0, 100.0 / 255.0, 30.0 / 255.0, edge_alpha)
		var inset := float(i)
		canvas.draw_rect(Rect2(shake_offset.x, shake_offset.y + inset, width, 1.0), color)
		canvas.draw_rect(Rect2(shake_offset.x, shake_offset.y + height - 1.0 - inset, width, 1.0), color)
		canvas.draw_rect(Rect2(shake_offset.x + inset, shake_offset.y, 1.0, height), color)
		canvas.draw_rect(Rect2(shake_offset.x + width - 1.0 - inset, shake_offset.y, 1.0, height), color)

	var side: String = str(context.get("stage1_wall_flash_side", "")).strip_edges().to_lower()
	var impact_pos: Vector2 = _as_vector2(
		context.get("stage1_wall_flash_position", Vector2(width * 0.5, height * 0.5)),
		Vector2(width * 0.5, height * 0.5)
	)
	if side != "left" and side != "right":
		side = "left" if impact_pos.x <= width * 0.5 else "right"
	if side != "left" and side != "right":
		return

	var speed_scale: float = clamp(float(context.get("stage1_wall_flash_speed", 0.0)) / 35.0, 0.75, 1.45)
	var side_dir := 1.0 if side == "left" else -1.0
	var wall_x := 4.0 if side == "left" else width - 4.0
	var spark_y: float = clamp(
		impact_pos.y,
		STAGE1_BORDER_THICKNESS + 8.0,
		height - STAGE1_BORDER_THICKNESS - 8.0
	)

	var side_strip_steps: int = _get_lod_count(
		STAGE1_WALL_FLASH_SIDE_STRIP_STEPS,
		STAGE1_WALL_FLASH_SIDE_STRIP_STEPS_LOD,
		STAGE1_WALL_FLASH_SIDE_STRIP_STEPS_SEVERE_LOD,
		quality_scale
	)
	for i in range(side_strip_steps):
		var side_t: float = 1.0 - float(i) / float(side_strip_steps)
		var side_alpha: float = 0.060 * ratio * side_t * side_t
		var x: float = float(i) if side == "left" else width - 1.0 - float(i)
		canvas.draw_rect(
			Rect2(shake_offset.x + x, shake_offset.y, 1.0, height),
			Color(1.0, 0.78, 0.27, side_alpha)
		)

	var line_x := STAGE1_BORDER_THICKNESS * 0.5 if side == "left" else width - STAGE1_BORDER_THICKNESS * 0.5
	canvas.draw_line(
		Vector2(line_x, 0.0) + shake_offset,
		Vector2(line_x, height) + shake_offset,
		Color(1.0, 0.84, 0.36, 0.18 * ratio),
		2.0 + 1.4 * speed_scale,
		true
	)

	_draw_stage1_wall_flash_sparkle(canvas, Vector2(wall_x, spark_y) + shake_offset, side_dir, ratio, speed_scale, quality_scale)
	_draw_stage1_wall_flash_satellites(canvas, Vector2(wall_x, spark_y) + shake_offset, side_dir, ratio, speed_scale, height, quality_scale)


func _draw_stage1_wall_flash_sparkle(canvas: CanvasItem, center: Vector2, side_dir: float, ratio: float, speed_scale: float, quality_scale: float) -> void:
	var core_alpha: float = min(0.56, 0.32 * ratio * speed_scale)
	var glow_alpha: float = min(0.28, 0.16 * ratio * speed_scale)
	canvas.draw_circle(center, 8.0 * ratio * speed_scale, Color(1.0, 0.78, 0.22, glow_alpha))
	canvas.draw_circle(center, 2.0 + 2.4 * ratio, Color(1.0, 0.96, 0.70, core_alpha))

	var horizontal_len: float = 22.0 * ratio * speed_scale
	var vertical_len: float = 13.0 * ratio * speed_scale
	var main_color := Color(1.0, 0.91, 0.48, min(0.64, 0.44 * ratio * speed_scale))
	var side_tail := Vector2(-side_dir * 4.0, 0.0)
	var inward := Vector2(side_dir * horizontal_len, 0.0)
	canvas.draw_line(center + side_tail, center + inward, main_color, 2.0, true)
	canvas.draw_line(center + Vector2(0.0, -vertical_len), center + Vector2(0.0, vertical_len), main_color, 1.6, true)
	if _is_lod_active(quality_scale):
		return
	canvas.draw_line(
		center + Vector2(-side_dir * 2.0, -vertical_len * 0.55),
		center + Vector2(side_dir * horizontal_len * 0.58, vertical_len * 0.55),
		Color(1.0, 1.0, 0.86, 0.30 * ratio),
		1.0,
		true
	)
	canvas.draw_line(
		center + Vector2(-side_dir * 2.0, vertical_len * 0.55),
		center + Vector2(side_dir * horizontal_len * 0.58, -vertical_len * 0.55),
		Color(1.0, 1.0, 0.86, 0.30 * ratio),
		1.0,
		true
	)


func _draw_stage1_wall_flash_satellites(canvas: CanvasItem, center: Vector2, side_dir: float, ratio: float, speed_scale: float, height: float, quality_scale: float) -> void:
	var now: float = float(Time.get_ticks_msec()) * 0.018
	var satellite_count: int = _get_lod_count(
		STAGE1_WALL_FLASH_SATELLITE_COUNT,
		STAGE1_WALL_FLASH_SATELLITE_COUNT_LOD,
		STAGE1_WALL_FLASH_SATELLITE_COUNT_SEVERE_LOD,
		quality_scale
	)
	for i in range(satellite_count):
		var phase: float = now + float(i) * 1.67
		var y: float = clamp(center.y + sin(phase) * 26.0 + (float(i) - 1.5) * 13.0, 18.0, height - 18.0)
		var x: float = center.x + side_dir * (7.0 + float(i % 2) * 4.0)
		var pulse: float = 0.55 + 0.45 * sin(phase * 1.9)
		var size: float = (2.0 + float(i % 2)) * ratio * speed_scale
		if size <= 0.4:
			continue
		var alpha: float = (0.12 + 0.18 * pulse) * ratio
		var pos := Vector2(x, y)
		var color := Color(1.0, 0.91, 0.48, alpha)
		canvas.draw_line(pos + Vector2(-size, 0.0), pos + Vector2(size, 0.0), color, 1.0, true)
		canvas.draw_line(pos + Vector2(0.0, -size), pos + Vector2(0.0, size), color, 1.0, true)


func _draw_border_bands(canvas: CanvasItem, width: float, height: float, bt: float, wood_deep: Color, wood_dark: Color, wood_mid: Color) -> void:
	for rect in [
		Rect2(0.0, 0.0, width, bt),
		Rect2(0.0, height - bt, width, bt),
		Rect2(0.0, 0.0, bt, height),
		Rect2(width - bt, 0.0, bt, height),
	]:
		canvas.draw_rect(rect, wood_deep)
	for rect in [
		Rect2(1.0, 1.0, width - 2.0, bt - 2.0),
		Rect2(1.0, height - bt + 1.0, width - 2.0, bt - 2.0),
		Rect2(1.0, 1.0, bt - 2.0, height - 2.0),
		Rect2(width - bt + 1.0, 1.0, bt - 2.0, height - 2.0),
	]:
		canvas.draw_rect(rect, wood_dark)
	for rect in [
		Rect2(2.0, 2.0, width - 4.0, bt - 4.0),
		Rect2(2.0, height - bt + 2.0, width - 4.0, bt - 4.0),
		Rect2(2.0, 2.0, bt - 4.0, height - 4.0),
		Rect2(width - bt + 2.0, 2.0, bt - 4.0, height - 4.0),
	]:
		canvas.draw_rect(rect, wood_mid)


func _draw_thick_thunder(canvas: CanvasItem, sx: float, sy: float, color: Color, color_dark: Color, horizontal: bool, lod_active: bool = false) -> void:
	var s := 3.0
	var w := 2.0
	if lod_active:
		if horizontal:
			canvas.draw_rect(Rect2(sx - s, sy - w * 0.5, s * 2.0 + 1.0, w), color)
			canvas.draw_rect(Rect2(sx - s, sy + s - 1.0, s * 2.0 + 1.0, 1.0), color_dark)
		else:
			canvas.draw_rect(Rect2(sx - w * 0.5, sy - s, w, s * 2.0 + 1.0), color)
			canvas.draw_rect(Rect2(sx + s - 1.0, sy - s, 1.0, s * 2.0 + 1.0), color_dark)
		return
	if horizontal:
		canvas.draw_rect(Rect2(sx - s, sy - s, s * 2.0 + 1.0, w), color)
		canvas.draw_rect(Rect2(sx + s - 1.0, sy - s, w, s + w), color)
		canvas.draw_rect(Rect2(sx - s, sy, s * 2.0, w), color)
		canvas.draw_rect(Rect2(sx - s, sy, w, s + 1.0), color)
		canvas.draw_rect(Rect2(sx - s, sy + s - 1.0, s * 2.0 + 1.0, 1.0), color_dark)
	else:
		canvas.draw_rect(Rect2(sx - s, sy - s, w, s * 2.0 + 1.0), color)
		canvas.draw_rect(Rect2(sx - s, sy + s - 1.0, s + w, w), color)
		canvas.draw_rect(Rect2(sx, sy - s, w, s * 2.0), color)
		canvas.draw_rect(Rect2(sx, sy - s, s + 1.0, w), color)
		canvas.draw_rect(Rect2(sx + s - 1.0, sy - s, 1.0, s * 2.0 + 1.0), color_dark)


func _draw_stadium_electric_flow(canvas: CanvasItem, width: float, height: float, quality_scale: float) -> void:
	var now_sec: float = float(Time.get_ticks_msec()) * 0.001
	if stadium_spark_next_time_sec < 0.0:
		stadium_spark_next_time_sec = now_sec + randf_range(
			STADIUM_SPARK_MIN_INTERVAL_SEC,
			STADIUM_SPARK_MAX_INTERVAL_SEC
		)

	if stadium_spark_active_start_sec < 0.0:
		if now_sec < stadium_spark_next_time_sec:
			return
		stadium_spark_active_start_sec = now_sec
		stadium_spark_cycle_index += 1
		stadium_spark_direction = -1.0 if stadium_spark_cycle_index % 2 == 1 else 1.0

	var burst_time: float = now_sec - stadium_spark_active_start_sec
	if burst_time >= STADIUM_SPARK_BURST_DURATION_SEC:
		stadium_spark_active_start_sec = -1.0
		stadium_spark_next_time_sec = now_sec + randf_range(
			STADIUM_SPARK_MIN_INTERVAL_SEC,
			STADIUM_SPARK_MAX_INTERVAL_SEC
		)
		return

	var line_y: float = height * 0.5
	var start_x := 0.0
	var end_x: float = max(1.0, width - 1.0)
	var span: float = max(1.0, end_x - start_x)
	var pulse: float = burst_time / STADIUM_SPARK_BURST_DURATION_SEC
	var travel: float = pulse * pulse * (3.0 - 2.0 * pulse)
	if stadium_spark_direction < 0.0:
		travel = 1.0 - travel

	var head_x: float = start_x + span * travel
	var strength: float = sin(pulse * PI)
	var main_alpha: float = 72.0 + 70.0 * strength
	var branch_alpha: float = 42.0 + 48.0 * strength
	var point_step: float = STADIUM_SPARK_POINT_STEP_SEVERE_LOD if _is_severe_lod_active(quality_scale) else STADIUM_SPARK_POINT_STEP_LOD if _is_lod_active(quality_scale) else STADIUM_SPARK_POINT_STEP
	var tail_len := 96.0
	var head_lead := 10.0
	var bolt_start: float
	var bolt_end: float
	if stadium_spark_direction > 0.0:
		bolt_start = max(start_x, head_x - tail_len)
		bolt_end = min(end_x, head_x + head_lead)
	else:
		bolt_start = max(start_x, head_x - head_lead)
		bolt_end = min(end_x, head_x + tail_len)

	var points: Array[Vector2] = []
	var px := bolt_start
	var idx := 0
	while px <= bolt_end:
		var jitter_seed: float = px * 0.34 + float(stadium_spark_cycle_index) * 1.9
		var jitter: float = sin(jitter_seed) * 3.0 + sin(jitter_seed * 1.8) * 1.6
		if idx % 2 == 1:
			jitter += 2.0 if stadium_spark_direction > 0.0 else -2.0
		points.append(Vector2(px, line_y + jitter))
		px += point_step
		idx += 1

	for point_idx in range(points.size() - 1):
		canvas.draw_line(points[point_idx], points[point_idx + 1], _rgba(38.0, 214.0, 224.0, main_alpha), 2.0)

	for point_idx in range(0, max(0, points.size() - 2), 2):
		canvas.draw_line(points[point_idx], points[point_idx + 2], _rgba(224.0, 82.0, 142.0, branch_alpha), 1.0)

	canvas.draw_circle(Vector2(head_x, line_y), 3.0, _rgba(80.0, 232.0, 236.0, 86.0 + 50.0 * strength))

	var branch_count: int = _get_lod_count(
		STADIUM_SPARK_BRANCH_COUNT,
		STADIUM_SPARK_BRANCH_COUNT_LOD,
		STADIUM_SPARK_BRANCH_COUNT_SEVERE_LOD,
		quality_scale
	)
	for branch_idx in range(branch_count):
		var branch_dir := -1.0 if branch_idx % 2 == 1 else 1.0
		var branch_x: float = head_x - stadium_spark_direction * (8.0 + float(branch_idx) * 10.0)
		if branch_x < start_x or branch_x > end_x:
			continue
		@warning_ignore("shadowed_global_identifier")
		var seed: float = float(stadium_spark_cycle_index) * 2.31 + float(branch_idx) * 1.17
		var branch_len: float = 10.0 + 5.0 * sin(seed)
		var branch_y: float = line_y + branch_dir * (3.0 + 3.0 * cos(seed))
		var branch_end := Vector2(
			branch_x - stadium_spark_direction * branch_len,
			branch_y + branch_dir * (9.0 + float(branch_idx))
		)
		canvas.draw_line(Vector2(branch_x, branch_y), branch_end, _rgba(68.0, 224.0, 232.0, branch_alpha), 1.0)

	var spark_count: int = _get_lod_count(
		STADIUM_SPARK_TRAIL_SPARK_COUNT,
		STADIUM_SPARK_TRAIL_SPARK_COUNT_LOD,
		STADIUM_SPARK_TRAIL_SPARK_COUNT_SEVERE_LOD,
		quality_scale
	)
	for spark_idx in range(spark_count):
		var spark_x: float = head_x - stadium_spark_direction * (14.0 + float(spark_idx) * 18.0)
		if spark_x < start_x or spark_x > end_x:
			continue
		var spark_seed: float = float(stadium_spark_cycle_index) * 4.11 + float(spark_idx) * 1.73
		var spark_y: float = line_y + sin(spark_seed) * 18.0
		canvas.draw_circle(
			Vector2(spark_x, spark_y),
			1.0 + float(spark_idx % 2),
			_rgba(80.0, 232.0, 236.0, 48.0 + 44.0 * strength)
		)

	var center_x: float = width * 0.5
	if abs(head_x - center_x) < STADIUM_CIRCLE_RADIUS + 36.0:
		var base_angle := PI if stadium_spark_direction > 0.0 else 0.0
		var angle: float = base_angle + (travel - 0.5) * 1.2
		canvas.draw_arc(
			Vector2(center_x, line_y),
			STADIUM_CIRCLE_RADIUS,
			angle - 0.22,
			angle + 0.28,
			10 if _is_severe_lod_active(quality_scale) else 16 if _is_lod_active(quality_scale) else 24,
			_rgba(48.0, 212.0, 222.0, 46.0 + 36.0 * strength),
			2.0
		)
		canvas.draw_arc(
			Vector2(center_x, line_y),
			STADIUM_CIRCLE_RADIUS,
			angle + 0.44,
			angle + 0.62,
			8 if _is_severe_lod_active(quality_scale) else 12 if _is_lod_active(quality_scale) else 18,
			_rgba(218.0, 82.0, 142.0, 24.0 + 25.0 * strength),
			1.0
		)


func _draw_grid_particles(canvas: CanvasItem, width: float, height: float, quality_scale: float) -> void:
	_ensure_grid_particles(width, height)
	if grid_particles.is_empty():
		return
	var now_sec: float = float(Time.get_ticks_msec()) * 0.001
	var half_h: float = max(1.0, height * 0.5)
	var particle_count: int = _get_lod_count(grid_particles.size(), GRID_PARTICLE_COUNT_LOD, GRID_PARTICLE_COUNT_SEVERE_LOD, quality_scale)
	var start_index: int = 0
	if _is_lod_active(quality_scale):
		start_index = int(floor(now_sec * 12.0)) % max(1, grid_particles.size())
	for particle_idx in range(particle_count):
		var particle: Vector4 = grid_particles[(start_index + particle_idx) % grid_particles.size()]
		var speed: float = particle.z
		var phase: float = particle.y
		var y: float = height - fmod(now_sec * GRID_PARTICLE_FPS_SPEED * speed + phase, half_h)
		var alpha: float = 100.0 * (1.0 - (y - half_h) / half_h)
		if alpha <= 0.0:
			continue
		canvas.draw_circle(
			Vector2(particle.x, y),
			particle.w,
			_rgba(25.0, 25.0, 150.0, alpha)
		)


func _ensure_grid_particles(width: float, height: float) -> void:
	var layout_size := Vector2(width, height)
	if grid_particles.size() == GRID_PARTICLE_COUNT and grid_particle_layout_size == layout_size:
		return
	grid_particles.clear()
	grid_particle_layout_size = layout_size
	var rng := RandomNumberGenerator.new()
	rng.seed = 1831
	var half_h: float = max(1.0, height * 0.5)
	for _i in range(GRID_PARTICLE_COUNT):
		grid_particles.append(Vector4(
			rng.randf_range(0.0, width),
			rng.randf_range(0.0, half_h),
			rng.randf_range(0.5, 2.0),
			float(rng.randi_range(1, 3))
		))


func draw_dash_trail(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	if canvas == null:
		return

	var now_msec: int = Time.get_ticks_msec()
	var quality_scale: float = _get_playfield_quality_scale(context)
	if bool(context.get("dash_active", false)):
		_capture_dash_afterimage(context, now_msec, quality_scale)
	if dash_afterimages.is_empty():
		return
	_draw_dash_afterimages(canvas, shake_offset, now_msec)


func _capture_dash_afterimage(context: Dictionary, now_msec: int, quality_scale: float) -> void:
	var spawn_interval: int = DASH_AFTERIMAGE_LOD_SPAWN_INTERVAL_MSEC if _is_lod_active(quality_scale) else DASH_AFTERIMAGE_SPAWN_INTERVAL_MSEC
	if now_msec - dash_afterimage_last_spawn_msec < spawn_interval and not dash_afterimages.is_empty():
		return
	var uses_directional_walk := false
	var sprite_texture = context.get("player_sprite_texture", null)
	var directional_texture = _get_player_directional_walk_texture(context)
	if directional_texture is Texture2D:
		uses_directional_walk = true
		sprite_texture = directional_texture
	if not (sprite_texture is Texture2D):
		return
	var dash_timer: float = max(0.0, float(context.get("dash_timer", 0.0)))
	if dash_timer <= 0.0:
		return
	var base_alpha: float = min(DASH_AFTERIMAGE_MAX_ALPHA, DASH_AFTERIMAGE_MAX_ALPHA * (dash_timer / 15.0))
	dash_afterimages.append({
		"texture": sprite_texture,
		"source_rect": _get_player_directional_walk_region(context) if uses_directional_walk else _get_player_sprite_region(context),
		"draw_rect": _get_player_afterimage_rect(context, uses_directional_walk),
		"base_alpha": base_alpha,
		"spawn_msec": now_msec,
	})
	var afterimage_cap: int = DASH_AFTERIMAGE_LOD_MAX_COUNT if _is_lod_active(quality_scale) else DASH_AFTERIMAGE_MAX_COUNT
	while dash_afterimages.size() > afterimage_cap:
		dash_afterimages.pop_front()
	dash_afterimage_last_spawn_msec = now_msec


func _draw_dash_afterimages(canvas: CanvasItem, shake_offset: Vector2, now_msec: int) -> void:
	var write_idx := 0
	for i in range(dash_afterimages.size()):
		var afterimage: Dictionary = dash_afterimages[i]
		var spawn_msec: int = int(afterimage.get("spawn_msec", now_msec))
		var age_msec: float = float(now_msec - spawn_msec)
		var life_ratio: float = clamp(1.0 - age_msec / DASH_AFTERIMAGE_LIFETIME_MSEC, 0.0, 1.0)
		if life_ratio <= 0.0:
			continue
		var texture = afterimage.get("texture", null)
		if not (texture is Texture2D):
			continue
		var texture_typed: Texture2D = texture
		var draw_rect: Rect2 = _as_rect2(afterimage.get("draw_rect", Rect2()), Rect2())
		if draw_rect.size.x <= 0.0 or draw_rect.size.y <= 0.0:
			continue
		draw_rect.position += shake_offset
		var alpha: float = clamp(float(afterimage.get("base_alpha", DASH_AFTERIMAGE_MAX_ALPHA)) * life_ratio, 0.0, 1.0)
		canvas.draw_texture_rect_region(
			texture_typed,
			draw_rect,
			_as_rect2(afterimage.get("source_rect", Rect2()), Rect2(Vector2.ZERO, texture_typed.get_size())),
			Color(1.0, 1.0, 1.0, alpha),
			false,
			true
		)
		dash_afterimages[write_idx] = afterimage
		write_idx += 1
	dash_afterimages.resize(write_idx)


func _get_player_afterimage_rect(context: Dictionary, uses_directional_walk: bool = false) -> Rect2:
	var player_pos: Vector2 = _as_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
	var paddle_size: Vector2 = _as_vector2(context.get("player_paddle_size", Vector2(84.0, 16.0)), Vector2(84.0, 16.0))
	var player_anim_clock: float = float(context.get("player_anim_clock", 0.0))
	var smasher_body_motion: bool = _uses_smasher_body_motion(context)
	var hover_amplitude: float = float(context.get("player_hover_amplitude", 7.0)) if smasher_body_motion else 0.0
	var hover_wave: float = sin(player_anim_clock * float(context.get("player_hover_speed", 4.5)))
	var hover_offset: float = hover_wave * hover_amplitude
	var move_bob_amplitude: float = float(context.get("player_move_bob_amplitude", 5.0)) if smasher_body_motion else 0.0
	var move_bob: float = abs(sin(player_anim_clock * 10.0)) * move_bob_amplitude
	var player_draw_size: Vector2 = _as_vector2(context.get("player_sprite_draw_size", Vector2(250.0, 120.0)), Vector2(250.0, 120.0))
	if uses_directional_walk:
		player_draw_size = _as_vector2(
			context.get("player_directional_walk_draw_size", DEFAULT_PLAYER_DIRECTIONAL_WALK_DRAW_SIZE),
			DEFAULT_PLAYER_DIRECTIONAL_WALK_DRAW_SIZE
		)
	var player_paddle_scale: float = max(0.1, float(context.get("player_paddle_scale", max(1.0, paddle_size.x / 155.0))))
	player_draw_size *= player_paddle_scale
	var player_visual_y_offset: float = -hover_offset - move_bob
	return Rect2(
		player_pos.x + paddle_size.x * 0.5 - player_draw_size.x * 0.5,
		player_pos.y + paddle_size.y - player_draw_size.y + 12.0 + player_visual_y_offset,
		player_draw_size.x,
		player_draw_size.y
	)


func _get_player_sprite_region(context: Dictionary) -> Rect2:
	var frame_x: float = float(context.get("player_sprite_frame_width", 250.0)) * float(context.get("player_sprite_frame", 0))
	return Rect2(frame_x, 0.0, float(context.get("player_sprite_frame_width", 250.0)), float(context.get("player_sprite_frame_height", 120.0)))


func _get_player_directional_walk_texture(context: Dictionary) -> Variant:
	var direction: int = int(context.get("player_walk_direction", 1))
	var texture_key := "player_walk_left_texture" if direction < 0 else "player_walk_right_texture"
	return context.get(texture_key, null)


func _get_player_directional_walk_region(context: Dictionary) -> Rect2:
	var cell_w: float = float(context.get("player_directional_walk_cell_width", 160.0))
	var cell_h: float = float(context.get("player_directional_walk_cell_height", 160.0))
	var grid_cols: int = max(1, int(context.get("player_directional_walk_grid_cols", DEFAULT_PLAYER_DIRECTIONAL_WALK_GRID_COLS)))
	var max_frame: int = max(0, int(context.get("player_directional_walk_frame_count", DEFAULT_PLAYER_DIRECTIONAL_WALK_FRAME_COUNT)) - 1)
	var frame: int = clamp(int(context.get("player_sprite_frame", 0)), 0, max_frame)
	var col: int = frame % grid_cols
	@warning_ignore("integer_division")
	var row: int = int(frame / grid_cols)
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)


func _as_vector2(value, fallback: Vector2) -> Vector2:
	return Stage1ContextReader.as_vector2(value, fallback)


func _uses_smasher_body_motion(context: Dictionary) -> bool:
	var character_type: String = str(context.get("selected_character_type", "smasher")).strip_edges().to_lower()
	return character_type == "" or character_type == "smasher" or character_type == "ufo_player"


func _as_color(value, fallback: Color) -> Color:
	return Stage1ContextReader.as_color(value, fallback)


func _get_playfield_quality_scale(context: Dictionary) -> float:
	return BattleRenderQuality.effect_scale(context)


func _is_lod_active(quality_scale: float) -> bool:
	return quality_scale < 0.85


func _is_severe_lod_active(quality_scale: float) -> bool:
	return quality_scale < 0.66


func _get_lod_count(base_count: int, lod_count: int, severe_lod_count: int, quality_scale: float) -> int:
	if _is_severe_lod_active(quality_scale):
		return max(0, min(base_count, severe_lod_count))
	if not _is_lod_active(quality_scale):
		return base_count
	return max(0, min(base_count, lod_count))


func _rgb(r: float, g: float, b: float) -> Color:
	return _rgba(r, g, b, 255.0)


func _rgba(r: float, g: float, b: float, a: float) -> Color:
	return Color(r / 255.0, g / 255.0, b / 255.0, clamp(a / 255.0, 0.0, 1.0))


func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clamp(alpha, 0.0, 1.0))


func _as_rect2(value, fallback: Rect2) -> Rect2:
	if value is Rect2:
		return value
	return fallback
