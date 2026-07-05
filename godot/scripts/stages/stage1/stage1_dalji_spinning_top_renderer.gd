extends RefCounted

const Stage1ContextReader := preload("res://scripts/stages/stage1/stage1_context_reader.gd")
const ViperAirborneLod := preload("res://scripts/core/viper_airborne_lod.gd")

const TOP_SIZE := 50.0
const TOP_CENTER := TOP_SIZE * 0.5
const TOP_RADIUS := 18.0
const WHIP_SEGMENTS := 3
const BODY_LAYER_COUNT := 3
const GOLDEN_OUTER_GLOW_LAYERS := 2
const GOLDEN_INNER_GLOW_LAYERS := 2
const LOD_WHIP_SEGMENTS := 1
const LOD_BODY_LAYER_COUNT := 1
const LOD_GOLDEN_OUTER_GLOW_LAYERS := 1
const LOD_GOLDEN_INNER_GLOW_LAYERS := 1
const WHIP_COLOR := Color(0.545, 0.271, 0.075, 1.0)
const WOOD_COLOR := Color(0.627, 0.322, 0.176, 1.0)
const AXIS_COLOR := Color(0.235, 0.118, 0.059, 1.0)
const DEFAULT_BOSS_VISUAL_CENTER_Y_OFFSET := 25.0
const DEFAULT_BOSS_DRAW_SIZE := Vector2(96.0, 112.0)
const PAENGI_TOP_WHIP_SOURCE_CELL_SIZE := 512.0
# Per-frame switch-tip (whip-cord origin) for the v2 32-frame paengi sheet, in
# 512 px source-cell coords. Measured by motion phase: windup (0-4) switch raised
# up-left, downswing/strike (5-7) down-right, post-strike (8) down-left, ready
# (9-22) switch held across the chest with the tip on her right, recovery (23-31)
# switch lowered forward down-right. Manual estimates (~+/-20px) — fine-tune in
# live QA if the procedural cord drifts off Dalji's drawn switch.
const PAENGI_STICK_TIP_SOURCE_POINTS := [
	Vector2(90.0, 60.0),
	Vector2(105.0, 62.0),
	Vector2(120.0, 68.0),
	Vector2(140.0, 75.0),
	Vector2(135.0, 62.0),
	Vector2(345.0, 275.0),
	Vector2(360.0, 310.0),
	Vector2(380.0, 345.0),
	Vector2(150.0, 270.0),
	Vector2(320.0, 245.0),
	Vector2(326.0, 245.0),
	Vector2(326.0, 245.0),
	Vector2(326.0, 245.0),
	Vector2(326.0, 245.0),
	Vector2(326.0, 245.0),
	Vector2(326.0, 245.0),
	Vector2(326.0, 245.0),
	Vector2(326.0, 245.0),
	Vector2(326.0, 245.0),
	Vector2(326.0, 245.0),
	Vector2(326.0, 245.0),
	Vector2(326.0, 245.0),
	Vector2(326.0, 245.0),
	Vector2(345.0, 255.0),
	Vector2(345.0, 320.0),
	Vector2(350.0, 345.0),
	Vector2(350.0, 348.0),
	Vector2(350.0, 348.0),
	Vector2(350.0, 348.0),
	Vector2(350.0, 348.0),
	Vector2(350.0, 348.0),
	Vector2(365.0, 348.0),
]
const NORMAL_PATTERN_COLORS := [
	Color(0.392, 0.784, 0.784, 1.0),
	Color(0.863, 0.392, 0.392, 1.0),
	Color(1.000, 0.784, 0.196, 1.0),
]
const GOLDEN_PATTERN_COLORS := [
	Color(1.000, 0.843, 0.000, 1.0),
	Color(1.000, 0.875, 0.000, 1.0),
	Color(0.855, 0.647, 0.125, 1.0),
]


func draw(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2, perf_logger: Object = null) -> void:
	if canvas == null or not bool(context.get("stage1_spinning_top_active", false)):
		return
	var tops: Array = _get_array(context.get("stage1_spinning_top_tops", []))
	if tops.is_empty():
		return
	var lod_active: bool = ViperAirborneLod.is_any_lod_active(context)
	var sample_start: int = _perf_begin(perf_logger)
	var whip_target: int = int(context.get("stage1_spinning_top_whip_target_index", -1))
	if whip_target >= 0 and whip_target < tops.size() and (tops[whip_target] is Dictionary):
		_draw_whip_line(canvas, context, tops[whip_target], shake_offset, lod_active)
	_perf_end(perf_logger, "stage1.spinning_top.whip", sample_start)
	sample_start = _perf_begin(perf_logger)
	for top_value in tops:
		if top_value is Dictionary:
			_draw_top(canvas, top_value, shake_offset, lod_active)
	_perf_end(perf_logger, "stage1.spinning_top.tops", sample_start)


func _draw_whip_line(canvas: CanvasItem, context: Dictionary, top: Dictionary, shake_offset: Vector2, lod_active: bool) -> void:
	var start: Vector2 = _get_whip_start(context, shake_offset)
	var timer: float = float(context.get("stage1_spinning_top_whip_timer", 0.0))
	var segment_count: int = LOD_WHIP_SEGMENTS if lod_active else WHIP_SEGMENTS
	var end := Vector2(float(top.get("x", 0.0)), float(top.get("y", 0.0))) + shake_offset
	var control := Vector2(
		(start.x + end.x) * 0.5 + sin(timer * 0.5) * 30.0,
		(start.y + end.y) * 0.5 - 20.0
	)
	for i in range(segment_count):
		var t1: float = float(i) / float(segment_count)
		var t2: float = float(i + 1) / float(segment_count)
		var p1: Vector2 = _quadratic_point(start, control, end, t1)
		var p2: Vector2 = _quadratic_point(start, control, end, t2)
		var thickness: float = max(1.0, 3.0 - floor(float(i) * 0.3))
		canvas.draw_line(p1, p2, WHIP_COLOR, thickness, true)


func _get_whip_start(context: Dictionary, shake_offset: Vector2) -> Vector2:
	if bool(context.get("boss_paengi_top_whip_active", false)):
		var frame: int = clamp(
			int(context.get("boss_paengi_top_whip_frame", 0)),
			0,
			PAENGI_STICK_TIP_SOURCE_POINTS.size() - 1
		)
		var source_point: Vector2 = PAENGI_STICK_TIP_SOURCE_POINTS[frame]
		var visual_rect: Rect2 = _get_boss_visual_rect(context, shake_offset)
		return visual_rect.position + Vector2(
			source_point.x / PAENGI_TOP_WHIP_SOURCE_CELL_SIZE * visual_rect.size.x,
			source_point.y / PAENGI_TOP_WHIP_SOURCE_CELL_SIZE * visual_rect.size.y
		)

	var boss_pos: Vector2 = Stage1ContextReader.as_vector2(context.get("boss_pos", Vector2.ZERO), Vector2.ZERO)
	var boss_size: Vector2 = Stage1ContextReader.as_vector2(context.get("boss_paddle_size", Vector2(100.0, 40.0)), Vector2(100.0, 40.0))
	var boss_hitbox_height: float = float(context.get("boss_hitbox_height", boss_size.y))
	return Vector2(
		boss_pos.x + boss_size.x * 0.5,
		boss_pos.y + boss_hitbox_height * 0.5
	) + shake_offset


func _get_boss_visual_rect(context: Dictionary, shake_offset: Vector2) -> Rect2:
	var boss_pos: Vector2 = Stage1ContextReader.as_vector2(context.get("boss_pos", Vector2.ZERO), Vector2.ZERO)
	var boss_size: Vector2 = Stage1ContextReader.as_vector2(context.get("boss_paddle_size", Vector2(100.0, 40.0)), Vector2(100.0, 40.0))
	var boss_hitbox_height: float = float(context.get("boss_hitbox_height", boss_size.y))
	var boss_draw_size: Vector2 = Stage1ContextReader.as_vector2(
		context.get("boss_sprite_draw_size", DEFAULT_BOSS_DRAW_SIZE),
		DEFAULT_BOSS_DRAW_SIZE
	)
	var boss_visual_center_y: float = (
		boss_pos.y
		+ boss_hitbox_height * 0.5
		+ float(context.get("boss_visual_center_y_offset", DEFAULT_BOSS_VISUAL_CENTER_Y_OFFSET))
		+ float(context.get("boss_whip_bob_offset", 0.0))
	)
	return Rect2(
		boss_pos.x + boss_size.x * 0.5 - boss_draw_size.x * 0.5 + shake_offset.x,
		boss_visual_center_y - boss_draw_size.y * 0.5 + shake_offset.y,
		boss_draw_size.x,
		boss_draw_size.y
	)


func _draw_top(canvas: CanvasItem, top: Dictionary, shake_offset: Vector2, lod_active: bool) -> void:
	var pos := Vector2(float(top.get("x", 0.0)), float(top.get("y", 0.0))) + shake_offset
	var alpha: float = clamp(float(top.get("alpha", 255.0)) / 255.0, 0.0, 1.0)
	var tilt: float = float(top.get("tilt", 0.0))
	var height_scale: float = 1.0 - clamp(tilt / 90.0, 0.0, 1.0) * 0.5
	if bool(top.get("is_golden", false)):
		_draw_golden_glow(canvas, pos, alpha, lod_active)
	_draw_shadow(canvas, pos, alpha, tilt)
	_draw_body(canvas, pos, alpha, height_scale, lod_active)
	_draw_disc(canvas, top, pos, alpha, height_scale)
	_draw_axis(canvas, pos, alpha, height_scale)


func _draw_golden_glow(canvas: CanvasItem, pos: Vector2, alpha: float, lod_active: bool) -> void:
	var ticks: float = float(Time.get_ticks_msec()) / 1000.0
	var intensity: float = (sin(ticks * 2.0) + 1.0) * 0.3 + 0.4
	var outer_layers: int = LOD_GOLDEN_OUTER_GLOW_LAYERS if lod_active else GOLDEN_OUTER_GLOW_LAYERS
	var inner_layers: int = LOD_GOLDEN_INNER_GLOW_LAYERS if lod_active else GOLDEN_INNER_GLOW_LAYERS
	for i in range(outer_layers):
		var radius: float = 60.0 - float(i) * 10.0
		var glow_alpha: float = 0.06 * (1.0 - float(i) / float(outer_layers)) * intensity * alpha
		canvas.draw_circle(pos, radius, Color(1.0, 0.84, 0.0, glow_alpha))
	for i in range(inner_layers):
		var radius: float = 34.0 - float(i) * 7.0
		var glow_alpha: float = 0.10 * (1.0 - float(i) / float(inner_layers)) * intensity * alpha
		canvas.draw_circle(pos, radius, Color(1.0, 0.90, 0.0, glow_alpha))


func _draw_shadow(canvas: CanvasItem, pos: Vector2, alpha: float, tilt: float) -> void:
	var shadow_width: float = 30.0 + int(tilt / 4.0)
	var shadow_alpha: float = alpha * 0.25
	if tilt > 0.0:
		shadow_alpha *= 1.0 - clamp(tilt / 90.0, 0.0, 1.0)
	var rect := Rect2(
		pos + Vector2(-shadow_width * 0.5, 25.0),
		Vector2(shadow_width, 12.0)
	)
	canvas.draw_circle(rect.position + rect.size * 0.5, min(rect.size.x, rect.size.y) * 0.5, Color(0.0, 0.0, 0.0, shadow_alpha))


func _draw_body(canvas: CanvasItem, pos: Vector2, alpha: float, height_scale: float, lod_active: bool) -> void:
	var layer_count: int = LOD_BODY_LAYER_COUNT if lod_active else BODY_LAYER_COUNT
	for i in range(layer_count):
		var y_offset: float = float(i) * height_scale * 1.5
		if TOP_CENTER + y_offset >= TOP_SIZE - 3.0:
			continue
		var radius: float = 18.0 - float(i) * 2.4
		if radius > 0.0:
			canvas.draw_circle(pos + Vector2(0.0, y_offset), radius, _with_alpha(WOOD_COLOR, alpha))


func _draw_disc(canvas: CanvasItem, top: Dictionary, pos: Vector2, alpha: float, height_scale: float) -> void:
	var colors: Array = GOLDEN_PATTERN_COLORS if bool(top.get("is_golden", false)) else NORMAL_PATTERN_COLORS
	if float(top.get("boost_timer", 0.0)) > 0.0:
		colors = _boost_colors(colors, float(top.get("boost_timer", 0.0)))
	var rotation_phase: float = fposmod(float(top.get("rotation", 0.0)) / 10.0, 3.0)
	var color_index: int = int(rotation_phase)
	var next_color_index: int = (color_index + 1) % 3
	var blend_factor: float = rotation_phase - float(color_index)
	var current_color: Color = colors[color_index]
	var next_color: Color = colors[next_color_index]
	var blended := current_color.lerp(next_color, blend_factor)
	var disc_center := pos + Vector2(0.0, TOP_CENTER * height_scale - 5.0 - TOP_CENTER)
	canvas.draw_circle(disc_center, TOP_RADIUS, _with_alpha(blended, alpha))
	canvas.draw_circle(disc_center, 12.0, _with_alpha(colors[(color_index + 2) % 3], alpha))
	canvas.draw_circle(disc_center, 6.0, _with_alpha(colors[color_index], alpha))


func _draw_axis(canvas: CanvasItem, pos: Vector2, alpha: float, height_scale: float) -> void:
	var start := pos + Vector2(0.0, TOP_CENTER * height_scale - 5.0 - TOP_CENTER)
	var end := pos + Vector2(0.0, TOP_CENTER + 30.0 * height_scale - TOP_CENTER)
	canvas.draw_line(start, end, _with_alpha(AXIS_COLOR, alpha), 3.0, true)


func _boost_colors(colors: Array, boost_timer: float) -> Array:
	var glow: float = 0.5 * clamp(boost_timer / 18.0, 0.0, 1.0)
	var boosted: Array = []
	for color_value in colors:
		var color: Color = color_value
		boosted.append(Color(
			min(1.0, color.r + glow),
			min(1.0, color.g + glow),
			min(1.0, color.b + glow),
			color.a
		))
	return boosted


func _quadratic_point(start: Vector2, control: Vector2, end: Vector2, t: float) -> Vector2:
	var inv: float = 1.0 - t
	return start * inv * inv + control * 2.0 * t * inv + end * t * t


func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * alpha)


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
