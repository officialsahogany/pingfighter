extends RefCounted

const StageClearResultLayoutHelper := preload("res://scripts/ui/stage_clear_result_layout_helper.gd")


static func draw_sheet_frame(
	canvas: CanvasItem,
	sheet: Texture2D,
	frame: int,
	grid_cols: int,
	cell_size: Vector2,
	rect: Rect2,
	alpha: float
) -> void:
	if canvas == null or sheet == null or alpha <= 0.001:
		return
	var source: Rect2 = StageClearResultLayoutHelper.sheet_source_rect(frame, grid_cols, cell_size)
	canvas.draw_texture_rect_region(sheet, rect, source, Color(1.0, 1.0, 1.0, alpha), false, true)
