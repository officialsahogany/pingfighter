extends SceneTree

const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const GameplayCoreModuleCatalog := preload("res://scripts/resources/gameplay_core_module_catalog.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const StageClearRewardResolver := preload("res://scripts/core/stage_clear_reward_resolver.gd")

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

	func _init(new_instances: Dictionary) -> void:
		instances = new_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	_verify_module_registration()
	_verify_roll_contract()
	_verify_normal_box_reward_odds()
	_verify_grant_paths()
	_verify_result_box_mythic_grant_starts_acquisition_cinematic()

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
	_expect(resolver._resolve_advanced_box_reward_type(0.0) == "mythic", "advanced boxes should map the low 3 percent to mythic items")
	_expect(resolver._resolve_advanced_box_reward_type(0.029) == "mythic", "advanced box mythic range should end before 3 percent")
	_expect(resolver._resolve_advanced_box_reward_type(0.03) == "advanced_starpoint_2", "advanced boxes should map the next 25 percent to two-starpoint rewards")
	_expect(resolver._resolve_advanced_box_reward_type(0.279) == "advanced_starpoint_2", "advanced box two-starpoint range should end before 28 percent")
	_expect(resolver._resolve_advanced_box_reward_type(0.28) == "advanced_starpoint_3", "advanced boxes should map the next 10 percent to three-starpoint rewards")
	_expect(resolver._resolve_advanced_box_reward_type(0.379) == "advanced_starpoint_3", "advanced box three-starpoint range should end before 38 percent")
	_expect(resolver._resolve_advanced_box_reward_type(0.38) == "passive", "advanced boxes should map the upper 62 percent to passive items")
	_expect(str(resolver.roll_reward("advanced").get("type", "")) in ["mythic", "starpoint", "passive"], "advanced box kind should be accepted by the resolver")
	_expect(str(resolver.roll_reward("mythic").get("type", "")) in ["mythic", "starpoint", "passive"], "legacy box-kind alias should remain accepted")
	var guaranteed_reward: Dictionary = resolver.roll_reward("guaranteed_mythic")
	_expect(str(guaranteed_reward.get("type", "")) == "mythic", "guaranteed mythic boxes should always roll a mythic item")
	_expect(str(guaranteed_reward.get("item_name", "")) != "", "guaranteed mythic reward should carry a grantable item name")
	_expect(str(guaranteed_reward.get("icon_path", "")) != "", "guaranteed mythic reward should expose the real item icon path")

	var mythic_reward: Dictionary = resolver._roll_advanced_box_reward(null, null, 0.0)
	_expect(str(mythic_reward.get("type", "")) == "mythic", "advanced box low roll should return a mythic item reward")
	_expect(str(mythic_reward.get("item_name", "")) != "", "mythic item reward should carry a grantable item name")
	_expect(str(mythic_reward.get("icon_path", "")) != "", "mythic item reward should expose the real item icon path")
	var starpoint_double_reward: Dictionary = resolver._roll_advanced_box_reward(null, null, 0.03)
	_expect(str(starpoint_double_reward.get("type", "")) == "starpoint", "advanced box middle roll should return starpoints")
	_expect(int(starpoint_double_reward.get("amount", 0)) == 2, "advanced box two-starpoint reward should grant two points")
	var starpoint_triple_reward: Dictionary = resolver._roll_advanced_box_reward(null, null, 0.28)
	_expect(str(starpoint_triple_reward.get("type", "")) == "starpoint", "advanced box upper-middle roll should return starpoints")
	_expect(int(starpoint_triple_reward.get("amount", 0)) == 3, "advanced box three-starpoint reward should grant three points")
	var passive_reward: Dictionary = resolver._roll_advanced_box_reward(null, null, 0.38)
	_expect(str(passive_reward.get("type", "")) == "passive", "advanced box high roll should return a passive item")
	_expect(str(passive_reward.get("item_name", "")) != "", "advanced box passive reward should carry a grantable item name")
	_expect(str(passive_reward.get("icon_path", "")) != "", "advanced box passive reward should expose the real item icon path")

	var normal_counts := {
		"active": 0,
		"passive": 0,
		"starpoint": 0,
		"mythic": 0,
	}
	for _i in range(400):
		var normal_reward: Dictionary = resolver.roll_reward("normal")
		var reward_type: String = str(normal_reward.get("type", ""))
		_expect(
			reward_type in ["active", "passive", "starpoint", "mythic"],
			"normal box should roll active, passive, starpoint, or mythic rewards"
		)
		if normal_counts.has(reward_type):
			normal_counts[reward_type] = int(normal_counts[reward_type]) + 1
		if reward_type == "starpoint":
			var amount: int = int(normal_reward.get("amount", 0))
			_expect(amount == 1, "normal box starpoint rewards should grant exactly one perk choice")
		else:
			_expect(str(normal_reward.get("icon_path", "")) != "", "item rewards should expose the real item icon path")
	var normal_mythic_reward: Dictionary = resolver._roll_normal_box_reward(null, null, 0.99)
	_expect(str(normal_mythic_reward.get("type", "")) == "mythic", "normal box upper range should return a mythic item")
	_expect(str(normal_mythic_reward.get("item_name", "")) != "", "normal box mythic reward should carry a grantable item name")
	_expect(str(normal_mythic_reward.get("icon_path", "")) != "", "normal box mythic reward should expose the real item icon path")


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
	var resolver: Object = StageClearRewardResolver.new()
	var summary: Dictionary = resolver.grant_rewards([
		{"type": "active", "item_name": "gauge_charge", "label": "Gauge Charge"},
		{"type": "passive", "item_name": "speedboots", "label": "Speed Boots", "rolls": {"speed_bonus_pct": 10.0}, "item_data": speedboots},
		{"type": "mythic", "item_name": "megingjord", "label": "Megingjord", "rolls": {"extra_pick_chance": 40.0}, "item_data": megingjord},
		{"type": "starpoint", "label": "★ 1", "amount": 1},
	], owner, registry)

	_expect(int(summary.get("attempted", 0)) == 4, "grant summary should count all staged rewards")
	_expect(int(summary.get("granted", 0)) == 4, "grant summary should count all successful grants")
	_expect(owner.active_item_slots.size() == 1, "active rewards should enter active item slots")
	_expect(str(owner.active_item_slots[0].get("name", "")) == "gauge_charge", "active reward should preserve item identity")
	_expect(mythic_runtime.has_owned_item_name("speedboots"), "passive reward should enter mythic/passive runtime inventory")
	_expect(mythic_runtime.has_owned_item_name("megingjord"), "mythic reward should enter mythic/passive runtime inventory")
	_expect(bool(perk_state.is_choice_active()), "starpoint reward should open the runtime perk choice flow")
	_expect(owner.runtime_perk_pending_choices == 1, "starpoint reward should sync one pending perk choice to the owner")


func _verify_result_box_mythic_grant_starts_acquisition_cinematic() -> void:
	var mythic_runtime: Object = MythicItemRuntime.new()
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
	owner.queue_free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
