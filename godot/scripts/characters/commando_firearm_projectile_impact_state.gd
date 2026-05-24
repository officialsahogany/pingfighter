extends RefCounted

const CommandoFirearmHitGeometry := preload("res://scripts/characters/commando_firearm_hit_geometry.gd")
const CommandoFirearmImpactFlashResolver := preload("res://scripts/characters/commando_firearm_impact_flash_resolver.gd")
const CommandoFirearmLingeringEffectState := preload("res://scripts/characters/commando_firearm_lingering_effect_state.gd")
const CommandoFirearmOriginGeometry := preload("res://scripts/characters/commando_firearm_origin_geometry.gd")
const CommandoFirearmProfileResolver := preload("res://scripts/characters/commando_firearm_profile_resolver.gd")
const CommandoFirearmStage2RockInteractionResolver := preload("res://scripts/characters/commando_firearm_stage2_rock_interaction_resolver.gd")
const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")
const CommandoFirearmAudioDispatcher := preload("res://scripts/characters/commando_firearm_audio_dispatcher.gd")
const CommandoFirearmHitFeedbackDispatcher := preload("res://scripts/characters/commando_firearm_hit_feedback_dispatcher.gd")


static func build_hit_event(
	projectile: Dictionary,
	weapon_id: String,
	projectile_kind: String,
	pos: Vector2,
	velocity: Vector2,
	intensity: float,
	combat_result: Dictionary
) -> Dictionary:
	return {
		"id": int(projectile.get("id", 0)),
		"weapon_id": weapon_id,
		"kind": projectile_kind,
		"target": "boss",
		"pos": pos,
		"velocity": velocity,
		"intensity": intensity,
		"result": combat_result,
	}


static func append_runtime_hit_event(
	hit_events: Array,
	projectile: Dictionary,
	weapon_id: String,
	projectile_kind: String,
	pos: Vector2,
	velocity: Vector2,
	intensity: float,
	combat_result: Dictionary,
	hit_event_limit: int
) -> Dictionary:
	var hit_event: Dictionary = build_hit_event(
		projectile,
		weapon_id,
		projectile_kind,
		pos,
		velocity,
		intensity,
		combat_result
	)
	CommandoFirearmValueUtils.append_limited(hit_events, hit_event, hit_event_limit)
	return hit_event


static func append_runtime_boss_hit(
	hit_events: Array,
	projectile: Dictionary,
	weapon_id: String,
	feedback_profile: Dictionary,
	combat_result: Dictionary,
	context: Dictionary,
	deps: Dictionary,
	base_weapon_id: String,
	hit_event_limit: int
) -> Dictionary:
	var pos: Vector2 = CommandoFirearmValueUtils.get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	var velocity: Vector2 = CommandoFirearmValueUtils.get_vector2(projectile.get("velocity", Vector2.ZERO), Vector2.ZERO)
	var intensity: float = float(feedback_profile.get("intensity", 0.5))
	var color: Color = CommandoFirearmValueUtils.get_color(projectile.get("color", Color.WHITE), Color.WHITE)
	var hit_event: Dictionary = append_runtime_hit_event(
		hit_events,
		projectile,
		weapon_id,
		CommandoFirearmValueUtils.get_projectile_kind(projectile, "bullet"),
		pos,
		velocity,
		intensity,
		combat_result,
		hit_event_limit
	)
	CommandoFirearmHitFeedbackDispatcher.spawn_shared_impact_particles(pos, color, velocity, intensity, deps)
	CommandoFirearmHitFeedbackDispatcher.trigger_hit_feedback(feedback_profile, deps)
	CommandoFirearmHitFeedbackDispatcher.trigger_boss_hit_animation(context, deps)
	CommandoFirearmHitFeedbackDispatcher.register_ball_hit_pulse(pos, velocity, intensity, weapon_id, deps, base_weapon_id)
	CommandoFirearmAudioDispatcher.play_impact_audio(weapon_id, deps)
	return hit_event


static func build_environment_impact_result(weapon_id: String, reason: String, pos: Vector2) -> Dictionary:
	return {
		"commando_firearm_environment_impact": true,
		"commando_firearm_environment_impact_reason": reason,
		"commando_firearm_environment_impact_weapon_id": weapon_id,
		"commando_firearm_environment_impact_pos": pos,
	}


static func register_environment_impact(
	projectile: Dictionary,
	reason: String,
	deps: Dictionary,
	weapon_hit_feedback: Dictionary,
	hit_feedback_profile_overrides: Dictionary,
	base_weapon_id: String
) -> Dictionary:
	var weapon_id: String = CommandoFirearmValueUtils.get_projectile_weapon_id(projectile, base_weapon_id)
	var pos: Vector2 = CommandoFirearmValueUtils.get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	var velocity: Vector2 = CommandoFirearmValueUtils.get_vector2(projectile.get("velocity", Vector2.ZERO), Vector2.ZERO)
	var feedback_profile: Dictionary = CommandoFirearmProfileResolver.get_hit_feedback_profile(
		weapon_id,
		weapon_hit_feedback,
		hit_feedback_profile_overrides
	)
	var intensity: float = float(feedback_profile.get("intensity", 0.5))
	var color: Color = CommandoFirearmValueUtils.get_color(projectile.get("color", Color.WHITE), Color.WHITE)
	CommandoFirearmHitFeedbackDispatcher.spawn_shared_impact_particles(pos, color, velocity, intensity, deps)
	CommandoFirearmHitFeedbackDispatcher.trigger_hit_feedback(feedback_profile, deps)
	CommandoFirearmAudioDispatcher.play_impact_audio(weapon_id, deps)
	return build_environment_impact_result(weapon_id, reason, pos)


static func dispatch_runtime_impact(
	impact_flashes: Array,
	runtime_owner: Object,
	projectile: Dictionary,
	impact_reason: String,
	projectile_weapon_id: String,
	context: Dictionary,
	deps: Dictionary,
	weapon_profiles: Dictionary,
	weapon_profile_overrides: Dictionary,
	weapon_hit_feedback: Dictionary,
	hit_feedback_profile_overrides: Dictionary,
	base_weapon_id: String,
	grenade_explosion_duration_frames: float,
	flash_limit: int
) -> Dictionary:
	if impact_reason == "":
		return {}
	CommandoFirearmImpactFlashResolver.append_flash(
		impact_flashes,
		projectile,
		weapon_profiles,
		weapon_profile_overrides,
		base_weapon_id,
		grenade_explosion_duration_frames,
		flash_limit
	)
	var rock_impact_profile: Dictionary = CommandoFirearmProfileResolver.get_weapon_profile(
		projectile_weapon_id,
		weapon_profiles,
		weapon_profile_overrides
	)
	CommandoFirearmStage2RockInteractionResolver.destroy_projectile_impact_rocks(
		projectile,
		context,
		deps,
		projectile_weapon_id,
		CommandoFirearmHitGeometry.get_explosion_radius(projectile, rock_impact_profile)
	)
	if impact_reason == "target":
		if runtime_owner != null and runtime_owner.has_method("_register_projectile_hit"):
			runtime_owner.call("_register_projectile_hit", projectile, context, deps)
		return {}
	if impact_reason == "wall":
		return register_environment_impact(
			projectile,
			impact_reason,
			deps,
			weapon_hit_feedback,
			hit_feedback_profile_overrides,
			base_weapon_id
		)
	if CommandoFirearmHitGeometry.is_net_gun_weapon(projectile_weapon_id):
		if runtime_owner != null and runtime_owner.has_method("_spawn_lingering_effect"):
			runtime_owner.call(
				"_spawn_lingering_effect",
				"net_gun",
				CommandoFirearmLingeringEffectState.build_net_dissolve_projectile(projectile),
				context
			)
	return {}


static func get_impact_reason(
	projectile: Dictionary,
	context: Dictionary,
	weapon_profiles: Dictionary,
	weapon_profile_overrides: Dictionary,
	base_weapon_id: String,
	field_size: Vector2,
	field_width: float
) -> String:
	var target: Vector2 = CommandoFirearmValueUtils.get_projectile_target(
		projectile,
		CommandoFirearmOriginGeometry.get_boss_target_pos(context, field_width)
	)
	var weapon_id: String = CommandoFirearmValueUtils.get_projectile_weapon_id(
		projectile,
		base_weapon_id
	)
	var profile: Dictionary = CommandoFirearmProfileResolver.get_weapon_profile(
		weapon_id,
		weapon_profiles,
		weapon_profile_overrides
	)
	return CommandoFirearmHitGeometry.get_projectile_impact_reason(
		projectile,
		target,
		weapon_id,
		profile,
		CommandoFirearmHitGeometry.get_boss_rect(context, field_width),
		field_size,
		field_width
	)
