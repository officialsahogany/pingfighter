extends SceneTree

const BallFrameMotionController := preload("res://scripts/ball/ball_frame_motion_controller.gd")
const BallPhysics := preload("res://scripts/ball/ball_physics.gd")
const BallSpeedPolicy := preload("res://scripts/ball/ball_speed_policy.gd")
const BallUpdateContext := preload("res://scripts/ball/ball_update_context.gd")
const BattleDrawBallContext := preload("res://scripts/core/battle_draw_ball_context.gd")
const PaddleBounceEventRouter := preload("res://scripts/ball/paddle_bounce_event_router.gd")
const PaddleBounceVelocityStep := preload("res://scripts/ball/paddle_bounce_velocity_step.gd")
const WeatherEventState := preload("res://scripts/stages/common/weather_event_state.gd")

class FakeOwner:
	var battle_textures: Dictionary = {}
	var current_stage := 1
	var ai_mode := "mythic"
	var arena_mode_enabled := false
	var weather_type := "fire"
	var weather_event_active := true
	var ball_pos := Vector2(380.0, 500.0)
	var ball_vel := Vector2(0.0, -60.0)
	var ball_active := true
	var player_pos := Vector2(300.0, 700.0)
	var boss_pos := Vector2(330.0, 25.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var special_gauge_max := 500.0


class FakePhysics:
	func enforce_minimum_rally_speed(velocity: Vector2) -> Vector2:
		return velocity

	func get_minimum_effective_boost(_velocity: Vector2) -> float:
		return 1.0


class FakeBounceState:
	var captured_max_speed := 0.0

	func resolve_velocity(
		_ball_velocity: Vector2,
		_hit_pos: float,
		_is_player: bool,
		_incoming_dx: float,
		_outgoing_direction: float,
		speed: float,
		_angle_rad: float,
		_drive_activated: bool,
		_accel_scale: float,
		_vertical_bounce_count: int,
		_ball_physics: Object,
		_drive_bounce_state: Object,
		_current_drive_speed_increase: float,
		_current_spin_strength: float,
		_min_ball_speed: float,
		max_ball_speed: float
	) -> Dictionary:
		captured_max_speed = max_ball_speed
		return {
			"ball_vel": Vector2(0.0, -speed),
			"vertical_bounce_count": 0,
			"drive_speed_increase": 0.0,
			"ball_spin_strength": 0.0,
		}


class FakeMovementState:
	var call_count := 0
	var last_velocity := 0.0
	var last_frames := 0.0
	var last_decay := 0.0
	var last_replace_current := false
	var last_cleansable := true

	func start_knockback(
		velocity: float,
		frames: float = 18.0,
		decay_per_frame: float = 0.92,
		replace_current: bool = false,
		cleansable: bool = true
	) -> bool:
		call_count += 1
		last_velocity = velocity
		last_frames = frames
		last_decay = decay_per_frame
		last_replace_current = replace_current
		last_cleansable = cleansable
		return true


class FakeAiState:
	var call_count := 0
	var last_velocity := 0.0
	var last_frames := 0.0
	var last_decay := 0.0
	var last_replace_current := false

	func start_paddle_hit_knockback(
		velocity: float,
		frames: float = 36.0,
		decay_per_frame: float = 0.85,
		replace_current: bool = true
	) -> void:
		call_count += 1
		last_velocity = velocity
		last_frames = frames
		last_decay = decay_per_frame
		last_replace_current = replace_current


func _init() -> void:
	_verify_fire_rally_speed_multiplier()
	_verify_fire_update_context_uses_35_speed_cap()
	_verify_frame_motion_respects_fire_35_speed_cap()
	_verify_paddle_bounce_uses_fire_35_speed_cap()
	_verify_fire_hit_boost_is_doubled()
	_verify_fire_paddle_hit_knockback_matches_original_strength()
	_verify_fire_suppresses_default_paddle_recoil()
	_verify_fire_draw_context_enables_burning_ball()
	print("fire_weather_ball_speed_rules_smoke: ok")
	quit(0)


func _verify_fire_rally_speed_multiplier() -> void:
	var policy := BallSpeedPolicy.new()
	var normal_scale: float = policy.get_rally_speed_increase_multiplier({})
	var fire_scale: float = policy.get_rally_speed_increase_multiplier({
		"weather_active": true,
		"weather_type": "fire",
	})
	_expect(is_equal_approx(fire_scale, normal_scale * 2.0), "fire weather should double the normal rally speed increase scale")

	var physics := BallPhysics.new()
	physics.configure_context(1, "champion", false, "fire")
	_expect(is_equal_approx(float(physics.get_rally_speed_increase_multiplier()), normal_scale * 2.0), "ball physics should inherit the fire rally speed multiplier")


func _verify_fire_update_context_uses_35_speed_cap() -> void:
	var owner := FakeOwner.new()
	var context: Dictionary = BallUpdateContext.new().build_update_context(owner)
	_expect(not bool(context.get("speed_limit_disabled", false)), "fire weather should keep frame speed limits enabled")
	_expect(is_equal_approx(float(context.get("max_ball_speed", 0.0)), 35.0), "fire weather should raise the max ball speed cap to 35")
	_expect(is_equal_approx(float(context.get("impact_boost_max_ball_speed", 0.0)), 35.0), "fire weather should cap impact-boosted ball speed at 35")
	_expect(is_equal_approx(float(context.get("fire_weather_max_ball_speed", 0.0)), 35.0), "fire weather cap should be exposed in the update context")
	_expect(bool(context.get("fire_weather_speed_cap_active", false)), "fire weather should mark the 35 cap as active")


func _verify_frame_motion_respects_fire_35_speed_cap() -> void:
	var motion := BallFrameMotionController.new()
	var capped_scene := {
		"ball_vel": Vector2(60.0, 0.0),
		"ball_impact_boost": 1.0,
		"max_ball_speed": 26.0,
		"impact_boost_max_ball_speed": 26.0,
		"speed_limit_disabled": false,
	}
	motion.apply_ball_speed_limits(capped_scene, {"ball_physics": FakePhysics.new()})
	_expect(_get_vec(capped_scene, "ball_vel").length() <= 26.01, "normal frame motion should still cap ball speed")

	var fire_scene := {
		"ball_vel": Vector2(60.0, 0.0),
		"ball_impact_boost": 1.0,
		"max_ball_speed": 35.0,
		"impact_boost_max_ball_speed": 35.0,
		"fire_weather_max_ball_speed": 35.0,
		"fire_weather_speed_cap_active": true,
		"smasher_wheel_speed_cap": 60.0,
		"speed_limit_disabled": false,
	}
	motion.apply_ball_speed_limits(fire_scene, {"ball_physics": FakePhysics.new()})
	_expect(_get_vec(fire_scene, "ball_vel").length() <= 35.01, "fire frame motion should clamp ball speed to 35 even when another cap is higher")


func _verify_paddle_bounce_uses_fire_35_speed_cap() -> void:
	var weather := WeatherEventState.new()
	weather.force_start_weather_event("fire", 1, 1, null, null)
	var step := PaddleBounceVelocityStep.new()
	var bounce_state := FakeBounceState.new()
	var result: Dictionary = step.apply(
		bounce_state,
		null,
		Vector2(0.0, -60.0),
		0.0,
		true,
		0.0,
		-1.0,
		60.0,
		0.0,
		false,
		{
			"accel_scale": 1.0,
			"vertical_bounce_count": 0,
			"drive_speed_increase": 0.0,
			"ball_spin_strength": 0.0,
		},
		null,
		{"weather_event_state": weather},
		{
			"min_ball_speed": 3.0,
			"max_ball_speed": 26.0,
			"fire_weather_max_ball_speed": 35.0,
		}
	)
	_expect(is_equal_approx(bounce_state.captured_max_speed, 35.0), "fire paddle bounce should pass the 35 max speed cap")
	_expect(_get_vec(result, "ball_vel").length() <= 35.01, "fire hit speed boost should be clamped back to 35 after the boost")


func _verify_fire_hit_boost_is_doubled() -> void:
	var weather := WeatherEventState.new()
	weather.force_start_weather_event("fire", 1, 1, null, null)
	var boosted: Vector2 = weather.apply_fire_hit_speed(Vector2(0.0, -10.0))
	_expect(boosted.length() > 10.5, "fire hit speed boost should exceed the old 5-7 percent range")


func _verify_fire_paddle_hit_knockback_matches_original_strength() -> void:
	var weather := WeatherEventState.new()
	weather.force_start_weather_event("fire", 1, 1, null, null)
	var movement := FakeMovementState.new()
	var player_result: Dictionary = weather.apply_fire_paddle_hit_knockback(
		true,
		Vector2(380.0, 690.0),
		{},
		{"movement_state": movement}
	)
	_expect(bool(player_result.get("applied", false)), "fire player paddle hit should apply weather knockback")
	_expect(movement.call_count == 1, "fire player paddle hit should route to player movement knockback")
	_expect(is_equal_approx(abs(movement.last_velocity), 22.0), "fire player knockback should use the original strong ±22 impulse")
	_expect(is_equal_approx(movement.last_frames, 36.0), "fire player knockback should keep the original long slide window")
	_expect(is_equal_approx(movement.last_decay, 0.85), "fire player knockback should use the original fire decay")
	_expect(movement.last_replace_current, "fire player knockback should replace weaker base recoil")
	_expect(not movement.last_cleansable, "fire player knockback should not be treated as a cleansable stun")
	_expect(
		weather.harvest_particles("fire").size() >= (
			WeatherEventState.FIRE_HIT_EXPLOSION_PARTICLES + WeatherEventState.FIRE_HIT_SPARK_PARTICLES
		),
		"fire paddle hit should spawn the configured explosion and spark particles"
	)

	var ai_state := FakeAiState.new()
	var boss_result: Dictionary = weather.apply_fire_paddle_hit_knockback(
		false,
		Vector2(380.0, 60.0),
		{},
		{"ai_state": ai_state}
	)
	_expect(bool(boss_result.get("applied", false)), "fire boss paddle hit should apply weather knockback")
	_expect(ai_state.call_count == 1, "fire boss paddle hit should route to boss AI knockback")
	_expect(is_equal_approx(abs(ai_state.last_velocity), 22.0), "fire boss knockback should use the original strong ±22 impulse")
	_expect(is_equal_approx(ai_state.last_frames, 36.0), "fire boss knockback should keep the original long slide window")
	_expect(is_equal_approx(ai_state.last_decay, 0.85), "fire boss knockback should use the original fire decay")
	_expect(ai_state.last_replace_current, "fire boss knockback should replace weaker base recoil")
	_expect(is_equal_approx(abs(float(boss_result.get("boss_vel", 0.0))), 22.0), "fire boss result should expose the strong recoil velocity")


func _verify_fire_suppresses_default_paddle_recoil() -> void:
	var router := PaddleBounceEventRouter.new()
	var movement := FakeMovementState.new()
	router.register_rally_feedback(
		Vector2(380.0, 690.0),
		Vector2(0.0, -20.0),
		true,
		false,
		{"movement_state": movement},
		{"suppress_paddle_hit_knockback": true},
		0.0
	)
	_expect(movement.call_count == 0, "fire weather should suppress the normal paddle recoil before applying fire recoil")


func _verify_fire_draw_context_enables_burning_ball() -> void:
	var builder := BattleDrawBallContext.new()
	var draw_data: Dictionary = builder.build_draw(
		{
			"ball_active": true,
			"ball_pos": Vector2(380.0, 400.0),
			"ball_vel": Vector2(12.0, -20.0),
			"weather_active": true,
			"weather_type": "fire",
		},
		{}
	)
	var ball_context: Dictionary = draw_data.get("context", {})
	_expect(bool(ball_context.get("fire_weather_ball_active", false)), "fire weather should enable the always-burning ball overlay")


func _get_vec(source: Dictionary, key: String) -> Vector2:
	var value: Variant = source.get(key, Vector2.ZERO)
	if value is Vector2:
		return value
	return Vector2.ZERO


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
