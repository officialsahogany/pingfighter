extends SceneTree

const LingpetCompanionSkillEffectUpdateGate := preload("res://scripts/lingpet/lingpet_companion_skill_effect_update_gate.gd")

var _failures: Array[String] = []


class FakeSkillState:
	extends RefCounted

	var cooldown := 0.0
	var windup_active := false


class FakeRuntimeHost:
	extends RefCounted

	var visible_skill_ids: Dictionary = {}

	func _init(ids: Array = []) -> void:
		for raw_id in ids:
			visible_skill_ids[str(raw_id)] = true

	func has_visible_effects_for_skill(skill_id: String) -> bool:
		return bool(visible_skill_ids.get(skill_id, false))


func _init() -> void:
	_verify_idle_skip_policy()
	_verify_counter_recording()
	_verify_runtime_delegates_idle_skip_gate()

	if _failures.is_empty():
		print("lingpet_companion_skill_effect_update_gate_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_idle_skip_policy() -> void:
	var gate := LingpetCompanionSkillEffectUpdateGate.new()
	var state := FakeSkillState.new()
	var host := FakeRuntimeHost.new()

	_expect(gate.can_skip_idle("maribo_hydro_sphere", state, false, host), "ball-inactive idle skill should skip runtime update")
	_expect(not gate.can_skip_idle("maribo_hydro_sphere", state, true, host), "active ball should keep runtime update live")
	state.cooldown = 4.0
	_expect(gate.can_skip_idle("maribo_hydro_sphere", state, true, host), "cooldown should skip runtime update even while the ball is active")
	state.windup_active = true
	_expect(not gate.can_skip_idle("maribo_hydro_sphere", state, false, host), "windup should never take the idle skip path")
	state.windup_active = false
	_expect(not gate.can_skip_idle("maribo_hydro_sphere", state, false, FakeRuntimeHost.new(["maribo_hydro_sphere"])), "visible skill effects should keep runtime update live")


func _verify_counter_recording() -> void:
	var gate := LingpetCompanionSkillEffectUpdateGate.new()
	gate.record_idle_skip()
	gate.record_runtime_update()
	_expect_eq(gate.get_idle_skip_count(), 0, "counters should stay disabled until a test reset enables them")
	_expect_eq(gate.get_runtime_update_count(), 0, "runtime counter should stay disabled until a test reset enables it")
	gate.reset_counters_for_tests()
	gate.record_idle_skip()
	gate.record_idle_skip()
	gate.record_runtime_update()
	_expect_eq(gate.get_idle_skip_count(), 2, "idle skip counter should record enabled skip events")
	_expect_eq(gate.get_runtime_update_count(), 1, "runtime update counter should record enabled update events")


func _verify_runtime_delegates_idle_skip_gate() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var owner_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_skill_effect_update_gate.gd")
	_expect(runtime_source.find("LingpetCompanionSkillEffectUpdateGate") >= 0, "egg runtime should preload the skill effect update gate")
	_expect(runtime_source.find("_companion_skill_effect_update_gate.can_skip_idle") >= 0, "runtime skill-effect hook should delegate idle skip decisions")
	_expect(runtime_source.find("_skill_effect_update_counters_enabled_for_tests") < 0, "runtime should not keep skill-effect counter enable state locally")
	_expect(runtime_source.find("func _can_skip_companion_skill_effect_idle") < 0, "runtime should not keep idle-skip policy inline")
	_expect(owner_source.find("has_visible_effects_for_skill") >= 0, "gate should preserve the visible-effect guard")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
