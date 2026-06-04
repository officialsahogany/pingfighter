extends RefCounted

const StageClearResultLayoutHelper := preload("res://scripts/ui/stage_clear_result_layout_helper.gd")
const StageClearResultSheetDrawHelper := preload("res://scripts/ui/stage_clear_result_sheet_draw_helper.gd")


static func draw_dalji_defeated(
	canvas: CanvasItem,
	defeat_sheet: Texture2D,
	click_reaction_sheet: Texture2D,
	reaction_state: Dictionary,
	view_size: Vector2,
	scale: float,
	grid_cols: int,
	cell_size: Vector2,
	alpha: float
) -> Rect2:
	var draw_rect: Rect2 = StageClearResultLayoutHelper.get_dalji_draw_rect(view_size, scale)
	StageClearResultSheetDrawHelper.draw_reaction_sheet(canvas, defeat_sheet, click_reaction_sheet, reaction_state, grid_cols, cell_size, draw_rect, alpha)
	return draw_rect


static func draw_stage2_defeated(
	canvas: CanvasItem,
	defeat_sheet: Texture2D,
	click_reaction_sheet: Texture2D,
	reaction_state: Dictionary,
	view_size: Vector2,
	scale: float,
	grid_cols: int,
	cell_size: Vector2,
	alpha: float
) -> void:
	var draw_rect: Rect2 = StageClearResultLayoutHelper.get_stage2_boss_result_draw_rect(view_size, scale)
	StageClearResultSheetDrawHelper.draw_reaction_sheet(canvas, defeat_sheet, click_reaction_sheet, reaction_state, grid_cols, cell_size, draw_rect, alpha)


static func draw_stage3_defeated(
	canvas: CanvasItem,
	defeat_sheet: Texture2D,
	click_reaction_sheet: Texture2D,
	reaction_state: Dictionary,
	view_size: Vector2,
	scale: float,
	grid_cols: int,
	cell_size: Vector2,
	alpha: float
) -> void:
	var draw_rect: Rect2 = StageClearResultLayoutHelper.get_stage3_boss_result_draw_rect(view_size, scale)
	StageClearResultSheetDrawHelper.draw_reaction_sheet(canvas, defeat_sheet, click_reaction_sheet, reaction_state, grid_cols, cell_size, draw_rect, alpha)


static func draw_player_victory_live2d(
	canvas: CanvasItem,
	victory_sheet: Texture2D,
	click_reaction_sheet: Texture2D,
	reaction_state: Dictionary,
	view_size: Vector2,
	scale: float,
	grid_cols: int,
	cell_size: Vector2
) -> Dictionary:
	if victory_sheet == null:
		return {"drawn": true, "click_rect": Rect2()}
	var actor_rect: Rect2 = StageClearResultLayoutHelper.get_player_victory_actor_rect(view_size, scale)
	var click_rect: Rect2 = StageClearResultLayoutHelper.get_player_victory_click_rect(view_size, scale, cell_size)
	StageClearResultSheetDrawHelper.draw_reaction_sheet(canvas, victory_sheet, click_reaction_sheet, reaction_state, grid_cols, cell_size, actor_rect, 1.0)
	return {"drawn": true, "click_rect": click_rect}
