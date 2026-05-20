extends SceneTree

const PassiveMythicItemDebugMenu := preload("res://scripts/items/passive_mythic_item_debug_menu.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_inventory_lookup_helpers()
	_verify_grid_draw_uses_lookup()

	if _failures.is_empty():
		print("passive_mythic_debug_menu_draw_lookup_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_inventory_lookup_helpers() -> void:
	var menu: Object = PassiveMythicItemDebugMenu.new()
	var inventory := [
		{"name": "alpha", "quality_rank": 2},
		{"name": "alpha", "_equipped_slot": "head", "quality_rank": 4},
		{"name": "beta"},
	]
	var lookup: Dictionary = menu._build_inventory_lookup(inventory)

	_expect(menu._get_inventory_item_count_from_lookup("alpha", lookup) == 2, "lookup should count duplicate inventory items")
	_expect(menu._get_inventory_item_count_from_lookup("beta", lookup) == 1, "lookup should count single inventory items")
	_expect(menu._get_inventory_item_count_from_lookup("missing", lookup) == 0, "lookup should return zero for missing items")
	_expect(menu._is_inventory_item_owned_from_lookup("alpha", lookup), "lookup should mark owned items")
	_expect(menu._is_inventory_item_equipped_from_lookup("alpha", lookup), "lookup should mark equipped duplicate items")
	var display_item: Dictionary = menu._get_display_item_data_from_lookup({"name": "alpha", "quality_rank": 0}, lookup)
	_expect(int(display_item.get("quality_rank", 0)) == 2, "lookup should expose the first matching display item")


func _verify_grid_draw_uses_lookup() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/items/passive_mythic_item_debug_menu.gd")
	var grid_body := _function_body(source, "func _draw_selected_item_grid(")
	var cell_body := _function_body(source, "func _draw_item_cell(")
	var tooltip_body := _function_body(source, "func _draw_hover_tooltip(")

	_expect(grid_body.find("_build_inventory_lookup(inventory)") >= 0, "grid draw should build one inventory lookup per frame")
	_expect(grid_body.find("_get_inventory_item_count(item_name, inventory)") < 0, "grid draw should not scan inventory for every cell count")
	_expect(cell_body.find("_get_display_item_data(item_data, inventory)") < 0, "cell draw should not rescan inventory for display data")
	_expect(cell_body.find("_is_inventory_item_equipped(item_name, inventory)") < 0, "cell draw should not rescan inventory for equipped state")
	_expect(cell_body.find("_get_inventory_index_for_item_name_in_inventory") < 0, "cell draw should not rescan inventory for owned state")
	_expect(tooltip_body.find("_catalog_item_status(item_name, inventory)") < 0, "tooltip draw should not rescan full inventory for status")


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\nfunc ", start + 1)
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
