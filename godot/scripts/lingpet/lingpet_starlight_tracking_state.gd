extends RefCounted

const PASSIVE_ID := "lingpet_starlight_tracking"
const DROP_TOKEN_KEY := "lingpet_starlight_tracking_token"
const DROP_ROLL_DONE_KEY := "lingpet_starlight_tracking_roll_done"
const DROP_ACTIVE_KEY := "lingpet_starlight_tracking_active"
const DROP_CARRYING_KEY := "lingpet_starlight_tracking_carrying"
const DROP_HOLD_REMAINING_KEY := "lingpet_starlight_tracking_hold_remaining"
const DROP_FORCE_ROLL_KEY := "lingpet_starlight_tracking_force_roll_pct"
const DROP_COMPANION_POS_KEY := "lingpet_starlight_tracking_companion_pos"
const DEFAULT_CHANCE_PCT := 20.0
const DEFAULT_CHASE_SPEED := 480.0
const DEFAULT_COLLECT_RADIUS := 28.0
const DEFAULT_DELIVERY_RADIUS := 42.0
const DEFAULT_PICKUP_HOLD_SECONDS := 1.0
const CARRIED_DROP_MIN_LIFE := 180.0
const PHASE_NONE := ""
const PHASE_TO_DROP := "to_drop"
const PHASE_PICKUP_HOLD := "pickup_hold"
const PHASE_TO_PLAYER := "to_player"

var _active := false
var _phase := PHASE_NONE
var _target_token := 0
var _next_token := 1
var _target_pos := Vector2.ZERO
var _companion_pos := Vector2.ZERO
var _last_roll_pct := -1.0
var _last_success := false
var _last_collected_pos := Vector2.ZERO
var _trigger_count := 0
var _claim_count := 0
var _pickup_hold_timer := 0.0


func advance(_delta: float, passive_skill: Dictionary, companion_active: bool, current_companion_pos: Vector2) -> void:
	if not _is_enabled(passive_skill, companion_active):
		reset_round_transients()
		return
	if _active and _companion_pos == Vector2.ZERO:
		_companion_pos = current_companion_pos


func update_drop(
	delta: float,
	drop: Dictionary,
	passive_skill: Dictionary,
	companion_active: bool,
	current_companion_pos: Vector2,
	player_delivery_pos: Vector2
) -> Dictionary:
	if drop.is_empty():
		return {}
	if not _is_enabled(passive_skill, companion_active):
		return {}
	var drop_token := _ensure_drop_token(drop)
	if _active and drop_token != _target_token:
		return {
			"claimed": false,
			"blocked_by_active_tracking": true,
		}
	if not _active:
		if bool(drop.get(DROP_ROLL_DONE_KEY, false)):
			return {}
		drop[DROP_ROLL_DONE_KEY] = true
		var chance_pct := maxf(0.0, float(passive_skill.get("starpoint_tracking_chance_pct", DEFAULT_CHANCE_PCT)))
		_last_roll_pct = _roll_percent(drop)
		_last_success = _last_roll_pct <= chance_pct
		if not _last_success:
			return {
				"rolled": true,
				"claimed": false,
				"success": false,
				"roll_pct": _last_roll_pct,
				"chance_pct": chance_pct,
			}
		_begin_tracking(drop_token, _get_drop_pos(drop), current_companion_pos)

	var safe_delta := maxf(0.0, delta)
	var chase_speed := maxf(0.0, float(passive_skill.get("starpoint_tracking_chase_speed", DEFAULT_CHASE_SPEED)))
	var collect_radius := maxf(1.0, float(passive_skill.get("starpoint_tracking_collect_radius", DEFAULT_COLLECT_RADIUS)))
	var delivery_radius := maxf(1.0, float(passive_skill.get("starpoint_tracking_delivery_radius", DEFAULT_DELIVERY_RADIUS)))
	var previous_pos := _resolve_companion_pos(current_companion_pos)
	var picked_up := false
	var delivered := false
	var move_delta := safe_delta
	if _phase == PHASE_TO_PLAYER:
		_target_pos = player_delivery_pos
	elif _phase == PHASE_PICKUP_HOLD:
		_target_pos = _companion_pos
		var hold_elapsed := minf(_pickup_hold_timer, safe_delta)
		_pickup_hold_timer = maxf(0.0, _pickup_hold_timer - safe_delta)
		move_delta = maxf(0.0, safe_delta - hold_elapsed)
		if _pickup_hold_timer <= 0.0:
			_phase = PHASE_TO_PLAYER
			_target_pos = player_delivery_pos
	else:
		_target_pos = _get_drop_pos(drop)
	if _phase != PHASE_PICKUP_HOLD:
		_companion_pos = previous_pos.move_toward(_target_pos, chase_speed * move_delta)
	_sync_drop_claim_state(drop)
	if _phase == PHASE_TO_DROP:
		picked_up = previous_pos.distance_to(_target_pos) <= collect_radius or _companion_pos.distance_to(_target_pos) <= collect_radius
		if picked_up:
			_companion_pos = _target_pos
			_phase = PHASE_PICKUP_HOLD
			_pickup_hold_timer = maxf(0.0, float(passive_skill.get("starpoint_tracking_pickup_hold_seconds", DEFAULT_PICKUP_HOLD_SECONDS)))
			_sync_drop_claim_state(drop)
	if _phase == PHASE_TO_PLAYER:
		_sync_drop_claim_state(drop)
		delivered = _companion_pos.distance_to(player_delivery_pos) <= delivery_radius
	if delivered:
		_last_collected_pos = _target_pos
		_trigger_count += 1
		_claim_count += 1
		_clear_active_tracking()
		drop[DROP_ACTIVE_KEY] = false
		drop[DROP_CARRYING_KEY] = false
		drop[DROP_HOLD_REMAINING_KEY] = 0.0
	return {
		"rolled": true,
		"claimed": true,
		"success": true,
		"picked_up": picked_up,
		"holding": _phase == PHASE_PICKUP_HOLD,
		"carrying": _phase == PHASE_PICKUP_HOLD or _phase == PHASE_TO_PLAYER,
		"delivered": delivered,
		"companion_pos": _companion_pos,
		"target_pos": _target_pos,
		"hold_remaining": _pickup_hold_timer,
		"roll_pct": _last_roll_pct,
	}


func has_companion_position_override() -> bool:
	return _active and _companion_pos != Vector2.ZERO


func get_companion_position_override(fallback: Vector2) -> Vector2:
	return _companion_pos if has_companion_position_override() else fallback


func reset_all() -> void:
	reset_round_transients()
	_next_token = 1
	_last_roll_pct = -1.0
	_last_success = false
	_last_collected_pos = Vector2.ZERO
	_trigger_count = 0
	_claim_count = 0


func reset_round_transients() -> void:
	_clear_active_tracking()
	_target_pos = Vector2.ZERO
	_companion_pos = Vector2.ZERO


func get_snapshot() -> Dictionary:
	return {
		"starlight_tracking_active": _active,
		"starlight_tracking_phase": _phase,
		"starlight_tracking_holding": _phase == PHASE_PICKUP_HOLD,
		"starlight_tracking_carrying": _phase == PHASE_PICKUP_HOLD or _phase == PHASE_TO_PLAYER,
		"starlight_tracking_hold_remaining": _pickup_hold_timer,
		"starlight_tracking_target_pos": _target_pos,
		"starlight_tracking_companion_pos": _companion_pos,
		"starlight_tracking_last_roll_pct": _last_roll_pct,
		"starlight_tracking_last_success": _last_success,
		"starlight_tracking_last_collected_pos": _last_collected_pos,
		"starlight_tracking_trigger_count": _trigger_count,
		"starlight_tracking_claim_count": _claim_count,
	}


func get_trigger_count_for_tests() -> int:
	return _trigger_count


func is_active_for_tests() -> bool:
	return _active


func _begin_tracking(drop_token: int, drop_pos: Vector2, current_companion_pos: Vector2) -> void:
	_active = true
	_phase = PHASE_TO_DROP
	_target_token = drop_token
	_target_pos = drop_pos
	_companion_pos = current_companion_pos if current_companion_pos != Vector2.ZERO else drop_pos


func _clear_active_tracking() -> void:
	_active = false
	_phase = PHASE_NONE
	_target_token = 0
	_pickup_hold_timer = 0.0


func _sync_drop_claim_state(drop: Dictionary) -> void:
	drop[DROP_ACTIVE_KEY] = true
	drop[DROP_COMPANION_POS_KEY] = _companion_pos
	if _phase == PHASE_PICKUP_HOLD or _phase == PHASE_TO_PLAYER:
		drop[DROP_CARRYING_KEY] = true
		drop[DROP_HOLD_REMAINING_KEY] = _pickup_hold_timer
		drop["pos"] = _companion_pos
		drop["vel"] = Vector2.ZERO
		drop["life"] = maxf(float(drop.get("life", 0.0)), CARRIED_DROP_MIN_LIFE)
	else:
		drop[DROP_CARRYING_KEY] = false
		drop[DROP_HOLD_REMAINING_KEY] = 0.0


func _is_enabled(passive_skill: Dictionary, companion_active: bool) -> bool:
	return companion_active and str(passive_skill.get("id", "")).strip_edges().to_lower() == PASSIVE_ID


func _ensure_drop_token(drop: Dictionary) -> int:
	var token := int(drop.get(DROP_TOKEN_KEY, 0))
	if token <= 0:
		token = _next_token
		_next_token += 1
		drop[DROP_TOKEN_KEY] = token
	return token


func _roll_percent(drop: Dictionary) -> float:
	if drop.has(DROP_FORCE_ROLL_KEY):
		return clampf(float(drop.get(DROP_FORCE_ROLL_KEY, 100.0)), 0.0, 100.0)
	return randf() * 100.0


func _resolve_companion_pos(current_companion_pos: Vector2) -> Vector2:
	if _companion_pos != Vector2.ZERO:
		return _companion_pos
	if current_companion_pos != Vector2.ZERO:
		return current_companion_pos
	return _target_pos


func _get_drop_pos(drop: Dictionary) -> Vector2:
	var value: Variant = drop.get("pos", Vector2.ZERO)
	return value if value is Vector2 else Vector2.ZERO
