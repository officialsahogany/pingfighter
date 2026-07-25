extends RefCounted

# Pure layout/spec owner shared by PlazaInteriorView drawing, hover, click,
# scroll, and drag/drop paths.

const SHOP_TRADE_MODAL_RECT := Rect2(Vector2(70.0, 165.0), Vector2(620.0, 420.0))
const SHOP_TRADE_LEFT_PANEL := Rect2(Vector2(90.0, 215.0), Vector2(280.0, 320.0))
const SHOP_TRADE_RIGHT_PANEL := Rect2(Vector2(390.0, 215.0), Vector2(280.0, 320.0))
const SHOP_TRADE_CELL_SIZE := 42.0
const SHOP_TRADE_CELL_GAP := 6.0
const SHOP_TRADE_CELL_START_OFFSET := Vector2(14.0, 38.0)
const SHOP_TRADE_VISIBLE_CELLS := 30
const SHOP_TRADE_COLUMNS := 5


static func get_trade_panel_at_pos(game_pos: Vector2) -> String:
	if SHOP_TRADE_LEFT_PANEL.has_point(game_pos):
		return "player"
	if SHOP_TRADE_RIGHT_PANEL.has_point(game_pos):
		return "shop"
	return ""


static func get_trade_panel_rect(panel: String) -> Rect2:
	if panel == "player":
		return SHOP_TRADE_LEFT_PANEL
	if panel == "shop":
		return SHOP_TRADE_RIGHT_PANEL
	return Rect2()


static func get_trade_panel_key(panel_rect: Rect2) -> String:
	if panel_rect == SHOP_TRADE_LEFT_PANEL:
		return "player"
	if panel_rect == SHOP_TRADE_RIGHT_PANEL:
		return "shop"
	return ""


static func get_visible_trade_cell_rect(panel_rect: Rect2, visible_index: int) -> Rect2:
	var col := visible_index % SHOP_TRADE_COLUMNS
	@warning_ignore("integer_division")
	var row := int(visible_index / SHOP_TRADE_COLUMNS)
	var start := panel_rect.position + SHOP_TRADE_CELL_START_OFFSET
	return Rect2(
		start + Vector2(float(col), float(row)) * (SHOP_TRADE_CELL_SIZE + SHOP_TRADE_CELL_GAP),
		Vector2(SHOP_TRADE_CELL_SIZE, SHOP_TRADE_CELL_SIZE)
	)


static func get_trade_cell_index_at_pos(panel_rect: Rect2, item_count: int, scroll_offset: int, game_pos: Vector2) -> int:
	for visible_index in range(SHOP_TRADE_VISIBLE_CELLS):
		if get_visible_trade_cell_rect(panel_rect, visible_index).has_point(game_pos):
			var item_index := scroll_offset + visible_index
			return item_index if item_index < item_count else -1
	return -1


static func get_trade_drop_index_at_pos(panel: String, item_count: int, scroll_offset: int, game_pos: Vector2) -> int:
	var panel_rect := get_trade_panel_rect(panel)
	if panel_rect.size == Vector2.ZERO or item_count <= 0:
		return -1
	for visible_index in range(SHOP_TRADE_VISIBLE_CELLS):
		if get_visible_trade_cell_rect(panel_rect, visible_index).has_point(game_pos):
			return clampi(scroll_offset + visible_index, 0, item_count - 1)
	return -1


static func get_trade_cell_center(panel: String, index: int, item_count: int, scroll_offset: int) -> Vector2:
	var panel_rect := get_trade_panel_rect(panel)
	if panel_rect.size == Vector2.ZERO or index < 0 or index >= item_count:
		return Vector2.INF
	if index < scroll_offset or index >= scroll_offset + SHOP_TRADE_VISIBLE_CELLS:
		return Vector2.INF
	return get_visible_trade_cell_rect(panel_rect, index - scroll_offset).get_center()


static func get_trade_max_scroll_offset(item_count: int) -> int:
	if item_count <= SHOP_TRADE_VISIBLE_CELLS:
		return 0
	var overflow := item_count - SHOP_TRADE_VISIBLE_CELLS
	return int(ceil(float(overflow) / float(SHOP_TRADE_COLUMNS))) * SHOP_TRADE_COLUMNS


static func clamp_trade_scroll_offset(offset: int, item_count: int) -> int:
	return clampi(offset, 0, get_trade_max_scroll_offset(item_count))


static func hit_test_object(specs: Array[Dictionary], game_pos: Vector2, hit_slop: float = 12.0) -> String:
	for index in range(specs.size() - 1, -1, -1):
		var spec: Dictionary = specs[index]
		var rect: Rect2 = spec.get("rect", Rect2())
		if rect.grow(hit_slop).has_point(game_pos):
			return str(spec.get("id", ""))
	return ""


static func find_object_spec(specs: Array[Dictionary], object_id: String) -> Dictionary:
	for spec in specs:
		if str(spec.get("id", "")) == object_id:
			return spec
	return {}


static func build_object_specs(
	building_type: String,
	actions: Array[String],
	room_backdrop_present: bool,
	shop_strewn_specs: Array
) -> Array[Dictionary]:
	if building_type == "shop":
		return build_topview_shop_object_specs(shop_strewn_specs)
	var result: Array[Dictionary] = []
	var count := mini(actions.size(), 4)
	if count <= 0:
		return result
	var rects := get_default_object_rects(count, room_backdrop_present and building_type == "shop")
	for index in range(count):
		result.append({
			"id": "%s_action_%d" % [building_type, index],
			"action_index": index,
			"label": str(actions[index]),
			"kind": get_object_kind(building_type, index),
			"rect": rects[index],
		})
	return result


static func build_topview_shop_object_specs(shop_strewn_specs: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for spec_value in shop_strewn_specs:
		if not (spec_value is Dictionary):
			continue
		var spec: Dictionary = spec_value.duplicate(true)
		spec["action_index"] = 0
		spec["role"] = "strewn"
		result.append(spec)
	return result


static func get_default_object_rects(count: int, shop_backdrop_present: bool = false) -> Array[Rect2]:
	if count == 1:
		return [Rect2(Vector2(438.0, 392.0), Vector2(126.0, 132.0))]
	if count == 2:
		return [
			Rect2(Vector2(368.0, 400.0), Vector2(118.0, 128.0)),
			Rect2(Vector2(548.0, 400.0), Vector2(118.0, 128.0)),
		]
	if count == 3:
		if shop_backdrop_present:
			return [
				Rect2(Vector2(282.0, 348.0), Vector2(112.0, 118.0)),
				Rect2(Vector2(408.0, 344.0), Vector2(118.0, 122.0)),
				Rect2(Vector2(560.0, 350.0), Vector2(112.0, 118.0)),
			]
		return [
			Rect2(Vector2(318.0, 404.0), Vector2(116.0, 124.0)),
			Rect2(Vector2(464.0, 390.0), Vector2(126.0, 136.0)),
			Rect2(Vector2(610.0, 404.0), Vector2(112.0, 124.0)),
		]
	return [
		Rect2(Vector2(304.0, 406.0), Vector2(100.0, 118.0)),
		Rect2(Vector2(418.0, 394.0), Vector2(108.0, 128.0)),
		Rect2(Vector2(540.0, 394.0), Vector2(108.0, 128.0)),
		Rect2(Vector2(662.0, 406.0), Vector2(84.0, 118.0)),
	]


static func get_object_kind(building_type: String, index: int) -> String:
	match building_type:
		"shop":
			return ["crystal", "capsule", "sell"][mini(index, 2)]
		"bank":
			return "sell"
		"gacha", "lingpet_store":
			return "capsule"
		_:
			return "crystal"
