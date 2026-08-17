extends RefCounted

const CooldownFloorPolicy := preload("res://scripts/characters/cooldown_floor_policy.gd")
const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")

const MAX_SKILL_SLOTS := 5

var runtime_cooldown_multiplier := 1.0
var item_cooldown_multiplier := 1.0
var equipped_skills: Array[String] = []


func get_snapshot() -> Dictionary:
	var cooldown_reduction_skill_ids := get_cooldown_reduction_skill_ids()
	return {
		"max_slots": get_max_skill_slots(),
		"equipped_skills": equipped_skills.duplicate(),
		"skill_costs": CommonSkillCatalog.get_skill_costs(),
		"skill_colors": CommonSkillCatalog.get_skill_colors(),
		"runtime_cooldown_multiplier": runtime_cooldown_multiplier,
		"item_cooldown_multiplier": item_cooldown_multiplier,
		"cooldown_multiplier": get_effective_cooldown_multiplier(),
		"cooldown_reduction_eligible": not cooldown_reduction_skill_ids.is_empty(),
		"cooldown_reduction_skill_ids": cooldown_reduction_skill_ids,
		"cooldown_seconds": _get_equipped_cooldown_seconds_map(),
		"skill_data": CommonSkillCatalog.get_all_skill_data(),
	}


func get_max_skill_slots() -> int:
	return MAX_SKILL_SLOTS


func get_equipped_skills() -> Array:
	return equipped_skills.duplicate()


func get_cooldown_seconds(skill_name: String) -> float:
	return float(CommonSkillCatalog.get_cooldown_seconds_map(get_effective_cooldown_multiplier()).get(skill_name, 0.0))


func get_cooldown_reduction_skill_ids() -> Array[String]:
	var result: Array[String] = []
	for skill_id: String in equipped_skills:
		if get_cooldown_seconds(skill_id) > 0.0:
			result.append(skill_id)
	return result


func _get_equipped_cooldown_seconds_map() -> Dictionary:
	var result: Dictionary = {}
	for skill_id: String in get_cooldown_reduction_skill_ids():
		result[skill_id] = get_cooldown_seconds(skill_id)
	return result


func get_effective_cooldown_multiplier() -> float:
	return CooldownFloorPolicy.floor_final_multiplier(
		max(0.0, runtime_cooldown_multiplier) * max(0.0, item_cooldown_multiplier)
	)


func set_runtime_cooldown_multiplier(multiplier: float) -> void:
	runtime_cooldown_multiplier = max(0.0, multiplier)


func set_item_cooldown_multiplier(multiplier: float) -> void:
	item_cooldown_multiplier = max(0.0, multiplier)



func get_skill_data(skill_name: String) -> Dictionary:
	if CommonSkillCatalog.is_common_skill(skill_name):
		var data := CommonSkillCatalog.get_skill_data(skill_name)
		data["cooldown"] = get_cooldown_seconds(skill_name)
		return data
	return {}


func is_skill_equipped(skill_name: String) -> bool:
	return equipped_skills.has(skill_name)


func is_shared_slot_full() -> bool:
	return equipped_skills.size() >= get_max_skill_slots()


func get_shared_slot_swap_candidates(skill_name: String) -> Array:
	if not CommonSkillCatalog.is_common_skill(skill_name) or equipped_skills.has(skill_name):
		return []
	return equipped_skills.duplicate()


func unlock_and_equip_skill(skill_name: String) -> bool:
	if not CommonSkillCatalog.is_common_skill(skill_name):
		return false
	if equipped_skills.has(skill_name):
		return true
	if is_shared_slot_full():
		return false
	equipped_skills.append(skill_name)
	return true


func unequip_skill(skill_name: String) -> bool:
	if not equipped_skills.has(skill_name):
		return false
	equipped_skills.erase(skill_name)
	return true


func reset_runtime_skills() -> void:
	runtime_cooldown_multiplier = 1.0
	item_cooldown_multiplier = 1.0
	equipped_skills.clear()
