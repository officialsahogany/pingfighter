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


static func draw_reaction_sheet(
	canvas: CanvasItem,
	base_sheet: Texture2D,
	reaction_sheet: Texture2D,
	reaction_state: Dictionary,
	grid_cols: int,
	cell_size: Vector2,
	rect: Rect2,
	alpha: float
) -> void:
	if not bool(reaction_state.get("reaction_active", false)) or reaction_sheet == null:
		draw_sheet_frame(canvas, base_sheet, int(reaction_state.get("base_frame", 0)), grid_cols, cell_size, rect, alpha)
		return

	var reaction_alpha: float = float(reaction_state.get("reaction_alpha", 0.0))
	var base_alpha: float = 1.0 - reaction_alpha
	draw_sheet_frame(canvas, base_sheet, int(reaction_state.get("transition_base_frame", 0)), grid_cols, cell_size, rect, alpha * base_alpha)
	draw_sheet_frame(canvas, reaction_sheet, int(reaction_state.get("reaction_frame", 0)), grid_cols, cell_size, rect, alpha * reaction_alpha)
