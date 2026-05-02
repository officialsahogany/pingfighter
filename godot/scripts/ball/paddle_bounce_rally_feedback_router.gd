extends RefCounted


func register(
	ball_pos: Vector2,
	ball_vel: Vector2,
	is_player: bool,
	power_activated: bool,
	deps: Dictionary
) -> void:
	var ball_intensity = deps.get("ball_intensity", null)
	if ball_intensity != null:
		ball_intensity.register_hit("player" if is_player else "boss")

	var impact_effects = deps.get("impact_effects", null)
	if impact_effects != null:
		var intensity: float = 0.0
		if ball_intensity != null:
			intensity = float(ball_intensity.calculate(ball_vel))
		impact_effects.create_energy_explosion(ball_pos, 0.8, intensity)
		impact_effects.spawn_paddle_hit_particles(ball_pos, is_player)

	var feedback = deps.get("feedback", null)
	if feedback != null:
		feedback.set_screen_shake(0.10, 3.0)

	if not power_activated:
		var audio = deps.get("audio", null)
		if audio != null:
			audio.play_paddle_hit()
