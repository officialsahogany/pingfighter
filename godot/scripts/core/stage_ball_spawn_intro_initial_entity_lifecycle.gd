extends RefCounted


func spawn_initial_entities(intro: Object, config: Dictionary) -> void:
	if intro == null:
		return
	var game_width: float = float(config.get("game_width", 760.0))
	var game_height: float = float(config.get("game_height", 750.0))
	var quantum_particle_base: int = int(config.get("quantum_particle_base", 24))
	var vortex_ring_count: int = int(config.get("vortex_ring_count", 5))
	var starfield_count: int = int(config.get("starfield_count", 26))
	var haze_cloud_count: int = int(config.get("haze_cloud_count", 2))
	var max_radius: float = min(game_width, game_height) * 0.4
	for _i in range(quantum_particle_base):
		intro.particles.append(intro._make_quantum_particle(max_radius))
	for i in range(vortex_ring_count):
		var ring_radius: float = max_radius * (0.22 + float(i) * 0.075)
		intro.vortex_rings.append(intro._make_vortex_ring(ring_radius))
	for _i in range(2):
		var angle: float = intro.rng.randf_range(0.0, TAU)
		var sd: float = max_radius * intro.rng.randf_range(0.7, 1.0)
		var sx: Vector2 = intro.start_pos + Vector2(cos(angle), sin(angle)) * sd
		var ed: float = max_radius * intro.rng.randf_range(0.3, 0.55)
		var end_angle: float = angle + intro.rng.randf_range(-0.35, 0.35)
		var ex: Vector2 = intro.start_pos + Vector2(cos(end_angle), sin(end_angle)) * ed
		intro.lightning_bolts.append(intro._make_lightning_bolt(sx, ex, true, 1))
	for _i in range(starfield_count):
		intro.starfield.append(intro._make_starfield_dot(game_width, game_height))
	for _i in range(haze_cloud_count):
		intro.haze_clouds.append(intro._make_haze_cloud(game_width, game_height))
	intro.fog_alpha = 100.0
	intro.fog_color = Color(0.78, 0.86, 1.0, 1.0)
