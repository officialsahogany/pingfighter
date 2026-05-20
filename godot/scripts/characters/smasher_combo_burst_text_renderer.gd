extends RefCounted

const MAX_TEXT_SIZE_CACHE_ENTRIES := 48

var _text_size_cache: Dictionary = {}


func draw(
	canvas: CanvasItem,
	draw_center: Vector2,
	combo: int,
	progress: float,
	scale: float,
	base_color: Color,
	alpha: float
) -> void:
	var font_size: int = int(36.0 * scale + float(combo) * 4.0)
	var combo_text: String = "%dCOMBO!" % combo
	var outline_width: int = 2 if combo < 5 else 3
	_draw_centered_text_with_outline(canvas, draw_center + Vector2(4.0, 5.0), combo_text, font_size, Color(0.0, 0.0, 0.0, 0.72), alpha * 0.72, Color.BLACK, 1)
	if combo >= 3 and progress < 0.36:
		_draw_centered_text_with_outline(canvas, draw_center, combo_text, font_size, Color.WHITE, alpha * 0.88, Color.WHITE, outline_width)
	_draw_centered_text_with_outline(canvas, draw_center, combo_text, font_size, base_color, alpha, Color.BLACK, outline_width + 1)
	if combo >= 5 and progress < 0.34:
		_draw_centered_text_with_outline(canvas, draw_center + Vector2(-1.5, -1.5), combo_text, font_size, Color(1.0, 1.0, 1.0, 0.45), alpha * 0.42, Color(1.0, 1.0, 1.0, 0.12), 1)


func _draw_centered_text_with_outline(
	canvas: CanvasItem,
	center: Vector2,
	text: String,
	font_size: int,
	color: Color,
	alpha: float,
	outline_color: Color = Color.BLACK,
	outline_width: int = 1
) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text_size: Vector2 = _get_cached_text_size(font, text, font_size)
	var baseline: Vector2 = Vector2(center.x - text_size.x * 0.5, center.y + text_size.y * 0.35)
	var clamped_alpha: float = clamp(alpha, 0.0, 1.0)
	if outline_width > 0 and outline_color.a > 0.0:
		canvas.draw_string_outline(
			font,
			baseline,
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size,
			outline_width,
			Color(outline_color.r, outline_color.g, outline_color.b, outline_color.a * clamped_alpha)
		)
	canvas.draw_string(
		font,
		baseline,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		Color(color.r, color.g, color.b, color.a * clamped_alpha)
	)


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
