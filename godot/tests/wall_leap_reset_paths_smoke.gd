extends SceneTree

const Support := preload("res://tests/wall_leap_test_support.gd")
const BallRoundCleanup := preload("res://scripts/ball/ball_round_cleanup.gd")
const MatchResetController := preload("res://scripts/core/match_reset_controller.gd")

class StageResetBridge:
	extends RefCounted
	var runtime: Object
	func _init(next_runtime: Object) -> void: runtime = next_runtime
	func reset_ball() -> void:
		BallRoundCleanup.new().reset_for_ball_reset({"viper_skill_runtime": runtime})

var _support := Support.new()
var _failures: Array[String] = []


func _init() -> void:
	var round_fixture: Dictionary = _active_fixture()
	BallRoundCleanup.new().reset_for_ball_reset({"viper_skill_runtime": round_fixture["runtime"]})
	_assert_normalized(round_fixture["runtime"], "round end")

	var result_fixture: Dictionary = _active_fixture()
	MatchResetController.new().reset_game({"skill_runtimes": [result_fixture["runtime"]]}, {})
	_assert_normalized(result_fixture["runtime"], "result/game end")

	var stage_fixture: Dictionary = _active_fixture()
	var bridge := StageResetBridge.new(stage_fixture["runtime"])
	MatchResetController.new().reset_for_stage_transition({}, {"reset_ball": Callable(bridge, "reset_ball")})
	_assert_normalized(stage_fixture["runtime"], "stage exit")
	_finish()


func _active_fixture() -> Dictionary:
	var fixture: Dictionary = _support.make_fixture()
	_support.enter(fixture)
	_support.advance_to_infiltrating(fixture)
	_support.route_once(fixture, {"direction": -1.0})
	_support.route_once(fixture, {"mouse_left_pressed": true, "mouse_left_just_pressed": true})
	_support.advance_frames(fixture, 6)
	var snapshot: Dictionary = fixture["runtime"].get_snapshot()
	_expect(str(snapshot.get("wall_leap_raid_state", "")) == "blade_flight", "reset fixture must own a live blade")
	_expect(bool(snapshot.get("wall_leap_raid_blade_active", false)), "reset fixture must start with projectile state to avoid vacuous GREEN")
	fixture["runtime"].wall_leap_state._start_blast_vfx(Vector2(377.5, 50.0), Vector2(377.5, 45.0), true)
	_expect(bool(fixture["runtime"].get_snapshot().get("wall_leap_raid_blast_vfx_active", false)), "reset fixture must also own a live detached blast tail")
	return fixture


func _assert_normalized(runtime: Object, label: String) -> void:
	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(str(snapshot.get("wall_leap_raid_state", "")) == "idle", "%s must clear active state" % label)
	_expect(not bool(snapshot.get("wall_leap_raid_active", true)), "%s must clear active flag" % label)
	_expect(snapshot.get("wall_leap_raid_entry_pos", Vector2.ONE) == Vector2.ZERO, "%s must clear saved entry position" % label)
	_expect(int(snapshot.get("wall_leap_raid_facing_dir", 0)) == 1, "%s must reset the facing latch" % label)
	_expect(int(snapshot.get("wall_leap_raid_lateral_motion_dir", 1)) == 0, "%s must clear lateral presentation motion" % label)
	_expect(is_zero_approx(float(snapshot.get("wall_leap_raid_slash_elapsed_seconds", -1.0))), "%s must clear the sword-swing clock" % label)
	_expect(not bool(snapshot.get("wall_leap_raid_slash_presentation_active", true)), "%s must clear sword-swing presentation ownership" % label)
	_expect(not bool(snapshot.get("wall_leap_raid_blade_active", true)), "%s must destroy the blade projectile" % label)
	_expect(snapshot.get("wall_leap_raid_blade_pos", Vector2.ONE) == Vector2.ZERO, "%s must clear blade position" % label)
	_expect(not bool(snapshot.get("wall_leap_raid_blade_burst_active", true)), "%s must clear blade burst presentation" % label)
	_expect(not bool(snapshot.get("wall_leap_raid_blast_vfx_active", true)), "%s must clear detached blast presentation" % label)
	_expect(snapshot.get("wall_leap_raid_blast_vfx_origin", Vector2.ONE) == Vector2.ZERO, "%s must clear blast presentation coordinates" % label)
	_expect(bool(runtime.get_ball_collision_context().get("player_guard_available", false)), "%s must restore player guard" % label)
	_expect(is_equal_approx(float(runtime.get_ball_collision_context().get("ball_motion_step_multiplier", 0.0)), 1.0), "%s must clear ball multiplier" % label)


func _expect(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("wall_leap_reset_paths_smoke: ok")
		quit(0)
		return
	for failure in _failures: push_error(failure)
	quit(1)
