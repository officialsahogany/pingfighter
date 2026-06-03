extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

const UPDATE_MODULE_KEYS := [
	"battle_frame_flow_controller",
	"battle_frame_flow_deps_builder",
	"battle_scene_actor_update_driver",
	"battle_scene_actor_update_result_applier",
	"battle_scene_player_control_config_builder",
	"battle_scene_item_update_driver",
	"battle_scene_skill_tooltip_driver",
	"battle_scene_runtime_perk_update_driver",
	"battle_scene_scoreboard_update_driver",
	"battle_scene_match_event_driver",
	"battle_scene_boss_health_flow",
	"battle_scene_effects_update_driver",
	"battle_scene_effects_update_result_applier",
	"lingpet_egg_runtime",
	"battle_scene_match_flow_driver",
	"battle_scene_match_reset_result_applier",
	"match_score_event_controller",
	"match_scoreboard_flow_controller",
	"match_round_restart_controller",
	"match_reset_controller",
	"active_item_runtime",
	"boss_ai_state",
	"serve_flow_controller",
	"skill_orb_tooltip_hover_state",
	"commando_firearm_tooltip_renderer",
]
const EFFECTS_CORE_PREWARM_KEYS := [
	"battle_feedback_state",
	"game_audio",
	"match_score_state",
	"scoreboard_state",
	"orb_hud_state",
	"actor_animation_state",
	"impact_effects",
	"ball_effects",
	"player_movement_state",
	"status_effect_state",
	"active_item_runtime",
	"mythic_item_runtime",
	"runtime_perk_state",
	"runtime_perk_catalog",
]
const EFFECTS_COMMON_CHARACTER_PREWARM_KEYS := [
	"runtime_perk_state",
	"monkey_blessing_delivery_state",
]
const EFFECTS_SMASHER_PREWARM_KEYS := [
	"smasher_power_smash_state",
	"smasher_plasma_state",
	"smasher_recovery_state",
	"smasher_cleanse_state",
	"smasher_warp_gate_state",
	"smasher_wheel_state",
	"smasher_magnum_grip_state",
	"smasher_dash_spirit_state",
	"smasher_shield_kiting_state",
	"smasher_combo_state",
]
const EFFECTS_VIPER_PREWARM_KEYS := [
	"viper_skill_runtime",
	"viper_jetpack_state",
	"viper_skill_config",
	"viper_skill_state",
]
const EFFECTS_COMMANDO_PREWARM_KEYS := [
	"commando_firearm_runtime",
]
const MATCH_STATE_PREWARM_KEYS := [
	"match_score_state",
	"round_flow_state",
	"scoreboard_state",
	"game_audio",
	"match_score_event_controller",
	"match_scoreboard_flow_controller",
	"match_round_restart_controller",
	"match_reset_controller",
]
const MATCH_ITEM_RUNTIME_PREWARM_KEYS := [
	"orb_hud_state",
	"active_item_hud_state",
	"active_item_runtime",
	"mythic_item_runtime",
	"treasure_hunt_runtime",
]
const MATCH_PLAYER_SKILL_COMMON_PREWARM_KEYS := [
	"laurel_leaf_shield_state",
	"monkey_blessing_delivery_state",
	"commando_reload_delivery_state",
	"runtime_perk_state",
]
const MATCH_SMASHER_SKILL_PREWARM_KEYS := [
	"smasher_skill_state",
	"smasher_drive_input_state",
	"smasher_plasma_state",
	"smasher_recovery_state",
	"smasher_cleanse_state",
	"smasher_warp_gate_state",
	"smasher_wheel_state",
	"smasher_magnum_grip_state",
	"smasher_dash_spirit_state",
	"smasher_shield_kiting_state",
	"smasher_skill_config",
	"smasher_dash_state",
]
const MATCH_VIPER_SKILL_PREWARM_KEYS := [
	"viper_skill_state",
	"viper_skill_config",
	"viper_skill_runtime",
]
const MATCH_COMMANDO_SKILL_PREWARM_KEYS := [
	"commando_skill_state",
	"commando_skill_config",
	"commando_emergency_supply_state",
	"commando_firearm_runtime",
	"commando_supply_drop_state",
]
const MATCH_OPTIMUS_SKILL_PREWARM_KEYS := [
	"optimus_energy_state",
]
const STAGE_RUNTIME_COMMON_PREWARM_KEYS := [
	"weather_event_state",
	"stage_runtime_router",
]
const STAGE1_RUNTIME_PREWARM_KEYS := [
	"stage1_pillar_background",
	"stage1_dalji_whip_skill_state",
	"stage1_dalji_spinning_top_skill_state",
	"stage1_dalji_boss_skill_cooldown_state",
	"stage1_balloon_event",
]
const STAGE2_RUNTIME_PREWARM_KEYS := [
	"stage2_pillar_background",
	"stage2_boss_skill_state",
	"stage2_monkey_banana_event",
]
const STAGE3_RUNTIME_PREWARM_KEYS := [
	"stage3_pillar_background",
	"stage3_boss_skill_state",
]
const STAGE4_RUNTIME_PREWARM_KEYS := [
	"stage4_pillar_background",
	"stage4_map_state",
	"stage4_temple_destruction_event",
	"stage4_moon_event",
	"stage4_bird_event",
	"stage4_brazier_monk_event",
	"stage4_ponk_skill_state",
]
const STAGE5_RUNTIME_PREWARM_KEYS := [
	"stage5_hongryun_pillar_background",
	"stage5_hongryun_state",
	"stage5_hongryun_fire_machine_event",
]
const STAGE6_RUNTIME_PREWARM_KEYS := [
	"stage6_tetriser_pillar_background",
	"stage6_tetriser_state",
	"stage6_tetriser_boss_skill_hud_renderer",
]

var character_runtime: Object = PlayerCharacterRuntime.new()
var battle_update_prewarmed := false
var battle_update_prewarmed_for := ""
var update_prewarm_step_index := 0
var update_prewarm_substep_index := 0
var update_prewarm_detail_label := ""
var battle_ball_update_prewarmed := false
var battle_ball_update_prewarmed_for := ""


func prewarm_update(owner: Object, registry: Object) -> void:
	while not prewarm_update_step(owner, registry):
		pass


func prewarm_update_step(owner: Object, registry: Object) -> bool:
	if owner == null or registry == null:
		return true
	var prewarm_key := _build_prewarm_key(owner)
	if battle_update_prewarmed and battle_update_prewarmed_for == prewarm_key:
		return true
	if battle_update_prewarmed_for != prewarm_key:
		battle_update_prewarmed = false
		battle_update_prewarmed_for = prewarm_key
		update_prewarm_step_index = 0
		update_prewarm_substep_index = 0
		update_prewarm_detail_label = ""
	var module_count := UPDATE_MODULE_KEYS.size()
	if update_prewarm_step_index < module_count:
		update_prewarm_detail_label = str(UPDATE_MODULE_KEYS[update_prewarm_step_index])
		_get_instance(registry, update_prewarm_detail_label)
		update_prewarm_step_index += 1
		update_prewarm_substep_index = 0
		return false

	var step_done := true
	match update_prewarm_step_index - module_count:
		0:
			update_prewarm_detail_label = "player_lookup"
			_prewarm_player_control_lookup(owner, registry)
		1:
			step_done = _prewarm_player_control_context_step(owner, registry)
		2:
			update_prewarm_detail_label = "boss_ai_context"
			_prewarm_boss_ai_context(owner, registry)
		3:
			step_done = _prewarm_effects_context_step(owner, registry)
		4:
			step_done = _prewarm_match_flow_context_step(owner, registry)
		_:
			battle_update_prewarmed = true
			update_prewarm_step_index = 0
			update_prewarm_substep_index = 0
			update_prewarm_detail_label = ""
			return true
	if not step_done:
		return false
	update_prewarm_step_index += 1
	update_prewarm_substep_index = 0
	return false


func prewarm_ball_update(owner: Object, registry: Object) -> void:
	while not prewarm_ball_update_step(owner, registry):
		pass


func prewarm_ball_update_step(owner: Object, registry: Object) -> bool:
	if owner == null or registry == null:
		return true
	var prewarm_key := _build_prewarm_key(owner)
	if battle_ball_update_prewarmed and battle_ball_update_prewarmed_for == prewarm_key:
		return true
	var ball_driver: Object = _get_instance(registry, "battle_scene_ball_update_driver")
	if ball_driver != null and ball_driver.has_method("prewarm_update"):
		ball_driver.prewarm_update(owner, registry)
	if ball_driver != null and ball_driver.has_method("prewarm_round_deps"):
		ball_driver.prewarm_round_deps(owner, registry)
	battle_ball_update_prewarmed = true
	battle_ball_update_prewarmed_for = prewarm_key
	return true


func get_update_prewarm_detail_label(owner: Object) -> String:
	var module_count := UPDATE_MODULE_KEYS.size()
	if update_prewarm_step_index < module_count:
		return str(UPDATE_MODULE_KEYS[update_prewarm_step_index])
	match update_prewarm_step_index - module_count:
		0:
			return "player_lookup"
		1:
			return _get_step_key_label(
				"player_deps",
				_get_player_control_context_prewarm_keys(character_runtime.normalize(_get_owner_value(owner, "selected_character_type", "smasher")))
			)
		2:
			return "boss_ai_context"
		3:
			return _get_step_key_label("effects_deps", _get_effects_context_prewarm_keys(owner))
		4:
			return _get_step_key_label("match_deps", _get_match_flow_context_prewarm_keys(owner))
	return ""


func _prewarm_update_context(owner: Object, registry: Object) -> void:
	_prewarm_player_control_context(owner, registry)
	_prewarm_boss_ai_context(owner, registry)
	_prewarm_effects_context(owner, registry)
	_prewarm_match_flow_context(registry)


func _prewarm_player_control_context(owner: Object, registry: Object) -> void:
	var context_builder: Object = _get_instance(registry, "battle_update_context")
	if context_builder == null:
		return

	var character_type: String = str(_get_owner_value(owner, "selected_character_type", "smasher"))
	if context_builder.has_method("build_player_control_config"):
		context_builder.build_player_control_config(character_type)
	if context_builder.has_method("build_player_control_deps"):
		context_builder.build_player_control_deps(registry, character_type)


func _prewarm_player_control_context_step(owner: Object, registry: Object) -> bool:
	var character_type: String = character_runtime.normalize(_get_owner_value(owner, "selected_character_type", "smasher"))
	var keys: Array = _get_player_control_context_prewarm_keys(character_type)
	if update_prewarm_substep_index < keys.size():
		var key := str(keys[update_prewarm_substep_index])
		update_prewarm_detail_label = "player_deps.%02d_%s" % [
			update_prewarm_substep_index,
			key,
		]
		var instance: Object = _get_instance(registry, key)
		if not _prewarm_instance_assets_step(key, instance):
			return false
		update_prewarm_substep_index += 1
		return false
	update_prewarm_detail_label = "player_deps.finalize"
	_prewarm_player_control_context(owner, registry)
	return true


func _prewarm_boss_ai_context(owner: Object, registry: Object) -> void:
	var context_builder: Object = _get_instance(registry, "battle_update_context")
	if context_builder == null:
		return
	if context_builder.has_method("build_boss_ai_context"):
		context_builder.build_boss_ai_context(owner, registry)


func _prewarm_effects_context(owner: Object, registry: Object) -> void:
	var context_builder: Object = _get_instance(registry, "battle_update_context")
	if context_builder == null:
		return
	var character_type: String = str(_get_owner_value(owner, "selected_character_type", "smasher"))
	var effects_context: Dictionary = {}
	if context_builder.has_method("build_effects_context"):
		effects_context = context_builder.build_effects_context(owner, registry)
	if context_builder.has_method("build_effects_deps"):
		context_builder.build_effects_deps(
			registry,
			int(effects_context.get("current_stage", _get_owner_value(owner, "current_stage", 1))),
			str(effects_context.get("selected_character_type", character_type))
		)


func _prewarm_effects_context_step(owner: Object, registry: Object) -> bool:
	var keys: Array = _get_effects_context_prewarm_keys(owner)
	if update_prewarm_substep_index < keys.size():
		var key := str(keys[update_prewarm_substep_index])
		update_prewarm_detail_label = "effects_deps.%02d_%s" % [
			update_prewarm_substep_index,
			key,
		]
		var instance: Object = _get_instance(registry, key)
		if not _prewarm_instance_assets_step(key, instance):
			return false
		update_prewarm_substep_index += 1
		return false
	update_prewarm_detail_label = "effects_deps.finalize"
	_prewarm_effects_context(owner, registry)
	return true


func _prewarm_match_flow_context(registry: Object) -> void:
	var context_builder: Object = _get_instance(registry, "battle_update_context")
	if context_builder == null:
		return
	if context_builder.has_method("build_match_flow_deps"):
		context_builder.build_match_flow_deps(registry)


func _prewarm_match_flow_context_step(owner: Object, registry: Object) -> bool:
	var keys: Array = _get_match_flow_context_prewarm_keys(owner)
	if update_prewarm_substep_index < keys.size():
		var key := str(keys[update_prewarm_substep_index])
		update_prewarm_detail_label = "match_deps.%02d_%s" % [
			update_prewarm_substep_index,
			key,
		]
		var instance: Object = _get_instance(registry, key)
		if not _prewarm_instance_assets_step(key, instance):
			return false
		update_prewarm_substep_index += 1
		return false
	update_prewarm_detail_label = "match_deps.deferred_finalize"
	return true


func _prewarm_player_control_lookup(owner: Object, registry: Object) -> void:
	var character_type: String = character_runtime.normalize(_get_owner_value(owner, "selected_character_type", "smasher"))
	_get_instance(registry, character_runtime.get_player_controller_key(character_type))


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _prewarm_instance_assets_step(key: String, instance: Object) -> bool:
	if key != "smasher_cleanse_state":
		return true
	if instance == null or not instance.has_method("prewarm_assets_step"):
		return true
	return bool(instance.prewarm_assets_step())


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	return BattleSceneOwnerReader.get_value(owner, key, fallback)


func _build_prewarm_key(owner: Object) -> String:
	return "%s:%d" % [
		character_runtime.normalize(_get_owner_value(owner, "selected_character_type", "smasher")),
		int(_get_owner_value(owner, "current_stage", 1)),
	]


func _get_player_control_context_prewarm_keys(character_type: String) -> Array:
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
	else:
		keys.append_array([
			"smasher_drive_input_state",
			"smasher_power_smash_state",
			"smasher_plasma_state",
			"smasher_recovery_state",
			"smasher_cleanse_state",
			"smasher_warp_gate_state",
			"smasher_wheel_state",
			"smasher_magnum_grip_state",
			"smasher_dash_spirit_state",
			"smasher_shield_kiting_state",
			"smasher_combo_state",
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


func _get_effects_context_prewarm_keys(owner: Object) -> Array:
	var character_type: String = character_runtime.normalize(_get_owner_value(owner, "selected_character_type", "smasher"))
	var current_stage: int = int(_get_owner_value(owner, "current_stage", 1))
	var keys: Array = []
	keys.append_array(EFFECTS_CORE_PREWARM_KEYS)
	keys.append_array(EFFECTS_COMMON_CHARACTER_PREWARM_KEYS)
	if character_runtime.is_viper(character_type):
		keys.append_array(EFFECTS_VIPER_PREWARM_KEYS)
	elif character_runtime.is_commando(character_type):
		keys.append_array(EFFECTS_COMMANDO_PREWARM_KEYS)
	elif not character_runtime.is_optimus(character_type):
		keys.append_array(EFFECTS_SMASHER_PREWARM_KEYS)
	keys.append_array(_get_stage_runtime_prewarm_keys(current_stage, false))
	return _unique_non_empty_keys(keys)


func _get_match_flow_context_prewarm_keys(owner: Object) -> Array:
	var character_type: String = character_runtime.normalize(_get_owner_value(owner, "selected_character_type", "smasher"))
	var current_stage: int = int(_get_owner_value(owner, "current_stage", 1))
	var keys: Array = []
	keys.append_array(MATCH_STATE_PREWARM_KEYS)
	keys.append_array(MATCH_ITEM_RUNTIME_PREWARM_KEYS)
	keys.append_array(_get_match_player_skill_prewarm_keys(character_type))
	keys.append_array(_get_stage_runtime_prewarm_keys(current_stage, false))
	return _unique_non_empty_keys(keys)


func _get_match_player_skill_prewarm_keys(character_type: String) -> Array:
	var normalized_character: String = character_runtime.normalize(character_type)
	var keys: Array = []
	keys.append_array(MATCH_PLAYER_SKILL_COMMON_PREWARM_KEYS)
	if character_runtime.is_viper(normalized_character):
		keys.append_array(MATCH_VIPER_SKILL_PREWARM_KEYS)
	elif character_runtime.is_commando(normalized_character):
		keys.append_array(MATCH_COMMANDO_SKILL_PREWARM_KEYS)
	elif character_runtime.is_optimus(normalized_character):
		keys.append_array(MATCH_OPTIMUS_SKILL_PREWARM_KEYS)
	else:
		keys.append_array(MATCH_SMASHER_SKILL_PREWARM_KEYS)
	return keys


func _get_stage_runtime_prewarm_keys(current_stage: int, include_all_stages: bool) -> Array:
	var keys: Array = []
	keys.append_array(STAGE_RUNTIME_COMMON_PREWARM_KEYS)
	if include_all_stages:
		keys.append_array(STAGE1_RUNTIME_PREWARM_KEYS)
		keys.append_array(STAGE2_RUNTIME_PREWARM_KEYS)
		keys.append_array(STAGE3_RUNTIME_PREWARM_KEYS)
		keys.append_array(STAGE4_RUNTIME_PREWARM_KEYS)
		keys.append_array(STAGE5_RUNTIME_PREWARM_KEYS)
		keys.append_array(STAGE6_RUNTIME_PREWARM_KEYS)
		return keys
	match current_stage:
		1:
			keys.append_array(STAGE1_RUNTIME_PREWARM_KEYS)
		2:
			keys.append_array(STAGE2_RUNTIME_PREWARM_KEYS)
		3:
			keys.append_array(STAGE3_RUNTIME_PREWARM_KEYS)
		4:
			keys.append_array(STAGE4_RUNTIME_PREWARM_KEYS)
		5:
			keys.append_array(STAGE5_RUNTIME_PREWARM_KEYS)
		6:
			keys.append_array(STAGE6_RUNTIME_PREWARM_KEYS)
		_:
			keys.append_array(STAGE1_RUNTIME_PREWARM_KEYS)
	return keys


func _unique_non_empty_keys(keys: Array) -> Array:
	var unique_keys: Array = []
	for key_value in keys:
		var key := str(key_value)
		if key == "" or unique_keys.has(key):
			continue
		unique_keys.append(key)
	return unique_keys


func _get_step_key_label(prefix: String, keys: Array) -> String:
	if update_prewarm_substep_index < keys.size():
		return "%s.%02d_%s" % [
			prefix,
			update_prewarm_substep_index,
			str(keys[update_prewarm_substep_index]),
		]
	return "%s.finalize" % prefix
