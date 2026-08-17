extends RefCounted

const CommandoFirearmAudioDispatcher := preload("res://scripts/characters/commando_firearm_audio_dispatcher.gd")
const CommandoFirearmBowlingTrapGeometry := preload("res://scripts/characters/commando_firearm_bowling_trap_geometry.gd")
const CommandoFirearmCooldownState := preload("res://scripts/characters/commando_firearm_cooldown_state.gd")
const CommandoFirearmFireResultState := preload("res://scripts/characters/commando_firearm_fire_result_state.gd")
const CommandoFirearmInputResolver := preload("res://scripts/characters/commando_firearm_input_resolver.gd")
const CommandoFirearmProfileResolver := preload("res://scripts/characters/commando_firearm_profile_resolver.gd")
const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")


static func update_runtime_generic_weapon_input(
	runtime_owner: Object,
	input_snapshot: Dictionary,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary,
	current_weapon: Dictionary,
	now_msec: int,
	switch_fire_suppress_msec: int,
	fire_debounce_msec: int,
	options: Dictionary
) -> Dictionary:
	var weapon_id := str(current_weapon.get("weapon_id", "pistol"))
	if not bool(input_snapshot.get("action_pressed", false)):
		return {}
	if not CommandoFirearmInputResolver.input_action_just_pressed(input_snapshot):
		return {}
	if bool(input_snapshot.get("down_pressed", false)):
		return {}
	var weapon_controller: Object = deps.get("commando_weapon_controller", null)
	if CommandoFirearmInputResolver.is_fire_suppressed_after_switch(
		weapon_controller,
		now_msec,
		switch_fire_suppress_msec
	):
		return {}
	if now_msec - int(runtime_owner.get("last_fire_msec")) < fire_debounce_msec:
		return {}
	if not CommandoFirearmCooldownState.is_ready(weapon_id, now_msec, deps):
		return _build_generic_fire_failed_result(weapon_id, special_gauge)
	if not bool(current_weapon.get("can_fire", true)):
		return _build_generic_fire_failed_result(weapon_id, special_gauge)
	if weapon_controller != null and weapon_controller.has_method("consume_current_weapon_ammo"):
		if not bool(weapon_controller.consume_current_weapon_ammo(1)):
			return _build_generic_fire_failed_result(weapon_id, special_gauge)
	runtime_owner.set("last_fire_msec", now_msec)
	if weapon_id != "pistol":
		CommandoFirearmCooldownState.trigger_configured_cooldown(weapon_id, now_msec, deps)
	_spawn_runtime_firearm_effect(runtime_owner, weapon_id, config, deps, options)
	CommandoFirearmAudioDispatcher.play_fire_audio(weapon_id, deps)
	return {
		"handled": true,
		"weapon_id": weapon_id,
		"fired": true,
		"special_gauge": special_gauge,
		"skill_gold_award": 0,
	}


static func update_runtime_bazooka_input(
	runtime_owner: Object,
	input_snapshot: Dictionary,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary,
	current_weapon: Dictionary,
	now_msec: int,
	options: Dictionary
) -> Dictionary:
	if not _has_single_press_fire_input(input_snapshot):
		return {}
	var weapon_controller: Object = deps.get("commando_weapon_controller", null)
	if CommandoFirearmInputResolver.is_fire_suppressed_after_switch(
		weapon_controller,
		now_msec,
		int(options.get("switch_fire_suppress_msec", 0))
	):
		return {}
	var failure_fields := CommandoFirearmFireResultState.build_runtime_bazooka_timing_fields(runtime_owner)
	if float(runtime_owner.get("bazooka_control_lock_frames")) > 0.0:
		return CommandoFirearmFireResultState.build_fire_failed_result("bazooka", special_gauge, "bazooka_control_lock", failure_fields)
	if float(runtime_owner.get("bazooka_cooldown_frames")) > 0.0:
		return CommandoFirearmFireResultState.build_fire_failed_result("bazooka", special_gauge, "bazooka_cooldown", failure_fields)
	if not CommandoFirearmCooldownState.is_ready("bazooka", now_msec, deps):
		return CommandoFirearmFireResultState.build_fire_failed_result("bazooka", special_gauge, "configured_cooldown", failure_fields)
	var ammo_current: int = int(current_weapon.get("ammo_current", 0))
	if ammo_current <= 0 or not bool(current_weapon.get("can_fire", true)):
		return CommandoFirearmFireResultState.build_fire_failed_result("bazooka", special_gauge, "bazooka_empty", failure_fields)
	if weapon_controller != null and weapon_controller.has_method("consume_current_weapon_ammo"):
		if not bool(weapon_controller.consume_current_weapon_ammo(1)):
			return CommandoFirearmFireResultState.build_fire_failed_result("bazooka", special_gauge, "bazooka_ammo_unavailable", failure_fields)

	runtime_owner.set("last_fire_msec", now_msec)
	var doping_defaults: Dictionary = CommandoFirearmValueUtils.get_dict(options.get("doping_potion_defaults", {}))
	var doping_context: Dictionary = CommandoFirearmValueUtils.get_doping_potion_context_from_deps(
		deps,
		doping_defaults
	)
	var doping_active: bool = bool(doping_context.get("active", false))
	var cooldown_max_frames: float = CommandoFirearmValueUtils.get_bazooka_cooldown_frames(
		doping_context,
		doping_active,
		float(options.get("bazooka_cooldown_frames", 0.0)),
		float(options.get("doping_bazooka_cooldown_frames", 0.0))
	)
	var control_lock_max_frames: float = CommandoFirearmValueUtils.get_bazooka_control_lock_frames(
		doping_context,
		doping_active,
		float(options.get("bazooka_control_lock_frames", 0.0)),
		float(options.get("doping_bazooka_control_lock_frames", 0.0))
	)
	runtime_owner.set("bazooka_cooldown_max_frames", cooldown_max_frames)
	runtime_owner.set("bazooka_control_lock_max_frames", control_lock_max_frames)
	runtime_owner.set("bazooka_cooldown_frames", cooldown_max_frames)
	runtime_owner.set("bazooka_control_lock_frames", control_lock_max_frames)
	runtime_owner.set("bazooka_fire_animation_frames", float(options.get("bazooka_fire_animation_frames", 0.0)))
	runtime_owner.set("bazooka_firing_pose_frames", float(options.get("bazooka_firing_pose_frames", 0.0)))
	runtime_owner.set("bazooka_muzzle_flash_frames", float(options.get("bazooka_muzzle_flash_frames", 0.0)))
	CommandoFirearmCooldownState.trigger_skill_cooldown(
		"bazooka",
		now_msec,
		deps,
		doping_context,
		doping_active,
		float(options.get("doping_fire_rate_multiplier", 1.0))
	)
	_spawn_runtime_firearm_effect(runtime_owner, "bazooka", config, deps, options)
	CommandoFirearmAudioDispatcher.play_fire_audio("bazooka", deps)
	var updated_weapon: Dictionary = current_weapon
	if weapon_controller != null and weapon_controller.has_method("get_current_weapon_data"):
		updated_weapon = weapon_controller.get_current_weapon_data()
	return CommandoFirearmFireResultState.build_ammo_weapon_fired_result(
		"bazooka",
		updated_weapon,
		max(0, ammo_current - 1),
		int(options.get("bazooka_ammo_max", 0)),
		special_gauge,
		CommandoFirearmFireResultState.build_runtime_bazooka_timing_fields(runtime_owner)
	)


static func update_runtime_net_gun_input(
	runtime_owner: Object,
	input_snapshot: Dictionary,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary,
	current_weapon: Dictionary,
	now_msec: int,
	options: Dictionary
) -> Dictionary:
	if not _has_single_press_fire_input(input_snapshot):
		return {}
	var weapon_controller: Object = deps.get("commando_weapon_controller", null)
	if CommandoFirearmInputResolver.is_fire_suppressed_after_switch(
		weapon_controller,
		now_msec,
		int(options.get("switch_fire_suppress_msec", 0))
	):
		return {}
	var failure_fields := CommandoFirearmFireResultState.build_runtime_net_gun_timing_fields(runtime_owner)
	if float(runtime_owner.get("net_gun_control_lock_frames")) > 0.0:
		return CommandoFirearmFireResultState.build_fire_failed_result("net_gun", special_gauge, "net_gun_control_lock", failure_fields)
	if float(runtime_owner.get("net_gun_cooldown_frames")) > 0.0:
		return CommandoFirearmFireResultState.build_fire_failed_result("net_gun", special_gauge, "net_gun_cooldown", failure_fields)
	if not CommandoFirearmCooldownState.is_ready("net_gun", now_msec, deps):
		return CommandoFirearmFireResultState.build_fire_failed_result("net_gun", special_gauge, "configured_cooldown", failure_fields)
	var ammo_current: int = int(current_weapon.get("ammo_current", 0))
	if ammo_current <= 0 or not bool(current_weapon.get("can_fire", true)):
		return CommandoFirearmFireResultState.build_fire_failed_result("net_gun", special_gauge, "net_gun_empty", failure_fields)
	if weapon_controller != null and weapon_controller.has_method("consume_current_weapon_ammo"):
		if not bool(weapon_controller.consume_current_weapon_ammo(1)):
			return CommandoFirearmFireResultState.build_fire_failed_result("net_gun", special_gauge, "net_gun_ammo_unavailable", failure_fields)

	runtime_owner.set("last_fire_msec", now_msec)
	runtime_owner.set("net_gun_cooldown_frames", float(options.get("net_gun_cooldown_frames", 0.0)))
	runtime_owner.set("net_gun_control_lock_frames", float(options.get("net_gun_control_lock_frames", 0.0)))
	runtime_owner.set("net_gun_throw_pose_frames", float(options.get("net_gun_throw_pose_frames", 0.0)))
	runtime_owner.set("net_gun_harpoon_flash_frames", float(options.get("net_gun_harpoon_flash_frames", 0.0)))
	CommandoFirearmCooldownState.trigger_configured_cooldown("net_gun", now_msec, deps)
	_spawn_runtime_firearm_effect(runtime_owner, "net_gun", config, deps, options)
	CommandoFirearmAudioDispatcher.play_fire_audio("net_gun", deps)
	var updated_weapon: Dictionary = current_weapon
	if weapon_controller != null and weapon_controller.has_method("get_current_weapon_data"):
		updated_weapon = weapon_controller.get_current_weapon_data()
	return CommandoFirearmFireResultState.build_ammo_weapon_fired_result(
		"net_gun",
		updated_weapon,
		max(0, ammo_current - 1),
		int(options.get("net_gun_ammo_max", 0)),
		special_gauge,
		CommandoFirearmFireResultState.build_runtime_net_gun_timing_fields(runtime_owner)
	)


static func update_runtime_bowling_trap_input(
	runtime_owner: Object,
	input_snapshot: Dictionary,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary,
	current_weapon: Dictionary,
	now_msec: int,
	options: Dictionary
) -> Dictionary:
	if not _consume_bowling_trap_single_press_input(runtime_owner, input_snapshot):
		return {}
	var weapon_controller: Object = deps.get("commando_weapon_controller", null)
	if CommandoFirearmInputResolver.is_fire_suppressed_after_switch(
		weapon_controller,
		now_msec,
		int(options.get("switch_fire_suppress_msec", 0))
	):
		return {}
	var failure_fields := CommandoFirearmFireResultState.build_runtime_bowling_trap_timing_fields(runtime_owner)
	if float(runtime_owner.get("bowling_trap_control_lock_frames")) > 0.0:
		return CommandoFirearmFireResultState.build_fire_failed_result("bowling_trap", special_gauge, "bowling_trap_control_lock", failure_fields)
	if float(runtime_owner.get("bowling_trap_cooldown_frames")) > 0.0:
		return CommandoFirearmFireResultState.build_fire_failed_result("bowling_trap", special_gauge, "bowling_trap_cooldown", failure_fields)
	var bowling_traps: Array = CommandoFirearmValueUtils.get_array(runtime_owner.get("bowling_traps"))
	if CommandoFirearmBowlingTrapGeometry.has_installing_trap(bowling_traps):
		return CommandoFirearmFireResultState.build_fire_failed_result("bowling_trap", special_gauge, "bowling_trap_installing", failure_fields)
	if not CommandoFirearmBowlingTrapGeometry.is_install_in_player_field(
		config,
		float(options.get("field_width", 760.0)),
		float(options.get("field_height", 750.0)),
		float(options.get("bowling_trap_min_field_y_ratio", 0.6))
	):
		return CommandoFirearmFireResultState.build_fire_failed_result("bowling_trap", special_gauge, "bowling_trap_install_field", failure_fields)
	if not CommandoFirearmCooldownState.is_ready("bowling_trap", now_msec, deps):
		return CommandoFirearmFireResultState.build_fire_failed_result("bowling_trap", special_gauge, "configured_cooldown", failure_fields)
	var ammo_current: int = int(current_weapon.get("ammo_current", 0))
	if ammo_current <= 0 or not bool(current_weapon.get("can_fire", true)):
		return CommandoFirearmFireResultState.build_fire_failed_result("bowling_trap", special_gauge, "bowling_trap_empty", failure_fields)
	if weapon_controller != null and weapon_controller.has_method("consume_current_weapon_ammo"):
		if not bool(weapon_controller.consume_current_weapon_ammo(1)):
			return CommandoFirearmFireResultState.build_fire_failed_result("bowling_trap", special_gauge, "bowling_trap_ammo_unavailable", failure_fields)

	runtime_owner.set("last_fire_msec", now_msec)
	runtime_owner.set("bowling_trap_cooldown_frames", float(options.get("bowling_trap_cooldown_frames", 0.0)))
	runtime_owner.set("bowling_trap_control_lock_frames", float(options.get("bowling_trap_control_lock_frames", 0.0)))
	runtime_owner.set("bowling_trap_install_pose_frames", float(options.get("bowling_trap_install_frames", 0.0)))
	CommandoFirearmCooldownState.trigger_configured_cooldown("bowling_trap", now_msec, deps)
	_spawn_runtime_firearm_effect(runtime_owner, "bowling_trap", config, deps, options)
	CommandoFirearmAudioDispatcher.play_fire_audio("bowling_trap", deps)
	var updated_weapon: Dictionary = current_weapon
	if weapon_controller != null and weapon_controller.has_method("get_current_weapon_data"):
		updated_weapon = weapon_controller.get_current_weapon_data()
	return CommandoFirearmFireResultState.build_ammo_weapon_fired_result(
		"bowling_trap",
		updated_weapon,
		max(0, ammo_current - 1),
		int(options.get("bowling_trap_ammo_max", 0)),
		special_gauge,
		CommandoFirearmFireResultState.build_runtime_bowling_trap_timing_fields(runtime_owner, true, 0.0)
	)


static func _has_single_press_fire_input(input_snapshot: Dictionary) -> bool:
	var action_pressed: bool = bool(input_snapshot.get("action_pressed", false))
	var action_just_pressed: bool = bool(input_snapshot.get("action_just_pressed", action_pressed))
	return action_pressed and action_just_pressed and not bool(input_snapshot.get("down_pressed", false))


static func _consume_bowling_trap_single_press_input(runtime_owner: Object, input_snapshot: Dictionary) -> bool:
	var action_pressed: bool = bool(input_snapshot.get("action_pressed", false))
	if not action_pressed:
		runtime_owner.set("bowling_trap_last_action_pressed", false)
		return false
	var action_just_pressed: bool = bool(input_snapshot.get(
		"action_just_pressed",
		action_pressed and not bool(runtime_owner.get("bowling_trap_last_action_pressed"))
	))
	runtime_owner.set("bowling_trap_last_action_pressed", action_pressed)
	return action_just_pressed and not bool(input_snapshot.get("down_pressed", false))


static func _build_generic_fire_failed_result(weapon_id: String, special_gauge: float) -> Dictionary:
	return {
		"handled": true,
		"weapon_id": weapon_id,
		"fire_failed": true,
		"special_gauge": special_gauge,
	}


static func _spawn_runtime_firearm_effect(
	runtime_owner: Object,
	weapon_id: String,
	config: Dictionary,
	deps: Dictionary,
	options: Dictionary
) -> void:
	if runtime_owner == null or not runtime_owner.has_method("_spawn_firearm_effect"):
		return
	var weapon_profiles: Dictionary = CommandoFirearmValueUtils.get_dict(options.get("weapon_profiles", {}))
	var weapon_profile_overrides: Dictionary = CommandoFirearmValueUtils.get_dict(options.get("weapon_profile_overrides", {}))
	runtime_owner.call(
		"_spawn_firearm_effect",
		weapon_id,
		config,
		deps,
		CommandoFirearmProfileResolver.get_weapon_profile(
			weapon_id,
			weapon_profiles,
			weapon_profile_overrides
		)
	)
