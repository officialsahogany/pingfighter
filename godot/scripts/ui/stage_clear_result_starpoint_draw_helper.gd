extends RefCounted

const StageClearResultShapeHelper := preload("res://scripts/ui/stage_clear_result_shape_helper.gd")
const StageClearResultTextLayoutHelper := preload("res://scripts/ui/stage_clear_result_text_layout_helper.gd")


static func draw_ingame_starpoint_visual(
	canvas: CanvasItem,
	visual_state: Dictionary,
	draw_amount: bool
) -> void:
	if canvas == null:
		return
	var star_center: Vector2 = visual_state.get("star_center", Vector2.ZERO)
	var star_radius: float = float(visual_state.get("star_radius", 34.0))
	var glow_layers_value: Variant = visual_state.get("glow_layers", [])
	var glow_layers: Array = glow_layers_value if glow_layers_value is Array else []
	for layer_value in glow_layers:
		if not (layer_value is Dictionary):
			continue
		var layer: Dictionary = layer_value
		var radius: float = float(layer.get("radius", 0.0))
		var color: Color = layer.get("color", Color.TRANSPARENT)
		if radius > 0.0 and color.a > 0.001:
			canvas.draw_circle(star_center, radius, color)

	StageClearResultShapeHelper.draw_star_polygon(
		canvas,
		star_center,
		star_radius,
		float(visual_state.get("inner_radius", star_radius * 0.5)),
		1.0,
		visual_state.get("star_fill", Color(1.0, 0.42, 0.78, 1.0)),
		visual_state.get("star_outline", Color(1.0, 1.0, 0.0, 1.0)),
		float(visual_state.get("star_outline_width", 3.0))
	)
	draw_starpoint_sparkle_rays(canvas, star_center, visual_state)
	canvas.draw_circle(
		star_center,
		float(visual_state.get("center_dot_radius", max(2.0, star_radius * 0.18))),
		visual_state.get("center_dot_color", Color.WHITE)
	)

	if not draw_amount:
		return
	var amount: int = int(visual_state.get("amount", 1))
	var font: Font = ThemeDB.fallback_font
	StageClearResultTextLayoutHelper.draw_centered_text(
		canvas,
		font,
		"x %d" % amount,
		visual_state.get("text_rect", Rect2(star_center + Vector2(-56.0, 38.0), Vector2(112.0, 32.0))),
		int(round(float(visual_state.get("amount_font_size", 22.0)))),
		visual_state.get("text_color", Color(1.0, 0.97, 0.70, 1.0))
	)


static func draw_starpoint_sparkle_rays(
	canvas: CanvasItem,
	star_center: Vector2,
	visual_state: Dictionary
) -> void:
	if canvas == null:
		return
	var ray_color: Color = visual_state.get("ray_color", Color.TRANSPARENT)
	var ray_hot_color: Color = visual_state.get("ray_hot_color", Color.TRANSPARENT)
	if ray_color.a <= 0.001 and ray_hot_color.a <= 0.001:
		return
	var ray_angle: float = float(visual_state.get("ray_angle", 0.0))
	var ray_length: float = float(visual_state.get("ray_length", 0.0))
	if ray_length <= 0.0:
		return
	var main_width: float = float(visual_state.get("ray_width", 1.4))
	var diagonal_width: float = float(visual_state.get("diagonal_ray_width", 0.9))
	var directions := [
		Vector2.RIGHT.rotated(ray_angle),
		Vector2.UP.rotated(ray_angle),
		Vector2(1.0, 1.0).normalized().rotated(ray_angle),
		Vector2(1.0, -1.0).normalized().rotated(ray_angle),
	]
	for i in range(directions.size()):
		var direction: Vector2 = directions[i]
		var length: float = ray_length if i < 2 else ray_length * 0.72
		var width: float = main_width if i < 2 else diagonal_width
		var color: Color = ray_color if i < 2 else ray_hot_color
		if color.a <= 0.001:
			continue
		canvas.draw_line(star_center - direction * length, star_center + direction * length, color, width, true)
