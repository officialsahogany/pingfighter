extends RefCounted

const CommandoFirearmAudioDispatcher := preload("res://scripts/characters/commando_firearm_audio_dispatcher.gd")
const CommandoFirearmControlState := preload("res://scripts/characters/commando_firearm_control_state.gd")
const CommandoFirearmCooldownState := preload("res://scripts/characters/commando_firearm_cooldown_state.gd")
const CommandoFirearmFireResultState := preload("res://scripts/characters/commando_firearm_fire_result_state.gd")
const CommandoFirearmInputResolver := preload("res://scripts/characters/commando_firearm_input_resolver.gd")
const CommandoFirearmProfileResolver := preload("res://scripts/characters/commando_firearm_profile_resolver.gd")
const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")


static func update_runtime_input(
	runtime_owner: Object,
	input_snapshot: Dictionary,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary,
	current_weapon: Dictionary,
	now_msec: int,
	options: Dictionary
) -> Dictionary:
	var weapon_controller: Object = deps.get("commando_weapon_controller", null)
	var action_pressed: bool = bool(input_snapshot.get("action_pressed", false))
	var previous_action_pressed: bool = bool(runtime_owner.get("ak47_last_action_pressed"))
	var action_just_pressed: bool = bool(input_snapshot.get("action_just_pressed", action_pressed and not previous_action_pressed))
	runtime_owner.set("ak47_last_action_pressed", action_pressed)
	if not action_pressed or bool(input_snapshot.get("down_pressed", false)):
		CommandoFirearmControlState.apply_ak47_trigger_cleared(runtime_owner)
		return {}
	if CommandoFirearmInputResolver.is_fire_suppressed_after_switch(
		weapon_controller,
		now_msec,
		int(options.get("switch_fire_suppress_msec", 0))
	):
		runtime_owner.set("ak47_trigger_held", true)
		return {}
	if action_just_pressed:
		runtime_owner.set("ak47_trigger_held", true)
		runtime_owner.set("ak47_burst_shots_remaining", int(options.get("ak47_initial_burst_shots", 0)))
		runtime_owner.set("ak47_fire_interval_frames", 0.0)
	else:
		runtime_owner.set("ak47_trigger_held", true)
	var doping_context: Dictionary = CommandoFirearmValueUtils.get_doping_potion_context_from_deps(
		deps,
		CommandoFirearmValueUtils.get_dict(options.get("doping_potion_defaults", {}))
	)
	var doping_active: bool = bool(doping_context.get("active", false))
	var ammo_current: int = int(current_weapon.get("ammo_current", 0))
	if ammo_current <= 0 or not bool(current_weapon.get("can_fire", true)):
		CommandoFirearmControlState.apply_ak47_trigger_cleared(runtime_owner)
		return _build_fire_failed_result(runtime_owner, special_gauge, "ak47_empty")
	if weapon_controller != null and weapon_controller.has_method("consume_current_weapon_duration"):
		weapon_controller.consume_current_weapon_duration(1.0)
	if weapon_controller != null and weapon_controller.has_method("get_current_weapon_data"):
		current_weapon = weapon_controller.get_current_weapon_data()
	if float(runtime_owner.get("ak47_fire_interval_frames")) > 0.0:
		return CommandoFirearmFireResultState.build_ak47_holding_result(
			special_gauge,
			float(runtime_owner.get("ak47_fire_interval_frames")),
			int(runtime_owner.get("ak47_burst_shots_remaining")),
			float(options.get("ak47_movement_speed_multiplier", 1.0))
		)
	if weapon_controller != null and weapon_controller.has_method("consume_current_weapon_ammo"):
		if not bool(weapon_controller.consume_current_weapon_ammo(1)):
			CommandoFirearmControlState.apply_ak47_trigger_cleared(runtime_owner)
			return _build_fire_failed_result(runtime_owner, special_gauge, "ak47_ammo_unavailable")
	runtime_owner.set("last_fire_msec", now_msec)
	_spawn_runtime_firearm_effect(runtime_owner, config, deps, options)
	CommandoFirearmAudioDispatcher.play_fire_audio("ak47", deps)
	CommandoFirearmCooldownState.trigger_skill_cooldown(
		"ak47",
		now_msec,
		deps,
		doping_context,
		doping_active,
		float(options.get("doping_fire_rate_multiplier", 1.0))
	)
	runtime_owner.set(
		"ak47_recoil_accumulation",
		min(
			float(options.get("ak47_max_recoil", 0.0)),
			float(runtime_owner.get("ak47_recoil_accumulation")) + float(options.get("ak47_recoil_per_shot", 0.0))
		)
	)
	if int(runtime_owner.get("ak47_burst_shots_remaining")) > 0:
		runtime_owner.set("ak47_burst_shots_remaining", int(runtime_owner.get("ak47_burst_shots_remaining")) - 1)
	var fire_interval_max_frames: float = CommandoFirearmValueUtils.get_ak47_fire_interval_frames(
		doping_context,
		doping_active,
		float(options.get("ak47_fire_interval_frames", 0.0)),
		float(options.get("doping_ak47_fire_interval_frames", 0.0))
	)
	runtime_owner.set("ak47_fire_interval_max_frames", fire_interval_max_frames)
	runtime_owner.set("ak47_fire_interval_frames", fire_interval_max_frames)
	var updated_weapon: Dictionary = current_weapon
	if weapon_controller != null and weapon_controller.has_method("get_current_weapon_data"):
		updated_weapon = weapon_controller.get_current_weapon_data()
	var remaining_ammo: int = int(updated_weapon.get("ammo_current", max(0, ammo_current - 1)))
	if str(updated_weapon.get("weapon_id", "ak47")) != "ak47":
		remaining_ammo = max(0, ammo_current - 1)
	if remaining_ammo <= 0:
		CommandoFirearmControlState.apply_ak47_trigger_cleared(runtime_owner)
	var movement_multiplier: float = float(options.get("ak47_movement_speed_multiplier", 1.0)) if remaining_ammo > 0 else 1.0
	var ammo_max_result: int = int(updated_weapon.get("ammo_max", current_weapon.get("ammo_max", options.get("ak47_ammo_max", 0))))
	if str(updated_weapon.get("weapon_id", "ak47")) != "ak47":
		ammo_max_result = int(current_weapon.get("ammo_max", options.get("ak47_ammo_max", 0)))
	return CommandoFirearmFireResultState.build_ak47_fired_result(
		remaining_ammo,
		ammo_max_result,
		updated_weapon,
		float(options.get("ak47_duration_frames", 0.0)),
		float(runtime_owner.get("ak47_fire_interval_frames")),
		int(runtime_owner.get("ak47_burst_shots_remaining")),
		float(runtime_owner.get("ak47_recoil_accumulation")),
		movement_multiplier,
		special_gauge
	)


static func _build_fire_failed_result(runtime_owner: Object, special_gauge: float, reason: String) -> Dictionary:
	return CommandoFirearmFireResultState.build_fire_failed_result("ak47", special_gauge, reason, {
		"fire_interval_frames": float(runtime_owner.get("ak47_fire_interval_frames")),
		"burst_shots_remaining": int(runtime_owner.get("ak47_burst_shots_remaining")),
		"movement_speed_multiplier": _get_runtime_movement_speed_multiplier(runtime_owner),
	})


static func _get_runtime_movement_speed_multiplier(runtime_owner: Object) -> float:
	if runtime_owner != null and runtime_owner.has_method("get_movement_speed_multiplier"):
		return float(runtime_owner.call("get_movement_speed_multiplier"))
	return 1.0


static func _spawn_runtime_firearm_effect(
	runtime_owner: Object,
	config: Dictionary,
	deps: Dictionary,
	options: Dictionary
) -> void:
	if runtime_owner == null or not runtime_owner.has_method("_spawn_firearm_effect"):
		return
	runtime_owner.call(
		"_spawn_firearm_effect",
		"ak47",
		config,
		deps,
		CommandoFirearmProfileResolver.build_ak47_fire_profile(
			CommandoFirearmValueUtils.get_dict(options.get("weapon_profiles", {})),
			CommandoFirearmValueUtils.get_dict(options.get("weapon_profile_overrides", {})),
			float(runtime_owner.get("ak47_recoil_accumulation")),
			float(options.get("ak47_base_spread_radians", 0.0))
		)
	)
