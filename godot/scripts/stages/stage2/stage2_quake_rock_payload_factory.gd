extends RefCounted


func build_quake_rock(
	rock_id: int,
	spawn_index: int,
	target: Vector2,
	fall_y: float,
	size: float,
	gravity: float,
	max_bounces: int,
	seed_value: int,
	is_golden: bool,
	rock_life: float,
	visual_data: Dictionary
) -> Dictionary:
	var rock := {
		"id": rock_id,
		"pos": Vector2(target.x, fall_y),
		"target_pos": target,
		"fall_y": fall_y,
		"quake_offset": Vector2.ZERO,
		"falling": true,
		"spawn_delay_frames": float(spawn_index * 10),
		"delay_timer_frames": 0.0,
		"fall_speed": 0.0,
		"gravity": gravity,
		"bounce_count": 0,
		"max_bounces": max_bounces,
		"fall_progress": 0.0,
		"shadow_scale": 0.2,
		"radius": size * 0.5,
		"visual_radius": size,
		"hp": 1,
		"life": rock_life,
		"flash": 0.0,
		"water_target_flash": 0.0,
		"phase": float(seed_value % 628) / 100.0,
		"seed": seed_value,
		"is_golden": is_golden,
	}
	rock.merge(visual_data, true)
	return rock
