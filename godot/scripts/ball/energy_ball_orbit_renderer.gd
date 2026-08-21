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
	ball_inner_color: Color,
	fx_lod_scale: float = 1.0,
	visual_alpha: float = 1.0
) -> void:
	var lod_scale: float = clamp(fx_lod_scale, 0.35, 1.0)
	var ring_angles: Array[float] = [
		fmod(current_time_ms * 0.15, 360.0),
		fmod(360.0 - current_time_ms * 0.12, 360.0),
	]
	var ring_tilts: Array[float] = [
		24.0 + sin(current_time_ms * 0.002) * 9.0,
		62.0 + sin(current_time_ms * 0.0015 + 1.0) * 10.0,
	]
	var ring_radii: Array[float] = [
		ball_radius * 1.18,
		ball_radius * 1.34,
	]

	var ring_count: int = ring_radii.size() if lod_scale >= 0.82 else 1
	for ring_idx in range(ring_count):
		ring_renderer.draw_ring(
			canvas,
			pos,
			time_seconds,
			ball_ring_color,
			ball_inner_color,
			ring_angles[ring_idx],
			ring_tilts[ring_idx],
			ring_radii[ring_idx],
			ring_idx,
			lod_scale,
			visual_alpha
		)
