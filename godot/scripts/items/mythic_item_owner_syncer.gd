extends RefCounted


func sync_owner(runtime: Object, owner: Object, registry: Object, constants: Dictionary) -> void:
	sync_runtime_perk_state_ref(runtime, registry)
	sync_item_perk_level_bonus_to_runtime_perk_state(runtime, owner, registry)
	sync_skill_cooldown_to_configs(runtime, registry)
	sync_dash_token_capacity(runtime, registry)
	sync_player_status_resistance_to_movement(runtime, registry)
	sync_gold_digger_to_runtime_perk_state(runtime, registry)
	if owner == null:
		return
	var slots: Dictionary = {}
	for item_value in runtime.inventory_items:
		var item_data: Dictionary = runtime._get_dict(item_value)
		if item_data.is_empty():
			continue
		var slot_key: String = str(item_data.get("_equipped_slot", ""))
		if slot_key == "":
			continue
		var canonical_slot_key: String = runtime._canonical_equipment_slot_key(slot_key)
		var synced_item: Dictionary = item_data.duplicate(true)
		synced_item["_equipped_slot"] = canonical_slot_key
		slots[canonical_slot_key] = synced_item
	owner.set("equipment_slots", slots)
	owner.set("passive_item_inventory", runtime.inventory_items.duplicate(true))
	owner.set("passive_item_slots", slots.duplicate(true))
	owner.set("equipped_passive_items", slots.duplicate(true))
	sync_boomerang_active_slot_visuals(runtime, owner, constants)
	owner.set("mythic_item_state", runtime.get_snapshot())
	owner.set("megingjord_equipped", runtime.is_equipped(str(constants.get("item_megingjord", "megingjord"))))
	owner.set("dowsing_pendulum_equipped", runtime.is_dowsing_pendulum_equipped())
	owner.set("dowsing_pendulum_range", runtime.get_dowsing_pendulum_range())
	owner.set("dowsing_pendulum_context", runtime.get_dowsing_pendulum_context())
	owner.set("dowsing_goggles_equipped", runtime.is_dowsing_goggles_equipped())
	owner.set("dowsing_goggles_active", runtime.is_dowsing_goggles_active())
	owner.set("dowsing_goggles_bonus_perk_chance", runtime.get_dowsing_goggles_bonus_perk_chance_pct())
	owner.set("dowsing_goggles_bonus_triggered", runtime.dowsing_goggles_bonus_triggered)
	owner.set("speedboots_equipped", runtime.is_speedboots_equipped())
	owner.set("speedboots_speed_bonus_pct", runtime.get_speedboots_speed_bonus_pct())
	owner.set("speedgear_equipped", runtime.is_speedgear_equipped())
	owner.set("speedgear_turn_decel_multiplier", runtime.get_speedgear_turn_decel_multiplier())
	owner.set("gravitybelt_equipped", runtime.is_gravitybelt_equipped())
	owner.set("gravitybelt_active", runtime.is_gravitybelt_active())
	owner.set("gravitybelt_instant_movement", runtime.is_gravitybelt_active())
	owner.set("revival_equipped", runtime.is_revival_equipped())
	owner.set("revival_available", runtime.is_revival_available())
	owner.set("revival_used", runtime.revival_state.used)
	owner.set("revival_effect_active", runtime.is_revival_effect_active())
	owner.set("revival_last_loss_type", runtime.revival_state.last_loss_type)
	owner.set("sensor_equipped", runtime.is_sensor_equipped())
	owner.set("sensor_enabled", runtime.sensor_enabled)
	owner.set("sensor_ready", runtime.is_sensor_auto_dash_ready())
	owner.set("sensor_cooldown_sec", runtime.get_sensor_cooldown_seconds())
	owner.set("sensor_cooldown_remaining_sec", runtime.get_sensor_cooldown_remaining_seconds())
	owner.set("sensor_cooldown_progress", runtime.get_sensor_cooldown_progress())
	owner.set("sensor_auto_dash_effect_active", runtime.sensor_auto_dash_effect_timer_frames > 0.0)
	owner.set("sensor_last_dash_direction", runtime.sensor_last_dash_direction)
	owner.set("sensor_context", runtime.get_sensor_context())
	owner.set("hermes_shoes_equipped", runtime.is_hermes_shoes_equipped())
	owner.set("hermes_shoes_active", runtime.is_hermes_shoes_active())
	owner.set("hermes_shoes_speed_bonus_pct", runtime.get_hermes_shoes_speed_bonus_pct())
	owner.set("hermes_shoes_speed_multiplier", runtime.get_hermes_shoes_speed_multiplier())
	owner.set("hermes_shoes_context", runtime.get_hermes_shoes_context())
	owner.set("player_speed_multiplier", runtime.get_player_speed_multiplier())
	owner.set("player_turn_decel_multiplier", runtime.get_player_turn_decel_multiplier())
	sync_bulkup_paddle_scale(runtime, owner, registry, constants)
	owner.set("bulkup_equipped", runtime.is_bulkup_equipped())
	owner.set("bulkup_body_size_pct", runtime.get_bulkup_body_size_pct())
	owner.set("bulkup_paddle_scale", runtime.get_player_paddle_scale())
	owner.set("spikeboots_equipped", runtime.is_spikeboots_equipped())
	owner.set("spikeboots_dash_afterdelay_reduction_pct", runtime.get_spikeboots_dash_afterdelay_reduction_pct())
	owner.set("spikeboots_dash_cooldown_reduction_pct", runtime.get_spikeboots_dash_cooldown_reduction_pct())
	owner.set("bulletproof_hat_equipped", runtime.is_bulletproof_hat_equipped())
	owner.set("bulletproof_hat_stun_resist_pct", runtime.get_bulletproof_hat_stun_resist_pct())
	owner.set("player_stun_resist_pct", runtime.get_player_stun_resist_pct())
	owner.set("spiked_helmet_equipped", runtime.is_spiked_helmet_equipped())
	owner.set("spiked_helmet_knockback_resist_pct", runtime.get_spiked_helmet_knockback_resist_pct())
	owner.set("player_knockback_resist_pct", runtime.get_player_knockback_resist_pct())
	owner.set("player_knockback_resist_scale", runtime.get_player_knockback_resist_scale())
	owner.set("celestial_armor_equipped", runtime.is_celestial_armor_equipped())
	owner.set("celestial_armor_active", runtime.is_celestial_armor_active())
	owner.set("celestial_armor_trigger_chance_pct", runtime.get_celestial_armor_trigger_chance_pct())
	owner.set("celestial_armor_gauge_cost", runtime.get_celestial_armor_gauge_cost())
	owner.set("celestial_armor_context", runtime.get_celestial_armor_context())
	owner.set("celestial_armor_wave_active", runtime.celestial_armor_state.is_wave_active())
	owner.set("baal_boots_equipped", runtime.is_baal_boots_equipped())
	owner.set("baal_boots_active", runtime.is_baal_boots_active())
	owner.set("baal_boots_context", runtime.get_baal_boots_context())
	owner.set("pandora_legacy_equipped", runtime.is_pandora_legacy_equipped())
	owner.set("pandora_legacy_active", runtime.is_pandora_legacy_active())
	owner.set("pandora_legacy_selection_quality", runtime.get_pandora_legacy_selection_quality())
	owner.set("pandora_legacy_trigger_chance", runtime.get_pandora_legacy_trigger_chance())
	owner.set("pandora_legacy_pending", runtime.has_pending_pandora_legacy_selection())
	owner.set("pandora_legacy_selection_active", runtime.is_pandora_legacy_selection_active())
	owner.set("pandora_legacy_selection_items", runtime.pandora_legacy_selection_state.get_items())
	owner.set("pandora_legacy_selected_index", int(runtime.pandora_legacy_selection_state.selected_index))
	owner.set("slot_add_equipped", runtime.is_slot_add_equipped())
	owner.set("slot_add_active_item_slot_bonus", runtime.get_slot_add_active_item_slot_bonus())
	owner.set("active_item_slot_capacity_bonus", runtime.get_slot_add_active_item_slot_bonus())
	owner.set("active_item_slot_capacity", runtime.get_active_item_slot_capacity(3))
	owner.set("chargebag_equipped", runtime.is_chargebag_equipped())
	owner.set("chargebag_wall_bounce_gauge_pct", runtime.get_chargebag_wall_bounce_gauge_pct())
	owner.set("battery_equipped", runtime.is_battery_equipped())
	owner.set("battery_gauge_preserve_pct", runtime.get_battery_gauge_preserve_pct())
	owner.set("knee_pads_equipped", runtime.is_knee_pads_equipped())
	owner.set("knee_pads_charge_pct", runtime.get_knee_pads_charge_pct())
	sync_fuel_pouch_gauge_max(runtime, owner, constants)
	owner.set("fuel_pouch_equipped", runtime.is_fuel_pouch_equipped())
	owner.set("fuel_pouch_gauge_bonus", runtime.get_fuel_pouch_gauge_bonus())
	owner.set("bluetooth_ring_equipped", runtime.is_bluetooth_ring_equipped())
	owner.set("bluetooth_ring_active", runtime.is_bluetooth_ring_active())
	owner.set("bluetooth_ring_gauge_gain_pct", runtime.get_bluetooth_ring_gauge_gain_pct())
	owner.set("bluetooth_ring_gauge_multiplier", runtime.get_bluetooth_ring_gauge_multiplier())
	owner.set("star_detector_equipped", runtime.is_star_detector_equipped())
	owner.set("star_detector_active", runtime.is_star_detector_active())
	owner.set("star_detector_star_bonus_pct", runtime.get_star_detector_star_bonus_pct())
	owner.set("star_detector_bonus_chance", runtime.get_star_detector_bonus_chance())
	owner.set("sage_ring_equipped", runtime.is_sage_ring_equipped())
	owner.set("sage_ring_active", runtime.is_sage_ring_active())
	owner.set("sage_ring_count", runtime.get_sage_ring_count())
	owner.set("sage_ring_perk_level_bonus", runtime.get_sage_ring_perk_level_bonus())
	owner.set("sage_ring_speed_penalty_pct", runtime.get_sage_ring_speed_penalty_pct())
	owner.set("sage_ring_body_penalty_pct", runtime.get_sage_ring_body_penalty_pct())
	owner.set("sage_ring_speed_multiplier", runtime.get_sage_ring_speed_multiplier())
	owner.set("smartphone_equipped", runtime.is_smartphone_equipped())
	owner.set("smartphone_active", runtime.is_smartphone_active())
	owner.set("smartphone_count", runtime.get_smartphone_count())
	owner.set("smartphone_auto_cooldown_frames", runtime.smartphone_cooldown_frames)
	owner.set("smartphone_last_auto_item", runtime.smartphone_last_auto_item)
	owner.set("neural_helmet_equipped", runtime.is_neural_helmet_equipped())
	owner.set("neural_helmet_active", runtime.is_neural_helmet_active())
	owner.set("neural_helmet_count", runtime.get_neural_helmet_count())
	owner.set("neural_helmet_aipill_gauge_reduction", runtime.get_neural_helmet_aipill_gauge_reduction())
	owner.set("neural_helmet_aipill_spawn_bonus_pct", runtime.get_neural_helmet_aipill_spawn_bonus_pct())
	owner.set("aipill_gauge_drain", runtime.get_aipill_gauge_drain())
	owner.set("aipill_item_spawn_multiplier", runtime.get_aipill_item_spawn_multiplier())
	owner.set("venom_mist_gauntlet_equipped", runtime.is_venom_mist_gauntlet_equipped())
	owner.set("venom_mist_gauntlet_active", runtime.is_venom_mist_gauntlet_active())
	owner.set("venom_mist_gauntlet_count", runtime.get_venom_mist_gauntlet_count())
	owner.set("venom_mist_trigger_chance_pct", runtime.get_venom_mist_trigger_chance_pct())
	owner.set("venom_mist_duration_sec", runtime.get_venom_mist_duration_sec())
	owner.set("venom_mist_ball_poisoned", runtime.venom_mist_ball_poisoned)
	owner.set("venom_mist_field_active", runtime.venom_mist_field_active)
	owner.set("venom_mist_field_center", runtime.venom_mist_center)
	owner.set("venom_mist_field_radius", float(constants.get("venom_mist_radius", 120.0)))
	owner.set("venom_mist_field_timer_frames", runtime.venom_mist_timer_frames)
	owner.set("venom_mist_boss_in_field", runtime.venom_mist_boss_in_field)
	owner.set("venom_mist_boss_slow_multiplier", runtime.get_venom_mist_boss_slow_multiplier())
	owner.set("reinforced_boomerang_gauntlet_equipped", runtime.is_reinforced_boomerang_gauntlet_equipped())
	owner.set("reinforced_boomerang_gauntlet_active", runtime.is_reinforced_boomerang_gauntlet_active())
	owner.set("reinforced_boomerang_gauntlet_count", runtime.get_reinforced_boomerang_gauntlet_count())
	owner.set("reinforced_boomerang_gauntlet_launch_speed_pct", runtime.get_boomerang_launch_speed_pct())
	owner.set("reinforced_boomerang_gauntlet_homing_pct", runtime.get_boomerang_homing_pct())
	owner.set("reinforced_boomerang_gauntlet_spawn_bonus_pct", runtime.get_boomerang_spawn_bonus_pct())
	owner.set("boomerang_launch_speed_multiplier", runtime.get_boomerang_launch_speed_multiplier())
	owner.set("boomerang_homing_multiplier", runtime.get_boomerang_homing_multiplier())
	owner.set("boomerang_item_spawn_multiplier", runtime.get_boomerang_item_spawn_multiplier())
	owner.set("boomerang_knockback_multiplier", runtime.get_boomerang_knockback_multiplier())
	owner.set("boomerang_stun_multiplier", runtime.get_boomerang_stun_multiplier())
	owner.set("commando_arm_equipped", runtime.is_commando_arm_equipped())
	owner.set("commando_arm_active", runtime.is_commando_arm_active())
	owner.set("commando_arm_count", runtime.get_commando_arm_count())
	owner.set("commando_arm_throw_speed_pct", runtime.get_commando_arm_throw_speed_pct())
	owner.set("commando_arm_explosion_range_pct", runtime.get_commando_arm_explosion_range_pct())
	owner.set("commando_arm_smoke_duration_pct", runtime.get_commando_arm_smoke_duration_pct())
	owner.set("commando_arm_prep_reduction_pct", runtime.get_commando_arm_prep_reduction_pct())
	owner.set("commando_arm_prep_multiplier", runtime.get_commando_arm_prep_multiplier())
	owner.set("commando_arm_generic_throw_speed_multiplier", runtime.get_commando_arm_throw_speed_multiplier(false))
	owner.set("commando_arm_boomerang_throw_speed_multiplier", runtime.get_commando_arm_throw_speed_multiplier(true))
	owner.set("commando_arm_range_multiplier", runtime.get_commando_arm_range_multiplier())
	owner.set("commando_arm_smoke_duration_multiplier", runtime.get_commando_arm_smoke_duration_multiplier())
	owner.set("commando_arm_context", runtime.get_commando_arm_context())
	owner.set("rainbow_fur_glove_equipped", runtime.is_rainbow_fur_glove_equipped())
	owner.set("rainbow_fur_glove_active", runtime.is_rainbow_fur_glove_active())
	owner.set("rainbow_fur_glove_trigger_chance_pct", runtime.get_rainbow_fur_glove_trigger_chance_pct())
	owner.set("rainbow_fur_glove_cooldown_reduction_pct", runtime.get_rainbow_fur_glove_cooldown_reduction_pct())
	owner.set("rainbow_fur_glove_context", runtime.get_rainbow_fur_glove_context())
	owner.set("adversity_armor_equipped", runtime.is_adversity_armor_equipped())
	owner.set("adversity_armor_active", runtime.is_adversity_armor_active())
	owner.set("adversity_armor_trigger_chance_pct", runtime.get_adversity_armor_trigger_chance_pct())
	owner.set("adversity_armor_invincible_duration_sec", runtime.get_adversity_armor_invincible_duration_sec())
	owner.set("adversity_armor_serve_speed_bonus_pct", runtime.get_adversity_armor_serve_speed_bonus_pct())
	owner.set("adversity_armor_pending_invincible", runtime.adversity_armor_pending_invincible)
	owner.set("adversity_armor_invincible", runtime.is_adversity_armor_invincible())
	owner.set("adversity_armor_context", runtime.get_adversity_armor_context())
	owner.set("shrapnel_armor_equipped", runtime.is_shrapnel_armor_equipped())
	owner.set("shrapnel_armor_active", runtime.is_shrapnel_armor_active())
	owner.set("shrapnel_armor_trigger_chance_pct", runtime.get_shrapnel_armor_trigger_chance_pct())
	owner.set("shrapnel_armor_shard_count", runtime.get_shrapnel_armor_shard_count())
	owner.set("shrapnel_armor_knockback_level", runtime.get_shrapnel_armor_knockback_level())
	owner.set("shrapnel_armor_gauge_cost", runtime.get_shrapnel_armor_gauge_cost())
	owner.set("shrapnel_armor_context", runtime.get_shrapnel_armor_context())
	owner.set("foul_whistle_equipped", runtime.is_foul_whistle_equipped())
	owner.set("foul_whistle_active", runtime.is_foul_whistle_active())
	owner.set("foul_whistle_negate_chance_pct", runtime.get_foul_whistle_negate_chance_pct())
	owner.set("foul_whistle_negate_chance", runtime.get_foul_whistle_negate_chance())
	owner.set("foul_whistle_effect_active", runtime.foul_whistle_state.animation_active)
	owner.set("foul_whistle_pending_round_reset", runtime.foul_whistle_state.pending_round_reset)
	owner.set("gold_digger_equipped", runtime.is_gold_digger_equipped())
	owner.set("gold_digger_count", runtime.get_gold_digger_count())
	owner.set("gold_digger_gold_bonus_pct", runtime.get_gold_digger_gold_bonus_pct())
	owner.set("gold_digger_multiplier", runtime.get_gold_digger_multiplier())
	owner.set("gold_bar_equipped", runtime.is_gold_bar_equipped())
	owner.set("gold_bar_owned", runtime.is_gold_bar_owned())
	owner.set("gold_bar_active", runtime.is_gold_bar_active())
	owner.set("gold_bar_count", runtime.get_gold_bar_count())
	owner.set("gold_bar_sell_price", runtime.get_gold_bar_sell_price())
	owner.set("gold_bar_total_sell_price", runtime.get_gold_bar_total_sell_price())
	owner.set("gold_bar_speed_penalty_pct", runtime.get_gold_bar_speed_penalty_pct())
	owner.set("gold_bar_speed_multiplier", runtime.get_gold_bar_speed_multiplier())
	owner.set("lucky_coin_equipped", runtime.is_lucky_coin_equipped())
	owner.set("lucky_coin_active", runtime.is_lucky_coin_active())
	owner.set("lucky_coin_double_spawn_pct", runtime.get_lucky_coin_double_spawn_pct())
	owner.set("lucky_coin_double_spawn_chance", runtime.get_lucky_coin_double_spawn_chance())
	owner.set("master_equipped", runtime.is_master_equipped())
	owner.set("master_wall_length_bonus_pct", runtime.get_master_wall_length_bonus_pct())
	owner.set("master_item_cooldown_reduction_pct", runtime.get_master_item_cooldown_reduction_pct())
	owner.set("master_wall_spawn_bonus_pct", runtime.get_master_wall_spawn_bonus_pct())
	owner.set("cooltime_equipped", runtime.is_cooltime_equipped())
	owner.set("cooltime_active_item_cooldown_reduction_pct", runtime.get_cooltime_active_item_cooldown_reduction_pct())
	owner.set("active_item_cooldown_reduction_pct", runtime.get_total_active_item_cooldown_reduction_pct())
	owner.set("timer_belt_equipped", runtime.is_timer_belt_equipped())
	owner.set("timer_belt_skill_cooldown_reduction_pct", runtime.get_timer_belt_skill_cooldown_reduction_pct())
	owner.set("sacred_laurel_equipped", runtime.is_sacred_laurel_equipped())
	owner.set("sacred_laurel_leaf_bonus", runtime.get_sacred_laurel_leaf_bonus())
	owner.set("sacred_laurel_context", runtime.get_sacred_laurel_context())
	owner.set("transcendent_crown_equipped", runtime.is_transcendent_crown_equipped())
	owner.set("transcendent_crown_skill_bonus", runtime.get_transcendent_crown_skill_bonus())
	owner.set("transcendent_crown_context", runtime.get_transcendent_crown_context())
	owner.set("item_perk_level_bonus", runtime.get_total_item_perk_level_bonus())
	owner.set("heavenly_cape_equipped", runtime.is_heavenly_cape_equipped())
	owner.set("heavenly_cape_skill_cooldown_reduction_pct", runtime.get_heavenly_cape_skill_cooldown_reduction_pct())
	owner.set("heavenly_cape_skill_slot_bonus", runtime.get_heavenly_cape_skill_slot_bonus())
	owner.set("player_skill_max_slots", runtime.get_player_skill_max_slots(5))
	owner.set("player_skill_cooldown_multiplier", runtime.get_player_skill_cooldown_multiplier())
	owner.set("dashgear_equipped", runtime.is_dashgear_equipped())
	owner.set("dashgear_dash_distance_bonus_pct", runtime.get_dashgear_dash_distance_bonus_pct())
	owner.set("dashgear_boost_charge_chance_pct", runtime.get_dashgear_boost_charge_chance_pct())
	owner.set("soul_burst_equipped", runtime.is_soul_burst_equipped())
	owner.set("soul_burst_active", runtime.is_soul_burst_active())
	owner.set("soul_burst_gauge_cost", runtime.get_soul_burst_gauge_cost())
	owner.set("soul_burst_dash_active", runtime.soul_burst_dash_active)
	owner.set("dashholder_equipped", runtime.is_dashholder_equipped())
	owner.set("dashholder_dash_token_bonus", runtime.get_dashholder_dash_token_bonus())
	owner.set("dash_token_capacity", runtime.get_dash_token_capacity(1))
	owner.set("poseidon_trident_equipped", runtime.is_equipped(str(constants.get("item_poseidon_trident", "poseidon_trident"))))
	owner.set("poseidon_trident_context", runtime.get_poseidon_context())


func sync_fuel_pouch_gauge_max(runtime: Object, owner: Object, constants: Dictionary) -> void:
	if owner == null:
		return
	var base_special_gauge_max: float = float(constants.get("base_special_gauge_max", 500.0))
	var next_max: float = runtime.get_effective_special_gauge_max(base_special_gauge_max)
	var previous_max: float = max(1.0, float(runtime._safe_owner_get(owner, "special_gauge_max", runtime.synced_special_gauge_max)))
	var current_gauge: float = max(0.0, float(runtime._safe_owner_get(owner, "special_gauge", 0.0)))
	if abs(previous_max - next_max) > 0.001:
		var ratio: float = clamp(current_gauge / previous_max, 0.0, 1.0)
		owner.set("special_gauge", clamp(round(next_max * ratio), 0.0, next_max))
	else:
		owner.set("special_gauge", min(current_gauge, next_max))
	owner.set("special_gauge_max", next_max)
	runtime.synced_special_gauge_max = next_max


func sync_boomerang_active_slot_visuals(runtime: Object, owner: Object, constants: Dictionary) -> void:
	if owner == null:
		return
	var slots_value: Variant = runtime._safe_owner_get(owner, "active_item_slots", [])
	if not (slots_value is Array):
		return
	var slots: Array = slots_value
	var use_metal: bool = runtime.is_reinforced_boomerang_gauntlet_equipped()
	var normal_icon_path: String = str(constants.get("boomerang_icon_path", "res://assets/sprites/items/boomerang.png"))
	var metal_icon_path: String = str(constants.get("boomerang_metal_icon_path", "res://assets/sprites/items/boomerang_metal.png"))
	var changed := false
	for i in range(slots.size()):
		if not (slots[i] is Dictionary):
			continue
		var item_data: Dictionary = slots[i]
		var item_name: String = str(item_data.get("name", item_data.get("effect", "")))
		var effect_name: String = str(item_data.get("effect", ""))
		if item_name != "boomerang" and effect_name != "boomerang":
			continue
		var next_item: Dictionary = item_data.duplicate(true)
		next_item["icon_path"] = metal_icon_path if use_metal else normal_icon_path
		if use_metal:
			next_item["color"] = Color(150.0 / 255.0, 220.0 / 255.0, 1.0)
			next_item["visual_variant"] = "metal"
		else:
			next_item.erase("visual_variant")
		slots[i] = next_item
		changed = true
	if changed:
		owner.set("active_item_slots", slots)


func sync_bulkup_paddle_scale(runtime: Object, owner: Object, registry: Object, constants: Dictionary) -> void:
	if owner == null:
		return
	var field_width: float = float(constants.get("field_width", 760.0))
	var field_height: float = float(constants.get("field_height", 750.0))
	var base_paddle_width: float = float(constants.get("player_base_paddle_width", 155.0))
	var base_paddle_height: float = float(constants.get("player_base_paddle_height", 50.0))
	var runtime_base_width: float = max(1.0, float(runtime._safe_owner_get(owner, "runtime_paddle_base_width", base_paddle_width)))
	var runtime_base_height: float = max(1.0, float(runtime._safe_owner_get(owner, "runtime_paddle_base_height", base_paddle_height)))
	var runtime_paddle_scale: float = max(0.1, float(runtime._safe_owner_get(owner, "runtime_paddle_scale", 1.0)))
	var active_item_scale: float = get_active_item_paddle_scale(runtime, registry)
	var bulkup_scale: float = runtime.get_player_paddle_scale()
	var final_scale: float = max(0.1, runtime_paddle_scale * active_item_scale * bulkup_scale)
	var current_width: float = max(1.0, float(runtime._safe_owner_get(owner, "player_paddle_width", base_paddle_width)))
	var current_height: float = max(1.0, float(runtime._safe_owner_get(owner, "player_paddle_height", base_paddle_height)))
	var next_width: float = runtime_base_width * final_scale
	var next_height: float = runtime_base_height * final_scale
	var player_pos_value: Variant = runtime._safe_owner_get(owner, "player_pos", Vector2.ZERO)
	if player_pos_value is Vector2 and (not is_equal_approx(current_width, next_width) or not is_equal_approx(current_height, next_height)):
		var player_pos: Vector2 = player_pos_value
		var center_x: float = player_pos.x + current_width * 0.5
		var warp_gate_state: Object = runtime._get_instance(registry, "smasher_warp_gate_state")
		player_pos.x = clamp_synced_player_x(center_x - next_width * 0.5, next_width, warp_gate_state, field_width)
		var current_bottom: float = player_pos.y + current_height
		if abs(current_bottom - field_height) <= max(2.0, current_height * 0.05) or current_bottom > field_height:
			player_pos.y = field_height - next_height
		owner.set("player_pos", player_pos)
	owner.set("player_paddle_width", next_width)
	owner.set("player_paddle_height", next_height)
	owner.set("player_paddle_scale", max(0.1, next_width / base_paddle_width))


func get_active_item_paddle_scale(runtime: Object, registry: Object) -> float:
	var active_item_runtime: Object = runtime._get_instance(registry, "active_item_runtime")
	if active_item_runtime != null and active_item_runtime.has_method("get_player_paddle_scale"):
		return max(0.1, float(active_item_runtime.get_player_paddle_scale()))
	return 1.0


func clamp_synced_player_x(x: float, paddle_width: float, warp_gate_state: Object, field_width: float) -> float:
	if warp_gate_state != null and warp_gate_state.has_method("is_active") and bool(warp_gate_state.is_active()):
		return clamp(x, -max(1.0, paddle_width), field_width)
	return clamp(x, 0.0, max(0.0, field_width - max(1.0, paddle_width)))


func sync_skill_cooldown_to_configs(runtime: Object, registry: Object) -> void:
	if registry == null:
		return
	var multiplier: float = runtime.get_player_skill_cooldown_multiplier()
	var skill_slot_bonus: int = runtime.get_heavenly_cape_skill_slot_bonus()
	for key in ["smasher_skill_config", "viper_skill_config", "commando_skill_config"]:
		var skill_config: Object = runtime._get_instance(registry, key)
		if skill_config != null and skill_config.has_method("set_item_cooldown_multiplier"):
			skill_config.set_item_cooldown_multiplier(multiplier)
		if skill_config != null and skill_config.has_method("set_item_skill_slot_bonus"):
			var removed_value: Variant = skill_config.set_item_skill_slot_bonus(skill_slot_bonus)
			if removed_value is Array:
				cleanup_removed_player_skills(runtime, registry, removed_value)


func cleanup_removed_player_skills(runtime: Object, registry: Object, removed_skills: Array) -> void:
	if registry == null or removed_skills.is_empty():
		return
	var runtime_perk_state: Object = runtime._get_instance(registry, "runtime_perk_state")
	if runtime_perk_state == null:
		return
	var levels_value: Variant = runtime_perk_state.get("runtime_skill_levels")
	if not (levels_value is Dictionary):
		return
	var levels: Dictionary = levels_value
	var changed := false
	for skill_value in removed_skills:
		var skill_name: String = str(skill_value)
		if skill_name != "" and levels.has(skill_name):
			levels.erase(skill_name)
			changed = true
	if changed:
		runtime_perk_state.set("runtime_skill_levels", levels)


func sync_dash_token_capacity(runtime: Object, registry: Object) -> void:
	if registry == null:
		return
	var dash_state: Object = runtime._get_instance(registry, "smasher_dash_state")
	if dash_state == null:
		return
	var runtime_perk_state: Object = runtime._get_instance(registry, "runtime_perk_state")
	var max_tokens: int = runtime.get_dash_token_capacity(1, runtime_perk_state)
	var changed := false
	if dash_state.has_method("set_max_tokens"):
		changed = bool(dash_state.set_max_tokens(max_tokens, true))
	elif dash_state.has_method("reset_full"):
		dash_state.reset_full(max_tokens)
		changed = true
	if not changed or not dash_state.has_method("get_snapshot"):
		return
	var orb_hud_state: Object = runtime._get_instance(registry, "orb_hud_state")
	if orb_hud_state != null and orb_hud_state.has_method("reset_dash_tokens"):
		var dash_snapshot: Dictionary = dash_state.get_snapshot()
		orb_hud_state.reset_dash_tokens(int(dash_snapshot.get("tokens", 0)))


func sync_player_status_resistance_to_movement(runtime: Object, registry: Object) -> void:
	if registry == null:
		return
	var movement_state: Object = runtime._get_instance(registry, "player_movement_state")
	if movement_state != null and movement_state.has_method("set_knockback_resist_pct"):
		movement_state.set_knockback_resist_pct(runtime.get_player_knockback_resist_pct())


func sync_gold_digger_to_runtime_perk_state(runtime: Object, registry: Object) -> void:
	if registry == null:
		return
	var runtime_perk_state: Object = runtime._get_instance(registry, "runtime_perk_state")
	if runtime_perk_state != null and runtime_perk_state.has_method("set_item_gold_gain_multiplier"):
		runtime_perk_state.set_item_gold_gain_multiplier(runtime.get_gold_digger_multiplier())


func sync_runtime_perk_state_ref(runtime: Object, registry: Object) -> void:
	var runtime_perk_state: Object = runtime._get_instance(registry, "runtime_perk_state")
	if runtime_perk_state != null:
		runtime.runtime_perk_state_ref = runtime_perk_state


func sync_item_perk_level_bonus_to_runtime_perk_state(runtime: Object, owner: Object, registry: Object) -> void:
	if registry == null:
		return
	var runtime_perk_state: Object = runtime._get_instance(registry, "runtime_perk_state")
	if runtime_perk_state == null or not runtime_perk_state.has_method("set_item_perk_level_bonus"):
		return
	var changed: bool = bool(runtime_perk_state.set_item_perk_level_bonus(runtime.get_total_item_perk_level_bonus()))
	if changed and runtime_perk_state.has_method("refresh_item_perk_level_bonus_dynamic_effects"):
		runtime_perk_state.refresh_item_perk_level_bonus_dynamic_effects(registry, owner)
