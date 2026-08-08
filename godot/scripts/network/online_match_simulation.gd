extends RefCounted

const BallPhysics := preload("res://scripts/ball/ball_physics.gd")
const BallUpdateStaticConfig := preload("res://scripts/ball/ball_update_static_config.gd")
const MatchScoreState := preload("res://scripts/core/match_score_state.gd")
const OnlineMatchProtocol := preload("res://scripts/network/online_match_protocol.gd")
const OnlinePaddleState := preload("res://scripts/network/online_paddle_state.gd")
const PaddleBounceController := preload("res://scripts/ball/paddle_bounce_controller.gd")
const PaddleBounceFrameState := preload("res://scripts/ball/paddle_bounce_frame_state.gd")
const PaddleBounceState := preload("res://scripts/ball/paddle_bounce_state.gd")
const RoundFlowState := preload("res://scripts/core/round_flow_state.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const PADDLE_WIDTH := 155.0
const PADDLE_HEIGHT := 50.0

var host_paddle: Object = OnlinePaddleState.new()
var client_paddle: Object = OnlinePaddleState.new()
var match_score_state: Object = null
var round_flow_state: Object = null
var ball_physics: Object = BallPhysics.new()
var ball_update_static_config: Object = BallUpdateStaticConfig.new()
var paddle_bounce_state: Object = PaddleBounceState.new()
var paddle_bounce_controller: Object = PaddleBounceController.new()
var paddle_bounce_frame_state: Object = PaddleBounceFrameState.new()
var bounce_config: Dictionary = ball_update_static_config.build_update_config()

var ball_pos := Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT * 0.5)
var ball_vel := Vector2.ZERO
var ball_active := false
var vertical_bounce_count := 0
var rally_speed_cap_bonus := 0.0
var max_ball_speed := 0.0
var winner_side := ""


func configure(score_state: Object = null, serve_state: Object = null) -> void:
	match_score_state = score_state if score_state != null else MatchScoreState.new()
	round_flow_state = serve_state if serve_state != null else RoundFlowState.new()
	bounce_config = ball_update_static_config.build_update_config()
	ball_physics.configure_context(1, "champion", false, "")


func reset_match() -> void:
	if match_score_state == null or round_flow_state == null:
		configure()
	host_paddle.reset("host")
	client_paddle.reset("client")
	match_score_state.reset()
	round_flow_state.reset_game()
	ball_pos = Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT * 0.5)
	ball_vel = Vector2.ZERO
	ball_active = false
	vertical_bounce_count = 0
	_reset_rally_physics_state()
	winner_side = ""


func step(delta: float, host_input: Dictionary, client_input: Dictionary, match_phase: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if match_phase == "finished":
		return events

	var host_motion: Dictionary = host_paddle.step(delta, host_input)
	var client_motion: Dictionary = client_paddle.step(delta, client_input)
	if bool(host_motion.get("dash_started", false)):
		events.append(_event("dash", host_paddle.position.x + PADDLE_WIDTH * 0.5, 0.0, bool(host_motion.get("half_dash", false))))
	if bool(client_motion.get("dash_started", false)):
		events.append(_event("dash", client_paddle.position.x + PADDLE_WIDTH * 0.5, 0.0, bool(client_motion.get("half_dash", false))))

	round_flow_state.update_serve_banner(delta)
	if ball_active:
		events.append_array(_step_ball(delta))
	elif match_phase == "serve_wait":
		var serve_ready := bool(round_flow_state.update_waiting(delta))
		var host_serves := bool(round_flow_state.does_player_serve())
		var serve_edge := (
			bool(host_input.get("serve_edge", false))
			if host_serves
			else bool(client_input.get("serve_edge", false))
		)
		if serve_ready and serve_edge:
			_start_serve(host_serves)
			events.append(_event("serve", ball_pos.x, ball_vel.length()))
	return events


func build_snapshot(
	tick: int,
	match_phase: String,
	ack_input_tick: int,
	event: Dictionary = {},
	countdown_remaining: float = 0.0
) -> Dictionary:
	var score: Dictionary = match_score_state.get_snapshot()
	var serve: Dictionary = round_flow_state.get_snapshot()
	return OnlineMatchProtocol.sanitize_match_snapshot({
		"tick": tick,
		"ack_input_tick": ack_input_tick,
		"ball_pos": OnlineMatchProtocol.vector_to_wire(ball_pos),
		"ball_vel": OnlineMatchProtocol.vector_to_wire(ball_vel),
		"ball_active": ball_active,
		"p_host": host_paddle.get_snapshot(),
		"p_client": client_paddle.get_snapshot(),
		"score": {
			"host": int(score.get("player_score", 0)),
			"client": int(score.get("boss_score", 0)),
			"deuce_mode": bool(score.get("deuce_mode", false)),
			"deuce_goal": int(score.get("deuce_goal", 8)),
			"win_goal": int(score.get("win_goal", 7)),
		},
		"serve": {
			"waiting": bool(serve.get("waiting_for_serve", true)),
			"owner_side": "host" if bool(serve.get("player_serves", true)) else "client",
			"serve_timer": float(serve.get("serve_timer", 0.0)),
			"serve_delay": float(serve.get("serve_delay", 1.0)),
			"banner_timer": float(serve.get("serve_banner_timer", 0.0)),
		},
		"match_phase": match_phase,
		"countdown_remaining": countdown_remaining,
		"winner_side": winner_side,
		"event": event,
	})


func apply_authoritative_snapshot(snapshot: Dictionary) -> void:
	var clean := OnlineMatchProtocol.sanitize_match_snapshot(snapshot)
	ball_pos = OnlineMatchProtocol.wire_to_vector(clean.get("ball_pos", {}), ball_pos)
	ball_vel = OnlineMatchProtocol.wire_to_vector(clean.get("ball_vel", {}), ball_vel)
	ball_active = bool(clean.get("ball_active", false))
	host_paddle.apply_snapshot(clean.get("p_host", {}))
	client_paddle.apply_snapshot(clean.get("p_client", {}))
	var score: Dictionary = clean.get("score", {})
	match_score_state.force_score(int(score.get("host", 0)), int(score.get("client", 0)))
	match_score_state.deuce_mode = bool(score.get("deuce_mode", match_score_state.deuce_mode))
	match_score_state.deuce_goal = int(score.get("deuce_goal", match_score_state.deuce_goal))
	var serve: Dictionary = clean.get("serve", {})
	round_flow_state.waiting_for_serve = bool(serve.get("waiting", true))
	round_flow_state.player_serves = str(serve.get("owner_side", "host")) == "host"
	round_flow_state.serve_timer = float(serve.get("serve_timer", 0.0))
	round_flow_state.serve_target_delay = float(serve.get("serve_delay", 1.0))
	round_flow_state.serve_banner_timer = float(serve.get("banner_timer", 0.0))
	winner_side = str(clean.get("winner_side", ""))


func reset_client_paddle_to_snapshot(snapshot: Dictionary) -> void:
	client_paddle.apply_snapshot(snapshot)


func _start_serve(host_serves: bool) -> void:
	ball_pos = Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT * 0.5)
	ball_vel = ball_physics.build_serve_velocity(host_serves)
	ball_active = true
	vertical_bounce_count = 0
	round_flow_state.begin_serve(Time.get_ticks_msec())


func _step_ball(delta: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var fps_scale := delta * 60.0
	var ball_radius := float(bounce_config["ball_size"]) * 0.5
	var distance := ball_vel.length() * fps_scale
	var substep_distance := maxf(1.0, float(bounce_config["max_step_distance"]))
	var substeps := maxi(1, int(ceil(distance / substep_distance)))
	var substep_scale := fps_scale / float(substeps)
	for _substep in range(substeps):
		var previous_pos := ball_pos
		ball_pos += ball_vel * substep_scale
		if ball_pos.x - ball_radius <= 0.0 and ball_vel.x < 0.0:
			ball_pos.x = ball_radius
			ball_vel.x = absf(ball_vel.x)
			events.append(_event("wall", ball_pos.x, ball_vel.length()))
		elif ball_pos.x + ball_radius >= FIELD_WIDTH and ball_vel.x > 0.0:
			ball_pos.x = FIELD_WIDTH - ball_radius
			ball_vel.x = -absf(ball_vel.x)
			events.append(_event("wall", ball_pos.x, ball_vel.length()))

		if _try_paddle_collision(previous_pos, host_paddle, -1.0, true):
			events.append(_event("paddle", ball_pos.x, ball_vel.length()))
		elif _try_paddle_collision(previous_pos, client_paddle, 1.0, false):
			events.append(_event("paddle", ball_pos.x, ball_vel.length()))

		if ball_pos.y + ball_radius < 0.0:
			events.append_array(_score_point("host"))
			break
		if ball_pos.y - ball_radius > FIELD_HEIGHT:
			events.append_array(_score_point("client"))
			break
	return events


func _try_paddle_collision(previous_pos: Vector2, paddle: Object, outgoing_y: float, is_host: bool) -> bool:
	var ball_radius := float(bounce_config["ball_size"]) * 0.5
	var hitbox_padding := float(bounce_config["hitbox_padding"])
	if is_host and ball_vel.y <= 0.0:
		return false
	if not is_host and ball_vel.y >= 0.0:
		return false
	var paddle_rect := Rect2(paddle.position, Vector2(PADDLE_WIDTH, PADDLE_HEIGHT))
	var facing_surface := paddle_rect.position.y - hitbox_padding if is_host else paddle_rect.end.y + hitbox_padding
	var crossed_surface := (
		previous_pos.y + ball_radius <= facing_surface
		and ball_pos.y + ball_radius >= facing_surface
		if is_host
		else previous_pos.y - ball_radius >= facing_surface
		and ball_pos.y - ball_radius <= facing_surface
	)
	if not crossed_surface:
		return false
	if (
		ball_pos.x + ball_radius < paddle_rect.position.x - hitbox_padding
		or ball_pos.x - ball_radius > paddle_rect.end.x + hitbox_padding
	):
		return false
	var separation := float(bounce_config["ball_size"])
	ball_pos.y = paddle_rect.position.y - separation if is_host else paddle_rect.end.y + separation
	var hit_pos := clampf(
		(ball_pos.x - (paddle_rect.position.x + PADDLE_WIDTH * 0.5)) / (PADDLE_WIDTH * 0.5),
		-1.0,
		1.0
	)
	ball_vel = _resolve_canonical_paddle_bounce(hit_pos, outgoing_y)
	return true


func _score_point(scoring_side: String) -> Array[Dictionary]:
	ball_active = false
	ball_vel = Vector2.ZERO
	ball_pos = Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT * 0.5)
	_reset_rally_physics_state()
	var score_side := MatchScoreState.SIDE_PLAYER if scoring_side == "host" else MatchScoreState.SIDE_BOSS
	var result: Dictionary = match_score_state.score_for(score_side)
	if bool(result.get("match_finished", false)):
		winner_side = scoring_side
	else:
		round_flow_state.set_player_serves(bool(result.get("next_player_serves", true)))
		round_flow_state.prepare_serve_after_scoreboard()
		host_paddle.reset_round()
		client_paddle.reset_round()
	return [_event("score", ball_pos.x), _event("match_finished" if winner_side != "" else "round_reset")]


func _resolve_canonical_paddle_bounce(hit_pos: float, outgoing_y: float) -> Vector2:
	# Resolve both sides in the production player's lower-side coordinate frame.
	# Mirroring the complete upper-side input/output (rather than only the base
	# angle) also mirrors every canonical random contact rotation and stall-guard
	# adjustment. Thus sign(outgoing x) == sign(hit_pos) on both sides.
	var mirror_upper_side := outgoing_y > 0.0
	var resolver_ball_vel := ball_vel
	var resolver_outgoing_y := outgoing_y
	if mirror_upper_side:
		resolver_ball_vel.y = -resolver_ball_vel.y
		resolver_outgoing_y = -1.0
	var speed: float = float(paddle_bounce_state.get_initial_speed(resolver_ball_vel))
	var angle_rad := deg_to_rad(
		hit_pos * float(bounce_config["max_bounce_angle"])
	)
	var canonical_frame: Dictionary = paddle_bounce_frame_state.build(
		{"vertical_bounce_count": vertical_bounce_count},
		ball_physics,
		resolver_ball_vel,
		speed,
		angle_rad
	)
	# Both online sides use the player branch. This preserves the symmetric
	# Han Miryang contract while reusing the production contact-shape, speed,
	# random-curve, minimum-vertical, and vertical-stall resolvers as one unit.
	var result: Dictionary = paddle_bounce_state.resolve_velocity(
		resolver_ball_vel,
		hit_pos,
		true,
		resolver_ball_vel.x,
		resolver_outgoing_y,
		speed,
		angle_rad,
		false,
		float(canonical_frame["accel_scale"]),
		vertical_bounce_count,
		ball_physics,
		null,
		0.0,
		0.0,
		maxf(float(bounce_config["min_ball_speed"]), ball_physics.get_minimum_rally_speed()),
		max_ball_speed
	)
	vertical_bounce_count = int(result.get("vertical_bounce_count", vertical_bounce_count))
	var resolved_velocity: Variant = result.get("ball_vel", ball_vel)
	var next_velocity: Vector2 = ball_vel
	if resolved_velocity is Vector2:
		next_velocity = resolved_velocity
		if mirror_upper_side:
			next_velocity.y = -next_velocity.y
	_apply_canonical_rally_cap_progression()
	return next_velocity


func _apply_canonical_rally_cap_progression() -> void:
	var progression: Dictionary = {}
	var context := {
		"rally_speed_cap_increase_per_hit": float(bounce_config["rally_speed_cap_increase_per_hit"]),
		"rally_speed_cap_bonus_max": float(bounce_config["rally_speed_cap_bonus_max"]),
		"rally_speed_cap_bonus": rally_speed_cap_bonus,
		"max_ball_speed": max_ball_speed,
		"impact_boost_max_ball_speed": max_ball_speed,
		"fire_weather_speed_cap_active": false,
	}
	paddle_bounce_controller.apply_rally_speed_cap_progression(progression, context)
	rally_speed_cap_bonus = float(progression.get("rally_speed_cap_bonus", rally_speed_cap_bonus))
	max_ball_speed = float(progression.get("max_ball_speed", max_ball_speed))


func _reset_rally_physics_state() -> void:
	rally_speed_cap_bonus = 0.0
	max_ball_speed = float(bounce_config["max_ball_speed"])


func _event(kind: String, source_x: float = FIELD_WIDTH * 0.5, speed: float = 0.0, half_dash: bool = false) -> Dictionary:
	return {
		"kind": kind,
		"source_x": source_x,
		"speed": speed,
		"half_dash": half_dash,
	}
