extends RefCounted

const CharacterInfoOverlayFormatter := preload("res://scripts/hud/character_info_overlay_formatter.gd")
const CharacterInfoOverlayHoverGeometry := preload("res://scripts/hud/character_info_overlay_hover_geometry.gd")
const CharacterInfoOverlayOwnerState := preload("res://scripts/hud/character_info_overlay_owner_state.gd")
const CharacterInfoOverlayTextureDrawer := preload("res://scripts/hud/character_info_overlay_texture_drawer.gd")
const CharacterInfoOverlayValueUtils := preload("res://scripts/hud/character_info_overlay_value_utils.gd")
const PassiveItemQuality := preload("res://scripts/items/passive_item_quality.gd")


static func build_body(item_data: Dictionary) -> String:
	var lines: Array = []
	var description: String = CharacterInfoOverlayValueUtils.get_string_fallback(item_data, "description", "desc")
	if description != "":
		lines.append(description)
	var equipped_slot: String = str(item_data.get("_equipped_slot", ""))
	if equipped_slot != "":
		lines.append("장착: %s" % CharacterInfoOverlayFormatter.slot_display_label(equipped_slot))
	else:
		lines.append("미장착")
	return "\n".join(lines)


static func body_hash(item_data: Dictionary) -> int:
	return hash([
		item_data.get("name", ""),
		item_data.get("display_name", ""),
		item_data.get("korean", ""),
		item_data.get("description", ""),
		item_data.get("desc", ""),
		item_data.get("_equipped_slot", ""),
	])


static func build_cached_body(target: Object, item_data: Dictionary, current_hash: int, cache_ready: bool, cached_body: String) -> String:
	var cache_hash: int = body_hash(item_data)
	if cache_ready and cache_hash == current_hash:
		return cached_body
	target.set("_passive_item_body_cache_hash", cache_hash)
	target.set("_passive_item_body_cache_ready", true)
	var body: String = build_body(item_data)
	target.set("_passive_item_body_cache", body)
	return body




static func roll_option_value(option: Dictionary, rolls: Dictionary, key: String) -> float:
	var direct_value: Variant = option.get("value", null)
	if direct_value != null:
		return float(direct_value)
	var rolled_value: Variant = rolls.get(key, null)
	if rolled_value != null:
		return float(rolled_value)
	var default_value: Variant = option.get("default", null)
	if default_value != null:
		return float(default_value)
	return float(option.get("min", 0.0))


static func append_fixed_roll_entries(result: Array, fixed_options: Array, stat_buff_color: Color, roll_entry_dict_cache: Array) -> void:
	for fixed_value in fixed_options:
		var fixed_option: Dictionary = CharacterInfoOverlayValueUtils.get_dict(fixed_value)
		var fixed_label: String = str(fixed_option.get("label", ""))
		if fixed_label == "":
			continue
		var fixed_text: String = "%s%s" % [
			str(fixed_option.get("value", "")),
			str(fixed_option.get("unit", "")),
		]
		var fixed_entry := roll_entry_dict(roll_entry_dict_cache, result.size())
		fixed_entry["text"] = "%s: %s" % [fixed_label, fixed_text]
		fixed_entry["color"] = stat_buff_color
		result.append(fixed_entry)


static func append_roll_option_entry(result: Array, label: String, formatted: String, color: Color, roll_entry_dict_cache: Array) -> void:
	var option_entry := roll_entry_dict(roll_entry_dict_cache, result.size())
	option_entry["text"] = "%s: %s" % [label, formatted]
	option_entry["color"] = color
	result.append(option_entry)


static func rebuild_roll_entries(result: Array, fixed_options: Array, option_source: Array, rolls: Dictionary, item_data: Dictionary, registry: Object, mythic_item_runtime: Object, stat_buff_color: Color, accent_gold: Color, roll_entry_dict_cache: Array) -> void:
	append_fixed_roll_entries(result, fixed_options, stat_buff_color, roll_entry_dict_cache)
	for option_value in option_source:
		var option: Dictionary = CharacterInfoOverlayValueUtils.get_dict(option_value)
		var key: String = str(option.get("key", ""))
		if key == "":
			continue
		var label: String = str(option.get("label", key))
		var value: float = roll_option_value(option, rolls, key)
		var effective_value: float = float(mythic_item_runtime.get_item_roll_value(item_data, key, true, registry)) if mythic_item_runtime != null and mythic_item_runtime.has_method("get_item_roll_value") else value
		var formatted: String = CharacterInfoOverlayFormatter.format_roll_option_value(value, option)
		formatted += CharacterInfoOverlayFormatter.format_roll_effective_delta(value, effective_value, option)
		append_roll_option_entry(result, label, formatted, CharacterInfoOverlayValueUtils.get_color(option.get("color", accent_gold)), roll_entry_dict_cache)


static func build_cached_roll_entries(
	item_data: Dictionary,
	registry: Object,
	mythic_item_runtime: Object,
	runtime_state: Object,
	stat_buff_color: Color,
	accent_gold: Color,
	cache_item_hash: int,
	cache_runtime_id: int,
	cache_polish_multiplier: float,
	roll_entries_cache: Array,
	roll_entry_dict_cache: Array
) -> Dictionary:
	var rolls: Dictionary = CharacterInfoOverlayValueUtils.get_dict(item_data.get("rolls", {}))
	var option_source: Array = CharacterInfoOverlayValueUtils.get_array(item_data.get("rolled_options", []))
	if option_source.is_empty():
		option_source = CharacterInfoOverlayValueUtils.get_array(item_data.get("roll_options", []))
	var fixed_options: Array = CharacterInfoOverlayValueUtils.get_array(item_data.get("fixed_options", []))
	if fixed_options.is_empty() and option_source.is_empty():
		return _roll_entries_state([], cache_item_hash, cache_runtime_id, cache_polish_multiplier)
	mythic_item_runtime = mythic_item_runtime if mythic_item_runtime != null else CharacterInfoOverlayOwnerState.get_instance(registry, "mythic_item_runtime")
	var runtime_id: int = mythic_item_runtime.get_instance_id() if mythic_item_runtime != null else 0
	var polish_multiplier: float = CharacterInfoOverlayOwnerState.passive_item_roll_polish_multiplier(registry, runtime_state)
	var item_hash: int = hash(item_data)
	if item_hash == cache_item_hash and runtime_id == cache_runtime_id and is_equal_approx(polish_multiplier, cache_polish_multiplier):
		return _roll_entries_state(roll_entries_cache, cache_item_hash, cache_runtime_id, cache_polish_multiplier)
	roll_entries_cache.clear()
	var result: Array = roll_entries_cache
	rebuild_roll_entries(result, fixed_options, option_source, rolls, item_data, registry, mythic_item_runtime, stat_buff_color, accent_gold, roll_entry_dict_cache)
	return _roll_entries_state(result, item_hash, runtime_id, polish_multiplier)


static func build_overlay_roll_entries(
	target: Object,
	item_data: Dictionary,
	registry: Object,
	mythic_item_runtime: Object,
	runtime_state: Object,
	stat_buff_color: Color,
	accent_gold: Color,
	cache_item_hash: int,
	cache_runtime_id: int,
	cache_polish_multiplier: float,
	roll_entries_cache: Array,
	roll_entry_dict_cache: Array
) -> Array:
	var state: Dictionary = build_cached_roll_entries(item_data, registry, mythic_item_runtime, runtime_state, stat_buff_color, accent_gold, cache_item_hash, cache_runtime_id, cache_polish_multiplier, roll_entries_cache, roll_entry_dict_cache)
	target.set("_passive_item_roll_entries_cache_item_hash", int(state.get("item_hash", cache_item_hash)))
	target.set("_passive_item_roll_entries_cache_runtime_id", int(state.get("runtime_id", cache_runtime_id)))
	target.set("_passive_item_roll_entries_cache_polish_multiplier", float(state.get("polish_multiplier", cache_polish_multiplier)))
	return CharacterInfoOverlayValueUtils.get_array(state.get("entries", []))


static func roll_entry_dict(roll_entry_dict_cache: Array, index: int) -> Dictionary:
	while roll_entry_dict_cache.size() <= index:
		roll_entry_dict_cache.append({})
	var data: Dictionary = roll_entry_dict_cache[index]
	data.clear()
	return data


static func _roll_entries_state(entries: Array, item_hash: int, runtime_id: int, polish_multiplier: float) -> Dictionary:
	return {
		"entries": entries,
		"item_hash": item_hash,
		"runtime_id": runtime_id,
		"polish_multiplier": polish_multiplier,
	}


static func has_direct_frame_color(item_data: Dictionary) -> bool:
	return item_data.get("color", null) is Color


static func direct_frame_color(item_data: Dictionary) -> Color:
	var raw: Variant = item_data.get("color", Color.WHITE)
	return raw if raw is Color else Color.WHITE


static func frame_color(item_data: Dictionary) -> Color:
	var rarity: String = CharacterInfoOverlayValueUtils.get_string_fallback(item_data, "rarity", "type").to_lower()
	match rarity:
		"mythic":
			return Color(1.0, 215.0 / 255.0, 75.0 / 255.0)
		"legendary":
			return Color(1.0, 130.0 / 255.0, 92.0 / 255.0)
		"passive":
			return Color(105.0 / 255.0, 245.0 / 255.0, 170.0 / 255.0)
		_:
			return Color(185.0 / 255.0, 205.0 / 255.0, 235.0 / 255.0)


static func frame_color_hash(item_data: Dictionary) -> int:
	return hash([
		item_data.get("name", ""),
		item_data.get("rarity", ""),
		item_data.get("type", ""),
	])


static func cached_frame_color(item_data: Dictionary, color_cache: Dictionary, cache_limit: int) -> Color:
	if has_direct_frame_color(item_data):
		return direct_frame_color(item_data)
	var cache_hash: int = frame_color_hash(item_data)
	var cached_color: Variant = color_cache.get(cache_hash, null)
	if cached_color is Color:
		return cached_color
	var result: Color = frame_color(item_data)
	if color_cache.size() >= cache_limit:
		color_cache.clear()
	color_cache[cache_hash] = result
	return result


static func equipment_display_name(item_data: Dictionary) -> String:
	var qualified_name: String = str(item_data.get("qualified_display_name", ""))
	if qualified_name != "":
		return qualified_name
	var display_name: String = str(item_data.get("display_name", ""))
	if display_name == "":
		display_name = str(item_data.get("korean", ""))
	if display_name != "":
		return PassiveItemQuality.format_item_display_name(item_data)
	var item_name: String = str(item_data.get("name", ""))
	if item_name != "":
		return PassiveItemQuality.format_item_display_name(item_data)
	return "장비"


static func item_quality_color(item_data: Dictionary, fallback: Color = Color.WHITE) -> Color:
	return PassiveItemQuality.get_item_quality_color(item_data, fallback)


static func cached_equipment_display_name(target: Object, item_data: Dictionary, current_hash: int, cache_ready: bool, cached_name: String) -> String:
	var cache_hash: int = CharacterInfoOverlayFormatter.equipment_item_display_name_hash(item_data)
	if cache_ready and cache_hash == current_hash:
		return cached_name
	target.set("_equipment_item_display_name_cache_hash", cache_hash)
	target.set("_equipment_item_display_name_cache_ready", true)
	var display_name: String = equipment_display_name(item_data)
	target.set("_equipment_item_display_name_cache", display_name)
	return display_name


static func cached_item_quality_color(target: Object, item_data: Dictionary, fallback: Color, current_hash: int, cache_ready: bool, cached_color: Color) -> Color:
	var cache_hash: int = CharacterInfoOverlayFormatter.item_quality_color_hash(item_data, fallback)
	if cache_ready and cache_hash == current_hash:
		return cached_color
	target.set("_item_quality_color_cache_hash", cache_hash)
	target.set("_item_quality_color_cache_ready", true)
	var quality_color: Color = item_quality_color(item_data, fallback)
	target.set("_item_quality_color_cache", quality_color)
	return quality_color


static func passive_inventory_icon_hash(inventory_items: Array) -> int:
	var result: int = inventory_items.size()
	for item_value in inventory_items:
		if not (item_value is Dictionary):
			continue
		var item_data: Dictionary = item_value
		if item_data.is_empty():
			continue
		result = hash([
			result,
			item_data.get("name", ""),
			item_data.get("icon_path", ""),
			item_data.get("icon_sheet_path", ""),
		])
	return result


static func passive_inventory_items(owner: Object, registry: Object, mythic_item_runtime: Object = null) -> Array:
	var runtime: Object = mythic_item_runtime if mythic_item_runtime != null else CharacterInfoOverlayOwnerState.get_instance(registry, "mythic_item_runtime")
	if runtime != null:
		var live_items_value: Variant = runtime.get("inventory_items")
		if live_items_value is Array:
			return live_items_value
		if runtime.has_method("get_snapshot"):
			var items: Array = CharacterInfoOverlayValueUtils.get_array(CharacterInfoOverlayValueUtils.get_dict(runtime.get_snapshot()).get("inventory_items", []))
			if not items.is_empty():
				return items
	var direct: Array = CharacterInfoOverlayValueUtils.get_array(CharacterInfoOverlayValueUtils.safe_owner_get(owner, "passive_item_inventory", []))
	if not direct.is_empty():
		return direct
	var state: Dictionary = CharacterInfoOverlayValueUtils.get_dict(CharacterInfoOverlayValueUtils.safe_owner_get(owner, "mythic_item_state", {}))
	var state_items: Array = CharacterInfoOverlayValueUtils.get_array(state.get("inventory_items", []))
	if not state_items.is_empty():
		return state_items
	var equipped: Dictionary = CharacterInfoOverlayValueUtils.get_dict(state.get("equipped_items", {}))
	var result: Array = []
	for item_name in equipped:
		var item_data: Dictionary = CharacterInfoOverlayValueUtils.get_dict(equipped[item_name])
		if not item_data.is_empty():
			result.append(item_data)
	return result


static func prewarm_overlay_visible_item_icons(owner: Object, registry: Object, module_getter: Callable, equipment_slot_keys: Array[String], empty_equipment_item: Dictionary, icon_renderer: Object) -> void:
	var items: Array = CharacterInfoOverlayTextureDrawer.collect_visible_item_icon_items(equipment_slot_keys, CharacterInfoOverlayOwnerState.equipment_state_from_owner(owner), CharacterInfoOverlayValueUtils.get_array(CharacterInfoOverlayValueUtils.safe_owner_get(owner, "active_item_slots", [])), passive_inventory_items(owner, registry, CharacterInfoOverlayOwnerState.prewarm_instance(registry, module_getter, "mythic_item_runtime")), Callable(CharacterInfoOverlayOwnerState, "equipment_item_or_empty").bind(empty_equipment_item))
	if items.is_empty():
		return
	CharacterInfoOverlayTextureDrawer.prewarm_item_icon_textures(items, CharacterInfoOverlayOwnerState.prewarm_instance(registry, module_getter, "active_item_hud_visuals"), icon_renderer, Callable(CharacterInfoOverlayValueUtils, "get_dict"))


static func prewarm_overlay_inventory_assets(target: Object, owner: Object, registry: Object, module_getter: Callable, current_items_hash: int, current_item_count: int, icon_renderer: Object) -> void:
	var inventory_items: Array = passive_inventory_items(owner, registry)
	var runtime: Object = CharacterInfoOverlayOwnerState.prewarm_instance(registry, module_getter, "mythic_item_runtime") if inventory_items.is_empty() else null
	if runtime != null:
		inventory_items = CharacterInfoOverlayValueUtils.get_array(runtime.get("inventory_items"))
		if inventory_items.is_empty() and runtime.has_method("get_snapshot"):
			inventory_items = CharacterInfoOverlayValueUtils.get_array(CharacterInfoOverlayValueUtils.get_dict(runtime.get_snapshot()).get("inventory_items", []))
	var items_hash: int = passive_inventory_icon_hash(inventory_items)
	if items_hash == current_items_hash and inventory_items.size() == current_item_count:
		return
	target.set("_passive_inventory_icon_prewarm_items_hash", items_hash)
	target.set("_passive_inventory_icon_prewarm_item_count", inventory_items.size())
	if inventory_items.is_empty():
		return
	CharacterInfoOverlayTextureDrawer.prewarm_item_icon_textures(inventory_items, CharacterInfoOverlayOwnerState.prewarm_instance(registry, module_getter, "active_item_hud_visuals"), icon_renderer, Callable(CharacterInfoOverlayValueUtils, "get_dict"))


static func try_handle_inventory_context_click(mouse_pos: Vector2, owner: Object, registry: Object, grid_rect: Rect2, grid_start: Vector2, cell_size: float, stride: float, columns: int, item_count: int) -> bool:
	var runtime: Object = CharacterInfoOverlayOwnerState.get_instance(registry, "mythic_item_runtime")
	if runtime == null or not runtime.has_method("toggle_inventory_item"):
		return false
	var index: int = CharacterInfoOverlayHoverGeometry.get_cached_grid_hover_index(mouse_pos, grid_rect, grid_start, cell_size, stride, columns, item_count)
	return index >= 0 and bool(runtime.toggle_inventory_item(index, owner, registry))


static func update_overlay_grid_layout(target: Object, grid_rect: Rect2, cell_size: float, stride: float, columns: int, item_count: int, scroll: float, current_layout_rect: Rect2, current_scroll: float, current_columns: int, current_cell_size: float, current_stride: float, current_item_count: int, cell_rect_cache: Array[Rect2], icon_rect_cache: Array[Rect2], fallback_rect_cache: Array[Rect2], badge_rect_cache: Array[Rect2], badge_center_x_cache: Array[float], badge_center_y_cache: Array[float], visible_index_cache: Array[int]) -> void:
	if grid_rect == current_layout_rect and item_count == current_item_count and columns == current_columns and is_equal_approx(cell_size, current_cell_size) and is_equal_approx(stride, current_stride) and is_equal_approx(scroll, current_scroll):
		return
	target.set("_passive_grid_layout_rect", grid_rect)
	target.set("_passive_grid_layout_item_count", item_count)
	target.set("_passive_grid_layout_columns", columns)
	target.set("_passive_grid_layout_cell_size", cell_size)
	target.set("_passive_grid_layout_stride", stride)
	target.set("_passive_grid_layout_scroll", scroll)
	var layout_state: Dictionary = CharacterInfoOverlayValueUtils.refresh_passive_inventory_grid_layout_arrays(
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
	target.set("_last_passive_grid_start", layout_state.get("start", Vector2.ZERO))
	target.set("_last_passive_grid_cell_size", cell_size)
	target.set("_last_passive_grid_stride", stride)
	target.set("_last_passive_grid_columns", columns)
	target.set("_last_passive_grid_item_count", item_count)


static func prepare_inventory_draw_arrays(
	inventory_items: Array,
	_passive_inventory_item_cache: Array[Dictionary],
	_passive_inventory_draw_color_cache: Array[Color],
	_passive_inventory_border_color_cache: Array[Color],
	_passive_inventory_active_border_color_cache: Array[Color],
	_passive_inventory_equipped_cache: Array[bool],
	frame_color_callable: Callable
) -> int:
	var equipped_count := 0
	for i in range(inventory_items.size()):
		var item_value: Variant = inventory_items[i]
		var item_data: Dictionary = CharacterInfoOverlayValueUtils.get_dict(item_value)
		if item_data.is_empty():
			_passive_inventory_item_cache[i] = {}
			_passive_inventory_draw_color_cache[i] = Color.WHITE
			_passive_inventory_border_color_cache[i] = Color.TRANSPARENT
			_passive_inventory_active_border_color_cache[i] = Color.TRANSPARENT
			_passive_inventory_equipped_cache[i] = false
			continue
		_passive_inventory_item_cache[i] = item_data
		var cached_color: Variant = item_data.get("_draw_color", null)
		var color_value: Variant = cached_color if cached_color is Color else frame_color_callable.call(item_data)
		var color: Color = color_value if color_value is Color else Color.WHITE
		var equipped: bool = bool(item_data.get("equipped", false)) or str(item_data.get("_equipped_slot", "")) != ""
		var cached_equipped: Variant = item_data.get("_draw_equipped", null)
		if typeof(cached_equipped) != TYPE_BOOL or bool(cached_equipped) != equipped:
			item_data["_draw_equipped"] = equipped
		if equipped:
			equipped_count += 1
		if not (cached_color is Color):
			item_data["_draw_color"] = color
		if not (item_data.get("_draw_border_color", null) is Color):
			item_data["_draw_border_color"] = Color(color.r, color.g, color.b, 0.48)
		if not (item_data.get("_draw_active_border_color", null) is Color):
			item_data["_draw_active_border_color"] = Color(color.r, color.g, color.b, 0.90)
		_passive_inventory_draw_color_cache[i] = color
		_passive_inventory_border_color_cache[i] = item_data["_draw_border_color"] as Color
		_passive_inventory_active_border_color_cache[i] = item_data["_draw_active_border_color"] as Color
		_passive_inventory_equipped_cache[i] = equipped
	return equipped_count


static func prepare_overlay_inventory_draw_cache(
	target: Object,
	inventory_items: Array,
	current_items_hash: int,
	current_item_count: int,
	item_cache: Array[Dictionary],
	draw_color_cache: Array[Color],
	border_color_cache: Array[Color],
	active_border_color_cache: Array[Color],
	equipped_cache: Array[bool],
	summary: Dictionary,
	current_summary_count: int,
	current_summary_equipped: int,
	frame_color_callable: Callable
) -> Dictionary:
	var item_count: int = inventory_items.size()
	var items_hash: int = hash(inventory_items)
	if items_hash == current_items_hash and item_count == current_item_count and item_cache.size() == item_count:
		return summary
	if not CharacterInfoOverlayValueUtils.arrays_match_size([draw_color_cache, border_color_cache, active_border_color_cache, equipped_cache, item_cache], item_count):
		CharacterInfoOverlayValueUtils.resize_arrays([item_cache, draw_color_cache, border_color_cache, active_border_color_cache, equipped_cache], item_count)
	var equipped_count: int = prepare_inventory_draw_arrays(inventory_items, item_cache, draw_color_cache, border_color_cache, active_border_color_cache, equipped_cache, frame_color_callable)
	target.set("_passive_inventory_draw_cache_items_hash", hash(inventory_items))
	target.set("_passive_inventory_draw_cache_item_count", item_count)
	return set_inventory_summary(target, item_count, equipped_count, summary, current_summary_count, current_summary_equipped)


static func set_inventory_summary(target: Object, item_count: int, equipped_count: int, summary: Dictionary, current_summary_count: int, current_summary_equipped: int) -> Dictionary:
	if item_count == current_summary_count and equipped_count == current_summary_equipped:
		return summary
	target.set("_passive_inventory_summary_count", item_count)
	target.set("_passive_inventory_summary_equipped", equipped_count)
	summary["count"] = item_count
	summary["equipped"] = equipped_count
	summary["count_text"] = "보유 " + str(item_count) + " / 장착 " + str(equipped_count)
	return summary
