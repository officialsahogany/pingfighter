extends RefCounted

const BattleSceneBallSnapshotApplier := preload("res://scripts/core/battle_scene_ball_snapshot_applier.gd")
const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

var _snapshot_applier: Object = BattleSceneBallSnapshotApplier.new()


func reset_ball(owner: Object, registry: Object) -> void:
	var controller: Object = _get_instance(registry, "ball_round_controller")
	var context_builder: Object = _get_instance(registry, "ball_update_context")
	if owner == null or controller == null or context_builder == null:
		return
	var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
	var total_start: int = _perf_begin(perf_logger)
	var sample_start: int = _perf_begin(perf_logger)
	var reset_config: Dictionary = context_builder.build_reset_config(owner)
	_perf_end(perf_logger, "process.reset_ball.build_config", sample_start)
	sample_start = _perf_begin(perf_logger)
	var round_deps: Dictionary = _get_ball_round_deps(
		registry,
		owner,
		perf_logger,
		"process.reset_ball.build_deps"
	)
	round_deps["perf_logger"] = perf_logger
	_perf_end(perf_logger, "process.reset_ball.build_deps", sample_start)
	sample_start = _perf_begin(perf_logger)
	var result: Dictionary = controller.reset_ball(
		reset_config,
		round_deps,
		{"apply_ball_snapshot": Callable(self, "_apply_current_owner_snapshot").bind(owner)}
	)
	_perf_end(perf_logger, "process.reset_ball.controller", sample_start)
	sample_start = _perf_begin(perf_logger)
	_snapshot_applier.apply_reset_result(owner, result)
	_perf_end(perf_logger, "process.reset_ball.apply_result", sample_start)
	_perf_end(perf_logger, "process.reset_ball.total", total_start)


func serve_ball(owner: Object, registry: Object) -> void:
	var controller: Object = _get_instance(registry, "ball_round_controller")
	var context_builder: Object = _get_instance(registry, "ball_update_context")
	if owner == null or controller == null or context_builder == null:
		return
	var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
	var total_start: int = _perf_begin(perf_logger)
	var sample_start: int = _perf_begin(perf_logger)
	var serve_config: Dictionary = context_builder.build_serve_config(owner)
	_perf_end(perf_logger, "physics.serve_ball.build_config", sample_start)
	sample_start = _perf_begin(perf_logger)
	var round_deps: Dictionary = _get_ball_round_deps(
		registry,
		owner,
		perf_logger,
		"physics.serve_ball.build_deps"
	)
	round_deps["perf_logger"] = perf_logger
	_perf_end(perf_logger, "physics.serve_ball.build_deps", sample_start)
	sample_start = _perf_begin(perf_logger)
	controller.serve_ball(
		serve_config,
		round_deps,
		{"apply_ball_snapshot": Callable(self, "_apply_current_owner_snapshot").bind(owner)}
	)
	_perf_end(perf_logger, "physics.serve_ball.controller", sample_start)
	_perf_end(perf_logger, "physics.serve_ball.total", total_start)


func prewarm_update(owner: Object, registry: Object) -> void:
	var controller: Object = _get_instance(registry, "ball_update_controller")
	var context_builder: Object = _get_instance(registry, "ball_update_context")
	if owner == null or controller == null or context_builder == null:
		return
	var update_context: Dictionary = context_builder.build_update_context(owner)
	context_builder.build_update_deps(registry, update_context)


func prewarm_round_deps(owner: Object, registry: Object) -> void:
	_get_ball_round_deps(registry, owner)


func update_ball(
	owner: Object,
	registry: Object,
	delta: float,
	score_callback: Callable = Callable(),
	round_restart_callback: Callable = Callable()
) -> void:
	var controller: Object = _get_instance(registry, "ball_update_controller")
	var context_builder: Object = _get_instance(registry, "ball_update_context")
	if owner == null or controller == null or context_builder == null:
		return
	var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
	var total_start: int = _perf_begin(perf_logger)
	var sample_start: int = _perf_begin(perf_logger)
	var update_context: Dictionary = context_builder.build_update_context(owner)
	_perf_end(perf_logger, "physics.ball.build_context", sample_start)
	sample_start = _perf_begin(perf_logger)
	var update_deps: Dictionary = context_builder.build_update_deps(registry, update_context)
	_perf_end(perf_logger, "physics.ball.build_deps", sample_start)
	# Inject perf_logger into deps so the ball update controller can subdivide
	# its hot physics step (motion / collision / stage collision / effects) for
	# spike attribution. The driver layer already owns the perf_logger handle
	# via the registry, so threading it through deps keeps the controller free
	# of registry knowledge.
	update_deps["perf_logger"] = perf_logger
	sample_start = _perf_begin(perf_logger)
	var result: Dictionary = controller.update(
		delta,
		update_context,
		update_deps,
		{
			"reset_drive_input": Callable(self, "_reset_drive_input_frames").bind(registry),
			"clear_drive_ball": Callable(self, "_clear_drive_ball_state").bind(owner, registry),
		}
	)
	_perf_end(perf_logger, "physics.ball.controller", sample_start)
	sample_start = _perf_begin(perf_logger)
	var apply_events_start: int = sample_start
	var snapshot: Variant = result.get("snapshot", {})
	if snapshot is Dictionary:
		_snapshot_applier.apply_snapshot(owner, snapshot)
	_perf_end(perf_logger, "physics.ball.apply_snapshot", sample_start)
	sample_start = _perf_begin(perf_logger)
	var score_event: String = str(result.get("score_event", ""))
	if score_event != "" and score_callback.is_valid():
		score_callback.call(score_event)
	_perf_end(perf_logger, "physics.ball.score_event", sample_start)
	sample_start = _perf_begin(perf_logger)
	var round_restart_event: String = str(result.get("round_restart_event", ""))
	if round_restart_event != "" and round_restart_callback.is_valid():
		round_restart_callback.call(round_restart_event)
	_perf_end(perf_logger, "physics.ball.round_restart_event", sample_start)
	_perf_end(perf_logger, "physics.ball.apply_and_events", apply_events_start)
	_perf_end(perf_logger, "physics.ball.total", total_start)


func reset_drive_input_frames(registry: Object) -> void:
	var bridge: Object = _get_instance(registry, "ball_scene_bridge")
	if bridge != null:
		bridge.reset_drive_input_frames(registry)


func _reset_drive_input_frames(registry: Object) -> void:
	reset_drive_input_frames(registry)


func _clear_drive_ball_state(first: Variant = false, second: Variant = null, third: Variant = null) -> void:
	var parsed := _parse_clear_drive_ball_callback_args(first, second, third)
	var owner: Object = parsed.get("owner", null)
	var registry: Object = parsed.get("registry", null)
	var clear_spin: bool = bool(parsed.get("clear_spin", false))
	var bridge: Object = _get_instance(registry, "ball_scene_bridge")
	if bridge != null:
		_snapshot_applier.apply_snapshot(owner, bridge.clear_drive_ball_state(registry, clear_spin))


func _parse_clear_drive_ball_callback_args(first: Variant, second: Variant, third: Variant) -> Dictionary:
	if first is bool:
		return {
			"clear_spin": bool(first),
			"owner": second,
			"registry": third,
		}
	return {
		"clear_spin": false,
		"owner": first,
		"registry": second,
	}


func _get_ball_round_deps(
	registry: Object,
	owner: Object = null,
	perf_logger: Object = null,
	perf_label_prefix: String = ""
) -> Dictionary:
	var context_builder: Object = _get_instance(registry, "ball_update_context")
	if context_builder == null:
		return {}
	var runtime_context: Dictionary = _build_round_runtime_context(owner)
	if not runtime_context.is_empty():
		runtime_context["_perf_logger"] = perf_logger
		runtime_context["_perf_prefix"] = perf_label_prefix
	return context_builder.build_round_deps(registry, runtime_context)


func _build_round_runtime_context(owner: Object) -> Dictionary:
	if owner == null:
		return {}
	return {
		"current_stage": BattleSceneOwnerReader.get_value(owner, "current_stage", 1),
		"selected_character_type": BattleSceneOwnerReader.get_value(owner, "selected_character_type", "smasher"),
	}


func _apply_current_owner_snapshot(snapshot: Dictionary, owner: Object) -> void:
	_snapshot_applier.apply_snapshot(owner, snapshot)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
