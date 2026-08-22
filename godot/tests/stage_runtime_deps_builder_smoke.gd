extends SceneTree

const StageRuntimeDepsBuilder := preload("res://scripts/core/battle_update_stage_runtime_deps_builder.gd")
const BattleUpdateEffectsContext := preload("res://scripts/core/battle_update_effects_context.gd")
const BattleUpdateMatchFlowContext := preload("res://scripts/core/battle_update_match_flow_context.gd")
const MatchStageRuntimeDepsBuilder := preload("res://scripts/core/battle_update_match_stage_runtime_deps_builder.gd")
const MatchResetController := preload("res://scripts/core/match_reset_controller.gd")

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
			"stage1_gaksital_fan_throw_skill_state",
			"stage1_gaksital_fan_wind_skill_state",
			"stage1_gaksital_boss_skill_cooldown_state",
			"stage1_pododaejang_patrol_guards_skill_state",
			"stage1_pododaejang_arrest_rope_skill_state",
			"stage1_pododaejang_boss_skill_cooldown_state",
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
			"stage6_tetriser_state",
			"stage1_pillar_background",
			"stage2_pillar_background",
			"stage5_hongryun_pillar_background",
		]:
			instances[key] = RefCounted.new()
		instances["stage_runtime_router"] = FakeStageRouter.new()

	func get_instance(key: String) -> Object:
		requested_keys.append(key)
		return instances.get(key, null)


class FakeResettable:
	extends RefCounted

	var reset_count := 0

	func reset() -> void:
		reset_count += 1


# Models the real registry's lazy semantics: get_instance() COLD-CREATES a
# missing module, get_cached_instance() peeks and never creates.
class FakeLazyRegistry:
	extends RefCounted

	var instances: Dictionary = {}
	var cold_created_keys: Array[String] = []
	var peeked_keys: Array[String] = []

	func get_instance(key: String) -> Object:
		if not instances.has(key):
			cold_created_keys.append(key)
			instances[key] = RefCounted.new()
		return instances[key]

	func get_cached_instance(key: String) -> Object:
		peeked_keys.append(key)
		return instances.get(key, null)


func _init() -> void:
	var registry := FakeRegistry.new()
	var builder: Object = StageRuntimeDepsBuilder.new()

	_verify_scoped_stage2_deps(builder.build_deps(registry, 2), registry, "shared builder")
	_expect(not registry.requested_keys.has("stage1_balloon_event"), "scoped shared builder should not request Stage 1 event on Stage 2")
	_expect(not registry.requested_keys.has("stage4_map_state"), "scoped shared builder should not request Stage 4 state on Stage 2")
	_verify_scoped_stage5_deps(builder.build_deps(registry, 5), registry, "shared builder")
	_verify_scoped_stage1_gaksital_deps(builder.build_deps(registry, 1, false, "gaksi"), registry, "shared builder")
	_verify_scoped_stage1_pododaejang_deps(builder.build_deps(registry, 1, false, "pododaejang"), registry, "shared builder")

	_verify_all_stage_deps(builder.build_deps(registry, 2, true), registry, "shared builder include-all")
	_verify_all_stage_deps(MatchStageRuntimeDepsBuilder.new().build_deps(registry, 2), registry, "match-stage facade")
	_verify_scoped_stage2_deps(BattleUpdateEffectsContext.new().build_deps(registry, 2), registry, "effects context facade")
	_verify_all_stage_deps(BattleUpdateMatchFlowContext.new().build_deps(registry, 2), registry, "match flow context facade")

	var fallback_deps: Dictionary = builder.build_deps(registry, 99)
	_expect(
		fallback_deps.get("stage_background", null) == registry.instances["stage1_pillar_background"],
		"shared stage runtime deps should fall back to Stage 1 background"
	)
	_expect(registry.requested_keys.has("stage_runtime_router"), "shared stage runtime deps should query stage router")

	var null_deps: Dictionary = builder.build_deps(null, 2)
	_expect(null_deps.get("stage_background", RefCounted.new()) == null, "null registry should produce null stage background")
	_expect(null_deps.get("stage2_boss_skill_state", RefCounted.new()) == null, "null registry should produce null Stage 2 skill state")

	_verify_include_all_never_cold_instantiates(builder)
	_verify_existing_modules_still_reach_reset()

	if _failures.is_empty():
		print("stage_runtime_deps_builder_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_scoped_stage2_deps(deps: Dictionary, registry: FakeRegistry, source: String) -> void:
	for key in [
		"weather_event_state",
		"stage2_boss_skill_state",
		"stage2_monkey_banana_event",
	]:
		_expect(deps.get(key, null) == registry.instances[key], "%s should include %s" % [source, key])
	for inactive_key in [
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
		"stage3_boss_skill_state",
		"stage4_map_state",
		"stage4_temple_destruction_event",
		"stage4_moon_event",
		"stage4_bird_event",
		"stage4_brazier_monk_event",
		"stage4_ponk_skill_state",
		"stage5_hongryun_state",
		"stage5_hongryun_fire_machine_event",
		"stage6_tetriser_state",
	]:
		_expect(not deps.has(inactive_key), "%s should omit inactive stage dep %s" % [source, inactive_key])
	_expect(
		deps.get("stage_background", null) == registry.instances["stage2_pillar_background"],
		"%s should use routed Stage 2 background" % source
	)


func _verify_scoped_stage5_deps(deps: Dictionary, registry: FakeRegistry, source: String) -> void:
	for key in [
		"weather_event_state",
		"stage5_hongryun_state",
		"stage5_hongryun_fire_machine_event",
	]:
		_expect(deps.get(key, null) == registry.instances[key], "%s should include %s" % [source, key])
	for inactive_key in [
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
		"stage2_boss_skill_state",
		"stage2_monkey_banana_event",
		"stage3_boss_skill_state",
		"stage4_map_state",
		"stage4_temple_destruction_event",
		"stage4_moon_event",
		"stage4_bird_event",
		"stage4_brazier_monk_event",
		"stage4_ponk_skill_state",
		"stage6_tetriser_state",
	]:
		_expect(not deps.has(inactive_key), "%s should omit inactive stage dep %s" % [source, inactive_key])
	_expect(
		deps.get("stage_background", null) == registry.instances["stage5_hongryun_pillar_background"],
		"%s should use routed Stage 5 Hongryun background" % source
	)


func _verify_all_stage_deps(deps: Dictionary, registry: FakeRegistry, source: String) -> void:
	for key in [
		"weather_event_state",
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
		"stage6_tetriser_state",
	]:
		_expect(deps.get(key, null) == registry.instances[key], "%s should include %s" % [source, key])
	_expect(
		deps.get("stage_background", null) == registry.instances["stage2_pillar_background"],
		"%s should use routed Stage 2 background" % source
	)


func _verify_scoped_stage1_gaksital_deps(deps: Dictionary, registry: FakeRegistry, source: String) -> void:
	for key in [
		"weather_event_state",
		"stage1_gaksital_fan_throw_skill_state",
		"stage1_gaksital_fan_wind_skill_state",
		"stage1_gaksital_boss_skill_cooldown_state",
		"stage1_balloon_event",
	]:
		_expect(deps.get(key, null) == registry.instances[key], "%s should include %s for Gaksital" % [source, key])
	for inactive_key in [
		"stage1_dalji_whip_skill_state",
		"stage1_dalji_spinning_top_skill_state",
		"stage1_dalji_boss_skill_cooldown_state",
		"stage1_pododaejang_patrol_guards_skill_state",
		"stage1_pododaejang_arrest_rope_skill_state",
		"stage1_pododaejang_boss_skill_cooldown_state",
		"stage2_boss_skill_state",
		"stage4_map_state",
		"stage5_hongryun_state",
	]:
		_expect(not deps.has(inactive_key), "%s should omit inactive Gaksital stage dep %s" % [source, inactive_key])


func _verify_scoped_stage1_pododaejang_deps(deps: Dictionary, registry: FakeRegistry, source: String) -> void:
	for key in [
		"weather_event_state",
		"stage1_pododaejang_patrol_guards_skill_state",
		"stage1_pododaejang_arrest_rope_skill_state",
		"stage1_pododaejang_boss_skill_cooldown_state",
		"stage1_balloon_event",
	]:
		_expect(deps.get(key, null) == registry.instances[key], "%s should include %s for Pododaejang" % [source, key])
	for inactive_key in [
		"stage1_dalji_whip_skill_state",
		"stage1_dalji_spinning_top_skill_state",
		"stage1_dalji_boss_skill_cooldown_state",
		"stage1_gaksital_fan_throw_skill_state",
		"stage1_gaksital_fan_wind_skill_state",
		"stage1_gaksital_boss_skill_cooldown_state",
		"stage2_boss_skill_state",
		"stage4_map_state",
		"stage5_hongryun_state",
	]:
		_expect(not deps.has(inactive_key), "%s should omit inactive Pododaejang stage dep %s" % [source, inactive_key])


# Contract: the include-all (reset / transition / round-restart) path must
# never cold-instantiate a stage module. A stage-1 match end used to lazily
# create every other stage's state through get_instance (370ms stall).
func _verify_include_all_never_cold_instantiates(builder: Object) -> void:
	var registry := FakeLazyRegistry.new()
	for key in [
		"weather_event_state",
		"stage_runtime_router",
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
	]:
		registry.instances[key] = RefCounted.new()
	registry.cold_created_keys.clear()

	var deps: Dictionary = builder.build_deps(registry, 1, true)
	_expect(
		registry.cold_created_keys.is_empty(),
		"include-all deps build must not cold-instantiate any module (created: %s)" % str(registry.cold_created_keys)
	)
	_expect(not registry.peeked_keys.is_empty(), "include-all deps build should use the cached-instance peek")
	_expect(
		deps.get("stage1_balloon_event", null) == registry.instances["stage1_balloon_event"],
		"already-created stage1 module should still land in include-all deps"
	)
	for missing_key in ["stage2_boss_skill_state", "stage4_map_state", "stage5_hongryun_state", "stage6_tetriser_state"]:
		_expect(deps.get(missing_key, RefCounted.new()) == null, "never-created %s should stay null in include-all deps" % missing_key)

	var facade_registry := FakeLazyRegistry.new()
	facade_registry.instances["weather_event_state"] = RefCounted.new()
	facade_registry.instances["stage_runtime_router"] = RefCounted.new()
	facade_registry.instances["stage1_pillar_background"] = RefCounted.new()
	facade_registry.cold_created_keys.clear()
	var facade_deps: Dictionary = MatchStageRuntimeDepsBuilder.new().build_deps(facade_registry, 1, true)
	_expect(
		not facade_registry.cold_created_keys.has("stage5_hongryun_actor_renderer"),
		"match-stage facade include-all path must not cold-instantiate the hongryun actor renderer"
	)
	_expect(
		facade_deps.get("stage5_hongryun_actor_renderer", RefCounted.new()) == null,
		"never-created hongryun actor renderer should stay null in include-all deps"
	)


# Contract: modules that DO exist keep flowing through the include-all deps
# into the real reset, so the cross-stage leak-reset invariant is preserved.
func _verify_existing_modules_still_reach_reset() -> void:
	var registry := FakeLazyRegistry.new()
	registry.instances["weather_event_state"] = FakeResettable.new()
	registry.instances["stage_runtime_router"] = RefCounted.new()
	registry.instances["stage1_pillar_background"] = RefCounted.new()
	var stage4_map := FakeResettable.new()
	var stage5_hongryun := FakeResettable.new()
	var stage6_tetriser := FakeResettable.new()
	registry.instances["stage4_map_state"] = stage4_map
	registry.instances["stage5_hongryun_state"] = stage5_hongryun
	registry.instances["stage6_tetriser_state"] = stage6_tetriser
	registry.cold_created_keys.clear()

	var deps: Dictionary = StageRuntimeDepsBuilder.new().build_deps(registry, 1, true)
	_expect(deps.get("stage4_map_state", null) == stage4_map, "pre-created stage4 map state should be included in include-all deps")
	_expect(deps.get("stage5_hongryun_state", null) == stage5_hongryun, "pre-created stage5 hongryun state should be included in include-all deps")
	_expect(deps.get("stage6_tetriser_state", null) == stage6_tetriser, "pre-created stage6 tetriser state should be included in include-all deps")

	MatchResetController.new().reset_stage_state(deps)
	_expect(stage4_map.reset_count == 1, "pre-created stage4 map state should be reset exactly once (got %d)" % stage4_map.reset_count)
	_expect(stage5_hongryun.reset_count == 1, "pre-created stage5 hongryun state should be reset exactly once (got %d)" % stage5_hongryun.reset_count)
	_expect(stage6_tetriser.reset_count == 1, "pre-created stage6 tetriser state should be reset exactly once (got %d)" % stage6_tetriser.reset_count)
	_expect(registry.cold_created_keys.is_empty(), "reset flow must not cold-instantiate modules (created: %s)" % str(registry.cold_created_keys))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
