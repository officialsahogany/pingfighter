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

	StageClearResultShapeHelper.draw_soul_flame(
		canvas,
		star_center,
		star_radius,
		float(visual_state.get("flame_sway", 0.0)),
		visual_state.get("flame_fill", Color(0.68, 0.015, 0.07, 1.0)),
		visual_state.get("flame_outline", Color(1.0, 0.62, 0.18, 1.0)),
		float(visual_state.get("flame_outline_width", 3.0)),
		visual_state.get("inner_flame_fill", Color(1.0, 0.72, 0.24, 0.96)),
		visual_state.get("core_color", Color(1.0, 0.98, 0.86, 1.0))
	)
	draw_muhon_wisps(canvas, star_center, star_radius, visual_state)

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


static func draw_muhon_wisps(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	visual_state: Dictionary
) -> void:
	if canvas == null:
		return
	var wisp_color: Color = visual_state.get("wisp_color", Color.TRANSPARENT)
	if wisp_color.a <= 0.001 or radius <= 0.0:
		return
	var phase: float = float(visual_state.get("wisp_phase", 0.0))
	for direction in [-1.0, 1.0]:
		var side: float = float(direction)
		var points: PackedVector2Array = StageClearResultShapeHelper.soul_wisp_polyline_points(center, radius, side, phase)
		var glow_color: Color = wisp_color
		glow_color.a *= 0.28
		canvas.draw_polyline(points, glow_color, maxf(2.0, radius * 0.14), true)
		canvas.draw_polyline(points, wisp_color, maxf(1.0, radius * 0.045), true)
		if not points.is_empty():
			var ember_color: Color = wisp_color.lightened(0.52)
			ember_color.a = minf(1.0, wisp_color.a * 1.35)
			canvas.draw_circle(points[points.size() - 1], maxf(1.2, radius * 0.045), ember_color)
