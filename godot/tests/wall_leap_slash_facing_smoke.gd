extends SceneTree

const Support := preload("res://tests/wall_leap_test_support.gd")

var _support := Support.new()
var _failures: Array[String] = []


func _init() -> void:
	_verify_offset(110.0, true, "110 boundary")
	_verify_offset(111.0, false, "111 boundary")
	_verify_offset(0.0, false, "rear zero")
	_verify_rect_edge_miss()
	_finish()


func _verify_offset(offset: float, should_hit: bool, label: String) -> void:
	var fixture: Dictionary = _support.make_fixture()
	fixture["context"]["boss_pos"] = Vector2(340.0, 25.0)
	_support.enter(fixture)
	_support.advance_to_infiltrating(fixture)
	var player_center_x: float = (fixture["player_pos"] as Vector2).x + 77.5
	fixture["context"]["boss_pos"] = Vector2(player_center_x + offset - 50.0, 25.0)
	_support.route_once(fixture, {"mouse_left_pressed": true, "mouse_left_just_pressed": true})
	var calls: Array = fixture["status"].calls
	_expect((not calls.is_empty()) == should_hit, "%s hit result mismatch" % label)
	_expect(is_equal_approx(float(fixture["special_gauge"]), 340.0), "%s must spend entry 100 plus slash 60 even on miss" % label)
	_expect(str(fixture["runtime"].get_snapshot().get("wall_leap_raid_state", "")) == "return", "%s must immediately return" % label)
	if should_hit and not calls.is_empty():
		var call: Dictionary = calls[0]
		_expect(str(call.get("status_id", "")) == "slow", "slash must use shared slow status")
		_expect(is_equal_approx(float(call.get("duration_frames", 0.0)), 300.0), "slash slow must last five seconds")
		_expect(is_equal_approx(float((call.get("data", {}) as Dictionary).get("multiplier", 1.0)), 0.55), "slash slow multiplier must be 0.55")


func _verify_rect_edge_miss() -> void:
	var fixture: Dictionary = _support.make_fixture()
	fixture["context"]["boss_pos"] = Vector2(340.0, 25.0)
	_support.enter(fixture)
	_support.advance_to_infiltrating(fixture)
	var player_pos: Vector2 = fixture["player_pos"]
	fixture["context"]["boss_pos"] = Vector2(player_pos.x + 155.0, 25.0)
	_support.route_once(fixture, {"mouse_left_pressed": true, "mouse_left_just_pressed": true})
	_expect(fixture["status"].calls.is_empty(), "rect edge contact must not replace boss-center distance")


func _expect(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("wall_leap_slash_facing_smoke: ok")
		quit(0)
		return
	for failure in _failures: push_error(failure)
	quit(1)
