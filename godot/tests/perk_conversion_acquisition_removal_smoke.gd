extends SceneTree

const ActiveItemFieldSpawnPool := preload("res://scripts/items/active_item_field_spawn_pool.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const PandoraLegacyPoolBuilder := preload("res://scripts/items/pandora_legacy_pool_builder.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const StageClearRewardResolver := preload("res://scripts/core/stage_clear_reward_resolver.gd")
const TreasureHuntRuntime := preload("res://scripts/items/treasure_hunt_runtime.gd")

var _failures: Array[String] = []


class FakeOwner:
	var active_item_slots: Array = []
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var runtime_perk_levels: Dictionary = {}
	var runtime_perk_effective_levels: Dictionary = {}
	var runtime_perk_pending_choices := 0
	var runtime_perk_starpoints := 0
	var runtime_perk_choice_active := false
	var selected_character_type := "smasher"
	var player_pos := Vector2(302.5, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0

	func queue_redraw() -> void:
		pass


class FakeRegistry:
	var instances: Dictionary = {}

	func _init(new_instances: Dictionary = {}) -> void:
		instances = new_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	PerkConversionFlags.debug_set_enabled(false)

	_verify_field_spawn_gate()
	_verify_stage_clear_box_redirect()
	_verify_pandora_passive_pool_gate()
	_verify_treasure_hunt_redirect()

	PerkConversionFlags.debug_set_enabled(false)
	if _failures.is_empty():
		print("perk_conversion_acquisition_removal_smoke: ok")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_field_spawn_gate() -> void:
	var pool := ActiveItemFieldSpawnPool.new()
	var registry := FakeRegistry.new()

	PerkConversionFlags.debug_set_enabled(false)
	var off_candidates: Array[Dictionary] = pool.build_spawn_candidates(registry)
	var off_counts := _count_spawn_groups(off_candidates)
	_expect(int(off_counts.get("active", 0)) > 0, "flag-OFF field spawn should keep active candidates")
	_expect(int(off_counts.get("passive", 0)) > 0, "flag-OFF field spawn should keep passive candidates")
	_expect(int(off_counts.get("mythic", 0)) > 0, "flag-OFF field spawn should keep mythic candidates")
	_expect(_array_has_item(off_candidates, "dowsing_pendulum"), "flag-OFF field spawn should include passive Dowsing Pendulum")

	PerkConversionFlags.debug_set_enabled(true)
	var on_candidates: Array[Dictionary] = pool.build_spawn_candidates(registry)
	var on_counts := _count_spawn_groups(on_candidates)
	_expect(int(on_counts.get("active", 0)) > 0, "flag-ON field spawn should keep active candidates")
	_expect(int(on_counts.get("passive", 0)) == 0, "flag-ON field spawn should remove passive candidates")
	_expect(int(on_counts.get("mythic", 0)) > 0, "flag-ON field spawn should keep mythic candidates")
	_expect(_array_has_item(on_candidates, "megingjord"), "flag-ON field spawn should not remove mythic candidates")


func _verify_stage_clear_box_redirect() -> void:
	var resolver := StageClearRewardResolver.new()

	PerkConversionFlags.debug_set_enabled(false)
	var normal_off: Dictionary = resolver._roll_normal_box_reward(null, null, 0.15)
	_expect(str(normal_off.get("type", "")) == StageClearRewardResolver.REWARD_PASSIVE, "flag-OFF normal passive roll should stay passive")
	var advanced_off: Dictionary = resolver._roll_advanced_box_reward(null, null, 0.38)
	_expect(str(advanced_off.get("type", "")) == StageClearRewardResolver.REWARD_PASSIVE, "flag-OFF advanced passive roll should stay passive")

	PerkConversionFlags.debug_set_enabled(true)
	var normal_on: Dictionary = resolver._roll_normal_box_reward(null, null, 0.15)
	_expect(str(normal_on.get("type", "")) == StageClearRewardResolver.REWARD_STARPOINT, "flag-ON normal passive roll should redirect to starpoint")
	_expect(int(normal_on.get("amount", 0)) == 1, "flag-ON normal passive roll should grant one starpoint")
	var advanced_on: Dictionary = resolver._roll_advanced_box_reward(null, null, 0.38)
	_expect(str(advanced_on.get("type", "")) == StageClearRewardResolver.REWARD_STARPOINT, "flag-ON advanced passive roll should redirect to starpoint")
	_expect(int(advanced_on.get("amount", 0)) == 2, "flag-ON advanced passive roll should grant two starpoints")


func _verify_pandora_passive_pool_gate() -> void:
	var builder := PandoraLegacyPoolBuilder.new()
	var catalog := MythicItemCatalog.new()
	var owner := FakeOwner.new()

	PerkConversionFlags.debug_set_enabled(false)
	var off_passive_pool: Array = builder.build_passive_pool(catalog, owner)
	_expect(not off_passive_pool.is_empty(), "flag-OFF Pandora passive pool should stay populated")

	PerkConversionFlags.debug_set_enabled(true)
	var on_passive_pool: Array = builder.build_passive_pool(catalog, owner)
	_expect(on_passive_pool.is_empty(), "flag-ON Pandora passive pool should be empty")

	var runtime := MythicItemRuntime.new()
	var choices: Array = runtime.generate_pandora_legacy_selection_choices(owner, FakeRegistry.new({"mythic_item_runtime": runtime}))
	_expect(choices.size() == 3, "flag-ON Pandora should still build three choices from active/mythic pools")
	_expect(_choices_are_unique(choices), "flag-ON Pandora choices should remain unique when passive pool is empty")
	for choice_value in choices:
		var choice: Dictionary = _get_dict(choice_value)
		_expect(str(choice.get("pandora_source", "")) != "passive", "flag-ON Pandora choices should not include passive-source items")


func _verify_treasure_hunt_redirect() -> void:
	PerkConversionFlags.debug_set_enabled(false)
	var off_runtime := TreasureHuntRuntime.new()
	var off_mythic_runtime := MythicItemRuntime.new()
	var off_owner := FakeOwner.new()
	var off_registry := FakeRegistry.new({
		"mythic_item_runtime": off_mythic_runtime,
		"runtime_perk_state": RuntimePerkState.new(),
		"runtime_perk_catalog": RuntimePerkCatalog.new(),
	})
	var passive_off: Dictionary = off_runtime._roll_result(off_owner, off_registry, 0.21)
	_expect(str(passive_off.get("result_type", "")) == "passive", "flag-OFF treasure passive roll should grant a passive item")
	_expect(_inventory_has_item(off_mythic_runtime, str(passive_off.get("item_name", ""))), "flag-OFF treasure passive result should enter inventory")

	PerkConversionFlags.debug_set_enabled(true)
	var on_runtime := TreasureHuntRuntime.new()
	var on_mythic_runtime := MythicItemRuntime.new()
	var on_perk_state := RuntimePerkState.new()
	var on_owner := FakeOwner.new()
	var on_registry := FakeRegistry.new({
		"mythic_item_runtime": on_mythic_runtime,
		"runtime_perk_state": on_perk_state,
		"runtime_perk_catalog": RuntimePerkCatalog.new(),
	})
	var starpoint_on: Dictionary = on_runtime._roll_result(on_owner, on_registry, 0.21)
	_expect(str(starpoint_on.get("result_type", "")) == "starpoint", "flag-ON treasure passive roll should redirect to starpoint")
	_expect(int(starpoint_on.get("amount", 0)) == 1, "flag-ON treasure passive roll should grant one starpoint")
	_expect(on_mythic_runtime.get_snapshot().get("inventory_items", []).is_empty(), "flag-ON treasure passive roll should not grant passive inventory")
	_expect(int(on_perk_state.pending_skill_choices) == 1, "flag-ON treasure starpoint should enter runtime perk progression")

	var missing_state_runtime := TreasureHuntRuntime.new()
	var missing_state_mythic_runtime := MythicItemRuntime.new()
	var missing_state_result: Dictionary = missing_state_runtime._roll_result(FakeOwner.new(), FakeRegistry.new({
		"mythic_item_runtime": missing_state_mythic_runtime,
	}), 0.21)
	_expect(str(missing_state_result.get("result_type", "")) != "passive", "flag-ON treasure passive roll should not fall back to passive when perk state is missing")
	_expect(missing_state_mythic_runtime.get_snapshot().get("inventory_items", []).is_empty(), "flag-ON treasure missing-state fallback should not grant passive inventory")

	var mythic_off_runtime := TreasureHuntRuntime.new()
	var mythic_off_equipment := MythicItemRuntime.new()
	PerkConversionFlags.debug_set_enabled(false)
	var mythic_off: Dictionary = mythic_off_runtime._roll_result(FakeOwner.new(), FakeRegistry.new({
		"mythic_item_runtime": mythic_off_equipment,
		"runtime_perk_state": RuntimePerkState.new(),
	}), 0.0)
	PerkConversionFlags.debug_set_enabled(true)
	var mythic_on_runtime := TreasureHuntRuntime.new()
	var mythic_on_equipment := MythicItemRuntime.new()
	var mythic_on: Dictionary = mythic_on_runtime._roll_result(FakeOwner.new(), FakeRegistry.new({
		"mythic_item_runtime": mythic_on_equipment,
		"runtime_perk_state": RuntimePerkState.new(),
		"runtime_perk_catalog": RuntimePerkCatalog.new(),
	}), 0.0)
	_expect(str(mythic_off.get("result_type", "")) == "legendary", "flag-OFF treasure mythic roll should stay legendary")
	_expect(str(mythic_on.get("result_type", "")) == "legendary", "flag-ON treasure mythic roll should stay legendary")


func _count_spawn_groups(candidates: Array) -> Dictionary:
	var counts := {
		"active": 0,
		"passive": 0,
		"mythic": 0,
	}
	for value in candidates:
		var item: Dictionary = _get_dict(value)
		var group := _get_item_group(item)
		counts[group] = int(counts.get(group, 0)) + 1
	return counts


func _get_item_group(item_data: Dictionary) -> String:
	var item_type := str(item_data.get("type", "active"))
	var rarity := str(item_data.get("rarity", ""))
	if item_type in ["mythic", "legendary"] or rarity in ["mythic", "legendary"]:
		return "mythic"
	if item_type == "passive":
		return "passive"
	return "active"


func _array_has_item(items: Array, item_name: String) -> bool:
	for item_value in items:
		var item: Dictionary = _get_dict(item_value)
		if str(item.get("name", "")) == item_name:
			return true
	return false


func _choices_are_unique(items: Array) -> bool:
	var names: Dictionary = {}
	for item_value in items:
		var item: Dictionary = _get_dict(item_value)
		var item_name := str(item.get("name", ""))
		if item_name == "" or names.has(item_name):
			return false
		names[item_name] = true
	return true


func _inventory_has_item(runtime: Object, item_name: String) -> bool:
	if item_name == "":
		return false
	for item_value in runtime.get_snapshot().get("inventory_items", []):
		var item: Dictionary = _get_dict(item_value)
		if str(item.get("name", "")) == item_name:
			return true
	return false


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
