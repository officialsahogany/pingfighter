extends RefCounted

const StageClearResultLive2DActorDrawHelper := preload("res://scripts/ui/stage_clear_result_live2d_actor_draw_helper.gd")
const StageClearResultPulseActorDrawHelper := preload("res://scripts/ui/stage_clear_result_pulse_actor_draw_helper.gd")
const StageClearResultLayoutHelper := preload("res://scripts/ui/stage_clear_result_layout_helper.gd")

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
# Stage 7 아카무: 동일 4x2 8프레임 256px AutoSprite 시트 계약 — 프레임/펄스
# 수치는 공용 pulse helper의 Stage 6 값을 별칭(새 픽셀 수학 없음). 시트가
# 아직 없으면 presenter가 코드 네이티브 액터로 같은 rect에 그린다.
const STAGE7_AKAMU_DEFEAT_FRAME_COUNT := 8
const STAGE7_AKAMU_DEFEAT_GRID_COLS := 4
const STAGE7_AKAMU_DEFEAT_CELL_SIZE := Vector2(256.0, 256.0)
const STAGE7_AKAMU_DEFEAT_FRAME_INTERVAL := StageClearResultPulseActorDrawHelper.STAGE6_TETRISER_DEFEAT_FRAME_INTERVAL
const STAGE7_AKAMU_CLICK_REACTION_DURATION := StageClearResultPulseActorDrawHelper.STAGE6_TETRISER_CLICK_REACTION_DURATION
const STAGE7_AKAMU_CLICK_TRANSITION_DURATION := StageClearResultPulseActorDrawHelper.STAGE6_TETRISER_CLICK_TRANSITION_DURATION
const STAGE7_AKAMU_CLICK_RETURN_HOLD_DURATION := StageClearResultPulseActorDrawHelper.STAGE6_TETRISER_CLICK_RETURN_HOLD_DURATION
const STAGE7_AKAMU_CLICK_RETURN_FADE_DURATION := StageClearResultPulseActorDrawHelper.STAGE6_TETRISER_CLICK_RETURN_FADE_DURATION
const STAGE7_AKAMU_CLICK_TOTAL_DURATION := StageClearResultPulseActorDrawHelper.STAGE6_TETRISER_CLICK_TOTAL_DURATION
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


static func _get_stage7_akamu_defeat_hold_timer(base_timer: float) -> float:
	# 아카무 패배 시트는 one-shot 계약(defeat.loop=false): 마지막 프레임에
	# 도달하면 그 쓰러진 자세를 유지한다. 공용 pulse 상태 계산은 base_timer를
	# `% frame_count`로 순환시키므로, 마지막 프레임 '중앙' 시각으로 clamp한
	# 타이머를 전달해 순환을 차단한다(경계 부동소수 오차 회피용 +0.5 인터벌).
	var last_frame_hold: float = (float(STAGE7_AKAMU_DEFEAT_FRAME_COUNT - 1) + 0.5) * STAGE7_AKAMU_DEFEAT_FRAME_INTERVAL
	return minf(base_timer, last_frame_hold)


static func get_stage7_akamu_reaction_state(
	base_timer: float,
	reaction_timer: float,
	transition_base_frame: int
) -> Dictionary:
	return StageClearResultPulseActorDrawHelper.get_stage6_tetriser_reaction_state(
		_get_stage7_akamu_defeat_hold_timer(base_timer),
		reaction_timer,
		transition_base_frame
	)


static func get_stage7_akamu_click_attempt(
	mouse_position: Vector2,
	view_size: Vector2,
	scale: float,
	reaction_timer: float,
	base_timer: float
) -> Dictionary:
	var click_rect: Rect2 = StageClearResultLayoutHelper.get_stage7_result_draw_rect(view_size, scale)
	# transition_base_frame도 동일한 one-shot clamp를 거친 타이머로 계산한다
	# (클릭 순간의 base 프레임 = 유지 중인 마지막 프레임).
	return StageClearResultPulseActorDrawHelper.get_pulse_result_click_attempt(
		mouse_position,
		click_rect,
		reaction_timer,
		STAGE7_AKAMU_CLICK_TOTAL_DURATION,
		_get_stage7_akamu_defeat_hold_timer(base_timer),
		STAGE7_AKAMU_DEFEAT_FRAME_INTERVAL,
		STAGE7_AKAMU_DEFEAT_FRAME_COUNT
	)


static func draw_stage7_akamu_defeated(
	canvas: CanvasItem,
	defeat_sheet: Texture2D,
	timer: float,
	view_size: Vector2,
	scale: float,
	alpha: float,
	reaction_timer: float = STAGE7_AKAMU_CLICK_TOTAL_DURATION,
	transition_base_frame: int = 0
) -> Rect2:
	var draw_rect: Rect2 = StageClearResultLayoutHelper.get_stage7_result_draw_rect(view_size, scale)
	var reaction_state: Dictionary = get_stage7_akamu_reaction_state(timer, reaction_timer, transition_base_frame)
	StageClearResultPulseActorDrawHelper.draw_pulse_result_sheet(
		canvas,
		defeat_sheet,
		draw_rect,
		reaction_state,
		STAGE7_AKAMU_DEFEAT_GRID_COLS,
		STAGE7_AKAMU_DEFEAT_CELL_SIZE,
		scale,
		alpha,
		reaction_timer,
		STAGE7_AKAMU_CLICK_TOTAL_DURATION
	)
	return draw_rect


static func draw_stage7_akamu_code_native(
	canvas: CanvasItem,
	draw_rect: Rect2,
	timer: float
) -> void:
	# AutoSprite 결과 시트 도착 전의 코드 네이티브 아카무 실루엣: 진홍
	# 포니테일 헤어(정체성 앵커) + 자주 기모노 바디 + 진홍 허리띠 + 은빛
	# 수리검 힌트. 전부 고정 볼록 폴리곤/원 프리미티브라 삼각분할 안전,
	# 펄스는 알파/스케일에만. 어두운 결과 배경 위에서도 읽히는 명도로 유지.
	var pulse := 0.5 + 0.5 * sin(timer * 2.4)
	var center := draw_rect.get_center()
	var body_half := draw_rect.size * Vector2(0.22, 0.30)
	var body_rect := Rect2(center - body_half + Vector2(0.0, draw_rect.size.y * 0.06), body_half * 2.0)
	var head_radius := draw_rect.size.x * 0.12
	var head_center := Vector2(center.x, body_rect.position.y - head_radius * 0.85)
	# 헤어: 진홍 볼륨 원 + 위로 솟은 포니테일 폴리곤(아카무의 붉은 머리 읽기).
	canvas.draw_circle(head_center, head_radius * 1.28, Color(0.72, 0.13, 0.17, 0.95))
	var ponytail := PackedVector2Array([
		head_center + Vector2(-head_radius * 0.35, -head_radius * 1.05),
		head_center + Vector2(head_radius * 0.55, -head_radius * (2.3 + 0.25 * pulse)),
		head_center + Vector2(head_radius * 1.05, -head_radius * 0.75),
	])
	canvas.draw_colored_polygon(ponytail, Color(0.78, 0.15, 0.20, 0.94))
	# 얼굴 톤 원(헤어 안쪽) — 실루엣이 단색 덩어리로 뭉개지지 않게.
	canvas.draw_circle(head_center + Vector2(0.0, head_radius * 0.18), head_radius * 0.78, Color(0.92, 0.82, 0.74, 0.96))
	# 기모노 바디 + 진홍 허리띠.
	canvas.draw_rect(body_rect, Color(0.38, 0.22, 0.46, 0.95), true)
	canvas.draw_rect(body_rect, Color(0.80, 0.24, 0.30, 0.9), false, maxf(2.0, draw_rect.size.x * 0.012))
	var sash_height := body_rect.size.y * 0.14
	var sash_rect := Rect2(body_rect.position + Vector2(0.0, body_rect.size.y * 0.52), Vector2(body_rect.size.x, sash_height))
	canvas.draw_rect(sash_rect, Color(0.82, 0.20, 0.26, 0.95), true)
	var shuriken_center := center + Vector2(draw_rect.size.x * 0.28, draw_rect.size.y * 0.02)
	var shuriken_radius := draw_rect.size.x * (0.05 + 0.012 * pulse)
	canvas.draw_circle(shuriken_center, shuriken_radius, Color(0.85, 0.87, 0.92, 0.9))
	canvas.draw_circle(shuriken_center, shuriken_radius * 0.4, Color(0.34, 0.36, 0.44, 0.92))
