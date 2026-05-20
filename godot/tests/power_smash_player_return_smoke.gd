extends SceneTree

const PaddleBounceController := preload("res://scripts/ball/paddle_bounce_controller.gd")
const SmasherPowerSmashState := preload("res://scripts/characters/smasher_power_smash_state.gd")

var _failures: Array[String] = []


class FakePaddleBounceState:
	extends RefCounted

	func get_initial_speed(ball_velocity: Vector2) -> float:
		return ball_velocity.length()

	func resolve_velocity(
		_ball_velocity: Vector2,
		_hit_pos: float,
		is_player: bool,
		_incoming_dx: float,
		_outgoing_direction: float,
		speed: float,
		_angle_rad: float,
		_drive_activated: bool,
		_accel_scale: float,
		vertical_bounce_count: int,
		_physics: Object,
		_drive_bounce_state: Object,
		drive_speed_increase: float,
		ball_spin_strength: float,
		_min_ball_speed: float,
		_max_ball_speed: float
	) -> Dictionary:
		return {
			"ball_vel": Vector2(0.0, -max(8.0, speed)) if is_player else Vector2(0.0, max(8.0, speed)),
			"vertical_bounce_count": vertical_bounce_count,
			"drive_speed_increase": drive_speed_increase,
			"ball_spin_strength": ball_spin_strength,
		}


func _init() -> void:
	_verify_player_return_clears_power_smash_gravity()

	if _failures.is_empty():
		print("power_smash_player_return_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_player_return_clears_power_smash_gravity() -> void:
	var power_state: Object = SmasherPowerSmashState.new()
	power_state.begin_activation(0, 0.0, 0, 30.0, false, 1000)
	power_state.update_freeze(0.0, 0.0)
	_expect(power_state.is_parabola_active(), "test setup should start power-smash parabola motion")

	var controller: Object = PaddleBounceController.new()
	var result: Dictionary = controller.bounce(
		300.0,
		100.0,
		true,
		{
			"selected_character_type": "smasher",
			"ball_active": true,
			"ball_pos": Vector2(350.0, 686.0),
			"ball_vel": Vector2(1.5, 11.0),
			"ball_size": 28.6,
			"player_pos": Vector2(300.0, 700.0),
			"player_y": 700.0,
			"paddle_width": 100.0,
			"paddle_height": 50.0,
			"max_bounce_angle": 60.0,
			"min_ball_speed": 3.0,
			"max_ball_speed": 26.0,
			"base_ball_speed": 8.0,
			"special_gauge": 0.0,
		},
		{
			"paddle_bounce_state": FakePaddleBounceState.new(),
			"power_state": power_state,
		}
	)

	var bounced_velocity: Vector2 = result.get("ball_vel", Vector2.ZERO)
	_expect(bounced_velocity.y < 0.0, "player return hit should relaunch the ball upward")
	_expect(not power_state.is_parabola_active(), "player return hit should clear stale power-smash parabola motion")

	var after_motion: Vector2 = power_state.apply_motion(bounced_velocity, 1.0, 99.0, 0.5)
	_expect(after_motion == bounced_velocity, "cleared power-smash state should not keep applying gravity after the player hit")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
