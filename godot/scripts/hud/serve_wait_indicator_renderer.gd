extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const TUTORIAL_STAGE := 50
const PLAYER_AUTO_SERVE_DELAY := 3.0
const SERVE_FONT_SIZE := 24
const INFO_FONT_SIZE := 16
const SERVE_BANNER_FONT_SIZE := 48
const RESTART_NOTICE_FONT_SIZE := 52
const SERVE_BANNER_FADE_IN := 0.12
const SERVE_BANNER_FADE_OUT := 0.16
const RESTART_NOTICE_TEXT := "재시작!"
const STAGE_BOSS_NAMES := {
	1: "달지",
}

const SERVE_FONT: Font = preload("res://assets/fonts/NeoDunggeunmoPro.ttf")


func draw(canvas: CanvasItem, width: float, height: float, context: Dictionary, deps: Dictionary) -> void:
	var round_state = deps.get("round_state", null)
	if canvas == null or round_state == null or not round_state.is_waiting_for_serve():
		return
	if int(context.get("current_stage", 1)) == TUTORIAL_STAGE:
		return

	var player_serves: bool = round_state.does_player_serve()
	var snapshot: Dictionary = round_state.get_snapshot()
	var serve_timer: float = float(snapshot.get("serve_timer", 0.0))
	var serve_delay: float = float(snapshot.get("serve_delay", 1.0))
	var serve_label: String = _get_serve_label(player_serves, context)
	var accent_color: Color = Color(0.0, 0.78, 0.39, 0.92) if player_serves else Color(0.78, 0.31, 0.31, 0.92)
	if player_serves:
		_draw_player_serve(canvas, width, height, serve_timer, serve_label, accent_color)
	else:
		_draw_boss_serve(canvas, width, serve_timer, serve_delay, serve_label, accent_color)
	if bool(round_state.is_round_restart_notice_active() if round_state.has_method("is_round_restart_notice_active") else false):
		_draw_round_restart_notice(canvas, width, height, snapshot)
	if bool(round_state.is_serve_banner_active() if round_state.has_method("is_serve_banner_active") else false):
		_draw_serve_banner(canvas, width, height, snapshot, serve_label, accent_color)


func _draw_player_serve(
	canvas: CanvasItem,
	width: float,
	height: float,
	serve_timer: float,
	serve_label: String,
	accent_color: Color
) -> void:
	var center := Vector2(width * 0.5, height - 100.0)
	var serve_rect: Rect2 = _draw_text_centered(canvas, center, serve_label, SERVE_FONT_SIZE, Color.WHITE)
	_draw_accent_line(canvas, width, serve_rect, accent_color)

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


func _draw_boss_serve(
	canvas: CanvasItem,
	width: float,
	serve_timer: float,
	serve_delay: float,
	serve_label: String,
	accent_color: Color
) -> void:
	var center := Vector2(width * 0.5, 80.0)
	var serve_rect: Rect2 = _draw_text_centered(canvas, center, serve_label, SERVE_FONT_SIZE, Color.WHITE)
	_draw_accent_line(canvas, width, serve_rect, accent_color)

	var info_text := LanguageSettings.translate("hud.serve_wait.preparing")
	var info_color := Color(0.78, 0.78, 0.78)
	if serve_timer >= serve_delay:
		info_text = LanguageSettings.translate("hud.serve_wait.ready")
		info_color = Color(1.0, 1.0, 0.39)
	_draw_text_centered(canvas, Vector2(width * 0.5, serve_rect.position.y + serve_rect.size.y + 20.0), info_text, INFO_FONT_SIZE, info_color)


func _draw_serve_banner(
	canvas: CanvasItem,
	width: float,
	height: float,
	snapshot: Dictionary,
	serve_label: String,
	accent_color: Color
) -> void:
	var timer: float = float(snapshot.get("serve_banner_timer", 0.0))
	var duration: float = max(0.001, float(snapshot.get("serve_banner_duration", 0.85)))
	var alpha: float = _get_banner_alpha(timer, duration)
	if alpha <= 0.0:
		return
	canvas.draw_rect(Rect2(0.0, 0.0, width, height), Color(0.0, 0.0, 0.0, (120.0 / 255.0) * alpha), true)

	var center := Vector2(width * 0.5, height * 0.5)
	var serve_rect: Rect2 = _draw_text_centered(
		canvas,
		center,
		serve_label,
		SERVE_BANNER_FONT_SIZE,
		Color(1.0, 1.0, 1.0, alpha),
		alpha
	)
	var elapsed: float = duration - timer
	var pulse: float = 5.0 * sin(elapsed * 10.0)
	var line_width: float = serve_rect.size.x + 60.0 + pulse
	var line_rect := Rect2(
		Vector2((width - line_width) * 0.5, serve_rect.position.y + serve_rect.size.y + 10.0),
		Vector2(line_width, 4.0)
	)
	canvas.draw_rect(line_rect, Color(accent_color.r, accent_color.g, accent_color.b, alpha), true)


func _draw_round_restart_notice(
	canvas: CanvasItem,
	width: float,
	height: float,
	snapshot: Dictionary
) -> void:
	var timer: float = float(snapshot.get("round_restart_notice_timer", 0.0))
	var duration: float = max(0.001, float(snapshot.get("round_restart_notice_duration", 1.0)))
	var alpha: float = _get_banner_alpha(timer, duration)
	if alpha <= 0.0:
		return
	canvas.draw_rect(Rect2(0.0, 0.0, width, height), Color(0.0, 0.0, 0.0, (105.0 / 255.0) * alpha), true)

	var center := Vector2(width * 0.5, height * 0.5)
	var notice_rect: Rect2 = _draw_text_centered(
		canvas,
		center,
		RESTART_NOTICE_TEXT,
		RESTART_NOTICE_FONT_SIZE,
		Color(1.0, 0.92, 0.35, alpha),
		alpha
	)
	var elapsed: float = duration - timer
	var pulse: float = 7.0 * sin(elapsed * 12.0)
	var line_width: float = notice_rect.size.x + 76.0 + pulse
	var line_rect := Rect2(
		Vector2((width - line_width) * 0.5, notice_rect.position.y + notice_rect.size.y + 12.0),
		Vector2(line_width, 4.0)
	)
	canvas.draw_rect(line_rect.grow(1.0), Color(0.0, 0.0, 0.0, 0.48 * alpha), true)
	canvas.draw_rect(line_rect, Color(1.0, 0.72, 0.18, alpha), true)


func _get_banner_alpha(timer: float, duration: float) -> float:
	var elapsed: float = duration - timer
	if elapsed < SERVE_BANNER_FADE_IN:
		return clamp(elapsed / SERVE_BANNER_FADE_IN, 0.0, 1.0)
	if timer < SERVE_BANNER_FADE_OUT:
		return clamp(timer / SERVE_BANNER_FADE_OUT, 0.0, 1.0)
	return 1.0


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
	color: Color,
	shadow_alpha: float = 1.0
) -> Rect2:
	text = LanguageSettings.translate_text(text)
	var font: Font = SERVE_FONT if SERVE_FONT != null else ThemeDB.fallback_font
	if font == null:
		return Rect2(center, Vector2.ZERO)
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline := Vector2(center.x - text_size.x * 0.5, center.y + text_size.y * 0.35)
	for offset in [Vector2(-1.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, -1.0), Vector2(0.0, 1.0), Vector2(2.0, 2.0)]:
		canvas.draw_string(font, baseline + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, 0.72 * shadow_alpha))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
	return Rect2(center - text_size * 0.5, text_size)


func _get_serve_label(player_serves: bool, context: Dictionary) -> String:
	if player_serves:
		return LanguageSettings.translate_text("플레이어 서브")
	var current_stage: int = int(context.get("current_stage", 1))
	var boss_name_key: String = str(STAGE_BOSS_NAMES.get(current_stage, "보스"))
	var boss_name: String = LanguageSettings.translate_text(boss_name_key)
	return LanguageSettings.translate("hud.serve_wait.boss_turn_format") % boss_name
