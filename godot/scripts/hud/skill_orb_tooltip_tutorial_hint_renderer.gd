extends RefCounted

const POINTER_TRAVEL_SECONDS := 1.25
const POINTER_FINISH_SECONDS := 1.45
const POINTER_TRAIL_COUNT := 6
const FONT_SIZE := 23
const MIN_FONT_SIZE := 17
const FOCUS_SHADOW_ALPHA := 0.68
const FOCUS_GROW := 22.0
const PHASE_POINTER := "pointer"


static func draw_overlay(
	canvas: CanvasItem,
	view_size: Vector2,
	phase: String,
	elapsed: float,
	highlight_rect: Rect2,
	message_lines: Array[String],
	text_size_cache: Dictionary,
	alpha: float
) -> void:
	if canvas == null or alpha <= 0.001:
		return
	if highlight_rect.size != Vector2.ZERO:
		_draw_focus_shadow(canvas, view_size, highlight_rect, alpha)
		_draw_orb_highlight(canvas, highlight_rect, alpha)
		if phase == PHASE_POINTER:
			_draw_guidance_pointer(canvas, view_size, highlight_rect, elapsed, alpha)
	else:
		canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, FOCUS_SHADOW_ALPHA * alpha))
	_draw_message(canvas, view_size, message_lines, text_size_cache, alpha)


static func pointer_progress(phase: String, elapsed: float) -> float:
	if phase != PHASE_POINTER:
		return 0.0
	return smooth_step(clampf(elapsed / POINTER_TRAVEL_SECONDS, 0.0, 1.0))


static func smooth_step(value: float) -> float:
	var t: float = clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _draw_orb_highlight(canvas: CanvasItem, rect: Rect2, alpha: float) -> void:
	var center: Vector2 = rect.get_center()
	var radius: float = max(rect.size.x, rect.size.y) * 0.5
	var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec() % 900) / 900.0 * TAU)
	var outer_radius: float = radius + 10.0 + 5.0 * pulse
	canvas.draw_circle(center, outer_radius + 4.0, Color(0.0, 0.0, 0.0, 0.28 * alpha))
	canvas.draw_circle(center, outer_radius, Color(1.0, 0.92, 0.28, 0.16 * alpha))
	canvas.draw_circle(center, outer_radius, Color(1.0, 0.92, 0.28, 0.92 * alpha), false, 4.0)
	canvas.draw_circle(center, radius + 4.0, Color(1.0, 1.0, 1.0, 0.64 * alpha), false, 2.0)


static func _draw_guidance_pointer(canvas: CanvasItem, view_size: Vector2, target_rect: Rect2, elapsed: float, alpha: float) -> void:
	if target_rect.size == Vector2.ZERO:
		return
	var start: Vector2 = _get_pointer_start(view_size, target_rect)
	var target: Vector2 = target_rect.get_center() + Vector2(9.0, 8.0)
	var control: Vector2 = Vector2(
		lerpf(start.x, target.x, 0.52),
		min(start.y, target.y) - max(64.0, view_size.y * 0.08)
	)
	var progress: float = pointer_progress(PHASE_POINTER, elapsed)
	for i in range(POINTER_TRAIL_COUNT, 0, -1):
		var trail_progress: float = clampf(progress - float(i) * 0.075, 0.0, 1.0)
		if progress <= 0.02 and trail_progress <= 0.0:
			continue
		var trail_alpha: float = alpha * (1.0 - float(i) / float(POINTER_TRAIL_COUNT + 1)) * 0.34
		_draw_mouse_cursor(canvas, _quadratic_bezier(start, control, target, trail_progress), 0.90, trail_alpha)
	var cursor_pos: Vector2 = _quadratic_bezier(start, control, target, progress)
	_draw_mouse_cursor(canvas, cursor_pos, 1.0, alpha)
	if progress >= 0.96:
		var click_alpha: float = alpha * smooth_step((progress - 0.96) / 0.04)
		var click_radius: float = target_rect.size.x * 0.46 + 8.0 * sin(float(Time.get_ticks_msec() % 420) / 420.0 * TAU)
		canvas.draw_circle(target_rect.get_center(), click_radius, Color(1.0, 1.0, 1.0, 0.28 * click_alpha), false, 2.0)


static func _draw_mouse_cursor(canvas: CanvasItem, position: Vector2, scale: float, alpha: float) -> void:
	if alpha <= 0.001:
		return
	var base_points: Array[Vector2] = [
		Vector2(0.0, 0.0),
		Vector2(0.0, 31.0),
		Vector2(8.0, 23.0),
		Vector2(13.0, 36.0),
		Vector2(20.0, 33.0),
		Vector2(15.0, 21.0),
		Vector2(27.0, 21.0),
	]
	var points := PackedVector2Array()
	for point in base_points:
		points.append(position + point * scale)
	canvas.draw_colored_polygon(points, Color(0.95, 0.98, 1.0, 0.88 * alpha))
	canvas.draw_polyline(
		PackedVector2Array([points[0], points[1], points[2], points[3], points[4], points[5], points[6], points[0]]),
		Color(0.02, 0.04, 0.08, 0.82 * alpha),
		2.0 * scale,
		true
	)
	canvas.draw_line(
		position + Vector2(5.0, 5.0) * scale,
		position + Vector2(15.0, 17.0) * scale,
		Color(0.42, 0.78, 1.0, 0.42 * alpha),
		1.5 * scale
	)


static func _draw_focus_shadow(canvas: CanvasItem, view_size: Vector2, rect: Rect2, alpha: float) -> void:
	var screen_rect := Rect2(Vector2.ZERO, view_size)
	var focus_rect: Rect2 = rect.grow(FOCUS_GROW).intersection(screen_rect)
	if focus_rect.size.x <= 0.0 or focus_rect.size.y <= 0.0:
		canvas.draw_rect(screen_rect, Color(0.0, 0.0, 0.0, FOCUS_SHADOW_ALPHA * alpha))
		return
	var shadow_color := Color(0.0, 0.0, 0.0, FOCUS_SHADOW_ALPHA * alpha)
	if focus_rect.position.y > 0.0:
		canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(view_size.x, focus_rect.position.y)), shadow_color)
	if focus_rect.end.y < view_size.y:
		canvas.draw_rect(Rect2(Vector2(0.0, focus_rect.end.y), Vector2(view_size.x, view_size.y - focus_rect.end.y)), shadow_color)
	if focus_rect.position.x > 0.0:
		canvas.draw_rect(Rect2(Vector2(0.0, focus_rect.position.y), Vector2(focus_rect.position.x, focus_rect.size.y)), shadow_color)
	if focus_rect.end.x < view_size.x:
		canvas.draw_rect(Rect2(Vector2(focus_rect.end.x, focus_rect.position.y), Vector2(view_size.x - focus_rect.end.x, focus_rect.size.y)), shadow_color)


static func _draw_message(
	canvas: CanvasItem,
	view_size: Vector2,
	lines: Array[String],
	text_size_cache: Dictionary,
	alpha: float
) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null or lines.is_empty():
		return
	var font_size: int = _get_fit_font_size(font, lines, view_size.x, text_size_cache)
	var text_size: Vector2 = _get_text_block_size(font, lines, font_size, text_size_cache)
	var center := Vector2(view_size.x * 0.5, view_size.y * 0.53)
	var padding := Vector2(24.0, 14.0)
	var panel_rect := Rect2(center - (text_size + padding * 2.0) * 0.5, text_size + padding * 2.0)
	_draw_round_rect(canvas, panel_rect, 9.0, Color(0.02, 0.04, 0.08, 0.68 * alpha))
	canvas.draw_rect(panel_rect, Color(0.88, 0.96, 1.0, 0.18 * alpha), false, 1.5)
	var line_height: float = _get_line_height(font, font_size)
	var line_gap := 5.0
	var y: float = center.y - text_size.y * 0.5 + font.get_ascent(font_size)
	for i in range(lines.size()):
		var line: String = lines[i]
		var line_width: float = _get_text_size(font, line, font_size, text_size_cache).x
		var baseline := Vector2(center.x - line_width * 0.5, y)
		var text_color := Color(0.94, 0.98, 1.0, alpha)
		if i == 0:
			text_color = Color(1.0, 0.94, 0.58, alpha)
		canvas.draw_string_outline(font, baseline, line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 4, Color(0.0, 0.0, 0.0, 0.80 * alpha))
		canvas.draw_string(font, baseline, line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, text_color)
		y += line_height + line_gap


static func _draw_round_rect(canvas: CanvasItem, rect: Rect2, radius: float, color: Color) -> void:
	canvas.draw_rect(Rect2(rect.position + Vector2(radius, 0.0), Vector2(rect.size.x - radius * 2.0, rect.size.y)), color)
	canvas.draw_rect(Rect2(rect.position + Vector2(0.0, radius), Vector2(rect.size.x, rect.size.y - radius * 2.0)), color)
	canvas.draw_circle(rect.position + Vector2(radius, radius), radius, color)
	canvas.draw_circle(rect.position + Vector2(rect.size.x - radius, radius), radius, color)
	canvas.draw_circle(rect.position + Vector2(radius, rect.size.y - radius), radius, color)
	canvas.draw_circle(rect.position + rect.size - Vector2(radius, radius), radius, color)


static func _get_fit_font_size(font: Font, lines: Array[String], max_width: float, text_size_cache: Dictionary) -> int:
	var font_size: int = FONT_SIZE
	var available_width: float = max(120.0, max_width - 72.0)
	while font_size > MIN_FONT_SIZE and _get_text_block_size(font, lines, font_size, text_size_cache).x > available_width:
		font_size -= 1
	return font_size


static func _get_text_block_size(font: Font, lines: Array[String], font_size: int, text_size_cache: Dictionary) -> Vector2:
	var max_width := 0.0
	for line in lines:
		max_width = max(max_width, _get_text_size(font, line, font_size, text_size_cache).x)
	var line_gap := 5.0
	var height: float = _get_line_height(font, font_size) * float(lines.size())
	if lines.size() > 1:
		height += line_gap * float(lines.size() - 1)
	return Vector2(max_width, height)


static func _get_text_size(font: Font, text: String, font_size: int, text_size_cache: Dictionary) -> Vector2:
	var cache_key := "%s|%d" % [text, font_size]
	if text_size_cache.has(cache_key):
		var cached: Variant = text_size_cache[cache_key]
		if cached is Vector2:
			return cached
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	text_size_cache[cache_key] = text_size
	return text_size


static func _get_line_height(font: Font, font_size: int) -> float:
	return max(1.0, font.get_string_size("Ag", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).y)


static func _get_pointer_start(view_size: Vector2, target_rect: Rect2) -> Vector2:
	var side: float = 1.0 if target_rect.get_center().x < view_size.x * 0.5 else -1.0
	return Vector2(
		clampf(view_size.x * 0.5 + view_size.x * 0.18 * side, 72.0, view_size.x - 72.0),
		clampf(view_size.y * 0.56, 96.0, view_size.y - 96.0)
	)


static func _quadratic_bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var inv := 1.0 - t
	return a * inv * inv + b * 2.0 * inv * t + c * t * t
