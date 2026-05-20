extends SceneTree

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemHolyBarrierParticles := preload("res://scripts/items/active_item_holy_barrier_particles.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_particle_lifecycle()
	_verify_controller_delegates_particles()

	if _failures.is_empty():
		print("active_item_holy_barrier_particles_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_particle_lifecycle() -> void:
	seed(99)
	var particles_helper: Object = ActiveItemHolyBarrierParticles.new()
	var particles: Array[Dictionary] = []

	var accumulator: float = particles_helper.advance_idle_particles(particles, 4.5, 1.0, 1.0 / 60.0)
	_expect(is_equal_approx(accumulator, 0.5), "holy barrier particles should return remaining spawn accumulator")
	_expect(particles.size() == 2, "holy barrier idle particles should spawn in pairs")
	_expect(float(particles[0].get("alpha", 0.0)) < 1.0, "holy barrier idle particles should fade after spawning")

	particles_helper.spawn_hit_particles(particles, Vector2(200.0, 720.0))
	_expect(particles.size() == 12, "holy barrier hit should add burst particles")

	var expired: Array[Dictionary] = [{
		"position": Vector2.ZERO,
		"velocity": Vector2.ZERO,
		"alpha": 0.01,
	}]
	particles_helper.update_particles(expired, 2.0, 1.0 / 30.0)
	_expect(expired.is_empty(), "holy barrier particles should compact faded entries")


func _verify_controller_delegates_particles() -> void:
	seed(111)
	var controller: Object = ActiveItemEffectController.new()
	controller.holy_barrier_active = true
	controller.holy_barrier_timer_frames = 30.0
	controller.holy_barrier_initial_timer_frames = 30.0
	controller.holy_barrier_particle_accumulator_frames = 4.5

	controller.update(null, 1.0 / 60.0)
	_expect(controller.holy_barrier_particles.size() == 2, "controller should delegate holy barrier idle particles")
	_expect(is_equal_approx(controller.holy_barrier_particle_accumulator_frames, 0.5), "controller should preserve delegated holy barrier accumulator")

	controller.notify_holy_barrier_hit(Vector2(200.0, 720.0))
	_expect(controller.holy_barrier_particles.size() == 12, "controller should delegate holy barrier hit particles")

	controller.holy_barrier_active = false
	controller.holy_barrier_particles.clear()
	controller.holy_barrier_particles.append({
		"position": Vector2.ZERO,
		"velocity": Vector2.ZERO,
		"alpha": 0.01,
	})
	controller.update(null, 1.0 / 30.0)
	_expect(controller.holy_barrier_particles.is_empty(), "inactive controller should still fade remaining holy barrier particles")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
