extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const DEFAULT_QUAKE_WAVE_COUNT := 6
const DEFAULT_QUAKE_WAVE_SEGMENTS := 16
const DEFAULT_VISUAL_ONLY_QUAKE_WAVE_COUNT := 3
const DEFAULT_VISUAL_ONLY_QUAKE_WAVE_SEGMENTS := 8

var _text_layout_cache: Dictionary = {}


func draw_skill_warning_banner(
	canvas: CanvasItem,
	width: float,
	height: float,
	shake_offset: Vector2,
	warning: Dictionary
) -> void:
	var timer: float = float(warning.get("timer", 0.0))
	var text: String = LanguageSettings.translate_text(str(warning.get("text", "")))
	if timer <= 0.0 or text.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var duration: float = max(0.001, float(warning.get("duration", 1.0)))
	var remaining_ratio: float = clamp(timer / duration, 0.0, 1.0)
	var elapsed_ratio: float = 1.0 - remaining_ratio
	var appear_alpha: float = clamp(elapsed_ratio / 0.16, 0.0, 1.0)
	var fade_alpha: float = clamp(remaining_ratio / 0.18, 0.0, 1.0)
	var alpha: float = min(appear_alpha, fade_alpha)
	if alpha <= 0.0:
		return
	var time_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var pulse: float = 0.5 + 0.5 * sin(time_seconds * 9.0)
	var warning_color: Color = _get_skill_warning_color(str(warning.get("kind", "")))
	var max_text_width: float = 250.0
	var text_layout: Dictionary = _get_fitted_text_layout(font, text, 22, max_text_width, 15)
	var text_size: int = int(text_layout.get("font_size", 22))
	var measured_width: float = float(_get_vector2(text_layout.get("size", Vector2.ZERO), Vector2.ZERO).x)
	var banner_width: float = clamp(measured_width + 98.0, 238.0, 360.0)
	var banner_height: float = 43.0
	var center := Vector2(width * 0.5, clamp(height * 0.16, 76.0, 128.0)) + shake_offset
	var banner_rect := Rect2(
		Vector2(round(center.x - banner_width * 0.5), round(center.y - banner_height * 0.5)),
		Vector2(round(banner_width), banner_height)
	)
	canvas.draw_rect(banner_rect, Color(0.015, 0.025, 0.020, 0.74 * alpha))
	canvas.draw_rect(
		Rect2(banner_rect.position + Vector2(2.0, 2.0), banner_rect.size - Vector2(4.0, 4.0)),
		Color(warning_color.r, warning_color.g, warning_color.b, (0.08 + 0.08 * pulse) * alpha)
	)
	canvas.draw_rect(banner_rect, Color(warning_color.r, warning_color.g, warning_color.b, (0.64 + 0.18 * pulse) * alpha), false, 2.0)
	canvas.draw_line(
		banner_rect.position + Vector2(10.0, banner_rect.size.y - 7.0),
		banner_rect.position + Vector2(banner_rect.size.x - 10.0, banner_rect.size.y - 7.0),
		Color(warning_color.r, warning_color.g, warning_color.b, 0.42 * alpha),
		2.0
	)
	_draw_centered_text(
		canvas,
		font,
		banner_rect.position + Vector2(banner_rect.size.x * 0.5, 29.0),
		text,
		text_size,
		Color(1.0, 0.96, 0.82, alpha),
		banner_rect.size.x - 24.0
	)


func draw_quake_waves(canvas: CanvasItem, width: float, shake_offset: Vector2, quake_state: Dictionary) -> void:
	var timer: float = float(quake_state.get("timer", 0.0))
	if timer <= 0.0:
		return
	var duration: float = max(0.001, float(quake_state.get("duration", 1.0)))
	var ratio: float = clamp(timer / duration, 0.0, 1.0)
	var time: float = float(Time.get_ticks_msec()) / 1000.0
	var wave_count: int = int(quake_state.get("wave_count", DEFAULT_QUAKE_WAVE_COUNT))
	var wave_segments: int = int(quake_state.get("wave_segments", DEFAULT_QUAKE_WAVE_SEGMENTS))
	if bool(quake_state.get("visual_only", false)):
		wave_count = int(quake_state.get("visual_only_wave_count", DEFAULT_VISUAL_ONLY_QUAKE_WAVE_COUNT))
		wave_segments = int(quake_state.get("visual_only_wave_segments", DEFAULT_VISUAL_ONLY_QUAKE_WAVE_SEGMENTS))
	wave_segments = max(1, wave_segments)
	for idx in range(max(0, wave_count)):
		var y: float = 120.0 + float(idx) * 92.0 + sin(time * 7.0 + float(idx)) * 5.0
		var alpha: float = (0.12 + 0.08 * sin(time * 5.0 + float(idx))) * ratio
		var points := PackedVector2Array()
		for step in range(0, wave_segments + 1):
			var x: float = width * float(step) / float(wave_segments)
			points.append(Vector2(x, y + sin(time * 8.0 + float(step) * 0.9 + float(idx)) * 5.0) + shake_offset)
		for step in range(points.size() - 1):
			canvas.draw_line(points[step], points[step + 1], Color(0.48, 0.95, 0.36, alpha), 2.0, true)


func _get_skill_warning_color(kind: String) -> Color:
	match kind:
		"quake":
			return Color(0.54, 1.0, 0.42, 1.0)
		"water_charge":
			return Color(0.35, 0.92, 1.0, 1.0)
		"water_fire":
			return Color(0.18, 0.62, 1.0, 1.0)
		"fragment":
			return Color(1.0, 0.42, 0.16, 1.0)
		_:
			return Color(0.82, 1.0, 0.62, 1.0)


func _draw_centered_text(
	canvas: CanvasItem,
	font: Font,
	center: Vector2,
	text: String,
	font_size: int,
	color: Color,
	max_width: float
) -> void:
	var fitted_size: int = max(1, font_size)
	var text_layout: Dictionary = _get_fitted_text_layout(font, text, fitted_size, max_width, 12)
	fitted_size = int(text_layout.get("font_size", fitted_size))
	var text_size: Vector2 = _get_vector2(text_layout.get("size", Vector2.ZERO), Vector2.ZERO)
	var baseline := Vector2(center.x - text_size.x * 0.5, center.y)
	canvas.draw_string(font, baseline + Vector2(1.5, 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, max_width, fitted_size, Color(0.0, 0.0, 0.0, min(0.76, color.a)))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, max_width, fitted_size, color)


func _get_fitted_text_layout(font: Font, text: String, font_size: int, max_width: float, min_size: int) -> Dictionary:
	var cache_key := "%s|%d|%d|%d" % [text, font_size, int(round(max_width)), min_size]
	if _text_layout_cache.has(cache_key):
		return _text_layout_cache[cache_key]
	var fitted_size: int = max(1, font_size)
	var measured_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fitted_size)
	while fitted_size > min_size and measured_size.x > max_width:
		fitted_size -= 1
		measured_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fitted_size)
	var layout := {
		"font_size": fitted_size,
		"size": measured_size,
	}
	_text_layout_cache[cache_key] = layout
	return layout


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
