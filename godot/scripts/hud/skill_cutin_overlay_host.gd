extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const CUTIN_SHEET_PATH := "res://assets/ui/skill_cutin/smasher_power_smashing_cutin_sheet.png"
const CUTIN_FRAME_COUNT := 16
const CUTIN_AUTOSPRITE_COLUMNS := 3
const CUTIN_STANDARD_COLUMNS := 4

const POWER_SMASHING_COLOR := Color(1.0, 100.0 / 255.0, 50.0 / 255.0)
const WIPE_COLOR := Color(1.0, 100.0 / 255.0, 50.0 / 255.0, 0.85)
const FLASH_COLOR := Color(1.0, 0.88, 0.7, 1.0)
const RIM_COLOR := Color(0.27, 0.87, 0.8, 0.6)
const CHARGE_CORE_COLOR := Color(1.0, 0.12, 0.05, 1.0)
const CHARGE_HOT_COLOR := Color(1.0, 0.55, 0.16, 1.0)
const DIM_ALPHA_MAX := 0.6
const SPEED_LINE_COUNT := 24
const SPEED_LINE_ALPHA := 0.2

var _prewarmed: bool = false
var _cutin_sheet_texture: Texture2D = null
var _cutin_sheet_columns: int = CUTIN_AUTOSPRITE_COLUMNS
var _cutin_sheet_rows: int = 3


func prewarm_assets() -> void:
	_prewarmed = true
	_cutin_sheet_texture = _load_cutin_sheet_texture()
	_refresh_sheet_grid()


func prewarm_runtime_nodes(_owner: Object = null) -> void:
	prewarm_assets()


func draw(canvas: CanvasItem, cutin_state: Object, view_size: Vector2) -> void:
	if canvas == null:
		return
	if cutin_state == null or not cutin_state.is_active():
		return

	var progress: float = cutin_state.get_progress()
	var phase: String = cutin_state.get_phase()

	_draw_dim(canvas, view_size, progress, phase)
	_draw_wipe(canvas, view_size, progress, phase)
	_draw_speed_lines(canvas, view_size, progress, phase)
	_draw_cutin_sheet(canvas, view_size, progress, phase)
	_draw_title_text(canvas, view_size, progress, phase)
	_draw_flash(canvas, view_size, progress, phase)


func _load_cutin_sheet_texture() -> Texture2D:
	if not FileAccess.file_exists(CUTIN_SHEET_PATH) and not FileAccess.file_exists("%s.import" % CUTIN_SHEET_PATH):
		return null
	return ProjectResourceLoader.load_texture(
		CUTIN_SHEET_PATH,
		"",
		"Failed to load Smasher power-smashing cut-in sheet: %s"
	)


func _refresh_sheet_grid() -> void:
	_cutin_sheet_columns = CUTIN_AUTOSPRITE_COLUMNS
	_cutin_sheet_rows = 3
	if _cutin_sheet_texture == null:
		return
	var texture_size: Vector2 = _cutin_sheet_texture.get_size()
	if texture_size.x <= 1.0 or texture_size.y <= 1.0:
		return
	if texture_size.x >= texture_size.y * 1.7:
		_cutin_sheet_columns = CUTIN_STANDARD_COLUMNS
		_cutin_sheet_rows = int(ceil(float(CUTIN_FRAME_COUNT) / float(_cutin_sheet_columns)))
	elif absf(texture_size.x - texture_size.y) <= maxf(texture_size.x, texture_size.y) * 0.05:
		_cutin_sheet_columns = CUTIN_STANDARD_COLUMNS
		_cutin_sheet_rows = CUTIN_STANDARD_COLUMNS
	else:
		_cutin_sheet_columns = CUTIN_AUTOSPRITE_COLUMNS
		_cutin_sheet_rows = int(ceil(float(CUTIN_FRAME_COUNT) / float(_cutin_sheet_columns)))


func _draw_dim(canvas: CanvasItem, view_size: Vector2, progress: float, phase: String) -> void:
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


func _draw_wipe(canvas: CanvasItem, view_size: Vector2, progress: float, phase: String) -> void:
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
	canvas.draw_colored_polygon(points, WIPE_COLOR)


func _draw_speed_lines(canvas: CanvasItem, view_size: Vector2, progress: float, phase: String) -> void:
	if phase not in ["main", "text"]:
		return
	var center: Vector2 = view_size * 0.5
	var max_radius: float = view_size.length() * 0.55
	var phase_local: float = (progress - 0.11) / 0.62
	var alpha: float = SPEED_LINE_ALPHA * clampf(phase_local * 3.0, 0.0, 1.0)

	for i in SPEED_LINE_COUNT:
		var angle: float = (float(i) / float(SPEED_LINE_COUNT)) * TAU
		var inner_r: float = max_radius * 0.35
		var outer_r: float = max_radius * (0.7 + 0.3 * sin(angle * 3.0 + progress * 20.0))
		var p_inner: Vector2 = center + Vector2(cos(angle), sin(angle)) * inner_r
		var p_outer: Vector2 = center + Vector2(cos(angle), sin(angle)) * outer_r
		canvas.draw_line(p_inner, p_outer, Color(1.0, 1.0, 1.0, alpha), 1.5)


func _draw_cutin_sheet(canvas: CanvasItem, view_size: Vector2, progress: float, phase: String) -> void:
	if _cutin_sheet_texture == null:
		return
	if phase not in ["main", "text", "flash"]:
		return
	var source: Rect2 = _cutin_source_rect(progress)
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
	var rim_rect := draw_rect.grow(view_size.y * 0.012)
	canvas.draw_rect(
		rim_rect,
		Color(RIM_COLOR.r, RIM_COLOR.g, RIM_COLOR.b, 0.10 * alpha),
		false,
		max(2.0, view_size.y * 0.008)
	)
	canvas.draw_texture_rect_region(
		_cutin_sheet_texture,
		draw_rect,
		source,
		Color(1.0, 1.0, 1.0, alpha),
		false,
		true
	)
	_draw_red_charge_aura(canvas, draw_rect, progress, phase, alpha)


func _cutin_source_rect(progress: float) -> Rect2:
	if _cutin_sheet_texture == null:
		return Rect2()
	var texture_size: Vector2 = _cutin_sheet_texture.get_size()
	var columns: int = max(1, _cutin_sheet_columns)
	var rows: int = max(1, _cutin_sheet_rows)
	var cell_size := Vector2(texture_size.x / float(columns), texture_size.y / float(rows))
	if cell_size.x <= 1.0 or cell_size.y <= 1.0:
		return Rect2()
	var frame_index: int = _cutin_frame_index(progress)
	var col: int = frame_index % columns
	var row: int = int(floor(float(frame_index) / float(columns)))
	return Rect2(Vector2(cell_size.x * float(col), cell_size.y * float(row)), cell_size)


func _cutin_frame_index(progress: float) -> int:
	var local: float = clampf((progress - 0.11) / 0.71, 0.0, 0.999)
	return clampi(int(floor(local * float(CUTIN_FRAME_COUNT))), 0, CUTIN_FRAME_COUNT - 1)


func _draw_red_charge_aura(
	canvas: CanvasItem,
	draw_rect: Rect2,
	progress: float,
	phase: String,
	base_alpha: float
) -> void:
	if phase not in ["main", "text", "flash"]:
		return
	var frame_index: int = _cutin_frame_index(progress)
	var center: Vector2 = draw_rect.position + draw_rect.size * _charge_point_ratio(frame_index)
	var charge: float = clampf((progress - 0.13) / 0.58, 0.0, 1.0)
	var release: float = clampf((progress - 0.72) / 0.16, 0.0, 1.0)
	var flash_fade: float = 1.0
	if phase == "flash":
		flash_fade = 1.0 - clampf((progress - 0.82) / 0.18, 0.0, 1.0)
	var alpha: float = base_alpha * flash_fade * (0.30 + charge * 0.70)
	if alpha <= 0.01:
		return
	var base_radius: float = maxf(18.0, minf(draw_rect.size.x, draw_rect.size.y) * 0.040)
	var pulse: float = sin(progress * TAU * 7.0)
	var radius_boost: float = 1.0 + release * 0.85
	for ring_index in 3:
		var ring_t: float = float(ring_index) / 2.0
		var radius: float = base_radius * (1.0 + ring_t * 0.72 + pulse * 0.08) * radius_boost
		var width: float = maxf(2.0, base_radius * (0.10 + ring_t * 0.04))
		var ring_alpha: float = alpha * (0.46 - ring_t * 0.10)
		var offset: float = progress * TAU * (1.7 + ring_t)
		var color: Color = CHARGE_CORE_COLOR.lerp(CHARGE_HOT_COLOR, ring_t)
		canvas.draw_arc(center, radius, offset, offset + TAU * 0.72, 48, Color(color.r, color.g, color.b, ring_alpha), width, true)
		canvas.draw_arc(center, radius * 0.72, -offset * 0.8, -offset * 0.8 + TAU * 0.52, 40, Color(1.0, 0.85, 0.45, ring_alpha * 0.65), maxf(1.0, width * 0.55), true)
	for spark_index in 14:
		var spark_t: float = float(spark_index) / 14.0
		var angle: float = spark_t * TAU + progress * TAU * (2.2 + float(spark_index % 3) * 0.18)
		var outer: float = base_radius * lerpf(3.1, 1.45, charge) * (1.0 + 0.18 * sin(progress * 19.0 + float(spark_index)))
		var inner: float = base_radius * (0.48 + 0.14 * sin(progress * 11.0 + float(spark_index)))
		var from_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * outer
		var to_pos: Vector2 = center + Vector2(cos(angle + 0.25), sin(angle + 0.25)) * inner
		var spark_alpha: float = alpha * (0.25 + 0.35 * sin(spark_t * PI))
		canvas.draw_line(from_pos, to_pos, Color(1.0, 0.23, 0.08, spark_alpha), maxf(1.0, base_radius * 0.05), true)
	canvas.draw_circle(center, base_radius * (0.42 + release * 0.25), Color(1.0, 0.20, 0.06, alpha * 0.38))
	canvas.draw_circle(center, base_radius * (0.20 + release * 0.22), Color(1.0, 0.90, 0.62, alpha * 0.48))


func _charge_point_ratio(frame_index: int) -> Vector2:
	match clampi(frame_index, 0, CUTIN_FRAME_COUNT - 1):
		0:
			return Vector2(0.62, 0.18)
		1:
			return Vector2(0.66, 0.19)
		2:
			return Vector2(0.70, 0.18)
		3:
			return Vector2(0.75, 0.17)
		4:
			return Vector2(0.61, 0.28)
		5:
			return Vector2(0.54, 0.33)
		6:
			return Vector2(0.43, 0.35)
		7:
			return Vector2(0.31, 0.43)
		8:
			return Vector2(0.19, 0.54)
		9:
			return Vector2(0.22, 0.55)
		10:
			return Vector2(0.25, 0.55)
		11:
			return Vector2(0.27, 0.55)
		12:
			return Vector2(0.20, 0.61)
		13:
			return Vector2(0.23, 0.61)
		14:
			return Vector2(0.25, 0.61)
	return Vector2(0.27, 0.61)


func _draw_title_text(canvas: CanvasItem, view_size: Vector2, progress: float, phase: String) -> void:
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
	var font_size: int = int(view_size.y * 0.065)
	var text: String = "파워스매싱"
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos: Vector2 = Vector2(
		(view_size.x - text_size.x) * 0.5,
		view_size.y * 0.78
	)

	var shadow_color := Color(0.0, 0.0, 0.0, 0.5 * text_alpha)
	canvas.draw_string(font, text_pos + Vector2(2, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shadow_color)

	var text_color := Color(POWER_SMASHING_COLOR.r, POWER_SMASHING_COLOR.g, POWER_SMASHING_COLOR.b, text_alpha)
	canvas.draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)


func _draw_flash(canvas: CanvasItem, view_size: Vector2, progress: float, phase: String) -> void:
	if phase != "flash":
		return
	var flash_local: float = (progress - 0.82) / 0.18
	var flash_alpha: float = lerpf(0.7, 0.0, flash_local)
	if flash_alpha <= 0.0:
		return
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(FLASH_COLOR, flash_alpha))


func _fit_region_rect(source_size: Vector2, target: Rect2) -> Rect2:
	if source_size.x <= 1.0 or source_size.y <= 1.0 or target.size.x <= 1.0 or target.size.y <= 1.0:
		return Rect2(target.position, Vector2.ZERO)
	var scale_factor: float = minf(target.size.x / source_size.x, target.size.y / source_size.y)
	var draw_size: Vector2 = source_size * scale_factor
	return Rect2(target.position + (target.size - draw_size) * 0.5, draw_size)
