extends RefCounted

# Stage 8 미노타우로스 boss actor renderer (Slice 1 bootable placeholder shell).
#
# Ported from stage7_akamu_boss_actor_renderer. Slice 1 preserves the public
# prewarm / draw / pose-selection / debug contract that the actor renderer +
# sibling playfield renderer call by name, but THINS the Akamu-specific combat
# channels (shadow clone, shuriken, cloud dash, escape, superspeed, wind-aura
# awakening) down to generic 9-pose selection + a code-native minotaur
# silhouette. Slice 2 drops the real 4x2 AutoSprite sheets into SHEET_PATHS and
# the sprite branch lights up automatically; Slice 5 restores earthquake combat.
#
# RESERVED-ASSET SAFETY (critical): the stage8 boss sheets do NOT exist yet.
# Every load in prewarm_assets_step() is guarded by ResourceLoader.exists(), so
# an absent sheet is skipped without a load error and WITHOUT the caller ever
# wiring a not-yet-generated res:// path into the per-frame draw. draw() is
# fully code-native (draw_rect / draw_polygon / draw_line / draw_circle /
# draw_string) — _textures stays empty until the art lands, so the placeholder
# minotaur is what renders every frame with zero filesystem re-stat.

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const StatusEffectOverlayRenderer := preload("res://scripts/status/status_effect_overlay_renderer.gd")

const SHEET_DIR := "res://assets/sprites/bosses/stage8_minotaur/"
const SHEET_PATHS := {
	"idle": SHEET_DIR + "stage8_minotaur_boss_idle.png",
	"walk_left": SHEET_DIR + "stage8_minotaur_boss_walk_left.png",
	"walk_right": SHEET_DIR + "stage8_minotaur_boss_walk_right.png",
	"attack": SHEET_DIR + "stage8_minotaur_boss_attack.png",
	"dash_left": SHEET_DIR + "stage8_minotaur_boss_dash_left.png",
	"dash_right": SHEET_DIR + "stage8_minotaur_boss_dash_right.png",
	"victory": SHEET_DIR + "stage8_minotaur_boss_victory.png",
	"defeat": SHEET_DIR + "stage8_minotaur_boss_defeat.png",
	"stun": SHEET_DIR + "stage8_minotaur_boss_stun.png",
}
const PREWARM_TEXTURE_KEYS := [
	"idle",
	"walk_left",
	"walk_right",
	"attack",
	"dash_left",
	"dash_right",
	"victory",
	"defeat",
	"stun",
]
const GRID_COLS := 4
const GRID_ROWS := 2
const FRAME_COUNT := GRID_COLS * GRID_ROWS
# DRAW_SIZE 결정: 원본(Python) 미노타우로스 소스 프레임은 백업 83x92(4시트, canonical)
# vs repo 72x80(2시트)로 갈렸다. 미노타우로스는 대형 프레임 보스(Tauren 83x92 급)
# 이므로 백업 83x92를 소스 종횡비의 기준으로 채택한다(0.902). 화면 렌더 크기는
# akamu(128x128)의 온스크린 존재감을 유지하되 그 0.902 종횡비를 보존해
# 128x142(=0.901)로 둔다. 세로로 살짝 큰 실루엣이 뿔 달린 대형 수인 실루엣을 살린다.
const DRAW_SIZE := Vector2(128.0, 142.0)
const VISUAL_CENTER_Y_OFFSET := 12.0
const MOVING_THRESHOLD := 0.12
const MOVE_RELEASE_SEC := 0.12
const FRAME_INTERVAL_SEC := {
	"idle": 0.16,
	"walk_left": 0.09,
	"walk_right": 0.09,
	"attack": 0.06,
	"dash_left": 0.08,
	"dash_right": 0.08,
	"victory": 0.11,
	"defeat": 0.11,
	"stun": 0.085,
}

# Code-native minotaur silhouette palette (Slice 1 placeholder only).
const BODY_COLOR := Color(0.34, 0.21, 0.14, 0.98)
const BODY_SHADE_COLOR := Color(0.22, 0.13, 0.09, 0.98)
const SHOULDER_COLOR := Color(0.29, 0.18, 0.12, 0.98)
const HORN_COLOR := Color(0.88, 0.83, 0.71, 0.98)
const SNOUT_COLOR := Color(0.52, 0.36, 0.28, 0.96)
const NOSTRIL_COLOR := Color(0.12, 0.08, 0.06, 0.92)
const EYE_COLOR := Color(0.96, 0.30, 0.16, 0.95)
const LABEL_COLOR := Color(0.92, 0.88, 0.80, 0.85)
const DEFEAT_BODY_COLOR := Color(0.20, 0.16, 0.14, 0.80)
const VICTORY_BODY_COLOR := Color(0.42, 0.27, 0.18, 0.98)
# Slice 5 그림자분신 계약용 틴트(Python stage8 parity BLEND_RGBA_MULT). Slice 1
# 에서는 시트가 없어 get_shadow_clone_frame_spec가 {}를 돌려주므로 미사용.
const SHADOW_CLONE_TINT := Color(150.0 / 255.0, 150.0 / 255.0, 180.0 / 255.0)

var status_overlay_renderer: Object = StatusEffectOverlayRenderer.new()
var _textures: Dictionary = {}
var _assets_prewarmed := false
var _prewarm_step_index := 0
var _last_center_x := INF
var _facing := 1
var _is_moving := false
var _move_release_sec := 0.0
var _last_msec := 0
var _time := 0.0


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if _assets_prewarmed:
		return true
	if _prewarm_step_index >= PREWARM_TEXTURE_KEYS.size():
		_assets_prewarmed = true
		_prewarm_step_index = 0
		return true
	var key: String = str(PREWARM_TEXTURE_KEYS[_prewarm_step_index])
	# RESERVED-ASSET GUARD: the stage8 sheets are not generated yet. Skip absent
	# paths so prewarm is a safe no-op — never load / re-stat a missing res://
	# every warmup step, and never leave a phantom entry in _textures. Slice 2
	# just adds the PNGs and this same guard promotes them with no code change.
	var sheet_path: String = str(SHEET_PATHS[key])
	if ResourceLoader.exists(sheet_path):
		# Prefer the editor-imported texture so warmup never decodes the source
		# PNG in-frame; the shared loader still falls back source-first on a
		# fresh checkout where the import artifact is genuinely absent.
		var texture: Object = ProjectResourceLoader.load_imported_texture(sheet_path)
		if texture is Texture2D:
			_textures[key] = texture
	_prewarm_step_index += 1
	if _prewarm_step_index >= PREWARM_TEXTURE_KEYS.size():
		_assets_prewarmed = true
		_prewarm_step_index = 0
		return true
	return false


func reset() -> void:
	_last_center_x = INF
	_facing = 1
	_is_moving = false
	_move_release_sec = 0.0
	_last_msec = 0
	_time = 0.0


func clear_transient_canvas_items() -> void:
	pass


func draw(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	if canvas == null:
		return
	var dt: float = _consume_dt()
	_time += dt
	var boss_pos: Vector2 = _as_vector2(context.get("boss_pos", Vector2(330.0, 25.0)), Vector2(330.0, 25.0))
	var boss_size: Vector2 = _as_vector2(context.get("boss_paddle_size", Vector2(100.0, 40.0)), Vector2(100.0, 40.0))
	var hitbox_h: float = float(context.get("boss_hitbox_height", boss_size.y))
	var center := Vector2(
		boss_pos.x + boss_size.x * 0.5,
		boss_pos.y + hitbox_h * 0.5 + VISUAL_CENTER_Y_OFFSET
	) + shake_offset
	_update_motion_state(dt, center.x, context)

	var dwarf_shrink: float = clampf(float(context.get("boss_paddle_shrink_scale", 1.0)), 0.2, 1.0)
	var draw_size := DRAW_SIZE * dwarf_shrink
	# Slice 1: _textures is always empty (sheets absent → prewarm guard skips
	# every load), so the code-native placeholder is what renders every frame.
	# Slice 2 populates _textures and the sprite branch takes over unchanged.
	if not _assets_prewarmed or _textures.is_empty():
		_draw_placeholder_actor(canvas, context, center, draw_size)
	else:
		var pose: Dictionary = _select_pose(context)
		_draw_sprite_pose(canvas, pose, context, center, draw_size)
	_draw_status_overlays(canvas, context, boss_pos, boss_size, hitbox_h, shake_offset)


func get_asset_status() -> Dictionary:
	var status: Dictionary = {}
	var all_loaded := true
	for key_value in PREWARM_TEXTURE_KEYS:
		var key := str(key_value)
		var loaded: bool = _textures.get(key, null) is Texture2D
		status["stage8_minotaur_" + key] = loaded
		all_loaded = all_loaded and loaded
	status["stage8_minotaur_walk"] = bool(status.get("stage8_minotaur_walk_left", false)) \
		and bool(status.get("stage8_minotaur_walk_right", false))
	status["prewarm_complete"] = _assets_prewarmed
	status["generated_art_loaded"] = all_loaded
	status["uses_code_native_placeholder"] = _textures.is_empty()
	return status


func get_imagegen_asset_status() -> Dictionary:
	return get_asset_status()


func get_debug_sheet_paths() -> Dictionary:
	return SHEET_PATHS.duplicate()


func get_debug_grid_contract() -> Dictionary:
	return {
		"cols": GRID_COLS,
		"rows": GRID_ROWS,
		"frame_count": FRAME_COUNT,
		"draw_size": DRAW_SIZE,
	}


func get_debug_selected_pose(context: Dictionary) -> Dictionary:
	return _select_pose(context).duplicate()


func get_debug_source_rect(state: String, frame: int) -> Rect2:
	var texture_value: Variant = _textures.get(state, null)
	if not (texture_value is Texture2D):
		return Rect2()
	return _get_source_rect(texture_value as Texture2D, frame)


# Slice 5 그림자분신 계약(그림자분신은 보스의 "현재" 포즈 프레임을 어둡고 반투명한
# 틴트로 복제). Slice 1 미노타우로스는 아직 분신 스킬이 없고 시트도 없어 항상 {}를
# 돌려주며, 이때 sibling playfield 렌더러는 코드-네이티브 폴백을 유지한다.
func get_shadow_clone_frame_spec(context: Dictionary) -> Dictionary:
	if not _assets_prewarmed:
		return {}
	var pose: Dictionary = _select_pose(context)
	var texture_value: Variant = _textures.get(str(pose.get("key", "idle")), null)
	if not (texture_value is Texture2D):
		texture_value = _textures.get("idle", null)
	if not (texture_value is Texture2D):
		return {}
	var texture: Texture2D = texture_value as Texture2D
	return {
		"texture": texture,
		"source_rect": _get_source_rect(texture, int(pose.get("frame", 0))),
		"tint": SHADOW_CLONE_TINT,
	}


func _select_pose(context: Dictionary) -> Dictionary:
	if bool(context.get("boss_defeat_active", false)):
		return {"key": "defeat", "frame": _result_frame(context, "boss_defeat_frame")}
	if bool(context.get("boss_victory_active", false)):
		return {"key": "victory", "frame": _result_frame(context, "boss_victory_frame")}
	if _is_stunned(context):
		return {"key": "stun", "frame": _stun_frame(context)}
	if _is_dash_active(context):
		var dash_direction: int = int(context.get("boss_facing", 0))
		if dash_direction == 0:
			dash_direction = _facing
		var dash_key := "dash_left" if dash_direction < 0 else "dash_right"
		return {"key": dash_key, "frame": _dash_frame(context, dash_key)}
	if _is_attack_active(context):
		return {"key": "attack", "frame": _attack_frame(context)}
	if _is_moving or bool(context.get("boss_is_walking", false)):
		var facing: int = int(context.get("boss_facing", _facing))
		if facing == 0:
			facing = _facing
		var walk_key := "walk_left" if facing < 0 else "walk_right"
		return {
			"key": walk_key,
			"frame": posmod(int(context.get("boss_sprite_frame", _loop_frame(walk_key))), FRAME_COUNT),
		}
	return {
		"key": "idle",
		"frame": posmod(int(context.get("boss_idle_frame", _loop_frame("idle"))), FRAME_COUNT),
	}


func _draw_sprite_pose(
	canvas: CanvasItem,
	pose: Dictionary,
	context: Dictionary,
	center: Vector2,
	draw_size: Vector2
) -> void:
	var key: String = str(pose.get("key", "idle"))
	var texture_value: Variant = _textures.get(key, null)
	if not (texture_value is Texture2D):
		texture_value = _textures.get("idle", null)
	if not (texture_value is Texture2D):
		return
	var intangible: bool = bool(context.get("stage8_minotaur_boss_ball_intangible", false))
	var alpha: float = 0.44 if intangible else 1.0
	var modulate := Color(1.0, 1.0, 1.0, alpha)
	var target_rect := Rect2(center - draw_size * 0.5, draw_size)
	canvas.draw_texture_rect_region(
		texture_value as Texture2D,
		target_rect,
		_get_source_rect(texture_value as Texture2D, int(pose.get("frame", 0))),
		modulate,
		false,
		true
	)


func _get_source_rect(texture: Texture2D, frame: int) -> Rect2:
	if texture == null:
		return Rect2()
	var texture_size: Vector2 = texture.get_size()
	var cell_size := Vector2(
		texture_size.x / float(GRID_COLS),
		texture_size.y / float(GRID_ROWS)
	)
	var safe_frame := posmod(frame, FRAME_COUNT)
	return Rect2(
		Vector2(float(safe_frame % GRID_COLS), float(safe_frame / GRID_COLS)) * cell_size,
		cell_size
	)


func _is_stunned(context: Dictionary) -> bool:
	return bool(context.get("active_item_boss_stun_active", false)) \
		or bool(context.get("status_boss_stun_active", false)) \
		or bool(context.get("ragnarok_hammer_boss_stun_active", false)) \
		or bool(context.get("boss_electric_stun_active", false))


func _is_dash_active(context: Dictionary) -> bool:
	return bool(context.get("boss_dash_active", false))


func _is_attack_active(context: Dictionary) -> bool:
	return bool(context.get("stage8_minotaur_boss_attack_active", false)) \
		or bool(context.get("boss_hit_active", false))


func _result_frame(context: Dictionary, primary_key: String) -> int:
	return clampi(
		int(context.get(primary_key, context.get("boss_result_frame", _loop_frame("defeat")))),
		0,
		FRAME_COUNT - 1
	)


func _stun_frame(context: Dictionary) -> int:
	if context.has("active_item_boss_stun_frame"):
		return posmod(int(context.get("active_item_boss_stun_frame", 0)), FRAME_COUNT)
	return _loop_frame("stun")


func _dash_frame(context: Dictionary, dash_key: String = "dash_right") -> int:
	if context.has("boss_dash_frame"):
		return posmod(int(context.get("boss_dash_frame", 0)), FRAME_COUNT)
	return _loop_frame(dash_key)


func _attack_frame(context: Dictionary) -> int:
	if context.has("boss_hit_frame") and bool(context.get("boss_hit_active", false)):
		return posmod(int(context.get("boss_hit_frame", 0)), FRAME_COUNT)
	# Generic windup→peak→recovery mapping: play the whole 8-frame swing exactly
	# once across the attack window (progress = 1 - remaining/total) so the arc
	# never clips. Slice 5 minotaur combat feeds these keys.
	var attack_total: float = float(context.get("stage8_minotaur_boss_attack_total", 0.0))
	if attack_total > 0.0:
		var remaining: float = float(context.get("stage8_minotaur_boss_attack_remaining", 0.0))
		var attack_progress: float = clampf(1.0 - remaining / attack_total, 0.0, 1.0)
		return clampi(floori(attack_progress * float(FRAME_COUNT)), 0, FRAME_COUNT - 1)
	return _loop_frame("attack")


func _loop_frame(state: String) -> int:
	var interval: float = float(FRAME_INTERVAL_SEC.get(state, 0.1))
	return int(_time / maxf(0.001, interval)) % FRAME_COUNT


func _update_motion_state(dt: float, center_x: float, context: Dictionary) -> void:
	var declared_facing: int = int(context.get("boss_facing", _facing))
	if declared_facing != 0:
		_facing = -1 if declared_facing < 0 else 1
	if is_inf(_last_center_x):
		_last_center_x = center_x
		_is_moving = bool(context.get("boss_is_walking", false))
		if _is_moving:
			_move_release_sec = MOVE_RELEASE_SEC
		return
	var delta_x: float = center_x - _last_center_x
	if absf(delta_x) > MOVING_THRESHOLD:
		_facing = -1 if delta_x < 0.0 else 1
		_is_moving = true
		_move_release_sec = MOVE_RELEASE_SEC
	elif bool(context.get("boss_is_walking", false)):
		_is_moving = true
		_move_release_sec = MOVE_RELEASE_SEC
	else:
		_move_release_sec = maxf(0.0, _move_release_sec - dt)
		if _move_release_sec <= 0.0:
			_is_moving = false
	_last_center_x = center_x


# Code-native minotaur silhouette. Fully vector-drawn so no reserved stage8
# res:// path is ever touched on the draw path. Reads only generic pose keys
# (defeat / victory / attack / intangible) — no Akamu combat channels remain.
func _draw_placeholder_actor(canvas: CanvasItem, context: Dictionary, center: Vector2, draw_size: Vector2) -> void:
	var attack_active: bool = bool(context.get("stage8_minotaur_boss_attack_active", false)) \
		or bool(context.get("boss_hit_active", false))
	var intangible_alpha: float = 0.44 if bool(context.get("stage8_minotaur_boss_ball_intangible", false)) else 1.0
	var attack_target_x: float = float(context.get("stage8_minotaur_boss_attack_target_x", center.x + 1.0))
	var attack_direction := -1.0 if attack_target_x < center.x else 1.0
	var pose_center: Vector2 = center + Vector2(attack_direction * 4.0, 0.0) if attack_active else center

	var body_color := BODY_COLOR
	if bool(context.get("boss_defeat_active", false)):
		body_color = DEFEAT_BODY_COLOR
	elif bool(context.get("boss_victory_active", false)):
		body_color = VICTORY_BODY_COLOR
	body_color.a *= intangible_alpha
	var shade_color := BODY_SHADE_COLOR
	shade_color.a *= intangible_alpha
	var shoulder_color := SHOULDER_COLOR
	shoulder_color.a *= intangible_alpha

	# Layout (back-to-front): legs → torso → shoulders → head → horns → snout →
	# nostrils → eyes → label.
	var torso_w: float = draw_size.x * 0.60
	var torso_h: float = draw_size.y * 0.42
	var torso_cy: float = pose_center.y + draw_size.y * 0.16
	var torso_top: float = torso_cy - torso_h * 0.5
	var torso_bottom: float = torso_cy + torso_h * 0.5

	var leg_w: float = draw_size.x * 0.20
	var leg_h: float = draw_size.y * 0.22
	var leg_y: float = torso_bottom - leg_h * 0.25
	canvas.draw_rect(Rect2(pose_center.x - torso_w * 0.30 - leg_w * 0.5, leg_y, leg_w, leg_h), shade_color)
	canvas.draw_rect(Rect2(pose_center.x + torso_w * 0.30 - leg_w * 0.5, leg_y, leg_w, leg_h), shade_color)

	canvas.draw_rect(Rect2(pose_center.x - torso_w * 0.5, torso_top, torso_w, torso_h), body_color)

	var shoulder_w: float = draw_size.x * 0.74
	var shoulder_h: float = draw_size.y * 0.14
	canvas.draw_rect(
		Rect2(pose_center.x - shoulder_w * 0.5, torso_top - shoulder_h * 0.4, shoulder_w, shoulder_h),
		shoulder_color
	)

	var head_w: float = draw_size.x * 0.46
	var head_h: float = draw_size.y * 0.30
	var head_cy: float = pose_center.y - draw_size.y * 0.26
	var head_top: float = head_cy - head_h * 0.5
	canvas.draw_rect(Rect2(pose_center.x - head_w * 0.5, head_top, head_w, head_h), body_color)

	# Horns — two static triangles (always triangulable) sweeping up and out.
	var horn_color := HORN_COLOR
	horn_color.a *= intangible_alpha
	var left_horn := PackedVector2Array([
		Vector2(pose_center.x - head_w * 0.26, head_top + head_h * 0.08),
		Vector2(pose_center.x - head_w * 0.52, head_top + head_h * 0.02),
		Vector2(pose_center.x - head_w * 0.84, head_top - head_h * 0.62),
	])
	var right_horn := PackedVector2Array([
		Vector2(pose_center.x + head_w * 0.26, head_top + head_h * 0.08),
		Vector2(pose_center.x + head_w * 0.52, head_top + head_h * 0.02),
		Vector2(pose_center.x + head_w * 0.84, head_top - head_h * 0.62),
	])
	canvas.draw_colored_polygon(left_horn, horn_color)
	canvas.draw_colored_polygon(right_horn, horn_color)

	# Snout / muzzle.
	var snout_w: float = head_w * 0.54
	var snout_h: float = head_h * 0.34
	var snout_color := SNOUT_COLOR
	snout_color.a *= intangible_alpha
	var snout_top: float = head_cy + head_h * 0.10
	canvas.draw_rect(Rect2(pose_center.x - snout_w * 0.5, snout_top, snout_w, snout_h), snout_color)
	var nostril_color := NOSTRIL_COLOR
	nostril_color.a *= intangible_alpha
	var nostril_r: float = maxf(1.5, draw_size.x * 0.022)
	var nostril_y: float = snout_top + snout_h * 0.55
	canvas.draw_circle(Vector2(pose_center.x - snout_w * 0.22, nostril_y), nostril_r, nostril_color)
	canvas.draw_circle(Vector2(pose_center.x + snout_w * 0.22, nostril_y), nostril_r, nostril_color)

	# Eyes — pulsing red glow.
	var pulse: float = 0.72 + 0.28 * sin(_time * 3.2)
	var eye_color := Color(EYE_COLOR.r, EYE_COLOR.g, EYE_COLOR.b, EYE_COLOR.a * pulse * intangible_alpha)
	var eye_dx: float = head_w * 0.22
	var eye_y: float = head_cy - head_h * 0.06
	var eye_r: float = maxf(2.5, draw_size.x * 0.045)
	canvas.draw_circle(Vector2(pose_center.x - eye_dx, eye_y), eye_r, eye_color)
	canvas.draw_circle(Vector2(pose_center.x + eye_dx, eye_y), eye_r, eye_color)

	# Placeholder label (ASCII — fallback font may not cover Hangul).
	var font: Font = ThemeDB.fallback_font
	if font != null:
		var label_color := LABEL_COLOR
		label_color.a *= intangible_alpha
		var label_w: float = draw_size.x
		canvas.draw_string(
			font,
			Vector2(pose_center.x - label_w * 0.5, center.y + draw_size.y * 0.5 + 12.0),
			"STAGE 8 MINOTAUR",
			HORIZONTAL_ALIGNMENT_CENTER,
			label_w,
			11,
			label_color
		)


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


func _consume_dt() -> float:
	var now := Time.get_ticks_msec()
	if _last_msec == 0:
		_last_msec = now
		return 0.0
	var delta := float(now - _last_msec) / 1000.0
	_last_msec = now
	return clampf(delta, 0.0, 0.1)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
