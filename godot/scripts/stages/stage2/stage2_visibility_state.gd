extends RefCounted


static func has_visible_effects(
	playfield_overlay_visible: bool,
	playfield_obstacles_visible: bool,
	rustle_active: bool
) -> bool:
	return playfield_overlay_visible or playfield_obstacles_visible or rustle_active


static func has_visible_playfield_overlay(
	border_flash_active: bool,
	boss_rage_active: bool,
	boss_rage_tint: float,
	skill_warning_active: bool,
	fragment_hit_flash_timer: float,
	leaf_particle_count: int,
	starpoint_drop_count: int,
	starpoint_particle_count: int
) -> bool:
	return (
		border_flash_active
		or boss_rage_active
		or boss_rage_tint > 0.001
		or skill_warning_active
		or fragment_hit_flash_timer > 0.0
		or leaf_particle_count > 0
		or starpoint_drop_count > 0
		or starpoint_particle_count > 0
	)


static func has_visible_playfield_obstacles(
	quake_timer: float,
	water_cannon_phase: String,
	rock_count: int,
	rock_fragment_count: int,
	water_trail_count: int,
	water_splash_count: int
) -> bool:
	return (
		quake_timer > 0.0
		or water_cannon_phase != "idle"
		or rock_count > 0
		or rock_fragment_count > 0
		or water_trail_count > 0
		or water_splash_count > 0
	)


static func is_boss_movement_locked(boss_rage_active: bool, water_cannon_phase: String) -> bool:
	return boss_rage_active or water_cannon_phase in ["charging", "firing"]
