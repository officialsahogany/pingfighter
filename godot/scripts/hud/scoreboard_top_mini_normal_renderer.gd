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
	boss_score: int
) -> void:
	chrome_renderer.draw_background(canvas, rect, scale_factor, sparkle_intensity)

	var font_size: int = max(18, int(36.0 * scale_factor))
	var center_pos := rect.get_center()
	var score_offset: float = max(16.0, 28.0 * scale_factor)
	text_renderer.draw_score_text(
		canvas,
		center_pos + Vector2(-score_offset, 1.0 * scale_factor),
		str(player_score),
		font_size,
		Color(100.0 / 255.0, 180.0 / 255.0, 1.0),
		Color(0.0, 0.0, 0.0, 0.95),
		Color(100.0 / 255.0, 180.0 / 255.0, 1.0),
		0.35 + sparkle_intensity * 0.55
	)
	text_renderer.draw_score_text(
		canvas,
		center_pos + Vector2(0.0, 1.0 * scale_factor),
		":",
		font_size,
		Color.WHITE,
		Color(0.0, 0.0, 0.0, 0.95),
		Color(1.0, 1.0, 220.0 / 255.0),
		0.18 + sparkle_intensity * 0.45
	)
	text_renderer.draw_score_text(
		canvas,
		center_pos + Vector2(score_offset, 1.0 * scale_factor),
		str(boss_score),
		font_size,
		Color(1.0, 100.0 / 255.0, 100.0 / 255.0),
		Color(0.0, 0.0, 0.0, 0.95),
		Color(1.0, 100.0 / 255.0, 100.0 / 255.0),
		0.35 + sparkle_intensity * 0.55
	)

	chrome_renderer.draw_sparkles(canvas, rect, scale_factor, sparkle_progress, sparkle_intensity)
