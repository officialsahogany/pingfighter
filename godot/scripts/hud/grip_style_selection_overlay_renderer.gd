extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const CARD_GAP := 22.0
const CARD_RADIUS := 8.0
const TITLE_FONT_SIZE := 28
const CARD_TITLE_FONT_SIZE := 18
const CARD_DESC_FONT_SIZE := 13
const HINT_FONT_SIZE := 14
const CARD_ASPECT := 16.0 / 9.0


static func draw_overlay(
	canvas: CanvasItem,
	view_size: Vector2,
	alpha: float,
	selected_index: int,
	hovered_index: int,
	pressed_index: int,
	pending_confirm: bool,
	textures: Array[Texture2D],
	card_specs: Array,
	title_text: String,
	subtitle_text: String,
	footer_text: String,
	text_size_cache: Dictionary
) -> void:
	if canvas == null:
		return
	ensure_textures(textures, card_specs)
	var draw_alpha: float = clampf(alpha, 0.0, 1.0)
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, 0.52 * draw_alpha))
	var panel_rect: Rect2 = get_panel_rect(view_size)
	draw_round_rect(canvas, panel_rect, CARD_RADIUS, Color(0.96, 0.97, 0.98, 0.98 * draw_alpha))
	draw_round_rect_outline(canvas, panel_rect, CARD_RADIUS, Color(0.16, 0.20, 0.26, 0.28 * draw_alpha), 2.0)

	var title_y: float = panel_rect.position.y + 42.0
	draw_centered_text(canvas, title_text, Vector2(panel_rect.get_center().x, title_y), TITLE_FONT_SIZE, Color(0.08, 0.10, 0.13, draw_alpha), text_size_cache)
	draw_centered_text(canvas, subtitle_text, Vector2(panel_rect.get_center().x, title_y + 34.0), HINT_FONT_SIZE, Color(0.24, 0.28, 0.34, 0.84 * draw_alpha), text_size_cache)

	var card_rects: Array[Rect2] = get_card_rects(view_size)
	for i in range(card_rects.size()):
		draw_card(canvas, i, card_rects[i], draw_alpha, selected_index, hovered_index, pressed_index, pending_confirm, textures, card_specs, text_size_cache)

	draw_centered_text(canvas, footer_text, Vector2(panel_rect.get_center().x, panel_rect.end.y - 28.0), HINT_FONT_SIZE, Color(0.30, 0.34, 0.40, 0.80 * draw_alpha), text_size_cache)


static func get_card_rects(view_size: Vector2) -> Array[Rect2]:
	var panel_rect: Rect2 = get_panel_rect(view_size)
	var inner_margin := 38.0
	var available_width: float = max(1.0, panel_rect.size.x - inner_margin * 2.0)
	var cards_top: float = panel_rect.position.y + 106.0
	var bottom_reserved := 64.0
	if view_size.x < 900.0:
		var vertical_card_width: float = min(360.0, available_width)
		var vertical_card_height: float = min(170.0, (panel_rect.end.y - cards_top - bottom_reserved - CARD_GAP * 2.0) / 3.0)
		var result: Array[Rect2] = []
		var vertical_start_x: float = panel_rect.get_center().x - vertical_card_width * 0.5
		for i in range(3):
			result.append(Rect2(vertical_start_x, cards_top + float(i) * (vertical_card_height + CARD_GAP), vertical_card_width, vertical_card_height))
		return result
	var card_width: float = min(320.0, (available_width - CARD_GAP * 2.0) / 3.0)
	var card_height: float = min(270.0, panel_rect.end.y - cards_top - bottom_reserved)
	var total_width: float = card_width * 3.0 + CARD_GAP * 2.0
	var start_x: float = panel_rect.get_center().x - total_width * 0.5
	var horizontal_result: Array[Rect2] = []
	for i in range(3):
		horizontal_result.append(Rect2(start_x + float(i) * (card_width + CARD_GAP), cards_top, card_width, card_height))
	return horizontal_result


static func get_panel_rect(view_size: Vector2) -> Rect2:
	var panel_width: float = min(view_size.x - 64.0, 1120.0)
	var panel_height: float = min(view_size.y - 64.0, 472.0)
	if view_size.x < 900.0:
		panel_width = min(view_size.x - 32.0, 430.0)
		panel_height = min(view_size.y - 32.0, 690.0)
	return Rect2((view_size - Vector2(panel_width, panel_height)) * 0.5, Vector2(panel_width, panel_height))


static func draw_card(
	canvas: CanvasItem,
	index: int,
	card_rect: Rect2,
	draw_alpha: float,
	selected_index: int,
	hovered_index: int,
	pressed_index: int,
	pending_confirm: bool,
	textures: Array[Texture2D],
	card_specs: Array,
	text_size_cache: Dictionary
) -> void:
	var selected: bool = index == selected_index
	var hovered: bool = index == hovered_index
	var pressed: bool = index == pressed_index or (pending_confirm and selected)
	var visual_rect: Rect2 = card_rect
	if pressed:
		visual_rect.position.y += 2.0
	elif hovered:
		visual_rect.position.y -= 4.0
		visual_rect = visual_rect.grow(3.0)
	var shadow_alpha: float = 0.20 if (hovered or selected or pressed) else 0.08
	var shadow_offset := Vector2(0.0, 7.0 if (hovered or pressed) else 4.0)
	draw_round_rect(canvas, Rect2(visual_rect.position + shadow_offset, visual_rect.size), CARD_RADIUS, Color(0.0, 0.0, 0.0, shadow_alpha * draw_alpha))
	var card_color := Color(1.0, 1.0, 1.0, 0.98 * draw_alpha)
	if hovered:
		card_color = Color(0.96, 0.99, 1.0, 1.0 * draw_alpha)
	if pressed:
		card_color = Color(0.88, 0.96, 1.0, 1.0 * draw_alpha)
	var border_color := Color(0.12, 0.55, 0.94, 0.95 * draw_alpha) if selected else Color(0.18, 0.22, 0.28, 0.18 * draw_alpha)
	var border_width := 3.0 if selected else 1.4
	if hovered:
		border_color = Color(0.09, 0.66, 1.0, 1.0 * draw_alpha)
		border_width = 3.6
	if pressed:
		border_color = Color(0.02, 0.42, 0.98, 1.0 * draw_alpha)
		border_width = 4.2
	draw_round_rect(canvas, visual_rect, CARD_RADIUS, card_color)
	draw_round_rect_outline(canvas, visual_rect, CARD_RADIUS, border_color, border_width)
	var image_margin := 12.0
	var image_rect := Rect2(
		visual_rect.position + Vector2(image_margin, image_margin),
		Vector2(visual_rect.size.x - image_margin * 2.0, (visual_rect.size.x - image_margin * 2.0) / CARD_ASPECT)
	)
	image_rect.size.y = min(image_rect.size.y, visual_rect.size.y - 92.0)
	var texture: Texture2D = get_texture(index, textures)
	if texture != null:
		canvas.draw_texture_rect(texture, image_rect, false, Color(1.0, 1.0, 1.0, draw_alpha))
	else:
		canvas.draw_rect(image_rect, Color(0.90, 0.92, 0.95, draw_alpha))
	draw_centered_text(canvas, get_card_title(card_specs, index), Vector2(visual_rect.get_center().x, image_rect.end.y + 26.0), CARD_TITLE_FONT_SIZE, Color(0.08, 0.10, 0.14, draw_alpha), text_size_cache)
	draw_centered_text(canvas, get_card_desc(card_specs, index), Vector2(visual_rect.get_center().x, image_rect.end.y + 49.0), CARD_DESC_FONT_SIZE, Color(0.32, 0.36, 0.42, 0.86 * draw_alpha), text_size_cache)


static func draw_round_rect(canvas: CanvasItem, rect: Rect2, radius: float, color: Color) -> void:
	canvas.draw_rect(Rect2(rect.position + Vector2(radius, 0.0), Vector2(rect.size.x - radius * 2.0, rect.size.y)), color)
	canvas.draw_rect(Rect2(rect.position + Vector2(0.0, radius), Vector2(rect.size.x, rect.size.y - radius * 2.0)), color)
	canvas.draw_circle(rect.position + Vector2(radius, radius), radius, color)
	canvas.draw_circle(rect.position + Vector2(rect.size.x - radius, radius), radius, color)
	canvas.draw_circle(rect.position + Vector2(radius, rect.size.y - radius), radius, color)
	canvas.draw_circle(rect.position + rect.size - Vector2(radius, radius), radius, color)


static func draw_round_rect_outline(canvas: CanvasItem, rect: Rect2, radius: float, color: Color, width: float) -> void:
	canvas.draw_arc(rect.position + Vector2(radius, radius), radius, PI, PI * 1.5, 10, color, width)
	canvas.draw_arc(rect.position + Vector2(rect.size.x - radius, radius), radius, PI * 1.5, TAU, 10, color, width)
	canvas.draw_arc(rect.position + Vector2(rect.size.x - radius, rect.size.y - radius), radius, 0.0, PI * 0.5, 10, color, width)
	canvas.draw_arc(rect.position + Vector2(radius, rect.size.y - radius), radius, PI * 0.5, PI, 10, color, width)
	canvas.draw_line(rect.position + Vector2(radius, 0.0), rect.position + Vector2(rect.size.x - radius, 0.0), color, width)
	canvas.draw_line(rect.position + Vector2(rect.size.x, radius), rect.position + Vector2(rect.size.x, rect.size.y - radius), color, width)
	canvas.draw_line(rect.position + Vector2(radius, rect.size.y), rect.position + Vector2(rect.size.x - radius, rect.size.y), color, width)
	canvas.draw_line(rect.position + Vector2(0.0, radius), rect.position + Vector2(0.0, rect.size.y - radius), color, width)


static func draw_centered_text(canvas: CanvasItem, text: String, baseline_center: Vector2, font_size: int, color: Color, text_size_cache: Dictionary) -> void:
	if text == "":
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text_size: Vector2 = get_text_size(font, text, font_size, text_size_cache)
	var pos := Vector2(baseline_center.x - text_size.x * 0.5, baseline_center.y)
	canvas.draw_string(font, pos + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(1.0, 1.0, 1.0, min(color.a, 0.80)))
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


static func ensure_textures(textures: Array[Texture2D], card_specs: Array) -> void:
	while textures.size() < card_specs.size():
		textures.append(null)
	for i in range(card_specs.size()):
		load_texture_at(i, textures, card_specs)


static func load_texture_at(index: int, textures: Array[Texture2D], card_specs: Array) -> void:
	while textures.size() < card_specs.size():
		textures.append(null)
	if index < 0 or index >= card_specs.size():
		return
	if textures[index] != null:
		return
	var texture_path: String = str(get_card_spec(card_specs, index).get("texture_path", ""))
	if texture_path == "" or not ResourceLoader.exists(texture_path):
		return
	var loaded: Resource = ResourceLoader.load(texture_path)
	if loaded is Texture2D:
		textures[index] = loaded as Texture2D


static func get_texture(index: int, textures: Array[Texture2D]) -> Texture2D:
	if index < 0 or index >= textures.size():
		return null
	return textures[index]


static func get_card_title(card_specs: Array, index: int) -> String:
	var spec: Dictionary = get_card_spec(card_specs, index)
	return translate(str(spec.get("title_key", "")), str(spec.get("title_fallback", "")))


static func get_card_desc(card_specs: Array, index: int) -> String:
	var spec: Dictionary = get_card_spec(card_specs, index)
	return translate(str(spec.get("desc_key", "")), str(spec.get("desc_fallback", "")))


static func get_card_spec(card_specs: Array, index: int) -> Dictionary:
	if index < 0 or index >= card_specs.size():
		return {}
	var value: Variant = card_specs[index]
	if value is Dictionary:
		return value
	return {}


static func get_text_size(font: Font, text: String, font_size: int, text_size_cache: Dictionary) -> Vector2:
	var cache_key := str(font_size) + ":" + text
	if text_size_cache.has(cache_key):
		var cached_size: Variant = text_size_cache[cache_key]
		if cached_size is Vector2:
			return cached_size
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	text_size_cache[cache_key] = text_size
	return text_size


static func translate(key: String, fallback: String) -> String:
	if key == "":
		return fallback
	return LanguageSettings.translate(key, fallback)
