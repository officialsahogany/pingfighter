extends RefCounted

const ActiveItemPaddleSync := preload("res://scripts/items/active_item_paddle_sync.gd")

var _paddle_sync: Object = ActiveItemPaddleSync.new()


func configure_ball_physics_context(
	owner: Object,
	registry: Object,
	stage: int,
	league_mode: String = "champion",
	arena_enabled: bool = false,
	active_weather_type: String = ""
) -> void:
	var bridge: Object = _get_instance(registry, "ball_scene_bridge")
	if bridge != null:
		bridge.apply_physics_context(owner, registry, stage, league_mode, arena_enabled, active_weather_type)
	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_stage_bgm"):
		audio.play_stage_bgm(stage)


func configure_ball_visual_state(
	owner: Object,
	registry: Object,
	visual_type: String = "energy",
	boost_active: bool = false,
	poisoned: bool = false,
	viper_knockback: bool = false,
	bomb_loaded: bool = false
) -> void:
	var bridge: Object = _get_instance(registry, "ball_scene_bridge")
	if bridge != null:
		bridge.apply_visual_state(owner, visual_type, boost_active, poisoned, viper_knockback, bomb_loaded)


func activate_drive_ball(
	owner: Object,
	registry: Object,
	direction: int,
	spin_strength: float,
	speed_multiplier: float = 1.015,
	speed_bypass_bonus: float = 0.0
) -> void:
	var bridge: Object = _get_instance(registry, "ball_scene_bridge")
	if bridge != null:
		bridge.apply_drive_ball(owner, registry, direction, spin_strength, speed_multiplier, speed_bypass_bonus)


func collect_star_point(owner: Object, registry: Object, amount: int = 1) -> void:
	if owner == null:
		return
	var perk_state: Object = _get_instance(registry, "runtime_perk_state")
	var perk_catalog: Object = _get_instance(registry, "runtime_perk_catalog")
	if perk_state == null or perk_catalog == null:
		return
	if perk_state.has_method("collect_star_points"):
		perk_state.collect_star_points(
			max(1, amount),
			str(owner.get("selected_character_type") if owner.get("selected_character_type") != null else "smasher"),
			perk_catalog,
			owner,
			registry
		)
	if owner.has_method("queue_redraw"):
		owner.queue_redraw()


func equip_mythic_item(owner: Object, registry: Object, item_name: String = "megingjord") -> bool:
	if owner == null:
		return false
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("equip_item"):
		return false
	var equipped: bool = bool(mythic_item_runtime.equip_item(item_name, owner, registry, {}, true))
	if equipped and owner.has_method("queue_redraw"):
		owner.queue_redraw()
	return equipped


func debug_toggle_mythic_item(owner: Object, registry: Object, item_name: String = "megingjord") -> bool:
	if owner == null or item_name == "":
		return false
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime == null:
		return false
	var changed: bool = false
	if mythic_item_runtime.has_method("debug_toggle_item"):
		changed = bool(mythic_item_runtime.debug_toggle_item(item_name, owner, registry))
	elif item_name == "megingjord" and mythic_item_runtime.has_method("debug_toggle_megingjord"):
		changed = bool(mythic_item_runtime.debug_toggle_megingjord(owner, registry))
	if changed and owner.has_method("queue_redraw"):
		owner.queue_redraw()
	return changed


func debug_equip_megingjord(owner: Object, registry: Object) -> bool:
	return debug_toggle_mythic_item(owner, registry, "megingjord")


func _get_league_player_paddle_scale(owner: Object, registry: Object) -> float:
	var scene_config: Object = _get_instance(registry, "battle_scene_config")
	if scene_config != null and scene_config.has_method("get_league_player_paddle_scale"):
		return maxf(0.1, float(scene_config.get_league_player_paddle_scale(owner)))
	return 1.0


func _sync_final_player_paddle_size(owner: Object, registry: Object) -> void:
	if owner == null or _paddle_sync == null:
		return
	var active_item_scale := 1.0
	var active_item_runtime: Object = _get_instance(registry, "active_item_runtime")
	if active_item_runtime != null and active_item_runtime.has_method("get_player_paddle_scale"):
		active_item_scale = maxf(0.1, float(active_item_runtime.get_player_paddle_scale()))
	_paddle_sync.sync_owner_state(
		owner,
		active_item_scale,
		_get_instance(registry, "smasher_warp_gate_state"),
		_get_instance(registry, "mythic_item_runtime")
	)


func configure_player_character(owner: Object, registry: Object, character_type: String = "smasher") -> void:
	if owner == null:
		return
	var previous_paddle_size := Vector2(
		max(1.0, float(owner.get("player_paddle_width") if owner.get("player_paddle_width") != null else 155.0)),
		max(1.0, float(owner.get("player_paddle_height") if owner.get("player_paddle_height") != null else 50.0))
	)
	var character_runtime: Object = _get_instance(registry, "player_character_runtime")
	var normalized: String = character_type
	if character_runtime != null and character_runtime.has_method("normalize"):
		normalized = str(character_runtime.normalize(character_type))
	owner.set("selected_character_type", normalized)
	owner.set("selected_runtime_character_id", normalized)
	owner.set("player_speed", 0.0)
	var viper_jetpack_state: Object = _get_instance(registry, "viper_jetpack_state")
	if viper_jetpack_state != null:
		var jetpack_audio: Object = _get_instance(registry, "game_audio")
		if viper_jetpack_state.has_method("reset_round"):
			viper_jetpack_state.reset_round({"audio": jetpack_audio})
		elif viper_jetpack_state.has_method("reset"):
			viper_jetpack_state.reset()
	if normalized != "smasher":
		owner.set("drive_ball_active", false)
		owner.set("drive_hit_boss", false)
		owner.set("drive_speed_increase", 0.0)
		owner.set("drive_text_timer_frames", 0.0)
		var smasher_skill_state: Object = _get_instance(registry, "smasher_skill_state")
		if smasher_skill_state != null and smasher_skill_state.has_method("reset"):
			smasher_skill_state.reset()
		var power_state: Object = _get_instance(registry, "smasher_power_smash_state")
		if power_state != null and power_state.has_method("reset"):
			power_state.reset()
		var drive_input_state: Object = _get_instance(registry, "smasher_drive_input_state")
		if drive_input_state != null and drive_input_state.has_method("reset"):
			drive_input_state.reset()
		var plasma_state: Object = _get_instance(registry, "smasher_plasma_state")
		if plasma_state != null and plasma_state.has_method("reset"):
			plasma_state.reset()
		var recovery_state: Object = _get_instance(registry, "smasher_recovery_state")
		if recovery_state != null and recovery_state.has_method("reset"):
			recovery_state.reset()
		var cleanse_state: Object = _get_instance(registry, "smasher_cleanse_state")
		if cleanse_state != null and cleanse_state.has_method("reset"):
			cleanse_state.reset()
		var warp_gate_state: Object = _get_instance(registry, "smasher_warp_gate_state")
		if warp_gate_state != null and warp_gate_state.has_method("reset"):
			warp_gate_state.reset()
		var wheel_state: Object = _get_instance(registry, "smasher_wheel_state")
		if wheel_state != null and wheel_state.has_method("reset"):
			wheel_state.reset()
		var audio: Object = _get_instance(registry, "game_audio")
		if audio != null:
			if audio.has_method("stop_plasma_charge"):
				audio.stop_plasma_charge()
			if audio.has_method("stop_plasma_shock"):
				audio.stop_plasma_shock()
			if audio.has_method("stop_warp_gate_loop"):
				audio.stop_warp_gate_loop()
		var combo_state: Object = _get_instance(registry, "smasher_combo_state")
		if combo_state != null:
			if combo_state.has_method("reset_combo"):
				combo_state.reset_combo()
			if combo_state.has_method("clear_effects"):
				combo_state.clear_effects()
	if normalized != "soldier":
		var commando_audio: Object = _get_instance(registry, "game_audio")
		var commando_skill_state: Object = _get_instance(registry, "commando_skill_state")
		if commando_skill_state != null and commando_skill_state.has_method("reset"):
			commando_skill_state.reset()
		var commando_weapon_controller: Object = _get_instance(registry, "commando_weapon_controller")
		if commando_weapon_controller != null and commando_weapon_controller.has_method("reset"):
			commando_weapon_controller.reset()
		var commando_emergency_supply_state: Object = _get_instance(registry, "commando_emergency_supply_state")
		if commando_emergency_supply_state != null and commando_emergency_supply_state.has_method("reset"):
			commando_emergency_supply_state.reset()
		var commando_firearm_runtime: Object = _get_instance(registry, "commando_firearm_runtime")
		if commando_firearm_runtime != null and commando_firearm_runtime.has_method("reset_round"):
			commando_firearm_runtime.reset_round({"audio": commando_audio, "preserve_bowling_traps": false})
		elif commando_firearm_runtime != null and commando_firearm_runtime.has_method("reset"):
			commando_firearm_runtime.reset()
		var commando_supply_drop_state: Object = _get_instance(registry, "commando_supply_drop_state")
		if commando_supply_drop_state != null and commando_supply_drop_state.has_method("reset"):
			if commando_audio != null and commando_audio.has_method("stop_commando_supply_radio_loop"):
				commando_audio.stop_commando_supply_radio_loop()
			if commando_audio != null and commando_audio.has_method("stop_commando_supply_aircraft_loop"):
				commando_audio.stop_commando_supply_aircraft_loop()
			commando_supply_drop_state.reset()
	if normalized != "viper":
		var viper_audio: Object = _get_instance(registry, "game_audio")
		var viper_skill_state: Object = _get_instance(registry, "viper_skill_state")
		if viper_skill_state != null and viper_skill_state.has_method("reset"):
			viper_skill_state.reset()
		var viper_skill_runtime: Object = _get_instance(registry, "viper_skill_runtime")
		if viper_skill_runtime != null and viper_skill_runtime.has_method("reset_round"):
			viper_skill_runtime.reset_round({
				"audio": viper_audio,
				"owner": owner,
				"registry": registry,
				"runtime_perk_state": _get_instance(registry, "runtime_perk_state"),
				"preserve_ignition_aura": false,
				"preserve_dual_glitch": false,
			})
		elif viper_skill_runtime != null and viper_skill_runtime.has_method("reset"):
			viper_skill_runtime.reset()
	var blacksmith_shield_state: Object = _get_instance(registry, "blacksmith_thor_shield_state")
	if normalized == "blacksmith":
		if blacksmith_shield_state != null and blacksmith_shield_state.has_method("reset"):
			blacksmith_shield_state.reset()
		_clear_blacksmith_umbrella_owner_fields(owner)
	elif _has_blacksmith_umbrella_owner_fields(owner):
		if blacksmith_shield_state != null and blacksmith_shield_state.has_method("reset"):
			blacksmith_shield_state.reset()
		_clear_blacksmith_umbrella_owner_fields(owner)
	var optimus_energy_state: Object = _get_instance(registry, "optimus_energy_state")
	if normalized == "optimus":
		if optimus_energy_state != null and optimus_energy_state.has_method("reset"):
			optimus_energy_state.reset()
		var optimus_snapshot: Dictionary = {}
		var paddle_base_scale: float = _get_league_player_paddle_scale(owner, registry)
		if optimus_energy_state != null and optimus_energy_state.has_method("prepare_owner_runtime_base_for_optimus"):
			optimus_snapshot = optimus_energy_state.prepare_owner_runtime_base_for_optimus(
				owner,
				paddle_base_scale
			)
		elif optimus_energy_state != null and optimus_energy_state.has_method("prepare_owner_for_optimus"):
			optimus_snapshot = optimus_energy_state.prepare_owner_for_optimus(owner, paddle_base_scale)
		if not optimus_snapshot.is_empty():
			for key in optimus_snapshot.keys():
				owner.set(str(key), optimus_snapshot[key])
		_align_player_to_current_paddle(owner, previous_paddle_size)
		_sync_final_player_paddle_size(owner, registry)
	elif bool(owner.get("optimus_energy_initialized") if owner.get("optimus_energy_initialized") != null else false):
		if optimus_energy_state != null and optimus_energy_state.has_method("reset"):
			optimus_energy_state.reset()
		owner.set("optimus_energy_initialized", false)
		owner.set("optimus_energy_ratio", 1.0)
		owner.set("optimus_paddle_scale", 1.0)
		owner.set("optimus_speed_multiplier", 1.0)
		owner.set("optimus_charge_active", false)
		owner.set("optimus_charge_hold_seconds", 0.0)
		owner.set("optimus_charge_hold_ratio", 0.0)
		owner.set("optimus_charge_lock_seconds", 0.0)
		owner.set("optimus_charge_movement_locked", false)
		owner.set("runtime_paddle_base_width", 155.0)
		owner.set("runtime_paddle_base_height", 50.0)
		owner.set("runtime_paddle_scale", 1.0)
		owner.set("player_paddle_scale", 1.0)
		owner.set("player_paddle_visual_scale_override", -1.0)
		owner.set("player_paddle_width", 155.0)
		owner.set("player_paddle_height", 50.0)
		_align_player_to_current_paddle(owner, previous_paddle_size)
	if owner.has_method("queue_redraw"):
		owner.queue_redraw()


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _has_blacksmith_umbrella_owner_fields(owner: Object) -> bool:
	if owner == null:
		return false
	return (
		bool(owner.get("blacksmith_umbrella_open") if owner.get("blacksmith_umbrella_open") != null else false)
		or float(owner.get("blacksmith_umbrella_anim_timer") if owner.get("blacksmith_umbrella_anim_timer") != null else 0.0) > 0.0
		or bool(owner.get("blacksmith_umbrella_retracting") if owner.get("blacksmith_umbrella_retracting") != null else false)
		or float(owner.get("blacksmith_umbrella_open_ratio") if owner.get("blacksmith_umbrella_open_ratio") != null else 0.0) > 0.0
		or str(owner.get("blacksmith_umbrella_visual_state") if owner.get("blacksmith_umbrella_visual_state") != null else "closed") != "closed"
		or bool(owner.get("blacksmith_umbrella_swing_active") if owner.get("blacksmith_umbrella_swing_active") != null else false)
	)


func _clear_blacksmith_umbrella_owner_fields(owner: Object) -> void:
	if owner == null:
		return
	owner.set("blacksmith_umbrella_open", false)
	owner.set("blacksmith_umbrella_anim_timer", 0.0)
	owner.set("blacksmith_umbrella_retracting", false)
	owner.set("blacksmith_umbrella_anim_direction", 1)
	owner.set("blacksmith_umbrella_open_ratio", 0.0)
	owner.set("blacksmith_thor_shield_open_ratio", 0.0)
	owner.set("blacksmith_umbrella_raise_amount", 0.0)
	owner.set("blacksmith_umbrella_shield_open_amount", 0.0)
	owner.set("blacksmith_umbrella_visual_state", "closed")
	owner.set("blacksmith_umbrella_folded", true)
	owner.set("blacksmith_umbrella_deployed", false)
	owner.set("blacksmith_umbrella_swing_active", false)
	owner.set("blacksmith_umbrella_swing_direction", 0)
	owner.set("blacksmith_umbrella_swing_timer", 0.0)
	owner.set("blacksmith_umbrella_gauge", 5)
	owner.set("blacksmith_umbrella_gauge_max", 5)
	owner.set("blacksmith_umbrella_gauge_gain", 60.0)
	owner.set("blacksmith_umbrella_damage_flash_timer", 0.0)
	owner.set("blacksmith_umbrella_hit_pulse_timer", 0.0)


func _align_player_to_current_paddle(owner: Object, previous_paddle_size: Vector2) -> void:
	var next_width: float = max(1.0, float(owner.get("player_paddle_width") if owner.get("player_paddle_width") != null else previous_paddle_size.x))
	var next_height: float = max(1.0, float(owner.get("player_paddle_height") if owner.get("player_paddle_height") != null else previous_paddle_size.y))
	var player_pos_value: Variant = owner.get("player_pos")
	var player_pos := Vector2(760.0 * 0.5 - previous_paddle_size.x * 0.5, 750.0 - previous_paddle_size.y)
	if player_pos_value is Vector2:
		player_pos = player_pos_value
	var center_x: float = player_pos.x + max(1.0, previous_paddle_size.x) * 0.5
	player_pos.x = clamp(center_x - next_width * 0.5, 0.0, max(0.0, 760.0 - next_width))
	player_pos.y = 750.0 - next_height
	owner.set("player_pos", player_pos)
