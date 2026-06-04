extends RefCounted

const DRIVE_TITLE_FONT: Font = preload("res://assets/fonts/NanumSquareB.ttf")
const DRIVE_TITLE_TEXT := "드라이브"
const DRIVE_COLOR := Color(0.22, 0.95, 1.0)
const DRIVE_ACCENT_HOT := Color(1.0, 0.78, 0.24)
const DRIVE_CHARACTER_PATH := "res://assets/ui/skill_cutin/drive/drive_cutin_character.png"
const DRIVE_BACKPLATE_PATH := "res://assets/ui/skill_cutin/drive/drive_cutin_backplate.png"
const DRIVE_ARC_PATH := "res://assets/ui/skill_cutin/drive/drive_cutin_arc.png"
const DRIVE_TRIANGLE_TOP_LEFT := Vector2(0.000, -0.045)
const DRIVE_TRIANGLE_TOP_RIGHT := Vector2(0.360, -0.030)
const DRIVE_TRIANGLE_BOTTOM_LEFT := Vector2(0.000, 0.485)
const DRIVE_BACKPLATE_SIZE_RATIO := 0.34
const DRIVE_BACKPLATE_CENTER_Y_RATIO := 0.15
const DRIVE_ARC_SIZE_RATIO := 0.30
const DRIVE_ARC_CENTER_Y_RATIO := 0.14
const DRIVE_ARC_SPIN_SPEED := 0.55
const DRIVE_SLIDE_DISTANCE_RATIO := 0.55
const DRIVE_PORTRAIT_HEIGHT_RATIO := 0.30
const DRIVE_PORTRAIT_CENTER_X_RATIO := 0.075
const DRIVE_PORTRAIT_CENTER_Y_RATIO := 0.135
const DRIVE_PORTRAIT_CHAR_CENTER := Vector2(0.30, 0.26)
const DRIVE_VFX_CENTER_X_RATIO := 0.17
const SKILL_DRIVE := "drive"


static func draw_drive_cutin(
	canvas: CanvasItem,
	drive_cutin_state: Object,
	view_size: Vector2,
	texture_getter: Callable,
	material_getter: Callable,
	title_getter: Callable,
	fit_title_font_size: Callable
) -> void:
	if canvas == null:
		return
	if drive_cutin_state == null or not drive_cutin_state.has_method("is_active") or not bool(drive_cutin_state.is_active()):
		return
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		return
	var progress: float = 0.0
	if drive_cutin_state.has_method("get_progress"):
		progress = clampf(float(drive_cutin_state.get_progress()), 0.0, 1.0)
	var alpha: float = drive_alpha(progress)
	if alpha <= 0.0:
		return
	var slide_px: float = compute_drive_slide_px(progress, view_size.x)
	var enraged: bool = drive_cutin_state.has_method("is_enraged") and bool(drive_cutin_state.is_enraged())
	_draw_drive_triangle_panel(canvas, view_size, progress, alpha, slide_px)
	_draw_drive_backplate(canvas, view_size, progress, alpha, slide_px, texture_getter, material_getter, enraged)
	_draw_drive_arc(canvas, view_size, alpha, slide_px, texture_getter, material_getter, enraged)
	_draw_drive_portrait(canvas, view_size, progress, alpha, slide_px, texture_getter)
	_draw_drive_title(canvas, view_size, progress, alpha, slide_px, title_getter, fit_title_font_size)


static func compute_drive_slide_px(progress: float, view_width: float) -> float:
	return -drive_slide_ratio(clampf(progress, 0.0, 1.0)) * view_width * DRIVE_SLIDE_DISTANCE_RATIO


static func drive_slide_ratio(progress: float) -> float:
	if progress < 0.12:
		return 1.0 - _ease_out_cubic(clampf(progress / 0.12, 0.0, 1.0))
	if progress < 0.58:
		return 0.0
	return _ease_in_out(clampf((progress - 0.58) / 0.42, 0.0, 1.0))


static func drive_alpha(progress: float) -> float:
	if progress < 0.10:
		return clampf(progress / 0.10, 0.0, 1.0)
	if progress < 0.80:
		return 1.0
	return clampf((1.0 - progress) / 0.20, 0.0, 1.0)


static func drive_impact_punch(progress: float) -> float:
	var punch_in: float = _ease_out_cubic(clampf(progress / 0.12, 0.0, 1.0))
	var punch_out: float = 1.0 - _ease_out_cubic(clampf((progress - 0.12) / 0.18, 0.0, 1.0))
	return 1.0 + 0.06 * punch_in * punch_out


static func drive_triangle_points(view_size: Vector2, slide_px: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(view_size.x * DRIVE_TRIANGLE_TOP_LEFT.x + slide_px, view_size.y * DRIVE_TRIANGLE_TOP_LEFT.y),
		Vector2(view_size.x * DRIVE_TRIANGLE_TOP_RIGHT.x + slide_px, view_size.y * DRIVE_TRIANGLE_TOP_RIGHT.y),
		Vector2(view_size.x * DRIVE_TRIANGLE_BOTTOM_LEFT.x + slide_px, view_size.y * DRIVE_TRIANGLE_BOTTOM_LEFT.y),
	])


static func expanded_drive_polygon(points: PackedVector2Array, amount: float) -> PackedVector2Array:
	if points.is_empty() or absf(amount) <= 0.01:
		return points
	var center := Vector2.ZERO
	for p in points:
		center += p
	center /= float(points.size())
	var expanded := PackedVector2Array()
	for p in points:
		var dir := p - center
		if dir.length_squared() <= 0.001:
			expanded.push_back(p)
		else:
			expanded.push_back(p + dir.normalized() * amount)
	return expanded


static func should_draw_drive_edge_flames(from_point: Vector2, to_point: Vector2) -> bool:
	return absf(from_point.x - to_point.x) > 0.01


static func _draw_drive_triangle_panel(canvas: CanvasItem, view_size: Vector2, progress: float, alpha: float, slide_px: float) -> void:
	var points: PackedVector2Array = drive_triangle_points(view_size, slide_px)
	var pulse: float = 0.5 + 0.5 * sin(progress * TAU * 2.1 + float(Time.get_ticks_msec()) * 0.004)
	var fill_alpha: float = alpha * lerpf(0.44, 0.58, pulse)
	var glow_alpha: float = alpha * lerpf(0.16, 0.24, pulse)
	var shadow_points: PackedVector2Array = expanded_drive_polygon(points, view_size.y * 0.018)
	canvas.draw_colored_polygon(shadow_points, Color(DRIVE_COLOR.r, DRIVE_COLOR.g, DRIVE_COLOR.b, glow_alpha))
	canvas.draw_colored_polygon(points, Color(0.01, 0.58, 0.56, fill_alpha))
	var inner_points: PackedVector2Array = expanded_drive_polygon(points, -view_size.y * 0.018)
	canvas.draw_colored_polygon(inner_points, Color(DRIVE_COLOR.r, DRIVE_COLOR.g, DRIVE_COLOR.b, alpha * 0.12))
	_draw_drive_triangle_edge_flames(canvas, points, progress, alpha)


static func _draw_drive_triangle_edge_flames(canvas: CanvasItem, points: PackedVector2Array, progress: float, alpha: float) -> void:
	if points.size() < 3:
		return
	var center := Vector2.ZERO
	for p in points:
		center += p
	center /= float(points.size())
	var time_sec: float = float(Time.get_ticks_msec()) / 1000.0
	for i in points.size():
		var from_point: Vector2 = points[i]
		var to_point: Vector2 = points[(i + 1) % points.size()]
		_draw_drive_flame_edge(canvas, from_point, to_point, center, time_sec, progress, alpha, i)


static func _draw_drive_flame_edge(
	canvas: CanvasItem,
	from_point: Vector2,
	to_point: Vector2,
	center: Vector2,
	time_sec: float,
	progress: float,
	alpha: float,
	edge_index: int
) -> void:
	var edge := to_point - from_point
	var edge_len: float = edge.length()
	if edge_len <= 1.0:
		return
	if not should_draw_drive_edge_flames(from_point, to_point):
		canvas.draw_line(from_point, to_point, Color(1.0, 1.0, 1.0, alpha * 0.20), 1.2, true)
		return
	var tangent: Vector2 = edge / edge_len
	var normal := Vector2(tangent.y, -tangent.x)
	var midpoint := (from_point + to_point) * 0.5
	if normal.dot(midpoint - center) < 0.0:
		normal = -normal
	var segment_count := 14
	var cyan_edge := PackedVector2Array()
	var hot_edge := PackedVector2Array()
	var base_push: float = minf(11.0, edge_len * 0.025)
	for s in segment_count + 1:
		var t: float = float(s) / float(segment_count)
		var wave_a: float = sin(time_sec * 9.0 + t * TAU * 2.6 + float(edge_index) * 1.7)
		var wave_b: float = sin(time_sec * 15.0 - t * TAU * 4.1 + progress * TAU)
		var lick: float = maxf(0.0, wave_a * 0.55 + wave_b * 0.45)
		var offset: float = base_push + lick * minf(18.0, edge_len * 0.040)
		var along_jitter: float = sin(time_sec * 11.0 + t * TAU * 3.0 + float(edge_index)) * edge_len * 0.006
		var base_point: Vector2 = from_point.lerp(to_point, t) + tangent * along_jitter
		cyan_edge.push_back(base_point + normal * offset)
		hot_edge.push_back(base_point + normal * (offset * 0.58))
		if s > 0 and s < segment_count and s % 2 == edge_index % 2:
			var spike_len: float = minf(20.0, edge_len * 0.045) * (0.35 + lick)
			canvas.draw_line(
				base_point + normal * (offset * 0.45),
				base_point + normal * (offset + spike_len),
				Color(DRIVE_ACCENT_HOT.r, DRIVE_ACCENT_HOT.g, DRIVE_ACCENT_HOT.b, alpha * (0.18 + 0.16 * lick)),
				2.0,
				true
			)
	canvas.draw_polyline(cyan_edge, Color(DRIVE_COLOR.r, DRIVE_COLOR.g, DRIVE_COLOR.b, alpha * 0.34), 6.0, true)
	canvas.draw_polyline(hot_edge, Color(DRIVE_ACCENT_HOT.r, DRIVE_ACCENT_HOT.g, DRIVE_ACCENT_HOT.b, alpha * 0.42), 2.4, true)
	canvas.draw_line(from_point, to_point, Color(1.0, 1.0, 1.0, alpha * 0.20), 1.2, true)


static func _draw_drive_backplate(
	canvas: CanvasItem,
	view_size: Vector2,
	progress: float,
	alpha: float,
	slide_px: float,
	texture_getter: Callable,
	material_getter: Callable,
	enraged: bool = false
) -> void:
	var texture: Texture2D = _get_texture(texture_getter, DRIVE_BACKPLATE_PATH)
	if texture == null:
		return
	var a: float = alpha * 0.9
	if a <= 0.01:
		return
	var size: float = view_size.y * DRIVE_BACKPLATE_SIZE_RATIO
	var center := Vector2(view_size.x * DRIVE_VFX_CENTER_X_RATIO + slide_px, view_size.y * DRIVE_BACKPLATE_CENTER_Y_RATIO)
	var rect := Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size))
	_draw_drive_shaded_texture(canvas, texture, rect, a, 1.0 + 0.12 * sin(progress * TAU * 1.3), material_getter, enraged)


static func _draw_drive_arc(
	canvas: CanvasItem,
	view_size: Vector2,
	alpha: float,
	slide_px: float,
	texture_getter: Callable,
	material_getter: Callable,
	enraged: bool = false
) -> void:
	var texture: Texture2D = _get_texture(texture_getter, DRIVE_ARC_PATH)
	if texture == null:
		return
	var a: float = alpha * 0.82
	if a <= 0.01:
		return
	var size: float = view_size.y * DRIVE_ARC_SIZE_RATIO
	var center := Vector2(view_size.x * DRIVE_VFX_CENTER_X_RATIO + slide_px, view_size.y * DRIVE_ARC_CENTER_Y_RATIO)
	var angle: float = float(Time.get_ticks_msec()) / 1000.0 * DRIVE_ARC_SPIN_SPEED
	var h: float = size * 0.5
	var ca: float = cos(angle)
	var sa: float = sin(angle)
	var corners := [Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]
	var pts := PackedVector2Array()
	for c in corners:
		pts.push_back(center + Vector2(c.x * ca - c.y * sa, c.x * sa + c.y * ca))
	var uvs := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	var mat: ShaderMaterial = _get_material(material_getter, enraged)
	if mat != null:
		mat.set_shader_parameter("elapsed", float(Time.get_ticks_msec()) / 1000.0)
		mat.set_shader_parameter("intensity", 1.0)
		var prev: Material = canvas.material
		canvas.material = mat
		canvas.draw_colored_polygon(pts, Color(1.0, 1.0, 1.0, a), uvs, texture)
		canvas.material = prev
	else:
		canvas.draw_colored_polygon(pts, Color(1.0, 1.0, 1.0, a), uvs, texture)


static func _draw_drive_shaded_texture(
	canvas: CanvasItem,
	texture: Texture2D,
	rect: Rect2,
	alpha: float,
	intensity: float,
	material_getter: Callable,
	enraged: bool = false
) -> void:
	var mat: ShaderMaterial = _get_material(material_getter, enraged)
	if mat == null:
		canvas.draw_texture_rect(texture, rect, false, Color(1.0, 1.0, 1.0, alpha))
		return
	mat.set_shader_parameter("elapsed", float(Time.get_ticks_msec()) / 1000.0)
	mat.set_shader_parameter("intensity", intensity)
	var prev: Material = canvas.material
	canvas.material = mat
	canvas.draw_texture_rect(texture, rect, false, Color(1.0, 1.0, 1.0, alpha))
	canvas.material = prev


static func _draw_drive_portrait(
	canvas: CanvasItem,
	view_size: Vector2,
	progress: float,
	alpha: float,
	slide_px: float,
	texture_getter: Callable
) -> void:
	var texture: Texture2D = _get_texture(texture_getter, DRIVE_CHARACTER_PATH)
	if texture == null:
		return
	var tex_size: Vector2 = texture.get_size()
	if tex_size.x <= 1.0 or tex_size.y <= 1.0:
		return
	var draw_h: float = view_size.y * DRIVE_PORTRAIT_HEIGHT_RATIO * drive_impact_punch(progress)
	var scale: float = draw_h / tex_size.y
	var draw_size := Vector2(tex_size.x * scale, draw_h)
	var char_center := Vector2(
		view_size.x * DRIVE_PORTRAIT_CENTER_X_RATIO + slide_px,
		view_size.y * DRIVE_PORTRAIT_CENTER_Y_RATIO + sin(progress * TAU * 1.5) * view_size.y * 0.006
	)
	var pos: Vector2 = char_center - DRIVE_PORTRAIT_CHAR_CENTER * draw_size
	canvas.draw_texture_rect(texture, Rect2(pos, draw_size), false, Color(1.0, 1.0, 1.0, alpha))


static func _draw_drive_title(
	canvas: CanvasItem,
	view_size: Vector2,
	progress: float,
	alpha: float,
	slide_px: float,
	title_getter: Callable,
	fit_title_font_size: Callable
) -> void:
	var reveal: float = clampf((progress - 0.14) / 0.12, 0.0, 1.0)
	var title_alpha: float = alpha * reveal
	if title_alpha <= 0.01:
		return
	var title_text: String = str(title_getter.call(SKILL_DRIVE, DRIVE_TITLE_TEXT))
	var size_px: int = int(fit_title_font_size.call(DRIVE_TITLE_FONT, title_text, max(12, int(view_size.y * 0.056)), view_size.x * 0.42))
	var text_dim: Vector2 = DRIVE_TITLE_FONT.get_string_size(title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px)
	var slide_in: float = lerpf(view_size.x * 0.05, 0.0, _ease_out_cubic(reveal))
	var base := Vector2(view_size.x * 0.04 + slide_px + slide_in, view_size.y * 0.385)
	var bar_rect := Rect2(
		base.x - view_size.x * 0.012,
		base.y + view_size.y * 0.012,
		text_dim.x + view_size.x * 0.024,
		maxf(3.0, view_size.y * 0.008)
	)
	canvas.draw_rect(bar_rect, Color(DRIVE_COLOR.r, DRIVE_COLOR.g, DRIVE_COLOR.b, title_alpha))
	canvas.draw_string(DRIVE_TITLE_FONT, base + Vector2(3, 3), title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(0.0, 0.0, 0.0, 0.55 * title_alpha))
	canvas.draw_string(DRIVE_TITLE_FONT, base, title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(1.0, 1.0, 1.0, title_alpha))


static func _get_texture(texture_getter: Callable, path: String) -> Texture2D:
	if not texture_getter.is_valid():
		return null
	var value: Variant = texture_getter.call(path)
	if value is Texture2D:
		return value
	return null


static func _get_material(material_getter: Callable, enraged: bool) -> ShaderMaterial:
	if not material_getter.is_valid():
		return null
	var value: Variant = material_getter.call(enraged)
	if value is ShaderMaterial:
		return value
	return null


static func _ease_out_cubic(t: float) -> float:
	var c: float = clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - c, 3.0)


static func _ease_in_out(t: float) -> float:
	var c: float = clampf(t, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)
