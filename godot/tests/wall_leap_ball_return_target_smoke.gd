extends SceneTree

const Support := preload("res://tests/wall_leap_test_support.gd")

const FRAME_DELTA := 1.0 / 60.0
const PLAYER_HALF_WIDTH := 77.5
const BOSS_HALF_WIDTH := 50.0

var _support := Support.new()
var _failures: Array[String] = []


func _init() -> void:
	_verify_blast_returns_to_ball_snapshot()
	_verify_slash_returns_to_ball_with_wall_clamp()
	_verify_forced_return_keeps_entry_anchor()
	_finish()


func _verify_blast_returns_to_ball_snapshot() -> void:
	var fixture: Dictionary = _support.make_fixture()
	_support.enter(fixture)
	_support.advance_to_infiltrating(fixture)
	_support.advance_frames(fixture, 16)
	fixture["context"]["ball_pos"] = Vector2(650.0, 360.0)
	_support.route_once(fixture, {"secondary_action_pressed": true, "secondary_action_just_pressed": true})
	_support.advance_frames(fixture, 43)
	_expect(str(fixture["runtime"].get_snapshot().get("wall_leap_raid_state", "")) == "return", "blast commit must begin RETURN before checking the ball target")
	fixture["context"]["ball_pos"] = Vector2(100.0, 360.0)
	_support.advance_frames(fixture, 14)
	var landed: Vector2 = fixture["player_pos"]
	_expect(str(fixture["runtime"].get_snapshot().get("wall_leap_raid_state", "")) == "idle", "blast return must complete within the authored 0.22 seconds")
	_expect(is_equal_approx(landed.x, 650.0 - PLAYER_HALF_WIDTH), "blast return must align the paddle center to the ball X captured at commit (got %.2f)" % landed.x)
	_expect(is_equal_approx(landed.y, 680.0), "ball-targeted blast return must preserve the original landing Y")


func _verify_slash_returns_to_ball_with_wall_clamp() -> void:
	var fixture: Dictionary = _support.make_fixture()
	fixture["context"]["ball_pos"] = Vector2(20.0, 420.0)
	_support.enter(fixture)
	_support.advance_to_infiltrating(fixture)
	var player_center_x: float = (fixture["player_pos"] as Vector2).x + PLAYER_HALF_WIDTH
	fixture["context"]["boss_pos"] = Vector2(player_center_x + 40.0 - BOSS_HALF_WIDTH, 25.0)
	_support.route_once(fixture, {"mouse_left_pressed": true, "mouse_left_just_pressed": true})
	_support.advance_frames(fixture, 6)
	_expect(str(fixture["runtime"].get_snapshot().get("wall_leap_raid_state", "")) == "return", "same-frame blade contact must begin RETURN")
	_support.advance_frames(fixture, 14)
	var landed: Vector2 = fixture["player_pos"]
	_expect(is_equal_approx(landed.x, 0.0), "slash return must clamp a left-edge ball target inside the playfield (got %.2f)" % landed.x)
	_expect(is_equal_approx(landed.x + PLAYER_HALF_WIDTH, PLAYER_HALF_WIDTH), "clamped slash return must keep the full paddle on screen (got %.2f)" % landed.x)


func _verify_forced_return_keeps_entry_anchor() -> void:
	var fixture: Dictionary = _support.make_fixture()
	fixture["context"]["ball_pos"] = Vector2(650.0, 360.0)
	_support.enter(fixture)
	_support.advance_to_infiltrating(fixture)
	_support.route_once(fixture, {"direction": 1.0}, FRAME_DELTA)
	_expect(fixture["runtime"].wall_leap_state.force_return("seal_forced_return", fixture["deps"]), "active infiltration must accept forced return")
	_support.advance_frames(fixture, 14)
	var landed: Vector2 = fixture["player_pos"]
	_expect(is_equal_approx(landed.x, 300.0), "state-based forced return must keep the original entry X safety anchor")
	_expect(not is_equal_approx(landed.x, 650.0 - PLAYER_HALF_WIDTH), "forced return must not inherit the normal action ball-target override")


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
