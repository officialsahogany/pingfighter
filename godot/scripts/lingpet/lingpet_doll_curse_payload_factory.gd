extends RefCounted

const CONFUSION_VISUAL := "koyora_doll_curse"


static func build_doll(
	side: int,
	spawn_pos: Vector2,
	target_pos: Vector2,
	beam_base_angle: float,
	beam_initial_sweep_half_angle: float,
	beam_sweep_phase_slow: String,
	beam_slow_sweep_min_seconds: float,
	beam_slow_sweep_max_seconds: float,
	beam_slow_turn_rate_min: float,
	beam_slow_turn_rate_max: float
) -> Dictionary:
	var angle := randf_range(
		beam_base_angle - beam_initial_sweep_half_angle,
		beam_base_angle + beam_initial_sweep_half_angle
	)
	return {
		"alive": true,
		"side": side,
		"pos": spawn_pos,
		"spawn_pos": spawn_pos,
		"target_pos": target_pos,
		"emerge_progress": 0.0,
		"marionette_rigging": true,
		"beam_angle": angle,
		"beam_target_angle": angle,
		"beam_sweep_phase": beam_sweep_phase_slow,
		"beam_sweep_timer": randf_range(beam_slow_sweep_min_seconds, beam_slow_sweep_max_seconds),
		"beam_turn_rate": randf_range(beam_slow_turn_rate_min, beam_slow_turn_rate_max),
		"beam_homing_targeted": false,
		"beam_homing_focus_active": false,
		"beam_on_boss": false,
		"beam_boss_point": Vector2.ZERO,
		"wobble": randf_range(0.0, TAU),
	}


static func build_confusion_status_data() -> Dictionary:
	return {
		"cleansable": true,
		"visual": CONFUSION_VISUAL,
	}


static func build_destroy_particle(pos: Vector2, particle_life: float) -> Dictionary:
	var angle := randf_range(0.0, TAU)
	var speed := randf_range(55.0, 180.0)
	return {
		"pos": pos + Vector2(randf_range(-8.0, 8.0), randf_range(-10.0, 10.0)),
		"vel": Vector2(cos(angle), sin(angle)) * speed,
		"life": randf_range(0.25, particle_life),
		"max_life": particle_life,
		"size": randf_range(2.0, 5.0),
	}
