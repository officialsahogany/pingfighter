extends RefCounted

const CommandoFirearmBowlingTrapGeometry := preload("res://scripts/characters/commando_firearm_bowling_trap_geometry.gd")
const CommandoFirearmHitFeedbackDispatcher := preload("res://scripts/characters/commando_firearm_hit_feedback_dispatcher.gd")
const CommandoFirearmOriginGeometry := preload("res://scripts/characters/commando_firearm_origin_geometry.gd")
const CommandoFirearmProfileResolver := preload("res://scripts/characters/commando_firearm_profile_resolver.gd")
const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")


static func consume_runtime_boss_guard(
	target: Object,
	ball_vel: Vector2,
	context: Dictionary,
	deps: Dictionary,
	field_width: float,
	base_weapon_id: String,
	weapon_profiles: Dictionary,
	weapon_profile_overrides: Dictionary,
	weapon_hit_feedback: Dictionary,
	hit_feedback_profile_overrides: Dictionary,
	guard_knockback_power: float,
	guard_stun_frames: float,
	guard_knockback_frames: float,
	guard_knockback_decay: float
) -> Dictionary:
	if target == null or not bool(target.get("bowling_trap_guard_armed")):
		return {}

	var source: String = str(target.get("bowling_trap_guard_source"))
	if source == "":
		source = "commando_bowling_trap_guard"
	var restore_speed: float = max(1.0, float(target.get("bowling_trap_guard_restore_speed")))
	CommandoFirearmBowlingTrapGeometry.apply_guard_state(
		target,
		CommandoFirearmBowlingTrapGeometry.build_cleared_guard_state()
	)

	var next_ball_vel: Vector2 = CommandoFirearmBowlingTrapGeometry.soften_guard_ball(ball_vel, restore_speed)
	if CommandoFirearmBowlingTrapGeometry.is_stage2_boss_status_immune(context, deps):
		return CommandoFirearmBowlingTrapGeometry.build_guard_immune_result(next_ball_vel)

	var boss_center: Vector2 = CommandoFirearmOriginGeometry.get_boss_target_pos(context, field_width)
	var knockback_vel: float = CommandoFirearmBowlingTrapGeometry.get_guard_knockback_velocity(
		boss_center,
		context,
		field_width,
		guard_knockback_power
	)
	var feedback_profile: Dictionary = CommandoFirearmProfileResolver.get_hit_feedback_profile(
		"bowling_trap",
		weapon_hit_feedback,
		hit_feedback_profile_overrides
	)
	var profile: Dictionary = CommandoFirearmProfileResolver.get_weapon_profile(
		"bowling_trap",
		weapon_profiles,
		weapon_profile_overrides
	)
	var applied_status := _apply_boss_guard_status(
		deps,
		knockback_vel,
		guard_stun_frames,
		guard_knockback_frames,
		guard_knockback_decay,
		source
	)
	if not applied_status:
		_apply_boss_guard_ai_knockback(
			deps,
			knockback_vel,
			guard_knockback_frames,
			guard_knockback_decay
		)

	CommandoFirearmHitFeedbackDispatcher.spawn_shared_impact_particles(
		boss_center,
		CommandoFirearmValueUtils.get_color(profile.get("color", Color.WHITE), Color.WHITE),
		next_ball_vel,
		float(feedback_profile.get("intensity", 0.82)),
		deps
	)
	CommandoFirearmHitFeedbackDispatcher.trigger_hit_feedback(feedback_profile, deps)
	CommandoFirearmHitFeedbackDispatcher.trigger_boss_hit_animation(context, deps)
	CommandoFirearmHitFeedbackDispatcher.register_ball_hit_pulse(
		boss_center,
		next_ball_vel,
		0.9,
		"bowling_trap_guard",
		deps,
		base_weapon_id
	)
	return CommandoFirearmBowlingTrapGeometry.build_guard_hit_result(
		next_ball_vel,
		knockback_vel,
		source,
		guard_stun_frames,
		restore_speed
	)


static func _apply_boss_guard_status(
	deps: Dictionary,
	knockback_vel: float,
	stun_frames: float,
	knockback_frames: float,
	knockback_decay: float,
	source: String
) -> bool:
	var status_effect_state: Object = deps.get("status_effect_state", null)
	if status_effect_state == null or not status_effect_state.has_method("apply_status"):
		return false
	status_effect_state.apply_status(
		"boss",
		"stun",
		stun_frames,
		CommandoFirearmBowlingTrapGeometry.build_guard_status_data(
			knockback_vel,
			knockback_frames,
			knockback_decay,
			source
		),
		source
	)
	return true


static func _apply_boss_guard_ai_knockback(
	deps: Dictionary,
	knockback_vel: float,
	knockback_frames: float,
	knockback_decay: float
) -> void:
	var ai_state: Object = deps.get("ai_state", null)
	if ai_state == null or not ai_state.has_method("start_paddle_hit_knockback"):
		return
	ai_state.start_paddle_hit_knockback(
		knockback_vel,
		knockback_frames,
		knockback_decay,
		true
	)
