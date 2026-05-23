extends RefCounted

var _method_argument_count_cache: Dictionary = {}


func apply_update(
	runtime: Object,
	owner: Object,
	registry: Object,
	delta: float,
	store_item_callback: Callable,
	pickup_callback: Callable,
	apply_item_effect_callback: Callable,
	pending_use_backup_callback: Callable,
	perf_logger: Object = null
) -> Dictionary:
	if owner == null:
		return {}

	var throw_locked_at_update_start: bool = bool(runtime.is_player_control_locked())
	var warp_gate_state: Object = _get_instance(registry, "smasher_warp_gate_state")
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	var detail_perf_logger: Object = _detail_perf_logger(perf_logger, "active_item.runtime.update")

	var sample_start: int = _perf_begin(detail_perf_logger)
	_call_effect_controller_update(
		runtime.effect_controller,
		owner,
		delta,
		warp_gate_state,
		mythic_item_runtime,
		detail_perf_logger
	)
	_perf_end(detail_perf_logger, "physics.callback.active_items.effect_controller", sample_start)
	var time_frozen: bool = bool(runtime.effect_controller.is_time_frozen())
	if not time_frozen:
		sample_start = _perf_begin(detail_perf_logger)
		_call_field_spawn_controller_update(
			runtime.field_spawn_controller,
			owner,
			registry,
			delta,
			store_item_callback,
			pickup_callback,
			perf_logger
		)
		_perf_end(detail_perf_logger, "physics.callback.active_items.field_spawn", sample_start)
		sample_start = _perf_begin(detail_perf_logger)
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
		_perf_end(detail_perf_logger, "physics.callback.active_items.throws", sample_start)
		sample_start = _perf_begin(detail_perf_logger)
		runtime.pending_throw_recovery.clear_backup_if_released(runtime.throw_controller)
		_perf_end(detail_perf_logger, "physics.callback.active_items.pending_throw_recovery", sample_start)

	var input_locked: bool = (
		throw_locked_at_update_start
		or bool(runtime.is_player_control_locked())
		or bool(runtime.is_aipill_active())
		or _is_active_item_use_locked(registry)
	)
	sample_start = _perf_begin(detail_perf_logger)
	var slot_result: Dictionary = _call_slot_controller_update(
		runtime.slot_controller,
		owner,
		registry,
		input_locked,
		apply_item_effect_callback,
		pending_use_backup_callback,
		detail_perf_logger
	)
	_perf_end(detail_perf_logger, "physics.callback.active_items.slots", sample_start)
	if int(slot_result.get("used_slot", -1)) >= 0:
		sample_start = _perf_begin(detail_perf_logger)
		runtime.effect_controller.sync_long_boost_owner_state(owner, warp_gate_state, mythic_item_runtime)
		_perf_end(detail_perf_logger, "physics.callback.active_items.owner_sync", sample_start)
	return slot_result


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _is_active_item_use_locked(registry: Object) -> bool:
	var round_state: Object = _get_instance(registry, "round_flow_state")
	if round_state != null and round_state.has_method("is_waiting_for_serve"):
		if bool(round_state.is_waiting_for_serve()):
			return true
	return (
		_is_module_active(_get_cached_instance(registry, "stage_landing_intro"))
		or _is_module_active(_get_cached_instance(registry, "stage_ball_spawn_intro"))
	)


func _is_module_active(module: Object) -> bool:
	return module != null and module.has_method("is_active") and bool(module.is_active())


func _get_cached_instance(registry: Object, key: String) -> Object:
	if registry != null and registry.has_method("get_cached_instance"):
		return registry.get_cached_instance(key)
	return _get_instance(registry, key)


func _call_effect_controller_update(
	effect_controller: Object,
	owner: Object,
	delta: float,
	warp_gate_state: Object,
	mythic_item_runtime: Object,
	perf_logger: Object
) -> void:
	if effect_controller == null or not effect_controller.has_method("update"):
		return
	if _get_method_argument_count(effect_controller, "update") >= 5:
		effect_controller.update(owner, delta, warp_gate_state, mythic_item_runtime, perf_logger)
	else:
		effect_controller.update(owner, delta, warp_gate_state, mythic_item_runtime)


func _call_field_spawn_controller_update(
	field_spawn_controller: Object,
	owner: Object,
	registry: Object,
	delta: float,
	store_item_callback: Callable,
	pickup_callback: Callable,
	perf_logger: Object
) -> void:
	if field_spawn_controller == null or not field_spawn_controller.has_method("update"):
		return
	if _get_method_argument_count(field_spawn_controller, "update") >= 6:
		field_spawn_controller.update(
			owner,
			registry,
			delta,
			store_item_callback,
			pickup_callback,
			perf_logger
		)
	else:
		field_spawn_controller.update(
			owner,
			registry,
			delta,
			store_item_callback,
			pickup_callback
		)


func _call_slot_controller_update(
	slot_controller: Object,
	owner: Object,
	registry: Object,
	input_locked: bool,
	apply_item_effect_callback: Callable,
	pending_use_backup_callback: Callable,
	perf_logger: Object
) -> Dictionary:
	if slot_controller == null or not slot_controller.has_method("update"):
		return {}
	if _get_method_argument_count(slot_controller, "update") >= 6:
		return slot_controller.update(
			owner,
			registry,
			input_locked,
			apply_item_effect_callback,
			pending_use_backup_callback,
			perf_logger
		)
	return slot_controller.update(
		owner,
		registry,
		input_locked,
		apply_item_effect_callback,
		pending_use_backup_callback
	)


func _get_method_argument_count(target: Object, method_name: String) -> int:
	if target == null:
		return 0
	var cache_key := "%d:%s" % [target.get_instance_id(), method_name]
	if _method_argument_count_cache.has(cache_key):
		return int(_method_argument_count_cache[cache_key])
	for method_info in target.get_method_list():
		if not (method_info is Dictionary):
			continue
		if str(method_info.get("name", "")) != method_name:
			continue
		var args_value: Variant = method_info.get("args", [])
		if args_value is Array:
			var args_count: int = args_value.size()
			_method_argument_count_cache[cache_key] = args_count
			return args_count
	_method_argument_count_cache[cache_key] = 0
	return 0


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


func _detail_perf_logger(perf_logger: Object, label: String) -> Object:
	if perf_logger == null:
		return null
	if perf_logger.has_method("should_sample_detail"):
		return perf_logger if bool(perf_logger.should_sample_detail(label)) else null
	return perf_logger
