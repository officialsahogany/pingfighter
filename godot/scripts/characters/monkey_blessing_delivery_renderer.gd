extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const RIGHT_SHEET_PATH := "res://assets/sprites/perks/monkey_blessing_delivery_sheet.png"
const LEFT_SHEET_PATH := "res://assets/sprites/perks/monkey_blessing_delivery_sheet_left.png"
const SHEET_ROWS := 4
const SHEET_COLS := 4
const FALLBACK_BODY := Color(0.52, 0.28, 0.11, 1.0)
const FALLBACK_FACE := Color(0.95, 0.72, 0.48, 1.0)
const FALLBACK_BANANA := Color(1.0, 0.88, 0.18, 1.0)

var right_sheet: Texture2D
var left_sheet: Texture2D
var load_attempted := false
var _prewarm_assets_done := false
var _prewarm_step_index := 0


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if _prewarm_assets_done:
		return true
	match _prewarm_step_index:
		0:
			right_sheet = ProjectResourceLoader.load_texture(
				RIGHT_SHEET_PATH,
				"Missing Monkey Blessing delivery sheet at %s",
				"Failed to load Monkey Blessing delivery sheet at %s"
			)
		1:
			left_sheet = ProjectResourceLoader.load_texture(
				LEFT_SHEET_PATH,
				"Missing Monkey Blessing mirrored delivery sheet at %s",
				"Failed to load Monkey Blessing mirrored delivery sheet at %s"
			)
		_:
			load_attempted = true
			_prewarm_assets_done = true
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	if _prewarm_step_index > 1:
		load_attempted = true
		_prewarm_assets_done = true
		_prewarm_step_index = 0
		return true
	return false


func draw(canvas: CanvasItem, snapshot: Dictionary, shake_offset: Vector2) -> void:
	if canvas == null or not bool(snapshot.get("visible", false)):
		return

	_ensure_textures()
	var pos: Vector2 = _as_vector2(snapshot.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var draw_size: Vector2 = _as_vector2(snapshot.get("draw_size", Vector2(96.0, 96.0)), Vector2(96.0, 96.0))
	var alpha: float = clamp(float(snapshot.get("alpha", 1.0)), 0.0, 1.0)
	var frame: int = clampi(int(snapshot.get("frame", 0)), 0, SHEET_ROWS * SHEET_COLS - 1)
	var facing: float = float(snapshot.get("facing", 1.0))
	var texture: Texture2D = left_sheet if facing < 0.0 else right_sheet
	var draw_rect := Rect2(
		Vector2(pos.x - draw_size.x * 0.5, pos.y - draw_size.y),
		draw_size
	)

	if texture != null:
		var cell_size := Vector2(
			float(texture.get_width()) / float(SHEET_COLS),
			float(texture.get_height()) / float(SHEET_ROWS)
		)
		@warning_ignore("integer_division")
		var row: int = int(frame / SHEET_COLS)
		var col: int = frame % SHEET_COLS
		canvas.draw_texture_rect_region(
			texture,
			draw_rect,
			Rect2(Vector2(float(col) * cell_size.x, float(row) * cell_size.y), cell_size),
			Color(1.0, 1.0, 1.0, alpha)
		)
		return

	_draw_fallback_monkey(canvas, pos, draw_size, alpha, facing)


func _ensure_textures() -> void:
	if load_attempted:
		return
	prewarm_assets()


func _draw_fallback_monkey(
	canvas: CanvasItem,
	pos: Vector2,
	draw_size: Vector2,
	alpha: float,
	facing: float
) -> void:
	var body_color := Color(FALLBACK_BODY.r, FALLBACK_BODY.g, FALLBACK_BODY.b, alpha)
	var face_color := Color(FALLBACK_FACE.r, FALLBACK_FACE.g, FALLBACK_FACE.b, alpha)
	var banana_color := Color(FALLBACK_BANANA.r, FALLBACK_BANANA.g, FALLBACK_BANANA.b, alpha)
	var scale: float = draw_size.y / 96.0
	var dir: float = 1.0 if facing >= 0.0 else -1.0
	var body_center := pos + Vector2(-8.0 * dir, -34.0) * scale
	var head_center := pos + Vector2(12.0 * dir, -60.0) * scale
	canvas.draw_circle(body_center, 22.0 * scale, body_color)
	canvas.draw_circle(head_center, 19.0 * scale, body_color)
	canvas.draw_circle(head_center + Vector2(5.0 * dir, 2.0) * scale, 11.0 * scale, face_color)
	canvas.draw_circle(head_center + Vector2(-14.0 * dir, -2.0) * scale, 7.0 * scale, body_color)
	canvas.draw_arc(
		body_center + Vector2(-22.0 * dir, 6.0) * scale,
		17.0 * scale,
		PI * 0.15,
		PI * 1.18,
		14,
		body_color,
		4.0 * scale
	)
	var hand := head_center + Vector2(31.0 * dir, 7.0) * scale
	canvas.draw_line(body_center, hand, body_color, 6.0 * scale)
	canvas.draw_line(
		hand + Vector2(-2.0 * dir, 7.0) * scale,
		hand + Vector2(14.0 * dir, -14.0) * scale,
		banana_color,
		6.0 * scale
	)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
