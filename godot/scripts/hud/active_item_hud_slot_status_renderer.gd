extends RefCounted


func draw_status_overlays(canvas: Node2D, slot_rect: Rect2, scale_factor: float, slot_status: Dictionary) -> float:
	var remaining_ratio: float = float(slot_status.get("cooldown_remaining_ratio", 0.0))
	if remaining_ratio > 0.0:
		canvas.draw_rect(slot_rect, Color(0.0, 0.0, 0.0, 80.0 / 255.0))

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


func _draw_text_centered(canvas: Node2D, center: Vector2, text: String, font_size: int, color: Color, alpha: float) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var pos: Vector2 = center - text_size * 0.5 + Vector2(0.0, text_size.y * 0.35)
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(color.r, color.g, color.b, color.a * alpha))
