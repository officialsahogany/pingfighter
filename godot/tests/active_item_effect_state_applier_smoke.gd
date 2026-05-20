extends SceneTree

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemEffectStateApplier := preload("res://scripts/items/active_item_effect_state_applier.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_state_snapshot_application()
	_verify_clear_particle_flags()

	if _failures.is_empty():
		print("active_item_effect_state_applier_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_state_snapshot_application() -> void:
	var controller: Object = ActiveItemEffectController.new()
	var applier: Object = ActiveItemEffectStateApplier.new()

	applier.apply_aipill_state(controller, {"active": true, "phase": 1.5, "flash_timer_frames": 3.0})
	_expect(controller.aipill_active, "applier should set AI Pill active")
	_expect(is_equal_approx(controller.aipill_phase, 1.5), "applier should set AI Pill phase")

	applier.apply_long_boost_state(controller, {"active": true, "timer_frames": 10.0, "initial_timer_frames": 20.0, "scale": 1.25})
	_expect(controller.long_boost_active, "applier should set long boost active")
	_expect(is_equal_approx(controller.long_boost_scale, 1.25), "applier should set long boost scale")

	applier.apply_vitamin_pill_state(controller, {"active": true, "timer_frames": 30.0, "initial_timer_frames": 40.0, "phase": 2.0, "flash_timer_frames": 4.0, "player_center": Vector2(111.0, 222.0)})
	_expect(controller.vitamin_pill_active, "applier should set vitamin pill active")
	_expect(controller.vitamin_pill_player_center == Vector2(111.0, 222.0), "applier should set vitamin pill center")

	applier.apply_strange_vial_state(controller, {"active": true, "timer_frames": 50.0, "initial_timer_frames": 60.0, "effect_type": "shrink", "scale": 0.55, "target_scale": 0.55, "speed_multiplier": 1.35, "target_speed_multiplier": 1.35, "phase": 3.0, "flash_timer_frames": 5.0, "player_center": Vector2(222.0, 333.0)})
	_expect(controller.strange_vial_active, "applier should set strange vial active")
	_expect(str(controller.strange_vial_effect_type) == "shrink", "applier should set strange vial effect type")
	_expect(is_equal_approx(controller.strange_vial_speed_multiplier, 1.35), "applier should set strange vial speed")

	applier.apply_stopwatch_state(controller, {"active": true, "timer_frames": 70.0, "initial_timer_frames": 80.0, "recovery_timer_frames": 9.0, "original_ball_vel": Vector2(4.0, -5.0), "flash_timer_frames": 6.0, "clock_angle": 7.0})
	_expect(controller.stopwatch_active, "applier should set stopwatch active")
	_expect(controller.stopwatch_original_ball_vel == Vector2(4.0, -5.0), "applier should set stopwatch original velocity")

	applier.apply_brick_wall_installation_state(controller, {"installing": true, "timer_frames": 12.0, "initial_frames": 24.0, "pending_wall": {"rect": Rect2(Vector2(1.0, 2.0), Vector2(3.0, 4.0))}})
	_expect(controller.brick_wall_installing, "applier should set brick wall installing")
	_expect(not controller.pending_brick_wall.is_empty(), "applier should set pending brick wall")


func _verify_clear_particle_flags() -> void:
	var controller: Object = ActiveItemEffectController.new()
	var applier: Object = ActiveItemEffectStateApplier.new()

	controller.magnet_field_particles.append({"alpha": 1.0})
	applier.apply_magnet_field_state(controller, {"active": true, "timer_frames": 10.0, "initial_timer_frames": 20.0, "phase": 1.0, "player_center": Vector2(333.0, 444.0), "particle_accumulator_frames": 2.0, "clear_particles": true})
	_expect(controller.magnet_field_active, "applier should set magnet field active")
	_expect(controller.magnet_field_player_center == Vector2(333.0, 444.0), "applier should set magnet field center")
	_expect(controller.magnet_field_particles.is_empty(), "applier should clear magnet field particles on flag")

	controller.holy_barrier_particles.append({"alpha": 1.0})
	applier.apply_holy_barrier_state(controller, {"active": true, "timer_frames": 30.0, "initial_timer_frames": 40.0, "glow_phase": 3.0, "particle_accumulator_frames": 4.0, "clear_particles": true})
	_expect(controller.holy_barrier_active, "applier should set holy barrier active")
	_expect(is_equal_approx(controller.holy_barrier_glow_phase, 3.0), "applier should set holy barrier glow")
	_expect(controller.holy_barrier_particles.is_empty(), "applier should clear holy barrier particles on flag")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
