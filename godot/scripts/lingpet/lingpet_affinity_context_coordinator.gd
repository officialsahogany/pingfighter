extends RefCounted

const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")
const LingpetCurrentProfile := preload("res://scripts/lingpet/lingpet_current_profile.gd")

var _context_profile: Object = LingpetCurrentProfile.new()
var _reward_seeds_by_pet_id: Dictionary = {}


func reset_for_new_run() -> void:
	_reward_seeds_by_pet_id.clear()


func configure(
	pet_id: String,
	current_pet_id: String,
	current_profile: Object,
	loadout_state: Object,
	affinity_state: Object,
	loadout: Dictionary = {}
) -> Dictionary:
	var normalized_pet_id := _normalize_pet_id(pet_id, current_profile)
	if normalized_pet_id == "" or affinity_state == null:
		return {}
	var context_loadout := loadout
	if context_loadout.is_empty() and loadout_state != null:
		context_loadout = _get_stored_loadout(loadout_state, normalized_pet_id)
	var active_base_level := int(context_loadout.get("active_skill_level", 1))
	var passive_base_level := int(context_loadout.get("passive_skill_level", 1))
	var active_present_id := str(context_loadout.get("active_skill_id", "")).strip_edges()
	var passive_present_id := str(context_loadout.get("passive_skill_id", "")).strip_edges()
	var motion_style := _resolve_motion_style(normalized_pet_id, current_pet_id, current_profile)
	var reward_seed := _get_or_create_reward_seed(normalized_pet_id, affinity_state)
	var ring_core_cap := clampi(
		int(affinity_state.get_run_ring_core_cap()),
		0,
		LingpetAffinityState.MAX_LEVEL
	)
	affinity_state.configure_reward_context(
		normalized_pet_id,
		motion_style,
		active_base_level,
		passive_base_level,
		reward_seed,
		false,
		ring_core_cap,
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
		"reward_seed": reward_seed,
		"ring_core_cap": ring_core_cap,
	}


func sync_current_profile(
	pet_id: String,
	current_pet_id: String,
	current_profile: Object,
	loadout_state: Object,
	affinity_state: Object,
	loadout: Dictionary = {}
) -> void:
	var normalized_pet_id := _normalize_pet_id(pet_id, current_profile)
	if normalized_pet_id == "":
		if current_profile != null:
			current_profile.set_affinity_state(0, LingpetAffinityState.get_empty_reward_counts())
			if current_profile.has_method("set_hatch_stat_roll"):
				current_profile.set_hatch_stat_roll(0.0, 0.0)
		return
	configure(
		normalized_pet_id,
		current_pet_id,
		current_profile,
		loadout_state,
		affinity_state,
		loadout
	)
	current_profile.set_affinity_state(
		affinity_state.get_level(normalized_pet_id),
		affinity_state.get_cumulative_rewards(normalized_pet_id)
	)
	if current_profile.has_method("set_hatch_stat_roll") and affinity_state.has_method("get_hatch_stat_roll"):
		var hatch_roll: Dictionary = affinity_state.get_hatch_stat_roll(normalized_pet_id)
		current_profile.set_hatch_stat_roll(
			float(hatch_roll.get("mobility", 0.0)),
			float(hatch_roll.get("defense", 0.0))
		)


func handle_level_gain(
	pet_id: String,
	_registry: Object,
	current_pet_id: String,
	current_profile: Object,
	loadout_state: Object,
	affinity_state: Object,
	snapshot_builder: Object = null
) -> void:
	sync_current_profile(
		pet_id,
		current_pet_id,
		current_profile,
		loadout_state,
		affinity_state
	)
	if loadout_state != null and loadout_state.has_method("invalidate_runtime_cache"):
		loadout_state.invalidate_runtime_cache()
	if snapshot_builder != null and snapshot_builder.has_method("invalidate_sync_cache"):
		snapshot_builder.invalidate_sync_cache()


func set_reward_seed_for_tests(
	pet_id: String,
	reward_seed: int,
	current_pet_id: String,
	current_profile: Object,
	loadout_state: Object,
	affinity_state: Object
) -> bool:
	var normalized_pet_id := _normalize_pet_id(pet_id, current_profile)
	if normalized_pet_id == "" or affinity_state == null:
		return false
	_reward_seeds_by_pet_id[normalized_pet_id] = _normalize_reward_seed(reward_seed)
	configure(
		normalized_pet_id,
		current_pet_id,
		current_profile,
		loadout_state,
		affinity_state
	)
	affinity_state.set_reward_seed_for_tests(normalized_pet_id, reward_seed)
	if normalized_pet_id == current_pet_id:
		sync_current_profile(
			normalized_pet_id,
			current_pet_id,
			current_profile,
			loadout_state,
			affinity_state
		)
		return true
	return false


func get_reward_seed_for_tests(pet_id: String, current_profile: Object) -> int:
	var normalized_pet_id := _normalize_pet_id(pet_id, current_profile)
	return int(_reward_seeds_by_pet_id.get(normalized_pet_id, 0))


func _resolve_motion_style(pet_id: String, current_pet_id: String, current_profile: Object) -> String:
	if current_profile != null and pet_id == current_pet_id:
		return str(current_profile.get_affinity_motion_style())
	_context_profile.set_pet_id(pet_id)
	return str(_context_profile.get_affinity_motion_style())


func _get_or_create_reward_seed(pet_id: String, affinity_state: Object = null) -> int:
	if not _reward_seeds_by_pet_id.has(pet_id):
		# Adopt a restored pet's existing seed (e.g. after a save/restore round trip that
		# cleared this cache via reset_for_new_run but re-imported the pet's run state) so
		# the reward deck / unlock-choice shuffle stays deterministic. Only mint a fresh
		# random seed when the pet genuinely has none.
		var restored_seed := 0
		if affinity_state != null and affinity_state.has_method("get_reward_seed"):
			restored_seed = int(affinity_state.get_reward_seed(pet_id))
		if restored_seed > 0:
			_reward_seeds_by_pet_id[pet_id] = _normalize_reward_seed(restored_seed)
		else:
			_reward_seeds_by_pet_id[pet_id] = int(randi() % (LingpetAffinityState.REWARD_DECK_SEED_MOD - 1)) + 1
	return int(_reward_seeds_by_pet_id.get(pet_id, 0))


func _get_stored_loadout(loadout_state: Object, pet_id: String) -> Dictionary:
	if loadout_state == null:
		return {}
	if loadout_state.has_method("get_stored_loadout"):
		return loadout_state.get_stored_loadout(pet_id)
	if loadout_state.has_method("get_loadout"):
		return loadout_state.get_loadout(pet_id)
	return {}


func _normalize_reward_seed(reward_seed: int) -> int:
	return maxi(1, reward_seed % LingpetAffinityState.REWARD_DECK_SEED_MOD)


func _normalize_pet_id(pet_id: String, current_profile: Object) -> String:
	if current_profile == null:
		return ""
	return str(current_profile.normalize_pet_id(pet_id))
