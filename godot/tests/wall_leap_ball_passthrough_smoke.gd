extends SceneTree

const Support := preload("res://tests/wall_leap_test_support.gd")
const BallMotionCollisionDetector := preload("res://scripts/ball/ball_motion_collision_detector.gd")

var _failures: Array[String] = []


func _init() -> void:
	var support := Support.new()
	var fixture: Dictionary = support.make_fixture()
	var detector := BallMotionCollisionDetector.new()
	var base := {
		"player_pos": Vector2(300.0, 680.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"player_collision_cooldown": 0.0,
		"boss_collision_cooldown": 0.0,
	}
	_expect(bool(support.enter(fixture).get("activated", false)), "entry must activate through Viper route")
	support.advance_to_infiltrating(fixture)
	var active_context: Dictionary = base.duplicate(true)
	active_context.merge(fixture["runtime"].get_ball_collision_context(), true)
	var active_hit: Dictionary = detector.check_paddles(Vector2(377.5, 700.0), Vector2(0.0, 9.0), 28.6, active_context)
	_expect(active_hit.is_empty(), "infiltrating body paddle must be pass-through")
	var slash_result: Dictionary = support.route_once(fixture, {"mouse_left_pressed": true, "mouse_left_just_pressed": true})
	_expect(str(fixture["runtime"].get_snapshot().get("wall_leap_raid_state", "")) == "return", "slash route must begin return")
	var landing: Dictionary = support.advance_frames(fixture, 14)
	_expect(str(fixture["runtime"].get_snapshot().get("wall_leap_raid_state", "")) == "idle", "return landing must restore idle")
	_expect(is_equal_approx(float(landing.get("player_collision_cooldown", -1.0)), 6.0), "landing must rearm six-frame collision cooldown")
	var restored_context: Dictionary = base.duplicate(true)
	restored_context.merge(fixture["runtime"].get_ball_collision_context(), true)
	var restored_hit: Dictionary = detector.check_paddles(Vector2(377.5, 700.0), Vector2(0.0, 9.0), 28.6, restored_context)
	_expect(str(restored_hit.get("event", "")) == "player_paddle", "body paddle collision must return after landing")
	_expect(not fixture["skill_state"].cooldowns.is_empty(), "cooldown must start only at landing")
	_expect(bool(slash_result.get("handled", false)), "slash must pass the real activation router")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("wall_leap_ball_passthrough_smoke: ok")
		quit(0)
		return
	for failure in _failures: push_error(failure)
	quit(1)
