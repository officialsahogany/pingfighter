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
# Defense is a LOCAL, ANTICIPATORY predictive guard, NOT a field-wide goalkeeper.
# Design intent: when the lingpet is off doing its own thing (far from the player)
# and a ball the player cannot reach falls NEAR the lingpet, it predicts the landing
# X and starts easing toward it EARLY (anchors as soon as the ball enters the band),
# so it is in position by the time the ball arrives. It must NOT sprint across the
# field — a high constant speed (the earlier 420 "fix") read as the lingpet running
# the whole field. The motion therefore stays LOCAL and eased (NOT a field sprint),
# but the peak chase speed is a CLEARLY perceptible step above patrol (≈192 for a
# 120px/s pet vs the old subtle ≈156) — the +30% floor was raised to +60% on
# 2026-06-25 after a felt-gap report that defense activation read identical to patrol.
# The scope/ease caution from the saga is about LOCAL+eased motion, NOT raw speed, so
# this raise does not reopen the teleport regression. The commit zone is a generous
# LOCAL radius (not a tight "reachable THIS frame" window): the lingpet anchors early
# and tracks, which is what makes a high defense rate actually guard nearby balls
# instead of whiffing because it committed too late.
# Guard chase speed = the pet's OWN move speed * (1 + bonus). The bonus is a +60%
# FLOOR that EVERY defending lingpet gets (current AND future, no per-pet code), and it
# scales HIGHER for pets whose defense_rate exceeds 60% -- so a higher defense rate is
# BOTH wider (local zone above) AND faster, keeping the widened commit zone reachable.
# The floor makes the "+60% move speed while defending" buff universal, not maribo-
# specific. (Flight pets have no defense intercept, so they never reach this -- by
# design; defense is patrol-only.) Examples (120px/s base pet): rate 0.10 -> floor +60%
# -> 192; rate 0.30 (maribo) -> +60% -> 192; rate 1.0 -> +100% -> 240. Capped well under
# the saga-rejected 420 "robot teleport"; the ease-in/out ramp below keeps even the high
# end from snapping. Playtest defaults -- keep speed on this SINGLE lever (saga: do not
# raise guard speed in more than one place). If a live look still reads weak, bump this
# floor (0.70/0.80); if it snaps/teleports, drop it back.
const COMPANION_DEFENSE_GUARD_SPEED_MIN_BONUS := 0.60
const COMPANION_DEFENSE_GUARD_SPEED_RATE_GAIN := 1.0
const COMPANION_DEFENSE_GUARD_SPEED_CAP := 320.0
# Ease-in: ramp from patrol speed up to the peak so even the small guard move starts
# gently instead of snapping.
const COMPANION_DEFENSE_INTERCEPT_ACCEL := 1500.0
const COMPANION_DEFENSE_GUARD_AURA_RAMP_SECONDS := 0.15
# Ease-out: cap the speed at distance / this time so it decelerates into the
# intercept point (smooth arrival) instead of stopping dead.
const COMPANION_DEFENSE_INTERCEPT_EASE_OUT_TIME := 0.12
# Local commit zone: the lingpet anchors to (and eases toward) a predicted landing X
# only when it is within this horizontal radius of the lingpet. It scales with
# defense_rate so higher defense is both more likely and broader, while still
# bounded so far balls stay out of scope (no field sprint).
const COMPANION_DEFENSE_LOCAL_ZONE_MIN := 150.0
const COMPANION_DEFENSE_LOCAL_ZONE_MAX := 350.0
const COMPANION_DEFENSE_TARGET_TOLERANCE := 8.0
const MOTION_STYLE_PATROL := "patrol"
const MOTION_STYLE_FREE_FLIGHT := "free_flight"
const MOTION_STYLE_SORTIE_FLIGHT := "sortie_flight"
const FREE_FLIGHT_MARGIN_X := 96.0
const FREE_FLIGHT_MARGIN_Y := 72.0
const FREE_FLIGHT_INSIDE_MARGIN_X := 42.0
const FREE_FLIGHT_INSIDE_MARGIN_Y := 70.0
const FREE_FLIGHT_TARGET_TOLERANCE := 12.0
const FREE_FLIGHT_TARGET_INTERVAL_MIN := 0.55
const FREE_FLIGHT_TARGET_INTERVAL_MAX := 1.65
const FREE_FLIGHT_EXIT_CHANCE := 0.28
# free_flight = GHOST blink: rabi fades in at a spot, hovers, fades out IN PLACE,
# waits hidden, then reappears at a NEW random spot. It does NOT fly. appearance_rate
# shortens the hidden wait (HIDDEN_FAST_* is the appearance_rate=1.0 floor).
const FREE_GHOST_VISIBLE_SECONDS_MIN := 2.2
const FREE_GHOST_VISIBLE_SECONDS_MAX := 3.8
const FREE_GHOST_HIDDEN_SECONDS_MIN := 5.00
const FREE_GHOST_HIDDEN_SECONDS_MAX := 12.00
const FREE_GHOST_HIDDEN_FAST_MIN := 1.20
const FREE_GHOST_HIDDEN_FAST_MAX := 2.50
const FREE_GHOST_FADE_SECONDS := 0.35
# While visible the ghost slowly drifts toward nearby wander points so it reads as a
# floating spirit, not a frozen sprite (it still vanishes in place and reappears
# elsewhere). Slow + local on purpose -- this is NOT the old continuous roam.
const FREE_GHOST_DRIFT_SPEED := 64.0
const FREE_GHOST_WANDER_RADIUS := 96.0
const FREE_GHOST_WANDER_TOLERANCE := 12.0
const SORTIE_OFFSCREEN_MARGIN_X := 190.0
const SORTIE_OFFSCREEN_MARGIN_Y := 150.0
const SORTIE_EDGE_Y_MIN := 118.0
const SORTIE_EDGE_Y_MAX := FIELD_HEIGHT - 250.0
const SORTIE_HIDDEN_SECONDS_MIN := 6.50
const SORTIE_HIDDEN_SECONDS_MAX := 15.00
# appearance_rate=1.0 floor for the sortie hidden (reappear) wait.
const SORTIE_HIDDEN_FAST_MIN := 1.50
const SORTIE_HIDDEN_FAST_MAX := 3.00
const SORTIE_TURN_RATE := 1.05
const SORTIE_LOITER_TURN_RATE := 1.42
const SORTIE_EXIT_TURN_RATE := 0.94
const SORTIE_ACCELERATION := 240.0
const SORTIE_INGRESS_DECELERATION := 390.0
const SORTIE_EXIT_ACCELERATION := 520.0
const SORTIE_HOLD_DECELERATION := 360.0
const SORTIE_INGRESS_SPEED_MIN := 430.0
const SORTIE_INGRESS_SPEED_MAX := 560.0
const SORTIE_LOITER_SPEED_MIN := 118.0
const SORTIE_LOITER_SPEED_MAX := 205.0
const SORTIE_EXIT_SPEED_MAX := 630.0
const SORTIE_INGRESS_SLOW_DISTANCE := 420.0
const SORTIE_REACH_TOLERANCE := 34.0
const SORTIE_LOITER_REACH_TOLERANCE := 26.0
const SORTIE_LOITER_SECONDS_MIN := 1.70
const SORTIE_LOITER_SECONDS_MAX := 3.90
const SORTIE_LOITER_TARGET_INTERVAL_MIN := 0.42
const SORTIE_LOITER_TARGET_INTERVAL_MAX := 1.05
const SORTIE_HOLD_SECONDS_MIN := 0.28
const SORTIE_HOLD_SECONDS_MAX := 0.72
const SORTIE_CENTER_MIN_X := 150.0
const SORTIE_CENTER_MAX_X := FIELD_WIDTH - 150.0
const SORTIE_CENTER_MIN_Y := 150.0
const SORTIE_CENTER_MAX_Y := FIELD_HEIGHT - 270.0
const SORTIE_PHASE_HIDDEN := "hidden"
const SORTIE_PHASE_INGRESS := "ingress"
const SORTIE_PHASE_LOITER := "loiter"
const SORTIE_PHASE_HOLD := "hold"
const SORTIE_PHASE_EXIT := "exit"

var pos := Vector2.ZERO
var motion_style := MOTION_STYLE_PATROL
var free_flight_target := Vector2.ZERO
var motion_velocity := Vector2.ZERO
var motion_speed_ratio := 0.0
var motion_visible := true
var sortie_phase := ""
var sortie_phase_timer := 0.0
# appearance_rate (출현율): flight-only stat that shortens hidden/vanish waits.
var appearance_rate := 0.0
# Ghost (free_flight) fade: 0 = fully hidden, 1 = fully visible. Renderer multiplies
# the companion sprite alpha by this so rabi fades out/in instead of hard-popping.
var ghost_alpha := 1.0
var ghost_visible_total := 0.0
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
var defense_intercept_speed := 0.0
# ACTUAL per-frame intercept movement speed (0 while parked at the anchor waiting
# for the ball). motion_speed_ratio is the renderer's walk/idle gate AND walk-anim
# speed, so it must come from this, never from the guard capability cap — the
# anticipatory guard arrives EARLY by design, and a cap-based ratio makes the
# arrived-and-holding companion treadmill in place at full walk speed.
var defense_intercept_step_speed := 0.0
var defense_last_roll := 1.0
var defense_guard_aura_ratio := 0.0


func reset() -> void:
	pos = Vector2.ZERO
	motion_style = MOTION_STYLE_PATROL
	free_flight_target = Vector2.ZERO
	motion_velocity = Vector2.ZERO
	motion_speed_ratio = 0.0
	motion_visible = true
	sortie_phase = ""
	sortie_phase_timer = 0.0
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
	defense_intercept_speed = 0.0
	defense_intercept_step_speed = 0.0
	defense_guard_aura_ratio = 0.0


static func get_defense_local_zone(defense_rate: float) -> float:
	return lerpf(
		COMPANION_DEFENSE_LOCAL_ZONE_MIN,
		COMPANION_DEFENSE_LOCAL_ZONE_MAX,
		clampf(defense_rate, 0.0, 1.0)
	)


static func get_defense_guard_speed(speed_default: float, defense_rate: float) -> float:
	var rate: float = clampf(defense_rate, 0.0, 1.0)
	# +60% floor for EVERY defending pet, scaling above it once defense_rate > 0.60.
	var bonus: float = maxf(COMPANION_DEFENSE_GUARD_SPEED_MIN_BONUS, COMPANION_DEFENSE_GUARD_SPEED_RATE_GAIN * rate)
	var scaled: float = maxf(1.0, speed_default) * (1.0 + bonus)
	return minf(scaled, COMPANION_DEFENSE_GUARD_SPEED_CAP)


func _normalize_motion_style(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	if normalized == MOTION_STYLE_SORTIE_FLIGHT:
		return MOTION_STYLE_SORTIE_FLIGHT
	if normalized == MOTION_STYLE_FREE_FLIGHT:
		return MOTION_STYLE_FREE_FLIGHT
	return MOTION_STYLE_PATROL


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
	speed_default: float,
	speed_min: float,
	speed_max: float,
	motion_style_value: String = MOTION_STYLE_PATROL,
	appearance_rate_value: float = 0.0,
	satiety_speed_scale: float = 1.0
) -> void:
	motion_style = _normalize_motion_style(motion_style_value)
	appearance_rate = clampf(appearance_rate_value, 0.0, 1.0)
	var speed_scale := clampf(satiety_speed_scale, 0.0, 1.0)
	if motion_style == MOTION_STYLE_SORTIE_FLIGHT:
		_update_sortie_flight(delta, owner, freeze_motion, trigger_count, speed_min, speed_max, speed_scale)
		return
	if motion_style == MOTION_STYLE_FREE_FLIGHT:
		_update_free_flight(delta, owner, freeze_motion, trigger_count, speed_min, speed_max, speed_scale)
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
	motion_visible = true
	if freeze_motion:
		clear_defense_intercept()
		motion_speed_ratio = 0.0
		return
	if safe_delta <= 0.0:
		motion_speed_ratio = 0.0 if patrol_pause > 0.0 else _speed_ratio(patrol_speed * speed_scale, speed_min, speed_max)
		return
	if _try_update_defense_intercept(safe_delta, owner, defense_rate, speed_default * speed_scale, speed_min * speed_scale):
		_advance_defense_guard_aura(safe_delta)
		motion_speed_ratio = _speed_ratio(defense_intercept_step_speed, speed_min, speed_max)
		return
	_advance_defense_guard_aura(safe_delta)
	if patrol_pause > 0.0:
		patrol_pause = maxf(0.0, patrol_pause - safe_delta)
		motion_speed_ratio = 0.0
		return

	patrol_change_timer = maxf(0.0, patrol_change_timer - safe_delta)
	if is_zero_approx(patrol_dir):
		# Recover a heading before moving. The defense intercept parks patrol_dir at 0 when it
		# arrives at the guard point, and NOTHING restores it once the guard clears: a flip is
		# -1 * 0 = 0, and a heading-less pet can never reach a lane edge to be re-aimed, so it
		# would sit frozen in place (the real cause of the lingpet "제자리걸음" / barely-moving
		# bug) until a round reset re-initializes it. Re-seed a direction here, where the patrol
		# section only runs once the defense guard is no longer active.
		patrol_dir = -1.0 if _next_unit() < 0.5 else 1.0
	var effective_patrol_speed := patrol_speed * speed_scale
	var next_x: float = pos.x + patrol_dir * effective_patrol_speed * safe_delta
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
	# An edge-hit / surprise / choose-next-action above may have just armed patrol_pause
	# (the pet should stand still this beat). Reflect that in the draw ratio now instead of
	# emitting one stray walk frame at the clamped boundary before the next frame's pause
	# branch zeroes it.
	if patrol_pause > 0.0:
		motion_speed_ratio = 0.0
	else:
		motion_speed_ratio = _speed_ratio(absf(effective_patrol_speed), speed_min, speed_max)


func initialize(
	owner: Object,
	randomize_x: bool,
	trigger_count: int,
	speed_min: float,
	speed_max: float,
	motion_style_value: String = MOTION_STYLE_PATROL
) -> void:
	motion_style = _normalize_motion_style(motion_style_value)
	if motion_style == MOTION_STYLE_SORTIE_FLIGHT:
		_initialize_sortie_flight(owner, randomize_x, trigger_count, speed_min, speed_max)
		return
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
	motion_visible = true
	motion_speed_ratio = 0.0


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
		snapshot.get("companion_sortie_target", snapshot.get("companion_free_flight_target", free_flight_target)),
		free_flight_target
	)
	motion_velocity = _get_vector2_from_variant(
		snapshot.get("companion_motion_velocity", motion_velocity),
		motion_velocity
	)
	motion_speed_ratio = clampf(float(snapshot.get("companion_motion_speed_ratio", motion_speed_ratio)), 0.0, 1.0)
	motion_visible = bool(snapshot.get("companion_visible", motion_visible))
	ghost_alpha = clampf(float(snapshot.get("companion_ghost_alpha", ghost_alpha)), 0.0, 1.0)
	sortie_phase = str(snapshot.get("companion_sortie_phase", sortie_phase)).strip_edges().to_lower()
	sortie_phase_timer = maxf(0.0, float(snapshot.get("companion_sortie_phase_timer", sortie_phase_timer)))
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
		"companion_sortie_target": free_flight_target,
		"companion_motion_velocity": motion_velocity,
		"companion_motion_speed_ratio": motion_speed_ratio,
		"companion_visible": motion_visible,
		"companion_ghost_alpha": ghost_alpha,
		"companion_sortie_phase": sortie_phase,
		"companion_sortie_phase_timer": sortie_phase_timer,
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
		"companion_defense_guard_aura_ratio": defense_guard_aura_ratio,
		"companion_defense_decision_timer": defense_decision_timer,
		"companion_defense_last_roll": defense_last_roll,
	}


func get_save_snapshot() -> Dictionary:
	return {
		"companion_motion_style": motion_style,
		"companion_free_flight_target": free_flight_target,
		"companion_sortie_target": free_flight_target,
		"companion_motion_velocity": motion_velocity,
		"companion_motion_speed_ratio": motion_speed_ratio,
		"companion_visible": motion_visible,
		"companion_ghost_alpha": ghost_alpha,
		"companion_sortie_phase": sortie_phase,
		"companion_sortie_phase_timer": sortie_phase_timer,
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
	defense_guard_aura_ratio = 1.0 if test_intercept_active else 0.0
	motion_velocity = Vector2.ZERO
	motion_speed_ratio = 0.0
	motion_visible = true
	sortie_phase = SORTIE_PHASE_LOITER
	sortie_phase_timer = 1.0
	free_flight_target = test_pos
	patrol_change_timer = 1.0
	patrol_speed = SORTIE_LOITER_SPEED_MIN


func configure_sortie_hidden_for_tests(test_pos: Vector2, test_seed: int, hidden_seconds: float) -> void:
	pos = test_pos
	patrol_seed = maxi(1, test_seed)
	motion_style = MOTION_STYLE_SORTIE_FLIGHT
	free_flight_target = test_pos
	motion_velocity = Vector2.ZERO
	motion_speed_ratio = 0.0
	motion_visible = false
	sortie_phase = SORTIE_PHASE_HIDDEN
	sortie_phase_timer = 0.0
	patrol_pause = maxf(0.0, hidden_seconds)
	patrol_change_timer = 0.0
	patrol_speed = SORTIE_LOITER_SPEED_MIN
	clear_defense_intercept()


func resume_sortie_loiter_from_current(
	owner: Object,
	trigger_count: int,
	speed_min: float,
	speed_max: float,
	motion_style_value: String = MOTION_STYLE_PATROL
) -> bool:
	motion_style = _normalize_motion_style(motion_style_value)
	if motion_style != MOTION_STYLE_SORTIE_FLIGHT:
		return false
	if patrol_seed <= 0:
		patrol_seed = _build_seed(owner, trigger_count)
	if pos == Vector2.ZERO:
		pos = _get_sortie_center_target()
	pos.x = clampf(pos.x, COMPANION_RADIUS + 20.0, FIELD_WIDTH - COMPANION_RADIUS - 20.0)
	pos.y = clampf(pos.y, COMPANION_RADIUS + 20.0, FIELD_HEIGHT - COMPANION_RADIUS - 20.0)
	motion_visible = true
	sortie_phase = SORTIE_PHASE_LOITER
	sortie_phase_timer = SORTIE_LOITER_SECONDS_MAX
	patrol_pause = 0.0
	patrol_change_timer = 0.0
	if motion_velocity.length() <= 0.01:
		var fallback_dir := 1.0 if patrol_dir >= 0.0 else -1.0
		motion_velocity = Vector2(fallback_dir, -0.16).normalized() * SORTIE_LOITER_SPEED_MIN
		patrol_dir = fallback_dir
	_choose_sortie_loiter_target(speed_min, speed_max)
	motion_speed_ratio = _speed_ratio(motion_velocity.length(), speed_min, speed_max)
	clear_defense_intercept()
	return true


func resolve_facing_left_from_patrol_dir(current_facing_left: bool) -> bool:
	if absf(float(patrol_dir)) <= 0.01:
		return current_facing_left
	return float(patrol_dir) < 0.0


func resolve_facing_left_after_motion(
	previous_pos: Vector2,
	current_pos: Vector2,
	current_facing_left: bool
) -> bool:
	# Flip the walk-sheet mirror only when the companion visibly travels left/right.
	# The zero-to-spawn/restore placement jump is not real travel, so that first
	# frame seeds from the real patrol direction instead.
	if current_pos == Vector2.ZERO:
		return current_facing_left
	if previous_pos == Vector2.ZERO:
		return resolve_facing_left_from_patrol_dir(current_facing_left)
	var dx: float = current_pos.x - previous_pos.x
	if absf(dx) > 0.05:
		return dx < 0.0
	return current_facing_left


func _update_free_flight(
	delta: float,
	owner: Object,
	freeze_motion: bool,
	trigger_count: int,
	speed_min: float,
	speed_max: float,
	satiety_speed_scale: float = 1.0
) -> void:
	if patrol_seed <= 0:
		_initialize_free_flight(owner, pos == Vector2.ZERO, trigger_count, speed_min, speed_max)
	_sync_free_flight_bounds()
	if pos == Vector2.ZERO:
		_initialize_free_flight(owner, true, trigger_count, speed_min, speed_max)
		return

	var safe_delta: float = maxf(0.0, delta)
	var speed_scale := clampf(satiety_speed_scale, 0.0, 1.0)
	clear_defense_intercept()
	# rabi is a GHOST: it never flies IN/OUT, it blinks (vanish in place -> wait ->
	# reappear at a NEW spot). While visible it gently DRIFTS so it reads as a floating
	# spirit rather than a frozen sprite.
	if freeze_motion or safe_delta <= 0.0:
		motion_velocity = Vector2.ZERO
		motion_speed_ratio = 0.0
		return

	if motion_visible:
		# Visible: fade in -> hover-drift -> fade out, then vanish in place.
		patrol_change_timer = maxf(0.0, patrol_change_timer - safe_delta)
		var elapsed: float = maxf(0.0, ghost_visible_total - patrol_change_timer)
		var fade_in: float = clampf(elapsed / FREE_GHOST_FADE_SECONDS, 0.0, 1.0)
		var fade_out: float = clampf(patrol_change_timer / FREE_GHOST_FADE_SECONDS, 0.0, 1.0)
		ghost_alpha = minf(fade_in, fade_out)
		# Gentle local drift toward a nearby wander point (re-picked when reached).
		if free_flight_target == pos or pos.distance_to(free_flight_target) <= FREE_GHOST_WANDER_TOLERANCE:
			_pick_ghost_wander_target()
		var offset: Vector2 = free_flight_target - pos
		var distance: float = offset.length()
		if distance > 0.01:
			var drift_speed := FREE_GHOST_DRIFT_SPEED * speed_scale
			var step: float = minf(distance, drift_speed * safe_delta)
			motion_velocity = offset / distance * (step / safe_delta)
			pos += offset / distance * step
			if absf(offset.x) > 1.0:
				patrol_dir = 1.0 if offset.x > 0.0 else -1.0
		else:
			motion_velocity = Vector2.ZERO
		motion_speed_ratio = _speed_ratio(motion_velocity.length(), speed_min, speed_max)
		if patrol_change_timer <= 0.0:
			_begin_free_ghost_hidden()
	else:
		# Hidden: vanished, waiting; appearance_rate (출현율) shortens this wait.
		motion_velocity = Vector2.ZERO
		motion_speed_ratio = 0.0
		ghost_alpha = 0.0
		patrol_pause = maxf(0.0, patrol_pause - safe_delta)
		if patrol_pause <= 0.0:
			_begin_free_ghost_visible()


func _begin_free_ghost_hidden() -> void:
	motion_visible = false
	motion_velocity = Vector2.ZERO
	motion_speed_ratio = 0.0
	ghost_alpha = 0.0
	var hidden_min: float = lerpf(FREE_GHOST_HIDDEN_SECONDS_MIN, FREE_GHOST_HIDDEN_FAST_MIN, appearance_rate)
	var hidden_max: float = lerpf(FREE_GHOST_HIDDEN_SECONDS_MAX, FREE_GHOST_HIDDEN_FAST_MAX, appearance_rate)
	patrol_pause = _next_range(hidden_min, hidden_max)


func _begin_free_ghost_visible() -> void:
	# Reappear at a NEW random inside spot (teleport blink), then fade in.
	pos = Vector2(
		_next_range(FREE_FLIGHT_INSIDE_MARGIN_X, FIELD_WIDTH - FREE_FLIGHT_INSIDE_MARGIN_X),
		_next_range(FREE_FLIGHT_INSIDE_MARGIN_Y, FIELD_HEIGHT - FREE_FLIGHT_INSIDE_MARGIN_Y)
	)
	free_flight_target = pos
	motion_visible = true
	motion_velocity = Vector2.ZERO
	motion_speed_ratio = 0.0
	ghost_alpha = 0.0
	ghost_visible_total = _next_range(FREE_GHOST_VISIBLE_SECONDS_MIN, FREE_GHOST_VISIBLE_SECONDS_MAX)
	patrol_change_timer = ghost_visible_total
	patrol_dir = -1.0 if _next_unit() < 0.5 else 1.0


func _pick_ghost_wander_target() -> void:
	# A nearby point within the field so the visible ghost drifts locally (not a
	# cross-field roam). Re-picked when reached; cleared/replaced on each reappear.
	var tx: float = clampf(pos.x + _next_range(-FREE_GHOST_WANDER_RADIUS, FREE_GHOST_WANDER_RADIUS), FREE_FLIGHT_INSIDE_MARGIN_X, FIELD_WIDTH - FREE_FLIGHT_INSIDE_MARGIN_X)
	var ty: float = clampf(pos.y + _next_range(-FREE_GHOST_WANDER_RADIUS, FREE_GHOST_WANDER_RADIUS), FREE_FLIGHT_INSIDE_MARGIN_Y, FIELD_HEIGHT - FREE_FLIGHT_INSIDE_MARGIN_Y)
	free_flight_target = Vector2(tx, ty)


func _initialize_free_flight(
	owner: Object,
	randomize_pos: bool,
	trigger_count: int,
	speed_min: float,
	speed_max: float
) -> void:
	var _unused_speed_min := speed_min  # ghost does not fly; fly speeds are ignored
	var _unused_speed_max := speed_max
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
	free_flight_target = pos
	if is_zero_approx(patrol_dir):
		patrol_dir = -1.0 if _next_unit() < 0.5 else 1.0
	# Start the ghost cycle already VISIBLE at the spawn spot, then it will blink.
	motion_visible = true
	motion_velocity = Vector2.ZERO
	motion_speed_ratio = 0.0
	ghost_alpha = 0.0
	ghost_visible_total = _next_range(FREE_GHOST_VISIBLE_SECONDS_MIN, FREE_GHOST_VISIBLE_SECONDS_MAX)
	patrol_change_timer = ghost_visible_total
	patrol_pause = 0.0


func _update_sortie_flight(
	delta: float,
	owner: Object,
	freeze_motion: bool,
	trigger_count: int,
	speed_min: float,
	speed_max: float,
	satiety_speed_scale: float = 1.0
) -> void:
	var speed_scale := clampf(satiety_speed_scale, 0.0, 1.0)
	if patrol_seed <= 0 or sortie_phase == "":
		_initialize_sortie_flight(owner, true, trigger_count, speed_min, speed_max, speed_scale)
	if pos == Vector2.ZERO:
		_initialize_sortie_flight(owner, true, trigger_count, speed_min, speed_max, speed_scale)
		return

	var safe_delta: float = maxf(0.0, delta)
	clear_defense_intercept()
	if freeze_motion:
		motion_speed_ratio = 0.0
		return
	if safe_delta <= 0.0:
		motion_speed_ratio = _speed_ratio(motion_velocity.length(), speed_min, speed_max)
		return

	match sortie_phase:
		SORTIE_PHASE_HIDDEN:
			_update_sortie_hidden(safe_delta, owner, trigger_count, speed_min, speed_max, speed_scale)
		SORTIE_PHASE_INGRESS:
			_update_sortie_ingress(safe_delta, speed_min, speed_max, speed_scale)
		SORTIE_PHASE_LOITER:
			_update_sortie_loiter(safe_delta, speed_min, speed_max, speed_scale)
		SORTIE_PHASE_HOLD:
			_update_sortie_hold(safe_delta, speed_min, speed_max, speed_scale)
		SORTIE_PHASE_EXIT:
			_update_sortie_exit(safe_delta, speed_min, speed_max, speed_scale)
		_:
			_start_sortie_entry(owner, trigger_count, speed_min, speed_max, speed_scale)


func _initialize_sortie_flight(
	owner: Object,
	_randomize_pos: bool,
	trigger_count: int,
	speed_min: float,
	speed_max: float,
	satiety_speed_scale: float = 1.0
) -> void:
	if patrol_seed <= 0:
		patrol_seed = _build_seed(owner, trigger_count)
	_start_sortie_entry(owner, trigger_count, speed_min, speed_max, satiety_speed_scale)


func _update_sortie_hidden(delta: float, owner: Object, trigger_count: int, speed_min: float, speed_max: float, satiety_speed_scale: float = 1.0) -> void:
	motion_visible = false
	motion_velocity = Vector2.ZERO
	motion_speed_ratio = 0.0
	patrol_pause = maxf(0.0, patrol_pause - delta)
	if patrol_pause <= 0.0:
		_start_sortie_entry(owner, trigger_count, speed_min, speed_max, satiety_speed_scale)


func _update_sortie_ingress(delta: float, speed_min: float, speed_max: float, satiety_speed_scale: float = 1.0) -> void:
	motion_visible = true
	var distance := pos.distance_to(free_flight_target)
	if distance <= SORTIE_REACH_TOLERANCE:
		_begin_sortie_loiter(speed_min, speed_max)
		return
	var slow_ratio := clampf(distance / SORTIE_INGRESS_SLOW_DISTANCE, 0.0, 1.0)
	var target_speed := lerpf(patrol_speed, SORTIE_INGRESS_SPEED_MIN, slow_ratio)
	_advance_sortie_steered(delta, target_speed, SORTIE_TURN_RATE, SORTIE_INGRESS_DECELERATION, speed_min, speed_max, satiety_speed_scale)
	if pos.distance_to(free_flight_target) <= SORTIE_REACH_TOLERANCE:
		_begin_sortie_loiter(speed_min, speed_max)


func _update_sortie_loiter(delta: float, speed_min: float, speed_max: float, satiety_speed_scale: float = 1.0) -> void:
	motion_visible = true
	sortie_phase_timer = maxf(0.0, sortie_phase_timer - delta)
	patrol_change_timer = maxf(0.0, patrol_change_timer - delta)
	if sortie_phase_timer <= 0.0:
		_begin_sortie_hold(speed_min, speed_max)
		return
	if (
		free_flight_target == Vector2.ZERO
		or patrol_change_timer <= 0.0
		or pos.distance_to(free_flight_target) <= SORTIE_LOITER_REACH_TOLERANCE
	):
		_choose_sortie_loiter_target(speed_min, speed_max)
	_advance_sortie_steered(delta, patrol_speed, SORTIE_LOITER_TURN_RATE, SORTIE_ACCELERATION, speed_min, speed_max, satiety_speed_scale)


func _update_sortie_hold(delta: float, speed_min: float, speed_max: float, satiety_speed_scale: float = 1.0) -> void:
	motion_visible = true
	var speed_scale := clampf(satiety_speed_scale, 0.0, 1.0)
	patrol_pause = maxf(0.0, patrol_pause - delta)
	var current_speed := motion_velocity.length()
	var next_speed := move_toward(current_speed, 0.0, SORTIE_HOLD_DECELERATION * speed_scale * delta)
	if current_speed > 0.01 and next_speed > 0.01:
		motion_velocity = motion_velocity.normalized() * next_speed
		pos += motion_velocity * delta
	else:
		motion_velocity = Vector2.ZERO
	motion_speed_ratio = _speed_ratio(motion_velocity.length(), speed_min, speed_max)
	if patrol_pause <= 0.0:
		_start_sortie_exit(speed_min, speed_max, satiety_speed_scale)


func _update_sortie_exit(delta: float, speed_min: float, speed_max: float, satiety_speed_scale: float = 1.0) -> void:
	motion_visible = true
	_advance_sortie_steered(delta, SORTIE_EXIT_SPEED_MAX, SORTIE_EXIT_TURN_RATE, SORTIE_EXIT_ACCELERATION, speed_min, speed_max, satiety_speed_scale)
	if pos.distance_to(free_flight_target) <= SORTIE_REACH_TOLERANCE or _is_sortie_far_offscreen(pos):
		_begin_sortie_hidden(speed_min, speed_max)


func _start_sortie_entry(owner: Object, trigger_count: int, speed_min: float, speed_max: float, satiety_speed_scale: float = 1.0) -> void:
	if patrol_seed <= 0:
		patrol_seed = _build_seed(owner, trigger_count)
	var speed_scale := clampf(satiety_speed_scale, 0.0, 1.0)
	var from_left := _next_unit() < 0.5
	pos = Vector2(
		-SORTIE_OFFSCREEN_MARGIN_X if from_left else FIELD_WIDTH + SORTIE_OFFSCREEN_MARGIN_X,
		_next_range(SORTIE_EDGE_Y_MIN, SORTIE_EDGE_Y_MAX)
	)
	free_flight_target = _get_sortie_center_target()
	patrol_speed = _next_range(SORTIE_LOITER_SPEED_MIN, SORTIE_LOITER_SPEED_MAX)
	var route_dir := (free_flight_target - pos).normalized()
	var entry_bias: float = _next_range(-0.18, 0.18)
	motion_velocity = route_dir.rotated(entry_bias) * _next_range(SORTIE_INGRESS_SPEED_MIN, SORTIE_INGRESS_SPEED_MAX) * speed_scale
	patrol_dir = 1.0 if motion_velocity.x >= 0.0 else -1.0
	patrol_pause = 0.0
	patrol_change_timer = _next_range(SORTIE_LOITER_TARGET_INTERVAL_MIN, SORTIE_LOITER_TARGET_INTERVAL_MAX)
	sortie_phase = SORTIE_PHASE_INGRESS
	sortie_phase_timer = 0.0
	motion_visible = true
	motion_speed_ratio = _speed_ratio(motion_velocity.length(), speed_min, speed_max)


func _begin_sortie_loiter(speed_min: float, speed_max: float) -> void:
	sortie_phase = SORTIE_PHASE_LOITER
	sortie_phase_timer = _next_range(SORTIE_LOITER_SECONDS_MIN, SORTIE_LOITER_SECONDS_MAX)
	_choose_sortie_loiter_target(speed_min, speed_max)


func _begin_sortie_hold(speed_min: float, speed_max: float) -> void:
	var _unused_speed_min := speed_min
	var _unused_speed_max := speed_max
	sortie_phase = SORTIE_PHASE_HOLD
	patrol_pause = _next_range(SORTIE_HOLD_SECONDS_MIN, SORTIE_HOLD_SECONDS_MAX)
	patrol_change_timer = 0.0
	free_flight_target = pos
	motion_speed_ratio = _speed_ratio(motion_velocity.length(), speed_min, speed_max)


func _start_sortie_exit(speed_min: float, speed_max: float, satiety_speed_scale: float = 1.0) -> void:
	var _unused_speed_min := speed_min
	var _unused_speed_max := speed_max
	var speed_scale := clampf(satiety_speed_scale, 0.0, 1.0)
	sortie_phase = SORTIE_PHASE_EXIT
	patrol_pause = 0.0
	patrol_change_timer = 0.0
	free_flight_target = _get_sortie_exit_target()
	if motion_velocity.length() <= 0.01:
		var exit_dir := (free_flight_target - pos).normalized()
		motion_velocity = exit_dir * SORTIE_LOITER_SPEED_MIN * speed_scale
	patrol_dir = 1.0 if motion_velocity.x >= 0.0 else -1.0


func _begin_sortie_hidden(speed_min: float, speed_max: float) -> void:
	pos = free_flight_target
	motion_velocity = Vector2.ZERO
	motion_speed_ratio = 0.0
	motion_visible = false
	sortie_phase = SORTIE_PHASE_HIDDEN
	sortie_phase_timer = 0.0
	# appearance_rate (출현율) shortens the hidden wait toward the FAST floor.
	var hidden_min: float = lerpf(SORTIE_HIDDEN_SECONDS_MIN, SORTIE_HIDDEN_FAST_MIN, appearance_rate)
	var hidden_max: float = lerpf(SORTIE_HIDDEN_SECONDS_MAX, SORTIE_HIDDEN_FAST_MAX, appearance_rate)
	patrol_pause = _next_range(hidden_min, hidden_max)
	patrol_speed = _next_speed(speed_min, speed_max)


func _choose_sortie_loiter_target(speed_min: float, speed_max: float) -> void:
	var _unused_speed_min := speed_min
	var _unused_speed_max := speed_max
	free_flight_target = _get_sortie_center_target()
	patrol_speed = _next_range(SORTIE_LOITER_SPEED_MIN, SORTIE_LOITER_SPEED_MAX)
	patrol_change_timer = _next_range(SORTIE_LOITER_TARGET_INTERVAL_MIN, SORTIE_LOITER_TARGET_INTERVAL_MAX)


func _get_sortie_center_target() -> Vector2:
	return Vector2(
		_next_range(SORTIE_CENTER_MIN_X, SORTIE_CENTER_MAX_X),
		_next_range(SORTIE_CENTER_MIN_Y, SORTIE_CENTER_MAX_Y)
	)


func _get_sortie_exit_target() -> Vector2:
	var exit_left := false
	if absf(motion_velocity.x) > 10.0:
		exit_left = motion_velocity.x < 0.0
	else:
		exit_left = _next_unit() < 0.5
	if absf(pos.x - FIELD_WIDTH * 0.5) > FIELD_WIDTH * 0.25 and _next_unit() < 0.55:
		exit_left = pos.x < FIELD_WIDTH * 0.5
	return Vector2(
		-SORTIE_OFFSCREEN_MARGIN_X if exit_left else FIELD_WIDTH + SORTIE_OFFSCREEN_MARGIN_X,
		_next_range(SORTIE_EDGE_Y_MIN, SORTIE_EDGE_Y_MAX)
	)


func _advance_sortie_steered(
	delta: float,
	target_speed: float,
	turn_rate: float,
	speed_change_rate: float,
	speed_min: float,
	speed_max: float,
	satiety_speed_scale: float = 1.0
) -> void:
	var offset := free_flight_target - pos
	var distance := offset.length()
	var speed_scale := clampf(satiety_speed_scale, 0.0, 1.0)
	var scaled_target_speed := target_speed * speed_scale
	var scaled_change_rate := speed_change_rate * speed_scale
	if distance <= 0.01:
		motion_speed_ratio = _speed_ratio(motion_velocity.length(), speed_min, speed_max)
		return
	var desired_dir := offset / distance
	if motion_velocity.length() <= 0.01:
		motion_velocity = desired_dir * maxf(0.0, scaled_target_speed)
	var current_dir := motion_velocity.normalized()
	var turn_angle := clampf(current_dir.angle_to(desired_dir), -turn_rate * delta, turn_rate * delta)
	var next_dir := current_dir.rotated(turn_angle).normalized()
	var next_speed := move_toward(motion_velocity.length(), scaled_target_speed, scaled_change_rate * delta)
	motion_velocity = next_dir * next_speed
	pos += motion_velocity * delta
	if absf(motion_velocity.x) > 1.0:
		patrol_dir = 1.0 if motion_velocity.x > 0.0 else -1.0
	motion_speed_ratio = _speed_ratio(next_speed, speed_min, speed_max)


func _is_sortie_far_offscreen(value: Vector2) -> bool:
	return (
		value.x <= -SORTIE_OFFSCREEN_MARGIN_X
		or value.x >= FIELD_WIDTH + SORTIE_OFFSCREEN_MARGIN_X
		or value.y <= -SORTIE_OFFSCREEN_MARGIN_Y
		or value.y >= FIELD_HEIGHT + SORTIE_OFFSCREEN_MARGIN_Y
	)


func _sync_free_flight_bounds() -> void:
	patrol_lane_y = FIELD_HEIGHT * 0.5
	patrol_min_x = -FREE_FLIGHT_MARGIN_X
	patrol_max_x = FIELD_WIDTH + FREE_FLIGHT_MARGIN_X


func _try_update_defense_intercept(delta: float, owner: Object, defense_rate: float, speed_default: float, speed_min: float) -> bool:
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
	# Predict where the ball will cross the lane (used for both tracking and arming).
	var impact_boost: float = maxf(0.01, float(_get_owner_value(owner, "ball_impact_boost", 1.0)))
	var frames_to_contact: float = vertical_gap / maxf(0.01, ball_vel.y * impact_boost)
	var future_ball_x: float = ball_pos.x + ball_vel.x * impact_boost * frames_to_contact
	var target_clamped: float = clampf(future_ball_x, patrol_min_x, patrol_max_x)
	if defense_intercept_active:
		# Anticipatory tracking: keep re-anchoring to the predicted landing X while the
		# ball descends, so a still-descending (or gently curving) ball stays guarded.
		# The slow intercept speed caps total travel per descent, so re-anchoring can
		# never become a field sprint even if the prediction drifts.
		defense_intercept_target_x = target_clamped
		return _advance_defense_intercept(delta, speed_default, speed_min, defense_rate)
	defense_decision_timer = maxf(0.0, defense_decision_timer - delta)
	if defense_decision_timer > 0.0 or vertical_gap > COMPANION_DEFENSE_LOOKAHEAD_MAX_GAP:
		return false
	# Only guard balls the PLAYER cannot reach -- guarding a ball the player could
	# block anyway is pointless (mirrors lingpet_ring_dash_state._player_can_block).
	# Checked before the roll/timer so player-blockable balls don't burn the roll.
	if _player_can_block(owner, target_clamped, ball_radius):
		return false
	# Local commit zone (ANTICIPATORY): arm as soon as the predicted X is within the
	# defense-rate-scaled local radius, then anchor and ease toward it EARLY -- do NOT
	# wait until the ball is close enough to reach this very frame (that late-commit
	# window is exactly why a high defense rate still whiffed nearby balls).
	var local_zone: float = get_defense_local_zone(defense_rate)
	if absf(target_clamped - pos.x) > local_zone:
		return false
	defense_decision_timer = _next_range(
		COMPANION_DEFENSE_DECISION_INTERVAL_MIN,
		COMPANION_DEFENSE_DECISION_INTERVAL_MAX
	)
	defense_last_roll = _next_unit()
	if defense_last_roll >= defense_rate:
		return false
	defense_intercept_target_x = target_clamped
	defense_intercept_active = true
	defense_intercept_speed = 0.0  # start the ease-in ramp fresh from patrol speed
	patrol_pause = 0.0
	return _advance_defense_intercept(delta, speed_default, speed_min, defense_rate)


func _player_can_block(owner: Object, future_ball_x: float, ball_radius: float) -> bool:
	var player_width: float = maxf(1.0, float(_get_owner_value(owner, "player_paddle_width", 155.0)))
	var player_pos: Vector2 = _get_owner_vector2(owner, "player_pos", Vector2(FIELD_WIDTH * 0.5 - player_width * 0.5, 0.0))
	return future_ball_x >= player_pos.x - ball_radius and future_ball_x <= player_pos.x + player_width + ball_radius


func _advance_defense_intercept(delta: float, speed_default: float, speed_min: float, defense_rate: float) -> bool:
	var safe_delta: float = maxf(0.0, delta)
	var target_x: float = clampf(defense_intercept_target_x, patrol_min_x, patrol_max_x)
	var distance: float = target_x - pos.x
	if absf(distance) <= COMPANION_DEFENSE_TARGET_TOLERANCE:
		pos.x = target_x
		patrol_dir = 0.0
		defense_intercept_speed = 0.0
		defense_intercept_step_speed = 0.0
		return true
	patrol_dir = 1.0 if distance > 0.0 else -1.0
	# Ease-in: ramp from the patrol launch speed up to the cap so the dash starts
	# gently (a constant cap-speed slide from a standstill read as a teleport).
	var guard_speed: float = get_defense_guard_speed(speed_default, defense_rate)
	defense_intercept_speed = minf(
		guard_speed,
		maxf(defense_intercept_speed, speed_min) + COMPANION_DEFENSE_INTERCEPT_ACCEL * safe_delta
	)
	# Ease-out: never move faster than what settles onto the target within the
	# ease-out window, so the companion decelerates into the intercept point.
	var ease_out_speed: float = absf(distance) / COMPANION_DEFENSE_INTERCEPT_EASE_OUT_TIME
	var step_speed: float = minf(defense_intercept_speed, ease_out_speed)
	defense_intercept_step_speed = step_speed
	patrol_speed = clampf(step_speed, speed_min, guard_speed)
	pos.x = move_toward(pos.x, target_x, step_speed * safe_delta)
	pos.x = clampf(pos.x, patrol_min_x, patrol_max_x)
	return true


func _advance_defense_guard_aura(delta: float) -> void:
	if not defense_intercept_active:
		defense_guard_aura_ratio = 0.0
		return
	defense_guard_aura_ratio = minf(
		1.0,
		defense_guard_aura_ratio + maxf(0.0, delta) / COMPANION_DEFENSE_GUARD_AURA_RAMP_SECONDS
	)


func _resolve_lane(owner: Object) -> Dictionary:
	var player_size := Vector2(
		maxf(1.0, float(_get_owner_value(owner, "player_paddle_width", 155.0))),
		maxf(1.0, float(_get_owner_value(owner, "player_paddle_height", 50.0)))
	)
	var floor_y: float = _resolve_player_floor_y(owner, player_size)
	var lane_y: float = floor_y + player_size.y * COMPANION_PATROL_LANE_Y_OFFSET
	var min_x: float = maxf(COMPANION_PATROL_EDGE_MARGIN, COMPANION_RADIUS + 10.0)
	var max_x: float = minf(FIELD_WIDTH - COMPANION_PATROL_EDGE_MARGIN, FIELD_WIDTH - COMPANION_RADIUS - 10.0)
	return {
		"y": clampf(lane_y, COMPANION_RADIUS + 20.0, FIELD_HEIGHT - COMPANION_RADIUS - 20.0),
		"min_x": min_x,
		"max_x": max_x,
	}


func _resolve_player_floor_y(owner: Object, player_size: Vector2) -> float:
	var fallback_floor_y: float = maxf(0.0, FIELD_HEIGHT - player_size.y)
	return clampf(
		float(_get_owner_value(owner, "player_floor_y", fallback_floor_y)),
		0.0,
		fallback_floor_y
	)


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


func _speed_ratio(current_speed: float, speed_min: float, speed_max: float) -> float:
	var _unused_speed_min := speed_min
	if speed_max <= 0.0:
		return 1.0 if current_speed > 0.0 else 0.0
	return clampf(current_speed / speed_max, 0.0, 1.0)


func _next_unit() -> float:
	if patrol_seed <= 0:
		patrol_seed = 991
	patrol_seed = int((patrol_seed * 1103515245 + 12345) % COMPANION_PATROL_SEED_MOD)
	return float(patrol_seed % 10000) / 10000.0


func _build_seed(owner: Object, trigger_count: int) -> int:
	var player_pos: Vector2 = _get_owner_vector2(owner, "player_pos", Vector2(FIELD_WIDTH * 0.5 - 77.5, FIELD_HEIGHT - 50.0))
	var player_size := Vector2(
		maxf(1.0, float(_get_owner_value(owner, "player_paddle_width", 155.0))),
		maxf(1.0, float(_get_owner_value(owner, "player_paddle_height", 50.0)))
	)
	var player_floor_y: float = _resolve_player_floor_y(owner, player_size)
	var raw_seed: int = int(absf(round(
		player_pos.x * 13.0
		+ player_floor_y * 17.0
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
