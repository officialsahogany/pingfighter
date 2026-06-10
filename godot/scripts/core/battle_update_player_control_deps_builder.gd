extends RefCounted

const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const PlayerSkillLockInputProxy := preload("res://scripts/characters/player_skill_lock_input_proxy.gd")
const Stage3CurseControlInputProxy := preload("res://scripts/stages/stage3/stage3_curse_control_input_proxy.gd")

const WIDTH: float = 760.0
const PLAY_LEFT: float = 0.0
const PLAY_RIGHT: float = WIDTH
const PADDLE_WIDTH: float = 155.0

var character_runtime: Object = PlayerCharacterRuntime.new()

var _cached_status_input_reader: Object = null
var _cached_status_stage3_boss_skill_state: Object = null
var _cached_status_effect_state: Object = null
var _cached_status_input_proxy: Object = null
var _cached_skill_lock_input_reader: Object = null
var _cached_skill_lock_mythic_item_runtime: Object = null
var _cached_skill_lock_input_proxy: Object = null


func build_config(character_type: String = "smasher") -> Dictionary:
	var config := {
		"play_left": PLAY_LEFT,
		"play_right": PLAY_RIGHT,
		"paddle_width": PADDLE_WIDTH,
		"selected_character_type": character_type,
	}
	config.merge(character_runtime.get_base_movement_config(character_type), true)
	return config


func build_deps(registry: Object, character_type: String = "smasher") -> Dictionary:
	var is_viper: bool = character_runtime.is_viper(character_type)
	var is_commando: bool = character_runtime.is_commando(character_type)
	var is_optimus: bool = character_runtime.is_optimus(character_type)
	var is_blacksmith: bool = character_runtime.is_blacksmith(character_type)
	var combo_key: String = character_runtime.get_combo_state_key(character_type)
	var skill_state_key: String = character_runtime.get_skill_state_key(character_type)
	var skill_config_key: String = character_runtime.get_skill_config_key(character_type)
	var stage3_boss_skill_state: Object = _get_instance(registry, "stage3_boss_skill_state")
	var status_effect_state: Object = _get_instance(registry, "status_effect_state")
	var input_reader: Object = _get_instance(registry, character_runtime.get_input_reader_key(character_type))
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	var routed_input_reader: Object = _build_skill_lock_input_reader(
		_build_status_input_reader(input_reader, stage3_boss_skill_state, status_effect_state),
		mythic_item_runtime
	)
	return {
		"registry": registry,
		"input_reader": routed_input_reader,
		"dash_state": _get_instance(registry, character_runtime.get_dash_state_key(character_type)),
		"drive_input_state": null if is_viper or is_commando or is_optimus or is_blacksmith else _get_instance(registry, "smasher_drive_input_state"),
		"skill_state": _get_instance(registry, skill_state_key) if skill_state_key != "" else null,
		"skill_config": _get_instance(registry, skill_config_key) if skill_config_key != "" else null,
		"viper_skill_runtime": _get_instance(registry, "viper_skill_runtime") if is_viper else null,
		"viper_jetpack_state": _get_instance(registry, "viper_jetpack_state") if is_viper else null,
		"optimus_energy_state": _get_instance(registry, "optimus_energy_state") if is_optimus else null,
		"commando_weapon_controller": _get_instance(registry, "commando_weapon_controller") if is_commando else null,
		"commando_emergency_supply_state": _get_instance(registry, "commando_emergency_supply_state") if is_commando else null,
		"commando_reload_delivery_state": _get_instance(registry, "commando_reload_delivery_state") if is_commando else null,
		"commando_firearm_runtime": _get_instance(registry, "commando_firearm_runtime") if is_commando else null,
		"commando_supply_drop_state": _get_instance(registry, "commando_supply_drop_state") if is_commando else null,
		"blacksmith_thor_shield_state": _get_instance(registry, "blacksmith_thor_shield_state") if is_blacksmith else null,
		"power_state": null if is_viper or is_commando or is_optimus or is_blacksmith else _get_instance(registry, "smasher_power_smash_state"),
		"smasher_plasma_state": null if is_viper or is_commando or is_optimus or is_blacksmith else _get_instance(registry, "smasher_plasma_state"),
		"smasher_recovery_state": null if is_viper or is_commando or is_optimus or is_blacksmith else _get_instance(registry, "smasher_recovery_state"),
		"smasher_cleanse_state": null if is_viper or is_commando or is_optimus or is_blacksmith else _get_instance(registry, "smasher_cleanse_state"),
		"smasher_warp_gate_state": null if is_viper or is_commando or is_optimus or is_blacksmith else _get_instance(registry, "smasher_warp_gate_state"),
		"smasher_wheel_state": null if is_viper or is_commando or is_optimus or is_blacksmith else _get_instance(registry, "smasher_wheel_state"),
		"smasher_magnum_grip_state": null if is_viper or is_commando or is_optimus or is_blacksmith else _get_instance(registry, "smasher_magnum_grip_state"),
		"smasher_dash_spirit_state": null if is_viper or is_commando or is_optimus or is_blacksmith else _get_instance(registry, "smasher_dash_spirit_state"),
		"smasher_shield_kiting_state": null if is_viper or is_commando or is_optimus or is_blacksmith else _get_instance(registry, "smasher_shield_kiting_state"),
		"movement_state": _get_instance(registry, "player_movement_state"),
		"combo_state": _get_instance(registry, combo_key) if combo_key != "" else null,
		"runtime_perk_state": _get_instance(registry, "runtime_perk_state"),
		"orb_hud_state": _get_instance(registry, "orb_hud_state"),
		"active_item_runtime": _get_instance(registry, "active_item_runtime"),
		"mythic_item_runtime": mythic_item_runtime,
		"player_skill_input_locked": _is_player_skill_locked(mythic_item_runtime),
		"status_effect_state": status_effect_state,
		"stage3_boss_skill_state": stage3_boss_skill_state,
		"round_state": _get_instance(registry, "round_flow_state"),
		"audio": _get_instance(registry, "game_audio"),
		"feedback": _get_instance(registry, "battle_feedback_state"),
		"current_stage": 1,
	}


func _build_status_input_reader(input_reader: Object, stage3_boss_skill_state: Object, status_effect_state: Object) -> Object:
	if input_reader == null or (stage3_boss_skill_state == null and status_effect_state == null):
		_cached_status_input_reader = null
		_cached_status_stage3_boss_skill_state = null
		_cached_status_effect_state = null
		_cached_status_input_proxy = null
		return input_reader
	if (
		_cached_status_input_proxy != null
		and input_reader == _cached_status_input_reader
		and stage3_boss_skill_state == _cached_status_stage3_boss_skill_state
		and status_effect_state == _cached_status_effect_state
	):
		return _cached_status_input_proxy
	_cached_status_input_reader = input_reader
	_cached_status_stage3_boss_skill_state = stage3_boss_skill_state
	_cached_status_effect_state = status_effect_state
	_cached_status_input_proxy = Stage3CurseControlInputProxy.new().configure(
		input_reader,
		stage3_boss_skill_state,
		status_effect_state
	)
	return _cached_status_input_proxy


func _build_skill_lock_input_reader(input_reader: Object, mythic_item_runtime: Object) -> Object:
	if input_reader == null or mythic_item_runtime == null or not _is_player_skill_locked(mythic_item_runtime):
		_cached_skill_lock_input_reader = null
		_cached_skill_lock_mythic_item_runtime = null
		_cached_skill_lock_input_proxy = null
		return input_reader
	if (
		_cached_skill_lock_input_proxy != null
		and input_reader == _cached_skill_lock_input_reader
		and mythic_item_runtime == _cached_skill_lock_mythic_item_runtime
	):
		return _cached_skill_lock_input_proxy
	_cached_skill_lock_input_reader = input_reader
	_cached_skill_lock_mythic_item_runtime = mythic_item_runtime
	_cached_skill_lock_input_proxy = PlayerSkillLockInputProxy.new().configure(input_reader, mythic_item_runtime)
	return _cached_skill_lock_input_proxy


func _is_player_skill_locked(mythic_item_runtime: Object) -> bool:
	if mythic_item_runtime == null:
		return false
	if (
		mythic_item_runtime.has_method("is_horn_strawberry_skills_locked")
		and bool(mythic_item_runtime.is_horn_strawberry_skills_locked())
	):
		return true
	if (
		mythic_item_runtime.has_method("is_horn_strawberry_control_locked")
		and bool(mythic_item_runtime.is_horn_strawberry_control_locked())
	):
		return true
	if (
		mythic_item_runtime.has_method("is_odins_eye_skills_locked")
		and bool(mythic_item_runtime.is_odins_eye_skills_locked())
	):
		return true
	if (
		mythic_item_runtime.has_method("is_odins_eye_control_locked")
		and bool(mythic_item_runtime.is_odins_eye_control_locked())
	):
		return true
	return false


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or key == "" or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
