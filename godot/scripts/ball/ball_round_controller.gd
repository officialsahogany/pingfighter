extends RefCounted

const BallContextReader := preload("res://scripts/ball/ball_context_reader.gd")
const BallRenderInterpolation := preload("res://scripts/ball/ball_render_interpolation.gd")
const BallRoundCleanup := preload("res://scripts/ball/ball_round_cleanup.gd")

var cleanup: Object = BallRoundCleanup.new()


func reset_ball(config: Dictionary, deps: Dictionary, callbacks: Dictionary) -> Dictionary:
	var perf_logger: Object = deps.get("perf_logger", null)
	var sample_start: int = _perf_begin(perf_logger)
	var ball_round_state = deps.get("ball_round_state", null)
	if ball_round_state != null:
		_apply_snapshot(ball_round_state.build_reset_snapshot(
			float(config.get("width", 0.0)),
			float(config.get("height", 0.0))
		), callbacks)
	_perf_end(perf_logger, "process.reset_ball.controller.round_state", sample_start)

	sample_start = _perf_begin(perf_logger)
	cleanup.reset_for_ball_reset(deps)
	_perf_end(perf_logger, "process.reset_ball.controller.cleanup", sample_start)

	sample_start = _perf_begin(perf_logger)
	var player_pos: Vector2 = _get_vector2(config, "player_pos", Vector2.ZERO)
	player_pos.x = float(config.get("width", 0.0)) * 0.5 - float(config.get("player_paddle_width", 0.0)) * 0.5
	player_pos.y = float(config.get("player_y", player_pos.y))
	var boss_pos: Vector2 = _get_vector2(config, "boss_pos", Vector2.ZERO)
	boss_pos.x = float(config.get("width", 0.0)) * 0.5 - float(config.get("boss_paddle_width", 0.0)) * 0.5
	boss_pos.y = float(config.get("boss_y", boss_pos.y))
	_perf_end(perf_logger, "process.reset_ball.controller.positions", sample_start)

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
		_apply_adversity_armor_serve_speed_bonus(snapshot, player_is_serving, deps)
		_apply_snapshot(snapshot, callbacks)
		_trigger_serve_feedback(snapshot, player_is_serving, str(config.get("ball_visual_type", "")), deps)


func _apply_snapshot(snapshot: Dictionary, callbacks: Dictionary) -> void:
	if snapshot.has("ball_pos"):
		BallRenderInterpolation.reset_ball_interpolation(snapshot)
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
		impact_effects.spawn_paddle_hit_particles(ball_pos, player_is_serving, ball_vel, intensity)

	var feedback = deps.get("feedback", null)
	if feedback != null:
		feedback.set_screen_shake(0.10, 3.0)

	var audio = deps.get("audio", null)
	if audio != null and audio.has_method("play_serve"):
		audio.play_serve(ball_visual_type)


func _apply_adversity_armor_serve_speed_bonus(
	snapshot: Dictionary,
	player_is_serving: bool,
	deps: Dictionary
) -> void:
	if not player_is_serving:
		return
	var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("consume_adversity_armor_serve_speed_bonus"):
		return
	var bonus_fraction: float = float(mythic_item_runtime.consume_adversity_armor_serve_speed_bonus())
	if bonus_fraction <= 0.0:
		return
	var ball_vel: Vector2 = _get_vector2(snapshot, "ball_vel", Vector2.ZERO)
	if ball_vel.length() <= 0.01:
		return
	var boosted_vel: Vector2 = ball_vel * (1.0 + bonus_fraction)
	snapshot["ball_vel"] = boosted_vel
	var ball_physics: Object = deps.get("ball_physics", null)
	if ball_physics != null and ball_physics.has_method("compute_serve_launch_impact_boost"):
		var serve_impact: Variant = ball_physics.compute_serve_launch_impact_boost(boosted_vel)
		if serve_impact is Dictionary:
			var impact: Dictionary = serve_impact
			snapshot["ball_impact_boost"] = float(impact.get("boost", snapshot.get("ball_impact_boost", 1.0)))
			snapshot["ball_boost_decay_rate"] = float(impact.get("decay_rate", snapshot.get("ball_boost_decay_rate", 0.975)))
			snapshot["ball_min_boost"] = float(impact.get("min_boost", snapshot.get("ball_min_boost", 0.70)))


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BallContextReader.get_vector2(source, key, fallback)


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
