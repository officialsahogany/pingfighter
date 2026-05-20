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
	var mythic_reward: Dictionary = resolver.roll_reward("mythic")
	_expect(str(mythic_reward.get("type", "")) == "mythic", "mythic boxes should roll a mythic reward")
	_expect(str(mythic_reward.get("item_name", "")) != "", "mythic reward should carry a grantable item name")
	_expect(str(mythic_reward.get("icon_path", "")) != "", "mythic reward should expose the real item icon path")

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
			_expect(amount == 1, "stage-clear starpoint rewards should grant one perk choice")
		else:
			_expect(str(normal_reward.get("icon_path", "")) != "", "item rewards should expose the real item icon path")
	_expect(int(normal_counts["mythic"]) > 0, "normal boxes should be able to roll mythic rewards")


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
