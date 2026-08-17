extends SceneTree

const ActiveItemSlotController := preload("res://scripts/items/active_item_slot_controller.gd")
const CharacterInfoOverlayStatsPresenter := preload("res://scripts/hud/character_info_overlay_stats_presenter.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


class FakeRegistry:
	var runtime_perk_state: Object

	func _init(perk_state: Object) -> void:
		runtime_perk_state = perk_state

	func get_instance(key: String) -> Object:
		if key == "runtime_perk_state":
			return runtime_perk_state
		return null


class StorePolicy:
	func can_store_item(_item_name: String) -> bool:
		return true


func _init() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	_verify_capacity_and_slot_controller_share_the_same_total()
	_verify_linked_arsenal_requires_linked_step()
	if _failures.is_empty():
		print("perk_fusion_active_item_slot_byproducts_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_capacity_and_slot_controller_share_the_same_total() -> void:
	var state: Object = RuntimePerkState.new()
	state.runtime_skill_levels.merge({
		"item_luck": 5,
		"common_bulk_up": 5,
		"dash_amplification": 3,
	}, true)
	var record: Dictionary = state.commit_perk_fusion(
		["item_luck", "common_bulk_up"],
		{
			"outcome": "byproduct",
			"byproducts": ["sleeve_cosmos", "reverb", "linked_arsenal"],
		},
		RuntimePerkCatalog.new()
	)
	_expect(not record.is_empty(), "valid fusion should commit the live slot byproduct")
	_expect("sleeve_cosmos" not in (record.get("byproducts", []) as Array), "commit must prune the retired Sleevebound Cosmos from the record")
	_expect(state.get_active_item_slot_capacity(3) == 6, "base 3 + Linked Step 3 should total six slots")
	var fusion_breakdown: Dictionary = state.get_perk_fusion_active_item_slot_bonus_breakdown()
	_expect(not fusion_breakdown.has("sleeve_cosmos"), "runtime state must not expose the retired Sleevebound Cosmos bonus")
	_expect(int(fusion_breakdown.get("linked_arsenal", 0)) == 3, "runtime state should expose Linked Arsenal at the live Linked Step rank")

	var stat_breakdown: Array = CharacterInfoOverlayStatsPresenter.active_item_slot_breakdown(state, null, 3)
	var displayed_sources: Dictionary = {}
	for entry_value: Variant in stat_breakdown:
		var entry: Dictionary = entry_value as Dictionary
		displayed_sources[str(entry.get("icon_id", ""))] = str(entry.get("text", ""))
	_expect(not displayed_sources.has("item_bag_expansion"), "character info must not expose the retired bag Mugong")
	_expect(not displayed_sources.has("sleeve_cosmos"), "character info must not expose the retired Sleevebound Cosmos entry")
	_expect(str(displayed_sources.get("linked_arsenal", "")) == "+3", "character info should show the rare Linked Step scaling separately")

	var active_item_slots: Array = []
	for slot_index in range(5):
		active_item_slots.append({"name": "fixture_%d" % slot_index})
	var controller: Object = ActiveItemSlotController.new()
	var registry := FakeRegistry.new(state)
	var policy := StorePolicy.new()
	_expect(controller.store_active_item({"item_data": {"name": "sixth"}}, active_item_slots, registry, Callable(policy, "can_store_item")), "slot controller should accept the sixth item through the canonical capacity query")
	_expect(active_item_slots.size() == 6, "the sixth item should occupy the final expanded slot")
	_expect(not controller.store_active_item({"item_data": {"name": "seventh"}}, active_item_slots, registry, Callable(policy, "can_store_item")), "slot controller should reject an item beyond the computed six-slot capacity")

	state.reset()
	_expect(state.get_active_item_slot_capacity(3) == 3, "run reset should clear acquired slot arts and their capacity bonuses")


func _verify_linked_arsenal_requires_linked_step() -> void:
	var state: Object = RuntimePerkState.new()
	state.runtime_skill_levels.merge({
		"item_luck": 5,
		"common_bulk_up": 5,
	}, true)
	state.commit_perk_fusion(
		["item_luck", "common_bulk_up"],
		{
			"outcome": "byproduct",
			"byproducts": ["overload_circuit", "reverb", "linked_arsenal"],
		},
		RuntimePerkCatalog.new()
	)
	_expect(state.get_active_item_slot_capacity(3) == 3, "Linked Arsenal should add zero slots when Linked Step is unlearned")
	state.runtime_skill_levels["dash_amplification"] = 5
	_expect(state.get_active_item_slot_capacity(3) == 8, "Linked Arsenal should track the current five Linked Step ranks without reacquisition")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
