extends SceneTree

const CommandoFirearmBowlingTrapGeometry := preload("res://scripts/characters/commando_firearm_bowling_trap_geometry.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_bowling_trap_geometry()
	_verify_runtime_delegates_bowling_trap_geometry()

	if _failures.is_empty():
		print("commando_firearm_bowling_trap_geometry_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_bowling_trap_geometry() -> void:
	_expect(
		CommandoFirearmBowlingTrapGeometry.get_install_pos({}, 760.0, 750.0, 60.0, 20.0, 0.6) == Vector2(457.5, 735.0),
		"bowling-trap default install position should preserve legacy fallback geometry"
	)
	_expect(
		CommandoFirearmBowlingTrapGeometry.get_install_pos(
			{"player_pos": Vector2(10.0, 100.0), "paddle_width": 10.0, "paddle_height": 10.0},
			760.0,
			750.0,
			60.0,
			20.0,
			0.6
		) == Vector2(30.0, 450.0),
		"bowling-trap install position should clamp to field and minimum install row"
	)

	_expect(
		CommandoFirearmBowlingTrapGeometry.soften_guard_ball(Vector2.ZERO, 8.0) == Vector2(0.0, 8.0),
		"zero guard velocity should restore downward speed"
	)
	_expect(
		CommandoFirearmBowlingTrapGeometry.soften_guard_ball(Vector2(3.0, 4.0), 10.0) == Vector2(6.0, 8.0),
		"nonzero guard velocity should preserve direction and restore target speed"
	)

	_expect(
		is_equal_approx(CommandoFirearmBowlingTrapGeometry.get_guard_knockback_velocity(Vector2(200.0, 0.0), {}, 760.0, 22.0), 22.0),
		"left-side boss guard hit should knock right"
	)
	_expect(
		is_equal_approx(CommandoFirearmBowlingTrapGeometry.get_guard_knockback_velocity(Vector2(500.0, 0.0), {}, 760.0, 22.0), -22.0),
		"right-side boss guard hit should knock left"
	)
	_expect(
		is_equal_approx(CommandoFirearmBowlingTrapGeometry.get_guard_knockback_velocity(Vector2(380.0, 0.0), {"boss_vel": -3.0}, 760.0, 22.0), -22.0),
		"center boss guard hit should follow current boss velocity when available"
	)
	_expect(CommandoFirearmBowlingTrapGeometry.get_launch_direction(5) == -1, "shot id modulo 5 == 0 should launch left")
	_expect(CommandoFirearmBowlingTrapGeometry.get_launch_direction(9) == 1, "shot id modulo 5 == 4 should launch right")
	_expect(CommandoFirearmBowlingTrapGeometry.get_launch_direction(7) == 0, "middle modulo values should launch straight")

	var trap := {"pos": Vector2(100.0, 100.0), "width": 60.0}
	var hit_context := {"ball_pos": Vector2(100.0, 110.0), "ball_vel": Vector2(0.0, 5.0), "ball_size": 20.0}
	_expect(CommandoFirearmBowlingTrapGeometry.hits_ball(trap, hit_context, 20.0, 40.0, 60.0), "downward ball should hit overlapping bowling trap")
	_expect(
		not CommandoFirearmBowlingTrapGeometry.hits_ball(trap, {"ball_pos": Vector2(100.0, 110.0), "ball_vel": Vector2(0.0, -5.0), "ball_size": 20.0}, 20.0, 40.0, 60.0),
		"upward ball should not trigger bowling trap"
	)
	_expect(
		not CommandoFirearmBowlingTrapGeometry.hits_ball(trap, {"ball_pos": Vector2(240.0, 110.0), "ball_vel": Vector2(0.0, 5.0), "ball_size": 20.0}, 20.0, 40.0, 60.0),
		"non-overlapping downward ball should not hit bowling trap"
	)


func _verify_runtime_delegates_bowling_trap_geometry() -> void:
	var runtime := CommandoFirearmRuntime.new()
	_expect(runtime._get_bowling_trap_install_pos({}) == Vector2(457.5, 735.0), "runtime install-position wrapper should delegate")
	_expect(runtime._soften_bowling_trap_guard_ball(Vector2(3.0, 4.0), 10.0) == Vector2(6.0, 8.0), "runtime guard-soften wrapper should delegate")
	_expect(is_equal_approx(runtime._get_bowling_trap_guard_knockback_velocity(Vector2(500.0, 0.0), {}), -22.0), "runtime guard-knockback wrapper should delegate")
	_expect(runtime._get_bowling_trap_launch_direction(9) == 1, "runtime launch-direction wrapper should delegate")
	_expect(
		runtime._bowling_trap_hits_ball(
			{"pos": Vector2(100.0, 100.0), "width": 60.0},
			{"ball_pos": Vector2(100.0, 110.0), "ball_vel": Vector2(0.0, 5.0), "ball_size": 20.0}
		),
		"runtime trap-hit wrapper should delegate"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
