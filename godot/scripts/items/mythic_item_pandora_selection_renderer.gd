extends RefCounted


func get_choice_source_label(item_data: Dictionary) -> String:
	match str(item_data.get("pandora_source", item_data.get("type", "active"))):
		"mythic":
			return "신화"
		"passive":
			return "패시브"
		_:
			return "액티브"


func get_choice_source_color(item_data: Dictionary) -> Color:
	match str(item_data.get("pandora_source", item_data.get("type", "active"))):
		"mythic":
			return Color(1.0, 0.72, 0.24, 1.0)
		"passive":
			return Color(0.38, 0.82, 1.0, 1.0)
		_:
			return Color(0.74, 0.55, 1.0, 1.0)


func get_choice_title(item_data: Dictionary, active_item_korean_names: Dictionary) -> String:
	var item_name: String = str(item_data.get("name", ""))
	if active_item_korean_names.has(item_name):
		return str(active_item_korean_names[item_name])
	for key in ["korean_name", "display_name", "name"]:
		var value: String = str(item_data.get(key, ""))
		if value != "":
			return value
	return "???"


func get_choice_icon_texture(item_data: Dictionary, icon_texture_cache: Dictionary) -> Texture2D:
	var path: String = str(item_data.get("icon_path", ""))
	if path == "":
		return null
	if icon_texture_cache.has(path):
		var cached: Variant = icon_texture_cache[path]
		return cached if cached is Texture2D else null
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		var loaded: Resource = ResourceLoader.load(path)
		if loaded is Texture2D:
			texture = loaded
	icon_texture_cache[path] = texture
	return texture


func get_card_rect(index: int, view_size: Vector2, card_count: int) -> Rect2:
	var gap: float = 34.0
	var card_w: float = 150.0
	var card_h: float = 174.0
	var max_width: float = max(260.0, view_size.x - 40.0)
	var total_w: float = card_w * float(card_count) + gap * float(card_count - 1)
	if total_w > max_width:
		card_w = max(92.0, (max_width - gap * float(card_count - 1)) / float(card_count))
		card_h = max(142.0, card_w * 1.14)
		total_w = card_w * float(card_count) + gap * float(card_count - 1)
	var start_x: float = view_size.x * 0.5 - total_w * 0.5
	var card_y: float = clamp(view_size.y * 0.40, 142.0, max(142.0, view_size.y - card_h - 72.0))
	return Rect2(Vector2(start_x + float(index) * (card_w + gap), card_y), Vector2(card_w, card_h))


func get_card_index_at(position: Vector2, view_size: Vector2, card_count: int) -> int:
	for i in range(card_count):
		if get_card_rect(i, view_size, card_count).has_point(position):
			return i
	return -1


func draw_choice_card_body(
	canvas: CanvasItem,
	font: Font,
	rect: Rect2,
	badge_text: String,
	badge_color: Color,
	icon_texture: Texture2D,
	title: String,
	selected: bool,
	alpha: float
) -> void:
	var fill := Color(0.10, 0.07, 0.18, 0.92 * alpha)
	var border := Color(0.46, 0.36, 0.72, 0.95 * alpha)
	if selected:
		fill = Color(0.17, 0.12, 0.27, 0.97 * alpha)
		border = Color(1.0, 0.80, 0.26, alpha)
		canvas.draw_rect(rect.grow(7.0), Color(1.0, 0.72, 0.18, 0.10 * alpha))
	canvas.draw_rect(rect, fill)
	canvas.draw_rect(rect, border, false, 2.6 if selected else 1.6)
	draw_badge(canvas, font, rect.position + Vector2(10.0, 22.0), badge_text, badge_color, alpha)
	var icon_rect := Rect2(rect.position + Vector2(rect.size.x * 0.5 - 32.0, 46.0), Vector2(64.0, 64.0))
	if icon_texture != null:
		canvas.draw_texture_rect(icon_texture, icon_rect, false, Color(1.0, 1.0, 1.0, alpha))
	else:
		canvas.draw_circle(icon_rect.get_center(), 28.0, Color(badge_color.r, badge_color.g, badge_color.b, 0.72 * alpha))
		canvas.draw_circle(icon_rect.get_center(), 20.0, Color(1.0, 1.0, 1.0, 0.12 * alpha))
	draw_centered_text(canvas, font, title, rect.position + Vector2(rect.size.x * 0.5, 132.0), 14, Color(0.95, 0.97, 1.0, alpha), rect.size.x - 16.0)


func draw_badge(canvas: CanvasItem, font: Font, pos: Vector2, text: String, color: Color, alpha: float) -> void:
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11)
	var badge_rect := Rect2(pos, Vector2(text_size.x + 14.0, 22.0))
	canvas.draw_rect(badge_rect, Color(color.r, color.g, color.b, 0.18 * alpha))
	canvas.draw_rect(badge_rect, Color(color.r, color.g, color.b, 0.74 * alpha), false, 1.0)
	canvas.draw_string(font, pos + Vector2(7.0, 15.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color(0.95, 0.98, 1.0, alpha))


func draw_centered_text(
	canvas: CanvasItem,
	font: Font,
	text: String,
	center: Vector2,
	font_size: int,
	color: Color,
	width: float = -1.0
) -> void:
	var measured: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var draw_width: float = width if width > 0.0 else measured.x
	var pos := Vector2(center.x - draw_width * 0.5, center.y + measured.y * 0.32)
	canvas.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, draw_width, font_size, 2, Color(0.0, 0.0, 0.0, color.a * 0.70))
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, draw_width, font_size, color)
