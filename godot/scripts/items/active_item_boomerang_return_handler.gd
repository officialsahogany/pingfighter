extends RefCounted

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")

var item_catalog: Object = ActiveItemCatalog.new()


func handle_return(
	owner: Object,
	payload: Dictionary,
	registry: Object,
	slot_controller: Object,
	effect_controller: Object,
	pickup_feedback_callback: Callable
) -> void:
	if owner == null or slot_controller == null:
		return

	var can_store_callback := Callable()
	if effect_controller != null and effect_controller.has_method("can_store_item"):
		can_store_callback = Callable(effect_controller, "can_store_item")

	var picked_items: Array = payload.get("picked_items", [])
	for picked_value in picked_items:
		if not (picked_value is Dictionary):
			continue
		var field_item: Dictionary = picked_value
		var picked_data: Dictionary = _get_dictionary(field_item, "item_data")
		if picked_data.is_empty():
			continue
		if slot_controller.append_item_data(owner, picked_data, registry, false, can_store_callback):
			if pickup_feedback_callback.is_valid():
				pickup_feedback_callback.call(field_item, registry)

	var boomerang_item: Dictionary = item_catalog.build_item_by_name("boomerang")
	if boomerang_item.is_empty():
		return
	boomerang_item["allow_overflow"] = true
	slot_controller.append_item_data(owner, boomerang_item, registry, true)


func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return value
	return {}
