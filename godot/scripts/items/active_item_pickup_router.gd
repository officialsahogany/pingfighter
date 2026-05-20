extends RefCounted


func store_field_item(
	field_item: Dictionary,
	active_item_slots: Array,
	registry: Object,
	owner: Object,
	slot_controller: Object,
	effect_controller: Object
) -> bool:
	if slot_controller == null:
		return false

	var item_data: Dictionary = _get_dictionary(field_item, "item_data")
	if is_passive_or_mythic_item(item_data):
		return acquire_passive_or_mythic_item(item_data, owner, registry, field_item)

	return slot_controller.store_active_item(
		field_item,
		active_item_slots,
		registry,
		_build_can_store_callback(effect_controller)
	)


func collect_field_item_to_owner_slots(
	field_item: Dictionary,
	owner: Object,
	registry: Object,
	slot_controller: Object,
	effect_controller: Object,
	pickup_feedback_callback: Callable = Callable()
) -> bool:
	if owner == null or slot_controller == null:
		return false

	var item_data: Dictionary = _get_dictionary(field_item, "item_data")
	if item_data.is_empty():
		return false

	var stored := false
	if is_passive_or_mythic_item(item_data):
		stored = acquire_passive_or_mythic_item(item_data, owner, registry, field_item)
	else:
		stored = bool(slot_controller.append_item_data(
			owner,
			item_data,
			registry,
			false,
			_build_can_store_callback(effect_controller)
		))

	if stored and pickup_feedback_callback.is_valid():
		if not bool(field_item.get("skip_pickup_feedback", false)):
			pickup_feedback_callback.call(field_item, registry)
	return stored


func trigger_pickup_effect(
	field_item: Dictionary,
	registry: Object,
	pickup_feedback: Object,
	effect_controller: Object
) -> void:
	if bool(field_item.get("skip_pickup_feedback", false)):
		return
	if pickup_feedback != null and pickup_feedback.has_method("trigger_pickup_effect"):
		pickup_feedback.trigger_pickup_effect(field_item, effect_controller, registry)


func is_passive_or_mythic_item(item_data: Dictionary) -> bool:
	var item_type: String = str(item_data.get("type", "")).to_lower()
	var rarity: String = str(item_data.get("rarity", "")).to_lower()
	return (
		item_type == "passive"
		or item_type == "mythic"
		or item_type == "legendary"
		or rarity == "passive"
		or rarity == "mythic"
		or rarity == "legendary"
	)


func acquire_passive_or_mythic_item(
	item_data: Dictionary,
	owner: Object,
	registry: Object,
	field_item: Dictionary = {}
) -> bool:
	var item_name: String = str(item_data.get("name", ""))
	if item_name == "" or owner == null:
		return false
	var mythic_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if mythic_runtime == null or not mythic_runtime.has_method("acquire_item"):
		return false
	var roll_overrides: Dictionary = _get_dictionary(item_data, "rolls").duplicate(true)
	var inventory_index: int = int(mythic_runtime.acquire_item(
		item_name,
		owner,
		registry,
		roll_overrides,
		true,
		false,
		item_data.duplicate(true)
	))
	if inventory_index < 0:
		return false
	if mythic_runtime.has_method("get_inventory_item"):
		var acquired_item: Dictionary = mythic_runtime.get_inventory_item(inventory_index)
		if not acquired_item.is_empty():
			field_item["item_data"] = acquired_item
			if _try_start_acquisition_cinematic(acquired_item, field_item, owner, registry, mythic_runtime):
				field_item["skip_pickup_feedback"] = true
	return true


func _try_start_acquisition_cinematic(
	acquired_item: Dictionary,
	field_item: Dictionary,
	owner: Object,
	registry: Object,
	mythic_runtime: Object
) -> bool:
	if mythic_runtime == null or not mythic_runtime.has_method("start_acquisition_cinematic"):
		return false
	if not _is_mythic_cinematic_item(acquired_item):
		return false
	return bool(mythic_runtime.start_acquisition_cinematic(
		acquired_item,
		_get_vector2(field_item, "position", Vector2(380.0, 375.0)),
		owner,
		registry
	))


func _is_mythic_cinematic_item(item_data: Dictionary) -> bool:
	var item_type: String = str(item_data.get("type", "")).to_lower()
	var rarity: String = str(item_data.get("rarity", "")).to_lower()
	return item_type == "mythic" or item_type == "legendary" or rarity == "mythic" or rarity == "legendary"


func _build_can_store_callback(effect_controller: Object) -> Callable:
	if effect_controller != null and effect_controller.has_method("can_store_item"):
		return Callable(effect_controller, "can_store_item")
	return Callable()


func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return value
	return {}


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
