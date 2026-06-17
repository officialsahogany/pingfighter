extends SceneTree

const EffectsDepsBuilder := preload("res://scripts/core/battle_update_effects_deps_builder.gd")
const BattleUpdateEffectsContext := preload("res://scripts/core/battle_update_effects_context.gd")

var _failures: Array[String] = []


class FakeStageRouter:
	extends RefCounted

	func get_instance(registry: Object, current_stage: int, role: String) -> Object:
		if current_stage == 2 and role == "stage_background":
			return registry.get_instance("stage2_pillar_background")
		return null


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}
	var requested_keys: Array[String] = []

	func _init() -> void:
		for key in [
			"battle_feedback_state",
			"game_audio",
			"match_score_state",
			"scoreboard_state",
			"smasher_power_smash_state",
			"smasher_plasma_state",
			"smasher_recovery_state",
			"smasher_cleanse_state",
			"smasher_warp_gate_state",
			"smasher_wheel_state",
			"smasher_magnum_grip_state",
			"smasher_dash_spirit_state",
			"smasher_shield_kiting_state",
			"viper_skill_runtime",
			"viper_jetpack_state",
			"viper_skill_config",
			"viper_skill_state",
			"commando_firearm_runtime",
			"commando_reload_delivery_state",
			"monkey_blessing_delivery_state",
			"smasher_combo_state",
			"stage1_pillar_background",
			"stage2_pillar_background",
			"orb_hud_state",
			"actor_animation_state",
			"impact_effects",
			"player_movement_state",
			"active_item_runtime",
			"runtime_perk_state",
			"runtime_perk_catalog",
			"weather_event_state",
			"stage1_dalji_whip_skill_state",
			"stage1_dalji_spinning_top_skill_state",
			"stage1_dalji_boss_skill_cooldown_state",
			"stage1_balloon_event",
			"stage2_boss_skill_state",
			"stage2_monkey_banana_event",
			"stage3_boss_skill_state",
			"stage4_map_state",
			"stage4_temple_destruction_event",
			"stage4_moon_event",
			"stage4_bird_event",
			"stage4_brazier_monk_event",
			"stage4_ponk_skill_state",
			"stage5_hongryun_state",
		]:
			instances[key] = RefCounted.new()
		instances["stage_runtime_router"] = FakeStageRouter.new()

	func get_instance(key: String) -> Object:
		requested_keys.append(key)
		return instances.get(key, null)


func _init() -> void:
	var registry := FakeRegistry.new()
	var builder: Object = EffectsDepsBuilder.new()

	_verify_deps(builder.build_deps(registry, 2), registry, "direct builder")
	_verify_deps(BattleUpdateEffectsContext.new().build_deps(registry, 2), registry, "effects context facade")
	_verify_scoped_cache_deps()

	var fallback_deps: Dictionary = builder.build_deps(registry, 1)
	_expect(
		fallback_deps.get("stage_background", null) == registry.instances["stage1_pillar_background"],
		"effects deps should fall back to Stage 1 background when stage router does not route"
	)

	var null_deps: Dictionary = builder.build_deps(null, 2)
	_expect(null_deps.get("feedback", RefCounted.new()) == null, "null registry should produce null feedback")
	_expect(null_deps.get("stage_background", RefCounted.new()) == null, "null registry should produce null stage background")

	if _failures.is_empty():
		print("effects_deps_builder_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_deps(deps: Dictionary, registry: FakeRegistry, source: String) -> void:
	var dep_to_registry_key := {
		"feedback": "battle_feedback_state",
		"audio": "game_audio",
		"score_state": "match_score_state",
		"scoreboard_state": "scoreboard_state",
		"power_state": "smasher_power_smash_state",
		"smasher_plasma_state": "smasher_plasma_state",
		"smasher_recovery_state": "smasher_recovery_state",
		"smasher_cleanse_state": "smasher_cleanse_state",
		"smasher_warp_gate_state": "smasher_warp_gate_state",
		"smasher_wheel_state": "smasher_wheel_state",
		"smasher_magnum_grip_state": "smasher_magnum_grip_state",
		"smasher_dash_spirit_state": "smasher_dash_spirit_state",
		"smasher_shield_kiting_state": "smasher_shield_kiting_state",
		"viper_skill_runtime": "viper_skill_runtime",
		"viper_jetpack_state": "viper_jetpack_state",
		"viper_skill_config": "viper_skill_config",
		"viper_skill_state": "viper_skill_state",
		"commando_firearm_runtime": "commando_firearm_runtime",
		"commando_reload_delivery_state": "commando_reload_delivery_state",
		"monkey_blessing_delivery_state": "monkey_blessing_delivery_state",
		"combo_state": "smasher_combo_state",
		"stage_background": "stage2_pillar_background",
		"orb_hud_state": "orb_hud_state",
		"animation_state": "actor_animation_state",
		"impact_effects": "impact_effects",
		"movement_state": "player_movement_state",
		"active_item_runtime": "active_item_runtime",
		"runtime_perk_state": "runtime_perk_state",
		"runtime_perk_catalog": "runtime_perk_catalog",
		"weather_event_state": "weather_event_state",
		"stage2_boss_skill_state": "stage2_boss_skill_state",
		"stage2_monkey_banana_event": "stage2_monkey_banana_event",
	}
	for dep_key in dep_to_registry_key.keys():
		var registry_key: String = str(dep_to_registry_key[dep_key])
		_expect(
			deps.get(dep_key, null) == registry.instances[registry_key],
			"%s should include %s from %s" % [source, dep_key, registry_key]
		)
	for inactive_key in [
		"stage1_dalji_whip_skill_state",
		"stage1_dalji_spinning_top_skill_state",
		"stage1_dalji_boss_skill_cooldown_state",
		"stage1_balloon_event",
		"stage3_boss_skill_state",
		"stage4_map_state",
		"stage4_temple_destruction_event",
		"stage4_moon_event",
		"stage4_bird_event",
		"stage4_brazier_monk_event",
		"stage4_ponk_skill_state",
		"stage5_hongryun_state",
	]:
		_expect(not deps.has(inactive_key), "%s should omit inactive stage dep %s" % [source, inactive_key])


func _verify_scoped_cache_deps() -> void:
	var registry := FakeRegistry.new()
	var builder: Object = EffectsDepsBuilder.new()
	var viper_deps: Dictionary = builder.build_deps(registry, 2, "viper")
	_expect(viper_deps.get("viper_skill_runtime", null) == registry.instances["viper_skill_runtime"], "scoped effects deps should include Viper runtime")
	_expect(viper_deps.get("commando_reload_delivery_state", null) == registry.instances["commando_reload_delivery_state"], "scoped effects deps should keep shared Commando reload delivery cleanup state")
	_expect(viper_deps.get("stage_background", null) == registry.instances["stage2_pillar_background"], "scoped effects deps should still include routed stage background")
	_expect(viper_deps.get("stage2_boss_skill_state", null) == registry.instances["stage2_boss_skill_state"], "scoped effects deps should include current Stage 2 runtime")
	_expect(not viper_deps.has("power_state"), "scoped effects deps should not expose Smasher power state for Viper")
	_expect(not viper_deps.has("stage1_balloon_event"), "scoped effects deps should not expose Stage 1 event on Stage 2")
	_expect(not registry.requested_keys.has("smasher_wheel_state"), "scoped effects deps should not request Smasher wheel state for Viper")
	_expect(not registry.requested_keys.has("commando_firearm_runtime"), "scoped effects deps should not request Commando runtime for Viper")
	_expect(not registry.requested_keys.has("stage4_map_state"), "scoped effects deps should not request Stage 4 map state on Stage 2")
	_expect(not registry.requested_keys.has("stage5_hongryun_state"), "scoped effects deps should not request Stage 5 Hongryun state on Stage 2")

	registry.requested_keys.clear()
	var cached_deps: Dictionary = builder.build_deps(registry, 2, "viper")
	_expect(registry.requested_keys.is_empty(), "same effects deps stage/character should be served from cache")
	cached_deps["viper_skill_runtime"] = null
	var cached_again: Dictionary = builder.build_deps(registry, 2, "viper")
	_expect(cached_again.get("viper_skill_runtime", null) == registry.instances["viper_skill_runtime"], "cached effects deps should be returned as a fresh top-level dictionary")

	var commando_deps: Dictionary = builder.build_deps(registry, 2, "soldier")
	_expect(commando_deps.get("commando_firearm_runtime", null) == registry.instances["commando_firearm_runtime"], "changing character should rebuild scoped effects deps")
	_expect(commando_deps.get("commando_reload_delivery_state", null) == registry.instances["commando_reload_delivery_state"], "scoped Commando effects deps should include reload delivery state")
	_expect(not commando_deps.has("viper_skill_runtime"), "scoped Commando effects deps should not expose Viper runtime")

	registry.requested_keys.clear()
	var commando_alias_deps: Dictionary = builder.build_deps(registry, 2, " Commando ")
	_expect(registry.requested_keys.is_empty(), "normalized Commando aliases should reuse the Soldier scoped effects deps cache")
	_expect(commando_alias_deps.get("commando_firearm_runtime", null) == registry.instances["commando_firearm_runtime"], "cached Commando alias deps should keep firearm runtime")

	var legacy_builder: Object = EffectsDepsBuilder.new()
	var legacy_registry := FakeRegistry.new()
	var legacy_deps: Dictionary = legacy_builder.build_deps(legacy_registry, 2, "")
	_expect(legacy_deps.has("viper_skill_runtime") and legacy_deps.has("commando_firearm_runtime"), "blank character deps should keep the legacy all-character dependency set")
	legacy_registry.requested_keys.clear()
	var smasher_deps: Dictionary = legacy_builder.build_deps(legacy_registry, 2, " Smasher ")
	_expect(not legacy_registry.requested_keys.is_empty(), "scoped Smasher deps must not reuse the blank legacy cache")
	_expect(not smasher_deps.has("viper_skill_runtime") and not smasher_deps.has("commando_firearm_runtime"), "scoped Smasher deps should stay narrower than blank legacy deps")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
