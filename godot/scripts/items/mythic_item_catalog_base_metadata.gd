extends RefCounted


func with_item_base(
	item_data: Dictionary,
	catalog: Object,
	item_name: String,
	item_type: String,
	slot: String,
	chance: float
) -> Dictionary:
	item_data["name"] = item_name
	item_data["type"] = item_type
	item_data["rarity"] = item_type
	item_data["effect"] = item_name
	item_data["slot"] = slot
	var icon_path := ""
	if catalog != null and catalog.has_method("get_icon_path"):
		icon_path = str(catalog.call("get_icon_path", item_name))
	item_data["icon_path"] = icon_path
	item_data["chance"] = chance
	return item_data


func with_static_item_base(
	item_data: Dictionary,
	catalog: Object,
	item_name: String,
	item_type: String,
	slot: String,
	chance: float,
	include_fixed_options: bool = true
) -> Dictionary:
	with_item_base(item_data, catalog, item_name, item_type, slot, chance)
	item_data["rolls"] = {}
	item_data["roll_options"] = []
	item_data["rolled_options"] = []
	if include_fixed_options and catalog != null and catalog.has_method("get_fixed_options"):
		item_data["fixed_options"] = catalog.call("get_fixed_options", item_name)
	return item_data


func with_rolled_item_base(
	item_data: Dictionary,
	catalog: Object,
	item_name: String,
	item_type: String,
	slot: String,
	chance: float,
	include_fixed_options: bool = false
) -> Dictionary:
	with_item_base(item_data, catalog, item_name, item_type, slot, chance)

	var rolls: Dictionary = {}
	if catalog != null and catalog.has_method("build_default_rolls"):
		var roll_result: Variant = catalog.call("build_default_rolls", item_name)
		if roll_result is Dictionary:
			rolls = roll_result as Dictionary
	item_data["rolls"] = rolls

	var roll_options: Array = []
	if catalog != null and catalog.has_method("get_roll_options"):
		var options_result: Variant = catalog.call("get_roll_options", item_name)
		if options_result is Array:
			roll_options = options_result as Array
	item_data["roll_options"] = roll_options

	var rolled_options: Array = []
	if catalog != null and catalog.has_method("build_rolled_options"):
		var rolled_result: Variant = catalog.call("build_rolled_options", item_name, rolls)
		if rolled_result is Array:
			rolled_options = rolled_result as Array
	item_data["rolled_options"] = rolled_options

	if include_fixed_options and catalog != null and catalog.has_method("get_fixed_options"):
		item_data["fixed_options"] = catalog.call("get_fixed_options", item_name)
	return item_data
