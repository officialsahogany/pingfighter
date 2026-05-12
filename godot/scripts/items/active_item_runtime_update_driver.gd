extends RefCounted


func apply_update(
	runtime: Object,
	owner: Object,
	registry: Object,
	delta: float,
	store_item_callback: Callable,
	pickup_callback: Callable,
	apply_item_effect_callback: Callable,
	pending_use_backup_callback: Callable
) -> Dictionary:
	if owner == null:
		return {}

	var throw_locked_at_update_start: bool = bool(runtime.is_player_control_locked())
	var warp_gate_state: Object = _get_instance(registry, "smasher_warp_gate_state")
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")

	runtime.effect_controller.update(owner, delta, warp_gate_state, mythic_item_runtime)
	var time_frozen: bool = bool(runtime.effect_controller.is_time_frozen())
	if not time_frozen:
		runtime.field_spawn_controller.update(
			owner,
			registry,
			delta,
			store_item_callback,
			pickup_callback
		)
		runtime.throw_controller.update(
			owner,
			registry,
			delta,
			Callable(runtime.field_spawn_controller, "collect_items_near"),
			Callable(runtime.boomerang_return_handler, "handle_return").bind(
				runtime.slot_controller,
				runtime.effect_controller,
				pickup_callback
			)
		)
		runtime.pending_throw_recovery.clear_backup_if_released(runtime.throw_controller)

	var input_locked: bool = (
		throw_locked_at_update_start
		or bool(runtime.is_player_control_locked())
		or bool(runtime.is_aipill_active())
	)
	var slot_result: Dictionary = runtime.slot_controller.update(
		owner,
		registry,
		input_locked,
		apply_item_effect_callback,
		pending_use_backup_callback
	)
	runtime.effect_controller.sync_long_boost_owner_state(owner, warp_gate_state, mythic_item_runtime)
	return slot_result


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
