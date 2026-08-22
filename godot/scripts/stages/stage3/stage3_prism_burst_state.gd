extends RefCounted

const StageActorDrawContextArrays := preload("res://scripts/stages/common/stage_actor_draw_context_arrays.gd")
const Stage3BossSkillPayloadFactory := preload("res://scripts/stages/stage3/stage3_boss_skill_payload_factory.gd")

const MAX_PARTICLES := 60
const NORMAL_COUNT := 18
const STRONG_MIN_COUNT := 18
const STRONG_MAX_COUNT := 22

var prism_particles: Array = []

var _rng: RandomNumberGenerator


func _init(shared_rng: RandomNumberGenerator) -> void:
	_rng = shared_rng


func reset() -> void:
	prism_particles.clear()


func spawn(center: Vector2, strong: bool = false) -> int:
	var particle_count: int = _rng.randi_range(STRONG_MIN_COUNT, STRONG_MAX_COUNT) if strong else NORMAL_COUNT
	prism_particles.append_array(Stage3BossSkillPayloadFactory.build_prism_particles(
		center,
		particle_count,
		strong,
		_rng
	))
	if prism_particles.size() > MAX_PARTICLES:
		_trim_from_front(MAX_PARTICLES)
	return particle_count


func update(delta: float) -> void:
	var fps_scale: float = delta * 60.0
	var damping: float = pow(0.98, fps_scale)
	var write_idx: int = 0
	for idx in range(prism_particles.size()):
		var particle: Dictionary = prism_particles[idx]
		particle["x"] = float(particle["x"]) + float(particle["vx"]) * fps_scale
		particle["y"] = float(particle["y"]) + float(particle["vy"]) * fps_scale
		particle["vy"] = (float(particle["vy"]) + 0.10 * fps_scale) * damping
		particle["vx"] = float(particle["vx"]) * damping
		particle["sparkle"] = float(particle.get("sparkle", 0.0)) + 0.30 * fps_scale
		particle["life"] = float(particle["life"]) - delta
		if float(particle["life"]) <= 0.0:
			continue
		prism_particles[write_idx] = particle
		write_idx += 1
	if write_idx < prism_particles.size():
		prism_particles.resize(write_idx)


func get_actor_draw_context(copy_arrays: bool = false) -> Dictionary:
	return {
		"stage3_prism_particles": StageActorDrawContextArrays.snapshot(prism_particles, copy_arrays, true),
	}


func _trim_from_front(max_size: int) -> void:
	var overflow: int = prism_particles.size() - max_size
	if overflow <= 0:
		return
	var write_idx: int = 0
	for read_idx in range(overflow, prism_particles.size()):
		prism_particles[write_idx] = prism_particles[read_idx]
		write_idx += 1
	prism_particles.resize(write_idx)
