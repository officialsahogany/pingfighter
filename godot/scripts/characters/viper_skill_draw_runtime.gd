extends RefCounted


static func draw(runtime: Object, canvas: CanvasItem, shake_offset: Vector2, node_fx_layout: Dictionary, timer_stack: Object, perf_logger: Object, effect_lod_scale: float, constants: Dictionary) -> void:
	if canvas == null or not runtime.has_visible_effects():
		runtime.fx_host_controller.hide_fx_host(runtime.chaos_fx_host)
		runtime.fx_host_controller.hide_fx_host(runtime.emp_fx_host)
		return
	var clamped_lod_scale: float = max(0.1, effect_lod_scale); var sample_start: int = _perf_begin(perf_logger); var emp_fx_synced: bool = runtime.fx_host_controller.sync_emp_strike_fx(runtime, canvas, shake_offset, node_fx_layout, runtime.visibility_query, runtime.particle_drawer, float(constants.get("dive_shockwave_frames", 60.0)), float(constants.get("dive_jetpack_max_height", 200.0)), float(constants.get("dive_hit_text_frames", 50.0)))
	if not emp_fx_synced:
		runtime.particle_drawer.draw_dive_effects(canvas, shake_offset, runtime, runtime.floating_text_renderer, float(constants.get("dive_shockwave_frames", 60.0)), float(constants.get("dual_glitch_dive_telegraph_frames", 6.0)), float(constants.get("dive_hit_text_frames", 50.0)), float(constants.get("dive_hit_text_float_y", 36.0)), clamped_lod_scale)
	_perf_end(perf_logger, "viper.skill.emp_dive", sample_start)
	sample_start = _perf_begin(perf_logger)
	var ignition_aura_ratio: float = runtime.visibility_query.get_ignition_aura_ratio(runtime)
	runtime.particle_drawer.draw_ignition_aura_effects(canvas, shake_offset, runtime, ignition_aura_ratio, str(constants.get("ignition_aura_effect_sheet_path", "")), int(constants.get("ignition_aura_effect_sheet_cols", 4)), int(constants.get("ignition_aura_effect_sheet_rows", 4)), int(constants.get("ignition_aura_effect_frame_interval_msec", 70)), clamped_lod_scale)
	runtime.timer_gauge_renderer.draw_ignition_aura_runtime_timer_gauge(canvas, timer_stack, runtime, constants.get("ignition_timer_bar_size", Vector2(150.0, 12.0)), constants.get("ignition_timer_bar_margin", Vector2(16.0, 28.0)), float(constants.get("ignition_timer_stack_spacing", 18.0)), str(constants.get("ignition_timer_stack_key", "ignition_aura")))
	_perf_end(perf_logger, "viper.skill.ignition_aura", sample_start)
	sample_start = _perf_begin(perf_logger)
	runtime.dual_glitch_effect_renderer.draw_dual_glitch_runtime_effects(canvas, shake_offset, runtime, runtime._get_dual_glitch_clone_rect_entries(false, true), float(constants.get("dual_glitch_startup_frames", 48.0)), float(constants.get("dual_glitch_spawn_frames", 22.8)), float(constants.get("dual_glitch_fade_frames", 18.0)), float(constants.get("dual_glitch_evaporation_frames", 13.2)), float(constants.get("dual_glitch_offset_padding", -15.0)), float(constants.get("dual_glitch_alpha", 0.63)), float(constants.get("dual_glitch_wiggle_amplitude", 3.0)))
	runtime.timer_gauge_renderer.draw_dual_glitch_runtime_timer_gauge(canvas, timer_stack, runtime, constants.get("dual_glitch_timer_bar_size", Vector2(150.0, 12.0)), constants.get("dual_glitch_timer_bar_margin", Vector2(16.0, 28.0)), float(constants.get("dual_glitch_timer_stack_spacing", 18.0)), str(constants.get("dual_glitch_timer_stack_key", "dual_glitch")))
	_perf_end(perf_logger, "viper.skill.dual_glitch", sample_start)
	sample_start = _perf_begin(perf_logger)
	runtime.blade_effect_renderer.draw_blade_effects(canvas, shake_offset, runtime, runtime.blade_effect_renderer.get_draw_constants(float(constants.get("blade_base_width", 350.0)), float(constants.get("blade_hitbox_height", 55.0)), float(constants.get("blade_dark_hitbox_height", 83.0)), float(constants.get("blade_fadeout_frames", 30.0)), float(constants.get("blade_rest_frames", 66.0)), float(constants.get("blade_dark_rest_frames", 90.0))))
	_perf_end(perf_logger, "viper.skill.blade", sample_start)
	sample_start = _perf_begin(perf_logger)
	runtime.wall_leap_state.draw_effects(canvas, shake_offset, node_fx_layout)
	_perf_end(perf_logger, "viper.skill.wall_leap_raid", sample_start)
	sample_start = _perf_begin(perf_logger)
	runtime.particle_drawer.draw_nerve_strike_runtime_effects(canvas, shake_offset, runtime, float(constants.get("nerve_dash_frames", 30.0)), float(constants.get("nerve_return_hit_frames", 15.0)), float(constants.get("nerve_return_miss_frames", 9.0)), float(constants.get("nerve_slash_vfx_frames", 30.0)), float(constants.get("dual_glitch_nerve_stagger_frames", 12.0)), float(constants.get("dual_glitch_nerve_slash_frames", 12.0)))
	runtime.floating_text_renderer.draw_nerve_strike_miss_text(canvas, runtime.nerve_strike_miss_text_timer, runtime.nerve_strike_miss_text_pos, shake_offset, float(constants.get("nerve_miss_text_frames", 60.0)), float(constants.get("nerve_miss_text_float_y", 34.0)))
	_perf_end(perf_logger, "viper.skill.nerve_strike", sample_start)
	sample_start = _perf_begin(perf_logger)
	runtime.kick_effect_renderer.draw_core_flip_effects(canvas, shake_offset, runtime, float(constants.get("core_flip_phase0_frames", 24.0)), float(constants.get("core_flip_phase2_frames", 23.4)))
	runtime.floating_text_renderer.draw_core_flip_miss_text(canvas, runtime.core_flip_miss_text_timer, runtime.core_flip_miss_text_pos, shake_offset, float(constants.get("core_flip_miss_text_frames", 50.0)), float(constants.get("core_flip_miss_text_float_y", 34.0)))
	_perf_end(perf_logger, "viper.skill.core_flip", sample_start)
	sample_start = _perf_begin(perf_logger)
	runtime.kick_effect_renderer.draw_marshal_effect_stack(canvas, shake_offset, runtime, runtime.particle_drawer, float(constants.get("viper_hit_particle_glow_size_threshold", 3.2)), float(constants.get("marshal_dmk_freeze_frames", 60.0)), float(constants.get("marshal_dmk_text_frames", 80.0)), clamped_lod_scale)
	_perf_end(perf_logger, "viper.skill.marshal", sample_start)
	sample_start = _perf_begin(perf_logger)
	runtime.shadow_effect_renderer.draw_shadow_step_wave(canvas, shake_offset, runtime)
	var shadow_draw_constants: Dictionary = runtime.shadow_effect_renderer.get_draw_constants(float(constants.get("shadow_step_hologram_frames", 30.0)), constants.get("viper_hologram_base_visual_size", Vector2(160.0, 160.0)), float(constants.get("viper_hologram_base_paddle_width", 155.0)), float(constants.get("viper_hologram_feet_offset", 12.0)), int(constants.get("shadow_step_starburst_frames", 5)))
	runtime.shadow_effect_renderer.draw_shadow_step_hologram(canvas, shake_offset, runtime, shadow_draw_constants)
	runtime.shadow_effect_renderer.draw_shadow_starburst(canvas, shake_offset, runtime, shadow_draw_constants)
	_perf_end(perf_logger, "viper.skill.shadow_step", sample_start)
	sample_start = _perf_begin(perf_logger)
	var absorb_center: Vector2 = runtime.chaos_target + shake_offset
	runtime.chaos_spear_effect_renderer.draw_chaos_absorb_pulses(canvas, absorb_center, runtime.chaos_absorb_pulses, shake_offset)
	var chaos_fx_synced := false
	if runtime.chaos_state != "idle":
		chaos_fx_synced = runtime.fx_host_controller.sync_chaos_spear_fx(runtime, canvas, shake_offset, node_fx_layout, runtime.chaos_spear_effect_renderer, float(constants.get("chaos_startup_frames", 45.0)), float(constants.get("chaos_travel_frames", 16.8)), float(constants.get("chaos_impact_frames", 21.6)), float(constants.get("chaos_blackhole_frames", 180.0)), float(constants.get("chaos_fade_frames", 25.2)), float(constants.get("chaos_fx_disk_height", 220.0)))
	runtime.chaos_spear_effect_renderer.draw_chaos_fallback_effects(canvas, shake_offset, runtime, chaos_fx_synced, float(constants.get("chaos_startup_frames", 45.0)), float(constants.get("chaos_impact_frames", 21.6)), float(constants.get("chaos_fade_frames", 25.2)), float(constants.get("chaos_visual_length", 78.0)))
	if not chaos_fx_synced:
		runtime.fx_host_controller.hide_fx_host(runtime.chaos_fx_host)
	runtime.chaos_spear_effect_renderer.draw_chaos_cancel_flash(canvas, runtime.chaos_cancel_flash_frames)
	_perf_end(perf_logger, "viper.skill.chaos_spear", sample_start)


static func _perf_begin(perf_logger: Object) -> int:
	return int(perf_logger.begin_sample()) if perf_logger != null and perf_logger.has_method("begin_sample") else 0


static func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
