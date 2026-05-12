extends SceneTree

const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")

var _failures: Array[String] = []


class FakeHudState:
	extends RefCounted

	var selected_index := -1

	func set_selected_index(index: int) -> void:
		selected_index = index


class FakeRegistry:
	extends RefCounted

	var hud_state := FakeHudState.new()

	func get_instance(key: String) -> Object:
		if key == "active_item_hud_state":
			return hud_state
		return null


class FakeOwner:
	extends RefCounted

	var active_item_slots: Array = []


func _init() -> void:
	_verify_wheel_adjusts_debug_item_quantity()
	_verify_spawn_mode_spawns_field_item()

	if _failures.is_empty():
		print("active_item_debug_spawn_menu_wheel_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_wheel_adjusts_debug_item_quantity() -> void:
	var runtime: Object = ActiveItemRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var view_size := Vector2(900.0, 720.0)

	runtime.toggle_debug_spawn_menu()
	var menu: Object = runtime.debug_spawn_menu
	var first_cell: Rect2 = menu._get_cell_rect(menu._get_panel_rect(view_size), 0)
	var cell_center: Vector2 = first_cell.get_center()

	_send_wheel(runtime, cell_center, MOUSE_BUTTON_WHEEL_UP, view_size, owner, registry)
	_expect(owner.active_item_slots.size() == 1, "wheel up should add one debug active item")
	_expect(str(owner.active_item_slots[0].get("name", "")) == "gauge_charge", "first debug entry should add gauge_charge")
	_expect(runtime.is_debug_spawn_menu_open(), "wheel adjustment should keep the F2 menu open")

	_send_wheel(runtime, cell_center, MOUSE_BUTTON_WHEEL_UP, view_size, owner, registry)
	_send_wheel(runtime, cell_center, MOUSE_BUTTON_WHEEL_UP, view_size, owner, registry)
	_send_wheel(runtime, cell_center, MOUSE_BUTTON_WHEEL_UP, view_size, owner, registry)
	_expect(owner.active_item_slots.size() == 3, "wheel up should respect active slot capacity")
	_expect(int(runtime.get_debug_item_counts(owner).get("gauge_charge", 0)) == 3, "debug count badge data should match slots")

	_send_wheel(runtime, cell_center, MOUSE_BUTTON_WHEEL_DOWN, view_size, owner, registry)
	_expect(owner.active_item_slots.size() == 2, "wheel down should remove one matching debug active item")
	_expect(int(runtime.get_debug_item_counts(owner).get("gauge_charge", 0)) == 2, "debug count should decrease after wheel down")


func _verify_spawn_mode_spawns_field_item() -> void:
	var runtime: Object = ActiveItemRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var view_size := Vector2(900.0, 720.0)

	runtime.toggle_debug_spawn_menu()
	var menu: Object = runtime.debug_spawn_menu
	var panel_rect: Rect2 = menu._get_panel_rect(view_size)
	var spawn_button: Rect2 = menu._get_action_button_rect(panel_rect, 1)
	var first_cell: Rect2 = menu._get_cell_rect(panel_rect, 0)

	_send_mouse(runtime, spawn_button.get_center(), MOUSE_BUTTON_LEFT, view_size, owner, registry)
	_expect(menu.action_mode == "spawn", "spawn button should switch the F2 menu to field-spawn mode")

	_send_mouse(runtime, first_cell.get_center(), MOUSE_BUTTON_LEFT, view_size, owner, registry)
	_expect(owner.active_item_slots.is_empty(), "spawn mode click should not grant an active slot item")
	var spawned_items: Array = runtime.get_field_spawned_items()
	_expect(spawned_items.size() == 1, "spawn mode click should create one field item")
	var field_item: Dictionary = {}
	if spawned_items[0] is Dictionary:
		field_item = spawned_items[0]
	var item_data_value: Variant = field_item.get("item_data", {})
	var item_data: Dictionary = {}
	if item_data_value is Dictionary:
		item_data = item_data_value
	_expect(str(item_data.get("name", "")) == "gauge_charge", "spawned field item should match the clicked debug entry")
	_send_wheel(runtime, first_cell.get_center(), MOUSE_BUTTON_WHEEL_UP, view_size, owner, registry)
	_expect(runtime.get_field_spawned_items().size() == 1, "mouse wheel should not spawn extra field items in spawn mode")
	_expect(owner.active_item_slots.is_empty(), "mouse wheel in spawn mode should not grant active slot items")
	_expect(runtime.is_debug_spawn_menu_open(), "spawn mode should keep the F2 menu open for repeated spawns")


func _send_wheel(
	runtime: Object,
	position: Vector2,
	button_index: int,
	view_size: Vector2,
	owner: Object,
	registry: Object
) -> void:
	var event := InputEventMouseButton.new()
	@warning_ignore("int_as_enum_without_cast")
	event.button_index = button_index
	event.pressed = true
	event.position = position
	runtime.handle_debug_spawn_menu_input(event, view_size, owner, registry)


func _send_mouse(
	runtime: Object,
	position: Vector2,
	button_index: int,
	view_size: Vector2,
	owner: Object,
	registry: Object
) -> void:
	var event := InputEventMouseButton.new()
	@warning_ignore("int_as_enum_without_cast")
	event.button_index = button_index
	event.pressed = true
	event.position = position
	runtime.handle_debug_spawn_menu_input(event, view_size, owner, registry)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
