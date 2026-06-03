extends RefCounted

# Stage 6 테트리서 boss state.
#
# 기획: docs/stage6_tetriser_port_plan.md
# 원본 참조: pingfighter.py `stage7_*` / `STAGE7_*`,
#   game_logic/stage7_tetriser.py (순수 불변식).
#
# 2단계(손맛 코어, 2a 범위):
#   - 보스 게이지 (max 500, 25/초 자동 충전, 라운드 간 persist).
#   - 낙하 테트로미노 (5~10초 간격, 게이지 30 소모, 1초 조립 → 낙하 →
#     낙하 중 드리프트/회전 → 바닥/기존 블록 위 정착).
# 아직 미구현(후속): 공 충돌/반사/파괴(2b), 가드 블록/벽(3), 초인테트리서/
#   광선/중앙 큐브(4), 보스 카드 HUD(5), 사운드.
#
# 단일 cleanup 경로 규율 (홍련 패턴 / CLAUDE.md 보스 이벤트 누수 규칙):
# round / result / stage-leave 모두 `_clear_combat_state()`를 통과한다.
# 게이지는 라운드 간 보존(원본 stage7_persistent_boss_gauge)이므로 reset_round()
# 에서는 비우지 않고 reset()/reset_for_result()에서만 0으로 되돌린다.

const STAGE_ID := 6
const BOSS_NAME := "테트리서"

# === 보스 게이지 (원본 update_stage7_gauge_charge: elapsed_ms * 0.025, cap 500) ===
const GAUGE_MAX := 500.0
const GAUGE_CHARGE_PER_SEC := 25.0

# === 낙하 테트로미노 (원본 STAGE7_TETRO_*) ===
const TETRO_MIN_INTERVAL_SEC := 5.0
const TETRO_MAX_INTERVAL_SEC := 10.0
const TETRO_GAUGE_COST := 30.0
const TETRO_CELL_SIZE := 20.0
const TETRO_ASSEMBLY_TOTAL_SEC := 1.0    # 원본 1000ms
const TETRO_ASSEMBLY_STEP_SEC := 0.25    # 4셀, 250ms 간격 등장
const TETRO_FALL_SPEED := 82.0           # ≈ 9px / 0.110s (원본 110ms 스텝). 인게임 튜닝 대상.
const TETRO_DRIFT_CHANCE := 0.40         # 낙하 중 수평 드리프트 확률
const TETRO_ROTATE_CHANCE := 0.35        # 낙하 중 회전 확률
const TETRO_EVENT_CHECK_INTERVAL_SEC := 0.45
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const SPAWN_TOP_Y := 92.0                # 보스 hitbox(~65) 아래에서 조립 시작
const SPAWN_MARGIN_X := 40.0
# 안전 캡: 공 충돌(2b)/중앙 큐브(step4) 파괴가 들어오기 전까지 정착 블록 누적 방지.
# 실제 게임에선 공/대시/연막/큐브가 정리하므로 이 캡에 거의 닿지 않는다.
const MAX_ACTIVE_TETROMINOS := 14

# === 공 충돌/반사 (원본 ball update loop + game_logic/choose_reflection_axis) ===
const BALL_MIN_V_SPEED := 6.0            # 원본 min_v_speed
const BALL_MIN_H_SPEED := 3.0            # 원본 min_h_speed
const BALL_REFLECT_X_JITTER := 0.35      # 원본 random.uniform(-0.35, 0.35)
const DEBRIS_LIFE_SEC := 0.35            # 파괴 파편 플래시 수명

# 표준 7종 테트로미노 셀 오프셋 (원본 game_logic/_tetro_wall_shapes 동일).
const TETRO_SHAPES := {
	"I": [Vector2(0, 0), Vector2(1, 0), Vector2(2, 0), Vector2(3, 0)],
	"O": [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)],
	"T": [Vector2(0, 0), Vector2(1, 0), Vector2(2, 0), Vector2(1, 1)],
	"S": [Vector2(1, 0), Vector2(2, 0), Vector2(0, 1), Vector2(1, 1)],
	"Z": [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(2, 1)],
	"J": [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(2, 1)],
	"L": [Vector2(2, 0), Vector2(0, 1), Vector2(1, 1), Vector2(2, 1)],
}
const TETRO_COLORS := {
	"I": Color(0.30, 0.80, 0.95),
	"O": Color(0.95, 0.83, 0.30),
	"T": Color(0.72, 0.40, 0.92),
	"S": Color(0.40, 0.86, 0.45),
	"Z": Color(0.93, 0.36, 0.38),
	"J": Color(0.36, 0.50, 0.93),
	"L": Color(0.95, 0.58, 0.27),
}

var boss_gauge: float = 0.0
var status: String = "charging"

var _tetrominoes: Array[Dictionary] = []
var _debris: Array[Dictionary] = []
var _spawn_timer_sec: float = 0.0
var _shape_keys: Array = TETRO_SHAPES.keys()
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()
	_arm_spawn_timer()


# ============================================================================
# Reset 경로 (단일 _clear_combat_state 코어)
# ============================================================================

func reset() -> void:
	# 전체 초기화(스테이지 이탈 / 디버그 피커 진입). 게이지도 0.
	_clear_combat_state()
	boss_gauge = 0.0
	status = "charging"


func reset_round() -> void:
	# 라운드 경계. 전투 구조물만 정리하고 게이지는 보존(원본 persistent).
	_clear_combat_state()
	status = "charging"


func reset_for_result() -> void:
	# 결과/게임 종료 — 다음 게임으로 게이지/블록 누수 방지(전체 초기화).
	reset()


func _clear_combat_state() -> void:
	_tetrominoes.clear()
	_debris.clear()
	_arm_spawn_timer()


# ============================================================================
# Per-frame tick
# ============================================================================

func update(delta: float, context: Dictionary, _deps: Dictionary = {}) -> Dictionary:
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID:
		if not _tetrominoes.is_empty() or boss_gauge > 0.0:
			reset()
		return _build_result()

	var clamped_delta: float = clampf(delta, 0.0, 0.1)

	# 비활성 / 서브 대기 / 시간 정지 중에는 게이지·스폰·낙하 모두 정지(블록 동결, 게이지 유지).
	if not bool(context.get("ball_active", false)) \
			or bool(context.get("waiting_for_serve", false)) \
			or _is_timing_frozen(context):
		status = "paused"
		return _build_result()

	status = "charging"
	_charge_gauge(clamped_delta)
	_update_spawn_scheduler(clamped_delta)
	_update_tetrominoes(clamped_delta)
	_update_debris(clamped_delta)
	return _build_result()


func _charge_gauge(delta: float) -> void:
	if boss_gauge >= GAUGE_MAX:
		boss_gauge = GAUGE_MAX
		return
	boss_gauge = minf(GAUGE_MAX, boss_gauge + GAUGE_CHARGE_PER_SEC * delta)


func _update_spawn_scheduler(delta: float) -> void:
	_spawn_timer_sec -= delta
	if _spawn_timer_sec > 0.0:
		return
	if boss_gauge < TETRO_GAUGE_COST or _tetrominoes.size() >= MAX_ACTIVE_TETROMINOS:
		_spawn_timer_sec = 1.0   # 게이지 부족 / 캡 도달 → 짧게 재시도
		return
	_spawn_tetromino()
	boss_gauge -= TETRO_GAUGE_COST
	_arm_spawn_timer()


func _arm_spawn_timer() -> void:
	_spawn_timer_sec = _rng.randf_range(TETRO_MIN_INTERVAL_SEC, TETRO_MAX_INTERVAL_SEC)


func _spawn_tetromino() -> void:
	var shape_name: String = String(_shape_keys[_rng.randi_range(0, _shape_keys.size() - 1)])
	var cells: Array = _rotate_cells(TETRO_SHAPES[shape_name], _rng.randi_range(0, 3))
	var width_px: float = _cells_dims(cells).x * TETRO_CELL_SIZE
	var min_x: float = SPAWN_MARGIN_X
	var max_x: float = maxf(min_x, FIELD_WIDTH - width_px - SPAWN_MARGIN_X)
	_tetrominoes.append({
		"shape": shape_name,
		"state": "assembling",
		"cells": cells,
		"origin": Vector2(_rng.randf_range(min_x, max_x), SPAWN_TOP_Y),
		"assembly_elapsed": 0.0,
		"visible_cells": 1,
		"event_timer": TETRO_EVENT_CHECK_INTERVAL_SEC,
	})


func _update_tetrominoes(delta: float) -> void:
	var settled_rects: Array = _collect_settled_cell_rects()
	for tetro in _tetrominoes:
		match String(tetro.get("state", "")):
			"assembling":
				_update_assembling(tetro, delta)
			"falling":
				_update_falling(tetro, delta, settled_rects)
			# "settled": 정착 후 정지(파괴는 2b 공 충돌 / step4 큐브에서).


func _update_assembling(tetro: Dictionary, delta: float) -> void:
	var elapsed: float = float(tetro["assembly_elapsed"]) + delta
	tetro["assembly_elapsed"] = elapsed
	var cell_count: int = (tetro["cells"] as Array).size()
	tetro["visible_cells"] = clampi(int(elapsed / TETRO_ASSEMBLY_STEP_SEC) + 1, 1, cell_count)
	if elapsed >= TETRO_ASSEMBLY_TOTAL_SEC:
		tetro["state"] = "falling"
		tetro["visible_cells"] = cell_count


func _update_falling(tetro: Dictionary, delta: float, settled_rects: Array) -> void:
	var event_timer: float = float(tetro["event_timer"]) - delta
	if event_timer <= 0.0:
		event_timer = TETRO_EVENT_CHECK_INTERVAL_SEC
		_maybe_drift(tetro)
		_maybe_rotate(tetro)
	tetro["event_timer"] = event_timer

	var origin: Vector2 = tetro["origin"]
	var next_origin: Vector2 = origin + Vector2(0.0, TETRO_FALL_SPEED * delta)
	if _would_settle(tetro, next_origin, settled_rects):
		tetro["state"] = "settled"   # 마지막 유효 위치(current origin)에서 정착
	else:
		tetro["origin"] = next_origin


func _would_settle(tetro: Dictionary, next_origin: Vector2, settled_rects: Array) -> bool:
	for cell in tetro["cells"]:
		var rect: Rect2 = Rect2(next_origin + cell * TETRO_CELL_SIZE, Vector2(TETRO_CELL_SIZE, TETRO_CELL_SIZE))
		if rect.position.y + rect.size.y >= FIELD_HEIGHT:
			return true
		for settled in settled_rects:
			if rect.intersects(settled):
				return true
	return false


func _maybe_drift(tetro: Dictionary) -> void:
	if _rng.randf() >= TETRO_DRIFT_CHANCE:
		return
	var dir: float = -1.0 if _rng.randf() < 0.5 else 1.0
	var dx: float = dir * float(_rng.randi_range(1, 2)) * TETRO_CELL_SIZE
	tetro["origin"] = _clamp_origin_x(tetro["origin"] + Vector2(dx, 0.0), tetro["cells"])


func _maybe_rotate(tetro: Dictionary) -> void:
	if _rng.randf() >= TETRO_ROTATE_CHANCE:
		return
	var rotated: Array = _rotate_cells(tetro["cells"], _rng.randi_range(1, 2))
	tetro["cells"] = rotated
	tetro["origin"] = _clamp_origin_x(tetro["origin"], rotated)


func _clamp_origin_x(origin: Vector2, cells: Array) -> Vector2:
	var width_px: float = _cells_dims(cells).x * TETRO_CELL_SIZE
	var max_x: float = maxf(SPAWN_MARGIN_X, FIELD_WIDTH - width_px - SPAWN_MARGIN_X)
	return Vector2(clampf(origin.x, SPAWN_MARGIN_X, max_x), origin.y)


func _collect_settled_cell_rects() -> Array:
	var rects: Array = []
	for tetro in _tetrominoes:
		if String(tetro.get("state", "")) != "settled":
			continue
		var origin: Vector2 = tetro["origin"]
		for cell in tetro["cells"]:
			rects.append(Rect2(origin + cell * TETRO_CELL_SIZE, Vector2(TETRO_CELL_SIZE, TETRO_CELL_SIZE)))
	return rects


# ============================================================================
# 공 충돌 / 반사 / 파괴 (ball_update_controller가 motion step 직후 호출)
# ============================================================================

# scene["ball_pos"]는 공의 '중심'(commando_supply_drop 선례와 동일 규약).
func resolve_ball_collision(scene: Dictionary, context: Dictionary, _deps: Dictionary = {}) -> bool:
	if _tetrominoes.is_empty():
		return false
	var ball_pos: Vector2 = scene.get("ball_pos", Vector2.ZERO)
	var prev_pos: Vector2 = scene.get("previous_ball_pos", context.get("ball_pos", ball_pos))
	var radius: float = maxf(1.0, float(context.get("ball_size", 28.6)) * 0.5)
	var diameter: Vector2 = Vector2(radius * 2.0, radius * 2.0)
	var ball_rect: Rect2 = Rect2(ball_pos - Vector2(radius, radius), diameter)
	var prev_rect: Rect2 = Rect2(prev_pos - Vector2(radius, radius), diameter)

	var hit_tetro: Dictionary = {}
	var hit_cell_rect: Rect2 = Rect2()
	for tetro in _tetrominoes:
		var tetro_state: String = String(tetro.get("state", ""))
		# 조립 중 셀은 아직 solid 아님. 낙하/정착만 충돌.
		if tetro_state != "falling" and tetro_state != "settled":
			continue
		var origin: Vector2 = tetro["origin"]
		for cell in tetro["cells"]:
			var cell_rect: Rect2 = Rect2(origin + cell * TETRO_CELL_SIZE, Vector2(TETRO_CELL_SIZE, TETRO_CELL_SIZE))
			if ball_rect.intersects(cell_rect):
				hit_tetro = tetro
				hit_cell_rect = cell_rect
				break
		if not hit_tetro.is_empty():
			break
	if hit_tetro.is_empty():
		return false

	var ball_vel: Vector2 = scene.get("ball_vel", Vector2.ZERO)
	var axis: String = _choose_reflection_axis(prev_rect, ball_rect, hit_cell_rect)
	var block_center: Vector2 = hit_cell_rect.get_center()
	if axis == "v":
		if prev_pos.y < block_center.y:
			ball_pos.y = hit_cell_rect.position.y - radius - 1.0
			ball_vel.y = -maxf(BALL_MIN_V_SPEED, absf(ball_vel.y))
		else:
			ball_pos.y = hit_cell_rect.position.y + hit_cell_rect.size.y + radius + 1.0
			ball_vel.y = maxf(BALL_MIN_V_SPEED, absf(ball_vel.y))
	else:
		if prev_pos.x < block_center.x:
			ball_pos.x = hit_cell_rect.position.x - radius - 1.0
			ball_vel.x = -maxf(BALL_MIN_H_SPEED, absf(ball_vel.x))
		else:
			ball_pos.x = hit_cell_rect.position.x + hit_cell_rect.size.x + radius + 1.0
			ball_vel.x = maxf(BALL_MIN_H_SPEED, absf(ball_vel.x))
	ball_vel.x += _rng.randf_range(-BALL_REFLECT_X_JITTER, BALL_REFLECT_X_JITTER)

	scene["ball_pos"] = ball_pos
	scene["ball_vel"] = ball_vel

	# 파괴 매트릭스(코덱스 리뷰 §2.5): 일반 공 반사는 일반 테트로만 파괴한다.
	# super 테트로(초인테트리서, step 4)는 공에 맞아도 파괴되지 않고 튕기기만 한다.
	# super 셰이프는 아직 스폰되지 않으므로 현재는 항상 일반 분기.
	if not bool(hit_tetro.get("super", false)):
		_destroy_tetromino_by_ball(hit_tetro)
	return true


# 원본 game_logic/stage7_tetriser.choose_reflection_axis 포트.
func _choose_reflection_axis(prev_rect: Rect2, cur_rect: Rect2, block: Rect2) -> String:
	var b_left: float = block.position.x
	var b_right: float = block.position.x + block.size.x
	var b_top: float = block.position.y
	var b_bottom: float = block.position.y + block.size.y
	var collided_horiz: bool = (prev_rect.position.x + prev_rect.size.x <= b_left) or (prev_rect.position.x >= b_right)
	var collided_vert: bool = (prev_rect.position.y + prev_rect.size.y <= b_top) or (prev_rect.position.y >= b_bottom)
	if collided_horiz and not collided_vert:
		return "h"
	if collided_vert and not collided_horiz:
		return "v"
	var overlap_x: float = minf(cur_rect.position.x + cur_rect.size.x - b_left, b_right - cur_rect.position.x)
	var overlap_y: float = minf(cur_rect.position.y + cur_rect.size.y - b_top, b_bottom - cur_rect.position.y)
	return "h" if overlap_x < overlap_y else "v"


func _destroy_tetromino_by_ball(tetro: Dictionary) -> void:
	var origin: Vector2 = tetro.get("origin", Vector2.ZERO)
	var color: Color = TETRO_COLORS.get(String(tetro.get("shape", "T")), Color(0.6, 0.7, 1.0))
	var rects: Array = []
	for cell in tetro.get("cells", []):
		rects.append(Rect2(origin + cell * TETRO_CELL_SIZE, Vector2(TETRO_CELL_SIZE, TETRO_CELL_SIZE)))
	_debris.append({"rects": rects, "color": color, "life": DEBRIS_LIFE_SEC, "max_life": DEBRIS_LIFE_SEC})
	_tetrominoes.erase(tetro)
	# TODO(step 2b polish): tetrisbreak.wav 사운드 + 큐브 재조립 notify(step 4).


func _update_debris(delta: float) -> void:
	if _debris.is_empty():
		return
	var alive: Array[Dictionary] = []
	for d in _debris:
		var life: float = float(d["life"]) - delta
		if life > 0.0:
			d["life"] = life
			alive.append(d)
	_debris = alive


# 원본 game_logic/stage7_tetriser._rotate_cells 포트: (x,y) -> (-y,x) 후 비음수 정규화.
func _rotate_cells(cells: Array, times: int) -> Array:
	var pts: Array = cells.duplicate()
	for _i in range(posmod(times, 4)):
		var rotated: Array = []
		var min_x: float = INF
		var min_y: float = INF
		for p in pts:
			var rp: Vector2 = Vector2(-p.y, p.x)
			rotated.append(rp)
			min_x = minf(min_x, rp.x)
			min_y = minf(min_y, rp.y)
		var shifted: Array = []
		for p in rotated:
			shifted.append(Vector2(p.x - min_x, p.y - min_y))
		pts = shifted
	return pts


func _cells_dims(cells: Array) -> Vector2:
	var max_x: float = 0.0
	var max_y: float = 0.0
	for p in cells:
		max_x = maxf(max_x, p.x)
		max_y = maxf(max_y, p.y)
	return Vector2(max_x + 1.0, max_y + 1.0)


func _is_timing_frozen(context: Dictionary) -> bool:
	return bool(context.get("stopwatch_freeze_active", false)) \
		or bool(context.get("perk_resume_freeze_active", false)) \
		or bool(context.get("power_smashing_freeze_active", false)) \
		or bool(context.get("viper_dmk_freeze_active", false)) \
		or bool(context.get("viper_nerve_strike_freeze_active", false))


func _build_result() -> Dictionary:
	# 2a에서는 공 모션을 가로채지 않는다(공 충돌은 2b).
	return {"skip_ball_motion_step": false}


# ============================================================================
# State queries (HUD / boss AI / renderer 소비)
# ============================================================================

func get_actor_draw_context() -> Dictionary:
	return {
		"stage6_tetriser_tetrominoes": _build_tetromino_draw_list(),
		"stage6_tetriser_debris": _build_debris_draw_list(),
		"stage6_tetriser_cell_size": TETRO_CELL_SIZE,
	}


func _build_debris_draw_list() -> Array:
	var out: Array = []
	for d in _debris:
		var max_life: float = maxf(0.001, float(d.get("max_life", DEBRIS_LIFE_SEC)))
		out.append({
			"rects": (d.get("rects", []) as Array).duplicate(),
			"color": d.get("color", Color(1.0, 1.0, 1.0)),
			"progress": clampf(1.0 - float(d.get("life", 0.0)) / max_life, 0.0, 1.0),
		})
	return out


func _build_tetromino_draw_list() -> Array:
	var out: Array = []
	for tetro in _tetrominoes:
		var shape_name: String = String(tetro.get("shape", "T"))
		out.append({
			"shape": shape_name,
			"state": tetro.get("state", "falling"),
			"origin": tetro.get("origin", Vector2.ZERO),
			"cells": (tetro.get("cells", []) as Array).duplicate(),
			"visible_cells": int(tetro.get("visible_cells", 4)),
			"color": TETRO_COLORS.get(shape_name, Color(0.6, 0.7, 1.0)),
		})
	return out


func get_boss_ai_context() -> Dictionary:
	return {
		"stage6_tetriser_boss_gauge": boss_gauge,
		"stage6_tetriser_tetromino_count": _tetrominoes.size(),
	}


func get_hud_context(_stage_background: Object = null, _context: Dictionary = {}) -> Dictionary:
	# 보스 카드 HUD(step 5)에서 소비 예정. 현재는 게이지 상태만 노출.
	return {
		"stage6_boss_skill_hud_active": true,
		"stage6_boss_skill_hud_boss_name": BOSS_NAME,
		"stage6_boss_skill_hud_status": status,
		"stage6_boss_skill_hud_gauge": boss_gauge,
		"stage6_boss_skill_hud_gauge_max": GAUGE_MAX,
	}


func should_skip_ball_motion_step() -> bool:
	return false


func get_status() -> String:
	return status


# ============================================================================
# Debug / test hooks
# ============================================================================

func debug_force_spawn_tetromino() -> void:
	_spawn_tetromino()


# 결정론적 충돌 테스트용: 지정 위치에 즉시 'falling' 테트로미노 배치.
func debug_spawn_tetromino_at(origin: Vector2, shape: String = "O", super_flag: bool = false) -> void:
	var cells: Array = (TETRO_SHAPES.get(shape, TETRO_SHAPES["O"]) as Array).duplicate()
	_tetrominoes.append({
		"shape": shape,
		"state": "falling",
		"cells": cells,
		"origin": origin,
		"assembly_elapsed": TETRO_ASSEMBLY_TOTAL_SEC,
		"visible_cells": cells.size(),
		"event_timer": TETRO_EVENT_CHECK_INTERVAL_SEC,
		"super": super_flag,
	})


func debug_get_debris_count() -> int:
	return _debris.size()


func debug_get_gauge() -> float:
	return boss_gauge


func debug_get_tetromino_count() -> int:
	return _tetrominoes.size()


func debug_get_tetromino_states() -> Array:
	var out: Array = []
	for tetro in _tetrominoes:
		out.append(String(tetro.get("state", "")))
	return out
