extends RefCounted


static func get_suicide_drone_input_vector(input_snapshot: Dictionary) -> Vector2:
	var x := 0.0
	var y := 0.0
	if bool(input_snapshot.get("left_pressed", false)):
		x -= 1.0
	if bool(input_snapshot.get("right_pressed", false)):
		x += 1.0
	if bool(input_snapshot.get("up_pressed", false)):
		y -= 1.0
	if bool(input_snapshot.get("down_pressed", false)):
		y += 1.0
	var vector := Vector2(x, y)
	if vector.length_squared() > 1.0:
		vector = vector.normalized()
	return vector


static func input_action_just_pressed(input_snapshot: Dictionary) -> bool:
	if input_snapshot.has("action_just_pressed"):
		return bool(input_snapshot.get("action_just_pressed", false))
	return bool(input_snapshot.get("action_pressed", false))


static func is_fire_suppressed_after_switch(weapon_controller: Object, now_msec: int, suppress_msec: int) -> bool:
	if weapon_controller == null:
		return false
	if not weapon_controller.has_method("get_last_switch_msec"):
		return false
	var last_switch: int = int(weapon_controller.get_last_switch_msec())
	return now_msec - last_switch < suppress_msec
