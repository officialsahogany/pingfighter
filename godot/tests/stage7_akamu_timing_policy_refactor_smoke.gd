extends SceneTree

const TIMING_POLICY_PATH := "res://scripts/stages/stage7/stage7_akamu_timing_policy.gd"
const HOST_PATH := "res://scripts/stages/stage7/stage7_akamu_state.gd"

var _failures: Array[String] = []


class FakeActiveItemRuntime:
	extends RefCounted

	var context: Dictionary = {}
	var request_count := 0

	func get_boss_ai_context() -> Dictionary:
		request_count += 1
		return context


func _init() -> void:
	_verify_owner_boundary()
	_verify_gameplay_timing_freeze_contract()
	_verify_direct_cooldown_pause_precedence()
	_verify_runtime_cooldown_pause_fallback()

	if _failures.is_empty():
		print("stage7_akamu_timing_policy_refactor_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_owner_boundary() -> void:
	_expect(FileAccess.file_exists(TIMING_POLICY_PATH), "Stage 7 timing gates should have a focused policy owner")
	if not FileAccess.file_exists(TIMING_POLICY_PATH):
		return
	var host_source := FileAccess.get_file_as_string(HOST_PATH)
	var policy_source := FileAccess.get_file_as_string(TIMING_POLICY_PATH)
	_expect(
		host_source.find("const Stage7AkamuTimingPolicy := preload(\"%s\")" % TIMING_POLICY_PATH) >= 0,
		"Stage7AkamuState should preload the focused timing policy"
	)
	_expect(
		host_source.find("var _timing_policy: Object = Stage7AkamuTimingPolicy.new()") >= 0,
		"Stage7AkamuState should retain one timing policy instance"
	)
	for marker in [
		"func is_gameplay_timing_frozen(",
		"func is_context_boss_skill_cooldown_paused(",
		"func is_boss_skill_cooldown_paused(",
	]:
		_expect(policy_source.find(marker) >= 0, "focused timing policy should implement %s" % marker)
	_expect(
		host_source.find("_timing_policy.is_gameplay_timing_frozen(context)") >= 0,
		"gameplay timing gate should delegate to the focused policy"
	)
	_expect(
		host_source.find("_timing_policy.is_boss_skill_cooldown_paused(context, deps)") >= 0,
		"full cooldown-pause checks should delegate to the focused policy"
	)
	_expect(
		host_source.find("_timing_policy.is_context_boss_skill_cooldown_paused(context)") >= 0,
		"Wind Aura should preserve its direct-context-only pause contract through the policy"
	)
	for moved_key in [
		"\"active_item_stopwatch_freeze_active\"",
		"\"viper_nerve_strike_freeze_active\"",
		"\"lingpet_star_coil_freeze_boss_skill_cd\"",
		"\"active_item_tear_gas_cooldown_pause_active\"",
	]:
		_expect(host_source.find(moved_key) < 0, "Stage7AkamuState should not retain timing policy key %s" % moved_key)


func _verify_gameplay_timing_freeze_contract() -> void:
	var policy: Object = _new_policy()
	if policy == null:
		return
	var base_context := {
		"ball_active": true,
		"waiting_for_serve": false,
	}
	_expect(not policy.is_gameplay_timing_frozen(base_context), "active served play should advance Stage 7 timing")
	for key in [
		"waiting_for_serve",
		"gameplay_timing_frozen",
		"stopwatch_freeze_active",
		"active_item_stopwatch_freeze_active",
		"perk_resume_freeze_active",
		"power_smashing_freeze_active",
		"viper_dmk_freeze_active",
		"viper_nerve_strike_freeze_active",
	]:
		var context: Dictionary = base_context.duplicate()
		context[key] = true
		_expect(policy.is_gameplay_timing_frozen(context), "%s should freeze Stage 7 timing" % key)
	var inactive_ball: Dictionary = base_context.duplicate()
	inactive_ball["ball_active"] = false
	_expect(policy.is_gameplay_timing_frozen(inactive_ball), "inactive ball should freeze Stage 7 timing")


func _verify_direct_cooldown_pause_precedence() -> void:
	var policy: Object = _new_policy()
	if policy == null:
		return
	_expect(
		policy.is_context_boss_skill_cooldown_paused({"lingpet_star_coil_freeze_boss_skill_cd": true}),
		"Star Coil should pause boss-skill cooldowns"
	)
	_expect(
		policy.is_context_boss_skill_cooldown_paused({"active_item_boss_skill_cooldown_paused": true}),
		"canonical active-item pause key should be honored"
	)
	_expect(
		policy.is_context_boss_skill_cooldown_paused({"active_item_tear_gas_cooldown_pause_active": true}),
		"legacy Tear Gas pause key should remain a fallback"
	)
	_expect(
		not policy.is_context_boss_skill_cooldown_paused({
			"active_item_boss_skill_cooldown_paused": false,
			"active_item_tear_gas_cooldown_pause_active": true,
		}),
		"explicit canonical false should override the legacy Tear Gas fallback"
	)


func _verify_runtime_cooldown_pause_fallback() -> void:
	var policy: Object = _new_policy()
	if policy == null:
		return
	var runtime := FakeActiveItemRuntime.new()
	runtime.context = {"active_item_tear_gas_cooldown_pause_active": true}
	_expect(
		policy.is_boss_skill_cooldown_paused({}, {"active_item_runtime": runtime}),
		"active-item runtime context should provide the legacy pause fallback"
	)
	_expect(runtime.request_count == 1, "runtime fallback should request one boss-AI context snapshot")
	runtime.context = {
		"active_item_boss_skill_cooldown_paused": false,
		"active_item_tear_gas_cooldown_pause_active": true,
	}
	_expect(
		not policy.is_boss_skill_cooldown_paused({}, {"active_item_runtime": runtime}),
		"runtime canonical false should override its legacy fallback"
	)
	var before_direct := runtime.request_count
	_expect(
		policy.is_boss_skill_cooldown_paused(
			{"lingpet_star_coil_freeze_boss_skill_cd": true},
			{"active_item_runtime": runtime}
		),
		"direct Star Coil pause should remain authoritative"
	)
	_expect(runtime.request_count == before_direct, "authoritative direct pause should not query active-item runtime")
	_expect(
		not policy.is_boss_skill_cooldown_paused({}, {"active_item_runtime": RefCounted.new()}),
		"runtime without a boss-AI context method should not pause cooldowns"
	)


func _new_policy() -> Object:
	if not FileAccess.file_exists(TIMING_POLICY_PATH):
		return null
	var policy_script: Script = load(TIMING_POLICY_PATH)
	return policy_script.new()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
