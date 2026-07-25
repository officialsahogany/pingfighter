extends RefCounted

const MysticDiceModalFlow := preload("res://scripts/characters/mystic_dice_modal_flow.gd")
const MysticDiceModalLayout := preload("res://scripts/characters/mystic_dice_modal_layout.gd")
const MysticDiceLocalization := preload("res://scripts/characters/mystic_dice_localization.gd")
const MysticDiceRoller := preload("res://scripts/characters/mystic_dice_roller.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const KOREAN_UI_FONT: Font = preload("res://assets/fonts/NanumSquareB.ttf")
const LINGPET_GLYPH_FONT: Font = preload("res://assets/fonts/LingpetScriptDisplay-Regular.ttf")
# Each die face carries a distinct Lingpet Script (링펫어) rune. The face value is
# purely decorative here — the roll outcome is the 7-stat shift — so real Lingpet
# glyphs fit the theme far better than mundane 1-6 pips.
const FACE_GLYPHS: Array[String] = ["c", "o", "g", "m", "t", "z"]

const BACKDROP_COLOR := Color(0.008, 0.006, 0.04, 0.82)
const PANEL_COLOR := Color(0.035, 0.025, 0.11, 0.97)
const PANEL_BORDER_COLOR := Color(0.27, 0.84, 1.0, 0.88)
const DIE_BODY_DEEP := Color(0.09, 0.03, 0.28, 1.0)
const DIE_BODY_MID := Color(0.20, 0.08, 0.50, 1.0)
const DIE_BODY_LIT := Color(0.40, 0.22, 0.74, 1.0)
const DIE_EDGE_COLOR := Color(0.44, 0.91, 1.0, 1.0)
const DIE_BEVEL_COLOR := Color(0.66, 0.94, 1.0, 0.42)
const DIE_RIM_SHADOW := Color(0.02, 0.01, 0.08, 0.96)
const STARLIGHT_COLOR := Color(0.82, 0.97, 1.0, 1.0)
const BENEFIT_COLOR := Color(0.42, 1.0, 0.62, 1.0)
const HARM_COLOR := Color(1.0, 0.38, 0.44, 1.0)
const NEUTRAL_COLOR := Color(0.68, 0.73, 0.84, 1.0)
const MAX_ACCUMULATED_RAW := 30
const DIE_SUPERELLIPSE_N := 4.0
const DIE_OUTLINE_POINTS := 32

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
	_draw_arcane_backdrop(canvas, view_size, float(modal_snapshot.get("phase_elapsed", 0.0)))
	var visual: Dictionary = get_visual_state(modal_snapshot, view_size)
	_draw_dice(
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


static func _benefit_from_raw(stat_key: String, raw_value: int) -> int:
	return -raw_value if stat_key in MysticDiceRoller.LOWER_IS_BETTER_STAT_KEYS else raw_value


func _draw_arcane_backdrop(canvas: CanvasItem, view_size: Vector2, elapsed: float) -> void:
	var center := view_size * 0.5
	var pulse := 0.5 + 0.5 * sin(elapsed * 1.8)
	var radius: float = minf(view_size.x, view_size.y) * (0.34 + pulse * 0.015)
	canvas.draw_circle(center, radius, Color(0.18, 0.04, 0.42, 0.18))
	canvas.draw_arc(center, radius * 0.82, 0.0, TAU, 48, Color(0.22, 0.82, 1.0, 0.18), 2.0)
	canvas.draw_arc(center, radius, 0.0, TAU, 48, Color(0.62, 0.26, 1.0, 0.13), 1.5)
	for star_index: int in range(8):
		var angle: float = float(star_index) * TAU / 8.0 + elapsed * 0.08
		var star_center: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius * 0.92
		var star_radius: float = 2.0 + float(star_index % 3)
		canvas.draw_circle(star_center, star_radius, Color(0.55, 0.92, 1.0, 0.30 + pulse * 0.22))


func _draw_dice(
	canvas: CanvasItem,
	center: Vector2,
	size: float,
	rotation: float,
	face: int,
	is_rolling: bool = false,
	pulse: float = 0.0
) -> void:
	var half := size * 0.5
	# Ambient arcane glow.
	canvas.draw_circle(center, size * 0.80, Color(0.16, 0.66, 1.0, 0.06))
	canvas.draw_circle(center, size * 0.62, Color(0.52, 0.20, 1.0, 0.10))
	# Spin trail behind the die (deterministic — driven by rotation, no RNG).
	if is_rolling:
		for trail_index: int in [2, 1]:
			var trail_alpha := 0.06 * float(trail_index)
			var trail_color := DIE_BODY_MID
			trail_color.a = trail_alpha
			canvas.draw_colored_polygon(
				_die_body_points(center, half, rotation - float(trail_index) * 0.22, 0.86),
				trail_color
			)
	# Drop shadow for grounded volume.
	canvas.draw_colored_polygon(
		_die_body_points(center + Vector2(size * 0.03, size * 0.075), half, rotation, 0.86),
		Color(0.0, 0.0, 0.0, 0.34)
	)
	# Body with a top-lit vertical gradient (real volume, not a flat sticker).
	var body_points := _die_body_points(center, half, rotation, 0.86)
	canvas.draw_polygon(body_points, _die_gradient_colors(body_points))
	# Outer rim: dark seat + cyan edge light.
	var outline := body_points.duplicate()
	outline.append(body_points[0])
	canvas.draw_polyline(outline, DIE_RIM_SHADOW, maxf(5.0, size * 0.05), true)
	canvas.draw_polyline(outline, DIE_EDGE_COLOR, maxf(2.0, size * 0.022), true)
	# Beveled inner face (cyan, replaces the clashing gold filet).
	var bevel := _die_body_points(center, half, rotation, 0.66)
	bevel.append(bevel[0])
	canvas.draw_polyline(bevel, DIE_BEVEL_COLOR, maxf(1.2, size * 0.012), true)
	# Crisp top-left rim light.
	_draw_die_rim_light(canvas, center, half, rotation, size)
	_draw_face_glyph(canvas, center, size, clampi(face, 1, 6))
	# Twinkling corner sparkle (deterministic from the phase pulse).
	_draw_die_sparkle(canvas, center, half, rotation, pulse)


func _die_body_points(center: Vector2, half: float, rotation: float, radius_scale: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point_index: int in range(DIE_OUTLINE_POINTS):
		var angle: float = float(point_index) * TAU / float(DIE_OUTLINE_POINTS)
		var cosine := cos(angle)
		var sine := sin(angle)
		var denom: float = pow(
			pow(absf(cosine), DIE_SUPERELLIPSE_N) + pow(absf(sine), DIE_SUPERELLIPSE_N),
			1.0 / DIE_SUPERELLIPSE_N
		)
		var local := Vector2(cosine, sine) * (half * radius_scale / maxf(0.0001, denom))
		points.append(center + _rotated(local, rotation))
	return points


func _die_gradient_colors(points: PackedVector2Array) -> PackedColorArray:
	var min_y := points[0].y
	var max_y := points[0].y
	for point: Vector2 in points:
		min_y = minf(min_y, point.y)
		max_y = maxf(max_y, point.y)
	var span := maxf(1.0, max_y - min_y)
	var colors := PackedColorArray()
	for point: Vector2 in points:
		var t := clampf((point.y - min_y) / span, 0.0, 1.0)
		if t < 0.5:
			colors.append(DIE_BODY_LIT.lerp(DIE_BODY_MID, t / 0.5))
		else:
			colors.append(DIE_BODY_MID.lerp(DIE_BODY_DEEP, (t - 0.5) / 0.5))
	return colors


func _draw_die_rim_light(canvas: CanvasItem, center: Vector2, half: float, rotation: float, size: float) -> void:
	var points := PackedVector2Array()
	var steps := 9
	for step_index: int in range(steps + 1):
		var angle := lerpf(PI * 1.06, PI * 1.62, float(step_index) / float(steps))
		var cosine := cos(angle)
		var sine := sin(angle)
		var denom: float = pow(
			pow(absf(cosine), DIE_SUPERELLIPSE_N) + pow(absf(sine), DIE_SUPERELLIPSE_N),
			1.0 / DIE_SUPERELLIPSE_N
		)
		var local := Vector2(cosine, sine) * (half * 0.86 / maxf(0.0001, denom))
		points.append(center + _rotated(local, rotation))
	canvas.draw_polyline(points, Color(0.88, 0.98, 1.0, 0.7), maxf(1.4, size * 0.015), true)


func _draw_die_sparkle(canvas: CanvasItem, center: Vector2, half: float, rotation: float, pulse: float) -> void:
	var twinkle := 0.5 + 0.5 * sin(pulse * 3.4)
	var pos := center + _rotated(Vector2(half * 0.56, -half * 0.56), rotation)
	var ray := half * (0.11 + 0.05 * twinkle)
	var color := Color(0.92, 0.99, 1.0, 0.42 + 0.4 * twinkle)
	var width := maxf(1.0, half * 0.022)
	canvas.draw_line(pos - Vector2(ray, 0.0), pos + Vector2(ray, 0.0), color, width, true)
	canvas.draw_line(pos - Vector2(0.0, ray), pos + Vector2(0.0, ray), color, width, true)
	canvas.draw_circle(pos, ray * 0.26, Color.WHITE)


func _draw_face_glyph(canvas: CanvasItem, center: Vector2, size: float, face: int) -> void:
	# Carve a distinct Lingpet Script rune into the top face. Drawn upright (not
	# rotated with the die) because draw_string cannot rotate without a leaked
	# canvas transform, and the result phase settles near zero rotation anyway.
	var key: String = FACE_GLYPHS[clampi(face, 1, 6) - 1]
	var glyph_size: int = int(maxf(18.0, size * 0.5))
	var glow_size: int = glyph_size + int(maxf(2.0, size * 0.03))
	var glyph_extent: Vector2 = LINGPET_GLYPH_FONT.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1.0, glyph_size)
	var glow_extent: Vector2 = LINGPET_GLYPH_FONT.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1.0, glow_size)
	var base_pos: Vector2 = center - Vector2(glyph_extent.x * 0.5, -glyph_extent.y * 0.34)
	var glow_pos: Vector2 = center - Vector2(glow_extent.x * 0.5, -glow_extent.y * 0.34)
	# Cyan bloom halo (a slightly larger glyph behind reads as a glowing outline).
	canvas.draw_string(LINGPET_GLYPH_FONT, glow_pos, key, HORIZONTAL_ALIGNMENT_LEFT, -1.0, glow_size, Color(0.28, 0.86, 1.0, 0.30))
	# Engraved dark underlay offset downward for a carved-in read.
	canvas.draw_string(LINGPET_GLYPH_FONT, base_pos + Vector2(0.0, size * 0.014), key, HORIZONTAL_ALIGNMENT_LEFT, -1.0, glyph_size, Color(0.02, 0.01, 0.08, 0.55))
	# Starlight rune.
	canvas.draw_string(LINGPET_GLYPH_FONT, base_pos, key, HORIZONTAL_ALIGNMENT_LEFT, -1.0, glyph_size, STARLIGHT_COLOR)


func _draw_rolling_copy(canvas: CanvasItem, view_size: Vector2) -> void:
	_draw_text_centered(canvas, MysticDiceLocalization.text("roll_title"), Vector2(view_size.x * 0.5, view_size.y * 0.44), _responsive_font_size(view_size, 30, 20), Color.WHITE)
	_draw_text_centered(canvas, MysticDiceLocalization.text("rolling"), Vector2(view_size.x * 0.5, view_size.y * 0.50), _responsive_font_size(view_size, 17, 12), Color(0.68, 0.90, 1.0))


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
	_draw_text_centered_fitted(canvas, MysticDiceLocalization.text("roll_header"), Vector2(roll_x, header_y), header_size, Color(0.68, 0.88, 1.0), (accumulated_x - roll_x) * 0.94, 8)
	_draw_text_centered_fitted(canvas, MysticDiceLocalization.text("total_header"), Vector2(accumulated_x, header_y), header_size, Color(0.80, 0.70, 1.0), (panel_rect.end.x - accumulated_x) * 2.0 - 6.0, 8)
	for row_index: int in range(rows.size()):
		var row: Dictionary = rows[row_index]
		var center_y: float = panel_rect.position.y + header_height + row_height * (float(row_index) + 0.5)
		if row_index > 0:
			canvas.draw_line(Vector2(panel_rect.position.x + 8.0, center_y - row_height * 0.5), Vector2(panel_rect.end.x - 8.0, center_y - row_height * 0.5), Color(0.30, 0.34, 0.55, 0.26), 1.0)
		var stat_key: String = str(row.get("stat_key", ""))
		var row_font_size := _responsive_font_size(view_size, 14, 9)
		_draw_text_fitted(canvas, MysticDiceLocalization.text(stat_key), Vector2(name_x, center_y + float(row_font_size) * 0.34), row_font_size, Color(0.86, 0.91, 1.0), maxf(80.0, roll_x - name_x - 32.0), 8)
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
	_draw_text_centered(canvas, rerolls_text, Vector2(view_size.x * 0.5, minf(view_size.y - 18.0, first_button_y + 66.0)), _responsive_font_size(view_size, 14, 10), Color(0.70, 0.80, 0.94))


func _draw_action_button(canvas: CanvasItem, rect_value: Variant, label: String, selected: bool) -> void:
	if not (rect_value is Rect2):
		return
	var rect: Rect2 = rect_value
	var fill: Color = Color(0.20, 0.15, 0.42, 0.98) if selected else Color(0.07, 0.06, 0.16, 0.94)
	var border: Color = Color(0.42, 0.92, 1.0, 1.0) if selected else Color(0.35, 0.38, 0.62, 0.76)
	canvas.draw_rect(rect, fill)
	canvas.draw_rect(rect, border, false, 2.0 if selected else 1.0)
	if selected:
		canvas.draw_rect(rect.grow(3.0), Color(0.40, 0.76, 1.0, 0.16), false, 2.0)
	_draw_text_centered(canvas, label, rect.get_center(), 16, Color.WHITE if selected else Color(0.74, 0.78, 0.88))


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
