extends RefCounted

const StageClearResultShapeHelper := preload("res://scripts/ui/stage_clear_result_shape_helper.gd")


static func draw_cyber_scroll_fallback(
	canvas: CanvasItem,
	rect: Rect2,
	scale: float,
	alpha: float
) -> void:
	if canvas == null or alpha <= 0.0:
		return
	var fill := Color(0.86, 0.98, 1.0, 0.76 * alpha)
	var border := Color(0.20, 0.92, 1.0, 0.88 * alpha)
	StageClearResultShapeHelper.draw_panel(canvas, rect, fill, border, max(2.0, 2.5 * scale), 18.0 * scale)
	var rod_height: float = 26.0 * scale
	var rod_color := Color(0.04, 0.08, 0.11, 0.94 * alpha)
	StageClearResultShapeHelper.draw_panel(
		canvas,
		Rect2(rect.position + Vector2(-18.0 * scale, -rod_height * 0.45), Vector2(rect.size.x + 36.0 * scale, rod_height)),
		rod_color,
		border,
		max(1.0, 1.5 * scale),
		13.0 * scale
	)
	StageClearResultShapeHelper.draw_panel(
		canvas,
		Rect2(Vector2(rect.position.x - 18.0 * scale, rect.end.y - rod_height * 0.55), Vector2(rect.size.x + 36.0 * scale, rod_height)),
		rod_color,
		border,
		max(1.0, 1.5 * scale),
		13.0 * scale
	)


static func draw_section_group_panel(
	canvas: CanvasItem,
	rect: Rect2,
	scale: float,
	alpha: float
) -> void:
	if canvas == null:
		return
	StageClearResultShapeHelper.draw_panel(
		canvas,
		rect,
		Color(0.92, 0.98, 1.0, 0.16 * alpha),
		Color(0.05, 0.66, 0.84, 0.20 * alpha),
		max(1.0, 1.0 * scale),
		16.0 * scale
	)
