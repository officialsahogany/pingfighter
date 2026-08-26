extends RefCounted

const SmasherDriveCutinState := preload("res://scripts/characters/smasher_drive_cutin_state.gd")
const RuntimePerkModalTimeShift := preload("res://scripts/core/runtime_perk_modal_time_shift.gd")

const SKILL_NAME := "magnum_grip"
const GAUGE_COST := 70.0
const MAX_DURATION_MSEC := 2500
const HOLD_DURATION_MSEC := 300
const PULL_ACCEL := 1.5325
const MAX_PULL_SPEED := 26.0
const RELEASE_HIT_MAX_BALL_SPEED := 45.0
const HIGH_SPEED_DAMPEN_START := 16.0
const HIGH_SPEED_DAMPEN_END := 31.0
const MIN_PULL_ACCEL_MULT := 0.28
const APPROACH_SPEED_FAR_CAP := 19.0
const APPROACH_SPEED_NEAR_CAP := 12.25
const NEAR_APPROACH_DISTANCE := 240.0
const MIN_APPROACH_SPEED_CAP := 8.0
const PADDLE_HOMING_SIDE_DAMPEN := 0.055
const PADDLE_HOMING_NEAR_BONUS := 0.04
const PARTICLE_CAP := 42
const CUTIN_DURATION_SEC := 1.20

var active := false
var start_msec := 0
var keys_released := true
var both_held_start_msec := 0
var ring_phase := 0.0
var arc_phase := 0.0
var last_burst_msec := 0
var activated_this_frame := false
var release_hit_pending := false
var release_hit_speed_cap_active := false
var particles: Array[Dictionary] = []
var cutin_state: Object = SmasherDriveCutinState.new()
var _runtime_perk_modal_pause_started_msec := -1


func reset() -> void:
	active = false
	start_msec = 0
	keys_released = true
	both_held_start_msec = 0
	ring_phase = 0.0
	arc_phase = 0.0
	last_burst_msec = 0
	activated_this_frame = false
	release_hit_pending = false
	release_hit_speed_cap_active = false
	_runtime_perk_modal_pause_started_msec = -1
	particles.clear()
	cutin_state.reset()


func reset_round() -> void:
	reset()


# 퍽 모달 동안 벽시계 앵커 동결. 규칙은 runtime_perk_modal_time_shift.gd 참조.
func pause_runtime_perk_modal_time(current_msec: int) -> void:
	_runtime_perk_modal_pause_started_msec = RuntimePerkModalTimeShift.begin_pause(
		_runtime_perk_modal_pause_started_msec, current_msec
	)


func resume_runtime_perk_modal_time(current_msec: int) -> void:
	if _runtime_perk_modal_pause_started_msec < 0:
		return
	var pause_started_msec: int = _runtime_perk_modal_pause_started_msec
	_runtime_perk_modal_pause_started_msec = -1
	shift_runtime_perk_modal_time(pause_started_msec, current_msec)


func shift_runtime_perk_modal_time(pause_started_msec: int, resumed_msec: int) -> void:
	var delta_msec: int = RuntimePerkModalTimeShift.resolve_paused_duration(pause_started_msec, resumed_msec)
	if delta_msec <= 0:
		return
	if active:
		start_msec = RuntimePerkModalTimeShift.shift_anchor(start_msec, delta_msec)
	last_burst_msec = RuntimePerkModalTimeShift.shift_anchor(last_burst_msec, delta_msec)
	both_held_start_msec = RuntimePerkModalTimeShift.shift_anchor(both_held_start_msec, delta_msec)


func is_active() -> bool:
	return active


func needs_effect_update() -> bool:
	return active or cutin_state.is_active()


func deactivate() -> bool:
	if not active:
		return false
	active = false
	particles.clear()
	return true


func force_release_for_lock() -> bool:
	both_held_start_msec = 0
	keys_released = true
	activated_this_frame = false
	clear_release_hit_speed_cap()
	return deactivate()


func consume_release_hit_speed_cap() -> bool:
	var should_apply := release_hit_pending
	release_hit_pending = false
	if should_apply:
		release_hit_speed_cap_active = true
	return should_apply


func clear_release_hit_speed_cap() -> void:
	release_hit_pending = false
	release_hit_speed_cap_active = false


func get_pending_release_hit_speed_cap() -> float:
	return RELEASE_HIT_MAX_BALL_SPEED if release_hit_pending else 0.0


func get_release_hit_speed_cap() -> float:
	return RELEASE_HIT_MAX_BALL_SPEED if release_hit_speed_cap_active else 0.0


func update_input(
	input_snapshot: Dictionary,
	current_msec: int,
	special_gauge: float,
	deps: Dictionary
) -> Dictionary:
	activated_this_frame = false
	var result := {
		"special_gauge": special_gauge,
		"activated": false,
		"deactivated": false,
	}

	if not _is_skill_equipped(deps.get("skill_config", null)):
		result["deactivated"] = deactivate()
		both_held_start_msec = 0
		return result

	if _is_power_motion_locked(deps):
		both_held_start_msec = 0
		_update_key_release(input_snapshot)
		return result

	var left_pressed: bool = bool(input_snapshot.get("left_pressed", false))
	var right_pressed: bool = bool(input_snapshot.get("right_pressed", false))
	if bool(input_snapshot.get("vision_input_exclusive", false)):
		both_held_start_msec = 0
		keys_released = not (left_pressed or right_pressed)
		return result
	var both_pressed: bool = left_pressed and right_pressed
	if both_pressed:
		if both_held_start_msec == 0:
			both_held_start_msec = current_msec
	else:
		both_held_start_msec = 0

	if not (left_pressed or right_pressed):
		keys_released = true

	if (
		not active
		and keys_released
		and both_held_start_msec > 0
		and current_msec - both_held_start_msec >= HOLD_DURATION_MSEC
		and special_gauge >= _get_skill_cost(deps.get("skill_config", null))
		and _get_cooldown_remaining(deps, current_msec) <= 0.0
	):
		active = true
		start_msec = current_msec
		keys_released = false
		last_burst_msec = current_msec
		activated_this_frame = true
		both_held_start_msec = 0
		particles.clear()
		cutin_state.begin(CUTIN_DURATION_SEC)
		var next_gauge: float = max(0.0, special_gauge - _get_skill_cost(deps.get("skill_config", null)))
		result["special_gauge"] = next_gauge
		result["activated"] = true
		var skill_state: Object = deps.get("skill_state", null)
		if skill_state != null and skill_state.has_method("trigger_configured_cooldown"):
			skill_state.trigger_configured_cooldown(SKILL_NAME, current_msec, deps.get("skill_config", null))

	return result


func update_effects(fps_scale: float, current_msec: int, context: Dictionary) -> Dictionary:
	if cutin_state.is_active():
		cutin_state.update(fps_scale / 60.0)
	if _expire_if_needed(current_msec):
		return {"deactivated": true}
	if not active:
		return {}

	ring_phase += 0.08 * fps_scale
	arc_phase += 0.14 * fps_scale
	_spawn_particles(context, fps_scale)
	_update_particles(context, fps_scale)
	return {"active": true}


func apply_ball_motion(
	fps_scale: float,
	ball_vel: Vector2,
	context: Dictionary,
	power_motion_locked: bool
) -> Dictionary:
	if _expire_if_needed(int(context.get("current_msec", Time.get_ticks_msec()))):
		return {"deactivated": true}
	if not active or power_motion_locked:
		return {}
	if _player_intersects_ball(context):
		return {"deactivated": deactivate()}

	var ball_center: Vector2 = _get_ball_center(context)
	var player_center: Vector2 = _get_player_center(context)
	var delta: Vector2 = player_center - ball_center
	var dist: float = delta.length()
	if dist <= 1.0:
		return {}

	var pull_dir: Vector2 = delta / dist
	var velocity: Vector2 = ball_vel + pull_dir * _get_effective_pull_accel(ball_vel, pull_dir, context) * fps_scale
	velocity = _steer_velocity_toward_paddle(velocity, pull_dir, dist, fps_scale)
	velocity = _cap_approach_speed(velocity, pull_dir, dist, context)
	var speed_cap: float = max(15.0, MAX_PULL_SPEED + 5.0)
	var speed: float = velocity.length()
	if speed > speed_cap:
		velocity *= speed_cap / speed
	release_hit_pending = true
	return {"ball_vel": velocity}


func get_draw_context() -> Dictionary:
	return {
		"active": active,
		"particles": particles,
		"ring_phase": ring_phase,
		"arc_phase": arc_phase,
		"start_msec": start_msec,
		"max_duration_msec": MAX_DURATION_MSEC,
		"last_burst_msec": last_burst_msec,
	}


func is_partial_cutin_active() -> bool:
	return cutin_state.is_active()


func _expire_if_needed(current_msec: int) -> bool:
	if active and current_msec - start_msec > MAX_DURATION_MSEC:
		return deactivate()
	return false


func _update_key_release(input_snapshot: Dictionary) -> void:
	var left_pressed: bool = bool(input_snapshot.get("left_pressed", false))
	var right_pressed: bool = bool(input_snapshot.get("right_pressed", false))
	if not (left_pressed or right_pressed):
		keys_released = true


func _spawn_particles(context: Dictionary, fps_scale: float) -> void:
	var ball_center: Vector2 = _get_ball_center(context)
	var player_center: Vector2 = _get_player_center(context)
	var spawn_count: int = 1
	if randf() < 0.32 * clamp(fps_scale, 0.25, 1.5):
		spawn_count += 1
	for _i in range(spawn_count):
		var angle: float = randf_range(0.0, TAU)
		var spawn_dist: float = randf_range(14.0, 32.0)
		var spawn_pos: Vector2 = ball_center + Vector2(cos(angle), sin(angle)) * spawn_dist
		particles.append({
			"pos": spawn_pos,
			"target": player_center,
			"life": 0.0,
			"max_life": float(randi_range(14, 24)),
			"size": randf_range(1.5, 3.5),
			"phase": randf_range(0.0, TAU),
			"curve": randf_range(-0.35, 0.35),
		})
	if particles.size() > PARTICLE_CAP:
		while particles.size() > PARTICLE_CAP:
			particles.pop_front()


func _update_particles(context: Dictionary, fps_scale: float) -> void:
	var player_center: Vector2 = _get_player_center(context)
	var write_index := 0
	for read_index in range(particles.size()):
		var particle: Dictionary = particles[read_index]
		var life: float = float(particle.get("life", 0.0)) + fps_scale
		var max_life: float = max(1.0, float(particle.get("max_life", 1.0)))
		if life >= max_life:
			continue
		var pos: Vector2 = _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO)
		var delta: Vector2 = player_center - pos
		var dist: float = delta.length()
		if dist < 6.0:
			continue
		var dir: Vector2 = delta / dist
		var perp := Vector2(-dir.y, dir.x)
		var accel: float = (1.8 + (1.0 - min(dist / 400.0, 1.0)) * 2.2) * fps_scale
		var curve_strength: float = float(particle.get("curve", 0.0)) * (1.0 - life / max_life)
		particle["pos"] = pos + dir * accel + perp * curve_strength * fps_scale
		particle["target"] = player_center
		particle["life"] = life
		particles[write_index] = particle
		write_index += 1
	if write_index < particles.size():
		particles.resize(write_index)


func _get_effective_pull_accel(ball_vel: Vector2, pull_dir: Vector2, context: Dictionary) -> float:
	var approach_speed: float = ball_vel.dot(pull_dir)
	if approach_speed <= 0.0:
		return PULL_ACCEL
	var impact_boost: float = max(1.0, float(context.get("ball_impact_boost", 1.0)))
	var reference_speed: float = max(ball_vel.length(), approach_speed * impact_boost)
	var dampen_span: float = max(0.001, HIGH_SPEED_DAMPEN_END - HIGH_SPEED_DAMPEN_START)
	var dampen_t: float = clamp((reference_speed - HIGH_SPEED_DAMPEN_START) / dampen_span, 0.0, 1.0)
	return PULL_ACCEL * lerp(1.0, MIN_PULL_ACCEL_MULT, dampen_t)


func _cap_approach_speed(velocity: Vector2, pull_dir: Vector2, distance: float, context: Dictionary) -> Vector2:
	var approach_speed: float = velocity.dot(pull_dir)
	if approach_speed <= 0.0:
		return velocity
	var approach_cap: float = _get_approach_speed_cap(distance, context)
	if approach_speed <= approach_cap:
		return velocity
	return velocity - pull_dir * (approach_speed - approach_cap)


func _steer_velocity_toward_paddle(velocity: Vector2, pull_dir: Vector2, distance: float, fps_scale: float) -> Vector2:
	var approach_velocity: Vector2 = pull_dir * velocity.dot(pull_dir)
	var side_velocity: Vector2 = velocity - approach_velocity
	if side_velocity.length_squared() <= 0.0001:
		return velocity
	var near_t: float = 1.0 - clamp(distance / NEAR_APPROACH_DISTANCE, 0.0, 1.0)
	var dampen: float = clamp((PADDLE_HOMING_SIDE_DAMPEN + PADDLE_HOMING_NEAR_BONUS * near_t) * fps_scale, 0.0, 0.55)
	return velocity - side_velocity * dampen


func _get_approach_speed_cap(distance: float, context: Dictionary) -> float:
	var near_t: float = 1.0 - clamp(distance / NEAR_APPROACH_DISTANCE, 0.0, 1.0)
	var safe_cap: float = lerp(APPROACH_SPEED_FAR_CAP, APPROACH_SPEED_NEAR_CAP, near_t)
	var impact_boost: float = max(1.0, float(context.get("ball_impact_boost", 1.0)))
	return max(MIN_APPROACH_SPEED_CAP, safe_cap / impact_boost)


func _player_intersects_ball(context: Dictionary) -> bool:
	var ball_size: float = float(context.get("ball_size", 28.6))
	var ball_center: Vector2 = _get_ball_center(context)
	var ball_rect := Rect2(ball_center - Vector2(ball_size, ball_size) * 0.5, Vector2(ball_size, ball_size))
	var player_pos: Vector2 = _get_vector2(context, "player_pos", Vector2.ZERO)
	var player_size: Vector2 = _get_vector2(context, "player_paddle_size", Vector2(155.0, 50.0))
	var player_rect := Rect2(player_pos, player_size)
	return player_rect.intersects(ball_rect)


func _get_cooldown_remaining(deps: Dictionary, current_msec: int) -> float:
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state == null or not skill_state.has_method("get_configured_cooldown_remaining"):
		return 0.0
	return float(skill_state.get_configured_cooldown_remaining(SKILL_NAME, current_msec, deps.get("skill_config", null)))


func _get_skill_cost(skill_config: Object) -> float:
	if skill_config != null and skill_config.has_method("get_skill_cost"):
		return float(skill_config.get_skill_cost(SKILL_NAME))
	if skill_config != null and skill_config.has_method("get_snapshot"):
		var snapshot: Variant = skill_config.get_snapshot()
		if snapshot is Dictionary:
			var costs: Variant = snapshot.get("skill_costs", {})
			if costs is Dictionary:
				return float(costs.get(SKILL_NAME, GAUGE_COST))
	return GAUGE_COST


func _is_skill_equipped(skill_config: Object) -> bool:
	if skill_config != null and skill_config.has_method("is_skill_equipped"):
		return bool(skill_config.is_skill_equipped(SKILL_NAME))
	if skill_config != null and skill_config.has_method("get_snapshot"):
		var snapshot: Variant = skill_config.get_snapshot()
		if snapshot is Dictionary:
			var equipped: Variant = snapshot.get("equipped_skills", [])
			if equipped is Array:
				return equipped.has(SKILL_NAME)
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


func _get_ball_center(context: Dictionary) -> Vector2:
	return _get_vector2(context, "ball_pos", Vector2.ZERO)


func _get_player_center(context: Dictionary) -> Vector2:
	var pos: Vector2 = _get_vector2(context, "player_pos", Vector2.ZERO)
	var size: Vector2 = _get_vector2(context, "player_paddle_size", Vector2(155.0, 50.0))
	return pos + size * 0.5


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return _as_vector2(source.get(key, fallback), fallback)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
