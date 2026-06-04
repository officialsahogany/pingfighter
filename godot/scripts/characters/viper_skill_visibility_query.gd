extends RefCounted


func has_visible_effects(runtime: Object) -> bool:
	return (
		has_shadow_step_visuals(runtime)
		or has_blade_visuals(runtime)
		or has_nerve_strike_visuals(runtime)
		or has_emp_strike_visuals(runtime)
		or has_ignition_aura_visuals(runtime)
		or has_dual_glitch_visuals(runtime)
		or has_blade_combo_window_visuals(runtime)
		or has_marshal_kick_visuals(runtime)
		or has_core_flip_visuals(runtime)
		or has_venom_edge_visuals(runtime)
		or has_chaos_spear_visuals(runtime)
	)


func has_shadow_step_visuals(runtime: Object) -> bool:
	return (
		runtime.shadow_hologram_active
		or runtime.shadow_wave_active
		or not runtime.shadow_wave_trail.is_empty()
		or runtime.shadow_starburst_active
		or runtime.phantom_strike_active
	)


func has_emp_strike_visuals(runtime: Object) -> bool:
	return (
		runtime.dive_hold_start_msec > 0
		or not runtime.dive_charge_particles.is_empty()
		or runtime.dive_active
		or not runtime.dive_particles.is_empty()
		or runtime.dive_shockwave_timer > 0.0
		or runtime.dive_hit_text_timer > 0.0
	)


func has_ignition_aura_visuals(runtime: Object) -> bool:
	return (
		runtime.ignition_hold_start_msec > 0
		or runtime.ignition_active
		or not runtime.ignition_charge_particles.is_empty()
		or not runtime.ignition_burst_particles.is_empty()
		or not runtime.ignition_live_embers.is_empty()
	)


func has_dual_glitch_visuals(runtime: Object) -> bool:
	return (
		not runtime.dual_glitch_clone_dive_entries.is_empty()
		or runtime.dual_glitch_state != "idle"
		or not runtime.dual_glitch_clones.is_empty()
	)


func has_nerve_strike_visuals(runtime: Object) -> bool:
	return (
		runtime.nerve_strike_active
		or runtime.nerve_strike_miss_text_timer > 0.0
		or runtime.nerve_strike_slash_vfx_frames > 0.0
		or not runtime.nerve_strike_clone_slashes.is_empty()
	)


func has_blade_visuals(runtime: Object) -> bool:
	return (
		runtime.blade_motion_active
		or runtime.blade_projectile_active
		or not runtime.blade_projectile_trail.is_empty()
		or not runtime.blade_followup_projectiles.is_empty()
	)


func has_blade_combo_window_visuals(runtime: Object) -> bool:
	return (
		runtime.blade_air_combo_window
		or runtime.blade_dark_combo_window
		or runtime.dark_blade_window
	)


func has_core_flip_visuals(runtime: Object) -> bool:
	return (
		runtime.core_flip_attack_active
		or runtime.core_flip_miss_text_timer > 0.0
	)


func has_venom_edge_visuals(runtime: Object) -> bool:
	return (
		runtime.venom_edge_strike_active
		or runtime.venom_edge_stationary_active
	)


func has_marshal_kick_visuals(runtime: Object) -> bool:
	return (
		runtime.marshal_ready
		or runtime.double_marshal_ready
		or runtime.marshal_active
		or runtime.phantom_aura_active
		or runtime.dmk_freeze_active
		or runtime.dmk_text_active
		or not runtime.marshal_web_lines.is_empty()
		or not runtime.core_flip_web_lines.is_empty()
		or not runtime.marshal_particles.is_empty()
		or not runtime.phantom_hit_particles.is_empty()
	)


func has_chaos_spear_visuals(runtime: Object) -> bool:
	return (
		runtime.chaos_state != "idle"
		or not runtime.chaos_absorb_pulses.is_empty()
		or runtime.chaos_cancel_flash_frames > 0.0
	)


func needs_effect_update(runtime: Object) -> bool:
	return (
		has_visible_effects(runtime)
		or runtime.shadow_kick_ready
		or runtime.shadow_marshal_delay_frames > 0.0
		or runtime.shadow_curve_active
		or runtime.marshal_first_hit_pending
	)


func needs_ball_motion_update(runtime: Object) -> bool:
	return (
		runtime.shadow_wave_active
		or runtime.shadow_hologram_active
		or runtime.shadow_curve_active
		or runtime.blade_projectile_active
		or not runtime.blade_followup_projectiles.is_empty()
		or runtime.chaos_release_pending
		or runtime.chaos_state == "blackhole"
		or (runtime.dive_active and runtime.dive_phase == 2 and not runtime.dive_ball_boosted)
		or not runtime.dual_glitch_clone_dive_entries.is_empty()
	)


func is_kick_skill_knockback_ball_active(runtime: Object) -> bool:
	return runtime.kick_skill_knockback_pending_pct > 0


func is_dmk_freeze_active(runtime: Object) -> bool:
	return runtime.dmk_freeze_active


func is_chaos_blackhole_audio_active(runtime: Object) -> bool:
	return runtime.chaos_state in ["impact", "blackhole", "fade"]


func get_ignition_aura_ratio(runtime: Object) -> float:
	if not runtime.ignition_active:
		return 0.0
	return clamp(runtime.ignition_remaining_frames / max(1.0, runtime.ignition_total_frames), 0.0, 1.0)


func get_venom_edge_strike_frame(runtime: Object, total_frames: float) -> int:
	if not runtime.venom_edge_strike_active:
		return 0
	var progress: float = clamp(runtime.venom_edge_strike_elapsed_frames / total_frames, 0.0, 0.999)
	return clamp(int(progress * 8.0), 0, 7)


func get_dual_glitch_remaining_frames(runtime: Object) -> float:
	if runtime.dual_glitch_state == "idle":
		return 0.0
	if runtime.dual_glitch_state in ["startup", "spawn"]:
		return runtime.dual_glitch_active_total_frames
	if runtime.dual_glitch_state == "active":
		return max(0.0, runtime.dual_glitch_active_total_frames - runtime.dual_glitch_phase_frames)
	return 0.0


func get_nerve_strike_freeze_frames(runtime: Object, slash_hit_frames: float) -> float:
	if not runtime.nerve_strike_freeze_active:
		return 0.0
	return max(0.0, slash_hit_frames - runtime.nerve_strike_phase_frames)


func is_dual_glitch_clone_alive(clone: Dictionary) -> bool:
	return int(clone.get("hp", 0)) > 0 and bool(clone.get("collision_enabled", true))


func is_dual_glitch_clone_evaporating(clone: Dictionary, evaporation_frames_total: float) -> bool:
	var evaporation_frames: float = float(clone.get("evaporation_frames", -1.0))
	return evaporation_frames >= 0.0 and evaporation_frames < evaporation_frames_total


func has_living_dual_glitch_clone(clones: Array) -> bool:
	for clone_value in clones:
		if clone_value is Dictionary and is_dual_glitch_clone_alive(clone_value):
			return true
	return false


func get_dual_glitch_clone_rect_entries(
	runtime: Object,
	collision_only: bool,
	include_evaporating: bool,
	evaporation_frames_total: float,
	offset_padding: float
) -> Array:
	var entries: Array = []
	var state_allows_collision: bool = runtime.dual_glitch_state in ["active", "fade"]
	var state_allows_visible: bool = runtime.dual_glitch_state in ["spawn", "active", "fade"]
	if collision_only and not state_allows_collision:
		return entries
	if not collision_only and not state_allows_visible:
		return entries
	var offset_x: float = max(1.0, runtime.dual_glitch_paddle_size.x + offset_padding)
	for index in range(runtime.dual_glitch_clones.size()):
		var clone_value: Variant = runtime.dual_glitch_clones[index]
		if not (clone_value is Dictionary):
			continue
		var clone: Dictionary = clone_value
		var alive: bool = is_dual_glitch_clone_alive(clone)
		var evaporating: bool = is_dual_glitch_clone_evaporating(clone, evaporation_frames_total)
		if collision_only and not alive:
			continue
		if not collision_only and not alive and not (include_evaporating and evaporating):
			continue
		var side: int = int(clone.get("side", 0))
		if side == 0:
			continue
		entries.append({
			"rect": Rect2(runtime.dual_glitch_base_pos + Vector2(float(side) * offset_x, 0.0), runtime.dual_glitch_paddle_size),
			"index": index,
			"side": side,
			"hp": int(clone.get("hp", 0)),
			"max_hp": int(clone.get("max_hp", 1)),
			"alive": alive,
			"evaporating": evaporating,
			"evaporation_frames": float(clone.get("evaporation_frames", -1.0)),
		})
	return entries


func get_dual_glitch_replication_origins(entries: Array) -> Array:
	var origins: Array = []
	for entry_value in entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var rect: Rect2 = entry.get("rect", Rect2())
		origins.append({
			"x": rect.get_center().x,
			"y": rect.get_center().y,
			"bottom": rect.position.y + rect.size.y,
			"side": int(entry.get("side", 0)),
		})
	return origins


func is_viper_airborne(deps: Dictionary) -> bool:
	var jetpack_state: Object = deps.get("viper_jetpack_state", null)
	if jetpack_state != null and jetpack_state.has_method("is_airborne"):
		return bool(jetpack_state.is_airborne(10.0))
	return false


func is_control_locked(deps: Dictionary) -> bool:
	if bool(deps.get("player_skill_input_locked", false)):
		return true
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime != null and active_item_runtime.has_method("is_player_control_locked"):
		if bool(active_item_runtime.is_player_control_locked()):
			return true
	var status_effect_state: Object = deps.get("status_effect_state", null)
	if status_effect_state != null:
		if status_effect_state.has_method("is_player_stun_active") and bool(status_effect_state.is_player_stun_active()):
			return true
		if status_effect_state.has_method("has_status") and bool(status_effect_state.has_status("player", "stun")):
			return true
	var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
	if (
		mythic_item_runtime != null
		and mythic_item_runtime.has_method("is_horn_strawberry_skills_locked")
		and bool(mythic_item_runtime.is_horn_strawberry_skills_locked())
	):
		return true
	if (
		mythic_item_runtime != null
		and mythic_item_runtime.has_method("is_horn_strawberry_control_locked")
		and bool(mythic_item_runtime.is_horn_strawberry_control_locked())
	):
		return true
	return false


func is_round_waiting_for_serve(deps: Dictionary) -> bool:
	var round_state: Object = deps.get("round_state", null)
	return round_state != null and round_state.has_method("is_waiting_for_serve") and bool(round_state.is_waiting_for_serve())


func is_stage2_speed_defense_boss_immune(context: Dictionary = {}, deps: Dictionary = {}) -> bool:
	if int(context.get("current_stage", 0)) == 2:
		if (
			bool(context.get("stage2_speed_defense_status_immunity_active", false))
			or bool(context.get("stage2_speed_defense_active", false))
		):
			return true
	var stage2_skill_state: Object = deps.get("stage2_boss_skill_state", null)
	return (
		stage2_skill_state != null
		and stage2_skill_state.has_method("is_boss_status_immune")
		and bool(stage2_skill_state.is_boss_status_immune())
	)


func should_stop_viper_context_effect(context: Dictionary) -> bool:
	return (
		(context.has("selected_character_type") and str(context.get("selected_character_type", "viper")) != "viper")
		or not bool(context.get("ball_active", true))
		or bool(context.get("waiting_for_serve", false))
	)


func get_viper_skill_config(deps: Dictionary) -> Object:
	var config: Object = deps.get("viper_skill_config", null)
	if config != null:
		return config
	return deps.get("skill_config", null)


func get_viper_skill_state(deps: Dictionary) -> Object:
	var state: Object = deps.get("viper_skill_state", null)
	if state != null:
		return state
	return deps.get("skill_state", null)


func is_skill_equipped(skill_config: Object, skill_name: String) -> bool:
	if skill_config != null and skill_config.has_method("is_skill_equipped"):
		return bool(skill_config.is_skill_equipped(skill_name))
	return false


func get_skill_cost(skill_config: Object, skill_name: String) -> float:
	if skill_config != null and skill_config.has_method("get_skill_cost"):
		return float(skill_config.get_skill_cost(skill_name))
	if skill_config != null and skill_config.has_method("get_snapshot"):
		var snapshot: Variant = skill_config.get_snapshot()
		if snapshot is Dictionary:
			var costs: Variant = snapshot.get("skill_costs", {})
			if costs is Dictionary:
				return float(costs.get(skill_name, 0.0))
	return 0.0


func get_marshal_skill_to_fire(runtime: Object, marshal_kick_name: String, phantom_kick_name: String) -> String:
	if runtime.marshal_ready and runtime.marshal_ready_frames > 0.0:
		return marshal_kick_name
	if runtime.double_marshal_ready and runtime.double_marshal_ready_frames > 0.0:
		return phantom_kick_name
	return ""


func get_marshal_skill_cost(skill_config: Object, skill_name: String, phantom_kick_name: String) -> float:
	var configured: float = get_skill_cost(skill_config, skill_name)
	if configured > 0.0:
		return configured
	if skill_name == phantom_kick_name:
		return 60.0
	return 80.0


func context_has_enough_gauge(context: Dictionary, cost: float) -> bool:
	if not context.has("special_gauge"):
		return true
	return float(context.get("special_gauge", 0.0)) >= cost


func is_configured_skill_ready(skill_name: String, deps: Dictionary, now_msec: int = -1) -> bool:
	var skill_state: Object = get_viper_skill_state(deps)
	if skill_state != null and skill_state.has_method("get_configured_cooldown_remaining"):
		var current_msec: int = now_msec if now_msec >= 0 else Time.get_ticks_msec()
		return skill_state.get_configured_cooldown_remaining(
			skill_name,
			current_msec,
			get_viper_skill_config(deps)
		) <= 0.0
	return true


func get_dash_snapshot(dash_state: Object) -> Dictionary:
	if dash_state != null and dash_state.has_method("get_snapshot"):
		var snapshot: Variant = dash_state.get_snapshot()
		if snapshot is Dictionary:
			return snapshot
	return {}


func is_dash_motion_busy(deps: Dictionary) -> bool:
	var snapshot: Dictionary = get_dash_snapshot(deps.get("dash_state", null))
	return bool(snapshot.get("active", false)) or bool(snapshot.get("recovering", false))


func get_runtime_skill_level(deps: Dictionary, skill_id: String) -> int:
	var runtime_perk_state: Object = deps.get("runtime_perk_state", null)
	if runtime_perk_state != null and runtime_perk_state.has_method("get_runtime_skill_level"):
		return max(0, int(runtime_perk_state.get_runtime_skill_level(skill_id)))
	return 0


func get_mythic_item_runtime(deps: Dictionary) -> Object:
	var runtime: Object = deps.get("mythic_item_runtime", null)
	if runtime != null:
		return runtime
	var registry: Object = deps.get("registry", null)
	if registry != null and registry.has_method("get_instance"):
		return registry.get_instance("mythic_item_runtime")
	return null
