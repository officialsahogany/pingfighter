extends RefCounted

const LingpetGuardianRunState := preload("res://scripts/lingpet/lingpet_guardian_run_state.gd")
const LingpetCurrentProfile := preload("res://scripts/lingpet/lingpet_current_profile.gd")

const DEFAULT_SKILL_LEVEL := 1


func has_work(guardian_run_state: Object, pet_id: String) -> bool:
	if guardian_run_state == null or pet_id == "":
		return false
	var rewards: Dictionary = guardian_run_state.get_cumulative_rewards(pet_id)
	return (
		bool(rewards.get("active_unlocked", false))
		or bool(rewards.get("passive_unlocked", false))
		or bool(rewards.get("second_active_unlocked", false))
		or bool(rewards.get("second_passive_unlocked", false))
	)


func reconcile_for_runtime(
	owner: Object,
	pet_id: String,
	current_profile: Object,
	guardian_run_state: Object,
	loadout_state: Object,
	skill_runtime_host: Object,
	snapshot_builder: Object = null
) -> bool:
	var normalized_pet_id := _normalize_pet_id(pet_id, current_profile)
	if normalized_pet_id == "":
		return false
	var changed: bool = reconcile(
		owner,
		normalized_pet_id,
		guardian_run_state,
		loadout_state,
		skill_runtime_host
	)
	if changed:
		_invalidate_runtime_caches(loadout_state, snapshot_builder)
	return changed


func reconcile(
	owner: Object,
	pet_id: String,
	guardian_run_state: Object,
	loadout_state: Object,
	skill_runtime_host: Object
) -> bool:
	if pet_id == "" or guardian_run_state == null or loadout_state == null:
		return false
	_seed_unlock_choice_candidates(pet_id, guardian_run_state)
	_auto_resolve_unlock_choices(pet_id, guardian_run_state)
	var resolved: Dictionary = guardian_run_state.get_resolved_unlock_choices(pet_id)
	var active_id := _get_resolved_unlock_id(resolved, "active")
	var passive_id := _get_resolved_unlock_id(resolved, "passive")
	var second_active_id := _get_reconciled_second_active_id(
		active_id,
		_get_resolved_unlock_id(resolved, "second_active"),
		skill_runtime_host
	)
	var second_passive_id := _get_reconciled_second_passive_id(
		passive_id,
		_get_resolved_unlock_id(resolved, "second_passive")
	)
	var current_loadout: Dictionary = loadout_state.get_loadout(pet_id)
	if loadout_matches(
		current_loadout,
		active_id,
		passive_id,
		second_active_id,
		second_passive_id
	):
		return false
	loadout_state.set_pet_loadout(
		owner,
		pet_id,
		active_id,
		passive_id,
		_get_loadout_skill_level(current_loadout, "active_skill_levels", "active_skill_level", active_id),
		_get_loadout_skill_level(current_loadout, "passive_skill_levels", "passive_skill_level", passive_id),
		second_active_id,
		second_passive_id,
		_get_loadout_skill_level(current_loadout, "active_skill_levels", "second_active_skill_level", second_active_id),
		_get_loadout_skill_level(current_loadout, "passive_skill_levels", "second_passive_skill_level", second_passive_id)
	)
	return true


func get_active_unlock_candidate_ids(pet_id: String) -> Array[String]:
	var profile: Object = LingpetCurrentProfile.new()
	profile.set_pet_id(pet_id)
	# S2 노출 차단: 해금 후보는 acquisition_locked(안장)를 제외한 풀에서만 뽑는다.
	var ids := _skill_ids_from_pool(profile.get_acquirable_active_skill_pool())
	return first_raw_candidates(ids, 2)


func first_raw_candidates(ids: Array[String], count: int) -> Array[String]:
	var result: Array[String] = []
	for skill_id in ids:
		if result.size() >= count:
			break
		result.append(skill_id)
	return result


func loadout_matches(
	loadout: Dictionary,
	active_id: String,
	passive_id: String,
	second_active_id: String,
	second_passive_id: String
) -> bool:
	var active_ids: Array = loadout.get("active_skill_ids", []) as Array
	var passive_ids: Array = loadout.get("passive_skill_ids", []) as Array
	var expected_active_size := (1 if active_id != "" else 0) + (1 if second_active_id != "" else 0)
	var expected_passive_size := (1 if passive_id != "" else 0) + (1 if second_passive_id != "" else 0)
	if active_ids.size() != expected_active_size or passive_ids.size() != expected_passive_size:
		return false
	if active_id == "" and str(loadout.get("active_skill_id", "")) != "":
		return false
	if passive_id == "" and str(loadout.get("passive_skill_id", "")) != "":
		return false
	if second_active_id == "" and str(loadout.get("second_active_skill_id", "")) != "":
		return false
	if second_passive_id == "" and str(loadout.get("second_passive_skill_id", "")) != "":
		return false
	if active_id != "" and str(loadout.get("active_skill_id", "")) != active_id:
		return false
	if passive_id != "" and str(loadout.get("passive_skill_id", "")) != passive_id:
		return false
	if second_active_id != "" and str(loadout.get("second_active_skill_id", "")) != second_active_id:
		return false
	if second_passive_id != "" and str(loadout.get("second_passive_skill_id", "")) != second_passive_id:
		return false
	if active_id != "" and (active_ids.is_empty() or str(active_ids[0]) != active_id):
		return false
	if passive_id != "" and (passive_ids.is_empty() or str(passive_ids[0]) != passive_id):
		return false
	if second_active_id != "" and (active_ids.size() < 2 or str(active_ids[1]) != second_active_id):
		return false
	if second_passive_id != "" and (passive_ids.size() < 2 or str(passive_ids[1]) != second_passive_id):
		return false
	return true


func _seed_unlock_choice_candidates(pet_id: String, guardian_run_state: Object) -> void:
	var rewards: Dictionary = guardian_run_state.get_cumulative_rewards(pet_id)
	if bool(rewards.get("active_unlocked", false)):
		_seed_unlock_candidates_for_type(
			pet_id,
			LingpetGuardianRunState.REWARD_TYPE_ACTIVE_UNLOCK,
			get_active_unlock_candidate_ids(pet_id),
			guardian_run_state
		)
	if bool(rewards.get("passive_unlocked", false)):
		_seed_unlock_candidates_for_type(
			pet_id,
			LingpetGuardianRunState.REWARD_TYPE_PASSIVE_UNLOCK,
			_get_first_passive_unlock_candidate_ids(pet_id),
			guardian_run_state
		)
	_auto_resolve_unlock_choices(pet_id, guardian_run_state, ["active", "passive"])
	if bool(rewards.get("second_active_unlocked", false)):
		_seed_unlock_candidates_for_type(
			pet_id,
			LingpetGuardianRunState.REWARD_TYPE_SECOND_ACTIVE_UNLOCK,
			_get_second_active_unlock_candidate_ids(pet_id, guardian_run_state),
			guardian_run_state
		)
	if bool(rewards.get("second_passive_unlocked", false)):
		_seed_unlock_candidates_for_type(
			pet_id,
			LingpetGuardianRunState.REWARD_TYPE_SECOND_PASSIVE_UNLOCK,
			_get_second_passive_unlock_candidate_ids(pet_id, guardian_run_state),
			guardian_run_state
		)


func _seed_unlock_candidates_for_type(
	pet_id: String,
	reward_type: String,
	candidate_ids: Array[String],
	guardian_run_state: Object
) -> void:
	var choice_key := _unlock_choice_key_for_reward_type(reward_type)
	if choice_key == "":
		return
	if guardian_run_state.get_resolved_unlock_choices(pet_id).has(choice_key):
		return
	if candidate_ids.size() == 1:
		guardian_run_state.resolve_single_unlock(pet_id, reward_type, candidate_ids[0])
	elif candidate_ids.size() >= 2:
		guardian_run_state.set_unlock_choice_candidates(pet_id, reward_type, candidate_ids)


func _auto_resolve_unlock_choices(
	pet_id: String,
	guardian_run_state: Object,
	choice_keys: Array[String] = []
) -> void:
	var keys := choice_keys
	if keys.is_empty():
		keys = ["active", "passive", "second_active", "second_passive"]
	var pending: Dictionary = guardian_run_state.get_pending_unlock_choices(pet_id)
	for choice_key in keys:
		if not pending.has(choice_key):
			continue
		var choice: Dictionary = pending.get(choice_key, {}) as Dictionary
		var candidates: Array = choice.get("candidates", []) as Array
		if candidates.is_empty():
			continue
		guardian_run_state.resolve_random_unlock(pet_id, str(choice.get("type", "")))


func _get_first_passive_unlock_candidate_ids(pet_id: String) -> Array[String]:
	var profile: Object = LingpetCurrentProfile.new()
	profile.set_pet_id(pet_id)
	var ids := _skill_ids_from_pool(profile.get_passive_skill_pool())
	return _first_seeded_candidates(ids, _candidate_seed_for_pet(pet_id, 17), 2)


func _get_second_active_unlock_candidate_ids(pet_id: String, guardian_run_state: Object) -> Array[String]:
	var resolved: Dictionary = guardian_run_state.get_resolved_unlock_choices(pet_id)
	var primary_id := _get_resolved_unlock_id(resolved, "active")
	var profile: Object = LingpetCurrentProfile.new()
	profile.set_pet_id(pet_id)
	# S2 노출 차단: 2번째 액티브 후보에서도 acquisition_locked(안장) 제외.
	var ids := _skill_ids_from_pool(profile.get_acquirable_active_skill_pool())
	if primary_id != "":
		ids.erase(primary_id)
	return _first_seeded_candidates(ids, _candidate_seed_for_pet(pet_id, 31), 2)


func _get_second_passive_unlock_candidate_ids(pet_id: String, guardian_run_state: Object) -> Array[String]:
	var resolved: Dictionary = guardian_run_state.get_resolved_unlock_choices(pet_id)
	var primary_id := _get_resolved_unlock_id(resolved, "passive")
	var profile: Object = LingpetCurrentProfile.new()
	profile.set_pet_id(pet_id)
	var ids := _skill_ids_from_pool(profile.get_passive_skill_pool())
	if primary_id != "":
		ids.erase(primary_id)
	return _first_seeded_candidates(ids, _candidate_seed_for_pet(pet_id, 43), 2)


func _skill_ids_from_pool(pool: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	for skill in pool:
		var skill_id := str(skill.get("id", "")).strip_edges()
		if skill_id != "" and not ids.has(skill_id):
			ids.append(skill_id)
	return ids


func _first_seeded_candidates(ids: Array[String], seed_value: int, count: int) -> Array[String]:
	var shuffled: Array[String] = ids.duplicate()
	var state := maxi(1, seed_value % LingpetGuardianRunState.REWARD_DECK_SEED_MOD)
	for i in range(shuffled.size() - 1, 0, -1):
		state = int((int(state) * 1103515245 + 12345) % LingpetGuardianRunState.REWARD_DECK_SEED_MOD)
		var j := state % (i + 1)
		var temporary: String = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = temporary
	var result: Array[String] = []
	for skill_id in shuffled:
		if result.size() >= count:
			break
		result.append(skill_id)
	return result


func _candidate_seed_for_pet(pet_id: String, salt: int) -> int:
	var seed_value := int(hash(pet_id)) ^ int(salt * 1103)
	return maxi(1, abs(seed_value) % LingpetGuardianRunState.REWARD_DECK_SEED_MOD)


func _get_resolved_unlock_id(resolved: Dictionary, choice_key: String) -> String:
	var choice: Dictionary = resolved.get(choice_key, {}) as Dictionary
	return str(choice.get("selected", "")).strip_edges()


func _get_reconciled_second_active_id(
	active_id: String,
	second_active_id: String,
	skill_runtime_host: Object
) -> String:
	if active_id == "" or second_active_id == "":
		return ""
	if active_id == second_active_id:
		return ""
	if skill_runtime_host != null and skill_runtime_host.has_method("would_share_module"):
		if bool(skill_runtime_host.would_share_module(active_id, second_active_id)):
			return ""
	return second_active_id


func _get_reconciled_second_passive_id(passive_id: String, second_passive_id: String) -> String:
	if passive_id == "" or second_passive_id == "":
		return ""
	if passive_id == second_passive_id:
		return ""
	return second_passive_id


func _get_loadout_skill_level(
	loadout: Dictionary,
	levels_key: String,
	fallback_level_key: String,
	skill_id: String
) -> int:
	if skill_id == "":
		return 0
	var levels: Dictionary = loadout.get(levels_key, {}) as Dictionary
	return clampi(
		int(levels.get(skill_id, loadout.get(fallback_level_key, DEFAULT_SKILL_LEVEL))),
		1,
		LingpetGuardianRunState.SKILL_LEVEL_MAX
	)


func _unlock_choice_key_for_reward_type(reward_type: String) -> String:
	match reward_type:
		LingpetGuardianRunState.REWARD_TYPE_ACTIVE_UNLOCK:
			return "active"
		LingpetGuardianRunState.REWARD_TYPE_PASSIVE_UNLOCK:
			return "passive"
		LingpetGuardianRunState.REWARD_TYPE_SECOND_ACTIVE_UNLOCK:
			return "second_active"
		LingpetGuardianRunState.REWARD_TYPE_SECOND_PASSIVE_UNLOCK:
			return "second_passive"
	return ""


func _normalize_pet_id(pet_id: String, current_profile: Object) -> String:
	if current_profile != null and current_profile.has_method("normalize_pet_id"):
		return str(current_profile.normalize_pet_id(pet_id))
	return pet_id.strip_edges().to_lower()


func _invalidate_runtime_caches(loadout_state: Object, snapshot_builder: Object) -> void:
	if loadout_state != null and loadout_state.has_method("invalidate_runtime_cache"):
		loadout_state.invalidate_runtime_cache()
	if snapshot_builder != null and snapshot_builder.has_method("invalidate_sync_cache"):
		snapshot_builder.invalidate_sync_cache()
