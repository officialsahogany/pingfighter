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
		intro.starfield.append({
			"pos": Vector2(intro.rng.randf_range(0.0, game_width), intro.rng.randf_range(0.0, game_height)),
			"size": intro.rng.randf_range(0.7, 2.0),
			"phase": intro.rng.randf_range(0.0, TAU),
			"speed": intro.rng.randf_range(2.5, 7.0),
			"hue": intro.rng.randi_range(0, 4),
		})
	var palette: Array = [
		Color(0.55, 0.75, 1.0),
		Color(0.78, 0.62, 1.0),
		Color(1.0, 0.72, 0.92),
		Color(0.66, 0.92, 1.0),
	]
	for _i in range(haze_cloud_count):
		intro.haze_clouds.append({
			"pos": Vector2(intro.rng.randf_range(80.0, game_width - 80.0), intro.rng.randf_range(80.0, game_height - 80.0)),
			"radius": intro.rng.randf_range(180.0, 320.0),
			"drift_angle": intro.rng.randf_range(0.0, TAU),
			"drift_speed": intro.rng.randf_range(8.0, 20.0),
			"rotation": intro.rng.randf_range(0.0, TAU),
			"rotation_speed": intro.rng.randf_range(-0.3, 0.3),
			"pulse_phase": intro.rng.randf_range(0.0, TAU),
			"pulse_speed": intro.rng.randf_range(0.7, 1.6),
			"color": palette[intro.rng.randi_range(0, palette.size() - 1)],
		})
	intro.fog_alpha = 100.0
	intro.fog_color = Color(0.78, 0.86, 1.0, 1.0)
