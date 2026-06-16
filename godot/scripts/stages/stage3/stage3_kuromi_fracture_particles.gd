extends RefCounted
## Stage 3 (멘헤라걸 / Kuromi) stone-shatter fracture particle subsystem.
##
## Extracted from stage3_boss_skill_state.gd. This owns the crack-fragment
## particle lifecycle ONLY: pending spawn budgeting, per-frame physics
## integration, z-order sorting, and front-trim capping. The awakening timer
## lifecycle (kuromi_awakening / kuromi_petrified / kuromi_awakened) and its
## external effects (screen shake, audio) stay in the owner, which drives this
## subsystem through spawn_explosion() / update() / clear() delegations.
##
## Determinism contract: the owner INJECTS its own RandomNumberGenerator so the
## fragment draw sequence is identical to the pre-extraction inline code. The
## owner must keep calling spawn_explosion() / update() in the same order it
## previously called the inline helpers, so this generator advances at the same
## points it always did.

const WIDTH := 760.0
const HEIGHT := 750.0
const MAX_KUROMI_CRACK_PARTICLES := 96
const KUROMI_FRAGMENT_SPAWN_BUDGET_PER_FRAME := 16

var _rng: RandomNumberGenerator
var particles: Array = []
var particles_draw_order: Array = []
var pending_large_fragments := 0
var pending_small_fragments := 0


func _init(rng: RandomNumberGenerator = null) -> void:
	_rng = rng if rng != null else RandomNumberGenerator.new()


func clear() -> void:
	particles.clear()
	particles_draw_order.clear()
	pending_large_fragments = 0
	pending_small_fragments = 0


func clear_pending() -> void:
	pending_large_fragments = 0
	pending_small_fragments = 0


func spawn_explosion() -> void:
	pending_large_fragments = _rng.randi_range(36, 48)
	pending_small_fragments = 24
	_spawn_pending(KUROMI_FRAGMENT_SPAWN_BUDGET_PER_FRAME)


func update(delta: float) -> void:
	_spawn_pending(KUROMI_FRAGMENT_SPAWN_BUDGET_PER_FRAME)
	if particles.is_empty():
		particles_draw_order.clear()
		return
	var fps_scale: float = delta * 60.0
	var write_idx: int = 0
	for idx in range(particles.size()):
		var particle: Dictionary = particles[idx]
		particle["x"] = float(particle.get("x", 0.0)) + float(particle.get("vx", 0.0)) * fps_scale
		particle["y"] = float(particle.get("y", 0.0)) + float(particle.get("vy", 0.0)) * fps_scale
		particle["vy"] = float(particle.get("vy", 0.0)) + 0.2 * fps_scale
		particle["vx"] = float(particle.get("vx", 0.0)) * pow(0.99, fps_scale)
		particle["z_pos"] = float(particle.get("z_pos", 0.0)) + float(particle.get("z_vel", 1.0)) * fps_scale
		particle["size"] = float(particle.get("initial_size", 10.0)) * (1.0 + float(particle.get("z_pos", 0.0)) / 50.0)
		if float(particle.get("z_pos", 0.0)) > 30.0:
			particle["vx"] = float(particle.get("vx", 0.0)) * pow(1.02, fps_scale)
			particle["vy"] = float(particle.get("vy", 0.0)) * pow(1.02, fps_scale)
		particle["rotation"] = float(particle.get("rotation", 0.0)) + float(particle.get("angular_vel", 0.0)) * fps_scale
		particle["life"] = float(particle.get("life", 0.0)) - delta
		if float(particle.get("life", 0.0)) <= 0.0:
			continue
		particles[write_idx] = particle
		write_idx += 1
	if write_idx < particles.size():
		particles.resize(write_idx)
	_refresh_draw_order()


func _spawn_pending(budget: int = KUROMI_FRAGMENT_SPAWN_BUDGET_PER_FRAME) -> void:
	if budget <= 0 or (pending_large_fragments <= 0 and pending_small_fragments <= 0):
		return
	var center := Vector2(WIDTH * 0.5, HEIGHT * 0.5)
	var remaining_budget: int = budget
	while remaining_budget > 0 and pending_large_fragments > 0:
		pending_large_fragments -= 1
		remaining_budget -= 1
		particles.append(_make_fragment(
			center + Vector2(_rng.randi_range(-30, 30), _rng.randi_range(-30, 30)),
			_rng.randf_range(15.0, 40.0),
			3.0,
			_rng.randi_range(3, 25),
			_rng.randf_range(0.5, 2.0),
			true
		))
	while remaining_budget > 0 and pending_small_fragments > 0:
		pending_small_fragments -= 1
		remaining_budget -= 1
		particles.append(_make_fragment(
			center + Vector2(_rng.randi_range(-40, 40), _rng.randi_range(-40, 40)),
			_rng.randf_range(10.0, 30.0),
			80.0 / 60.0,
			_rng.randi_range(2, 5),
			_rng.randf_range(0.3, 1.0),
			false
		))
	_trim()
	_refresh_draw_order()


func _make_fragment(pos: Vector2, speed: float, life: float, initial_size: int, z_vel: float, large: bool) -> Dictionary:
	var angle: float = _rng.randf_range(0.0, TAU)
	var edge_boost: float = 1.0
	if large and (abs(cos(angle)) > 0.7 or abs(sin(angle)) > 0.7):
		edge_boost = _rng.randf_range(1.2, 1.8)
	var boosted_speed: float = speed * edge_boost
	var colors := [
		Color(180.0 / 255.0, 180.0 / 255.0, 180.0 / 255.0, 1.0),
		Color(150.0 / 255.0, 150.0 / 255.0, 150.0 / 255.0, 1.0),
		Color(120.0 / 255.0, 120.0 / 255.0, 120.0 / 255.0, 1.0),
		Color(200.0 / 255.0, 200.0 / 255.0, 200.0 / 255.0, 1.0),
		Color(100.0 / 255.0, 100.0 / 255.0, 100.0 / 255.0, 1.0),
		Color(160.0 / 255.0, 140.0 / 255.0, 120.0 / 255.0, 1.0),
	]
	return {
		"x": pos.x,
		"y": pos.y,
		"vx": cos(angle) * boosted_speed,
		"vy": sin(angle) * boosted_speed - _rng.randf_range(-2.0, 8.0),
		"life": life,
		"max_life": life,
		"initial_size": float(initial_size),
		"size": float(initial_size),
		"z_vel": z_vel,
		"z_pos": 0.0,
		"rotation": _rng.randf_range(0.0, 360.0),
		"angular_vel": _rng.randf_range(-30.0, 30.0) if large else _rng.randf_range(-40.0, 40.0),
		"color": colors[_rng.randi_range(0, colors.size() - 1)],
		"seed": _rng.randi(),
	}


func _trim() -> void:
	var overflow: int = particles.size() - MAX_KUROMI_CRACK_PARTICLES
	if overflow <= 0:
		return
	var write_idx: int = 0
	for read_idx in range(overflow, particles.size()):
		particles[write_idx] = particles[read_idx]
		write_idx += 1
	particles.resize(write_idx)


func _refresh_draw_order() -> void:
	particles_draw_order.clear()
	if particles.is_empty():
		return
	for particle in particles:
		particles_draw_order.append(particle)
	particles_draw_order.sort_custom(Callable(self, "_sort_z"))


func _sort_z(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("z_pos", 0.0)) < float(b.get("z_pos", 0.0))
