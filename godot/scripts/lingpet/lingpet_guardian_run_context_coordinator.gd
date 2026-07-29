extends RefCounted

const LingpetGuardianRunState := preload("res://scripts/lingpet/lingpet_guardian_run_state.gd")
const LingpetCurrentProfile := preload("res://scripts/lingpet/lingpet_current_profile.gd")

var _context_profile: Object = LingpetCurrentProfile.new()


func reset_for_new_run() -> void:
	pass


func configure(
	pet_id: String,
	current_pet_id: String,
	current_profile: Object,
	loadout_state: Object,
	guardian_run_state: Object,
	loadout: Dictionary = {}
) -> Dictionary:
	var normalized_pet_id := _normalize_pet_id(pet_id, current_profile)
	if normalized_pet_id == "" or guardian_run_state == null:
		return {}
	var context_loadout := loadout
	if context_loadout.is_empty() and loadout_state != null:
		context_loadout = _get_stored_loadout(loadout_state, normalized_pet_id)
	var active_base_level := int(context_loadout.get("active_skill_level", 1))
	var passive_base_level := int(context_loadout.get("passive_skill_level", 1))
	var active_present_id := str(context_loadout.get("active_skill_id", "")).strip_edges()
	var passive_present_id := str(context_loadout.get("passive_skill_id", "")).strip_edges()
	var motion_style := _resolve_motion_style(normalized_pet_id, current_pet_id, current_profile)
	guardian_run_state.configure_reward_context(
		normalized_pet_id,
		motion_style,
		active_base_level,
		passive_base_level,
		0,
		false,
		active_present_id,
		passive_present_id
	)
	return {
		"pet_id": normalized_pet_id,
		"motion_style": motion_style,
		"active_base_level": active_base_level,
		"passive_base_level": passive_base_level,
		"active_present_id": active_present_id,
		"passive_present_id": passive_present_id,
	}


func sync_current_profile(
	pet_id: String,
	current_pet_id: String,
	current_profile: Object,
	loadout_state: Object,
	guardian_run_state: Object,
	loadout: Dictionary = {},
	hatch_stat_roll_state: Object = null
) -> void:
	var normalized_pet_id := _normalize_pet_id(pet_id, current_profile)
	if normalized_pet_id == "":
		if current_profile != null:
			current_profile.set_enhancement_rewards(LingpetGuardianRunState.get_empty_reward_counts())
			if current_profile.has_method("set_hatch_stat_roll"):
				current_profile.set_hatch_stat_roll(0.0, 0.0)
		return
	configure(
		normalized_pet_id,
		current_pet_id,
		current_profile,
		loadout_state,
		guardian_run_state,
		loadout
	)
	current_profile.set_enhancement_rewards(
		guardian_run_state.get_cumulative_rewards(normalized_pet_id)
	)
	if (
		hatch_stat_roll_state != null
		and current_profile.has_method("set_hatch_stat_roll")
		and hatch_stat_roll_state.has_method("get_hatch_stat_roll")
	):
		var hatch_roll: Dictionary = hatch_stat_roll_state.get_hatch_stat_roll(normalized_pet_id)
		current_profile.set_hatch_stat_roll(
			float(hatch_roll.get("mobility", 0.0)),
			float(hatch_roll.get("defense", 0.0))
		)


func handle_enhancement_gain(
	pet_id: String,
	_registry: Object,
	current_pet_id: String,
	current_profile: Object,
	loadout_state: Object,
	guardian_run_state: Object,
	snapshot_builder: Object = null
) -> void:
	sync_current_profile(
		pet_id,
		current_pet_id,
		current_profile,
		loadout_state,
		guardian_run_state
	)
	if loadout_state != null and loadout_state.has_method("invalidate_runtime_cache"):
		loadout_state.invalidate_runtime_cache()
	if snapshot_builder != null and snapshot_builder.has_method("invalidate_sync_cache"):
		snapshot_builder.invalidate_sync_cache()


func _resolve_motion_style(pet_id: String, current_pet_id: String, current_profile: Object) -> String:
	if current_profile != null and pet_id == current_pet_id:
		return str(current_profile.get_guardian_motion_style())
	_context_profile.set_pet_id(pet_id)
	return str(_context_profile.get_guardian_motion_style())


func _get_stored_loadout(loadout_state: Object, pet_id: String) -> Dictionary:
	if loadout_state == null:
		return {}
	if loadout_state.has_method("get_stored_loadout"):
		return loadout_state.get_stored_loadout(pet_id)
	if loadout_state.has_method("get_loadout"):
		return loadout_state.get_loadout(pet_id)
	return {}


func _normalize_pet_id(pet_id: String, current_profile: Object) -> String:
	if current_profile == null:
		return ""
	return str(current_profile.normalize_pet_id(pet_id))
