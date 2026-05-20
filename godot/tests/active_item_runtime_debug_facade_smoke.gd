extends SceneTree

const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const ActiveItemRuntimeDebugFacade := preload("res://scripts/items/active_item_runtime_debug_facade.gd")

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
	_verify_debug_facade_menu_state_and_inventory()
	_verify_runtime_delegates_debug_lifecycle()

	if _failures.is_empty():
		print("active_item_runtime_debug_facade_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_debug_facade_menu_state_and_inventory() -> void:
	var runtime: Object = ActiveItemRuntime.new()
	_finish_runtime_initialization(runtime)
	var facade: Object = ActiveItemRuntimeDebugFacade.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var view_size := Vector2(900.0, 720.0)

	facade.toggle_debug_spawn_menu(runtime)
	_expect(facade.is_debug_spawn_menu_open(runtime), "debug facade should toggle menu open")

	var first_cell: Rect2 = runtime.debug_spawn_menu._get_cell_rect(runtime.debug_spawn_menu._get_panel_rect(view_size), 0)
	var wheel_event := InputEventMouseButton.new()
	wheel_event.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_event.pressed = true
	wheel_event.position = first_cell.get_center()
	_expect(
		facade.handle_debug_spawn_menu_input(runtime, wheel_event, view_size, owner, registry),
		"debug facade should handle wheel input"
	)
	_expect(owner.active_item_slots.size() == 1, "debug facade wheel input should add one item")
	_expect(str(owner.active_item_slots[0].get("name", "")) == "gauge_charge", "debug facade should preserve menu item selection")
	_expect(int(facade.get_debug_item_counts(runtime, owner).get("gauge_charge", 0)) == 1, "debug facade should expose counts")

	_expect(facade.debug_remove_item_from_slot(runtime, "gauge_charge", owner, registry), "debug facade should remove item")
	_expect(owner.active_item_slots.is_empty(), "debug facade remove should mutate owner slots")
	facade.close_debug_spawn_menu(runtime)
	_expect(not facade.is_debug_spawn_menu_open(runtime), "debug facade should close menu")


func _verify_runtime_delegates_debug_lifecycle() -> void:
	var runtime: Object = ActiveItemRuntime.new()
	_finish_runtime_initialization(runtime)
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()

	runtime.toggle_debug_spawn_menu()
	_expect(runtime.is_debug_spawn_menu_open(), "runtime should delegate debug menu toggle")
	runtime.close_debug_spawn_menu()
	_expect(not runtime.is_debug_spawn_menu_open(), "runtime should delegate debug menu close")

	_expect(runtime.debug_spawn_item("gauge_charge", owner, registry), "runtime should delegate debug spawn")
	_expect(runtime.fill_empty_slots_with_item("gauge_charge", owner, registry) == 2, "runtime should delegate debug fill")
	_expect(owner.active_item_slots.size() == 3, "runtime delegated debug fill should respect slot capacity")
	_expect(runtime.grant_item_to_slot("gauge_charge", owner, registry, true), "runtime should delegate overflow grant")
	_expect(owner.active_item_slots.size() == 4, "runtime delegated overflow grant should append")
	_expect(int(runtime.get_debug_item_counts(owner).get("gauge_charge", 0)) == 4, "runtime should delegate debug counts")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish_runtime_initialization(runtime: Object) -> void:
	var guard := 0
	while runtime != null and runtime.has_method("prewarm_initialization_step") and not bool(runtime.prewarm_initialization_step()):
		guard += 1
		if guard > 64:
			_failures.append("active item runtime staged initialization did not finish")
			return
