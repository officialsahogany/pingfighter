extends SceneTree

const Support := preload("res://tests/wall_leap_test_support.gd")

const FRAME_DELTA := 1.0 / 60.0
const PLAYER_HALF_WIDTH := 77.5
const BOSS_HALF_WIDTH := 50.0

var _support := Support.new()
var _failures: Array[String] = []


func _init() -> void:
	_verify_windup_and_forward_authority()
	_verify_same_frame_hit_keeps_impact_sheet()
	_verify_rear_target_misses()
	_verify_swept_segment_prevents_tunneling()
	_verify_range_boundary()
	_verify_single_hit_and_return_timing()
	_verify_forced_return_clears_blade_without_refund()
	_finish()


func _verify_windup_and_forward_authority() -> void:
	var fixture := _start_slash(1, 59.0)
	_support.advance_frames(fixture, 5)
	var pre_impact: Dictionary = fixture["runtime"].get_snapshot()
	_expect(str(pre_impact.get("wall_leap_raid_state", "")) == "slash", "blade must remain in slash windup before impact frame 3")
	_expect(not bool(pre_impact.get("wall_leap_raid_blade_active", true)), "blade must not exist before impact frame 3")
	_expect((fixture["status"].calls as Array).is_empty(), "windup must not apply the boss slow")
	_support.advance_frames(fixture, 1)
	var spawned: Dictionary = fixture["runtime"].get_snapshot()
	_expect(str(spawned.get("wall_leap_raid_state", "")) == "blade_flight", "impact frame 3 must spawn the blade into BLADE_FLIGHT")
	_expect(bool(spawned.get("wall_leap_raid_blade_active", false)), "blade must be live after the impact frame")
	_expect((fixture["status"].calls as Array).is_empty(), "a forward target outside the spawn segment must wait for blade contact")


func _verify_same_frame_hit_keeps_impact_sheet() -> void:
	var fixture := _start_slash(1, 40.0)
	_support.advance_frames(fixture, 6)
	var snapshot: Dictionary = fixture["runtime"].get_snapshot()
	var actor_context: Dictionary = fixture["runtime"].get_actor_draw_context()
	_expect(str(snapshot.get("wall_leap_raid_state", "")) == "return", "a boss center inside the spawn segment must consume the blade and return on impact")
	_expect((fixture["status"].calls as Array).size() == 1, "spawn-segment contact must apply exactly one slow")
	_expect(bool(actor_context.get("player_hit_active", false)), "same-frame blade consumption must still present the authored sword impact frame")
	_expect(int(actor_context.get("player_hit_frame", -1)) == 3, "same-frame blade consumption must not erase attack frame 3 before draw")


func _verify_rear_target_misses() -> void:
	var fixture := _start_slash(1, -60.0)
	_advance_until_return(fixture)
	_expect((fixture["status"].calls as Array).is_empty(), "a target behind the latched slash direction must miss")
	_expect(is_equal_approx(float(fixture["special_gauge"]), 340.0), "a rear miss must still keep the committed 100 + 60 cost")


func _verify_swept_segment_prevents_tunneling() -> void:
	var fixture := _start_slash(1, 59.0)
	_support.advance_frames(fixture, 6)
	_expect((fixture["status"].calls as Array).is_empty(), "tunneling fixture must begin between the spawn point and the next 14px step")
	_support.advance_frames(fixture, 1)
	_expect((fixture["status"].calls as Array).size() == 1, "previous-to-current swept segment must catch the boss center between blade samples")
	_expect(str(fixture["runtime"].get_snapshot().get("wall_leap_raid_state", "")) == "return", "a swept blade hit must begin RETURN on the same frame")


func _verify_range_boundary() -> void:
	var boundary := _start_slash(1, 360.0)
	_advance_until_return(boundary)
	_expect((boundary["status"].calls as Array).size() == 1, "boss center exactly 360px forward must be hittable")

	var outside := _start_slash(1, 361.0)
	_advance_until_return(outside)
	_expect((outside["status"].calls as Array).is_empty(), "boss center 361px forward must be outside the blade authority")
	_expect(not bool(outside["runtime"].get_snapshot().get("wall_leap_raid_blade_active", true)), "range expiry must destroy the blade before RETURN")


func _verify_single_hit_and_return_timing() -> void:
	var fixture := _start_slash(-1, 73.0)
	_support.advance_frames(fixture, 6)
	var flight: Dictionary = fixture["runtime"].get_snapshot()
	_expect(str(flight.get("wall_leap_raid_state", "")) == "blade_flight", "slash must not return while its blade remains visible")
	_expect(bool(flight.get("wall_leap_raid_blade_active", false)), "blade must remain active until hit, wall, or range expiry")
	_advance_until_return(fixture)
	var calls: Array = fixture["status"].calls
	_expect(calls.size() == 1, "blade contact must apply the slow exactly once")
	if not calls.is_empty():
		var call: Dictionary = calls[0]
		_expect(str(call.get("status_id", "")) == "slow", "blade authority must use the shared slow status")
		_expect(is_equal_approx(float(call.get("duration_frames", 0.0)), 300.0), "blade slow must last five seconds")
		_expect(is_equal_approx(float((call.get("data", {}) as Dictionary).get("multiplier", 1.0)), 0.55), "blade slow must use BossSlowTiers.MEDIUM")
	_support.advance_frames(fixture, 30)
	_expect((fixture["status"].calls as Array).size() == 1, "a destroyed blade must never re-hit during RETURN or landing")


func _verify_forced_return_clears_blade_without_refund() -> void:
	var fixture := _start_slash(1, 240.0)
	_support.advance_frames(fixture, 6)
	_expect(str(fixture["runtime"].get_snapshot().get("wall_leap_raid_state", "")) == "blade_flight", "forced-return fixture must own a live blade")
	var forced: bool = fixture["runtime"].wall_leap_state.force_return("seal_forced_return", fixture["deps"])
	var snapshot: Dictionary = fixture["runtime"].get_snapshot()
	_expect(forced, "BLADE_FLIGHT must accept state-based forced return")
	_expect(str(snapshot.get("wall_leap_raid_state", "")) == "return", "forced return must enter RETURN immediately")
	_expect(not bool(snapshot.get("wall_leap_raid_blade_active", true)), "forced return must destroy the live blade")
	_expect(is_equal_approx(float(fixture["special_gauge"]), 340.0), "forced return after slash commit must not refund the 60 cost")


func _start_slash(direction: int, boss_offset_in_slash_direction: float) -> Dictionary:
	var fixture: Dictionary = _support.make_fixture()
	_support.enter(fixture)
	_support.advance_to_infiltrating(fixture)
	_support.route_once(fixture, {"direction": float(direction)})
	var snapshot: Dictionary = fixture["runtime"].get_snapshot()
	var player_center_x := (snapshot.get("wall_leap_raid_current_pos", fixture["player_pos"]) as Vector2).x + PLAYER_HALF_WIDTH
	var boss_center_x := player_center_x + float(direction) * boss_offset_in_slash_direction
	fixture["context"]["boss_pos"] = Vector2(boss_center_x - BOSS_HALF_WIDTH, 25.0)
	_support.route_once(fixture, {"mouse_left_pressed": true, "mouse_left_just_pressed": true})
	_expect(str(fixture["runtime"].get_snapshot().get("wall_leap_raid_state", "")) == "slash", "LMB must enter SLASH before spawning the blade")
	_expect(is_equal_approx(float(fixture["special_gauge"]), 340.0), "slash must commit 60 after the 100 entry cost")
	return fixture


func _advance_until_return(fixture: Dictionary, limit: int = 80) -> void:
	for _index in range(limit):
		if str(fixture["runtime"].get_snapshot().get("wall_leap_raid_state", "")) == "return":
			return
		_support.route_once(fixture, {}, FRAME_DELTA)
	_expect(false, "blade flight must terminate by hit, 360px range, or wall within the bounded fixture")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("wall_leap_blade_projectile_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
