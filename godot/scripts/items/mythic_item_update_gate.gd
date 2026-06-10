extends RefCounted


func has_runtime_update_work(runtime: Object) -> bool:
	if has_modal_runtime_update_work(runtime):
		return true
	return has_transient_runtime_update_work(runtime)


func has_modal_runtime_update_work(runtime: Object) -> bool:
	if runtime.acquisition_cinematic != null and runtime.acquisition_cinematic.has_method("is_active") and bool(runtime.acquisition_cinematic.is_active()):
		return true
	if runtime.pandora_legacy_selection_state.is_active():
		return true
	return false


func has_transient_runtime_update_work(runtime: Object) -> bool:
	if runtime.is_activation_effect_active():
		return true
	if has_ragnarok_transient_runtime_update_work(runtime):
		return true
	return has_non_ragnarok_transient_runtime_update_work(runtime)


func has_ragnarok_transient_runtime_update_work(runtime: Object) -> bool:
	return (
		runtime.ragnarok_stun_ball_active
		or runtime.ragnarok_boss_stun_timer_frames > 0.0
		or runtime.ragnarok_boss_knockback_timer_frames > 0.0
		or abs(runtime.ragnarok_boss_knockback_vel) > 0.0
		or runtime.ragnarok_shock_loop_active
		or not runtime.ragnarok_sparks.is_empty()
	)


func has_non_ragnarok_transient_runtime_update_work(runtime: Object) -> bool:
	if (
		runtime.poseidon_effect_cooldown_frames > 0.0
		or runtime.poseidon_vortex_active
		or runtime.poseidon_vortex_reentry_cooldown_frames > 0.0
		or runtime.poseidon_water_trail_active
		or runtime.poseidon_explosion_active
		or runtime.poseidon_capture_active
		or not runtime.poseidon_particles.is_empty()
		or not runtime.poseidon_water_trail.is_empty()
		or not runtime.poseidon_explosion_particles.is_empty()
	):
		return true
	if runtime.knee_pads_flash_timer_frames > 0.0 or not runtime.knee_pads_particles.is_empty():
		return true
	if (
		runtime.soul_burst_effect_timer_frames > 0.0
		or runtime.soul_burst_dash_active
		or not runtime.soul_burst_particles.is_empty()
		or not runtime.soul_burst_shockwaves.is_empty()
		or not runtime.soul_burst_wind_trails.is_empty()
	):
		return true
	if runtime.foul_whistle_state.animation_active or runtime.foul_whistle_state.pending_round_reset:
		return true
	if runtime.revival_state.is_effect_active():
		return true
	if runtime.odins_eye_runtime.has_runtime_update_work(runtime):
		return true
	if runtime.sensor_cooldown_timer_frames > 0.0 or runtime.sensor_auto_dash_effect_timer_frames > 0.0:
		return true
	if runtime.smartphone_cooldown_frames > 0.0:
		return true
	if runtime.venom_mist_field_active or not runtime.venom_mist_particles.is_empty():
		return true
	if runtime.rainbow_fur_glove_aura_timer_frames > 0.0 or not runtime.rainbow_fur_glove_particles.is_empty():
		return true
	if runtime.adversity_armor_runtime.is_effect_active(runtime):
		return true
	if (
		not runtime.shrapnel_armor_shards.is_empty()
		or not runtime.shrapnel_armor_dust_particles.is_empty()
		or runtime.shrapnel_armor_flash_timer_frames > 0.0
		or runtime.shrapnel_armor_boss_impact_timer_frames > 0.0
		or runtime.shrapnel_armor_boss_knockback_timer_frames > 0.0
		or runtime.shrapnel_armor_boss_stun_timer_frames > 0.0
	):
		return true
	if runtime.celestial_armor_state.is_wave_active():
		return true
	if runtime.is_hermes_shoes_equipped() or runtime.hermes_shoes_state.is_visible(false):
		return true
	if (
		runtime.baal_boots_weather_state.has_round_activity()
		or runtime.baal_boots_effect_state.is_visible(
			runtime.baal_boots_weather_state.cinematic_active,
			runtime.baal_boots_weather_state.round_effect_active
		)
	):
		return true
	if (
		runtime.horn_strawberry_mask_runtime.is_equipped(runtime)
		or runtime.horn_strawberry_mask_runtime.has_runtime_update_work(runtime)
	):
		return true
	return false


func build_update_scope(runtime: Object) -> Dictionary:
	var had_ragnarok_transient_work: bool = has_ragnarok_transient_runtime_update_work(runtime)
	var had_non_ragnarok_transient_work: bool = has_non_ragnarok_transient_runtime_update_work(runtime)
	return {
		"had_ragnarok_transient_work": had_ragnarok_transient_work,
		"had_non_ragnarok_transient_work": had_non_ragnarok_transient_work,
		"had_only_ragnarok_transient_work": had_ragnarok_transient_work and not had_non_ragnarok_transient_work,
		"had_modal_runtime_work": has_modal_runtime_update_work(runtime),
	}


func sync_after_update(runtime: Object, owner: Object, registry: Object, update_scope: Dictionary) -> void:
	var has_non_ragnarok_transient_work: bool = has_non_ragnarok_transient_runtime_update_work(runtime)
	var has_modal_runtime_work: bool = has_modal_runtime_update_work(runtime)
	if (
		(bool(update_scope.get("had_non_ragnarok_transient_work", false)) or has_non_ragnarok_transient_work)
		and not bool(update_scope.get("had_modal_runtime_work", false))
		and not has_modal_runtime_work
	):
		runtime.owner_syncer.sync_transient_owner_state(runtime, owner)
	elif bool(update_scope.get("had_only_ragnarok_transient_work", false)) and not has_non_ragnarok_transient_work:
		runtime.owner_syncer.sync_ragnarok_transient_owner_state(runtime, owner)
	else:
		runtime._sync_owner(owner, registry)
