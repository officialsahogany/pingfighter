extends RefCounted

# Stage 7 Akamu Rigo generated pillar + field art owner.
#
# Screen-space pillar art is cover-cropped into the two letterbox side rects.
# The center field is drawn into the complete Godot game canvas rect; the
# legacy Python x=80..680 inset is intentionally not used.

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const LOGICAL := Vector2(760.0, 750.0)
const BASE_TEXTURE_PATH := "res://assets/sprites/hud/stage7_akamu_pillar_base_imagegen_v1.png"
const FIELD_TEXTURE_PATH := "res://assets/sprites/hud/stage7_akamu_center_field_imagegen_v1.png"
const MOTION_TEXTURE_PATH := "res://assets/sprites/hud/stage7_akamu_pillar_motion_sprites_imagegen_v1.png"
const REACTIVE_TEXTURE_PATH := "res://assets/sprites/hud/stage7_akamu_pillar_reactive_sprites_imagegen_v1.png"
const MOTION_ATLAS_COLUMNS := 4
const MOTION_ATLAS_ROWS := 2
const MOTION_ATLAS_FRAMES := 8
const REACTIVE_ATLAS_COLUMNS := 4
const REACTIVE_ATLAS_ROWS := 2
const REACTIVE_ATLAS_FRAMES := 8
const PREWARM_TEXTURE_FALLBACK_MSEC := 650
const PREWARM_TEXTURE_FALLBACK_POLLS := 120

const VOID_COLOR := Color(0.016, 0.012, 0.026, 1.0)
const SIDE_FALLBACK_COLOR := Color(0.050, 0.038, 0.075, 1.0)
const SIDE_VIGNETTE_COLOR := Color(0.006, 0.004, 0.012, 0.16)
const FIELD_FALLBACK_COLOR := Color(0.022, 0.018, 0.036, 1.0)
const FIELD_SHADE := Color(0.010, 0.008, 0.022, 0.10)
const FIELD_BORDER := Color(0.43, 0.27, 0.62, 0.46)
const FIELD_BORDER_WARM := Color(0.92, 0.42, 0.18, 0.16)
const EXCITEMENT_PURPLE := Color(0.44, 0.16, 0.62, 0.22)
const EXCITEMENT_ORANGE := Color(1.0, 0.38, 0.12, 0.72)
const EXCITEMENT_DECAY_PER_SEC := 1.8

var base_texture: Texture2D = null
var field_texture: Texture2D = null
var motion_texture: Texture2D = null
var reactive_texture: Texture2D = null

var _prewarm_assets_step_index := 0
var _assets_prewarmed := false
var _ambient_time := 0.0
var _excitement := 0.0


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if _assets_prewarmed:
		return true
	match _prewarm_assets_step_index:
		0:
			var base_result: Dictionary = _prewarm_texture_step(BASE_TEXTURE_PATH)
			if not bool(base_result.get("done", true)):
				return false
			base_texture = base_result.get("texture", base_texture) as Texture2D
		1:
			var field_result: Dictionary = _prewarm_texture_step(FIELD_TEXTURE_PATH)
			if not bool(field_result.get("done", true)):
				return false
			field_texture = field_result.get("texture", field_texture) as Texture2D
		2:
			var motion_result: Dictionary = _prewarm_texture_step(MOTION_TEXTURE_PATH)
			if not bool(motion_result.get("done", true)):
				return false
			motion_texture = motion_result.get("texture", motion_texture) as Texture2D
		3:
			var reactive_result: Dictionary = _prewarm_texture_step(REACTIVE_TEXTURE_PATH)
			if not bool(reactive_result.get("done", true)):
				return false
			reactive_texture = reactive_result.get("texture", reactive_texture) as Texture2D
		4:
			_touch_texture(base_texture)
		5:
			_touch_texture(field_texture)
		6:
			_touch_texture(motion_texture)
		7:
			_touch_texture(reactive_texture)
		_:
			_assets_prewarmed = true
			_prewarm_assets_step_index = 0
			return true
	_prewarm_assets_step_index += 1
	return false


func reset() -> void:
	_ambient_time = 0.0
	_excitement = 0.0


func update(delta: float, _context: Dictionary = {}, _deps: Dictionary = {}) -> void:
	var clamped_delta: float = clampf(delta, 0.0, 0.1)
	_ambient_time += clamped_delta
	_excitement = maxf(0.0, _excitement - clamped_delta * EXCITEMENT_DECAY_PER_SEC)


func trigger_excitement(level: float = 1.0) -> void:
	_excitement = maxf(_excitement, clampf(level, 0.0, 1.0))


func draw(
	canvas: CanvasItem,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	_field_width: float,
	_perf_logger: Object = null,
	quality_scale: float = 1.0
) -> bool:
	if canvas == null:
		return false
	var target_size: Vector2 = _resolve_target_size(view_size, game_offset, game_size)
	if target_size.x <= 0.0 or target_size.y <= 0.0:
		return false
	if game_size.x <= 0.0 or game_size.y <= 0.0:
		game_offset = Vector2.ZERO
		game_size = target_size

	canvas.draw_rect(Rect2(Vector2.ZERO, target_size), VOID_COLOR)
	_draw_side_base(canvas, target_size, game_offset, game_size)
	_draw_field_base(canvas, game_offset, game_size, quality_scale)
	_draw_motion_layers(canvas, target_size, game_offset, game_size, quality_scale)
	var side_rects: Array[Rect2] = get_side_rects(target_size, game_offset, game_size)
	if _excitement > 0.001:
		_draw_excitement_background(canvas, side_rects, _excitement)
		_draw_excited_reactive_props(canvas, side_rects, _excitement)
		_draw_excitement_seams(canvas, side_rects, _excitement)
	else:
		_draw_resting_reactive_props(canvas, target_size, game_offset, game_size)
	_draw_side_vignette(canvas, target_size, game_offset, game_size, quality_scale)
	return true


func draw_pillar_background_overlay(
	canvas: CanvasItem,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	_field_width: float,
	_perf_logger: Object = null,
	_quality_scale: float = 1.0
) -> void:
	if canvas == null or _excitement <= 0.001:
		return
	var target_size: Vector2 = _resolve_target_size(view_size, game_offset, game_size)
	var side_rects: Array[Rect2] = get_side_rects(target_size, game_offset, game_size)
	_draw_excitement_background(canvas, side_rects, _excitement)
	_draw_excited_reactive_props(canvas, side_rects, _excitement)
	_draw_excitement_seams(canvas, side_rects, _excitement)


func get_asset_status() -> Dictionary:
	return {
		"theme": "akamu_shadow_dojo_ringpia",
		"base_texture_path": BASE_TEXTURE_PATH,
		"field_texture_path": FIELD_TEXTURE_PATH,
		"motion_texture_path": MOTION_TEXTURE_PATH,
		"reactive_texture_path": REACTIVE_TEXTURE_PATH,
		"base_texture": base_texture != null,
		"field_texture": field_texture != null,
		"motion_texture": motion_texture != null,
		"reactive_texture": reactive_texture != null,
		"motion_atlas_grid": Vector2i(MOTION_ATLAS_COLUMNS, MOTION_ATLAS_ROWS),
		"motion_atlas_frames": MOTION_ATLAS_FRAMES,
		"reactive_atlas_grid": Vector2i(REACTIVE_ATLAS_COLUMNS, REACTIVE_ATLAS_ROWS),
		"reactive_atlas_frames": REACTIVE_ATLAS_FRAMES,
		"uses_code_native_placeholder": not _all_generated_art_loaded(),
		"uses_static_texture": true,
		"generated_art_loaded": _all_generated_art_loaded(),
		"has_runtime_animation": true,
		"supports_score_excitement": true,
		"prewarm_complete": _assets_prewarmed,
	}


func get_imagegen_asset_status() -> Dictionary:
	return get_asset_status()


func get_layout_rects(view_size: Vector2, game_offset: Vector2, game_size: Vector2) -> Dictionary:
	var target_size: Vector2 = _resolve_target_size(view_size, game_offset, game_size)
	var sides: Array[Rect2] = get_side_rects(target_size, game_offset, game_size)
	return {
		"field": Rect2(game_offset, game_size),
		"left": sides[0],
		"right": sides[1],
	}


func get_side_rects(view_size: Vector2, game_offset: Vector2, game_size: Vector2) -> Array[Rect2]:
	var right_x: float = game_offset.x + game_size.x
	return [
		Rect2(Vector2.ZERO, Vector2(maxf(0.0, game_offset.x), view_size.y)),
		Rect2(Vector2(right_x, 0.0), Vector2(maxf(0.0, view_size.x - right_x), view_size.y)),
	]


func get_reactive_prop_rects(side_rect: Rect2, ornament_index: int, x_offset: float = 0.0) -> Dictionary:
	var bamboo_width: float = minf(310.0, side_rect.size.x * 1.18)
	var bamboo_height: float = minf(side_rect.size.y * 0.46, bamboo_width * 1.125)
	var bamboo_center := Vector2(
		side_rect.get_center().x + x_offset,
		side_rect.position.y + side_rect.size.y * 0.79
	)
	var bamboo_rect := Rect2(
		bamboo_center - Vector2(bamboo_width, bamboo_height) * 0.5,
		Vector2(bamboo_width, bamboo_height)
	)

	var ornament_width: float = minf(182.0, side_rect.size.x * 0.88)
	var ornament_height: float = minf(side_rect.size.y * 0.34, ornament_width * 1.125)
	var ornament_y_ratio: float = 0.31 if ornament_index <= 5 else 0.29
	var ornament_center := Vector2(
		side_rect.get_center().x + x_offset,
		side_rect.position.y + side_rect.size.y * ornament_y_ratio
	)
	var ornament_rect := Rect2(
		ornament_center - Vector2(ornament_width, ornament_height) * 0.5,
		Vector2(ornament_width, ornament_height)
	)
	return {
		"bamboo": _clamp_rect_to_side(bamboo_rect, side_rect),
		"ornament": _clamp_rect_to_side(ornament_rect, side_rect),
	}


func get_performance_snapshot() -> Dictionary:
	return {
		"static_texture_draws": 3,
		"motion_sprite_draws_full": 8,
		"motion_sprite_draws_lod": 4,
		"resting_reactive_draws": 4,
		"score_reactive_draws": 4,
		"hot_path_image_processing": false,
	}


func get_debug_snapshot() -> Dictionary:
	return {
		"ambient_time": _ambient_time,
		"excitement": _excitement,
		"prewarm_step_index": _prewarm_assets_step_index,
		"prewarm_complete": _assets_prewarmed,
	}


func _all_generated_art_loaded() -> bool:
	return base_texture != null and field_texture != null and motion_texture != null and reactive_texture != null


func _resolve_target_size(view_size: Vector2, game_offset: Vector2, game_size: Vector2) -> Vector2:
	if view_size.x > 0.0 and view_size.y > 0.0:
		return view_size
	var fallback: Vector2 = game_offset * 2.0 + game_size
	if fallback.x > 0.0 and fallback.y > 0.0:
		return fallback
	return LOGICAL


func _draw_side_base(canvas: CanvasItem, view_size: Vector2, game_offset: Vector2, game_size: Vector2) -> void:
	var side_rects: Array[Rect2] = get_side_rects(view_size, game_offset, game_size)
	if base_texture != null:
		_draw_cover_texture_in_rects(canvas, base_texture, view_size, side_rects)
		return
	for side_rect in side_rects:
		if side_rect.size.x > 0.0 and side_rect.size.y > 0.0:
			canvas.draw_rect(side_rect, SIDE_FALLBACK_COLOR)


func _draw_field_base(canvas: CanvasItem, game_offset: Vector2, game_size: Vector2, quality_scale: float) -> void:
	if game_size.x <= 0.0 or game_size.y <= 0.0:
		return
	var field_rect := Rect2(game_offset, game_size)
	if field_texture != null:
		canvas.draw_texture_rect(field_texture, field_rect, false)
	else:
		canvas.draw_rect(field_rect, FIELD_FALLBACK_COLOR)
	canvas.draw_rect(field_rect, FIELD_SHADE)
	var scale: float = maxf(1.0, game_size.x / LOGICAL.x)
	var border_width: float = maxf(1.0, roundf(2.0 * scale))
	canvas.draw_rect(field_rect.grow(scale * 2.0), FIELD_BORDER_WARM, false, border_width, true)
	if quality_scale > 0.35:
		canvas.draw_rect(field_rect, FIELD_BORDER, false, border_width, true)


func _draw_cover_texture_in_rects(
	canvas: CanvasItem,
	texture: Texture2D,
	view_size: Vector2,
	target_rects: Array[Rect2]
) -> void:
	var source_size: Vector2 = texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return
	var cover_scale: float = maxf(view_size.x / source_size.x, view_size.y / source_size.y)
	var target_size: Vector2 = source_size * cover_scale
	var target_pos: Vector2 = (view_size - target_size) * 0.5
	var full_target := Rect2(target_pos, target_size)
	for target_rect in target_rects:
		var clipped: Rect2 = target_rect.intersection(full_target)
		if clipped.size.x <= 0.0 or clipped.size.y <= 0.0:
			continue
		var source_rect := Rect2(
			(clipped.position - target_pos) / cover_scale,
			clipped.size / cover_scale
		)
		canvas.draw_texture_rect_region(texture, clipped, source_rect, Color.WHITE, false, true)


func _draw_motion_layers(
	canvas: CanvasItem,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	quality_scale: float
) -> void:
	if motion_texture == null:
		return
	var side_rects: Array[Rect2] = get_side_rects(view_size, game_offset, game_size)
	for side_index in range(side_rects.size()):
		var side_rect: Rect2 = side_rects[side_index]
		if side_rect.size.x < 36.0 or side_rect.size.y < 120.0:
			continue
		var pulse: float = 0.5 + 0.5 * sin(_ambient_time * 1.35 + float(side_index) * 1.7)
		_draw_side_mist(canvas, side_rect, side_index, 0, pulse)
		if quality_scale > 0.48:
			_draw_side_mist(canvas, side_rect, side_index, 1, 1.0 - pulse)
			_draw_drifting_paper(canvas, side_rect, side_index)
		_draw_lantern_glow(canvas, side_rect, side_index, pulse)


func _draw_side_mist(canvas: CanvasItem, side_rect: Rect2, side_index: int, layer_index: int, pulse: float) -> void:
	var target_width: float = minf(240.0, side_rect.size.x * 0.96)
	var target_height: float = minf(150.0, target_width * 0.66)
	var phase: float = _ambient_time * (0.22 + float(layer_index) * 0.07) + float(side_index) * 1.8
	var center_x: float = side_rect.get_center().x + sin(phase) * side_rect.size.x * 0.08
	var y_ratio: float = 0.16 if layer_index == 0 else 0.72
	var center_y: float = side_rect.position.y + side_rect.size.y * y_ratio + cos(phase * 0.7) * 5.0
	var target_rect := Rect2(Vector2(center_x, center_y) - Vector2(target_width, target_height) * 0.5, Vector2(target_width, target_height))
	var texture_index: int = side_index * 2 + layer_index
	_draw_motion_atlas_cell(
		canvas,
		texture_index,
		_clamp_rect_to_side(target_rect, side_rect),
		Color(0.78, 0.82, 1.0, 0.22 + pulse * 0.10)
	)


func _draw_drifting_paper(canvas: CanvasItem, side_rect: Rect2, side_index: int) -> void:
	var phase_offset: float = 0.15 + float(side_index) * 0.43
	var travel: float = fmod(_ambient_time * 0.055 + phase_offset, 1.0)
	var target_width: float = minf(118.0, side_rect.size.x * 0.58)
	var target_height: float = target_width * 1.04
	var center_x: float = side_rect.get_center().x + sin(_ambient_time * 0.9 + float(side_index) * 2.1) * side_rect.size.x * 0.17
	var center_y: float = side_rect.position.y + side_rect.size.y * (0.08 + travel * 0.82)
	var target_rect := Rect2(Vector2(center_x, center_y) - Vector2(target_width, target_height) * 0.5, Vector2(target_width, target_height))
	_draw_motion_atlas_cell(
		canvas,
		4 + side_index,
		_clamp_rect_to_side(target_rect, side_rect),
		Color(1.0, 0.94, 0.82, 0.34)
	)


func _draw_lantern_glow(canvas: CanvasItem, side_rect: Rect2, side_index: int, pulse: float) -> void:
	var target_width: float = minf(136.0, side_rect.size.x * 0.72)
	var target_height: float = target_width * 1.08
	var center_y: float = side_rect.position.y + side_rect.size.y * (0.33 if side_index == 0 else 0.27)
	var target_rect := Rect2(
		Vector2(side_rect.get_center().x, center_y) - Vector2(target_width, target_height) * 0.5,
		Vector2(target_width, target_height)
	)
	_draw_motion_atlas_cell(
		canvas,
		6 + side_index,
		_clamp_rect_to_side(target_rect, side_rect),
		Color(1.0, 0.64, 0.34, 0.28 + pulse * 0.16)
	)


func _draw_resting_reactive_props(
	canvas: CanvasItem,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2
) -> void:
	if reactive_texture == null:
		return
	var side_rects: Array[Rect2] = get_side_rects(view_size, game_offset, game_size)
	if side_rects[0].size.x >= 44.0:
		_draw_reactive_side_props(canvas, side_rects[0], 0, 4, Color(0.92, 0.90, 1.0, 0.86))
	if side_rects[1].size.x >= 44.0:
		_draw_reactive_side_props(canvas, side_rects[1], 2, 6, Color(0.92, 0.90, 1.0, 0.86))


func _draw_excited_reactive_props(canvas: CanvasItem, side_rects: Array[Rect2], excitement: float) -> void:
	if reactive_texture == null or side_rects.size() < 2:
		return
	var jitter: float = sin(_ambient_time * 31.0) * 2.5 * excitement
	var modulate := Color(1.0, 0.82 + excitement * 0.18, 0.72 + excitement * 0.28, 0.68 + excitement * 0.32)
	if side_rects[0].size.x >= 44.0:
		_draw_reactive_side_props(canvas, side_rects[0], 1, 5, modulate, jitter)
	if side_rects[1].size.x >= 44.0:
		_draw_reactive_side_props(canvas, side_rects[1], 3, 7, modulate, -jitter)


func _draw_excitement_background(canvas: CanvasItem, side_rects: Array[Rect2], excitement: float) -> void:
	for side_rect in side_rects:
		if side_rect.size.x <= 0.0 or side_rect.size.y <= 0.0:
			continue
		canvas.draw_rect(
			side_rect,
			Color(
				EXCITEMENT_PURPLE.r,
				EXCITEMENT_PURPLE.g,
				EXCITEMENT_PURPLE.b,
				EXCITEMENT_PURPLE.a * excitement
			)
		)


func _draw_reactive_side_props(
	canvas: CanvasItem,
	side_rect: Rect2,
	bamboo_index: int,
	ornament_index: int,
	modulate: Color,
	x_offset: float = 0.0
) -> void:
	var rects: Dictionary = get_reactive_prop_rects(side_rect, ornament_index, x_offset)
	_draw_reactive_atlas_cell(canvas, bamboo_index, rects.get("bamboo", Rect2()), modulate)
	_draw_reactive_atlas_cell(canvas, ornament_index, rects.get("ornament", Rect2()), modulate)


func _draw_excitement_seams(canvas: CanvasItem, side_rects: Array[Rect2], excitement: float) -> void:
	var pulse: float = 0.55 + 0.45 * sin(_ambient_time * 20.0)
	var line_color := Color(
		EXCITEMENT_ORANGE.r,
		EXCITEMENT_ORANGE.g,
		EXCITEMENT_ORANGE.b,
		EXCITEMENT_ORANGE.a * excitement * pulse
	)
	for side_index in range(side_rects.size()):
		var rect: Rect2 = side_rects[side_index]
		if rect.size.x <= 1.0 or rect.size.y <= 1.0:
			continue
		var edge_x: float = rect.end.x - 1.0 if side_index == 0 else rect.position.x + 1.0
		canvas.draw_line(Vector2(edge_x, 0.0), Vector2(edge_x, rect.size.y), line_color, 2.0, true)


func _draw_side_vignette(
	canvas: CanvasItem,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	quality_scale: float
) -> void:
	var side_rects: Array[Rect2] = get_side_rects(view_size, game_offset, game_size)
	for side_rect in side_rects:
		if side_rect.size.x > 0.0 and side_rect.size.y > 0.0:
			canvas.draw_rect(side_rect, SIDE_VIGNETTE_COLOR)
	if quality_scale <= 0.42:
		return
	if side_rects[0].size.x > 20.0:
		canvas.draw_line(Vector2(side_rects[0].end.x - 1.0, 0.0), Vector2(side_rects[0].end.x - 1.0, view_size.y), FIELD_BORDER, 1.0, true)
	if side_rects[1].size.x > 20.0:
		canvas.draw_line(Vector2(side_rects[1].position.x + 1.0, 0.0), Vector2(side_rects[1].position.x + 1.0, view_size.y), FIELD_BORDER, 1.0, true)


func _draw_motion_atlas_cell(
	canvas: CanvasItem,
	index: int,
	target_rect: Rect2,
	modulate: Color
) -> void:
	_draw_atlas_cell(
		canvas,
		motion_texture,
		index,
		target_rect,
		modulate,
		MOTION_ATLAS_COLUMNS,
		MOTION_ATLAS_ROWS,
		MOTION_ATLAS_FRAMES
	)


func _draw_reactive_atlas_cell(
	canvas: CanvasItem,
	index: int,
	target_rect: Rect2,
	modulate: Color
) -> void:
	_draw_atlas_cell(
		canvas,
		reactive_texture,
		index,
		target_rect,
		modulate,
		REACTIVE_ATLAS_COLUMNS,
		REACTIVE_ATLAS_ROWS,
		REACTIVE_ATLAS_FRAMES
	)


func _draw_atlas_cell(
	canvas: CanvasItem,
	texture: Texture2D,
	index: int,
	target_rect: Rect2,
	modulate: Color,
	columns: int,
	rows: int,
	frame_count: int
) -> void:
	if texture == null or target_rect.size.x <= 0.0 or target_rect.size.y <= 0.0:
		return
	if columns <= 0 or rows <= 0 or index < 0 or index >= frame_count or frame_count > columns * rows:
		return
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var cell_size := Vector2(texture_size.x / float(columns), texture_size.y / float(rows))
	var column: int = posmod(index, columns)
	var row: int = int(index / columns)
	var source_rect := Rect2(Vector2(float(column), float(row)) * cell_size, cell_size).grow(-2.0)
	canvas.draw_texture_rect_region(texture, target_rect, source_rect, modulate, false, true)


func _clamp_rect_to_side(target_rect: Rect2, side_rect: Rect2) -> Rect2:
	var clamped_size := Vector2(minf(target_rect.size.x, side_rect.size.x), minf(target_rect.size.y, side_rect.size.y))
	var min_pos: Vector2 = side_rect.position
	var max_pos: Vector2 = side_rect.end - clamped_size
	var clamped_pos := Vector2(
		clampf(target_rect.position.x, min_pos.x, max_pos.x),
		clampf(target_rect.position.y, min_pos.y, max_pos.y)
	)
	return Rect2(clamped_pos, clamped_size)


func _prewarm_texture_step(path: String) -> Dictionary:
	return ProjectResourceLoader.prewarm_texture_threaded_step(
		path,
		"",
		"",
		PREWARM_TEXTURE_FALLBACK_MSEC,
		PREWARM_TEXTURE_FALLBACK_POLLS,
		false,
		true
	)


func _touch_texture(texture: Texture2D) -> void:
	if texture == null:
		return
	texture.get_size()
	texture.get_width()
	texture.get_height()
