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
