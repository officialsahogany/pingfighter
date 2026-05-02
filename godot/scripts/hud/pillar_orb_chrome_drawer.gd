extends RefCounted

const PillarShapeHelper := preload("res://scripts/hud/pillar_shape_helper.gd")

const ORB_FRAME_BASE_RADIUS := 55.0
const ORB_FRAME_BASE_SIZE := 196.0

var shape_helper: Object = PillarShapeHelper.new()


func get_orb_frame_draw_size(radius: float) -> float:
	return max(1.0, round(radius * ORB_FRAME_BASE_SIZE / ORB_FRAME_BASE_RADIUS))


func draw_rotating_orb_frame_texture(
	canvas: CanvasItem,
	texture: Texture2D,
	center: Vector2,
	radius: float,
	spin_angle_degrees: float
) -> bool:
	if canvas == null or texture == null:
		return false

	var frame_size: float = get_orb_frame_draw_size(radius)
	var frame_vector := Vector2(frame_size, frame_size)
	if abs(spin_angle_degrees) > 0.01:
		canvas.draw_set_transform(center, -deg_to_rad(spin_angle_degrees), Vector2.ONE)
		canvas.draw_texture_rect(texture, Rect2(-frame_vector * 0.5, frame_vector), false)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		canvas.draw_texture_rect(texture, Rect2(center - frame_vector * 0.5, frame_vector), false)
	return true


func draw_pillar_orb_frame(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	frame_width: float,
	metal_dark: Color,
	metal_mid: Color,
	metal_light: Color,
	gem_core: Color,
	gem_highlight: Color
) -> void:
	if canvas == null:
		return

	canvas.draw_circle(center, radius + frame_width, metal_dark)
	canvas.draw_arc(center, radius + frame_width - 1.0, 0.0, TAU, 48, Color(metal_mid.r, metal_mid.g, metal_mid.b, 0.95), 4.0)
	canvas.draw_arc(center, radius + frame_width - 4.5, 0.0, TAU, 48, Color(metal_light.r, metal_light.g, metal_light.b, 0.82), 2.0)
	canvas.draw_arc(center, radius + frame_width - 5.5, deg_to_rad(200.0), deg_to_rad(340.0), 22, Color(1.0, 0.97, 0.86, 0.62), 3.0)
	canvas.draw_arc(center, radius + frame_width - 5.5, deg_to_rad(20.0), deg_to_rad(160.0), 22, Color(0.12, 0.08, 0.05, 0.62), 3.0)
	canvas.draw_arc(center, radius + 1.5, 0.0, TAU, 48, Color(0.08, 0.06, 0.04, 0.85), 2.0)

	for i in range(8):
		var angle: float = -PI * 0.5 + float(i) * TAU / 8.0
		var stud_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * (radius + frame_width * 0.55)
		canvas.draw_circle(stud_pos, frame_width * 0.58, Color(metal_dark.r * 0.70, metal_dark.g * 0.70, metal_dark.b * 0.70, 1.0))
		canvas.draw_circle(stud_pos, frame_width * 0.48, metal_mid)
		canvas.draw_circle(stud_pos, frame_width * 0.36, metal_light)
		canvas.draw_circle(stud_pos, frame_width * 0.24, gem_core)
		canvas.draw_circle(stud_pos + Vector2(-1.0, -1.0), frame_width * 0.11, Color(gem_highlight.r, gem_highlight.g, gem_highlight.b, 0.90))

	for angle_deg in [315.0, 45.0, 225.0, 135.0]:
		var angle: float = deg_to_rad(angle_deg)
		var bolt_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * (radius + frame_width * 0.92)
		canvas.draw_circle(bolt_pos, frame_width * 0.60, Color(metal_dark.r * 0.82, metal_dark.g * 0.82, metal_dark.b * 0.82, 1.0))
		canvas.draw_circle(bolt_pos, frame_width * 0.50, metal_mid)
		canvas.draw_circle(bolt_pos, frame_width * 0.38, metal_light)
		canvas.draw_circle(bolt_pos, frame_width * 0.24, gem_core)
		canvas.draw_circle(bolt_pos + Vector2(-1.0, -1.0), frame_width * 0.12, Color(gem_highlight.r, gem_highlight.g, gem_highlight.b, 0.72))


func draw_pillar_orb_glass(canvas: CanvasItem, center: Vector2, radius: float, rim_color: Color) -> void:
	if canvas == null:
		return

	var highlight_rect_1 := Rect2(center.x - radius + 8.0, center.y - radius + 5.0, radius + 12.0, radius * 0.55)
	var highlight_rect_2 := Rect2(center.x - radius + 14.0, center.y - radius + 11.0, max(8.0, radius - 10.0), radius * 0.36)
	var highlight_rect_3 := Rect2(center.x - radius + 18.0, center.y - radius + 15.0, max(7.0, radius * 0.56), max(6.0, radius * 0.25))
	canvas.draw_colored_polygon(shape_helper.build_ellipse_points(highlight_rect_1, 24), Color(1.0, 1.0, 1.0, 0.12))
	canvas.draw_colored_polygon(shape_helper.build_ellipse_points(highlight_rect_2, 24), Color(1.0, 1.0, 1.0, 0.18))
	canvas.draw_colored_polygon(shape_helper.build_ellipse_points(highlight_rect_3, 20), Color(1.0, 1.0, 1.0, 0.22))
	canvas.draw_circle(center + Vector2(-radius * 0.34, -radius * 0.34), max(1.5, radius * 0.06), Color(1.0, 1.0, 1.0, 0.72))
	canvas.draw_circle(center + Vector2(-radius * 0.30, -radius * 0.30), max(1.0, radius * 0.04), Color(1.0, 1.0, 1.0, 0.42))
	canvas.draw_arc(center, radius - 2.0, deg_to_rad(30.0), deg_to_rad(150.0), 18, Color(rim_color.r, rim_color.g, rim_color.b, 0.20), 2.0)


func draw_pillar_text_centered(canvas: CanvasItem, center: Vector2, text: String, font_size: int, color: Color) -> void:
	if canvas == null:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline: Vector2 = Vector2(center.x - text_size.x * 0.5, center.y + text_size.y * 0.35)
	for offset in [Vector2(-1.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, -1.0), Vector2(0.0, 1.0)]:
		canvas.draw_string(font, baseline + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, min(1.0, color.a + 0.20)))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
