extends RefCounted

const CommandoFirearmAudioDispatcher := preload("res://scripts/characters/commando_firearm_audio_dispatcher.gd")
const CommandoFirearmFireResultState := preload("res://scripts/characters/commando_firearm_fire_result_state.gd")
const CommandoFirearmInputResolver := preload("res://scripts/characters/commando_firearm_input_resolver.gd")
const CommandoFirearmPistolReloadState := preload("res://scripts/characters/commando_firearm_pistol_reload_state.gd")
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
	var weapon_id: String = str(current_weapon.get("weapon_id", options.get("commando_pistol_weapon_id", "commando_pistol")))
	var commando_pistol_weapon_id: String = str(options.get("commando_pistol_weapon_id", "commando_pistol"))
	var is_commando_pistol: bool = weapon_id == commando_pistol_weapon_id
	if not bool(input_snapshot.get("action_pressed", false)):
		return {}
	if input_snapshot.has("action_just_pressed") and not bool(input_snapshot.get("action_just_pressed", false)):
		return {}
	if bool(input_snapshot.get("down_pressed", false)):
		return {}
	var weapon_controller: Object = deps.get("commando_weapon_controller", null)
	if CommandoFirearmInputResolver.is_fire_suppressed_after_switch(
		weapon_controller,
		now_msec,
		int(options.get("switch_fire_suppress_msec", 0))
	):
		return {}
	if float(runtime_owner.get("pistol_fire_delay_frames")) > 0.0:
		return _build_pistol_failed_result(runtime_owner, weapon_id, special_gauge, "pistol_animation_busy")
	if float(runtime_owner.get("pistol_cooldown_frames")) > 0.0:
		return _build_pistol_failed_result(runtime_owner, weapon_id, special_gauge, "pistol_cooldown")
	if bool(current_weapon.get("reloading", false)):
		return _build_pistol_failed_result(runtime_owner, weapon_id, special_gauge, "pistol_reloading")
	var ammo_current: int = int(current_weapon.get("ammo_current", 0))
	var magazines_current: int = int(current_weapon.get("magazines_current", 0))
	if ammo_current <= 0:
		if weapon_id == str(options.get("base_weapon_id", "pistol")):
			return CommandoFirearmPistolReloadState.start_base_empty_reload(
				special_gauge,
				deps,
				str(options.get("base_weapon_id", "pistol")),
				float(runtime_owner.get("pistol_cooldown_frames")),
				float(runtime_owner.get("pistol_control_lock_frames")),
				float(runtime_owner.get("pistol_fire_delay_frames")),
				int(options.get("pistol_ammo_max", 0)),
				float(options.get("pistol_fire_delay_frames", 0.0)),
				float(options.get("pistol_empty_reload_gauge_cost", 0.0))
			)
		return _build_pistol_failed_result(runtime_owner, weapon_id, special_gauge, "pistol_empty")
	if weapon_controller != null and weapon_controller.has_method("consume_current_weapon_ammo"):
		if not bool(weapon_controller.consume_current_weapon_ammo(1)):
			return _build_pistol_failed_result(runtime_owner, weapon_id, special_gauge, "pistol_ammo_unavailable")
	runtime_owner.set("last_fire_msec", now_msec)
	var doping_defaults: Dictionary = CommandoFirearmValueUtils.get_dict(options.get("doping_potion_defaults", {}))
	var doping_context: Dictionary = CommandoFirearmValueUtils.get_doping_potion_context_from_deps(
		deps,
		doping_defaults
	)
	var doping_active: bool = bool(doping_context.get("active", false))
	var cooldown_max_frames: float = CommandoFirearmValueUtils.get_pistol_cooldown_frames(
		weapon_id,
		doping_context,
		doping_active,
		float(options.get("pistol_cooldown_frames", 0.0)),
		float(options.get("beretta_cooldown_frames", 0.0)),
		float(options.get("doping_potion_pistol_cooldown_frames", 0.0))
	)
	var control_lock_max_frames: float = CommandoFirearmValueUtils.get_pistol_control_lock_frames(
		doping_context,
		doping_active,
		float(options.get("pistol_control_lock_frames", 0.0)),
		float(options.get("doping_potion_pistol_control_lock_frames", 0.0))
	)
	if is_commando_pistol and options.has("commando_pistol_control_lock_frames"):
		control_lock_max_frames = float(options.get("commando_pistol_control_lock_frames", control_lock_max_frames))
	var fire_delay_frames: float = float(options.get("pistol_fire_delay_frames", 0.0))
	if is_commando_pistol and options.has("commando_pistol_fire_delay_frames"):
		fire_delay_frames = float(options.get("commando_pistol_fire_delay_frames", fire_delay_frames))
	runtime_owner.set("pistol_cooldown_max_frames", cooldown_max_frames)
	runtime_owner.set("pistol_control_lock_max_frames", control_lock_max_frames)
	runtime_owner.set("pistol_cooldown_frames", cooldown_max_frames)
	runtime_owner.set("pistol_control_lock_frames", control_lock_max_frames)
	var pending_config: Dictionary = config.duplicate(true)
	CommandoFirearmValueUtils.apply_doping_potion_to_pistol_config(
		pending_config,
		doping_context,
		doping_defaults
	)
	if fire_delay_frames <= 0.0:
		runtime_owner.set("pistol_fire_delay_frames", 0.0)
		runtime_owner.set("pistol_pending_config", {})
		runtime_owner.set("pistol_pending_weapon_id", "")
		if runtime_owner.has_method("_spawn_firearm_effect"):
			runtime_owner.call("_spawn_firearm_effect", weapon_id, pending_config, deps)
		CommandoFirearmAudioDispatcher.play_fire_audio(weapon_id, deps)
		var post_fire_animation_frames: float = float(options.get("pistol_post_fire_animation_frames", 0.0))
		runtime_owner.set("pistol_post_fire_animation_frames", post_fire_animation_frames)
		var fired_weapon: Dictionary = current_weapon
		if weapon_controller != null and weapon_controller.has_method("get_current_weapon_data"):
			fired_weapon = weapon_controller.get_current_weapon_data()
		return CommandoFirearmFireResultState.build_pistol_shot_fired_result(
			weapon_id,
			fired_weapon,
			max(0, ammo_current - 1),
			int(current_weapon.get("ammo_max", options.get("pistol_ammo_max", 0))),
			magazines_current,
			float(runtime_owner.get("pistol_cooldown_frames")),
			float(runtime_owner.get("pistol_control_lock_frames")),
			0.0,
			post_fire_animation_frames,
			doping_context,
			doping_active,
			special_gauge
		)
	runtime_owner.set("pistol_fire_delay_frames", fire_delay_frames)
	runtime_owner.set("pistol_pending_config", pending_config)
	runtime_owner.set("pistol_pending_weapon_id", weapon_id)
	CommandoFirearmAudioDispatcher.play_first_audio_method(deps, ["play_commando_pistol_ready"])
	var updated_weapon: Dictionary = current_weapon
	if weapon_controller != null and weapon_controller.has_method("get_current_weapon_data"):
		updated_weapon = weapon_controller.get_current_weapon_data()
	return CommandoFirearmFireResultState.build_pistol_shot_queued_result(
		weapon_id,
		updated_weapon,
		max(0, ammo_current - 1),
		int(current_weapon.get("ammo_max", options.get("pistol_ammo_max", 0))),
		magazines_current,
		float(runtime_owner.get("pistol_cooldown_frames")),
		float(runtime_owner.get("pistol_control_lock_frames")),
		float(runtime_owner.get("pistol_fire_delay_frames")),
		doping_context,
		doping_active,
		special_gauge
	)


static func _build_pistol_failed_result(
	runtime_owner: Object,
	weapon_id: String,
	special_gauge: float,
	reason: String
) -> Dictionary:
	return CommandoFirearmFireResultState.build_pistol_fire_failed_result(
		weapon_id,
		special_gauge,
		reason,
		float(runtime_owner.get("pistol_cooldown_frames")),
		float(runtime_owner.get("pistol_control_lock_frames")),
		float(runtime_owner.get("pistol_fire_delay_frames"))
	)
