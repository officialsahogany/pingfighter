extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const ICON_TEXTURE: Texture2D = preload("res://assets/sprites/perks/sage_ring_mugong_icon.png")

const TIMER_STACK_KEY := "hyeonmun_charyeok"
const TIMER_BAR_SIZE := Vector2(150.0, 12.0)
const TIMER_BAR_MARGIN := Vector2(16.0, 28.0)
const TIMER_STACK_SPACING := 18.0


func draw(canvas: CanvasItem, timer_stack: Object, snapshot: Dictionary) -> void:
	if canvas == null or not bool(snapshot.get("active", false)):
		return
	var stack_index := claim_timer_stack_index(timer_stack)
	var frame_rect := Rect2(get_timer_bar_position(stack_index), TIMER_BAR_SIZE)
	var ratio := clampf(float(snapshot.get("duration_ratio", 0.0)), 0.0, 1.0)
	var remaining_sec := maxf(0.0, float(snapshot.get("remaining_sec", 0.0)))
	var level_bonus := maxi(0, int(snapshot.get("level_bonus", 0)))
	var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.012)

	_draw_frame(canvas, frame_rect)
	_draw_fill(canvas, frame_rect, ratio, remaining_sec <= 2.0, pulse)
	_draw_icon(canvas, frame_rect, pulse)
	_draw_label(canvas, frame_rect, level_bonus, remaining_sec)


func get_timer_bar_position(stack_index: int) -> Vector2:
	return Vector2(
		760.0 - TIMER_BAR_SIZE.x - TIMER_BAR_MARGIN.x,
		750.0 - TIMER_BAR_MARGIN.y - float(maxi(0, stack_index)) * TIMER_STACK_SPACING
	)


func claim_timer_stack_index(timer_stack: Object) -> int:
	if timer_stack != null and timer_stack.has_method("claim"):
		var claimed := int(timer_stack.claim(TIMER_STACK_KEY, true))
		if claimed >= 0:
			return claimed
	return 0


func _draw_frame(canvas: CanvasItem, frame_rect: Rect2) -> void:
	canvas.draw_rect(frame_rect.grow(5.0), Color(0.0, 0.0, 0.0, 0.28))
	canvas.draw_rect(frame_rect.grow(5.0), Color(0.08, 0.025, 0.13, 0.94))
	canvas.draw_rect(frame_rect.grow(3.0), Color(0.44, 0.16, 0.68, 0.90))
	canvas.draw_rect(frame_rect.grow(3.0), Color(0.92, 0.65, 1.0, 0.75), false, 2.0)
	canvas.draw_rect(frame_rect.grow(2.0), Color(0.04, 0.01, 0.08, 0.96))
	canvas.draw_rect(frame_rect, Color(0.025, 0.012, 0.05, 0.96))


func _draw_fill(canvas: CanvasItem, frame_rect: Rect2, ratio: float, warning: bool, pulse: float) -> void:
	var fill_width := maxf(1.0, (frame_rect.size.x - 4.0) * ratio)
	var fill_rect := Rect2(frame_rect.position + Vector2(2.0, 2.0), Vector2(fill_width, frame_rect.size.y - 4.0))
	var base_color := Color(0.60, 0.22, 0.95, 0.98)
	var highlight_color := Color(0.94, 0.70, 1.0, 0.98)
	if warning:
		base_color = Color(1.0, 0.22 + pulse * 0.22, 0.40, 0.99)
		highlight_color = Color(1.0, 0.78, 0.90, 0.99)
	canvas.draw_rect(fill_rect, base_color)
	canvas.draw_rect(Rect2(fill_rect.position, Vector2(fill_rect.size.x, maxf(2.0, fill_rect.size.y * 0.36))), highlight_color)
	for index in range(1, 10):
		var tick_x := frame_rect.position.x + 2.0 + (frame_rect.size.x - 4.0) * (float(index) / 10.0)
		canvas.draw_line(
			Vector2(tick_x, frame_rect.position.y + frame_rect.size.y - 4.0),
			Vector2(tick_x, frame_rect.position.y + frame_rect.size.y - 1.0),
			Color(0.95, 0.84, 1.0, 0.66),
			1.0
		)


func _draw_icon(canvas: CanvasItem, frame_rect: Rect2, pulse: float) -> void:
	var center := frame_rect.position + Vector2(-19.0, frame_rect.size.y * 0.5)
	canvas.draw_circle(center, 15.0 + pulse * 1.5, Color(0.55, 0.16, 0.92, 0.16 + pulse * 0.08))
	canvas.draw_circle(center, 11.5, Color(0.10, 0.025, 0.17, 0.92))
	if ICON_TEXTURE != null:
		canvas.draw_texture_rect(ICON_TEXTURE, Rect2(center - Vector2(10.0, 10.0), Vector2(20.0, 20.0)), false)
	canvas.draw_arc(center, 12.0, 0.0, TAU, 24, Color(0.94, 0.78, 1.0, 0.76), 1.4)


func _draw_label(canvas: CanvasItem, frame_rect: Rect2, level_bonus: int, remaining_sec: float) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var perk_name := LanguageSettings.localize_perk_name("sage_ring", "현문차력")
	var seconds_text := _format_seconds(remaining_sec)
	var label := "%s +%d  %s" % [perk_name, level_bonus, seconds_text]
	canvas.draw_string(
		font,
		frame_rect.position + Vector2(8.0, -6.0),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		142.0,
		10,
		Color(0.96, 0.90, 1.0, 0.92)
	)


func _format_seconds(seconds: float) -> String:
	var language := LanguageSettings.get_language()
	if language == LanguageSettings.LANGUAGE_CHINESE or language == LanguageSettings.LANGUAGE_JAPANESE:
		return "%.1f秒" % seconds
	if language == LanguageSettings.LANGUAGE_RUSSIAN:
		return "%.1fс" % seconds
	if language in [
		LanguageSettings.LANGUAGE_ENGLISH,
		LanguageSettings.LANGUAGE_SPANISH,
		LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL,
	]:
		return "%.1fs" % seconds
	return "%.1f초" % seconds
