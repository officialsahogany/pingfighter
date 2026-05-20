extends SceneTree

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemEffectStateApplier := preload("res://scripts/items/active_item_effect_state_applier.gd")
const ActiveItemMagnetFieldParticles := preload("res://scripts/items/active_item_magnet_field_particles.gd")
const ActiveItemMagnetFieldRuntime := preload("res://scripts/items/active_item_magnet_field_runtime.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var player_pos := Vector2(100.0, 600.0)
	var player_paddle_width := 120.0
	var player_paddle_height := 40.0


class FakeTarget:
	extends RefCounted

	var magnet_field_active := false
	var magnet_field_timer_frames := 0.0
	var magnet_field_initial_timer_frames := 0.0
	var magnet_field_phase := 0.0
	var magnet_field_player_center := Vector2.ZERO
	var magnet_field_particle_accumulator_frames := 0.0
	var magnet_field_particles: Array[Dictionary] = []


func _init() -> void:
	_verify_direct_runtime_state()
	_verify_direct_runtime_update_application()
	_verify_controller_delegates_runtime_state()

	if _failures.is_empty():
		print("active_item_magnet_field_runtime_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_runtime_state() -> void:
	var runtime: Object = ActiveItemMagnetFieldRuntime.new()
	var center := Vector2(160.0, 620.0)

	var started: Dictionary = runtime.start_state(center)
	_expect(bool(started.get("active", false)), "magnet runtime should start active")
	_expect(is_equal_approx(float(started.get("timer_frames", 0.0)), 480.0), "magnet runtime should use reference duration")
	_expect(started.get("player_center", Vector2.ZERO) == center, "magnet runtime should preserve start center")
	_expect(bool(started.get("clear_particles", false)), "magnet runtime should request particle clear on start")

	var updated: Dictionary = runtime.update_state(true, 30.0, 30.0, 1.0, center, 2.5, true, 1.0 / 60.0)
	_expect(bool(updated.get("active", false)), "magnet runtime should remain active while time remains")
	_expect(is_equal_approx(float(updated.get("timer_frames", 0.0)), 29.0), "magnet runtime should tick duration")
	_expect(is_equal_approx(float(updated.get("phase", 0.0)), 1.08), "magnet runtime should advance phase")
	_expect(is_equal_approx(float(updated.get("particle_accumulator_frames", 0.0)), 2.5), "magnet runtime should preserve accumulator before particles")
	_expect(not bool(updated.get("clear_particles", true)), "magnet runtime should not clear particles during active tick")

	var expired: Dictionary = runtime.update_state(true, 1.0, 30.0, 1.0, center, 2.5, true, 1.0 / 60.0)
	_expect(not bool(expired.get("active", true)), "magnet runtime should expire at zero timer")
	_expect(is_equal_approx(float(expired.get("phase", -1.0)), 0.0), "magnet runtime should reset phase on expiry")
	_expect(bool(expired.get("clear_particles", false)), "magnet runtime should clear particles on expiry")

	var lost_owner: Dictionary = runtime.update_state(true, 30.0, 30.0, 1.0, center, 2.5, false, 1.0 / 60.0)
	_expect(not bool(lost_owner.get("active", true)), "magnet runtime should clear when owner disappears")
	_expect(bool(lost_owner.get("clear_particles", false)), "magnet runtime should request particle clear without owner")

	var inactive: Dictionary = runtime.update_state(false, 99.0, 30.0, 3.0, center, 5.0, false, 1.0 / 60.0)
	_expect(not bool(inactive.get("active", true)), "inactive magnet runtime should stay inactive")
	_expect(is_equal_approx(float(inactive.get("timer_frames", -1.0)), 0.0), "inactive magnet runtime should reset timer")
	_expect(is_equal_approx(float(inactive.get("phase", 0.0)), 3.0), "inactive magnet runtime should preserve idle phase")
	_expect(not bool(inactive.get("clear_particles", true)), "inactive magnet runtime should not request particle clear")


func _verify_direct_runtime_update_application() -> void:
	seed(100)
	var runtime: Object = ActiveItemMagnetFieldRuntime.new()
	var state_applier: Object = ActiveItemEffectStateApplier.new()
	var particles_helper: Object = ActiveItemMagnetFieldParticles.new()
	var target := FakeTarget.new()
	var center := Vector2(160.0, 620.0)

	target.magnet_field_active = true
	target.magnet_field_timer_frames = 30.0
	target.magnet_field_initial_timer_frames = 30.0
	target.magnet_field_particle_accumulator_frames = 2.5
	runtime.apply_update(
		target,
		target.magnet_field_particles,
		target.magnet_field_active,
		target.magnet_field_timer_frames,
		target.magnet_field_initial_timer_frames,
		target.magnet_field_phase,
		center,
		target.magnet_field_particle_accumulator_frames,
		true,
		1.0 / 60.0,
		state_applier,
		particles_helper
	)
	_expect(target.magnet_field_active, "magnet runtime should apply active update state")
	_expect(is_equal_approx(target.magnet_field_timer_frames, 29.0), "magnet runtime should apply timer tick")
	_expect(is_equal_approx(target.magnet_field_phase, 0.08), "magnet runtime should apply phase tick")
	_expect(target.magnet_field_player_center == center, "magnet runtime should apply player center")
	_expect(target.magnet_field_particles.size() == 1, "magnet runtime should advance particles")
	_expect(is_equal_approx(target.magnet_field_particle_accumulator_frames, 0.5), "magnet runtime should write particle accumulator result")

	target.magnet_field_particles.append({"alpha": 1.0})
	target.magnet_field_active = true
	target.magnet_field_timer_frames = 1.0
	target.magnet_field_initial_timer_frames = 30.0
	target.magnet_field_phase = 5.0
	target.magnet_field_particle_accumulator_frames = 2.5
	runtime.apply_update(
		target,
		target.magnet_field_particles,
		target.magnet_field_active,
		target.magnet_field_timer_frames,
		target.magnet_field_initial_timer_frames,
		target.magnet_field_phase,
		center,
		target.magnet_field_particle_accumulator_frames,
		true,
		1.0 / 60.0,
		state_applier,
		particles_helper
	)
	_expect(not target.magnet_field_active, "magnet runtime should apply expiry state")
	_expect(is_equal_approx(target.magnet_field_phase, 0.0), "magnet runtime should reset phase on expiry")
	_expect(target.magnet_field_particles.is_empty(), "magnet runtime should clear particles on expiry")


func _verify_controller_delegates_runtime_state() -> void:
	seed(99)
	var controller: Object = ActiveItemEffectController.new()
	var owner := FakeOwner.new()
	controller.magnet_field_particles.append({"alpha": 1.0})

	_expect(controller.activate_magnet_field(owner, null), "controller should activate magnet field through runtime helper")
	_expect(controller.magnet_field_active, "controller should apply active magnet state")
	_expect(is_equal_approx(controller.magnet_field_timer_frames, 480.0), "controller should apply helper duration")
	_expect(controller.magnet_field_player_center == Vector2(160.0, 620.0), "controller should snapshot owner center on activation")
	_expect(controller.magnet_field_particles.is_empty(), "controller should clear particles on activation")

	controller.magnet_field_timer_frames = 30.0
	controller.magnet_field_initial_timer_frames = 30.0
	controller.magnet_field_particle_accumulator_frames = 2.5
	controller.update(owner, 1.0 / 60.0)
	_expect(controller.magnet_field_active, "controller should keep magnet field active while helper timer remains")
	_expect(is_equal_approx(controller.magnet_field_timer_frames, 29.0), "controller should apply helper timer tick")
	_expect(is_equal_approx(controller.magnet_field_phase, 0.08), "controller should apply helper phase tick")
	_expect(controller.magnet_field_particles.size() == 1, "controller should still delegate active magnet particles")
	_expect(is_equal_approx(controller.magnet_field_particle_accumulator_frames, 0.5), "controller should keep particle accumulator result")

	controller.magnet_field_particles.append({"alpha": 1.0})
	controller.magnet_field_active = true
	controller.magnet_field_timer_frames = 1.0
	controller.magnet_field_initial_timer_frames = 30.0
	controller.magnet_field_phase = 5.0
	controller.magnet_field_particle_accumulator_frames = 2.5
	controller.update(owner, 1.0 / 60.0)
	_expect(not controller.magnet_field_active, "controller should apply helper expiry")
	_expect(is_equal_approx(controller.magnet_field_phase, 0.0), "controller should reset phase on helper clear")
	_expect(controller.magnet_field_particles.is_empty(), "controller should clear particles on helper clear")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
