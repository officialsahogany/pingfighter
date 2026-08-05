extends SceneTree

const BallPhysics := preload("res://scripts/ball/ball_physics.gd")
const BallUpdateController := preload("res://scripts/ball/ball_update_controller.gd")
const PaddleBouncePowerHitHandler := preload("res://scripts/ball/paddle_bounce_power_hit_handler.gd")
const SmasherPowerSmashHitVelocityResolver := preload("res://scripts/characters/smasher_power_smash_hit_velocity_resolver.gd")
const SmasherPowerSmashState := preload("res://scripts/characters/smasher_power_smash_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_junior_power_smash_launch_speed_multiplier()
	_verify_junior_power_smash_speed_cap_multiplier()
	_verify_power_smash_combo_gate_uses_real_combo_for_launch_cap()

	if _failures.is_empty():
		print("junior_power_smash_tuning_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_junior_power_smash_launch_speed_multiplier() -> void:
	var champion_speed: float = _resolve_power_smash_launch_speed("champion")
	var junior_speed: float = _resolve_power_smash_launch_speed("junior")
	_expect(champion_speed > 0.0, "Champion power-smash launch should produce speed")
	_expect(
		is_equal_approx(junior_speed / champion_speed, 1.30),
		"Junior power-smash launch speed should be 30 percent higher than Champion"
	)


func _verify_junior_power_smash_speed_cap_multiplier() -> void:
	var controller: Object = BallUpdateController.new()
	var scene := {"ball_impact_boost": 1.0}
	var champion_cap: float = controller._get_power_smash_effective_speed_cap(
		scene,
		{"ai_mode": "champion", "power_smash_max_ball_speed": 35.0},
		{}
	)
	var junior_cap: float = controller._get_power_smash_effective_speed_cap(
		scene,
		{"ai_mode": "junior league", "power_smash_max_ball_speed": 35.0},
		{}
	)
	_expect(is_equal_approx(champion_cap, 35.0), "Champion power-smash speed cap should keep the base cap")
	_expect(is_equal_approx(junior_cap / champion_cap, 1.30), "Junior power-smash speed cap should be 30 percent higher")


func _resolve_power_smash_launch_speed(ai_mode: String) -> float:
	return _resolve_power_smash_launch_speed_with_combo(ai_mode, 0, 8.0)


func _resolve_power_smash_launch_speed_with_combo(ai_mode: String, combo_consumed: int, incoming_speed: float) -> float:
	var power_state: Object = SmasherPowerSmashState.new()
	power_state.begin_activation(0, 0.0, combo_consumed, 0.0, false, 0, 0.0)
	var physics: Object = BallPhysics.new()
	physics.configure_context(1, ai_mode)
	var handler: Object = PaddleBouncePowerHitHandler.new()
	var velocity: Vector2 = handler.apply(
		Vector2(380.0, 700.0),
		Vector2(0.0, -incoming_speed),
		155.0,
		true,
		power_state,
		physics,
		{
			"ai_mode": ai_mode,
			"player_pos": Vector2(302.5, 700.0),
			"paddle_width": 155.0,
			"base_ball_speed": BallPhysics.BALL_BASE_SPEED,
			"combo_min_count": 2,
			"ball_size": 28.6,
		}
	)
	return velocity.length()


func _verify_power_smash_combo_gate_uses_real_combo_for_launch_cap() -> void:
	var no_combo_speed: float = _resolve_power_smash_launch_speed_with_combo("champion", 0, 30.0)
	var combo_speed: float = _resolve_power_smash_launch_speed_with_combo("champion", 3, 30.0)
	var expected_no_combo_cap: float = BallPhysics.BALL_BASE_SPEED * SmasherPowerSmashHitVelocityResolver.POWER_SMASH_MAX_LAUNCH_SPEED_MULT
	var expected_combo_cap: float = BallPhysics.BALL_BASE_SPEED * SmasherPowerSmashHitVelocityResolver.POWER_SMASH_MAX_COMBO_LAUNCH_SPEED_MULT
	_expect(
		is_equal_approx(no_combo_speed, expected_no_combo_cap),
		"no-combo power-smash should clamp to the non-combo launch cap"
	)
	_expect(
		is_equal_approx(combo_speed, expected_combo_cap),
		"real combo power-smash should clamp to the combo launch cap"
	)
	_expect(
		combo_speed > no_combo_speed * 1.10,
		"real combo power-smash should keep a meaningful launch-speed spread"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
