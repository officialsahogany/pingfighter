extends RefCounted

const PowerSmashParticleState := preload("res://scripts/characters/smasher_power_smash_particle_state.gd")
const PowerSmashTrailState := preload("res://scripts/characters/smasher_power_smash_trail_state.gd")

var particle_state: Object = PowerSmashParticleState.new()
var trail_state: Object = PowerSmashTrailState.new()


func clear() -> void:
	trail_state.clear()
	particle_state.clear()


func spawn_trail(pos: Vector2, ball_size: float, combo_count: int = 0) -> void:
	trail_state.spawn(pos, ball_size, combo_count)


func spawn_particles(pos: Vector2, count: int, combo_count: int = 0) -> void:
	particle_state.spawn(pos, count, combo_count)


func spawn_initial_burst(pos: Vector2) -> void:
	particle_state.spawn_initial_burst(pos)


func update(
	fps_scale: float,
	ball_pos: Vector2,
	ball_active: bool,
	ball_size: float,
	power_active: bool,
	parabola_active: bool,
	combo_count: int = 0
) -> void:
	if power_active and ball_active:
		trail_state.maybe_spawn(ball_pos, ball_size, combo_count)
		if parabola_active:
			if randf() < min(1.0, 0.70 * fps_scale):
				particle_state.spawn_ambient_energy(ball_pos)
			if randf() < min(1.0, 0.30 * fps_scale):
				particle_state.spawn_ambient_spark(ball_pos)

	trail_state.update(fps_scale)
	particle_state.update(fps_scale)


func get_trails() -> Array[Dictionary]:
	return trail_state.get_trails()


func get_particles() -> Array[Dictionary]:
	return particle_state.get_particles()
