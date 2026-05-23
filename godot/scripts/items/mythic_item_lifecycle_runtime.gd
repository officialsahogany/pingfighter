extends RefCounted


func reset(runtime: Object, base_special_gauge_max: float) -> void:
	runtime.debug_management_menu.reset()
	runtime.acquisition_cinematic_runtime.reset(runtime)
	runtime.inventory_items.clear()
	runtime.equipped_items.clear()
	runtime.runtime_perk_state_ref = null
	runtime.next_inventory_id = 1
	runtime.megingjord_extra_pick_count = 0
	runtime.dowsing_runtime.reset_bonus_trigger(runtime)
	runtime.synced_special_gauge_max = base_special_gauge_max
	runtime.activation_effect_runtime.reset(runtime)
	runtime._clear_ragnarok_runtime(null)
	runtime._clear_poseidon_runtime(null)
	runtime._clear_knee_pads_runtime()
	runtime._clear_soul_burst_runtime()
	runtime._clear_foul_whistle_runtime()
	runtime._clear_revival_runtime(true)
	runtime._clear_sensor_runtime(true)
	runtime._clear_smartphone_runtime()
	runtime._clear_venom_mist_runtime()
	runtime._clear_rainbow_fur_glove_runtime()
	runtime._clear_adversity_armor_runtime()
	runtime._clear_shrapnel_armor_runtime()
	runtime._clear_celestial_armor_runtime()
	runtime._clear_hermes_shoes_runtime()
	runtime._clear_baal_boots_runtime()
	runtime._clear_horn_strawberry_mask_runtime(true)
	runtime.pandora_legacy_runtime.clear_runtime(runtime)


func reset_round(runtime: Object, registry: Object = null) -> void:
	runtime.acquisition_cinematic_runtime.reset(runtime, registry)
	runtime._clear_ragnarok_runtime(registry)
	runtime._clear_poseidon_runtime(registry)
	runtime._clear_knee_pads_runtime()
	runtime._clear_soul_burst_runtime()
	runtime._clear_foul_whistle_runtime()
	runtime._clear_sensor_round_state()
	runtime._clear_venom_mist_round_state()
	runtime._clear_rainbow_fur_glove_round_state()
	runtime._clear_adversity_armor_round_state()
	runtime._clear_shrapnel_armor_round_state()
	runtime._clear_celestial_armor_round_state()
	runtime._clear_hermes_shoes_round_state()
	runtime._clear_baal_boots_round_state(registry)
	runtime._clear_horn_strawberry_mask_runtime(false)
