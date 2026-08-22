extends RefCounted

const RuntimePerkProgression := preload("res://scripts/characters/runtime_perk_progression.gd")


static func segment_intersects_rect(start_pos: Vector2, end_pos: Vector2, rect: Rect2) -> bool:
	if rect.has_point(start_pos) or rect.has_point(end_pos):
		return true
	var top_left: Vector2 = rect.position
	var top_right := Vector2(rect.position.x + rect.size.x, rect.position.y)
	var bottom_right := rect.position + rect.size
	var bottom_left := Vector2(rect.position.x, rect.position.y + rect.size.y)
	return (
		_segments_intersect(start_pos, end_pos, top_left, top_right)
		or _segments_intersect(start_pos, end_pos, top_right, bottom_right)
		or _segments_intersect(start_pos, end_pos, bottom_right, bottom_left)
		or _segments_intersect(start_pos, end_pos, bottom_left, top_left)
	)


static func blade_rect(pos: Vector2, width: float, dark_mode: bool, normal_height: float, dark_height: float) -> Rect2:
	var hit_height: float = dark_height if dark_mode else normal_height
	return Rect2(Vector2(pos.x - width * 0.5, pos.y - hit_height), Vector2(width, hit_height))


static func blade_projectile_speed_multiplier(blade_amp_level: int) -> float:
	return 1.0 + RuntimePerkProgression.get_value("blade_amp", "projectile_speed_bonus", blade_amp_level)


static func blade_projectile_homing_strength(blade_amp_level: int, dark_mode: bool) -> float:
	if RuntimePerkProgression.get_int_value("blade_amp", "homing_tier", blade_amp_level) <= 0:
		return 0.0
	return 0.30 if dark_mode else 0.60


static func blade_projectile_motion(
	pos: Vector2,
	ball_pos: Vector2,
	fps_scale: float,
	base_speed: float,
	blade_amp_level: int,
	dark_mode: bool,
	allow_homing: bool
) -> Vector2:
	var next_pos: Vector2 = pos
	var projectile_speed_mult: float = blade_projectile_speed_multiplier(blade_amp_level)
	next_pos.y -= base_speed * projectile_speed_mult * fps_scale
	if allow_homing:
		var homing: float = blade_projectile_homing_strength(blade_amp_level, dark_mode)
		if homing > 0.0:
			var homing_dx: float = ball_pos.x - next_pos.x
			if abs(homing_dx) > 0.5:
				next_pos.x += clamp(homing_dx * 0.35 * homing, -18.0 * homing, 18.0 * homing) * fps_scale
	return next_pos


static func blade_projectile_trail_next(trail: Array, pos: Vector2, max_points: int) -> Array:
	var next_trail: Array = trail.duplicate()
	next_trail.append(pos)
	var safe_max_points: int = max(0, max_points)
	while next_trail.size() > safe_max_points:
		next_trail.pop_front()
	return next_trail


static func blade_projectile_allows_homing(already_hit_ball: bool, fading: bool) -> bool:
	return not already_hit_ball and not fading


static func blade_projectile_should_start_fadeout(projectile_y: float, target_y: float, already_fading: bool) -> bool:
	return not already_fading and projectile_y <= target_y


static func blade_projectile_fadeout_tick(fading: bool, fadeout_frames: float, fps_scale: float) -> Dictionary:
	if not fading:
		return {
			"frames": fadeout_frames,
			"expired": false,
		}
	var next_frames: float = max(0.0, fadeout_frames - fps_scale)
	return {
		"frames": next_frames,
		"expired": next_frames <= 0.0,
	}


static func blade_projectile_hits_ball(
	projectile_rect: Rect2,
	target_ball_rect: Rect2,
	ball_active: bool,
	already_hit_ball: bool,
	fading: bool
) -> bool:
	return ball_active and not already_hit_ball and not fading and projectile_rect.intersects(target_ball_rect)


static func blade_projectile_launch_spec(
	player_pos: Vector2,
	paddle_size: Vector2,
	blade_amp_level: int,
	dark_mode: bool,
	base_width: float,
	base_range: float,
	start_y_offset: float,
	width_scale: float = 1.0,
	range_scale: float = 1.0,
	min_width: float = 0.0
) -> Dictionary:
	var amp_mult: float = 1.0 + RuntimePerkProgression.get_value("blade_amp", "range_width_bonus", blade_amp_level)
	var size_mult: float = (1.3 if dark_mode else 1.0) * amp_mult
	var range_mult: float = (2.0 if dark_mode else 1.0) * amp_mult
	var center: Vector2 = player_pos + paddle_size * 0.5
	var start_pos := Vector2(center.x, center.y + start_y_offset)
	return {
		"pos": start_pos,
		"start_y": start_pos.y,
		"target_y": start_pos.y - base_range * range_mult * range_scale,
		"width": max(min_width, base_width * size_mult * width_scale),
		"size_mult": size_mult,
		"range_mult": range_mult,
	}


static func blade_motion_phase_progress(phase_frames: float, duration_frames: float) -> float:
	return min(1.0, phase_frames / max(1.0, duration_frames))


static func blade_motion_start_position(
	player_pos: Vector2,
	floor_y: float,
	pop_up_from_combo: bool,
	combo_pop_min_offset: float,
	combo_pop_extra: float
) -> Vector2:
	if not pop_up_from_combo:
		return player_pos
	var current_offset: float = player_pos.y - floor_y
	var pop_offset: float = min(current_offset, combo_pop_min_offset) - combo_pop_extra
	return Vector2(player_pos.x, floor_y + pop_offset)


static func blade_prep_fall_y(player_y: float, floor_y: float, fps_scale: float, prep_fall_speed: float) -> float:
	return min(floor_y, player_y + prep_fall_speed * fps_scale)


static func blade_motion_spin_angle(phase: int, progress: float, spin_turns: float) -> float:
	var safe_progress: float = clamp(progress, 0.0, 1.0)
	match phase:
		0:
			return safe_progress * TAU * spin_turns
		1:
			var remaining: float = 1.0 - safe_progress
			return TAU * spin_turns + remaining * deg_to_rad(90.0) * remaining
	return 0.0


static func blade_motion_rest_position(
	x_pos: float,
	phase2_base_y: float,
	floor_y: float,
	phase_frames: float,
	jump_up_frames: float,
	rest_frames: float,
	jump_peak: float
) -> Vector2:
	var offset_y: float = 0.0
	var base_y: float = phase2_base_y
	if phase_frames < jump_up_frames:
		var jump_t: float = blade_motion_phase_progress(phase_frames, jump_up_frames)
		offset_y = -jump_peak * sin(jump_t * PI * 0.5)
	else:
		var fall_t: float = blade_motion_phase_progress(phase_frames - jump_up_frames, rest_frames - jump_up_frames)
		var fall_progress: float = 1.0 - cos(fall_t * PI * 0.5)
		offset_y = -jump_peak * (1.0 - fall_progress)
		base_y = lerp(phase2_base_y, floor_y, fall_progress)
	return Vector2(x_pos, base_y + offset_y)


static func blade_horizontal_control_motion(
	player_pos: Vector2,
	player_speed: float,
	direction: float,
	fps_scale: float,
	config: Dictionary,
	floor_y: float,
	paddle_width: float,
	jetpack_max_height: float,
	airborne_bonus_max: float,
	dark_mode: bool,
	lateral_speed_scale: float = 1.0
) -> Dictionary:
	var max_speed: float = max(0.0, float(config.get("paddle_max_speed", config.get("paddle_speed", 4.0))))
	var accel: float = max(0.0, float(config.get("paddle_accel", 0.38)))
	var decel: float = max(0.0, float(config.get("paddle_decel", 0.38)))
	var turn_decel: float = max(0.0, float(config.get("paddle_turn_decel", 1.0)))
	var airborne_mult: float = 1.0
	if player_pos.y < floor_y:
		var height_ratio: float = clamp((floor_y - player_pos.y) / jetpack_max_height, 0.0, 1.0)
		airborne_mult += height_ratio * airborne_bonus_max
	max_speed *= airborne_mult
	accel *= airborne_mult
	if dark_mode:
		max_speed *= 3.0
		accel *= 3.0
	# Post-fire steering damp (Dark Blade phase 2): scales BOTH cap and accel so the
	# airborne x3.15 * dark x3.0 stack does not read as a too-fast left/right slide.
	var safe_lateral_scale: float = max(0.0, lateral_speed_scale)
	max_speed *= safe_lateral_scale
	accel *= safe_lateral_scale
	if direction < 0.0:
		var target_left: float = -max_speed
		if player_speed > target_left:
			player_speed -= accel * fps_scale
		if player_speed > 0.0:
			player_speed -= turn_decel * fps_scale
	elif direction > 0.0:
		var target_right: float = max_speed
		if player_speed < target_right:
			player_speed += accel * fps_scale
		if player_speed < 0.0:
			player_speed += turn_decel * fps_scale
	else:
		player_speed = move_toward(player_speed, 0.0, decel * fps_scale)
	player_speed = clamp(player_speed, -max_speed, max_speed)
	var next_pos := Vector2(player_pos.x + player_speed * fps_scale, player_pos.y)
	next_pos = clamp_player_pos(
		next_pos,
		float(config.get("play_left", 0.0)),
		float(config.get("play_right", config.get("width", 760.0))),
		paddle_width
	)
	return {"player_pos": next_pos, "player_speed": player_speed}


static func blade_dark_auto_fire_window_active(
	dark_mode: bool,
	motion_phase: int,
	total_frames: float,
	start_frames: float,
	end_frames: float
) -> bool:
	return dark_mode and motion_phase < 2 and total_frames >= start_frames and total_frames <= end_frames


static func blade_dark_auto_fire_near_ball(
	ball_pos: Vector2,
	ball_size: float,
	blade_pos: Vector2,
	paddle_size: Vector2,
	near_y: float
) -> bool:
	var ball_center_y: float = ball_pos.y + ball_size * 0.5
	var blade_center_y: float = blade_pos.y + paddle_size.y * 0.5
	return ball_center_y <= blade_center_y and (blade_center_y - ball_center_y) <= near_y


static func blade_dark_should_auto_fire(
	dark_mode: bool,
	motion_phase: int,
	total_frames: float,
	start_frames: float,
	end_frames: float,
	ball_vel: Vector2,
	ball_pos: Vector2,
	ball_size: float,
	blade_pos: Vector2,
	paddle_size: Vector2,
	near_y: float
) -> bool:
	if not blade_dark_auto_fire_window_active(dark_mode, motion_phase, total_frames, start_frames, end_frames):
		return false
	if ball_vel.y <= 0.0:
		return false
	return blade_dark_auto_fire_near_ball(ball_pos, ball_size, blade_pos, paddle_size, near_y)


static func blade_hit_velocity(
	ball_vel: Vector2,
	impact_boost: float,
	speed_cap: float,
	blade_amp_level: int,
	dark_mode: bool,
	hit_speed_scale: float,
	air_base_mult: float,
	dark_base_mult: float
) -> Vector2:
	var current_speed: float = ball_vel.length()
	var next_vel: Vector2 = ball_vel
	if current_speed > 0.1:
		var base_mult: float = dark_base_mult if dark_mode else air_base_mult
		var hit_mult: float = base_mult * (1.0 + RuntimePerkProgression.get_value("blade_amp", "hit_speed_bonus", blade_amp_level)) * max(0.0, hit_speed_scale)
		var new_speed: float = current_speed * hit_mult
		var ratio: float = new_speed / current_speed
		next_vel = Vector2(ball_vel.x * ratio, -abs(ball_vel.y * ratio))
	else:
		next_vel = Vector2(0.0, -10.0)
	return limit_effective_velocity(next_vel, impact_boost, speed_cap)


static func ball_rect(scene: Dictionary, context: Dictionary) -> Rect2:
	var resolved_ball_pos: Vector2 = _get_vector2(scene.get("ball_pos", context.get("ball_pos", Vector2.ZERO)), Vector2.ZERO)
	var ball_size: float = max(1.0, float(context.get("ball_size", scene.get("ball_size", 28.6))))
	return Rect2(resolved_ball_pos - Vector2(ball_size, ball_size) * 0.5, Vector2(ball_size, ball_size))


static func shadow_step_wave_rect(pos: Vector2, collision_size: Vector2) -> Rect2:
	return Rect2(pos - collision_size * 0.5, collision_size)


static func shadow_step_wave_motion(
	pos: Vector2,
	direction: int,
	speed: float,
	fps_scale: float,
	target_x: float
) -> Dictionary:
	var next_pos: Vector2 = pos
	next_pos.x += float(direction) * speed * fps_scale
	var reached_target: bool = (
		(direction > 0 and next_pos.x >= target_x)
		or (direction < 0 and next_pos.x <= target_x)
	)
	return {
		"pos": next_pos,
		"reached_target": reached_target,
	}


static func shadow_step_hologram_progress(frames: float, duration: float) -> float:
	return clamp(frames / max(1.0, duration), 0.0, 1.0)


static func shadow_step_curve_motion(
	ball_vel: Vector2,
	timer: float,
	total_frames: float,
	force: float,
	curve_dir: int,
	fps_scale: float
) -> Dictionary:
	var progress: float = 1.0 - timer / max(1.0, total_frames)
	var rot_deg: float = (1.0 - progress) * force * 0.35
	var curved_vel: Vector2 = ball_vel.rotated(float(curve_dir) * deg_to_rad(rot_deg))
	var next_timer: float = max(0.0, timer - fps_scale)
	return {
		"ball_vel": curved_vel,
		"timer": next_timer,
		"active": next_timer > 0.0,
	}


static func shadow_step_hit_profile(
	ball_pos: Vector2,
	hit_center: Vector2,
	hit_size: Vector2,
	speed_min: float,
	speed_max: float,
	curve_frames_min: float,
	curve_frames_max: float,
	force_min: float,
	force_max: float
) -> Dictionary:
	var dx: float = abs(ball_pos.x - hit_center.x) / max(hit_size.x * 0.5, 1.0)
	var dy: float = abs(ball_pos.y - hit_center.y) / max(hit_size.y * 0.5, 1.0)
	var dist_ratio: float = min(1.0, max(dx, dy))
	var center_t: float = 1.0 - dist_ratio
	return {
		"center_t": center_t,
		"speed_mult": speed_min + center_t * (speed_max - speed_min),
		"curve_frames": curve_frames_min + center_t * (curve_frames_max - curve_frames_min),
		"curve_force": force_min + center_t * (force_max - force_min),
	}


static func shadow_step_hologram_hit_rect(target: Vector2, paddle_size: Vector2, hitbox_padding: Vector2) -> Rect2:
	var collision_size: Vector2 = paddle_size + hitbox_padding
	return Rect2(target - collision_size * 0.5, collision_size)


static func emp_strike_hit_velocity(ball_vel: Vector2) -> Vector2:
	return Vector2(ball_vel.x, -abs(ball_vel.y))


static func emp_strike_shockwave_pos(player_pos: Vector2, paddle_size: Vector2, floor_y: float) -> Vector2:
	return Vector2(player_pos.x + paddle_size.x * 0.5, floor_y + paddle_size.y)


static func emp_strike_shockwave_progress(timer: float, shockwave_pos: Vector2, total_frames: float) -> float:
	if timer <= 0.0:
		return 1.0 if shockwave_pos != Vector2.ZERO else 0.0
	return 1.0 - clamp(timer / max(1.0, total_frames), 0.0, 1.0)


static func emp_strike_shockwave_radius(
	timer: float,
	shockwave_pos: Vector2,
	total_frames: float,
	start_radius: float,
	max_radius: float
) -> float:
	return lerp(start_radius, max_radius, emp_strike_shockwave_progress(timer, shockwave_pos, total_frames))


static func dive_shockwave_boss_reach_radius(
	config: Dictionary,
	shockwave_pos: Vector2,
	base_max_radius: float,
	ring_half_thickness: float
) -> float:
	var boss_pos: Vector2 = _get_vector2(
		config.get("boss_pos", Vector2(float(config.get("width", 760.0)) * 0.5 - 50.0, 25.0)),
		Vector2.ZERO
	)
	var boss_width: float = max(1.0, float(config.get("boss_paddle_width", 100.0)))
	var boss_height: float = max(1.0, float(config.get("boss_hitbox_height", 40.0)))
	var boss_center: Vector2 = boss_pos + Vector2(boss_width * 0.5, boss_height * 0.5)
	return max(base_max_radius, shockwave_pos.distance_to(boss_center) + ring_half_thickness)


static func dive_shockwave_ring_touches_boss(
	previous_radius: float,
	current_radius: float,
	config: Dictionary,
	shockwave_pos: Vector2,
	ring_half_thickness: float
) -> bool:
	var boss_pos: Vector2 = _get_vector2(
		config.get("boss_pos", Vector2(float(config.get("width", 760.0)) * 0.5 - 50.0, 25.0)),
		Vector2.ZERO
	)
	var boss_width: float = max(1.0, float(config.get("boss_paddle_width", 100.0)))
	var boss_height: float = max(1.0, float(config.get("boss_hitbox_height", 40.0)))
	var closest_x: float = clamp(shockwave_pos.x, boss_pos.x, boss_pos.x + boss_width)
	var closest_y: float = clamp(shockwave_pos.y, boss_pos.y, boss_pos.y + boss_height)
	var boss_distance: float = shockwave_pos.distance_to(Vector2(closest_x, closest_y))
	var ring_inner: float = min(previous_radius, current_radius) - ring_half_thickness
	var ring_outer: float = max(previous_radius, current_radius) + ring_half_thickness
	return ring_inner <= boss_distance and ring_outer >= boss_distance


static func emp_slip_start_state(
	ball_pos: Vector2,
	context: Dictionary,
	height_snapshot: float,
	max_height: float,
	min_duration: float,
	max_duration: float,
	emp_sleep_pct: int,
	slip_speed: float
) -> Dictionary:
	var boss_pos: Vector2 = _get_vector2(
		context.get("boss_pos", Vector2(float(context.get("width", 760.0)) * 0.5 - 50.0, 25.0)),
		Vector2.ZERO
	)
	var boss_width: float = max(1.0, float(context.get("boss_paddle_width", 100.0)))
	var boss_center_x: float = boss_pos.x + boss_width * 0.5
	var slip_dir: float = 1.0 if ball_pos.x > boss_center_x else -1.0
	var height_ratio: float = clamp(height_snapshot / max(1.0, max_height), 0.0, 1.0)
	var base_duration: float = min_duration + (max_duration - min_duration) * height_ratio
	var emp_sleep_multiplier: float = 1.0 + float(emp_sleep_pct) / 100.0
	var duration: float = max(1.0, round(base_duration * emp_sleep_multiplier))
	return {
		"duration": duration,
		"slip_vel": slip_dir * slip_speed,
	}


static func emp_slip_boss_motion(
	boss_pos: Vector2,
	context: Dictionary,
	fps_scale: float,
	slip_timer: float,
	slip_duration: float,
	slip_vel: float
) -> Dictionary:
	if slip_timer <= 0.0:
		return {
			"boss_pos": boss_pos,
			"boss_vel": 0.0,
			"slip_timer": 0.0,
			"slip_vel": 0.0,
		}
	var next_pos: Vector2 = boss_pos
	var next_slip_vel: float = slip_vel
	var play_left: float = float(context.get("play_left", 0.0))
	var play_right: float = float(context.get("play_right", context.get("width", 760.0)))
	var boss_width: float = max(1.0, float(context.get("boss_paddle_width", 100.0)))
	var ratio: float = clamp(slip_timer / max(1.0, slip_duration), 0.0, 1.0)
	var motion_vel: float = next_slip_vel * ratio
	next_pos.x += motion_vel * fps_scale
	if next_pos.x <= play_left:
		next_pos.x = play_left
		next_slip_vel = abs(next_slip_vel) * 0.5
	elif next_pos.x >= play_right - boss_width:
		next_pos.x = play_right - boss_width
		next_slip_vel = -abs(next_slip_vel) * 0.5
	var next_timer: float = max(0.0, slip_timer - fps_scale)
	if next_timer <= 0.0:
		next_slip_vel = 0.0
	return {
		"boss_pos": next_pos,
		"boss_vel": motion_vel,
		"slip_timer": next_timer,
		"slip_vel": next_slip_vel,
	}


static func phantom_kick_knockback_velocity(ball_pos: Vector2, boss_pos: Vector2, boss_width: float, base_speed: float) -> float:
	var boss_center_x: float = boss_pos.x + boss_width * 0.5
	var knockback_dir: float = 1.0 if ball_pos.x > boss_center_x else -1.0
	return knockback_dir * base_speed


static func kick_guard_knockback_velocity(
	boss_pos: Vector2,
	boss_width: float,
	context: Dictionary,
	bonus_pct: int,
	fire_base: float,
	distance_multiplier: float
) -> float:
	var knockback_ratio: float = max(0.0, float(bonus_pct) / 100.0)
	if knockback_ratio <= 0.0:
		return 0.0
	var base_power: float = fire_base * knockback_ratio * distance_multiplier
	var width: float = float(context.get("width", context.get("play_right", 760.0)))
	var boss_center_x: float = boss_pos.x + boss_width * 0.5
	var direction: float = -1.0 if boss_center_x >= width * 0.5 else 1.0
	return direction * base_power * randf_range(1.1, 1.2)


static func center_to_player_pos(center: Vector2, config: Dictionary, player_paddle_size: Vector2) -> Vector2:
	var play_left: float = float(config.get("play_left", 0.0))
	var play_right: float = float(config.get("play_right", config.get("width", 760.0)))
	var height: float = float(config.get("height", 750.0))
	return Vector2(
		clamp(center.x - player_paddle_size.x * 0.5, play_left, max(play_left, play_right - player_paddle_size.x)),
		clamp(center.y - player_paddle_size.y * 0.5, 0.0, max(0.0, height - player_paddle_size.y))
	)


static func player_center(player_pos: Vector2, config: Dictionary) -> Vector2:
	return player_pos + get_paddle_size(config) * 0.5


static func get_paddle_size(config: Dictionary) -> Vector2:
	return Vector2(
		max(1.0, float(config.get("paddle_width", 155.0))),
		max(1.0, float(config.get("paddle_height", 50.0)))
	)


static func get_ball_pos(config: Dictionary) -> Vector2:
	return _get_vector2(config.get("ball_pos", Vector2.ZERO), Vector2.ZERO)


static func nerve_strike_target_pos(config: Dictionary, target_y_offset: float) -> Vector2:
	var target_center: Vector2 = nerve_strike_target_center(config, target_y_offset)
	var player_paddle_size: Vector2 = get_paddle_size(config)
	# Python parity: Venom Edge snaps PLAYER.centerx to BOSS.centerx even near
	# the walls. Do not clamp here, or edge-position bosses leave Viper beside
	# the boss instead of directly behind it.
	return target_center - player_paddle_size * 0.5


static func nerve_strike_target_center(config: Dictionary, target_y_offset: float) -> Vector2:
	var boss_center: Vector2 = nerve_strike_boss_center(config)
	var visual_offset_y: float = float(config.get("boss_visual_center_y_offset", 0.0))
	return Vector2(boss_center.x, boss_center.y + visual_offset_y + target_y_offset)


static func nerve_strike_boss_center(config: Dictionary) -> Vector2:
	var boss_pos: Vector2 = _get_vector2(config.get("boss_pos", Vector2(330.0, 25.0)), Vector2(330.0, 25.0))
	var boss_width: float = max(1.0, float(config.get("boss_paddle_width", config.get("boss_width", 100.0))))
	var boss_height: float = max(1.0, float(config.get("boss_hitbox_height", config.get("boss_paddle_height", 50.0))))
	return boss_pos + Vector2(boss_width * 0.5, boss_height * 0.5)


static func nerve_strike_hits_target(strike_center: Vector2, target_center: Vector2, hit_radius: float) -> bool:
	return strike_center.distance_to(target_center) <= hit_radius


static func nerve_strike_miss_text_pos(target_center: Vector2, y_offset: float) -> Vector2:
	return target_center + Vector2(0.0, y_offset)


static func nerve_strike_return_target_pos(config: Dictionary) -> Vector2:
	var player_paddle_size: Vector2 = get_paddle_size(config)
	var fallback_ball_pos := Vector2(float(config.get("width", 760.0)) * 0.5, 0.0)
	var current_ball_pos: Vector2 = _get_vector2(config.get("ball_pos", fallback_ball_pos), fallback_ball_pos)
	var target := Vector2(current_ball_pos.x - player_paddle_size.x * 0.5, player_floor_y(config))
	return clamp_player_pos(target, float(config.get("play_left", 0.0)), float(config.get("play_right", config.get("width", 760.0))), player_paddle_size.x)


static func nerve_strike_phase_progress(phase_frames: float, duration: float) -> float:
	return clamp(phase_frames / max(1.0, duration), 0.0, 1.0)


static func nerve_strike_should_trigger_slash(hit_confirmed: bool, slash_triggered: bool, progress: float, trigger_ratio: float) -> bool:
	return hit_confirmed and not slash_triggered and progress >= trigger_ratio


static func nerve_strike_dash_motion(
	start_pos: Vector2,
	current_target_pos: Vector2,
	live_target_pos: Vector2,
	phase_frames: float,
	dash_frames: float,
	tracking_end_ratio: float,
	tracking_strength: float
) -> Dictionary:
	var progress: float = clamp(phase_frames / max(1.0, dash_frames), 0.0, 1.0)
	var next_target_pos: Vector2 = current_target_pos
	if progress <= tracking_end_ratio:
		var track_ratio: float = 1.0 - clamp(progress / max(0.01, tracking_end_ratio), 0.0, 1.0)
		next_target_pos = next_target_pos.lerp(live_target_pos, clamp(tracking_strength * track_ratio, 0.0, 1.0))
	var eased: float = 0.5 - 0.5 * cos(progress * PI)
	return {
		"progress": progress,
		"target_pos": next_target_pos,
		"pos": start_pos.lerp(next_target_pos, eased),
	}


static func nerve_strike_return_motion(start_pos: Vector2, target_pos: Vector2, phase_frames: float, duration: float) -> Dictionary:
	var progress: float = clamp(phase_frames / max(1.0, duration), 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - progress, 2.0)
	return {
		"progress": progress,
		"pos": start_pos.lerp(target_pos, eased),
	}


static func nerve_strike_clone_slash_motion(
	origin: Vector2,
	current_target: Vector2,
	live_target: Vector2,
	current_timer: float,
	fps_scale: float,
	travel_frames: float,
	tracking_end_ratio: float,
	tracking_strength: float
) -> Dictionary:
	var timer: float = min(travel_frames, current_timer + fps_scale)
	var progress: float = clamp(timer / max(1.0, travel_frames), 0.0, 1.0)
	var next_target: Vector2 = current_target
	if progress <= tracking_end_ratio:
		next_target = next_target.lerp(live_target, tracking_strength)
	var eased: float = 0.5 - 0.5 * cos(progress * PI)
	return {
		"timer": timer,
		"progress": progress,
		"target": next_target,
		"pos": origin.lerp(next_target, eased),
	}


static func player_floor_y(config: Dictionary) -> float:
	return float(config.get("player_floor_y", float(config.get("height", 750.0)) - get_paddle_size(config).y))


static func clamp_player_pos(pos: Vector2, play_left: float, play_right: float, paddle_width: float) -> Vector2:
	var min_x: float = play_left
	var max_x: float = play_right - max(1.0, paddle_width)
	if max_x < min_x:
		return Vector2(play_left, pos.y)
	return Vector2(clamp(pos.x, min_x, max_x), pos.y)


static func locked_startup_player_pos(player_pos: Vector2, locked_x_valid: bool, locked_x: float, config: Dictionary) -> Vector2:
	if not locked_x_valid:
		return player_pos
	var play_left: float = float(config.get("play_left", 0.0))
	return Vector2(clamp(locked_x, play_left, max(play_left, float(config.get("play_right", 760.0)) - get_paddle_size(config).x)), player_pos.y)


static func core_flip_velocity_to_target(
	speed: float,
	kick_dir: int,
	ball_pos: Vector2,
	width: float,
	target_x: float,
	target_y: float
) -> Vector2:
	var mirrored_target_x: float = (2.0 * width) - target_x if kick_dir > 0 else -target_x
	var delta := Vector2(mirrored_target_x - ball_pos.x, target_y - ball_pos.y)
	if delta.length() <= 0.000001:
		return Vector2.ZERO
	return delta.normalized() * speed


static func core_flip_bank_velocity(speed: float, kick_dir: int, config: Dictionary, aim_level: int) -> Vector2:
	var width: float = float(config.get("width", config.get("play_right", 760.0)))
	var ball_pos: Vector2 = get_ball_pos(config)
	var boss_pos: Vector2 = _get_vector2(config.get("boss_pos", Vector2(width * 0.5 - 50.0, 25.0)), Vector2(width * 0.5 - 50.0, 25.0))
	var boss_width: float = max(1.0, float(config.get("boss_paddle_width", 100.0)))
	var boss_height: float = max(1.0, float(config.get("boss_hitbox_height", 40.0)))
	var boss_center := Vector2(boss_pos.x + boss_width * 0.5, boss_pos.y + boss_height * 0.5)
	var bias: float = 0.6 + (1.0 - 0.6) * RuntimePerkProgression.get_value("kick_enhance", "runtime_aim_gain", aim_level)
	var safe_dir: int = 1 if kick_dir >= 0 else -1
	var wall_x: float = width if safe_dir > 0 else 0.0
	var target_spread_x: float = max(20.0, 150.0 * (1.0 - bias))
	var target_spread_y: float = max(10.0, 68.0 * (1.0 - bias))
	var fallback_target_x: float = clamp(boss_center.x + randf_range(-target_spread_x, target_spread_x), 70.0, width - 70.0)
	var fallback_target_y: float = max(70.0, min(ball_pos.y - 120.0, boss_center.y + randf_range(-target_spread_y, target_spread_y)))
	var boss_avoid_margin_x: float = round(max(18.0, 54.0 - bias * 24.0))
	var boss_avoid_margin_y: float = round(max(8.0, 24.0 - bias * 10.0))
	var boss_avoid_rect := Rect2(boss_pos, Vector2(boss_width, boss_height)).grow_individual(
		boss_avoid_margin_x,
		boss_avoid_margin_y,
		boss_avoid_margin_x,
		boss_avoid_margin_y
	)
	var lane_gap_base: float = max(12.0, 42.0 - bias * 18.0)
	var lane_gap_step: float = max(10.0, 30.0 - bias * 10.0)
	var lane_jitter: float = max(2.0, 16.0 * (1.0 - bias))
	var candidate_count := RuntimePerkProgression.get_int_value(
		"kick_enhance", "runtime_aim_candidate_count", aim_level
	)
	var target_y_offsets := [
		0.0,
		-target_spread_y * 0.55,
		target_spread_y * 0.55,
		-target_spread_y,
		target_spread_y,
	]
	var preferred_sides := [-1, 1] if safe_dir < 0 else [1, -1]
	for side_pref in preferred_sides:
		for y_off in target_y_offsets:
			var candidate_y: float = boss_center.y + float(y_off) + randf_range(-lane_jitter, lane_jitter)
			candidate_y = max(70.0, min(ball_pos.y - 120.0, candidate_y))
			for idx in range(candidate_count):
				var lane_gap: float = lane_gap_base + float(idx) * lane_gap_step
				var candidate_x: float = boss_avoid_rect.position.x - lane_gap if int(side_pref) < 0 else boss_avoid_rect.position.x + boss_avoid_rect.size.x + lane_gap
				candidate_x += randf_range(-lane_jitter, lane_jitter)
				candidate_x = clamp(candidate_x, 28.0, width - 28.0)
				var velocity: Vector2 = core_flip_velocity_to_target(speed, safe_dir, ball_pos, width, candidate_x, candidate_y)
				if velocity.length() <= 0.01 or abs(velocity.x) <= 0.000001:
					continue
				var t_wall: float = (wall_x - ball_pos.x) / velocity.x
				if not (t_wall > 0.03 and t_wall < 0.97):
					continue
				var bounce_y: float = ball_pos.y + velocity.y * t_wall
				if bounce_y < 40.0 or bounce_y > ball_pos.y - 18.0:
					continue
				if segment_intersects_rect(Vector2(wall_x, bounce_y), Vector2(candidate_x, candidate_y), boss_avoid_rect):
					continue
				return velocity
	var fallback_velocity: Vector2 = core_flip_velocity_to_target(speed, safe_dir, ball_pos, width, fallback_target_x, fallback_target_y)
	if fallback_velocity.length() > 0.01:
		return fallback_velocity
	return Vector2(float(safe_dir) * 0.65, -0.76).normalized() * speed


static func core_flip_start_motion(origin_center: Vector2, target_center: Vector2, apex_y_offset: float) -> Dictionary:
	return {
		"apex_center": target_center + Vector2(0.0, apex_y_offset),
		"kick_dir": core_flip_kick_direction(origin_center, target_center),
	}


static func core_flip_miss_text_pos(origin_center: Vector2, apex_y_offset: float) -> Vector2:
	return origin_center + Vector2(0.0, apex_y_offset)


static func core_flip_kick_direction(from_center: Vector2, target_center: Vector2) -> int:
	return 1 if target_center.x >= from_center.x else -1


static func core_flip_phase_progress(phase_frames: float, duration_frames: float) -> float:
	return min(1.0, phase_frames / duration_frames)


static func core_flip_should_enter_kick_phase(wall_touch_count: int, climb_t: float) -> bool:
	return wall_touch_count >= 2 or climb_t >= 1.0


static func core_flip_spin_degrees(phase: int, phase_t: float) -> float:
	var safe_t: float = clamp(phase_t, 0.0, 1.0)
	match phase:
		0:
			return safe_t * 720.0
		1:
			return 720.0 + safe_t * 120.0
		2:
			return 1440.0 + safe_t * 360.0
		3:
			return 1800.0 + (1.0 - pow(1.0 - safe_t, 2.0)) * 90.0
	return 0.0


static func core_flip_wall_climb_center(
	t1: float,
	config: Dictionary,
	player_paddle_size: Vector2,
	origin_center: Vector2,
	target_center: Vector2,
	kick_dir: int,
	phase_frames: float,
	leg_frames: float,
	cling_frames: float,
	kick_trigger_y: float
) -> Vector2:
	var width: float = float(config.get("width", config.get("play_right", 760.0)))
	var left_wall_x: float = max(player_paddle_size.x * 0.5, 15.0)
	var right_wall_x: float = width - max(player_paddle_size.x * 0.5, 15.0)
	var first_wall_x: float = left_wall_x if kick_dir >= 0 else right_wall_x
	var second_wall_x: float = right_wall_x if kick_dir >= 0 else left_wall_x
	var safe_cling_frames: float = min(leg_frames - 2.0, cling_frames)
	var travel_frames: float = max(2.0, leg_frames - safe_cling_frames)
	var leg_index: int = max(0, int(floor(phase_frames / max(1.0, leg_frames))))
	var leg_elapsed: float = fmod(phase_frames, max(1.0, leg_frames))
	var prev_x: float = origin_center.x if leg_index == 0 else (first_wall_x if (leg_index - 1) % 2 == 0 else second_wall_x)
	var next_x: float = first_wall_x if leg_index % 2 == 0 else second_wall_x
	var pos_x: float = next_x
	var wall_hop: float = 0.0
	if leg_elapsed < travel_frames:
		var leg_t: float = leg_elapsed / travel_frames
		var leg_ease: float = leg_t * leg_t * (3.0 - 2.0 * leg_t)
		pos_x = lerpf(prev_x, next_x, leg_ease)
		wall_hop = sin(leg_t * PI) * 18.0
	var goal_y: float = clamp(target_center.y + kick_trigger_y * 0.75, 120.0, 650.0)
	var pos_y: float = lerpf(origin_center.y, goal_y, t1) - wall_hop
	return Vector2(
		clamp(pos_x, player_paddle_size.x * 0.5, width - player_paddle_size.x * 0.5),
		clamp(pos_y, player_paddle_size.y * 0.5, float(config.get("height", 750.0)) - player_paddle_size.y * 0.5)
	)


static func core_flip_wall_contact_state(center: Vector2, width: float, phase_frames: float, leg_frames: float, cling_frames: float) -> Dictionary:
	var wall_x: float = 2.0 if center.x < width * 0.5 else width - 2.0
	var travel_frames: float = max(2.0, leg_frames - cling_frames)
	var wall_touch_count: int = 0
	if phase_frames >= travel_frames:
		wall_touch_count = 1
	if phase_frames >= leg_frames + travel_frames:
		wall_touch_count = 2
	return {
		"line_to": Vector2(wall_x, center.y),
		"touch_count": wall_touch_count,
	}


static func core_flip_kick_motion(apex_center: Vector2, target_center: Vector2, kick_t: float) -> Dictionary:
	var safe_t: float = clamp(kick_t, 0.0, 1.0)
	var ease_t: float = safe_t * safe_t
	var center: Vector2 = apex_center.lerp(target_center, ease_t)
	return {
		"center": center,
		"dir": core_flip_kick_direction(center, target_center),
	}


static func core_flip_kick_hits_ball(kick_center: Vector2, ball_center: Vector2, hit_radius: float) -> bool:
	return kick_center.distance_to(ball_center) <= hit_radius


static func core_flip_return_motion(return_start_center: Vector2, origin_center: Vector2, return_t: float) -> Dictionary:
	var safe_t: float = clamp(return_t, 0.0, 1.0)
	var ease_t: float = safe_t * safe_t
	return {
		"center": return_start_center.lerp(origin_center, ease_t),
		"spin_degrees": core_flip_spin_degrees(3, safe_t),
	}


static func aimed_kick_launch_angle(
	kick_dir: int,
	ball_pos: Vector2,
	boss_pos: Vector2,
	aim_level: int,
	base_bias: float,
	min_angle: float
) -> float:
	var bias: float = base_bias + (1.0 - base_bias) * RuntimePerkProgression.get_value("kick_enhance", "runtime_aim_gain", aim_level)
	var boss_dx: float = boss_pos.x - ball_pos.x
	var away_dir: int = -1 if boss_dx > 0.0 else (1 if boss_dx < 0.0 else kick_dir)
	var raw_angle: float = randf_range(-55.0, 55.0)
	var avoidance: float = float(away_dir) * randf_range(25.0, 50.0)
	var final_angle: float = raw_angle * (1.0 - bias) + avoidance * bias
	if kick_dir > 0 and final_angle < 0.0:
		final_angle = max(final_angle, -min_angle * 0.5)
	elif kick_dir < 0 and final_angle > 0.0:
		final_angle = min(final_angle, min_angle * 0.5)
	if abs(final_angle) < min_angle:
		final_angle = min_angle * (1.0 if final_angle >= 0.0 else -1.0)
	return clamp(final_angle, -60.0, 60.0)


static func aimed_kick_launch_velocity(speed: float, launch_angle_degrees: float) -> Vector2:
	var rad: float = deg_to_rad(-90.0 + launch_angle_degrees)
	return Vector2(cos(rad), sin(rad)) * speed


static func marshal_launch_angle(
	kick_dir: int,
	ball_pos: Vector2,
	boss_pos: Vector2,
	aim_level: int,
	is_double: bool
) -> float:
	var base_bias: float = 0.8 if is_double else 0.6
	var min_angle: float = 25.0 if is_double else 20.0
	return aimed_kick_launch_angle(kick_dir, ball_pos, boss_pos, aim_level, base_bias, min_angle)


static func marshal_initial_wall_target(
	player_pos: Vector2,
	player_center_pos: Vector2,
	ball_pos: Vector2,
	paddle_size: Vector2,
	field_width: float,
	floor_y: float,
	wall_inset: float,
	min_y: float,
	max_y: float,
	min_rise: float,
	max_rise: float
) -> Dictionary:
	var wall_center_x: float = wall_inset if ball_pos.x >= field_width * 0.5 else field_width - wall_inset
	var ground_y: float = floor_y + paddle_size.y * 0.5
	var height_ratio: float = clamp((player_center_pos.y - min_y) / max(1.0, ground_y - min_y), 0.0, 1.0)
	var rise: float = min_rise + (max_rise - min_rise) * height_ratio
	var wall_center_y: float = clamp(player_center_pos.y - rise, min_y, max_y)
	var wall_pos: Vector2 = Vector2(wall_center_x, wall_center_y) - paddle_size * 0.5
	return {
		"pos": wall_pos,
		"side": 1 if wall_pos.x > player_pos.x else -1,
	}


static func marshal_phase_progress(phase_frames: float, duration_frames: float) -> float:
	return min(1.0, phase_frames / duration_frames)


static func marshal_jump_position(start_pos: Vector2, wall_pos: Vector2, jump_t: float) -> Vector2:
	var eased_t: float = 1.0 - pow(1.0 - jump_t, 2.0)
	return start_pos.lerp(wall_pos, eased_t)


static func marshal_reclimb_wall_target(
	current_wall_center: Vector2,
	ball_pos: Vector2,
	paddle_size: Vector2,
	field_width: float,
	wall_inset: float,
	ball_y_offset: float,
	min_y: float,
	max_y: float
) -> Vector2:
	var wall_center_x: float = wall_inset
	if current_wall_center.x < field_width * 0.5:
		wall_center_x = field_width - wall_inset
	var wall_center_y: float = clamp(ball_pos.y + ball_y_offset, min_y, max_y)
	return Vector2(wall_center_x, wall_center_y) - paddle_size * 0.5


static func marshal_should_reclimb(ball_pos: Vector2, wall_center: Vector2, threshold: float) -> bool:
	return abs(ball_pos.x - wall_center.x) < threshold


static func marshal_reclimb_position(reclimb_start_pos: Vector2, wall_pos: Vector2, reclimb_t: float) -> Vector2:
	var smooth_t: float = reclimb_t * reclimb_t * (3.0 - 2.0 * reclimb_t)
	return reclimb_start_pos.lerp(wall_pos, smooth_t)


static func marshal_charge_position(
	charge_start_pos: Vector2,
	ball_pos: Vector2,
	paddle_size: Vector2,
	charge_t: float
) -> Vector2:
	var target_pos: Vector2 = ball_pos - paddle_size * 0.5
	return charge_start_pos.lerp(target_pos, charge_t * charge_t)


static func marshal_charge_hits_ball(charge_center: Vector2, ball_pos: Vector2, hit_radius: float) -> bool:
	return charge_center.distance_to(ball_pos) <= hit_radius


static func marshal_return_target(
	return_start_pos: Vector2,
	paddle_size: Vector2,
	play_left: float,
	play_right: float,
	floor_y: float
) -> Vector2:
	return Vector2(clamp(return_start_pos.x, play_left, play_right - paddle_size.x), floor_y)


static func marshal_return_position(return_start_pos: Vector2, return_target: Vector2, return_t: float) -> Vector2:
	var smooth_t: float = return_t * return_t * (3.0 - 2.0 * return_t)
	return return_start_pos.lerp(return_target, smooth_t)


static func marshal_wall_kick_dir(wall_center: Vector2, field_width: float) -> int:
	return 1 if wall_center.x < field_width * 0.5 else -1


static func limit_effective_velocity(velocity: Vector2, impact_boost: float, max_effective_speed: float) -> Vector2:
	if max_effective_speed <= 0.0:
		return velocity
	var speed: float = velocity.length()
	if speed <= 0.0:
		return velocity
	var safe_boost: float = max(0.001, impact_boost)
	var effective_speed: float = speed * safe_boost
	if effective_speed <= max_effective_speed:
		return velocity
	return velocity.normalized() * (max_effective_speed / safe_boost)


static func _segments_intersect(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var r: Vector2 = b - a
	var s: Vector2 = d - c
	var denom: float = r.cross(s)
	var cma: Vector2 = c - a
	if abs(denom) <= 0.000001:
		if abs(cma.cross(r)) > 0.000001:
			return false
		var rr: float = r.dot(r)
		if rr <= 0.000001:
			return a.distance_to(c) <= 0.000001
		var t0: float = cma.dot(r) / rr
		var t1: float = t0 + s.dot(r) / rr
		return max(min(t0, t1), 0.0) <= min(max(t0, t1), 1.0)
	var t: float = cma.cross(s) / denom
	var u: float = cma.cross(r) / denom
	return t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
