extends RefCounted

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemPickupRouter := preload("res://scripts/items/active_item_pickup_router.gd")

var item_catalog: Object = ActiveItemCatalog.new()
var pickup_router: Object = ActiveItemPickupRouter.new()


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

	var picked_items: Array = payload.get("picked_items", [])
	for picked_value in picked_items:
		if not (picked_value is Dictionary):
			continue
		var field_item: Dictionary = picked_value
		pickup_router.collect_field_item_to_owner_slots(
			field_item,
			owner,
			registry,
			slot_controller,
			effect_controller,
			pickup_feedback_callback
		)

	var boomerang_item: Dictionary = item_catalog.build_item_by_name("boomerang")
	if boomerang_item.is_empty():
		return
	boomerang_item["allow_overflow"] = true
	slot_controller.append_item_data(owner, boomerang_item, registry, true)
