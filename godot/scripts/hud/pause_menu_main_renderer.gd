extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PauseMenuOverlayLayout := preload("res://scripts/hud/pause_menu_overlay_layout.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const MAIN_EDITORIAL_BG_PATH := "res://assets/ui/pause_menu/pause_system_hwangyeokjeon_map_bg_v1.png"
const MAIN_DIAL_ROTATIONS_PER_SECOND := 0.075
const OPEN_BG_FADE_SECONDS := 0.15
const OPEN_CHROME_FADE_SECONDS := 0.20
const OPEN_BAR_SWEEP_SECONDS := 0.20
const OPEN_TEXT_FADE_DELAY_SECONDS := 0.08
const OPEN_TEXT_FADE_SECONDS := 0.14
const OPEN_ITEM_STAGGER_SECONDS := 0.045
const OPEN_ITEM_SLIDE_X := 34.0
const MAIN_SELECTED_PRIMARY_MIN_FONT_SIZE := 20
const MAIN_SELECTED_HELPER_MIN_FONT_SIZE := 11
const MAIN_UNSELECTED_MIN_FONT_SIZE := 14
const MAIN_TEXT_SIDE_INSET := 8.0
const MAIN_TITLE_MIN_FONT_SIZE := 22
const MAIN_TITLE_MAX_WIDTH_RATIO := 0.30
const MAIN_TITLE_MAX_WIDTH := 250.0
const YUNDO_RING_RADII := [0.34, 0.56, 0.78, 1.0]
const YUNDO_OUTER_TICK_COUNT := 24
const YUNDO_INNER_TICK_COUNT := 12
const YUNDO_SPIRIT_ARC_RADIUS_SCALE := 1.08
const SCROLL_SPIRIT_HAIRLINE_ALPHA := 0.58
const HANJI_FIBER_COUNT := 3
const HANJI_FIBER_ALPHA := 0.045
const STACKED_HELPER_BOTTOM_INSET := 14.0
# Match the loading-tip calligraphy route: use an OS brush-serif when present,
# then fall back through Batang and the shipped body font.
const MAIN_SYSTEM_FONT_NAMES := ["Gungsuh", "궁서", "GungSeo", "Batang", "바탕"]

const PAPER_BG := Color(0.055, 0.050, 0.042)
const INK := Color(0.92, 0.89, 0.82)
# The compatibility name stays until the later shape slices; its value is now
# the aged-gilt selection accent rather than dominant cyberpunk cyan.
const SELECT_BLUE := Color(0.62, 0.52, 0.30)
const SELECT_SUBINK := Color(0.14, 0.10, 0.06)
const GRAPHIC_INK := Color(0.03, 0.028, 0.024)
const TITLE_ON_GRAPHIC_INK := Color(0.90, 0.86, 0.78)
const DIAMOND_GRAY := Color(0.72, 0.60, 0.36)
const SPINE_LINE := Color(0.03, 0.028, 0.024, 0.28)
const SEAL_RED := Color(139.0 / 255.0, 44.0 / 255.0, 33.0 / 255.0)
const SPIRIT_BLUE := Color(0.42, 0.66, 0.86)

var background_texture: Texture2D = null
var _main_brush_font: Font = null


func prewarm_assets() -> void:
	if background_texture != null:
		return
	background_texture = ProjectResourceLoader.load_texture(
		MAIN_EDITORIAL_BG_PATH,
		"Pause menu editorial background texture is missing",
		"Pause menu editorial background texture failed to load"
	)


func get_main_brush_font(fallback: Font) -> Font:
	if _main_brush_font != null:
		return _main_brush_font
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray(MAIN_SYSTEM_FONT_NAMES)
	if fallback != null:
		system_font.fallbacks = [fallback]
	_main_brush_font = system_font
	return _main_brush_font


func clear_assets() -> void:
	background_texture = null
	_main_brush_font = null


func draw_menu(
	canvas: CanvasItem,
	font: Font,
	main_fallback_font: Font,
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
	draw_editorial_header(canvas, main_fallback_font, panel_rect, chrome_alpha)
	draw_editorial_spine(canvas, panel_rect, entries.size(), chrome_alpha)
	if entries.is_empty():
		return
	draw_selected_bar(
		canvas,
		font,
		main_fallback_font,
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
				main_fallback_font,
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
	draw_ink_wash_header(canvas, panel_rect, chrome_alpha)
	draw_editorial_dial(canvas, panel_rect, main_dial_time, chrome_alpha)
	draw_knot_marker(canvas, panel_rect.position + Vector2(panel_rect.size.x - 92.0, panel_rect.size.y - 82.0), 9.0, _with_alpha(Color(SELECT_BLUE.r, SELECT_BLUE.g, SELECT_BLUE.b, 0.32), chrome_alpha))
	draw_knot_marker(canvas, panel_rect.position + Vector2(panel_rect.size.x - 168.0, 54.0), 6.0, _with_alpha(Color(SELECT_BLUE.r, SELECT_BLUE.g, SELECT_BLUE.b, 0.24), chrome_alpha))


func draw_ink_wash_header(canvas: CanvasItem, panel_rect: Rect2, alpha: float = 1.0) -> void:
	var top_left := panel_rect.position
	var wash_width := minf(panel_rect.size.x * 0.50, 560.0)
	var wash_height := minf(panel_rect.size.y * 0.46, 340.0)
	var ink_wash_feather_curve := PackedVector2Array([
		top_left,
		top_left + Vector2(wash_width * 0.96, 0.0),
		top_left + Vector2(wash_width * 0.88, wash_height * 0.08),
		top_left + Vector2(wash_width * 0.81, wash_height * 0.18),
		top_left + Vector2(wash_width * 0.73, wash_height * 0.31),
		top_left + Vector2(wash_width * 0.64, wash_height * 0.46),
		top_left + Vector2(wash_width * 0.57, wash_height * 0.61),
		top_left + Vector2(wash_width * 0.48, wash_height * 0.75),
		top_left + Vector2(wash_width * 0.35, wash_height * 0.88),
		top_left + Vector2(wash_width * 0.16, wash_height),
		top_left + Vector2(0.0, wash_height * 0.96),
	])
	canvas.draw_colored_polygon(
		ink_wash_feather_curve,
		_with_alpha(Color(GRAPHIC_INK.r, GRAPHIC_INK.g, GRAPHIC_INK.b, 0.28), alpha)
	)
	var ink_wash_curve := PackedVector2Array([
		top_left,
		top_left + Vector2(wash_width * 0.82, 0.0),
		top_left + Vector2(wash_width * 0.76, wash_height * 0.07),
		top_left + Vector2(wash_width * 0.70, wash_height * 0.16),
		top_left + Vector2(wash_width * 0.66, wash_height * 0.26),
		top_left + Vector2(wash_width * 0.58, wash_height * 0.40),
		top_left + Vector2(wash_width * 0.52, wash_height * 0.52),
		top_left + Vector2(wash_width * 0.46, wash_height * 0.66),
		top_left + Vector2(wash_width * 0.36, wash_height * 0.79),
		top_left + Vector2(wash_width * 0.18, wash_height * 0.91),
		top_left + Vector2(0.0, wash_height * 0.95),
	])
	canvas.draw_colored_polygon(
		ink_wash_curve,
		_with_alpha(Color(GRAPHIC_INK.r, GRAPHIC_INK.g, GRAPHIC_INK.b, 0.78), alpha)
	)
	var wash_blooms := [
		{"position": Vector2(wash_width * 0.79, wash_height * 0.10), "radius": wash_height * 0.055},
		{"position": Vector2(wash_width * 0.61, wash_height * 0.42), "radius": wash_height * 0.045},
		{"position": Vector2(wash_width * 0.42, wash_height * 0.72), "radius": wash_height * 0.052},
	]
	for bloom in wash_blooms:
		canvas.draw_circle(
			top_left + Vector2(bloom["position"]),
			float(bloom["radius"]),
			_with_alpha(Color(GRAPHIC_INK.r, GRAPHIC_INK.g, GRAPHIC_INK.b, 0.18), alpha)
		)


func draw_editorial_base(canvas: CanvasItem, panel_rect: Rect2, alpha: float = 1.0) -> void:
	var draw_alpha := clampf(alpha, 0.0, 1.0)
	if background_texture == null:
		prewarm_assets()
	if background_texture != null:
		var cover_region := get_background_cover_region(background_texture, panel_rect)
		canvas.draw_texture_rect_region(background_texture, panel_rect, cover_region, Color(1.0, 1.0, 1.0, draw_alpha))
		return
	canvas.draw_rect(panel_rect, _with_alpha(PAPER_BG, draw_alpha))
	draw_map_texture(canvas, panel_rect, draw_alpha)


func get_background_cover_region(texture: Texture2D, panel_rect: Rect2) -> Rect2:
	var source_size := Vector2(texture.get_width(), texture.get_height())
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return Rect2(Vector2.ZERO, source_size)
	var destination_aspect := panel_rect.size.x / maxf(panel_rect.size.y, 1.0)
	var source_aspect := source_size.x / source_size.y
	if destination_aspect > source_aspect:
		var cropped_height := source_size.x / destination_aspect
		return Rect2(0.0, (source_size.y - cropped_height) * 0.5, source_size.x, cropped_height)
	var cropped_width := source_size.y * destination_aspect
	# The plate deliberately reserves its left third for text, so horizontal
	# cover crops discard only the detailed right edge instead of re-centering.
	return Rect2(0.0, 0.0, cropped_width, source_size.y)


func draw_map_texture(canvas: CanvasItem, panel_rect: Rect2, alpha: float = 1.0) -> void:
	var map_color := Color(SPIRIT_BLUE.r, SPIRIT_BLUE.g, SPIRIT_BLUE.b, 0.05 * clampf(alpha, 0.0, 1.0))
	var street_color := Color(SPIRIT_BLUE.r, SPIRIT_BLUE.g, SPIRIT_BLUE.b, 0.07 * clampf(alpha, 0.0, 1.0))
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


func draw_editorial_header(canvas: CanvasItem, main_fallback_font: Font, panel_rect: Rect2, alpha: float = 1.0) -> void:
	var title_text := get_title_text()
	var title_font := _get_text_draw_font(main_fallback_font, title_text, true)
	var title_size := get_title_font_size(main_fallback_font, title_text, panel_rect)
	var title_pos := panel_rect.position + Vector2(PauseMenuOverlayLayout.get_main_title_left_margin(panel_rect), maxf(54.0, panel_rect.size.y * 0.115))
	canvas.draw_string(title_font, title_pos, title_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_size, _with_alpha(TITLE_ON_GRAPHIC_INK, alpha))
	var title_width := title_font.get_string_size(title_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_size).x
	var seal_size := clampf(float(title_size) * 0.42, 18.0, 26.0)
	var seal_rect := Rect2(
		Vector2(title_pos.x + title_width + 12.0, title_pos.y - float(title_size) * 0.72),
		Vector2(seal_size, seal_size)
	)
	draw_title_seal(canvas, main_fallback_font, seal_rect, alpha)


func draw_title_seal(canvas: CanvasItem, fallback_font: Font, seal_rect: Rect2, alpha: float = 1.0) -> void:
	canvas.draw_rect(seal_rect, _with_alpha(Color(SEAL_RED.r, SEAL_RED.g, SEAL_RED.b, 0.88), alpha), true)
	canvas.draw_rect(seal_rect.grow(-1.5), _with_alpha(Color(INK.r, INK.g, INK.b, 0.56), alpha), false, 1.0, true)
	var seal_text := "系"
	var seal_font := _get_text_draw_font(fallback_font, seal_text)
	var seal_font_size := maxi(11, int(round(seal_rect.size.y * 0.66)))
	var seal_text_width := seal_font.get_string_size(seal_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, seal_font_size).x
	var seal_text_pos := Vector2(
		seal_rect.get_center().x - seal_text_width * 0.5,
		seal_rect.position.y + seal_rect.size.y * 0.76
	)
	canvas.draw_string(seal_font, seal_text_pos, seal_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, seal_font_size, _with_alpha(INK, alpha))


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
	var center := get_yundo_center(panel_rect)
	var radius := get_yundo_radius(panel_rect)
	var yundo_rings := YUNDO_RING_RADII
	var ring_alphas := [0.56, 0.44, 0.34, 0.50]
	for ring_index in range(yundo_rings.size()):
		canvas.draw_arc(
			center,
			radius * float(yundo_rings[ring_index]),
			0.0,
			TAU,
			48 + ring_index * 8,
			_with_alpha(Color(SELECT_BLUE.r, SELECT_BLUE.g, SELECT_BLUE.b, float(ring_alphas[ring_index])), alpha),
			1.15 if ring_index < yundo_rings.size() - 1 else 1.8,
			true
		)
	var tick_color := _with_alpha(Color(SELECT_BLUE.r, SELECT_BLUE.g, SELECT_BLUE.b, 0.58), alpha)
	for tick_index in range(YUNDO_OUTER_TICK_COUNT):
		var tick_angle := float(tick_index) / float(YUNDO_OUTER_TICK_COUNT) * TAU
		var is_major_tick := tick_index % 3 == 0
		var tick_inner_radius := radius * (0.84 if is_major_tick else 0.89)
		var tick_outer_radius := radius * 0.98
		var tick_direction := Vector2(cos(tick_angle), sin(tick_angle))
		canvas.draw_line(center + tick_direction * tick_inner_radius, center + tick_direction * tick_outer_radius, tick_color, 1.25 if is_major_tick else 0.85, true)
	for tick_index in range(YUNDO_INNER_TICK_COUNT):
		var tick_angle := (float(tick_index) + 0.5) / float(YUNDO_INNER_TICK_COUNT) * TAU
		var tick_direction := Vector2(cos(tick_angle), sin(tick_angle))
		canvas.draw_line(center + tick_direction * radius * 0.39, center + tick_direction * radius * 0.53, _with_alpha(Color(INK.r, INK.g, INK.b, 0.38), alpha), 0.9, true)
	var base_angle := fposmod(-0.92 * PI + main_dial_time * MAIN_DIAL_ROTATIONS_PER_SECOND * TAU, TAU)
	var spirit_arc_start := base_angle + PI * 0.16
	canvas.draw_arc(
		center,
		radius * YUNDO_SPIRIT_ARC_RADIUS_SCALE,
		spirit_arc_start,
		spirit_arc_start + PI * 1.18,
		42,
		_with_alpha(Color(SPIRIT_BLUE.r, SPIRIT_BLUE.g, SPIRIT_BLUE.b, 0.68), alpha),
		2.2,
		true
	)
	var needle_direction := Vector2(cos(base_angle), sin(base_angle))
	var needle_perpendicular := needle_direction.rotated(PI * 0.5)
	var needle_half_width := radius * 0.105
	var red_tip := center + needle_direction * radius * 0.70
	var ink_tip := center - needle_direction * radius * 0.58
	var needle_blades := [
		PackedVector2Array([red_tip, center + needle_perpendicular * needle_half_width, center - needle_perpendicular * needle_half_width]),
		PackedVector2Array([ink_tip, center - needle_perpendicular * needle_half_width, center + needle_perpendicular * needle_half_width]),
	]
	var needle_colors := [
		_with_alpha(Color(SEAL_RED.r, SEAL_RED.g, SEAL_RED.b, 0.96), alpha),
		_with_alpha(Color(SELECT_SUBINK.r, SELECT_SUBINK.g, SELECT_SUBINK.b, 0.98), alpha),
	]
	for blade_index in range(needle_blades.size()):
		canvas.draw_colored_polygon(needle_blades[blade_index], needle_colors[blade_index])
	canvas.draw_circle(center, radius * 0.115, _with_alpha(GRAPHIC_INK, alpha))
	canvas.draw_arc(center, radius * 0.115, 0.0, TAU, 24, _with_alpha(Color(SELECT_BLUE.r, SELECT_BLUE.g, SELECT_BLUE.b, 0.82), alpha), 1.4, true)
	canvas.draw_circle(center, maxf(2.4, radius * 0.036), _with_alpha(Color(INK.r, INK.g, INK.b, 0.92), alpha))


func get_yundo_radius(panel_rect: Rect2) -> float:
	return clampf(minf(panel_rect.size.x, panel_rect.size.y) * 0.105, 46.0, 84.0)


func get_yundo_center(panel_rect: Rect2) -> Vector2:
	var radius := get_yundo_radius(panel_rect)
	var ring_clearance := radius * YUNDO_SPIRIT_ARC_RADIUS_SCALE + 6.0
	var right_inset := maxf(minf(88.0, panel_rect.size.x * 0.09), ring_clearance)
	var top_inset := maxf(maxf(52.0, panel_rect.size.y * 0.10), ring_clearance)
	return panel_rect.position + Vector2(panel_rect.size.x - right_inset, top_inset)


func draw_selected_bar(
	canvas: CanvasItem,
	font: Font,
	main_fallback_font: Font,
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
	draw_scroll_banner(canvas, bar_rect, flash_alpha)
	var primary_text := get_primary_label_text(entry)
	var primary_font := _get_text_draw_font(main_fallback_font, primary_text, true)
	var primary_size := get_selected_primary_font_size(main_fallback_font, primary_text, final_bar_rect)
	var primary_text_size := primary_font.get_string_size(primary_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, primary_size)
	var local_text := get_selected_local_text(entry)
	var local_font := _get_text_draw_font(font, local_text)
	var local_size := get_selected_helper_font_size(local_font, local_text, final_bar_rect)
	var local_text_size := local_font.get_string_size(local_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, local_size) if not local_text.is_empty() else Vector2.ZERO
	var local_x := PauseMenuOverlayLayout.get_main_selected_local_x(final_bar_rect, local_text_size.x) if not local_text.is_empty() else -1.0
	var primary_x := PauseMenuOverlayLayout.get_main_selected_en_x(final_bar_rect, primary_text_size.x, local_x)
	var primary_pos := Vector2(primary_x, final_bar_rect.get_center().y + float(primary_size) * 0.36)
	var helper_fits_inline := (
		not local_text.is_empty()
		and local_x > primary_pos.x + primary_text_size.x + 20.0
		and local_x + local_text_size.x <= bar_rect.end.x - 24.0
	)
	if not local_text.is_empty() and not helper_fits_inline:
		primary_pos.y = final_bar_rect.position.y + float(primary_size) + 4.0
	var draw_text_alpha := clampf(text_alpha, 0.0, 1.0)
	canvas.draw_string(primary_font, primary_pos, primary_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, primary_size, _with_alpha(Color.WHITE, draw_text_alpha))
	if not local_text.is_empty():
		if helper_fits_inline:
			canvas.draw_string(local_font, Vector2(local_x, final_bar_rect.get_center().y + float(local_size) * 0.35), local_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, local_size, _with_alpha(SELECT_SUBINK, draw_text_alpha))
		else:
			var stacked_helper_x := maxf(
				final_bar_rect.position.x + PauseMenuOverlayLayout.get_main_scroll_text_side_inset(final_bar_rect),
				final_bar_rect.end.x - local_text_size.x - PauseMenuOverlayLayout.get_main_scroll_text_side_inset(final_bar_rect)
			)
			var stacked_helper_pos := Vector2(stacked_helper_x, final_bar_rect.end.y - STACKED_HELPER_BOTTOM_INSET)
			canvas.draw_string(local_font, stacked_helper_pos, local_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, local_size, _with_alpha(SELECT_SUBINK, draw_text_alpha))


func draw_scroll_banner(canvas: CanvasItem, bar_rect: Rect2, flash_alpha: float = 0.0) -> void:
	var cap_half_width := minf(
		PauseMenuOverlayLayout.get_main_scroll_cap_half_width(bar_rect),
		bar_rect.size.x * 0.5
	)
	var left_axis_x := bar_rect.position.x + cap_half_width
	# The right axis is derived from the swept end, so it travels with the
	# existing open animation and reads as a scroll being unrolled.
	var right_axis_x := bar_rect.end.x - cap_half_width
	var edge_inset := clampf(bar_rect.size.y * 0.10, 4.0, 8.0)
	var paper_top := bar_rect.position.y + edge_inset
	var paper_bottom := bar_rect.end.y - edge_inset
	if right_axis_x > left_axis_x:
		var scroll_paper := SELECT_BLUE.lerp(INK, 0.10)
		var paper_points := PackedVector2Array([
			Vector2(left_axis_x, paper_top + 2.2),
			Vector2(lerpf(left_axis_x, right_axis_x, 0.24), paper_top - 1.8),
			Vector2(lerpf(left_axis_x, right_axis_x, 0.52), paper_top + 2.0),
			Vector2(lerpf(left_axis_x, right_axis_x, 0.78), paper_top - 1.6),
			Vector2(right_axis_x, paper_top + 1.8),
			Vector2(right_axis_x, paper_bottom - 1.8),
			Vector2(lerpf(left_axis_x, right_axis_x, 0.76), paper_bottom + 1.6),
			Vector2(lerpf(left_axis_x, right_axis_x, 0.48), paper_bottom - 2.0),
			Vector2(lerpf(left_axis_x, right_axis_x, 0.22), paper_bottom + 1.8),
			Vector2(left_axis_x, paper_bottom - 2.2),
		])
		canvas.draw_colored_polygon(paper_points, scroll_paper)
		draw_hanji_edge(canvas, left_axis_x, right_axis_x, paper_top, -1.0, _with_alpha(INK, 0.34), 1.15)
		draw_hanji_edge(canvas, left_axis_x, right_axis_x, paper_bottom, 1.0, _with_alpha(SELECT_SUBINK, 0.48), 1.15)
		draw_hanji_fibers(canvas, Rect2(Vector2(left_axis_x, paper_top), Vector2(right_axis_x - left_axis_x, paper_bottom - paper_top)))
		if SCROLL_SPIRIT_HAIRLINE_ALPHA > 0.0:
			draw_hanji_edge(
				canvas,
				left_axis_x,
				right_axis_x,
				paper_bottom - 2.0,
				1.0,
				Color(SPIRIT_BLUE.r, SPIRIT_BLUE.g, SPIRIT_BLUE.b, SCROLL_SPIRIT_HAIRLINE_ALPHA),
				1.0
			)
		if flash_alpha > 0.0:
			canvas.draw_colored_polygon(paper_points, Color(1.0, 1.0, 1.0, flash_alpha))
	draw_scroll_axis_cap(canvas, left_axis_x, bar_rect, cap_half_width)
	draw_scroll_axis_cap(canvas, right_axis_x, bar_rect, cap_half_width)
	if bar_rect.size.x > cap_half_width * 6.0:
		draw_scroll_tassel(canvas, Vector2(right_axis_x, paper_bottom), cap_half_width)


func draw_scroll_axis_cap(canvas: CanvasItem, axis_x: float, bar_rect: Rect2, cap_half_width: float) -> void:
	var axis_top := bar_rect.position.y + maxf(2.0, cap_half_width * 0.30)
	var axis_bottom := bar_rect.end.y - maxf(2.0, cap_half_width * 0.30)
	var shaft_width := maxf(1.2, cap_half_width * 0.30)
	var tip_radius := maxf(1.6, cap_half_width * 0.34)
	var roll_rect := Rect2(
		Vector2(axis_x - cap_half_width * 0.42, axis_top),
		Vector2(cap_half_width * 0.84, maxf(1.0, axis_bottom - axis_top))
	)
	canvas.draw_rect(roll_rect, SELECT_BLUE.darkened(0.16), true)
	canvas.draw_rect(roll_rect, _with_alpha(SELECT_SUBINK, 0.56), false, maxf(1.0, cap_half_width * 0.08), true)
	canvas.draw_line(Vector2(axis_x, axis_top), Vector2(axis_x, axis_bottom), SELECT_SUBINK, shaft_width, true)
	canvas.draw_line(Vector2(axis_x - cap_half_width * 0.54, axis_top), Vector2(axis_x + cap_half_width * 0.54, axis_top), INK, maxf(1.0, shaft_width * 0.52), true)
	canvas.draw_line(Vector2(axis_x - cap_half_width * 0.54, axis_bottom), Vector2(axis_x + cap_half_width * 0.54, axis_bottom), INK, maxf(1.0, shaft_width * 0.52), true)
	canvas.draw_circle(Vector2(axis_x, axis_top), tip_radius, SELECT_BLUE)
	canvas.draw_circle(Vector2(axis_x, axis_bottom), tip_radius, SELECT_BLUE)
	canvas.draw_circle(Vector2(axis_x, axis_top), maxf(1.0, tip_radius * 0.36), SELECT_SUBINK)
	canvas.draw_circle(Vector2(axis_x, axis_bottom), maxf(1.0, tip_radius * 0.36), SELECT_SUBINK)


func draw_hanji_edge(
	canvas: CanvasItem,
	start_x: float,
	end_x: float,
	base_y: float,
	direction: float,
	color: Color,
	width: float
) -> void:
	if end_x <= start_x:
		return
	var edge_points := PackedVector2Array()
	var edge_offsets := [0.8, -0.6, 1.0, -0.9, 0.5, -0.4, 0.7]
	for edge_index in range(edge_offsets.size()):
		var ratio := float(edge_index) / float(edge_offsets.size() - 1)
		edge_points.append(Vector2(lerpf(start_x, end_x, ratio), base_y + float(edge_offsets[edge_index]) * direction * 1.8))
	canvas.draw_polyline(edge_points, color, width, true)


func draw_hanji_fibers(canvas: CanvasItem, paper_rect: Rect2) -> void:
	if paper_rect.size.x <= 0.0 or paper_rect.size.y <= 0.0:
		return
	var fiber_top := paper_rect.position.y + paper_rect.size.y * 0.08
	var fiber_bottom := paper_rect.end.y - paper_rect.size.y * 0.08
	for fiber_index in range(HANJI_FIBER_COUNT):
		var fiber_ratio := float(fiber_index + 1) / float(HANJI_FIBER_COUNT + 1)
		var fiber_x := paper_rect.position.x + paper_rect.size.x * fiber_ratio
		var fiber_lean := (float(fiber_index) - 1.0) * 0.18
		var fiber_alpha := HANJI_FIBER_ALPHA * (0.88 + float(fiber_index % 2) * 0.12)
		canvas.draw_line(
			Vector2(fiber_x, fiber_top),
			Vector2(fiber_x + fiber_lean, fiber_bottom),
			_with_alpha(SELECT_SUBINK, fiber_alpha),
			0.55,
			true
		)


func draw_scroll_tassel(canvas: CanvasItem, anchor: Vector2, scale_hint: float) -> void:
	var tassel_length := clampf(scale_hint * 1.55, 9.0, 17.0)
	var knot_center := anchor + Vector2(0.0, maxf(2.0, scale_hint * 0.28))
	draw_knot_marker(canvas, knot_center, maxf(2.6, scale_hint * 0.34), SELECT_SUBINK)
	canvas.draw_line(knot_center + Vector2(-1.2, 2.0), knot_center + Vector2(-2.8, tassel_length), SELECT_SUBINK, 1.2, true)
	canvas.draw_line(knot_center + Vector2(1.2, 2.0), knot_center + Vector2(3.8, tassel_length * 0.84), SELECT_SUBINK, 1.1, true)


func draw_unselected_entry(
	canvas: CanvasItem,
	main_fallback_font: Font,
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
	draw_knot_marker(canvas, Vector2(PauseMenuOverlayLayout.get_main_diamond_center_x(panel_rect) + x_offset, center_y), 7.0 if hovered else 6.0, _with_alpha(diamond_color, open_ratio))
	var primary_text := get_primary_label_text(entry)
	var primary_font := _get_text_draw_font(main_fallback_font, primary_text, true)
	var primary_size := get_unselected_primary_font_size(main_fallback_font, primary_text, panel_rect)
	var color := INK if hovered else Color(INK.r, INK.g, INK.b, 0.78 - float(index) * 0.08)
	canvas.draw_string(primary_font, Vector2(PauseMenuOverlayLayout.get_main_unselected_text_x(panel_rect) + x_offset, center_y + float(primary_size) * 0.34), primary_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, primary_size, _with_alpha(color, open_ratio))


func draw_knot_marker(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var knot_points := PackedVector2Array([
		center + Vector2(-radius, 0.0),
		center + Vector2(-radius * 0.52, -radius * 0.58),
		center,
		center + Vector2(radius * 0.52, radius * 0.58),
		center + Vector2(radius, 0.0),
		center + Vector2(radius * 0.52, -radius * 0.58),
		center,
		center + Vector2(-radius * 0.52, radius * 0.58),
		center + Vector2(-radius, 0.0),
	])
	canvas.draw_polyline(knot_points, color, maxf(1.0, radius * 0.22), true)
	canvas.draw_circle(center, maxf(1.0, radius * 0.18), color)


# Compatibility entry point retained for the pause facade; the shape itself is
# now the traditional knot contract rather than a cyberpunk sparkle diamond.
func draw_sparkle(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	draw_knot_marker(canvas, center, radius, color)


func should_show_local_label() -> bool:
	return LanguageSettings.get_language() != LanguageSettings.LANGUAGE_ENGLISH


func get_primary_label_text(entry: Dictionary) -> String:
	if should_show_local_label():
		return str(entry.get("label", entry.get("en", "")))
	return str(entry.get("en", entry.get("label", "")))


func get_title_text() -> String:
	return LanguageSettings.translate("pause.title", "일시정지")


func get_title_font_size(fallback: Font, text: String, panel_rect: Rect2) -> int:
	return _get_fitted_font_size(
		get_main_text_draw_font(fallback, text),
		text,
		PauseMenuOverlayLayout.get_main_title_font_size(panel_rect),
		MAIN_TITLE_MIN_FONT_SIZE,
		get_title_max_width(panel_rect)
	)


func get_title_max_width(panel_rect: Rect2) -> float:
	return clampf(panel_rect.size.x * MAIN_TITLE_MAX_WIDTH_RATIO, 88.0, MAIN_TITLE_MAX_WIDTH)


func get_main_text_draw_font(fallback: Font, text: String) -> Font:
	return _get_text_draw_font(fallback, text, true)


func get_selected_primary_font_size(fallback: Font, text: String, bar_rect: Rect2) -> int:
	var draw_font := get_main_text_draw_font(fallback, text)
	var preferred_size := PauseMenuOverlayLayout.get_main_entry_selected_font_size(bar_rect)
	var scroll_text_width := maxf(
		1.0,
		bar_rect.size.x - PauseMenuOverlayLayout.get_main_scroll_text_side_inset(bar_rect) * 2.0
	)
	return _get_fitted_font_size(
		draw_font,
		text,
		preferred_size,
		MAIN_SELECTED_PRIMARY_MIN_FONT_SIZE,
		scroll_text_width
	)


func get_selected_helper_font_size(font: Font, text: String, bar_rect: Rect2) -> int:
	var preferred_size := PauseMenuOverlayLayout.get_main_entry_local_font_size(bar_rect)
	var scroll_text_width := maxf(
		1.0,
		bar_rect.size.x - PauseMenuOverlayLayout.get_main_scroll_text_side_inset(bar_rect) * 2.0
	)
	return _get_fitted_font_size(
		font,
		text,
		preferred_size,
		MAIN_SELECTED_HELPER_MIN_FONT_SIZE,
		scroll_text_width
	)


func get_unselected_primary_font_size(fallback: Font, text: String, panel_rect: Rect2) -> int:
	var draw_font := get_main_text_draw_font(fallback, text)
	var preferred_size := PauseMenuOverlayLayout.get_main_entry_idle_font_size(panel_rect)
	var text_x := PauseMenuOverlayLayout.get_main_unselected_text_x(panel_rect)
	return _get_fitted_font_size(
		draw_font,
		text,
		preferred_size,
		MAIN_UNSELECTED_MIN_FONT_SIZE,
		maxf(1.0, panel_rect.end.x - text_x - MAIN_TEXT_SIDE_INSET)
	)


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


func _get_text_draw_font(font: Font, text: String, use_main_brush: bool = false) -> Font:
	if _needs_cjk_fallback_font(text):
		return ThemeDB.fallback_font if ThemeDB.fallback_font != null else font
	if use_main_brush:
		return get_main_brush_font(font)
	return font


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


func _get_fitted_font_size(font: Font, text: String, preferred_size: int, minimum_size: int, max_width: float) -> int:
	if font == null or text.is_empty() or max_width <= 0.0:
		return preferred_size
	var preferred_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, preferred_size).x
	if preferred_width <= max_width:
		return preferred_size
	var fitted_size := clampi(int(floor(float(preferred_size) * max_width / maxf(preferred_width, 1.0))), minimum_size, preferred_size)
	while fitted_size > minimum_size and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fitted_size).x > max_width:
		fitted_size -= 1
	return fitted_size


func _has_feedback_rect(rect: Rect2) -> bool:
	return rect.size.x > 1.0 and rect.size.y > 1.0


func _with_alpha(color: Color, alpha_scale: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * clampf(alpha_scale, 0.0, 1.0))
