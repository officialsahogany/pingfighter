extends RefCounted

const BattleSceneUpdateCallbacks := preload("res://scripts/core/battle_scene_update_callbacks.gd")

var _callbacks: Object = BattleSceneUpdateCallbacks.new()


func update(owner: Object, registry: Object, delta: float) -> void:
	if owner == null or registry == null:
		return
	var flow_controller: Object = _get_instance(registry, "battle_frame_flow_controller")
	if flow_controller == null:
		return

	var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
	var total_start: int = _perf_begin(perf_logger)
	var callbacks_start: int = _perf_begin(perf_logger)
	var frame_callbacks: Dictionary = _callbacks.build_frame_callbacks(owner, registry)
	_perf_end(perf_logger, "physics.update_driver.build_callbacks", callbacks_start)
	var pending_scoreboard_start: int = _perf_begin(perf_logger)
	if _dispatch_pending_scoreboard_result(registry, frame_callbacks, perf_logger):
		_perf_end(perf_logger, "physics.update_driver.scoreboard_result", pending_scoreboard_start)
		_perf_end(perf_logger, "physics.update_driver.total", total_start)
		return
	_perf_end(perf_logger, "physics.update_driver.scoreboard_result", pending_scoreboard_start)
	var deps_start: int = _perf_begin(perf_logger)
	var deps: Dictionary = _build_frame_flow_deps(owner, registry)
	_perf_end(perf_logger, "physics.update_driver.build_deps", deps_start)
	deps["perf_logger"] = perf_logger
	var flow_start: int = _perf_begin(perf_logger)
	flow_controller.update(delta, deps, frame_callbacks)
	_perf_end(perf_logger, "physics.update_driver.flow_update", flow_start)
	_perf_end(perf_logger, "physics.update_driver.total", total_start)


func update_scoreboard_overlay(owner: Object, registry: Object, delta: float) -> void:
	if owner == null or registry == null:
		return
	var scoreboard_driver: Object = _get_scoreboard_update_driver(registry)
	if scoreboard_driver == null or not scoreboard_driver.has_method("update_scoreboard_overlay"):
		return

	var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
	var callbacks: Dictionary = _callbacks.build_frame_callbacks(owner, registry)
	if _method_accepts_argument_count(scoreboard_driver, "update_scoreboard_overlay", 5):
		scoreboard_driver.update_scoreboard_overlay(owner, registry, delta, callbacks, perf_logger)
	else:
		scoreboard_driver.update_scoreboard_overlay(owner, registry, delta, callbacks)


func update_scoreboard_visuals(owner: Object, registry: Object, delta: float) -> void:
	if owner == null or registry == null:
		return
	var scoreboard_driver: Object = _get_scoreboard_update_driver(registry)
	if scoreboard_driver != null and scoreboard_driver.has_method("update_scoreboard_visuals"):
		var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
		var sample_start: int = _perf_begin(perf_logger)
		scoreboard_driver.update_scoreboard_visuals(owner, registry, delta)
		_perf_end(perf_logger, "process.scoreboard_visuals", sample_start)


func prewarm_update(owner: Object, registry: Object) -> void:
	if owner == null or registry == null:
		return
	var prewarm_driver: Object = _get_update_prewarm_driver(registry)
	if prewarm_driver != null and prewarm_driver.has_method("prewarm_update"):
		prewarm_driver.prewarm_update(owner, registry)

	_callbacks.build_frame_callbacks(owner, registry)


func reset_ball(owner: Object, registry: Object) -> void:
	_callbacks.reset_ball(owner, registry)


func prewarm_ball_update(owner: Object, registry: Object) -> void:
	var prewarm_driver: Object = _get_update_prewarm_driver(registry)
	if prewarm_driver != null and prewarm_driver.has_method("prewarm_ball_update"):
		prewarm_driver.prewarm_ball_update(owner, registry)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _build_frame_flow_deps(owner: Object, registry: Object) -> Dictionary:
	var deps_builder: Object = _get_instance(registry, "battle_frame_flow_deps_builder")
	if deps_builder == null or not deps_builder.has_method("build_deps"):
		return {}
	return deps_builder.build_deps(owner, registry)


func _get_scoreboard_update_driver(registry: Object) -> Object:
	return _get_instance(registry, "battle_scene_scoreboard_update_driver")


func _get_update_prewarm_driver(registry: Object) -> Object:
	return _get_instance(registry, "battle_scene_update_prewarm_driver")


func _dispatch_pending_scoreboard_result(
	registry: Object,
	frame_callbacks: Dictionary,
	perf_logger: Object
) -> bool:
	var scoreboard_driver: Object = _get_scoreboard_update_driver(registry)
	if scoreboard_driver == null or not scoreboard_driver.has_method("dispatch_pending_scoreboard_result"):
		return false
	return bool(scoreboard_driver.dispatch_pending_scoreboard_result(frame_callbacks, perf_logger))


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


func _method_accepts_argument_count(target: Object, method_name: String, argument_count: int) -> bool:
	if target == null:
		return false
	for method_value in target.get_method_list():
		var method_info: Dictionary = method_value if method_value is Dictionary else {}
		if str(method_info.get("name", "")) != method_name:
			continue
		var args: Array = method_info.get("args", [])
		return args.size() >= argument_count
	return false
