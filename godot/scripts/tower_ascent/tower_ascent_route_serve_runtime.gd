extends RefCounted

const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")
const BattleSceneOwnerReader := preload(
	"res://scripts/core/battle_scene_owner_reader.gd"
)
const PlayerCharacterRuntime := preload(
	"res://scripts/characters/player_character_runtime.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)
const TowerAscentRouteWindPolicy := preload(
	"res://scripts/tower_ascent/tower_ascent_route_wind_policy.gd"
)
const WeatherEventState := preload(
	"res://scripts/stages/common/weather_event_state.gd"
)

const STATUS_WAITING := "waiting"
const STATUS_FLIGHT := "flight"
const STATUS_MISS := "miss"
const STATUS_HIT := "hit"
# 코덱스 리뷰(8/23): 픽스처 비행이 구 522px/s 잔존 리터럴로 날면 생산
# 속도(더 긴 비행 = 제곱으로 커지는 바람 변위)를 재현하지 못한다. 항상
# 생산 튜닝에서 파생한다.
const DEBUG_SERVE_SPEED_PER_FRAME := (
	TowerAscentTuning.TEMP_ROUTE_AIM_SERVE_SPEED_PER_SECOND / 60.0
)

var _active := false
var _fixture_mode := false
var _owner: Object = null
var _registry: Object = null
var _game_audio: Object = null
var _round_state: Object = null
var _ball_driver: Object = null
var _motion_stepper: Object = null
var _paddle_bounce_state: Object = null
var _ball_physics: Object = null
var _input_reader: Object = null
var _movement_state: Object = null
var _player_control_context: Object = null
var _player_control_config_builder: Object = null
var _character_runtime: Object = PlayerCharacterRuntime.new()
var _character_type := PlayerCharacterRuntime.SMASHER
var _fixture_ball_position := Vector2.ZERO
var _fixture_ball_velocity := Vector2.ZERO
var _fixture_ball_active := false
var _serve_attempt_count := 0
var _aim_elapsed_seconds := 0.0
var _aim_angle_degrees := 0.0
var _aim_sweep_direction := 1.0
var _serve_arm_remaining := 0.0
var _wind_model: Dictionary = TowerAscentRouteWindPolicy.calm_model()
var _wind_visual_state: Object = WeatherEventState.new()


func begin(owner: Object, registry: Object, wind_model: Variant = {}) -> Dictionary:
	cancel()
	_wind_model = TowerAscentRouteWindPolicy.normalize_model(wind_model)
	_sync_wind_visual_profile()
	_update_aim_oscillator(0.0)
	_owner = owner
	_registry = registry
	_game_audio = _get_instance(registry, "game_audio")
	_fixture_mode = owner == null or not (owner is Node)
	_serve_attempt_count = 0
	_serve_arm_remaining = TowerAscentTuning.TEMP_ROUTE_AIM_ENTRY_ARM_SECONDS
	if _fixture_mode:
		_active = true
		return {"accepted": true, "reason": "test_fixture"}
	_round_state = _get_instance(registry, "round_flow_state")
	_ball_driver = _get_instance(registry, "battle_scene_ball_update_driver")
	_motion_stepper = _get_instance(registry, "ball_motion_stepper")
	_paddle_bounce_state = _get_instance(registry, "paddle_bounce_state")
	_ball_physics = _get_instance(registry, "ball_physics")
	_character_type = _character_runtime.normalize(_owner_value(
		"selected_character_type",
		PlayerCharacterRuntime.SMASHER
	))
	_input_reader = _get_instance(
		registry,
		_character_runtime.get_input_reader_key(_character_type)
	)
	_movement_state = _get_instance(registry, "player_movement_state")
	_player_control_context = _get_instance(registry, "battle_update_context")
	_player_control_config_builder = _get_instance(
		registry,
		"battle_scene_player_control_config_builder"
	)
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
	_game_audio = null
	_round_state = null
	_ball_driver = null
	_motion_stepper = null
	_paddle_bounce_state = null
	_ball_physics = null
	_input_reader = null
	_movement_state = null
	_player_control_context = null
	_player_control_config_builder = null
	_character_type = PlayerCharacterRuntime.SMASHER
	_fixture_ball_position = Vector2.ZERO
	_fixture_ball_velocity = Vector2.ZERO
	_fixture_ball_active = false
	_serve_arm_remaining = 0.0
	_wind_model = TowerAscentRouteWindPolicy.calm_model()
	_wind_visual_state.clear_presentation_wind()


func finish_selection() -> void:
	_hide_owned_ball()
	_active = false
	_wind_visual_state.clear_presentation_wind()


func update(
	delta: float,
	targets: Array[Dictionary],
	pickups: Array[Dictionary] = []
) -> Dictionary:
	if not _active:
		return {"status": STATUS_WAITING}
	_wind_visual_state.update_presentation_wind(maxf(0.0, delta))
	if _fixture_mode:
		return _update_fixture_flight(delta, targets, pickups)
	var input_snapshot := _read_player_input_snapshot()
	var safe_delta := maxf(0.0, delta)
	var serve_input_armed := _serve_arm_remaining <= 0.0
	_serve_arm_remaining = maxf(0.0, _serve_arm_remaining - safe_delta)
	_update_player_route_movement(safe_delta, input_snapshot)
	if bool(_round_state.is_waiting_for_serve()):
		# ROUTE_AIM is intentionally manual-only. The normal ServeFlowController
		# retains its three-second auto-serve for combat, but this selective flow
		# consumes the shared idempotent input snapshot and never advances that
		# timer (v1.7 section 3.2).
		_update_aim_oscillator(safe_delta)
		if (
			serve_input_armed
			and bool(input_snapshot.get("mouse_left_just_pressed", false))
		):
			_serve_live_ball()
		if bool(_round_state.is_waiting_for_serve()):
			return {"status": STATUS_WAITING}
	if not bool(_owner_value("ball_active", false)):
		_prepare_next_serve()
		return {"status": STATUS_MISS}
	return _advance_live_ball(delta, targets, pickups)


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


func get_wind_model() -> Dictionary:
	return _wind_model.duplicate(true)


func get_wind_visual_state() -> Object:
	return _wind_visual_state


func get_wind_visual_snapshot() -> Dictionary:
	return _wind_visual_state.get_presentation_wind_snapshot()


func has_visible_wind_indicator() -> bool:
	return TowerAscentRouteWindPolicy.is_indicator_visible(_wind_model)


func get_aim_gauge_model() -> Dictionary:
	var waiting := _active and not is_ball_in_flight()
	if not _fixture_mode and _round_state != null:
		waiting = waiting and bool(_round_state.is_waiting_for_serve())
	var player_pos := _owner_vector2(
		"player_pos",
		Vector2(
			BattleSceneConfig.WIDTH * 0.5 - 77.5,
			BattleSceneConfig.HEIGHT - 50.0
		)
	)
	var paddle_width := maxf(1.0, float(_owner_value("player_paddle_width", 155.0)))
	var effective_bounds := _effective_aim_bounds()
	return {
		"visible": waiting,
		"origin": Vector2(
			player_pos.x + paddle_width * 0.5,
			player_pos.y - TowerAscentTuning.TEMP_ROUTE_AIM_GAUGE_PLAYER_GAP
		),
		"angle_degrees": _aim_angle_degrees,
		"sweep_direction": _aim_sweep_direction,
		"min_degrees": effective_bounds.x,
		"max_degrees": effective_bounds.y,
		"wind_bias_degrees": float(_wind_model.get("bias_degrees", 0.0)),
	}


func _serve_live_ball() -> void:
	_ball_driver.serve_ball(_owner, _registry)
	if bool(_owner_value("ball_active", false)):
		var angle_radians := deg_to_rad(_aim_angle_degrees)
		var direction := Vector2(sin(angle_radians), -cos(angle_radians)).normalized()
		_set_owner_value(
			"ball_vel",
			direction * (
				TowerAscentTuning.TEMP_ROUTE_AIM_SERVE_SPEED_PER_SECOND / 60.0
			)
		)
		_serve_attempt_count += 1


func _update_aim_oscillator(delta: float) -> void:
	var period := maxf(0.1, TowerAscentTuning.TEMP_ROUTE_AIM_SWEEP_PERIOD_SECONDS)
	_aim_elapsed_seconds = fposmod(_aim_elapsed_seconds + delta, period)
	var phase := _aim_elapsed_seconds / period * TAU
	var effective_bounds := _effective_aim_bounds()
	var midpoint := (effective_bounds.x + effective_bounds.y) * 0.5
	var amplitude := (effective_bounds.y - effective_bounds.x) * 0.5
	_aim_angle_degrees = midpoint + sin(phase) * amplitude
	_aim_sweep_direction = 1.0 if cos(phase) >= 0.0 else -1.0


func _wind_flight_accel_per_frame() -> float:
	var strength := int(_wind_model.get("strength_level", 0))
	if strength <= 0:
		return 0.0
	return (
		float(_wind_model.get("direction", 0))
		* float(strength)
		* TowerAscentTuning.TEMP_ROUTE_WIND_FLIGHT_FORCE_PER_FRAME
	)


func _effective_aim_bounds() -> Vector2:
	var bias_degrees := float(_wind_model.get("bias_degrees", 0.0))
	return Vector2(
		TowerAscentTuning.TEMP_ROUTE_AIM_MIN_DEGREES + bias_degrees,
		TowerAscentTuning.TEMP_ROUTE_AIM_MAX_DEGREES + bias_degrees
	)


func _sync_wind_visual_profile() -> void:
	if not TowerAscentRouteWindPolicy.is_indicator_visible(_wind_model):
		_wind_visual_state.clear_presentation_wind()
		return
	_wind_visual_state.configure_presentation_wind(
		int(_wind_model.get("direction", 0)),
		int(_wind_model.get("strength_level", 0))
	)


func _read_player_input_snapshot() -> Dictionary:
	if _input_reader == null or not _input_reader.has_method("get_snapshot"):
		return {}
	var value: Variant = _input_reader.call("get_snapshot")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _update_player_route_movement(delta: float, input_snapshot: Dictionary) -> void:
	var config_value: Variant = _player_control_config_builder.call(
		"build_config",
		_owner,
		_registry,
		_character_type,
		_player_control_context
	)
	var config: Dictionary = config_value if config_value is Dictionary else {}
	var player_pos := _owner_vector2("player_pos", Vector2.ZERO)
	var movement_value: Variant = _movement_state.call(
		"update_horizontal",
		delta,
		player_pos,
		float(_owner_value("player_speed", 0.0)),
		float(input_snapshot.get("direction", 0.0)),
		float(config.get("play_left", 0.0)),
		float(config.get("play_right", BattleSceneConfig.WIDTH)),
		maxf(1.0, float(config.get(
			"paddle_width",
			_owner_value("player_paddle_width", 155.0)
		))),
		config
	)
	if not (movement_value is Dictionary):
		return
	var movement := movement_value as Dictionary
	var next_pos: Variant = movement.get("player_pos", player_pos)
	if next_pos is Vector2:
		_set_owner_value("player_pos", next_pos)
	_set_owner_value(
		"player_speed",
		float(movement.get("player_speed", _owner_value("player_speed", 0.0)))
	)
	_set_owner_value(
		"gameplay_frame_counter",
		int(_owner_value("gameplay_frame_counter", 0)) + 1
	)


func _advance_live_ball(
	delta: float,
	targets: Array[Dictionary],
	pickups: Array[Dictionary]
) -> Dictionary:
	var previous := _owner_vector2("ball_pos", Vector2.ZERO)
	var velocity := _owner_vector2("ball_vel", Vector2.ZERO)
	# 피드백2 6항: wind exerts a real lateral force on the flying route ball
	# (2026-08-21 bias-only ruling reversed). The aim-window bias stays, so the
	# arrow still points at the true launch direction and upwind compensation
	# angles remain reachable.
	var wind_accel := _wind_flight_accel_per_frame()
	if wind_accel != 0.0 and velocity != Vector2.ZERO:
		velocity.x += wind_accel * maxf(0.0, delta) * 60.0
		_set_owner_value("ball_vel", velocity)
	var impact_boost := maxf(0.0, float(_owner_value("ball_impact_boost", 1.0)))
	var movement := velocity * impact_boost * maxf(0.0, delta) * 60.0
	var step_result: Dictionary = _motion_stepper.step(
		previous,
		movement,
		velocity,
		_build_route_motion_context()
	)
	var current := _vector2(step_result.get("ball_pos", previous), previous)
	var pickup_ids := _find_hit_pickup_ids(previous, current, _ball_radius(), pickups)
	var target_id := _find_hit_target(previous, current, _ball_radius(), targets)
	if not target_id.is_empty():
		_set_owner_value("ball_pos", current)
		_hide_owned_ball()
		return {"status": STATUS_HIT, "target_id": target_id, "pickup_ids": pickup_ids}
	match str(step_result.get("event", "none")):
		"wall":
			var side := str(step_result.get("side", ""))
			var impact_speed := velocity.length()
			velocity.x = absf(velocity.x) if side == "left" else -absf(velocity.x)
			velocity = _normalize_route_bounce_velocity(velocity)
			_set_owner_value("ball_pos", current)
			_set_owner_value("ball_vel", velocity)
			var impact_position := _vector2(
				step_result.get("impact_pos", current),
				current
			)
			_play_route_wall_hit(impact_speed, impact_position.x)
			return {"status": STATUS_FLIGHT, "pickup_ids": pickup_ids}
		"player_paddle":
			_set_owner_value("ball_pos", current)
			var resolved_velocity := _resolve_player_paddle_bounce(
				current,
				velocity,
				float(step_result.get("paddle_x", 0.0)),
				maxf(1.0, float(step_result.get("paddle_w", 155.0)))
			)
			_set_owner_value(
				"ball_vel",
				_normalize_route_bounce_velocity(resolved_velocity)
			)
			return {"status": STATUS_FLIGHT, "pickup_ids": pickup_ids}
		"player_scored":
			var impact_speed := velocity.length()
			current.y = _ball_radius()
			velocity.y = absf(velocity.y)
			velocity = _normalize_route_bounce_velocity(velocity)
			_set_owner_value("ball_pos", current)
			_set_owner_value("ball_vel", velocity)
			_play_route_wall_hit(impact_speed, current.x)
			return {"status": STATUS_FLIGHT, "pickup_ids": pickup_ids}
		"boss_scored":
			_prepare_next_serve()
			return {"status": STATUS_MISS, "pickup_ids": pickup_ids}
	_set_owner_value("ball_pos", current)
	return {"status": STATUS_FLIGHT, "pickup_ids": pickup_ids}


func _update_fixture_flight(
	delta: float,
	targets: Array[Dictionary],
	pickups: Array[Dictionary]
) -> Dictionary:
	if not _fixture_ball_active:
		return {"status": STATUS_WAITING}
	var previous := _fixture_ball_position
	# The fixture flight must feel the same wind force as the live path, or
	# fixture-driven seals silently stop covering the production trajectory.
	var wind_accel := _wind_flight_accel_per_frame()
	if wind_accel != 0.0 and _fixture_ball_velocity != Vector2.ZERO:
		_fixture_ball_velocity.x += wind_accel * maxf(0.0, delta) * 60.0
	_fixture_ball_position += _fixture_ball_velocity * maxf(0.0, delta) * 60.0
	var pickup_ids := _find_hit_pickup_ids(
		previous,
		_fixture_ball_position,
		_ball_radius(),
		pickups
	)
	var target_id := _find_hit_target(previous, _fixture_ball_position, _ball_radius(), targets)
	if not target_id.is_empty():
		_fixture_ball_active = false
		_sync_fixture_to_owner()
		return {"status": STATUS_HIT, "target_id": target_id, "pickup_ids": pickup_ids}
	if _fixture_ball_position.y < _ball_radius():
		var impact_speed := _fixture_ball_velocity.length()
		_fixture_ball_position.y = _ball_radius()
		_fixture_ball_velocity.y = absf(_fixture_ball_velocity.y)
		_fixture_ball_velocity = _normalize_route_bounce_velocity(
			_fixture_ball_velocity
		)
		_sync_fixture_to_owner()
		_play_route_wall_hit(impact_speed, _fixture_ball_position.x)
		return {"status": STATUS_FLIGHT, "pickup_ids": pickup_ids}
	if _fixture_ball_position.y > BattleSceneConfig.HEIGHT:
		_fixture_ball_active = false
		_fixture_ball_position = Vector2(BattleSceneConfig.WIDTH * 0.5, BattleSceneConfig.HEIGHT - 85.0)
		_fixture_ball_velocity = Vector2.ZERO
		_sync_fixture_to_owner()
		return {"status": STATUS_MISS, "pickup_ids": pickup_ids}
	_sync_fixture_to_owner()
	return {"status": STATUS_FLIGHT, "pickup_ids": pickup_ids}


func _prepare_next_serve() -> void:
	_round_state.set_player_serves(true)
	_round_state.reset_round_wait()
	_ball_driver.reset_ball(_owner, _registry)


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


func _find_hit_pickup_ids(
	segment_start: Vector2,
	segment_end: Vector2,
	ball_radius: float,
	pickups: Array[Dictionary]
) -> Array[String]:
	var result: Array[String] = []
	for pickup in pickups:
		if bool(pickup.get("consumed", false)):
			continue
		var pickup_id := str(pickup.get("id", ""))
		var pickup_position := _vector2(
			pickup.get("position", Vector2.ZERO),
			Vector2.ZERO
		)
		var hit_radius := maxf(0.0, float(pickup.get("hit_radius", 0.0))) + ball_radius
		if (
			not pickup_id.is_empty()
			and hit_radius > 0.0
			and _distance_to_segment(pickup_position, segment_start, segment_end) <= hit_radius
		):
			result.append(pickup_id)
	return result


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
		"player_pos": _owner_vector2("player_pos", Vector2.ZERO),
		"player_paddle_size": Vector2(
			maxf(1.0, float(_owner_value("player_paddle_width", 155.0))),
			maxf(1.0, float(_owner_value("player_paddle_height", 50.0)))
		),
		"player_guard_available": true,
		"boss_pos": Vector2(-1000.0, -1000.0),
		"boss_paddle_size": Vector2.ZERO,
	}


func _resolve_player_paddle_bounce(
	ball_position: Vector2,
	ball_velocity: Vector2,
	paddle_x: float,
	paddle_width: float
) -> Vector2:
	var paddle_center_x := paddle_x + paddle_width * 0.5
	var hit_position := clampf(
		(ball_position.x - paddle_center_x) / maxf(0.5, paddle_width * 0.5),
		-1.0,
		1.0
	)
	var incoming_speed := ball_velocity.length()
	var minimum_speed := (
		TowerAscentTuning.TEMP_ROUTE_AIM_SERVE_SPEED_PER_SECOND / 60.0
	)
	var bounce_result: Dictionary = _paddle_bounce_state.resolve_velocity(
		ball_velocity,
		hit_position,
		true,
		ball_velocity.x,
		-1.0,
		float(_paddle_bounce_state.get_initial_speed(ball_velocity)),
		deg_to_rad(hit_position * 60.0),
		false,
		1.0,
		0,
		_ball_physics,
		null,
		0.0,
		0.0,
		minimum_speed,
		maxf(minimum_speed, incoming_speed)
	)
	var resolved := _vector2(bounce_result.get("ball_vel", ball_velocity), ball_velocity)
	if resolved.y >= 0.0:
		resolved.y = -maxf(minimum_speed, absf(ball_velocity.y))
	var resolved_speed := resolved.length()
	if incoming_speed > 0.0001 and resolved_speed > incoming_speed:
		resolved *= incoming_speed / resolved_speed
	return resolved


func _normalize_route_bounce_velocity(velocity: Vector2) -> Vector2:
	if velocity == Vector2.ZERO:
		return velocity
	return velocity.normalized() * (
		TowerAscentTuning.TEMP_ROUTE_AIM_SERVE_SPEED_PER_SECOND / 60.0
	)


func _play_route_wall_hit(impact_speed: float, source_x: float) -> void:
	if _game_audio != null and _game_audio.has_method("play_wall_hit"):
		_game_audio.play_wall_hit(impact_speed, source_x)


func _ball_radius() -> float:
	return maxf(2.0, float(_owner_value("ball_size", 28.6)) * 0.5)


func _has_production_contract() -> bool:
	return (
		_round_state != null
		and _round_state.has_method("is_waiting_for_serve")
		and _round_state.has_method("set_player_serves")
		and _round_state.has_method("reset_round_wait")
		and _ball_driver != null
		and _ball_driver.has_method("reset_ball")
		and _ball_driver.has_method("serve_ball")
		and _motion_stepper != null
		and _motion_stepper.has_method("step")
		and _paddle_bounce_state != null
		and _paddle_bounce_state.has_method("get_initial_speed")
		and _paddle_bounce_state.has_method("resolve_velocity")
		and _ball_physics != null
		and _input_reader != null
		and _input_reader.has_method("get_snapshot")
		and _movement_state != null
		and _movement_state.has_method("update_horizontal")
		and _player_control_context != null
		and _player_control_context.has_method("build_player_control_config")
		and _player_control_config_builder != null
		and _player_control_config_builder.has_method("build_config")
	)


func _sync_fixture_to_owner() -> void:
	_set_owner_value("ball_pos", _fixture_ball_position)
	_set_owner_value("ball_vel", _fixture_ball_velocity)
	_set_owner_value("ball_active", _fixture_ball_active)


func _owner_vector2(property_name: String, fallback: Vector2) -> Vector2:
	return BattleSceneOwnerReader.get_vector2(_owner, property_name, fallback)


func _owner_value(property_name: String, fallback: Variant) -> Variant:
	return BattleSceneOwnerReader.get_value(_owner, property_name, fallback)


func _set_owner_value(property_name: String, value: Variant) -> void:
	if _owner != null:
		_owner.set(property_name, value)


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
