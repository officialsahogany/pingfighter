extends RefCounted

const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")

const MAX_SKILL_SLOTS := 5

var equipped_skills: Array[String] = []


func get_snapshot() -> Dictionary:
	var skill_data := CommonSkillCatalog.get_skill_data()
	return {
		"max_slots": MAX_SKILL_SLOTS,
		"equipped_skills": equipped_skills.duplicate(),
		"skill_costs": {CommonSkillCatalog.SOUL_SUMMON_ART_ID: 0.0},
		"skill_colors": {CommonSkillCatalog.SOUL_SUMMON_ART_ID: CommonSkillCatalog.SOUL_SUMMON_ART_COLOR},
		"runtime_cooldown_multiplier": 1.0,
		"item_cooldown_multiplier": 1.0,
		"cooldown_multiplier": 1.0,
		"cooldown_reduction_eligible": false,
		"cooldown_reduction_skill_ids": [],
		"cooldown_seconds": {CommonSkillCatalog.SOUL_SUMMON_ART_ID: 0.0},
		"skill_data": {CommonSkillCatalog.SOUL_SUMMON_ART_ID: skill_data},
	}


func get_max_skill_slots() -> int:
	return MAX_SKILL_SLOTS


func get_equipped_skills() -> Array:
	return equipped_skills.duplicate()


func get_cooldown_seconds(_skill_name: String) -> float:
	return 0.0


func get_cooldown_reduction_skill_ids() -> Array[String]:
	return []


func set_runtime_cooldown_multiplier(_multiplier: float) -> void:
	pass


func set_item_cooldown_multiplier(_multiplier: float) -> void:
	pass


func get_skill_data(skill_name: String) -> Dictionary:
	if skill_name == CommonSkillCatalog.SOUL_SUMMON_ART_ID:
		return CommonSkillCatalog.get_skill_data()
	return {}


func is_skill_equipped(skill_name: String) -> bool:
	return equipped_skills.has(skill_name)


func is_shared_slot_full() -> bool:
	return equipped_skills.size() >= MAX_SKILL_SLOTS


func get_shared_slot_swap_candidates(skill_name: String) -> Array:
	if skill_name != CommonSkillCatalog.SOUL_SUMMON_ART_ID or equipped_skills.has(skill_name):
		return []
	return equipped_skills.duplicate()


func unlock_and_equip_skill(skill_name: String) -> bool:
	if skill_name != CommonSkillCatalog.SOUL_SUMMON_ART_ID:
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
	equipped_skills.clear()
