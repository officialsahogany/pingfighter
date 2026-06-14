extends RefCounted

const ViperSkillGeometry := preload("res://scripts/characters/viper_skill_geometry.gd")


func trigger_viper_runtime_cooldown(
	skill_name: String,
	now_msec: int,
	skill_config: Object,
	deps: Dictionary,
	cooldown_seconds: float,
	visibility_query: Object
) -> void:
	var skill_state: Object = visibility_query.get_viper_skill_state(deps)
	if skill_state == null:
		return
	if skill_state.has_method("trigger_cooldown"):
		skill_state.trigger_cooldown(skill_name, now_msec, cooldown_seconds)
	elif skill_state.has_method("trigger_configured_cooldown"):
		skill_state.trigger_configured_cooldown(skill_name, now_msec, skill_config)


func get_viper_airborne_height(deps: Dictionary, config: Dictionary, player_pos: Vector2) -> float:
	var jetpack_state: Object = deps.get("viper_jetpack_state", null)
	if jetpack_state != null and jetpack_state.has_method("get_offset_y"):
		return max(0.0, -float(jetpack_state.get_offset_y()))
	return max(0.0, ViperSkillGeometry.player_floor_y(config) - player_pos.y)


func set_viper_jetpack_offset_y(deps: Dictionary, offset_y: float) -> void:
	var jetpack_state: Object = deps.get("viper_jetpack_state", null)
	if jetpack_state != null and jetpack_state.has_method("set_offset_y"):
		jetpack_state.set_offset_y(offset_y, deps)


func force_viper_jetpack_land(deps: Dictionary) -> void:
	var jetpack_state: Object = deps.get("viper_jetpack_state", null)
	if jetpack_state != null and jetpack_state.has_method("force_land"):
		jetpack_state.force_land(deps)


func interrupt_viper_jetpack_thrust(deps: Dictionary) -> void:
	var jetpack_state: Object = deps.get("viper_jetpack_state", null)
	if jetpack_state != null and jetpack_state.has_method("interrupt_thrust"):
		jetpack_state.interrupt_thrust(deps)


func award_skill_gold(deps: Dictionary, gold_award: int, context: Dictionary = {}) -> Dictionary:
	var runtime_perk_state: Object = deps.get("runtime_perk_state", null)
	if runtime_perk_state != null and runtime_perk_state.has_method("award_gold"):
		return {"runtime_perk_gold": int(_call_award_gold(runtime_perk_state, gold_award, context, deps))}
	return {"skill_gold_award": gold_award}


func _call_award_gold(runtime_perk_state: Object, amount: int, context: Dictionary, deps: Dictionary) -> int:
	if _method_accepts_arg_count(runtime_perk_state, "award_gold", 3):
		return int(runtime_perk_state.award_gold(amount, context, deps))
	return int(runtime_perk_state.award_gold(amount))


func _method_accepts_arg_count(target: Object, method_name: String, arg_count: int) -> bool:
	if target == null:
		return false
	for method in target.get_method_list():
		if str(method.get("name", "")) != method_name:
			continue
		var args: Variant = method.get("args", [])
		if args is Array:
			return (args as Array).size() >= arg_count
	return false


func trigger_feedback(deps: Dictionary, amount: float, intensity: float) -> void:
	var feedback: Object = deps.get("feedback", null)
	if feedback == null:
		return
	if feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(amount, intensity)
	elif feedback.has_method("set_screen_shake"):
		feedback.set_screen_shake(amount, intensity)
