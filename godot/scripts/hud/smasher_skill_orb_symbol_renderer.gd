extends RefCounted

const KEY_LABEL_SINGLE_Y_OFFSET := 0.32
const KEY_LABEL_COMBO_Y_OFFSET := 0.36


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
	elif skill_name.begins_with("horn_strawberry_"):
		_draw_horn_strawberry_symbol(canvas, center, icon_radius, skill_name, color, symbol_color, is_active)
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


func _draw_horn_strawberry_symbol(
	canvas: CanvasItem,
	center: Vector2,
	icon_radius: float,
	skill_name: String,
	color: Color,
	symbol_color: Color,
	is_active: bool
) -> void:
	var alpha: float = 1.0 if is_active else 0.58
	var berry_color := Color(0.95, 0.12, 0.20, alpha)
	var leaf_color := Color(0.25, 0.88, 0.34, alpha)
	var accent_color := Color(symbol_color.r, symbol_color.g, symbol_color.b, alpha)
	match skill_name:
		"horn_strawberry_horn_charge":
			_draw_horn_charge_icon(canvas, center, icon_radius, color, accent_color)
			_draw_key_label(canvas, center + Vector2(0.0, icon_radius * KEY_LABEL_SINGLE_Y_OFFSET), "W", icon_radius, accent_color)
		"horn_strawberry_field":
			_draw_field_icon(canvas, center, icon_radius, berry_color, leaf_color)
			_draw_key_label(canvas, center + Vector2(0.0, icon_radius * KEY_LABEL_SINGLE_Y_OFFSET), "S", icon_radius, accent_color)
		"horn_strawberry_eat":
			_draw_eat_icon(canvas, center, icon_radius, berry_color, leaf_color, accent_color)
			_draw_key_label(canvas, center + Vector2(0.0, icon_radius * KEY_LABEL_COMBO_Y_OFFSET), "SP", icon_radius, accent_color)
		"horn_strawberry_bomb":
			_draw_bomb_icon(canvas, center, icon_radius, berry_color, accent_color)
			_draw_key_label(canvas, center + Vector2(0.0, icon_radius * KEY_LABEL_COMBO_Y_OFFSET), "A+D", icon_radius, accent_color)
		_:
			canvas.draw_circle(center, icon_radius * 0.34, berry_color)


func _draw_horn_charge_icon(
	canvas: CanvasItem,
	center: Vector2,
	icon_radius: float,
	color: Color,
	symbol_color: Color
) -> void:
	var horn_tip := center + Vector2(0.0, -icon_radius * 0.68)
	var left_base := center + Vector2(-icon_radius * 0.36, icon_radius * 0.12)
	var right_base := center + Vector2(icon_radius * 0.36, icon_radius * 0.12)
	canvas.draw_colored_polygon(PackedVector2Array([horn_tip, left_base, right_base]), Color(color.r, color.g, color.b, 0.82))
	canvas.draw_line(left_base, horn_tip, symbol_color, max(1.0, icon_radius * 0.10))
	canvas.draw_line(right_base, horn_tip, symbol_color, max(1.0, icon_radius * 0.10))
	for i in range(3):
		var start := center + Vector2(-icon_radius * (0.66 - float(i) * 0.18), icon_radius * (0.08 + float(i) * 0.08))
		var end := start + Vector2(icon_radius * 0.28, 0.0)
		canvas.draw_line(start, end, Color(symbol_color.r, symbol_color.g, symbol_color.b, 0.55), max(1.0, icon_radius * 0.07))


func _draw_field_icon(canvas: CanvasItem, center: Vector2, icon_radius: float, berry_color: Color, leaf_color: Color) -> void:
	for i in range(3):
		var y: float = center.y - icon_radius * 0.22 + float(i) * icon_radius * 0.18
		canvas.draw_line(
			Vector2(center.x - icon_radius * 0.52, y),
			Vector2(center.x + icon_radius * 0.52, y),
			Color(berry_color.r, berry_color.g, berry_color.b, 0.70 - float(i) * 0.10),
			max(1.0, icon_radius * 0.10)
		)
	canvas.draw_arc(center, icon_radius * 0.44, PI * 0.08, PI * 0.92, 18, Color(leaf_color.r, leaf_color.g, leaf_color.b, 0.75), max(1.0, icon_radius * 0.08))


func _draw_eat_icon(
	canvas: CanvasItem,
	center: Vector2,
	icon_radius: float,
	berry_color: Color,
	leaf_color: Color,
	symbol_color: Color
) -> void:
	var berry_center := center + Vector2(-icon_radius * 0.10, -icon_radius * 0.12)
	canvas.draw_circle(berry_center, icon_radius * 0.34, berry_color)
	canvas.draw_circle(berry_center + Vector2(-icon_radius * 0.10, -icon_radius * 0.08), icon_radius * 0.10, Color(1.0, 0.56, 0.60, berry_color.a))
	canvas.draw_line(
		berry_center + Vector2(-icon_radius * 0.08, -icon_radius * 0.34),
		berry_center + Vector2(icon_radius * 0.10, -icon_radius * 0.52),
		leaf_color,
		max(1.0, icon_radius * 0.08)
	)
	for i in range(3):
		var stem_start := center + Vector2(icon_radius * 0.20, -icon_radius * (0.18 - float(i) * 0.15))
		var stem_end := stem_start + Vector2(icon_radius * 0.34, -icon_radius * (0.18 - float(i) * 0.18))
		canvas.draw_line(stem_start, stem_end, symbol_color, max(1.0, icon_radius * 0.07))
		canvas.draw_circle(stem_end, icon_radius * 0.06, leaf_color)


func _draw_bomb_icon(canvas: CanvasItem, center: Vector2, icon_radius: float, berry_color: Color, symbol_color: Color) -> void:
	for i in range(3):
		var offset := Vector2((float(i) - 1.0) * icon_radius * 0.28, -icon_radius * (0.04 + float(i % 2) * 0.10))
		var bomb_center := center + offset
		canvas.draw_circle(bomb_center, icon_radius * 0.18, berry_color)
		canvas.draw_line(
			bomb_center + Vector2(0.0, -icon_radius * 0.18),
			bomb_center + Vector2(icon_radius * 0.12, -icon_radius * 0.32),
			symbol_color,
			max(1.0, icon_radius * 0.06)
		)
	canvas.draw_arc(center, icon_radius * 0.50, -PI * 0.86, -PI * 0.24, 14, Color(symbol_color.r, symbol_color.g, symbol_color.b, 0.58), max(1.0, icon_radius * 0.07))


func _draw_key_label(canvas: CanvasItem, center: Vector2, text: String, icon_radius: float, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var font_size: int = max(7, int(round(icon_radius * 0.42)))
	if text.length() >= 3:
		font_size = max(6, int(round(icon_radius * 0.31)))
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	canvas.draw_string(
		font,
		center - Vector2(text_size.x * 0.5, -text_size.y * 0.35),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		color
	)
