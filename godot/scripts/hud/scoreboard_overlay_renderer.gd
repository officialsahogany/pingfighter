extends RefCounted

const ScoreboardOverlayFrameRenderer := preload("res://scripts/hud/scoreboard_overlay_frame_renderer.gd")
const ScoreboardOverlayHeaderRenderer := preload("res://scripts/hud/scoreboard_overlay_header_renderer.gd")
const ScoreboardOverlayScorePanelRenderer := preload("res://scripts/hud/scoreboard_overlay_score_panel_renderer.gd")

var frame_renderer: Object = ScoreboardOverlayFrameRenderer.new()
var header_renderer: Object = ScoreboardOverlayHeaderRenderer.new()
var score_panel_renderer: Object = ScoreboardOverlayScorePanelRenderer.new()


func draw(
	canvas: Node2D,
	hud_state,
	gameplay_width: float,
	gameplay_height: float,
	win_goal: int,
	fade_in_duration: float
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

	canvas.draw_rect(Rect2(0.0, 0.0, gameplay_width, gameplay_height), Color(0.0, 0.0, 0.0, (180.0 / 255.0) * alpha))
	frame_renderer.draw(canvas, Rect2(board_x, board_y, board_width, board_height), alpha)
	canvas.draw_rect(Rect2(inner_x, inner_y, inner_w, inner_h), _rgb(5.0, 8.0, 22.0, alpha))
	header_renderer.draw(canvas, Rect2(header_x, header_y, header_w, header_h), alpha)

	var score_area_x: float = header_x + 5.0
	var score_area_y: float = header_y + header_h + 15.0
	var score_area_w: float = header_w - 10.0
	var score_area_h: float = inner_h - header_h - 70.0
	var score_area_rect: Rect2 = Rect2(score_area_x, score_area_y, score_area_w, score_area_h)
	score_panel_renderer.draw(
		canvas,
		score_area_rect,
		center_x,
		animation_frame,
		hud_state.get_player_points(),
		hud_state.get_boss_points(),
		alpha
	)

	var footer_rect: Rect2 = Rect2(header_x + 5.0, inner_y + inner_h - 52.0, header_w - 10.0, 36.0)
	canvas.draw_rect(footer_rect, _rgb(10.0, 25.0, 55.0, alpha))
	canvas.draw_rect(footer_rect, _rgb(60.0, 130.0, 210.0, alpha), false, 2.0)
	_draw_text_centered(canvas, footer_rect.get_center(), "FIRST TO %d" % win_goal, 17, _rgb(100.0, 180.0, 255.0, 1.0), alpha)


func _draw_text_centered(canvas: Node2D, center: Vector2, text: String, font_size: int, color: Color, alpha: float) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline: Vector2 = Vector2(center.x - text_size.x * 0.5, center.y + text_size.y * 0.35)
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, _alpha_color(color, alpha))


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
