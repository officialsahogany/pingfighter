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
	var paddle_center_x: float = paddle_x + paddle_w * 0.5
	var contact_offset_x: float = ball_pos.x - paddle_center_x
	# Negative contact offset means the ball hit left of paddle center;
	# positive / zero means right. Player attack-sheet selection consumes
	# this same sign through `hit_pos`.
	var hit_pos: float = contact_offset_x / (paddle_w * 0.5)
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
	var result: Dictionary = frame_state.build_result_snapshot(frame, ball_pos, ball_vel, player_speed, boss_vel)
	if post_hit_result.has("runtime_perk_gold"):
		result["runtime_perk_gold"] = int(post_hit_result.get("runtime_perk_gold", 0))
	for key in [
		"player_collision_cooldown",
		"boss_collision_cooldown",
		"smasher_wheel_speed_cap",
		"smasher_wheel_hit",
		"rainbow_fur_glove_activated",
		"rainbow_fur_glove_cooldown_reduction_pct",
		"shrapnel_armor_activated",
		"shrapnel_armor_shard_count",
		"shrapnel_armor_gauge_cost",
		"blacksmith_thor_shield_hit",
		"blacksmith_thor_shield_hit_pos",
		"blacksmith_umbrella_open",
		"blacksmith_umbrella_anim_timer",
		"blacksmith_umbrella_retracting",
		"blacksmith_umbrella_anim_direction",
		"blacksmith_umbrella_open_ratio",
		"blacksmith_thor_shield_open_ratio",
		"blacksmith_umbrella_raise_amount",
		"blacksmith_umbrella_shield_open_amount",
		"blacksmith_umbrella_visual_state",
		"blacksmith_umbrella_folded",
		"blacksmith_umbrella_deployed",
		"blacksmith_umbrella_swing_active",
		"blacksmith_umbrella_swing_direction",
		"blacksmith_umbrella_swing_timer",
		"blacksmith_umbrella_gauge",
		"blacksmith_umbrella_gauge_max",
		"blacksmith_umbrella_gauge_gain",
		"blacksmith_umbrella_damage_flash_timer",
		"blacksmith_umbrella_hit_pulse_timer",
		"suppress_paddle_hit_knockback",
		"paddle_hit_pulse_kind",
		"paddle_hit_pulse_intensity",
		"commando_bowling_trap_guard_consumed",
		"commando_bowling_trap_guarded",
		"commando_bowling_trap_guard_hit",
		"commando_bowling_trap_guard_armed",
		"commando_bowling_trap_guard_source",
		"commando_bowling_trap_guard_status_source",
		"commando_bowling_trap_guard_knockback_power",
		"commando_bowling_trap_guard_knockback_vel",
		"commando_bowling_trap_guard_stun_frames",
		"commando_bowling_trap_guard_restore_speed",
		"commando_bowling_trap_guard_consumed_restore_speed",
		"commando_suicide_drone_ball_boost_active",
		"commando_suicide_drone_ball_restore_speed",
		"commando_suicide_drone_ball_boosted_speed",
		"commando_suicide_drone_ball_boost_consumed",
		"commando_suicide_drone_ball_restored_speed",
		"lingpet_wild_roar_ball_boost_active",
		"lingpet_wild_roar_ball_restore_speed",
		"lingpet_wild_roar_ball_boost_consumed",
		"lingpet_wild_roar_ball_restored_speed",
		"boss_status_immune",
		"speed_limit_disabled",
	]:
		if post_hit_result.has(key):
			result[key] = post_hit_result[key]
	_apply_rally_speed_cap_progression(result, context)
	return result


func _apply_rally_speed_cap_progression(result: Dictionary, context: Dictionary) -> void:
	var increase: float = max(0.0, float(context.get("rally_speed_cap_increase_per_hit", 0.5)))
	if increase <= 0.0:
		return
	var bonus_max: float = max(0.0, float(context.get("rally_speed_cap_bonus_max", 10.0)))
	var current_bonus: float = max(0.0, float(context.get("rally_speed_cap_bonus", 0.0)))
	var next_bonus: float = min(current_bonus + increase, bonus_max)
	result["rally_speed_cap_bonus"] = next_bonus
	var applied_increase: float = next_bonus - current_bonus
	if applied_increase <= 0.0:
		return
	_raise_cap(result, context, "max_ball_speed", 26.0, applied_increase)
	_raise_cap(result, context, "impact_boost_max_ball_speed", 26.0, applied_increase)
	if bool(context.get("fire_weather_speed_cap_active", false)):
		_raise_cap(result, context, "fire_weather_max_ball_speed", 35.0, applied_increase)


func _raise_cap(
	result: Dictionary,
	context: Dictionary,
	key: String,
	fallback: float,
	increase: float
) -> void:
	var current_cap: float = float(context.get(key, fallback))
	if current_cap >= INF:
		return
	result[key] = current_cap + increase


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BallContextReader.get_vector2(source, key, fallback)
