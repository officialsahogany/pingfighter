extends RefCounted

const StageClearResultLayoutHelper := preload("res://scripts/ui/stage_clear_result_layout_helper.gd")

const BUTTON_NONE := "none"
const BUTTON_NEXT_STAGE := "next_stage"
const BUTTON_EXIT := "exit"
const PHASE_VISIBLE := "visible"


static func get_scroll_button_layout(scroll_rect: Rect2, draw_scale: float) -> Dictionary:
	var button_size := Vector2(280.0, 64.0) * draw_scale
	var gap: float = 28.0 * draw_scale
	var total_width: float = button_size.x * 2.0 + gap
	var start_x: float = scroll_rect.position.x + (scroll_rect.size.x - total_width) * 0.5
	var button_y: float = scroll_rect.position.y + scroll_rect.size.y - 90.0 * draw_scale
	return {
		"next_stage_rect": Rect2(Vector2(start_x, button_y), button_size),
		"exit_rect": Rect2(Vector2(start_x + button_size.x + gap, button_y), button_size),
	}


static func get_hovered_button(mouse_position: Vector2, next_stage_rect: Rect2, exit_rect: Rect2) -> String:
	if _rect_contains_mouse(next_stage_rect, mouse_position):
		return BUTTON_NEXT_STAGE
	if _rect_contains_mouse(exit_rect, mouse_position):
		return BUTTON_EXIT
	return BUTTON_NONE


static func get_clicked_button(
	mouse_position: Vector2,
	next_stage_rect: Rect2,
	exit_rect: Rect2,
	scroll_phase: String
) -> String:
	if scroll_phase != PHASE_VISIBLE:
		return BUTTON_NONE
	return get_hovered_button(mouse_position, next_stage_rect, exit_rect)


static func get_hovered_box_index(
	boxes: Array,
	mouse_position: Vector2,
	draw_scale: float,
	timer: float,
	base_size: Vector2,
	hover_grow: float,
	default_amplitude: float,
	default_speed: float
) -> int:
	return _get_box_index_at_mouse(boxes, mouse_position, draw_scale, timer, base_size, hover_grow, default_amplitude, default_speed, false)


static func get_clicked_idle_box_index(
	boxes: Array,
	mouse_position: Vector2,
	draw_scale: float,
	timer: float,
	base_size: Vector2,
	hover_grow: float,
	default_amplitude: float,
	default_speed: float
) -> int:
	return _get_box_index_at_mouse(boxes, mouse_position, draw_scale, timer, base_size, hover_grow, default_amplitude, default_speed, true)


static func get_box_state_counts(boxes: Array) -> Dictionary:
	var opened_count: int = 0
	var opening_count: int = 0
	for box_value in boxes:
		if not (box_value is Dictionary):
			continue
		var box: Dictionary = box_value
		var state: String = str(box.get("state", "idle"))
		if state == "opened":
			opened_count += 1
		elif state == "opening":
			opening_count += 1
	return {
		"opened_count": opened_count,
		"opening_count": opening_count,
	}


static func all_boxes_opened(boxes: Array) -> bool:
	if boxes.is_empty():
		return false
	for box_value in boxes:
		if not (box_value is Dictionary):
			continue
		var box: Dictionary = box_value
		if str(box.get("state", "idle")) != "opened":
			return false
	return true


static func _get_box_index_at_mouse(
	boxes: Array,
	mouse_position: Vector2,
	draw_scale: float,
	timer: float,
	base_size: Vector2,
	hover_grow: float,
	default_amplitude: float,
	default_speed: float,
	idle_only: bool
) -> int:
	for i in range(boxes.size() - 1, -1, -1):
		var box: Dictionary = boxes[i] if boxes[i] is Dictionary else {}
		if idle_only and str(box.get("state", "idle")) != "idle":
			continue
		if StageClearResultLayoutHelper.get_box_aabb(
			box,
			draw_scale,
			timer,
			base_size,
			hover_grow,
			default_amplitude,
			default_speed
		).has_point(mouse_position):
			return i
	return -1


static func _rect_contains_mouse(rect: Rect2, mouse_position: Vector2) -> bool:
	return rect.size.x > 0.0 and rect.has_point(mouse_position)
