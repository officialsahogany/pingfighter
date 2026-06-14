extends RefCounted


static func build_bullet(muzzle_pos: Vector2, direction: Vector2, speed: float, angle: float, shot_count: int) -> Dictionary:
	return {
		"pos": muzzle_pos,
		"vel": direction * speed,
		"age": 0.0,
		"angle": angle,
		"tracer": (shot_count % 5) == 0,
	}


static func build_ak47_stun_status_data(knockback_velocity: float, knockback_frames: float, knockback_decay: float, source: String) -> Dictionary:
	return {
		"knockback_vel": knockback_velocity,
		"knockback_active": absf(knockback_velocity) > 0.001,
		"knockback_frames": knockback_frames,
		"knockback_decay_per_frame": knockback_decay,
		"source": source,
	}


static func build_hit_particle(position: Vector2, hit_angle: float, index: int) -> Dictionary:
	var spread_angle := hit_angle + PI + randf_range(-1.2, 1.2)
	var speed := randf_range(100.0, 300.0)
	return {
		"pos": position,
		"vel": Vector2(cos(spread_angle), sin(spread_angle)) * speed,
		"life": randf_range(0.15, 0.35),
		"age": 0.0,
		"size": randf_range(1.5, 4.0),
		"ember": (index % 3) == 0,
	}


static func build_shell_casing(position: Vector2, direction: Vector2) -> Dictionary:
	var side := -1.0 if randf() < 0.5 else 1.0
	var side_vec := Vector2(-direction.y, direction.x) * side
	return {
		"pos": position,
		"vel": side_vec * randf_range(80.0, 160.0) + Vector2(0.0, randf_range(-100.0, -30.0)),
		"gravity": 500.0,
		"age": 0.0,
		"life": 0.5,
		"rotation": randf_range(0.0, TAU),
		"rot_speed": randf_range(8.0, 20.0),
	}


static func build_muzzle_smoke(position: Vector2, direction: Vector2) -> Dictionary:
	return {
		"pos": position - direction * 4.0,
		"vel": -direction * randf_range(8.0, 26.0) + Vector2(randf_range(-10.0, 10.0), randf_range(-18.0, -4.0)),
		"age": 0.0,
		"life": randf_range(0.18, 0.34),
		"size": randf_range(4.0, 8.0),
	}
