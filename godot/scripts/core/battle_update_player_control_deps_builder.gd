extends RefCounted

const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const PlayerSkillLockInputProxy := preload("res://scripts/characters/player_skill_lock_input_proxy.gd")
const Stage3CurseControlInputProxy := preload("res://scripts/stages/stage3/stage3_curse_control_input_proxy.gd")
const Stage3DashBlockInputProxy := preload("res://scripts/stages/stage3/stage3_dash_block_input_proxy.gd")

const WIDTH: float = 760.0
const PLAY_LEFT: float = 0.0
const PLAY_RIGHT: float = WIDTH
const PADDLE_WIDTH: float = 155.0

var character_runtime: Object = PlayerCharacterRuntime.new()

var _cached_status_input_reader: Object = null
var _cached_status_stage3_boss_skill_state: Object = null
var _cached_status_effect_state: Object = null
var _cached_status_input_proxy: Object = null
var _cached_dash_lock_input_reader: Object = null
var _cached_dash_lock_stage3_boss_skill_state: Object = null
var _cached_dash_lock_input_proxy: Object = null
var _cached_skill_lock_input_reader: Object = null
var _cached_skill_lock_mythic_item_runtime: Object = null
var _cached_skill_lock_lingpet_runtime: Object = null
var _cached_skill_lock_input_proxy: Object = null


func build_config(character_type: String = PlayerCharacterRuntime.SMASHER) -> Dictionary:
	var config := {
		"play_left": PLAY_LEFT,
		"play_right": PLAY_RIGHT,
		"paddle_width": PADDLE_WIDTH,
		"selected_character_type": character_type,
	}
	config.merge(character_runtime.get_base_movement_config(character_type), true)
	return config


func build_deps(registry: Object, character_type: String = PlayerCharacterRuntime.SMASHER) -> Dictionary:
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
	var lingpet_runtime: Object = _get_cached_instance(registry, "lingpet_egg_runtime")
	# Status-proxied but NOT skill-lock-proxied reader. Dash is core movement, so the controllers
	# read its down trigger from here to survive a 뿔딸기 / 오딘의 눈 transform, whose skill-lock
	# proxy zeroes down_pressed to block down-based character skills (warp gate / EMP dive). When no
	# transform lock is active this bypasses only the player-skill lock; the boss-owned dash lock
	# remains authoritative. Status/curse gates still suppress dash.
	var status_input_reader: Object = _build_status_input_reader(input_reader, stage3_boss_skill_state, status_effect_state)
	var dash_input_reader: Object = _build_dash_lock_input_reader(status_input_reader, stage3_boss_skill_state)
	var routed_input_reader: Object = _build_skill_lock_input_reader(status_input_reader, mythic_item_runtime, lingpet_runtime)
	var lingpet_mount_active := _is_baekrin_mount_active(lingpet_runtime)
	return {
		"registry": registry,
		"ai_state": _get_instance(registry, "boss_ai_state"),
		"impact_effects": _get_instance(registry, "impact_effects"),
		"input_reader": routed_input_reader,
		"dash_input_reader": dash_input_reader,
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
		# 월담야습의 공통 ball_unavailable 게이트는 캐릭터별 공격 소유권과
		# 무관하게 라이브 공 프리즈를 관측해야 한다.
		"ball_power_freeze_state": _get_instance(registry, "smasher_power_smash_state"),
		"smasher_plasma_state": null if is_viper or is_commando or is_optimus or is_blacksmith else _get_instance(registry, "smasher_plasma_state"),
		"smasher_recovery_state": null if is_viper or is_commando or is_optimus or is_blacksmith else _get_instance(registry, "smasher_recovery_state"),
		"smasher_cleanse_state": null if is_viper or is_commando or is_optimus or is_blacksmith else _get_instance(registry, "smasher_cleanse_state"),
		"smasher_warp_gate_state": null if is_viper or is_commando or is_optimus or is_blacksmith else _get_instance(registry, "smasher_warp_gate_state"),
		"smasher_wheel_state": null if is_viper or is_commando or is_optimus or is_blacksmith else _get_instance(registry, "smasher_wheel_state"),
		"smasher_overdrive_state": null if is_viper or is_commando or is_optimus or is_blacksmith else _get_instance(registry, "smasher_overdrive_state"),
		"smasher_void_phantom_state": null if is_viper or is_commando or is_optimus or is_blacksmith else _get_instance(registry, "smasher_void_phantom_state"),
		"smasher_magnum_grip_state": null if is_viper or is_commando or is_optimus or is_blacksmith else _get_instance(registry, "smasher_magnum_grip_state"),
		"smasher_dash_spirit_state": null if is_viper or is_commando or is_optimus or is_blacksmith else _get_instance(registry, "smasher_dash_spirit_state"),
		"smasher_shield_kiting_state": null if is_viper or is_commando or is_optimus or is_blacksmith else _get_instance(registry, "smasher_shield_kiting_state"),
		"movement_state": _get_instance(registry, "player_movement_state"),
		"combo_state": _get_instance(registry, combo_key) if combo_key != "" else null,
		"runtime_perk_state": _get_instance(registry, "runtime_perk_state"),
		"dalji_vision_chosik_state": _get_instance(registry, "dalji_vision_chosik_state"),
		"gaksital_vision_chosik_state": _get_instance(registry, "gaksital_vision_chosik_state"),
		"cheongringwi_vision_chosik_state": _get_instance(registry, "cheongringwi_vision_chosik_state"),
		"yeonmyo_vision_chosik_state": _get_instance(registry, "yeonmyo_vision_chosik_state"),
		"boss_ai_state": _get_instance(registry, "boss_ai_state"),
		"orb_hud_state": _get_instance(registry, "orb_hud_state"),
		"active_item_runtime": _get_instance(registry, "active_item_runtime"),
		"mythic_item_runtime": mythic_item_runtime,
		"lingpet_mount_active": lingpet_mount_active,
		"player_skill_input_locked": _is_player_skill_locked(mythic_item_runtime) or lingpet_mount_active,
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


func _build_dash_lock_input_reader(input_reader: Object, stage3_boss_skill_state: Object) -> Object:
	if input_reader == null or stage3_boss_skill_state == null:
		_cached_dash_lock_input_reader = null
		_cached_dash_lock_stage3_boss_skill_state = null
		_cached_dash_lock_input_proxy = null
		return input_reader
	if (
		_cached_dash_lock_input_proxy != null
		and input_reader == _cached_dash_lock_input_reader
		and stage3_boss_skill_state == _cached_dash_lock_stage3_boss_skill_state
	):
		return _cached_dash_lock_input_proxy
	_cached_dash_lock_input_reader = input_reader
	_cached_dash_lock_stage3_boss_skill_state = stage3_boss_skill_state
	_cached_dash_lock_input_proxy = Stage3DashBlockInputProxy.new().configure(input_reader, stage3_boss_skill_state)
	return _cached_dash_lock_input_proxy


func _build_skill_lock_input_reader(input_reader: Object, mythic_item_runtime: Object, lingpet_runtime: Object = null) -> Object:
	if input_reader == null or (not _is_player_skill_locked(mythic_item_runtime) and not _is_baekrin_mount_active(lingpet_runtime)):
		_cached_skill_lock_input_reader = null
		_cached_skill_lock_mythic_item_runtime = null
		_cached_skill_lock_lingpet_runtime = null
		_cached_skill_lock_input_proxy = null
		return input_reader
	if (
		_cached_skill_lock_input_proxy != null
		and input_reader == _cached_skill_lock_input_reader
		and mythic_item_runtime == _cached_skill_lock_mythic_item_runtime
		and lingpet_runtime == _cached_skill_lock_lingpet_runtime
	):
		return _cached_skill_lock_input_proxy
	_cached_skill_lock_input_reader = input_reader
	_cached_skill_lock_mythic_item_runtime = mythic_item_runtime
	_cached_skill_lock_lingpet_runtime = lingpet_runtime
	_cached_skill_lock_input_proxy = PlayerSkillLockInputProxy.new().configure(input_reader, mythic_item_runtime, lingpet_runtime)
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


func _is_baekrin_mount_active(lingpet_runtime: Object) -> bool:
	return (
		lingpet_runtime != null
		and lingpet_runtime.has_method("is_baekrin_mount_active")
		and bool(lingpet_runtime.is_baekrin_mount_active())
	)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or key == "" or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_cached_instance(registry: Object, key: String) -> Object:
	if registry == null or key == "" or not registry.has_method("get_cached_instance"):
		return null
	var value: Variant = registry.get_cached_instance(key)
	return value as Object if typeof(value) == TYPE_OBJECT and is_instance_valid(value) else null
