extends RefCounted

const ScoreboardTopMiniNormalDecorationRenderer := preload("res://scripts/hud/scoreboard_top_mini_normal_decoration_renderer.gd")

var decoration_renderer: Object = ScoreboardTopMiniNormalDecorationRenderer.new()


func draw_background(canvas: Node2D, rect: Rect2, scale_factor: float, sparkle_intensity: float) -> void:
	var glow_margin: float = max(4.0, 6.0 * scale_factor)
	var glow_alpha: float = (40.0 + 60.0 * sparkle_intensity) / 255.0
	for layer in range(3):
		var layer_grow: float = glow_margin + float(layer) * 2.0
		canvas.draw_rect(
			rect.grow(layer_grow),
			Color(1.0, 215.0 / 255.0, 100.0 / 255.0, glow_alpha * (0.45 - float(layer) * 0.10))
		)

	for yi in range(int(rect.size.y)):
		var ratio: float = float(yi) / max(1.0, rect.size.y)
		var r: float = (35.0 - 15.0 * ratio) / 255.0
		var g: float = (30.0 - 10.0 * ratio) / 255.0
		var b: float = (50.0 - 20.0 * ratio) / 255.0
		if sparkle_intensity > 0.0:
			r = min(1.0, r + (30.0 / 255.0) * sparkle_intensity)
			g = min(1.0, g + (25.0 / 255.0) * sparkle_intensity)
			b = min(1.0, b + (20.0 / 255.0) * sparkle_intensity)
		canvas.draw_line(
			Vector2(rect.position.x, rect.position.y + float(yi)),
			Vector2(rect.end.x, rect.position.y + float(yi)),
			Color(r, g, b, 230.0 / 255.0),
			1.0
		)

	canvas.draw_line(
		rect.position + Vector2(4.0, 2.0),
		Vector2(rect.end.x - 4.0, rect.position.y + 2.0),
		Color(1.0, 1.0, 1.0, (30.0 + 40.0 * sparkle_intensity) / 255.0),
		1.0
	)

	var border_brightness: float = 180.0 + 75.0 * sparkle_intensity
	canvas.draw_rect(
		rect,
		Color(border_brightness / 255.0, border_brightness * 0.75 / 255.0, 50.0 / 255.0),
		false,
		2.0
	)
	canvas.draw_rect(rect.grow(-2.0), Color(100.0 / 255.0, 80.0 / 255.0, 30.0 / 255.0, 150.0 / 255.0), false, 1.0)

	decoration_renderer.draw_score_diamonds(canvas, rect, scale_factor, sparkle_intensity)


func draw_sparkles(
	canvas: Node2D,
	rect: Rect2,
	scale_factor: float,
	sparkle_progress: float,
	sparkle_intensity: float
) -> void:
	decoration_renderer.draw_sparkles(canvas, rect, scale_factor, sparkle_progress, sparkle_intensity)
