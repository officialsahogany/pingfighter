extends RefCounted


func draw_slot_panel(canvas: Node2D, rect: Rect2, fill_color: Color, border_color: Color) -> void:
	canvas.draw_rect(rect, fill_color)
	canvas.draw_rect(rect, border_color, false, 1.0)
	canvas.draw_line(rect.position + Vector2(1.0, 1.0), Vector2(rect.end.x - 1.0, rect.position.y + 1.0), Color(1.0, 1.0, 1.0, 0.05), 1.0)
	canvas.draw_line(Vector2(rect.position.x + 1.0, rect.end.y - 1.0), rect.end - Vector2(1.0, 1.0), Color(0.0, 0.0, 0.0, 0.22), 1.0)


func draw_cooldown_status_frame_for_slots(
	canvas: Node2D,
	slot_rects: Array,
	scale_factor: float,
	remaining_ratio: float
) -> void:
	if remaining_ratio <= 0.0 or slot_rects.is_empty():
		return
	var rect: Rect2 = _get_bounds(slot_rects)
	var cooldown_pad: float = max(11.0, round(13.0 * scale_factor))
	_draw_cooldown_status_frame(canvas, rect.grow(cooldown_pad), remaining_ratio)


func _get_bounds(rects: Array) -> Rect2:
	var first_rect: Rect2 = rects[0]
	var left: float = first_rect.position.x
	var top: float = first_rect.position.y
	var right: float = first_rect.end.x
	var bottom: float = first_rect.end.y
	for rect_variant in rects:
		var rect: Rect2 = rect_variant
		left = min(left, rect.position.x)
		top = min(top, rect.position.y)
		right = max(right, rect.end.x)
		bottom = max(bottom, rect.end.y)
	return Rect2(left, top, right - left, bottom - top)


func _draw_cooldown_status_frame(canvas: Node2D, rect: Rect2, remaining_ratio: float) -> void:
	var clamped_ratio: float = clamp(remaining_ratio, 0.0, 1.0)
	if clamped_ratio <= 0.0:
		return

	var line_width: float = max(3.0, min(rect.size.x, rect.size.y) * 0.075)
	var inset: float = max(2.0, floor(line_width * 0.5) + 1.0)
	var frame_rect: Rect2 = rect.grow(-inset)
	if frame_rect.size.x <= 2.0 or frame_rect.size.y <= 2.0:
		return

	canvas.draw_rect(frame_rect, Color(9.0 / 255.0, 12.0 / 255.0, 18.0 / 255.0, 125.0 / 255.0), false, line_width)
	_draw_rect_progress(
		canvas,
		frame_rect,
		clamped_ratio,
		Color(120.0 / 255.0, 224.0 / 255.0, 238.0 / 255.0, 220.0 / 255.0),
		line_width
	)


func _draw_rect_progress(canvas: Node2D, rect: Rect2, ratio: float, color: Color, line_width: float) -> void:
	var points: Array[Vector2] = [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
		rect.position,
	]
	var perimeter: float = rect.size.x * 2.0 + rect.size.y * 2.0
	var remaining: float = perimeter * clamp(ratio, 0.0, 1.0)
	for i in range(points.size() - 1):
		if remaining <= 0.0:
			break
		var start: Vector2 = points[i]
		var end: Vector2 = points[i + 1]
		var segment_length: float = start.distance_to(end)
		if segment_length <= 0.0:
			continue
		var draw_length: float = min(remaining, segment_length)
		var segment_end: Vector2 = start.lerp(end, draw_length / segment_length)
		canvas.draw_line(start, segment_end, color, line_width)
		remaining -= draw_length
