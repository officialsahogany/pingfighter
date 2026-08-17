extends SceneTree

const RuntimePerkDynamicEffects := preload("res://scripts/characters/runtime_perk_dynamic_effects.gd")
const RuntimePerkEffectiveLevels := preload("res://scripts/characters/runtime_perk_effective_levels.gd")

var _failures: Array[String] = []
var _sync_owner_effects_calls := 0
var _training_calls := 0
var _refresh_consumers_calls := 0


func _init() -> void:
	_verify_active_and_item_bonus_updates()
	_verify_dynamic_refresh_orchestration()
	_verify_runtime_state_facade_owns_deps_and_callbacks()
	_verify_source_contract()

	if _failures.is_empty():
		print("runtime_perk_dynamic_effects_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_active_and_item_bonus_updates() -> void:
	var helper := RuntimePerkDynamicEffects.new()
	var effective := RuntimePerkEffectiveLevels.new()
	var state := FakeRuntimeState.new()
	var active_result: Dictionary = helper.set_viper_ignition_aura_active(effective, state, true)
	_expect(bool(active_result.get("accepted", false)), "dynamic helper should apply Viper Ignition active updates")
	_expect(state.viper_ignition_aura_active, "dynamic helper should set Viper Ignition active")
	_expect(state.viper_ignition_aura_owner_sync_dirty, "dynamic helper should mark owner sync dirty")
	_expect(not bool(helper.set_viper_ignition_aura_active(effective, state, true).get("accepted", true)), "dynamic helper should reject unchanged Viper Ignition active updates")

	var item_result: Dictionary = helper.set_item_perk_level_bonus(effective, state, 3)
	_expect(bool(item_result.get("accepted", false)), "dynamic helper should apply item perk-level bonus updates")
	_expect(state.item_perk_level_bonus == 3, "dynamic helper should write item perk-level bonus")
	_expect(not bool(helper.set_item_perk_level_bonus(effective, state, 3).get("accepted", true)), "dynamic helper should reject unchanged item perk-level bonus updates")


func _verify_dynamic_refresh_orchestration() -> void:
	var helper := RuntimePerkDynamicEffects.new()
	var effective := RuntimePerkEffectiveLevels.new()
	var state := FakeRuntimeState.new()
	state.viper_ignition_aura_owner_sync_dirty = true
	_reset_calls()
	var owner_result: Dictionary = helper.refresh_viper_ignition_aura_dynamic_effects(
		effective,
		state,
		FakeRegistry.new(),
		FakeOwner.new(),
		_callbacks()
	)
	_expect(bool(owner_result.get("accepted", false)), "dynamic helper should accept owner refresh plans")
	_expect(_sync_owner_effects_calls == 1, "owner refresh should sync owner effects")
	_expect(_training_calls == 0, "owner refresh should not separately train configs")
	_expect(_refresh_consumers_calls == 1, "owner refresh should refresh runtime consumers")
	_expect(not state.viper_ignition_aura_owner_sync_dirty, "owner refresh should clear dirty owner-sync state")

	state.viper_ignition_aura_owner_sync_dirty = true
	_reset_calls()
	var no_owner_result: Dictionary = helper.refresh_viper_ignition_aura_owner_sync_if_needed(
		effective,
		state,
		FakeRegistry.new(),
		null,
		_callbacks()
	)
	_expect(bool(no_owner_result.get("accepted", false)), "dirty no-owner refresh should still apply state-update helper")
	_expect(_sync_owner_effects_calls == 0, "dirty no-owner refresh should not sync missing owner effects")
	_expect(_training_calls == 1, "dirty no-owner refresh should train skill configs")
	_expect(_refresh_consumers_calls == 0, "dirty no-owner refresh should keep the legacy no-consumer-refresh behavior")
	_expect(state.viper_ignition_aura_owner_sync_dirty, "dirty no-owner refresh should keep owner-sync dirty")

	_reset_calls()
	var item_result: Dictionary = helper.refresh_item_perk_level_bonus_dynamic_effects(
		effective,
		state,
		FakeRegistry.new(),
		null,
		_callbacks()
	)
	_expect(bool(item_result.get("accepted", false)), "item bonus refresh should accept no-owner refresh plans")
	_expect(_training_calls == 1, "item bonus no-owner refresh should train skill configs")
	_expect(_refresh_consumers_calls == 1, "item bonus no-owner refresh should refresh runtime consumers")


func _verify_runtime_state_facade_owns_deps_and_callbacks() -> void:
	var helper := RuntimePerkDynamicEffects.new()
	var state := FakeRuntimeState.new()
	var active_result: Dictionary = helper.set_viper_ignition_aura_active_from_runtime_state(state, true)
	_expect(bool(active_result.get("accepted", false)), "dynamic facade should apply Viper Ignition active updates")
	_expect(state.viper_ignition_aura_active, "dynamic facade should use runtime-state effective-level helper for active writes")
	_expect(state.viper_ignition_aura_owner_sync_dirty, "dynamic facade active write should mark owner sync dirty")
	_expect(helper.is_viper_ignition_aura_active_from_runtime_state(state), "dynamic facade should read live Viper Ignition active state")
	_expect(not helper.is_viper_ignition_aura_active_from_runtime_state(null), "dynamic facade should use false Viper Ignition active fallback")

	var item_set_result: Dictionary = helper.set_item_perk_level_bonus_from_runtime_state(state, 2)
	_expect(bool(item_set_result.get("accepted", false)), "dynamic facade should apply item perk-level bonus updates")
	_expect(state.item_perk_level_bonus == 2, "dynamic facade should write item perk-level bonus")
	_expect(helper.get_item_perk_level_bonus_from_runtime_state(state) == 2, "dynamic facade should read live item perk-level bonus")
	_expect(helper.get_item_perk_level_bonus_from_runtime_state(null) == 0, "dynamic facade should use neutral item perk-level bonus fallback")

	state.viper_ignition_aura_owner_sync_dirty = true
	state.reset_calls()
	var owner_refresh_result: Dictionary = helper.refresh_viper_ignition_aura_dynamic_effects_from_runtime_state(
		state,
		FakeRegistry.new(),
		FakeOwner.new()
	)
	_expect(bool(owner_refresh_result.get("accepted", false)), "dynamic facade should accept owner refresh plans")
	_expect(state.sync_owner_effects_calls == 1, "dynamic facade should build owner-sync callback internally")
	_expect(state.refresh_consumers_calls == 1, "dynamic facade should build consumer-refresh callback internally")
	_expect(not state.viper_ignition_aura_owner_sync_dirty, "dynamic facade owner refresh should clear dirty state")

	state.reset_calls()
	var item_refresh_result: Dictionary = helper.refresh_item_perk_level_bonus_dynamic_effects_from_runtime_state(
		state,
		FakeRegistry.new(),
		null
	)
	_expect(bool(item_refresh_result.get("accepted", false)), "dynamic facade should accept item no-owner refresh plans")
	_expect(state.training_calls == 1, "dynamic facade item no-owner refresh should train skill configs")
	_expect(state.refresh_consumers_calls == 1, "dynamic facade item no-owner refresh should refresh consumers")

	state.viper_ignition_aura_owner_sync_dirty = true
	state.reset_calls()
	var dirty_sync_result: Dictionary = helper.refresh_viper_ignition_aura_owner_sync_if_needed_from_runtime_state(
		state,
		FakeRegistry.new(),
		null
	)
	_expect(bool(dirty_sync_result.get("accepted", false)), "dynamic facade should accept dirty no-owner sync refresh")
	_expect(state.sync_owner_effects_calls == 0, "dynamic facade dirty no-owner sync should not call owner sync")
	_expect(state.training_calls == 1, "dynamic facade dirty no-owner sync should train configs")


func _verify_source_contract() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_dynamic_effects.gd")
	var set_active_body: String = _function_body(state_source, "func set_viper_ignition_aura_active(")
	var viper_refresh_body: String = _function_body(state_source, "func refresh_viper_ignition_aura_dynamic_effects(")
	var item_refresh_body: String = _function_body(state_source, "func refresh_item_perk_level_bonus_dynamic_effects(")
	var set_item_body: String = _function_body(state_source, "func set_item_perk_level_bonus(")
	var is_active_body: String = _function_body(state_source, "func is_viper_ignition_aura_active(")
	var get_item_bonus_body: String = _function_body(state_source, "func get_item_perk_level_bonus(")
	var dirty_sync_body: String = _function_body(state_source, "func _refresh_viper_ignition_aura_owner_sync_if_needed(")
	var active_facade_body: String = _function_body(helper_source, "func set_viper_ignition_aura_active_from_runtime_state(")
	var item_facade_body: String = _function_body(helper_source, "func set_item_perk_level_bonus_from_runtime_state(")
	var active_query_facade_body: String = _function_body(helper_source, "func is_viper_ignition_aura_active_from_runtime_state(")
	var item_query_facade_body: String = _function_body(helper_source, "func get_item_perk_level_bonus_from_runtime_state(")
	var viper_facade_body: String = _function_body(helper_source, "func refresh_viper_ignition_aura_dynamic_effects_from_runtime_state(")
	var item_refresh_facade_body: String = _function_body(helper_source, "func refresh_item_perk_level_bonus_dynamic_effects_from_runtime_state(")
	var dirty_sync_facade_body: String = _function_body(helper_source, "func refresh_viper_ignition_aura_owner_sync_if_needed_from_runtime_state(")
	_expect(state_source.find("RuntimePerkDynamicEffects") >= 0, "state should preload dynamic-effect helper")
	_expect(state_source.find("_dynamic_effects.set_viper_ignition_aura_active") >= 0, "state should route Viper Ignition active writes through dynamic helper")
	_expect(state_source.find("_dynamic_effects.set_item_perk_level_bonus") >= 0, "state should route item perk-level bonus writes through dynamic helper")
	_expect(is_active_body.find("_dynamic_effects.is_viper_ignition_aura_active_from_runtime_state") >= 0, "state Viper Ignition active query should delegate through dynamic helper")
	_expect(is_active_body.find("return viper_ignition_aura_active") < 0, "state should not read Viper Ignition active field inline")
	_expect(get_item_bonus_body.find("_dynamic_effects.get_item_perk_level_bonus_from_runtime_state") >= 0, "state item perk-level bonus query should delegate through dynamic helper")
	_expect(get_item_bonus_body.find("return item_perk_level_bonus") < 0, "state should not read item perk-level bonus field inline")
	_expect(state_source.find("_dynamic_effects.refresh_viper_ignition_aura_dynamic_effects") >= 0, "state should route Viper Ignition refresh through dynamic helper")
	_expect(state_source.find("_dynamic_effects.refresh_item_perk_level_bonus_dynamic_effects") >= 0, "state should route item bonus refresh through dynamic helper")
	_expect(set_active_body.find("_effective_levels") < 0, "state Viper Ignition setter should not pass effective-level helper inline")
	_expect(set_item_body.find("_effective_levels") < 0, "state item bonus setter should not pass effective-level helper inline")
	_expect(viper_refresh_body.find("_effective_levels") < 0, "state Viper refresh should not pass effective-level helper inline")
	_expect(item_refresh_body.find("_effective_levels") < 0, "state item refresh should not pass effective-level helper inline")
	_expect(dirty_sync_body.find("_effective_levels") < 0, "state dirty owner sync should not pass effective-level helper inline")
	_expect(viper_refresh_body.find("build_state_callbacks(self)") < 0, "state Viper refresh should not build callback map inline")
	_expect(item_refresh_body.find("build_state_callbacks(self)") < 0, "state item refresh should not build callback map inline")
	_expect(dirty_sync_body.find("build_state_callbacks(self)") < 0, "state dirty owner sync should not build callback map inline")
	_expect(helper_source.find("func set_viper_ignition_aura_active_from_runtime_state(") >= 0, "dynamic helper should expose active-write runtime-state facade")
	_expect(helper_source.find("func set_item_perk_level_bonus_from_runtime_state(") >= 0, "dynamic helper should expose item-bonus runtime-state facade")
	_expect(helper_source.find("func is_viper_ignition_aura_active_from_runtime_state(") >= 0, "dynamic helper should expose active-state runtime-state query facade")
	_expect(helper_source.find("func get_item_perk_level_bonus_from_runtime_state(") >= 0, "dynamic helper should expose item-bonus runtime-state query facade")
	_expect(helper_source.find("func refresh_viper_ignition_aura_dynamic_effects_from_runtime_state(") >= 0, "dynamic helper should expose Viper refresh runtime-state facade")
	_expect(helper_source.find("func refresh_item_perk_level_bonus_dynamic_effects_from_runtime_state(") >= 0, "dynamic helper should expose item refresh runtime-state facade")
	_expect(helper_source.find("func refresh_viper_ignition_aura_owner_sync_if_needed_from_runtime_state(") >= 0, "dynamic helper should expose dirty-sync runtime-state facade")
	_expect(active_facade_body.find("RuntimePerkRuntimeStateAccess.get_object(runtime_state, \"_effective_levels\")") >= 0, "dynamic active facade should own effective-level lookup")
	_expect(item_facade_body.find("RuntimePerkRuntimeStateAccess.get_object(runtime_state, \"_effective_levels\")") >= 0, "dynamic item facade should own effective-level lookup")
	_expect(active_query_facade_body.find("viper_ignition_aura_active") >= 0, "dynamic active query facade should own active field read")
	_expect(item_query_facade_body.find("item_perk_level_bonus") >= 0, "dynamic item query facade should own item bonus field read")
	_expect(viper_facade_body.find("RuntimePerkRuntimeStateAccess.get_object(runtime_state, \"_effective_levels\")") >= 0, "dynamic Viper refresh facade should own effective-level lookup")
	_expect(item_refresh_facade_body.find("RuntimePerkRuntimeStateAccess.get_object(runtime_state, \"_effective_levels\")") >= 0, "dynamic item refresh facade should own effective-level lookup")
	_expect(dirty_sync_facade_body.find("RuntimePerkRuntimeStateAccess.get_object(runtime_state, \"_effective_levels\")") >= 0, "dynamic dirty-sync facade should own effective-level lookup")
	_expect(viper_facade_body.find("build_state_callbacks(runtime_state)") >= 0, "dynamic Viper refresh facade should build callback map internally")
	_expect(item_refresh_facade_body.find("build_state_callbacks(runtime_state)") >= 0, "dynamic item refresh facade should build callback map internally")
	_expect(dirty_sync_facade_body.find("build_state_callbacks(runtime_state)") >= 0, "dynamic dirty-sync facade should build callback map internally")
	_expect(state_source.find("func _apply_dynamic_effect_refresh_plan(") < 0, "state should not keep local dynamic refresh plan orchestration")
	_expect(state_source.find("_effective_levels.apply_dynamic_effect_refresh_state_update(self") < 0, "state should not apply dynamic refresh state updates inline")
	_expect(helper_source.find("build_dynamic_effect_refresh_plan") >= 0, "dynamic helper should own dynamic refresh plan consumption")
	_expect(helper_source.find("build_dirty_owner_sync_refresh_plan") >= 0, "dynamic helper should own dirty owner-sync refresh plan consumption")
	_expect(helper_source.find("apply_dynamic_effect_refresh_state_update") >= 0, "dynamic helper should apply effective-level refresh state updates")


func _callbacks() -> Dictionary:
	return {
		RuntimePerkDynamicEffects.CALLBACK_SYNC_RUNTIME_PERK_OWNER_EFFECTS: Callable(self, "_sync_runtime_perk_owner_effects"),
		RuntimePerkDynamicEffects.CALLBACK_APPLY_TRAINING_TO_SKILL_CONFIGS: Callable(self, "_apply_training_to_skill_configs"),
		RuntimePerkDynamicEffects.CALLBACK_REFRESH_ITEM_POLISH_CONSUMERS: Callable(self, "_refresh_item_polish_consumers"),
	}


func _reset_calls() -> void:
	_sync_owner_effects_calls = 0
	_training_calls = 0
	_refresh_consumers_calls = 0


func _sync_runtime_perk_owner_effects(_owner: Object, _registry: Object) -> void:
	_sync_owner_effects_calls += 1


func _apply_training_to_skill_configs(_registry: Object) -> void:
	_training_calls += 1


func _refresh_item_polish_consumers(_owner: Object, _registry: Object) -> void:
	_refresh_consumers_calls += 1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)


class FakeRuntimeState:
	extends RefCounted

	var _effective_levels: Object = RuntimePerkEffectiveLevels.new()
	var viper_ignition_aura_active := false
	var viper_ignition_aura_owner_sync_dirty := false
	var item_perk_level_bonus := 0
	var sync_owner_effects_calls := 0
	var training_calls := 0
	var refresh_consumers_calls := 0

	func reset_calls() -> void:
		sync_owner_effects_calls = 0
		training_calls = 0
		refresh_consumers_calls = 0

	func _sync_runtime_perk_owner_effects(_owner: Object, _registry: Object) -> void:
		sync_owner_effects_calls += 1

	func _apply_training_to_skill_configs(_registry: Object) -> void:
		training_calls += 1

	func _refresh_item_polish_consumers(_owner: Object, _registry: Object) -> void:
		refresh_consumers_calls += 1


class FakeOwner:
	extends RefCounted


class FakeRegistry:
	extends RefCounted
