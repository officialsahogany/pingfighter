extends RefCounted

const STAGE_ID := 1
const BOSS_GAUGE_MAX := 500.0
const BOSS_GAUGE_GAIN_ON_HIT := 50.0
const WHIP_GAUGE_COST := 200.0
const WHIP_ACTIVATION_CHANCE := 0.12
const WHIP_DURATION_FRAMES := 260.0
const WHIP_WAVE_SPEED := 0.30
const WHIP_WAVE_AMPLITUDE := 15.0
const WHIP_ACTIVE_ROTATION_DEG_PER_FRAME := 15.0
const WHIP_DEACTIVATION_DURATION_FRAMES := 90.0
const WHIP_DEACTIVATION_ROTATION_SPEED := 20.0
const WHIP_DEACTIVATION_START_SPEED_MULT := 0.5
const WHIP_DEACTIVATION_END_SPEED_MULT := 0.2
const WHIP_POST_STUN_FRAMES := 30.0
const WHIP_FRAME_COUNT := 8
const MIN_DOWNWARD_SPEED_ON_CAST := 8.0
const MIN_ACTIVE_DOWNWARD_SPEED := 5.0
const MIN_COUNTER_UPWARD_SPEED := 8.0

var boss_special_gauge := 0.0
var active := false
var timer_frames := 0.0
var wave_phase := 0.0
var hit_by_player := false
var original_ball_y_speed := 0.0
var visual_angle_degrees := 0.0
var deactivation_active := false
var deactivation_timer_frames := 0.0
var deactivation_rotation_speed := 0.0
var post_stun_timer_frames := 0.0
var whip_audio: Object = null


func reset() -> void:
	boss_special_gauge = 0.0
	reset_round()


func reset_round() -> void:
	_stop_whip_sound()
	active = false
	timer_frames = 0.0
	wave_phase = 0.0
	hit_by_player = false
	original_ball_y_speed = 0.0
	visual_angle_degrees = 0.0
	deactivation_active = false
	deactivation_timer_frames = 0.0
	deactivation_rotation_speed = 0.0
	post_stun_timer_frames = 0.0
	whip_audio = null


func register_boss_hit(ball_vel: Vector2, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID:
		return {}

	boss_special_gauge = min(boss_special_gauge + BOSS_GAUGE_GAIN_ON_HIT, BOSS_GAUGE_MAX)
	var next_ball_vel: Vector2 = ball_vel
	var activated := false
	if _can_activate():
		if randf() <= WHIP_ACTIVATION_CHANCE:
			next_ball_vel = _activate(next_ball_vel, deps)
			activated = true
	return {
		"ball_vel": next_ball_vel,
		"boss_special_gauge": boss_special_gauge,
		"whip_activated": activated,
	}


func register_player_hit(ball_vel: Vector2, context: Dictionary) -> Dictionary:
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID or not active:
		return {}

	hit_by_player = true
	var next_ball_vel: Vector2 = ball_vel
	if next_ball_vel.y > 0.0:
		next_ball_vel.y = -abs(next_ball_vel.y)
	if abs(next_ball_vel.y) < MIN_COUNTER_UPWARD_SPEED:
		next_ball_vel.y = -MIN_COUNTER_UPWARD_SPEED
	_start_deactivation()
	return {
		"ball_vel": next_ball_vel,
		"whip_deactivated": true,
	}


func update_ball_motion(
	fps_scale: float,
	ball_vel: Vector2,
	context: Dictionary,
	power_motion_locked: bool = false
) -> Dictionary:
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID:
		reset_round()
		return {}

	_update_post_stun(fps_scale)
	_update_deactivation(fps_scale)
	if not active:
		return {}

	timer_frames = max(0.0, timer_frames - fps_scale)
	if timer_frames <= 0.0:
		_start_deactivation()
		return {"ball_vel": ball_vel}

	var old_wave_phase: float = wave_phase
	wave_phase += WHIP_WAVE_SPEED * fps_scale
	if int(old_wave_phase / TAU) < int(wave_phase / TAU):
		_play_whip_sound()
	visual_angle_degrees = fposmod(
		visual_angle_degrees + WHIP_ACTIVE_ROTATION_DEG_PER_FRAME * fps_scale,
		360.0
	)

	var next_ball_vel: Vector2 = ball_vel
	if not power_motion_locked:
		next_ball_vel.x = sin(wave_phase) * WHIP_WAVE_AMPLITUDE
		if not hit_by_player:
			if next_ball_vel.y < 0.0:
				next_ball_vel.y = abs(original_ball_y_speed) if original_ball_y_speed != 0.0 else 10.0
			if abs(next_ball_vel.y) < MIN_ACTIVE_DOWNWARD_SPEED:
				next_ball_vel.y = MIN_ACTIVE_DOWNWARD_SPEED
		else:
			if next_ball_vel.y > 0.0:
				next_ball_vel.y = -abs(next_ball_vel.y)
			if abs(next_ball_vel.y) < MIN_COUNTER_UPWARD_SPEED:
				next_ball_vel.y = -MIN_COUNTER_UPWARD_SPEED
	return {"ball_vel": next_ball_vel}


func get_ai_context() -> Dictionary:
	return {
		"stage1_dalji_whip_active": active,
		"stage1_dalji_whip_deactivation_active": deactivation_active,
		"stage1_dalji_whip_deactivation_speed_multiplier": get_deactivation_speed_multiplier(),
		"stage1_dalji_whip_post_stun_active": post_stun_timer_frames > 0.0,
	}


func get_draw_context() -> Dictionary:
	return {
		"boss_whip_active": active,
		"boss_whip_deactivation_active": deactivation_active,
		"boss_whip_post_stun_active": post_stun_timer_frames > 0.0,
		"boss_whip_frame": get_whip_frame_index(),
		"boss_whip_post_stun_frame": get_post_stun_frame_index(),
		"boss_whip_bob_offset": get_post_stun_bob_offset(),
	}


func get_whip_frame_index() -> int:
	var step: float = 360.0 / float(WHIP_FRAME_COUNT)
	return int(fposmod(visual_angle_degrees, 360.0) / step + 0.5) % WHIP_FRAME_COUNT


func get_post_stun_bob_offset() -> float:
	if post_stun_timer_frames <= 0.0:
		return 0.0
	var elapsed: float = WHIP_POST_STUN_FRAMES - post_stun_timer_frames
	var progress: float = clamp(elapsed / WHIP_POST_STUN_FRAMES, 0.0, 1.0)
	return sin(progress * PI * 4.0) * 6.0 * (1.0 - 0.4 * progress)


func get_post_stun_frame_index() -> int:
	if post_stun_timer_frames <= 0.0:
		return 0
	var elapsed: float = WHIP_POST_STUN_FRAMES - post_stun_timer_frames
	var progress: float = clamp(elapsed / WHIP_POST_STUN_FRAMES, 0.0, 0.999)
	return int(progress * float(WHIP_FRAME_COUNT))


func get_deactivation_progress() -> float:
	if not deactivation_active:
		return 0.0
	return clamp(1.0 - (deactivation_timer_frames / WHIP_DEACTIVATION_DURATION_FRAMES), 0.0, 1.0)


func get_deactivation_speed_multiplier() -> float:
	if not deactivation_active:
		return 1.0
	return lerp(WHIP_DEACTIVATION_START_SPEED_MULT, WHIP_DEACTIVATION_END_SPEED_MULT, get_deactivation_progress())


func is_movement_locked() -> bool:
	return deactivation_active or post_stun_timer_frames > 0.0


func get_boss_special_gauge() -> float:
	return boss_special_gauge


func _can_activate() -> bool:
	return (
		boss_special_gauge >= WHIP_GAUGE_COST
		and not active
		and not deactivation_active
		and post_stun_timer_frames <= 0.0
	)


func _activate(ball_vel: Vector2, deps: Dictionary) -> Vector2:
	boss_special_gauge = max(0.0, boss_special_gauge - WHIP_GAUGE_COST)
	active = true
	timer_frames = WHIP_DURATION_FRAMES
	wave_phase = 0.0
	hit_by_player = false
	original_ball_y_speed = ball_vel.y
	deactivation_active = false
	deactivation_timer_frames = 0.0
	deactivation_rotation_speed = 0.0
	post_stun_timer_frames = 0.0
	whip_audio = deps.get("audio", null)

	var next_ball_vel := Vector2(0.0, abs(ball_vel.y) * 0.75)
	if next_ball_vel.y < MIN_DOWNWARD_SPEED_ON_CAST:
		next_ball_vel.y = MIN_DOWNWARD_SPEED_ON_CAST

	_play_whip_sound()
	return next_ball_vel


func _start_deactivation() -> void:
	active = false
	timer_frames = 0.0
	_stop_whip_sound()
	if deactivation_active or post_stun_timer_frames > 0.0:
		return
	deactivation_active = true
	deactivation_timer_frames = WHIP_DEACTIVATION_DURATION_FRAMES
	deactivation_rotation_speed = max(deactivation_rotation_speed, WHIP_DEACTIVATION_ROTATION_SPEED)


func _update_deactivation(fps_scale: float) -> void:
	if not deactivation_active:
		return
	if deactivation_timer_frames > 0.0:
		deactivation_timer_frames = max(0.0, deactivation_timer_frames - fps_scale)
		var progress: float = 1.0 - (deactivation_timer_frames / WHIP_DEACTIVATION_DURATION_FRAMES)
		var eased_progress: float = 1.0 - pow(1.0 - clamp(progress, 0.0, 1.0), 3.0)
		deactivation_rotation_speed = (1.0 - eased_progress) * WHIP_DEACTIVATION_ROTATION_SPEED
		visual_angle_degrees = fposmod(
			visual_angle_degrees + max(0.0, deactivation_rotation_speed) * fps_scale,
			360.0
		)
		return

	deactivation_active = false
	deactivation_rotation_speed = 0.0
	post_stun_timer_frames = WHIP_POST_STUN_FRAMES


func _update_post_stun(fps_scale: float) -> void:
	if post_stun_timer_frames > 0.0:
		post_stun_timer_frames = max(0.0, post_stun_timer_frames - fps_scale)


func _play_whip_sound() -> void:
	if whip_audio != null and whip_audio.has_method("play_whip"):
		whip_audio.play_whip()


func _stop_whip_sound() -> void:
	if whip_audio != null and whip_audio.has_method("stop_whip"):
		whip_audio.stop_whip()
