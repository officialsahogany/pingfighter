extends SceneTree

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemEffectStateApplier := preload("res://scripts/items/active_item_effect_state_applier.gd")
const ActiveItemHolyBarrierParticles := preload("res://scripts/items/active_item_holy_barrier_particles.gd")
const ActiveItemHolyBarrierRuntime := preload("res://scripts/items/active_item_holy_barrier_runtime.gd")

var _failures: Array[String] = []


class FakeTarget:
	extends RefCounted

	var holy_barrier_active := false
	var holy_barrier_timer_frames := 0.0
	var holy_barrier_initial_timer_frames := 0.0
	var holy_barrier_glow_phase := 0.0
	var holy_barrier_particle_accumulator_frames := 0.0
	var holy_barrier_particles: Array[Dictionary] = []


func _init() -> void:
	_verify_direct_runtime_state()
	_verify_direct_runtime_update_application()
	_verify_controller_delegates_runtime_state()

	if _failures.is_empty():
		print("active_item_holy_barrier_runtime_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_runtime_state() -> void:
	var runtime: Object = ActiveItemHolyBarrierRuntime.new()

	var started: Dictionary = runtime.start_state()
	_expect(bool(started.get("active", false)), "holy barrier runtime should start active")
	_expect(is_equal_approx(float(started.get("timer_frames", 0.0)), 360.0), "holy barrier runtime should use reference duration")
	_expect(is_equal_approx(float(started.get("glow_phase", -1.0)), 0.0), "holy barrier runtime should reset glow on start")
	_expect(bool(started.get("clear_particles", false)), "holy barrier runtime should clear particles on start")

	var updated: Dictionary = runtime.update_state(true, 30.0, 30.0, 1.0, 4.5, 1.0 / 60.0)
	_expect(bool(updated.get("active", false)), "holy barrier runtime should remain active while time remains")
	_expect(is_equal_approx(float(updated.get("timer_frames", 0.0)), 29.0), "holy barrier runtime should tick duration")
	_expect(is_equal_approx(float(updated.get("glow_phase", 0.0)), 1.1), "holy barrier runtime should advance glow")
	_expect(is_equal_approx(float(updated.get("particle_accumulator_frames", 0.0)), 4.5), "holy barrier runtime should preserve accumulator before particles")
	_expect(bool(updated.get("advance_idle_particles", false)), "holy barrier runtime should request idle particle advance")

	var expired: Dictionary = runtime.update_state(true, 1.0, 30.0, 5.0, 4.5, 1.0 / 60.0)
	_expect(not bool(expired.get("active", true)), "holy barrier runtime should expire at zero timer")
	_expect(is_equal_approx(float(expired.get("glow_phase", -1.0)), 5.0), "holy barrier expiry should preserve current glow until next inactive tick")
	_expect(is_equal_approx(float(expired.get("particle_accumulator_frames", 0.0)), 4.5), "holy barrier expiry should preserve accumulator until next inactive tick")
	_expect(bool(expired.get("clear_particles", false)), "holy barrier runtime should clear particles on expiry")

	var inactive: Dictionary = runtime.update_state(false, 99.0, 30.0, 3.0, 2.0, 1.0 / 30.0)
	_expect(not bool(inactive.get("active", true)), "inactive holy barrier runtime should stay inactive")
	_expect(is_equal_approx(float(inactive.get("timer_frames", -1.0)), 0.0), "inactive holy barrier runtime should reset timer")
	_expect(is_equal_approx(float(inactive.get("glow_phase", -1.0)), 0.0), "inactive holy barrier runtime should reset glow")
	_expect(bool(inactive.get("update_fade_particles", false)), "inactive holy barrier runtime should request particle fade update")
	_expect(is_equal_approx(float(inactive.get("fps_scale", 0.0)), 2.0), "inactive holy barrier runtime should expose fps scale")


func _verify_direct_runtime_update_application() -> void:
	seed(223)
	var runtime: Object = ActiveItemHolyBarrierRuntime.new()
	var state_applier: Object = ActiveItemEffectStateApplier.new()
	var particles_helper: Object = ActiveItemHolyBarrierParticles.new()
	var target := FakeTarget.new()

	target.holy_barrier_active = true
	target.holy_barrier_timer_frames = 30.0
	target.holy_barrier_initial_timer_frames = 30.0
	target.holy_barrier_particle_accumulator_frames = 4.5
	runtime.apply_update(
		target,
		target.holy_barrier_particles,
		target.holy_barrier_active,
		target.holy_barrier_timer_frames,
		target.holy_barrier_initial_timer_frames,
		target.holy_barrier_glow_phase,
		target.holy_barrier_particle_accumulator_frames,
		1.0 / 60.0,
		state_applier,
		particles_helper
	)
	_expect(target.holy_barrier_active, "holy barrier runtime should apply active update state")
	_expect(is_equal_approx(target.holy_barrier_timer_frames, 29.0), "holy barrier runtime should apply timer tick")
	_expect(is_equal_approx(target.holy_barrier_glow_phase, 0.1), "holy barrier runtime should apply glow tick")
	_expect(target.holy_barrier_particles.size() == 2, "holy barrier runtime should advance idle particles")
	_expect(is_equal_approx(target.holy_barrier_particle_accumulator_frames, 0.5), "holy barrier runtime should write particle accumulator result")

	target.holy_barrier_active = false
	target.holy_barrier_particles.clear()
	target.holy_barrier_particles.append({
		"position": Vector2.ZERO,
		"velocity": Vector2.ZERO,
		"alpha": 0.01,
	})
	runtime.apply_update(
		target,
		target.holy_barrier_particles,
		target.holy_barrier_active,
		target.holy_barrier_timer_frames,
		target.holy_barrier_initial_timer_frames,
		target.holy_barrier_glow_phase,
		target.holy_barrier_particle_accumulator_frames,
		1.0 / 30.0,
		state_applier,
		particles_helper
	)
	_expect(is_equal_approx(target.holy_barrier_glow_phase, 0.0), "holy barrier runtime should apply inactive glow reset")
	_expect(target.holy_barrier_particles.is_empty(), "holy barrier runtime should fade inactive particles")


func _verify_controller_delegates_runtime_state() -> void:
	seed(222)
	var controller: Object = ActiveItemEffectController.new()
	controller.holy_barrier_particles.append({"alpha": 1.0})

	_expect(controller.activate_holy_barrier(null, null), "controller should activate holy barrier through runtime helper")
	_expect(controller.holy_barrier_active, "controller should apply active holy barrier state")
	_expect(is_equal_approx(controller.holy_barrier_timer_frames, 360.0), "controller should apply helper duration")
	_expect(is_equal_approx(controller.holy_barrier_glow_phase, 0.0), "controller should reset glow on activation")
	_expect(controller.holy_barrier_particles.is_empty(), "controller should clear particles on activation")

	controller.holy_barrier_timer_frames = 30.0
	controller.holy_barrier_initial_timer_frames = 30.0
	controller.holy_barrier_particle_accumulator_frames = 4.5
	controller.update(null, 1.0 / 60.0)
	_expect(controller.holy_barrier_active, "controller should keep holy barrier active while helper timer remains")
	_expect(is_equal_approx(controller.holy_barrier_timer_frames, 29.0), "controller should apply helper timer tick")
	_expect(is_equal_approx(controller.holy_barrier_glow_phase, 0.1), "controller should apply helper glow tick")
	_expect(controller.holy_barrier_particles.size() == 2, "controller should still delegate idle particles")
	_expect(is_equal_approx(controller.holy_barrier_particle_accumulator_frames, 0.5), "controller should keep particle accumulator result")

	controller.holy_barrier_particles.append({"alpha": 1.0})
	controller.holy_barrier_active = true
	controller.holy_barrier_timer_frames = 1.0
	controller.holy_barrier_initial_timer_frames = 30.0
	controller.holy_barrier_glow_phase = 7.0
	controller.holy_barrier_particle_accumulator_frames = 4.5
	controller.update(null, 1.0 / 60.0)
	_expect(not controller.holy_barrier_active, "controller should apply helper expiry")
	_expect(is_equal_approx(controller.holy_barrier_glow_phase, 7.0), "controller should preserve glow on expiry tick")
	_expect(controller.holy_barrier_particles.is_empty(), "controller should clear particles on helper expiry")

	controller.holy_barrier_active = false
	controller.holy_barrier_particles.append({
		"position": Vector2.ZERO,
		"velocity": Vector2.ZERO,
		"alpha": 0.01,
	})
	controller.update(null, 1.0 / 30.0)
	_expect(is_equal_approx(controller.holy_barrier_glow_phase, 0.0), "controller should reset glow during inactive tick")
	_expect(controller.holy_barrier_particles.is_empty(), "controller should still fade inactive particles")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
