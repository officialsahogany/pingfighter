extends RefCounted


func use_slot(runtime: Object, slot_index: int, owner: Object, registry: Object) -> bool:
	if owner == null:
		return false
	var input_locked: bool = (
		bool(runtime.is_player_control_locked())
		or bool(runtime.is_aipill_active())
		or _is_active_item_use_locked(registry)
	)
	return bool(runtime.slot_controller.use_slot(
		slot_index,
		owner,
		registry,
		input_locked,
		Callable(runtime, "_apply_item_effect"),
		Callable(runtime, "_backup_pending_throw_item")
	))


func try_smartphone_auto_recovery(
	runtime: Object,
	owner: Object,
	registry: Object,
	gauge_threshold: float = 120.0
) -> String:
	if _is_active_item_use_locked(registry):
		return ""
	return str(runtime.smartphone_auto_use.try_auto_recovery(
		owner,
		registry,
		gauge_threshold,
		runtime.slot_controller,
		Callable(runtime, "_apply_item_effect"),
		Callable(runtime, "_backup_pending_throw_item")
	))


func try_smartphone_auto_defense(runtime: Object, owner: Object, registry: Object) -> String:
	if _is_active_item_use_locked(registry):
		return ""
	return str(runtime.smartphone_auto_use.try_auto_defense(
		owner,
		registry,
		runtime.slot_controller,
		runtime.effect_controller,
		Callable(runtime, "_apply_item_effect"),
		Callable(runtime, "_backup_pending_throw_item")
	))


func restore_pending_throw_item_on_round_end(runtime: Object, owner: Object, registry: Object) -> bool:
	var restored_or_cancelled: bool = bool(runtime.pending_throw_recovery.restore_on_round_end(
		owner,
		registry,
		runtime.slot_controller,
		runtime.throw_controller
	))
	var detonated_count := 0
	if runtime.throw_controller != null and runtime.throw_controller.has_method("detonate_placed_dynamites_on_round_end"):
		detonated_count = int(runtime.throw_controller.detonate_placed_dynamites_on_round_end(owner, registry))
	return restored_or_cancelled or detonated_count > 0


func activate_dimension_gate(runtime: Object, registry: Object = null) -> bool:
	var activated: bool = bool(runtime.field_spawn_controller.activate_dimension_gate())
	if activated:
		var audio: Object = _get_instance(registry, "game_audio")
		if audio != null and audio.has_method("play_pandora"):
			audio.play_pandora()
		elif audio != null and audio.has_method("play_active_item"):
			audio.play_active_item()
	return activated


func is_dimension_gate_active(runtime: Object) -> bool:
	return bool(runtime.field_spawn_controller.is_dimension_gate_active())


func apply_item_effect(runtime: Object, item_data: Dictionary, owner: Object, registry: Object) -> bool:
	var item_name: String = _get_item_identity(item_data)
	var effect_name: String = str(item_data.get("effect", item_name))
	if item_name == "pandora_box" or effect_name == "pandora_box":
		return activate_dimension_gate(runtime, registry)

	return bool(runtime.effect_router.apply_item_effect(
		item_data,
		owner,
		registry,
		runtime.effect_controller,
		runtime.throw_controller
	))


func backup_pending_throw_item(
	runtime: Object,
	item_data: Dictionary,
	slot_index: int,
	owner: Object,
	registry: Object
) -> void:
	runtime.pending_throw_recovery.backup_pending_throw_item(
		item_data,
		slot_index,
		owner,
		registry,
		runtime.slot_controller,
		runtime.throw_controller
	)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_item_identity(item_data: Dictionary) -> String:
	for key in ["name", "effect", "item_name", "item_id"]:
		var raw_value: Variant = item_data.get(str(key), "")
		if raw_value == null:
			continue
		var value: String = str(raw_value)
		if value != "":
			return value
	return ""


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
