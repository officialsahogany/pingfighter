extends RefCounted

const SmasherComboGaugeFillRenderer := preload("res://scripts/characters/smasher_combo_gauge_fill_renderer.gd")
const SmasherComboGaugeTextRenderer := preload("res://scripts/characters/smasher_combo_gauge_text_renderer.gd")

var fill_renderer: Object = SmasherComboGaugeFillRenderer.new()
var text_renderer: Object = SmasherComboGaugeTextRenderer.new()


func draw(canvas: Node2D, combo_state, anchor_rect: Rect2 = Rect2(), ui_scale: float = 1.0) -> void:
	if canvas == null or combo_state == null:
		return

	var combo_count: int = combo_state.get_combo_count()
	var grace_count: int = combo_state.get_dash_combo_grace_count()
	var gauge_smooth: float = combo_state.get_gauge_smooth()
	var display_combo: int = combo_count if combo_count > 0 else grace_count
	if display_combo <= 0 and gauge_smooth <= 0.01:
		return

	var font: Font = ThemeDB.fallback_font
	if font == null:
		return

	var in_grace: bool = combo_count == 0 and grace_count > 0
	var combo_for_color: int = display_combo
	if combo_for_color < 1:
		combo_for_color = 1
	var combo_color: Color = combo_state.get_combo_color(combo_for_color)
	var glow_color: Color = combo_state.get_combo_glow_color(combo_for_color)
	var safe_scale: float = max(0.45, ui_scale)
	var has_anchor: bool = anchor_rect.size.x > 0.0 and anchor_rect.size.y > 0.0
	var bar_w: float = 72.0 * safe_scale
	var bar_h: float = max(14.0, 20.0 * safe_scale)
	var bar_center_x: float = 4.0 * safe_scale + bar_w * 0.5
	var bar_y: float = 78.0 * safe_scale
	if has_anchor:
		bar_w = max(72.0 * safe_scale, anchor_rect.size.x * 0.82)
		bar_h = max(max(14.0, 20.0 * safe_scale), min(anchor_rect.size.y * 0.42, 22.0 * safe_scale))
		bar_center_x = anchor_rect.position.x + anchor_rect.size.x * 0.5
		bar_y = anchor_rect.position.y + anchor_rect.size.y + max(12.0 * safe_scale, 18.0 * safe_scale)
	var bar_x: float = bar_center_x - bar_w * 0.5
	var progress: float = clamp(gauge_smooth, 0.0, 1.0)
	var fill_alpha_mult: float = 1.0
	var grace_frames: float = max(1.0, combo_state.get_dash_combo_grace_frames())
	if in_grace and grace_frames > 0.0:
		var grace_ratio: float = clamp(combo_state.get_dash_combo_grace_timer() / grace_frames, 0.0, 1.0)
		fill_alpha_mult = 0.35 + 0.65 * grace_ratio

	var track_rect: Rect2 = Rect2(bar_x, bar_y, bar_w, bar_h)
	canvas.draw_rect(Rect2(bar_x - 4.0 * safe_scale, bar_y - 3.0 * safe_scale, bar_w + 8.0 * safe_scale, bar_h + 7.0 * safe_scale), Color(0.0, 0.0, 0.0, 0.45))
	canvas.draw_rect(Rect2(bar_x - 2.0 * safe_scale, bar_y - 2.0 * safe_scale, bar_w + 4.0 * safe_scale, bar_h + 4.0 * safe_scale), Color(18.0 / 255.0, 18.0 / 255.0, 26.0 / 255.0, 0.92))
	canvas.draw_rect(track_rect, Color(45.0 / 255.0, 45.0 / 255.0, 58.0 / 255.0, 1.0))
	canvas.draw_rect(Rect2(bar_x, bar_y, bar_w, max(2.0, bar_h * 0.35)), Color(0.0, 0.0, 0.0, 0.32))

	var fill_w: float = bar_w * progress
	if fill_w > 0.5:
		fill_renderer.draw_fill(canvas, bar_x, bar_y, bar_h, fill_w, progress, combo_color, glow_color, fill_alpha_mult, display_combo)

	var gauge_max_count: float = max(1.0, combo_state.get_gauge_max_count())
	for seg in range(1, int(gauge_max_count)):
		var tx: float = bar_x + bar_w * (float(seg) / gauge_max_count)
		var reached: bool = display_combo > seg + 1
		var tick_color: Color = Color(1.0, 240.0 / 255.0, 200.0 / 255.0, 0.72) if reached else Color(1.0, 1.0, 1.0, 0.25)
		canvas.draw_line(Vector2(tx, bar_y + 2.0), Vector2(tx, bar_y + bar_h - 2.0), tick_color, 1.0)

	var border_alpha: float = 1.0
	if in_grace:
		border_alpha = 0.47 + 0.53 * (0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.020))
	canvas.draw_rect(Rect2(bar_x - 2.0 * safe_scale, bar_y - 2.0 * safe_scale, bar_w + 4.0 * safe_scale, bar_h + 4.0 * safe_scale), Color(glow_color.r, glow_color.g, glow_color.b, border_alpha), false, max(1.0, 2.0 * safe_scale))

	if display_combo >= 3 and fill_w > 0.0:
		fill_renderer.draw_sparkles(canvas, bar_x, bar_y, bar_h, fill_w, progress, fill_alpha_mult)

	if display_combo >= int(gauge_max_count):
		var max_pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.012)
		canvas.draw_rect(Rect2(bar_x - 1.0, bar_y - 1.0, bar_w + 2.0, bar_h + 2.0), Color(1.0, 240.0 / 255.0, 200.0 / 255.0, 0.22 * max_pulse))

	text_renderer.draw_labels(
		canvas,
		bar_center_x,
		bar_y,
		bar_h,
		display_combo,
		in_grace,
		safe_scale,
		combo_color,
		glow_color
	)
