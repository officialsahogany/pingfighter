extends RefCounted

const PADDLE_HIT_ENERGY_SCALE := 0.52
const PADDLE_HIT_SHAKE_AMOUNT := 0.075
const PADDLE_HIT_SHAKE_AMOUNT_MAX := 0.10
const PADDLE_HIT_SHAKE_INTENSITY := 2.2
const PADDLE_HIT_SHAKE_INTENSITY_MAX := 2.6
const BALL_CONTACT_RADIUS := 14.3


func register(
	ball_pos: Vector2,
	ball_vel: Vector2,
	is_player: bool,
	power_activated: bool,
	deps: Dictionary,
	context: Dictionary = {},
	drive_activated: bool = false
) -> void:
	var ball_intensity = deps.get("ball_intensity", null)
	var intensity: float = 0.0
	if ball_intensity != null:
		ball_intensity.register_hit("player" if is_player else "boss")
		intensity = float(ball_intensity.calculate(ball_vel))

	var ball_effects = deps.get("ball_effects", null)
	var pulse_registered := false
	if ball_effects != null and ball_effects.has_method("register_hit_pulse"):
		var contact_pos: Vector2 = _get_paddle_contact_pos(ball_pos, is_player)
		var pulse_kind: String = str(context.get(
			"paddle_hit_pulse_kind",
			"player_paddle" if is_player else "boss_paddle"
		))
		var pulse_intensity: float = clamp(float(context.get("paddle_hit_pulse_intensity", intensity)), 0.0, 1.0)
		ball_effects.register_hit_pulse(contact_pos, ball_vel, pulse_intensity, pulse_kind)
		pulse_registered = true

	var impact_effects = deps.get("impact_effects", null)
	if not pulse_registered and impact_effects != null:
		var fallback_contact_pos: Vector2 = _get_paddle_contact_pos(ball_pos, is_player)
		impact_effects.create_energy_explosion(fallback_contact_pos, PADDLE_HIT_ENERGY_SCALE, intensity)
		impact_effects.spawn_paddle_hit_particles(fallback_contact_pos, is_player, ball_vel, intensity)

	var feedback = deps.get("feedback", null)
	if feedback != null:
		var shake_amount := lerpf(PADDLE_HIT_SHAKE_AMOUNT, PADDLE_HIT_SHAKE_AMOUNT_MAX, clampf(intensity, 0.0, 1.0))
		var shake_intensity := lerpf(PADDLE_HIT_SHAKE_INTENSITY, PADDLE_HIT_SHAKE_INTENSITY_MAX, clampf(intensity, 0.0, 1.0))
		if feedback.has_method("max_screen_shake"):
			feedback.max_screen_shake(shake_amount, shake_intensity)
		elif feedback.has_method("set_screen_shake"):
			feedback.set_screen_shake(shake_amount, shake_intensity)
		if is_player and feedback.has_method("trigger_paddle_hit_vibration"):
			feedback.trigger_paddle_hit_vibration(ball_vel.length(), is_player, drive_activated, power_activated)

	if not power_activated and not _should_suppress_paddle_hit_audio(is_player, context, deps):
		var audio = deps.get("audio", null)
		if audio != null:
			audio.play_paddle_hit()
			if _did_rally_tier_advance(ball_intensity) and audio.has_method("play_rally_tier_accent"):
				audio.play_rally_tier_accent(_get_rally_tier(ball_intensity))


func _should_suppress_paddle_hit_audio(is_player: bool, context: Dictionary, deps: Dictionary) -> bool:
	if is_player or int(context.get("current_stage", 0)) != 2:
		return false
	if bool(context.get("stage2_speed_defense_active", false)):
		return true
	var stage2_skill_state: Object = deps.get("stage2_boss_skill_state", null)
	return (
		stage2_skill_state != null
		and stage2_skill_state.has_method("is_speed_defense_active")
		and bool(stage2_skill_state.is_speed_defense_active())
	)


func _get_paddle_contact_pos(ball_pos: Vector2, is_player: bool) -> Vector2:
	var y_offset: float = BALL_CONTACT_RADIUS if is_player else -BALL_CONTACT_RADIUS
	return ball_pos + Vector2(0.0, y_offset)


func _did_rally_tier_advance(ball_intensity: Object) -> bool:
	if ball_intensity == null or not ball_intensity.has_method("did_rally_tier_advance"):
		return false
	return bool(ball_intensity.did_rally_tier_advance())


func _get_rally_tier(ball_intensity: Object) -> int:
	if ball_intensity == null or not ball_intensity.has_method("get_rally_tier"):
		return 0
	return int(ball_intensity.get_rally_tier())
