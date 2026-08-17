extends RefCounted


static func build_catalog(tuning: Dictionary) -> Dictionary:
	var grenade_explosion_radius := _float_value(tuning, "grenade_explosion_radius", 150.0)
	var grenade_boss_stun_frames := _float_value(tuning, "grenade_boss_stun_frames", 90.0)
	var grenade_boss_knockback_power := _float_value(tuning, "grenade_boss_knockback_power", 40.0)
	var grenade_boss_knockback_frames := _float_value(tuning, "grenade_boss_knockback_frames", 18.0)
	var grenade_boss_knockback_decay := _float_value(tuning, "grenade_boss_knockback_decay", 0.85)
	return {
		"weapon_profiles": {
			"pistol": {
				"kind": "bullet",
				"speed": _float_value(tuning, "pistol_bullet_speed", 25.0),
				"radius": 4.4,
				"hitbox_size": Vector2(9.0, 9.0),
				"life_frames": 44.0,
				"trail": 30.0,
				"impact_radius": 16.0,
				"color": Color(0.96, 0.82, 0.36),
				"secondary": Color(1.0, 0.52, 0.18),
			},
			"commando_pistol": {
				"kind": "bullet",
				"speed": _float_value(tuning, "beretta_bullet_speed", 30.0),
				"radius": 5.0,
				"hitbox_size": Vector2(10.0, 10.0),
				"life_frames": 44.0,
				"trail": 34.0,
				"impact_radius": 16.0,
				"color": Color(1.0, 0.86, 0.40),
				"secondary": Color(1.0, 0.50, 0.18),
			},
			"ak47": {
				"kind": "bullet",
				"speed": _float_value(tuning, "ak47_bullet_speed", 23.04),
				"radius": 3.6,
				"hitbox_size": Vector2(6.0, 6.0),
				"life_frames": _float_value(tuning, "ak47_bullet_life_frames", 60.0),
				"trail": 40.0,
				"impact_radius": 12.0,
				"color": Color(0.95, 1.0, 0.50),
				"secondary": Color(0.72, 0.94, 0.25),
			},
			"bazooka": {
				"kind": "rocket",
				"speed": _float_value(tuning, "bazooka_initial_speed", 3.0),
				"acceleration": _float_value(tuning, "bazooka_acceleration", 0.8),
				"max_speed": _float_value(tuning, "bazooka_max_speed", 35.0),
				"radius": 9.5,
				"hitbox_size": Vector2(20.0, 30.0),
				"hitbox_offset": Vector2(0.0, 5.0),
				"life_frames": 72.0,
				"trail": 48.0,
				"impact_radius": 46.0,
				"explosion_radius": _float_value(tuning, "bazooka_explosion_radius", 108.5),
				"smoke_trail_limit": _int_value(tuning, "bazooka_smoke_trail_limit", 10),
				"vertical_launch": true,
				"muzzle_flash_frames": _float_value(tuning, "bazooka_muzzle_flash_frames", 5.0),
				"color": Color(1.0, 0.46, 0.18),
				"secondary": Color(1.0, 0.88, 0.38),
			},
			"net_gun": {
				"kind": "net",
				"speed": _float_value(tuning, "net_gun_projectile_speed", 18.0),
				"radius": 13.0,
				"hitbox_size": Vector2(12.0, 12.0),
				"boss_inflate": Vector2(60.0, 40.0),
				"segment_radius": 6.0,
				"life_frames": 64.0,
				"trail": 20.0,
				"impact_radius": 36.0,
				"rope_trail_limit": _int_value(tuning, "net_gun_rope_trail_limit", 18),
				"muzzle_flash_frames": _float_value(tuning, "net_gun_harpoon_flash_frames", 6.0),
				"color": Color(0.42, 1.0, 0.52),
				"secondary": Color(0.18, 0.65, 0.28),
			},
			"fire_support": {
				"kind": "support",
				"speed": _float_value(tuning, "support_bomb_initial_vy", 0.0),
				"initial_vy": _float_value(tuning, "support_bomb_initial_vy", 0.0),
				"gravity": _float_value(tuning, "support_bomb_gravity", 0.0),
				"horizontal_jitter": _float_value(tuning, "support_bomb_horizontal_jitter", 0.0),
				"flight_frames": _float_value(tuning, "support_missile_flight_frames", 90.0),
				"radius": 7.0,
				"hitbox_size": Vector2(14.0, 14.0),
				"life_frames": _float_value(tuning, "support_missile_life_frames", 150.0),
				"trail": 52.0,
				"impact_radius": 54.0,
				"explosion_radius": grenade_explosion_radius,
				"color": Color(1.0, 0.34, 0.16),
				"secondary": Color(1.0, 0.82, 0.25),
			},
			"bowling_trap": {
				"kind": "trap",
				"speed": 8.5,
				"radius": 12.0,
				"life_frames": 84.0,
				"trail": 22.0,
				"impact_radius": 30.0,
				"color": Color(0.95, 0.18, 0.24),
				"secondary": Color(0.22, 0.10, 0.12),
			},
			"suicide_drone": {
				"kind": "drone",
				"speed": 0.0,
				"radius": 24.0,
				"hitbox_size": _vector2_value(tuning, "suicide_drone_size", Vector2(48.0, 48.0)),
				"life_frames": _float_value(tuning, "suicide_drone_life_frames", 3600.0),
				"trail": 26.0,
				"impact_radius": 40.0,
				"explosion_radius": 150.0,
				"max_speed": _float_value(tuning, "suicide_drone_max_speed", 14.0),
				"acceleration": _float_value(tuning, "suicide_drone_accel", 1.2),
				"color": Color(1.0, 0.42, 0.18),
				"secondary": Color(0.45, 0.86, 1.0),
			},
		},
		"weapon_hit_feedback": {
			"pistol": {"intensity": 0.46, "shake_amount": 0.040, "shake_intensity": 1.25},
			"commando_pistol": {"intensity": 0.50, "shake_amount": 0.045, "shake_intensity": 1.4},
			"ak47": {"intensity": 0.36, "shake_amount": 0.030, "shake_intensity": 1.1},
			"bazooka": {"intensity": 1.12, "shake_amount": 0.140, "shake_intensity": 3.2},
			"net_gun": {"intensity": 0.76, "shake_amount": 0.070, "shake_intensity": 1.8},
			"fire_support": {"intensity": 1.25, "shake_amount": 0.24, "shake_intensity": 7.0},
			"bowling_trap": {"intensity": 0.82, "shake_amount": 0.085, "shake_intensity": 2.1},
			"suicide_drone": {"intensity": 1.05, "shake_amount": 0.125, "shake_intensity": 3.0},
		},
		"weapon_hit_results": {
			"pistol": {
				"stun_frames": 42.0,
				"knockback_power": _float_value(tuning, "pistol_boss_knockback_power", 8.0),
				"damage_units": 0,
			},
			"commando_pistol": {
				"stun_frames": 42.0,
				"knockback_power": _float_value(tuning, "pistol_boss_knockback_power", 8.0),
				"damage_units": 0,
			},
			"ak47": {
				"stun_frames": 12.0,
				"knockback_power": _float_value(tuning, "ak47_boss_knockback_power", 8.0),
				"knockback_velocity_scale": _float_value(tuning, "ak47_knockback_velocity_scale", 0.10),
				"knockback_frames": _float_value(tuning, "ak47_knockback_frames", 3.0),
				"knockback_decay_per_frame": _float_value(tuning, "ak47_knockback_decay_per_frame", 0.72),
				"damage_units": 0,
			},
			"bazooka": {
				"stun_frames": _float_value(tuning, "bazooka_stun_frames", 90.0),
				"knockback_power": _float_value(tuning, "bazooka_knockback_power", 40.0),
				"knockback_frames": _float_value(tuning, "bazooka_knockback_frames", 18.0),
				"knockback_decay_per_frame": _float_value(tuning, "bazooka_knockback_decay_per_frame", 0.85),
				"damage_units": 2,
			},
			"net_gun": {"damage_units": 0},
			"fire_support": {
				"stun_frames": grenade_boss_stun_frames,
				"knockback_power": grenade_boss_knockback_power,
				"knockback_frames": grenade_boss_knockback_frames,
				"knockback_decay_per_frame": grenade_boss_knockback_decay,
				"damage_units": 1,
			},
			"bowling_trap": {
				# This direct-hit route is effectively unreachable because the trap
				# relaunches the captured ball; keep it aligned with the 2.5 s guard stun.
				"stun_frames": 150.0,
				"knockback_power": 7.0,
				"damage_units": 0,
			},
			"suicide_drone": {
				"stun_frames": 48.0,
				"knockback_power": _float_value(tuning, "suicide_drone_knockback_power", 12.0),
				"knockback_frames": _float_value(tuning, "suicide_drone_knockback_frames", 18.0),
				"knockback_decay_per_frame": _float_value(tuning, "suicide_drone_knockback_decay_per_frame", 0.85),
				"damage_units": 0,
			},
		},
		"weapon_lingering_effects": {
			"net_gun": {
				"kind": "net_field",
				"duration_frames": _float_value(tuning, "net_gun_field_duration_frames", 240.0),
				"dissolve_frames": _float_value(tuning, "net_gun_dissolve_frames", 21.0),
				"dash_break_frames": _float_value(tuning, "net_gun_dash_break_frames", 24.0),
				"width": _float_value(tuning, "net_gun_width", 280.0),
				"height": _float_value(tuning, "net_gun_height", 140.0),
				"min_height": _float_value(tuning, "net_gun_min_height", 90.0),
				"color": Color(0.42, 1.0, 0.52),
				"secondary": Color(0.72, 0.95, 1.0),
			},
			"bowling_trap": {
				"kind": "trap_clamp",
				"duration_frames": 90.0,
				"width": 92.0,
				"height": 42.0,
				"color": Color(0.95, 0.18, 0.24),
				"secondary": Color(0.22, 0.10, 0.12),
			},
			"suicide_drone": {
				"kind": "fire_zone",
				"duration_frames": 150.0,
				"width": 150.0,
				"height": 60.0,
				"color": Color(1.0, 0.28, 0.08),
				"secondary": Color(1.0, 0.78, 0.18),
			},
		},
		"weapon_profile_overrides": {
			"fire_support": {"explosion_radius": grenade_explosion_radius},
		},
		"hit_feedback_profile_overrides": {
			"fire_support": {"shake_amount": 0.24, "shake_intensity": 7.0},
		},
		"hit_result_profile_overrides": {
			"fire_support": {
				"stun_frames": grenade_boss_stun_frames,
				"knockback_power": grenade_boss_knockback_power,
				"knockback_frames": grenade_boss_knockback_frames,
				"knockback_decay_per_frame": grenade_boss_knockback_decay,
			},
		},
	}


static func _float_value(tuning: Dictionary, key: String, fallback: float) -> float:
	return float(tuning.get(key, fallback))


static func _int_value(tuning: Dictionary, key: String, fallback: int) -> int:
	return int(tuning.get(key, fallback))


static func _vector2_value(tuning: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = tuning.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
