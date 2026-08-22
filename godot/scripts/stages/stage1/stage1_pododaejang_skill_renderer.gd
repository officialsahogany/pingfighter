extends RefCounted

const Stage1ContextReader := preload("res://scripts/stages/stage1/stage1_context_reader.gd")

const POJOL_GRID_COLS := 3
const POJOL_GRID_ROWS := 3
const POJOL_FRAME_COUNT := 8
const POJOL_DRAW_SIZE := Vector2(48.0, 66.0)
const ROPE_DARK := Color(0.34, 0.24, 0.13, 0.95)
const ROPE_BASE := Color(0.69, 0.57, 0.37, 0.98)
const ROPE_LIGHT := Color(0.84, 0.74, 0.52, 0.90)


func draw(
	canvas: CanvasItem,
	context: Dictionary,
	shake_offset: Vector2 = Vector2.ZERO,
	_perf_logger: Object = null
) -> void:
	if canvas == null or int(context.get("current_stage", 1)) != 1:
		return
	_draw_patrol_guards(canvas, context, shake_offset)
	_draw_arrest_rope(canvas, context, shake_offset)


func _draw_patrol_guards(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	if not bool(context.get("stage1_pododaejang_patrol_guards_active", false)):
		return
	var guards_value: Variant = context.get("stage1_pododaejang_patrol_guards", [])
	if not (guards_value is Array):
		return
	var texture_value: Variant = context.get("stage1_pojol_patrol_walk_sheet", null)
	for guard_value in guards_value as Array:
		if not (guard_value is Dictionary):
			continue
		var guard: Dictionary = guard_value
		var center := Vector2(float(guard.get("x", 0.0)), float(guard.get("y", 0.0))) + shake_offset
		var alpha: float = clampf(float(guard.get("alpha", 1.0)), 0.0, 1.0)
		var age_frames: float = maxf(0.0, float(guard.get("age_frames", 0.0)))
		var frame: int = int(floor(age_frames / 6.0)) % POJOL_FRAME_COUNT
		if texture_value is Texture2D:
			_draw_sheet_frame(canvas, texture_value as Texture2D, center, frame, alpha)
		else:
			_draw_guard_fallback(canvas, center, alpha)


func _draw_sheet_frame(canvas: CanvasItem, texture: Texture2D, center: Vector2, frame: int, alpha: float) -> void:
	var texture_size: Vector2 = texture.get_size()
	var cell_size := Vector2(
		texture_size.x / float(POJOL_GRID_COLS),
		texture_size.y / float(POJOL_GRID_ROWS)
	)
	if cell_size.x <= 0.0 or cell_size.y <= 0.0:
		return
	var safe_frame: int = clampi(frame, 0, POJOL_FRAME_COUNT - 1)
	var row: int = safe_frame / POJOL_GRID_COLS
	var source_rect := Rect2(
		Vector2(float(safe_frame % POJOL_GRID_COLS), float(row)) * cell_size,
		cell_size
	)
	var dest_rect := Rect2(center - POJOL_DRAW_SIZE * 0.5, POJOL_DRAW_SIZE)
	canvas.draw_texture_rect_region(texture, dest_rect, source_rect, Color(1.0, 1.0, 1.0, alpha))


func _draw_guard_fallback(canvas: CanvasItem, center: Vector2, alpha: float) -> void:
	canvas.draw_circle(center + Vector2(0.0, -18.0), 8.0, Color(0.74, 0.58, 0.42, alpha))
	canvas.draw_rect(Rect2(center + Vector2(-9.0, -10.0), Vector2(18.0, 29.0)), Color(0.10, 0.15, 0.28, alpha))
	canvas.draw_line(center + Vector2(-13.0, -24.0), center + Vector2(13.0, -24.0), Color(0.05, 0.04, 0.03, alpha), 3.0)
	canvas.draw_line(center + Vector2(9.0, -6.0), center + Vector2(18.0, 16.0), Color(0.34, 0.22, 0.12, alpha), 3.0)


func _draw_arrest_rope(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	if not bool(context.get("stage1_pododaejang_arrest_rope_visible", false)):
		return
	var phase: String = str(context.get("stage1_pododaejang_arrest_rope_phase", "idle"))
	var origin: Vector2 = Stage1ContextReader.as_vector2(
		context.get("stage1_pododaejang_arrest_rope_origin", Vector2.ZERO),
		Vector2.ZERO
	) + shake_offset
	var target: Vector2 = Stage1ContextReader.as_vector2(
		context.get("stage1_pododaejang_arrest_rope_target", Vector2.ZERO),
		Vector2.ZERO
	) + shake_offset
	var progress: float = clampf(float(context.get("stage1_pododaejang_arrest_rope_throw_progress", 0.0)), 0.0, 1.0)
	var end_pos: Vector2 = target
	var alpha := 1.0
	if phase == "throwing":
		var eased: float = 1.0 - pow(1.0 - progress, 2.0)
		end_pos = origin.lerp(target, eased)
	elif phase == "miss":
		var miss_timer: float = maxf(0.0, float(context.get("stage1_pododaejang_arrest_rope_timer", 0.0)))
		var sag: float = sin((30.0 - miss_timer) / 30.0 * PI) * 28.0
		end_pos += Vector2(0.0, sag)
		alpha = clampf(miss_timer / 30.0, 0.0, 1.0)
	elif phase == "releasing":
		var release_timer: float = maxf(0.0, float(context.get("stage1_pododaejang_arrest_rope_timer", 0.0)))
		alpha = clampf(release_timer / 28.0, 0.0, 1.0)
		end_pos += Vector2(sin(release_timer * 0.7) * 8.0, (1.0 - alpha) * 20.0)
	_draw_rope_segments(canvas, origin, end_pos, alpha, phase)
	if phase == "bound":
		_draw_bound_knot(canvas, target, context)
	elif phase == "throwing":
		_draw_rope_loop(canvas, end_pos, 10.0 + progress * 8.0, alpha)


func _draw_rope_segments(
	canvas: CanvasItem,
	origin: Vector2,
	target: Vector2,
	alpha: float,
	phase: String
) -> void:
	var segment_count: int = 16 if phase == "bound" else 14
	var points := PackedVector2Array()
	for index in range(segment_count + 1):
		var t: float = float(index) / float(segment_count)
		var point: Vector2 = origin.lerp(target, t)
		var sag_scale: float = sin(t * PI)
		if phase in ["miss", "releasing"]:
			point.y += sag_scale * 20.0
		else:
			point += Vector2(0.0, sin(t * TAU * 3.0) * 1.8 * sag_scale)
		points.append(point)
	for index in range(points.size() - 1):
		canvas.draw_line(points[index], points[index + 1], Color(ROPE_DARK.r, ROPE_DARK.g, ROPE_DARK.b, ROPE_DARK.a * alpha), 5.0)
		canvas.draw_line(points[index], points[index + 1], Color(ROPE_BASE.r, ROPE_BASE.g, ROPE_BASE.b, ROPE_BASE.a * alpha), 3.0)
		canvas.draw_line(points[index], points[index + 1], Color(ROPE_LIGHT.r, ROPE_LIGHT.g, ROPE_LIGHT.b, ROPE_LIGHT.a * alpha), 1.0)


func _draw_rope_loop(canvas: CanvasItem, center: Vector2, radius: float, alpha: float) -> void:
	canvas.draw_arc(center, radius, -0.35, TAU - 0.35, 24, Color(ROPE_DARK.r, ROPE_DARK.g, ROPE_DARK.b, alpha), 5.0)
	canvas.draw_arc(center, radius, -0.35, TAU - 0.35, 24, Color(ROPE_LIGHT.r, ROPE_LIGHT.g, ROPE_LIGHT.b, alpha), 2.0)


func _draw_bound_knot(canvas: CanvasItem, center: Vector2, context: Dictionary) -> void:
	var pulse: float = 0.72 + 0.28 * sin(float(context.get("time_seconds", 0.0)) * 7.0)
	_draw_rope_loop(canvas, center, 22.0, pulse)
	canvas.draw_line(center + Vector2(-10.0, -10.0), center + Vector2(10.0, 10.0), Color(ROPE_LIGHT.r, ROPE_LIGHT.g, ROPE_LIGHT.b, pulse), 3.0)
	canvas.draw_line(center + Vector2(10.0, -10.0), center + Vector2(-10.0, 10.0), Color(ROPE_LIGHT.r, ROPE_LIGHT.g, ROPE_LIGHT.b, pulse), 3.0)
	var ratio: float = clampf(float(context.get("stage1_pododaejang_arrest_rope_bound_ratio", 0.0)), 0.0, 1.0)
	canvas.draw_arc(center, 35.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 28, Color(0.95, 0.75, 0.30, 0.88), 2.0)
