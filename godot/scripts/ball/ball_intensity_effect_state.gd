extends RefCounted

const BallIntensityParticleState := preload("res://scripts/ball/ball_intensity_particle_state.gd")
const BallIntensityTrailState := preload("res://scripts/ball/ball_intensity_trail_state.gd")

var particle_state: Object = BallIntensityParticleState.new()
var trail_state: Object = BallIntensityTrailState.new()


func clear() -> void:
	particle_state.clear()
	trail_state.clear()


func update(
	ball_center: Vector2,
	ball_velocity: Vector2,
	fps_scale: float,
	intensity: float,
	colors: Array[Color]
) -> void:
	if intensity < 0.1:
		particle_state.update_low_intensity(fps_scale)
		return

	var safe_colors: Array[Color] = colors
	if safe_colors.is_empty():
		safe_colors = [
			Color(100.0 / 255.0, 180.0 / 255.0, 1.0),
			Color(80.0 / 255.0, 160.0 / 255.0, 1.0),
			Color(60.0 / 255.0, 140.0 / 255.0, 1.0),
		]

	particle_state.update(ball_center, ball_velocity, fps_scale, intensity, safe_colors)
	trail_state.update(ball_center, fps_scale, intensity, safe_colors)


func get_particles() -> Array[Dictionary]:
	return particle_state.get_particles()


func get_trail() -> Array[Dictionary]:
	return trail_state.get_trail()
