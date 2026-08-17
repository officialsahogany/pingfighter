extends RefCounted

const KEY_LABEL_SINGLE_Y_OFFSET := 0.48
const KEY_LABEL_COMBO_Y_OFFSET := 0.50


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
	elif skill_name == "soul_summon_art":
		_draw_soul_summon_art_symbol(canvas, center, icon_radius, color, symbol_color)
	elif skill_name == "dalji_vision_chain_top":
		_draw_dalji_vision_chain_top_symbol(canvas, center, icon_radius, color, symbol_color)
	elif skill_name == "cheongringwi_vision_dragon_torrent":
		_draw_cheongringwi_vision_dragon_torrent_symbol(canvas, center, icon_radius, color, symbol_color)
	elif skill_name == "yeonmyo_vision_bonghongwe":
		_draw_yeonmyo_vision_bonghongwe_symbol(canvas, center, icon_radius, color, symbol_color)
	elif skill_name.begins_with("horn_strawberry_"):
		_draw_horn_strawberry_symbol(canvas, center, icon_radius, skill_name, color, symbol_color, is_active)
	else:
		var inactive_color: Color = Color(color.r * 0.45, color.g * 0.45, color.b * 0.45, 0.85)
		canvas.draw_circle(center, icon_radius * 0.34, color if is_active else inactive_color)


func _draw_soul_summon_art_symbol(
	canvas: CanvasItem,
	center: Vector2,
	icon_radius: float,
	color: Color,
	symbol_color: Color
) -> void:
	var egg := PackedVector2Array()
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		egg.append(center + Vector2(
			sin(angle) * icon_radius * (0.31 + 0.05 * maxf(0.0, cos(angle))),
			-cos(angle) * icon_radius * 0.45 + icon_radius * 0.07
		))
	canvas.draw_colored_polygon(egg, Color(symbol_color.r, symbol_color.g, symbol_color.b, 0.92))
	var outline := egg.duplicate()
	outline.append(egg[0])
	canvas.draw_polyline(outline, color, maxf(1.2, icon_radius * 0.07), true)
	canvas.draw_polyline(PackedVector2Array([
		center + Vector2(-icon_radius * 0.04, -icon_radius * 0.20),
		center + Vector2(icon_radius * 0.08, -icon_radius * 0.05),
		center + Vector2(-icon_radius * 0.02, icon_radius * 0.05),
		center + Vector2(icon_radius * 0.09, icon_radius * 0.18),
	]), color, maxf(1.3, icon_radius * 0.075), true)


func _draw_dalji_vision_chain_top_symbol(
	canvas: CanvasItem,
	center: Vector2,
	icon_radius: float,
	color: Color,
	symbol_color: Color
) -> void:
	var rim_color := Color(0.96, 0.76, 0.28, symbol_color.a)
	var moon_color := Color(0.66, 1.0, 0.94, symbol_color.a)
	var top_centers: Array[Vector2] = [
		center + Vector2(-icon_radius * 0.27, -icon_radius * 0.08),
		center + Vector2(icon_radius * 0.27, -icon_radius * 0.08),
	]
	for index in range(top_centers.size()):
		var top_center: Vector2 = top_centers[index]
		var side := -1.0 if index == 0 else 1.0
		var body := PackedVector2Array([
			top_center + Vector2(-icon_radius * 0.18, -icon_radius * 0.06),
			top_center + Vector2(icon_radius * 0.18, -icon_radius * 0.06),
			top_center + Vector2(icon_radius * 0.07, icon_radius * 0.14),
			top_center + Vector2(0.0, icon_radius * 0.23),
			top_center + Vector2(-icon_radius * 0.07, icon_radius * 0.14),
		])
		canvas.draw_colored_polygon(body, Color(color.r * 0.42, color.g * 0.42, color.b * 0.42, 0.94))
		canvas.draw_arc(top_center, icon_radius * 0.17, 0.0, TAU, 16, rim_color, maxf(1.3, icon_radius * 0.065), true)
		canvas.draw_circle(top_center, icon_radius * 0.055, moon_color)
		canvas.draw_arc(
			top_center + Vector2(-side * icon_radius * 0.05, -icon_radius * 0.02),
			icon_radius * 0.30,
			-PI * 0.85 if side < 0.0 else PI * 0.15,
			PI * 0.15 if side < 0.0 else PI * 1.15,
			16,
			Color(moon_color.r, moon_color.g, moon_color.b, 0.58),
			maxf(1.0, icon_radius * 0.045),
			true
		)
	var ball_center := center + Vector2(0.0, icon_radius * 0.25)
	canvas.draw_circle(ball_center, icon_radius * 0.13, Color(color.r, color.g, color.b, 0.42))
	canvas.draw_circle(ball_center, icon_radius * 0.085, symbol_color)
	canvas.draw_arc(ball_center, icon_radius * 0.18, 0.0, TAU, 18, moon_color, maxf(1.0, icon_radius * 0.045), true)


func _draw_cheongringwi_vision_dragon_torrent_symbol(
	canvas: CanvasItem,
	center: Vector2,
	icon_radius: float,
	color: Color,
	symbol_color: Color
) -> void:
	var earth_color := Color(0.82, 0.60, 0.20, symbol_color.a)
	var rock_center := center + Vector2(0.0, -icon_radius * 0.12)
	var rock_points := PackedVector2Array([
		rock_center + Vector2(-icon_radius * 0.36, icon_radius * 0.18),
		rock_center + Vector2(-icon_radius * 0.22, -icon_radius * 0.30),
		rock_center + Vector2(icon_radius * 0.08, -icon_radius * 0.42),
		rock_center + Vector2(icon_radius * 0.36, -icon_radius * 0.12),
		rock_center + Vector2(icon_radius * 0.28, icon_radius * 0.28),
		rock_center + Vector2(-icon_radius * 0.10, icon_radius * 0.38),
	])
	canvas.draw_colored_polygon(rock_points, Color(color.r, color.g, color.b, 0.72))
	rock_points.append(rock_points[0])
	canvas.draw_polyline(rock_points, symbol_color, maxf(1.2, icon_radius * 0.06), true)
	canvas.draw_line(rock_center + Vector2(-icon_radius * 0.05, -icon_radius * 0.28), rock_center + Vector2(icon_radius * 0.02, icon_radius * 0.12), earth_color, maxf(1.0, icon_radius * 0.055), true)
	canvas.draw_line(rock_center + Vector2(icon_radius * 0.02, icon_radius * 0.12), rock_center + Vector2(icon_radius * 0.17, icon_radius * 0.25), earth_color, maxf(1.0, icon_radius * 0.055), true)
	for side: float in [-1.0, 1.0]:
		var wave_center := center + Vector2(side * icon_radius * 0.22, icon_radius * 0.33)
		canvas.draw_arc(wave_center, icon_radius * 0.22, 0.15, PI - 0.15, 12, earth_color, maxf(1.0, icon_radius * 0.05), true)


func _draw_yeonmyo_vision_bonghongwe_symbol(
	canvas: CanvasItem,
	center: Vector2,
	icon_radius: float,
	color: Color,
	symbol_color: Color
) -> void:
	var body := Rect2(
		center + Vector2(-icon_radius * 0.48, -icon_radius * 0.16),
		Vector2(icon_radius * 0.96, icon_radius * 0.58)
	)
	canvas.draw_rect(body, Color(color.r * 0.48, color.g * 0.34, color.b * 0.58, 0.96), true)
	canvas.draw_rect(body, symbol_color, false, maxf(1.3, icon_radius * 0.07))
	var lid := Rect2(
		center + Vector2(-icon_radius * 0.53, -icon_radius * 0.34),
		Vector2(icon_radius * 1.06, icon_radius * 0.26)
	)
	canvas.draw_rect(lid, color, true)
	canvas.draw_rect(lid, symbol_color, false, maxf(1.2, icon_radius * 0.055))
	canvas.draw_circle(center + Vector2(0.0, icon_radius * 0.12), icon_radius * 0.10, Color(1.0, 0.78, 0.30, 1.0))
	canvas.draw_arc(center, icon_radius * 0.73, PI * 0.08, PI * 0.92, 20, Color(color.r, color.g, color.b, 0.68), maxf(1.0, icon_radius * 0.045), true)


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
	var bolt_points := PackedVector2Array([
		center + Vector2(-icon_radius * 0.08, -icon_radius * 0.62),
		center + Vector2(-icon_radius * 0.34, -icon_radius * 0.02),
		center + Vector2(-icon_radius * 0.04, -icon_radius * 0.02),
		center + Vector2(-icon_radius * 0.20, icon_radius * 0.64),
		center + Vector2(icon_radius * 0.38, -icon_radius * 0.16),
		center + Vector2(icon_radius * 0.08, -icon_radius * 0.16),
	])
	canvas.draw_polyline(bolt_points, Color(color.r, color.g, color.b, 0.72), max(3.0, icon_radius * 0.20), true)
	canvas.draw_polyline(bolt_points, symbol_color, max(1.4, icon_radius * 0.08), true)
	for i in range(4):
		var angle: float = -PI * 0.75 + float(i) * PI * 0.50
		var start: Vector2 = center + Vector2(cos(angle), sin(angle)) * icon_radius * 0.30
		var end: Vector2 = center + Vector2(cos(angle), sin(angle)) * icon_radius * 0.54
		canvas.draw_line(start, end, color if i % 2 == 0 else symbol_color, max(1.0, icon_radius * 0.06), true)


func _draw_horn_strawberry_symbol(
	canvas: CanvasItem,
	center: Vector2,
	icon_radius: float,
	skill_name: String,
	_color: Color,
	symbol_color: Color,
	is_active: bool
) -> void:
	var alpha: float = 1.0 if is_active else 0.58
	var berry_color := Color(0.95, 0.12, 0.20, alpha)
	var leaf_color := Color(0.25, 0.88, 0.34, alpha)
	var accent_color := Color(symbol_color.r, symbol_color.g, symbol_color.b, alpha)
	match skill_name:
		"horn_strawberry_horn_charge":
			_draw_horn_charge_icon(canvas, center, icon_radius, berry_color, leaf_color, accent_color)
			_draw_key_label(canvas, center + Vector2(0.0, icon_radius * KEY_LABEL_SINGLE_Y_OFFSET), "W", icon_radius, accent_color)
		"horn_strawberry_field":
			_draw_field_icon(canvas, center, icon_radius, berry_color, leaf_color, accent_color)
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
	berry_color: Color,
	leaf_color: Color,
	symbol_color: Color
) -> void:
	var motif_center := center + Vector2(0.0, -icon_radius * 0.17)
	var horn_fill := Color(1.0, 0.73, 0.25, berry_color.a)
	var horn_outline := Color(0.20, 0.07, 0.035, 0.96 * berry_color.a)
	var left_horn := PackedVector2Array([
		motif_center + Vector2(-icon_radius * 0.17, -icon_radius * 0.06),
		motif_center + Vector2(-icon_radius * 0.64, -icon_radius * 0.52),
		motif_center + Vector2(-icon_radius * 0.36, -icon_radius * 0.58),
		motif_center + Vector2(-icon_radius * 0.07, -icon_radius * 0.19),
	])
	var right_horn := PackedVector2Array([
		motif_center + Vector2(icon_radius * 0.17, -icon_radius * 0.06),
		motif_center + Vector2(icon_radius * 0.64, -icon_radius * 0.52),
		motif_center + Vector2(icon_radius * 0.36, -icon_radius * 0.58),
		motif_center + Vector2(icon_radius * 0.07, -icon_radius * 0.19),
	])
	canvas.draw_colored_polygon(left_horn, horn_fill)
	canvas.draw_colored_polygon(right_horn, horn_fill)
	_draw_closed_polyline(canvas, left_horn, horn_outline, maxf(1.0, icon_radius * 0.065))
	_draw_closed_polyline(canvas, right_horn, horn_outline, maxf(1.0, icon_radius * 0.065))

	canvas.draw_circle(motif_center, icon_radius * 0.29, horn_outline)
	canvas.draw_circle(motif_center, icon_radius * 0.235, berry_color)
	var leaf_crown := PackedVector2Array([
		motif_center + Vector2(-icon_radius * 0.24, -icon_radius * 0.20),
		motif_center + Vector2(-icon_radius * 0.07, -icon_radius * 0.38),
		motif_center + Vector2(0.0, -icon_radius * 0.22),
		motif_center + Vector2(icon_radius * 0.10, -icon_radius * 0.39),
		motif_center + Vector2(icon_radius * 0.24, -icon_radius * 0.20),
	])
	canvas.draw_colored_polygon(leaf_crown, leaf_color)
	canvas.draw_circle(motif_center + Vector2(-icon_radius * 0.08, -icon_radius * 0.01), icon_radius * 0.035, symbol_color)
	canvas.draw_circle(motif_center + Vector2(icon_radius * 0.08, -icon_radius * 0.01), icon_radius * 0.035, symbol_color)

	for side in [-1.0, 1.0]:
		for streak_index in range(2):
			var y_offset: float = icon_radius * (-0.02 + float(streak_index) * 0.13)
			var start := motif_center + Vector2(side * icon_radius * 0.70, y_offset)
			var end := motif_center + Vector2(side * icon_radius * (0.47 + float(streak_index) * 0.03), y_offset)
			canvas.draw_line(start, end, Color(symbol_color.r, symbol_color.g, symbol_color.b, 0.72), maxf(1.0, icon_radius * 0.055), true)


func _draw_field_icon(
	canvas: CanvasItem,
	center: Vector2,
	icon_radius: float,
	berry_color: Color,
	leaf_color: Color,
	symbol_color: Color
) -> void:
	var field_center := center + Vector2(0.0, -icon_radius * 0.05)
	var soil_color := Color(0.20, 0.07, 0.035, 0.92 * berry_color.a)
	var field_points := _ellipse_points(field_center, icon_radius * 0.66, icon_radius * 0.28, 24)
	canvas.draw_colored_polygon(field_points, soil_color)
	_draw_closed_polyline(canvas, field_points, Color(symbol_color.r, symbol_color.g, symbol_color.b, 0.76), maxf(1.0, icon_radius * 0.055))
	for row_index in range(3):
		var row_y: float = field_center.y - icon_radius * 0.12 + float(row_index) * icon_radius * 0.12
		var row_half_width: float = icon_radius * (0.46 - float(row_index) * 0.035)
		canvas.draw_line(
			Vector2(field_center.x - row_half_width, row_y),
			Vector2(field_center.x + row_half_width, row_y),
			Color(leaf_color.r, leaf_color.g, leaf_color.b, 0.72),
			maxf(1.0, icon_radius * 0.055),
			true
		)
	for plant_index in range(3):
		var plant_x: float = field_center.x + (float(plant_index) - 1.0) * icon_radius * 0.31
		var berry_center := Vector2(plant_x, field_center.y - icon_radius * (0.22 + float(plant_index % 2) * 0.05))
		canvas.draw_line(berry_center, berry_center + Vector2(0.0, icon_radius * 0.16), leaf_color, maxf(1.0, icon_radius * 0.05), true)
		canvas.draw_circle(berry_center, icon_radius * 0.105, berry_color)
		canvas.draw_line(berry_center + Vector2(-icon_radius * 0.03, -icon_radius * 0.07), berry_center + Vector2(-icon_radius * 0.11, -icon_radius * 0.13), leaf_color, maxf(1.0, icon_radius * 0.045), true)
		canvas.draw_line(berry_center + Vector2(icon_radius * 0.03, -icon_radius * 0.07), berry_center + Vector2(icon_radius * 0.11, -icon_radius * 0.13), leaf_color, maxf(1.0, icon_radius * 0.045), true)


func _draw_eat_icon(
	canvas: CanvasItem,
	center: Vector2,
	icon_radius: float,
	berry_color: Color,
	leaf_color: Color,
	symbol_color: Color
) -> void:
	var berry_center := center + Vector2(-icon_radius * 0.05, -icon_radius * 0.19)
	var outline_color := Color(0.20, 0.055, 0.04, 0.96 * berry_color.a)
	_draw_strawberry(canvas, berry_center, icon_radius * 0.90, berry_color, leaf_color, outline_color, symbol_color)
	var bite_color := Color(0.075, 0.035, 0.028, 0.95 * berry_color.a)
	for bite_offset in [
		Vector2(icon_radius * 0.29, -icon_radius * 0.18),
		Vector2(icon_radius * 0.34, -icon_radius * 0.04),
		Vector2(icon_radius * 0.28, icon_radius * 0.10),
	]:
		canvas.draw_circle(berry_center + bite_offset, icon_radius * 0.095, bite_color)
	for ray_index in range(3):
		var angle: float = -0.72 + float(ray_index) * 0.72
		var ray_start := berry_center + Vector2(icon_radius * 0.44, 0.0) + Vector2(cos(angle), sin(angle)) * icon_radius * 0.07
		var ray_end := berry_center + Vector2(icon_radius * 0.44, 0.0) + Vector2(cos(angle), sin(angle)) * icon_radius * 0.20
		canvas.draw_line(ray_start, ray_end, symbol_color, maxf(1.0, icon_radius * 0.045), true)


func _draw_bomb_icon(canvas: CanvasItem, center: Vector2, icon_radius: float, berry_color: Color, symbol_color: Color) -> void:
	var bomb_center := center + Vector2(-icon_radius * 0.08, -icon_radius * 0.14)
	var bomb_outline := Color(0.12, 0.035, 0.028, 0.98 * berry_color.a)
	var bomb_fill := Color(0.76, 0.06, 0.10, berry_color.a)
	var leaf_color := Color(0.24, 0.76, 0.28, berry_color.a)
	canvas.draw_circle(bomb_center, icon_radius * 0.40, Color(0.07, 0.025, 0.02, 0.54 * berry_color.a))
	_draw_strawberry(canvas, bomb_center, icon_radius * 0.80, bomb_fill, leaf_color, bomb_outline, symbol_color)
	var fuse_start := bomb_center + Vector2(icon_radius * 0.11, -icon_radius * 0.39)
	var fuse_mid := bomb_center + Vector2(icon_radius * 0.25, -icon_radius * 0.55)
	var fuse_end := bomb_center + Vector2(icon_radius * 0.45, -icon_radius * 0.50)
	canvas.draw_polyline(PackedVector2Array([fuse_start, fuse_mid, fuse_end]), bomb_outline, maxf(2.0, icon_radius * 0.10), true)
	canvas.draw_polyline(PackedVector2Array([fuse_start, fuse_mid, fuse_end]), Color(1.0, 0.65, 0.18, berry_color.a), maxf(1.0, icon_radius * 0.045), true)
	canvas.draw_circle(fuse_end, icon_radius * 0.085, Color(1.0, 0.82, 0.22, berry_color.a))
	for spark_index in range(5):
		var angle: float = TAU * float(spark_index) / 5.0
		var spark_start := fuse_end + Vector2(cos(angle), sin(angle)) * icon_radius * 0.11
		var spark_end := fuse_end + Vector2(cos(angle), sin(angle)) * icon_radius * 0.21
		canvas.draw_line(spark_start, spark_end, Color(symbol_color.r, symbol_color.g * 0.82, 0.20, berry_color.a), maxf(1.0, icon_radius * 0.04), true)


func _draw_strawberry(
	canvas: CanvasItem,
	center: Vector2,
	size: float,
	berry_color: Color,
	leaf_color: Color,
	outline_color: Color,
	highlight_color: Color
) -> void:
	var berry_points := PackedVector2Array([
		center + Vector2(-size * 0.34, -size * 0.22),
		center + Vector2(-size * 0.44, -size * 0.02),
		center + Vector2(-size * 0.34, size * 0.23),
		center + Vector2(-size * 0.17, size * 0.41),
		center + Vector2(0.0, size * 0.52),
		center + Vector2(size * 0.17, size * 0.41),
		center + Vector2(size * 0.34, size * 0.23),
		center + Vector2(size * 0.44, -size * 0.02),
		center + Vector2(size * 0.34, -size * 0.22),
		center + Vector2(0.0, -size * 0.30),
	])
	canvas.draw_colored_polygon(berry_points, berry_color)
	_draw_closed_polyline(canvas, berry_points, outline_color, maxf(1.0, size * 0.065))
	var leaf_points := PackedVector2Array([
		center + Vector2(-size * 0.36, -size * 0.21),
		center + Vector2(-size * 0.12, -size * 0.38),
		center + Vector2(0.0, -size * 0.25),
		center + Vector2(size * 0.13, -size * 0.40),
		center + Vector2(size * 0.36, -size * 0.21),
		center + Vector2(size * 0.13, -size * 0.16),
		center + Vector2(0.0, -size * 0.07),
		center + Vector2(-size * 0.14, -size * 0.16),
	])
	canvas.draw_colored_polygon(leaf_points, leaf_color)
	for seed_offset in [
		Vector2(-0.18, 0.02),
		Vector2(0.10, -0.01),
		Vector2(-0.07, 0.22),
		Vector2(0.17, 0.25),
		Vector2(0.0, 0.39),
	]:
		var seed_center := center + Vector2(seed_offset.x * size, seed_offset.y * size)
		canvas.draw_line(seed_center, seed_center + Vector2(0.0, size * 0.065), highlight_color, maxf(1.0, size * 0.035), true)


func _ellipse_points(center: Vector2, radius_x: float, radius_y: float, point_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point_index in range(point_count):
		var angle: float = TAU * float(point_index) / float(point_count)
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points


func _draw_closed_polyline(canvas: CanvasItem, points: PackedVector2Array, color: Color, width: float) -> void:
	if points.is_empty():
		return
	var closed_points := points.duplicate()
	closed_points.append(points[0])
	canvas.draw_polyline(closed_points, color, width, true)


func _draw_key_label(canvas: CanvasItem, center: Vector2, text: String, icon_radius: float, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var font_size: int = max(7, int(round(icon_radius * 0.42)))
	if text.length() >= 3:
		font_size = max(6, int(round(icon_radius * 0.31)))
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var cap_height: float = maxf(float(font_size) + 4.0, icon_radius * 0.40)
	var cap_width: float = maxf(text_size.x + 8.0, cap_height + 4.0)
	var cap_radius: float = cap_height * 0.5
	var left_center := center + Vector2(-cap_width * 0.5 + cap_radius, 0.0)
	var right_center := center + Vector2(cap_width * 0.5 - cap_radius, 0.0)
	var cap_fill := Color(0.055, 0.025, 0.02, 0.90 * maxf(0.58, color.a))
	var cap_outline := Color(1.0, 0.74, 0.30, 0.82 * color.a)
	canvas.draw_rect(
		Rect2(Vector2(left_center.x, center.y - cap_radius), Vector2(right_center.x - left_center.x, cap_height)),
		cap_fill,
		true
	)
	canvas.draw_circle(left_center, cap_radius, cap_fill)
	canvas.draw_circle(right_center, cap_radius, cap_fill)
	canvas.draw_line(Vector2(left_center.x, center.y - cap_radius), Vector2(right_center.x, center.y - cap_radius), cap_outline, 1.0, true)
	canvas.draw_line(Vector2(left_center.x, center.y + cap_radius), Vector2(right_center.x, center.y + cap_radius), cap_outline, 1.0, true)
	canvas.draw_arc(left_center, cap_radius, PI * 0.5, PI * 1.5, 8, cap_outline, 1.0, true)
	canvas.draw_arc(right_center, cap_radius, -PI * 0.5, PI * 0.5, 8, cap_outline, 1.0, true)
	canvas.draw_string(
		font,
		center + Vector2(-text_size.x * 0.5, text_size.y * 0.35),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		color
	)
