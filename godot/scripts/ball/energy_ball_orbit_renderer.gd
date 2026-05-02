extends RefCounted

const EnergyBallOrbitRingRenderer := preload("res://scripts/ball/energy_ball_orbit_ring_renderer.gd")

var ring_renderer: Object = EnergyBallOrbitRingRenderer.new()


func draw(
	canvas: CanvasItem,
	pos: Vector2,
	current_time_ms: float,
	time_seconds: float,
	ball_radius: float,
	ball_ring_color: Color,
	ball_inner_color: Color
) -> void:
	var ring_angles: Array[float] = [
		fmod(current_time_ms * 0.15, 360.0),
		fmod(360.0 - current_time_ms * 0.12, 360.0),
		fmod(current_time_ms * 0.15, 360.0),
	]
	var ring_tilts: Array[float] = [
		20.0 + sin(current_time_ms * 0.002) * 10.0,
		45.0 + sin(current_time_ms * 0.0015 + 1.0) * 12.0,
		70.0 + sin(current_time_ms * 0.001 + 2.0) * 8.0,
	]
	var ring_radii: Array[float] = [
		ball_radius * 1.156,
		ball_radius * 1.264,
		ball_radius * 1.372,
	]

	for ring_idx in range(ring_radii.size()):
		ring_renderer.draw_ring(
			canvas,
			pos,
			time_seconds,
			ball_ring_color,
			ball_inner_color,
			ring_angles[ring_idx],
			ring_tilts[ring_idx],
			ring_radii[ring_idx],
			ring_idx
		)
