extends RefCounted

const Stage1DaljiSpinningTopRenderer := preload("res://scripts/stages/stage1/stage1_dalji_spinning_top_renderer.gd")
const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const CAST_DURATION_SEC := 0.4
const WHIP_COLOR := Color(0.545, 0.271, 0.075, 1.0)
const WHIP_SEGMENTS := 3
const TIMER_BAR_SIZE := Vector2(150.0, 12.0)
const TIMER_BAR_MARGIN := Vector2(16.0, 28.0)
const TIMER_STACK_SPACING := 18.0
const TIMER_STACK_KEY := "dalji_vision_chain_top"

var _top_renderer: Object = Stage1DaljiSpinningTopRenderer.new()


func draw(
	canvas: CanvasItem,
	snapshot: Dictionary,
	shake_offset: Vector2 = Vector2.ZERO,
	timer_stack: Object = null
) -> void:
	if canvas == null:
		return
	var tops := _get_array(snapshot.get("tops", []))
	var cast_remaining := float(snapshot.get("cast_remaining", 0.0))
	if cast_remaining > 0.0:
		_draw_launch_cords(
			canvas,
			snapshot.get("player_anchor", Vector2.ZERO) as Vector2,
			tops,
			cast_remaining,
			shake_offset
		)
	_top_renderer.draw_top_set(canvas, tops, shake_offset)
	_draw_timer_bar(
		canvas,
		float(snapshot.get("active_duration_ratio", 0.0)),
		float(snapshot.get("active_duration_remaining_sec", 0.0)),
		timer_stack
	)


func _draw_launch_cords(
	canvas: CanvasItem,
	anchor: Vector2,
	tops: Array,
	cast_remaining: float,
	shake_offset: Vector2
) -> void:
	var cast_progress := 1.0 - clampf(cast_remaining / CAST_DURATION_SEC, 0.0, 1.0)
	var start := anchor + shake_offset
	for top_value: Variant in tops:
		if not (top_value is Dictionary):
			continue
		var top := top_value as Dictionary
		var end := Vector2(float(top.get("x", 0.0)), float(top.get("y", 0.0))) + shake_offset
		var control := Vector2(
			(start.x + end.x) * 0.5 + sin(cast_progress * TAU) * 30.0,
			(start.y + end.y) * 0.5 - 20.0
		)
		for segment in range(WHIP_SEGMENTS):
			var t1 := float(segment) / float(WHIP_SEGMENTS)
			var t2 := float(segment + 1) / float(WHIP_SEGMENTS)
			canvas.draw_line(
				_quadratic_point(start, control, end, t1),
				_quadratic_point(start, control, end, t2),
				WHIP_COLOR,
				maxf(1.0, 3.0 - floorf(float(segment) * 0.3)),
				true
			)


func _quadratic_point(start: Vector2, control: Vector2, end: Vector2, t: float) -> Vector2:
	var inv := 1.0 - t
	return start * inv * inv + control * 2.0 * t * inv + end * t * t


func _draw_timer_bar(
	canvas: CanvasItem,
	ratio: float,
	remaining_sec: float,
	timer_stack: Object
) -> void:
	var safe_ratio := clampf(ratio, 0.0, 1.0)
	if safe_ratio <= 0.0:
		return
	var stack_index := 0
	if timer_stack != null and timer_stack.has_method("claim"):
		stack_index = maxi(0, int(timer_stack.claim(TIMER_STACK_KEY, true)))
	var position := Vector2(
		760.0 - TIMER_BAR_SIZE.x - TIMER_BAR_MARGIN.x,
		750.0 - TIMER_BAR_MARGIN.y - float(stack_index) * TIMER_STACK_SPACING
	)
	var rect := Rect2(position, TIMER_BAR_SIZE)
	canvas.draw_rect(rect.grow(3.0), Color(0.0, 0.0, 0.0, 0.45))
	canvas.draw_rect(rect, Color(0.035, 0.075, 0.15, 0.84))
	canvas.draw_rect(
		Rect2(rect.position + Vector2(2.0, 2.0), Vector2((rect.size.x - 4.0) * safe_ratio, rect.size.y - 4.0)),
		Color(0.46, 0.91, 0.86, 0.94)
	)
	canvas.draw_rect(rect, Color(0.82, 1.0, 0.96, 0.90), false, 2.0)
	var label := "%s  %s" % [
		CommonSkillCatalog.get_dalji_vision_timer_label(),
		_format_seconds(maxf(0.0, remaining_sec)),
	]
	canvas.draw_string(
		ThemeDB.fallback_font,
		rect.position + Vector2(8.0, -6.0),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		142.0,
		10,
		Color(0.92, 1.0, 0.98, 0.96)
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


func _get_array(value: Variant) -> Array:
	return value if value is Array else []
