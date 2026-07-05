extends SceneTree

# Seals the character-info drag-and-drop routing + hit-test + drop dispatch.
# compute_drop_action is the pure routing table; the FakeTarget integration
# proves press -> drop dispatches to the correct (already-sealed) runtime API.

const DragController := preload("res://scripts/hud/character_info_overlay_drag_controller.gd")


class RecordingMythic:
	var calls: Array = []
	var equipment_index: Object = null
	var inventory_items: Array = [{"name": "ragnarok_hammer", "display_name": "라그나로크 해머"}]

	func discard_inventory_item(index: int, _owner: Object, _registry: Object) -> bool:
		calls.append(["discard_inventory", index])
		return true

	func equip_inventory_item_to_slot(index: int, slot_key: String, _owner: Object, _registry: Object) -> bool:
		calls.append(["equip_to_slot", index, slot_key])
		return true

	func swap_equipment_slots(slot_a: String, slot_b: String, _owner: Object, _registry: Object) -> bool:
		calls.append(["swap", slot_a, slot_b])
		return true

	func unequip_slot(slot_key: String, _owner: Object, _registry: Object) -> bool:
		calls.append(["unequip", slot_key])
		return true


class RecordingActive:
	var calls: Array = []

	func reorder_active_slots(from_index: int, to_index: int, _owner: Object, _registry: Object) -> bool:
		calls.append(["reorder", from_index, to_index])
		return true


class FakeRegistry:
	var mythic: Object
	var active: Object

	func get_instance(key: String) -> Object:
		if key == "mythic_item_runtime":
			return mythic
		if key == "active_item_runtime":
			return active
		return null


class FakeOwner:
	var equipment_slots: Dictionary = {}
	var active_item_slots: Array = []


class FakeTarget:
	var _layout_panel_rect := Rect2(0, 0, 800, 700)
	var _last_passive_inventory_rect := Rect2(0, 500, 200, 200)
	var _last_passive_inventory_grid_rect := Rect2(0, 500, 200, 200)
	var _last_passive_grid_start := Vector2(0, 500)
	var _last_passive_grid_cell_size := 40.0
	var _last_passive_grid_stride := 44.0
	var _last_passive_grid_columns := 4
	var _last_passive_grid_item_count := 6
	var _last_equipment_rect := Rect2(0, 0, 200, 200)
	var _last_active_items_rect := Rect2(0, 250, 200, 80)
	var _last_active_slot_start := Vector2(0, 250)
	var _last_active_slot_size := 40.0
	var _last_active_slot_stride := 50.0
	var _last_active_slot_count := 3
	var _drag_active := false
	var _drag_is_mouse_down := false
	var _drag_moved := false
	var _drag_source := ""
	var _drag_inventory_index := -1
	var _drag_slot_key := ""
	var _drag_active_index := -1
	var _drag_press_pos := Vector2.ZERO
	var _drag_current_pos := Vector2.ZERO
	var _last_trash_rect := Rect2()
	var _discard_confirm: Object = null
	var _active_item_icon_renderer: Object = null

	func _get_equipment_slot_key_at_mouse(mouse_pos: Vector2) -> String:
		if not _last_equipment_rect.has_point(mouse_pos):
			return ""
		return "left_arm" if mouse_pos.x < 100.0 else "right_arm"


func _init() -> void:
	_verify_pure_routing()
	_verify_trash_rect()
	_verify_begin_and_drop_dispatch()
	_verify_slot_to_inventory_unequip()
	_verify_active_reorder_dispatch()
	_verify_click_without_movement_is_noop()
	_verify_press_then_release_on_slot_equips()
	_verify_trash_discard_confirm_flow()
	print("character_info_overlay_drag_controller_smoke: ok")
	quit(0)


func _verify_pure_routing() -> void:
	var bag := {"source": "bag", "inventory_index": 2, "slot_key": "", "active_index": -1}
	_expect(str(DragController.compute_drop_action(bag, {"region": "slot", "slot_key": "right_arm"}).get("action")) == "equip_to_slot", "bag -> slot should equip to slot")
	_expect(str(DragController.compute_drop_action(bag, {"region": "trash"}).get("action")) == "discard_inventory", "bag -> trash should discard inventory item")
	_expect(str(DragController.compute_drop_action(bag, {"region": "inventory", "inventory_index": 1}).get("action")) == "none", "bag -> inventory should be a no-op")

	var slot := {"source": "slot", "inventory_index": -1, "slot_key": "left_arm", "active_index": -1}
	_expect(str(DragController.compute_drop_action(slot, {"region": "slot", "slot_key": "right_arm"}).get("action")) == "slot_to_slot", "slot -> other slot should swap")
	_expect(str(DragController.compute_drop_action(slot, {"region": "slot", "slot_key": "left_arm"}).get("action")) == "none", "slot -> same slot should be a no-op")
	_expect(str(DragController.compute_drop_action(slot, {"region": "inventory", "inventory_index": -1}).get("action")) == "unequip_slot", "slot -> inventory should unequip")
	_expect(str(DragController.compute_drop_action(slot, {"region": "trash"}).get("action")) == "discard_slot_item", "slot -> trash should discard the equipped item")

	var act := {"source": "active", "inventory_index": -1, "slot_key": "", "active_index": 0}
	_expect(str(DragController.compute_drop_action(act, {"region": "active", "active_index": 2}).get("action")) == "reorder_active", "active -> other active should reorder")
	_expect(str(DragController.compute_drop_action(act, {"region": "active", "active_index": 0}).get("action")) == "none", "active -> same active should be a no-op")
	_expect(str(DragController.compute_drop_action(act, {"region": "trash"}).get("action")) == "discard_active", "active -> trash should discard the active item")


func _verify_trash_rect() -> void:
	var panel := Rect2(0, 0, 800, 700)
	var trash: Rect2 = DragController.compute_trash_rect(panel)
	_expect(trash.size.x > 0.0, "trash rect should be non-empty for a valid panel rect")
	_expect(panel.encloses(trash), "trash rect should sit inside the panel rect")
	_expect(trash.end.x <= panel.end.x and trash.position.x > panel.get_center().x, "trash rect should sit in the panel's right region")
	_expect(trash.position.y < panel.get_center().y, "trash rect should sit in the panel's top region")
	_expect(DragController.compute_trash_rect(Rect2()).size == Vector2.ZERO, "trash rect for an empty panel rect should be empty")


func _make_context() -> Dictionary:
	var mythic := RecordingMythic.new()
	var active := RecordingActive.new()
	var registry := FakeRegistry.new()
	registry.mythic = mythic
	registry.active = active
	return {"target": FakeTarget.new(), "owner": FakeOwner.new(), "registry": registry, "mythic": mythic, "active": active}


func _verify_begin_and_drop_dispatch() -> void:
	var ctx := _make_context()
	var target: Object = ctx.target
	# Press over an inventory item (grid cell 0 -> index 0).
	_expect(DragController.begin_drag(target, Vector2(10, 510), ctx.owner, ctx.registry), "press over an inventory item should begin a drag")
	_expect(target._drag_source == "bag", "inventory drag source should be 'bag'")
	_expect(target._drag_inventory_index == 0, "inventory drag should capture the grid index")
	# Drop onto the right-arm equipment slot.
	DragController.resolve_drop(target, Vector2(150, 100), ctx.owner, ctx.registry)
	_expect(ctx.mythic.calls.size() == 1 and ctx.mythic.calls[0][0] == "equip_to_slot" and str(ctx.mythic.calls[0][2]) == "right_arm", "dropping a bag item on a slot should call equip_inventory_item_to_slot")
	_expect(not target._drag_active, "a resolved drop should clear the held state")


func _verify_slot_to_inventory_unequip() -> void:
	var ctx := _make_context()
	var target: Object = ctx.target
	ctx.owner.equipment_slots = {"left_arm": {"name": "ragnarok_hammer", "_equipped_slot": "left_arm"}}
	_expect(DragController.begin_drag(target, Vector2(40, 100), ctx.owner, ctx.registry), "press over an occupied slot should begin a drag")
	_expect(target._drag_source == "slot" and target._drag_slot_key == "left_arm", "slot drag should capture the slot key")
	# Drop into the inventory region (empty cell -> still inventory region).
	DragController.resolve_drop(target, Vector2(190, 690), ctx.owner, ctx.registry)
	_expect(ctx.mythic.calls.size() == 1 and ctx.mythic.calls[0][0] == "unequip" and str(ctx.mythic.calls[0][1]) == "left_arm", "dropping a slot item into the inventory should unequip it")


func _verify_active_reorder_dispatch() -> void:
	var ctx := _make_context()
	var target: Object = ctx.target
	ctx.owner.active_item_slots = [{"name": "a"}, {"name": "b"}, {"name": "c"}]
	_expect(DragController.begin_drag(target, Vector2(10, 270), ctx.owner, ctx.registry), "press over an occupied active slot should begin a drag")
	_expect(target._drag_source == "active" and target._drag_active_index == 0, "active drag should capture slot 0")
	DragController.resolve_drop(target, Vector2(110, 270), ctx.owner, ctx.registry)
	_expect(ctx.active.calls.size() == 1 and ctx.active.calls[0][0] == "reorder" and int(ctx.active.calls[0][1]) == 0 and int(ctx.active.calls[0][2]) == 2, "dropping an active item on another slot should reorder")


func _verify_click_without_movement_is_noop() -> void:
	# Original parity: a mouse-up always clears the hold. A click that doesn't move
	# resolves onto its own press position (a no-op) and leaves nothing held.
	var ctx := _make_context()
	var target: Object = ctx.target
	_expect(DragController.handle_left_press(target, Vector2(10, 510), ctx.owner, ctx.registry), "press over an item should be consumed")
	_expect(target._drag_active, "a press over an item should begin a drag")
	_expect(DragController.handle_left_release(target, Vector2(10, 510), ctx.owner, ctx.registry), "release should be consumed")
	_expect(not target._drag_active, "a click without movement must NOT keep the item held")
	_expect(ctx.mythic.calls.is_empty(), "a click without movement should be a no-op (no equip)")


func _verify_press_then_release_on_slot_equips() -> void:
	# A real drag through the press -> release path equips at the release position.
	var ctx := _make_context()
	var target: Object = ctx.target
	_expect(DragController.handle_left_press(target, Vector2(10, 510), ctx.owner, ctx.registry), "press over a bag item should begin a drag")
	_expect(DragController.handle_left_release(target, Vector2(150, 100), ctx.owner, ctx.registry), "release over a slot should be consumed")
	_expect(ctx.mythic.calls.size() == 1 and ctx.mythic.calls[0][0] == "equip_to_slot" and str(ctx.mythic.calls[0][2]) == "right_arm", "releasing a dragged bag item on a slot should equip it there")
	_expect(not target._drag_active, "a completed drag should clear the held state")


func _verify_trash_discard_confirm_flow() -> void:
	var ctx := _make_context()
	var target: Object = ctx.target
	# Pick up a bag item and drop it on the trash zone.
	_expect(DragController.begin_drag(target, Vector2(10, 510), ctx.owner, ctx.registry), "press over a bag item should begin a drag")
	var trash: Rect2 = DragController.compute_trash_rect(target._layout_panel_rect)
	DragController.resolve_drop(target, trash.get_center(), ctx.owner, ctx.registry)
	_expect(DragController.is_confirm_active(target), "dropping on the trash should open the discard-confirm modal")
	_expect(ctx.mythic.calls.is_empty(), "the discard must NOT happen until the player confirms")
	var pending: Dictionary = target._discard_confirm.get_pending()
	_expect(str(pending.get("kind")) == "inventory" and int(pending.get("index")) == 0, "the confirm should hold the inventory discard target")
	# Confirm the discard.
	DragController._apply_confirmed_discard(target, ctx.owner, ctx.registry)
	_expect(ctx.mythic.calls.size() == 1 and ctx.mythic.calls[0][0] == "discard_inventory" and int(ctx.mythic.calls[0][1]) == 0, "confirming should discard the inventory item")
	_expect(not DragController.is_confirm_active(target), "confirming should close the modal")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
