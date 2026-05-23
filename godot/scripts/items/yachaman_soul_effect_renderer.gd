extends RefCounted

const FIELD_CENTER := Vector2(380.0, 375.0)
const DARK_CORE := Color(20.0 / 255.0, 20.0 / 255.0, 25.0 / 255.0)
const ORANGE := Color(1.0, 120.0 / 255.0, 0.0)
const GOLD := Color(1.0, 210.0 / 255.0, 90.0 / 255.0)
const GATHER_FRAMES := 60.0
const BURST_FRAMES := 30.0
const HELMET_DARK := Color(25.0 / 255.0, 25.0 / 255.0, 30.0 / 255.0)
const HELMET_HIGHLIGHT := Color(45.0 / 255.0, 45.0 / 255.0, 50.0 / 255.0)
const HELMET_RIM := Color(15.0 / 255.0, 15.0 / 255.0, 18.0 / 255.0)


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


func draw_bomb_kit(canvas: CanvasItem, state: Object, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null or state == null:
		return
	var context: Dictionary = state.get_context()
	_draw_bomb_explosion(canvas, context, shake_offset)
	_draw_helmet_return(canvas, context, shake_offset)
	_draw_bomb_spin(canvas, context, shake_offset)


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


func _draw_bomb_spin(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	if not bool(context.get("bomb_spin_active", false)):
		return
	var center: Vector2 = context.get("bomb_spin_helmet_pos", Vector2.ZERO) + shake_offset
	if center == shake_offset:
		return
	var radius: float = float(context.get("bomb_spin_helmet_radius", 14.0))
	var angle: float = float(context.get("bomb_spin_angle", 0.0))
	var phase: int = int(context.get("bomb_spin_phase", 0))
	var direction: float = float(context.get("bomb_spin_direction", 1))
	if phase == 1 or phase == 2:
		var spin_center_y: float = center.y + cos(angle) * (20.0 if phase == 1 else 22.0)
		for i in range(3):
			var trail_angle: float = angle - float(i + 1) * 0.5
			var orbit_rx := 35.0 if phase == 1 else 40.0
			var orbit_ry := 20.0 if phase == 1 else 22.0
			var forward := 0.0 if phase == 1 else direction * 22.0
			var trail_center := Vector2(
				center.x - sin(angle) * orbit_rx + forward + sin(trail_angle) * orbit_rx,
				spin_center_y - cos(trail_angle) * orbit_ry
			)
			_draw_spin_helmet(canvas, trail_center, radius, trail_angle, 0.45 - float(i) * 0.10, false)
		canvas.draw_circle(center, radius + 6.0, _with_alpha(ORANGE, 0.16), false, 3.0)
	_draw_spin_helmet(canvas, center, radius, angle if phase == 1 or phase == 2 else 0.0, 1.0, true)
	if phase == 2:
		for i in range(5):
			var y: float = center.y - 8.0 + float(i) * 4.0
			var start := Vector2(center.x - direction * (20.0 + float(i) * 3.0), y)
			var end := start - Vector2(direction * (12.0 + float(i) * 2.0), 0.0)
			canvas.draw_line(start, end, _with_alpha(GOLD, 0.50 - float(i) * 0.075), 1.0, true)


func _draw_bomb_explosion(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	if not bool(context.get("bomb_explosion_active", false)):
		return
	var center: Vector2 = context.get("bomb_explosion_pos", Vector2.ZERO) + shake_offset
	var timer: float = float(context.get("bomb_explosion_timer", 0.0))
	var total: float = max(1.0, float(context.get("bomb_explosion_total_frames", 30.0)))
	var progress: float = clampf(timer / total, 0.0, 1.0)
	var ring_radius: float = 15.0 + progress * 60.0
	canvas.draw_circle(center, ring_radius, _with_alpha(ORANGE, 1.0 - progress), false, 3.0)
	if progress < 0.3:
		var flash_t: float = 1.0 - progress / 0.3
		canvas.draw_circle(center, 25.0 * flash_t, _with_alpha(Color(1.0, 1.0, 200.0 / 255.0), 0.78 * flash_t))
	for particle_value in context.get("bomb_explosion_particles", []):
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		var pos: Vector2 = particle.get("pos", center) + shake_offset
		var life: float = float(particle.get("life", 0.0))
		var max_life: float = max(1.0, float(particle.get("max_life", 30.0)))
		var size: float = max(1.0, float(particle.get("size", 3.0)))
		var color: Color = particle.get("color", GOLD)
		canvas.draw_circle(pos, size * 0.5, _with_alpha(color, clampf(life / max_life, 0.0, 1.0)))


func _draw_helmet_return(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	if not bool(context.get("helmet_returning", false)):
		return
	var center: Vector2 = context.get("helmet_return_pos", Vector2.ZERO) + shake_offset
	var start: Vector2 = context.get("helmet_return_start", center) + shake_offset
	var radius: float = float(context.get("bomb_spin_helmet_radius", 14.0))
	var timer: float = float(context.get("helmet_return_timer", 0.0))
	var total: float = max(1.0, float(context.get("helmet_return_total_frames", 30.0)))
	var progress: float = clampf(timer / total, 0.0, 1.0)
	for i in range(3):
		var back_t: float = max(0.0, progress - float(i + 1) * 0.08) / max(0.01, progress)
		var trail_center: Vector2 = start.lerp(center, back_t)
		_draw_spin_helmet(canvas, trail_center, radius - float(i), 0.0, max(0.16, 0.42 - float(i) * 0.10), false)
	_draw_spin_helmet(canvas, center, radius, 0.0, 1.0, true)


func _draw_spin_helmet(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	spin_angle: float,
	alpha: float,
	draw_flame: bool
) -> void:
	var flip_strength: float = abs(cos(spin_angle * 1.7))
	var shell_h: float = max(8.0, radius * 2.0 * (0.45 + flip_strength * 0.55))
	_draw_ellipse(canvas, center, Vector2(radius, shell_h * 0.5), _with_alpha(HELMET_DARK, alpha), 24)
	_draw_ellipse(canvas, center + Vector2(-2.0, -3.0), Vector2(radius * 0.60, shell_h * 0.28), _with_alpha(HELMET_HIGHLIGHT, min(alpha, 0.64)), 18)
	if shell_h >= radius + 8.0:
		_draw_ellipse(canvas, center + Vector2(0.0, 1.0), Vector2(radius * 0.52, shell_h * 0.10), _with_alpha(Color(60.0 / 255.0, 60.0 / 255.0, 68.0 / 255.0), min(alpha, 0.56)), 14)
	if draw_flame:
		var fuse_base := center + Vector2(0.0, -shell_h * 0.5 + 3.0)
		var fuse_tip := center + Vector2(3.0, -shell_h * 0.5 - 7.0 + sin(spin_angle * 2.5) * 2.0)
		canvas.draw_line(fuse_base, fuse_tip, _with_alpha(Color(90.0 / 255.0, 80.0 / 255.0, 70.0 / 255.0), alpha), 2.0, true)
		var wobble: float = sin(spin_angle * 3.1) * 2.0
		canvas.draw_circle(fuse_tip + Vector2(wobble, -1.0), 4.0, _with_alpha(Color(1.0, 220.0 / 255.0, 80.0 / 255.0), min(alpha, 0.92)))
		canvas.draw_circle(fuse_tip + Vector2(wobble, -2.0), 2.4, _with_alpha(Color(1.0, 120.0 / 255.0, 0.0), alpha))
	_draw_ellipse(canvas, center, Vector2(radius, shell_h * 0.5), _with_alpha(HELMET_RIM, alpha), 24, false, 1.0)


func _draw_ellipse(
	canvas: CanvasItem,
	center: Vector2,
	radius: Vector2,
	color: Color,
	segments: int = 20,
	filled: bool = true,
	width: float = 1.0
) -> void:
	if radius.x <= 0.0 or radius.y <= 0.0 or color.a <= 0.001:
		return
	var points := PackedVector2Array()
	var count: int = max(8, segments)
	for i in range(count):
		var angle: float = TAU * float(i) / float(count)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	if filled:
		canvas.draw_polygon(points, PackedColorArray([color]))
	else:
		canvas.draw_polyline(points, color, width, true)


func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0))
