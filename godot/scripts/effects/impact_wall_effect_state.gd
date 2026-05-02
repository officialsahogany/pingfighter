extends RefCounted

const WALL_IMPACT_FLASH_DURATION := 8.0 / 60.0
const WALL_IMPACT_PARTICLE_LIFE_MIN := 12.0 / 60.0
const WALL_IMPACT_PARTICLE_LIFE_MAX := 20.0 / 60.0
const WALL_IMPACT_PARTICLE_DRAG := 0.92
const WALL_IMPACT_PARTICLE_SIZE_DRAG := 0.95
const WALL_IMPACT_PARTICLE_COLORS: Array[Color] = [
	Color(150.0 / 255.0, 200.0 / 255.0, 1.0),
	Color(180.0 / 255.0, 220.0 / 255.0, 1.0),
	Color(120.0 / 255.0, 180.0 / 255.0, 240.0 / 255.0),
]

var wall_impact_particles: Array[Dictionary] = []
var wall_impact_flash_timer := 0.0
var wall_impact_position := Vector2.ZERO


func clear() -> void:
	wall_impact_particles.clear()
	wall_impact_flash_timer = 0.0
	wall_impact_position = Vector2.ZERO


func spawn_wall_impact(pos: Vector2, side: String, impact_speed: float) -> void:
	wall_impact_flash_timer = WALL_IMPACT_FLASH_DURATION
	wall_impact_position = pos

	var direction_mult: float = 1.0 if side == "left" else -1.0
	var speed_bonus: float = clamp((impact_speed - 6.0) / 24.0, 0.0, 1.0)
	var particle_count: int = 6 + int(round(speed_bonus * 3.0))
	for _i in range(particle_count):
		var angle: float = randf_range(-0.8, 0.8)
		var speed: float = randf_range(2.0, 5.0 + speed_bonus * 2.0)
		var max_life: float = randf_range(WALL_IMPACT_PARTICLE_LIFE_MIN, WALL_IMPACT_PARTICLE_LIFE_MAX)
		wall_impact_particles.append({
			"pos": pos,
			"vel": Vector2(cos(angle) * speed * direction_mult, sin(angle) * speed + randf_range(-1.0, 1.0)),
			"life": max_life,
			"max_life": max_life,
			"size": randf_range(2.0, 4.0 + speed_bonus),
			"color": WALL_IMPACT_PARTICLE_COLORS[randi() % WALL_IMPACT_PARTICLE_COLORS.size()],
		})


func update(delta: float) -> void:
	wall_impact_flash_timer = max(0.0, wall_impact_flash_timer - delta)
	var to_remove: Array[int] = []
	for i in range(wall_impact_particles.size()):
		var p: Dictionary = wall_impact_particles[i]
		var particle_pos: Vector2 = p["pos"]
		var particle_vel: Vector2 = p["vel"]
		var particle_life: float = float(p["life"])
		var particle_size: float = float(p["size"])
		particle_pos += particle_vel
		particle_vel *= WALL_IMPACT_PARTICLE_DRAG
		particle_life -= delta
		particle_size *= pow(WALL_IMPACT_PARTICLE_SIZE_DRAG, delta * 60.0)
		p["pos"] = particle_pos
		p["vel"] = particle_vel
		p["life"] = particle_life
		p["size"] = particle_size
		wall_impact_particles[i] = p
		if particle_life <= 0.0 or particle_size <= 0.5:
			to_remove.append(i)

	to_remove.reverse()
	for idx in to_remove:
		wall_impact_particles.remove_at(idx)


func get_wall_impact_particles() -> Array[Dictionary]:
	return wall_impact_particles.duplicate()


func get_wall_impact_flash_timer() -> float:
	return wall_impact_flash_timer


func get_wall_impact_position() -> Vector2:
	return wall_impact_position
