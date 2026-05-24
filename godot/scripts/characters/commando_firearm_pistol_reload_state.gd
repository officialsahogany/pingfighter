extends RefCounted

const CommandoFirearmAudioDispatcher := preload("res://scripts/characters/commando_firearm_audio_dispatcher.gd")
const CommandoFirearmFireResultState := preload("res://scripts/characters/commando_firearm_fire_result_state.gd")


static func start_base_empty_reload(
	special_gauge: float,
	deps: Dictionary,
	base_weapon_id: String,
	cooldown_frames: float,
	control_lock_frames: float,
	fire_delay_frames: float,
	ammo_max_default: int,
	reload_timer_default: float,
	reload_gauge_cost: float
) -> Dictionary:
	if special_gauge < reload_gauge_cost:
		return CommandoFirearmFireResultState.build_pistol_fire_failed_result(
			base_weapon_id,
			special_gauge,
			"pistol_reload_gauge_insufficient",
			cooldown_frames,
			control_lock_frames,
			fire_delay_frames
		)
	var weapon_controller: Object = deps.get("commando_weapon_controller", null)
	if weapon_controller == null or not weapon_controller.has_method("start_weapon_reload"):
		return CommandoFirearmFireResultState.build_pistol_fire_failed_result(
			base_weapon_id,
			special_gauge,
			"pistol_reload_unavailable",
			cooldown_frames,
			control_lock_frames,
			fire_delay_frames
		)
	if not bool(weapon_controller.start_weapon_reload(base_weapon_id)):
		return CommandoFirearmFireResultState.build_pistol_fire_failed_result(
			base_weapon_id,
			special_gauge,
			"pistol_reload_unavailable",
			cooldown_frames,
			control_lock_frames,
			fire_delay_frames
		)
	var updated_weapon: Dictionary = {}
	if weapon_controller.has_method("get_current_weapon_data"):
		updated_weapon = weapon_controller.get_current_weapon_data()
	CommandoFirearmAudioDispatcher.play_first_audio_method(deps, ["play_commando_pistol_reload_start"])
	return CommandoFirearmFireResultState.build_base_pistol_reload_started_result(
		base_weapon_id,
		max(0.0, special_gauge - reload_gauge_cost),
		updated_weapon,
		ammo_max_default,
		reload_timer_default,
		reload_gauge_cost
	)
