extends RefCounted

const StageClearResultShapeHelper := preload("res://scripts/ui/stage_clear_result_shape_helper.gd")
const StageClearResultTextLayoutHelper := preload("res://scripts/ui/stage_clear_result_text_layout_helper.gd")


static func draw_metric_tile(
	canvas: CanvasItem,
	font: Font,
	rect: Rect2,
	title: String,
	value: String,
	title_color: Color,
	value_color: Color,
	alpha: float
) -> void:
	if canvas == null or font == null:
		return
	var unit: float = rect.size.y / 78.0
	StageClearResultShapeHelper.draw_panel(canvas, rect, Color(0.88, 0.97, 1.0, 0.32 * alpha), Color(0.04, 0.78, 0.95, 0.52 * alpha), 1.6, 12.0)
	StageClearResultTextLayoutHelper.draw_text(canvas, font, title, rect.position + Vector2(16.0, 25.0) * unit, int(round(18.0 * unit)), title_color)
	StageClearResultTextLayoutHelper.draw_text(canvas, font, value, rect.position + Vector2(16.0, 61.0) * unit, int(round(30.0 * unit)), value_color)


static func draw_rating_tile(
	canvas: CanvasItem,
	font: Font,
	rect: Rect2,
	title: String,
	stars_filled: int,
	title_color: Color,
	alpha: float
) -> void:
	if canvas == null or font == null:
		return
	var unit: float = rect.size.y / 78.0
	StageClearResultShapeHelper.draw_panel(canvas, rect, Color(0.88, 0.97, 1.0, 0.32 * alpha), Color(0.04, 0.78, 0.95, 0.52 * alpha), 1.6, 12.0)
	StageClearResultTextLayoutHelper.draw_text(canvas, font, title, rect.position + Vector2(16.0, 25.0) * unit, int(round(18.0 * unit)), title_color)
	var star_outer: float = 13.0 * unit
	var star_inner: float = 6.2 * unit
	var star_gap: float = 33.0 * unit
	var star_y: float = rect.position.y + 55.0 * unit
	var start_x: float = rect.position.x + 16.0 * unit + star_outer
	var outline_width: float = max(1.0, 1.5 * unit)
	var fill_color := Color(1.0, 0.82, 0.24, alpha)
	var fill_outline := Color(1.0, 0.95, 0.66, alpha * 0.92)
	var empty_fill := Color(0.30, 0.40, 0.46, alpha * 0.18)
	var empty_outline := Color(0.28, 0.44, 0.50, alpha * 0.55)
	for i in range(3):
		var center := Vector2(start_x + float(i) * star_gap, star_y)
		if i < stars_filled:
			StageClearResultShapeHelper.draw_star_polygon(
				canvas,
				center,
				star_outer,
				star_inner,
				1.0,
				fill_color,
				fill_outline,
				outline_width
			)
		else:
			StageClearResultShapeHelper.draw_star_polygon(
				canvas,
				center,
				star_outer,
				star_inner,
				1.0,
				empty_fill,
				empty_outline,
				outline_width
			)
