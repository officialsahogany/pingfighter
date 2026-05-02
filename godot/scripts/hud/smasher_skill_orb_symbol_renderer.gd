extends RefCounted


func draw(
	canvas: CanvasItem,
	center: Vector2,
	icon_radius: float,
	skill_name: String,
	color: Color,
	is_active: bool
) -> void:
	var symbol_color: Color = Color.WHITE if is_active else Color(0.55, 0.55, 0.55)
	if skill_name == "drive":
		_draw_drive_symbol(canvas, center, icon_radius, color, symbol_color)
	elif skill_name == "power_smashing":
		_draw_power_smashing_symbol(canvas, center, icon_radius, color, symbol_color)
	else:
		var inactive_color: Color = Color(color.r * 0.45, color.g * 0.45, color.b * 0.45, 0.85)
		canvas.draw_circle(center, icon_radius * 0.34, color if is_active else inactive_color)


func _draw_drive_symbol(
	canvas: CanvasItem,
	center: Vector2,
	icon_radius: float,
	color: Color,
	symbol_color: Color
) -> void:
	for i in range(5):
		var a0: float = -PI * 0.5 + float(i) * TAU / 5.0
		var a1: float = a0 + PI / 5.0
		canvas.draw_line(center, center + Vector2(cos(a0), sin(a0)) * icon_radius * 0.62, symbol_color, 2.0)
		canvas.draw_line(
			center + Vector2(cos(a0), sin(a0)) * icon_radius * 0.62,
			center + Vector2(cos(a1), sin(a1)) * icon_radius * 0.28,
			color,
			2.0
		)


func _draw_power_smashing_symbol(
	canvas: CanvasItem,
	center: Vector2,
	icon_radius: float,
	color: Color,
	symbol_color: Color
) -> void:
	for i in range(8):
		var angle: float = float(i) * TAU / 8.0
		var end: Vector2 = center + Vector2(cos(angle), sin(angle)) * icon_radius * (0.42 + 0.18 * float(i % 2))
		canvas.draw_line(center, end, color if i % 2 == 0 else symbol_color, 2.0)
	canvas.draw_circle(center, icon_radius * 0.24, symbol_color)
