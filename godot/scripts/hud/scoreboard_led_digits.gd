extends RefCounted

const ScoreboardLedDigitPatterns := preload("res://scripts/hud/scoreboard_led_digit_patterns.gd")
const ScoreboardLedDotRenderer := preload("res://scripts/hud/scoreboard_led_dot_renderer.gd")

var digit_patterns: Object = ScoreboardLedDigitPatterns.new()
var dot_renderer: Object = ScoreboardLedDotRenderer.new()


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
	var spacing: float = floor(size / 11.0)
	var digit_pitch: float = 7.0 * spacing + spacing * 1.35
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
	var spacing: float = floor(size / 11.0)
	var digits: int = max(1, str(value).length())
	return float(digits) * 7.0 * spacing + float(max(0, digits - 1)) * spacing * 1.35


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
	var pattern: Array = digit_patterns.get_pattern(digit)
	var spacing: float = floor(size / 11.0)
	for row_idx in range(pattern.size()):
		var row: String = pattern[row_idx]
		for col_idx in range(row.length()):
			var dot_center := Vector2(
				origin.x + float(col_idx) * spacing + spacing * 0.5,
				origin.y + float(row_idx) * spacing + spacing * 0.5
			)
			dot_renderer.draw_premium_led(
				canvas,
				dot_center,
				color,
				dot_radius,
				intensity,
				row.substr(col_idx, 1) == "1",
				alpha
			)
