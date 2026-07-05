extends RefCounted


func rebuild_equipped_items(runtime: Object, constants: Dictionary) -> void:
	runtime.equipped_items.clear()
	for i in range(runtime.inventory_items.size()):
		var item_data: Dictionary = runtime._get_dict(runtime.inventory_items[i])
		if item_data.is_empty():
			continue
		var item_name: String = str(item_data.get("name", ""))
		if item_name == "":
			continue
		if bool(item_data.get("equipped", false)) or str(item_data.get("_equipped_slot", "")) != "":
			if is_single_equipment_item(item_name, constants) and runtime.equipped_items.has(item_name):
				item_data["equipped"] = false
				item_data["_equipped_slot"] = ""
				runtime.inventory_items[i] = item_data
				continue
			runtime.equipped_items[item_name] = item_data.duplicate(true)


func is_single_equipment_item(item_name: String, constants: Dictionary) -> bool:
	return item_name == str(constants.get("item_smartphone", "smartphone"))


func is_item_equipped(runtime: Object, item_name: String) -> bool:
	return runtime.equipped_items.has(item_name)


func find_inventory_index_by_name(runtime: Object, item_name: String) -> int:
	for i in range(runtime.inventory_items.size()):
		var item_data: Dictionary = runtime._get_dict(runtime.inventory_items[i])
		if str(item_data.get("name", "")) == item_name:
			return i
	return -1


func find_equipped_inventory_index_by_name(runtime: Object, item_name: String) -> int:
	for i in range(runtime.inventory_items.size()):
		var item_data: Dictionary = runtime._get_dict(runtime.inventory_items[i])
		if str(item_data.get("name", "")) != item_name:
			continue
		if bool(item_data.get("equipped", false)) or str(item_data.get("_equipped_slot", "")) != "":
			return i
	return -1


func find_equipped_inventory_index_by_slot(runtime: Object, slot_key: String) -> int:
	var canonical_slot_key: String = canonical_equipment_slot_key(slot_key)
	for i in range(runtime.inventory_items.size()):
		var item_data: Dictionary = runtime._get_dict(runtime.inventory_items[i])
		if canonical_equipment_slot_key(str(item_data.get("_equipped_slot", ""))) == canonical_slot_key:
			return i
	return -1


func resolve_equipment_slot_key(runtime: Object, item_data: Dictionary, owner: Object, constants: Dictionary) -> String:
	var item_name: String = str(item_data.get("name", ""))
	var slot_key: String = canonical_equipment_slot_key(str(item_data.get("slot", runtime.catalog.get_slot_key(item_name))))
	if slot_key == "arm":
		var arm_slot_keys: Array = _get_array(constants.get("arm_slot_keys", ["left_arm", "right_arm"]))
		for arm_slot in arm_slot_keys:
			var arm_key: String = str(arm_slot)
			if not is_equipment_slot_enabled(runtime, arm_key, owner):
				continue
			if find_equipped_inventory_index_by_slot(runtime, arm_key) < 0:
				return arm_key
		return ""
	if slot_key != "accessory":
		return slot_key
	var accessory_slot_keys: Array = _get_array(constants.get("accessory_slot_keys", ["accessory1", "accessory2"]))
	for accessory_slot in accessory_slot_keys:
		var key: String = str(accessory_slot)
		if not is_equipment_slot_enabled(runtime, key, owner):
			continue
		if find_equipped_inventory_index_by_slot(runtime, key) < 0:
			return key
	return ""


func slot_family_for_key(slot_key: String) -> String:
	var canonical: String = canonical_equipment_slot_key(slot_key)
	if canonical == "left_arm" or canonical == "right_arm":
		return "arm"
	if canonical.begins_with("accessory"):
		return "accessory"
	return canonical


func slot_family_for_item(runtime: Object, item_data: Dictionary) -> String:
	var item_name: String = str(item_data.get("name", ""))
	return canonical_equipment_slot_key(str(item_data.get("slot", runtime.catalog.get_slot_key(item_name))))


func is_slot_compatible(runtime: Object, item_data: Dictionary, slot_key: String) -> bool:
	if item_data.is_empty():
		return false
	return slot_family_for_item(runtime, item_data) == slot_family_for_key(slot_key)


func candidate_slot_keys(item_family: String, constants: Dictionary) -> Array:
	if item_family == "arm":
		return _get_array(constants.get("arm_slot_keys", ["left_arm", "right_arm"]))
	if item_family == "accessory":
		return _get_array(constants.get("accessory_slot_keys", ["accessory1", "accessory2"]))
	return [item_family]


func resolve_auto_equip_slot(runtime: Object, item_data: Dictionary, owner: Object, constants: Dictionary) -> String:
	# Original PingFighter find_slot_for_item parity: prefer the first empty
	# enabled slot of the item's family, otherwise fall back to the first
	# enabled candidate (which will be swap-replaced on equip).
	var family: String = slot_family_for_item(runtime, item_data)
	var candidates: Array = candidate_slot_keys(family, constants)
	var first_enabled: String = ""
	for raw_slot in candidates:
		var key: String = str(raw_slot)
		if not is_equipment_slot_enabled(runtime, key, owner):
			continue
		if first_enabled == "":
			first_enabled = key
		if find_equipped_inventory_index_by_slot(runtime, key) < 0:
			return key
	return first_enabled


func canonical_equipment_slot_key(slot_key: String) -> String:
	match slot_key:
		"back", "등":
			return "belt2"
		"torso":
			return "top"
		_:
			return slot_key


func is_equipment_slot_enabled(runtime: Object, slot_key: String, owner: Object) -> bool:
	if not slot_key.begins_with("accessory"):
		return true
	var slot_number: int = int(slot_key.substr("accessory".length(), 1))
	if slot_number <= 0:
		return true
	var explicit_count: int = int(runtime._safe_owner_get(owner, "accessory_slot_count", 0))
	var slot_count: int = explicit_count if explicit_count > 0 else 2
	var runtime_bonus: int = int(runtime._safe_owner_get(owner, "runtime_accessory_slot_bonus", 0))
	var levels: Dictionary = runtime._get_dict(runtime._safe_owner_get(owner, "runtime_perk_levels", {}))
	runtime_bonus = max(runtime_bonus, int(levels.get("common_expansion", 0)))
	return slot_number <= clamp(slot_count + runtime_bonus, 1, 4)


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
