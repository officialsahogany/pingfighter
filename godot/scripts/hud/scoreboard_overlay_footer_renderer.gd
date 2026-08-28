extends RefCounted

const MatchScoreState := preload("res://scripts/core/match_score_state.gd")
const SCOREBOARD_FONT: Font = preload("res://assets/fonts/NanumSquareB.ttf")
const BRUSH_FONT: Font = preload("res://assets/fonts/NanumBrushScript-Regular.ttf")

const INK_COLOR := Color(0.105, 0.065, 0.035, 1.0)
const MUTED_INK_COLOR := Color(0.30, 0.19, 0.095, 1.0)
const VICTORY_INK_COLOR := Color(0.50, 0.055, 0.035, 1.0)
const STAMP_PAPER_COLOR := Color(0.96, 0.88, 0.70, 1.0)
const FOOTER_Y_RATIO := 0.829
const FOOTER_COLUMN_X_RATIO := 0.350
const FOOTER_TEXT_WIDTH_RATIO := 0.215
const OVERTIME_ENTRY_START := 0.30
const OVERTIME_ENTRY_DURATION := 0.46


func draw(
	canvas: CanvasItem,
	board_rect: Rect2,
	alpha: float,
	overtime_mode: bool,
	victory_goal: int,
	overtime_entry: bool = false,
	scoreboard_timer: float = 1.0
) -> void:
	if canvas == null or alpha <= 0.001:
		return
	var copy: Dictionary = resolve_rule_copy(overtime_mode, victory_goal)
	var presentation: Dictionary = resolve_overtime_entry_presentation(scoreboard_timer, overtime_entry)
	var footer_y: float = board_rect.position.y + board_rect.size.y * FOOTER_Y_RATIO
	var left_center := Vector2(board_rect.position.x + board_rect.size.x * FOOTER_COLUMN_X_RATIO, footer_y)
	var right_center := Vector2(board_rect.position.x + board_rect.size.x * (1.0 - FOOTER_COLUMN_X_RATIO), footer_y)
	var max_size := Vector2(board_rect.size.x * FOOTER_TEXT_WIDTH_RATIO, board_rect.size.y * 0.060)
	var entry_color_mix: float = float(presentation.get("color_mix", 0.0))
	var left_color: Color = VICTORY_INK_COLOR if overtime_mode else INK_COLOR
	var right_color: Color = INK_COLOR.lerp(VICTORY_INK_COLOR, entry_color_mix)
	if overtime_entry:
		_draw_overtime_ink_wash(
			canvas,
			left_center,
			board_rect.size.y,
			alpha * float(presentation.get("wash_alpha", 0.0))
		)
	_draw_footer_text(
		canvas,
		left_center,
		str(copy.get("left", "")),
		int(clampf(roundf(board_rect.size.y * 0.044), 14.0, 18.0)),
		max_size,
		left_color,
		alpha,
		float(presentation.get("state_scale", 1.0))
	)
	_draw_footer_text(
		canvas,
		right_center,
		str(copy.get("right", "")),
		int(clampf(roundf(board_rect.size.y * 0.040), 13.0, 17.0)),
		max_size,
		right_color,
		alpha * float(presentation.get("goal_alpha", 1.0)),
		float(presentation.get("goal_scale", 1.0))
	)
	_draw_result_seal(canvas, board_rect, alpha)


func resolve_rule_copy(overtime_mode: bool, victory_goal: int) -> Dictionary:
	var safe_goal: int = MatchScoreState.WIN_GOAL
	if overtime_mode:
		safe_goal = clampi(
			victory_goal,
			MatchScoreState.DEUCE_GOAL_BASE,
			MatchScoreState.DEUCE_GOAL_MAX
		)
	return {
		"left": "연장전" if overtime_mode else "정규전",
		"right": "%d점 승리" % safe_goal,
	}


func resolve_overtime_entry_presentation(scoreboard_timer: float, overtime_entry: bool) -> Dictionary:
	if not overtime_entry:
		return {
			"state_scale": 1.0,
			"goal_scale": 1.0,
			"goal_alpha": 1.0,
			"wash_alpha": 0.0,
			"color_mix": 0.0,
		}
	var progress: float = clampf(
		(scoreboard_timer - OVERTIME_ENTRY_START) / OVERTIME_ENTRY_DURATION,
		0.0,
		1.0
	)
	var state_scale: float
	if progress < 0.44:
		state_scale = lerpf(0.94, 1.08, _smoothstep01(progress / 0.44))
	else:
		state_scale = lerpf(1.08, 1.0, _smoothstep01((progress - 0.44) / 0.56))
	var goal_progress: float = _smoothstep01((scoreboard_timer - 0.37) / 0.20)
	return {
		"state_scale": state_scale,
		"goal_scale": lerpf(0.96, 1.0, goal_progress),
		"goal_alpha": goal_progress,
		"wash_alpha": sin(progress * PI) * 0.18,
		"color_mix": (1.0 - progress) * 0.65,
	}


func _draw_overtime_ink_wash(
	canvas: CanvasItem,
	center: Vector2,
	board_height: float,
	alpha: float
) -> void:
	if alpha <= 0.001:
		return
	var radius: float = clampf(board_height * 0.038, 12.0, 16.0)
	var wash_offsets: Array[Vector2] = [
		Vector2(-8.0, 0.8),
		Vector2(1.0, -1.5),
		Vector2(9.0, 1.2),
	]
	for offset in wash_offsets:
		canvas.draw_circle(
			center + offset,
			radius,
			Color(VICTORY_INK_COLOR.r, VICTORY_INK_COLOR.g, VICTORY_INK_COLOR.b, 0.22 * alpha)
		)


func _draw_footer_text(
	canvas: CanvasItem,
	center: Vector2,
	text: String,
	requested_size: int,
	max_size: Vector2,
	color: Color,
	alpha: float,
	scale: float = 1.0
) -> void:
	var font: Font = SCOREBOARD_FONT if SCOREBOARD_FONT != null else BRUSH_FONT
	if font == null:
		font = ThemeDB.fallback_font
	if font == null:
		return
	var scaled_requested_size: int = maxi(11, int(roundf(float(requested_size) * scale)))
	var font_size: int = _fit_font_size(font, text, scaled_requested_size, max_size)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline := Vector2(
		center.x - text_size.x * 0.5,
		center.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	)
	canvas.draw_string(
		font,
		baseline + Vector2(1.0, 1.0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		Color(MUTED_INK_COLOR.r, MUTED_INK_COLOR.g, MUTED_INK_COLOR.b, 0.18 * alpha)
	)
	canvas.draw_string(
		font,
		baseline,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		Color(color.r, color.g, color.b, 0.92 * alpha)
	)


func _draw_result_seal(canvas: CanvasItem, board_rect: Rect2, alpha: float) -> void:
	var center := Vector2(
		board_rect.get_center().x,
		board_rect.position.y + board_rect.size.y * 0.800
	)
	var seal_size: float = clampf(board_rect.size.y * 0.066, 23.0, 28.0)
	var seal_rect := Rect2(center - Vector2.ONE * seal_size * 0.5, Vector2.ONE * seal_size)
	canvas.draw_rect(
		seal_rect.grow(2.5),
		Color(VICTORY_INK_COLOR.r, VICTORY_INK_COLOR.g, VICTORY_INK_COLOR.b, 0.52 * alpha),
		false,
		1.5
	)
	var font: Font = SCOREBOARD_FONT if SCOREBOARD_FONT != null else ThemeDB.fallback_font
	if font == null:
		return
	var font_size: int = int(clampf(roundf(seal_size * 0.47), 11.0, 14.0))
	var text_size := font.get_string_size("결", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline := Vector2(
		center.x - text_size.x * 0.5,
		center.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	)
	canvas.draw_string(
		font,
		baseline,
		"결",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		Color(STAMP_PAPER_COLOR.r, STAMP_PAPER_COLOR.g, STAMP_PAPER_COLOR.b, alpha)
	)


func _fit_font_size(font: Font, text: String, requested_size: int, max_size: Vector2) -> int:
	var font_size: int = maxi(11, requested_size)
	while font_size > 11:
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
		if text_size.x <= max_size.x and text_size.y <= max_size.y:
			break
		font_size -= 1
	return font_size


func _smoothstep01(value: float) -> float:
	var t: float = clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
