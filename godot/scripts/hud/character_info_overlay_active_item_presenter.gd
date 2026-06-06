extends RefCounted

const CharacterInfoOverlayFormatter := preload("res://scripts/hud/character_info_overlay_formatter.gd")
const CharacterInfoOverlayOwnerState := preload("res://scripts/hud/character_info_overlay_owner_state.gd")
const CharacterInfoOverlayTextureDrawer := preload("res://scripts/hud/character_info_overlay_texture_drawer.gd")
const CharacterInfoOverlayValueUtils := preload("res://scripts/hud/character_info_overlay_value_utils.gd")

static func update_overlay_slot_layout(target: Object, rect: Rect2, slot_size: float, gap: float, max_slots: int, current_layout_rect: Rect2, current_layout_count: int, current_slot_size: float, current_gap: float, slot_rect_cache: Array[Rect2], fallback_rect_cache: Array[Rect2], center_x_cache: Array[float]) -> void:
	if rect == current_layout_rect and max_slots == current_layout_count and is_equal_approx(slot_size, current_slot_size) and is_equal_approx(gap, current_gap):
		return
	target.set("_active_slot_layout_rect", rect)
	target.set("_active_slot_layout_count", max_slots)
	target.set("_active_slot_layout_slot_size", slot_size)
	target.set("_active_slot_layout_gap", gap)
	var layout_state: Dictionary = CharacterInfoOverlayValueUtils.refresh_active_slot_layout_arrays(
		rect,
		slot_size,
		gap,
		max_slots,
		slot_rect_cache,
		fallback_rect_cache,
		center_x_cache
	)
	target.set("_active_slot_empty_marker_y", float(layout_state.get("empty_marker_y", 0.0)))
	target.set("_active_slot_label_y", float(layout_state.get("label_y", 0.0)))
	target.set("_last_active_slot_start", layout_state.get("start", Vector2.ZERO))
	target.set("_last_active_slot_size", slot_size)
	target.set("_last_active_slot_stride", float(layout_state.get("stride", 0.0)))
	target.set("_last_active_slot_count", max_slots)


static func refresh_overlay_draw_cache(target: Object, slots: Array, max_slots: int, visuals: Object, should_cache_colors: bool, current_slots_hash: int, current_max_slots: int, current_visuals_id: int, current_should_cache_colors: bool, has_item_cache: Array[bool], item_cache: Array[Dictionary], fallback_color_cache: Array[Color], has_fallback_color_cache: Array[bool], item_color_callable: Callable) -> void:
	var slots_hash: int = hash(slots)
	var visuals_id: int = visuals.get_instance_id() if visuals != null else 0
	if slots_hash == current_slots_hash and max_slots == current_max_slots and visuals_id == current_visuals_id and should_cache_colors == current_should_cache_colors and has_item_cache.size() == max_slots:
		return
	target.set("_active_slot_draw_cache_slots_hash", slots_hash)
	target.set("_active_slot_draw_cache_max_slots", max_slots)
	target.set("_active_slot_draw_cache_visuals_id", visuals_id)
	target.set("_active_slot_draw_cache_should_cache_colors", should_cache_colors)
	CharacterInfoOverlayValueUtils.refresh_active_slot_draw_cache(
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


static func build_body(item_data: Dictionary, cooldown_msec: int) -> String:
	var lines: Array = []
	var description: String = CharacterInfoOverlayValueUtils.get_string_fallback(item_data, "description", "desc").strip_edges()
	if description != "":
		lines.append(description)
	lines.append("쿨타임 %.1f초" % (float(max(0, cooldown_msec)) / 1000.0))
	return "\n".join(lines)


static func draw_slots(
	canvas: CanvasItem,
	font: Font,
	hover_data: Dictionary,
	max_slots: int,
	hovered_active_slot: int,
	icon_renderer: Object,
	can_draw_active_item_icon: bool,
	visuals: Object,
	stat_sources: Array,
	registry: Object,
	slot_rect_cache: Array[Rect2],
	slot_has_item_cache: Array[bool],
	slot_item_cache: Array[Dictionary],
	fallback_color_cache: Array[Color],
	has_fallback_color_cache: Array[bool],
	fallback_rect_cache: Array[Rect2],
	center_x_cache: Array[float],
	empty_marker_y: float,
	label_y: float,
	display_name_cache: Array[String],
	trimmed_label_cache: Array[String],
	letter_cache: Dictionary,
	letter_cache_limit: int,
	ring_segments: int,
	slot_fill: Color,
	slot_border: Color,
	empty_text_color: Color,
	text_dim: Color,
	draw_text_centered_xy_callable: Callable,
	set_hover_data_callable: Callable
) -> Dictionary:
	for i in range(max_slots):
		var slot_rect: Rect2 = slot_rect_cache[i]
		canvas.draw_rect(slot_rect, slot_fill)
		canvas.draw_rect(slot_rect, slot_border, false, 1.5)
		var has_active_slot: bool = slot_has_item_cache[i]
		if not has_active_slot:
			var empty_slot_hovered: bool = i == hovered_active_slot
			if empty_slot_hovered:
				draw_text_centered_xy_callable.call(canvas, font, "-", center_x_cache[i], empty_marker_y, 20, empty_text_color)
			continue
		var item_data: Dictionary = slot_item_cache[i]
		var active_item_hovered: bool = i == hovered_active_slot
		var active_item_color: Color = fallback_color_cache[i]
		var has_active_item_color: bool = has_fallback_color_cache[i]
		if can_draw_active_item_icon:
			icon_renderer.draw_icon(canvas, slot_rect, item_data, 1.0, visuals)
		else:
			CharacterInfoOverlayTextureDrawer.draw_fallback_symbol(canvas, fallback_rect_cache[i], active_item_color, str(item_data.get("name", "")), letter_cache, letter_cache_limit, ring_segments, draw_text_centered_xy_callable)
		var display_name: String = display_name_cache[i]
		var trimmed_label: String = trimmed_label_cache[i]
		draw_text_centered_xy_callable.call(canvas, font, trimmed_label, center_x_cache[i], label_y, 10, text_dim)
		if active_item_hovered:
			if not has_active_item_color:
				active_item_color = CharacterInfoOverlayFormatter.item_color(item_data, visuals, Color(200.0 / 255.0, 200.0 / 255.0, 200.0 / 255.0))
			var base_cooldown_msec: int = max(0, int(CharacterInfoOverlayValueUtils.get_number_fallback(item_data, "cooldown_msec", "cooldown_ms")))
			var cooldown_msec: int = CharacterInfoOverlayOwnerState.active_item_cooldown_from_base(base_cooldown_msec, stat_sources if not stat_sources.is_empty() else CharacterInfoOverlayOwnerState.stat_sources(registry), Callable(CharacterInfoOverlayOwnerState, "apply_stat_chain"))
			var body: String = build_body(item_data, cooldown_msec)
			hover_data = set_hover_data_callable.call(
				hover_data,
				display_name,
				"슬롯 %d" % (i + 1),
				body,
				active_item_color
			)
	return hover_data


static func draw_overlay_slots(
	canvas: CanvasItem,
	font: Font,
	hover_data: Dictionary,
	target: Object,
	max_slots: int,
	hovered_active_slot: int,
	icon_renderer: Object,
	can_draw_active_item_icon: bool,
	visuals: Object,
	stat_sources: Array,
	registry: Object,
	empty_marker_y: float,
	label_y: float,
	letter_cache: Dictionary,
	letter_cache_limit: int,
	ring_segments: int,
	slot_fill: Color,
	slot_border: Color,
	empty_text_color: Color,
	text_dim: Color,
	draw_text_centered_xy_callable: Callable,
	set_hover_data_callable: Callable
) -> Dictionary:
	return draw_slots(
		canvas,
		font,
		hover_data,
		max_slots,
		hovered_active_slot,
		icon_renderer,
		can_draw_active_item_icon,
		visuals,
		stat_sources,
		registry,
		target.get("_active_slot_rect_cache"),
		target.get("_active_slot_has_item_cache"),
		target.get("_active_slot_item_cache"),
		target.get("_active_slot_fallback_color_cache"),
		target.get("_active_slot_has_fallback_color_cache"),
		target.get("_active_slot_fallback_rect_cache"),
		target.get("_active_slot_center_x_cache"),
		empty_marker_y,
		label_y,
		target.get("_active_item_display_name_cache"),
		target.get("_active_item_trimmed_label_cache"),
		letter_cache,
		letter_cache_limit,
		ring_segments,
		slot_fill,
		slot_border,
		empty_text_color,
		text_dim,
		draw_text_centered_xy_callable,
		set_hover_data_callable
	)
