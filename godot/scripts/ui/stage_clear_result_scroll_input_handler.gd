extends RefCounted

const StageClearResultInteractionState := preload("res://scripts/ui/stage_clear_result_interaction_state.gd")
const StageClearResultScrollState := preload("res://scripts/ui/stage_clear_result_scroll_state.gd")


static func get_button_layout(
	scroll_phase: String,
	draw_scale: float,
	position_offset: Vector2
) -> Dictionary:
	return StageClearResultInteractionState.get_visible_scroll_button_layout(
		scroll_phase,
		draw_scale,
		position_offset
	)


static func get_button_click_result(
	mouse_position: Vector2,
	scroll_phase: String,
	draw_scale: float,
	position_offset: Vector2
) -> Dictionary:
	var layout: Dictionary = get_button_layout(scroll_phase, draw_scale, position_offset)
	var clicked_button: String = StageClearResultInteractionState.get_clicked_button(
		mouse_position,
		layout.get("next_stage_rect", Rect2()),
		layout.get("exit_rect", Rect2()),
		scroll_phase
	)
	layout["clicked_button"] = clicked_button
	return layout


static func get_hovered_button_result(
	mouse_position: Vector2,
	previous_hovered_button: String,
	scroll_phase: String,
	draw_scale: float,
	position_offset: Vector2
) -> Dictionary:
	var layout: Dictionary = get_button_layout(scroll_phase, draw_scale, position_offset)
	var hovered_button: String = StageClearResultInteractionState.get_hovered_button(
		mouse_position,
		layout.get("next_stage_rect", Rect2()),
		layout.get("exit_rect", Rect2())
	)
	layout["hovered_button"] = hovered_button
	layout["changed"] = hovered_button != previous_hovered_button
	return layout


static func get_hovered_button_apply_result(
	hover_result: Dictionary,
	current_hovered_button: String
) -> Dictionary:
	var result: Dictionary = _get_button_layout_apply_result(hover_result)
	result["hovered_button"] = str(hover_result.get("hovered_button", current_hovered_button))
	result["redraw"] = bool(hover_result.get("changed", false))
	return result


static func get_drag_start_result(
	mouse_position: Vector2,
	scroll_phase: String,
	blocked: bool,
	draw_scale: float,
	position_offset: Vector2
) -> Dictionary:
	return StageClearResultInteractionState.get_scroll_drag_start_state(
		mouse_position,
		scroll_phase,
		blocked,
		draw_scale,
		position_offset
	)


static func get_drag_start_apply_result(
	drag_state: Dictionary,
	current_scroll_dragging: bool,
	current_grab_offset: Vector2,
	current_hovered_button: String
) -> Dictionary:
	var button_layout: Dictionary = _extract_button_layout(drag_state)
	var result: Dictionary = _get_button_layout_apply_result(button_layout)
	var started: bool = bool(drag_state.get("started", false))
	result["started"] = started
	result["scroll_dragging"] = true if started else current_scroll_dragging
	result["scroll_drag_grab_offset"] = drag_state.get("grab_offset", current_grab_offset) if started else current_grab_offset
	result["hovered_button"] = str(drag_state.get("hovered_button", current_hovered_button)) if started else current_hovered_button
	result["redraw"] = started
	return result


static func get_drag_update_result(
	mouse_position: Vector2,
	grab_offset: Vector2,
	scroll_phase: String,
	draw_scale: float,
	view_size: Vector2
) -> Dictionary:
	var next_position_offset: Vector2 = StageClearResultScrollState.get_region_drag_offset(
		mouse_position,
		grab_offset,
		draw_scale,
		view_size
	)
	var layout: Dictionary = get_button_layout(scroll_phase, draw_scale, next_position_offset)
	layout["position_offset"] = next_position_offset
	return layout


static func get_drag_update_apply_result(
	update_result: Dictionary,
	current_position_offset: Vector2
) -> Dictionary:
	var result: Dictionary = _get_button_layout_apply_result(update_result)
	result["scroll_position_offset"] = update_result.get("position_offset", current_position_offset)
	result["redraw"] = true
	return result


static func get_drag_finish_result(
	mouse_position: Vector2,
	grab_offset: Vector2,
	scroll_phase: String,
	current_hovered_button: String,
	draw_scale: float,
	view_size: Vector2
) -> Dictionary:
	var update_result: Dictionary = get_drag_update_result(
		mouse_position,
		grab_offset,
		scroll_phase,
		draw_scale,
		view_size
	)
	if scroll_phase == StageClearResultInteractionState.PHASE_VISIBLE:
		var hover_result: Dictionary = get_hovered_button_result(
			mouse_position,
			current_hovered_button,
			scroll_phase,
			draw_scale,
			update_result.get("position_offset", Vector2.ZERO)
		)
		update_result["next_stage_rect"] = hover_result.get("next_stage_rect", Rect2())
		update_result["exit_rect"] = hover_result.get("exit_rect", Rect2())
		update_result["hovered_button"] = str(hover_result.get("hovered_button", current_hovered_button))
		update_result["hover_changed"] = bool(hover_result.get("changed", false))
	return update_result


static func get_drag_finish_apply_result(
	finish_result: Dictionary,
	scroll_phase: String,
	current_position_offset: Vector2,
	current_hovered_button: String
) -> Dictionary:
	var result: Dictionary = _get_button_layout_apply_result(finish_result)
	result["scroll_position_offset"] = finish_result.get("position_offset", current_position_offset)
	result["scroll_dragging"] = false
	if scroll_phase == StageClearResultInteractionState.PHASE_VISIBLE:
		result["hovered_button"] = str(finish_result.get("hovered_button", current_hovered_button))
	result["redraw"] = true
	return result


static func get_drag_cancel_apply_result(current_scroll_dragging: bool) -> Dictionary:
	return {
		"scroll_dragging": false if current_scroll_dragging else current_scroll_dragging,
		"redraw": current_scroll_dragging,
	}


static func get_scroll_state_apply_result(scroll_state_result: Dictionary, current_state: Dictionary) -> Dictionary:
	return {
		"next_stage_rect": _rect_value(scroll_state_result, current_state, "next_stage_rect"),
		"exit_rect": _rect_value(scroll_state_result, current_state, "exit_rect"),
		"scroll_position_offset": _vector2_value(scroll_state_result, current_state, "scroll_position_offset"),
		"scroll_dragging": bool(scroll_state_result.get("scroll_dragging", current_state.get("scroll_dragging", false))),
		"scroll_drag_grab_offset": _vector2_value(scroll_state_result, current_state, "scroll_drag_grab_offset"),
		"hovered_button": str(scroll_state_result.get("hovered_button", current_state.get("hovered_button", StageClearResultInteractionState.BUTTON_NONE))),
	}


static func _extract_button_layout(source: Dictionary) -> Dictionary:
	var button_layout_value: Variant = source.get("button_layout", {})
	return button_layout_value if button_layout_value is Dictionary else {}


static func _get_button_layout_apply_result(source: Dictionary) -> Dictionary:
	return {
		"next_stage_rect": source.get("next_stage_rect", Rect2()),
		"exit_rect": source.get("exit_rect", Rect2()),
	}


static func _rect_value(scroll_state_result: Dictionary, current_state: Dictionary, key: String) -> Rect2:
	var current_value: Variant = current_state.get(key, Rect2())
	if not current_value is Rect2:
		current_value = Rect2()
	var value: Variant = scroll_state_result.get(key, current_value)
	if value is Rect2:
		return value
	return current_value


static func _vector2_value(scroll_state_result: Dictionary, current_state: Dictionary, key: String) -> Vector2:
	var current_value: Variant = current_state.get(key, Vector2.ZERO)
	if not current_value is Vector2:
		current_value = Vector2.ZERO
	var value: Variant = scroll_state_result.get(key, current_value)
	if value is Vector2:
		return value
	return current_value
