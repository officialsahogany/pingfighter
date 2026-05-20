extends RefCounted

const BALL_VISUAL_SCALE := 1.575
const BALL_SIZE := 28.6 * BALL_VISUAL_SCALE

var pingpong_ball_angle: float = 0.0


func clear() -> void:
	pingpong_ball_angle = 0.0


func draw(canvas: CanvasItem, pos: Vector2, texture: Variant, ball_vel: Vector2) -> void:
	var ball_size: float = (BALL_SIZE + 4.0) * 1.6
	pingpong_ball_angle = fmod(pingpong_ball_angle - ball_vel.x * 3.0, 360.0)

	if texture is Texture2D:
		canvas.draw_texture_rect(
			texture as Texture2D,
			Rect2(pos - Vector2(ball_size, ball_size) * 0.5, Vector2(ball_size, ball_size)),
			false
		)
		return

	var radius: float = ball_size * (16.0 / 36.0)
	canvas.draw_circle(pos, radius, Color(1.0, 1.0, 1.0))
	canvas.draw_circle(pos, ball_size * (14.0 / 36.0), Color(230.0 / 255.0, 230.0 / 255.0, 230.0 / 255.0))
	canvas.draw_circle(pos + Vector2(-ball_size * 4.0 / 36.0, -ball_size * 4.0 / 36.0), ball_size * (6.0 / 36.0), Color(1.0, 1.0, 1.0))
