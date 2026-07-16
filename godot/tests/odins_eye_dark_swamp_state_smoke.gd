extends SceneTree

const DarkSwampState := preload("res://scripts/items/odins_eye_dark_swamp_state.gd")
const FRAME_SEC := 1.0 / 60.0

var _failures: Array[String] = []


func _init() -> void:
	_verify_activation_gates_and_lifecycle()
	_verify_sequential_spawn_and_phases()
	_verify_full_playfield_spawn_clamp()
	_verify_ball_and_boss_collisions()
	_verify_phase_gate_and_cleanup()

	if _failures.is_empty():
		print("odins_eye_dark_swamp_state_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_activation_gates_and_lifecycle() -> void:
	var state: Object = DarkSwampState.new()
	state.set_random_seed(1107)
	_expect(not state.can_activate(100.0), "Dark Swamp must stay locked before revival finalize enable")
	state.enable()
	_expect(not state.can_activate(99.99), "Dark Swamp must require the full 100 gauge")
	state.set_activation_blocked(true, false)
	_expect(not state.can_activate(100.0), "revival animation must block Dark Swamp")
	state.set_activation_blocked(false, true)
	_expect(not state.can_activate(100.0), "death animation must block Dark Swamp")
	state.set_activation_blocked(false, false)
	_expect(state.can_activate(100.0), "finalized transformed Odin should activate at 100 gauge")
	_expect(
		not state.activate(Vector2(300.0, 700.0), Vector2(420.0, 50.0), 99.0),
		"failed activation must preserve state when gauge is insufficient"
	)
	_expect(
		state.activate(Vector2(300.0, 700.0), Vector2(420.0, 50.0)),
		"ready Dark Swamp should activate"
	)
	var context: Dictionary = state.get_context(150.0)
	_expect(context.get("path_start", Vector2.ZERO) == Vector2(300.0, 670.0), "path should start 30px above player center")
	_expect(context.get("path_end", Vector2.ZERO) == Vector2(420.0, 80.0), "path should end 30px below boss center")
	_expect_close(float(context.get("cooldown_remaining_frames", -1.0)), 120.0, "activation should start the 120-frame cooldown")
	_expect_close(float(state.consume_activation_gauge_cost()), 100.0, "activation should request exactly 100 gauge once")
	_expect_close(float(state.consume_activation_gauge_cost()), 0.0, "activation gauge request should be one-shot")
	_expect(not state.can_activate(999.0), "active Dark Swamp must reject reactivation")

	for _frame_index in range(8):
		state.update(FRAME_SEC)
	_expect(int(state.consume_spawned_spike_count()) == 1, "eight frames should publish one spike-spawn audio edge")
	state.reset_round()
	context = state.get_context(150.0)
	_expect(bool(context.get("enabled", false)), "round reset should preserve transformed Dark Swamp enable")
	_expect(not bool(context.get("active", true)), "round reset should clear the active hazard wave")
	_expect((context.get("spikes", []) as Array).is_empty(), "round reset should clear all spikes")
	_expect((context.get("fragments", []) as Array).is_empty(), "round reset should clear all fragments")
	_expect(float(context.get("cooldown_remaining_frames", 0.0)) > 0.0, "round reset should preserve the same-form cooldown")
	state.disable()
	context = state.get_context(150.0)
	_expect(not bool(context.get("enabled", true)), "disable should release Dark Swamp with Odin's penalty form")
	_expect_close(float(context.get("cooldown_remaining_frames", -1.0)), 0.0, "disable should clear cooldown")
	_expect(not state.has_runtime_update_work(), "disabled clean state should not keep the item update gate hot")


func _verify_sequential_spawn_and_phases() -> void:
	var state: Object = DarkSwampState.new()
	state.set_random_seed(2208)
	state.enable()
	_expect(state.activate(Vector2(380.0, 700.0), Vector2(380.0, 50.0)), "spawn smoke setup should activate")
	var spawn_frames: Array[int] = []
	var spawn_y_positions: Array[float] = []
	for frame_number in range(1, 97):
		state.update(FRAME_SEC)
		var spawned_count: int = int(state.consume_spawned_spike_count())
		if spawned_count <= 0:
			continue
		_expect(spawned_count == 1, "the 8-frame interval should spawn spikes sequentially, never in a burst")
		spawn_frames.append(frame_number)
		var context: Dictionary = state.get_context()
		var newest_id := int(context.get("spawned_spike_count", 0))
		var newest_spike := _find_spike_by_id(context.get("spikes", []) as Array, newest_id)
		_expect(not newest_spike.is_empty(), "spawned spike should be renderer-visible on its spawn frame")
		spawn_y_positions.append(float(newest_spike.get("y", 0.0)))
	_expect(spawn_frames.size() == 12, "one activation must spawn exactly 12 spikes")
	for spawn_index in range(spawn_frames.size()):
		_expect(spawn_frames[spawn_index] == (spawn_index + 1) * 8, "spike spawn frames must be 8,16,...,96")
		if spawn_index > 0:
			_expect(spawn_y_positions[spawn_index] < spawn_y_positions[spawn_index - 1], "spikes should advance from player toward boss")
	var full_context: Dictionary = state.get_context()
	_expect(int(full_context.get("spawned_spike_count", -1)) == 12, "spawn counter must stop at exactly 12")
	_expect(int(full_context.get("max_spikes", -1)) == 12, "renderer context should expose the 12-spike cap")
	_expect_close(float(full_context.get("wave_progress", 0.0)), 1.0, "wave progress should finish after 40 frames")

	# A separate activation seals the 10/35/15 phase clock without older spikes.
	state.disable()
	state.enable()
	state.set_random_seed(3309)
	state.activate(Vector2(380.0, 700.0), Vector2(380.0, 50.0))
	for _frame_index in range(8):
		state.update(FRAME_SEC)
	var spike := _find_spike_by_id(state.get_context().get("spikes", []) as Array, 1)
	_expect(str(spike.get("phase", "")) == "rising", "new spike should begin in rising phase")
	_expect(float(spike.get("height", 0.0)) >= 10.0, "new rising spike should expose collision height")
	for _frame_index in range(9):
		state.update(FRAME_SEC)
	spike = _find_spike_by_id(state.get_context().get("spikes", []) as Array, 1)
	_expect(str(spike.get("phase", "")) == "hold", "spike should enter hold after 10 update frames")
	for _frame_index in range(35):
		state.update(FRAME_SEC)
	spike = _find_spike_by_id(state.get_context().get("spikes", []) as Array, 1)
	_expect(str(spike.get("phase", "")) == "falling", "spike should enter falling after 35 hold frames")
	for _frame_index in range(15):
		state.update(FRAME_SEC)
	spike = _find_spike_by_id(state.get_context().get("spikes", []) as Array, 1)
	_expect(spike.is_empty(), "spike should be removed after 15 falling frames")


func _verify_ball_and_boss_collisions() -> void:
	var state: Object = DarkSwampState.new()
	state.set_random_seed(4410)
	state.enable()
	state.activate(Vector2(380.0, 700.0), Vector2(380.0, 50.0))
	for _frame_index in range(8):
		state.update(FRAME_SEC)
	var spike_one := _find_spike_by_id(state.get_context().get("spikes", []) as Array, 1)
	var spike_one_rect := _ball_rect_inside_spike(spike_one, 0.0)
	var fast_result: Dictionary = state.check_ball_collision(spike_one_rect, Vector2(4.0, 0.0))
	_expect(bool(fast_result.get("hit", false)), "fast ball should collide with a rising spike")
	_expect(bool(fast_result.get("consumed", false)), "ball hit result should confirm the spike was consumed")
	_expect(int(fast_result.get("spike_id", -1)) == 1, "ball collision should identify the consumed spike")
	_expect(fast_result.get("impact_pos", Vector2.ZERO) is Vector2, "ball collision should publish an impact position")
	var fast_velocity := Vector2(fast_result.get("new_velocity", Vector2.ZERO))
	_expect(fast_velocity.y < 0.0, "fast spike rebound must point upward toward the boss")
	_expect(fast_velocity.length() >= 14.0 and fast_velocity.length() <= 17.001, "fast spike rebound should use min speed 10 and 1.4-1.7x boost")
	_expect(not bool(fast_result.get("used_fallback", true)), "fast ball should use angle-based rebound")
	var repeat_boss_rect := Rect2(Vector2(float(spike_one.get("x", 0.0)) - 20.0, float(spike_one.get("y", 0.0)) - float(spike_one.get("height", 0.0)) - 8.0), Vector2(40.0, 18.0))
	_expect(not bool(state.check_boss_collision(repeat_boss_rect).get("hit", false)), "a ball-consumed spike must not hit the boss in the same lifetime")

	for _frame_index in range(9):
		state.update(FRAME_SEC)
	var spike_two := _find_spike_by_id(state.get_context().get("spikes", []) as Array, 2)
	var boss_rect := Rect2(
		Vector2(float(spike_two.get("x", 0.0)) - 5.0, float(spike_two.get("y", 0.0)) - float(spike_two.get("height", 0.0)) - 8.0),
		Vector2(40.0, 16.0)
	)
	var boss_result: Dictionary = state.check_boss_collision(boss_rect)
	_expect(bool(boss_result.get("hit", false)), "boss tip should collide with a tall rising spike")
	_expect(bool(boss_result.get("consumed", false)), "boss hit result should confirm the spike was consumed")
	_expect(int(boss_result.get("spike_id", -1)) == 2, "boss collision should identify the consumed spike")
	_expect(int(boss_result.get("knockback_direction", 0)) == 1, "boss should be knocked away to the right when spike is left of its center")
	_expect_close(float(boss_result.get("knockback_power", 0.0)), 25.0, "boss collision should apply 25 knockback power")
	_expect(int(boss_result.get("knockback_timer_frames", 0)) == 24, "boss collision should publish the 24-frame knockback timer")
	_expect(int(boss_result.get("stun_duration_frames", 0)) == 60, "boss collision should publish a 60-frame stun")
	var boss_status: Dictionary = state.get_context()
	_expect_close(float(boss_status.get("boss_stun_timer_frames", 0.0)), 60.0, "boss collision should latch the 60-frame stun in state")
	_expect_close(float(boss_status.get("boss_knockback_timer_frames", 0.0)), 24.0, "boss collision should latch the 24-frame knockback in state")
	_expect_close(float(boss_status.get("boss_knockback_vel", 0.0)), 25.0, "boss collision should latch signed px/frame knockback velocity")
	state.update(FRAME_SEC)
	boss_status = state.get_context()
	# Python parity: CC timers consume SEQUENTIALLY — the knockback branch
	# returns before the stun branch for its 24 frames (pingfighter.py:178178
	# vs :178654), so the stun timer stays frozen at 60 while the knockback
	# timer drains.
	_expect_close(float(boss_status.get("boss_stun_timer_frames", 0.0)), 60.0, "boss stun timer must stay frozen while the knockback window drains")
	_expect_close(float(boss_status.get("boss_knockback_timer_frames", 0.0)), 23.0, "boss knockback timer should decrement once per virtual frame")
	_expect(absf(float(boss_status.get("boss_knockback_vel", 0.0))) < 25.0, "boss knockback velocity should decay per virtual frame")
	_expect(not bool(state.check_ball_collision(_ball_rect_inside_spike(spike_two, 0.0), Vector2(8.0, 0.0)).get("hit", false)), "a boss-consumed spike must not hit the ball")

	for _frame_index in range(8):
		state.update(FRAME_SEC)
	var spike_three := _find_spike_by_id(state.get_context().get("spikes", []) as Array, 3)
	var slow_result: Dictionary = state.check_ball_collision(_ball_rect_inside_spike(spike_three, -2.0), Vector2(3.0, 0.0))
	_expect(bool(slow_result.get("hit", false)), "slow ball should collide with a rising spike")
	_expect(bool(slow_result.get("used_fallback", false)), "speed 3 should use fallback impulse")
	_expect(Vector2(slow_result.get("new_velocity", Vector2.ZERO)) == Vector2(-5.0, -12.0), "slow fallback should be -/+5 x and -12 y in px/frame")
	_expect(not (state.get_context().get("fragments", []) as Array).is_empty(), "a consumed spike should publish renderable fragments")


func _verify_phase_gate_and_cleanup() -> void:
	var state: Object = DarkSwampState.new()
	state.set_random_seed(5511)
	state.enable()
	state.activate(Vector2(380.0, 700.0), Vector2(380.0, 50.0))
	for _frame_index in range(52):
		state.update(FRAME_SEC)
	var first_spike := _find_spike_by_id(state.get_context().get("spikes", []) as Array, 1)
	_expect(str(first_spike.get("phase", "")) == "falling", "phase-gate setup should reach falling")
	var falling_result: Dictionary = state.check_ball_collision(_ball_rect_inside_spike(first_spike, 0.0), Vector2(8.0, 0.0))
	_expect(not bool(falling_result.get("hit", false)), "falling spikes must not collide")

	for _frame_index in range(220):
		state.update(FRAME_SEC)
	var context: Dictionary = state.get_context()
	_expect(int(context.get("spawned_spike_count", -1)) == 12, "long update must still cap total spawned spikes at 12")
	_expect((context.get("spikes", []) as Array).is_empty(), "all natural spikes should clean up")
	_expect((context.get("fragments", []) as Array).is_empty(), "all fragments should clean up")
	_expect_close(float(context.get("cooldown_remaining_frames", -1.0)), 0.0, "cooldown should expire after 120 virtual frames")
	_expect(not bool(context.get("active", true)), "Dark Swamp should finish after its last transient")
	_expect(not state.has_runtime_update_work(), "idle enabled skill should release the item update gate")
	_expect(state.can_activate(100.0), "finished Dark Swamp should become ready again")
	state.disable()
	context = state.get_context()
	_expect_close(float(context.get("boss_stun_timer_frames", -1.0)), 0.0, "disable should clear boss stun state")
	_expect_close(float(context.get("boss_knockback_timer_frames", -1.0)), 0.0, "disable should clear boss knockback timer")
	_expect_close(float(context.get("boss_knockback_vel", -1.0)), 0.0, "disable should clear boss knockback velocity")


func _verify_full_playfield_spawn_clamp() -> void:
	var left_state: Object = DarkSwampState.new()
	left_state.set_random_seed(6612)
	left_state.enable()
	left_state.activate(Vector2(0.0, 700.0), Vector2(0.0, 50.0))
	for _frame_index in range(8):
		left_state.update(FRAME_SEC)
	var left_spike := _find_spike_by_id(left_state.get_context().get("spikes", []) as Array, 1)
	_expect_close(float(left_spike.get("x", -1.0)), 18.0, "left-edge spike should use the full Godot playfield margin, not legacy x=100")

	var right_state: Object = DarkSwampState.new()
	right_state.set_random_seed(7713)
	right_state.enable()
	right_state.activate(Vector2(760.0, 700.0), Vector2(760.0, 50.0))
	for _frame_index in range(16):
		right_state.update(FRAME_SEC)
	var right_spike := _find_spike_by_id(right_state.get_context().get("spikes", []) as Array, 2)
	_expect_close(float(right_spike.get("x", -1.0)), 742.0, "right-edge spike should use the full Godot playfield margin, not legacy x=660")


func _find_spike_by_id(spikes: Array, spike_id: int) -> Dictionary:
	for spike_value in spikes:
		var spike := spike_value as Dictionary
		if int(spike.get("id", -1)) == spike_id:
			return spike
	return {}


func _ball_rect_inside_spike(spike: Dictionary, center_x_offset: float) -> Rect2:
	var center := Vector2(
		float(spike.get("x", 0.0)) + center_x_offset,
		float(spike.get("y", 0.0)) - float(spike.get("height", 0.0)) * 0.5
	)
	return Rect2(center - Vector2(4.0, 4.0), Vector2(8.0, 8.0))


func _expect_close(actual: float, expected: float, message: String, tolerance: float = 0.001) -> void:
	_expect(absf(actual - expected) <= tolerance, "%s (got %.4f, expected %.4f)" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
