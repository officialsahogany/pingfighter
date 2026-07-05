extends RefCounted

const Stage1ContextReader := preload("res://scripts/stages/stage1/stage1_context_reader.gd")

const DEFAULT_DRAW_SIZE := Vector2(56.0, 56.0)
const HIT_EFFECT_MAX_FRAMES := 24.0
const FAN_WIND_MAX_RADIUS := 42.0
# Sheet grid is per-asset authority (see gaksital manifest) -- never assume a shared 4x4.
const FAN_WIND_SHEET_COLS := 4
const FAN_WIND_SHEET_ROWS := 4
const FAN_WIND_SHEET_DRAW_DIAMETER := 128.0
const FAN_WIND_FADE_TIMER_RATIO := 0.125


func draw(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2 = Vector2.ZERO, _perf_logger: Object = null) -> void:
	if canvas == null or int(context.get("current_stage", 1)) != 1:
		return
	# Flat sequence on purpose: fan_wind / hit-effect visibility must NEVER
	# depend on the fan projectile list being non-empty (fan_wind runs with
	# zero fans in flight).
	_draw_fans(canvas, context, shake_offset)
	_draw_fan_wind(canvas, context, shake_offset)
	_draw_hit_effect(canvas, context, shake_offset)


func _draw_fans(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var fans: Array = context.get("stage1_fan_throw_fans", []) if context.get("stage1_fan_throw_fans", []) is Array else []
	var texture: Variant = context.get("boss_fan_projectile_texture", null)
	for fan_value in fans:
		if not (fan_value is Dictionary):
			continue
		_draw_fan(canvas, fan_value as Dictionary, texture, shake_offset)


func _draw_fan(canvas: CanvasItem, fan: Dictionary, texture: Variant, shake_offset: Vector2) -> void:
	var pos := Vector2(float(fan.get("x", 0.0)), float(fan.get("y", 0.0))) + shake_offset
	var draw_size := Vector2(
		max(1.0, float(fan.get("draw_size", DEFAULT_DRAW_SIZE.x))),
		max(1.0, float(fan.get("draw_size", DEFAULT_DRAW_SIZE.y)))
	)
	var alpha: float = clamp(float(fan.get("alpha", 1.0)), 0.0, 1.0)
	var tint := _as_color(fan.get("tint", Color.WHITE), Color.WHITE)
	var modulate := Color(tint.r, tint.g, tint.b, tint.a * alpha)
	var spin: float = float(fan.get("spin", 0.0))
	if texture is Texture2D:
		_draw_rotated_texture(canvas, texture as Texture2D, pos, draw_size, spin, modulate)
		return
	_draw_fallback_fan(canvas, pos, draw_size, spin, modulate)


func _draw_rotated_texture(
	canvas: CanvasItem,
	texture: Texture2D,
	center: Vector2,
	draw_size: Vector2,
	angle_radians: float,
	modulate: Color
) -> void:
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var half_size: Vector2 = draw_size * 0.5
	var cos_a: float = cos(angle_radians)
	var sin_a: float = sin(angle_radians)
	var offsets := [
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	]
	var points := PackedVector2Array()
	for offset in offsets:
		points.append(center + Vector2(
			offset.x * cos_a - offset.y * sin_a,
			offset.x * sin_a + offset.y * cos_a
		))
	var uvs := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(1.0, 1.0),
		Vector2(0.0, 1.0),
	])
	canvas.draw_polygon(points, PackedColorArray([modulate, modulate, modulate, modulate]), uvs, texture)


func _draw_fallback_fan(canvas: CanvasItem, center: Vector2, draw_size: Vector2, angle_radians: float, modulate: Color) -> void:
	var radius: float = max(draw_size.x, draw_size.y) * 0.42
	var handle := Vector2(cos(angle_radians), sin(angle_radians)) * radius * 0.28
	var points := PackedVector2Array()
	points.append(center - handle)
	for i in range(9):
		var t: float = -0.62 + 1.24 * float(i) / 8.0
		var angle: float = angle_radians - PI * 0.5 + t
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	canvas.draw_colored_polygon(points, Color(modulate.r, modulate.g, modulate.b, 0.78 * modulate.a))
	for i in range(1, points.size()):
		canvas.draw_line(center - handle, points[i], Color(0.95, 0.70, 0.30, 0.75 * modulate.a), 1.0)
	canvas.draw_arc(center - handle, radius * 0.18, angle_radians - 0.7, angle_radians + 0.7, 10, Color(0.95, 0.30, 0.18, modulate.a), 2.0)


func _draw_hit_effect(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var timer: float = max(0.0, float(context.get("stage1_fan_throw_hit_effect_timer", 0.0)))
	if timer <= 0.0:
		return
	var pos: Vector2 = Stage1ContextReader.as_vector2(
		context.get("stage1_fan_throw_hit_effect_pos", Vector2.ZERO),
		Vector2.ZERO
	) + shake_offset
	var ratio: float = clamp(timer / HIT_EFFECT_MAX_FRAMES, 0.0, 1.0)
	var outward: float = 1.0 - ratio
	var radius: float = 14.0 + outward * 28.0
	canvas.draw_circle(pos, radius * 0.55, Color(1.0, 0.34, 0.24, 0.18 * ratio))
	canvas.draw_arc(pos, radius, 0.0, TAU, 32, Color(1.0, 0.86, 0.45, 0.62 * ratio), 2.0)
	canvas.draw_arc(pos, radius * 0.66, 0.0, TAU, 24, Color(0.98, 0.24, 0.18, 0.55 * ratio), 1.5)


func _draw_fan_wind(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	if not bool(context.get("stage1_fan_wind_visible", false)):
		return
	var center: Vector2 = Stage1ContextReader.as_vector2(
		context.get("stage1_fan_wind_pos", Vector2.ZERO),
		Vector2.ZERO
	) + shake_offset
	var growth: float = clamp(float(context.get("stage1_fan_wind_growth_scale", 0.0)), 0.0, 1.0)
	var timer_ratio: float = clamp(float(context.get("stage1_fan_wind_timer_ratio", 1.0)), 0.0, 1.0)
	var phase: float = float(context.get("stage1_fan_wind_spin_phase", 0.0))
	var captured: bool = bool(context.get("stage1_fan_wind_captured", false))
	var charging: bool = bool(context.get("stage1_fan_wind_charging", false))
	var sheet: Variant = context.get("boss_fan_wind_sheet", null)
	if sheet is Texture2D:
		_draw_fan_wind_sheet(canvas, sheet as Texture2D, center, growth, timer_ratio, phase, charging, captured)
	else:
		_draw_fan_wind_procedural(canvas, center, growth, timer_ratio, phase, charging, captured)
	if captured:
		var capture_radius: float = max(3.0, float(context.get("stage1_fan_wind_capture_radius", 0.0)))
		var capture_angle: float = float(context.get("stage1_fan_wind_capture_angle", 0.0))
		var capture_pos: Vector2 = center + Vector2(cos(capture_angle), sin(capture_angle)) * capture_radius
		canvas.draw_arc(center, capture_radius, 0.0, TAU, 24, Color(1.0, 0.95, 0.58, 0.62), 1.4)
		canvas.draw_circle(capture_pos, 4.0, Color(1.0, 0.90, 0.40, 0.58))


func _draw_fan_wind_sheet(
	canvas: CanvasItem,
	sheet: Texture2D,
	center: Vector2,
	growth: float,
	timer_ratio: float,
	phase: float,
	charging: bool,
	captured: bool
) -> void:
	var texture_size: Vector2 = sheet.get_size()
	var cell := Vector2(texture_size.x / float(FAN_WIND_SHEET_COLS), texture_size.y / float(FAN_WIND_SHEET_ROWS))
	if cell.x <= 0.0 or cell.y <= 0.0:
		return
	var frame_count: int = FAN_WIND_SHEET_COLS * FAN_WIND_SHEET_ROWS
	var frame: int = int(floor(fposmod(phase, TAU) / TAU * float(frame_count))) % frame_count
	var column: int = frame % FAN_WIND_SHEET_COLS
	var row: int = int(float(frame) / float(FAN_WIND_SHEET_COLS))
	var source_rect := Rect2(Vector2(float(column) * cell.x, float(row) * cell.y), cell)
	var draw_diameter: float = FAN_WIND_SHEET_DRAW_DIAMETER * max(growth, 0.12)
	var alpha: float = clamp(timer_ratio / FAN_WIND_FADE_TIMER_RATIO, 0.0, 1.0)
	if charging:
		alpha = 0.85
	if captured:
		alpha = min(1.0, alpha + 0.1)
	var dest_rect := Rect2(center - Vector2(draw_diameter, draw_diameter) * 0.5, Vector2(draw_diameter, draw_diameter))
	canvas.draw_texture_rect_region(sheet, dest_rect, source_rect, Color(1.0, 1.0, 1.0, alpha))


func _draw_fan_wind_procedural(
	canvas: CanvasItem,
	center: Vector2,
	growth: float,
	timer_ratio: float,
	phase: float,
	charging: bool,
	captured: bool
) -> void:
	var radius: float = lerp(12.0, FAN_WIND_MAX_RADIUS, max(growth, 0.1))
	var alpha: float = 0.22 + 0.26 * timer_ratio
	if charging:
		alpha *= 0.75
	if captured:
		alpha = min(0.75, alpha + 0.18)
	canvas.draw_circle(center, radius * 0.78, Color(0.58, 0.86, 1.0, 0.10 * alpha))
	for i in range(5):
		var ring_radius: float = radius * (0.38 + float(i) * 0.15)
		var start_angle: float = phase * (1.0 + float(i) * 0.12) + float(i) * 0.74
		canvas.draw_arc(
			center,
			ring_radius,
			start_angle,
			start_angle + PI * 1.25,
			18,
			Color(0.72, 0.93, 1.0, alpha * (0.76 - float(i) * 0.08)),
			1.2
		)
	for i in range(6):
		var angle: float = phase + float(i) * TAU / 6.0
		var inner: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius * 0.18
		var outer: Vector2 = center + Vector2(cos(angle + 0.45), sin(angle + 0.45)) * radius
		canvas.draw_line(inner, outer, Color(0.46, 0.78, 1.0, alpha * 0.48), 1.0)


func _as_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback
