extends RefCounted

const BATTLE_SCENE_DRAW_PREWARM_FRAMES := 6

var _battle_scene_draw_prewarm_frames: int = 0


func process_idle(
	delta: float,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	callbacks: Dictionary
) -> bool:
	var perf_logger: Object = _get_module(module_getter, "battle_perf_logger")
	var sample_start: int = 0
	var logo_intro: Object = _get_module(module_getter, "penguin_logo_intro")
	if _is_active(logo_intro):
		if logo_intro.has_method("update"):
			sample_start = _perf_begin(perf_logger)
			logo_intro.update(delta)
			_perf_end(perf_logger, "process.intro.logo_update", sample_start)
		if logo_intro.has_method("is_active") and not bool(logo_intro.is_active()):
			if not _is_boot_warmup_finished(module_getter):
				_run_boot_warmup_step_with_perf(owner, module_getter, callbacks, perf_logger)
				_queue_redraw(owner)
				return true
		else:
			sample_start = _perf_begin(perf_logger)
			_call(callbacks, "run_logo_intro_warmup_step")
			_perf_end(perf_logger, "process.intro.logo_warmup_step", sample_start)
		_queue_redraw(owner)
		return true

	if not _is_boot_warmup_finished(module_getter):
		_run_boot_warmup_step_with_perf(owner, module_getter, callbacks, perf_logger)
		if not _is_boot_warmup_finished(module_getter):
			_queue_redraw(owner)
			return true
	if not _call_bool(callbacks, "is_stage_landing_intro_started") and _should_hold_loading_completion(owner, module_getter):
		_queue_redraw(owner)
		return true
	if not _call_bool(callbacks, "is_battle_initialized"):
		sample_start = _perf_begin(perf_logger)
		_call(callbacks, "initialize_battle")
		_perf_end(perf_logger, "process.intro.initialize_battle", sample_start)
	sample_start = _perf_begin(perf_logger)
	_call(callbacks, "begin_stage_landing_intro")
	_perf_end(perf_logger, "process.intro.begin_stage_landing", sample_start)
	if not _call_bool(callbacks, "is_stage_landing_intro_started"):
		_queue_redraw(owner)
		return true

	var landing_intro: Object = _get_module(module_getter, "stage_landing_intro")
	if _is_active(landing_intro):
		if landing_intro.has_method("update"):
			sample_start = _perf_begin(perf_logger)
			landing_intro.update(delta, registry)
			_perf_end(perf_logger, "process.intro.stage_landing_update", sample_start)
		if landing_intro.has_method("is_active") and not bool(landing_intro.is_active()):
			sample_start = _perf_begin(perf_logger)
			_call(callbacks, "begin_ball_spawn_intro")
			_perf_end(perf_logger, "process.intro.begin_ball_spawn", sample_start)
		_queue_redraw(owner)
		return true

	var ball_spawn_intro: Object = _get_module(module_getter, "stage_ball_spawn_intro")
	if _is_active(ball_spawn_intro) or _is_overlay_active(ball_spawn_intro):
		if ball_spawn_intro.has_method("update"):
			sample_start = _perf_begin(perf_logger)
			ball_spawn_intro.update(delta, owner, registry)
			_perf_end(perf_logger, "process.intro.ball_spawn_update", sample_start)
		_queue_redraw(owner)
		return _is_active(ball_spawn_intro)
	return false


func draw_intro_or_boot(
	canvas: CanvasItem,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	callbacks: Dictionary,
	view_size: Vector2
) -> bool:
	var logo_intro: Object = _get_module(module_getter, "penguin_logo_intro")
	if _is_active(logo_intro):
		if logo_intro.has_method("draw"):
			if _call_bool(callbacks, "is_battle_initialized") and _battle_scene_draw_prewarm_frames < BATTLE_SCENE_DRAW_PREWARM_FRAMES:
				_call(callbacks, "draw_battle_scene")
				_battle_scene_draw_prewarm_frames += 1
			logo_intro.draw(canvas, view_size)
		return true
	if not _call_bool(callbacks, "is_battle_initialized"):
		_draw_loading_screen(canvas, owner, module_getter, callbacks, view_size)
		return true
	var landing_intro: Object = _get_module(module_getter, "stage_landing_intro")
	if _is_active(landing_intro):
		_hide_loading_screen(module_getter, owner)
		if landing_intro.has_method("draw"):
			landing_intro.draw(canvas, owner, registry, view_size)
		return true
	if not _is_boot_warmup_finished(module_getter) or not _call_bool(callbacks, "is_stage_landing_intro_started"):
		_draw_loading_screen(canvas, owner, module_getter, callbacks, view_size)
		return true
	_hide_loading_screen(module_getter, owner)
	return false


func draw_ball_spawn_overlay(
	canvas: CanvasItem,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	view_size: Vector2
) -> bool:
	var ball_spawn_intro: Object = _get_module(module_getter, "stage_ball_spawn_intro")
	if _is_overlay_active(ball_spawn_intro) and ball_spawn_intro.has_method("draw"):
		ball_spawn_intro.draw(canvas, owner, registry, view_size)
		return true
	return false


func is_ball_spawn_overlay_active(module_getter: Callable) -> bool:
	return _is_overlay_active(_get_module(module_getter, "stage_ball_spawn_intro"))


func should_restore_ball_spawn_pillar_overlay(module_getter: Callable) -> bool:
	var ball_spawn_intro: Object = _get_module(module_getter, "stage_ball_spawn_intro")
	if not _is_overlay_active(ball_spawn_intro):
		return false
	if ball_spawn_intro.has_method("should_restore_pillar_overlay"):
		return bool(ball_spawn_intro.should_restore_pillar_overlay())
	return true


func _is_boot_warmup_finished(module_getter: Callable) -> bool:
	var readiness: Object = _get_module(module_getter, "battle_scene_readiness_controller")
	if readiness == null or not readiness.has_method("is_boot_warmup_finished"):
		return true
	return bool(readiness.is_boot_warmup_finished(module_getter))


func _is_active(module: Object) -> bool:
	return module != null and module.has_method("is_active") and bool(module.is_active())


func _is_overlay_active(module: Object) -> bool:
	if module == null:
		return false
	if module.has_method("is_overlay_active"):
		return bool(module.is_overlay_active())
	return _is_active(module)


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _call(callbacks: Dictionary, key: String) -> void:
	var callback: Callable = callbacks.get(key, Callable())
	if callback.is_valid():
		callback.call()


func _call_bool(callbacks: Dictionary, key: String) -> bool:
	var callback: Callable = callbacks.get(key, Callable())
	if not callback.is_valid():
		return false
	return bool(callback.call())


func _run_boot_warmup_step_with_perf(
	_owner: Object,
	module_getter: Callable,
	callbacks: Dictionary,
	perf_logger: Object
) -> void:
	var warmup: Object = _get_module(module_getter, "battle_boot_warmup_controller")
	var start_step := _get_int_property(warmup, "boot_warmup_step", -1)
	var start_detail_label := _get_boot_warmup_detail_label(warmup, _owner, module_getter)
	var sample_start: int = _perf_begin(perf_logger)
	_call(callbacks, "run_boot_warmup_step")
	var end_step := _get_int_property(warmup, "boot_warmup_step", -1)
	_perf_end(perf_logger, "process.intro.boot_warmup_step", sample_start)
	var batch_label := _build_boot_warmup_batch_sample_label(start_step, end_step)
	if batch_label == "":
		return
	_perf_end(perf_logger, batch_label, sample_start)
	var detail_batch_label := _build_boot_warmup_batch_detail_sample_label(start_step, end_step, start_detail_label)
	if detail_batch_label != "":
		_perf_end(perf_logger, detail_batch_label, sample_start)
	_record_counter(perf_logger, "boot_warmup.batch.start_step", float(start_step))
	_record_counter(perf_logger, "boot_warmup.batch.end_step", float(end_step))
	_record_counter(perf_logger, "boot_warmup.batch.steps_advanced", float(max(0, end_step - start_step)))


func _build_boot_warmup_batch_sample_label(start_step: int, end_step: int) -> String:
	if start_step < 0 or end_step < 0:
		return ""
	return "process.intro.boot_warmup_batch.step_%02d_to_%02d" % [start_step, end_step]


func _build_boot_warmup_batch_detail_sample_label(start_step: int, end_step: int, detail_label: String) -> String:
	if detail_label == "":
		return ""
	if start_step < 0 or end_step < 0:
		return ""
	return "process.intro.boot_warmup_batch_detail.step_%02d_to_%02d.%s" % [
		start_step,
		end_step,
		_sanitize_sample_token(detail_label),
	]


func _get_boot_warmup_detail_label(warmup: Object, owner: Object, module_getter: Callable) -> String:
	if warmup != null and warmup.has_method("get_current_sample_detail_label"):
		return str(warmup.get_current_sample_detail_label(owner, module_getter))
	return ""


func _get_int_property(source: Object, property_name: String, fallback: int) -> int:
	if source == null:
		return fallback
	var value: Variant = source.get(property_name)
	if typeof(value) == TYPE_INT:
		return int(value)
	if typeof(value) == TYPE_FLOAT:
		return int(value)
	return fallback


func _sanitize_sample_token(value: String) -> String:
	return value.replace("/", "_").replace("\\", "_").replace(":", "_").replace(" ", "_")


func _record_counter(perf_logger: Object, label: String, value: float) -> void:
	if perf_logger != null and perf_logger.has_method("record_counter_sample"):
		perf_logger.record_counter_sample(label, value)


func _queue_redraw(owner: Object) -> void:
	if owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()


func _should_hold_loading_completion(owner: Object, module_getter: Callable) -> bool:
	var renderer: Object = _get_module(module_getter, "battle_loading_screen_renderer")
	if renderer != null and renderer.has_method("should_hold_completion"):
		return bool(renderer.call("should_hold_completion", owner, module_getter))
	return false


func _draw_loading_screen(
	canvas: CanvasItem,
	owner: Object,
	module_getter: Callable,
	callbacks: Dictionary,
	view_size: Vector2
) -> void:
	var renderer: Object = _get_module(module_getter, "battle_loading_screen_renderer")
	if renderer != null and renderer.has_method("draw"):
		renderer.draw(canvas, owner, module_getter, view_size, {
			"battle_initialized": _call_bool(callbacks, "is_battle_initialized"),
			"stage_landing_intro_started": _call_bool(callbacks, "is_stage_landing_intro_started"),
		})
		return
	_draw_black(canvas, view_size)


func _hide_loading_screen(module_getter: Callable, owner: Object = null) -> void:
	var renderer: Object = _get_module(module_getter, "battle_loading_screen_renderer")
	if renderer != null and renderer.has_method("hide_loading"):
		renderer.call("hide_loading")
	if renderer != null and renderer.has_method("release_stained_glass_hosts"):
		renderer.call("release_stained_glass_hosts", owner)


func _draw_black(canvas: CanvasItem, view_size: Vector2) -> void:
	if canvas != null:
		canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color.BLACK)


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
