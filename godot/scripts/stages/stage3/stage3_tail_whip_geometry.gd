extends RefCounted

# Pure curve generation and collision query for Stage 3 Kuromi's tail whip.
# Runtime state injects the clock and retains targeting, hit effects, rewards,
# cooldowns, and ball-velocity ownership.

const TAIL_HIT_PROGRESS_MIN := 0.2
const TAIL_HIT_PROGRESS_MAX := 0.8
const TAIL_HIT_RADIUS := 80.0
const TAIL_POINT_COUNT := 24
const TAIL_COLLISION_MID_INDEX_RANGE := 8


static func build_points(progress: float, target: Vector2, center: Vector2, elapsed_msec: int) -> Array[Vector2]:
	var angle_to_target := atan2(target.y - center.y, target.x - center.x)
	var distance_to_target := center.distance_to(target)
	var tail_base_angle := angle_to_target + PI if progress < 0.3 else angle_to_target
	var frame_time := float(elapsed_msec) * 0.06
	var points: Array[Vector2] = []
	for index in range(TAIL_POINT_COUNT):
		var ratio := float(index) / float(TAIL_POINT_COUNT - 1)
		var wave := 0.0
		var distance := 0.0
		var depth_offset := 0.0
		if progress < 0.3:
			var spiral := ratio * PI * 4.0
			var wave_amplitude := 30.0 * (1.0 - ratio * 0.5)
			wave = sin(spiral - progress * PI * 3.0) * wave_amplitude
			distance = 25.0 * ratio * ratio * (1.0 - progress * 2.0)
		elif progress < 0.6:
			var whip_power := (progress - 0.3) / 0.3
			distance = distance_to_target * ratio * whip_power
			var wave_amplitude := 5.0 * (1.0 - ratio) * (1.0 - whip_power)
			wave = sin(ratio * PI * 2.0) * wave_amplitude
		else:
			var recovery := (progress - 0.6) / 0.4
			var spiral := ratio * PI * 2.0
			var wave_amplitude := 15.0 * (1.0 - ratio * 0.5) * recovery
			wave = sin(spiral + frame_time * 0.01) * wave_amplitude
			distance = 35.0 * ratio * ratio * (0.5 + recovery * 0.5)
			depth_offset = cos(frame_time * 0.008 + ratio * 3.0) * 8.0 * (1.0 - ratio) * recovery
		var tail_angle := tail_base_angle + wave * 0.02
		points.append(center + Vector2(
			distance * cos(tail_angle) + depth_offset * sin(tail_angle),
			distance * sin(tail_angle) - depth_offset * cos(tail_angle)
		))
	return points


static func hits_ball(progress: float, ball_pos: Vector2, points: Array[Vector2]) -> bool:
	if progress < TAIL_HIT_PROGRESS_MIN or progress > TAIL_HIT_PROGRESS_MAX or points.size() < 2:
		return false
	@warning_ignore("integer_division")
	var middle_index := int(points.size() / 2)
	var start_index := maxi(0, middle_index - TAIL_COLLISION_MID_INDEX_RANGE)
	var end_index := mini(points.size(), middle_index + TAIL_COLLISION_MID_INDEX_RANGE)
	for index in range(start_index, end_index):
		if ball_pos.distance_to(points[index]) < TAIL_HIT_RADIUS:
			return true
	return false
