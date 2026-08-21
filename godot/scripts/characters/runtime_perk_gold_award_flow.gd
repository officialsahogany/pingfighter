extends RefCounted

const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")

const RuntimePerkGoldAwards := preload("res://scripts/characters/runtime_perk_gold_awards.gd")


func calculate_rally_gold(ball_vel: Vector2) -> int:
	return RuntimePerkGoldAwards.calculate_rally_gold(ball_vel)


func calculate_rally_gold_from_runtime_state(_runtime_state: Object, ball_vel: Vector2) -> int:
	return calculate_rally_gold(ball_vel)


func award_rally_gold(
	ball_vel: Vector2,
	context: Dictionary,
	deps: Dictionary,
	runtime_state: Object,
	choice_feedback: Object
) -> int:
	var result: Dictionary = RuntimePerkGoldAwards.award_rally_gold(
		ball_vel,
		RuntimePerkRuntimeStateAccess.get_int(runtime_state, "gold_from_perks"),
		context,
		deps,
		_get_item_gold_gain_multiplier(runtime_state),
		RuntimePerkRuntimeStateAccess.get_bool(runtime_state, "viper_ignition_aura_active")
	)
	return apply_gold_award_result(result, runtime_state, choice_feedback, deps)


func award_rally_gold_from_runtime_state(
	runtime_state: Object,
	ball_vel: Vector2,
	context: Dictionary,
	deps: Dictionary
) -> int:
	return award_rally_gold(
		ball_vel,
		context,
		deps,
		runtime_state,
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_choice_feedback")
	)


func award_gold(
	amount: int,
	context: Dictionary,
	deps: Dictionary,
	runtime_state: Object,
	choice_feedback: Object
) -> int:
	var result: Dictionary = RuntimePerkGoldAwards.award_gold(
		amount,
		RuntimePerkRuntimeStateAccess.get_int(runtime_state, "gold_from_perks"),
		context,
		deps,
		_get_item_gold_gain_multiplier(runtime_state),
		RuntimePerkRuntimeStateAccess.get_bool(runtime_state, "viper_ignition_aura_active")
	)
	return apply_gold_award_result(result, runtime_state, choice_feedback, deps)


func award_gold_from_runtime_state(
	runtime_state: Object,
	amount: int,
	context: Dictionary,
	deps: Dictionary
) -> int:
	return award_gold(
		amount,
		context,
		deps,
		runtime_state,
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_choice_feedback")
	)


func store_gold_gain(
	boosted_amount: int,
	feedback_duration: float,
	runtime_state: Object,
	choice_feedback: Object,
	show_feedback: bool = false,
	deps: Dictionary = {}
) -> int:
	var result: Dictionary = RuntimePerkGoldAwards.store_gold_gain(
		boosted_amount,
		RuntimePerkRuntimeStateAccess.get_int(runtime_state, "gold_from_perks"),
		feedback_duration,
		show_feedback
	)
	return apply_gold_award_result(result, runtime_state, choice_feedback, deps)


func store_gold_gain_from_runtime_state(
	runtime_state: Object,
	boosted_amount: int,
	feedback_duration: float,
	show_feedback: bool = false,
	deps: Dictionary = {}
) -> int:
	return store_gold_gain(
		boosted_amount,
		feedback_duration,
		runtime_state,
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_choice_feedback"),
		show_feedback,
		deps
	)


func apply_convert_to_gold_choice(
	choice: Dictionary,
	owner: Object,
	combo_state: Object,
	runtime_state: Object,
	choice_feedback: Object,
	registry: Object = null
) -> int:
	var result: Dictionary = RuntimePerkGoldAwards.award_convert_to_gold_choice(
		choice,
		RuntimePerkRuntimeStateAccess.get_int(runtime_state, "gold_from_perks"),
		owner,
		combo_state,
		_get_item_gold_gain_multiplier(runtime_state),
		RuntimePerkRuntimeStateAccess.get_bool(runtime_state, "viper_ignition_aura_active")
	)
	return apply_gold_award_result(
		result,
		runtime_state,
		choice_feedback,
		{"registry": registry}
	)


func apply_convert_to_gold_choice_from_runtime_state(
	runtime_state: Object,
	choice: Dictionary,
	owner: Object,
	registry: Object
) -> bool:
	apply_convert_to_gold_choice(
		choice,
		owner,
		RuntimePerkRuntimeStateAccess.call_object(runtime_state, "_get_instance", [registry, "smasher_combo_state"]),
		runtime_state,
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_choice_feedback"),
		registry
	)
	_sync_owner_from_runtime_state(runtime_state, owner)
	return true


func apply_gold_award_result(
	result: Dictionary,
	runtime_state: Object,
	choice_feedback: Object,
	deps: Dictionary = {}
) -> int:
	var current_total: int = RuntimePerkRuntimeStateAccess.get_int(runtime_state, "gold_from_perks")
	var tower_route: Dictionary = _route_awarded_gold_to_tower(result, deps)
	if bool(tower_route.get("handled", false)):
		if not bool(tower_route.get("accepted", false)):
			push_error(
				"[TowerAscent] battle gold route rejected: %s" % str(
					tower_route.get("reason", "unknown")
				)
			)
		# Keep the plaza-bound compatibility accumulator unchanged. Several battle
		# callers project this return value onto owner.runtime_perk_gold.
		return current_total
	var state_apply_result: Dictionary = RuntimePerkGoldAwards.apply_award_result_to_runtime_state(
		runtime_state,
		result,
		_build_feedback_apply(choice_feedback)
	)
	if not bool(state_apply_result.get("accepted", false)):
		return current_total
	return int(state_apply_result.get("gold_from_perks", current_total))


func apply_gold_award_result_from_runtime_state(runtime_state: Object, result: Dictionary) -> int:
	return apply_gold_award_result(
		result,
		runtime_state,
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_choice_feedback")
	)


func set_item_gold_gain_multiplier_from_runtime_state(runtime_state: Object, multiplier: float) -> Dictionary:
	var update: Dictionary = RuntimePerkGoldAwards.build_item_gold_gain_multiplier_update(
		_get_item_gold_gain_multiplier(runtime_state),
		multiplier
	)
	return RuntimePerkGoldAwards.apply_item_gold_gain_multiplier_update(runtime_state, update)


func get_item_gold_gain_multiplier_from_runtime_state(runtime_state: Object) -> float:
	return _get_item_gold_gain_multiplier(runtime_state)


func get_viper_ignition_aura_gold_bonus_from_runtime_state(runtime_state: Object) -> int:
	return RuntimePerkGoldAwards.get_viper_ignition_aura_gold_bonus(
		RuntimePerkRuntimeStateAccess.get_bool(runtime_state, "viper_ignition_aura_active")
	)


func _build_feedback_apply(choice_feedback: Object) -> Callable:
	if choice_feedback != null and choice_feedback.has_method("apply_feedback_state_update"):
		return Callable(choice_feedback, "apply_feedback_state_update")
	return Callable()


func _sync_owner_from_runtime_state(runtime_state: Object, owner: Object) -> void:
	if runtime_state == null or not runtime_state.has_method("_sync_owner"):
		return
	RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_sync_owner").call(owner)


func _get_item_gold_gain_multiplier(runtime_state: Object) -> float:
	if runtime_state == null:
		return 1.0
	return float(RuntimePerkRuntimeStateAccess.get_float(runtime_state, "item_gold_gain_multiplier"))


func _route_awarded_gold_to_tower(result: Dictionary, deps: Dictionary) -> Dictionary:
	var awarded_amount := maxi(0, int(result.get("awarded", 0)))
	if awarded_amount <= 0:
		return {}
	var registry: Object = deps.get("registry", null)
	var flow_owner := _get_cached_registry_instance(registry, "tower_ascent_flow_owner")
	if (
		flow_owner == null
		or not flow_owner.has_method("get_run_id")
		or str(flow_owner.call("get_run_id")).strip_edges().is_empty()
	):
		return {}
	if not flow_owner.has_method("collect_gold"):
		return {
			"handled": true,
			"accepted": false,
			"reason": "missing_collect_gold",
		}
	var apply_value: Variant = flow_owner.call("collect_gold", awarded_amount)
	var apply_result: Dictionary = apply_value if apply_value is Dictionary else {}
	return {
		"handled": true,
		"accepted": bool(apply_result.get("accepted", false)),
		"reason": str(apply_result.get("reason", "tower_gold_rejected")),
		"amount": awarded_amount,
		"run_state_result": apply_result,
	}


func _get_cached_registry_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_cached_instance"):
		return null
	var value: Variant = registry.call("get_cached_instance", key)
	if typeof(value) != TYPE_OBJECT or value == null or not is_instance_valid(value):
		return null
	return value as Object
