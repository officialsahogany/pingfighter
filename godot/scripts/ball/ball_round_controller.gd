extends RefCounted

const BallContextReader := preload("res://scripts/ball/ball_context_reader.gd")
const BallRoundCleanup := preload("res://scripts/ball/ball_round_cleanup.gd")

var cleanup: Object = BallRoundCleanup.new()


func reset_ball(config: Dictionary, deps: Dictionary, callbacks: Dictionary) -> Dictionary:
	var ball_round_state = deps.get("ball_round_state", null)
	if ball_round_state != null:
		_apply_snapshot(ball_round_state.build_reset_snapshot(
			float(config.get("width", 0.0)),
			float(config.get("height", 0.0))
		), callbacks)

	cleanup.reset_for_ball_reset(deps)

	var player_pos: Vector2 = _get_vector2(config, "player_pos", Vector2.ZERO)
	player_pos.x = float(config.get("width", 0.0)) * 0.5 - float(config.get("player_paddle_width", 0.0)) * 0.5
	var boss_pos: Vector2 = _get_vector2(config, "boss_pos", Vector2.ZERO)
	boss_pos.x = float(config.get("width", 0.0)) * 0.5 - float(config.get("boss_paddle_width", 0.0)) * 0.5

	return {
		"player_pos": player_pos,
		"boss_pos": boss_pos,
		"boss_vel": 0.0,
		"player_speed": 0.0,
	}


func serve_ball(config: Dictionary, deps: Dictionary, callbacks: Dictionary) -> void:
	var round_state = deps.get("round_state", null)
	if round_state != null:
		round_state.begin_serve(int(config.get("current_msec", Time.get_ticks_msec())))
	var player_is_serving: bool = round_state == null or round_state.does_player_serve()
	cleanup.reset_for_serve(deps)

	var ball_round_state = deps.get("ball_round_state", null)
	if ball_round_state != null:
		var snapshot: Dictionary = ball_round_state.build_serve_snapshot(
			player_is_serving,
			_get_vector2(config, "player_pos", Vector2.ZERO),
			_get_vector2(config, "boss_pos", Vector2.ZERO),
			float(config.get("player_y", 0.0)),
			float(config.get("boss_y", 0.0)),
			float(config.get("player_paddle_width", 0.0)),
			float(config.get("boss_paddle_width", 0.0)),
			float(config.get("boss_hitbox_height", 0.0)),
			float(config.get("ball_size", 0.0)),
			float(config.get("ball_render_radius", float(config.get("ball_size", 0.0)) * 0.5)),
			deps.get("ball_physics", null)
		)
		_apply_snapshot(snapshot, callbacks)
		_trigger_serve_feedback(snapshot, player_is_serving, str(config.get("ball_visual_type", "")), deps)


func _apply_snapshot(snapshot: Dictionary, callbacks: Dictionary) -> void:
	var apply_callback: Callable = callbacks.get("apply_ball_snapshot", Callable())
	if apply_callback.is_valid():
		apply_callback.call(snapshot)


func _trigger_serve_feedback(
	snapshot: Dictionary,
	player_is_serving: bool,
	ball_visual_type: String,
	deps: Dictionary
) -> void:
	var ball_pos: Vector2 = _get_vector2(snapshot, "ball_pos", Vector2.ZERO)
	var ball_vel: Vector2 = _get_vector2(snapshot, "ball_vel", Vector2.ZERO)
	var impact_effects = deps.get("impact_effects", null)
	var ball_intensity = deps.get("ball_intensity", null)
	if impact_effects != null:
		var intensity: float = 0.0
		if ball_intensity != null and ball_intensity.has_method("calculate"):
			intensity = float(ball_intensity.calculate(ball_vel))
		impact_effects.create_energy_explosion(ball_pos, 0.8, intensity)
		impact_effects.spawn_paddle_hit_particles(ball_pos, player_is_serving)

	var feedback = deps.get("feedback", null)
	if feedback != null:
		feedback.trigger_hit_flash(0.08)
		feedback.set_screen_shake(0.10, 3.0)

	var audio = deps.get("audio", null)
	if audio != null and audio.has_method("play_serve"):
		audio.play_serve(ball_visual_type)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BallContextReader.get_vector2(source, key, fallback)
