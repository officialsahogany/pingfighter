extends RefCounted

const BOSS_SLOW_VISUAL := "red_dragon_dragon_breath"


static func build_breath_particle(origin: Vector2, direction: float, initial: bool, index_ratio: float = 0.0) -> Dictionary:
	var delay := index_ratio * 0.3 if initial else 0.0
	var life := randf_range(1.0, 1.8) if initial else randf_range(0.6, 1.2)
	var size := randf_range(10.0, 25.0) if initial else randf_range(8.0, 18.0)
	var start_y_offset := 20.0 if initial else 25.0
	var speed_min := 350.0 if initial else 400.0
	var speed_max := 600.0 if initial else 550.0
	var vx_range := 66.0 if initial else 54.0
	return {
		"pos": origin + Vector2(randf_range(-25.0, 25.0), direction * start_y_offset),
		"vel": Vector2(randf_range(-vx_range, vx_range), direction * randf_range(speed_min, speed_max)),
		"life": life + delay,
		"max_life": maxf(0.01, life),
		"size": size,
		"max_size": size,
		"phase": randf(),
		"wob": randf(),
		"delay": delay,
		"zone_reported": false,
	}


static func build_fire_zone(
	center: Vector2,
	width: float,
	height: float,
	duration_seconds: float,
	zone_id: int
) -> Dictionary:
	return {
		"position": center,
		"width": width,
		"height": height,
		"timer": duration_seconds,
		"max_timer": duration_seconds,
		"spread_timer": 0.0,
		# Smooth bounce state (parity with the molotov fire zone).
		"knockback_vel": 0.0,
		"knockback_cooldown": 0.0,
		"engage_dir": 0.0,
		"flames": [],
		"boss_in_fire": false,
		"last_push_dir": 0.0,
		"zone_id": zone_id,
	}


static func build_zone_flame(center: Vector2, spread_x: float, spread_y: float) -> Dictionary:
	return {
		"pos": center + Vector2(randf_range(-spread_x, spread_x), randf_range(-spread_y, spread_y)),
		"size": randf_range(8.0, 20.0),
		"life": randf_range(0.33, 0.66),
		"max_life": 0.66,
		"phase": randf(),
	}


static func build_boss_slow_status_data(slow_multiplier: float) -> Dictionary:
	return {
		"multiplier": slow_multiplier,
		"cleansable": true,
		"visual": BOSS_SLOW_VISUAL,
		"suppress_legacy_boss_ai_slow": true,
	}


static func build_molotov_zone_payload(
	zone: Dictionary,
	fallback_width: float,
	fallback_height: float,
	fallback_duration_seconds: float,
	flames: Array
) -> Dictionary:
	var timer := float(zone.get("timer", 0.0))
	var max_timer := maxf(0.01, float(zone.get("max_timer", fallback_duration_seconds)))
	return {
		"position": zone.get("position", Vector2.ZERO),
		"width": float(zone.get("width", fallback_width)) * 1.35,
		"height": float(zone.get("height", fallback_height)) * 1.35,
		"zone_id": int(zone.get("zone_id", 0)),
		"duration_frames": timer * 60.0,
		"max_duration_frames": max_timer * 60.0,
		"age_frames": (max_timer - timer) * 60.0,
		"flames": flames,
	}


static func build_molotov_flame_payload(flame: Dictionary, default_size: float, default_max_life: float) -> Dictionary:
	return {
		"position": flame.get("pos", Vector2.ZERO),
		"size": float(flame.get("size", default_size)),
		"lifetime_frames": float(flame.get("life", 0.0)) * 60.0,
		"max_lifetime_frames": maxf(1.0, float(flame.get("max_life", default_max_life)) * 60.0),
		"color_phase": float(flame.get("phase", 0.0)),
	}
