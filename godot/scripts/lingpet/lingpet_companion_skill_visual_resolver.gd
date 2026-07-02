extends RefCounted


func get_active_position_override_owner(
	active_skill_ids: Array[String],
	skill_runtime_host: Object,
	fallback_pos: Vector2
) -> Dictionary:
	if skill_runtime_host == null:
		return _empty_override_owner(fallback_pos)
	if skill_runtime_host.has_method("get_active_position_override_owner"):
		var modern_owner: Variant = skill_runtime_host.get_active_position_override_owner(active_skill_ids, fallback_pos)
		if modern_owner is Dictionary:
			return modern_owner
	for index in range(active_skill_ids.size()):
		var skill_id := str(active_skill_ids[index])
		if skill_id == "":
			continue
		if not skill_runtime_host.has_method("has_companion_position_override"):
			continue
		if bool(skill_runtime_host.has_companion_position_override(skill_id)):
			return {
				"has": true,
				"slot_index": index,
				"skill_id": skill_id,
				"pos": _get_position_override(skill_runtime_host, skill_id, fallback_pos),
			}
	return _empty_override_owner(fallback_pos)


func has_active_position_override(override_owner: Dictionary) -> bool:
	return bool(override_owner.get("has", false))


func get_companion_body_skill_id(override_owner: Dictionary, current_skill_id: String) -> String:
	var override_skill_id := str(override_owner.get("skill_id", ""))
	return override_skill_id if override_skill_id != "" else current_skill_id


func get_active_visual_slot_index(
	active_skill_ids: Array[String],
	skill_states: Array,
	skill_runtime_host: Object
) -> int:
	for slot in range(active_skill_ids.size()):
		var skill_id := str(active_skill_ids[slot])
		if skill_id == "":
			continue
		var skill_state: Object = skill_states[slot] if slot >= 0 and slot < skill_states.size() else null
		if skill_state != null and bool(skill_state.windup_active):
			return slot
		if _get_cast_pose_progress(skill_runtime_host, skill_id) >= 0.0:
			return slot
	return 0


func _get_position_override(skill_runtime_host: Object, skill_id: String, fallback_pos: Vector2) -> Vector2:
	if skill_runtime_host == null or not skill_runtime_host.has_method("get_companion_position_override"):
		return fallback_pos
	var pos: Variant = skill_runtime_host.get_companion_position_override(skill_id, fallback_pos)
	return pos if pos is Vector2 else fallback_pos


func _get_cast_pose_progress(skill_runtime_host: Object, skill_id: String) -> float:
	if skill_runtime_host == null or not skill_runtime_host.has_method("get_companion_cast_pose_progress"):
		return -1.0
	return float(skill_runtime_host.get_companion_cast_pose_progress(skill_id))


func _empty_override_owner(fallback_pos: Vector2) -> Dictionary:
	return {
		"has": false,
		"slot_index": -1,
		"skill_id": "",
		"pos": fallback_pos,
	}
