extends RefCounted

const BALL_IMPACT_BASE_DECAY_RATE := 0.975
const BALL_IMPACT_BASE_MIN_BOOST := 0.70
const SERVE_COLLISION_COOLDOWN_FRAMES := 12.0


func build_reset_snapshot(field_width: float, field_height: float) -> Dictionary:
	var snapshot: Dictionary = build_common_snapshot()
	snapshot["ball_pos"] = Vector2(field_width * 0.5, field_height * 0.5)
	snapshot["ball_vel"] = Vector2.ZERO
	snapshot["ball_active"] = false
	return snapshot


func build_serve_snapshot(
	player_is_serving: bool,
	player_pos: Vector2,
	boss_pos: Vector2,
	player_y: float,
	boss_y: float,
	player_paddle_width: float,
	boss_paddle_width: float,
	boss_hitbox_height: float,
	ball_size: float,
	serve_ball_offset: float,
	ball_physics: Object
) -> Dictionary:
	var snapshot: Dictionary = build_common_snapshot()
	snapshot["ball_active"] = true
	snapshot["ball_serve_origin"] = "player" if player_is_serving else "boss"
	var serve_velocity: Vector2 = _build_serve_velocity(player_is_serving, ball_physics)
	snapshot["ball_vel"] = serve_velocity
	_apply_serve_launch_boost(snapshot, serve_velocity, ball_physics)
	var serve_offset: float = max(1.0, serve_ball_offset if serve_ball_offset > 0.0 else ball_size * 0.5)
	if player_is_serving:
		snapshot["ball_pos"] = Vector2(player_pos.x + player_paddle_width * 0.5, player_y - serve_offset)
		snapshot["player_collision_cooldown"] = SERVE_COLLISION_COOLDOWN_FRAMES
		snapshot["boss_collision_cooldown"] = max(4.0, SERVE_COLLISION_COOLDOWN_FRAMES * 0.5)
	else:
		snapshot["ball_pos"] = Vector2(
			boss_pos.x + boss_paddle_width * 0.5,
			boss_y + boss_hitbox_height + serve_offset
		)
		snapshot["boss_collision_cooldown"] = SERVE_COLLISION_COOLDOWN_FRAMES
		snapshot["player_collision_cooldown"] = max(4.0, SERVE_COLLISION_COOLDOWN_FRAMES * 0.5)
	return snapshot


func build_common_snapshot() -> Dictionary:
	return {
		"ball_impact_boost": 1.0,
		"ball_boost_decay_rate": BALL_IMPACT_BASE_DECAY_RATE,
		"ball_min_boost": BALL_IMPACT_BASE_MIN_BOOST,
		"ball_serve_origin": "",
		"rally_speed_cap_bonus": 0.0,
		"player_collision_cooldown": 0.0,
		"boss_collision_cooldown": 0.0,
		"vertical_bounce_count": 0,
		"ball_spin_strength": 0.0,
		"ball_spin_direction": 0,
		"drive_ball_active": false,
		"drive_hit_boss": false,
		"drive_speed_increase": 0.0,
		"drive_text_timer_frames": 0.0,
		"smasher_wheel_speed_cap": 0.0,
		"commando_bowling_trap_guard_armed": false,
		"commando_bowling_trap_guard_source": "",
		"commando_bowling_trap_guard_knockback_power": 0.0,
		"commando_bowling_trap_guard_stun_frames": 0.0,
		"commando_bowling_trap_guard_restore_speed": 0.0,
		"commando_suicide_drone_ball_boost_active": false,
		"commando_suicide_drone_ball_restore_speed": 0.0,
		"commando_suicide_drone_ball_boosted_speed": 0.0,
		"blacksmith_umbrella_open": false,
		"blacksmith_umbrella_anim_timer": 0.0,
		"blacksmith_umbrella_retracting": false,
		"blacksmith_umbrella_anim_direction": 1,
		"blacksmith_umbrella_open_ratio": 0.0,
		"blacksmith_thor_shield_open_ratio": 0.0,
		"blacksmith_umbrella_raise_amount": 0.0,
		"blacksmith_umbrella_shield_open_amount": 0.0,
		"blacksmith_umbrella_visual_state": "closed",
		"blacksmith_umbrella_folded": true,
		"blacksmith_umbrella_deployed": false,
		"blacksmith_umbrella_swing_active": false,
		"blacksmith_umbrella_swing_direction": 0,
		"blacksmith_umbrella_swing_timer": 0.0,
		"blacksmith_umbrella_gauge": 5,
		"blacksmith_umbrella_gauge_max": 5,
		"blacksmith_umbrella_gauge_gain": 60.0,
		"blacksmith_umbrella_damage_flash_timer": 0.0,
		"blacksmith_umbrella_hit_pulse_timer": 0.0,
	}


func _build_serve_velocity(player_is_serving: bool, ball_physics: Object) -> Vector2:
	if ball_physics != null and ball_physics.has_method("build_serve_velocity"):
		var velocity: Variant = ball_physics.build_serve_velocity(player_is_serving)
		if velocity is Vector2:
			return velocity
	return Vector2.ZERO


func _apply_serve_launch_boost(snapshot: Dictionary, velocity: Vector2, ball_physics: Object) -> void:
	if ball_physics == null or not ball_physics.has_method("compute_serve_launch_impact_boost"):
		return
	var serve_impact: Variant = ball_physics.compute_serve_launch_impact_boost(velocity)
	if not (serve_impact is Dictionary):
		return
	snapshot["ball_impact_boost"] = float(serve_impact.get("boost", snapshot["ball_impact_boost"]))
	snapshot["ball_boost_decay_rate"] = float(serve_impact.get("decay_rate", snapshot["ball_boost_decay_rate"]))
	snapshot["ball_min_boost"] = float(serve_impact.get("min_boost", snapshot["ball_min_boost"]))
