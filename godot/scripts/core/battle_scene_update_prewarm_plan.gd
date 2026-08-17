extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const BattleSceneUpdatePrewarmKeySets := preload(
	"res://scripts/core/battle_scene_update_prewarm_key_sets.gd"
)
const PlayerCharacterRuntime := preload(
	"res://scripts/characters/player_character_runtime.gd"
)

var character_runtime: Object = PlayerCharacterRuntime.new()


func build_prewarm_key(owner: Object) -> String:
	return "%s:%d" % [
		character_runtime.normalize(_get_owner_value(
			owner,
			"selected_character_type",
			"smasher"
		)),
		int(_get_owner_value(owner, "current_stage", 1)),
	]


func get_player_control_context_keys(character_type: String) -> Array:
	var normalized_character: String = character_runtime.normalize(character_type)
	var keys: Array = [
		"stage3_boss_skill_state",
		"status_effect_state",
		character_runtime.get_input_reader_key(normalized_character),
		"mythic_item_runtime",
		character_runtime.get_dash_state_key(normalized_character),
		character_runtime.get_skill_state_key(normalized_character),
		character_runtime.get_skill_config_key(normalized_character),
	]
	if character_runtime.is_viper(normalized_character):
		keys.append_array([
			"viper_skill_runtime",
			"viper_jetpack_state",
		])
	elif character_runtime.is_optimus(normalized_character):
		keys.append("optimus_energy_state")
	elif character_runtime.is_commando(normalized_character):
		keys.append_array([
			"commando_weapon_controller",
			"commando_emergency_supply_state",
			"commando_reload_delivery_state",
			"commando_firearm_runtime",
			"commando_supply_drop_state",
		])
	elif character_runtime.is_blacksmith(normalized_character):
		keys.append_array([
			"blacksmith_player_controller",
			"blacksmith_thor_shield_state",
			"blacksmith_skill_state",
			"blacksmith_skill_config",
		])
	else:
		keys.append_array([
			"smasher_drive_input_state",
			"smasher_power_smash_state",
			"smasher_plasma_state",
			"smasher_recovery_state",
			"smasher_cleanse_state",
			"smasher_warp_gate_state",
			"smasher_wheel_state",
			"smasher_overdrive_state",
			"smasher_void_phantom_state",
			"smasher_magnum_grip_state",
			"smasher_dash_spirit_state",
			"smasher_shield_kiting_state",
			"smasher_combo_state",
			"smasher_drive_bounce_state",
			"smasher_drive_counter_state",
			"smasher_drive_activation_controller",
			"smasher_power_smash_activation_controller",
			"smasher_power_smash_motion_controller",
		])
	keys.append_array([
		"player_movement_state",
		"runtime_perk_state",
		"orb_hud_state",
		"active_item_runtime",
		"round_flow_state",
		"game_audio",
		"battle_feedback_state",
	])
	return _unique_non_empty_keys(keys)


func get_effects_context_keys(owner: Object) -> Array:
	var character_type: String = character_runtime.normalize(_get_owner_value(
		owner,
		"selected_character_type",
		"smasher"
	))
	var current_stage: int = int(_get_owner_value(owner, "current_stage", 1))
	var keys: Array = []
	keys.append_array(BattleSceneUpdatePrewarmKeySets.EFFECTS_CORE_PREWARM_KEYS)
	keys.append_array(
		BattleSceneUpdatePrewarmKeySets.EFFECTS_COMMON_CHARACTER_PREWARM_KEYS
	)
	if character_runtime.is_viper(character_type):
		keys.append_array(BattleSceneUpdatePrewarmKeySets.EFFECTS_VIPER_PREWARM_KEYS)
	elif character_runtime.is_commando(character_type):
		keys.append_array(BattleSceneUpdatePrewarmKeySets.EFFECTS_COMMANDO_PREWARM_KEYS)
	elif character_runtime.is_blacksmith(character_type):
		keys.append_array(["blacksmith_thor_shield_state"])
	elif not character_runtime.is_optimus(character_type):
		keys.append_array(BattleSceneUpdatePrewarmKeySets.EFFECTS_SMASHER_PREWARM_KEYS)
	keys.append_array(get_stage_runtime_keys(current_stage, false))
	return _unique_non_empty_keys(keys)


func get_match_flow_context_keys(owner: Object) -> Array:
	var character_type: String = character_runtime.normalize(_get_owner_value(
		owner,
		"selected_character_type",
		"smasher"
	))
	var current_stage: int = int(_get_owner_value(owner, "current_stage", 1))
	var keys: Array = []
	keys.append_array(BattleSceneUpdatePrewarmKeySets.MATCH_STATE_PREWARM_KEYS)
	keys.append_array(BattleSceneUpdatePrewarmKeySets.MATCH_ITEM_RUNTIME_PREWARM_KEYS)
	keys.append_array(_get_match_player_skill_keys(character_type))
	keys.append_array(get_stage_runtime_keys(current_stage, false))
	return _unique_non_empty_keys(keys)


func get_stage_runtime_keys(current_stage: int, include_all_stages: bool) -> Array:
	var keys: Array = []
	keys.append_array(BattleSceneUpdatePrewarmKeySets.STAGE_RUNTIME_COMMON_PREWARM_KEYS)
	if include_all_stages:
		keys.append_array(BattleSceneUpdatePrewarmKeySets.STAGE1_RUNTIME_PREWARM_KEYS)
		keys.append_array(BattleSceneUpdatePrewarmKeySets.STAGE2_RUNTIME_PREWARM_KEYS)
		keys.append_array(BattleSceneUpdatePrewarmKeySets.STAGE3_RUNTIME_PREWARM_KEYS)
		keys.append_array(BattleSceneUpdatePrewarmKeySets.STAGE4_RUNTIME_PREWARM_KEYS)
		keys.append_array(BattleSceneUpdatePrewarmKeySets.STAGE5_RUNTIME_PREWARM_KEYS)
		keys.append_array(BattleSceneUpdatePrewarmKeySets.STAGE6_RUNTIME_PREWARM_KEYS)
		return _unique_non_empty_keys(keys)
	match current_stage:
		1:
			keys.append_array(BattleSceneUpdatePrewarmKeySets.STAGE1_RUNTIME_PREWARM_KEYS)
		2:
			keys.append_array(BattleSceneUpdatePrewarmKeySets.STAGE2_RUNTIME_PREWARM_KEYS)
		3:
			keys.append_array(BattleSceneUpdatePrewarmKeySets.STAGE3_RUNTIME_PREWARM_KEYS)
		4:
			keys.append_array(BattleSceneUpdatePrewarmKeySets.STAGE4_RUNTIME_PREWARM_KEYS)
		5:
			keys.append_array(BattleSceneUpdatePrewarmKeySets.STAGE5_RUNTIME_PREWARM_KEYS)
		6:
			keys.append_array(BattleSceneUpdatePrewarmKeySets.STAGE6_RUNTIME_PREWARM_KEYS)
		_:
			keys.append_array(BattleSceneUpdatePrewarmKeySets.STAGE1_RUNTIME_PREWARM_KEYS)
	return _unique_non_empty_keys(keys)


func _get_match_player_skill_keys(character_type: String) -> Array:
	var normalized_character: String = character_runtime.normalize(character_type)
	var keys: Array = []
	keys.append_array(
		BattleSceneUpdatePrewarmKeySets.MATCH_PLAYER_SKILL_COMMON_PREWARM_KEYS
	)
	if character_runtime.is_viper(normalized_character):
		keys.append_array(BattleSceneUpdatePrewarmKeySets.MATCH_VIPER_SKILL_PREWARM_KEYS)
	elif character_runtime.is_commando(normalized_character):
		keys.append_array(BattleSceneUpdatePrewarmKeySets.MATCH_COMMANDO_SKILL_PREWARM_KEYS)
	elif character_runtime.is_optimus(normalized_character):
		keys.append_array(BattleSceneUpdatePrewarmKeySets.MATCH_OPTIMUS_SKILL_PREWARM_KEYS)
	elif character_runtime.is_blacksmith(normalized_character):
		keys.append_array([
			"blacksmith_skill_state",
			"blacksmith_skill_config",
			"blacksmith_thor_shield_state",
		])
	else:
		keys.append_array(BattleSceneUpdatePrewarmKeySets.MATCH_SMASHER_SKILL_PREWARM_KEYS)
	return keys


func _unique_non_empty_keys(keys: Array) -> Array:
	var unique_keys: Array = []
	for key_value in keys:
		var key := str(key_value)
		if key.is_empty() or unique_keys.has(key):
			continue
		unique_keys.append(key)
	return unique_keys


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	return BattleSceneOwnerReader.get_value(owner, key, fallback)
