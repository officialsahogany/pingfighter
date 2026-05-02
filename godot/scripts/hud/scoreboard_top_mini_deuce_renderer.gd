extends RefCounted

const ScoreboardTopMiniDeuceEffectRenderer := preload("res://scripts/hud/scoreboard_top_mini_deuce_effect_renderer.gd")
const ScoreboardTopMiniTextRenderer := preload("res://scripts/hud/scoreboard_top_mini_text_renderer.gd")

var effect_renderer: Object = ScoreboardTopMiniDeuceEffectRenderer.new()
var text_renderer: Object = ScoreboardTopMiniTextRenderer.new()


func draw(
	canvas: Node2D,
	rect: Rect2,
	scale_factor: float,
	t: float,
	sparkle_intensity: float,
	player_score: int,
	boss_score: int
) -> void:
	var pulse: float = effect_renderer.draw(canvas, rect, scale_factor, t)

	var deuce_label_y: float = max(10.0 * scale_factor, rect.position.y - 12.0 * scale_factor)
	text_renderer.draw_score_text(
		canvas,
		Vector2(rect.get_center().x, deuce_label_y),
		"DEUCE!",
		max(10, int(11.0 * scale_factor)),
		Color(1.0, 1.0, 230.0 / 255.0),
		Color(100.0 / 255.0, 30.0 / 255.0, 5.0 / 255.0, 0.95),
		Color(1.0, 100.0 / 255.0, 0.0),
		pulse
	)

	var center_pos := rect.get_center() + Vector2(sin(t * 20.0), cos(t * 25.0) * 0.5) * scale_factor
	var font_size: int = max(20, int(42.0 * scale_factor))
	var score_offset: float = max(16.0, 28.0 * scale_factor)
	var glow_strength: float = max(0.7, pulse + sparkle_intensity * 0.4)
	text_renderer.draw_score_text(
		canvas,
		center_pos + Vector2(-score_offset, 0.0),
		str(player_score),
		font_size,
		Color(1.0, 1.0, 230.0 / 255.0),
		Color(100.0 / 255.0, 30.0 / 255.0, 5.0 / 255.0, 0.95),
		Color(1.0, 100.0 / 255.0, 0.0),
		glow_strength
	)
	text_renderer.draw_score_text(
		canvas,
		center_pos,
		":",
		font_size,
		Color(1.0, 220.0 / 255.0, 150.0 / 255.0),
		Color(100.0 / 255.0, 30.0 / 255.0, 5.0 / 255.0, 0.95),
		Color(1.0, 160.0 / 255.0, 30.0 / 255.0),
		glow_strength
	)
	text_renderer.draw_score_text(
		canvas,
		center_pos + Vector2(score_offset, 0.0),
		str(boss_score),
		font_size,
		Color(1.0, 1.0, 230.0 / 255.0),
		Color(100.0 / 255.0, 30.0 / 255.0, 5.0 / 255.0, 0.95),
		Color(1.0, 100.0 / 255.0, 0.0),
		glow_strength
	)
