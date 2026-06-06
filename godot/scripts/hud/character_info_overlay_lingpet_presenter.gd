extends RefCounted

const CharacterInfoOverlayFormatter := preload("res://scripts/hud/character_info_overlay_formatter.gd")
const CharacterInfoOverlayLingpetSnapshotBuilder := preload("res://scripts/hud/character_info_overlay_lingpet_snapshot_builder.gd")
const CharacterInfoOverlayLingpetTextureLoader := preload("res://scripts/hud/character_info_overlay_lingpet_texture_loader.gd")
const CharacterInfoOverlayTextureDrawer := preload("res://scripts/hud/character_info_overlay_texture_drawer.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")

const PANEL_LIVE2D_COLS_BY_PET_ID := {
	"lunabi": 14,
}
const PANEL_LIVE2D_ROWS_BY_PET_ID := {
	"lunabi": 7,
}
const PANEL_LIVE2D_FRAME_COUNT_BY_PET_ID := {
	"lunabi": 98,
}
const PANEL_LIVE2D_FRAME_INTERVAL_BY_PET_ID := {
	"lunabi": 1.0 / 16.0,
}

static func draw_panel(
	canvas: CanvasItem,
	font: Font,
	rect: Rect2,
	snapshot: Dictionary,
	mouse_pos: Vector2,
	hover_data: Dictionary,
	skill_icon_rects: Array,
	art_texture_cache: Dictionary,
	skill_icon_texture_cache: Dictionary,
	section_color: Color,
	section_border: Color,
	grid_fill: Color,
	stat_buff_color: Color,
	empty_text_color: Color,
	accent_blue: Color,
	accent_gold: Color,
	text_soft: Color,
	slot_fill: Color,
	ring_segments: int,
	ui_text_scale: float,
	wrap_text_callable: Callable,
	hatch_required_hits: int,
	panel_animation_time: float = 0.0
) -> Dictionary:
	skill_icon_rects.clear()
	CharacterInfoOverlayTextureDrawer.draw_panel(canvas, rect, section_color, section_border, 2.0)
	_draw_text_xy(canvas, font, "링펫", rect.position.x + 12.0, rect.position.y + 24.0, 13, accent_blue, ui_text_scale)
	var content_rect := Rect2(rect.position.x + 12.0, rect.position.y + 36.0, rect.size.x - 24.0, rect.size.y - 48.0)
	canvas.draw_rect(content_rect, grid_fill)
	var state: String = str(snapshot.get("state", "none"))
	if state == "companion":
		return draw_companion_panel(canvas, font, content_rect, snapshot, mouse_pos, hover_data, skill_icon_rects, art_texture_cache, skill_icon_texture_cache, stat_buff_color, empty_text_color, accent_blue, slot_fill, ring_segments, ui_text_scale, panel_animation_time)
	draw_non_companion_panel(canvas, font, content_rect, snapshot, hatch_required_hits, stat_buff_color, empty_text_color, accent_gold, text_soft, ring_segments, ui_text_scale, wrap_text_callable)
	return hover_data


static func draw_egg_icon(canvas: CanvasItem, rect: Rect2, state: String, progress: float, stat_buff_color: Color, empty_text_color: Color, ring_segments: int, ui_text_scale: float) -> void:
	var center := rect.get_center()
	var rx: float = rect.size.x * 0.34
	var ry: float = rect.size.y * 0.43
	var egg_color := Color(1.0, 170.0 / 255.0, 218.0 / 255.0, 0.28)
	var ring_color := Color(85.0 / 255.0, 218.0 / 255.0, 1.0, 0.82)
	if state == "companion":
		egg_color = Color(105.0 / 255.0, 245.0 / 255.0, 170.0 / 255.0, 0.24)
		ring_color = stat_buff_color
	for i in range(5, 0, -1):
		canvas.draw_circle(center, max(rx, ry) + float(i) * 3.0, Color(ring_color.r, ring_color.g, ring_color.b, 0.018 * float(i)))
	var egg_points := PackedVector2Array()
	for point_index in range(18):
		var angle: float = TAU * float(point_index) / 18.0
		egg_points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	canvas.draw_colored_polygon(egg_points, egg_color)
	canvas.draw_arc(center, max(rx, ry) * 0.84, 0.0, TAU, ring_segments, ring_color, 2.0)
	canvas.draw_circle(center + Vector2(-rx * 0.24, -ry * 0.22), max(2.0, rx * 0.09), Color(1.0, 1.0, 1.0, 0.58))
	if state == "egg" and progress > 0.0:
		var crack_color := Color(1.0, 245.0 / 255.0, 170.0 / 255.0, 0.88)
		var crack_bottom: float = center.y - ry * 0.2 + ry * 0.95 * progress
		canvas.draw_polyline(PackedVector2Array([
			center + Vector2(-rx * 0.08, -ry * 0.62),
			center + Vector2(rx * 0.10, -ry * 0.30),
			center + Vector2(-rx * 0.02, -ry * 0.06),
			Vector2(center.x + rx * 0.18, crack_bottom),
		]), crack_color, 1.8)
	elif state == "none":
		var none_rect := rect.grow(-8.0)
		var none_line_color := Color(empty_text_color.r, empty_text_color.g, empty_text_color.b, 0.32)
		canvas.draw_line(none_rect.position + Vector2(9.0, 9.0), none_rect.end - Vector2(9.0, 9.0), none_line_color, 1.4)
		canvas.draw_line(Vector2(none_rect.end.x - 9.0, none_rect.position.y + 9.0), Vector2(none_rect.position.x + 9.0, none_rect.end.y - 9.0), none_line_color, 1.4)
	else:
		_draw_centered_fallback_text(canvas, "M", center.x, center.y + 4.0, int(rect.size.x * 0.30), Color.WHITE, ui_text_scale)


static func draw_non_companion_panel(
	canvas: CanvasItem,
	font: Font,
	content_rect: Rect2,
	snapshot: Dictionary,
	hatch_required_hits: int,
	stat_buff_color: Color,
	empty_text_color: Color,
	accent_gold: Color,
	text_soft: Color,
	ring_segments: int,
	ui_text_scale: float,
	wrap_text_callable: Callable
) -> void:
	var state: String = str(snapshot.get("state", "none"))
	var hits: int = int(snapshot.get("hatch_hits", 0))
	var required_hits: int = max(1, int(snapshot.get("required_hits", hatch_required_hits)))
	var progress: float = clamp(float(hits) / float(required_hits), 0.0, 1.0)
	var compact: bool = content_rect.size.x < 260.0 or content_rect.size.y < 145.0
	var icon_size: float = clamp(min(content_rect.size.x * (0.36 if not compact else 0.28), content_rect.size.y * 0.54), 38.0, 82.0)
	var icon_rect: Rect2
	var text_x: float
	var text_y: float
	var text_w: float
	if compact:
		icon_rect = Rect2(content_rect.position.x + 10.0, content_rect.position.y + 10.0, icon_size, icon_size)
		text_x = icon_rect.end.x + 10.0
		text_y = content_rect.position.y + 23.0
		text_w = max(96.0, content_rect.end.x - text_x - 10.0)
	else:
		icon_rect = Rect2(content_rect.position.x + 16.0, content_rect.position.y + content_rect.size.y * 0.5 - icon_size * 0.5, icon_size, icon_size)
		text_x = icon_rect.end.x + 18.0
		text_y = content_rect.position.y + 36.0
		text_w = max(120.0, content_rect.end.x - text_x - 12.0)
	draw_egg_icon(canvas, icon_rect, state, progress, stat_buff_color, empty_text_color, ring_segments, ui_text_scale)

	var title: String = str(snapshot.get("title", "링펫 없음"))
	var subtitle: String = str(snapshot.get("subtitle", "미해금"))
	var body: String = str(snapshot.get("body", ""))
	_draw_text_xy(canvas, font, title, text_x, text_y, 15, Color.WHITE, ui_text_scale)
	_draw_text_xy(canvas, font, subtitle, text_x, text_y + 24.0, 12, accent_gold if state == "egg" else text_soft, ui_text_scale)
	var body_lines_value: Variant = wrap_text_callable.call(font, LanguageSettings.translate_text(body), 11, text_w, 4)
	var body_lines: Array = body_lines_value if body_lines_value is Array else []
	for i in range(body_lines.size()):
		_draw_text_xy(canvas, font, str(body_lines[i]), text_x, text_y + 48.0 + float(i) * 18.0, 11, empty_text_color, ui_text_scale)
	if state == "egg":
		var meter_rect := Rect2(text_x, min(content_rect.end.y - 24.0, text_y + 94.0), text_w, 8.0)
		canvas.draw_rect(meter_rect, Color(8.0 / 255.0, 12.0 / 255.0, 20.0 / 255.0, 0.96))
		canvas.draw_rect(Rect2(meter_rect.position, Vector2(meter_rect.size.x * clamp(progress, 0.0, 1.0), meter_rect.size.y)), Color(85.0 / 255.0, 218.0 / 255.0, 1.0, 0.82))
		canvas.draw_rect(meter_rect, Color(85.0 / 255.0, 218.0 / 255.0, 1.0, 0.85), false, 1.0)


static func draw_companion_panel(
	canvas: CanvasItem,
	font: Font,
	content_rect: Rect2,
	snapshot: Dictionary,
	mouse_pos: Vector2,
	hover_data: Dictionary,
	skill_icon_rects: Array,
	art_texture_cache: Dictionary,
	skill_icon_texture_cache: Dictionary,
	stat_buff_color: Color,
	empty_text_color: Color,
	accent_blue: Color,
	slot_fill: Color,
	ring_segments: int,
	ui_text_scale: float,
	panel_animation_time: float = 0.0
) -> Dictionary:
	var title: String = str(snapshot.get("title", "링펫"))
	var subtitle: String = str(snapshot.get("subtitle", "동행 중"))
	var pet_id := str(snapshot.get("pet_id", "")).strip_edges().to_lower()
	var skill_specs: Array = get_skill_specs(snapshot, stat_buff_color)
	var skill_row_h: float = clamp(content_rect.size.y * 0.22, 58.0, 78.0)
	var title_y: float = content_rect.position.y + 26.0
	_draw_centered_text(canvas, font, title, content_rect.get_center().x, title_y, 18, Color.WHITE, ui_text_scale)
	_draw_centered_text(canvas, font, subtitle, content_rect.get_center().x, title_y + 23.0, 12, stat_buff_color, ui_text_scale)

	var art_rect: Rect2 = companion_art_rect(content_rect, skill_row_h)
	canvas.draw_rect(art_rect, Color(7.0 / 255.0, 15.0 / 255.0, 25.0 / 255.0, 0.34))
	var art_glow_center := art_rect.get_center()
	var art_glow_radius: float = min(art_rect.size.x, art_rect.size.y) * 0.42
	for glow_index in range(4, 0, -1):
		canvas.draw_circle(art_glow_center, art_glow_radius + float(glow_index) * 11.0, Color(0.0, 205.0 / 255.0, 1.0, 0.018 * float(glow_index)))
	var art_texture: Texture2D = CharacterInfoOverlayLingpetTextureLoader.get_art_texture(str(snapshot.get("pet_id", "")), art_texture_cache)
	if art_texture != null:
		if CharacterInfoOverlayLingpetTextureLoader.uses_panel_live2d_art(pet_id):
			draw_panel_live2d_art(canvas, art_texture, art_rect.grow(-4.0), pet_id, panel_animation_time)
		else:
			CharacterInfoOverlayTextureDrawer.draw_contained(canvas, art_texture, art_rect.grow(-4.0), Color(1.0, 1.0, 1.0, 0.96))
	else:
		draw_egg_icon(canvas, Rect2(art_rect.get_center() - Vector2(44.0, 44.0), Vector2(88.0, 88.0)), "companion", 1.0, stat_buff_color, empty_text_color, ring_segments, ui_text_scale)

	var icon_count: int = max(1, skill_specs.size())
	var icon_gap: float = 9.0
	var icon_size: float = clamp((content_rect.size.x - 24.0 - icon_gap * float(icon_count - 1)) / float(icon_count), 38.0, 58.0)
	var icon_total_w: float = icon_size * float(icon_count) + icon_gap * float(icon_count - 1)
	var icon_x: float = content_rect.get_center().x - icon_total_w * 0.5
	var icon_y: float = content_rect.end.y - skill_row_h + (skill_row_h - icon_size) * 0.48
	for i in range(skill_specs.size()):
		var icon_rect := Rect2(icon_x + float(i) * (icon_size + icon_gap), icon_y, icon_size, icon_size)
		skill_icon_rects.append(icon_rect)
		var spec: Dictionary = skill_specs[i]
		hover_data = draw_skill_icon(canvas, font, icon_rect, spec, mouse_pos, hover_data, skill_icon_texture_cache, accent_blue, slot_fill, ring_segments, ui_text_scale)
	return hover_data


static func companion_art_rect(content_rect: Rect2, skill_row_h: float) -> Rect2:
	return Rect2(content_rect.position.x + 10.0, content_rect.position.y + 44.0, content_rect.size.x - 20.0, max(82.0, content_rect.size.y - skill_row_h - 54.0))


static func should_redraw_panel_live2d(snapshot: Dictionary) -> bool:
	if str(snapshot.get("state", "")) != "companion":
		return false
	return CharacterInfoOverlayLingpetTextureLoader.uses_panel_live2d_art(str(snapshot.get("pet_id", "")))


static func draw_panel_live2d_art(canvas: CanvasItem, texture: Texture2D, rect: Rect2, pet_id: String, panel_animation_time: float) -> void:
	var source := panel_live2d_source_rect(pet_id, texture.get_size(), panel_animation_time)
	if source.size.x <= 0.0 or source.size.y <= 0.0:
		CharacterInfoOverlayTextureDrawer.draw_contained(canvas, texture, rect, Color(1.0, 1.0, 1.0, 0.96))
		return
	CharacterInfoOverlayTextureDrawer.draw_contained_region(canvas, texture, rect, source, Color(1.0, 1.0, 1.0, 0.96))


static func panel_live2d_source_rect(pet_id: String, texture_size: Vector2, panel_animation_time: float) -> Rect2:
	if texture_size.x <= 1.0 or texture_size.y <= 1.0:
		return Rect2()
	var normalized_pet_id := pet_id.strip_edges().to_lower()
	var cols: int = max(1, int(PANEL_LIVE2D_COLS_BY_PET_ID.get(normalized_pet_id, 1)))
	var rows: int = max(1, int(PANEL_LIVE2D_ROWS_BY_PET_ID.get(normalized_pet_id, 1)))
	var max_frames: int = cols * rows
	var frame_count: int = clampi(int(PANEL_LIVE2D_FRAME_COUNT_BY_PET_ID.get(normalized_pet_id, max_frames)), 1, max_frames)
	var frame_interval: float = maxf(0.016, float(PANEL_LIVE2D_FRAME_INTERVAL_BY_PET_ID.get(normalized_pet_id, 0.0625)))
	var frame_index: int = int(floor(maxf(0.0, panel_animation_time) / frame_interval)) % frame_count
	var col: int = frame_index % cols
	var row: int = int(floor(float(frame_index) / float(cols)))
	var cell_size := Vector2(texture_size.x / float(cols), texture_size.y / float(rows))
	return Rect2(Vector2(float(col) * cell_size.x, float(row) * cell_size.y), cell_size)


static func draw_skill_icon(
	canvas: CanvasItem,
	font: Font,
	rect: Rect2,
	spec: Dictionary,
	mouse_pos: Vector2,
	hover_data: Dictionary,
	skill_icon_texture_cache: Dictionary,
	accent_blue: Color,
	slot_fill: Color,
	ring_segments: int,
	ui_text_scale: float
) -> Dictionary:
	var color: Color = _get_color(spec.get("color", accent_blue), accent_blue)
	var hovered: bool = rect.has_point(mouse_pos)
	var border_color: Color = Color(color.r, color.g, color.b, 1.0 if hovered else 0.72)
	canvas.draw_rect(rect, slot_fill)
	canvas.draw_rect(rect, border_color, false, 2.0 if hovered else 1.0)
	var inner := rect.grow(-4.0)
	var use_card: bool = bool(spec.get("use_card", false))
	var texture: Texture2D = CharacterInfoOverlayLingpetTextureLoader.get_skill_icon_texture(str(spec.get("card_texture_path" if use_card else "icon_texture_id", "")), skill_icon_texture_cache)
	if texture != null and use_card:
		CharacterInfoOverlayTextureDrawer.draw_cover(canvas, texture, inner, Color(1.0, 1.0, 1.0, 0.94))
	elif texture != null:
		CharacterInfoOverlayTextureDrawer.draw_contained(canvas, texture, inner, Color(1.0, 1.0, 1.0, 0.96))
	else:
		_draw_skill_symbol(canvas, font, inner, str(spec.get("id", "")), color, ring_segments, ui_text_scale)
	var badge: String = str(spec.get("badge", ""))
	if badge != "":
		var badge_rect := Rect2(rect.end.x - 22.0, rect.position.y + 3.0, 19.0, 14.0)
		canvas.draw_rect(badge_rect, Color(0.0, 0.0, 0.0, 0.58))
		canvas.draw_rect(badge_rect, Color(color.r, color.g, color.b, 0.88), false, 1.0)
		_draw_centered_text(canvas, font, badge, badge_rect.get_center().x, badge_rect.position.y + 11.0, 8, Color.WHITE, ui_text_scale)
	if hovered:
		_fill_hover_data(hover_data, str(spec.get("title", "")), str(spec.get("subtitle", "")), str(spec.get("body", "")), color, rect)
	return hover_data


static func _draw_skill_symbol(canvas: CanvasItem, font: Font, rect: Rect2, id: String, color: Color, ring_segments: int, ui_text_scale: float) -> void:
	var center := rect.get_center()
	var radius: float = min(rect.size.x, rect.size.y) * 0.36
	canvas.draw_circle(center, radius + 7.0, Color(color.r, color.g, color.b, 0.12))
	canvas.draw_circle(center, radius, Color(color.r, color.g, color.b, 0.26))
	canvas.draw_arc(center, radius, 0.0, TAU, ring_segments, color, 2.0)
	match id:
		"lingpet_afterglow_leak":
			canvas.draw_circle(center + Vector2(-radius * 0.18, radius * 0.10), radius * 0.42, Color(0.40, 1.0, 0.82, 0.42))
			canvas.draw_circle(center + Vector2(radius * 0.18, -radius * 0.08), radius * 0.30, Color(0.86, 1.0, 0.64, 0.34))
			canvas.draw_arc(center, radius * 0.66, -0.15, PI * 1.2, ring_segments, Color(1.0, 1.0, 0.82, 0.52), 1.4, true)
			canvas.draw_circle(center, radius * 0.16, Color(1.0, 1.0, 0.86, 0.88))
		"lingpet_tailwind_steps":
			var trail_color := Color(0.60, 1.0, 0.88, 0.58)
			for i in range(3):
				var y_offset: float = (float(i) - 1.0) * radius * 0.22
				canvas.draw_arc(center + Vector2(-radius * 0.08, y_offset), radius * (0.34 + float(i) * 0.10), PI * 0.06, PI * 0.86, ring_segments, trail_color, 1.3)
			var arrow_start := center + Vector2(-radius * 0.46, radius * 0.18)
			var arrow_end := center + Vector2(radius * 0.44, -radius * 0.18)
			canvas.draw_line(arrow_start, arrow_end, Color.WHITE, 2.0)
			canvas.draw_line(arrow_end, arrow_end + Vector2(-radius * 0.20, -radius * 0.02), Color.WHITE, 2.0)
			canvas.draw_line(arrow_end, arrow_end + Vector2(-radius * 0.08, radius * 0.18), Color.WHITE, 2.0)
		"lingpet_starlight_tracking":
			var star_points := PackedVector2Array()
			for i in range(10):
				var angle: float = -PI * 0.5 + TAU * float(i) / 10.0
				var point_radius: float = radius * (0.54 if i % 2 == 0 else 0.23)
				star_points.append(center + Vector2(cos(angle), sin(angle)) * point_radius)
			canvas.draw_colored_polygon(star_points, Color(1.0, 0.92, 0.45, 0.82))
			canvas.draw_arc(center + Vector2(-radius * 0.10, radius * 0.08), radius * 0.78, PI * 0.18, PI * 1.30, ring_segments, Color(0.65, 1.0, 1.0, 0.54), 1.6)
			canvas.draw_circle(center + Vector2(radius * 0.46, -radius * 0.34), radius * 0.10, Color.WHITE)
		"lingpet_ring_dash":
			var dash_color := Color(0.50, 0.92, 1.0, 0.62)
			for i in range(3):
				var trail_offset := Vector2(-radius * (0.52 + float(i) * 0.16), radius * (0.20 - float(i) * 0.14))
				canvas.draw_line(center + trail_offset, center + trail_offset + Vector2(radius * 0.46, -radius * 0.18), dash_color, 1.4)
			var shield_rect := Rect2(center - Vector2(radius * 0.16, radius * 0.42), Vector2(radius * 0.46, radius * 0.84))
			canvas.draw_rect(shield_rect, Color(1.0, 1.0, 1.0, 0.78), false, 2.0)
			canvas.draw_line(center + Vector2(-radius * 0.46, radius * 0.28), center + Vector2(radius * 0.42, -radius * 0.28), Color.WHITE, 2.2)
		"resonance_boost", "maribo_resonance_boost", "lingpet_resonance_boost":
			for i in range(3):
				var arc_radius: float = radius * (0.55 + float(i) * 0.18)
				canvas.draw_arc(center, arc_radius, -0.2 + float(i) * 0.42, PI + float(i) * 0.34, ring_segments, Color(1.0, 1.0, 1.0, 0.36), 1.2)
			canvas.draw_circle(center, radius * 0.22, Color(1.0, 1.0, 1.0, 0.86))
			_draw_centered_text(canvas, font, "+", center.x, center.y + radius * 0.18, int(radius * 0.95), Color.WHITE, ui_text_scale)
		_:
			_draw_fallback_symbol(canvas, rect, color, id, ring_segments, ui_text_scale)


static func _draw_fallback_symbol(canvas: CanvasItem, rect: Rect2, color: Color, id_text: String, ring_segments: int, ui_text_scale: float) -> void:
	var center := rect.get_center()
	var radius: float = min(rect.size.x, rect.size.y) * 0.38
	canvas.draw_circle(center, radius, Color(color.r, color.g, color.b, 0.32))
	canvas.draw_arc(center, radius, 0.0, TAU, ring_segments, color, 2.0)
	_draw_centered_text(canvas, ThemeDB.fallback_font, _fallback_symbol_letter(id_text), center.x, center.y + 3.0, int(radius * 1.2), Color.WHITE, ui_text_scale)


static func _fill_hover_data(data: Dictionary, title: String, subtitle: String, body: String, color: Color, anchor_rect: Rect2) -> void:
	data.clear()
	data["title"] = title
	data["subtitle"] = subtitle
	data["body"] = body
	data["color"] = color
	data["anchor_rect"] = anchor_rect


static func _get_color(value: Variant, fallback: Color) -> Color:
	return value if value is Color else fallback


static func _fallback_symbol_letter(id_text: String) -> String:
	return "?" if id_text == "" else id_text.substr(0, 1).to_upper()


static func _draw_centered_fallback_text(canvas: CanvasItem, text: String, center_x: float, center_y: float, size: int, color: Color, ui_text_scale: float) -> void:
	_draw_centered_text(canvas, ThemeDB.fallback_font, text, center_x, center_y, size, color, ui_text_scale)


static func _draw_centered_text(canvas: CanvasItem, font: Font, text: String, center_x: float, center_y: float, size: int, color: Color, ui_text_scale: float) -> void:
	if text == "":
		return
	if font == null:
		return
	var visible_text := LanguageSettings.translate_text(text)
	var ui_size: int = max(1, int(round(float(size) * ui_text_scale)))
	var text_size: Vector2 = font.get_string_size(visible_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, ui_size)
	canvas.draw_string(font, Vector2(center_x - text_size.x * 0.5, center_y + text_size.y * 0.34), visible_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, ui_size, color)


static func _draw_text_xy(canvas: CanvasItem, font: Font, text: String, baseline_x: float, baseline_y: float, size: int, color: Color, ui_text_scale: float) -> void:
	if text == "":
		return
	if font == null:
		return
	canvas.draw_string(font, Vector2(baseline_x, baseline_y), LanguageSettings.translate_text(text), HORIZONTAL_ALIGNMENT_LEFT, -1.0, max(1, int(round(float(size) * ui_text_scale))), color)


static func get_display_name(lingpet_id: String) -> String:
	if LingpetCatalog.has_pet(lingpet_id):
		return LingpetCatalog.get_display_name(lingpet_id)
	match lingpet_id:
		"maribo":
			return "마리보"
		"":
			return "링펫"
		_:
			return lingpet_id


static func get_skill_specs(snapshot: Dictionary, stat_buff_color: Color) -> Array:
	var specs: Array = []
	var skill_id: String = str(snapshot.get("companion_skill_id", "")).strip_edges()
	if skill_id != "":
		var skill_name: String = str(snapshot.get("companion_skill_name", "")).strip_edges()
		if skill_name == "":
			skill_name = "액티브 스킬"
		var active_cooldown: float = float(snapshot.get("companion_skill_cooldown_duration", 0.0))
		var skill_description: String = str(snapshot.get("companion_skill_description", "")).strip_edges()
		if skill_description == "":
			skill_description = "링펫이 전투 중 자동으로 사용하는 액티브 스킬입니다."
		var icon_texture_id := str(snapshot.get("companion_skill_icon_path", "")).strip_edges()
		var skill_level: int = int(snapshot.get("companion_skill_level", 0))
		var active_level_label := "Lv.%d · " % skill_level if skill_level > 0 else ""
		specs.append({
			"id": skill_id,
			"title": skill_name,
			"subtitle": "액티브 · " + active_level_label + "쿨타임 " + CharacterInfoOverlayFormatter.format_seconds_text(active_cooldown),
			"body": skill_description,
			"color": Color(80.0 / 255.0, 220.0 / 255.0, 1.0),
			"badge": "A",
			"use_card": icon_texture_id == "",
			"icon_texture_id": icon_texture_id,
			"card_texture_path": str(snapshot.get("companion_skill_card_path", "")),
		})
	var gauge_bonus_pct: float = float(snapshot.get("gauge_gain_bonus_pct", 0.0))
	var player_speed_bonus_pct: float = float(snapshot.get("companion_player_speed_bonus_pct", 0.0))
	var starpoint_tracking_chance_pct: float = float(snapshot.get("companion_starpoint_tracking_chance_pct", 0.0))
	var ring_dash_chance_pct: float = float(snapshot.get("companion_ring_dash_chance_pct", 0.0))
	var passive_id: String = str(snapshot.get("companion_passive_skill_id", "")).strip_edges()
	if passive_id != "":
		var passive_name: String = str(snapshot.get("companion_passive_skill_name", "")).strip_edges()
		if passive_name == "":
			passive_name = "패시브 스킬"
		var passive_description: String = str(snapshot.get("companion_passive_skill_description", "")).strip_edges()
		if passive_description == "":
			passive_description = "링펫에게 배정된 패시브 스킬입니다."
		var passive_subtitle := "패시브"
		var passive_level: int = int(snapshot.get("companion_passive_skill_level", 0))
		if passive_level > 0:
			passive_subtitle += " · Lv.%d" % passive_level
		if gauge_bonus_pct > 0.0:
			passive_subtitle += " · 받아치기 +" + CharacterInfoOverlayFormatter.format_percent_text(gauge_bonus_pct)
		if player_speed_bonus_pct > 0.0:
			passive_subtitle += " · 이동 +" + CharacterInfoOverlayFormatter.format_percent_text(player_speed_bonus_pct)
		if starpoint_tracking_chance_pct > 0.0:
			passive_subtitle += " · 추적 " + CharacterInfoOverlayFormatter.format_percent_text(starpoint_tracking_chance_pct)
		if ring_dash_chance_pct > 0.0:
			passive_subtitle += " · 전이 " + CharacterInfoOverlayFormatter.format_percent_text(ring_dash_chance_pct)
		specs.append({
			"id": passive_id,
			"title": passive_name,
			"subtitle": passive_subtitle,
			"body": passive_description,
			"color": stat_buff_color,
			"badge": "P",
			"icon_texture_id": str(snapshot.get("companion_passive_skill_icon_path", snapshot.get("gauge_gain_bonus_icon_path", ""))),
		})
	elif gauge_bonus_pct > 0.0:
		var fallback_passive: Dictionary = LingpetCatalog.get_passive_skill(str(snapshot.get("pet_id", "")))
		var fallback_passive_id := str(fallback_passive.get("id", "")).strip_edges()
		var fallback_passive_title := str(fallback_passive.get("name", "")).strip_edges()
		var fallback_passive_description := str(fallback_passive.get("description", "")).strip_edges()
		var fallback_icon_texture_id := str(snapshot.get("gauge_gain_bonus_icon_path", "")).strip_edges()
		if fallback_icon_texture_id == "":
			fallback_icon_texture_id = str(fallback_passive.get("icon_texture_path", "")).strip_edges()
		if fallback_passive_id == "":
			fallback_passive_id = "lingpet_resonance_boost"
		if fallback_passive_title == "":
			fallback_passive_title = "공명 증폭"
		if fallback_passive_description == "":
			fallback_passive_description = "플레이어가 공을 받아칠 때 게이지 획득량이 증가합니다."
		specs.append({
			"id": fallback_passive_id,
			"title": fallback_passive_title,
			"subtitle": "패시브 · 받아치기 +" + CharacterInfoOverlayFormatter.format_percent_text(gauge_bonus_pct),
			"body": fallback_passive_description,
			"color": stat_buff_color,
			"badge": "P",
			"icon_texture_id": fallback_icon_texture_id,
		})
	return specs


static func build_panel_snapshot(owner: Object, safe_owner_get: Callable, hatch_required_hits: int) -> Dictionary:
	return CharacterInfoOverlayLingpetSnapshotBuilder.build_panel_snapshot(owner, safe_owner_get, hatch_required_hits)

static func build_stats(
	snapshot: Dictionary,
	accent_gold: Color,
	text_soft: Color,
	empty_text_color: Color,
	stat_buff_color: Color,
	speed_display_px_per_point: float,
	hatch_required_hits: int,
	defense_rate_tooltip: String
) -> Array:
	var state: String = str(snapshot.get("state", "none"))
	if state == "egg":
		var hits: int = int(snapshot.get("hatch_hits", 0))
		var required_hits: int = max(1, int(snapshot.get("required_hits", hatch_required_hits)))
		return [
			make_display_stat_row("상태", "알", accent_gold),
			make_display_stat_row("부화 진행", CharacterInfoOverlayFormatter.format_int_pair(hits, required_hits), text_soft),
		]
	if state != "companion":
		return [
			make_display_stat_row("상태", "미획득", empty_text_color),
		]
	var speed_default: float = float(snapshot.get("companion_patrol_speed_default", 120.0))
	var speed_min: float = float(snapshot.get("companion_patrol_speed_min", 70.0))
	var speed_max: float = float(snapshot.get("companion_patrol_speed_max", 135.0))
	var catch_width: float = float(snapshot.get("companion_catch_width", 100.0))
	var catch_height: float = float(snapshot.get("companion_catch_height", 44.0))
	var hit_gain: float = float(snapshot.get("companion_hit_gauge_gain", 40.0))
	var skill_id: String = str(snapshot.get("companion_skill_id", "")).strip_edges()
	var skill_name: String = str(snapshot.get("companion_skill_name", "")).strip_edges()
	if skill_name == "":
		skill_name = "액티브 스킬"
	var active_cooldown: float = float(snapshot.get("companion_skill_cooldown_duration", 40.0))
	var defense_rate: float = float(snapshot.get("companion_defense_rate", 0.0))
	var speed_display: float = speed_default / speed_display_px_per_point
	var rows := [
		make_display_stat_row("이동 속도", "%.2f" % speed_display, Color.WHITE, "마리보가 플레이어 진영에서 독자적으로 순찰할 때 쓰는 기본 이동 속도입니다. 실제 순찰은 %s~%spx/s 사이에서 자연스럽게 변동됩니다." % [CharacterInfoOverlayFormatter.format_plain_number(speed_min), CharacterInfoOverlayFormatter.format_plain_number(speed_max)]),
		make_display_stat_row("몸집크기", "%sx%spx" % [CharacterInfoOverlayFormatter.format_plain_number(catch_width), CharacterInfoOverlayFormatter.format_plain_number(catch_height)], Color.WHITE, "마리보가 공을 튕겨낼 때 쓰는 실제 판정 범위입니다."),
		make_display_stat_row("게이지 획득량", "%spt" % CharacterInfoOverlayFormatter.format_plain_number(hit_gain), stat_buff_color, "링펫이 공을 직접 튕겼을 때 얻는 공통 기본 게이지 획득량입니다."),
		make_display_stat_row("방어율", CharacterInfoOverlayFormatter.format_percent_text(defense_rate * 100.0), stat_buff_color, defense_rate_tooltip),
	]
	if skill_id != "":
		rows.insert(3, make_display_stat_row("액티브 쿨타임", CharacterInfoOverlayFormatter.format_seconds_text(active_cooldown), Color.WHITE, "%s을(를) 다시 사용할 수 있게 되는 시간입니다." % skill_name))
	return rows


static func build_stats_cached(
	snapshot: Dictionary,
	cache: Dictionary,
	accent_gold: Color,
	text_soft: Color,
	empty_text_color: Color,
	stat_buff_color: Color,
	speed_display_px_per_point: float,
	hatch_required_hits: int,
	defense_rate_tooltip: String
) -> Dictionary:
	var cache_hash: int = get_stats_cache_hash(snapshot, hatch_required_hits)
	if bool(cache.get("ready", false)) and int(cache.get("hash", 0)) == cache_hash:
		return cache
	return {
		"ready": true,
		"hash": cache_hash,
		"rows": build_stats(snapshot, accent_gold, text_soft, empty_text_color, stat_buff_color, speed_display_px_per_point, hatch_required_hits, defense_rate_tooltip).duplicate(true),
	}


static func get_stats_cache_hash(snapshot: Dictionary, hatch_required_hits: int) -> int:
	var state: String = str(snapshot.get("state", "none"))
	if state == "egg":
		return hash([
			LanguageSettings.get_language(),
			state,
			int(snapshot.get("hatch_hits", 0)),
			int(snapshot.get("required_hits", hatch_required_hits)),
		])
	if state != "companion":
		return hash([LanguageSettings.get_language(), state])
	return hash([
		LanguageSettings.get_language(),
		state,
		float(snapshot.get("companion_patrol_speed_default", 120.0)),
		float(snapshot.get("companion_patrol_speed_min", 70.0)),
		float(snapshot.get("companion_patrol_speed_max", 135.0)),
		float(snapshot.get("companion_catch_width", 100.0)),
		float(snapshot.get("companion_catch_height", 44.0)),
		float(snapshot.get("companion_hit_gauge_gain", 40.0)),
		str(snapshot.get("companion_skill_id", "")).strip_edges(),
		str(snapshot.get("companion_skill_name", "")).strip_edges(),
		float(snapshot.get("companion_skill_cooldown_duration", 40.0)),
		float(snapshot.get("companion_defense_rate", 0.0)),
	])


static func make_display_stat_row(label: String, value_text: String, color: Color, tooltip_body: String = "") -> Dictionary:
	var row := {
		"label": LanguageSettings.translate_text(label),
		"value": LanguageSettings.translate_text(value_text),
		"color": color,
	}
	if tooltip_body != "":
		row["tooltip_title"] = LanguageSettings.translate_text(label)
		row["tooltip_subtitle"] = LanguageSettings.translate_text(value_text)
		row["tooltip_body"] = LanguageSettings.translate_text(tooltip_body)
	return row
