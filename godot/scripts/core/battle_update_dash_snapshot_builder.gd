extends RefCounted


func build_snapshot(registry: Object) -> Dictionary:
	var dash_state: Object = _get_instance(registry, "smasher_dash_state")
	if dash_state != null and dash_state.has_method("get_snapshot"):
		var snapshot: Variant = dash_state.get_snapshot()
		if snapshot is Dictionary:
			return snapshot
	return build_default_snapshot()


func build_default_snapshot() -> Dictionary:
	return {
		"tokens": 0,
		"max_tokens": 1,
		"active": false,
		"direction": 0.0,
		"is_half": false,
		"recovering": false,
		"stun_timer": 0.0,
		"recovery_total_frames": 0.0,
		"recovery_progress": 1.0,
		"available_timer": 0.0,
		"charge_timer": 0.0,
		"recharge_frames": 300.0,
		"boost_charging_pending_dash_refund": false,
		"boost_charging_active": false,
		"boost_charging_timer": 0.0,
		"boost_charging_effect_timer": 0.0,
		"boost_charging_effect_duration": 12.0,
		"boost_charging_token_index": -1,
	}


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
