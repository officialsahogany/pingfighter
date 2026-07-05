extends RefCounted

# Stage 6 테트리서 boss actor renderer.
#
# AutoSprite로 생성한 16-bit 픽셀아트 7종 시트
# (idle / walk / attack / dash / victory / defeat / stun)를 우선순위 상태머신으로
# 렌더한다. 각 시트는 3열 그리드 8프레임, 256px 셀 (768x768).
# 정체성: 분홍 둥근 차량형 본체 + 파란 바이저/뿔 + 파란 글로우 구체 손 +
# 파란 구체 바퀴 + 분홍 L자 테트로미노 패널. 좌우 대칭이라 facing flip 불필요.
# 우선순위(§17.6): defeat > victory > stun > dash > attack > walk > idle.
# 초인테트리서 발동 중에는 super_scale로 본체가 커진다(state 4a).

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const SHEET_DIR := "res://assets/sprites/bosses/stage6_tetriser/"
const SHEET_PATHS := {
	"idle": SHEET_DIR + "stage6_tetriser_boss_idle.png",
	"walk": SHEET_DIR + "stage6_tetriser_boss_walk.png",
	"attack": SHEET_DIR + "stage6_tetriser_boss_attack.png",
	"dash": SHEET_DIR + "stage6_tetriser_boss_dash.png",
	"victory": SHEET_DIR + "stage6_tetriser_boss_victory.png",
	"defeat": SHEET_DIR + "stage6_tetriser_boss_defeat.png",
	"stun": SHEET_DIR + "stage6_tetriser_boss_stun.png",
}
const STATE_ORDER := ["idle", "walk", "attack", "dash", "victory", "defeat", "stun"]
const SHEET_COLS := 3
const FRAME_COUNT := 8
const DRAW_SIZE := Vector2(128.0, 128.0)
const VISUAL_CENTER_Y_OFFSET := 16.0
const MOVING_THRESHOLD := 0.16
const MOVE_RELEASE_SEC := 0.12
const ATTACK_HOLD_SEC := 0.42
const FRAME_INTERVAL := {
	"idle": 0.16, "walk": 0.10, "attack": 0.05, "dash": 0.06,
	"victory": 0.10, "defeat": 0.10, "stun": 0.085,
}
const PLACEHOLDER_FILL := Color(0.47, 0.67, 1.0, 0.92)

var _textures: Dictionary = {}
var _loaded := false
var _prewarm_idx := 0
var _last_center_x := INF
var _is_moving := false
var _move_release := 0.0
var _attack_timer := 0.0
var _prev_hit_active := false
var _last_msec := 0
var _time := 0.0


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if _loaded:
		return true
	if _prewarm_idx >= STATE_ORDER.size():
		_loaded = true
		_prewarm_idx = 0
		return true
	var key: String = STATE_ORDER[_prewarm_idx]
	_textures[key] = ProjectResourceLoader.load_texture(SHEET_PATHS[key])
	_prewarm_idx += 1
	return false


func reset() -> void:
	_last_center_x = INF
	_is_moving = false
	_move_release = 0.0
	_attack_timer = 0.0
	_prev_hit_active = false
	_last_msec = 0


func draw(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	if canvas == null:
		return
	_ensure_textures()
	var dt: float = _consume_dt()
	_time += dt

	var boss_pos: Vector2 = _as_vector2(context.get("boss_pos", Vector2(330.0, 25.0)), Vector2(330.0, 25.0))
	var boss_size: Vector2 = _as_vector2(context.get("boss_paddle_size", Vector2(100.0, 40.0)), Vector2(100.0, 40.0))
	var hitbox_h: float = float(context.get("boss_hitbox_height", boss_size.y))
	var center: Vector2 = Vector2(
		boss_pos.x + boss_size.x * 0.5,
		boss_pos.y + hitbox_h * 0.5 + VISUAL_CENTER_Y_OFFSET
	) + shake_offset

	_update_motion(dt, center.x)
	_update_attack(dt, context)

	var super_scale: float = maxf(1.0, float(context.get("stage6_tetriser_super_scale", 1.0)))
	var draw_size: Vector2 = DRAW_SIZE * super_scale

	var state: String = _select_state(context)
	_draw_frame(canvas, state, _frame_for_state(state, context), center, draw_size)


func _select_state(context: Dictionary) -> String:
	if bool(context.get("boss_defeat_active", false)):
		return "defeat"
	if bool(context.get("boss_victory_active", false)):
		return "victory"
	if _is_stunned(context):
		return "stun"
	if bool(context.get("boss_dash_active", false)):
		return "dash"
	if _attack_timer > 0.0:
		return "attack"
	if _is_moving:
		return "walk"
	return "idle"


func _is_stunned(context: Dictionary) -> bool:
	return bool(context.get("active_item_boss_stun_active", false)) \
		or bool(context.get("ragnarok_hammer_boss_stun_active", false))


func _frame_for_state(state: String, context: Dictionary) -> int:
	match state:
		"attack":
			var prog: float = clampf(1.0 - _attack_timer / ATTACK_HOLD_SEC, 0.0, 1.0)
			return clampi(int(prog * float(FRAME_COUNT)), 0, FRAME_COUNT - 1)
		"dash":
			if context.has("boss_dash_frame"):
				return posmod(int(context.get("boss_dash_frame", 0)), FRAME_COUNT)
			return _loop_frame(state)
		"victory":
			return clampi(int(context.get("boss_victory_frame", _loop_frame(state))), 0, FRAME_COUNT - 1)
		"defeat":
			return clampi(int(context.get("boss_defeat_frame", _loop_frame(state))), 0, FRAME_COUNT - 1)
		_:
			return _loop_frame(state)


func _loop_frame(state: String) -> int:
	var interval: float = float(FRAME_INTERVAL.get(state, 0.12))
	return int(_time / maxf(0.001, interval)) % FRAME_COUNT


func _update_motion(dt: float, center_x: float) -> void:
	if is_inf(_last_center_x):
		_last_center_x = center_x
		return
	if absf(center_x - _last_center_x) > MOVING_THRESHOLD:
		_is_moving = true
		_move_release = MOVE_RELEASE_SEC
	else:
		_move_release = maxf(0.0, _move_release - dt)
		if _move_release <= 0.0:
			_is_moving = false
	_last_center_x = center_x


func _update_attack(dt: float, context: Dictionary) -> void:
	var hit: bool = bool(context.get("boss_hit_active", false))
	if hit and not _prev_hit_active:
		_attack_timer = ATTACK_HOLD_SEC   # boss_hit_active 상승 에지 → attack 1회 재생
	_prev_hit_active = hit
	_attack_timer = maxf(0.0, _attack_timer - dt)


func _draw_frame(canvas: CanvasItem, state: String, frame: int, center: Vector2, draw_size: Vector2) -> void:
	var texture: Texture2D = _textures.get(state, null)
	if texture == null:
		texture = _textures.get("idle", null)
	if texture == null:
		canvas.draw_rect(Rect2(center - draw_size * 0.5, draw_size), PLACEHOLDER_FILL)
		return
	var tex_size: Vector2 = texture.get_size()
	var cell_w: float = tex_size.x / float(SHEET_COLS)
	var cell_h: float = tex_size.y / float(SHEET_COLS)   # 8프레임이 3x3 그리드 → rows == cols == 3
	var col: int = frame % SHEET_COLS
	var row: int = int(floor(float(frame) / float(SHEET_COLS)))
	var src := Rect2(Vector2(float(col) * cell_w, float(row) * cell_h), Vector2(cell_w, cell_h))
	canvas.draw_texture_rect_region(texture, Rect2(center - draw_size * 0.5, draw_size), src)


func get_asset_status() -> Dictionary:
	_ensure_textures()
	var out: Dictionary = {}
	for key in STATE_ORDER:
		out["stage6_tetriser_" + key] = _textures.get(key, null) != null
	return out


func _ensure_textures() -> void:
	if _loaded:
		return
	while not prewarm_assets_step():
		pass


func _consume_dt() -> float:
	var now: int = Time.get_ticks_msec()
	if _last_msec == 0:
		_last_msec = now
		return 0.0
	var dt: float = float(now - _last_msec) / 1000.0
	_last_msec = now
	return clampf(dt, 0.0, 0.1)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
