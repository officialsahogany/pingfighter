extends RefCounted


func initialize(owner: CanvasItem, registry: Object, context: Dictionary = {}) -> void:
	if owner == null or registry == null:
		return
	var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
	var sample_start: int = _perf_begin(perf_logger)
	randomize()
	owner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	owner.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	var startup_context: Dictionary = _build_startup_context(owner, registry)
	if not context.is_empty():
		startup_context.merge(context, true)
	_perf_end(perf_logger, "process.intro.initialize_battle.lifecycle.context", sample_start)

	var view_layout: Object = _get_instance(registry, "battle_view_layout")
	if view_layout != null:
		sample_start = _perf_begin(perf_logger)
		view_layout.configure_window(owner.get_window())
		_perf_end(perf_logger, "process.intro.initialize_battle.lifecycle.configure_window", sample_start)

	var bootstrap: Object = _get_instance(registry, "battle_scene_bootstrap")
	if bootstrap != null:
		sample_start = _perf_begin(perf_logger)
		var bootstrap_snapshot: Dictionary = bootstrap.initialize(owner, startup_context, registry)
		_perf_end(perf_logger, "process.intro.initialize_battle.lifecycle.bootstrap", sample_start)
		sample_start = _perf_begin(perf_logger)
		_apply_owner_snapshot(owner, bootstrap_snapshot)
		_perf_end(perf_logger, "process.intro.initialize_battle.lifecycle.apply_snapshot", sample_start)
		sample_start = _perf_begin(perf_logger)
		_prepare_stage_clear_result_baseline(owner, registry, int(startup_context.get("current_stage", 1)))
		_perf_end(perf_logger, "process.intro.initialize_battle.lifecycle.result_baseline", sample_start)

	var update_driver: Object = _get_instance(registry, "battle_scene_update_driver")
	if update_driver != null:
		sample_start = _perf_begin(perf_logger)
		update_driver.reset_ball(owner, registry)
		_perf_end(perf_logger, "process.intro.initialize_battle.lifecycle.reset_ball", sample_start)
		if update_driver.has_method("prewarm_update"):
			sample_start = _perf_begin(perf_logger)
			update_driver.prewarm_update(owner, registry)
			_perf_end(perf_logger, "process.intro.initialize_battle.lifecycle.prewarm_update", sample_start)
		sample_start = _perf_begin(perf_logger)
		update_driver.prewarm_ball_update(owner, registry)
		_perf_end(perf_logger, "process.intro.initialize_battle.lifecycle.prewarm_ball", sample_start)


func _apply_owner_snapshot(owner: Object, snapshot: Dictionary) -> void:
	if owner == null:
		return
	for key in snapshot.keys():
		owner.set(str(key), snapshot[key])


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger == null or not perf_logger.has_method("begin_sample"):
		return 0
	return int(perf_logger.begin_sample())


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger == null or not perf_logger.has_method("finish_sample"):
		return
	perf_logger.finish_sample(label, start_usec)


func _prepare_stage_clear_result_baseline(owner: Object, registry: Object, stage_id: int) -> void:
	var result_screen: Object = _get_instance(registry, "stage_clear_result_screen")
	if result_screen != null and result_screen.has_method("prepare_stage_start"):
		result_screen.prepare_stage_start(owner, registry, stage_id)


func _build_startup_context(owner: Object, registry: Object) -> Dictionary:
	var config: Object = _get_instance(registry, "battle_scene_config")
	if config != null and config.has_method("build_startup_context"):
		return config.build_startup_context(owner)
	return {
		"width": 760.0,
		"height": 750.0,
		"pillar_width": 80.0,
		"player_y": 700.0,
		"boss_y": 25.0,
		"player_paddle_width": 155.0,
		"boss_paddle_width": 100.0,
		"current_stage": int(owner.get("current_stage")),
		"ai_mode": str(owner.get("ai_mode")),
		"arena_mode_enabled": bool(owner.get("arena_mode_enabled")),
		"weather_type": str(owner.get("weather_type")),
	}
