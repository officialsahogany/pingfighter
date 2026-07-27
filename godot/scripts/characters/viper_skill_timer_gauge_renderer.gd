extends RefCounted

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ViperSkillVisibilityQuery := preload("res://scripts/characters/viper_skill_visibility_query.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

var _visibility_query := ViperSkillVisibilityQuery.new()


func draw_ignition_aura_runtime_timer_gauge(
	canvas: CanvasItem,
	timer_stack: Object,
	runtime: Object,
	bar_size: Vector2,
	margin: Vector2,
	stack_spacing: float,
	stack_key: String
) -> void:
	if not runtime.ignition_active:
		return
	draw_ignition_aura_timer_gauge(
		canvas,
		timer_stack,
		_visibility_query.get_ignition_aura_ratio(runtime),
		runtime.ignition_remaining_frames,
		bar_size,
		margin,
		stack_spacing,
		stack_key
	)


func draw_ignition_aura_timer_gauge(
	canvas: CanvasItem,
	timer_stack: Object,
	ratio: float,
	remaining_frames: float,
	bar_size: Vector2,
	margin: Vector2,
	stack_spacing: float,
	stack_key: String
) -> void:
	if canvas == null:
		return
	var stack_index: int = claim_timer_stack_index(timer_stack, stack_key)
	var frame_rect := Rect2(get_timer_bar_position(stack_index, bar_size, margin, stack_spacing), bar_size)
	var pulse: float = abs(sin(float(Time.get_ticks_msec()) * 0.015))
	_draw_timer_frame(
		canvas,
		frame_rect,
		Color(0.12, 0.04, 0.02, 0.94),
		Color(0.76, 0.26, 0.06, 0.88),
		Color(1.0, 0.66, 0.16, 0.78),
		Color(0.08, 0.02, 0.01, 0.96),
		Color(0.05, 0.025, 0.01, 0.94)
	)
	var base_color := Color(1.0, 0.42, 0.10, 0.98)
	var highlight_color := Color(1.0, 0.86, 0.32, 0.98)
	if remaining_frames <= 180.0:
		base_color = Color(1.0, 0.18 + pulse * 0.20, 0.06, 0.99)
		highlight_color = Color(1.0, 0.78, 0.36, 0.99)
	_draw_timer_fill(canvas, frame_rect, ratio, base_color, highlight_color, Color(1.0, 0.90, 0.48, 0.70), 0.36)
	var icon_center := frame_rect.position + Vector2(-19.0, frame_rect.size.y * 0.5)
	ImpactFlareTextureCache.draw_glow(canvas, icon_center, 17.0, Color(1.0, 0.34, 0.06), 0.24 + pulse * 0.12)
	canvas.draw_circle(icon_center, 8.5, Color(1.0, 0.28, 0.08, 0.68))
	canvas.draw_circle(icon_center + Vector2(0.0, -2.0), 4.8, Color(1.0, 0.86, 0.30, 0.70))
	canvas.draw_arc(icon_center, 12.0, -PI * 0.15, PI * 1.35, 24, Color(1.0, 0.96, 0.74, 0.54), 1.6)
	var font: Font = ThemeDB.fallback_font
	if font != null:
		var remaining_seconds: float = max(0.0, remaining_frames / 60.0)
		var timer_language := LanguageSettings.get_language()
		var seconds_text: String = "%.1fs" % remaining_seconds
		if timer_language == LanguageSettings.LANGUAGE_CHINESE or timer_language == LanguageSettings.LANGUAGE_JAPANESE:
			seconds_text = "%.1f秒" % remaining_seconds
		elif timer_language == LanguageSettings.LANGUAGE_RUSSIAN:
			seconds_text = "%.1fс" % remaining_seconds
		elif timer_language != LanguageSettings.LANGUAGE_ENGLISH and timer_language != LanguageSettings.LANGUAGE_SPANISH and timer_language != LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
			seconds_text = "%.1f초" % remaining_seconds
		var label: String = "%s %s" % [LanguageSettings.translate_text("염화개맥"), seconds_text]
		canvas.draw_string(font, frame_rect.position + Vector2(8.0, -6.0), label, HORIZONTAL_ALIGNMENT_LEFT, 104.0, 10, Color(1.0, 0.95, 0.82, 0.90))


func draw_dual_glitch_runtime_timer_gauge(
	canvas: CanvasItem,
	timer_stack: Object,
	runtime: Object,
	bar_size: Vector2,
	margin: Vector2,
	stack_spacing: float,
	stack_key: String
) -> void:
	if runtime.dual_glitch_state not in ["startup", "spawn", "active"]:
		return
	var total_frames: float = max(1.0, runtime.dual_glitch_active_total_frames)
	var remaining_frames: float = _visibility_query.get_dual_glitch_remaining_frames(runtime)
	var ratio: float = clamp(remaining_frames / total_frames, 0.0, 1.0)
	var remaining_seconds: float = remaining_frames / 60.0
	draw_dual_glitch_timer_gauge(
		canvas,
		timer_stack,
		ratio,
		remaining_seconds,
		remaining_seconds <= 3.0 and runtime.dual_glitch_state == "active",
		bar_size,
		margin,
		stack_spacing,
		stack_key
	)


func draw_dual_glitch_timer_gauge(
	canvas: CanvasItem,
	timer_stack: Object,
	ratio: float,
	remaining_seconds: float,
	is_warning: bool,
	bar_size: Vector2,
	margin: Vector2,
	stack_spacing: float,
	stack_key: String
) -> void:
	if canvas == null:
		return
	var stack_index: int = claim_timer_stack_index(timer_stack, stack_key)
	var frame_rect := Rect2(get_timer_bar_position(stack_index, bar_size, margin, stack_spacing), bar_size)
	_draw_timer_frame(
		canvas,
		frame_rect,
		Color(0.06, 0.03, 0.11, 0.94),
		Color(0.16, 0.60, 0.76, 0.90),
		Color(0.64, 0.20, 0.92, 0.82),
		Color(0.04, 0.02, 0.08, 0.96),
		Color(0.02, 0.03, 0.07, 0.94)
	)
	var pulse: float = abs(sin(float(Time.get_ticks_msec()) * 0.015))
	var base_color := Color(0.24, 0.95, 1.0, 0.98)
	var highlight_color := Color(0.92, 0.56, 1.0, 0.98)
	if is_warning:
		base_color = Color(1.0, 0.22 + pulse * 0.22, 0.46 + pulse * 0.20, 0.99)
		highlight_color = Color(1.0, 0.76, 0.92, 0.99)
	_draw_timer_fill(canvas, frame_rect, ratio, base_color, highlight_color, Color(0.68, 0.92, 1.0, 0.72), 0.34)
	var icon_center := frame_rect.position + Vector2(-19.0, frame_rect.size.y * 0.5)
	ImpactFlareTextureCache.draw_glow(canvas, icon_center, 16.0, Color(0.42, 0.0, 0.62), 0.22 + pulse * 0.10)
	canvas.draw_circle(icon_center + Vector2(-4.0, 0.0), 7.0, Color(0.24, 0.96, 1.0, 0.58))
	canvas.draw_circle(icon_center + Vector2(4.0, 0.0), 7.0, Color(0.82, 0.22, 1.0, 0.58))
	canvas.draw_arc(icon_center, 12.0, 0.0, TAU, 24, Color(0.96, 0.90, 1.0, 0.52), 1.6)
	var font: Font = ThemeDB.fallback_font
	if font != null:
		var label: String = "%s %.1f" % [LanguageSettings.translate_text("쌍영분신"), max(0.0, remaining_seconds)]
		canvas.draw_string(font, frame_rect.position + Vector2(8.0, -6.0), label, HORIZONTAL_ALIGNMENT_LEFT, 92.0, 10, Color(0.90, 0.98, 1.0, 0.88))


func get_timer_bar_position(stack_index: int, bar_size: Vector2, margin: Vector2, stack_spacing: float) -> Vector2:
	return Vector2(
		760.0 - bar_size.x - margin.x,
		750.0 - margin.y - float(max(0, stack_index)) * stack_spacing
	)


func claim_timer_stack_index(timer_stack: Object, stack_key: String) -> int:
	if timer_stack != null and timer_stack.has_method("claim"):
		var claimed: int = int(timer_stack.claim(stack_key, true))
		if claimed >= 0:
			return claimed
	return 0


func _draw_timer_frame(
	canvas: CanvasItem,
	frame_rect: Rect2,
	outer_color: Color,
	mid_color: Color,
	mid_border_color: Color,
	border_color: Color,
	inner_color: Color
) -> void:
	var outer_rect := frame_rect.grow(5.0)
	var mid_rect := frame_rect.grow(3.0)
	var border_rect := frame_rect.grow(2.0)
	canvas.draw_rect(outer_rect, Color(0.0, 0.0, 0.0, 0.28))
	canvas.draw_rect(outer_rect, outer_color)
	canvas.draw_rect(mid_rect, mid_color)
	canvas.draw_rect(mid_rect, mid_border_color, false, 2.0)
	canvas.draw_rect(border_rect, border_color)
	canvas.draw_rect(frame_rect, inner_color)


func _draw_timer_fill(
	canvas: CanvasItem,
	frame_rect: Rect2,
	ratio: float,
	base_color: Color,
	highlight_color: Color,
	tick_color: Color,
	highlight_height_ratio: float
) -> void:
	var fill_width: float = max(1.0, (frame_rect.size.x - 4.0) * ratio)
	var fill_rect := Rect2(frame_rect.position + Vector2(2.0, 2.0), Vector2(fill_width, frame_rect.size.y - 4.0))
	canvas.draw_rect(fill_rect, base_color)
	canvas.draw_rect(Rect2(fill_rect.position, Vector2(fill_rect.size.x, max(2.0, fill_rect.size.y * highlight_height_ratio))), highlight_color)
	for i in range(1, 10):
		var tick_x: float = frame_rect.position.x + 2.0 + (frame_rect.size.x - 4.0) * (float(i) / 10.0)
		canvas.draw_line(
			Vector2(tick_x, frame_rect.position.y + frame_rect.size.y - 4.0),
			Vector2(tick_x, frame_rect.position.y + frame_rect.size.y - 1.0),
			tick_color,
			1.0
		)
