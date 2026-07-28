extends RefCounted

var _pushed_owner_id := 0
var _surface_key: Array = []
var _build_count_for_tests := 0


func reset_build_counter_for_tests() -> void:
	_build_count_for_tests = 0


func get_build_count_for_tests() -> int:
	return _build_count_for_tests


func build_snapshot(
	state: String,
	companion_state: String,
	pet_id: String,
	affinity_state: Object,
	context_coordinator: Object,
	current_profile: Object,
	loadout_state: Object
) -> Dictionary:
	var level := 0
	var points := 0.0
	var next_requirement := 0.0
	var next_label := ""
	if state == companion_state and affinity_state != null:
		if context_coordinator != null:
			context_coordinator.configure(
				pet_id,
				pet_id,
				current_profile,
				loadout_state,
				affinity_state
			)
		level = int(affinity_state.get_level(pet_id))
		points = float(affinity_state.get_points(pet_id))
		next_requirement = float(affinity_state.get_next_requirement(pet_id))
		next_label = _get_next_reward_label(affinity_state, pet_id)
	return {
		"level": level,
		"points": points,
		"next_requirement": next_requirement,
		"next_label": next_label,
	}


func sync_owner_if_changed(
	owner: Object,
	snapshot_builder: Object,
	state: String,
	companion_state: String,
	pet_id: String,
	affinity_state: Object,
	context_coordinator: Object,
	current_profile: Object,
	loadout_state: Object
) -> bool:
	if owner == null or snapshot_builder == null:
		return false
	var surface_key := _build_surface_key(state, companion_state, pet_id, affinity_state, current_profile)
	if not _should_sync(owner, surface_key):
		return false
	var snapshot := build_snapshot(
		state,
		companion_state,
		pet_id,
		affinity_state,
		context_coordinator,
		current_profile,
		loadout_state
	)
	snapshot_builder.set_owner_pair_gated(owner, "lingpet_affinity_level", "ringpet_affinity_level", int(snapshot.get("level", 0)))
	snapshot_builder.set_owner_pair_gated(owner, "lingpet_affinity_points", "ringpet_affinity_points", float(snapshot.get("points", 0.0)))
	snapshot_builder.set_owner_pair_gated(owner, "lingpet_affinity_next_requirement", "ringpet_affinity_next_requirement", float(snapshot.get("next_requirement", 0.0)))
	snapshot_builder.set_owner_pair_gated(owner, "lingpet_affinity_next_label", "ringpet_affinity_next_label", str(snapshot.get("next_label", "")))
	return true


func _build_surface_key(
	state: String,
	companion_state: String,
	pet_id: String,
	affinity_state: Object,
	current_profile: Object
) -> Array:
	if state != companion_state or affinity_state == null:
		return [state, "", 0, 0.0, ""]
	var reward_signature := ""
	if current_profile != null:
		reward_signature = str(current_profile.affinity_reward_signature)
	return [
		state,
		pet_id,
		int(affinity_state.get_level(pet_id)),
		float(affinity_state.get_points(pet_id)),
		reward_signature,
	]


func _should_sync(owner: Object, surface_key: Array) -> bool:
	var owner_id := owner.get_instance_id()
	if owner_id != _pushed_owner_id:
		_pushed_owner_id = owner_id
		_surface_key = []
	if not _surface_key.is_empty() and _surface_key == surface_key:
		return false
	_surface_key = surface_key.duplicate(true)
	_build_count_for_tests += 1
	return true


func _get_next_reward_label(affinity_state: Object, pet_id: String) -> String:
	# Single source: cap-aware + graceful-terminal "다음 보상" label lives on
	# LingpetAffinityState so the TAB panel and the level-up toast cannot drift.
	if affinity_state.has_method("get_next_reward_display_label"):
		return str(affinity_state.get_next_reward_display_label(pet_id))
	var next_reward: Dictionary = affinity_state.get_next_reward(pet_id)
	if next_reward.has("title"):
		return str(next_reward.get("title", "하트 공명"))
	return str(next_reward.get("label", ""))
