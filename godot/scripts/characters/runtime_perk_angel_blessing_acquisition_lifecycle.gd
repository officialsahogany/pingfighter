extends RefCounted

const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")

const PERK_ID := "angel_blessing"
const TUTORIAL_STAGE := 50
const FIRST_ACQUISITION_REASON := "first_acquisition"
const RESULT_GRANT_SCOPE := "stage_clear_result"
const RESULT_CHOICE_SOURCES := {
	"result_box_mythic_choice": true,
	"result_box_starpoint_choice": true,
	"result_box_mythic_direct": true,
}


func on_accepted_choice(
	runtime_state: Object,
	choice: Dictionary,
	previous_raw_level: int,
	new_raw_level: int,
	choice_context: Dictionary,
	cinematic_started: bool,
	owner: Object,
	registry: Object
) -> Dictionary:
	var perk_id: String = str(choice.get("id", choice.get("perk_id", ""))).strip_edges()
	if perk_id != PERK_ID:
		return _ignored("different_perk")
	if previous_raw_level != 0 or new_raw_level != 1:
		return _ignored("not_first_acquisition")
	if runtime_state == null:
		return _blocked("missing_runtime_state")

	var modal_flow: Object = RuntimePerkRuntimeStateAccess.get_object(
		runtime_state,
		"_angel_blessing_modal_flow"
	)
	if modal_flow == null:
		return _blocked("missing_angel_blessing_modal_flow")

	var source: String = str(
		choice.get("source", choice_context.get("source", ""))
	).strip_edges().to_lower()
	var grant_scope: String = str(
		choice.get("grant_scope", choice_context.get("grant_scope", ""))
	).strip_edges().to_lower()
	if RESULT_CHOICE_SOURCES.has(source) or grant_scope == RESULT_GRANT_SCOPE:
		if not modal_flow.has_method("queue_next_valid_intro_roll"):
			return _blocked("missing_next_intro_queue_api")
		var queue_result: Dictionary = _as_dictionary(
			modal_flow.call(
				"queue_next_valid_intro_roll",
				FIRST_ACQUISITION_REASON,
				cinematic_started
			)
		)
		return _with_route(queue_result, "next_valid_intro", 0, cinematic_started, source, grant_scope)

	if owner == null or registry == null:
		return _blocked("missing_battle_context")
	if owner.get("arena_mode_enabled") == true:
		return _ignored("arena_context")
	var stage: int = _get_current_stage(runtime_state, owner)
	if stage <= 0:
		return _ignored("invalid_stage")
	if stage == TUTORIAL_STAGE:
		return _ignored("tutorial_stage")
	if not modal_flow.has_method("queue_current_stage_roll"):
		return _blocked("missing_current_stage_queue_api")
	var queue_result: Dictionary = _as_dictionary(
		modal_flow.call(
			"queue_current_stage_roll",
			stage,
			FIRST_ACQUISITION_REASON,
			cinematic_started
		)
	)
	return _with_route(
		queue_result,
		"current_stage",
		stage,
		cinematic_started,
		source,
		grant_scope
	)


func on_acquisition_cinematic_finished(runtime_state: Object, perk_id: String) -> Dictionary:
	if perk_id.strip_edges() != PERK_ID:
		return _ignored("different_perk")
	if runtime_state == null:
		return _blocked("missing_runtime_state")
	var modal_flow: Object = RuntimePerkRuntimeStateAccess.get_object(
		runtime_state,
		"_angel_blessing_modal_flow"
	)
	if modal_flow == null:
		return _blocked("missing_angel_blessing_modal_flow")
	if not modal_flow.has_method("mark_acquisition_cinematic_finished"):
		return _blocked("missing_cinematic_finished_api")
	var release_value: Variant = modal_flow.call("mark_acquisition_cinematic_finished", PERK_ID)
	var result: Dictionary = _as_dictionary(release_value)
	if release_value is int or release_value is float:
		result["released"] = int(release_value)
	result["perk_id"] = PERK_ID
	result["cinematic_finished"] = true
	return result


func _get_current_stage(runtime_state: Object, owner: Object) -> int:
	var character_context: Object = RuntimePerkRuntimeStateAccess.get_object(
		runtime_state,
		"_character_context"
	)
	if character_context != null and character_context.has_method("get_current_stage"):
		return max(0, int(character_context.call("get_current_stage", owner)))
	var stage_value: Variant = owner.get("current_stage")
	return max(0, int(stage_value)) if stage_value != null else 0


func _with_route(
	queue_result: Dictionary,
	route: String,
	stage: int,
	waiting_for_cinematic: bool,
	source: String,
	grant_scope: String
) -> Dictionary:
	var result: Dictionary = queue_result.duplicate(true)
	if not result.has("accepted"):
		result["accepted"] = true
	result["perk_id"] = PERK_ID
	result["route"] = route
	result["stage"] = stage
	result["reason"] = FIRST_ACQUISITION_REASON
	result["waiting_for_cinematic"] = waiting_for_cinematic
	result["source"] = source
	result["grant_scope"] = grant_scope
	return result


func _ignored(reason: String) -> Dictionary:
	return {
		"accepted": false,
		"queued": false,
		"ignored": true,
		"reason": reason,
	}


func _blocked(blocked_reason: String) -> Dictionary:
	return {
		"accepted": false,
		"queued": false,
		"blocked_reason": blocked_reason,
	}


func _as_dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}
