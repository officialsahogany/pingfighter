extends RefCounted


func draw_fill(
	canvas: CanvasItem,
	bar_x: float,
	bar_y: float,
	bar_h: float,
	fill_w: float,
	progress: float,
	combo_color: Color,
	glow_color: Color,
	fill_alpha_mult: float,
	display_combo: int
) -> void:
	var tick_ms: float = float(Time.get_ticks_msec())
	var fill_rect: Rect2 = Rect2(bar_x, bar_y, fill_w, bar_h)
	canvas.draw_rect(fill_rect, Color(combo_color.r, combo_color.g, combo_color.b, 0.75 * fill_alpha_mult))
	for shade_idx in range(int(max(1.0, fill_w))):
		var shade_t: float = float(shade_idx) / max(1.0, fill_w)
		var shade_color: Color = glow_color.lerp(combo_color, shade_t)
		canvas.draw_line(
			Vector2(bar_x + float(shade_idx), bar_y + 1.0),
			Vector2(bar_x + float(shade_idx), bar_y + bar_h - 1.0),
			Color(shade_color.r, shade_color.g, shade_color.b, 0.32 * fill_alpha_mult),
			1.0
		)

	var wave_points: PackedVector2Array = PackedVector2Array()
	var wave_amp: float = 1.0 + progress * 2.4
	var wave_step: int = 4
	for local_x in range(0, int(fill_w) + wave_step, wave_step):
		var clamped_x: float = min(float(local_x), fill_w)
		var wave_y: float = bar_y + 3.0 + sin(clamped_x * 0.12 + tick_ms * 0.010) * wave_amp + sin(clamped_x * 0.27 + tick_ms * 0.015) * wave_amp * 0.35
		wave_points.append(Vector2(bar_x + clamped_x, clamp(wave_y, bar_y + 1.0, bar_y + bar_h - 2.0)))
	if wave_points.size() >= 2:
		canvas.draw_polyline(wave_points, Color(1.0, 1.0, 1.0, 0.65 * fill_alpha_mult), 1.5)
		for wave_idx in range(wave_points.size()):
			if wave_idx % 3 == 0:
				canvas.draw_circle(wave_points[wave_idx] + Vector2(0.0, 1.5), 1.0, Color(1.0, 1.0, 1.0, 0.28 * fill_alpha_mult))

	if display_combo >= 2:
		_draw_bubbles(canvas, bar_x, bar_y, bar_h, fill_w, progress, fill_alpha_mult, tick_ms)


func draw_sparkles(
	canvas: CanvasItem,
	bar_x: float,
	bar_y: float,
	bar_h: float,
	fill_w: float,
	progress: float,
	fill_alpha_mult: float
) -> void:
	var sparkle_count: int = min(14, int(2.0 + progress * 12.0))
	for sparkle_idx in range(sparkle_count):
		var sparkle_phase: float = fmod(float(Time.get_ticks_msec()) * 0.0017 + float(sparkle_idx) * 0.37, 1.0)
		var sparkle_x: float = bar_x + fmod(float(sparkle_idx * 53 + 17) * 0.113, 1.0) * fill_w
		var sparkle_y: float = bar_y + 2.0 + fmod(float(sparkle_idx * 29 + 7) * 0.131, 1.0) * (bar_h - 4.0) - sparkle_phase * 4.0
		var sparkle_alpha: float = (1.0 - sparkle_phase) * fill_alpha_mult
		if sparkle_alpha > 0.03:
			canvas.draw_circle(Vector2(sparkle_x, sparkle_y), 1.0 + (1.0 if sparkle_phase < 0.5 else 0.0), Color(1.0, 1.0, 230.0 / 255.0, sparkle_alpha))


func _draw_bubbles(
	canvas: CanvasItem,
	bar_x: float,
	bar_y: float,
	bar_h: float,
	fill_w: float,
	progress: float,
	fill_alpha_mult: float,
	tick_ms: float
) -> void:
	var bubble_count: int = min(8, 1 + int(progress * 7.0))
	for bubble_idx in range(bubble_count):
		var cycle: float = 1.2 + float((bubble_idx * 173) % 900) / 1000.0
		var bubble_t: float = fmod(tick_ms / 1000.0 + float(bubble_idx) * 0.2, cycle) / cycle
		var bubble_x: float = bar_x + fmod(float(bubble_idx * 31 + 11) * 0.173, 1.0) * fill_w
		var bubble_y: float = bar_y + bar_h - bubble_t * (bar_h - 3.0) - 1.0
		var bubble_alpha: float = (1.0 - bubble_t) * 0.65 * fill_alpha_mult
		if bubble_x > bar_x + 2.0 and bubble_x < bar_x + fill_w - 2.0 and bubble_alpha > 0.02:
			canvas.draw_circle(Vector2(bubble_x, bubble_y), 1.4, Color(1.0, 1.0, 1.0, bubble_alpha))
