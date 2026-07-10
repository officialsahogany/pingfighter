extends RefCounted

const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")

const PERK_ID := "angel_blessing"
const TUTORIAL_STAGE := 50


func on_ball_spawn_intro_finished(
	runtime_state: Object,
	owner: Object,
	registry: Object,
	forced_face: int = 0,
	forced_candidate_order: Array = []
) -> Dictionary:
	if runtime_state == null or owner == null or registry == null:
		return {}
	var runtime_levels: Dictionary = RuntimePerkRuntimeStateAccess.get_dict(
		runtime_state,
		"runtime_skill_levels"
	)
	if int(runtime_levels.get(PERK_ID, 0)) <= 0:
		return {}
	if bool(owner.get("arena_mode_enabled")):
		return {}

	var character_context: Object = RuntimePerkRuntimeStateAccess.get_object(
		runtime_state,
		"_character_context"
	)
	var stage: int = _get_current_stage(owner, character_context)
	if stage <= 0 or stage == TUTORIAL_STAGE:
		return {}
	var character_type: String = _get_character_type(owner, character_context)
	if not runtime_state.has_method("get_angel_blessing_eligible_buff_ids"):
		return {}
	var eligible_value: Variant = runtime_state.get_angel_blessing_eligible_buff_ids(
		character_type,
		registry
	)
	if not (eligible_value is Array):
		return {}
	var eligible_buff_ids: Array = eligible_value
	if eligible_buff_ids.is_empty() or not runtime_state.has_method("roll_angel_blessing_for_stage"):
		return {}

	var result: Dictionary = runtime_state.roll_angel_blessing_for_stage(
		stage,
		eligible_buff_ids,
		forced_face,
		forced_candidate_order
	)
	result["character_type"] = character_type
	result["eligible_buff_ids"] = eligible_buff_ids.duplicate()
	if not bool(result.get("rolled", false)):
		return result

	if runtime_state.has_method("_sync_runtime_perk_owner_effects"):
		runtime_state.call("_sync_runtime_perk_owner_effects", owner, registry)
	if runtime_state.has_method("_refresh_mythic_runtime_perk_consumers"):
		runtime_state.call("_refresh_mythic_runtime_perk_consumers", owner, registry)
	return result


func _get_current_stage(owner: Object, character_context: Object) -> int:
	if character_context != null and character_context.has_method("get_current_stage"):
		return int(character_context.get_current_stage(owner))
	var value: Variant = owner.get("current_stage")
	return max(0, int(value)) if value != null else 0


func _get_character_type(owner: Object, character_context: Object) -> String:
	if character_context != null and character_context.has_method("get_normalized_owner_character_type"):
		return str(character_context.get_normalized_owner_character_type(owner))
	var value: Variant = owner.get("selected_character_type")
	return str(value).strip_edges().to_lower() if value != null else "smasher"
