extends RefCounted

const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")


static func apply_pistol_side_wall_bounce(
	projectile: Dictionary,
	pos: Vector2,
	velocity: Vector2,
	field_width: float,
	margin: float,
	max_bounces: int,
	damping: float
) -> Dictionary:
	if int(projectile.get("wall_bounces", 0)) >= max_bounces:
		return {"bounced": false}
	var next_projectile: Dictionary = projectile.duplicate(true)
	var left_margin := margin
	var right_margin := field_width - margin
	var bounced := false
	if pos.x <= left_margin:
		pos.x = left_margin
		velocity.x = abs(velocity.x) * damping
		next_projectile["wall_bounce_side"] = "left"
		bounced = true
	elif pos.x >= right_margin:
		pos.x = right_margin
		velocity.x = -abs(velocity.x) * damping
		next_projectile["wall_bounce_side"] = "right"
		bounced = true
	if not bounced:
		return {"bounced": false}
	next_projectile["wall_bounces"] = int(next_projectile.get("wall_bounces", 0)) + 1
	next_projectile["pos"] = pos
	next_projectile["velocity"] = velocity
	next_projectile["speed"] = velocity.length()
	return {
		"bounced": true,
		"projectile": next_projectile,
	}


static func update_rocket_motion(
	projectile: Dictionary,
	pos: Vector2,
	velocity: Vector2,
	step: float,
	default_acceleration: float,
	default_max_speed: float,
	default_smoke_trail_limit: int
) -> Dictionary:
	var next_projectile: Dictionary = projectile.duplicate(true)
	var direction: Vector2 = velocity.normalized() if velocity.length() > 0.001 else Vector2.UP
	var speed: float = float(next_projectile.get("speed", velocity.length()))
	var acceleration: float = max(0.0, float(next_projectile.get("acceleration", default_acceleration)))
	var max_speed: float = max(speed, float(next_projectile.get("max_speed", default_max_speed)))
	var smoke_trail: Array = CommandoFirearmValueUtils.get_array(next_projectile.get("smoke_trail", []))
	var should_append_smoke := smoke_trail.is_empty()
	if not should_append_smoke:
		var last_smoke: Vector2 = CommandoFirearmValueUtils.get_vector2(smoke_trail.back(), pos)
		should_append_smoke = last_smoke.distance_to(pos) > 5.0
	if should_append_smoke:
		smoke_trail.append(pos)
		var smoke_limit: int = max(1, int(next_projectile.get("smoke_trail_limit", default_smoke_trail_limit)))
		while smoke_trail.size() > smoke_limit:
			smoke_trail.pop_front()
		next_projectile["smoke_trail"] = smoke_trail
	speed = min(max_speed, speed + acceleration * max(0.0, step))
	next_projectile["speed"] = speed
	return {
		"projectile": next_projectile,
		"velocity": direction * speed,
	}


static func advance_linear_motion(
	projectile: Dictionary,
	pos: Vector2,
	velocity: Vector2,
	step: float
) -> Dictionary:
	var frame_step: float = max(0.0, step)
	var next_velocity: Vector2 = velocity
	if projectile.has("gravity"):
		next_velocity.y += float(projectile.get("gravity", 0.0)) * frame_step
	return {
		"prev_pos": pos,
		"pos": pos + next_velocity * frame_step,
		"velocity": next_velocity,
	}


static func update_net_projectile_rope(
	projectile: Dictionary,
	pos: Vector2,
	origin: Vector2,
	default_rope_trail_limit: int
) -> Dictionary:
	var next_projectile: Dictionary = projectile.duplicate(true)
	next_projectile["origin"] = origin
	var rope_points: Array = CommandoFirearmValueUtils.get_array(next_projectile.get("rope_points", []))
	rope_points.append(pos)
	var rope_limit: int = max(1, int(next_projectile.get("rope_trail_limit", default_rope_trail_limit)))
	while rope_points.size() > rope_limit:
		rope_points.pop_front()
	next_projectile["rope_points"] = rope_points
	return next_projectile
