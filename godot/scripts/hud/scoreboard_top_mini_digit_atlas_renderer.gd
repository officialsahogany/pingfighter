extends RefCounted

# The atlas is 10 columns x 2 rows. Each 128px square keeps the body and
# derived core in identical coordinates so a core pass can never drift from
# its parent glyph.
const CELL_SIZE := 128.0
const BODY_ROW_Y := 0.0
const CORE_ROW_Y := 128.0
const ATLAS_CAP_HEIGHT := 96.0
const ATLAS_CAP_RATIO := ATLAS_CAP_HEIGHT / CELL_SIZE

const DIGIT_CAP_TO_PANEL_HEIGHT := 0.92
const NUMBER_WIDTH_TO_PANEL_WIDTH := 0.92
const DIGIT_GAP_TO_CAP_HEIGHT := 0.11
const BODY_GLOW_PASS_COUNT := 3
const BODY_GLOW_PASS_COUNT_LOD := 1

# Alpha-bbox widths measured from the hand-painted brush body row, divided by
# the common 96px cap height. These are optical, not typographic, widths: the
# narrow 1 and formerly light 2/5/8 carry extra mass without clipping 4.
const GLYPH_WIDTH_TO_CAP := [
	76.0 / 96.0,
	52.0 / 96.0,
	84.0 / 96.0,
	76.0 / 96.0,
	82.0 / 96.0,
	82.0 / 96.0,
	76.0 / 96.0,
	78.0 / 96.0,
	70.0 / 96.0,
	72.0 / 96.0,
]

const CORE_COLOR := Color(243.0 / 255.0, 1.0, 1.0, 1.0)


static func get_source_rect(digit: int, core: bool = false) -> Rect2:
	var safe_digit: int = clampi(digit, 0, 9)
	return Rect2(
		float(safe_digit) * CELL_SIZE,
		CORE_ROW_Y if core else BODY_ROW_Y,
		CELL_SIZE,
		CELL_SIZE
	)


static func get_core_pass_color(alpha: float = 1.0) -> Color:
	return Color(CORE_COLOR.r, CORE_COLOR.g, CORE_COLOR.b, clampf(alpha, 0.0, 1.0))


func get_number_size(value: int, cap_height: float) -> Vector2:
	var text := str(maxi(0, value))
	var width := 0.0
	for digit_index in range(text.length()):
		var digit := int(text.substr(digit_index, 1))
		width += float(GLYPH_WIDTH_TO_CAP[digit]) * cap_height
	width += float(maxi(0, text.length() - 1)) * cap_height * DIGIT_GAP_TO_CAP_HEIGHT
	return Vector2(width, cap_height)


func build_number_layout(
	panel_rect: Rect2,
	value: int,
	center_offset: Vector2 = Vector2.ZERO
) -> Dictionary:
	var text := str(maxi(0, value))
	var cap_height: float = panel_rect.size.y * DIGIT_CAP_TO_PANEL_HEIGHT
	var number_size: Vector2 = get_number_size(value, cap_height)
	var max_width: float = panel_rect.size.x * NUMBER_WIDTH_TO_PANEL_WIDTH
	if number_size.x > max_width and number_size.x > 0.0:
		cap_height *= max_width / number_size.x
		number_size = get_number_size(value, cap_height)

	var cell_draw_size: float = cap_height / ATLAS_CAP_RATIO
	var digit_gap: float = cap_height * DIGIT_GAP_TO_CAP_HEIGHT
	var center: Vector2 = panel_rect.get_center() + center_offset
	var cursor_x: float = center.x - number_size.x * 0.5
	var draw_rects: Array[Rect2] = []
	var content_rects: Array[Rect2] = []
	var body_source_rects: Array[Rect2] = []
	var core_source_rects: Array[Rect2] = []

	for digit_index in range(text.length()):
		var digit := int(text.substr(digit_index, 1))
		var content_width: float = float(GLYPH_WIDTH_TO_CAP[digit]) * cap_height
		var content_rect := Rect2(
			cursor_x,
			center.y - cap_height * 0.5,
			content_width,
			cap_height
		)
		var draw_rect := Rect2(
			content_rect.get_center() - Vector2.ONE * cell_draw_size * 0.5,
			Vector2.ONE * cell_draw_size
		)
		content_rects.append(content_rect)
		draw_rects.append(draw_rect)
		body_source_rects.append(get_source_rect(digit, false))
		core_source_rects.append(get_source_rect(digit, true))
		cursor_x += content_width + digit_gap

	return {
		"value": maxi(0, value),
		"cap_height": cap_height,
		"total_width": number_size.x,
		"max_width": max_width,
		"draw_rects": draw_rects,
		"body_draw_rects": draw_rects,
		"core_draw_rects": draw_rects,
		"content_rects": content_rects,
		"body_source_rects": body_source_rects,
		"core_source_rects": core_source_rects,
	}


func draw_number(
	canvas: CanvasItem,
	texture: Texture2D,
	panel_rect: Rect2,
	value: int,
	body_color: Color,
	glow_color: Color,
	glow_intensity: float,
	core_alpha: float,
	quality_scale: float = 1.0,
	center_offset: Vector2 = Vector2.ZERO
) -> bool:
	if canvas == null or texture == null or panel_rect.size.x <= 0.0 or panel_rect.size.y <= 0.0:
		return false
	var layout: Dictionary = build_number_layout(panel_rect, value, center_offset)
	var draw_rects: Array = layout.get("draw_rects", [])
	var body_source_rects: Array = layout.get("body_source_rects", [])
	var core_source_rects: Array = layout.get("core_source_rects", [])
	var cap_height: float = float(layout.get("cap_height", 0.0))
	var lod_active: bool = quality_scale < 0.85
	var glow_pass_count: int = BODY_GLOW_PASS_COUNT_LOD if lod_active else BODY_GLOW_PASS_COUNT
	var safe_intensity: float = clampf(glow_intensity, 0.0, 1.6)

	# MIX-blend approximation: broad low-alpha passes first, then the unscaled
	# body. No per-command CanvasItem material contract is claimed here.
	for pass_index in range(glow_pass_count):
		var reverse_index: float = float(glow_pass_count - pass_index)
		var grow: float = maxf(0.75, cap_height * 0.032) * reverse_index
		var pass_alpha: float = safe_intensity * (0.055 + float(pass_index) * 0.022)
		if lod_active:
			pass_alpha = safe_intensity * 0.105
		var pass_color := Color(glow_color.r, glow_color.g, glow_color.b, pass_alpha)
		for digit_index in range(draw_rects.size()):
			var glow_dest_rect: Rect2 = draw_rects[digit_index]
			var glow_source_rect: Rect2 = body_source_rects[digit_index]
			canvas.draw_texture_rect_region(
				texture,
				glow_dest_rect.grow(grow),
				glow_source_rect,
				pass_color,
				false,
				true
			)

	for digit_index in range(draw_rects.size()):
		var body_dest_rect: Rect2 = draw_rects[digit_index]
		var body_source_rect: Rect2 = body_source_rects[digit_index]
		canvas.draw_texture_rect_region(
			texture,
			body_dest_rect,
			body_source_rect,
			body_color,
			false,
			true
		)

	var core_color: Color = get_core_pass_color(core_alpha)
	for digit_index in range(draw_rects.size()):
		var core_dest_rect: Rect2 = draw_rects[digit_index]
		var core_source_rect: Rect2 = core_source_rects[digit_index]
		canvas.draw_texture_rect_region(
			texture,
			core_dest_rect,
			core_source_rect,
			core_color,
			false,
			true
		)
	return true
