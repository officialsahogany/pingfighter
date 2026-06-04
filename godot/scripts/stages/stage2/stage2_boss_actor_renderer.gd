extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const StatusEffectOverlayRenderer := preload("res://scripts/status/status_effect_overlay_renderer.gd")
const ElectricStunVisual := preload("res://scripts/status/boss_electric_stun_visual.gd")
const ElectrocutionFieldHost := preload("res://scripts/effects/boss_electrocution_field_fx_host.gd")

const SPEED_DEFENSE_TEXTURE_PATH := "res://assets/sprites/stage2/boss_stage2_speed_imagegen_v4.png"
const WALK_LEFT_TEXTURE_PATH := "res://assets/sprites/stage2/stage2_boss_run_left_angled_autosprite_v1_16f.png"
const WALK_RIGHT_TEXTURE_PATH := "res://assets/sprites/stage2/stage2_boss_run_right_angled_autosprite_v1_16f.png"
const ATTACK_TEXTURE_PATH := "res://assets/sprites/stage2/stage2_boss_attack_front_paddle_autosprite_v1_16f.png"
const IDLE_TEXTURE_PATH := "res://assets/sprites/stage2/stage2_boss_idle_combat_breath_autosprite_v2_8f.png"
const VICTORY_TEXTURE_PATH := "res://assets/sprites/stage2/stage2_boss_victory_hop_autosprite_v1_64f.png"
const DEFEAT_TEXTURE_PATH := "res://assets/sprites/stage2/stage2_boss_defeat_collapse_autosprite_v1_64f.png"
const GROUND_SHADOW_SEGMENTS := 18
const SPEED_DEFENSE_DRAW_SIZE := Vector2(116.0, 142.0)
const WALK_LEFT_SHEET_COLS := 4
const WALK_LEFT_SHEET_ROWS := 4
const WALK_LEFT_FRAME_COUNT := WALK_LEFT_SHEET_COLS * WALK_LEFT_SHEET_ROWS
const WALK_LEFT_FRAME_INTERVAL_MS := 70.0
const WALK_RIGHT_SHEET_COLS := 4
const WALK_RIGHT_SHEET_ROWS := 4
const WALK_RIGHT_FRAME_COUNT := WALK_RIGHT_SHEET_COLS * WALK_RIGHT_SHEET_ROWS
const WALK_RIGHT_FRAME_INTERVAL_MS := 70.0
const WALK_DRAW_SIZE := Vector2(150.0, 150.0)
const WALK_CENTER_OFFSET := Vector2(0.0, -4.0)
const ATTACK_SHEET_COLS := 4
const ATTACK_SHEET_ROWS := 4
const ATTACK_FRAME_COUNT := ATTACK_SHEET_COLS * ATTACK_SHEET_ROWS
const ATTACK_DRAW_SIZE := Vector2(156.0, 156.0)
const ATTACK_CENTER_OFFSET := Vector2(0.0, -7.0)
const IDLE_SHEET_COLS := 4
const IDLE_SHEET_ROWS := 2
const IDLE_FRAME_COUNT := IDLE_SHEET_COLS * IDLE_SHEET_ROWS
const IDLE_FRAME_INTERVAL_MS := 250.0
const IDLE_DRAW_SIZE := Vector2(150.0, 150.0)
const IDLE_CENTER_OFFSET := Vector2(0.0, -4.0)
const VICTORY_SHEET_COLS := 8
const VICTORY_SHEET_ROWS := 8
const VICTORY_FRAME_COUNT := VICTORY_SHEET_COLS * VICTORY_SHEET_ROWS
const VICTORY_FRAME_INTERVAL_MS := 40.0
const VICTORY_DRAW_SIZE := Vector2(156.0, 156.0)
const VICTORY_CENTER_OFFSET := Vector2(0.0, -10.0)
const DEFEAT_SHEET_COLS := 8
const DEFEAT_SHEET_ROWS := 8
const DEFEAT_FRAME_COUNT := DEFEAT_SHEET_COLS * DEFEAT_SHEET_ROWS
const DEFEAT_FRAME_INTERVAL_MS := 25.0
const DEFEAT_DRAW_SIZE := Vector2(164.0, 164.0)
const DEFEAT_CENTER_OFFSET := Vector2(0.0, -8.0)
const STUN_STAR_FILL := Color(1.0, 1.0, 100.0 / 255.0, 1.0)
const STUN_STAR_OUTLINE := Color(1.0, 200.0 / 255.0, 0.0, 1.0)
const STUN_STAR_GLOW_OUTER := Color(1.0, 0.92, 0.20, 0.14)
const STUN_STAR_GLOW_INNER := Color(1.0, 1.0, 0.52, 0.20)

var speed_defense_texture: Texture2D
var walk_left_texture: Texture2D
var walk_right_texture: Texture2D
var attack_texture: Texture2D
var idle_texture: Texture2D
var victory_texture: Texture2D
var defeat_texture: Texture2D
var _unit_stun_star_points := PackedVector2Array()
var status_overlay_renderer: Object = StatusEffectOverlayRenderer.new()
var _prewarm_done := false
var _prewarm_step_index := 0


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if _prewarm_done:
		return true
	match _prewarm_step_index:
		0:
			_get_speed_defense_texture()
		1:
			_get_walk_left_texture()
		2:
			_get_walk_right_texture()
		3:
			_get_attack_texture()
		4:
			_get_idle_texture()
		5:
			_get_victory_texture()
		6:
			_get_defeat_texture()
		_:
			_prewarm_done = true
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	if _prewarm_step_index > 6:
		_prewarm_done = true
		_prewarm_step_index = 0
		return true
	return false


func draw(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var boss_pos: Vector2 = _as_vector2(context.get("boss_pos", Vector2.ZERO), Vector2.ZERO)
	var boss_paddle_size: Vector2 = _as_vector2(context.get("boss_paddle_size", Vector2(110.0, 18.0)), Vector2(110.0, 18.0))
	var boss_hitbox_height: float = float(context.get("boss_hitbox_height", boss_paddle_size.y))
	var center := Vector2(
		boss_pos.x + boss_paddle_size.x * 0.5 + shake_offset.x,
		boss_pos.y + boss_hitbox_height * 0.5 + 31.0 + shake_offset.y
	)
	center.y += float(context.get("stage2_boss_rage_offset_y", 0.0))
	center += _get_emp_status_jitter(context) + ElectricStunVisual.body_jitter(context)
	ElectrocutionFieldHost.drive_from_context(canvas, center, context)
	var facing: float = -1.0 if int(context.get("boss_facing", 1)) < 0 else 1.0
	var hit_active: bool = bool(context.get("boss_hit_active", false))
	var rage_tint: float = clamp(float(context.get("stage2_boss_rage_tint", 0.0)), 0.0, 1.0)
	var expression: String = str(context.get("stage2_boss_expression", "neutral"))
	var speed_defense_active: bool = bool(context.get("stage2_speed_defense_active", false))
	var pulse: float = 1.0 + (0.07 if hit_active else 0.0) + rage_tint * 0.05

	_draw_speed_defense_trails(canvas, context, shake_offset)
	_draw_shadow(canvas, center + Vector2(0.0, 36.0), Vector2(78.0, 13.0))
	if bool(context.get("boss_defeat_active", false)) and _draw_defeat_sheet(canvas, center, context):
		_draw_emp_status_overlay(canvas, center, DEFEAT_DRAW_SIZE, context)
		_draw_status_overlays(canvas, context, boss_pos, boss_paddle_size, boss_hitbox_height, shake_offset)
		return
	if bool(context.get("boss_victory_active", false)) and _draw_victory_sheet(canvas, center, context):
		_draw_emp_status_overlay(canvas, center, VICTORY_DRAW_SIZE, context)
		_draw_status_overlays(canvas, context, boss_pos, boss_paddle_size, boss_hitbox_height, shake_offset)
		return
	if speed_defense_active and _draw_speed_defense_form(canvas, center, context):
		_draw_rage_overlay(canvas, center, rage_tint)
		_draw_emp_status_overlay(canvas, center, SPEED_DEFENSE_DRAW_SIZE, context)
		_draw_status_overlays(canvas, context, boss_pos, boss_paddle_size, boss_hitbox_height, shake_offset)
		return
	if hit_active and _draw_attack_sheet(canvas, center, context):
		_draw_rage_overlay(canvas, center, rage_tint)
		_draw_emp_status_overlay(canvas, center, ATTACK_DRAW_SIZE, context)
		_draw_status_overlays(canvas, context, boss_pos, boss_paddle_size, boss_hitbox_height, shake_offset)
		return
	if not hit_active and _draw_idle_sheet(canvas, center, context):
		_draw_rage_overlay(canvas, center, rage_tint)
		_draw_emp_status_overlay(canvas, center, IDLE_DRAW_SIZE, context)
		_draw_status_overlays(canvas, context, boss_pos, boss_paddle_size, boss_hitbox_height, shake_offset)
		return
	if not hit_active and _draw_walk_sheet(canvas, center, context, facing):
		_draw_rage_overlay(canvas, center, rage_tint)
		_draw_emp_status_overlay(canvas, center, WALK_DRAW_SIZE, context)
		_draw_status_overlays(canvas, context, boss_pos, boss_paddle_size, boss_hitbox_height, shake_offset)
		return
	_draw_tail(canvas, center, facing, pulse)
	_draw_body(canvas, center, facing, pulse)
	_draw_head(canvas, center, facing, pulse, hit_active, expression)
	_draw_rage_overlay(canvas, center, rage_tint)
	_draw_emp_status_overlay(canvas, center, Vector2(122.0, 96.0), context)
	_draw_status_overlays(canvas, context, boss_pos, boss_paddle_size, boss_hitbox_height, shake_offset)


func _draw_speed_defense_trails(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var trails: Array = _as_array(context.get("stage2_speed_defense_trails", []))
	if trails.is_empty():
		return
	var texture: Texture2D = _get_speed_defense_texture()
	for idx in range(trails.size() - 1, -1, -1):
		var trail: Dictionary = trails[idx] if trails[idx] is Dictionary else {}
		var center: Vector2 = _as_vector2(trail.get("center", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var alpha: float = clamp(float(trail.get("alpha", 0.0)), 0.0, 0.72)
		if alpha <= 0.0:
			continue
		var shrink: float = clamp(1.0 - float(idx) * 0.025, 0.58, 1.0)
		var draw_size: Vector2 = SPEED_DEFENSE_DRAW_SIZE * shrink
		var rect := Rect2(center - draw_size * 0.5, draw_size)
		if texture != null:
			canvas.draw_texture_rect(texture, rect, false, Color(0.65, 0.92, 1.0, alpha))
		else:
			_draw_speed_defense_fallback_shield(canvas, center, draw_size, alpha)


func _draw_speed_defense_form(canvas: CanvasItem, center: Vector2, context: Dictionary) -> bool:
	var progress: float = clamp(float(context.get("stage2_speed_defense_progress", 1.0)), 0.0, 1.0)
	var pulse: float = 1.0 + sin(float(Time.get_ticks_msec()) * 0.026) * 0.035 + (1.0 - progress) * 0.04
	var draw_size: Vector2 = SPEED_DEFENSE_DRAW_SIZE * pulse
	var rect := Rect2(center - draw_size * 0.5, draw_size)
	var texture: Texture2D = _get_speed_defense_texture()
	if texture != null:
		canvas.draw_texture_rect(texture, rect, false, Color(1.0, 1.0, 1.0, 1.0))
		_draw_speed_defense_energy(canvas, center, draw_size, progress)
		return true
	_draw_speed_defense_fallback_shield(canvas, center, draw_size, 1.0)
	_draw_speed_defense_energy(canvas, center, draw_size, progress)
	return true


func _draw_speed_defense_energy(canvas: CanvasItem, center: Vector2, draw_size: Vector2, progress: float) -> void:
	var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.020)
	var radius: float = max(draw_size.x, draw_size.y) * (0.48 + 0.04 * pulse)
	canvas.draw_arc(center, radius, -0.28, TAU - 0.28, 44, Color(0.38, 0.90, 1.0, 0.48), 2.4, true)
	canvas.draw_arc(center, radius * 0.78, 0.30, TAU + 0.30, 36, Color(0.80, 1.0, 0.94, 0.28), 1.6, true)
	for idx in range(3):
		var angle: float = float(Time.get_ticks_msec()) * 0.006 + TAU * float(idx) / 3.0
		var spark_pos := center + Vector2(cos(angle), sin(angle)) * radius * 0.58
		canvas.draw_circle(spark_pos, 2.4 + pulse * 1.2, Color(0.50, 0.96, 1.0, 0.48 + 0.22 * progress))


func _draw_speed_defense_fallback_shield(canvas: CanvasItem, center: Vector2, draw_size: Vector2, alpha: float) -> void:
	var half := draw_size * 0.5
	var shield := PackedVector2Array([
		center + Vector2(0.0, -half.y * 0.88),
		center + Vector2(half.x * 0.72, -half.y * 0.40),
		center + Vector2(half.x * 0.58, half.y * 0.38),
		center + Vector2(0.0, half.y * 0.88),
		center + Vector2(-half.x * 0.58, half.y * 0.38),
		center + Vector2(-half.x * 0.72, -half.y * 0.40),
	])
	canvas.draw_colored_polygon(shield, Color(0.08, 0.26, 0.24, alpha))
	canvas.draw_polyline(shield, Color(0.38, 0.92, 1.0, alpha), 3.0, true)
	canvas.draw_line(center + Vector2(0.0, -half.y * 0.65), center + Vector2(0.0, half.y * 0.58), Color(0.82, 1.0, 0.94, alpha * 0.75), 2.0)
	canvas.draw_line(center + Vector2(-half.x * 0.42, -half.y * 0.08), center + Vector2(half.x * 0.42, -half.y * 0.08), Color(0.82, 1.0, 0.94, alpha * 0.55), 2.0)


func _get_speed_defense_texture() -> Texture2D:
	if speed_defense_texture != null:
		return speed_defense_texture
	speed_defense_texture = ProjectResourceLoader.load_texture(
		SPEED_DEFENSE_TEXTURE_PATH,
		"Missing Stage 2 speed defense texture at %s",
		"Failed to load Stage 2 speed defense texture at %s"
	)
	return speed_defense_texture


func _draw_walk_sheet(canvas: CanvasItem, center: Vector2, context: Dictionary, facing: float) -> bool:
	if not bool(context.get("boss_is_walking", false)):
		return false
	var texture: Texture2D = _get_walk_left_texture() if facing < 0.0 else _get_walk_right_texture()
	if texture == null:
		return false

	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return false
	var sheet_cols: int = WALK_LEFT_SHEET_COLS if facing < 0.0 else WALK_RIGHT_SHEET_COLS
	var sheet_rows: int = WALK_LEFT_SHEET_ROWS if facing < 0.0 else WALK_RIGHT_SHEET_ROWS
	var cell_width: float = texture_size.x / float(sheet_cols)
	var cell_height: float = texture_size.y / float(sheet_rows)
	var frame: int = _get_walk_frame_index(facing)
	var col: int = frame % sheet_cols
	@warning_ignore("integer_division")
	var row: int = int(frame / sheet_cols)
	var source_rect := Rect2(
		float(col) * cell_width,
		float(row) * cell_height,
		cell_width,
		cell_height
	)
	var draw_rect := Rect2(
		center + WALK_CENTER_OFFSET - WALK_DRAW_SIZE * 0.5,
		WALK_DRAW_SIZE
	)
	canvas.draw_texture_rect_region(texture, draw_rect, source_rect, ElectricStunVisual.body_modulate(context), false, true)
	return true


func _get_walk_frame_index(facing: float) -> int:
	if facing < 0.0:
		return int(floor(float(Time.get_ticks_msec()) / WALK_LEFT_FRAME_INTERVAL_MS)) % WALK_LEFT_FRAME_COUNT
	return int(floor(float(Time.get_ticks_msec()) / WALK_RIGHT_FRAME_INTERVAL_MS)) % WALK_RIGHT_FRAME_COUNT


func _get_walk_left_texture() -> Texture2D:
	if walk_left_texture != null:
		return walk_left_texture
	walk_left_texture = ProjectResourceLoader.load_texture(
		WALK_LEFT_TEXTURE_PATH,
		"Missing Stage 2 walk-left texture at %s",
		"Failed to load Stage 2 walk-left texture at %s"
	)
	return walk_left_texture


func _get_walk_right_texture() -> Texture2D:
	if walk_right_texture != null:
		return walk_right_texture
	walk_right_texture = ProjectResourceLoader.load_texture(
		WALK_RIGHT_TEXTURE_PATH,
		"Missing Stage 2 walk-right texture at %s",
		"Failed to load Stage 2 walk-right texture at %s"
	)
	return walk_right_texture


func _draw_attack_sheet(canvas: CanvasItem, center: Vector2, context: Dictionary) -> bool:
	var texture: Texture2D = _get_attack_texture()
	if texture == null:
		return false

	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return false
	var cell_width: float = texture_size.x / float(ATTACK_SHEET_COLS)
	var cell_height: float = texture_size.y / float(ATTACK_SHEET_ROWS)
	var frame: int = int(context.get("boss_hit_frame", 0)) % ATTACK_FRAME_COUNT
	var col: int = frame % ATTACK_SHEET_COLS
	@warning_ignore("integer_division")
	var row: int = int(frame / ATTACK_SHEET_COLS)
	var source_rect := Rect2(
		float(col) * cell_width,
		float(row) * cell_height,
		cell_width,
		cell_height
	)
	var draw_rect := Rect2(
		center + ATTACK_CENTER_OFFSET - ATTACK_DRAW_SIZE * 0.5,
		ATTACK_DRAW_SIZE
	)
	canvas.draw_texture_rect_region(texture, draw_rect, source_rect, ElectricStunVisual.body_modulate(context), false, true)
	return true


func _get_attack_texture() -> Texture2D:
	if attack_texture != null:
		return attack_texture
	attack_texture = ProjectResourceLoader.load_texture(
		ATTACK_TEXTURE_PATH,
		"Missing Stage 2 attack texture at %s",
		"Failed to load Stage 2 attack texture at %s"
	)
	return attack_texture


func _draw_idle_sheet(canvas: CanvasItem, center: Vector2, context: Dictionary) -> bool:
	if bool(context.get("boss_is_walking", false)):
		return false
	var texture: Texture2D = _get_idle_texture()
	if texture == null:
		return false

	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return false
	var cell_width: float = texture_size.x / float(IDLE_SHEET_COLS)
	var cell_height: float = texture_size.y / float(IDLE_SHEET_ROWS)
	var frame: int = _get_idle_frame_index()
	var col: int = frame % IDLE_SHEET_COLS
	@warning_ignore("integer_division")
	var row: int = int(frame / IDLE_SHEET_COLS)
	var source_rect := Rect2(
		float(col) * cell_width,
		float(row) * cell_height,
		cell_width,
		cell_height
	)
	var draw_rect := Rect2(
		center + IDLE_CENTER_OFFSET - IDLE_DRAW_SIZE * 0.5,
		IDLE_DRAW_SIZE
	)
	canvas.draw_texture_rect_region(texture, draw_rect, source_rect, ElectricStunVisual.body_modulate(context), false, true)
	return true


func _get_idle_frame_index() -> int:
	return int(floor(float(Time.get_ticks_msec()) / IDLE_FRAME_INTERVAL_MS)) % IDLE_FRAME_COUNT


func _get_idle_texture() -> Texture2D:
	if idle_texture != null:
		return idle_texture
	idle_texture = ProjectResourceLoader.load_texture(
		IDLE_TEXTURE_PATH,
		"Missing Stage 2 idle texture at %s",
		"Failed to load Stage 2 idle texture at %s"
	)
	return idle_texture


func _draw_victory_sheet(canvas: CanvasItem, center: Vector2, context: Dictionary) -> bool:
	var texture: Texture2D = _get_victory_texture()
	if texture == null:
		return false

	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return false
	var cell_width: float = texture_size.x / float(VICTORY_SHEET_COLS)
	var cell_height: float = texture_size.y / float(VICTORY_SHEET_ROWS)
	var frame: int = _get_victory_frame_index(context)
	var col: int = frame % VICTORY_SHEET_COLS
	@warning_ignore("integer_division")
	var row: int = int(frame / VICTORY_SHEET_COLS)
	var source_rect := Rect2(
		float(col) * cell_width,
		float(row) * cell_height,
		cell_width,
		cell_height
	)
	var draw_rect := Rect2(
		center + VICTORY_CENTER_OFFSET - VICTORY_DRAW_SIZE * 0.5,
		VICTORY_DRAW_SIZE
	)
	canvas.draw_texture_rect_region(texture, draw_rect, source_rect, Color.WHITE, false, true)
	return true


func _get_victory_frame_index(context: Dictionary) -> int:
	var frame: int = int(context.get("boss_victory_frame", -1))
	if frame >= 0:
		return frame % VICTORY_FRAME_COUNT
	return int(floor(float(Time.get_ticks_msec()) / VICTORY_FRAME_INTERVAL_MS)) % VICTORY_FRAME_COUNT


func _get_victory_texture() -> Texture2D:
	if victory_texture != null:
		return victory_texture
	victory_texture = ProjectResourceLoader.load_texture(
		VICTORY_TEXTURE_PATH,
		"Missing Stage 2 victory texture at %s",
		"Failed to load Stage 2 victory texture at %s"
	)
	return victory_texture


func _draw_defeat_sheet(canvas: CanvasItem, center: Vector2, context: Dictionary) -> bool:
	var texture: Texture2D = _get_defeat_texture()
	if texture == null:
		return false

	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return false
	var cell_width: float = texture_size.x / float(DEFEAT_SHEET_COLS)
	var cell_height: float = texture_size.y / float(DEFEAT_SHEET_ROWS)
	var frame: int = _get_defeat_frame_index(context)
	var col: int = frame % DEFEAT_SHEET_COLS
	@warning_ignore("integer_division")
	var row: int = int(frame / DEFEAT_SHEET_COLS)
	var source_rect := Rect2(
		float(col) * cell_width,
		float(row) * cell_height,
		cell_width,
		cell_height
	)
	var draw_rect := Rect2(
		center + DEFEAT_CENTER_OFFSET - DEFEAT_DRAW_SIZE * 0.5,
		DEFEAT_DRAW_SIZE
	)
	canvas.draw_texture_rect_region(texture, draw_rect, source_rect, Color.WHITE, false, true)
	return true


func _get_defeat_frame_index(context: Dictionary) -> int:
	var frame: int = int(context.get("boss_defeat_frame", -1))
	if frame >= 0:
		return clamp(frame, 0, DEFEAT_FRAME_COUNT - 1)
	return min(DEFEAT_FRAME_COUNT - 1, int(floor(float(Time.get_ticks_msec()) / DEFEAT_FRAME_INTERVAL_MS)))


func _get_defeat_texture() -> Texture2D:
	if defeat_texture != null:
		return defeat_texture
	defeat_texture = ProjectResourceLoader.load_texture(
		DEFEAT_TEXTURE_PATH,
		"Missing Stage 2 defeat texture at %s",
		"Failed to load Stage 2 defeat texture at %s"
	)
	return defeat_texture


func _draw_body(canvas: CanvasItem, center: Vector2, _facing: float, pulse: float) -> void:
	var body_rect := Rect2(center - Vector2(43.0 * pulse, 24.0), Vector2(86.0 * pulse, 47.0))
	canvas.draw_colored_polygon(_ellipse_points(body_rect, 24), Color(0.12, 0.34, 0.16, 1.0))
	canvas.draw_arc(body_rect.get_center(), body_rect.size.x * 0.47, 0.15, PI - 0.15, 32, Color(0.30, 0.55, 0.20, 0.60), 3.0)
	for idx in range(4):
		var x: float = center.x - 24.0 + float(idx) * 16.0
		canvas.draw_circle(Vector2(x, center.y - 14.0 + sin(float(idx)) * 2.0), 4.0, Color(0.07, 0.22, 0.10, 0.75))
	for leg in [-1.0, 1.0]:
		var foot := Rect2(center + Vector2(leg * 28.0 - 17.0, 18.0), Vector2(34.0, 10.0))
		canvas.draw_colored_polygon(_ellipse_points(foot, 14), Color(0.08, 0.25, 0.11, 1.0))


func _draw_head(canvas: CanvasItem, center: Vector2, facing: float, pulse: float, hit_active: bool, expression: String) -> void:
	var snout_center := center + Vector2(facing * 46.0, -13.0)
	var snout_rect := Rect2(snout_center - Vector2(30.0 * pulse, 14.0), Vector2(60.0 * pulse, 28.0))
	canvas.draw_colored_polygon(_ellipse_points(snout_rect, 20), Color(0.10, 0.31, 0.15, 1.0))
	canvas.draw_colored_polygon(_ellipse_points(snout_rect.grow(-5.0), 20), Color(0.20, 0.43, 0.18, 0.95))
	var eye_y: float = snout_center.y - 11.0
	var eye_centers: Array[Vector2] = []
	for eye_idx in [-1.0, 1.0]:
		var eye := Vector2(snout_center.x - facing * 8.0 + eye_idx * 9.0, eye_y)
		eye_centers.append(eye)
		canvas.draw_circle(eye, 4.2, Color(0.95, 0.88, 0.42, 1.0))
		if expression != "happy":
			canvas.draw_circle(eye + Vector2(facing * 1.0, 0.2), 1.7, Color(0.02, 0.05, 0.02, 1.0))
	_draw_expression(canvas, snout_center, facing, hit_active, expression, eye_centers)


func _draw_expression(
	canvas: CanvasItem,
	snout_center: Vector2,
	facing: float,
	hit_active: bool,
	expression: String,
	eye_centers: Array[Vector2]
) -> void:
	var mouth_y: float = snout_center.y + (3.0 if hit_active else 5.0)
	if expression == "happy":
		var mouth_rect := Rect2(snout_center + Vector2(-24.0, 5.0), Vector2(48.0, 16.0))
		canvas.draw_colored_polygon(_ellipse_points(mouth_rect, 16), Color(0.50, 0.05, 0.03, 0.96))
		canvas.draw_arc(snout_center + Vector2(0.0, 2.0), 25.0, 0.10, PI - 0.10, 28, Color(0.02, 0.05, 0.02, 0.92), 3.5, true)
		for tooth_idx in range(4):
			var tooth_x: float = snout_center.x - 15.0 + float(tooth_idx) * 10.0
			canvas.draw_rect(Rect2(Vector2(tooth_x, mouth_y + 5.0), Vector2(5.0, 7.0)), Color(0.94, 0.90, 0.72, 0.94))
		for eye in eye_centers:
			canvas.draw_arc(eye + Vector2(0.0, -2.0), 5.6, 0.12, PI - 0.12, 12, Color(0.02, 0.05, 0.02, 0.92), 2.0, true)
		return
	if expression == "sad":
		canvas.draw_arc(snout_center + Vector2(0.0, 17.0), 21.0, PI + 0.22, TAU - 0.22, 26, Color(0.02, 0.05, 0.02, 0.90), 3.0, true)
		for eye in eye_centers:
			var tear_top := eye + Vector2(0.0, 7.0)
			canvas.draw_circle(tear_top, 3.2, Color(0.38, 0.76, 1.0, 0.80))
			canvas.draw_circle(tear_top + Vector2(0.0, 6.0), 2.2, Color(0.68, 0.90, 1.0, 0.62))
			canvas.draw_line(eye + Vector2(-4.0, -6.0), eye + Vector2(4.0, -2.0), Color(0.02, 0.05, 0.02, 0.82), 2.0)
		return
	canvas.draw_line(
		Vector2(snout_center.x - facing * 25.0, mouth_y),
		Vector2(snout_center.x + facing * 24.0, mouth_y + 2.0),
		Color(0.02, 0.06, 0.02, 0.85),
		2.0
	)
	for tooth_idx in range(5):
		var t: float = float(tooth_idx) / 4.0
		var x: float = lerp(snout_center.x - facing * 19.0, snout_center.x + facing * 20.0, t)
		canvas.draw_line(Vector2(x, mouth_y), Vector2(x + facing * 2.0, mouth_y + 5.0), Color(0.90, 0.86, 0.70, 0.9), 1.4)


func _draw_tail(canvas: CanvasItem, center: Vector2, facing: float, pulse: float) -> void:
	var base := center + Vector2(-facing * 39.0, 2.0)
	var tail := PackedVector2Array([
		base + Vector2(0.0, -10.0),
		base + Vector2(-facing * 48.0 * pulse, -8.0),
		base + Vector2(-facing * 64.0 * pulse, 6.0),
		base + Vector2(-facing * 8.0, 14.0),
	])
	canvas.draw_colored_polygon(tail, Color(0.08, 0.25, 0.11, 1.0))
	canvas.draw_line(base + Vector2(-facing * 6.0, -3.0), base + Vector2(-facing * 48.0, 3.0), Color(0.24, 0.48, 0.17, 0.55), 2.0)


func _draw_shadow(canvas: CanvasItem, center: Vector2, radius: Vector2) -> void:
	var rect := Rect2(center - radius, radius * 2.0)
	canvas.draw_colored_polygon(_ellipse_points(rect, GROUND_SHADOW_SEGMENTS), Color(0.0, 0.0, 0.0, 0.24))


func _draw_rage_overlay(canvas: CanvasItem, center: Vector2, rage_tint: float) -> void:
	if rage_tint <= 0.0:
		return
	var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.018)
	canvas.draw_circle(center, 64.0 + pulse * 10.0, Color(1.0, 0.06, 0.02, 0.10 * rage_tint))
	canvas.draw_arc(center, 58.0 + pulse * 7.0, -0.25, PI * 1.15, 36, Color(1.0, 0.20, 0.05, 0.48 * rage_tint), 3.0)
	canvas.draw_arc(center + Vector2(0.0, 5.0), 43.0 + pulse * 5.0, PI * 0.80, TAU - 0.24, 34, Color(1.0, 0.72, 0.18, 0.22 * rage_tint), 2.0)


func _draw_emp_status_overlay(canvas: CanvasItem, center: Vector2, visual_size: Vector2, context: Dictionary) -> void:
	var intensity: float = _get_emp_status_intensity(context)
	if intensity <= 0.0:
		return
	var now: float = float(Time.get_ticks_msec())
	var pulse: float = 0.5 + 0.5 * sin(now * 0.020)
	var aura_rect := Rect2(
		center - Vector2(visual_size.x * 0.46, visual_size.y * 0.42),
		Vector2(visual_size.x * 0.92, visual_size.y * 0.76)
	)
	canvas.draw_colored_polygon(
		_ellipse_points(aura_rect.grow(8.0 + pulse * 4.0), 24),
		Color(0.05, 0.86, 1.0, 0.10 * intensity)
	)
	_draw_ellipse_outline(canvas, aura_rect.grow(5.0 + pulse * 5.0), Color(0.28, 0.96, 1.0, 0.42 * intensity), 2.2)
	_draw_ellipse_outline(canvas, aura_rect.grow(-5.0 + pulse * 2.0), Color(0.86, 1.0, 1.0, 0.26 * intensity), 1.3)
	for idx in range(4):
		var angle: float = now * 0.011 + TAU * float(idx) / 4.0
		var start: Vector2 = center + Vector2(cos(angle), sin(angle) * 0.46) * (visual_size.x * 0.25)
		var mid: Vector2 = center + Vector2(cos(angle + 0.38), sin(angle + 0.38) * 0.54) * (visual_size.x * 0.37)
		var end: Vector2 = center + Vector2(cos(angle + 0.82), sin(angle + 0.82) * 0.50) * (visual_size.x * 0.48)
		canvas.draw_polyline(PackedVector2Array([start, mid, end]), Color(0.10, 0.58, 1.0, 0.28 * intensity), 3.0, false)
		canvas.draw_polyline(PackedVector2Array([start, mid, end]), Color(0.84, 1.0, 1.0, 0.82 * intensity), 1.2, false)
	for idx in range(5):
		var spark_angle: float = now * 0.016 + TAU * float(idx) / 5.0
		var spark_pos: Vector2 = center + Vector2(cos(spark_angle), sin(spark_angle) * 0.58) * (visual_size.x * 0.36 + pulse * 5.0)
		canvas.draw_circle(spark_pos, 1.7 + pulse, Color(0.88, 1.0, 1.0, 0.64 * intensity))


func _get_emp_status_intensity(context: Dictionary) -> float:
	if not bool(context.get("viper_emp_slip_active", false)):
		return 0.0
	var ratio: float = clamp(float(context.get("viper_emp_slip_ratio", 1.0)), 0.0, 1.0)
	return clamp(0.36 + ratio * 0.64, 0.0, 1.0)


func _get_emp_status_jitter(context: Dictionary) -> Vector2:
	var intensity: float = _get_emp_status_intensity(context)
	if intensity <= 0.0:
		return Vector2.ZERO
	var now: float = float(Time.get_ticks_msec())
	return Vector2(
		(sin(now * 0.054) + sin(now * 0.091) * 0.55) * 2.2 * intensity,
		sin(now * 0.073) * 1.2 * intensity
	)


func _draw_ellipse_outline(canvas: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var points: PackedVector2Array = _ellipse_points(rect, 24)
	if points.size() < 2:
		return
	for idx in range(points.size()):
		canvas.draw_line(points[idx], points[(idx + 1) % points.size()], color, width)


func _draw_status_overlays(
	canvas: CanvasItem,
	context: Dictionary,
	boss_pos: Vector2,
	boss_paddle_size: Vector2,
	boss_hitbox_height: float,
	shake_offset: Vector2
) -> void:
	status_overlay_renderer.draw_boss_status_overlays(canvas, context, boss_pos, boss_paddle_size, boss_hitbox_height, shake_offset, {
		"extra_y_offset": float(context.get("stage2_boss_rage_offset_y", 0.0)),
	})


func _draw_stun_star(canvas: CanvasItem, center: Vector2, radius: float) -> void:
	if _unit_stun_star_points.is_empty():
		_unit_stun_star_points = _build_unit_stun_star_points()
	canvas.draw_circle(center, radius * 2.0, STUN_STAR_GLOW_OUTER)
	canvas.draw_circle(center, radius * 1.35, STUN_STAR_GLOW_INNER)
	var points := PackedVector2Array()
	for point in _unit_stun_star_points:
		points.append(center + point * radius)
	canvas.draw_colored_polygon(points, STUN_STAR_FILL)
	for idx in range(points.size()):
		canvas.draw_line(points[idx], points[(idx + 1) % points.size()], STUN_STAR_OUTLINE, 1.2, true)


func _build_unit_stun_star_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	for idx in range(10):
		var point_angle: float = deg_to_rad(float(idx) * 36.0 - 90.0)
		var point_radius: float = 1.0 if idx % 2 == 0 else 0.4
		points.append(Vector2(cos(point_angle), sin(point_angle)) * point_radius)
	return points


func _ellipse_points(rect: Rect2, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var center: Vector2 = rect.get_center()
	var radius: Vector2 = rect.size * 0.5
	for idx in range(max(8, segments)):
		var angle: float = TAU * float(idx) / float(max(8, segments))
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
