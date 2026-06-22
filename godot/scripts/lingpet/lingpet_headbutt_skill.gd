extends RefCounted

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const DASH_SPEED := 1080.0
const DASH_RADIUS := 31.0
const HOMING_TURN_RATE := 7.25
const HOMING_LEAD_SECONDS := 0.12
const IMPACT_SECONDS := 0.34
const MISS_FLASH_SECONDS := 0.24
const KNOCKBACK_DISTANCE := 150.0
const IMPACT_NUDGE_DISTANCE := 24.0
const KNOCKBACK_VELOCITY := 13.0
const KNOCKBACK_FRAMES := 30.0
const KNOCKBACK_DECAY := 0.91
const MOVING_MISS_SPEED_THRESHOLD := 2.0
const GUARANTEED_MISS_SPEED := 18.0
const MOVING_MISS_CHANCE := 0.14
const MOVING_MISS_MAX_CHANCE := 0.34
const MISS_OFFSET_X := 130.0
const MISS_TEXT := "MISS!"
const MISS_TEXT_SECONDS := 0.85
const MISS_TEXT_FLOAT_Y := 34.0
const TRAIL_MAX_POINTS := 12
const COMBO_MIN_COUNT := 1
const COMBO_MAX_COUNT := 3
const COMBO_COUNT_BY_LEVEL := [1, 1, 2, 2, 3]
const KNOCKBACK_SCALE_BY_LEVEL := [1.10, 1.175, 1.25, 1.325, 1.40]
const MEGA_CHANCE_BY_LEVEL := [0.0, 0.0, 0.20, 0.20, 0.25]
const MEGA_KNOCKBACK_BONUS_PCT_BY_LEVEL := [0.0, 0.0, 0.30, 0.30, 0.50]
const MEGA_STUN_SECONDS_BY_LEVEL := [0.0, 0.0, 1.0, 1.0, 1.5]
const MEGA_CHARGE_SECONDS := 2.0
const MEGA_STUN_SOURCE := "lingpet_headbutt_mega"
const REPEAT_DELAY_MIN_SECONDS := 1.0
const REPEAT_DELAY_MAX_SECONDS := 2.0
const REPEAT_RECOIL_DISTANCE_Y := 92.0
const REPEAT_RECOIL_DURATION_RATIO := 0.42
const REPEAT_RECOIL_MIN_SECONDS := 0.30
const REPEAT_RECOIL_MAX_SECONDS := 0.58
const REPEAT_LOITER_RADIUS_X := 34.0
const REPEAT_LOITER_RADIUS_Y := 14.0
const REPEAT_LOITER_ANGULAR_SPEED := 8.2

var _active := false
var _planned_miss := false
var _pos := Vector2.ZERO
var _target := Vector2.ZERO
var _dash_dir := Vector2(0.0, -1.0)
var _trail: Array[Vector2] = []
var _impact_pos := Vector2.ZERO
var _impact_timer := 0.0
var _miss_timer := 0.0
var _miss_text_timer := 0.0
var _miss_text_pos := Vector2.ZERO
var _repeat_wait_timer := 0.0
var _repeat_anchor_pos := Vector2.ZERO
var _repeat_recoil_start_pos := Vector2.ZERO
var _repeat_wait_duration := 0.0
var _repeat_loiter_phase := 0.0
var _combo_total := 0
var _combo_index := 0
var _active_skill_level := 1
var _knockback_scale := 1.0
var _is_mega := false
var _mega_charge_timer := 0.0
var _mega_charge_origin := Vector2.ZERO
var _mega_stun_seconds := 0.0
var _mega_knockback_bonus := 0.0
var _mega_chance := 0.0
var _last_mega_roll := 1.0
var _force_mega_roll := -1.0
var _mega_impact := false
var _strike_request_count := 0
var _last_result := ""
var _last_miss_reason := ""
var _last_knockback_velocity := 0.0
var _hit_count := 0
var _miss_count := 0
var _last_boss_pos := Vector2.ZERO
var _has_last_boss_pos := false


func reset() -> void:
	_active = false
	_planned_miss = false
	_pos = Vector2.ZERO
	_target = Vector2.ZERO
	_dash_dir = Vector2(0.0, -1.0)
	_trail.clear()
	_impact_pos = Vector2.ZERO
	_impact_timer = 0.0
	_miss_timer = 0.0
	_miss_text_timer = 0.0
	_miss_text_pos = Vector2.ZERO
	_repeat_wait_timer = 0.0
	_repeat_anchor_pos = Vector2.ZERO
	_repeat_recoil_start_pos = Vector2.ZERO
	_repeat_wait_duration = 0.0
	_repeat_loiter_phase = 0.0
	_combo_total = 0
	_combo_index = 0
	_active_skill_level = 1
	_knockback_scale = 1.0
	_is_mega = false
	_mega_charge_timer = 0.0
	_mega_charge_origin = Vector2.ZERO
	_mega_stun_seconds = 0.0
	_mega_knockback_bonus = 0.0
	_mega_chance = 0.0
	_last_mega_roll = 1.0
	_mega_impact = false
	_strike_request_count = 0
	_last_result = ""
	_last_miss_reason = ""
	_last_knockback_velocity = 0.0
	_last_boss_pos = Vector2.ZERO
	_has_last_boss_pos = false


func prewarm() -> void:
	pass


func can_arm(params: Dictionary) -> bool:
	if not bool(params.get("companion_visible", false)):
		return false
	var companion_pos: Vector2 = _as_vector2(params.get("companion_pos", Vector2.ZERO), Vector2.ZERO)
	return _is_companion_onscreen(companion_pos)


func launch(origin: Vector2, owner: Object, launch_context: Dictionary = {}) -> bool:
	if owner == null:
		return false
	_active_skill_level = _get_active_skill_level(launch_context)
	_knockback_scale = _resolve_knockback_scale(launch_context)
	_is_mega = _roll_mega(launch_context)
	_mega_stun_seconds = _resolve_mega_stun_seconds(launch_context) if _is_mega else 0.0
	_mega_knockback_bonus = _resolve_mega_knockback_bonus(launch_context) if _is_mega else 0.0
	_mega_impact = false
	_combo_total = 1 if _is_mega else _resolve_combo_total(launch_context)
	_combo_index = 1
	_repeat_wait_timer = 0.0
	_repeat_anchor_pos = origin
	_repeat_recoil_start_pos = origin
	_repeat_wait_duration = 0.0
	_repeat_loiter_phase = 0.0
	_strike_request_count = 0
	if _is_mega:
		_mega_charge_origin = origin
		_mega_charge_timer = MEGA_CHARGE_SECONDS
		_pos = origin
		_last_result = "mega_charging"
		_remember_boss_pos(_get_boss_rect(owner).position)
		return true
	return _begin_dash(origin, owner)


func _begin_dash(origin: Vector2, owner: Object) -> bool:
	if owner == null:
		return false
	var boss_rect: Rect2 = _get_boss_rect(owner)
	_pos = origin
	_target = _get_homing_target(owner, boss_rect)
	_trail.clear()
	_trail.append(_pos)
	var moving_speed: float = _get_boss_moving_speed(owner, boss_rect.position)
	_planned_miss = _should_miss_moving_target(origin, boss_rect.position, moving_speed)
	if _planned_miss:
		var boss_center: Vector2 = boss_rect.get_center()
		var boss_vel: float = float(_get_owner_value(owner, "boss_vel", 0.0))
		var miss_dir: float = float(sign(boss_vel))
		if absf(miss_dir) <= 0.01:
			miss_dir = float(sign(boss_center.x - origin.x))
		if absf(miss_dir) <= 0.01:
			miss_dir = 1.0
		_target.x = clampf(boss_center.x + miss_dir * (boss_rect.size.x * 0.55 + MISS_OFFSET_X), -80.0, FIELD_WIDTH + 80.0)
		_target.y = boss_center.y + 18.0
		_last_miss_reason = "moving_target"
	else:
		_last_miss_reason = ""
	var to_target: Vector2 = _target - _pos
	if to_target.length_squared() <= 1.0:
		_dash_dir = Vector2(0.0, -1.0)
	else:
		_dash_dir = to_target.normalized()
	_active = true
	_last_result = "charging"
	_strike_request_count += 1
	_remember_boss_pos(boss_rect.position)
	return true


func update(delta: float, owner: Object, registry: Object = null) -> void:
	var safe_delta: float = maxf(0.0, delta)
	_impact_timer = maxf(0.0, _impact_timer - safe_delta)
	_miss_timer = maxf(0.0, _miss_timer - safe_delta)
	_miss_text_timer = maxf(0.0, _miss_text_timer - safe_delta)
	if _mega_charge_timer > 0.0:
		_mega_charge_timer = maxf(0.0, _mega_charge_timer - safe_delta)
		if _mega_charge_timer <= 0.0:
			_begin_dash(_mega_charge_origin, owner)
		else:
			_pos = _mega_charge_origin
			_remember_boss_pos(_get_boss_rect(owner).position)
	elif _active:
		_step_dash(safe_delta, owner, registry)
	elif _repeat_wait_timer > 0.0:
		_repeat_wait_timer = maxf(0.0, _repeat_wait_timer - safe_delta)
		if _repeat_wait_timer <= 0.0 and _combo_index < _combo_total:
			var repeat_origin := _get_repeat_wait_position()
			_combo_index += 1
			if not _begin_dash(repeat_origin, owner):
				_repeat_wait_timer = 0.0
		else:
			_pos = _get_repeat_wait_position()
			_remember_boss_pos(_get_boss_rect(owner).position)
	else:
		_remember_boss_pos(_get_boss_rect(owner).position)


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	if _mega_charge_timer > 0.0:
		_draw_mega_charge(canvas, _mega_charge_origin + shake_offset)
	if _active:
		_draw_dash(canvas, shake_offset)
	if _impact_timer > 0.0:
		_draw_impact(canvas, _impact_pos + shake_offset, _impact_timer / IMPACT_SECONDS, true)
		if _mega_impact:
			_draw_mega_impact(canvas, _impact_pos + shake_offset, _impact_timer / IMPACT_SECONDS)
	if _miss_timer > 0.0:
		_draw_impact(canvas, _impact_pos + shake_offset, _miss_timer / MISS_FLASH_SECONDS, false)
	if _miss_text_timer > 0.0:
		_draw_miss_text(canvas, shake_offset)


func has_visible_effects() -> bool:
	return _active or _impact_timer > 0.0 or _miss_timer > 0.0 or _miss_text_timer > 0.0 or _repeat_wait_timer > 0.0 or _mega_charge_timer > 0.0


func is_active() -> bool:
	return _active or _repeat_wait_timer > 0.0 or _mega_charge_timer > 0.0


func has_companion_position_override() -> bool:
	return _active or _impact_timer > 0.0 or _miss_timer > 0.0 or _repeat_wait_timer > 0.0 or _mega_charge_timer > 0.0


func get_companion_position_override(fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if _mega_charge_timer > 0.0:
		return _mega_charge_origin
	if _active:
		return _pos
	if _repeat_wait_timer > 0.0:
		return _get_repeat_wait_position()
	if _impact_timer > 0.0 or _miss_timer > 0.0:
		return _impact_pos
	return fallback


func consume_companion_strike_request() -> bool:
	if _strike_request_count <= 0:
		return false
	_strike_request_count -= 1
	return true


func get_hit_count_for_tests() -> int:
	return _hit_count


func set_force_mega_roll_for_tests(value: float) -> void:
	_force_mega_roll = value


func get_miss_count_for_tests() -> int:
	return _miss_count


func get_snapshot() -> Dictionary:
	return {
		"headbutt_active": _active,
		"headbutt_pos": _pos,
		"headbutt_target": _target,
		"headbutt_companion_override_active": has_companion_position_override(),
		"headbutt_companion_pos": get_companion_position_override(Vector2.ZERO),
		"headbutt_impact_active": _impact_timer > 0.0,
		"headbutt_impact_timer": _impact_timer,
		"headbutt_miss_active": _miss_timer > 0.0,
		"headbutt_miss_timer": _miss_timer,
		"headbutt_miss_text_active": _miss_text_timer > 0.0,
		"headbutt_miss_text_timer": _miss_text_timer,
		"headbutt_repeat_wait_active": _repeat_wait_timer > 0.0,
		"headbutt_repeat_wait_timer": _repeat_wait_timer,
		"headbutt_repeat_wait_duration": _repeat_wait_duration,
		"headbutt_repeat_delay_min": REPEAT_DELAY_MIN_SECONDS,
		"headbutt_repeat_delay_max": REPEAT_DELAY_MAX_SECONDS,
		"headbutt_repeat_recoil_start_pos": _repeat_recoil_start_pos,
		"headbutt_repeat_recoil_anchor_pos": _repeat_anchor_pos,
		"headbutt_repeat_recoil_distance_y": REPEAT_RECOIL_DISTANCE_Y,
		"headbutt_repeat_loiter_active": _is_repeat_loiter_active(),
		"headbutt_repeat_loiter_radius_x": REPEAT_LOITER_RADIUS_X,
		"headbutt_repeat_loiter_radius_y": REPEAT_LOITER_RADIUS_Y,
		"headbutt_combo_min": COMBO_MIN_COUNT,
		"headbutt_combo_max": COMBO_MAX_COUNT,
		"headbutt_combo_total": _combo_total,
		"headbutt_combo_index": _combo_index,
		"headbutt_combo_remaining": maxi(0, _combo_total - _combo_index),
		"headbutt_last_result": _last_result,
		"headbutt_last_miss_reason": _last_miss_reason,
		"headbutt_hit_count": _hit_count,
		"headbutt_miss_count": _miss_count,
		"headbutt_knockback_distance": KNOCKBACK_DISTANCE,
		"headbutt_impact_nudge_distance": IMPACT_NUDGE_DISTANCE,
		"headbutt_knockback_velocity": _last_knockback_velocity,
		"headbutt_knockback_frames": KNOCKBACK_FRAMES,
		"headbutt_knockback_decay": KNOCKBACK_DECAY,
		"headbutt_active_skill_level": _active_skill_level,
		"headbutt_knockback_scale": _knockback_scale,
		"headbutt_is_mega": _is_mega,
		"headbutt_mega_charging": _mega_charge_timer > 0.0,
		"headbutt_mega_charge_timer": _mega_charge_timer,
		"headbutt_mega_charge_seconds": MEGA_CHARGE_SECONDS,
		"headbutt_mega_chance": _mega_chance,
		"headbutt_mega_last_roll": _last_mega_roll,
		"headbutt_mega_stun_seconds": _mega_stun_seconds,
		"headbutt_mega_knockback_bonus": _mega_knockback_bonus,
		"headbutt_mega_impact": _mega_impact,
		"headbutt_moving_miss_speed_threshold": MOVING_MISS_SPEED_THRESHOLD,
		"headbutt_guaranteed_miss_speed": GUARANTEED_MISS_SPEED,
		"headbutt_moving_miss_chance": MOVING_MISS_CHANCE,
		"headbutt_moving_miss_max_chance": MOVING_MISS_MAX_CHANCE,
	}


func _step_dash(delta: float, owner: Object, registry: Object) -> void:
	if delta <= 0.0:
		return
	_trail.append(_pos)
	while _trail.size() > TRAIL_MAX_POINTS:
		_trail.remove_at(0)
	var boss_rect: Rect2 = _get_boss_rect(owner)
	if not _planned_miss:
		_target = _get_homing_target(owner, boss_rect)
		_steer_toward_target(delta)
	var remaining: float = (_target - _pos).length()
	var step_distance: float = DASH_SPEED * delta
	if step_distance >= remaining:
		_pos = _target
	else:
		_pos += _dash_dir * step_distance
	if not _planned_miss and _circle_hits_rect(_pos, DASH_RADIUS, boss_rect):
		_resolve_hit(owner, registry, boss_rect)
		return
	if step_distance >= remaining:
		_resolve_miss()
		return
	_remember_boss_pos(boss_rect.position)


func _resolve_hit(owner: Object, registry: Object, boss_rect: Rect2) -> void:
	_active = false
	_planned_miss = false
	_impact_pos = _pos
	_impact_timer = IMPACT_SECONDS
	_miss_timer = 0.0
	_last_result = "mega_hit" if _is_mega else "hit"
	_mega_impact = _is_mega
	_last_miss_reason = ""
	_hit_count += 1
	var boss_pos: Vector2 = boss_rect.position
	var boss_w: float = boss_rect.size.x
	var direction: float = float(sign(_dash_dir.x))
	if absf(direction) <= 0.01:
		direction = 1.0 if boss_rect.get_center().x <= FIELD_WIDTH * 0.5 else -1.0
	var next_pos := boss_pos
	var effective_scale := _knockback_scale * (1.0 + maxf(0.0, _mega_knockback_bonus))
	_last_knockback_velocity = direction * KNOCKBACK_VELOCITY * effective_scale
	var impact_nudge := 0.0
	if _is_mega and _mega_stun_seconds > 0.0:
		# Mega: the boss is stunned, and boss_ai's stun branch OWNS boss movement and
		# returns BEFORE the paddle-hit knockback channel. So the strong knockback must
		# ride the stun status (knockback_vel/frames/decay) like milk_shot/gatling -- the
		# separate paddle-hit channel would be silently bypassed here. Keep a small nudge.
		_apply_boss_stun(registry, _mega_stun_seconds, _last_knockback_velocity)
		impact_nudge = direction * IMPACT_NUDGE_DISTANCE
	else:
		var ai_knockback_applied := _apply_ai_knockback(registry, _last_knockback_velocity)
		impact_nudge = direction * (IMPACT_NUDGE_DISTANCE if ai_knockback_applied else KNOCKBACK_DISTANCE * effective_scale)
	next_pos.x = clampf(boss_pos.x + impact_nudge, 0.0, maxf(0.0, FIELD_WIDTH - boss_w))
	if owner != null:
		owner.set("boss_pos", next_pos)
		if owner.get("boss_vel") != null:
			owner.set("boss_vel", _last_knockback_velocity)
	_play_boomerang_hit(registry)
	_trail.clear()
	_remember_boss_pos(next_pos)
	_schedule_next_dash_or_finish()


func _resolve_miss() -> void:
	_active = false
	_planned_miss = false
	_impact_pos = _pos
	_miss_timer = MISS_FLASH_SECONDS
	_miss_text_timer = MISS_TEXT_SECONDS
	_miss_text_pos = _pos
	_impact_timer = 0.0
	_last_result = "miss"
	_miss_count += 1
	_trail.clear()
	_schedule_next_dash_or_finish()


func _schedule_next_dash_or_finish() -> void:
	if _combo_index < _combo_total:
		_repeat_recoil_start_pos = _impact_pos
		_repeat_anchor_pos = _get_repeat_recoil_anchor_pos(_impact_pos)
		_repeat_wait_timer = _pick_repeat_delay()
		_repeat_wait_duration = _repeat_wait_timer
		_repeat_loiter_phase = _deterministic_unit(_impact_pos + Vector2(17.0, -29.0), _target, 8.0 + float(_combo_index)) * TAU
		_pos = _impact_pos
	else:
		_repeat_wait_timer = 0.0
		_repeat_wait_duration = 0.0
		_repeat_loiter_phase = 0.0


func _get_repeat_wait_position() -> Vector2:
	if _repeat_wait_duration <= 0.0:
		return _repeat_anchor_pos
	var elapsed := clampf(_repeat_wait_duration - _repeat_wait_timer, 0.0, _repeat_wait_duration)
	var recoil_duration := _get_repeat_recoil_duration()
	var progress := clampf(elapsed / maxf(0.001, recoil_duration), 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	if progress < 1.0:
		return _repeat_recoil_start_pos.lerp(_repeat_anchor_pos, eased)
	return _get_repeat_loiter_position(elapsed - recoil_duration)


func _get_repeat_recoil_duration() -> float:
	return clampf(
		_repeat_wait_duration * REPEAT_RECOIL_DURATION_RATIO,
		REPEAT_RECOIL_MIN_SECONDS,
		REPEAT_RECOIL_MAX_SECONDS
	)


func _get_repeat_loiter_position(loiter_elapsed: float) -> Vector2:
	var safe_elapsed := maxf(0.0, loiter_elapsed)
	var phase := _repeat_loiter_phase + safe_elapsed * REPEAT_LOITER_ANGULAR_SPEED
	var x_offset := sin(phase) * REPEAT_LOITER_RADIUS_X
	var y_offset := sin(phase * 1.65 + 0.55) * REPEAT_LOITER_RADIUS_Y
	return Vector2(
		clampf(_repeat_anchor_pos.x + x_offset, 20.0, FIELD_WIDTH - 20.0),
		clampf(_repeat_anchor_pos.y + y_offset, 40.0, FIELD_HEIGHT - 48.0)
	)


func _is_repeat_loiter_active() -> bool:
	if _repeat_wait_timer <= 0.0 or _repeat_wait_duration <= 0.0:
		return false
	var elapsed := clampf(_repeat_wait_duration - _repeat_wait_timer, 0.0, _repeat_wait_duration)
	return elapsed >= _get_repeat_recoil_duration()


func _get_repeat_recoil_anchor_pos(from_pos: Vector2) -> Vector2:
	return Vector2(
		clampf(from_pos.x, 20.0, FIELD_WIDTH - 20.0),
		clampf(from_pos.y + REPEAT_RECOIL_DISTANCE_Y, 40.0, FIELD_HEIGHT - 48.0)
	)


func _steer_toward_target(delta: float) -> void:
	var offset := _target - _pos
	if offset.length_squared() <= 1.0:
		return
	var desired_dir := offset.normalized()
	var turn_angle := clampf(_dash_dir.angle_to(desired_dir), -HOMING_TURN_RATE * delta, HOMING_TURN_RATE * delta)
	_dash_dir = _dash_dir.rotated(turn_angle).normalized()


func _get_homing_target(owner: Object, boss_rect: Rect2) -> Vector2:
	var target := boss_rect.get_center()
	var boss_vel := float(_get_owner_value(owner, "boss_vel", 0.0))
	target.x += boss_vel * 60.0 * HOMING_LEAD_SECONDS
	target.x = clampf(target.x, boss_rect.size.x * 0.5, FIELD_WIDTH - boss_rect.size.x * 0.5)
	return target


func _should_miss_moving_target(origin: Vector2, boss_pos: Vector2, moving_speed: float) -> bool:
	if moving_speed < MOVING_MISS_SPEED_THRESHOLD:
		return false
	if moving_speed >= GUARANTEED_MISS_SPEED:
		return true
	var roll := _deterministic_unit(origin, boss_pos, moving_speed)
	var speed_ratio := clampf(
		(moving_speed - MOVING_MISS_SPEED_THRESHOLD) / (GUARANTEED_MISS_SPEED - MOVING_MISS_SPEED_THRESHOLD),
		0.0,
		1.0
	)
	var miss_chance := lerpf(MOVING_MISS_CHANCE, MOVING_MISS_MAX_CHANCE, speed_ratio)
	return roll < miss_chance


func _get_active_skill_level(launch_context: Dictionary) -> int:
	return clampi(int(launch_context.get("active_skill_level", launch_context.get("skill_level", 1))), 1, 5)


func _resolve_combo_total(launch_context: Dictionary) -> int:
	var provided := int(round(float(launch_context.get("headbutt_count", -1.0))))
	if provided >= COMBO_MIN_COUNT:
		return clampi(provided, COMBO_MIN_COUNT, COMBO_MAX_COUNT)
	return clampi(int(round(_get_level_array_value(COMBO_COUNT_BY_LEVEL, 1.0))), COMBO_MIN_COUNT, COMBO_MAX_COUNT)


func _resolve_knockback_scale(launch_context: Dictionary) -> float:
	var provided := float(launch_context.get("knockback_scale", -1.0))
	if provided > 0.0:
		return provided
	return _get_level_array_value(KNOCKBACK_SCALE_BY_LEVEL, 1.0)


func _get_level_array_value(values: Array, fallback: float) -> float:
	if values.is_empty():
		return fallback
	var index := clampi(_active_skill_level, 1, values.size()) - 1
	return float(values[index])


func _roll_mega(launch_context: Dictionary) -> bool:
	_mega_chance = _resolve_mega_chance(launch_context)
	if _mega_chance <= 0.0:
		_last_mega_roll = 1.0
		return false
	_last_mega_roll = _consume_mega_roll(launch_context)
	return _last_mega_roll < _mega_chance


func _resolve_mega_chance(launch_context: Dictionary) -> float:
	var provided := float(launch_context.get("mega_chance", -1.0))
	if provided >= 0.0:
		return clampf(provided, 0.0, 1.0)
	return clampf(_get_level_array_value(MEGA_CHANCE_BY_LEVEL, 0.0), 0.0, 1.0)


func _resolve_mega_stun_seconds(launch_context: Dictionary) -> float:
	var provided := float(launch_context.get("mega_stun_seconds", -1.0))
	if provided >= 0.0:
		return provided
	return _get_level_array_value(MEGA_STUN_SECONDS_BY_LEVEL, 0.0)


func _resolve_mega_knockback_bonus(launch_context: Dictionary) -> float:
	var provided := float(launch_context.get("mega_knockback_bonus_pct", -1.0))
	if provided >= 0.0:
		return provided
	return _get_level_array_value(MEGA_KNOCKBACK_BONUS_PCT_BY_LEVEL, 0.0)


func _consume_mega_roll(launch_context: Dictionary) -> float:
	if _force_mega_roll >= 0.0:
		return clampf(_force_mega_roll, 0.0, 1.0)
	if launch_context.has("headbutt_mega_roll"):
		return clampf(float(launch_context.get("headbutt_mega_roll", 1.0)), 0.0, 1.0)
	return randf()


func _apply_boss_stun(registry: Object, seconds: float, knockback_velocity: float = 0.0) -> void:
	if seconds <= 0.0:
		return
	var status_state := _get_registry_instance(registry, "status_effect_state")
	if status_state == null or not status_state.has_method("apply_status"):
		return
	# Carry the knockback on the stun itself: boss_ai applies the stun-owned knockback
	# (decayed over knockback_frames) while the boss is stunned, instead of the bypassed
	# paddle-hit channel. Mirrors milk_shot / gatling boss-CC.
	var data := {"source": MEGA_STUN_SOURCE}
	if absf(knockback_velocity) > 0.001:
		data["knockback_vel"] = knockback_velocity
		data["knockback_active"] = true
		data["knockback_frames"] = KNOCKBACK_FRAMES
		data["knockback_decay_per_frame"] = KNOCKBACK_DECAY
	status_state.apply_status("boss", "stun", maxf(1.0, seconds * 60.0), data, MEGA_STUN_SOURCE)


func _pick_repeat_delay() -> float:
	var roll := _deterministic_unit(
		_repeat_anchor_pos + Vector2(float(_combo_index) * 19.0, 43.0),
		_target,
		3.0 + float(_combo_index)
	)
	return lerpf(REPEAT_DELAY_MIN_SECONDS, REPEAT_DELAY_MAX_SECONDS, roll)


func _get_boss_moving_speed(owner: Object, boss_pos: Vector2) -> float:
	var owner_speed := absf(float(_get_owner_value(owner, "boss_vel", 0.0)))
	var sampled_speed := 0.0
	if _has_last_boss_pos:
		sampled_speed = absf(boss_pos.x - _last_boss_pos.x)
	return maxf(owner_speed, sampled_speed)


func _circle_hits_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	var closest := Vector2(
		clampf(center.x, rect.position.x, rect.end.x),
		clampf(center.y, rect.position.y, rect.end.y)
	)
	return center.distance_squared_to(closest) <= radius * radius


func _get_boss_rect(owner: Object) -> Rect2:
	var boss_pos: Vector2 = _get_owner_vector2(owner, "boss_pos", Vector2(FIELD_WIDTH * 0.5 - 50.0, 25.0))
	var boss_w: float = maxf(1.0, float(_get_owner_value(owner, "boss_paddle_width", 100.0)))
	var boss_h: float = maxf(1.0, float(_get_owner_value(owner, "boss_hitbox_height", 40.0)))
	return Rect2(boss_pos, Vector2(boss_w, boss_h))


func _remember_boss_pos(boss_pos: Vector2) -> void:
	_last_boss_pos = boss_pos
	_has_last_boss_pos = true


func _is_companion_onscreen(companion_pos: Vector2) -> bool:
	return (
		companion_pos.x >= 0.0
		and companion_pos.x <= FIELD_WIDTH
		and companion_pos.y >= 0.0
		and companion_pos.y <= FIELD_HEIGHT
	)


func _apply_ai_knockback(registry: Object, knockback_velocity: float) -> bool:
	var ai_state := _get_registry_instance(registry, "boss_ai_state")
	if ai_state != null and ai_state.has_method("start_paddle_hit_knockback"):
		ai_state.start_paddle_hit_knockback(knockback_velocity, KNOCKBACK_FRAMES, KNOCKBACK_DECAY, true)
		return true
	return false


func _deterministic_unit(origin: Vector2, boss_pos: Vector2, moving_speed: float) -> float:
	var hash_seed := origin.x * 12.9898 + origin.y * 4.1414 + boss_pos.x * 78.233 + moving_speed * 37.719 + float(_hit_count + _miss_count) * 11.13
	var value := sin(hash_seed) * 43758.5453
	return value - floor(value)


func _draw_dash(canvas: CanvasItem, shake_offset: Vector2) -> void:
	for i in range(_trail.size()):
		var ratio := float(i + 1) / float(maxi(1, _trail.size()))
		var trail_pos := _trail[i] + shake_offset
		var alpha := 0.08 + 0.30 * ratio
		canvas.draw_circle(trail_pos, lerpf(3.0, 10.0, ratio), Color(0.84, 0.34, 1.0, alpha))
		if i > 0:
			var prev_pos := _trail[i - 1] + shake_offset
			canvas.draw_line(prev_pos, trail_pos, Color(0.55, 0.95, 1.0, 0.26 * ratio), maxf(1.0, 4.0 * ratio), true)
	var pos := _pos + shake_offset
	canvas.draw_circle(pos, DASH_RADIUS + 9.0, Color(0.72, 0.25, 1.0, 0.12))
	canvas.draw_arc(pos, DASH_RADIUS + 5.0, 0.0, TAU, 30, Color(0.92, 0.62, 1.0, 0.42), 1.8, true)


func _draw_impact(canvas: CanvasItem, pos: Vector2, ratio: float, hit: bool) -> void:
	var clamped := clampf(ratio, 0.0, 1.0)
	var expansion := 1.0 - clamped
	var color := Color(0.58, 0.95, 1.0, 1.0) if hit else Color(0.75, 0.68, 0.90, 1.0)
	var radius := lerpf(18.0, 58.0, expansion)
	canvas.draw_circle(pos, radius, Color(color.r, color.g, color.b, 0.18 * clamped))
	canvas.draw_arc(pos, radius * 0.82, 0.0, TAU, 32, Color(color.r, color.g, color.b, 0.62 * clamped), 2.4)
	for i in range(8):
		var angle := TAU * float(i) / 8.0 + expansion * 0.55
		var start := pos + Vector2(cos(angle), sin(angle)) * radius * 0.26
		var end := pos + Vector2(cos(angle), sin(angle)) * radius
		canvas.draw_line(start, end, Color(1.0, 1.0, 1.0, 0.42 * clamped), 1.5, true)


func _draw_miss_text(canvas: CanvasItem, shake_offset: Vector2) -> void:
	if _miss_text_timer <= 0.0:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var progress := 1.0 - clampf(_miss_text_timer / MISS_TEXT_SECONDS, 0.0, 1.0)
	var alpha := maxf(0.0, 1.0 - progress)
	var draw_pos := _miss_text_pos + shake_offset + Vector2(0.0, -progress * MISS_TEXT_FLOAT_Y)
	draw_pos.x = clampf(draw_pos.x, 60.0, FIELD_WIDTH - 60.0)
	draw_pos.y = clampf(draw_pos.y, 60.0, FIELD_HEIGHT - 48.0)
	var font_size := int(round(24.0 + sin(progress * PI) * 3.0))
	canvas.draw_string(font, draw_pos + Vector2(-44.0, 2.0), MISS_TEXT, HORIZONTAL_ALIGNMENT_CENTER, 88.0, font_size, Color(0.04, 0.02, 0.08, 0.78 * alpha))
	canvas.draw_string(font, draw_pos + Vector2(-46.0, 0.0), MISS_TEXT, HORIZONTAL_ALIGNMENT_CENTER, 88.0, font_size, Color(0.86, 0.36, 1.0, 0.95 * alpha))


func _play_boomerang_hit(registry: Object) -> void:
	var audio := _get_registry_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_boomerang_hit"):
		audio.play_boomerang_hit()
	elif audio.has_method("play_paddle_hit"):
		audio.play_paddle_hit()


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner != null and owner.get(key) != null:
		return owner.get(key)
	return fallback


func _get_owner_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = _get_owner_value(owner, key, fallback)
	return value if value is Vector2 else fallback


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback


func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry == null:
		return null
	if registry.has_method("get_cached_instance"):
		var cached: Variant = registry.get_cached_instance(key)
		if typeof(cached) == TYPE_OBJECT and is_instance_valid(cached):
			return cached as Object
	if registry.has_method("get_instance"):
		var value: Variant = registry.get_instance(key)
		if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
			return value as Object
	return null

func _draw_mega_charge(canvas: CanvasItem, center: Vector2) -> void:
	var ratio := clampf(1.0 - _mega_charge_timer / maxf(0.001, MEGA_CHARGE_SECONDS), 0.0, 1.0)
	var swell := lerpf(26.0, 46.0, ratio)
	canvas.draw_circle(center, swell, Color(0.62, 0.30, 1.0, 0.10 + 0.16 * ratio))
	canvas.draw_arc(center, swell, 0.0, TAU, 36, Color(0.92, 0.66, 1.0, 0.34 + 0.40 * ratio), 2.0 + 1.5 * ratio, true)
	for i in range(8):
		var angle := TAU * float(i) / 8.0 + ratio * 4.0
		var conv := lerpf(64.0, 10.0, ratio)
		var spark := center + Vector2(cos(angle), sin(angle)) * conv
		canvas.draw_circle(spark, lerpf(2.0, 5.5, ratio), Color(1.0, 0.92, 0.55, 0.45 + 0.45 * ratio))
		canvas.draw_line(spark, center, Color(0.84, 0.55, 1.0, 0.18 + 0.30 * ratio), 1.4, true)
	var core := lerpf(4.0, 12.0, ratio)
	canvas.draw_circle(center, core, Color(1.0, 0.98, 0.86, 0.60 + 0.35 * ratio))


func _draw_mega_impact(canvas: CanvasItem, pos: Vector2, ratio: float) -> void:
	var clamped := clampf(ratio, 0.0, 1.0)
	var expansion := 1.0 - clamped
	var radius := lerpf(30.0, 104.0, expansion)
	canvas.draw_circle(pos, radius, Color(1.0, 0.52, 0.16, 0.22 * clamped))
	canvas.draw_circle(pos, radius * 0.6, Color(1.0, 0.86, 0.42, 0.30 * clamped))
	canvas.draw_arc(pos, radius * 0.9, 0.0, TAU, 40, Color(1.0, 0.78, 0.36, 0.72 * clamped), 3.4, true)
	for i in range(14):
		var angle := TAU * float(i) / 14.0 + expansion * 0.7
		var start := pos + Vector2(cos(angle), sin(angle)) * radius * 0.22
		var end := pos + Vector2(cos(angle), sin(angle)) * radius * (1.0 + 0.18 * sin(float(i) * 1.7))
		canvas.draw_line(start, end, Color(1.0, 0.95, 0.7, 0.5 * clamped), 2.2, true)
