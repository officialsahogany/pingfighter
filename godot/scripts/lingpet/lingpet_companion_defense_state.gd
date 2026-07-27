extends RefCounted

const FIELD_WIDTH := 760.0
const BALL_RADIUS_FALLBACK := 14.3
const COMPANION_HIT_HALF_HEIGHT := 22.0
# Local, anticipatory ground-companion guard. It only commits to a predicted
# landing point the player cannot block and that falls inside the companion's
# defense-rate-scaled local zone. Keep all reach/speed tuning on these constants;
# docs/godot_runtime_traps.md records the rejected field-wide sprint behavior.
const COMPANION_DEFENSE_DECISION_INTERVAL_MIN := 0.55
const COMPANION_DEFENSE_DECISION_INTERVAL_MAX := 0.95
const COMPANION_DEFENSE_LOOKAHEAD_MAX_GAP := 320.0
const COMPANION_DEFENSE_GUARD_SPEED_MIN_BONUS := 0.60
const COMPANION_DEFENSE_GUARD_SPEED_RATE_GAIN := 1.0
const COMPANION_DEFENSE_GUARD_SPEED_CAP := 320.0
const COMPANION_DEFENSE_INTERCEPT_ACCEL := 1500.0
const COMPANION_DEFENSE_GUARD_AURA_RAMP_SECONDS := 0.15
const COMPANION_DEFENSE_INTERCEPT_EASE_OUT_TIME := 0.12
const COMPANION_DEFENSE_LOCAL_ZONE_MIN := 150.0
const COMPANION_DEFENSE_LOCAL_ZONE_MAX := 350.0
const COMPANION_DEFENSE_TARGET_TOLERANCE := 8.0
const COMPANION_PATROL_SEED_MOD := 2147483647

var defense_decision_timer := 0.0
var defense_intercept_active := false
var defense_intercept_target_x := 0.0
var defense_intercept_speed := 0.0
var defense_intercept_step_speed := 0.0
var defense_last_roll := 1.0
var defense_guard_aura_ratio := 0.0


func reset() -> void:
	defense_decision_timer = 0.0
	defense_last_roll = 1.0
	clear_intercept()


func clear_intercept() -> void:
	defense_intercept_active = false
	defense_intercept_target_x = 0.0
	defense_intercept_speed = 0.0
	defense_intercept_step_speed = 0.0
	defense_guard_aura_ratio = 0.0


func configure_for_tests(test_decision_timer: float, test_intercept_active: bool) -> void:
	defense_decision_timer = maxf(0.0, test_decision_timer)
	defense_intercept_active = test_intercept_active
	defense_guard_aura_ratio = 1.0 if test_intercept_active else 0.0


static func get_defense_local_zone(defense_rate: float) -> float:
	return lerpf(
		COMPANION_DEFENSE_LOCAL_ZONE_MIN,
		COMPANION_DEFENSE_LOCAL_ZONE_MAX,
		clampf(defense_rate, 0.0, 1.0)
	)


static func get_defense_guard_speed(speed_default: float, defense_rate: float) -> float:
	var rate: float = clampf(defense_rate, 0.0, 1.0)
	# Every defending ground companion gets the +60% floor. Higher defense
	# rates scale above it, while the cap preserves the local/eased scope.
	var bonus: float = maxf(
		COMPANION_DEFENSE_GUARD_SPEED_MIN_BONUS,
		COMPANION_DEFENSE_GUARD_SPEED_RATE_GAIN * rate
	)
	var scaled: float = maxf(1.0, speed_default) * (1.0 + bonus)
	return minf(scaled, COMPANION_DEFENSE_GUARD_SPEED_CAP)


func try_update(
	delta: float,
	battle_owner: Object,
	motion_host: Object,
	defense_rate: float,
	speed_default: float,
	speed_min: float
) -> bool:
	if motion_host == null:
		clear_intercept()
		return false
	if defense_rate <= 0.0:
		clear_intercept()
		return false
	if not bool(_get_owner_value(battle_owner, "ball_active", false)):
		clear_intercept()
		defense_decision_timer = 0.0
		return false

	var ball_vel: Vector2 = _get_owner_vector2(battle_owner, "ball_vel", Vector2.ZERO)
	if ball_vel.y <= 0.0:
		clear_intercept()
		defense_decision_timer = 0.0
		return false

	var ball_pos: Vector2 = _get_owner_vector2(battle_owner, "ball_pos", Vector2.ZERO)
	var ball_radius: float = maxf(
		1.0,
		float(_get_owner_value(battle_owner, "ball_size", BALL_RADIUS_FALLBACK * 2.0)) * 0.5
	)
	var patrol_lane_y := float(motion_host.get("patrol_lane_y"))
	var vertical_gap: float = (patrol_lane_y - COMPANION_HIT_HALF_HEIGHT) - (ball_pos.y + ball_radius)
	if vertical_gap < 0.0:
		clear_intercept()
		return false

	# Re-predict the landing point throughout descent. The slow, eased local
	# chase caps travel; the target itself must not be frozen at arm time.
	var impact_boost: float = maxf(
		0.01,
		float(_get_owner_value(battle_owner, "ball_impact_boost", 1.0))
	)
	var frames_to_contact: float = vertical_gap / maxf(0.01, ball_vel.y * impact_boost)
	var future_ball_x: float = ball_pos.x + ball_vel.x * impact_boost * frames_to_contact
	var patrol_min_x := float(motion_host.get("patrol_min_x"))
	var patrol_max_x := float(motion_host.get("patrol_max_x"))
	var target_clamped: float = clampf(future_ball_x, patrol_min_x, patrol_max_x)
	if defense_intercept_active:
		defense_intercept_target_x = target_clamped
		return _advance_intercept(delta, motion_host, speed_default, speed_min, defense_rate)

	defense_decision_timer = maxf(0.0, defense_decision_timer - delta)
	if defense_decision_timer > 0.0 or vertical_gap > COMPANION_DEFENSE_LOOKAHEAD_MAX_GAP:
		return false
	if _player_can_block(battle_owner, target_clamped, ball_radius):
		return false

	var companion_pos := _get_motion_pos(motion_host)
	if absf(target_clamped - companion_pos.x) > get_defense_local_zone(defense_rate):
		return false
	defense_decision_timer = _next_range(
		motion_host,
		COMPANION_DEFENSE_DECISION_INTERVAL_MIN,
		COMPANION_DEFENSE_DECISION_INTERVAL_MAX
	)
	defense_last_roll = _next_unit(motion_host)
	if defense_last_roll >= defense_rate:
		return false

	defense_intercept_target_x = target_clamped
	defense_intercept_active = true
	defense_intercept_speed = 0.0
	motion_host.set("patrol_pause", 0.0)
	return _advance_intercept(delta, motion_host, speed_default, speed_min, defense_rate)


func advance_guard_aura(delta: float) -> void:
	if not defense_intercept_active:
		defense_guard_aura_ratio = 0.0
		return
	defense_guard_aura_ratio = minf(
		1.0,
		defense_guard_aura_ratio + maxf(0.0, delta) / COMPANION_DEFENSE_GUARD_AURA_RAMP_SECONDS
	)


func _advance_intercept(
	delta: float,
	motion_host: Object,
	speed_default: float,
	speed_min: float,
	defense_rate: float
) -> bool:
	var safe_delta: float = maxf(0.0, delta)
	var patrol_min_x := float(motion_host.get("patrol_min_x"))
	var patrol_max_x := float(motion_host.get("patrol_max_x"))
	var target_x: float = clampf(defense_intercept_target_x, patrol_min_x, patrol_max_x)
	var companion_pos := _get_motion_pos(motion_host)
	var distance: float = target_x - companion_pos.x
	if absf(distance) <= COMPANION_DEFENSE_TARGET_TOLERANCE:
		companion_pos.x = target_x
		motion_host.set("pos", companion_pos)
		motion_host.set("patrol_dir", 0.0)
		defense_intercept_speed = 0.0
		defense_intercept_step_speed = 0.0
		return true

	motion_host.set("patrol_dir", 1.0 if distance > 0.0 else -1.0)
	var guard_speed: float = get_defense_guard_speed(speed_default, defense_rate)
	defense_intercept_speed = minf(
		guard_speed,
		maxf(defense_intercept_speed, speed_min) + COMPANION_DEFENSE_INTERCEPT_ACCEL * safe_delta
	)
	var ease_out_speed: float = absf(distance) / COMPANION_DEFENSE_INTERCEPT_EASE_OUT_TIME
	var step_speed: float = minf(defense_intercept_speed, ease_out_speed)
	defense_intercept_step_speed = step_speed
	motion_host.set("patrol_speed", clampf(step_speed, speed_min, guard_speed))
	companion_pos.x = move_toward(companion_pos.x, target_x, step_speed * safe_delta)
	companion_pos.x = clampf(companion_pos.x, patrol_min_x, patrol_max_x)
	motion_host.set("pos", companion_pos)
	return true


func _player_can_block(battle_owner: Object, future_ball_x: float, ball_radius: float) -> bool:
	var player_width: float = maxf(
		1.0,
		float(_get_owner_value(battle_owner, "player_paddle_width", 155.0))
	)
	var player_pos: Vector2 = _get_owner_vector2(
		battle_owner,
		"player_pos",
		Vector2(FIELD_WIDTH * 0.5 - player_width * 0.5, 0.0)
	)
	return (
		future_ball_x >= player_pos.x - ball_radius
		and future_ball_x <= player_pos.x + player_width + ball_radius
	)


func _next_range(motion_host: Object, min_value: float, max_value: float) -> float:
	return lerpf(min_value, max_value, _next_unit(motion_host))


func _next_unit(motion_host: Object) -> float:
	var patrol_seed := int(motion_host.get("patrol_seed"))
	if patrol_seed <= 0:
		patrol_seed = 991
	patrol_seed = int((patrol_seed * 1103515245 + 12345) % COMPANION_PATROL_SEED_MOD)
	motion_host.set("patrol_seed", patrol_seed)
	return float(patrol_seed % 10000) / 10000.0


func _get_motion_pos(motion_host: Object) -> Vector2:
	var value: Variant = motion_host.get("pos")
	return value if value is Vector2 else Vector2.ZERO


func _get_owner_value(owner: Object, property_name: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	var value: Variant = owner.get(property_name)
	return fallback if value == null else value


func _get_owner_vector2(owner: Object, property_name: String, fallback: Vector2) -> Vector2:
	var value: Variant = _get_owner_value(owner, property_name, fallback)
	return value if value is Vector2 else fallback
