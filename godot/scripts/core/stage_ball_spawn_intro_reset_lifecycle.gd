extends RefCounted


func reset_state(intro: Object) -> void:
	if intro == null:
		return
	var ball_renderer: Variant = intro.get("ball_renderer")
	if ball_renderer != null and ball_renderer.has_method("clear"):
		ball_renderer.clear()
	intro._tear_down_fx_host()
	if intro.has_method("_tear_down_pillar_overlay_host"):
		intro._tear_down_pillar_overlay_host()
	intro.particles.clear()
	intro.vortex_rings.clear()
	intro.lightning_bolts.clear()
	intro.chain_lightnings.clear()
	intro.electric_arcs.clear()
	intro.sparks.clear()
	intro.hologram_rings.clear()
	intro.energy_rings.clear()
	intro.phase3_trail.clear()
	intro.starfield.clear()
	intro.haze_clouds.clear()
	intro.lightning_spawn_timer = 0.0
	intro.arc_spawn_timer = 0.0
	intro.spark_spawn_timer = 0.0
	intro.hologram_spawn_timer = 0.0
	intro.energy_ring_timer = 0.0
	intro.particle_spawn_timer = 0.0
	intro.chain_spawn_timer = 0.0
	intro.fog_alpha = 0.0
	intro.core_glow_radius = 0.0
	intro.core_glow_alpha = 0.0
