extends RefCounted

const StageClearResultLive2DActorDrawHelper := preload("res://scripts/ui/stage_clear_result_live2d_actor_draw_helper.gd")
const StageClearResultPulseActorDrawHelper := preload("res://scripts/ui/stage_clear_result_pulse_actor_draw_helper.gd")

const DALJI_FRAME_COUNT := StageClearResultLive2DActorDrawHelper.DALJI_FRAME_COUNT
const DALJI_GRID_COLS := StageClearResultLive2DActorDrawHelper.DALJI_GRID_COLS
const DALJI_CELL_SIZE := StageClearResultLive2DActorDrawHelper.DALJI_CELL_SIZE
const DALJI_FRAME_INTERVAL := StageClearResultLive2DActorDrawHelper.DALJI_FRAME_INTERVAL
const DALJI_CLICK_FRAME_INTERVAL := StageClearResultLive2DActorDrawHelper.DALJI_CLICK_FRAME_INTERVAL
const DALJI_CLICK_REACTION_DURATION := StageClearResultLive2DActorDrawHelper.DALJI_CLICK_REACTION_DURATION
const DALJI_CLICK_TRANSITION_DURATION := StageClearResultLive2DActorDrawHelper.DALJI_CLICK_TRANSITION_DURATION
const DALJI_CLICK_RETURN_HOLD_DURATION := StageClearResultLive2DActorDrawHelper.DALJI_CLICK_RETURN_HOLD_DURATION
const DALJI_CLICK_RETURN_FADE_DURATION := StageClearResultLive2DActorDrawHelper.DALJI_CLICK_RETURN_FADE_DURATION
const DALJI_CLICK_TOTAL_DURATION := StageClearResultLive2DActorDrawHelper.DALJI_CLICK_TOTAL_DURATION

const PLAYER_VICTORY_FRAME_COUNT := StageClearResultLive2DActorDrawHelper.PLAYER_VICTORY_FRAME_COUNT
const PLAYER_VICTORY_GRID_COLS := StageClearResultLive2DActorDrawHelper.PLAYER_VICTORY_GRID_COLS
const PLAYER_VICTORY_CELL_SIZE := StageClearResultLive2DActorDrawHelper.PLAYER_VICTORY_CELL_SIZE
const PLAYER_VICTORY_FRAME_INTERVAL := StageClearResultLive2DActorDrawHelper.PLAYER_VICTORY_FRAME_INTERVAL
const PLAYER_VICTORY_CLICK_FRAME_INTERVAL := StageClearResultLive2DActorDrawHelper.PLAYER_VICTORY_CLICK_FRAME_INTERVAL
const PLAYER_VICTORY_CLICK_REACTION_DURATION := StageClearResultLive2DActorDrawHelper.PLAYER_VICTORY_CLICK_REACTION_DURATION
const PLAYER_VICTORY_CLICK_TRANSITION_DURATION := StageClearResultLive2DActorDrawHelper.PLAYER_VICTORY_CLICK_TRANSITION_DURATION
const PLAYER_VICTORY_CLICK_RETURN_HOLD_DURATION := StageClearResultLive2DActorDrawHelper.PLAYER_VICTORY_CLICK_RETURN_HOLD_DURATION
const PLAYER_VICTORY_CLICK_RETURN_FADE_DURATION := StageClearResultLive2DActorDrawHelper.PLAYER_VICTORY_CLICK_RETURN_FADE_DURATION
const PLAYER_VICTORY_CLICK_TOTAL_DURATION := StageClearResultLive2DActorDrawHelper.PLAYER_VICTORY_CLICK_TOTAL_DURATION

const BOSS_DEFEAT_LIVE2D_FRAME_COUNT := StageClearResultLive2DActorDrawHelper.BOSS_DEFEAT_LIVE2D_FRAME_COUNT
const BOSS_DEFEAT_LIVE2D_GRID_COLS := StageClearResultLive2DActorDrawHelper.BOSS_DEFEAT_LIVE2D_GRID_COLS
const BOSS_DEFEAT_LIVE2D_CELL_SIZE := StageClearResultLive2DActorDrawHelper.BOSS_DEFEAT_LIVE2D_CELL_SIZE
const BOSS_DEFEAT_LIVE2D_FRAME_INTERVAL := StageClearResultLive2DActorDrawHelper.BOSS_DEFEAT_LIVE2D_FRAME_INTERVAL
const BOSS_DEFEAT_CLICK_FRAME_INTERVAL := StageClearResultLive2DActorDrawHelper.BOSS_DEFEAT_CLICK_FRAME_INTERVAL
const BOSS_DEFEAT_CLICK_REACTION_DURATION := StageClearResultLive2DActorDrawHelper.BOSS_DEFEAT_CLICK_REACTION_DURATION
const BOSS_DEFEAT_CLICK_TRANSITION_DURATION := StageClearResultLive2DActorDrawHelper.BOSS_DEFEAT_CLICK_TRANSITION_DURATION
const BOSS_DEFEAT_CLICK_RETURN_HOLD_DURATION := StageClearResultLive2DActorDrawHelper.BOSS_DEFEAT_CLICK_RETURN_HOLD_DURATION
const BOSS_DEFEAT_CLICK_RETURN_FADE_DURATION := StageClearResultLive2DActorDrawHelper.BOSS_DEFEAT_CLICK_RETURN_FADE_DURATION
const BOSS_DEFEAT_CLICK_TOTAL_DURATION := StageClearResultLive2DActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION

const STAGE5_HONGRYUN_RESULT_FRAME_COUNT := StageClearResultPulseActorDrawHelper.STAGE5_HONGRYUN_RESULT_FRAME_COUNT
const STAGE5_HONGRYUN_RESULT_GRID_COLS := StageClearResultPulseActorDrawHelper.STAGE5_HONGRYUN_RESULT_GRID_COLS
const STAGE5_HONGRYUN_RESULT_CELL_SIZE := StageClearResultPulseActorDrawHelper.STAGE5_HONGRYUN_RESULT_CELL_SIZE
const STAGE5_HONGRYUN_RESULT_FRAME_INTERVAL := StageClearResultPulseActorDrawHelper.STAGE5_HONGRYUN_RESULT_FRAME_INTERVAL
const STAGE5_HONGRYUN_CLICK_REACTION_DURATION := StageClearResultPulseActorDrawHelper.STAGE5_HONGRYUN_CLICK_REACTION_DURATION
const STAGE5_HONGRYUN_CLICK_TRANSITION_DURATION := StageClearResultPulseActorDrawHelper.STAGE5_HONGRYUN_CLICK_TRANSITION_DURATION
const STAGE5_HONGRYUN_CLICK_RETURN_HOLD_DURATION := StageClearResultPulseActorDrawHelper.STAGE5_HONGRYUN_CLICK_RETURN_HOLD_DURATION
const STAGE5_HONGRYUN_CLICK_RETURN_FADE_DURATION := StageClearResultPulseActorDrawHelper.STAGE5_HONGRYUN_CLICK_RETURN_FADE_DURATION
const STAGE5_HONGRYUN_CLICK_TOTAL_DURATION := StageClearResultPulseActorDrawHelper.STAGE5_HONGRYUN_CLICK_TOTAL_DURATION

const STAGE6_TETRISER_DEFEAT_FRAME_COUNT := StageClearResultPulseActorDrawHelper.STAGE6_TETRISER_DEFEAT_FRAME_COUNT
const STAGE6_TETRISER_DEFEAT_GRID_COLS := StageClearResultPulseActorDrawHelper.STAGE6_TETRISER_DEFEAT_GRID_COLS
const STAGE6_TETRISER_DEFEAT_CELL_SIZE := StageClearResultPulseActorDrawHelper.STAGE6_TETRISER_DEFEAT_CELL_SIZE
const STAGE6_TETRISER_DEFEAT_FRAME_INTERVAL := StageClearResultPulseActorDrawHelper.STAGE6_TETRISER_DEFEAT_FRAME_INTERVAL
const STAGE6_TETRISER_CLICK_REACTION_DURATION := StageClearResultPulseActorDrawHelper.STAGE6_TETRISER_CLICK_REACTION_DURATION
const STAGE6_TETRISER_CLICK_TRANSITION_DURATION := StageClearResultPulseActorDrawHelper.STAGE6_TETRISER_CLICK_TRANSITION_DURATION
const STAGE6_TETRISER_CLICK_RETURN_HOLD_DURATION := StageClearResultPulseActorDrawHelper.STAGE6_TETRISER_CLICK_RETURN_HOLD_DURATION
const STAGE6_TETRISER_CLICK_RETURN_FADE_DURATION := StageClearResultPulseActorDrawHelper.STAGE6_TETRISER_CLICK_RETURN_FADE_DURATION
const STAGE6_TETRISER_CLICK_TOTAL_DURATION := StageClearResultPulseActorDrawHelper.STAGE6_TETRISER_CLICK_TOTAL_DURATION


static func get_dalji_reaction_state(
	base_timer: float,
	reaction_timer: float,
	transition_base_frame: int
) -> Dictionary:
	return StageClearResultLive2DActorDrawHelper.get_dalji_reaction_state(
		base_timer,
		reaction_timer,
		transition_base_frame
	)


static func get_player_victory_reaction_state(
	base_timer: float,
	reaction_timer: float,
	transition_base_frame: int
) -> Dictionary:
	return StageClearResultLive2DActorDrawHelper.get_player_victory_reaction_state(
		base_timer,
		reaction_timer,
		transition_base_frame
	)


static func get_boss_defeat_reaction_state(
	base_timer: float,
	reaction_timer: float,
	transition_base_frame: int
) -> Dictionary:
	return StageClearResultLive2DActorDrawHelper.get_boss_defeat_reaction_state(
		base_timer,
		reaction_timer,
		transition_base_frame
	)


static func get_stage5_hongryun_reaction_state(
	base_timer: float,
	reaction_timer: float,
	transition_base_frame: int
) -> Dictionary:
	return StageClearResultPulseActorDrawHelper.get_stage5_hongryun_reaction_state(
		base_timer,
		reaction_timer,
		transition_base_frame
	)


static func get_stage6_tetriser_reaction_state(
	base_timer: float,
	reaction_timer: float,
	transition_base_frame: int
) -> Dictionary:
	return StageClearResultPulseActorDrawHelper.get_stage6_tetriser_reaction_state(
		base_timer,
		reaction_timer,
		transition_base_frame
	)


static func get_player_victory_click_attempt(
	mouse_position: Vector2,
	view_size: Vector2,
	scale: float,
	reaction_timer: float,
	base_timer: float
) -> Dictionary:
	return StageClearResultLive2DActorDrawHelper.get_player_victory_click_attempt(
		mouse_position,
		view_size,
		scale,
		reaction_timer,
		base_timer
	)


static func get_dalji_click_attempt(
	mouse_position: Vector2,
	view_size: Vector2,
	scale: float,
	reaction_timer: float,
	base_timer: float
) -> Dictionary:
	return StageClearResultLive2DActorDrawHelper.get_dalji_click_attempt(
		mouse_position,
		view_size,
		scale,
		reaction_timer,
		base_timer
	)


static func get_boss_defeat_click_attempt(
	stage_id: int,
	mouse_position: Vector2,
	view_size: Vector2,
	scale: float,
	reaction_timer: float,
	base_timer: float
) -> Dictionary:
	return StageClearResultLive2DActorDrawHelper.get_boss_defeat_click_attempt(
		stage_id,
		mouse_position,
		view_size,
		scale,
		reaction_timer,
		base_timer
	)


static func get_stage5_hongryun_click_attempt(
	mouse_position: Vector2,
	view_size: Vector2,
	scale: float,
	reaction_timer: float,
	base_timer: float
) -> Dictionary:
	return StageClearResultPulseActorDrawHelper.get_stage5_hongryun_click_attempt(
		mouse_position,
		view_size,
		scale,
		reaction_timer,
		base_timer
	)


static func get_stage6_tetriser_click_attempt(
	mouse_position: Vector2,
	view_size: Vector2,
	scale: float,
	reaction_timer: float,
	base_timer: float
) -> Dictionary:
	return StageClearResultPulseActorDrawHelper.get_stage6_tetriser_click_attempt(
		mouse_position,
		view_size,
		scale,
		reaction_timer,
		base_timer
	)


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
	return StageClearResultLive2DActorDrawHelper.draw_dalji_defeated(
		canvas,
		defeat_sheet,
		click_reaction_sheet,
		reaction_state,
		view_size,
		scale,
		grid_cols,
		cell_size,
		alpha
	)


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
	StageClearResultLive2DActorDrawHelper.draw_stage2_defeated(
		canvas,
		defeat_sheet,
		click_reaction_sheet,
		reaction_state,
		view_size,
		scale,
		grid_cols,
		cell_size,
		alpha
	)


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
	StageClearResultLive2DActorDrawHelper.draw_stage3_defeated(
		canvas,
		defeat_sheet,
		click_reaction_sheet,
		reaction_state,
		view_size,
		scale,
		grid_cols,
		cell_size,
		alpha
	)


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
	StageClearResultLive2DActorDrawHelper.draw_stage4_ponk_defeated(
		canvas,
		defeat_sheet,
		click_reaction_sheet,
		reaction_state,
		view_size,
		scale,
		grid_cols,
		cell_size,
		alpha
	)


static func draw_stage5_hongryun_result_fallback(
	canvas: CanvasItem,
	result_sheet: Texture2D,
	timer: float,
	view_size: Vector2,
	scale: float,
	alpha: float,
	reaction_timer: float = STAGE5_HONGRYUN_CLICK_TOTAL_DURATION,
	transition_base_frame: int = 0
) -> Rect2:
	return StageClearResultPulseActorDrawHelper.draw_stage5_hongryun_result_fallback(
		canvas,
		result_sheet,
		timer,
		view_size,
		scale,
		alpha,
		reaction_timer,
		transition_base_frame
	)


static func draw_stage6_tetriser_defeated(
	canvas: CanvasItem,
	defeat_sheet: Texture2D,
	timer: float,
	view_size: Vector2,
	scale: float,
	alpha: float,
	reaction_timer: float = STAGE6_TETRISER_CLICK_TOTAL_DURATION,
	transition_base_frame: int = 0
) -> Rect2:
	return StageClearResultPulseActorDrawHelper.draw_stage6_tetriser_defeated(
		canvas,
		defeat_sheet,
		timer,
		view_size,
		scale,
		alpha,
		reaction_timer,
		transition_base_frame
	)


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
	return StageClearResultLive2DActorDrawHelper.draw_player_victory_live2d(
		canvas,
		victory_sheet,
		click_reaction_sheet,
		reaction_state,
		view_size,
		scale,
		grid_cols,
		cell_size
	)
