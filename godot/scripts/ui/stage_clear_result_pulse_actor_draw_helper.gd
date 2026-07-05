extends RefCounted

const StageClearResultClickReactionState := preload("res://scripts/ui/stage_clear_result_click_reaction_state.gd")
const StageClearResultLayoutHelper := preload("res://scripts/ui/stage_clear_result_layout_helper.gd")
const StageClearResultSheetDrawHelper := preload("res://scripts/ui/stage_clear_result_sheet_draw_helper.gd")

const STAGE5_HONGRYUN_RESULT_FRAME_COUNT := 8
const STAGE5_HONGRYUN_RESULT_GRID_COLS := 4
const STAGE5_HONGRYUN_RESULT_CELL_SIZE := Vector2(384.0, 384.0)
const STAGE5_HONGRYUN_RESULT_FRAME_INTERVAL := 0.16
const STAGE5_HONGRYUN_CLICK_REACTION_DURATION := 0.36
const STAGE5_HONGRYUN_CLICK_TRANSITION_DURATION := 0.08
const STAGE5_HONGRYUN_CLICK_RETURN_HOLD_DURATION := 0.08
const STAGE5_HONGRYUN_CLICK_RETURN_FADE_DURATION := 0.12
const STAGE5_HONGRYUN_CLICK_TOTAL_DURATION := STAGE5_HONGRYUN_CLICK_REACTION_DURATION + STAGE5_HONGRYUN_CLICK_RETURN_HOLD_DURATION + STAGE5_HONGRYUN_CLICK_RETURN_FADE_DURATION

const STAGE6_TETRISER_DEFEAT_FRAME_COUNT := 8
const STAGE6_TETRISER_DEFEAT_GRID_COLS := 3
const STAGE6_TETRISER_DEFEAT_CELL_SIZE := Vector2(256.0, 256.0)
const STAGE6_TETRISER_DEFEAT_FRAME_INTERVAL := 0.10
const STAGE6_TETRISER_CLICK_REACTION_DURATION := 0.36
const STAGE6_TETRISER_CLICK_TRANSITION_DURATION := 0.08
const STAGE6_TETRISER_CLICK_RETURN_HOLD_DURATION := 0.08
const STAGE6_TETRISER_CLICK_RETURN_FADE_DURATION := 0.12
const STAGE6_TETRISER_CLICK_TOTAL_DURATION := STAGE6_TETRISER_CLICK_REACTION_DURATION + STAGE6_TETRISER_CLICK_RETURN_HOLD_DURATION + STAGE6_TETRISER_CLICK_RETURN_FADE_DURATION


static func get_stage5_hongryun_reaction_state(
	base_timer: float,
	reaction_timer: float,
	transition_base_frame: int
) -> Dictionary:
	return get_pulse_result_reaction_state(
		base_timer,
		reaction_timer,
		transition_base_frame,
		STAGE5_HONGRYUN_RESULT_FRAME_INTERVAL,
		STAGE5_HONGRYUN_RESULT_FRAME_COUNT,
		STAGE5_HONGRYUN_CLICK_REACTION_DURATION,
		STAGE5_HONGRYUN_CLICK_TRANSITION_DURATION,
		STAGE5_HONGRYUN_CLICK_RETURN_HOLD_DURATION,
		STAGE5_HONGRYUN_CLICK_RETURN_FADE_DURATION,
		STAGE5_HONGRYUN_CLICK_TOTAL_DURATION
	)


static func get_stage6_tetriser_reaction_state(
	base_timer: float,
	reaction_timer: float,
	transition_base_frame: int
) -> Dictionary:
	return get_pulse_result_reaction_state(
		base_timer,
		reaction_timer,
		transition_base_frame,
		STAGE6_TETRISER_DEFEAT_FRAME_INTERVAL,
		STAGE6_TETRISER_DEFEAT_FRAME_COUNT,
		STAGE6_TETRISER_CLICK_REACTION_DURATION,
		STAGE6_TETRISER_CLICK_TRANSITION_DURATION,
		STAGE6_TETRISER_CLICK_RETURN_HOLD_DURATION,
		STAGE6_TETRISER_CLICK_RETURN_FADE_DURATION,
		STAGE6_TETRISER_CLICK_TOTAL_DURATION
	)


static func get_pulse_result_reaction_state(
	base_timer: float,
	reaction_timer: float,
	transition_base_frame: int,
	frame_interval: float,
	frame_count: int,
	reaction_duration: float,
	transition_duration: float,
	return_hold_duration: float,
	return_fade_duration: float,
	total_duration: float
) -> Dictionary:
	return StageClearResultClickReactionState.get_reaction_state(
		base_timer,
		frame_interval,
		frame_count,
		reaction_timer,
		reaction_duration,
		frame_interval,
		transition_duration,
		transition_base_frame,
		return_hold_duration,
		return_fade_duration,
		total_duration
	)


static func get_stage5_hongryun_click_attempt(
	mouse_position: Vector2,
	view_size: Vector2,
	scale: float,
	reaction_timer: float,
	base_timer: float
) -> Dictionary:
	var click_rect: Rect2 = StageClearResultLayoutHelper.get_stage5_hongryun_result_draw_rect(view_size, scale)
	return get_pulse_result_click_attempt(
		mouse_position,
		click_rect,
		reaction_timer,
		STAGE5_HONGRYUN_CLICK_TOTAL_DURATION,
		base_timer,
		STAGE5_HONGRYUN_RESULT_FRAME_INTERVAL,
		STAGE5_HONGRYUN_RESULT_FRAME_COUNT
	)


static func get_stage6_tetriser_click_attempt(
	mouse_position: Vector2,
	view_size: Vector2,
	scale: float,
	reaction_timer: float,
	base_timer: float
) -> Dictionary:
	var click_rect: Rect2 = StageClearResultLayoutHelper.get_stage6_tetriser_result_draw_rect(view_size, scale)
	return get_pulse_result_click_attempt(
		mouse_position,
		click_rect,
		reaction_timer,
		STAGE6_TETRISER_CLICK_TOTAL_DURATION,
		base_timer,
		STAGE6_TETRISER_DEFEAT_FRAME_INTERVAL,
		STAGE6_TETRISER_DEFEAT_FRAME_COUNT
	)


static func get_pulse_result_click_attempt(
	mouse_position: Vector2,
	click_rect: Rect2,
	reaction_timer: float,
	total_duration: float,
	base_timer: float,
	frame_interval: float,
	frame_count: int
) -> Dictionary:
	return {
		"click_rect": click_rect,
		"attempt": StageClearResultClickReactionState.get_click_reaction_attempt(
			mouse_position,
			click_rect,
			reaction_timer,
			total_duration,
			base_timer,
			frame_interval,
			frame_count
		),
	}


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
	var draw_rect: Rect2 = StageClearResultLayoutHelper.get_stage5_hongryun_result_draw_rect(view_size, scale)
	var reaction_state: Dictionary = get_stage5_hongryun_reaction_state(timer, reaction_timer, transition_base_frame)
	draw_pulse_result_sheet(
		canvas,
		result_sheet,
		draw_rect,
		reaction_state,
		STAGE5_HONGRYUN_RESULT_GRID_COLS,
		STAGE5_HONGRYUN_RESULT_CELL_SIZE,
		scale,
		alpha,
		reaction_timer,
		STAGE5_HONGRYUN_CLICK_TOTAL_DURATION
	)
	return draw_rect


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
	var draw_rect: Rect2 = StageClearResultLayoutHelper.get_stage6_tetriser_result_draw_rect(view_size, scale)
	var reaction_state: Dictionary = get_stage6_tetriser_reaction_state(timer, reaction_timer, transition_base_frame)
	draw_pulse_result_sheet(
		canvas,
		defeat_sheet,
		draw_rect,
		reaction_state,
		STAGE6_TETRISER_DEFEAT_GRID_COLS,
		STAGE6_TETRISER_DEFEAT_CELL_SIZE,
		scale,
		alpha,
		reaction_timer,
		STAGE6_TETRISER_CLICK_TOTAL_DURATION
	)
	return draw_rect


static func draw_pulse_result_sheet(
	canvas: CanvasItem,
	sheet: Texture2D,
	draw_rect: Rect2,
	reaction_state: Dictionary,
	grid_cols: int,
	cell_size: Vector2,
	scale: float,
	alpha: float,
	reaction_timer: float,
	total_duration: float
) -> void:
	var reaction_active: bool = bool(reaction_state.get("reaction_active", false))
	var frame: int = int(reaction_state.get("base_frame", 0))
	var render_rect: Rect2 = draw_rect
	if reaction_active:
		frame = int(reaction_state.get("transition_base_frame", frame))
		var pulse_progress: float = clamp(reaction_timer / max(0.001, total_duration), 0.0, 1.0)
		var pulse: float = sin(pulse_progress * PI)
		var grow: float = 14.0 * max(0.25, scale) * pulse
		render_rect = Rect2(draw_rect.position - Vector2(grow, grow), draw_rect.size + Vector2(grow * 2.0, grow * 2.0))
		StageClearResultSheetDrawHelper.draw_sheet_frame(
			canvas,
			sheet,
			frame,
			grid_cols,
			cell_size,
			Rect2(draw_rect.position - Vector2(grow * 0.45, grow * 0.45), draw_rect.size + Vector2(grow * 0.9, grow * 0.9)),
			alpha * 0.32 * float(reaction_state.get("reaction_alpha", 0.0))
		)
	StageClearResultSheetDrawHelper.draw_sheet_frame(
		canvas,
		sheet,
		frame,
		grid_cols,
		cell_size,
		render_rect,
		alpha
	)
