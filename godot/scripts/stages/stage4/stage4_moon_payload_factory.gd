extends RefCounted


static func build_fragment(
	origin: Vector2,
	target_pos: Vector2,
	random: RandomNumberGenerator,
	now_msec: int,
	rotation_speed_min: float,
	rotation_speed_max: float,
	image_scale_min: float,
	image_scale_max: float,
	field_entry_right: float,
	sprite_count: int
) -> Dictionary:
	var to_target: Vector2 = target_pos - origin
	if to_target.length() <= 0.001:
		to_target = Vector2(-1.0, 1.0)
	var direction: Vector2 = to_target.normalized()
	var speed: float = random.randf_range(5.0, 8.0)
	var fragment_id: int = now_msec * 1000 + random.randi_range(0, 999)
	var size: float = random.randf_range(8.0, 15.0)
	return {
		"fragment_id": fragment_id,
		"x": origin.x + random.randf_range(-8.0, 12.0),
		"y": origin.y + random.randf_range(-8.0, 8.0),
		"vx": direction.x * speed,
		"vy": direction.y * speed,
		"target_x": target_pos.x,
		"target_y": target_pos.y,
		"size": size,
		"rotation": random.randf_range(0.0, 360.0),
		"rotation_speed": _build_rotation_speed(random, rotation_speed_min, rotation_speed_max),
		"lifetime": 300.0,
		"trail": [origin],
		"impact": false,
		"impact_timer": 0.0,
		"shockwave_radius": 0.0,
		"entered_field": origin.x <= field_entry_right,
		"deflected": false,
		"glow_phase": random.randf_range(0.0, TAU),
		"sprite_index": random.randi_range(0, maxi(0, sprite_count - 1)),
		"sprite_scale_jitter": random.randf_range(0.88, 1.0),
		"visual_scale": random.randf_range(image_scale_min, image_scale_max),
	}


static func _build_rotation_speed(random: RandomNumberGenerator, min_speed: float, max_speed: float) -> float:
	var direction := -1.0 if random.randf() < 0.5 else 1.0
	return direction * random.randf_range(min_speed, max_speed)
