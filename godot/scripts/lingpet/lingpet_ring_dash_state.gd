extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

const PASSIVE_ID := "lingpet_ring_dash"
const MOTION_STYLE_PATROL := "patrol"
const FORCE_ROLL_OWNER_KEY := "lingpet_ring_dash_force_roll_pct"
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const BALL_RADIUS_FALLBACK := 14.3
const DEFAULT_CHANCE_PCT := 14.0
const DEFAULT_COOLDOWN_SECONDS := 12.0
const DEFAULT_MIN_DISTANCE := 130.0
const DEFAULT_LOOKAHEAD_GAP := 110.0
const DEFAULT_REAPPEAR_DELAY_SECONDS := 0.06
const DASH_HOLD_SECONDS := 0.22

var _active := false
var _target_pos := Vector2.ZERO
var _dash_pos := Vector2.ZERO
var _cooldown := 0.0
var _hold_timer := 0.0
var _visual_hidden_timer := 0.0
var _last_roll_pct := -1.0
var _last_trigger_pos := Vector2.ZERO
var _trigger_count := 0
var _rolled_this_descent := false


func advance(
	delta: float,
	owner: Object,
	passive_skill: Dictionary,
	companion_active: bool,
	current_companion_pos: Vector2,
	catch_width: float,
	catch_height: float,
	motion_style: String = MOTION_STYLE_PATROL
) -> Dictionary:
	var safe_delta := maxf(0.0, delta)
	_cooldown = maxf(0.0, _cooldown - safe_delta)
	_visual_hidden_timer = maxf(0.0, _visual_hidden_timer - safe_delta)
	if not _is_enabled(passive_skill, companion_active):
		reset_round_transients()
		return {}
	if owner == null or current_companion_pos == Vector2.ZERO:
		_cancel_dash()
		return {}
	_update_descent_roll_lock(owner)
	if _active:
		return _advance_active_dash(safe_delta, owner, passive_skill, current_companion_pos, catch_width, catch_height)
	if _cooldown > 0.0:
		return {}
	var is_ground_pet := motion_style.strip_edges().to_lower() == MOTION_STYLE_PATROL
	var target_data := _build_target_data(owner, passive_skill, current_companion_pos, catch_width, catch_height, true, is_ground_pet)
	if target_data.is_empty():
		return {}
	if _rolled_this_descent:
		# This descent already consumed its single Linkport roll; do not re-roll per frame.
		return {}
	var chance_pct := maxf(0.0, float(passive_skill.get("ring_dash_chance_pct", DEFAULT_CHANCE_PCT)))
	_last_roll_pct = _roll_percent(owner)
	_rolled_this_descent = true
	if _last_roll_pct > chance_pct:
		return {
			"rolled": true,
			"started": false,
			"roll_pct": _last_roll_pct,
			"chance_pct": chance_pct,
		}
	_active = true
	_target_pos = target_data.get("target_pos", current_companion_pos)
	_dash_pos = _target_pos
	_hold_timer = DASH_HOLD_SECONDS
	_visual_hidden_timer = maxf(0.0, float(passive_skill.get("ring_dash_reappear_delay_seconds", DEFAULT_REAPPEAR_DELAY_SECONDS)))
	_cooldown = maxf(0.0, float(passive_skill.get("ring_dash_cooldown_seconds", DEFAULT_COOLDOWN_SECONDS)))
	_last_trigger_pos = _target_pos
	_trigger_count += 1
	return _build_dash_result(true)


func has_companion_position_override() -> bool:
	return _active and _dash_pos != Vector2.ZERO


func get_companion_position_override(fallback: Vector2) -> Vector2:
	return _dash_pos if has_companion_position_override() else fallback


func is_companion_visual_hidden() -> bool:
	return _active and _visual_hidden_timer > 0.0


func reset_all() -> void:
	reset_round_transients()
	_last_roll_pct = -1.0
	_last_trigger_pos = Vector2.ZERO
	_trigger_count = 0


func reset_round_transients() -> void:
	_cancel_dash()
	_cooldown = 0.0
	_rolled_this_descent = false


func get_snapshot() -> Dictionary:
	return {
		"ring_dash_active": _active,
		"ring_dash_target_pos": _target_pos,
		"ring_dash_companion_pos": _dash_pos,
		"ring_dash_cooldown": _cooldown,
		"ring_dash_last_roll_pct": _last_roll_pct,
		"ring_dash_last_trigger_pos": _last_trigger_pos,
		"ring_dash_trigger_count": _trigger_count,
		"ring_dash_visual_hidden": is_companion_visual_hidden(),
		"ring_dash_reappear_delay": _visual_hidden_timer,
		"ring_dash_rolled_this_descent": _rolled_this_descent,
	}


func get_trigger_count_for_tests() -> int:
	return _trigger_count


func is_active_for_tests() -> bool:
	return _active


func _advance_active_dash(
	delta: float,
	owner: Object,
	_passive_skill: Dictionary,
	current_companion_pos: Vector2,
	_catch_width: float,
	catch_height: float
) -> Dictionary:
	if not _ball_still_needs_guard(owner, current_companion_pos, catch_height):
		_cancel_dash()
		return {}
	_hold_timer = maxf(0.0, _hold_timer - delta)
	return _build_dash_result(false)


func _build_dash_result(started: bool) -> Dictionary:
	return {
		"active": true,
		"started": started,
		"companion_pos": _dash_pos,
		"target_pos": _target_pos,
		"visual_hidden": is_companion_visual_hidden(),
	}


func _build_target_data(
	owner: Object,
	passive_skill: Dictionary,
	current_companion_pos: Vector2,
	catch_width: float,
	catch_height: float,
	require_emergency: bool,
	is_ground_pet: bool
) -> Dictionary:
	if not bool(BattleSceneOwnerReader.get_value(owner, "ball_active", false)):
		return {}
	var ball_vel: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "ball_vel", Vector2.ZERO)
	if ball_vel.y <= 0.0:
		return {}
	var ball_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "ball_pos", Vector2.ZERO)
	var ball_radius := maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "ball_size", BALL_RADIUS_FALLBACK * 2.0)) * 0.5)
	var half_height := maxf(1.0, catch_height * 0.5)
	# Ground (patrol) lingpets cannot move into the air, so the Linkport teleport must keep
	# the companion's own ground-lane Y and only shift X. Diving to the player guard-center Y
	# pops the pet upward by guard_y - patrol_lane_y -- negligible at the 50px base paddle but
	# a visible upward jump once a paddle-height perk/item raises the paddle. Flight pets keep
	# the guard-center dive because they can legitimately move to the ball.
	var target_y := current_companion_pos.y if is_ground_pet else _resolve_player_guard_center_y(owner, catch_height, ball_radius)
	var vertical_gap := (target_y - half_height) - (ball_pos.y + ball_radius)
	if vertical_gap < -ball_radius:
		return {}
	var lookahead_gap := maxf(1.0, float(passive_skill.get("ring_dash_lookahead_gap", DEFAULT_LOOKAHEAD_GAP)))
	if vertical_gap > lookahead_gap:
		return {}
	var impact_boost := maxf(0.01, float(BattleSceneOwnerReader.get_value(owner, "ball_impact_boost", 1.0)))
	var frames_to_contact := maxf(0.0, vertical_gap) / maxf(0.01, ball_vel.y * impact_boost)
	var future_ball_x := ball_pos.x + ball_vel.x * impact_boost * frames_to_contact
	var half_width := maxf(1.0, catch_width * 0.5)
	var target_x := clampf(future_ball_x, half_width + ball_radius, FIELD_WIDTH - half_width - ball_radius)
	if require_emergency:
		if _player_can_block(owner, target_x, ball_radius):
			return {}
		var min_distance := maxf(0.0, float(passive_skill.get("ring_dash_min_distance", DEFAULT_MIN_DISTANCE)))
		if absf(target_x - current_companion_pos.x) < min_distance:
			return {}
	return {
		"target_pos": Vector2(target_x, target_y),
		"frames_to_contact": frames_to_contact,
	}


func _ball_still_needs_guard(owner: Object, current_companion_pos: Vector2, catch_height: float) -> bool:
	if not bool(BattleSceneOwnerReader.get_value(owner, "ball_active", false)):
		return false
	var ball_vel: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "ball_vel", Vector2.ZERO)
	if ball_vel.y <= 0.0:
		return false
	var ball_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "ball_pos", Vector2.ZERO)
	var ball_radius := maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "ball_size", BALL_RADIUS_FALLBACK * 2.0)) * 0.5)
	var half_height := maxf(1.0, catch_height * 0.5)
	if ball_pos.y - ball_radius > current_companion_pos.y + half_height + ball_radius:
		return _hold_timer > 0.0
	return true


func _player_can_block(owner: Object, future_ball_x: float, ball_radius: float) -> bool:
	var player_size := Vector2(
		maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_width", 155.0))),
		maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_height", 50.0)))
	)
	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "player_pos", Vector2(FIELD_WIDTH * 0.5 - player_size.x * 0.5, 0.0))
	return future_ball_x >= player_pos.x - ball_radius and future_ball_x <= player_pos.x + player_size.x + ball_radius


func _resolve_player_guard_center_y(owner: Object, catch_height: float, ball_radius: float) -> float:
	var player_height := maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_height", 50.0)))
	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(
		owner,
		"player_pos",
		Vector2(FIELD_WIDTH * 0.5 - 77.5, FIELD_HEIGHT - player_height)
	)
	var half_height := maxf(1.0, catch_height * 0.5)
	var guard_y := player_pos.y + half_height
	return clampf(guard_y, half_height + ball_radius, FIELD_HEIGHT - half_height - ball_radius)


func _roll_percent(owner: Object) -> float:
	var forced_roll: float = float(BattleSceneOwnerReader.get_value(owner, FORCE_ROLL_OWNER_KEY, -1.0))
	if forced_roll >= 0.0:
		return clampf(forced_roll, 0.0, 100.0)
	return randf() * 100.0


func _cancel_dash() -> void:
	_active = false
	_target_pos = Vector2.ZERO
	_dash_pos = Vector2.ZERO
	_hold_timer = 0.0
	_visual_hidden_timer = 0.0


func _update_descent_roll_lock(owner: Object) -> void:
	# Linkport must roll ONCE per descent opportunity, not once per frame. The ball
	# sits in the lower guard band for many frames, so a per-frame roll compounds to
	# 1 - (1 - p)^N: the Lv.1 12% saturates to ~70% and the Lv.5 32% to ~99%, which
	# makes every passive level feel identical in play. Clear the lock whenever the
	# ball is not descending toward the player floor so the next descent becomes a
	# fresh single roll whose success rate matches the displayed chance_pct.
	if not bool(BattleSceneOwnerReader.get_value(owner, "ball_active", false)):
		_rolled_this_descent = false
		return
	var ball_vel: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "ball_vel", Vector2.ZERO)
	if ball_vel.y <= 0.0:
		_rolled_this_descent = false


func _is_enabled(passive_skill: Dictionary, companion_active: bool) -> bool:
	return companion_active and str(passive_skill.get("id", "")).strip_edges().to_lower() == PASSIVE_ID
