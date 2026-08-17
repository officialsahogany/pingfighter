extends RefCounted

const BASE_ROAM_SPEED := 0.6
const INITIAL_ROAM_SPEED := 0.4
const SIDE_MARGIN := 40.0
const BOTTOM_MARGIN := 100.0
const TOP_MARGIN := 70.0
const LAUNCH_SPEED := 13.0
const LAUNCH_DECAY := 0.94
const LAUNCH_SPEED_BOOST := 3.0
const LAUNCH_BOOST_FRAMES := 34.0


static func apply_launch(top: Dictionary, index: int, vertical_sign: float = 1.0) -> void:
	var direction := launch_direction(index, vertical_sign)
	top["launched"] = true
	top["whip_phase"] = "spinning"
	top["rotation_speed"] = 20.0
	top["vx"] = direction.x * LAUNCH_SPEED
	top["vy"] = direction.y * LAUNCH_SPEED
	top["speed_boost"] = LAUNCH_SPEED_BOOST
	top["boost_timer"] = LAUNCH_BOOST_FRAMES
	top["launch_boost"] = true
	top["zigzag_timer"] = 0.0


static func launch_direction(index: int, vertical_sign: float = 1.0) -> Vector2:
	# Dalji's first top takes a clean shallow skid; later tops alternate between
	# shallow and diagonal launches. Player-owned tops mirror only the vertical
	# sign so their launch silhouette and decay stay identical to the boss skill.
	var side := -1.0 if index % 2 == 0 else 1.0
	var angle_deg: float
	if index == 0:
		angle_deg = randf_range(18.0, 30.0)
	elif randf() < 0.6:
		angle_deg = randf_range(16.0, 32.0)
	else:
		angle_deg = randf_range(34.0, 48.0)
	var angle := deg_to_rad(angle_deg)
	return Vector2(side * cos(angle), signf(vertical_sign) * sin(angle))


static func update_running_top(
	top: Dictionary,
	fps_scale: float,
	width: float,
	height: float,
	vertical_sign: float = 1.0,
	keep_in_field: bool = false
) -> void:
	var direction_sign := signf(vertical_sign)
	if is_zero_approx(direction_sign):
		direction_sign = 1.0
	var boost_timer := float(top.get("boost_timer", 0.0))
	if boost_timer > 0.0:
		boost_timer = maxf(0.0, boost_timer - fps_scale)
		top["boost_timer"] = boost_timer
		if bool(top.get("launch_boost", false)):
			var decay := pow(LAUNCH_DECAY, fps_scale)
			top["vx"] = float(top.get("vx", 0.0)) * decay
			top["vy"] = float(top.get("vy", 0.0)) * decay
		if boost_timer <= 0.0:
			top["speed_boost"] = 0.0
			top["launch_boost"] = false
			top["vx"] = float(top.get("vx", 0.0)) * 0.25
			top["vy"] = BASE_ROAM_SPEED * direction_sign

	top["rotation"] = float(top.get("rotation", 0.0)) + float(top.get("rotation_speed", 20.0)) * fps_scale
	top["zigzag_timer"] = float(top.get("zigzag_timer", 0.0)) + fps_scale

	if float(top.get("boost_timer", 0.0)) <= 0.0:
		var zigzag_timer := int(top.get("zigzag_timer", 0.0))
		var period := randi_range(20, 40)
		if period > 0 and zigzag_timer % period == 0:
			top["vx"] = randf_range(-2.0, 2.0)
		var wave_x := sin(float(top.get("zigzag_timer", 0.0)) * 0.1) * 0.5
		top["x"] = float(top.get("x", 0.0)) + (float(top.get("vx", 0.0)) + wave_x) * fps_scale
		top["y"] = float(top.get("y", 0.0)) + float(top.get("vy", INITIAL_ROAM_SPEED * direction_sign)) * fps_scale
	else:
		top["x"] = float(top.get("x", 0.0)) + float(top.get("vx", 0.0)) * fps_scale
		top["y"] = float(top.get("y", 0.0)) + float(top.get("vy", 0.0)) * fps_scale

	if float(top.get("x", 0.0)) < SIDE_MARGIN or float(top.get("x", 0.0)) > width - SIDE_MARGIN:
		top["vx"] = -float(top.get("vx", 0.0))
		top["x"] = clampf(float(top.get("x", 0.0)), SIDE_MARGIN, width - SIDE_MARGIN)

	if keep_in_field:
		var min_y := TOP_MARGIN
		var max_y := maxf(min_y, height - BOTTOM_MARGIN)
		if float(top.get("y", 0.0)) < min_y or float(top.get("y", 0.0)) > max_y:
			top["vy"] = -float(top.get("vy", BASE_ROAM_SPEED * direction_sign))
			top["y"] = clampf(float(top.get("y", 0.0)), min_y, max_y)
	elif float(top.get("y", 0.0)) < height - BOTTOM_MARGIN and float(top.get("boost_timer", 0.0)) <= 0.0:
		# Preserve the shipped boss behavior exactly: once the launch skid ends,
		# Dalji's top resumes its slow downward drift.
		top["vy"] = BASE_ROAM_SPEED
