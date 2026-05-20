extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemDebugInventory := preload("res://scripts/items/active_item_debug_inventory.gd")
const ActiveItemDebugSpawnMenu := preload("res://scripts/items/active_item_debug_spawn_menu.gd")
const ActiveItemRuntimeDebugFacade := preload("res://scripts/items/active_item_runtime_debug_facade.gd")
const ActiveItemSlotController := preload("res://scripts/items/active_item_slot_controller.gd")

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


class FakeEffectGate:
	extends RefCounted

	func can_store_item(_item_name: String) -> bool:
		return true


class FakeCountingInventory:
	extends RefCounted

	var count_calls := 0

	func get_debug_item_counts(_owner: Object) -> Dictionary:
		count_calls += 1
		return {}


class FakeRuntime:
	extends RefCounted

	var debug_spawn_menu: Object = null
	var debug_inventory: Object = null
	var item_catalog: Object = null
	var slot_controller: Object = null
	var effect_controller: Object = null
	var spawned_field_items: Array[String] = []

	func spawn_field_item(item_name: String, _position: Variant = null) -> bool:
		spawned_field_items.append(item_name)
		return true


func _init() -> void:
	_verify_closed_debug_draw_skips_inventory_counts()
	_verify_menu_state_and_inventory_actions()
	_verify_spawn_mode_uses_field_spawn_path()

	if _failures.is_empty():
		print("active_item_runtime_debug_facade_direct_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _build_runtime() -> FakeRuntime:
	var runtime := FakeRuntime.new()
	runtime.debug_spawn_menu = ActiveItemDebugSpawnMenu.new()
	runtime.debug_inventory = ActiveItemDebugInventory.new()
	runtime.item_catalog = ActiveItemCatalog.new()
	runtime.slot_controller = ActiveItemSlotController.new()
	runtime.effect_controller = FakeEffectGate.new()
	return runtime


func _verify_closed_debug_draw_skips_inventory_counts() -> void:
	var facade := ActiveItemRuntimeDebugFacade.new()
	var runtime := _build_runtime()
	var counting_inventory := FakeCountingInventory.new()
	runtime.debug_inventory = counting_inventory
	facade.draw_debug_spawn_menu(runtime, null, Vector2(900.0, 720.0), FakeOwner.new())
	_expect(counting_inventory.count_calls == 0, "closed debug menu draw should not scan active item counts")


func _verify_menu_state_and_inventory_actions() -> void:
	var facade := ActiveItemRuntimeDebugFacade.new()
	var runtime := _build_runtime()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var view_size := Vector2(900.0, 720.0)

	facade.toggle_debug_spawn_menu(runtime)
	_expect(facade.is_debug_spawn_menu_open(runtime), "debug facade should toggle the menu open")

	var first_cell: Rect2 = runtime.debug_spawn_menu._get_cell_rect(runtime.debug_spawn_menu._get_panel_rect(view_size), 0)
	var wheel_event := InputEventMouseButton.new()
	@warning_ignore("int_as_enum_without_cast")
	wheel_event.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_event.pressed = true
	wheel_event.position = first_cell.get_center()
	_expect(
		facade.handle_debug_spawn_menu_input(runtime, wheel_event, view_size, owner, registry),
		"debug facade should handle mouse wheel input"
	)
	_expect(owner.active_item_slots.size() == 1, "debug facade wheel input should grant one slot item")
	_expect(str(owner.active_item_slots[0].get("name", "")) == "gauge_charge", "debug facade should preserve menu item id")
	_expect(int(facade.get_debug_item_counts(runtime, owner).get("gauge_charge", 0)) == 1, "debug facade should expose slot counts")

	_expect(facade.fill_empty_slots_with_item(runtime, "gauge_charge", owner, registry) == 2, "debug facade should fill remaining slots")
	_expect(owner.active_item_slots.size() == 3, "debug facade fill should respect normal slot capacity")
	_expect(facade.grant_item_to_slot(runtime, "gauge_charge", owner, registry, true), "debug facade should allow explicit overflow grants")
	_expect(owner.active_item_slots.size() == 4, "debug facade overflow grant should append beyond normal capacity")
	_expect(facade.debug_remove_item_from_slot(runtime, "gauge_charge", owner, registry), "debug facade should remove a matching item")
	_expect(owner.active_item_slots.size() == 3, "debug facade remove should mutate owner slots")

	facade.close_debug_spawn_menu(runtime)
	_expect(not facade.is_debug_spawn_menu_open(runtime), "debug facade should close the menu")


func _verify_spawn_mode_uses_field_spawn_path() -> void:
	var facade := ActiveItemRuntimeDebugFacade.new()
	var runtime := _build_runtime()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var view_size := Vector2(900.0, 720.0)

	facade.toggle_debug_spawn_menu(runtime)
	var panel_rect: Rect2 = runtime.debug_spawn_menu._get_panel_rect(view_size)
	var spawn_button: Rect2 = runtime.debug_spawn_menu._get_action_button_rect(panel_rect, 1)
	var first_cell: Rect2 = runtime.debug_spawn_menu._get_cell_rect(panel_rect, 0)

	var mode_event := _build_mouse_event(MOUSE_BUTTON_LEFT, spawn_button.get_center())
	_expect(
		facade.handle_debug_spawn_menu_input(runtime, mode_event, view_size, owner, registry),
		"debug facade should handle the spawn mode button"
	)
	_expect(runtime.debug_spawn_menu.action_mode == "spawn", "debug facade should leave the menu in spawn mode")

	var spawn_event := _build_mouse_event(MOUSE_BUTTON_LEFT, first_cell.get_center())
	_expect(
		facade.handle_debug_spawn_menu_input(runtime, spawn_event, view_size, owner, registry),
		"debug facade should handle spawn mode cell clicks"
	)
	_expect(owner.active_item_slots.is_empty(), "spawn mode should not grant slot inventory items")
	_expect(runtime.spawned_field_items == ["gauge_charge"], "spawn mode should call the runtime field-spawn path")


func _build_mouse_event(button_index: int, position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	@warning_ignore("int_as_enum_without_cast")
	event.button_index = button_index
	event.pressed = true
	event.position = position
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
