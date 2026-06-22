extends RefCounted


static func build_projectile(
	position: Vector2,
	direction: Vector2,
	speed: float,
	angle: float,
	shot_index: int,
	mode: String
) -> Dictionary:
	return {
		"pos": position,
		"vel": direction * speed,
		"age": 0.0,
		"angle": angle,
		"shot_index": shot_index,
		"mode": mode,
	}


static func build_boss_stun_status_data(
	knockback_velocity: float,
	knockback_frames: float,
	knockback_decay: float,
	source: String
) -> Dictionary:
	return {
		"knockback_vel": knockback_velocity,
		"knockback_active": absf(knockback_velocity) > 0.001,
		"knockback_frames": knockback_frames,
		"knockback_decay_per_frame": knockback_decay,
		"source": source,
	}


static func build_hit_particle(position: Vector2, hit_angle: float, index: int) -> Dictionary:
	var spread_angle := hit_angle + PI + randf_range(-1.4, 1.4)
	var speed := randf_range(55.0, 210.0)
	return {
		"pos": position,
		"vel": Vector2(cos(spread_angle), sin(spread_angle)) * speed,
		"life": randf_range(0.18, 0.38),
		"age": 0.0,
		"size": randf_range(2.0, 5.0),
		"foam": (index % 2) == 0,
	}


static func build_muzzle_splash(position: Vector2, direction: Vector2) -> Dictionary:
	return {
		"pos": position - direction * 5.0,
		"vel": -direction * randf_range(12.0, 32.0) + Vector2(randf_range(-18.0, 18.0), randf_range(-34.0, 4.0)),
		"life": randf_range(0.16, 0.30),
		"age": 0.0,
		"size": randf_range(2.5, 6.5),
		"foam": true,
	}
