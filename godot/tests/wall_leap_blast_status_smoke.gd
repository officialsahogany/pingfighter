extends SceneTree

const Support := preload("res://tests/wall_leap_test_support.gd")
const StatusEffectState := preload("res://scripts/status/status_effect_state.gd")
const BossAiState := preload("res://scripts/ai/boss_ai_state.gd")

var _support := Support.new()
var _failures: Array[String] = []


func _init() -> void:
	_verify_blast_offset(50.0, true)
	_verify_blast_offset(51.0, false)
	_finish()


func _verify_blast_offset(offset: float, should_hit: bool) -> void:
	var fixture: Dictionary = _support.make_fixture()
	var status := StatusEffectState.new()
	fixture["deps"]["status_effect_state"] = status
	_support.enter(fixture)
	_support.advance_to_infiltrating(fixture)
	_support.advance_frames(fixture, 16)
	var player_center_x: float = (fixture["player_pos"] as Vector2).x + 77.5
	fixture["context"]["boss_pos"] = Vector2(player_center_x + offset - 50.0, 25.0)
	_support.route_once(fixture, {"secondary_action_pressed": true, "secondary_action_just_pressed": true})
	_expect(is_equal_approx(float(fixture["special_gauge"]), 250.0), "blast branch must commit 150 gauge at FUSE entry")
	_support.advance_frames(fixture, 43)
	var stun: Dictionary = status.get_status("boss", "stun")
	_expect((not stun.is_empty()) == should_hit, "blast offset %.1f hit result mismatch" % offset)
	if not should_hit:
		return
	_expect(is_equal_approx(float(stun.get("remaining_frames", 0.0)), 180.0), "blast stun must last three seconds")
	_expect(is_equal_approx(float(stun.get("knockback_vel", 0.0)), 19.0), "blast must use 19px initial knockback")
	_expect(is_equal_approx(float(stun.get("knockback_frames", 0.0)), 18.0), "blast must carry 18 knockback frames")
	var ai := BossAiState.new()
	var ai_context: Dictionary = status.get_boss_ai_context()
	ai_context.merge({"width": 760.0, "boss_paddle_width": 100.0, "current_stage": 1}, true)
	var first: Dictionary = ai.update(1.0 / 60.0, Vector2(300.0, 25.0), 0.0, ai_context)
	_expect(is_equal_approx((first.get("boss_pos", Vector2.ZERO) as Vector2).x, 319.0), "shared AI consumer must turn stun knockback into 19px displacement")
	status.update(1.0)
	var decayed_context: Dictionary = status.get_boss_ai_context()
	decayed_context.merge({"width": 760.0, "boss_paddle_width": 100.0, "current_stage": 1}, true)
	var second: Dictionary = ai.update(1.0 / 60.0, first.get("boss_pos", Vector2.ZERO), 0.0, decayed_context)
	var second_dx: float = (second.get("boss_pos", Vector2.ZERO) as Vector2).x - (first.get("boss_pos", Vector2.ZERO) as Vector2).x
	_expect(second_dx > 0.0 and second_dx < 19.0, "shared status decay must reduce later knockback displacement")


func _expect(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("wall_leap_blast_status_smoke: ok")
		quit(0)
		return
	for failure in _failures: push_error(failure)
	quit(1)
