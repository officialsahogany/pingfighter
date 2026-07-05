extends RefCounted

const SmasherDriveContactShapeResolver := preload("res://scripts/characters/smasher_drive_contact_shape_resolver.gd")
const SmasherDriveInitialBounceResolver := preload("res://scripts/characters/smasher_drive_initial_bounce_resolver.gd")

var contact_shape_resolver: Object = SmasherDriveContactShapeResolver.new()
var initial_bounce_resolver: Object = SmasherDriveInitialBounceResolver.new()


func apply_initial_bounce(
	speed: float,
	hit_pos: float,
	drive_direction: int,
	combo_count: int,
	accel_scale: float,
	ball_physics: Object,
	combo_min_count: int,
	text_duration_frames: float,
	combo_amp_speed: float = 0.0,
	combo_amp_curve: float = 0.0
) -> Dictionary:
	return initial_bounce_resolver.apply(
		speed,
		hit_pos,
		drive_direction,
		combo_count,
		accel_scale,
		ball_physics,
		combo_min_count,
		text_duration_frames,
		combo_amp_speed,
		combo_amp_curve
	)


func apply_contact_shape(
	speed: float,
	bounce_vector: Vector2,
	hit_pos: float,
	accel_scale: float,
	ball_physics: Object,
	current_speed_increase: float,
	current_spin_strength: float,
	center_hit_threshold: float,
	smash_hit_threshold: float
) -> Dictionary:
	return contact_shape_resolver.apply(
		speed,
		bounce_vector,
		hit_pos,
		accel_scale,
		ball_physics,
		current_speed_increase,
		current_spin_strength,
		center_hit_threshold,
		smash_hit_threshold
	)
