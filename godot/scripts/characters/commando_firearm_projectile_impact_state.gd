extends RefCounted

const CommandoFirearmHitGeometry := preload("res://scripts/characters/commando_firearm_hit_geometry.gd")
const CommandoFirearmHitResultState := preload("res://scripts/characters/commando_firearm_hit_result_state.gd")
const CommandoFirearmImpactFlashResolver := preload("res://scripts/characters/commando_firearm_impact_flash_resolver.gd")
const CommandoFirearmLingeringEffectState := preload("res://scripts/characters/commando_firearm_lingering_effect_state.gd")
const CommandoFirearmOriginGeometry := preload("res://scripts/characters/commando_firearm_origin_geometry.gd")
const CommandoFirearmPendingResultState := preload("res://scripts/characters/commando_firearm_pending_result_state.gd")
const CommandoFirearmProfileResolver := preload("res://scripts/characters/commando_firearm_profile_resolver.gd")
const CommandoFirearmStage2RockInteractionResolver := preload("res://scripts/characters/commando_firearm_stage2_rock_interaction_resolver.gd")
const CommandoFirearmSuicideDroneState := preload("res://scripts/characters/commando_firearm_suicide_drone_state.gd")
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


static func register_runtime_projectile_hit(
	runtime_owner: Object,
	projectile: Dictionary,
	context: Dictionary,
	deps: Dictionary,
	options: Dictionary
) -> Dictionary:
	if runtime_owner == null:
		return {}
	var base_weapon_id: String = str(options.get("base_weapon_id", "pistol"))
	var weapon_id: String = CommandoFirearmValueUtils.get_projectile_weapon_id(projectile, base_weapon_id)
	var feedback_profile: Dictionary = CommandoFirearmProfileResolver.get_hit_feedback_profile(
		weapon_id,
		CommandoFirearmValueUtils.get_dict(options.get("weapon_hit_feedback", {})),
		CommandoFirearmValueUtils.get_dict(options.get("hit_feedback_profile_overrides", {}))
	)
	var combat_result: Dictionary = CommandoFirearmHitResultState.apply_runtime_weapon_hit_result(
		runtime_owner,
		weapon_id,
		projectile,
		context,
		deps,
		CommandoFirearmValueUtils.get_dict(options.get("weapon_hit_results", {})),
		CommandoFirearmValueUtils.get_dict(options.get("hit_result_profile_overrides", {})),
		base_weapon_id,
		CommandoFirearmValueUtils.get_dict(options.get("slingshot_stun_multipliers", {})),
		CommandoFirearmValueUtils.get_dict(options.get("slingshot_knockback_multipliers", {})),
		float(options.get("doping_potion_head_leg_multiplier", 1.0)),
		float(options.get("pistol_head_shot_chance", 0.0)),
		float(options.get("pistol_leg_shot_chance", 0.0)),
		CommandoFirearmValueUtils.get_dict(options.get("pistol_hit_tuning", {})),
		Vector2(float(options.get("field_width", 760.0)), float(options.get("field_height", 750.0))),
		float(options.get("pistol_hit_text_timer_frames", 60.0)),
		str(options.get("pistol_head_shot_label", "헤드샷!")),
		str(options.get("pistol_leg_shot_label", "레그샷!")),
		int(options.get("pistol_feedback_limit", 4)),
		int(options.get("ak47_boss_damage_hit_threshold", 5))
	)
	CommandoFirearmPendingResultState.queue_runtime_combat_result(runtime_owner, combat_result)
	var lingering_result: Dictionary = {}
	if weapon_id == "suicide_drone":
		lingering_result = CommandoFirearmSuicideDroneState.trigger_active_item_fire_zone(projectile, deps)
		if lingering_result.is_empty():
			lingering_result = _call_runtime_lingering_spawn(runtime_owner, weapon_id, projectile, context)
	else:
		lingering_result = _call_runtime_lingering_spawn(runtime_owner, weapon_id, projectile, context)
	if not lingering_result.is_empty():
		combat_result["lingering_effect"] = lingering_result
	var hit_events: Array = CommandoFirearmValueUtils.get_array(runtime_owner.get("hit_events"))
	append_runtime_boss_hit(
		hit_events,
		projectile,
		weapon_id,
		feedback_profile,
		combat_result,
		context,
		deps,
		base_weapon_id,
		int(options.get("hit_event_limit", 20))
	)
	runtime_owner.set("hit_events", hit_events)
	return combat_result


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
	if _should_spawn_impact_flash(projectile, impact_reason):
		CommandoFirearmImpactFlashResolver.append_flash(
			impact_flashes,
			projectile,
			weapon_profiles,
			weapon_profile_overrides,
			base_weapon_id,
			grenade_explosion_duration_frames,
			flash_limit
		)
	CommandoFirearmHitFeedbackDispatcher.trigger_explosion_screen_shake(
		CommandoFirearmValueUtils.get_projectile_weapon_id(projectile, base_weapon_id),
		deps
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


# Bullet-kind projectiles (pistol / commando_pistol / ak47) that die without
# hitting anything must fizzle silently. The terminal flash would otherwise pop
# the red-orange starburst — and the fx-host glow + one-shot particle burst
# anchored to impact_flashes[0] — at the bullet's quasi-random death position in
# the open field (spread misses, stage 2 rock ricochet deaths). "expired" stays
# a visible detonation reason for rocket / support / drone / net payloads.
static func _should_spawn_impact_flash(projectile: Dictionary, impact_reason: String) -> bool:
	if impact_reason != "expired" and impact_reason != "out_of_bounds":
		return true
	return str(projectile.get("kind", "bullet")) != "bullet"


static func _call_runtime_lingering_spawn(
	runtime_owner: Object,
	weapon_id: String,
	projectile: Dictionary,
	context: Dictionary
) -> Dictionary:
	if runtime_owner != null and runtime_owner.has_method("_spawn_lingering_effect"):
		return CommandoFirearmValueUtils.get_dict(runtime_owner.call(
			"_spawn_lingering_effect",
			weapon_id,
			projectile,
			context
		))
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
