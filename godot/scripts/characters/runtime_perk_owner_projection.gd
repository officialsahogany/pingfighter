extends RefCounted


func build_state(
	runtime_skill_levels: Dictionary,
	effective_runtime_skill_levels: Dictionary,
	pending_skill_choices: int,
	starpoint_for_skills: int,
	gold_from_perks: int,
	choice_active: bool,
	item_perk_level_bonus: int,
	viper_ignition_aura_active: bool
) -> Dictionary:
	return {
		"runtime_skill_levels": runtime_skill_levels.duplicate(true),
		"effective_runtime_skill_levels": effective_runtime_skill_levels.duplicate(true),
		"pending_skill_choices": max(0, pending_skill_choices),
		"starpoint_for_skills": max(0, starpoint_for_skills),
		"gold_from_perks": max(0, gold_from_perks),
		"choice_active": choice_active,
		"item_perk_level_bonus": max(0, item_perk_level_bonus),
		"viper_ignition_aura_active": viper_ignition_aura_active,
	}


func sync_owner(owner: Object, state: Dictionary) -> void:
	if owner == null:
		return
	owner.set("runtime_perk_levels", _get_dict(state.get("runtime_skill_levels", {})).duplicate(true))
	owner.set("runtime_perk_effective_levels", _get_dict(state.get("effective_runtime_skill_levels", {})).duplicate(true))
	owner.set("runtime_perk_pending_choices", int(state.get("pending_skill_choices", 0)))
	owner.set("runtime_perk_starpoints", int(state.get("starpoint_for_skills", 0)))
	owner.set("runtime_perk_gold", int(state.get("gold_from_perks", 0)))
	owner.set("runtime_perk_choice_active", bool(state.get("choice_active", false)))
	owner.set("item_perk_level_bonus", int(state.get("item_perk_level_bonus", 0)))
	owner.set("viper_ignition_aura_active", bool(state.get("viper_ignition_aura_active", false)))


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
