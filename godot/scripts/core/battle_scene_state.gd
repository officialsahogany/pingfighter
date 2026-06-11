extends RefCounted

const DEFAULT_VALUES: Dictionary = {
	"ball_pos": Vector2.ZERO,
	"ball_pos_prev": Vector2.ZERO,
	"ball_interp_reset_requested": false,
	"ball_interp_last_physics_usec": 0,
	"ball_render_interpolation_enabled": true,
	"ball_vel": Vector2.ZERO,
	"ball_active": false,
	"skip_ball_motion_step": false,
	"ball_impact_boost": 1.0,
	"stage3_kuromi_ball_hidden": false,
	"ball_boost_decay_rate": 0.975,
	"ball_min_boost": 0.70,
	"rally_speed_cap_bonus": 0.0,
	"player_collision_cooldown": 0.0,
	"boss_collision_cooldown": 0.0,
	"vertical_bounce_count": 0,
	"ball_spin_strength": 0.0,
	"ball_spin_direction": 0,
	"drive_ball_active": false,
	"drive_hit_boss": false,
	"drive_speed_increase": 0.0,
	"drive_text_timer_frames": 0.0,
	"smasher_wheel_speed_cap": 0.0,
	"trampoline_launch_speed_cap": 0.0,
	"trampoline_launch_speed_cap_frames": 0.0,
	"gameplay_frame_counter": 0,
	"ball_visual_type": "energy",
	"boost_charging_active": false,
	"poisoned_ball_overlay_active": false,
	"viper_knockback_overlay_active": false,
	"bomb_ball_loaded": false,
	"player_pos": Vector2.ZERO,
	"player_speed": 0.0,
	"player_paddle_width": 155.0,
	"player_paddle_height": 50.0,
	"player_paddle_scale": 1.0,
	"player_paddle_visual_scale_override": -1.0,
	"runtime_paddle_base_width": 155.0,
	"runtime_paddle_base_height": 50.0,
	"runtime_paddle_scale": 1.0,
	"optimus_energy_initialized": false,
	"optimus_energy_ratio": 1.0,
	"optimus_paddle_scale": 1.0,
	"optimus_speed_multiplier": 1.0,
	"optimus_charge_active": false,
	"optimus_charge_hold_seconds": 0.0,
	"optimus_charge_hold_ratio": 0.0,
	"optimus_charge_lock_seconds": 0.0,
	"optimus_charge_movement_locked": false,
	"boss_pos": Vector2.ZERO,
	"boss_pos_prev": Vector2.ZERO,
	# Lingpet 꼭두각시 조종 (Koyora puppet grab): while true, the boss paddle is
	# scripted by the lingpet skill — the boss AI must not move it and the ball
	# must not bounce off it. See lingpet_puppet_grab_skill.gd.
	"lingpet_puppet_grab_active": false,
	"boss_paddle_width": 100.0,
	"boss_hitbox_height": 40.0,
	"boss_interp_last_physics_usec": 0,
	"boss_render_interpolation_enabled": true,
	"boss_vel": 0.0,
	"boss_max_health": 0,
	"boss_current_health": 0,
	"boss_health_damage_units": 0,
	"boss_last_damage_source": "",
	"boss_defeated_by_health": false,
	"current_stage": 1,
	"selected_character_type": "smasher",
	"ai_mode": "champion",
	"starting_dash_tokens": 1,
	"arena_mode_enabled": false,
	"weather_type": "",
	"weather_event_active": false,
	"weather_event_context": {},
	"selected_character_id": "ufo_player",
	"selected_runtime_character_id": "smasher",
	"selected_character_name": "스매셔",
	"active_item_slots": [],
	"equipment_slots": {},
	"passive_item_inventory": [],
	"passive_item_slots": {},
	"equipped_passive_items": {},
	"mythic_item_state": {},
	"odins_eye_equipped": false,
	"odins_eye_available": false,
	"odins_eye_revival_used": false,
	"odins_eye_penalty_active": false,
	"odins_eye_transformed": false,
	"odins_eye_skills_locked": false,
	"odins_eye_control_locked": false,
	"odins_eye_revival_animation_active": false,
	"odins_eye_death_animation_active": false,
	"odins_eye_effect_active": false,
	"odins_eye_revival_chance_pct": 35.0,
	"odins_eye_context": {},
	"odins_eye_move_speed_multiplier": 1.0,
	"odins_eye_dash_token_limit": null,
	"odins_eye_dash_cooldown_multiplier": 1.0,
	"odins_eye_death_phase": "",
	"odins_eye_death_overall_progress": 0.0,
	"odins_eye_death_phase_progress": 0.0,
	"odins_eye_death_energy_buildup": 0.0,
	"odins_eye_death_disintegrate_progress": 0.0,
	"odins_eye_death_shake_intensity": 0.0,
	"odins_eye_hide_player_paddle": false,
	"baal_boots_equipped": false,
	"baal_boots_active": false,
	"baal_boots_context": {},
	"megingjord_equipped": false,
	"sage_ring_equipped": false,
	"sage_ring_active": false,
	"sage_ring_count": 0,
	"sage_ring_perk_level_bonus": 0,
	"sage_ring_speed_penalty_pct": 0.0,
	"sage_ring_body_penalty_pct": 0.0,
	"sage_ring_speed_multiplier": 1.0,
	"transcendent_crown_equipped": false,
	"transcendent_crown_skill_bonus": 0,
	"transcendent_crown_context": {},
	"smasher_skill_icon_textures": {},
	"viper_skill_icon_textures": {},
	"commando_skill_icon_textures": {},
	"special_gauge": 0.0,
	"special_gauge_max": 500.0,
	"battle_textures": {},
	"player_customization_overlays_enabled": true,
	"player_customization_debug_overlay_enabled": false,
	"player_customization_overlay_slots": {},
	"player_customization_overlay_textures": {},
	"runtime_perk_levels": {},
	"runtime_perk_pending_choices": 0,
	"runtime_perk_starpoints": 0,
	"runtime_perk_gold": 0,
	"runtime_perk_choice_active": false,
	"lingpet_id": "",
	"active_lingpet_id": "",
	"current_lingpet_id": "",
	"lingpet_state": "none",
	"ringpet_state": "none",
	"lingpet_hatch_hits": 0,
	"ringpet_hatch_hits": 0,
	"lingpet_hatch_required_hits": 3,
	"ringpet_hatch_required_hits": 3,
	"lingpet_egg_pos": Vector2.ZERO,
	"lingpet_companion_pos": Vector2.ZERO,
	"ringpet_companion_pos": Vector2.ZERO,
	# Live companion defense rate (override-aware). MUST be declared here, or
	# set_value() silently no-ops the per-frame sync and the character-info panel
	# falls back to the catalog defense_rate (which equals the base, so the F7
	# defense-rate override never shows up in the panel).
	"lingpet_companion_defense_rate": 0.0,
	"ringpet_companion_defense_rate": 0.0,
	# Flight-style appearance rate (출현율). Same schema requirement as defense_rate:
	# missing here -> set_value() no-ops the sync and the panel can't show it.
	"lingpet_companion_appearance_rate": 0.0,
	"ringpet_companion_appearance_rate": 0.0,
	# Run-scoped affinity ("교감" in HUD strings). These are synced from the
	# lingpet runtime so the TAB panel never falls back to stale catalog data.
	"lingpet_affinity_level": 0,
	"ringpet_affinity_level": 0,
	"lingpet_affinity_points": 0.0,
	"ringpet_affinity_points": 0.0,
	"lingpet_affinity_next_requirement": 0.0,
	"ringpet_affinity_next_requirement": 0.0,
	"lingpet_affinity_next_label": "",
	"ringpet_affinity_next_label": "",
	# Permanent bond title ("친밀도" in collection/panel strings). Kept separate
	# from run-scoped affinity so the TAB panel can show the residue title without
	# adding another stat row.
	"lingpet_bond_points": 0,
	"ringpet_bond_points": 0,
	"lingpet_bond_title": "",
	"ringpet_bond_title": "",
	"lingpet_companion_contact_count": 0,
	"ringpet_companion_contact_count": 0,
	"lingpet_companion_last_contact_pos": Vector2.ZERO,
	"ringpet_companion_last_contact_pos": Vector2.ZERO,
	"lingpet_companion_hit_cooldown": 0.0,
	"ringpet_companion_hit_cooldown": 0.0,
	# Per-frame lingpet runtime -> TAB panel stat mirrors. Every key the
	# snapshot sync writes MUST be declared here (owner-field schema trap):
	# a missing key makes owner.set() silently no-op and the panel falls back
	# to the catalog BASE, hiding 교감 reward stacks and passive stat boosts.
	# Sealed by character_info_live_stats_smoke
	# _verify_snapshot_sync_keys_are_schema_declared.
	"lingpet_companion_hit_gauge_gain": 0.0,
	"ringpet_companion_hit_gauge_gain": 0.0,
	"lingpet_companion_hit_gauge_last_gain": 0.0,
	"ringpet_companion_hit_gauge_last_gain": 0.0,
	"lingpet_companion_hit_gauge_trigger_count": 0,
	"ringpet_companion_hit_gauge_trigger_count": 0,
	"lingpet_companion_patrol_speed_default": 0.0,
	"ringpet_companion_patrol_speed_default": 0.0,
	"lingpet_companion_patrol_speed_min": 0.0,
	"ringpet_companion_patrol_speed_min": 0.0,
	"lingpet_companion_patrol_speed_max": 0.0,
	"ringpet_companion_patrol_speed_max": 0.0,
	"lingpet_companion_catch_width": 0.0,
	"ringpet_companion_catch_width": 0.0,
	"lingpet_companion_catch_height": 0.0,
	"ringpet_companion_catch_height": 0.0,
	"lingpet_companion_defense_intercept_active": false,
	"ringpet_companion_defense_intercept_active": false,
	"lingpet_companion_defense_intercept_target_x": 0.0,
	"ringpet_companion_defense_intercept_target_x": 0.0,
	"lingpet_gauge_gain_bonus_pct": 0.0,
	"ringpet_gauge_gain_bonus_pct": 0.0,
	"lingpet_player_speed_bonus_pct": 0.0,
	"ringpet_player_speed_bonus_pct": 0.0,
	"lingpet_ring_dash_chance_pct": 0.0,
	"ringpet_ring_dash_chance_pct": 0.0,
	"lingpet_starpoint_tracking_chance_pct": 0.0,
	"ringpet_starpoint_tracking_chance_pct": 0.0,
	"lingpet_slots": [],
	"ringpet_slots": [],
	"lingpet_slot_pet_ids": [],
	"ringpet_slot_pet_ids": [],
	# -1 sentinel: slot readers treat negatives as "not synced yet" so a fresh
	# battle state cannot force slot 0 over the runtime's internal index.
	"lingpet_active_slot_index": -1,
	"ringpet_active_slot_index": -1,
	"lingpet_skill_id": "",
	"ringpet_skill_id": "",
	"lingpet_active_skill_id": "",
	"ringpet_active_skill_id": "",
	"lingpet_active_skill_level": 0,
	"ringpet_active_skill_level": 0,
	"lingpet_active_skill_max_level": 0,
	"ringpet_active_skill_max_level": 0,
	"lingpet_skill_name": "",
	"ringpet_skill_name": "",
	"lingpet_skill_cooldown": 0.0,
	"ringpet_skill_cooldown": 0.0,
	"lingpet_skill_cooldown_duration": 40.0,
	"ringpet_skill_cooldown_duration": 40.0,
	"lingpet_skill_ready": false,
	"ringpet_skill_ready": false,
	"lingpet_skill_last_gain": 0.0,
	"ringpet_skill_last_gain": 0.0,
	"lingpet_skill_trigger_count": 0,
	"ringpet_skill_trigger_count": 0,
	"lingpet_passive_skill_id": "",
	"ringpet_passive_skill_id": "",
	"lingpet_passive_skill_level": 0,
	"ringpet_passive_skill_level": 0,
	"lingpet_passive_skill_max_level": 0,
	"ringpet_passive_skill_max_level": 0,
	"lingpet_passive_skill_name": "",
	"ringpet_passive_skill_name": "",
	"lingpet_passive_skill_description": "",
	"ringpet_passive_skill_description": "",
	"lingpet_passive_skill_icon_path": "",
	"ringpet_passive_skill_icon_path": "",
	"lingpet_effect_text": "",
	"lingpet_owned_pet_ids": [],
	"owned_lingpet_ids": [],
	"owned_ringpet_ids": [],
	"lingpet_collection": {},
	"ringpet_collection": {},
	"owned_lingpets": {},
	"owned_ringpets": {},
	"lingpet_loadouts": {},
	"ringpet_loadouts": {},
	"owned_lingpet_loadouts": {},
	"owned_ringpet_loadouts": {},
	"runtime_accessory_slot_bonus": 0,
	"item_perk_level_bonus": 0,
	"commando_firearm_boss_damage_units_total": 0,
	"commando_firearm_last_damage_units": 0,
	"commando_firearm_last_damage_source": "",
	"commando_bowling_trap_guard_armed": false,
	"commando_bowling_trap_guard_source": "",
	"commando_bowling_trap_guard_knockback_power": 0.0,
	"commando_bowling_trap_guard_stun_frames": 0.0,
	"commando_bowling_trap_guard_restore_speed": 0.0,
	"commando_suicide_drone_ball_boost_active": false,
	"commando_suicide_drone_ball_restore_speed": 0.0,
	"commando_suicide_drone_ball_boosted_speed": 0.0,
}

var values: Dictionary = {}


func _init() -> void:
	reset()


func reset() -> void:
	values.clear()
	for key in DEFAULT_VALUES.keys():
		values[key] = _copy_default(DEFAULT_VALUES[key])


func has_key(key: String) -> bool:
	return DEFAULT_VALUES.has(key)


func get_value(key: String) -> Variant:
	if values.has(key):
		return values[key]
	if DEFAULT_VALUES.has(key):
		return _copy_default(DEFAULT_VALUES[key])
	return null


func set_value(key: String, value: Variant) -> void:
	if DEFAULT_VALUES.has(key):
		values[key] = value


func _copy_default(value: Variant) -> Variant:
	if value is Array:
		var array_value: Array = value
		return array_value.duplicate(true)
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value.duplicate(true)
	return value
