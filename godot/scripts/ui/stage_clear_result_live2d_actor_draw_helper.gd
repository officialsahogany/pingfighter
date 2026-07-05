extends RefCounted

const StageClearResultClickReactionState := preload("res://scripts/ui/stage_clear_result_click_reaction_state.gd")
const StageClearResultLayoutHelper := preload("res://scripts/ui/stage_clear_result_layout_helper.gd")
const StageClearResultSheetDrawHelper := preload("res://scripts/ui/stage_clear_result_sheet_draw_helper.gd")

const DALJI_FRAME_COUNT := 98
const DALJI_GRID_COLS := 14
# Source sheet stores 1152px cells, but the result screen only displays the
# character at ~760px. The .import caps the imported texture to 896px cells
# (process/size_limit=12544) so the GPU upload is ~3x cheaper with no visible
# change at the display size. This cell size MUST match that imported cell size.
const DALJI_CELL_SIZE := Vector2(896.0, 896.0)
const DALJI_FRAME_INTERVAL := 0.055
const DALJI_CLICK_FRAME_INTERVAL := 0.036
const DALJI_CLICK_REACTION_DURATION := DALJI_FRAME_COUNT * DALJI_CLICK_FRAME_INTERVAL
const DALJI_CLICK_TRANSITION_DURATION := 0.16
const DALJI_CLICK_RETURN_HOLD_DURATION := 0.18
const DALJI_CLICK_RETURN_FADE_DURATION := 0.05
const DALJI_CLICK_TOTAL_DURATION := DALJI_CLICK_REACTION_DURATION + DALJI_CLICK_RETURN_HOLD_DURATION + DALJI_CLICK_RETURN_FADE_DURATION

const PLAYER_VICTORY_FRAME_COUNT := 98
const PLAYER_VICTORY_GRID_COLS := 11
# Source sheet stores 1408px cells; result screen displays at ~760px. The
# .import caps the imported texture to 896px cells (process/size_limit=9856)
# for a ~6x cheaper GPU upload with no visible change. Must match the imported
# cell size; StageClearResultLayoutHelper keeps the authored 1408px click
# offsets separately so the click region does not drift after downscale.
const PLAYER_VICTORY_CELL_SIZE := Vector2(896.0, 896.0)
const PLAYER_VICTORY_FRAME_INTERVAL := 0.055
const PLAYER_VICTORY_CLICK_FRAME_INTERVAL := 0.036
const PLAYER_VICTORY_CLICK_REACTION_DURATION := PLAYER_VICTORY_FRAME_COUNT * PLAYER_VICTORY_CLICK_FRAME_INTERVAL
const PLAYER_VICTORY_CLICK_TRANSITION_DURATION := 0.16
const PLAYER_VICTORY_CLICK_RETURN_HOLD_DURATION := 0.18
const PLAYER_VICTORY_CLICK_RETURN_FADE_DURATION := 0.05
const PLAYER_VICTORY_CLICK_TOTAL_DURATION := PLAYER_VICTORY_CLICK_REACTION_DURATION + PLAYER_VICTORY_CLICK_RETURN_HOLD_DURATION + PLAYER_VICTORY_CLICK_RETURN_FADE_DURATION

const BOSS_DEFEAT_LIVE2D_FRAME_COUNT := 98
const BOSS_DEFEAT_LIVE2D_GRID_COLS := 14
# Source sheet stores 1152px cells; capped to 896px cells on import
# (process/size_limit=12544). Must match the imported cell size.
const BOSS_DEFEAT_LIVE2D_CELL_SIZE := Vector2(896.0, 896.0)
const BOSS_DEFEAT_LIVE2D_FRAME_INTERVAL := 0.055
const BOSS_DEFEAT_CLICK_FRAME_INTERVAL := 0.036
const BOSS_DEFEAT_CLICK_REACTION_DURATION := BOSS_DEFEAT_LIVE2D_FRAME_COUNT * BOSS_DEFEAT_CLICK_FRAME_INTERVAL
const BOSS_DEFEAT_CLICK_TRANSITION_DURATION := 0.16
const BOSS_DEFEAT_CLICK_RETURN_HOLD_DURATION := 0.18
const BOSS_DEFEAT_CLICK_RETURN_FADE_DURATION := 0.05
const BOSS_DEFEAT_CLICK_TOTAL_DURATION := BOSS_DEFEAT_CLICK_REACTION_DURATION + BOSS_DEFEAT_CLICK_RETURN_HOLD_DURATION + BOSS_DEFEAT_CLICK_RETURN_FADE_DURATION


static func get_dalji_reaction_state(
	base_timer: float,
	reaction_timer: float,
	transition_base_frame: int
) -> Dictionary:
	return StageClearResultClickReactionState.get_reaction_state(
		base_timer,
		DALJI_FRAME_INTERVAL,
		DALJI_FRAME_COUNT,
		reaction_timer,
		DALJI_CLICK_REACTION_DURATION,
		DALJI_CLICK_FRAME_INTERVAL,
		DALJI_CLICK_TRANSITION_DURATION,
		transition_base_frame,
		DALJI_CLICK_RETURN_HOLD_DURATION,
		DALJI_CLICK_RETURN_FADE_DURATION,
		DALJI_CLICK_TOTAL_DURATION
	)


static func get_player_victory_reaction_state(
	base_timer: float,
	reaction_timer: float,
	transition_base_frame: int
) -> Dictionary:
	return StageClearResultClickReactionState.get_reaction_state(
		base_timer,
		PLAYER_VICTORY_FRAME_INTERVAL,
		PLAYER_VICTORY_FRAME_COUNT,
		reaction_timer,
		PLAYER_VICTORY_CLICK_REACTION_DURATION,
		PLAYER_VICTORY_CLICK_FRAME_INTERVAL,
		PLAYER_VICTORY_CLICK_TRANSITION_DURATION,
		transition_base_frame,
		PLAYER_VICTORY_CLICK_RETURN_HOLD_DURATION,
		PLAYER_VICTORY_CLICK_RETURN_FADE_DURATION,
		PLAYER_VICTORY_CLICK_TOTAL_DURATION
	)


static func get_boss_defeat_reaction_state(
	base_timer: float,
	reaction_timer: float,
	transition_base_frame: int
) -> Dictionary:
	return StageClearResultClickReactionState.get_reaction_state(
		base_timer,
		BOSS_DEFEAT_LIVE2D_FRAME_INTERVAL,
		BOSS_DEFEAT_LIVE2D_FRAME_COUNT,
		reaction_timer,
		BOSS_DEFEAT_CLICK_REACTION_DURATION,
		BOSS_DEFEAT_CLICK_FRAME_INTERVAL,
		BOSS_DEFEAT_CLICK_TRANSITION_DURATION,
		transition_base_frame,
		BOSS_DEFEAT_CLICK_RETURN_HOLD_DURATION,
		BOSS_DEFEAT_CLICK_RETURN_FADE_DURATION,
		BOSS_DEFEAT_CLICK_TOTAL_DURATION
	)


static func get_player_victory_click_attempt(
	mouse_position: Vector2,
	view_size: Vector2,
	scale: float,
	reaction_timer: float,
	base_timer: float
) -> Dictionary:
	var click_rect: Rect2 = StageClearResultLayoutHelper.get_player_victory_click_rect(
		view_size,
		scale,
		PLAYER_VICTORY_CELL_SIZE
	)
	return {
		"click_rect": click_rect,
		"attempt": StageClearResultClickReactionState.get_click_reaction_attempt(
			mouse_position,
			click_rect,
			reaction_timer,
			PLAYER_VICTORY_CLICK_TOTAL_DURATION,
			base_timer,
			PLAYER_VICTORY_FRAME_INTERVAL,
			PLAYER_VICTORY_FRAME_COUNT
		),
	}


static func get_dalji_click_attempt(
	mouse_position: Vector2,
	view_size: Vector2,
	scale: float,
	reaction_timer: float,
	base_timer: float
) -> Dictionary:
	var click_rect: Rect2 = StageClearResultLayoutHelper.get_dalji_draw_rect(view_size, scale)
	return {
		"click_rect": click_rect,
		"attempt": StageClearResultClickReactionState.get_click_reaction_attempt(
			mouse_position,
			click_rect,
			reaction_timer,
			DALJI_CLICK_TOTAL_DURATION,
			base_timer,
			DALJI_FRAME_INTERVAL,
			DALJI_FRAME_COUNT
		),
	}


static func get_boss_defeat_click_attempt(
	stage_id: int,
	mouse_position: Vector2,
	view_size: Vector2,
	scale: float,
	reaction_timer: float,
	base_timer: float
) -> Dictionary:
	var click_rect: Rect2 = StageClearResultLayoutHelper.get_stage2_boss_result_draw_rect(view_size, scale)
	if stage_id == 3:
		click_rect = StageClearResultLayoutHelper.get_stage3_boss_result_draw_rect(view_size, scale)
	elif stage_id == 4:
		click_rect = StageClearResultLayoutHelper.get_stage4_boss_result_draw_rect(view_size, scale)
	return {
		"click_rect": click_rect,
		"attempt": StageClearResultClickReactionState.get_click_reaction_attempt(
			mouse_position,
			click_rect,
			reaction_timer,
			BOSS_DEFEAT_CLICK_TOTAL_DURATION,
			base_timer,
			BOSS_DEFEAT_LIVE2D_FRAME_INTERVAL,
			BOSS_DEFEAT_LIVE2D_FRAME_COUNT
		),
	}


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


static func draw_stage4_ponk_defeated(
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
	var draw_rect: Rect2 = StageClearResultLayoutHelper.get_stage4_boss_result_draw_rect(view_size, scale)
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
