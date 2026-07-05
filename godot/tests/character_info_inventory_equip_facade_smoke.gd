extends SceneTree

# Seals the slot-targeted equip / swap / auto-equip facade APIs that back the
# character-info drag-and-drop + right-click-auto-equip port (original
# PingFighter parity). Reverse-verify by breaking any single asserted branch in
# mythic_item_equipment_facade.gd / mythic_item_equipment_index.gd.

const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const MythicItemRagnarokRuntime := preload("res://scripts/items/mythic_item_ragnarok_runtime.gd")


class FakeOwner:
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}

	func queue_redraw() -> void:
		pass


class SpyRagnarokRuntime:
	extends MythicItemRagnarokRuntime

	var clear_calls := 0

	func clear_runtime(runtime: Object, registry: Object) -> void:
		clear_calls += 1
		super(runtime, registry)


func _init() -> void:
	_verify_equip_to_specific_slot()
	_verify_incompatible_slot_rejected()
	_verify_slot_swap()
	_verify_occupied_slot_auto_replaces()
	_verify_auto_equip_into_empty_slot()
	_verify_auto_equip_swaps_when_full()
	_verify_displaced_item_runs_unequip_cleanup()
	print("character_info_inventory_equip_facade_smoke: ok")
	quit(0)


func _verify_equip_to_specific_slot() -> void:
	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var index: int = runtime.acquire_item("ragnarok_hammer", owner, null, {}, false)
	_expect(index >= 0, "ragnarok_hammer should land in the inventory without auto-equip")
	_expect(not owner.equipment_slots.has("left_arm"), "inventory-only acquire should not equip anything")
	_expect(runtime.equip_inventory_item_to_slot(index, "right_arm", owner), "slot-targeted equip should place the item in the chosen slot")
	_expect(owner.equipment_slots.has("right_arm"), "equip_inventory_item_to_slot should sync the chosen slot")
	_expect(str(owner.equipment_slots["right_arm"].get("name", "")) == "ragnarok_hammer", "the chosen slot should hold the dragged item")
	_expect(not owner.equipment_slots.has("left_arm"), "the other arm slot should stay empty")


func _verify_incompatible_slot_rejected() -> void:
	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var index: int = runtime.acquire_item("ragnarok_hammer", owner, null, {}, false)
	_expect(index >= 0, "ragnarok_hammer should land in the inventory")
	_expect(not runtime.equip_inventory_item_to_slot(index, "shoes", owner), "an arm item must not equip into the shoes slot")
	_expect(not owner.equipment_slots.has("shoes"), "a rejected equip must leave the incompatible slot empty")
	_expect(owner.equipment_slots.is_empty(), "a rejected equip must not equip the item anywhere")


func _verify_slot_swap() -> void:
	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var index_a: int = runtime.acquire_item("ragnarok_hammer", owner, null, {}, false)
	var index_b: int = runtime.acquire_item("poseidon_trident", owner, null, {}, false)
	_expect(runtime.equip_inventory_item_to_slot(index_a, "left_arm", owner), "first arm item should equip to the left arm")
	_expect(runtime.equip_inventory_item_to_slot(index_b, "right_arm", owner), "second arm item should equip to the right arm")
	_expect(runtime.swap_equipment_slots("left_arm", "right_arm", owner), "two compatible occupied slots should swap")
	_expect(str(owner.equipment_slots["left_arm"].get("name", "")) == "poseidon_trident", "swap should move the right item to the left slot")
	_expect(str(owner.equipment_slots["right_arm"].get("name", "")) == "ragnarok_hammer", "swap should move the left item to the right slot")


func _verify_occupied_slot_auto_replaces() -> void:
	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var index_a: int = runtime.acquire_item("ragnarok_hammer", owner, null, {}, false)
	var index_b: int = runtime.acquire_item("poseidon_trident", owner, null, {}, false)
	_expect(runtime.equip_inventory_item_to_slot(index_a, "left_arm", owner), "occupant should equip to the left arm")
	_expect(runtime.equip_inventory_item_to_slot(index_b, "left_arm", owner), "dropping a second item on an occupied slot should replace the occupant")
	_expect(str(owner.equipment_slots["left_arm"].get("name", "")) == "poseidon_trident", "the new item should own the slot after replace")
	_expect(str(_get_inventory_slot(runtime, index_a)) == "", "the displaced occupant should be unequipped")


func _verify_auto_equip_into_empty_slot() -> void:
	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var index: int = runtime.acquire_item("ragnarok_hammer", owner, null, {}, false)
	_expect(runtime.auto_equip_inventory_item(index, owner), "auto-equip should equip into a free compatible slot")
	_expect(owner.equipment_slots.has("left_arm"), "auto-equip should prefer the first empty enabled candidate (left arm)")
	_expect(str(owner.equipment_slots["left_arm"].get("name", "")) == "ragnarok_hammer", "auto-equip should place the item in the empty slot")


func _verify_auto_equip_swaps_when_full() -> void:
	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var index_a: int = runtime.acquire_item("ragnarok_hammer", owner, null, {}, false)
	var index_b: int = runtime.acquire_item("poseidon_trident", owner, null, {}, false)
	_expect(runtime.equip_inventory_item_to_slot(index_a, "left_arm", owner), "fill the left arm")
	_expect(runtime.equip_inventory_item_to_slot(index_b, "right_arm", owner), "fill the right arm")
	var index_c: int = runtime.acquire_item("master", owner, null, {}, false)
	_expect(runtime.auto_equip_inventory_item(index_c, owner), "auto-equip into full arms should swap-replace the first enabled candidate")
	_expect(str(owner.equipment_slots["left_arm"].get("name", "")) == "master", "auto-equip should replace the first enabled candidate (left arm) when all are full")


func _verify_displaced_item_runs_unequip_cleanup() -> void:
	# Replacing an equipped runtime-state item must run that item's unequip
	# cleanup, not just clear its equipped flags.
	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var index_ragnarok: int = runtime.acquire_item("ragnarok_hammer", owner, null, {}, false)
	var index_poseidon: int = runtime.acquire_item("poseidon_trident", owner, null, {}, false)
	_expect(index_ragnarok >= 0 and index_poseidon >= 0, "both arm items should land in the inventory")
	_expect(runtime.equip_inventory_item_to_slot(index_ragnarok, "left_arm", owner), "ragnarok should equip to the left arm")
	# Swap in a spy AFTER the initial equip so we only observe the displacement cleanup.
	var spy := SpyRagnarokRuntime.new()
	runtime.ragnarok_runtime = spy
	_expect(runtime.equip_inventory_item_to_slot(index_poseidon, "left_arm", owner), "poseidon should equip onto the occupied left arm, displacing ragnarok")
	_expect(str(owner.equipment_slots["left_arm"].get("name", "")) == "poseidon_trident", "the displacing item should own the slot")
	_expect(str(_get_inventory_slot(runtime, index_ragnarok)) == "", "the displaced item should be unequipped")
	_expect(spy.clear_calls == 1, "displacing an equipped runtime-state item should run its unequip cleanup exactly once")


func _get_inventory_slot(runtime: Object, index: int) -> String:
	var items: Array = runtime.inventory_items
	if index < 0 or index >= items.size():
		return ""
	var item_data: Dictionary = items[index] if items[index] is Dictionary else {}
	return str(item_data.get("_equipped_slot", ""))


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
