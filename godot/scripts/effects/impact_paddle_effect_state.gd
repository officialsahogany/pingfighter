extends RefCounted

const PADDLE_HIT_PLAYER_COLOR_LIGHT := Color(0.40, 0.60, 1.0)
const PADDLE_HIT_BOSS_COLOR_LIGHT := Color(1.0, 0.45, 0.35)

var hit_particles: Array[Dictionary] = []


func clear() -> void:
	hit_particles.clear()


func spawn_hit_particles(pos: Vector2, color: Color) -> void:
	for _i in range(8):
		hit_particles.append({
			"pos": pos,
			"vel": Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0)),
			"life": randf_range(0.20, 0.40),
			"max_life": 0.40,
			"size": randf_range(2.0, 5.0),
			"color": color,
		})


func spawn_paddle_hit_particles(pos: Vector2, is_player: bool) -> void:
	spawn_hit_particles(pos, PADDLE_HIT_PLAYER_COLOR_LIGHT if is_player else PADDLE_HIT_BOSS_COLOR_LIGHT)


func update(delta: float) -> void:
	var to_remove: Array[int] = []
	for i in range(hit_particles.size()):
		var p: Dictionary = hit_particles[i]
		var particle_pos: Vector2 = p["pos"]
		var particle_vel: Vector2 = p["vel"]
		var particle_life: float = float(p["life"])
		particle_pos += particle_vel
		particle_vel *= 0.92
		particle_life -= delta
		p["pos"] = particle_pos
		p["vel"] = particle_vel
		p["life"] = particle_life
		hit_particles[i] = p
		if particle_life <= 0.0:
			to_remove.append(i)

	to_remove.reverse()
	for idx in to_remove:
		hit_particles.remove_at(idx)


func get_hit_particles() -> Array[Dictionary]:
	return hit_particles.duplicate()
