extends RefCounted

const GHOST_MAX_ALPHA := 0.706
const GHOST_BODY_RX := 22.0
const GHOST_BODY_RY := 20.0
const GHOST_BODY_COLOR := Color(0.314, 0.706, 0.627)
const GHOST_EYE_COLOR := Color(0.549, 1.0, 0.902)
const GHOST_EYE_HILITE := Color(0.784, 1.0, 0.961)
const GHOST_BULGE_COLOR := Color(0.353, 0.765, 0.686)
const GHOST_MOUTH_COLOR := Color(0.157, 0.314, 0.275)
const GHOST_EYE_GLOW := Color(0.627, 1.0, 0.922)
const GHOST_SHADOW_COLOR := Color(0.039, 0.078, 0.071)
const GHOST_FLASH_COLOR := Color(0.235, 0.471, 0.392)


func draw_ghost_summon(
	canvas: CanvasItem,
	shake_offset: Vector2,
	particles: Array[Dictionary],
	teleport_particles: Array[Dictionary],
	launch_flash_timer: float,
	launch_origin: Vector2,
	launch_flash_duration: float,
	dying_ghosts: Array[Dictionary],
	death_duration: float,
	ghosts: Array[Dictionary],
	emerge_duration: float,
	teleport_disappear_duration: float,
	teleport_appear_duration: float
) -> void:
	if canvas == null:
		return
	_draw_particles(canvas, particles, shake_offset, 1.0)
	_draw_particles(canvas, teleport_particles, shake_offset, 1.0)
	if launch_flash_timer > 0.0:
		_draw_launch_flash(canvas, launch_origin + shake_offset, launch_flash_timer, launch_flash_duration)
	for dying_index in range(dying_ghosts.size()):
		_draw_dying_ghost(canvas, dying_ghosts[dying_index], shake_offset, death_duration, dying_index)
	for ghost_value in ghosts:
		var ghost := ghost_value as Dictionary
		if bool(ghost.get("teleporting", false)):
			_draw_teleporting_ghost(
				canvas,
				ghost,
				shake_offset,
				emerge_duration,
				teleport_disappear_duration,
				teleport_appear_duration
			)
		elif bool(ghost.get("eating", false)):
			_draw_eating_state(canvas, ghost, shake_offset, emerge_duration)
		else:
			_draw_roaming_state(canvas, ghost, shake_offset, emerge_duration)


func get_dying_spark_projection_for_tests(dying: Dictionary, death_duration: float, spark_index: int) -> Dictionary:
	var projection := _get_dying_spark_projection(dying, death_duration, spark_index)
	return {
		"offset": Vector2(projection.x, projection.y),
		"alpha_scale": projection.z,
		"radius": projection.w,
	}


func _draw_roaming_state(canvas: CanvasItem, ghost: Dictionary, shake_offset: Vector2, emerge_duration: float) -> void:
	var pos: Vector2 = _get_dict_vector2(ghost, "pos", Vector2.ZERO) + shake_offset
	var spawn_time := float(ghost.get("spawn_time", 0.0))
	var ghost_id := float(ghost.get("id", 0))
	var phase := float(ghost.get("phase", 0.0))
	var alpha := GHOST_MAX_ALPHA * clampf(spawn_time / maxf(0.001, emerge_duration), 0.0, 1.0)
	if alpha <= 0.01:
		return
	var hover_main := 14.0 * sin(spawn_time * 2.2 + ghost_id * PI)
	var hover := hover_main + 5.0 * sin(spawn_time * 3.8 + ghost_id * 2.1)
	_draw_ground_shadow(canvas, pos, 1.0, alpha, hover_main)
	_draw_fallback_ghost(canvas, pos + Vector2(0.0, hover), 1.0, alpha, phase)


func _draw_eating_state(canvas: CanvasItem, ghost: Dictionary, shake_offset: Vector2, emerge_duration: float) -> void:
	var pos: Vector2 = _get_dict_vector2(ghost, "pos", Vector2.ZERO) + shake_offset
	var spawn_time := float(ghost.get("spawn_time", 0.0))
	var phase := float(ghost.get("phase", 0.0))
	var eat_scale := float(ghost.get("eat_scale", 1.0))
	var bulge_phase := float(ghost.get("eat_bulge_phase", 0.0))
	var eat_timer := float(ghost.get("eat_timer", 0.0))
	var alpha := GHOST_MAX_ALPHA * clampf(spawn_time / maxf(0.001, emerge_duration), 0.0, 1.0)
	if alpha <= 0.01:
		return
	var scale_x := eat_scale * (1.0 + 0.06 * sin(bulge_phase))
	var scale_y := eat_scale * (1.0 + 0.06 * sin(bulge_phase + 1.5))
	var shake := Vector2(2.0 * sin(bulge_phase * 3.7), 1.5 * cos(bulge_phase * 2.9))
	_draw_ground_shadow(canvas, pos, eat_scale, alpha, 0.0)
	_draw_ghost_glyph(canvas, pos + shake, scale_x, scale_y, alpha, phase, true, eat_timer)


func _draw_teleporting_ghost(
	canvas: CanvasItem,
	ghost: Dictionary,
	shake_offset: Vector2,
	emerge_duration: float,
	teleport_disappear_duration: float,
	teleport_appear_duration: float
) -> void:
	var phase_name := str(ghost.get("teleport_phase", ""))
	var timer := float(ghost.get("teleport_timer", 0.0))
	var phase := float(ghost.get("phase", 0.0))
	var eat_scale := float(ghost.get("eat_scale", 1.0))
	if phase_name == "disappear":
		var progress := clampf(timer / maxf(0.001, teleport_disappear_duration), 0.0, 1.0)
		var alpha := GHOST_MAX_ALPHA * (1.0 - progress)
		if alpha <= 0.04:
			return
		var shrink := eat_scale * (1.0 - progress * 0.8)
		var swirl := Vector2(8.0 * sin(timer * 25.0) * (1.0 - progress), 8.0 * cos(timer * 25.0) * (1.0 - progress))
		var pre_position := _get_dict_vector2(ghost, "pre_teleport_pos", _get_dict_vector2(ghost, "pos", Vector2.ZERO))
		_draw_fallback_ghost(canvas, pre_position + swirl + shake_offset, shrink, alpha, phase)
	elif phase_name == "appear":
		var progress := clampf(timer / maxf(0.001, teleport_appear_duration), 0.0, 1.0)
		var eased_progress: float
		if progress < 0.6:
			eased_progress = sqrt(progress / 0.6)
		else:
			eased_progress = 1.0 + 0.15 * sin((progress - 0.6) / 0.4 * PI)
		var alpha := GHOST_MAX_ALPHA * minf(1.0, progress * 1.5)
		var appear_scale := 0.2 + 0.8 * eased_progress
		var position: Vector2 = _get_dict_vector2(ghost, "pos", Vector2.ZERO) + shake_offset
		_draw_fallback_ghost(canvas, position, appear_scale, alpha, phase)
	else:
		_draw_roaming_state(canvas, ghost, shake_offset, emerge_duration)


func _draw_dying_ghost(
	canvas: CanvasItem,
	dying: Dictionary,
	shake_offset: Vector2,
	death_duration: float,
	dying_index: int
) -> void:
	var progress := clampf(float(dying.get("death_timer", 0.0)) / maxf(0.001, death_duration), 0.0, 1.0)
	var alpha := GHOST_MAX_ALPHA * (1.0 - progress)
	if alpha <= 0.04:
		return
	var pos: Vector2 = _get_dict_vector2(dying, "pos", Vector2.ZERO) + shake_offset
	pos.y -= 40.0 * progress
	var phase := float(dying.get("phase", 0.0))
	var count := int(8.0 * progress)
	for spark_index in range(count):
		var projection := _get_dying_spark_projection(dying, death_duration, spark_index + dying_index * 17)
		var spark := Vector2(pos.x + projection.x, pos.y - 30.0 * progress + projection.y)
		var spark_alpha := alpha * 0.5 * projection.z
		if spark_alpha > 0.04:
			canvas.draw_circle(spark, projection.w, Color(0.35, 0.82, 0.71, spark_alpha))
	_draw_fallback_ghost(canvas, pos, 1.0, alpha, phase)


func _get_dying_spark_projection(dying: Dictionary, death_duration: float, spark_index: int) -> Vector4:
	var pos := _get_dict_vector2(dying, "pos", Vector2.ZERO)
	var phase := float(dying.get("phase", 0.0))
	var progress := clampf(float(dying.get("death_timer", 0.0)) / maxf(0.001, death_duration), 0.0, 1.0)
	var seed_value := pos.x * 0.017 + pos.y * 0.031 + phase * 1.73 + progress * 9.11 + float(spark_index) * 2.47
	return Vector4(
		lerpf(-30.0, 30.0, _seeded_unit(seed_value, 1.0)),
		lerpf(-15.0, 15.0, _seeded_unit(seed_value, 2.0)),
		lerpf(0.3, 1.0, _seeded_unit(seed_value, 3.0)),
		lerpf(2.0, 5.0, _seeded_unit(seed_value, 4.0))
	)


func _seeded_unit(seed_value: float, salt: float) -> float:
	var value := sin(seed_value * 12.9898 + salt * 78.233) * 43758.5453
	return value - floor(value)


func _draw_launch_flash(
	canvas: CanvasItem,
	origin: Vector2,
	launch_flash_timer: float,
	launch_flash_duration: float
) -> void:
	var progress := clampf(launch_flash_timer / maxf(0.001, launch_flash_duration), 0.0, 1.0)
	var radius := 36.0 + (1.0 - progress) * 110.0
	var disc := GHOST_FLASH_COLOR
	disc.a = 0.34 * progress
	_fill_ellipse(canvas, origin, radius, radius, disc, 28)
	canvas.draw_arc(origin, radius, 0.0, TAU, 36, Color(0.55, 1.0, 0.86, 0.7 * progress), 2.5, true)


func _draw_fallback_ghost(canvas: CanvasItem, center: Vector2, scale_value: float, alpha: float, phase: float) -> void:
	if alpha <= 0.01 or scale_value <= 0.05:
		return
	_draw_ghost_glyph(canvas, center, scale_value, scale_value, alpha, phase, false, 0.0)


func _draw_ghost_glyph(
	canvas: CanvasItem,
	center: Vector2,
	scale_x: float,
	scale_y: float,
	alpha: float,
	phase: float,
	eating: bool,
	eat_timer: float
) -> void:
	var body_color := GHOST_BODY_COLOR
	body_color.a = alpha
	var body_center := center + Vector2(0.0, -6.0 * scale_y)
	_fill_ellipse(canvas, body_center, GHOST_BODY_RX * scale_x, GHOST_BODY_RY * scale_y, body_color, 28)
	if eating:
		var bulge_offset := Vector2(8.0 * sin(eat_timer * 6.0), 5.0 * cos(eat_timer * 4.5))
		var bulge_color := GHOST_BULGE_COLOR
		bulge_color.a = minf(1.0, alpha * 1.1)
		canvas.draw_circle(body_center + bulge_offset, 8.0 * minf(scale_x, scale_y), bulge_color)
	var body_bottom := body_center.y + GHOST_BODY_RY * scale_y
	var wave_offsets := [-16.5, -5.5, 5.5, 16.5]
	var wave_amplitude := 4.0 if eating else 2.5
	var wave_speed := (8.0 + eat_timer * 4.0) if eating else 1.5
	for i in range(wave_offsets.size()):
		var wave_x := float(wave_offsets[i]) * scale_x
		var wave_radius_y := (8.0 + wave_amplitude * sin(phase * wave_speed + float(i) * 0.9)) * scale_y
		_fill_ellipse(canvas, Vector2(center.x + wave_x, body_bottom + wave_radius_y * 0.5 - 2.0 * scale_y), 6.0 * scale_x, wave_radius_y, body_color, 12)
	var eye_y := body_center.y - 4.0 * scale_y
	var left_eye := Vector2(center.x - 7.0 * scale_x, eye_y)
	var right_eye := Vector2(center.x + 7.0 * scale_x, eye_y)
	var eye_radius := maxf(2.0, 3.2 * minf(scale_x, scale_y))
	var eye_color := GHOST_EYE_COLOR
	eye_color.a = alpha
	if eating:
		canvas.draw_circle(left_eye, eye_radius, eye_color)
		canvas.draw_circle(right_eye, eye_radius, eye_color)
		canvas.draw_circle(left_eye + Vector2(0.0, 2.0 * scale_y), eye_radius, body_color)
		canvas.draw_circle(right_eye + Vector2(0.0, 2.0 * scale_y), eye_radius, body_color)
		var glow := GHOST_EYE_GLOW
		glow.a = minf(1.0, alpha * 1.3)
		canvas.draw_circle(left_eye + Vector2(0.0, -1.0), maxf(1.0, eye_radius - 1.0), glow)
		canvas.draw_circle(right_eye + Vector2(0.0, -1.0), maxf(1.0, eye_radius - 1.0), glow)
		var chew := sin(eat_timer * 8.0)
		var mouth_height := maxf(2.0, (4.0 + 3.0 * absf(chew)) * minf(scale_x, scale_y))
		var mouth_width := maxf(3.0, (6.0 + 2.0 * chew) * minf(scale_x, scale_y))
		var mouth_color := GHOST_MOUTH_COLOR
		mouth_color.a = minf(1.0, alpha * 1.2)
		_fill_ellipse(canvas, Vector2(center.x, body_center.y + 8.0 * scale_y), mouth_width * 0.5, mouth_height * 0.5, mouth_color, 14)
	else:
		canvas.draw_circle(left_eye, eye_radius, eye_color)
		canvas.draw_circle(right_eye, eye_radius, eye_color)
		var highlight := GHOST_EYE_HILITE
		highlight.a = alpha
		canvas.draw_circle(left_eye + Vector2(-1.0 * scale_x, -1.0 * scale_y), maxf(1.0, eye_radius * 0.4), highlight)
		canvas.draw_circle(right_eye + Vector2(-1.0 * scale_x, -1.0 * scale_y), maxf(1.0, eye_radius * 0.4), highlight)


func _draw_ground_shadow(canvas: CanvasItem, pos: Vector2, scale_value: float, alpha: float, hover_main: float) -> void:
	var shadow_scale := clampf(1.0 - absf(hover_main) / 25.0, 0.35, 1.0)
	var color := GHOST_SHADOW_COLOR
	color.a = alpha * 0.35 * shadow_scale
	_fill_ellipse(canvas, pos + Vector2(0.0, 24.0 * scale_value), GHOST_BODY_RX * scale_value * shadow_scale, 4.0 * scale_value, color, 16)


func _fill_ellipse(canvas: CanvasItem, center: Vector2, radius_x: float, radius_y: float, color: Color, segments: int) -> void:
	if radius_x <= 0.5 or radius_y <= 0.5 or color.a <= 0.0:
		return
	var points := PackedVector2Array()
	var count := maxi(6, segments)
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	canvas.draw_colored_polygon(points, color)


func _draw_particles(canvas: CanvasItem, particles: Array[Dictionary], shake_offset: Vector2, alpha_scale: float) -> void:
	for particle_value in particles:
		var particle := particle_value as Dictionary
		var age := float(particle.get("age", 0.0))
		var life := maxf(0.001, float(particle.get("life", 0.001)))
		var ratio := clampf(1.0 - age / life, 0.0, 1.0)
		var color_value: Color = particle.get("color", Color(0.55, 1.0, 0.9, 0.5))
		color_value.a *= ratio * alpha_scale
		var pos: Vector2 = _get_dict_vector2(particle, "pos", Vector2.ZERO) + shake_offset
		canvas.draw_circle(pos, maxf(0.5, float(particle.get("size", 2.0))) * (0.6 + ratio * 0.8), color_value)


func _get_dict_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	return value if value is Vector2 else fallback
