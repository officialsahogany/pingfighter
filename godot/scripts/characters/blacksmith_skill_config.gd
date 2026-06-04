extends RefCounted


func get_snapshot() -> Dictionary:
	return {
		"max_slots": 5,
		"equipped_skills": [],
		"skill_costs": {},
		"skill_colors": {},
		"cooldown_seconds": {},
		"skill_data": {},
	}


func get_max_skill_slots() -> int:
	return 5


func get_equipped_skills() -> Array:
	return []


func get_cooldown_seconds(_skill_name: String) -> float:
	return 0.0


func get_skill_data(_skill_name: String) -> Dictionary:
	return {}


func is_skill_equipped(_skill_name: String) -> bool:
	return false


func reset_runtime_skills() -> void:
	pass
