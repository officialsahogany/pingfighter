extends SceneTree

const RuntimePerkChoiceCompletion := preload("res://scripts/characters/runtime_perk_choice_completion.gd")
const RuntimePerkChoiceFeedback := preload("res://scripts/characters/runtime_perk_choice_feedback.gd")
const RuntimePerkChoiceFinishFlow := preload("res://scripts/characters/runtime_perk_choice_finish_flow.gd")

var _failures: Array[String] = []
var _open_next_calls := 0
var _resume_calls := 0
var _arm_resume_calls := 0
var _absorption_calls := 0
var _sync_owner_calls := 0
var _last_next_context: Dictionary = {}
var _has_pending_swap := false
var _open_next_marks_choice_active := false


func _init() -> void:
	_verify_fully_closed_finish_runs_close_steps()
	_verify_runtime_state_facade_fully_closed_finish_runs_close_steps()
	_verify_open_next_choice_keeps_modal_side_effects_gated()
	_verify_megingjord_extra_pick_feedback()
	_verify_source_contract()

	if _failures.is_empty():
		print("runtime_perk_choice_finish_flow_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_fully_closed_finish_runs_close_steps() -> void:
	_reset_calls()
	var state := FakeRuntimeState.new()
	state.pending_skill_choices = 1
	state.selected_choice_sequence = 4
	state.current_choice_context = {"source": "field", "nested": {"value": 1}}
	var result: Dictionary = _finish_helper().finish_successful_choice(
		"dash_lightweight",
		FakeOwner.new(),
		FakeRegistry.new(),
		state,
		{"dash_lightweight": 2},
		{"id": "dash_lightweight", "name": "Dash"},
		RuntimePerkChoiceCompletion.new(),
		FakeChoiceOfferModifiers.new(false),
		RuntimePerkChoiceFeedback.new(),
		_callbacks(),
		null
	)
	_expect(bool(result.get("accepted", false)), "finish flow should accept a valid successful choice")
	_expect(state.last_selected_id == "dash_lightweight", "finish flow should apply last selected id")
	_expect(state.selected_choice_sequence == 5, "finish flow should apply selected-choice sequence")
	_expect(state.pending_skill_choices == 0, "finish flow should consume one pending choice")
	_expect(not state.choice_active, "finish flow should close the current modal")
	_expect(state.current_choices.is_empty(), "finish flow should clear current choices")
	_expect(state.current_choice_context.is_empty(), "finish flow should clear context after final close")
	_expect(_open_next_calls == 0, "final close should not open another choice")
	_expect(_resume_calls == 1, "final close should resume skill cooldowns")
	_expect(_arm_resume_calls == 1, "final close should arm resume safety")
	_expect(_absorption_calls == 1, "final close should start starpoint absorption")
	_expect(_sync_owner_calls == 1, "final close should sync owner once")


func _verify_runtime_state_facade_fully_closed_finish_runs_close_steps() -> void:
	var state := FakeRuntimeState.new()
	state.pending_skill_choices = 1
	state.selected_choice_sequence = 4
	state.current_choice_context = {"source": "field", "nested": {"value": 1}}
	state.runtime_skill_levels = {"dash_lightweight": 2}
	state._choice_completion = RuntimePerkChoiceCompletion.new()
	state._choice_offer_modifiers = FakeChoiceOfferModifiers.new(false)
	state._choice_feedback = RuntimePerkChoiceFeedback.new()
	var result: Dictionary = _finish_helper().finish_successful_choice_from_runtime_state(
		state,
		"dash_lightweight",
		FakeOwner.new(),
		FakeRegistry.new(),
		null,
		{"id": "dash_lightweight", "name": "Dash"}
	)
	_expect(bool(result.get("accepted", false)), "runtime-state facade should accept a valid successful choice")
	_expect(state.last_selected_id == "dash_lightweight", "runtime-state facade should apply last selected id")
	_expect(state.selected_choice_sequence == 5, "runtime-state facade should apply selected-choice sequence")
	_expect(state.pending_skill_choices == 0, "runtime-state facade should consume one pending choice")
	_expect(not state.choice_active, "runtime-state facade should close the current modal")
	_expect(state.current_choices.is_empty(), "runtime-state facade should clear current choices")
	_expect(state.current_choice_context.is_empty(), "runtime-state facade should clear context after final close")
	_expect(state.open_next_calls == 0, "runtime-state facade final close should not open another choice")
	_expect(state.resume_calls == 1, "runtime-state facade final close should resume skill cooldowns")
	_expect(state.arm_resume_calls == 1, "runtime-state facade final close should arm resume safety")
	_expect(state.absorption_calls == 1, "runtime-state facade final close should start starpoint absorption")
	_expect(state.sync_owner_calls == 1, "runtime-state facade final close should sync owner once")


func _verify_open_next_choice_keeps_modal_side_effects_gated() -> void:
	_reset_calls()
	_open_next_marks_choice_active = true
	var state := FakeRuntimeState.new()
	_current_open_state = state
	state.pending_skill_choices = 2
	state.current_choice_context = {"source": "academy", "nested": {"value": 1}}
	var result: Dictionary = _finish_helper().finish_successful_choice(
		"common_bulk_up",
		FakeOwner.new(),
		FakeRegistry.new(),
		state,
		{"common_bulk_up": 1},
		{"id": "common_bulk_up", "name": "Bulk"},
		RuntimePerkChoiceCompletion.new(),
		FakeChoiceOfferModifiers.new(false),
		RuntimePerkChoiceFeedback.new(),
		_callbacks(),
		null
	)
	_expect(bool(result.get("accepted", false)), "finish flow should accept open-next choices")
	_expect(bool(result.get("opened_next_choice", false)), "finish flow should report open-next requests")
	_expect(_open_next_calls == 1, "finish flow should open the next pending choice")
	_expect(str(_last_next_context.get("source", "")) == "academy", "open-next should receive a copied choice context")
	_get_dict(_last_next_context.get("nested", {}))["value"] = 9
	_expect(int(_get_dict(state.current_choice_context.get("nested", {})).get("value", 0)) == 1, "open-next context should be deep-copied")
	_expect(_resume_calls == 0, "open-next should not resume skill cooldowns yet")
	_expect(_arm_resume_calls == 0, "open-next should not arm resume safety yet")
	_expect(_absorption_calls == 0, "open-next should not start absorption yet")
	_expect(_sync_owner_calls == 1, "open-next should still sync owner")
	_open_next_marks_choice_active = false
	_current_open_state = null


func _verify_megingjord_extra_pick_feedback() -> void:
	_reset_calls()
	var state := FakeRuntimeState.new()
	state.pending_skill_choices = 1
	state.feedback_timer = 0.2
	var result: Dictionary = _finish_helper().finish_successful_choice(
		"smash_power",
		FakeOwner.new(),
		FakeRegistry.new(),
		state,
		{"smash_power": 1},
		{"id": "smash_power", "name": "Smash"},
		RuntimePerkChoiceCompletion.new(),
		FakeChoiceOfferModifiers.new(true),
		RuntimePerkChoiceFeedback.new(),
		_callbacks(),
		null
	)
	_expect(bool(result.get("accepted", false)), "finish flow should accept Megingjord extra-pick finishes")
	_expect(state.pending_skill_choices == 1, "Megingjord extra pick should restore one pending choice after consume")
	_expect(state.feedback_text == RuntimePerkChoiceFeedback.MEGINGJORD_EXTRA_PICK_TEXT, "finish flow should apply Megingjord feedback text")
	_expect(is_equal_approx(state.feedback_timer, RuntimePerkChoiceFeedback.MEGINGJORD_EXTRA_PICK_TIMER), "finish flow should apply Megingjord feedback timer")


func _verify_source_contract() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_finish_flow.gd")
	var finish_body: String = _function_body(state_source, "func _finish_successful_choice(")
	var facade_body: String = _function_body(helper_source, "func finish_successful_choice_from_runtime_state(")
	_expect(state_source.find("RuntimePerkChoiceFinishFlow") >= 0, "state should preload finish-flow helper")
	_expect(finish_body.find("_choice_finish_flow.finish_successful_choice_from_runtime_state") >= 0, "state finish-success wrapper should delegate runtime-state assembly to finish-flow helper")
	_expect(finish_body.find("runtime_skill_levels") < 0, "state finish-success wrapper should not pass runtime levels inline")
	_expect(finish_body.find("_choice_completion") < 0, "state finish-success wrapper should not pass completion helper inline")
	_expect(finish_body.find("_choice_offer_modifiers") < 0, "state finish-success wrapper should not pass offer modifier helper inline")
	_expect(finish_body.find("_choice_feedback") < 0, "state finish-success wrapper should not pass feedback helper inline")
	_expect(finish_body.find("build_state_callbacks(self)") < 0, "state finish-success wrapper should not build callback map inline")
	_expect(helper_source.find("func finish_successful_choice_from_runtime_state(") >= 0, "finish-flow helper should expose runtime-state facade")
	_expect(facade_body.find("runtime_skill_levels") >= 0, "finish-flow facade should own runtime-level lookup")
	_expect(facade_body.find("_choice_completion") >= 0, "finish-flow facade should own completion helper lookup")
	_expect(facade_body.find("_choice_offer_modifiers") >= 0, "finish-flow facade should own offer modifier lookup")
	_expect(facade_body.find("_choice_feedback") >= 0, "finish-flow facade should own feedback helper lookup")
	_expect(facade_body.find("build_state_callbacks(runtime_state)") >= 0, "finish-flow facade should own callback-map assembly")
	_expect(finish_body.find("build_success_state_update_for_choice") < 0, "state finish-success wrapper should not build success payloads directly")
	_expect(finish_body.find("apply_success_state_update") < 0, "state finish-success wrapper should not apply success state directly")
	_expect(finish_body.find("build_post_state_plan") < 0, "state finish-success wrapper should not build post-state plans directly")
	_expect(finish_body.find("build_modal_close_steps") < 0, "state finish-success wrapper should not iterate close steps directly")
	_expect(finish_body.find("_choice_offer_modifiers.try_megingjord_extra_pick") < 0, "state finish-success wrapper should not own Megingjord finish sequencing")
	_expect(helper_source.find("build_success_state_update_for_choice") >= 0, "finish-flow helper should consume completion success payloads")
	_expect(helper_source.find("build_post_state_plan") >= 0, "finish-flow helper should consume post-state plans")
	_expect(helper_source.find("build_modal_close_steps") >= 0, "finish-flow helper should consume modal close steps")
	_expect(helper_source.find("try_megingjord_extra_pick") >= 0, "finish-flow helper should own Megingjord finish sequencing")


func _finish_helper() -> Object:
	return RuntimePerkChoiceFinishFlow.new()


func _callbacks() -> Dictionary:
	return {
		RuntimePerkChoiceFinishFlow.CALLBACK_GET_CHARACTER_TYPE: Callable(self, "_get_character_type"),
		RuntimePerkChoiceFinishFlow.CALLBACK_GET_CATALOG: Callable(self, "_get_catalog"),
		RuntimePerkChoiceFinishFlow.CALLBACK_GET_INSTANCE: Callable(self, "_get_instance"),
		RuntimePerkChoiceFinishFlow.CALLBACK_HAS_PENDING_UNLOCK_SWAP: Callable(self, "_has_pending_unlock_swap"),
		RuntimePerkChoiceFinishFlow.CALLBACK_OPEN_NEXT_CHOICE: Callable(self, "_open_next_choice"),
		RuntimePerkChoiceFinishFlow.CALLBACK_RESUME_SKILL_COOLDOWNS: Callable(self, "_resume_skill_cooldowns"),
		RuntimePerkChoiceFinishFlow.CALLBACK_TRY_ARM_RESUME_SAFETY: Callable(self, "_try_arm_resume_safety"),
		RuntimePerkChoiceFinishFlow.CALLBACK_START_STARPOINT_ABSORPTION: Callable(self, "_start_starpoint_absorption"),
		RuntimePerkChoiceFinishFlow.CALLBACK_SYNC_OWNER: Callable(self, "_sync_owner"),
	}


func _reset_calls() -> void:
	_open_next_calls = 0
	_resume_calls = 0
	_arm_resume_calls = 0
	_absorption_calls = 0
	_sync_owner_calls = 0
	_last_next_context.clear()
	_has_pending_swap = false
	_open_next_marks_choice_active = false


func _get_character_type(_owner: Object) -> String:
	return "smasher"


func _get_catalog(_registry: Object) -> Object:
	return FakeCatalog.new()


func _get_instance(_registry: Object, _key: String) -> Object:
	return null


func _has_pending_unlock_swap() -> bool:
	return _has_pending_swap


func _open_next_choice(
	_character_type: String,
	_catalog: Object,
	_exclude_instant: bool,
	_owner: Object,
	_registry: Object,
	_perf_logger: Object,
	next_choice_context: Dictionary
) -> bool:
	_open_next_calls += 1
	_last_next_context = next_choice_context.duplicate(true)
	if _open_next_marks_choice_active:
		_current_open_state.choice_active = true
	return true


var _current_open_state: Object = null


func _resume_skill_cooldowns() -> void:
	_resume_calls += 1


func _try_arm_resume_safety(_owner: Object, _registry: Object) -> void:
	_arm_resume_calls += 1


func _start_starpoint_absorption(_owner: Object) -> void:
	_absorption_calls += 1


func _sync_owner(_owner: Object) -> void:
	_sync_owner_calls += 1


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class FakeRuntimeState:
	extends RefCounted

	var last_selected_id := ""
	var last_selected_choice: Dictionary = {}
	var selected_choice_sequence := 0
	var pending_skill_choices := 0
	var choice_active := true
	var current_choices: Array = [{"id": "old"}]
	var animation_time := 1.0
	var feedback_text := ""
	var feedback_timer := 0.0
	var current_choice_context: Dictionary = {}
	var runtime_skill_levels: Dictionary = {}
	var _choice_completion: Object = null
	var _choice_offer_modifiers: Object = null
	var _choice_feedback: Object = null
	var open_next_calls := 0
	var resume_calls := 0
	var arm_resume_calls := 0
	var absorption_calls := 0
	var sync_owner_calls := 0
	var last_next_context: Dictionary = {}
	var has_pending_swap := false
	var open_next_marks_choice_active := false

	func _get_character_type(_owner: Object) -> String:
		return "smasher"

	func _get_catalog(_registry: Object) -> Object:
		return FakeCatalog.new()

	func _get_instance(_registry: Object, _key: String) -> Object:
		return null

	func has_pending_unlock_swap() -> bool:
		return has_pending_swap

	func open_next_choice(
		_character_type: String,
		_catalog: Object,
		_exclude_instant: bool,
		_owner: Object,
		_registry: Object,
		_perf_logger: Object,
		next_choice_context: Dictionary
	) -> bool:
		open_next_calls += 1
		last_next_context = next_choice_context.duplicate(true)
		if open_next_marks_choice_active:
			choice_active = true
		return true

	func _resume_skill_cooldowns_for_choice() -> void:
		resume_calls += 1

	func _try_arm_resume_safety(_owner: Object, _registry: Object) -> void:
		arm_resume_calls += 1

	func _start_starpoint_absorption_effect(_owner: Object) -> void:
		absorption_calls += 1

	func _sync_owner(_owner: Object) -> void:
		sync_owner_calls += 1


class FakeChoiceOfferModifiers:
	extends RefCounted

	var should_extra_pick := false

	func _init(extra_pick: bool) -> void:
		should_extra_pick = extra_pick

	func try_megingjord_extra_pick(_choice_id: String, _owner: Object, _registry: Object, _get_instance: Callable) -> bool:
		return should_extra_pick


class FakeOwner:
	extends RefCounted


class FakeRegistry:
	extends RefCounted


class FakeCatalog:
	extends RefCounted
