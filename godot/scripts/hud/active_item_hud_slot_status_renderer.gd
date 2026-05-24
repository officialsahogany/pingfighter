extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const ROUNDED_RECT_SAMPLES := 1
const MAX_TEXT_SIZE_CACHE_ENTRIES := 16

var _text_size_cache: Dictionary = {}
var _frame_points_cache_key: String = ""
var _frame_points_cache: Array[Vector2] = []
var _frame_segment_lengths_cache: Array[float] = []
var _frame_perimeter_cache: float = 0.0


func draw_status_overlays(canvas: Node2D, slot_rect: Rect2, scale_factor: float, slot_status: Dictionary) -> float:
	var remaining_ratio: float = float(slot_status.get("cooldown_remaining_ratio", 0.0))
	if remaining_ratio > 0.0:
		canvas.draw_rect(slot_rect, Color(0.0, 0.0, 0.0, 80.0 / 255.0))

	var flash_pulse: float = float(slot_status.get("cooldown_flash_pulse", 0.0))
	if flash_pulse > 0.0:
		var flash_alpha: float = floor(flash_pulse * 255.0 / 16.0) * 16.0 / 255.0
		canvas.draw_rect(slot_rect, Color(1.0, 230.0 / 255.0, 100.0 / 255.0, flash_alpha))
		canvas.draw_rect(slot_rect.grow(2.0), Color(1.0, 230.0 / 255.0, 100.0 / 255.0, flash_pulse * 200.0 / 255.0), false, 3.0)

	var remaining_seconds: int = int(slot_status.get("throw_lock_remaining_seconds", 0))
	if remaining_seconds > 0:
		canvas.draw_rect(slot_rect, Color(0.0, 0.0, 0.0, 150.0 / 255.0))
		_draw_text_centered(
			canvas,
			slot_rect.get_center(),
			str(remaining_seconds),
			max(14, int(20.0 * scale_factor)),
			Color(1.0, 100.0 / 255.0, 100.0 / 255.0),
			1.0
		)
	var alchemy_ratio: float = clamp(float(slot_status.get("alchemy_notice_ratio", 0.0)), 0.0, 1.0)
	if alchemy_ratio > 0.0:
		_draw_alchemy_notice(canvas, slot_rect, scale_factor, alchemy_ratio)
	return remaining_ratio


func draw_group_cooldown_frame(canvas: Node2D, frame_rect: Rect2, remaining_ratio: float, scale_factor: float) -> void:
	if canvas == null:
		return
	if frame_rect.size.x <= 0.0 or frame_rect.size.y <= 0.0:
		return
	_draw_cooldown_status_frame(canvas, frame_rect, remaining_ratio, scale_factor)


func _draw_cooldown_status_frame(canvas: Node2D, rect: Rect2, remaining_ratio: float, scale_factor: float) -> void:
	var clamped_ratio: float = clamp(remaining_ratio, 0.0, 1.0)
	if clamped_ratio <= 0.0:
		return

	var line_width: float = max(2.0, round(min(rect.size.x, rect.size.y) * 0.04))
	var glow_width: float = line_width + 2.0
	var inset: float = max(2.0, floor(glow_width * 0.5) + 1.0)
	var frame_rect: Rect2 = rect.grow(-inset)
	if frame_rect.size.x <= 2.0 or frame_rect.size.y <= 2.0:
		return

	var radius: float = max(3.0, round(5.0 * max(1.0, scale_factor)))
	var points: Array[Vector2] = _rounded_rect_progress_points(frame_rect, radius)
	_draw_polyline_progress(canvas, points, _frame_segment_lengths_cache, _frame_perimeter_cache, 1.0, Color(3.0 / 255.0, 6.0 / 255.0, 10.0 / 255.0, 180.0 / 255.0), line_width + 0.75)
	_draw_polyline_progress(canvas, points, _frame_segment_lengths_cache, _frame_perimeter_cache, clamped_ratio, Color(70.0 / 255.0, 210.0 / 255.0, 1.0, 70.0 / 255.0), glow_width)
	_draw_polyline_progress(canvas, points, _frame_segment_lengths_cache, _frame_perimeter_cache, clamped_ratio, Color(120.0 / 255.0, 236.0 / 255.0, 1.0, 245.0 / 255.0), line_width)


func _rounded_rect_progress_points(rect: Rect2, radius: float) -> Array[Vector2]:
	var cache_key: String = "%s|%.3f" % [rect, radius]
	if cache_key == _frame_points_cache_key:
		return _frame_points_cache
	var clamped_radius: float = clamp(radius, 0.0, min(rect.size.x, rect.size.y) * 0.5)
	var samples := ROUNDED_RECT_SAMPLES
	var center_x: float = rect.get_center().x
	var points: Array[Vector2] = [Vector2(center_x, rect.position.y)]
	points.append(Vector2(rect.end.x - clamped_radius, rect.position.y))
	_append_arc_points(points, Vector2(rect.end.x - clamped_radius, rect.position.y + clamped_radius), -90.0, 0.0, clamped_radius, samples)
	points.append(Vector2(rect.end.x, rect.end.y - clamped_radius))
	_append_arc_points(points, Vector2(rect.end.x - clamped_radius, rect.end.y - clamped_radius), 0.0, 90.0, clamped_radius, samples)
	points.append(Vector2(rect.position.x + clamped_radius, rect.end.y))
	_append_arc_points(points, Vector2(rect.position.x + clamped_radius, rect.end.y - clamped_radius), 90.0, 180.0, clamped_radius, samples)
	points.append(Vector2(rect.position.x, rect.position.y + clamped_radius))
	_append_arc_points(points, Vector2(rect.position.x + clamped_radius, rect.position.y + clamped_radius), 180.0, 270.0, clamped_radius, samples)
	points.append(Vector2(center_x, rect.position.y))
	_frame_points_cache_key = cache_key
	_frame_points_cache = points
	_rebuild_frame_segment_cache(points)
	return points


func _append_arc_points(points: Array[Vector2], center: Vector2, start_degrees: float, end_degrees: float, radius: float, samples: int) -> void:
	for step in range(1, samples + 1):
		var angle: float = deg_to_rad(start_degrees + (end_degrees - start_degrees) * float(step) / float(samples))
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)


func _rebuild_frame_segment_cache(points: Array[Vector2]) -> void:
	_frame_segment_lengths_cache.clear()
	_frame_perimeter_cache = 0.0
	for i in range(points.size() - 1):
		var segment_length: float = points[i].distance_to(points[i + 1])
		_frame_segment_lengths_cache.append(segment_length)
		_frame_perimeter_cache += segment_length


func _draw_polyline_progress(canvas: Node2D, points: Array[Vector2], segment_lengths: Array[float], perimeter: float, ratio: float, color: Color, line_width: float) -> void:
	if points.size() < 2:
		return
	if segment_lengths.size() != points.size() - 1 or perimeter <= 0.0:
		return
	var remaining: float = perimeter * clamp(ratio, 0.0, 1.0)
	if remaining <= 0.0:
		return
	var cap_radius: float = max(1.0, line_width * 0.5)
	var start: Vector2 = points[0]
	var end: Vector2 = start
	for i in range(segment_lengths.size()):
		if remaining <= 0.0:
			break
		var segment_length: float = segment_lengths[i]
		if segment_length <= 0.0:
			continue
		var segment_start: Vector2 = points[i]
		var segment_end: Vector2 = points[i + 1]
		var draw_length: float = min(remaining, segment_length)
		end = segment_start.lerp(segment_end, draw_length / segment_length)
		canvas.draw_line(segment_start, end, color, line_width)
		remaining -= draw_length
	canvas.draw_circle(start, cap_radius, color)
	canvas.draw_circle(end, cap_radius, color)


func _draw_text_centered(canvas: Node2D, center: Vector2, text: String, font_size: int, color: Color, alpha: float) -> void:
	text = LanguageSettings.translate_text(text)
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text_size: Vector2 = _get_cached_text_size(font, text, font_size)
	var pos: Vector2 = center - text_size * 0.5 + Vector2(0.0, text_size.y * 0.35)
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(color.r, color.g, color.b, color.a * alpha))


func _draw_alchemy_notice(canvas: Node2D, slot_rect: Rect2, scale_factor: float, ratio: float) -> void:
	var alpha: float = clamp(ratio * 1.4, 0.0, 1.0)
	var pulse: float = 0.55 + 0.45 * sin(float(Time.get_ticks_msec()) * 0.018)
	var glow_color := Color(168.0 / 255.0, 70.0 / 255.0, 1.0, 0.20 * alpha)
	canvas.draw_rect(slot_rect, glow_color)
	canvas.draw_rect(slot_rect.grow(2.0 + 2.0 * pulse * scale_factor), Color(202.0 / 255.0, 120.0 / 255.0, 1.0, 0.48 * alpha), false, max(1.0, 2.0 * scale_factor))

	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text := LanguageSettings.translate_text("연금술!")
	var font_size: int = max(10, int(round(13.0 * scale_factor)))
	var text_size: Vector2 = _get_cached_text_size(font, text, font_size)
	var center: Vector2 = slot_rect.get_center() + Vector2(0.0, slot_rect.size.y * 0.30)
	var pos: Vector2 = center - text_size * 0.5 + Vector2(0.0, text_size.y * 0.35)
	canvas.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, max(1, int(round(2.0 * scale_factor))), Color(35.0 / 255.0, 0.0, 60.0 / 255.0, 0.92 * alpha))
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(240.0 / 255.0, 210.0 / 255.0, 1.0, alpha))


func _get_cached_text_size(font: Font, text: String, font_size: int) -> Vector2:
	var cache_key: String = "%s|%d" % [text, font_size]
	var cached: Variant = _text_size_cache.get(cache_key, null)
	if cached is Vector2:
		return cached
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	if _text_size_cache.size() >= MAX_TEXT_SIZE_CACHE_ENTRIES:
		_text_size_cache.clear()
	_text_size_cache[cache_key] = text_size
	return text_size
