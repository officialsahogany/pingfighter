extends RefCounted

const BattleSceneBossHealthFlow := preload("res://scripts/core/battle_scene_boss_health_flow.gd")

var _last_mythic_update_frame := -1
var _fallback_boss_health_flow: Object = BattleSceneBossHealthFlow.new()
var _method_argument_count_cache: Dictionary = {}


func update_items(owner: Object, registry: Object, delta: float) -> void:
	var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
	var total_start: int = _perf_begin(perf_logger)
	var active_item_runtime: Object = _get_instance(registry, "active_item_runtime")
	if active_item_runtime != null and active_item_runtime.has_method("update"):
		var sample_start: int = _perf_begin(perf_logger)
		_call_active_item_runtime_update(active_item_runtime, owner, registry, delta, perf_logger)
		_perf_end(perf_logger, "physics.items.active_runtime", sample_start)
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	var mythic_start: int = _perf_begin(perf_logger)
	_update_mythic_once(owner, registry, delta, mythic_item_runtime)
	_perf_end(perf_logger, "physics.items.mythic_once_from_active", mythic_start)
	if (
		mythic_item_runtime != null
		and mythic_item_runtime.has_method("consume_foul_whistle_reset_ready")
		and bool(mythic_item_runtime.consume_foul_whistle_reset_ready())
	):
		var reset_start: int = _perf_begin(perf_logger)
		_reset_ball_after_foul_whistle(owner, registry)
		_perf_end(perf_logger, "physics.items.foul_whistle_reset", reset_start)
	_perf_end(perf_logger, "physics.items.active_total", total_start)


func update_mythic_items(owner: Object, registry: Object, delta: float) -> void:
	var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
	var sample_start: int = _perf_begin(perf_logger)
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	_update_mythic_once(owner, registry, delta, mythic_item_runtime)
	_perf_end(perf_logger, "physics.items.mythic_total", sample_start)


func restore_pending_throw_item_on_round_end(owner: Object, registry: Object) -> void:
	var active_item_runtime: Object = _get_instance(registry, "active_item_runtime")
	if (
		active_item_runtime != null
		and active_item_runtime.has_method("restore_pending_throw_item_on_round_end")
	):
		active_item_runtime.restore_pending_throw_item_on_round_end(owner, registry)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _call_active_item_runtime_update(
	active_item_runtime: Object,
	owner: Object,
	registry: Object,
	delta: float,
	perf_logger: Object
) -> void:
	if _get_method_argument_count(active_item_runtime, "update") >= 4:
		active_item_runtime.update(owner, registry, delta, perf_logger)
	else:
		active_item_runtime.update(owner, registry, delta)


func _reset_ball_after_foul_whistle(owner: Object, registry: Object) -> void:
	var ball_driver: Object = _get_instance(registry, "battle_scene_ball_update_driver")
	if ball_driver != null and ball_driver.has_method("reset_ball"):
		ball_driver.reset_ball(owner, registry)
	_reset_boss_round_health(owner, registry)
	var round_state: Object = _get_instance(registry, "round_flow_state")
	if round_state != null:
		if round_state.has_method("set_player_serves"):
			round_state.set_player_serves(true)
		if round_state.has_method("reset_round_wait"):
			round_state.reset_round_wait()


func _update_mythic_once(owner: Object, registry: Object, delta: float, mythic_item_runtime: Object) -> void:
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("update"):
		return
	var frame_key := -1
	if owner != null:
		var value: Variant = owner.get("gameplay_frame_counter")
		if value != null:
			frame_key = int(value)
	if frame_key >= 0 and frame_key == _last_mythic_update_frame and not _is_pause_cinematic_active(mythic_item_runtime):
		return
	mythic_item_runtime.update(owner, registry, delta)
	if frame_key >= 0:
		_last_mythic_update_frame = frame_key


func _is_pause_cinematic_active(mythic_item_runtime: Object) -> bool:
	if mythic_item_runtime.has_method("is_acquisition_cinematic_active") and bool(mythic_item_runtime.is_acquisition_cinematic_active()):
		return true
	if mythic_item_runtime.has_method("is_baal_boots_cinematic_active") and bool(mythic_item_runtime.is_baal_boots_cinematic_active()):
		return true
	if mythic_item_runtime.has_method("is_pandora_legacy_selection_active") and bool(mythic_item_runtime.is_pandora_legacy_selection_active()):
		return true
	return false


func _reset_boss_round_health(owner: Object, registry: Object) -> void:
	var flow: Object = _get_instance(registry, "battle_scene_boss_health_flow")
	if flow == null or not flow.has_method("reset_round_health"):
		flow = _fallback_boss_health_flow
	flow.reset_round_health(owner)


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
