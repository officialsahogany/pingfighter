extends RefCounted

const TowerAscentFeatureFlags := preload("res://scripts/tower_ascent/tower_ascent_feature_flags.gd")


func should_block(
	delta: float,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	callbacks: Dictionary,
	modal_pause_state: Object,
	perf_logger: Object = null
) -> bool:
	var sample_start := _perf_begin(perf_logger)
	if _call_readiness_bool(module_getter, "is_logo_intro_active"):
		_perf_end(perf_logger, "physics.frame.gate.logo_intro", sample_start)
		return true
	_perf_end(perf_logger, "physics.frame.gate.logo_intro", sample_start)

	sample_start = _perf_begin(perf_logger)
	if not _call_callback_bool(callbacks, "is_battle_initialized"):
		_perf_end(perf_logger, "physics.frame.gate.battle_initialized", sample_start)
		return true
	_perf_end(perf_logger, "physics.frame.gate.battle_initialized", sample_start)

	sample_start = _perf_begin(perf_logger)
	if not _call_readiness_bool(module_getter, "is_boot_warmup_finished", true):
		_perf_end(perf_logger, "physics.frame.gate.boot_warmup", sample_start)
		return true
	_perf_end(perf_logger, "physics.frame.gate.boot_warmup", sample_start)

	# The start-card deadline is authoritative gameplay state. Advance it exactly
	# once per fixed physics tick, before the stage-landing-started gate that is
	# intentionally still closed while this pre-intro modal is visible.
	sample_start = _perf_begin(perf_logger)
	if TowerAscentFeatureFlags.is_vertical_slice_enabled():
		var start_card: Object = _get_module(module_getter, "tower_start_card_state")
		if start_card != null and start_card.has_method("is_active") and bool(start_card.is_active()):
			if start_card.has_method("update_physics"):
				start_card.update_physics(delta)
			if start_card.has_method("is_active") and bool(start_card.is_active()):
				_perf_end(perf_logger, "physics.frame.gate.tower_start_card", sample_start)
				return true
	_perf_end(perf_logger, "physics.frame.gate.tower_start_card", sample_start)

	sample_start = _perf_begin(perf_logger)
	if not _call_callback_bool(callbacks, "is_stage_landing_intro_started"):
		_perf_end(perf_logger, "physics.frame.gate.stage_landing_started", sample_start)
		return true
	_perf_end(perf_logger, "physics.frame.gate.stage_landing_started", sample_start)

	sample_start = _perf_begin(perf_logger)
	if _call_readiness_bool(module_getter, "is_stage_landing_intro_active"):
		_perf_end(perf_logger, "physics.frame.gate.stage_landing_intro", sample_start)
		return true
	_perf_end(perf_logger, "physics.frame.gate.stage_landing_intro", sample_start)

	sample_start = _perf_begin(perf_logger)
	if _call_readiness_bool(module_getter, "is_ball_spawn_intro_active"):
		_perf_end(perf_logger, "physics.frame.gate.ball_spawn_intro", sample_start)
		return true
	_perf_end(perf_logger, "physics.frame.gate.ball_spawn_intro", sample_start)

	sample_start = _perf_begin(perf_logger)
	if _is_stage_transition_loading_active(module_getter):
		_perf_end(
			perf_logger,
			"physics.frame.gate.stage_transition_loading",
			sample_start
		)
		return true
	_perf_end(
		perf_logger,
		"physics.frame.gate.stage_transition_loading",
		sample_start
	)

	sample_start = _perf_begin(perf_logger)
	if _is_module_active(module_getter, "stage_clear_result_screen"):
		_perf_end(perf_logger, "physics.frame.gate.stage_clear_result", sample_start)
		return true
	_perf_end(perf_logger, "physics.frame.gate.stage_clear_result", sample_start)

	sample_start = _perf_begin(perf_logger)
	if _does_continue_block_battle(module_getter):
		_perf_end(
			perf_logger,
			"physics.frame.gate.defeat_chance_gems_continue",
			sample_start
		)
		return true
	_perf_end(
		perf_logger,
		"physics.frame.gate.defeat_chance_gems_continue",
		sample_start
	)

	sample_start = _perf_begin(perf_logger)
	if _is_module_active(module_getter, "defeat_settlement_screen"):
		_perf_end(perf_logger, "physics.frame.gate.defeat_settlement", sample_start)
		return true
	_perf_end(perf_logger, "physics.frame.gate.defeat_settlement", sample_start)

	sample_start = _perf_begin(perf_logger)
	if _update_tower_ascent_flow(delta, owner, registry, module_getter):
		if modal_pause_state != null and modal_pause_state.has_method("enter_modal_block"):
			modal_pause_state.call("enter_modal_block", owner, registry, module_getter)
		_perf_end(perf_logger, "physics.frame.gate.tower_ascent_flow", sample_start)
		return true
	_perf_end(perf_logger, "physics.frame.gate.tower_ascent_flow", sample_start)

	sample_start = _perf_begin(perf_logger)
	if process_grip_selection(delta, owner, registry, module_getter):
		_perf_end(perf_logger, "physics.frame.gate.grip_style_selection", sample_start)
		return true
	_perf_end(perf_logger, "physics.frame.gate.grip_style_selection", sample_start)

	sample_start = _perf_begin(perf_logger)
	if _should_block_for_modal(module_getter, perf_logger):
		if modal_pause_state != null and modal_pause_state.has_method("enter_modal_block"):
			modal_pause_state.call("enter_modal_block", owner, registry, module_getter)
		# (H 이식) 신화 획득 유지보수 틱 — 공통 모달 차단 return 직전 앵커.
		# 시네마틱은 차단 모달이지만 유일한 생산 클록이 이 게이트가 건너뛰는
		# mythic 업데이트 경로다. 차단 프레임에서 정확히 1회만 펌프하고, 상위
		# 우선 퍽/엔젤 모달은 배타 소유를 유지한다. 커밋본 정본은
		# battle_scene_frame_controller의 동일 훅(ce480e254 이식).
		_update_blocked_mythic_acquisition(delta, owner, registry, module_getter)
		_perf_end(perf_logger, "physics.frame.gate.modal_block", sample_start)
		return true
	_perf_end(perf_logger, "physics.frame.gate.modal_block", sample_start)
	if modal_pause_state != null and modal_pause_state.has_method("leave_modal_block"):
		modal_pause_state.call("leave_modal_block", owner, registry, module_getter)
	return false


func _update_tower_ascent_flow(
	delta: float,
	owner: Object,
	registry: Object,
	module_getter: Callable
) -> bool:
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled():
		return false
	var flow_owner := _get_cached_module(registry, module_getter, "tower_ascent_flow_owner")
	if (
		flow_owner == null
		or not flow_owner.has_method("is_active")
		or not bool(flow_owner.call("is_active"))
	):
		return false
	if flow_owner.has_method("update_selective"):
		flow_owner.call("update_selective", delta, owner)
	_queue_redraw(owner)
	return true


func process_grip_selection(
	_delta: float,
	owner: Object,
	registry: Object,
	module_getter: Callable
) -> bool:
	var grip_overlay := _get_module(module_getter, "grip_style_selection_overlay")
	if grip_overlay == null or not grip_overlay.has_method("update"):
		return false
	if bool(grip_overlay.call("update", 0.0, owner, registry, module_getter)):
		_queue_redraw(owner)
	return (
		grip_overlay.has_method("is_active")
		and bool(grip_overlay.call("is_active"))
	)


func _call_readiness_bool(
	module_getter: Callable,
	method_name: String,
	fallback: bool = false
) -> bool:
	var readiness := _get_module(module_getter, "battle_scene_readiness_controller")
	if readiness == null or not readiness.has_method(method_name):
		return fallback
	return bool(readiness.call(method_name, module_getter))


func _call_callback_bool(callbacks: Dictionary, key: String) -> bool:
	var callback: Callable = callbacks.get(key, Callable())
	return callback.is_valid() and bool(callback.call())


func _is_stage_transition_loading_active(module_getter: Callable) -> bool:
	var driver := _get_module(module_getter, "battle_scene_match_event_driver")
	return (
		driver != null
		and driver.has_method("is_stage_transition_loading_active")
		and bool(driver.call("is_stage_transition_loading_active"))
	)


func _is_module_active(module_getter: Callable, key: String) -> bool:
	var module := _get_module(module_getter, key)
	return (
		module != null
		and module.has_method("is_active")
		and bool(module.call("is_active"))
	)


func _does_continue_block_battle(module_getter: Callable) -> bool:
	var screen := _get_module(module_getter, "defeat_chance_gems_continue_screen")
	if screen == null:
		return false
	if screen.has_method("blocks_battle_physics"):
		return bool(screen.call("blocks_battle_physics"))
	return screen.has_method("is_active") and bool(screen.call("is_active"))


func _should_block_for_modal(
	module_getter: Callable,
	perf_logger: Object
) -> bool:
	var modal_gate := _get_module(module_getter, "battle_scene_modal_gate_controller")
	if modal_gate == null:
		return false
	if modal_gate.has_method("should_block_battle_physics_with_perf"):
		return bool(modal_gate.call(
			"should_block_battle_physics_with_perf",
			module_getter,
			perf_logger
		))
	if modal_gate.has_method("should_block_battle_physics"):
		return bool(modal_gate.call("should_block_battle_physics", module_getter))
	return false


func _update_blocked_mythic_acquisition(
	delta: float,
	owner: Object,
	registry: Object,
	module_getter: Callable
) -> void:
	var modal_gate := _get_module(module_getter, "battle_scene_modal_gate_controller")
	if modal_gate == null:
		return
	# GRT-048: 게이트 술어들은 module_getter 1인자 시그니처다. has_method는
	# 인자수를 검증하지 못하므로 커밋본 _call_modal_gate_bool과 동일하게
	# module_getter를 전달한다.
	if not (
		modal_gate.has_method("is_mythic_acquisition_cinematic_active")
		and bool(modal_gate.call("is_mythic_acquisition_cinematic_active", module_getter))
	):
		return
	if (
		modal_gate.has_method("is_runtime_perk_choice_active")
		and bool(modal_gate.call("is_runtime_perk_choice_active", module_getter))
	) or (
		modal_gate.has_method("is_angel_blessing_modal_active")
		and bool(modal_gate.call("is_angel_blessing_modal_active", module_getter))
	):
		return
	var item_driver := _get_module(module_getter, "battle_scene_item_update_driver")
	if item_driver == null or not item_driver.has_method("update_mythic_items"):
		return
	item_driver.update_mythic_items(owner, registry, delta)
	_queue_redraw(owner)


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
	if typeof(value) == TYPE_OBJECT and value != null and is_instance_valid(value):
		return value as Object
	return null


func _get_cached_module(
	registry: Object,
	module_getter: Callable,
	key: String
) -> Object:
	if registry != null and registry.has_method("get_cached_instance"):
		var cached: Variant = registry.call("get_cached_instance", key)
		if typeof(cached) == TYPE_OBJECT and cached != null and is_instance_valid(cached):
			return cached as Object
		return null
	return _get_module(module_getter, key)


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
