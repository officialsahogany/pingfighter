extends RefCounted


static func build_archer(
	archer_id: int,
	position: Vector2,
	velocity_x: float,
	patrol_y_min: float,
	patrol_y_max: float,
	arrow_cooldown: float,
	is_golden: bool,
	caster_is_top: bool
) -> Dictionary:
	return {
		"id": archer_id,
		"pos": position,
		"velocity_x": velocity_x,
		"patrol_y_min": patrol_y_min,
		"patrol_y_max": patrol_y_max,
		"spawn_time": 0.0,
		"is_golden": is_golden,
		"arrow_cooldown": maxf(0.0, arrow_cooldown),
		"is_drawing": false,
		"draw_timer": 0.0,
		"draw_target": Vector2.ZERO,
		"body_bob": 0.0,
		"step_phase": randf_range(0.0, TAU),
		"caster_is_top": caster_is_top,
	}


static func build_arrow(
	position: Vector2,
	direction: Vector2,
	speed: float,
	archer_id: int,
	is_golden: bool
) -> Dictionary:
	var safe_direction := direction.normalized()
	if safe_direction.length_squared() <= 0.0001:
		safe_direction = Vector2.UP
	return {
		"pos": position,
		"vel": safe_direction * maxf(0.0, speed),
		"age": 0.0,
		"archer_id": archer_id,
		"is_golden": is_golden,
		"angle": safe_direction.angle(),
		"trail": [position],
	}


static func build_bone_fragment(position: Vector2, index: int) -> Dictionary:
	var angle := TAU * float(index) / 12.0 + randf_range(-0.22, 0.22)
	var speed := randf_range(110.0, 260.0)
	return {
		"pos": position + Vector2(randf_range(-8.0, 8.0), randf_range(-18.0, 8.0)),
		"vel": Vector2(cos(angle), sin(angle)) * speed + Vector2(0.0, -80.0),
		"rotation": randf_range(0.0, TAU),
		"rotation_speed": randf_range(-9.0, 9.0),
		"length": randf_range(5.0, 13.0),
		"is_bow": index == 0,
	}


static func build_hit_particle(position: Vector2, incoming_velocity: Vector2, index: int) -> Dictionary:
	var base_angle := incoming_velocity.angle() + PI
	var angle := base_angle + randf_range(-0.9, 0.9) + float(index) * 0.04
	var speed := randf_range(90.0, 260.0)
	return {
		"pos": position,
		"vel": Vector2(cos(angle), sin(angle)) * speed,
		"age": 0.0,
		"life": randf_range(0.20, 0.46),
		"size": randf_range(2.0, 5.0),
		"color": Color(0.72, 0.88, 1.0, randf_range(0.55, 0.86)),
	}


static func build_summon_particle(position: Vector2) -> Dictionary:
	var angle := randf_range(PI, TAU)
	var speed := randf_range(30.0, 150.0)
	return {
		"pos": position + Vector2(randf_range(-18.0, 18.0), randf_range(-6.0, 8.0)),
		"vel": Vector2(cos(angle), sin(angle)) * speed + Vector2(0.0, -55.0),
		"age": 0.0,
		"life": randf_range(0.35, 0.86),
		"size": randf_range(1.8, 4.5),
		"color": Color(0.48, 0.90, 0.78, randf_range(0.34, 0.68)),
	}
