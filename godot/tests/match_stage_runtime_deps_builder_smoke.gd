extends SceneTree

const MatchStageRuntimeDepsBuilder := preload("res://scripts/core/battle_update_match_stage_runtime_deps_builder.gd")
const BattleUpdateMatchFlowContext := preload("res://scripts/core/battle_update_match_flow_context.gd")
const BattleUpdateMatchFlowDepsGroups := preload("res://scripts/core/battle_update_match_flow_deps_groups.gd")

var _failures: Array[String] = []


class FakeStageRouter:
	extends RefCounted

	func get_instance(registry: Object, current_stage: int, role: String) -> Object:
		if current_stage == 2 and role == "stage_background":
			return registry.get_instance("stage2_pillar_background")
		if current_stage == 5 and role == "stage_background":
			return registry.get_instance("stage5_hongryun_pillar_background")
		return null


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}
	var requested_keys: Array[String] = []

	func _init() -> void:
		for key in [
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
			"stage5_hongryun_fire_machine_event",
			"stage5_hongryun_actor_renderer",
			"stage1_pillar_background",
			"stage2_pillar_background",
			"stage5_hongryun_pillar_background",
		]:
			instances[key] = RefCounted.new()
		instances["stage_runtime_router"] = FakeStageRouter.new()

	func get_instance(key: String) -> Object:
		requested_keys.append(key)
		return instances.get(key, null)


func _init() -> void:
	var registry := FakeRegistry.new()
	var builder: Object = MatchStageRuntimeDepsBuilder.new()

	_verify_stage_deps(builder.build_deps(registry, 2), registry, "direct builder")
	_verify_stage_deps(BattleUpdateMatchFlowDepsGroups.new().build_stage_runtime_deps(registry, 2), registry, "deps groups facade")

	var match_flow_deps: Dictionary = BattleUpdateMatchFlowContext.new().build_deps(registry, 2)
	_verify_stage_deps(match_flow_deps, registry, "match flow context facade")

	var fallback_deps: Dictionary = builder.build_deps(registry, 99)
	_expect(
		fallback_deps.get("stage_background", null) == registry.instances["stage1_pillar_background"],
		"stage runtime deps should fall back to Stage 1 background"
	)
	_expect(registry.requested_keys.has("stage_runtime_router"), "stage runtime deps should query stage router")

	var null_deps: Dictionary = builder.build_deps(null, 2)
	_expect(null_deps.get("stage_background", RefCounted.new()) == null, "null registry should produce null stage background")
	_expect(null_deps.get("stage2_boss_skill_state", RefCounted.new()) == null, "null registry should produce null Stage 2 skill state")

	if _failures.is_empty():
		print("match_stage_runtime_deps_builder_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_stage_deps(deps: Dictionary, registry: FakeRegistry, source: String) -> void:
	for key in [
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
		"stage5_hongryun_fire_machine_event",
		"stage5_hongryun_actor_renderer",
	]:
		_expect(deps.get(key, null) == registry.instances[key], "%s should include %s" % [source, key])
	_expect(
		deps.get("stage_background", null) == registry.instances["stage2_pillar_background"],
		"%s should use routed Stage 2 background" % source
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
