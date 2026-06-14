extends RefCounted


static func build_boss_stun_status_data(
	visual_source: String,
	knockback_velocity: float,
	knockback_frames: float,
	knockback_decay: float
) -> Dictionary:
	return {
		"cleansable": true,
		"visual": visual_source,
		"knockback_vel": knockback_velocity,
		"knockback_active": true,
		"knockback_frames": knockback_frames,
		"knockback_decay_per_frame": knockback_decay,
	}


static func build_player_stun_status_data(visual_source: String, weak_stun: bool) -> Dictionary:
	return {
		"cleansable": true,
		"visual": visual_source,
		"weak_stun": weak_stun,
	}


static func build_particle(pos: Vector2, vel: Vector2, life: float, size: float, kind: int) -> Dictionary:
	var safe_life := maxf(0.01, life)
	return {
		"pos": pos,
		"vel": vel,
		"life": safe_life,
		"max_life": safe_life,
		"size": maxf(0.5, size),
		"kind": kind,
	}


static func build_explosion_particle(origin: Vector2, self_explosion: bool) -> Dictionary:
	var speed_min := 120.0 if self_explosion else 220.0
	var speed_max := 360.0 if self_explosion else 720.0
	var life_min := 0.16 if self_explosion else 0.24
	var life_max := 0.40 if self_explosion else 0.62
	var angle := randf_range(0.0, TAU)
	var speed := randf_range(speed_min, speed_max)
	var pos := origin + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
	var vel := Vector2(cos(angle), sin(angle)) * speed
	var life := randf_range(life_min, life_max)
	var size := randf_range(2.0, 7.0) if self_explosion else randf_range(3.0, 11.0)
	var kind := 0 if randf() < 0.72 else 1
	return build_particle(pos, vel, life, size, kind)
