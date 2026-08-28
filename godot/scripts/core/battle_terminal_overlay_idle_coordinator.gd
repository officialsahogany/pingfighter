extends RefCounted


func process_idle(
	delta: float,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	perf_logger: Object = null
) -> bool:
	var result_screen := _get_module(module_getter, "stage_clear_result_screen")
	if _is_active(result_screen):
		_update_screen(result_screen, delta, perf_logger, "process.frame.result_screen")
		if _is_runtime_perk_choice_active(module_getter):
			var overlay_frame := _get_module(
				module_getter,
				"battle_scene_overlay_frame_controller"
			)
			if overlay_frame != null and overlay_frame.has_method("process_idle"):
				var perk_start := _perf_begin(perf_logger)
				overlay_frame.call(
					"process_idle",
					delta,
					owner,
					registry,
					module_getter
				)
				_perf_end(
					perf_logger,
					"process.frame.runtime_perk_overlay",
					perk_start
				)
		_queue_redraw(owner)
		return true

	var continue_screen := _get_module(
		module_getter,
		"defeat_chance_gems_continue_screen"
	)
	if _is_active(continue_screen):
		_update_screen(
			continue_screen,
			delta,
			perf_logger,
			"process.frame.defeat_chance_gems_continue"
		)
		_queue_redraw(owner)
		if _blocks_battle_physics(continue_screen):
			return true

	var settlement_screen := _get_module(module_getter, "defeat_settlement_screen")
	if _is_active(settlement_screen):
		_update_screen(
			settlement_screen,
			delta,
			perf_logger,
			"process.frame.defeat_settlement"
		)
		_queue_redraw(owner)
		return true
	return false


func _update_screen(
	screen: Object,
	delta: float,
	perf_logger: Object,
	perf_label: String
) -> void:
	if not screen.has_method("update"):
		return
	var start_usec := _perf_begin(perf_logger)
	screen.call("update", delta)
	_perf_end(perf_logger, perf_label, start_usec)


func _is_active(screen: Object) -> bool:
	return (
		screen != null
		and screen.has_method("is_active")
		and bool(screen.call("is_active"))
	)


func _blocks_battle_physics(screen: Object) -> bool:
	if screen == null:
		return false
	if screen.has_method("blocks_battle_physics"):
		return bool(screen.call("blocks_battle_physics"))
	return _is_active(screen)


func _is_runtime_perk_choice_active(module_getter: Callable) -> bool:
	var modal_gate := _get_module(module_getter, "battle_scene_modal_gate_controller")
	return (
		modal_gate != null
		and modal_gate.has_method("is_runtime_perk_choice_active")
		and bool(modal_gate.call("is_runtime_perk_choice_active", module_getter))
	)


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
	if typeof(value) == TYPE_OBJECT and value != null and is_instance_valid(value):
		return value as Object
	return null


func _queue_redraw(owner: Object) -> void:
	if owner == null:
		return
	if owner.has_method("request_battle_redraw"):
		owner.call("request_battle_redraw")
	elif owner.has_method("queue_redraw"):
		owner.call("queue_redraw")


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.call("begin_sample"))
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.call("finish_sample", label, start_usec)
