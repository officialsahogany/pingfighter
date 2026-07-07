extends RefCounted

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")

const ITEM_POSEIDON_TRIDENT := "poseidon_trident"


func is_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_POSEIDON_TRIDENT)


func is_active(runtime: Object) -> bool:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_level(runtime) > 0
	return is_equipped(runtime)


func apply_wave_to_ball(
	runtime: Object,
	scene: Dictionary,
	fps_scale: float,
	deps: Dictionary,
	constants: Dictionary
) -> Dictionary:
	var ball_pos: Vector2 = runtime._get_vector2(scene.get("ball_pos", Vector2.ZERO))
	var ball_vel: Vector2 = runtime._get_vector2(scene.get("ball_vel", Vector2.ZERO))
	if runtime.poseidon_capture_active:
		return update_captured_ball(runtime, ball_pos, fps_scale, scene, deps, constants)
	if runtime.poseidon_water_trail_active:
		add_water_trail(runtime, ball_pos, constants)
	if not is_active(runtime):
		return {}
	if not runtime.poseidon_vortex_active:
		return {}
	if runtime.poseidon_vortex_timer_frames >= float(constants.get("vortex_hold_frames", 48.0)):
		return {}
	if ball_vel.y <= 0.0:
		return {}
	if runtime.poseidon_vortex_affected or runtime.poseidon_vortex_reentry_cooldown_frames > 0.0:
		return {}

	var vortex_hit: Dictionary = get_vortex_hit(runtime, ball_pos, constants)
	if vortex_hit.is_empty():
		return {}

	start_capture(runtime, ball_pos, ball_vel, vortex_hit, constants)
	runtime.audio_router.apply_poseidon_feedback(
		runtime,
		deps,
		float(constants.get("feedback_shake_amount", 0.16)) * 0.55,
		float(constants.get("feedback_shake_intensity", 4.8)) * 0.70
	)
	return update_captured_ball(runtime, ball_pos, fps_scale, scene, deps, constants)


func apply_boss_hit(runtime: Object, ball_vel: Vector2) -> Dictionary:
	if not runtime.poseidon_vortex_affected:
		return {}
	runtime.poseidon_vortex_affected = false
	runtime.poseidon_capture_active = false
	runtime.poseidon_water_trail_active = false
	runtime.poseidon_water_trail.clear()
	runtime.poseidon_vortex_reentry_cooldown_frames = 0.0
	return {
		"ball_vel": ball_vel * 0.5,
		"poseidon_trident_cleared": true,
	}


func get_cooldown(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_mythic_value(runtime, "cooldown")
	return clamp(runtime.roll_query.get_equipped_roll_value(runtime, ITEM_POSEIDON_TRIDENT, "cooldown"), 0.1, 30.0)


func get_gauge_cost(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_mythic_value(runtime, "gauge_cost")
	return clamp(runtime.roll_query.get_equipped_roll_value(runtime, ITEM_POSEIDON_TRIDENT, "gauge_cost"), 0.0, 100.0)


func get_vortex_size(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_mythic_value(runtime, "vortex_size")
	return clamp(runtime.roll_query.get_equipped_roll_value(runtime, ITEM_POSEIDON_TRIDENT, "vortex_size"), 60.0, 500.0)


func is_ball_motion_active(runtime: Object, constants: Dictionary) -> bool:
	if runtime.poseidon_capture_active or runtime.poseidon_water_trail_active:
		return true
	if not is_active(runtime):
		return false
	return (
		runtime.poseidon_vortex_active
		and runtime.poseidon_vortex_timer_frames < float(constants.get("vortex_hold_frames", 48.0))
		and not runtime.poseidon_vortex_affected
		and runtime.poseidon_vortex_reentry_cooldown_frames <= 0.0
	)


func clear_runtime(runtime: Object) -> void:
	runtime.poseidon_effect_cooldown_frames = 0.0
	runtime.poseidon_vortex_active = false
	runtime.poseidon_vortex_timer_frames = 0.0
	runtime.poseidon_vortex_left_pos = Vector2.ZERO
	runtime.poseidon_vortex_right_pos = Vector2.ZERO
	runtime.poseidon_vortex_left_height = 0.0
	runtime.poseidon_vortex_right_height = 0.0
	runtime.poseidon_vortex_spin_speed = 0.0
	runtime.poseidon_vortex_reentry_cooldown_frames = 0.0
	runtime.poseidon_vortex_affected = false
	runtime.poseidon_dash_was_active = false
	runtime.poseidon_dash_was_recovering = false
	runtime.poseidon_last_dash_direction = 0.0
	runtime.poseidon_particles.clear()
	runtime.poseidon_water_trail.clear()
	runtime.poseidon_water_trail_active = false
	runtime.poseidon_explosion_active = false
	runtime.poseidon_explosion_timer = 0.0
	runtime.poseidon_explosion_particles.clear()
	runtime.poseidon_capture_active = false
	runtime.poseidon_capture_timer_frames = 0.0
	runtime.poseidon_capture_duration_frames = 0.0
	runtime.poseidon_capture_base_pos = Vector2.ZERO
	runtime.poseidon_capture_start_angle = 0.0
	runtime.poseidon_capture_radius = 0.0
	runtime.poseidon_capture_turns = 0.0
	runtime.poseidon_capture_spin_sign = 1.0
	runtime.poseidon_capture_original_speed = 0.0
	runtime.poseidon_capture_last_pos = Vector2.ZERO


func poll_idle_dash_trigger(runtime: Object, owner: Object, registry: Object) -> void:
	if not is_active(runtime):
		return
	update_dash_trigger(runtime, owner, registry)
	if runtime.update_gate.has_transient_runtime_update_work(runtime):
		runtime._sync_owner(owner, registry)


func update_runtime(
	runtime: Object,
	owner: Object,
	registry: Object,
	fps_scale: float,
	constants: Dictionary
) -> void:
	runtime.poseidon_player_center = runtime.owner_syncer.read_owner_player_center(runtime, owner)
	var was_cooling: bool = runtime.poseidon_effect_cooldown_frames > 0.0
	if runtime.poseidon_effect_cooldown_frames > 0.0:
		runtime.poseidon_effect_cooldown_frames = max(0.0, runtime.poseidon_effect_cooldown_frames - fps_scale)
	if (
		was_cooling
		and runtime.poseidon_effect_cooldown_frames <= 0.0
		and is_active(runtime)
	):
		start_water_explosion(runtime, constants)
		runtime.audio_router.play_poseidon_charge_audio(runtime, registry)
	if runtime.poseidon_vortex_reentry_cooldown_frames > 0.0:
		runtime.poseidon_vortex_reentry_cooldown_frames = max(
			0.0,
			runtime.poseidon_vortex_reentry_cooldown_frames - fps_scale
		)
	update_dash_trigger(runtime, owner, registry)
	update_vortex(runtime, fps_scale, constants)
	update_particles(runtime, fps_scale, constants)
	update_water_trail(runtime, fps_scale, constants)
	update_water_explosion(runtime, fps_scale, constants)


func update_dash_trigger(runtime: Object, owner: Object, registry: Object) -> void:
	var dash_state: Object = runtime._get_instance(registry, "smasher_dash_state")
	var active := false
	var recovering := false
	var direction := 0.0
	if dash_state != null and dash_state.has_method("get_snapshot"):
		var snapshot: Dictionary = dash_state.get_snapshot()
		active = bool(snapshot.get("active", false))
		recovering = bool(snapshot.get("recovering", false))
		direction = float(snapshot.get("direction", 0.0))
	if abs(direction) > 0.01:
		runtime.poseidon_last_dash_direction = direction

	var just_started_recovery: bool = recovering and not runtime.poseidon_dash_was_recovering and runtime.poseidon_dash_was_active
	if is_active(runtime) and just_started_recovery:
		var trigger_direction: float = direction
		if abs(trigger_direction) <= 0.01:
			trigger_direction = runtime.poseidon_last_dash_direction
		try_trigger_vortex(runtime, owner, registry, trigger_direction, {})

	runtime.poseidon_dash_was_active = active
	runtime.poseidon_dash_was_recovering = recovering


func try_trigger_vortex(
	runtime: Object,
	owner: Object,
	registry: Object,
	direction: float,
	constants: Dictionary
) -> bool:
	if not is_active(runtime):
		return false
	if runtime.poseidon_effect_cooldown_frames > 0.0:
		return false
	var gauge_cost: float = get_gauge_cost(runtime)
	var current_gauge: float = float(runtime._safe_owner_get(owner, "special_gauge", 0.0))
	if current_gauge < gauge_cost:
		return false
	if owner != null:
		owner.set("special_gauge", max(0.0, current_gauge - gauge_cost))
	runtime.poseidon_effect_cooldown_frames = get_cooldown(runtime) * 60.0
	start_vortex(runtime, owner, direction, constants)
	runtime.audio_router.play_poseidon_wave_audio(runtime, registry)
	runtime.audio_router.apply_poseidon_feedback(
		runtime,
		{"registry": registry},
		float(constants.get("feedback_shake_amount", 0.16)) * 0.65,
		float(constants.get("feedback_shake_intensity", 4.8)) * 0.75
	)
	if owner != null and owner.has_method("request_battle_redraw"):
		owner.request_battle_redraw()
	elif owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()
	return true


func start_vortex(runtime: Object, owner: Object, direction: float, constants: Dictionary) -> void:
	var player_pos: Vector2 = runtime._get_vector2(runtime._safe_owner_get(owner, "player_pos", Vector2.ZERO))
	var player_size := Vector2(
		float(runtime._safe_owner_get(owner, "player_paddle_width", 155.0)),
		float(runtime._safe_owner_get(owner, "player_paddle_height", 50.0))
	)
	var anchor: Vector2 = player_pos + Vector2(player_size.x * 0.5, player_size.y * 0.5)
	var offset_x: float = float(constants.get("vortex_offset_x", 120.0))
	runtime.poseidon_vortex_left_pos = anchor + Vector2(-offset_x, 0.0)
	runtime.poseidon_vortex_right_pos = anchor + Vector2(offset_x, 0.0)
	runtime.poseidon_vortex_left_height = 0.0
	runtime.poseidon_vortex_right_height = 0.0
	runtime.poseidon_vortex_spin_speed = 0.0
	runtime.poseidon_vortex_timer_frames = 0.0
	runtime.poseidon_vortex_active = true
	runtime.poseidon_vortex_reentry_cooldown_frames = 0.0
	runtime.poseidon_vortex_affected = false
	runtime.poseidon_water_trail.clear()
	runtime.poseidon_water_trail_active = false
	if abs(direction) > 0.01:
		runtime.poseidon_last_dash_direction = direction
	runtime.poseidon_particles.clear()
	spawn_particles(runtime, int(constants.get("initial_particles_per_side", 18)), true, constants)


func update_vortex(runtime: Object, fps_scale: float, constants: Dictionary) -> void:
	if not runtime.poseidon_vortex_active:
		return
	runtime.poseidon_vortex_timer_frames += fps_scale
	var max_height: float = float(constants.get("vortex_max_height", 350.0))
	var grow_frames: float = float(constants.get("vortex_grow_frames", 18.0))
	var hold_frames: float = float(constants.get("vortex_hold_frames", 48.0))
	var total_frames: float = float(constants.get("vortex_total_frames", 96.0))
	if runtime.poseidon_vortex_timer_frames < grow_frames:
		var growth: float = clamp(runtime.poseidon_vortex_timer_frames / grow_frames, 0.0, 1.0)
		runtime.poseidon_vortex_left_height = max_height * growth
		runtime.poseidon_vortex_right_height = max_height * growth
		runtime.poseidon_vortex_spin_speed = 10.0 * growth
	elif runtime.poseidon_vortex_timer_frames < hold_frames:
		runtime.poseidon_vortex_left_height = max_height
		runtime.poseidon_vortex_right_height = max_height
		runtime.poseidon_vortex_spin_speed = 10.0
	elif runtime.poseidon_vortex_timer_frames < total_frames:
		var fade: float = 1.0 - (runtime.poseidon_vortex_timer_frames - hold_frames) / (total_frames - hold_frames)
		runtime.poseidon_vortex_left_height = max_height * clamp(fade, 0.0, 1.0)
		runtime.poseidon_vortex_right_height = max_height * clamp(fade, 0.0, 1.0)
		runtime.poseidon_vortex_spin_speed = 10.0 * clamp(fade, 0.0, 1.0)
	else:
		runtime.poseidon_vortex_active = false
		runtime.poseidon_vortex_left_height = 0.0
		runtime.poseidon_vortex_right_height = 0.0

	if (
		runtime.poseidon_vortex_active
		and runtime.poseidon_vortex_timer_frames < hold_frames
		and runtime.poseidon_particles.size() < int(constants.get("max_particles", 84))
	):
		spawn_particles(runtime, 2, false, constants)


func spawn_particles(
	runtime: Object,
	count_per_side: int,
	initial_burst: bool,
	constants: Dictionary
) -> void:
	for side in [-1, 1]:
		for _i in range(count_per_side):
			if runtime.poseidon_particles.size() >= int(constants.get("max_particles", 84)):
				return
			runtime.poseidon_particles.append(make_particle(runtime, side, initial_burst, constants))


func make_particle(runtime: Object, side: int, initial_burst: bool, _constants: Dictionary) -> Dictionary:
	var width: float = get_vortex_size(runtime)
	var center_pos: Vector2 = runtime.poseidon_vortex_left_pos if side < 0 else runtime.poseidon_vortex_right_pos
	var spawn_x: float
	var spawn_y: float
	var spiral_radius: float
	var life: float
	if initial_burst:
		var particle_spread: float = width * 0.15
		var spiral_max: float = max(20.0, width * 0.30)
		var height_offset: float = randf_range(0.0, width)
		spawn_x = center_pos.x + randf_range(-particle_spread, particle_spread)
		spawn_y = center_pos.y - height_offset
		spiral_radius = randf_range(20.0, spiral_max)
		life = float(randi_range(40, 80))
	else:
		spawn_x = center_pos.x + randf_range(-50.0, 50.0)
		spawn_y = center_pos.y + randf_range(-20.0, 20.0)
		spiral_radius = randf_range(20.0, 60.0)
		life = float(randi_range(30, 60))
	return {
		"side": side,
		"x": spawn_x,
		"y": spawn_y,
		"spiral_angle": randf_range(0.0, TAU),
		"spiral_radius": spiral_radius,
		"size": randf_range(3.0, 10.0),
		"life": life,
		"max_life": life,
		"color": Color(50.0 / 255.0, (150.0 + randf_range(0.0, 100.0)) / 255.0, 1.0),
	}


func update_particles(runtime: Object, fps_scale: float, constants: Dictionary) -> void:
	if runtime.poseidon_particles.is_empty():
		return
	var radius_decay: float = pow(float(constants.get("particle_radius_decay", 0.98)), fps_scale)
	var write_index := 0
	for read_index in range(runtime.poseidon_particles.size()):
		var particle: Dictionary = runtime._get_dict(runtime.poseidon_particles[read_index])
		var remaining: float = float(particle.get("life", 0.0)) - fps_scale
		if remaining <= 0.0:
			continue
		particle["life"] = remaining
		var side: int = int(particle.get("side", -1))
		var center_pos: Vector2 = runtime.poseidon_vortex_left_pos if side < 0 else runtime.poseidon_vortex_right_pos
		var angle: float = float(particle.get("spiral_angle", 0.0)) + runtime.poseidon_vortex_spin_speed * 0.1 * fps_scale
		var radius: float = float(particle.get("spiral_radius", 0.0)) * radius_decay
		particle["spiral_angle"] = angle
		particle["spiral_radius"] = radius
		particle["x"] = center_pos.x + cos(angle) * radius
		particle["y"] = float(particle.get("y", 0.0)) - float(constants.get("particle_rise_speed", 3.0)) * fps_scale
		particle["size"] = float(particle.get("size", 0.0)) * radius_decay
		runtime.poseidon_particles[write_index] = particle
		write_index += 1
	if write_index < runtime.poseidon_particles.size():
		runtime.poseidon_particles.resize(write_index)


func update_water_trail(runtime: Object, fps_scale: float, constants: Dictionary) -> void:
	if runtime.poseidon_water_trail.is_empty():
		return
	var write_index := 0
	for read_index in range(runtime.poseidon_water_trail.size()):
		var droplet: Dictionary = runtime._get_dict(runtime.poseidon_water_trail[read_index])
		var remaining: float = float(droplet.get("life", 0.0)) - fps_scale
		if remaining <= 0.0:
			continue
		droplet["life"] = remaining
		droplet["x"] = float(droplet.get("x", 0.0)) + float(droplet.get("vx", 0.0)) * fps_scale
		droplet["y"] = float(droplet.get("y", 0.0)) + float(droplet.get("vy", 0.0)) * fps_scale
		droplet["vy"] = float(droplet.get("vy", 0.0)) + float(constants.get("droplet_gravity", 0.5)) * fps_scale
		runtime.poseidon_water_trail[write_index] = droplet
		write_index += 1
	if write_index < runtime.poseidon_water_trail.size():
		runtime.poseidon_water_trail.resize(write_index)
	if runtime.poseidon_water_trail.is_empty():
		runtime.poseidon_water_trail_active = false


func add_water_trail(runtime: Object, ball_pos: Vector2, constants: Dictionary) -> void:
	if randf() >= float(constants.get("droplet_spawn_chance", 0.35)):
		return
	var count: int = randi_range(
		int(constants.get("droplet_min_per_tick", 1)),
		int(constants.get("droplet_max_per_tick", 3))
	)
	for _i in range(count):
		if runtime.poseidon_water_trail.size() >= int(constants.get("water_trail_max_points", 24)):
			break
		runtime.poseidon_water_trail.append({
			"x": ball_pos.x + randf_range(-8.0, 8.0),
			"y": ball_pos.y + randf_range(-8.0, 8.0),
			"vx": randf_range(-3.0, 3.0),
			"vy": randf_range(-2.0, 2.0),
			"size": randf_range(3.0, 6.0),
			"life": float(constants.get("water_trail_life_frames", 30.0)),
			"max_life": float(constants.get("water_trail_life_frames", 30.0)),
		})


func start_water_explosion(runtime: Object, constants: Dictionary) -> void:
	runtime.poseidon_explosion_active = true
	runtime.poseidon_explosion_timer = 0.0
	runtime.poseidon_explosion_particles.clear()
	var count: int = int(constants.get("explosion_particle_count", 8))
	for i in range(count):
		var angle: float = float(i) / float(count) * TAU + randf_range(-0.2, 0.2)
		var speed: float = randf_range(60.0, 90.0)
		runtime.poseidon_explosion_particles.append({
			"offset_x": 0.0,
			"offset_y": 0.0,
			"vx": cos(angle) * speed,
			"vy": sin(angle) * speed,
			"size": randf_range(12.0, 24.0),
			"life": randf_range(1.2, 2.0),
			"max_life": 2.0,
			"color": Color(
				(100.0 + randf_range(0.0, 40.0)) / 255.0,
				(190.0 + randf_range(0.0, 50.0)) / 255.0,
				(240.0 + randf_range(0.0, 15.0)) / 255.0
			),
		})


func update_water_explosion(runtime: Object, fps_scale: float, constants: Dictionary) -> void:
	if not runtime.poseidon_explosion_active:
		return
	var dt: float = fps_scale / 60.0
	runtime.poseidon_explosion_timer += dt
	var damp: float = pow(float(constants.get("explosion_vel_damp", 0.92)), fps_scale)
	var write_index := 0
	for read_index in range(runtime.poseidon_explosion_particles.size()):
		var p: Dictionary = runtime._get_dict(runtime.poseidon_explosion_particles[read_index])
		var life: float = float(p.get("life", 0.0)) - dt
		if life <= 0.0:
			continue
		p["life"] = life
		p["offset_x"] = float(p.get("offset_x", 0.0)) + float(p.get("vx", 0.0)) * dt
		p["offset_y"] = float(p.get("offset_y", 0.0)) + float(p.get("vy", 0.0)) * dt
		p["vx"] = float(p.get("vx", 0.0)) * damp
		p["vy"] = float(p.get("vy", 0.0)) * damp
		runtime.poseidon_explosion_particles[write_index] = p
		write_index += 1
	if write_index < runtime.poseidon_explosion_particles.size():
		runtime.poseidon_explosion_particles.resize(write_index)
	if runtime.poseidon_explosion_particles.is_empty():
		runtime.poseidon_explosion_active = false


func start_capture(
	runtime: Object,
	ball_pos: Vector2,
	ball_vel: Vector2,
	vortex_hit: Dictionary,
	constants: Dictionary
) -> void:
	runtime.poseidon_capture_active = true
	runtime.poseidon_capture_timer_frames = 0.0
	runtime.poseidon_capture_duration_frames = float(constants.get("capture_duration_frames", 34.0))
	runtime.poseidon_capture_base_pos = runtime._get_vector2(vortex_hit.get("pos", ball_pos))
	runtime.poseidon_capture_start_angle = atan2(
		ball_pos.y - runtime.poseidon_capture_base_pos.y,
		ball_pos.x - runtime.poseidon_capture_base_pos.x
	)
	var min_radius: float = float(constants.get("capture_min_radius", 42.0))
	runtime.poseidon_capture_radius = clamp(
		(ball_pos - runtime.poseidon_capture_base_pos).length(),
		min_radius,
		max(min_radius, get_vortex_size(runtime) * 0.50)
	)
	runtime.poseidon_capture_turns = randf_range(
		float(constants.get("capture_min_turns", 2.0)),
		float(constants.get("capture_max_turns", 3.0))
	)
	runtime.poseidon_capture_spin_sign = -1.0 if str(vortex_hit.get("side", "left")) == "left" else 1.0
	runtime.poseidon_capture_original_speed = max(ball_vel.length(), float(constants.get("reflect_min_speed", 18.0)))
	runtime.poseidon_capture_last_pos = ball_pos
	runtime.poseidon_water_trail_active = true
	add_water_trail(runtime, ball_pos, constants)


func update_captured_ball(
	runtime: Object,
	ball_pos: Vector2,
	fps_scale: float,
	scene: Dictionary,
	deps: Dictionary,
	constants: Dictionary
) -> Dictionary:
	if not runtime.poseidon_capture_active:
		return {}
	runtime.poseidon_capture_timer_frames = min(
		runtime.poseidon_capture_duration_frames,
		runtime.poseidon_capture_timer_frames + max(0.0, fps_scale)
	)
	var progress: float = clamp(
		runtime.poseidon_capture_timer_frames / max(1.0, runtime.poseidon_capture_duration_frames),
		0.0,
		1.0
	)
	var next_pos: Vector2 = get_capture_position(runtime, progress, constants)
	var previous_pos: Vector2 = runtime.poseidon_capture_last_pos if runtime.poseidon_capture_last_pos != Vector2.ZERO else ball_pos
	var capture_vel: Vector2 = (next_pos - previous_pos) / max(0.001, fps_scale)
	runtime.poseidon_capture_last_pos = next_pos
	add_water_trail(runtime, next_pos, constants)

	if progress >= 1.0:
		var release_vel: Vector2 = build_release_velocity(runtime, constants)
		runtime.poseidon_capture_active = false
		runtime.poseidon_vortex_affected = true
		runtime.poseidon_vortex_reentry_cooldown_frames = float(constants.get("reentry_cooldown_frames", 60.0))
		runtime.audio_router.apply_poseidon_feedback(
			runtime,
			deps,
			float(constants.get("feedback_shake_amount", 0.16)),
			float(constants.get("feedback_shake_intensity", 4.8))
		)
		return {
			"ball_pos": next_pos,
			"ball_vel": release_vel,
			"skip_ball_motion_step": false,
			"ball_impact_boost": max(float(constants.get("capture_release_boost", 1.35)), float(scene.get("ball_impact_boost", 1.0))),
			"poseidon_trident_released": true,
			"poseidon_trident_capture_progress": progress,
		}

	return {
		"ball_pos": next_pos,
		"ball_vel": capture_vel,
		"skip_ball_motion_step": true,
		"ball_impact_boost": 1.0,
		"poseidon_trident_captured": true,
		"poseidon_trident_capture_progress": progress,
	}


func get_capture_position(runtime: Object, progress: float, constants: Dictionary) -> Vector2:
	var t: float = clamp(progress, 0.0, 1.0)
	var eased_up: float = 1.0 - pow(1.0 - t, 1.35)
	var rise_height: float = min(
		float(constants.get("vortex_max_height", 350.0)) * 0.72,
		max(170.0, get_vortex_size(runtime) * 1.18)
	)
	var radius: float = lerp(runtime.poseidon_capture_radius, max(22.0, runtime.poseidon_capture_radius * 0.45), t)
	var angle: float = runtime.poseidon_capture_start_angle + runtime.poseidon_capture_spin_sign * TAU * runtime.poseidon_capture_turns * t
	var center: Vector2 = runtime.poseidon_capture_base_pos + Vector2(0.0, -rise_height * eased_up)
	return center + Vector2(cos(angle) * radius, sin(angle) * radius * 0.62)


func build_release_velocity(runtime: Object, constants: Dictionary) -> Vector2:
	var speed: float = clamp(
		runtime.poseidon_capture_original_speed * randf_range(1.55, 1.95),
		float(constants.get("reflect_min_speed", 18.0)),
		float(constants.get("reflect_max_speed", 34.0))
	)
	var angle: float = -PI * 0.5 + randf_range(
		-float(constants.get("capture_release_spread", PI / 4.0)),
		float(constants.get("capture_release_spread", PI / 4.0))
	)
	var velocity := Vector2(cos(angle), sin(angle)) * speed
	if velocity.y > -float(constants.get("reflect_min_upward_speed", 14.0)):
		velocity.y = -float(constants.get("reflect_min_upward_speed", 14.0))
	velocity.x = clamp(
		velocity.x,
		-float(constants.get("reflect_max_x_speed", 24.0)),
		float(constants.get("reflect_max_x_speed", 24.0))
	)
	return velocity


func get_vortex_hit(runtime: Object, ball_pos: Vector2, constants: Dictionary) -> Dictionary:
	var width: float = get_vortex_size(runtime)
	var half_width: float = width * 0.5
	var candidates: Array = [
		{"side": "left", "pos": runtime.poseidon_vortex_left_pos, "height": runtime.poseidon_vortex_left_height},
		{"side": "right", "pos": runtime.poseidon_vortex_right_pos, "height": runtime.poseidon_vortex_right_height},
	]
	for candidate_value in candidates:
		var candidate: Dictionary = runtime._get_dict(candidate_value)
		var base: Vector2 = runtime._get_vector2(candidate.get("pos", Vector2.ZERO))
		var height: float = min(float(candidate.get("height", 0.0)), float(constants.get("vortex_max_height", 350.0)))
		if height <= 1.0:
			continue
		var x_in_vortex: bool = abs(ball_pos.x - base.x) <= half_width
		var y_in_vortex: bool = ball_pos.y >= base.y - height - 20.0 and ball_pos.y <= base.y + 100.0
		if x_in_vortex and y_in_vortex:
			return candidate
	return {}


func _get_converted_mythic_value(runtime: Object, key: String) -> float:
	if _get_converted_perk_level(runtime) <= 0:
		return 0.0
	return PerkConversionValues.get_mythic_value(ITEM_POSEIDON_TRIDENT, key)


func _get_converted_perk_level(runtime: Object) -> int:
	if runtime != null and runtime.has_method("get_converted_perk_effect_level"):
		return max(0, int(runtime.get_converted_perk_effect_level(ITEM_POSEIDON_TRIDENT)))
	return 0
