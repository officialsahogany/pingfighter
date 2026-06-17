extends SceneTree

const BallImpactBoostPolicy := preload("res://scripts/ball/ball_impact_boost_policy.gd")
const BallPhysics := preload("res://scripts/ball/ball_physics.gd")
const BallSceneBridge := preload("res://scripts/ball/ball_scene_bridge.gd")
const BallSpeedPolicy := preload("res://scripts/ball/ball_speed_policy.gd")

const EXPECTED_JUNIOR_SPEED_RATIO := 0.85

var _failures: Array[String] = []


func _init() -> void:
	_verify_junior_speed_ratio()
	_verify_scene_bridge_fallback_normalizes_league_mode()

	if _failures.is_empty():
		print("junior_league_ball_speed_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_junior_speed_ratio() -> void:
	var policy := BallSpeedPolicy.new()
	var champion_context := {"ai_mode": "champion", "current_stage": 1}
	var junior_context := {"ai_mode": "junior", "current_stage": 1}
	_expect_close(
		policy.get_junior_ball_speed_multiplier(junior_context),
		EXPECTED_JUNIOR_SPEED_RATIO,
		"junior base ball speed should be 15 percent slower than champion"
	)
	_expect_close(
		policy.get_junior_speed_increase_multiplier(junior_context),
		EXPECTED_JUNIOR_SPEED_RATIO,
		"junior rally speed increase should be 15 percent slower than champion"
	)
	_expect_close(
		policy.get_minimum_rally_speed(junior_context) / policy.get_minimum_rally_speed(champion_context),
		EXPECTED_JUNIOR_SPEED_RATIO,
		"junior minimum rally speed should keep the 15 percent slowdown"
	)

	seed(12345)
	var champion_serve_speed: float = policy.build_serve_velocity(true, champion_context).length()
	seed(12345)
	var junior_serve_speed: float = policy.build_serve_velocity(true, junior_context).length()
	_expect_close(
		junior_serve_speed / champion_serve_speed,
		EXPECTED_JUNIOR_SPEED_RATIO,
		"junior serve velocity should be 85 percent of champion serve velocity"
	)

	var champion_physics := BallPhysics.new()
	champion_physics.configure_context(1, "champion")
	var junior_physics := BallPhysics.new()
	junior_physics.configure_context(1, "junior")
	_expect_close(
		junior_physics.get_junior_ball_speed_multiplier(),
		EXPECTED_JUNIOR_SPEED_RATIO,
		"ball physics should expose the junior base speed ratio"
	)
	_expect_close(
		junior_physics.get_junior_speed_increase_multiplier(),
		EXPECTED_JUNIOR_SPEED_RATIO,
		"ball physics should expose the junior rally speed increase ratio"
	)

	var champion_impact: Dictionary = champion_physics.compute_serve_launch_impact_boost(Vector2(0.0, -10.0))
	var junior_impact: Dictionary = junior_physics.compute_serve_launch_impact_boost(Vector2(0.0, -10.0))
	_expect_close(
		float(junior_impact.get("boost", 0.0)),
		float(champion_impact.get("boost", 0.0)),
		"junior serve impact boost should not add another hidden speed penalty"
	)
	_expect_close(
		BallImpactBoostPolicy.JUNIOR_IMPACT_BOOST_SCALE,
		1.0,
		"junior impact boost scale should preserve the configured 15 percent ball-speed ratio"
	)


func _verify_scene_bridge_fallback_normalizes_league_mode() -> void:
	var bridge := BallSceneBridge.new()
	var context: Dictionary = bridge.configure_physics_context(null, 1, "junior league")
	_expect(
		str(context.get("ai_mode", "")) == "junior",
		"ball scene bridge fallback should normalize league aliases without a physics module"
	)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)


func _expect_close(actual: float, expected: float, message: String) -> void:
	if abs(actual - expected) <= 0.0001:
		return
	_failures.append("%s: got %.6f expected %.6f" % [message, actual, expected])
