extends RefCounted


func can_arm(
	slot_index: int,
	skill_id: String,
	active_skill_ids: Array[String],
	skill_states: Array,
	skill_runtime_host: Object
) -> bool:
	if skill_runtime_host == null or not skill_runtime_host.has_method("skills_share_exclusive_resource"):
		return true
	for other_slot in range(active_skill_ids.size()):
		if other_slot == slot_index:
			continue
		var other_skill_id := str(active_skill_ids[other_slot])
		if other_skill_id == "":
			continue
		if not bool(skill_runtime_host.skills_share_exclusive_resource(skill_id, other_skill_id)):
			continue
		if slot_holds_exclusive_resource(other_slot, other_skill_id, skill_states, skill_runtime_host):
			return false
	return true


func slot_holds_exclusive_resource(
	slot_index: int,
	skill_id: String,
	skill_states: Array,
	skill_runtime_host: Object
) -> bool:
	var state: Object = skill_states[slot_index] if slot_index >= 0 and slot_index < skill_states.size() else null
	if state != null and bool(state.windup_active):
		return true
	if skill_runtime_host == null:
		return false
	if skill_runtime_host.has_method("is_launch_blocked") and bool(skill_runtime_host.is_launch_blocked(skill_id)):
		return true
	if skill_runtime_host.has_method("has_companion_position_override"):
		return bool(skill_runtime_host.has_companion_position_override(skill_id))
	return false
