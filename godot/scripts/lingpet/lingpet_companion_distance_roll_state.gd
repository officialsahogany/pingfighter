extends RefCounted

var angle := 0.0
var angular_velocity := 0.0
var _draw_pos_prev := Vector2.ZERO
var _override_move_ratio := 0.0


func reset() -> void:
	angle = 0.0
	angular_velocity = 0.0
	_draw_pos_prev = Vector2.ZERO
	_override_move_ratio = 0.0


func advance_draw_movement(
	pos: Vector2,
	delta: float,
	speed_max: float,
	profile: Object,
	fallback_draw_size: float,
	fallback_motion_speed_ratio: float
) -> void:
	var safe_speed_max: float = maxf(1.0, speed_max)
	if _draw_pos_prev == Vector2.ZERO:
		_override_move_ratio = maxf(0.0, fallback_motion_speed_ratio)
	else:
		var moved: Vector2 = pos - _draw_pos_prev
		var moved_x: float = absf(moved.x)
		var safe_delta: float = maxf(0.0001, delta)
		_override_move_ratio = clampf((moved_x / safe_delta) / safe_speed_max, 0.0, 1.0)
		advance_for_movement(moved, delta, profile, fallback_draw_size)
	_draw_pos_prev = pos


func get_override_move_ratio() -> float:
	return _override_move_ratio


func signed_roll_distance(moved: Vector2) -> float:
	if absf(moved.x) >= absf(moved.y):
		return moved.x
	var spin_sign: float = signf(angular_velocity)
	if spin_sign == 0.0:
		spin_sign = 1.0
	return spin_sign * moved.length()


func advance_for_movement(moved: Vector2, delta: float, profile: Object, fallback_draw_size: float) -> void:
	if not is_enabled(profile):
		return
	var moved_distance := signed_roll_distance(moved)
	var safe_delta: float = maxf(0.0, delta)
	if absf(moved_distance) <= 0.001:
		_advance_coast(safe_delta, profile)
		return
	var angular_delta: float = moved_distance / get_radius(profile, fallback_draw_size)
	angle = wrapf(angle + angular_delta, -TAU, TAU)
	if safe_delta > 0.0001:
		angular_velocity = clampf(
			angular_delta / safe_delta,
			-get_max_angular_velocity(profile),
			get_max_angular_velocity(profile)
		)


func is_enabled(profile: Object) -> bool:
	if profile == null or not profile.has_method("get_visual_layout_value"):
		return false
	return float(profile.get_visual_layout_value("companion_distance_roll_enabled", 0.0)) > 0.0


func get_radius(profile: Object, fallback_draw_size: float) -> float:
	var configured: float = _get_visual_value(profile, "companion_distance_roll_radius", 0.0)
	if configured > 0.0:
		return maxf(1.0, configured)
	var draw_size: float = _get_visual_value(profile, "companion_walk_draw_size", fallback_draw_size)
	return maxf(1.0, draw_size * 0.5)


func get_stop_deceleration(profile: Object) -> float:
	var configured: float = _get_visual_value(profile, "companion_distance_roll_stop_deceleration", 0.0)
	return maxf(0.1, configured if configured > 0.0 else 16.0)


func get_max_angular_velocity(profile: Object) -> float:
	var configured: float = _get_visual_value(profile, "companion_distance_roll_max_angular_velocity", 0.0)
	return maxf(0.1, configured if configured > 0.0 else 6.0)


func get_draw_angle(profile: Object, fallback_draw_size: float) -> float:
	if not is_enabled(profile):
		return angle
	var visual_tilt: float = _get_visual_value(profile, "companion_distance_roll_visual_tilt_radians", 0.0)
	if visual_tilt > 0.0:
		return sin(angle) * visual_tilt
	var visual_scale: float = maxf(0.0, _get_visual_value(profile, "companion_distance_roll_visual_angle_scale", 1.0))
	return wrapf(angle * visual_scale, -TAU, TAU)


func _advance_coast(delta: float, profile: Object) -> void:
	if delta <= 0.0:
		return
	if absf(angular_velocity) <= 0.001:
		angular_velocity = 0.0
		return
	var next_velocity: float = move_toward(angular_velocity, 0.0, get_stop_deceleration(profile) * delta)
	var average_velocity: float = (angular_velocity + next_velocity) * 0.5
	angle = wrapf(angle + average_velocity * delta, -TAU, TAU)
	angular_velocity = next_velocity


func _get_visual_value(profile: Object, key: String, fallback: float) -> float:
	if profile == null or not profile.has_method("get_visual_layout_value"):
		return fallback
	return float(profile.get_visual_layout_value(key, fallback))
