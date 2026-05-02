extends RefCounted


func activate_drive_ball(
	owner: Object,
	registry: Object,
	direction: int,
	spin_strength: float,
	speed_multiplier: float = 1.015,
	speed_bypass_bonus: float = 0.0
) -> Dictionary:
	var ball_spin_state: Object = _get_module(registry, "ball_spin_state")
	if ball_spin_state == null or not ball_spin_state.has_method("activate_drive"):
		return {}
	var snapshot: Variant = ball_spin_state.activate_drive(
		_get_owner_vector2(owner, "ball_vel", Vector2.ZERO),
		direction,
		spin_strength,
		speed_multiplier,
		speed_bypass_bonus,
		_get_module(registry, "ball_physics")
	)
	if snapshot is Dictionary:
		return snapshot
	return {}


func clear_drive_ball_state(registry: Object, clear_spin: bool = false) -> Dictionary:
	var ball_spin_state: Object = _get_module(registry, "ball_spin_state")
	if ball_spin_state == null or not ball_spin_state.has_method("build_clear_drive_snapshot"):
		return {}
	var snapshot: Variant = ball_spin_state.build_clear_drive_snapshot(clear_spin)
	if snapshot is Dictionary:
		return snapshot
	return {}


func clear_power_smashing_state(registry: Object, clear_text: bool = true) -> void:
	var power_state: Object = _get_module(registry, "smasher_power_smash_state")
	if power_state != null and power_state.has_method("reset"):
		power_state.reset(clear_text)


func reset_drive_input_frames(registry: Object) -> void:
	var drive_input_state: Object = _get_module(registry, "smasher_drive_input_state")
	if drive_input_state != null and drive_input_state.has_method("reset"):
		drive_input_state.reset()


func _get_module(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_owner_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	if value is Vector2:
		return value
	return fallback
