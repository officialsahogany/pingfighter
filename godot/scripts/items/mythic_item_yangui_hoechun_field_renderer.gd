extends RefCounted

const SEGMENTS := 18
const TRAIL_COUNT := 3


func draw_effect(canvas: CanvasItem, shake_offset: Vector2, context: Dictionary) -> void:
	if canvas == null or not bool(context.get("visible", false)):
		return
	var origin: Vector2 = _as_vector2(context.get("origin", Vector2.ZERO)) + shake_offset
	var alpha := clampf(float(context.get("alpha", 0.0)), 0.0, 1.0)
	var phase := float(context.get("phase", 0.0))
	var half_height := maxf(1.0, float(context.get("half_height", 92.0)))
	if bool(context.get("wave_active", false)) and alpha > 0.001:
		_draw_wave_pair(
			canvas,
			origin,
			float(context.get("left_front_x", origin.x)),
			float(context.get("right_front_x", origin.x)),
			half_height,
			phase,
			alpha
		)
		_draw_activation_breath(canvas, origin, float(context.get("progress", 0.0)), alpha)
	var hit_ratio := clampf(float(context.get("hit_flash_ratio", 0.0)), 0.0, 1.0)
	if hit_ratio > 0.001:
		_draw_hit_flash(canvas, _as_vector2(context.get("hit_position", origin)) + shake_offset, hit_ratio, phase)


func _draw_wave_pair(
	canvas: CanvasItem,
	origin: Vector2,
	left_front_x: float,
	right_front_x: float,
	half_height: float,
	phase: float,
	alpha: float
) -> void:
	for side in [-1, 1]:
		var front_x := left_front_x if side < 0 else right_front_x
		for trail_index in range(TRAIL_COUNT - 1, -1, -1):
			var trail_ratio := float(trail_index) / float(maxi(1, TRAIL_COUNT - 1))
			var trail_x := front_x - float(side) * float(trail_index) * 13.0
			var trail_alpha := alpha * lerpf(0.18, 0.54, 1.0 - trail_ratio)
			var points := _build_crescent_points(
				trail_x,
				origin.y - half_height * 0.42,
				half_height * (1.0 - trail_ratio * 0.12),
				side,
				phase + float(trail_index) * 0.65
			)
			canvas.draw_polyline(points, Color(1.0, 0.77, 0.12, trail_alpha), 8.0 - trail_ratio * 3.0, true)
			canvas.draw_polyline(points, Color(1.0, 0.96, 0.58, trail_alpha * 1.25), 2.2, true)
		_draw_motes(canvas, Vector2(front_x, origin.y - half_height * 0.42), half_height, side, phase, alpha)


func _build_crescent_points(front_x: float, center_y: float, half_height: float, side: int, phase: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for segment in range(SEGMENTS + 1):
		var ratio := float(segment) / float(SEGMENTS)
		var vertical := lerpf(-half_height, half_height, ratio)
		var bulge := sin(ratio * PI) * 26.0
		var ripple := sin(ratio * PI * 3.0 + phase) * 2.8 * sin(ratio * PI)
		points.append(Vector2(front_x + float(side) * (bulge + ripple), center_y + vertical))
	return points


func _draw_motes(canvas: CanvasItem, center: Vector2, half_height: float, side: int, phase: float, alpha: float) -> void:
	for mote_index in range(5):
		var mote_phase := phase * 0.8 + float(mote_index) * 1.73
		var y_ratio := fmod(float(mote_index) * 0.23 + phase * 0.06, 1.0)
		var mote_pos := Vector2(
			center.x - float(side) * (8.0 + float(mote_index % 3) * 8.0) + sin(mote_phase) * 3.0,
			center.y + lerpf(-half_height, half_height, y_ratio)
		)
		var radius := 1.6 + float(mote_index % 2) * 1.1
		canvas.draw_circle(mote_pos, radius * 2.1, Color(1.0, 0.73, 0.08, alpha * 0.16))
		canvas.draw_circle(mote_pos, radius, Color(1.0, 0.98, 0.62, alpha * 0.82))


func _draw_activation_breath(canvas: CanvasItem, origin: Vector2, progress: float, alpha: float) -> void:
	var breath_ratio := clampf((0.28 - progress) / 0.28, 0.0, 1.0)
	if breath_ratio <= 0.001:
		return
	var radius := lerpf(22.0, 84.0, 1.0 - breath_ratio)
	canvas.draw_arc(origin - Vector2(0.0, 18.0), radius, PI * 0.08, PI * 0.92, 28, Color(1.0, 0.72, 0.10, alpha * breath_ratio * 0.35), 7.0, true)
	canvas.draw_arc(origin - Vector2(0.0, 18.0), radius, PI * 0.08, PI * 0.92, 28, Color(1.0, 1.0, 0.68, alpha * breath_ratio * 0.78), 2.0, true)


func _draw_hit_flash(canvas: CanvasItem, position: Vector2, ratio: float, phase: float) -> void:
	var expand := 1.0 - ratio
	canvas.draw_circle(position, 12.0 + expand * 25.0, Color(1.0, 0.76, 0.08, ratio * 0.18))
	canvas.draw_arc(position, 11.0 + expand * 28.0, phase, phase + TAU * 0.86, 24, Color(1.0, 0.94, 0.42, ratio * 0.88), 4.0, true)
	for ray_index in range(8):
		var angle := phase + TAU * float(ray_index) / 8.0
		var direction := Vector2.from_angle(angle)
		canvas.draw_line(position + direction * 8.0, position + direction * (18.0 + expand * 20.0), Color(1.0, 1.0, 0.72, ratio * 0.72), 2.0, true)


func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO
