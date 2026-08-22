extends RefCounted

const RuntimePerkProgression := preload("res://scripts/characters/runtime_perk_progression.gd")

const CAFFEINE_SKILL_ID := "item_caffeine"
const CAFFEINE_DURATION_BONUS_PER_LEVEL := 0.30


func get_multiplier(registry: Object) -> float:
	var runtime_perk_state: Object = _get_instance(registry, "runtime_perk_state")
	if runtime_perk_state == null:
		return 1.0
	if runtime_perk_state.has_method("get_active_item_duration_multiplier"):
		return max(0.0, float(runtime_perk_state.get_active_item_duration_multiplier()))
	if runtime_perk_state.has_method("get_runtime_skill_bonus"):
		return max(0.0, 1.0 + max(0.0, float(runtime_perk_state.get_runtime_skill_bonus(CAFFEINE_SKILL_ID))))
	if runtime_perk_state.has_method("get_runtime_skill_level"):
		var level: int = max(0, int(runtime_perk_state.get_runtime_skill_level(CAFFEINE_SKILL_ID)))
		return 1.0 + RuntimePerkProgression.get_value(CAFFEINE_SKILL_ID, "duration_bonus", level)
	return 1.0


func scale_frames(base_duration_frames: float, registry: Object) -> float:
	if base_duration_frames <= 0.0:
		return 0.0
	return max(1.0, float(int(base_duration_frames * get_multiplier(registry))))


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
