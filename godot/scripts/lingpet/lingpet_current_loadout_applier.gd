extends RefCounted

const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")
const LingpetLoadoutCacheKeyBuilder := preload("res://scripts/lingpet/lingpet_loadout_cache_key_builder.gd")

var _loadout_cache_key_builder: Object = LingpetLoadoutCacheKeyBuilder.new()


func apply(
	pet_id: String,
	owner: Object,
	ensure: bool,
	randomize_missing: bool,
	current_profile: Object,
	loadout_state: Object,
	affinity_state: Object,
	unlock_loadout_reconciler: Object,
	hatch_stat_roll_state: Object,
	affinity_context_coordinator: Object,
	skill_runtime_host: Object,
	active_skill_slot_resolver: Object,
	snapshot_builder: Object
) -> void:
	if pet_id == "":
		loadout_state.set_skip_unlock_reconcile(false)
		if loadout_state.has_applied_runtime_cache():
			current_profile.set_affinity_state(0, LingpetAffinityState.get_empty_reward_counts())
			current_profile.set_hatch_stat_roll(0.0, 0.0)
			current_profile.set_loadout("", "")
			loadout_state.invalidate_runtime_and_snapshot_cache(snapshot_builder)
		return
	var reconciled_unlocks := false
	if not loadout_state.should_skip_unlock_reconcile() and unlock_loadout_reconciler.has_work(affinity_state, pet_id):
		reconciled_unlocks = unlock_loadout_reconciler.reconcile_for_runtime(
			owner,
			pet_id,
			current_profile,
			affinity_state,
			loadout_state,
			skill_runtime_host,
			snapshot_builder
		)
	if not randomize_missing and not reconciled_unlocks and loadout_state.has_applied_runtime_cache():
		return
	var loadout: Dictionary = {}
	if ensure:
		loadout = loadout_state.ensure_pet_loadout(owner, pet_id, null, randomize_missing)
	else:
		loadout = loadout_state.get_loadout(pet_id)
	if randomize_missing:
		hatch_stat_roll_state.ensure_roll(
			pet_id,
			affinity_state,
			current_profile,
			LingpetAffinityState.MOTION_STYLE_PATROL
		)
	affinity_context_coordinator.configure(
		pet_id,
		pet_id,
		current_profile,
		loadout_state,
		affinity_state,
		loadout
	)
	var loadout_key: String = _loadout_cache_key_builder.build_key(
		pet_id,
		loadout,
		affinity_state.get_reward_signature(pet_id)
	)
	if not randomize_missing and loadout_key == loadout_state.get_applied_runtime_cache_key():
		return
	current_profile.set_loadout_from_data(loadout)
	affinity_context_coordinator.sync_current_profile(
		pet_id,
		pet_id,
		current_profile,
		loadout_state,
		affinity_state,
		loadout
	)
	loadout_state.mark_runtime_cache_applied(loadout_key)
	skill_runtime_host.prewarm_many(
		active_skill_slot_resolver.get_active_skill_ids_for_runtime(current_profile, skill_runtime_host)
	)
