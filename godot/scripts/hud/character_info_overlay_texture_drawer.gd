extends RefCounted

const CharacterInfoOverlayValueUtils := preload("res://scripts/hud/character_info_overlay_value_utils.gd")
const PremiumPanelFrame := preload("res://scripts/hud/premium_panel_frame.gd")


static func touch_texture(texture: Texture2D) -> void:
	if texture != null:
		texture.get_size()


static func draw_panel(canvas: CanvasItem, rect: Rect2, fill: Color, border: Color, border_width: float, frame_kind: int = PremiumPanelFrame.KIND_SECTION) -> void:
	PremiumPanelFrame.draw_panel(canvas, rect, frame_kind, fill, border, border_width)


static func draw_main_panel(canvas: CanvasItem, rect: Rect2, fill: Color, border: Color, border_width: float) -> void:
	PremiumPanelFrame.draw_panel(canvas, rect, PremiumPanelFrame.KIND_MAIN, fill, border, border_width)


static func draw_section_chrome(canvas: CanvasItem, rect: Rect2, fill: Color, border: Color, accent: Color) -> void:
	PremiumPanelFrame.draw_panel(canvas, rect, PremiumPanelFrame.KIND_SECTION, fill, border, 2.0)
	if rect.size.y < 44.0 or rect.size.x < 72.0:
		return
	var band_height := 32.0
	canvas.draw_rect(Rect2(rect.position + Vector2(2.0, 2.0), Vector2(rect.size.x - 4.0, band_height)), Color(accent.r, accent.g, accent.b, 0.05))
	canvas.draw_line(
		Vector2(rect.position.x + 10.0, rect.position.y + band_height + 2.0),
		Vector2(rect.end.x - 10.0, rect.position.y + band_height + 2.0),
		Color(accent.r, accent.g, accent.b, 0.20),
		1.0,
		true
	)


# Machined empty-slot socket (Slice C). The texture is pushed in once from the
# overlay's scene-dressing prewarm; presenters draw empty slots through the
# helper so the PNG frame wins with a procedural slot-panel fallback.
static var _empty_slot_socket_texture: Texture2D = null


static func set_empty_slot_socket_texture(texture: Texture2D) -> void:
	if texture != null:
		_empty_slot_socket_texture = texture


static func draw_empty_slot_socket(canvas: CanvasItem, rect: Rect2, fill: Color, border: Color) -> void:
	if _empty_slot_socket_texture != null:
		draw_contained(canvas, _empty_slot_socket_texture, rect, Color(1.0, 1.0, 1.0, 0.96))
		return
	PremiumPanelFrame.draw_panel(canvas, rect, PremiumPanelFrame.KIND_SLOT, fill, border, 1.5)


# Pointy-top hexagon cell (perk grid). Shared static scratch buffers keep the
# per-frame draw loop allocation-free; vertices are recomputed in place.
static var _hex_points := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
static var _hex_outline := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])


static func draw_hex_cell(canvas: CanvasItem, rect: Rect2, fill: Color, border: Color, border_width: float) -> void:
	var center := rect.get_center()
	var radius: float = minf(rect.size.x, rect.size.y) * 0.5
	for i in range(6):
		var vertex_angle := -PI * 0.5 + float(i) * PI / 3.0
		var point := center + Vector2(cos(vertex_angle), sin(vertex_angle)) * radius
		_hex_points[i] = point
		_hex_outline[i] = point
	_hex_outline[6] = _hex_points[0]
	canvas.draw_colored_polygon(_hex_points, fill)
	canvas.draw_polyline(_hex_outline, border, border_width, true)


# Tiny procedural line glyphs for section titles and stat rows. Kept as code
# (not bitmaps): at 10-14px they stay crisp, tintable, and font-independent
# (decorative unicode would render as tofu on the Korean font stack).
static func draw_ui_glyph(canvas: CanvasItem, center: Vector2, size: float, kind: String, color: Color) -> void:
	var s := size * 0.5
	match kind:
		"sword":
			canvas.draw_line(center + Vector2(-s * 0.7, s * 0.7), center + Vector2(s * 0.62, -s * 0.62), color, 1.8, true)
			canvas.draw_line(center + Vector2(-s * 0.16, -s * 0.6), center + Vector2(s * 0.6, s * 0.16), color, 1.4, true)
			canvas.draw_line(center + Vector2(-s * 0.72, s * 0.4), center + Vector2(-s * 0.4, s * 0.72), color, 1.6, true)
		"hex":
			var points := PackedVector2Array()
			for i in range(7):
				var a := -PI * 0.5 + float(i % 6) * PI / 3.0
				points.append(center + Vector2(cos(a), sin(a)) * s * 0.9)
			canvas.draw_polyline(points, color, 1.4, true)
			canvas.draw_circle(center, s * 0.28, color)
		"star":
			canvas.draw_colored_polygon(PackedVector2Array([
				center + Vector2(0.0, -s), center + Vector2(s * 0.32, -s * 0.32),
				center + Vector2(s, 0.0), center + Vector2(s * 0.32, s * 0.32),
				center + Vector2(0.0, s), center + Vector2(-s * 0.32, s * 0.32),
				center + Vector2(-s, 0.0), center + Vector2(-s * 0.32, -s * 0.32),
			]), color)
		"flask":
			canvas.draw_rect(Rect2(center + Vector2(-s * 0.22, -s), Vector2(s * 0.44, s * 0.5)), color)
			canvas.draw_circle(center + Vector2(0.0, s * 0.28), s * 0.66, color)
		"chart":
			canvas.draw_rect(Rect2(center + Vector2(-s * 0.9, s * 0.1), Vector2(s * 0.44, s * 0.8)), color)
			canvas.draw_rect(Rect2(center + Vector2(-s * 0.22, -s * 0.3), Vector2(s * 0.44, s * 1.2)), color)
			canvas.draw_rect(Rect2(center + Vector2(s * 0.46, -s * 0.9), Vector2(s * 0.44, s * 1.8)), color)
		"chest":
			canvas.draw_rect(Rect2(center + Vector2(-s * 0.9, -s * 0.55), Vector2(s * 1.8, s * 1.3)), color, false, 1.4)
			canvas.draw_line(center + Vector2(-s * 0.9, -s * 0.1), center + Vector2(s * 0.9, -s * 0.1), color, 1.4, true)
			canvas.draw_circle(center + Vector2(0.0, s * 0.28), s * 0.2, color)
		"speed":
			canvas.draw_line(center + Vector2(-s * 0.8, -s * 0.7), center + Vector2(-s * 0.1, 0.0), color, 1.6, true)
			canvas.draw_line(center + Vector2(-s * 0.1, 0.0), center + Vector2(-s * 0.8, s * 0.7), color, 1.6, true)
			canvas.draw_line(center + Vector2(0.0, -s * 0.7), center + Vector2(s * 0.7, 0.0), color, 1.6, true)
			canvas.draw_line(center + Vector2(s * 0.7, 0.0), center + Vector2(0.0, s * 0.7), color, 1.6, true)
		"size":
			canvas.draw_line(center + Vector2(-s * 0.9, 0.0), center + Vector2(s * 0.9, 0.0), color, 1.4, true)
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-s, 0.0), center + Vector2(-s * 0.45, -s * 0.4), center + Vector2(-s * 0.45, s * 0.4)]), color)
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(s, 0.0), center + Vector2(s * 0.45, -s * 0.4), center + Vector2(s * 0.45, s * 0.4)]), color)
		"gauge_gain":
			canvas.draw_colored_polygon(PackedVector2Array([
				center + Vector2(0.0, -s), center + Vector2(s * 0.6, s * 0.2),
				center + Vector2(0.0, s * 0.75), center + Vector2(-s * 0.6, s * 0.2),
			]), color)
		"gauge_max":
			canvas.draw_arc(center + Vector2(0.0, s * 0.3), s * 0.85, PI, TAU, 12, color, 1.6, true)
			canvas.draw_line(center + Vector2(0.0, s * 0.3), center + Vector2(s * 0.5, -s * 0.35), color, 1.5, true)
		"dash_range":
			canvas.draw_line(center + Vector2(-s * 0.95, 0.0), center + Vector2(-s * 0.45, 0.0), color, 1.5, true)
			canvas.draw_line(center + Vector2(-s * 0.2, 0.0), center + Vector2(s * 0.3, 0.0), color, 1.5, true)
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(s, 0.0), center + Vector2(s * 0.4, -s * 0.45), center + Vector2(s * 0.4, s * 0.45)]), color)
		"delay":
			canvas.draw_arc(center, s * 0.85, 0.0, TAU, 14, color, 1.4, true)
			canvas.draw_line(center, center + Vector2(0.0, -s * 0.55), color, 1.4, true)
			canvas.draw_line(center, center + Vector2(s * 0.4, s * 0.15), color, 1.4, true)
		"recharge":
			canvas.draw_arc(center, s * 0.75, -PI * 0.35, PI * 1.05, 12, color, 1.6, true)
			canvas.draw_colored_polygon(PackedVector2Array([
				center + Vector2(s * 0.95, -s * 0.5), center + Vector2(s * 0.3, -s * 0.55), center + Vector2(s * 0.75, s * 0.05),
			]), color)
		"slots":
			canvas.draw_rect(Rect2(center + Vector2(-s * 0.9, -s * 0.9), Vector2(s * 0.75, s * 0.75)), color, false, 1.3)
			canvas.draw_rect(Rect2(center + Vector2(s * 0.15, -s * 0.9), Vector2(s * 0.75, s * 0.75)), color, false, 1.3)
			canvas.draw_rect(Rect2(center + Vector2(-s * 0.9, s * 0.15), Vector2(s * 0.75, s * 0.75)), color, false, 1.3)
			canvas.draw_rect(Rect2(center + Vector2(s * 0.15, s * 0.15), Vector2(s * 0.75, s * 0.75)), color, false, 1.3)


static func draw_empty_state_diamond(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	canvas.draw_colored_polygon(
		PackedVector2Array([
			center + Vector2(0.0, -radius),
			center + Vector2(radius * 0.56, 0.0),
			center + Vector2(0.0, radius),
			center + Vector2(-radius * 0.56, 0.0),
		]),
		color
	)


static func draw_slot_panel(canvas: CanvasItem, rect: Rect2, fill: Color, border: Color, border_width: float) -> void:
	PremiumPanelFrame.draw_panel(canvas, rect, PremiumPanelFrame.KIND_SLOT, fill, border, border_width)


static func draw_cell_panel(canvas: CanvasItem, rect: Rect2, fill: Color, border: Color, border_width: float) -> void:
	PremiumPanelFrame.draw_panel(canvas, rect, PremiumPanelFrame.KIND_CELL, fill, border, border_width)


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


static func draw_contained_region(canvas: CanvasItem, texture: Texture2D, rect: Rect2, source: Rect2, modulate: Color = Color.WHITE) -> void:
	if texture == null:
		return
	if source.size.x <= 0.0 or source.size.y <= 0.0:
		return
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var scale: float = min(rect.size.x / source.size.x, rect.size.y / source.size.y)
	var dest_size: Vector2 = source.size * scale
	var dest := Rect2(rect.get_center() - dest_size * 0.5, dest_size)
	canvas.draw_texture_rect_region(texture, dest, source, modulate, false, true)


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
