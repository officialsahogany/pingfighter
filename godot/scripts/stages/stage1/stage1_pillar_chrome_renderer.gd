extends RefCounted

const PILLAR_GOLD_BRIGHT := Color(0.92, 0.79, 0.46)


func draw_hanji_subtle_borders(canvas: CanvasItem, view_size: Vector2, game_rect: Rect2, scale_factor: float) -> void:
	var s: float = max(1.0, round(scale_factor))
	var border_specs: Array[Dictionary] = [
		{"inset": 8.0 * s, "color": Color(239.0 / 255.0, 226.0 / 255.0, 190.0 / 255.0, 88.0 / 255.0), "width": max(1.0, s)},
		{"inset": 12.0 * s, "color": Color(72.0 / 255.0, 64.0 / 255.0, 47.0 / 255.0, 96.0 / 255.0), "width": max(1.0, s)},
		{"inset": 18.0 * s, "color": Color(35.0 / 255.0, 58.0 / 255.0, 82.0 / 255.0, 70.0 / 255.0), "width": max(1.0, s)},
	]
	for spec in border_specs:
		var inset: float = float(spec["inset"])
		var line_color: Color = spec["color"]
		var line_width: float = float(spec["width"])
		var rect := Rect2(Vector2(inset, inset), view_size - Vector2(inset * 2.0, inset * 2.0))
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			canvas.draw_rect(rect, line_color, false, line_width)

	var frame_rect: Rect2 = game_rect.grow(10.0 * s)
	canvas.draw_rect(frame_rect, Color(56.0 / 255.0, 48.0 / 255.0, 34.0 / 255.0, 108.0 / 255.0), false, max(2.0, 2.0 * s))
	canvas.draw_rect(frame_rect.grow(-4.0 * s), Color(231.0 / 255.0, 214.0 / 255.0, 172.0 / 255.0, 90.0 / 255.0), false, max(1.0, s))
	if view_size.y > game_rect.end.y:
		var y: float = game_rect.end.y + max(3.0, 4.0 * s)
		canvas.draw_line(
			Vector2(max(0.0, game_rect.position.x - 24.0 * s), y),
			Vector2(min(view_size.x, game_rect.end.x + 24.0 * s), y),
			Color(44.0 / 255.0, 60.0 / 255.0, 74.0 / 255.0, 72.0 / 255.0),
			max(1.0, s)
		)


func draw_game_border_shine(canvas: CanvasItem, game_rect: Rect2, scale_factor: float, time: float) -> void:
	var shine: float = (30.0 + 15.0 * sin(time * 2.0)) / 255.0
	var s: float = max(1.0, scale_factor)
	for i in range(3):
		var alpha: float = shine - float(i) * (10.0 / 255.0)
		if alpha <= 0.0:
			continue
		var rect: Rect2 = game_rect.grow((8.0 + float(i)) * s)
		canvas.draw_rect(rect, Color(PILLAR_GOLD_BRIGHT.r, PILLAR_GOLD_BRIGHT.g, PILLAR_GOLD_BRIGHT.b, alpha), false, 1.0)
