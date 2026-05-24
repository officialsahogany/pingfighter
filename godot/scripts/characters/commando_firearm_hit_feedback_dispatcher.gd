extends RefCounted

const CommandoFirearmAudioResolver := preload("res://scripts/characters/commando_firearm_audio_resolver.gd")


static func spawn_shared_impact_particles(
	pos: Vector2,
	color: Color,
	velocity: Vector2,
	intensity: float,
	deps: Dictionary
) -> void:
	var impact_effects: Object = deps.get("impact_effects", null)
	if impact_effects == null or not impact_effects.has_method("spawn_hit_particles"):
		return
	impact_effects.spawn_hit_particles(pos, color, velocity, intensity, velocity.length())


static func trigger_hit_feedback(feedback_profile: Dictionary, deps: Dictionary) -> void:
	var feedback: Object = deps.get("feedback", null)
	if feedback == null:
		return
	var shake_amount: float = float(feedback_profile.get("shake_amount", 0.04))
	var shake_intensity: float = float(feedback_profile.get("shake_intensity", 1.2))
	if feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(shake_amount, shake_intensity)
	elif feedback.has_method("set_screen_shake"):
		feedback.set_screen_shake(shake_amount, shake_intensity)


static func trigger_boss_hit_animation(context: Dictionary, deps: Dictionary) -> void:
	var animation_state: Object = deps.get("animation_state", null)
	if animation_state == null or not animation_state.has_method("trigger_boss_hit"):
		return
	animation_state.trigger_boss_hit(
		float(context.get("boss_vel", 0.0)),
		bool(context.get("boss_has_hit_sprite", false))
	)


static func register_ball_hit_pulse(
	pos: Vector2,
	velocity: Vector2,
	intensity: float,
	weapon_id: String,
	deps: Dictionary,
	base_weapon_id: String
) -> void:
	var ball_effects: Object = deps.get("ball_effects", null)
	if ball_effects == null or not ball_effects.has_method("register_hit_pulse"):
		return
	ball_effects.register_hit_pulse(
		pos,
		velocity,
		clamp(intensity, 0.0, 1.0),
		CommandoFirearmAudioResolver.get_ball_hit_pulse_kind(weapon_id, base_weapon_id)
	)
