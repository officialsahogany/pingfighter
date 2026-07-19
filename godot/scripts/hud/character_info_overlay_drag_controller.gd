extends RefCounted

# Character-info inventory / equipment / active-item drag-and-drop + click-to-pick
# controller (original PingFighter parity). Operates on the overlay `target`
# (character_info_overlay_core) and reads its cached hit-test geometry. The pure
# routing helpers compute_drop_action / compute_trash_rect are smoke-sealed; the
# apply side dispatches to the already-sealed runtime APIs.

const CharacterInfoOverlayOwnerState := preload("res://scripts/hud/character_info_overlay_owner_state.gd")
const CharacterInfoOverlayHoverGeometry := preload("res://scripts/hud/character_info_overlay_hover_geometry.gd")
const CharacterInfoOverlayDiscardConfirm := preload("res://scripts/hud/character_info_overlay_discard_confirm.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const DRAG_THRESHOLD_PX := 6.0


# --- Pure routing -----------------------------------------------------------

static func compute_drop_action(drag: Dictionary, hit: Dictionary) -> Dictionary:
	var source: String = str(drag.get("source", ""))
	var region: String = str(hit.get("region", "none"))
	if region == "trash":
		match source:
			"bag":
				return {"action": "discard_inventory", "index": int(drag.get("inventory_index", -1))}
			"slot":
				return {"action": "discard_slot_item", "slot": str(drag.get("slot_key", ""))}
			"active":
				return {"action": "discard_active", "index": int(drag.get("active_index", -1))}
		return {"action": "none"}
	match source:
		"bag":
			if region == "slot":
				return {"action": "equip_to_slot", "index": int(drag.get("inventory_index", -1)), "slot": str(hit.get("slot_key", ""))}
			return {"action": "none"}
		"slot":
			if region == "slot" and str(hit.get("slot_key", "")) != str(drag.get("slot_key", "")) and str(hit.get("slot_key", "")) != "":
				return {"action": "slot_to_slot", "from_slot": str(drag.get("slot_key", "")), "to_slot": str(hit.get("slot_key", ""))}
			if region == "inventory":
				return {"action": "unequip_slot", "slot": str(drag.get("slot_key", ""))}
			return {"action": "none"}
		"active":
			var to_index: int = int(hit.get("active_index", -1))
			if region == "active" and to_index >= 0 and to_index != int(drag.get("active_index", -1)):
				return {"action": "reorder_active", "from": int(drag.get("active_index", -1)), "to": to_index}
			return {"action": "none"}
	return {"action": "none"}


static func compute_trash_rect(panel_rect: Rect2) -> Rect2:
	# Always-visible discard trash can in the panel's top-right corner, where the
	# old "선택 대기 / 퍽 골드" status line used to sit (original PingFighter parity).
	if panel_rect.size.x <= 0.0 or panel_rect.size.y <= 0.0:
		return Rect2()
	var size := Vector2(48.0, 48.0)
	var pos := Vector2(panel_rect.end.x - size.x - 20.0, panel_rect.position.y + 12.0)
	return Rect2(pos, size)


static func should_show_trash(target: Object) -> bool:
	# The trash can only receives drags that start from the equipment slots, the
	# active-item slots, or the passive vault. With the passive-item system retired
	# those sections are zero-hidden, so the always-on trash chrome would be a dead
	# drop target -- show it only while at least one drag-source section is laid out.
	for layout_key in ["_layout_equipment_rect", "_layout_active_items_rect", "_layout_inventory_rect"]:
		var value: Variant = target.get(layout_key)
		if value is Rect2 and (value as Rect2).size != Vector2.ZERO:
			return true
	return false


# --- Hit testing ------------------------------------------------------------

static func hit_test(target: Object, owner: Object, mouse_pos: Vector2) -> Dictionary:
	var result := {"region": "none", "slot_key": "", "active_index": -1, "inventory_index": -1, "occupied": false}
	var trash_rect: Rect2 = compute_trash_rect(target.get("_layout_panel_rect"))
	if trash_rect.size.x > 0.0 and trash_rect.has_point(mouse_pos):
		result.region = "trash"
		return result
	var inventory_rect: Rect2 = target.get("_last_passive_inventory_rect")
	var equipment_rect: Rect2 = target.get("_last_equipment_rect")
	if equipment_rect.has_point(mouse_pos):
		var slot_key: String = str(target.call("_get_equipment_slot_key_at_mouse", mouse_pos))
		if slot_key != "":
			result.region = "slot"
			result.slot_key = slot_key
			var slot_state: Dictionary = CharacterInfoOverlayOwnerState.equipment_state_from_owner(owner)
			var item: Dictionary = CharacterInfoOverlayOwnerState.equipment_item_or_empty(slot_state, slot_key, {})
			result.occupied = not item.is_empty() and str(item.get("name", "")) != ""
			return result
	var active_rect: Rect2 = target.get("_last_active_items_rect")
	if active_rect.has_point(mouse_pos):
		var active_index: int = CharacterInfoOverlayHoverGeometry.get_cached_linear_hover_index(
			mouse_pos,
			target.get("_last_active_slot_start"),
			float(target.get("_last_active_slot_size")),
			float(target.get("_last_active_slot_stride")),
			int(target.get("_last_active_slot_count"))
		)
		result.region = "active"
		result.active_index = active_index
		if active_index >= 0:
			var active_slots: Array = CharacterInfoOverlayOwnerState.owner_value(owner, "active_item_slots", []) as Array
			result.occupied = active_index < active_slots.size()
		return result
	if inventory_rect.has_point(mouse_pos):
		var inventory_index: int = CharacterInfoOverlayHoverGeometry.get_cached_grid_hover_index(
			mouse_pos,
			target.get("_last_passive_inventory_grid_rect"),
			target.get("_last_passive_grid_start"),
			float(target.get("_last_passive_grid_cell_size")),
			float(target.get("_last_passive_grid_stride")),
			int(target.get("_last_passive_grid_columns")),
			int(target.get("_last_passive_grid_item_count"))
		)
		result.region = "inventory"
		result.inventory_index = inventory_index
		result.occupied = inventory_index >= 0
		return result
	return result


# --- Drag lifecycle ---------------------------------------------------------

static func handle_left_press(target: Object, mouse_pos: Vector2, owner: Object, registry: Object) -> bool:
	return begin_drag(target, mouse_pos, owner, registry)


static func handle_left_release(target: Object, mouse_pos: Vector2, owner: Object, registry: Object) -> bool:
	# Original PingFighter parity: a mouse-up ALWAYS resolves the drop and clears
	# the hold (pingfighter.py:196249/196271/196307). A click without movement
	# resolves onto its own press position (a no-op) and is released — nothing
	# stays held.
	if not bool(target.get("_drag_active")) or not bool(target.get("_drag_is_mouse_down")):
		return false
	resolve_drop(target, mouse_pos, owner, registry)
	return true


static func handle_motion(target: Object, mouse_pos: Vector2) -> void:
	if not bool(target.get("_drag_active")):
		return
	target.set("_drag_current_pos", mouse_pos)
	if bool(target.get("_drag_is_mouse_down")):
		var press_pos: Vector2 = target.get("_drag_press_pos")
		if press_pos.distance_to(mouse_pos) >= DRAG_THRESHOLD_PX:
			target.set("_drag_moved", true)


static func begin_drag(target: Object, mouse_pos: Vector2, owner: Object, registry: Object) -> bool:
	var hit: Dictionary = hit_test(target, owner, mouse_pos)
	var source := ""
	match str(hit.get("region", "none")):
		"inventory":
			if int(hit.get("inventory_index", -1)) < 0:
				return false
			source = "bag"
		"slot":
			if not bool(hit.get("occupied", false)):
				return false
			source = "slot"
		"active":
			if int(hit.get("active_index", -1)) < 0 or not bool(hit.get("occupied", false)):
				return false
			source = "active"
		_:
			return false
	target.set("_drag_active", true)
	target.set("_drag_is_mouse_down", true)
	target.set("_drag_moved", false)
	target.set("_drag_source", source)
	target.set("_drag_inventory_index", int(hit.get("inventory_index", -1)))
	target.set("_drag_slot_key", str(hit.get("slot_key", "")))
	target.set("_drag_active_index", int(hit.get("active_index", -1)))
	target.set("_drag_press_pos", mouse_pos)
	target.set("_drag_current_pos", mouse_pos)
	return true


static func cancel_drag(target: Object) -> void:
	target.set("_drag_active", false)
	target.set("_drag_is_mouse_down", false)
	target.set("_drag_moved", false)
	target.set("_drag_source", "")
	target.set("_drag_inventory_index", -1)
	target.set("_drag_slot_key", "")
	target.set("_drag_active_index", -1)


static func resolve_drop(target: Object, mouse_pos: Vector2, owner: Object, registry: Object) -> bool:
	var drag := _drag_descriptor(target)
	var hit: Dictionary = hit_test(target, owner, mouse_pos)
	var action: Dictionary = compute_drop_action(drag, hit)
	var consumed: bool = apply_drop_action(target, action, owner, registry)
	cancel_drag(target)
	return consumed


static func _drag_descriptor(target: Object) -> Dictionary:
	return {
		"source": str(target.get("_drag_source")),
		"inventory_index": int(target.get("_drag_inventory_index")),
		"slot_key": str(target.get("_drag_slot_key")),
		"active_index": int(target.get("_drag_active_index")),
	}


# --- Apply ------------------------------------------------------------------

static func apply_drop_action(target: Object, action: Dictionary, owner: Object, registry: Object) -> bool:
	var mythic: Object = CharacterInfoOverlayOwnerState.get_instance(registry, "mythic_item_runtime")
	var active_runtime: Object = CharacterInfoOverlayOwnerState.get_instance(registry, "active_item_runtime")
	match str(action.get("action", "none")):
		"equip_to_slot":
			return mythic != null and bool(mythic.equip_inventory_item_to_slot(int(action.get("index", -1)), str(action.get("slot", "")), owner, registry))
		"slot_to_slot":
			return mythic != null and bool(mythic.swap_equipment_slots(str(action.get("from_slot", "")), str(action.get("to_slot", "")), owner, registry))
		"unequip_slot":
			return mythic != null and bool(mythic.unequip_slot(str(action.get("slot", "")), owner, registry))
		"reorder_active":
			return active_runtime != null and bool(active_runtime.reorder_active_slots(int(action.get("from", -1)), int(action.get("to", -1)), owner, registry))
		"discard_inventory":
			return _open_discard_confirm(target, owner, registry, mythic, {"kind": "inventory", "index": int(action.get("index", -1))})
		"discard_slot_item":
			if mythic == null:
				return false
			var inv_index: int = int(mythic.equipment_index.find_equipped_inventory_index_by_slot(mythic, str(action.get("slot", ""))))
			if inv_index < 0:
				return false
			return _open_discard_confirm(target, owner, registry, mythic, {"kind": "inventory", "index": inv_index})
		"discard_active":
			return _open_discard_confirm(target, owner, registry, mythic, {"kind": "active", "index": int(action.get("index", -1))})
	return false


# --- Discard confirm --------------------------------------------------------

static func ensure_confirm(target: Object) -> Object:
	var confirm: Object = target.get("_discard_confirm")
	if confirm == null:
		confirm = CharacterInfoOverlayDiscardConfirm.new()
		target.set("_discard_confirm", confirm)
	return confirm


static func is_confirm_active(target: Object) -> bool:
	var confirm: Object = target.get("_discard_confirm")
	return confirm != null and confirm.has_method("is_active") and bool(confirm.is_active())


static func handle_confirm_mouse_button(target: Object, mouse_pos: Vector2, button_index: int, owner: Object, registry: Object) -> bool:
	var confirm: Object = target.get("_discard_confirm")
	if confirm == null or not bool(confirm.is_active()):
		return false
	var action: StringName = confirm.handle_mouse_button(mouse_pos, button_index)
	if action == &"confirmed":
		_apply_confirmed_discard(target, owner, registry)
	elif action == &"cancelled":
		confirm.reset()
	return true


static func cancel_confirm(target: Object) -> void:
	var confirm: Object = target.get("_discard_confirm")
	if confirm != null and confirm.has_method("reset"):
		confirm.reset()


static func _apply_confirmed_discard(target: Object, owner: Object, registry: Object) -> void:
	var confirm: Object = target.get("_discard_confirm")
	if confirm == null:
		return
	var pending: Dictionary = confirm.get_pending()
	confirm.reset()
	match str(pending.get("kind", "")):
		"inventory":
			var mythic: Object = CharacterInfoOverlayOwnerState.get_instance(registry, "mythic_item_runtime")
			if mythic != null:
				mythic.discard_inventory_item(int(pending.get("index", -1)), owner, registry)
		"active":
			var active_runtime: Object = CharacterInfoOverlayOwnerState.get_instance(registry, "active_item_runtime")
			if active_runtime != null:
				active_runtime.discard_active_slot(int(pending.get("index", -1)), owner, registry)


static func _open_discard_confirm(target: Object, owner: Object, registry: Object, mythic: Object, pending: Dictionary) -> bool:
	var confirm: Object = ensure_confirm(target)
	var label: String = _label_for_pending(owner, registry, mythic, pending)
	return bool(confirm.open(label, pending))


static func _label_for_pending(owner: Object, registry: Object, mythic: Object, pending: Dictionary) -> String:
	match str(pending.get("kind", "")):
		"inventory":
			if mythic != null:
				var items: Array = mythic.inventory_items
				var index: int = int(pending.get("index", -1))
				if index >= 0 and index < items.size() and items[index] is Dictionary:
					return _item_label(items[index])
		"active":
			var active_slots: Array = CharacterInfoOverlayOwnerState.owner_value(owner, "active_item_slots", []) as Array
			var slot_index: int = int(pending.get("index", -1))
			if slot_index >= 0 and slot_index < active_slots.size() and active_slots[slot_index] is Dictionary:
				return _item_label(active_slots[slot_index])
	return ""


static func _item_label(item_data: Dictionary) -> String:
	var display_name: String = str(item_data.get("display_name", ""))
	if display_name != "":
		return display_name
	return str(item_data.get("name", ""))


# --- Drawing ----------------------------------------------------------------

static func draw_overlay(target: Object, canvas: CanvasItem, owner: Object, registry: Object, view_size: Vector2, font: Font, panel_rect: Rect2) -> void:
	if canvas == null:
		return
	var mouse_pos := Vector2.INF
	var viewport: Viewport = canvas.get_viewport()
	if viewport != null:
		mouse_pos = viewport.get_mouse_position()
	if is_confirm_active(target):
		var confirm: Object = target.get("_discard_confirm")
		confirm.draw(canvas, font, panel_rect, view_size, mouse_pos)
		return
	# Discard trash can in the top-right corner; brightens while an item is held and
	# turns red while hovered. Hidden while every drag-source section is zero-hidden
	# (see should_show_trash) -- no drag can start, so it would be a dead drop target.
	var dragging: bool = bool(target.get("_drag_active"))
	var trash_rect: Rect2 = compute_trash_rect(panel_rect) if should_show_trash(target) else Rect2()
	target.set("_last_trash_rect", trash_rect)
	_draw_trash(canvas, trash_rect, dragging, trash_rect.size.x > 0.0 and trash_rect.has_point(mouse_pos))
	if not dragging:
		return
	# Dragged item preview following the cursor.
	if not bool(target.get("_drag_moved")) and bool(target.get("_drag_is_mouse_down")):
		return
	var item_data: Dictionary = _dragged_item_data(target, owner, registry)
	if item_data.is_empty():
		return
	var preview_size := 46.0
	var preview_rect := Rect2(mouse_pos - Vector2(preview_size, preview_size) * 0.5, Vector2(preview_size, preview_size))
	var icon_renderer: Object = target.get("_active_item_icon_renderer")
	var visuals: Object = CharacterInfoOverlayOwnerState.get_instance(registry, "active_item_hud_visuals")
	canvas.draw_rect(preview_rect, Color(0.0, 0.0, 0.0, 0.35))
	if icon_renderer != null and icon_renderer.has_method("draw_icon"):
		icon_renderer.draw_icon(canvas, preview_rect, item_data, 1.0, visuals)
	else:
		canvas.draw_rect(preview_rect, Color(0.6, 0.6, 0.7, 0.7))
	canvas.draw_rect(preview_rect, Color(1.0, 1.0, 1.0, 0.6), false, 1.5)


static func _draw_trash(canvas: CanvasItem, rect: Rect2, dragging: bool, hovered: bool) -> void:
	# Procedural trash-can icon (lid + handle + body + ridges), mirroring the
	# original PingFighter panel trash button.
	if rect.size.x <= 0.0:
		return
	var bg_color: Color
	var border_color: Color
	if dragging and hovered:
		bg_color = Color(0.47, 0.16, 0.16)
		border_color = Color(1.0, 0.39, 0.39)
	elif dragging:
		bg_color = Color(0.235, 0.196, 0.196)
		border_color = Color(0.78, 0.59, 0.59)
	else:
		bg_color = Color(0.157, 0.172, 0.235)
		border_color = Color(0.39, 0.43, 0.51)
	canvas.draw_rect(rect, bg_color)
	canvas.draw_rect(rect, border_color, false, 2.0)
	var center_x: float = rect.position.x + rect.size.x * 0.5
	var center_y: float = rect.position.y + rect.size.y * 0.5
	var icon_color: Color = Color(0.71, 0.71, 0.75) if dragging else Color(0.55, 0.55, 0.59)
	var body_rect := Rect2(center_x - 11.0, center_y - 12.0 + 4.0, 22.0, 24.0)
	canvas.draw_rect(body_rect, icon_color)
	var lid_rect := Rect2(center_x - 13.0, center_y - 12.0 - 2.0, 26.0, 6.0)
	canvas.draw_rect(lid_rect, icon_color.lightened(0.12))
	var handle_rect := Rect2(center_x - 4.0, lid_rect.position.y - 4.0 + 1.0, 8.0, 4.0)
	canvas.draw_rect(handle_rect, icon_color.lightened(0.24))
	var ridge_color := Color(0.47, 0.47, 0.51)
	for i in range(3):
		var line_x: float = body_rect.position.x + 5.0 + float(i) * 6.0
		canvas.draw_line(Vector2(line_x, body_rect.position.y + 4.0), Vector2(line_x, body_rect.position.y + body_rect.size.y - 4.0), ridge_color, 1.0)


static func _dragged_item_data(target: Object, owner: Object, registry: Object) -> Dictionary:
	match str(target.get("_drag_source")):
		"bag":
			var mythic: Object = CharacterInfoOverlayOwnerState.get_instance(registry, "mythic_item_runtime")
			if mythic != null:
				var items: Array = mythic.inventory_items
				var index: int = int(target.get("_drag_inventory_index"))
				if index >= 0 and index < items.size() and items[index] is Dictionary:
					return items[index]
		"slot":
			var slot_state: Dictionary = CharacterInfoOverlayOwnerState.equipment_state_from_owner(owner)
			return CharacterInfoOverlayOwnerState.equipment_item_or_empty(slot_state, str(target.get("_drag_slot_key")), {})
		"active":
			var active_slots: Array = CharacterInfoOverlayOwnerState.owner_value(owner, "active_item_slots", []) as Array
			var slot_index: int = int(target.get("_drag_active_index"))
			if slot_index >= 0 and slot_index < active_slots.size() and active_slots[slot_index] is Dictionary:
				return active_slots[slot_index]
	return {}
