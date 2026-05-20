extends RefCounted

const DIGIT_SEGMENTS := {
	"0": ["a", "b", "c", "d", "e", "f"],
	"1": ["b", "c"],
	"2": ["a", "b", "g", "e", "d"],
	"3": ["a", "b", "g", "c", "d"],
	"4": ["f", "g", "b", "c"],
	"5": ["a", "f", "g", "c", "d"],
	"6": ["a", "f", "g", "e", "c", "d"],
	"7": ["a", "b", "c"],
	"8": ["a", "b", "c", "d", "e", "f", "g"],
	"9": ["a", "b", "c", "d", "f", "g"],
}


func get_text_size(text: String, font_size: int) -> Vector2:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return Vector2.ZERO
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)


func get_segment_number_size(value: int, digit_height: float) -> Vector2:
	var digit_count: int = max(1, str(value).length())
	var digit_width: float = _get_segment_digit_width(digit_height)
	var digit_gap: float = max(2.0, digit_height * 0.11)
	return Vector2(
		float(digit_count) * digit_width + float(max(0, digit_count - 1)) * digit_gap,
		digit_height
	)


func draw_segment_number(
	canvas: CanvasItem,
	center: Vector2,
	value: int,
	digit_height: float,
	color: Color,
	glow_color: Color,
	intensity: float,
	alpha: float
) -> void:
	var text := str(value)
	var number_size: Vector2 = get_segment_number_size(value, digit_height)
	var digit_width: float = _get_segment_digit_width(digit_height)
	var digit_gap: float = max(2.0, digit_height * 0.11)
	var origin := Vector2(center.x - number_size.x * 0.5, center.y - number_size.y * 0.5)
	for digit_idx in range(text.length()):
		_draw_segment_digit(
			canvas,
			origin + Vector2(float(digit_idx) * (digit_width + digit_gap), 0.0),
			text.substr(digit_idx, 1),
			digit_height,
			color,
			glow_color,
			intensity,
			alpha
		)


func draw_segment_colon(
	canvas: CanvasItem,
	center: Vector2,
	digit_height: float,
	color: Color,
	glow_color: Color,
	intensity: float,
	alpha: float
) -> void:
	var dot_radius: float = max(2.0, digit_height * 0.055)
	var dot_gap: float = max(8.0, digit_height * 0.25)
	for y_offset in [-dot_gap * 0.5, dot_gap * 0.5]:
		_draw_led_dot(canvas, center + Vector2(0.0, y_offset), dot_radius, color, glow_color, intensity, alpha)


func draw_score_text(
	canvas: CanvasItem,
	center: Vector2,
	text: String,
	font_size: int,
	color: Color,
	shadow_color: Color,
	glow_color: Color,
	glow_strength: float
) -> void:
	if glow_strength > 0.0:
		for glow_radius in range(4, 0, -1):
			var glow_alpha: float = clamp(glow_strength, 0.0, 1.5) * (45.0 / 255.0) / float(glow_radius)
			var layer_color: Color = Color(glow_color.r, glow_color.g, glow_color.b, glow_alpha)
			for offset in [
				Vector2(-float(glow_radius), 0.0),
				Vector2(float(glow_radius), 0.0),
				Vector2(0.0, -float(glow_radius)),
				Vector2(0.0, float(glow_radius)),
			]:
				_draw_text_centered(canvas, center + offset, text, font_size, layer_color, 1.0)
	_draw_text_centered(canvas, center + Vector2(2.0, 2.0), text, font_size, shadow_color, 1.0)
	_draw_text_centered(canvas, center, text, font_size, color, 1.0)


func _draw_text_centered(canvas: CanvasItem, center: Vector2, text: String, font_size: int, color: Color, alpha: float) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text_size: Vector2 = get_text_size(text, font_size)
	var baseline: Vector2 = Vector2(center.x - text_size.x * 0.5, center.y + text_size.y * 0.35)
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, _alpha_color(color, alpha))


func _alpha_color(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * clamp(alpha, 0.0, 1.0))


func _draw_segment_digit(
	canvas: CanvasItem,
	origin: Vector2,
	digit: String,
	digit_height: float,
	color: Color,
	glow_color: Color,
	intensity: float,
	alpha: float
) -> void:
	var lit_segments: Array = DIGIT_SEGMENTS.get(digit, DIGIT_SEGMENTS["0"])
	var segments: Dictionary = _get_segment_rects(origin, digit_height)
	for segment_id in ["a", "b", "c", "d", "e", "f", "g"]:
		var segment_rect: Rect2 = segments[segment_id]
		var is_lit: bool = lit_segments.has(segment_id)
		_draw_segment(canvas, segment_rect, _is_horizontal_segment(segment_id), color, glow_color, intensity, alpha, is_lit)


func _get_segment_rects(origin: Vector2, digit_height: float) -> Dictionary:
	var digit_width: float = _get_segment_digit_width(digit_height)
	var thickness: float = _get_segment_thickness(digit_height)
	var vertical_height: float = (digit_height - thickness * 3.0) * 0.5
	var top_y: float = origin.y
	var middle_y: float = origin.y + (digit_height - thickness) * 0.5
	var bottom_y: float = origin.y + digit_height - thickness
	var upper_y: float = origin.y + thickness * 0.72
	var lower_y: float = middle_y + thickness * 0.72
	return {
		"a": Rect2(origin.x + thickness * 0.45, top_y, digit_width - thickness * 0.9, thickness),
		"g": Rect2(origin.x + thickness * 0.45, middle_y, digit_width - thickness * 0.9, thickness),
		"d": Rect2(origin.x + thickness * 0.45, bottom_y, digit_width - thickness * 0.9, thickness),
		"f": Rect2(origin.x, upper_y, thickness, vertical_height),
		"b": Rect2(origin.x + digit_width - thickness, upper_y, thickness, vertical_height),
		"e": Rect2(origin.x, lower_y, thickness, vertical_height),
		"c": Rect2(origin.x + digit_width - thickness, lower_y, thickness, vertical_height),
	}


func _draw_segment(
	canvas: CanvasItem,
	rect: Rect2,
	is_horizontal: bool,
	color: Color,
	glow_color: Color,
	intensity: float,
	alpha: float,
	is_lit: bool
) -> void:
	if is_lit:
		var glow_alpha: float = clamp(intensity, 0.0, 1.6) * (42.0 / 255.0) * alpha
		canvas.draw_rect(rect.grow(max(2.0, rect.size.y * 0.55)), Color(glow_color.r, glow_color.g, glow_color.b, glow_alpha))
		_draw_beveled_segment(canvas, rect, is_horizontal, _alpha_color(color, alpha))
		_draw_beveled_segment(
			canvas,
			rect.grow(-max(0.7, rect.size.y * 0.22)),
			is_horizontal,
			_alpha_color(_brighten_color(color, 0.20), alpha * 0.72)
		)
	else:
		_draw_beveled_segment(canvas, rect.grow(-max(0.4, rect.size.y * 0.16)), is_horizontal, Color(color.r * 0.10, color.g * 0.10, color.b * 0.10, alpha * 0.35))


func _draw_beveled_segment(canvas: CanvasItem, rect: Rect2, is_horizontal: bool, color: Color) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var bevel: float = min(rect.size.x, rect.size.y) * 0.5
	var points := PackedVector2Array()
	if is_horizontal:
		var cy: float = rect.position.y + rect.size.y * 0.5
		points.append_array([
			Vector2(rect.position.x + bevel, rect.position.y),
			Vector2(rect.end.x - bevel, rect.position.y),
			Vector2(rect.end.x, cy),
			Vector2(rect.end.x - bevel, rect.end.y),
			Vector2(rect.position.x + bevel, rect.end.y),
			Vector2(rect.position.x, cy),
		])
	else:
		var cx: float = rect.position.x + rect.size.x * 0.5
		points.append_array([
			Vector2(cx, rect.position.y),
			Vector2(rect.end.x, rect.position.y + bevel),
			Vector2(rect.end.x, rect.end.y - bevel),
			Vector2(cx, rect.end.y),
			Vector2(rect.position.x, rect.end.y - bevel),
			Vector2(rect.position.x, rect.position.y + bevel),
		])
	canvas.draw_colored_polygon(points, color)


func _draw_led_dot(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	color: Color,
	glow_color: Color,
	intensity: float,
	alpha: float
) -> void:
	canvas.draw_circle(center, radius * 2.2, Color(glow_color.r, glow_color.g, glow_color.b, clamp(intensity, 0.0, 1.6) * (36.0 / 255.0) * alpha))
	canvas.draw_circle(center, radius, _alpha_color(color, alpha))
	canvas.draw_circle(center + Vector2(-radius * 0.28, -radius * 0.28), max(1.0, radius * 0.35), _alpha_color(_brighten_color(color, 0.24), alpha))


func _get_segment_digit_width(digit_height: float) -> float:
	return digit_height * 0.54


func _get_segment_thickness(digit_height: float) -> float:
	return max(2.0, digit_height * 0.115)


func _is_horizontal_segment(segment_id: String) -> bool:
	return segment_id == "a" or segment_id == "g" or segment_id == "d"


func _brighten_color(color: Color, amount: float) -> Color:
	return Color(
		min(1.0, color.r + amount),
		min(1.0, color.g + amount),
		min(1.0, color.b + amount),
		color.a
	)
