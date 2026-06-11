extends SceneTree

const Stage2QuakeBallMotionState := preload("res://scripts/stages/stage2/stage2_quake_ball_motion_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_impulse_scale()
	_verify_player_pull()
	_verify_original_speed_cap()
	_verify_boss_launch_guard()
	_verify_background_delegates_quake_ball_motion()

	if _failures.is_empty():
		print("stage2_quake_ball_motion_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_impulse_scale() -> void:
	_expect(is_equal_approx(Stage2QuakeBallMotionState.get_impulse_scale(0.10), 1.0), "early quake impulse should keep full strength")
	_expect(is_equal_approx(Stage2QuakeBallMotionState.get_impulse_scale(0.45), 0.89), "mid quake impulse should ease down")
	_expect(is_equal_approx(Stage2QuakeBallMotionState.get_impulse_scale(1.0), 0.0), "late quake impulse should fade out")


func _verify_player_pull() -> void:
	var pulled: Vector2 = Stage2QuakeBallMotionState.apply_player_pull(
		Vector2.ZERO,
		Vector2.ZERO,
		{
			"player_pos": Vector2(90.0, 90.0),
			"player_paddle_size": Vector2(20.0, 20.0),
		}
	)
	_expect(pulled.length() > 0.0, "distant player paddle should apply a small pull")
	_expect(is_equal_approx(pulled.x, pulled.y), "player pull should follow the center delta direction")
	var unchanged: Vector2 = Stage2QuakeBallMotionState.apply_player_pull(
		Vector2(1.0, 2.0),
		Vector2(100.0, 100.0),
		{
			"player_pos": Vector2(90.0, 90.0),
			"player_paddle_size": Vector2(20.0, 20.0),
		}
	)
	_expect(unchanged == Vector2(1.0, 2.0), "nearby player paddle should not add pull jitter")


func _verify_original_speed_cap() -> void:
	var scene := {
		"ball_impact_boost": 2.0,
		"max_ball_speed": 20.0,
		"impact_boost_max_ball_speed": 19.0,
	}
	var capped: Vector2 = Stage2QuakeBallMotionState.apply_original_speed_cap(scene, Vector2(10.0, 0.0), 5.0)
	_expect(capped.is_equal_approx(Vector2(2.5, 0.0)), "speed cap should account for impact boost")
	_expect(is_equal_approx(float(scene.get("max_ball_speed", 0.0)), 5.0), "speed cap should clamp scene max ball speed")
	_expect(is_equal_approx(float(scene.get("impact_boost_max_ball_speed", 0.0)), 5.0), "speed cap should clamp impact-boost max speed")


func _verify_boss_launch_guard() -> void:
	var scene := {"ball_pos": Vector2(120.0, 40.0)}
	var result: Dictionary = Stage2QuakeBallMotionState.apply_boss_launch_guard(
		scene,
		{
			"ball_size": 28.6,
			"boss_pos": Vector2(100.0, 30.0),
			"boss_hitbox_height": 40.0,
		},
		Vector2(1.0, 1.0),
		2.0,
		0.5,
		20.0,
		true,
		9.0
	)
	var guarded_vel: Vector2 = result.get("ball_vel", Vector2.ZERO)
	var guarded_pos: Vector2 = scene.get("ball_pos", Vector2.ZERO)
	_expect(guarded_pos.y > 90.0, "boss launch guard should move ball below the boss safety band")
	_expect(is_equal_approx(guarded_vel.y, 9.0), "boss launch guard should derive minimum down speed from backup velocity")
	_expect(float(result.get("guard_timer", 0.0)) < 0.5, "boss launch guard should decay timer by frame scale")

	# Displaced-boss regression (lingpet puppet grab): the guard must anchor to
	# the HOME boss_y, not clamp the ball below a mid-field boss into the
	# player's floor band.
	var displaced_scene := {"ball_pos": Vector2(120.0, 40.0)}
	var displaced_result: Dictionary = Stage2QuakeBallMotionState.apply_boss_launch_guard(
		displaced_scene,
		{
			"ball_size": 28.6,
			"boss_pos": Vector2(100.0, 634.0),
			"boss_hitbox_height": 40.0,
			"boss_y": 25.0,
		},
		Vector2(1.0, 1.0),
		2.0,
		0.5,
		20.0,
		true,
		9.0
	)
	var displaced_pos: Vector2 = displaced_scene.get("ball_pos", Vector2.ZERO)
	var displaced_vel: Vector2 = displaced_result.get("ball_vel", Vector2.ZERO)
	_expect(
		displaced_pos.y > 80.0 and displaced_pos.y < 120.0,
		"boss launch guard must anchor to the home top band while the boss is displaced mid-field"
	)
	_expect(is_equal_approx(displaced_vel.y, 9.0), "displaced-boss guard should keep the minimum down speed behavior")


func _verify_background_delegates_quake_ball_motion() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_pillar_background.gd")
	_expect(
		source.find("Stage2QuakeBallMotionState.get_impulse_scale") >= 0,
		"Stage 2 background source should call quake impulse scale helper directly"
	)
	_expect(
		source.find("Stage2QuakeBallMotionState.apply_player_pull") >= 0,
		"Stage 2 background source should call quake player-pull helper directly"
	)
	_expect(
		source.find("Stage2QuakeBallMotionState.apply_original_speed_cap") >= 0,
		"Stage 2 background source should call quake speed-cap helper directly"
	)
	_expect(
		source.find("Stage2QuakeBallMotionState.apply_boss_launch_guard") >= 0,
		"Stage 2 background source should keep boss launch guard delegated"
	)
	_expect(
		source.find("func _get_quake_impulse_scale") < 0
		and source.find("func _apply_quake_player_pull") < 0
		and source.find("func _apply_quake_original_speed_cap") < 0,
		"Stage 2 background source should not keep quake ball pass-through wrappers"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
