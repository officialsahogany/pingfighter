extends RefCounted

const CharacterInfoOverlayValueUtils := preload("res://scripts/hud/character_info_overlay_value_utils.gd")


static func touch_texture(texture: Texture2D) -> void:
	if texture != null:
		texture.get_size()


static func draw_panel(canvas: CanvasItem, rect: Rect2, fill: Color, border: Color, border_width: float) -> void:
	canvas.draw_rect(rect, fill)
	canvas.draw_rect(rect, border, false, border_width)


static func draw_scrollbar(canvas: CanvasItem, track_rect: Rect2, thumb_rect: Rect2, track_color: Color, thumb_color: Color) -> void:
	canvas.draw_rect(track_rect, track_color)
	canvas.draw_rect(thumb_rect, thumb_color)


static func draw_fallback_symbol(canvas: CanvasItem, rect: Rect2, color: Color, id_text: String, letter_cache: Dictionary, letter_cache_limit: int, ring_segments: int, draw_text_centered_xy_callable: Callable) -> void:
	var center := rect.get_center()
	var radius: float = min(rect.size.x, rect.size.y) * 0.38
	canvas.draw_circle(center, radius, Color(color.r, color.g, color.b, 0.32))
	canvas.draw_arc(center, radius, 0.0, TAU, ring_segments, color, 2.0)
	var letter: String = CharacterInfoOverlayValueUtils.fallback_symbol_letter(id_text, letter_cache, letter_cache_limit)
	draw_text_centered_xy_callable.call(canvas, ThemeDB.fallback_font, letter, center.x, center.y + 3.0, int(radius * 1.2), Color.WHITE)


static func collect_visible_item_icon_items(slot_keys: Array, slot_state: Dictionary, active_slots: Array, passive_items: Array, get_equipment_item_callable: Callable) -> Array:
	var items: Array = []
	for slot_key in slot_keys:
		var item_value: Variant = get_equipment_item_callable.call(slot_state, str(slot_key))
		var item_data: Dictionary = item_value if item_value is Dictionary else {}
		if not item_data.is_empty():
			items.append(item_data)
	for active_value in active_slots:
		if active_value is Dictionary:
			items.append(active_value)
	items.append_array(passive_items)
	return items


static func prewarm_item_icon_textures(items: Array, visuals: Object, icon_renderer: Object, get_dict_callable: Callable) -> void:
	if icon_renderer != null and icon_renderer.has_method("prewarm_item_icons"):
		icon_renderer.prewarm_item_icons(items, visuals)
		return
	if visuals == null or not visuals.has_method("get_icon_texture"):
		return
	for item_value in items:
		var item_data_value: Variant = get_dict_callable.call(item_value)
		var item_data: Dictionary = item_data_value if item_data_value is Dictionary else {}
		if item_data.is_empty():
			continue
		var texture: Variant = visuals.get_icon_texture(item_data)
		if texture is Texture2D:
			touch_texture(texture as Texture2D)


static func draw_contained(canvas: CanvasItem, texture: Texture2D, rect: Rect2, modulate: Color = Color.WHITE) -> void:
	if texture == null:
		return
	var source_size: Vector2 = texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return
	var scale: float = min(rect.size.x / source_size.x, rect.size.y / source_size.y)
	var dest_size: Vector2 = source_size * scale
	var dest := Rect2(rect.get_center() - dest_size * 0.5, dest_size)
	canvas.draw_texture_rect(texture, dest, false, modulate)


static func draw_cover(canvas: CanvasItem, texture: Texture2D, rect: Rect2, modulate: Color = Color.WHITE) -> void:
	if texture == null:
		return
	var source_size: Vector2 = texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0 or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var source := Rect2(Vector2.ZERO, source_size)
	var target_ratio: float = rect.size.x / rect.size.y
	var source_ratio: float = source_size.x / source_size.y
	if source_ratio > target_ratio:
		source.size.x = source_size.y * target_ratio
		source.position.x = (source_size.x - source.size.x) * 0.5
	else:
		source.size.y = source_size.x / target_ratio
		source.position.y = (source_size.y - source.size.y) * 0.5
	canvas.draw_texture_rect_region(texture, rect, source, modulate, false, true)
