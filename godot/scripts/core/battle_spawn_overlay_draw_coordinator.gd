extends RefCounted


func draw(
	canvas: CanvasItem,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	callbacks: Dictionary,
	intro_frame: Object,
	view_size: Vector2,
	perf_logger: Object = null
) -> void:
	var overlay_active := (
		intro_frame != null
		and intro_frame.has_method("is_ball_spawn_overlay_active")
		and bool(intro_frame.call("is_ball_spawn_overlay_active", module_getter))
	)
	var should_restore_pillars := (
		overlay_active
		and (
			not intro_frame.has_method("should_restore_ball_spawn_pillar_overlay")
			or bool(intro_frame.call(
				"should_restore_ball_spawn_pillar_overlay",
				module_getter
			))
		)
	)
	var split_pass := (
		should_restore_pillars
		and _has_callback(callbacks, "draw_battle_pillar_overlay")
	)

	_draw_callback(
		callbacks,
		"draw_battle_scene",
		perf_logger,
		"draw.frame.battle_scene"
	)
	if intro_frame != null and intro_frame.has_method("draw_ball_spawn_overlay"):
		var spawn_start := _perf_begin(perf_logger)
		intro_frame.call(
			"draw_ball_spawn_overlay",
			canvas,
			owner,
			registry,
			module_getter,
			view_size
		)
		_perf_end(perf_logger, "draw.frame.ball_spawn_overlay", spawn_start)
	if split_pass:
		_draw_callback(
			callbacks,
			"draw_battle_pillar_overlay",
			perf_logger,
			"draw.frame.pillar_overlay"
		)


func _draw_callback(
	callbacks: Dictionary,
	key: String,
	perf_logger: Object,
	perf_label: String
) -> void:
	var start_usec := _perf_begin(perf_logger)
	var callback: Callable = callbacks.get(key, Callable())
	if callback.is_valid():
		callback.call()
	_perf_end(perf_logger, perf_label, start_usec)


func _has_callback(callbacks: Dictionary, key: String) -> bool:
	var callback: Callable = callbacks.get(key, Callable())
	return callback.is_valid()


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.call("begin_sample"))
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.call("finish_sample", label, start_usec)
