extends RefCounted

static func rect_map_key_contains_mouse(rects: Dictionary, key_text: String, mouse_pos: Vector2) -> bool:
	var rect_value: Variant = rects.get(key_text, null)
	if rect_value == null and key_text.is_valid_int():
		rect_value = rects.get(int(key_text), null)
	if not (rect_value is Rect2):
		return false
	var rect: Rect2 = rect_value
	return rect.has_point(mouse_pos)

static func get_rect_map_hover_signature(rects: Dictionary, mouse_pos: Vector2, prefix: String) -> String:
	for key_value in rects:
		var rect_value: Variant = rects[key_value]
		if rect_value is Rect2:
			var rect: Rect2 = rect_value
			if rect.has_point(mouse_pos):
				return prefix + ":" + str(key_value)
	return ""

static func rect_list_index_contains_mouse(rects: Array[Rect2], key_text: String, mouse_pos: Vector2) -> bool:
	var index: int = int(key_text) if key_text.is_valid_int() else -1
	return index >= 0 and index < rects.size() and rects[index].has_point(mouse_pos)

static func get_rect_list_hover_signature(rects: Array[Rect2], mouse_pos: Vector2, prefix: String) -> String:
	for i in range(rects.size()):
		if rects[i].has_point(mouse_pos):
			return prefix + ":" + str(i)
	return ""

static func equipment_hover_signature(mouse_pos: Vector2, slot_index: int, keys: Array[String], has_indexed_layout: bool, fallback_rects: Dictionary) -> String:
	if slot_index >= 0:
		return "equipment:%s" % (str(keys[slot_index]) if slot_index < keys.size() else str(slot_index))
	if has_indexed_layout:
		return ""
	return get_rect_map_hover_signature(fallback_rects, mouse_pos, "equipment")

static func equipment_signature_contains_mouse(key_text: String, mouse_pos: Vector2, index_cache: Dictionary, rect_list_cache: Array[Rect2], has_indexed_layout: bool, fallback_rects: Dictionary) -> bool:
	var slot_index: int = int(key_text) if key_text.is_valid_int() else int(index_cache.get(key_text, -1))
	if slot_index >= 0 and slot_index < rect_list_cache.size():
		return rect_list_cache[slot_index].has_point(mouse_pos)
	if has_indexed_layout:
		return false
	return rect_map_key_contains_mouse(fallback_rects, key_text, mouse_pos)

static func find_hovered_rect_index(rects: Array[Rect2], mouse_pos: Vector2) -> int:
	for i in range(rects.size()):
		if rects[i].has_point(mouse_pos):
			return i
	return -1

static func set_grid_hover_layout(target: Object, start: Vector2, cell_size: float, stride: float, columns: int, item_count: int, start_property: String, cell_size_property: String, stride_property: String, columns_property: String, item_count_property: String) -> void:
	target.set(start_property, start)
	target.set(cell_size_property, cell_size)
	target.set(stride_property, stride)
	target.set(columns_property, columns)
	target.set(item_count_property, item_count)

static func set_linear_hover_layout(target: Object, start: Vector2, slot_size: float, stride: float, slot_count: int, start_property: String, slot_size_property: String, stride_property: String, slot_count_property: String) -> void:
	target.set(start_property, start)
	target.set(slot_size_property, slot_size)
	target.set(stride_property, stride)
	target.set(slot_count_property, slot_count)

static func should_redraw_for_mouse_motion(target: Object, mouse_pos: Vector2, hover_signature: String, last_hover_signature: String, has_mouse_redraw_position: bool, last_mouse_redraw_position: Vector2, redraw_distance_sq: float) -> bool:
	if hover_signature != last_hover_signature:
		target.set("_last_hover_signature", hover_signature)
		target.set("_last_mouse_redraw_position", mouse_pos)
		target.set("_has_mouse_redraw_position", true)
		return last_hover_signature.find(":") >= 0 or hover_signature.find(":") >= 0
	if hover_signature.find(":") < 0 or not has_mouse_redraw_position:
		target.set("_last_mouse_redraw_position", mouse_pos)
		target.set("_has_mouse_redraw_position", true)
		return hover_signature.find(":") >= 0
	if mouse_pos.distance_squared_to(last_mouse_redraw_position) >= redraw_distance_sq:
		target.set("_last_mouse_redraw_position", mouse_pos)
		return true
	return false

static func overlay_signature_contains_mouse(
	signature: String,
	mouse_pos: Vector2,
	passive_inventory_rect: Rect2,
	perk_grid_rect: Rect2,
	equipment_contains_callable: Callable,
	skill_start: Vector2,
	skill_size: float,
	skill_stride: float,
	skill_count: int,
	active_start: Vector2,
	active_size: float,
	active_stride: float,
	active_count: int,
	passive_grid_rect: Rect2,
	passive_start: Vector2,
	passive_cell_size: float,
	passive_stride: float,
	passive_columns: int,
	passive_count: int,
	perk_start: Vector2,
	perk_cell_size: float,
	perk_stride: float,
	perk_columns: int,
	perk_count: int,
	lingpet_skill_rects: Array[Rect2],
	lingpet_stat_rects: Array[Rect2]
) -> bool:
	if signature == "passive_inventory":
		return passive_inventory_rect.has_point(mouse_pos)
	if signature == "perk_grid":
		return perk_grid_rect.has_point(mouse_pos)
	var delimiter: int = signature.find(":")
	if delimiter < 0:
		return false
	var prefix: String = signature.substr(0, delimiter)
	var key_text: String = signature.substr(delimiter + 1)
	match prefix:
		"equipment":
			return bool(equipment_contains_callable.call(key_text, mouse_pos))
		"skill":
			return cached_linear_signature_contains_mouse(key_text, mouse_pos, skill_start, skill_size, skill_stride, skill_count)
		"active_item":
			return cached_linear_signature_contains_mouse(key_text, mouse_pos, active_start, active_size, active_stride, active_count)
		"passive_item":
			return cached_grid_signature_contains_mouse(key_text, mouse_pos, passive_grid_rect, passive_start, passive_cell_size, passive_stride, passive_columns, passive_count)
		"perk":
			return cached_grid_signature_contains_mouse(key_text, mouse_pos, perk_grid_rect, perk_start, perk_cell_size, perk_stride, perk_columns, perk_count)
		"lingpet_skill":
			return rect_list_index_contains_mouse(lingpet_skill_rects, key_text, mouse_pos)
		"lingpet_stat":
			return rect_list_index_contains_mouse(lingpet_stat_rects, key_text, mouse_pos)
	return false

static func overlay_hover_signature(
	mouse_pos: Vector2,
	last_hover_signature: String,
	hover_contains_callable: Callable,
	equipment_rect: Rect2,
	equipment_signature_callable: Callable,
	skill_rect: Rect2,
	skill_start: Vector2,
	skill_size: float,
	skill_stride: float,
	skill_count: int,
	active_rect: Rect2,
	active_start: Vector2,
	active_size: float,
	active_stride: float,
	active_count: int,
	passive_inventory_rect: Rect2,
	passive_grid_rect: Rect2,
	passive_start: Vector2,
	passive_cell_size: float,
	passive_stride: float,
	passive_columns: int,
	passive_count: int,
	perk_grid_rect: Rect2,
	perk_start: Vector2,
	perk_cell_size: float,
	perk_stride: float,
	perk_columns: int,
	perk_count: int,
	lingpet_skill_rects: Array[Rect2],
	lingpet_stat_rects: Array[Rect2]
) -> String:
	if last_hover_signature.find(":") >= 0 and bool(hover_contains_callable.call(last_hover_signature, mouse_pos)):
		return last_hover_signature
	if equipment_rect.has_point(mouse_pos):
		var equipment_signature: String = str(equipment_signature_callable.call(mouse_pos))
		if equipment_signature != "":
			return equipment_signature
	if skill_rect.has_point(mouse_pos):
		var skill_signature: String = get_cached_linear_hover_signature(mouse_pos, skill_start, skill_size, skill_stride, skill_count, "skill")
		if skill_signature != "":
			return skill_signature
	if active_rect.has_point(mouse_pos):
		var active_item_signature: String = get_cached_linear_hover_signature(mouse_pos, active_start, active_size, active_stride, active_count, "active_item")
		if active_item_signature != "":
			return active_item_signature
	if passive_inventory_rect.has_point(mouse_pos):
		var passive_signature: String = get_cached_grid_hover_signature(mouse_pos, passive_grid_rect, passive_start, passive_cell_size, passive_stride, passive_columns, passive_count, "passive_item")
		return passive_signature if passive_signature != "" else "passive_inventory"
	if perk_grid_rect.has_point(mouse_pos):
		var perk_signature: String = get_cached_grid_hover_signature(mouse_pos, perk_grid_rect, perk_start, perk_cell_size, perk_stride, perk_columns, perk_count, "perk")
		return perk_signature if perk_signature != "" else "perk_grid"
	var lingpet_skill_signature: String = get_rect_list_hover_signature(lingpet_skill_rects, mouse_pos, "lingpet_skill")
	if lingpet_skill_signature != "":
		return lingpet_skill_signature
	return get_rect_list_hover_signature(lingpet_stat_rects, mouse_pos, "lingpet_stat")

static func get_cached_grid_hover_signature(
	mouse_pos: Vector2,
	grid_rect: Rect2,
	start: Vector2,
	cell_size: float,
	stride: float,
	columns: int,
	item_count: int,
	prefix: String
) -> String:
	var index: int = get_cached_grid_hover_index(mouse_pos, grid_rect, start, cell_size, stride, columns, item_count)
	if index < 0:
		return ""
	return prefix + ":" + str(index)

static func cached_grid_signature_contains_mouse(
	key_text: String,
	mouse_pos: Vector2,
	grid_rect: Rect2,
	start: Vector2,
	cell_size: float,
	stride: float,
	columns: int,
	item_count: int
) -> bool:
	if not key_text.is_valid_int():
		return false
	var index: int = get_cached_grid_hover_index(mouse_pos, grid_rect, start, cell_size, stride, columns, item_count)
	return index >= 0 and index == int(key_text)

static func get_cached_grid_hover_index(
	mouse_pos: Vector2,
	grid_rect: Rect2,
	start: Vector2,
	cell_size: float,
	stride: float,
	columns: int,
	item_count: int
) -> int:
	if not grid_rect.has_point(mouse_pos):
		return -1
	return get_hovered_grid_index(mouse_pos, start.x, start.y, cell_size, stride, columns, item_count)

static func get_cached_linear_hover_signature(
	mouse_pos: Vector2,
	start: Vector2,
	slot_size: float,
	stride: float,
	slot_count: int,
	prefix: String
) -> String:
	var index: int = get_cached_linear_hover_index(mouse_pos, start, slot_size, stride, slot_count)
	if index < 0:
		return ""
	return prefix + ":" + str(index)

static func cached_linear_signature_contains_mouse(
	key_text: String,
	mouse_pos: Vector2,
	start: Vector2,
	slot_size: float,
	stride: float,
	slot_count: int
) -> bool:
	if not key_text.is_valid_int():
		return false
	var index: int = get_cached_linear_hover_index(mouse_pos, start, slot_size, stride, slot_count)
	return index >= 0 and index == int(key_text)

static func get_cached_linear_hover_index(
	mouse_pos: Vector2,
	start: Vector2,
	slot_size: float,
	stride: float,
	slot_count: int
) -> int:
	return get_hovered_linear_slot_index(mouse_pos, start.x, start.y, slot_size, stride, slot_count)

static func find_hovered_rect_key(rects: Dictionary, mouse_pos: Vector2) -> Variant:
	for key_value in rects:
		var rect_value: Variant = rects[key_value]
		if rect_value is Rect2:
			var rect: Rect2 = rect_value
			if rect.has_point(mouse_pos):
				return key_value
	return null

static func get_hovered_linear_slot_index(
	mouse_pos: Vector2,
	start_x: float,
	start_y: float,
	slot_size: float,
	stride: float,
	slot_count: int
) -> int:
	if slot_count < 1 or slot_size <= 0.0 or stride <= 0.0:
		return -1
	if mouse_pos.y < start_y or mouse_pos.y >= start_y + slot_size:
		return -1
	var slot_index: int = int(floor((mouse_pos.x - start_x) / stride))
	if slot_index < 0 or slot_index >= slot_count:
		return -1
	var slot_x: float = start_x + float(slot_index) * stride
	if mouse_pos.x < slot_x or mouse_pos.x >= slot_x + slot_size:
		return -1
	return slot_index

static func get_hovered_grid_index(
	mouse_pos: Vector2,
	start_x: float,
	start_y: float,
	cell_size: float,
	stride: float,
	columns: int,
	item_count: int
) -> int:
	if columns < 1 or item_count < 1:
		return -1
	var col: int = int(floor((mouse_pos.x - start_x) / stride))
	var row: int = int(floor((mouse_pos.y - start_y) / stride))
	if col < 0 or col >= columns or row < 0:
		return -1
	var cell_x: float = start_x + float(col) * stride
	var cell_y: float = start_y + float(row) * stride
	if mouse_pos.x < cell_x or mouse_pos.x >= cell_x + cell_size:
		return -1
	if mouse_pos.y < cell_y or mouse_pos.y >= cell_y + cell_size:
		return -1
	var index: int = row * columns + col
	if index < 0 or index >= item_count:
		return -1
	return index
