extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const Stage1PillarAmbientState := preload("res://scripts/stages/stage1/stage1_pillar_ambient_state.gd")
const Stage1PillarBackgroundAssets := preload("res://scripts/stages/stage1/stage1_pillar_background_assets.gd")
const Stage1PillarLayerRenderer := preload("res://scripts/stages/stage1/stage1_pillar_layer_renderer.gd")

const HANJI_TEXTURE_PATH := Stage1PillarBackgroundAssets.HANJI_TEXTURE_PATH
const TREE_SPRITE_TEXTURE_PATH := Stage1PillarBackgroundAssets.TREE_SPRITE_TEXTURE_PATH
const CLOUD_SPRITE_TEXTURE_PATH := Stage1PillarBackgroundAssets.CLOUD_SPRITE_TEXTURE_PATH
const BUTTERFLY_SHEET_TEXTURE_PATH := Stage1PillarBackgroundAssets.BUTTERFLY_SHEET_TEXTURE_PATH
const BUTTERFLY_FRAME_COUNT := Stage1PillarBackgroundAssets.BUTTERFLY_FRAME_COUNT
const BUTTERFLY_COLOR_COUNT := Stage1PillarBackgroundAssets.BUTTERFLY_COLOR_COUNT
const PREWARM_TEXTURE_FALLBACK_MSEC := Stage1PillarBackgroundAssets.PREWARM_TEXTURE_FALLBACK_MSEC
const PREWARM_TEXTURE_FALLBACK_POLLS := Stage1PillarBackgroundAssets.PREWARM_TEXTURE_FALLBACK_POLLS
const MOOD_GRADE_COLOR := Color(4.0 / 255.0, 8.0 / 255.0, 22.0 / 255.0, 88.0 / 255.0)
const MOOD_INK_COLOR := Color(0.0, 1.0 / 255.0, 7.0 / 255.0, 52.0 / 255.0)
const MOOD_EDGE_STEPS := 6
const MOOD_EDGE_ALPHA := 48.0 / 255.0
const OMINOUS_CORNER_STEPS := 7
const CYBER_SIGN_SLIT_COUNT := 4
const CYBER_CYAN := Color(0.0, 0.90, 1.0, 1.0)
const CYBER_MAGENTA := Color(1.0, 0.12, 0.76, 1.0)
const LOD_PETAL_STRIDE := 2
const BUTTERFLY_ABSORB_RING_COUNT := 1
const BUTTERFLY_ABSORB_RING_SEGMENTS := 18
const BUTTERFLY_ABSORB_RING_SEGMENTS_LOD := 10
const CRESCENDO_MOOD_ALPHA_MAX := 0.08
const CRESCENDO_SHINE_ALPHA_BOOST_MAX := 0.45
const CRESCENDO_CLOUD_MOTION_BOOST_MAX := 0.10
const CRESCENDO_TREE_OFFSET_MAX_PIXELS := 2.0

var hanji_texture: Texture2D
var tree_sprite_texture: Texture2D
var cloud_sprite_texture: Texture2D
var butterfly_sheet_texture: Texture2D

var ambient_state: Object = Stage1PillarAmbientState.new()
var layer_renderer: Object = Stage1PillarLayerRenderer.new()
var _prewarm_assets_step_index := 0


func _init() -> void:
	ambient_state.init_state()


func _load_textures() -> void:
	hanji_texture = _load_texture_resource(HANJI_TEXTURE_PATH)
	tree_sprite_texture = _load_texture_resource(TREE_SPRITE_TEXTURE_PATH)
	cloud_sprite_texture = _load_texture_resource(CLOUD_SPRITE_TEXTURE_PATH)
	butterfly_sheet_texture = _load_texture_resource(BUTTERFLY_SHEET_TEXTURE_PATH)


func _load_texture_resource(path: String) -> Texture2D:
	return ProjectResourceLoader.load_texture(path)


func prewarm_assets(
	view_size: Vector2 = Vector2(1280.0, 800.0),
	game_offset: Vector2 = Vector2(260.0, 0.0),
	game_size: Vector2 = Vector2(760.0, 750.0)
) -> void:
	while not prewarm_assets_step(view_size, game_offset, game_size):
		pass


func prewarm_assets_step(
	view_size: Vector2 = Vector2(1280.0, 800.0),
	game_offset: Vector2 = Vector2(260.0, 0.0),
	game_size: Vector2 = Vector2(760.0, 750.0)
) -> bool:
	match _prewarm_assets_step_index:
		0:
			var hanji_result: Dictionary = _prewarm_texture_step(HANJI_TEXTURE_PATH)
			if not bool(hanji_result.get("done", true)):
				return false
			hanji_texture = hanji_result.get("texture", hanji_texture) as Texture2D
		1:
			var tree_result: Dictionary = _prewarm_texture_step(TREE_SPRITE_TEXTURE_PATH)
			if not bool(tree_result.get("done", true)):
				return false
			tree_sprite_texture = tree_result.get("texture", tree_sprite_texture) as Texture2D
		2:
			var cloud_result: Dictionary = _prewarm_texture_step(CLOUD_SPRITE_TEXTURE_PATH)
			if not bool(cloud_result.get("done", true)):
				return false
			cloud_sprite_texture = cloud_result.get("texture", cloud_sprite_texture) as Texture2D
		3:
			var butterfly_result: Dictionary = _prewarm_texture_step(BUTTERFLY_SHEET_TEXTURE_PATH)
			if not bool(butterfly_result.get("done", true)):
				return false
			butterfly_sheet_texture = butterfly_result.get("texture", butterfly_sheet_texture) as Texture2D
		4:
			ambient_state.update_layout(view_size, game_offset, game_size)
		5:
			_touch_texture(hanji_texture)
		6:
			_touch_texture(tree_sprite_texture)
		7:
			_touch_texture(cloud_sprite_texture)
		8:
			_touch_texture(butterfly_sheet_texture)
		_:
			_prewarm_assets_step_index = 0
			return true
	_prewarm_assets_step_index += 1
	return false


func reset() -> void:
	ambient_state.reset()


func update(delta: float, context: Dictionary = {}, _deps: Dictionary = {}) -> void:
	ambient_state.update(delta, context)


func consume_butterfly_gauge_recovery() -> bool:
	return ambient_state.consume_gauge_recovery()


func trigger_tree_shake(side: String, impact_y: float, impact_speed: float, field_height: float) -> void:
	ambient_state.trigger_tree_shake(side, impact_y, impact_speed, field_height, layer_renderer)


func draw(
	canvas: CanvasItem,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	field_width: float,
	perf_logger: Object = null,
	quality_scale: float = 1.0,
	director_snapshot: Dictionary = {}
) -> bool:
	ambient_state.update_layout(view_size, game_offset, game_size)
	if hanji_texture == null:
		return false

	var source_size: Vector2 = hanji_texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0 or view_size.x <= 0.0 or view_size.y <= 0.0:
		return false

	var game_rect := Rect2(game_offset, game_size)
	var cover_scale: float = max(view_size.x / source_size.x, view_size.y / source_size.y)
	var target_size: Vector2 = source_size * cover_scale
	var target_pos: Vector2 = (view_size - target_size) * 0.5
	var sample_start: int = _perf_begin(perf_logger)
	canvas.draw_texture_rect(hanji_texture, Rect2(target_pos, target_size), false)
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(1.0, 246.0 / 255.0, 220.0 / 255.0, 16.0 / 255.0))
	_perf_end(perf_logger, "stage1.pillar.bg_base", sample_start)

	var scale_factor: float = game_size.x / max(1.0, field_width)
	var crescendo_cloud_motion: float = _get_crescendo_cloud_motion_multiplier(director_snapshot, quality_scale)
	var crescendo_tree_offset: Vector2 = _get_crescendo_tree_motion_offset(director_snapshot, quality_scale, scale_factor, ambient_state.get_time())
	var crescendo_shine_alpha: float = _get_crescendo_shine_alpha_multiplier(director_snapshot, quality_scale)
	sample_start = _perf_begin(perf_logger)
	layer_renderer.draw_hanji_subtle_borders(canvas, view_size, game_rect, scale_factor)
	_perf_end(perf_logger, "stage1.pillar.bg_borders", sample_start)
	sample_start = _perf_begin(perf_logger)
	layer_renderer.draw_cloud_motion_layers(canvas, cloud_sprite_texture, view_size, game_offset, game_size, scale_factor, ambient_state.get_time(), quality_scale, crescendo_cloud_motion)
	_perf_end(perf_logger, "stage1.pillar.bg_clouds", sample_start)
	sample_start = _perf_begin(perf_logger)
	layer_renderer.draw_tree_motion_layers(canvas, tree_sprite_texture, view_size, game_offset, game_size, scale_factor, ambient_state.get_tree_shakes(), crescendo_tree_offset)
	_perf_end(perf_logger, "stage1.pillar.bg_trees", sample_start)
	sample_start = _perf_begin(perf_logger)
	layer_renderer.draw_tree_drop_petals(canvas, ambient_state.get_tree_drop_petals(), quality_scale)
	layer_renderer.draw_floating_petals(canvas, ambient_state.get_floating_petals(), quality_scale)
	_perf_end(perf_logger, "stage1.pillar.bg_petals", sample_start)
	sample_start = _perf_begin(perf_logger)
	layer_renderer.draw_butterflies(canvas, butterfly_sheet_texture, ambient_state.get_butterflies(), view_size, game_offset, game_size, scale_factor, ambient_state.get_time(), quality_scale)
	_perf_end(perf_logger, "stage1.pillar.bg_butterflies", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_mood_grade(canvas, [Rect2(Vector2.ZERO, view_size)], true, quality_scale, director_snapshot)
	_perf_end(perf_logger, "stage1.pillar.bg_mood_grade", sample_start)
	sample_start = _perf_begin(perf_logger)
	layer_renderer.draw_game_border_shine(canvas, game_rect, scale_factor, ambient_state.get_time(), quality_scale, crescendo_shine_alpha)
	_perf_end(perf_logger, "stage1.pillar.bg_shine", sample_start)
	return true


func draw_pillar_background_overlay(
	canvas: CanvasItem,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	field_width: float,
	perf_logger: Object = null,
	quality_scale: float = 1.0,
	director_snapshot: Dictionary = {}
) -> bool:
	ambient_state.update_layout(view_size, game_offset, game_size)
	if canvas == null or hanji_texture == null:
		return false
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		return false

	var sample_start: int = _perf_begin(perf_logger)
	_draw_hanji_side_regions(canvas, view_size, game_offset, game_size)
	for side_rect in _get_side_rects(view_size, game_offset, game_size):
		if side_rect.size.x > 0.0 and side_rect.size.y > 0.0:
			canvas.draw_rect(side_rect, Color(1.0, 246.0 / 255.0, 220.0 / 255.0, 16.0 / 255.0))
	_perf_end(perf_logger, "stage1.pillar.overlay_base", sample_start)

	var scale_factor: float = game_size.x / max(1.0, field_width)
	var crescendo_cloud_motion: float = _get_crescendo_cloud_motion_multiplier(director_snapshot, quality_scale)
	var crescendo_tree_offset: Vector2 = _get_crescendo_tree_motion_offset(director_snapshot, quality_scale, scale_factor, ambient_state.get_time())
	var crescendo_shine_alpha: float = _get_crescendo_shine_alpha_multiplier(director_snapshot, quality_scale)
	sample_start = _perf_begin(perf_logger)
	layer_renderer.draw_cloud_motion_layers(canvas, cloud_sprite_texture, view_size, game_offset, game_size, scale_factor, ambient_state.get_time(), quality_scale, crescendo_cloud_motion)
	_perf_end(perf_logger, "stage1.pillar.overlay_clouds", sample_start)
	sample_start = _perf_begin(perf_logger)
	layer_renderer.draw_tree_motion_layers(canvas, tree_sprite_texture, view_size, game_offset, game_size, scale_factor, ambient_state.get_tree_shakes(), crescendo_tree_offset)
	_perf_end(perf_logger, "stage1.pillar.overlay_trees", sample_start)
	sample_start = _perf_begin(perf_logger)
	layer_renderer.draw_tree_drop_petals(canvas, ambient_state.get_tree_drop_petals(), quality_scale)
	layer_renderer.draw_floating_petals(canvas, ambient_state.get_floating_petals(), quality_scale)
	_perf_end(perf_logger, "stage1.pillar.overlay_petals", sample_start)
	sample_start = _perf_begin(perf_logger)
	layer_renderer.draw_butterflies(canvas, butterfly_sheet_texture, ambient_state.get_butterflies(), view_size, game_offset, game_size, scale_factor, ambient_state.get_time(), quality_scale)
	_perf_end(perf_logger, "stage1.pillar.overlay_butterflies", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_mood_grade(canvas, _get_side_rects(view_size, game_offset, game_size), false, quality_scale, director_snapshot)
	_perf_end(perf_logger, "stage1.pillar.overlay_mood_grade", sample_start)
	sample_start = _perf_begin(perf_logger)
	layer_renderer.draw_game_border_shine(canvas, Rect2(game_offset, game_size), scale_factor, ambient_state.get_time(), quality_scale, crescendo_shine_alpha)
	_perf_end(perf_logger, "stage1.pillar.overlay_shine", sample_start)
	return true


func draw_butterfly_ingame(
	canvas: CanvasItem,
	shake_offset: Vector2 = Vector2.ZERO,
	perf_logger: Object = null,
	quality_scale: float = 1.0
) -> void:
	if canvas == null:
		return
	if ambient_state.has_method("has_ingame_butterfly_effect") and not bool(ambient_state.has_ingame_butterfly_effect()):
		return
	var sample_start: int = _perf_begin(perf_logger)
	_draw_flying_butterfly_trail(canvas, shake_offset, quality_scale)
	_perf_end(perf_logger, "stage1.butterfly.trail", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_butterfly_absorption_particles(canvas, shake_offset, quality_scale)
	_perf_end(perf_logger, "stage1.butterfly.particles", sample_start)

	sample_start = _perf_begin(perf_logger)
	var flying: Dictionary = ambient_state.get_flying_butterfly()
	if not flying.is_empty():
		_draw_ingame_butterfly(canvas, flying, 1.0, 1.0, shake_offset)
	_perf_end(perf_logger, "stage1.butterfly.sprite", sample_start)

	sample_start = _perf_begin(perf_logger)
	var absorbing: Dictionary = ambient_state.get_absorbing_butterfly()
	if absorbing.is_empty():
		_perf_end(perf_logger, "stage1.butterfly.absorb", sample_start)
		return
	var progress: float = clamp(float(absorbing.get("progress", 0.0)), 0.0, 1.0)
	var center: Vector2 = _get_vector2(absorbing, "position", Vector2.ZERO) + shake_offset
	var fade: float = 1.0 - progress
	var arc_segments: int = BUTTERFLY_ABSORB_RING_SEGMENTS_LOD if _is_lod_active(quality_scale) else BUTTERFLY_ABSORB_RING_SEGMENTS
	for i in range(BUTTERFLY_ABSORB_RING_COUNT):
		var ring_radius: float = 18.0 + progress * 55.0 + float(i) * 12.0
		var ring_alpha: float = fade * (0.36 - float(i) * 0.08)
		if ring_alpha > 0.0:
			canvas.draw_arc(
				center,
				ring_radius,
				0.0,
				TAU,
				arc_segments,
				Color(0.64, 0.90, 1.0, ring_alpha),
				max(1.0, 3.0 - float(i) * 0.5),
				true
			)
	_draw_ingame_butterfly(canvas, absorbing, fade, 1.0 + progress * 0.35, shake_offset)
	_perf_end(perf_logger, "stage1.butterfly.absorb", sample_start)


func _draw_flying_butterfly_trail(canvas: CanvasItem, shake_offset: Vector2, quality_scale: float) -> void:
	var trail: Array[Dictionary] = ambient_state.get_flying_trail()
	var stride: int = LOD_PETAL_STRIDE if _is_lod_active(quality_scale) else 1
	var start_index: int = int(floor(ambient_state.get_time() * 30.0)) % stride
	for index in range(start_index, trail.size(), stride):
		var trail_point: Dictionary = trail[index]
		var pos: Vector2 = _get_vector2(trail_point, "position", Vector2.ZERO) + shake_offset
		var alpha: float = clamp(float(trail_point.get("alpha", 0.0)), 0.0, 1.0)
		var radius: float = 3.0 + 8.0 * alpha
		canvas.draw_circle(pos, radius, Color(0.50, 0.88, 1.0, 0.10 * alpha))
		canvas.draw_circle(pos, max(1.0, radius * 0.36), Color(1.0, 0.90, 0.52, 0.24 * alpha))


func _draw_butterfly_absorption_particles(canvas: CanvasItem, shake_offset: Vector2, quality_scale: float) -> void:
	var particles: Array[Dictionary] = ambient_state.get_absorption_particles()
	var stride: int = LOD_PETAL_STRIDE if _is_lod_active(quality_scale) else 1
	var start_index: int = int(floor(ambient_state.get_time() * 30.0)) % stride
	for index in range(start_index, particles.size(), stride):
		var particle: Dictionary = particles[index]
		var life: float = clamp(float(particle.get("life", 0.0)), 0.0, 1.0)
		if life <= 0.0:
			continue
		var pos: Vector2 = _get_vector2(particle, "position", Vector2.ZERO) + shake_offset
		var size: float = max(1.0, float(particle.get("size", 2.0)))
		canvas.draw_circle(pos, size * (0.5 + life), Color(0.50, 0.88, 1.0, 0.30 * life))
		canvas.draw_circle(pos, max(1.0, size * 0.45), Color(1.0, 0.95, 0.62, 0.72 * life))


func _draw_ingame_butterfly(
	canvas: CanvasItem,
	butterfly: Dictionary,
	alpha: float,
	size_multiplier: float,
	shake_offset: Vector2
) -> void:
	var center: Vector2 = _get_vector2(butterfly, "position", Vector2.ZERO) + shake_offset
	var size: float = max(18.0, 44.0 * max(0.4, float(butterfly.get("size", 1.0))) * size_multiplier)
	if _draw_butterfly_sprite(canvas, butterfly, center, size, alpha):
		return
	_draw_fallback_butterfly(canvas, center, size, alpha)


func _draw_butterfly_sprite(
	canvas: CanvasItem,
	butterfly: Dictionary,
	center: Vector2,
	size: float,
	alpha: float
) -> bool:
	if butterfly_sheet_texture == null:
		return false
	if butterfly_sheet_texture.get_width() <= 0 or butterfly_sheet_texture.get_height() <= 0:
		return false
	var phase: float = float(butterfly.get("phase", 0.0))
	var wing_speed: float = float(butterfly.get("wing_speed", 10.0))
	var anim_t: float = fmod(ambient_state.get_time() * wing_speed + phase, TAU)
	var frame_index: int = int((anim_t / TAU) * float(BUTTERFLY_FRAME_COUNT)) % BUTTERFLY_FRAME_COUNT
	var color_index: int = int(butterfly.get("color_index", 0)) % BUTTERFLY_COLOR_COUNT
	var cell_w: float = float(butterfly_sheet_texture.get_width()) / float(BUTTERFLY_FRAME_COUNT)
	var cell_h: float = float(butterfly_sheet_texture.get_height()) / float(BUTTERFLY_COLOR_COUNT)
	if cell_w <= 0.0 or cell_h <= 0.0:
		return false
	var source_region := Rect2(cell_w * float(frame_index), cell_h * float(color_index), cell_w, cell_h)
	var dest := Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size))
	canvas.draw_texture_rect_region(
		butterfly_sheet_texture,
		dest,
		source_region,
		Color(1.0, 1.0, 1.0, clamp(alpha, 0.0, 1.0)),
		false,
		true
	)
	return true


func _draw_fallback_butterfly(canvas: CanvasItem, center: Vector2, size: float, alpha: float) -> void:
	var wing_w: float = size * 0.34
	var wing_h: float = size * 0.24
	var body_color := Color(0.18, 0.12, 0.24, 0.85 * alpha)
	var wing_color := Color(0.52, 0.84, 1.0, 0.58 * alpha)
	canvas.draw_circle(center + Vector2(-wing_w * 0.45, -wing_h * 0.18), wing_w, wing_color)
	canvas.draw_circle(center + Vector2(wing_w * 0.45, -wing_h * 0.18), wing_w, wing_color)
	canvas.draw_circle(center + Vector2(-wing_w * 0.32, wing_h * 0.44), wing_w * 0.72, Color(1.0, 0.78, 0.38, 0.42 * alpha))
	canvas.draw_circle(center + Vector2(wing_w * 0.32, wing_h * 0.44), wing_w * 0.72, Color(1.0, 0.78, 0.38, 0.42 * alpha))
	canvas.draw_line(center + Vector2(0.0, -size * 0.24), center + Vector2(0.0, size * 0.22), body_color, max(1.0, size * 0.08), true)


func _draw_hanji_side_regions(canvas: CanvasItem, view_size: Vector2, game_offset: Vector2, game_size: Vector2) -> void:
	var source_size: Vector2 = hanji_texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return
	var cover_scale: float = max(view_size.x / source_size.x, view_size.y / source_size.y)
	var target_size: Vector2 = source_size * cover_scale
	var target_pos: Vector2 = (view_size - target_size) * 0.5
	var full_target := Rect2(target_pos, target_size)
	for side_rect in _get_side_rects(view_size, game_offset, game_size):
		var clipped: Rect2 = side_rect.intersection(full_target)
		if clipped.size.x <= 0.0 or clipped.size.y <= 0.0:
			continue
		var source_rect := Rect2(
			(clipped.position - target_pos) / cover_scale,
			clipped.size / cover_scale
		)
		canvas.draw_texture_rect_region(hanji_texture, clipped, source_rect, Color.WHITE, false, true)


func _draw_mood_grade(canvas: CanvasItem, rects: Array, include_top_bottom: bool, quality_scale: float, director_snapshot: Dictionary = {}) -> void:
	var mood_alpha_boost: float = _get_crescendo_mood_alpha_boost(director_snapshot, quality_scale)
	for rect_value in rects:
		if not (rect_value is Rect2):
			continue
		var rect: Rect2 = rect_value
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		if is_zero_approx(mood_alpha_boost):
			canvas.draw_rect(rect, MOOD_GRADE_COLOR)
			canvas.draw_rect(rect, MOOD_INK_COLOR)
		else:
			canvas.draw_rect(rect, _with_alpha(MOOD_GRADE_COLOR, MOOD_GRADE_COLOR.a + mood_alpha_boost))
			canvas.draw_rect(rect, _with_alpha(MOOD_INK_COLOR, MOOD_INK_COLOR.a + mood_alpha_boost * 0.55))
		_draw_rect_side_shadow(canvas, rect, false, quality_scale)
		_draw_rect_side_shadow(canvas, rect, true, quality_scale)
		if include_top_bottom:
			_draw_rect_horizontal_shadow(canvas, rect, false, quality_scale)
			_draw_rect_horizontal_shadow(canvas, rect, true, quality_scale)
		_draw_rect_ominous_corners(canvas, rect, include_top_bottom, quality_scale)
		_draw_rect_cyber_neon(canvas, rect, include_top_bottom, quality_scale)


func _draw_rect_side_shadow(canvas: CanvasItem, rect: Rect2, right_side: bool, quality_scale: float) -> void:
	var edge_steps: int = _get_mood_edge_steps(quality_scale)
	var max_steps: int = mini(edge_steps, int(max(1.0, rect.size.x * 0.34)))
	for idx in range(max_steps):
		var t := 1.0 - float(idx) / float(max_steps)
		var alpha := MOOD_EDGE_ALPHA * t * t
		var x := rect.end.x - 1.0 - float(idx) if right_side else rect.position.x + float(idx)
		canvas.draw_rect(
			Rect2(x, rect.position.y, 1.0, rect.size.y),
			Color(2.0 / 255.0, 5.0 / 255.0, 10.0 / 255.0, alpha)
		)


func _draw_rect_horizontal_shadow(canvas: CanvasItem, rect: Rect2, bottom_side: bool, quality_scale: float) -> void:
	var edge_steps: int = _get_mood_edge_steps(quality_scale)
	var max_steps: int = mini(edge_steps, int(max(1.0, rect.size.y * 0.12)))
	for idx in range(max_steps):
		var t := 1.0 - float(idx) / float(max_steps)
		var alpha := MOOD_EDGE_ALPHA * 0.72 * t * t
		var y := rect.end.y - 1.0 - float(idx) if bottom_side else rect.position.y + float(idx)
		canvas.draw_rect(
			Rect2(rect.position.x, y, rect.size.x, 1.0),
			Color(2.0 / 255.0, 5.0 / 255.0, 10.0 / 255.0, alpha)
		)


func _draw_rect_cyber_neon(canvas: CanvasItem, rect: Rect2, include_top_bottom: bool, quality_scale: float) -> void:
	var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.0015)
	var edge_alpha: float = (0.032 + pulse * 0.014) * clamp(quality_scale, 0.45, 1.0)
	var cyan := _with_alpha(CYBER_CYAN, edge_alpha)
	var magenta := _with_alpha(CYBER_MAGENTA, edge_alpha * 0.72)
	var left_x: float = rect.position.x + 5.0
	var right_x: float = rect.end.x - 6.0
	canvas.draw_line(Vector2(left_x, rect.position.y), Vector2(left_x, rect.end.y), cyan, 1.0, true)
	canvas.draw_line(Vector2(right_x, rect.position.y), Vector2(right_x, rect.end.y), magenta, 1.0, true)
	_draw_rect_neon_slits(canvas, rect, pulse, quality_scale)
	if not include_top_bottom:
		return
	var top_y: float = rect.position.y + 10.0
	var bottom_y: float = rect.end.y - 11.0
	canvas.draw_line(Vector2(rect.position.x, top_y), Vector2(rect.end.x, top_y), _with_alpha(CYBER_CYAN, edge_alpha * 0.45), 1.0, true)
	canvas.draw_line(Vector2(rect.position.x, bottom_y), Vector2(rect.end.x, bottom_y), _with_alpha(CYBER_MAGENTA, edge_alpha * 0.38), 1.0, true)


func _draw_rect_ominous_corners(canvas: CanvasItem, rect: Rect2, include_top_bottom: bool, quality_scale: float) -> void:
	var steps: int = _get_ominous_corner_steps(quality_scale)
	var side_span: float = float(min(rect.size.x * 0.38, 42.0))
	var vertical_span: float = float(min(rect.size.y * 0.22, 76.0)) if include_top_bottom else 0.0
	for idx in range(steps):
		var t: float = 1.0 - float(idx) / float(steps)
		var alpha: float = 0.030 * t * t
		var side_w: float = float(max(1.0, side_span / float(steps) + 1.0))
		var x_offset: float = side_w * float(idx)
		var color := Color(0.0, 1.0 / 255.0, 6.0 / 255.0, alpha)
		canvas.draw_rect(Rect2(rect.position.x + x_offset, rect.position.y, side_w, rect.size.y), color)
		canvas.draw_rect(Rect2(rect.end.x - x_offset - side_w, rect.position.y, side_w, rect.size.y), color)
		if include_top_bottom:
			var band_h: float = float(max(1.0, vertical_span / float(steps) + 1.0))
			var y_offset: float = band_h * float(idx)
			canvas.draw_rect(Rect2(rect.position.x, rect.position.y + y_offset, rect.size.x, band_h), color)
			canvas.draw_rect(Rect2(rect.position.x, rect.end.y - y_offset - band_h, rect.size.x, band_h), color)


func _draw_rect_neon_slits(canvas: CanvasItem, rect: Rect2, pulse: float, quality_scale: float) -> void:
	var slit_count: int = _get_neon_slit_count(quality_scale)
	var now: float = float(Time.get_ticks_msec()) * 0.001
	for idx in range(slit_count):
		var ratio: float = (float(idx) + 1.0) / float(slit_count + 1)
		var y: float = rect.position.y + rect.size.y * ratio
		var phase: float = now * (0.9 + float(idx) * 0.07) + float(idx) * 1.83
		var flicker: float = 0.45 + 0.55 * float(max(0.0, sin(phase)))
		var slit_len: float = float(min(rect.size.x * 0.34, 30.0 + float(idx % 2) * 12.0))
		var left_x: float = rect.position.x + 10.0 + 4.0 * sin(phase * 0.7)
		var right_x: float = rect.end.x - 10.0 - slit_len - 3.0 * cos(phase * 0.6)
		canvas.draw_line(
			Vector2(left_x, y),
			Vector2(left_x + slit_len, y),
			_with_alpha(CYBER_CYAN, (0.024 + pulse * 0.012) * flicker),
			1.0,
			true
		)
		canvas.draw_line(
			Vector2(right_x, y + 5.0),
			Vector2(right_x + slit_len, y + 5.0),
			_with_alpha(CYBER_MAGENTA, (0.020 + (1.0 - pulse) * 0.010) * flicker),
			1.0,
			true
		)


func _get_mood_edge_steps(quality_scale: float) -> int:
	if quality_scale < 0.66:
		return 1
	if quality_scale < 0.85:
		return 3
	return MOOD_EDGE_STEPS


func _get_ominous_corner_steps(quality_scale: float) -> int:
	if quality_scale < 0.66:
		return 1
	if quality_scale < 0.85:
		return 4
	return OMINOUS_CORNER_STEPS


func _get_neon_slit_count(quality_scale: float) -> int:
	if quality_scale < 0.66:
		return 0
	if quality_scale < 0.85:
		return 2
	return CYBER_SIGN_SLIT_COUNT


func _is_lod_active(quality_scale: float) -> bool:
	return quality_scale < 0.85


func _get_crescendo_mood_alpha_boost(director_snapshot: Dictionary, quality_scale: float) -> float:
	return CRESCENDO_MOOD_ALPHA_MAX * _get_crescendo_strength(director_snapshot, quality_scale)


func _get_crescendo_shine_alpha_multiplier(director_snapshot: Dictionary, quality_scale: float) -> float:
	return 1.0 + CRESCENDO_SHINE_ALPHA_BOOST_MAX * _get_crescendo_strength(director_snapshot, quality_scale)


func _get_crescendo_cloud_motion_multiplier(director_snapshot: Dictionary, quality_scale: float) -> float:
	return 1.0 + CRESCENDO_CLOUD_MOTION_BOOST_MAX * _get_crescendo_parallax_strength(director_snapshot, quality_scale)


func _get_crescendo_tree_motion_offset(
	director_snapshot: Dictionary,
	quality_scale: float,
	scale_factor: float,
	time: float
) -> Vector2:
	var strength: float = _get_crescendo_parallax_strength(director_snapshot, quality_scale)
	if strength <= 0.0:
		return Vector2.ZERO
	var amplitude: float = CRESCENDO_TREE_OFFSET_MAX_PIXELS * max(1.0, scale_factor) * strength
	return Vector2(
		round(sin(time * 0.68) * amplitude),
		round(cos(time * 0.47) * amplitude * 0.35)
	)


func _get_crescendo_strength(director_snapshot: Dictionary, quality_scale: float) -> float:
	if director_snapshot.is_empty():
		return 0.0
	var display_intensity: float = clamp(float(director_snapshot.get("display_intensity", 0.0)), 0.0, 1.0)
	var rally_tier: int = clampi(int(director_snapshot.get("rally_tier", 0)), 0, 5)
	var tier_ratio: float = float(rally_tier) / 5.0
	return clampf((display_intensity * 0.62 + tier_ratio * 0.38) * _get_crescendo_quality_factor(quality_scale), 0.0, 1.0)


func _get_crescendo_parallax_strength(director_snapshot: Dictionary, quality_scale: float) -> float:
	if director_snapshot.is_empty():
		return 0.0
	var rally_tier: int = clampi(int(director_snapshot.get("rally_tier", 0)), 0, 5)
	if rally_tier < 2:
		return 0.0
	var display_intensity: float = clamp(float(director_snapshot.get("display_intensity", 0.0)), 0.0, 1.0)
	var tier_ratio: float = float(rally_tier) / 5.0
	return clampf((display_intensity * 0.55 + tier_ratio * 0.45) * _get_crescendo_quality_factor(quality_scale), 0.0, 1.0)


func _get_crescendo_quality_factor(quality_scale: float) -> float:
	return clampf(quality_scale, 0.0, 1.0)


func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clamp(alpha, 0.0, 1.0))


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


func _touch_texture(texture: Texture2D) -> void:
	if texture == null:
		return
	texture.get_size()
	texture.get_width()
	texture.get_height()


func _prewarm_texture_step(path: String) -> Dictionary:
	return ProjectResourceLoader.prewarm_texture_threaded_step(
		path,
		"",
		"",
		PREWARM_TEXTURE_FALLBACK_MSEC,
		PREWARM_TEXTURE_FALLBACK_POLLS,
		false
	)


func _get_side_rects(view_size: Vector2, game_offset: Vector2, game_size: Vector2) -> Array[Rect2]:
	var right_x: float = game_offset.x + game_size.x
	return [
		Rect2(Vector2.ZERO, Vector2(max(0.0, game_offset.x), view_size.y)),
		Rect2(Vector2(right_x, 0.0), Vector2(max(0.0, view_size.x - right_x), view_size.y)),
	]


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
