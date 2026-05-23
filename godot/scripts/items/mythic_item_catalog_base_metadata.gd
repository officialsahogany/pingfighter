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
