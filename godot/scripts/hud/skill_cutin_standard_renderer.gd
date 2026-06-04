extends RefCounted

const POWER_SMASHING_CUTIN_SHEET_PATH := "res://assets/ui/skill_cutin/smasher_power_smashing_cutin_sheet.png"
const CUTIN_FRAME_COUNT := 16
const WIPE_COLOR := Color(1.0, 100.0 / 255.0, 50.0 / 255.0, 0.85)
const FLASH_COLOR := Color(1.0, 0.88, 0.7, 1.0)
const POWER_SMASHING_COLOR := Color(1.0, 100.0 / 255.0, 50.0 / 255.0)
const CHARGE_CORE_COLOR := Color(1.0, 0.12, 0.05, 1.0)
const CHARGE_HOT_COLOR := Color(1.0, 0.55, 0.16, 1.0)
const DIM_ALPHA_MAX := 0.6
const SPEED_LINE_COUNT := 24
const SPEED_LINE_ALPHA := 0.2


static func draw(
	canvas: CanvasItem,
	view_size: Vector2,
	progress: float,
	phase: String,
	profile: Dictionary,
	texture_getter: Callable,
	grid_getter: Callable,
	title_getter: Callable,
	fit_title_font_size: Callable
) -> void:
	_draw_dim(canvas, view_size, progress, phase)
	_draw_wipe(canvas, view_size, progress, phase, profile)
	_draw_speed_lines(canvas, view_size, progress, phase, profile)
	_draw_cutin_sheet(canvas, view_size, progress, phase, profile, texture_getter, grid_getter)
	_draw_title_text(canvas, view_size, progress, phase, profile, title_getter, fit_title_font_size)
	_draw_flash(canvas, view_size, progress, phase, profile)


static func _draw_dim(canvas: CanvasItem, view_size: Vector2, progress: float, phase: String) -> void:
	var alpha: float = 0.0
	if phase == "wipe":
		alpha = lerpf(0.0, DIM_ALPHA_MAX, progress / 0.11)
	elif phase in ["main", "text"]:
		alpha = DIM_ALPHA_MAX
	elif phase == "flash":
		var flash_local: float = (progress - 0.82) / 0.18
		alpha = lerpf(DIM_ALPHA_MAX, 0.0, flash_local)
	if alpha <= 0.0:
		return
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, alpha))


static func _draw_wipe(
	canvas: CanvasItem,
	view_size: Vector2,
	progress: float,
	phase: String,
	profile: Dictionary
) -> void:
	if phase != "wipe":
		return
	var wipe_progress: float = clampf(progress / 0.11, 0.0, 1.0)
	var width: float = view_size.x * 0.12
	var sweep_x: float = lerpf(-width, view_size.x + width, wipe_progress)

	var points: PackedVector2Array = PackedVector2Array([
		Vector2(sweep_x - width, 0.0),
		Vector2(sweep_x, 0.0),
		Vector2(sweep_x - width * 0.3, view_size.y),
		Vector2(sweep_x - width * 1.3, view_size.y),
	])
	var wipe_color: Color = profile.get("wipe_color", WIPE_COLOR)
	canvas.draw_colored_polygon(points, wipe_color)


static func _draw_speed_lines(
	canvas: CanvasItem,
	view_size: Vector2,
	progress: float,
	phase: String,
	profile: Dictionary
) -> void:
	if phase not in ["main", "text"]:
		return
	var center: Vector2 = view_size * 0.5
	var max_radius: float = view_size.length() * 0.55
	var phase_local: float = (progress - 0.11) / 0.62
	var alpha: float = SPEED_LINE_ALPHA * clampf(phase_local * 3.0, 0.0, 1.0)
	var line_color: Color = profile.get("speed_line_color", Color.WHITE)

	for i in SPEED_LINE_COUNT:
		var angle: float = (float(i) / float(SPEED_LINE_COUNT)) * TAU
		var inner_r: float = max_radius * 0.35
		var outer_r: float = max_radius * (0.7 + 0.3 * sin(angle * 3.0 + progress * 20.0))
		var p_inner: Vector2 = center + Vector2(cos(angle), sin(angle)) * inner_r
		var p_outer: Vector2 = center + Vector2(cos(angle), sin(angle)) * outer_r
		canvas.draw_line(p_inner, p_outer, Color(line_color.r, line_color.g, line_color.b, alpha), 1.5)


static func _draw_cutin_sheet(
	canvas: CanvasItem,
	view_size: Vector2,
	progress: float,
	phase: String,
	profile: Dictionary,
	texture_getter: Callable,
	grid_getter: Callable
) -> void:
	var sheet_path: String = str(profile.get("sheet_path", POWER_SMASHING_CUTIN_SHEET_PATH))
	var cutin_sheet_texture := _get_texture(texture_getter, sheet_path)
	if cutin_sheet_texture == null:
		return
	if phase not in ["main", "text", "flash"]:
		return
	var source: Rect2 = _cutin_source_rect(cutin_sheet_texture, sheet_path, progress, grid_getter)
	if source.size.x <= 1.0 or source.size.y <= 1.0:
		return
	var target_bounds := Rect2(
		Vector2(view_size.x * 0.05, view_size.y * 0.02),
		Vector2(view_size.x * 0.90, view_size.y * 0.74)
	)
	var draw_rect: Rect2 = _fit_region_rect(source.size, target_bounds)
	var main_local: float = clampf((progress - 0.11) / 0.16, 0.0, 1.0)
	var ease_in: float = 1.0 - pow(1.0 - main_local, 3.0)
	draw_rect.position.x += lerpf(view_size.x * 0.08, 0.0, ease_in)
	draw_rect.position.y += sin(progress * TAU * 2.0) * view_size.y * 0.004
	var alpha: float = clampf(main_local * 1.4, 0.0, 1.0)
	if phase == "flash":
		var flash_local: float = clampf((progress - 0.82) / 0.18, 0.0, 1.0)
		alpha = lerpf(1.0, 0.0, flash_local)
	var sheet_modulate: Color = profile.get("sheet_modulate", Color.WHITE)
	canvas.draw_texture_rect_region(
		cutin_sheet_texture,
		draw_rect,
		source,
		Color(sheet_modulate.r, sheet_modulate.g, sheet_modulate.b, alpha * sheet_modulate.a),
		false,
		true
	)
	if bool(profile.get("ghost_wisps", false)):
		_draw_ghost_cutin_wisps(canvas, draw_rect, progress, phase, alpha)
	_draw_skill_charge_aura(canvas, draw_rect, progress, phase, alpha, profile)


static func _cutin_source_rect(
	texture: Texture2D,
	sheet_path: String,
	progress: float,
	grid_getter: Callable
) -> Rect2:
	if texture == null:
		return Rect2()
	var texture_size: Vector2 = texture.get_size()
	var grid: Vector2i = _get_grid(grid_getter, sheet_path)
	var columns: int = max(1, grid.x)
	var rows: int = max(1, grid.y)
	var cell_size := Vector2(texture_size.x / float(columns), texture_size.y / float(rows))
	if cell_size.x <= 1.0 or cell_size.y <= 1.0:
		return Rect2()
	var frame_index: int = _cutin_frame_index(progress)
	var col: int = frame_index % columns
	var row: int = int(floor(float(frame_index) / float(columns)))
	return Rect2(Vector2(cell_size.x * float(col), cell_size.y * float(row)), cell_size)


static func _cutin_frame_index(progress: float) -> int:
	var local: float = clampf((progress - 0.11) / 0.71, 0.0, 0.999)
	return clampi(int(floor(local * float(CUTIN_FRAME_COUNT))), 0, CUTIN_FRAME_COUNT - 1)


static func _draw_skill_charge_aura(
	canvas: CanvasItem,
	draw_rect: Rect2,
	progress: float,
	phase: String,
	base_alpha: float,
	profile: Dictionary
) -> void:
	if phase not in ["main", "text", "flash"]:
		return
	var frame_index: int = _cutin_frame_index(progress)
	var center: Vector2 = draw_rect.position + draw_rect.size * _charge_point_ratio(frame_index, profile)
	var charge: float = clampf((progress - 0.13) / 0.58, 0.0, 1.0)
	var release: float = clampf((progress - 0.72) / 0.16, 0.0, 1.0)
	var flash_fade: float = 1.0
	if phase == "flash":
		flash_fade = 1.0 - clampf((progress - 0.82) / 0.18, 0.0, 1.0)
	var alpha: float = base_alpha * flash_fade * (0.30 + charge * 0.70)
	if alpha <= 0.01:
		return
	var charge_core_color: Color = profile.get("charge_core_color", CHARGE_CORE_COLOR)
	var charge_hot_color: Color = profile.get("charge_hot_color", CHARGE_HOT_COLOR)
	var base_radius: float = maxf(18.0, minf(draw_rect.size.x, draw_rect.size.y) * 0.040)
	var pulse: float = sin(progress * TAU * 7.0)
	var radius_boost: float = 1.0 + release * 0.85
	for ring_index in 3:
		var ring_t: float = float(ring_index) / 2.0
		var radius: float = base_radius * (1.0 + ring_t * 0.72 + pulse * 0.08) * radius_boost
		var width: float = maxf(2.0, base_radius * (0.10 + ring_t * 0.04))
		var ring_alpha: float = alpha * (0.46 - ring_t * 0.10)
		var offset: float = progress * TAU * (1.7 + ring_t)
		var color: Color = charge_core_color.lerp(charge_hot_color, ring_t)
		canvas.draw_arc(center, radius, offset, offset + TAU * 0.72, 48, Color(color.r, color.g, color.b, ring_alpha), width, true)
		canvas.draw_arc(center, radius * 0.72, -offset * 0.8, -offset * 0.8 + TAU * 0.52, 40, Color(charge_hot_color.r, charge_hot_color.g, charge_hot_color.b, ring_alpha * 0.65), maxf(1.0, width * 0.55), true)
	for spark_index in 14:
		var spark_t: float = float(spark_index) / 14.0
		var angle: float = spark_t * TAU + progress * TAU * (2.2 + float(spark_index % 3) * 0.18)
		var outer: float = base_radius * lerpf(3.1, 1.45, charge) * (1.0 + 0.18 * sin(progress * 19.0 + float(spark_index)))
		var inner: float = base_radius * (0.48 + 0.14 * sin(progress * 11.0 + float(spark_index)))
		var from_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * outer
		var to_pos: Vector2 = center + Vector2(cos(angle + 0.25), sin(angle + 0.25)) * inner
		var spark_alpha: float = alpha * (0.25 + 0.35 * sin(spark_t * PI))
		canvas.draw_line(from_pos, to_pos, Color(charge_hot_color.r, charge_hot_color.g, charge_hot_color.b, spark_alpha), maxf(1.0, base_radius * 0.05), true)
	canvas.draw_circle(center, base_radius * (0.42 + release * 0.25), Color(charge_core_color.r, charge_core_color.g, charge_core_color.b, alpha * 0.38))
	canvas.draw_circle(center, base_radius * (0.20 + release * 0.22), Color(charge_hot_color.r, charge_hot_color.g, charge_hot_color.b, alpha * 0.48))


static func _draw_ghost_cutin_wisps(
	canvas: CanvasItem,
	draw_rect: Rect2,
	progress: float,
	phase: String,
	base_alpha: float
) -> void:
	if phase not in ["main", "text", "flash"]:
		return
	var flash_fade: float = 1.0
	if phase == "flash":
		flash_fade = 1.0 - clampf((progress - 0.82) / 0.18, 0.0, 1.0)
	var alpha: float = base_alpha * flash_fade * clampf((progress - 0.13) / 0.22, 0.0, 1.0)
	if alpha <= 0.01:
		return
	var center: Vector2 = draw_rect.get_center()
	var base_radius: float = minf(draw_rect.size.x, draw_rect.size.y) * 0.08
	for wisp_index in 9:
		var t: float = float(wisp_index) / 9.0
		var angle: float = t * TAU + progress * TAU * 1.35
		var orbit: Vector2 = Vector2(cos(angle), sin(angle * 1.4)) * draw_rect.size * Vector2(0.36, 0.20)
		var pos: Vector2 = center + orbit + Vector2(0.0, sin(progress * TAU * 4.0 + t * TAU) * draw_rect.size.y * 0.035)
		var local_radius: float = base_radius * (0.45 + 0.25 * sin(progress * TAU * 5.0 + t * TAU))
		var local_alpha: float = alpha * (0.12 + 0.13 * sin(t * PI))
		canvas.draw_circle(pos, local_radius * 1.25, Color(0.18, 0.02, 0.28, local_alpha * 0.75))
		canvas.draw_arc(
			pos,
			local_radius,
			angle + PI * 0.2,
			angle + PI * 1.25,
			24,
			Color(0.72, 0.42, 1.0, local_alpha),
			maxf(1.0, local_radius * 0.08),
			true
		)


static func _charge_point_ratio(frame_index: int, profile: Dictionary = {}) -> Vector2:
	var profile_points: Variant = profile.get("charge_points", [])
	if profile_points is Array and not profile_points.is_empty():
		var points: Array = profile_points
		var index: int = clampi(frame_index, 0, points.size() - 1)
		var point: Variant = points[index]
		if point is Vector2:
			return point
	match clampi(frame_index, 0, CUTIN_FRAME_COUNT - 1):
		0:
			return Vector2(0.39, 0.51)
		1:
			return Vector2(0.40, 0.51)
		2:
			return Vector2(0.40, 0.50)
		3:
			return Vector2(0.40, 0.50)
		4:
			return Vector2(0.41, 0.50)
		5:
			return Vector2(0.41, 0.50)
		6:
			return Vector2(0.41, 0.49)
		7:
			return Vector2(0.41, 0.45)
		8:
			return Vector2(0.53, 0.48)
		9:
			return Vector2(0.55, 0.54)
		10:
			return Vector2(0.48, 0.60)
		11:
			return Vector2(0.46, 0.63)
		12:
			return Vector2(0.47, 0.63)
		13:
			return Vector2(0.47, 0.63)
		14:
			return Vector2(0.47, 0.63)
	return Vector2(0.48, 0.63)


static func _draw_title_text(
	canvas: CanvasItem,
	view_size: Vector2,
	progress: float,
	phase: String,
	profile: Dictionary,
	title_getter: Callable,
	fit_title_font_size: Callable
) -> void:
	if phase not in ["text", "flash"]:
		return
	var text_alpha: float = 1.0
	if phase == "text":
		var text_local: float = (progress - 0.73) / 0.09
		text_alpha = clampf(text_local, 0.0, 1.0)
	elif phase == "flash":
		var flash_local: float = (progress - 0.82) / 0.18
		text_alpha = lerpf(1.0, 0.0, flash_local)
	if text_alpha <= 0.0:
		return

	var font: Font = ThemeDB.fallback_font
	var text: String = _get_title(title_getter, profile)
	var target_size := int(view_size.y * 0.065)
	var font_size: int = _fit_title_size(fit_title_font_size, font, text, target_size, view_size.x * 0.88)
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos: Vector2 = Vector2(
		(view_size.x - text_size.x) * 0.5,
		view_size.y * 0.78
	)

	var shadow_color := Color(0.0, 0.0, 0.0, 0.5 * text_alpha)
	canvas.draw_string(font, text_pos + Vector2(2, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shadow_color)

	var title_color: Color = profile.get("title_color", POWER_SMASHING_COLOR)
	var text_color := Color(title_color.r, title_color.g, title_color.b, text_alpha)
	canvas.draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)


static func _draw_flash(
	canvas: CanvasItem,
	view_size: Vector2,
	progress: float,
	phase: String,
	profile: Dictionary
) -> void:
	if phase != "flash":
		return
	var flash_local: float = (progress - 0.82) / 0.18
	var flash_alpha: float = lerpf(0.7, 0.0, flash_local)
	if flash_alpha <= 0.0:
		return
	var flash_color: Color = profile.get("flash_color", FLASH_COLOR)
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(flash_color, flash_alpha))


static func _fit_region_rect(source_size: Vector2, target: Rect2) -> Rect2:
	if source_size.x <= 1.0 or source_size.y <= 1.0 or target.size.x <= 1.0 or target.size.y <= 1.0:
		return Rect2(target.position, Vector2.ZERO)
	var scale_factor: float = minf(target.size.x / source_size.x, target.size.y / source_size.y)
	var draw_size: Vector2 = source_size * scale_factor
	return Rect2(target.position + (target.size - draw_size) * 0.5, draw_size)


static func _get_texture(texture_getter: Callable, path: String) -> Texture2D:
	if not texture_getter.is_valid():
		return null
	var value: Variant = texture_getter.call(path)
	if value is Texture2D:
		return value
	return null


static func _get_grid(grid_getter: Callable, path: String) -> Vector2i:
	if not grid_getter.is_valid():
		return Vector2i(4, 4)
	var value: Variant = grid_getter.call(path)
	if value is Vector2i:
		return value
	return Vector2i(4, 4)


static func _get_title(title_getter: Callable, profile: Dictionary) -> String:
	if not title_getter.is_valid():
		return str(profile.get("title", ""))
	return str(title_getter.call(profile))


static func _fit_title_size(
	fit_title_font_size: Callable,
	font: Font,
	text: String,
	target_size: int,
	max_width: float
) -> int:
	if not fit_title_font_size.is_valid():
		return max(12, target_size)
	return int(fit_title_font_size.call(font, text, target_size, max_width))
