extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const DefeatContinueVisualProjection := preload("res://scripts/core/defeat_continue_visual_projection.gd")
const TITLE_FONT: Font = preload("res://assets/fonts/NanumSquareB.ttf")

const HWANGYEOKJEON_CHROME_BASE := "res://assets/ui/character_select_chrome/hwangyeokjeon/"
const HANJI_BAND_TEXTURE_PATH := HWANGYEOKJEON_CHROME_BASE + "hanji_name_band_9p.png"
const SELECT_BUTTON_TEXTURE_PATH := HWANGYEOKJEON_CHROME_BASE + "select_button_9p.png"
const HANJI_BAND_SLICE := Vector4(156.0, 76.0, 156.0, 76.0)
const SELECT_BUTTON_SLICE := Vector4(98.0, 68.0, 98.0, 68.0)

enum StatusMode {
	PRESENT,
	SHAKING,
	CONSUMED,
}


static func resolve_status_mode(is_present: bool, shatter_window_active: bool, shatter_completed: bool) -> int:
	if is_present:
		return StatusMode.PRESENT
	if shatter_window_active or shatter_completed:
		return StatusMode.CONSUMED
	return StatusMode.SHAKING


static func draw_header_and_status(
	canvas: CanvasItem,
	view_size: Vector2,
	pulse: float,
	accent: Color,
	status_mode: int
) -> void:
	if canvas == null:
		return
	var font := ThemeDB.fallback_font
	var center_x := view_size.x * 0.5
	_draw_broken_ward_sigil(
		canvas,
		Vector2(center_x, DefeatContinueVisualProjection.scaled_y(view_size, 62.0)),
		accent,
		pulse
	)
	_draw_cloud_title_rule(
		canvas,
		center_x,
		DefeatContinueVisualProjection.scaled_y(view_size, 115.0),
		minf(view_size.x * 0.33, 360.0),
		accent
	)
	_draw_centered_text(
		canvas,
		TITLE_FONT,
		"패배",
		Vector2(center_x, DefeatContinueVisualProjection.scaled_y(view_size, 120.0)),
		DefeatContinueVisualProjection.scaled_font(view_size, 42),
		Color(0.92, 0.88, 0.76, 0.98)
	)
	_draw_centered_text(
		canvas,
		font,
		"아쉽지만 다음 기회를 노려보세요.",
		Vector2(center_x, DefeatContinueVisualProjection.scaled_y(view_size, 174.0)),
		DefeatContinueVisualProjection.scaled_font(view_size, 18),
		Color(0.58, 0.69, 0.63, 0.92)
	)
	_draw_status_hanji_band(canvas, view_size, center_x)
	_draw_continue_status_text(canvas, font, view_size, center_x, status_mode)


static func draw_footer(
	canvas: CanvasItem,
	view_size: Vector2,
	visual_remaining_gems: int,
	show_confirm_button: bool,
	pulse: float,
	accent: Color,
	gold: Color
) -> void:
	if canvas == null:
		return
	var font := ThemeDB.fallback_font
	var center_x := view_size.x * 0.5
	var line_one := "기회의 보석은 패배 시 1개가 소모됩니다."
	var line_two := "모든 보석이 소모되면 더 이상 도전할 수 없습니다."
	var guide_color := Color(0.68, 0.69, 0.63, 0.90)
	if visual_remaining_gems <= 0:
		line_one = "이번이 마지막 기회입니다."
		line_two = "다음 패배 시 게임이 종료됩니다."
		guide_color = gold
	var guide_center_y := DefeatContinueVisualProjection.scaled_y(view_size, 604.0)
	var guide_font_size := DefeatContinueVisualProjection.scaled_font(view_size, 15)
	_draw_centered_text(canvas, font, line_one, Vector2(center_x, guide_center_y - 12.0), guide_font_size, guide_color)
	_draw_centered_text(canvas, font, line_two, Vector2(center_x, guide_center_y + 12.0), guide_font_size, guide_color)
	if not show_confirm_button:
		return
	var button_rect := get_button_rect(view_size)
	_draw_button_frame(canvas, button_rect, accent, pulse)
	_draw_centered_text(
		canvas,
		TITLE_FONT,
		"확인",
		button_rect.get_center() + Vector2(0.0, 1.0),
		DefeatContinueVisualProjection.scaled_font(view_size, 18),
		Color.WHITE
	)


static func get_button_rect(view_size: Vector2) -> Rect2:
	return DefeatContinueVisualProjection.get_button_rect(view_size)


static func _draw_broken_ward_sigil(canvas: CanvasItem, center: Vector2, accent: Color, pulse: float) -> void:
	var jade := Color(accent.r, accent.g, accent.b, 0.24 + pulse * 0.08)
	var brass := Color(0.72, 0.57, 0.31, 0.30)
	for i in range(8):
		var angle := -PI * 0.92 + float(i) * TAU / 8.0
		var arc_start := angle
		var arc_end := angle + TAU / 8.0 * 0.58
		canvas.draw_arc(center, 26.0, arc_start, arc_end, 8, jade if i % 2 == 0 else brass, 1.2)
		var tangent := Vector2(-sin(angle), cos(angle))
		var radial := Vector2(cos(angle), sin(angle))
		var line_center := center + radial * 32.0
		canvas.draw_line(line_center - tangent * 5.0, line_center + tangent * 5.0, brass, 1.1)
		if i % 3 == 0:
			canvas.draw_line(line_center - tangent * 5.0 + radial * 3.0, line_center + tangent * 5.0 + radial * 3.0, jade, 0.9)
	canvas.draw_rect(Rect2(center - Vector2(3.5, 3.5), Vector2(7.0, 7.0)), Color(0.48, 0.16, 0.11, 0.74))


static func _draw_cloud_title_rule(canvas: CanvasItem, x: float, y: float, half_width: float, accent: Color) -> void:
	var brass := Color(0.72, 0.58, 0.34, 0.30)
	var jade := Color(accent.r, accent.g, accent.b, 0.22)
	canvas.draw_line(Vector2(x - half_width, y), Vector2(x - 92.0, y), brass, 1.0)
	canvas.draw_line(Vector2(x + 92.0, y), Vector2(x + half_width, y), brass, 1.0)
	_draw_cloud_hook(canvas, Vector2(x - 116.0, y), -1.0, jade, brass)
	_draw_cloud_hook(canvas, Vector2(x + 116.0, y), 1.0, jade, brass)


static func _draw_cloud_hook(canvas: CanvasItem, center: Vector2, side: float, jade: Color, brass: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(side * 26.0, 0.0),
		center + Vector2(side * 16.0, -6.0),
		center + Vector2(side * 4.0, -4.0),
		center + Vector2(side * 10.0, 4.0),
		center + Vector2(side * 19.0, 5.0),
	])
	canvas.draw_polyline(points, brass, 1.2)
	canvas.draw_circle(center + Vector2(side * 4.0, -4.0), 2.0, jade)


static func _draw_status_hanji_band(canvas: CanvasItem, view_size: Vector2, center_x: float) -> void:
	var band_rect := Rect2(
		Vector2(center_x - minf(view_size.x * 0.31, 348.0), DefeatContinueVisualProjection.scaled_y(view_size, 438.0)),
		Vector2(minf(view_size.x * 0.62, 696.0), DefeatContinueVisualProjection.scaled_y(view_size, 126.0))
	)
	var texture := ProjectResourceLoader.get_cached_texture(HANJI_BAND_TEXTURE_PATH)
	if texture != null:
		_draw_nine_patch_texture(canvas, texture, band_rect, HANJI_BAND_SLICE, Color(1.0, 1.0, 1.0, 0.80))
	else:
		canvas.draw_rect(band_rect, Color(0.018, 0.022, 0.019, 0.74))
	canvas.draw_line(
		Vector2(band_rect.position.x + 72.0, band_rect.position.y + 7.0),
		Vector2(band_rect.end.x - 72.0, band_rect.position.y + 7.0),
		Color(0.72, 0.58, 0.33, 0.16),
		1.0
	)


static func _draw_button_frame(canvas: CanvasItem, rect: Rect2, accent: Color, pulse: float) -> void:
	var texture := ProjectResourceLoader.get_cached_texture(SELECT_BUTTON_TEXTURE_PATH)
	if texture != null:
		_draw_nine_patch_texture(canvas, texture, rect, SELECT_BUTTON_SLICE, Color(1.0, 1.0, 1.0, 0.94))
	else:
		var inset := rect.grow(-2.0)
		canvas.draw_rect(rect, Color(0.07, 0.045, 0.025, 0.94))
		canvas.draw_rect(inset, Color(0.025, 0.20, 0.16, 0.88))
		canvas.draw_rect(rect, Color(0.72, 0.58, 0.33, 0.66 + pulse * 0.16), false, 1.6)
	canvas.draw_line(
		Vector2(rect.position.x + 42.0, rect.position.y + 5.0),
		Vector2(rect.end.x - 42.0, rect.position.y + 5.0),
		Color(0.88, 0.74, 0.46, 0.10 + pulse * 0.05),
		1.0
	)


static func _draw_continue_status_text(canvas: CanvasItem, font: Font, view_size: Vector2, center_x: float, status_mode: int) -> void:
	var center := Vector2(center_x, DefeatContinueVisualProjection.scaled_y(view_size, 470.0))
	var font_size := DefeatContinueVisualProjection.scaled_font(view_size, 20)
	if status_mode == StatusMode.PRESENT:
		_draw_three_segment_text(
			canvas,
			font,
			"확인하면 기회의 보석이 ",
			"1개",
			" 소모됩니다.",
			center,
			font_size
		)
		return
	if status_mode == StatusMode.CONSUMED:
		_draw_three_segment_text(
			canvas,
			font,
			"기회의 보석이 ",
			"1개",
			" 소모되었습니다.",
			center,
			font_size
		)
		return
	_draw_centered_text(canvas, font, "기회의 보석이 흔들립니다...", center, font_size, Color(0.86, 0.92, 1.0, 0.94))


static func _draw_three_segment_text(
	canvas: CanvasItem,
	font: Font,
	left_text: String,
	middle_text: String,
	right_text: String,
	center: Vector2,
	font_size: int
) -> void:
	if font == null:
		return
	var left_size := font.get_string_size(left_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var middle_size := font.get_string_size(middle_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var right_size := font.get_string_size(right_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var total_width := left_size.x + middle_size.x + right_size.x
	var max_height := maxf(left_size.y, maxf(middle_size.y, right_size.y))
	var cursor := Vector2(center.x - total_width * 0.5, center.y - max_height * 0.5 + max_height * 0.78)
	cursor = _draw_text_segment(canvas, font, left_text, cursor, font_size, Color(0.88, 0.88, 0.82, 0.96))
	cursor = _draw_text_segment(canvas, font, middle_text, cursor, font_size, Color(0.88, 0.69, 0.36, 0.98))
	_draw_text_segment(canvas, font, right_text, cursor, font_size, Color(0.88, 0.88, 0.82, 0.96))


static func _draw_text_segment(canvas: CanvasItem, font: Font, text: String, cursor: Vector2, font_size: int, color: Color) -> Vector2:
	canvas.draw_string(font, cursor + Vector2(1.5, 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, color.a * 0.72))
	canvas.draw_string(font, cursor, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
	return cursor + Vector2(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x, 0.0)


static func _draw_nine_patch_texture(
	canvas: CanvasItem,
	texture: Texture2D,
	target: Rect2,
	source_margins: Vector4,
	texture_modulate: Color = Color.WHITE
) -> void:
	if texture == null or target.size.x <= 1.0 or target.size.y <= 1.0:
		return
	var texture_size := texture.get_size()
	if texture_size.x <= 1.0 or texture_size.y <= 1.0:
		return
	var source_left := clampf(source_margins.x, 0.0, texture_size.x * 0.49)
	var source_top := clampf(source_margins.y, 0.0, texture_size.y * 0.49)
	var source_right := clampf(source_margins.z, 0.0, texture_size.x * 0.49)
	var source_bottom := clampf(source_margins.w, 0.0, texture_size.y * 0.49)
	var horizontal_scale := minf(1.0, target.size.x / maxf(1.0, source_left + source_right))
	var vertical_scale := minf(1.0, target.size.y / maxf(1.0, source_top + source_bottom))
	var target_left := source_left * horizontal_scale
	var target_right := source_right * horizontal_scale
	var target_top := source_top * vertical_scale
	var target_bottom := source_bottom * vertical_scale
	var source_x := PackedFloat32Array([0.0, source_left, texture_size.x - source_right])
	var source_y := PackedFloat32Array([0.0, source_top, texture_size.y - source_bottom])
	var source_widths := PackedFloat32Array([source_left, texture_size.x - source_left - source_right, source_right])
	var source_heights := PackedFloat32Array([source_top, texture_size.y - source_top - source_bottom, source_bottom])
	var target_x := PackedFloat32Array([target.position.x, target.position.x + target_left, target.end.x - target_right])
	var target_y := PackedFloat32Array([target.position.y, target.position.y + target_top, target.end.y - target_bottom])
	var target_widths := PackedFloat32Array([target_left, target.size.x - target_left - target_right, target_right])
	var target_heights := PackedFloat32Array([target_top, target.size.y - target_top - target_bottom, target_bottom])
	for row in range(3):
		for column in range(3):
			if source_widths[column] <= 0.0 or source_heights[row] <= 0.0:
				continue
			if target_widths[column] <= 0.0 or target_heights[row] <= 0.0:
				continue
			canvas.draw_texture_rect_region(
				texture,
				Rect2(Vector2(target_x[column], target_y[row]), Vector2(target_widths[column], target_heights[row])),
				Rect2(Vector2(source_x[column], source_y[row]), Vector2(source_widths[column], source_heights[row])),
				texture_modulate,
				false,
				true
			)


static func _draw_centered_text(canvas: CanvasItem, font: Font, text: String, center: Vector2, font_size: int, color: Color) -> void:
	if font == null or text == "":
		return
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline := center - text_size * 0.5 + Vector2(0.0, text_size.y * 0.78)
	canvas.draw_string(font, baseline + Vector2(1.5, 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, color.a * 0.72))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
