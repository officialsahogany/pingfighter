extends RefCounted


func draw_slot_panel(canvas: Node2D, rect: Rect2, fill_color: Color, border_color: Color) -> void:
	canvas.draw_rect(rect, fill_color)
	canvas.draw_rect(rect, border_color, false, 1.0)
	canvas.draw_line(rect.position + Vector2(1.0, 1.0), Vector2(rect.end.x - 1.0, rect.position.y + 1.0), Color(1.0, 1.0, 1.0, 0.05), 1.0)
	canvas.draw_line(Vector2(rect.position.x + 1.0, rect.end.y - 1.0), rect.end - Vector2(1.0, 1.0), Color(0.0, 0.0, 0.0, 0.22), 1.0)
