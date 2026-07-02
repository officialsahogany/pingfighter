extends RefCounted


func get_active_skill_for_slot(profile: Object, slot_index: int) -> Dictionary:
	if profile == null or not profile.has_method("get_active_skill"):
		return {}
	var skill: Variant = profile.get_active_skill(slot_index)
	if skill is Dictionary:
		return skill
	return {}


func get_skill_id_for_slot(profile: Object, slot_index: int) -> String:
	if profile == null or not profile.has_method("get_skill_id"):
		return ""
	if slot_index <= 0:
		return str(profile.get_skill_id(0))
	if not is_second_active_slot_enabled(profile):
		return ""
	return str(profile.get_skill_id(slot_index))


func get_skill_windup_seconds_for_slot(profile: Object, fallback: float, slot_index: int) -> float:
	if profile == null or not profile.has_method("get_skill_windup_seconds"):
		return fallback
	return float(profile.get_skill_windup_seconds(fallback, slot_index))


func get_second_active_skill_for_runtime_surface(profile: Object, skill_runtime_host: Object) -> Dictionary:
	if get_active_slot_count(profile, skill_runtime_host) < 2:
		return {}
	return get_active_skill_for_slot(profile, 1)


func get_second_skill_windup_seconds_for_runtime_surface(
	profile: Object,
	skill_runtime_host: Object,
	fallback: float
) -> float:
	if get_active_slot_count(profile, skill_runtime_host) < 2:
		return 0.0
	return get_skill_windup_seconds_for_slot(profile, fallback, 1)


func get_active_skill_ids_for_runtime(profile: Object, skill_runtime_host: Object) -> Array[String]:
	var skill_ids: Array[String] = []
	for slot_index in range(get_active_slot_count(profile, skill_runtime_host)):
		skill_ids.append(get_skill_id_for_slot(profile, slot_index))
	return skill_ids


func get_active_slot_count(profile: Object, skill_runtime_host: Object) -> int:
	if not is_second_active_slot_enabled(profile):
		return 1
	var first_skill_id := _get_profile_skill_id(profile, 0)
	var second_skill_id := _get_profile_skill_id(profile, 1)
	if _would_share_module(skill_runtime_host, first_skill_id, second_skill_id):
		return 1
	return 2


func is_second_active_slot_enabled(profile: Object) -> bool:
	if profile == null:
		return false
	if not profile.has_method("is_second_active_unlocked") or not bool(profile.is_second_active_unlocked()):
		return false
	if not profile.has_method("get_active_slot_count") or int(profile.get_active_slot_count()) < 2:
		return false
	return _get_profile_skill_id(profile, 1) != ""


func _get_profile_skill_id(profile: Object, slot_index: int) -> String:
	if profile == null or not profile.has_method("get_skill_id"):
		return ""
	return str(profile.get_skill_id(slot_index))


func _would_share_module(skill_runtime_host: Object, first_skill_id: String, second_skill_id: String) -> bool:
	if skill_runtime_host == null or not skill_runtime_host.has_method("would_share_module"):
		return false
	return bool(skill_runtime_host.would_share_module(first_skill_id, second_skill_id))
