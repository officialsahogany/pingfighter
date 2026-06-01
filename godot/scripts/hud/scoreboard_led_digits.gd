extends RefCounted

const ScoreboardLedDigitPatterns := preload("res://scripts/hud/scoreboard_led_digit_patterns.gd")

const LIT_GLOW_LAYER_COUNT := 1
const INACTIVE_LED_ALPHA := 0.54
const INACTIVE_LED_COLOR_SCALE := 0.075
const INACTIVE_LED_RADIUS_SCALE := 0.74

var digit_patterns: Object = ScoreboardLedDigitPatterns.new()
var lit_point_cache: Dictionary = {}
var lit_center_cache: Dictionary = {}
var matrix_center_cache: Dictionary = {}
var unlit_center_cache: Dictionary = {}
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
	glow_stride: int = 1,
	draw_inactive_sockets: bool = true,
	draw_highlight: bool = true
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
			spacing,
			draw_inactive_sockets,
			draw_highlight
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
	spacing: float,
	draw_inactive_sockets: bool,
	draw_highlight: bool
) -> void:
	var pattern: Array = digit_patterns.get_pattern(digit)
	var centers: Array[Vector2] = _get_lit_centers(digit, pattern, spacing)
	var glow_step: int = maxi(1, glow_stride)
	if draw_inactive_sockets:
		var unlit_centers: Array[Vector2] = _get_unlit_centers(digit, pattern, spacing)
		for unlit_center in unlit_centers:
			_draw_inactive_led(canvas, origin + unlit_center, color, dot_radius, alpha)
	for point_index in range(centers.size()):
		var dot_center: Vector2 = origin + centers[point_index]
		if point_index % glow_step == 0:
			_draw_led_glow(canvas, dot_center, color, dot_radius, intensity, alpha)
		_draw_lit_led(canvas, dot_center, color, dot_radius, alpha, draw_highlight)


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


func _get_matrix_centers(pattern: Array, spacing: float) -> Array[Vector2]:
	var row_count: int = pattern.size()
	var col_count: int = 0
	if row_count > 0:
		col_count = str(pattern[0]).length()
	var cache_key := "%d:%d:%d" % [row_count, col_count, int(spacing)]
	var cached: Variant = matrix_center_cache.get(cache_key, null)
	if cached is Array:
		return cached
	var centers: Array[Vector2] = []
	for row_idx in range(row_count):
		var row: String = str(pattern[row_idx])
		for col_idx in range(row.length()):
			centers.append(Vector2(
				float(col_idx) * spacing + spacing * 0.5,
				float(row_idx) * spacing + spacing * 0.5
			))
	matrix_center_cache[cache_key] = centers
	return centers


func _get_unlit_centers(digit: String, pattern: Array, spacing: float) -> Array[Vector2]:
	var cache_key := "%s:%d" % [digit, int(spacing)]
	var cached: Variant = unlit_center_cache.get(cache_key, null)
	if cached is Array:
		return cached
	var lit_points: Array[Vector2i] = _get_lit_points(digit, pattern)
	var lit_lookup: Dictionary = {}
	for point in lit_points:
		lit_lookup["%d:%d" % [point.x, point.y]] = true
	var centers: Array[Vector2] = []
	for row_idx in range(pattern.size()):
		var row: String = str(pattern[row_idx])
		for col_idx in range(row.length()):
			if lit_lookup.has("%d:%d" % [col_idx, row_idx]):
				continue
			centers.append(Vector2(
				float(col_idx) * spacing + spacing * 0.5,
				float(row_idx) * spacing + spacing * 0.5
			))
	unlit_center_cache[cache_key] = centers
	return centers


func _draw_inactive_led(canvas: Node2D, center: Vector2, color: Color, dot_radius: float, alpha: float) -> void:
	var dim_radius: float = max(1.0, dot_radius * INACTIVE_LED_RADIUS_SCALE)
	var dim_color := Color(
		max(10.0 / 255.0, color.r * INACTIVE_LED_COLOR_SCALE),
		max(10.0 / 255.0, color.g * INACTIVE_LED_COLOR_SCALE),
		max(10.0 / 255.0, color.b * INACTIVE_LED_COLOR_SCALE),
		INACTIVE_LED_ALPHA * alpha
	)
	canvas.draw_circle(center, dim_radius, dim_color)


func _draw_led_glow(
	canvas: Node2D,
	center: Vector2,
	color: Color,
	dot_radius: float,
	intensity: float,
	alpha: float
) -> void:
	for layer in range(LIT_GLOW_LAYER_COUNT, 0, -1):
		var layer_f: float = float(layer)
		var glow_radius: float = dot_radius + layer_f * 3.0
		var glow_alpha: float = (34.0 / 255.0) * intensity * alpha / layer_f
		canvas.draw_circle(center, glow_radius, Color(color.r, color.g, color.b, glow_alpha))


func _draw_lit_led(
	canvas: Node2D,
	center: Vector2,
	color: Color,
	dot_radius: float,
	alpha: float,
	draw_highlight: bool
) -> void:
	var core_color := Color(color.r, color.g, color.b, color.a * alpha)
	canvas.draw_circle(center, dot_radius, core_color)
	if not draw_highlight:
		return
	var highlight_color := Color(
		min(1.0, color.r + 150.0 / 255.0),
		min(1.0, color.g + 150.0 / 255.0),
		min(1.0, color.b + 150.0 / 255.0),
		alpha
	)
	var highlight_radius: float = max(1.0, dot_radius * 0.35)
	var highlight_offset := Vector2(-max(1.0, dot_radius * 0.32), -max(1.0, dot_radius * 0.32))
	canvas.draw_circle(center + highlight_offset, highlight_radius, highlight_color)
