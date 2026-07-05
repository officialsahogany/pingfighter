extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const StageClearResultLayoutHelper := preload("res://scripts/ui/stage_clear_result_layout_helper.gd")
const StageClearResultShapeHelper := preload("res://scripts/ui/stage_clear_result_shape_helper.gd")
const StageClearResultSheetDrawHelper := preload("res://scripts/ui/stage_clear_result_sheet_draw_helper.gd")
const StageClearResultTextLayoutHelper := preload("res://scripts/ui/stage_clear_result_text_layout_helper.gd")


static func draw_background(
	canvas: CanvasItem,
	background_texture: Texture2D,
	view_size: Vector2
) -> void:
	if canvas == null:
		return
	if background_texture == null:
		canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.05, 0.07, 0.12, 1.0))
		return
	var texture_size: Vector2 = background_texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.05, 0.07, 0.12, 1.0))
		return
	var source: Rect2 = StageClearResultLayoutHelper.cover_source_rect(texture_size, view_size)
	canvas.draw_texture_rect_region(background_texture, Rect2(Vector2.ZERO, view_size), source, Color.WHITE, false, true)


static func draw_dalji_click_dialogue(
	canvas: CanvasItem,
	font: Font,
	view_size: Vector2,
	scale: float,
	dialogue_timer: float,
	dialogue_fade_duration: float,
	dialogue_text: String
) -> void:
	if canvas == null or font == null or dialogue_timer <= 0.0:
		return
	var alpha: float = clamp(dialogue_timer / dialogue_fade_duration, 0.0, 1.0)
	var boss_rect: Rect2 = StageClearResultLayoutHelper.get_dalji_draw_rect(view_size, scale)
	var bubble_size := Vector2(210.0, 58.0) * scale
	var bubble_position := Vector2(
		max(18.0 * scale, boss_rect.position.x + 132.0 * scale),
		max(52.0 * scale, boss_rect.position.y - 42.0 * scale)
	)
	var bubble := Rect2(bubble_position, bubble_size)
	StageClearResultShapeHelper.draw_panel(
		canvas,
		bubble,
		Color(1.0, 0.96, 0.98, 0.90 * alpha),
		Color(1.0, 0.72, 0.82, 0.95 * alpha),
		2.0 * scale,
		17.0 * scale
	)
	var tail := PackedVector2Array([
		Vector2(bubble.position.x + 44.0 * scale, bubble.position.y + bubble.size.y - 2.0 * scale),
		Vector2(bubble.position.x + 72.0 * scale, bubble.position.y + bubble.size.y - 2.0 * scale),
		Vector2(bubble.position.x + 54.0 * scale, bubble.position.y + bubble.size.y + 22.0 * scale),
	])
	canvas.draw_colored_polygon(tail, Color(1.0, 0.96, 0.98, 0.90 * alpha))
	StageClearResultTextLayoutHelper.draw_centered_text(
		canvas,
		font,
		LanguageSettings.translate_text(dialogue_text),
		bubble,
		int(round(26.0 * scale)),
		Color(0.34, 0.12, 0.18, 0.98 * alpha)
	)


static func draw_plaza_notice(
	canvas: CanvasItem,
	font: Font,
	scale: float,
	plaza_rect: Rect2,
	remaining: float
) -> void:
	if canvas == null or font == null or remaining <= 0.0 or plaza_rect.size.x <= 0.0:
		return
	# remaining 은 만료까지 남은 초. 마지막 0.35초 동안만 페이드아웃.
	var alpha: float = clamp(remaining / 0.35, 0.0, 1.0)
	var bubble_size := Vector2(196.0, 46.0) * scale
	var bubble_position := Vector2(
		plaza_rect.position.x + (plaza_rect.size.x - bubble_size.x) * 0.5,
		plaza_rect.position.y - bubble_size.y - 14.0 * scale
	)
	var bubble := Rect2(bubble_position, bubble_size)
	StageClearResultShapeHelper.draw_panel(
		canvas,
		bubble,
		Color(0.12, 0.13, 0.18, 0.92 * alpha),
		Color(1.0, 0.86, 0.42, 0.95 * alpha),
		2.0 * scale,
		13.0 * scale
	)
	var center_x: float = bubble.position.x + bubble.size.x * 0.5
	var tail := PackedVector2Array([
		Vector2(center_x - 12.0 * scale, bubble.position.y + bubble.size.y - 2.0 * scale),
		Vector2(center_x + 12.0 * scale, bubble.position.y + bubble.size.y - 2.0 * scale),
		Vector2(center_x, bubble.position.y + bubble.size.y + 16.0 * scale),
	])
	canvas.draw_colored_polygon(tail, Color(0.12, 0.13, 0.18, 0.92 * alpha))
	StageClearResultTextLayoutHelper.draw_centered_text(
		canvas,
		font,
		LanguageSettings.translate_text("준비중입니다"),
		bubble,
		int(round(22.0 * scale)),
		Color(1.0, 0.92, 0.66, 0.98 * alpha)
	)


static func draw_player_victory_fallback(
	canvas: CanvasItem,
	font: Font,
	view_size: Vector2,
	scale: float,
	timer: float,
	player_victory_sheet: Texture2D,
	frame_interval: float,
	frame_count: int,
	grid_cols: int,
	cell_size: Vector2,
	title_text: String,
	pose_text: String,
	subtitle_text: String
) -> void:
	if canvas == null or font == null:
		return
	var panel: Rect2 = StageClearResultLayoutHelper.get_player_victory_panel_rect(view_size, scale)
	StageClearResultShapeHelper.draw_panel(canvas, panel, Color(0.03, 0.75, 0.78, 0.74), Color(0.76, 1.0, 1.0, 0.92), 2.0 * scale, 22.0 * scale)

	if player_victory_sheet != null:
		var frame: int = int(floor(timer / frame_interval)) % frame_count
		var actor_rect: Rect2 = StageClearResultLayoutHelper.get_player_victory_actor_rect(view_size, scale)
		StageClearResultSheetDrawHelper.draw_sheet_frame(canvas, player_victory_sheet, frame, grid_cols, cell_size, actor_rect, 1.0)

	StageClearResultTextLayoutHelper.draw_text(
		canvas,
		font,
		LanguageSettings.translate_text(title_text),
		Vector2(panel.position.x + 34.0 * scale, panel.position.y + panel.size.y - 325.0 * scale),
		int(round(25.0 * scale)),
		Color(0.96, 1.0, 1.0, 0.97)
	)
	StageClearResultTextLayoutHelper.draw_text(
		canvas,
		font,
		LanguageSettings.translate_text(pose_text),
		Vector2(panel.position.x + 34.0 * scale, panel.position.y + panel.size.y - 278.0 * scale),
		int(round(34.0 * scale)),
		Color(1.0, 1.0, 1.0, 0.96)
	)
	StageClearResultTextLayoutHelper.draw_text(
		canvas,
		font,
		LanguageSettings.translate_text(subtitle_text),
		Vector2(panel.position.x + 34.0 * scale, panel.position.y + panel.size.y - 225.0 * scale),
		int(round(23.0 * scale)),
		Color(0.83, 0.98, 1.0, 0.92)
	)


static func draw_footer(
	canvas: CanvasItem,
	font: Font,
	view_size: Vector2,
	scale: float,
	current_stage: int
) -> void:
	if canvas == null or font == null:
		return
	StageClearResultTextLayoutHelper.draw_text(
		canvas,
		font,
		LanguageSettings.translate_text("스테이지 %d 결과 화면" % current_stage),
		Vector2(34.0, view_size.y - 26.0 * scale),
		int(round(24.0 * scale)),
		Color(0.86, 0.88, 1.0, 0.82)
	)
