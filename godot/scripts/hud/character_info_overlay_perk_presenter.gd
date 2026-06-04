extends RefCounted

const CharacterInfoOverlayFormatter := preload("res://scripts/hud/character_info_overlay_formatter.gd")
const CharacterInfoOverlayTextureDrawer := preload("res://scripts/hud/character_info_overlay_texture_drawer.gd")
const CharacterInfoOverlayValueUtils := preload("res://scripts/hud/character_info_overlay_value_utils.gd")


static func build_equipped_skill_lookup(equipped_skills: Array) -> Dictionary:
	var result: Dictionary = {}
	for skill_id_value in equipped_skills:
		var skill_id: String = str(skill_id_value)
		if skill_id != "":
			result[skill_id] = true
	return result


static func acquired_perk_cache_hash(levels: Dictionary, catalog: Object, runtime_state: Object = null, runtime_snapshot_override: Variant = null, effective_levels: Dictionary = {}, equipped_skills_for_filter: Array = []) -> int:
	var catalog_id: int = catalog.get_instance_id() if catalog != null else 0
	var equipped_skills_hash: int = hash(equipped_skills_for_filter)
	var has_snapshot_effective_levels := runtime_snapshot_override is Dictionary and (runtime_snapshot_override as Dictionary).has("effective_runtime_skill_levels")
	if runtime_state != null and not has_snapshot_effective_levels:
		return acquired_perk_runtime_cache_hash(levels, catalog_id, runtime_state, effective_levels, equipped_skills_hash)
	return hash([catalog_id, hash(levels), hash(effective_levels), equipped_skills_hash])


static func acquired_perk_runtime_cache_hash(levels: Dictionary, catalog_id: int, runtime_state: Object, effective_levels: Dictionary, equipped_skills_hash: int) -> int:
	var result: int = hash(catalog_id)
	result = hash([result, equipped_skills_hash])
	for skill_id_value in levels:
		var skill_id: String = str(skill_id_value)
		var base_level: int = int(levels.get(skill_id_value, 0))
		if base_level <= 0:
			continue
		var effective_level: int = effective_runtime_perk_level(runtime_state, skill_id, base_level, effective_levels)
		result = hash([result, skill_id, base_level, effective_level])
	return result


static func should_hide_equipped_unlock_perk(perk_data: Dictionary, equipped_skill_lookup: Dictionary) -> bool:
	if equipped_skill_lookup.is_empty():
		return false
	var unlocked_skill: String = str(perk_data.get("unlocks_skill", ""))
	return unlocked_skill != "" and bool(equipped_skill_lookup.get(unlocked_skill, false))


static func acquired_perk_data(
	skill_id: String,
	base_level: int,
	level: int,
	catalog: Object,
	equipped_skill_lookup: Dictionary,
	accent_blue: Color
) -> Dictionary:
	var data: Dictionary = {}
	if catalog != null and catalog.has_method("get_perk_data"):
		data = catalog.get_perk_data(skill_id)
	if data.is_empty():
		data = {"name": skill_id, "icon_color": accent_blue, "tree": ""}
	elif should_hide_equipped_unlock_perk(data, equipped_skill_lookup):
		return {}
	data = data.duplicate(true)
	data["id"] = skill_id
	data["base_level"] = base_level
	data["level"] = level
	if not data.has("description"):
		var descriptions: Dictionary = CharacterInfoOverlayValueUtils.get_dict(data.get("descriptions", {}))
		var description_value: Variant = descriptions.get(level, null)
		if description_value == null:
			description_value = data.get("detail", "")
		data["description"] = str(description_value)
	return data


static func build_acquired_perks(levels: Dictionary, catalog: Object, runtime_state: Object = null, runtime_snapshot_override: Variant = null, effective_levels_override: Dictionary = {}, equipped_skills_for_filter: Array = [], accent_blue: Color = Color.WHITE, accent_gold: Color = Color.WHITE) -> Array:
	var result: Array = []
	var effective_levels: Dictionary = effective_levels_override if not effective_levels_override.is_empty() else effective_runtime_perk_levels_from_snapshot(runtime_snapshot_override)
	var equipped_skill_lookup: Dictionary = build_equipped_skill_lookup(equipped_skills_for_filter)
	for skill_id_value in levels:
		var skill_id: String = str(skill_id_value)
		var base_level: int = int(levels.get(skill_id_value, 0))
		if base_level <= 0:
			continue
		var level: int = effective_runtime_perk_level(runtime_state, skill_id, base_level, effective_levels)
		var data: Dictionary = acquired_perk_data(skill_id, base_level, level, catalog, equipped_skill_lookup, accent_blue)
		if data.is_empty():
			continue
		data["_draw_id"] = skill_id
		var draw_color: Color = CharacterInfoOverlayValueUtils.get_color(data.get("icon_color", accent_blue))
		data["_draw_color"] = draw_color
		data["_draw_border_color"] = Color(draw_color.r, draw_color.g, draw_color.b, 0.48)
		data["_draw_hover_border_color"] = Color(draw_color.r, draw_color.g, draw_color.b, 0.92)
		data["_level_text"] = CharacterInfoOverlayFormatter.perk_level_text(data)
		data["_level_color"] = CharacterInfoOverlayFormatter.perk_level_color(data, accent_gold)
		result.append(data)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return sort_perks(a, b)
	)
	return result


static func build_overlay_acquired_perks_cached(
	target: Object,
	levels: Dictionary,
	catalog: Object,
	runtime_state: Object,
	runtime_snapshot_override: Variant,
	equipped_skills_for_filter: Array,
	current_cache_hash: int,
	cache_ready: bool,
	cached_perks: Array,
	draw_id_cache: Array[String],
	draw_color_cache: Array[Color],
	border_color_cache: Array[Color],
	hover_border_color_cache: Array[Color],
	level_text_cache: Array[String],
	level_color_cache: Array[Color],
	hover_title_cache: Array[String],
	hover_body_cache: Array[String],
	accent_blue: Color,
	accent_gold: Color
) -> Array:
	var effective_levels: Dictionary = effective_runtime_perk_levels_from_snapshot(runtime_snapshot_override)
	var cache_hash: int = acquired_perk_cache_hash(levels, catalog, runtime_state, runtime_snapshot_override, effective_levels, equipped_skills_for_filter)
	if cache_ready and cache_hash == current_cache_hash:
		return cached_perks
	var acquired: Array = build_acquired_perks(levels, catalog, runtime_state, runtime_snapshot_override, effective_levels, equipped_skills_for_filter, accent_blue, accent_gold)
	refresh_draw_arrays(acquired, draw_id_cache, draw_color_cache, border_color_cache, hover_border_color_cache, level_text_cache, level_color_cache, hover_title_cache, hover_body_cache, accent_blue, Callable(CharacterInfoOverlayFormatter, "perk_level_text"), Callable(CharacterInfoOverlayFormatter, "perk_level_color").bind(accent_gold))
	target.set("_acquired_perk_cache_hash", cache_hash)
	target.set("_acquired_perk_cache_ready", true)
	target.set("_acquired_perk_cache", acquired)
	return acquired


static func catalog_prewarm_entries(catalog: Object, character_type: String) -> Array:
	if catalog == null:
		return []
	if catalog.has_method("get_debug_perk_entries"):
		var debug_entries: Variant = catalog.get_debug_perk_entries(character_type)
		return debug_entries if debug_entries is Array else []
	if not catalog.has_method("get_all_perk_data"):
		return []
	var all_data_value: Variant = catalog.get_all_perk_data()
	if not (all_data_value is Dictionary):
		return []
	var all_data: Dictionary = all_data_value
	var entries: Array = []
	for skill_id_value in all_data.keys():
		var raw_entry: Variant = all_data[skill_id_value]
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry.duplicate(true)
		entry["id"] = str(skill_id_value)
		entries.append(entry)
	return entries


static func prewarm_runtime_perk_text(
	font: Font,
	catalog: Object,
	character_type: String,
	runtime_state: Object,
	text_size_callable: Callable,
	trim_label_callable: Callable,
	prewarm_text_block_callable: Callable
) -> bool:
	if catalog == null:
		return false
	var entries: Array = catalog_prewarm_entries(catalog, character_type)
	for entry_value in entries:
		CharacterInfoOverlayValueUtils.prewarm_perk_text_entry(
			font,
			CharacterInfoOverlayValueUtils.get_dict(entry_value),
			text_size_callable,
			trim_label_callable,
			prewarm_text_block_callable
		)
	if runtime_state == null or not runtime_state.has_method("get_snapshot"):
		return true
	var snapshot: Dictionary = CharacterInfoOverlayValueUtils.get_dict(runtime_state.get_snapshot())
	var levels: Dictionary = CharacterInfoOverlayValueUtils.get_dict(snapshot.get("runtime_skill_levels", {}))
	for skill_id_value in levels.keys():
		var skill_id: String = str(skill_id_value)
		var level: int = int(levels.get(skill_id_value, 1))
		text_size_callable.call(font, "Lv.%d" % level, 9)
		if catalog.has_method("get_perk_data"):
			var data: Dictionary = CharacterInfoOverlayValueUtils.get_dict(catalog.get_perk_data(skill_id))
			if not data.is_empty():
				data["id"] = skill_id
				data["level"] = level
				CharacterInfoOverlayValueUtils.prewarm_perk_text_entry(
					font,
					data,
					text_size_callable,
					trim_label_callable,
					prewarm_text_block_callable
			)
	return true


static func update_overlay_grid_layout(target: Object, grid_rect: Rect2, cell_size: float, stride: float, columns: int, item_count: int, scroll: float, current_layout_rect: Rect2, current_scroll: float, current_columns: int, current_cell_size: float, current_stride: float, current_item_count: int, cell_rect_cache: Array[Rect2], icon_rect_cache: Array[Rect2], center_x_cache: Array[float], level_y_cache: Array[float], visible_index_cache: Array[int]) -> void:
	if grid_rect == current_layout_rect and item_count == current_item_count and columns == current_columns and is_equal_approx(cell_size, current_cell_size) and is_equal_approx(stride, current_stride) and is_equal_approx(scroll, current_scroll):
		return
	target.set("_perk_grid_layout_rect", grid_rect)
	target.set("_perk_grid_layout_item_count", item_count)
	target.set("_perk_grid_layout_columns", columns)
	target.set("_perk_grid_layout_cell_size", cell_size)
	target.set("_perk_grid_layout_stride", stride)
	target.set("_perk_grid_layout_scroll", scroll)
	var layout_state: Dictionary = CharacterInfoOverlayValueUtils.refresh_perk_grid_layout_arrays(
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
	target.set("_last_perk_grid_start", layout_state.get("start", Vector2.ZERO))
	target.set("_last_perk_grid_cell_size", cell_size)
	target.set("_last_perk_grid_stride", stride)
	target.set("_last_perk_grid_columns", columns)
	target.set("_last_perk_grid_item_count", item_count)


static func refresh_draw_arrays(
	acquired: Array,
	draw_id_cache: Array[String],
	draw_color_cache: Array[Color],
	border_color_cache: Array[Color],
	hover_border_color_cache: Array[Color],
	level_text_cache: Array[String],
	level_color_cache: Array[Color],
	hover_title_cache: Array[String],
	hover_body_cache: Array[String],
	accent_blue: Color,
	perk_level_text_callable: Callable,
	perk_level_color_callable: Callable
) -> void:
	var acquired_count: int = acquired.size()
	draw_id_cache.resize(acquired_count)
	draw_color_cache.resize(acquired_count)
	border_color_cache.resize(acquired_count)
	hover_border_color_cache.resize(acquired_count)
	level_text_cache.resize(acquired_count)
	level_color_cache.resize(acquired_count)
	hover_title_cache.resize(acquired_count)
	hover_body_cache.resize(acquired_count)
	for i in range(acquired_count):
		var perk: Dictionary = CharacterInfoOverlayValueUtils.get_dict(acquired[i])
		draw_id_cache[i] = str(perk.get("_draw_id", perk.get("id", "")))
		draw_color_cache[i] = CharacterInfoOverlayValueUtils.get_color(perk.get("_draw_color", perk.get("icon_color", accent_blue)))
		var draw_color: Color = draw_color_cache[i]
		border_color_cache[i] = CharacterInfoOverlayValueUtils.get_color(perk.get("_draw_border_color", Color(draw_color.r, draw_color.g, draw_color.b, 0.48)))
		hover_border_color_cache[i] = CharacterInfoOverlayValueUtils.get_color(perk.get("_draw_hover_border_color", Color(draw_color.r, draw_color.g, draw_color.b, 0.92)))
		level_text_cache[i] = str(perk.get("_level_text", perk_level_text_callable.call(perk)))
		level_color_cache[i] = CharacterInfoOverlayValueUtils.get_color(perk.get("_level_color", perk_level_color_callable.call(perk)))
		hover_title_cache[i] = CharacterInfoOverlayValueUtils.get_string_fallback(perk, "name", "id")
		hover_body_cache[i] = CharacterInfoOverlayValueUtils.get_string_fallback(perk, "description", "detail")


static func draw_grid_cells(
	canvas: CanvasItem,
	font: Font,
	hover_data: Dictionary,
	visible_index_cache: Array[int],
	hovered_perk_index: int,
	icon_renderer: Object,
	can_draw_perk_icon: bool,
	cell_rect_cache: Array[Rect2],
	icon_rect_cache: Array[Rect2],
	center_x_cache: Array[float],
	level_y_cache: Array[float],
	draw_id_cache: Array[String],
	draw_color_cache: Array[Color],
	border_color_cache: Array[Color],
	hover_border_color_cache: Array[Color],
	level_text_cache: Array[String],
	level_color_cache: Array[Color],
	hover_title_cache: Array[String],
	hover_body_cache: Array[String],
	letter_cache: Dictionary,
	letter_cache_limit: int,
	ring_segments: int,
	grid_cell_fill: Color,
	get_level_text_size_callable: Callable,
	draw_text_centered_with_size_xy_callable: Callable,
	draw_text_centered_xy_callable: Callable,
	set_hover_data_callable: Callable
) -> Dictionary:
	for i in visible_index_cache:
		var cell_rect: Rect2 = cell_rect_cache[i]
		var color: Color = draw_color_cache[i]
		var hovered: bool = i == hovered_perk_index
		var border_color: Color = border_color_cache[i]
		if hovered:
			border_color = hover_border_color_cache[i]
		canvas.draw_rect(cell_rect, grid_cell_fill)
		canvas.draw_rect(cell_rect, border_color, false, 2.0 if hovered else 1.0)
		var perk_id: String = draw_id_cache[i]
		if not can_draw_perk_icon or not bool(icon_renderer.draw_icon(canvas, perk_id, icon_rect_cache[i], 1.0, true)):
			CharacterInfoOverlayTextureDrawer.draw_fallback_symbol(canvas, icon_rect_cache[i], color, perk_id, letter_cache, letter_cache_limit, ring_segments, draw_text_centered_xy_callable)
		var level_text: String = level_text_cache[i]
		var level_color: Color = level_color_cache[i]
		var level_text_size: Vector2 = get_level_text_size_callable.call(font, level_text, 9)
		draw_text_centered_with_size_xy_callable.call(canvas, font, level_text, center_x_cache[i], level_y_cache[i], 9, level_color, level_text_size)
		if hovered:
			hover_data = set_hover_data_callable.call(hover_data, hover_title_cache[i], level_text, hover_body_cache[i], color)
	return hover_data


static func draw_overlay_grid_cells(
	canvas: CanvasItem,
	font: Font,
	hover_data: Dictionary,
	target: Object,
	hovered_perk_index: int,
	icon_renderer: Object,
	can_draw_perk_icon: bool,
	letter_cache: Dictionary,
	letter_cache_limit: int,
	ring_segments: int,
	grid_cell_fill: Color,
	get_level_text_size_callable: Callable,
	draw_text_centered_with_size_xy_callable: Callable,
	draw_text_centered_xy_callable: Callable,
	set_hover_data_callable: Callable
) -> Dictionary:
	return draw_grid_cells(
		canvas,
		font,
		hover_data,
		target.get("_perk_grid_visible_index_cache"),
		hovered_perk_index,
		icon_renderer,
		can_draw_perk_icon,
		target.get("_perk_grid_cell_rect_cache"),
		target.get("_perk_grid_icon_rect_cache"),
		target.get("_perk_grid_center_x_cache"),
		target.get("_perk_grid_level_y_cache"),
		target.get("_acquired_perk_draw_id_cache"),
		target.get("_acquired_perk_draw_color_cache"),
		target.get("_acquired_perk_border_color_cache"),
		target.get("_acquired_perk_hover_border_color_cache"),
		target.get("_acquired_perk_level_text_cache"),
		target.get("_acquired_perk_level_color_cache"),
		target.get("_acquired_perk_hover_title_cache"),
		target.get("_acquired_perk_hover_body_cache"),
		letter_cache,
		letter_cache_limit,
		ring_segments,
		grid_cell_fill,
		get_level_text_size_callable,
		draw_text_centered_with_size_xy_callable,
		draw_text_centered_xy_callable,
		set_hover_data_callable
	)


static func effective_runtime_perk_levels_from_snapshot(runtime_snapshot_override: Variant) -> Dictionary:
	if runtime_snapshot_override is Dictionary:
		return CharacterInfoOverlayValueUtils.get_dict((runtime_snapshot_override as Dictionary).get("effective_runtime_skill_levels", {}))
	return {}


static func effective_runtime_perk_level(runtime_state: Object, skill_id: String, base_level: int, effective_levels: Dictionary = {}) -> int:
	if base_level <= 0:
		return base_level
	if effective_levels.has(skill_id):
		return max(0, int(effective_levels.get(skill_id, base_level)))
	if runtime_state != null and runtime_state.has_method("get_runtime_skill_level"):
		return max(0, int(runtime_state.get_runtime_skill_level(skill_id)))
	return base_level


static func sort_perks(a: Dictionary, b: Dictionary) -> bool:
	var a_level: int = int(a.get("level", 0))
	var b_level: int = int(b.get("level", 0))
	if a_level == b_level:
		return str(a.get("id", "")) < str(b.get("id", ""))
	return a_level > b_level
