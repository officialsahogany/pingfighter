extends RefCounted


func build_crisis_rock(
	rock_id: int,
	spawn_index: int,
	crisis_rock_count: int,
	rng: RandomNumberGenerator,
	rock_visual_factory: Object,
	y_min: float,
	y_mid: float,
	y_max: float,
	drop_height: float,
	size_scale: float,
	drop_stagger_sec: float,
	drop_time_sec: float,
	rock_life_sec: float
) -> Dictionary:
	var spacing: float = 620.0 / float(crisis_rock_count + 1)
	var target_y := rng.randf_range(y_min, y_mid)
	if spawn_index % 2 == 1:
		target_y = rng.randf_range(y_mid, y_max)
	var target := Vector2(
		70.0 + spacing * float(spawn_index + 1) + rng.randf_range(-18.0, 18.0),
		target_y
	)
	var start := target + Vector2(rng.randf_range(-12.0, 12.0), -drop_height - float(spawn_index) * 7.0)
	var collision_radius := rng.randf_range(25.0, 37.0) * size_scale
	var seed_value := rng.randi()
	var rock_visual: Dictionary = {}
	if rock_visual_factory != null and rock_visual_factory.has_method("build_visual_data"):
		rock_visual = rock_visual_factory.build_visual_data(collision_radius * 2.0, false, seed_value, rng)
	var rock := {
		"id": rock_id,
		"pos": start,
		"start_pos": start,
		"target_pos": target,
		"quake_offset": Vector2.ZERO,
		"falling": true,
		"drop_delay": float(spawn_index) * drop_stagger_sec,
		"fall_timer": drop_time_sec,
		"fall_total": drop_time_sec,
		"fall_progress": 0.0,
		"radius": collision_radius,
		"visual_radius": collision_radius * 2.0,
		"hp": 1,
		"life": rock_life_sec,
		"flash": 0.0,
		"water_target_flash": 0.0,
		"phase": rng.randf_range(0.0, TAU),
		"seed": seed_value,
		"crisis_wall": true,
	}
	rock.merge(rock_visual, true)
	return rock
