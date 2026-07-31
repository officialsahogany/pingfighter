extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const SmasherDashActiveMotionResolver := preload("res://scripts/characters/smasher_dash_active_motion_resolver.gd")

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
	motion_style: String = MOTION_STYLE_PATROL,
	player_dash: Dictionary = {},
	player_guard_available: bool = true
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
	var target_data := _build_target_data(owner, passive_skill, current_companion_pos, catch_width, catch_height, true, is_ground_pet, player_dash, player_guard_available)
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


# Stow ends an in-flight Linkport immediately, but intentionally preserves the
# remaining cooldown and the per-descent roll lock. Clearing either here would
# let Ctrl/R3 stow-resummon reroll the same defensive opportunity.
func end_for_stow() -> void:
	_cancel_dash()


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
	is_ground_pet: bool,
	player_dash: Dictionary = {},
	player_guard_available: bool = true
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
		if player_guard_available:
			if _player_can_block(owner, target_x, ball_radius):
				return {}
			if _player_dash_projects_block(owner, player_dash, target_x, ball_radius, frames_to_contact):
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
	var player_size := _resolve_player_paddle_size(owner)
	var player_pos := _resolve_player_paddle_pos(owner, player_size)
	return future_ball_x >= player_pos.x - ball_radius and future_ball_x <= player_pos.x + player_size.x + ball_radius


# `_player_can_block`은 패들의 "현재 정지 스팬"만 본다. 플레이어가 이미 공 쪽으로
# 대쉬를 커밋한 프레임에는 접촉 X가 아직 그 스팬 밖이라 "못 막는다"로 오판하고,
# 링크포트가 같은 공을 향해 동시 발동한다 = 이중수비(2026-07-06 신고).
# 대쉬는 발동 후 방향/지속이 확정된 스크립트 이동이므로 접촉 시점 위치를 투영할 수
# 있다. 잔여 이동거리를 frames_to_contact로 캡해(공이 먼저 도착하면 대쉬는 그만큼만
# 진행) 접촉 시점의 패들 스팬이 공을 덮는지 판정한다.
# 반대 방향 대쉬나 접촉까지 닿지 못하는 짧은 잔여 타이머는 실제로 못 막으므로
# 보류하지 않는다 — "대쉬 중이면 무조건 보류"는 링크포트를 죽인다.
func _player_dash_projects_block(
	owner: Object,
	player_dash: Dictionary,
	future_ball_x: float,
	ball_radius: float,
	frames_to_contact: float
) -> bool:
	if not bool(player_dash.get("active", false)):
		return false
	var direction := signf(float(player_dash.get("direction", 0.0)))
	if is_zero_approx(direction):
		return false
	var dash_timer := maxf(0.0, float(player_dash.get("timer", 0.0)))
	if dash_timer <= 0.0:
		return false
	var travel_frames := clampf(frames_to_contact, 0.0, dash_timer)
	if travel_frames <= 0.0:
		return false
	var travel := _resolve_dash_travel(
		dash_timer,
		travel_frames,
		maxf(0.0, float(player_dash.get("dash_distance_multiplier", 1.0)))
	)
	if travel <= 0.0:
		return false
	var player_size := _resolve_player_paddle_size(owner)
	var player_pos := _resolve_player_paddle_pos(owner, player_size)
	# 라이브 대쉬와 동일한 클램프(play_left 0 ~ play_right - paddle_width, 플레이필드는
	# 전체 캔버스) -- 벽에 붙은 대쉬가 벽을 뚫고 커버하는 것처럼 계산되면 안 된다.
	var projected_x := clampf(
		player_pos.x + direction * travel,
		0.0,
		maxf(0.0, FIELD_WIDTH - player_size.x)
	)
	return future_ball_x >= projected_x - ball_radius and future_ball_x <= projected_x + player_size.x + ball_radius


# 대쉬 감속 커브는 shipped resolver가 단일 소유한다(상수를 여기 다시 타이핑하면
# 커브가 갈린다). compute_total_dash_distance는 timer가 0까지 내려가는 적분이므로
# total(timer) - total(timer - n) = "앞으로 n프레임 동안 갈 거리"가 된다.
func _resolve_dash_travel(dash_timer: float, frames: float, distance_multiplier: float) -> float:
	var full := SmasherDashActiveMotionResolver.compute_total_dash_distance(dash_timer, distance_multiplier)
	var remaining_after := SmasherDashActiveMotionResolver.compute_total_dash_distance(
		maxf(0.0, dash_timer - frames),
		distance_multiplier
	)
	return maxf(0.0, full - remaining_after)


func _resolve_player_paddle_size(owner: Object) -> Vector2:
	return Vector2(
		maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_width", 155.0))),
		maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_height", 50.0)))
	)


func _resolve_player_paddle_pos(owner: Object, player_size: Vector2) -> Vector2:
	return BattleSceneOwnerReader.get_vector2(owner, "player_pos", Vector2(FIELD_WIDTH * 0.5 - player_size.x * 0.5, 0.0))


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
