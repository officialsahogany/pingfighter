extends RefCounted

# Pure boss-side ball-boost cleanup shared by the real boss paddle and
# auxiliary boss reflectors. It intentionally knows nothing about boss
# animation, knockback, item-hit effects, or collision cooldowns.


static func apply(ball_vel: Vector2, context: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var next_ball_vel: Vector2 = ball_vel
	var suicide_result: Dictionary = consume_commando_suicide_drone(next_ball_vel, context)
	if not suicide_result.is_empty():
		next_ball_vel = _vector(suicide_result.get("ball_vel", next_ball_vel), next_ball_vel)
		result.merge(suicide_result, true)
	var wild_roar_result: Dictionary = consume_lingpet_wild_roar(next_ball_vel, context)
	if not wild_roar_result.is_empty():
		next_ball_vel = _vector(wild_roar_result.get("ball_vel", next_ball_vel), next_ball_vel)
		result.merge(wild_roar_result, true)
	if not result.is_empty():
		result["ball_vel"] = next_ball_vel
	return result


static func consume_commando_suicide_drone(ball_vel: Vector2, context: Dictionary) -> Dictionary:
	if not bool(context.get("commando_suicide_drone_ball_boost_active", false)):
		return {}
	var restore_speed: float = maxf(0.0, float(context.get("commando_suicide_drone_ball_restore_speed", 0.0)))
	var next_ball_vel: Vector2 = ball_vel
	if restore_speed > 0.0 and ball_vel.length() > 0.001:
		next_ball_vel = ball_vel.normalized() * restore_speed
	return {
		"ball_vel": next_ball_vel,
		"commando_suicide_drone_ball_boost_active": false,
		"commando_suicide_drone_ball_restore_speed": 0.0,
		"commando_suicide_drone_ball_boosted_speed": 0.0,
		"commando_suicide_drone_ball_boost_consumed": true,
		"commando_suicide_drone_ball_restored_speed": restore_speed,
		"commando_suicide_drone_speed_limit_disabled": false,
		"speed_limit_disabled": false,
	}


static func consume_lingpet_wild_roar(ball_vel: Vector2, context: Dictionary) -> Dictionary:
	if not bool(context.get("lingpet_wild_roar_ball_boost_active", false)):
		return {}
	var restore_speed: float = maxf(0.0, float(context.get("lingpet_wild_roar_ball_restore_speed", 0.0)))
	var next_ball_vel: Vector2 = ball_vel
	if restore_speed > 0.0 and ball_vel.length() > 0.001:
		next_ball_vel = ball_vel.normalized() * restore_speed
	return {
		"ball_vel": next_ball_vel,
		"lingpet_wild_roar_ball_boost_active": false,
		"lingpet_wild_roar_ball_restore_speed": 0.0,
		"lingpet_wild_roar_ball_boost_consumed": true,
		"lingpet_wild_roar_ball_restored_speed": restore_speed,
		"lingpet_wild_roar_speed_limit_disabled": false,
		"speed_limit_disabled": false,
	}


static func _vector(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
