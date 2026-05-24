extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")


func draw_foul_whistle_effect(
	canvas: CanvasItem,
	shake_offset: Vector2,
	state: Object,
	field_size: Vector2,
	total_frames: float,
	referee_frame_count: int,
	referee_frame_frames: float
) -> void:
	if state == null or not bool(state.get("animation_active")):
		return
	var animation_frame: float = float(state.get("animation_frame"))
	var progress: float = clamp(animation_frame / max(1.0, total_frames), 0.0, 1.0)
	var fade_in: float = clamp(animation_frame / 10.0, 0.0, 1.0)
	var fade_out: float = clamp((total_frames - animation_frame) / 28.0, 0.0, 1.0)
	var alpha: float = min(fade_in, fade_out)
	var field_rect := Rect2(Vector2.ZERO, field_size)
	canvas.draw_rect(field_rect, Color(0.0, 0.0, 0.0, 0.36 * alpha))

	var center := Vector2(field_size.x * 0.5, field_size.y * 0.5 - 46.0) + shake_offset
	var pulse_radius: float = 82.0 + 210.0 * progress
	var secondary_radius: float = 42.0 + 124.0 * progress
	canvas.draw_arc(center, pulse_radius, 0.0, TAU, 72, Color(1.0, 240.0 / 255.0, 140.0 / 255.0, max(0.0, 0.80 - progress) * alpha), 7.0, true)
	canvas.draw_arc(center, secondary_radius, 0.0, TAU, 64, Color(1.0, 200.0 / 255.0, 80.0 / 255.0, max(0.0, 0.62 - progress * 0.72) * alpha), 4.0, true)

	var referee_frame: int = int(floor(animation_frame / referee_frame_frames)) % referee_frame_count
	draw_foul_whistle_referee(canvas, center, referee_frame, alpha)
	draw_foul_whistle_text(canvas, center + Vector2(0.0, 136.0), alpha, animation_frame)


func draw_foul_whistle_referee(canvas: CanvasItem, center: Vector2, frame: int, alpha: float) -> void:
	var body_rect := Rect2(center + Vector2(-22.0, -8.0), Vector2(44.0, 82.0))
	canvas.draw_rect(body_rect, Color(0.90, 0.90, 0.88, alpha))
	canvas.draw_rect(Rect2(center + Vector2(-30.0, -12.0), Vector2(60.0, 16.0)), Color(0.08, 0.08, 0.09, alpha))
	canvas.draw_circle(center + Vector2(0.0, -30.0), 28.0, Color(245.0 / 255.0, 213.0 / 255.0, 180.0 / 255.0, alpha))
	canvas.draw_circle(center + Vector2(-8.0, -38.0), 4.0, Color(0.08, 0.08, 0.08, alpha))
	canvas.draw_circle(center + Vector2(8.0, -38.0), 4.0, Color(0.08, 0.08, 0.08, alpha))

	var whistle_offset: float = 4.0 if frame % 2 == 0 else 0.0
	canvas.draw_rect(Rect2(center + Vector2(-8.0, -20.0 + whistle_offset), Vector2(16.0, 10.0)), Color(1.0, 230.0 / 255.0, 120.0 / 255.0, alpha))
	canvas.draw_circle(center + Vector2(8.0, -15.0 + whistle_offset), 4.0, Color(200.0 / 255.0, 160.0 / 255.0, 60.0 / 255.0, alpha))

	var arm_angle: float = deg_to_rad(30.0 + float(frame) * 5.0)
	var arm_end := center + Vector2(-cos(arm_angle) * 62.0, 20.0 - sin(arm_angle) * 62.0)
	var arm_start := center + Vector2(-18.0, 18.0)
	canvas.draw_line(arm_start, arm_end, Color(245.0 / 255.0, 213.0 / 255.0, 180.0 / 255.0, alpha), 10.0, true)
	canvas.draw_circle(arm_end, 10.0, Color(245.0 / 255.0, 213.0 / 255.0, 180.0 / 255.0, alpha))

	var card_center := arm_end + Vector2(0.0, -12.0)
	var card_w := 25.0
	var card_h := 35.0
	canvas.draw_rect(Rect2(card_center - Vector2(card_w, card_h) * 0.5, Vector2(card_w, card_h)), Color(220.0 / 255.0, 60.0 / 255.0, 60.0 / 255.0, alpha))
	canvas.draw_arc(center + Vector2(0.0, -30.0), 46.0, 0.0, TAU, 48, Color(1.0, 240.0 / 255.0, 160.0 / 255.0, 0.36 * alpha), 6.0, true)


func draw_foul_whistle_text(canvas: CanvasItem, center: Vector2, alpha: float, animation_frame: float) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var scale: float = 1.0 + 0.08 * sin(animation_frame * 0.30)
	var font_size: int = int(round(74.0 * scale))
	var text := LanguageSettings.translate_text("무효!")
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var pos := center + Vector2(-text_size.x * 0.5, text_size.y * 0.35)
	canvas.draw_string(font, pos + Vector2(4.0, 5.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(80.0 / 255.0, 40.0 / 255.0, 0.0, 0.82 * alpha))
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(1.0, 240.0 / 255.0, 140.0 / 255.0, alpha))


func draw_revival_effect(
	canvas: CanvasItem,
	shake_offset: Vector2,
	state: Object,
	field_size: Vector2,
	effect_frames: float
) -> void:
	if state == null:
		return
	var effect_timer_frames: float = float(state.get("effect_timer_frames"))
	if effect_timer_frames <= 0.0:
		return
	var elapsed: float = effect_frames - effect_timer_frames
	var progress: float = clamp(elapsed / max(1.0, effect_frames), 0.0, 1.0)
	var fade_in: float = clamp(elapsed / 12.0, 0.0, 1.0)
	var fade_out: float = clamp(effect_timer_frames / 34.0, 0.0, 1.0)
	var alpha: float = min(fade_in, fade_out)
	var field_rect := Rect2(Vector2.ZERO, field_size)
	canvas.draw_rect(field_rect, Color(30.0 / 255.0, 0.0, 42.0 / 255.0, 0.38 * alpha))

	var center := Vector2(field_size.x * 0.5, field_size.y * 0.5 - 36.0) + shake_offset
	var ring_radius: float = 44.0 + 168.0 * progress
	var pulse_radius: float = 38.0 + 10.0 * sin(elapsed * 0.18)
	canvas.draw_arc(center, ring_radius, 0.0, TAU, 72, Color(1.0, 70.0 / 255.0, 220.0 / 255.0, max(0.0, 0.78 - progress * 0.70) * alpha), 6.0, true)
	canvas.draw_arc(center, ring_radius * 0.62, 0.0, TAU, 64, Color(180.0 / 255.0, 100.0 / 255.0, 1.0, max(0.0, 0.60 - progress * 0.62) * alpha), 3.0, true)
	canvas.draw_circle(center, pulse_radius, Color(1.0, 80.0 / 255.0, 220.0 / 255.0, 0.18 * alpha))
	canvas.draw_circle(center, pulse_radius * 0.62, Color(1.0, 220.0 / 255.0, 1.0, 0.22 * alpha))
	draw_revival_text(canvas, center + Vector2(0.0, 86.0), alpha, effect_timer_frames, effect_frames)


func draw_revival_text(canvas: CanvasItem, center: Vector2, alpha: float, effect_timer_frames: float, effect_frames: float) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var scale: float = 1.0 + 0.05 * sin((effect_frames - effect_timer_frames) * 0.28)
	var font_size: int = int(round(32.0 * scale))
	var text := LanguageSettings.translate_text("윤회의 부적 발동!")
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var box_rect := Rect2(center + Vector2(-text_size.x * 0.5 - 20.0, -text_size.y * 0.5 - 12.0), Vector2(text_size.x + 40.0, text_size.y + 24.0))
	canvas.draw_rect(box_rect, Color(16.0 / 255.0, 0.0, 26.0 / 255.0, 0.70 * alpha))
	canvas.draw_rect(box_rect, Color(1.0, 80.0 / 255.0, 220.0 / 255.0, 0.72 * alpha), false, 2.0)
	var pos := center + Vector2(-text_size.x * 0.5, text_size.y * 0.35)
	canvas.draw_string(font, pos + Vector2(3.0, 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(40.0 / 255.0, 0.0, 70.0 / 255.0, 0.9 * alpha))
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(1.0, 225.0 / 255.0, 1.0, alpha))


func draw_sensor_auto_dash_effect(
	canvas: CanvasItem,
	shake_offset: Vector2,
	timer_frames: float,
	effect_center: Vector2,
	last_dash_direction: float,
	effect_frames: float
) -> void:
	if timer_frames <= 0.0:
		return
	var elapsed: float = effect_frames - timer_frames
	var progress: float = clamp(elapsed / max(1.0, effect_frames), 0.0, 1.0)
	var fade: float = clamp(timer_frames / 12.0, 0.0, 1.0)
	var center: Vector2 = effect_center + shake_offset
	var direction: float = last_dash_direction
	if abs(direction) <= 0.01:
		direction = 1.0
	canvas.draw_circle(center, 18.0 + 8.0 * sin(elapsed * 0.42), Color(125.0 / 255.0, 90.0 / 255.0, 1.0, 0.18 * fade))
	for i in range(3):
		var ring_progress: float = clamp(progress + float(i) * 0.20, 0.0, 1.0)
		var alpha: float = max(0.0, 0.58 * (1.0 - ring_progress) * fade)
		if alpha <= 0.01:
			continue
		var radius: float = 26.0 + ring_progress * 92.0
		canvas.draw_arc(center, radius, 0.0, TAU, 64, Color(150.0 / 255.0, 120.0 / 255.0, 1.0, alpha), max(1.0, 3.0 * (1.0 - ring_progress)), true)
	var dash_len: float = 70.0 * (1.0 - progress * 0.35)
	var beam_start := center - Vector2(direction * dash_len * 0.55, 0.0)
	var beam_end := center + Vector2(direction * dash_len, 0.0)
	canvas.draw_line(beam_start, beam_end, Color(110.0 / 255.0, 76.0 / 255.0, 1.0, 0.22 * fade), 10.0, true)
	canvas.draw_line(beam_start, beam_end, Color(220.0 / 255.0, 205.0 / 255.0, 1.0, 0.74 * fade), 3.0, true)
	var arrow_tip := beam_end
	var arrow_back := beam_end - Vector2(direction * 14.0, 0.0)
	canvas.draw_line(arrow_tip, arrow_back + Vector2(0.0, -8.0), Color(220.0 / 255.0, 205.0 / 255.0, 1.0, 0.72 * fade), 2.0, true)
	canvas.draw_line(arrow_tip, arrow_back + Vector2(0.0, 8.0), Color(220.0 / 255.0, 205.0 / 255.0, 1.0, 0.72 * fade), 2.0, true)
