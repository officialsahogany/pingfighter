extends RefCounted

const BallContextReader := preload("res://scripts/ball/ball_context_reader.gd")
const PaddleBounceEventRouter := preload("res://scripts/ball/paddle_bounce_event_router.gd")
const PaddleBounceBossPostHitHandler := preload("res://scripts/ball/paddle_bounce_boss_post_hit_handler.gd")
const PaddleBouncePlayerPostHitHandler := preload("res://scripts/ball/paddle_bounce_player_post_hit_handler.gd")
const PaddleBouncePowerHitHandler := preload("res://scripts/ball/paddle_bounce_power_hit_handler.gd")

var boss_post_hit_handler: Object = PaddleBounceBossPostHitHandler.new()
var event_router: Object = PaddleBounceEventRouter.new()
var player_post_hit_handler: Object = PaddleBouncePlayerPostHitHandler.new()
var power_hit_handler: Object = PaddleBouncePowerHitHandler.new()


func apply(
	is_player: bool,
	ball_pos: Vector2,
	ball_vel: Vector2,
	hit_pos: float,
	paddle_w: float,
	power_activated: bool,
	was_power_smashing: bool,
	drive_activated: bool,
	ball_spin_strength: float,
	drive_speed_increase: float,
	drive_ball_active: bool,
	drive_hit_boss: bool,
	special_gauge: float,
	context: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var power_state: Object = deps.get("power_state", null)
	var physics: Object = deps.get("ball_physics", null)
	ball_vel = power_hit_handler.apply(
		ball_pos,
		ball_vel,
		paddle_w,
		power_activated,
		power_state,
		physics,
		context
	)

	var player_speed: float = float(context.get("player_speed", 0.0))
	var boss_vel: float = float(context.get("boss_vel", 0.0))
	if is_player:
		var player_result: Dictionary = player_post_hit_handler.apply(
			ball_pos,
			hit_pos,
			power_activated,
			drive_activated,
			special_gauge,
			context,
			deps,
			event_router
		)
		ball_pos = _get_vector2(player_result, "ball_pos", ball_pos)
		special_gauge = float(player_result.get("special_gauge", special_gauge))
		player_speed = float(player_result.get("player_speed", player_speed))
		boss_vel = float(player_result.get("boss_vel", boss_vel))
		var whip_state: Object = deps.get("stage1_dalji_whip_skill_state", null)
		if whip_state != null and whip_state.has_method("register_player_hit"):
			var whip_result: Dictionary = whip_state.register_player_hit(ball_vel, context)
			ball_vel = _get_vector2(whip_result, "ball_vel", ball_vel)
	else:
		var boss_result: Dictionary = boss_post_hit_handler.apply(
			ball_pos,
			ball_vel,
			ball_spin_strength,
			drive_speed_increase,
			drive_ball_active,
			drive_hit_boss,
			was_power_smashing,
			context,
			deps,
			event_router
		)
		ball_pos = _get_vector2(boss_result, "ball_pos", ball_pos)
		ball_vel = _get_vector2(boss_result, "ball_vel", ball_vel)
		ball_spin_strength = float(boss_result.get("ball_spin_strength", ball_spin_strength))
		drive_speed_increase = float(boss_result.get("drive_speed_increase", drive_speed_increase))
		drive_hit_boss = bool(boss_result.get("drive_hit_boss", drive_hit_boss))

	event_router.register_rally_feedback(ball_pos, ball_vel, is_player, power_activated, deps)
	return {
		"ball_pos": ball_pos,
		"ball_vel": ball_vel,
		"ball_spin_strength": ball_spin_strength,
		"drive_speed_increase": drive_speed_increase,
		"drive_hit_boss": drive_hit_boss,
		"special_gauge": special_gauge,
		"player_speed": player_speed,
		"boss_vel": boss_vel,
	}


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BallContextReader.get_vector2(source, key, fallback)
