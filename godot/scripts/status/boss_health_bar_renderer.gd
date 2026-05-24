extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const BAR_WIDTH := 200.0
const BAR_HEIGHT := 8.0
const BAR_Y_OFFSET := 35.0
const FRAME_PAD := 5.0


func draw(
	canvas: CanvasItem,
	context: Dictionary,
	boss_pos: Vector2,
	boss_paddle_size: Vector2,
	boss_hitbox_height: float,
	shake_offset: Vector2
) -> void:
	if canvas == null:
		return
	var max_health: int = max(0, int(context.get("boss_max_health", 0)))
	if max_health <= 0:
		return
	var current_health: int = clamp(int(context.get("boss_current_health", max_health)), 0, max_health)
	var ratio: float = clamp(float(current_health) / float(max_health), 0.0, 1.0)
	var bar_x: float = boss_pos.x + boss_paddle_size.x * 0.5 - BAR_WIDTH * 0.5 + shake_offset.x
	var bar_y: float = boss_pos.y + boss_hitbox_height + BAR_Y_OFFSET + shake_offset.y
	var bg_rect := Rect2(bar_x, bar_y, BAR_WIDTH, BAR_HEIGHT)
	var frame_points := PackedVector2Array([
		bg_rect.position + Vector2(-FRAME_PAD, BAR_HEIGHT * 0.5),
		bg_rect.position + Vector2(-2.0, -3.0),
		bg_rect.position + Vector2(BAR_WIDTH + 2.0, -3.0),
		bg_rect.position + Vector2(BAR_WIDTH + FRAME_PAD, BAR_HEIGHT * 0.5),
		bg_rect.position + Vector2(BAR_WIDTH + 2.0, BAR_HEIGHT + 3.0),
		bg_rect.position + Vector2(-2.0, BAR_HEIGHT + 3.0),
	])
	var frame_outline := frame_points.duplicate()
	frame_outline.append(frame_points[0])
	canvas.draw_colored_polygon(frame_points, Color(0.02, 0.025, 0.035, 0.82))
	canvas.draw_polyline(frame_outline, Color(0.85, 0.88, 0.95, 0.44), 1.2, true)
	canvas.draw_rect(bg_rect, Color(0.05, 0.06, 0.07, 0.90), true)
	for tick_x in range(20, int(BAR_WIDTH), 20):
		canvas.draw_line(
			Vector2(bar_x + float(tick_x), bar_y),
			Vector2(bar_x + float(tick_x), bar_y + BAR_HEIGHT),
			Color(1.0, 1.0, 1.0, 0.09),
			1.0
		)
	if ratio > 0.0:
		var fill_width: float = max(1.0, BAR_WIDTH * ratio)
		var fill_rect := Rect2(bar_x, bar_y, fill_width, BAR_HEIGHT)
		var health_color: Color = _get_health_color(ratio)
		canvas.draw_rect(fill_rect, Color(health_color.r * 0.35, health_color.g * 0.35, health_color.b * 0.35, 0.96), true)
		canvas.draw_rect(Rect2(fill_rect.position, Vector2(fill_width, max(1.0, BAR_HEIGHT * 0.45))), health_color, true)
		var highlight_width: float = min(18.0, fill_width)
		if highlight_width > 2.0:
			canvas.draw_rect(
				Rect2(bar_x + fill_width - highlight_width, bar_y, highlight_width, BAR_HEIGHT),
				Color(1.0, 1.0, 1.0, 0.12),
				true
			)
	canvas.draw_rect(bg_rect, Color(0.95, 0.97, 1.0, 0.46), false, 1.0)
	_draw_health_text(canvas, bg_rect, current_health, max_health)
	if current_health <= max(1, int(ceil(float(max_health) * 0.2))) and current_health > 0:
		canvas.draw_rect(bg_rect.grow(5.0), Color(1.0, 0.15, 0.10, 0.34), false, 2.0)


func _get_health_color(ratio: float) -> Color:
	if ratio > 0.5:
		return Color(0.0, 0.78, 0.70, 0.96)
	if ratio > 0.2:
		return Color(0.95, 0.78, 0.12, 0.96)
	return Color(0.96, 0.20, 0.18, 0.96)


func _draw_health_text(canvas: CanvasItem, bg_rect: Rect2, current_health: int, max_health: int) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var label := LanguageSettings.translate_text("체력")
	var value := "%02d/%02d" % [current_health, max_health]
	var label_size: int = 13
	var value_size: int = 13
	var label_pos := Vector2(bg_rect.position.x - 34.0, bg_rect.position.y + BAR_HEIGHT + 1.0)
	var value_pos := Vector2(bg_rect.end.x + 10.0, bg_rect.position.y + BAR_HEIGHT + 1.0)
	canvas.draw_string(font, label_pos + Vector2(1.0, 1.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label_size, Color(0.0, 0.0, 0.0, 0.70))
	canvas.draw_string(font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label_size, Color(0.86, 0.92, 1.0, 0.94))
	canvas.draw_rect(Rect2(value_pos + Vector2(-3.0, -BAR_HEIGHT - 1.0), Vector2(52.0, BAR_HEIGHT + 6.0)), Color(0.02, 0.025, 0.035, 0.74), true)
	canvas.draw_string(font, value_pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, value_size, Color(0.95, 0.97, 1.0, 0.96))
