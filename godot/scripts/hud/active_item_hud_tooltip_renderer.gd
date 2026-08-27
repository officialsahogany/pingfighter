extends RefCounted

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const BASE_WIDTH := 286.0
const BASE_PADDING := 13.0
const PANEL_FILL := Color(0.045, 0.055, 0.09, 0.97)
const PANEL_BORDER := Color(0.42, 0.82, 1.0, 0.92)
const TITLE_COLOR := Color(1.0, 0.93, 0.67)
const META_COLOR := Color(0.55, 0.84, 1.0)
const BODY_COLOR := Color(0.88, 0.91, 0.96)
const READY_COLOR := Color(0.48, 1.0, 0.68)
const WAIT_COLOR := Color(1.0, 0.66, 0.38)

var _catalog: Object = ActiveItemCatalog.new()


func build_tooltip_data(item_data: Dictionary, slot_status: Dictionary, slot_index: int) -> Dictionary:
	var localized_item: Dictionary = _resolve_localized_item(item_data)
	var display_name: String = str(localized_item.get("qualified_display_name", localized_item.get("display_name", localized_item.get("name", "")))).strip_edges()
	var description: String = str(localized_item.get("description", localized_item.get("desc", ""))).strip_edges()
	var throw_lock_seconds: int = int(slot_status.get("throw_lock_remaining_seconds", 0))
	var cooldown_ratio: float = float(slot_status.get("cooldown_remaining_ratio", 0.0))
	var status_text: String
	var status_color: Color
	if throw_lock_seconds > 0:
		status_text = LanguageSettings.translate("hud.active_item.throw_lock", "투척 준비 %d초") % throw_lock_seconds
		status_color = WAIT_COLOR
	elif cooldown_ratio > 0.0:
		status_text = LanguageSettings.translate("hud.active_item.cooldown", "재사용 대기 중")
		status_color = WAIT_COLOR
	else:
		status_text = LanguageSettings.translate("hud.active_item.ready", "사용 가능")
		status_color = READY_COLOR
	return {
		"title": display_name,
		"body": description,
		"hint": LanguageSettings.translate("hud.active_item.click_hint", "슬롯 %d · 좌클릭으로 사용") % (slot_index + 1),
		"status": status_text,
		"status_color": status_color,
	}


func draw(
	canvas: CanvasItem,
	item_data: Dictionary,
	slot_status: Dictionary,
	slot_index: int,
	anchor_rect: Rect2,
	view_size: Vector2,
	scale_factor: float
) -> void:
	if canvas == null or item_data.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var data: Dictionary = build_tooltip_data(item_data, slot_status, slot_index)
	var ui_scale: float = clampf(scale_factor, 0.88, 1.22)
	var width: float = minf(BASE_WIDTH * ui_scale, maxf(180.0, view_size.x - 16.0))
	var padding: float = BASE_PADDING * ui_scale
	var text_width: float = maxf(120.0, width - padding * 2.0)
	var title_size: int = maxi(14, int(round(16.0 * ui_scale)))
	var meta_size: int = maxi(11, int(round(12.0 * ui_scale)))
	var body_size: int = maxi(12, int(round(13.0 * ui_scale)))
	var title_lines: Array[String] = _wrap_text(font, str(data.get("title", "")), title_size, text_width, 2)
	var body_lines: Array[String] = _wrap_text(font, str(data.get("body", "")), body_size, text_width, 6)
	var title_line_height: float = 21.0 * ui_scale
	var meta_line_height: float = 18.0 * ui_scale
	var body_line_height: float = 19.0 * ui_scale
	var height: float = padding * 2.0 + float(title_lines.size()) * title_line_height + meta_line_height * 2.0
	if not body_lines.is_empty():
		height += 7.0 * ui_scale + float(body_lines.size()) * body_line_height

	var position := Vector2(anchor_rect.position.x, anchor_rect.position.y - height - 10.0 * ui_scale)
	if position.y < 8.0:
		position.y = anchor_rect.end.y + 10.0 * ui_scale
	position.x = clampf(position.x, 8.0, maxf(8.0, view_size.x - width - 8.0))
	position.y = clampf(position.y, 8.0, maxf(8.0, view_size.y - height - 8.0))
	var panel_rect := Rect2(position, Vector2(width, height))
	canvas.draw_rect(panel_rect, PANEL_FILL)
	canvas.draw_rect(panel_rect, PANEL_BORDER, false, maxf(1.0, 1.5 * ui_scale))
	canvas.draw_line(panel_rect.position + Vector2(1.0, 2.0), Vector2(panel_rect.end.x - 1.0, panel_rect.position.y + 2.0), Color(1.0, 0.82, 0.34, 0.72), maxf(1.0, 2.0 * ui_scale))

	var x: float = position.x + padding
	var y: float = position.y + padding
	for line in title_lines:
		y += font.get_ascent(title_size)
		_draw_text(canvas, font, str(line), Vector2(x, y), title_size, TITLE_COLOR)
		y += title_line_height - font.get_ascent(title_size)
	_draw_text(canvas, font, str(data.get("hint", "")), Vector2(x, y + font.get_ascent(meta_size)), meta_size, META_COLOR)
	y += meta_line_height
	_draw_text(canvas, font, str(data.get("status", "")), Vector2(x, y + font.get_ascent(meta_size)), meta_size, data.get("status_color", READY_COLOR) as Color)
	y += meta_line_height
	if not body_lines.is_empty():
		y += 7.0 * ui_scale
		canvas.draw_line(Vector2(x, y - 3.0 * ui_scale), Vector2(position.x + width - padding, y - 3.0 * ui_scale), Color(0.35, 0.48, 0.66, 0.55), 1.0)
		for line in body_lines:
			_draw_text(canvas, font, str(line), Vector2(x, y + font.get_ascent(body_size)), body_size, BODY_COLOR)
			y += body_line_height


func _resolve_localized_item(item_data: Dictionary) -> Dictionary:
	var item_id: String = _get_item_identity(item_data)
	if item_id != "":
		var catalog_item: Dictionary = _catalog.build_item_by_name(item_id)
		if not catalog_item.is_empty():
			return catalog_item
	return LanguageSettings.localize_item_data(item_data)


func _get_item_identity(item_data: Dictionary) -> String:
	for key in ["name", "effect", "item_name", "item_id"]:
		var value: String = str(item_data.get(key, ""))
		if value != "":
			return value
	return ""


func _wrap_text(font: Font, text: String, font_size: int, max_width: float, max_lines: int) -> Array[String]:
	var lines: Array[String] = []
	for paragraph in text.split("\n"):
		var words: PackedStringArray = str(paragraph).split(" ", false)
		var current := ""
		for word in words:
			var candidate: String = str(word) if current == "" else "%s %s" % [current, word]
			if current != "" and font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > max_width:
				lines.append(current)
				current = str(word)
				if lines.size() >= max_lines:
					return lines
			else:
				current = candidate
		if current != "" and lines.size() < max_lines:
			lines.append(current)
		if lines.size() >= max_lines:
			break
	return lines


func _draw_text(canvas: CanvasItem, font: Font, text: String, baseline: Vector2, font_size: int, color: Color) -> void:
	canvas.draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 2, Color(0.0, 0.0, 0.0, 0.92))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
