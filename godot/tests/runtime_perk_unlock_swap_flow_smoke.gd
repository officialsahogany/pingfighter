extends SceneTree

const RuntimePerkUnlockSwapFlow := preload("res://scripts/characters/runtime_perk_unlock_swap_flow.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []
var _sync_owner_calls := 0
var _commit_level_calls := 0
var _sync_owner_effect_calls := 0
var _completion_state_update_calls := 0
var _completion_showcase_calls := 0
var _completion_showcase_choice_id := ""
var _completion_showcase_choice: Dictionary = {}
var _selection_state_update_calls := 0
var _selection_update_index := -1


func _init() -> void:
	_verify_start_gate_and_payload()
	_verify_query_helpers()
	_verify_feedback_payloads()
	_verify_selection_payloads()
	_verify_confirm_request_payload()
	_verify_confirm_orchestration()
	_verify_state_facing_confirm_orchestration()
	_verify_state_update_application()
	_verify_swap_apply_and_cleanup()
	_verify_commando_weapon_sync()

	if _failures.is_empty():
		print("runtime_perk_unlock_swap_flow_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_query_helpers() -> void:
	var flow := RuntimePerkUnlockSwapFlow.new()
	var pending := {"choice_id": "soldier_unlock_bowling_trap", "nested": {"value": 1}}
	_expect(flow.has_pending_swap(pending), "query helper should detect pending swap payloads")
	_expect(not flow.has_pending_swap({}), "query helper should reject empty pending swap payloads")
	var snapshot: Dictionary = flow.get_pending_swap_snapshot(pending)
	snapshot["choice_id"] = "mutated"
	_get_dict(snapshot.get("nested", {}))["value"] = 9
	_expect(str(pending.get("choice_id", "")) == "soldier_unlock_bowling_trap", "query helper should deep-copy pending swap snapshots")
	_expect(int(_get_dict(pending.get("nested", {})).get("value", 0)) == 1, "query helper should deep-copy nested pending swap data")
	_expect(flow.get_selected_index(3) == 3, "query helper should preserve selected index")
	var payload_for_count: Dictionary = flow.build_pending_swap(_choice(), FakeSkillConfig.new())
	_expect(flow.get_candidate_count(payload_for_count) == 3, "query helper should count pending swap candidates")
	_expect(flow.has_candidates(payload_for_count), "query helper should detect pending swap candidates")
	_expect(flow.get_candidate_count({}) == 0, "query helper should return zero for missing candidate payloads")
	_expect(not flow.has_candidates({}), "query helper should reject missing candidate payloads")

	var query_state := FakeRuntimeState.new()
	query_state.pending_unlock_swap = pending.duplicate(true)
	query_state.unlock_swap_selected_index = 2
	_expect(flow.has_pending_swap_from_runtime_state(query_state), "runtime-state query should detect pending swap payloads")
	var query_snapshot: Dictionary = flow.get_pending_swap_snapshot_from_runtime_state(query_state)
	query_snapshot["choice_id"] = "mutated"
	_expect(str(query_state.pending_unlock_swap.get("choice_id", "")) == "soldier_unlock_bowling_trap", "runtime-state query should deep-copy pending swap snapshots")
	_expect(flow.get_selected_index_from_runtime_state(query_state) == 2, "runtime-state query should read selected swap index")
	_expect(not flow.has_pending_swap_from_runtime_state(null), "runtime-state query should reject missing state")
	_expect(flow.get_pending_swap_snapshot_from_runtime_state(null).is_empty(), "runtime-state snapshot query should reject missing state")
	_expect(flow.get_selected_index_from_runtime_state(null) == 0, "runtime-state selected-index query should default missing state to zero")

	var state := RuntimePerkState.new()
	state.pending_unlock_swap = pending.duplicate(true)
	state.unlock_swap_selected_index = 2
	_expect(state.has_pending_unlock_swap(), "state pending-swap query should delegate to helper")
	_expect(state.get_unlock_swap_selected_index() == 2, "state selected-index query should delegate to helper")
	var state_snapshot: Dictionary = state.get_pending_unlock_swap()
	state_snapshot["choice_id"] = "mutated"
	_expect(str(state.pending_unlock_swap.get("choice_id", "")) == "soldier_unlock_bowling_trap", "state pending-swap snapshot should be deep-copied")
	state.pending_unlock_swap.clear()
	_expect(not state.has_pending_unlock_swap(), "state pending-swap query should reject empty state")

	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	_expect(state_source.find("_unlock_swap_flow.has_pending_swap_from_runtime_state") >= 0, "state should delegate runtime-state pending-swap existence checks")
	_expect(state_source.find("_unlock_swap_flow.get_pending_swap_snapshot_from_runtime_state") >= 0, "state should delegate runtime-state pending-swap snapshots")
	_expect(state_source.find("_unlock_swap_flow.get_selected_index_from_runtime_state") >= 0, "state should delegate runtime-state swap selected-index query")
	_expect(state_source.find("return not pending_unlock_swap.is_empty()") < 0, "state should not inline pending-swap existence query")
	_expect(state_source.find("return pending_unlock_swap.duplicate(true)") < 0, "state should not inline pending-swap snapshot duplication")
	_expect(state_source.find("return unlock_swap_selected_index") < 0, "state should not inline swap selected-index query")
	_expect(state_source.find("if pending_unlock_swap.is_empty():") < 0, "state should route pending-swap empty guards through the public query")


func _verify_start_gate_and_payload() -> void:
	var flow := RuntimePerkUnlockSwapFlow.new()
	var config := FakeSkillConfig.new()
	_expect(flow.should_start_swap(config, "bowling_trap", "commando"), "commando alias should use soldier swap flow")
	_expect(flow.should_start_swap(config, "bowling_trap", "smasher"), "shared-slot configs should own cross-character swap eligibility")
	_expect(not flow.should_start_swap(config, "net_gun", "soldier"), "already equipped skill should not start swap")

	var payload: Dictionary = flow.build_pending_swap(_choice(), config)
	_expect(str(payload.get("choice_id", "")) == "soldier_unlock_bowling_trap", "payload should preserve choice id")
	_expect(str(payload.get("unlocks_skill", "")) == "bowling_trap", "payload should preserve unlocked skill")
	_expect(str(payload.get("new_name", "")) == "K bowling_trap", "payload should use skill-config display name")
	var candidates: Array = _get_array(payload.get("candidates", []))
	_expect(candidates.size() == 3, "payload should include each shared-slot swap candidate")
	if candidates.size() == 3:
		_expect(str(_get_dict(candidates[0]).get("name", "")) == "K net_gun", "candidate names should use skill-config Korean data")

	var start_update: Dictionary = flow.build_start_state_update(payload)
	_expect(bool(start_update.get("accepted", false)), "start state update should accept non-empty pending swap")
	_expect(str(_get_dict(start_update.get("pending_unlock_swap", {})).get("choice_id", "")) == "soldier_unlock_bowling_trap", "start state update should carry pending swap")
	_expect(int(start_update.get("unlock_swap_selected_index", -1)) == 0, "start state update should reset selected index")
	_expect(int(start_update.get("gamepad_unlock_swap_horizontal_latch", -1)) == 0, "start state update should reset gamepad latch")
	_expect(bool(start_update.get("sync_owner", false)), "start state update should request owner sync")
	var copied_payload: Dictionary = _get_dict(start_update.get("pending_unlock_swap", {}))
	copied_payload["choice_id"] = "mutated"
	_expect(str(payload.get("choice_id", "")) == "soldier_unlock_bowling_trap", "start state update should deep-copy pending swap payload")


func _verify_feedback_payloads() -> void:
	var flow := RuntimePerkUnlockSwapFlow.new()
	var cancel_feedback: Dictionary = flow.build_cancel_feedback()
	_expect(str(cancel_feedback.get("feedback_text", "")) == RuntimePerkUnlockSwapFlow.SWAP_CANCEL_FEEDBACK_TEXT, "cancel feedback text should be helper-owned")
	_expect(is_equal_approx(float(cancel_feedback.get("feedback_timer", 0.0)), RuntimePerkUnlockSwapFlow.SWAP_CANCEL_FEEDBACK_TIMER), "cancel feedback timer should be helper-owned")

	var confirm_feedback: Dictionary = flow.build_confirm_feedback(_choice())
	_expect(str(confirm_feedback.get("feedback_text", "")) == "Bowling Trap 교체 완료", "confirm feedback should use choice display name")
	_expect(is_equal_approx(float(confirm_feedback.get("feedback_timer", 0.0)), RuntimePerkUnlockSwapFlow.SWAP_COMPLETE_FEEDBACK_TIMER), "confirm feedback timer should be helper-owned")

	var cancel_update: Dictionary = flow.build_cancel_state_update()
	_expect(bool(cancel_update.get("clear_pending_unlock_swap", false)), "cancel state update should clear pending swap")
	_expect(bool(cancel_update.get("clear_current_choice_context", false)), "cancel state update should clear choice context")
	_expect(bool(cancel_update.get("sync_owner", false)), "cancel state update should request owner sync")
	_expect(str(_get_dict(cancel_update.get("feedback_result", {})).get("feedback_text", "")) == RuntimePerkUnlockSwapFlow.SWAP_CANCEL_FEEDBACK_TEXT, "cancel state update should carry cancel feedback")

	var confirm_update: Dictionary = flow.build_confirm_state_update(_choice())
	_expect(bool(confirm_update.get("clear_pending_unlock_swap", false)), "confirm state update should clear pending swap")
	_expect(not bool(confirm_update.get("clear_current_choice_context", false)), "confirm state update should leave choice context for showcase finish")
	_expect(str(_get_dict(confirm_update.get("feedback_result", {})).get("feedback_text", "")) == str(confirm_feedback.get("feedback_text", "")), "confirm state update should carry confirm feedback")

	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_unlock_swap_flow.gd")
	var unlock_apply_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_unlock_choice_apply.gd")
	var cancel_body := _function_body(state_source, "func cancel_pending_unlock_swap(")
	_expect(unlock_apply_source.find("build_start_state_update") >= 0, "unlock-apply helper should consume start state update helper")
	_expect(state_source.find("_unlock_choice_apply.apply_choice") >= 0, "state should route unlock-choice start flow through unlock-apply helper")
	_expect(helper_source.find("func cancel_pending_swap_from_runtime_state(") >= 0, "helper should expose runtime-state cancel orchestration")
	_expect(cancel_body.find("_unlock_swap_flow.cancel_pending_swap_from_runtime_state") >= 0, "state cancel wrapper should delegate runtime-state cancel orchestration")
	_expect(cancel_body.find("has_pending_unlock_swap") < 0, "state cancel wrapper should not guard pending swap inline")
	_expect(cancel_body.find("build_cancel_state_update") < 0, "state cancel wrapper should not build cancel state updates inline")
	_expect(state_source.find("_unlock_swap_flow.confirm_pending_swap_from_runtime_state") >= 0, "state should consume state-facing confirm orchestration helper")
	_expect(helper_source.find("build_confirm_completion_plan") >= 0, "helper should own confirm completion-plan construction")
	_expect(state_source.find("apply_state_update_and_sync_owner_from_runtime_state") >= 0, "state should delegate runtime-state swap state application and owner sync to helper")
	_expect(state_source.find("build_cancel_feedback") < 0, "state should not consume raw cancel feedback helper")
	_expect(state_source.find("build_confirm_feedback") < 0, "state should not consume raw confirm feedback helper")
	_expect(state_source.find("build_confirm_completion_plan") < 0, "state should not consume confirm completion-plan helper directly")
	_expect(state_source.find("feedback_timer = 0.8") < 0, "state should not own swap cancel timer literal")
	_expect(state_source.find("pending_unlock_swap = _get_dict(update.get") < 0, "state should not inline pending-swap payload application")
	_expect(state_source.find("pending_unlock_swap.clear()") < 0, "state should not inline pending-swap clearing")
	_expect(state_source.find("gamepad_unlock_swap_horizontal_latch = int(update.get") < 0, "state should not inline swap gamepad latch application")


func _verify_selection_payloads() -> void:
	var flow := RuntimePerkUnlockSwapFlow.new()
	var move_forward: Dictionary = flow.build_move_selection_state_update(1, 1, 3)
	_expect(int(move_forward.get("unlock_swap_selected_index", -1)) == 2, "swap move should advance inside range")
	var wrap_forward: Dictionary = flow.build_move_selection_state_update(2, 1, 3)
	_expect(int(wrap_forward.get("unlock_swap_selected_index", -1)) == 0, "swap move should wrap forward")
	var wrap_backward: Dictionary = flow.build_move_selection_state_update(0, -1, 3)
	_expect(int(wrap_backward.get("unlock_swap_selected_index", -1)) == 2, "swap move should wrap backward")
	_expect(not bool(flow.build_move_selection_state_update(0, 1, 0).get("accepted", false)), "swap move should reject empty candidates")

	var direct: Dictionary = flow.build_direct_selection_state_update(1, 3)
	_expect(bool(direct.get("accepted", false)), "swap direct selection should accept in-range indices")
	_expect(int(direct.get("unlock_swap_selected_index", -1)) == 1, "swap direct selection should preserve chosen index")
	_expect(not bool(flow.build_direct_selection_state_update(-1, 3).get("accepted", false)), "swap direct selection should reject negative indices")
	_expect(not bool(flow.build_direct_selection_state_update(3, 3).get("accepted", false)), "swap direct selection should reject candidate-count index")

	var pending_swap: Dictionary = flow.build_pending_swap(_choice(), FakeSkillConfig.new())
	var pending_move: Dictionary = flow.build_move_selection_for_pending_swap(pending_swap, 2, 1)
	_expect(int(pending_move.get("unlock_swap_selected_index", -1)) == 0, "pending-swap move should use helper-owned candidate count")
	var pending_direct: Dictionary = flow.build_direct_selection_for_pending_swap(pending_swap, 2)
	_expect(int(pending_direct.get("unlock_swap_selected_index", -1)) == 2, "pending-swap direct selection should use helper-owned candidate count")
	_expect(not bool(flow.build_direct_selection_for_pending_swap(pending_swap, 3).get("accepted", false)), "pending-swap direct selection should reject out-of-range indices")

	var runtime_state := FakeRuntimeState.new()
	runtime_state.pending_unlock_swap = pending_swap.duplicate(true)
	runtime_state.unlock_swap_selected_index = 2
	var runtime_move: Dictionary = flow.move_selection_from_runtime_state(runtime_state, 1)
	_expect(bool(runtime_move.get("accepted", false)), "runtime-state swap move facade should accept pending swap")
	_expect(runtime_state.unlock_swap_selected_index == 0, "runtime-state swap move facade should wrap selected index")
	var runtime_direct: Dictionary = flow.select_index_from_runtime_state(runtime_state, 2)
	_expect(bool(runtime_direct.get("accepted", false)), "runtime-state swap direct facade should accept in-range index")
	_expect(runtime_state.unlock_swap_selected_index == 2, "runtime-state swap direct facade should write selected index")
	_expect(not bool(flow.select_index_from_runtime_state(runtime_state, 9).get("accepted", true)), "runtime-state swap direct facade should reject out-of-range index")
	_expect(not bool(flow.move_selection_from_runtime_state(null, 1).get("accepted", true)), "runtime-state swap move facade should reject missing state")
	_expect(not bool(flow.select_index_from_runtime_state(null, 0).get("accepted", true)), "runtime-state swap direct facade should reject missing state")

	var clamp_high: Dictionary = flow.build_clamped_selection_state_update(8, 3)
	_expect(int(clamp_high.get("unlock_swap_selected_index", -1)) == 2, "swap clamp should cap high indices")
	var clamp_low: Dictionary = flow.build_clamped_selection_state_update(-5, 3)
	_expect(int(clamp_low.get("unlock_swap_selected_index", -1)) == 0, "swap clamp should raise low indices")
	_expect(not bool(flow.build_clamped_selection_state_update(0, 0).get("accepted", false)), "swap clamp should reject empty candidates")
	var pending_clamp: Dictionary = flow.build_clamped_selection_for_pending_swap(pending_swap, 8)
	_expect(int(pending_clamp.get("unlock_swap_selected_index", -1)) == 2, "pending-swap clamp should use helper-owned candidate count")

	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_unlock_swap_flow.gd")
	var move_body := _function_body(state_source, "func move_unlock_swap_selection(")
	var direct_body := _function_body(state_source, "func _select_unlock_swap_index(")
	_expect(move_body.find("_unlock_swap_flow.move_selection_from_runtime_state") >= 0, "state should consume runtime-state swap move facade")
	_expect(direct_body.find("_unlock_swap_flow.select_index_from_runtime_state") >= 0, "state should consume runtime-state swap direct facade")
	_expect(move_body.find("build_move_selection_for_pending_swap") < 0, "state move wrapper should not consume pending-swap move builder directly")
	_expect(direct_body.find("build_direct_selection_for_pending_swap") < 0, "state direct wrapper should not consume pending-swap direct builder directly")
	_expect(move_body.find("pending_unlock_swap") < 0, "state move wrapper should not pass pending swap directly")
	_expect(move_body.find("unlock_swap_selected_index") < 0, "state move wrapper should not pass selected index directly")
	_expect(direct_body.find("pending_unlock_swap") < 0, "state direct wrapper should not pass pending swap directly")
	_expect(helper_source.find("func move_selection_from_runtime_state(") >= 0, "helper should expose runtime-state swap move facade")
	_expect(helper_source.find("func select_index_from_runtime_state(") >= 0, "helper should expose runtime-state swap direct facade")
	_expect(helper_source.find("build_confirm_request") >= 0, "helper should own confirm-request construction")
	_expect(state_source.find("build_confirm_request") < 0, "state should not consume confirm-request helper directly")
	_expect(state_source.find("pending_unlock_swap.get(\"candidates\"") < 0, "state should not inspect pending swap candidates directly")
	_expect(state_source.find("unlock_swap_selected_index = clicked_index") < 0, "state should not inline swap click selection")
	_expect(state_source.find("unlock_swap_selected_index = hovered_index") < 0, "state should not inline swap hover selection")
	_expect(state_source.find("unlock_swap_selected_index = posmod(unlock_swap_selected_index + delta_index, candidates.size())") < 0, "state should not inline swap movement wrap")
	_expect(state_source.find("unlock_swap_selected_index = clampi(unlock_swap_selected_index, 0, candidates.size() - 1)") < 0, "state should not inline swap selection clamp")


func _verify_confirm_request_payload() -> void:
	var flow := RuntimePerkUnlockSwapFlow.new()
	var pending_swap: Dictionary = flow.build_pending_swap(_choice(), FakeSkillConfig.new())
	var request: Dictionary = flow.build_confirm_request(pending_swap, 8, "smasher")
	_expect(bool(request.get("accepted", false)), "confirm request should accept valid pending swaps")
	_expect(str(request.get("choice_id", "")) == "soldier_unlock_bowling_trap", "confirm request should preserve choice id")
	_expect(str(request.get("unlocked_skill", "")) == "bowling_trap", "confirm request should preserve unlocked skill")
	_expect(str(request.get("character_type", "")) == "soldier", "confirm request should prefer choice character restriction")
	_expect(int(request.get("selected_index", -1)) == 2, "confirm request should clamp selected index")
	_expect(bool(_get_dict(request.get("selection_update", {})).get("accepted", false)), "confirm request should carry clamped selection update")

	var fallback_pending := pending_swap.duplicate(true)
	_get_dict(fallback_pending.get("choice", {})).erase("character_restriction")
	var fallback_request: Dictionary = flow.build_confirm_request(fallback_pending, 0, "soldier")
	_expect(str(fallback_request.get("character_type", "")) == "soldier", "confirm request should use fallback character type")
	_expect(not bool(flow.build_confirm_request({}, 0, "soldier").get("accepted", true)), "confirm request should reject empty pending swaps")
	var missing_skill := pending_swap.duplicate(true)
	missing_skill.erase("unlocks_skill")
	_get_dict(missing_skill.get("choice", {})).erase("unlocks_skill")
	_expect(str(flow.build_confirm_request(missing_skill, 0, "soldier").get("blocked_reason", "")) == "missing_unlocked_skill", "confirm request should reject missing unlocked skill")
	_selection_state_update_calls = 0
	_selection_update_index = -1
	var selection_result: Dictionary = flow.apply_confirm_selection_update(
		request,
		FakeOwner.new(),
		Callable(self, "_apply_selection_state_update")
	)
	_expect(bool(selection_result.get("accepted", false)), "confirm selection wrapper should accept valid confirm requests")
	_expect(_selection_state_update_calls == 1, "confirm selection wrapper should apply the clamped selection once")
	_expect(_selection_update_index == 2, "confirm selection wrapper should apply the clamped selected index")
	_expect(not bool(flow.apply_confirm_selection_update({"accepted": false}, FakeOwner.new(), Callable(self, "_apply_selection_state_update")).get("accepted", true)), "confirm selection wrapper should reject invalid confirm requests")
	var completion_plan: Dictionary = flow.build_confirm_completion_plan(request)
	_expect(bool(completion_plan.get("accepted", false)), "confirm completion plan should accept valid confirm requests")
	_expect(str(completion_plan.get("showcase_choice_id", "")) == "soldier_unlock_bowling_trap", "confirm completion plan should preserve showcase choice id")
	_expect(str(_get_dict(completion_plan.get("showcase_choice", {})).get("id", "")) == "soldier_unlock_bowling_trap", "confirm completion plan should carry showcase choice")
	var completion_state_update: Dictionary = _get_dict(completion_plan.get("state_update", {}))
	var completion_feedback: Dictionary = _get_dict(completion_state_update.get("feedback_result", {}))
	_expect(str(completion_feedback.get("feedback_text", "")) != "", "confirm completion plan should carry confirm feedback text")
	_expect(is_equal_approx(float(completion_feedback.get("feedback_timer", 0.0)), RuntimePerkUnlockSwapFlow.SWAP_COMPLETE_FEEDBACK_TIMER), "confirm completion plan should carry confirm feedback timer")
	_expect(not bool(flow.build_confirm_completion_plan({"accepted": false}).get("accepted", true)), "confirm completion plan should reject invalid confirm requests")
	_completion_state_update_calls = 0
	_completion_showcase_calls = 0
	_completion_showcase_choice_id = ""
	_completion_showcase_choice.clear()
	var completion_result: Dictionary = flow.apply_confirm_completion_and_showcase(
		completion_plan,
		FakeOwner.new(),
		FakeRegistry.new({}),
		Callable(self, "_apply_completion_state_update"),
		Callable(self, "_finish_or_open_showcase")
	)
	_expect(bool(completion_result.get("accepted", false)), "confirm completion/showcase wrapper should accept valid completion plans")
	_expect(_completion_state_update_calls == 1, "confirm completion/showcase wrapper should apply the completion state once")
	_expect(_completion_showcase_calls == 1, "confirm completion/showcase wrapper should hand off to showcase once")
	_expect(_completion_showcase_choice_id == "soldier_unlock_bowling_trap", "confirm completion/showcase wrapper should preserve showcase choice id")
	_expect(str(_completion_showcase_choice.get("id", "")) == "soldier_unlock_bowling_trap", "confirm completion/showcase wrapper should preserve showcase choice payload")
	_expect(not bool(flow.apply_confirm_completion_and_showcase({"accepted": false}, FakeOwner.new(), FakeRegistry.new({}), Callable(self, "_apply_completion_state_update"), Callable(self, "_finish_or_open_showcase")).get("accepted", true)), "confirm completion/showcase wrapper should reject invalid plans")
	var skill_config_request: Dictionary = flow.build_confirm_skill_config_request(request, Callable(self, "_get_skill_config_key"))
	_expect(bool(skill_config_request.get("accepted", false)), "confirm skill-config request should accept valid confirm requests")
	_expect(str(skill_config_request.get("character_type", "")) == "soldier", "confirm skill-config request should preserve character type")
	_expect(str(skill_config_request.get("skill_config_key", "")) == "commando_skill_config", "confirm skill-config request should resolve config key")
	_expect(not bool(flow.build_confirm_skill_config_request({"accepted": false}, Callable(self, "_get_skill_config_key")).get("accepted", true)), "confirm skill-config request should reject invalid confirm requests")
	var resolve_registry := FakeRegistry.new({"commando_skill_config": FakeSkillConfig.new()})
	var resolved_skill_config: Dictionary = flow.resolve_confirm_skill_config(
		request,
		resolve_registry,
		Callable(self, "_get_instance"),
		Callable(self, "_get_skill_config_key")
	)
	_expect(bool(resolved_skill_config.get("accepted", false)), "confirm skill-config resolver should accept valid config lookups")
	_expect(resolved_skill_config.get("skill_config") is FakeSkillConfig, "confirm skill-config resolver should return the resolved skill config")
	_expect(str(resolved_skill_config.get("skill_config_key", "")) == "commando_skill_config", "confirm skill-config resolver should preserve config key")
	_expect(not bool(flow.resolve_confirm_skill_config(request, FakeRegistry.new({}), Callable(self, "_get_instance"), Callable(self, "_get_skill_config_key")).get("accepted", true)), "confirm skill-config resolver should reject missing configs")
	_commit_level_calls = 0
	var levels: Dictionary = {}
	var commit_result: Dictionary = flow.commit_confirm_choice_level(
		request,
		levels,
		Callable(self, "_commit_unlock_choice_level")
	)
	_expect(bool(commit_result.get("accepted", false)), "confirm level commit wrapper should accept valid confirm requests")
	_expect(_commit_level_calls == 1, "confirm level commit wrapper should call the level-side-effect callback once")
	_expect(int(levels.get("soldier_unlock_bowling_trap", 0)) == 1, "confirm level commit wrapper should let callback mutate runtime levels")
	_expect(not bool(flow.commit_confirm_choice_level({"accepted": false}, levels, Callable(self, "_commit_unlock_choice_level")).get("accepted", true)), "confirm level commit wrapper should reject invalid confirm requests")
	_sync_owner_effect_calls = 0
	var owner_effect_result: Dictionary = flow.sync_confirm_owner_effects(
		request,
		FakeOwner.new(),
		FakeRegistry.new({}),
		Callable(self, "_sync_owner_effects")
	)
	_expect(bool(owner_effect_result.get("accepted", false)), "confirm owner-effect sync wrapper should accept valid confirm requests")
	_expect(_sync_owner_effect_calls == 1, "confirm owner-effect sync wrapper should call the sync callback once")
	_expect(not bool(flow.sync_confirm_owner_effects({"accepted": false}, FakeOwner.new(), FakeRegistry.new({}), Callable(self, "_sync_owner_effects")).get("accepted", true)), "confirm owner-effect sync wrapper should reject invalid confirm requests")

	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_unlock_swap_flow.gd")
	var confirm_body := _function_body(state_source, "func confirm_pending_unlock_swap(")
	var facade_body := _function_body(helper_source, "func confirm_pending_swap_from_runtime_state(")
	var callback_facade_body := _function_body(helper_source, "func build_confirm_callbacks_from_runtime_state(")
	_expect(confirm_body.find("_unlock_swap_flow.confirm_pending_swap_from_runtime_state") >= 0, "state confirm swap should consume helper-owned state-facing confirm orchestration")
	_expect(confirm_body.find("build_confirm_callbacks") < 0, "state confirm swap should not build callback maps directly")
	_expect(helper_source.find("func confirm_pending_swap(") >= 0, "helper should own full confirm orchestration")
	_expect(helper_source.find("func build_confirm_callbacks(") >= 0, "helper should own confirm callback map assembly")
	_expect(helper_source.find("func build_confirm_callbacks_from_runtime_state(") >= 0, "helper should own runtime-state confirm callback map assembly")
	_expect(helper_source.find("func confirm_pending_swap_from_runtime_state(") >= 0, "helper should own runtime-state confirm assembly")
	_expect(confirm_body.find("_level_side_effects") < 0, "state confirm swap should not pass level-side-effect helper inline")
	_expect(callback_facade_body.find("_get_runtime_state_object(runtime_state, \"_level_side_effects\")") >= 0, "helper runtime-state confirm callback facade should own level-side-effect lookup")
	_expect(facade_body.find("build_confirm_callbacks_from_runtime_state(runtime_state)") >= 0, "helper runtime-state confirm facade should build callbacks internally")
	_expect(confirm_body.find("build_confirm_request") < 0, "state confirm swap should not build confirm requests directly")
	_expect(confirm_body.find("apply_confirm_selection_update") < 0, "state confirm swap should not apply confirm selection directly")
	_expect(confirm_body.find("build_confirm_completion_plan") < 0, "state confirm swap should not build completion plans directly")
	_expect(confirm_body.find("resolve_confirm_skill_config") < 0, "state confirm swap should not resolve skill configs directly")
	_expect(confirm_body.find("commit_confirm_choice_level") < 0, "state confirm swap should not commit levels directly")
	_expect(confirm_body.find("sync_confirm_owner_effects") < 0, "state confirm swap should not sync owner effects directly")
	_expect(confirm_body.find("apply_confirm_completion_and_showcase") < 0, "state confirm swap should not apply completion/showcase directly")
	_expect(confirm_body.find("build_confirm_skill_config_request") < 0, "state confirm swap should not build skill config requests inline")
	_expect(confirm_body.find("_level_side_effects.commit_unlock_choice_level") < 0, "state confirm swap should not commit unlock levels inline")
	_expect(confirm_body.find("_sync_runtime_perk_owner_effects(owner, registry)") < 0, "state confirm swap should not sync owner effects inline")
	_expect(confirm_body.find("_finish_or_open_unlock_showcase(\n") < 0, "state confirm swap should not call showcase finish inline")
	_expect(confirm_body.find("confirm_request.get(\"selection_update\"") < 0, "state confirm swap should not read confirm selection update inline")
	_expect(confirm_body.find("completion_plan.get(\"showcase_choice_id\"") < 0, "state confirm swap should not read showcase choice id inline")
	_expect(confirm_body.find("completion_plan.get(\"showcase_choice\"") < 0, "state confirm swap should not read showcase choice payload inline")
	_expect(confirm_body.find("var choice: Dictionary") < 0, "state confirm swap should not retain a confirm choice payload inline")
	_expect(confirm_body.find("pending_unlock_swap.get(\"choice\"") < 0, "state confirm swap should not read pending choice inline")
	_expect(confirm_body.find("pending_unlock_swap.get(\"choice_id\"") < 0, "state confirm swap should not read pending choice id inline")
	_expect(confirm_body.find("pending_unlock_swap.get(\"unlocks_skill\"") < 0, "state confirm swap should not read pending unlocked skill inline")
	_expect(confirm_body.find("has_candidates(pending_unlock_swap)") < 0, "state confirm swap should not validate pending candidates inline")
	_expect(confirm_body.find("build_clamped_selection_for_pending_swap") < 0, "state confirm swap should not build selection clamp inline")
	_expect(confirm_body.find("build_confirm_state_update") < 0, "state confirm swap should not build confirm state update inline")
	_expect(confirm_body.find("confirm_request.get(\"character_type\"") < 0, "state confirm swap should not read confirm request character type inline")
	_expect(confirm_body.find("_get_skill_config_key(character_type)") < 0, "state confirm swap should not resolve skill config key inline")
	_expect(confirm_body.find("_get_instance(registry") < 0, "state confirm swap should not resolve skill config instance inline")
	_expect(confirm_body.find("_get_catalog(") < 0, "state confirm swap should not resolve catalog inline")
	_expect(confirm_body.find("_get_character_type(") < 0, "state confirm swap should not resolve character type inline")
	_expect(confirm_body.find("runtime_skill_levels") < 0, "state confirm swap should not pass runtime levels inline")
	_expect(confirm_body.find("unlock_swap_selected_index") < 0, "state confirm swap should not pass selected index inline")


func _verify_confirm_orchestration() -> void:
	var flow := RuntimePerkUnlockSwapFlow.new()
	var config := FakeSkillConfig.new()
	var weapon_controller := FakeWeaponController.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new({
		"commando_skill_config": config,
		"commando_weapon_controller": weapon_controller,
		"game_audio": audio,
	})
	var pending_swap: Dictionary = flow.build_pending_swap(_choice(), config)
	var levels := {
		"soldier_unlock_bazooka": 1,
	}
	_selection_state_update_calls = 0
	_selection_update_index = -1
	_completion_state_update_calls = 0
	_completion_showcase_calls = 0
	_completion_showcase_choice_id = ""
	_completion_showcase_choice.clear()
	_commit_level_calls = 0
	_sync_owner_effect_calls = 0
	var result: Dictionary = flow.confirm_pending_swap(
		pending_swap,
		1,
		levels,
		FakeOwner.new(),
		registry,
		FakeCatalog.new({"soldier_unlock_bazooka": {"unlocks_skill": "bazooka"}}),
		"soldier",
		_confirm_callbacks()
	)
	_expect(bool(result.get("accepted", false)), "confirm orchestration should accept a valid pending swap")
	_expect(_selection_state_update_calls == 1, "confirm orchestration should apply the clamped selected index once")
	_expect(_selection_update_index == 1, "confirm orchestration should preserve the requested selected index")
	_expect(_commit_level_calls == 1, "confirm orchestration should commit the unlock level once")
	_expect(_sync_owner_effect_calls == 1, "confirm orchestration should sync owner effects once")
	_expect(_completion_state_update_calls == 1, "confirm orchestration should apply completion state once")
	_expect(_completion_showcase_calls == 1, "confirm orchestration should open or finish showcase once")
	_expect(_completion_showcase_choice_id == "soldier_unlock_bowling_trap", "confirm orchestration should preserve showcase choice id")
	_expect(config.equipped == ["net_gun", "bowling_trap", "ak47"], "confirm orchestration should swap the selected shared slot")
	_expect(not levels.has("soldier_unlock_bazooka"), "confirm orchestration should remove the replaced unlock perk")
	_expect(int(levels.get("soldier_unlock_bowling_trap", 0)) == 1, "confirm orchestration should grant the new unlock perk level")
	_expect(weapon_controller.sync_count == 1, "confirm orchestration should sync the Commando weapon controller")
	_expect(audio.play_count == 1, "confirm orchestration should play the Commando weapon-change cue")
	_expect(not bool(flow.confirm_pending_swap({}, 0, {}, FakeOwner.new(), registry, FakeCatalog.new({}), "soldier", _confirm_callbacks()).get("accepted", true)), "confirm orchestration should reject missing pending swap")

	config = FakeSkillConfig.new()
	registry = FakeRegistry.new({"commando_skill_config": config})
	pending_swap = flow.build_pending_swap(_choice(), config)
	var missing_callbacks: Dictionary = flow.confirm_pending_swap(
		pending_swap,
		0,
		{},
		FakeOwner.new(),
		registry,
		FakeCatalog.new({}),
		"soldier",
		{}
	)
	_expect(not bool(missing_callbacks.get("accepted", true)), "confirm orchestration should fail closed without callbacks")


func _verify_state_facing_confirm_orchestration() -> void:
	var flow := RuntimePerkUnlockSwapFlow.new()
	var config := FakeSkillConfig.new()
	var weapon_controller := FakeWeaponController.new()
	var audio := FakeAudio.new()
	var catalog := FakeCatalog.new({
		"soldier_unlock_bazooka": {"unlocks_skill": "bazooka"},
	})
	var registry := FakeRegistry.new({
		"runtime_perk_catalog": catalog,
		"commando_skill_config": config,
		"commando_weapon_controller": weapon_controller,
		"game_audio": audio,
	})
	var runtime_state := FakeConfirmRuntimeState.new()
	var owner := FakeOwner.new()
	runtime_state.pending_unlock_swap = flow.build_pending_swap(_choice(), config)
	runtime_state.unlock_swap_selected_index = 1
	runtime_state.runtime_skill_levels = {"soldier_unlock_bazooka": 1}

	var result: Dictionary = flow.confirm_pending_swap_from_runtime_state(
		runtime_state,
		owner,
		registry
	)
	_expect(bool(result.get("accepted", false)), "state-facing confirm orchestration should accept a valid runtime state")
	_expect(runtime_state.catalog_calls == 1, "state-facing confirm orchestration should resolve catalog through runtime state")
	_expect(runtime_state.character_type_calls == 1, "state-facing confirm orchestration should resolve character type through runtime state")
	_expect(runtime_state.selection_update_calls == 1, "state-facing confirm orchestration should apply selection update through runtime state")
	_expect(runtime_state.completion_update_calls == 1, "state-facing confirm orchestration should apply completion update through runtime state")
	_expect(runtime_state.owner_effect_calls == 1, "state-facing confirm orchestration should sync owner effects through runtime state")
	_expect(runtime_state.showcase_calls == 1, "state-facing confirm orchestration should finish/open showcase through runtime state")
	_expect(runtime_state._level_side_effects.commit_calls == 1, "state-facing confirm orchestration should commit levels through runtime-state side-effect helper")
	_expect(config.equipped == ["net_gun", "bowling_trap", "ak47"], "state-facing confirm orchestration should apply the selected skill swap")
	_expect(not runtime_state.runtime_skill_levels.has("soldier_unlock_bazooka"), "state-facing confirm orchestration should remove the replaced unlock perk")
	_expect(int(runtime_state.runtime_skill_levels.get("soldier_unlock_bowling_trap", 0)) == 1, "state-facing confirm orchestration should grant the new unlock perk level")
	_expect(weapon_controller.sync_count == 1, "state-facing confirm orchestration should sync the Commando weapon controller")
	_expect(audio.play_count == 1, "state-facing confirm orchestration should play the Commando weapon-change cue")
	_expect(not bool(flow.confirm_pending_swap_from_runtime_state(FakeConfirmRuntimeState.new(), owner, registry).get("accepted", true)), "state-facing confirm orchestration should reject missing pending state")
	_expect(not bool(flow.confirm_pending_swap_from_runtime_state(null, owner, registry).get("accepted", true)), "state-facing confirm orchestration should reject missing runtime state")


func _verify_state_update_application() -> void:
	var flow := RuntimePerkUnlockSwapFlow.new()
	var feedback := FakeFeedbackHelper.new()
	var state := FakeRuntimeState.new()
	var payload: Dictionary = flow.build_pending_swap(_choice(), FakeSkillConfig.new())
	var start_result: Dictionary = flow.apply_state_update(
		state,
		flow.build_start_state_update(payload),
		feedback,
		state.feedback_timer
	)
	_expect(bool(start_result.get("accepted", false)), "helper should apply start state updates")
	_expect(str(state.pending_unlock_swap.get("choice_id", "")) == "soldier_unlock_bowling_trap", "helper should write pending swap payload")
	_expect(state.unlock_swap_selected_index == 0, "helper should reset selected index on start")
	_expect(state.gamepad_unlock_swap_horizontal_latch == 0, "helper should reset gamepad latch on start")
	_expect(bool(start_result.get("sync_owner", false)), "helper result should preserve sync-owner request")
	state.pending_unlock_swap["choice_id"] = "mutated"
	_expect(str(payload.get("choice_id", "")) == "soldier_unlock_bowling_trap", "helper should deep-copy pending swap into state")

	state.current_choice_context = {"source": "swap"}
	state.feedback_timer = 0.4
	var cancel_result: Dictionary = flow.apply_state_update(
		state,
		flow.build_cancel_state_update(),
		feedback,
		state.feedback_timer
	)
	_expect(bool(cancel_result.get("accepted", false)), "helper should apply cancel state updates")
	_expect(state.pending_unlock_swap.is_empty(), "helper should clear pending swap on cancel")
	_expect(state.current_choice_context.is_empty(), "helper should clear current choice context on cancel")
	_expect(str(state.feedback_text) == RuntimePerkUnlockSwapFlow.SWAP_CANCEL_FEEDBACK_TEXT, "helper should apply cancel feedback text")
	_expect(is_equal_approx(state.feedback_timer, RuntimePerkUnlockSwapFlow.SWAP_CANCEL_FEEDBACK_TIMER), "helper should apply cancel feedback timer")
	_expect(feedback.apply_count == 1, "helper should route feedback through feedback helper")
	_expect(not bool(flow.apply_state_update(null, flow.build_cancel_state_update()).get("accepted", true)), "helper should reject missing state")
	_expect(not bool(flow.apply_state_update(state, {"accepted": false}).get("accepted", true)), "helper should reject rejected updates")

	_sync_owner_calls = 0
	var synced_state := FakeRuntimeState.new()
	var synced_result: Dictionary = flow.apply_state_update_and_sync_owner(
		synced_state,
		flow.build_start_state_update(payload),
		feedback,
		synced_state.feedback_timer,
		FakeOwner.new(),
		Callable(self, "_sync_owner")
	)
	_expect(bool(synced_result.get("accepted", false)), "helper sync wrapper should accept valid state updates")
	_expect(_sync_owner_calls == 1, "helper sync wrapper should call owner sync for sync-owner updates")
	_expect(bool(synced_result.get("owner_synced", false)), "helper sync wrapper should report owner sync")
	var unsynced_result: Dictionary = flow.apply_state_update_and_sync_owner(
		synced_state,
		flow.build_move_selection_state_update(0, 1, 3),
		feedback,
		synced_state.feedback_timer,
		FakeOwner.new(),
		Callable(self, "_sync_owner")
	)
	_expect(bool(unsynced_result.get("accepted", false)), "helper sync wrapper should accept non-sync updates")
	_expect(_sync_owner_calls == 1, "helper sync wrapper should skip owner sync when update does not request it")
	_expect(not bool(unsynced_result.get("owner_synced", true)), "helper sync wrapper should report skipped owner sync")

	var runtime_feedback := FakeFeedbackHelper.new()
	var runtime_state := FakeRuntimeState.new()
	runtime_state._choice_feedback = runtime_feedback
	runtime_state.current_choice_context = {"source": "swap"}
	var runtime_result: Dictionary = flow.apply_state_update_and_sync_owner_from_runtime_state(
		runtime_state,
		flow.build_cancel_state_update(),
		FakeOwner.new()
	)
	_expect(bool(runtime_result.get("accepted", false)), "runtime-state sync wrapper should accept valid state updates")
	_expect(str(runtime_state.feedback_text) == RuntimePerkUnlockSwapFlow.SWAP_CANCEL_FEEDBACK_TEXT, "runtime-state sync wrapper should use the state's feedback helper")
	_expect(runtime_feedback.apply_count == 1, "runtime-state sync wrapper should route feedback through the runtime state's helper")
	_expect(runtime_state.current_choice_context.is_empty(), "runtime-state sync wrapper should apply state-field cleanup")
	_expect(runtime_state.sync_owner_calls == 1, "runtime-state sync wrapper should call runtime-state owner sync")
	_expect(bool(runtime_result.get("owner_synced", false)), "runtime-state sync wrapper should report owner sync")

	var cancel_runtime_feedback := FakeFeedbackHelper.new()
	var cancel_runtime_state := FakeRuntimeState.new()
	cancel_runtime_state._choice_feedback = cancel_runtime_feedback
	cancel_runtime_state.pending_unlock_swap = flow.build_pending_swap(_choice(), FakeSkillConfig.new())
	cancel_runtime_state.current_choice_context = {"source": "swap"}
	var runtime_cancel_result: Dictionary = flow.cancel_pending_swap_from_runtime_state(
		cancel_runtime_state,
		FakeOwner.new()
	)
	_expect(bool(runtime_cancel_result.get("accepted", false)), "runtime-state cancel facade should accept pending swap cancellation")
	_expect(cancel_runtime_state.pending_unlock_swap.is_empty(), "runtime-state cancel facade should clear pending swap")
	_expect(cancel_runtime_state.current_choice_context.is_empty(), "runtime-state cancel facade should clear current choice context")
	_expect(cancel_runtime_feedback.apply_count == 1, "runtime-state cancel facade should route feedback through runtime-state feedback helper")
	_expect(cancel_runtime_state.sync_owner_calls == 1, "runtime-state cancel facade should sync owner")
	var missing_cancel_result: Dictionary = flow.cancel_pending_swap_from_runtime_state(FakeRuntimeState.new(), FakeOwner.new())
	_expect(not bool(missing_cancel_result.get("accepted", true)), "runtime-state cancel facade should reject missing pending swap")

	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var apply_body := _function_body(state_source, "func _apply_unlock_swap_state_update(")
	var cancel_body := _function_body(state_source, "func cancel_pending_unlock_swap(")
	_expect(apply_body.find("apply_state_update_and_sync_owner_from_runtime_state") >= 0, "state swap apply wrapper should consume runtime-state helper sync wrapper")
	_expect(apply_body.find("_choice_feedback") < 0, "state swap apply wrapper should not pass feedback helper inline")
	_expect(apply_body.find("feedback_timer") < 0, "state swap apply wrapper should not pass feedback timer inline")
	_expect(apply_body.find("Callable(self, \"_sync_owner\")") < 0, "state swap apply wrapper should not build owner-sync callable inline")
	_expect(apply_body.find("get(\"sync_owner\"") < 0, "state swap apply wrapper should not inspect sync-owner result")
	_expect(apply_body.find("_sync_owner(owner)") < 0, "state swap apply wrapper should not call owner sync inline")
	_expect(cancel_body.find("cancel_pending_swap_from_runtime_state") >= 0, "state cancel wrapper should consume runtime-state cancel facade")
	_expect(cancel_body.find("build_cancel_state_update") < 0, "state cancel wrapper should not build cancel updates inline")
	_expect(cancel_body.find("has_pending_unlock_swap") < 0, "state cancel wrapper should not inspect pending state inline")


func _verify_swap_apply_and_cleanup() -> void:
	var flow := RuntimePerkUnlockSwapFlow.new()
	var config := FakeSkillConfig.new()
	var payload: Dictionary = flow.build_pending_swap(_choice(), config)
	var result: Dictionary = flow.apply_selected_swap(payload, 1, config)
	_expect(bool(result.get("ok", false)), "selected swap should apply through skill config")
	_expect(str(result.get("removed_skill", "")) == "bazooka", "selected index should choose the removed skill")
	_expect(config.equipped == ["net_gun", "bowling_trap", "ak47"], "swap should replace the selected shared-slot skill")

	var levels := {
		"soldier_unlock_bazooka": 1,
		"soldier_pistol_perk": 1,
	}
	var catalog := FakeCatalog.new({
		"soldier_unlock_bazooka": {"unlocks_skill": "bazooka"},
	})
	config = FakeSkillConfig.new()
	payload = flow.build_pending_swap(_choice(), config)
	var cleanup_result: Dictionary = flow.apply_selected_swap_and_cleanup(payload, 1, config, levels, catalog)
	_expect(bool(cleanup_result.get("ok", false)), "selected swap cleanup wrapper should apply the swap")
	_expect(str(cleanup_result.get("removed_perk_id", "")) == "soldier_unlock_bazooka", "selected swap cleanup wrapper should remove mapped unlock perk")
	_expect(not levels.has("soldier_unlock_bazooka"), "selected swap cleanup wrapper should mutate runtime levels")
	levels["soldier_unlock_bazooka"] = 1
	config = FakeSkillConfig.new()
	payload = flow.build_pending_swap(_choice(), config)
	var confirm_request: Dictionary = flow.build_confirm_request(payload, 1, "soldier")
	var confirm_cleanup_result: Dictionary = flow.apply_confirm_selected_swap_and_cleanup(
		confirm_request,
		payload,
		config,
		levels,
		catalog
	)
	_expect(bool(confirm_cleanup_result.get("ok", false)), "confirm selected swap cleanup wrapper should apply the swap")
	_expect(bool(confirm_cleanup_result.get("accepted", false)), "confirm selected swap cleanup wrapper should report accepted results")
	_expect(int(confirm_cleanup_result.get("selected_index", -1)) == 1, "confirm selected swap cleanup wrapper should preserve selected index")
	_expect(not levels.has("soldier_unlock_bazooka"), "confirm selected swap cleanup wrapper should mutate runtime levels")
	_expect(not bool(flow.apply_confirm_selected_swap_and_cleanup({"accepted": false}, payload, config, levels, catalog).get("ok", true)), "confirm selected swap cleanup wrapper should reject invalid confirm requests")

	levels["soldier_unlock_bazooka"] = 1
	_expect(flow.remove_runtime_unlock_for_skill(levels, "bazooka", catalog) == "soldier_unlock_bazooka", "cleanup should erase catalog-mapped unlock perk")
	_expect(not levels.has("soldier_unlock_bazooka"), "catalog-mapped unlock should be removed from runtime levels")
	_expect(flow.remove_runtime_unlock_for_skill(levels, "commando_pistol", FakeCatalog.new({})) == "soldier_pistol_perk", "cleanup should fall back for commando pistol")
	_expect(not levels.has("soldier_pistol_perk"), "fallback unlock should be removed from runtime levels")

	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_unlock_swap_flow.gd")
	var confirm_body := _function_body(state_source, "func confirm_pending_unlock_swap(")
	_expect(helper_source.find("apply_confirm_selected_swap_and_cleanup") >= 0, "helper should own confirm swap cleanup wrapper")
	_expect(confirm_body.find("apply_confirm_selected_swap_and_cleanup") < 0, "state confirm swap should not call confirm swap cleanup directly")
	_expect(confirm_body.find("apply_selected_swap_and_cleanup(") < 0, "state confirm swap should not call raw swap cleanup wrapper")
	_expect(confirm_body.find("confirm_request.get(\"selected_index\"") < 0, "state confirm swap should not read confirm selected index inline")
	_expect(confirm_body.find("remove_runtime_unlock_for_skill") < 0, "state confirm swap should not cleanup removed unlock perks inline")
	_expect(confirm_body.find("removed_skill") < 0, "state confirm swap should not retain removed-skill cleanup payload inline")


func _verify_commando_weapon_sync() -> void:
	var flow := RuntimePerkUnlockSwapFlow.new()
	var config := FakeSkillConfig.new()
	var weapon_controller := FakeWeaponController.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new({
		"commando_weapon_controller": weapon_controller,
		"game_audio": audio,
	})
	_expect(flow.sync_commando_weapon_controller("ak47", config, registry, "soldier", Callable(self, "_get_instance")), "soldier sync should reach the weapon controller")
	_expect(weapon_controller.sync_count == 1, "sync should prefer sync_equipped_permanent")
	_expect(weapon_controller.highlighted_weapon == "ak47", "sync should trigger the HUD highlight for the new weapon")
	_expect(audio.play_count == 1, "sync should play the Commando weapon-change cue")
	_expect(not flow.sync_commando_weapon_controller("ak47", config, registry, "viper", Callable(self, "_get_instance")), "non-soldier sync should be ignored")
	_expect(weapon_controller.sync_count == 1, "ignored sync should not touch weapon controller again")

	var request: Dictionary = flow.build_confirm_request(flow.build_pending_swap(_choice(), config), 0, "soldier")
	_expect(flow.sync_commando_weapon_controller_for_confirm_request(request, config, registry, Callable(self, "_get_instance")), "confirm request sync should route Commando sync")
	_expect(weapon_controller.sync_count == 2, "confirm request sync should reach weapon controller")
	var non_soldier_request := request.duplicate(true)
	non_soldier_request["character_type"] = "viper"
	_expect(not flow.sync_commando_weapon_controller_for_confirm_request(non_soldier_request, config, registry, Callable(self, "_get_instance")), "confirm request sync should ignore non-soldier requests")
	_expect(weapon_controller.sync_count == 2, "ignored confirm request sync should not touch weapon controller")

	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_unlock_swap_flow.gd")
	var confirm_body := _function_body(state_source, "func confirm_pending_unlock_swap(")
	_expect(helper_source.find("sync_commando_weapon_controller_for_confirm_request") >= 0, "helper should own confirm-request Commando sync wrapper")
	_expect(confirm_body.find("sync_commando_weapon_controller_for_confirm_request") < 0, "state confirm swap should not call confirm-request Commando sync directly")
	_expect(confirm_body.find("sync_commando_weapon_controller(\n") < 0, "state confirm swap should not call raw Commando sync helper")
	_expect(confirm_body.find("confirm_request.get(\"unlocked_skill\"") < 0, "state confirm swap should not read confirm request unlocked skill for Commando sync")


func _confirm_callbacks() -> Dictionary:
	return {
		RuntimePerkUnlockSwapFlow.CALLBACK_APPLY_UNLOCK_SWAP_STATE_UPDATE: Callable(self, "_apply_confirm_state_update"),
		RuntimePerkUnlockSwapFlow.CALLBACK_GET_INSTANCE: Callable(self, "_get_instance"),
		RuntimePerkUnlockSwapFlow.CALLBACK_GET_SKILL_CONFIG_KEY: Callable(self, "_get_skill_config_key"),
		RuntimePerkUnlockSwapFlow.CALLBACK_COMMIT_UNLOCK_CHOICE_LEVEL: Callable(self, "_commit_unlock_choice_level"),
		RuntimePerkUnlockSwapFlow.CALLBACK_SYNC_RUNTIME_PERK_OWNER_EFFECTS: Callable(self, "_sync_owner_effects"),
		RuntimePerkUnlockSwapFlow.CALLBACK_FINISH_OR_OPEN_UNLOCK_SHOWCASE: Callable(self, "_finish_or_open_showcase"),
	}


func _choice() -> Dictionary:
	return {
		"id": "soldier_unlock_bowling_trap",
		"unlocks_skill": "bowling_trap",
		"name": "Bowling Trap",
		"character_restriction": "soldier",
	}


func _get_instance(registry: Object, key: String) -> Object:
	return registry.get_instance(key)


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_skill_config_key(character_type: String) -> String:
	if character_type == "soldier":
		return "commando_skill_config"
	return "smasher_skill_config"


func _commit_unlock_choice_level(choice: Dictionary, runtime_skill_levels: Dictionary) -> Dictionary:
	_commit_level_calls += 1
	var choice_id := str(choice.get("id", ""))
	if choice_id == "":
		return {"accepted": false}
	runtime_skill_levels[choice_id] = int(runtime_skill_levels.get(choice_id, 0)) + 1
	return {"accepted": true, "choice_id": choice_id}


func _sync_owner(_owner: Object) -> void:
	_sync_owner_calls += 1


func _sync_owner_effects(_owner: Object, _registry: Object) -> void:
	_sync_owner_effect_calls += 1


func _apply_completion_state_update(update: Dictionary, _owner: Object = null) -> bool:
	_completion_state_update_calls += 1
	return bool(update.get("accepted", false))


func _finish_or_open_showcase(
	choice_id: String,
	_owner: Object,
	_registry: Object,
	_perf_logger: Object = null,
	choice: Dictionary = {}
) -> void:
	_completion_showcase_calls += 1
	_completion_showcase_choice_id = choice_id
	_completion_showcase_choice = choice.duplicate(true)


func _apply_selection_state_update(update: Dictionary, _owner: Object = null) -> bool:
	_selection_state_update_calls += 1
	_selection_update_index = int(update.get("unlock_swap_selected_index", -1))
	return bool(update.get("accepted", false))


func _apply_confirm_state_update(update: Dictionary, _owner: Object = null) -> bool:
	if bool(update.get("clear_pending_unlock_swap", false)):
		_completion_state_update_calls += 1
	elif update.has("unlock_swap_selected_index"):
		_selection_state_update_calls += 1
		_selection_update_index = int(update.get("unlock_swap_selected_index", -1))
	return bool(update.get("accepted", false))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)


class FakeSkillConfig:
	var equipped: Array = ["net_gun", "bazooka", "ak47"]

	func is_skill_equipped(skill_name: String) -> bool:
		return equipped.has(skill_name)

	func is_shared_slot_full() -> bool:
		return true

	func get_shared_slot_swap_candidates(_skill_name: String) -> Array:
		return equipped.duplicate()

	func get_skill_data(skill_name: String) -> Dictionary:
		return {"korean": "K %s" % skill_name}

	func swap_equipped_permanent(old_skill_name: String, new_skill_name: String) -> bool:
		var index := equipped.find(old_skill_name)
		if index < 0:
			return false
		equipped[index] = new_skill_name
		return true


class FakeCatalog:
	var data: Dictionary = {}

	func _init(source: Dictionary) -> void:
		data = source

	func get_perk_data(perk_id: String) -> Dictionary:
		return _get_dict(data.get(perk_id, {}))

	func _get_dict(value: Variant) -> Dictionary:
		if value is Dictionary:
			return value
		return {}


class FakeWeaponController:
	var sync_count := 0
	var highlighted_weapon := ""

	func sync_equipped_permanent(_skill_config: Object) -> void:
		sync_count += 1

	func trigger_hud_highlight(weapon_id: String) -> void:
		highlighted_weapon = weapon_id


class FakeAudio:
	var play_count := 0

	func play_commando_weapon_change() -> void:
		play_count += 1


class FakeFeedbackHelper:
	var apply_count := 0

	func apply_feedback_state_update(runtime_state: Object, update: Dictionary, fallback_timer: float = 0.0) -> Dictionary:
		apply_count += 1
		runtime_state.feedback_text = str(update.get("feedback_text", ""))
		runtime_state.feedback_timer = float(update.get("feedback_timer", fallback_timer))
		return {
			"accepted": true,
			"feedback_text": runtime_state.feedback_text,
			"feedback_timer": runtime_state.feedback_timer,
		}


class FakeRuntimeState:
	var pending_unlock_swap: Dictionary = {}
	var unlock_swap_selected_index := 3
	var gamepad_unlock_swap_horizontal_latch := 1
	var current_choice_context: Dictionary = {}
	var feedback_text := ""
	var feedback_timer := 0.0
	var _choice_feedback: Object = null
	var sync_owner_calls := 0

	func _sync_owner(_owner: Object) -> void:
		sync_owner_calls += 1


class FakeConfirmRuntimeState:
	var runtime_skill_levels: Dictionary = {}
	var pending_unlock_swap: Dictionary = {}
	var unlock_swap_selected_index := 0
	var _level_side_effects: Object = FakeLevelSideEffects.new()
	var catalog_calls := 0
	var character_type_calls := 0
	var selection_update_calls := 0
	var completion_update_calls := 0
	var owner_effect_calls := 0
	var showcase_calls := 0

	func _get_catalog(registry: Object) -> Object:
		catalog_calls += 1
		return registry.get_instance("runtime_perk_catalog")

	func _get_character_type(owner: Object) -> String:
		character_type_calls += 1
		return str(owner.get("selected_character_type"))

	func _get_instance(registry: Object, key: String) -> Object:
		return registry.get_instance(key)

	func _get_skill_config_key(character_type: String) -> String:
		if character_type == "soldier":
			return "commando_skill_config"
		return "smasher_skill_config"

	func _apply_unlock_swap_state_update(update: Dictionary, _owner: Object = null) -> bool:
		if bool(update.get("clear_pending_unlock_swap", false)):
			completion_update_calls += 1
			pending_unlock_swap.clear()
		elif update.has("unlock_swap_selected_index"):
			selection_update_calls += 1
			unlock_swap_selected_index = int(update.get("unlock_swap_selected_index", unlock_swap_selected_index))
		return bool(update.get("accepted", false))

	func _sync_runtime_perk_owner_effects(_owner: Object, _registry: Object) -> void:
		owner_effect_calls += 1

	func _finish_or_open_unlock_showcase(
		_choice_id: String,
		_owner: Object,
		_registry: Object,
		_perf_logger: Object = null,
		_choice: Dictionary = {}
	) -> void:
		showcase_calls += 1


class FakeLevelSideEffects:
	var commit_calls := 0

	func commit_unlock_choice_level(choice: Dictionary, runtime_skill_levels: Dictionary) -> Dictionary:
		commit_calls += 1
		var choice_id := str(choice.get("id", ""))
		if choice_id == "":
			return {"accepted": false}
		runtime_skill_levels[choice_id] = int(runtime_skill_levels.get(choice_id, 0)) + 1
		return {"accepted": true, "choice_id": choice_id}


class FakeOwner:
	var selected_character_type := "soldier"


class FakeRegistry:
	var instances: Dictionary = {}

	func _init(source: Dictionary) -> void:
		instances = source

	func get_instance(key: String) -> Object:
		return instances.get(key, null)
