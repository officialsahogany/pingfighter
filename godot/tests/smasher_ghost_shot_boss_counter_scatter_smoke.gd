extends SceneTree

const SmasherPowerSmashState := preload("res://scripts/characters/smasher_power_smash_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_boss_counter_during_rise_phase_clears_visuals()

	if _failures.is_empty():
		print("smasher_ghost_shot_boss_counter_scatter_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_boss_counter_during_rise_phase_clears_visuals() -> void:
	var power_state: Object = SmasherPowerSmashState.new()
	power_state.begin_activation(0, 0.0, 0, 30.0, true, 1000)
	power_state.update_freeze(0.0, 0.0)
	_expect(power_state.is_ghost_shot_motion_active(), "test setup should start ghost shot motion")
	_expect(power_state.is_ghost_shot_active(), "test setup should mark ghost state active")

	var rise_pos := Vector2(380.0, 520.0)
	var ball_size := 28.6
	power_state.update_effects(1.0, rise_pos, true, ball_size)
	_expect(power_state.has_ghost_shot_visible_aura(), "rise phase should expose the visible aura")
	var trajectory_during_rise: int = power_state.get_ghost_shot_trajectory_points().size()
	_expect(trajectory_during_rise > 0, "rise phase should emit at least one trajectory point")

	var counter_origin := Vector2(380.0, 90.0)
	power_state.finish_after_boss_counter(counter_origin)

	_expect(not power_state.is_ghost_shot_active(), "boss counter must clear ghost-shot active state")
	_expect(not power_state.is_ghost_shot_motion_active(), "boss counter must clear ghost-shot motion-active state")
	_expect(not power_state.has_ghost_shot_visible_aura(), "boss counter must hide the lingering ghost-shot aura")
	_expect(not power_state.has_ghost_shot_pending_teleport(), "boss counter must drop any pending teleport")

	# Simulate the boss returning the ball downward into player territory.
	# With active cleared, no new trajectory points should be appended along
	# the return trip, but existing ones still fade out naturally.
	var return_pos := counter_origin
	var return_vel := Vector2(0.0, 12.0)
	var trajectory_before_return: int = power_state.get_ghost_shot_trajectory_points().size()
	for _i in range(12):
		return_pos += return_vel
		power_state.update_effects(1.0, return_pos, true, ball_size)
	var trajectory_after_return: int = power_state.get_ghost_shot_trajectory_points().size()
	_expect(
		trajectory_after_return <= trajectory_before_return,
		"boss counter must stop appending new ghost trajectory points along the return trip"
	)

	# Let the scatter ghosts age out (scatter window is 42 frames).
	for _i in range(60):
		return_pos += return_vel
		power_state.update_effects(1.0, return_pos, true, ball_size)
	_expect(
		power_state.get_ghost_shot_ghosts().is_empty(),
		"scatter ghosts must fully clear after their decay window"
	)
	_expect(
		not power_state.has_visible_effects(),
		"all ghost-shot visuals must be gone once scatter and trajectory have faded"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
