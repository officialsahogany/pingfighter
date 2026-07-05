extends RefCounted

const CharacterInfoOverlayValueUtils := preload("res://scripts/hud/character_info_overlay_value_utils.gd")


static func handle_input(target: Object, event: InputEvent, owner: Object, registry: Object) -> bool:
	if not bool(target.get("active")):
		return false
	if event is InputEventMouseMotion:
		return _handle_mouse_motion(target, event)
	if event is InputEventKey:
		return _handle_key(target, event)
	if event is InputEventMouseButton:
		return _handle_mouse_button(target, event, owner, registry)
	return true


static func _handle_mouse_motion(target: Object, event: InputEvent) -> bool:
	var motion_event: InputEventMouseMotion = event
	if bool(target.get("_drag_active")):
		target.call("_drag_handle_motion", motion_event.position)
		target.call("_request_redraw", true)
		return true
	if bool(target.call("_should_redraw_for_mouse_motion", motion_event.position)):
		target.call("_request_redraw", true)
	return true


static func _handle_key(target: Object, event: InputEvent) -> bool:
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return true
	if key_event.keycode == KEY_TAB or key_event.physical_keycode == KEY_TAB or key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE:
		if bool(target.call("_is_discard_confirm_active")):
			target.call("_cancel_discard_confirm")
			target.call("_reset_hover_and_request_redraw", true)
			return true
		if bool(target.get("_drag_active")):
			target.call("_drag_cancel")
			target.call("_reset_hover_and_request_redraw", true)
			return true
		if bool(target.call("_is_pendulum_interior_active")):
			target.call("_close_pendulum_interior")
			return true
		target.call("close", true)
	return true


static func _handle_mouse_button(target: Object, event: InputEvent, owner: Object, registry: Object) -> bool:
	var mouse_event: InputEventMouseButton = event
	# Discard-confirm modal intercepts everything while it is open.
	if bool(target.call("_is_discard_confirm_active")):
		if bool(target.call("_handle_discard_confirm_mouse_button", mouse_event.position, mouse_event.button_index, owner, registry)):
			target.call("_reset_hover_and_request_redraw", true)
		return true
	if bool(target.call("_is_pendulum_interior_active")):
		return bool(target.call("_handle_pendulum_mouse_button", mouse_event.position, mouse_event.button_index))
	# Inventory / equipment / active-item drag-and-drop + click-to-pick.
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		if mouse_event.pressed:
			if bool(target.call("_drag_handle_left_press", mouse_event.position, owner, registry)):
				target.call("_reset_hover_and_request_redraw", true)
				return true
		else:
			if bool(target.call("_drag_handle_left_release", mouse_event.position, owner, registry)):
				target.call("_reset_hover_and_request_redraw", true)
				return true
	# Right-click cancels a held item before doing normal right-click work.
	if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT and bool(target.get("_drag_active")):
		target.call("_drag_cancel")
		target.call("_reset_hover_and_request_redraw", true)
		return true
	if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		if bool(target.call("_try_handle_lingpet_slot_tab_click", mouse_event.position, owner, registry)):
			target.call("_reset_hover_and_request_redraw", true)
			return true
		if bool(target.call("_try_handle_lingpet_pendulum_open_click", mouse_event.position, owner, registry)):
			target.call("_reset_hover_and_request_redraw", true)
			return true
		if bool(target.call("_try_handle_lingpet_unlock_pick_click", mouse_event.position, owner, registry)):
			target.call("_reset_hover_and_request_redraw", true)
			return true
	if mouse_event.pressed and _handle_passive_inventory_mouse_button(target, mouse_event, owner, registry):
		return true
	if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		if bool(target.call("_try_handle_equipment_context_click", mouse_event.position, owner, registry)):
			target.call("_reset_hover_and_request_redraw", true)
			return true
	if mouse_event.pressed:
		_handle_perk_grid_mouse_button(target, mouse_event)
	return true


static func _handle_passive_inventory_mouse_button(target: Object, mouse_event: InputEventMouseButton, owner: Object, registry: Object) -> bool:
	var inventory_rect: Rect2 = target.get("_last_passive_inventory_rect")
	if not inventory_rect.has_point(mouse_event.position):
		return false
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		if bool(target.call("_try_handle_passive_inventory_context_click", mouse_event.position, owner, registry)):
			target.call("_reset_hover_and_request_redraw", true)
		return true
	var max_scroll: float = max(0.0, float(target.get("_last_passive_inventory_content_height")) - inventory_rect.size.y + 48.0)
	var previous_scroll: float = float(target.get("passive_inventory_scroll"))
	var next_scroll: float = CharacterInfoOverlayValueUtils.scroll_value_for_button(previous_scroll, mouse_event.button_index, max_scroll)
	target.set("passive_inventory_scroll", next_scroll)
	if not is_equal_approx(next_scroll, previous_scroll):
		target.call("_reset_hover_and_request_redraw", true)
	return true


static func _handle_perk_grid_mouse_button(target: Object, mouse_event: InputEventMouseButton) -> void:
	var perk_rect: Rect2 = target.get("_last_perk_grid_rect")
	if not perk_rect.has_point(mouse_event.position):
		return
	var max_scroll: float = max(0.0, float(target.get("_last_perk_content_height")) - perk_rect.size.y)
	var previous_scroll: float = float(target.get("perk_scroll"))
	var next_scroll: float = CharacterInfoOverlayValueUtils.scroll_value_for_button(previous_scroll, mouse_event.button_index, max_scroll)
	target.set("perk_scroll", next_scroll)
	if not is_equal_approx(next_scroll, previous_scroll):
		target.call("_reset_hover_and_request_redraw", true)
