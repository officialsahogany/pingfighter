extends RefCounted

const PillarShapeHelper := preload("res://scripts/hud/pillar_shape_helper.gd")

const LIQUID_SURFACE_STEP := 1.5
const LIQUID_SURFACE_STEP_LOD := 4.0
const LIQUID_BAND_STEP := 4.0
const LIQUID_BAND_STEP_LOD := 12.0
const LIQUID_MAX_BUBBLES := 2
const LIQUID_WAVE_GLOW_WIDTH := 1.4
const LIQUID_POLYGON_MAX_POINTS := 260
const LIQUID_ANIMATION_SPEED := 0.45
const LIQUID_EDGE_SEARCH_STEPS := 8
const LIQUID_SURFACE_GLOW_MIN_HEIGHT := 2.0
const LIQUID_STABLE_FULL_THRESHOLD := 0.999
const LIQUID_STABLE_FULL_SEGMENTS := 48
const LIQUID_FAST_LOD_SCALE := 0.60
const LIQUID_FAST_SEGMENTS := 24
const DASH_SECTOR_SEGMENTS := 14
const DASH_INNER_SECTOR_SEGMENTS := 9
const DASH_PULSE_ARC_POINTS := 9

var shape_helper: Object = PillarShapeHelper.new()


func draw_pillar_liquid_fill(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	fill_ratio: float,
	t: float,
	top_color: Color,
	bottom_color: Color,
	wave_glow: Color,
	quality_scale: float = 1.0
) -> void:
	if canvas == null:
		return
	var clamped_ratio: float = clamp(fill_ratio, 0.0, 1.0)
	if clamped_ratio <= 0.0:
		return

	var inner_radius: float = max(4.0, radius)
	if _is_stable_full_fill_ratio(clamped_ratio):
		_draw_stable_full_liquid(canvas, center, inner_radius, top_color, bottom_color)
		return
	if quality_scale <= LIQUID_FAST_LOD_SCALE:
		_draw_fast_lod_liquid(canvas, center, inner_radius, clamped_ratio, top_color, bottom_color, wave_glow)
		return

	var fill_height: float = inner_radius * 2.0 * clamped_ratio
	var fill_top: float = center.y + inner_radius - fill_height
	var wave_amp: float = max(3.5, inner_radius * 0.10)
	var liquid_t: float = t * LIQUID_ANIMATION_SPEED
	var wave_offset: float = sin(liquid_t * 2.3) * wave_amp * 0.5
	var lod_active: bool = quality_scale < 0.85
	# Draw the fill as a single sampled polygon. The previous vertical-column
	# fill was cheaper per sample but produced visible block stairs on large orbs.
	var surface_step: float = LIQUID_SURFACE_STEP_LOD if lod_active else LIQUID_SURFACE_STEP
	var band_step: float = LIQUID_BAND_STEP_LOD if lod_active else LIQUID_BAND_STEP
	var max_bubbles: int = 2 if lod_active else LIQUID_MAX_BUBBLES
	var max_surface_samples: int = floori(float(LIQUID_POLYGON_MAX_POINTS) * 0.5)
	var requested_surface_samples: int = max(12, int(ceil((inner_radius * 2.0) / max(0.5, surface_step))) + 1)
	var sample_count: int = mini(max_surface_samples, requested_surface_samples)
	var first_valid_sample: int = -1
	var last_valid_sample: int = -1

	for sample_idx in range(sample_count):
		var sample_t: float = float(sample_idx) / max(1.0, float(sample_count - 1))
		var local_x: float = lerpf(-inner_radius, inner_radius, sample_t)
		if _liquid_column_height(local_x, center.y, inner_radius, fill_top, wave_amp, wave_offset, liquid_t, surface_step) > 0.05:
			if first_valid_sample < 0:
				first_valid_sample = sample_idx
			last_valid_sample = sample_idx

	if first_valid_sample < 0 or last_valid_sample < first_valid_sample:
		return

	var left_invalid_x: float = -inner_radius if first_valid_sample <= 0 else lerpf(-inner_radius, inner_radius, float(first_valid_sample - 1) / max(1.0, float(sample_count - 1)))
	var left_valid_x: float = lerpf(-inner_radius, inner_radius, float(first_valid_sample) / max(1.0, float(sample_count - 1)))
	var right_valid_x: float = lerpf(-inner_radius, inner_radius, float(last_valid_sample) / max(1.0, float(sample_count - 1)))
	var right_invalid_x: float = inner_radius if last_valid_sample >= sample_count - 1 else lerpf(-inner_radius, inner_radius, float(last_valid_sample + 1) / max(1.0, float(sample_count - 1)))
	var left_edge_x: float = _find_liquid_edge_x(left_invalid_x, left_valid_x, true, center.y, inner_radius, fill_top, wave_amp, wave_offset, liquid_t, surface_step)
	var right_edge_x: float = _find_liquid_edge_x(right_valid_x, right_invalid_x, false, center.y, inner_radius, fill_top, wave_amp, wave_offset, liquid_t, surface_step)
	var edge_span: float = max(0.0, right_edge_x - left_edge_x)
	var draw_sample_count: int = mini(max_surface_samples, max(12, int(ceil(edge_span / max(0.5, surface_step))) + 1))
	var top_points := PackedVector2Array()
	var top_colors := PackedColorArray()
	var surface_points := PackedVector2Array()

	for sample_idx in range(draw_sample_count):
		var sample_t: float = float(sample_idx) / max(1.0, float(draw_sample_count - 1))
		var local_x: float = lerpf(left_edge_x, right_edge_x, sample_t)
		var y_limit: float = sqrt(max(0.0, inner_radius * inner_radius - local_x * local_x))
		var circle_top: float = center.y - y_limit
		var line_bottom: float = center.y + y_limit
		var wave_y: float = _sample_smoothed_liquid_wave_top(local_x, inner_radius, fill_top, wave_amp, wave_offset, liquid_t, surface_step)
		var line_top: float = clamp(max(circle_top, wave_y), circle_top, line_bottom)
		if sample_idx == 0 or sample_idx == draw_sample_count - 1:
			line_top = line_bottom
		var gradient_t: float = clamp((line_top - (center.y - inner_radius)) / max(1.0, inner_radius * 2.0), 0.0, 1.0)
		top_points.append(Vector2(center.x + local_x, line_top))
		top_colors.append(top_color.lerp(bottom_color, gradient_t))
		if sample_idx > 0 and sample_idx < draw_sample_count - 1 and line_bottom - line_top > LIQUID_SURFACE_GLOW_MIN_HEIGHT:
			surface_points.append(Vector2(center.x + local_x, line_top))

	if top_points.size() < 2:
		return

	var fill_points := PackedVector2Array()
	var fill_colors := PackedColorArray()
	for idx in range(top_points.size()):
		fill_points.append(top_points[idx])
		fill_colors.append(top_colors[idx])
	var right_edge: Vector2 = top_points[top_points.size() - 1]
	var left_edge: Vector2 = top_points[0]
	var right_angle: float = atan2(right_edge.y - center.y, right_edge.x - center.x)
	var left_angle: float = atan2(left_edge.y - center.y, left_edge.x - center.x)
	while left_angle <= right_angle:
		left_angle += TAU
	var arc_span: float = left_angle - right_angle
	var remaining_point_budget: int = max(6, LIQUID_POLYGON_MAX_POINTS - fill_points.size())
	var arc_sample_count: int = mini(remaining_point_budget, max(8, int(ceil((arc_span * inner_radius) / max(1.0, surface_step))) + 1))
	for arc_idx in range(1, arc_sample_count - 1):
		var arc_t: float = float(arc_idx) / max(1.0, float(arc_sample_count - 1))
		var angle: float = lerpf(right_angle, left_angle, arc_t)
		fill_points.append(center + Vector2(cos(angle), sin(angle)) * inner_radius)
		fill_colors.append(bottom_color)
	canvas.draw_polygon(fill_points, fill_colors)
	if surface_points.size() > 1:
		canvas.draw_polyline(surface_points, Color(wave_glow.r, wave_glow.g, wave_glow.b, 0.22), LIQUID_WAVE_GLOW_WIDTH * 3.0, true)
		canvas.draw_polyline(surface_points, Color(wave_glow.r, wave_glow.g, wave_glow.b, 0.58), LIQUID_WAVE_GLOW_WIDTH, true)

	for band_idx in range(2):
		var band_ratio: float = 0.28 + float(band_idx) * 0.28
		var band_center_y: float = center.y + inner_radius - fill_height * band_ratio + sin(liquid_t * (2.6 + float(band_idx) * 0.8) + float(band_idx)) * (wave_amp * 1.0)
		var band_points := PackedVector2Array()
		var band_sample_count: int = max(8, int(ceil((inner_radius * 2.0) / max(1.0, band_step))) + 1)
		for sample_idx in range(band_sample_count):
			var sample_t: float = float(sample_idx) / max(1.0, float(band_sample_count - 1))
			var local_x: float = lerpf(-inner_radius + 4.0, inner_radius - 4.0, sample_t)
			var y_limit: float = sqrt(max(0.0, inner_radius * inner_radius - local_x * local_x))
			var band_dx_ratio: float = abs(local_x) / max(1.0, inner_radius)
			var line_y: float = clamp(band_center_y + sin(local_x * 0.09 + liquid_t * 2.0 + float(band_idx) * 0.6), center.y - y_limit, center.y + y_limit)
			if line_y > fill_top + 3.0 and line_y < center.y + y_limit - 2.0:
				band_points.append(Vector2(center.x + local_x, line_y))
			elif band_points.size() > 1:
				var band_alpha: float = 0.06 + (1.0 - band_dx_ratio) * 0.08 * clamped_ratio
				canvas.draw_polyline(band_points, Color(wave_glow.r, wave_glow.g, wave_glow.b, band_alpha), 1.5, true)
				band_points.clear()
		if band_points.size() > 1:
			canvas.draw_polyline(band_points, Color(wave_glow.r, wave_glow.g, wave_glow.b, 0.08 + 0.06 * clamped_ratio), 1.5, true)

	var bubble_count: int = mini(max_bubbles, int(round(2.0 + clamped_ratio * 3.0)))
	for i in range(bubble_count):
		var phase: float = liquid_t * 1.4 + float(i) * 1.26
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


func _is_stable_full_fill_ratio(fill_ratio: float) -> bool:
	return fill_ratio >= LIQUID_STABLE_FULL_THRESHOLD


func _draw_stable_full_liquid(canvas: CanvasItem, center: Vector2, radius: float, top_color: Color, bottom_color: Color) -> void:
	var fill_points := PackedVector2Array()
	var fill_colors := PackedColorArray()
	for idx in range(LIQUID_STABLE_FULL_SEGMENTS):
		var angle: float = -PI * 0.5 + TAU * float(idx) / float(LIQUID_STABLE_FULL_SEGMENTS)
		var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
		var gradient_t: float = clamp((point.y - (center.y - radius)) / max(1.0, radius * 2.0), 0.0, 1.0)
		fill_points.append(point)
		fill_colors.append(top_color.lerp(bottom_color, gradient_t))
	canvas.draw_polygon(fill_points, fill_colors)


func _draw_fast_lod_liquid(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	fill_ratio: float,
	top_color: Color,
	bottom_color: Color,
	wave_glow: Color
) -> void:
	var fill_top: float = center.y + radius - radius * 2.0 * fill_ratio
	var local_y: float = clamp(fill_top - center.y, -radius, radius)
	var half_width: float = sqrt(max(0.0, radius * radius - local_y * local_y))
	if half_width <= 0.5:
		return
	var right_angle: float = atan2(local_y, half_width)
	var left_angle: float = atan2(local_y, -half_width)
	while left_angle <= right_angle:
		left_angle += TAU

	var fill_points := PackedVector2Array()
	var fill_colors := PackedColorArray()
	var top_left := Vector2(center.x - half_width, center.y + local_y)
	var top_right := Vector2(center.x + half_width, center.y + local_y)
	var top_gradient: float = clamp((top_left.y - (center.y - radius)) / max(1.0, radius * 2.0), 0.0, 1.0)
	var surface_color: Color = top_color.lerp(bottom_color, top_gradient)
	fill_points.append(top_left)
	fill_colors.append(surface_color)
	fill_points.append(top_right)
	fill_colors.append(surface_color)

	var segment_count: int = max(8, int(ceil((left_angle - right_angle) / TAU * float(LIQUID_FAST_SEGMENTS))))
	for idx in range(1, segment_count):
		var angle: float = lerpf(right_angle, left_angle, float(idx) / float(segment_count))
		var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
		var gradient_t: float = clamp((point.y - (center.y - radius)) / max(1.0, radius * 2.0), 0.0, 1.0)
		fill_points.append(point)
		fill_colors.append(top_color.lerp(bottom_color, gradient_t))

	canvas.draw_polygon(fill_points, fill_colors)
	var surface_alpha: float = clamp(0.20 + 0.18 * fill_ratio, 0.0, 0.42)
	canvas.draw_line(top_left, top_right, Color(wave_glow.r, wave_glow.g, wave_glow.b, surface_alpha), 2.0, true)


func draw_dash_sector_liquid(
	canvas: CanvasItem,
	center: Vector2,
	inner_radius: float,
	start_rad: float,
	end_rad: float,
	progress: float,
	t: float,
	_scale_factor: float = 1.0,
	quality_scale: float = 1.0
) -> void:
	if canvas == null:
		return
	var charge_radius: float = inner_radius * progress
	# A near-zero charge radius collapses every sector point onto the center,
	# which fails canvas_item_add_polygon triangulation and spams error logs.
	if charge_radius <= 0.5:
		return
	var lod_active: bool = quality_scale < 0.85
	var sector_segments: int = 12 if lod_active else DASH_SECTOR_SEGMENTS
	var inner_segments: int = 7 if lod_active else DASH_INNER_SECTOR_SEGMENTS
	var pulse_arc_points: int = 8 if lod_active else DASH_PULSE_ARC_POINTS
	canvas.draw_colored_polygon(shape_helper.build_sector_points(center, charge_radius, start_rad, end_rad, sector_segments), Color(0.76, 0.26, 0.22, 0.92))
	if progress > 0.15:
		canvas.draw_colored_polygon(shape_helper.build_sector_points(center, charge_radius * 0.72, start_rad, end_rad, inner_segments), Color(1.0, 0.58, 0.44, 0.16 + 0.12 * progress))
	var pulse_r: float = charge_radius * (0.85 + 0.15 * sin(t * 5.0))
	canvas.draw_arc(center, pulse_r, start_rad, end_rad, pulse_arc_points, Color(1.0, 0.72, 0.56, 0.28 + 0.18 * sin(t * 4.0)), 2.0)


func _sample_smoothed_liquid_wave_top(
	local_x: float,
	inner_radius: float,
	fill_top: float,
	wave_amp: float,
	wave_offset: float,
	t: float,
	sample_span: float
) -> float:
	var center_y: float = _sample_liquid_wave_top(local_x, inner_radius, fill_top, wave_amp, wave_offset, t)
	var left_y: float = _sample_liquid_wave_top(local_x - sample_span, inner_radius, fill_top, wave_amp, wave_offset, t)
	var right_y: float = _sample_liquid_wave_top(local_x + sample_span, inner_radius, fill_top, wave_amp, wave_offset, t)
	return (left_y + center_y * 2.0 + right_y) * 0.25


func _sample_liquid_wave_top(
	local_x: float,
	inner_radius: float,
	fill_top: float,
	wave_amp: float,
	wave_offset: float,
	t: float
) -> float:
	var edge_ratio: float = clamp(abs(local_x) / max(1.0, inner_radius), 0.0, 1.0)
	var edge_fade: float = clamp(1.0 - pow(edge_ratio, 2.2), 0.0, 1.0)
	var primary_wave: float = sin(local_x * 0.055 + t * 2.55) * wave_amp
	var secondary_wave: float = sin(local_x * 0.030 - t * 1.85 + 0.7) * wave_amp * 0.34
	var soft_ripple: float = sin(local_x * 0.095 + t * 2.2 + 1.3) * wave_amp * 0.08
	return fill_top + (primary_wave + secondary_wave + soft_ripple + wave_offset) * edge_fade


func _find_liquid_edge_x(
	valid_or_invalid_a: float,
	valid_or_invalid_b: float,
	search_left_edge: bool,
	center_y: float,
	inner_radius: float,
	fill_top: float,
	wave_amp: float,
	wave_offset: float,
	liquid_t: float,
	sample_span: float
) -> float:
	var invalid_x: float = valid_or_invalid_a if search_left_edge else valid_or_invalid_b
	var valid_x: float = valid_or_invalid_b if search_left_edge else valid_or_invalid_a
	for _step in range(LIQUID_EDGE_SEARCH_STEPS):
		var mid_x: float = (invalid_x + valid_x) * 0.5
		if _liquid_column_height(mid_x, center_y, inner_radius, fill_top, wave_amp, wave_offset, liquid_t, sample_span) > 0.05:
			valid_x = mid_x
		else:
			invalid_x = mid_x
	return valid_x


func _liquid_column_height(
	local_x: float,
	center_y: float,
	inner_radius: float,
	fill_top: float,
	wave_amp: float,
	wave_offset: float,
	liquid_t: float,
	sample_span: float
) -> float:
	var y_limit: float = sqrt(max(0.0, inner_radius * inner_radius - local_x * local_x))
	var circle_top: float = center_y - y_limit
	var line_bottom: float = center_y + y_limit
	var wave_y: float = _sample_smoothed_liquid_wave_top(local_x, inner_radius, fill_top, wave_amp, wave_offset, liquid_t, sample_span)
	var line_top: float = clamp(max(circle_top, wave_y), circle_top, line_bottom)
	return line_bottom - line_top
