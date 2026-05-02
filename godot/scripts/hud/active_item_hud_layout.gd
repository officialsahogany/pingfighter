extends RefCounted

const ACTIVE_ITEM_MAX_SLOTS := 3
const ACTIVE_ITEM_SLOT_BASE_SIZE := 42.0
const ACTIVE_ITEM_SLOT_BASE_MARGIN := 2.0
const ACTIVE_ITEM_SLOT_BASE_PADDING := 4.0


func build_layout(
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	gameplay_width: float,
	item_count: int
) -> Dictionary:
	var bottom_pillar_y: float = game_offset.y + game_size.y
	var bottom_pillar_h: float = view_size.y - bottom_pillar_y
	if bottom_pillar_h < 18.0:
		return {"visible": false}

	var scale_factor: float = game_size.x / gameplay_width
	var slot_w: float = max(16.0, floor(ACTIVE_ITEM_SLOT_BASE_SIZE * scale_factor))
	var slot_h: float = slot_w
	var slot_margin: float = max(1.0, floor(ACTIVE_ITEM_SLOT_BASE_MARGIN * scale_factor))
	var box_padding: float = max(2.0, floor(ACTIVE_ITEM_SLOT_BASE_PADDING * scale_factor))
	var slot_step: float = slot_w + slot_margin
	var max_slots: int = max(1, ACTIVE_ITEM_MAX_SLOTS)
	var actual_item_count: int = max(0, item_count)
	var overflow_count: int = max(0, actual_item_count - max_slots)

	var box_inner_width: float = float(max_slots) * slot_w + float(max_slots - 1) * slot_margin
	var box_width: float = box_inner_width + box_padding * 2.0
	var box_height: float = slot_h + box_padding * 2.0
	var overflow_box_width: float = 0.0
	if overflow_count > 0:
		var overflow_inner_width: float = float(overflow_count) * slot_w + float(overflow_count - 1) * slot_margin
		overflow_box_width = overflow_inner_width + box_padding * 2.0 - 1.0

	var total_width: float = box_width + overflow_box_width
	var box_y: float = bottom_pillar_y + max(2.0, floor((bottom_pillar_h - box_height) * 0.5))
	box_y = max(bottom_pillar_y + 2.0, box_y - max(1.0, floor(3.0 * scale_factor)))

	var game_area_right: float = game_offset.x + game_size.x
	var total_start_x: float = game_offset.x + floor((game_size.x - total_width) * 0.5)
	if total_start_x < game_offset.x:
		total_start_x = game_offset.x
	if total_start_x + total_width > game_area_right:
		total_start_x = game_area_right - total_width

	var box_x: float = total_start_x
	var main_box_rect := Rect2(box_x, box_y, box_width, box_height)
	var overflow_box_x: float = box_x + box_width - 1.0
	var overflow_box_rect := Rect2()
	var overflow_visible := false
	if overflow_count > 0 and overflow_box_width > 0.0:
		var actual_overflow_width: float = min(overflow_box_width + 1.0, game_area_right - overflow_box_x)
		if actual_overflow_width > 0.0:
			overflow_visible = true
			overflow_box_rect = Rect2(overflow_box_x, box_y, actual_overflow_width, box_height)

	var slot_rects: Array[Rect2] = []
	var slot_overflow_flags: Array[bool] = []
	var total_slots: int = max(max_slots, actual_item_count)
	var slot_start_x: float = box_x + box_padding
	var slot_start_y: float = box_y + box_padding

	for slot_index in range(total_slots):
		var slot_x: float
		if slot_index < max_slots:
			slot_x = slot_start_x + float(slot_index) * slot_step
		else:
			var overflow_idx: int = slot_index - max_slots
			slot_x = overflow_box_x + box_padding + float(overflow_idx) * slot_step
		if slot_x >= game_area_right or slot_x + slot_w > game_area_right:
			break
		slot_rects.append(Rect2(slot_x, slot_start_y, slot_w, slot_h))
		slot_overflow_flags.append(slot_index >= max_slots)

	return {
		"visible": true,
		"scale_factor": scale_factor,
		"max_slots": max_slots,
		"actual_item_count": actual_item_count,
		"overflow_count": overflow_count,
		"main_box_rect": main_box_rect,
		"overflow_box_rect": overflow_box_rect,
		"overflow_visible": overflow_visible,
		"slot_rects": slot_rects,
		"slot_overflow_flags": slot_overflow_flags,
	}
