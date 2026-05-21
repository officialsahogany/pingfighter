extends RefCounted


static func step_absorbing_rock(
	rock: Dictionary,
	rock_center: Vector2,
	absorb_center: Vector2,
	frame_step: float,
	destroy_distance: float,
	angular_speed_max: float,
	angular_speed_numerator: float,
	radial_speed_min: float,
	radial_speed_max: float,
	radial_speed_numerator: float,
	spin_multiplier: float
) -> Dictionary:
	var offset: Vector2 = rock_center - absorb_center
	var distance: float = offset.length()
	if distance < destroy_distance:
		return {
			"destroyed": true,
			"center": rock_center,
			"moved": false,
		}
	distance = max(4.0, distance)
	var spin_dir: float = float(rock.get("chaos_spin_dir", 1.0))
	var angular_velocity: float = min(angular_speed_max, angular_speed_numerator / distance) * spin_dir
	var angle: float = atan2(offset.y, offset.x) + angular_velocity * frame_step
	var radial_speed: float = clamp(
		radial_speed_numerator / distance,
		radial_speed_min,
		radial_speed_max
	)
	var next_distance: float = max(0.0, distance - radial_speed * frame_step)
	var next_center := absorb_center + Vector2(cos(angle), sin(angle)) * next_distance
	rock["rotation"] = float(rock.get("rotation", 0.0)) + angular_velocity * spin_multiplier * frame_step
	rock["phase"] = float(rock.get("phase", 0.0)) + abs(angular_velocity) * 1.6 * frame_step
	return {
		"destroyed": next_distance < destroy_distance,
		"center": next_center,
		"moved": true,
	}
