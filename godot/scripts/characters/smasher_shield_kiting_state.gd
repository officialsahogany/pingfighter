extends RefCounted

const SmasherShieldKitingRenderer := preload("res://scripts/characters/smasher_shield_kiting_renderer.gd")
const SmasherSkillPartialCutinState := preload("res://scripts/characters/smasher_skill_partial_cutin_state.gd")

const SKILL_NAME := "shield_kiting"
const GAUGE_COST := 130.0
const COOLDOWN_SECONDS := 12.0
const HOMING_STRENGTH := 0.40
const SPEED_BURST_MULTIPLIER := 1.30
const HIT_GOLD := 15
const DOUBLE_TAP_THRESHOLD_MSEC := 280
const DOUBLE_TAP_COOLDOWN_MSEC := 200

const STATE_WIND_UP := "wind_up"
const STATE_OUTBOUND := "outbound"
const STATE_RETURN := "return"
const STATE_LANDED := "landed"

const WIND_UP_MSEC := 320
const URGENT_WIND_UP_MSEC := 90
const PANIC_WIND_UP_MSEC := 0
const PANIC_Y_GAP := 50.0
const PANIC_INTERCEPT_FRAMES := 8.0
const URGENT_X_GAP := 145.0
const URGENT_Y_GAP := 140.0
const URGENT_DESCEND_SPEED := 1.0
const EMERGENCY_INTERCEPT_FRAMES := 26.0
const OUTBOUND_DURATION_MSEC := 460
const OUTBOUND_TIMEOUT_MSEC := 1100
const RETURN_LAND_DISTANCE := 5.0
const RETURN_APPROACH_DISTANCE := 40.0
const RETURN_APPROACH_FLOOR := 0.55
const ROTATION_SPEED := 540.0
const CURVE_AMPLITUDE := 36.0
const MIN_CURVE_FACTOR := 0.18
const FULL_CURVE_X_DISTANCE := 120.0
const CLOSE_PUNCH_X_GAP := 360.0
const CLOSE_PUNCH_MIN_LIFT := 115.0
const CLOSE_PUNCH_APEX_LIFT := 210.0
const CLOSE_PUNCH_PAST_BALL := 95.0
const CLOSE_PUNCH_HIT_RADIUS_BONUS := 26.0
const CLOSE_PUNCH_EARLY_CATCH_RADIUS_BONUS := 16.0
const CLOSE_PUNCH_OUTBOUND_DURATION_MSEC := 340
const EMERGENCY_GUARD_OUTBOUND_DURATION_MSEC := 130
const EMERGENCY_GUARD_LEAD_FRAMES := 2.0
const EMERGENCY_GUARD_LEAD_MAX_Y := 32.0
const MIN_HIT_FOLLOWTHROUGH_PROGRESS := 0.22
const MIN_HIT_FOLLOWTHROUGH_DISTANCE := 70.0
const CLOSE_PUNCH_FOLLOWTHROUGH_DISTANCE := 140.0
const RETURN_BASE_MULTIPLIER := 0.85
const RETURN_RAMP_BASE := 0.20
const RETURN_RAMP_RANGE := 1.80
const RETURN_RAMP_POWER := 3.0
const RETURN_RAMP_FRAMES := 28.0
const RETURN_WOBBLE_FADE_IN_FRAMES := 8.0
const MISS_RETURN_WOBBLE_SCALE := 0.45
const HOMING_X_GAIN := 0.13
const HOMING_Y_GAIN := 0.18
const HOMING_START_PROGRESS := 0.0
const TARGET_DRIFT_RATE := 0.26
const TARGET_LEAD_X_FRAMES := 8.0
const TARGET_LEAD_Y_FRAMES := 11.0
const TARGET_LEAD_MAX_X := 110.0
const TARGET_LEAD_MAX_Y := 140.0
const TRACKING_VEL_BLEND := 0.45
const TRACKING_MAX_SPEED := 20.0
const HIT_RADIUS_SCALE := 0.88
const OUTBOUND_BASE_MIN_LIFT := 150.0
const NEAR_RANGE_Y_DISTANCE := 170.0
const NEAR_RANGE_MIN_LIFT := 30.0
const EARLY_MISS_START_PROGRESS := 0.46
const EARLY_MISS_Y_GAP := 24.0
const EARLY_MISS_X_GAP := 34.0
const TRAIL_LEN := 4
const SHIELD_RADIUS := 36.0
const BOOMERANG_RETURN_SPEED := 8.4
const DEFAULT_BALL_SIZE := 28.6
const DEFAULT_PLAYER_SIZE := Vector2(155.0, 50.0)
const SHIELD_HIT_ENERGY_INTENSITY := 0.78
const SHIELD_HIT_SHAKE_AMOUNT := 0.11
const SHIELD_HIT_SHAKE_INTENSITY := 3.2
const PLASMA_HIT_SHARD_COUNT := 5
const PLASMA_HIT_EFFECT_MAX_COUNT := 3
const PARTIAL_CUTIN_DURATION := 1.70

var projectile: Dictionary = {}
var hit_effects: Array = []
var renderer: Object = SmasherShieldKitingRenderer.new()
var cutin_state: Object = SmasherSkillPartialCutinState.new()
var last_action_edge_msec := -100000
var post_activate_cooldown_until_msec := 0
var previous_action_pressed := false
var locked_player_x := 0.0
var launch_sound_pending := false


func reset() -> void:
	projectile.clear()
	hit_effects.clear()
	cutin_state.reset()
	last_action_edge_msec = -100000
	post_activate_cooldown_until_msec = 0
	previous_action_pressed = false
	locked_player_x = 0.0
	launch_sound_pending = false


func reset_round(deps: Dictionary = {}) -> void:
	projectile.clear()
	hit_effects.clear()
	cutin_state.reset()
	locked_player_x = 0.0
	launch_sound_pending = false
	_stop_wind_up_sound(deps)


func update_input(
	input_snapshot: Dictionary,
	current_msec: int,
	special_gauge: float,
	player_pos: Vector2,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var result := {
		"special_gauge": special_gauge,
		"activated": false,
		"movement_locked": is_movement_locked(),
		"locked_player_x": locked_player_x,
	}

	var action_pressed: bool = bool(input_snapshot.get("action_pressed", false))
	var action_edge: bool = action_pressed and not previous_action_pressed
	previous_action_pressed = action_pressed

	if not _is_skill_equipped(deps.get("skill_config", null)):
		return result
	if _is_power_motion_locked(deps):
		last_action_edge_msec = -100000
		return result
	if not bool(config.get("ball_active", false)):
		# 투사체는 update_and_collide(볼 패스 전용)로만 전진한다. 공 게이트가 닫힌
		# 창(승리 전리품 페이즈 · 서브 대기 등)은 볼 패스가 아예 돌지 않으므로
		# 살아있는 WIND_UP 투사체는 영원히 발사되지 않고 이동잠금만 남는다.
		# 여기서 해제해 잠금이 페이즈를 넘겨 살아남지 못하게 한다.
		_release_stalled_projectile(deps)
		result["movement_locked"] = false
		result["locked_player_x"] = locked_player_x
		return result
	if _has_live_projectile():
		result["movement_locked"] = is_movement_locked()
		result["locked_player_x"] = locked_player_x
		return result
	if not action_edge:
		return result

	if current_msec < post_activate_cooldown_until_msec:
		last_action_edge_msec = current_msec
		return result

	if current_msec - last_action_edge_msec > DOUBLE_TAP_THRESHOLD_MSEC:
		last_action_edge_msec = current_msec
		return result

	last_action_edge_msec = -100000
	if special_gauge < _get_skill_cost(deps.get("skill_config", null)):
		return result
	if _get_cooldown_remaining(deps, current_msec) > 0.0:
		return result

	var origin: Vector2 = _get_shield_attach_point(player_pos, _get_player_size(config))
	projectile = _build_projectile(origin, current_msec, config)
	cutin_state.begin(SKILL_NAME, PARTIAL_CUTIN_DURATION)
	locked_player_x = player_pos.x
	post_activate_cooldown_until_msec = current_msec + DOUBLE_TAP_COOLDOWN_MSEC

	var next_gauge: float = max(0.0, special_gauge - _get_skill_cost(deps.get("skill_config", null)))
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state != null and skill_state.has_method("trigger_configured_cooldown"):
		skill_state.trigger_configured_cooldown(SKILL_NAME, current_msec, deps.get("skill_config", null))
	else:
		_trigger_fallback_cooldown(skill_state, current_msec)
	_play_wind_up_sound(deps)

	result["special_gauge"] = next_gauge
	result["activated"] = true
	result["movement_locked"] = true
	result["locked_player_x"] = locked_player_x
	return result


func update_and_collide(_fps_scale: float, scene: Dictionary, context: Dictionary, deps: Dictionary) -> Dictionary:
	var result := {}
	if str(context.get("selected_character_type", "smasher")) != "smasher":
		return result
	if not _has_live_projectile():
		return result

	_play_pending_launch_sound(deps)
	var now_msec: int = Time.get_ticks_msec()
	var player_pos: Vector2 = _get_vector2(context, "player_pos", Vector2.ZERO)
	var player_size: Vector2 = _get_player_size(context)
	var owner_target: Vector2 = _get_shield_attach_point(player_pos, player_size)
	var events: Array = _update_projectile(projectile, now_msec, owner_target, scene, context)

	for event in events:
		if not (event is Dictionary):
			continue
		var event_type: String = str(event.get("type", ""))
		if event_type == "launched":
			_queue_launch_sound(deps)
		elif event_type == "ball_hit":
			_apply_ball_hit(scene, context, deps, result)
		elif event_type == "returned":
			projectile.clear()

	if _has_live_projectile() and not bool(projectile.get("active", false)):
		projectile.clear()
	return result


func update_effects(fps_scale: float) -> void:
	if cutin_state.is_active():
		cutin_state.update(fps_scale / 60.0)
	_update_hit_effects(fps_scale)


func is_movement_locked() -> bool:
	return _has_live_projectile() and str(projectile.get("state", "")) == STATE_WIND_UP


func get_locked_player_x() -> float:
	return locked_player_x


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if renderer != null and renderer.has_method("draw"):
		renderer.draw(canvas, projectile, hit_effects, shake_offset)


func get_snapshot() -> Dictionary:
	return {
		"projectile": projectile,
		"hit_effects": hit_effects,
		"movement_locked": is_movement_locked(),
	}


func has_visible_effects() -> bool:
	return _has_live_projectile() or not hit_effects.is_empty()


func needs_effect_update() -> bool:
	return cutin_state.is_active() or not hit_effects.is_empty()


func is_partial_cutin_active() -> bool:
	return cutin_state.is_active()


func draw_cutin_symbol(
	canvas: CanvasItem,
	center: Vector2,
	progress: float,
	alpha: float,
	view_size: Vector2
) -> void:
	if renderer != null and renderer.has_method("draw_cutin_symbol"):
		renderer.draw_cutin_symbol(canvas, center, progress, alpha, view_size)


func _build_projectile(origin: Vector2, current_msec: int, config: Dictionary) -> Dictionary:
	var tracked_velocity: Vector2 = _clamp_tracking_velocity(_get_vector2(config, "ball_vel", Vector2.ZERO))
	return {
		"state": STATE_WIND_UP,
		"active": true,
		"hit_ball": false,
		"origin": origin,
		"position": origin,
		"start_position": origin,
		"launch_target": origin + Vector2(0.0, -180.0),
		"curve_sign": 1.0,
		"curve_strength": 1.0,
		"close_punch_active": false,
		"emergency_guard_active": false,
		"curve_offset": Vector2.ZERO,
		"angle": 0.0,
		"trail": [],
		"homing_strength": HOMING_STRENGTH,
		"outbound_progress": 0.0,
		"outbound_duration_msec": OUTBOUND_DURATION_MSEC,
		"return_ramp_t": 0.0,
		"return_elapsed": 0.0,
		"return_missed": false,
		"return_wobble_phase": 0.0,
		"return_wobble_amp": 12.0,
		"tracked_ball_center": _get_ball_center(config),
		"tracked_ball_velocity": tracked_velocity,
		"started_msec": current_msec,
		"last_update_msec": current_msec,
		"outbound_started_msec": 0,
		"gold_awarded": false,
		"windup_strength": 0.0,
	}


func _update_projectile(
	data: Dictionary,
	now_msec: int,
	owner_target: Vector2,
	scene: Dictionary,
	context: Dictionary
) -> Array:
	if not bool(data.get("active", false)):
		return []

	var events: Array = []
	var last_update: int = int(data.get("last_update_msec", now_msec))
	var delta_msec: int = max(1, now_msec - last_update)
	data["last_update_msec"] = now_msec
	var dt: float = min(2.5, float(delta_msec) / 16.6667)
	var dt_seconds: float = float(delta_msec) / 1000.0
	var state: String = str(data.get("state", STATE_WIND_UP))
	var ball_center: Vector2 = _get_ball_center(scene)

	if state == STATE_WIND_UP:
		_update_ball_tracking(data, ball_center, dt)
		data["position"] = owner_target
		data["angle"] = float(data.get("angle", 0.0)) - ROTATION_SPEED * 0.18 * dt_seconds
		data["windup_strength"] = _get_windup_strength(now_msec, int(data.get("started_msec", now_msec)))
		if now_msec - int(data.get("started_msec", now_msec)) >= _get_required_wind_up_msec(data, ball_center):
			_start_outbound(data, ball_center)
			events.append({"type": "launched"})
			if _collides_with_ball(data, scene, context):
				data["hit_ball"] = true
				events.append({"type": "ball_hit"})
	elif state == STATE_OUTBOUND:
		var duration: float = max(1.0, float(data.get("outbound_duration_msec", OUTBOUND_DURATION_MSEC)))
		var progress: float = min(1.0, float(data.get("outbound_progress", 0.0)) + dt_seconds / (duration / 1000.0))
		data["outbound_progress"] = progress
		var eased: float = 1.0 - pow(1.0 - progress, 3.0)

		var start_position: Vector2 = _as_vector2(data.get("start_position", owner_target), owner_target)
		var launch_target: Vector2 = _as_vector2(data.get("launch_target", owner_target + Vector2(0.0, -180.0)), owner_target + Vector2(0.0, -180.0))
		var base: Vector2 = start_position.lerp(launch_target, eased)
		var curve_x: float = sin(progress * PI) * CURVE_AMPLITUDE * float(data.get("curve_sign", 1.0)) * float(data.get("curve_strength", 1.0))
		var curve_offset: Vector2 = _as_vector2(data.get("curve_offset", Vector2.ZERO), Vector2.ZERO)

		_update_ball_tracking(data, ball_center, dt)
		var predicted: Vector2 = _get_predicted_ball_target(data, ball_center)
		if bool(data.get("emergency_guard_active", false)):
			var tracked_vel: Vector2 = _as_vector2(data.get("tracked_ball_velocity", Vector2.ZERO), Vector2.ZERO)
			predicted = ball_center + Vector2(
				0.0,
				min(EMERGENCY_GUARD_LEAD_MAX_Y, max(0.0, tracked_vel.y * EMERGENCY_GUARD_LEAD_FRAMES))
			)
		elif bool(data.get("close_punch_active", false)):
			predicted.y = _get_close_punch_apex_y(data, predicted.y)

		var drift: float = min(0.9, TARGET_DRIFT_RATE * dt)
		launch_target = launch_target.lerp(predicted, drift)
		data["launch_target"] = launch_target

		var homing_factor: float = max(0.0, progress - HOMING_START_PROGRESS)
		homing_factor *= float(data.get("homing_strength", HOMING_STRENGTH))
		var current_probe := Vector2(base.x + curve_x + curve_offset.x, base.y + curve_offset.y)
		var delta_to_ball: Vector2 = predicted - current_probe
		curve_offset.x = clamp(curve_offset.x + delta_to_ball.x * homing_factor * HOMING_X_GAIN * dt, -140.0, 140.0)
		curve_offset.y = clamp(curve_offset.y + delta_to_ball.y * homing_factor * HOMING_Y_GAIN * dt, -80.0, 80.0)
		data["curve_offset"] = curve_offset
		data["position"] = Vector2(base.x + curve_x + curve_offset.x, base.y + curve_offset.y)
		data["angle"] = float(data.get("angle", 0.0)) + ROTATION_SPEED * dt_seconds
		_record_trail(data)

		if bool(data.get("hit_ball", false)):
			if _hit_followthrough_finished(data) or progress >= 1.0 or now_msec - int(data.get("outbound_started_msec", now_msec)) >= OUTBOUND_TIMEOUT_MSEC:
				_start_return(data, false)
			return events

		if _collides_with_ball(data, scene, context):
			data["hit_ball"] = true
			events.append({"type": "ball_hit"})
			if _hit_followthrough_finished(data):
				_start_return(data, false)
			return events

		var position: Vector2 = _as_vector2(data.get("position", Vector2.ZERO), Vector2.ZERO)
		var ball_delta: Vector2 = ball_center - position
		if progress >= EARLY_MISS_START_PROGRESS and ball_delta.y >= EARLY_MISS_Y_GAP and abs(ball_delta.x) >= EARLY_MISS_X_GAP:
			_start_return(data, true)
			events.append({"type": "miss_abort"})
			return events
		if progress >= 1.0 or now_msec - int(data.get("outbound_started_msec", now_msec)) >= OUTBOUND_TIMEOUT_MSEC:
			_start_return(data, true)
			events.append({"type": "miss_timeout"})
	elif state == STATE_RETURN:
		var position: Vector2 = _as_vector2(data.get("position", owner_target), owner_target)
		var to_target: Vector2 = owner_target - position
		var dist: float = to_target.length()
		if dist <= RETURN_LAND_DISTANCE:
			data["position"] = owner_target
			data["state"] = STATE_LANDED
			data["active"] = false
			events.append({"type": "returned"})
		elif dist > 0.001:
			var direction: Vector2 = to_target / dist
			var perp := Vector2(-direction.y, direction.x)
			var ramp_t: float = min(1.0, float(data.get("return_ramp_t", 0.0)) + dt / RETURN_RAMP_FRAMES)
			var elapsed: float = float(data.get("return_elapsed", 0.0)) + dt
			var return_mul: float = RETURN_RAMP_BASE + RETURN_RAMP_RANGE * pow(ramp_t, RETURN_RAMP_POWER)
			return_mul *= max(RETURN_APPROACH_FLOOR, min(1.0, dist / RETURN_APPROACH_DISTANCE))
			var wobble_phase: float = float(data.get("return_wobble_phase", 0.0)) + 0.11 * dt
			var lateral: float = sin(wobble_phase) * float(data.get("return_wobble_amp", 12.0))
			lateral *= min(1.0, dist / 160.0)
			lateral *= min(1.0, elapsed / RETURN_WOBBLE_FADE_IN_FRAMES)
			if bool(data.get("return_missed", false)):
				lateral *= MISS_RETURN_WOBBLE_SCALE
			var step: float = min(dist, BOOMERANG_RETURN_SPEED * RETURN_BASE_MULTIPLIER * return_mul * dt)
			data["position"] = position + direction * step + perp * lateral * 0.12
			data["angle"] = float(data.get("angle", 0.0)) + ROTATION_SPEED * 1.15 * dt_seconds
			data["return_ramp_t"] = ramp_t
			data["return_elapsed"] = elapsed
			data["return_wobble_phase"] = wobble_phase
			_record_trail(data)

	return events


func _start_outbound(data: Dictionary, ball_center: Vector2) -> void:
	data["state"] = STATE_OUTBOUND
	data["outbound_started_msec"] = Time.get_ticks_msec()
	data["outbound_progress"] = 0.0
	var start_position: Vector2 = _as_vector2(data.get("position", Vector2.ZERO), Vector2.ZERO)
	data["start_position"] = start_position
	var target: Vector2 = _get_predicted_ball_target(data, ball_center)
	var target_dx: float = target.x - start_position.x
	var close_horizontal: bool = abs(target_dx) <= CLOSE_PUNCH_X_GAP
	var close_vertical: bool = target.y >= _get_close_punch_target_y(data)
	var tracked_vel: Vector2 = _as_vector2(data.get("tracked_ball_velocity", Vector2.ZERO), Vector2.ZERO)
	var descending: bool = tracked_vel.y >= URGENT_DESCEND_SPEED

	var emergency_guard: bool = _is_emergency_guard_intercept(data, ball_center)
	data["emergency_guard_active"] = emergency_guard
	if emergency_guard:
		target = ball_center + Vector2(
			0.0,
			min(EMERGENCY_GUARD_LEAD_MAX_Y, max(0.0, tracked_vel.y * EMERGENCY_GUARD_LEAD_FRAMES))
		)
		target_dx = target.x - start_position.x
		close_horizontal = true
		data["close_punch_active"] = true
		data["outbound_duration_msec"] = EMERGENCY_GUARD_OUTBOUND_DURATION_MSEC
	else:
		var close_punch: bool = close_horizontal and (close_vertical or descending)
		data["close_punch_active"] = close_punch
		if close_punch:
			target.y = _get_close_punch_apex_y(data, target.y)
			data["outbound_duration_msec"] = CLOSE_PUNCH_OUTBOUND_DURATION_MSEC
		else:
			data["outbound_duration_msec"] = OUTBOUND_DURATION_MSEC

	var launch_y: float = target.y if emergency_guard else _get_outbound_target_y(data, target.y)
	data["launch_target"] = Vector2(target.x, launch_y)
	var curve_sign: float = 1.0 if target_dx >= 0.0 else -1.0
	if abs(target_dx) < 8.0:
		curve_sign = 1.0
	data["curve_sign"] = curve_sign
	data["curve_strength"] = max(MIN_CURVE_FACTOR, min(1.0, abs(target_dx) / FULL_CURVE_X_DISTANCE))
	data["curve_offset"] = Vector2.ZERO
	data["windup_strength"] = 0.0


func _start_return(data: Dictionary, missed: bool) -> void:
	data["state"] = STATE_RETURN
	data["return_missed"] = missed
	data["return_elapsed"] = 0.0
	data["return_wobble_phase"] = 0.0
	data["return_ramp_t"] = 0.6 if missed else 0.0


func _apply_ball_hit(scene: Dictionary, context: Dictionary, deps: Dictionary, result: Dictionary) -> void:
	_play_hit_sound(deps)
	var hit_dir: Vector2 = _get_hit_direction(projectile)
	if hit_dir.length_squared() <= 0.00001:
		hit_dir = Vector2(0.0, -1.0)
	else:
		hit_dir = hit_dir.normalized()
	if hit_dir.y > -0.15:
		hit_dir.y = -abs(hit_dir.y) - 0.45
		hit_dir = hit_dir.normalized()
	var current_speed: float = max(7.0, _get_vector2(scene, "ball_vel", Vector2.ZERO).length())
	var next_vel: Vector2 = hit_dir * current_speed * SPEED_BURST_MULTIPLIER
	if next_vel.y > 0.0:
		next_vel.y = -abs(next_vel.y)
	scene["ball_vel"] = next_vel
	result["ball_vel"] = next_vel

	var ball_intensity: Object = deps.get("ball_intensity", null)
	if ball_intensity != null and ball_intensity.has_method("register_hit"):
		ball_intensity.register_hit("player")
	var impact_effects: Object = deps.get("impact_effects", null)
	var ball_pos: Vector2 = _get_ball_center(scene)
	var ball_effects: Object = deps.get("ball_effects", null)
	var pulse_registered := false
	if ball_effects != null and ball_effects.has_method("register_hit_pulse"):
		ball_effects.register_hit_pulse(ball_pos, next_vel, SHIELD_HIT_ENERGY_INTENSITY, "shield_kiting")
		pulse_registered = true
	if not pulse_registered and impact_effects != null:
		if impact_effects.has_method("spawn_paddle_hit_particles"):
			impact_effects.spawn_paddle_hit_particles(ball_pos, true, next_vel, SHIELD_HIT_ENERGY_INTENSITY)
		if impact_effects.has_method("create_energy_explosion"):
			impact_effects.create_energy_explosion(ball_pos, 0.62, SHIELD_HIT_ENERGY_INTENSITY)
	_spawn_plasma_hit_effect(ball_pos, next_vel)
	_trigger_feedback(deps)

	if not bool(projectile.get("gold_awarded", false)):
		projectile["gold_awarded"] = true
		var runtime_perk_state: Object = deps.get("runtime_perk_state", null)
		if runtime_perk_state != null and runtime_perk_state.has_method("award_gold"):
			result["runtime_perk_gold"] = int(_call_award_gold(runtime_perk_state, HIT_GOLD, context, deps))


func _update_ball_tracking(data: Dictionary, ball_center: Vector2, dt: float) -> void:
	var previous: Vector2 = _as_vector2(data.get("tracked_ball_center", ball_center), ball_center)
	var velocity: Vector2 = _as_vector2(data.get("tracked_ball_velocity", Vector2.ZERO), Vector2.ZERO)
	if dt > 0.00001:
		var raw: Vector2 = (ball_center - previous) / dt
		velocity = velocity * (1.0 - TRACKING_VEL_BLEND) + raw * TRACKING_VEL_BLEND
		velocity = _clamp_tracking_velocity(velocity)
	data["tracked_ball_center"] = ball_center
	data["tracked_ball_velocity"] = velocity


func _get_predicted_ball_target(data: Dictionary, ball_center: Vector2) -> Vector2:
	var velocity: Vector2 = _as_vector2(data.get("tracked_ball_velocity", Vector2.ZERO), Vector2.ZERO)
	var lead := Vector2(
		clamp(velocity.x * TARGET_LEAD_X_FRAMES, -TARGET_LEAD_MAX_X, TARGET_LEAD_MAX_X),
		clamp(velocity.y * TARGET_LEAD_Y_FRAMES, -TARGET_LEAD_MAX_Y, TARGET_LEAD_MAX_Y)
	)
	return ball_center + lead


func _get_required_wind_up_msec(data: Dictionary, ball_center: Vector2) -> int:
	var position: Vector2 = _as_vector2(data.get("position", Vector2.ZERO), Vector2.ZERO)
	var horizontal_gap: float = abs(ball_center.x - position.x)
	var vertical_gap: float = position.y - ball_center.y
	var vy: float = _as_vector2(data.get("tracked_ball_velocity", Vector2.ZERO), Vector2.ZERO).y
	var descending: bool = vy >= URGENT_DESCEND_SPEED
	var low_far_ball: bool = horizontal_gap >= URGENT_X_GAP and vertical_gap <= URGENT_Y_GAP
	var frames_to_player: float = vertical_gap / vy if descending and vertical_gap > 0.0 else INF
	var emergency_intercept: bool = descending and frames_to_player <= EMERGENCY_INTERCEPT_FRAMES
	var panic_intercept: bool = descending and (vertical_gap <= PANIC_Y_GAP or frames_to_player <= PANIC_INTERCEPT_FRAMES)
	if low_far_ball or panic_intercept:
		return PANIC_WIND_UP_MSEC
	if emergency_intercept:
		return URGENT_WIND_UP_MSEC
	return WIND_UP_MSEC


func _is_emergency_guard_intercept(data: Dictionary, ball_center: Vector2) -> bool:
	var position: Vector2 = _as_vector2(data.get("position", Vector2.ZERO), Vector2.ZERO)
	var horizontal_gap: float = abs(ball_center.x - position.x)
	var vertical_gap: float = position.y - ball_center.y
	if horizontal_gap >= URGENT_X_GAP and vertical_gap <= URGENT_Y_GAP:
		return true
	var vy: float = _as_vector2(data.get("tracked_ball_velocity", Vector2.ZERO), Vector2.ZERO).y
	if vy < URGENT_DESCEND_SPEED:
		return false
	var frames_to_player: float = vertical_gap / vy if vertical_gap > 0.0 else 0.0
	return (
		vertical_gap <= PANIC_Y_GAP
		or frames_to_player <= PANIC_INTERCEPT_FRAMES
		or (horizontal_gap >= URGENT_X_GAP and frames_to_player <= EMERGENCY_INTERCEPT_FRAMES)
	)


func _get_outbound_target_y(data: Dictionary, target_y: float) -> float:
	var start_position: Vector2 = _as_vector2(data.get("start_position", Vector2.ZERO), Vector2.ZERO)
	var distance_y: float = max(0.0, start_position.y - target_y)
	var near_factor: float = 1.0 - min(1.0, distance_y / NEAR_RANGE_Y_DISTANCE)
	var min_lift: float = OUTBOUND_BASE_MIN_LIFT * (1.0 - near_factor) + NEAR_RANGE_MIN_LIFT * near_factor
	var apex_cap: float = start_position.y - min_lift
	return min(apex_cap, target_y)


func _get_close_punch_target_y(data: Dictionary) -> float:
	var start_position: Vector2 = _as_vector2(data.get("start_position", _as_vector2(data.get("position", Vector2.ZERO), Vector2.ZERO)), Vector2.ZERO)
	return start_position.y - CLOSE_PUNCH_MIN_LIFT


func _get_close_punch_apex_y(data: Dictionary, ball_target_y: float) -> float:
	var start_position: Vector2 = _as_vector2(data.get("start_position", _as_vector2(data.get("position", Vector2.ZERO), Vector2.ZERO)), Vector2.ZERO)
	var start_y: float = start_position.y
	var vy: float = _as_vector2(data.get("tracked_ball_velocity", Vector2.ZERO), Vector2.ZERO).y
	if vy >= URGENT_DESCEND_SPEED:
		return min(start_y - NEAR_RANGE_MIN_LIFT, ball_target_y)
	var vertical_gap: float = start_y - ball_target_y
	var past_ball_y: float = ball_target_y - CLOSE_PUNCH_PAST_BALL
	if vertical_gap <= 8.0:
		return min(start_y - CLOSE_PUNCH_MIN_LIFT, past_ball_y)
	if vertical_gap <= 40.0:
		return min(start_y - 40.0, ball_target_y - 20.0)
	if vertical_gap <= 150.0:
		return min(start_y - CLOSE_PUNCH_MIN_LIFT, ball_target_y - 30.0)
	return min(start_y - CLOSE_PUNCH_APEX_LIFT, past_ball_y)


func _hit_followthrough_finished(data: Dictionary) -> bool:
	var position: Vector2 = _as_vector2(data.get("position", Vector2.ZERO), Vector2.ZERO)
	var start_position: Vector2 = _as_vector2(data.get("start_position", position), position)
	var travel_distance: float = position.distance_to(start_position)
	if bool(data.get("close_punch_active", false)):
		return travel_distance >= CLOSE_PUNCH_FOLLOWTHROUGH_DISTANCE
	return float(data.get("outbound_progress", 0.0)) >= MIN_HIT_FOLLOWTHROUGH_PROGRESS or travel_distance >= MIN_HIT_FOLLOWTHROUGH_DISTANCE


func _collides_with_ball(data: Dictionary, scene: Dictionary, context: Dictionary) -> bool:
	var radius: float = SHIELD_RADIUS * HIT_RADIUS_SCALE
	if bool(data.get("close_punch_active", false)):
		radius += CLOSE_PUNCH_HIT_RADIUS_BONUS
		if float(data.get("outbound_progress", 0.0)) <= 0.2:
			radius += CLOSE_PUNCH_EARLY_CATCH_RADIUS_BONUS
	var ball_radius: float = max(1.0, float(context.get("ball_size", DEFAULT_BALL_SIZE))) * 0.5
	var position: Vector2 = _as_vector2(data.get("position", Vector2.ZERO), Vector2.ZERO)
	return position.distance_squared_to(_get_ball_center(scene)) <= pow(radius + ball_radius, 2.0)


func _get_hit_direction(data: Dictionary) -> Vector2:
	var state: String = str(data.get("state", ""))
	var position: Vector2 = _as_vector2(data.get("position", Vector2.ZERO), Vector2.ZERO)
	var origin: Vector2 = _as_vector2(data.get("origin", position), position)
	if state == STATE_RETURN and origin.distance_squared_to(position) > 0.00001:
		return (origin - position).normalized()
	var angle_rad: float = deg_to_rad(float(data.get("angle", 0.0)) - 90.0)
	return Vector2(cos(angle_rad), sin(angle_rad))


func _record_trail(data: Dictionary) -> void:
	var trail: Array = _as_array(data.get("trail", []))
	trail.append({
		"pos": _as_vector2(data.get("position", Vector2.ZERO), Vector2.ZERO),
		"angle": float(data.get("angle", 0.0)),
	})
	if trail.size() > TRAIL_LEN:
		trail.pop_front()
	data["trail"] = trail


func _spawn_plasma_hit_effect(pos: Vector2, ball_vel: Vector2) -> void:
	var shards: Array = []
	var base_angle: float = ball_vel.angle() if ball_vel.length_squared() > 0.001 else -PI * 0.5
	for _i in range(PLASMA_HIT_SHARD_COUNT):
		var angle: float = base_angle + randf_range(-1.55, 1.55)
		var speed: float = randf_range(2.4, 7.4)
		shards.append({
			"pos": pos + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0)),
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"length": randf_range(9.0, 23.0),
			"width": randf_range(1.2, 3.2),
			"warmth": randf(),
		})
	hit_effects.append({
		"pos": pos,
		"age": 0.0,
		"life": 0.34,
		"shards": shards,
	})
	while hit_effects.size() > PLASMA_HIT_EFFECT_MAX_COUNT:
		hit_effects.pop_front()


func _update_hit_effects(fps_scale: float) -> void:
	var write_index := 0
	for read_index in range(hit_effects.size()):
		var effect: Variant = hit_effects[read_index]
		if not (effect is Dictionary):
			continue
		var age: float = float(effect.get("age", 0.0)) + fps_scale / 60.0
		var life: float = max(0.01, float(effect.get("life", 0.34)))
		if age >= life:
			continue
		var shards: Array = _as_array(effect.get("shards", []))
		for shard in shards:
			if shard is Dictionary:
				shard["pos"] = _as_vector2(shard.get("pos", Vector2.ZERO), Vector2.ZERO) + _as_vector2(shard.get("vel", Vector2.ZERO), Vector2.ZERO) * fps_scale
				shard["vel"] = _as_vector2(shard.get("vel", Vector2.ZERO), Vector2.ZERO) * pow(0.94, fps_scale)
		effect["age"] = age
		effect["shards"] = shards
		hit_effects[write_index] = effect
		write_index += 1
	if write_index < hit_effects.size():
		hit_effects.resize(write_index)


func _get_windup_strength(now_msec: int, start_msec: int) -> float:
	var windup_t: float = clamp(float(now_msec - start_msec) / float(max(1, WIND_UP_MSEC)), 0.0, 1.0)
	if windup_t < 0.62:
		var back_t: float = windup_t / 0.62
		return 1.0 - pow(1.0 - back_t, 2.0)
	var forward_t: float = (windup_t - 0.62) / 0.38
	return max(0.0, min(1.0, 1.0 - pow(forward_t, 3.0)))


func _get_shield_attach_point(player_pos: Vector2, player_size: Vector2) -> Vector2:
	return player_pos + Vector2(player_size.x * 0.70, player_size.y * 0.34)


func _get_player_size(source: Dictionary) -> Vector2:
	return _get_vector2(source, "player_paddle_size", Vector2(
		max(1.0, float(source.get("paddle_width", DEFAULT_PLAYER_SIZE.x))),
		max(1.0, float(source.get("paddle_height", DEFAULT_PLAYER_SIZE.y)))
	))


func _get_ball_center(source: Dictionary) -> Vector2:
	return _get_vector2(source, "ball_pos", Vector2.ZERO)


func _clamp_tracking_velocity(value: Vector2) -> Vector2:
	return Vector2(
		clamp(value.x, -TRACKING_MAX_SPEED, TRACKING_MAX_SPEED),
		clamp(value.y, -TRACKING_MAX_SPEED, TRACKING_MAX_SPEED)
	)


func _trigger_feedback(deps: Dictionary) -> void:
	var feedback: Object = deps.get("feedback", null)
	if feedback == null:
		return
	if feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(SHIELD_HIT_SHAKE_AMOUNT, SHIELD_HIT_SHAKE_INTENSITY)
	elif feedback.has_method("set_screen_shake"):
		feedback.set_screen_shake(SHIELD_HIT_SHAKE_AMOUNT, SHIELD_HIT_SHAKE_INTENSITY)


func _play_wind_up_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_shield_kiting_wind_up"):
		audio.play_shield_kiting_wind_up()


func _stop_wind_up_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("stop_shield_kiting_wind_up"):
		audio.stop_shield_kiting_wind_up()


func _play_launch_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_shield_kiting_launch"):
		audio.play_shield_kiting_launch()


func _queue_launch_sound(deps: Dictionary) -> void:
	if _is_wind_up_sound_busy(deps):
		launch_sound_pending = true
		return
	launch_sound_pending = false
	_play_launch_sound(deps)


func _play_pending_launch_sound(deps: Dictionary) -> void:
	if not launch_sound_pending:
		return
	if _is_wind_up_sound_busy(deps):
		return
	launch_sound_pending = false
	_play_launch_sound(deps)


func _is_wind_up_sound_busy(deps: Dictionary) -> bool:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("is_shield_kiting_wind_up_playing"):
		return bool(audio.is_shield_kiting_wind_up_playing())
	return false


func _play_hit_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_shield_kiting_hit"):
		audio.play_shield_kiting_hit()


func _trigger_fallback_cooldown(skill_state: Object, current_msec: int) -> void:
	if skill_state != null and skill_state.has_method("trigger_cooldown"):
		skill_state.trigger_cooldown(SKILL_NAME, current_msec, COOLDOWN_SECONDS)


func _get_cooldown_remaining(deps: Dictionary, current_msec: int) -> float:
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state != null and skill_state.has_method("get_configured_cooldown_remaining"):
		return float(skill_state.get_configured_cooldown_remaining(SKILL_NAME, current_msec, deps.get("skill_config", null)))
	return 0.0


func _get_skill_cost(skill_config: Object) -> float:
	if skill_config != null and skill_config.has_method("get_skill_cost"):
		return float(skill_config.get_skill_cost(SKILL_NAME))
	return GAUGE_COST


func _is_skill_equipped(skill_config: Object) -> bool:
	if skill_config != null and skill_config.has_method("is_skill_equipped"):
		return bool(skill_config.is_skill_equipped(SKILL_NAME))
	return false


func _is_power_motion_locked(deps: Dictionary) -> bool:
	var power_state: Object = deps.get("power_state", null)
	if power_state == null:
		return false
	if power_state.has_method("is_freeze_active") and bool(power_state.is_freeze_active()):
		return true
	if power_state.has_method("is_parabola_active") and bool(power_state.is_parabola_active()):
		return true
	return false


func _has_live_projectile() -> bool:
	return not projectile.is_empty() and bool(projectile.get("active", false))


func _release_stalled_projectile(deps: Dictionary) -> void:
	if projectile.is_empty():
		return
	projectile.clear()
	launch_sound_pending = false
	_stop_wind_up_sound(deps)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return _as_vector2(source.get(key, fallback), fallback)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _call_award_gold(runtime_perk_state: Object, amount: int, context: Dictionary, deps: Dictionary) -> int:
	if _method_accepts_arg_count(runtime_perk_state, "award_gold", 3):
		return int(runtime_perk_state.award_gold(amount, context, deps))
	return int(runtime_perk_state.award_gold(amount))


func _method_accepts_arg_count(target: Object, method_name: String, arg_count: int) -> bool:
	if target == null:
		return false
	for method in target.get_method_list():
		if str(method.get("name", "")) != method_name:
			continue
		var args: Variant = method.get("args", [])
		if args is Array:
			return (args as Array).size() >= arg_count
	return false
