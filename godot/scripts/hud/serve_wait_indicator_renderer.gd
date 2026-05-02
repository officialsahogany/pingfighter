extends RefCounted

const TUTORIAL_STAGE := 50
const PLAYER_AUTO_SERVE_DELAY := 3.0
const BOSS_AUTO_SERVE_DELAY := 1.0
const SERVE_FONT_SIZE := 24
const INFO_FONT_SIZE := 16


func draw(canvas: CanvasItem, width: float, height: float, context: Dictionary, deps: Dictionary) -> void:
	var round_state = deps.get("round_state", null)
	if canvas == null or round_state == null or not round_state.is_waiting_for_serve():
		return
	if int(context.get("current_stage", 1)) == TUTORIAL_STAGE:
		return

	var player_serves: bool = round_state.does_player_serve()
	var snapshot: Dictionary = round_state.get_snapshot()
	var serve_timer: float = float(snapshot.get("serve_timer", 0.0))
	if player_serves:
		_draw_player_serve(canvas, width, height, serve_timer)
	else:
		_draw_boss_serve(canvas, width, serve_timer)


func _draw_player_serve(canvas: CanvasItem, width: float, height: float, serve_timer: float) -> void:
	var center := Vector2(width * 0.5, height - 100.0)
	var text := "Player Serve"
	var serve_rect: Rect2 = _draw_text_centered(canvas, center, text, SERVE_FONT_SIZE, Color.WHITE)
	_draw_accent_line(canvas, width, serve_rect, Color(0.0, 0.78, 0.39, 0.92))

	var info_text := "Manual serve"
	if serve_timer >= 1.0:
		var remaining: int = int(max(0.0, ceil(PLAYER_AUTO_SERVE_DELAY - serve_timer)))
		if remaining > 0:
			info_text = "SPACE (%ds)" % remaining
		else:
			info_text = "Auto serve"
	var info_color := Color(0.78, 0.78, 0.78)
	if info_text == "Auto serve":
		info_color = Color(1.0, 1.0, 0.39)
	_draw_text_centered(canvas, Vector2(width * 0.5, serve_rect.position.y + serve_rect.size.y + 20.0), info_text, INFO_FONT_SIZE, info_color)


func _draw_boss_serve(canvas: CanvasItem, width: float, serve_timer: float) -> void:
	var center := Vector2(width * 0.5, 80.0)
	var text := "Boss Serve"
	var serve_rect: Rect2 = _draw_text_centered(canvas, center, text, SERVE_FONT_SIZE, Color.WHITE)
	_draw_accent_line(canvas, width, serve_rect, Color(0.78, 0.31, 0.31, 0.92))

	var info_text := "Preparing..."
	var info_color := Color(0.78, 0.78, 0.78)
	if serve_timer >= BOSS_AUTO_SERVE_DELAY:
		info_text = "Ready"
		info_color = Color(1.0, 1.0, 0.39)
	_draw_text_centered(canvas, Vector2(width * 0.5, serve_rect.position.y + serve_rect.size.y + 20.0), info_text, INFO_FONT_SIZE, info_color)


func _draw_accent_line(canvas: CanvasItem, width: float, serve_rect: Rect2, color: Color) -> void:
	var line_width: float = serve_rect.size.x + 20.0
	var line_rect := Rect2(
		Vector2((width - line_width) * 0.5, serve_rect.position.y + serve_rect.size.y + 5.0),
		Vector2(line_width, 3.0)
	)
	canvas.draw_rect(line_rect.grow(1.0), Color(0.0, 0.0, 0.0, 0.42), true)
	canvas.draw_rect(line_rect, color, true)


func _draw_text_centered(
	canvas: CanvasItem,
	center: Vector2,
	text: String,
	font_size: int,
	color: Color
) -> Rect2:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return Rect2(center, Vector2.ZERO)
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline := Vector2(center.x - text_size.x * 0.5, center.y + text_size.y * 0.35)
	for offset in [Vector2(-1.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, -1.0), Vector2(0.0, 1.0), Vector2(2.0, 2.0)]:
		canvas.draw_string(font, baseline + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, 0.72))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
	return Rect2(center - text_size * 0.5, text_size)
