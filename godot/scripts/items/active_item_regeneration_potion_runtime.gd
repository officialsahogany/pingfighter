extends RefCounted


func apply(registry: Object) -> Dictionary:
	_reset_skill_cooldowns(_get_instance(registry, "smasher_skill_state"))
	_reset_skill_cooldowns(_get_instance(registry, "viper_skill_state"))

	var drive_input_state: Object = _get_instance(registry, "smasher_drive_input_state")
	if drive_input_state != null and drive_input_state.has_method("reset_cooldowns"):
		drive_input_state.reset_cooldowns()

	var dash_state: Object = _get_instance(registry, "smasher_dash_state")
	var dash_snapshot: Dictionary = {}
	if dash_state != null:
		if dash_state.has_method("refill_tokens"):
			dash_state.refill_tokens()
		if dash_state.has_method("get_snapshot"):
			dash_snapshot = dash_state.get_snapshot()

	var dash_tokens := int(dash_snapshot.get("tokens", 1))
	var orb_hud_state: Object = _get_instance(registry, "orb_hud_state")
	if orb_hud_state != null and orb_hud_state.has_method("reset_dash_tokens"):
		orb_hud_state.reset_dash_tokens(dash_tokens)

	return {
		"dash_tokens": dash_tokens,
		"has_dash_snapshot": not dash_snapshot.is_empty(),
	}


func _reset_skill_cooldowns(skill_state: Object) -> void:
	if skill_state == null:
		return
	if skill_state.has_method("reset_cooldowns"):
		skill_state.reset_cooldowns()
	elif skill_state.has_method("reset"):
		skill_state.reset()


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
