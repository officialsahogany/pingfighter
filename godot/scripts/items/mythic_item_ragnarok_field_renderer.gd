extends RefCounted

const RAGNAROK_ELECTRIC_BRANCH_COUNT := 4
const RAGNAROK_ELECTRIC_SPARK_COUNT := 3
const RAGNAROK_ELECTRIC_CORE_COLORS := [
	Color(1.0, 1.0, 1.0, 1.0),
	Color(1.0, 1.0, 230.0 / 255.0, 1.0),
	Color(1.0, 250.0 / 255.0, 200.0 / 255.0, 1.0),
]
const RAGNAROK_ELECTRIC_OUTER_COLORS := [
	Color(120.0 / 255.0, 180.0 / 255.0, 1.0, 1.0),
	Color(80.0 / 255.0, 140.0 / 255.0, 1.0, 1.0),
	Color(160.0 / 255.0, 200.0 / 255.0, 1.0, 1.0),
	Color(1.0, 240.0 / 255.0, 120.0 / 255.0, 1.0),
	Color(1.0, 220.0 / 255.0, 80.0 / 255.0, 1.0),
]
const RAGNAROK_ELECTRIC_BRANCH_COLORS := [
	Color(120.0 / 255.0, 180.0 / 255.0, 1.0, 1.0),
	Color(80.0 / 255.0, 140.0 / 255.0, 1.0, 1.0),
	Color(160.0 / 255.0, 200.0 / 255.0, 1.0, 1.0),
	Color(1.0, 240.0 / 255.0, 120.0 / 255.0, 1.0),
	Color(1.0, 220.0 / 255.0, 80.0 / 255.0, 1.0),
	Color(1.0, 1.0, 1.0, 1.0),
	Color(1.0, 1.0, 230.0 / 255.0, 1.0),
	Color(1.0, 250.0 / 255.0, 200.0 / 255.0, 1.0),
]
const RAGNAROK_ELECTRIC_SPARK_COLORS := [
	Color(1.0, 1.0, 1.0, 1.0),
	Color(1.0, 1.0, 200.0 / 255.0, 1.0),
	Color(200.0 / 255.0, 230.0 / 255.0, 1.0, 1.0),
]


func draw_ragnarok_impact_rings(
	canvas: CanvasItem,
	center: Vector2,
	elapsed: float,
	impact_effect_duration: float,
	impact_ring_segments: int
) -> void:
	if canvas == null:
		return
	var t: float = clamp(elapsed / impact_effect_duration, 0.0, 1.0)
	var alpha: float = 1.0 - t
	for i in range(3):
		var local_t: float = clamp(t - float(i) * 0.12, 0.0, 1.0)
		var radius: float = 34.0 + 112.0 * local_t + float(i) * 16.0
		var color := Color(120.0 / 255.0, 210.0 / 255.0, 1.0, alpha * (0.58 - float(i) * 0.12))
		canvas.draw_arc(center, radius, 0.0, TAU, impact_ring_segments, color, max(1.0, 5.0 * (1.0 - local_t)))
	var flash_alpha: float = 0.34 * alpha
	canvas.draw_circle(center, 62.0 + 18.0 * t, Color(150.0 / 255.0, 220.0 / 255.0, 1.0, flash_alpha))


func draw_ragnarok_stun_aura(
	canvas: CanvasItem,
	center: Vector2,
	aura_segments: int,
	aura_outer_segments: int
) -> void:
	if canvas == null:
		return
	var now: float = float(Time.get_ticks_msec())
	var pulse: float = 0.5 + 0.5 * sin(now * 0.012)
	canvas.draw_arc(center, 48.0 + pulse * 6.0, 0.0, TAU, aura_segments, Color(110.0 / 255.0, 210.0 / 255.0, 1.0, 0.46), 2.0)
	canvas.draw_arc(center, 72.0 + pulse * 8.0, 0.0, TAU, aura_outer_segments, Color(1.0, 235.0 / 255.0, 150.0 / 255.0, 0.30), 1.5)
	for i in range(5):
		var angle: float = now * 0.006 + float(i) * TAU / 5.0
		var start: Vector2 = center + Vector2(cos(angle), sin(angle)) * (34.0 + pulse * 5.0)
		var end: Vector2 = center + Vector2(cos(angle + 0.42), sin(angle + 0.42)) * (70.0 + pulse * 8.0)
		canvas.draw_line(start, end, Color(215.0 / 255.0, 245.0 / 255.0, 1.0, 0.62), 1.6)


func draw_ragnarok_electric_stun_overlay(
	canvas: CanvasItem,
	center: Vector2,
	target_size: Vector2,
	intensity: float,
	ellipse_segments: int
) -> void:
	if canvas == null:
		return
	var safe_intensity: float = max(0.25, intensity)
	var now_msec: int = Time.get_ticks_msec()
	var time_sec: float = float(now_msec) * 0.001
	var tick: int = int(float(now_msec) / 70.0)
	var electric_center: Vector2 = center + Vector2(0.0, 20.0 * safe_intensity)
	var half_width: float = max(10.0, (target_size.x * 0.5 + 5.0) * safe_intensity)
	var half_height: float = max(18.0, 28.0 * safe_intensity)

	var glow_w: float = half_width * 2.0 + 28.0
	var glow_h: float = half_height * 2.0 + 24.0
	for ring in range(3, 0, -1):
		var ring_alpha: float = (24.0 + float(ring) * 10.0) * safe_intensity / 255.0
		var rx: float = (glow_w - float(ring) * 6.0) * 0.5
		var ry: float = (glow_h - float(ring) * 4.0) * 0.5
		if rx <= 0.0 or ry <= 0.0:
			continue
		var glow_points: PackedVector2Array = make_ragnarok_ellipse_points(electric_center, rx, ry, ellipse_segments)
		canvas.draw_polyline(glow_points, Color(160.0 / 255.0, 210.0 / 255.0, 1.0, ring_alpha), max(1.0, 2.0 * safe_intensity), true)

	var main_arc_count: int = max(1, int(round(1.0 * safe_intensity)))
	for _arc_idx in range(main_arc_count):
		var arc_seed: int = tick + _arc_idx * 31
		var sx: float = electric_center.x + _ragnarok_range(arc_seed, time_sec, -half_width / 3.0, half_width / 3.0)
		var sy: float = electric_center.y + _ragnarok_range(arc_seed + 3, time_sec, -half_height / 2.0, half_height / 2.0)
		var arc_len: float = _ragnarok_range(arc_seed + 7, time_sec, 12.0 * safe_intensity, 24.0 * safe_intensity)
		var arc_angle: float = _ragnarok_unit(arc_seed + 11, time_sec) * TAU
		var ex: float = sx + cos(arc_angle) * arc_len
		var ey: float = sy + sin(arc_angle) * arc_len

		var segs: int = 3 + int(_ragnarok_unit(arc_seed + 13, time_sec) > 0.55)
		var pts := PackedVector2Array()
		pts.append(Vector2(sx, sy))
		for j in range(1, segs):
			var frac: float = float(j) / float(segs)
			var mx: float = sx + (ex - sx) * frac + _ragnarok_range(arc_seed + j * 17, time_sec, -2.5, 2.5) * safe_intensity
			var my: float = sy + (ey - sy) * frac + _ragnarok_range(arc_seed + j * 19, time_sec, -2.0, 2.0) * safe_intensity
			pts.append(Vector2(mx, my))
		pts.append(Vector2(ex, ey))

		canvas.draw_polyline(pts, _array_color(RAGNAROK_ELECTRIC_OUTER_COLORS, Color(100.0 / 255.0, 200.0 / 255.0, 1.0)), max(1.0, 2.0 * safe_intensity), true)
		canvas.draw_polyline(pts, _array_color(RAGNAROK_ELECTRIC_CORE_COLORS, Color(225.0 / 255.0, 245.0 / 255.0, 1.0)), 1.0, true)

	var branch_count: int = max(2, int(round(float(RAGNAROK_ELECTRIC_BRANCH_COUNT) * safe_intensity)))
	for _branch_idx in range(branch_count):
		var branch_seed: int = tick + _branch_idx * 43
		var bx: float = electric_center.x + _ragnarok_range(branch_seed, time_sec, -half_width, half_width)
		var by: float = electric_center.y + _ragnarok_range(branch_seed + 5, time_sec, -half_height, half_height)
		var b_angle: float = _ragnarok_unit(branch_seed + 9, time_sec) * TAU
		var b_len: float = _ragnarok_range(branch_seed + 15, time_sec, 8.0, 18.0) * safe_intensity
		var branch_pts := PackedVector2Array()
		branch_pts.append(Vector2(bx, by))
		var b_segs: int = 2 + int(floor(_ragnarok_unit(branch_seed + 21, time_sec) * 2.99))
		for j in range(1, b_segs + 1):
			var frac_b: float = float(j) / float(b_segs)
			var nx: float = bx + cos(b_angle) * b_len * frac_b + _ragnarok_range(branch_seed + j * 23, time_sec, -4.0, 4.0) * safe_intensity
			var ny: float = by + sin(b_angle) * b_len * frac_b + _ragnarok_range(branch_seed + j * 29, time_sec, -4.0, 4.0) * safe_intensity
			branch_pts.append(Vector2(nx, ny))
		canvas.draw_polyline(branch_pts, _array_color(RAGNAROK_ELECTRIC_BRANCH_COLORS, Color(120.0 / 255.0, 220.0 / 255.0, 1.0)), 1.0, true)

	var spark_count: int = max(2, int(round(float(RAGNAROK_ELECTRIC_SPARK_COUNT) * safe_intensity)))
	for _spark_idx in range(spark_count):
		var spark_seed: int = tick + _spark_idx * 37
		var sp_x: float = electric_center.x + _ragnarok_range(spark_seed, time_sec, -half_width, half_width)
		var sp_y: float = electric_center.y + _ragnarok_range(spark_seed + 7, time_sec, -half_height, half_height)
		var sp_size: float = 1.0 + floor(_ragnarok_unit(spark_seed + 13, time_sec) * max(1.0, 2.0 * safe_intensity))
		canvas.draw_circle(Vector2(sp_x, sp_y), sp_size, _array_color(RAGNAROK_ELECTRIC_SPARK_COLORS, Color(1.0, 245.0 / 255.0, 190.0 / 255.0)))


func _ragnarok_unit(sample_seed: int, time_sec: float) -> float:
	return 0.5 + 0.5 * sin(float(sample_seed) * 12.9898 + time_sec * 9.37)


func _ragnarok_range(sample_seed: int, time_sec: float, low: float, high: float) -> float:
	return lerp(low, high, _ragnarok_unit(sample_seed, time_sec))


func make_ragnarok_ellipse_points(center: Vector2, radius_x: float, radius_y: float, segments: int) -> PackedVector2Array:
	var count: int = max(12, segments)
	var points := PackedVector2Array()
	for idx in range(count + 1):
		var angle: float = TAU * float(idx) / float(count)
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points


func draw_ragnarok_sparks(
	canvas: CanvasItem,
	center: Vector2,
	sparks: Array,
	spark_render_limit: int,
	alpha_cutoff: float
) -> void:
	if canvas == null:
		return
	for spark_index in range(_recent_start(sparks, spark_render_limit), sparks.size()):
		var spark: Dictionary = _as_dict(sparks[spark_index])
		var life: float = float(spark.get("life", 0.0))
		var max_life: float = max(0.01, float(spark.get("max_life", 1.0)))
		var alpha: float = clamp(life / max_life, 0.0, 1.0)
		if alpha <= alpha_cutoff:
			continue
		var angle: float = float(spark.get("angle", 0.0))
		var radius: float = float(spark.get("radius", 0.0))
		var direction := Vector2(cos(angle), sin(angle))
		var pos: Vector2 = center + direction * radius
		var tail: Vector2 = center + direction * max(8.0, radius - 18.0)
		var width: float = float(spark.get("width", 1.0))
		canvas.draw_line(tail, pos, Color(70.0 / 255.0, 165.0 / 255.0, 1.0, 0.28 * alpha), width + 3.0)
		canvas.draw_line(tail, pos, Color(225.0 / 255.0, 245.0 / 255.0, 1.0, 0.84 * alpha), width)
		canvas.draw_circle(pos, width + 1.2, Color(1.0, 245.0 / 255.0, 190.0 / 255.0, 0.72 * alpha))


func _as_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _as_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback


func _array_color(values: Array, fallback: Color) -> Color:
	if values.is_empty():
		return fallback
	return _as_color(values[randi() % values.size()], fallback)


func _recent_start(source: Array, render_limit: int) -> int:
	if render_limit < 0:
		return 0
	return max(0, source.size() - max(0, render_limit))
