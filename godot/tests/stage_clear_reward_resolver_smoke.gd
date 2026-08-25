extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const GameplayCoreModuleCatalog := preload("res://scripts/resources/gameplay_core_module_catalog.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const StageClearRewardResolver := preload("res://scripts/core/stage_clear_reward_resolver.gd")
const TowerAscentChestContract := preload("res://scripts/tower_ascent/tower_ascent_chest_contract.gd")
const TowerAscentFeatureFlags := preload("res://scripts/tower_ascent/tower_ascent_feature_flags.gd")

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
	var runtime_perk_gold := 0
	var runtime_perk_choice_active := false
	var selected_character_type := "smasher"
	var item_perk_level_bonus := 0
	var viper_ignition_aura_active := false

	func queue_redraw() -> void:
		pass


class FakeNodeOwner:
	extends Node

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
	var runtime_perk_gold := 0
	var runtime_perk_choice_active := false
	var selected_character_type := "smasher"
	var item_perk_level_bonus := 0
	var viper_ignition_aura_active := false
	var player_pos := Vector2(302.5, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0

	func queue_redraw() -> void:
		pass


class FakeRegistry:
	var instances: Dictionary = {}

	func _init(new_instances: Dictionary = {}) -> void:
		instances = new_instances
		if not instances.has("tower_ascent_unlock_store"):
			instances["tower_ascent_unlock_store"] = FakeUnlockStore.new()

	func get_instance(key: String) -> Object:
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Object:
		return instances.get(key, null)


class FakeUnlockStore:
	extends RefCounted

	func is_unlocked(_content_type: String, _content_id: String) -> bool:
		return true


class FakeTowerFlowOwner:
	extends RefCounted
	var collected_muhon := 0

	func collect_muhon(amount: int, _owner: Object) -> Dictionary:
		collected_muhon += amount
		return {"accepted": true, "amount": amount}


class FakeCinematicMythicRuntime:
	var inventory: Array = []
	var cinematic_active := false
	var cinematic_snapshot: Dictionary = {}

	func acquire_item(
		item_name: String,
		_owner: Object,
		_registry: Object,
		_rolls: Dictionary = {},
		_auto_equip: bool = true,
		_play_feedback: bool = false,
		source_item_data: Dictionary = {}
	) -> int:
		var stored: Dictionary = source_item_data.duplicate(true)
		if stored.is_empty():
			stored = {"name": item_name, "type": "mythic", "rarity": "mythic"}
		stored["name"] = item_name
		inventory.append(stored)
		return inventory.size() - 1

	func get_inventory_item(index: int) -> Dictionary:
		if index < 0 or index >= inventory.size():
			return {}
		return (inventory[index] as Dictionary).duplicate(true)

	func has_owned_item_name(item_name: String) -> bool:
		for item in inventory:
			if item is Dictionary and str((item as Dictionary).get("name", "")) == item_name:
				return true
		return false

	func start_acquisition_cinematic(
		acquired_item_data: Dictionary,
		pickup_position: Vector2,
		_owner: Object,
		_registry: Object = null,
		target_player_center_override: Vector2 = Vector2.INF
	) -> bool:
		cinematic_active = true
		cinematic_snapshot = {
			"item_name": str(acquired_item_data.get("name", "")),
			"pickup_position": pickup_position,
			"player_center": target_player_center_override,
		}
		return true

	func is_acquisition_cinematic_active() -> bool:
		return cinematic_active

	func get_acquisition_cinematic_snapshot() -> Dictionary:
		return cinematic_snapshot.duplicate(true)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_module_registration()
	_verify_roll_contract()
	_verify_normal_box_reward_odds()
	_verify_grant_paths()
	_verify_result_box_mythic_grant_starts_acquisition_cinematic()
	_verify_result_box_mythic_active_grants_slot_and_keeps_cinematic()
	await _drain_frames(12)
	_clear_runtime_caches_for_test()
	await _drain_frames(30)

	if _failures.is_empty():
		print("stage_clear_reward_resolver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_module_registration() -> void:
	var spec: Dictionary = GameplayCoreModuleCatalog.new().get_spec("stage_clear_reward_resolver")
	_expect(
		str(spec.get("path", "")) == "res://scripts/core/stage_clear_reward_resolver.gd",
		"stage clear reward resolver should be registered in the core module catalog"
	)


func _verify_roll_contract() -> void:
	var resolver: Object = StageClearRewardResolver.new()
	var registry := FakeRegistry.new()
	_expect(TowerAscentFeatureFlags.is_vertical_slice_enabled(), "reward smoke should exercise the default flag-ON Tower lane")
	_expect(not resolver._is_advanced_box_kind("advanced"), "advanced must no longer be recognized as a live box tier")
	_expect(not resolver._is_advanced_box_kind("mythic"), "the legacy mythic alias must no longer revive the advanced tier")
	_expect(resolver._resolve_advanced_box_reward_type(0.0) == "mythic", "advanced boxes should map the low 3 percent to mythic items")
	_expect(resolver._resolve_advanced_box_reward_type(0.029) == "mythic", "advanced box mythic range should end before 3 percent")
	_expect(resolver._resolve_advanced_box_reward_type(0.03) == "advanced_starpoint_2", "advanced boxes should map the next 25 percent to two-starpoint rewards")
	_expect(resolver._resolve_advanced_box_reward_type(0.279) == "advanced_starpoint_2", "advanced box two-starpoint range should end before 28 percent")
	_expect(resolver._resolve_advanced_box_reward_type(0.28) == "advanced_starpoint_3", "advanced boxes should map the next 10 percent to three-starpoint rewards")
	_expect(resolver._resolve_advanced_box_reward_type(0.379) == "advanced_starpoint_3", "advanced box three-starpoint range should end before 38 percent")
	_expect(resolver._resolve_advanced_box_reward_type(0.38) == "passive", "advanced boxes should map the upper 62 percent to passive items")
	_expect(str(resolver.roll_reward("advanced", null, registry).get("type", "")) in ["active", "mythic", "starpoint", "passive"], "retired advanced ids should fall through to the flag-ON normal reward lane")
	_expect(str(resolver.roll_reward("mythic", null, registry).get("type", "")) in ["active", "mythic", "starpoint", "passive"], "legacy mythic ids should fall through to the flag-ON normal reward lane")
	var retired_reward: Dictionary = resolver.roll_reward("guaranteed_mythic", null, registry, 0.999999)
	_expect(str(retired_reward.get("type", "")) == "starpoint", "retired guaranteed-mythic id should follow the flag-ON normal chest lane")
	var supreme_reward: Dictionary = resolver.roll_reward(TowerAscentChestContract.CHEST_SUPREME_ART, null, registry)
	_expect(str(supreme_reward.get("type", "")) == StageClearRewardResolver.REWARD_MYTHIC_PERK_CHOICE, "supreme-art chest should use the live guaranteed mythic-perk channel")
	_expect(int(supreme_reward.get("choice_count", 0)) == 3, "supreme-art reward should preserve the three-card choice contract")

	var starpoint_double_reward: Dictionary = resolver._roll_advanced_box_reward(null, registry, 0.03)
	_expect(str(starpoint_double_reward.get("type", "")) == "starpoint", "advanced box middle roll should return starpoints")
	_expect(int(starpoint_double_reward.get("amount", 0)) == 2, "advanced box two-starpoint reward should grant two points")
	var starpoint_triple_reward: Dictionary = resolver._roll_advanced_box_reward(null, registry, 0.28)
	_expect(str(starpoint_triple_reward.get("type", "")) == "starpoint", "advanced box upper-middle roll should return starpoints")
	_expect(int(starpoint_triple_reward.get("amount", 0)) == 3, "advanced box three-starpoint reward should grant three points")
	var active_reward: Dictionary = resolver.roll_reward(TowerAscentChestContract.CHEST_NORMAL, null, registry, 0.10)
	_expect(str(active_reward.get("type", "")) == "active", "flag-ON normal chest should retain the active-item segment")
	_expect(str(active_reward.get("item_name", "")) != "", "flag-ON active reward should carry a grantable item name")
	_expect(str(active_reward.get("icon_path", "")) != "", "flag-ON active reward should expose its catalog icon path")
	var normal_starpoint: Dictionary = resolver.roll_reward(TowerAscentChestContract.CHEST_NORMAL, null, registry, 0.999999)
	_expect(str(normal_starpoint.get("type", "")) == "starpoint", "flag-ON normal chest upper range should remain in the normal starpoint lane")
	_expect(int(normal_starpoint.get("amount", 0)) == 1, "flag-ON normal chest starpoint reward should grant one Muhon unit")


func _verify_normal_box_reward_odds() -> void:
	var resolver: Object = StageClearRewardResolver.new()
	_expect(
		resolver._resolve_normal_box_reward_type(0.0) == "active",
		"normal boxes should map the low 15 percent to active items"
	)
	_expect(
		resolver._resolve_normal_box_reward_type(0.149) == "active",
		"normal box active range should end before 15 percent"
	)
	_expect(
		resolver._resolve_normal_box_reward_type(0.15) == "passive",
		"normal boxes should map the next 27 percent to passive items"
	)
	_expect(
		resolver._resolve_normal_box_reward_type(0.419) == "passive",
		"normal box passive range should end before 42 percent"
	)
	_expect(
		resolver._resolve_normal_box_reward_type(0.42) == "starpoint_1",
		"normal boxes should map the next 57 percent to one starpoint"
	)
	_expect(
		resolver._resolve_normal_box_reward_type(0.989) == "starpoint_1",
		"normal box one-starpoint range should end before 99 percent"
	)
	_expect(
		resolver._resolve_normal_box_reward_type(0.99) == "mythic",
		"normal boxes should map the upper 1 percent to mythic items"
	)
	var starpoint_one: Dictionary = resolver._roll_normal_box_reward(null, null, 0.67)
	_expect(
		str(starpoint_one.get("type", "")) == "starpoint" and int(starpoint_one.get("amount", 0)) == 1,
		"normal box one-starpoint range should grant exactly one point"
	)


func _verify_grant_paths() -> void:
	var active_runtime: Object = ActiveItemRuntime.new()
	var mythic_runtime: Object = MythicItemRuntime.new()
	var perk_state: Object = RuntimePerkState.new()
	var perk_catalog: Object = RuntimePerkCatalog.new()
	var active_catalog: Object = ActiveItemCatalog.new()
	var mythic_catalog: Object = MythicItemCatalog.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({
		"active_item_runtime": active_runtime,
		"mythic_item_runtime": mythic_runtime,
		"runtime_perk_state": perk_state,
		"runtime_perk_catalog": perk_catalog,
	})

	var speedboots: Dictionary = mythic_catalog.build_item_by_name("speedboots")
	var megingjord: Dictionary = mythic_catalog.build_item_by_name("megingjord")
	var elixir_of_mastery: Dictionary = active_catalog.build_item_by_name("elixir_of_mastery")
	_expect(str(speedboots.get("icon_path", "")) != "", "passive catalog reward should expose the real item icon path")
	_expect(str(megingjord.get("icon_path", "")) != "", "mythic catalog reward should expose the real item icon path")
	_expect(str(elixir_of_mastery.get("icon_path", "")) != "", "mythic-rarity active reward should expose the real item icon path")
	var tower_flow_owner := FakeTowerFlowOwner.new()
	registry.instances["tower_ascent_flow_owner"] = tower_flow_owner
	var resolver: Object = StageClearRewardResolver.new()
	var summary: Dictionary = resolver.grant_rewards([
		{"type": "active", "item_name": "gauge_charge", "label": "Gauge Charge"},
		{"type": "passive", "item_name": "speedboots", "label": "Speed Boots", "rolls": {"speed_bonus_pct": 10.0}, "item_data": speedboots},
		{"type": "mythic", "item_name": "megingjord", "label": "Megingjord", "rolls": {"extra_pick_chance": 40.0}, "item_data": megingjord},
		{"type": "mythic", "item_name": "elixir_of_mastery", "label": "Daeseong Yeongdan", "item_data": elixir_of_mastery},
		{"type": "starpoint", "label": "★ 1", "amount": 1},
	], owner, registry)

	_expect(int(summary.get("attempted", 0)) == 5, "grant summary should count all staged rewards")
	_expect(int(summary.get("granted", 0)) == 5, "grant summary should count all successful grants")
	_expect(int(summary.get("active_granted", 0)) == 2, "grant summary should count mythic-rarity active items as active grants")
	_expect(int(summary.get("mythic_granted", 0)) == 1, "grant summary should reserve mythic grants for equipment inventory")
	_expect(owner.active_item_slots.size() == 2, "active rewards should enter active item slots")
	_expect(str(owner.active_item_slots[0].get("name", "")) == "gauge_charge", "active reward should preserve item identity")
	_expect(str(owner.active_item_slots[1].get("name", "")) == "elixir_of_mastery", "mythic-lane Daeseong Yeongdan reward should enter an active slot")
	_expect(mythic_runtime.has_owned_item_name("speedboots"), "passive reward should enter mythic/passive runtime inventory")
	_expect(mythic_runtime.has_owned_item_name("megingjord"), "mythic reward should enter mythic/passive runtime inventory")
	_expect(not mythic_runtime.has_owned_item_name("elixir_of_mastery"), "Daeseong Yeongdan reward should not enter mythic equipment inventory")
	_expect(not bool(perk_state.is_choice_active()), "flag-ON starpoint reward should not reopen the retired battle choice flow")
	_expect(owner.runtime_perk_pending_choices == 0, "flag-ON starpoint reward should leave pending perk choices untouched")
	_expect(tower_flow_owner.collected_muhon == 1, "flag-ON starpoint reward should collect exactly one Muhon through the cached Tower owner")
	active_runtime.reset()
	mythic_runtime.reset()
	perk_state.reset()
	registry.instances.clear()


func _verify_result_box_mythic_grant_starts_acquisition_cinematic() -> void:
	var mythic_runtime: Object = FakeCinematicMythicRuntime.new()
	var mythic_catalog: Object = MythicItemCatalog.new()
	var owner := FakeNodeOwner.new()
	root.add_child(owner)
	var registry := FakeRegistry.new({
		"mythic_item_runtime": mythic_runtime,
	})
	var heavenly_cape: Dictionary = mythic_catalog.build_item_by_name("heavenly_cape")
	var resolver: Object = StageClearRewardResolver.new()
	var summary: Dictionary = resolver.grant_rewards([
		{
			"type": "mythic",
			"item_name": "heavenly_cape",
			"label": "Heavenly Cape",
			"item_data": heavenly_cape,
			"show_acquisition_cinematic": true,
			"pickup_position": Vector2(240.0, 310.0),
			"target_player_center": Vector2(610.0, 280.0),
		},
	], owner, registry)

	_expect(int(summary.get("granted", 0)) == 1, "result mythic reward should still grant inventory ownership")
	_expect(mythic_runtime.has_owned_item_name("heavenly_cape"), "result mythic reward should enter mythic runtime inventory")
	_expect(
		bool(mythic_runtime.is_acquisition_cinematic_active()),
		"result mythic reward should start the field acquisition cinematic"
	)
	var snapshot: Dictionary = mythic_runtime.get_acquisition_cinematic_snapshot()
	_expect(str(snapshot.get("item_name", "")) == "heavenly_cape", "acquisition cinematic should use the acquired mythic item")
	_expect(
		snapshot.get("player_center", Vector2.ZERO) == Vector2(610.0, 280.0),
		"result mythic acquisition cinematic should honor the result Live2D absorb target"
	)
	_cleanup_mythic_runtime_owner(mythic_runtime, registry, owner)


func _verify_result_box_mythic_active_grants_slot_and_keeps_cinematic() -> void:
	var active_runtime: Object = ActiveItemRuntime.new()
	var active_catalog: Object = ActiveItemCatalog.new()
	var mythic_runtime: Object = FakeCinematicMythicRuntime.new()
	var owner := FakeNodeOwner.new()
	root.add_child(owner)
	var registry := FakeRegistry.new({
		"active_item_runtime": active_runtime,
		"mythic_item_runtime": mythic_runtime,
	})
	var resolver: Object = StageClearRewardResolver.new()
	var summary: Dictionary = resolver.grant_rewards([
		{
			"type": "mythic",
			"item_name": "elixir_of_mastery",
			"label": "Daeseong Yeongdan",
			"item_data": active_catalog.build_item_by_name("elixir_of_mastery"),
			"show_acquisition_cinematic": true,
			"pickup_position": Vector2(260.0, 320.0),
			"target_player_center": Vector2(610.0, 280.0),
		},
	], owner, registry)

	_expect(int(summary.get("granted", 0)) == 1, "result mythic-active reward should be granted")
	_expect(owner.active_item_slots.size() == 1, "result mythic-active reward should append an active slot")
	_expect(str(owner.active_item_slots[0].get("name", "")) == "elixir_of_mastery", "result reward should preserve Daeseong Yeongdan identity")
	_expect(mythic_runtime.inventory.is_empty(), "result mythic-active reward should not enter equipment inventory")
	_expect(mythic_runtime.is_acquisition_cinematic_active(), "result mythic-active reward should retain its acquisition cinematic")
	var snapshot: Dictionary = mythic_runtime.get_acquisition_cinematic_snapshot()
	_expect(str(snapshot.get("item_name", "")) == "elixir_of_mastery", "mythic-active acquisition cinematic should use Daeseong Yeongdan")
	_expect(snapshot.get("player_center", Vector2.ZERO) == Vector2(610.0, 280.0), "mythic-active acquisition cinematic should retain its target")

	active_runtime.reset()
	_cleanup_mythic_runtime_owner(mythic_runtime, registry, owner)


func _drain_frames(frame_count: int) -> void:
	for _i in range(frame_count):
		await process_frame


func _clear_runtime_caches_for_test() -> void:
	ProjectResourceLoader.clear_caches()


func _cleanup_mythic_runtime_owner(runtime: Object, registry: Object, owner: Node) -> void:
	if runtime != null and runtime.has_method("reset_round"):
		runtime.reset_round(registry)
	if runtime != null:
		var cinematic: Variant = runtime.get("acquisition_cinematic")
		if cinematic != null:
			runtime.set("acquisition_cinematic", null)
		if cinematic is Node and is_instance_valid(cinematic):
			(cinematic as Node).free()
	if owner != null:
		owner.queue_free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
