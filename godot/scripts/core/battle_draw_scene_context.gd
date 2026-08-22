extends RefCounted

const BattleDrawPlayfieldSceneContext := preload("res://scripts/core/battle_draw_playfield_scene_context.gd")
const BattleDrawPillarContext := preload("res://scripts/core/battle_draw_pillar_context.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

var playfield_context: Object = BattleDrawPlayfieldSceneContext.new()
var pillar_context: Object = BattleDrawPillarContext.new()
var character_runtime: Object = PlayerCharacterRuntime.new()


func build_pillar_scene_context(
	owner: Object,
	view_size: Vector2,
	layout: Dictionary,
	top_mini_score_sparkle_duration: float
) -> Dictionary:
	return pillar_context.build_scene_context(owner, view_size, layout, top_mini_score_sparkle_duration)


func build_pillar_scene_states(registry, current_stage: int = 1) -> Dictionary:
	return pillar_context.build_scene_states(registry, current_stage)


func build_scene_context(owner: Object, shake_offset: Vector2, registry) -> Dictionary:
	return playfield_context.build(owner, shake_offset, registry)


func build_scene_deps(registry, feedback, power_state, draw_context: Dictionary = {}) -> Dictionary:
	if draw_context.is_empty():
		return _build_full_scene_deps(registry, feedback, power_state)
	var deps: Dictionary = _build_common_scene_deps(registry, feedback, power_state)
	_append_stage_scene_deps(
		deps,
		registry,
		int(draw_context.get("current_stage", 1)),
		_normalize_stage1_boss_variant(draw_context.get("stage1_boss_variant", "dalji"))
	)
	_append_character_scene_deps(
		deps,
		registry,
		character_runtime.normalize(draw_context.get("selected_character_type", "smasher"))
	)
	return deps


func _build_full_scene_deps(registry, feedback, power_state) -> Dictionary:
	return {
		"feedback": feedback,
		"animation_state": _get_instance(registry, "actor_animation_state"),
		"scoreboard_state": _get_instance(registry, "scoreboard_state"),
		"boss_ai_state": _get_instance(registry, "boss_ai_state"),
		"pillar_drawer": _get_instance(registry, "pillar_orb_drawer"),
		"ball_effects": _get_instance(registry, "ball_effects"),
		"ball_intensity": _get_instance(registry, "ball_intensity"),
		"impact_effects": _get_instance(registry, "impact_effects"),
		"round_state": _get_instance(registry, "round_flow_state"),
		"power_state": power_state,
		"drive_input_state": _get_instance(registry, "smasher_drive_input_state"),
		"skill_state": _get_instance(registry, "smasher_skill_state"),
		"skill_config": _get_instance(registry, "smasher_skill_config"),
		"battle_resources": _get_instance(registry, "battle_resources"),
		"stage1_dalji_whip_skill_state": _get_instance(registry, "stage1_dalji_whip_skill_state"),
		"stage1_dalji_spinning_top_skill_state": _get_instance(registry, "stage1_dalji_spinning_top_skill_state"),
		"stage1_dalji_boss_skill_cooldown_state": _get_instance(registry, "stage1_dalji_boss_skill_cooldown_state"),
		"stage1_gaksital_fan_throw_skill_state": _get_instance(registry, "stage1_gaksital_fan_throw_skill_state"),
		"stage1_gaksital_fan_wind_skill_state": _get_instance(registry, "stage1_gaksital_fan_wind_skill_state"),
		"stage1_gaksital_boss_skill_cooldown_state": _get_instance(registry, "stage1_gaksital_boss_skill_cooldown_state"),
		"stage1_pododaejang_patrol_guards_skill_state": _get_instance(registry, "stage1_pododaejang_patrol_guards_skill_state"),
		"stage1_pododaejang_arrest_rope_skill_state": _get_instance(registry, "stage1_pododaejang_arrest_rope_skill_state"),
		"stage1_pododaejang_boss_skill_cooldown_state": _get_instance(registry, "stage1_pododaejang_boss_skill_cooldown_state"),
		"stage2_pillar_background": _get_instance(registry, "stage2_pillar_background"),
		"stage2_boss_skill_state": _get_instance(registry, "stage2_boss_skill_state"),
		"stage3_boss_skill_state": _get_instance(registry, "stage3_boss_skill_state"),
		"stage4_map_state": _get_instance(registry, "stage4_map_state"),
		"stage4_temple_destruction_event": _get_instance(registry, "stage4_temple_destruction_event"),
		"stage4_moon_event": _get_instance(registry, "stage4_moon_event"),
		"stage4_bird_event": _get_instance(registry, "stage4_bird_event"),
		"stage4_brazier_monk_event": _get_instance(registry, "stage4_brazier_monk_event"),
		"stage4_ponk_skill_state": _get_instance(registry, "stage4_ponk_skill_state"),
		"stage5_hongryun_state": _get_instance(registry, "stage5_hongryun_state"),
		"stage5_hongryun_fire_machine_event": _get_instance(registry, "stage5_hongryun_fire_machine_event"),
		"stage5_hongryun_boss_skill_hud_renderer": _get_instance(registry, "stage5_hongryun_boss_skill_hud_renderer"),
		"stage6_tetriser_state": _get_instance(registry, "stage6_tetriser_state"),
		"stage7_akamu_state": _get_instance(registry, "stage7_akamu_state"),
		"active_item_runtime": _get_instance(registry, "active_item_runtime"),
		"mythic_item_runtime": _get_instance(registry, "mythic_item_runtime"),
		"status_effect_state": _get_instance(registry, "status_effect_state"),
		"smasher_warp_gate_state": _get_instance(registry, "smasher_warp_gate_state"),
		"smasher_wheel_state": _get_instance(registry, "smasher_wheel_state"),
		"commando_firearm_runtime": _get_instance(registry, "commando_firearm_runtime"),
		"commando_weapon_controller": _get_instance(registry, "commando_weapon_controller"),
		"commando_supply_drop_state": _get_instance(registry, "commando_supply_drop_state"),
		"commando_reload_delivery_state": _get_instance(registry, "commando_reload_delivery_state"),
		"viper_jetpack_state": _get_instance(registry, "viper_jetpack_state"),
		"viper_skill_runtime": _get_instance(registry, "viper_skill_runtime"),
		"stage_ball_spawn_intro": _get_instance(registry, "stage_ball_spawn_intro"),
		"defeat_continue_revival_beat_state": _get_instance(registry, "defeat_continue_revival_beat_state"),
		"victory_loot_phase_state": _get_instance(registry, "victory_loot_phase_state"),
	}


func _build_common_scene_deps(registry, feedback, power_state) -> Dictionary:
	return {
		"feedback": feedback,
		"animation_state": _get_instance(registry, "actor_animation_state"),
		"scoreboard_state": _get_instance(registry, "scoreboard_state"),
		"boss_ai_state": _get_instance(registry, "boss_ai_state"),
		"pillar_drawer": _get_instance(registry, "pillar_orb_drawer"),
		"ball_effects": _get_instance(registry, "ball_effects"),
		"ball_intensity": _get_instance(registry, "ball_intensity"),
		"impact_effects": _get_instance(registry, "impact_effects"),
		"round_state": _get_instance(registry, "round_flow_state"),
		"power_state": power_state,
		"battle_resources": _get_instance(registry, "battle_resources"),
		"active_item_runtime": _get_instance(registry, "active_item_runtime"),
		"mythic_item_runtime": _get_instance(registry, "mythic_item_runtime"),
		"status_effect_state": _get_instance(registry, "status_effect_state"),
		"stage_ball_spawn_intro": _get_instance(registry, "stage_ball_spawn_intro"),
		"defeat_continue_revival_beat_state": _get_instance(registry, "defeat_continue_revival_beat_state"),
		"victory_loot_phase_state": _get_instance(registry, "victory_loot_phase_state"),
	}


func _append_stage_scene_deps(
	deps: Dictionary,
	registry,
	current_stage: int,
	stage1_boss_variant: String = "dalji"
) -> void:
	match current_stage:
		1:
			if stage1_boss_variant == "gaksi":
				deps["stage1_gaksital_fan_throw_skill_state"] = _get_instance(registry, "stage1_gaksital_fan_throw_skill_state")
				deps["stage1_gaksital_fan_wind_skill_state"] = _get_instance(registry, "stage1_gaksital_fan_wind_skill_state")
				deps["stage1_gaksital_boss_skill_cooldown_state"] = _get_instance(registry, "stage1_gaksital_boss_skill_cooldown_state")
			elif stage1_boss_variant == "podo":
				deps["stage1_pododaejang_patrol_guards_skill_state"] = _get_instance(registry, "stage1_pododaejang_patrol_guards_skill_state")
				deps["stage1_pododaejang_arrest_rope_skill_state"] = _get_instance(registry, "stage1_pododaejang_arrest_rope_skill_state")
				deps["stage1_pododaejang_boss_skill_cooldown_state"] = _get_instance(registry, "stage1_pododaejang_boss_skill_cooldown_state")
			elif stage1_boss_variant == "dalji":
				deps["stage1_dalji_whip_skill_state"] = _get_instance(registry, "stage1_dalji_whip_skill_state")
				deps["stage1_dalji_spinning_top_skill_state"] = _get_instance(registry, "stage1_dalji_spinning_top_skill_state")
				deps["stage1_dalji_boss_skill_cooldown_state"] = _get_instance(registry, "stage1_dalji_boss_skill_cooldown_state")
		2:
			deps["stage2_pillar_background"] = _get_instance(registry, "stage2_pillar_background")
			deps["stage2_boss_skill_state"] = _get_instance(registry, "stage2_boss_skill_state")
		3:
			deps["stage3_boss_skill_state"] = _get_instance(registry, "stage3_boss_skill_state")
		4:
			deps["stage4_map_state"] = _get_instance(registry, "stage4_map_state")
			deps["stage4_temple_destruction_event"] = _get_instance(registry, "stage4_temple_destruction_event")
			deps["stage4_moon_event"] = _get_instance(registry, "stage4_moon_event")
			deps["stage4_bird_event"] = _get_instance(registry, "stage4_bird_event")
			deps["stage4_brazier_monk_event"] = _get_instance(registry, "stage4_brazier_monk_event")
			deps["stage4_ponk_skill_state"] = _get_instance(registry, "stage4_ponk_skill_state")
		5:
			deps["stage5_hongryun_state"] = _get_instance(registry, "stage5_hongryun_state")
			deps["stage5_hongryun_fire_machine_event"] = _get_instance(registry, "stage5_hongryun_fire_machine_event")
			deps["stage5_hongryun_boss_skill_hud_renderer"] = _get_instance(registry, "stage5_hongryun_boss_skill_hud_renderer")
		6:
			deps["stage6_tetriser_state"] = _get_instance(registry, "stage6_tetriser_state")
		7:
			deps["stage7_akamu_state"] = _get_instance(registry, "stage7_akamu_state")


func _append_character_scene_deps(deps: Dictionary, registry, character_type: String) -> void:
	deps["skill_state"] = _get_instance(registry, character_runtime.get_skill_state_key(character_type))
	deps["skill_config"] = _get_instance(registry, character_runtime.get_skill_config_key(character_type))
	match character_type:
		"smasher":
			deps["drive_input_state"] = _get_instance(registry, "smasher_drive_input_state")
			deps["smasher_warp_gate_state"] = _get_instance(registry, "smasher_warp_gate_state")
			deps["smasher_wheel_state"] = _get_instance(registry, "smasher_wheel_state")
		"soldier":
			deps["commando_firearm_runtime"] = _get_instance(registry, "commando_firearm_runtime")
			deps["commando_weapon_controller"] = _get_instance(registry, "commando_weapon_controller")
			deps["commando_supply_drop_state"] = _get_instance(registry, "commando_supply_drop_state")
			deps["commando_reload_delivery_state"] = _get_instance(registry, "commando_reload_delivery_state")
		"viper":
			deps["viper_jetpack_state"] = _get_instance(registry, "viper_jetpack_state")
			deps["viper_skill_runtime"] = _get_instance(registry, "viper_skill_runtime")


func _get_instance(registry, key: String) -> Object:
	if registry == null or key == "" or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _normalize_stage1_boss_variant(value: Variant) -> String:
	var variant: String = str(value).strip_edges().to_lower()
	if variant in ["gaksi", "gaksital", "talkwangdae", "talchum"]:
		return "gaksi"
	if variant in ["podo", "pododaejang", "podo_daejang"]:
		return "podo"
	return "dalji"
