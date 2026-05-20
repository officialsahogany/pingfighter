extends RefCounted

const BALL_VISUAL_SCALE := 1.575
const BALL_SIZE := 28.6 * BALL_VISUAL_SCALE


func draw(canvas: CanvasItem, pos: Vector2) -> void:
	var radius: float = BALL_SIZE * 0.5 + 1.0
	canvas.draw_circle(pos, radius, Color(25.0 / 255.0, 25.0 / 255.0, 30.0 / 255.0))
	canvas.draw_circle(pos + Vector2(-radius / 3.0, -radius / 3.0), radius * 0.5, Color(45.0 / 255.0, 45.0 / 255.0, 50.0 / 255.0, 0.95))

	var fuse_top: float = pos.y - radius - 5.0 * BALL_VISUAL_SCALE
	canvas.draw_line(
		Vector2(pos.x + 2.0, pos.y - radius),
		Vector2(pos.x + 3.0, fuse_top),
		Color(100.0 / 255.0, 90.0 / 255.0, 70.0 / 255.0),
		2.0 * BALL_VISUAL_SCALE
	)

	var blink: bool = int(float(Time.get_ticks_msec()) / 125.0) % 2 == 0
	if blink:
		canvas.draw_circle(Vector2(pos.x + 3.0, fuse_top - 2.0 * BALL_VISUAL_SCALE), 4.0 * BALL_VISUAL_SCALE, Color(1.0, 220.0 / 255.0, 60.0 / 255.0))
		canvas.draw_circle(Vector2(pos.x + 3.0, fuse_top - 3.0 * BALL_VISUAL_SCALE), 2.0 * BALL_VISUAL_SCALE, Color(1.0, 140.0 / 255.0, 0.0))
	else:
		canvas.draw_circle(Vector2(pos.x + 3.0, fuse_top - 2.0 * BALL_VISUAL_SCALE), 3.0 * BALL_VISUAL_SCALE, Color(1.0, 160.0 / 255.0, 30.0 / 255.0))
		canvas.draw_circle(Vector2(pos.x + 3.0, fuse_top - 3.0 * BALL_VISUAL_SCALE), 2.0 * BALL_VISUAL_SCALE, Color(1.0, 80.0 / 255.0, 0.0))
	canvas.draw_arc(pos, radius, 0.0, TAU, 32, Color(15.0 / 255.0, 15.0 / 255.0, 18.0 / 255.0), 1.0 * BALL_VISUAL_SCALE)
