extends RefCounted

const STATE_TRANSFORM_EVENT := "transform_event"
const STATE_DETRANSFORM_EVENT := "detransform_event"
const TRANSFORM_EVENT_SEC := 4.5
const DETRANSFORM_EVENT_SEC := 2.0
const FIELD_CENTER := Vector2(380.0, 375.0)
const FIELD_SIZE := Vector2(760.0, 750.0)
const RING_SEGMENTS := 54
const SPARK_COUNT := 18


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


func draw(canvas: CanvasItem, shake_offset: Vector2, context: Dictionary) -> void:
	if canvas == null:
		return
	var phase: Dictionary = build_phase_context(context)
	if phase.is_empty():
		return
	var progress: float = float(phase.get("progress", 0.0))
	var mode: String = str(phase.get("mode", ""))
	var center: Vector2 = FIELD_CENTER + shake_offset
	var pulse: float = sin(progress * PI)
	var body_alpha: float = 0.10 + 0.16 * pulse
	var ring_alpha: float = 0.28 + 0.42 * pulse
	if mode == "detransform":
		body_alpha *= 0.72
		ring_alpha *= 0.76

	canvas.draw_rect(Rect2(Vector2.ZERO, FIELD_SIZE), Color(0.96, 0.05, 0.12, body_alpha), true)
	_draw_rings(canvas, center, progress, mode, ring_alpha)
	_draw_sparks(canvas, center, progress, mode, ring_alpha)
	_draw_emblem(canvas, center, progress, mode)


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


func _draw_rings(canvas: CanvasItem, center: Vector2, progress: float, mode: String, alpha: float) -> void:
	for ring_index in range(3):
		var local_progress: float = fmod(progress + float(ring_index) * 0.24, 1.0)
		if mode == "detransform":
			local_progress = 1.0 - local_progress
		var radius: float = 56.0 + local_progress * 210.0
		var width: float = max(1.4, 6.0 * (1.0 - local_progress))
		canvas.draw_arc(
			center,
			radius,
			0.0,
			TAU,
			RING_SEGMENTS,
			Color(1.0, 0.86, 0.32, alpha * (1.0 - local_progress * 0.72)),
			width,
			true
		)
		canvas.draw_arc(
			center,
			radius * 0.72,
			0.0,
			TAU,
			RING_SEGMENTS,
			Color(0.30, 0.98, 0.22, alpha * 0.46),
			max(1.0, width * 0.42),
			true
		)


func _draw_sparks(canvas: CanvasItem, center: Vector2, progress: float, mode: String, alpha: float) -> void:
	for i in range(SPARK_COUNT):
		var angle: float = float(i) * TAU / float(SPARK_COUNT) + progress * TAU * 0.72
		var wave: float = 0.5 + 0.5 * sin(progress * TAU + float(i) * 1.41)
		var distance: float = 58.0 + wave * 168.0
		if mode == "detransform":
			distance = 230.0 - wave * 160.0
		var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * distance
		var size: float = 2.0 + 3.0 * wave
		canvas.draw_circle(pos, size * 2.4, Color(1.0, 0.08, 0.14, alpha * 0.22))
		canvas.draw_circle(pos, size, Color(1.0, 0.84, 0.42, alpha * 0.86))


func _draw_emblem(canvas: CanvasItem, center: Vector2, progress: float, mode: String) -> void:
	var pulse: float = 0.5 + 0.5 * sin(progress * TAU * 2.0)
	var scale: float = 0.78 + 0.22 * pulse
	if mode == "transform":
		scale *= 0.58 + 0.42 * clamp(progress * 1.6, 0.0, 1.0)
	else:
		scale *= 1.0 - 0.22 * progress
	var berry_radius: float = 34.0 * scale
	canvas.draw_circle(center, berry_radius + 9.0, Color(0.98, 0.02, 0.12, 0.20))
	canvas.draw_circle(center, berry_radius, Color(0.94, 0.07, 0.14, 0.88))
	canvas.draw_circle(center + Vector2(-berry_radius * 0.28, -berry_radius * 0.18), berry_radius * 0.20, Color(1.0, 0.66, 0.66, 0.64))
	_draw_leaf(canvas, center + Vector2(0.0, -berry_radius * 0.82), berry_radius * 0.52, -0.42)
	_draw_leaf(canvas, center + Vector2(0.0, -berry_radius * 0.86), berry_radius * 0.52, 0.42)
	for i in range(7):
		var angle: float = float(i) * TAU / 7.0 + 0.3
		var seed_pos: Vector2 = center + Vector2(cos(angle) * berry_radius * 0.48, sin(angle) * berry_radius * 0.42)
		canvas.draw_circle(seed_pos, max(1.6, berry_radius * 0.055), Color(1.0, 0.86, 0.38, 0.92))


func _draw_leaf(canvas: CanvasItem, center: Vector2, size: float, tilt: float) -> void:
	var dir := Vector2(sin(tilt), -cos(tilt))
	var side := Vector2(-dir.y, dir.x)
	var tip := center + dir * size
	var left := center - dir * size * 0.15 + side * size * 0.42
	var right := center - dir * size * 0.15 - side * size * 0.42
	canvas.draw_polygon(
		PackedVector2Array([tip, left, center, right]),
		PackedColorArray([
			Color(0.30, 0.95, 0.22, 0.92),
			Color(0.07, 0.44, 0.14, 0.86),
			Color(0.14, 0.72, 0.16, 0.92),
			Color(0.06, 0.38, 0.12, 0.86),
		])
	)
