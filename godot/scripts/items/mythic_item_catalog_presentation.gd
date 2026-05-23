extends RefCounted

const PassiveItemQuality := preload("res://scripts/items/passive_item_quality.gd")


func get_display_name(catalog: Object, item_name: String) -> String:
	var item_data: Dictionary = catalog.build_item_by_name(item_name)
	return str(item_data.get("display_name", item_name))


func format_item_display_name(item_data: Dictionary) -> String:
	return PassiveItemQuality.format_item_display_name(item_data)


func get_item_quality_color(item_data: Dictionary, fallback: Color = Color.WHITE) -> Color:
	return PassiveItemQuality.get_item_quality_color(item_data, fallback)
