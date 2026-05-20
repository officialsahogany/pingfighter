extends RefCounted

const ScoreboardState := preload("res://scripts/hud/scoreboard_state.gd")


func draw(canvas: CanvasItem, registry: Object, view_size: Vector2, layout: Dictionary, context_owner: Object = null) -> void:
	var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
	var total_start: int = _perf_begin(perf_logger)
	var draw_context_builder: Object = _get_instance(registry, "battle_draw_context")
	if draw_context_builder == null:
		_perf_end(perf_logger, "draw.pillar.total", total_start)
		return
	var context_source: Object = context_owner if context_owner != null else canvas
	var sample_start: int = _perf_begin(perf_logger)
	var context: Dictionary = draw_context_builder.build_pillar_scene_context(
		context_source,
		view_size,
		layout,
		ScoreboardState.TOP_MINI_SCORE_SPARKLE_DURATION
	)
	_append_viper_lod_context(context, registry)
	context["battle_perf_logger"] = perf_logger
	_perf_end(perf_logger, "draw.pillar.context", sample_start)
	var current_stage: int = int(context.get("current_stage", 1))
	sample_start = _perf_begin(perf_logger)
	var states: Dictionary = draw_context_builder.build_pillar_scene_states(registry, current_stage)
	_perf_end(perf_logger, "draw.pillar.states", sample_start)
	var pillar_scene_drawer: Object = _get_stage_instance(registry, current_stage, "pillar_scene_drawer", "stage1_pillar_scene_drawer")
	if pillar_scene_drawer == null:
		_perf_end(perf_logger, "draw.pillar.total", total_start)
		return
	sample_start = _perf_begin(perf_logger)
	pillar_scene_drawer.draw(
		canvas,
		context,
		registry,
		states
	)
	_perf_end(perf_logger, "draw.pillar.stage_draw", sample_start)
	_perf_end(perf_logger, "draw.pillar.total", total_start)


func draw_hud_overlay(canvas: CanvasItem, registry: Object, view_size: Vector2, layout: Dictionary, context_owner: Object = null) -> void:
	var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
	var total_start: int = _perf_begin(perf_logger)
	var draw_context_builder: Object = _get_instance(registry, "battle_draw_context")
	if draw_context_builder == null:
		_perf_end(perf_logger, "draw.pillar_hud_overlay.total", total_start)
		return
	var context_source: Object = context_owner if context_owner != null else canvas
	var sample_start: int = _perf_begin(perf_logger)
	var context: Dictionary = draw_context_builder.build_pillar_scene_context(
		context_source,
		view_size,
		layout,
		ScoreboardState.TOP_MINI_SCORE_SPARKLE_DURATION
	)
	_append_viper_lod_context(context, registry)
	context["battle_perf_logger"] = perf_logger
	_perf_end(perf_logger, "draw.pillar_hud_overlay.context", sample_start)
	var current_stage: int = int(context.get("current_stage", 1))
	sample_start = _perf_begin(perf_logger)
	var states: Dictionary = draw_context_builder.build_pillar_scene_states(registry, current_stage)
	_perf_end(perf_logger, "draw.pillar_hud_overlay.states", sample_start)
	var pillar_scene_drawer: Object = _get_stage_instance(registry, current_stage, "pillar_scene_drawer", "stage1_pillar_scene_drawer")
	if pillar_scene_drawer == null or not pillar_scene_drawer.has_method("draw_pillar_hud_overlay"):
		_perf_end(perf_logger, "draw.pillar_hud_overlay.total", total_start)
		return
	sample_start = _perf_begin(perf_logger)
	pillar_scene_drawer.draw_pillar_hud_overlay(
		canvas,
		context,
		registry,
		states
	)
	_perf_end(perf_logger, "draw.pillar_hud_overlay.stage_draw", sample_start)
	_perf_end(perf_logger, "draw.pillar_hud_overlay.total", total_start)


func draw_background_overlay(canvas: CanvasItem, registry: Object, view_size: Vector2, layout: Dictionary, context_owner: Object = null) -> void:
	var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
	var total_start: int = _perf_begin(perf_logger)
	var draw_context_builder: Object = _get_instance(registry, "battle_draw_context")
	if draw_context_builder == null:
		_perf_end(perf_logger, "draw.pillar_background_overlay.total", total_start)
		return
	var context_source: Object = context_owner if context_owner != null else canvas
	var sample_start: int = _perf_begin(perf_logger)
	var context: Dictionary = draw_context_builder.build_pillar_scene_context(
		context_source,
		view_size,
		layout,
		ScoreboardState.TOP_MINI_SCORE_SPARKLE_DURATION
	)
	_append_viper_lod_context(context, registry)
	context["battle_perf_logger"] = perf_logger
	_perf_end(perf_logger, "draw.pillar_background_overlay.context", sample_start)
	var current_stage: int = int(context.get("current_stage", 1))
	sample_start = _perf_begin(perf_logger)
	var states: Dictionary = draw_context_builder.build_pillar_scene_states(registry, current_stage)
	_perf_end(perf_logger, "draw.pillar_background_overlay.states", sample_start)
	var pillar_scene_drawer: Object = _get_stage_instance(registry, current_stage, "pillar_scene_drawer", "stage1_pillar_scene_drawer")
	if pillar_scene_drawer == null or not pillar_scene_drawer.has_method("draw_pillar_background_overlay"):
		_perf_end(perf_logger, "draw.pillar_background_overlay.total", total_start)
		return
	sample_start = _perf_begin(perf_logger)
	pillar_scene_drawer.draw_pillar_background_overlay(
		canvas,
		context,
		registry,
		states
	)
	_perf_end(perf_logger, "draw.pillar_background_overlay.stage_draw", sample_start)
	_perf_end(perf_logger, "draw.pillar_background_overlay.total", total_start)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _append_viper_lod_context(context: Dictionary, registry: Object) -> void:
	var jetpack_state: Object = _get_instance(registry, "viper_jetpack_state")
	if jetpack_state == null:
		return
	if "active" in jetpack_state:
		context["viper_jetpack_active"] = bool(jetpack_state.active)
	if jetpack_state.has_method("is_airborne"):
		context["viper_jetpack_airborne"] = bool(jetpack_state.is_airborne(0.1))
	if "air_strike_flash_timer" in jetpack_state:
		context["viper_air_strike_flash_timer"] = float(jetpack_state.air_strike_flash_timer)


func _get_stage_instance(registry: Object, current_stage: int, role: String, fallback_key: String) -> Object:
	var router: Object = _get_instance(registry, "stage_runtime_router")
	if router != null and router.has_method("get_instance"):
		var routed: Object = router.get_instance(registry, current_stage, role)
		if routed != null:
			return routed
	return _get_instance(registry, fallback_key)


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
