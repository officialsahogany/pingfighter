extends SceneTree

const RuntimePerkChoiceConfirmFlow := preload("res://scripts/characters/runtime_perk_choice_confirm_flow.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_choose_starts_flight_before_apply()
	_verify_runtime_state_facade_choose_starts_flight_before_apply()
	_verify_choose_applies_and_finishes_without_flight()
	_verify_choice_apply_failure_feedback()
	_verify_flight_finish_applies_and_finishes()
	_verify_runtime_state_facade_flight_finish_applies_and_finishes()
	_verify_source_contract()

	if _failures.is_empty():
		print("runtime_perk_choice_confirm_flow_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_choose_starts_flight_before_apply() -> void:
	var state := FakeRuntimeState.new()
	var selection := FakeChoiceSelection.new(_selection("unlock_plasma", {"id": "unlock_plasma", "unlocks_skill": "plasma"}))
	var flight := FakeActiveUnlockFlight.new()
	flight.effect_to_build = {"active": true, "choice_id": "unlock_plasma", "skill_id": "plasma"}
	var result: Dictionary = _helper().choose_selected(
		[{"id": "unlock_plasma"}],
		0,
		FakeOwner.new(),
		FakeRegistry.new(),
		Vector2(1280.0, 720.0),
		state,
		selection,
		flight,
		_helper().build_state_callbacks(state)
	)
	_expect(bool(result.get("accepted", false)), "confirm flow should accept a flight-start result")
	_expect(bool(result.get("started_flight", false)), "confirm flow should report a started flight")
	_expect(state.apply_choice_calls == 0, "flight-start path should not apply the choice before landing")
	_expect(state.active_flight_audio_calls == 1, "flight-start path should play active-unlock flight audio")
	_expect(bool(state.choice_flight_effect.get("active", false)), "flight-start path should write active flight state")


func _verify_runtime_state_facade_choose_starts_flight_before_apply() -> void:
	var state := FakeRuntimeState.new()
	state.current_choices = [{"id": "unlock_plasma"}]
	state.selected_index = 0
	state._choice_selection = FakeChoiceSelection.new(_selection("unlock_plasma", {"id": "unlock_plasma", "unlocks_skill": "plasma"}))
	var flight := FakeActiveUnlockFlight.new()
	flight.effect_to_build = {"active": true, "choice_id": "unlock_plasma", "skill_id": "plasma"}
	state._active_unlock_flight = flight
	var result: Dictionary = _helper().choose_selected_from_runtime_state(
		state,
		FakeOwner.new(),
		FakeRegistry.new(),
		Vector2(1280.0, 720.0)
	)
	_expect(bool(result.get("accepted", false)), "runtime-state facade should accept a flight-start result")
	_expect(bool(result.get("started_flight", false)), "runtime-state facade should report a started flight")
	_expect(state.apply_choice_calls == 0, "runtime-state facade flight-start path should not apply before landing")
	_expect(state.active_flight_audio_calls == 1, "runtime-state facade flight-start path should play active-unlock flight audio")
	_expect(bool(state.choice_flight_effect.get("active", false)), "runtime-state facade should write active flight state")


func _verify_choose_applies_and_finishes_without_flight() -> void:
	var state := FakeRuntimeState.new()
	var selection := FakeChoiceSelection.new(_selection("common_bulk_up", {"id": "common_bulk_up", "name": "Bulk"}))
	var flight := FakeActiveUnlockFlight.new()
	var result: Dictionary = _helper().choose_selected(
		[{"id": "common_bulk_up"}],
		0,
		FakeOwner.new(),
		FakeRegistry.new(),
		Vector2.ZERO,
		state,
		selection,
		flight,
		_helper().build_state_callbacks(state)
	)
	_expect(bool(result.get("accepted", false)), "confirm flow should apply ordinary selected choices")
	_expect(state.apply_choice_calls == 1, "ordinary selected choice should apply once")
	_expect(state.perk_select_audio_calls == 1, "ordinary selected choice should play perk-select audio")
	_expect(state.finish_or_showcase_calls == 1, "ordinary selected choice should hand off to finish/showcase")
	_expect(state.failure_feedback_calls == 0, "ordinary selected choice should not show failure feedback")


func _verify_choice_apply_failure_feedback() -> void:
	var state := FakeRuntimeState.new()
	state.apply_choice_result = false
	var selection := FakeChoiceSelection.new(_selection("common_bulk_up", {"id": "common_bulk_up", "name": "Bulk"}))
	var result: Dictionary = _helper().choose_selected(
		[{"id": "common_bulk_up"}],
		0,
		FakeOwner.new(),
		FakeRegistry.new(),
		Vector2.ZERO,
		state,
		selection,
		FakeActiveUnlockFlight.new(),
		_helper().build_state_callbacks(state)
	)
	_expect(not bool(result.get("accepted", true)), "confirm flow should reject failed choice application")
	_expect(state.failure_feedback_calls == 1, "failed choice application should show failure feedback")
	_expect(state.finish_or_showcase_calls == 0, "failed choice application should not finish the choice")


func _verify_flight_finish_applies_and_finishes() -> void:
	var state := FakeRuntimeState.new()
	var flight := FakeActiveUnlockFlight.new()
	flight.advance_result = true
	state.choice_flight_effect = {
		"active": true,
		"choice_id": "unlock_plasma",
		"choice": {"id": "unlock_plasma", "unlocks_skill": "plasma"},
	}
	flight.landing_payload = {
		"accepted": true,
		"choice_id": "unlock_plasma",
		"choice": {"id": "unlock_plasma", "unlocks_skill": "plasma"},
	}
	var result: Dictionary = _helper().update_choice_flight_effect(
		state.choice_flight_effect,
		2.0,
		FakeOwner.new(),
		FakeRegistry.new(),
		flight,
		_helper().build_state_callbacks(state)
	)
	_expect(bool(result.get("accepted", false)), "confirm flow should accept successful flight finishes")
	_expect(bool(result.get("finished", false)), "confirm flow should report finished flights")
	_expect(state.choice_flight_effect.is_empty(), "flight finish should consume and clear flight state")
	_expect(state.apply_choice_calls == 1, "flight finish should apply the landed choice once")
	_expect(state.finish_or_showcase_calls == 1, "flight finish should hand off to finish/showcase once")


func _verify_runtime_state_facade_flight_finish_applies_and_finishes() -> void:
	var state := FakeRuntimeState.new()
	var flight := FakeActiveUnlockFlight.new()
	flight.advance_result = true
	state._active_unlock_flight = flight
	state.choice_flight_effect = {
		"active": true,
		"choice_id": "unlock_plasma",
		"choice": {"id": "unlock_plasma", "unlocks_skill": "plasma"},
	}
	flight.landing_payload = {
		"accepted": true,
		"choice_id": "unlock_plasma",
		"choice": {"id": "unlock_plasma", "unlocks_skill": "plasma"},
	}
	var result: Dictionary = _helper().update_choice_flight_effect_from_runtime_state(
		state,
		2.0,
		FakeOwner.new(),
		FakeRegistry.new()
	)
	_expect(bool(result.get("accepted", false)), "runtime-state facade should accept successful flight finishes")
	_expect(bool(result.get("finished", false)), "runtime-state facade should report finished flights")
	_expect(state.choice_flight_effect.is_empty(), "runtime-state facade flight finish should consume and clear flight state")
	_expect(state.apply_choice_calls == 1, "runtime-state facade flight finish should apply the landed choice once")
	_expect(state.finish_or_showcase_calls == 1, "runtime-state facade flight finish should hand off to finish/showcase once")


func _verify_source_contract() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_confirm_flow.gd")
	var choose_body: String = _function_body(state_source, "func choose_selected(")
	var update_body: String = _function_body(state_source, "func _update_choice_flight_effect(")
	var choose_facade_body: String = _function_body(helper_source, "func choose_selected_from_runtime_state(")
	var update_facade_body: String = _function_body(helper_source, "func update_choice_flight_effect_from_runtime_state(")
	_expect(state_source.find("RuntimePerkChoiceConfirmFlow") >= 0, "state should preload choice confirm-flow helper")
	_expect(choose_body.find("_choice_confirm_flow.choose_selected_from_runtime_state") >= 0, "state choose_selected should delegate runtime-state assembly to confirm-flow helper")
	_expect(update_body.find("_choice_confirm_flow.update_choice_flight_effect_from_runtime_state") >= 0, "state flight update should delegate runtime-state assembly to confirm-flow helper")
	_expect(choose_body.find("current_choices") < 0, "state choose_selected should not pass current choices inline")
	_expect(choose_body.find("selected_index") < 0, "state choose_selected should not pass selected index inline")
	_expect(choose_body.find("_choice_selection") < 0, "state choose_selected should not pass choice-selection helper inline")
	_expect(choose_body.find("_active_unlock_flight") < 0, "state choose_selected should not pass active-unlock flight helper inline")
	_expect(choose_body.find("build_state_callbacks(self)") < 0, "state choose_selected should not build callback map inline")
	_expect(update_body.find("\n\t\tchoice_flight_effect") < 0, "state flight update should not pass flight-effect state inline")
	_expect(update_body.find("_active_unlock_flight") < 0, "state flight update should not pass active-unlock flight helper inline")
	_expect(update_body.find("build_state_callbacks(self)") < 0, "state flight update should not build callback map inline")
	_expect(helper_source.find("func choose_selected_from_runtime_state(") >= 0, "confirm-flow helper should expose choose runtime-state facade")
	_expect(helper_source.find("func update_choice_flight_effect_from_runtime_state(") >= 0, "confirm-flow helper should expose flight-update runtime-state facade")
	_expect(choose_facade_body.find("current_choices") >= 0, "confirm-flow choose facade should own current-choice lookup")
	_expect(choose_facade_body.find("selected_index") >= 0, "confirm-flow choose facade should own selected-index lookup")
	_expect(choose_facade_body.find("_choice_selection") >= 0, "confirm-flow choose facade should own choice-selection lookup")
	_expect(choose_facade_body.find("_active_unlock_flight") >= 0, "confirm-flow choose facade should own active-unlock flight lookup")
	_expect(choose_facade_body.find("build_state_callbacks(runtime_state)") >= 0, "confirm-flow choose facade should own callback-map assembly")
	_expect(update_facade_body.find("choice_flight_effect") >= 0, "confirm-flow flight facade should own flight-effect lookup")
	_expect(update_facade_body.find("_active_unlock_flight") >= 0, "confirm-flow flight facade should own active-unlock flight lookup")
	_expect(update_facade_body.find("build_state_callbacks(runtime_state)") >= 0, "confirm-flow flight facade should own callback-map assembly")
	_expect(state_source.find("func _try_start_active_unlock_flight(") < 0, "state should not keep active-unlock flight start orchestration")
	_expect(state_source.find("func _finish_choice_flight_effect(") < 0, "state should not keep active-unlock flight finish orchestration")
	_expect(choose_body.find("build_selected_choice_payload") < 0, "state choose_selected should not build selected-choice payloads directly")
	_expect(choose_body.find("apply_choice(choice") < 0, "state choose_selected should not apply choices directly")
	_expect(helper_source.find("build_selected_choice_payload") >= 0, "confirm-flow helper should consume selected-choice payloads")
	_expect(helper_source.find("build_effect_for_selected_card") >= 0, "confirm-flow helper should build selected-card active-unlock flights")
	_expect(helper_source.find("apply_effect_state_update") >= 0, "confirm-flow helper should apply active-unlock flight state")
	_expect(helper_source.find("consume_effect") >= 0, "confirm-flow helper should consume active-unlock flight state")
	_expect(helper_source.find("build_landing_payload") >= 0, "confirm-flow helper should validate flight landing payloads")
	_expect(helper_source.find("CALLBACK_FINISH_OR_OPEN_UNLOCK_SHOWCASE") >= 0, "confirm-flow helper should hand off to finish/showcase callback")


func _helper() -> Object:
	return RuntimePerkChoiceConfirmFlow.new()


func _selection(choice_id: String, choice: Dictionary) -> Dictionary:
	return {
		"accepted": true,
		"choice_id": choice_id,
		"choice": choice.duplicate(true),
	}


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

	var selectable := true
	var apply_choice_result := true
	var current_choices: Array = []
	var selected_index := 0
	var choice_flight_effect: Dictionary = {}
	var _choice_selection: Object = null
	var _active_unlock_flight: Object = null
	var apply_choice_calls := 0
	var active_flight_audio_calls := 0
	var perk_select_audio_calls := 0
	var failure_feedback_calls := 0
	var finish_or_showcase_calls := 0
	var card_rects: Array = [Rect2(Vector2(10.0, 20.0), Vector2(100.0, 60.0))]

	func is_selectable() -> bool:
		return selectable

	func get_card_rects(_view_size: Vector2) -> Array:
		return card_rects.duplicate()

	func apply_choice(_choice: Dictionary, _owner: Object, _registry: Object, _perf_logger: Object = null) -> bool:
		apply_choice_calls += 1
		return apply_choice_result

	func _apply_choice_failure_feedback() -> void:
		failure_feedback_calls += 1

	func _play_active_unlock_flight_audio(_registry: Object) -> void:
		active_flight_audio_calls += 1

	func _play_perk_select_audio(_registry: Object) -> void:
		perk_select_audio_calls += 1

	func _finish_or_open_unlock_showcase(
		_choice_id: String,
		_owner: Object,
		_registry: Object,
		_perf_logger: Object = null,
		_choice: Dictionary = {}
	) -> void:
		finish_or_showcase_calls += 1


class FakeChoiceSelection:
	extends RefCounted

	var payload: Dictionary = {}
	var calls := 0

	func _init(next_payload: Dictionary) -> void:
		payload = next_payload.duplicate(true)

	func build_selected_choice_payload(_choices: Array, _selected_index: int, _selectable: bool) -> Dictionary:
		calls += 1
		return payload.duplicate(true)


class FakeActiveUnlockFlight:
	extends RefCounted

	var effect_to_build: Dictionary = {}
	var landing_payload: Dictionary = {}
	var advance_result := false

	func build_effect_for_selected_card(
		_choice: Dictionary,
		_selected_index: int,
		_card_rects: Array,
		_owner: Object,
		_registry: Object,
		_view_size: Vector2
	) -> Dictionary:
		return effect_to_build.duplicate(true)

	func apply_effect_state_update(runtime_state: Object, effect: Dictionary) -> Dictionary:
		runtime_state.set("choice_flight_effect", effect.duplicate(true))
		return {"accepted": true, "choice_id": str(effect.get("choice_id", ""))}

	func advance(_effect: Dictionary, _delta: float) -> bool:
		return advance_result

	func consume_effect(effect: Dictionary) -> Dictionary:
		var snapshot: Dictionary = effect.duplicate(true)
		effect.clear()
		return snapshot

	func build_landing_payload(_effect: Dictionary) -> Dictionary:
		return landing_payload.duplicate(true)


class FakeOwner:
	extends RefCounted


class FakeRegistry:
	extends RefCounted
