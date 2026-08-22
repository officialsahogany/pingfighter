extends RefCounted

const CrystalShieldState := preload("res://scripts/stages/stage6/stage6_tetriser_crystal_shield_state.gd")
const TetriserCombatFeedbackState := preload("res://scripts/stages/stage6/stage6_tetriser_combat_feedback_state.gd")
const TetriserContextBuilder := preload("res://scripts/stages/stage6/stage6_tetriser_context_builder.gd")
const TetriserCubeState := preload("res://scripts/stages/stage6/stage6_tetriser_cube_state.gd")
const TetriserEventCoordinator := preload("res://scripts/stages/stage6/stage6_tetriser_event_coordinator.gd")
const TetriserGuardState := preload("res://scripts/stages/stage6/stage6_tetriser_guard_state.gd")
const TetriserHudStateBuilder := preload("res://scripts/stages/stage6/stage6_tetriser_hud_state_builder.gd")
const TetriserObstacleInteraction := preload("res://scripts/stages/stage6/stage6_tetriser_obstacle_interaction.gd")
const TetriserPlayerExplosionApplier := preload("res://scripts/stages/stage6/stage6_tetriser_player_explosion_applier.gd")
const TetriserStarpointState := preload("res://scripts/stages/stage6/stage6_tetriser_starpoint_state.gd")
const TetriserSuperState := preload("res://scripts/stages/stage6/stage6_tetriser_super_state.gd")
const TetriserTetrominoState := preload("res://scripts/stages/stage6/stage6_tetriser_tetromino_state.gd")
const TetriserWallState := preload("res://scripts/stages/stage6/stage6_tetriser_wall_state.gd")

# Stage 6 Tetriser boss state.
#
# Planning: docs/stage6_tetriser_port_plan.md
# Source reference: legacy Python stage7 Tetriser / game_logic/stage7_tetriser.py.
#
# Runtime owner summary:
#   - boss gauge (max 500, 25/sec, round-persistent)
#   - tetromino, super/laser, and central-cube event-order delegation
#   - starpoint, combat-feedback, and player-explosion event coordination
#   - obstacle destruction/cube-progress callbacks
#   - boss AI / actor draw and boss skill-card HUD context delegation
#   - Falling/settled tetrominoes, obstacle collision/attack policy, Super/laser
#     lifecycle, starpoint-drop lifecycle, combat feedback, player-explosion
#     response, cross-owner event coordination, actor/boss-AI context,
#     boss skill-card projection, Guard bars,
#     edge tetro walls, central-cube state, and Crystal Shield delegate to
#     focused owners.
#
# 단일 cleanup 경로 규율 (홍련 패턴 / CLAUDE.md 보스 이벤트 누수 규칙):
# round / result / stage-leave 모두 `_clear_combat_state()`를 통과한다.
# 게이지는 라운드 간 보존(원본 stage7_persistent_boss_gauge)이므로 reset_round()
# 에서는 비우지 않고 reset()/reset_for_result()에서만 0으로 되돌린다.

const STAGE_ID := 6
# === 보스 게이지 (원본 update_stage7_gauge_charge: elapsed_ms * 0.025, cap 500) ===
const GAUGE_MAX := 500.0
const GAUGE_CHARGE_PER_SEC := 25.0

# === 낙하 테트로미노 외부 효과 계약 ===
const TETRO_CELL_SIZE := TetriserTetrominoState.CELL_SIZE
# === 중앙 큐브 (원본 stage7_center_cube_state, 2D 논리 큐브) ===
# 화면 중앙 원형 존. 공이 진입할 때마다 3×3 그리드 셔플, passes_to_solve(10~14)
# 도달 시 단색 정답 → 1초 후 폭발 → 맵 테트로/벽 정리. 이후 재조립 모드:
# 플레이어가 테트로 5개 파괴 시 새 큐브 활성. (광선 melt는 4c, EMP는 4c.)
# === 초인 광선 + EMP (원본 STAGE7_TETRO_LASER_* / 큐브 melt by_laser) ===

var boss_gauge: float = 0.0
var status: String = "charging"

var _tetromino_state: Object = null
var _combat_feedback: Object = TetriserCombatFeedbackState.new()
var _context_builder: Object = TetriserContextBuilder.new()
var _event_coordinator: Object = null
var _starpoint_state: Object = null
var _guard_state: Object = null
var _hud_state_builder: Object = TetriserHudStateBuilder.new()
var _super_state: Object = TetriserSuperState.new()
var _wall_state: Object = null
var _cube_state: Object = null
var _obstacle_interaction: Object = null
var _player_explosion_applier: Object = TetriserPlayerExplosionApplier.new()
var _crystal_shield: Object = CrystalShieldState.new()
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()
	_tetromino_state = TetriserTetrominoState.new(_rng)
	_guard_state = TetriserGuardState.new(_rng)
	_wall_state = TetriserWallState.new(
		_rng,
		TetriserTetrominoState.SHAPES,
		TetriserTetrominoState.COLORS,
		TetriserTetrominoState.SHAPES.keys()
	)
	_cube_state = TetriserCubeState.new(_rng)
	_starpoint_state = TetriserStarpointState.new(_rng)
	_event_coordinator = TetriserEventCoordinator.new(
		_tetromino_state,
		_guard_state,
		_wall_state,
		_cube_state,
		_starpoint_state,
		_super_state,
		_combat_feedback,
		_player_explosion_applier
	)
	_obstacle_interaction = TetriserObstacleInteraction.new(
		_rng,
		_tetromino_state,
		_guard_state,
		_wall_state,
		Callable(_event_coordinator, "destroy_tetromino"),
		Callable(_event_coordinator, "destroy_guard_block"),
		Callable(_event_coordinator, "handle_extracted_guard"),
		Callable(_event_coordinator, "destroy_wall_piece"),
		Callable(_event_coordinator, "handle_super_tetromino_bounce")
	)


# ============================================================================
# Reset 경로 (단일 _clear_combat_state 코어)
# ============================================================================

func reset() -> void:
	# 전체 초기화(스테이지 이탈 / 디버그 피커 진입). 게이지도 0.
	_clear_combat_state(true)
	boss_gauge = 0.0
	status = "charging"


func reset_round() -> void:
	# 라운드 경계. 전투 구조물만 정리하고 게이지는 보존(원본 persistent).
	_clear_combat_state(false)
	status = "charging"


func reset_for_result() -> void:
	# 결과/게임 종료 — 다음 게임으로 게이지/블록 누수 방지(전체 초기화).
	reset()


func _clear_combat_state(clear_match_state: bool = false) -> void:
	_tetromino_state.clear_blocks()
	_guard_state.clear_blocks()
	_wall_state.clear_blocks()
	_combat_feedback.reset()
	_starpoint_state.clear()
	_super_state.reset()
	_crystal_shield.reset(clear_match_state)
	# Boss skill cooldown timers are persistent like boss_gauge: only a full match
	# reset (init / stage-leave / result) re-arms them. A round boundary preserves
	# them, or every lost point would visibly restart the guard/drop/wall cards.
	if clear_match_state:
		_tetromino_state.arm_timer()
		_guard_state.arm_timer()
		_wall_state.arm_timer()
	_cube_state.reset()


# ============================================================================
# Per-frame tick
# ============================================================================

func update(delta: float, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID:
		if _tetromino_state.has_blocks() or _starpoint_state.has_drops() or _combat_feedback.has_runtime_state() or boss_gauge > 0.0 or _crystal_shield.has_runtime_state():
			reset()
		return _build_result()

	var clamped_delta: float = clampf(delta, 0.0, 0.1)
	var fps_scale: float = clamped_delta * 60.0
	_crystal_shield.update(clamped_delta, context)

	# 비활성 / 서브 대기 / 시간 정지 중에는 게이지·스폰·낙하 모두 정지(블록 동결, 게이지 유지).
	if not bool(context.get("ball_active", false)) \
			or bool(context.get("waiting_for_serve", false)) \
			or _is_timing_frozen(context):
		status = "crystal_shield" if _crystal_shield.is_freeze_active() else "paused"
		return _build_result()

	status = "charging"
	_update_super_state(clamped_delta)
	if not _super_state.is_active():
		_charge_gauge(clamped_delta)   # 초인테트리서 발동 중에는 충전 정지(드레인만)
	boss_gauge -= _tetromino_state.update_scheduler(
		clamped_delta,
		context,
		boss_gauge,
		_super_state.is_active()
	)
	boss_gauge -= _guard_state.update_scheduler(clamped_delta, context, boss_gauge)
	var wall_spend: float = _wall_state.update_scheduler(clamped_delta, boss_gauge)
	if wall_spend > 0.0:
		boss_gauge -= wall_spend
		_combat_feedback.queue_sound(TetriserCombatFeedbackState.SOUND_WALL)
	_tetromino_state.update_lifecycle(
		clamped_delta,
		_wall_state.get_installed_cell_rects(),
		Callable(_event_coordinator, "handle_tetromino_lifecycle_event").bind(context, deps)
	)
	_guard_state.update_motion(clamped_delta)
	_combat_feedback.emit_debris_events(
		_wall_state.update_lifetime(clamped_delta),
		TetriserWallState.FALLBACK_COLOR,
		TETRO_CELL_SIZE
	)
	_obstacle_interaction.apply_player_attack_destruction(context, deps)
	_event_coordinator.update_cube(clamped_delta, context.get("ball_pos", Vector2(-9999.0, -9999.0)))
	_event_coordinator.update_laser(clamped_delta)
	_combat_feedback.update(clamped_delta)
	_starpoint_state.update(fps_scale, context, deps)
	_combat_feedback.flush_sounds(deps)
	return _build_result()


func _charge_gauge(delta: float) -> void:
	if boss_gauge >= GAUGE_MAX:
		boss_gauge = GAUGE_MAX
		return
	boss_gauge = minf(GAUGE_MAX, boss_gauge + GAUGE_CHARGE_PER_SEC * delta)


func _update_super_state(delta: float) -> void:
	var result: Dictionary = _super_state.update_super(delta, boss_gauge)
	boss_gauge = float(result.get("gauge", boss_gauge))
	if bool(result.get("status_super", false)):
		status = "super"
	if bool(result.get("activated", false)):
		_combat_feedback.queue_sound(TetriserCombatFeedbackState.SOUND_SUPER)


# ============================================================================
# 공 충돌 / 반사 / 파괴 (ball_update_controller가 motion step 직후 호출)
# ============================================================================

# scene["ball_pos"]는 공의 '중심'(commando_supply_drop 선례와 동일 규약).
# 테트로미노 → 가드 블록 순으로 첫 충돌 셀을 찾아 반사 + 파괴한다.
func resolve_ball_collision(scene: Dictionary, context: Dictionary, _deps: Dictionary = {}) -> bool:
	if _crystal_shield.resolve_ball_collision(scene, context, _deps):
		_combat_feedback.queue_sound(TetriserCombatFeedbackState.SOUND_SHIELD)
		return true
	return _obstacle_interaction.resolve_ball_collision(scene, context)


func _is_timing_frozen(context: Dictionary) -> bool:
	return bool(context.get("stopwatch_freeze_active", false)) \
		or bool(context.get("perk_resume_freeze_active", false)) \
		or bool(context.get("power_smashing_freeze_active", false)) \
		or bool(context.get("viper_dmk_freeze_active", false)) \
		or bool(context.get("viper_nerve_strike_freeze_active", false))


func _build_result() -> Dictionary:
	# 2a에서는 공 모션을 가로채지 않는다(공 충돌은 2b).
	var result := {"skip_ball_motion_step": false}
	result.merge(_crystal_shield.get_update_result(), true)
	return result


# ============================================================================
# State queries (HUD / boss AI / renderer 소비)
# ============================================================================

func get_actor_draw_context() -> Dictionary:
	return _context_builder.build_actor_draw_context(
		TETRO_CELL_SIZE,
		_tetromino_state,
		_guard_state,
		_wall_state,
		_combat_feedback,
		_cube_state,
		_starpoint_state,
		_super_state,
		_crystal_shield,
		TetriserCubeState.CENTER
	)


func get_boss_ai_context() -> Dictionary:
	return _context_builder.build_boss_ai_context(
		boss_gauge,
		_tetromino_state,
		_super_state,
		_crystal_shield
	)


func get_hud_context(_stage_background: Object = null, _context: Dictionary = {}) -> Dictionary:
	# 보스 스킬 카드 HUD(달지식)가 소비. 게이지 + 4스킬(낙하/가드/벽/초인) 카드.
	return _hud_state_builder.build_context(
		boss_gauge,
		status,
		GAUGE_MAX,
		GAUGE_CHARGE_PER_SEC,
		_tetromino_state,
		_guard_state,
		_wall_state,
		_super_state
	)


func should_skip_ball_motion_step() -> bool:
	return false


func get_status() -> String:
	return status


# ============================================================================
# Debug / test hooks
# ============================================================================

func debug_force_spawn_tetromino(context: Dictionary = {}) -> void:
	_tetromino_state.spawn(context, _super_state.is_active())


func debug_set_spawn_timer(value: float) -> void:
	_tetromino_state.debug_set_timer(value)


func debug_set_rng_seed(seed: int) -> void:
	_rng.seed = seed


# 결정론적 충돌 테스트용: 지정 위치에 즉시 'falling' 테트로미노 배치.
func debug_spawn_tetromino_at(origin: Vector2, shape: String = "O", super_flag: bool = false, golden: bool = false) -> void:
	_tetromino_state.debug_spawn_at(origin, shape, super_flag, golden)


func debug_configure_first_tetromino_motion(motion: Dictionary) -> void:
	_tetromino_state.debug_configure_first_motion(motion)


func debug_get_first_tetromino_origin() -> Vector2:
	return _tetromino_state.debug_get_first_origin()


func debug_get_first_tetromino_cells() -> Array:
	return _tetromino_state.debug_get_first_cells()


func debug_get_first_tetromino_motion() -> Dictionary:
	return _tetromino_state.debug_get_first_motion()


func debug_get_debris_count() -> int:
	return _combat_feedback.get_debris_count()


func debug_spawn_starpoint_drop_at(pos: Vector2) -> void:
	_starpoint_state.spawn(pos)


func debug_get_starpoint_drop_count() -> int:
	return _starpoint_state.get_count()


func debug_get_starpoint_drops_snapshot() -> Array:
	return _starpoint_state.get_snapshot()


func debug_get_guard_count() -> int:
	return _guard_state.get_count()


func debug_get_guard_states() -> Array:
	return _guard_state.get_states()


func debug_get_guard_visible_counts() -> Array:
	return _guard_state.get_visible_counts()


func debug_force_spawn_guard(context: Dictionary = {}) -> void:
	_guard_state.debug_force_scheduler_ready()
	boss_gauge -= _guard_state.update_scheduler(0.0, context if not context.is_empty() else {
		"current_stage": STAGE_ID,
		"ball_active": true,
		"waiting_for_serve": false,
	}, boss_gauge)


func debug_get_wall_cell_count() -> int:
	return _wall_state.get_cell_count()


func debug_get_wall_collidable_cell_count() -> int:
	return _wall_state.get_collidable_cell_count()


func debug_get_wall_piece_count() -> int:
	return _wall_state.get_piece_count()


func debug_get_wall_states() -> Array:
	return _wall_state.get_states()


func debug_force_spawn_wall(seed: int = -1) -> void:
	if seed >= 0:
		_rng.seed = seed
	_wall_state.spawn_wall()
	_combat_feedback.queue_sound(TetriserCombatFeedbackState.SOUND_WALL)


# 결정론적 테스트용: 지정 위치에 단일 벽 셀 배치.
func debug_spawn_wall_cell_at(origin: Vector2, golden: bool = false) -> void:
	_wall_state.debug_spawn_cell_at(origin, golden)


# 결정론적 테스트용: 지정 위치에 즉시 'active' 가드 블록 배치.
func debug_spawn_guard_at(origin: Vector2, side: String = "left") -> void:
	_guard_state.debug_spawn_active_at(origin, side)


func debug_get_gauge() -> float:
	return boss_gauge


func debug_set_gauge(value: float) -> void:
	boss_gauge = clampf(value, 0.0, GAUGE_MAX)


func debug_is_super_active() -> bool:
	return _super_state.is_active()


func debug_get_super_scale() -> float:
	return _super_state.get_scale()


func debug_is_cube_active() -> bool:
	return bool(_cube_state.is_active())


func debug_get_cube_rebuild_progress() -> int:
	return int(_cube_state.get_rebuild_progress())


func debug_is_cube_rebuild() -> bool:
	return bool(_cube_state.is_rebuild())


func debug_get_laser_state() -> String:
	return _super_state.get_laser_state()


func debug_get_emp_count() -> int:
	return _combat_feedback.get_emp_count()


func debug_force_crystal_shield_pending() -> void:
	_crystal_shield.debug_force_pending()


func debug_start_crystal_shield(boss_center: Vector2 = Vector2(380.0, 45.0), active_immediately: bool = false) -> void:
	_crystal_shield.debug_start(boss_center, active_immediately)


func debug_is_crystal_shield_pending() -> bool:
	return bool(_crystal_shield.pending_activation)


func debug_is_crystal_shield_freeze_active() -> bool:
	return _crystal_shield.is_freeze_active()


func debug_is_crystal_shield_active() -> bool:
	return _crystal_shield.is_active()


func debug_get_crystal_shield_block_count() -> int:
	return _crystal_shield.get_active_block_count()


# 결정론적 테스트용: 공 1회 큐브 통과 시뮬레이션.
func debug_pass_ball_through_cube() -> void:
	_cube_state.debug_pass_ball_through()


# 결정론적 테스트용: 솔브 대기까지 강제로 패스 누적 후, delta로 솔브 타이머 진행.
func debug_force_cube_solve_pending() -> void:
	_cube_state.debug_force_solve_pending()


func debug_get_tetromino_count() -> int:
	return _tetromino_state.get_count()


func debug_get_tetromino_states() -> Array:
	return _tetromino_state.get_states()
