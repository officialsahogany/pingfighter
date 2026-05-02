extends RefCounted


func draw(canvas: CanvasItem, pos: Vector2, context: Dictionary, ball_render_radius: float) -> void:
	if bool(context.get("poisoned_ball_overlay_active", false)):
		_draw_poisoned_ball_overlay(canvas, pos, ball_render_radius)
	if bool(context.get("viper_knockback_overlay_active", false)):
		_draw_viper_knockback_ball_overlay(canvas, pos, ball_render_radius)


func _draw_poisoned_ball_overlay(canvas: CanvasItem, pos: Vector2, ball_render_radius: float) -> void:
	var radius: float = max(4.0, ball_render_radius)
	var now: float = float(Time.get_ticks_msec())
	var pulse: float = 0.5 + 0.5 * sin(now * 0.0105)
	canvas.draw_circle(pos, radius + 14.0 + 2.0 * pulse, Color(45.0 / 255.0, 125.0 / 255.0, 55.0 / 255.0, (26.0 + 14.0 * pulse) / 255.0))
	canvas.draw_circle(pos, radius + 8.0, Color(75.0 / 255.0, 185.0 / 255.0, 85.0 / 255.0, (40.0 + 18.0 * pulse) / 255.0))
	canvas.draw_circle(pos, radius + 3.0, Color(105.0 / 255.0, 220.0 / 255.0, 110.0 / 255.0, (42.0 + 14.0 * pulse) / 255.0))
	canvas.draw_circle(pos, max(2.0, radius * 0.65), Color(185.0 / 255.0, 1.0, 175.0 / 255.0, (72.0 + 18.0 * pulse) / 255.0))

	var orbit_distance: float = radius + 4.0 + pulse * 3.0
	var mote_size: float = max(2.0, floor(radius / 4.0))
	var phases: Array[float] = [0.0, PI]
	for phase in phases:
		var angle: float = now * 0.006 + phase
		var mote_pos: Vector2 = pos + Vector2(cos(angle) * orbit_distance, sin(angle) * orbit_distance * 0.55)
		var mote_r: float = mote_size + (1.0 if phase == 0.0 else 0.0)
		canvas.draw_circle(mote_pos, mote_r + 1.0, Color(165.0 / 255.0, 1.0, 155.0 / 255.0, (78.0 + 24.0 * pulse) / 255.0))


func _draw_viper_knockback_ball_overlay(canvas: CanvasItem, pos: Vector2, ball_render_radius: float) -> void:
	var radius: float = max(4.0, ball_render_radius)
	var now: float = float(Time.get_ticks_msec())
	var pulse: float = 0.5 + 0.5 * sin(now * 0.0115)
	canvas.draw_circle(pos, radius + 16.0 + 3.0 * pulse, Color(115.0 / 255.0, 24.0 / 255.0, 12.0 / 255.0, (34.0 + 18.0 * pulse) / 255.0))
	canvas.draw_circle(pos, radius + 10.0 + 2.0 * pulse, Color(185.0 / 255.0, 42.0 / 255.0, 18.0 / 255.0, (52.0 + 26.0 * pulse) / 255.0))
	canvas.draw_circle(pos, radius + 4.0, Color(240.0 / 255.0, 76.0 / 255.0, 22.0 / 255.0, (76.0 + 28.0 * pulse) / 255.0))
	canvas.draw_circle(pos, max(3.0, radius * 0.72), Color(1.0, 208.0 / 255.0, 128.0 / 255.0, (82.0 + 20.0 * pulse) / 255.0))

	var ember_distance: float = radius + 5.0 + pulse * 4.0
	var ember_size: float = max(2.0, floor(radius / 4.0))
	var phases: Array[float] = [0.0, PI * 0.7]
	for phase in phases:
		var angle: float = now * 0.0075 + phase
		var ember_pos: Vector2 = pos + Vector2(cos(angle) * ember_distance, sin(angle) * ember_distance * 0.58)
		canvas.draw_circle(ember_pos, ember_size + 1.0, Color(1.0, 170.0 / 255.0, 88.0 / 255.0, (92.0 + 32.0 * pulse) / 255.0))
