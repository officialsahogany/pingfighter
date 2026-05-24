extends RefCounted


func draw(
	canvas: CanvasItem,
	pillar_drawer: Object,
	center: Vector2,
	inner_radius: float,
	max_tokens: int,
	divider_anim_progress: float,
	start_angle_offset: float,
	sector_angle: float,
	scale_factor: float
) -> void:
	if canvas == null or pillar_drawer == null:
		return
	if max_tokens <= 1:
		return

	var divider_progress: float = pillar_drawer.ease_out_cubic(divider_anim_progress)
	for i in range(max_tokens):
		_draw_divider_line(
			canvas,
			center,
			inner_radius,
			start_angle_offset + sector_angle * float(i),
			divider_progress,
			scale_factor
		)
	_draw_center_chrome(canvas, center, scale_factor)


func _draw_divider_line(
	canvas: CanvasItem,
	center: Vector2,
	inner_radius: float,
	divider_angle: float,
	divider_progress: float,
	scale_factor: float
) -> void:
	var current_length: float = (inner_radius - 6.0) * divider_progress
	for seg in range(12):
		var start_ratio: float = float(seg) / 12.0
		var end_ratio: float = float(seg + 1) / 12.0
		var seg_start: Vector2 = center + Vector2(cos(divider_angle), sin(divider_angle)) * current_length * start_ratio
		var seg_end: Vector2 = center + Vector2(cos(divider_angle), sin(divider_angle)) * current_length * end_ratio
		var thickness: float = max(1.0, 4.0 - float(seg) * 0.25)
		var gold_mix: float = 1.0 - float(seg) / 12.0
		canvas.draw_line(seg_start, seg_end, Color(0.62 + gold_mix * 0.18, 0.46 + gold_mix * 0.14, 0.20 + gold_mix * 0.10, 0.80), thickness)

	var tip_pos: Vector2 = center + Vector2(cos(divider_angle), sin(divider_angle)) * current_length
	canvas.draw_circle(tip_pos, 3.0 * scale_factor, Color(0.82, 0.66, 0.34, 0.76))
	canvas.draw_circle(tip_pos, 2.0 * scale_factor, Color(1.0, 0.86, 0.54, 0.64))


func _draw_center_chrome(canvas: CanvasItem, center: Vector2, scale_factor: float) -> void:
	canvas.draw_circle(center, 6.0 * scale_factor, Color(0.70, 0.54, 0.24, 0.92))
	canvas.draw_circle(center, 4.0 * scale_factor, Color(0.90, 0.74, 0.40, 0.92))
	canvas.draw_circle(center, 2.0 * scale_factor, Color(1.0, 0.90, 0.66, 0.94))
