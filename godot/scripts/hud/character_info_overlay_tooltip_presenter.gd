extends RefCounted

const CharacterInfoOverlayTextureDrawer := preload("res://scripts/hud/character_info_overlay_texture_drawer.gd")
const CharacterInfoOverlayValueUtils := preload("res://scripts/hud/character_info_overlay_value_utils.gd")


static func draw_tooltip(
	canvas: CanvasItem,
	data: Dictionary,
	mouse_pos: Vector2,
	view_size: Vector2,
	font: Font,
	empty_roll_entries: Array,
	accent_blue: Color,
	text_soft: Color,
	panel_fill: Color,
	draw_text_callable: Callable,
	wrap_text_callable: Callable,
	tooltip_width_callable: Callable,
	draw_dual_item_tooltip_callable: Callable,
	tooltip_subtitle_color_callable: Callable
) -> void:
	var color: Color = CharacterInfoOverlayValueUtils.get_color(data.get("color", accent_blue))
	var title: String = str(data.get("title", ""))
	var title_color: Color = CharacterInfoOverlayValueUtils.get_color(data.get("title_color", Color.WHITE))
	var subtitle: String = str(data.get("subtitle", ""))
	var body: String = str(data.get("body", ""))
	var roll_entries: Array = CharacterInfoOverlayValueUtils.get_array(data.get("roll_options")) if data.has("roll_options") else CharacterInfoOverlayValueUtils.get_array(data.get("options")) if data.has("options") else empty_roll_entries
	if not roll_entries.is_empty() and body != "":
		draw_dual_item_tooltip_callable.call(canvas, data, mouse_pos, view_size, font, color, title, subtitle, body, roll_entries)
		return
	var width: float = float(tooltip_width_callable.call(font, title, subtitle, body, view_size))
	var text_width: float = width - 28.0
	var title_lines: Array = _call_array(wrap_text_callable, [font, title, 15, text_width, 2])
	var subtitle_lines: Array = _call_array(wrap_text_callable, [font, subtitle, 12, text_width, 2])
	var line_height := 20.0
	var max_tooltip_height: float = max(80.0, view_size.y - 16.0)
	var fixed_height: float = 38.0 + float(title_lines.size() + subtitle_lines.size()) * line_height
	var body_line_limit: int = max(1, int(floor((max_tooltip_height - fixed_height) / line_height)))
	var body_lines: Array = _call_array(wrap_text_callable, [font, body, 13, text_width, body_line_limit])
	var height: float = fixed_height + float(body_lines.size()) * line_height
	var anchor_rect: Rect2 = CharacterInfoOverlayValueUtils.tooltip_anchor_rect(data, mouse_pos)
	var pos_x: float = anchor_rect.position.x + 10.0
	var pos_y: float = anchor_rect.end.y + 12.0
	if pos_x + width > view_size.x - 8.0:
		pos_x = anchor_rect.end.x - width
	if pos_y + height > view_size.y - 8.0:
		pos_y = anchor_rect.position.y - height - 12.0
	pos_x = clamp(pos_x, 8.0, max(8.0, view_size.x - width - 8.0))
	pos_y = clamp(pos_y, 8.0, max(8.0, view_size.y - height - 8.0))
	var rect := Rect2(pos_x, pos_y, width, height)
	CharacterInfoOverlayTextureDrawer.draw_panel(canvas, rect, panel_fill, color, 2.0)
	var text_x: float = pos_x + 14.0
	var y := pos_y + 24.0
	for line in title_lines:
		draw_text_callable.call(canvas, font, str(line), text_x, y, 15, title_color)
		y += line_height
	if not subtitle_lines.is_empty():
		var subtitle_color: Color = _call_color(tooltip_subtitle_color_callable, color)
		for line in subtitle_lines:
			draw_text_callable.call(canvas, font, str(line), text_x, y, 12, subtitle_color)
			y += line_height
	for line in body_lines:
		draw_text_callable.call(canvas, font, str(line), text_x, y, 13, text_soft)
		y += line_height


static func draw_dual_item_tooltip(
	canvas: CanvasItem,
	data: Dictionary,
	mouse_pos: Vector2,
	view_size: Vector2,
	font: Font,
	color: Color,
	title: String,
	subtitle: String,
	body: String,
	roll_entries: Array,
	text_soft: Color,
	accent_gold: Color,
	panel_fill: Color,
	roll_panel_fill: Color,
	roll_border: Color,
	draw_text_callable: Callable,
	wrap_text_callable: Callable,
	build_entry_lines_callable: Callable,
	tooltip_subtitle_color_callable: Callable,
	tooltip_entry_line_text_cache: Array[String],
	tooltip_entry_line_color_cache: Array[Color]
) -> void:
	var gap := 10.0
	var desc_width: float = min(270.0, max(205.0, view_size.x * 0.52))
	var roll_width: float = min(210.0, max(154.0, view_size.x - desc_width - gap - 26.0))
	if desc_width + gap + roll_width > view_size.x - 16.0:
		var available: float = max(300.0, view_size.x - 16.0 - gap)
		desc_width = max(178.0, available * 0.58)
		roll_width = max(132.0, available - desc_width)
	var body_lines: Array = _call_array(wrap_text_callable, [font, body, 13, desc_width - 28.0, 8])
	var roll_lines: Array = _call_array(build_entry_lines_callable, [font, roll_entries, 13, roll_width - 24.0, 8])
	var title_color: Color = CharacterInfoOverlayValueUtils.get_color(data.get("title_color", Color.WHITE))
	var line_height := 20.0
	var desc_height: float = 58.0 + float(body_lines.size()) * line_height
	if subtitle != "":
		desc_height += line_height
	var roll_height: float = 42.0 + float(roll_lines.size()) * line_height
	var total_width: float = desc_width + gap + roll_width
	var total_height: float = max(desc_height, roll_height)
	var anchor_rect: Rect2 = CharacterInfoOverlayValueUtils.tooltip_anchor_rect(data, mouse_pos)
	var pos_x: float = anchor_rect.position.x + 10.0
	var pos_y: float = anchor_rect.position.y - total_height - 12.0
	if pos_y < 8.0:
		pos_y = anchor_rect.end.y + 12.0
	if pos_x + total_width > view_size.x - 8.0:
		pos_x = anchor_rect.end.x - total_width
	pos_x = clamp(pos_x, 8.0, max(8.0, view_size.x - total_width - 8.0))
	pos_y = clamp(pos_y, 8.0, max(8.0, view_size.y - total_height - 8.0))

	var desc_rect := Rect2(pos_x, pos_y, desc_width, desc_height)
	var roll_rect := Rect2(pos_x + desc_width + gap, pos_y, roll_width, roll_height)
	CharacterInfoOverlayTextureDrawer.draw_panel(canvas, desc_rect, panel_fill, color, 2.0)
	var desc_text_x: float = pos_x + 14.0
	draw_text_callable.call(canvas, font, title, desc_text_x, pos_y + 24.0, 15, title_color)
	var desc_y := pos_y + 44.0
	if subtitle != "":
		var subtitle_color: Color = _call_color(tooltip_subtitle_color_callable, color)
		draw_text_callable.call(canvas, font, subtitle, desc_text_x, desc_y, 12, subtitle_color)
		desc_y += line_height
	for line in body_lines:
		draw_text_callable.call(canvas, font, str(line), desc_text_x, desc_y, 13, text_soft)
		desc_y += line_height

	CharacterInfoOverlayTextureDrawer.draw_panel(canvas, roll_rect, roll_panel_fill, roll_border, 2.0)
	var roll_text_x: float = pos_x + desc_width + gap + 12.0
	draw_text_callable.call(canvas, font, "롤 옵션", roll_text_x, pos_y + 24.0, 13, accent_gold)
	var roll_y := pos_y + 44.0
	for i in range(roll_lines.size()):
		draw_text_callable.call(canvas, font, tooltip_entry_line_text_cache[i], roll_text_x, roll_y, 13, tooltip_entry_line_color_cache[i])
		roll_y += line_height


static func _call_array(callable: Callable, arguments: Array) -> Array:
	var value: Variant = callable.callv(arguments)
	return value if value is Array else []


static func _call_color(callable: Callable, color: Color) -> Color:
	var value: Variant = callable.call(color)
	return value if value is Color else color
