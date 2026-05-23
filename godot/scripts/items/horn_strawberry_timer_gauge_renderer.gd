extends RefCounted

const BAR_BG := Color(0.08, 0.02, 0.03, 0.95)
const BAR_FRAME := Color(0.58, 0.06, 0.10, 0.92)
const BAR_FRAME_LIGHT := Color(1.0, 0.36, 0.42, 0.82)
const BAR_FILL := Color(0.92, 0.08, 0.14, 0.98)
const BAR_FILL_LIGHT := Color(1.0, 0.54, 0.58, 0.98)
const SEED_GOLD := Color(0.96, 0.82, 0.28, 0.88)


func draw_transform_timer_gauge(
	canvas: CanvasItem,
	timer_stack: Object,
	context: Dictionary,
	bar_size: Vector2,
	margin: Vector2,
	stack_spacing: float,
	stack_key: String
) -> void:
	if canvas == null or not bool(context.get("transformed", false)):
		return
	var total_sec: float = max(0.001, float(context.get("transform_duration_sec", 60.0)))
	var remaining_sec: float = clamp(float(context.get("transform_timer_sec", 0.0)), 0.0, total_sec)
	var ratio: float = clamp(remaining_sec / total_sec, 0.0, 1.0)
	var stack_index: int = _claim_timer_stack_index(timer_stack, stack_key)
	var frame_rect := Rect2(_get_timer_bar_position(stack_index, bar_size, margin, stack_spacing), bar_size)
	var pulse: float = abs(sin(float(Time.get_ticks_msec()) * 0.014))
	var warning: bool = remaining_sec <= 6.0
	var fill_color := BAR_FILL
	var fill_light := BAR_FILL_LIGHT
	if warning:
		fill_color = Color(1.0, 0.08 + pulse * 0.20, 0.10, 0.99)
		fill_light = Color(1.0, 0.80, 0.38, 0.99)
	_draw_frame(canvas, frame_rect)
	_draw_fill(canvas, frame_rect, ratio, fill_color, fill_light)
	_draw_icon(canvas, frame_rect.position + Vector2(-19.0, frame_rect.size.y * 0.5), pulse)
	var font: Font = ThemeDB.fallback_font
	if font != null:
		var label := "뿔딸기 %.1f" % remaining_sec
		canvas.draw_string(font, frame_rect.position + Vector2(8.0, -6.0), label, HORIZONTAL_ALIGNMENT_LEFT, 104.0, 10, Color(1.0, 0.94, 0.92, 0.90))


func _draw_frame(canvas: CanvasItem, frame_rect: Rect2) -> void:
	canvas.draw_rect(frame_rect.grow(5.0), Color(0.0, 0.0, 0.0, 0.28))
	canvas.draw_rect(frame_rect.grow(5.0), Color(0.18, 0.03, 0.04, 0.94))
	canvas.draw_rect(frame_rect.grow(3.0), BAR_FRAME)
	canvas.draw_rect(frame_rect.grow(3.0), BAR_FRAME_LIGHT, false, 2.0)
	canvas.draw_rect(frame_rect.grow(2.0), Color(0.30, 0.02, 0.04, 0.96))
	canvas.draw_rect(frame_rect, BAR_BG)


func _draw_fill(canvas: CanvasItem, frame_rect: Rect2, ratio: float, base_color: Color, light_color: Color) -> void:
	var fill_width: float = max(1.0, (frame_rect.size.x - 4.0) * ratio)
	var fill_rect := Rect2(frame_rect.position + Vector2(2.0, 2.0), Vector2(fill_width, frame_rect.size.y - 4.0))
	canvas.draw_rect(fill_rect, base_color)
	canvas.draw_rect(Rect2(fill_rect.position, Vector2(fill_rect.size.x, max(2.0, fill_rect.size.y * 0.38))), light_color)
	for i in range(1, 10):
		var tick_x: float = frame_rect.position.x + 2.0 + (frame_rect.size.x - 4.0) * (float(i) / 10.0)
		canvas.draw_line(
			Vector2(tick_x, frame_rect.position.y + frame_rect.size.y - 4.0),
			Vector2(tick_x, frame_rect.position.y + frame_rect.size.y - 1.0),
			SEED_GOLD,
			1.0
		)


func _draw_icon(canvas: CanvasItem, center: Vector2, pulse: float) -> void:
	canvas.draw_circle(center, 14.0 + pulse * 2.0, Color(1.0, 0.08, 0.12, 0.16 + pulse * 0.08))
	canvas.draw_circle(center + Vector2(0.0, 1.0), 8.5, Color(0.90, 0.07, 0.12, 0.88))
	canvas.draw_circle(center + Vector2(-2.8, -1.8), 3.0, Color(1.0, 0.58, 0.60, 0.62))
	for side in [-1, 1]:
		var base := center + Vector2(float(side) * 4.5, -7.0)
		var tip := center + Vector2(float(side) * 9.0, -16.0)
		canvas.draw_line(base, tip, Color(0.15, 0.64, 0.13, 0.92), 3.0)
		canvas.draw_circle(tip, 2.8, Color(0.48, 0.88, 0.32, 0.92))
	for seed_offset in [Vector2(-2.0, 1.0), Vector2(2.8, -0.8), Vector2(0.8, 3.6)]:
		canvas.draw_circle(center + seed_offset, 1.2, Color(0.98, 0.84, 0.30, 0.90))


func _claim_timer_stack_index(timer_stack: Object, key: String) -> int:
	if timer_stack != null and timer_stack.has_method("claim"):
		var claimed: int = int(timer_stack.claim(key, true))
		if claimed >= 0:
			return claimed
	return 0


func _get_timer_bar_position(stack_index: int, bar_size: Vector2, margin: Vector2, stack_spacing: float) -> Vector2:
	return Vector2(
		760.0 - bar_size.x - margin.x,
		750.0 - margin.y - float(max(0, stack_index)) * stack_spacing
	)
