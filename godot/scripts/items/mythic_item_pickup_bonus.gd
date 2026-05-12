extends RefCounted

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemSlotController := preload("res://scripts/items/active_item_slot_controller.gd")


func try_grant_reinforced_boomerang_pickup_bonus(
	runtime: Object,
	item_name: String,
	owner: Object,
	registry: Object,
	gauntlet_item_name: String,
	boomerang_item_name: String
) -> bool:
	if item_name != gauntlet_item_name or owner == null:
		return false
	var bonus_item: Dictionary = build_reinforced_boomerang_bonus_item(
		runtime,
		registry,
		boomerang_item_name
	)
	if bonus_item.is_empty():
		return false
	var slot_controller: Object = get_active_item_slot_controller(runtime, registry)
	if slot_controller == null:
		slot_controller = ActiveItemSlotController.new()
	if not slot_controller.has_method("append_item_data"):
		return false
	return bool(slot_controller.append_item_data(owner, bonus_item, registry, true))


func build_reinforced_boomerang_bonus_item(
	runtime: Object,
	registry: Object,
	boomerang_item_name: String
) -> Dictionary:
	var active_item_runtime: Object = runtime._get_instance(registry, "active_item_runtime")
	if active_item_runtime != null:
		var runtime_catalog: Object = active_item_runtime.get("item_catalog")
		if runtime_catalog != null and runtime_catalog.has_method("build_item_by_name"):
			var runtime_item: Dictionary = runtime_catalog.build_item_by_name(boomerang_item_name)
			if not runtime_item.is_empty():
				return runtime_item
	var fallback_catalog: Object = ActiveItemCatalog.new()
	return fallback_catalog.build_item_by_name(boomerang_item_name)


func get_active_item_slot_controller(runtime: Object, registry: Object) -> Object:
	var active_item_runtime: Object = runtime._get_instance(registry, "active_item_runtime")
	if active_item_runtime == null:
		return null
	return active_item_runtime.get("slot_controller")
