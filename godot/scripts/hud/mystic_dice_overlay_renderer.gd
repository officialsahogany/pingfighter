extends RefCounted

const MysticDiceModalFlow := preload("res://scripts/characters/mystic_dice_modal_flow.gd")
const MysticDiceModalLayout := preload("res://scripts/characters/mystic_dice_modal_layout.gd")
const MysticDiceLocalization := preload("res://scripts/characters/mystic_dice_localization.gd")
const MysticDiceRoller := preload("res://scripts/characters/mystic_dice_roller.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const KOREAN_UI_FONT: Font = preload("res://assets/fonts/NanumSquareB.ttf")

const BACKDROP_COLOR := Color(0.012, 0.009, 0.007, 0.86)
const PANEL_COLOR := Color(0.075, 0.043, 0.028, 0.97)
const PANEL_BORDER_COLOR := Color(0.78, 0.56, 0.24, 0.92)
const YUT_BODY_DEEP := Color(0.56, 0.39, 0.20, 1.0)
const YUT_BODY_MID := Color(0.78, 0.62, 0.38, 1.0)
const YUT_BODY_LIT := Color(0.96, 0.84, 0.58, 1.0)
const YUT_CAP_DEEP := Color(0.19, 0.075, 0.035, 1.0)
const YUT_CAP_LIT := Color(0.36, 0.16, 0.075, 1.0)
const YUT_EDGE_COLOR := Color(0.78, 0.56, 0.24, 1.0)
const YUT_FACE_INK := Color(0.055, 0.035, 0.025, 0.96)
const YUT_RIM_SHADOW := Color(0.018, 0.012, 0.009, 0.98)
const YUT_KNOT_RED := Color(0.76, 0.10, 0.075, 1.0)
const YUT_KNOT_DARK := Color(0.24, 0.025, 0.018, 1.0)
const TALISMAN_INK_COLOR := Color(0.56, 0.51, 0.43, 0.22)
const BENEFIT_COLOR := Color(0.14, 0.52, 0.82, 1.0)
const HARM_COLOR := Color(0.88, 0.20, 0.18, 1.0)
const NEUTRAL_COLOR := Color(0.70, 0.65, 0.56, 1.0)
const MAX_ACCUMULATED_RAW := 9
const YUT_STICK_COUNT := 4
# Faces 1..6 remain compatibility inputs from the unchanged gameplay state.
# They project to do/gae/geol/yut/mo plus a second do pose; each bit marks one
# flat, ink-carved back among the four sticks.
const YUT_BACK_MASKS := [1, 3, 7, 15, 0, 8]
const YUT_BASE_ANGLES := [-0.44, -0.15, 0.15, 0.44]
const YUT_BASE_OFFSETS := [
	Vector2(-0.285, 0.04),
	Vector2(-0.095, -0.035),
	Vector2(0.095, -0.035),
	Vector2(0.285, 0.04),
]
const YUT_CAPSULE_ARC_STEPS := 6

var _layout_helper: Object = MysticDiceModalLayout.new()
var _fallback_font: Font = null


func prewarm_assets() -> void:
	# Resolve both locale branches before the first visible modal frame so a
	# language switch cannot move ThemeDB fallback lookup into draw().
	_fallback_font = ThemeDB.fallback_font


func reset() -> void:
	pass


func draw(
	canvas: CanvasItem,
	modal_snapshot: Dictionary,
	dice_snapshot: Dictionary,
	view_size: Vector2
) -> void:
	if canvas == null or modal_snapshot.is_empty() or view_size.x <= 1.0 or view_size.y <= 1.0:
		return
	var phase: String = str(modal_snapshot.get("phase", ""))
	if phase not in [
		MysticDiceModalFlow.PHASE_ROLLING,
		MysticDiceModalFlow.PHASE_RESULT,
		MysticDiceModalFlow.PHASE_COMMITTED,
	]:
		return

	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), BACKDROP_COLOR)
	_draw_talisman_backdrop(canvas, view_size, float(modal_snapshot.get("phase_elapsed", 0.0)))
	var visual: Dictionary = get_visual_state(modal_snapshot, view_size)
	_draw_yut_bundle(
		canvas,
		visual.get("center", view_size * 0.5),
		float(visual.get("size", 96.0)),
		float(visual.get("rotation", 0.0)),
		int(visual.get("face", 5)),
		phase == MysticDiceModalFlow.PHASE_ROLLING,
		float(modal_snapshot.get("phase_elapsed", 0.0))
	)

	if phase == MysticDiceModalFlow.PHASE_ROLLING:
		_draw_rolling_copy(canvas, view_size)
		return
	_draw_result_panel(canvas, modal_snapshot, dice_snapshot, view_size)


static func get_visual_state(modal_snapshot: Dictionary, view_size: Vector2) -> Dictionary:
	var phase: String = str(modal_snapshot.get("phase", MysticDiceModalFlow.PHASE_INACTIVE))
	var elapsed: float = maxf(0.0, float(modal_snapshot.get("phase_elapsed", 0.0)))
	var center := Vector2(view_size.x * 0.5, view_size.y * 0.20)
	var size: float = clampf(minf(view_size.x, view_size.y) * 0.17, 72.0, 138.0)
	var rotation := 0.0
	var face := 5
	if phase == MysticDiceModalFlow.PHASE_ROLLING:
		var duration: float = maxf(0.001, float(modal_snapshot.get("roll_duration", MysticDiceModalFlow.ROLL_DURATION)))
		var progress: float = clampf(elapsed / duration, 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - progress, 3.0)
		var drop_offset: float = lerpf(-view_size.y * 0.24, 0.0, eased)
		var bounce_offset: float = -absf(sin(progress * PI * 3.0)) * (1.0 - progress) * minf(44.0, view_size.y * 0.07)
		center.y += drop_offset + bounce_offset
		rotation = sin(progress * TAU * 2.25) * (1.0 - progress) * 0.68
		face = 1 + posmod(int(floor(elapsed * 12.0)), 6)
	else:
		center.y += sin(elapsed * 2.2) * minf(7.0, view_size.y * 0.012)
		rotation = sin(elapsed * 1.35) * 0.045
		var current_roll: Dictionary = _as_dict(modal_snapshot.get("current_roll", {}))
		var raw: Dictionary = _as_dict(current_roll.get("raw", {}))
		var raw_sum := 0
		for value: Variant in raw.values():
			raw_sum += absi(int(value))
		face = 1 + posmod(raw_sum, 6)
	return {
		"center": center,
		"size": size,
		"rotation": rotation,
		"face": face,
	}


static func build_result_rows(modal_snapshot: Dictionary, dice_snapshot: Dictionary) -> Array:
	var current_roll: Dictionary = _as_dict(modal_snapshot.get("current_roll", {}))
	var raw_roll: Dictionary = _as_dict(current_roll.get("raw", {}))
	var benefits: Dictionary = _as_dict(current_roll.get("benefits", {}))
	var permanent_raw: Dictionary = _as_dict(dice_snapshot.get("permanent_raw", {}))
	var rows: Array = []
	for stat_key: String in MysticDiceRoller.STAT_KEYS:
		var raw_change: int = int(raw_roll.get(stat_key, 0))
		var accumulated_raw: int = clampi(
			int(permanent_raw.get(stat_key, 0)) + raw_change,
			-MAX_ACCUMULATED_RAW,
			MAX_ACCUMULATED_RAW
		)
		rows.append({
			"stat_key": stat_key,
			"raw_change": raw_change,
			"benefit": int(benefits.get(stat_key, _benefit_from_raw(stat_key, raw_change))),
			"accumulated_raw": accumulated_raw,
			"accumulated_benefit": _benefit_from_raw(stat_key, accumulated_raw),
		})
	return rows


static func get_yut_back_mask(face: int) -> int:
	return int(YUT_BACK_MASKS[clampi(face, 1, 6) - 1])


static func get_yut_back_count(face: int) -> int:
	var mask := get_yut_back_mask(face)
	var count := 0
	for stick_index: int in range(YUT_STICK_COUNT):
		if (mask & (1 << stick_index)) != 0:
			count += 1
	return count


static func _benefit_from_raw(stat_key: String, raw_value: int) -> int:
	return -raw_value if stat_key in MysticDiceRoller.LOWER_IS_BETTER_STAT_KEYS else raw_value


func _draw_talisman_backdrop(canvas: CanvasItem, view_size: Vector2, elapsed: float) -> void:
	var center := view_size * 0.5
	var pulse := 0.5 + 0.5 * sin(elapsed * 1.8)
	var radius: float = minf(view_size.x, view_size.y) * (0.34 + pulse * 0.015)
	canvas.draw_circle(center, radius, Color(0.11, 0.065, 0.035, 0.16))
	canvas.draw_arc(center, radius * 0.82, 0.0, TAU, 48, Color(0.65, 0.49, 0.26, 0.18), 2.0)
	canvas.draw_arc(center, radius, 0.0, TAU, 48, TALISMAN_INK_COLOR, 1.5)
	for mark_index: int in range(12):
		var angle: float = float(mark_index) * TAU / 12.0 + elapsed * 0.025
		var radial := Vector2(cos(angle), sin(angle))
		var tangent := Vector2(-radial.y, radial.x)
		var mark_center: Vector2 = center + radial * radius * 0.91
		var half_mark: float = 4.0 + float(mark_index % 3) * 1.5
		canvas.draw_line(
			mark_center - tangent * half_mark,
			mark_center + tangent * half_mark,
			Color(0.61, 0.56, 0.47, 0.16 + pulse * 0.08),
			1.4,
			true
		)


func _draw_yut_bundle(
	canvas: CanvasItem,
	center: Vector2,
	size: float,
	rotation: float,
	face: int,
	is_rolling: bool = false,
	pulse: float = 0.0
) -> void:
	# The old cyan/purple glow becomes a faint talisman-ink seal behind the set.
	canvas.draw_arc(center, size * 0.68, 0.0, TAU, 36, Color(0.58, 0.52, 0.43, 0.18), maxf(1.0, size * 0.012))
	canvas.draw_arc(center, size * 0.55, PI * 0.12, PI * 1.82, 30, Color(0.72, 0.55, 0.27, 0.16), maxf(1.0, size * 0.01))
	var back_mask := get_yut_back_mask(face)
	var stick_length := size * 0.88
	var stick_width := size * 0.16
	for stick_index: int in range(YUT_STICK_COUNT):
		var stick_offset: Vector2 = YUT_BASE_OFFSETS[stick_index] * size
		var stick_rotation: float = rotation + float(YUT_BASE_ANGLES[stick_index])
		if is_rolling:
			var phase_offset := pulse * 6.2 + float(stick_index) * 1.73
			stick_offset += Vector2(sin(phase_offset), cos(phase_offset * 0.83)) * size * 0.045
			# Keep the four silhouettes independently alive without letting adjacent
			# phases collapse into one apparent stick at the mid-throw frame.
			stick_rotation += sin(phase_offset * 1.17) * 0.12
		var stick_center := center + _rotated(stick_offset, rotation * 0.45)
		var shows_back := (back_mask & (1 << stick_index)) != 0
		if is_rolling:
			for trail_index: int in [2, 1]:
				var trail_alpha := 0.045 * float(trail_index)
				_draw_yut_stick(
					canvas,
					stick_center + Vector2(0.0, float(trail_index) * size * 0.025),
					stick_length,
					stick_width,
					stick_rotation - float(trail_index) * 0.12,
					shows_back,
					trail_alpha
				)
		_draw_yut_stick(canvas, stick_center, stick_length, stick_width, stick_rotation, shows_back)
	_draw_yut_knot(canvas, center, size, rotation)


func _draw_yut_knot(canvas: CanvasItem, center: Vector2, size: float, rotation: float) -> void:
	# One small red binding is the shared identity cue between the 32 px icon
	# and the full four-stick modal set. It stays subordinate to the face result.
	var knot_center := center + _rotated(Vector2(0.0, size * 0.018), rotation)
	var wrap_axis := _rotated(Vector2(size * 0.17, 0.0), rotation)
	canvas.draw_line(knot_center - wrap_axis, knot_center + wrap_axis, YUT_KNOT_DARK, maxf(2.0, size * 0.052), true)
	canvas.draw_line(knot_center - wrap_axis, knot_center + wrap_axis, YUT_KNOT_RED, maxf(1.2, size * 0.030), true)
	canvas.draw_circle(knot_center, size * 0.052, YUT_KNOT_DARK)
	canvas.draw_circle(knot_center, size * 0.034, YUT_KNOT_RED)
	for tail_sign: float in [-1.0, 1.0]:
		var tail_end := knot_center + _rotated(Vector2(tail_sign * size * 0.045, size * 0.13), rotation)
		canvas.draw_line(knot_center, tail_end, YUT_KNOT_DARK, maxf(1.6, size * 0.036), true)
		canvas.draw_line(knot_center, tail_end, YUT_KNOT_RED, maxf(1.0, size * 0.020), true)


func _draw_yut_stick(
	canvas: CanvasItem,
	center: Vector2,
	length: float,
	width: float,
	rotation: float,
	shows_back: bool,
	alpha: float = 1.0
) -> void:
	if alpha >= 0.99:
		canvas.draw_colored_polygon(
			_yut_capsule_points(center + Vector2(width * 0.12, width * 0.24), length, width, rotation),
			Color(0.0, 0.0, 0.0, 0.34)
		)
	var outer_points := _yut_capsule_points(center, length, width, rotation)
	canvas.draw_colored_polygon(outer_points, _with_alpha(YUT_CAP_DEEP, alpha))
	var outline := outer_points.duplicate()
	outline.append(outer_points[0])
	canvas.draw_polyline(outline, _with_alpha(YUT_RIM_SHADOW, alpha), maxf(1.4, width * 0.16), true)

	var body_width := width * (0.84 if shows_back else 0.72)
	var body_length := length * 0.68
	var body_points := _yut_capsule_points(center, body_length, body_width, rotation)
	canvas.draw_colored_polygon(body_points, _with_alpha(YUT_BODY_LIT if shows_back else YUT_BODY_DEEP, alpha))
	if not shows_back:
		var rounded_face := _yut_capsule_points(center, body_length * 0.96, body_width * 0.64, rotation)
		canvas.draw_colored_polygon(rounded_face, _with_alpha(YUT_BODY_MID, alpha))
		var highlight_x := -body_width * 0.14
		canvas.draw_line(
			center + _rotated(Vector2(highlight_x, -body_length * 0.26), rotation),
			center + _rotated(Vector2(highlight_x, body_length * 0.22), rotation),
			_with_alpha(YUT_BODY_LIT, alpha * 0.86),
			maxf(1.0, width * 0.075),
			true
		)
	var body_outline := body_points.duplicate()
	body_outline.append(body_points[0])
	canvas.draw_polyline(body_outline, _with_alpha(YUT_EDGE_COLOR, alpha * 0.76), maxf(1.0, width * 0.075), true)

	# The flat back has one transverse ink carving instead of a six-face rune.
	if shows_back:
		canvas.draw_line(
			center + _rotated(Vector2(-body_width * 0.36, -body_length * 0.035), rotation),
			center + _rotated(Vector2(body_width * 0.36, body_length * 0.035), rotation),
			_with_alpha(YUT_FACE_INK, alpha),
			maxf(1.4, width * 0.13),
			true
		)

	# Thin brass seams make the lacquered end caps legible without carrying the
	# silhouette; the cream/black/red family still reads if this detail disappears.
	for end_sign: float in [-1.0, 1.0]:
		var seam_y := end_sign * body_length * 0.50
		canvas.draw_line(
			center + _rotated(Vector2(-width * 0.30, seam_y), rotation),
			center + _rotated(Vector2(width * 0.30, seam_y), rotation),
			_with_alpha(YUT_CAP_LIT.lerp(YUT_EDGE_COLOR, 0.58), alpha),
			maxf(1.0, width * 0.065),
			true
		)


func _yut_capsule_points(center: Vector2, length: float, width: float, rotation: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var half_width := width * 0.5
	var cap_center_y := maxf(0.0, length * 0.5 - half_width)
	for step_index: int in range(YUT_CAPSULE_ARC_STEPS + 1):
		var angle := PI + PI * float(step_index) / float(YUT_CAPSULE_ARC_STEPS)
		var local := Vector2(cos(angle), sin(angle)) * half_width + Vector2(0.0, -cap_center_y)
		points.append(center + _rotated(local, rotation))
	for step_index: int in range(YUT_CAPSULE_ARC_STEPS + 1):
		var angle := PI * float(step_index) / float(YUT_CAPSULE_ARC_STEPS)
		var local := Vector2(cos(angle), sin(angle)) * half_width + Vector2(0.0, cap_center_y)
		points.append(center + _rotated(local, rotation))
	return points


static func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * clampf(alpha, 0.0, 1.0))


func _draw_rolling_copy(canvas: CanvasItem, view_size: Vector2) -> void:
	_draw_text_centered(canvas, MysticDiceLocalization.text("roll_title"), Vector2(view_size.x * 0.5, view_size.y * 0.44), _responsive_font_size(view_size, 30, 20), Color.WHITE)
	_draw_text_centered(canvas, MysticDiceLocalization.text("rolling"), Vector2(view_size.x * 0.5, view_size.y * 0.50), _responsive_font_size(view_size, 17, 12), Color(0.92, 0.79, 0.52))


func _draw_result_panel(canvas: CanvasItem, modal_snapshot: Dictionary, dice_snapshot: Dictionary, view_size: Vector2) -> void:
	var action_rects: Dictionary = _layout_helper.get_action_rects(modal_snapshot, view_size)
	var first_button_y: float = view_size.y * 0.78
	for rect_value: Variant in action_rects.values():
		if rect_value is Rect2:
			first_button_y = minf(first_button_y, (rect_value as Rect2).position.y)
	var panel_width: float = minf(680.0, maxf(292.0, view_size.x - 28.0))
	var panel_top: float = maxf(view_size.y * 0.34, 142.0)
	var panel_bottom: float = maxf(panel_top + 132.0, first_button_y - 24.0)
	panel_bottom = minf(panel_bottom, view_size.y - 72.0)
	var panel_rect := Rect2(Vector2((view_size.x - panel_width) * 0.5, panel_top), Vector2(panel_width, maxf(132.0, panel_bottom - panel_top)))
	canvas.draw_rect(panel_rect, PANEL_COLOR)
	canvas.draw_rect(panel_rect, PANEL_BORDER_COLOR, false, 2.0)
	_draw_text_centered(canvas, MysticDiceLocalization.text("result_title"), Vector2(view_size.x * 0.5, panel_rect.position.y - 18.0), _responsive_font_size(view_size, 24, 16), Color.WHITE)

	var rows: Array = build_result_rows(modal_snapshot, dice_snapshot)
	var header_height: float = clampf(panel_rect.size.y * 0.14, 20.0, 30.0)
	var row_height: float = (panel_rect.size.y - header_height - 8.0) / float(maxi(1, rows.size()))
	var name_x: float = panel_rect.position.x + 14.0
	var roll_x: float = panel_rect.position.x + panel_rect.size.x * 0.70
	var accumulated_x: float = panel_rect.position.x + panel_rect.size.x * 0.88
	var header_size := _responsive_font_size(view_size, 13, 10)
	var header_y: float = panel_rect.position.y + header_height * 0.58
	_draw_text_centered_fitted(canvas, MysticDiceLocalization.text("roll_header"), Vector2(roll_x, header_y), header_size, Color(0.90, 0.78, 0.55), (accumulated_x - roll_x) * 0.94, 8)
	_draw_text_centered_fitted(canvas, MysticDiceLocalization.text("total_header"), Vector2(accumulated_x, header_y), header_size, Color(0.73, 0.67, 0.57), (panel_rect.end.x - accumulated_x) * 2.0 - 6.0, 8)
	for row_index: int in range(rows.size()):
		var row: Dictionary = rows[row_index]
		var center_y: float = panel_rect.position.y + header_height + row_height * (float(row_index) + 0.5)
		if row_index > 0:
			canvas.draw_line(Vector2(panel_rect.position.x + 8.0, center_y - row_height * 0.5), Vector2(panel_rect.end.x - 8.0, center_y - row_height * 0.5), Color(0.45, 0.36, 0.26, 0.30), 1.0)
		var stat_key: String = str(row.get("stat_key", ""))
		var row_font_size := _responsive_font_size(view_size, 14, 9)
		_draw_text_fitted(canvas, MysticDiceLocalization.text(stat_key), Vector2(name_x, center_y + float(row_font_size) * 0.34), row_font_size, Color(0.91, 0.86, 0.75), maxf(80.0, roll_x - name_x - 32.0), 8)
		var raw_change: int = int(row.get("raw_change", 0))
		var accumulated_raw: int = int(row.get("accumulated_raw", 0))
		_draw_text_centered(canvas, _signed_percent(raw_change), Vector2(roll_x, center_y), row_font_size, _value_color(int(row.get("benefit", 0))))
		_draw_text_centered(canvas, _signed_percent(accumulated_raw), Vector2(accumulated_x, center_y), row_font_size, _value_color(int(row.get("accumulated_benefit", 0))))

	var selected_action: int = int(modal_snapshot.get("selected_action", MysticDiceModalFlow.ACTION_CONFIRM))
	if action_rects.has("reroll"):
		_draw_action_button(canvas, action_rects.get("reroll", Rect2()), MysticDiceLocalization.text("reroll"), selected_action == MysticDiceModalFlow.ACTION_REROLL)
	if action_rects.has("confirm"):
		_draw_action_button(canvas, action_rects.get("confirm", Rect2()), MysticDiceLocalization.text("confirm"), selected_action == MysticDiceModalFlow.ACTION_CONFIRM)
	var rerolls_text := MysticDiceLocalization.format("rerolls_left", [int(modal_snapshot.get("rerolls_remaining", 0))])
	_draw_text_centered(canvas, rerolls_text, Vector2(view_size.x * 0.5, minf(view_size.y - 18.0, first_button_y + 66.0)), _responsive_font_size(view_size, 14, 10), Color(0.78, 0.70, 0.58))


func _draw_action_button(canvas: CanvasItem, rect_value: Variant, label: String, selected: bool) -> void:
	if not (rect_value is Rect2):
		return
	var rect: Rect2 = rect_value
	var fill: Color = Color(0.28, 0.13, 0.055, 0.98) if selected else Color(0.095, 0.055, 0.035, 0.94)
	var border: Color = Color(0.86, 0.63, 0.27, 1.0) if selected else Color(0.48, 0.36, 0.22, 0.78)
	canvas.draw_rect(rect, fill)
	canvas.draw_rect(rect, border, false, 2.0 if selected else 1.0)
	if selected:
		canvas.draw_rect(rect.grow(3.0), Color(0.86, 0.61, 0.24, 0.16), false, 2.0)
	_draw_text_centered(canvas, label, rect.get_center(), 16, Color.WHITE if selected else Color(0.78, 0.72, 0.62))


func _draw_text_fitted(canvas: CanvasItem, text: String, baseline: Vector2, font_size: int, color: Color, max_width: float, min_font_size: int) -> void:
	if text.is_empty() or max_width <= 1.0:
		return
	var font: Font = _get_font()
	var fitted_size := font_size
	while fitted_size > min_font_size and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fitted_size).x > max_width:
		fitted_size -= 1
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, max_width, fitted_size, color)


func _draw_text_centered_fitted(canvas: CanvasItem, text: String, center: Vector2, font_size: int, color: Color, max_width: float, min_font_size: int) -> void:
	if text.is_empty() or max_width <= 1.0:
		return
	var font: Font = _get_font()
	var fitted_size := font_size
	while fitted_size > min_font_size and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fitted_size).x > max_width:
		fitted_size -= 1
	_draw_text_centered(canvas, text, center, fitted_size, color)


func _draw_text_centered(canvas: CanvasItem, text: String, center: Vector2, font_size: int, color: Color) -> void:
	if text.is_empty():
		return
	var font: Font = _get_font()
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	canvas.draw_string(font, center - Vector2(text_size.x * 0.5, -text_size.y * 0.34), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _get_font() -> Font:
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_KOREAN:
		return KOREAN_UI_FONT
	if _fallback_font == null:
		_fallback_font = ThemeDB.fallback_font
	return _fallback_font if _fallback_font != null else KOREAN_UI_FONT


func _responsive_font_size(view_size: Vector2, preferred: int, minimum: int) -> int:
	var scale_factor: float = clampf(minf(view_size.x / 760.0, view_size.y / 750.0), 0.62, 1.0)
	return maxi(minimum, int(round(float(preferred) * scale_factor)))


func _value_color(benefit_value: int) -> Color:
	if benefit_value > 0:
		return BENEFIT_COLOR
	if benefit_value < 0:
		return HARM_COLOR
	return NEUTRAL_COLOR


func _signed_percent(value: int) -> String:
	return "%+d%%" % value


static func _rotated(value: Vector2, rotation: float) -> Vector2:
	var cosine := cos(rotation)
	var sine := sin(rotation)
	return Vector2(value.x * cosine - value.y * sine, value.x * sine + value.y * cosine)


static func _as_dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}
