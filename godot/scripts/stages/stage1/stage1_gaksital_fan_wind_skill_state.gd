extends RefCounted

const BallContextReader := preload("res://scripts/ball/ball_context_reader.gd")

const STAGE_ID := 1
const BOSS_VARIANT := "gaksi"
const CHARGE_FRAMES := 60.0
const DURATION_FRAMES := 240.0
const SPAWN_X_JITTER := 30.0
const SPAWN_Y_OFFSET := 10.0
const DESCENT_PER_FRAME := 0.6
const DRIFT_INIT_MAX := 1.2
const DRIFT_REROLL_MAX := 1.5
const DRIFT_REROLL_MIN_FRAMES := 25.0
const DRIFT_REROLL_MAX_FRAMES := 55.0
const ROAM_LEFT := 110.0
const ROAM_RIGHT := 650.0
const CAPTURE_RADIUS := 42.0
const CAPTURE_DURATION_FRAMES := 60.0
const ORBIT_SHRINK := 0.96
const ORBIT_GROW := 1.06
const ORBIT_MIN := 3.0
const ORBIT_MAX := 55.0
const SPIN_BASE := 0.25
const SPIN_GAIN := 0.35
const RELEASE_SPEED_MIN := 12.0
const RELEASE_SPEED_MAX := 16.0
const EXPIRE_RELEASE_SPEED := 13.0
const FAILSAFE_Y := 720.0

var charging := false
var active := false
var captured := false
var charge_timer := 0.0
var timer_frames := 0.0
var vortex_pos := Vector2.ZERO
var drift_vx := 0.0
var drift_reroll_timer := 0.0
var capture_timer := 0.0
var capture_radius := 0.0
var capture_angle := 0.0
var spin_phase := 0.0
var growth_scale := 0.0
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()
	reset()


func reset() -> void:
	reset_round()


func reset_round() -> void:
	charging = false
	active = false
	captured = false
	charge_timer = 0.0
	timer_frames = 0.0
	vortex_pos = Vector2.ZERO
	drift_vx = 0.0
	drift_reroll_timer = 0.0
	capture_timer = 0.0
	capture_radius = 0.0
	capture_angle = 0.0
	spin_phase = 0.0
	growth_scale = 0.0


func can_activate(context: Dictionary = {}) -> bool:
	return (
		int(context.get("current_stage", STAGE_ID)) == STAGE_ID
		and _is_gaksital_context(context)
		and not charging
		and not active
		and not captured
	)


func try_consume_boss_hit(context: Dictionary, deps: Dictionary = {}) -> bool:
	if not can_activate(context):
		return false
	var cooldown_state: Object = deps.get("stage1_gaksital_boss_skill_cooldown_state", null)
	if cooldown_state == null or not cooldown_state.has_method("consume_on_hit"):
		return false
	if not bool(cooldown_state.consume_on_hit("fan_wind", context, deps)):
		return false
	_start_charge(context, deps)
	return true


func update_and_collide(fps_scale: float, scene: Dictionary, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID or not _is_gaksital_context(context):
		var teardown_result := _build_expire_release_result() if captured else {}
		reset_round()
		return teardown_result

	if not is_active():
		return {}

	if charging:
		_update_charge(fps_scale)
		return {}

	_update_active_vortex(fps_scale)
	if _is_expired():
		var expired_result := _build_expire_release_result() if captured else {}
		reset_round()
		return expired_result

	if not captured:
		# If another owner already holds the ball, this hazard keeps drifting but
		# never steals ownership from that skill's release contract.
		if bool(scene.get("skip_ball_motion_step", false)):
			return {}
		_try_capture_ball(scene, context)

	if captured:
		return _update_capture(fps_scale)
	return {}


func notify_absorbed_by_chaos_spear(_context: Dictionary = {}, _deps: Dictionary = {}) -> Dictionary:
	if not is_active():
		return {}
	var result := _build_expire_release_result() if captured else {}
	reset_round()
	return result


func absorb_chaos_spear_objects(center: Vector2, pull_radius: float, _deps: Dictionary = {}) -> Array:
	# Chaos Spear object-absorb protocol (Python L6260 parity: the blackhole
	# eats a charging/active fan-wind vortex and pays object gold).
	if not is_active():
		return []
	# A vortex that currently OWNS the ball is skipped this poll: the absorb
	# poll runs inside the chaos apply on the ball path BEFORE this skill's
	# own tick, so there is no consumer at that point to apply the captured
	# ball's release dict. The vortex gets absorbed on a later poll after it
	# releases naturally.
	if captured:
		return []
	if vortex_pos.distance_to(center) > pull_radius:
		return []
	var entry := {
		"position": vortex_pos,
		"strength": 1.15,
		"color": Color(0.46, 0.78, 1.0, 1.0),
	}
	reset_round()
	return [entry]


func get_draw_context() -> Dictionary:
	return {
		"stage1_fan_wind_visible": is_active(),
		"stage1_fan_wind_charging": charging,
		"stage1_fan_wind_active": active,
		"stage1_fan_wind_captured": captured,
		"stage1_fan_wind_pos": vortex_pos,
		"stage1_fan_wind_growth_scale": growth_scale,
		"stage1_fan_wind_capture_radius": capture_radius,
		"stage1_fan_wind_capture_angle": capture_angle,
		"stage1_fan_wind_spin_phase": spin_phase,
		"stage1_fan_wind_charge_progress": clamp(1.0 - charge_timer / CHARGE_FRAMES, 0.0, 1.0),
		"stage1_fan_wind_timer_ratio": clamp(timer_frames / DURATION_FRAMES, 0.0, 1.0),
	}


func is_active() -> bool:
	return charging or active or captured


func is_ball_captured() -> bool:
	return captured


func _start_charge(context: Dictionary, deps: Dictionary) -> void:
	var boss_pos: Vector2 = _get_vector2(context, "boss_pos", Vector2.ZERO)
	var boss_size: Vector2 = _get_vector2(context, "boss_paddle_size", Vector2(100.0, 40.0))
	var boss_height: float = max(1.0, float(context.get("boss_hitbox_height", boss_size.y)))
	vortex_pos = Vector2(
		boss_pos.x + boss_size.x * 0.5 + rng.randf_range(-SPAWN_X_JITTER, SPAWN_X_JITTER),
		boss_pos.y + boss_height + SPAWN_Y_OFFSET
	)
	charging = true
	active = false
	captured = false
	charge_timer = CHARGE_FRAMES
	timer_frames = DURATION_FRAMES
	growth_scale = 0.0
	spin_phase = 0.0
	capture_timer = 0.0
	capture_radius = 0.0
	capture_angle = 0.0
	drift_vx = _random_signed(DRIFT_INIT_MAX)
	drift_reroll_timer = rng.randf_range(DRIFT_REROLL_MIN_FRAMES, DRIFT_REROLL_MAX_FRAMES)
	_play_fan_audio(deps, 0.35)


func _update_charge(fps_scale: float) -> void:
	charge_timer = max(0.0, charge_timer - fps_scale)
	growth_scale = clamp(1.0 - charge_timer / CHARGE_FRAMES, 0.0, 1.0)
	spin_phase += SPIN_BASE * 0.55 * fps_scale
	if charge_timer > 0.0:
		return
	charging = false
	active = true
	timer_frames = DURATION_FRAMES
	growth_scale = 1.0


func _update_active_vortex(fps_scale: float) -> void:
	timer_frames = max(0.0, timer_frames - fps_scale)
	vortex_pos.y += DESCENT_PER_FRAME * fps_scale
	vortex_pos.x += drift_vx * fps_scale
	if vortex_pos.x <= ROAM_LEFT:
		vortex_pos.x = ROAM_LEFT
		drift_vx = abs(drift_vx)
	elif vortex_pos.x >= ROAM_RIGHT:
		vortex_pos.x = ROAM_RIGHT
		drift_vx = -abs(drift_vx)

	drift_reroll_timer -= fps_scale
	if drift_reroll_timer <= 0.0:
		drift_vx = _random_signed(DRIFT_REROLL_MAX)
		drift_reroll_timer = rng.randf_range(DRIFT_REROLL_MIN_FRAMES, DRIFT_REROLL_MAX_FRAMES)
	spin_phase += (SPIN_BASE + (1.0 - timer_frames / DURATION_FRAMES) * 0.18) * fps_scale


func _is_expired() -> bool:
	return timer_frames <= 0.0 or vortex_pos.y > FAILSAFE_Y


func _try_capture_ball(scene: Dictionary, context: Dictionary) -> void:
	var ball_pos: Vector2 = _get_vector2(scene, "ball_pos", _get_vector2(context, "ball_pos", Vector2.ZERO))
	var distance: float = ball_pos.distance_to(vortex_pos)
	if distance >= CAPTURE_RADIUS:
		return
	captured = true
	capture_timer = CAPTURE_DURATION_FRAMES
	capture_radius = max(distance, 8.0)
	capture_angle = atan2(ball_pos.y - vortex_pos.y, ball_pos.x - vortex_pos.x)
	scene["stage1_gaksital_fan_wind_captured"] = true


func _update_capture(fps_scale: float) -> Dictionary:
	capture_timer = max(0.0, capture_timer - fps_scale)
	var progress: float = clamp(1.0 - capture_timer / CAPTURE_DURATION_FRAMES, 0.0, 1.0)
	if progress < 0.6:
		capture_radius = max(ORBIT_MIN, capture_radius * pow(ORBIT_SHRINK, fps_scale))
	else:
		capture_radius = min(ORBIT_MAX, capture_radius * pow(ORBIT_GROW, fps_scale))
	capture_angle += (SPIN_BASE + progress * SPIN_GAIN) * fps_scale
	var orbit_pos := vortex_pos + Vector2(cos(capture_angle), sin(capture_angle)) * capture_radius
	if capture_timer <= 0.0:
		var release_result := _build_release_result(orbit_pos)
		reset_round()
		return release_result
	return {
		"skip_ball_motion_step": true,
		"ball_pos": orbit_pos,
		"ball_vel": Vector2.ZERO,
		"stage1_gaksital_fan_wind_captured": true,
	}


func _build_release_result(ball_pos: Vector2) -> Dictionary:
	return {
		"skip_ball_motion_step": false,
		"ball_pos": ball_pos,
		"ball_vel": _random_downward_velocity(RELEASE_SPEED_MIN, RELEASE_SPEED_MAX),
		"stage1_gaksital_fan_wind_released": true,
		"stage1_gaksital_fan_wind_captured": false,
	}


func _build_expire_release_result() -> Dictionary:
	var ball_pos: Vector2 = vortex_pos + Vector2(cos(capture_angle), sin(capture_angle)) * max(capture_radius, ORBIT_MIN)
	return {
		"skip_ball_motion_step": false,
		"ball_pos": ball_pos,
		"ball_vel": _expire_downward_velocity(),
		"stage1_gaksital_fan_wind_expired_release": true,
		"stage1_gaksital_fan_wind_captured": false,
	}


func _random_downward_velocity(min_speed: float, max_speed: float) -> Vector2:
	var speed: float = rng.randf_range(min_speed, max_speed)
	var angle: float = rng.randf_range(0.0, TAU)
	var velocity := Vector2(cos(angle) * speed, abs(sin(angle)) * speed)
	if velocity.y <= 0.001:
		velocity.y = speed * 0.35
	return velocity


func _expire_downward_velocity() -> Vector2:
	var angle: float = rng.randf_range(-0.8 * PI, -0.2 * PI)
	return Vector2(cos(angle) * EXPIRE_RELEASE_SPEED, abs(sin(angle)) * EXPIRE_RELEASE_SPEED)


func _random_signed(max_abs: float) -> float:
	var value: float = rng.randf_range(0.35, max_abs)
	return -value if rng.randf() < 0.5 else value


func _play_fan_audio(deps: Dictionary, volume: float) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_gaksital_fan"):
		audio.play_gaksital_fan(volume)


func _is_gaksital_context(context: Dictionary) -> bool:
	var variant: String = str(context.get("stage1_boss_variant", "dalji")).strip_edges().to_lower()
	return variant in [BOSS_VARIANT, "gaksital", "talkwangdae", "talchum"]


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BallContextReader.get_vector2(source, key, fallback)
