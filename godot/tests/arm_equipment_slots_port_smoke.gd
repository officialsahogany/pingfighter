extends SceneTree

const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")


class FakeOwner:
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}

	func queue_redraw() -> void:
		pass


func _init() -> void:
	var catalog: Object = MythicItemCatalog.new()
	_expect(str(catalog.build_item_by_name("ragnarok_hammer").get("slot", "")) == "arm", "Ragnarok Hammer should use the shared arm slot family")
	_expect(str(catalog.build_item_by_name("poseidon_trident").get("slot", "")) == "arm", "Poseidon Trident should use the shared arm slot family")
	var arm_items: Array = _get_arm_item_names(catalog)
	_expect(arm_items.has("master"), "Master should be classified as a shared arm item")
	_expect(arm_items.has("smartphone"), "Smartphone should be classified as a shared arm item")
	_expect(arm_items.has("gold_digger"), "Gold Digger should be classified as a shared arm item")
	_expect(arm_items.has("venom_mist_gauntlet"), "Venom Mist Gauntlet should be classified as a shared arm item")
	_expect(arm_items.has("reinforced_boomerang_gauntlet"), "Reinforced Boomerang Gauntlet should be classified as a shared arm item")
	_expect(arm_items.has("commando_arm"), "Commando Arm should be classified as a shared arm item")
	_expect(arm_items.has("rainbow_fur_glove"), "Rainbow Fur Glove should be classified as a shared arm item")
	_expect(arm_items.has("ragnarok_hammer"), "Ragnarok Hammer should be classified as a shared arm item")
	_expect(arm_items.has("poseidon_trident"), "Poseidon Trident should be classified as a shared arm item")
	_expect(arm_items.size() == 9, "all current Godot arm items should be covered by this smoke test")

	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()

	_expect(runtime.equip_item("ragnarok_hammer", owner, null, {}, false), "first arm item should equip")
	_expect(runtime.equip_item("poseidon_trident", owner, null, {}, false), "second arm item should equip")

	_expect(owner.equipment_slots.has("left_arm"), "first arm item should sync into the left arm slot")
	_expect(owner.equipment_slots.has("right_arm"), "second arm item should sync into the right arm slot")
	_expect(str(owner.equipment_slots["left_arm"].get("name", "")) == "ragnarok_hammer", "Ragnarok Hammer should remain equipped on the left arm")
	_expect(str(owner.equipment_slots["right_arm"].get("name", "")) == "poseidon_trident", "Poseidon Trident should equip on the right arm")
	_expect(str(owner.equipment_slots["left_arm"].get("_equipped_slot", "")) == "left_arm", "left arm sync should expose the resolved slot key")
	_expect(str(owner.equipment_slots["right_arm"].get("_equipped_slot", "")) == "right_arm", "right arm sync should expose the resolved slot key")

	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(bool(snapshot.get("ragnarok_hammer_equipped", false)), "snapshot should keep Ragnarok Hammer equipped")
	_expect(bool(snapshot.get("poseidon_trident_equipped", false)), "snapshot should keep Poseidon Trident equipped")

	_expect(not runtime.equip_item("master", owner, null, {}, false), "third shared arm item should fail when both arm slots are full")
	_expect(owner.equipment_slots.size() == 2, "failed third arm equip should not replace either equipped arm item")

	for i in range(arm_items.size()):
		for j in range(arm_items.size()):
			if i == j:
				continue
			_expect_pair_equips_to_both_arms(str(arm_items[i]), str(arm_items[j]))

	print("arm_equipment_slots_port_smoke: ok")
	quit(0)


func _get_arm_item_names(catalog: Object) -> Array:
	var result: Array = []
	for item_value in catalog.get_debug_items():
		var item_data: Dictionary = item_value if item_value is Dictionary else {}
		if item_data.is_empty():
			continue
		var item_name: String = str(item_data.get("name", ""))
		var slot_key: String = str(item_data.get("slot", ""))
		_expect(slot_key != "left_arm" and slot_key != "right_arm", "%s should use 'arm' so runtime can resolve left/right placement" % item_name)
		if slot_key == "arm":
			result.append(item_name)
	return result


func _expect_pair_equips_to_both_arms(first_item: String, second_item: String) -> void:
	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	_expect(runtime.equip_item(first_item, owner, null, {}, false), "%s should equip as the first arm item" % first_item)
	_expect(runtime.equip_item(second_item, owner, null, {}, false), "%s should equip as the second arm item" % second_item)
	_expect(owner.equipment_slots.has("left_arm"), "%s + %s should fill the left arm slot" % [first_item, second_item])
	_expect(owner.equipment_slots.has("right_arm"), "%s + %s should fill the right arm slot" % [first_item, second_item])
	_expect(str(owner.equipment_slots["left_arm"].get("name", "")) == first_item, "%s should remain in the left arm slot" % first_item)
	_expect(str(owner.equipment_slots["right_arm"].get("name", "")) == second_item, "%s should equip in the right arm slot" % second_item)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
