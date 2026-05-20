extends RefCounted

const DEFAULT_ACTIVE_ITEM_MAX_SLOTS := 3
const ACTIVE_ITEM_SLOT_BASE_SIZE := 42.0
const ACTIVE_ITEM_SLOT_BASE_MARGIN := 2.0
const ACTIVE_ITEM_SLOT_BASE_PADDING := 4.0
const ACTIVE_ITEM_SLOT_BOTTOM_DROP := 24.0
const ACTIVE_ITEM_MOBILE_SLOT_MIN_SIZE := 46.0
const ACTIVE_ITEM_MOBILE_SLOT_MAX_SIZE := 70.0
const ACTIVE_ITEM_MOBILE_BOTTOM_MARGIN_MIN := 12.0
const ACTIVE_ITEM_MOBILE_BOTTOM_MARGIN_RATIO := 0.025
const ACTIVE_ITEM_MOBILE_BOTTOM_LIFT_MIN := 82.0
const ACTIVE_ITEM_MOBILE_BOTTOM_LIFT_RATIO := 0.085
const ACTIVE_ITEM_MOBILE_SIDE_MARGIN_MIN := 10.0
const ACTIVE_ITEM_MOBILE_SIDE_Y_RATIO := 0.42
const ACTIVE_ITEM_MOBILE_SIDE_MAX_Y_RATIO := 0.62

var _cached_layout_key: String = ""
var _cached_layout: Dictionary = {}


func build_layout(
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	gameplay_width: float,
	item_count: int,
	slot_capacity: int = DEFAULT_ACTIVE_ITEM_MAX_SLOTS
) -> Dictionary:
	var resolved_capacity: int = max(1, slot_capacity)
	var layout_key: String = "%s|%s|%s|%.3f|%d|%d|%s" % [
		view_size,
		game_offset,
		game_size,
		gameplay_width,
		item_count,
		resolved_capacity,
		_is_mobile_runtime(),
	]
	if layout_key == _cached_layout_key:
		return _cached_layout
	var scale_factor: float = game_size.x / gameplay_width
	var mobile_runtime: bool = _is_mobile_runtime()
	var slot_w: float = max(16.0, floor(ACTIVE_ITEM_SLOT_BASE_SIZE * scale_factor))
	if mobile_runtime:
		slot_w = clamp(slot_w, ACTIVE_ITEM_MOBILE_SLOT_MIN_SIZE, ACTIVE_ITEM_MOBILE_SLOT_MAX_SIZE)
		scale_factor = slot_w / ACTIVE_ITEM_SLOT_BASE_SIZE
	var slot_h: float = slot_w
	var slot_margin: float = max(1.0, floor(ACTIVE_ITEM_SLOT_BASE_MARGIN * scale_factor))
	var box_padding: float = max(2.0, floor(ACTIVE_ITEM_SLOT_BASE_PADDING * scale_factor))
	if mobile_runtime:
		slot_margin = max(slot_margin, 3.0)
		box_padding = max(box_padding, 5.0)
	var slot_step: float = slot_w + slot_margin
	var max_slots: int = resolved_capacity
	var actual_item_count: int = max(0, item_count)
	var overflow_count: int = max(0, actual_item_count - max_slots)

	var box_inner_width: float = float(max_slots) * slot_w + float(max_slots - 1) * slot_margin
	var box_width: float = box_inner_width + box_padding * 2.0
	var box_height: float = slot_h + box_padding * 2.0
	var overflow_box_width: float = 0.0
	if overflow_count > 0:
		var overflow_inner_width: float = float(overflow_count) * slot_w + float(overflow_count - 1) * slot_margin
		overflow_box_width = overflow_inner_width + box_padding * 2.0 - 1.0

	var bottom_pillar_y: float = game_offset.y + game_size.y
	var bottom_pillar_h: float = view_size.y - bottom_pillar_y
	var mobile_overlay: bool = mobile_runtime
	if bottom_pillar_h < 18.0 and not mobile_overlay:
		return _cache_layout(layout_key, {"visible": false})

	var total_width: float = box_width + overflow_box_width
	var game_area_left: float = game_offset.x
	var game_area_right: float = game_offset.x + game_size.x
	var mobile_side_rect: Rect2 = _get_mobile_side_slot_rect(view_size, game_offset, game_size, total_width, box_height)
	var mobile_side_layout: bool = mobile_overlay and mobile_side_rect.size.x > 0.0
	var box_y: float
	var total_start_x: float
	if mobile_side_layout:
		box_y = game_offset.y + floor(game_size.y * ACTIVE_ITEM_MOBILE_SIDE_Y_RATIO) - box_height * 0.5
		var side_min_y: float = mobile_side_rect.position.y
		var side_max_y: float = min(
			mobile_side_rect.end.y - box_height,
			game_offset.y + floor(game_size.y * ACTIVE_ITEM_MOBILE_SIDE_MAX_Y_RATIO) - box_height
		)
		side_max_y = max(side_min_y, side_max_y)
		box_y = clamp(box_y, side_min_y, side_max_y)
		game_area_left = mobile_side_rect.position.x
		game_area_right = mobile_side_rect.end.x
		total_start_x = mobile_side_rect.position.x + floor((mobile_side_rect.size.x - total_width) * 0.5)
	elif mobile_overlay:
		var bottom_margin: float = max(
			ACTIVE_ITEM_MOBILE_BOTTOM_MARGIN_MIN,
			floor(view_size.y * ACTIVE_ITEM_MOBILE_BOTTOM_MARGIN_RATIO)
		)
		var bottom_lift: float = max(
			ACTIVE_ITEM_MOBILE_BOTTOM_LIFT_MIN,
			floor(game_size.y * ACTIVE_ITEM_MOBILE_BOTTOM_LIFT_RATIO)
		)
		var safe_bottom: float = min(view_size.y - bottom_margin, bottom_pillar_y - bottom_margin)
		if safe_bottom <= box_height:
			safe_bottom = view_size.y - bottom_margin
		box_y = safe_bottom - box_height - bottom_lift
		var min_y: float = max(0.0, game_offset.y + max(6.0, floor(game_size.y * 0.05)))
		var max_y: float = max(0.0, safe_bottom - box_height)
		box_y = clamp(box_y, min_y, max_y)
		game_area_left = 0.0
		game_area_right = view_size.x
		total_start_x = floor((view_size.x - total_width) * 0.5)
	else:
		box_y = bottom_pillar_y + max(2.0, floor((bottom_pillar_h - box_height) * 0.5))
		var bottom_limit: float = bottom_pillar_y + bottom_pillar_h - box_height - max(2.0, floor(2.0 * scale_factor))
		bottom_limit = max(bottom_pillar_y + 2.0, bottom_limit)
		box_y = clamp(
			box_y - max(1.0, floor(3.0 * scale_factor)) + max(0.0, floor(ACTIVE_ITEM_SLOT_BOTTOM_DROP * scale_factor)),
			bottom_pillar_y + 2.0,
			bottom_limit
		)
		total_start_x = game_offset.x + floor((game_size.x - total_width) * 0.5)
	if total_start_x < game_area_left:
		total_start_x = game_area_left
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

	return _cache_layout(layout_key, {
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
		"mobile_overlay": mobile_overlay,
		"mobile_side_layout": mobile_side_layout,
	})


func _get_mobile_side_slot_rect(
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	total_width: float,
	box_height: float
) -> Rect2:
	if not _is_mobile_runtime():
		return Rect2()
	var margin: float = ACTIVE_ITEM_MOBILE_SIDE_MARGIN_MIN
	var min_width: float = total_width + margin * 2.0
	var min_height: float = box_height + margin * 2.0
	var left_width: float = max(0.0, game_offset.x)
	var right_x: float = game_offset.x + game_size.x
	var right_width: float = max(0.0, view_size.x - right_x)
	var left_rect := Rect2(Vector2.ZERO, Vector2(left_width, view_size.y))
	var right_rect := Rect2(Vector2(right_x, 0.0), Vector2(right_width, view_size.y))
	if left_rect.size.x >= min_width and left_rect.size.y >= min_height:
		return left_rect.grow_individual(-margin, -margin, -margin, -margin)
	if right_rect.size.x >= min_width and right_rect.size.y >= min_height:
		return right_rect.grow_individual(-margin, -margin, -margin, -margin)
	return Rect2()


func _is_mobile_runtime() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")


func _cache_layout(key: String, layout: Dictionary) -> Dictionary:
	_cached_layout_key = key
	_cached_layout = layout
	return layout
