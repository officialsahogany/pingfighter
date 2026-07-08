extends SceneTree

const RuntimePerkStarpointAbsorption := preload("res://scripts/characters/runtime_perk_starpoint_absorption.gd")
const RuntimePerkStarpointCollectionFlow := preload("res://scripts/characters/runtime_perk_starpoint_collection_flow.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_collection_opens_choice_and_runs_post_actions()
	_verify_runtime_state_facade_collects_and_runs_post_actions()
	_verify_deferred_collection_skips_choice_open()
	_verify_failed_choice_open_clears_pre_choice_velocity()
	_verify_source_contract()

	if _failures.is_empty():
		print("runtime_perk_starpoint_collection_flow_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_collection_opens_choice_and_runs_post_actions() -> void:
	var flow := RuntimePerkStarpointCollectionFlow.new()
	var state := FakeRuntimeState.new()
	state.open_should_activate = true
	var modifiers := FakeOfferModifiers.new()
	var feedback := FakeChoiceFeedback.new()
	var result: Dictionary = flow.collect_star_points(
		1,
		"smasher",
		FakeCatalog.new(),
		FakeOwner.new(),
		FakeRegistry.new(),
		false,
		state,
		RuntimePerkStarpointAbsorption.new(),
		modifiers,
		feedback,
		flow.build_state_callbacks(state),
		RuntimePerkState.STARPOINT_PER_SKILL_CHOICE
	)
	_expect(bool(result.get("accepted", false)), "collection flow should accept a valid collection")
	_expect(bool(result.get("choice_active", false)), "collection flow should report active choice after successful open")
	_expect(state.starpoint_for_skills == 0, "collection flow should apply starpoint remainder")
	_expect(state.pending_skill_choices == 1, "collection flow should apply pending choices")
	_expect(modifiers.reset_calls == 1, "collection flow should reset Megingjord batch count once")
	_expect(modifiers.last_new_pending_count == 1, "collection flow should pass newly granted choice count")
	_expect(feedback.calls == 1, "collection flow should apply collection feedback")
	_expect(str(state.feedback_text) == "\uc2a4\ud0c0\ud3ec\uc778\ud2b8 +1", "collection flow should preserve helper-owned feedback text")
	_expect(state.capture_calls == 1, "collection flow should capture resume velocity before opening")
	_expect(state.open_calls == 1, "collection flow should open the next choice")
	_expect(state.clear_pre_choice_calls == 0, "successful choice open should preserve pre-choice velocity")
	_expect(state.sync_calls == 1, "collection flow should sync owner after collection")
	_expect(state.events == ["capture", "open", "sync"], "collection flow should keep post-collection action order")


func _verify_runtime_state_facade_collects_and_runs_post_actions() -> void:
	var flow := RuntimePerkStarpointCollectionFlow.new()
	var state := FakeRuntimeState.new()
	state.open_should_activate = true
	state._starpoint_absorption = RuntimePerkStarpointAbsorption.new()
	var modifiers := FakeOfferModifiers.new()
	var feedback := FakeChoiceFeedback.new()
	state._choice_offer_modifiers = modifiers
	state._choice_feedback = feedback
	var result: Dictionary = flow.collect_star_points_from_runtime_state(
		state,
		1,
		"smasher",
		FakeCatalog.new(),
		FakeOwner.new(),
		FakeRegistry.new(),
		false
	)
	_expect(bool(result.get("accepted", false)), "runtime-state facade should accept valid collection deps")
	_expect(bool(result.get("choice_active", false)), "runtime-state facade should report opened choice")
	_expect(state.pending_skill_choices == 1, "runtime-state facade should apply pending choices")
	_expect(modifiers.reset_calls == 1, "runtime-state facade should reset Megingjord batch count")
	_expect(feedback.calls == 1, "runtime-state facade should apply collection feedback")
	_expect(state.events == ["capture", "open", "sync"], "runtime-state facade should preserve post-collection action order")
	_expect(
		RuntimePerkStarpointCollectionFlow.DEFAULT_STARPOINT_PER_SKILL_CHOICE == RuntimePerkState.STARPOINT_PER_SKILL_CHOICE,
		"runtime-state facade default starpoint conversion should match RuntimePerkState constant"
	)


func _verify_deferred_collection_skips_choice_open() -> void:
	var flow := RuntimePerkStarpointCollectionFlow.new()
	var state := FakeRuntimeState.new()
	flow.collect_star_points(
		1,
		"smasher",
		FakeCatalog.new(),
		FakeOwner.new(),
		FakeRegistry.new(),
		true,
		state,
		RuntimePerkStarpointAbsorption.new(),
		FakeOfferModifiers.new(),
		FakeChoiceFeedback.new(),
		flow.build_state_callbacks(state),
		RuntimePerkState.STARPOINT_PER_SKILL_CHOICE
	)
	_expect(state.pending_skill_choices == 1, "deferred collection should still queue pending choices")
	_expect(not state.choice_active, "deferred collection should not open a modal")
	_expect(state.capture_calls == 0, "deferred collection should not capture resume velocity")
	_expect(state.open_calls == 0, "deferred collection should not open next choice")
	_expect(state.sync_calls == 1, "deferred collection should still sync owner")


func _verify_failed_choice_open_clears_pre_choice_velocity() -> void:
	var flow := RuntimePerkStarpointCollectionFlow.new()
	var state := FakeRuntimeState.new()
	state.open_should_activate = false
	var result: Dictionary = flow.collect_star_points(
		1,
		"smasher",
		FakeCatalog.new(),
		FakeOwner.new(),
		FakeRegistry.new(),
		false,
		state,
		RuntimePerkStarpointAbsorption.new(),
		FakeOfferModifiers.new(),
		FakeChoiceFeedback.new(),
		flow.build_state_callbacks(state),
		RuntimePerkState.STARPOINT_PER_SKILL_CHOICE
	)
	_expect(bool(result.get("accepted", false)), "failed-open collection should still accept collection state")
	_expect(not bool(result.get("choice_active", true)), "failed-open collection should report inactive choice")
	_expect(state.capture_calls == 1, "failed-open collection should capture before attempting open")
	_expect(state.open_calls == 1, "failed-open collection should attempt to open")
	_expect(state.clear_pre_choice_calls == 1, "failed-open collection should clear captured pre-choice velocity")
	_expect(state.events == ["capture", "open", "clear_pre_choice", "sync"], "failed-open cleanup should happen before owner sync")


func _verify_source_contract() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_starpoint_collection_flow.gd")
	var collect_body: String = _function_body(state_source, "func collect_star_points(")
	var facade_body: String = _function_body(flow_source, "func collect_star_points_from_runtime_state(")
	_expect(state_source.find("RuntimePerkStarpointCollectionFlow") >= 0, "runtime perk state should preload starpoint collection-flow helper")
	_expect(collect_body.find("_starpoint_collection_flow.collect_star_points_from_runtime_state") >= 0, "state collect wrapper should delegate runtime-state assembly to collection-flow helper")
	_expect(collect_body.find("_starpoint_absorption") < 0, "state collect wrapper should not pass starpoint absorption helper inline")
	_expect(collect_body.find("_choice_offer_modifiers") < 0, "state collect wrapper should not pass offer modifier helper inline")
	_expect(collect_body.find("_choice_feedback") < 0, "state collect wrapper should not pass feedback helper inline")
	_expect(collect_body.find("build_state_callbacks(self)") < 0, "state collect wrapper should not build collection callbacks inline")
	_expect(collect_body.find("STARPOINT_PER_SKILL_CHOICE") < 0, "state collect wrapper should not pass starpoint conversion constants inline")
	_expect(flow_source.find("func collect_star_points_from_runtime_state(") >= 0, "collection-flow helper should expose runtime-state facade")
	_expect(facade_body.find("_starpoint_absorption") >= 0, "collection-flow facade should own starpoint absorption lookup")
	_expect(facade_body.find("_choice_offer_modifiers") >= 0, "collection-flow facade should own offer modifier lookup")
	_expect(facade_body.find("_choice_feedback") >= 0, "collection-flow facade should own feedback lookup")
	_expect(facade_body.find("build_state_callbacks(runtime_state)") >= 0, "collection-flow facade should own callback-map assembly")
	_expect(facade_body.find("DEFAULT_STARPOINT_PER_SKILL_CHOICE") >= 0, "collection-flow facade should own default conversion constant")
	_expect(collect_body.find("build_collection_update") < 0, "state collect wrapper should not build collection updates directly")
	_expect(collect_body.find("apply_collection_state_update") < 0, "state collect wrapper should not apply collection state directly")
	_expect(collect_body.find("build_post_collection_choice_plan") < 0, "state collect wrapper should not plan post-collection choice opening directly")
	_expect(collect_body.find("should_clear_pre_choice_after_open") < 0, "state collect wrapper should not own failed-open cleanup gating")
	_expect(flow_source.find("build_collection_update") >= 0, "collection-flow helper should consume collection update helper")
	_expect(flow_source.find("apply_collection_state_update") >= 0, "collection-flow helper should apply collection state")
	_expect(flow_source.find("reset_megingjord_extra_pick_count_for_new_choices") >= 0, "collection-flow helper should reset Megingjord batch count")
	_expect(flow_source.find("apply_feedback_state_update") >= 0, "collection-flow helper should apply collection feedback")
	_expect(flow_source.find("build_post_collection_choice_plan") >= 0, "collection-flow helper should consume post-collection choice plan")
	_expect(flow_source.find("should_clear_pre_choice_after_open") >= 0, "collection-flow helper should own failed-open resume cleanup gate")


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

	var starpoint_for_skills := 0
	var pending_skill_choices := 0
	var choice_active := false
	var feedback_text := ""
	var feedback_timer := 0.0
	var open_should_activate := false
	var _starpoint_absorption: Object = null
	var _choice_offer_modifiers: Object = null
	var _choice_feedback: Object = null
	var capture_calls := 0
	var open_calls := 0
	var clear_pre_choice_calls := 0
	var sync_calls := 0
	var events: Array[String] = []

	func _get_instance(registry: Object, key: String) -> Object:
		if registry != null and registry.has_method("get_instance"):
			return registry.get_instance(key)
		return null

	func _capture_resume_pre_choice_velocity(_owner: Object) -> void:
		capture_calls += 1
		events.append("capture")

	func open_next_choice(
		_character_type: String,
		_catalog: Object,
		_exclude_instant: bool = false,
		_owner: Object = null,
		_registry: Object = null,
		_perf_logger: Object = null,
		_choice_context: Dictionary = {}
	) -> void:
		open_calls += 1
		events.append("open")
		choice_active = open_should_activate

	func _clear_resume_pre_choice() -> void:
		clear_pre_choice_calls += 1
		events.append("clear_pre_choice")

	func _sync_owner(_owner: Object) -> void:
		sync_calls += 1
		events.append("sync")


class FakeOfferModifiers:
	extends RefCounted

	var reset_calls := 0
	var last_new_pending_count := 0

	func reset_megingjord_extra_pick_count_for_new_choices(
		_owner: Object,
		_registry: Object,
		_get_instance: Callable,
		new_pending_choice_count: int
	) -> void:
		reset_calls += 1
		last_new_pending_count = new_pending_choice_count


class FakeChoiceFeedback:
	extends RefCounted

	var calls := 0

	func apply_feedback_state_update(runtime_state: Object, update: Dictionary, fallback_timer: float = 0.0) -> Dictionary:
		calls += 1
		runtime_state.feedback_text = str(update.get("feedback_text", ""))
		runtime_state.feedback_timer = float(update.get("feedback_timer", fallback_timer))
		return {"accepted": true}


class FakeCatalog:
	extends RefCounted


class FakeOwner:
	extends RefCounted


class FakeRegistry:
	extends RefCounted

	func get_instance(_key: String) -> Object:
		return null
