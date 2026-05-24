extends RefCounted

const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const CommandoFirearmAudioDispatcher := preload("res://scripts/characters/commando_firearm_audio_dispatcher.gd")
const CommandoFirearmHitFeedbackDispatcher := preload("res://scripts/characters/commando_firearm_hit_feedback_dispatcher.gd")
const CommandoFirearmHitGeometry := preload("res://scripts/characters/commando_firearm_hit_geometry.gd")
const CommandoFirearmImpactFlashResolver := preload("res://scripts/characters/commando_firearm_impact_flash_resolver.gd")
const CommandoFirearmMuzzleFlashResolver := preload("res://scripts/characters/commando_firearm_muzzle_flash_resolver.gd")
const CommandoFirearmOriginGeometry := preload("res://scripts/characters/commando_firearm_origin_geometry.gd")
const CommandoFirearmProfileResolver := preload("res://scripts/characters/commando_firearm_profile_resolver.gd")
const CommandoFirearmSuicideDroneBallBoostResolver := preload("res://scripts/characters/commando_firearm_suicide_drone_ball_boost_resolver.gd")
const CommandoFirearmSuicideDroneGeometry := preload("res://scripts/characters/commando_firearm_suicide_drone_geometry.gd")
const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")


static func append_spawn_effects(
	projectiles: Array,
	muzzle_flashes: Array,
	config: Dictionary,
	profile: Dictionary,
	shot_id: int,
	field_width: float,
	field_height: float,
	drone_size: Vector2,
	default_max_speed: float,
	default_acceleration: float,
	default_life_frames: float,
	grace_frames: float,
	rotor_base_speed: float,
	projectile_limit: int,
	flash_limit: int
) -> Dictionary:
	var origin: Vector2 = CommandoFirearmSuicideDroneGeometry.get_spawn_pos(
		config,
		field_width,
		field_height,
		drone_size
	)
	var projectile: Dictionary = build_projectile(
		profile,
		origin,
		CommandoFirearmOriginGeometry.get_boss_target_pos(config, field_width),
		shot_id,
		CommandoFirearmSuicideDroneGeometry.get_player_lock_pos(config, field_width, field_height),
		drone_size,
		default_max_speed,
		default_acceleration,
		default_life_frames,
		grace_frames,
		rotor_base_speed
	)
	CommandoFirearmValueUtils.append_limited(projectiles, projectile, projectile_limit)
	CommandoFirearmValueUtils.append_limited(
		muzzle_flashes,
		CommandoFirearmMuzzleFlashResolver.build_flash(origin, Vector2.UP, profile, "suicide_drone"),
		flash_limit
	)
	return projectile


static func build_projectile(
	profile: Dictionary,
	origin: Vector2,
	target: Vector2,
	shot_id: int,
	player_lock_pos: Vector2,
	drone_size: Vector2,
	default_max_speed: float,
	default_acceleration: float,
	default_life_frames: float,
	grace_frames: float,
	rotor_base_speed: float
) -> Dictionary:
	var life_frames: float = float(profile.get("life_frames", default_life_frames))
	return {
		"id": shot_id,
		"weapon_id": "suicide_drone",
		"kind": "drone",
		"manual_control": true,
		"pos": origin,
		"prev_pos": origin,
		"target": target,
		"velocity": Vector2.ZERO,
		"speed": 0.0,
		"max_speed": float(profile.get("max_speed", default_max_speed)),
		"acceleration": float(profile.get("acceleration", default_acceleration)),
		"radius": float(profile.get("radius", 24.0)),
		"size": drone_size,
		"trail": float(profile.get("trail", 26.0)),
		"life_frames": life_frames,
		"max_life_frames": life_frames,
		"grace_timer_frames": grace_frames,
		"rotor_angle": 0.0,
		"rotor_speed": rotor_base_speed,
		"impact_radius": float(profile.get("impact_radius", 40.0)),
		"explosion_radius": float(profile.get("explosion_radius", 150.0)),
		"color": profile.get("color", Color(1.0, 0.42, 0.18)),
		"secondary": profile.get("secondary", Color(0.45, 0.86, 1.0)),
		"player_lock_pos": player_lock_pos,
	}


static func apply_input(
	projectile: Dictionary,
	input_vector: Vector2,
	default_acceleration: float,
	default_max_speed: float,
	rotor_base_speed: float,
	rotor_speed_scale: float
) -> Dictionary:
	var next_projectile: Dictionary = projectile.duplicate(true)
	var velocity: Vector2 = CommandoFirearmValueUtils.get_vector2(
		next_projectile.get("velocity", Vector2.ZERO),
		Vector2.ZERO
	)
	if input_vector.length_squared() <= 0.001:
		velocity *= 0.90
		if abs(velocity.x) < 0.05:
			velocity.x = 0.0
		if abs(velocity.y) < 0.05:
			velocity.y = 0.0
	else:
		velocity += input_vector * float(next_projectile.get("acceleration", default_acceleration))
		var max_speed: float = max(1.0, float(next_projectile.get("max_speed", default_max_speed)))
		if velocity.length() > max_speed:
			velocity = velocity.normalized() * max_speed
	next_projectile["velocity"] = velocity
	next_projectile["speed"] = velocity.length()
	next_projectile["rotor_speed"] = rotor_base_speed + min(20.0, velocity.length() * rotor_speed_scale)
	return next_projectile


static func advance_active_projectile(
	projectile: Dictionary,
	fps_scale: float,
	field_size: Vector2,
	default_size: Vector2,
	rotor_base_speed: float
) -> Dictionary:
	var step: float = max(0.0, fps_scale)
	var next_projectile: Dictionary = projectile.duplicate(true)
	next_projectile["grace_timer_frames"] = max(0.0, float(next_projectile.get("grace_timer_frames", 0.0)) - step)
	next_projectile["rotor_angle"] = fmod(
		float(next_projectile.get("rotor_angle", 0.0)) + float(next_projectile.get("rotor_speed", rotor_base_speed)) * step,
		360.0
	)
	return clamp_projectile(next_projectile, field_size, default_size)


static func resolve_runtime_collision(
	projectile: Dictionary,
	fps_scale: float,
	context: Dictionary,
	field_size: Vector2,
	default_size: Vector2,
	rotor_base_speed: float,
	field_width: float
) -> Dictionary:
	if not bool(projectile.get("manual_control", false)):
		return {}
	var next_projectile: Dictionary = advance_active_projectile(
		projectile,
		max(0.0, fps_scale),
		field_size,
		default_size,
		rotor_base_speed
	)
	var reason: String = ""
	if float(next_projectile.get("grace_timer_frames", 0.0)) <= 0.0:
		if CommandoFirearmSuicideDroneGeometry.hits_ball(next_projectile, context, default_size):
			reason = "ball_hit"
		elif CommandoFirearmSuicideDroneGeometry.hits_boss_rect(
			next_projectile,
			CommandoFirearmHitGeometry.get_boss_rect(context, field_width),
			default_size
		):
			reason = "boss_hit"
		elif CommandoFirearmSuicideDroneGeometry.hits_top_wall(next_projectile, default_size):
			reason = "boss_back_wall"
		elif float(next_projectile.get("life_frames", 0.0)) <= 0.0:
			reason = "expired"
	return {
		"projectile": next_projectile,
		"reason": reason,
	}


static func clamp_projectile(projectile: Dictionary, field_size: Vector2, default_size: Vector2) -> Dictionary:
	var next_projectile: Dictionary = projectile.duplicate(true)
	var pos: Vector2 = CommandoFirearmValueUtils.get_vector2(next_projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	var size: Vector2 = CommandoFirearmValueUtils.get_vector2(next_projectile.get("size", default_size), default_size)
	var half: Vector2 = size * 0.5
	pos.x = clamp(pos.x, half.x, field_size.x - half.x)
	pos.y = clamp(pos.y, half.y, field_size.y - half.y)
	next_projectile["pos"] = pos
	return next_projectile


static func get_homing_velocity(
	pos: Vector2,
	projectile: Dictionary,
	target: Vector2,
	fps_scale: float
) -> Vector2:
	if bool(projectile.get("manual_control", false)):
		return CommandoFirearmValueUtils.get_vector2(projectile.get("velocity", Vector2.ZERO), Vector2.ZERO)
	var speed: float = float(projectile.get("speed", 8.8))
	var desired: Vector2 = target - pos
	if desired.length() <= 0.001:
		return CommandoFirearmValueUtils.get_vector2(projectile.get("velocity", Vector2.UP * speed), Vector2.UP * speed)
	desired = desired.normalized() * speed
	var current: Vector2 = CommandoFirearmValueUtils.get_vector2(projectile.get("velocity", Vector2.UP * speed), Vector2.UP * speed)
	return current.lerp(desired, clamp(0.08 * max(0.0, fps_scale), 0.0, 0.42))


static func build_fire_result(
	updated_weapon: Dictionary,
	ammo_current: int,
	ammo_max: int,
	grace_frames: float,
	special_gauge: float
) -> Dictionary:
	return {
		"handled": true,
		"weapon_id": "suicide_drone",
		"fired": true,
		"drone_active": true,
		"ammo_current": int(updated_weapon.get("ammo_current", max(0, ammo_current - 1))),
		"ammo_max": int(updated_weapon.get("ammo_max", ammo_max)),
		"grace_frames": grace_frames,
		"special_gauge": special_gauge,
		"skill_gold_award": 0,
	}


static func build_fire_failed_result(special_gauge: float, reason: String, cooldown_frames: float) -> Dictionary:
	return {
		"handled": true,
		"weapon_id": "suicide_drone",
		"fire_failed": true,
		"failure_reason": reason,
		"cooldown_frames": cooldown_frames,
		"special_gauge": special_gauge,
	}


static func build_active_input_result(projectile: Dictionary, special_gauge: float) -> Dictionary:
	return {
		"handled": true,
		"weapon_id": "suicide_drone",
		"drone_active": true,
		"drone_pos": CommandoFirearmValueUtils.get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO),
		"drone_velocity": CommandoFirearmValueUtils.get_vector2(projectile.get("velocity", Vector2.ZERO), Vector2.ZERO),
		"grace_frames": float(projectile.get("grace_timer_frames", 0.0)),
		"special_gauge": special_gauge,
	}


static func has_active_projectile(projectiles: Array) -> bool:
	return get_active_projectile_index(projectiles) >= 0


static func get_active_projectile_index(projectiles: Array) -> int:
	for index in range(projectiles.size()):
		var projectile: Dictionary = CommandoFirearmValueUtils.get_dict(projectiles[index])
		if is_projectile(projectile):
			return index
	return -1


static func is_projectile(projectile: Dictionary) -> bool:
	return (
		CommandoFirearmValueUtils.get_projectile_weapon_id(projectile, "") == "suicide_drone"
		and CommandoFirearmValueUtils.get_projectile_kind(projectile) == "drone"
	)


static func build_detonation_result(
	reason: String,
	pos: Vector2,
	hit_boss: bool,
	cooldown_frames: float
) -> Dictionary:
	return {
		"handled": true,
		"weapon_id": "suicide_drone",
		"commando_suicide_drone_detonated": true,
		"commando_suicide_drone_reason": reason,
		"commando_suicide_drone_pos": pos,
		"commando_suicide_drone_hit_boss": hit_boss,
		"commando_suicide_drone_cooldown_frames": cooldown_frames,
	}


static func append_runtime_detonation_flash(
	impact_flashes: Array,
	projectile: Dictionary,
	weapon_profiles: Dictionary,
	weapon_profile_overrides: Dictionary,
	base_weapon_id: String,
	grenade_explosion_duration_frames: float,
	flash_limit: int
) -> void:
	CommandoFirearmImpactFlashResolver.append_flash(
		impact_flashes,
		projectile,
		weapon_profiles,
		weapon_profile_overrides,
		base_weapon_id,
		grenade_explosion_duration_frames,
		flash_limit
	)


static func explosion_hits_runtime_boss(
	projectile: Dictionary,
	context: Dictionary,
	weapon_profiles: Dictionary,
	weapon_profile_overrides: Dictionary,
	field_width: float
) -> bool:
	return CommandoFirearmSuicideDroneGeometry.explosion_hits_boss(
		projectile,
		CommandoFirearmHitGeometry.get_boss_rect(context, field_width),
		CommandoFirearmHitGeometry.get_explosion_radius(
			projectile,
			CommandoFirearmProfileResolver.get_weapon_profile(
				"suicide_drone",
				weapon_profiles,
				weapon_profile_overrides
			)
		)
	)


static func dispatch_miss_detonation_feedback(
	projectile: Dictionary,
	deps: Dictionary,
	weapon_hit_feedback: Dictionary,
	hit_feedback_profile_overrides: Dictionary,
	base_weapon_id: String
) -> void:
	var pos: Vector2 = CommandoFirearmValueUtils.get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	var velocity: Vector2 = CommandoFirearmValueUtils.get_vector2(projectile.get("velocity", Vector2.ZERO), Vector2.ZERO)
	CommandoFirearmHitFeedbackDispatcher.spawn_shared_impact_particles(
		pos,
		CommandoFirearmValueUtils.get_color(projectile.get("color", Color.WHITE), Color.WHITE),
		velocity,
		1.0,
		deps
	)
	CommandoFirearmHitFeedbackDispatcher.trigger_hit_feedback(
		CommandoFirearmProfileResolver.get_hit_feedback_profile(
			"suicide_drone",
			weapon_hit_feedback,
			hit_feedback_profile_overrides
		),
		deps
	)
	CommandoFirearmHitFeedbackDispatcher.register_ball_hit_pulse(
		pos,
		velocity,
		0.86,
		"suicide_drone",
		deps,
		base_weapon_id
	)
	CommandoFirearmAudioDispatcher.play_impact_audio("suicide_drone", deps)


static func build_runtime_detonation_result(
	reason: String,
	pos: Vector2,
	hit_boss: bool,
	cooldown_frames: float,
	projectile: Dictionary,
	context: Dictionary,
	ball_speed_multiplier: float,
	ball_fan_degrees: float
) -> Dictionary:
	var result: Dictionary = build_detonation_result(reason, pos, hit_boss, cooldown_frames)
	if reason == "ball_hit":
		result.merge(
			CommandoFirearmSuicideDroneBallBoostResolver.build_boost_result(
				projectile,
				context,
				ball_speed_multiplier,
				ball_fan_degrees
			),
			true
		)
	return result


static func trigger_active_item_fire_zone(projectile: Dictionary, deps: Dictionary) -> Dictionary:
	var registry: Object = deps.get("registry", null)
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime == null:
		active_item_runtime = CommandoFirearmValueUtils.get_instance(registry, "active_item_runtime")
	if active_item_runtime == null or not active_item_runtime.has_method("trigger_molotov_fire_zone"):
		return {}
	active_item_runtime.trigger_molotov_fire_zone(
		CommandoFirearmValueUtils.get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO),
		null,
		registry,
		false
	)
	return build_active_item_fire_zone_result()


static func build_active_item_fire_zone_result() -> Dictionary:
	return {
		"kind": "fire_zone",
		"duration_frames": ActiveItemThrowController.MOLOTOV_FIRE_DURATION_FRAMES,
		"source": "active_item_molotov_fire_zone",
	}
