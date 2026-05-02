extends RefCounted


func draw(canvas: Node2D, rect: Rect2, alpha: float) -> void:
	if canvas == null:
		return
	var x: float = rect.position.x
	var y: float = rect.position.y
	var w: float = rect.size.x
	var h: float = rect.size.y
	var thickness: float = 18.0

	canvas.draw_rect(Rect2(x + 5.0, y + 5.0, w + 10.0, h + 10.0), Color(0.0, 0.0, 0.0, 80.0 / 255.0 * alpha))
	canvas.draw_rect(rect, _rgb(5.0, 15.0, 35.0, alpha))
	canvas.draw_rect(Rect2(x, y, w, thickness), _rgb(40.0, 80.0, 140.0, alpha))
	canvas.draw_rect(Rect2(x, y + h - thickness, w, thickness), _rgb(31.0, 62.0, 108.0, alpha))
	canvas.draw_rect(Rect2(x, y, thickness, h), _rgb(45.0, 88.0, 148.0, alpha))
	canvas.draw_rect(Rect2(x + w - thickness, y, thickness, h), _rgb(28.0, 58.0, 105.0, alpha))
	canvas.draw_line(Vector2(x, y), Vector2(x + w - 1.0, y), _rgb(90.0, 140.0, 200.0, alpha), 2.0)
	canvas.draw_line(Vector2(x, y), Vector2(x, y + h - 1.0), _rgb(90.0, 140.0, 200.0, alpha), 2.0)
	canvas.draw_line(Vector2(x + 1.0, y + h - 1.0), Vector2(x + w, y + h - 1.0), _rgb(10.0, 35.0, 80.0, alpha), 3.0)
	canvas.draw_line(Vector2(x + w - 1.0, y + 1.0), Vector2(x + w - 1.0, y + h), _rgb(10.0, 35.0, 80.0, alpha), 3.0)
	_draw_corner_bolts(canvas, x, y, w, h, thickness, alpha)


func _draw_corner_bolts(
	canvas: Node2D,
	x: float,
	y: float,
	w: float,
	h: float,
	thickness: float,
	alpha: float
) -> void:
	var bolt_positions: Array[Vector2] = [
		Vector2(x + thickness * 0.5, y + thickness * 0.5),
		Vector2(x + w - thickness * 0.5, y + thickness * 0.5),
		Vector2(x + thickness * 0.5, y + h - thickness * 0.5),
		Vector2(x + w - thickness * 0.5, y + h - thickness * 0.5),
	]
	for bolt_pos in bolt_positions:
		canvas.draw_circle(bolt_pos, 8.0, _rgb(40.0, 45.0, 50.0, alpha))
		canvas.draw_circle(bolt_pos, 6.0, _rgb(60.0, 65.0, 70.0, alpha))
		canvas.draw_line(bolt_pos + Vector2(-4.0, 0.0), bolt_pos + Vector2(4.0, 0.0), _rgb(50.0, 55.0, 60.0, alpha), 2.0)
		canvas.draw_line(bolt_pos + Vector2(0.0, -4.0), bolt_pos + Vector2(0.0, 4.0), _rgb(50.0, 55.0, 60.0, alpha), 2.0)
		canvas.draw_circle(bolt_pos + Vector2(-2.0, -2.0), 2.0, _rgb(90.0, 95.0, 100.0, alpha))


func _rgb(r: float, g: float, b: float, alpha: float) -> Color:
	return Color(r / 255.0, g / 255.0, b / 255.0, clamp(alpha, 0.0, 1.0))
