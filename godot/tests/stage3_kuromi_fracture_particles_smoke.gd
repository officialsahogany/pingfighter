extends SceneTree
## Seals the stage3_kuromi_fracture_particles.gd extraction from
## stage3_boss_skill_state.gd. Asserts the END EFFECT (fracture particles spawn,
## cap, z-sort, decay, determinism) so a broken/no-op subsystem fails here, and
## proves the Stage3BossSkillState awakening explosion still routes through the
## extracted module end-to-end.

const Stage3BossSkillState := preload("res://scripts/stages/stage3/stage3_boss_skill_state.gd")
const Stage3KuromiFractureParticles := preload("res://scripts/stages/stage3/stage3_kuromi_fracture_particles.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_module_caps_particle_count()
	_verify_module_draw_order_z_sorted()
	_verify_module_determinism_same_seed()
	_verify_clear_semantics()
	_verify_awakening_explosion_routes_through_module()

	if _failures.is_empty():
		print("stage3_kuromi_fracture_particles_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _make_module(seed_value: int) -> Object:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return Stage3KuromiFractureParticles.new(rng)


func _verify_module_caps_particle_count() -> void:
	var module: Object = _make_module(101)
	# Overflow the spawn queue well past the live cap so trimming must fire.
	module.pending_large_fragments = 200
	var cap: int = Stage3KuromiFractureParticles.MAX_KUROMI_CRACK_PARTICLES
	var stayed_capped := true
	for _frame in range(40):
		module.update(0.016)
		if module.particles.size() > cap:
			stayed_capped = false
	_expect(stayed_capped, "fracture particles must never exceed MAX_KUROMI_CRACK_PARTICLES while spawning")
	_expect(module.particles.size() == cap, "fracture spawn should actually reach the live cap (proves spawning + trim ran)")
	_expect(module.particles_draw_order.size() == module.particles.size(), "draw order must mirror the live particle count")


func _verify_module_draw_order_z_sorted() -> void:
	var module: Object = _make_module(202)
	module.spawn_explosion()
	for _frame in range(6):
		module.update(0.05)
	_expect(not module.particles.is_empty(), "explosion should leave live fracture particles")
	_expect(module.particles_draw_order.size() == module.particles.size(), "draw order length must equal particle count")
	var sorted := true
	for idx in range(1, module.particles_draw_order.size()):
		var prev_z: float = float(module.particles_draw_order[idx - 1].get("z_pos", 0.0))
		var cur_z: float = float(module.particles_draw_order[idx].get("z_pos", 0.0))
		if cur_z < prev_z:
			sorted = false
	_expect(sorted, "fracture draw order must stay ascending by z_pos")


func _verify_module_determinism_same_seed() -> void:
	var a: Object = _make_module(777)
	var b: Object = _make_module(777)
	a.spawn_explosion()
	b.spawn_explosion()
	for _frame in range(5):
		a.update(0.05)
		b.update(0.05)
	_expect(a.particles.size() == b.particles.size(), "same seed must yield the same fracture particle count")
	var identical: bool = a.particles.size() == b.particles.size()
	if identical:
		for idx in range(a.particles.size()):
			var pa: Dictionary = a.particles[idx]
			var pb: Dictionary = b.particles[idx]
			if not is_equal_approx(float(pa.get("x", 0.0)), float(pb.get("x", 0.0))):
				identical = false
			if not is_equal_approx(float(pa.get("z_pos", 0.0)), float(pb.get("z_pos", 0.0))):
				identical = false
			if not is_equal_approx(float(pa.get("rotation", 0.0)), float(pb.get("rotation", 0.0))):
				identical = false
			if Color(pa.get("color", Color.WHITE)) != Color(pb.get("color", Color.WHITE)):
				identical = false
	_expect(identical, "injected-rng fracture output must be deterministic for a fixed seed")


func _verify_clear_semantics() -> void:
	var module: Object = _make_module(303)
	module.spawn_explosion()
	module.update(0.05)
	_expect(not module.particles.is_empty(), "explosion + update should spawn live particles")
	# clear_pending() drops the spawn queue but must NOT wipe live particles.
	module.clear_pending()
	_expect(module.pending_large_fragments == 0 and module.pending_small_fragments == 0, "clear_pending must zero the spawn queue")
	_expect(not module.particles.is_empty(), "clear_pending must keep already-spawned particles alive")
	# clear() wipes everything.
	module.clear()
	_expect(module.particles.is_empty(), "clear must empty the live particles")
	_expect(module.particles_draw_order.is_empty(), "clear must empty the draw order")
	_expect(module.pending_large_fragments == 0 and module.pending_small_fragments == 0, "clear must zero the spawn queue")


func _verify_awakening_explosion_routes_through_module() -> void:
	var state := Stage3BossSkillState.new()
	state.handle_score_event("player", {"player_score": 2, "boss_score": 0}, {})
	_expect(state.is_kuromi_awakening_active(), "reaching 2 points should arm Kuromi awakening")
	var context := {"current_stage": 3, "ball_active": false, "waiting_for_serve": true}
	for _frame in range(70):
		state.update(0.05, context, {})
	var snapshot: Dictionary = state.get_snapshot()
	var crack: Array = _as_array(snapshot.get("stage3_kuromi_crack_particles", []))
	_expect(not crack.is_empty(), "awakening explosion should produce fracture particles through the extracted module")
	_expect(crack.size() <= Stage3KuromiFractureParticles.MAX_KUROMI_CRACK_PARTICLES, "snapshot fracture particles must respect the live cap")
	var draw_order: Array = _as_array(snapshot.get("stage3_kuromi_crack_particles_draw_order", []))
	_expect(draw_order.size() == crack.size(), "snapshot draw order must mirror the fracture particle count")
	_expect(bool(snapshot.get("stage3_kuromi_awakened", false)), "awakening should finish and mark Kuromi awakened")


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
