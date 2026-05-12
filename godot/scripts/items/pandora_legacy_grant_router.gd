extends RefCounted

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemSlotController := preload("res://scripts/items/active_item_slot_controller.gd")


func grant_selected_item(
	selected_item: Dictionary,
	mythic_runtime: Object,
	owner: Object,
	registry: Object = null,
	mythic_catalog: Object = null
) -> bool:
	var item_name: String = str(selected_item.get("name", ""))
	if item_name == "":
		return false
	var source: String = str(selected_item.get("pandora_source", ""))
	if source == "active" or _mythic_catalog_item_is_empty(mythic_catalog, item_name):
		return _grant_active_item(item_name, owner, registry)
	if mythic_runtime == null or not mythic_runtime.has_method("acquire_item"):
		return false
	return int(mythic_runtime.call("acquire_item", item_name, owner, registry, {}, true, false, selected_item)) >= 0


func _grant_active_item(item_name: String, owner: Object, registry: Object = null) -> bool:
	var active_item_runtime: Object = _get_instance(registry, "active_item_runtime")
	if active_item_runtime != null and active_item_runtime.has_method("grant_item_to_slot"):
		return bool(active_item_runtime.grant_item_to_slot(item_name, owner, registry, true))
	var active_catalog: Object = ActiveItemCatalog.new()
	var active_item: Dictionary = active_catalog.build_item_by_name(item_name)
	if active_item.is_empty():
		return false
	var slot_controller: Object = ActiveItemSlotController.new()
	return bool(slot_controller.append_item_data(owner, active_item, registry, true))


func _mythic_catalog_item_is_empty(mythic_catalog: Object, item_name: String) -> bool:
	if mythic_catalog == null or not mythic_catalog.has_method("build_item_by_name"):
		return true
	return _get_dict(mythic_catalog.build_item_by_name(item_name)).is_empty()


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}
