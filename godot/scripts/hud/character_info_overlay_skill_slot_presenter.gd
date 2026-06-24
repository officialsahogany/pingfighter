extends RefCounted

const CharacterInfoOverlayTextureDrawer := preload("res://scripts/hud/character_info_overlay_texture_drawer.gd")
const CharacterInfoOverlayValueUtils := preload("res://scripts/hud/character_info_overlay_value_utils.gd")


static func update_overlay_layout(target: Object, rect: Rect2, slot_size: float, max_slots: int, current_layout_rect: Rect2, current_layout_count: int, current_layout_slot_size: float, slot_rect_cache: Array[Rect2], icon_rect_cache: Array[Rect2], fallback_rect_cache: Array[Rect2], center_cache: Array[Vector2], center_x_cache: Array[float]) -> void:
	if rect == current_layout_rect and max_slots == current_layout_count and is_equal_approx(slot_size, current_layout_slot_size):
		return
	target.set("_skill_slot_layout_rect", rect)
	target.set("_skill_slot_layout_count", max_slots)
	target.set("_skill_slot_layout_slot_size", slot_size)
	var layout_state: Dictionary = CharacterInfoOverlayValueUtils.refresh_skill_slot_layout_arrays(
		rect,
		slot_size,
		max_slots,
		slot_rect_cache,
		icon_rect_cache,
		fallback_rect_cache,
		center_cache,
		center_x_cache
	)
	target.set("_skill_slot_label_y", float(layout_state.get("label_y", 0.0)))
	target.set("_last_skill_slot_start", layout_state.get("start", Vector2.ZERO))
	target.set("_last_skill_slot_size", slot_size)
	target.set("_last_skill_slot_stride", float(layout_state.get("stride", 0.0)))
	target.set("_last_skill_slot_count", max_slots)


static func refresh_overlay_draw_cache(target: Object, equipped: Array, skill_data: Dictionary, fallback_skill_color: Color, slot_fill: Color, current_equipped_hash: int, current_skill_data_hash: int, current_fallback_color: Color, id_cache: Array[String], data_cache: Array[Dictionary], label_cache: Array[String], color_cache: Array[Color], fill_color_cache: Array[Color], border_color_cache: Array[Color], short_skill_name_callable: Callable) -> void:
	var equipped_hash: int = hash(equipped)
	var skill_data_hash: int = hash(skill_data)
	if equipped_hash == current_equipped_hash and skill_data_hash == current_skill_data_hash and fallback_skill_color == current_fallback_color and id_cache.size() == equipped.size():
		return
	target.set("_skill_slot_draw_cache_equipped_hash", equipped_hash)
	target.set("_skill_slot_draw_cache_skill_data_hash", skill_data_hash)
	target.set("_skill_slot_draw_cache_fallback_color", fallback_skill_color)
	CharacterInfoOverlayValueUtils.refresh_skill_slot_draw_cache(
		equipped,
		skill_data,
		fallback_skill_color,
		slot_fill,
		id_cache,
		data_cache,
		label_cache,
		color_cache,
		fill_color_cache,
		border_color_cache,
		short_skill_name_callable
	)


static func draw_slots(
	canvas: CanvasItem,
	font: Font,
	hover_data: Dictionary,
	max_slots: int,
	equipped_count: int,
	hovered_skill_slot: int,
	slot_size: float,
	icon_renderer: Object,
	can_draw_skill_icon: bool,
	slot_rect_cache: Array[Rect2],
	icon_rect_cache: Array[Rect2],
	fallback_rect_cache: Array[Rect2],
	center_cache: Array[Vector2],
	center_x_cache: Array[float],
	id_cache: Array[String],
	data_cache: Array[Dictionary],
	color_cache: Array[Color],
	fill_color_cache: Array[Color],
	border_color_cache: Array[Color],
	label_cache: Array[String],
	label_y: float,
	letter_cache: Dictionary,
	letter_cache_limit: int,
	ring_segments: int,
	slot_fill: Color,
	slot_border: Color,
	empty_hover_fill: Color,
	text_dim: Color,
	draw_text_centered_xy_callable: Callable,
	set_hover_data_callable: Callable
) -> Dictionary:
	for i in range(max_slots):
		var slot_rect: Rect2 = slot_rect_cache[i]
		var has_skill_slot: bool = i < equipped_count
		if not has_skill_slot:
			CharacterInfoOverlayTextureDrawer.draw_slot_panel(canvas, slot_rect, slot_fill, slot_border, 1.5)
			var hovered_empty: bool = i == hovered_skill_slot
			if hovered_empty:
				canvas.draw_circle(center_cache[i], slot_size * 0.22, empty_hover_fill)
			continue
		var skill_id: String = id_cache[i]
		var data: Dictionary = data_cache[i]
		var color: Color = color_cache[i]
		CharacterInfoOverlayTextureDrawer.draw_slot_panel(canvas, slot_rect, fill_color_cache[i], border_color_cache[i], 2.0)
		if not can_draw_skill_icon or not bool(icon_renderer.draw_icon(canvas, skill_id, icon_rect_cache[i], 1.0, true)):
			CharacterInfoOverlayTextureDrawer.draw_fallback_symbol(canvas, fallback_rect_cache[i], color, skill_id, letter_cache, letter_cache_limit, ring_segments, draw_text_centered_xy_callable)
		var label: String = label_cache[i]
		draw_text_centered_xy_callable.call(canvas, font, label, center_x_cache[i], label_y, 10, text_dim)
		if i == hovered_skill_slot:
			hover_data = set_hover_data_callable.call(
				hover_data,
				str(data.get("korean", skill_id)),
				"비용 %d  쿨타임 %.0f초" % [int(float(data.get("cost", 0.0))), float(data.get("cooldown", 0.0))],
				str(data.get("description", "")),
				color
			)
	return hover_data


static func draw_overlay_slots(
	canvas: CanvasItem,
	font: Font,
	hover_data: Dictionary,
	target: Object,
	max_slots: int,
	equipped_count: int,
	hovered_skill_slot: int,
	slot_size: float,
	icon_renderer: Object,
	can_draw_skill_icon: bool,
	label_y: float,
	letter_cache: Dictionary,
	letter_cache_limit: int,
	ring_segments: int,
	slot_fill: Color,
	slot_border: Color,
	empty_hover_fill: Color,
	text_dim: Color,
	draw_text_centered_xy_callable: Callable,
	set_hover_data_callable: Callable
) -> Dictionary:
	return draw_slots(
		canvas,
		font,
		hover_data,
		max_slots,
		equipped_count,
		hovered_skill_slot,
		slot_size,
		icon_renderer,
		can_draw_skill_icon,
		target.get("_skill_slot_rect_cache"),
		target.get("_skill_slot_icon_rect_cache"),
		target.get("_skill_slot_fallback_rect_cache"),
		target.get("_skill_slot_center_cache"),
		target.get("_skill_slot_center_x_cache"),
		target.get("_skill_slot_id_cache"),
		target.get("_skill_slot_data_cache"),
		target.get("_skill_slot_color_cache"),
		target.get("_skill_slot_fill_color_cache"),
		target.get("_skill_slot_border_color_cache"),
		target.get("_skill_slot_label_cache"),
		label_y,
		letter_cache,
		letter_cache_limit,
		ring_segments,
		slot_fill,
		slot_border,
		empty_hover_fill,
		text_dim,
		draw_text_centered_xy_callable,
		set_hover_data_callable
	)
