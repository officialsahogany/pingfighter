extends RefCounted

const ViperSkillGeometry := preload("res://scripts/characters/viper_skill_geometry.gd")


static func try_command_activation(runtime: Object, player_pos: Vector2, special_gauge: float, config: Dictionary, deps: Dictionary, now_msec: int, constants: Dictionary) -> Dictionary:
	var skill_name: String = str(constants.get("skill_name", "dual_glitch"))
	if not runtime.command_tracker.consume_dual_glitch_command_ready(runtime, now_msec, int(constants.get("command_window_msec", 1200))):
		return {}
	if not (runtime.dual_glitch_state == "idle" and not runtime._has_viper_attack_motion_active(true) and runtime.chaos_state != "startup" and not (runtime.visibility_query.is_dash_motion_busy(deps) or runtime.visibility_query.is_control_locked(deps)) and bool(config.get("ball_active", false)) and not runtime.visibility_query.is_round_waiting_for_serve(deps)):
		return {}
	var dual_glitch_skill_config: Object = runtime.visibility_query.get_viper_skill_config(deps)
	if not runtime._can_activate_configured_skill(dual_glitch_skill_config, special_gauge, deps, skill_name, now_msec):
		return {}
	var dual_glitch_next_gauge: float = max(0.0, special_gauge - runtime.visibility_query.get_skill_cost(dual_glitch_skill_config, skill_name))
	runtime.dual_glitch_state = "startup"
	runtime.dual_glitch_phase_frames = 0.0
	var duration_pct: float = float(runtime._get_four_poisons_scaled_pct(deps, constants.get("duration_pct_values", []), int(constants.get("duration_pct_cap", 45)), int(constants.get("duration_pct_per_extra", 5))))
	runtime.dual_glitch_active_total_frames = max(1.0, float(constants.get("active_frames", 900.0)) * (1.0 + duration_pct / 100.0))
	runtime.dual_glitch_locked_player_x = player_pos.x
	runtime.dual_glitch_locked_player_x_valid = true
	runtime.dual_glitch_base_pos = player_pos
	runtime.dual_glitch_paddle_size = ViperSkillGeometry.get_paddle_size(config)
	runtime.dual_glitch_fade_reason = ""
	runtime.dual_glitch_start_msec = now_msec
	runtime.dual_glitch_cmd_buffer.clear()
	runtime.dual_glitch_clones.clear()
	var clone_hp: int = runtime.skill_scaling.get_dual_glitch_clone_hp(runtime.visibility_query.get_runtime_skill_level(deps, "four_poisons"), constants.get("clone_hp_values", []), int(constants.get("clone_hp_cap", 6)))
	for side in [-1, 1]:
		runtime.dual_glitch_clones.append({"side": side, "hp": clone_hp, "max_hp": clone_hp, "collision_enabled": true, "evaporation_frames": -1.0})
	var cooldown_seconds: float = runtime._get_skill_cooldown_seconds_with_fallback(dual_glitch_skill_config, skill_name, float(constants.get("cooldown_seconds", 45.0)))
	cooldown_seconds = runtime._get_four_poisons_additive_cooldown_seconds(skill_name, dual_glitch_skill_config, deps, cooldown_seconds)
	runtime.runtime_action_router.trigger_viper_runtime_cooldown(skill_name, now_msec, dual_glitch_skill_config, deps, cooldown_seconds, runtime.visibility_query)
	runtime._trigger_orb_gauge_spin(deps, now_msec)
	runtime.runtime_action_router.trigger_feedback(deps, 0.09, 3.2)
	return {"handled": true, "activated": true, "skill_name": skill_name, "player_pos": Vector2(runtime.dual_glitch_locked_player_x, player_pos.y), "player_speed": 0.0, "special_gauge": dual_glitch_next_gauge, "locked_player_x": runtime.dual_glitch_locked_player_x}


static func update_clone_lifecycle(runtime: Object, fps_scale: float, context: Dictionary, constants: Dictionary) -> void:
	if runtime.dual_glitch_state == "idle":
		return
	if _should_hard_stop_dual_glitch_context(context):
		runtime._reset_dual_glitch_runtime(true)
		return
	runtime.dual_glitch_base_pos = _get_vector2(context.get("player_pos", runtime.dual_glitch_base_pos), runtime.dual_glitch_base_pos)
	runtime.dual_glitch_paddle_size = _get_vector2(context.get("player_paddle_size", runtime.dual_glitch_paddle_size), runtime.dual_glitch_paddle_size)
	if _should_pause_for_round_boundary(context):
		return
	runtime.dual_glitch_phase_frames += fps_scale
	_update_clone_evaporation(runtime, fps_scale)
	_update_lifecycle_state(runtime, constants)
	_prune_finished_clones(runtime, float(constants.get("evaporation_frames", 13.2)))


static func _should_hard_stop_dual_glitch_context(context: Dictionary) -> bool:
	var character_type := ""
	if context.has("selected_character_type"):
		character_type = str(context.get("selected_character_type", "viper")).strip_edges().to_lower()
	return character_type != "" and character_type != "viper"


static func _should_pause_for_round_boundary(context: Dictionary) -> bool:
	return bool(context.get("waiting_for_serve", false)) or not bool(context.get("ball_active", true))


static func _update_clone_evaporation(runtime: Object, fps_scale: float) -> void:
	for index in range(runtime.dual_glitch_clones.size()):
		var clone_value: Variant = runtime.dual_glitch_clones[index]
		if not (clone_value is Dictionary):
			continue
		var clone: Dictionary = clone_value
		var evaporation_frames: float = float(clone.get("evaporation_frames", -1.0))
		if evaporation_frames >= 0.0:
			clone["evaporation_frames"] = evaporation_frames + fps_scale; runtime.dual_glitch_clones[index] = clone


static func _update_lifecycle_state(runtime: Object, constants: Dictionary) -> void:
	match runtime.dual_glitch_state:
		"startup":
			if runtime.dual_glitch_phase_frames >= float(constants.get("startup_frames", 48.0)):
				runtime.dual_glitch_state = "spawn"; runtime.dual_glitch_phase_frames = 0.0; runtime.dual_glitch_locked_player_x_valid = false
		"spawn":
			if runtime.dual_glitch_phase_frames >= float(constants.get("spawn_frames", 22.8)):
				runtime.dual_glitch_state = "active"; runtime.dual_glitch_phase_frames = 0.0
		"active":
			if not runtime.visibility_query.has_living_dual_glitch_clone(runtime.dual_glitch_clones):
				runtime._enter_dual_glitch_fade("destroyed")
			elif runtime.dual_glitch_phase_frames >= runtime.dual_glitch_active_total_frames:
				runtime._enter_dual_glitch_fade("timeout")
		"fade":
			if runtime.dual_glitch_phase_frames >= float(constants.get("fade_frames", 18.0)):
				runtime._reset_dual_glitch_runtime(false)


static func _prune_finished_clones(runtime: Object, evaporation_frames: float) -> void:
	var alive_clones: Array = []
	for clone_value in runtime.dual_glitch_clones:
		if not (clone_value is Dictionary):
			continue
		var clone: Dictionary = clone_value
		if runtime.visibility_query.is_dual_glitch_clone_alive(clone) or runtime.visibility_query.is_dual_glitch_clone_evaporating(clone, evaporation_frames):
			alive_clones.append(clone)
	runtime.dual_glitch_clones = alive_clones


static func update_clone_dive_entries(runtime: Object, fps_scale: float, deps: Dictionary, constants: Dictionary) -> void:
	if runtime.dual_glitch_clone_dive_entries.is_empty():
		return
	var updated_entries: Array = []
	for entry_value in runtime.dual_glitch_clone_dive_entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		if not bool(entry.get("activated", false)):
			_update_pending_dive_entry(runtime, entry, fps_scale, deps, constants)
		else:
			entry["timer"] = max(0.0, float(entry.get("timer", 0.0)) - fps_scale)
		if (not bool(entry.get("activated", false))) or float(entry.get("timer", 0.0)) > 0.0:
			updated_entries.append(entry)
	runtime.dual_glitch_clone_dive_entries = updated_entries


static func _update_pending_dive_entry(runtime: Object, entry: Dictionary, fps_scale: float, deps: Dictionary, constants: Dictionary) -> void:
	var delay_frames: float = max(0.0, float(entry.get("delay_frames", 0.0)) - fps_scale)
	entry["delay_frames"] = delay_frames; entry["telegraph"] = delay_frames > 0.0 and delay_frames <= float(constants.get("telegraph_frames", 6.0))
	if delay_frames <= 0.0:
		entry["activated"] = true; entry["telegraph"] = false; entry["timer"] = float(constants.get("shockwave_frames", 60.0))
		var center := Vector2(float(entry.get("x", runtime.dive_shockwave_pos.x)), float(entry.get("y", runtime.dive_shockwave_pos.y)))
		runtime.particle_drawer.spawn_dual_glitch_clone_dive_particles(runtime.dive_particles, center, int(constants.get("particle_limit", 150)))
		runtime.runtime_action_router.trigger_feedback(deps, 0.08, 2.4)


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
