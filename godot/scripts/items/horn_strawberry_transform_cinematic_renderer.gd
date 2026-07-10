extends RefCounted

const HornStrawberryPaddleRenderer := preload("res://scripts/items/horn_strawberry_paddle_renderer.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const STATE_TRANSFORM_EVENT := "transform_event"
const STATE_DETRANSFORM_EVENT := "detransform_event"
const TRANSFORM_EVENT_SEC := 4.5
const DETRANSFORM_EVENT_SEC := 2.0
const FIELD_SIZE := Vector2(760.0, 750.0)
const RING_SEGMENTS := 56
const SPARK_COUNT := 22

var _strawberry_renderer: Object = HornStrawberryPaddleRenderer.new()


func is_visible(context: Dictionary) -> bool:
	var state_name: String = str(context.get("state", ""))
	return state_name == STATE_TRANSFORM_EVENT or state_name == STATE_DETRANSFORM_EVENT


func build_phase_context(context: Dictionary) -> Dictionary:
	var state_name: String = str(context.get("state", ""))
	if state_name == STATE_TRANSFORM_EVENT:
		return _build_phase("transform", context, TRANSFORM_EVENT_SEC)
	if state_name == STATE_DETRANSFORM_EVENT:
		return _build_phase("detransform", context, DETRANSFORM_EVENT_SEC)
	return {}


func draw(canvas: CanvasItem, shake_offset: Vector2, context: Dictionary, draw_context: Dictionary = {}) -> void:
	if canvas == null:
		return
	var phase: Dictionary = build_phase_context(context)
	if phase.is_empty():
		return
	var progress: float = float(phase.get("progress", 0.0))
	var mode: String = str(phase.get("mode", ""))
	var player_pos: Vector2 = _as_vector2(draw_context.get("player_pos", Vector2(302.5, 700.0)), Vector2(302.5, 700.0))
	var paddle_size: Vector2 = _as_vector2(draw_context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))
	var player_center: Vector2 = player_pos + Vector2(paddle_size.x * 0.5, paddle_size.y * 0.5) + shake_offset
	if mode == "transform":
		_draw_transform(canvas, player_pos, paddle_size, player_center, shake_offset, progress, draw_context)
	else:
		_draw_detransform(canvas, player_center, progress)


func _build_phase(mode: String, context: Dictionary, duration_sec: float) -> Dictionary:
	var remaining: float = clamp(float(context.get("event_timer_sec", duration_sec)), 0.0, duration_sec)
	var elapsed: float = duration_sec - remaining
	return {
		"mode": mode,
		"duration_sec": duration_sec,
		"elapsed_sec": elapsed,
		"remaining_sec": remaining,
		"progress": clamp(elapsed / max(0.001, duration_sec), 0.0, 1.0),
	}


func _draw_transform(
	canvas: CanvasItem,
	player_pos: Vector2,
	paddle_size: Vector2,
	player_center: Vector2,
	shake_offset: Vector2,
	progress: float,
	draw_context: Dictionary
) -> void:
	var pulse: float = sin(progress * PI)
	canvas.draw_rect(Rect2(Vector2.ZERO, FIELD_SIZE), Color(0.10, 0.0, 0.05, 0.08 + 0.18 * pulse), true)
	if progress < 0.35:
		_draw_phase_rise_spin(canvas, player_center, paddle_size, progress / 0.35, draw_context)
	elif progress < 0.60:
		_draw_phase_swirl(canvas, player_center, (progress - 0.35) / 0.25)
	elif progress < 0.75:
		_draw_phase_burst(canvas, player_center, (progress - 0.60) / 0.15)
	else:
		_draw_phase_landing(canvas, player_pos, paddle_size, shake_offset, (progress - 0.75) / 0.25, draw_context)
	_draw_transform_particles(canvas, player_center, progress)


func _draw_phase_rise_spin(canvas: CanvasItem, player_center: Vector2, paddle_size: Vector2, phase_progress: float, draw_context: Dictionary) -> void:
	var p: float = clamp(phase_progress, 0.0, 1.0)
	var rise_ease: float = 1.0 - pow(1.0 - p, 2.0)
	var center := player_center + Vector2(0.0, -80.0 * rise_ease)
	var spin_angle: float = p * TAU * 2.25
	var x_scale: float = cos(spin_angle)
	for i in range(3):
		var stream_x: float = player_center.x + (float(i) - 1.0) * 26.0
		var top := Vector2(stream_x, center.y - 70.0 - p * 42.0)
		var bottom := Vector2(stream_x + sin(p * TAU + float(i)) * 6.0, player_center.y + 38.0)
		canvas.draw_line(bottom, top, Color(1.0, 0.48, 0.62, 0.12 + p * 0.16), 3.0)
	# The REAL character sprite now rises with this phase (actor renderer,
	# Python captured-snapshot parity), so the spinning silhouette drops to a
	# translucent overlay that reads as the original's ballerina-spin ghosting.
	_draw_spinning_paddle_silhouette(canvas, center, paddle_size, x_scale, 0.34 - p * 0.08, draw_context)
	_draw_magic_rings(canvas, center, p, 0.26 + p * 0.24)


func _draw_phase_swirl(canvas: CanvasItem, player_center: Vector2, phase_progress: float) -> void:
	var p: float = clamp(phase_progress, 0.0, 1.0)
	var center := player_center + Vector2(0.0, -80.0)
	canvas.draw_rect(Rect2(Vector2.ZERO, FIELD_SIZE), Color(0.20, 0.0, 0.08, 0.16 + p * 0.16), true)
	for i in range(34):
		var lane: float = float(i) / 34.0
		var angle: float = lane * TAU * 3.0 + p * TAU * 2.4
		var dist: float = lerp(92.0, 18.0, p) + sin(lane * 19.0 + p * TAU) * 10.0
		var pos := center + Vector2(cos(angle) * dist, sin(angle) * dist * 0.58)
		var color := Color(1.0, 0.34, 0.46, 0.20 + p * 0.24)
		if i % 5 == 0:
			_draw_tiny_strawberry(canvas, pos, 4.0 + p * 4.0, color.a + 0.15)
		else:
			canvas.draw_circle(pos, 2.0 + float(i % 3), color)
	canvas.draw_circle(center, 24.0 + p * 36.0, Color(1.0, 0.20, 0.28, 0.18 + p * 0.18))
	canvas.draw_circle(center, 13.0 + p * 18.0, Color(1.0, 0.86, 0.72, 0.24 + p * 0.30))
	_draw_magic_rings(canvas, center, p, 0.50)


func _draw_phase_burst(canvas: CanvasItem, player_center: Vector2, phase_progress: float) -> void:
	var p: float = clamp(phase_progress, 0.0, 1.0)
	var center := player_center + Vector2(0.0, -80.0)
	var flash: float = pow(1.0 - p, 0.65)
	canvas.draw_rect(Rect2(Vector2.ZERO, FIELD_SIZE), Color(1.0, 0.88, 0.88, 0.34 * flash), true)
	for i in range(3):
		var local_p: float = clamp((p - float(i) * 0.14) / max(0.001, 1.0 - float(i) * 0.14), 0.0, 1.0)
		if local_p <= 0.0:
			continue
		var radius: float = 24.0 + local_p * (130.0 + float(i) * 44.0)
		var alpha: float = (1.0 - local_p) * (0.82 - float(i) * 0.18)
		canvas.draw_arc(center, radius, 0.0, TAU, RING_SEGMENTS, Color(1.0, 0.34 + float(i) * 0.12, 0.48, alpha), 4.0 - float(i), true)
	for i in range(18):
		var angle: float = float(i) * TAU / 18.0
		var end_pos := center + Vector2(cos(angle), sin(angle)) * (80.0 + p * 210.0)
		canvas.draw_line(center, end_pos, Color(1.0, 0.82, 0.64, 0.20 * (1.0 - p)), 2.0)


func _draw_phase_landing(
	canvas: CanvasItem,
	player_pos: Vector2,
	paddle_size: Vector2,
	shake_offset: Vector2,
	phase_progress: float,
	draw_context: Dictionary
) -> void:
	var p: float = clamp(phase_progress, 0.0, 1.0)
	var descend_y := 0.0
	if p < 0.5:
		descend_y = -80.0 * (1.0 - sqrt(p / 0.5))
	elif p < 0.65:
		descend_y = -sin((p - 0.5) / 0.15 * PI) * 12.0
	elif p < 0.78:
		descend_y = -sin((p - 0.65) / 0.13 * PI) * 5.0
	var strawberry_context := draw_context.duplicate()
	strawberry_context["horn_strawberry_context"] = {}
	_strawberry_renderer.draw(
		canvas,
		strawberry_context,
		player_pos,
		paddle_size,
		shake_offset,
		clamp(p / 0.18, 0.0, 1.0),
		Vector2(0.0, descend_y)
	)
	var center := player_pos + Vector2(paddle_size.x * 0.5, paddle_size.y * 0.5 + descend_y) + shake_offset
	var aura_alpha: float = max(0.0, 0.36 * (1.0 - p * 0.72))
	for layer in range(4, 0, -1):
		canvas.draw_circle(center + Vector2(0.0, -18.0), 32.0 + float(layer) * 15.0, Color(1.0, 0.56, 0.64, aura_alpha / float(layer)))
	if p > 0.35:
		_draw_transform_label(canvas, center + Vector2(0.0, -84.0), (p - 0.35) / 0.65)
	if p > 0.45 and p < 0.86:
		var wave_p: float = (p - 0.45) / 0.41
		for i in range(2):
			var local_p: float = clamp((wave_p - float(i) * 0.16) / 0.84, 0.0, 1.0)
			if local_p <= 0.0:
				continue
			_draw_ellipse_outline(canvas, Vector2(center.x, player_pos.y + paddle_size.y + 4.0 + shake_offset.y), Vector2(18.0 + local_p * (92.0 + float(i) * 36.0), 7.0 + local_p * 8.0), Color(1.0, 0.48, 0.58, (1.0 - local_p) * 0.66), 2.2)


func _draw_detransform(canvas: CanvasItem, player_center: Vector2, progress: float) -> void:
	var p: float = clamp(progress, 0.0, 1.0)
	var center := player_center + Vector2(0.0, -18.0)
	canvas.draw_rect(Rect2(Vector2.ZERO, FIELD_SIZE), Color(0.26, 0.22, 0.42, 0.12 * sin(p * PI)), true)
	for i in range(3):
		var radius: float = 42.0 + (1.0 - p) * 130.0 + float(i) * 26.0
		canvas.draw_arc(center, radius, 0.0, TAU, RING_SEGMENTS, Color(0.72, 0.70, 1.0, (1.0 - p) * 0.40), 3.0, true)
	var font: Font = ThemeDB.fallback_font
	if font != null:
		var text := "변신해제..."
		var font_size: int = max(16, int(32.0 * sin(p * PI)))
		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
		var pos := center + Vector2(-text_size.x * 0.5, -66.0)
		canvas.draw_string(font, pos + Vector2(1.5, 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, 0.46))
		canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.82, 0.82, 1.0, 0.90))
	_draw_transform_particles(canvas, center, 1.0 - p)


func _draw_spinning_paddle_silhouette(canvas: CanvasItem, center: Vector2, paddle_size: Vector2, axis_scale: float, alpha: float, draw_context: Dictionary) -> void:
	var width: float = max(3.0, paddle_size.x * max(0.10, abs(axis_scale)))
	var height: float = max(14.0, paddle_size.y * 0.72)
	var base_color: Color = _as_color(draw_context.get("player_color", Color(0.25, 0.45, 1.0)), Color(0.25, 0.45, 1.0))
	if axis_scale < 0.0:
		base_color = Color(base_color.b * 0.65, base_color.g * 0.70, base_color.r * 0.78, base_color.a)
	var rect := Rect2(center - Vector2(width * 0.5, height * 0.5), Vector2(width, height))
	canvas.draw_rect(rect.grow(4.0), Color(1.0, 0.72, 0.82, 0.16 * alpha), true)
	canvas.draw_rect(rect, Color(base_color.r, base_color.g, base_color.b, 0.78 * alpha), true)
	canvas.draw_rect(Rect2(rect.position + Vector2(2.0, 2.0), Vector2(max(1.0, rect.size.x - 4.0), max(2.0, rect.size.y * 0.35))), Color(1.0, 1.0, 1.0, 0.20 * alpha), true)


func _draw_magic_rings(canvas: CanvasItem, center: Vector2, progress: float, alpha: float) -> void:
	for ring_index in range(3):
		var local_progress: float = fmod(progress + float(ring_index) * 0.24, 1.0)
		var radius: float = 44.0 + local_progress * 128.0
		var width: float = max(1.2, 4.8 * (1.0 - local_progress))
		canvas.draw_arc(center, radius, 0.0, TAU, RING_SEGMENTS, Color(1.0, 0.76, 0.30, alpha * (1.0 - local_progress * 0.70)), width, true)
		canvas.draw_arc(center, radius * 0.70, 0.0, TAU, RING_SEGMENTS, Color(0.34, 1.0, 0.24, alpha * 0.42), max(1.0, width * 0.42), true)


func _draw_transform_particles(canvas: CanvasItem, center: Vector2, progress: float) -> void:
	for i in range(SPARK_COUNT):
		var angle: float = float(i) * TAU / float(SPARK_COUNT) + progress * TAU * 1.2
		var wave: float = 0.5 + 0.5 * sin(progress * TAU * 2.0 + float(i) * 1.41)
		var distance: float = 36.0 + wave * (78.0 + 64.0 * progress)
		var pos: Vector2 = center + Vector2(cos(angle), sin(angle) * 0.72) * distance
		var size: float = 1.8 + 3.2 * wave
		canvas.draw_circle(pos, size * 2.4, Color(1.0, 0.10, 0.18, 0.11 + 0.12 * sin(progress * PI)))
		canvas.draw_circle(pos, size, Color(1.0, 0.86, 0.42, 0.56 + 0.28 * wave))


func _draw_tiny_strawberry(canvas: CanvasItem, center: Vector2, size: float, alpha: float) -> void:
	canvas.draw_circle(center, size, Color(0.92, 0.06, 0.12, clamp(alpha, 0.0, 1.0)))
	canvas.draw_circle(center + Vector2(-size * 0.24, -size * 0.18), size * 0.26, Color(1.0, 0.62, 0.66, clamp(alpha * 0.68, 0.0, 1.0)))
	canvas.draw_circle(center + Vector2(-size * 0.10, size * 0.10), max(1.0, size * 0.13), Color(1.0, 0.84, 0.30, clamp(alpha * 0.82, 0.0, 1.0)))
	canvas.draw_circle(center + Vector2(size * 0.18, -size * 0.48), size * 0.22, Color(0.22, 0.78, 0.18, clamp(alpha, 0.0, 1.0)))


func _draw_transform_label(canvas: CanvasItem, center: Vector2, progress: float) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var p: float = clamp(progress, 0.0, 1.0)
	var scale: float = 1.0
	if p < 0.30:
		scale = lerp(0.1, 1.20, p / 0.30)
	elif p < 0.50:
		scale = lerp(1.20, 1.0, (p - 0.30) / 0.20)
	var font_size: int = max(16, int(34.0 * scale))
	var alpha: float = clamp(p / 0.20, 0.0, 1.0)
	var text := LanguageSettings.translate_text("뿔딸기변신!")
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var pos := center - Vector2(text_size.x * 0.5, 0.0)
	for offset in [Vector2(-2.0, 0.0), Vector2(2.0, 0.0), Vector2(0.0, -2.0), Vector2(0.0, 2.0)]:
		canvas.draw_string(font, pos + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(1.0, 1.0, 1.0, 0.88 * alpha))
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(1.0, 0.12, 0.26, 0.96 * alpha))


func _draw_ellipse_outline(canvas: CanvasItem, center: Vector2, radius: Vector2, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for idx in range(28):
		var angle: float = TAU * float(idx) / 28.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	for idx in range(points.size()):
		canvas.draw_line(points[idx], points[(idx + 1) % points.size()], color, width)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _as_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback
