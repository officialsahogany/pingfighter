extends RefCounted


static func update_windows(runtime: Object, fps_scale: float, context: Dictionary, deps: Dictionary, constants: Dictionary) -> void:
	if runtime.core_flip_dark_blade_handoff_frames > 0.0:
		runtime.core_flip_dark_blade_handoff_frames = max(0.0, runtime.core_flip_dark_blade_handoff_frames - fps_scale)
	if runtime.dark_blade_window:
		runtime.dark_blade_window_frames = max(0.0, runtime.dark_blade_window_frames - fps_scale)
		if runtime.dark_blade_window_frames <= 0.0 or _should_close_dark_blade_window(runtime, context, deps):
			runtime.dark_blade_window = false; runtime.dark_blade_window_frames = 0.0; runtime.core_flip_dark_blade_handoff_frames = 0.0
	if runtime.blade_motion_active and runtime.blade_motion_phase == 2:
		if runtime.blade_dark_mode:
			runtime.blade_dark_fire_frames += fps_scale
			if runtime.blade_dark_fire_frames >= float(constants.get("combo_delay_frames", 30.0)):
				runtime.blade_dark_combo_window = true
		else:
			runtime.blade_air_fire_frames += fps_scale
			if runtime.blade_air_fire_frames >= float(constants.get("combo_delay_frames", 30.0)):
				runtime.blade_air_combo_window = true
	elif not runtime.blade_motion_active:
		runtime._reset_blade_motion_combo_windows()


static func _should_close_dark_blade_window(runtime: Object, context: Dictionary, deps: Dictionary) -> bool:
	return not runtime.visibility_query.is_viper_airborne(deps) and not bool(context.get("viper_jetpack_airborne", false)) and not ((runtime.core_flip_attack_active and runtime.core_flip_ball_hit) or runtime.core_flip_dark_blade_handoff_frames > 0.0) and not runtime.marshal_active
