extends SceneTree

const PlazaInteriorLayout := preload("res://scripts/plaza/plaza_interior_layout.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_trade_grid_geometry()
	_verify_scroll_and_drop_geometry()
	_verify_object_specs_and_hit_order()
	if _failures.is_empty():
		print("plaza_interior_layout_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_trade_grid_geometry() -> void:
	var player_panel := PlazaInteriorLayout.get_trade_panel_rect("player")
	var shop_panel := PlazaInteriorLayout.get_trade_panel_rect("shop")
	_expect(player_panel == PlazaInteriorLayout.SHOP_TRADE_LEFT_PANEL, "player inventory should use the left trade panel")
	_expect(shop_panel == PlazaInteriorLayout.SHOP_TRADE_RIGHT_PANEL, "shop inventory should use the right trade panel")
	_expect(PlazaInteriorLayout.get_trade_panel_at_pos(player_panel.get_center()) == "player", "left panel hit should resolve player inventory")
	_expect(PlazaInteriorLayout.get_trade_panel_at_pos(shop_panel.get_center()) == "shop", "right panel hit should resolve shop inventory")
	var first_cell := PlazaInteriorLayout.get_visible_trade_cell_rect(player_panel, 0)
	var next_row := PlazaInteriorLayout.get_visible_trade_cell_rect(player_panel, 5)
	_expect(first_cell == Rect2(104.0, 253.0, 42.0, 42.0), "first trade cell should use the shared panel inset")
	_expect(next_row.position == first_cell.position + Vector2(0.0, 48.0), "sixth trade cell should begin the next five-column row")
	_expect(PlazaInteriorLayout.get_trade_cell_index_at_pos(player_panel, 40, 5, first_cell.get_center()) == 5, "cell hit should add the active scroll offset")
	_expect(PlazaInteriorLayout.get_trade_cell_index_at_pos(player_panel, 0, 0, first_cell.get_center()) == -1, "empty cells should not resolve an item")


func _verify_scroll_and_drop_geometry() -> void:
	_expect(PlazaInteriorLayout.get_trade_max_scroll_offset(30) == 0, "one visible page should not scroll")
	_expect(PlazaInteriorLayout.get_trade_max_scroll_offset(31) == 5, "one overflow item should expose one row of scroll")
	_expect(PlazaInteriorLayout.get_trade_max_scroll_offset(36) == 10, "overflow should round up to complete rows")
	_expect(PlazaInteriorLayout.clamp_trade_scroll_offset(99, 31) == 5, "scroll offsets should clamp to the final row")
	var player_panel := PlazaInteriorLayout.get_trade_panel_rect("player")
	var last_visible := PlazaInteriorLayout.get_visible_trade_cell_rect(player_panel, 29)
	_expect(PlazaInteriorLayout.get_trade_drop_index_at_pos("player", 32, 5, last_visible.get_center()) == 31, "drop into trailing empty cells should clamp to the final item")
	var visible_center := PlazaInteriorLayout.get_trade_cell_center("player", 8, 40, 5)
	_expect(visible_center == PlazaInteriorLayout.get_visible_trade_cell_rect(player_panel, 3).get_center(), "absolute item centers should account for scroll offset")
	_expect(PlazaInteriorLayout.get_trade_cell_center("player", 4, 40, 5) == Vector2.INF, "off-page item centers should be rejected")


func _verify_object_specs_and_hit_order() -> void:
	var specs := PlazaInteriorLayout.build_object_specs("bank", ["deposit", "withdraw", "sell", "extra", "ignored"], false, [])
	_expect(specs.size() == 4, "procedural rooms should expose at most four action objects")
	_expect(str(specs[0].get("id", "")) == "bank_action_0", "object IDs should preserve building and action index")
	_expect(str(specs[0].get("kind", "")) == "sell", "bank objects should use the sell visual kind")
	var overlap_specs: Array[Dictionary] = [
		{"id": "back", "rect": Rect2(10.0, 10.0, 30.0, 30.0)},
		{"id": "front", "rect": Rect2(20.0, 20.0, 30.0, 30.0)},
	]
	_expect(PlazaInteriorLayout.hit_test_object(overlap_specs, Vector2(25.0, 25.0), 0.0) == "front", "later draw-order objects should win overlapping hit tests")
	var shop_specs := PlazaInteriorLayout.build_object_specs("shop", [], false, [{"id": "coin", "rect": Rect2(1.0, 2.0, 3.0, 4.0)}])
	_expect(shop_specs.size() == 1 and str(shop_specs[0].get("role", "")) == "strewn", "top-view shop specs should preserve strewn-object routing")
	_expect(int(shop_specs[0].get("action_index", -1)) == 0, "top-view shop specs should route to the trade action")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
