extends RefCounted

const PlazaShopPricing := preload("res://scripts/plaza/plaza_shop_pricing.gd")


static func format_gold_amount(amount: int) -> String:
	var sign := "-" if amount < 0 else ""
	var digits := str(absi(amount))
	var result := ""
	while digits.length() > 3:
		result = "," + digits.substr(digits.length() - 3, 3) + result
		digits = digits.substr(0, digits.length() - 3)
	return sign + digits + result


static func format_item_name(item_data: Dictionary) -> String:
	var name := str(item_data.get("qualified_display_name", item_data.get("display_name", item_data.get("korean_name", item_data.get("name", "아이템")))))
	return name if name != "" else "아이템"


static func format_item_description(item_data: Dictionary) -> String:
	for key in ["description", "desc", "korean_desc", "tooltip", "summary"]:
		var text := str(item_data.get(key, "")).strip_edges()
		if text != "":
			return text
	if str(item_data.get("name", "")) != "":
		return "%s의 효과를 전투 중에 발동합니다." % format_item_name(item_data)
	return "상세 효과는 장착 후 확인할 수 있습니다."


static func format_item_rolls(item_data: Dictionary) -> String:
	var roll_value: Variant = item_data.get("rolled_options", item_data.get("roll_options", []))
	if not roll_value is Array:
		return ""
	var parts: Array[String] = []
	for option_value in roll_value as Array:
		if not option_value is Dictionary:
			continue
		var option: Dictionary = option_value
		var label := str(option.get("label", option.get("stat", option.get("id", ""))))
		var value_text := str(option.get("display_value", option.get("value", "")))
		if label != "":
			parts.append("%s %s" % [label, value_text])
		if parts.size() >= 2:
			break
	return " / ".join(parts)


static func get_icon_path(item_data: Dictionary) -> String:
	var path := str(item_data.get("icon_path", ""))
	if path == "":
		path = str(item_data.get("icon", ""))
	if path == "":
		path = str(item_data.get("texture_path", ""))
	return path if path.begins_with("res://") else ""


static func get_item_identity(item_data: Dictionary) -> String:
	for key in ["name", "effect", "item_name", "item_id"]:
		var value := str(item_data.get(str(key), "")).strip_edges()
		if value != "":
			return value
	return ""


static func get_display_name(item_data: Dictionary) -> String:
	for key in ["qualified_display_name", "display_name", "korean_name", "name"]:
		var value := str(item_data.get(str(key), "")).strip_edges()
		if value != "":
			return value
	return ""


static func project_inventory(items: Variant, catalog: Object = null, include_sell_price: bool = false) -> Array:
	var result: Array = []
	if not (items is Array):
		return result
	for item_value in items as Array:
		if not (item_value is Dictionary):
			continue
		var item_data := (item_value as Dictionary).duplicate(true)
		var item_name := get_item_identity(item_data)
		if item_name != "" and catalog != null:
			if str(item_data.get("icon_path", "")) == "" and catalog.has_method("get_icon_path"):
				item_data["icon_path"] = str(catalog.get_icon_path(item_name))
			if str(item_data.get("icon_sheet_path", "")) == "" and catalog.has_method("get_icon_sheet_path"):
				item_data["icon_sheet_path"] = str(catalog.get_icon_sheet_path(item_name))
		if include_sell_price and item_name != "":
			item_data["shop_base_price"] = PlazaShopPricing.get_base_price(item_name)
			item_data["shop_sell_price"] = PlazaShopPricing.get_sell_price(item_data)
		result.append(item_data)
	return result
