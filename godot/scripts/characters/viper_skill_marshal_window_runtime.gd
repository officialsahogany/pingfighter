extends RefCounted


static func update_windows(runtime: Object, fps_scale: float, context: Dictionary, deps: Dictionary, constants: Dictionary) -> void:
	var skill_config: Object = runtime.visibility_query.get_viper_skill_config(deps)
	if runtime.marshal_ready:
		runtime.marshal_ready_frames = max(0.0, runtime.marshal_ready_frames - fps_scale)
		if runtime.marshal_ready_frames <= 0.0 or not runtime.visibility_query.context_has_enough_gauge(context, runtime.visibility_query.get_marshal_skill_cost(skill_config, str(constants.get("marshal_kick", "marshal_kick")), str(constants.get("phantom_kick", "phantom_kick")))):
			runtime._clear_marshal_ready_window()
	if runtime.marshal_first_hit_pending:
		runtime.marshal_first_hit_delay_frames = max(0.0, runtime.marshal_first_hit_delay_frames - fps_scale)
		if runtime.marshal_first_hit_delay_frames <= 0.0:
			runtime._clear_marshal_first_hit_pending()
			if runtime.marshal_phantom_allowed and runtime.shadow_was_airborne and runtime.visibility_query.get_runtime_skill_level(deps, str(constants.get("double_marshal_kick", "double_marshal_kick"))) > 0 and runtime.visibility_query.is_skill_equipped(skill_config, str(constants.get("phantom_kick", "phantom_kick"))) and runtime.visibility_query.context_has_enough_gauge(context, runtime.visibility_query.get_marshal_skill_cost(skill_config, str(constants.get("phantom_kick", "phantom_kick")), str(constants.get("phantom_kick", "phantom_kick")))) and runtime.visibility_query.is_configured_skill_ready(str(constants.get("phantom_kick", "phantom_kick")), deps, -1):
				runtime.double_marshal_ready = true; runtime.double_marshal_ready_frames = float(constants.get("marshal_ready_frames", 90.0))
			else:
				runtime._clear_phantom_kick_chain_window()
	if runtime.double_marshal_ready:
		runtime.double_marshal_ready_frames = max(0.0, runtime.double_marshal_ready_frames - fps_scale)
		if runtime.double_marshal_ready_frames <= 0.0 or not runtime.visibility_query.context_has_enough_gauge(context, runtime.visibility_query.get_marshal_skill_cost(skill_config, str(constants.get("phantom_kick", "phantom_kick")), str(constants.get("phantom_kick", "phantom_kick")))):
			runtime._clear_phantom_kick_chain_window()
	if runtime.dmk_freeze_active:
		var prep_mult: float = runtime._get_marshal_prep_duration_mult(deps)
		runtime.dmk_freeze_frames = max(0.0, runtime.dmk_freeze_frames - fps_scale / max(0.1, prep_mult))
		if runtime.dmk_freeze_frames <= 0.0:
			runtime.dmk_freeze_active = false
	if runtime.dmk_text_active:
		runtime.dmk_text_frames = max(0.0, runtime.dmk_text_frames - fps_scale)
		if runtime.dmk_text_frames <= 0.0:
			runtime.dmk_text_active = false
