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
const HIT_STUN_SOURCE := "lingpet_headbutt_hit"
const REPEAT_DELAY_MIN_SECONDS := 1.0
const REPEAT_DELAY_MAX_SECONDS := 2.0
const REPEAT_RECOIL_DISTANCE_Y := 92.0
const REPEAT_RECOIL_DURATION_RATIO := 0.42
const REPEAT_RECOIL_MIN_SECONDS := 0.30
const REPEAT_RECOIL_MAX_SECONDS := 0.58
const REPEAT_LOITER_RADIUS_X := 34.0
const REPEAT_LOITER_RADIUS_Y := 14.0
const REPEAT_LOITER_ANGULAR_SPEED := 8.2
# Onimaru ground-slam port (arena HornCharge parity): heavy earthquake screen shake on
# impact, then an eased recoil back to the launch origin (PHASE_RETURNING, 0.5s) before
# the self-stun, so the pet slams the boss then staggers home dazed instead of freezing
# at the contact point. Gated behind the `ground_slam` launch flag -> off for Lunabi.
const RETURN_SECONDS := 0.5
const GROUND_SLAM_DASH_SECONDS := 0.43
# Ground-slam earthquake feel. The old 0.40 / 8.0 (≈3.2px peak displacement, ~0.2s)
# read as "no shake at all" next to the explosion VFX -- roughly 7x weaker than the
# dynamite reference (0.67 / 35.0). Bumped to a heavy, readable quake that lands just
# under dynamite: 0.60 * 24.0 ≈ 14.4px peak, decaying over ~0.30s.
const GROUND_SLAM_SHAKE_AMOUNT := 0.60
const GROUND_SLAM_SHAKE_INTENSITY := 24.0
const GROUND_SLAM_MAX_RADIUS := 120.0
const GROUND_SLAM_DEBRIS_COUNT := 25
const GROUND_SLAM_CRACK_COUNT := 6
const GROUND_SLAM_SPARK_COUNT := 20
const GROUND_SLAM_FLAME_TONGUES := 12
# Flame aura is sized off the companion DRAW size (~82px WALK_DRAW_SIZE, half-extent ≈ 38),
# NOT _dash_radius (the 31px collision radius), so the fire wraps the VISIBLE body instead
# of hugging a small circle in Onimaru's middle. Mirrors the companion VFX sizing rule.
const GROUND_SLAM_FLAME_BODY_RADIUS := 38.0

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
# Onimaru 뿔박치기 leveling (all default to the Lunabi-compatible "off" values so the
# shared runtime is unchanged for every other pet). dash_radius widens the reach/hit
# zone with level. disable_moving_miss only removes the Lunabi-style random moving miss;
# ground_slam still commits to the cast-time boss spot, so a boss that leaves that spot
# is allowed to dodge into an empty-wall slam. Every real hit applies _hit_stun_seconds
# of boss stun (riding the stun-owned knockback like a mega), and the caster pays a
# self-stun that SHRINKS with level (Lv.1 long -> Lv.5 short).
var _dash_radius := DASH_RADIUS
# Ground-slam blast radius: drives BOTH the visible shockwave size AND the stun catch
# area (a boss within _slam_radius of the locked spot is stunned). Scales with level via
# slam_radius_by_level so higher level = bigger explosion AND a wider real stun reach.
var _slam_radius := GROUND_SLAM_MAX_RADIUS
var _disable_moving_miss := false
var _hit_stun_seconds := 0.0
var _self_stun_seconds := 0.0
var _self_stun_timer := 0.0
var _self_stun_pos := Vector2.ZERO
var _ground_slam := false
var _launch_origin := Vector2.ZERO
# Committed-slam target: for ground_slam the dash locks onto the boss center AT CAST TIME
# (the "wall" where the boss is right now) and does NOT re-track. If the boss leaves that
# spot during the dash it dodges and we slam empty wall (shake + VFX, no boss hit).
var _fixed_target := Vector2.ZERO
var _dash_origin := Vector2.ZERO
var _dash_elapsed := 0.0
var _dash_duration := 0.0
var _return_timer := 0.0
var _return_duration := 0.0
var _return_from_pos := Vector2.ZERO
var _ground_slam_sound_played := false


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
	_dash_radius = DASH_RADIUS
	_slam_radius = GROUND_SLAM_MAX_RADIUS
	_disable_moving_miss = false
	_hit_stun_seconds = 0.0
	_self_stun_seconds = 0.0
	_self_stun_timer = 0.0
	_self_stun_pos = Vector2.ZERO
	_ground_slam = false
	_launch_origin = Vector2.ZERO
	_fixed_target = Vector2.ZERO
	_dash_origin = Vector2.ZERO
	_dash_elapsed = 0.0
	_dash_duration = 0.0
	_return_timer = 0.0
	_return_duration = 0.0
	_return_from_pos = Vector2.ZERO
	_ground_slam_sound_played = false


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
	_dash_radius = _resolve_dash_radius(launch_context)
	_slam_radius = _resolve_slam_radius(launch_context)
	_disable_moving_miss = float(launch_context.get("disable_moving_miss", 0.0)) > 0.5
	_hit_stun_seconds = _resolve_optional_seconds(launch_context, "hit_stun_seconds")
	_self_stun_seconds = _resolve_optional_seconds(launch_context, "self_stun_seconds")
	_ground_slam = float(launch_context.get("ground_slam", 0.0)) > 0.5
	_launch_origin = origin
	_dash_origin = origin
	_dash_elapsed = 0.0
	_dash_duration = 0.0
	_ground_slam_sound_played = false
	if _ground_slam:
		_ground_slam_sound_played = _play_horn_charge_sound(_get_launch_registry(launch_context))
	_self_stun_timer = 0.0
	_return_timer = 0.0
	_return_duration = 0.0
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
	_dash_origin = origin
	_dash_elapsed = 0.0
	_dash_duration = GROUND_SLAM_DASH_SECONDS if _ground_slam else 0.0
	_trail.clear()
	_trail.append(_pos)
	if _ground_slam:
		# Committed slam: lock the slam point to where the boss is RIGHT NOW and never
		# re-track. The boss can dodge by leaving this spot during the 0.43s dash.
		_fixed_target = boss_rect.get_center()
		_target = _fixed_target
		_planned_miss = false
		_last_miss_reason = ""
	else:
		_target = _get_homing_target(owner, boss_rect)
		var moving_speed: float = _get_boss_moving_speed(owner, boss_rect.position)
		_planned_miss = false if _disable_moving_miss else _should_miss_moving_target(origin, boss_rect.position, moving_speed)
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
	elif _return_timer > 0.0:
		_return_timer = maxf(0.0, _return_timer - safe_delta)
		var progress := clampf(1.0 - _return_timer / maxf(0.001, _return_duration), 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - progress, 2.0)
		_pos = _return_from_pos.lerp(_launch_origin, eased)
		if _return_timer <= 0.0:
			_pos = _launch_origin
			_self_stun_timer = _self_stun_seconds
		_remember_boss_pos(_get_boss_rect(owner).position)
	elif _self_stun_timer > 0.0:
		_self_stun_timer = maxf(0.0, _self_stun_timer - safe_delta)
		_pos = _self_stun_pos
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
		if _ground_slam:
			# Cracks first so the dust rings + debris kick up OVER the split floor.
			_draw_ground_cracks(canvas, _impact_pos + shake_offset, _impact_timer / IMPACT_SECONDS)
			_draw_ground_slam(canvas, _impact_pos + shake_offset, _impact_timer / IMPACT_SECONDS)
		_draw_impact(canvas, _impact_pos + shake_offset, _impact_timer / IMPACT_SECONDS, true)
		if _mega_impact:
			_draw_mega_impact(canvas, _impact_pos + shake_offset, _impact_timer / IMPACT_SECONDS)
		if _ground_slam:
			# Hot sparks truly LAST -- above the cyan hit flash + mega burst so the embers pop
			# instead of being washed out by the generic impact overlay.
			_draw_ground_slam_sparks(canvas, _impact_pos + shake_offset, _impact_timer / IMPACT_SECONDS)
	if _miss_timer > 0.0:
		_draw_impact(canvas, _impact_pos + shake_offset, _miss_timer / MISS_FLASH_SECONDS, false)
	if _miss_text_timer > 0.0:
		_draw_miss_text(canvas, shake_offset)
	if _self_stun_timer > 0.0:
		_draw_self_stun(canvas, _self_stun_pos + shake_offset)


func has_visible_effects() -> bool:
	return _active or _impact_timer > 0.0 or _miss_timer > 0.0 or _miss_text_timer > 0.0 or _repeat_wait_timer > 0.0 or _mega_charge_timer > 0.0 or _self_stun_timer > 0.0 or _return_timer > 0.0


func is_active() -> bool:
	return _active or _repeat_wait_timer > 0.0 or _mega_charge_timer > 0.0 or _self_stun_timer > 0.0 or _return_timer > 0.0


func has_companion_position_override() -> bool:
	return _active or _impact_timer > 0.0 or _miss_timer > 0.0 or _repeat_wait_timer > 0.0 or _mega_charge_timer > 0.0 or _self_stun_timer > 0.0 or _return_timer > 0.0


func get_companion_position_override(fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if _mega_charge_timer > 0.0:
		return _mega_charge_origin
	if _active:
		return _pos
	if _repeat_wait_timer > 0.0:
		return _get_repeat_wait_position()
	if _return_timer > 0.0:
		return _pos
	if _self_stun_timer > 0.0:
		return _self_stun_pos
	if _impact_timer > 0.0 or _miss_timer > 0.0:
		return _impact_pos
	return fallback


func consume_companion_strike_request() -> bool:
	if _strike_request_count <= 0:
		return false
	_strike_request_count -= 1
	return true


func suppresses_companion_body_hit() -> bool:
	# While Onimaru is paying its post-headbutt self-stun it is incapacitated, so the
	# companion body must NOT bounce the ball or fire an anticipatory strike (both the
	# body-hit path and the strike anticipator gate on this). Mirrors the arena HornCharge
	# stunning the caster (downtown/hero_skills.py PHASE_STUN). Pets without a self-stun
	# (Lunabi etc.) keep _self_stun_timer at 0 here, so their hit behavior is unchanged.
	# The recoil RETURN window counts too: the dazed pet staggering home is still
	# incapacitated (the arena HornCharge locks control through PHASE_RETURNING).
	return _self_stun_timer > 0.0 or _return_timer > 0.0


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
		"headbutt_dash_radius": _dash_radius,
		"headbutt_disable_moving_miss": _disable_moving_miss,
		"headbutt_hit_stun_seconds": _hit_stun_seconds,
		"headbutt_self_stun_seconds": _self_stun_seconds,
		"headbutt_self_stun_active": _self_stun_timer > 0.0,
		"headbutt_self_stun_timer": _self_stun_timer,
		"headbutt_ground_slam": _ground_slam,
		"headbutt_slam_radius": _slam_radius,
		"headbutt_fixed_target": _fixed_target,
		"headbutt_wall_slam": _last_result == "wall_slam",
		"headbutt_dash_progress": clampf(_dash_elapsed / maxf(0.001, _dash_duration), 0.0, 1.0) if _dash_duration > 0.0 else 0.0,
		"headbutt_dash_duration": _dash_duration,
		"headbutt_returning": _return_timer > 0.0,
		"headbutt_return_timer": _return_timer,
	}


func _step_ground_slam_dash(delta: float, owner: Object, registry: Object) -> void:
	# Drive toward the FIXED cast-time slam point with the 0.43s progress^2 accel curve.
	# No live re-tracking: the boss can dodge by leaving _fixed_target during the dash.
	_dash_elapsed = minf(_dash_duration, _dash_elapsed + delta)
	var progress := clampf(_dash_elapsed / maxf(0.001, _dash_duration), 0.0, 1.0)
	var eased_progress := progress * progress
	_pos = _dash_origin.lerp(_fixed_target, eased_progress)
	var target_offset := _fixed_target - _dash_origin
	if target_offset.length_squared() > 1.0:
		_dash_dir = target_offset.normalized()
	if progress >= 1.0:
		_pos = _fixed_target
		var live_boss: Rect2 = _get_boss_rect(owner)
		if _circle_hits_rect(_fixed_target, _slam_radius, live_boss):
			# Boss is still inside the (level-scaled) slam blast radius -> real headbutt
			# (stun + knockback). The bigger the level, the wider this catch zone.
			_resolve_hit(owner, registry, live_boss)
		else:
			# Boss escaped the blast radius -> slam the empty wall: shake + shockwave, no
			# boss effect. Dodging needs more movement at higher level (radius grows).
			_resolve_wall_slam(owner, registry)
		return
	_remember_boss_pos(_get_boss_rect(owner).position)


func _step_dash(delta: float, owner: Object, registry: Object) -> void:
	if delta <= 0.0:
		return
	_trail.append(_pos)
	while _trail.size() > TRAIL_MAX_POINTS:
		_trail.remove_at(0)
	if _ground_slam:
		_step_ground_slam_dash(delta, owner, registry)
		return
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
	if not _planned_miss and _circle_hits_rect(_pos, _dash_radius, boss_rect):
		_resolve_hit(owner, registry, boss_rect)
		return
	if step_distance >= remaining:
		if _disable_moving_miss and not _planned_miss:
			# Non-committed variants may opt out of the random moving-target miss roll and
			# snap to the live boss on arrival. Onimaru's ground_slam returns earlier through
			# _step_ground_slam_dash, where it is dodgeable by leaving the fixed slam spot.
			_pos = boss_rect.get_center()
			_resolve_hit(owner, registry, boss_rect)
		else:
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
	# A boss stun (mega's random stun OR Onimaru's per-hit hit_stun) OWNS boss movement:
	# boss_ai's stun branch returns BEFORE the paddle-hit knockback channel, so the
	# knockback MUST ride the stun status (knockback_vel/frames/decay) like milk_shot /
	# gatling -- the separate paddle-hit channel would be silently bypassed here.
	var mega_stun := _mega_stun_seconds if _is_mega else 0.0
	var stun_seconds := maxf(mega_stun, _hit_stun_seconds)
	if stun_seconds > 0.0:
		_apply_boss_stun(registry, stun_seconds, _last_knockback_velocity)
		impact_nudge = direction * IMPACT_NUDGE_DISTANCE
	else:
		var ai_knockback_applied := _apply_ai_knockback(registry, _last_knockback_velocity)
		impact_nudge = direction * (IMPACT_NUDGE_DISTANCE if ai_knockback_applied else KNOCKBACK_DISTANCE * effective_scale)
	next_pos.x = clampf(boss_pos.x + impact_nudge, 0.0, maxf(0.0, FIELD_WIDTH - boss_w))
	if owner != null:
		owner.set("boss_pos", next_pos)
		if owner.get("boss_vel") != null:
			owner.set("boss_vel", _last_knockback_velocity)
	if _ground_slam:
		_apply_ground_slam_shake(registry)
	_play_impact_sound(registry)
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


func _resolve_wall_slam(owner: Object, registry: Object) -> void:
	# Committed slam landed on the empty wall (boss dodged): the impact still happens at the
	# locked spot -- earthquake shake + shockwave VFX (+ the launch slam sound) -- but the
	# boss takes NO stun and NO knockback. The pet still recoils home and self-stuns.
	_active = false
	_planned_miss = false
	_impact_pos = _fixed_target
	_impact_timer = IMPACT_SECONDS
	_miss_timer = 0.0
	_mega_impact = false
	_last_result = "wall_slam"
	_last_miss_reason = "boss_dodged"
	_miss_count += 1
	_last_knockback_velocity = 0.0
	_apply_ground_slam_shake(registry)
	_play_impact_sound(registry)
	_trail.clear()
	_remember_boss_pos(_get_boss_rect(owner).position)
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
		# Onimaru-style recoil self-stun: after the final headbutt the caster is briefly
		# incapacitated. is_active()/the position override keep the host from patrolling,
		# defending, or striking until the self-stun clears.
		if _self_stun_seconds > 0.0:
			if _ground_slam:
				# Arena HornCharge parity: ease back to the launch origin (PHASE_RETURNING)
				# THEN stagger-stun at the home lane, instead of freezing at the boss.
				_return_from_pos = _impact_pos
				_return_duration = RETURN_SECONDS
				_return_timer = RETURN_SECONDS
				_self_stun_pos = _launch_origin
			else:
				_self_stun_timer = _self_stun_seconds
				_self_stun_pos = _get_repeat_recoil_anchor_pos(_impact_pos)


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
	# A no-random-moving-miss headbutt aims at the live boss center with NO velocity
	# lead, so the predictive overshoot cannot carry the dash off a fast-moving boss.
	if not _disable_moving_miss:
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


func _resolve_dash_radius(launch_context: Dictionary) -> float:
	var provided := float(launch_context.get("dash_radius", -1.0))
	return provided if provided > 0.0 else DASH_RADIUS


func _resolve_slam_radius(launch_context: Dictionary) -> float:
	var provided := float(launch_context.get("slam_radius", -1.0))
	return provided if provided > 0.0 else GROUND_SLAM_MAX_RADIUS


func _resolve_optional_seconds(launch_context: Dictionary, key: String) -> float:
	var provided := float(launch_context.get(key, -1.0))
	return maxf(0.0, provided) if provided >= 0.0 else 0.0


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
	var source := MEGA_STUN_SOURCE if (_is_mega and _mega_stun_seconds > 0.0) else HIT_STUN_SOURCE
	var data := {"source": source}
	if absf(knockback_velocity) > 0.001:
		data["knockback_vel"] = knockback_velocity
		data["knockback_active"] = true
		data["knockback_frames"] = KNOCKBACK_FRAMES
		data["knockback_decay_per_frame"] = KNOCKBACK_DECAY
	status_state.apply_status("boss", "stun", maxf(1.0, seconds * 60.0), data, source)


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
	if _ground_slam:
		# Onimaru charges the boss wrapped in fire. Lunabi keeps its violet magic dash below.
		_draw_dash_flames(canvas, shake_offset)
		return
	for i in range(_trail.size()):
		var ratio := float(i + 1) / float(maxi(1, _trail.size()))
		var trail_pos := _trail[i] + shake_offset
		var alpha := 0.08 + 0.30 * ratio
		canvas.draw_circle(trail_pos, lerpf(3.0, 10.0, ratio), Color(0.84, 0.34, 1.0, alpha))
		if i > 0:
			var prev_pos := _trail[i - 1] + shake_offset
			canvas.draw_line(prev_pos, trail_pos, Color(0.55, 0.95, 1.0, 0.26 * ratio), maxf(1.0, 4.0 * ratio), true)
	var pos := _pos + shake_offset
	canvas.draw_circle(pos, _dash_radius + 9.0, Color(0.72, 0.25, 1.0, 0.12))
	canvas.draw_arc(pos, _dash_radius + 5.0, 0.0, TAU, 30, Color(0.92, 0.62, 1.0, 0.42), 1.8, true)


func _draw_dash_flames(canvas: CanvasItem, shake_offset: Vector2) -> void:
	# Fire wrapping Onimaru during the ground-slam charge: an ember trail streaming back
	# along the flight path, a translucent heat aura, and flame tongues licking around the
	# VISIBLE body perimeter (biased to the trailing side so the fire streams behind the
	# flight). Animated from _dash_elapsed -- the dash clock that advances on the update
	# tick and freezes if the tick is skipped (never wall-clock, per the walk-anim trap) --
	# so the flames flicker while flying but do not march in place if a pause branch skips
	# the update. draw_circle only, so it is immune to the animated-polygon triangulation
	# trap, and every tongue stays translucent so Onimaru reads through the fire.
	var clock := _dash_elapsed
	# Fiery ember trail streaming back along the flight path.
	for i in range(_trail.size()):
		var ratio := float(i + 1) / float(maxi(1, _trail.size()))
		var trail_pos := _trail[i] + shake_offset
		var puff := lerpf(2.0, 9.0, ratio)
		canvas.draw_circle(trail_pos, puff, Color(1.0, 0.40, 0.10, 0.05 + 0.20 * ratio))
		canvas.draw_circle(trail_pos, puff * 0.5, Color(1.0, 0.80, 0.34, 0.08 + 0.26 * ratio))
	var center := _pos + shake_offset
	# Translucent heat aura wrapping the body (rings, not fills -> the sprite reads through).
	canvas.draw_circle(center, GROUND_SLAM_FLAME_BODY_RADIUS + 15.0, Color(1.0, 0.34, 0.08, 0.10))
	canvas.draw_circle(center, GROUND_SLAM_FLAME_BODY_RADIUS + 7.0, Color(1.0, 0.50, 0.16, 0.15))
	# Flame tongues licking around the perimeter, pushed toward the trailing side.
	var back := -_dash_dir
	if back.length_squared() < 0.01:
		back = Vector2(0.0, 1.0)
	for i in range(GROUND_SLAM_FLAME_TONGUES):
		var base_angle := TAU * float(i) / float(GROUND_SLAM_FLAME_TONGUES)
		var out := Vector2(cos(base_angle), sin(base_angle))
		var dir := (out + back * 0.55).normalized()
		var flick := 0.55 + 0.45 * sin(clock * 45.0 + float(i) * 1.7)
		var inner := GROUND_SLAM_FLAME_BODY_RADIUS * 0.55
		var reach := GROUND_SLAM_FLAME_BODY_RADIUS + 4.0 + flick * 16.0
		_draw_flame_tongue(canvas, center, dir, inner, reach, i, clock)


func _draw_flame_tongue(canvas: CanvasItem, center: Vector2, dir: Vector2, inner: float, reach: float, seed_index: int, clock: float) -> void:
	# Soft flame tongue: deep-orange wide base near the body -> wispy yellow-white tip.
	# A few overlapping translucent circles along `dir`; alpha fades toward the tip so the
	# flame dissipates instead of ending in a hard dot.
	var perp := Vector2(-dir.y, dir.x)
	var steps := 3
	for s in range(steps + 1):
		var frac := float(s) / float(steps)
		var dist := lerpf(inner, reach, frac)
		var wobble := sin(clock * 30.0 + float(seed_index) * 2.1 + frac * 3.4) * 2.4 * frac
		var p := center + dir * dist + perp * wobble
		var size := lerpf(4.8, 1.0, frac)
		var col := Color(1.0, lerpf(0.34, 0.95, frac), lerpf(0.06, 0.55, frac), lerpf(0.72, 0.18, frac))
		canvas.draw_circle(p, maxf(0.6, size), col)


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


func _play_impact_sound(registry: Object) -> void:
	if not _ground_slam:
		_play_boomerang_hit(registry)
		return
	if _ground_slam_sound_played:
		return
	_ground_slam_sound_played = _play_horn_charge_sound(registry)
	if _ground_slam_sound_played:
		return
	var audio := _get_registry_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_dynamite_explosion"):
		audio.play_dynamite_explosion()
	elif audio.has_method("play_stage4_temple_hit"):
		audio.play_stage4_temple_hit()
	elif audio.has_method("play_grenade_explosion"):
		audio.play_grenade_explosion()
	elif audio.has_method("play_boomerang_hit"):
		audio.play_boomerang_hit()
	elif audio.has_method("play_paddle_hit"):
		audio.play_paddle_hit()


func _play_boomerang_hit(registry: Object) -> void:
	var audio := _get_registry_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_boomerang_hit"):
		audio.play_boomerang_hit()
	elif audio.has_method("play_paddle_hit"):
		audio.play_paddle_hit()


func _play_horn_charge_sound(registry: Object) -> bool:
	var audio := _get_registry_instance(registry, "game_audio")
	if audio == null:
		return false
	if audio.has_method("play_horn_charge"):
		audio.play_horn_charge()
		return true
	if audio.has_method("play_horn_strawberry_horn_charge"):
		audio.play_horn_strawberry_horn_charge()
		return true
	return false


func _apply_ground_slam_shake(registry: Object) -> void:
	var feedback := _get_registry_instance(registry, "battle_feedback_state")
	if feedback == null or not feedback.has_method("max_screen_shake"):
		return
	feedback.max_screen_shake(GROUND_SLAM_SHAKE_AMOUNT, GROUND_SLAM_SHAKE_INTENSITY)


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


func _get_launch_registry(launch_context: Dictionary) -> Object:
	var value: Variant = launch_context.get("registry", null)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null

func _draw_mega_charge(canvas: CanvasItem, center: Vector2) -> void:
	var ratio := clampf(1.0 - _mega_charge_timer / maxf(0.001, MEGA_CHARGE_SECONDS), 0.0, 1.0)
	var elapsed := ratio * MEGA_CHARGE_SECONDS
	var intensity := ratio * ratio
	var pulse := 0.5 + 0.5 * sin(elapsed * 26.0)
	var swell := lerpf(60.0, 30.0, ratio)
	# Gathering field: a soft violet aura that contracts and brightens as it charges.
	canvas.draw_circle(center, swell + 12.0, Color(0.42, 0.16, 0.95, 0.05 + 0.12 * intensity))
	canvas.draw_circle(center, swell, Color(0.60, 0.28, 1.0, 0.08 + 0.18 * intensity))
	# Converging energy streams pulled inward from the gathering field.
	for i in range(18):
		var a := TAU * float(i) / 18.0 + ratio * 1.8
		var dir := Vector2(cos(a), sin(a))
		var far := lerpf(98.0, 30.0, ratio) + 7.0 * sin(elapsed * 9.0 + float(i))
		var near := lerpf(42.0, 12.0, ratio)
		var streak_alpha := (0.10 + 0.45 * intensity) * (0.6 + 0.4 * pulse)
		canvas.draw_line(center + dir * far, center + dir * near, Color(0.80, 0.46, 1.0, streak_alpha), 1.2 + 1.8 * intensity, true)
		canvas.draw_circle(center + dir * near, 1.4 + 2.6 * intensity, Color(1.0, 0.9, 0.72, 0.4 + 0.5 * intensity))
	# Counter-rotating dashed energy rings.
	_draw_charge_ring(canvas, center, lerpf(56.0, 26.0, ratio), ratio * 5.0, 10, Color(0.92, 0.62, 1.0, 0.28 + 0.45 * intensity), 2.0 + 1.6 * intensity)
	_draw_charge_ring(canvas, center, lerpf(42.0, 18.0, ratio), -ratio * 7.0, 8, Color(0.70, 0.40, 1.0, 0.24 + 0.42 * intensity), 1.6 + 1.4 * intensity)
	# Crackling electric bolts radiating from the core (more of them as it charges).
	var bolt_count := 3 + int(round(3.0 * intensity))
	for i in range(bolt_count):
		_draw_charge_bolt(canvas, center, i, ratio, elapsed, intensity, pulse)
	# Pulsing white-hot core.
	var core := lerpf(5.0, 15.0, ratio) * (0.85 + 0.22 * pulse)
	canvas.draw_circle(center, core + 7.0, Color(0.85, 0.55, 1.0, 0.18 + 0.34 * intensity))
	canvas.draw_circle(center, core, Color(1.0, 0.93, 0.78, 0.55 + 0.4 * intensity))
	canvas.draw_circle(center, core * 0.5, Color(1.0, 1.0, 0.96, 0.7 + 0.3 * pulse))
	# Final-quarter shock ring telegraphs the imminent release.
	if ratio > 0.75:
		var burst := (ratio - 0.75) / 0.25
		canvas.draw_arc(center, lerpf(14.0, 72.0, burst), 0.0, TAU, 40, Color(1.0, 0.95, 0.8, 0.7 * (1.0 - burst)), 3.0 * (1.0 - burst) + 1.0, true)
	# Rising embers around the gather.
	for i in range(6):
		var t := fmod(elapsed * 0.7 + float(i) * 0.37, 1.0)
		var ex := center.x + sin(float(i) * 2.1 + elapsed * 3.0) * lerpf(8.0, 22.0, t)
		var ey := center.y + 18.0 - t * 46.0
		canvas.draw_circle(Vector2(ex, ey), 1.4 + 2.0 * (1.0 - t), Color(0.95, 0.72, 1.0, (1.0 - t) * (0.3 + 0.4 * intensity)))


func _draw_charge_ring(canvas: CanvasItem, center: Vector2, radius: float, rotation_offset: float, segments: int, color: Color, width: float) -> void:
	var step := TAU / float(maxi(1, segments))
	for i in range(segments):
		var a0 := step * float(i) + rotation_offset
		canvas.draw_arc(center, radius, a0, a0 + step * 0.55, 6, color, width, true)


func _draw_charge_bolt(canvas: CanvasItem, center: Vector2, seed_index: int, ratio: float, elapsed: float, intensity: float, pulse: float) -> void:
	var base_angle := TAU * float(seed_index) / 6.0 + ratio * 3.3 + _bolt_hash(seed_index, elapsed) * 1.4
	var length := lerpf(22.0, 52.0, intensity)
	var forward := Vector2(cos(base_angle), sin(base_angle))
	var perp := Vector2(-forward.y, forward.x)
	var points := PackedVector2Array()
	points.append(center)
	for s in range(1, 6):
		var frac := float(s) / 5.0
		var jitter := (_bolt_hash(seed_index * 17 + s, elapsed + float(s) * 0.13) - 0.5) * 18.0 * (1.0 - frac * 0.4)
		points.append(center + forward * (length * frac) + perp * jitter)
	canvas.draw_polyline(points, Color(0.96, 0.82, 1.0, (0.22 + 0.5 * intensity) * (0.5 + 0.5 * pulse)), 1.6, true)


func _bolt_hash(index: int, time_seconds: float) -> float:
	var v := sin(float(index) * 12.9898 + floor(time_seconds * 38.0) * 78.233) * 43758.5453
	return v - floor(v)


func _draw_ground_cracks(canvas: CanvasItem, pos: Vector2, ratio: float) -> void:
	# The ground SPLITS on impact: jagged dark fissures snap outward from the slam point
	# with a hot molten glow inside, then fade as the dust settles. Seeded on the STABLE
	# _impact_pos / _target (never on the shaken `pos`) so the crack SHAPE does not
	# re-randomize every frame under screen shake -- only the whole group translates with
	# `pos`. Draws with draw_line / draw_circle only (no draw_colored_polygon), so it is
	# immune to the animated-polygon triangulation trap.
	var clamped := clampf(ratio, 0.0, 1.0)
	var expansion := 1.0 - clamped
	var grow := clampf(expansion / 0.28, 0.0, 1.0)
	var reach := _slam_radius * 1.15 * grow
	if reach <= 6.0:
		return
	var fade := clampf(clamped * 1.5, 0.0, 1.0)
	# Faint scorched scar under the fissures to seat the split in the floor.
	canvas.draw_circle(pos, reach * 0.42, Color(0.05, 0.02, 0.02, 0.16 * fade))
	for i in range(GROUND_SLAM_CRACK_COUNT):
		var angle_seed := _deterministic_unit(_impact_pos + Vector2(float(i) * 7.3, 5.0), _target, float(i + 3))
		var base_angle := TAU * float(i) / float(GROUND_SLAM_CRACK_COUNT) + (angle_seed - 0.5) * 0.7
		var len_seed := 0.68 + _deterministic_unit(_impact_pos + Vector2(2.0, float(i) * 9.1), _target, float(i + 11)) * 0.5
		_draw_single_crack(canvas, pos, base_angle, reach * len_seed, i, fade, 0)


func _draw_single_crack(canvas: CanvasItem, origin: Vector2, angle: float, length: float, seed_index: int, fade: float, depth: int) -> void:
	if length <= 4.0:
		return
	var forward := Vector2(cos(angle), sin(angle))
	var perp := Vector2(-forward.y, forward.x)
	var seg_count := 5
	var points := PackedVector2Array()
	points.append(origin)
	for s in range(1, seg_count + 1):
		var frac := float(s) / float(seg_count)
		var wander := _deterministic_unit(_impact_pos + Vector2(float(seed_index) * 5.0, float(s) * 12.0), _target, float(seed_index * 13 + s)) - 0.5
		var jitter := wander * length * 0.16 * (1.0 - frac * 0.35)
		points.append(origin + forward * (length * frac) + perp * jitter)
	# Dark fissure body, tapering wide -> thin from the impact outward.
	var body_base := 5.4 - float(depth) * 1.9
	for s in range(points.size() - 1):
		var frac := float(s) / float(points.size() - 1)
		var w := lerpf(maxf(1.2, body_base), 0.9, frac)
		canvas.draw_line(points[s], points[s + 1], Color(0.05, 0.02, 0.02, 0.9 * fade), w, true)
	# Inner molten glow, hottest near the core.
	var glow_base := 2.6 - float(depth) * 0.9
	for s in range(points.size() - 1):
		var frac := float(s) / float(points.size() - 1)
		var w := lerpf(maxf(0.6, glow_base), 0.5, frac)
		var g := 0.30 + 0.35 * (1.0 - frac)
		canvas.draw_line(points[s], points[s + 1], Color(1.0, g, 0.12, 0.65 * fade * (1.0 - frac * 0.5)), w, true)
	# A single branching fork off each main crack sells the "splitting" read.
	if depth == 0 and points.size() >= 4:
		var branch_seed := _deterministic_unit(_impact_pos + Vector2(float(seed_index) * 3.0, 21.0), _target, float(seed_index + 29))
		var branch_dir := 1.0 if branch_seed > 0.5 else -1.0
		var branch_angle := angle + branch_dir * lerpf(0.55, 1.0, branch_seed)
		_draw_single_crack(canvas, points[2], branch_angle, length * 0.44, seed_index * 7 + 5, fade * 0.8, 1)


func _draw_ground_slam(canvas: CanvasItem, pos: Vector2, ratio: float) -> void:
	# Heavy ground-slam shockwave: expanding dust rings + a bright impact core + radial
	# debris chunks that arc back down (gravity), echoing the arena HornCharge impact.
	var clamped := clampf(ratio, 0.0, 1.0)
	var expansion := 1.0 - clamped
	for i in range(3):
		var ring_delay := float(i) * 0.10
		var rp := clampf((expansion - ring_delay) / maxf(0.001, 1.0 - ring_delay), 0.0, 1.0)
		if rp <= 0.0:
			continue
		var radius := lerpf(10.0, _slam_radius, rp)
		var ring_alpha := (1.0 - rp) * (0.78 - float(i) * 0.12)
		var ring_width := 8.0
		if i == 1:
			ring_width = 5.0
		elif i == 2:
			ring_width = 3.0
		canvas.draw_arc(pos, radius, 0.0, TAU, 40, Color(1.0, 0.32 + rp * 0.22, 0.12, ring_alpha), ring_width, true)
	canvas.draw_circle(pos, lerpf(38.0, 10.0, expansion), Color(1.0, 0.55, 0.20, 0.55 * clamped))
	for i in range(GROUND_SLAM_DEBRIS_COUNT):
		# Seed from the STABLE _impact_pos, never the shaken `pos`: the hash re-rolls
		# completely on any sub-pixel seed change, so seeding from the per-frame shake
		# offset makes the debris boil/re-scatter instead of translating as one explosion.
		var jitter := _deterministic_unit(_impact_pos + Vector2(float(i) * 13.0, 0.0), _target, float(i + 1)) * 0.5
		var angle := TAU * float(i) / float(GROUND_SLAM_DEBRIS_COUNT) + jitter
		var dir := Vector2(cos(angle), sin(angle))
		var speed_seed := 0.65 + _deterministic_unit(_impact_pos, _target + Vector2(float(i), 17.0), float(i + 5)) * 0.55
		var dist := lerpf(8.0, (_slam_radius - 2.0) * speed_seed, expansion)
		var gravity := expansion * expansion * 48.0
		var debris_pos := pos + dir * dist + Vector2(0.0, gravity)
		var debris_size := lerpf(6.0, 1.2, expansion) * (0.7 + speed_seed * 0.45)
		canvas.draw_circle(debris_pos, maxf(0.7, debris_size), Color(1.0, 0.47, 0.20, (1.0 - expansion) * 0.9))


func _draw_ground_slam_sparks(canvas: CanvasItem, pos: Vector2, ratio: float) -> void:
	# Fire sparks SPLASHING off the impact: bright white-hot heads with a fading ember
	# trail, launched in an UPWARD-biased fan (they arc up out of the blast, unlike the
	# heavier debris chunks that fall back down) and flickering like real embers. Seeded
	# on the STABLE _impact_pos so the spread does not re-randomize per frame under screen
	# shake. draw_line / draw_circle only -- no draw_colored_polygon.
	var clamped := clampf(ratio, 0.0, 1.0)
	var expansion := 1.0 - clamped
	if expansion <= 0.0:
		return
	var life := clamped
	for i in range(GROUND_SLAM_SPARK_COUNT):
		var angle_seed := _deterministic_unit(_impact_pos + Vector2(float(i) * 4.7, 11.0), _target, float(i + 5))
		var speed_seed := _deterministic_unit(_impact_pos + Vector2(3.0, float(i) * 6.3), _target, float(i + 17))
		# Fan biased upward: spread ~260 degrees centered on straight up (-PI/2).
		var angle := -PI * 0.5 + (angle_seed - 0.5) * (TAU * 0.72)
		var dir := Vector2(cos(angle), sin(angle))
		var reach := lerpf(6.0, (_slam_radius + 40.0) * lerpf(0.55, 1.0, speed_seed), expansion)
		# Gravity bends each spark's arc back down as it flies out.
		var gravity := expansion * expansion * lerpf(26.0, 72.0, speed_seed)
		var head := pos + dir * reach + Vector2(0.0, gravity)
		var tail := pos + dir * (reach * 0.72) + Vector2(0.0, gravity * 0.58)
		var flick := 0.58 + 0.42 * sin(expansion * 40.0 + float(i) * 2.3)
		var alpha := life * flick
		# Ember trail streak.
		canvas.draw_line(tail, head, Color(1.0, 0.60, 0.20, 0.55 * alpha), lerpf(2.4, 0.8, expansion), true)
		# White-hot head with a hotter inner core.
		var head_size := lerpf(2.9, 0.7, expansion) * (0.7 + speed_seed * 0.6)
		canvas.draw_circle(head, maxf(0.6, head_size), Color(1.0, 0.90, 0.55, 0.9 * alpha))
		canvas.draw_circle(head, maxf(0.3, head_size * 0.5), Color(1.0, 1.0, 0.92, alpha))


func _draw_self_stun(canvas: CanvasItem, center: Vector2) -> void:
	# Stun stars orbiting above the recoiling companion's head while it is incapacitated.
	var spin := (_self_stun_seconds - _self_stun_timer) * 6.0
	var head := center + Vector2(0.0, -34.0)
	var star_count := 3
	for i in range(star_count):
		var angle := spin + TAU * float(i) / float(star_count)
		var star_pos := head + Vector2(cos(angle) * 18.0, sin(angle) * 6.0)
		_draw_stun_star(canvas, star_pos, 5.0 + 1.4 * sin(spin * 2.0 + float(i)))


func _draw_stun_star(canvas: CanvasItem, center: Vector2, radius: float) -> void:
	var points := PackedVector2Array()
	for i in range(5):
		var outer := center + Vector2(cos(TAU * float(i) / 5.0 - PI * 0.5), sin(TAU * float(i) / 5.0 - PI * 0.5)) * radius
		var inner_angle := TAU * (float(i) + 0.5) / 5.0 - PI * 0.5
		var inner := center + Vector2(cos(inner_angle), sin(inner_angle)) * (radius * 0.45)
		points.append(outer)
		points.append(inner)
	canvas.draw_colored_polygon(points, Color(1.0, 0.92, 0.4, 0.92))


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
