extends RefCounted

# Stage 7 Akamu Rigo boss actor renderer.
#
# The eight native 4x2 sheets are prewarmed one texture per loading step. The
# code-native actor remains only as the short loading fallback; once prewarm is
# complete every runtime pose is selected from the promoted AutoSprite set.

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const StatusEffectOverlayRenderer := preload("res://scripts/status/status_effect_overlay_renderer.gd")

const SHEET_DIR := "res://assets/sprites/bosses/stage7_akamu/"
const SHEET_PATHS := {
	"idle": SHEET_DIR + "stage7_akamu_boss_idle.png",
	"walk_left": SHEET_DIR + "stage7_akamu_boss_walk_left.png",
	"walk_right": SHEET_DIR + "stage7_akamu_boss_walk_right.png",
	"attack": SHEET_DIR + "stage7_akamu_boss_attack.png",
	"dash_left": SHEET_DIR + "stage7_akamu_boss_dash_left.png",
	"dash_right": SHEET_DIR + "stage7_akamu_boss_dash_right.png",
	"victory": SHEET_DIR + "stage7_akamu_boss_victory.png",
	"defeat": SHEET_DIR + "stage7_akamu_boss_defeat.png",
	"stun": SHEET_DIR + "stage7_akamu_boss_stun.png",
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
const DRAW_SIZE := Vector2(128.0, 128.0)
const VISUAL_CENTER_Y_OFFSET := 12.0
const MOVING_THRESHOLD := 0.12
const MOVE_RELEASE_SEC := 0.12
const FRAME_INTERVAL_SEC := {
	"idle": 0.16,
	"walk_left": 0.09,
	"walk_right": 0.09,
	"attack": 0.06,
	# 원본 stage8dash 파리티: 방향별 2프레임 런지를 0.08s 간격으로 교차 재생
	# (시트는 A,B 타일링 4x2). 원본 코드의 좌우 스왑 결함은 아트 기준으로 교정.
	"dash_left": 0.08,
	"dash_right": 0.08,
	"victory": 0.11,
	"defeat": 0.11,
	"stun": 0.085,
}
const HOOD_COLOR := Color(0.12, 0.15, 0.23, 0.98)
const MASK_COLOR := Color(0.30, 0.34, 0.42, 0.96)
const EYE_COLOR := Color(0.86, 0.30, 0.22, 0.95)
const AWAKENED_COLOR := Color(0.46, 0.88, 1.0, 0.62)
const SUPERSPEED_AURA_COLOR := Color(1.0, 0.34, 0.08, 0.90)
const SUPERSPEED_HOOD_COLOR := Color(0.075, 0.025, 0.095, 0.98)
const SUPERSPEED_MASK_COLOR := Color(0.24, 0.10, 0.14, 0.98)
const SUPERSPEED_EYE_COLOR := Color(1.0, 0.46, 0.10, 1.0)
const ATTACK_HOOD_COLOR := Color(0.28, 0.16, 0.42, 0.98)
const ATTACK_STEEL_COLOR := Color(0.82, 0.90, 1.0, 0.92)
const SUPERSPEED_SPRITE_MODULATE := Color(1.0, 0.58, 0.42, 1.0)
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
var _wind_aura_superspeed := false


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
	# Prefer the editor-imported texture so loading never decodes the source PNG
	# in the warmup frame. The shared loader still falls back to source-first
	# when an import artifact is genuinely unavailable (fresh checkout/tests).
	_textures[key] = ProjectResourceLoader.load_imported_texture(str(SHEET_PATHS[key]))
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
	_wind_aura_superspeed = false


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
	var wind_aura := _as_dictionary(context.get("stage7_akamu_wind_aura", {}))
	var wind_aura_active: bool = not wind_aura.is_empty() and bool(wind_aura.get("active", false))
	var wind_aura_depleted: bool = bool(wind_aura.get("depleted", false))
	_wind_aura_superspeed = bool(wind_aura.get(
		"superspeed",
		context.get("stage7_akamu_superspeed_active", false)
	))
	# The physical wind shield owns the ring. Awakening alone no longer leaves
	# an always-on ring behind while the five-hit shield is depleted.
	if wind_aura_active and not wind_aura_depleted:
		_draw_awakened_aura(canvas, center, draw_size)
	if not _assets_prewarmed:
		_draw_placeholder_actor(canvas, context, center, draw_size)
	else:
		var pose: Dictionary = _select_pose(context)
		_draw_sprite_pose(canvas, pose, context, center, draw_size)
	# 원본 파리티(2026-07-11): 바람 오오라 내구 피드백은 점 카운터가 아니라
	# 오라 자체가 남은 횟수에 비례해 약해지는 것(playfield 오라 strength
	# 스케일)이다. 점 5개 + 재충전 바 오버레이는 원본에 없어 제거했고,
	# 소진 중 재충전 진행은 playfield 오라의 회색 링 + 진행 아크가 담당한다.
	_draw_status_overlays(canvas, context, boss_pos, boss_size, hitbox_h, shake_offset)


func get_asset_status() -> Dictionary:
	var status: Dictionary = {}
	var all_loaded := true
	for key_value in PREWARM_TEXTURE_KEYS:
		var key := str(key_value)
		var loaded: bool = _textures.get(key, null) is Texture2D
		status["stage7_akamu_" + key] = loaded
		all_loaded = all_loaded and loaded
	status["stage7_akamu_walk"] = bool(status.get("stage7_akamu_walk_left", false)) \
		and bool(status.get("stage7_akamu_walk_right", false))
	status["prewarm_complete"] = _assets_prewarmed
	status["generated_art_loaded"] = all_loaded
	status["uses_code_native_placeholder"] = not _assets_prewarmed
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


# 그림자분신은 보스의 "현재" 포즈 프레임을 어둡고 반투명한 틴트로 복제한다
# (Python stage8 parity: stage8_boss_sprite.get_current_frame +
# BLEND_RGBA_MULT(150,150,180)). 시트 프리웜 전에는 {}를 돌려주어
# 플레이필드 렌더러가 코드-네이티브 로딩 폴백을 유지한다.
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
		# 원본 파리티: 대시는 방향별 시트. 극정호신 대시 방향 → 선언된 facing
		# → 이동 추적 facing 순으로 해석한다.
		var dash_direction: int = clampi(
			int(context.get("stage7_akamu_superspeed_dash_direction", 0)),
			-1,
			1
		)
		if dash_direction == 0:
			var declared_facing: int = int(context.get("boss_facing", 0))
			dash_direction = declared_facing if declared_facing != 0 else _facing
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
	var intangible: bool = bool(context.get("stage7_akamu_boss_ball_intangible", false))
	var alpha: float = 0.44 if intangible else 1.0
	var modulate := Color(1.0, 1.0, 1.0, alpha)
	if bool(context.get("stage7_akamu_superspeed_active", false)):
		modulate = Color(
			SUPERSPEED_SPRITE_MODULATE.r,
			SUPERSPEED_SPRITE_MODULATE.g,
			SUPERSPEED_SPRITE_MODULATE.b,
			alpha
		)
	var target_rect := Rect2(center - draw_size * 0.5, draw_size)
	canvas.draw_texture_rect_region(
		texture_value as Texture2D,
		target_rect,
		_get_source_rect(texture_value as Texture2D, int(pose.get("frame", 0))),
		modulate,
		false,
		true
	)
	# 원본 파리티(2026-07-11): 무형은 판정 전용 — 파란 펄스 사각 아웃라인은
	# 128 셀 기준이라 몸보다 큰 "사각 그리드"로 읽혀 제거(분신/구름 시전 중
	# 리포트). 반투명 알파(0.44)만 무형 피드백으로 유지한다.
	# 승격된 공격 시트가 공격 모션 전체를 소유한다. 코드-네이티브 팔/검격
	# 오버레이는 프리웜 전 플레이스홀더 액터 전용 — 스프라이트 위에 겹치면
	# 원본에 없는 V자 잔상이 붙는다(2026-07-11 라이브 QA 리포트).


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
	var cloud_phase: String = str(context.get("stage7_akamu_cloud_dash_phase", ""))
	return bool(context.get("boss_dash_active", false)) \
		or cloud_phase in ["down", "up"] \
		or bool(context.get("stage7_akamu_superspeed_dash_active", false)) \
		or bool(context.get("stage7_akamu_escape_active", false))


func _is_attack_active(context: Dictionary) -> bool:
	return bool(context.get("stage7_akamu_boss_attack_active", false)) \
		or bool(context.get("boss_hit_active", false)) \
		or bool(context.get("stage7_akamu_clone_casting", false)) \
		or bool(context.get("stage7_akamu_shuriken_casting", false)) \
		or str(context.get("stage7_akamu_cloud_dash_phase", "")) == "pre"


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
	if bool(context.get("stage7_akamu_clone_casting", false)):
		var progress: float = clampf(float(context.get("stage7_akamu_clone_cast_progress", 0.0)), 0.0, 1.0)
		return clampi(floori(progress * float(FRAME_COUNT)), 0, FRAME_COUNT - 1)
	# 공격 시트는 windup→peak→recovery 핑퐁 8프레임 원샷. 고정 루프로 재생하면
	# 0.20초 창이 3~4프레임(정점)에서 끝나 스윙이 잘린다(사용자: "공격 모션 잘려보임").
	# 공격 창의 진행도(1 - remaining/total)에 8프레임을 매핑해 전체 스윙이 정확히
	# 한 번 재생되고 recovery까지 끝나게 한다.
	var attack_total: float = float(context.get("stage7_akamu_boss_attack_total", 0.0))
	if attack_total > 0.0:
		var remaining: float = float(context.get("stage7_akamu_boss_attack_remaining", 0.0))
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


func _draw_placeholder_actor(canvas: CanvasItem, context: Dictionary, center: Vector2, draw_size: Vector2) -> void:
	var attack_active: bool = bool(context.get("stage7_akamu_boss_attack_active", false)) \
		or bool(context.get("boss_hit_active", false)) \
		or bool(context.get("stage7_akamu_clone_casting", false))
	var superspeed_active: bool = bool(context.get("stage7_akamu_superspeed_active", false))
	var intangible_alpha: float = 0.44 if bool(context.get("stage7_akamu_boss_ball_intangible", false)) else 1.0
	var attack_target_x: float = float(context.get("stage7_akamu_boss_attack_target_x", center.x + 1.0))
	var attack_direction := -1.0 if attack_target_x < center.x else 1.0
	var pose_center: Vector2 = center + Vector2(attack_direction * 4.0, 0.0) if attack_active else center
	var body_rect := Rect2(pose_center - draw_size * 0.5, draw_size)
	var hood_color := HOOD_COLOR
	if bool(context.get("boss_defeat_active", false)):
		hood_color = Color(0.16, 0.16, 0.18, 0.72)
	elif bool(context.get("boss_victory_active", false)):
		hood_color = Color(0.20, 0.16, 0.30, 0.98)
	elif superspeed_active:
		hood_color = SUPERSPEED_HOOD_COLOR
	elif attack_active:
		hood_color = ATTACK_HOOD_COLOR
	elif bool(context.get("stage7_akamu_gameplay_freeze_active", false)):
		hood_color = Color(0.18, 0.30, 0.42, 0.98)
	hood_color.a *= intangible_alpha

	canvas.draw_rect(body_rect, hood_color)
	var mask_rect := Rect2(
		pose_center + Vector2(-draw_size.x * 0.33, -draw_size.y * 0.13),
		Vector2(draw_size.x * 0.66, draw_size.y * 0.28)
	)
	var mask_color := SUPERSPEED_MASK_COLOR if superspeed_active else MASK_COLOR
	mask_color.a *= intangible_alpha
	canvas.draw_rect(mask_rect, mask_color)
	var eye_y: float = pose_center.y - draw_size.y * 0.02
	var eye_span: float = draw_size.x * 0.20
	var eye_half_width: float = maxf(3.0, draw_size.x * 0.075)
	var pulse: float = 0.72 + 0.28 * sin(_time * 3.2)
	var eye_base := SUPERSPEED_EYE_COLOR if superspeed_active else EYE_COLOR
	var eye_color := Color(eye_base.r, eye_base.g, eye_base.b, eye_base.a * pulse * intangible_alpha)
	canvas.draw_line(Vector2(pose_center.x - eye_span - eye_half_width, eye_y), Vector2(pose_center.x - eye_span + eye_half_width, eye_y), eye_color, 2.0, true)
	canvas.draw_line(Vector2(pose_center.x + eye_span - eye_half_width, eye_y), Vector2(pose_center.x + eye_span + eye_half_width, eye_y), eye_color, 2.0, true)
	canvas.draw_line(
		body_rect.position + Vector2(draw_size.x * 0.12, draw_size.y * 0.80),
		body_rect.end - Vector2(draw_size.x * 0.12, draw_size.y * 0.20),
		(
			Color(1.0, 0.26, 0.07, 0.68 * intangible_alpha)
			if superspeed_active
			else Color(0.46, 0.40, 0.62, 0.56 * intangible_alpha)
		),
		2.0,
		true
	)
	# 무형 사각 아웃라인 제거 — 스프라이트 경로와 동일한 파리티 결정.
	if attack_active:
		_draw_attack_pose(canvas, context, pose_center, draw_size, attack_direction, intangible_alpha)


func _draw_attack_pose(
	canvas: CanvasItem,
	context: Dictionary,
	center: Vector2,
	draw_size: Vector2,
	direction: float,
	alpha_scale: float
) -> void:
	var source: String = (
		"clone"
		if bool(context.get("stage7_akamu_clone_casting", false))
		else str(context.get("stage7_akamu_boss_attack_source", "boss_paddle_hit"))
	)
	var shoulder := center + Vector2(direction * draw_size.x * 0.22, draw_size.y * 0.08)
	var hand := center + Vector2(direction * draw_size.x * 0.52, draw_size.y * 0.28)
	canvas.draw_line(shoulder, hand, Color(0.48, 0.42, 0.66, 0.92 * alpha_scale), maxf(2.0, draw_size.x * 0.045), true)
	if source == "shuriken":
		var radius: float = maxf(5.0, draw_size.x * 0.08)
		for index in range(4):
			var blade_direction := Vector2.RIGHT.rotated(_time * 10.0 + float(index) * PI * 0.5)
			var steel_color := ATTACK_STEEL_COLOR
			steel_color.a *= alpha_scale
			canvas.draw_line(hand, hand + blade_direction * radius, steel_color, 2.0, true)
	elif source == "clone":
		var cast_progress: float = clampf(float(context.get("stage7_akamu_clone_cast_progress", 0.0)), 0.0, 1.0)
		var ring_radius: float = draw_size.x * (0.24 + cast_progress * 0.24)
		var ring_color := Color(0.70, 0.52, 1.0, (0.36 + cast_progress * 0.42) * alpha_scale)
		canvas.draw_arc(center, ring_radius, 0.0, TAU, 28, ring_color, 3.0, true)
		canvas.draw_circle(center + Vector2(-ring_radius, 0.0), 4.0, ring_color)
		canvas.draw_circle(center + Vector2(ring_radius, 0.0), 4.0, ring_color)
	else:
		var slash_end := hand + Vector2(direction * draw_size.x * 0.24, -draw_size.y * 0.24)
		var steel_color := ATTACK_STEEL_COLOR
		steel_color.a *= alpha_scale
		canvas.draw_line(hand, slash_end, steel_color, 3.0, true)


func _draw_awakened_aura(canvas: CanvasItem, center: Vector2, draw_size: Vector2) -> void:
	var pulse: float = 0.5 + 0.5 * sin(_time * 4.0)
	var radius: float = maxf(draw_size.x, draw_size.y) * (0.58 + pulse * 0.05)
	var color := SUPERSPEED_AURA_COLOR if _wind_aura_superspeed else AWAKENED_COLOR
	color.a *= 0.65 + pulse * 0.35
	canvas.draw_arc(center, radius, 0.0, TAU, 36, color, 3.0, true)
	if _wind_aura_superspeed:
		canvas.draw_arc(
			center,
			radius * 0.82,
			_time * 2.0,
			_time * 2.0 + PI * 1.45,
			30,
			Color(0.12, 0.02, 0.14, 0.68 + pulse * 0.16),
			2.0,
			true
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


func _as_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
