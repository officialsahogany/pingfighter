extends SceneTree

const RuntimePerkAngelBlessingRuntimeState := preload("res://scripts/characters/runtime_perk_angel_blessing_runtime_state.gd")
const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_owner_boundary()
	_verify_direct_state_and_runtime_facade()
	if _failures.is_empty():
		print("runtime_perk_angel_blessing_runtime_state_refactor_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_owner_boundary() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var owner_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_angel_blessing_runtime_state.gd")
	_expect(RuntimePerkAngelBlessingRuntimeState != null, "Angel Blessing runtime-state owner should preload")
	_expect(
		runtime_source.find("RuntimePerkAngelBlessingRuntimeState") >= 0
		and runtime_source.find("var _angel_blessing_runtime_state: Object = RuntimePerkAngelBlessingRuntimeState.new()") >= 0,
		"runtime perk facade should construct one Angel Blessing feature-state owner"
	)
	for removed_storage: String in [
		"var _angel_blessing_state: Object = RuntimePerkAngelBlessingState.new()",
		"var _angel_blessing_cooldown_capability: Object = RuntimePerkAngelBlessingCooldownCapability.new()",
		"var _angel_blessing_stage_lifecycle: Object = RuntimePerkAngelBlessingStageLifecycle.new()",
		"var _angel_blessing_modal_flow: Object = RuntimePerkAngelBlessingModalFlow.new()",
		"var _angel_blessing_acquisition_lifecycle: Object = RuntimePerkAngelBlessingAcquisitionLifecycle.new()",
	]:
		_expect(runtime_source.find(removed_storage) < 0, "runtime facade should not retain Angel subsystem storage %s" % removed_storage)
	_expect(
		runtime_source.find("var _angel_blessing_state: Object:") >= 0
		and runtime_source.find("return _angel_blessing_runtime_state.get_state()") >= 0
		and runtime_source.find("var _angel_blessing_modal_flow: Object:") >= 0
		and runtime_source.find("return _angel_blessing_runtime_state.get_modal_flow()") >= 0,
		"legacy runtime-state lookup seams should be computed owner-backed properties"
	)
	_expect(
		owner_source.find("func roll_for_stage(") >= 0
		and owner_source.find("func get_eligible_buff_ids(") >= 0
		and owner_source.find("func on_ball_spawn_intro_finished(") >= 0
		and owner_source.find("func on_accepted_choice(") >= 0
		and owner_source.find("func on_acquisition_cinematic_finished(") >= 0
		and owner_source.find("func reset_state(") >= 0,
		"Angel owner should contain core, capability, stage, acquisition, and reset responsibilities"
	)
	_expect(
		owner_source.find("func get_acquisition_snapshot(") >= 0
		and owner_source.find("func update_acquisition_from_runtime_state(") >= 0
		and owner_source.find("func handle_spawn_intro_completion_from_runtime_state(") >= 0
		and owner_source.find("func handle_acquisition_input_from_runtime_state(") >= 0
		and owner_source.find("func finish_acquisition_cinematic_from_runtime_state(") >= 0
		and owner_source.find("func on_round_boundary_from_runtime_state(") >= 0
		and owner_source.find("func on_stage_transition_from_runtime_state(") >= 0,
		"Angel owner should own the complete acquisition modal and boundary transaction"
	)
	var spawn_intro_body := _function_body(runtime_source, "func on_ball_spawn_intro_finished(")
	var instant_finish_index := spawn_intro_body.find("_instant_choice_flow.on_ball_spawn_intro_finished_from_runtime_state")
	var angel_finish_index := spawn_intro_body.find("_angel_blessing_runtime_state.handle_spawn_intro_completion_from_runtime_state")
	_expect(
		instant_finish_index >= 0
		and angel_finish_index > instant_finish_index
		and spawn_intro_body.find("_angel_blessing_modal_flow.take_ready_roll_for_stage") < 0
		and spawn_intro_body.find("queue_reveal_from_roll_result") < 0,
		"spawn-intro facade should preserve instant-first ordering and delegate Angel details"
	)
	_expect(
		owner_source.find("func should_defer_next_choice(") >= 0
		and owner_source.find("func has_post_choice_blocker(") >= 0
		and owner_source.find("func continue_after_choice_from_runtime_state(") >= 0
		and owner_source.find("func try_resume_deferred_choices_from_runtime_state(") >= 0
		and owner_source.find("func finalize_deferred_choice_chain_from_runtime_state(") >= 0
		and owner_source.find("func get_owner_stage_from_runtime_state(") >= 0,
		"Angel owner should own deferred-choice and stage-policy decisions"
	)
	for wrapper_contract: Array in [
		["func get_angel_blessing_acquisition_snapshot(", "_angel_blessing_runtime_state.get_acquisition_snapshot"],
		["func update_angel_blessing_acquisition(", "_angel_blessing_runtime_state.update_acquisition_from_runtime_state"],
		["func handle_angel_blessing_input(", "_angel_blessing_runtime_state.handle_acquisition_input_from_runtime_state"],
		["func on_angel_blessing_acquisition_cinematic_finished(", "_angel_blessing_runtime_state.finish_acquisition_cinematic_from_runtime_state"],
		["func on_angel_blessing_round_boundary(", "_angel_blessing_runtime_state.on_round_boundary_from_runtime_state"],
		["func on_angel_blessing_stage_transition(", "_angel_blessing_runtime_state.on_stage_transition_from_runtime_state"],
		["func _should_defer_next_choice_for_angel_acquisition(", "_angel_blessing_runtime_state.should_defer_next_choice"],
		["func _has_angel_blessing_post_choice_blocker(", "_angel_blessing_runtime_state.has_post_choice_blocker"],
		["func _continue_angel_blessing_after_choice(", "_angel_blessing_runtime_state.continue_after_choice_from_runtime_state"],
		["func _try_resume_deferred_runtime_choices(", "_angel_blessing_runtime_state.try_resume_deferred_choices_from_runtime_state"],
		["func _finalize_angel_blessing_deferred_choice_chain(", "_angel_blessing_runtime_state.finalize_deferred_choice_chain_from_runtime_state"],
		["func _get_angel_blessing_owner_stage(", "_angel_blessing_runtime_state.get_owner_stage_from_runtime_state"],
	]:
		var body := _function_body(runtime_source, str(wrapper_contract[0]))
		_expect(body.find(str(wrapper_contract[1])) >= 0, "%s should delegate to the Angel owner" % str(wrapper_contract[0]))
	_expect(
		_function_body(runtime_source, "func update_angel_blessing_acquisition(").find("_angel_blessing_modal_flow.update") < 0
		and _function_body(runtime_source, "func _is_angel_blessing_open_blocked(").is_empty()
		and _function_body(runtime_source, "func _get_cached_angel_blocker_module(").is_empty(),
		"runtime Angel wrappers should not retain modal update or blocker policy bodies"
	)


func _verify_direct_state_and_runtime_facade() -> void:
	var owner := RuntimePerkAngelBlessingRuntimeState.new()
	var all_buff_ids: Array[String] = owner.get_state().get_all_buff_ids()
	var roll_result: Dictionary = owner.roll_for_stage(
		1,
		all_buff_ids,
		2,
		["move_speed", "gauge_max"]
	)
	_expect(bool(roll_result.get("rolled", false)), "owner should roll through the canonical Angel state")
	_expect(owner.get_snapshot().get("active_buff_ids", []) == ["move_speed", "gauge_max"], "owner should expose the committed Angel result")
	_expect(not owner.get_modal_flow().has_work(), "fresh owner modal flow should have no queued work")
	var revision_before_reset := int(owner.get_snapshot().get("revision", 0))
	owner.reset_state()
	_expect(int(owner.get_snapshot().get("revision", 0)) == revision_before_reset + 1, "owner reset should advance Angel revision exactly once")
	_expect(int(owner.get_snapshot().get("active_stage", -1)) == 0, "owner reset should clear the active Angel stage")

	var runtime := RuntimePerkState.new()
	_expect(
		RuntimePerkRuntimeStateAccess.get_object(runtime, "_angel_blessing_state") == runtime.get_angel_blessing_state(),
		"production runtime-state lookup should resolve the owner-backed Angel state"
	)
	_expect(
		RuntimePerkRuntimeStateAccess.get_object(runtime, "_angel_blessing_modal_flow") != null,
		"production runtime-state lookup should resolve the owner-backed Angel modal flow"
	)
	var runtime_roll: Dictionary = runtime.roll_angel_blessing_for_stage(
		2,
		runtime.get_angel_blessing_state().get_all_buff_ids(),
		1,
		["paddle_size"]
	)
	_expect(bool(runtime_roll.get("rolled", false)), "runtime facade should delegate canonical Angel rolls")
	runtime.reset()
	_expect(int(runtime.get_angel_blessing_snapshot().get("active_stage", -1)) == 0, "runtime full reset should clear the owner-backed Angel state")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	return source.substr(start) if next < 0 else source.substr(start, next - start)
