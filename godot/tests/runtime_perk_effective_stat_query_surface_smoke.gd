extends SceneTree

const RuntimePerkEffectiveLevels := preload("res://scripts/characters/runtime_perk_effective_levels.gd")
const RuntimePerkEffectiveStatQuerySurface := preload("res://scripts/characters/runtime_perk_effective_stat_query_surface.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


class FakeRuntimeState:
	extends RefCounted

	var _effective_levels: Object = null
	var runtime_skill_levels: Dictionary = {}
	var item_perk_level_bonus := 0
	var viper_ignition_aura_active := false

	func _get_instance(registry: Object, key: String) -> Object:
		if registry != null and registry.has_method("get_instance"):
			return registry.get_instance(key)
		return null


class FakeMythicRuntime:
	extends RefCounted

	func get_sacred_laurel_leaf_bonus() -> int:
		return 3


class FakeRegistry:
	extends RefCounted

	var mythic_item_runtime := FakeMythicRuntime.new()

	func get_instance(key: String) -> Object:
		if key == "mythic_item_runtime":
			return mythic_item_runtime
		return null


func _init() -> void:
	_verify_surface_projects_runtime_state()
	_verify_surface_fallbacks()
	_verify_runtime_state_facade_stat_queries()
	_verify_runtime_state_facade_laurel_lookup()
	_verify_state_wrappers_delegate_to_surface()
	_verify_source_contract()

	if _failures.is_empty():
		print("runtime_perk_effective_stat_query_surface_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_surface_projects_runtime_state() -> void:
	var surface: Object = RuntimePerkEffectiveStatQuerySurface.new()
	var effective_levels: Object = RuntimePerkEffectiveLevels.new()
	var state := FakeRuntimeState.new()
	state.runtime_skill_levels = {
		"item_caffeine": 3,
		"common_training": 1,
		"perk_laurel_shield": 2,
	}
	state.item_perk_level_bonus = 1
	state.viper_ignition_aura_active = true

	_expect_close(
		surface.get_active_item_duration_frames(effective_levels, state, 600.0),
		1680.0,
		"query surface should project runtime state into Lv.6+ active-item duration math"
	)
	_expect_close(
		surface.get_player_skill_cooldown_seconds(effective_levels, state, 10.0),
		6.8,
		"query surface should project runtime state into cooldown reduction math"
	)
	_expect(
		surface.get_laurel_leaf_count(effective_levels, state, FakeRegistry.new(), Callable(self, "_get_instance")) == 8,
		"query surface should stack effective Laurel level with Sacred Laurel registry bonus"
	)


func _verify_surface_fallbacks() -> void:
	var surface: Object = RuntimePerkEffectiveStatQuerySurface.new()
	var state := FakeRuntimeState.new()
	_expect_close(surface.get_player_speed_multiplier(null, state), 1.0, "query surface should keep neutral speed fallback without effective helper")
	_expect(surface.get_laurel_leaf_count(null, state, FakeRegistry.new(), Callable(self, "_get_instance")) == 3, "query surface should still expose Sacred Laurel fallback without effective helper")
	_expect(surface.get_effective_runtime_skill_levels(null, state).is_empty(), "query surface should return empty effective-level fallback")


func _verify_runtime_state_facade_stat_queries() -> void:
	var surface: Object = RuntimePerkEffectiveStatQuerySurface.new()
	var state := FakeRuntimeState.new()
	state._effective_levels = RuntimePerkEffectiveLevels.new()
	state.runtime_skill_levels = {
		"item_caffeine": 3,
		"common_training": 1,
		"dash_acceleration": 2,
	}
	state.item_perk_level_bonus = 1
	state.viper_ignition_aura_active = true

	_expect(
		surface.get_runtime_skill_level_from_runtime_state(state, "item_caffeine") == 6,
		"runtime-state facade should project item perk level bonus into runtime level reads"
	)
	_expect_close(
		surface.get_active_item_duration_frames_from_runtime_state(state, 600.0),
		1680.0,
		"runtime-state facade should project active-item duration math"
	)
	_expect_close(
		surface.get_player_skill_cooldown_seconds_from_runtime_state(state, 10.0),
		6.8,
		"runtime-state facade should project cooldown math"
	)
	_expect(
		surface.get_dash_acceleration_level_from_runtime_state(state) == 5,
		"runtime-state facade should project dash acceleration level"
	)
	_expect(
		surface.get_viper_ignition_aura_level_bonus_from_runtime_state(state) == 2,
		"runtime-state facade should expose Viper Ignition Aura level bonus"
	)
	_expect(
		surface.is_runtime_level_bonus_eligible_from_runtime_state(state, "item_caffeine", 3),
		"runtime-state facade should expose runtime level-bonus eligibility"
	)
	_expect(
		surface.is_ignition_aura_level_bonus_eligible_from_runtime_state(state, "item_caffeine", 3),
		"runtime-state facade should expose active Ignition Aura eligibility"
	)
	_expect(
		not surface.is_ignition_aura_level_bonus_eligible_from_runtime_state(state, "unlock_ignition_aura", 1),
		"runtime-state facade should preserve Ignition Aura exclusion ids"
	)


func _verify_runtime_state_facade_laurel_lookup() -> void:
	var surface: Object = RuntimePerkEffectiveStatQuerySurface.new()
	var state := FakeRuntimeState.new()
	state._effective_levels = RuntimePerkEffectiveLevels.new()
	state.runtime_skill_levels = {"perk_laurel_shield": 2}
	state.item_perk_level_bonus = 1
	state.viper_ignition_aura_active = true
	_expect(
		surface.get_laurel_leaf_count_from_runtime_state(state, FakeRegistry.new()) == 8,
		"runtime-state facade should stack effective Laurel level with Sacred Laurel registry bonus"
	)
	state._effective_levels = null
	_expect(
		surface.get_laurel_leaf_count_from_runtime_state(state, FakeRegistry.new()) == 3,
		"runtime-state facade should keep Sacred Laurel fallback without effective helper"
	)


func _verify_state_wrappers_delegate_to_surface() -> void:
	var state: Object = RuntimePerkState.new()
	state.runtime_skill_levels = {
		"item_caffeine": 3,
		"common_training": 1,
		"perk_laurel_shield": 2,
	}
	state.set_item_perk_level_bonus(1)
	state.set_viper_ignition_aura_active(true)
	_expect_close(state.get_active_item_duration_frames(600.0), 1680.0, "state duration wrapper should preserve surface-projected effective scaling")
	_expect_close(state.get_player_skill_cooldown_seconds(10.0), 6.8, "state cooldown wrapper should preserve surface-projected effective scaling")
	_expect(state.get_laurel_leaf_count(FakeRegistry.new()) == 8, "state Laurel wrapper should preserve registry bonus through query surface")
	_expect(state.get_viper_ignition_aura_level_bonus() == 2, "state Viper Ignition Aura wrapper should use query surface")
	_expect(state._is_runtime_level_bonus_eligible("item_caffeine", 3), "state runtime eligibility wrapper should use query surface")
	_expect(state._is_ignition_aura_level_bonus_eligible("item_caffeine", 3), "state Ignition Aura eligibility wrapper should use query surface")


func _verify_source_contract() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var surface_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_effective_stat_query_surface.gd")
	_expect(state_source.find("RuntimePerkEffectiveStatQuerySurface") >= 0, "state should preload the effective-stat query surface")
	_expect(state_source.find("_effective_stat_queries.get_dash_recharge_frames_from_runtime_state") >= 0, "state should delegate dash stat queries to runtime-state query surface facades")
	_expect(state_source.find("_effective_stat_queries.get_active_item_duration_frames_from_runtime_state") >= 0, "state should delegate active-item stat queries to runtime-state query surface facades")
	_expect(state_source.find("_effective_stat_queries.get_player_skill_cooldown_multiplier_from_runtime_state") >= 0, "state should delegate common stat queries to runtime-state query surface facades")
	_expect(state_source.find("_effective_stat_queries.get_laurel_leaf_count_from_runtime_state") >= 0, "state should delegate Laurel lookup to the runtime-state query surface facade")
	_expect(state_source.find("get_laurel_leaf_count(_effective_levels, self, registry, Callable(self, \"_get_instance\")") < 0, "state should not assemble Laurel get-instance callback inline")
	_expect(state_source.find("_effective_stat_queries.get_runtime_skill_level(_effective_levels") < 0, "state should not pass effective-level helper into runtime-level query inline")
	_expect(state_source.find("_effective_stat_queries.get_dash_recharge_frames(_effective_levels") < 0, "state should not pass effective-level helper into dash query inline")
	_expect(state_source.find("_effective_stat_queries.get_active_item_duration_frames(_effective_levels") < 0, "state should not pass effective-level helper into active-item query inline")
	_expect(state_source.find("_effective_stat_queries.get_player_skill_cooldown_multiplier(_effective_levels") < 0, "state should not pass effective-level helper into cooldown query inline")
	_expect(state_source.find("_effective_levels.get_") < 0, "state should not call effective-level getter methods directly")
	_expect(state_source.find("_effective_levels.is_") < 0, "state should not call effective-level predicate methods directly")
	_expect(state_source.find("_effective_levels.get_dash_recharge_frames") < 0, "state should not project dash query parameters inline")
	_expect(state_source.find("_effective_levels.get_active_item_duration_frames") < 0, "state should not project active-item query parameters inline")
	_expect(state_source.find("_effective_levels.get_player_skill_cooldown_multiplier") < 0, "state should not project cooldown query parameters inline")
	_expect(surface_source.find("func _call_effective_float") >= 0, "query surface should own repeated effective-helper argument projection")
	_expect(surface_source.find("func _get_runtime_skill_levels") >= 0, "query surface should own runtime level extraction")
	_expect(surface_source.find("func _get_sacred_laurel_leaf_bonus") >= 0, "query surface should own Sacred Laurel registry lookup")
	_expect(surface_source.find("func get_runtime_skill_level_from_runtime_state") >= 0, "query surface should expose runtime-level runtime-state facade")
	_expect(surface_source.find("func get_active_item_duration_frames_from_runtime_state") >= 0, "query surface should expose active-item runtime-state facade")
	_expect(surface_source.find("func get_player_skill_cooldown_multiplier_from_runtime_state") >= 0, "query surface should expose cooldown runtime-state facade")
	_expect(surface_source.find("func get_viper_ignition_aura_level_bonus_from_runtime_state") >= 0, "query surface should expose Viper Ignition Aura level-bonus facade")
	_expect(surface_source.find("func is_runtime_level_bonus_eligible_from_runtime_state") >= 0, "query surface should expose runtime eligibility facade")
	_expect(surface_source.find("func is_ignition_aura_level_bonus_eligible_from_runtime_state") >= 0, "query surface should expose Ignition Aura eligibility facade")
	_expect(surface_source.find("func get_laurel_leaf_count_from_runtime_state") >= 0, "query surface should expose Laurel runtime-state facade")
	_expect(surface_source.find("func _get_effective_levels") >= 0, "query surface should own effective-level helper lookup")
	_expect(surface_source.find("_build_runtime_state_get_instance(runtime_state)") >= 0, "query surface should assemble runtime-state get-instance callback")


func _get_instance(registry: Object, key: String) -> Object:
	if registry != null and registry.has_method("get_instance"):
		return registry.get_instance(key)
	return null


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)


func _expect_close(actual: float, expected: float, message: String) -> void:
	if abs(actual - expected) > 0.03:
		_failures.append("%s (actual %.3f, expected %.3f)" % [message, actual, expected])
