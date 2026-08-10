extends RefCounted

const PlazaInteriorDrawPrimitives := preload("res://scripts/plaza/plaza_interior_draw_primitives.gd")
const PlazaTradeItemIconCache := preload("res://scripts/plaza/plaza_trade_item_icon_cache.gd")


static func draw_root(canvas: CanvasItem, font: Font, snapshot: Dictionary) -> void:
	if canvas == null or snapshot.is_empty():
		return
	canvas.draw_rect(snapshot.get("backdrop_rect", Rect2()), snapshot.get("backdrop_color", Color.TRANSPARENT), true)
	canvas.draw_rect(snapshot.get("modal_rect", Rect2()), snapshot.get("modal_color", Color.TRANSPARENT), true)
	canvas.draw_rect(
		snapshot.get("modal_rect", Rect2()),
		snapshot.get("modal_border_color", Color.TRANSPARENT),
		false,
		float(snapshot.get("modal_border_width", 1.0))
	)
	PlazaInteriorDrawPrimitives.draw_text_shadow(
		canvas,
		font,
		snapshot.get("title_position", Vector2.ZERO),
		str(snapshot.get("title", "")),
		int(snapshot.get("title_font_size", 1)),
		snapshot.get("title_color", Color.WHITE)
	)
	PlazaInteriorDrawPrimitives.draw_text_shadow(
		canvas,
		font,
		snapshot.get("escape_position", Vector2.ZERO),
		str(snapshot.get("escape_label", "")),
		int(snapshot.get("escape_font_size", 1)),
		snapshot.get("escape_color", Color.WHITE)
	)


static func draw_panel(
	canvas: CanvasItem,
	font: Font,
	snapshot: Dictionary,
	scale: float,
	icon_cache: PlazaTradeItemIconCache
) -> void:
	if canvas == null or snapshot.is_empty():
		return
	var panel_rect: Rect2 = snapshot.get("rect", Rect2())
	canvas.draw_rect(panel_rect, snapshot.get("background_color", Color.TRANSPARENT), true)
	canvas.draw_rect(panel_rect, snapshot.get("border_color", Color.TRANSPARENT), false, float(snapshot.get("border_width", 1.0)))
	PlazaInteriorDrawPrimitives.draw_text_shadow(
		canvas,
		font,
		snapshot.get("title_position", Vector2.ZERO),
		str(snapshot.get("title", "")),
		int(snapshot.get("title_font_size", 1)),
		snapshot.get("title_color", Color.WHITE)
	)
	var cells: Array = snapshot.get("cells", [])
	for cell_value in cells:
		var cell := _get_dict(cell_value)
		var cell_rect: Rect2 = cell.get("rect", Rect2())
		canvas.draw_rect(cell_rect, cell.get("background_color", Color.TRANSPARENT), true)
		canvas.draw_rect(cell_rect, cell.get("border_color", Color.TRANSPARENT), false, float(cell.get("border_width", 1.0)))
		if not bool(cell.get("occupied", false)):
			continue
		var item_data := _get_dict(cell.get("item", {}))
		canvas.draw_circle(cell_rect.get_center(), float(cell.get("outer_radius", 0.0)), cell.get("outer_color", Color.TRANSPARENT))
		if not _draw_item_icon(canvas, icon_cache, item_data, cell_rect, scale):
			canvas.draw_circle(cell_rect.get_center(), float(cell.get("fallback_radius", 0.0)), cell.get("fallback_color", Color.TRANSPARENT))
		if bool(cell.get("featured", false)):
			canvas.draw_rect(cell.get("badge_rect", Rect2()), cell.get("badge_color", Color.TRANSPARENT), true)
		if bool(cell.get("equipped", false)):
			var equipped_rect: Rect2 = cell.get("equipped_rect", Rect2())
			canvas.draw_rect(equipped_rect, cell.get("equipped_color", Color.TRANSPARENT), true)
			canvas.draw_rect(equipped_rect, cell.get("equipped_border_color", Color.TRANSPARENT), false, float(cell.get("equipped_border_width", 1.0)))
			PlazaInteriorDrawPrimitives.draw_text_shadow(
				canvas,
				font,
				cell.get("equipped_label_position", Vector2.ZERO),
				"E",
				int(cell.get("equipped_label_font_size", 1)),
				cell.get("equipped_label_color", Color.WHITE)
			)
		if int(cell.get("price", 0)) > 0:
			PlazaInteriorDrawPrimitives.draw_text_shadow(
				canvas,
				font,
				cell.get("price_position", Vector2.ZERO),
				str(cell.get("price_text", "")),
				int(8.0 * scale),
				Color(1.0, 0.92, 0.62, 0.88)
			)
	_draw_scrollbar(canvas, _get_dict(snapshot.get("scrollbar", {})))


static func draw_tooltip(canvas: CanvasItem, font: Font, snapshot: Dictionary, scale: float) -> void:
	if canvas == null or font == null or snapshot.is_empty():
		return
	var rect: Rect2 = snapshot.get("rect", Rect2())
	canvas.draw_rect(rect, snapshot.get("background_color", Color.TRANSPARENT), true)
	canvas.draw_rect(rect, snapshot.get("border_color", Color.TRANSPARENT), false, float(snapshot.get("border_width", 1.0)))
	PlazaInteriorDrawPrimitives.draw_text_shadow(canvas, font, rect.position + Vector2(12.0, 22.0) * scale, str(snapshot.get("name", "")), int(14.0 * scale), snapshot.get("name_color", Color.WHITE))
	PlazaInteriorDrawPrimitives.draw_text_shadow(canvas, font, rect.position + Vector2(12.0, 42.0) * scale, str(snapshot.get("price_text", "")), int(12.0 * scale), Color(1.0, 0.91, 0.56, 0.94))
	if bool(snapshot.get("featured", false)):
		PlazaInteriorDrawPrimitives.draw_text_shadow(canvas, font, rect.position + Vector2(118.0, 42.0) * scale, "오늘의 특가", int(11.0 * scale), Color(1.0, 0.50, 0.95, 0.92))
	PlazaInteriorDrawPrimitives.draw_wrapped_text(
		canvas,
		font,
		rect.position + Vector2(12.0, 64.0) * scale,
		str(snapshot.get("description", "")),
		206.0 * scale,
		int(10.0 * scale),
		Color(0.80, 0.90, 0.94, 0.88),
		14.0 * scale,
		4
	)
	var roll_text := str(snapshot.get("roll_text", ""))
	if roll_text != "":
		PlazaInteriorDrawPrimitives.draw_wrapped_text(
			canvas,
			font,
			rect.position + Vector2(12.0, 122.0) * scale,
			roll_text,
			206.0 * scale,
			int(9.0 * scale),
			Color(0.68, 1.0, 0.88, 0.82),
			12.0 * scale,
			2
		)


static func draw_drag_ghost(
	canvas: CanvasItem,
	font: Font,
	snapshot: Dictionary,
	item_data: Dictionary,
	icon_cache: PlazaTradeItemIconCache
) -> void:
	if canvas == null or snapshot.is_empty():
		return
	var position: Vector2 = snapshot.get("position", Vector2.ZERO)
	canvas.draw_circle(position, float(snapshot.get("outer_radius", 0.0)), snapshot.get("outer_color", Color.TRANSPARENT))
	var icon_texture: Texture2D = null
	if icon_cache != null:
		icon_texture = icon_cache.get_texture(item_data)
	if icon_texture != null:
		canvas.draw_texture_rect(icon_texture, snapshot.get("icon_rect", Rect2()), false)
	else:
		canvas.draw_circle(position, float(snapshot.get("fallback_radius", 0.0)), snapshot.get("fallback_color", Color.TRANSPARENT))
	PlazaInteriorDrawPrimitives.draw_text_shadow(
		canvas,
		font,
		snapshot.get("name_position", Vector2.ZERO),
		str(snapshot.get("name", "")),
		int(snapshot.get("name_font_size", 1)),
		snapshot.get("name_color", Color.WHITE)
	)


static func draw_feedbacks(canvas: CanvasItem, font: Font, snapshots: Array) -> void:
	if canvas == null or font == null:
		return
	for snapshot_value in snapshots:
		var snapshot := _get_dict(snapshot_value)
		PlazaInteriorDrawPrimitives.draw_text_shadow(
			canvas,
			font,
			snapshot.get("position", Vector2.ZERO),
			str(snapshot.get("text", "")),
			int(snapshot.get("font_size", 1)),
			snapshot.get("color", Color.WHITE)
		)


static func draw_sell_confirm(canvas: CanvasItem, font: Font, snapshot: Dictionary, scale: float) -> void:
	if canvas == null or font == null or snapshot.is_empty():
		return
	var rect: Rect2 = snapshot.get("rect", Rect2())
	canvas.draw_rect(rect, snapshot.get("background_color", Color.TRANSPARENT), true)
	canvas.draw_rect(rect, snapshot.get("border_color", Color.TRANSPARENT), false, float(snapshot.get("border_width", 1.0)))
	PlazaInteriorDrawPrimitives.draw_text_shadow(canvas, font, rect.position + Vector2(20.0, 30.0) * scale, str(snapshot.get("title", "")), int(16.0 * scale), Color(0.84, 1.0, 1.0, 0.96))
	PlazaInteriorDrawPrimitives.draw_wrapped_text(
		canvas,
		font,
		rect.position + Vector2(20.0, 56.0) * scale,
		str(snapshot.get("question", "")),
		272.0 * scale,
		int(12.0 * scale),
		Color(0.92, 0.96, 1.0, 0.90),
		17.0 * scale,
		2
	)
	var sell_button := _get_dict(snapshot.get("sell_button", {}))
	var cancel_button := _get_dict(snapshot.get("cancel_button", {}))
	PlazaInteriorDrawPrimitives.draw_button(canvas, font, sell_button.get("rect", Rect2()), str(sell_button.get("label", "")), sell_button.get("color", Color.TRANSPARENT), scale)
	PlazaInteriorDrawPrimitives.draw_button(canvas, font, cancel_button.get("rect", Rect2()), str(cancel_button.get("label", "")), cancel_button.get("color", Color.TRANSPARENT), scale)


static func _draw_scrollbar(canvas: CanvasItem, snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	canvas.draw_rect(snapshot.get("track_rect", Rect2()), snapshot.get("track_color", Color.TRANSPARENT), true)
	canvas.draw_rect(snapshot.get("handle_rect", Rect2()), snapshot.get("handle_color", Color.TRANSPARENT), true)


static func _draw_item_icon(
	canvas: CanvasItem,
	icon_cache: PlazaTradeItemIconCache,
	item_data: Dictionary,
	cell_rect: Rect2,
	scale: float
) -> bool:
	var texture: Texture2D = null
	if icon_cache != null:
		texture = icon_cache.get_texture(item_data)
	if texture == null:
		return false
	canvas.draw_texture_rect(texture, cell_rect.grow(-4.0 * scale), false, Color(1.0, 1.0, 1.0, 0.96))
	return true


static func _get_dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}
