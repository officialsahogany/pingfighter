extends SceneTree

const RuntimePerkChoiceSelection := preload("res://scripts/characters/runtime_perk_choice_selection.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_selectable_query()
	_verify_selection_helper()
	_verify_selected_choice_payload()
	_verify_state_consumes_helper()
	_verify_state_source_contract()

	if _failures.is_empty():
		print("runtime_perk_choice_selection_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_selectable_query() -> void:
	var helper := RuntimePerkChoiceSelection.new()
	_expect(
		helper.is_selectable(true, false, false, false, RuntimePerkChoiceSelection.MIN_SELECTABLE_ANIMATION_TIME, 3),
		"selectable query should accept active ready choices"
	)
	_expect(not helper.is_selectable(false, false, false, false, 1.0, 3), "selectable query should reject inactive choices")
	_expect(not helper.is_selectable(true, true, false, false, 1.0, 3), "selectable query should reject active flight")
	_expect(not helper.is_selectable(true, false, true, false, 1.0, 3), "selectable query should reject active showcase")
	_expect(not helper.is_selectable(true, false, false, true, 1.0, 3), "selectable query should reject pending swap")
	_expect(not helper.is_selectable(true, false, false, false, 0.23, 3), "selectable query should reject early animation")
	_expect(not helper.is_selectable(true, false, false, false, 1.0, 0), "selectable query should reject empty choices")

	var state := FakeRuntimeState.new()
	state.choice_active = true
	state.animation_time = RuntimePerkChoiceSelection.MIN_SELECTABLE_ANIMATION_TIME
	state.current_choices = [{"id": "a"}]
	_expect(helper.is_selectable_from_runtime_state(state), "runtime-state selectable facade should accept ready choices")
	state.choice_flight_effect = {"active": true}
	_expect(not helper.is_selectable_from_runtime_state(state), "runtime-state selectable facade should reject active choice flight")
	state.choice_flight_effect.clear()
	state.unlock_showcase = {"active": true}
	_expect(not helper.is_selectable_from_runtime_state(state), "runtime-state selectable facade should reject active unlock showcase")
	state.unlock_showcase.clear()
	state.pending_unlock_swap = {"choice_id": "pending"}
	_expect(not helper.is_selectable_from_runtime_state(state), "runtime-state selectable facade should reject pending swap")
	state.pending_unlock_swap.clear()
	state.current_choices.clear()
	_expect(not helper.is_selectable_from_runtime_state(state), "runtime-state selectable facade should reject empty current choices")
	_expect(not helper.is_selectable_from_runtime_state(null), "runtime-state selectable facade should reject missing state")


func _verify_selection_helper() -> void:
	var helper := RuntimePerkChoiceSelection.new()
	var forward: Dictionary = helper.build_move_selection_update(1, 1, 3)
	_expect(int(forward.get("selected_index", -1)) == 2, "move selection should advance inside range")
	var wrap_forward: Dictionary = helper.build_move_selection_update(2, 1, 3)
	_expect(int(wrap_forward.get("selected_index", -1)) == 0, "move selection should wrap forward")
	var wrap_backward: Dictionary = helper.build_move_selection_update(0, -1, 3)
	_expect(int(wrap_backward.get("selected_index", -1)) == 2, "move selection should wrap backward")
	_expect(not bool(helper.build_move_selection_update(0, 1, 0).get("accepted", false)), "move selection should reject empty choices")

	var direct: Dictionary = helper.build_direct_selection_update(1, 3)
	_expect(bool(direct.get("accepted", false)), "direct selection should accept in-range indices")
	_expect(int(direct.get("selected_index", -1)) == 1, "direct selection should preserve the chosen index")
	_expect(not bool(helper.build_direct_selection_update(-1, 3).get("accepted", false)), "direct selection should reject negative indices")
	_expect(not bool(helper.build_direct_selection_update(3, 3).get("accepted", false)), "direct selection should reject choice-count index")
	_expect(not bool(helper.apply_state_update(null, direct).get("accepted", true)), "state application should reject missing state")

	var state := FakeRuntimeState.new()
	state.current_choices = [{"id": "a"}, {"id": "b"}, {"id": "c"}]
	state.selected_index = 0
	_expect(bool(helper.move_selection_from_runtime_state(state, -1).get("accepted", false)), "runtime-state move facade should accept valid states")
	_expect(state.selected_index == 2, "runtime-state move facade should wrap using current choices")
	_expect(bool(helper.select_index_from_runtime_state(state, 1).get("accepted", false)), "runtime-state direct facade should accept in-range index")
	_expect(state.selected_index == 1, "runtime-state direct facade should apply selected index")
	_expect(not bool(helper.select_index_from_runtime_state(state, 5).get("accepted", false)), "runtime-state direct facade should reject out-of-range index")
	_expect(state.selected_index == 1, "runtime-state direct facade should preserve selection after rejection")
	_expect(not bool(helper.move_selection_from_runtime_state(null, 1).get("accepted", true)), "runtime-state move facade should reject missing state")


func _verify_selected_choice_payload() -> void:
	var helper := RuntimePerkChoiceSelection.new()
	var choices: Array = [{"id": "a", "name": "A"}, {"id": "b", "name": "B"}]
	var payload: Dictionary = helper.build_selected_choice_payload(choices, 1, true)
	_expect(bool(payload.get("accepted", false)), "selected choice payload should accept a selectable in-range choice")
	_expect(str(payload.get("choice_id", "")) == "b", "selected choice payload should expose the choice id")
	var choice: Dictionary = _get_dict(payload.get("choice", {}))
	choice["id"] = "mutated"
	_expect(str(_get_dict(choices[1]).get("id", "")) == "b", "selected choice payload should deep-copy the choice")
	_expect(not bool(helper.build_selected_choice_payload(choices, 0, false).get("accepted", false)), "selected choice payload should reject non-selectable state")
	_expect(not bool(helper.build_selected_choice_payload(choices, -1, true).get("accepted", false)), "selected choice payload should reject negative selected index")
	_expect(not bool(helper.build_selected_choice_payload(choices, 2, true).get("accepted", false)), "selected choice payload should reject out-of-range selected index")
	_expect(not bool(helper.build_selected_choice_payload([{"name": "Missing"}], 0, true).get("accepted", false)), "selected choice payload should reject choices without ids")


func _verify_state_consumes_helper() -> void:
	var helper := RuntimePerkChoiceSelection.new()
	var state := RuntimePerkState.new()
	state.current_choices = [{"id": "a"}, {"id": "b"}, {"id": "c"}]
	state.selected_index = 0
	state.move_selection(-1)
	_expect(state.selected_index == 2, "state move_selection should consume helper wrap update")
	state.move_selection(1)
	_expect(state.selected_index == 0, "state move_selection should consume helper forward update")
	state._select_choice_index(1)
	_expect(state.selected_index == 1, "state should apply direct helper selection updates")
	state._select_choice_index(5)
	_expect(state.selected_index == 1, "state should ignore rejected direct selection updates")


func _verify_state_source_contract() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_selection.gd")
	var confirm_flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_confirm_flow.gd")
	var move_body: String = _function_body(state_source, "func move_selection(")
	var direct_body: String = _function_body(state_source, "func _select_choice_index(")
	var selectable_body: String = _function_body(state_source, "func is_selectable(")
	var input_body: String = _function_body(state_source, "func handle_input(")
	_expect(state_source.find("RuntimePerkChoiceSelection") >= 0, "state should preload the choice-selection helper")
	_expect(state_source.find("RuntimePerkChoiceConfirmFlow") >= 0, "state should preload the choice-confirm helper")
	_expect(helper_source.find("func is_selectable_from_runtime_state(") >= 0, "helper should expose runtime-state selectable facade")
	_expect(selectable_body.find("_choice_selection.is_selectable_from_runtime_state") >= 0, "state selectable wrapper should delegate runtime-state selectable facade")
	_expect(selectable_body.find("is_choice_flight_active") < 0, "state selectable wrapper should not query choice flight inline")
	_expect(selectable_body.find("is_unlock_showcase_active") < 0, "state selectable wrapper should not query unlock showcase inline")
	_expect(selectable_body.find("has_pending_unlock_swap") < 0, "state selectable wrapper should not query pending swap inline")
	_expect(selectable_body.find("current_choices.size()") < 0, "state selectable wrapper should not read choice count inline")
	_expect(selectable_body.find("animation_time") < 0, "state selectable wrapper should not read animation time inline")
	_expect(helper_source.find("func move_selection_from_runtime_state(") >= 0, "helper should expose runtime-state move facade")
	_expect(helper_source.find("func select_index_from_runtime_state(") >= 0, "helper should expose runtime-state direct selection facade")
	_expect(move_body.find("_choice_selection.move_selection_from_runtime_state") >= 0, "state move wrapper should delegate runtime-state move facade")
	_expect(direct_body.find("_choice_selection.select_index_from_runtime_state") >= 0, "state direct selection wrapper should delegate runtime-state direct facade")
	_expect(move_body.find("build_move_selection_update") < 0, "state move wrapper should not build move updates inline")
	_expect(direct_body.find("build_direct_selection_update") < 0, "state direct selection wrapper should not build direct updates inline")
	_expect(move_body.find("current_choices.size()") < 0, "state move wrapper should not read choice count inline")
	_expect(direct_body.find("current_choices.size()") < 0, "state direct selection wrapper should not read choice count inline")
	_expect(confirm_flow_source.find("build_selected_choice_payload") >= 0, "confirm-flow helper should consume helper-owned selected choice payloads")
	_expect(state_source.find("_choice_selection.is_selectable") >= 0, "state should delegate selectable query")
	_expect(state_source.find("animation_time >= 0.24") < 0, "state should not inline selectable animation threshold")
	_expect(state_source.find("not current_choices.is_empty()") < 0, "state should not inline selectable choice-count gate")
	_expect(move_body.find("selected_index = posmod(selected_index + delta_index, current_choices.size())") < 0, "state should not inline choice-selection wrap math")
	_expect(input_body.find("selected_index = clicked_index") < 0, "state should not inline mouse click selection")
	_expect(input_body.find("selected_index = hovered_index") < 0, "state should not inline mouse hover selection")
	var choose_body: String = _function_body(state_source, "func choose_selected(")
	_expect(choose_body.find("_choice_confirm_flow.choose_selected") >= 0, "state choose_selected should delegate selected choice confirmation")
	_expect(choose_body.find("build_selected_choice_payload") < 0, "state choose_selected should not build selected choice payloads directly")
	_expect(choose_body.find("if not is_selectable():") < 0, "state should not inline selectable gate in choose_selected")
	_expect(choose_body.find("selected_index < 0 or selected_index >= current_choices.size()") < 0, "state should not inline selected-index range gate")
	_expect(choose_body.find("choice_id == \"\"") < 0, "state should not inline empty choice-id gate")


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
	var current_choices: Array = []
	var selected_index := 0
	var choice_active := false
	var choice_flight_effect: Dictionary = {}
	var unlock_showcase: Dictionary = {}
	var pending_unlock_swap: Dictionary = {}
	var animation_time := 0.0

	func has_pending_unlock_swap() -> bool:
		return not pending_unlock_swap.is_empty()
