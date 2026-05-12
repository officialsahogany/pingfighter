extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemDebugInventory := preload("res://scripts/items/active_item_debug_inventory.gd")
const ActiveItemSlotController := preload("res://scripts/items/active_item_slot_controller.gd")

var _failures: Array[String] = []


class FakeHudState:
	extends RefCounted

	var selected_index := -1

	func set_selected_index(index: int) -> void:
		selected_index = index


class FakeRegistry:
	extends RefCounted

	var hud_state := FakeHudState.new()

	func get_instance(key: String) -> Object:
		if key == "active_item_hud_state":
			return hud_state
		return null


class FakeOwner:
	extends RefCounted

	var active_item_slots: Array = []


class FakeEffectGate:
	extends RefCounted

	var blocked_item_name := ""

	func can_store_item(item_name: String) -> bool:
		return item_name != blocked_item_name


func _init() -> void:
	_verify_debug_inventory()

	if _failures.is_empty():
		print("active_item_debug_inventory_direct_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_debug_inventory() -> void:
	var inventory: Object = ActiveItemDebugInventory.new()
	var catalog: Object = ActiveItemCatalog.new()
	var slot_controller: Object = ActiveItemSlotController.new()
	var effect_controller := FakeEffectGate.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()

	_expect(inventory.debug_add_item_to_slot(
		"gauge_charge",
		owner,
		registry,
		catalog,
		slot_controller,
		effect_controller
	), "debug inventory should add an active item")
	_expect(owner.active_item_slots.size() == 1, "debug inventory should append owner slot")
	_expect(registry.hud_state.selected_index == 0, "debug inventory should select the inserted slot")

	_expect(inventory.adjust_debug_item_quantity(
		"gauge_charge",
		4,
		owner,
		registry,
		catalog,
		slot_controller,
		effect_controller
	) == 2, "debug inventory should stop positive adjustment at slot capacity")
	_expect(owner.active_item_slots.size() == 3, "debug inventory should respect active slot capacity")
	_expect(int(inventory.get_debug_item_counts(owner).get("gauge_charge", 0)) == 3, "debug counts should track item names")

	_expect(inventory.grant_item_to_slot(
		"gauge_charge",
		owner,
		registry,
		catalog,
		slot_controller,
		effect_controller,
		true
	), "debug inventory should support explicit overflow grants")
	_expect(owner.active_item_slots.size() == 4, "overflow debug grant should append beyond normal capacity")

	_expect(inventory.debug_remove_item_from_slot("gauge_charge", owner, registry), "debug inventory should remove by item name")
	_expect(owner.active_item_slots.size() == 3, "debug remove should delete one matching slot")

	owner.active_item_slots.append({"name": "display_id", "effect": "effect_id"})
	_expect(inventory.debug_remove_item_from_slot("effect_id", owner, registry), "debug inventory should remove by effect id")
	_expect(not inventory.debug_remove_item_from_slot("missing_item", owner, registry), "debug inventory should reject missing remove")
	_expect(inventory.debug_remove_item_from_slot("gauge_charge", owner, registry), "debug inventory should make room before gate check")

	effect_controller.blocked_item_name = "magnet_field"
	_expect(not inventory.debug_add_item_to_slot(
		"magnet_field",
		owner,
		registry,
		catalog,
		slot_controller,
		effect_controller
	), "debug inventory should honor active-effect store gates")

	var handled: bool = inventory.apply_debug_spawn_menu_result(
		{"handled": true, "item_name": "life_elixir", "delta": -1},
		owner,
		registry,
		catalog,
		slot_controller,
		effect_controller
	)
	_expect(handled, "debug inventory should preserve handled menu result")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
