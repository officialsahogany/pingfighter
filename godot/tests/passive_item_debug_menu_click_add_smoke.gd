extends SceneTree

const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")

const POSEIDON_TRIDENT_ICON_SHEET_PATH := "res://assets/sprites/items/poseidon_trident_icon_sheet.png"

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}

	func queue_redraw() -> void:
		pass


class FakeRegistry:
	extends RefCounted

	var runtime: Object
	var active_runtime: Object

	func _init(runtime_ref: Object, active_runtime_ref: Object = null) -> void:
		runtime = runtime_ref
		active_runtime = active_runtime_ref

	func get_instance(key: String) -> Object:
		if key == "mythic_item_runtime":
			return runtime
		if key == "active_item_runtime":
			return active_runtime
		return null


func _init() -> void:
	_verify_click_adds_passive_items_without_wheel_quantity()

	if _failures.is_empty():
		print("passive_item_debug_menu_click_add_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_click_adds_passive_items_without_wheel_quantity() -> void:
	var runtime: Object = MythicItemRuntime.new()
	var active_runtime: Object = ActiveItemRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(runtime, active_runtime)
	var view_size := Vector2(900.0, 720.0)

	runtime.prewarm_assets()
	_expect(runtime.debug_management_menu._icons_prewarmed, "debug management prewarm should mark menu icons ready")
	_expect(
		runtime.debug_management_menu.icon_renderer._icon_sheet_cache.has(POSEIDON_TRIDENT_ICON_SHEET_PATH),
		"debug management prewarm should cache Poseidon Trident animated icon sheet before first draw"
	)
	runtime.prewarm_assets()
	_expect(runtime.debug_management_menu._icons_prewarmed, "debug management prewarm should be idempotent")

	runtime.toggle_debug_management_menu()
	var menu: Object = runtime.debug_management_menu
	var items: Array = menu._get_selected_tab_items(runtime)
	_expect(not items.is_empty(), "passive debug tab should expose at least one item")
	var target: Dictionary = _find_roll_edit_target(items)
	_expect(not target.is_empty(), "passive debug tab should expose an item with editable rolls")
	var item_index: int = int(target.get("index", 0))
	var item_name: String = str(target.get("item_name", ""))
	var option_key: String = str(target.get("option_key", ""))
	var expected_value: float = float(target.get("expected_value", 0.0))

	var panel_rect: Rect2 = menu._get_panel_rect(view_size)
	var first_cell: Rect2 = menu._get_cell_rect(panel_rect, item_index)
	var cell_center: Vector2 = first_cell.get_center()

	_send_mouse_button(menu, cell_center, MOUSE_BUTTON_RIGHT, view_size, owner, registry)
	_expect(runtime.is_debug_management_menu_open(), "right click should keep the F3 menu open")
	_expect(_inventory_count(runtime, item_name) == 0, "right click roll editing should not add the passive item")

	var editor_rect: Rect2 = menu._get_roll_editor_rect(panel_rect, runtime)
	var row_rect: Rect2 = menu._get_roll_option_row_rect(editor_rect, int(target.get("option_index", 0)))
	_send_mouse_button(menu, row_rect.get_center(), MOUSE_BUTTON_WHEEL_UP, view_size, owner, registry)
	_expect(_inventory_count(runtime, item_name) == 0, "wheel editing roll options should not add the passive item")

	_send_mouse_button(menu, cell_center, MOUSE_BUTTON_LEFT, view_size, owner, registry)
	_expect(runtime.is_debug_management_menu_open(), "left click should keep the F3 menu open")
	_expect(_inventory_count(runtime, item_name) == 1, "first click should add one passive item")
	_expect(int(runtime.get_debug_item_counts().get(item_name, 0)) == 1, "debug count should match one clicked item")
	_expect_close(_inventory_roll_value(runtime, item_name, option_key), expected_value, "left click should add the passive item with the currently edited roll")

	_send_mouse_button(menu, cell_center, MOUSE_BUTTON_LEFT, view_size, owner, registry)
	_expect(_inventory_count(runtime, item_name) == 2, "second click should add a duplicate passive item")
	_expect(int(runtime.get_debug_item_counts().get(item_name, 0)) == 2, "debug count should match two clicked items")

	_send_mouse_button(menu, cell_center, MOUSE_BUTTON_WHEEL_UP, view_size, owner, registry)
	_send_mouse_button(menu, cell_center, MOUSE_BUTTON_WHEEL_DOWN, view_size, owner, registry)
	_expect(_inventory_count(runtime, item_name) == 2, "mouse wheel over the item grid should not adjust passive item quantity")

	var spawn_button: Rect2 = menu._get_action_button_rect(panel_rect, 1)
	_send_mouse_button(menu, spawn_button.get_center(), MOUSE_BUTTON_LEFT, view_size, owner, registry)
	_expect(menu.action_mode == "spawn", "spawn button should switch the F3 menu to field-spawn mode")
	_send_mouse_button(menu, cell_center, MOUSE_BUTTON_LEFT, view_size, owner, registry)
	_expect(_inventory_count(runtime, item_name) == 2, "spawn mode click should not add directly to passive inventory")
	var spawned_items: Array = active_runtime.get_field_spawned_items()
	_expect(spawned_items.size() == 1, "spawn mode click should create a field item through active item runtime")
	var field_item: Dictionary = {}
	if spawned_items[0] is Dictionary:
		field_item = spawned_items[0]
	var spawned_item_value: Variant = field_item.get("item_data", {})
	var spawned_item: Dictionary = {}
	if spawned_item_value is Dictionary:
		spawned_item = spawned_item_value
	_expect(str(spawned_item.get("name", "")) == item_name, "spawned field item should match the clicked passive item")
	_expect_close(_roll_value_from_item(spawned_item, option_key), expected_value, "spawned passive item should preserve the edited roll")


func _find_roll_edit_target(items: Array) -> Dictionary:
	for item_index in range(items.size()):
		var item_data: Dictionary = items[item_index] if items[item_index] is Dictionary else {}
		if item_data.is_empty():
			continue
		var item_name: String = str(item_data.get("name", ""))
		var rolls: Dictionary = item_data.get("rolls", {}) if item_data.get("rolls", {}) is Dictionary else {}
		var options: Array = item_data.get("roll_options", []) if item_data.get("roll_options", []) is Array else []
		for option_index in range(options.size()):
			var option: Dictionary = options[option_index] if options[option_index] is Dictionary else {}
			var option_key: String = str(option.get("key", ""))
			if option_key == "":
				continue
			var minimum: float = float(option.get("min", option.get("default", 0.0)))
			var maximum: float = float(option.get("max", minimum))
			var step: float = max(0.0001, float(option.get("step", 1.0)))
			var current: float = float(rolls.get(option_key, option.get("default", minimum)))
			if current >= maximum:
				continue
			var expected: float = min(maximum, current + step)
			if step >= 1.0:
				expected = round(expected)
			return {
				"index": item_index,
				"item_name": item_name,
				"option_index": option_index,
				"option_key": option_key,
				"expected_value": expected,
			}
	return {}


func _send_mouse_button(
	menu: Object,
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
	menu.handle_input(event, owner, registry, view_size)


func _inventory_count(runtime: Object, item_name: String) -> int:
	var count := 0
	var snapshot: Dictionary = runtime.get_snapshot()
	for item_value in snapshot.get("inventory_items", []):
		if item_value is Dictionary and str(item_value.get("name", "")) == item_name:
			count += 1
	return count


func _inventory_roll_value(runtime: Object, item_name: String, option_key: String) -> float:
	var snapshot: Dictionary = runtime.get_snapshot()
	for item_value in snapshot.get("inventory_items", []):
		if not (item_value is Dictionary):
			continue
		if str(item_value.get("name", "")) != item_name:
			continue
		var rolls: Dictionary = item_value.get("rolls", {}) if item_value.get("rolls", {}) is Dictionary else {}
		return float(rolls.get(option_key, 0.0))
	return 0.0


func _roll_value_from_item(item_data: Dictionary, option_key: String) -> float:
	var rolls: Dictionary = item_data.get("rolls", {}) if item_data.get("rolls", {}) is Dictionary else {}
	return float(rolls.get(option_key, 0.0))


func _expect_close(actual: float, expected: float, message: String) -> void:
	if abs(actual - expected) > 0.0001:
		_failures.append("%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
