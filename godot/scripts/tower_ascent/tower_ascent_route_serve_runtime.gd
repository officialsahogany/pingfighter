extends RefCounted

const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")

const STATUS_WAITING := "waiting"
const STATUS_FLIGHT := "flight"
const STATUS_MISS := "miss"
const STATUS_HIT := "hit"
const DEBUG_SERVE_SPEED_PER_FRAME := 8.7

var _active := false
var _fixture_mode := false
var _owner: Object = null
var _registry: Object = null
var _round_state: Object = null
var _serve_flow: Object = null
var _ball_driver: Object = null
var _motion_stepper: Object = null
var _owner_properties: Dictionary = {}
var _fixture_ball_position := Vector2.ZERO
var _fixture_ball_velocity := Vector2.ZERO
var _fixture_ball_active := false
var _serve_attempt_count := 0


func begin(owner: Object, registry: Object) -> Dictionary:
	cancel()
	_owner = owner
	_registry = registry
	_fixture_mode = owner == null or not (owner is Node)
	_owner_properties = _collect_property_names(owner)
	_serve_attempt_count = 0
	if _fixture_mode:
		_active = true
		return {"accepted": true, "reason": "test_fixture"}
	_round_state = _get_instance(registry, "round_flow_state")
	_serve_flow = _get_instance(registry, "serve_flow_controller")
	_ball_driver = _get_instance(registry, "battle_scene_ball_update_driver")
	_motion_stepper = _get_instance(registry, "ball_motion_stepper")
	if not _has_production_contract():
		cancel()
		return {"accepted": false, "reason": "missing_route_serve_contract"}
	_prepare_next_serve()
	_active = true
	return {"accepted": true, "reason": "ready"}


func cancel() -> void:
	if _active:
		_hide_owned_ball()
	_active = false
	_fixture_mode = false
	_owner = null
	_registry = null
	_round_state = null
	_serve_flow = null
	_ball_driver = null
	_motion_stepper = null
	_owner_properties.clear()
	_fixture_ball_position = Vector2.ZERO
	_fixture_ball_velocity = Vector2.ZERO
	_fixture_ball_active = false


func finish_selection() -> void:
	_hide_owned_ball()
	_active = false


func update(delta: float, targets: Array[Dictionary]) -> Dictionary:
	if not _active:
		return {"status": STATUS_WAITING}
	if _fixture_mode:
		return _update_fixture_flight(delta, targets)
	if bool(_round_state.is_waiting_for_serve()):
		_serve_flow.update(
			maxf(0.0, delta),
			{"current_stage": int(_owner_value("current_stage", 1))},
			{"round_state": _round_state},
			{"serve_ball": Callable(self, "_serve_live_ball")}
		)
		return {"status": STATUS_WAITING}
	if not bool(_owner_value("ball_active", false)):
		_prepare_next_serve()
		return {"status": STATUS_MISS}
	return _advance_live_ball(delta, targets)


func debug_serve_toward(target_position: Vector2) -> void:
	if not _active:
		return
	var origin := Vector2(BattleSceneConfig.WIDTH * 0.5, BattleSceneConfig.HEIGHT - 85.0)
	var direction := (target_position - origin).normalized()
	_fixture_ball_position = origin
	_fixture_ball_velocity = direction * DEBUG_SERVE_SPEED_PER_FRAME
	_fixture_ball_active = true
	_serve_attempt_count += 1
	_sync_fixture_to_owner()


func debug_serve_miss() -> void:
	debug_serve_toward(Vector2(BattleSceneConfig.WIDTH * 0.5, -60.0))


func is_ball_in_flight() -> bool:
	if _fixture_mode:
		return _fixture_ball_active
	return _active and bool(_owner_value("ball_active", false)) and not bool(
		_round_state.is_waiting_for_serve()
	)


func get_ball_position() -> Vector2:
	if _fixture_mode:
		return _fixture_ball_position
	var value: Variant = _owner_value("ball_pos", Vector2.ZERO)
	return value as Vector2 if value is Vector2 else Vector2.ZERO


func get_serve_attempt_count() -> int:
	return _serve_attempt_count


func _serve_live_ball() -> void:
	_ball_driver.serve_ball(_owner, _registry)
	if bool(_owner_value("ball_active", false)):
		_serve_attempt_count += 1


func _advance_live_ball(delta: float, targets: Array[Dictionary]) -> Dictionary:
	var previous := _owner_vector2("ball_pos", Vector2.ZERO)
	var velocity := _owner_vector2("ball_vel", Vector2.ZERO)
	var impact_boost := maxf(0.0, float(_owner_value("ball_impact_boost", 1.0)))
	var movement := velocity * impact_boost * maxf(0.0, delta) * 60.0
	var step_result: Dictionary = _motion_stepper.step(
		previous,
		movement,
		velocity,
		_build_route_motion_context()
	)
	var current := _vector2(step_result.get("ball_pos", previous), previous)
	var target_id := _find_hit_target(previous, current, _ball_radius(), targets)
	if not target_id.is_empty():
		_set_owner_value("ball_pos", current)
		_hide_owned_ball()
		return {"status": STATUS_HIT, "target_id": target_id}
	match str(step_result.get("event", "none")):
		"wall":
			var side := str(step_result.get("side", ""))
			velocity.x = absf(velocity.x) if side == "left" else -absf(velocity.x)
			_set_owner_value("ball_pos", current)
			_set_owner_value("ball_vel", velocity)
			return {"status": STATUS_FLIGHT}
		"player_scored", "boss_scored":
			_prepare_next_serve()
			return {"status": STATUS_MISS}
	_set_owner_value("ball_pos", current)
	return {"status": STATUS_FLIGHT}


func _update_fixture_flight(delta: float, targets: Array[Dictionary]) -> Dictionary:
	if not _fixture_ball_active:
		return {"status": STATUS_WAITING}
	var previous := _fixture_ball_position
	_fixture_ball_position += _fixture_ball_velocity * maxf(0.0, delta) * 60.0
	var target_id := _find_hit_target(previous, _fixture_ball_position, _ball_radius(), targets)
	if not target_id.is_empty():
		_fixture_ball_active = false
		_sync_fixture_to_owner()
		return {"status": STATUS_HIT, "target_id": target_id}
	if _fixture_ball_position.y < 0.0 or _fixture_ball_position.y > BattleSceneConfig.HEIGHT:
		_fixture_ball_active = false
		_fixture_ball_position = Vector2(BattleSceneConfig.WIDTH * 0.5, BattleSceneConfig.HEIGHT - 85.0)
		_fixture_ball_velocity = Vector2.ZERO
		_sync_fixture_to_owner()
		return {"status": STATUS_MISS}
	_sync_fixture_to_owner()
	return {"status": STATUS_FLIGHT}


func _prepare_next_serve() -> void:
	_round_state.set_player_serves(true)
	_round_state.reset_round_wait()
	_ball_driver.reset_ball(_owner, _registry)
	_serve_flow.sync_current_input_state()


func _hide_owned_ball() -> void:
	if _fixture_mode:
		_fixture_ball_active = false
		_fixture_ball_velocity = Vector2.ZERO
		_sync_fixture_to_owner()
		return
	_set_owner_value("ball_active", false)
	_set_owner_value("ball_vel", Vector2.ZERO)


func _find_hit_target(
	segment_start: Vector2,
	segment_end: Vector2,
	ball_radius: float,
	targets: Array[Dictionary]
) -> String:
	for target in targets:
		var target_position := _vector2(target.get("position", Vector2.ZERO), Vector2.ZERO)
		var hit_radius := maxf(0.0, float(target.get("hit_radius", 0.0))) + ball_radius
		if hit_radius <= 0.0:
			continue
		if _distance_to_segment(target_position, segment_start, segment_end) <= hit_radius:
			return str(target.get("id", ""))
	return ""


func _distance_to_segment(point: Vector2, segment_start: Vector2, segment_end: Vector2) -> float:
	var segment := segment_end - segment_start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(segment_start)
	var ratio := clampf((point - segment_start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(segment_start + segment * ratio)


func _build_route_motion_context() -> Dictionary:
	return {
		"ball_size": maxf(4.0, float(_owner_value("ball_size", 28.6))),
		"width": BattleSceneConfig.WIDTH,
		"height": BattleSceneConfig.HEIGHT,
		"max_step_distance": 12.0,
		"player_pos": Vector2(-1000.0, -1000.0),
		"player_paddle_size": Vector2.ZERO,
		"boss_pos": Vector2(-1000.0, -1000.0),
		"boss_paddle_size": Vector2.ZERO,
	}


func _ball_radius() -> float:
	return maxf(2.0, float(_owner_value("ball_size", 28.6)) * 0.5)


func _has_production_contract() -> bool:
	return (
		_round_state != null
		and _round_state.has_method("is_waiting_for_serve")
		and _round_state.has_method("set_player_serves")
		and _round_state.has_method("reset_round_wait")
		and _serve_flow != null
		and _serve_flow.has_method("update")
		and _serve_flow.has_method("sync_current_input_state")
		and _ball_driver != null
		and _ball_driver.has_method("reset_ball")
		and _ball_driver.has_method("serve_ball")
		and _motion_stepper != null
		and _motion_stepper.has_method("step")
	)


func _sync_fixture_to_owner() -> void:
	_set_owner_value("ball_pos", _fixture_ball_position)
	_set_owner_value("ball_vel", _fixture_ball_velocity)
	_set_owner_value("ball_active", _fixture_ball_active)


func _owner_vector2(property_name: String, fallback: Vector2) -> Vector2:
	var value: Variant = _owner_value(property_name, fallback)
	return value as Vector2 if value is Vector2 else fallback


func _owner_value(property_name: String, fallback: Variant) -> Variant:
	if _owner == null or not _owner_properties.has(property_name):
		return fallback
	var value: Variant = _owner.get(property_name)
	return fallback if value == null else value


func _set_owner_value(property_name: String, value: Variant) -> void:
	if _owner != null and _owner_properties.has(property_name):
		_owner.set(property_name, value)


func _collect_property_names(target: Object) -> Dictionary:
	var result: Dictionary = {}
	if target == null:
		return result
	for property_variant in target.get_property_list():
		if property_variant is Dictionary:
			result[str((property_variant as Dictionary).get("name", ""))] = true
	return result


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null:
		return null
	for method_name in ["get_instance", "get_cached_instance"]:
		if not registry.has_method(method_name):
			continue
		var value: Variant = registry.call(method_name, key)
		if value is Object and value != null:
			return value as Object
	return null


func _vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value as Vector2 if value is Vector2 else fallback
