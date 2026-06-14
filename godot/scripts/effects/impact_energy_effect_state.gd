extends RefCounted

const ImpactEffectPayloadFactory := preload("res://scripts/effects/impact_effect_payload_factory.gd")

const ENERGY_EXPLOSION_MAX_PARTICLES := 36
const ENERGY_BURST_LIFE_BASE := 12.0
const ENERGY_BURST_LIFE_INTENSITY_BONUS := 7.0
const ENERGY_BURST_RADIUS_BASE := 34.0
const ENERGY_BURST_RADIUS_INTENSITY_BONUS := 38.0
const ENERGY_EXPLOSION_COLORS: Array[Color] = [
	Color(150.0 / 255.0, 200.0 / 255.0, 1.0),
	Color(100.0 / 255.0, 180.0 / 255.0, 1.0),
	Color(80.0 / 255.0, 160.0 / 255.0, 1.0),
	Color(200.0 / 255.0, 230.0 / 255.0, 1.0),
	Color(120.0 / 255.0, 200.0 / 255.0, 1.0),
]
const DRIVE_PARTICLE_COLORS: Array[Color] = [
	Color(1.0, 230.0 / 255.0, 70.0 / 255.0),
	Color(120.0 / 255.0, 1.0, 160.0 / 255.0),
	Color(200.0 / 255.0, 1.0, 240.0 / 255.0),
]

var energy_explosion_particles: Array[Dictionary] = []


func clear() -> void:
	energy_explosion_particles.clear()


func create_energy_explosion(pos: Vector2, scale: float, intensity: float) -> void:
	energy_explosion_particles.append(ImpactEffectPayloadFactory.build_energy_burst(
		pos,
		scale,
		intensity,
		ENERGY_EXPLOSION_COLORS,
		ENERGY_BURST_RADIUS_BASE,
		ENERGY_BURST_RADIUS_INTENSITY_BONUS,
		ENERGY_BURST_LIFE_BASE,
		ENERGY_BURST_LIFE_INTENSITY_BONUS
	))
	_trim_energy_particles()


func spawn_drive_particles(pos: Vector2, count: int = 4) -> void:
	for _i in range(max(0, count)):
		energy_explosion_particles.append(ImpactEffectPayloadFactory.build_drive_spark(pos, DRIVE_PARTICLE_COLORS))
	_trim_energy_particles()


func update(fps_scale: float) -> void:
	if energy_explosion_particles.is_empty():
		return
	var write_idx: int = 0
	for i in range(energy_explosion_particles.size()):
		var p: Dictionary = energy_explosion_particles[i]
		var lifetime: float = float(p["lifetime"]) + fps_scale
		var max_lifetime: float = float(p["max_lifetime"])
		var particle_size: float = float(p["size"])
		if str(p.get("type", "explosion")) != "burst":
			var particle_pos: Vector2 = p["pos"]
			var particle_vel: Vector2 = p["vel"]
			particle_pos += particle_vel * fps_scale
			particle_vel *= pow(0.94, fps_scale)
			particle_size *= pow(0.95, fps_scale)
			p["pos"] = particle_pos
			p["vel"] = particle_vel
			p["size"] = particle_size
		if lifetime < max_lifetime and particle_size >= 0.3:
			p["lifetime"] = lifetime
			energy_explosion_particles[write_idx] = p
			write_idx += 1
	energy_explosion_particles.resize(write_idx)


func get_energy_explosion_particles() -> Array[Dictionary]:
	return energy_explosion_particles


func has_energy_explosion_particles() -> bool:
	return not energy_explosion_particles.is_empty()


func _trim_energy_particles() -> void:
	while energy_explosion_particles.size() > ENERGY_EXPLOSION_MAX_PARTICLES:
		energy_explosion_particles.pop_front()
