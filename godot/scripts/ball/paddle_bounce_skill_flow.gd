extends RefCounted

const PaddleBounceDriveSkillFlow := preload("res://scripts/ball/paddle_bounce_drive_skill_flow.gd")
const PaddleBounceSkillRouter := preload("res://scripts/ball/paddle_bounce_skill_router.gd")

var drive_skill_flow: Object = PaddleBounceDriveSkillFlow.new()
var skill_router: Object = PaddleBounceSkillRouter.new()


func resolve_player_skills(
	speed: float,
	angle_rad: float,
	hit_pos: float,
	accel_scale: float,
	ball_pos: Vector2,
	ball_spin_strength: float,
	ball_spin_direction: int,
	drive_speed_increase: float,
	drive_ball_active: bool,
	drive_hit_boss: bool,
	special_gauge: float,
	drive_text_timer_frames: float,
	context: Dictionary,
	deps: Dictionary,
	callbacks: Dictionary
) -> Dictionary:
	var state: Dictionary = _build_state(
		speed,
		angle_rad,
		ball_spin_strength,
		ball_spin_direction,
		drive_speed_increase,
		drive_ball_active,
		drive_hit_boss,
		special_gauge,
		drive_text_timer_frames
	)

	if bool(state["drive_ball_active"]) and bool(state["drive_hit_boss"]):
		state.merge(_build_clear_drive_snapshot(deps, false), true)

	var power_result: Dictionary = skill_router.try_activate_power_smashing(
		ball_pos,
		bool(context.get("ball_active", false)),
		float(state["special_gauge"]),
		context,
		deps,
		callbacks
	)
	state["power_activated"] = bool(power_result.get("activated", false))
	state["special_gauge"] = float(power_result.get("special_gauge", state["special_gauge"]))

	if bool(state["power_activated"]):
		state.merge(_build_clear_drive_snapshot(deps, true), true)
	else:
		state.merge(drive_skill_flow.try_activate(skill_router, state, hit_pos, accel_scale, ball_pos, context, deps), true)

	return state


func _build_state(
	speed: float,
	angle_rad: float,
	ball_spin_strength: float,
	ball_spin_direction: int,
	drive_speed_increase: float,
	drive_ball_active: bool,
	drive_hit_boss: bool,
	special_gauge: float,
	drive_text_timer_frames: float
) -> Dictionary:
	return {
		"power_activated": false,
		"drive_activated": false,
		"speed": speed,
		"angle_rad": angle_rad,
		"ball_spin_strength": ball_spin_strength,
		"ball_spin_direction": ball_spin_direction,
		"drive_speed_increase": drive_speed_increase,
		"drive_ball_active": drive_ball_active,
		"drive_hit_boss": drive_hit_boss,
		"special_gauge": special_gauge,
		"drive_text_timer_frames": drive_text_timer_frames,
	}


func _build_clear_drive_snapshot(deps: Dictionary, clear_spin: bool) -> Dictionary:
	return skill_router.build_clear_drive_snapshot(deps.get("ball_spin_state", null), clear_spin)
