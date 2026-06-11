extends RefCounted

# Direct-draw exception note: the bounce visual is a per-frame deforming mat
# polygon (deterministic geometry driven by the runtime bounce timer), so the
# procedural path is kept as a fallback when the generated sprite assets are
# unavailable.

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const ActiveItemTrampolineRuntime := preload("res://scripts/items/active_item_trampoline_runtime.gd")

const INSTALLED_TEXTURE_PATH := "res://assets/sprites/items/trampoline_installed_runtime_v1.png"
const STRETCH_SHEET_TEXTURE_PATH := "res://assets/sprites/items/trampoline_stretch_autosprite_v2_runtime_sheet.png"
const STRETCH_SHEET_COLUMNS := 4
const STRETCH_SHEET_ROWS := 4
const STRETCH_SHEET_FRAME_COUNT := 16
const TEXTURE_DRAW_WIDTH_SCALE := 1.15
const TEXTURE_DRAW_BOTTOM_OFFSET := 11.0
const TEXTURE_DRAW_MIN_HEIGHT := 24.0
const MAT_TOP_SEGMENTS := 12
const MAT_MIN_FABRIC_THICKNESS := 2.0
const MAT_MAX_SAG := 7.0
const MAT_OVERSHOOT_SCALE := 0.65
const MAT_MAX_CAPTURE_SAG := 38.0
const MAT_SAG_ARCH_HALF_WIDTH := 0.55
const MAT_COLOR := Color(0.16, 0.22, 0.38)
const MAT_EDGE_COLOR := Color(0.10, 0.13, 0.24)
const RIM_COLOR := Color(0.42, 0.86, 1.0)
const LEG_COLOR := Color(0.30, 0.34, 0.44)
const SPRING_COLOR := Color(0.78, 0.84, 0.95)
const PIP_REMAINING_COLOR := Color(0.55, 0.95, 1.0)
const PIP_USED_COLOR := Color(0.30, 0.36, 0.50, 0.55)

var _installed_texture: Texture2D = null
var _stretch_sheet_texture: Texture2D = null


func prewarm_assets() -> void:
	_touch_texture(get_installed_texture())
	_touch_texture(get_stretch_sheet_texture())


func get_installed_texture() -> Texture2D:
	if _installed_texture != null:
		return _installed_texture
	_installed_texture = ProjectResourceLoader.load_texture(
		INSTALLED_TEXTURE_PATH,
		"Missing trampoline installed sprite at %s",
		"Failed to load trampoline installed sprite at %s"
	)
	return _installed_texture


func get_stretch_sheet_texture() -> Texture2D:
	if _stretch_sheet_texture != null:
		return _stretch_sheet_texture
	_stretch_sheet_texture = ProjectResourceLoader.load_texture(
		STRETCH_SHEET_TEXTURE_PATH,
		"Missing trampoline stretch sheet at %s",
		"Failed to load trampoline stretch sheet at %s"
	)
	return _stretch_sheet_texture


func get_stretch_sheet_source_rect_for_tests(frame_index: int) -> Rect2:
	var sheet: Texture2D = get_stretch_sheet_texture()
	if sheet == null:
		return Rect2()
	return _get_stretch_sheet_source_rect(sheet, frame_index)


func get_stretch_sheet_frame_index_for_tests(trampoline: Dictionary) -> int:
	return _get_stretch_sheet_frame_index(trampoline)


func draw_trampoline_effect(canvas: CanvasItem, trampoline_context: Dictionary, shake_offset: Vector2) -> void:
	if canvas == null or trampoline_context.is_empty():
		return
	var trampolines: Array = _get_array(trampoline_context, "trampolines")
	for trampoline_value in trampolines:
		if trampoline_value is Dictionary:
			_draw_trampoline(canvas, trampoline_value, shake_offset)
	var particles: Array = _get_array(trampoline_context, "particles")
	for particle_value in particles:
		if particle_value is Dictionary:
			_draw_particle(canvas, particle_value, shake_offset)


func _draw_trampoline(canvas: CanvasItem, trampoline: Dictionary, shake_offset: Vector2) -> void:
	var rect: Rect2 = _get_rect2(trampoline, "rect")
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return

	var spawn_scale: float = _get_spawn_scale(float(trampoline.get("spawn_timer_frames", 0.0)))
	var deflection: float = _get_mat_deflection(trampoline)
	var sag_center: float = clamp(float(trampoline.get("capture_x_ratio", 0.5)), 0.0, 1.0)
	var center := rect.get_center() + shake_offset
	var half_width: float = rect.size.x * 0.5 * spawn_scale
	var mat_height: float = max(4.0, rect.size.y * spawn_scale)
	var mat_top: float = center.y - mat_height * 0.5
	var mat_bottom: float = center.y + mat_height * 0.5

	if not _draw_textured_trampoline(canvas, trampoline, center, half_width, mat_bottom, spawn_scale):
		_draw_legs(canvas, center, half_width, mat_bottom)
		_draw_mat(canvas, center, half_width, mat_top, mat_bottom, deflection, sag_center)
		_draw_springs(canvas, center, half_width, mat_bottom)
	_draw_bounce_pips(canvas, trampoline, center, half_width, mat_top)


func _draw_textured_trampoline(
	canvas: CanvasItem,
	trampoline: Dictionary,
	center: Vector2,
	half_width: float,
	mat_bottom: float,
	spawn_scale: float
) -> bool:
	var frame_index: int = _get_stretch_sheet_frame_index(trampoline)
	var texture: Texture2D = null
	var source_rect := Rect2()
	if frame_index >= 0:
		texture = get_stretch_sheet_texture()
		if texture != null:
			source_rect = _get_stretch_sheet_source_rect(texture, frame_index)
	if texture == null:
		texture = get_installed_texture()
	if texture == null:
		return false

	var source_size: Vector2 = source_rect.size if source_rect.size.x > 0.0 and source_rect.size.y > 0.0 else texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return false
	var draw_width: float = max(1.0, half_width * 2.0 * TEXTURE_DRAW_WIDTH_SCALE)
	var draw_height: float = max(TEXTURE_DRAW_MIN_HEIGHT * spawn_scale, draw_width * source_size.y / source_size.x)
	var visual_bottom: float = mat_bottom + TEXTURE_DRAW_BOTTOM_OFFSET * spawn_scale
	var draw_rect := Rect2(
		Vector2(center.x - draw_width * 0.5, visual_bottom - draw_height),
		Vector2(draw_width, draw_height)
	)
	if source_rect.size.x > 0.0 and source_rect.size.y > 0.0:
		canvas.draw_texture_rect_region(texture, draw_rect, source_rect)
	else:
		canvas.draw_texture_rect(texture, draw_rect, false)
	return true


func _draw_legs(canvas: CanvasItem, center: Vector2, half_width: float, mat_bottom: float) -> void:
	var floor_y: float = ActiveItemTrampolineRuntime.TRAMPOLINE_BOTTOM_Y + 5.0
	var leg_height: float = max(2.0, floor_y - mat_bottom)
	for side in [-1.0, 1.0]:
		var leg_x: float = center.x + side * (half_width - 9.0)
		canvas.draw_rect(Rect2(leg_x - 2.5, mat_bottom - 1.0, 5.0, leg_height + 1.0), LEG_COLOR)


func _draw_mat(
	canvas: CanvasItem,
	center: Vector2,
	half_width: float,
	mat_top: float,
	mat_bottom: float,
	deflection: float,
	sag_center: float = 0.5
) -> void:
	var top_points := build_mat_top_points(center, half_width, mat_top, deflection, sag_center)
	canvas.draw_colored_polygon(build_mat_body_points(top_points, mat_bottom), MAT_COLOR)
	canvas.draw_line(
		Vector2(center.x - half_width, mat_bottom),
		Vector2(center.x + half_width, mat_bottom),
		MAT_EDGE_COLOR,
		2.0
	)
	canvas.draw_polyline(top_points, RIM_COLOR, 2.5)
	var glow_alpha: float = clamp(0.22 + abs(deflection) * 0.06, 0.22, 0.62)
	canvas.draw_polyline(top_points, Color(RIM_COLOR.r, RIM_COLOR.g, RIM_COLOR.b, glow_alpha), 5.0)


static func build_mat_top_points(
	center: Vector2,
	half_width: float,
	mat_top: float,
	deflection: float,
	sag_center: float
) -> PackedVector2Array:
	var top_points := PackedVector2Array()
	for i in range(MAT_TOP_SEGMENTS + 1):
		var ratio: float = float(i) / float(MAT_TOP_SEGMENTS)
		var x: float = center.x - half_width + ratio * half_width * 2.0
		var arch: float = max(0.0, 1.0 - pow((ratio - sag_center) / MAT_SAG_ARCH_HALF_WIDTH, 2.0))
		top_points.append(Vector2(x, mat_top + deflection * arch))
	return top_points


# A full slingshot draw (MAT_MAX_CAPTURE_SAG) sinks the top curve below the
# mat's bottom edge, so a fixed flat bottom would self-intersect and fail
# draw_colored_polygon triangulation. The bottom edge therefore follows the
# sagged top at a minimum fabric thickness wherever the top dips below it.
static func build_mat_body_points(top_points: PackedVector2Array, mat_bottom: float) -> PackedVector2Array:
	var body_points := PackedVector2Array(top_points)
	for i in range(top_points.size() - 1, -1, -1):
		var top_point: Vector2 = top_points[i]
		body_points.append(Vector2(top_point.x, max(mat_bottom, top_point.y + MAT_MIN_FABRIC_THICKNESS)))
	return body_points


func _draw_springs(canvas: CanvasItem, center: Vector2, half_width: float, mat_bottom: float) -> void:
	for i in range(4):
		var ratio: float = (float(i) + 0.5) / 4.0
		var x: float = center.x - half_width + ratio * half_width * 2.0
		canvas.draw_circle(Vector2(x, mat_bottom + 2.0), 2.0, SPRING_COLOR)


func _draw_bounce_pips(
	canvas: CanvasItem,
	trampoline: Dictionary,
	center: Vector2,
	half_width: float,
	mat_top: float
) -> void:
	if half_width < 10.0:
		return
	var max_bounces: int = ActiveItemTrampolineRuntime.TRAMPOLINE_MAX_BOUNCES
	var bounce_count: int = clamp(int(trampoline.get("bounce_count", 0)), 0, max_bounces)
	var pip_gap: float = 10.0
	var first_x: float = center.x - pip_gap * (float(max_bounces) - 1.0) * 0.5
	var pip_y: float = mat_top - 8.0
	for i in range(max_bounces):
		var pip_color: Color = PIP_REMAINING_COLOR if i < max_bounces - bounce_count else PIP_USED_COLOR
		canvas.draw_circle(Vector2(first_x + pip_gap * float(i), pip_y), 2.4, pip_color)


func _draw_particle(canvas: CanvasItem, particle: Dictionary, shake_offset: Vector2) -> void:
	var initial_frames: float = max(0.001, float(particle.get("initial_frames", 1.0)))
	var alpha: float = clamp(float(particle.get("timer_frames", 0.0)) / initial_frames, 0.0, 1.0)
	if alpha <= 0.01:
		return
	var position: Vector2 = _get_vector2(particle, "position") + shake_offset
	var radius: float = max(0.5, float(particle.get("radius", 2.0)))
	var fallback_color := Color(0.42, 0.86, 1.0)
	var color: Color = _get_color(particle.get("color", fallback_color), fallback_color)
	canvas.draw_circle(position, radius * 1.6, Color(color.r, color.g, color.b, alpha * 0.25))
	canvas.draw_circle(position, radius, Color(color.r, color.g, color.b, alpha))


func _get_spawn_scale(spawn_timer_frames: float) -> float:
	if spawn_timer_frames <= 0.0:
		return 1.0
	var progress: float = clamp(1.0 - spawn_timer_frames / ActiveItemTrampolineRuntime.TRAMPOLINE_SPAWN_FRAMES, 0.0, 1.0)
	var back: float = progress - 1.0
	var eased: float = 1.0 + 2.70158 * back * back * back + 1.70158 * back * back
	return clamp(0.2 + 0.8 * eased, 0.2, 1.12)


# Deflection source priority: while the slingshot capture is stretching the
# mat (or relaxing after an aborted capture), the mat follows the ball depth;
# once the launch arms bounce_timer_frames, the rebound oscillation takes
# over, starting with an upward snap.
func _get_mat_deflection(trampoline: Dictionary) -> float:
	var capture_depth: float = float(trampoline.get("capture_depth", 0.0))
	var bounce_timer: float = float(trampoline.get("bounce_timer_frames", 0.0))
	if bool(trampoline.get("capture_active", false)) or (capture_depth > 0.1 and bounce_timer <= 0.0):
		return clamp(capture_depth, 0.0, MAT_MAX_CAPTURE_SAG)
	return _get_bounce_deflection(bounce_timer)


func _get_stretch_sheet_frame_index(trampoline: Dictionary) -> int:
	var capture_depth: float = float(trampoline.get("capture_depth", 0.0))
	var bounce_timer: float = float(trampoline.get("bounce_timer_frames", 0.0))
	if bool(trampoline.get("capture_active", false)) or (capture_depth > 0.1 and bounce_timer <= 0.0):
		var capture_ratio: float = clamp(
			capture_depth / ActiveItemTrampolineRuntime.CAPTURE_MAX_SINK_DEPTH,
			0.0,
			1.0
		)
		return clamp(int(round(lerp(0.0, 8.0, capture_ratio))), 0, 8)
	if bounce_timer > 0.0:
		var rebound_progress: float = clamp(
			1.0 - bounce_timer / ActiveItemTrampolineRuntime.TRAMPOLINE_BOUNCE_ANIM_FRAMES,
			0.0,
			1.0
		)
		return clamp(9 + int(floor(rebound_progress * 7.0)), 9, STRETCH_SHEET_FRAME_COUNT - 1)
	return -1


func _get_stretch_sheet_source_rect(sheet: Texture2D, frame_index: int) -> Rect2:
	if sheet == null or sheet.get_width() <= 0 or sheet.get_height() <= 0:
		return Rect2()
	var clamped_index: int = clamp(frame_index, 0, STRETCH_SHEET_FRAME_COUNT - 1)
	var frame_width: float = float(sheet.get_width()) / float(STRETCH_SHEET_COLUMNS)
	var frame_height: float = float(sheet.get_height()) / float(STRETCH_SHEET_ROWS)
	var column: int = clamped_index % STRETCH_SHEET_COLUMNS
	var row: int = int(floor(float(clamped_index) / float(STRETCH_SHEET_COLUMNS)))
	return Rect2(
		Vector2(float(column) * frame_width, float(row) * frame_height),
		Vector2(frame_width, frame_height)
	)


func _get_bounce_deflection(bounce_timer_frames: float) -> float:
	if bounce_timer_frames <= 0.0:
		return 0.0
	var progress: float = clamp(1.0 - bounce_timer_frames / ActiveItemTrampolineRuntime.TRAMPOLINE_BOUNCE_ANIM_FRAMES, 0.0, 1.0)
	var envelope: float = pow(1.0 - progress, 1.4)
	var oscillation: float = cos(progress * PI * 2.6)
	var deflection: float = -envelope * oscillation * MAT_MAX_SAG
	if deflection > 0.0:
		deflection *= MAT_OVERSHOOT_SCALE
	return deflection


func _get_array(source: Dictionary, key: String) -> Array:
	var value: Variant = source.get(key, [])
	if value is Array:
		return value
	return []


func _get_rect2(source: Dictionary, key: String) -> Rect2:
	var value: Variant = source.get(key, Rect2())
	if value is Rect2:
		return value
	return Rect2()


func _get_vector2(source: Dictionary, key: String) -> Vector2:
	var value: Variant = source.get(key, Vector2.ZERO)
	if value is Vector2:
		return value
	return Vector2.ZERO


func _get_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback


func _touch_texture(texture: Texture2D) -> void:
	if texture != null:
		texture.get_size()
