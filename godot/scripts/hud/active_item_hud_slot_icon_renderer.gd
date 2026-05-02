extends RefCounted

const DEFAULT_ITEM_COLOR := Color(200.0 / 255.0, 200.0 / 255.0, 200.0 / 255.0)


func draw_icon(canvas: Node2D, slot_rect: Rect2, item_data: Dictionary, scale_factor: float, visuals) -> void:
	var pad: float = max(1.0, floor(slot_rect.size.x * 0.09))
	var icon_rect: Rect2 = Rect2(slot_rect.position + Vector2(pad, pad), slot_rect.size - Vector2(pad * 2.0, pad * 2.0))
	var icon_texture: Texture2D = _get_icon_texture(item_data, visuals)
	if icon_texture != null:
		canvas.draw_texture_rect(icon_texture, icon_rect, false)
		return

	var item_color: Color = _get_item_color(item_data, visuals)
	var radius: float = slot_rect.size.x * 0.28
	var center: Vector2 = slot_rect.get_center()
	canvas.draw_circle(center, radius + 3.0 * scale_factor, Color(item_color.r, item_color.g, item_color.b, 0.18))
	canvas.draw_circle(center, radius, item_color)
	canvas.draw_circle(center + Vector2(-radius * 0.30, -radius * 0.35), max(1.0, radius * 0.28), Color(1.0, 1.0, 1.0, 0.28))


func _get_icon_texture(item_data: Dictionary, visuals) -> Texture2D:
	if visuals != null:
		var module_texture: Variant = visuals.get_icon_texture(item_data)
		if module_texture is Texture2D:
			return module_texture as Texture2D
	return null


func _get_item_color(item_data: Dictionary, visuals) -> Color:
	if visuals != null:
		var module_color: Variant = visuals.get_item_color(item_data)
		if module_color is Color:
			return module_color as Color
	return DEFAULT_ITEM_COLOR
