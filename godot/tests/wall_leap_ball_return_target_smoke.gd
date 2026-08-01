extends SceneTree

const Support := preload("res://tests/wall_leap_test_support.gd")

const FRAME_DELTA := 1.0 / 60.0
const PLAYER_HALF_WIDTH := 77.5
const BOSS_HALF_WIDTH := 50.0
const POSITION_TOLERANCE := 0.02

var _support := Support.new()
var _failures: Array[String] = []


func _init() -> void:
	_verify_blast_returns_to_predicted_arrival_snapshot()
	_verify_slash_returns_to_wall_reflected_arrival()
	_verify_forced_return_keeps_entry_anchor()
	_finish()


func _verify_blast_returns_to_predicted_arrival_snapshot() -> void:
	var fixture: Dictionary = _support.make_fixture()
	_support.enter(fixture)
	_support.advance_to_infiltrating(fixture)
	_support.advance_frames(fixture, 16)
	fixture["context"]["ball_pos"] = Vector2(300.0, 300.0)
	fixture["context"]["ball_vel"] = Vector2(6.0, 10.0)
	_support.route_once(fixture, {"secondary_action_pressed": true, "secondary_action_just_pressed": true})
	_support.advance_frames(fixture, 43)
	var return_snapshot: Dictionary = fixture["runtime"].get_snapshot()
	_expect(str(return_snapshot.get("wall_leap_raid_state", "")) == "return", "blast commit must begin RETURN before checking the ball target")
	_expect_close((return_snapshot.get("wall_leap_raid_return_target_pos", Vector2.ZERO) as Vector2).x, 438.92, "blast return must lead the ball to its predicted player-line arrival X")
	fixture["context"]["ball_pos"] = Vector2(100.0, 360.0)
	_support.advance_frames(fixture, 14)
	var landed: Vector2 = fixture["player_pos"]
	_expect(str(fixture["runtime"].get_snapshot().get("wall_leap_raid_state", "")) == "idle", "blast return must complete within the authored 0.22 seconds")
	_expect_close(landed.x, 438.92, "blast return must keep the predicted arrival X snapshot even after the ball moves")
	_expect(is_equal_approx(landed.y, 680.0), "ball-targeted blast return must preserve the original landing Y")


func _verify_slash_returns_to_wall_reflected_arrival() -> void:
	var fixture: Dictionary = _support.make_fixture()
	fixture["context"]["ball_pos"] = Vector2(700.0, 400.0)
	fixture["context"]["ball_vel"] = Vector2(8.0, 10.0)
	_support.enter(fixture)
	_support.advance_to_infiltrating(fixture)
	var player_center_x: float = (fixture["player_pos"] as Vector2).x + PLAYER_HALF_WIDTH
	fixture["context"]["boss_pos"] = Vector2(player_center_x + 40.0 - BOSS_HALF_WIDTH, 25.0)
	_support.route_once(fixture, {"mouse_left_pressed": true, "mouse_left_just_pressed": true})
	_support.advance_frames(fixture, 6)
	var return_snapshot: Dictionary = fixture["runtime"].get_snapshot()
	_expect(str(return_snapshot.get("wall_leap_raid_state", "")) == "return", "same-frame blade contact must begin RETURN")
	_expect_close((return_snapshot.get("wall_leap_raid_return_target_pos", Vector2.ZERO) as Vector2).x, 505.34, "slash return prediction must fold the future trajectory across the right wall")
	_support.advance_frames(fixture, 14)
	var landed: Vector2 = fixture["player_pos"]
	_expect_close(landed.x, 505.34, "slash return must land at the wall-reflected arrival X")
	_expect(landed.x > 0.0 and landed.x + PLAYER_HALF_WIDTH * 2.0 < 760.0, "wall-reflected slash target must keep the full paddle on screen")


func _verify_forced_return_keeps_entry_anchor() -> void:
	var fixture: Dictionary = _support.make_fixture()
	fixture["context"]["ball_pos"] = Vector2(650.0, 360.0)
	fixture["context"]["ball_vel"] = Vector2(-4.0, 8.0)
	_support.enter(fixture)
	_support.advance_to_infiltrating(fixture)
	_support.route_once(fixture, {"direction": 1.0}, FRAME_DELTA)
	_expect(fixture["runtime"].wall_leap_state.force_return("seal_forced_return", fixture["deps"]), "active infiltration must accept forced return")
	_support.advance_frames(fixture, 14)
	var landed: Vector2 = fixture["player_pos"]
	_expect(is_equal_approx(landed.x, 300.0), "state-based forced return must keep the original entry X safety anchor")
	_expect(not is_equal_approx(landed.x, 422.15), "forced return must not inherit the normal action arrival prediction")


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(absf(actual - expected) <= POSITION_TOLERANCE, "%s (expected %.2f, got %.2f)" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("wall_leap_ball_return_target_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
