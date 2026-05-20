extends SceneTree

const BallUpdateController := preload("res://scripts/ball/ball_update_controller.gd")
const SmasherPowerSmashMotionController := preload("res://scripts/characters/smasher_power_smash_motion_controller.gd")
const SmasherPowerSmashState := preload("res://scripts/characters/smasher_power_smash_state.gd")

var _failures: Array[String] = []


class FakeMotionStepper:
	extends RefCounted

	func step(ball_pos: Vector2, delta: Vector2, _ball_vel: Vector2, _context: Dictionary) -> Dictionary:
		return {
			"ball_pos": ball_pos + delta,
			"event": "none",
		}


func _init() -> void:
	_verify_ghost_shot_chaos_waits_for_height_gate()
	_verify_ghost_shot_releases_motion_skip_after_teleports()

	if _failures.is_empty():
		print("smasher_ghost_shot_motion_skip_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_ghost_shot_releases_motion_skip_after_teleports() -> void:
	var power_state: Object = SmasherPowerSmashState.new()
	power_state.begin_activation(0, 0.0, 0, 30.0, true, 1000)
	power_state.update_freeze(0.0, 0.0)
	_expect(power_state.is_ghost_shot_motion_active(), "test setup should start ghost shot motion")

	var context: Dictionary = _base_context()
	var deps: Dictionary = {
		"power_state": power_state,
		"power_motion_controller": SmasherPowerSmashMotionController.new(),
		"motion_stepper": FakeMotionStepper.new(),
	}
	var controller: Object = BallUpdateController.new()
	var saw_motion_skip := false
	var resumed_while_active := false
	var final_released := false
	var first_resume_pos := Vector2.ZERO

	for frame in range(280):
		context["current_msec"] = 1000 + int(float(frame) * 1000.0 / 60.0)
		var result: Dictionary = controller.update(1.0 / 60.0, context, deps)
		var snapshot: Variant = result.get("snapshot", {})
		if snapshot is Dictionary:
			context.merge(snapshot, true)

		var skipping: bool = bool(context.get("skip_ball_motion_step", false))
		if skipping:
			saw_motion_skip = true
		elif saw_motion_skip and power_state.is_ghost_shot_motion_active():
			resumed_while_active = true
			if first_resume_pos == Vector2.ZERO:
				first_resume_pos = _get_vector2(context, "ball_pos", Vector2.ZERO)

		if (
			saw_motion_skip
			and not skipping
			and not power_state.is_ghost_shot_motion_active()
			and _get_vector2(context, "ball_vel", Vector2.ZERO).length() >= 12.0
		):
			final_released = true
			break

	_expect(saw_motion_skip, "ghost shot should briefly own the ball motion step during teleports")
	_expect(resumed_while_active, "ghost shot should clear stale motion-skip after a performance teleport")
	_expect(final_released, "ghost shot final fire should clear motion-skip and restore real ball velocity")
	_expect(not bool(context.get("skip_ball_motion_step", true)), "ghost shot should not leave the shared motion-skip flag stuck on")
	_expect(first_resume_pos != Vector2.ZERO, "ghost shot should expose a real visible position after teleport resume")


func _base_context() -> Dictionary:
	return {
		"selected_character_type": "smasher",
		"ball_active": true,
		"ball_pos": Vector2(380.0, 520.0),
		"ball_vel": Vector2(2.0, -11.0),
		"ball_size": 28.6,
		"skip_ball_motion_step": false,
		"ball_impact_boost": 1.0,
		"ball_boost_decay_rate": 0.975,
		"ball_min_boost": 0.70,
		"player_collision_cooldown": 0.0,
		"boss_collision_cooldown": 0.0,
		"vertical_bounce_count": 0,
		"ball_spin_strength": 0.0,
		"ball_spin_direction": 0,
		"drive_ball_active": false,
		"drive_hit_boss": false,
		"drive_speed_increase": 0.0,
		"drive_text_timer_frames": 0.0,
		"special_gauge": 0.0,
		"player_speed": 0.0,
		"boss_vel": 0.0,
		"player_pos": Vector2(380.0, 700.0),
		"boss_pos": Vector2(380.0, 60.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"boss_paddle_size": Vector2(120.0, 40.0),
		"current_stage": 1,
		"max_ball_speed": 26.0,
		"power_smash_max_ball_speed": 35.0,
	}


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _verify_ghost_shot_chaos_waits_for_height_gate() -> void:
	var power_state: Object = SmasherPowerSmashState.new()
	power_state.begin_activation(0, 0.0, 0, 30.0, true, 2000)
	power_state.update_freeze(0.0, 0.0)

	var rise_result: Dictionary = power_state.apply_ghost_shot_motion(
		{"ball_pos": Vector2(380.0, 540.0), "ball_vel": Vector2.ZERO},
		1.0,
		{"current_msec": 2016, "boss_pos": Vector2(380.0, 60.0)},
		{}
	)
	var rise_vel: Vector2 = _get_vector2(rise_result, "ball_vel", Vector2.ZERO)
	_expect(is_equal_approx(rise_vel.y, -14.0), "ghost shot should keep rising before the y=500 chaos gate")
	_expect(not bool(rise_result.get("skip_ball_motion_step", true)), "ghost shot rise should keep normal ball motion active")

	var chaos_result: Dictionary = power_state.apply_ghost_shot_motion(
		{"ball_pos": Vector2(380.0, 500.0), "ball_vel": rise_vel},
		1.0,
		{"current_msec": 2033, "boss_pos": Vector2(380.0, 60.0)},
		{}
	)
	var chaos_vel: Vector2 = _get_vector2(chaos_result, "ball_vel", Vector2.ZERO)
	_expect(chaos_vel.length() >= 20.0, "ghost shot should enter fast chaos steering at the y=500 gate")
	_expect(not is_equal_approx(chaos_vel.y, -14.0), "ghost shot chaos gate should replace the straight rise velocity")
	_expect(not bool(chaos_result.get("skip_ball_motion_step", true)), "ghost shot chaos steering should keep normal ball motion active")
