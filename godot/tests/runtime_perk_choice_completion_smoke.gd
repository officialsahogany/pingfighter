extends SceneTree

const RuntimePerkChoiceCompletion := preload("res://scripts/characters/runtime_perk_choice_completion.gd")
const RuntimePerkChoiceFeedback := preload("res://scripts/characters/runtime_perk_choice_feedback.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_selected_choice_snapshot()
	_verify_success_state_update()
	_verify_success_state_update_for_choice()
	_verify_success_state_application()
	_verify_extra_pick_update()
	_verify_next_choice_context_snapshot()
	_verify_post_state_plan()
	_verify_modal_close_plan()
	_verify_state_source_contract()

	if _failures.is_empty():
		print("runtime_perk_choice_completion_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_selected_choice_snapshot() -> void:
	var helper := RuntimePerkChoiceCompletion.new()
	var choice := {"name": "", "nested": {"value": 1}}
	var snapshot: Dictionary = helper.build_selected_choice_snapshot("dash_lightweight", choice, {"dash_lightweight": 2})
	_expect(str(snapshot.get("id", "")) == "dash_lightweight", "selected choice snapshot should force the choice id")
	_expect(str(snapshot.get("name", "")) == "dash_lightweight", "selected choice snapshot should backfill missing names")
	_expect(int(snapshot.get("current_level", -1)) == 1, "selected choice snapshot should expose previous level")
	_expect(int(snapshot.get("next_level", -1)) == 2, "selected choice snapshot should expose applied level")
	_expect(int(snapshot.get("level_delta", 0)) == 1, "selected choice snapshot should expose level delta")
	_as_dict(snapshot.get("nested", {}))["value"] = 9
	_expect(int(_as_dict(choice.get("nested", {})).get("value", 0)) == 1, "selected choice snapshot should deep-copy source choice data")


func _verify_success_state_update() -> void:
	var helper := RuntimePerkChoiceCompletion.new()
	var selected_snapshot := {
		"id": "dash_lightweight",
		"nested": {"value": 1},
	}
	var update: Dictionary = helper.build_success_state_update(
		"dash_lightweight",
		selected_snapshot,
		3,
		4,
		false
	)
	_expect(bool(update.get("accepted", false)), "success update should accept a valid choice id")
	_expect(str(update.get("last_selected_id", "")) == "dash_lightweight", "success update should expose last selected id")
	_expect(int(update.get("pending_skill_choices", 0)) == 2, "success update should consume one pending choice")
	_expect(int(update.get("selected_choice_sequence", 0)) == 5, "success update should bump selected choice sequence")
	_expect(not bool(update.get("choice_active", true)), "success update should mark the modal inactive before optional next-open")
	_expect(bool(update.get("clear_current_choices", false)), "success update should request clearing current choices")
	_expect(is_equal_approx(float(update.get("animation_time", -1.0)), 0.0), "success update should reset animation time")
	var copied_snapshot: Dictionary = _as_dict(update.get("last_selected_choice", {}))
	_as_dict(copied_snapshot.get("nested", {}))["value"] = 9
	_expect(int(_as_dict(selected_snapshot.get("nested", {})).get("value", 0)) == 1, "selected choice snapshot should be deep-copied")

	var rejected: Dictionary = helper.build_success_state_update("", {}, 1, 0, false)
	_expect(not bool(rejected.get("accepted", true)), "success update should reject empty choice ids")


func _verify_success_state_update_for_choice() -> void:
	var helper := RuntimePerkChoiceCompletion.new()
	var update: Dictionary = helper.build_success_state_update_for_choice(
		"dash_lightweight",
		{"id": "dash_lightweight", "name": "Dash"},
		{"dash_lightweight": 3},
		2,
		7,
		false
	)
	_expect(bool(update.get("accepted", false)), "choice success update should accept valid choices")
	var selected_snapshot: Dictionary = _as_dict(update.get("last_selected_choice", {}))
	_expect(int(selected_snapshot.get("current_level", -1)) == 2, "choice success update should include selected-choice level snapshot")
	_expect(int(selected_snapshot.get("next_level", -1)) == 3, "choice success update should include selected-choice applied level")
	_expect(int(update.get("pending_skill_choices", -1)) == 1, "choice success update should consume one pending choice")
	_expect(int(update.get("selected_choice_sequence", -1)) == 8, "choice success update should bump selected sequence")


func _verify_success_state_application() -> void:
	var helper := RuntimePerkChoiceCompletion.new()
	var state := FakeRuntimeState.new()
	state.feedback_timer = 0.4
	state.current_choices = [{"id": "a"}]
	var update: Dictionary = helper.build_success_state_update(
		"dash_lightweight",
		{"id": "dash_lightweight", "nested": {"value": 1}},
		2,
		3,
		false
	)
	var result: Dictionary = helper.apply_success_state_update(state, update, "fallback")
	_expect(bool(result.get("accepted", false)), "success state application should accept valid updates")
	_expect(state.last_selected_id == "dash_lightweight", "success state application should write last selected id")
	_expect(state.selected_choice_sequence == 4, "success state application should write selected sequence")
	_expect(state.pending_skill_choices == 1, "success state application should write pending choice count")
	_expect(not state.choice_active, "success state application should close the current choice modal")
	_expect(state.current_choices.is_empty(), "success state application should clear current choices")
	_expect(is_equal_approx(state.animation_time, 0.0), "success state application should reset animation time")
	_as_dict(state.last_selected_choice.get("nested", {}))["value"] = 9
	var update_snapshot: Dictionary = _as_dict(update.get("last_selected_choice", {}))
	var update_nested: Dictionary = _as_dict(update_snapshot.get("nested", {}))
	_expect(int(update_nested.get("value", 0)) == 1, "success state application should deep-copy selected choice")

	var feedback := RuntimePerkChoiceFeedback.new().build_megingjord_extra_pick_feedback(0.25)
	var feedback_update: Dictionary = helper.build_success_state_update(
		"smash_power",
		{"id": "smash_power"},
		1,
		0,
		true,
		feedback
	)
	helper.apply_success_state_update(state, feedback_update)
	_expect(state.feedback_text == RuntimePerkChoiceFeedback.MEGINGJORD_EXTRA_PICK_TEXT, "success state application should apply Megingjord feedback")
	_expect(is_equal_approx(state.feedback_timer, RuntimePerkChoiceFeedback.MEGINGJORD_EXTRA_PICK_TIMER), "success state application should apply Megingjord feedback timer")
	_expect(not bool(helper.apply_success_state_update(null, update).get("accepted", true)), "success state application should reject missing state")


func _verify_extra_pick_update() -> void:
	var helper := RuntimePerkChoiceCompletion.new()
	var feedback: Dictionary = RuntimePerkChoiceFeedback.new().build_megingjord_extra_pick_feedback(0.25)
	var update: Dictionary = helper.build_success_state_update(
		"smash_power",
		{"id": "smash_power"},
		1,
		0,
		true,
		feedback
	)
	_expect(int(update.get("pending_skill_choices", -1)) == 1, "Megingjord extra-pick should add back one pending choice after consume")
	var feedback_result: Dictionary = _as_dict(update.get("feedback_result", {}))
	_expect(
		str(feedback_result.get("feedback_text", "")) == RuntimePerkChoiceFeedback.MEGINGJORD_EXTRA_PICK_TEXT,
		"Megingjord feedback should flow through the completion payload"
	)
	feedback_result["feedback_text"] = "mutated"
	_expect(
		str(feedback.get("feedback_text", "")) == RuntimePerkChoiceFeedback.MEGINGJORD_EXTRA_PICK_TEXT,
		"Megingjord feedback payload should be deep-copied"
	)


func _verify_next_choice_context_snapshot() -> void:
	var helper := RuntimePerkChoiceCompletion.new()
	var current_context := {
		"source": "academy",
		"nested": {"value": 1},
	}
	var snapshot: Dictionary = helper.build_next_choice_context(current_context)
	_expect(str(snapshot.get("source", "")) == "academy", "next choice context snapshot should preserve source fields")
	_as_dict(snapshot.get("nested", {}))["value"] = 9
	_expect(int(_as_dict(current_context.get("nested", {})).get("value", 0)) == 1, "next choice context snapshot should deep-copy nested context data")


func _verify_post_state_plan() -> void:
	var helper := RuntimePerkChoiceCompletion.new()
	var open_plan: Dictionary = helper.build_post_state_plan(2, true, false)
	_expect(bool(open_plan.get("open_next_choice", false)), "post-state plan should open next choice when pending choices and catalog exist")
	_expect(not bool(open_plan.get("clear_choice_context", true)), "post-state open-next plan should preserve choice context")
	var open_state := FakeRuntimeState.new()
	open_state.current_choice_context = {"keep": true}
	var open_apply: Dictionary = helper.apply_post_state_plan(open_state, open_plan)
	_expect(bool(open_apply.get("accepted", false)), "post-state plan application should accept open-next plans")
	_expect(bool(open_apply.get("open_next_choice", false)), "post-state plan application should preserve open-next request")
	_expect(not open_state.current_choice_context.is_empty(), "post-state open-next application should preserve context")

	var clear_plan: Dictionary = helper.build_post_state_plan(0, true, false)
	_expect(not bool(clear_plan.get("open_next_choice", true)), "post-state plan should not open next choice with no pending choices")
	_expect(bool(clear_plan.get("clear_choice_context", false)), "post-state plan should clear context when no swap is pending")
	var clear_state := FakeRuntimeState.new()
	clear_state.current_choice_context = {"source": "choice"}
	var clear_apply: Dictionary = helper.apply_post_state_plan(clear_state, clear_plan)
	_expect(bool(clear_apply.get("accepted", false)), "post-state plan application should accept clear-context plans")
	_expect(bool(clear_apply.get("clear_choice_context", false)), "post-state plan application should report context clear")
	_expect(clear_state.current_choice_context.is_empty(), "post-state plan application should clear context")

	var swap_plan: Dictionary = helper.build_post_state_plan(0, true, true)
	_expect(not bool(swap_plan.get("clear_choice_context", true)), "post-state plan should preserve context while swap is pending")
	var swap_state := FakeRuntimeState.new()
	swap_state.current_choice_context = {"swap": true}
	helper.apply_post_state_plan(swap_state, swap_plan)
	_expect(not swap_state.current_choice_context.is_empty(), "post-state swap application should preserve context")
	_expect(not bool(helper.apply_post_state_plan(null, clear_plan).get("accepted", true)), "post-state plan application should reject missing state")


func _verify_modal_close_plan() -> void:
	var helper := RuntimePerkChoiceCompletion.new()
	var close_plan: Dictionary = helper.build_modal_close_plan(false, false)
	_expect(bool(close_plan.get(RuntimePerkChoiceCompletion.CLOSE_ACTION_RESUME_SKILL_COOLDOWNS, false)), "fully closed modal should resume skill cooldowns")
	_expect(bool(close_plan.get(RuntimePerkChoiceCompletion.CLOSE_ACTION_ARM_RESUME_SAFETY, false)), "fully closed modal should arm resume safety")
	_expect(bool(close_plan.get(RuntimePerkChoiceCompletion.CLOSE_ACTION_START_STARPOINT_ABSORPTION, false)), "fully closed modal should start starpoint absorption")
	_expect(bool(close_plan.get(RuntimePerkChoiceCompletion.CLOSE_ACTION_SYNC_OWNER, false)), "modal close plan should keep owner sync requested")
	var close_steps: Array = helper.build_modal_close_steps(close_plan)
	_expect(close_steps.size() == 4, "fully closed modal should expose four close steps")
	if close_steps.size() == 4:
		_expect(str(_as_dict(close_steps[0]).get("action", "")) == RuntimePerkChoiceCompletion.CLOSE_ACTION_RESUME_SKILL_COOLDOWNS, "close step 0 should resume cooldowns")
		_expect(str(_as_dict(close_steps[1]).get("action", "")) == RuntimePerkChoiceCompletion.CLOSE_ACTION_ARM_RESUME_SAFETY, "close step 1 should arm resume safety")
		_expect(str(_as_dict(close_steps[2]).get("action", "")) == RuntimePerkChoiceCompletion.CLOSE_ACTION_START_STARPOINT_ABSORPTION, "close step 2 should start absorption")
		_expect(str(_as_dict(close_steps[3]).get("action", "")) == RuntimePerkChoiceCompletion.CLOSE_ACTION_SYNC_OWNER, "close step 3 should sync owner")
		_expect(str(_as_dict(close_steps[3]).get("perf_label", "")).find("finish_success.sync_owner") >= 0, "close steps should carry helper-owned perf labels")

	var active_plan: Dictionary = helper.build_modal_close_plan(true, false)
	_expect(not bool(active_plan.get(RuntimePerkChoiceCompletion.CLOSE_ACTION_RESUME_SKILL_COOLDOWNS, true)), "active next modal should not resume cooldowns")
	var active_steps: Array = helper.build_modal_close_steps(active_plan)
	_expect(active_steps.size() == 1, "active next modal should only sync owner")
	var swap_plan: Dictionary = helper.build_modal_close_plan(false, true)
	_expect(not bool(swap_plan.get(RuntimePerkChoiceCompletion.CLOSE_ACTION_START_STARPOINT_ABSORPTION, true)), "pending swap should block final absorption")
	var swap_steps: Array = helper.build_modal_close_steps(swap_plan)
	_expect(swap_steps.size() == 1, "pending swap should only sync owner")


func _verify_state_source_contract() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var finish_flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_finish_flow.gd")
	_expect(state_source.find("RuntimePerkChoiceCompletion") >= 0, "state should preload the completion helper")
	_expect(state_source.find("RuntimePerkChoiceFinishFlow") >= 0, "state should preload the finish-flow helper")
	_expect(state_source.find("_choice_finish_flow.finish_successful_choice") >= 0, "state should route successful-choice finish through finish-flow helper")
	_expect(finish_flow_source.find("build_success_state_update_for_choice") >= 0, "finish-flow helper should consume helper-owned choice success payload")
	_expect(finish_flow_source.find("apply_success_state_update") >= 0, "finish-flow helper should delegate success state application")
	_expect(finish_flow_source.find("build_next_choice_context") >= 0, "finish-flow helper should delegate next-choice context snapshotting")
	_expect(finish_flow_source.find("build_post_state_plan") >= 0, "finish-flow helper should consume helper-owned post-state plan")
	_expect(finish_flow_source.find("apply_post_state_plan") >= 0, "finish-flow helper should delegate post-state plan application")
	_expect(finish_flow_source.find("build_modal_close_plan") >= 0, "finish-flow helper should consume helper-owned modal close plan")
	_expect(finish_flow_source.find("build_modal_close_steps") >= 0, "finish-flow helper should consume helper-owned modal close steps")
	var finish_body: String = _function_body(state_source, "func _finish_successful_choice(")
	_expect(finish_body.find("selected_choice_sequence += 1") < 0, "finish-success body should not own sequence increment inline")
	_expect(finish_body.find("pending_skill_choices = max(0, pending_skill_choices - 1)") < 0, "finish-success body should not own pending-choice consume formula inline")
	_expect(finish_body.find("last_selected_id =") < 0, "finish-success body should not apply last-selected state inline")
	_expect(finish_body.find("current_choices.clear()") < 0, "finish-success body should not clear choices inline")
	_expect(finish_body.find("current_choice_context.clear()") < 0, "finish-success body should not clear choice context inline")
	_expect(finish_body.find("current_choice_context.duplicate(true)") < 0, "finish-success body should not snapshot next-choice context inline")
	_expect(finish_body.find("_snapshot_builder.build_selected_choice") < 0, "finish-success body should not build selected-choice snapshots inline")
	_expect(finish_body.find("if not choice_active and not has_pending_unlock_swap()") < 0, "finish-success body should not own modal-close gating inline")
	_expect(finish_body.find("close_plan.get(\"resume_skill_cooldowns\"") < 0, "finish-success body should not inspect close-plan cooldown key inline")
	_expect(finish_body.find("finish_success.resume_skill_cooldowns") < 0, "finish-success body should not own close-step perf labels")
	_expect(finish_body.find("build_success_state_update_for_choice") < 0, "state finish-success wrapper should not build success payloads directly")
	_expect(finish_body.find("build_post_state_plan") < 0, "state finish-success wrapper should not build post-state plans directly")
	_expect(finish_body.find("build_modal_close_steps") < 0, "state finish-success wrapper should not iterate modal close steps directly")


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)


func _as_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class FakeRuntimeState:
	var last_selected_id := ""
	var last_selected_choice: Dictionary = {}
	var selected_choice_sequence := 0
	var pending_skill_choices := 0
	var choice_active := true
	var current_choices: Array = []
	var animation_time := 1.0
	var feedback_text := ""
	var feedback_timer := 0.0
	var current_choice_context: Dictionary = {}
