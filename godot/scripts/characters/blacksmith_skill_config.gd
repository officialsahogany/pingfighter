extends RefCounted

const MAX_SKILL_SLOTS := 5

var runtime_cooldown_multiplier := 1.0
var item_cooldown_multiplier := 1.0


func get_snapshot() -> Dictionary:
	return {
		"max_slots": get_max_skill_slots(),
		"equipped_skills": [],
		"skill_costs": {},
		"skill_colors": {},
		"runtime_cooldown_multiplier": runtime_cooldown_multiplier,
		"item_cooldown_multiplier": item_cooldown_multiplier,
		"cooldown_multiplier": get_effective_cooldown_multiplier(),
		"cooldown_reduction_eligible": false,
		"cooldown_reduction_skill_ids": [],
		"cooldown_seconds": {},
		"skill_data": {},
	}


func get_max_skill_slots() -> int:
	return MAX_SKILL_SLOTS


func get_equipped_skills() -> Array:
	return []


func get_cooldown_seconds(_skill_name: String) -> float:
	return 0.0


func get_effective_cooldown_multiplier() -> float:
	return max(0.0, runtime_cooldown_multiplier) * max(0.0, item_cooldown_multiplier)


func set_runtime_cooldown_multiplier(multiplier: float) -> void:
	runtime_cooldown_multiplier = max(0.0, multiplier)


func set_item_cooldown_multiplier(multiplier: float) -> void:
	item_cooldown_multiplier = max(0.0, multiplier)


func get_skill_data(_skill_name: String) -> Dictionary:
	return {}


func is_skill_equipped(_skill_name: String) -> bool:
	return false


func reset_runtime_skills() -> void:
	runtime_cooldown_multiplier = 1.0
	item_cooldown_multiplier = 1.0
