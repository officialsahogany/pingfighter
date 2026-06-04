extends RefCounted

const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

var character_runtime: Object = PlayerCharacterRuntime.new()

var _cached_update_registry: Object = null
var _cached_update_character_type := ""
var _cached_update_stage := -1
var _cached_update_deps: Dictionary = {}
var _has_cached_update_deps := false

var _cached_round_registry: Object = null
var _cached_round_character_type := ""
var _cached_round_stage := -1
var _cached_round_deps: Dictionary = {}
var _has_cached_round_deps := false


func build_update_deps(registry, runtime_context: Dictionary = {}) -> Dictionary:
	if not _has_runtime_selection_context(runtime_context):
		return _build_legacy_update_deps(registry)

	var character_type: String = character_runtime.normalize(runtime_context.get("selected_character_type", "smasher"))
	var current_stage: int = _normalize_stage(runtime_context.get("current_stage", 1))
	if (
		_has_cached_update_deps
		and registry == _cached_update_registry
		and character_type == _cached_update_character_type
		and current_stage == _cached_update_stage
	):
		return _cached_update_deps.duplicate()

	var deps: Dictionary = _build_common_update_deps(registry)
	_append_character_update_deps(deps, registry, character_type)
	_append_stage_update_deps(deps, registry, current_stage)
	_cached_update_registry = registry
	_cached_update_character_type = character_type
	_cached_update_stage = current_stage
	_cached_update_deps = deps
	_has_cached_update_deps = true
	return _cached_update_deps.duplicate()


func _build_legacy_update_deps(registry) -> Dictionary:
	var deps: Dictionary = _build_common_update_deps(registry)
	_append_smasher_update_deps(deps, registry, true)
	_append_viper_update_deps(deps, registry, false)
	_append_commando_update_deps(deps, registry, false)
	_append_legacy_stage_update_deps(deps, registry)
	return deps


func _build_common_update_deps(registry) -> Dictionary:
	return {
		"registry": registry,
		"ball_physics": _get_instance(registry, "ball_physics"),
		"ball_spin_state": _get_instance(registry, "ball_spin_state"),
		"ball_effects": _get_instance(registry, "ball_effects"),
		"ball_intensity": _get_instance(registry, "ball_intensity"),
		"motion_stepper": _get_instance(registry, "ball_motion_stepper"),
		"wall_bounce_controller": _get_instance(registry, "wall_bounce_controller"),
		"paddle_bounce_state": _get_instance(registry, "paddle_bounce_state"),
		"paddle_bounce_controller": _get_instance(registry, "paddle_bounce_controller"),
		"status_effect_state": _get_instance(registry, "status_effect_state"),
		"laurel_leaf_shield_state": _get_instance(registry, "laurel_leaf_shield_state"),
		"movement_state": _get_instance(registry, "player_movement_state"),
		"round_state": _get_instance(registry, "round_flow_state"),
		"dash_state": _get_instance(registry, "smasher_dash_state"),
		"orb_hud_state": _get_instance(registry, "orb_hud_state"),
		"impact_effects": _get_instance(registry, "impact_effects"),
		"audio": _get_instance(registry, "game_audio"),
		"feedback": _get_instance(registry, "battle_feedback_state"),
		"active_item_runtime": _get_instance(registry, "active_item_runtime"),
		"mythic_item_runtime": _get_instance(registry, "mythic_item_runtime"),
		"lingpet_egg_runtime": _get_instance(registry, "lingpet_egg_runtime"),
		"weather_event_state": _get_instance(registry, "weather_event_state"),
		"runtime_perk_state": _get_instance(registry, "runtime_perk_state"),
		"animation_state": _get_instance(registry, "actor_animation_state"),
		"ai_state": _get_instance(registry, "boss_ai_state"),
		"stage_runtime_router": _get_instance(registry, "stage_runtime_router"),
	}


func build_round_deps(registry, runtime_context: Dictionary = {}) -> Dictionary:
	if registry == null:
		return {}
	if not _has_runtime_selection_context(runtime_context):
		return _build_legacy_round_deps(registry)

	var character_type: String = character_runtime.normalize(runtime_context.get("selected_character_type", "smasher"))
	var current_stage: int = _normalize_stage(runtime_context.get("current_stage", 1))
	if (
		_has_cached_round_deps
		and registry == _cached_round_registry
		and character_type == _cached_round_character_type
		and current_stage == _cached_round_stage
	):
		return _cached_round_deps.duplicate()

	var perf_logger: Object = runtime_context.get("_perf_logger", null)
	var perf_prefix: String = str(runtime_context.get("_perf_prefix", "round_deps"))
	var deps: Dictionary = _build_common_round_deps(registry, perf_logger, "%s.common" % perf_prefix)
	_append_character_round_deps(deps, registry, character_type, perf_logger, "%s.character" % perf_prefix)
	_append_stage_round_deps(deps, registry, current_stage, perf_logger, "%s.stage" % perf_prefix)
	_cached_round_registry = registry
	_cached_round_character_type = character_type
	_cached_round_stage = current_stage
	_cached_round_deps = deps
	_has_cached_round_deps = true
	return _cached_round_deps.duplicate()


func _build_legacy_round_deps(registry) -> Dictionary:
	return {
		"registry": registry,
		"ball_round_state": registry.get_instance("ball_round_state"),
		"power_state": registry.get_instance("smasher_power_smash_state"),
		"drive_input_state": registry.get_instance("smasher_drive_input_state"),
		"smasher_magnum_grip_state": registry.get_instance("smasher_magnum_grip_state"),
		"smasher_recovery_state": registry.get_instance("smasher_recovery_state"),
		"smasher_cleanse_state": registry.get_instance("smasher_cleanse_state"),
		"status_effect_state": registry.get_instance("status_effect_state"),
		"smasher_warp_gate_state": registry.get_instance("smasher_warp_gate_state"),
		"smasher_wheel_state": registry.get_instance("smasher_wheel_state"),
		"smasher_dash_spirit_state": registry.get_instance("smasher_dash_spirit_state"),
		"smasher_shield_kiting_state": registry.get_instance("smasher_shield_kiting_state"),
		"laurel_leaf_shield_state": registry.get_instance("laurel_leaf_shield_state"),
		"combo_state": registry.get_instance("smasher_combo_state"),
		"ball_effects": registry.get_instance("ball_effects"),
		"ball_intensity": registry.get_instance("ball_intensity"),
		"impact_effects": registry.get_instance("impact_effects"),
		"audio": registry.get_instance("game_audio"),
		"ball_renderer": registry.get_instance("ball_renderer"),
		"wall_bounce_controller": registry.get_instance("wall_bounce_controller"),
		"round_state": registry.get_instance("round_flow_state"),
		"ai_state": registry.get_instance("boss_ai_state"),
		"movement_state": registry.get_instance("player_movement_state"),
		"animation_state": registry.get_instance("actor_animation_state"),
		"dash_state": registry.get_instance("smasher_dash_state"),
		"viper_skill_runtime": registry.get_instance("viper_skill_runtime"),
		"viper_skill_state": registry.get_instance("viper_skill_state"),
		"viper_skill_config": registry.get_instance("viper_skill_config"),
		"viper_jetpack_state": registry.get_instance("viper_jetpack_state"),
		"commando_firearm_runtime": registry.get_instance("commando_firearm_runtime"),
		"commando_supply_drop_state": registry.get_instance("commando_supply_drop_state"),
		"runtime_perk_state": registry.get_instance("runtime_perk_state"),
		"feedback": registry.get_instance("battle_feedback_state"),
		"ball_physics": registry.get_instance("ball_physics"),
		"active_item_runtime": registry.get_instance("active_item_runtime"),
		"mythic_item_runtime": registry.get_instance("mythic_item_runtime"),
		"weather_event_state": registry.get_instance("weather_event_state"),
		"stage1_dalji_whip_skill_state": registry.get_instance("stage1_dalji_whip_skill_state"),
		"stage1_dalji_spinning_top_skill_state": registry.get_instance("stage1_dalji_spinning_top_skill_state"),
		"stage1_dalji_boss_skill_cooldown_state": registry.get_instance("stage1_dalji_boss_skill_cooldown_state"),
		"stage2_boss_skill_state": registry.get_instance("stage2_boss_skill_state"),
		"stage3_boss_skill_state": registry.get_instance("stage3_boss_skill_state"),
		"stage2_pillar_background": registry.get_instance("stage2_pillar_background"),
		"stage4_pillar_background": registry.get_instance("stage4_pillar_background"),
		"stage4_map_state": registry.get_instance("stage4_map_state"),
		"stage4_temple_destruction_event": registry.get_instance("stage4_temple_destruction_event"),
		"stage4_moon_event": registry.get_instance("stage4_moon_event"),
		"stage4_bird_event": registry.get_instance("stage4_bird_event"),
		"stage4_brazier_monk_event": registry.get_instance("stage4_brazier_monk_event"),
		"stage4_ponk_skill_state": registry.get_instance("stage4_ponk_skill_state"),
		"stage5_hongryun_state": registry.get_instance("stage5_hongryun_state"),
		"stage5_hongryun_actor_renderer": registry.get_instance("stage5_hongryun_actor_renderer"),
		"stage1_balloon_event": registry.get_instance("stage1_balloon_event"),
	}


func _build_common_round_deps(registry, perf_logger: Object = null, perf_label_prefix: String = "") -> Dictionary:
	return {
		"registry": registry,
		"ball_round_state": _get_round_instance(registry, "ball_round_state", perf_logger, perf_label_prefix),
		"status_effect_state": _get_round_instance(registry, "status_effect_state", perf_logger, perf_label_prefix),
		"ball_effects": _get_round_instance(registry, "ball_effects", perf_logger, perf_label_prefix),
		"ball_intensity": _get_round_instance(registry, "ball_intensity", perf_logger, perf_label_prefix),
		"impact_effects": _get_round_instance(registry, "impact_effects", perf_logger, perf_label_prefix),
		"audio": _get_round_instance(registry, "game_audio", perf_logger, perf_label_prefix),
		"ball_renderer": _get_round_instance(registry, "ball_renderer", perf_logger, perf_label_prefix),
		"wall_bounce_controller": _get_round_instance(registry, "wall_bounce_controller", perf_logger, perf_label_prefix),
		"round_state": _get_round_instance(registry, "round_flow_state", perf_logger, perf_label_prefix),
		"ai_state": _get_round_instance(registry, "boss_ai_state", perf_logger, perf_label_prefix),
		"movement_state": _get_round_instance(registry, "player_movement_state", perf_logger, perf_label_prefix),
		"animation_state": _get_round_instance(registry, "actor_animation_state", perf_logger, perf_label_prefix),
		"runtime_perk_state": _get_round_instance(registry, "runtime_perk_state", perf_logger, perf_label_prefix),
		"feedback": _get_round_instance(registry, "battle_feedback_state", perf_logger, perf_label_prefix),
		"ball_physics": _get_round_instance(registry, "ball_physics", perf_logger, perf_label_prefix),
		"active_item_runtime": _get_round_instance(registry, "active_item_runtime", perf_logger, perf_label_prefix),
		"mythic_item_runtime": _get_round_instance(registry, "mythic_item_runtime", perf_logger, perf_label_prefix),
		"lingpet_egg_runtime": _get_round_instance(registry, "lingpet_egg_runtime", perf_logger, perf_label_prefix),
		"weather_event_state": _get_round_instance(registry, "weather_event_state", perf_logger, perf_label_prefix),
	}


func _append_character_round_deps(
	deps: Dictionary,
	registry,
	character_type: String,
	perf_logger: Object = null,
	perf_label_prefix: String = ""
) -> void:
	if character_runtime.is_viper(character_type):
		_append_viper_round_deps(deps, registry, perf_logger, perf_label_prefix)
	elif character_runtime.is_commando(character_type):
		_append_commando_round_deps(deps, registry, perf_logger, perf_label_prefix)
	elif character_runtime.is_blacksmith(character_type):
		_append_blacksmith_round_deps(deps, registry, perf_logger, perf_label_prefix)
	else:
		_append_smasher_round_deps(deps, registry, perf_logger, perf_label_prefix)


func _append_smasher_round_deps(
	deps: Dictionary,
	registry,
	perf_logger: Object = null,
	perf_label_prefix: String = ""
) -> void:
	deps["power_state"] = _get_round_instance(registry, "smasher_power_smash_state", perf_logger, perf_label_prefix)
	deps["drive_input_state"] = _get_round_instance(registry, "smasher_drive_input_state", perf_logger, perf_label_prefix)
	deps["smasher_magnum_grip_state"] = _get_round_instance(registry, "smasher_magnum_grip_state", perf_logger, perf_label_prefix)
	deps["smasher_recovery_state"] = _get_round_instance(registry, "smasher_recovery_state", perf_logger, perf_label_prefix)
	deps["smasher_cleanse_state"] = _get_round_instance(registry, "smasher_cleanse_state", perf_logger, perf_label_prefix)
	deps["smasher_warp_gate_state"] = _get_round_instance(registry, "smasher_warp_gate_state", perf_logger, perf_label_prefix)
	deps["smasher_wheel_state"] = _get_round_instance(registry, "smasher_wheel_state", perf_logger, perf_label_prefix)
	deps["smasher_dash_spirit_state"] = _get_round_instance(registry, "smasher_dash_spirit_state", perf_logger, perf_label_prefix)
	deps["smasher_shield_kiting_state"] = _get_round_instance(registry, "smasher_shield_kiting_state", perf_logger, perf_label_prefix)
	deps["combo_state"] = _get_round_instance(registry, "smasher_combo_state", perf_logger, perf_label_prefix)
	deps["dash_state"] = _get_round_instance(registry, "smasher_dash_state", perf_logger, perf_label_prefix)


func _append_viper_round_deps(
	deps: Dictionary,
	registry,
	perf_logger: Object = null,
	perf_label_prefix: String = ""
) -> void:
	deps["viper_skill_runtime"] = _get_round_instance(registry, "viper_skill_runtime", perf_logger, perf_label_prefix)
	deps["viper_skill_state"] = _get_round_instance(registry, "viper_skill_state", perf_logger, perf_label_prefix)
	deps["viper_skill_config"] = _get_round_instance(registry, "viper_skill_config", perf_logger, perf_label_prefix)
	deps["viper_jetpack_state"] = _get_round_instance(registry, "viper_jetpack_state", perf_logger, perf_label_prefix)


func _append_commando_round_deps(
	deps: Dictionary,
	registry,
	perf_logger: Object = null,
	perf_label_prefix: String = ""
) -> void:
	deps["commando_firearm_runtime"] = _get_round_instance(registry, "commando_firearm_runtime", perf_logger, perf_label_prefix)
	deps["commando_supply_drop_state"] = _get_round_instance(registry, "commando_supply_drop_state", perf_logger, perf_label_prefix)
	deps["commando_weapon_controller"] = _get_round_instance(registry, "commando_weapon_controller", perf_logger, perf_label_prefix)


func _append_blacksmith_round_deps(
	deps: Dictionary,
	registry,
	perf_logger: Object = null,
	perf_label_prefix: String = ""
) -> void:
	deps["blacksmith_thor_shield_state"] = _get_round_instance(registry, "blacksmith_thor_shield_state", perf_logger, perf_label_prefix)
	deps["blacksmith_skill_state"] = _get_round_instance(registry, "blacksmith_skill_state", perf_logger, perf_label_prefix)
	deps["blacksmith_skill_config"] = _get_round_instance(registry, "blacksmith_skill_config", perf_logger, perf_label_prefix)
	deps["skill_state"] = deps["blacksmith_skill_state"]
	deps["skill_config"] = deps["blacksmith_skill_config"]
	deps["dash_state"] = _get_round_instance(registry, "smasher_dash_state", perf_logger, perf_label_prefix)


func _append_stage_round_deps(
	deps: Dictionary,
	registry,
	current_stage: int,
	perf_logger: Object = null,
	perf_label_prefix: String = ""
) -> void:
	match current_stage:
		1:
			deps["stage1_dalji_whip_skill_state"] = _get_round_instance(registry, "stage1_dalji_whip_skill_state", perf_logger, perf_label_prefix)
			deps["stage1_dalji_spinning_top_skill_state"] = _get_round_instance(registry, "stage1_dalji_spinning_top_skill_state", perf_logger, perf_label_prefix)
			deps["stage1_dalji_boss_skill_cooldown_state"] = _get_round_instance(registry, "stage1_dalji_boss_skill_cooldown_state", perf_logger, perf_label_prefix)
			deps["stage1_balloon_event"] = _get_round_instance(registry, "stage1_balloon_event", perf_logger, perf_label_prefix)
		2:
			deps["stage2_pillar_background"] = _get_round_instance(registry, "stage2_pillar_background", perf_logger, perf_label_prefix)
			deps["stage2_boss_skill_state"] = _get_round_instance(registry, "stage2_boss_skill_state", perf_logger, perf_label_prefix)
		3:
			deps["stage3_boss_skill_state"] = _get_round_instance(registry, "stage3_boss_skill_state", perf_logger, perf_label_prefix)
		4:
			deps["stage4_pillar_background"] = _get_round_instance(registry, "stage4_pillar_background", perf_logger, perf_label_prefix)
			deps["stage4_map_state"] = _get_round_instance(registry, "stage4_map_state", perf_logger, perf_label_prefix)
			deps["stage4_temple_destruction_event"] = _get_round_instance(registry, "stage4_temple_destruction_event", perf_logger, perf_label_prefix)
			deps["stage4_moon_event"] = _get_round_instance(registry, "stage4_moon_event", perf_logger, perf_label_prefix)
			deps["stage4_bird_event"] = _get_round_instance(registry, "stage4_bird_event", perf_logger, perf_label_prefix)
			deps["stage4_brazier_monk_event"] = _get_round_instance(registry, "stage4_brazier_monk_event", perf_logger, perf_label_prefix)
			deps["stage4_ponk_skill_state"] = _get_round_instance(registry, "stage4_ponk_skill_state", perf_logger, perf_label_prefix)
		5:
			deps["stage5_hongryun_state"] = _get_round_instance(registry, "stage5_hongryun_state", perf_logger, perf_label_prefix)
			deps["stage5_hongryun_actor_renderer"] = _get_round_instance(registry, "stage5_hongryun_actor_renderer", perf_logger, perf_label_prefix)


func _append_character_update_deps(deps: Dictionary, registry, character_type: String) -> void:
	if character_runtime.is_viper(character_type):
		_append_viper_update_deps(deps, registry, true)
	elif character_runtime.is_commando(character_type):
		_append_commando_update_deps(deps, registry, true)
	elif character_runtime.is_blacksmith(character_type):
		_append_blacksmith_update_deps(deps, registry, true)
	else:
		_append_smasher_update_deps(deps, registry, true)


func _append_smasher_update_deps(deps: Dictionary, registry, include_generic_keys: bool) -> void:
	if include_generic_keys:
		deps["input_reader"] = _get_instance(registry, "smasher_input_reader")
		deps["power_state"] = _get_instance(registry, "smasher_power_smash_state")
		deps["drive_input_state"] = _get_instance(registry, "smasher_drive_input_state")
		deps["combo_state"] = _get_instance(registry, "smasher_combo_state")
		deps["skill_state"] = _get_instance(registry, "smasher_skill_state")
		deps["skill_config"] = _get_instance(registry, "smasher_skill_config")
	deps["drive_bounce_state"] = _get_instance(registry, "smasher_drive_bounce_state")
	deps["drive_counter_state"] = _get_instance(registry, "smasher_drive_counter_state")
	deps["drive_activation_controller"] = _get_instance(registry, "smasher_drive_activation_controller")
	deps["power_activation_controller"] = _get_instance(registry, "smasher_power_smash_activation_controller")
	deps["power_motion_controller"] = _get_instance(registry, "smasher_power_smash_motion_controller")
	deps["smasher_magnum_grip_state"] = _get_instance(registry, "smasher_magnum_grip_state")
	deps["smasher_recovery_state"] = _get_instance(registry, "smasher_recovery_state")
	deps["smasher_cleanse_state"] = _get_instance(registry, "smasher_cleanse_state")
	deps["smasher_warp_gate_state"] = _get_instance(registry, "smasher_warp_gate_state")
	deps["smasher_wheel_state"] = _get_instance(registry, "smasher_wheel_state")
	deps["smasher_dash_spirit_state"] = _get_instance(registry, "smasher_dash_spirit_state")
	deps["smasher_shield_kiting_state"] = _get_instance(registry, "smasher_shield_kiting_state")


func _append_viper_update_deps(deps: Dictionary, registry, include_generic_keys: bool) -> void:
	var skill_state: Object = _get_instance(registry, "viper_skill_state")
	var skill_config: Object = _get_instance(registry, "viper_skill_config")
	if include_generic_keys:
		deps["input_reader"] = _get_instance(registry, "viper_input_reader")
		deps["skill_state"] = skill_state
		deps["skill_config"] = skill_config
	deps["viper_skill_runtime"] = _get_instance(registry, "viper_skill_runtime")
	deps["viper_skill_state"] = skill_state
	deps["viper_skill_config"] = skill_config
	deps["viper_jetpack_state"] = _get_instance(registry, "viper_jetpack_state")


func _append_commando_update_deps(deps: Dictionary, registry, include_generic_keys: bool) -> void:
	var skill_state: Object = _get_instance(registry, "commando_skill_state")
	var skill_config: Object = _get_instance(registry, "commando_skill_config")
	if include_generic_keys:
		deps["input_reader"] = _get_instance(registry, "commando_input_reader")
		deps["skill_state"] = skill_state
		deps["skill_config"] = skill_config
	deps["commando_firearm_runtime"] = _get_instance(registry, "commando_firearm_runtime")
	deps["commando_supply_drop_state"] = _get_instance(registry, "commando_supply_drop_state")
	if include_generic_keys:
		deps["commando_weapon_controller"] = _get_instance(registry, "commando_weapon_controller")
		deps["commando_emergency_supply_state"] = _get_instance(registry, "commando_emergency_supply_state")


func _append_blacksmith_update_deps(deps: Dictionary, registry, include_generic_keys: bool) -> void:
	var skill_state: Object = _get_instance(registry, "blacksmith_skill_state")
	var skill_config: Object = _get_instance(registry, "blacksmith_skill_config")
	if include_generic_keys:
		deps["input_reader"] = _get_instance(registry, "blacksmith_input_reader")
		deps["skill_state"] = skill_state
		deps["skill_config"] = skill_config
	deps["blacksmith_skill_state"] = skill_state
	deps["blacksmith_skill_config"] = skill_config
	deps["blacksmith_thor_shield_state"] = _get_instance(registry, "blacksmith_thor_shield_state")


func _append_legacy_stage_update_deps(deps: Dictionary, registry) -> void:
	deps["stage_background"] = _get_instance(registry, "stage1_pillar_background")
	deps["stage1_pillar_background"] = _get_instance(registry, "stage1_pillar_background")
	deps["stage2_pillar_background"] = _get_instance(registry, "stage2_pillar_background")
	deps["stage2_boss_skill_state"] = _get_instance(registry, "stage2_boss_skill_state")
	deps["stage3_boss_skill_state"] = _get_instance(registry, "stage3_boss_skill_state")
	deps["stage4_pillar_background"] = _get_instance(registry, "stage4_pillar_background")
	deps["stage4_map_state"] = _get_instance(registry, "stage4_map_state")
	deps["stage4_temple_destruction_event"] = _get_instance(registry, "stage4_temple_destruction_event")
	deps["stage4_moon_event"] = _get_instance(registry, "stage4_moon_event")
	deps["stage4_bird_event"] = _get_instance(registry, "stage4_bird_event")
	deps["stage4_brazier_monk_event"] = _get_instance(registry, "stage4_brazier_monk_event")
	deps["stage4_ponk_skill_state"] = _get_instance(registry, "stage4_ponk_skill_state")
	deps["stage5_hongryun_state"] = _get_instance(registry, "stage5_hongryun_state")
	deps["stage1_dalji_whip_skill_state"] = _get_instance(registry, "stage1_dalji_whip_skill_state")
	deps["stage1_dalji_spinning_top_skill_state"] = _get_instance(registry, "stage1_dalji_spinning_top_skill_state")
	deps["stage1_dalji_boss_skill_cooldown_state"] = _get_instance(registry, "stage1_dalji_boss_skill_cooldown_state")
	deps["stage1_balloon_event"] = _get_instance(registry, "stage1_balloon_event")


func _append_stage_update_deps(deps: Dictionary, registry, current_stage: int) -> void:
	deps["current_stage"] = current_stage
	var stage_background_key: String = _get_stage_background_key(deps.get("stage_runtime_router", null), current_stage)
	var stage_background: Object = _get_instance(registry, stage_background_key)
	deps["stage_background"] = stage_background
	if stage_background_key != "":
		deps[stage_background_key] = stage_background

	match current_stage:
		1:
			deps["stage1_dalji_whip_skill_state"] = _get_instance(registry, "stage1_dalji_whip_skill_state")
			deps["stage1_dalji_spinning_top_skill_state"] = _get_instance(registry, "stage1_dalji_spinning_top_skill_state")
			deps["stage1_dalji_boss_skill_cooldown_state"] = _get_instance(registry, "stage1_dalji_boss_skill_cooldown_state")
			deps["stage1_balloon_event"] = _get_instance(registry, "stage1_balloon_event")
		2:
			deps["stage2_pillar_background"] = stage_background
			deps["stage2_boss_skill_state"] = _get_instance(registry, "stage2_boss_skill_state")
		3:
			deps["stage3_boss_skill_state"] = _get_instance(registry, "stage3_boss_skill_state")
		4:
			deps["stage4_pillar_background"] = stage_background
			deps["stage4_map_state"] = _get_instance(registry, "stage4_map_state")
			deps["stage4_temple_destruction_event"] = _get_instance(registry, "stage4_temple_destruction_event")
			deps["stage4_moon_event"] = _get_instance(registry, "stage4_moon_event")
			deps["stage4_bird_event"] = _get_instance(registry, "stage4_bird_event")
			deps["stage4_brazier_monk_event"] = _get_instance(registry, "stage4_brazier_monk_event")
			deps["stage4_ponk_skill_state"] = _get_instance(registry, "stage4_ponk_skill_state")
		5:
			deps["stage5_hongryun_state"] = _get_instance(registry, "stage5_hongryun_state")


func _get_stage_background_key(router: Object, current_stage: int) -> String:
	if router != null and router.has_method("get_module_key"):
		var routed_key: String = str(router.get_module_key(current_stage, "stage_background"))
		if routed_key != "":
			return routed_key
	match current_stage:
		2:
			return "stage2_pillar_background"
		3:
			return "stage3_pillar_background"
		4:
			return "stage4_pillar_background"
	return "stage1_pillar_background"


func _normalize_stage(value: Variant) -> int:
	var current_stage: int = int(value)
	if current_stage <= 0:
		return 1
	return current_stage


func _has_runtime_selection_context(runtime_context: Dictionary) -> bool:
	return runtime_context.has("current_stage") or runtime_context.has("selected_character_type")


func _get_instance(registry, key: String) -> Object:
	if registry == null or key == "" or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_round_instance(registry, key: String, perf_logger: Object, perf_label_prefix: String) -> Object:
	var sample_start: int = _perf_begin(perf_logger)
	var instance: Object = _get_instance(registry, key)
	if perf_label_prefix != "":
		_perf_end(perf_logger, "%s.%s" % [perf_label_prefix, key], sample_start)
	return instance


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
