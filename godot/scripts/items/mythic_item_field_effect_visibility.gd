extends RefCounted


func has_visible_field_effects(runtime: Object, ragnarok_impact_duration: float) -> bool:
	if runtime.ragnarok_runtime.get_impact_elapsed(runtime) < ragnarok_impact_duration:
		return true
	if runtime.ragnarok_boss_stun_timer_frames > 0.0 or not runtime.ragnarok_sparks.is_empty():
		return true
	if (
		runtime.poseidon_capture_active
		or runtime.poseidon_vortex_active
		or not runtime.poseidon_particles.is_empty()
		or not runtime.poseidon_water_trail.is_empty()
		or runtime.poseidon_explosion_active
	):
		return true
	if runtime.knee_pads_flash_timer_frames > 0.0 or not runtime.knee_pads_particles.is_empty():
		return true
	if (
		runtime.soul_burst_effect_timer_frames > 0.0
		or not runtime.soul_burst_particles.is_empty()
		or not runtime.soul_burst_shockwaves.is_empty()
		or not runtime.soul_burst_wind_trails.is_empty()
	):
		return true
	if runtime.foul_whistle_state.animation_active:
		return true
	if runtime.revival_runtime.is_effect_active(runtime):
		return true
	if runtime.sensor_auto_dash_effect_timer_frames > 0.0:
		return true
	if runtime.venom_mist_field_active or not runtime.venom_mist_particles.is_empty():
		return true
	if runtime.rainbow_fur_glove_aura_timer_frames > 0.0 or not runtime.rainbow_fur_glove_particles.is_empty():
		return true
	if runtime.adversity_armor_runtime.is_effect_active(runtime) or runtime.shrapnel_armor_runtime.is_effect_active(runtime):
		return true
	if runtime.celestial_armor_state.is_wave_active():
		return true
	if runtime.yangui_hoechun_runtime.has_visible_effects():
		return true
	if runtime.hermes_shoes_state.is_visible(runtime.is_hermes_shoes_active()):
		return true
	if runtime.baal_boots_effect_state.is_visible(
		runtime.baal_boots_weather_state.cinematic_active,
		runtime.baal_boots_weather_state.round_effect_active
	):
		return true
	if runtime.is_horn_strawberry_transformed():
		return true
	if runtime.horn_strawberry_mask_runtime.has_visible_effects(runtime):
		return true
	return runtime.acquisition_cinematic != null and runtime.acquisition_cinematic.is_active()
