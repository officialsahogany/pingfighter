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
	var live_skill_ids: Dictionary = {}

	func _init(ids: Array = [], live_ids: Array = []) -> void:
		for raw_id in ids:
			visible_skill_ids[str(raw_id)] = true
		for raw_live_id in live_ids:
			live_skill_ids[str(raw_live_id)] = true

	func has_visible_effects_for_skill(skill_id: String) -> bool:
		return bool(visible_skill_ids.get(skill_id, false))

	func is_launch_blocked(skill_id: String) -> bool:
		return bool(live_skill_ids.get(skill_id, false))


class LegacyRuntimeHost:
	extends RefCounted

	func has_visible_effects_for_skill(_skill_id: String) -> bool:
		return false


func _init() -> void:
	_verify_idle_skip_policy()
	_verify_invisible_but_live_skill_keeps_updating()
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


func _verify_invisible_but_live_skill_keeps_updating() -> void:
	# Structural seal for the "visible != live" trap. A skill whose last particle
	# died but that still owns runtime state -- a boss slip / boss freeze window,
	# a pending self-schedule (solar bolt refire, bubble trap queued shots), a
	# deferred ownerless release -- must keep receiving update(), or its timer
	# freezes for the whole remaining cooldown while consumers outside this gate
	# keep reading the stale state. `is_launch_blocked` is the host's liveness map.
	var gate := LingpetCompanionSkillEffectUpdateGate.new()
	var state := FakeSkillState.new()
	state.cooldown = 18.0
	var live_host := FakeRuntimeHost.new([], ["monkeyring_banana_slice"])
	_expect(
		not gate.can_skip_idle("monkeyring_banana_slice", state, true, live_host),
		"a skill with live runtime state but no visible effects must NOT be idle-skipped (frozen boss-slip class)"
	)
	_expect(
		not gate.can_skip_idle("monkeyring_banana_slice", state, false, live_host),
		"live runtime state should outrank the ball-inactive idle skip too"
	)
	var idle_host := FakeRuntimeHost.new([], [])
	_expect(
		gate.can_skip_idle("monkeyring_banana_slice", state, true, idle_host),
		"a genuinely idle skill on cooldown should still take the cheap idle-skip path"
	)
	# Hosts predating the liveness map must not crash the gate.
	_expect(
		gate.can_skip_idle("monkeyring_banana_slice", state, true, LegacyRuntimeHost.new()),
		"gate should tolerate a host without the liveness map"
	)


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
	var controller_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_skill_controller.gd")
	var owner_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_skill_effect_update_gate.gd")
	_expect(runtime_source.find("LingpetCompanionSkillEffectUpdateGate") < 0, "egg runtime should leave the skill effect update gate inside the skill controller")
	_expect(controller_source.find("LingpetCompanionSkillEffectUpdateGate") >= 0, "skill controller should compose the skill effect update gate")
	_expect(controller_source.find("_effect_update_gate.can_skip_idle") >= 0, "controller-owned slot tick should delegate idle skip decisions")
	_expect(runtime_source.find("_companion_skill_controller.reset_effect_update_counters_for_tests") >= 0, "runtime public test seam should forward counters through the skill controller")
	_expect(runtime_source.find("_skill_effect_update_counters_enabled_for_tests") < 0, "runtime should not keep skill-effect counter enable state locally")
	_expect(runtime_source.find("func _can_skip_companion_skill_effect_idle") < 0, "runtime should not keep idle-skip policy inline")
	_expect(owner_source.find("has_visible_effects_for_skill") >= 0, "gate should preserve the visible-effect guard")
	_expect(owner_source.find("is_launch_blocked") >= 0, "gate should preserve the live-runtime-state guard alongside the visible-effect guard")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
