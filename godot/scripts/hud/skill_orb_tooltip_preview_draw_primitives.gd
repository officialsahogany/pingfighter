extends RefCounted

func draw_preview_pentagon(canvas: CanvasItem, center: Vector2, radius: float, rotation_deg: float, fill_color: Color, outline_color: Color = Color(0.0, 0.0, 0.0, 0.0), outline_width: float = 0.0) -> void:
	draw_preview_pentagon_xf(canvas, center, radius, rotation_deg, fill_color, 0.0, center, outline_color, outline_width)


func draw_preview_pentagon_xf(canvas: CanvasItem, center: Vector2, radius: float, rotation_deg: float, fill_color: Color, rotation: float, rotation_center: Vector2, outline_color: Color = Color(0.0, 0.0, 0.0, 0.0), outline_width: float = 0.0) -> void:
	var points := PackedVector2Array()
	for i in range(5):
		var angle: float = deg_to_rad(rotation_deg + float(i) * 72.0)
		points.append(rotate_point(center + Vector2(cos(angle), sin(angle)) * radius, rotation, rotation_center))
	if fill_color.a > 0.0:
		canvas.draw_colored_polygon(points, fill_color)
	if outline_width > 0.0 and outline_color.a > 0.0:
		var outline := PackedVector2Array(points)
		outline.append(points[0])
		canvas.draw_polyline(outline, outline_color, outline_width)


func draw_ellipse(canvas: CanvasItem, rect: Rect2, color: Color, filled: bool, width: float = 1.0) -> void:
	var points := ellipse_points(rect, 32)
	if filled:
		canvas.draw_colored_polygon(points, color)
	else:
		points.append(points[0])
		canvas.draw_polyline(points, color, width)


func draw_ellipse_xf(canvas: CanvasItem, rect: Rect2, color: Color, filled: bool, width: float, rotation: float, rotation_center: Vector2) -> void:
	var points := ellipse_points(rect, 32)
	for i in range(points.size()):
		points[i] = rotate_point(points[i], rotation, rotation_center)
	if filled:
		canvas.draw_colored_polygon(points, color)
	else:
		points.append(points[0])
		canvas.draw_polyline(points, color, width)


func draw_ellipse_arc(canvas: CanvasItem, rect: Rect2, start_angle: float, end_angle: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	var center: Vector2 = rect.get_center()
	var rx: float = rect.size.x * 0.5
	var ry: float = rect.size.y * 0.5
	for i in range(28):
		var t: float = float(i) / 27.0
		var angle: float = start_angle + (end_angle - start_angle) * t
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	canvas.draw_polyline(points, color, width)


func ellipse_points(rect: Rect2, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var center: Vector2 = rect.get_center()
	var rx: float = rect.size.x * 0.5
	var ry: float = rect.size.y * 0.5
	for i in range(segments):
		var angle: float = TAU * float(i) / float(segments)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	return points


func draw_rect_xf(canvas: CanvasItem, rect: Rect2, color: Color, rotation: float, rotation_center: Vector2) -> void:
	draw_poly_xf(canvas, [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)], color, rotation, rotation_center)


func draw_rect_outline_xf(canvas: CanvasItem, rect: Rect2, color: Color, width: float, rotation: float, rotation_center: Vector2) -> void:
	var points := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y), rect.position])
	for i in range(points.size()):
		points[i] = rotate_point(points[i], rotation, rotation_center)
	canvas.draw_polyline(points, color, width)


func draw_poly_xf(canvas: CanvasItem, points_array: Array, color: Color, rotation: float, rotation_center: Vector2) -> void:
	var points := PackedVector2Array()
	for p in points_array:
		if p is Vector2:
			points.append(rotate_point(p, rotation, rotation_center))
	canvas.draw_colored_polygon(points, color)


func draw_line_xf(canvas: CanvasItem, start: Vector2, finish: Vector2, color: Color, width: float, rotation: float, rotation_center: Vector2) -> void:
	canvas.draw_line(rotate_point(start, rotation, rotation_center), rotate_point(finish, rotation, rotation_center), color, width)


func draw_circle_xf(canvas: CanvasItem, center: Vector2, radius: float, color: Color, rotation: float, rotation_center: Vector2) -> void:
	canvas.draw_circle(rotate_point(center, rotation, rotation_center), radius, color)


func rotate_point(point: Vector2, angle: float, pivot: Vector2) -> Vector2:
	if is_zero_approx(angle):
		return point
	return pivot + (point - pivot).rotated(angle)


func draw_round_rect(canvas: CanvasItem, rect: Rect2, color: Color, corner_radius: float) -> void:
	draw_panel(canvas, rect, color, Color(0.0, 0.0, 0.0, 0.0), 0.0, corner_radius)


func draw_round_rect_outline(canvas: CanvasItem, rect: Rect2, color: Color, corner_radius: float, width: float) -> void:
	draw_panel(canvas, rect, Color(0.0, 0.0, 0.0, 0.0), color, width, corner_radius)


func rainbow_color(t: float) -> Color:
	return Color.from_hsv(fposmod(t, 1.0), 1.0, 1.0)


func color8(r: float, g: float, b: float, a: float = 255.0) -> Color:
	return Color(r / 255.0, g / 255.0, b / 255.0, clamp(a, 0.0, 255.0) / 255.0)


func alpha(color: Color, alpha_value: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * clamp(alpha_value, 0.0, 1.0))


func tint(color: Color, tint_color: Color) -> Color:
	return Color(color.r * tint_color.r, color.g * tint_color.g, color.b * tint_color.b, color.a)

func draw_panel(canvas: CanvasItem, rect: Rect2, fill_color: Color, border_color: Color, border_width: float, corner_radius: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	var width: int = max(0, int(round(border_width)))
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	var radius: int = max(0, int(round(corner_radius)))
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	canvas.draw_style_box(style, rect)


func get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func get_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback
