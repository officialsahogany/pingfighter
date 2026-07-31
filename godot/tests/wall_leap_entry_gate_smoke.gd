extends SceneTree

const Support := preload("res://tests/wall_leap_test_support.gd")
const Stage3BossSkillState := preload("res://scripts/stages/stage3/stage3_boss_skill_state.gd")

var _support := Support.new()
var _failures: Array[String] = []


func _init() -> void:
	_verify_denied("skip_ball_motion_step", func(f): f["context"]["skip_ball_motion_step"] = true)
	_verify_denied("psychoball_hitstop", func(f):
		var stage3 := Stage3BossSkillState.new()
		stage3.set("psychoball_hitstop_timer", 0.05)
		f["deps"]["stage3_boss_skill_state"] = stage3
	)
	_verify_denied("power_freeze", func(f): f["power"].active = true)
	_verify_denied("dmk_freeze", func(f): f["runtime"].dmk_freeze_active = true)
	_verify_denied("stopwatch_freeze", func(f): f["context"]["stopwatch_freeze_active"] = true)
	_verify_denied("serve_wait", func(f): f["round"].waiting = true)
	_verify_denied("inactive_ball", func(f): f["context"]["ball_active"] = false)
	_verify_denied("gauge_159", func(f): f["special_gauge"] = 159.0)
	_verify_denied("dash_flight", func(f): f["dash"].active = true)
	_finish()


func _verify_denied(label: String, configure: Callable) -> void:
	var fixture: Dictionary = _support.make_fixture()
	configure.call(fixture)
	var before_gauge: float = fixture["special_gauge"]
	var result: Dictionary = _support.enter(fixture)
	_expect(not bool(result.get("activated", false)), "%s must block entry" % label)
	_expect(is_equal_approx(float(fixture["special_gauge"]), before_gauge), "%s must not spend gauge" % label)
	_expect(str(fixture["runtime"].get_snapshot().get("wall_leap_raid_state", "")) == "idle", "%s must keep state idle" % label)
	_expect(fixture["skill_state"].cooldowns.is_empty(), "%s must not start cooldown" % label)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("wall_leap_entry_gate_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
