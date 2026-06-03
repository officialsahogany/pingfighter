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

# === 가드 블록 (원본 STAGE7_GUARD_*: 보스 좌우 4셀 가로 바) ===
const GUARD_MIN_INTERVAL_SEC := 7.0      # STAGE7_GUARD_MIN_INTERVAL_MS
const GUARD_MAX_INTERVAL_SEC := 15.0     # STAGE7_GUARD_MAX_INTERVAL_MS
const GUARD_COST_SINGLE := 50.0          # 1개 50
const GUARD_COST_PAIR := 100.0           # 2개 100
const GUARD_MAX_ACTIVE := 4
const GUARD_SLIDE_SEC := 0.32            # STAGE7_GUARD_MOVEMENT_DURATION_MS=320
const GUARD_GAP_Y := 40.0                # STAGE7_GUARD_GAP_Y (층 쌓기 간격)
const GUARD_SPAWN_OFFSET_Y := 8.0
const GUARD_CELLS := [Vector2(0, 0), Vector2(1, 0), Vector2(2, 0), Vector2(3, 0)]  # 4x1 가로 바
const GUARD_COLOR := Color(0.58, 0.66, 0.78)  # 금속 가드

# === 테트로 벽 (원본 get_tetro_wall_spawn_spec_legacy: 30초, 코스트 50, 측면당 10개) ===
const WALL_INTERVAL_SEC := 30.0
const WALL_COST := 50.0
const WALL_COLS := 4                     # grid_w = 4*20 = 80px (좌 x=0 / 우 x=WIDTH-80)
const WALL_PIECES_PER_SIDE := 10         # 측면당 10조각 = 40셀 = 10행
const WALL_ROWS_PER_SIDE := 10           # 40셀 / 4열
const WALL_LIFETIME_SEC := 6.0           # 원본 installed_duration_ms=6000

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
var _guard_blocks: Array[Dictionary] = []
var _wall_blocks: Array[Dictionary] = []
var _debris: Array[Dictionary] = []
var _spawn_timer_sec: float = 0.0
var _guard_timer_sec: float = 0.0
var _wall_timer_sec: float = 0.0
var _wall_life_sec: float = 0.0
var _shape_keys: Array = TETRO_SHAPES.keys()
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()
	_arm_spawn_timer()
	_arm_guard_timer()
	_arm_wall_timer()


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
	_guard_blocks.clear()
	_wall_blocks.clear()
	_debris.clear()
	_wall_life_sec = 0.0
	_arm_spawn_timer()
	_arm_guard_timer()
	_arm_wall_timer()


# ============================================================================
# Per-frame tick
# ============================================================================

func update(delta: float, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
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
	_update_guard_scheduler(clamped_delta, context)
	_update_wall_scheduler(clamped_delta)
	_update_tetrominoes(clamped_delta)
	_update_guard_blocks(clamped_delta)
	_update_wall_lifetime(clamped_delta)
	_apply_player_attack_destruction(context, deps)
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


func _arm_guard_timer() -> void:
	_guard_timer_sec = _rng.randf_range(GUARD_MIN_INTERVAL_SEC, GUARD_MAX_INTERVAL_SEC)


# 가드 블록 스케줄러: 게이지 보유 시 보스 좌우로 4셀 바를 1~2개 전개(최대 4).
func _update_guard_scheduler(delta: float, context: Dictionary) -> void:
	_guard_timer_sec -= delta
	if _guard_timer_sec > 0.0:
		return
	var active: int = _guard_blocks.size()
	if active >= GUARD_MAX_ACTIVE:
		_guard_timer_sec = 1.0
		return
	var room: int = GUARD_MAX_ACTIVE - active
	if room >= 2 and boss_gauge >= GUARD_COST_PAIR:
		_spawn_guard_block("left", context)
		_spawn_guard_block("right", context)
		boss_gauge -= GUARD_COST_PAIR
		_arm_guard_timer()
	elif boss_gauge >= GUARD_COST_SINGLE:
		_spawn_guard_block(_fewer_guard_side(), context)
		boss_gauge -= GUARD_COST_SINGLE
		_arm_guard_timer()
	else:
		_guard_timer_sec = 1.0   # 게이지 부족 → 짧게 재시도


func _fewer_guard_side() -> String:
	var left_count: int = 0
	var right_count: int = 0
	for block in _guard_blocks:
		if String(block.get("side", "left")) == "left":
			left_count += 1
		else:
			right_count += 1
	return "left" if left_count <= right_count else "right"


func _spawn_guard_block(side: String, context: Dictionary) -> void:
	var boss_pos: Vector2 = context.get("boss_pos", Vector2(330.0, 25.0))
	var boss_size: Vector2 = context.get("boss_paddle_size", Vector2(100.0, 40.0))
	var cell: float = TETRO_CELL_SIZE
	var center_x: float = boss_pos.x + boss_size.x * 0.5
	var level: int = _count_guard_side(side)
	var base_top: float = maxf(12.0, boss_pos.y - cell - GUARD_SPAWN_OFFSET_Y)
	var top: float = maxf(12.0, base_top - float(level) * GUARD_GAP_Y)
	var start_origin: Vector2
	var final_origin: Vector2
	if side == "left":
		start_origin = Vector2(center_x - cell * 4.0, top)
		final_origin = Vector2(maxf(12.0, boss_pos.x - cell * 4.0 - 6.0), top)
	else:
		start_origin = Vector2(center_x, top)
		final_origin = Vector2(minf(FIELD_WIDTH - cell * 4.0 - 12.0, boss_pos.x + boss_size.x + 6.0), top)
	_guard_blocks.append({
		"kind": "guard",
		"state": "sliding",
		"side": side,
		"cells": GUARD_CELLS.duplicate(),
		"origin": start_origin,
		"start_origin": start_origin,
		"final_origin": final_origin,
		"slide_elapsed": 0.0,
	})


func _count_guard_side(side: String) -> int:
	var count: int = 0
	for block in _guard_blocks:
		if String(block.get("side", "left")) == side:
			count += 1
	return count


func _update_guard_blocks(delta: float) -> void:
	for block in _guard_blocks:
		if String(block.get("state", "")) != "sliding":
			continue
		var elapsed: float = float(block["slide_elapsed"]) + delta
		block["slide_elapsed"] = elapsed
		var t: float = clampf(elapsed / GUARD_SLIDE_SEC, 0.0, 1.0)
		var ease_t: float = 1.0 - (1.0 - t) * (1.0 - t)   # ease-out quad
		var start_origin: Vector2 = block["start_origin"]
		var final_origin: Vector2 = block["final_origin"]
		block["origin"] = start_origin.lerp(final_origin, ease_t)
		if t >= 1.0:
			block["state"] = "active"
			block["origin"] = final_origin


func _arm_wall_timer() -> void:
	_wall_timer_sec = WALL_INTERVAL_SEC


# 테트로 벽 스케줄러: 30초마다 게이지 50으로 좌우 벽을 재생성(수명 6초).
func _update_wall_scheduler(delta: float) -> void:
	_wall_timer_sec -= delta
	if _wall_timer_sec > 0.0:
		return
	if boss_gauge < WALL_COST:
		_wall_timer_sec = 1.0   # 게이지 부족 → 짧게 재시도
		return
	_spawn_tetro_wall()
	boss_gauge -= WALL_COST
	_arm_wall_timer()


func _update_wall_lifetime(delta: float) -> void:
	if _wall_blocks.is_empty():
		return
	_wall_life_sec -= delta
	if _wall_life_sec <= 0.0:
		_wall_blocks.clear()


# 좌(x=0) / 우(x=WIDTH-grid_w) 벽을 각 10행(=10조각) 쌓는다. 벽 셀은 단일-셀
# 블록이라 공/대시가 셀 단위로 파괴(원본 _mark_wall_cell_evaporated 동등).
# 단순화: 원본의 테트로 조각 중력 적층 대신 cols*rows 직사각형 채움(셀 수 동일).
func _spawn_tetro_wall() -> void:
	_wall_blocks.clear()
	var grid_w: float = float(WALL_COLS) * TETRO_CELL_SIZE
	_spawn_wall_side(0.0)
	_spawn_wall_side(FIELD_WIDTH - grid_w)
	_wall_life_sec = WALL_LIFETIME_SEC


func _spawn_wall_side(origin_x: float) -> void:
	for r in range(WALL_ROWS_PER_SIDE):
		var shape_name: String = String(_shape_keys[_rng.randi_range(0, _shape_keys.size() - 1)])
		var color: Color = TETRO_COLORS.get(shape_name, Color(0.6, 0.7, 1.0))
		var cell_top: float = FIELD_HEIGHT - float(r + 1) * TETRO_CELL_SIZE
		for col in range(WALL_COLS):
			_wall_blocks.append({
				"kind": "wall",
				"state": "active",
				"cells": [Vector2(0, 0)],
				"origin": Vector2(origin_x + float(col) * TETRO_CELL_SIZE, cell_top),
				"color": color,
			})


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
# 테트로미노 → 가드 블록 순으로 첫 충돌 셀을 찾아 반사 + 파괴한다.
func resolve_ball_collision(scene: Dictionary, context: Dictionary, _deps: Dictionary = {}) -> bool:
	if _tetrominoes.is_empty() and _guard_blocks.is_empty() and _wall_blocks.is_empty():
		return false
	var ball_pos: Vector2 = scene.get("ball_pos", Vector2.ZERO)
	var radius: float = maxf(1.0, float(context.get("ball_size", 28.6)) * 0.5)
	var ball_rect: Rect2 = Rect2(ball_pos - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0))

	# 1) 낙하/정착 테트로미노 (조립 중 셀은 아직 solid 아님).
	var tetro_hit: Dictionary = _find_block_cell_hit(_tetrominoes, ball_rect, ["falling", "settled"])
	if not tetro_hit.is_empty():
		_apply_cell_reflection(scene, context, radius, tetro_hit["cell_rect"])
		# 파괴 매트릭스(코덱스 §2.5): 일반 공은 super 테트로를 파괴하지 않고 튕기기만.
		var tetro: Dictionary = tetro_hit["item"]
		if not bool(tetro.get("super", false)):
			_destroy_block_group(_tetrominoes, tetro, TETRO_COLORS.get(String(tetro.get("shape", "T")), Color(0.6, 0.7, 1.0)))
		return true

	# 2) 가드 블록 (보스 좌우 4셀 바, 슬라이드 완료 후 collidable).
	var guard_hit: Dictionary = _find_block_cell_hit(_guard_blocks, ball_rect, ["active"])
	if not guard_hit.is_empty():
		_apply_cell_reflection(scene, context, radius, guard_hit["cell_rect"])
		_destroy_block_group(_guard_blocks, guard_hit["item"], GUARD_COLOR)
		return true

	# 3) 테트로 벽 (좌우 가장자리). 셀 단위 파괴(단일-셀 블록).
	var wall_hit: Dictionary = _find_block_cell_hit(_wall_blocks, ball_rect, ["active"])
	if not wall_hit.is_empty():
		_apply_cell_reflection(scene, context, radius, wall_hit["cell_rect"])
		var wall_cell: Dictionary = wall_hit["item"]
		_destroy_block_group(_wall_blocks, wall_cell, wall_cell.get("color", Color(0.6, 0.7, 1.0)))
		return true

	return false


# 셀 묶음(블록) 목록에서 공이 처음 겹치는 셀을 찾는다.
func _find_block_cell_hit(blocks: Array, ball_rect: Rect2, collidable_states: Array) -> Dictionary:
	for block in blocks:
		if not collidable_states.has(String(block.get("state", ""))):
			continue
		var origin: Vector2 = block["origin"]
		for cell in block["cells"]:
			var cell_rect: Rect2 = Rect2(origin + cell * TETRO_CELL_SIZE, Vector2(TETRO_CELL_SIZE, TETRO_CELL_SIZE))
			if ball_rect.intersects(cell_rect):
				return {"item": block, "cell_rect": cell_rect}
	return {}


# 원본 ball update loop 반사: 직전 프레임 위치 기준 축 선택 + 최소속도 + x 지터.
func _apply_cell_reflection(scene: Dictionary, context: Dictionary, radius: float, cell_rect: Rect2) -> void:
	var ball_pos: Vector2 = scene.get("ball_pos", Vector2.ZERO)
	var prev_pos: Vector2 = scene.get("previous_ball_pos", context.get("ball_pos", ball_pos))
	var ball_vel: Vector2 = scene.get("ball_vel", Vector2.ZERO)
	var diameter: Vector2 = Vector2(radius * 2.0, radius * 2.0)
	var ball_rect: Rect2 = Rect2(ball_pos - Vector2(radius, radius), diameter)
	var prev_rect: Rect2 = Rect2(prev_pos - Vector2(radius, radius), diameter)
	var axis: String = _choose_reflection_axis(prev_rect, ball_rect, cell_rect)
	var block_center: Vector2 = cell_rect.get_center()
	if axis == "v":
		if prev_pos.y < block_center.y:
			ball_pos.y = cell_rect.position.y - radius - 1.0
			ball_vel.y = -maxf(BALL_MIN_V_SPEED, absf(ball_vel.y))
		else:
			ball_pos.y = cell_rect.position.y + cell_rect.size.y + radius + 1.0
			ball_vel.y = maxf(BALL_MIN_V_SPEED, absf(ball_vel.y))
	else:
		if prev_pos.x < block_center.x:
			ball_pos.x = cell_rect.position.x - radius - 1.0
			ball_vel.x = -maxf(BALL_MIN_H_SPEED, absf(ball_vel.x))
		else:
			ball_pos.x = cell_rect.position.x + cell_rect.size.x + radius + 1.0
			ball_vel.x = maxf(BALL_MIN_H_SPEED, absf(ball_vel.x))
	ball_vel.x += _rng.randf_range(-BALL_REFLECT_X_JITTER, BALL_REFLECT_X_JITTER)
	scene["ball_pos"] = ball_pos
	scene["ball_vel"] = ball_vel


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


# 블록 그룹 전체 파괴(테트로/가드) + 파편 플래시.
func _destroy_block_group(blocks: Array, block: Dictionary, color: Color) -> void:
	_emit_debris(block.get("origin", Vector2.ZERO), block.get("cells", []), color)
	blocks.erase(block)
	# TODO(폴리시): tetrisbreak.wav 사운드 + 중앙 큐브 재조립 notify(step 4).


func _emit_debris(origin: Vector2, cells: Array, color: Color) -> void:
	var rects: Array = []
	for cell in cells:
		rects.append(Rect2(origin + cell * TETRO_CELL_SIZE, Vector2(TETRO_CELL_SIZE, TETRO_CELL_SIZE)))
	_debris.append({"rects": rects, "color": color, "life": DEBRIS_LIFE_SEC, "max_life": DEBRIS_LIFE_SEC})


# ============================================================================
# 플레이어 공격 파괴 (대시 / 연막 / 폭발) — 원본 by_dash / by_smoke.
# 공과 달리 super 면역 없음(공 반사 경로만 super 보존). 셀이 영역과 겹치면
# 테트로/가드는 그룹 통째, 벽은 단일-셀 블록이라 셀 단위로 파괴된다.
# ============================================================================

func _apply_player_attack_destruction(context: Dictionary, deps: Dictionary) -> void:
	if _tetrominoes.is_empty() and _guard_blocks.is_empty() and _wall_blocks.is_empty():
		return

	# 대시: 플레이어 패들이 휩쓰는 동안 겹치는 셀 파괴.
	var dash_snapshot: Dictionary = context.get("dash_snapshot", {})
	if bool(dash_snapshot.get("active", false)):
		var player_pos: Vector2 = context.get("player_pos", Vector2.ZERO)
		var paddle_size: Vector2 = context.get("player_paddle_size", Vector2(155.0, 50.0))
		var paddle_rect: Rect2 = Rect2(player_pos, paddle_size)
		_destroy_solid_obstacles(func(cell_rect: Rect2) -> bool: return paddle_rect.intersects(cell_rect))

	# 연막 / 폭발: active_item_runtime의 throw_controller zone 소비(item 코드 비침투).
	var active_item_runtime = deps.get("active_item_runtime", null)
	if active_item_runtime == null or not ("throw_controller" in active_item_runtime):
		return
	var throw_controller = active_item_runtime.throw_controller
	if throw_controller == null:
		return

	if throw_controller.has_method("get_tear_gas_zones"):
		for zone in throw_controller.get_tear_gas_zones():
			if float(zone.get("opacity", 1.0)) <= 0.12:
				continue
			var gas_center: Vector2 = zone.get("position", Vector2.ZERO)
			var gas_rx: float = float(zone.get("radius_x", zone.get("radius", 0.0)))
			var gas_ry: float = float(zone.get("radius", 0.0))
			if gas_rx > 0.0 and gas_ry > 0.0:
				_destroy_solid_obstacles(func(cell_rect: Rect2) -> bool: return _rect_in_ellipse(cell_rect, gas_center, gas_rx, gas_ry))

	if throw_controller.has_method("get_explosion_zones"):
		for zone in throw_controller.get_explosion_zones():
			if not bool(zone.get("active", true)):
				continue
			var blast_center: Vector2 = zone.get("position", Vector2.ZERO)
			var blast_radius: float = float(zone.get("radius", 0.0))
			if blast_radius > 0.0:
				_destroy_solid_obstacles(func(cell_rect: Rect2) -> bool: return _rect_in_circle(cell_rect, blast_center, blast_radius))


func _destroy_solid_obstacles(test: Callable) -> int:
	var destroyed: int = 0
	destroyed += _sweep_destroy(_tetrominoes, ["falling", "settled"], test)
	destroyed += _sweep_destroy(_guard_blocks, ["active"], test)
	destroyed += _sweep_destroy(_wall_blocks, ["active"], test)
	return destroyed


func _sweep_destroy(blocks: Array, solid_states: Array, test: Callable) -> int:
	var doomed: Array = []
	for block in blocks:
		if not solid_states.has(String(block.get("state", ""))):
			continue
		var origin: Vector2 = block["origin"]
		for cell in block["cells"]:
			var cell_rect: Rect2 = Rect2(origin + cell * TETRO_CELL_SIZE, Vector2(TETRO_CELL_SIZE, TETRO_CELL_SIZE))
			if bool(test.call(cell_rect)):
				doomed.append(block)
				break
	for block in doomed:
		_destroy_block_group(blocks, block, _block_color(block))
	return doomed.size()


func _block_color(block: Dictionary) -> Color:
	if block.has("color"):
		return block["color"]
	if block.has("shape"):
		return TETRO_COLORS.get(String(block["shape"]), Color(0.6, 0.7, 1.0))
	return GUARD_COLOR


func _rect_in_ellipse(cell_rect: Rect2, center: Vector2, rx: float, ry: float) -> bool:
	if rx <= 0.0 or ry <= 0.0:
		return false
	var c: Vector2 = cell_rect.get_center()
	var dx: float = (c.x - center.x) / rx
	var dy: float = (c.y - center.y) / ry
	return dx * dx + dy * dy <= 1.0


func _rect_in_circle(cell_rect: Rect2, center: Vector2, radius: float) -> bool:
	return cell_rect.get_center().distance_to(center) <= radius


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
		"stage6_tetriser_guard_blocks": _build_guard_draw_list(),
		"stage6_tetriser_wall_cells": _build_wall_draw_list(),
		"stage6_tetriser_debris": _build_debris_draw_list(),
		"stage6_tetriser_cell_size": TETRO_CELL_SIZE,
	}


func _build_wall_draw_list() -> Array:
	var out: Array = []
	for block in _wall_blocks:
		out.append({
			"origin": block.get("origin", Vector2.ZERO),
			"color": block.get("color", Color(0.6, 0.7, 1.0)),
		})
	return out


func _build_guard_draw_list() -> Array:
	var out: Array = []
	for block in _guard_blocks:
		out.append({
			"state": block.get("state", "active"),
			"origin": block.get("origin", Vector2.ZERO),
			"cells": (block.get("cells", []) as Array).duplicate(),
			"color": GUARD_COLOR,
		})
	return out


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


func debug_get_guard_count() -> int:
	return _guard_blocks.size()


func debug_get_wall_cell_count() -> int:
	return _wall_blocks.size()


func debug_force_spawn_wall() -> void:
	_spawn_tetro_wall()


# 결정론적 테스트용: 지정 위치에 단일 벽 셀 배치.
func debug_spawn_wall_cell_at(origin: Vector2) -> void:
	_wall_blocks.append({
		"kind": "wall",
		"state": "active",
		"cells": [Vector2(0, 0)],
		"origin": origin,
		"color": Color(0.6, 0.7, 1.0),
	})


# 결정론적 테스트용: 지정 위치에 즉시 'active' 가드 블록 배치.
func debug_spawn_guard_at(origin: Vector2, side: String = "left") -> void:
	_guard_blocks.append({
		"kind": "guard",
		"state": "active",
		"side": side,
		"cells": GUARD_CELLS.duplicate(),
		"origin": origin,
		"start_origin": origin,
		"final_origin": origin,
		"slide_elapsed": GUARD_SLIDE_SEC,
	})


func debug_get_gauge() -> float:
	return boss_gauge


func debug_get_tetromino_count() -> int:
	return _tetrominoes.size()


func debug_get_tetromino_states() -> Array:
	var out: Array = []
	for tetro in _tetrominoes:
		out.append(String(tetro.get("state", "")))
	return out
