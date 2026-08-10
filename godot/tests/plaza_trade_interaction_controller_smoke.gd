extends SceneTree

const PlazaInteriorLayout := preload("res://scripts/plaza/plaza_interior_layout.gd")
const PlazaTradeInteractionController := preload("res://scripts/plaza/plaza_trade_interaction_controller.gd")

var _failures: Array[String] = []


class CallbackSink:
	extends RefCounted

	var actions: Array[Dictionary] = []

	func dispatch(payload: Variant) -> bool:
		if payload is Dictionary:
			actions.append((payload as Dictionary).duplicate(true))
		return true


func _init() -> void:
	var sink := CallbackSink.new()
	var controller := PlazaTradeInteractionController.new()
	controller.set_action_callback(Callable(sink, "dispatch"))
	var player_inventory := [
		{"name": "equipped", "equipped": true, "_equipped_slot": "slot_0"},
		{"name": "plain_a"},
		{"name": "plain_b"},
	]
	var shop_inventory := [
		{"name": "stock_a", "shop_price": 100},
		{"name": "stock_b", "shop_price": 120},
	]
	_verify_hover_and_direct_trade(controller, sink, player_inventory, shop_inventory)
	_verify_sell_confirmation(controller, sink, player_inventory, shop_inventory)
	_verify_drag_routes(controller, sink, player_inventory, shop_inventory)
	_verify_scroll_and_cancel(controller, sink)
	if _failures.is_empty():
		print("plaza_trade_interaction_controller_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_hover_and_direct_trade(
	controller: PlazaTradeInteractionController,
	sink: CallbackSink,
	player_inventory: Array,
	shop_inventory: Array
) -> void:
	var shop_cell := PlazaInteriorLayout.get_visible_trade_cell_rect(
		PlazaInteriorLayout.SHOP_TRADE_RIGHT_PANEL,
		0
	).get_center()
	_expect(controller.update_hover(shop_cell, shop_cell, player_inventory, shop_inventory), "shop hover should change state")
	var status := controller.get_status(player_inventory.size(), shop_inventory.size())
	_expect(str(status.get("hover_panel", "")) == "shop", "hover panel should resolve from layout")
	_expect(int(status.get("hover_index", -1)) == 0, "hover index should resolve the first visible cell")
	_expect(controller.perform_at(shop_cell, player_inventory, shop_inventory), "shop click should dispatch a purchase")
	_expect(sink.actions.size() == 1, "direct shop trade should dispatch once")
	if not sink.actions.is_empty():
		_expect(str(sink.actions[-1].get("type", "")) == "shop_trade", "direct trade payload type")
		_expect(str(sink.actions[-1].get("panel", "")) == "shop", "direct trade payload panel")


func _verify_sell_confirmation(
	controller: PlazaTradeInteractionController,
	sink: CallbackSink,
	player_inventory: Array,
	shop_inventory: Array
) -> void:
	var player_cell := PlazaInteriorLayout.get_visible_trade_cell_rect(
		PlazaInteriorLayout.SHOP_TRADE_LEFT_PANEL,
		0
	).get_center()
	var before_count := sink.actions.size()
	_expect(controller.perform_at(player_cell, player_inventory, shop_inventory), "equipped item should open sale confirmation")
	_expect(controller.is_confirm_open(), "equipped item should remain confirmation-gated")
	_expect(sink.actions.size() == before_count, "confirmation gate should not dispatch the sale early")
	_expect(controller.confirm_sell(player_inventory, shop_inventory), "confirmed equipped sale should dispatch")
	_expect(not controller.is_confirm_open(), "confirmed sale should consume confirmation state")
	_expect(sink.actions.size() == before_count + 1, "confirmed sale should dispatch exactly once")
	if sink.actions.size() > before_count:
		_expect(str(sink.actions[-1].get("panel", "")) == "player", "confirmed sale payload panel")
		_expect(int(sink.actions[-1].get("index", -1)) == 0, "confirmed sale payload index")


func _verify_drag_routes(
	controller: PlazaTradeInteractionController,
	sink: CallbackSink,
	player_inventory: Array,
	shop_inventory: Array
) -> void:
	var player_cell_0 := PlazaInteriorLayout.get_visible_trade_cell_rect(
		PlazaInteriorLayout.SHOP_TRADE_LEFT_PANEL,
		0
	).get_center()
	var player_cell_1 := PlazaInteriorLayout.get_visible_trade_cell_rect(
		PlazaInteriorLayout.SHOP_TRADE_LEFT_PANEL,
		1
	).get_center()
	var shop_cell_0 := PlazaInteriorLayout.get_visible_trade_cell_rect(
		PlazaInteriorLayout.SHOP_TRADE_RIGHT_PANEL,
		0
	).get_center()
	var before_reorder := sink.actions.size()
	_expect(controller.begin_drag(player_cell_0, player_cell_0, player_inventory, shop_inventory), "player drag should start")
	_expect(controller.update_pointer(player_cell_1), "active drag pointer movement should report a visual change")
	_expect(controller.finish_drag(player_cell_1, player_cell_1, player_inventory, shop_inventory), "same-panel movement should reorder")
	_expect(sink.actions.size() == before_reorder + 1, "reorder should dispatch once")
	if sink.actions.size() > before_reorder:
		_expect(str(sink.actions[-1].get("type", "")) == "shop_trade_reorder", "reorder payload type")
		_expect(int(sink.actions[-1].get("from_index", -1)) == 0, "reorder source index")
		_expect(int(sink.actions[-1].get("to_index", -1)) == 1, "reorder target index")
	var before_cross_panel := sink.actions.size()
	_expect(controller.begin_drag(player_cell_0, player_cell_0, player_inventory, shop_inventory), "equipped cross-panel drag should start")
	_expect(controller.finish_drag(shop_cell_0, shop_cell_0, player_inventory, shop_inventory), "equipped cross-panel drag should open confirmation")
	_expect(controller.is_confirm_open(), "equipped cross-panel drag should remain confirmation-gated")
	_expect(sink.actions.size() == before_cross_panel, "cross-panel confirmation should not dispatch early")
	controller.clear_confirm()


func _verify_scroll_and_cancel(controller: PlazaTradeInteractionController, sink: CallbackSink) -> void:
	var player_inventory: Array = []
	for index in range(35):
		player_inventory.append({"name": "player_%02d" % index})
	var shop_inventory := [{"name": "stock"}]
	var player_panel_center := PlazaInteriorLayout.SHOP_TRADE_LEFT_PANEL.get_center()
	_expect(controller.scroll_at(player_panel_center, 1, player_inventory, shop_inventory), "overflowing player inventory should scroll")
	var status := controller.get_status(player_inventory.size(), shop_inventory.size())
	_expect(int(status.get("player_scroll", 0)) == PlazaInteriorLayout.SHOP_TRADE_COLUMNS, "scroll should move one complete row")
	var first_visible_cell := PlazaInteriorLayout.get_visible_trade_cell_rect(
		PlazaInteriorLayout.SHOP_TRADE_LEFT_PANEL,
		0
	).get_center()
	_expect(controller.begin_drag(first_visible_cell, first_visible_cell, player_inventory, shop_inventory), "scrolled visible item should begin drag")
	_expect(controller.reset_drag(), "reset should report an active drag was cleared")
	_expect(not controller.is_drag_active(), "reset should clear drag state")
	var equipped_inventory := [{"name": "equipped", "equipped": true}]
	controller.clamp_scroll_offsets(equipped_inventory.size(), shop_inventory.size())
	_expect(controller.perform_at(first_visible_cell, equipped_inventory, shop_inventory), "equipped sale should reopen confirmation")
	var action_count := sink.actions.size()
	_expect(
		controller.handle_confirm_mouse(
			PlazaInteriorLayout.SHOP_TRADE_CONFIRM_CANCEL_RECT.get_center(),
			MOUSE_BUTTON_LEFT,
			true,
			equipped_inventory,
			shop_inventory
		),
		"cancel button should consume confirmation input"
	)
	_expect(not controller.is_confirm_open(), "cancel button should clear confirmation")
	_expect(sink.actions.size() == action_count, "cancel should not dispatch a trade")


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
