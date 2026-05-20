extends RefCounted

const ScoreboardTopMiniNormalChromeRenderer := preload("res://scripts/hud/scoreboard_top_mini_normal_chrome_renderer.gd")
const ScoreboardTopMiniTextRenderer := preload("res://scripts/hud/scoreboard_top_mini_text_renderer.gd")

var chrome_renderer: Object = ScoreboardTopMiniNormalChromeRenderer.new()
var text_renderer: Object = ScoreboardTopMiniTextRenderer.new()


func draw(
	canvas: Node2D,
	rect: Rect2,
	scale_factor: float,
	sparkle_progress: float,
	sparkle_intensity: float,
	player_score: int,
	boss_score: int,
	quality_scale: float = 1.0
) -> void:
	chrome_renderer.draw_background(canvas, rect, scale_factor, sparkle_intensity, quality_scale)

	var layout: Dictionary = _get_score_layout(rect, scale_factor)
	var digit_height: float = _get_digit_height(
		layout.get("player_rect", Rect2()),
		layout.get("boss_rect", Rect2()),
		player_score,
		boss_score
	)
	var pulse: float = 0.82 + sparkle_intensity * 0.45
	text_renderer.draw_segment_number(
		canvas,
		layout.get("player_rect", Rect2()).get_center(),
		player_score,
		digit_height,
		Color(100.0 / 255.0, 180.0 / 255.0, 1.0),
		Color(100.0 / 255.0, 180.0 / 255.0, 1.0),
		pulse,
		1.0
	)
	text_renderer.draw_segment_colon(
		canvas,
		layout.get("colon_center", rect.get_center()),
		digit_height,
		Color(1.0, 1.0, 220.0 / 255.0),
		Color(1.0, 1.0, 220.0 / 255.0),
		0.50 + sparkle_intensity * 0.35,
		1.0
	)
	text_renderer.draw_segment_number(
		canvas,
		layout.get("boss_rect", Rect2()).get_center(),
		boss_score,
		digit_height,
		Color(1.0, 100.0 / 255.0, 100.0 / 255.0),
		Color(1.0, 100.0 / 255.0, 100.0 / 255.0),
		pulse,
		1.0
	)

	chrome_renderer.draw_sparkles(canvas, rect, scale_factor, sparkle_progress, sparkle_intensity, quality_scale)


func _get_score_layout(rect: Rect2, scale_factor: float) -> Dictionary:
	var side_pad: float = max(8.0, 9.0 * scale_factor)
	var top_pad: float = max(5.0, 5.0 * scale_factor)
	var center_gap: float = max(28.0, 28.0 * scale_factor)
	var score_width: float = (rect.size.x - side_pad * 2.0 - center_gap) * 0.5
	var score_height: float = rect.size.y - top_pad * 2.0
	var player_rect := Rect2(rect.position.x + side_pad, rect.position.y + top_pad, score_width, score_height)
	var boss_rect := Rect2(rect.end.x - side_pad - score_width, rect.position.y + top_pad, score_width, score_height)
	return {
		"player_rect": player_rect,
		"boss_rect": boss_rect,
		"colon_center": Vector2(rect.get_center().x, rect.get_center().y + max(0.0, scale_factor * 0.35)),
	}


func _get_digit_height(player_rect: Rect2, boss_rect: Rect2, player_score: int, boss_score: int) -> float:
	var digit_height: float = min(player_rect.size.y * 0.76, boss_rect.size.y * 0.76)
	var min_digit_height: float = max(18.0, min(player_rect.size.y, boss_rect.size.y) * 0.52)
	while digit_height > min_digit_height:
		var player_size: Vector2 = text_renderer.get_segment_number_size(player_score, digit_height)
		var boss_size: Vector2 = text_renderer.get_segment_number_size(boss_score, digit_height)
		if player_size.x <= player_rect.size.x * 0.88 and boss_size.x <= boss_rect.size.x * 0.88:
			break
		digit_height -= 1.0
	return digit_height
