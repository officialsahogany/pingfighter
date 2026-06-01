extends RefCounted

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const BALL_RADIUS_FALLBACK := 14.3
const COMPANION_RADIUS := 16.0
const COMPANION_HIT_HALF_HEIGHT := 22.0
const COMPANION_PATROL_SPEED := 120.0
const COMPANION_PATROL_EDGE_MARGIN := 42.0
const COMPANION_PATROL_LANE_Y_OFFSET := 0.5
const COMPANION_PATROL_PAUSE_MIN := 0.4
const COMPANION_PATROL_PAUSE_MAX := 1.2
const COMPANION_PATROL_CHANGE_INTERVAL_MIN := 0.45
const COMPANION_PATROL_CHANGE_INTERVAL_MAX := 1.40
const COMPANION_PATROL_SURPRISE_CHANCE_PER_SECOND := 0.30
const COMPANION_PATROL_SEED_MOD := 2147483647
const COMPANION_DEFENSE_DECISION_INTERVAL_MIN := 0.55
const COMPANION_DEFENSE_DECISION_INTERVAL_MAX := 0.95
const COMPANION_DEFENSE_LOOKAHEAD_MAX_GAP := 320.0
const COMPANION_DEFENSE_INTERCEPT_SPEED := 155.0
const COMPANION_DEFENSE_TARGET_TOLERANCE := 8.0
const MOTION_STYLE_PATROL := "patrol"
const MOTION_STYLE_FREE_FLIGHT := "free_flight"
const FREE_FLIGHT_MARGIN_X := 96.0
const FREE_FLIGHT_MARGIN_Y := 72.0
const FREE_FLIGHT_INSIDE_MARGIN_X := 42.0
const FREE_FLIGHT_INSIDE_MARGIN_Y := 70.0
const FREE_FLIGHT_TARGET_TOLERANCE := 12.0
const FREE_FLIGHT_TARGET_INTERVAL_MIN := 0.55
const FREE_FLIGHT_TARGET_INTERVAL_MAX := 1.65
const FREE_FLIGHT_EXIT_CHANCE := 0.28

var pos := Vector2.ZERO
var motion_style := MOTION_STYLE_PATROL
var free_flight_target := Vector2.ZERO
var patrol_dir := 0.0
var patrol_pause := 0.0
var patrol_change_timer := 0.0
var patrol_seed := 0
var patrol_speed := 0.0
var patrol_lane_y := 0.0
var patrol_min_x := 0.0
var patrol_max_x := 0.0
var defense_decision_timer := 0.0
var defense_intercept_active := false
var defense_intercept_target_x := 0.0
var defense_last_roll := 1.0


func reset() -> void:
	pos = Vector2.ZERO
	motion_style = MOTION_STYLE_PATROL
	free_flight_target = Vector2.ZERO
	patrol_dir = 0.0
	patrol_pause = 0.0
	patrol_change_timer = 0.0
	patrol_seed = 0
	patrol_speed = 0.0
	patrol_lane_y = 0.0
	patrol_min_x = 0.0
	patrol_max_x = 0.0
	reset_defense()


func reset_defense() -> void:
	defense_decision_timer = 0.0
	defense_last_roll = 1.0
	clear_defense_intercept()


func clear_defense_intercept() -> void:
	defense_intercept_active = false
	defense_intercept_target_x = 0.0


func _normalize_motion_style(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	return MOTION_STYLE_FREE_FLIGHT if normalized == MOTION_STYLE_FREE_FLIGHT else MOTION_STYLE_PATROL


func _get_vector2_from_variant(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Dictionary:
		var data := value as Dictionary
		return Vector2(float(data.get("x", fallback.x)), float(data.get("y", fallback.y)))
	return fallback


func update(
	delta: float,
	owner: Object,
	freeze_motion: bool,
	defense_rate: float,
	trigger_count: int,
	speed_min: float,
	speed_max: float,
	motion_style_value: String = MOTION_STYLE_PATROL
) -> void:
	motion_style = _normalize_motion_style(motion_style_value)
	if motion_style == MOTION_STYLE_FREE_FLIGHT:
		_update_free_flight(delta, owner, freeze_motion, trigger_count, speed_min, speed_max)
		return
	if patrol_seed <= 0 or patrol_min_x <= 0.0 or patrol_max_x <= patrol_min_x:
		initialize(owner, pos == Vector2.ZERO, trigger_count, speed_min, speed_max, motion_style)
	else:
		sync_lane(owner)
	if pos == Vector2.ZERO:
		initialize(owner, true, trigger_count, speed_min, speed_max, motion_style)
		return

	var safe_delta: float = maxf(0.0, delta)
	pos.y = patrol_lane_y
	if freeze_motion:
		clear_defense_intercept()
		return
	if safe_delta <= 0.0:
		return
	if _try_update_defense_intercept(safe_delta, owner, defense_rate, speed_min):
		return
	if patrol_pause > 0.0:
		patrol_pause = maxf(0.0, patrol_pause - safe_delta)
		return

	patrol_change_timer = maxf(0.0, patrol_change_timer - safe_delta)
	var next_x: float = pos.x + patrol_dir * patrol_speed * safe_delta
	if next_x <= patrol_min_x:
		pos.x = patrol_min_x
		patrol_dir = 1.0
		patrol_pause = _next_range(COMPANION_PATROL_PAUSE_MIN, COMPANION_PATROL_PAUSE_MAX)
		patrol_speed = _next_speed(speed_min, speed_max)
		patrol_change_timer = _next_range(COMPANION_PATROL_CHANGE_INTERVAL_MIN, COMPANION_PATROL_CHANGE_INTERVAL_MAX)
	elif next_x >= patrol_max_x:
		pos.x = patrol_max_x
		patrol_dir = -1.0
		patrol_pause = _next_range(COMPANION_PATROL_PAUSE_MIN, COMPANION_PATROL_PAUSE_MAX)
		patrol_speed = _next_speed(speed_min, speed_max)
		patrol_change_timer = _next_range(COMPANION_PATROL_CHANGE_INTERVAL_MIN, COMPANION_PATROL_CHANGE_INTERVAL_MAX)
	else:
		pos.x = next_x
		var surprise_chance: float = 1.0 - pow(1.0 - COMPANION_PATROL_SURPRISE_CHANCE_PER_SECOND, safe_delta)
		if _next_unit() < surprise_chance:
			patrol_dir *= -1.0
			patrol_pause = _next_range(COMPANION_PATROL_PAUSE_MIN, COMPANION_PATROL_PAUSE_MAX)
			patrol_speed = _next_speed(speed_min, speed_max)
			patrol_change_timer = _next_range(COMPANION_PATROL_CHANGE_INTERVAL_MIN, COMPANION_PATROL_CHANGE_INTERVAL_MAX)
		elif patrol_change_timer <= 0.0:
			_choose_next_action(speed_min, speed_max)


func initialize(
	owner: Object,
	randomize_x: bool,
	trigger_count: int,
	speed_min: float,
	speed_max: float,
	motion_style_value: String = MOTION_STYLE_PATROL
) -> void:
	motion_style = _normalize_motion_style(motion_style_value)
	if motion_style == MOTION_STYLE_FREE_FLIGHT:
		_initialize_free_flight(owner, randomize_x, trigger_count, speed_min, speed_max)
		return
	sync_lane(owner)
	if patrol_seed <= 0:
		patrol_seed = _build_seed(owner, trigger_count)
	if randomize_x or pos == Vector2.ZERO:
		pos = Vector2(
			_next_range(patrol_min_x, patrol_max_x),
			patrol_lane_y
		)
	else:
		pos = Vector2(
			clampf(pos.x, patrol_min_x, patrol_max_x),
			patrol_lane_y
		)
	if is_zero_approx(patrol_dir):
		patrol_dir = -1.0 if _next_unit() < 0.5 else 1.0
	patrol_speed = clampf(
		patrol_speed if patrol_speed > 0.0 else _next_speed(speed_min, speed_max),
		speed_min,
		speed_max
	)
	patrol_pause = maxf(0.0, patrol_pause)
	if patrol_change_timer <= 0.0:
		patrol_change_timer = _next_range(COMPANION_PATROL_CHANGE_INTERVAL_MIN, COMPANION_PATROL_CHANGE_INTERVAL_MAX)


func sync_lane(owner: Object) -> void:
	var lane: Dictionary = _resolve_lane(owner)
	patrol_lane_y = float(lane.get("y", FIELD_HEIGHT - 50.0))
	patrol_min_x = float(lane.get("min_x", COMPANION_PATROL_EDGE_MARGIN))
	patrol_max_x = float(lane.get("max_x", FIELD_WIDTH - COMPANION_PATROL_EDGE_MARGIN))
	if pos != Vector2.ZERO:
		pos.x = clampf(pos.x, patrol_min_x, patrol_max_x)
		pos.y = patrol_lane_y


func restore(
	snapshot: Dictionary,
	speed_min: float,
	speed_max: float,
	motion_style_value: String = MOTION_STYLE_PATROL
) -> void:
	motion_style = _normalize_motion_style(motion_style_value)
	free_flight_target = _get_vector2_from_variant(
		snapshot.get("companion_free_flight_target", free_flight_target),
		free_flight_target
	)
	var restored_dir: float = float(snapshot.get("companion_patrol_dir", patrol_dir))
	if restored_dir > 0.0:
		patrol_dir = 1.0
	elif restored_dir < 0.0:
		patrol_dir = -1.0
	else:
		patrol_dir = 0.0
	if is_zero_approx(patrol_dir):
		patrol_dir = 1.0
	patrol_pause = maxf(0.0, float(snapshot.get("companion_patrol_pause", 0.0)))
	patrol_change_timer = maxf(0.0, float(snapshot.get("companion_patrol_change_timer", 0.0)))
	patrol_seed = maxi(0, int(snapshot.get("companion_patrol_seed", 0)))
	patrol_speed = clampf(
		float(snapshot.get("companion_patrol_speed", COMPANION_PATROL_SPEED)),
		speed_min,
		speed_max
	)
	patrol_lane_y = float(snapshot.get("companion_patrol_lane_y", patrol_lane_y))


func get_snapshot(speed_default: float, speed_min: float, speed_max: float, defense_rate: float) -> Dictionary:
	return {
		"companion_motion_style": motion_style,
		"companion_free_flight_target": free_flight_target,
		"companion_patrol_dir": patrol_dir,
		"companion_patrol_pause": patrol_pause,
		"companion_patrol_change_timer": patrol_change_timer,
		"companion_patrol_seed": patrol_seed,
		"companion_patrol_speed": patrol_speed,
		"companion_patrol_speed_default": speed_default,
		"companion_patrol_speed_min": speed_min,
		"companion_patrol_speed_max": speed_max,
		"companion_patrol_lane_y": patrol_lane_y,
		"companion_patrol_min_x": patrol_min_x,
		"companion_patrol_max_x": patrol_max_x,
		"companion_defense_rate": defense_rate,
		"companion_defense_intercept_active": defense_intercept_active,
		"companion_defense_intercept_target_x": defense_intercept_target_x,
		"companion_defense_decision_timer": defense_decision_timer,
		"companion_defense_last_roll": defense_last_roll,
	}


func get_save_snapshot() -> Dictionary:
	return {
		"companion_motion_style": motion_style,
		"companion_free_flight_target": free_flight_target,
		"companion_patrol_dir": patrol_dir,
		"companion_patrol_pause": patrol_pause,
		"companion_patrol_change_timer": patrol_change_timer,
		"companion_patrol_seed": patrol_seed,
		"companion_patrol_speed": patrol_speed,
		"companion_patrol_lane_y": patrol_lane_y,
	}


func configure_for_tests(test_pos: Vector2, test_seed: int, test_decision_timer: float, test_intercept_active: bool) -> void:
	pos = test_pos
	patrol_seed = test_seed
	defense_decision_timer = maxf(0.0, test_decision_timer)
	defense_intercept_active = test_intercept_active


func _update_free_flight(
	delta: float,
	owner: Object,
	freeze_motion: bool,
	trigger_count: int,
	speed_min: float,
	speed_max: float
) -> void:
	if patrol_seed <= 0 or patrol_max_x <= patrol_min_x:
		_initialize_free_flight(owner, pos == Vector2.ZERO, trigger_count, speed_min, speed_max)
	else:
		_sync_free_flight_bounds()
	if pos == Vector2.ZERO:
		_initialize_free_flight(owner, true, trigger_count, speed_min, speed_max)
		return

	var safe_delta: float = maxf(0.0, delta)
	clear_defense_intercept()
	if freeze_motion or safe_delta <= 0.0:
		return
	patrol_change_timer = maxf(0.0, patrol_change_timer - safe_delta)
	if (
		free_flight_target == Vector2.ZERO
		or patrol_change_timer <= 0.0
		or pos.distance_to(free_flight_target) <= FREE_FLIGHT_TARGET_TOLERANCE
	):
		_choose_free_flight_target(speed_min, speed_max)

	var offset := free_flight_target - pos
	var distance := offset.length()
	if distance > 0.01:
		var step := minf(distance, patrol_speed * safe_delta)
		pos += offset / distance * step
		if absf(offset.x) > 1.0:
			patrol_dir = 1.0 if offset.x > 0.0 else -1.0
	pos.x = clampf(pos.x, patrol_min_x, patrol_max_x)
	pos.y = clampf(pos.y, -FREE_FLIGHT_MARGIN_Y, FIELD_HEIGHT + FREE_FLIGHT_MARGIN_Y)


func _initialize_free_flight(
	owner: Object,
	randomize_pos: bool,
	trigger_count: int,
	speed_min: float,
	speed_max: float
) -> void:
	_sync_free_flight_bounds()
	if patrol_seed <= 0:
		patrol_seed = _build_seed(owner, trigger_count)
	if randomize_pos or pos == Vector2.ZERO:
		pos = Vector2(
			_next_range(FREE_FLIGHT_INSIDE_MARGIN_X, FIELD_WIDTH - FREE_FLIGHT_INSIDE_MARGIN_X),
			_next_range(FREE_FLIGHT_INSIDE_MARGIN_Y, FIELD_HEIGHT - FREE_FLIGHT_INSIDE_MARGIN_Y)
		)
	else:
		pos = Vector2(
			clampf(pos.x, patrol_min_x, patrol_max_x),
			clampf(pos.y, -FREE_FLIGHT_MARGIN_Y, FIELD_HEIGHT + FREE_FLIGHT_MARGIN_Y)
		)
	if is_zero_approx(patrol_dir):
		patrol_dir = -1.0 if _next_unit() < 0.5 else 1.0
	patrol_speed = clampf(
		patrol_speed if patrol_speed > 0.0 else _next_speed(speed_min, speed_max),
		speed_min,
		speed_max
	)
	if patrol_change_timer <= 0.0 or free_flight_target == Vector2.ZERO:
		_choose_free_flight_target(speed_min, speed_max)


func _sync_free_flight_bounds() -> void:
	patrol_lane_y = FIELD_HEIGHT * 0.5
	patrol_min_x = -FREE_FLIGHT_MARGIN_X
	patrol_max_x = FIELD_WIDTH + FREE_FLIGHT_MARGIN_X


func _choose_free_flight_target(speed_min: float, speed_max: float) -> void:
	patrol_speed = _next_speed(speed_min, speed_max)
	patrol_pause = 0.0
	patrol_change_timer = _next_range(FREE_FLIGHT_TARGET_INTERVAL_MIN, FREE_FLIGHT_TARGET_INTERVAL_MAX)
	if _next_unit() < FREE_FLIGHT_EXIT_CHANCE:
		var side_roll := _next_unit()
		if side_roll < 0.25:
			free_flight_target = Vector2(
				-FREE_FLIGHT_MARGIN_X,
				_next_range(-FREE_FLIGHT_MARGIN_Y, FIELD_HEIGHT + FREE_FLIGHT_MARGIN_Y)
			)
		elif side_roll < 0.50:
			free_flight_target = Vector2(
				FIELD_WIDTH + FREE_FLIGHT_MARGIN_X,
				_next_range(-FREE_FLIGHT_MARGIN_Y, FIELD_HEIGHT + FREE_FLIGHT_MARGIN_Y)
			)
		elif side_roll < 0.75:
			free_flight_target = Vector2(
				_next_range(-FREE_FLIGHT_MARGIN_X, FIELD_WIDTH + FREE_FLIGHT_MARGIN_X),
				-FREE_FLIGHT_MARGIN_Y
			)
		else:
			free_flight_target = Vector2(
				_next_range(-FREE_FLIGHT_MARGIN_X, FIELD_WIDTH + FREE_FLIGHT_MARGIN_X),
				FIELD_HEIGHT + FREE_FLIGHT_MARGIN_Y
			)
		return
	free_flight_target = Vector2(
		_next_range(FREE_FLIGHT_INSIDE_MARGIN_X, FIELD_WIDTH - FREE_FLIGHT_INSIDE_MARGIN_X),
		_next_range(FREE_FLIGHT_INSIDE_MARGIN_Y, FIELD_HEIGHT - FREE_FLIGHT_INSIDE_MARGIN_Y)
	)


func _try_update_defense_intercept(delta: float, owner: Object, defense_rate: float, speed_min: float) -> bool:
	if defense_rate <= 0.0:
		clear_defense_intercept()
		return false
	if not bool(_get_owner_value(owner, "ball_active", false)):
		clear_defense_intercept()
		defense_decision_timer = 0.0
		return false
	var ball_vel: Vector2 = _get_owner_vector2(owner, "ball_vel", Vector2.ZERO)
	if ball_vel.y <= 0.0:
		clear_defense_intercept()
		defense_decision_timer = 0.0
		return false
	var ball_pos: Vector2 = _get_owner_vector2(owner, "ball_pos", Vector2.ZERO)
	var ball_radius: float = maxf(1.0, float(_get_owner_value(owner, "ball_size", BALL_RADIUS_FALLBACK * 2.0)) * 0.5)
	var vertical_gap: float = (patrol_lane_y - COMPANION_HIT_HALF_HEIGHT) - (ball_pos.y + ball_radius)
	if vertical_gap < 0.0:
		clear_defense_intercept()
		return false
	if defense_intercept_active:
		return _advance_defense_intercept(delta, speed_min)
	defense_decision_timer = maxf(0.0, defense_decision_timer - delta)
	if defense_decision_timer > 0.0 or vertical_gap > COMPANION_DEFENSE_LOOKAHEAD_MAX_GAP:
		return false
	defense_decision_timer = _next_range(
		COMPANION_DEFENSE_DECISION_INTERVAL_MIN,
		COMPANION_DEFENSE_DECISION_INTERVAL_MAX
	)
	defense_last_roll = _next_unit()
	if defense_last_roll >= defense_rate:
		return false
	var impact_boost: float = maxf(0.01, float(_get_owner_value(owner, "ball_impact_boost", 1.0)))
	var frames_to_contact: float = vertical_gap / maxf(0.01, ball_vel.y * impact_boost)
	var future_ball_x: float = ball_pos.x + ball_vel.x * impact_boost * frames_to_contact
	defense_intercept_target_x = clampf(future_ball_x, patrol_min_x, patrol_max_x)
	defense_intercept_active = true
	patrol_pause = 0.0
	return _advance_defense_intercept(delta, speed_min)


func _advance_defense_intercept(delta: float, speed_min: float) -> bool:
	var target_x: float = clampf(defense_intercept_target_x, patrol_min_x, patrol_max_x)
	var distance: float = target_x - pos.x
	if absf(distance) <= COMPANION_DEFENSE_TARGET_TOLERANCE:
		pos.x = target_x
		patrol_dir = 0.0
		return true
	patrol_dir = 1.0 if distance > 0.0 else -1.0
	patrol_speed = clampf(COMPANION_DEFENSE_INTERCEPT_SPEED, speed_min, COMPANION_DEFENSE_INTERCEPT_SPEED)
	pos.x = move_toward(pos.x, target_x, COMPANION_DEFENSE_INTERCEPT_SPEED * maxf(0.0, delta))
	pos.x = clampf(pos.x, patrol_min_x, patrol_max_x)
	return true


func _resolve_lane(owner: Object) -> Dictionary:
	var player_pos: Vector2 = _get_owner_vector2(owner, "player_pos", Vector2(FIELD_WIDTH * 0.5 - 77.5, FIELD_HEIGHT - 50.0))
	var player_size := Vector2(
		maxf(1.0, float(_get_owner_value(owner, "player_paddle_width", 155.0))),
		maxf(1.0, float(_get_owner_value(owner, "player_paddle_height", 50.0)))
	)
	var lane_y: float = player_pos.y + player_size.y * COMPANION_PATROL_LANE_Y_OFFSET
	var min_x: float = maxf(COMPANION_PATROL_EDGE_MARGIN, COMPANION_RADIUS + 10.0)
	var max_x: float = minf(FIELD_WIDTH - COMPANION_PATROL_EDGE_MARGIN, FIELD_WIDTH - COMPANION_RADIUS - 10.0)
	return {
		"y": clampf(lane_y, COMPANION_RADIUS + 20.0, FIELD_HEIGHT - COMPANION_RADIUS - 20.0),
		"min_x": min_x,
		"max_x": max_x,
	}


func _choose_next_action(speed_min: float, speed_max: float) -> void:
	var roll: float = _next_unit()
	if roll < 0.30:
		patrol_pause = _next_range(COMPANION_PATROL_PAUSE_MIN, COMPANION_PATROL_PAUSE_MAX)
	elif roll < 0.65:
		patrol_dir *= -1.0
		patrol_pause = _next_range(COMPANION_PATROL_PAUSE_MIN, COMPANION_PATROL_PAUSE_MAX)
	elif roll < 0.82:
		patrol_dir *= -1.0
	patrol_speed = _next_speed(speed_min, speed_max)
	patrol_change_timer = _next_range(COMPANION_PATROL_CHANGE_INTERVAL_MIN, COMPANION_PATROL_CHANGE_INTERVAL_MAX)


func _next_range(min_value: float, max_value: float) -> float:
	var unit: float = _next_unit()
	return lerpf(min_value, max_value, unit)


func _next_speed(speed_min: float, speed_max: float) -> float:
	return _next_range(speed_min, speed_max)


func _next_unit() -> float:
	if patrol_seed <= 0:
		patrol_seed = 991
	patrol_seed = int((patrol_seed * 1103515245 + 12345) % COMPANION_PATROL_SEED_MOD)
	return float(patrol_seed % 10000) / 10000.0


func _build_seed(owner: Object, trigger_count: int) -> int:
	var player_pos: Vector2 = _get_owner_vector2(owner, "player_pos", Vector2(FIELD_WIDTH * 0.5 - 77.5, FIELD_HEIGHT - 50.0))
	var raw_seed: int = int(absf(round(
		player_pos.x * 13.0
		+ player_pos.y * 17.0
		+ pos.x * 19.0
		+ pos.y * 23.0
		+ float(trigger_count + 1) * 97.0
	)))
	return maxi(1, raw_seed % COMPANION_PATROL_SEED_MOD)


func _get_owner_value(owner: Object, property_name: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	var value: Variant = owner.get(property_name)
	return fallback if value == null else value


func _get_owner_vector2(owner: Object, property_name: String, fallback: Vector2) -> Vector2:
	var value: Variant = _get_owner_value(owner, property_name, fallback)
	return value if value is Vector2 else fallback
