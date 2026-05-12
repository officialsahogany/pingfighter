extends SceneTree

const ActiveItemDebugSpawnMenu := preload("res://scripts/items/active_item_debug_spawn_menu.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_grant_mode_click_and_wheel()
	_verify_spawn_mode_click_and_wheel()
	_verify_outside_click_closes_menu()

	if _failures.is_empty():
		print("active_item_debug_spawn_menu_grid_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_grant_mode_click_and_wheel() -> void:
	var menu := ActiveItemDebugSpawnMenu.new()
	var view_size := Vector2(900.0, 720.0)
	menu.toggle()

	var panel_rect: Rect2 = menu._get_panel_rect(view_size)
	var first_cell: Rect2 = menu._get_cell_rect(panel_rect, 0)
	var cell_center: Vector2 = first_cell.get_center()

	var wheel_up: Dictionary = menu.handle_mouse_button(MOUSE_BUTTON_WHEEL_UP, cell_center, view_size)
	_expect_bool(bool(wheel_up.get("handled", false)), "wheel up should be handled while the menu is open")
	_expect_equal(str(wheel_up.get("action", "")), "grant", "grant mode wheel should return a grant action")
	_expect_equal(str(wheel_up.get("item_name", "")), "gauge_charge", "first grid item should be gauge_charge")
	_expect_equal(int(wheel_up.get("delta", 0)), 1, "wheel up should increase the grant delta")
	_expect_bool(menu.is_open(), "wheel adjustment should keep the menu open")

	var wheel_down: Dictionary = menu.handle_mouse_button(MOUSE_BUTTON_WHEEL_DOWN, cell_center, view_size)
	_expect_equal(str(wheel_down.get("action", "")), "grant", "grant mode wheel down should return a grant action")
	_expect_equal(str(wheel_down.get("item_name", "")), "gauge_charge", "wheel down should target the hovered item")
	_expect_equal(int(wheel_down.get("delta", 0)), -1, "wheel down should decrease the grant delta")
	_expect_bool(menu.is_open(), "wheel down should keep the menu open")

	var click_result: Dictionary = menu.handle_mouse_button(MOUSE_BUTTON_LEFT, cell_center, view_size)
	_expect_equal(str(click_result.get("action", "")), "grant", "left click should grant in the default mode")
	_expect_equal(str(click_result.get("item_name", "")), "gauge_charge", "left click should target the clicked item")
	_expect_equal(int(click_result.get("delta", 0)), 1, "left click should grant one item")
	_expect_bool(not menu.is_open(), "grant click should close the menu")


func _verify_spawn_mode_click_and_wheel() -> void:
	var menu := ActiveItemDebugSpawnMenu.new()
	var view_size := Vector2(900.0, 720.0)
	menu.toggle()

	var panel_rect: Rect2 = menu._get_panel_rect(view_size)
	var spawn_button: Rect2 = menu._get_action_button_rect(panel_rect, 1)
	var first_cell: Rect2 = menu._get_cell_rect(panel_rect, 0)

	var mode_result: Dictionary = menu.handle_mouse_button(MOUSE_BUTTON_LEFT, spawn_button.get_center(), view_size)
	_expect_bool(bool(mode_result.get("handled", false)), "spawn action button should be handled")
	_expect_equal(menu.action_mode, "spawn", "spawn action button should switch the menu mode")
	_expect_bool(menu.is_open(), "mode switch should keep the menu open")

	var spawn_result: Dictionary = menu.handle_mouse_button(MOUSE_BUTTON_LEFT, first_cell.get_center(), view_size)
	_expect_equal(str(spawn_result.get("action", "")), "spawn", "spawn mode left click should request a field spawn")
	_expect_equal(str(spawn_result.get("item_name", "")), "gauge_charge", "spawn mode should target the clicked item")
	_expect_equal(int(spawn_result.get("delta", 0)), 1, "spawn click should use a single-spawn delta")
	_expect_bool(menu.is_open(), "spawn mode should keep the menu open for repeated spawns")

	var wheel_result: Dictionary = menu.handle_mouse_button(MOUSE_BUTTON_WHEEL_UP, first_cell.get_center(), view_size)
	_expect_equal(str(wheel_result.get("action", "")), "spawn", "spawn mode wheel should remain in spawn action context")
	_expect_equal(str(wheel_result.get("item_name", "")), "", "spawn mode wheel should not select an item")
	_expect_equal(int(wheel_result.get("delta", 0)), 0, "spawn mode wheel should not request extra spawns")
	_expect_bool(menu.is_open(), "spawn mode wheel should keep the menu open")


func _verify_outside_click_closes_menu() -> void:
	var menu := ActiveItemDebugSpawnMenu.new()
	var view_size := Vector2(900.0, 720.0)
	menu.toggle()

	var outside_result: Dictionary = menu.handle_mouse_button(MOUSE_BUTTON_LEFT, Vector2(-10.0, -10.0), view_size)
	_expect_bool(bool(outside_result.get("handled", false)), "outside click should be consumed while the menu is open")
	_expect_equal(str(outside_result.get("item_name", "")), "", "outside click should not return an item")
	_expect_bool(not menu.is_open(), "outside click should close the menu")


func _expect_bool(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (got %s, expected %s)" % [message, str(actual), str(expected)])
