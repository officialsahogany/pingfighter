extends RefCounted


func apply(
	value: String,
	previous_pet_id: String,
	default_pet_id: String,
	current_profile: Object,
	guardian_run_context_coordinator: Object,
	loadout_state: Object,
	guardian_run_state: Object,
	hatch_stat_roll_state: Object,
	companion_distance_roll_state: Object,
	guard_feedback_state: Object,
	companion_click_reaction_visual_prewarm_state: Object,
	acquire_cutin_asset_prewarm_state: Object,
	snapshot_builder: Object
) -> String:
	var next_pet_id := str(current_profile.set_pet_id(value, default_pet_id))
	guardian_run_context_coordinator.sync_current_profile(
		next_pet_id,
		next_pet_id,
		current_profile,
		loadout_state,
		guardian_run_state,
		{},
		hatch_stat_roll_state
	)
	if next_pet_id != previous_pet_id:
		loadout_state.set_skip_unlock_reconcile(false)
		companion_distance_roll_state.reset()
		guard_feedback_state.reset_transients()
		loadout_state.invalidate_runtime_and_snapshot_cache(snapshot_builder)
		companion_click_reaction_visual_prewarm_state.reset()
		acquire_cutin_asset_prewarm_state.reset()
	return next_pet_id
