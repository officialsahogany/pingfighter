extends RefCounted

const CharacterInfoOverlayFormatter := preload("res://scripts/hud/character_info_overlay_formatter.gd")
const CharacterInfoOverlayTextureDrawer := preload("res://scripts/hud/character_info_overlay_texture_drawer.gd")
static func item_slot_key(item_data: Dictionary) -> String:
	var equipped_slot: String = str(item_data.get("_equipped_slot", ""))
	if equipped_slot != "":
		return equipped_slot
	var slot_key: String = str(item_data.get("slot", ""))
	if slot_key != "":
		return slot_key
	return str(item_data.get("body_part", ""))

static func draw_equipped_badge(canvas: CanvasItem, badge_rect: Rect2, badge_center_x: float, badge_center_y: float, font: Font, badge_fill: Color, draw_text_centered_xy_callable: Callable) -> void:
	canvas.draw_rect(badge_rect, badge_fill)
	canvas.draw_rect(badge_rect, Color.WHITE, false, 1.0)
	draw_text_centered_xy_callable.call(canvas, font, "E", badge_center_x, badge_center_y, 8, Color.WHITE)

static func draw_inventory_cells(
	canvas: CanvasItem,
	font: Font,
	hover_data: Dictionary,
	visible_index_cache: Array[int],
	hovered_passive_index: int,
	icon_renderer: Object,
	can_draw_passive_item_icon: bool,
	visuals: Object,
	registry: Object,
	mythic_item_runtime: Object,
	runtime_state: Object,
	cell_rect_cache: Array[Rect2],
	icon_rect_cache: Array[Rect2],
	fallback_rect_cache: Array[Rect2],
	badge_rect_cache: Array[Rect2],
	badge_center_x_cache: Array[float],
	badge_center_y_cache: Array[float],
	item_cache: Array[Dictionary],
	draw_color_cache: Array[Color],
	border_color_cache: Array[Color],
	active_border_color_cache: Array[Color],
	equipped_cache: Array[bool],
	letter_cache: Dictionary,
	letter_cache_limit: int,
	ring_segments: int,
	grid_cell_fill: Color,
	equipped_badge_fill: Color,
	draw_text_centered_xy_callable: Callable,
	equipment_display_name_callable: Callable,
	build_passive_item_body_callable: Callable,
	get_item_quality_color_callable: Callable,
	build_passive_item_roll_entries_callable: Callable,
	set_hover_data_callable: Callable
) -> Dictionary:
	for i in visible_index_cache:
		var cell_rect: Rect2 = cell_rect_cache[i]
		var item_data: Dictionary = item_cache[i]
		if item_data.is_empty():
			continue
		var color: Color = draw_color_cache[i]
		var hovered: bool = i == hovered_passive_index
		var equipped: bool = equipped_cache[i]
		var border_color: Color = border_color_cache[i]
		if hovered or equipped:
			border_color = active_border_color_cache[i]
		canvas.draw_rect(cell_rect, grid_cell_fill)
		canvas.draw_rect(cell_rect, border_color, false, 2.0 if hovered or equipped else 1.0)
		if can_draw_passive_item_icon:
			icon_renderer.draw_icon(canvas, icon_rect_cache[i], item_data, 1.0, visuals)
		else:
			CharacterInfoOverlayTextureDrawer.draw_fallback_symbol(canvas, fallback_rect_cache[i], color, str(item_data.get("name", "")), letter_cache, letter_cache_limit, ring_segments, draw_text_centered_xy_callable)
		if equipped:
			draw_equipped_badge(canvas, badge_rect_cache[i], badge_center_x_cache[i], badge_center_y_cache[i], font, equipped_badge_fill, draw_text_centered_xy_callable)
		if hovered:
			var slot_key: String = item_slot_key(item_data)
			hover_data = set_hover_data_callable.call(hover_data, equipment_display_name_callable.call(item_data), CharacterInfoOverlayFormatter.item_part_subtitle(slot_key), build_passive_item_body_callable.call(item_data), color, get_item_quality_color_callable.call(item_data, Color.WHITE), cell_rect, build_passive_item_roll_entries_callable.call(item_data, registry, mythic_item_runtime, runtime_state))
	return hover_data

static func draw_overlay_inventory_cells(
	canvas: CanvasItem,
	font: Font,
	hover_data: Dictionary,
	target: Object,
	hovered_passive_index: int,
	icon_renderer: Object,
	can_draw_passive_item_icon: bool,
	visuals: Object,
	registry: Object,
	mythic_item_runtime: Object,
	runtime_state: Object,
	letter_cache: Dictionary,
	letter_cache_limit: int,
	ring_segments: int,
	grid_cell_fill: Color,
	equipped_badge_fill: Color,
	draw_text_centered_xy_callable: Callable,
	equipment_display_name_callable: Callable,
	build_passive_item_body_callable: Callable,
	get_item_quality_color_callable: Callable,
	build_passive_item_roll_entries_callable: Callable,
	set_hover_data_callable: Callable
) -> Dictionary:
	return draw_inventory_cells(
		canvas,
		font,
		hover_data,
		target.get("_passive_grid_visible_index_cache"),
		hovered_passive_index,
		icon_renderer,
		can_draw_passive_item_icon,
		visuals,
		registry,
		mythic_item_runtime,
		runtime_state,
		target.get("_passive_grid_cell_rect_cache"),
		target.get("_passive_grid_icon_rect_cache"),
		target.get("_passive_grid_fallback_rect_cache"),
		target.get("_passive_grid_badge_rect_cache"),
		target.get("_passive_grid_badge_center_x_cache"),
		target.get("_passive_grid_badge_center_y_cache"),
		target.get("_passive_inventory_item_cache"),
		target.get("_passive_inventory_draw_color_cache"),
		target.get("_passive_inventory_border_color_cache"),
		target.get("_passive_inventory_active_border_color_cache"),
		target.get("_passive_inventory_equipped_cache"),
		letter_cache,
		letter_cache_limit,
		ring_segments,
		grid_cell_fill,
		equipped_badge_fill,
		draw_text_centered_xy_callable,
		equipment_display_name_callable,
		build_passive_item_body_callable,
		get_item_quality_color_callable,
		build_passive_item_roll_entries_callable,
		set_hover_data_callable
	)
