extends SceneTree

const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const ActiveItemFieldSpawnController := preload("res://scripts/items/active_item_field_spawn_controller.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const TreasureHuntRuntime := preload("res://scripts/items/treasure_hunt_runtime.gd")


class FakeOwner:
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var megingjord_equipped := false
	var dowsing_pendulum_equipped := false
	var dowsing_pendulum_range := 0.0
	var dowsing_pendulum_context: Dictionary = {}
	var accessory_slot_count := 2
	var runtime_accessory_slot_bonus := 0
	var runtime_perk_levels: Dictionary = {}
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var player_pos := Vector2(300.0, 700.0)

	func queue_redraw() -> void:
		pass


class FakeRegistry:
	var mythic_runtime: Object
	var runtime_perk_state: Object

	func _init(mythic: Object, perks: Object) -> void:
		mythic_runtime = mythic
		runtime_perk_state = perks

	func get_instance(key: String) -> Object:
		if key == "mythic_item_runtime":
			return mythic_runtime
		if key == "runtime_perk_state":
			return runtime_perk_state
		return null


func _init() -> void:
	var catalog := RuntimePerkCatalog.new()
	var treasure_map_data: Dictionary = catalog.get_perk_data("downtown_treasure_map")
	_expect(str(treasure_map_data.get("name", "")) == "보물지도", "catalog should register Treasure Map")
	_expect(int(treasure_map_data.get("max_level", 0)) == 5, "Treasure Map should have five levels")
	_expect(
		str(treasure_map_data.get("detail", "")).find("보물탐색") >= 0,
		"Treasure Map tooltip should mention Treasure Hunt synergy"
	)

	var perk_state := RuntimePerkState.new()
	perk_state.runtime_skill_levels["downtown_treasure_map"] = 5
	_expect_close(
		perk_state.get_downtown_treasure_map_field_mythic_multiplier(),
		8.5,
		"Lv.5 field mythic multiplier should match Python"
	)
	_expect_close(
		perk_state.get_downtown_treasure_map_passive_drop_share_bonus(),
		0.15,
		"Lv.5 passive drop-share bonus should match Python"
	)
	_expect_close(
		perk_state.get_treasure_hunt_legendary_chance(0.20),
		0.35,
		"Lv.5 treasure hunt legendary chance should match Python"
	)

	perk_state.runtime_skill_levels["downtown_treasure_map"] = 6
	_expect_close(
		perk_state.get_treasure_hunt_legendary_chance(0.20),
		0.38,
		"effective Lv.6 treasure hunt chance should keep scaling"
	)

	var treasure_runtime := TreasureHuntRuntime.new()
	var mythic_runtime := MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(mythic_runtime, perk_state)

	var field_spawn_controller := ActiveItemFieldSpawnController.new()
	var level6_shares: Dictionary = field_spawn_controller._get_spawn_group_target_shares(
		{"active": 1.0, "passive": 1.0, "mythic": 1.0},
		registry
	)
	_expect_close(
		float(level6_shares.get("active", 0.0)),
		0.52,
		"field spawn should read the canonical Lv.6 Treasure Map helper for active share"
	)
	_expect_close(
		float(level6_shares.get("passive", 0.0)),
		0.38,
		"field spawn should read the canonical Lv.6 Treasure Map helper for passive share"
	)
	_expect_close(
		float(level6_shares.get("mythic", 0.0)),
		0.10,
		"field spawn should read the canonical Lv.6 Treasure Map helper for mythic share"
	)

	_expect_close(
		treasure_runtime._get_legendary_chance(registry),
		0.38,
		"treasure hunt runtime should read the canonical effective-level helper"
	)
	_expect(
		treasure_runtime._get_mythic_reward_pool().has("megingjord"),
		"treasure hunt mythic pool should include ported mythics"
	)
	_expect(
		treasure_runtime._get_passive_reward_pool().has("dowsing_pendulum"),
		"treasure hunt passive pool should include ported passives"
	)

	var passive_result: Dictionary = treasure_runtime._grant_passive_or_mythic_reward(
		"dowsing_pendulum",
		"passive",
		owner,
		registry
	)
	_expect(bool(passive_result.get("ok", false)), "treasure hunt should grant passive rewards")
	_expect(_inventory_has_item(mythic_runtime, "dowsing_pendulum"), "passive treasure reward should enter passive inventory")

	var mythic_result: Dictionary = treasure_runtime._grant_passive_or_mythic_reward(
		"megingjord",
		"legendary",
		owner,
		registry
	)
	_expect(bool(mythic_result.get("ok", false)), "treasure hunt should grant mythic rewards")
	_expect(_inventory_has_item(mythic_runtime, "megingjord"), "mythic treasure reward should enter passive inventory")

	print("treasure_map_perk_port_smoke: ok")
	quit(0)


func _inventory_has_item(runtime: Object, item_name: String) -> bool:
	var snapshot: Dictionary = runtime.get_snapshot()
	var inventory: Array = snapshot.get("inventory_items", [])
	for item_value in inventory:
		if item_value is Dictionary and str(item_value.get("name", "")) == item_name:
			return true
	return false


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
