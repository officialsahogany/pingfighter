extends RefCounted


func reset(runtime: Object, base_special_gauge_max: float, baal_boots_constants: Dictionary) -> void:
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
	runtime.ragnarok_runtime.clear_runtime(runtime, null)
	runtime.poseidon_runtime.clear_runtime(runtime)
	runtime.knee_pads_runtime.clear_runtime(runtime)
	runtime.soul_burst_runtime.clear_runtime(runtime)
	runtime.foul_whistle_runtime.clear_runtime(runtime)
	runtime.revival_runtime.clear_runtime(runtime, true)
	runtime.odins_eye_runtime.reset(runtime)
	runtime.auto_defense_runtime.clear_sensor_runtime(runtime, true)
	runtime.ai_assist_runtime.clear_smartphone_runtime(runtime)
	runtime.venom_mist_runtime.clear_runtime(runtime)
	runtime.rainbow_fur_glove_runtime.clear_runtime(runtime)
	runtime.adversity_armor_runtime.clear_runtime(runtime)
	runtime.shrapnel_armor_runtime.clear_runtime(runtime)
	runtime.celestial_armor_runtime.clear_runtime(runtime)
	runtime.hermes_shoes_runtime.clear_runtime(runtime)
	runtime.baal_boots_runtime.clear_runtime(runtime, null, baal_boots_constants)
	runtime.horn_strawberry_mask_runtime.reset(runtime)
	runtime.pandora_legacy_runtime.clear_runtime(runtime)


func reset_round(runtime: Object, registry: Object = null, baal_boots_constants: Dictionary = {}) -> void:
	runtime.acquisition_cinematic_runtime.reset(runtime, registry)
	runtime.ragnarok_runtime.clear_runtime(runtime, registry)
	runtime.poseidon_runtime.clear_runtime(runtime)
	runtime.knee_pads_runtime.clear_runtime(runtime)
	runtime.soul_burst_runtime.clear_runtime(runtime)
	runtime.foul_whistle_runtime.clear_runtime(runtime)
	runtime.odins_eye_runtime.reset_round(runtime)
	runtime.auto_defense_runtime.clear_sensor_round_state(runtime)
	runtime.venom_mist_runtime.clear_runtime(runtime)
	runtime.rainbow_fur_glove_runtime.clear_round_state(runtime)
	runtime.adversity_armor_runtime.clear_round_state(runtime)
	runtime.shrapnel_armor_runtime.clear_round_state(runtime)
	runtime.celestial_armor_runtime.clear_round_state(runtime)
	runtime.hermes_shoes_runtime.clear_round_state(runtime)
	runtime.baal_boots_runtime.clear_round_state(runtime, registry, baal_boots_constants)
	runtime.horn_strawberry_mask_runtime.reset_round(runtime)
