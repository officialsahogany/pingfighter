extends RefCounted

const GameplayLoopAudioCleanup := preload("res://scripts/audio/gameplay_loop_audio_cleanup.gd")
const BossElectrocutionFieldHost := preload("res://scripts/effects/boss_electrocution_field_fx_host.gd")


func reset_game(deps: Dictionary, callbacks: Dictionary) -> Dictionary:
	_reset_match_state(deps)
	var orb_hud_state: Object = _reset_hud_state(deps)
	var active_item_slots: Array = _reset_item_runtimes(deps)
	_reset_player_skill_state(deps)
	_call_callback(callbacks, "reset_drive_input")
	_reset_dash_state(deps, orb_hud_state)
	_stop_reset_audio(deps)
	reset_stage_state(deps)
	_call_callback(callbacks, "reset_ball")
	return _build_reset_result(active_item_slots, deps)


func reset_for_stage_transition(deps: Dictionary, callbacks: Dictionary) -> Dictionary:
	_reset_match_state(deps)
	var orb_hud_state: Object = _reset_hud_state(deps)
	_reset_drive_input_cooldowns(deps)
	_call_callback(callbacks, "reset_drive_input")
	_reset_dash_state(deps, orb_hud_state)
	_stop_reset_audio(deps)
	reset_stage_state(deps)
	_call_callback(callbacks, "reset_ball")
	return _build_stage_transition_reset_result()


func _reset_drive_input_cooldowns(deps: Dictionary) -> void:
	var drive_input_state: Object = deps.get("drive_input_state", null)
	if drive_input_state != null and drive_input_state.has_method("reset_cooldowns"):
		drive_input_state.reset_cooldowns()


func _build_stage_transition_reset_result() -> Dictionary:
	# Stage transition only resets round-level / per-stage transient state.
	# Perks, items, equipment, mythic state, character skill state, paddle
	# scaling, and gear flags (sage_ring / megingjord / baal_boots / commando
	# bowling-trap-guard / suicide-drone) are intentionally NOT included so
	# the result applier reads from the owner and preserves currently
	# acquired progression across the stage boundary.
	return {
		"special_gauge": 0.0,
		"drive_text_timer_frames": 0.0,
		"optimus_energy_initialized": false,
	}


func _reset_match_state(deps: Dictionary) -> void:
	_call_reset(deps.get("scoreboard_state", null))
	_call_reset(deps.get("score_state", null))
	var round_state: Object = deps.get("round_state", null)
	if round_state != null and round_state.has_method("reset_game"):
		round_state.reset_game()


func _reset_hud_state(deps: Dictionary) -> Object:
	var orb_hud_state: Object = deps.get("orb_hud_state", null)
	if orb_hud_state != null and orb_hud_state.has_method("reset_gauge"):
		orb_hud_state.reset_gauge(0)
	_call_reset(deps.get("active_hud_state", null))
	return orb_hud_state


func _reset_item_runtimes(deps: Dictionary) -> Array:
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	var active_item_slots: Array = []
	if active_item_runtime != null:
		if active_item_runtime.has_method("reset"):
			active_item_runtime.reset()
		if active_item_runtime.has_method("build_starting_slots"):
			var slots: Variant = active_item_runtime.build_starting_slots()
			if slots is Array:
				active_item_slots = slots

	_call_reset(deps.get("mythic_item_runtime", null))
	_call_reset(deps.get("treasure_hunt_runtime", null))
	return active_item_slots


func _reset_player_skill_state(deps: Dictionary) -> void:
	var skill_states_value: Variant = deps.get("skill_states", [])
	if skill_states_value is Array:
		for skill_state in skill_states_value:
			_call_reset(skill_state)
	else:
		_call_reset(deps.get("skill_state", null))

	var drive_input_state: Object = deps.get("drive_input_state", null)
	if drive_input_state != null and drive_input_state.has_method("reset_cooldowns"):
		drive_input_state.reset_cooldowns()

	for key in [
		"smasher_plasma_state",
		"smasher_recovery_state",
		"smasher_cleanse_state",
		"status_effect_state",
		"smasher_warp_gate_state",
		"smasher_wheel_state",
		"smasher_magnum_grip_state",
		"smasher_dash_spirit_state",
		"smasher_shield_kiting_state",
		"laurel_leaf_shield_state",
		"monkey_blessing_delivery_state",
		"commando_reload_delivery_state",
		"runtime_perk_state",
		"optimus_energy_state",
	]:
		_call_reset(deps.get(key, null))

	var skill_configs_value: Variant = deps.get("skill_configs", [])
	if skill_configs_value is Array:
		for skill_config in skill_configs_value:
			if skill_config != null and skill_config.has_method("reset_runtime_skills"):
				skill_config.reset_runtime_skills()

	var skill_runtimes_value: Variant = deps.get("skill_runtimes", [])
	if skill_runtimes_value is Array:
		for skill_runtime in skill_runtimes_value:
			_call_reset(skill_runtime)


func _reset_dash_state(deps: Dictionary, orb_hud_state: Object) -> void:
	var dash_state: Object = deps.get("dash_state", null)
	if dash_state == null:
		return
	if dash_state.has_method("reset_full"):
		dash_state.reset_full(_get_dash_token_capacity(deps))
	if orb_hud_state != null and dash_state.has_method("get_snapshot") and orb_hud_state.has_method("reset_dash_tokens"):
		var dash_snapshot: Dictionary = dash_state.get_snapshot()
		orb_hud_state.reset_dash_tokens(int(dash_snapshot.get("tokens", 0)))


func _get_dash_token_capacity(deps: Dictionary) -> int:
	var base_tokens: int = max(1, int(deps.get("starting_dash_tokens", 1)))
	var runtime_perk_state: Object = deps.get("runtime_perk_state", null)
	var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
	if mythic_item_runtime != null and mythic_item_runtime.has_method("get_dash_token_capacity"):
		return max(1, int(mythic_item_runtime.get_dash_token_capacity(base_tokens, runtime_perk_state)))
	if runtime_perk_state != null and runtime_perk_state.has_method("get_runtime_skill_bonus"):
		base_tokens += int(runtime_perk_state.get_runtime_skill_bonus("dash_amplification"))
	return max(1, base_tokens)


func _stop_reset_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio == null:
		return
	GameplayLoopAudioCleanup.stop_all(audio)


func reset_stage_state(deps: Dictionary) -> void:
	for key in [
		"stage1_dalji_whip_skill_state",
		"stage1_dalji_spinning_top_skill_state",
		"stage1_dalji_boss_skill_cooldown_state",
		"weather_event_state",
		"stage2_boss_skill_state",
		"stage3_boss_skill_state",
		"stage2_monkey_banana_event",
		"stage4_map_state",
		"stage4_temple_destruction_event",
		"stage4_moon_event",
		"stage4_bird_event",
		"stage4_brazier_monk_event",
		"stage4_ponk_skill_state",
		"stage4_ponk_boss_skill_hud_renderer",
		"stage4_ponk_gauge_hud_renderer",
		"stage5_hongryun_state",
		"stage5_hongryun_fire_machine_event",
		"stage5_hongryun_actor_renderer",
		"stage5_hongryun_boss_skill_hud_renderer",
		"stage1_balloon_event",
		"stage_background",
	]:
		_call_reset(deps.get(key, null))
	# The shared boss electrocution field is a canvas-parented node host driven
	# per-frame by the boss renderer; force-hide any live host on round / stage
	# reset so a stun caught mid-transition cannot linger across the boundary.
	BossElectrocutionFieldHost.hide_all_existing_hosts()


func _build_reset_result(active_item_slots: Array, deps: Dictionary = {}) -> Dictionary:
	var league_player_paddle_scale: float = max(0.1, float(deps.get("league_player_paddle_scale", 1.0)))
	var player_paddle_width: float = 155.0 * league_player_paddle_scale
	var player_paddle_height: float = 50.0 * league_player_paddle_scale
	var player_paddle_visual_scale_override: float = 1.0 if not is_equal_approx(league_player_paddle_scale, 1.0) else -1.0
	return {
		"special_gauge": 0.0,
		"special_gauge_max": 500.0,
		"drive_text_timer_frames": 0.0,
		"player_paddle_width": player_paddle_width,
		"player_paddle_height": player_paddle_height,
		"player_paddle_scale": max(0.1, player_paddle_width / 155.0),
		"player_paddle_visual_scale_override": player_paddle_visual_scale_override,
		"runtime_paddle_base_width": player_paddle_width,
		"runtime_paddle_base_height": player_paddle_height,
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
		"runtime_perk_levels": {},
		"runtime_perk_pending_choices": 0,
		"runtime_perk_starpoints": 0,
		"runtime_perk_gold": 0,
		"runtime_perk_choice_active": false,
		"runtime_accessory_slot_bonus": 0,
		"runtime_laurel_leaf_count": 0,
		"item_perk_level_bonus": 0,
		"active_item_slots": active_item_slots,
		"equipment_slots": {},
		"passive_item_inventory": [],
		"passive_item_slots": {},
		"equipped_passive_items": {},
		"mythic_item_state": {},
		"weather_type": "",
		"weather_event_active": false,
		"weather_event_context": {},
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
		"commando_bowling_trap_guard_armed": false,
		"commando_bowling_trap_guard_source": "",
		"commando_bowling_trap_guard_knockback_power": 0.0,
		"commando_bowling_trap_guard_stun_frames": 0.0,
		"commando_bowling_trap_guard_restore_speed": 0.0,
		"commando_suicide_drone_ball_boost_active": false,
		"commando_suicide_drone_ball_restore_speed": 0.0,
		"commando_suicide_drone_ball_boosted_speed": 0.0,
	}


func _call_reset(target: Variant) -> void:
	if target != null and target.has_method("reset"):
		target.reset()


func _call_callback(callbacks: Dictionary, key: String) -> void:
	var callback: Callable = callbacks.get(key, Callable())
	if callback.is_valid():
		callback.call()
