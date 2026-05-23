extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const RIGHT_SHEET_PATH := "res://assets/sprites/perks/commando_reload_delivery_sheet.png"
const LEFT_SHEET_PATH := "res://assets/sprites/perks/commando_reload_delivery_sheet_left.png"
const SHEET_ROWS := 4
const SHEET_COLS := 4
const FALLBACK_UNIFORM := Color(0.27, 0.36, 0.22, 1.0)
const FALLBACK_PANTS := Color(0.21, 0.28, 0.17, 1.0)
const FALLBACK_FACE := Color(0.96, 0.78, 0.58, 1.0)
const FALLBACK_HELMET := Color(0.18, 0.24, 0.16, 1.0)
const FALLBACK_BOOTS := Color(0.10, 0.10, 0.10, 1.0)
const FALLBACK_BOX := Color(0.62, 0.45, 0.22, 1.0)
const FALLBACK_BOX_STRAP := Color(0.32, 0.22, 0.10, 1.0)
const FALLBACK_RADIO := Color(0.16, 0.18, 0.12, 1.0)
const FALLBACK_RADIO_LIGHT := Color(1.0, 0.65, 0.30, 1.0)

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
				"",
				""
			)
		1:
			left_sheet = ProjectResourceLoader.load_texture(
				LEFT_SHEET_PATH,
				"",
				""
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
	if canvas == null:
		return

	_ensure_textures()
	var soldier_visible: bool = bool(snapshot.get("visible", false))
	var radio_visible: bool = bool(snapshot.get("radio_visible", false))
	if not soldier_visible and not radio_visible:
		return

	if radio_visible:
		_draw_radio_cue(canvas, snapshot, shake_offset)

	if not soldier_visible:
		return

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

	_draw_fallback_soldier(canvas, pos, draw_size, alpha, facing, snapshot)


func _ensure_textures() -> void:
	if load_attempted:
		return
	prewarm_assets()


func _draw_radio_cue(canvas: CanvasItem, snapshot: Dictionary, shake_offset: Vector2) -> void:
	var anchor: Vector2 = _as_vector2(snapshot.get("radio_anchor", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var alpha: float = clamp(float(snapshot.get("radio_alpha", 1.0)), 0.0, 1.0)
	var pulse: float = clamp(float(snapshot.get("radio_pulse", 0.0)), 0.0, 1.0)
	if alpha <= 0.01:
		return
	var radio_color := Color(FALLBACK_RADIO.r, FALLBACK_RADIO.g, FALLBACK_RADIO.b, alpha)
	var light_color := Color(
		FALLBACK_RADIO_LIGHT.r,
		FALLBACK_RADIO_LIGHT.g,
		FALLBACK_RADIO_LIGHT.b,
		alpha * lerp(0.45, 1.0, pulse)
	)
	var body_rect := Rect2(anchor + Vector2(-9.0, -42.0), Vector2(18.0, 26.0))
	canvas.draw_rect(body_rect, radio_color, true)
	canvas.draw_line(
		anchor + Vector2(7.0, -42.0),
		anchor + Vector2(13.0, -64.0),
		radio_color,
		2.4
	)
	canvas.draw_circle(anchor + Vector2(13.0, -64.0), 2.6, light_color)
	canvas.draw_circle(anchor + Vector2(0.0, -30.0), 3.8 + 2.6 * pulse, light_color)


func _draw_fallback_soldier(
	canvas: CanvasItem,
	pos: Vector2,
	draw_size: Vector2,
	alpha: float,
	facing: float,
	snapshot: Dictionary
) -> void:
	var uniform_color := Color(FALLBACK_UNIFORM.r, FALLBACK_UNIFORM.g, FALLBACK_UNIFORM.b, alpha)
	var pants_color := Color(FALLBACK_PANTS.r, FALLBACK_PANTS.g, FALLBACK_PANTS.b, alpha)
	var face_color := Color(FALLBACK_FACE.r, FALLBACK_FACE.g, FALLBACK_FACE.b, alpha)
	var helmet_color := Color(FALLBACK_HELMET.r, FALLBACK_HELMET.g, FALLBACK_HELMET.b, alpha)
	var boots_color := Color(FALLBACK_BOOTS.r, FALLBACK_BOOTS.g, FALLBACK_BOOTS.b, alpha)
	var box_color := Color(FALLBACK_BOX.r, FALLBACK_BOX.g, FALLBACK_BOX.b, alpha)
	var strap_color := Color(FALLBACK_BOX_STRAP.r, FALLBACK_BOX_STRAP.g, FALLBACK_BOX_STRAP.b, alpha)
	var scale: float = draw_size.y / 96.0
	var dir: float = 1.0 if facing >= 0.0 else -1.0
	var leg_phase: float = float(snapshot.get("leg_phase", 0.0))
	var box_offset: Vector2 = _as_vector2(snapshot.get("box_offset", Vector2.ZERO), Vector2.ZERO) * scale
	var box_alpha: float = clamp(float(snapshot.get("box_alpha", 1.0)), 0.0, 1.0)

	var body_center := pos + Vector2(0.0, -36.0) * scale
	var head_center := pos + Vector2(0.0, -68.0) * scale
	var hip_center := pos + Vector2(0.0, -16.0) * scale

	var left_leg_swing: float = sin(leg_phase) * 8.0 * scale
	var right_leg_swing: float = sin(leg_phase + PI) * 8.0 * scale
	canvas.draw_line(
		hip_center + Vector2(-5.0, 0.0) * scale,
		hip_center + Vector2(-5.0 + left_leg_swing, 16.0) * scale,
		pants_color,
		6.0 * scale
	)
	canvas.draw_line(
		hip_center + Vector2(5.0, 0.0) * scale,
		hip_center + Vector2(5.0 + right_leg_swing, 16.0) * scale,
		pants_color,
		6.0 * scale
	)
	canvas.draw_circle(hip_center + Vector2(-5.0 + left_leg_swing, 16.0) * scale, 4.5 * scale, boots_color)
	canvas.draw_circle(hip_center + Vector2(5.0 + right_leg_swing, 16.0) * scale, 4.5 * scale, boots_color)

	var torso_rect := Rect2(
		body_center + Vector2(-13.0, -10.0) * scale,
		Vector2(26.0, 32.0) * scale
	)
	canvas.draw_rect(torso_rect, uniform_color, true)

	var helmet_rect := Rect2(
		head_center + Vector2(-13.0, -10.0) * scale,
		Vector2(26.0, 10.0) * scale
	)
	canvas.draw_circle(head_center, 11.0 * scale, face_color)
	canvas.draw_rect(helmet_rect, helmet_color, true)
	canvas.draw_arc(head_center + Vector2(0.0, -2.0) * scale, 11.0 * scale, PI, 2.0 * PI, 12, helmet_color, 2.0 * scale)

	var carry_arm_origin := body_center + Vector2(10.0 * dir, -4.0) * scale
	var idle_arm_origin := body_center + Vector2(-10.0 * dir, -2.0) * scale
	var arm_swing: float = sin(leg_phase + PI * 0.5) * 5.0 * scale
	canvas.draw_line(
		idle_arm_origin,
		idle_arm_origin + Vector2(-2.0 * dir, 12.0 + arm_swing) * scale,
		uniform_color,
		5.5 * scale
	)

	if box_alpha > 0.01:
		var box_color_final := Color(box_color.r, box_color.g, box_color.b, alpha * box_alpha)
		var strap_color_final := Color(strap_color.r, strap_color.g, strap_color.b, alpha * box_alpha)
		var box_center: Vector2 = carry_arm_origin + Vector2(8.0 * dir, 6.0) * scale + box_offset
		var box_rect := Rect2(
			box_center + Vector2(-12.0, -10.0) * scale,
			Vector2(24.0, 20.0) * scale
		)
		canvas.draw_rect(box_rect, box_color_final, true)
		canvas.draw_line(
			box_rect.position + Vector2(0.0, box_rect.size.y * 0.5),
			box_rect.position + Vector2(box_rect.size.x, box_rect.size.y * 0.5),
			strap_color_final,
			2.0 * scale
		)
		canvas.draw_line(
			box_rect.position + Vector2(box_rect.size.x * 0.5, 0.0),
			box_rect.position + Vector2(box_rect.size.x * 0.5, box_rect.size.y),
			strap_color_final,
			2.0 * scale
		)
		canvas.draw_line(
			carry_arm_origin,
			box_center,
			uniform_color,
			5.5 * scale
		)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
