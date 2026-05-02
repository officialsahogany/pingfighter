extends RefCounted

const BallContextReader := preload("res://scripts/ball/ball_context_reader.gd")
const PaddleBounceVelocityRules := preload("res://scripts/ball/paddle_bounce_velocity_rules.gd")

const CENTER_HIT_THRESHOLD: float = 0.05
const MID_HIT_THRESHOLD: float = 0.15
const SMASH_HIT_THRESHOLD: float = 0.75
const BOSS_CENTER_PRESERVE_THRESHOLD: float = 0.35

var velocity_rules: Object = PaddleBounceVelocityRules.new()


func apply(
	speed: float,
	bounce_vector: Vector2,
	hit_pos: float,
	incoming_dx: float,
	is_player: bool,
	drive_activated: bool,
	accel_scale: float,
	ball_physics: Object,
	drive_bounce_state: Object,
	drive_speed_increase: float,
	spin_strength: float
) -> Dictionary:
	bounce_vector = velocity_rules.apply_boss_center_preserve(
		bounce_vector, hit_pos, incoming_dx, is_player, BOSS_CENTER_PRESERVE_THRESHOLD, MID_HIT_THRESHOLD
	)

	if drive_activated and drive_bounce_state != null and drive_bounce_state.has_method("apply_contact_shape"):
		return _apply_drive_contact_shape(
			speed,
			bounce_vector,
			hit_pos,
			accel_scale,
			ball_physics,
			drive_bounce_state,
			drive_speed_increase,
			spin_strength
		)
	return _apply_normal_contact_shape(speed, bounce_vector, hit_pos, accel_scale, ball_physics)


func _apply_drive_contact_shape(
	speed: float,
	bounce_vector: Vector2,
	hit_pos: float,
	accel_scale: float,
	ball_physics: Object,
	drive_bounce_state: Object,
	drive_speed_increase: float,
	spin_strength: float
) -> Dictionary:
	var result: Dictionary = drive_bounce_state.apply_contact_shape(
		speed, bounce_vector, hit_pos, accel_scale, ball_physics,
		drive_speed_increase, spin_strength, CENTER_HIT_THRESHOLD, SMASH_HIT_THRESHOLD
	)
	return {
		"speed": float(result.get("speed", speed)),
		"bounce_vector": _get_vector2(result, "bounce_vector", bounce_vector),
		"drive_speed_increase": float(result.get("speed_increase", drive_speed_increase)),
		"ball_spin_strength": float(result.get("spin_strength", spin_strength)),
	}


func _apply_normal_contact_shape(
	speed: float,
	bounce_vector: Vector2,
	hit_pos: float,
	accel_scale: float,
	ball_physics: Object
) -> Dictionary:
	var result: Dictionary = velocity_rules.apply_normal_contact_shape(
		speed, bounce_vector, hit_pos, accel_scale, ball_physics,
		CENTER_HIT_THRESHOLD, MID_HIT_THRESHOLD, SMASH_HIT_THRESHOLD
	)
	return {
		"speed": float(result.get("speed", speed)),
		"bounce_vector": _get_vector2(result, "bounce_vector", bounce_vector),
	}


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BallContextReader.get_vector2(source, key, fallback)
