extends RefCounted

const CommandoFirearmAudioDispatcher := preload("res://scripts/characters/commando_firearm_audio_dispatcher.gd")
const CommandoFirearmHitFeedbackDispatcher := preload("res://scripts/characters/commando_firearm_hit_feedback_dispatcher.gd")
const CommandoFirearmImpactFlashResolver := preload("res://scripts/characters/commando_firearm_impact_flash_resolver.gd")
const CommandoFirearmProfileResolver := preload("res://scripts/characters/commando_firearm_profile_resolver.gd")
const CommandoFirearmProjectileSpawnState := preload("res://scripts/characters/commando_firearm_projectile_spawn_state.gd")
const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")


static func append_install_effects(
	bowling_traps: Array,
	impact_flashes: Array,
	config: Dictionary,
	profile: Dictionary,
	weapon_id: String,
	trap_id: int,
	field_width: float,
	field_height: float,
	trap_width: float,
	trap_height: float,
	min_field_y_ratio: float,
	install_frames: float,
	capture_ball_offset: Vector2,
	trap_limit: int,
	flash_limit: int
) -> Dictionary:
	var trap_pos: Vector2 = get_install_pos(
		config,
		field_width,
		field_height,
		trap_width,
		trap_height,
		min_field_y_ratio
	)
	var trap: Dictionary = build_install_trap(
		trap_pos,
		profile,
		weapon_id,
		trap_id,
		trap_width,
		trap_height,
		install_frames,
		capture_ball_offset
	)
	CommandoFirearmValueUtils.append_limited(bowling_traps, trap, trap_limit)
	CommandoFirearmValueUtils.append_limited(
		impact_flashes,
		build_install_marker_flash(trap_pos, profile, weapon_id),
		flash_limit
	)
	return trap


static func append_runtime_install_effects(
	bowling_traps: Array,
	impact_flashes: Array,
	runtime_owner: Object,
	config: Dictionary,
	profile: Dictionary,
	weapon_id: String,
	field_width: float,
	field_height: float,
	trap_width: float,
	trap_height: float,
	min_field_y_ratio: float,
	install_frames: float,
	capture_ball_offset: Vector2,
	trap_limit: int,
	flash_limit: int
) -> Dictionary:
	var trap_id: int = CommandoFirearmProjectileSpawnState.claim_next_shot_id(runtime_owner)
	return append_install_effects(
		bowling_traps,
		impact_flashes,
		config,
		profile,
		weapon_id,
		trap_id,
		field_width,
		field_height,
		trap_width,
		trap_height,
		min_field_y_ratio,
		install_frames,
		capture_ball_offset,
		trap_limit,
		flash_limit
	)


static func get_install_pos(
	config: Dictionary,
	field_width: float,
	field_height: float,
	trap_width: float,
	trap_height: float,
	min_field_y_ratio: float
) -> Vector2:
	var fallback_player_pos := Vector2(field_width * 0.5, field_height - 70.0)
	var player_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(config.get("player_pos", fallback_player_pos), fallback_player_pos)
	var paddle_width: float = max(1.0, float(config.get("paddle_width", 155.0)))
	var paddle_height: float = max(1.0, float(config.get("paddle_height", 50.0)))
	var trap_y: float = player_pos.y + paddle_height + 5.0
	var min_y: float = field_height * min_field_y_ratio
	return Vector2(
		clamp(player_pos.x + paddle_width * 0.5, trap_width * 0.5, field_width - trap_width * 0.5),
		clamp(max(trap_y, min_y), min_y, field_height - trap_height * 0.5)
	)


static func is_install_in_player_field(
	config: Dictionary,
	field_width: float,
	field_height: float,
	min_field_y_ratio: float
) -> bool:
	var fallback_player_pos := Vector2(field_width * 0.5, field_height - 70.0)
	var player_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(config.get("player_pos", fallback_player_pos), fallback_player_pos)
	var paddle_height: float = max(1.0, float(config.get("paddle_height", 50.0)))
	var trap_y: float = player_pos.y + paddle_height + 5.0
	return trap_y >= field_height * min_field_y_ratio


static func build_install_trap(
	trap_pos: Vector2,
	profile: Dictionary,
	weapon_id: String,
	trap_id: int,
	trap_width: float,
	trap_height: float,
	install_frames: float,
	capture_ball_offset: Vector2
) -> Dictionary:
	return {
		"id": trap_id,
		"weapon_id": weapon_id,
		"kind": "bowling_trap",
		"state": "installing",
		"pos": trap_pos,
		"width": trap_width,
		"height": trap_height,
		"timer_frames": install_frames,
		"max_timer_frames": install_frames,
		"install_progress": 0.0,
		"capture_progress": 0.0,
		"claw_angle": 1.0,
		"captured_ball_pos": trap_pos + capture_ball_offset,
		"captured_original_speed": 0.0,
		"captured_original_vel": Vector2.ZERO,
		"launch_direction": 0,
		"color": profile.get("color", Color(0.95, 0.18, 0.24)),
		"secondary": profile.get("secondary", Color(0.22, 0.10, 0.12)),
	}


static func build_install_marker_flash(trap_pos: Vector2, profile: Dictionary, weapon_id: String) -> Dictionary:
	return {
		"weapon_id": weapon_id,
		"kind": "trap_install_marker",
		"pos": trap_pos,
		"radius": 24.0,
		"timer_frames": 14.0,
		"max_timer_frames": 14.0,
		"color": profile.get("secondary", Color(0.22, 0.10, 0.12)),
		"secondary": profile.get("color", Color(0.95, 0.18, 0.24)),
	}


static func update_install_state(trap: Dictionary, fps_scale: float, install_frames: float) -> Dictionary:
	var next_trap: Dictionary = trap.duplicate(true)
	var timer: float = max(0.0, float(next_trap.get("timer_frames", install_frames)) - fps_scale)
	next_trap["timer_frames"] = timer
	next_trap["max_timer_frames"] = install_frames
	next_trap["install_progress"] = 1.0 - timer / install_frames
	if timer <= 0.0:
		next_trap["state"] = "waiting"
		next_trap["timer_frames"] = 0.0
		next_trap["max_timer_frames"] = 1.0
		next_trap["install_progress"] = 1.0
		next_trap["claw_angle"] = 0.0
	return next_trap


static func has_installing_trap(traps: Array) -> bool:
	for value in traps:
		var trap: Dictionary = CommandoFirearmValueUtils.get_dict(value)
		if str(trap.get("state", "")) == "installing":
			return true
	return false


static func get_install_progress(traps: Array) -> float:
	for value in traps:
		var trap: Dictionary = CommandoFirearmValueUtils.get_dict(value)
		if str(trap.get("state", "")) == "installing":
			return clamp(float(trap.get("install_progress", 0.0)), 0.0, 1.0)
	return 0.0


static func build_round_carryover(traps: Array, capture_ball_offset: Vector2) -> Array:
	var carried: Array = []
	for value in traps:
		var trap: Dictionary = CommandoFirearmValueUtils.get_dict(value)
		var state: String = str(trap.get("state", "waiting"))
		if state == "inactive" or state == "launching":
			continue
		var normalized: Dictionary = trap.duplicate(true)
		normalized["state"] = "waiting"
		normalized["timer_frames"] = 0.0
		normalized["max_timer_frames"] = 1.0
		normalized["install_progress"] = 1.0
		normalized["capture_progress"] = 0.0
		normalized["claw_angle"] = 0.0
		normalized["captured_original_speed"] = 0.0
		normalized["captured_original_vel"] = Vector2.ZERO
		var trap_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(normalized.get("pos", Vector2.ZERO), Vector2.ZERO)
		normalized["captured_ball_pos"] = trap_pos + capture_ball_offset
		carried.append(normalized)
	return carried


static func build_capture_state(
	trap: Dictionary,
	context: Dictionary,
	capture_frames: float,
	capture_ball_offset: Vector2
) -> Dictionary:
	var next_trap: Dictionary = trap.duplicate(true)
	var ball_vel: Vector2 = CommandoFirearmValueUtils.get_vector2(context.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	var trap_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(next_trap.get("pos", Vector2.ZERO), Vector2.ZERO)
	var original_speed: float = max(1.0, ball_vel.length())
	next_trap["state"] = "capturing"
	next_trap["timer_frames"] = capture_frames
	next_trap["max_timer_frames"] = capture_frames
	next_trap["capture_progress"] = 0.0
	next_trap["claw_angle"] = 1.0
	next_trap["captured_ball_pos"] = trap_pos + capture_ball_offset
	next_trap["captured_original_speed"] = original_speed
	next_trap["captured_original_vel"] = ball_vel
	next_trap["launch_direction"] = roll_launch_direction()
	return next_trap


static func update_capture_state(trap: Dictionary, fps_scale: float, capture_frames: float) -> Dictionary:
	var next_trap: Dictionary = trap.duplicate(true)
	var timer: float = max(0.0, float(next_trap.get("timer_frames", capture_frames)) - fps_scale)
	var progress: float = 1.0 - timer / capture_frames
	next_trap["timer_frames"] = timer
	next_trap["max_timer_frames"] = capture_frames
	next_trap["capture_progress"] = progress
	if progress < 0.2:
		next_trap["claw_angle"] = 1.0 - progress / 0.2
	elif progress < 0.5:
		next_trap["claw_angle"] = 0.0
	else:
		next_trap["claw_angle"] = -0.3 * ((progress - 0.5) / 0.5)
	return next_trap


static func is_capture_complete(trap: Dictionary) -> bool:
	return float(trap.get("timer_frames", 0.0)) <= 0.0


static func build_capture_result(trap: Dictionary) -> Dictionary:
	var captured_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(
		trap.get("captured_ball_pos", Vector2.ZERO),
		Vector2.ZERO
	)
	return {
		"ball_pos": captured_pos,
		"ball_vel": Vector2.ZERO,
		"skip_ball_motion_step": true,
		"commando_bowling_trap_captured": true,
		"commando_bowling_trap_capture_progress": float(trap.get("capture_progress", 0.0)),
	}


static func build_release_motion(
	trap: Dictionary,
	capture_ball_offset: Vector2,
	launch_speed_multiplier: float,
	launch_fan_half_angle: float
) -> Dictionary:
	var trap_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(trap.get("pos", Vector2.ZERO), Vector2.ZERO)
	var captured_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(
		trap.get("captured_ball_pos", trap_pos + capture_ball_offset),
		trap_pos + capture_ball_offset
	)
	var original_speed: float = max(1.0, float(trap.get("captured_original_speed", 0.0)))
	var launch_speed: float = original_speed * launch_speed_multiplier
	# launch_direction is a continuous random multiplier in [-1, 1] (rolled at capture); the
	# ball fires upward (toward the boss) within +/-launch_fan_half_angle of vertical.
	var launch_direction: float = clampf(float(trap.get("launch_direction", 0.0)), -1.0, 1.0)
	var launch_angle: float = -PI * 0.5 + launch_direction * launch_fan_half_angle
	var launch_vel: Vector2 = Vector2(cos(launch_angle), sin(launch_angle)) * launch_speed
	return {
		"trap_pos": trap_pos,
		"captured_pos": captured_pos,
		"original_speed": original_speed,
		"launch_speed": launch_speed,
		"launch_direction": launch_direction,
		"launch_angle": launch_angle,
		"launch_vel": launch_vel,
	}


static func build_release_pseudo_projectile(trap: Dictionary, motion: Dictionary, profile: Dictionary) -> Dictionary:
	return {
		"id": int(trap.get("id", 0)),
		"weapon_id": "bowling_trap",
		"kind": "trap",
		"pos": CommandoFirearmValueUtils.get_vector2(motion.get("trap_pos", Vector2.ZERO), Vector2.ZERO),
		"velocity": CommandoFirearmValueUtils.get_vector2(motion.get("launch_vel", Vector2.ZERO), Vector2.ZERO),
		"impact_radius": float(profile.get("impact_radius", 30.0)) * 1.5,
		"color": profile.get("color", Color(0.95, 0.18, 0.24)),
		"secondary": profile.get("secondary", Color(0.22, 0.10, 0.12)),
	}


static func build_release_result(
	motion: Dictionary,
	guard_source: String,
	guard_knockback_power: float,
	guard_stun_frames: float,
	guard_speed_reduction: float
) -> Dictionary:
	var captured_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(
		motion.get("captured_pos", Vector2.ZERO),
		Vector2.ZERO
	)
	var launch_vel: Vector2 = CommandoFirearmValueUtils.get_vector2(
		motion.get("launch_vel", Vector2.ZERO),
		Vector2.ZERO
	)
	var original_speed: float = max(1.0, float(motion.get("original_speed", 0.0)))
	return {
		"ball_pos": captured_pos,
		"ball_vel": launch_vel,
		"skip_ball_motion_step": false,
		"commando_bowling_trap_released": true,
		"commando_bowling_trap_guard_armed": true,
		"commando_bowling_trap_guard_source": guard_source,
		"commando_bowling_trap_launch_speed": float(motion.get("launch_speed", 0.0)),
		"commando_bowling_trap_guard_knockback_power": guard_knockback_power,
		"commando_bowling_trap_guard_stun_frames": guard_stun_frames,
		"commando_bowling_trap_guard_restore_speed": original_speed * guard_speed_reduction,
	}


static func build_release_payload(
	trap: Dictionary,
	profile: Dictionary,
	capture_ball_offset: Vector2,
	launch_speed_multiplier: float,
	launch_fan_half_angle: float,
	guard_speed_reduction: float,
	guard_knockback_power: float,
	guard_stun_frames: float
) -> Dictionary:
	var motion: Dictionary = build_release_motion(
		trap,
		capture_ball_offset,
		launch_speed_multiplier,
		launch_fan_half_angle
	)
	var guard_state: Dictionary = build_guard_state(
		trap,
		float(motion.get("original_speed", 1.0)),
		guard_speed_reduction
	)
	return {
		"motion": motion,
		"pseudo_projectile": build_release_pseudo_projectile(trap, motion, profile),
		"guard_state": guard_state,
		"release_result": build_release_result(
			motion,
			str(guard_state.get("source", "")),
			guard_knockback_power,
			guard_stun_frames,
			guard_speed_reduction
		),
	}


static func advance_runtime_traps(
	traps: Array,
	context: Dictionary,
	step: float,
	profile: Dictionary,
	install_frames: float,
	capture_frames: float,
	capture_ball_offset: Vector2,
	trap_height: float,
	capture_height: float,
	trap_width: float,
	launch_speed_multiplier: float,
	launch_fan_half_angle: float,
	guard_speed_reduction: float,
	guard_knockback_power: float,
	guard_stun_frames: float
) -> Dictionary:
	var safe_step: float = max(0.0, step)
	var result: Dictionary = {}
	var events: Array = []
	for index in range(traps.size() - 1, -1, -1):
		var trap: Dictionary = CommandoFirearmValueUtils.get_dict(traps[index])
		var state: String = str(trap.get("state", "waiting"))
		if state == "installing":
			traps[index] = update_install_state(trap, safe_step, install_frames)
		elif state == "waiting":
			if result.is_empty() and hits_ball(trap, context, trap_height, capture_height, trap_width):
				var captured_trap: Dictionary = build_capture_state(
					trap,
					context,
					capture_frames,
					capture_ball_offset
				)
				traps[index] = captured_trap
				events.append({
					"type": "capture",
					"captured_pos": CommandoFirearmValueUtils.get_vector2(captured_trap.get("captured_ball_pos", Vector2.ZERO), Vector2.ZERO),
					"ball_vel": CommandoFirearmValueUtils.get_vector2(captured_trap.get("captured_original_vel", Vector2.ZERO), Vector2.ZERO),
				})
				result = build_capture_result(captured_trap)
		elif state == "capturing":
			var next_trap: Dictionary = update_capture_state(trap, safe_step, capture_frames)
			if is_capture_complete(next_trap):
				var release_payload: Dictionary = build_release_payload(
					next_trap,
					profile,
					capture_ball_offset,
					launch_speed_multiplier,
					launch_fan_half_angle,
					guard_speed_reduction,
					guard_knockback_power,
					guard_stun_frames
				)
				events.append({
					"type": "release",
					"release_payload": release_payload,
				})
				traps.remove_at(index)
				if result.is_empty():
					result = CommandoFirearmValueUtils.get_dict(release_payload.get("release_result", {}))
			else:
				traps[index] = next_trap
				if result.is_empty():
					result = build_capture_result(next_trap)
		elif state == "launching" or state == "inactive":
			traps.remove_at(index)
		else:
			traps[index] = trap
	return {
		"result": result,
		"events": events,
	}


static func dispatch_runtime_update_events(
	events: Array,
	impact_flashes: Array,
	runtime_owner: Object,
	context: Dictionary,
	deps: Dictionary,
	weapon_profiles: Dictionary,
	weapon_profile_overrides: Dictionary,
	weapon_hit_feedback: Dictionary,
	hit_feedback_profile_overrides: Dictionary,
	base_weapon_id: String,
	grenade_explosion_duration_frames: float,
	flash_limit: int
) -> void:
	for event_value in events:
		var event: Dictionary = CommandoFirearmValueUtils.get_dict(event_value)
		match str(event.get("type", "")):
			"capture":
				_dispatch_capture_event(
					event,
					deps,
					weapon_hit_feedback,
					hit_feedback_profile_overrides,
					base_weapon_id
				)
			"release":
				_dispatch_release_event(
					event,
					impact_flashes,
					runtime_owner,
					context,
					deps,
					weapon_profiles,
					weapon_profile_overrides,
					weapon_hit_feedback,
					hit_feedback_profile_overrides,
					base_weapon_id,
					grenade_explosion_duration_frames,
					flash_limit
				)


static func advance_runtime_bowling_traps(
	traps: Array,
	impact_flashes: Array,
	runtime_owner: Object,
	context: Dictionary,
	deps: Dictionary,
	fps_scale: float,
	weapon_profiles: Dictionary,
	weapon_profile_overrides: Dictionary,
	weapon_hit_feedback: Dictionary,
	hit_feedback_profile_overrides: Dictionary,
	base_weapon_id: String,
	grenade_explosion_duration_frames: float,
	flash_limit: int,
	install_frames: float,
	capture_frames: float,
	capture_ball_offset: Vector2,
	trap_height: float,
	capture_height: float,
	trap_width: float,
	launch_speed_multiplier: float,
	launch_fan_half_angle: float,
	guard_speed_reduction: float,
	guard_knockback_power: float,
	guard_stun_frames: float
) -> Dictionary:
	var step: float = max(0.0, fps_scale)
	var profile: Dictionary = CommandoFirearmProfileResolver.get_weapon_profile(
		"bowling_trap",
		weapon_profiles,
		weapon_profile_overrides
	)
	var trap_update: Dictionary = advance_runtime_traps(
		traps,
		context,
		step,
		profile,
		install_frames,
		capture_frames,
		capture_ball_offset,
		trap_height,
		capture_height,
		trap_width,
		launch_speed_multiplier,
		launch_fan_half_angle,
		guard_speed_reduction,
		guard_knockback_power,
		guard_stun_frames
	)
	dispatch_runtime_update_events(
		CommandoFirearmValueUtils.get_array(trap_update.get("events", [])),
		impact_flashes,
		runtime_owner,
		context,
		deps,
		weapon_profiles,
		weapon_profile_overrides,
		weapon_hit_feedback,
		hit_feedback_profile_overrides,
		base_weapon_id,
		grenade_explosion_duration_frames,
		flash_limit
	)
	return CommandoFirearmValueUtils.get_dict(trap_update.get("result", {}))


static func _dispatch_capture_event(
	event: Dictionary,
	deps: Dictionary,
	weapon_hit_feedback: Dictionary,
	hit_feedback_profile_overrides: Dictionary,
	base_weapon_id: String
) -> void:
	CommandoFirearmHitFeedbackDispatcher.trigger_hit_feedback(
		CommandoFirearmProfileResolver.get_hit_feedback_profile(
			"bowling_trap",
			weapon_hit_feedback,
			hit_feedback_profile_overrides
		),
		deps
	)
	var captured_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(event.get("captured_pos", Vector2.ZERO), Vector2.ZERO)
	var ball_vel: Vector2 = CommandoFirearmValueUtils.get_vector2(event.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	CommandoFirearmHitFeedbackDispatcher.register_ball_hit_pulse(
		captured_pos,
		ball_vel,
		0.62,
		"bowling_trap_capture",
		deps,
		base_weapon_id
	)
	CommandoFirearmAudioDispatcher.play_impact_audio("bowling_trap", deps)


static func _dispatch_release_event(
	event: Dictionary,
	impact_flashes: Array,
	runtime_owner: Object,
	context: Dictionary,
	deps: Dictionary,
	weapon_profiles: Dictionary,
	weapon_profile_overrides: Dictionary,
	weapon_hit_feedback: Dictionary,
	hit_feedback_profile_overrides: Dictionary,
	base_weapon_id: String,
	grenade_explosion_duration_frames: float,
	flash_limit: int
) -> void:
	var release_payload: Dictionary = CommandoFirearmValueUtils.get_dict(event.get("release_payload", {}))
	var pseudo_projectile: Dictionary = CommandoFirearmValueUtils.get_dict(release_payload.get("pseudo_projectile", {}))
	CommandoFirearmImpactFlashResolver.append_flash(
		impact_flashes,
		pseudo_projectile,
		weapon_profiles,
		weapon_profile_overrides,
		base_weapon_id,
		grenade_explosion_duration_frames,
		flash_limit
	)
	if runtime_owner != null and runtime_owner.has_method("_spawn_lingering_effect"):
		runtime_owner.call("_spawn_lingering_effect", "bowling_trap", pseudo_projectile, context)
	CommandoFirearmHitFeedbackDispatcher.trigger_hit_feedback(
		CommandoFirearmProfileResolver.get_hit_feedback_profile(
			"bowling_trap",
			weapon_hit_feedback,
			hit_feedback_profile_overrides
		),
		deps
	)
	var motion: Dictionary = CommandoFirearmValueUtils.get_dict(release_payload.get("motion", {}))
	var captured_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(motion.get("captured_pos", Vector2.ZERO), Vector2.ZERO)
	var launch_vel: Vector2 = CommandoFirearmValueUtils.get_vector2(motion.get("launch_vel", Vector2.ZERO), Vector2.ZERO)
	CommandoFirearmHitFeedbackDispatcher.register_ball_hit_pulse(
		captured_pos,
		launch_vel,
		0.86,
		"bowling_trap_launch",
		deps,
		base_weapon_id
	)
	apply_guard_state(
		runtime_owner,
		CommandoFirearmValueUtils.get_dict(release_payload.get("guard_state", {}))
	)


static func build_guard_state(trap: Dictionary, original_speed: float, guard_speed_reduction: float) -> Dictionary:
	var safe_original_speed: float = max(1.0, original_speed)
	return {
		"armed": true,
		"original_speed": safe_original_speed,
		"restore_speed": safe_original_speed * guard_speed_reduction,
		"source": "commando_bowling_trap_guard_%d" % int(trap.get("id", 0)),
	}


static func build_cleared_guard_state() -> Dictionary:
	return {
		"armed": false,
		"original_speed": 0.0,
		"restore_speed": 0.0,
		"source": "",
	}


static func apply_guard_state(target: Object, guard_state: Dictionary) -> void:
	if target == null:
		return
	target.set("bowling_trap_guard_armed", bool(guard_state.get("armed", false)))
	target.set("bowling_trap_guard_original_speed", float(guard_state.get("original_speed", 0.0)))
	target.set("bowling_trap_guard_restore_speed", float(guard_state.get("restore_speed", 0.0)))
	target.set("bowling_trap_guard_source", str(guard_state.get("source", "")))


static func build_guard_status_data(
	knockback_vel: float,
	knockback_frames: float,
	knockback_decay_per_frame: float,
	source: String
) -> Dictionary:
	return {
		"knockback_vel": knockback_vel,
		"knockback_active": abs(knockback_vel) > 0.001,
		"knockback_frames": knockback_frames,
		"knockback_decay_per_frame": knockback_decay_per_frame,
		"knockback_stop_threshold": 0.3,
		"source": source,
	}


static func is_stage2_boss_status_immune(context: Dictionary, deps: Dictionary) -> bool:
	var stage2_boss_immune := false
	if int(context.get("current_stage", 0)) == 2:
		stage2_boss_immune = (
			bool(context.get("stage2_speed_defense_status_immunity_active", false))
			or bool(context.get("stage2_speed_defense_active", false))
		)
	var stage2_skill_state: Object = deps.get("stage2_boss_skill_state", null)
	if not stage2_boss_immune and _is_status_immune_owner(stage2_skill_state):
		stage2_boss_immune = true
	var registry: Object = deps.get("registry", null)
	var registry_stage2_skill_state: Object = CommandoFirearmValueUtils.get_instance(registry, "stage2_boss_skill_state")
	if not stage2_boss_immune and _is_status_immune_owner(registry_stage2_skill_state):
		stage2_boss_immune = true
	return stage2_boss_immune


static func _is_status_immune_owner(owner: Object) -> bool:
	return owner != null and owner.has_method("is_boss_status_immune") and bool(owner.is_boss_status_immune())


static func build_guard_immune_result(ball_vel: Vector2) -> Dictionary:
	return {
		"ball_vel": ball_vel,
		"commando_bowling_trap_guard_consumed": true,
		"commando_bowling_trap_guarded": false,
		"commando_bowling_trap_guard_hit": false,
		"commando_bowling_trap_guard_armed": false,
		"commando_bowling_trap_guard_source": "",
		"commando_bowling_trap_guard_knockback_power": 0.0,
		"commando_bowling_trap_guard_stun_frames": 0.0,
		"commando_bowling_trap_guard_restore_speed": 0.0,
		"boss_status_immune": true,
	}


static func build_guard_hit_result(
	ball_vel: Vector2,
	knockback_vel: float,
	source: String,
	stun_frames: float,
	restore_speed: float
) -> Dictionary:
	return {
		"ball_vel": ball_vel,
		"boss_vel": knockback_vel,
		"commando_bowling_trap_guard_consumed": true,
		"commando_bowling_trap_guarded": true,
		"commando_bowling_trap_guard_hit": true,
		"boss_status_immune": false,
		"commando_bowling_trap_guard_armed": false,
		"commando_bowling_trap_guard_source": "",
		"commando_bowling_trap_guard_status_source": source,
		"commando_bowling_trap_guard_knockback_power": 0.0,
		"commando_bowling_trap_guard_knockback_vel": knockback_vel,
		"commando_bowling_trap_guard_stun_frames": 0.0,
		"commando_bowling_trap_guard_restore_speed": 0.0,
		"commando_bowling_trap_guard_consumed_stun_frames": stun_frames,
		"commando_bowling_trap_guard_consumed_restore_speed": restore_speed,
	}


static func soften_guard_ball(ball_vel: Vector2, restore_speed: float) -> Vector2:
	var speed: float = max(1.0, restore_speed)
	if ball_vel.length() <= 0.001:
		return Vector2(0.0, speed)
	return ball_vel.normalized() * speed


static func get_guard_knockback_velocity(
	boss_center: Vector2,
	context: Dictionary,
	field_width: float,
	knockback_power: float
) -> float:
	var field_center_x: float = float(context.get("width", field_width)) * 0.5
	var direction: float = 1.0 if boss_center.x < field_center_x else -1.0
	if is_equal_approx(boss_center.x, field_center_x):
		direction = sign(float(context.get("boss_vel", 0.0)))
		if is_zero_approx(direction):
			direction = 1.0
	return direction * knockback_power


static func roll_launch_direction() -> float:
	# Continuous random fan multiplier in [-1.0, 1.0]: -1.0 = full-left deflection,
	# 0.0 = straight up (toward the boss), +1.0 = full-right. Scaled by the launch fan
	# half-angle (+/-40 deg) at release time in build_release_motion().
	return randf_range(-1.0, 1.0)


static func hits_ball(
	trap: Dictionary,
	context: Dictionary,
	trap_height: float,
	capture_height: float,
	default_trap_width: float
) -> bool:
	var ball_vel: Vector2 = CommandoFirearmValueUtils.get_vector2(context.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	if ball_vel.y <= 0.0:
		return false
	var ball_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(context.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	var ball_size: float = max(1.0, float(context.get("ball_size", 28.6)))
	var trap_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(trap.get("pos", Vector2.ZERO), Vector2.ZERO)
	var trap_width: float = max(1.0, float(trap.get("width", default_trap_width)))
	var trap_rect := Rect2(
		trap_pos - Vector2(trap_width * 0.5, trap_height * 0.5),
		Vector2(trap_width, capture_height)
	)
	var ball_rect := Rect2(
		ball_pos - Vector2(ball_size, ball_size) * 0.5,
		Vector2(ball_size, ball_size)
	)
	return trap_rect.intersects(ball_rect)
