extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PauseMenuOverlayLayout := preload("res://scripts/hud/pause_menu_overlay_layout.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const MAIN_EDITORIAL_BG_PATH := "res://assets/ui/pause_menu/pause_system_editorial_map_bg_cyberpunk_v2.png"
const MAIN_DIAL_ROTATIONS_PER_SECOND := 0.075
const MAIN_SELECTED_BAR_SKEW := 34.0
const OPEN_BG_FADE_SECONDS := 0.15
const OPEN_CHROME_FADE_SECONDS := 0.20
const OPEN_BAR_SWEEP_SECONDS := 0.20
const OPEN_TEXT_FADE_DELAY_SECONDS := 0.08
const OPEN_TEXT_FADE_SECONDS := 0.14
const OPEN_ITEM_STAGGER_SECONDS := 0.045
const OPEN_ITEM_SLIDE_X := 34.0

const PAPER_BG := Color(0.04, 0.055, 0.09)
const INK := Color(0.85, 0.92, 1.0)
const SELECT_BLUE := Color(0.36, 0.78, 0.98)
const SELECT_SUBINK := Color(0.04, 0.10, 0.16)
const GRAPHIC_INK := Color(0.02, 0.03, 0.05)
const TITLE_ON_GRAPHIC_INK := Color(0.82, 0.93, 1.0)
const DIAMOND_GRAY := Color(0.40, 0.66, 0.86)
const SPINE_LINE := Color(0.36, 0.78, 0.98, 0.22)

var background_texture: Texture2D = null


func prewarm_assets() -> void:
	if background_texture != null:
		return
	background_texture = ProjectResourceLoader.load_texture(
		MAIN_EDITORIAL_BG_PATH,
		"Pause menu editorial background texture is missing",
		"Pause menu editorial background texture failed to load"
	)


func clear_assets() -> void:
	background_texture = null


func draw_menu(
	canvas: CanvasItem,
	font: Font,
	tech_font: Font,
	panel_rect: Rect2,
	mouse_pos: Vector2,
	entries: Array,
	selected_index: int,
	selection_rect: Rect2,
	animation_time: float,
	main_dial_time: float,
	pop_projection: Dictionary
) -> void:
	var chrome_alpha := get_open_chrome_alpha(animation_time)
	draw_editorial_background(canvas, panel_rect, main_dial_time, get_open_bg_alpha(animation_time), chrome_alpha)
	draw_editorial_header(canvas, tech_font, panel_rect, chrome_alpha)
	draw_editorial_spine(canvas, panel_rect, entries.size(), chrome_alpha)
	if entries.is_empty():
		return
	draw_selected_bar(
		canvas,
		font,
		tech_font,
		selection_rect,
		entries[clampi(selected_index, 0, entries.size() - 1)],
		get_main_open_bar_ratio(animation_time),
		get_open_text_alpha(animation_time),
		pop_projection
	)
	for index in range(entries.size()):
		if index != selected_index:
			draw_unselected_entry(
				canvas,
				tech_font,
				panel_rect,
				entries[index],
				index,
				entries.size(),
				mouse_pos,
				get_main_open_entry_ratio(animation_time, index)
			)


func draw_editorial_background(
	canvas: CanvasItem,
	panel_rect: Rect2,
	main_dial_time: float,
	base_alpha: float = 1.0,
	chrome_alpha: float = 1.0
) -> void:
	draw_editorial_base(canvas, panel_rect, base_alpha)
	var top_left := panel_rect.position
	var wedge_width := minf(panel_rect.size.x * 0.42, 520.0)
	var wedge_height := minf(panel_rect.size.y * 0.42, 315.0)
	canvas.draw_colored_polygon(
		PackedVector2Array([
			top_left,
			top_left + Vector2(wedge_width, 0.0),
			top_left + Vector2(wedge_width * 0.50, wedge_height * 0.20),
			top_left + Vector2(wedge_width * 0.23, wedge_height),
			top_left + Vector2(0.0, wedge_height * 0.93),
		]),
		_with_alpha(GRAPHIC_INK, chrome_alpha)
	)
	var line_color := _with_alpha(Color(1.0, 1.0, 1.0, 0.62), chrome_alpha)
	canvas.draw_arc(top_left + Vector2(98.0, 68.0), 54.0, 0.16 * PI, 1.08 * PI, 28, line_color, 1.4, true)
	canvas.draw_line(top_left + Vector2(138.0, 118.0), top_left + Vector2(238.0, 42.0), _with_alpha(Color(1.0, 1.0, 1.0, 0.36), chrome_alpha), 1.2, true)
	draw_editorial_dial(canvas, panel_rect, main_dial_time, chrome_alpha)
	draw_sparkle(canvas, panel_rect.position + Vector2(panel_rect.size.x - 92.0, panel_rect.size.y - 82.0), 9.0, _with_alpha(Color(SELECT_BLUE.r, SELECT_BLUE.g, SELECT_BLUE.b, 0.32), chrome_alpha))
	draw_sparkle(canvas, panel_rect.position + Vector2(panel_rect.size.x - 168.0, 54.0), 6.0, _with_alpha(Color(SELECT_BLUE.r, SELECT_BLUE.g, SELECT_BLUE.b, 0.24), chrome_alpha))


func draw_editorial_base(canvas: CanvasItem, panel_rect: Rect2, alpha: float = 1.0) -> void:
	var draw_alpha := clampf(alpha, 0.0, 1.0)
	if background_texture == null:
		prewarm_assets()
	if background_texture != null:
		canvas.draw_texture_rect(background_texture, panel_rect, false, Color(1.0, 1.0, 1.0, draw_alpha))
		return
	canvas.draw_rect(panel_rect, _with_alpha(PAPER_BG, draw_alpha))
	draw_map_texture(canvas, panel_rect, draw_alpha)


func draw_map_texture(canvas: CanvasItem, panel_rect: Rect2, alpha: float = 1.0) -> void:
	var map_color := Color(0.36, 0.78, 0.98, 0.05 * clampf(alpha, 0.0, 1.0))
	var street_color := Color(0.36, 0.78, 0.98, 0.07 * clampf(alpha, 0.0, 1.0))
	var origin := panel_rect.position
	for i in range(5):
		var x := origin.x + panel_rect.size.x * (0.36 + float(i) * 0.105)
		canvas.draw_line(
			Vector2(x, origin.y + panel_rect.size.y * 0.08),
			Vector2(x + panel_rect.size.x * 0.08, panel_rect.end.y - panel_rect.size.y * 0.10),
			map_color,
			1.0,
			true
		)
	for i in range(4):
		var y := origin.y + panel_rect.size.y * (0.22 + float(i) * 0.15)
		canvas.draw_line(
			Vector2(origin.x + panel_rect.size.x * 0.28, y),
			Vector2(panel_rect.end.x - panel_rect.size.x * 0.10, y - panel_rect.size.y * 0.05),
			map_color,
			1.0,
			true
		)
	var block_origin := origin + Vector2(panel_rect.size.x * 0.63, panel_rect.size.y * 0.31)
	for i in range(3):
		var block := Rect2(block_origin + Vector2(float(i) * 42.0, float(i % 2) * 28.0), Vector2(30.0, 20.0))
		canvas.draw_rect(block, map_color, false, 1.0, true)
		canvas.draw_line(block.position, block.end, street_color, 1.0, true)


func draw_editorial_header(canvas: CanvasItem, tech_font: Font, panel_rect: Rect2, alpha: float = 1.0) -> void:
	var title_size := PauseMenuOverlayLayout.get_main_title_font_size(panel_rect)
	var title_pos := panel_rect.position + Vector2(PauseMenuOverlayLayout.get_main_title_left_margin(panel_rect), maxf(54.0, panel_rect.size.y * 0.115))
	canvas.draw_string(tech_font, title_pos, "SYSTEM", HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_size, _with_alpha(TITLE_ON_GRAPHIC_INK, alpha))


func draw_editorial_spine(canvas: CanvasItem, panel_rect: Rect2, entry_count: int, alpha: float = 1.0) -> void:
	if entry_count <= 0:
		return
	var x := PauseMenuOverlayLayout.get_main_diamond_center_x(panel_rect)
	var first_rect := PauseMenuOverlayLayout.get_main_row_band_rect(panel_rect, 0, entry_count)
	var last_rect := PauseMenuOverlayLayout.get_main_row_band_rect(panel_rect, entry_count - 1, entry_count)
	canvas.draw_line(
		Vector2(x, first_rect.get_center().y),
		Vector2(x, last_rect.get_center().y),
		_with_alpha(SPINE_LINE, alpha),
		1.4,
		true
	)


func draw_editorial_dial(canvas: CanvasItem, panel_rect: Rect2, main_dial_time: float, alpha: float = 1.0) -> void:
	var center := panel_rect.position + Vector2(panel_rect.size.x - minf(88.0, panel_rect.size.x * 0.09), maxf(52.0, panel_rect.size.y * 0.10))
	var radius := clampf(minf(panel_rect.size.x, panel_rect.size.y) * 0.105, 46.0, 84.0)
	var ring_radius := radius * 0.74
	canvas.draw_arc(center, ring_radius, 0.0, TAU, 72, _with_alpha(Color(INK.r, INK.g, INK.b, 0.55), alpha), 1.6, true)
	canvas.draw_arc(center, radius * 1.52, 0.30 * PI, 1.04 * PI, 48, _with_alpha(Color(SELECT_BLUE.r, SELECT_BLUE.g, SELECT_BLUE.b, 0.30), alpha), 1.2, true)
	var base_angle := fposmod(-0.92 * PI + main_dial_time * MAIN_DIAL_ROTATIONS_PER_SECOND * TAU, TAU)
	var star_color := _with_alpha(Color(INK.r, INK.g, INK.b, 0.96), alpha)
	var star_blades := [
		{"reach": 2.10, "width": 0.125},
		{"reach": 1.02, "width": 0.20},
		{"reach": 1.46, "width": 0.16},
		{"reach": 0.80, "width": 0.22},
	]
	for i in range(star_blades.size()):
		var blade: Dictionary = star_blades[i]
		var dir := Vector2(cos(base_angle + float(i) * PI * 0.5), sin(base_angle + float(i) * PI * 0.5))
		var perp := dir.rotated(PI * 0.5)
		var tip := center + dir * radius * float(blade["reach"])
		var half_width := radius * float(blade["width"])
		var blade_base := center - dir * radius * 0.10
		canvas.draw_colored_polygon(
			PackedVector2Array([tip, blade_base + perp * half_width, blade_base - perp * half_width]),
			star_color
		)
	var dot_angle := base_angle + PI * 0.72
	var dot_pos := center + Vector2(cos(dot_angle), sin(dot_angle)) * ring_radius
	canvas.draw_circle(dot_pos, maxf(3.2, radius * 0.062), star_color)


func draw_selected_bar(
	canvas: CanvasItem,
	font: Font,
	tech_font: Font,
	selection_rect: Rect2,
	entry: Dictionary,
	open_ratio: float = 1.0,
	text_alpha: float = 1.0,
	pop_projection: Dictionary = {}
) -> void:
	if not _has_feedback_rect(selection_rect):
		return
	var final_bar_rect := PauseMenuOverlayLayout.get_main_selection_bar_rect(selection_rect)
	var bar_rect := final_bar_rect
	bar_rect.size.x = maxf(1.0, final_bar_rect.size.x * clampf(open_ratio, 0.0, 1.0))
	var pop_amount: float = float(pop_projection.get("pop_amount", 0.0))
	var flash_alpha: float = float(pop_projection.get("flash_alpha", 0.0))
	if pop_amount > 0.0:
		var height_extra := bar_rect.size.y * pop_amount
		bar_rect.position.y -= height_extra * 0.5
		bar_rect.size.y += height_extra
		bar_rect.size.x *= 1.0 + pop_amount
	var skew := clampf(bar_rect.size.y * 0.42, 22.0, MAIN_SELECTED_BAR_SKEW)
	var bar_points := PackedVector2Array([
		Vector2(bar_rect.position.x - skew, bar_rect.position.y),
		Vector2(bar_rect.end.x - skew * 0.18, bar_rect.position.y),
		Vector2(bar_rect.end.x + skew, bar_rect.end.y),
		Vector2(bar_rect.position.x + skew * 0.22, bar_rect.end.y),
	])
	canvas.draw_colored_polygon(bar_points, SELECT_BLUE)
	var outline := PackedVector2Array(bar_points)
	outline.append(bar_points[0])
	canvas.draw_polyline(outline, Color(1.0, 1.0, 1.0, 0.24), 1.2, true)
	if flash_alpha > 0.0:
		canvas.draw_colored_polygon(bar_points, Color(1.0, 1.0, 1.0, flash_alpha))
	var en_text := str(entry.get("en", ""))
	var en_size := PauseMenuOverlayLayout.get_main_entry_selected_font_size(bar_rect)
	var en_text_size := tech_font.get_string_size(en_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, en_size)
	var local_text := get_selected_local_text(entry)
	var local_font := _get_text_draw_font(font, local_text)
	var local_size := PauseMenuOverlayLayout.get_main_entry_local_font_size(final_bar_rect)
	var local_text_size := local_font.get_string_size(local_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, local_size) if not local_text.is_empty() else Vector2.ZERO
	var local_x := PauseMenuOverlayLayout.get_main_selected_local_x(final_bar_rect, local_text_size.x) if not local_text.is_empty() else -1.0
	var en_x := PauseMenuOverlayLayout.get_main_selected_en_x(final_bar_rect, en_text_size.x, local_x)
	var en_pos := Vector2(en_x, final_bar_rect.get_center().y + float(en_size) * 0.36)
	var draw_text_alpha := clampf(text_alpha, 0.0, 1.0)
	canvas.draw_string(tech_font, en_pos, en_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, en_size, _with_alpha(Color.WHITE, draw_text_alpha))
	if not local_text.is_empty():
		if local_x > en_pos.x + en_text_size.x + 20.0 and local_x + local_text_size.x <= bar_rect.end.x - 24.0:
			canvas.draw_string(local_font, Vector2(local_x, final_bar_rect.get_center().y + float(local_size) * 0.35), local_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, local_size, _with_alpha(SELECT_SUBINK, draw_text_alpha))


func draw_unselected_entry(
	canvas: CanvasItem,
	tech_font: Font,
	panel_rect: Rect2,
	entry: Dictionary,
	index: int,
	entry_count: int,
	mouse_pos: Vector2,
	open_ratio: float = 1.0
) -> void:
	var band_rect := PauseMenuOverlayLayout.get_main_row_band_rect(panel_rect, index, entry_count)
	var center_y := band_rect.get_center().y
	var hovered := band_rect.has_point(mouse_pos)
	var eased_open := ease_out_cubic(open_ratio)
	var x_offset := -OPEN_ITEM_SLIDE_X * (1.0 - eased_open)
	var diamond_color := Color(DIAMOND_GRAY.r, DIAMOND_GRAY.g, DIAMOND_GRAY.b, 0.95 if hovered else 0.74)
	draw_sparkle(canvas, Vector2(PauseMenuOverlayLayout.get_main_diamond_center_x(panel_rect) + x_offset, center_y), 7.0 if hovered else 6.0, _with_alpha(diamond_color, open_ratio))
	var en_text := str(entry.get("en", ""))
	var en_size := PauseMenuOverlayLayout.get_main_entry_idle_font_size(panel_rect)
	var color := INK if hovered else Color(INK.r, INK.g, INK.b, 0.78 - float(index) * 0.08)
	canvas.draw_string(tech_font, Vector2(PauseMenuOverlayLayout.get_main_unselected_text_x(panel_rect) + x_offset, center_y + float(en_size) * 0.34), en_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, en_size, _with_alpha(color, open_ratio))


func draw_sparkle(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	canvas.draw_colored_polygon(
		PackedVector2Array([
			center + Vector2(0.0, -radius),
			center + Vector2(radius * 0.56, 0.0),
			center + Vector2(0.0, radius),
			center + Vector2(-radius * 0.56, 0.0),
		]),
		color
	)


func should_show_local_label() -> bool:
	return LanguageSettings.get_language() != LanguageSettings.LANGUAGE_ENGLISH


func get_selected_local_text(entry: Dictionary) -> String:
	if not should_show_local_label():
		return ""
	return str(entry.get("desc", entry.get("label", "")))


static func get_open_ratio(animation_time: float, duration: float, delay: float = 0.0) -> float:
	return clampf((animation_time - delay) / maxf(duration, 0.001), 0.0, 1.0)


static func get_open_bg_alpha(animation_time: float) -> float:
	return ease_out_cubic(get_open_ratio(animation_time, OPEN_BG_FADE_SECONDS))


static func get_open_chrome_alpha(animation_time: float) -> float:
	return ease_out_cubic(get_open_ratio(animation_time, OPEN_CHROME_FADE_SECONDS))


static func get_open_text_alpha(animation_time: float) -> float:
	return ease_out_cubic(get_open_ratio(animation_time, OPEN_TEXT_FADE_SECONDS, OPEN_TEXT_FADE_DELAY_SECONDS))


static func get_main_open_bar_ratio(animation_time: float) -> float:
	return clampf(ease_out_back(get_open_ratio(animation_time, OPEN_BAR_SWEEP_SECONDS)), 0.0, 1.0)


static func get_main_open_entry_ratio(animation_time: float, index: int) -> float:
	return ease_out_cubic(get_open_ratio(animation_time, OPEN_ITEM_STAGGER_SECONDS * 4.0, OPEN_TEXT_FADE_DELAY_SECONDS + float(index) * OPEN_ITEM_STAGGER_SECONDS))


static func ease_out_back(value: float) -> float:
	var clamped_value := clampf(value, 0.0, 1.0)
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(clamped_value - 1.0, 3.0) + c1 * pow(clamped_value - 1.0, 2.0)


static func ease_out_cubic(value: float) -> float:
	var clamped_value := clampf(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - clamped_value, 3.0)


func _get_text_draw_font(font: Font, text: String) -> Font:
	if font != null and not _needs_cjk_fallback_font(text):
		return font
	return ThemeDB.fallback_font if ThemeDB.fallback_font != null else font


func _needs_cjk_fallback_font(text: String) -> bool:
	for index in range(text.length()):
		var codepoint := text.unicode_at(index)
		if (
			(codepoint >= 0x3000 and codepoint <= 0x30FF)
			or (codepoint >= 0x3400 and codepoint <= 0x9FFF)
			or (codepoint >= 0xF900 and codepoint <= 0xFAFF)
			or (codepoint >= 0xFF66 and codepoint <= 0xFF9F)
		):
			return true
	return false


func _has_feedback_rect(rect: Rect2) -> bool:
	return rect.size.x > 1.0 and rect.size.y > 1.0


func _with_alpha(color: Color, alpha_scale: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * clampf(alpha_scale, 0.0, 1.0))
