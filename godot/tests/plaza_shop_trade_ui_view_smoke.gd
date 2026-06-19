extends SceneTree

const PlazaInteriorView := preload("res://scripts/plaza/plaza_interior_view.gd")

var _failures: Array[String] = []


class CallbackSink:
	extends RefCounted

	var actions: Array = []

	func close() -> void:
		pass

	func action(action_value: Variant) -> bool:
		actions.append(action_value)
		return true


func _init() -> void:
	_run()


func _run() -> void:
	_verify_shop_trade_entry_survives_missing_backdrop()

	var sink := CallbackSink.new()
	var view := PlazaInteriorView.new()
	root.add_child(view)
	view.size = Vector2(760.0, 750.0)
	var player_items := _build_items("player", 34)
	if not player_items.is_empty():
		var equipped_item: Dictionary = player_items[0]
		equipped_item["equipped"] = true
		equipped_item["_equipped_slot"] = "accessory_0"
		player_items[0] = equipped_item
	view.configure(
		{
			"building_type": "shop",
			"title": "VR 상점",
			"subtitle": "",
			"actions": ["특가 A", "특가 B"],
			"player_inventory": player_items,
			"shop_inventory": _build_items("shop", 37),
		},
		Callable(sink, "close"),
		Callable(sink, "action")
	)

	var status := view.get_status()
	_expect(bool(status.get("coin_trade_fx_particles_ready", false)), "coin pile trade FX should create a GPUParticles2D sparkle layer")
	_expect(bool(status.get("coin_trade_fx_aura_writhe_shader", false)), "coin pile trade hover aura should use the shared WritheEmber shader")
	_expect(bool(status.get("coin_trade_fx_burst_writhe_shader", false)), "coin pile trade click burst should use the shared WritheEmber shader")
	status = view.hover_object_for_test("shop_strewn_coin_pile")
	status = view.advance_time_for_test(0.20)
	_expect(bool(status.get("coin_trade_fx_particle_emitting", false)), "hovered coin pile should emit modular sparkle particles")
	status = view.click_object_for_test("shop_strewn_coin_pile")
	_expect(float(status.get("coin_trade_fx_burst_value", 0.0)) > 0.0, "coin pile click should start the Tween-driven burst envelope")

	status = view.open_trade_ui_for_test()
	_expect(bool(status.get("trade_ui_open", false)), "trade UI should open for direct view smoke")
	_expect(view.get_trade_item_price_for_test("player", 0) == 30, "player trade panel should read sell price, not buy price")
	_expect(view.get_trade_item_price_for_test("shop", 0) == 100, "shop trade panel should read buy price")
	status = view.scroll_trade_panel_for_test("shop", 1)
	_expect(int(status.get("trade_shop_scroll", 0)) == 5, "shop panel wheel scroll should move by one row")
	status = view.hover_trade_item_for_test("shop", 8)
	_expect(str(status.get("trade_hover_panel", "")) == "shop", "trade hover should track the shop panel")
	_expect(int(status.get("trade_hover_index", -1)) == 8, "trade hover should preserve the absolute scrolled item index")
	status = view.drag_trade_item_for_test("shop", 8, "player")
	_expect(not bool(status.get("trade_drag_active", true)), "trade drag should clear after release")
	_expect(sink.actions.size() == 1, "trade drag should invoke the action callback once")
	if sink.actions.size() >= 1:
		var action: Variant = sink.actions[0]
		_expect(action is Dictionary, "trade drag callback payload should be a dictionary")
		if action is Dictionary:
			var action_data: Dictionary = action
			_expect(str(action_data.get("type", "")) == "shop_trade", "trade drag callback should request shop_trade")
			_expect(str(action_data.get("panel", "")) == "shop", "trade drag callback should preserve source panel")
			_expect(int(action_data.get("index", -1)) == 8, "trade drag callback should preserve absolute source index")

	var action_count := sink.actions.size()
	_expect(view.is_trade_item_equipped_for_test("player", 0), "player fixture should mark the first item equipped")
	status = view.drag_trade_item_for_test("player", 0, "shop")
	_expect(bool(status.get("trade_confirm_open", false)), "equipped player item drag should open a sell confirmation")
	_expect(sink.actions.size() == action_count, "equipped player item should not sell before confirmation")
	status = view.confirm_trade_sell_for_test()
	_expect(not bool(status.get("trade_confirm_open", true)), "equipped sell confirmation should close after confirm")
	_expect(sink.actions.size() == action_count + 1, "equipped sell confirmation should invoke exactly one sale callback")
	if sink.actions.size() >= action_count + 1:
		var confirm_action: Variant = sink.actions[action_count]
		_expect(confirm_action is Dictionary, "equipped sell callback payload should be a dictionary")
		if confirm_action is Dictionary:
			var confirm_data: Dictionary = confirm_action
			_expect(str(confirm_data.get("type", "")) == "shop_trade", "equipped sell callback should request shop_trade")
			_expect(str(confirm_data.get("panel", "")) == "player", "equipped sell callback should preserve player panel")
			_expect(int(confirm_data.get("index", -1)) == 0, "equipped sell callback should preserve the player item index")

	action_count = sink.actions.size()
	status = view.reorder_trade_item_for_test("shop", 8, 12)
	_expect(sink.actions.size() == action_count + 1, "same-panel drag should invoke a reorder callback")
	if sink.actions.size() >= action_count + 1:
		var reorder_action: Variant = sink.actions[action_count]
		_expect(reorder_action is Dictionary, "reorder callback payload should be a dictionary")
		if reorder_action is Dictionary:
			var reorder_data: Dictionary = reorder_action
			_expect(str(reorder_data.get("type", "")) == "shop_trade_reorder", "same-panel drag should request shop_trade_reorder")
			_expect(str(reorder_data.get("panel", "")) == "shop", "reorder callback should preserve panel")
			_expect(int(reorder_data.get("from_index", -1)) == 8, "reorder callback should preserve source index")
			_expect(int(reorder_data.get("to_index", -1)) == 12, "reorder callback should preserve drop index")

	view.update_state({
		"last_trade_summary": {
			"action": "sale",
			"changed": true,
			"display_name": "player feedback item",
			"item_name": "player_item_00",
			"delta_gold": 42,
			"plaza_gold": 8042,
		},
	})
	status = view.get_status()
	_expect(int(status.get("trade_feedback_count", 0)) >= 1, "changed trade summary should create a gold feedback float")

	view.queue_free()
	if _failures.is_empty():
		print("plaza_shop_trade_ui_view_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_shop_trade_entry_survives_missing_backdrop() -> void:
	var sink := CallbackSink.new()
	var view := PlazaInteriorView.new()
	root.add_child(view)
	view.size = Vector2(760.0, 750.0)
	view.configure(
		{
			"building_type": "shop",
			"title": "VR 상점",
			"subtitle": "",
			"actions": [],
			"player_inventory": [],
			"shop_inventory": _build_items("shop_fallback", 6),
		},
		Callable(sink, "close"),
		Callable(sink, "action")
	)
	var status := view.get_status()
	_expect(int(status.get("object_count", 0)) == 1, "shop should keep the coin pile trade entry when the room backdrop is missing")
	status = view.click_object_for_test("shop_strewn_coin_pile")
	_expect(bool(status.get("shop_click_animation_active", false)), "fallback shop coin pile should start the trade click animation")
	status = view.advance_time_for_test(0.75)
	_expect(bool(status.get("trade_ui_open", false)), "fallback shop coin pile should still open the trade UI")
	_expect(sink.actions.is_empty(), "opening the fallback trade UI should not invoke a transaction callback")
	view.queue_free()


func _build_items(prefix: String, count: int) -> Array:
	var items: Array = []
	for idx in range(count):
		items.append({
			"name": "%s_item_%02d" % [prefix, idx],
			"display_name": "%s 아이템 %02d" % [prefix, idx],
			"description": "스크롤과 드래그 테스트용 상점 아이템입니다.",
			"shop_price": 100 + idx,
			"shop_sell_price": 30 + idx,
		})
		if prefix == "player" and idx == 0:
			var item: Dictionary = items[items.size() - 1]
			item["equipped"] = true
			item["_equipped_slot"] = "accessory_0"
			items[items.size() - 1] = item
	return items


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
