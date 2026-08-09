extends SceneTree

const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")
const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const GuardianEggAccessPolicy := preload("res://scripts/lingpet/guardian_egg_access_policy.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const ActiveItemFieldSpawnPool := preload("res://scripts/items/active_item_field_spawn_pool.gd")
const ActiveItemSlotController := preload("res://scripts/items/active_item_slot_controller.gd")
const PandoraLegacyPoolBuilder := preload("res://scripts/items/pandora_legacy_pool_builder.gd")

var _failures: Array[String] = []


class DynamicOwner:
	extends Node2D
	var scene_state := BattleSceneState.new()
	var extra := {"ai_mode": "champion", "selected_character_type": "smasher"}

	func _init() -> void:
		scene_state.reset()
		scene_state.set_value("player_pos", Vector2(380.0, 675.0))

	func _get(property: StringName) -> Variant:
		var key := str(property)
		return scene_state.get_value(key) if scene_state.has_key(key) else extra.get(key, null)

	func _set(property: StringName, value: Variant) -> bool:
		var key := str(property)
		if scene_state.has_key(key):
			scene_state.set_value(key, value)
		else:
			extra[key] = value
		return true


class FakeRuntimePerkState:
	extends RefCounted
	var runtime_skill_levels: Dictionary = {}

	func _init(has_art: bool) -> void:
		if has_art:
			runtime_skill_levels[CommonSkillCatalog.SOUL_SUMMON_ART_ID] = 1
			runtime_skill_levels[CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID] = 1

	func get_runtime_skill_level(skill_id: String) -> int:
		return int(runtime_skill_levels.get(skill_id, 0))


class FakeRegistry:
	extends RefCounted
	var instances: Dictionary
	var lazy_calls := 0
	var cached_calls := 0

	func _init(runtime: Object, has_art: bool) -> void:
		instances = {
			"lingpet_egg_runtime": runtime,
			"runtime_perk_state": FakeRuntimePerkState.new(has_art),
		}

	func get_instance(key: String) -> Object:
		lazy_calls += 1
		return instances.get(key, null) as Object

	func get_cached_instance(key: String) -> Object:
		cached_calls += 1
		return instances.get(key, null) as Object


func _init() -> void:
	_verify_all_gates_lock_without_art()
	_verify_all_gates_open_with_art()
	_verify_junior_exemption_and_immediate_trigger_bypass()
	if _failures.is_empty():
		print("guardian_egg_gate_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_all_gates_lock_without_art() -> void:
	var runtime := LingpetEggRuntime.new()
	var registry := FakeRegistry.new(runtime, false)
	var owner := DynamicOwner.new()
	var pool := ActiveItemFieldSpawnPool.new()
	var slots := ActiveItemSlotController.new()
	_expect(not runtime.can_offer_egg_item(owner, registry), "offer gate must lock without Soul Summoning Art")
	_expect(pool._should_skip_lingpet_egg_spawn(registry, owner), "field-spawn gate must skip without the art")
	_expect(slots._is_lingpet_egg_pickup_redundant([], registry, owner), "pickup gate must reject without the art")
	_expect(not slots.append_item_data(owner, _egg_item(), registry), "direct-grant gate must reject without the art")
	_expect(not runtime.deploy_egg_from_item(owner, registry), "use-site gate must reject without the art")
	_expect(
		not _pool_has_item(PandoraLegacyPoolBuilder.new().build_active_pool(owner, registry), "lingpet_egg"),
		"Pandora must not offer the Guardian Spirit egg without Soul Summoning Art"
	)
	var stale_guardian_owner := DynamicOwner.new()
	_set_owned_guardian(stale_guardian_owner)
	_expect(
		not runtime.can_offer_spirit_water_item(stale_guardian_owner, registry),
		"Spirit Water access must stay locked without Soul Summoning Art even if stale guardian ownership exists"
	)
	_expect(
		not _pool_has_item(PandoraLegacyPoolBuilder.new().build_active_pool(stale_guardian_owner, registry), "lingpet_spirit_water"),
		"Pandora must not offer Spirit Water without Soul Summoning Art"
	)
	stale_guardian_owner.free()
	_expect(registry.lazy_calls == 0, "ordinary egg gates must use non-instantiating cached peeks only")
	_expect(registry.cached_calls > 0, "gate fixture must actually exercise cached registry reads")
	owner.free()


func _verify_all_gates_open_with_art() -> void:
	var offer_runtime := LingpetEggRuntime.new()
	var offer_registry := FakeRegistry.new(offer_runtime, true)
	var offer_owner := DynamicOwner.new()
	_set_owned_guardian(offer_owner)
	_expect(offer_runtime.can_offer_egg_item(offer_owner, offer_registry), "offer gate should open with the art")
	_expect(not ActiveItemFieldSpawnPool.new()._should_skip_lingpet_egg_spawn(offer_registry, offer_owner), "field-spawn gate should open with the art")
	_expect(
		_pool_has_item(PandoraLegacyPoolBuilder.new().build_active_pool(offer_owner, offer_registry), "lingpet_egg"),
		"Pandora should keep the Guardian Spirit egg eligible with Soul Summoning Art"
	)
	_expect(
		offer_runtime.can_offer_spirit_water_item(offer_owner, offer_registry),
		"Spirit Water access should open with the art and an owned Guardian Spirit"
	)
	_expect(
		_pool_has_item(PandoraLegacyPoolBuilder.new().build_active_pool(offer_owner, offer_registry), "lingpet_spirit_water"),
		"Pandora should keep Spirit Water eligible with Soul Summoning Art and an owned Guardian Spirit"
	)
	offer_owner.free()

	var pickup_runtime := LingpetEggRuntime.new()
	var pickup_registry := FakeRegistry.new(pickup_runtime, true)
	var pickup_owner := DynamicOwner.new()
	_expect(ActiveItemSlotController.new().store_active_item(_field_egg(), [], pickup_registry, Callable(), pickup_owner), "pickup gate should open with the art")
	pickup_owner.free()

	var direct_runtime := LingpetEggRuntime.new()
	var direct_registry := FakeRegistry.new(direct_runtime, true)
	var direct_owner := DynamicOwner.new()
	_expect(ActiveItemSlotController.new().append_item_data(direct_owner, _egg_item(), direct_registry), "direct-grant gate should open with the art")
	direct_owner.free()

	var deploy_runtime := LingpetEggRuntime.new()
	var deploy_registry := FakeRegistry.new(deploy_runtime, true)
	var deploy_owner := DynamicOwner.new()
	_expect(deploy_runtime.deploy_egg_from_item(deploy_owner, deploy_registry), "use-site gate should open with the art")
	deploy_owner.free()


func _verify_junior_exemption_and_immediate_trigger_bypass() -> void:
	var junior_runtime := LingpetEggRuntime.new()
	var junior_registry := FakeRegistry.new(junior_runtime, false)
	var junior_owner := DynamicOwner.new()
	junior_owner.set("ai_mode", "junior league")
	_expect(GuardianEggAccessPolicy.has_egg_access(junior_owner, junior_registry), "auto-present junior league must pass the art access latch")
	_expect(not junior_runtime.can_offer_egg_item(junior_owner, junior_registry), "junior should still suppress the redundant item under its existing auto-present rule")
	junior_owner.free()

	var trigger_runtime := LingpetEggRuntime.new()
	var trigger_registry := FakeRegistry.new(trigger_runtime, false)
	var trigger_owner := DynamicOwner.new()
	var result := trigger_runtime.deploy_soul_summon_egg(trigger_owner, trigger_registry)
	_expect(bool(result.get("dropped", false)), "unlock-triggered immediate drop must be separate from ordinary item access gating")
	trigger_owner.free()


func _field_egg() -> Dictionary:
	return {"item_data": _egg_item()}


func _egg_item() -> Dictionary:
	return {
		"name": "lingpet_egg",
		"type": "active",
		"rarity": "pro",
		"consumable": true,
	}


func _set_owned_guardian(owner: Object) -> void:
	owner.set("lingpet_owned_pet_ids", ["maribo"])
	owner.set("owned_lingpet_ids", ["maribo"])
	owner.set("owned_ringpet_ids", ["maribo"])
	owner.set("lingpet_slots", ["maribo", "", ""])
	owner.set("ringpet_slots", ["maribo", "", ""])
	owner.set("lingpet_slot_pet_ids", ["maribo", "", ""])
	owner.set("ringpet_slot_pet_ids", ["maribo", "", ""])


func _pool_has_item(pool: Array, item_name: String) -> bool:
	for item_value in pool:
		if item_value is Dictionary and str((item_value as Dictionary).get("name", "")) == item_name:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
