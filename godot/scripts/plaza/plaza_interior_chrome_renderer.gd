extends RefCounted

const PlazaInteriorDrawPrimitives := preload("res://scripts/plaza/plaza_interior_draw_primitives.gd")


static func draw_title(canvas: CanvasItem, font: Font, snapshot: Dictionary) -> void:
	if canvas == null or font == null or snapshot.is_empty():
		return
	_draw_panel_rect(canvas, snapshot, "title_rect", "title_fill_color", "title_border_color", "title_border_width")
	PlazaInteriorDrawPrimitives.draw_text_shadow(canvas, font, snapshot.get("title_position", Vector2.ZERO), str(snapshot.get("title", "")), int(snapshot.get("title_font_size", 1)), snapshot.get("title_color", Color.WHITE))
	if str(snapshot.get("subtitle", "")) != "":
		PlazaInteriorDrawPrimitives.draw_text_shadow(canvas, font, snapshot.get("subtitle_position", Vector2.ZERO), str(snapshot.get("subtitle", "")), int(snapshot.get("subtitle_font_size", 1)), snapshot.get("subtitle_color", Color.WHITE))
	_draw_panel_rect(canvas, snapshot, "gold_rect", "gold_fill_color", "gold_border_color", "gold_border_width")
	PlazaInteriorDrawPrimitives.draw_text_shadow(canvas, font, snapshot.get("gold_position", Vector2.ZERO), str(snapshot.get("gold_text", "")), int(snapshot.get("gold_font_size", 1)), snapshot.get("gold_color", Color.WHITE))
	_draw_panel_rect(canvas, snapshot, "exit_rect", "exit_fill_color", "exit_border_color", "exit_border_width")
	PlazaInteriorDrawPrimitives.draw_text_shadow(canvas, font, snapshot.get("exit_position", Vector2.ZERO), str(snapshot.get("exit_text", "")), int(snapshot.get("exit_font_size", 1)), snapshot.get("exit_color", Color.WHITE))


static func draw_npc(canvas: CanvasItem, font: Font, snapshot: Dictionary, texture: Texture2D) -> void:
	if canvas == null or snapshot.is_empty():
		return
	var rect: Rect2 = snapshot.get("rect", Rect2())
	canvas.draw_rect(rect, snapshot.get("fill_color", Color.TRANSPARENT), true)
	canvas.draw_rect(rect, snapshot.get("accent_color", Color.TRANSPARENT), true)
	canvas.draw_rect(rect, snapshot.get("border_color", Color.TRANSPARENT), false, float(snapshot.get("border_width", 1.0)))
	var texture_rect: Rect2 = snapshot.get("texture_rect", Rect2())
	if texture != null and texture_rect.has_area():
		canvas.draw_texture_rect(texture, texture_rect, false)
	elif bool(snapshot.get("show_placeholder", false)):
		_draw_npc_placeholder(canvas, _get_dict(snapshot.get("placeholder", {})))
	if font == null:
		return
	PlazaInteriorDrawPrimitives.draw_text_shadow(canvas, font, snapshot.get("name_position", Vector2.ZERO), str(snapshot.get("name", "")), int(snapshot.get("name_font_size", 1)), snapshot.get("name_color", Color.WHITE))
	PlazaInteriorDrawPrimitives.draw_text_shadow(canvas, font, snapshot.get("message_position", Vector2.ZERO), str(snapshot.get("message", "")), int(snapshot.get("message_font_size", 1)), snapshot.get("message_color", Color.WHITE))


static func draw_topview_npc(canvas: CanvasItem, snapshot: Dictionary, texture: Texture2D) -> void:
	if canvas == null or texture == null or snapshot.is_empty():
		return
	canvas.draw_texture_rect(texture, snapshot.get("shadow_rect", Rect2()), false, snapshot.get("shadow_color", Color.WHITE))
	canvas.draw_texture_rect(texture, snapshot.get("draw_rect", Rect2()), false, snapshot.get("draw_color", Color.WHITE))


static func draw_speech_bubble(canvas: CanvasItem, font: Font, snapshot: Dictionary) -> void:
	if canvas == null or font == null or snapshot.is_empty():
		return
	var rect: Rect2 = snapshot.get("rect", Rect2())
	canvas.draw_rect(rect, snapshot.get("fill_color", Color.TRANSPARENT), true)
	canvas.draw_rect(rect, snapshot.get("border_color", Color.TRANSPARENT), false, float(snapshot.get("border_width", 1.0)))
	var tail: PackedVector2Array = snapshot.get("tail", PackedVector2Array())
	if tail.size() == 3:
		canvas.draw_colored_polygon(tail, snapshot.get("tail_fill_color", Color.TRANSPARENT))
		canvas.draw_line(tail[0], tail[2], snapshot.get("tail_line_color", Color.TRANSPARENT), float(snapshot.get("tail_line_width", 1.0)))
		canvas.draw_line(tail[1], tail[2], snapshot.get("tail_line_color", Color.TRANSPARENT), float(snapshot.get("tail_line_width", 1.0)))
	var lines: Array = snapshot.get("lines", [])
	for index in range(mini(lines.size(), 2)):
		PlazaInteriorDrawPrimitives.draw_text_shadow(
			canvas,
			font,
			snapshot.get("line_start_position", Vector2.ZERO) + Vector2(0.0, float(snapshot.get("line_spacing", 0.0)) * float(index)),
			str(lines[index]),
			int(snapshot.get("font_size", 1)),
			snapshot.get("text_color", Color.WHITE)
		)


static func draw_object_panel(canvas: CanvasItem, font: Font, snapshot: Dictionary, scale: float) -> void:
	if canvas == null or font == null or snapshot.is_empty():
		return
	var rect: Rect2 = snapshot.get("rect", Rect2())
	canvas.draw_rect(rect, snapshot.get("fill_color", Color.TRANSPARENT), true)
	canvas.draw_rect(rect, snapshot.get("accent_color", Color.TRANSPARENT), true)
	canvas.draw_rect(rect, snapshot.get("border_color", Color.TRANSPARENT), false, float(snapshot.get("border_width", 1.0)))
	PlazaInteriorDrawPrimitives.draw_text_shadow(canvas, font, snapshot.get("title_position", Vector2.ZERO), str(snapshot.get("title", "")), int(snapshot.get("title_font_size", 1)), snapshot.get("title_color", Color.WHITE))
	PlazaInteriorDrawPrimitives.draw_text_shadow(canvas, font, snapshot.get("description_position", Vector2.ZERO), str(snapshot.get("description", "")), int(snapshot.get("description_font_size", 1)), snapshot.get("description_color", Color.WHITE))
	PlazaInteriorDrawPrimitives.draw_text_shadow(canvas, font, snapshot.get("ap_position", Vector2.ZERO), str(snapshot.get("ap_text", "")), int(snapshot.get("ap_font_size", 1)), snapshot.get("ap_color", Color.WHITE))
	if str(snapshot.get("message", "")) != "":
		PlazaInteriorDrawPrimitives.draw_text_shadow(canvas, font, snapshot.get("message_position", Vector2.ZERO), str(snapshot.get("message", "")), int(snapshot.get("message_font_size", 1)), snapshot.get("message_color", Color.WHITE))
	var confirm_button := _get_dict(snapshot.get("confirm_button", {}))
	var cancel_button := _get_dict(snapshot.get("cancel_button", {}))
	PlazaInteriorDrawPrimitives.draw_button(canvas, font, confirm_button.get("rect", Rect2()), str(confirm_button.get("label", "")), confirm_button.get("color", Color.TRANSPARENT), scale)
	PlazaInteriorDrawPrimitives.draw_button(canvas, font, cancel_button.get("rect", Rect2()), str(cancel_button.get("label", "")), cancel_button.get("color", Color.TRANSPARENT), scale)


static func _draw_panel_rect(
	canvas: CanvasItem,
	snapshot: Dictionary,
	rect_key: String,
	fill_key: String,
	border_key: String,
	width_key: String
) -> void:
	var rect: Rect2 = snapshot.get(rect_key, Rect2())
	canvas.draw_rect(rect, snapshot.get(fill_key, Color.TRANSPARENT), true)
	canvas.draw_rect(rect, snapshot.get(border_key, Color.TRANSPARENT), false, float(snapshot.get(width_key, 1.0)))


static func _draw_npc_placeholder(canvas: CanvasItem, snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	canvas.draw_circle(snapshot.get("head_center", Vector2.ZERO), float(snapshot.get("head_radius", 0.0)), snapshot.get("head_color", Color.TRANSPARENT))
	canvas.draw_rect(snapshot.get("body_rect", Rect2()), snapshot.get("body_color", Color.TRANSPARENT), true)
	canvas.draw_line(snapshot.get("left_arm_start", Vector2.ZERO), snapshot.get("left_arm_end", Vector2.ZERO), snapshot.get("arm_color", Color.TRANSPARENT), float(snapshot.get("arm_width", 1.0)))
	canvas.draw_line(snapshot.get("right_arm_start", Vector2.ZERO), snapshot.get("right_arm_end", Vector2.ZERO), snapshot.get("arm_color", Color.TRANSPARENT), float(snapshot.get("arm_width", 1.0)))


static func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
