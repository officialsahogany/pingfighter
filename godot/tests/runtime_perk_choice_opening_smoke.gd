extends SceneTree

const RuntimePerkChoiceOpening := preload("res://scripts/characters/runtime_perk_choice_opening.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_choice_active_query()
	_verify_unavailable_state_update()
	_verify_empty_choices_state_update()
	_verify_generated_choices_state_update()
	_verify_ready_state_update()
	_verify_active_tick_state_update()
	_verify_state_source_contract()

	if _failures.is_empty():
		print("runtime_perk_choice_opening_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_choice_active_query() -> void:
	var helper := RuntimePerkChoiceOpening.new()
	_expect(helper.is_choice_active(true, false), "choice-active query should accept active choices")
	_expect(helper.is_choice_active(false, true), "choice-active query should accept pending swap modal")
	_expect(not helper.is_choice_active(false, false), "choice-active query should reject fully inactive state")

	var state := FakeRuntimeState.new()
	state.choice_active = true
	_expect(helper.is_choice_active_from_runtime_state(state), "runtime-state active query should accept active choices")
	state.choice_active = false
	state.pending_unlock_swap = {"choice_id": "unlock_skill"}
	_expect(helper.is_choice_active_from_runtime_state(state), "runtime-state active query should accept pending swap modal")
	state.pending_unlock_swap.clear()
	_expect(not helper.is_choice_active_from_runtime_state(state), "runtime-state active query should reject inactive state")
	_expect(not helper.is_choice_active_from_runtime_state(null), "runtime-state active query should reject missing state")


func _verify_unavailable_state_update() -> void:
	var helper := RuntimePerkChoiceOpening.new()
	var state := FakeRuntimeState.new()
	state.current_choices = [{"id": "a"}]
	state.current_choice_context = {"keep": true}
	state.current_perk_slot_status = {"count": 3}
	var update: Dictionary = helper.build_unavailable_state_update(true)
	var result: Dictionary = helper.apply_state_update(state, update)
	_expect(bool(result.get("accepted", false)), "unavailable update should apply")
	_expect(not state.choice_active, "unavailable update should close the modal")
	_expect(state.current_choices.is_empty(), "unavailable update should clear choices when requested")
	_expect(state.current_choice_context.is_empty(), "unavailable update should clear choice context")
	_expect(state.current_perk_slot_status.is_empty(), "unavailable update should clear slot status")
	_expect(bool(result.get("resume_skill_cooldowns", false)), "unavailable update should request cooldown resume")

	state.current_choices = [{"id": "b"}]
	var no_clear_update: Dictionary = helper.build_unavailable_state_update(false)
	helper.apply_state_update(state, no_clear_update)
	_expect(not state.current_choices.is_empty(), "unavailable update should preserve choices when not requested")


func _verify_empty_choices_state_update() -> void:
	var helper := RuntimePerkChoiceOpening.new()
	var state := FakeRuntimeState.new()
	state.pending_skill_choices = 2
	state.current_choice_context = {"chain": true}
	state.current_perk_slot_status = {"count": 2}
	var continue_update: Dictionary = helper.build_empty_choices_state_update(state.pending_skill_choices)
	var continue_result: Dictionary = helper.apply_state_update(state, continue_update)
	_expect(int(continue_result.get("pending_skill_choices", 0)) == 1, "empty choices should consume one pending choice")
	_expect(bool(continue_result.get("choice_active", false)), "empty choices should stay active when another pick is pending")
	_expect(bool(continue_result.get("open_next_choice", false)), "empty choices should request opening the next choice")
	_expect(not bool(continue_result.get("resume_skill_cooldowns", true)), "empty choices should keep cooldowns paused when another choice opens")
	_expect(not state.current_choice_context.is_empty(), "empty choices should preserve context while chaining")
	_expect(not state.current_perk_slot_status.is_empty(), "empty choices should preserve slot status while chaining")

	var final_state := FakeRuntimeState.new()
	final_state.pending_skill_choices = 1
	final_state.current_choice_context = {"chain": true}
	final_state.current_perk_slot_status = {"count": 2}
	var close_result: Dictionary = helper.apply_state_update(
		final_state,
		helper.build_empty_choices_state_update(final_state.pending_skill_choices)
	)
	_expect(int(close_result.get("pending_skill_choices", -1)) == 0, "final empty choices should consume the last pending choice")
	_expect(not bool(close_result.get("choice_active", true)), "final empty choices should close the modal")
	_expect(not bool(close_result.get("open_next_choice", true)), "final empty choices should not request another open")
	_expect(bool(close_result.get("resume_skill_cooldowns", false)), "final empty choices should resume cooldowns")
	_expect(final_state.current_choice_context.is_empty(), "final empty choices should clear context")
	_expect(final_state.current_perk_slot_status.is_empty(), "final empty choices should clear slot status")
	_expect(not bool(helper.apply_state_update(null, close_result).get("accepted", true)), "state update should reject missing state")


func _verify_generated_choices_state_update() -> void:
	var helper := RuntimePerkChoiceOpening.new()
	var state := FakeRuntimeState.new()
	var choice_context := {"source": "chain", "nested": {"value": 1}}
	var choices := [{"id": "a", "nested": {"value": 2}}]
	var slot_status := {"count": 2, "nested": {"limit": 4}}
	var result: Dictionary = helper.apply_state_update(
		state,
		helper.build_generated_choices_state_update(choice_context, choices, slot_status)
	)
	_expect(bool(result.get("accepted", false)), "generated choices update should apply")
	_expect(str(state.current_choice_context.get("source", "")) == "chain", "generated choices update should write context")
	_expect(state.current_choices.size() == 1, "generated choices update should write choices")
	_expect(int(state.current_perk_slot_status.get("count", 0)) == 2, "generated choices update should write slot status")
	_get_dict(state.current_choice_context.get("nested", {}))["value"] = 9
	_get_dict(_get_dict(state.current_choices[0]).get("nested", {}))["value"] = 9
	_get_dict(state.current_perk_slot_status.get("nested", {}))["limit"] = 99
	_expect(int(_get_dict(choice_context.get("nested", {})).get("value", 0)) == 1, "generated choices update should deep-copy context")
	_expect(int(_get_dict(_get_dict(choices[0]).get("nested", {})).get("value", 0)) == 2, "generated choices update should deep-copy choices")
	_expect(int(_get_dict(slot_status.get("nested", {})).get("limit", 0)) == 4, "generated choices update should deep-copy slot status")

	var dowsing_update := {
		"accepted": true,
		"current_choices": [{"id": "bonus"}],
	}
	helper.apply_state_update(state, dowsing_update)
	_expect(str(_get_dict(state.current_choices[0]).get("id", "")) == "bonus", "opening state application should accept current-choice patches")


func _verify_ready_state_update() -> void:
	var helper := RuntimePerkChoiceOpening.new()
	var state := FakeRuntimeState.new()
	state.selected_index = 99
	state.gamepad_choice_horizontal_latch = 1
	state.animation_time = 2.5
	state.choice_active = false
	var update: Dictionary = helper.build_ready_state_update(3)
	var result: Dictionary = helper.apply_state_update(state, update)
	_expect(bool(result.get("accepted", false)), "ready update should apply")
	_expect(state.selected_index == 1, "ready update should select the center card for three choices")
	_expect(state.gamepad_choice_horizontal_latch == 0, "ready update should reset gamepad horizontal latch")
	_expect(is_equal_approx(state.animation_time, 0.0), "ready update should reset animation time")
	_expect(state.choice_active, "ready update should activate the choice modal")
	_expect(bool(result.get("tick_lingpet_ring_core_offer_cooldown", false)), "ready update should request Lingpet cooldown tick")
	_expect(bool(result.get("pause_skill_cooldowns", false)), "ready update should request skill cooldown pause")
	_expect(bool(result.get("build_particles", false)), "ready update should request particle rebuild")

	var one_choice_state := FakeRuntimeState.new()
	helper.apply_state_update(one_choice_state, helper.build_ready_state_update(1))
	_expect(one_choice_state.selected_index == 0, "ready update should select the only card for one choice")
	_expect(not bool(helper.build_ready_state_update(0).get("accepted", true)), "ready update should reject empty choices")


func _verify_active_tick_state_update() -> void:
	var helper := RuntimePerkChoiceOpening.new()
	var state := FakeRuntimeState.new()
	state.animation_time = 0.5
	var tick_update: Dictionary = helper.build_active_tick_state_update(state.animation_time, 0.25, true)
	var tick_result: Dictionary = helper.apply_state_update(state, tick_update)
	_expect(bool(tick_result.get("accepted", false)), "active tick update should apply")
	_expect(is_equal_approx(state.animation_time, 0.75), "active tick update should advance animation time")
	_expect(bool(tick_result.get("update_particles", false)), "active tick update should request particle update")
	_expect(not bool(helper.build_active_tick_state_update(state.animation_time, 0.25, false).get("accepted", true)), "inactive tick update should reject")


func _verify_state_source_contract() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var open_flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_open_flow.gd")
	var update_flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_update_flow.gd")
	_expect(state_source.find("RuntimePerkChoiceOpening") >= 0, "state should preload the choice-opening helper")
	_expect(state_source.find("RuntimePerkChoiceOpenFlow") >= 0, "state should preload the choice open-flow helper")
	_expect(state_source.find("_choice_open_flow.open_next_choice") >= 0, "state should delegate open-next orchestration")
	_expect(open_flow_source.find("build_unavailable_state_update") >= 0, "open-flow should consume unavailable opening updates")
	_expect(open_flow_source.find("build_empty_choices_state_update") >= 0, "open-flow should consume empty-choice updates")
	_expect(open_flow_source.find("build_generated_choices_state_update") >= 0, "open-flow should consume generated-choice state updates")
	_expect(open_flow_source.find("build_ready_state_update") >= 0, "open-flow should consume ready opening updates")
	_expect(state_source.find("RuntimePerkUpdateFlow") >= 0, "state should preload the update-flow helper")
	_expect(state_source.find("_update_flow.update_internal") >= 0, "state should delegate active tick updates through update flow")
	_expect(update_flow_source.find("build_active_tick_state_update") >= 0, "update flow should consume active tick opening updates")
	var active_body: String = _function_body(state_source, "func is_choice_active(")
	_expect(state_source.find("_choice_opening.is_choice_active_from_runtime_state") >= 0, "state should delegate runtime-state choice-active query")
	_expect(active_body.find("_choice_opening.is_choice_active(choice_active") < 0, "state choice-active wrapper should not pass choice-active flag inline")
	_expect(active_body.find("runtime_state.get(\"choice_active\")") < 0, "state choice-active wrapper should not read choice-active flag inline")
	_expect(active_body.find("has_pending_unlock_swap") < 0, "state choice-active wrapper should not query pending swap inline")
	_expect(state_source.find("_apply_choice_opening_update") >= 0, "state should apply choice-opening updates through one wrapper")
	var open_body: String = _function_body(state_source, "func open_next_choice(")
	var update_body: String = _function_body(state_source, "func _update_internal(")
	_expect(open_body.find("pending_skill_choices = max(0, pending_skill_choices - 1)") < 0, "open-next body should not own empty-choice pending decrement inline")
	_expect(open_body.find("current_perk_slot_status.clear()") < 0, "open-next body should not clear slot status inline")
	_expect(open_body.find("current_choices.clear()") < 0, "open-next body should not clear current choices inline")
	_expect(open_body.find("current_choice_context = choice_context.duplicate(true)") < 0, "open-next body should not apply choice context inline")
	_expect(open_body.find("current_choices = catalog.get_choices") < 0, "open-next body should not apply catalog choices inline")
	_expect(open_body.find("current_perk_slot_status = _choice_offer_modifiers.build_perk_slot_status") < 0, "open-next body should not apply slot status inline")
	_expect(open_body.find("current_choices = _get_array(bonus_choice_update.get") < 0, "open-next body should not apply Dowsing choices inline")
	_expect(open_body.find("selected_index = min(1, current_choices.size() - 1)") < 0, "open-next body should not own ready selected-index reset inline")
	_expect(open_body.find("gamepad_choice_horizontal_latch = 0") < 0, "open-next body should not own ready gamepad latch reset inline")
	_expect(open_body.find("animation_time = 0.0") < 0, "open-next body should not own ready animation reset inline")
	_expect(open_body.find("choice_active = true") < 0, "open-next body should not own ready active flag inline")
	_expect(update_body.find("animation_time += delta") < 0, "update body should not own active animation tick inline")


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


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


class FakeRuntimeState:
	var pending_skill_choices := 0
	var choice_active := true
	var selected_index := 0
	var gamepad_choice_horizontal_latch := 0
	var animation_time := 0.0
	var current_choices: Array = []
	var current_choice_context: Dictionary = {}
	var current_perk_slot_status: Dictionary = {}
	var pending_unlock_swap: Dictionary = {}
