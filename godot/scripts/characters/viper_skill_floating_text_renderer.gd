extends RefCounted

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const DIVE_HIT_TEXT := "천뢰진각"
const MISS_TEXT := "MISS!"


func draw_dive_hit_text(
	canvas: CanvasItem,
	timer: float,
	pos: Vector2,
	height_ratio: float,
	shake_offset: Vector2,
	total_frames: float,
	float_y: float
) -> void:
	if timer <= 0.0:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var timer_ratio: float = clamp(timer / max(1.0, total_frames), 0.0, 1.0)
	var progress: float = 1.0 - timer_ratio
	var alpha: float = clamp(progress / 0.14, 0.0, 1.0) * clamp(timer_ratio / 0.32, 0.0, 1.0)
	if alpha <= 0.02:
		return
	var font_size: int = int(round(24.0 + height_ratio * 5.0 + sin(progress * PI) * 3.0))
	var text_width: float = 260.0
	var center: Vector2 = pos + shake_offset + Vector2(0.0, -26.0 - progress * float_y)
	center.x = clamp(center.x, 96.0, 664.0)
	center.y = clamp(center.y, 84.0, 704.0)
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.026)
	ImpactFlareTextureCache.draw_glow(canvas, center + Vector2(0.0, -12.0), 70.0 + pulse * 12.0, Color(0.25, 0.92, 1.0), alpha * 0.24)
	canvas.draw_line(
		center + Vector2(-68.0, 7.0),
		center + Vector2(68.0, 7.0),
		Color(0.25, 0.95, 1.0, alpha * 0.42),
		2.0,
		true
	)
	var origin: Vector2 = Vector2(center.x - text_width * 0.5, center.y)
	var label := LanguageSettings.translate_text(DIVE_HIT_TEXT)
	canvas.draw_string(font, origin + Vector2(3.0, 3.0), label, HORIZONTAL_ALIGNMENT_CENTER, text_width, font_size, Color(0.02, 0.03, 0.06, alpha * 0.82))
	canvas.draw_string(font, origin + Vector2(-1.0, 0.0), label, HORIZONTAL_ALIGNMENT_CENTER, text_width, font_size, Color(0.20, 0.96, 1.0, alpha * 0.50))
	canvas.draw_string(font, origin, label, HORIZONTAL_ALIGNMENT_CENTER, text_width, font_size, Color(1.0, 0.86, 0.48, alpha))


func draw_nerve_strike_miss_text(
	canvas: CanvasItem,
	timer: float,
	pos: Vector2,
	shake_offset: Vector2,
	total_frames: float,
	float_y: float
) -> void:
	if timer <= 0.0:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var progress: float = 1.0 - clamp(timer / max(1.0, total_frames), 0.0, 1.0)
	var alpha: float = max(0.0, 1.0 - progress)
	var draw_pos: Vector2 = pos + shake_offset + Vector2(0.0, -progress * float_y)
	var font_size: int = int(round(24.0 + sin(progress * PI) * 3.0))
	canvas.draw_string(font, draw_pos + Vector2(-44.0, 2.0), MISS_TEXT, HORIZONTAL_ALIGNMENT_CENTER, 88.0, font_size, Color(0.04, 0.02, 0.08, 0.78 * alpha))
	canvas.draw_string(font, draw_pos + Vector2(-46.0, 0.0), MISS_TEXT, HORIZONTAL_ALIGNMENT_CENTER, 88.0, font_size, Color(0.86, 0.36, 1.0, 0.95 * alpha))


func draw_core_flip_miss_text(
	canvas: CanvasItem,
	timer: float,
	pos: Vector2,
	shake_offset: Vector2,
	total_frames: float,
	float_y: float
) -> void:
	if timer <= 0.0:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var timer_ratio: float = clamp(timer / max(1.0, total_frames), 0.0, 1.0)
	var progress: float = 1.0 - timer_ratio
	var alpha: float = clamp(progress / 0.12, 0.0, 1.0) * clamp(timer_ratio / 0.28, 0.0, 1.0)
	if alpha <= 0.02:
		return
	var center: Vector2 = pos + shake_offset + Vector2(0.0, -progress * float_y)
	center.x = clamp(center.x, 88.0, 672.0)
	center.y = clamp(center.y, 78.0, 704.0)
	var text_width: float = 160.0
	var font_size: int = int(round(25.0 + sin(progress * PI) * 3.0))
	var origin: Vector2 = Vector2(center.x - text_width * 0.5, center.y)
	ImpactFlareTextureCache.draw_glow(canvas, center + Vector2(0.0, -11.0), 54.0, Color(1.0, 0.18, 0.58), alpha * 0.18)
	canvas.draw_string(font, origin + Vector2(3.0, 3.0), MISS_TEXT, HORIZONTAL_ALIGNMENT_CENTER, text_width, font_size, Color(0.02, 0.02, 0.04, alpha * 0.78))
	canvas.draw_string(font, origin, MISS_TEXT, HORIZONTAL_ALIGNMENT_CENTER, text_width, font_size, Color(1.0, 0.64, 0.92, alpha))
