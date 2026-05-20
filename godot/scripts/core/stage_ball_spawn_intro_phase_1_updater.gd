extends RefCounted


func update(intro: Object, dt: float, config: Dictionary) -> void:
	if intro == null:
		return
	var game_width: float = float(config.get("game_width", 760.0))
	var game_height: float = float(config.get("game_height", 750.0))
	var phase_1_duration: float = float(config.get("phase_1_duration", 2.0))
	var quantum_particle_hard_cap: int = int(config.get("quantum_particle_hard_cap", 36))
	var max_electric_arcs: int = int(config.get("max_electric_arcs", 7))
	var max_chain_lightnings: int = int(config.get("max_chain_lightnings", 2))
	var progress: float = clamp(float(intro.elapsed_sec) / phase_1_duration, 0.0, 1.0)

	for particle in intro.particles:
		intro._update_quantum_particle(particle, progress, dt)
	for ring in intro.vortex_rings:
		intro._update_vortex_ring(ring, progress, dt)

	intro.lightning_spawn_timer += dt
	var spawn_interval: float
	if progress < 0.8:
		spawn_interval = max(0.060, 0.20 - progress * 0.16)
	else:
		var fadeout: float = (progress - 0.8) / 0.2
		spawn_interval = 0.060 + fadeout * 0.32
	if intro.lightning_spawn_timer >= spawn_interval:
		intro.lightning_spawn_timer = 0.0
		intro._spawn_phase1_lightning(progress)

	intro.chain_spawn_timer += dt
	if (
		intro.chain_spawn_timer >= 0.18
		and intro.rng.randf() < 0.40 * (1.0 + progress)
		and intro.chain_lightnings.size() < max_chain_lightnings
	):
		intro.chain_spawn_timer = 0.0
		intro._spawn_chain_lightning()

	if progress > 0.45:
		intro.arc_spawn_timer += dt
		if intro.arc_spawn_timer >= 0.22 and intro.electric_arcs.size() < max_electric_arcs:
			intro.arc_spawn_timer = 0.0
			var arc_radius: float = clamp(60.0 * (1.0 - (progress - 0.45) * 1.4), 14.0, 60.0)
			intro.electric_arcs.append(intro._make_electric_arc(intro.start_pos, arc_radius))

	intro._prune_lifetime(intro.lightning_bolts, dt)
	intro._prune_lifetime(intro.chain_lightnings, dt)
	intro._prune_lifetime(intro.electric_arcs, dt)

	intro.particle_spawn_timer += dt
	var room: int = quantum_particle_hard_cap - intro.particles.size()
	if intro.particle_spawn_timer >= 0.30 and room > 0:
		intro.particle_spawn_timer = 0.0
		var max_radius: float = min(game_width, game_height) * 0.4 * (1.0 - progress * 0.5)
		var spawn_count: int = min(room, intro.rng.randi_range(3, 6))
		for _i in range(spawn_count):
			intro.particles.append(intro._make_quantum_particle(max_radius))

	if progress < 0.06:
		var burst: float = 1.0 - (progress / 0.06)
		intro.core_glow_radius = 30.0 + burst * 50.0 + progress * 40.0
		intro.core_glow_alpha = 180.0 + burst * 75.0
	else:
		intro.core_glow_radius = 22.0 + progress * 48.0
		intro.core_glow_alpha = 110.0 + progress * 145.0

	var envelope: float = pow(max(0.0, 1.0 - progress * 0.45), 1.2)
	var slow_breath: float = sin(progress * PI * 4.6)
	var mid_breath: float = sin(progress * PI * 7.8) * 0.22
	var fast_shimmer: float = sin(progress * PI * 19.0) * 0.08
	var pulse: float = 0.38 + 0.62 * max(0.0, slow_breath + mid_breath + fast_shimmer)
	var raw_fog: float = 165.0 * envelope * pulse
	var t1: float = progress * PI * 2.0
	var t2: float = progress * PI * 5.4
	var wave_r: float = sin(t1) + 0.15 * sin(t2)
	var wave_g: float = sin(t1 + PI * 2.0 / 3.0) + 0.12 * sin(t2 + 1.0)
	var wave_b: float = sin(t1 + PI * 4.0 / 3.0) + 0.10 * sin(t2 + 2.0)
	var r: int = clampi(218 + int(34.0 * wave_r), 175, 255)
	var g: int = clampi(205 + int(38.0 * wave_g), 165, 255)
	var b: int = clampi(230 + int(25.0 * wave_b), 200, 255)
	intro.fog_color = Color(r / 255.0, g / 255.0, b / 255.0, 1.0)
	if progress > 0.88:
		var end_t: float = (progress - 0.88) / 0.12
		var transition_alpha: float = 200.0 * (end_t * end_t)
		raw_fog = max(raw_fog, transition_alpha)
		var blend: float = end_t * end_t
		intro.fog_color = Color(
			lerp(intro.fog_color.r, 230.0 / 255.0, blend),
			lerp(intro.fog_color.g, 220.0 / 255.0, blend),
			lerp(intro.fog_color.b, 1.0, blend),
			1.0,
		)
	intro.fog_alpha = clamp(raw_fog, 0.0, 255.0)
