extends RefCounted

const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")


static func build_boost_result(
	projectile: Dictionary,
	context: Dictionary,
	speed_multiplier: float,
	fan_degrees: float
) -> Dictionary:
	var ball_vel: Vector2 = CommandoFirearmValueUtils.get_vector2(context.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	var original_speed: float = ball_vel.length()
	var base_speed: float = max(1.0, float(context.get("ball_base_speed", context.get("base_ball_speed", 8.0))))
	var restore_speed: float = original_speed if original_speed > 0.001 else base_speed
	var boosted_speed: float = restore_speed * speed_multiplier
	var angle_deg: float = get_fan_angle(projectile, fan_degrees)
	var radians: float = deg_to_rad(angle_deg)
	var boosted_vel := Vector2(
		boosted_speed * sin(radians),
		-abs(boosted_speed * cos(radians))
	)
	return {
		"ball_vel": boosted_vel,
		"commando_suicide_drone_ball_boosted": true,
		"commando_suicide_drone_ball_boost_active": true,
		"commando_suicide_drone_ball_original_speed": restore_speed,
		"commando_suicide_drone_ball_restore_speed": restore_speed,
		"commando_suicide_drone_ball_boosted_speed": boosted_speed,
		"commando_suicide_drone_ball_boost_angle_deg": angle_deg,
	}


static func get_fan_angle(projectile: Dictionary, fan_degrees: float) -> float:
	var pos: Vector2 = CommandoFirearmValueUtils.get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	@warning_ignore("shadowed_global_identifier")
	var seed: int = abs(int(projectile.get("id", 0)) * 37 + int(round(pos.x * 3.0)))
	var unit: float = float(seed % 1001) / 1000.0
	return -fan_degrees + unit * fan_degrees * 2.0
