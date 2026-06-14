extends RefCounted

const ImpactEffectPayloadFactory := preload("res://scripts/effects/impact_effect_payload_factory.gd")

const WALL_IMPACT_FLASH_DURATION := 8.0 / 60.0
const WALL_IMPACT_PARTICLE_LIFE_MIN := 10.0 / 60.0
const WALL_IMPACT_PARTICLE_LIFE_MAX := 16.0 / 60.0
const WALL_IMPACT_PARTICLE_DRAG := 0.92
const WALL_IMPACT_PARTICLE_SIZE_DRAG := 0.95
const WALL_IMPACT_PARTICLE_MAX_COUNT := 12
const WALL_IMPACT_RING_MAX_COUNT := 6
const WALL_IMPACT_RING_LIFE := 0.24
const WALL_BORDER_FLASH_DURATION := 15.0 / 60.0
const WALL_IMPACT_PARTICLE_COLORS: Array[Color] = [
	Color(150.0 / 255.0, 200.0 / 255.0, 1.0),
	Color(180.0 / 255.0, 220.0 / 255.0, 1.0),
	Color(120.0 / 255.0, 180.0 / 255.0, 240.0 / 255.0),
]

var wall_impact_particles: Array[Dictionary] = []
var wall_impact_rings: Array[Dictionary] = []
var wall_impact_flash_timer := 0.0
var wall_impact_position := Vector2.ZERO
var wall_border_flash_timer := 0.0
var wall_border_flash_position := Vector2.ZERO
var wall_border_flash_side := ""
var wall_border_flash_speed := 0.0


func clear() -> void:
	wall_impact_particles.clear()
	wall_impact_rings.clear()
	wall_impact_flash_timer = 0.0
	wall_impact_position = Vector2.ZERO
	wall_border_flash_timer = 0.0
	wall_border_flash_position = Vector2.ZERO
	wall_border_flash_side = ""
	wall_border_flash_speed = 0.0


func spawn_wall_impact(pos: Vector2, side: String, impact_speed: float) -> void:
	wall_impact_flash_timer = WALL_IMPACT_FLASH_DURATION
	wall_impact_position = pos
	wall_border_flash_timer = WALL_BORDER_FLASH_DURATION
	wall_border_flash_position = pos
	wall_border_flash_side = side
	wall_border_flash_speed = impact_speed

	var direction_mult: float = 1.0 if side == "left" else -1.0
	var speed_bonus: float = clamp((impact_speed - 6.0) / 24.0, 0.0, 1.0)
	var particle_count: int = 2 + int(round(speed_bonus))
	wall_impact_rings.append(ImpactEffectPayloadFactory.build_wall_ring(pos, side, speed_bonus, WALL_IMPACT_RING_LIFE, WALL_IMPACT_PARTICLE_COLORS))
	for _i in range(particle_count):
		wall_impact_particles.append(ImpactEffectPayloadFactory.build_wall_particle(
			pos,
			direction_mult,
			speed_bonus,
			WALL_IMPACT_PARTICLE_LIFE_MIN,
			WALL_IMPACT_PARTICLE_LIFE_MAX,
			WALL_IMPACT_PARTICLE_COLORS
		))
	while wall_impact_particles.size() > WALL_IMPACT_PARTICLE_MAX_COUNT:
		wall_impact_particles.pop_front()
	while wall_impact_rings.size() > WALL_IMPACT_RING_MAX_COUNT:
		wall_impact_rings.pop_front()


func update(delta: float) -> void:
	wall_impact_flash_timer = max(0.0, wall_impact_flash_timer - delta)
	wall_border_flash_timer = max(0.0, wall_border_flash_timer - delta)
	_update_rings(delta)
	if wall_impact_particles.is_empty():
		return
	var fps_scale: float = delta * 60.0
	var write_idx: int = 0
	for i in range(wall_impact_particles.size()):
		var p: Dictionary = wall_impact_particles[i]
		var particle_pos: Vector2 = p["pos"]
		var particle_vel: Vector2 = p["vel"]
		var particle_life: float = float(p["life"])
		var particle_size: float = float(p["size"])
		particle_pos += particle_vel * fps_scale
		particle_vel *= pow(WALL_IMPACT_PARTICLE_DRAG, fps_scale)
		particle_life -= delta
		particle_size *= pow(WALL_IMPACT_PARTICLE_SIZE_DRAG, delta * 60.0)
		p["pos"] = particle_pos
		p["vel"] = particle_vel
		p["life"] = particle_life
		p["size"] = particle_size
		if particle_life > 0.0 and particle_size > 0.5:
			wall_impact_particles[write_idx] = p
			write_idx += 1
	wall_impact_particles.resize(write_idx)


func get_wall_impact_particles() -> Array[Dictionary]:
	return wall_impact_particles


func get_wall_impact_rings() -> Array[Dictionary]:
	return wall_impact_rings


func get_wall_impact_flash_timer() -> float:
	return wall_impact_flash_timer


func get_wall_impact_position() -> Vector2:
	return wall_impact_position


func get_wall_border_flash_timer() -> float:
	return wall_border_flash_timer


func get_wall_border_flash_duration() -> float:
	return WALL_BORDER_FLASH_DURATION


func get_wall_border_flash_position() -> Vector2:
	return wall_border_flash_position


func get_wall_border_flash_side() -> String:
	return wall_border_flash_side


func get_wall_border_flash_speed() -> float:
	return wall_border_flash_speed


func has_wall_impact_effects() -> bool:
	return (
		wall_impact_flash_timer > 0.0
		or wall_border_flash_timer > 0.0
		or not wall_impact_particles.is_empty()
		or not wall_impact_rings.is_empty()
	)


func _update_rings(delta: float) -> void:
	if wall_impact_rings.is_empty():
		return
	var write_idx: int = 0
	for i in range(wall_impact_rings.size()):
		var ring: Dictionary = wall_impact_rings[i]
		var life: float = float(ring.get("life", 0.0)) - delta
		ring["life"] = life
		if life > 0.0:
			wall_impact_rings[write_idx] = ring
			write_idx += 1
	wall_impact_rings.resize(write_idx)
