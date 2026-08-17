extends SceneTree

const RuntimePerkStarpointAbsorption := preload("res://scripts/characters/runtime_perk_starpoint_absorption.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_collection_update_payload()
	_verify_collection_state_application()
	_verify_post_collection_choice_plan()
	_verify_runtime_state_collection_path()
	_verify_runtime_state_effect_facade()
	_verify_state_source_contract()

	if _failures.is_empty():
		print("runtime_perk_starpoint_absorption_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_collection_update_payload() -> void:
	var helper := RuntimePerkStarpointAbsorption.new()
	var update: Dictionary = helper.build_collection_update(3, 0, 1, RuntimePerkState.STARPOINT_PER_SKILL_CHOICE)
	_expect(bool(update.get("accepted", false)), "collection update should be accepted")
	_expect(int(update.get("next_pending_skill_choices", 0)) == 4, "collection update should convert points into pending choices")
	_expect(int(update.get("next_starpoint_for_skills", -1)) == 0, "collection update should expose the starpoint remainder")
	_expect(int(update.get("granted_choices", 0)) == 3, "collection update should expose granted choice count")
	_expect(str(update.get("feedback_text", "")) == "무혼 +3", "collection update should own feedback text")
	_expect(is_equal_approx(float(update.get("feedback_timer", 0.0)), RuntimePerkStarpointAbsorption.COLLECTION_FEEDBACK_TIMER), "collection update should own feedback timer")

	var partial: Dictionary = helper.build_collection_update(1, 1, 2, 3)
	_expect(int(partial.get("next_pending_skill_choices", 0)) == 2, "partial collection should preserve pending choices until cost is met")
	_expect(int(partial.get("next_starpoint_for_skills", 0)) == 2, "partial collection should keep starpoint remainder")


func _verify_collection_state_application() -> void:
	var helper := RuntimePerkStarpointAbsorption.new()
	var state := FakeRuntimeState.new()
	state.starpoint_for_skills = 1
	state.pending_skill_choices = 2
	var result: Dictionary = helper.apply_collection_state_update(
		state,
		helper.build_collection_update(2, state.starpoint_for_skills, state.pending_skill_choices, 2)
	)
	_expect(bool(result.get("accepted", false)), "collection state application should accept valid updates")
	_expect(state.starpoint_for_skills == 1, "collection state application should write starpoint remainder")
	_expect(state.pending_skill_choices == 3, "collection state application should write pending choices")
	_expect(int(result.get("previous_pending_skill_choices", 0)) == 2, "collection state application should expose previous pending choices")
	_expect(int(result.get("new_pending_choice_count", 0)) == 1, "collection state application should expose newly granted pending choice count")
	_expect(not bool(helper.apply_collection_state_update(null, result).get("accepted", true)), "collection state application should reject missing state")
	_expect(not bool(helper.apply_collection_state_update(state, {"accepted": false}).get("accepted", true)), "collection state application should reject rejected updates")


func _verify_post_collection_choice_plan() -> void:
	var helper := RuntimePerkStarpointAbsorption.new()
	var open_plan: Dictionary = helper.build_post_collection_choice_plan(1, false, false)
	_expect(bool(open_plan.get("open_next_choice", false)), "post-collection plan should open a choice when pending choices exist and no modal is active")
	_expect(bool(open_plan.get("capture_resume_pre_choice_velocity", false)), "post-collection plan should request pre-choice velocity capture before opening")
	_expect(
		helper.should_clear_pre_choice_after_open(open_plan, false),
		"post-collection plan should clear pre-choice velocity if opening fails"
	)
	_expect(
		not helper.should_clear_pre_choice_after_open(open_plan, true),
		"post-collection plan should preserve pre-choice velocity if opening succeeds"
	)

	var active_plan: Dictionary = helper.build_post_collection_choice_plan(1, true, false)
	_expect(not bool(active_plan.get("open_next_choice", true)), "post-collection plan should not open over an active modal")
	var deferred_plan: Dictionary = helper.build_post_collection_choice_plan(1, false, true)
	_expect(not bool(deferred_plan.get("open_next_choice", true)), "post-collection plan should honor deferred choice-open requests")
	var empty_plan: Dictionary = helper.build_post_collection_choice_plan(0, false, false)
	_expect(not bool(empty_plan.get("open_next_choice", true)), "post-collection plan should ignore missing pending choices")


func _verify_runtime_state_collection_path() -> void:
	var state := RuntimePerkState.new()
	state.collect_star_points(1, "smasher", null, null, null, true)
	_expect(state.starpoint_for_skills == 0, "runtime state collection should apply starpoint remainder through helper")
	_expect(state.pending_skill_choices == 1, "runtime state collection should apply pending choices through helper")
	_expect(str(state.feedback_text) == "무혼 +1", "runtime state collection should keep helper-owned feedback text")
	_expect(is_equal_approx(state.feedback_timer, RuntimePerkStarpointAbsorption.COLLECTION_FEEDBACK_TIMER), "runtime state collection should keep helper-owned feedback timer")


func _verify_runtime_state_effect_facade() -> void:
	var helper := RuntimePerkStarpointAbsorption.new()
	var state := FakeRuntimeState.new()
	state._starpoint_absorption = helper
	state._active_unlock_flight = FakeFlightLayout.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()

	_expect(not helper.is_active_from_runtime_state(state), "runtime-state facade should report inactive absorption before start")
	var start_result: Dictionary = helper.start_from_runtime_state(state, owner)
	_expect(bool(start_result.get("accepted", false)), "runtime-state facade should accept starpoint absorption start")
	_expect(bool(start_result.get("active", false)), "runtime-state facade should report active absorption after start")
	_expect(helper.is_active_from_runtime_state(state), "runtime-state facade should read active absorption from state helper")

	var update_result: Dictionary = helper.update_from_runtime_state(state, 0.10, Vector2(1280.0, 720.0), owner, registry)
	_expect(bool(update_result.get("accepted", false)), "runtime-state facade should accept starpoint absorption update")
	var first_snapshot: Dictionary = helper.get_snapshot()
	var first_target: Vector2 = _get_vector2(first_snapshot.get("target_pos", Vector2.ZERO))
	_expect(first_target != Vector2.ZERO, "runtime-state update should project absorption target through layout helper")

	owner.player_pos = Vector2(180.0, 600.0)
	helper.update_from_runtime_state(state, 0.10, Vector2(1280.0, 720.0), owner, registry)
	var moved_snapshot: Dictionary = helper.get_snapshot()
	var moved_target: Vector2 = _get_vector2(moved_snapshot.get("target_pos", Vector2.ZERO))
	_expect(moved_target.x > first_target.x, "runtime-state update should track moved owner position")

	helper.update_from_runtime_state(state, RuntimePerkStarpointAbsorption.DURATION, Vector2(1280.0, 720.0), owner, registry)
	_expect(not helper.is_active_from_runtime_state(state), "runtime-state facade should report inactive after duration expiry")
	_expect(not helper.is_active_from_runtime_state(null), "runtime-state facade should reject missing state for active query")
	_expect(not bool(helper.start_from_runtime_state(null, owner).get("accepted", true)), "runtime-state facade should reject missing state for start")
	_expect(not bool(helper.update_from_runtime_state(null, 0.10, Vector2(1280.0, 720.0), owner, registry).get("accepted", true)), "runtime-state facade should reject missing state for update")


func _verify_state_source_contract() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_starpoint_absorption.gd")
	var collection_flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_starpoint_collection_flow.gd")
	var collect_body: String = _function_body(state_source, "func collect_star_points(")
	var active_body: String = _function_body(state_source, "func is_starpoint_absorption_active(")
	var start_body: String = _function_body(state_source, "func _start_starpoint_absorption_effect(")
	var update_body: String = _function_body(state_source, "func _update_starpoint_absorption_effect(")
	_expect(state_source.find("RuntimePerkStarpointAbsorption") >= 0, "runtime perk state should preload starpoint absorption helper")
	_expect(state_source.find("RuntimePerkStarpointCollectionFlow") >= 0, "runtime perk state should preload starpoint collection-flow helper")
	_expect(collect_body.find("_starpoint_collection_flow.collect_star_points") >= 0, "collect body should delegate to collection-flow helper")
	_expect(helper_source.find("func is_active_from_runtime_state(") >= 0, "starpoint absorption helper should expose runtime-state active query")
	_expect(helper_source.find("func start_from_runtime_state(") >= 0, "starpoint absorption helper should expose runtime-state start facade")
	_expect(helper_source.find("func update_from_runtime_state(") >= 0, "starpoint absorption helper should expose runtime-state update facade")
	_expect(helper_source.find("build_layout_state_from_runtime_state") >= 0, "starpoint absorption helper should route layout through runtime-state flight helper")
	_expect(active_body.find("_starpoint_absorption.is_active_from_runtime_state") >= 0, "runtime perk state should route starpoint active query through runtime-state facade")
	_expect(start_body.find("_starpoint_absorption.start_from_runtime_state") >= 0, "runtime perk state should route starpoint start through runtime-state facade")
	_expect(update_body.find("_starpoint_absorption.update_from_runtime_state") >= 0, "runtime perk state should route starpoint update through runtime-state facade")
	_expect(active_body.find("_starpoint_absorption.is_active()") < 0, "runtime perk state should not call starpoint helper active query directly")
	_expect(start_body.find("_starpoint_absorption.start(owner)") < 0, "runtime perk state should not start starpoint absorption directly")
	_expect(update_body.find("_starpoint_absorption.update(delta, view_size, owner") < 0, "runtime perk state should not update starpoint absorption directly")
	_expect(update_body.find("_build_flight_layout_state") < 0, "runtime perk state should not build starpoint absorption layout inline")
	_expect(collection_flow_source.find("build_collection_update") >= 0, "collection flow should consume helper-owned collection updates")
	_expect(collection_flow_source.find("apply_collection_state_update") >= 0, "collection flow should delegate collection state application")
	_expect(collection_flow_source.find("build_post_collection_choice_plan") >= 0, "collection flow should consume helper-owned post-collection choice-open plan")
	_expect(collection_flow_source.find("should_clear_pre_choice_after_open") >= 0, "collection flow should delegate failed-open resume cleanup gating")
	_expect(collect_body.find("while starpoint_for_skills >=") < 0, "collect body should not own starpoint-to-choice conversion loop")
	_expect(collect_body.find("starpoint_for_skills = int(collection_update.get") < 0, "collect body should not apply starpoint remainder inline")
	_expect(collect_body.find("pending_skill_choices = int(collection_update.get") < 0, "collect body should not apply pending choices inline")
	_expect(collect_body.find("previous_pending_choices :=") < 0, "collect body should not compute previous pending choices inline")
	_expect(collect_body.find("pending_skill_choices > 0 and not choice_active and not defer_choice_open") < 0, "collect body should not own post-collection choice-open gating inline")
	_expect(collect_body.find("if not choice_active:") < 0, "collect body should not own failed-open resume cleanup gating inline")
	_expect(state_source.find("\"?ㅽ??ъ씤??+%d\"") < 0, "runtime perk state should not own starpoint collection feedback text")


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)


func _get_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class FakeRuntimeState:
	var starpoint_for_skills := 0
	var pending_skill_choices := 0
	var _starpoint_absorption: Object = null
	var _active_unlock_flight: Object = null


class FakeOwner:
	var player_pos := Vector2(100.0, 600.0)
	var player_paddle_width := 155.0


class FakeFlightLayout:
	func build_layout_state_from_runtime_state(_runtime_state: Object, _registry: Object, _view_size: Vector2) -> Dictionary:
		return {
			"game_offset": Vector2(10.0, 20.0),
			"game_size": Vector2(760.0, 750.0),
			"height": 750.0,
		}


class FakeRegistry:
	pass
