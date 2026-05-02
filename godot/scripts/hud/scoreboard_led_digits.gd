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

const SEGMENT_POINTS := {
	"a": [Vector2(0.20, 0.10), Vector2(0.80, 0.10)],
	"b": [Vector2(0.86, 0.16), Vector2(0.86, 0.46)],
	"c": [Vector2(0.86, 0.54), Vector2(0.86, 0.84)],
	"d": [Vector2(0.20, 0.90), Vector2(0.80, 0.90)],
	"e": [Vector2(0.14, 0.54), Vector2(0.14, 0.84)],
	"f": [Vector2(0.14, 0.16), Vector2(0.14, 0.46)],
	"g": [Vector2(0.20, 0.50), Vector2(0.80, 0.50)],
}
const SEGMENT_DRAW_ORDER := ["a", "b", "c", "d", "e", "f", "g"]


func draw_number(
	canvas: Node2D,
	origin: Vector2,
	value: int,
	color: Color,
	size: float,
	dot_radius: float,
	intensity: float,
	alpha: float
) -> void:
	var text := str(value)
	var digit_width: float = _get_digit_width(size)
	var digit_pitch: float = digit_width + max(8.0, size * 0.10)
	for digit_idx in range(text.length()):
		_draw_digit(
			canvas,
			origin + Vector2(float(digit_idx) * digit_pitch, 0.0),
			text.substr(digit_idx, 1),
			color,
			size,
			dot_radius,
			intensity,
			alpha
		)


func get_number_width(value: int, size: float) -> float:
	var digits: int = max(1, str(value).length())
	return float(digits) * _get_digit_width(size) + float(max(0, digits - 1)) * max(8.0, size * 0.10)


func _draw_digit(
	canvas: Node2D,
	origin: Vector2,
	digit: String,
	color: Color,
	size: float,
	dot_radius: float,
	intensity: float,
	alpha: float
) -> void:
	var active_segments: Array = DIGIT_SEGMENTS.get(digit, DIGIT_SEGMENTS["0"])
	var digit_size := Vector2(_get_digit_width(size), size)
	var thickness: float = max(dot_radius * 2.2, size * 0.085)
	for segment_name in SEGMENT_DRAW_ORDER:
		_draw_segment(
			canvas,
			origin,
			digit_size,
			segment_name,
			active_segments.has(segment_name),
			color,
			thickness,
			intensity,
			alpha
		)


func _draw_segment(
	canvas: Node2D,
	origin: Vector2,
	digit_size: Vector2,
	segment_name: String,
	active: bool,
	color: Color,
	thickness: float,
	intensity: float,
	alpha: float
) -> void:
	var points: Array = SEGMENT_POINTS.get(segment_name, [])
	if points.size() < 2:
		return
	var start_point: Vector2 = points[0]
	var end_point: Vector2 = points[1]
	var start: Vector2 = origin + Vector2(start_point.x * digit_size.x, start_point.y * digit_size.y)
	var end: Vector2 = origin + Vector2(end_point.x * digit_size.x, end_point.y * digit_size.y)
	if active:
		var pulse_alpha: float = clamp(alpha * intensity, 0.0, 1.0)
		canvas.draw_line(start, end, Color(color.r, color.g, color.b, pulse_alpha * 0.18), thickness * 2.4)
		canvas.draw_line(start, end, Color(color.r, color.g, color.b, pulse_alpha * 0.28), thickness * 1.55)
		canvas.draw_line(start, end, Color(color.r, color.g, color.b, clamp(alpha, 0.0, 1.0)), thickness)
	else:
		canvas.draw_line(start, end, Color(color.r * 0.18, color.g * 0.18, color.b * 0.18, alpha * 0.20), thickness * 0.65)


func _get_digit_width(size: float) -> float:
	return size * 0.62
