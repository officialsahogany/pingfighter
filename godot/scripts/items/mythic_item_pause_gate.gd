extends RefCounted


func should_pause_game(runtime: Object) -> bool:
	return (
		is_baal_boots_cinematic_active(runtime)
		or runtime.acquisition_cinematic_runtime.is_active(runtime)
		or runtime.pandora_legacy_selection_state.is_active()
		or runtime.horn_strawberry_mask_runtime.is_event_playing(runtime)
	)


func is_baal_boots_cinematic_active(runtime: Object) -> bool:
	return bool(runtime.baal_boots_weather_state.cinematic_active)
