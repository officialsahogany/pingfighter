extends RefCounted


func is_stage2_speed_defense_context_immune(runtime: Object, context: Dictionary, deps: Dictionary = {}) -> bool:
	if int(context.get("current_stage", 0)) != 2:
		return false
	if (
		bool(context.get("stage2_speed_defense_status_immunity_active", false))
		or bool(context.get("stage2_speed_defense_active", false))
	):
		return true
	return is_stage2_speed_defense_boss_immune(runtime, runtime._get_dict(deps).get("registry", null))


func is_stage2_speed_defense_boss_immune(runtime: Object, registry: Object) -> bool:
	var stage2_skill_state: Object = runtime._get_instance(registry, "stage2_boss_skill_state")
	return (
		stage2_skill_state != null
		and stage2_skill_state.has_method("is_boss_status_immune")
		and bool(stage2_skill_state.is_boss_status_immune())
	)
