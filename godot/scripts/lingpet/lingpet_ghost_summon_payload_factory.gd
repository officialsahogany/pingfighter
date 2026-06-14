extends RefCounted


static func build_ghost(index: int, origin: Vector2, target_y: float, game_left: float, game_right: float) -> Dictionary:
	var target_x := randf_range(game_left + 100.0, game_right - 100.0)
	return {
		"id": index,
		"pos": origin,
		"start_pos": origin,
		"target_pos": Vector2(target_x, target_y),
		"spawn_time": 0.0,
		"vx": randf_range(-5.0, 5.0),
		"hit_cooldown": 0.0,
		"eating": false,
		"eat_timer": 0.0,
		"eat_scale": 1.0,
		"eat_grow_acc": 0.0,
		"eat_bulge_phase": randf_range(0.0, TAU),
		"swallow_sound_played": false,
		"teleporting": false,
		"teleport_phase": "",
		"teleport_timer": 0.0,
		"teleport_target_x": target_x,
		"pre_teleport_pos": origin,
		"phase": randf_range(0.0, TAU),
	}


static func build_dying_ghost(pos: Vector2, phase: float) -> Dictionary:
	return {
		"pos": pos,
		"death_timer": 0.0,
		"phase": phase,
	}


static func build_particle(pos: Vector2, vel: Vector2, life: float, size: float, color_value: Color) -> Dictionary:
	return {
		"pos": pos,
		"vel": vel,
		"life": maxf(0.05, life),
		"age": 0.0,
		"size": size,
		"color": color_value,
	}


static func build_teleport_particle(origin: Vector2, ratio: float, inward: bool) -> Dictionary:
	var angle := randf_range(0.0, TAU)
	var dist := randf_range(0.0, 40.0) * clampf(ratio, 0.0, 1.0)
	var pos := origin + Vector2(cos(angle), sin(angle)) * dist
	var dir := Vector2(cos(angle), sin(angle))
	var velocity := dir * (-120.0 if inward else 150.0) + Vector2(0.0, -60.0)
	var color_options := [
		Color(0.36, 0.92, 0.82, 0.68),
		Color(0.55, 1.0, 0.90, 0.74),
		Color(0.25, 0.72, 0.62, 0.62),
	]
	return {
		"pos": pos,
		"vel": velocity,
		"life": randf_range(0.3, 0.8),
		"age": 0.0,
		"size": randf_range(3.0, 8.0),
		"color": color_options[randi() % color_options.size()],
	}
