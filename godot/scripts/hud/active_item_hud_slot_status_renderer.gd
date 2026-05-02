extends RefCounted


func draw_status_overlays(canvas: Node2D, slot_rect: Rect2, scale_factor: float, slot_status: Dictionary) -> float:
	var remaining_ratio: float = float(slot_status.get("cooldown_remaining_ratio", 0.0))
	if remaining_ratio > 0.0:
		canvas.draw_rect(slot_rect, Color(0.0, 0.0, 0.0, 80.0 / 255.0))
		_draw_slot_cooldown_frame(canvas, slot_rect, remaining_ratio, scale_factor)

	var flash_pulse: float = float(slot_status.get("cooldown_flash_pulse", 0.0))
	if flash_pulse > 0.0:
		var flash_alpha: float = floor(flash_pulse * 255.0 / 16.0) * 16.0 / 255.0
		canvas.draw_rect(slot_rect, Color(1.0, 230.0 / 255.0, 100.0 / 255.0, flash_alpha))
		canvas.draw_rect(slot_rect.grow(2.0), Color(1.0, 230.0 / 255.0, 100.0 / 255.0, flash_pulse * 200.0 / 255.0), false, 3.0)

	var remaining_seconds: int = int(slot_status.get("throw_lock_remaining_seconds", 0))
	if remaining_seconds > 0:
		canvas.draw_rect(slot_rect, Color(0.0, 0.0, 0.0, 150.0 / 255.0))
		_draw_text_centered(
			canvas,
			slot_rect.get_center(),
			str(remaining_seconds),
			max(14, int(20.0 * scale_factor)),
			Color(1.0, 100.0 / 255.0, 100.0 / 255.0),
			1.0
		)
	return remaining_ratio


func _draw_slot_cooldown_frame(canvas: Node2D, slot_rect: Rect2, remaining_ratio: float, scale_factor: float) -> void:
	var clamped_ratio: float = clamp(remaining_ratio, 0.0, 1.0)
	if clamped_ratio <= 0.0:
		return

	var line_width: float = max(2.0, floor(2.0 * scale_factor))
	var inset: float = max(2.0, floor(line_width * 0.5) + 1.0)
	var frame_rect: Rect2 = slot_rect.grow(-inset)
	if frame_rect.size.x <= 4.0 or frame_rect.size.y <= 4.0:
		return

	canvas.draw_rect(frame_rect, Color(8.0 / 255.0, 12.0 / 255.0, 18.0 / 255.0, 135.0 / 255.0), false, line_width)
	_draw_rect_progress(
		canvas,
		frame_rect,
		clamped_ratio,
		Color(120.0 / 255.0, 224.0 / 255.0, 238.0 / 255.0, 230.0 / 255.0),
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


func _draw_text_centered(canvas: Node2D, center: Vector2, text: String, font_size: int, color: Color, alpha: float) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var pos: Vector2 = center - text_size * 0.5 + Vector2(0.0, text_size.y * 0.35)
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(color.r, color.g, color.b, color.a * alpha))
