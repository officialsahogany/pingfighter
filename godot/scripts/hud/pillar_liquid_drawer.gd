extends RefCounted

const PillarShapeHelper := preload("res://scripts/hud/pillar_shape_helper.gd")

var shape_helper: Object = PillarShapeHelper.new()


func draw_pillar_liquid_fill(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	fill_ratio: float,
	t: float,
	top_color: Color,
	bottom_color: Color,
	wave_glow: Color
) -> void:
	if canvas == null:
		return
	var clamped_ratio: float = clamp(fill_ratio, 0.0, 1.0)
	if clamped_ratio <= 0.0:
		return

	var inner_radius: float = max(4.0, radius)
	var fill_height: float = inner_radius * 2.0 * clamped_ratio
	var fill_top: float = center.y + inner_radius - fill_height
	var wave_amp: float = max(3.5, inner_radius * 0.10)
	var wave_offset: float = sin(t * 2.3) * wave_amp * 0.5
	var prev_wave_point: Vector2 = Vector2.ZERO
	var has_prev: bool = false
	var step: int = 2

	for ix in range(int(-inner_radius), int(inner_radius) + 1, step):
		var local_x: float = float(ix)
		var y_limit: float = sqrt(max(0.0, inner_radius * inner_radius - local_x * local_x))
		var primary_wave: float = sin(local_x * 0.08 + t * 3.8) * wave_amp
		var secondary_wave: float = cos(local_x * 0.05 - t * 4.6) * wave_amp * 0.55
		var wave_y: float = fill_top + primary_wave + secondary_wave + wave_offset
		var line_top: float = clamp(max(center.y - y_limit, wave_y), center.y - y_limit, center.y + y_limit)
		var line_bottom: float = center.y + y_limit
		if line_top >= line_bottom:
			has_prev = false
			continue
		var gradient_t: float = clamp((line_top - (center.y - inner_radius)) / max(1.0, inner_radius * 2.0), 0.0, 1.0)
		var fill_color: Color = top_color.lerp(bottom_color, gradient_t)
		canvas.draw_line(Vector2(center.x + local_x, line_top), Vector2(center.x + local_x, line_bottom), fill_color, float(step))
		var wave_point := Vector2(center.x + local_x, line_top)
		if has_prev:
			canvas.draw_line(prev_wave_point, wave_point, Color(wave_glow.r, wave_glow.g, wave_glow.b, 0.50), 2.0)
		prev_wave_point = wave_point
		has_prev = true

	for band_idx in range(2):
		var band_ratio: float = 0.28 + float(band_idx) * 0.28
		var band_center_y: float = center.y + inner_radius - fill_height * band_ratio + sin(t * (2.6 + float(band_idx) * 0.8) + float(band_idx)) * (wave_amp * 1.0)
		for ix in range(int(-inner_radius) + 4, int(inner_radius) - 3, 4):
			var local_x: float = float(ix)
			var y_limit: float = sqrt(max(0.0, inner_radius * inner_radius - local_x * local_x))
			var band_dx_ratio: float = abs(local_x) / max(1.0, inner_radius)
			var band_width: float = (1.0 - band_dx_ratio) * (10.0 + inner_radius * 0.08)
			var line_y: float = clamp(band_center_y + sin(local_x * 0.09 + t * 2.0 + float(band_idx) * 0.6), center.y - y_limit, center.y + y_limit)
			var band_alpha: float = 0.06 + (1.0 - band_dx_ratio) * 0.08 * clamped_ratio
			if line_y > fill_top + 3.0 and line_y < center.y + y_limit - 2.0:
				canvas.draw_line(
					Vector2(center.x + local_x - band_width * 0.5, line_y),
					Vector2(center.x + local_x + band_width * 0.5, line_y),
					Color(wave_glow.r, wave_glow.g, wave_glow.b, band_alpha),
					1.5
				)

	var bubble_count: int = mini(5, int(round(3.0 + clamped_ratio * 3.0)))
	for i in range(bubble_count):
		var phase: float = t * 1.4 + float(i) * 1.26
		var bubble_x: float = center.x + sin(phase * 0.6 + float(i) * 2.1) * (inner_radius * (0.25 + float(i % 3) * 0.10))
		var bubble_offset_y: float = fmod(phase * (16.0 + float(i % 3) * 4.0) + float(i) * 24.0, max(1.0, fill_height))
		var bubble_y: float = center.y + inner_radius - bubble_offset_y
		var dx: float = bubble_x - center.x
		var dy: float = bubble_y - center.y
		if dx * dx + dy * dy < (inner_radius - 4.0) * (inner_radius - 4.0):
			var bubble_alpha: float = 0.35 + 0.18 * abs(sin(phase * 0.9))
			var bubble_radius: float = 2.0 + float(i % 3) * 0.8
			canvas.draw_circle(Vector2(bubble_x, bubble_y), bubble_radius, Color(0.86, 0.94, 1.0, bubble_alpha))
			canvas.draw_circle(Vector2(bubble_x - bubble_radius * 0.3, bubble_y - bubble_radius * 0.4), max(0.8, bubble_radius * 0.4), Color(1.0, 1.0, 1.0, bubble_alpha * 0.55))


func draw_dash_sector_liquid(
	canvas: CanvasItem,
	center: Vector2,
	inner_radius: float,
	start_rad: float,
	end_rad: float,
	progress: float,
	t: float,
	_scale_factor: float = 1.0
) -> void:
	if canvas == null:
		return
	var charge_radius: float = inner_radius * progress
	canvas.draw_colored_polygon(shape_helper.build_sector_points(center, charge_radius, start_rad, end_rad, 20), Color(0.76, 0.26, 0.22, 0.92))
	if progress > 0.15:
		canvas.draw_colored_polygon(shape_helper.build_sector_points(center, charge_radius * 0.72, start_rad, end_rad, 14), Color(1.0, 0.58, 0.44, 0.16 + 0.12 * progress))
	var pulse_r: float = charge_radius * (0.85 + 0.15 * sin(t * 5.0))
	canvas.draw_arc(center, pulse_r, start_rad, end_rad, 12, Color(1.0, 0.72, 0.56, 0.28 + 0.18 * sin(t * 4.0)), 2.0)
