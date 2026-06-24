extends RefCounted

const CharacterInfoOverlayFormatter := preload("res://scripts/hud/character_info_overlay_formatter.gd")
const CharacterInfoOverlayHoverGeometry := preload("res://scripts/hud/character_info_overlay_hover_geometry.gd")
const CharacterInfoOverlayOwnerState := preload("res://scripts/hud/character_info_overlay_owner_state.gd")
const CharacterInfoOverlayTextureDrawer := preload("res://scripts/hud/character_info_overlay_texture_drawer.gd")
const CharacterInfoOverlayValueUtils := preload("res://scripts/hud/character_info_overlay_value_utils.gd")
const PremiumPanelFrame := preload("res://scripts/hud/premium_panel_frame.gd")


static func ensure_slot_metadata_cache(definitions: Array, keys: Array[String], labels: Array[String], compact_labels: Array[String], bases: Array[String], accessory_numbers: Array[int], empty_colors: Array[Color], empty_border_colors: Array[Color], index_cache: Dictionary, equipment_color_head: Color, equipment_color_top: Color, equipment_color_arm: Color, equipment_color_belt: Color, equipment_color_back: Color, equipment_color_knee: Color, equipment_color_shoes: Color, equipment_color_accessory: Color) -> void:
	if keys.size() == definitions.size():
		return
	CharacterInfoOverlayValueUtils.clear_arrays([keys, labels, compact_labels, bases, accessory_numbers, empty_colors, empty_border_colors])
	index_cache.clear()
	for definition_value in definitions:
		var definition: Dictionary = CharacterInfoOverlayValueUtils.get_dict(definition_value)
		var key: String = str(definition.get("key", ""))
		var label: String = str(definition.get("label", key))
		var base: String = str(definition.get("base", key))
		var empty_color: Color = CharacterInfoOverlayFormatter.equipment_empty_color_for_base(base, equipment_color_head, equipment_color_top, equipment_color_arm, equipment_color_belt, equipment_color_back, equipment_color_knee, equipment_color_shoes, equipment_color_accessory)
		var accessory_number: int = CharacterInfoOverlayOwnerState.equipment_slot_accessory_number(key)
		index_cache[key] = keys.size()
		keys.append(key)
		labels.append(label)
		compact_labels.append(CharacterInfoOverlayFormatter.equipment_slot_label(label, key, 0.0))
		bases.append(base)
		accessory_numbers.append(accessory_number)
		empty_colors.append(empty_color)
		empty_border_colors.append(Color(empty_color.r, empty_color.g, empty_color.b, 0.58))


static func try_handle_context_click(mouse_pos: Vector2, owner: Object, registry: Object, equipment_rect: Rect2, slot_key_callable: Callable) -> bool:
	if not equipment_rect.has_point(mouse_pos):
		return false
	var runtime: Object = CharacterInfoOverlayOwnerState.get_instance(registry, "mythic_item_runtime")
	if runtime == null or not runtime.has_method("unequip_slot"):
		return false
	var slot_key: String = str(slot_key_callable.call(mouse_pos))
	return slot_key != "" and bool(runtime.unequip_slot(slot_key, owner, registry))


static func slot_key_at_index_or_mouse(mouse_pos: Vector2, slot_index: int, keys: Array[String], has_indexed_layout: bool, fallback_rects: Dictionary) -> String:
	if slot_index >= 0 and slot_index < keys.size():
		return keys[slot_index]
	if has_indexed_layout:
		return ""
	var slot_key_value: Variant = CharacterInfoOverlayHoverGeometry.find_hovered_rect_key(fallback_rects, mouse_pos)
	return "" if slot_key_value == null else str(slot_key_value)


static func refresh_visible_label_cache(keys: Array[String], labels: Array[String], compact_labels: Array[String], visible_label_cache: Array[String], use_compact: bool, cache_compact: bool) -> bool:
	var slot_count: int = keys.size()
	if visible_label_cache.size() == slot_count and cache_compact == use_compact:
		return cache_compact
	if visible_label_cache.size() != slot_count:
		visible_label_cache.resize(slot_count)
	var source_labels: Array[String] = compact_labels if use_compact else labels
	for i in range(slot_count):
		visible_label_cache[i] = source_labels[i]
	return use_compact


static func refresh_overlay_slot_frame_cache(target: Object, slot_state: Dictionary, accessory_slot_count: int, ensure_metadata_callable: Callable, ensure_frame_cache_size_callable: Callable, keys: Array[String], accessory_numbers: Array[int], empty_equipment_item: Dictionary, item_cache: Array[Dictionary], has_item_cache: Array[bool], enabled_cache: Array[bool], label_color_cache: Array[Color], base_color_cache: Array[Color], border_color_cache: Array[Color], fill_color_cache: Array[Color], border_width_cache: Array[float], locked_line_color_cache: Array[Color], empty_colors: Array[Color], empty_border_colors: Array[Color], slot_state_hash_cache: int, accessory_slot_count_cache: int, slot_count_cache: int, text_soft: Color, label_disabled: Color, color_disabled: Color, color_filled: Color, border_disabled: Color, border_filled: Color, fill_enabled: Color, fill_disabled: Color) -> void:
	ensure_metadata_callable.call()
	var slot_count: int = keys.size()
	ensure_frame_cache_size_callable.call(slot_count)
	var slot_state_hash: int = hash(slot_state)
	if slot_state_hash == slot_state_hash_cache and accessory_slot_count == accessory_slot_count_cache and slot_count == slot_count_cache:
		return
	target.set("_equipment_slot_frame_cache_slot_state_hash", slot_state_hash)
	target.set("_equipment_slot_frame_cache_accessory_slot_count", accessory_slot_count)
	target.set("_equipment_slot_frame_cache_slot_count", slot_count)
	refresh_slot_frame_arrays(slot_state, keys, accessory_numbers, empty_equipment_item, accessory_slot_count, item_cache, has_item_cache, enabled_cache, label_color_cache, base_color_cache, border_color_cache, fill_color_cache, border_width_cache, locked_line_color_cache, empty_colors, empty_border_colors, text_soft, label_disabled, color_disabled, color_filled, border_disabled, border_filled, fill_enabled, fill_disabled)


static func refresh_slot_frame_arrays(slot_state: Dictionary, keys: Array[String], accessory_numbers: Array[int], empty_equipment_item: Dictionary, accessory_slot_count: int, item_cache: Array[Dictionary], has_item_cache: Array[bool], enabled_cache: Array[bool], label_color_cache: Array[Color], base_color_cache: Array[Color], border_color_cache: Array[Color], fill_color_cache: Array[Color], border_width_cache: Array[float], locked_line_color_cache: Array[Color], empty_colors: Array[Color], empty_border_colors: Array[Color], text_soft: Color, label_disabled: Color, color_disabled: Color, color_filled: Color, border_disabled: Color, border_filled: Color, fill_enabled: Color, fill_disabled: Color) -> void:
	var slot_count: int = keys.size()
	for i in range(slot_count):
		var item_data: Dictionary = CharacterInfoOverlayOwnerState.equipment_item_or_empty(slot_state, keys[i], empty_equipment_item)
		var accessory_number: int = accessory_numbers[i]
		var enabled: bool = accessory_number <= 0 or accessory_number <= accessory_slot_count
		item_cache[i] = item_data
		has_item_cache[i] = not item_data.is_empty()
		enabled_cache[i] = enabled
		label_color_cache[i] = text_soft if enabled else label_disabled
		base_color_cache[i] = color_disabled if not enabled else color_filled if has_item_cache[i] else empty_colors[i]
		border_color_cache[i] = border_disabled if not enabled else border_filled if has_item_cache[i] else empty_border_colors[i]
		fill_color_cache[i] = fill_enabled if enabled else fill_disabled
		border_width_cache[i] = 2.0 if has_item_cache[i] else 1.4
		var base_color: Color = base_color_cache[i]
		locked_line_color_cache[i] = Color(base_color.r, base_color.g, base_color.b, 0.32)


static func draw_slots(
	canvas: CanvasItem,
	font: Font,
	hover_data: Dictionary,
	content_rect: Rect2,
	equipment_label_size: int,
	hovered_slot_index: int,
	icon_renderer: Object,
	can_draw_item_icon: bool,
	visuals: Object,
	registry: Object,
	mythic_item_runtime: Object,
	runtime_state: Object,
	keys: Array[String],
	labels: Array[String],
	bases: Array[String],
	slot_rect_cache: Array[Rect2],
	icon_rect_cache: Array[Rect2],
	fallback_rect_cache: Array[Rect2],
	placeholder_rect_cache: Array[Rect2],
	locked_line_a_start_cache: Array[Vector2],
	locked_line_a_end_cache: Array[Vector2],
	locked_line_b_start_cache: Array[Vector2],
	locked_line_b_end_cache: Array[Vector2],
	center_x_cache: Array[float],
	center_y_cache: Array[float],
	label_y_cache: Array[float],
	item_cache: Array[Dictionary],
	has_item_cache: Array[bool],
	enabled_cache: Array[bool],
	label_color_cache: Array[Color],
	base_color_cache: Array[Color],
	border_color_cache: Array[Color],
	fill_color_cache: Array[Color],
	border_width_cache: Array[float],
	locked_line_color_cache: Array[Color],
	visible_label_cache: Array[String],
	letter_cache: Dictionary,
	letter_cache_limit: int,
	fallback_symbol_ring_segments: int,
	slot_border_filled: Color,
	empty_ring_segments: int,
	placeholder_arc_segments: int,
	accessory_ring_segments: int,
	draw_text_centered_xy_callable: Callable,
	equipment_display_name_callable: Callable,
	get_item_quality_color_callable: Callable,
	build_passive_item_roll_entries_callable: Callable,
	set_hover_data_callable: Callable
) -> Dictionary:
	for i in range(keys.size()):
		var key := ""
		var slot_rect: Rect2 = slot_rect_cache[i]
		var slot_center_x: float = center_x_cache[i]
		var slot_center_y: float = center_y_cache[i]
		var enabled: bool = enabled_cache[i]
		var item_data: Dictionary = item_cache[i]
		var has_item: bool = has_item_cache[i]
		var hovered: bool = i == hovered_slot_index
		var base_color: Color = base_color_cache[i]
		var border_color: Color = border_color_cache[i]
		var border_width: float = border_width_cache[i]
		if hovered and enabled and not has_item:
			border_color = slot_border_filled
			border_width = 2.0
		if hovered:
			key = keys[i]
			draw_connector(canvas, content_rect, key, slot_center_x, slot_center_y, base_color, enabled)
		draw_slot_frame(canvas, slot_rect, fill_color_cache[i], base_color, border_color, border_width, enabled, has_item, hovered, empty_ring_segments)
		if has_item:
			if can_draw_item_icon:
				icon_renderer.draw_icon(canvas, icon_rect_cache[i], item_data, 1.0, visuals)
			else:
				if key == "":
					key = keys[i]
				CharacterInfoOverlayTextureDrawer.draw_fallback_symbol(canvas, fallback_rect_cache[i], base_color, str(item_data.get("name", key)), letter_cache, letter_cache_limit, fallback_symbol_ring_segments, draw_text_centered_xy_callable)
		elif hovered:
			var base: String = bases[i]
			draw_placeholder(canvas, placeholder_rect_cache[i], base, base_color, enabled, placeholder_arc_segments, accessory_ring_segments)
		if not enabled:
			draw_locked_slot(canvas, locked_line_a_start_cache[i], locked_line_a_end_cache[i], locked_line_b_start_cache[i], locked_line_b_end_cache[i], locked_line_color_cache[i])
		var visible_label: String = visible_label_cache[i]
		draw_text_centered_xy_callable.call(canvas, font, visible_label, slot_center_x, label_y_cache[i], equipment_label_size, label_color_cache[i])
		if hovered:
			if has_item:
				var display_name: String = equipment_display_name_callable.call(item_data)
				hover_data = set_hover_data_callable.call(hover_data, display_name, CharacterInfoOverlayFormatter.item_part_subtitle(key), CharacterInfoOverlayValueUtils.get_string_fallback(item_data, "description", "desc"), base_color, get_item_quality_color_callable.call(item_data, Color.WHITE), slot_rect, build_passive_item_roll_entries_callable.call(item_data, registry, mythic_item_runtime, runtime_state))
			else:
				var label: String = labels[i]
				hover_data = set_hover_data_callable.call(
					hover_data,
					label,
					"미장착" if enabled else "잠김",
					"패시브 장비가 연결되면 이 슬롯에 표시됩니다.",
					base_color
				)
	return hover_data


static func draw_overlay_slots(
	canvas: CanvasItem,
	font: Font,
	hover_data: Dictionary,
	target: Object,
	content_rect: Rect2,
	equipment_label_size: int,
	hovered_slot_index: int,
	icon_renderer: Object,
	can_draw_item_icon: bool,
	visuals: Object,
	registry: Object,
	mythic_item_runtime: Object,
	runtime_state: Object,
	letter_cache: Dictionary,
	letter_cache_limit: int,
	fallback_symbol_ring_segments: int,
	slot_border_filled: Color,
	empty_ring_segments: int,
	placeholder_arc_segments: int,
	accessory_ring_segments: int,
	draw_text_centered_xy_callable: Callable,
	equipment_display_name_callable: Callable,
	get_item_quality_color_callable: Callable,
	build_passive_item_roll_entries_callable: Callable,
	set_hover_data_callable: Callable
) -> Dictionary:
	return draw_slots(
		canvas,
		font,
		hover_data,
		content_rect,
		equipment_label_size,
		hovered_slot_index,
		icon_renderer,
		can_draw_item_icon,
		visuals,
		registry,
		mythic_item_runtime,
		runtime_state,
		target.get("_equipment_slot_keys"),
		target.get("_equipment_slot_labels"),
		target.get("_equipment_slot_bases"),
		target.get("_equipment_slot_rect_list_cache"),
		target.get("_equipment_slot_icon_rect_cache"),
		target.get("_equipment_slot_fallback_rect_cache"),
		target.get("_equipment_slot_placeholder_rect_cache"),
		target.get("_equipment_slot_locked_line_a_start_cache"),
		target.get("_equipment_slot_locked_line_a_end_cache"),
		target.get("_equipment_slot_locked_line_b_start_cache"),
		target.get("_equipment_slot_locked_line_b_end_cache"),
		target.get("_equipment_slot_center_x_cache"),
		target.get("_equipment_slot_center_y_cache"),
		target.get("_equipment_slot_label_y_cache"),
		target.get("_equipment_slot_item_cache"),
		target.get("_equipment_slot_has_item_cache"),
		target.get("_equipment_slot_enabled_cache"),
		target.get("_equipment_slot_label_color_cache"),
		target.get("_equipment_slot_base_color_cache"),
		target.get("_equipment_slot_border_color_cache"),
		target.get("_equipment_slot_fill_color_cache"),
		target.get("_equipment_slot_border_width_cache"),
		target.get("_equipment_slot_locked_line_color_cache"),
		target.get("_equipment_slot_visible_label_cache"),
		letter_cache,
		letter_cache_limit,
		fallback_symbol_ring_segments,
		slot_border_filled,
		empty_ring_segments,
		placeholder_arc_segments,
		accessory_ring_segments,
		draw_text_centered_xy_callable,
		equipment_display_name_callable,
		get_item_quality_color_callable,
		build_passive_item_roll_entries_callable,
		set_hover_data_callable
	)


static func draw_connector(
	canvas: CanvasItem,
	content_rect: Rect2,
	key: String,
	slot_center_x: float,
	slot_center_y: float,
	color: Color,
	enabled: bool
) -> void:
	var body_x: float = content_rect.position.x + content_rect.size.x * 0.45
	var target_x: float = body_x
	var target_y: float = content_rect.position.y + content_rect.size.y * 0.50
	var alpha: float = 0.18 if enabled else 0.07
	match key:
		"head":
			target_y = content_rect.position.y + content_rect.size.y * 0.17
		"top":
			target_y = content_rect.position.y + content_rect.size.y * 0.38
		"left_arm":
			target_x = body_x - content_rect.size.x * 0.21
			target_y = content_rect.position.y + content_rect.size.y * 0.36
		"right_arm":
			target_x = body_x + content_rect.size.x * 0.21
			target_y = content_rect.position.y + content_rect.size.y * 0.36
		"belt", "belt2":
			target_y = content_rect.position.y + content_rect.size.y * 0.58
		"knee":
			target_x = body_x - content_rect.size.x * 0.08
			target_y = content_rect.position.y + content_rect.size.y * 0.73
		"shoes":
			target_x = body_x + content_rect.size.x * 0.12
			target_y = content_rect.position.y + content_rect.size.y * 0.84
		_:
			target_x = body_x + content_rect.size.x * 0.25
			target_y = slot_center_y
	var delta_x: float = slot_center_x - target_x
	var delta_y: float = slot_center_y - target_y
	if delta_x * delta_x + delta_y * delta_y > 144.0:
		canvas.draw_line(Vector2(target_x, target_y), Vector2(slot_center_x, slot_center_y), Color(color.r, color.g, color.b, alpha), 1.0)


static func draw_slot_frame(
	canvas: CanvasItem,
	slot_rect: Rect2,
	fill_color: Color,
	color: Color,
	border_color: Color,
	border_width: float,
	enabled: bool,
	has_item: bool,
	hovered: bool,
	empty_ring_segments: int
) -> void:
	CharacterInfoOverlayTextureDrawer.draw_slot_panel(canvas, slot_rect, fill_color, border_color, border_width)
	if not hovered:
		return
	var corner_color := Color(color.r, color.g, color.b, min(1.0, border_color.a + 0.14))
	PremiumPanelFrame.draw_corner_brackets(canvas, slot_rect, corner_color)
	if not has_item and enabled:
		var empty_center := slot_rect.get_center()
		canvas.draw_circle(empty_center, slot_rect.size.x * 0.28, Color(color.r, color.g, color.b, 0.09 if enabled else 0.04))
		canvas.draw_arc(empty_center, slot_rect.size.x * 0.28, 0.0, TAU, empty_ring_segments, Color(color.r, color.g, color.b, 0.32 if enabled else 0.14), 1.0)


static func draw_locked_slot(canvas: CanvasItem, line_a_start: Vector2, line_a_end: Vector2, line_b_start: Vector2, line_b_end: Vector2, line_color: Color) -> void:
	canvas.draw_line(line_a_start, line_a_end, line_color, 1.4)
	canvas.draw_line(line_b_start, line_b_end, line_color, 1.4)


static func draw_placeholder(
	canvas: CanvasItem,
	rect: Rect2,
	base: String,
	color: Color,
	enabled: bool,
	placeholder_arc_segments: int,
	accessory_ring_segments: int
) -> void:
	var alpha: float = 0.42 if enabled else 0.20
	var center := rect.get_center()
	var stroke := Color(color.r, color.g, color.b, alpha)
	match base:
		"head":
			canvas.draw_arc(center + Vector2(0.0, 2.0), rect.size.x * 0.25, PI, TAU, placeholder_arc_segments, stroke, 1.6)
			canvas.draw_line(center + Vector2(-rect.size.x * 0.25, 2.0), center + Vector2(rect.size.x * 0.25, 2.0), stroke, 1.6)
		"top":
			var body := Rect2(center - Vector2(rect.size.x * 0.22, rect.size.y * 0.18), Vector2(rect.size.x * 0.44, rect.size.y * 0.38))
			canvas.draw_rect(body, Color(color.r, color.g, color.b, alpha * 0.28))
			canvas.draw_rect(body, stroke, false, 1.5)
			canvas.draw_line(body.position, body.position + Vector2(-rect.size.x * 0.12, rect.size.y * 0.16), stroke, 1.5)
			canvas.draw_line(Vector2(body.end.x, body.position.y), body.position + Vector2(body.size.x + rect.size.x * 0.12, rect.size.y * 0.16), stroke, 1.5)
		"arm":
			canvas.draw_line(center + Vector2(-rect.size.x * 0.20, -rect.size.y * 0.18), center + Vector2(rect.size.x * 0.18, rect.size.y * 0.18), stroke, 2.0)
			canvas.draw_circle(center + Vector2(rect.size.x * 0.21, rect.size.y * 0.20), rect.size.x * 0.08, stroke)
		"belt":
			var belt := Rect2(center - Vector2(rect.size.x * 0.28, rect.size.y * 0.06), Vector2(rect.size.x * 0.56, rect.size.y * 0.12))
			canvas.draw_rect(belt, Color(color.r, color.g, color.b, alpha * 0.32))
			canvas.draw_rect(belt, stroke, false, 1.4)
			canvas.draw_rect(Rect2(center - Vector2(rect.size.x * 0.07, rect.size.y * 0.08), Vector2(rect.size.x * 0.14, rect.size.y * 0.16)), stroke, false, 1.2)
		"back":
			var pack := Rect2(center - Vector2(rect.size.x * 0.18, rect.size.y * 0.24), Vector2(rect.size.x * 0.36, rect.size.y * 0.48))
			canvas.draw_rect(pack, Color(color.r, color.g, color.b, alpha * 0.26))
			canvas.draw_rect(pack, stroke, false, 1.5)
			canvas.draw_line(pack.position + Vector2(pack.size.x * 0.5, 0.0), pack.end - Vector2(pack.size.x * 0.5, 0.0), stroke, 1.0)
		"knee":
			canvas.draw_arc(center, rect.size.x * 0.22, -PI * 0.15, PI * 1.15, placeholder_arc_segments, stroke, 1.8)
			canvas.draw_line(center + Vector2(-rect.size.x * 0.22, rect.size.y * 0.08), center + Vector2(rect.size.x * 0.20, rect.size.y * 0.12), stroke, 1.6)
		"shoes":
			var sole := Rect2(center - Vector2(rect.size.x * 0.28, rect.size.y * 0.02), Vector2(rect.size.x * 0.56, rect.size.y * 0.14))
			canvas.draw_rect(sole, Color(color.r, color.g, color.b, alpha * 0.28))
			canvas.draw_rect(sole, stroke, false, 1.4)
			canvas.draw_line(sole.position + Vector2(rect.size.x * 0.10, 0.0), center + Vector2(-rect.size.x * 0.05, -rect.size.y * 0.18), stroke, 1.4)
		_:
			canvas.draw_circle(center, rect.size.x * 0.22, Color(color.r, color.g, color.b, alpha * 0.24))
			canvas.draw_arc(center, rect.size.x * 0.22, 0.0, TAU, accessory_ring_segments, stroke, 1.5)
