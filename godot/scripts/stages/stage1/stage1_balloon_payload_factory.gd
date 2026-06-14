extends RefCounted


static func build_balloon(
	position: Vector2,
	angle: float,
	speed: float,
	radius: float,
	color: Color,
	bounce: float,
	is_special: bool,
	sprite_index: int,
	rotation: float,
	rotation_speed: float
) -> Dictionary:
	return {
		"pos": position,
		"vel": Vector2(cos(angle), sin(angle)) * speed,
		"radius": radius,
		"color": color,
		"bounce": bounce,
		"lifetime": 0.0,
		"is_special": is_special,
		"sprite_index": sprite_index,
		"rotation": rotation,
		"rotation_speed": rotation_speed,
		"paddle_bounce_cooldown": 0.0,
		"paddle_bounce_slow_timer": 0.0,
	}


static func build_absorbed_balloon_payload(position: Vector2, radius: float, color: Color) -> Dictionary:
	return {
		"position": position,
		"strength": clamp(radius / 30.0, 0.75, 1.55),
		"color": color,
	}


static func build_sprite_pop_effect(
	position: Vector2,
	radius: float,
	is_special: bool,
	frame_count: int,
	frame_duration: float
) -> Dictionary:
	return {
		"type": "sprite",
		"pos": position,
		"timer": 0.0,
		"life": float(frame_count) * frame_duration,
		"radius": radius,
		"is_special": is_special,
	}


static func build_fallback_pop_effects(
	position: Vector2,
	color: Color,
	radius: float,
	is_special: bool,
	normal_particle_count: int,
	special_particle_count: int
) -> Array[Dictionary]:
	var effects: Array[Dictionary] = [{
		"type": "burst",
		"pos": position,
		"color": color,
		"radius": 4.0,
		"max_radius": max(40.0, radius * 2.2),
		"alpha": 0.86,
		"life": 16.0,
	}]
	var particle_count := special_particle_count if is_special else normal_particle_count
	for _i in range(maxi(0, particle_count)):
		var angle := randf_range(0.0, TAU)
		var speed := randf_range(3.0, 9.0)
		effects.append({
			"type": "particle",
			"pos": position,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"color": color,
			"alpha": 1.0,
			"size": float(randi_range(4, 11)),
			"life": float(randi_range(20, 34)),
		})
	return effects
