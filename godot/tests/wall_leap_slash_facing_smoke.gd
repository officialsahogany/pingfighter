extends SceneTree

const Support := preload("res://tests/wall_leap_test_support.gd")

const PLAYER_HALF_WIDTH := 77.5
const BOSS_HALF_WIDTH := 50.0

var _support := Support.new()
var _failures: Array[String] = []


func _init() -> void:
	_verify_directional_offset(1, 80.0, true, "right-facing forward")
	_verify_directional_offset(1, -80.0, false, "right-facing rear")
	_verify_directional_offset(-1, 80.0, true, "left-facing forward")
	_verify_directional_offset(-1, -80.0, false, "left-facing rear")
	_verify_rect_edge_without_center_misses()
	_finish()


func _verify_directional_offset(direction: int, signed_forward_offset: float, should_hit: bool, label: String) -> void:
	var fixture: Dictionary = _start_slash(direction, signed_forward_offset)
	_advance_until_return(fixture)
	var calls: Array = fixture["status"].calls
	_expect((not calls.is_empty()) == should_hit, "%s blade hit result mismatch" % label)
	_expect(is_equal_approx(float(fixture["special_gauge"]), 340.0), "%s must keep the committed entry 100 plus slash 60 cost" % label)
	if should_hit and not calls.is_empty():
		var call: Dictionary = calls[0]
		_expect(str(call.get("status_id", "")) == "slow", "blade slash must use shared slow status")
		_expect(is_equal_approx(float(call.get("duration_frames", 0.0)), 300.0), "blade slow must last five seconds")
		_expect(is_equal_approx(float((call.get("data", {}) as Dictionary).get("multiplier", 1.0)), 0.55), "blade slow multiplier must be 0.55")


func _verify_rect_edge_without_center_misses() -> void:
	# The boss rect begins at +311px and overlaps the blade's 360px path, but its
	# center is +361px. Rect contact must not replace the canonical center-X rule.
	var fixture: Dictionary = _start_slash(1, 361.0)
	_advance_until_return(fixture)
	_expect((fixture["status"].calls as Array).is_empty(), "boss rect edge inside range must miss when boss center X is outside 360px")
	_expect(is_equal_approx(float(fixture["special_gauge"]), 340.0), "rect-edge miss must still keep the committed slash cost")


func _start_slash(direction: int, signed_forward_offset: float) -> Dictionary:
	var fixture: Dictionary = _support.make_fixture()
	_support.enter(fixture)
	_support.advance_to_infiltrating(fixture)
	_support.route_once(fixture, {"direction": float(direction)})
	var current_pos: Vector2 = fixture["runtime"].get_snapshot().get("wall_leap_raid_current_pos", fixture["player_pos"])
	var player_center_x := current_pos.x + PLAYER_HALF_WIDTH
	var boss_center_x := player_center_x + float(direction) * signed_forward_offset
	fixture["context"]["boss_pos"] = Vector2(boss_center_x - BOSS_HALF_WIDTH, 25.0)
	_support.route_once(fixture, {"mouse_left_pressed": true, "mouse_left_just_pressed": true})
	_expect(str(fixture["runtime"].get_snapshot().get("wall_leap_raid_state", "")) == "slash", "LMB must enter windup instead of applying an immediate body-range hit")
	return fixture


func _advance_until_return(fixture: Dictionary, limit: int = 80) -> void:
	for _index in range(limit):
		if str(fixture["runtime"].get_snapshot().get("wall_leap_raid_state", "")) == "return":
			return
		_support.route_once(fixture)
	_expect(false, "slash blade must resolve to RETURN within its bounded range")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("wall_leap_slash_facing_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
