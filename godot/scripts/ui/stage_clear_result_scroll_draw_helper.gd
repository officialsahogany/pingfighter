extends RefCounted

const StageClearResultShapeHelper := preload("res://scripts/ui/stage_clear_result_shape_helper.gd")


static func draw_cyber_scroll_texture(
	canvas: CanvasItem,
	texture: Texture2D,
	visible_rect: Rect2,
	unfurl: float
) -> bool:
	if canvas == null or texture == null:
		return false
	if visible_rect.size.x <= 0.0 or visible_rect.size.y <= 0.0 or unfurl <= 0.0:
		return false
	var texture_size: Vector2 = texture.get_size()
	var source_height: float = max(1.0, texture_size.y * unfurl)
	var source := Rect2(Vector2.ZERO, Vector2(texture_size.x, source_height))
	canvas.draw_texture_rect_region(texture, visible_rect, source, Color.WHITE, false, true)
	return true


static func draw_cyber_scroll_frame(
	canvas: CanvasItem,
	texture: Texture2D,
	full_rect: Rect2,
	visible_rect: Rect2,
	scale: float,
	unfurl: float
) -> void:
	if canvas == null:
		return
	StageClearResultShapeHelper.draw_filled_ellipse(
		canvas,
		Vector2(full_rect.get_center().x, visible_rect.end.y + 22.0 * scale),
		full_rect.size.x * 0.45,
		16.0 * scale,
		Color(0.0, 0.0, 0.0, 0.22 + 0.14 * unfurl),
		24
	)
	if not draw_cyber_scroll_texture(canvas, texture, visible_rect, unfurl):
		draw_cyber_scroll_fallback(canvas, visible_rect, scale, unfurl)


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
