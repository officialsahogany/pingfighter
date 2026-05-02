extends RefCounted

const PowerSmashFeedbackEffectRenderer := preload("res://scripts/characters/smasher_power_smash_feedback_effect_renderer.gd")
const SmasherSkillTimingMonitorRenderer := preload("res://scripts/characters/smasher_skill_timing_monitor_renderer.gd")
const DASH_STATUS_COLOR := Color(0.20, 0.80, 1.0)
const HALF_DASH_STATUS_COLOR := Color(0.60, 0.60, 1.0, 0.40)

var power_effect_renderer: Object = PowerSmashFeedbackEffectRenderer.new()
var timing_monitor_renderer: Object = SmasherSkillTimingMonitorRenderer.new()


func draw_power_smash_effects(canvas: Node2D, power_state, shake_offset: Vector2) -> void:
	power_effect_renderer.draw(canvas, power_state, shake_offset)


func draw_banners(canvas: Node2D, width: float, height: float, context: Dictionary) -> void:
	if canvas == null:
		return

	var font: Font = ThemeDB.fallback_font
	if font == null:
		return

	var center_x: float = width * 0.5
	timing_monitor_renderer.draw(canvas, font, context)
	if bool(context.get("dash_active", false)):
		_draw_dash_status(canvas, font, center_x, height, bool(context.get("dash_is_half", false)))

	var drive_timer: float = float(context.get("drive_text_timer_frames", 0.0))
	var drive_duration: float = max(1.0, float(context.get("drive_text_duration_frames", 30.0)))
	if drive_timer > 0.0:
		_draw_drive_banner(canvas, font, center_x, height, drive_timer, drive_duration)

	var power_timer: float = float(context.get("power_smashing_text_timer_frames", 0.0))
	var power_duration: float = max(1.0, float(context.get("power_smash_text_duration_frames", 48.0)))
	if power_timer > 0.0:
		_draw_power_smash_banner(canvas, font, center_x, height, power_timer, power_duration)


func _draw_dash_status(canvas: Node2D, font: Font, center_x: float, height: float, is_half_dash: bool) -> void:
	var text: String = "HALF DASH!" if is_half_dash else "DASH!"
	var color: Color = HALF_DASH_STATUS_COLOR if is_half_dash else DASH_STATUS_COLOR
	canvas.draw_string(font, Vector2(center_x - 30.0, height - 30.0), text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, 16, color)


func _draw_drive_banner(
	canvas: Node2D,
	font: Font,
	center_x: float,
	height: float,
	timer_frames: float,
	duration_frames: float
) -> void:
	var fade_frames: float = 8.0
	var alpha: float = 1.0
	if timer_frames > duration_frames - fade_frames:
		alpha = clamp((duration_frames - timer_frames) / fade_frames, 0.0, 1.0)
	elif timer_frames < fade_frames:
		alpha = clamp(timer_frames / fade_frames, 0.0, 1.0)

	var text: String = "DRIVE!"
	var font_size: int = 28
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var text_pos: Vector2 = Vector2(center_x - text_size.x * 0.5, height * 0.60)
	canvas.draw_string(font, text_pos + Vector2(2.0, 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.1, 0.1, 0.1, 0.65 * alpha))
	canvas.draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(1.0, 1.0, 1.0, alpha))


func _draw_power_smash_banner(
	canvas: Node2D,
	font: Font,
	center_x: float,
	height: float,
	timer_frames: float,
	duration_frames: float
) -> void:
	var fade_frames: float = 10.0
	var alpha: float = 1.0
	if timer_frames > duration_frames - fade_frames:
		alpha = clamp((duration_frames - timer_frames) / fade_frames, 0.0, 1.0)
	elif timer_frames < fade_frames:
		alpha = clamp(timer_frames / fade_frames, 0.0, 1.0)

	var text: String = "POWER SMASHING"
	var font_size: int = 30
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var text_pos: Vector2 = Vector2(center_x - text_size.x * 0.5, height * 0.54)
	var glow_color: Color = Color(1.0, 80.0 / 255.0, 35.0 / 255.0, 0.55 * alpha)
	canvas.draw_string(font, text_pos + Vector2(3.0, 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.08, 0.02, 0.01, 0.78 * alpha))
	canvas.draw_string(font, text_pos + Vector2(-1.0, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, glow_color)
	canvas.draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(1.0, 230.0 / 255.0, 160.0 / 255.0, alpha))
