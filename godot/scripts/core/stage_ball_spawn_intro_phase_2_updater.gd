extends RefCounted


func update(intro: Object, dt: float, config: Dictionary) -> void:
	if intro == null:
		return
	var phase_1_duration: float = float(config.get("phase_1_duration", 2.0))
	var phase_2_duration: float = float(config.get("phase_2_duration", 0.75))
	var ball_render_radius: float = float(config.get("ball_render_radius", 26.6175))
	var max_energy_rings: int = int(config.get("max_energy_rings", 5))
	var max_electric_arcs: int = int(config.get("max_electric_arcs", 7))
	var phase_time: float = float(intro.elapsed_sec) - phase_1_duration
	var progress: float = clamp(phase_time / phase_2_duration, 0.0, 1.0)

	intro._prune_lifetime(intro.lightning_bolts, dt)
	intro._prune_lifetime(intro.chain_lightnings, dt)
	if progress < 0.55:
		intro.lightning_spawn_timer += dt
		var fade_interval: float = 0.10 + progress * 0.6
		if intro.lightning_spawn_timer >= fade_interval:
			intro.lightning_spawn_timer = 0.0
			var fade_mult: float = max(0.0, 1.0 - progress * 1.7)
			var max_r: float = max(20.0, 90.0 * fade_mult)
			var ang: float = intro.rng.randf_range(0.0, TAU)
			var sx: Vector2 = intro.start_pos + Vector2(cos(ang), sin(ang)) * max_r
			var ex: Vector2 = intro.start_pos + Vector2(
				intro.rng.randf_range(-15.0, 15.0),
				intro.rng.randf_range(-15.0, 15.0)
			)
			intro.lightning_bolts.append(intro._make_lightning_bolt(sx, ex, true, 0))

	intro.energy_ring_timer += dt
	if intro.energy_ring_timer >= 0.14 and intro.energy_rings.size() < max_energy_rings:
		intro.energy_ring_timer = 0.0
		var ball_state: Dictionary = intro._get_ball_state()
		var bp: Vector2 = intro._get_vector2(ball_state.get("pos", intro.start_pos), intro.start_pos)
		var bs: float = float(ball_state.get("scale", 1.0))
		intro.energy_rings.append(intro._make_energy_ring(bp, ball_render_radius * max(0.4, bs)))

	intro.arc_spawn_timer += dt
	if intro.arc_spawn_timer >= 0.20 and intro.electric_arcs.size() < max_electric_arcs:
		intro.arc_spawn_timer = 0.0
		var ball_state2: Dictionary = intro._get_ball_state()
		var bp2: Vector2 = intro._get_vector2(ball_state2.get("pos", intro.start_pos), intro.start_pos)
		var bs2: float = float(ball_state2.get("scale", 1.0))
		intro.electric_arcs.append(intro._make_electric_arc(bp2, ball_render_radius * 1.9 * max(0.5, bs2)))

	var ball_state3: Dictionary = intro._get_ball_state()
	var bp3: Vector2 = intro._get_vector2(ball_state3.get("pos", intro.start_pos), intro.start_pos)
	for ring in intro.energy_rings:
		intro._update_energy_ring(ring, dt, bp3)
	for arc in intro.electric_arcs:
		intro._update_electric_arc(arc, dt, bp3)
	intro._prune_lifetime(intro.energy_rings, dt)
	intro._prune_lifetime(intro.electric_arcs, dt)

	var keep_p: Array = []
	for particle in intro.particles:
		if intro.rng.randf() > 0.18:
			keep_p.append(particle)
	intro.particles = keep_p
	for particle in intro.particles:
		intro._update_quantum_particle(particle, 1.0, dt)

	for ring in intro.vortex_rings:
		intro._update_vortex_ring(ring, 1.0, dt)

	var global_t: float = float(intro.elapsed_sec) * PI * 0.5
	if progress < 0.15:
		var t: float = progress / 0.15
		intro.fog_alpha = max(0.0, 140.0 * (1.0 - t * 0.55))
	else:
		var rt: float = (progress - 0.15) / 0.85
		var remain: float = 1.0 - rt
		var shimmer: float = 0.55 + 0.45 * sin(rt * PI * 3.0)
		intro.fog_alpha = 60.0 * remain * shimmer
	var wr: float = sin(global_t) + 0.12 * sin(global_t * 2.7)
	var wg: float = sin(global_t + PI * 2.0 / 3.0) + 0.10 * sin(global_t * 2.7 + 1.0)
	var wb: float = sin(global_t + PI * 4.0 / 3.0) + 0.08 * sin(global_t * 2.7 + 2.0)
	var r2: int = clampi(215 + int(35.0 * wr), 170, 255)
	var g2: int = clampi(200 + int(38.0 * wg), 165, 255)
	var b2: int = clampi(228 + int(27.0 * wb), 200, 255)
	intro.fog_color = Color(r2 / 255.0, g2 / 255.0, b2 / 255.0, 1.0)

	intro.core_glow_radius = max(8.0, 50.0 - progress * 28.0)
	intro.core_glow_alpha = 220.0 * (1.0 - progress * 0.55)
