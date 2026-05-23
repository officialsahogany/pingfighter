extends RefCounted

const FIELD_CENTER := Vector2(380.0, 375.0)
const DARK_CORE := Color(20.0 / 255.0, 20.0 / 255.0, 25.0 / 255.0)
const ORANGE := Color(1.0, 120.0 / 255.0, 0.0)
const GOLD := Color(1.0, 210.0 / 255.0, 90.0 / 255.0)
const GATHER_FRAMES := 60.0
const BURST_FRAMES := 30.0


func draw_revival_event(canvas: CanvasItem, state: Object, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null or state == null or not state.is_event_playing():
		return
	var context: Dictionary = state.get_context()
	var center: Vector2 = context.get("revival_anchor", FIELD_CENTER)
	if center == Vector2.ZERO:
		center = FIELD_CENTER
	center += shake_offset
	var timer: float = float(context.get("animation_timer_frames", 0.0))
	if timer < GATHER_FRAMES:
		_draw_gather(canvas, center, timer / GATHER_FRAMES)
	else:
		_draw_burst(canvas, center, (timer - GATHER_FRAMES) / BURST_FRAMES)


func _draw_gather(canvas: CanvasItem, center: Vector2, progress: float) -> void:
	var t: float = clampf(progress, 0.0, 1.0)
	var radius: float = 10.0 + t * 35.0
	canvas.draw_circle(center, radius, _with_alpha(DARK_CORE, 0.38 + t * 0.42))
	canvas.draw_circle(center, radius + 2.0, _with_alpha(ORANGE, 0.18 + t * 0.24), false, 2.0)
	for i in range(8):
		var angle: float = deg_to_rad(float(i) * 45.0 + t * 360.0 * 1.2)
		var start_dist: float = (1.0 - t) * 120.0 + 20.0
		var start_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * start_dist
		var end_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius * 0.55
		canvas.draw_line(start_pos, end_pos, _with_alpha(ORANGE, 0.56 + t * 0.30), 2.0)


func _draw_burst(canvas: CanvasItem, center: Vector2, progress: float) -> void:
	var t: float = clampf(progress, 0.0, 1.0)
	var ring_radius: float = 20.0 + t * 80.0
	canvas.draw_circle(center, ring_radius, _with_alpha(ORANGE, 1.0 - t), false, 3.0)
	var flash_radius: float = max(0.0, 30.0 + t * 20.0)
	canvas.draw_circle(center, flash_radius, _with_alpha(GOLD, max(0.0, 0.72 * (1.0 - t))))
	for i in range(28):
		var seed_angle: float = float(i) * TAU / 28.0 + sin(float(i) * 13.37) * 0.18
		var speed: float = 20.0 + float(i % 7) * 7.0
		var particle_t: float = min(1.0, t * 1.22)
		var pos: Vector2 = center + Vector2(cos(seed_angle), sin(seed_angle)) * speed * particle_t
		pos.y += 24.0 * particle_t * particle_t
		var size: float = 2.0 + float(i % 4)
		var color: Color = GOLD if i % 3 == 0 else ORANGE
		canvas.draw_circle(pos, size, _with_alpha(color, max(0.0, 1.0 - t)))


func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0))
