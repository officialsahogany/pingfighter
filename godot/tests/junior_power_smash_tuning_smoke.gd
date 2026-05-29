extends SceneTree

const BallPhysics := preload("res://scripts/ball/ball_physics.gd")
const BallUpdateController := preload("res://scripts/ball/ball_update_controller.gd")
const PaddleBouncePowerHitHandler := preload("res://scripts/ball/paddle_bounce_power_hit_handler.gd")
const SmasherPowerSmashState := preload("res://scripts/characters/smasher_power_smash_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_junior_power_smash_launch_speed_multiplier()
	_verify_junior_power_smash_speed_cap_multiplier()

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
	var power_state: Object = SmasherPowerSmashState.new()
	power_state.begin_activation(0, 0.0, 0, 0.0, false, 0, 0.0)
	var physics: Object = BallPhysics.new()
	physics.configure_context(1, ai_mode)
	var handler: Object = PaddleBouncePowerHitHandler.new()
	var velocity: Vector2 = handler.apply(
		Vector2(380.0, 700.0),
		Vector2(0.0, -8.0),
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


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
