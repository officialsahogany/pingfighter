extends RefCounted

const DOLL_BODY_COLOR := Color(0.78, 0.28, 0.56)
const DOLL_BODY_DARK := Color(0.33, 0.10, 0.26)
const DOLL_FACE_COLOR := Color(1.0, 0.78, 0.88)
const DOLL_SHEET_COLS := 4
const DOLL_SHEET_ROWS := 4
const DOLL_SHEET_FRAME_COUNT := 16
const DOLL_SHEET_EMERGE_LAST_FRAME := 3
const DOLL_SHEET_ACTIVE_FIRST_FRAME := 0
const DOLL_SHEET_ACTIVE_LAST_FRAME := 15
const DOLL_SHEET_RETRACT_FIRST_FRAME := 12
const DOLL_SHEET_RETRACT_LAST_FRAME := 15
const DOLL_DANCE_FPS := 8.0
const DOLL_SPRITE_DRAW_SIZE := 78.0

const MARIONETTE_CONTROL_BAR_Y_OFFSET := -70.0
const MARIONETTE_CONTROL_BAR_WIDTH := 86.0
const MARIONETTE_CONTROL_BAR_HEIGHT := 7.0
const MARIONETTE_CONTROL_BAR_COLOR := Color(0.40, 0.25, 0.14, 0.82)
const MARIONETTE_CONTROL_BAR_EDGE := Color(0.78, 0.58, 0.33, 0.72)
const MARIONETTE_STRING_COLOR := Color(0.88, 0.84, 0.76, 0.58)
const MARIONETTE_STRING_SHADOW := Color(0.20, 0.12, 0.18, 0.28)
const MARIONETTE_STRING_WIDTH := 1.15
const MARIONETTE_HAND_OFFSET := Vector2(22.0, -1.0)
const MARIONETTE_HEAD_OFFSET := Vector2(0.0, -30.0)
const MARIONETTE_BODY_OFFSET := Vector2(0.0, 10.0)

const BEAM_DRAW_START_WIDTH := 8.0
const BEAM_NEAR_HAZE_LENGTH_RATIO := 0.45
const BEAM_NEAR_HAZE_START_WIDTH := 18.0
const BEAM_NEAR_HAZE_END_WIDTH := 3.0
const BEAM_MID_GLOW_END_SCALE := 0.34
const BEAM_INNER_GLOW_END_SCALE := 0.16
const BEAM_SHIMMER_MOTE_COUNT := 2


func draw_marionette_rigging(canvas: CanvasItem, dolls: Array[Dictionary], shake_offset: Vector2) -> void:
	for doll in dolls:
		if not bool(doll.get("alive", false)):
			continue
		var progress := clampf(float(doll.get("emerge_progress", 1.0)), 0.0, 1.0)
		if progress <= 0.03:
			continue
		var base_position: Vector2 = doll.get("pos", Vector2.ZERO)
		var wobble_phase := float(doll.get("wobble", 0.0))
		var wobble := sin(wobble_phase) * 3.0
		var position := base_position + Vector2(0.0, wobble) + shake_offset
		_draw_marionette_strings(canvas, doll, position, wobble_phase, progress)
		_draw_marionette_control_bar(canvas, doll, position, wobble_phase, progress)


func draw_beams(
	canvas: CanvasItem,
	dolls: Array[Dictionary],
	shake_offset: Vector2,
	active_skill_level: int,
	beam_length: float,
	beam_base_angle: float,
	beam_outer_end_half_width: float,
	doll_half: Vector2
) -> void:
	var level_progress := _get_beam_level_progress(active_skill_level)
	for doll in dolls:
		if not bool(doll.get("alive", false)):
			continue
		var origin := _get_doll_beam_origin(doll, doll_half) + shake_offset
		var angle := float(doll.get("beam_angle", beam_base_angle))
		var direction := Vector2(cos(angle), sin(angle))
		var perpendicular := Vector2(-direction.y, direction.x)
		var end_position := origin + direction * beam_length
		var pulse := _compute_beam_pulse(doll)
		var core_intensity := _compute_beam_core_intensity(doll, level_progress)
		var core_color := _compute_beam_core_color(doll, level_progress)
		canvas.draw_colored_polygon(
			_make_beam_quad(origin, end_position, perpendicular, BEAM_DRAW_START_WIDTH, beam_outer_end_half_width),
			Color(1.0, 0.40, 0.66, 0.12)
		)
		var near_end_position := origin + direction * (beam_length * BEAM_NEAR_HAZE_LENGTH_RATIO)
		canvas.draw_colored_polygon(
			_make_beam_quad(origin, near_end_position, perpendicular, BEAM_NEAR_HAZE_START_WIDTH, BEAM_NEAR_HAZE_END_WIDTH),
			Color(1.0, 0.50, 0.74, 0.10)
		)
		canvas.draw_colored_polygon(
			_make_beam_quad(origin, end_position, perpendicular, 5.0, beam_outer_end_half_width * BEAM_MID_GLOW_END_SCALE),
			Color(core_color.r, core_color.g, core_color.b, 0.16 + 0.10 * core_intensity)
		)
		canvas.draw_colored_polygon(
			_make_beam_quad(origin, end_position, perpendicular, 3.0, beam_outer_end_half_width * BEAM_INNER_GLOW_END_SCALE),
			Color(core_color.r, core_color.g, core_color.b, 0.24 + 0.18 * core_intensity)
		)
		canvas.draw_colored_polygon(
			_make_beam_quad(origin, end_position, perpendicular, 2.5, _get_beam_core_end_half_width(level_progress)),
			Color(1.0, 0.92, 0.97, lerpf(0.45, 0.92, core_intensity))
		)
		canvas.draw_line(
			origin,
			end_position,
			Color(1.0, 1.0, 1.0, lerpf(0.50, 1.0, core_intensity)),
			lerpf(3.0, 1.6, level_progress),
			true
		)
		_draw_beam_origin_flare(canvas, origin, pulse)
		_draw_beam_shimmer(canvas, origin, direction, doll, beam_length)
		if bool(doll.get("beam_on_boss", false)):
			var boss_point: Vector2 = doll.get("beam_boss_point", Vector2.ZERO)
			_draw_beam_boss_flash(canvas, boss_point + shake_offset, pulse)


func draw_dolls(
	canvas: CanvasItem,
	dolls: Array[Dictionary],
	shake_offset: Vector2,
	doll_sheet_texture: Texture2D,
	phase: int,
	phase_timer: float,
	phase_emerge: int,
	phase_active: int,
	phase_retract: int,
	emerge_seconds: float,
	retract_seconds: float,
	doll_half: Vector2
) -> void:
	for doll in dolls:
		if not bool(doll.get("alive", false)):
			continue
		var progress := clampf(float(doll.get("emerge_progress", 1.0)), 0.0, 1.0)
		if progress <= 0.03:
			continue
		var base_position: Vector2 = doll.get("pos", Vector2.ZERO)
		var wobble := sin(float(doll.get("wobble", 0.0))) * 3.0
		var position := base_position + Vector2(0.0, wobble) + shake_offset
		var scale := lerpf(0.45, 1.0, progress)
		if doll_sheet_texture != null:
			_draw_doll_sprite(
				canvas,
				doll,
				position,
				scale,
				doll_sheet_texture,
				phase,
				phase_timer,
				phase_emerge,
				phase_active,
				phase_retract,
				emerge_seconds,
				retract_seconds,
				doll_half
			)
		else:
			_draw_doll_procedural(canvas, position, scale, doll_half)


func draw_destroy_particles(
	canvas: CanvasItem,
	destroy_particles: Array[Dictionary],
	shake_offset: Vector2,
	destroy_particle_life: float
) -> void:
	for particle in destroy_particles:
		var max_life := maxf(0.01, float(particle.get("max_life", destroy_particle_life)))
		var ratio := clampf(float(particle.get("life", 0.0)) / max_life, 0.0, 1.0)
		if ratio <= 0.01:
			continue
		var position: Vector2 = particle.get("pos", Vector2.ZERO) + shake_offset
		var size := float(particle.get("size", 2.0)) * (0.7 + 0.3 * ratio)
		canvas.draw_circle(position, size, Color(1.0, 0.42, 0.72, 0.70 * ratio))


func draw_hit_flash(canvas: CanvasItem, position: Vector2, hit_flash_timer: float, hit_flash_seconds: float) -> void:
	var ratio := clampf(hit_flash_timer / hit_flash_seconds, 0.0, 1.0)
	canvas.draw_circle(position, lerpf(28.0, 8.0, ratio), Color(1.0, 0.62, 0.84, 0.18 * ratio))
	canvas.draw_circle(position, lerpf(12.0, 3.0, ratio), Color(1.0, 0.90, 0.98, 0.45 * ratio))


func get_doll_sheet_frame(
	_doll: Dictionary,
	phase: int,
	phase_timer: float,
	phase_emerge: int,
	phase_active: int,
	phase_retract: int,
	emerge_seconds: float,
	retract_seconds: float
) -> int:
	match phase:
		phase_emerge:
			var ratio := clampf(phase_timer / emerge_seconds, 0.0, 1.0)
			return clampi(int(floor(ratio * float(DOLL_SHEET_EMERGE_LAST_FRAME + 1))), 0, DOLL_SHEET_EMERGE_LAST_FRAME)
		phase_active:
			var active_span := DOLL_SHEET_ACTIVE_LAST_FRAME - DOLL_SHEET_ACTIVE_FIRST_FRAME + 1
			return DOLL_SHEET_ACTIVE_FIRST_FRAME + (int(floor(phase_timer * DOLL_DANCE_FPS)) % active_span)
		phase_retract:
			var ratio := clampf(phase_timer / retract_seconds, 0.0, 1.0)
			var retract_span := DOLL_SHEET_RETRACT_LAST_FRAME - DOLL_SHEET_RETRACT_FIRST_FRAME + 1
			return clampi(
				DOLL_SHEET_RETRACT_FIRST_FRAME + int(floor(ratio * float(retract_span))),
				DOLL_SHEET_RETRACT_FIRST_FRAME,
				DOLL_SHEET_RETRACT_LAST_FRAME
			)
	return 0


func get_beam_draw_debug(doll: Dictionary, active_skill_level: int, outer_end_half_width: float) -> Dictionary:
	var level_progress := _get_beam_level_progress(active_skill_level)
	var pulse := _compute_beam_pulse(doll)
	var core_intensity := _compute_beam_core_intensity(doll, level_progress)
	return {
		"outer_start_half_width": BEAM_DRAW_START_WIDTH,
		"outer_end_half_width": outer_end_half_width,
		"near_haze_start_half_width": BEAM_NEAR_HAZE_START_WIDTH,
		"near_haze_end_half_width": BEAM_NEAR_HAZE_END_WIDTH,
		"mid_glow_end_half_width": outer_end_half_width * BEAM_MID_GLOW_END_SCALE,
		"inner_glow_end_half_width": outer_end_half_width * BEAM_INNER_GLOW_END_SCALE,
		"core_end_half_width": _get_beam_core_end_half_width(level_progress),
		"needle_width": lerpf(3.0, 1.6, level_progress),
		"core_intensity": core_intensity,
		"core_alpha": lerpf(0.45, 0.92, core_intensity),
		"needle_alpha": lerpf(0.50, 1.0, core_intensity),
		"origin_flare_count": 3,
		"origin_core_radius": lerpf(5.0, 7.0, pulse),
		"shimmer_count": BEAM_SHIMMER_MOTE_COUNT,
		"polygon_layer_count": 5,
		"hit_flash_active": bool(doll.get("beam_on_boss", false)),
		"hit_flash_point": doll.get("beam_boss_point", Vector2.ZERO),
	}


func _draw_marionette_control_bar(
	canvas: CanvasItem,
	doll: Dictionary,
	position: Vector2,
	wobble_phase: float,
	alpha: float
) -> void:
	var bar_points := _get_marionette_bar_points(doll, position, wobble_phase)
	var left := bar_points[0]
	var right := bar_points[2]
	var shadow_offset := Vector2(1.2, 1.4)
	canvas.draw_line(
		left + shadow_offset,
		right + shadow_offset,
		_with_scaled_alpha(MARIONETTE_STRING_SHADOW, alpha),
		MARIONETTE_CONTROL_BAR_HEIGHT + 2.0,
		true
	)
	canvas.draw_line(
		left,
		right,
		_with_scaled_alpha(MARIONETTE_CONTROL_BAR_COLOR, alpha),
		MARIONETTE_CONTROL_BAR_HEIGHT,
		true
	)
	canvas.draw_line(
		left + Vector2(0.0, -MARIONETTE_CONTROL_BAR_HEIGHT * 0.35),
		right + Vector2(0.0, -MARIONETTE_CONTROL_BAR_HEIGHT * 0.35),
		_with_scaled_alpha(MARIONETTE_CONTROL_BAR_EDGE, alpha),
		1.0,
		true
	)


func _draw_marionette_strings(
	canvas: CanvasItem,
	doll: Dictionary,
	position: Vector2,
	wobble_phase: float,
	alpha: float
) -> void:
	var side := float(doll.get("side", 1))
	var sway := sin(wobble_phase * 0.65 + side * 0.9) * 3.6
	var bar_points := _get_marionette_bar_points(doll, position, wobble_phase)
	var left := bar_points[0]
	var center := bar_points[1]
	var right := bar_points[2]
	_draw_marionette_string(canvas, left, position + Vector2(-MARIONETTE_HAND_OFFSET.x, MARIONETTE_HAND_OFFSET.y), -sway, alpha)
	_draw_marionette_string(canvas, center + Vector2(-7.0, 0.0), position + MARIONETTE_HEAD_OFFSET, sway * 0.35, alpha)
	_draw_marionette_string(canvas, right, position + MARIONETTE_HAND_OFFSET, sway, alpha)
	_draw_marionette_string(canvas, center + Vector2(14.0, 0.0), position + MARIONETTE_BODY_OFFSET, sway * 0.55, alpha)


func _draw_marionette_string(canvas: CanvasItem, from_position: Vector2, to_position: Vector2, sway: float, alpha: float) -> void:
	var midpoint := (from_position + to_position) * 0.5 + Vector2(sway, 0.0)
	var shadow_offset := Vector2(0.8, 1.0)
	var shadow_color := _with_scaled_alpha(MARIONETTE_STRING_SHADOW, alpha)
	var string_color := _with_scaled_alpha(MARIONETTE_STRING_COLOR, alpha)
	canvas.draw_line(from_position + shadow_offset, midpoint + shadow_offset, shadow_color, MARIONETTE_STRING_WIDTH + 0.8, true)
	canvas.draw_line(midpoint + shadow_offset, to_position + shadow_offset, shadow_color, MARIONETTE_STRING_WIDTH + 0.8, true)
	canvas.draw_line(from_position, midpoint, string_color, MARIONETTE_STRING_WIDTH, true)
	canvas.draw_line(midpoint, to_position, string_color, MARIONETTE_STRING_WIDTH, true)


func _get_marionette_bar_points(doll: Dictionary, position: Vector2, wobble_phase: float) -> PackedVector2Array:
	var side := float(doll.get("side", 1))
	var center := position + Vector2(0.0, MARIONETTE_CONTROL_BAR_Y_OFFSET)
	var tilt := sin(wobble_phase * 0.45 + side) * 0.10
	var half_width := MARIONETTE_CONTROL_BAR_WIDTH * 0.5
	var left := center + Vector2(-half_width, -half_width * tilt)
	var right := center + Vector2(half_width, half_width * tilt)
	return PackedVector2Array([left, center, right])


func _with_scaled_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * clampf(alpha, 0.0, 1.0))


func _make_beam_quad(
	origin: Vector2,
	end_position: Vector2,
	perpendicular: Vector2,
	start_half_width: float,
	end_half_width: float
) -> PackedVector2Array:
	return PackedVector2Array([
		origin + perpendicular * start_half_width,
		origin - perpendicular * start_half_width,
		end_position - perpendicular * end_half_width,
		end_position + perpendicular * end_half_width,
	])


func _draw_beam_origin_flare(canvas: CanvasItem, origin: Vector2, pulse: float) -> void:
	canvas.draw_circle(origin, 18.0, Color(1.0, 0.45, 0.72, 0.10))
	canvas.draw_circle(origin, 11.0, Color(1.0, 0.62, 0.84, 0.22))
	canvas.draw_circle(origin, lerpf(5.0, 7.0, pulse), Color(1.0, 1.0, 1.0, 0.85))


func _draw_beam_shimmer(
	canvas: CanvasItem,
	origin: Vector2,
	direction: Vector2,
	doll: Dictionary,
	beam_length: float
) -> void:
	var wobble := float(doll.get("wobble", 0.0))
	for mote_index in range(BEAM_SHIMMER_MOTE_COUNT):
		var progress := fposmod(wobble * 0.12 + float(mote_index) * 0.5, 1.0)
		var alpha := sin(progress * PI) * 0.70
		if alpha <= 0.01:
			continue
		var position := origin + direction * (progress * beam_length)
		canvas.draw_circle(position, lerpf(2.5, 1.0, progress), Color(1.0, 1.0, 1.0, alpha))


func _draw_beam_boss_flash(canvas: CanvasItem, hit_point: Vector2, pulse: float) -> void:
	canvas.draw_circle(hit_point, lerpf(20.0, 26.0, pulse), Color(1.0, 0.55, 0.80, 0.16))
	canvas.draw_circle(hit_point, lerpf(8.0, 11.0, pulse), Color(1.0, 1.0, 1.0, 0.40))


func _draw_doll_sprite(
	canvas: CanvasItem,
	doll: Dictionary,
	position: Vector2,
	scale: float,
	doll_sheet_texture: Texture2D,
	phase: int,
	phase_timer: float,
	phase_emerge: int,
	phase_active: int,
	phase_retract: int,
	emerge_seconds: float,
	retract_seconds: float,
	doll_half: Vector2
) -> void:
	var frame := get_doll_sheet_frame(
		doll,
		phase,
		phase_timer,
		phase_emerge,
		phase_active,
		phase_retract,
		emerge_seconds,
		retract_seconds
	)
	var texture_size := doll_sheet_texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		_draw_doll_procedural(canvas, position, scale, doll_half)
		return
	var cell_width := texture_size.x / float(DOLL_SHEET_COLS)
	var cell_height := texture_size.y / float(DOLL_SHEET_ROWS)
	var safe_frame := clampi(frame, 0, DOLL_SHEET_FRAME_COUNT - 1)
	var column := safe_frame % DOLL_SHEET_COLS
	var row := int(floor(float(safe_frame) / float(DOLL_SHEET_COLS)))
	var source := Rect2(
		Vector2(float(column) * cell_width, float(row) * cell_height),
		Vector2(cell_width, cell_height)
	)
	var draw_size := DOLL_SPRITE_DRAW_SIZE * maxf(0.05, scale)
	var destination := Rect2(position - Vector2(draw_size, draw_size) * 0.5, Vector2(draw_size, draw_size))
	canvas.draw_texture_rect_region(doll_sheet_texture, destination, source, Color.WHITE, false, true)


func _draw_doll_procedural(canvas: CanvasItem, position: Vector2, scale: float, doll_half: Vector2) -> void:
	var half := doll_half * scale
	canvas.draw_circle(position + Vector2(0.0, -half.y * 0.48), half.x * 0.78, Color(0.24, 0.04, 0.18, 0.22))
	canvas.draw_circle(position + Vector2(0.0, half.y * 0.06), half.x * 0.70, DOLL_BODY_DARK)
	canvas.draw_circle(position + Vector2(0.0, -half.y * 0.56), half.x * 0.56, DOLL_FACE_COLOR)
	canvas.draw_line(
		position + Vector2(-half.x * 0.52, -half.y * 0.05),
		position + Vector2(half.x * 0.52, -half.y * 0.05),
		DOLL_BODY_COLOR,
		maxf(1.0, 4.0 * scale),
		true
	)
	canvas.draw_circle(position + Vector2(-half.x * 0.22, -half.y * 0.62), maxf(1.0, 2.0 * scale), DOLL_BODY_DARK)
	canvas.draw_circle(position + Vector2(half.x * 0.22, -half.y * 0.62), maxf(1.0, 2.0 * scale), DOLL_BODY_DARK)


func _get_doll_beam_origin(doll: Dictionary, doll_half: Vector2) -> Vector2:
	var position: Vector2 = doll.get("pos", Vector2.ZERO)
	return position + Vector2(0.0, -doll_half.y * 0.70)


func _get_beam_level_progress(active_skill_level: int) -> float:
	return clampf((float(active_skill_level) - 1.0) / 4.0, 0.0, 1.0)


func _compute_beam_pulse(doll: Dictionary) -> float:
	return 0.5 + 0.5 * sin(float(doll.get("wobble", 0.0)) * 1.7)


func _compute_beam_core_intensity(doll: Dictionary, level_progress: float) -> float:
	var homing_bonus := 0.22 if bool(doll.get("beam_homing_focus_active", false)) else 0.0
	var boss_bonus := 0.18 if bool(doll.get("beam_on_boss", false)) else 0.0
	var pulse := _compute_beam_pulse(doll)
	return clampf(0.55 + 0.30 * level_progress + homing_bonus + boss_bonus + 0.08 * pulse, 0.0, 1.0)


func _compute_beam_core_color(doll: Dictionary, level_progress: float) -> Color:
	var homing_progress := 0.20 if bool(doll.get("beam_homing_focus_active", false)) else 0.0
	var color_progress := clampf(0.35 * level_progress + homing_progress, 0.0, 1.0)
	return Color(1.0, 0.62, 0.84).lerp(Color.WHITE, color_progress)


func _get_beam_core_end_half_width(level_progress: float) -> float:
	return lerpf(11.0, 5.5, clampf(level_progress, 0.0, 1.0))
