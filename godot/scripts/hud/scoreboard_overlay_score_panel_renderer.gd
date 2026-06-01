extends RefCounted

const ScoreboardLedDigits := preload("res://scripts/hud/scoreboard_led_digits.gd")

const SCORE_PANEL_GLOW_STRIDE := 4
const SCORE_PANEL_DRAW_INACTIVE_SOCKETS := false
const SCORE_PANEL_DRAW_LED_HIGHLIGHT := false

var led_digits: Object = ScoreboardLedDigits.new()


func draw(
	canvas: Node2D,
	score_area: Rect2,
	center_x: float,
	frame: float,
	player_score: int,
	boss_score: int,
	alpha: float
) -> void:
	if canvas == null:
		return

	canvas.draw_rect(score_area, _rgb(5.0, 12.0, 30.0, alpha))
	canvas.draw_rect(score_area, _rgb(60.0, 120.0, 200.0, alpha), false, 3.0)
	canvas.draw_line(
		Vector2(center_x, score_area.position.y + 5.0),
		Vector2(center_x, score_area.position.y + score_area.size.y - 5.0),
		_rgb(60.0, 120.0, 200.0, alpha),
		3.0
	)

	var breath_pulse: float = 0.4 + 0.6 * sin(frame * 0.08)
	var flash_cycle: float = fmod(frame, 180.0) / 180.0
	var flash: float = 1.0
	if flash_cycle > 0.9:
		flash = 1.0 + 0.5 * sin((flash_cycle - 0.9) * 10.0 * PI)
	var combined_pulse: float = clamp(breath_pulse * flash, 0.3, 1.5)

	var led_size: float = min(100.0, score_area.size.y - 25.0) * 1.2
	var dot_radius: float = max(3.0, floor(led_size / 30.0))
	var left_area_width: float = center_x - score_area.position.x
	var right_area_width: float = (score_area.position.x + score_area.size.x) - center_x
	var player_color: Color = Color(
		min(1.0, (120.0 / 255.0) * combined_pulse),
		min(1.0, (220.0 / 255.0) * combined_pulse),
		min(1.0, combined_pulse)
	)
	var boss_color: Color = Color(
		min(1.0, combined_pulse),
		min(1.0, (130.0 / 255.0) * combined_pulse),
		min(1.0, (130.0 / 255.0) * combined_pulse)
	)
	var player_digit_width: float = led_digits.get_number_width(player_score, led_size)
	var boss_digit_width: float = led_digits.get_number_width(boss_score, led_size)
	var digit_y: float = score_area.position.y + (score_area.size.y - led_size) * 0.5
	led_digits.draw_number(
		canvas,
		Vector2(score_area.position.x + (left_area_width - player_digit_width) * 0.5, digit_y),
		player_score,
		player_color,
		led_size,
		dot_radius,
		0.4 + combined_pulse,
		alpha,
		SCORE_PANEL_GLOW_STRIDE,
		SCORE_PANEL_DRAW_INACTIVE_SOCKETS,
		SCORE_PANEL_DRAW_LED_HIGHLIGHT
	)
	led_digits.draw_number(
		canvas,
		Vector2(center_x + (right_area_width - boss_digit_width) * 0.5, digit_y),
		boss_score,
		boss_color,
		led_size,
		dot_radius,
		0.4 + combined_pulse,
		alpha,
		SCORE_PANEL_GLOW_STRIDE,
		SCORE_PANEL_DRAW_INACTIVE_SOCKETS,
		SCORE_PANEL_DRAW_LED_HIGHLIGHT
	)

	var vs_rect: Rect2 = Rect2(center_x - 28.0, score_area.position.y + score_area.size.y * 0.5 - 22.0, 56.0, 44.0)
	canvas.draw_rect(vs_rect, _rgb(15.0, 35.0, 70.0, alpha))
	canvas.draw_rect(vs_rect, _rgb(80.0, 160.0, 255.0, alpha), false, 2.0)
	_draw_text_centered(canvas, vs_rect.get_center(), "VS", 20, _rgb(120.0, 200.0, 255.0, 1.0), alpha)


func _draw_text_centered(canvas: Node2D, center: Vector2, text: String, font_size: int, color: Color, alpha: float) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline: Vector2 = Vector2(center.x - text_size.x * 0.5, center.y + text_size.y * 0.35)
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, _alpha_color(color, alpha))


func _alpha_color(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * clamp(alpha, 0.0, 1.0))


func _rgb(r: float, g: float, b: float, alpha: float) -> Color:
	return Color(r / 255.0, g / 255.0, b / 255.0, clamp(alpha, 0.0, 1.0))
