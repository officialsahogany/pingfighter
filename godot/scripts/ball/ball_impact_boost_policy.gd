extends RefCounted

const BallImpactAngleBoostPolicy := preload("res://scripts/ball/ball_impact_angle_boost_policy.gd")
const BallImpactDecayPolicy := preload("res://scripts/ball/ball_impact_decay_policy.gd")
const BOOST_SOFTEN_SPEED_LOW := 14.0
const BOOST_SOFTEN_SPEED_HIGH := 28.0
const RALLY_MIN_BOOST_RAMP_LOW_SPEED := 7.65
const RALLY_MIN_BOOST_RAMP_HIGH_SPEED := 18.0
const BOOST_DISTANCE_REFERENCE_SPEED := BOOST_SOFTEN_SPEED_LOW
const BOOST_DISTANCE_DECAY_EXPONENT := 0.5
const BOOST_DISTANCE_DECAY_SCALE_CAP := 1.7
const BOOST_MIN_VISIBLE_DECAY_FRAMES := 18.0
const OVERALL_BOOST_SCALE := 0.966
const BALL_IMPACT_STAGE1_CAP := 4.202
const BALL_IMPACT_STAGE2_CAP := 4.395
const BALL_IMPACT_STAGE3_CAP := 4.589
const BALL_IMPACT_NO_CAP := 999.0
const LAUNCH_BURST_MULT := 1.5
const VERTICAL_DECAY_STRENGTH_MULT := 1.6
const ANGLE_DECAY_SECONDS_25_DEG := 1.02
const ANGLE_DECAY_SECONDS_35_DEG := 0.92
const ANGLE_DECAY_SECONDS_45_DEG := 0.82
const BOOST_DECAY_SECONDS := 1.0
const BOOST_DECAY_STRENGTH_MULT := 1.5
const BOOST_DECAY_FPS := 60.0
const BOOST_DECAY_FRAMES := BOOST_DECAY_SECONDS * BOOST_DECAY_FPS / BOOST_DECAY_STRENGTH_MULT
const LAUNCH_DECAY_FRAMES_LOW := BOOST_DECAY_FRAMES
const LAUNCH_DECAY_FRAMES_HIGH := BOOST_DECAY_FRAMES
const LAUNCH_MIN_BOOST_LOW := 0.58
const LAUNCH_MIN_BOOST_HIGH := 0.86
const STRAIGHT_RALLY_MIN_BOOST_ANGLE_DEG := 20.0
const STRAIGHT_RALLY_MIN_BOOST_HIGH := 0.76
const SERVE_LAUNCH_BOOST := 2.637
const SERVE_LAUNCH_MIN_BOOST := 0.74
const SERVE_LAUNCH_DECAY_FRAMES := BOOST_DECAY_FRAMES
const JUNIOR_IMPACT_BOOST_SCALE := 0.55
const JUNIOR_MIN_IMPACT_BOOST := 1.05

var angle_boost_policy: Object = BallImpactAngleBoostPolicy.new()
var decay_policy: Object = BallImpactDecayPolicy.new()


func get_stage_impact_boost_cap(current_stage: int) -> float:
	if current_stage == 1:
		return BALL_IMPACT_STAGE1_CAP
	if current_stage == 2:
		return BALL_IMPACT_STAGE2_CAP
	if current_stage == 3:
		return BALL_IMPACT_STAGE3_CAP
	return BALL_IMPACT_NO_CAP


func compute_dynamic_impact_boost(
	velocity: Vector2,
	current_speed: float,
	launch_angle_rad: float,
	context: Dictionary
) -> Dictionary:
	var speed_ratio: float = _get_speed_ratio(current_speed)
	var angle_boost_multiplier: float = angle_boost_policy.get_multiplier(velocity)
	var base_boost: float = angle_boost_multiplier
	var min_boost_floor: float = 1.1
	if str(context.get("ai_mode", "champion")) == "junior":
		base_boost = 1.0 + (base_boost - 1.0) * JUNIOR_IMPACT_BOOST_SCALE
		min_boost_floor = JUNIOR_MIN_IMPACT_BOOST
	var speed_ratio_softened: float = pow(speed_ratio, 0.7)
	var dynamic_boost: float = base_boost - (base_boost - min_boost_floor) * speed_ratio_softened
	dynamic_boost *= LAUNCH_BURST_MULT
	dynamic_boost *= OVERALL_BOOST_SCALE
	dynamic_boost = min(dynamic_boost, get_stage_impact_boost_cap(int(context.get("current_stage", 1))))

	var launch_angle_deg: float = abs(rad_to_deg(launch_angle_rad))
	var vertical_decay_strength: float = _get_vertical_decay_strength(launch_angle_deg)
	var distance_decay_scale: float = _get_boost_distance_decay_scale(current_speed)
	var launch_decay_frames: float = _get_launch_angle_decay_frames(launch_angle_deg)
	var speed_adjusted_decay_frames: float = max(BOOST_MIN_VISIBLE_DECAY_FRAMES, launch_decay_frames / distance_decay_scale)
	var dynamic_decay_frames: float = speed_adjusted_decay_frames / vertical_decay_strength
	var dynamic_min_boost: float = _get_dynamic_min_boost(current_speed, launch_angle_deg)
	var decay_rate: float = _get_decay_rate(dynamic_boost, dynamic_min_boost, dynamic_decay_frames, speed_ratio)

	return {
		"boost": dynamic_boost,
		"decay_rate": decay_rate,
		"min_boost": dynamic_min_boost,
	}


func compute_serve_launch_impact_boost(velocity: Vector2, context: Dictionary) -> Dictionary:
	var speed_ratio: float = _get_speed_ratio(velocity.length())
	var boost: float = SERVE_LAUNCH_BOOST
	var min_boost: float = SERVE_LAUNCH_MIN_BOOST
	if str(context.get("ai_mode", "champion")) == "junior":
		boost = 1.0 + (boost - 1.0) * JUNIOR_IMPACT_BOOST_SCALE
		min_boost = max(min_boost, JUNIOR_MIN_IMPACT_BOOST)
	var decay_rate: float = _get_decay_rate(boost, min_boost, SERVE_LAUNCH_DECAY_FRAMES, speed_ratio)
	return {
		"boost": boost,
		"decay_rate": decay_rate,
		"min_boost": min_boost,
	}


func apply_impact_decay(
	velocity: Vector2,
	impact_boost: float,
	min_boost: float,
	decay_rate: float,
	fps_scale: float
) -> float:
	return decay_policy.apply(velocity, impact_boost, min_boost, decay_rate, fps_scale)


func _get_launch_angle_decay_frames(launch_angle_deg: float) -> float:
	if launch_angle_deg >= 45.0:
		return ANGLE_DECAY_SECONDS_45_DEG * BOOST_DECAY_FPS / BOOST_DECAY_STRENGTH_MULT
	if launch_angle_deg >= 35.0:
		return ANGLE_DECAY_SECONDS_35_DEG * BOOST_DECAY_FPS / BOOST_DECAY_STRENGTH_MULT
	if launch_angle_deg >= 25.0:
		return ANGLE_DECAY_SECONDS_25_DEG * BOOST_DECAY_FPS / BOOST_DECAY_STRENGTH_MULT
	return BOOST_DECAY_FRAMES


func _get_vertical_decay_strength(launch_angle_deg: float) -> float:
	if launch_angle_deg >= 25.0:
		return 1.0
	var vertical_ratio: float = 1.0 - clamp(launch_angle_deg / 25.0, 0.0, 1.0)
	return lerp(1.0, VERTICAL_DECAY_STRENGTH_MULT, vertical_ratio)


func _get_boost_distance_decay_scale(current_speed: float) -> float:
	var reference_speed: float = max(1.0, BOOST_DISTANCE_REFERENCE_SPEED)
	var speed_ratio: float = max(1.0, current_speed / reference_speed)
	return min(BOOST_DISTANCE_DECAY_SCALE_CAP, pow(speed_ratio, BOOST_DISTANCE_DECAY_EXPONENT))


func _get_speed_ratio(current_speed: float) -> float:
	if current_speed <= BOOST_SOFTEN_SPEED_LOW:
		return 0.0
	if current_speed >= BOOST_SOFTEN_SPEED_HIGH:
		return 1.0
	return (
		(current_speed - BOOST_SOFTEN_SPEED_LOW)
		/ (BOOST_SOFTEN_SPEED_HIGH - BOOST_SOFTEN_SPEED_LOW)
	)


func _get_min_boost_ramp_ratio(current_speed: float) -> float:
	if current_speed <= RALLY_MIN_BOOST_RAMP_LOW_SPEED:
		return 0.0
	if current_speed >= RALLY_MIN_BOOST_RAMP_HIGH_SPEED:
		return 1.0
	return (
		(current_speed - RALLY_MIN_BOOST_RAMP_LOW_SPEED)
		/ (RALLY_MIN_BOOST_RAMP_HIGH_SPEED - RALLY_MIN_BOOST_RAMP_LOW_SPEED)
	)


func _get_dynamic_min_boost(current_speed: float, launch_angle_deg: float) -> float:
	var min_boost_ratio: float = _get_min_boost_ramp_ratio(current_speed)
	var high_min_boost: float = LAUNCH_MIN_BOOST_HIGH
	if launch_angle_deg < STRAIGHT_RALLY_MIN_BOOST_ANGLE_DEG:
		var straight_ratio: float = 1.0 - clamp(
			launch_angle_deg / STRAIGHT_RALLY_MIN_BOOST_ANGLE_DEG,
			0.0,
			1.0
		)
		high_min_boost = lerp(LAUNCH_MIN_BOOST_HIGH, STRAIGHT_RALLY_MIN_BOOST_HIGH, straight_ratio)
	return LAUNCH_MIN_BOOST_LOW + (high_min_boost - LAUNCH_MIN_BOOST_LOW) * min_boost_ratio


func _get_decay_rate(
	dynamic_boost: float,
	dynamic_min_boost: float,
	dynamic_decay_frames: float,
	_speed_ratio: float
) -> float:
	if dynamic_decay_frames <= 0.0 or dynamic_boost <= dynamic_min_boost:
		return 0.95
	return pow(dynamic_min_boost / dynamic_boost, 1.0 / dynamic_decay_frames)
