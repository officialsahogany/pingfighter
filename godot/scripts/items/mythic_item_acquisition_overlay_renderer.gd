extends RefCounted

const OVERLAY_EXTRA_OVERSCAN := 8.0
const WHITE_OUT_REACH := 5000.0


static func compute_overlay_rect(field_size: Vector2, shake_max_offset: float) -> Rect2:
	var overscan := maxf(0.0, shake_max_offset) + OVERLAY_EXTRA_OVERSCAN
	return Rect2(
		Vector2(-overscan, -overscan),
		field_size + Vector2(overscan * 2.0, overscan * 2.0)
	)


static func compute_white_out_rect(field_size: Vector2) -> Rect2:
	var center := field_size * 0.5
	return Rect2(
		center - Vector2(WHITE_OUT_REACH, WHITE_OUT_REACH),
		Vector2(WHITE_OUT_REACH * 2.0, WHITE_OUT_REACH * 2.0)
	)


static func compute_paddle_glow_radius(intensity: float) -> float:
	var clamped_intensity := clampf(intensity, 0.0, 1.0)
	var pulse := 1.0 + (1.0 - clamped_intensity) * 0.6
	return 90.0 * pulse


static func compute_paddle_ray_reach(intensity: float) -> float:
	return 250.0 * (0.45 + clampf(intensity, 0.0, 1.0) * 0.85)


func draw_texture_overlay(canvas: CanvasItem, texture: Texture2D, rect: Rect2, alpha: float) -> void:
	if canvas == null or texture == null or alpha <= 0.001:
		return
	canvas.draw_texture_rect(
		texture,
		rect,
		false,
		Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0))
	)


func draw_white_out(canvas: CanvasItem, field_size: Vector2, alpha: float) -> void:
	if canvas == null or alpha <= 0.001:
		return
	canvas.draw_rect(
		compute_white_out_rect(field_size),
		Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0)),
		true
	)


func draw_paddle_impact(canvas: CanvasItem, center: Vector2, intensity: float) -> void:
	if canvas == null or intensity <= 0.001:
		return
	var clamped_intensity := clampf(intensity, 0.0, 1.0)
	var radius := compute_paddle_glow_radius(clamped_intensity)
	canvas.draw_circle(center, radius, Color(1.0, 0.85, 0.4, clamped_intensity * 0.55))
	canvas.draw_circle(center, radius * 0.6, Color(1.0, 1.0, 0.92, clamped_intensity * 0.35))
	canvas.draw_circle(center, radius * 0.3, Color(1.0, 1.0, 1.0, clamped_intensity * 0.5))
	draw_paddle_slam_rays(canvas, center, clamped_intensity)


func draw_paddle_slam_rays(canvas: CanvasItem, center: Vector2, intensity: float) -> void:
	var reach := compute_paddle_ray_reach(intensity)
	var warm := Color(1.0, 0.92, 0.6, intensity * 0.5)
	var core := Color(1.0, 1.0, 0.95, intensity * 0.85)
	var horizontal := Vector2(reach, 0.0)
	canvas.draw_line(center - horizontal, center + horizontal, warm, 9.0)
	canvas.draw_line(center - horizontal, center + horizontal, core, 2.5)
	var vertical_up := Vector2(0.0, reach * 0.62)
	var vertical_down := Vector2(0.0, reach * 0.26)
	canvas.draw_line(center - vertical_up, center + vertical_down, warm, 7.0)
	canvas.draw_line(center - vertical_up, center + vertical_down, core, 2.0)
	var diagonal := reach * 0.6 * 0.7071
	var first_diagonal := Vector2(diagonal, diagonal)
	var second_diagonal := Vector2(diagonal, -diagonal)
	canvas.draw_line(center - first_diagonal, center + first_diagonal, warm, 4.5)
	canvas.draw_line(center - second_diagonal, center + second_diagonal, warm, 4.5)
