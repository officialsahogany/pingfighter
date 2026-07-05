extends RefCounted


static func refresh_skill_slot_layout_arrays(
	rect: Rect2,
	slot_size: float,
	max_slots: int,
	rect_cache: Array[Rect2],
	icon_rect_cache: Array[Rect2],
	fallback_rect_cache: Array[Rect2],
	center_cache: Array[Vector2],
	center_x_cache: Array[float]
) -> Dictionary:
	_resize_arrays([rect_cache, icon_rect_cache, fallback_rect_cache, center_cache, center_x_cache], max_slots)
	var skill_slot_step: float = slot_size + 8.0
	var start_x: float = rect.position.x + (rect.size.x - (slot_size * float(max_slots) + 8.0 * float(max_slots - 1))) * 0.5
	var slot_y: float = rect.position.y + 42.0
	var skill_icon_size: float = slot_size - 20.0
	var fallback_icon_size: float = slot_size - 26.0
	for i in range(max_slots):
		var slot_x: float = start_x + float(i) * skill_slot_step
		rect_cache[i] = Rect2(slot_x, slot_y, slot_size, slot_size)
		icon_rect_cache[i] = Rect2(slot_x + (slot_size - skill_icon_size) * 0.5, slot_y + 5.0, skill_icon_size, skill_icon_size)
		fallback_rect_cache[i] = Rect2(slot_x + (slot_size - fallback_icon_size) * 0.5, slot_y + 9.0, fallback_icon_size, fallback_icon_size)
		center_x_cache[i] = slot_x + slot_size * 0.5
		center_cache[i] = Vector2(center_x_cache[i], slot_y + slot_size * 0.5)
	return {
		"start": Vector2(start_x, slot_y),
		"stride": skill_slot_step,
		"label_y": slot_y + slot_size - 11.0,
	}


static func refresh_active_slot_layout_arrays(
	rect: Rect2,
	slot_size: float,
	gap: float,
	max_slots: int,
	rect_cache: Array[Rect2],
	fallback_rect_cache: Array[Rect2],
	center_x_cache: Array[float]
) -> Dictionary:
	_resize_arrays([rect_cache, fallback_rect_cache, center_x_cache], max_slots)
	var y: float = rect.position.y + 44.0
	var active_slot_start_x: float = rect.position.x + gap
	var active_slot_step: float = slot_size + gap
	for i in range(max_slots):
		var slot_x: float = active_slot_start_x + float(i) * active_slot_step
		rect_cache[i] = Rect2(slot_x, y, slot_size, slot_size)
		fallback_rect_cache[i] = Rect2(slot_x + 10.0, y + 10.0, slot_size - 20.0, slot_size - 20.0)
		center_x_cache[i] = slot_x + slot_size * 0.5
	return {
		"start": Vector2(active_slot_start_x, y),
		"stride": active_slot_step,
		"empty_marker_y": y + slot_size * 0.5 + 5.0,
		"label_y": y + slot_size + 16.0,
	}


static func refresh_perk_grid_layout_arrays(
	grid_rect: Rect2,
	cell_size: float,
	stride: float,
	columns: int,
	item_count: int,
	scroll: float,
	cell_rect_cache: Array[Rect2],
	icon_rect_cache: Array[Rect2],
	center_x_cache: Array[float],
	level_y_cache: Array[float],
	visible_index_cache: Array[int]
) -> Dictionary:
	_resize_arrays([cell_rect_cache, icon_rect_cache, center_x_cache, level_y_cache], item_count)
	var rows: int = int(ceil(float(item_count) / float(columns)))
	var visible_first_row: int = max(0, int(ceil((scroll - cell_size) / stride)))
	var visible_last_row: int = min(rows - 1, int(floor((scroll + grid_rect.size.y) / stride)))
	visible_index_cache.clear()
	var start_x: float = grid_rect.position.x + (grid_rect.size.x - (cell_size * float(columns) + (stride - cell_size) * float(columns - 1))) * 0.5
	var start_y: float = grid_rect.position.y - scroll
	# Hex cells read roomier than the old squares — let the perk icon fill the
	# cell (orb icons carry transparent corners), keeping the badge strip below.
	var perk_icon_w: float = cell_size - 4.0
	var perk_icon_h: float = cell_size - 13.0
	for row in range(visible_first_row, visible_last_row + 1):
		var row_y: float = start_y + float(row) * stride
		if row_y + cell_size < grid_rect.position.y or row_y > grid_rect.end.y:
			continue
		for col in range(columns):
			var i: int = row * columns + col
			if i >= item_count:
				break
			var cell_x: float = start_x + float(col) * stride
			cell_rect_cache[i] = Rect2(cell_x, row_y, cell_size, cell_size)
			icon_rect_cache[i] = Rect2(cell_x + 2.0, row_y + 2.0, perk_icon_w, perk_icon_h)
			center_x_cache[i] = cell_x + cell_size * 0.5
			level_y_cache[i] = row_y + cell_size - 4.0
			visible_index_cache.append(i)
	return {
		"start": Vector2(start_x, start_y),
		"visible_first_row": visible_first_row,
		"visible_last_row": visible_last_row,
	}


static func refresh_passive_inventory_grid_layout_arrays(
	grid_rect: Rect2,
	cell_size: float,
	stride: float,
	columns: int,
	item_count: int,
	scroll: float,
	cell_rect_cache: Array[Rect2],
	icon_rect_cache: Array[Rect2],
	fallback_rect_cache: Array[Rect2],
	badge_rect_cache: Array[Rect2],
	badge_center_x_cache: Array[float],
	badge_center_y_cache: Array[float],
	visible_index_cache: Array[int]
) -> Dictionary:
	_resize_arrays([cell_rect_cache, icon_rect_cache, fallback_rect_cache, badge_rect_cache, badge_center_x_cache, badge_center_y_cache], item_count)
	var rows: int = int(ceil(float(item_count) / float(columns)))
	var visible_first_row: int = max(0, int(ceil(scroll / stride)))
	var visible_last_row: int = min(rows - 1, int(floor((scroll + grid_rect.size.y - cell_size) / stride)))
	visible_index_cache.clear()
	var start_x: float = grid_rect.position.x + (grid_rect.size.x - (cell_size * float(columns) + (stride - cell_size) * float(columns - 1))) * 0.5
	var start_y: float = grid_rect.position.y - scroll
	for row in range(visible_first_row, visible_last_row + 1):
		var row_y: float = start_y + float(row) * stride
		if row_y < grid_rect.position.y or row_y + cell_size > grid_rect.end.y:
			continue
		for col in range(columns):
			var i: int = row * columns + col
			if i >= item_count:
				break
			var cell_x: float = start_x + float(col) * stride
			cell_rect_cache[i] = Rect2(cell_x, row_y, cell_size, cell_size)
			icon_rect_cache[i] = Rect2(cell_x + 5.0, row_y + 5.0, cell_size - 10.0, cell_size - 10.0)
			fallback_rect_cache[i] = Rect2(cell_x + 9.0, row_y + 9.0, cell_size - 18.0, cell_size - 18.0)
			badge_rect_cache[i] = Rect2(cell_x + cell_size - 18.0, row_y + cell_size - 14.0, 16.0, 12.0)
			badge_center_x_cache[i] = cell_x + cell_size - 10.0
			badge_center_y_cache[i] = row_y + cell_size - 6.0
			visible_index_cache.append(i)
	return {
		"start": Vector2(start_x, start_y),
		"visible_first_row": visible_first_row,
		"visible_last_row": visible_last_row,
	}


static func _resize_arrays(arrays: Array, size: int) -> void:
	for values: Array in arrays:
		values.resize(size)
