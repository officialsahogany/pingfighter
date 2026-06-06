extends RefCounted

const PILLAR_GOLD_BRIGHT := Color(0.92, 0.79, 0.46)
const GAME_BORDER_SHINE_LAYERS := 2
const GAME_BORDER_SHINE_LAYERS_LOD := 1
const GAME_BORDER_SHINE_LOD_THRESHOLD := 0.85


func draw_hanji_subtle_borders(canvas: CanvasItem, view_size: Vector2, game_rect: Rect2, scale_factor: float) -> void:
	var s: float = max(1.0, round(scale_factor))
	var line_width: float = max(1.0, s)
	_draw_view_border(canvas, view_size, 8.0 * s, Color(239.0 / 255.0, 226.0 / 255.0, 190.0 / 255.0, 88.0 / 255.0), line_width)
	_draw_view_border(canvas, view_size, 12.0 * s, Color(72.0 / 255.0, 64.0 / 255.0, 47.0 / 255.0, 96.0 / 255.0), line_width)
	_draw_view_border(canvas, view_size, 18.0 * s, Color(35.0 / 255.0, 58.0 / 255.0, 82.0 / 255.0, 70.0 / 255.0), line_width)

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


func _draw_view_border(canvas: CanvasItem, view_size: Vector2, inset: float, line_color: Color, line_width: float) -> void:
	var rect := Rect2(Vector2(inset, inset), view_size - Vector2(inset * 2.0, inset * 2.0))
	if rect.size.x > 0.0 and rect.size.y > 0.0:
		canvas.draw_rect(rect, line_color, false, line_width)


func draw_game_border_shine(canvas: CanvasItem, game_rect: Rect2, scale_factor: float, time: float, quality_scale: float = 1.0, alpha_multiplier: float = 1.0) -> void:
	var shine: float = (30.0 + 15.0 * sin(time * 2.0)) / 255.0
	var s: float = max(1.0, scale_factor)
	var layer_count: int = GAME_BORDER_SHINE_LAYERS_LOD if quality_scale < GAME_BORDER_SHINE_LOD_THRESHOLD else GAME_BORDER_SHINE_LAYERS
	for i in range(layer_count):
		var alpha: float = (shine - float(i) * (10.0 / 255.0)) * max(0.0, alpha_multiplier)
		if alpha <= 0.0:
			continue
		var rect: Rect2 = game_rect.grow((8.0 + float(i)) * s)
		canvas.draw_rect(rect, Color(PILLAR_GOLD_BRIGHT.r, PILLAR_GOLD_BRIGHT.g, PILLAR_GOLD_BRIGHT.b, alpha), false, 1.0)
