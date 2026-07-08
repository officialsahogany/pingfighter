extends SceneTree

const RuntimePerkChoiceActionRunner := preload("res://scripts/characters/runtime_perk_choice_action_runner.gd")
const RuntimePerkChoiceApplyFlow := preload("res://scripts/characters/runtime_perk_choice_apply_flow.gd")
const RuntimePerkChoiceDispatch := preload("res://scripts/characters/runtime_perk_choice_dispatch.gd")
const RuntimePerkChoiceStandardPath := preload("res://scripts/characters/runtime_perk_choice_standard_path.gd")
const RuntimePerkInstantRewards := preload("res://scripts/characters/runtime_perk_instant_rewards.gd")
const RuntimePerkLevelSideEffects := preload("res://scripts/characters/runtime_perk_level_side_effects.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_action_path_runs_before_standard_level()
	_verify_unlock_path_delegates_to_state_callback()
	_verify_level_path_updates_runtime_state()
	_verify_runtime_state_facade_owns_deps_and_defaults()
	_verify_source_contract()

	if _failures.is_empty():
		print("runtime_perk_choice_apply_flow_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_action_path_runs_before_standard_level() -> void:
	var state := FakeRuntimeState.new()
	var levels: Dictionary = {}
	var result: Dictionary = _helper().apply_choice(
		{"id": "lingpet_affinity_chip", "name": "Affinity"},
		FakeOwner.new(),
		FakeRegistry.new(),
		state,
		levels,
		state.pending_skill_choices,
		state.starpoint_for_skills,
		RuntimePerkChoiceDispatch.new(),
		RuntimePerkChoiceActionRunner.new(),
		RuntimePerkChoiceStandardPath.new(),
		RuntimePerkInstantRewards.new(),
		RuntimePerkLevelSideEffects.new(),
		1,
		"lingpet_affinity_chip",
		"lingpet_ring_core_upgrade",
		_helper().build_state_callbacks(state),
		null
	)
	_expect(bool(result.get("accepted", false)), "apply-flow action path should accept handled actions")
	_expect(bool(result.get("handled", false)), "apply-flow action path should report handled actions")
	_expect(state.affinity_chip_calls == 1, "apply-flow action path should route through action-runner callbacks")
	_expect(state.feedback_calls == 1, "apply-flow action path should apply handled action feedback")
	_expect(levels.is_empty(), "handled action path should not fall through to runtime_skill_levels")
	_expect(state.level_side_effect_calls == 0, "handled action path should not run level side effects")


func _verify_unlock_path_delegates_to_state_callback() -> void:
	var state := FakeRuntimeState.new()
	var result: Dictionary = _helper().apply_choice(
		{"id": "unlock_plasma", "name": "Plasma", "unlocks_skill": "plasma"},
		FakeOwner.new(),
		FakeRegistry.new(),
		state,
		{},
		state.pending_skill_choices,
		state.starpoint_for_skills,
		RuntimePerkChoiceDispatch.new(),
		RuntimePerkChoiceActionRunner.new(),
		RuntimePerkChoiceStandardPath.new(),
		RuntimePerkInstantRewards.new(),
		RuntimePerkLevelSideEffects.new(),
		1,
		"lingpet_affinity_chip",
		"lingpet_ring_core_upgrade",
		_helper().build_state_callbacks(state),
		null
	)
	_expect(bool(result.get("accepted", false)), "apply-flow unlock path should accept callback success")
	_expect(state.unlock_calls == 1, "apply-flow unlock path should call the unlock callback once")
	_expect(state.level_side_effect_calls == 0, "apply-flow unlock path should not run level side effects")


func _verify_level_path_updates_runtime_state() -> void:
	var state := FakeRuntimeState.new()
	state.pending_skill_choices = 2
	var levels: Dictionary = {}
	var result: Dictionary = _helper().apply_choice(
		{"id": "common_bulk_up", "name": "Bulk", "max_level": 5},
		FakeOwner.new(),
		FakeRegistry.new(),
		state,
		levels,
		state.pending_skill_choices,
		state.starpoint_for_skills,
		RuntimePerkChoiceDispatch.new(),
		RuntimePerkChoiceActionRunner.new(),
		RuntimePerkChoiceStandardPath.new(),
		RuntimePerkInstantRewards.new(),
		RuntimePerkLevelSideEffects.new(),
		1,
		"lingpet_affinity_chip",
		"lingpet_ring_core_upgrade",
		_helper().build_state_callbacks(state),
		null
	)
	_expect(bool(result.get("accepted", false)), "apply-flow level path should accept ordinary level choices")
	_expect(int(levels.get("common_bulk_up", 0)) == 1, "apply-flow level path should update runtime_skill_levels")
	_expect(state.pending_skill_choices == 2, "apply-flow level path should preserve pending choice state")
	_expect(state.level_side_effect_calls == 1, "apply-flow level path should call level side effects once")
	_expect(state.feedback_calls == 1, "apply-flow level path should apply level feedback once")


func _verify_runtime_state_facade_owns_deps_and_defaults() -> void:
	var state := FakeRuntimeState.new()
	_attach_apply_flow_deps(state)
	state.pending_skill_choices = 2
	var result: Dictionary = _helper().apply_choice_from_runtime_state(
		state,
		{"id": "common_facade_bulk_up", "name": "Facade Bulk", "max_level": 5},
		FakeOwner.new(),
		FakeRegistry.new()
	)
	_expect(bool(result.get("accepted", false)), "runtime-state facade should accept ordinary choices")
	_expect(
		int(state.runtime_skill_levels.get("common_facade_bulk_up", 0)) == 1,
		"runtime-state facade should pass live runtime_skill_levels into the apply flow"
	)
	_expect(state.feedback_calls == 1, "runtime-state facade should build state callbacks internally")
	_expect(state.level_side_effect_calls == 1, "runtime-state facade should route level side effects")
	_expect(
		RuntimePerkChoiceApplyFlow.DEFAULT_STARPOINT_PER_SKILL_CHOICE == RuntimePerkState.STARPOINT_PER_SKILL_CHOICE,
		"apply-flow facade starpoint default should mirror RuntimePerkState"
	)
	_expect(
		RuntimePerkChoiceApplyFlow.DEFAULT_LINGPET_AFFINITY_CHIP_CHOICE_ID == RuntimePerkState.LINGPET_AFFINITY_CHIP_CHOICE_ID,
		"apply-flow facade affinity-chip default should mirror RuntimePerkState"
	)
	_expect(
		RuntimePerkChoiceApplyFlow.DEFAULT_LINGPET_RING_CORE_UPGRADE_CHOICE_ID == RuntimePerkState.LINGPET_RING_CORE_UPGRADE_CHOICE_ID,
		"apply-flow facade ring-core default should mirror RuntimePerkState"
	)


func _verify_source_contract() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_apply_flow.gd")
	var apply_body: String = _function_body(state_source, "func apply_choice(")
	var facade_body: String = _function_body(helper_source, "func apply_choice_from_runtime_state(")
	_expect(state_source.find("RuntimePerkChoiceApplyFlow") >= 0, "state should preload choice apply-flow helper")
	_expect(apply_body.find("_choice_apply_flow.apply_choice_from_runtime_state") >= 0, "state apply_choice should delegate to apply-flow facade")
	_expect(apply_body.find("_choice_dispatch.build_dispatch") < 0, "state apply_choice should not build dispatch payloads directly")
	_expect(apply_body.find("_choice_action_runner.run_dispatch") < 0, "state apply_choice should not run action dispatch directly")
	_expect(apply_body.find("_choice_standard_path.build_path_from_bookkeeping_choice") < 0, "state apply_choice should not build standard paths directly")
	_expect(apply_body.find("_choice_standard_path.apply_level_choice_to_runtime_state") < 0, "state apply_choice should not apply level paths directly")
	_expect(apply_body.find("_apply_unlock_choice(choice") < 0, "state apply_choice should not call unlock application directly")
	_expect(apply_body.find("_apply_level_side_effect(choice") < 0, "state apply_choice should not call level side effects directly")
	_expect(apply_body.find("runtime_skill_levels") < 0, "state apply_choice should not pass runtime_skill_levels inline")
	_expect(apply_body.find("pending_skill_choices") < 0, "state apply_choice should not pass pending choice state inline")
	_expect(apply_body.find("starpoint_for_skills") < 0, "state apply_choice should not pass starpoint state inline")
	_expect(apply_body.find("_choice_dispatch") < 0, "state apply_choice should not pass choice-dispatch helper inline")
	_expect(apply_body.find("_choice_action_runner") < 0, "state apply_choice should not pass action-runner helper inline")
	_expect(apply_body.find("_choice_standard_path") < 0, "state apply_choice should not pass standard-path helper inline")
	_expect(apply_body.find("_instant_rewards") < 0, "state apply_choice should not pass instant-reward helper inline")
	_expect(apply_body.find("_level_side_effects") < 0, "state apply_choice should not pass level-side-effect helper inline")
	_expect(apply_body.find("STARPOINT_PER_SKILL_CHOICE") < 0, "state apply_choice should not pass starpoint constants inline")
	_expect(apply_body.find("LINGPET_AFFINITY_CHIP_CHOICE_ID") < 0, "state apply_choice should not pass affinity constants inline")
	_expect(apply_body.find("LINGPET_RING_CORE_UPGRADE_CHOICE_ID") < 0, "state apply_choice should not pass ring-core constants inline")
	_expect(apply_body.find("build_state_callbacks(self)") < 0, "state apply_choice should not build callback map inline")
	_expect(state_source.find("func _build_choice_action_callbacks(") < 0, "state should not keep a choice-action callback wrapper")
	_expect(helper_source.find("func apply_choice_from_runtime_state(") >= 0, "apply-flow helper should expose a runtime-state facade")
	_expect(facade_body.find("_get_runtime_state_object(runtime_state, \"_choice_dispatch\")") >= 0, "apply-flow facade should own dispatch helper lookup")
	_expect(facade_body.find("_get_runtime_state_dict(runtime_state, \"runtime_skill_levels\")") >= 0, "apply-flow facade should own runtime level lookup")
	_expect(facade_body.find("DEFAULT_STARPOINT_PER_SKILL_CHOICE") >= 0, "apply-flow facade should own starpoint default")
	_expect(facade_body.find("DEFAULT_LINGPET_AFFINITY_CHIP_CHOICE_ID") >= 0, "apply-flow facade should own affinity-chip default")
	_expect(facade_body.find("DEFAULT_LINGPET_RING_CORE_UPGRADE_CHOICE_ID") >= 0, "apply-flow facade should own ring-core default")
	_expect(facade_body.find("build_state_callbacks(runtime_state)") >= 0, "apply-flow facade should build callback map internally")
	_expect(helper_source.find("build_dispatch") >= 0, "apply-flow helper should own dispatch payload consumption")
	_expect(helper_source.find("run_dispatch") >= 0, "apply-flow helper should own action runner sequencing")
	_expect(helper_source.find("build_path_from_bookkeeping_choice") >= 0, "apply-flow helper should own standard path selection")
	_expect(helper_source.find("apply_level_choice_to_runtime_state") >= 0, "apply-flow helper should own level path sequencing")
	_expect(helper_source.find("CALLBACK_APPLY_UNLOCK_CHOICE") >= 0, "apply-flow helper should expose unlock application callback")
	_expect(helper_source.find("CALLBACK_APPLY_LEVEL_SIDE_EFFECT") >= 0, "apply-flow helper should expose level side-effect callback")


func _helper() -> Object:
	return RuntimePerkChoiceApplyFlow.new()


func _attach_apply_flow_deps(state: FakeRuntimeState) -> void:
	state._choice_dispatch = RuntimePerkChoiceDispatch.new()
	state._choice_action_runner = RuntimePerkChoiceActionRunner.new()
	state._choice_standard_path = RuntimePerkChoiceStandardPath.new()
	state._instant_rewards = RuntimePerkInstantRewards.new()
	state._level_side_effects = RuntimePerkLevelSideEffects.new()


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class FakeRuntimeState:
	extends RefCounted

	var pending_skill_choices := 0
	var starpoint_for_skills := 0
	var runtime_skill_levels: Dictionary = {}
	var feedback_text := ""
	var feedback_timer := 0.0
	var unlock_calls := 0
	var level_side_effect_calls := 0
	var feedback_calls := 0
	var affinity_chip_calls := 0
	var _choice_dispatch: Object = null
	var _choice_action_runner: Object = null
	var _choice_standard_path: Object = null
	var _instant_rewards: Object = null
	var _level_side_effects: Object = null

	func _should_defer_full_gauge_until_spawn_intro_end() -> bool:
		return false

	func _should_defer_dimension_gate_until_spawn_intro_end() -> bool:
		return false

	func _apply_choice_feedback_result(result: Dictionary, _choice: Dictionary, fallback_timer: float) -> bool:
		feedback_calls += 1
		feedback_text = str(result.get("feedback_text", ""))
		feedback_timer = float(result.get("feedback_timer", fallback_timer))
		return bool(result.get("accepted", false))

	func _apply_unlock_choice(_choice: Dictionary, _owner: Object, _registry: Object, _perf_logger: Object = null) -> bool:
		unlock_calls += 1
		return true

	func _apply_level_side_effect(_choice: Dictionary, _owner: Object, _registry: Object, _perf_logger: Object = null) -> void:
		level_side_effect_calls += 1

	func _apply_lingpet_affinity_chip(_owner: Object, _registry: Object, choice_name: String = "") -> Dictionary:
		affinity_chip_calls += 1
		return {"accepted": true, "feedback_text": choice_name, "feedback_timer": 1.1}

	func _apply_convert_to_gold_choice(_choice: Dictionary, _owner: Object, _registry: Object) -> bool:
		return true

	func _queue_full_gauge_after_spawn_intro_choice(_owner: Object, choice_name: String = "") -> Dictionary:
		return {"accepted": true, "feedback_text": choice_name}

	func _apply_full_gauge_choice(_owner: Object, _registry: Object) -> Dictionary:
		return {"accepted": true}

	func _queue_dimension_gate_after_spawn_intro_choice(_owner: Object, choice_name: String = "") -> Dictionary:
		return {"accepted": true, "feedback_text": choice_name}

	func _apply_dimension_gate_choice(_registry: Object) -> Dictionary:
		return {"accepted": true}

	func _apply_monkey_blessing_choice(_owner: Object, _registry: Object, choice_name: String = "") -> Dictionary:
		return {"accepted": true, "feedback_text": choice_name}

	func _apply_treasure_hunt_choice(_owner: Object, _registry: Object) -> Dictionary:
		return {"accepted": true}

	func _apply_lingpet_ring_core_upgrade(_owner: Object, _registry: Object, _requested_tier: int = 0, choice_name: String = "") -> Dictionary:
		return {"accepted": true, "feedback_text": choice_name}


class FakeOwner:
	extends RefCounted


class FakeRegistry:
	extends RefCounted
