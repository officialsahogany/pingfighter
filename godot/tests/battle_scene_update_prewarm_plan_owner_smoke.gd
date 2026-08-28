extends SceneTree

const BattleSceneUpdatePrewarmPlan := preload(
	"res://scripts/core/battle_scene_update_prewarm_plan.gd"
)

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var current_stage := 4
	var selected_character_type := "viper"


func _init() -> void:
	_verify_selected_character_and_stage_plans()
	_verify_all_stage_plan_and_deduplication()
	_verify_source_ownership()

	if _failures.is_empty():
		print("battle_scene_update_prewarm_plan_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_selected_character_and_stage_plans() -> void:
	var planner: Object = BattleSceneUpdatePrewarmPlan.new()
	var owner := FakeOwner.new()
	_expect(planner.build_prewarm_key(owner) == "viper:4", "plan cache key must include normalized character and stage")

	var player_keys: Array = planner.get_player_control_context_keys("viper")
	_expect_has(player_keys, "viper_skill_runtime", "Viper player plan")
	_expect_has(player_keys, "viper_jetpack_state", "Viper player plan")
	_expect_not_has(player_keys, "commando_weapon_controller", "Viper player plan")
	_expect_not_has(player_keys, "smasher_drive_input_state", "Viper player plan")

	var effects_keys: Array = planner.get_effects_context_keys(owner)
	_expect_has(effects_keys, "viper_skill_runtime", "Viper effects plan")
	_expect_has(effects_keys, "stage4_ponk_skill_state", "Stage 4 effects plan")
	_expect_not_has(effects_keys, "smasher_power_smash_state", "Viper effects plan")
	_expect_not_has(effects_keys, "stage2_boss_skill_state", "Stage 4 effects plan")

	var match_keys: Array = planner.get_match_flow_context_keys(owner)
	_expect_has(match_keys, "viper_skill_state", "Viper match plan")
	_expect_has(match_keys, "viper_skill_runtime", "Viper match plan")
	_expect_has(match_keys, "stage4_map_state", "Stage 4 match plan")
	_expect_has(match_keys, "active_item_runtime", "shared match plan")
	_expect_has(match_keys, "ball_intensity", "shared match plan")
	_expect_has(match_keys, "victory_highlight_playback_state", "shared match plan")
	_expect_has(match_keys, "victory_highlight_recorder", "shared match plan")
	_expect_has(match_keys, "victory_loot_phase_state", "shared match plan")
	_expect_not_has(match_keys, "commando_firearm_runtime", "Viper match plan")


func _verify_all_stage_plan_and_deduplication() -> void:
	var planner: Object = BattleSceneUpdatePrewarmPlan.new()
	var all_stage_keys: Array = planner.get_stage_runtime_keys(4, true)
	for expected_key in [
		"stage1_balloon_event",
		"stage2_monkey_banana_event",
		"stage3_boss_skill_state",
		"stage4_bird_event",
		"stage5_hongryun_state",
		"stage6_tetriser_state",
	]:
		_expect_has(all_stage_keys, expected_key, "all-stage plan")
	_expect(all_stage_keys.count("weather_event_state") == 1, "all-stage plan must keep common keys unique")

	var owner := FakeOwner.new()
	var match_keys: Array = planner.get_match_flow_context_keys(owner)
	_expect(match_keys.count("runtime_perk_state") == 1, "merged match plan must deduplicate repeated runtime keys")


func _verify_source_ownership() -> void:
	var planner_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_scene_update_prewarm_plan.gd"
	)
	var driver_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_scene_update_prewarm_driver.gd"
	)
	_expect(planner_source.contains("EFFECTS_VIPER_PREWARM_KEYS"), "planner must own character effects selection")
	_expect(planner_source.contains("MATCH_COMMANDO_SKILL_PREWARM_KEYS"), "planner must own character match selection")
	_expect(planner_source.contains("STAGE6_RUNTIME_PREWARM_KEYS"), "planner must own stage dependency selection")
	_expect(driver_source.contains("BattleSceneUpdatePrewarmPlan.new()"), "driver must compose the plan owner")
	_expect(driver_source.contains("_prewarm_plan.get_player_control_context_keys"), "driver must consume player dependency plans")
	_expect(driver_source.contains("_prewarm_plan.get_effects_context_keys"), "driver must consume effects dependency plans")
	_expect(driver_source.contains("_prewarm_plan.get_match_flow_context_keys"), "driver must consume match dependency plans")
	_expect(not driver_source.contains("func _get_stage_runtime_prewarm_keys"), "driver must not retain stage-key selection policy")
	_expect(not driver_source.contains("func _unique_non_empty_keys"), "driver must not retain plan deduplication policy")


func _expect_has(keys: Array, key: String, scope: String) -> void:
	_expect(keys.has(key), "%s must include %s" % [scope, key])


func _expect_not_has(keys: Array, key: String, scope: String) -> void:
	_expect(not keys.has(key), "%s must exclude %s" % [scope, key])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
