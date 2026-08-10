extends SceneTree

const PlazaInteriorView := preload("res://scripts/plaza/plaza_interior_view.gd")

var _failures: Array[String] = []


class CallbackSink:
	extends RefCounted

	var close_calls := 0
	var actions: Array = []

	func close() -> void:
		close_calls += 1

	func action(action_value: Variant) -> bool:
		actions.append(action_value)
		return true


func _init() -> void:
	var sink := CallbackSink.new()
	var view := PlazaInteriorView.new()
	root.add_child(view)
	view.size = Vector2(760.0, 750.0)
	view.configure(
		{
			"building_type": "shop",
			"title": "shop",
			"actions": [],
			"player_inventory": [{"name": "owned", "equipped": true, "_equipped_slot": "accessory_0"}],
			"shop_inventory": [{"name": "stock", "shop_price": 100}],
		},
		Callable(sink, "close"),
		Callable(sink, "action")
	)

	view.handle_input(_key_press(KEY_ESCAPE))
	_expect(sink.close_calls == 1, "escape outside trade should invoke the close callback")

	view.open_trade_ui_for_test()
	view.handle_input(_key_press(KEY_ESCAPE))
	var status := view.get_status()
	_expect(not bool(status.get("trade_ui_open", true)), "trade escape should close trade before the interior")
	_expect(sink.close_calls == 1, "trade escape should not close the interior")

	view.open_trade_ui_for_test()
	view.drag_trade_item_for_test("player", 0, "shop")
	_expect(bool(view.get_status().get("trade_confirm_open", false)), "fixture should open equipped-item confirmation")
	view.handle_input(_key_press(KEY_ESCAPE))
	status = view.get_status()
	_expect(bool(status.get("trade_ui_open", false)), "confirmation escape should leave trade open")
	_expect(not bool(status.get("trade_confirm_open", true)), "confirmation escape should clear confirmation first")

	view.handle_input(_mouse_press(Vector2(12.0, 12.0), MOUSE_BUTTON_LEFT))
	_expect(not bool(view.get_status().get("trade_ui_open", true)), "outside-modal left press should dismiss trade")

	var coin_center := Vector2(518.0, 455.0)
	view.handle_input(_mouse_motion(coin_center))
	view.advance_time_for_test(0.20)
	_expect(str(view.get_status().get("hovered_object_id", "")) == "shop_strewn_coin_pile", "street motion should update the coin-pile hover")
	view.handle_input(_mouse_press(coin_center, MOUSE_BUTTON_LEFT))
	_expect(bool(view.get_status().get("shop_click_animation_active", false)), "street left press should activate the hovered coin pile")

	view.queue_free()
	if _failures.is_empty():
		print("plaza_interior_input_route_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _key_press(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func _mouse_press(position: Vector2, button_index: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = button_index
	event.pressed = true
	return event


func _mouse_motion(position: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	return event


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
