extends SceneTree

const Stage2PillarBackground := preload("res://scripts/stages/stage2/stage2_pillar_background.gd")
const Stage2QuakeBallMotionState := preload("res://scripts/stages/stage2/stage2_quake_ball_motion_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_impulse_scale()
	_verify_player_pull()
	_verify_original_speed_cap()
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


func _verify_background_delegates_quake_ball_motion() -> void:
	var background := Stage2PillarBackground.new()
	_expect(
		is_equal_approx(background._get_quake_impulse_scale(0.45), Stage2QuakeBallMotionState.get_impulse_scale(0.45)),
		"Stage 2 background should delegate quake impulse scale"
	)
	var source: String = FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_pillar_background.gd")
	_expect(
		source.find("Stage2QuakeBallMotionState.apply_original_speed_cap") >= 0,
		"Stage 2 background source should keep quake speed cap delegated"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
