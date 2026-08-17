extends SceneTree

const RuntimePerkOwnerEffectSync := preload("res://scripts/characters/runtime_perk_owner_effect_sync.gd")
const RuntimePerkOwnerProjection := preload("res://scripts/characters/runtime_perk_owner_projection.gd")
const RuntimePerkOwnerSyncFlow := preload("res://scripts/characters/runtime_perk_owner_sync_flow.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

const BASE_WIDTH := 155.0
const BASE_HEIGHT := 50.0
const FIELD_HEIGHT := 750.0

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var runtime_perk_levels: Dictionary = {}
	var runtime_perk_effective_levels: Dictionary = {}
	var runtime_perk_pending_choices := 0
	var runtime_perk_starpoints := 0
	var runtime_perk_gold := 0
	var runtime_perk_choice_active := false
	var runtime_accessory_slot_bonus := 0
	var runtime_laurel_leaf_count := 0
	var runtime_paddle_scale := 1.0
	var runtime_paddle_base_width := BASE_WIDTH
	var runtime_paddle_base_height := BASE_HEIGHT
	var player_pos := Vector2(302.5, FIELD_HEIGHT - BASE_HEIGHT)
	var player_paddle_width := BASE_WIDTH
	var player_paddle_height := BASE_HEIGHT
	var player_paddle_scale := 1.0
	var item_perk_level_bonus := 0
	var viper_ignition_aura_active := false
	var selected_character_type := "smasher"


class FakeScaledRuntime:
	extends RefCounted

	var scale := 1.0
	var refresh_calls := 0

	func get_player_paddle_scale() -> float:
		return scale

	func refresh_runtime_perk_scaling(_owner: Object, _registry: Object) -> void:
		refresh_calls += 1


class FakeSkillConfig:
	extends RefCounted

	var last_multiplier := -1.0

	func set_runtime_cooldown_multiplier(multiplier: float) -> void:
		last_multiplier = multiplier


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class FakeRuntimeState:
	extends RefCounted

	var _owner_projection: Object = null
	var _owner_effect_sync: Object = null
	var runtime_skill_levels: Dictionary = {}
	var effective_runtime_skill_levels: Dictionary = {}
	var pending_skill_choices := 0
	var starpoint_for_skills := 0
	var gold_from_perks := 0
	var choice_active := false
	var item_perk_level_bonus := 0
	var viper_ignition_aura_active := false
	var accessory_slot_bonus := 0
	var laurel_leaf_count := 0
	var paddle_multiplier := 1.0
	var cooldown_multiplier := 1.0

	func get_effective_runtime_skill_levels() -> Dictionary:
		return effective_runtime_skill_levels.duplicate(true)

	func is_choice_active() -> bool:
		return choice_active

	func get_accessory_slot_bonus() -> int:
		return accessory_slot_bonus

	func get_laurel_leaf_count(_registry: Object = null) -> int:
		return laurel_leaf_count

	func get_player_paddle_size_multiplier() -> float:
		return paddle_multiplier

	func get_player_skill_cooldown_multiplier() -> float:
		return cooldown_multiplier

	func _get_instance(registry: Object, key: String) -> Object:
		if registry != null and registry.has_method("get_instance"):
			return registry.get_instance(key)
		return null


func _init() -> void:
	_verify_projection_sync_flow()
	_verify_owner_effect_sync_flow()
	_verify_runtime_state_facade_sync_flow()
	_verify_state_wrappers_delegate_to_flow()
	_verify_source_contract()

	if _failures.is_empty():
		print("runtime_perk_owner_sync_flow_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_projection_sync_flow() -> void:
	var flow: Object = RuntimePerkOwnerSyncFlow.new()
	var owner := FakeOwner.new()
	var runtime_levels := {"dash_lightweight": 2}
	var effective_levels := {"dash_lightweight": 4}
	flow.sync_owner(
		owner,
		RuntimePerkOwnerProjection.new(),
		runtime_levels,
		effective_levels,
		3,
		1,
		77,
		true,
		2,
		true
	)
	_expect(int(owner.runtime_perk_levels.get("dash_lightweight", 0)) == 2, "flow should project runtime levels")
	_expect(int(owner.runtime_perk_effective_levels.get("dash_lightweight", 0)) == 4, "flow should project effective levels")
	_expect(owner.runtime_perk_pending_choices == 3, "flow should project pending choice count")
	_expect(owner.runtime_perk_starpoints == 1, "flow should project starpoint remainder")
	_expect(owner.runtime_perk_gold == 77, "flow should project stored perk gold")
	_expect(owner.runtime_perk_choice_active, "flow should project choice-active state")
	_expect(owner.item_perk_level_bonus == 2, "flow should project item perk level bonus")
	_expect(owner.viper_ignition_aura_active, "flow should project Viper Ignition Aura state")
	owner.runtime_perk_levels["dash_lightweight"] = 99
	owner.runtime_perk_effective_levels["dash_lightweight"] = 99
	_expect(int(runtime_levels.get("dash_lightweight", 0)) == 2, "flow projection should deep-copy runtime levels")
	_expect(int(effective_levels.get("dash_lightweight", 0)) == 4, "flow projection should deep-copy effective levels")


func _verify_owner_effect_sync_flow() -> void:
	var flow: Object = RuntimePerkOwnerSyncFlow.new()
	var owner := FakeOwner.new()
	var active_runtime := FakeScaledRuntime.new()
	active_runtime.scale = 1.2
	var mythic_runtime := FakeScaledRuntime.new()
	mythic_runtime.scale = 0.75
	var smasher_config := FakeSkillConfig.new()
	var viper_config := FakeSkillConfig.new()
	var commando_config := FakeSkillConfig.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"active_item_runtime": active_runtime,
		"mythic_item_runtime": mythic_runtime,
		"smasher_skill_config": smasher_config,
		"viper_skill_config": viper_config,
		"commando_skill_config": commando_config,
	}

	flow.sync_owner_effects(
		owner,
		registry,
		RuntimePerkOwnerEffectSync.new(),
		{"common_bulk_up": 1},
		2,
		3,
		1.06,
		0.84,
		Callable(self, "_get_instance")
	)
	_expect(owner.runtime_accessory_slot_bonus == 2, "flow should sync accessory slot bonus")
	_expect(owner.runtime_laurel_leaf_count == 3, "flow should sync Laurel leaf count")
	_expect_close(owner.runtime_paddle_scale, 1.06, "flow should sync raw perk paddle scale")
	_expect_close(owner.player_paddle_width, BASE_WIDTH * 1.06 * 1.2 * 0.75, "flow should combine perk, active-item, and mythic paddle scales")
	_expect_close(owner.player_paddle_height, BASE_HEIGHT * 1.06 * 1.2 * 0.75, "flow should combine paddle height scales")
	_expect_close(owner.player_pos.y + owner.player_paddle_height, FIELD_HEIGHT, "flow should preserve grounded paddle bottom during resize")
	_expect_close(smasher_config.last_multiplier, 0.84, "flow should sync Smasher cooldown multiplier")
	_expect_close(viper_config.last_multiplier, 0.84, "flow should sync Viper cooldown multiplier")
	_expect_close(commando_config.last_multiplier, 0.84, "flow should sync Commando cooldown multiplier")

	flow.refresh_item_polish_consumers(owner, registry, RuntimePerkOwnerEffectSync.new(), Callable(self, "_get_instance"))
	_expect(mythic_runtime.refresh_calls == 1, "flow should route item polish consumer refresh")
	flow.refresh_mythic_runtime_perk_consumers(owner, registry, RuntimePerkOwnerEffectSync.new(), Callable(self, "_get_instance"))
	_expect(mythic_runtime.refresh_calls == 2, "flow should route mythic runtime-perk consumer refresh")


func _verify_runtime_state_facade_sync_flow() -> void:
	var flow: Object = RuntimePerkOwnerSyncFlow.new()
	var owner := FakeOwner.new()
	var active_runtime := FakeScaledRuntime.new()
	active_runtime.scale = 1.1
	var mythic_runtime := FakeScaledRuntime.new()
	mythic_runtime.scale = 0.8
	var smasher_config := FakeSkillConfig.new()
	var viper_config := FakeSkillConfig.new()
	var commando_config := FakeSkillConfig.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"active_item_runtime": active_runtime,
		"mythic_item_runtime": mythic_runtime,
		"smasher_skill_config": smasher_config,
		"viper_skill_config": viper_config,
		"commando_skill_config": commando_config,
	}
	var runtime_state := FakeRuntimeState.new()
	runtime_state._owner_projection = RuntimePerkOwnerProjection.new()
	runtime_state._owner_effect_sync = RuntimePerkOwnerEffectSync.new()
	runtime_state.runtime_skill_levels = {"dash_lightweight": 3}
	runtime_state.effective_runtime_skill_levels = {"dash_lightweight": 5}
	runtime_state.pending_skill_choices = 4
	runtime_state.starpoint_for_skills = 2
	runtime_state.gold_from_perks = 11
	runtime_state.choice_active = true
	runtime_state.item_perk_level_bonus = 7
	runtime_state.viper_ignition_aura_active = true
	runtime_state.accessory_slot_bonus = 2
	runtime_state.laurel_leaf_count = 6
	runtime_state.paddle_multiplier = 1.08
	runtime_state.cooldown_multiplier = 0.81

	flow.sync_owner_from_runtime_state(runtime_state, owner)
	_expect(int(owner.runtime_perk_levels.get("dash_lightweight", 0)) == 3, "runtime-state facade should project runtime levels")
	_expect(int(owner.runtime_perk_effective_levels.get("dash_lightweight", 0)) == 5, "runtime-state facade should project effective levels")
	_expect(owner.runtime_perk_pending_choices == 4, "runtime-state facade should project pending choices")
	_expect(owner.runtime_perk_starpoints == 2, "runtime-state facade should project starpoints")
	_expect(owner.runtime_perk_gold == 11, "runtime-state facade should project perk gold")
	_expect(owner.runtime_perk_choice_active, "runtime-state facade should project active choice")
	_expect(owner.item_perk_level_bonus == 7, "runtime-state facade should project item perk bonus")
	_expect(owner.viper_ignition_aura_active, "runtime-state facade should project Viper Ignition Aura")

	flow.sync_owner_effects_from_runtime_state(runtime_state, owner, registry)
	_expect(owner.runtime_accessory_slot_bonus == 2, "runtime-state facade should sync accessory slot bonus")
	_expect(owner.runtime_laurel_leaf_count == 6, "runtime-state facade should sync Laurel leaf count")
	_expect_close(owner.player_paddle_width, BASE_WIDTH * 1.08 * 1.1 * 0.8, "runtime-state facade should use state get-instance callback for paddle scales")
	_expect_close(smasher_config.last_multiplier, 0.81, "runtime-state facade should refresh Smasher cooldown training")
	_expect_close(viper_config.last_multiplier, 0.81, "runtime-state facade should refresh Viper cooldown training")
	_expect_close(commando_config.last_multiplier, 0.81, "runtime-state facade should refresh Commando cooldown training")

	flow.refresh_item_polish_consumers_from_runtime_state(runtime_state, owner, registry)
	_expect(mythic_runtime.refresh_calls == 1, "runtime-state facade should route item polish refresh")
	flow.refresh_mythic_runtime_perk_consumers_from_runtime_state(runtime_state, owner, registry)
	_expect(mythic_runtime.refresh_calls == 2, "runtime-state facade should route mythic refresh")
	runtime_state.cooldown_multiplier = 0.73
	flow.apply_training_to_skill_configs_from_runtime_state(runtime_state, registry)
	_expect_close(smasher_config.last_multiplier, 0.73, "runtime-state facade should route direct training refresh")


func _verify_state_wrappers_delegate_to_flow() -> void:
	var state := RuntimePerkState.new()
	var owner := FakeOwner.new()
	state.runtime_skill_levels = {"dash_lightweight": 1}
	state.pending_skill_choices = 2
	state.starpoint_for_skills = 1
	state.gold_from_perks = 5
	state.item_perk_level_bonus = 1
	state.viper_ignition_aura_active = true
	state._sync_owner(owner)
	_expect(int(owner.runtime_perk_levels.get("dash_lightweight", 0)) == 1, "state owner-sync wrapper should still project runtime levels")
	_expect(owner.runtime_perk_pending_choices == 2, "state owner-sync wrapper should still project pending choices")
	_expect(owner.runtime_perk_gold == 5, "state owner-sync wrapper should still project stored gold")


func _verify_source_contract() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_owner_sync_flow.gd")
	_expect(state_source.find("RuntimePerkOwnerSyncFlow") >= 0, "state should preload owner-sync flow")
	_expect(flow_source.find("owner_projection.build_state") >= 0, "owner-sync flow should own owner projection state assembly")
	_expect(flow_source.find("owner_effect_sync.build_sync_context") >= 0, "owner-sync flow should own owner-effect context assembly")
	_expect(flow_source.find("refresh_item_polish_consumers") >= 0, "owner-sync flow should route item-polish consumer refresh")
	_expect(flow_source.find("apply_training_to_skill_configs") >= 0, "owner-sync flow should route skill-config training refresh")
	_expect(flow_source.find("RuntimePerkRuntimeStateAccess.get_object(runtime_state, \"_owner_projection\")") >= 0, "owner-sync flow should look up owner projection from runtime state")
	_expect(flow_source.find("RuntimePerkRuntimeStateAccess.get_object(runtime_state, \"_owner_effect_sync\")") >= 0, "owner-sync flow should look up owner-effect sync from runtime state")
	_expect(flow_source.find("RuntimePerkRuntimeStateAccess.build_callable(runtime_state, \"_get_instance\")") >= 0, "owner-sync flow should assemble runtime-state get-instance callback")

	var sync_body: String = _function_body(state_source, "func _sync_owner(")
	_expect(sync_body.find("_owner_sync_flow.sync_owner") >= 0, "state owner-sync wrapper should delegate to owner-sync flow")
	_expect(sync_body.find("build_state(") < 0, "state owner-sync wrapper should not assemble projection state inline")
	_expect(sync_body.find("_owner_projection") < 0, "state owner-sync wrapper should not pass owner projection inline")

	var effect_body: String = _function_body(state_source, "func _sync_runtime_perk_owner_effects(")
	_expect(effect_body.find("_owner_sync_flow.sync_owner_effects") >= 0, "state owner-effect wrapper should delegate to owner-sync flow")
	_expect(effect_body.find("build_sync_context(") < 0, "state owner-effect wrapper should not assemble sync context inline")
	_expect(effect_body.find("_owner_effect_sync") < 0, "state owner-effect wrapper should not pass owner-effect sync inline")
	_expect(effect_body.find("Callable(self, \"_get_instance\")") < 0, "state owner-effect wrapper should not assemble get-instance callback inline")

	var item_refresh_body: String = _function_body(state_source, "func _refresh_item_polish_consumers(")
	_expect(item_refresh_body.find("refresh_item_polish_consumers_from_runtime_state") >= 0, "state item-polish refresh wrapper should use runtime-state facade")
	_expect(item_refresh_body.find("Callable(self, \"_get_instance\")") < 0, "state item-polish refresh wrapper should not assemble get-instance callback inline")

	var mythic_refresh_body: String = _function_body(state_source, "func _refresh_mythic_runtime_perk_consumers(")
	_expect(mythic_refresh_body.find("refresh_mythic_runtime_perk_consumers_from_runtime_state") >= 0, "state mythic refresh wrapper should use runtime-state facade")
	_expect(mythic_refresh_body.find("Callable(self, \"_get_instance\")") < 0, "state mythic refresh wrapper should not assemble get-instance callback inline")

	var training_body: String = _function_body(state_source, "func _apply_training_to_skill_configs(")
	_expect(training_body.find("_owner_sync_flow.apply_training_to_skill_configs") >= 0, "state training wrapper should delegate to owner-sync flow")
	_expect(training_body.find("_owner_effect_sync.apply_training_to_skill_configs") < 0, "state training wrapper should not call owner-effect sync inline")
	_expect(training_body.find("_owner_effect_sync") < 0, "state training wrapper should not pass owner-effect sync inline")
	_expect(training_body.find("Callable(self, \"_get_instance\")") < 0, "state training wrapper should not assemble get-instance callback inline")


func _get_instance(registry: Object, key: String) -> Object:
	if registry != null and registry.has_method("get_instance"):
		return registry.get_instance(key)
	return null


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_close(actual: float, expected: float, message: String) -> void:
	if abs(actual - expected) > 0.0001:
		_failures.append("%s: got %.6f expected %.6f" % [message, actual, expected])


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)
