extends SceneTree

const BallMotionCollisionDetector := preload("res://scripts/ball/ball_motion_collision_detector.gd")
const BlacksmithThorShieldState := preload("res://scripts/characters/blacksmith_thor_shield_state.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_runtime_routing()
	_verify_shield_open_swing_and_speed()
	_verify_shield_collision_and_hit_reward()

	if _failures.is_empty():
		print("blacksmith_thor_shield_runtime_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_runtime_routing() -> void:
	var runtime: Object = PlayerCharacterRuntime.new()
	_expect(runtime.normalize("blacksmith") == "blacksmith", "Blacksmith should normalize to blacksmith")
	_expect(runtime.normalize("baltor") == "blacksmith", "Baltor alias should normalize to blacksmith")
	_expect(runtime.normalize("kohaku") == "blacksmith", "Kohaku alias should normalize to blacksmith")
	_expect(runtime.get_player_controller_key("blacksmith") == "blacksmith_player_controller", "Blacksmith should route to its player controller")
	_expect(runtime.get_input_reader_key("blacksmith") == "blacksmith_input_reader", "Blacksmith should route to its input reader")
	_expect(runtime.get_skill_state_key("blacksmith") == "blacksmith_skill_state", "Blacksmith should expose its skill-state compatibility shell")
	_expect(runtime.get_combo_state_key("blacksmith") == "", "Blacksmith should not inherit Smasher combo state")


func _verify_shield_open_swing_and_speed() -> void:
	var state: Object = BlacksmithThorShieldState.new()
	var config := {
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"player_skill_input_locked": false,
	}
	var open_result: Dictionary = state.update_input(
		0.016,
		{"up_just_pressed": true, "action_just_pressed": false, "blacksmith_swing_direction": 0},
		1000,
		90.0,
		Vector2(302.5, 700.0),
		config,
		{}
	)
	_expect(bool(open_result.get("blacksmith_umbrella_open", false)), "Up input should open Thor Shield")
	_expect(float(state.get_player_speed_multiplier()) < 0.26, "Open Thor Shield should slow movement to the legacy guard rate")
	state.update_input(
		0.80,
		{"up_just_pressed": false, "action_just_pressed": true, "blacksmith_swing_direction": -1},
		1800,
		90.0,
		Vector2(302.5, 700.0),
		config,
		{}
	)
	var swing_snapshot: Dictionary = state.get_snapshot()
	_expect(bool(swing_snapshot.get("blacksmith_umbrella_swing_active", false)), "Action plus horizontal input should start Thor Shield swing")
	_expect(int(swing_snapshot.get("blacksmith_umbrella_swing_direction", 0)) == -1, "Swing direction should preserve the exclusive horizontal input")


func _verify_shield_collision_and_hit_reward() -> void:
	var state: Object = BlacksmithThorShieldState.new()
	var config := {
		"paddle_width": 155.0,
		"paddle_height": 50.0,
	}
	state.update_input(
		0.80,
		{"up_just_pressed": true, "action_just_pressed": false, "blacksmith_swing_direction": 0},
		1000,
		100.0,
		Vector2(302.5, 700.0),
		config,
		{}
	)
	var collision_context: Dictionary = state.get_ball_collision_context({
		"player_pos": Vector2(302.5, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
	})
	_expect(bool(collision_context.get("blacksmith_thor_shield_active", false)), "Open Thor Shield should publish a ball collision context")
	var shield_rect: Rect2 = collision_context.get("blacksmith_thor_shield_rect", Rect2())
	var detector: Object = BallMotionCollisionDetector.new()
	var result: Dictionary = detector.check_paddles(
		shield_rect.get_center(),
		Vector2(0.0, 12.0),
		20.0,
		{
			"player_pos": Vector2(302.5, 700.0),
			"player_paddle_size": Vector2(155.0, 50.0),
			"hitbox_padding": 5.0,
			"player_collision_cooldown": 0.0,
			"boss_collision_cooldown": 0.0,
			"blacksmith_thor_shield_active": true,
			"blacksmith_thor_shield_rect": shield_rect,
			"blacksmith_umbrella_gauge_gain": 60.0,
		}
	)
	_expect(str(result.get("event", "")) == "player_paddle", "Thor Shield hitbox should resolve through the player paddle event")
	_expect(bool(result.get("blacksmith_thor_shield_hit", false)), "Thor Shield collision should mark the shield-hit flag")

	var hit_result: Dictionary = state.notify_ball_hit(
		shield_rect.get_center(),
		Vector2(0.0, 12.0),
		100.0,
		130.0,
		{"current_msec": 2000, "gauge_max": 500.0, "blacksmith_umbrella_gauge_gain": 60.0},
		{}
	)
	_expect(is_equal_approx(float(hit_result.get("special_gauge", 0.0)), 160.0), "Thor Shield hit should raise base paddle gauge gain to 60")
	_expect(int(hit_result.get("blacksmith_umbrella_gauge", 0)) == 4, "Thor Shield hit should consume one shield durability")
	_expect(bool(hit_result.get("suppress_paddle_hit_knockback", false)), "Thor Shield hit should suppress normal paddle knockback")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
