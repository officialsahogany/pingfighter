extends RefCounted

const SHADOW_STEP := "shadow_step"
const MARSHAL_KICK := "marshal_kick"
const SHADOW_STEP_DASH_GRACE_FRAMES := 36.0
const SHADOW_STEP_READY_FRAMES := 60.0
const MARSHAL_KICK_READY_FRAMES := 90.0
const MARSHAL_KICK_JUMP_FRAMES := 24.72
const MARSHAL_KICK_CLING_FRAMES := 15.0
const MARSHAL_KICK_CHARGE_FRAMES := 23.4
const MARSHAL_KICK_RECLIMB_FRAMES := 10.8
const MARSHAL_KICK_RETURN_FRAMES := 21.0
const MARSHAL_KICK_HIT_RADIUS := 90.0
const MARSHAL_KICK_RECLIMB_THRESHOLD := 120.0
const MARSHAL_KICK_WALL_INSET := 15.0
const MARSHAL_KICK_SPEED_MULT := 2.2
const MARSHAL_KICK_MIN_SPEED := 11.0

var previous_down_pressed := false
var previous_dash_active := false
var previous_dash_recovering := false
var dash_origin_pos := Vector2.ZERO
var dash_origin_valid := false
var dash_grace_frames := 0.0
var shadow_step_ready_frames := 0.0
var shadow_step_activation_msec := -100000
var marshal_ready := false
var marshal_ready_frames := 0.0
var marshal_active := false
var marshal_phase := 0
var marshal_phase_frames := 0.0
var marshal_start_pos := Vector2.ZERO
var marshal_wall_pos := Vector2.ZERO
var marshal_reclimb_start_pos := Vector2.ZERO
var marshal_charge_start_pos := Vector2.ZERO
var marshal_return_start_pos := Vector2.ZERO
var marshal_ball_hit := false
var marshal_activation_msec := -100000
var marshal_hit_msec := -100000
var marshal_last_hit_pos := Vector2.ZERO


func reset() -> void:
	reset_round()


func reset_round() -> void:
	previous_down_pressed = false
	previous_dash_active = false
	previous_dash_recovering = false
	dash_origin_pos = Vector2.ZERO
	dash_origin_valid = false
	dash_grace_frames = 0.0
	shadow_step_ready_frames = 0.0
	shadow_step_activation_msec = -100000
	marshal_ready = false
	marshal_ready_frames = 0.0
	_reset_marshal_runtime_fields()


func open_marshal_kick_window() -> void:
	if marshal_active:
		return
	marshal_ready = true
	marshal_ready_frames = MARSHAL_KICK_READY_FRAMES


func try_activate_before_movement(
	delta: float,
	player_pos: Vector2,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var input_reader: Object = deps.get("input_reader", null)
	var input_snapshot: Dictionary = input_reader.get_snapshot() if input_reader != null else {}
	var down_pressed: bool = bool(input_snapshot.get("down_pressed", false))
	var pressed_edge: bool = down_pressed and not previous_down_pressed
	previous_down_pressed = down_pressed

	shadow_step_ready_frames = max(0.0, shadow_step_ready_frames - delta * 60.0)
	_update_marshal_ready_timer(delta)
	if marshal_active:
		return _update_marshal_kick(delta, player_pos, special_gauge, config, deps)
	if pressed_edge and _can_marshal_kick(special_gauge, input_snapshot, deps):
		return _start_marshal_kick(player_pos, special_gauge, config, deps)
	if not pressed_edge or not _can_shadow_step(special_gauge, deps):
		return {"handled": false, "activated": false, "special_gauge": special_gauge}

	var target_pos: Vector2 = _clamp_player_pos(
		dash_origin_pos,
		float(config.get("play_left", 0.0)),
		float(config.get("play_right", 760.0)),
		float(config.get("paddle_width", 155.0))
	)
	var next_gauge: float = max(0.0, special_gauge - _get_skill_cost(deps.get("skill_config", null), SHADOW_STEP))
	var now_msec: int = Time.get_ticks_msec()
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state != null and skill_state.has_method("trigger_configured_cooldown"):
		skill_state.trigger_configured_cooldown(SHADOW_STEP, now_msec, deps.get("skill_config", null))
	var orb_hud_state: Object = deps.get("orb_hud_state", null)
	if orb_hud_state != null and orb_hud_state.has_method("trigger_gauge_spin"):
		orb_hud_state.trigger_gauge_spin(now_msec)
	var feedback: Object = deps.get("feedback", null)
	if feedback != null and feedback.has_method("set_screen_shake"):
		feedback.set_screen_shake(0.10, 5.0)
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_dash_start"):
		audio.play_dash_start(true)
	_cancel_dash_until_key_release(deps.get("dash_state", null))

	dash_origin_valid = false
	dash_grace_frames = 0.0
	previous_dash_active = false
	previous_dash_recovering = false
	shadow_step_ready_frames = SHADOW_STEP_READY_FRAMES
	shadow_step_activation_msec = now_msec
	return {
		"handled": true,
		"activated": true,
		"player_pos": target_pos,
		"player_speed": 0.0,
		"special_gauge": next_gauge,
		"skill_name": SHADOW_STEP,
	}


func observe_after_movement(delta: float, before_player_pos: Vector2, _after_player_pos: Vector2, deps: Dictionary) -> void:
	var dash_snapshot: Dictionary = _get_dash_snapshot(deps.get("dash_state", null))
	var dash_active: bool = bool(dash_snapshot.get("active", false))
	var dash_recovering: bool = bool(dash_snapshot.get("recovering", false))
	if dash_active and not previous_dash_active:
		dash_origin_pos = before_player_pos
		dash_origin_valid = true
	if dash_active or dash_recovering:
		dash_grace_frames = SHADOW_STEP_DASH_GRACE_FRAMES
	else:
		dash_grace_frames = max(0.0, dash_grace_frames - delta * 60.0)
		if dash_grace_frames <= 0.0:
			dash_origin_valid = false
	previous_dash_active = dash_active
	previous_dash_recovering = dash_recovering


func get_snapshot() -> Dictionary:
	return {
		"dash_origin_valid": dash_origin_valid,
		"dash_origin_pos": dash_origin_pos,
		"dash_grace_frames": dash_grace_frames,
		"shadow_step_ready_frames": shadow_step_ready_frames,
		"shadow_step_activation_msec": shadow_step_activation_msec,
		"dash_active": previous_dash_active,
		"dash_recovering": previous_dash_recovering,
		"marshal_ready": marshal_ready,
		"marshal_ready_frames": marshal_ready_frames,
		"marshal_active": marshal_active,
		"marshal_phase": marshal_phase,
		"marshal_phase_frames": marshal_phase_frames,
		"marshal_ball_hit": marshal_ball_hit,
		"marshal_activation_msec": marshal_activation_msec,
		"marshal_hit_msec": marshal_hit_msec,
		"marshal_last_hit_pos": marshal_last_hit_pos,
	}


func _update_marshal_ready_timer(delta: float) -> void:
	if not marshal_ready:
		return
	marshal_ready_frames = max(0.0, marshal_ready_frames - delta * 60.0)
	if marshal_ready_frames <= 0.0:
		marshal_ready = false


func _can_marshal_kick(special_gauge: float, input_snapshot: Dictionary, deps: Dictionary) -> bool:
	if not marshal_ready or marshal_ready_frames <= 0.0:
		return false
	if _is_control_locked(deps):
		return false
	if bool(input_snapshot.get("left_pressed", false)) or bool(input_snapshot.get("right_pressed", false)):
		return false
	if abs(float(input_snapshot.get("direction", 0.0))) > 0.01:
		return false
	var skill_config: Object = deps.get("skill_config", null)
	if not _is_skill_equipped(skill_config, MARSHAL_KICK):
		return false
	if special_gauge < _get_skill_cost(skill_config, MARSHAL_KICK):
		return false
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state != null and skill_state.has_method("get_configured_cooldown_remaining"):
		return skill_state.get_configured_cooldown_remaining(
			MARSHAL_KICK,
			Time.get_ticks_msec(),
			skill_config
		) <= 0.0
	return true


func _start_marshal_kick(player_pos: Vector2, special_gauge: float, config: Dictionary, deps: Dictionary) -> Dictionary:
	var now_msec: int = Time.get_ticks_msec()
	var skill_config: Object = deps.get("skill_config", null)
	var next_gauge: float = max(0.0, special_gauge - _get_skill_cost(skill_config, MARSHAL_KICK))
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state != null and skill_state.has_method("trigger_configured_cooldown"):
		skill_state.trigger_configured_cooldown(MARSHAL_KICK, now_msec, skill_config)
	var orb_hud_state: Object = deps.get("orb_hud_state", null)
	if orb_hud_state != null and orb_hud_state.has_method("trigger_gauge_spin"):
		orb_hud_state.trigger_gauge_spin(now_msec)
	var feedback: Object = deps.get("feedback", null)
	if feedback != null and feedback.has_method("set_screen_shake"):
		feedback.set_screen_shake(0.12, 4.0)
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_dash_start"):
		audio.play_dash_start(true)

	marshal_ready = false
	marshal_ready_frames = 0.0
	marshal_active = true
	marshal_phase = 0
	marshal_phase_frames = 0.0
	marshal_start_pos = player_pos
	marshal_wall_pos = _compute_marshal_wall_pos(player_pos, config)
	marshal_reclimb_start_pos = Vector2.ZERO
	marshal_charge_start_pos = Vector2.ZERO
	marshal_return_start_pos = Vector2.ZERO
	marshal_ball_hit = false
	marshal_activation_msec = now_msec
	marshal_hit_msec = -100000
	marshal_last_hit_pos = Vector2.ZERO
	return {
		"handled": true,
		"activated": true,
		"skill_name": MARSHAL_KICK,
		"player_pos": player_pos,
		"player_speed": 0.0,
		"special_gauge": next_gauge,
	}


func _update_marshal_kick(
	delta: float,
	player_pos: Vector2,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var fps_scale: float = delta * 60.0
	marshal_phase_frames += fps_scale
	var next_pos: Vector2 = player_pos
	var result := {
		"handled": true,
		"activated": false,
		"skill_name": MARSHAL_KICK,
		"player_pos": player_pos,
		"player_speed": 0.0,
		"special_gauge": special_gauge,
	}
	match marshal_phase:
		0:
			var t0: float = min(1.0, marshal_phase_frames / _get_marshal_duration_frames(MARSHAL_KICK_JUMP_FRAMES, deps))
			next_pos = marshal_start_pos.lerp(marshal_wall_pos, 1.0 - pow(1.0 - t0, 2.0))
			if t0 >= 1.0:
				_enter_marshal_phase(1, marshal_wall_pos)
				_trigger_feedback(deps, 0.08, 3.0)
		1:
			next_pos = marshal_wall_pos
			var t1: float = min(1.0, marshal_phase_frames / _get_marshal_duration_frames(MARSHAL_KICK_CLING_FRAMES, deps))
			if t1 >= 1.0:
				if abs(_get_ball_pos(config).x - _get_player_center(marshal_wall_pos, config).x) < MARSHAL_KICK_RECLIMB_THRESHOLD:
					marshal_reclimb_start_pos = marshal_wall_pos
					marshal_wall_pos = _compute_reclimb_wall_pos(config)
					_enter_marshal_phase(3, marshal_reclimb_start_pos)
				else:
					_enter_marshal_charge()
		3:
			var t3: float = min(1.0, marshal_phase_frames / _get_marshal_duration_frames(MARSHAL_KICK_RECLIMB_FRAMES, deps))
			next_pos = marshal_reclimb_start_pos.lerp(marshal_wall_pos, t3 * t3 * (3.0 - 2.0 * t3))
			if t3 >= 1.0:
				_trigger_feedback(deps, 0.06, 2.0)
				_enter_marshal_charge()
		2:
			var t2: float = min(1.0, marshal_phase_frames / _get_marshal_duration_frames(MARSHAL_KICK_CHARGE_FRAMES, deps))
			var target_pos: Vector2 = _get_ball_pos(config) - _get_paddle_size(config) * 0.5
			next_pos = marshal_charge_start_pos.lerp(target_pos, t2 * t2)
			if not marshal_ball_hit:
				var player_center: Vector2 = _get_player_center(next_pos, config)
				var ball_pos: Vector2 = _get_ball_pos(config)
				if player_center.distance_to(ball_pos) <= MARSHAL_KICK_HIT_RADIUS:
					marshal_ball_hit = true
					marshal_hit_msec = Time.get_ticks_msec()
					marshal_last_hit_pos = ball_pos
					result["ball_vel"] = _build_marshal_hit_velocity(config, deps)
					result["skill_gold_award"] = 30
					_trigger_feedback(deps, 0.20, 5.0)
					_enter_marshal_return(next_pos)
			if t2 >= 1.0 and marshal_phase == 2:
				_enter_marshal_return(next_pos)
		4:
			var t4: float = min(1.0, marshal_phase_frames / MARSHAL_KICK_RETURN_FRAMES)
			var return_target: Vector2 = _get_marshal_return_target(config)
			next_pos = marshal_return_start_pos.lerp(return_target, t4 * t4 * (3.0 - 2.0 * t4))
			if t4 >= 1.0:
				next_pos = return_target
				_reset_marshal_runtime_fields()
	result["player_pos"] = next_pos
	return result


func _enter_marshal_phase(next_phase: int, phase_pos: Vector2) -> void:
	marshal_phase = next_phase
	marshal_phase_frames = 0.0
	if next_phase == 1:
		marshal_wall_pos = phase_pos


func _enter_marshal_charge() -> void:
	marshal_phase = 2
	marshal_phase_frames = 0.0
	marshal_charge_start_pos = marshal_wall_pos


func _enter_marshal_return(return_start_pos: Vector2) -> void:
	marshal_phase = 4
	marshal_phase_frames = 0.0
	marshal_return_start_pos = return_start_pos


func _reset_marshal_runtime_fields() -> void:
	marshal_active = false
	marshal_phase = 0
	marshal_phase_frames = 0.0
	marshal_start_pos = Vector2.ZERO
	marshal_wall_pos = Vector2.ZERO
	marshal_reclimb_start_pos = Vector2.ZERO
	marshal_charge_start_pos = Vector2.ZERO
	marshal_return_start_pos = Vector2.ZERO
	marshal_ball_hit = false
	marshal_activation_msec = -100000
	marshal_hit_msec = -100000
	marshal_last_hit_pos = Vector2.ZERO


func _can_shadow_step(special_gauge: float, deps: Dictionary) -> bool:
	if not dash_origin_valid or dash_grace_frames <= 0.0:
		return false
	if _is_control_locked(deps):
		return false
	var skill_config: Object = deps.get("skill_config", null)
	if not _is_skill_equipped(skill_config, SHADOW_STEP):
		return false
	if special_gauge < _get_skill_cost(skill_config, SHADOW_STEP):
		return false
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state != null and skill_state.has_method("get_configured_cooldown_remaining"):
		return skill_state.get_configured_cooldown_remaining(
			SHADOW_STEP,
			Time.get_ticks_msec(),
			skill_config
		) <= 0.0
	return true


func _is_control_locked(deps: Dictionary) -> bool:
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime != null and active_item_runtime.has_method("is_player_control_locked"):
		return bool(active_item_runtime.is_player_control_locked())
	return false


func _is_skill_equipped(skill_config: Object, skill_name: String) -> bool:
	if skill_config != null and skill_config.has_method("is_skill_equipped"):
		return bool(skill_config.is_skill_equipped(skill_name))
	return false


func _get_skill_cost(skill_config: Object, skill_name: String) -> float:
	if skill_config != null and skill_config.has_method("get_skill_cost"):
		return float(skill_config.get_skill_cost(skill_name))
	if skill_config != null and skill_config.has_method("get_snapshot"):
		var snapshot: Variant = skill_config.get_snapshot()
		if snapshot is Dictionary:
			var costs: Variant = snapshot.get("skill_costs", {})
			if costs is Dictionary:
				return float(costs.get(skill_name, 0.0))
	return 0.0


func _get_dash_snapshot(dash_state: Object) -> Dictionary:
	if dash_state != null and dash_state.has_method("get_snapshot"):
		var snapshot: Variant = dash_state.get_snapshot()
		if snapshot is Dictionary:
			return snapshot
	return {}


func _cancel_dash_until_key_release(dash_state: Object) -> void:
	if dash_state == null:
		return
	if dash_state.has_method("cancel_until_key_release"):
		dash_state.cancel_until_key_release()
	elif dash_state.has_method("reset_round"):
		dash_state.reset_round()


func _clamp_player_pos(pos: Vector2, play_left: float, play_right: float, paddle_width: float) -> Vector2:
	var half_width: float = max(1.0, paddle_width) * 0.5
	var min_x: float = play_left + half_width
	var max_x: float = play_right - half_width
	if max_x < min_x:
		return Vector2((play_left + play_right) * 0.5, pos.y)
	return Vector2(clamp(pos.x, min_x, max_x), pos.y)


func _compute_marshal_wall_pos(player_pos: Vector2, config: Dictionary) -> Vector2:
	var width: float = float(config.get("width", config.get("play_right", 760.0)))
	var paddle_size: Vector2 = _get_paddle_size(config)
	var player_center: Vector2 = _get_player_center(player_pos, config)
	var ball_pos: Vector2 = _get_ball_pos(config)
	var wall_center_x: float = MARSHAL_KICK_WALL_INSET if ball_pos.x >= width * 0.5 else width - MARSHAL_KICK_WALL_INSET
	var ground_y: float = float(config.get("player_floor_y", 700.0)) + paddle_size.y * 0.5
	var min_y: float = 200.0
	var height_ratio: float = clamp((player_center.y - min_y) / max(1.0, ground_y - min_y), 0.0, 1.0)
	var rise: float = 50.0 + (200.0 - 50.0) * height_ratio
	var wall_center_y: float = clamp(player_center.y - rise, min_y, 650.0)
	return Vector2(wall_center_x, wall_center_y) - paddle_size * 0.5


func _compute_reclimb_wall_pos(config: Dictionary) -> Vector2:
	var width: float = float(config.get("width", config.get("play_right", 760.0)))
	var paddle_size: Vector2 = _get_paddle_size(config)
	var wall_center_x: float = width - MARSHAL_KICK_WALL_INSET if _get_player_center(marshal_wall_pos, config).x < width * 0.5 else MARSHAL_KICK_WALL_INSET
	var wall_center_y: float = clamp(_get_ball_pos(config).y - 50.0, 120.0, 650.0)
	return Vector2(wall_center_x, wall_center_y) - paddle_size * 0.5


func _get_marshal_return_target(config: Dictionary) -> Vector2:
	var paddle_size: Vector2 = _get_paddle_size(config)
	var play_left: float = float(config.get("play_left", 0.0))
	var play_right: float = float(config.get("play_right", config.get("width", 760.0)))
	var target_y: float = float(config.get("player_floor_y", float(config.get("height", 750.0)) - paddle_size.y))
	return Vector2(clamp(marshal_return_start_pos.x, play_left, play_right - paddle_size.x), target_y)


func _build_marshal_hit_velocity(config: Dictionary, deps: Dictionary) -> Vector2:
	var current_vel: Vector2 = _get_vector2(config.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	var current_speed: float = current_vel.length()
	var speed_bonus: float = 1.0 + float(_get_kick_enhance_level(deps)) * 0.04
	var ball_physics: Object = deps.get("ball_physics", null)
	var raw_multiplier: float = MARSHAL_KICK_SPEED_MULT * speed_bonus
	var multiplier: float = raw_multiplier
	if ball_physics != null and ball_physics.has_method("apply_dampened_multiplier"):
		multiplier = float(ball_physics.apply_dampened_multiplier(current_speed, raw_multiplier))
	var next_speed: float = max(current_speed * multiplier, MARSHAL_KICK_MIN_SPEED)
	var width: float = float(config.get("width", config.get("play_right", 760.0)))
	var kick_dir: int = 1 if _get_player_center(marshal_wall_pos, config).x < width * 0.5 else -1
	var angle: float = _compute_marshal_launch_angle(kick_dir, config, deps)
	var rad: float = deg_to_rad(-90.0 + angle)
	return Vector2(cos(rad), sin(rad)) * next_speed


func _compute_marshal_launch_angle(kick_dir: int, config: Dictionary, deps: Dictionary) -> float:
	var aim_level: int = _get_kick_enhance_level(deps)
	var bias: float = 0.6 + (1.0 - 0.6) * min(float(aim_level) * 0.09, 0.90)
	var ball_pos: Vector2 = _get_ball_pos(config)
	var boss_pos: Vector2 = _get_vector2(config.get("boss_pos", Vector2(float(config.get("width", 760.0)) * 0.5, 25.0)), Vector2.ZERO)
	var boss_dx: float = boss_pos.x - ball_pos.x
	var away_dir: int = -1 if boss_dx > 0.0 else (1 if boss_dx < 0.0 else kick_dir)
	var raw_angle: float = float(kick_dir) * 25.0
	var avoidance: float = float(away_dir) * 35.0
	var final_angle: float = raw_angle * (1.0 - bias) + avoidance * bias
	if kick_dir > 0 and final_angle < 0.0:
		final_angle = max(final_angle, -10.0)
	elif kick_dir < 0 and final_angle > 0.0:
		final_angle = min(final_angle, 10.0)
	if abs(final_angle) < 20.0:
		final_angle = 20.0 * (1.0 if final_angle >= 0.0 else -1.0)
	return clamp(final_angle, -60.0, 60.0)


func _get_marshal_duration_frames(base_frames: float, deps: Dictionary) -> float:
	var prep_cut_pct: float = min(float(_get_kick_enhance_level(deps)) * 7.0, 90.0)
	return max(1.0, base_frames * max(0.1, 1.0 - prep_cut_pct / 100.0))


func _get_kick_enhance_level(deps: Dictionary) -> int:
	var runtime_perk_state: Object = deps.get("runtime_perk_state", null)
	if runtime_perk_state != null and runtime_perk_state.has_method("get_runtime_skill_level"):
		return max(0, int(runtime_perk_state.get_runtime_skill_level("kick_enhance")))
	return 0


func _trigger_feedback(deps: Dictionary, amount: float, intensity: float) -> void:
	var feedback: Object = deps.get("feedback", null)
	if feedback == null:
		return
	if feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(amount, intensity)
	elif feedback.has_method("set_screen_shake"):
		feedback.set_screen_shake(amount, intensity)


func _get_player_center(player_pos: Vector2, config: Dictionary) -> Vector2:
	return player_pos + _get_paddle_size(config) * 0.5


func _get_paddle_size(config: Dictionary) -> Vector2:
	return Vector2(
		max(1.0, float(config.get("paddle_width", 155.0))),
		max(1.0, float(config.get("paddle_height", 50.0)))
	)


func _get_ball_pos(config: Dictionary) -> Vector2:
	return _get_vector2(config.get("ball_pos", Vector2.ZERO), Vector2.ZERO)


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
