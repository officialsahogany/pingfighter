extends RefCounted


func get_debug_items(catalog: Object, item_order: Array) -> Array:
	var result: Array = []
	for item_name in item_order:
		var item_data: Dictionary = catalog.build_item_by_name(str(item_name))
		if not item_data.is_empty():
			result.append(item_data)
	return result


func get_field_spawn_items(catalog: Object, item_order: Array) -> Array:
	var result: Array = []
	for item_name in item_order:
		var normalized_name: String = str(item_name)
		var item_data: Dictionary = catalog.build_item_by_name(normalized_name)
		if item_data.is_empty():
			continue
		item_data["rolls"] = catalog.build_random_rolls(normalized_name)
		item_data = catalog.sync_roll_fields(item_data, false)
		result.append(item_data)
	return result
