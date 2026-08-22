extends SceneTree

const BallDependencyContext := preload("res://scripts/ball/ball_dependency_context.gd")

var _failures: Array[String] = []


class FakeStageRouter:
	extends RefCounted

	func get_module_key(stage: int, role: String) -> String:
		if role != "stage_background":
			return ""
		match stage:
			2:
				return "stage2_pillar_background"
			3:
				return "stage3_pillar_background"
			4:
				return "stage4_pillar_background"
			6:
				return "stage6_tetriser_pillar_background"
		return "stage1_pillar_background"


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}
	var requested_keys: Array[String] = []

	func _init() -> void:
		for key in _get_instance_keys():
			instances[key] = RefCounted.new()
		instances["stage_runtime_router"] = FakeStageRouter.new()

	func get_instance(key: String) -> Object:
		requested_keys.append(key)
		return instances.get(key, null)

	func _get_instance_keys() -> Array[String]:
		return [
			"ball_physics",
			"ball_spin_state",
			"ball_effects",
			"ball_intensity",
			"ball_motion_stepper",
			"wall_bounce_controller",
			"paddle_bounce_state",
			"paddle_bounce_controller",
			"status_effect_state",
			"laurel_leaf_shield_state",
			"player_movement_state",
			"round_flow_state",
			"smasher_dash_state",
			"orb_hud_state",
			"impact_effects",
			"game_audio",
			"battle_feedback_state",
			"active_item_runtime",
			"mythic_item_runtime",
			"weather_event_state",
			"runtime_perk_state",
			"actor_animation_state",
			"boss_ai_state",
			"stage_runtime_router",
			"smasher_input_reader",
			"smasher_power_smash_state",
			"smasher_drive_input_state",
			"smasher_combo_state",
			"smasher_skill_state",
			"smasher_skill_config",
			"smasher_drive_bounce_state",
			"smasher_drive_counter_state",
			"smasher_drive_activation_controller",
			"smasher_power_smash_activation_controller",
			"smasher_power_smash_motion_controller",
			"smasher_magnum_grip_state",
			"smasher_recovery_state",
			"smasher_cleanse_state",
			"smasher_warp_gate_state",
			"smasher_wheel_state",
			"smasher_dash_spirit_state",
			"smasher_shield_kiting_state",
			"viper_input_reader",
			"viper_skill_runtime",
			"viper_skill_state",
			"viper_skill_config",
			"viper_jetpack_state",
			"commando_input_reader",
			"commando_skill_state",
			"commando_skill_config",
			"commando_firearm_runtime",
			"commando_supply_drop_state",
			"commando_weapon_controller",
			"commando_emergency_supply_state",
			"stage1_pillar_background",
			"stage1_dalji_whip_skill_state",
			"stage1_dalji_spinning_top_skill_state",
			"stage1_dalji_boss_skill_cooldown_state",
			"stage1_gaksital_fan_throw_skill_state",
			"stage1_gaksital_fan_wind_skill_state",
			"stage1_gaksital_boss_skill_cooldown_state",
			"stage1_pododaejang_patrol_guards_skill_state",
			"stage1_pododaejang_arrest_rope_skill_state",
			"stage1_pododaejang_boss_skill_cooldown_state",
			"stage1_balloon_event",
			"stage2_pillar_background",
			"stage2_boss_skill_state",
			"stage3_pillar_background",
			"stage3_boss_skill_state",
			"stage4_pillar_background",
			"stage4_map_state",
			"stage4_temple_destruction_event",
			"stage4_moon_event",
			"stage4_bird_event",
			"stage4_brazier_monk_event",
			"stage4_ponk_skill_state",
			"stage5_hongryun_state",
			"stage6_tetriser_state",
			"stage6_tetriser_pillar_background",
		]


func _init() -> void:
	_verify_smasher_stage1_scope()
	_verify_smasher_stage1_gaksital_scope_and_cache()
	_verify_smasher_stage1_pododaejang_scope_and_cache()
	_verify_viper_stage4_scope_and_cache()
	_verify_commando_stage2_scope()
	_verify_smasher_stage6_scope()
	_verify_legacy_update_deps_keep_stage6()

	if _failures.is_empty():
		print("ball_dependency_context_scope_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_smasher_stage1_scope() -> void:
	var registry := FakeRegistry.new()
	var deps: Dictionary = BallDependencyContext.new().build_update_deps(registry, {
		"selected_character_type": "smasher",
		"current_stage": 1,
	})
	_expect(deps.get("skill_config", null) == registry.instances["smasher_skill_config"], "Smasher scope should use Smasher skill config")
	_expect(deps.get("smasher_wheel_state", null) == registry.instances["smasher_wheel_state"], "Smasher scope should include Smasher collision states")
	_expect(deps.get("laurel_leaf_shield_state", null) == registry.instances["laurel_leaf_shield_state"], "shared Laurel shield should remain available in scoped ball deps")
	_expect(deps.get("stage_background", null) == registry.instances["stage1_pillar_background"], "Stage 1 scope should route the Stage 1 background")
	_expect(deps.get("stage1_balloon_event", null) == registry.instances["stage1_balloon_event"], "Stage 1 scope should include balloon collision event")
	_expect(deps.get("stage1_dalji_whip_skill_state", null) == registry.instances["stage1_dalji_whip_skill_state"], "Stage 1 default scope should include Dalji whip")
	_expect(not _requested(registry, "stage1_gaksital_fan_throw_skill_state"), "Stage 1 default scope should not request Gaksital fan throw")
	_expect(not _requested(registry, "viper_skill_runtime"), "Smasher scope should not request Viper runtime")
	_expect(not _requested(registry, "commando_firearm_runtime"), "Smasher scope should not request Commando firearm runtime")
	_expect(not _requested(registry, "stage2_boss_skill_state"), "Stage 1 scope should not request Stage 2 boss state")
	_expect(not _requested(registry, "stage4_map_state"), "Stage 1 scope should not request Stage 4 map state")
	_expect(not _requested(registry, "stage5_hongryun_state"), "Stage 1 scope should not request Stage 5 Hongryun state")


func _verify_smasher_stage1_gaksital_scope_and_cache() -> void:
	var registry := FakeRegistry.new()
	var builder: Object = BallDependencyContext.new()
	var dalji_scope := {
		"selected_character_type": "smasher",
		"current_stage": 1,
		"stage1_boss_variant": "dalji",
	}
	builder.build_update_deps(registry, dalji_scope)
	registry.requested_keys.clear()
	var gaksital_deps: Dictionary = builder.build_update_deps(registry, {
		"selected_character_type": "smasher",
		"current_stage": 1,
		"stage1_boss_variant": "gaksi",
	})
	_expect(deps_has(gaksital_deps, registry, "stage1_gaksital_fan_throw_skill_state"), "Gaksital scope should include fan throw state")
	_expect(deps_has(gaksital_deps, registry, "stage1_gaksital_fan_wind_skill_state"), "Gaksital scope should include fan wind state")
	_expect(deps_has(gaksital_deps, registry, "stage1_gaksital_boss_skill_cooldown_state"), "Gaksital scope should include fan throw cooldown state")
	_expect(deps_has(gaksital_deps, registry, "stage1_balloon_event"), "Gaksital scope should keep Stage 1 balloon event")
	_expect(not gaksital_deps.has("stage1_dalji_whip_skill_state"), "Gaksital scope should omit Dalji whip")
	_expect(not gaksital_deps.has("stage1_dalji_spinning_top_skill_state"), "Gaksital scope should omit Dalji spinning top")
	_expect(_requested(registry, "stage1_gaksital_fan_throw_skill_state"), "Stage 1 boss variant must be part of the ball deps cache key")


func _verify_smasher_stage1_pododaejang_scope_and_cache() -> void:
	var registry := FakeRegistry.new()
	var builder: Object = BallDependencyContext.new()
	builder.build_update_deps(registry, {
		"selected_character_type": "smasher",
		"current_stage": 1,
		"stage1_boss_variant": "dalji",
	})
	registry.requested_keys.clear()
	var podo_deps: Dictionary = builder.build_update_deps(registry, {
		"selected_character_type": "smasher",
		"current_stage": 1,
		"stage1_boss_variant": "pododaejang",
	})
	_expect(deps_has(podo_deps, registry, "stage1_balloon_event"), "Pododaejang scope should keep Stage 1 balloon event")
	_expect(podo_deps.get("stage1_boss_variant", "") == "podo", "Pododaejang scope should normalize the boss variant")
	_expect(deps_has(podo_deps, registry, "stage1_pododaejang_patrol_guards_skill_state"), "Pododaejang scope should include patrol guards")
	_expect(deps_has(podo_deps, registry, "stage1_pododaejang_arrest_rope_skill_state"), "Pododaejang scope should include arrest rope")
	_expect(deps_has(podo_deps, registry, "stage1_pododaejang_boss_skill_cooldown_state"), "Pododaejang scope should include boss cooldown state")
	_expect(not podo_deps.has("stage1_dalji_whip_skill_state"), "Pododaejang scope should omit Dalji whip")
	_expect(not podo_deps.has("stage1_dalji_spinning_top_skill_state"), "Pododaejang scope should omit Dalji spinning top")
	_expect(not podo_deps.has("stage1_dalji_boss_skill_cooldown_state"), "Pododaejang scope should omit Dalji cooldown state")
	_expect(not podo_deps.has("stage1_gaksital_fan_throw_skill_state"), "Pododaejang scope should omit Gaksital fan throw")
	_expect(not podo_deps.has("stage1_gaksital_fan_wind_skill_state"), "Pododaejang scope should omit Gaksital fan wind")
	_expect(not podo_deps.has("stage1_gaksital_boss_skill_cooldown_state"), "Pododaejang scope should omit Gaksital cooldown state")
	_expect(_requested(registry, "stage1_balloon_event"), "Pododaejang variant must break the Stage 1 ball deps cache key")
	_expect(_requested(registry, "stage1_pododaejang_patrol_guards_skill_state"), "Pododaejang variant must request its combat modules")
	_expect(not _requested(registry, "stage1_dalji_whip_skill_state"), "Pododaejang scope should not request Dalji modules")
	_expect(not _requested(registry, "stage1_gaksital_fan_throw_skill_state"), "Pododaejang scope should not request Gaksital modules")


func _verify_viper_stage4_scope_and_cache() -> void:
	var registry := FakeRegistry.new()
	var builder: Object = BallDependencyContext.new()
	var scope := {
		"selected_character_type": "viper",
		"current_stage": 4,
	}
	var deps: Dictionary = builder.build_update_deps(registry, scope)
	_expect(deps.get("skill_config", null) == registry.instances["viper_skill_config"], "Viper scope should use Viper skill config as the generic skill config")
	_expect(deps.get("viper_skill_runtime", null) == registry.instances["viper_skill_runtime"], "Viper scope should include Viper runtime")
	_expect(deps.get("stage_background", null) == registry.instances["stage4_pillar_background"], "Stage 4 scope should route the Stage 4 background")
	_expect(deps.get("stage4_ponk_skill_state", null) == registry.instances["stage4_ponk_skill_state"], "Stage 4 scope should include Ponk ball state")
	_expect(not _requested(registry, "smasher_wheel_state"), "Viper scope should not request Smasher wheel state")
	_expect(not _requested(registry, "commando_firearm_runtime"), "Viper scope should not request Commando firearm runtime")
	_expect(not _requested(registry, "stage2_pillar_background"), "Stage 4 scope should not request Stage 2 background")
	_expect(not _requested(registry, "stage5_hongryun_state"), "Stage 4 scope should not request Stage 5 Hongryun state")

	registry.requested_keys.clear()
	var cached_deps: Dictionary = builder.build_update_deps(registry, scope)
	_expect(registry.requested_keys.is_empty(), "same character/stage ball deps should be served from cache")
	cached_deps["viper_skill_runtime"] = null
	var cached_again: Dictionary = builder.build_update_deps(registry, scope)
	_expect(cached_again.get("viper_skill_runtime", null) == registry.instances["viper_skill_runtime"], "cached deps should be returned as a fresh top-level dictionary")


func _verify_commando_stage2_scope() -> void:
	var registry := FakeRegistry.new()
	var deps: Dictionary = BallDependencyContext.new().build_update_deps(registry, {
		"selected_character_type": "commando",
		"current_stage": 2,
	})
	_expect(deps.get("skill_config", null) == registry.instances["commando_skill_config"], "Commando alias should use Commando skill config")
	_expect(deps.get("commando_firearm_runtime", null) == registry.instances["commando_firearm_runtime"], "Commando scope should include firearm runtime")
	_expect(deps.get("commando_supply_drop_state", null) == registry.instances["commando_supply_drop_state"], "Commando scope should include supply-drop state")
	_expect(deps.get("stage_background", null) == registry.instances["stage2_pillar_background"], "Stage 2 scope should route the Stage 2 background")
	_expect(deps.get("stage2_boss_skill_state", null) == registry.instances["stage2_boss_skill_state"], "Stage 2 scope should include boss skill state")
	_expect(not _requested(registry, "viper_skill_runtime"), "Commando scope should not request Viper runtime")
	_expect(not _requested(registry, "smasher_wheel_state"), "Commando scope should not request Smasher wheel state")
	_expect(not _requested(registry, "stage4_ponk_skill_state"), "Stage 2 scope should not request Stage 4 boss skill state")
	_expect(not _requested(registry, "stage5_hongryun_state"), "Stage 2 scope should not request Stage 5 Hongryun state")


func _verify_smasher_stage6_scope() -> void:
	var registry := FakeRegistry.new()
	var deps: Dictionary = BallDependencyContext.new().build_update_deps(registry, {
		"selected_character_type": "smasher",
		"current_stage": 6,
	})
	_expect(deps.get("stage6_tetriser_state", null) == registry.instances["stage6_tetriser_state"], "Stage 6 scope should include Tetriser collision state")
	_expect(deps.get("stage_background", null) == registry.instances["stage6_tetriser_pillar_background"], "Stage 6 scope should route the Stage 6 background")
	_expect(not _requested(registry, "stage5_hongryun_state"), "Stage 6 scope should not request Stage 5 Hongryun state")
	_expect(not _requested(registry, "stage4_ponk_skill_state"), "Stage 6 scope should not request Stage 4 boss skill state")


func _verify_legacy_update_deps_keep_stage6() -> void:
	var registry := FakeRegistry.new()
	var deps: Dictionary = BallDependencyContext.new().build_update_deps(registry)
	_expect(deps.get("stage6_tetriser_state", null) == registry.instances["stage6_tetriser_state"], "legacy ball update deps should include Stage 6 Tetriser state")


func _requested(registry: FakeRegistry, key: String) -> bool:
	return registry.requested_keys.has(key)


func deps_has(deps: Dictionary, registry: FakeRegistry, key: String) -> bool:
	return deps.get(key, null) == registry.instances[key]


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
