extends RefCounted

const CharacterInfoOverlayPrewarmTextUtils := preload("res://scripts/hud/character_info_overlay_prewarm_text_utils.gd")
const CharacterInfoOverlayLayoutUtils := preload("res://scripts/hud/character_info_overlay_layout_utils.gd")
const CharacterInfoOverlayMiscValueUtils := preload("res://scripts/hud/character_info_overlay_misc_value_utils.gd")
const CharacterInfoOverlaySlotCacheUtils := preload("res://scripts/hud/character_info_overlay_slot_cache_utils.gd")
const CharacterInfoOverlayTextUtils := preload("res://scripts/hud/character_info_overlay_text_utils.gd")

static func get_string_fallback(data: Dictionary, key: String, fallback_key: String, default_value: String = "") -> String:
	var primary: Variant = data.get(key, null)
	if primary != null:
		var primary_text := str(primary)
		if primary_text != "":
			return primary_text
	var fallback: Variant = data.get(fallback_key, null)
	if fallback != null:
		var fallback_text := str(fallback)
		if fallback_text != "":
			return fallback_text
	return default_value


static func get_array_fallback(data: Dictionary, key: String, fallback_key: String) -> Array:
	if data.has(key):
		return get_array(data.get(key))
	return get_array(data.get(fallback_key, []))


static func get_tooltip_roll_entries(data: Dictionary, empty_entries: Array) -> Array:
	if data.has("roll_options"):
		return get_array(data.get("roll_options"))
	if data.has("options"):
		return get_array(data.get("options"))
	return empty_entries


static func get_number_fallback(data: Dictionary, key: String, fallback_key: String, default_value: float = 0.0) -> float:
	var primary: Variant = data.get(key, null)
	if primary != null:
		return float(primary)
	var fallback: Variant = data.get(fallback_key, null)
	if fallback != null:
		return float(fallback)
	return default_value


static func safe_owner_get(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	return fallback if value == null else value


static func get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


static func get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


static func get_color(value: Variant) -> Color:
	if value is Color:
		return value
	return Color.WHITE


static func arrays_match_size(arrays: Array, expected_size: int) -> bool:
	for values: Array in arrays:
		if values.size() != expected_size:
			return false
	return true


static func resize_arrays(arrays: Array, size: int) -> void:
	for values: Array in arrays:
		values.resize(size)


static func resize_arrays_if_needed(arrays: Array, size: int) -> void:
	if arrays_match_size(arrays, size):
		return
	resize_arrays(arrays, size)


static func consume_overlay_input_redraw(target: Object, input_redraw_requested: bool, redraw_requested: bool) -> bool:
	target.set("_input_redraw_requested", false)
	target.set("_redraw_requested", redraw_requested and not input_redraw_requested)
	return input_redraw_requested


static func request_overlay_redraw(target: Object, from_input: bool) -> void:
	target.set("_redraw_requested", true)
	if from_input:
		target.set("_input_redraw_requested", true)


static func reset_overlay_hover_tracking(target: Object) -> void:
	target.set("_last_hover_signature", "")
	target.set("_has_mouse_redraw_position", false)
	target.set("_last_mouse_redraw_position", Vector2.ZERO)


static func reset_overlay_hover_and_request_redraw(target: Object, from_input: bool) -> void:
	reset_overlay_hover_tracking(target)
	request_overlay_redraw(target, from_input)


static func clear_arrays(arrays: Array) -> void:
	for values: Array in arrays:
		values.clear()


static func append_empty_stats_row(row_cache: Array, label_cache: Array[String], value_cache: Array[String], color_cache: Array[Color], width_cache: Array[float], width_text_cache: Array[String], width_size_cache: Array[int], width_font_id_cache: Array[int]) -> void:
	row_cache.append({})
	label_cache.append("")
	value_cache.append("")
	color_cache.append(Color.WHITE)
	width_cache.append(0.0)
	width_text_cache.append("")
	width_size_cache.append(0)
	width_font_id_cache.append(0)


static func scroll_value_for_button(current_scroll: float, button_index: int, max_scroll: float, step: float = 48.0) -> float:
	return CharacterInfoOverlayMiscValueUtils.scroll_value_for_button(current_scroll, button_index, max_scroll, step)


static func update_scrollbar_rects(target: Object, track_property: String, thumb_property: String, grid_rect: Rect2, content_height: float, scroll: float, max_scroll: float) -> void:
	CharacterInfoOverlayMiscValueUtils.update_scrollbar_rects(target, track_property, thumb_property, grid_rect, content_height, scroll, max_scroll)


static func tooltip_width(font: Font, title: String, subtitle: String, body: String, view_size: Vector2, text_size_callable: Callable) -> float:
	return CharacterInfoOverlayMiscValueUtils.tooltip_width(font, title, subtitle, body, view_size, text_size_callable)


static func tooltip_anchor_rect(data: Dictionary, mouse_pos: Vector2) -> Rect2:
	return CharacterInfoOverlayMiscValueUtils.tooltip_anchor_rect(data, mouse_pos)


static func fallback_symbol_letter(id_text: String, letter_cache: Dictionary, cache_limit: int) -> String:
	return CharacterInfoOverlayMiscValueUtils.fallback_symbol_letter(id_text, letter_cache, cache_limit)


static func set_hover_data(data: Dictionary, title: String, subtitle: String, body: String, color: Color, title_color: Variant = null, anchor_rect: Variant = null, roll_options: Variant = null) -> Dictionary:
	return CharacterInfoOverlayMiscValueUtils.set_hover_data(data, title, subtitle, body, color, title_color, anchor_rect, roll_options)


static func cached_alpha_color(target: Object, color: Color, source_color: Color, cached_color: Color, source_property: String, cache_property: String, alpha: float) -> Color:
	return CharacterInfoOverlayMiscValueUtils.cached_alpha_color(target, color, source_color, cached_color, source_property, cache_property, alpha)


static func build_overlay_wrapped_text(
	target: Object,
	font: Font,
	text: String,
	size: int,
	size_key: int,
	max_width: float,
	max_lines: int,
	cache: Dictionary,
	fast_text: String,
	fast_size: int,
	fast_width: int,
	fast_max_lines: int,
	fast_lines: Array,
	text_size_callable: Callable,
	cache_limit: int
) -> Array:
	return CharacterInfoOverlayTextUtils.build_overlay_wrapped_text(
		target,
		font,
		text,
		size,
		size_key,
		max_width,
		max_lines,
		cache,
		fast_text,
		fast_size,
		fast_width,
		fast_max_lines,
		fast_lines,
		text_size_callable,
		cache_limit
	)


static func build_overlay_tooltip_entry_lines(
	target: Object,
	font: Font,
	entries: Array,
	size: int,
	max_width: float,
	max_lines: int,
	current_entries_hash: int,
	current_size: int,
	current_width: int,
	current_max_lines: int,
	line_cache: Array,
	line_dict_cache: Array,
	text_cache: Array[String],
	color_cache: Array[Color],
	wrap_text_callable: Callable,
	accent_gold: Color
) -> Array:
	return CharacterInfoOverlayTextUtils.build_overlay_tooltip_entry_lines(
		target,
		font,
		entries,
		size,
		max_width,
		max_lines,
		current_entries_hash,
		current_size,
		current_width,
		current_max_lines,
		line_cache,
		line_dict_cache,
		text_cache,
		color_cache,
		wrap_text_callable,
		accent_gold
	)


static func active_item_label_state(slot_value: Variant, active_item_catalog: Object) -> Dictionary:
	return CharacterInfoOverlaySlotCacheUtils.active_item_label_state(slot_value, active_item_catalog)


static func refresh_active_item_label_cache(
	slots: Array,
	active_item_catalog: Object,
	name_cache: Array[String],
	raw_display_name_cache: Array[String],
	display_name_cache: Array[String],
	trimmed_label_cache: Array[String],
	trim_label_callable: Callable
) -> void:
	CharacterInfoOverlaySlotCacheUtils.refresh_active_item_label_cache(
		slots,
		active_item_catalog,
		name_cache,
		raw_display_name_cache,
		display_name_cache,
		trimmed_label_cache,
		trim_label_callable
	)


static func refresh_active_slot_draw_cache(
	slots: Array,
	max_slots: int,
	visuals: Object,
	should_cache_colors: bool,
	has_item_cache: Array[bool],
	item_cache: Array[Dictionary],
	fallback_color_cache: Array[Color],
	has_fallback_color_cache: Array[bool],
	item_color_callable: Callable
) -> void:
	CharacterInfoOverlaySlotCacheUtils.refresh_active_slot_draw_cache(
		slots,
		max_slots,
		visuals,
		should_cache_colors,
		has_item_cache,
		item_cache,
		fallback_color_cache,
		has_fallback_color_cache,
		item_color_callable
	)


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
	return CharacterInfoOverlayLayoutUtils.refresh_skill_slot_layout_arrays(
		rect,
		slot_size,
		max_slots,
		rect_cache,
		icon_rect_cache,
		fallback_rect_cache,
		center_cache,
		center_x_cache
	)


static func refresh_active_slot_layout_arrays(
	rect: Rect2,
	slot_size: float,
	gap: float,
	max_slots: int,
	rect_cache: Array[Rect2],
	fallback_rect_cache: Array[Rect2],
	center_x_cache: Array[float]
) -> Dictionary:
	return CharacterInfoOverlayLayoutUtils.refresh_active_slot_layout_arrays(
		rect,
		slot_size,
		gap,
		max_slots,
		rect_cache,
		fallback_rect_cache,
		center_x_cache
	)


static func refresh_skill_slot_draw_cache(
	equipped: Array,
	skill_data: Dictionary,
	fallback_skill_color: Color,
	slot_fill_color: Color,
	id_cache: Array[String],
	data_cache: Array[Dictionary],
	label_cache: Array[String],
	color_cache: Array[Color],
	fill_color_cache: Array[Color],
	border_color_cache: Array[Color],
	short_skill_name_callable: Callable
) -> void:
	CharacterInfoOverlaySlotCacheUtils.refresh_skill_slot_draw_cache(
		equipped,
		skill_data,
		fallback_skill_color,
		slot_fill_color,
		id_cache,
		data_cache,
		label_cache,
		color_cache,
		fill_color_cache,
		border_color_cache,
		short_skill_name_callable
	)


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
	return CharacterInfoOverlayLayoutUtils.refresh_perk_grid_layout_arrays(
		grid_rect,
		cell_size,
		stride,
		columns,
		item_count,
		scroll,
		cell_rect_cache,
		icon_rect_cache,
		center_x_cache,
		level_y_cache,
		visible_index_cache
	)


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
	return CharacterInfoOverlayLayoutUtils.refresh_passive_inventory_grid_layout_arrays(
		grid_rect,
		cell_size,
		stride,
		columns,
		item_count,
		scroll,
		cell_rect_cache,
		icon_rect_cache,
		fallback_rect_cache,
		badge_rect_cache,
		badge_center_x_cache,
		badge_center_y_cache,
		visible_index_cache
	)


static func prewarm_active_item_text(
	font: Font,
	active_item_catalog: Object,
	field_spawn_order: Array,
	extra_item_names: Array,
	text_size_callable: Callable,
	trim_label_callable: Callable,
	prewarm_text_block_callable: Callable
) -> void:
	CharacterInfoOverlayPrewarmTextUtils.prewarm_active_item_text(
		font,
		active_item_catalog,
		field_spawn_order,
		extra_item_names,
		text_size_callable,
		trim_label_callable,
		prewarm_text_block_callable
	)


static func prewarm_skill_text(
	font: Font,
	character_runtime: Object,
	current_character_label: String,
	registry: Object,
	module_getter: Callable,
	get_prewarm_instance_callable: Callable,
	text_size_callable: Callable,
	trim_label_callable: Callable,
	prewarm_text_block_callable: Callable
) -> bool:
	return CharacterInfoOverlayPrewarmTextUtils.prewarm_skill_text(
		font,
		character_runtime,
		current_character_label,
		registry,
		module_getter,
		get_prewarm_instance_callable,
		text_size_callable,
		trim_label_callable,
		prewarm_text_block_callable
	)


static func prewarm_perk_text_entry(
	font: Font,
	entry: Dictionary,
	text_size_callable: Callable,
	trim_label_callable: Callable,
	prewarm_text_block_callable: Callable
) -> void:
	CharacterInfoOverlayPrewarmTextUtils.prewarm_perk_text_entry(
		font,
		entry,
		text_size_callable,
		trim_label_callable,
		prewarm_text_block_callable
	)
