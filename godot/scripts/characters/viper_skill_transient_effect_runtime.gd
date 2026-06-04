extends RefCounted


static func update_nerve_transients(runtime: Object, fps_scale: float) -> void:
	if runtime.nerve_strike_miss_text_timer > 0.0:
		runtime.nerve_strike_miss_text_timer = _tick_down(runtime.nerve_strike_miss_text_timer, fps_scale)
	if runtime.nerve_strike_slash_vfx_frames > 0.0:
		runtime.nerve_strike_slash_vfx_frames = _tick_down(runtime.nerve_strike_slash_vfx_frames, fps_scale)


static func update_dive_and_core_transients(runtime: Object, fps_scale: float) -> void:
	if runtime.dive_hit_text_timer > 0.0:
		runtime.dive_hit_text_timer = _tick_down(runtime.dive_hit_text_timer, fps_scale)
	runtime.particle_drawer.update_dive_particle_array(runtime.dive_charge_particles, fps_scale)
	runtime.particle_drawer.update_dive_particle_array(runtime.dive_particles, fps_scale)
	if runtime.core_flip_miss_text_timer > 0.0:
		runtime.core_flip_miss_text_timer = _tick_down(runtime.core_flip_miss_text_timer, fps_scale)


static func update_venom_and_marshal_transients(runtime: Object, fps_scale: float, venom_total_frames: float) -> void:
	if runtime.venom_edge_strike_active:
		runtime.venom_edge_strike_elapsed_frames += fps_scale
		if runtime.venom_edge_strike_elapsed_frames >= venom_total_frames:
			runtime.venom_edge_strike_active = false
			runtime.venom_edge_strike_elapsed_frames = 0.0
	runtime.particle_drawer.update_particle_list(runtime.marshal_particles, fps_scale, 0.985, 0.0)
	runtime.particle_drawer.update_particle_list(runtime.phantom_hit_particles, fps_scale, 0.97, 0.04)


static func _tick_down(value: float, fps_scale: float) -> float:
	return max(0.0, value - fps_scale)
