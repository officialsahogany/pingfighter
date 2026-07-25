extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const TILT_SHEET_LEFT_PATH := "res://assets/sprites/effects/commando_supply_aircraft/commando_supply_aircraft_tilt_sheet_autosprite_v1_left.png"
const TILT_SHEET_RIGHT_PATH := "res://assets/sprites/effects/commando_supply_aircraft/commando_supply_aircraft_tilt_sheet_autosprite_v1_right.png"
const TILT_FRAME_COUNT := 16
const TILT_GRID_COLS := 4
const TILT_GRID_ROWS := 4
const TILT_FRAME_INTERVAL := 0.06
const TILT_DRAW_SIZE := Vector2(148.0, 148.0)

const CRASH_SHEET_LEFT_PATH := "res://assets/sprites/effects/commando_supply_aircraft/commando_supply_aircraft_crash_sheet_autosprite_v1_left.png"
const CRASH_SHEET_RIGHT_PATH := "res://assets/sprites/effects/commando_supply_aircraft/commando_supply_aircraft_crash_sheet_autosprite_v1_right.png"
const CRASH_FRAME_COUNT := 16
const CRASH_GRID_COLS := 4
const CRASH_GRID_ROWS := 4
const CRASH_DRAW_SIZE := Vector2(148.0, 148.0)

static var _tilt_sheet_cache: Dictionary = {}
static var _tilt_sheet_checked: Dictionary = {}
static var _crash_sheet_cache: Dictionary = {}
static var _crash_sheet_checked: Dictionary = {}


static func prewarm_assets() -> void:
	get_tilt_sheet("left_to_right")
	get_tilt_sheet("right_to_left")
	get_crash_sheet("left_to_right")
	get_crash_sheet("right_to_left")


static func build_status(
	direction: String,
	flight_elapsed: float,
	crash_elapsed: float,
	crash_frame_interval: float,
	speed_pixels_per_second: float,
	travel_duration: float
) -> Dictionary:
	var active_path := get_tilt_sheet_path(direction)
	var active_sheet := get_tilt_sheet(direction)
	var left_sheet := get_tilt_sheet("right_to_left")
	var right_sheet := get_tilt_sheet("left_to_right")
	var crash_active_path := get_crash_sheet_path(direction)
	var crash_active_sheet := get_crash_sheet(direction)
	var crash_left_sheet := get_crash_sheet("right_to_left")
	var crash_right_sheet := get_crash_sheet("left_to_right")
	return {
		"sheet_pipeline": true,
		"active_path": active_path,
		"active_loaded": active_sheet != null,
		"left_loaded": left_sheet != null,
		"right_loaded": right_sheet != null,
		"frame": get_tilt_frame(flight_elapsed),
		"frame_count": TILT_FRAME_COUNT,
		"grid_cols": TILT_GRID_COLS,
		"grid_rows": TILT_GRID_ROWS,
		"frame_interval": TILT_FRAME_INTERVAL,
		"draw_size": TILT_DRAW_SIZE,
		"crash_sheet_pipeline": true,
		"crash_active_path": crash_active_path,
		"crash_active_loaded": crash_active_sheet != null,
		"crash_left_loaded": crash_left_sheet != null,
		"crash_right_loaded": crash_right_sheet != null,
		"crash_frame": get_crash_frame(crash_elapsed, crash_frame_interval),
		"crash_frame_count": CRASH_FRAME_COUNT,
		"crash_grid_cols": CRASH_GRID_COLS,
		"crash_grid_rows": CRASH_GRID_ROWS,
		"crash_frame_interval": crash_frame_interval,
		"crash_draw_size": CRASH_DRAW_SIZE,
		"speed_pixels_per_second": speed_pixels_per_second,
		"travel_duration": travel_duration,
	}


static func draw_sprite(
	canvas: CanvasItem,
	pos: Vector2,
	direction: String,
	rotation: float,
	crashing: bool,
	flight_elapsed: float,
	crash_elapsed: float,
	crash_frame_interval: float
) -> bool:
	if canvas == null:
		return false
	if crashing:
		var crash_sheet := get_crash_sheet(direction)
		if crash_sheet == null:
			return false
		var source := get_crash_source_rect(
			crash_sheet,
			get_crash_frame(crash_elapsed, crash_frame_interval)
		)
		draw_texture_region_rotated(canvas, crash_sheet, source, pos, CRASH_DRAW_SIZE, rotation, Color.WHITE)
		return true
	if absf(rotation) > 0.001:
		return false
	var sheet := get_tilt_sheet(direction)
	if sheet == null:
		return false
	var source := get_tilt_source_rect(sheet, get_tilt_frame(flight_elapsed))
	var dest := Rect2(pos - TILT_DRAW_SIZE * 0.5, TILT_DRAW_SIZE)
	canvas.draw_texture_rect_region(sheet, dest, source, Color.WHITE, false, true)
	return true


static func get_tilt_frame(flight_elapsed: float) -> int:
	var frame := int(floor(maxf(flight_elapsed, 0.0) / TILT_FRAME_INTERVAL))
	return frame % TILT_FRAME_COUNT


static func get_crash_frame(crash_elapsed: float, frame_interval: float) -> int:
	var safe_interval := maxf(frame_interval, 0.000001)
	var frame := int(floor(maxf(crash_elapsed, 0.0) / safe_interval))
	return clampi(frame, 0, CRASH_FRAME_COUNT - 1)


static func get_tilt_sheet(direction: String) -> Texture2D:
	var path := get_tilt_sheet_path(direction)
	if bool(_tilt_sheet_checked.get(path, false)):
		return _tilt_sheet_cache.get(path, null) as Texture2D
	_tilt_sheet_checked[path] = true
	var texture := ProjectResourceLoader.load_texture(path, "", "")
	_tilt_sheet_cache[path] = texture
	return texture


static func get_tilt_sheet_path(direction: String) -> String:
	return TILT_SHEET_LEFT_PATH if direction == "right_to_left" else TILT_SHEET_RIGHT_PATH


static func get_crash_sheet(direction: String) -> Texture2D:
	var path := get_crash_sheet_path(direction)
	if bool(_crash_sheet_checked.get(path, false)):
		return _crash_sheet_cache.get(path, null) as Texture2D
	_crash_sheet_checked[path] = true
	var texture := ProjectResourceLoader.load_texture(path, "", "")
	_crash_sheet_cache[path] = texture
	return texture


static func get_crash_sheet_path(direction: String) -> String:
	return CRASH_SHEET_LEFT_PATH if direction == "right_to_left" else CRASH_SHEET_RIGHT_PATH


static func get_tilt_source_rect(sheet: Texture2D, frame: int) -> Rect2:
	return _get_source_rect(sheet, frame, TILT_FRAME_COUNT, TILT_GRID_COLS, TILT_GRID_ROWS)


static func get_crash_source_rect(sheet: Texture2D, frame: int) -> Rect2:
	return _get_source_rect(sheet, frame, CRASH_FRAME_COUNT, CRASH_GRID_COLS, CRASH_GRID_ROWS)


static func build_rotated_quad(
	texture: Texture2D,
	source: Rect2,
	center: Vector2,
	size: Vector2,
	rotation: float
) -> Dictionary:
	if texture == null or size.x <= 0.0 or size.y <= 0.0:
		return {}
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return {}
	var half := size * 0.5
	var corners := [
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	]
	var points := PackedVector2Array()
	for corner in corners:
		points.append(center + corner.rotated(rotation))
	var uv_min := Vector2(source.position.x / texture_size.x, source.position.y / texture_size.y)
	var uv_max := Vector2(source.end.x / texture_size.x, source.end.y / texture_size.y)
	return {
		"points": points,
		"uvs": PackedVector2Array([
			Vector2(uv_min.x, uv_min.y),
			Vector2(uv_max.x, uv_min.y),
			Vector2(uv_max.x, uv_max.y),
			Vector2(uv_min.x, uv_max.y),
		]),
	}


static func draw_texture_region_rotated(
	canvas: CanvasItem,
	texture: Texture2D,
	source: Rect2,
	center: Vector2,
	size: Vector2,
	rotation: float,
	color: Color
) -> void:
	if canvas == null:
		return
	var quad := build_rotated_quad(texture, source, center, size, rotation)
	if quad.is_empty():
		return
	var colors := PackedColorArray([color, color, color, color])
	canvas.draw_polygon(quad["points"], colors, quad["uvs"], texture)


static func _get_source_rect(
	sheet: Texture2D,
	frame: int,
	frame_count: int,
	grid_cols: int,
	grid_rows: int
) -> Rect2:
	if sheet == null or grid_cols <= 0 or grid_rows <= 0:
		return Rect2()
	var frame_index := clampi(frame, 0, frame_count - 1)
	var texture_size := sheet.get_size()
	var cell_w := texture_size.x / float(grid_cols)
	var cell_h := texture_size.y / float(grid_rows)
	var col := frame_index % grid_cols
	@warning_ignore("integer_division")
	var row := int(frame_index / grid_cols)
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)
