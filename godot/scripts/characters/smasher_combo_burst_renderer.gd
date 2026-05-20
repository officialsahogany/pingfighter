extends RefCounted

const SmasherComboBurstAccentRenderer := preload("res://scripts/characters/smasher_combo_burst_accent_renderer.gd")
const SmasherComboBurstTextRenderer := preload("res://scripts/characters/smasher_combo_burst_text_renderer.gd")

var accent_renderer: Object = SmasherComboBurstAccentRenderer.new()
var text_renderer: Object = SmasherComboBurstTextRenderer.new()


func draw(
	canvas: CanvasItem,
	combo_state,
	shake_offset: Vector2,
	effect_count: int,
	effect_timer_frames: float
) -> void:
	if canvas == null or combo_state == null:
		return
	if not combo_state.is_effect_active():
		return

	var combo: int = max(0, effect_count)
	if combo < combo_state.get_min_skill_count():
		return
	var effect_duration: float = max(1.0, combo_state.get_effect_duration_frames())
	var effect_pos: Vector2 = combo_state.get_effect_pos() + shake_offset
	var progress: float = 1.0 - clamp(effect_timer_frames / effect_duration, 0.0, 1.0)
	var base_color: Color = combo_state.get_combo_color(combo)
	var alpha: float = 1.0
	if progress > 0.70:
		alpha = clamp(1.0 - (progress - 0.70) / 0.30, 0.0, 1.0)

	var scale: float = 1.0
	if progress < 0.20:
		scale = 1.0 + (1.0 - progress / 0.20) * 0.50

	var shake_intensity: float = float(min(combo - 1, 5)) * 2.0 if effect_timer_frames > 30.0 else 0.0
	var jitter: Vector2 = Vector2.ZERO
	if shake_intensity > 0.0:
		jitter = Vector2(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity))
	var draw_center: Vector2 = effect_pos + jitter

	_draw_starburst_body(canvas, draw_center, combo, progress, scale, base_color, alpha)
	accent_renderer.draw(canvas, draw_center, combo, progress, effect_timer_frames, base_color, alpha)
	text_renderer.draw(canvas, draw_center, combo, progress, scale, base_color, alpha)


func _draw_starburst_body(
	canvas: CanvasItem,
	draw_center: Vector2,
	combo: int,
	progress: float,
	scale: float,
	base_color: Color,
	alpha: float
) -> void:
	var burst_points: int = min(20, 10 + combo * 2)
	var burst_outer: float = (42.0 + float(combo) * 7.0) * scale
	var burst_inner: float = (24.0 + float(combo) * 3.0) * scale
	var burst_rotation: float = -PI * 0.5 + progress * 1.6
	var burst_polygon: PackedVector2Array = _build_starburst(draw_center, burst_inner, burst_outer, burst_points, burst_rotation, true)
	canvas.draw_colored_polygon(
		burst_polygon,
		Color(base_color.r, base_color.g, base_color.b, (0.18 + min(0.10, float(combo) * 0.012)) * alpha)
	)
	_draw_polyline(canvas, burst_polygon, Color(0.0, 0.0, 0.0, 0.40 * alpha), max(2.0, 2.0 + floor(float(combo) * 0.22)))
	_draw_polyline(canvas, burst_polygon, Color(1.0, 1.0, 0.86, 0.62 * alpha), max(1.0, 1.0 + floor(float(combo) * 0.12)))
	if combo < 7:
		return
	var inner_burst: PackedVector2Array = _build_starburst(
		draw_center,
		burst_inner * 0.48,
		burst_outer * 0.70,
		max(10, burst_points - 4),
		burst_rotation + PI / float(max(6, burst_points)),
		true
	)
	canvas.draw_colored_polygon(inner_burst, Color(1.0, 1.0, 1.0, 0.16 * alpha))
	_draw_polyline(canvas, inner_burst, Color(1.0, 0.95, 0.66, 0.42 * alpha), 1.5)

func _build_starburst(
	center: Vector2,
	inner_radius: float,
	outer_radius: float,
	point_count: int,
	rotation: float,
	closed: bool = false
) -> PackedVector2Array:
	var safe_points: int = point_count
	if safe_points < 3:
		safe_points = 3
	var points := PackedVector2Array()
	var total_vertices: int = safe_points * 2
	for point_idx in range(total_vertices):
		var radius: float = outer_radius if point_idx % 2 == 0 else inner_radius
		var angle: float = rotation + (float(point_idx) / float(total_vertices)) * TAU
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	if closed and points.size() > 0:
		points.append(points[0])
	return points


func _draw_polyline(canvas: CanvasItem, points: PackedVector2Array, color: Color, width: float) -> void:
	if points.size() < 2:
		return
	canvas.draw_polyline(points, color, width)
