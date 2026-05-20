extends RefCounted


func update(intro: Object, dt: float, config: Dictionary) -> void:
	if intro == null:
		return
	var phase_1_duration: float = float(config.get("phase_1_duration", 2.0))
	var phase_2_duration: float = float(config.get("phase_2_duration", 0.75))
	var phase_3_duration: float = float(config.get("phase_3_duration", 1.25))
	var ball_render_radius: float = float(config.get("ball_render_radius", 26.6175))
	var phase3_trail_limit: int = int(config.get("phase3_trail_limit", 18))
	var max_hologram_rings: int = int(config.get("max_hologram_rings", 9))
	var max_sparks: int = int(config.get("max_sparks", 34))
	var max_electric_arcs: int = int(config.get("max_electric_arcs", 7))
	var max_energy_rings: int = int(config.get("max_energy_rings", 5))
	var max_lightning_bolts: int = int(config.get("max_lightning_bolts", 12))
	var phase_time: float = float(intro.elapsed_sec) - phase_1_duration - phase_2_duration
	var progress: float = clamp(phase_time / phase_3_duration, 0.0, 1.0)

	for ring in intro.vortex_rings:
		ring.angle += ring.rotation_speed * dt
		ring.radius += sin(phase_time * 2.5 + ring.angle) * dt * 22.0
		ring.center.y -= dt * 14.0
		ring.radius *= max(0.0, 1.0 - dt * 0.42)
	var keep_v: Array = []
	for ring in intro.vortex_rings:
		if ring.radius > 3.0:
			keep_v.append(ring)
	intro.vortex_rings = keep_v

	var ball_state: Dictionary = intro._get_ball_state()
	var bp: Vector2 = intro._get_vector2(ball_state.get("pos", intro.start_pos), intro.start_pos)
	intro.phase3_trail.append(bp)
	if intro.phase3_trail.size() > phase3_trail_limit:
		intro.phase3_trail.pop_front()

	intro.hologram_spawn_timer += dt
	if intro.hologram_spawn_timer >= 0.14 and intro.hologram_rings.size() < max_hologram_rings:
		intro.hologram_spawn_timer = 0.0
		for radius_mult in [1.4, 2.3, 3.2]:
			intro.hologram_rings.append(intro._make_hologram_ring(bp, ball_render_radius * radius_mult))
	for hologram in intro.hologram_rings:
		intro._update_hologram_ring(hologram, dt, bp)
	intro._prune_lifetime(intro.hologram_rings, dt)

	intro.spark_spawn_timer += dt
	if intro.spark_spawn_timer >= 0.05 and intro.sparks.size() < max_sparks:
		intro.spark_spawn_timer = 0.0
		var move_dir: float = PI * 0.5 if intro.player_serves else -PI * 0.5
		var spark_base: float = move_dir + PI
		var burst: int = intro.rng.randi_range(2, 4)
		for _i in range(burst):
			var sa: float = spark_base + intro.rng.randf_range(-0.9, 0.9)
			intro.sparks.append(intro._make_spark(
				bp + Vector2(intro.rng.randf_range(-10.0, 10.0), intro.rng.randf_range(-6.0, 6.0)),
				sa
			))
	for spark in intro.sparks:
		intro._update_spark(spark, dt)
	intro._prune_lifetime(intro.sparks, dt)

	intro.arc_spawn_timer += dt
	if intro.arc_spawn_timer >= 0.12 and intro.electric_arcs.size() < max_electric_arcs:
		intro.arc_spawn_timer = 0.0
		intro.electric_arcs.append(intro._make_electric_arc(bp, ball_render_radius * 1.9))
	for arc in intro.electric_arcs:
		intro._update_electric_arc(arc, dt, bp)
	intro._prune_lifetime(intro.electric_arcs, dt)

	intro.energy_ring_timer += dt
	if intro.energy_ring_timer >= 0.20 and intro.energy_rings.size() < max_energy_rings:
		intro.energy_ring_timer = 0.0
		intro.energy_rings.append(intro._make_energy_ring(bp, ball_render_radius))
	for ring in intro.energy_rings:
		intro._update_energy_ring(ring, dt, bp)
	intro._prune_lifetime(intro.energy_rings, dt)

	if intro.phase3_trail.size() >= 5 and intro.rng.randf() < 0.35 and intro.lightning_bolts.size() < max_lightning_bolts:
		var idx: int = intro.rng.randi_range(0, max(0, intro.phase3_trail.size() - 5))
		var tail: Vector2 = intro.phase3_trail[idx]
		if tail.distance_to(bp) > 18.0:
			intro.lightning_bolts.append(intro._make_lightning_bolt(tail, bp, true, 0))
	intro._prune_lifetime(intro.lightning_bolts, dt)

	var keep_p: Array = []
	for particle in intro.particles:
		if intro.rng.randf() > 0.10:
			keep_p.append(particle)
	intro.particles = keep_p
	for particle in intro.particles:
		intro._update_quantum_particle(particle, 1.0, dt)

	intro.core_glow_alpha = 120.0 * (1.0 - progress)
	intro.core_glow_radius = max(6.0, 24.0 - progress * 18.0)

	var global_t: float = float(intro.elapsed_sec) * PI * 0.5
	if progress < 0.65:
		var fog_remain: float = pow(1.0 - progress / 0.65, 1.2)
		var fog_shimmer: float = 0.5 + 0.5 * sin(progress * PI * 2.5)
		intro.fog_alpha = 36.0 * fog_remain * fog_shimmer
		var wr: float = sin(global_t)
		var wg: float = sin(global_t + PI * 2.0 / 3.0)
		var wb: float = sin(global_t + PI * 4.0 / 3.0)
		var r2: int = clampi(210 + int(35.0 * wr), 170, 255)
		var g2: int = clampi(198 + int(38.0 * wg), 165, 255)
		var b2: int = clampi(225 + int(27.0 * wb), 200, 255)
		intro.fog_color = Color(r2 / 255.0, g2 / 255.0, b2 / 255.0, 1.0)
	else:
		intro.fog_alpha = 0.0
