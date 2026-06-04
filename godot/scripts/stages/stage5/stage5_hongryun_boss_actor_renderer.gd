extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const StatusEffectOverlayRenderer := preload("res://scripts/status/status_effect_overlay_renderer.gd")
const BattleRenderQuality := preload("res://scripts/core/battle_render_quality.gd")
const ElectricStunVisual := preload("res://scripts/status/boss_electric_stun_visual.gd")
const ElectrocutionFieldHost := preload("res://scripts/effects/boss_electrocution_field_fx_host.gd")

const WALK_TEXTURE_PATH := "res://assets/sprites/stage5/stage5_hongryun_boss_sheet.png"
const ATTACK_TEXTURE_PATH := "res://assets/sprites/stage5/stage5_hongryun_boss_attack.png"
const DASH_TEXTURE_PATH := "res://assets/sprites/stage5/stage5_hongryun_boss_dash.png"
const TURN_TEXTURE_PATH := "res://assets/sprites/stage5/stage5_hongryun_boss_turn.png"
const DRAGON_HEAD_TEXTURE_PATH := "res://assets/sprites/hud/stage5_hongryun_dragon_head_sheet_imagegen_v3_16f.png"

const SHEET_COLS := 4
const SHEET_ROWS := 2
const FRAME_COUNT := SHEET_COLS * SHEET_ROWS
const TURN_SHEET_COLS := 8
const TURN_SHEET_ROWS := 2
const TURN_FRAME_COUNT := TURN_SHEET_COLS * TURN_SHEET_ROWS
const WALK_FRAME_INTERVAL_SEC := 0.085
const ATTACK_FRAME_INTERVAL_SEC := 0.045
const DASH_FRAME_INTERVAL_SEC := 0.060
const TURN_FRAME_INTERVAL_SEC := 0.055
const TURN_DURATION_SEC := 0.32
const DRAGON_HEAD_FRAME_COUNT := 16
const DRAGON_HEAD_FRAME_INTERVAL_SEC := 1.0 / 12.0
const WALK_SOURCE_INSET_X := 88.0
const WALK_SOURCE_INSET_Y := 0.0
const WALK_SOURCE_SIZE := Vector2(528.0, 768.0)
const DEFAULT_DRAW_SIZE := Vector2(68.0, 100.0)
const ATTACK_DRAW_SIZE := Vector2(76.0, 108.0)
const DASH_DRAW_SIZE := Vector2(76.0, 106.0)
const DRAGON_HEAD_DRAW_SIZE := Vector2(72.0, 32.0)
const VISUAL_CENTER_Y_OFFSET := 25.0
const MOVING_THRESHOLD := 0.16
const MOVE_RELEASE_SEC := 0.12
const TURN_HOP_HEIGHT_RATIO := 0.04
# Visible turn pose is disabled: shipped turn sheet packs 7 chars/row at
# ~390 px spacing but the code slices 8 cols at 344 px, leaking neighbor
# frames. Hop-only fallback until the turn art is regenerated to a clean
# 8x2 layout. See CLAUDE.md "Apparent turn-face clipping" rule.
const TURN_POSE_VISIBLE := false

var walk_texture: Texture2D = null
var attack_texture: Texture2D = null
var dash_texture: Texture2D = null
var turn_texture: Texture2D = null
var dragon_head_texture: Texture2D = null
var textures_loaded := false
var _last_center_x := INF
var _facing := 1
var _turn_active := false
var _turn_time := 0.0
var _move_release_time := 0.0
var _is_moving := false
var _last_draw_msec := 0
var time_sec := 0.0
var status_overlay_renderer: Object = StatusEffectOverlayRenderer.new()
var _active_quality_scale := 1.0
var _prewarm_step_index := 0


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if textures_loaded:
		return true
	match _prewarm_step_index:
		0:
			walk_texture = ProjectResourceLoader.load_texture(WALK_TEXTURE_PATH)
		1:
			attack_texture = ProjectResourceLoader.load_texture(ATTACK_TEXTURE_PATH)
		2:
			dash_texture = ProjectResourceLoader.load_texture(DASH_TEXTURE_PATH)
		3:
			turn_texture = ProjectResourceLoader.load_texture(TURN_TEXTURE_PATH)
		4:
			dragon_head_texture = ProjectResourceLoader.load_texture(DRAGON_HEAD_TEXTURE_PATH)
		_:
			textures_loaded = true
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	return false


func reset() -> void:
	_last_center_x = INF
	_facing = 1
	_turn_active = false
	_turn_time = 0.0
	_move_release_time = 0.0
	_is_moving = false
	_last_draw_msec = 0


func draw(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	if canvas == null:
		return
	_ensure_textures()
	_active_quality_scale = BattleRenderQuality.effect_scale(context)
	var boss_pos: Vector2 = _as_vector2(context.get("boss_pos", Vector2(330.0, 25.0)), Vector2(330.0, 25.0))
	var boss_size: Vector2 = _as_vector2(context.get("boss_paddle_size", Vector2(100.0, 40.0)), Vector2(100.0, 40.0))
	var boss_hitbox_height: float = float(context.get("boss_hitbox_height", boss_size.y))
	var center := Vector2(
		boss_pos.x + boss_size.x * 0.5,
		boss_pos.y + boss_hitbox_height * 0.5 + VISUAL_CENTER_Y_OFFSET
	) + shake_offset
	var dt := _consume_draw_delta()
	_update_motion_state(dt, center.x, context)
	var pose := _select_pose(context)
	var draw_size := _get_pose_draw_size(pose)
	center.y += _get_turn_hop_offset(draw_size.y)
	center += ElectricStunVisual.body_jitter(context)
	ElectrocutionFieldHost.drive_from_context(canvas, center, context)
	var inferno_active := bool(context.get("stage5_hongryun_inferno_active", false))
	var inferno_phase := int(context.get("stage5_hongryun_inferno_phase", 0))
	var hit_active := bool(context.get("boss_hit_active", false))

	_draw_ground_shadow(
		canvas,
		center + Vector2(0.0, draw_size.y * 0.40),
		Vector2(maxf(42.0, draw_size.x * 0.58), 8.0)
	)
	# 2026-05-18 사용자 보고: phase 2(trail)에서는 보스 옆 inferno overlay가
	# trail VFX(ball 따라감)와 분리되어 stuck처럼 보임. Phase 2 시각 강조는
	# trail_fx_host에 전적으로 위임하고, boss_actor는 charge phase(보스가
	# 공을 잡고 응축하는 시점)에만 inferno aura/dragon_head 오버레이를 그림.
	if inferno_active and inferno_phase == 1:
		_draw_inferno_aura(canvas, center, inferno_phase)
	var drawn := _draw_pose(canvas, context, pose, center, draw_size, ElectricStunVisual.body_modulate(context))
	if drawn and (hit_active or bool(context.get("stage5_hongryun_boss_throwing", false))):
		_draw_pose(canvas, context, pose, center, draw_size, Color(1.0, 0.24, 0.12, 0.28))
	if not drawn:
		_draw_fallback(canvas, center, draw_size, hit_active, inferno_active)
	if inferno_active and inferno_phase == 1:
		_draw_dragon_head(canvas, context, center)
	_draw_status_overlays(canvas, context, boss_pos, boss_size, boss_hitbox_height, shake_offset)


func get_asset_status() -> Dictionary:
	_ensure_textures()
	return {
		"stage5_hongryun_walk": walk_texture != null,
		"stage5_hongryun_attack": attack_texture != null,
		"stage5_hongryun_dash": dash_texture != null,
		"stage5_hongryun_turn": turn_texture != null,
		"stage5_hongryun_dragon_head": dragon_head_texture != null,
		"frame_count": FRAME_COUNT,
		"turn_frame_count": TURN_FRAME_COUNT,
		"turn_pose_visible": TURN_POSE_VISIBLE,
		"dragon_head_frame_count": DRAGON_HEAD_FRAME_COUNT,
	}


func get_debug_selected_texture_paths(context: Dictionary = {}) -> Dictionary:
	_ensure_textures()
	return {
		"walk": _texture_path(_get_pose_texture(context, "walk")),
		"attack": _texture_path(_get_pose_texture(context, "attack")),
		"dash": _texture_path(_get_pose_texture(context, "dash")),
		"turn": _texture_path(_get_pose_texture(context, "turn")),
	}


func get_debug_frame_geometry() -> Dictionary:
	_ensure_textures()
	return {
		"walk_source_rect": _get_pose_source_rect(walk_texture, "walk", 0),
		"attack_source_rect": _get_pose_source_rect(attack_texture, "attack", 0),
		"dash_source_rect": _get_pose_source_rect(dash_texture, "dash", 0),
		"turn_source_rect": _get_pose_source_rect(turn_texture, "turn", 0),
		"walk_draw_size": DEFAULT_DRAW_SIZE,
		"attack_draw_size": ATTACK_DRAW_SIZE,
		"dash_draw_size": DASH_DRAW_SIZE,
	}


func _ensure_textures() -> void:
	if textures_loaded:
		return
	prewarm_assets()


func _select_pose(context: Dictionary) -> Dictionary:
	if bool(context.get("boss_dash_active", false)):
		return {
			"key": "dash",
			"frame": int(context.get("boss_dash_frame", _time_frame(DASH_FRAME_INTERVAL_SEC))) % FRAME_COUNT,
			"flip_h": int(context.get("boss_dash_direction", _facing)) < 0,
		}
	if bool(context.get("stage5_hongryun_boss_throwing", false)):
		var progress := clampf(float(context.get("stage5_hongryun_boss_throw_progress", -1.0)), 0.0, 1.0)
		var frame := int(floor(progress * float(FRAME_COUNT))) if progress >= 0.0 else _time_frame(ATTACK_FRAME_INTERVAL_SEC)
		return {
			"key": "attack",
			"frame": clampi(frame, 0, FRAME_COUNT - 1),
			"flip_h": _facing < 0,
		}
	if bool(context.get("boss_hit_active", false)):
		return {
			"key": "attack",
			"frame": int(context.get("boss_hit_frame", _time_frame(ATTACK_FRAME_INTERVAL_SEC))) % FRAME_COUNT,
			"flip_h": _facing < 0,
		}
	return {
		"key": "walk",
		"frame": int(context.get("boss_sprite_frame", _time_frame(WALK_FRAME_INTERVAL_SEC))) % FRAME_COUNT if _is_moving else 0,
		"flip_h": _facing < 0,
	}


func _get_pose_draw_size(pose: Dictionary) -> Vector2:
	match str(pose.get("key", "walk")):
		"attack":
			return ATTACK_DRAW_SIZE
		"dash":
			return DASH_DRAW_SIZE
	return DEFAULT_DRAW_SIZE


func _draw_pose(canvas: CanvasItem, context: Dictionary, pose: Dictionary, center: Vector2, draw_size: Vector2, modulate: Color) -> bool:
	var texture := _get_pose_texture(context, str(pose.get("key", "walk")))
	if texture == null:
		return false
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return false
	var pose_key := str(pose.get("key", "walk"))
	var frame := clampi(int(pose.get("frame", 0)), 0, _get_pose_frame_count(pose_key) - 1)
	var source_rect := _get_pose_source_rect(texture, pose_key, frame)
	var target_rect := Rect2(center - draw_size * 0.5, draw_size)
	if bool(pose.get("flip_h", false)):
		_draw_flipped_texture_region(canvas, texture, source_rect, target_rect, modulate)
	else:
		canvas.draw_texture_rect_region(texture, target_rect, source_rect, modulate, false, true)
	return true


func _get_pose_texture(_context: Dictionary, key: String) -> Texture2D:
	match key:
		"attack":
			return attack_texture
		"dash":
			return dash_texture
		"turn":
			return turn_texture
	return walk_texture


func _get_pose_source_rect(texture: Texture2D, key: String, frame: int) -> Rect2:
	if texture == null:
		return Rect2()
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Rect2()
	var cols := _get_pose_sheet_cols(key)
	var rows := _get_pose_sheet_rows(key)
	var cell_size := Vector2(texture_size.x / float(cols), texture_size.y / float(rows))
	var frame_idx := clampi(frame, 0, _get_pose_frame_count(key) - 1)
	var col := frame_idx % cols
	@warning_ignore("integer_division")
	var row := int(frame_idx / cols)
	var cell_origin := Vector2(float(col) * cell_size.x, float(row) * cell_size.y)
	if key == "walk" and cell_size.x >= WALK_SOURCE_SIZE.x and cell_size.y >= WALK_SOURCE_SIZE.y:
		return Rect2(
			cell_origin + Vector2(WALK_SOURCE_INSET_X, WALK_SOURCE_INSET_Y),
			Vector2(
				minf(WALK_SOURCE_SIZE.x, cell_size.x - WALK_SOURCE_INSET_X),
				minf(WALK_SOURCE_SIZE.y, cell_size.y - WALK_SOURCE_INSET_Y)
			)
		)
	return Rect2(cell_origin, cell_size)


func _get_pose_sheet_cols(key: String) -> int:
	if key == "turn":
		return TURN_SHEET_COLS
	return SHEET_COLS


func _get_pose_sheet_rows(key: String) -> int:
	if key == "turn":
		return TURN_SHEET_ROWS
	return SHEET_ROWS


func _get_pose_frame_count(key: String) -> int:
	if key == "turn":
		return TURN_FRAME_COUNT
	return FRAME_COUNT


func _texture_path(texture: Texture2D) -> String:
	if texture == null:
		return ""
	return str(texture.resource_path)


func _draw_dragon_head(canvas: CanvasItem, context: Dictionary, boss_center: Vector2) -> void:
	if dragon_head_texture == null:
		canvas.draw_arc(boss_center + Vector2(0.0, -78.0), 44.0, 0.0, TAU, 48, Color(1.0, 0.12, 0.03, 0.72), 3.0, true)
		return
	var texture_size := dragon_head_texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var elapsed := float(context.get("stage5_hongryun_inferno_trail_elapsed_sec", time_sec))
	var frame := int(floor(elapsed / DRAGON_HEAD_FRAME_INTERVAL_SEC)) % DRAGON_HEAD_FRAME_COUNT
	var cell_w := texture_size.x / float(DRAGON_HEAD_FRAME_COUNT)
	var source_rect := Rect2(float(frame) * cell_w, 0.0, cell_w, texture_size.y)
	var pulse := 1.0 + sin(time_sec * 9.0) * 0.05
	var draw_size := DRAGON_HEAD_DRAW_SIZE * pulse
	var center := boss_center + Vector2(0.0, -64.0)
	var target_rect := Rect2(center - draw_size * 0.5, draw_size)
	if _facing < 0:
		_draw_flipped_texture_region(canvas, dragon_head_texture, source_rect, target_rect, Color(1.0, 0.48, 0.24, 0.92))
	else:
		canvas.draw_texture_rect_region(dragon_head_texture, target_rect, source_rect, Color(1.0, 0.48, 0.24, 0.92), false, true)


func _draw_inferno_aura(canvas: CanvasItem, center: Vector2, inferno_phase: int) -> void:
	var pulse := 0.5 + 0.5 * sin(time_sec * (8.0 if inferno_phase == 1 else 4.0))
	var radius := 74.0 + pulse * (18.0 if inferno_phase == 1 else 10.0)
	canvas.draw_circle(center + Vector2(0.0, 3.0), radius, Color(1.0, 0.08, 0.02, 0.12))
	canvas.draw_arc(center, radius * 0.82, time_sec * 2.0, time_sec * 2.0 + PI * 1.2, 48, Color(1.0, 0.46, 0.13, 0.42), 2.0, true)


func _draw_ground_shadow(canvas: CanvasItem, center: Vector2, size: Vector2) -> void:
	var points := PackedVector2Array()
	var segment_count := 18 if _active_quality_scale > 0.6 else 12
	for idx in range(segment_count):
		var angle := TAU * float(idx) / float(segment_count)
		points.append(center + Vector2(cos(angle) * size.x, sin(angle) * size.y))
	canvas.draw_colored_polygon(points, Color(0.0, 0.0, 0.0, 0.24))


func _draw_fallback(canvas: CanvasItem, center: Vector2, draw_size: Vector2, hit_active: bool, inferno_active: bool) -> void:
	var body_color := Color(0.62, 0.11, 0.07, 1.0) if inferno_active else Color(0.36, 0.11, 0.08, 1.0)
	if hit_active:
		body_color = Color(0.92, 0.22, 0.08, 1.0)
	var body := PackedVector2Array([
		center + Vector2(-draw_size.x * 0.28, -draw_size.y * 0.24),
		center + Vector2(draw_size.x * 0.26, -draw_size.y * 0.24),
		center + Vector2(draw_size.x * 0.36, draw_size.y * 0.22),
		center + Vector2(draw_size.x * 0.14, draw_size.y * 0.42),
		center + Vector2(-draw_size.x * 0.18, draw_size.y * 0.40),
		center + Vector2(-draw_size.x * 0.38, draw_size.y * 0.22),
	])
	canvas.draw_colored_polygon(body, body_color)
	canvas.draw_polyline(body, Color(1.0, 0.56, 0.18, 0.72), 2.0, true)
	canvas.draw_circle(center + Vector2(0.0, -draw_size.y * 0.36), 18.0, Color(0.85, 0.52, 0.36, 1.0))
	canvas.draw_line(center + Vector2(-10.0, -draw_size.y * 0.36), center + Vector2(-3.0, -draw_size.y * 0.37), Color(1.0, 0.92, 0.22, 0.9), 2.0, true)
	canvas.draw_line(center + Vector2(3.0, -draw_size.y * 0.37), center + Vector2(10.0, -draw_size.y * 0.36), Color(1.0, 0.92, 0.22, 0.9), 2.0, true)


func _draw_status_overlays(
	canvas: CanvasItem,
	context: Dictionary,
	boss_pos: Vector2,
	boss_size: Vector2,
	boss_hitbox_height: float,
	shake_offset: Vector2
) -> void:
	if status_overlay_renderer != null and status_overlay_renderer.has_method("draw_boss_status_overlays"):
		status_overlay_renderer.draw_boss_status_overlays(canvas, context, boss_pos, boss_size, boss_hitbox_height, shake_offset)
	elif status_overlay_renderer != null and status_overlay_renderer.has_method("draw_boss_cooldown_pause_marker"):
		status_overlay_renderer.draw_boss_cooldown_pause_marker(canvas, context, boss_pos, boss_size, boss_hitbox_height, shake_offset)


func _update_motion_state(delta: float, center_x: float, context: Dictionary) -> void:
	var previous_facing := _facing
	if _last_center_x < INF:
		var dx := center_x - _last_center_x
		if absf(dx) > MOVING_THRESHOLD:
			_facing = -1 if dx < 0.0 else 1
			_move_release_time = MOVE_RELEASE_SEC
			_is_moving = true
	if bool(context.get("boss_is_walking", false)):
		_is_moving = true
		_move_release_time = MOVE_RELEASE_SEC
	else:
		_move_release_time = maxf(0.0, _move_release_time - delta)
		_is_moving = _move_release_time > 0.0
	if previous_facing != _facing:
		_turn_active = true
		_turn_time = 0.0
	if _turn_active:
		_turn_time += delta
		if _turn_time >= TURN_DURATION_SEC:
			_turn_active = false
	_last_center_x = center_x


func _get_turn_hop_offset(rendered_height: float) -> float:
	if not _turn_active or TURN_DURATION_SEC <= 0.0:
		return 0.0
	var progress: float = clampf(_turn_time / TURN_DURATION_SEC, 0.0, 1.0)
	return -maxf(1.0, rendered_height * TURN_HOP_HEIGHT_RATIO) * sin(PI * progress)


func _consume_draw_delta() -> float:
	var now := Time.get_ticks_msec()
	if _last_draw_msec <= 0:
		_last_draw_msec = now
		time_sec += 1.0 / 60.0
		return 1.0 / 60.0
	var delta := clampf(float(now - _last_draw_msec) / 1000.0, 0.0, 0.1)
	_last_draw_msec = now
	time_sec += delta
	return delta


func _time_frame(interval_sec: float) -> int:
	return int(floor(time_sec / maxf(0.001, interval_sec)))


func _draw_flipped_texture_region(
	canvas: CanvasItem,
	texture: Texture2D,
	source_rect: Rect2,
	target_rect: Rect2,
	modulate: Color
) -> void:
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var points := PackedVector2Array([
		target_rect.position,
		Vector2(target_rect.end.x, target_rect.position.y),
		target_rect.end,
		Vector2(target_rect.position.x, target_rect.end.y),
	])
	var uv_min := Vector2(source_rect.position.x / texture_size.x, source_rect.position.y / texture_size.y)
	var uv_max := Vector2(source_rect.end.x / texture_size.x, source_rect.end.y / texture_size.y)
	var uvs := PackedVector2Array([
		Vector2(uv_max.x, uv_min.y),
		Vector2(uv_min.x, uv_min.y),
		Vector2(uv_min.x, uv_max.y),
		Vector2(uv_max.x, uv_max.y),
	])
	var colors := PackedColorArray([modulate, modulate, modulate, modulate])
	canvas.draw_polygon(points, colors, uvs, texture)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
