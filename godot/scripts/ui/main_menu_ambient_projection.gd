extends RefCounted

const BACKGROUND_SOURCE_SIZE := Vector2(2912.0, 1632.0)
const LOGO_GLINT_SOURCE_RECT := Rect2(Vector2(90.0, 330.0), Vector2(1015.0, 126.0))
const LOGO_ORB_EFFECT_SOURCE_RECT := Rect2(Vector2(420.0, 205.0), Vector2(285.0, 310.0))
const LOGO_ORB_SOURCE_CENTER := Vector2(560.0, 382.0)
const LOGO_LETTER_MASK_RECT := Rect2i(90, 330, 1015, 126)
const LOGO_ORB_MASK_RECT := Rect2i(420, 205, 285, 310)
const LOGO_ORB_DIFF_THRESHOLD := 16.0 / 255.0
const LOGO_ORB_LUMA_THRESHOLD := 58.0 / 255.0
const LOGO_ORB_CHROMA_THRESHOLD := 18.0 / 255.0
const LOGO_LETTER_DIFF_THRESHOLD := 40.0 / 255.0
const LOGO_LETTER_LUMA_THRESHOLD := 180.0 / 255.0
const LOGO_LETTER_CHROMA_MAX := 110.0 / 255.0
const LOGO_WORD_SOURCE_RECTS := [
	Rect2(Vector2(90.0, 330.0), Vector2(360.0, 126.0)),
	Rect2(Vector2(585.0, 330.0), Vector2(520.0, 126.0)),
]


static func source_rect_to_screen(source_rect: Rect2, view_size: Vector2) -> Rect2:
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		return Rect2()
	var rect := Rect2(source_to_screen(source_rect.position, view_size), source_rect.size * background_source_scale(view_size))
	return intersect_rect(rect, Rect2(Vector2.ZERO, view_size))


static func background_image_rect(view_size: Vector2) -> Rect2:
	return Rect2(Vector2.ZERO, view_size)


static func background_source_scale(view_size: Vector2) -> Vector2:
	if BACKGROUND_SOURCE_SIZE.x <= 1.0 or BACKGROUND_SOURCE_SIZE.y <= 1.0:
		return Vector2.ONE
	return Vector2(view_size.x / BACKGROUND_SOURCE_SIZE.x, view_size.y / BACKGROUND_SOURCE_SIZE.y)


static func source_to_screen(source_pos: Vector2, view_size: Vector2) -> Vector2:
	return background_image_rect(view_size).position + source_pos * background_source_scale(view_size)


static func screen_to_source(screen_pos: Vector2, view_size: Vector2) -> Vector2:
	var source_scale := background_source_scale(view_size)
	if source_scale.x <= 0.0 or source_scale.y <= 0.0:
		return Vector2.ZERO
	return (screen_pos - background_image_rect(view_size).position) / source_scale


static func intersect_rect(a: Rect2, b: Rect2) -> Rect2:
	var x0 := maxf(a.position.x, b.position.x)
	var y0 := maxf(a.position.y, b.position.y)
	var x1 := minf(a.end.x, b.end.x)
	var y1 := minf(a.end.y, b.end.y)
	if x1 <= x0 or y1 <= y0:
		return Rect2()
	return Rect2(Vector2(x0, y0), Vector2(x1 - x0, y1 - y0))


static func clipped_line_to_rect(line_start: Vector2, line_end: Vector2, rect: Rect2) -> PackedVector2Array:
	var delta := line_end - line_start
	var t_min := 0.0
	var t_max := 1.0
	var clip_edges := [
		Vector2(-delta.x, line_start.x - rect.position.x),
		Vector2(delta.x, rect.end.x - line_start.x),
		Vector2(-delta.y, line_start.y - rect.position.y),
		Vector2(delta.y, rect.end.y - line_start.y),
	]
	for edge in clip_edges:
		var p: float = edge.x
		var q: float = edge.y
		if is_zero_approx(p):
			if q < 0.0:
				return PackedVector2Array()
			continue
		var ratio := q / p
		if p < 0.0:
			if ratio > t_max:
				return PackedVector2Array()
			t_min = maxf(t_min, ratio)
		else:
			if ratio < t_min:
				return PackedVector2Array()
			t_max = minf(t_max, ratio)
	return PackedVector2Array([line_start + delta * t_min, line_start + delta * t_max])


static func sweep_x_at_y(screen_y: float, rect: Rect2, center_x: float, tilt_x: float) -> float:
	if rect.size.y <= 1.0:
		return center_x
	return center_x + tilt_x * ((screen_y - rect.position.y) / rect.size.y)


static func orb_sweep_x_at_y(screen_y: float, orb_center_y: float, center_x: float, tilt_x: float, orb_rect: Rect2) -> float:
	if orb_rect.size.y <= 1.0:
		return center_x
	return center_x + tilt_x * ((screen_y - orb_center_y) / orb_rect.size.y)


static func sparkle_fade_curve(raw_amount: float) -> float:
	var amount := clampf(raw_amount, 0.0, 1.0)
	return amount * amount * amount * (amount * (amount * 6.0 - 15.0) + 10.0)


static func hash01(value: float) -> float:
	return fposmod(sin(value) * 43758.5453, 1.0)


static func is_source_point_inside_logo_word(source_pos: Vector2) -> bool:
	for word_rect in LOGO_WORD_SOURCE_RECTS:
		if word_rect.has_point(source_pos):
			return true
	return false


static func is_logo_letter_color(logo_color: Color, base_color: Color) -> bool:
	var diff := _max3(absf(logo_color.r - base_color.r), absf(logo_color.g - base_color.g), absf(logo_color.b - base_color.b))
	if diff < LOGO_LETTER_DIFF_THRESHOLD:
		return false
	var luma := logo_color.r * 0.2126 + logo_color.g * 0.7152 + logo_color.b * 0.0722
	if luma < LOGO_LETTER_LUMA_THRESHOLD:
		return false
	var chroma := _max3(logo_color.r, logo_color.g, logo_color.b) - _min3(logo_color.r, logo_color.g, logo_color.b)
	return chroma <= LOGO_LETTER_CHROMA_MAX


static func is_logo_orb_effect_color(logo_color: Color, base_color: Color, source_pos: Vector2) -> bool:
	var diff := _max3(absf(logo_color.r - base_color.r), absf(logo_color.g - base_color.g), absf(logo_color.b - base_color.b))
	if diff < LOGO_ORB_DIFF_THRESHOLD:
		return false
	var luma := logo_color.r * 0.2126 + logo_color.g * 0.7152 + logo_color.b * 0.0722
	if luma < LOGO_ORB_LUMA_THRESHOLD:
		return false
	var chroma := _max3(logo_color.r, logo_color.g, logo_color.b) - _min3(logo_color.r, logo_color.g, logo_color.b)
	var dist := source_pos.distance_to(LOGO_ORB_SOURCE_CENTER)
	return dist <= 74.0 or (dist <= 150.0 and chroma >= LOGO_ORB_CHROMA_THRESHOLD) or (dist <= 125.0 and luma >= 0.55)


static func _max3(a: float, b: float, c: float) -> float:
	return maxf(maxf(a, b), c)


static func _min3(a: float, b: float, c: float) -> float:
	return minf(minf(a, b), c)
