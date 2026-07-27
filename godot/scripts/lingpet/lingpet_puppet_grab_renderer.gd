extends RefCounted

const CHU_FONT: Font = preload("res://assets/fonts/NanumSquareB.ttf")

const PHASE_EXTENDING := 0
const PHASE_PULLING := 1
const PHASE_KISSING := 2
const PHASE_RETURNING := 3
const PHASE_MISSING := 4
const PHASE_RETRY_WAIT := 5

const STRING_COUNT := 5
const STRING_SEGMENTS := 20
const STRING_WAVE_SPEED := 4.0
const STRING_WAVE_AMPLITUDE := 12.0
const STRING_TIP_FOCUS_START := 0.55
const STRING_TIP_FOCUS_POWER := 1.35
const HAND_OFFSET_Y := -6.0

const PULL_TENSION_LINE_COUNT := 3
const PULL_TENSION_LINE_MIN := 20.0
const PULL_TENSION_LINE_MAX := 40.0
const PULL_TENSION_FPS := 60.0

const CHU_TEXT := "CHU~"
const CHU_FONT_SIZE := 22
const CHU_OFFSET := Vector2(48.0, -28.0)
const MISS_TEXT := "MISS"
const MISS_FONT_SIZE := 32
const MISS_FLOAT_UP_SPEED := 28.0
const MISS_OFFSET := Vector2(-32.0, -6.0)

const ROPE_CUT_GAP := 18.0
const CUT_RECOIL_EASE_POWER := 2.4
const CUT_RECOIL_RESIDUAL := 0.26
const CUT_BODY_SEGMENTS := 7
const CUT_BODY_LASH_AMPLITUDE := 15.0
const CUT_BODY_LASH_FREQ := 23.0
const CUT_TEXT := "끊김!"
const CUT_FONT_SIZE := 25
const CUT_OFFSET := Vector2(-36.0, -18.0)

const HEART_LIFE_SECONDS := 0.9
const SPARKLE_LIFE_SECONDS := 0.5

# Stateless procedural renderer for Koyora Puppet Grab. Runtime phase clocks,
# positions, cut payloads, and particles stay in the skill owner. Pull-tension
# jitter is a pure projection of the supplied clock and shot count, so redraws
# at the same runtime state neither consume global RNG nor change pixels.


func draw_strings(
	canvas: CanvasItem,
	shake_offset: Vector2,
	phase: int,
	phase_timer: float,
	anim_time: float,
	cast_pos: Vector2,
	boss_center: Vector2,
	predicted_target: Vector2,
	cut_by_ball: bool,
	cut_point: Vector2,
	cut_fray_hand: Array,
	cut_fray_boss: Array,
	extend_seconds: float,
	miss_seconds: float,
	return_seconds: float
) -> void:
	var unshaken_hand := cast_pos + Vector2(0.0, HAND_OFFSET_Y)
	var hand := unshaken_hand + shake_offset
	var tip := _compute_string_tip(
		hand,
		shake_offset,
		phase,
		phase_timer,
		boss_center,
		predicted_target,
		extend_seconds,
		miss_seconds
	)
	var kissing := phase == PHASE_KISSING or phase == PHASE_RETURNING
	var base_color: Color
	if _is_miss_feedback_phase(phase):
		var miss_fade := _miss_feedback_fade(phase_timer, miss_seconds)
		base_color = Color(0.85, 0.30, 0.40, 0.85 * miss_fade)
	elif kissing:
		base_color = Color(1.0, 0.588, 0.706, 0.9)
	else:
		base_color = Color(0.706, 0.392, 0.588, 0.85)
	var axis := tip - hand
	var length := axis.length()
	if length < 1.0:
		return
	if cut_by_ball and phase == PHASE_RETURNING:
		_draw_cut_strings(
			canvas,
			hand,
			unshaken_hand,
			tip,
			base_color,
			cut_point,
			phase_timer,
			anim_time,
			cut_fray_hand,
			cut_fray_boss,
			return_seconds
		)
		return
	var perp := Vector2(-axis.y, axis.x).normalized()
	var extend_ratio := 1.0
	if phase == PHASE_EXTENDING:
		extend_ratio = clampf(phase_timer / maxf(0.001, extend_seconds), 0.0, 1.0)
	for string_index in range(STRING_COUNT):
		var offset := -20.0 + float(string_index) * 10.0
		var phase_seed := float(string_index) * 1.31 + anim_time * STRING_WAVE_SPEED
		var points := PackedVector2Array()
		for segment_index in range(STRING_SEGMENTS + 1):
			var progress := float(segment_index) / float(STRING_SEGMENTS)
			var along := hand.lerp(tip, progress)
			var taper := 1.0 - progress * 0.5
			var wave := sin(phase_seed + progress * PI * 3.0) * STRING_WAVE_AMPLITUDE * taper * extend_ratio
			var tip_focus := string_tip_focus(progress)
			along += perp * ((offset * (1.0 - progress * 0.6) + wave) * tip_focus)
			points.append(along)
		canvas.draw_polyline(points, Color(base_color.r, base_color.g, base_color.b, base_color.a * 0.85), 2.0, true)


func draw_pull_tension(
	canvas: CanvasItem,
	shake_offset: Vector2,
	cast_pos: Vector2,
	boss_center: Vector2,
	anim_time: float,
	shot_count: int
) -> void:
	var hand := cast_pos + Vector2(0.0, HAND_OFFSET_Y) + shake_offset
	var tip := boss_center + shake_offset
	var center := hand.lerp(tip, 0.5)
	var color := Color(1.0, 0.784, 0.863, 0.4)
	for line_index in range(PULL_TENSION_LINE_COUNT):
		var line := get_pull_tension_line_for_tests(line_index, anim_time, shot_count)
		canvas.draw_line(center, center + line, color, 1.0, true)


func get_pull_tension_line_for_tests(line_index: int, anim_time: float, shot_count: int) -> Vector2:
	var frame_index := int(floor(maxf(0.0, anim_time) * PULL_TENSION_FPS))
	var base_seed := shot_count * 104729 + frame_index * 8191 + line_index * 313
	var angle := _hash_unit(base_seed + 17) * TAU
	var line_length := lerpf(PULL_TENSION_LINE_MIN, PULL_TENSION_LINE_MAX, _hash_unit(base_seed + 97))
	return Vector2(cos(angle), sin(angle)) * line_length


func draw_hand(canvas: CanvasItem, shake_offset: Vector2, cast_pos: Vector2) -> void:
	var hand := cast_pos + Vector2(0.0, HAND_OFFSET_Y) + shake_offset
	canvas.draw_circle(hand, 8.0, Color(0.588, 0.314, 0.471, 0.85))
	canvas.draw_circle(hand, 5.0, Color(0.784, 0.471, 0.627, 0.95))


func draw_chu_text(canvas: CanvasItem, shake_offset: Vector2, kiss_center: Vector2, phase_timer: float) -> void:
	var anchor := kiss_center + CHU_OFFSET + shake_offset
	var fade := clampf(phase_timer / 0.18, 0.0, 1.0)
	var alpha := 0.95 * fade
	canvas.draw_string(
		CHU_FONT,
		anchor + Vector2(2.0, 2.0),
		CHU_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		CHU_FONT_SIZE,
		Color(0.0, 0.0, 0.0, 0.5 * fade),
	)
	canvas.draw_string(
		CHU_FONT,
		anchor,
		CHU_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		CHU_FONT_SIZE,
		Color(1.0, 0.588, 0.784, alpha),
	)


func draw_cut_text(
	canvas: CanvasItem,
	shake_offset: Vector2,
	cut_point: Vector2,
	boss_center: Vector2,
	phase_timer: float,
	return_seconds: float
) -> void:
	var anchor := (cut_point if cut_point != Vector2.ZERO else boss_center) + CUT_OFFSET + shake_offset
	var fade := 1.0 - clampf(phase_timer / maxf(0.001, return_seconds), 0.0, 1.0)
	var alpha := 0.95 * fade
	canvas.draw_string(
		CHU_FONT,
		anchor + Vector2(2.0, 2.0),
		CUT_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		CUT_FONT_SIZE,
		Color(0.0, 0.0, 0.0, 0.58 * fade),
	)
	canvas.draw_string(
		CHU_FONT,
		anchor,
		CUT_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		CUT_FONT_SIZE,
		Color(1.0, 0.82, 0.92, alpha),
	)


func draw_miss_text(
	canvas: CanvasItem,
	shake_offset: Vector2,
	predicted_target: Vector2,
	phase_timer: float,
	miss_seconds: float
) -> void:
	var anchor := predicted_target + MISS_OFFSET + shake_offset
	anchor.y -= MISS_FLOAT_UP_SPEED * phase_timer
	var fade := _miss_feedback_fade(phase_timer, miss_seconds)
	var alpha := 0.95 * fade
	canvas.draw_string(
		CHU_FONT,
		anchor + Vector2(2.0, 2.0),
		MISS_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		MISS_FONT_SIZE,
		Color(0.0, 0.0, 0.0, 0.6 * fade),
	)
	canvas.draw_string(
		CHU_FONT,
		anchor,
		MISS_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		MISS_FONT_SIZE,
		Color(1.0, 0.27, 0.32, alpha),
	)


func draw_sparkles(canvas: CanvasItem, shake_offset: Vector2, sparkles: Array[Dictionary]) -> void:
	for sparkle in sparkles:
		var life_ratio := clampf(float(sparkle.get("life", 0.0)) / SPARKLE_LIFE_SECONDS, 0.0, 1.0)
		var pos: Vector2 = sparkle.get("pos", Vector2.ZERO) + shake_offset
		var size := float(sparkle.get("size", 3.0))
		canvas.draw_circle(pos, size, Color(1.0, 1.0, 0.784, life_ratio))


func draw_hearts(canvas: CanvasItem, shake_offset: Vector2, hearts: Array[Dictionary]) -> void:
	for heart in hearts:
		var life_ratio := clampf(float(heart.get("life", 0.0)) / HEART_LIFE_SECONDS, 0.0, 1.0)
		var pos: Vector2 = heart.get("pos", Vector2.ZERO) + shake_offset
		var size := float(heart.get("size", 6.0))
		var alpha := 0.85 * life_ratio
		_draw_heart(canvas, pos, size, Color(1.0, 0.42, 0.62, alpha))


func recoil_retract(progress: float) -> float:
	return 1.0 - pow(1.0 - clampf(progress, 0.0, 1.0), CUT_RECOIL_EASE_POWER)


func recoil_free_point(anchor: Vector2, break_point: Vector2, progress: float) -> Vector2:
	var retract := recoil_retract(progress)
	return anchor.lerp(break_point, lerpf(1.0, CUT_RECOIL_RESIDUAL, retract))


func string_tip_focus(path_progress: float) -> float:
	var progress := clampf(
		(path_progress - STRING_TIP_FOCUS_START) / maxf(0.001, 1.0 - STRING_TIP_FOCUS_START),
		0.0,
		1.0
	)
	var eased := pow(progress, STRING_TIP_FOCUS_POWER)
	return clampf(1.0 - eased, 0.0, 1.0)


func _compute_string_tip(
	hand: Vector2,
	shake_offset: Vector2,
	phase: int,
	phase_timer: float,
	boss_center: Vector2,
	predicted_target: Vector2,
	extend_seconds: float,
	miss_seconds: float
) -> Vector2:
	match phase:
		PHASE_EXTENDING:
			var progress := clampf(phase_timer / maxf(0.001, extend_seconds), 0.0, 1.0)
			var eased := 1.0 - pow(1.0 - progress, 3.0)
			return hand.lerp(predicted_target + shake_offset, eased)
		PHASE_MISSING, PHASE_RETRY_WAIT:
			var retract_progress := _miss_feedback_fade(phase_timer, miss_seconds)
			return hand.lerp(predicted_target + shake_offset, retract_progress)
		_:
			return boss_center + shake_offset


func _draw_cut_strings(
	canvas: CanvasItem,
	hand: Vector2,
	unshaken_hand: Vector2,
	tip: Vector2,
	base_color: Color,
	cut_point: Vector2,
	phase_timer: float,
	anim_time: float,
	cut_fray_hand: Array,
	cut_fray_boss: Array,
	return_seconds: float
) -> void:
	var axis := tip - hand
	var length := axis.length()
	if length < 1.0:
		return
	var direction := axis / length
	var perpendicular := Vector2(-direction.y, direction.x)
	var break_point := cut_point
	if break_point == Vector2.ZERO:
		break_point = hand.lerp(tip, 0.5)
	else:
		break_point += hand - unshaken_hand
	var local_break := _closest_point_on_segment(break_point, hand, tip)
	var half_gap := ROPE_CUT_GAP * 0.5
	var hand_break := local_break - direction * half_gap
	var boss_break := local_break + direction * half_gap
	var progress := clampf(phase_timer / maxf(0.001, return_seconds), 0.0, 1.0)
	var lash_decay := pow(1.0 - progress, 1.4)
	var fade := 1.0 - progress * 0.6
	for string_index in range(STRING_COUNT):
		var lateral := -20.0 + float(string_index) * 10.0
		var hand_anchor := hand + perpendicular * (lateral * 0.34)
		var boss_anchor := tip + perpendicular * (lateral * 0.34)
		var hand_free := recoil_free_point(hand_anchor, hand_break, progress)
		var boss_free := recoil_free_point(boss_anchor, boss_break, progress)
		var seed_phase := float(string_index) * 1.7
		var hand_bundle: Array = []
		var boss_bundle: Array = []
		if string_index < cut_fray_hand.size() and cut_fray_hand[string_index] is Array:
			hand_bundle = cut_fray_hand[string_index] as Array
		if string_index < cut_fray_boss.size() and cut_fray_boss[string_index] is Array:
			boss_bundle = cut_fray_boss[string_index] as Array
		_draw_snapped_half(canvas, hand_anchor, hand_free, perpendicular, base_color, fade, lash_decay, seed_phase, true, anim_time, hand_bundle)
		_draw_snapped_half(canvas, boss_anchor, boss_free, perpendicular, base_color, fade, lash_decay, seed_phase, false, anim_time, boss_bundle)


func _draw_snapped_half(
	canvas: CanvasItem,
	anchor: Vector2,
	free_end: Vector2,
	perpendicular: Vector2,
	base_color: Color,
	fade: float,
	lash_decay: float,
	seed_phase: float,
	is_hand: bool,
	anim_time: float,
	fray_bundle: Array
) -> void:
	var body_length := anchor.distance_to(free_end)
	var lash_amplitude := minf(CUT_BODY_LASH_AMPLITUDE, body_length * 0.55)
	var lash_sign := 1.0 if is_hand else -1.0
	var points := PackedVector2Array()
	for segment_index in range(CUT_BODY_SEGMENTS + 1):
		var progress := float(segment_index) / float(CUT_BODY_SEGMENTS)
		var base := anchor.lerp(free_end, progress)
		var lash := sin(anim_time * CUT_BODY_LASH_FREQ + seed_phase + progress * PI * 1.3) * lash_amplitude * lash_decay * progress * lash_sign
		points.append(base + perpendicular * lash)
	canvas.draw_polyline(points, Color(base_color.r, base_color.g, base_color.b, base_color.a * 0.82 * fade), 2.0, true)
	if points.size() < 2 or fray_bundle.is_empty():
		return
	var tail := points[points.size() - 1]
	var tail_direction := tail - points[points.size() - 2]
	if tail_direction.length() > 0.001:
		tail_direction = tail_direction.normalized()
	else:
		tail_direction = (free_end - anchor).normalized()
	_draw_fray_bundle(canvas, tail, tail_direction, fray_bundle, base_color, fade, lash_decay, anim_time)


func _draw_fray_bundle(
	canvas: CanvasItem,
	origin: Vector2,
	out_direction: Vector2,
	fibers: Array,
	base_color: Color,
	fade: float,
	lash_decay: float,
	anim_time: float
) -> void:
	var lit := Color(
		minf(1.0, base_color.r * 1.08),
		minf(1.0, base_color.g + 0.18),
		minf(1.0, base_color.b + 0.12),
		base_color.a
	)
	for fiber in fibers:
		var is_long := bool(fiber.get("long", false))
		var splay := float(fiber.get("splay", 0.0))
		var fiber_length := float(fiber.get("len", 14.0))
		var curl := float(fiber.get("curl", 0.0))
		var droop := float(fiber.get("droop", 0.0))
		var wobble_phase := float(fiber.get("wob_phase", 0.0))
		var wobble_frequency := float(fiber.get("wob_freq", 32.0))
		var wobble_amplitude := float(fiber.get("wob_amp", 3.5))
		var thickness := float(fiber.get("thick", 1.3))
		var segment_count := 10 if is_long else 4
		var base_direction := out_direction.rotated(splay)
		var cursor := origin
		var step_length := fiber_length / float(segment_count)
		var lash_wave := 0.6 if is_long else 1.0
		var points := PackedVector2Array([cursor])
		for segment_index in range(segment_count):
			var progress := float(segment_index + 1) / float(segment_count)
			var heading := (base_direction.rotated(curl * progress) + Vector2(0.0, droop * progress)).normalized()
			cursor += heading * step_length
			var perpendicular := Vector2(-heading.y, heading.x)
			var lash := sin(anim_time * wobble_frequency + wobble_phase + progress * PI * lash_wave) * wobble_amplitude * lash_decay * progress
			points.append(cursor + perpendicular * lash)
		var fade_alpha := base_color.a * (0.46 if is_long else 0.62) * fade
		canvas.draw_polyline(points, Color(lit.r, lit.g, lit.b, fade_alpha), thickness, true)


func _draw_heart(canvas: CanvasItem, center: Vector2, size: float, color: Color) -> void:
	var lobe := size * 0.5
	canvas.draw_circle(center + Vector2(-lobe * 0.55, -lobe * 0.25), lobe, color)
	canvas.draw_circle(center + Vector2(lobe * 0.55, -lobe * 0.25), lobe, color)
	var triangle := PackedVector2Array([
		center + Vector2(-size * 0.6, 0.0),
		center + Vector2(size * 0.6, 0.0),
		center + Vector2(0.0, size * 0.9),
	])
	canvas.draw_colored_polygon(triangle, color)


func _is_miss_feedback_phase(phase: int) -> bool:
	return phase == PHASE_MISSING or phase == PHASE_RETRY_WAIT


func _miss_feedback_fade(phase_timer: float, miss_seconds: float) -> float:
	var progress := clampf(minf(phase_timer, miss_seconds) / maxf(0.001, miss_seconds), 0.0, 1.0)
	return 1.0 - progress


func _closest_point_on_segment(point: Vector2, start: Vector2, end: Vector2) -> Vector2:
	var axis := end - start
	var length_squared := axis.length_squared()
	if length_squared <= 0.0001:
		return start
	var progress := clampf((point - start).dot(axis) / length_squared, 0.0, 1.0)
	return start + axis * progress


func _hash_unit(value: int) -> float:
	return fposmod(sin(float(value) * 12.9898 + 78.233) * 43758.5453, 1.0)
