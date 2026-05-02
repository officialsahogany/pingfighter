extends RefCounted

const BallContextReader := preload("res://scripts/ball/ball_context_reader.gd")
const PaddleBounceFrameState := preload("res://scripts/ball/paddle_bounce_frame_state.gd")
const PaddleBouncePlayerSkillStep := preload("res://scripts/ball/paddle_bounce_player_skill_step.gd")
const PaddleBouncePostHitHandler := preload("res://scripts/ball/paddle_bounce_post_hit_handler.gd")
const PaddleBouncePostHitStep := preload("res://scripts/ball/paddle_bounce_post_hit_step.gd")
const PaddleBounceSkillFlow := preload("res://scripts/ball/paddle_bounce_skill_flow.gd")
const PaddleBounceVelocityStep := preload("res://scripts/ball/paddle_bounce_velocity_step.gd")

var frame_state: Object = PaddleBounceFrameState.new()
var player_skill_step: Object = PaddleBouncePlayerSkillStep.new()
var post_hit_handler: Object = PaddleBouncePostHitHandler.new()
var post_hit_step: Object = PaddleBouncePostHitStep.new()
var skill_flow: Object = PaddleBounceSkillFlow.new()
var velocity_step: Object = PaddleBounceVelocityStep.new()


func bounce(
	paddle_x: float,
	paddle_w: float,
	is_player: bool,
	context: Dictionary,
	deps: Dictionary,
	callbacks: Dictionary = {}
) -> Dictionary:
	var ball_pos: Vector2 = _get_vector2(context, "ball_pos", Vector2.ZERO)
	var ball_vel: Vector2 = _get_vector2(context, "ball_vel", Vector2.ZERO)
	var pre_hit_speed: float = ball_vel.length()
	var incoming_dx: float = ball_vel.x
	var hit_pos: float = (ball_pos.x - (paddle_x + paddle_w * 0.5)) / (paddle_w * 0.5)
	hit_pos = clamp(hit_pos, -1.0, 1.0)

	var power_state = deps.get("power_state", null)
	var was_power_smashing: bool = power_state != null and (
		power_state.is_parabola_active() or power_state.is_freeze_active()
	)
	var physics = deps.get("ball_physics", null)
	var paddle_bounce_state = deps.get("paddle_bounce_state", null)
	if paddle_bounce_state == null:
		return {}

	var outgoing_direction: float = -1.0 if is_player else 1.0
	var speed: float = float(paddle_bounce_state.get_initial_speed(ball_vel))
	var angle_rad: float = deg_to_rad(hit_pos * float(context.get("max_bounce_angle", 60.0)))
	var frame: Dictionary = frame_state.build(context, physics, ball_vel, pre_hit_speed, angle_rad)
	var power_activated: bool = false
	var drive_activated: bool = false
	if is_player:
		var skill_step_result: Dictionary = player_skill_step.apply(
			skill_flow,
			frame_state,
			speed,
			angle_rad,
			hit_pos,
			float(frame["accel_scale"]),
			ball_pos,
			frame,
			context,
			deps,
			callbacks
		)
		power_activated = bool(skill_step_result.get("power_activated", false))
		drive_activated = bool(skill_step_result.get("drive_activated", false))
		speed = float(skill_step_result.get("speed", speed))
		angle_rad = float(skill_step_result.get("angle_rad", angle_rad))

	var velocity_step_result: Dictionary = velocity_step.apply(
		paddle_bounce_state,
		frame_state,
		ball_vel,
		hit_pos,
		is_player,
		incoming_dx,
		outgoing_direction,
		speed,
		angle_rad,
		drive_activated,
		frame,
		physics,
		deps,
		context
	)
	ball_vel = _get_vector2(velocity_step_result, "ball_vel", ball_vel)

	var post_hit_result: Dictionary = post_hit_step.apply(
		post_hit_handler,
		frame_state,
		is_player,
		ball_pos,
		ball_vel,
		hit_pos,
		paddle_w,
		power_activated,
		was_power_smashing,
		drive_activated,
		frame,
		context,
		deps
	)
	ball_pos = _get_vector2(post_hit_result, "ball_pos", ball_pos)
	ball_vel = _get_vector2(post_hit_result, "ball_vel", ball_vel)
	var player_speed: float = float(post_hit_result.get("player_speed", context.get("player_speed", 0.0)))
	var boss_vel: float = float(post_hit_result.get("boss_vel", context.get("boss_vel", 0.0)))
	return frame_state.build_result_snapshot(frame, ball_pos, ball_vel, player_speed, boss_vel)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BallContextReader.get_vector2(source, key, fallback)
