extends RefCounted

const ScoreboardLedDigitPatterns := preload("res://scripts/hud/scoreboard_led_digit_patterns.gd")

var digit_patterns: Object = ScoreboardLedDigitPatterns.new()
var lit_point_cache: Dictionary = {}
var lit_center_cache: Dictionary = {}
var number_width_cache: Dictionary = {}


func draw_number(
	canvas: Node2D,
	origin: Vector2,
	value: int,
	color: Color,
	size: float,
	dot_radius: float,
	intensity: float,
	alpha: float,
	glow_stride: int = 1
) -> void:
	var text := str(value)
	var spacing: float = floor(size / 11.0)
	var digit_pitch: float = 7.0 * spacing + spacing * 1.35
	for digit_idx in range(text.length()):
		_draw_digit(
			canvas,
			origin + Vector2(float(digit_idx) * digit_pitch, 0.0),
			text.substr(digit_idx, 1),
			color,
			dot_radius,
			intensity,
			alpha,
			glow_stride,
			spacing
		)


func get_number_width(value: int, size: float) -> float:
	var spacing: float = floor(size / 11.0)
	var digits: int = max(1, str(value).length())
	var cache_key := "%d:%d" % [digits, int(spacing)]
	if number_width_cache.has(cache_key):
		return float(number_width_cache.get(cache_key, 0.0))
	var width: float = float(digits) * 7.0 * spacing + float(max(0, digits - 1)) * spacing * 1.35
	number_width_cache[cache_key] = width
	return width


func _draw_digit(
	canvas: Node2D,
	origin: Vector2,
	digit: String,
	color: Color,
	dot_radius: float,
	intensity: float,
	alpha: float,
	glow_stride: int,
	spacing: float
) -> void:
	var pattern: Array = digit_patterns.get_pattern(digit)
	var glow_color := Color(color.r, color.g, color.b, (34.0 / 255.0) * intensity * alpha)
	var core_color := Color(color.r, color.g, color.b, color.a * alpha)
	var glow_radius: float = dot_radius + 3.0
	var centers: Array[Vector2] = _get_lit_centers(digit, pattern, spacing)
	var glow_step: int = maxi(1, glow_stride)
	for point_index in range(centers.size()):
		var dot_center: Vector2 = origin + centers[point_index]
		if point_index % glow_step == 0:
			canvas.draw_circle(dot_center, glow_radius, glow_color)
		canvas.draw_circle(dot_center, dot_radius, core_color)


func _get_lit_points(digit: String, pattern: Array) -> Array[Vector2i]:
	var cached: Variant = lit_point_cache.get(digit, null)
	if cached is Array:
		return cached
	var points: Array[Vector2i] = []
	for row_idx in range(pattern.size()):
		var row: String = pattern[row_idx]
		for col_idx in range(row.length()):
			if row.substr(col_idx, 1) == "1":
				points.append(Vector2i(col_idx, row_idx))
	lit_point_cache[digit] = points
	return points


func _get_lit_centers(digit: String, pattern: Array, spacing: float) -> Array[Vector2]:
	var cache_key := "%s:%d" % [digit, int(spacing)]
	var cached: Variant = lit_center_cache.get(cache_key, null)
	if cached is Array:
		return cached
	var points: Array[Vector2i] = _get_lit_points(digit, pattern)
	var centers: Array[Vector2] = []
	for point in points:
		centers.append(Vector2(
			float(point.x) * spacing + spacing * 0.5,
			float(point.y) * spacing + spacing * 0.5
		))
	lit_center_cache[cache_key] = centers
	return centers
