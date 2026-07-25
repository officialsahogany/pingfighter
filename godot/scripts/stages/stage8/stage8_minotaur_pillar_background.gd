extends RefCounted

# Stage 8 Minotauros generated pillar + field art owner.
#
# Slice 1 = BOOTABLE PLACEHOLDER SHELL. No stage8 imagegen art exists yet, so
# every draw path is code-native (Parthenon-aquamarine placeholder) and no
# not-yet-generated res:// path is ever wired into a per-frame draw. The four
# texture slots below stay null until the real art lands; prewarm is
# no-op-safe (guarded by ResourceLoader.exists), and the draw path only reads
# the in-memory Texture2D members, never a filesystem path.
#
# Screen-space pillar art cover-crops into the two letterbox side rects. The
# center field is drawn into the COMPLETE Godot game canvas rect (760x750); the
# legacy Python x=80..680 inset is intentionally NOT used
# (feedback_godot_playfield_letterbox_reality).

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const LOGICAL := Vector2(760.0, 750.0)
const BASE_TEXTURE_PATH := "res://assets/sprites/hud/stage8_minotaur_pillar_base_imagegen_v1.png"
const FIELD_TEXTURE_PATH := "res://assets/sprites/hud/stage8_minotaur_center_field_imagegen_v1.png"
const MOTION_TEXTURE_PATH := "res://assets/sprites/hud/stage8_minotaur_pillar_motion_sprites_imagegen_v1.png"
const REACTIVE_TEXTURE_PATH := "res://assets/sprites/hud/stage8_minotaur_pillar_reactive_sprites_imagegen_v1.png"
const MOTION_ATLAS_COLUMNS := 4
const MOTION_ATLAS_ROWS := 2
const MOTION_ATLAS_FRAMES := 8
const REACTIVE_ATLAS_COLUMNS := 4
const REACTIVE_ATLAS_ROWS := 2
const REACTIVE_ATLAS_FRAMES := 8
const PREWARM_TEXTURE_FALLBACK_MSEC := 650
const PREWARM_TEXTURE_FALLBACK_POLLS := 120

# Parthenon-aquamarine placeholder palette (~ (140,255,240) aquamarine accent).
const AQUAMARINE := Color(0.549, 1.000, 0.941, 1.0)
const VOID_COLOR := Color(0.020, 0.055, 0.052, 1.0)
const SIDE_FALLBACK_COLOR := Color(0.035, 0.086, 0.082, 1.0)
const SIDE_VIGNETTE_COLOR := Color(0.004, 0.012, 0.012, 0.18)
const FIELD_TOP_COLOR := Color(0.050, 0.135, 0.130, 1.0)
const FIELD_BOTTOM_COLOR := Color(0.086, 0.200, 0.190, 1.0)
const FIELD_FALLBACK_COLOR := Color(0.070, 0.170, 0.160, 1.0)
const FIELD_BORDER := Color(0.36, 0.78, 0.72, 0.42)
const FIELD_MARKER := Color(0.549, 1.000, 0.941, 0.30)
const MARBLE_COLOR := Color(0.62, 0.86, 0.83, 0.85)
const MARBLE_SHADE := Color(0.20, 0.42, 0.40, 0.55)
const CAPITAL_COLOR := Color(0.74, 0.94, 0.90, 0.92)
const EXCITEMENT_TINT := Color(0.35, 0.95, 0.85, 0.20)
const EXCITEMENT_SEAM := Color(0.70, 1.000, 0.92, 0.78)
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
	_draw_side_base(canvas, target_size, game_offset, game_size, quality_scale)
	_draw_field_base(canvas, game_offset, game_size, quality_scale)
	var side_rects: Array[Rect2] = get_side_rects(target_size, game_offset, game_size)
	if _excitement > 0.001:
		_draw_excitement_background(canvas, side_rects, _excitement)
		_draw_excitement_seams(canvas, side_rects, _excitement)
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
	_draw_excitement_seams(canvas, side_rects, _excitement)


func get_asset_status() -> Dictionary:
	return {
		"theme": "minotaur_parthenon_ringpia",
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
		"uses_static_texture": _all_generated_art_loaded(),
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
		"static_texture_draws": 0,
		"motion_sprite_draws_full": 0,
		"motion_sprite_draws_lod": 0,
		"resting_reactive_draws": 6,
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


func _draw_side_base(
	canvas: CanvasItem,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	quality_scale: float
) -> void:
	var side_rects: Array[Rect2] = get_side_rects(view_size, game_offset, game_size)
	if base_texture != null:
		# Slice 3: real Parthenon chrome. base_texture = the combined
		# outer_pillar_scene (left + right aquamarine Ionic columns, torches, gold
		# trim). Cover-fit it to the whole view and sample each letterbox side rect
		# so the left/right columns land in the left/right margins; the dark center
		# band of the source falls in the (undrawn) field region.
		_draw_cover_texture_in_rects(canvas, base_texture, view_size, side_rects)
		return
	for side_index in range(side_rects.size()):
		var side_rect: Rect2 = side_rects[side_index]
		if side_rect.size.x <= 0.0 or side_rect.size.y <= 0.0:
			continue
		# Fallback (no art): flat aquamarine letterbox fill + code-native columns.
		canvas.draw_rect(side_rect, SIDE_FALLBACK_COLOR)
		_draw_marble_columns(canvas, side_rect, side_index, quality_scale)


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


func _draw_marble_columns(
	canvas: CanvasItem,
	side_rect: Rect2,
	_side_index: int,
	quality_scale: float
) -> void:
	if side_rect.size.x < 16.0 or side_rect.size.y < 60.0:
		return
	var inset: float = minf(6.0, side_rect.size.x * 0.12)
	var usable_w: float = side_rect.size.x - inset * 2.0
	if usable_w <= 6.0:
		return
	var col_count: int = 3 if usable_w > 120.0 else 2
	var slot: float = usable_w / float(col_count)
	var shaft_w: float = clampf(slot * 0.5, 4.0, 26.0)
	var cap_h: float = clampf(shaft_w * 0.34, 3.0, 12.0)
	var top: float = side_rect.position.y + side_rect.size.y * 0.10
	var bottom: float = side_rect.position.y + side_rect.size.y * 0.92
	var shaft_h: float = bottom - top - cap_h * 2.0
	if shaft_h <= 8.0:
		return
	var glow: float = clampf(_excitement, 0.0, 1.0)
	var shaft_color: Color = MARBLE_COLOR.lerp(AQUAMARINE, glow * 0.5)
	var cap_color: Color = CAPITAL_COLOR.lerp(AQUAMARINE, glow * 0.5)
	for i in range(col_count):
		var cx: float = side_rect.position.x + inset + slot * (float(i) + 0.5)
		var shaft_rect := Rect2(Vector2(cx - shaft_w * 0.5, top + cap_h), Vector2(shaft_w, shaft_h))
		canvas.draw_rect(shaft_rect, shaft_color)
		# capital (top) + base (bottom) blocks, slightly wider than the shaft
		var block_w: float = shaft_w * 1.35
		canvas.draw_rect(Rect2(Vector2(cx - block_w * 0.5, top), Vector2(block_w, cap_h)), cap_color)
		canvas.draw_rect(Rect2(Vector2(cx - block_w * 0.5, bottom - cap_h), Vector2(block_w, cap_h)), cap_color)
		# fluting: a couple of vertical shade lines, detail-gated by quality
		if quality_scale > 0.5 and shaft_w >= 10.0:
			var flute_x0: float = cx - shaft_w * 0.22
			var flute_x1: float = cx + shaft_w * 0.22
			canvas.draw_line(Vector2(flute_x0, top + cap_h), Vector2(flute_x0, bottom - cap_h), MARBLE_SHADE, 1.0, true)
			canvas.draw_line(Vector2(flute_x1, top + cap_h), Vector2(flute_x1, bottom - cap_h), MARBLE_SHADE, 1.0, true)


func _draw_field_base(canvas: CanvasItem, game_offset: Vector2, game_size: Vector2, quality_scale: float) -> void:
	if game_size.x <= 0.0 or game_size.y <= 0.0:
		return
	var field_rect := Rect2(game_offset, game_size)
	if field_texture != null:
		# Future path: real stage8 field art. Not reached in Slice 1 (texture null).
		canvas.draw_texture_rect(field_texture, field_rect, false)
	else:
		# Slice 1 placeholder: vertical aquamarine gradient via a convex quad.
		var points := PackedVector2Array([
			field_rect.position,
			Vector2(field_rect.end.x, field_rect.position.y),
			field_rect.end,
			Vector2(field_rect.position.x, field_rect.end.y),
		])
		var colors := PackedColorArray([
			FIELD_TOP_COLOR,
			FIELD_TOP_COLOR,
			FIELD_BOTTOM_COLOR,
			FIELD_BOTTOM_COLOR,
		])
		canvas.draw_polygon(points, colors)
	_draw_field_center_marker(canvas, field_rect, quality_scale)
	var scale: float = maxf(1.0, game_size.x / LOGICAL.x)
	var border_width: float = maxf(1.0, roundf(2.0 * scale))
	canvas.draw_rect(field_rect, FIELD_BORDER, false, border_width, true)


func _draw_field_center_marker(canvas: CanvasItem, field_rect: Rect2, quality_scale: float) -> void:
	if field_rect.size.x <= 4.0 or field_rect.size.y <= 4.0:
		return
	var center: Vector2 = field_rect.get_center()
	var scale: float = maxf(1.0, field_rect.size.x / LOGICAL.x)
	var line_width: float = maxf(1.0, roundf(2.0 * scale))
	# Center stadium line across the full field width (Python stage9 marker feel).
	canvas.draw_line(
		Vector2(field_rect.position.x, center.y),
		Vector2(field_rect.end.x, center.y),
		FIELD_MARKER,
		line_width,
		true
	)
	if quality_scale <= 0.35:
		return
	# Center ring + inner dot.
	var radius: float = field_rect.size.x * 0.14
	if radius > 6.0:
		canvas.draw_arc(center, radius, 0.0, TAU, 48, FIELD_MARKER, line_width, true)
		canvas.draw_circle(center, maxf(2.0, radius * 0.06), FIELD_MARKER)


func _draw_excitement_background(canvas: CanvasItem, side_rects: Array[Rect2], excitement: float) -> void:
	for side_rect in side_rects:
		if side_rect.size.x <= 0.0 or side_rect.size.y <= 0.0:
			continue
		canvas.draw_rect(
			side_rect,
			Color(
				EXCITEMENT_TINT.r,
				EXCITEMENT_TINT.g,
				EXCITEMENT_TINT.b,
				EXCITEMENT_TINT.a * excitement
			)
		)


func _draw_excitement_seams(canvas: CanvasItem, side_rects: Array[Rect2], excitement: float) -> void:
	var pulse: float = 0.55 + 0.45 * sin(_ambient_time * 20.0)
	var line_color := Color(
		EXCITEMENT_SEAM.r,
		EXCITEMENT_SEAM.g,
		EXCITEMENT_SEAM.b,
		EXCITEMENT_SEAM.a * excitement * pulse
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
	# Slice 1 guard: stage8 art is not generated yet. Skip absent paths so the
	# threaded loader never re-stats a missing file; prewarm stays no-op-safe.
	if not ResourceLoader.exists(path):
		return {"done": true, "texture": null}
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
