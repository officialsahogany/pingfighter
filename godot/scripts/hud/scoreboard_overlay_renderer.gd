extends RefCounted

const ScoreboardOverlayFrameRenderer := preload("res://scripts/hud/scoreboard_overlay_frame_renderer.gd")
const ScoreboardOverlayHeaderRenderer := preload("res://scripts/hud/scoreboard_overlay_header_renderer.gd")
const ScoreboardOverlayScorePanelRenderer := preload("res://scripts/hud/scoreboard_overlay_score_panel_renderer.gd")

const DIM_ALPHA := 180.0 / 255.0
const SHADOW_OPENING_SLICE_COUNT := 36
const SHADOW_FEATHER_STEPS := 6
const STAGE_LIGHT_BAND_STEPS := 5
const PLAYER_RESULT_DRAW_SIZE := Vector2(160.0, 160.0)
const BOSS_VISUAL_CENTER_Y_OFFSET := 25.0

var frame_renderer: Object = ScoreboardOverlayFrameRenderer.new()
var header_renderer: Object = ScoreboardOverlayHeaderRenderer.new()
var score_panel_renderer: Object = ScoreboardOverlayScorePanelRenderer.new()


func draw(
	canvas: Node2D,
	hud_state,
	gameplay_width: float,
	gameplay_height: float,
	win_goal: int,
	fade_in_duration: float,
	draw_context: Dictionary = {},
	perf_logger: Object = null
) -> void:
	if canvas == null or hud_state == null:
		return

	var alpha: float = _get_overlay_alpha(hud_state, fade_in_duration)
	var animation_frame: float = _get_animation_frame_time(hud_state)
	var board_width: float = min(680.0, gameplay_width - 40.0)
	var board_height: float = min(380.0, gameplay_height - 80.0)
	var board_x: float = (gameplay_width - board_width) * 0.5
	var board_y: float = (gameplay_height - board_height) * 0.5
	var inner_x: float = board_x + 24.0
	var inner_y: float = board_y + 24.0
	var inner_w: float = board_width - 48.0
	var inner_h: float = board_height - 48.0
	var header_x: float = board_x + 34.0
	var header_y: float = board_y + 32.0
	var header_w: float = inner_w - 20.0
	var header_h: float = 60.0
	var center_x: float = board_x + board_width * 0.5

	var sample_start: int = _perf_begin(perf_logger)
	_draw_shadow_backdrop(canvas, hud_state, draw_context, gameplay_width, gameplay_height, alpha)
	_perf_end(perf_logger, "scoreboard.overlay.shadow", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_stage_light_beams(canvas, hud_state, draw_context, gameplay_width, gameplay_height, alpha, animation_frame)
	_perf_end(perf_logger, "scoreboard.overlay.light", sample_start)
	sample_start = _perf_begin(perf_logger)
	frame_renderer.draw(canvas, Rect2(board_x, board_y, board_width, board_height), alpha)
	canvas.draw_rect(Rect2(inner_x, inner_y, inner_w, inner_h), _rgb(5.0, 8.0, 22.0, alpha))
	_perf_end(perf_logger, "scoreboard.overlay.frame", sample_start)
	sample_start = _perf_begin(perf_logger)
	header_renderer.draw(canvas, Rect2(header_x, header_y, header_w, header_h), alpha)
	_perf_end(perf_logger, "scoreboard.overlay.header", sample_start)

	var score_area_x: float = header_x + 5.0
	var score_area_y: float = header_y + header_h + 15.0
	var score_area_w: float = header_w - 10.0
	var score_area_h: float = inner_h - header_h - 70.0
	var score_area_rect: Rect2 = Rect2(score_area_x, score_area_y, score_area_w, score_area_h)
	sample_start = _perf_begin(perf_logger)
	score_panel_renderer.draw(
		canvas,
		score_area_rect,
		center_x,
		animation_frame,
		hud_state.get_player_points(),
		hud_state.get_boss_points(),
		alpha
	)
	_perf_end(perf_logger, "scoreboard.overlay.score_panel", sample_start)

	sample_start = _perf_begin(perf_logger)
	var footer_rect: Rect2 = Rect2(header_x + 5.0, inner_y + inner_h - 52.0, header_w - 10.0, 36.0)
	canvas.draw_rect(footer_rect, _rgb(10.0, 25.0, 55.0, alpha))
	canvas.draw_rect(footer_rect, _rgb(60.0, 130.0, 210.0, alpha), false, 2.0)
	_draw_text_centered(canvas, footer_rect.get_center(), "FIRST TO %d" % win_goal, 17, _rgb(100.0, 180.0, 255.0, 1.0), alpha)
	_perf_end(perf_logger, "scoreboard.overlay.footer", sample_start)


func _draw_text_centered(canvas: Node2D, center: Vector2, text: String, font_size: int, color: Color, alpha: float) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline: Vector2 = Vector2(center.x - text_size.x * 0.5, center.y + text_size.y * 0.35)
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, _alpha_color(color, alpha))


func _draw_shadow_backdrop(
	canvas: Node2D,
	hud_state,
	draw_context: Dictionary,
	gameplay_width: float,
	gameplay_height: float,
	alpha: float
) -> void:
	var scoring_side: String = _get_scoring_side(hud_state)
	if scoring_side != "player" and scoring_side != "boss":
		_draw_shadow_rect(canvas, Rect2(0.0, 0.0, gameplay_width, gameplay_height), DIM_ALPHA * alpha)
		return

	var focus_rect: Rect2 = _get_winner_shadow_rect(scoring_side, draw_context, gameplay_width, gameplay_height)
	var center: Vector2 = focus_rect.get_center()
	var inner_rx: float = max(8.0, focus_rect.size.x * 0.5)
	var inner_ry: float = max(8.0, focus_rect.size.y * 0.5)
	var feather: float = max(28.0, max(inner_rx, inner_ry) * 0.22)
	var outer_rx: float = inner_rx + feather
	var outer_ry: float = inner_ry + feather
	var shadow_alpha: float = DIM_ALPHA * clamp(alpha, 0.0, 1.0)
	var top: float = clamp(center.y - outer_ry, 0.0, gameplay_height)
	var bottom: float = clamp(center.y + outer_ry, 0.0, gameplay_height)

	_draw_shadow_rect(canvas, Rect2(0.0, 0.0, gameplay_width, top), shadow_alpha)
	_draw_shadow_rect(canvas, Rect2(0.0, bottom, gameplay_width, gameplay_height - bottom), shadow_alpha)
	if bottom <= top:
		return

	var slice_h: float = max(1.0, (bottom - top) / float(SHADOW_OPENING_SLICE_COUNT))
	for slice_index in range(SHADOW_OPENING_SLICE_COUNT):
		var y0: float = top + float(slice_index) * slice_h
		var y1: float = min(bottom, y0 + slice_h)
		var y_mid: float = (y0 + y1) * 0.5
		var outer_half: float = _ellipse_half_width(y_mid, center.y, outer_rx, outer_ry)
		var inner_half: float = _ellipse_half_width(y_mid, center.y, inner_rx, inner_ry)
		var outer_left: float = clamp(center.x - outer_half, 0.0, gameplay_width)
		var outer_right: float = clamp(center.x + outer_half, 0.0, gameplay_width)
		var row_h: float = y1 - y0

		_draw_shadow_rect(canvas, Rect2(0.0, y0, outer_left, row_h), shadow_alpha)
		_draw_shadow_rect(canvas, Rect2(outer_right, y0, gameplay_width - outer_right, row_h), shadow_alpha)
		_draw_shadow_feather_row(canvas, center.x, y0, row_h, outer_half, inner_half, shadow_alpha, gameplay_width)


func _get_scoring_side(hud_state) -> String:
	if hud_state != null and hud_state.has_method("get_last_scoring_side"):
		var side: String = str(hud_state.get_last_scoring_side())
		if side == "player" or side == "boss":
			return side
	var player_points: int = 0
	var boss_points: int = 0
	if hud_state != null and hud_state.has_method("get_player_points"):
		player_points = int(hud_state.get_player_points())
	if hud_state != null and hud_state.has_method("get_boss_points"):
		boss_points = int(hud_state.get_boss_points())
	if player_points > boss_points:
		return "player"
	if boss_points > player_points:
		return "boss"
	return ""


func _draw_stage_light_beams(
	canvas: Node2D,
	hud_state,
	draw_context: Dictionary,
	gameplay_width: float,
	gameplay_height: float,
	alpha: float,
	animation_frame: float
) -> void:
	var scoring_side: String = _get_scoring_side(hud_state)
	if scoring_side != "player" and scoring_side != "boss":
		return

	var focus_rect: Rect2 = _get_winner_shadow_rect(scoring_side, draw_context, gameplay_width, gameplay_height)
	var focus_center: Vector2 = focus_rect.get_center()
	var target_base := Vector2(focus_center.x, focus_center.y - focus_rect.size.y * 0.10)
	var target_half_width: float = max(68.0, focus_rect.size.x * 0.43)
	var color := Color(1.0, 0.92, 0.68, 1.0)
	var beam_alpha: float = 0.026 * clamp(alpha, 0.0, 1.0)
	var origin_y: float = -48.0

	var left_origin := Vector2(
		gameplay_width * 0.20 + sin(animation_frame * 0.026) * 18.0,
		origin_y
	)
	var right_origin := Vector2(
		gameplay_width * 0.80 + sin(animation_frame * 0.023 + 1.8) * 18.0,
		origin_y
	)
	var left_target := target_base + Vector2(sin(animation_frame * 0.021 + 0.6) * 16.0, 0.0)
	var right_target := target_base + Vector2(sin(animation_frame * 0.019 + 2.2) * 16.0, 0.0)

	_draw_stage_light_beam(canvas, left_origin, left_target, 12.0, target_half_width, color, beam_alpha)
	_draw_stage_light_beam(canvas, right_origin, right_target, 12.0, target_half_width, color, beam_alpha * 0.88)


func _draw_stage_light_beam(
	canvas: Node2D,
	origin: Vector2,
	target: Vector2,
	top_half_width: float,
	target_half_width: float,
	color: Color,
	alpha: float
) -> void:
	var direction: Vector2 = target - origin
	if direction.length() < 1.0:
		return
	var normal := Vector2(-direction.y, direction.x).normalized()
	for band_index in range(STAGE_LIGHT_BAND_STEPS):
		var progress: float = float(band_index) / float(max(1, STAGE_LIGHT_BAND_STEPS - 1))
		var width_scale: float = lerpf(1.0, 0.34, progress)
		var band_alpha: float = alpha * lerpf(0.20, 0.78, progress)
		var top_half: float = top_half_width * width_scale
		var bottom_half: float = target_half_width * width_scale
		var points := PackedVector2Array([
			origin - normal * top_half,
			origin + normal * top_half,
			target + normal * bottom_half,
			target - normal * bottom_half,
		])
		canvas.draw_colored_polygon(points, Color(color.r, color.g, color.b, band_alpha))


func _draw_shadow_feather_row(
	canvas: Node2D,
	center_x: float,
	y: float,
	height: float,
	outer_half: float,
	inner_half: float,
	shadow_alpha: float,
	gameplay_width: float
) -> void:
	if outer_half <= inner_half:
		return
	var previous_half: float = outer_half
	for step_index in range(SHADOW_FEATHER_STEPS):
		var t: float = float(step_index + 1) / float(SHADOW_FEATHER_STEPS)
		var next_half: float = lerpf(outer_half, inner_half, t)
		var band_alpha: float = shadow_alpha * pow(1.0 - t, 1.25)
		if band_alpha > 0.001:
			_draw_shadow_rect(
				canvas,
				Rect2(
					clamp(center_x - previous_half, 0.0, gameplay_width),
					y,
					max(0.0, previous_half - next_half),
					height
				),
				band_alpha
			)
			_draw_shadow_rect(
				canvas,
				Rect2(
					clamp(center_x + next_half, 0.0, gameplay_width),
					y,
					max(0.0, previous_half - next_half),
					height
				),
				band_alpha
			)
		previous_half = next_half


func _ellipse_half_width(y: float, center_y: float, radius_x: float, radius_y: float) -> float:
	if radius_x <= 0.0 or radius_y <= 0.0:
		return 0.0
	var dy: float = abs(y - center_y) / radius_y
	if dy >= 1.0:
		return 0.0
	return radius_x * sqrt(max(0.0, 1.0 - dy * dy))


func _draw_shadow_rect(canvas: Node2D, rect: Rect2, alpha: float) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0 or alpha <= 0.0:
		return
	canvas.draw_rect(rect, Color(0.0, 0.0, 0.0, alpha))


func _get_winner_shadow_rect(
	scoring_side: String,
	draw_context: Dictionary,
	gameplay_width: float,
	gameplay_height: float
) -> Rect2:
	if scoring_side == "boss":
		var boss_pos: Vector2 = _get_vector2(draw_context, "boss_pos", Vector2(gameplay_width * 0.5 - 50.0, 25.0))
		var boss_size: Vector2 = _get_vector2(draw_context, "boss_paddle_size", Vector2(100.0, 40.0))
		var boss_hitbox_height: float = float(draw_context.get("boss_hitbox_height", boss_size.y))
		var boss_center := Vector2(
			boss_pos.x + boss_size.x * 0.5,
			boss_pos.y + boss_hitbox_height * 0.5 + float(draw_context.get("boss_visual_center_y_offset", BOSS_VISUAL_CENTER_Y_OFFSET))
		)
		var boss_opening_size := Vector2(184.0, 154.0)
		return Rect2(boss_center - boss_opening_size * 0.5, boss_opening_size)

	var player_pos: Vector2 = _get_vector2(draw_context, "player_pos", Vector2(gameplay_width * 0.5 - 77.5, gameplay_height - 50.0))
	var player_size: Vector2 = _get_vector2(draw_context, "player_paddle_size", Vector2(155.0, 50.0))
	var player_scale: float = max(0.1, float(draw_context.get("player_paddle_scale", max(1.0, player_size.x / 155.0))))
	var draw_size: Vector2 = PLAYER_RESULT_DRAW_SIZE * player_scale
	var player_center := Vector2(
		player_pos.x + player_size.x * 0.5,
		player_pos.y + player_size.y - draw_size.y * 0.48 + 12.0
	)
	var player_opening_size := Vector2(238.0, 190.0) * player_scale
	return Rect2(player_center - player_opening_size * 0.5, player_opening_size)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _get_overlay_alpha(hud_state, fade_in_duration: float) -> float:
	if hud_state != null and hud_state.has_method("get_overlay_alpha"):
		return float(hud_state.get_overlay_alpha())
	return clamp(hud_state.get_timer() / max(0.001, fade_in_duration), 0.0, 1.0)


func _get_animation_frame_time(hud_state) -> float:
	if hud_state != null and hud_state.has_method("get_animation_frame_time"):
		return float(hud_state.get_animation_frame_time())
	return float(hud_state.get_animation_frame())


func _alpha_color(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * clamp(alpha, 0.0, 1.0))


func _rgb(r: float, g: float, b: float, alpha: float) -> Color:
	return Color(r / 255.0, g / 255.0, b / 255.0, clamp(alpha, 0.0, 1.0))


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
