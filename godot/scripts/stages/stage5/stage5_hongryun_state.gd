extends RefCounted

const Stage5HongryunPayloadFactory := preload("res://scripts/stages/stage5/stage5_hongryun_payload_factory.gd")
const CommonStarpointVisualHost := preload("res://scripts/effects/common_starpoint_visual_host.gd")
const LingpetStarlightTrackingBridge := preload("res://scripts/stages/common/lingpet_starlight_tracking_bridge.gd")
const StarpointBonusDropPolicy := preload("res://scripts/stages/common/starpoint_bonus_drop_policy.gd")
const PlayerKnockbackImmunity := preload("res://scripts/stages/common/player_knockback_immunity.gd")
const StarpointCollectionCompaction := preload("res://scripts/stages/common/starpoint_collection_compaction.gd")
const StarpointCollectionRewardPolicy := preload("res://scripts/stages/common/starpoint_collection_reward_policy.gd")
const StarpointDowsingAttraction := preload("res://scripts/stages/common/starpoint_dowsing_attraction.gd")
const StarpointDropMotionState := preload("res://scripts/stages/common/starpoint_drop_motion_state.gd")
const StarpointDropOverlapQuery := preload("res://scripts/stages/common/starpoint_drop_overlap_query.gd")
const StarpointParticleState := preload("res://scripts/stages/common/starpoint_particle_state.gd")
const StarpointPayloadFactory := preload("res://scripts/stages/common/starpoint_payload_factory.gd")
const StagePlayerInteractionRects := preload("res://scripts/stages/common/stage_player_interaction_rects.gd")
const StagePlayfieldBounds := preload("res://scripts/stages/common/stage_playfield_bounds.gd")
const BossSkillParryGate := preload("res://scripts/stages/common/boss_skill_parry_gate.gd")

# Stage 5 홍련 boss state.
#
# 단일 cleanup 경로 규율 (CLAUDE.md "Legacy Stage Order Reference + Current
# Godot Decision" / docs/stage5_hongryun_godot_port_plan.md §5):
# round-end / show_result / stage-leave 세 경로 모두 `_clear_combat_state()`
# 1개 함수를 통과시킨다. 새 상태 변수를 추가할 때도 그 함수 안에만 정리를
# 추가하면 누락이 발생할 수 없도록 유지한다.
#
# 원본 참조:
# - pingfighter.py `flame_trail_*`, `hongryun_hit_count`, `hongryun_ready`,
#   `HONGRYUN_MAX_HITS`, `show_hongryun_explosion()`, `_stage6_ball_mark_phase`
# - game_state.HONGRYUN_MAX_HITS

const STAGE_ID := 5

# === 홍련탄 (boss-thrown fireball) ===
# 원본 기획: 라운드 시작 2.5초 후 활성, 3.5~5.0초 쿨다운, 기본 1발 /
# 40% 확률 2~3발. 정확한 수치는 MVP 구현 시 원본 핸들러에서 확정.
const FIREBALL_INITIAL_DELAY_SEC := 2.5
const FIREBALL_COOLDOWN_MIN_SEC := 3.5
const FIREBALL_COOLDOWN_MAX_SEC := 5.0
const FIREBALL_MULTI_SHOT_CHANCE := 0.40
const FIREBALL_MULTI_SHOT_MIN := 2
const FIREBALL_MULTI_SHOT_MAX := 3
const FIREBALL_SPEED := 15.0
const FIREBALL_RADIUS := 12.8
const FIREBALL_OFFSCREEN_MARGIN := 100.0
const BOSS_THROW_WINDUP_FRAMES := 25.0
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0

# === 용 구슬 게이지 (홍련폭염 충전 카운터) ===
# 원본 game_state.HONGRYUN_MAX_HITS == 5.
const DRAGON_ORB_MAX := 5

# === 보스 피격 스타포인트 드랍 ===
# 홍련이 공에 맞을 때(보스 패들 접촉) 단일 굴림 1회:
# [0, 0.007) → 2개, [0.007, 0.025) → 1개, 나머지 → 없음.
# per-frame 재굴림이 아니라 접촉 이벤트당 1회라 확률 복리 트랩 없음.
const BOSS_HIT_STARPOINT_DOUBLE_CHANCE := 0.007
const BOSS_HIT_STARPOINT_SINGLE_CHANCE := 0.018
const BOSS_HIT_STARPOINT_SCATTER_PX := 30
# Drop 물리/수명 상수는 stage1~4 공용 값과 동일 유지.
const STARPOINT_DROP_SIZE := 12.0
const STARPOINT_DROP_LIFETIME := 600.0
const STARPOINT_DROP_ACCELERATION := 0.25
const STARPOINT_DROP_MAX_FALL_SPEED := 12.0
const STARPOINT_DROP_BOUNCE_DAMPING := 0.7
const STARPOINT_PARTICLE_COUNT := 20
const STARPOINT_PARTICLE_LIFE := 60.0
const STAR_DETECTOR_BONUS_DROP_OFFSET_CHOICES := [-36.0, -24.0, 24.0, 36.0]
const MAX_STAGE5_STARPOINT_DROPS := 12
const MAX_STAGE5_STARPOINT_PARTICLES := 96

# === 홍련폭염 (inferno burst) ===
# charge 1.4초 (원본 1.0초 + cinematic VFX 강도와 맞춤, 2026-05-18 결정)
# → snake-trail 가속 → 충돌 시 폭발. trail max length는 원본
# `flame_trail_positions.pop(0)` 30개 컷오프와 동일.
const INFERNO_CHARGE_SEC := 1.4
const INFERNO_TRAIL_MAX_LEN := 30
# Trail speed/amplitude는 원본 패리티 (pingfighter.py:185751-185756, 2026-05-18
# 코덱스 리뷰 복구). 원본 동작:
#   max_speed = 6.0, accel_time = 6.0
#   amplitude_x = min(40, 10 + t * 6)
#   amplitude_y = min(20, 5 + t * 3)
const INFERNO_MAX_SPEED := 6.0
const INFERNO_ACCEL_TIME_SEC := 6.0
const INFERNO_BASE_AMPLITUDE_X := 10.0
const INFERNO_BASE_AMPLITUDE_Y := 5.0
const INFERNO_MAX_AMPLITUDE_X := 40.0
const INFERNO_MAX_AMPLITUDE_Y := 20.0
const INFERNO_AMPLITUDE_X_GROWTH_PER_SEC := 6.0
const INFERNO_AMPLITUDE_Y_GROWTH_PER_SEC := 3.0
# Pillar excursion is a slow, large-amplitude lateral velocity term that
# integrates to a wide position swing so the ball physically drifts into the
# pillar letterbox. The high-freq wobble above keeps short jitter while this
# term carries the wide arcing motion. (1.0 - landing_progress) fades it out
# before final landing so the plunge funnels into the central guard lane.
const INFERNO_PILLAR_SWEEP_AMPLITUDE := 4.0
const INFERNO_PILLAR_SWEEP_FREQ_HZ := 0.35
# 홍련폭염 trail phase 한정으로 ball 좌표가 letterbox로 자유롭게 침범할 수
# 있게 허용한다 (2026-05-18 사용자 손맛 요청 — 원본 동작 패리티).
# Charge phase (phase 1)는 보스 옆에서 정지 상태라 letterbox 침범할 일이 없고,
# Charge VFX host는 별도 letterbox clamp 적용되어 있어 보스 옆 letterbox에는
# 침범하지 않는다. Trail phase의 ball 위치 = trail_fx_host head 위치이므로
# trail VFX는 ball 따라 letterbox로 함께 들어간다.
const INFERNO_PILLAR_OVERSHOOT_X := 240.0
const INFERNO_SAFETY_MAX_SEC := 8.0
# Removed (2026-05-18): INFERNO_TARGET_STEER_PER_SEC — was the auto-steering
# strength for trail base_vel. Original game has no auto-steer.
# Removed (2026-05-18): INFERNO_LANDING_FOCUS_DISTANCE,
# INFERNO_LANDING_MIN_WOBBLE_SCALE, INFERNO_GUARD_LANE_Y_MARGIN,
# INFERNO_LANDING_MAX_X_CORRECTION_PER_FRAME — used by auto-steer / wobble /
# funnel helpers that sapped variability. Phase 2 now matches original parity.
const PLAYER_STUN_FRAMES := 18.0
const PLAYER_FIREBALL_STUN_IMMUNITY_FRAMES := 24.0
const PLAYER_FIREBALL_KNOCKBACK := 18.0
const PLAYER_INFERNO_KNOCKBACK := 24.0
const PLAYER_KNOCKBACK_FRAMES := 18.0
const PLAYER_KNOCKBACK_DECAY := 0.88

# 결정적 RNG (멀티샷 / inferno noise 재현성).
const RNG_SEED := 5170

# ----- 홍련탄 -----
var fireball_cooldown := FIREBALL_INITIAL_DELAY_SEC
var fireball_cooldown_total := FIREBALL_INITIAL_DELAY_SEC
var fireball_projectiles: Array = []  # [{pos: Vector2, vel: Vector2, ...}]
var fireball_impact_events: Array = []  # transient draw/VFX hints
var pending_inferno_burst_active := false  # transient — true for one frame on inferno hit
var pending_inferno_burst_pos := Vector2.ZERO  # playfield coords; only valid when active
var boss_throwing_windup_active := false
var boss_throwing_windup_timer := 0.0
var player_fireball_stun_immunity_timer := 0.0

# ----- 용 구슬 게이지 -----
var dragon_orb_count := 0.0
var inferno_ready := false  # orb >= MAX 이후 보스 패들 접촉 대기

# ----- 홍련폭염 -----
var inferno_active := false
var inferno_phase := 0  # 0=idle, 1=charge, 2=trail
var inferno_charge_timer := 0.0
var inferno_trail_positions: Array = []  # [Vector2, ...]
var inferno_base_vel := Vector2.ZERO
var inferno_guard_target := Vector2.ZERO
var inferno_guard_target_locked := false
var inferno_started_at_ms := 0
var inferno_trail_elapsed_sec := 0.0

# ----- Ball-physics hijack -----
# 외부 ball updater가 `should_skip_ball_motion_step()`을 매 프레임 확인.
# 단일 query → 단일 cleanup 패턴으로 skip 플래그 leak 차단.
var ball_hold_active := false
var ball_hijack_reason := ""

# ----- 보스 피격 스타포인트 드랍 -----
var starpoint_drops: Array = []
var starpoint_particles: Array = []

# ----- 일반 상태 -----
var status := "charging"
var rng := RandomNumberGenerator.new()
var was_waiting_for_serve := true


func _init() -> void:
	rng.seed = RNG_SEED


# ============================================================================
# Public cleanup API — 모두 _clear_combat_state() 1개를 통과한다.
# ============================================================================

# Stage 진입 / Stage 이탈 / debug stage switch / full reset.
func reset() -> void:
	_clear_combat_state()
	dragon_orb_count = 0.0
	inferno_ready = false
	fireball_cooldown = FIREBALL_INITIAL_DELAY_SEC
	fireball_cooldown_total = FIREBALL_INITIAL_DELAY_SEC
	status = "charging"
	was_waiting_for_serve = true


# 라운드 종료(스코어 이벤트) 후 serve-wait 진입.
# Godot Stage 5는 라운드를 넘어가도 dragon orb 게이지를 보존한다.
# 원본 Python의 라운드 전환 1칸 감소는 이 포팅 버전에서 의도적으로 제거.
func reset_round() -> void:
	_clear_combat_state()
	inferno_ready = dragon_orb_count >= float(DRAGON_ORB_MAX)
	fireball_cooldown = FIREBALL_INITIAL_DELAY_SEC
	fireball_cooldown_total = FIREBALL_INITIAL_DELAY_SEC
	status = "charging"
	was_waiting_for_serve = true


# 결과 화면 / 게임 종료 진입.
# 원본 show_result()가 홍련 상태 정리를 누락해 다음 게임 Stage 1에
# `flame_trail_active` / `hongryun_*` 글로벌이 누수되던 트랩을 차단한다.
# 호출자가 이름만 보고도 의도를 알 수 있도록 별도 진입점으로 노출.
func reset_for_result() -> void:
	reset()


# 단일 combat-state cleanup 코어 — 모든 reset 경로의 공통 진입.
# 새 상태 변수 추가 시 여기에 정리를 추가하면 round/result/stage-leave
# 셋이 자동으로 같이 정리된다.
func _clear_combat_state() -> void:
	fireball_projectiles.clear()
	fireball_impact_events.clear()
	pending_inferno_burst_active = false
	pending_inferno_burst_pos = Vector2.ZERO
	boss_throwing_windup_active = false
	boss_throwing_windup_timer = 0.0
	player_fireball_stun_immunity_timer = 0.0
	inferno_active = false
	inferno_phase = 0
	inferno_charge_timer = 0.0
	inferno_trail_positions.clear()
	inferno_base_vel = Vector2.ZERO
	inferno_guard_target = Vector2.ZERO
	inferno_guard_target_locked = false
	inferno_started_at_ms = 0
	inferno_trail_elapsed_sec = 0.0
	ball_hold_active = false
	ball_hijack_reason = ""
	var had_starpoints := not starpoint_drops.is_empty() or not starpoint_particles.is_empty()
	starpoint_drops.clear()
	starpoint_particles.clear()
	if had_starpoints:
		CommonStarpointVisualHost.hide_all_existing_hosts()


# ============================================================================
# Per-frame tick
# ============================================================================

func update(delta: float, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID:
		if (
			inferno_active
			or dragon_orb_count > 0
			or fireball_projectiles.size() > 0
			or not starpoint_drops.is_empty()
			or not starpoint_particles.is_empty()
		):
			reset()
		return {"skip_ball_motion_step": false}

	var perf_logger: Object = deps.get("perf_logger", null)
	var clamped_delta: float = clampf(delta, 0.0, 0.1)
	var fps_scale: float = clamped_delta * 60.0
	var result := {}
	var sample_start: int = _perf_begin(perf_logger)
	fireball_impact_events.clear()
	pending_inferno_burst_active = false
	_tick_player_fireball_immunity(fps_scale)
	_perf_end(perf_logger, "physics.stage5.hongryun.immunity", sample_start)

	if not bool(context.get("ball_active", false)) or bool(context.get("waiting_for_serve", false)):
		was_waiting_for_serve = true
		status = "paused"
		if not _is_timing_frozen(context):
			sample_start = _perf_begin(perf_logger)
			_update_fireball_projectiles(fps_scale, context, deps, result)
			_perf_end(perf_logger, "physics.stage5.hongryun.projectiles_paused", sample_start)
			_update_starpoint_drops(fps_scale, context, deps)
			_update_starpoint_particles(fps_scale)
		result.merge(_build_public_update_result(), false)
		return result
	was_waiting_for_serve = false

	if _is_timing_frozen(context):
		status = "paused"
		result.merge(_build_public_update_result(), false)
		return result

	if inferno_active:
		sample_start = _perf_begin(perf_logger)
		_update_inferno(clamped_delta, fps_scale, context, deps, result)
		_perf_end(perf_logger, "physics.stage5.hongryun.inferno", sample_start)
	else:
		sample_start = _perf_begin(perf_logger)
		_update_fireball_skill(clamped_delta, context, deps, result)
		_perf_end(perf_logger, "physics.stage5.hongryun.fireball_skill", sample_start)

	sample_start = _perf_begin(perf_logger)
	_update_boss_throwing_windup(fps_scale)
	_perf_end(perf_logger, "physics.stage5.hongryun.boss_throw_windup", sample_start)
	sample_start = _perf_begin(perf_logger)
	_update_fireball_projectiles(fps_scale, context, deps, result)
	_perf_end(perf_logger, "physics.stage5.hongryun.projectiles", sample_start)
	sample_start = _perf_begin(perf_logger)
	_update_starpoint_drops(fps_scale, context, deps)
	_update_starpoint_particles(fps_scale)
	_perf_end(perf_logger, "physics.stage5.hongryun.starpoints", sample_start)
	result.merge(_build_public_update_result(), false)
	return result

# ============================================================================
# State queries (HUD / boss AI / renderer 소비)
# ============================================================================

# 보스 카드 HUD가 소비하는 dict — stage2/stage4 패턴과 동일 shape.
func get_hud_context(_stage_background: Object = null, _context: Dictionary = {}) -> Dictionary:
	return {
		"stage5_boss_skill_hud_active": true,
		"stage5_boss_skill_hud_boss_name": "홍련",
		"stage5_boss_skill_hud_status": status,
		"stage5_boss_skill_hud_dragon_orb_count": dragon_orb_count,
		"stage5_boss_skill_hud_dragon_orb_max": DRAGON_ORB_MAX,
		"stage5_boss_skill_hud_dragon_orb_ready": inferno_ready,
		"stage5_boss_skill_hud_inferno_active": inferno_active,
		"stage5_boss_skill_hud_skills": [
			_get_fireball_hud_skill(),
			_get_inferno_hud_skill(),
		],
	}


func get_boss_ai_context() -> Dictionary:
	return {
		"stage5_hongryun_inferno_active": inferno_active,
		"stage5_hongryun_inferno_phase": inferno_phase,
		"stage5_hongryun_dragon_orb_count": dragon_orb_count,
		"stage5_hongryun_inferno_ready": inferno_ready,
		"stage5_hongryun_boss_throwing": boss_throwing_windup_active,
	}


func get_actor_draw_context() -> Dictionary:
	var charge_remaining: float = clamp(inferno_charge_timer / INFERNO_CHARGE_SEC, 0.0, 1.0) if inferno_phase == 1 else 0.0
	return {
		"stage5_hongryun_fireballs": fireball_projectiles.duplicate(true),
		"stage5_hongryun_fireball_impacts": fireball_impact_events.duplicate(true),
		"stage5_hongryun_inferno_active": inferno_active,
		"stage5_hongryun_inferno_phase": inferno_phase,
		"stage5_hongryun_inferno_charge_progress": charge_remaining,
		"stage5_hongryun_inferno_charge_ratio": 1.0 - charge_remaining,
		"stage5_hongryun_inferno_trail": inferno_trail_positions.duplicate(),
		"stage5_hongryun_inferno_trail_elapsed_sec": inferno_trail_elapsed_sec,
		"stage5_hongryun_inferno_burst_pending": pending_inferno_burst_active,
		"stage5_hongryun_inferno_burst_pos": pending_inferno_burst_pos,
		"stage5_hongryun_dragon_orb_count": dragon_orb_count,
		"stage5_hongryun_boss_throwing": boss_throwing_windup_active,
		"stage5_hongryun_boss_throw_progress": _get_boss_throw_progress(),
		"stage5_hongryun_starpoint_drops": starpoint_drops.duplicate(true),
		"stage5_hongryun_starpoint_particles": starpoint_particles.duplicate(true),
	}


# 외부 ball updater는 매 프레임 이 결과를 보고 motion step skip 여부 결정.
# 단일 query 강제 → cleanup 단일 함수와 짝을 이뤄 skip 플래그 leak 차단.
func should_skip_ball_motion_step() -> bool:
	if ball_hold_active:
		return true
	if inferno_active and inferno_phase == 1:
		return true
	return false


# ============================================================================
# Event hooks
# ============================================================================

# 보스 → 플레이어 화염탄이 플레이어를 맞췄을 때.
# inferno 활성 중에는 게이지 충전 막는다(원본 동작).
func register_fireball_hit_player(deps: Dictionary = {}) -> Dictionary:
	if not inferno_active:
		dragon_orb_count = min(float(DRAGON_ORB_MAX), dragon_orb_count + 1.0)
		if dragon_orb_count >= DRAGON_ORB_MAX:
			inferno_ready = true
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_stage5_hongryun_hurt"):
		audio.play_stage5_hongryun_hurt()
	return {
		"stage5_hongryun_dragon_orb_count": dragon_orb_count,
		"stage5_hongryun_inferno_ready": inferno_ready,
	}


# 공이 보스 패들에 충돌했을 때 — 스타포인트 드랍 굴림 후,
# inferno_ready면 홍련폭염 시작.
func register_boss_paddle_contact(ball_vel: Vector2, deps: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	_roll_boss_hit_starpoint_drops(deps, context)
	if inferno_ready and not inferno_active:
		if BossSkillParryGate.try_parry("hongryun_inferno", "홍련폭염", context, deps):
			inferno_ready = false
			dragon_orb_count = 0.0
			status = "charging"
			return {"stage5_hongryun_inferno_parried": true}
		_start_inferno(ball_vel, deps, context)
		return {"stage5_hongryun_inferno_started": true}
	return {}


func resolve_inferno_player_guard(pos: Vector2, deps: Dictionary = {}, paddle_x: float = INF, paddle_w: float = 0.0) -> Dictionary:
	if not inferno_active:
		return {}
	# Glance vs 정타 분기 (사용자 손맛 요청 — paddle 가장자리로 받으면
	# stun 없이 normal physics bounce로 빠른 역공). paddle 정보가 없으면
	# (legacy caller) 기존 단순 가드 동작 유지.
	if not is_inf(paddle_x) and paddle_w > 0.0:
		var paddle_center_x: float = paddle_x + paddle_w * 0.5
		var hit_offset_x: float = absf(pos.x - paddle_center_x)
		var glance_threshold: float = paddle_w * 0.35
		if hit_offset_x > glance_threshold:
			# Glance hit — trail 종료 + stun 없음 + ball_vel 그대로
			# (직전 frame_move의 inferno 속도가 normal physics에 상속됨 →
			# controller.bounce()가 보스 쪽으로 빠르게 반사).
			_register_fireball_impact(pos, "inferno_glance", deps, 1.2)
			_stop_inferno(deps)
			return {
				"skip_ball_motion_step": false,
				"stage5_hongryun_inferno_glance_bounce": true,
			}
	_register_fireball_impact(pos, "inferno_guard", deps, 1.35)
	_stop_inferno(deps)
	return {
		"skip_ball_motion_step": false,
		"stage5_hongryun_inferno_guarded": true,
	}


# 화염탄이 magic-anti 포션 등으로 parry된 경우 — 게이지 충전 차단만 알림.
# (원본 pingfighter.py:185659-185670 의 보스 스킬 면역 분기 대응.)
func resolve_inferno_player_miss(pos: Vector2, deps: Dictionary = {}) -> Dictionary:
	if not inferno_active:
		return {}
	_register_fireball_impact(pos, "inferno_miss", deps, 1.55)
	_stop_inferno(deps)
	return {
		"skip_ball_motion_step": false,
		"stage5_hongryun_inferno_missed_player": true,
	}


# 금강결계(바닥 무적)가 홍련폭염 trail 공을 받아냈을 때 — inferno를 종료하고
# 공을 normal physics로 되돌린다. inferno owned-ball은 step_motion()을 우회하므로
# ball_update_controller가 베리어 충돌을 직접 감지해 이 entry point를 호출한다
# (가드/미스 경로와 동일하게 _stop_inferno로 단일 cleanup을 통과시킨다).
func resolve_inferno_holy_barrier(pos: Vector2, deps: Dictionary = {}) -> Dictionary:
	if not inferno_active:
		return {}
	_register_fireball_impact(pos, "inferno_guard", deps, 1.35)
	_stop_inferno(deps)
	return {
		"skip_ball_motion_step": false,
		"stage5_hongryun_inferno_holy_barrier_block": true,
	}


func register_fireball_parried() -> Dictionary:
	return {"stage5_hongryun_fireball_parried": true}


# ============================================================================
# Private helpers
# ============================================================================

func _start_inferno(ball_vel: Vector2, deps: Dictionary, context: Dictionary = {}) -> void:
	var perf_logger: Object = deps.get("perf_logger", null)
	var sample_start: int = _perf_begin(perf_logger)
	inferno_active = true
	inferno_phase = 1
	inferno_charge_timer = INFERNO_CHARGE_SEC
	inferno_guard_target = _get_inferno_guard_target(context)
	inferno_guard_target_locked = true
	inferno_base_vel = _get_inferno_base_velocity(context, ball_vel)
	rng.randomize()
	inferno_trail_positions.clear()
	inferno_started_at_ms = Time.get_ticks_msec()
	inferno_trail_elapsed_sec = 0.0
	ball_hold_active = true
	ball_hijack_reason = "hongryun_inferno_charge"
	# 즉시 클리어해 중복 발동 방지.
	inferno_ready = false
	dragon_orb_count = 0.0
	status = "inferno_charge"
	_perf_end(perf_logger, "physics.stage5.hongryun.start_inferno_state", sample_start)
	_set_stage5_inferno_mode(true, deps)
	sample_start = _perf_begin(perf_logger)
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_stage5_hongryun_charge"):
		audio.play_stage5_hongryun_charge()
	_perf_end(perf_logger, "physics.stage5.hongryun.audio_charge", sample_start)


func _get_inferno_base_velocity(context: Dictionary, fallback_vel: Vector2) -> Vector2:
	var ball_pos: Vector2 = _get_vector2(context, "ball_pos", Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT * 0.5))
	var direction: Vector2 = _get_locked_inferno_guard_target(context) - ball_pos
	if direction.length() <= 0.001:
		direction = fallback_vel if fallback_vel.length() > 0.001 else Vector2.DOWN
	return direction.normalized()


func _update_fireball_skill(delta: float, context: Dictionary, deps: Dictionary, result: Dictionary) -> void:
	if _is_boss_skill_cooldown_paused(context):
		status = "paused"
		return
	status = "charging"
	fireball_cooldown = max(0.0, fireball_cooldown - delta)
	if fireball_cooldown > 0.0001:
		return
	_spawn_fireball_volley(context, deps, result)


func _spawn_fireball_volley(context: Dictionary, deps: Dictionary, result: Dictionary) -> void:
	var perf_logger: Object = deps.get("perf_logger", null)
	var sample_start: int = _perf_begin(perf_logger)
	if BossSkillParryGate.try_parry("hongryun_fireball", "화염탄", context, deps):
		fireball_cooldown_total = rng.randf_range(FIREBALL_COOLDOWN_MIN_SEC, FIREBALL_COOLDOWN_MAX_SEC)
		fireball_cooldown = fireball_cooldown_total
		status = "charging"
		result["stage5_hongryun_fireball_parried"] = true
		_perf_end(perf_logger, "physics.stage5.hongryun.fireball_spawn", sample_start)
		return
	var boss_origin: Vector2 = _get_boss_fireball_origin(context)
	var target_center: Vector2 = _get_player_rect(context).get_center()
	var count := 1
	if rng.randf() < FIREBALL_MULTI_SHOT_CHANCE:
		count = rng.randi_range(FIREBALL_MULTI_SHOT_MIN, FIREBALL_MULTI_SHOT_MAX)

	for _index in range(count):
		var direction: Vector2 = target_center - boss_origin
		if direction.length() <= 0.001:
			direction = Vector2.DOWN
		direction = direction.normalized().rotated(deg_to_rad(rng.randf_range(-20.0, 20.0)))
		fireball_projectiles.append(Stage5HongryunPayloadFactory.build_fireball_projectile(
			boss_origin,
			direction * FIREBALL_SPEED,
			FIREBALL_RADIUS
		))

	fireball_cooldown_total = rng.randf_range(FIREBALL_COOLDOWN_MIN_SEC, FIREBALL_COOLDOWN_MAX_SEC)
	fireball_cooldown = fireball_cooldown_total
	boss_throwing_windup_active = true
	boss_throwing_windup_timer = BOSS_THROW_WINDUP_FRAMES
	status = "casting"
	result["stage5_hongryun_fireball_spawned"] = count
	_perf_end(perf_logger, "physics.stage5.hongryun.fireball_spawn", sample_start)
	_trigger_stage5_spiral_burst(deps)
	sample_start = _perf_begin(perf_logger)
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_stage5_hongryun_fireball"):
		audio.play_stage5_hongryun_fireball()
	_perf_end(perf_logger, "physics.stage5.hongryun.audio_fireball", sample_start)


func _update_boss_throwing_windup(fps_scale: float) -> void:
	if not boss_throwing_windup_active:
		return
	boss_throwing_windup_timer = max(0.0, boss_throwing_windup_timer - fps_scale)
	if boss_throwing_windup_timer <= 0.0:
		boss_throwing_windup_active = false


func _update_fireball_projectiles(fps_scale: float, context: Dictionary, deps: Dictionary, result: Dictionary) -> void:
	if fireball_projectiles.is_empty():
		return

	var next_projectiles: Array = []
	var player_rect: Rect2 = _get_player_rect(context)
	for value in fireball_projectiles:
		if not (value is Dictionary):
			continue
		var projectile: Dictionary = value
		var pos: Vector2 = _get_dict_vector2(projectile, "pos", Vector2.ZERO)
		var vel: Vector2 = _get_dict_vector2(projectile, "vel", Vector2.ZERO)
		var radius: float = max(1.0, float(projectile.get("radius", FIREBALL_RADIUS)))
		pos += vel * fps_scale
		projectile["pos"] = pos
		projectile["age"] = float(projectile.get("age", 0.0)) + fps_scale

		var projectile_rect := Rect2(pos - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0))
		if projectile_rect.intersects(player_rect):
			_resolve_fireball_player_hit(pos, context, deps, result)
			continue
		if pos.y + radius >= FIELD_HEIGHT:
			_register_fireball_impact(pos, "floor", deps)
			continue
		if _is_fireball_inside_keepalive_bounds(pos):
			next_projectiles.append(projectile)
	fireball_projectiles = next_projectiles


func _resolve_fireball_player_hit(pos: Vector2, context: Dictionary, deps: Dictionary, result: Dictionary) -> void:
	_register_fireball_impact(pos, "player", deps)
	if _is_boss_skill_immune(context, deps):
		result.merge(register_fireball_parried(), true)
		_trigger_boss_skill_parry(pos, context, deps)
		return

	# 부동갑주(celestial_armor): 화염탄은 스턴+넉백을 동시에 주는 stun-bearing 히트라
	# 전체 히트를 stun 게이트로 막는다(한 롤로 스턴·넉백 동시 스킵). proc/클렌즈 시
	# register_fireball_hit_player(오브 충전·피격 SFX)·면역타이머까지 모두 스킵 —
	# "웨이브는 떴는데 스턴은 먹었다"는 부분차단 버그(신고된 화염탄/우박 증상)를 봉인.
	if PlayerKnockbackImmunity.is_cleanse_immune(deps, context):
		result["stage5_hongryun_player_hit_blocked_by_cleanse"] = true
		return
	if PlayerKnockbackImmunity.try_block_player_stun(deps, context, "stage5_fireball"):
		result["stage5_hongryun_player_hit_blocked_by_armor"] = true
		return

	result.merge(register_fireball_hit_player(deps), true)
	_apply_player_stun_and_knockback(
		"stage5_fireball",
		PLAYER_FIREBALL_KNOCKBACK,
		context,
		deps,
		result,
		true
	)
	result["stage5_hongryun_fireball_hit_player"] = true


func _update_inferno(delta: float, fps_scale: float, context: Dictionary, deps: Dictionary, result: Dictionary) -> void:
	var perf_logger: Object = deps.get("perf_logger", null)
	var sample_start: int = _perf_begin(perf_logger)
	var ball_pos: Vector2 = _get_vector2(context, "ball_pos", Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT * 0.5))
	var ball_vel: Vector2 = _get_vector2(context, "ball_vel", Vector2.ZERO)
	if inferno_base_vel.length() <= 0.001:
		inferno_base_vel = _get_locked_inferno_guard_target(context) - ball_pos
		if inferno_base_vel.length() <= 0.001:
			inferno_base_vel = ball_vel if ball_vel.length() > 0.001 else Vector2.DOWN
		inferno_base_vel = inferno_base_vel.normalized()

	_append_inferno_trail(ball_pos)
	_perf_end(perf_logger, "physics.stage5.hongryun.inferno_setup", sample_start)
	if inferno_phase == 1:
		sample_start = _perf_begin(perf_logger)
		inferno_charge_timer = max(0.0, inferno_charge_timer - delta)
		var charge_elapsed: float = INFERNO_CHARGE_SEC - inferno_charge_timer
		var jitter: Vector2 = Vector2(sin(charge_elapsed * 25.0) * 2.0, cos(charge_elapsed * 30.0) * 1.0) * max(0.0, fps_scale)
		ball_pos = _clamp_inferno_ball_pos(ball_pos + jitter, context)
		ball_vel = Vector2.ZERO
		result["ball_pos"] = ball_pos
		result["ball_vel"] = ball_vel
		if inferno_charge_timer <= 0.0:
			_enter_inferno_trail_phase(deps)
		status = "inferno_charge"
		_perf_end(perf_logger, "physics.stage5.hongryun.inferno_charge", sample_start)
		return

	sample_start = _perf_begin(perf_logger)
	inferno_phase = 2
	inferno_trail_elapsed_sec += delta
	var accel_elapsed: float = inferno_trail_elapsed_sec
	var current_speed: float = INFERNO_MAX_SPEED * min(1.0, accel_elapsed / INFERNO_ACCEL_TIME_SEC)
	current_speed = max(0.001, pow(current_speed, 1.2))
	# 원본 패리티 (pingfighter.py:185763-185764). 이전 구현은 auto-steering /
	# wobble_scale / landing_progress의 3중 도와주기 보정으로 player에 가까워질수록
	# 진동 + noise를 자동 축소해 사실상 자동 가드되었음. 원본은 base_vel +
	# sin/cos + 균등 noise 그대로 진행해 "쫄깃한 맛"을 유지한다.
	# pillar_excursion(cinematic letterbox sweep)만 유지.
	var base_dir: Vector2 = inferno_base_vel.normalized()
	var amplitude_x: float = min(
		INFERNO_MAX_AMPLITUDE_X,
		INFERNO_BASE_AMPLITUDE_X + accel_elapsed * INFERNO_AMPLITUDE_X_GROWTH_PER_SEC
	)
	var amplitude_y: float = min(
		INFERNO_MAX_AMPLITUDE_Y,
		INFERNO_BASE_AMPLITUDE_Y + accel_elapsed * INFERNO_AMPLITUDE_Y_GROWTH_PER_SEC
	)
	var pillar_sweep_phase: float = TAU * INFERNO_PILLAR_SWEEP_FREQ_HZ * accel_elapsed
	var pillar_excursion: float = sin(pillar_sweep_phase) * INFERNO_PILLAR_SWEEP_AMPLITUDE
	var frame_move := Vector2(
		base_dir.x * current_speed + sin(accel_elapsed * 6.0) * amplitude_x + pillar_excursion + rng.randf_range(-2.0, 2.0),
		base_dir.y * current_speed + cos(accel_elapsed * 3.0) * amplitude_y + rng.randf_range(-1.0, 1.0)
	)
	var previous_pos := ball_pos
	ball_pos = _clamp_inferno_ball_pos(ball_pos + frame_move * fps_scale, context, previous_pos)
	ball_vel = ball_pos - previous_pos
	result["ball_pos"] = ball_pos
	result["ball_vel"] = ball_vel
	status = "casting"
	_perf_end(perf_logger, "physics.stage5.hongryun.inferno_trail_motion", sample_start)
	if inferno_trail_elapsed_sec >= INFERNO_SAFETY_MAX_SEC:
		sample_start = _perf_begin(perf_logger)
		_stop_inferno(deps)
		_perf_end(perf_logger, "physics.stage5.hongryun.stop_inferno", sample_start)
		result["skip_ball_motion_step"] = false
		result["stage5_hongryun_inferno_expired"] = true


func _enter_inferno_trail_phase(deps: Dictionary) -> void:
	if inferno_phase == 2:
		return
	var perf_logger: Object = deps.get("perf_logger", null)
	var sample_start: int = _perf_begin(perf_logger)
	inferno_phase = 2
	inferno_charge_timer = 0.0
	inferno_trail_elapsed_sec = 0.0
	ball_hijack_reason = "hongryun_inferno_trail"
	_perf_end(perf_logger, "physics.stage5.hongryun.enter_inferno_trail", sample_start)
	sample_start = _perf_begin(perf_logger)
	var audio: Object = deps.get("audio", null)
	if audio != null:
		if audio.has_method("stop_stage5_hongryun_charge"):
			audio.stop_stage5_hongryun_charge()
		if audio.has_method("play_stage5_hongryun_shoot"):
			audio.play_stage5_hongryun_shoot()
	_perf_end(perf_logger, "physics.stage5.hongryun.audio_inferno_shoot", sample_start)


func _resolve_inferno_player_hit(pos: Vector2, context: Dictionary, deps: Dictionary, result: Dictionary) -> void:
	# 가장자리 vs 정타 분기는 `resolve_inferno_player_guard()` 안으로
	# 옮김 (그쪽이 ball_update_controller가 호출하는 실제 entry point).
	# 이 내부 helper는 phase 2 self-hit fallback용으로 단순 유지.
	_register_fireball_impact(pos, "inferno_player", deps, 1.7)
	_apply_player_stun_and_knockback(
		"flame_trail",
		PLAYER_INFERNO_KNOCKBACK,
		context,
		deps,
		result,
		false
	)
	_stop_inferno(deps)
	result["skip_ball_motion_step"] = false
	result["stage5_hongryun_inferno_hit_player"] = true
	# One-shot burst VFX at the impact location (playfield coords). Pending
	# flag lives for one frame; playfield_renderer consumes it via
	# get_actor_draw_context() and triggers stage5_hongryun_inferno_burst_fx_host.
	pending_inferno_burst_active = true
	pending_inferno_burst_pos = pos
	result["stage5_hongryun_inferno_burst_trigger"] = true
	result["stage5_hongryun_inferno_burst_pos"] = pos


func _stop_inferno(deps: Dictionary) -> void:
	inferno_active = false
	inferno_phase = 0
	inferno_charge_timer = 0.0
	inferno_trail_positions.clear()
	inferno_base_vel = Vector2.ZERO
	inferno_guard_target = Vector2.ZERO
	inferno_guard_target_locked = false
	inferno_started_at_ms = 0
	inferno_trail_elapsed_sec = 0.0
	ball_hold_active = false
	ball_hijack_reason = ""
	status = "charging"
	_set_stage5_inferno_mode(false, deps)
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("stop_stage5_hongryun_charge"):
		audio.stop_stage5_hongryun_charge()


func _append_inferno_trail(pos: Vector2) -> void:
	inferno_trail_positions.append(pos)
	while inferno_trail_positions.size() > INFERNO_TRAIL_MAX_LEN:
		inferno_trail_positions.pop_front()


func _get_inferno_guard_target(context: Dictionary) -> Vector2:
	# 원본 패리티 (pingfighter.py:185727-185730):
	# `flame_trail_base_vel = (PLAYER.center - BALL.center).normalize()`
	# 원본은 player center를 그대로 target으로 잡고, X clamp / Y 화면 바닥
	# 보정을 하지 않는다. 이전 구현은 두 보정 모두 적용해 target이 항상
	# player가 가드 가능한 위치로 funnel되어 "쫄깃한 맛"이 사라졌었음
	# (2026-05-18 user feedback 기준 원본 패리티로 복귀).
	var player_rect: Rect2 = _get_player_rect(context)
	return player_rect.get_center()


func _get_locked_inferno_guard_target(context: Dictionary) -> Vector2:
	if not inferno_guard_target_locked:
		inferno_guard_target = _get_inferno_guard_target(context)
		inferno_guard_target_locked = true
	return inferno_guard_target


func _clamp_inferno_ball_pos(pos: Vector2, context: Dictionary, _previous_pos: Vector2 = Vector2.INF) -> Vector2:
	# 원본 패리티 + 사용자 손맛 요청 (2026-05-18):
	# Funnel은 제거되어 있고 (auto-guard 모드 해제), ball 좌표는 trail phase
	# 동안 INFERNO_PILLAR_OVERSHOOT_X 만큼 letterbox로 자유롭게 침범한다.
	# 원본 동작에서 ball이 필러 letterbox를 가로지르는 손맛 — trail_fx_host의
	# head VFX는 ball 좌표 그대로 따라가 letterbox로 함께 들어간다.
	# Charge phase의 큰 정적 VFX는 별도 letterbox bleed clamp가 host 측에
	# 걸려 있어 보스 옆 letterbox 침범을 막는다.
	var ball_half: float = _get_ball_half_size(context)
	var field_width: float = _get_field_width(context)
	var x_min: float = -INFERNO_PILLAR_OVERSHOOT_X
	var x_max: float = maxf(x_min, field_width + INFERNO_PILLAR_OVERSHOOT_X)
	return Vector2(
		clampf(pos.x, x_min, x_max),
		clampf(pos.y, ball_half, _get_field_height(context) - ball_half)
	)


# Auto-steering / landing zone funnel / wobble scale helpers were removed
# (2026-05-18) — they made trail ball converge onto player center automatically,
# which sapped the "쫄깃한 맛" the original game had. Phase 2 now uses simple
# base_vel + sin/cos + flat noise (pingfighter.py:185763-185764 parity).


func _get_ball_half_size(context: Dictionary) -> float:
	return maxf(1.0, float(context.get("ball_size", 28.6)) * 0.5)


func _get_field_width(context: Dictionary) -> float:
	return maxf(1.0, float(context.get("width", FIELD_WIDTH)))


func _get_field_height(context: Dictionary) -> float:
	return maxf(1.0, float(context.get("height", FIELD_HEIGHT)))


func _apply_player_stun_and_knockback(
	source: String,
	knockback_power: float,
	context: Dictionary,
	deps: Dictionary,
	result: Dictionary,
	use_fireball_immunity: bool
) -> void:
	if use_fireball_immunity and player_fireball_stun_immunity_timer > 0.0:
		result["stage5_hongryun_player_stun_blocked_by_immunity"] = true
		return

	var status_state: Object = deps.get("status_effect_state", null)
	if status_state != null and status_state.has_method("apply_status"):
		status_state.apply_status(
			"player",
			"stun",
			PLAYER_STUN_FRAMES,
			{"cleansable": true, "visual": source},
			source
		)
	var movement_state: Object = deps.get("movement_state", null)
	var knockback_vel: float = _roll_player_knockback_velocity(knockback_power, context)
	if movement_state != null and movement_state.has_method("start_knockback"):
		movement_state.start_knockback(
			knockback_vel,
			PLAYER_KNOCKBACK_FRAMES,
			PLAYER_KNOCKBACK_DECAY,
			true,
			true
		)
	if use_fireball_immunity:
		player_fireball_stun_immunity_timer = PLAYER_FIREBALL_STUN_IMMUNITY_FRAMES
	result["stage5_hongryun_player_stunned"] = true
	result["stage5_hongryun_player_knockback_vel"] = knockback_vel


func _roll_player_knockback_velocity(power: float, _context: Dictionary) -> float:
	var direction := -1.0 if rng.randi_range(0, 1) == 0 else 1.0
	return direction * abs(power)


func _tick_player_fireball_immunity(fps_scale: float) -> void:
	if player_fireball_stun_immunity_timer <= 0.0:
		return
	player_fireball_stun_immunity_timer = max(0.0, player_fireball_stun_immunity_timer - fps_scale)


func _register_fireball_impact(pos: Vector2, reason: String, deps: Dictionary, scale: float = 0.85) -> void:
	var perf_logger: Object = deps.get("perf_logger", null)
	var sample_start: int = _perf_begin(perf_logger)
	fireball_impact_events.append(Stage5HongryunPayloadFactory.build_fireball_impact_event(
		pos,
		reason,
		scale
	))
	var stage_background: Object = deps.get("stage_background", null)
	if stage_background != null and stage_background.has_method("add_fire_impact"):
		stage_background.add_fire_impact(pos.x, pos.y)
	var impact_effects: Object = deps.get("impact_effects", null)
	if impact_effects != null and impact_effects.has_method("create_energy_explosion"):
		impact_effects.create_energy_explosion(pos, scale, 1.0)
	var feedback: Object = deps.get("feedback", null)
	if feedback != null and feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(0.05 * scale, 1.2 * scale)
	_perf_end(perf_logger, "physics.stage5.hongryun.impact_register", sample_start)


func _trigger_stage5_spiral_burst(deps: Dictionary) -> void:
	var perf_logger: Object = deps.get("perf_logger", null)
	var sample_start: int = _perf_begin(perf_logger)
	var stage_background: Object = deps.get("stage_background", null)
	if stage_background != null and stage_background.has_method("trigger_spiral_burst"):
		stage_background.trigger_spiral_burst(inferno_active)
	_perf_end(perf_logger, "physics.stage5.hongryun.spiral_burst", sample_start)


func _set_stage5_inferno_mode(active: bool, deps: Dictionary) -> void:
	var perf_logger: Object = deps.get("perf_logger", null)
	var sample_start: int = _perf_begin(perf_logger)
	var stage_background: Object = deps.get("stage_background", null)
	if stage_background != null and stage_background.has_method("set_inferno_mode"):
		stage_background.set_inferno_mode(active)
	_perf_end(perf_logger, "physics.stage5.hongryun.inferno_mode", sample_start)


func _is_fireball_inside_keepalive_bounds(pos: Vector2) -> bool:
	return (
		pos.x >= -FIREBALL_OFFSCREEN_MARGIN
		and pos.x <= FIELD_WIDTH + FIREBALL_OFFSCREEN_MARGIN
		and pos.y >= -FIREBALL_OFFSCREEN_MARGIN
		and pos.y <= FIELD_HEIGHT + FIREBALL_OFFSCREEN_MARGIN
	)


func _is_boss_skill_cooldown_paused(context: Dictionary) -> bool:
	return bool(context.get(
		"active_item_boss_skill_cooldown_paused",
		context.get("active_item_tear_gas_cooldown_pause_active", false)
	))


func _is_timing_frozen(context: Dictionary) -> bool:
	return (
		bool(context.get("stopwatch_freeze_active", false))
		or bool(context.get("active_item_stopwatch_freeze_active", false))
		or bool(context.get("perk_resume_freeze_active", false))
		or bool(context.get("power_smashing_freeze_active", false))
		or bool(context.get("viper_dmk_freeze_active", false))
		or bool(context.get("viper_nerve_strike_freeze_active", false))
	)


func _is_boss_skill_immune(context: Dictionary, deps: Dictionary) -> bool:
	if bool(context.get("boss_skill_immune", false)) or bool(context.get("active_item_boss_skill_immune", false)):
		return true
	if BossSkillParryGate.is_active(context, deps):
		return true
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime == null:
		return false
	for method_name in [
		"is_boss_skill_immune",
		"is_player_boss_skill_immune",
		"is_magic_anti_active",
	]:
		if active_item_runtime.has_method(method_name) and bool(active_item_runtime.call(method_name)):
			return true
	return false


func _trigger_boss_skill_parry(pos: Vector2, context: Dictionary, deps: Dictionary) -> void:
	if BossSkillParryGate.try_parry("hongryun_fireball", "화염탄", context, deps, pos):
		return
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime != null and active_item_runtime.has_method("trigger_magic_anti_potion_parry"):
		active_item_runtime.trigger_magic_anti_potion_parry("화염탄", pos, "hongryeon_fireball")


# ============================================================================
# 보스 피격 스타포인트 드랍 (stage1~4 공용 starpoint 모듈 패턴)
# ============================================================================

# 단일 굴림 → 드랍 개수 매핑. 스모크에서 경계값 봉인용으로 public static.
# [0, 0.007) → 2개 / [0.007, 0.025) → 1개 / [0.025, 1.0] → 0개.
static func resolve_boss_hit_starpoint_drop_count(roll: float) -> int:
	if roll < BOSS_HIT_STARPOINT_DOUBLE_CHANCE:
		return 2
	if roll < BOSS_HIT_STARPOINT_DOUBLE_CHANCE + BOSS_HIT_STARPOINT_SINGLE_CHANCE:
		return 1
	return 0


func _roll_boss_hit_starpoint_drops(deps: Dictionary, context: Dictionary) -> void:
	var drop_count: int = resolve_boss_hit_starpoint_drop_count(rng.randf())
	if drop_count <= 0:
		return
	var ball_pos: Vector2 = _get_vector2(context, "ball_pos", Vector2(FIELD_WIDTH * 0.5, 120.0))
	for _idx in range(drop_count):
		var drop_pos := Vector2(
			clamp(
				ball_pos.x + float(rng.randi_range(-BOSS_HIT_STARPOINT_SCATTER_PX, BOSS_HIT_STARPOINT_SCATTER_PX)),
				StagePlayfieldBounds.get_left(context) + STARPOINT_DROP_SIZE,
				StagePlayfieldBounds.get_right(context, FIELD_WIDTH) - STARPOINT_DROP_SIZE
			),
			clamp(
				ball_pos.y + float(rng.randi_range(-BOSS_HIT_STARPOINT_SCATTER_PX, BOSS_HIT_STARPOINT_SCATTER_PX)),
				STARPOINT_DROP_SIZE,
				StagePlayfieldBounds.get_height(context, FIELD_HEIGHT) - STARPOINT_DROP_SIZE
			)
		)
		_spawn_starpoint_drop_at(drop_pos, deps, context, true, false, "hongryun_boss_hit")


func _spawn_starpoint_drop_at(
	pos: Vector2,
	deps: Dictionary = {},
	context: Dictionary = {},
	allow_star_detector_bonus: bool = true,
	star_detector_bonus: bool = false,
	source_type: String = "hongryun_boss_hit"
) -> void:
	starpoint_drops.append(StarpointPayloadFactory.build_drop(
		pos,
		rng,
		star_detector_bonus,
		STARPOINT_DROP_SIZE,
		STARPOINT_DROP_LIFETIME,
		0.05,
		0.1,
		source_type
	))
	if starpoint_drops.size() > MAX_STAGE5_STARPOINT_DROPS:
		_trim_array_from_front(starpoint_drops, MAX_STAGE5_STARPOINT_DROPS)
	_spawn_starpoint_particles(pos, STARPOINT_PARTICLE_COUNT + (6 if star_detector_bonus else 0), 1.2 if star_detector_bonus else 1.0)
	if allow_star_detector_bonus:
		_spawn_star_detector_bonus_drops(pos, deps, context)


func _spawn_star_detector_bonus_drops(pos: Vector2, deps: Dictionary, context: Dictionary) -> void:
	var bonus_count: int = StarpointBonusDropPolicy.roll_star_detector_bonus_drop_count(deps, context)
	for _idx in range(bonus_count):
		var bonus_pos := Vector2(
			clamp(
				pos.x + float(STAR_DETECTOR_BONUS_DROP_OFFSET_CHOICES[rng.randi_range(0, STAR_DETECTOR_BONUS_DROP_OFFSET_CHOICES.size() - 1)]),
				StagePlayfieldBounds.get_left(context) + STARPOINT_DROP_SIZE,
				StagePlayfieldBounds.get_right(context, FIELD_WIDTH) - STARPOINT_DROP_SIZE
			),
			clamp(
				pos.y + float(STAR_DETECTOR_BONUS_DROP_OFFSET_CHOICES[rng.randi_range(0, STAR_DETECTOR_BONUS_DROP_OFFSET_CHOICES.size() - 1)]),
				STARPOINT_DROP_SIZE,
				StagePlayfieldBounds.get_height(context, FIELD_HEIGHT) - STARPOINT_DROP_SIZE
			)
		)
		_spawn_starpoint_drop_at(bonus_pos, deps, context, false, true, "hongryun_boss_hit")


func _update_starpoint_drops(fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	if starpoint_drops.is_empty():
		return
	var player_rect := Rect2(
		_get_vector2(context, "player_pos", Vector2.ZERO),
		_get_vector2(context, "player_paddle_size", Vector2(155.0, 50.0))
	)
	var player_rects: Array[Rect2] = StagePlayerInteractionRects.get_player_interaction_rects(player_rect, deps)
	var play_left: float = StagePlayfieldBounds.get_left(context)
	var play_right: float = StagePlayfieldBounds.get_right(context, FIELD_WIDTH)
	var play_height: float = StagePlayfieldBounds.get_height(context, FIELD_HEIGHT)
	var dowsing_context: Dictionary = StarpointDowsingAttraction.resolve_context(context, deps)
	var dowsing_player_center: Vector2 = StarpointDowsingAttraction.resolve_player_center(context)
	var write_index := 0
	var drop_count := starpoint_drops.size()
	for index in range(drop_count):
		var drop_value: Variant = starpoint_drops[index]
		var drop: Dictionary = drop_value if drop_value is Dictionary else {}
		StarpointDowsingAttraction.apply_to_drop(drop, dowsing_context, dowsing_player_center, fps_scale)
		if not StarpointDropMotionState.update_drop(
			drop,
			fps_scale,
			play_left,
			play_right,
			play_height,
			STARPOINT_DROP_SIZE,
			STARPOINT_DROP_MAX_FALL_SPEED,
			STARPOINT_DROP_ACCELERATION,
			STARPOINT_DROP_BOUNCE_DAMPING
		):
			continue

		var starlight_tracking_result := LingpetStarlightTrackingBridge.update_drop(drop, fps_scale, context, deps)
		if bool(starlight_tracking_result.get("delivered", false)):
			if _collect_starpoint_drop(drop, context, deps):
				StarpointCollectionCompaction.finish_in_place(starpoint_drops, index, write_index, drop_count)
				return
			if starpoint_drops.size() < drop_count:
				return
			continue
		if bool(starlight_tracking_result.get("claimed", false)):
			starpoint_drops[write_index] = drop
			write_index += 1
			continue

		if StarpointDropOverlapQuery.overlaps_any_circle_player(drop, player_rects, STARPOINT_DROP_SIZE):
			if _collect_starpoint_drop(drop, context, deps):
				StarpointCollectionCompaction.finish_in_place(starpoint_drops, index, write_index, drop_count)
				return
			if starpoint_drops.size() < drop_count:
				return
			continue
		starpoint_drops[write_index] = drop
		write_index += 1
	if write_index < drop_count:
		starpoint_drops.resize(write_index)


func _update_starpoint_particles(fps_scale: float) -> void:
	StarpointParticleState.update_particles(starpoint_particles, fps_scale)


func _collect_starpoint_drop(drop: Dictionary, context: Dictionary, deps: Dictionary) -> bool:
	var opened_choice: bool = StarpointCollectionRewardPolicy.collect_starpoint_reward(context, deps)
	var pos: Vector2 = _get_vector2(drop, "pos", Vector2.ZERO)
	_spawn_starpoint_particles(pos, STARPOINT_PARTICLE_COUNT + 10, 1.4)
	_play_starpoint_collect_sound(deps)
	StarpointCollectionRewardPolicy.request_owner_redraw(context)
	return opened_choice


func _spawn_starpoint_particles(pos: Vector2, count: int, intensity: float) -> void:
	starpoint_particles.append_array(StarpointPayloadFactory.build_particles(
		pos,
		count,
		intensity,
		rng,
		STARPOINT_PARTICLE_LIFE
	))
	if starpoint_particles.size() > MAX_STAGE5_STARPOINT_PARTICLES:
		_trim_array_from_front(starpoint_particles, MAX_STAGE5_STARPOINT_PARTICLES)


func _play_starpoint_collect_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_starpoint_collect"):
		audio.play_starpoint_collect()


func _trim_array_from_front(source: Array, max_size: int) -> void:
	if max_size <= 0:
		source.clear()
		return
	var overflow := source.size() - max_size
	if overflow <= 0:
		return
	var write_index := 0
	for read_index in range(overflow, source.size()):
		source[write_index] = source[read_index]
		write_index += 1
	source.resize(write_index)


func _build_public_update_result() -> Dictionary:
	return {
		"skip_ball_motion_step": should_skip_ball_motion_step(),
		"stage5_hongryun_fireball_count": fireball_projectiles.size(),
		"stage5_hongryun_boss_throwing": boss_throwing_windup_active,
		"stage5_hongryun_boss_throw_progress": _get_boss_throw_progress(),
		"stage5_hongryun_dragon_orb_count": dragon_orb_count,
		"stage5_hongryun_inferno_ready": inferno_ready,
		"stage5_hongryun_inferno_active": inferno_active,
		"stage5_hongryun_inferno_phase": inferno_phase,
		"stage5_hongryun_inferno_trail_elapsed_sec": inferno_trail_elapsed_sec,
	}


func _get_boss_throw_progress() -> float:
	if not boss_throwing_windup_active:
		return 0.0
	return clampf(1.0 - boss_throwing_windup_timer / maxf(1.0, BOSS_THROW_WINDUP_FRAMES), 0.0, 1.0)


func _get_boss_fireball_origin(context: Dictionary) -> Vector2:
	var boss_pos: Vector2 = _get_vector2(context, "boss_pos", Vector2(FIELD_WIDTH * 0.5 - 50.0, 55.0))
	var boss_size: Vector2 = _get_vector2(
		context,
		"boss_paddle_size",
		Vector2(float(context.get("boss_paddle_width", 100.0)), float(context.get("boss_hitbox_height", 40.0)))
	)
	return boss_pos + Vector2(boss_size.x * 0.5, boss_size.y)


func _get_player_rect(context: Dictionary) -> Rect2:
	var player_pos: Vector2 = _get_vector2(context, "player_pos", Vector2(FIELD_WIDTH * 0.5 - 77.5, 690.0))
	var player_size: Vector2 = _get_vector2(
		context,
		"player_paddle_size",
		Vector2(float(context.get("player_paddle_width", context.get("paddle_width", 155.0))), float(context.get("player_paddle_height", context.get("paddle_height", 50.0))))
	)
	return Rect2(player_pos, player_size)


func _get_ball_rect(ball_pos: Vector2, context: Dictionary) -> Rect2:
	var ball_size: float = max(1.0, float(context.get("ball_size", 28.6)))
	return Rect2(ball_pos - Vector2(ball_size, ball_size) * 0.5, Vector2(ball_size, ball_size))


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _get_dict_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _get_fireball_hud_skill() -> Dictionary:
	var remaining: float = max(0.0, fireball_cooldown)
	var total: float = max(0.1, fireball_cooldown_total)
	var skill_status := "ready" if remaining <= 0.0 else "charging"
	if boss_throwing_windup_active:
		skill_status = "casting"
	return {
		"id": "hongryun_fireball",
		"label": "홍련 화염탄",
		"status": skill_status,
		"cooldown_remaining": remaining,
		"cooldown_total": total,
		"cooldown_contract": "time",
		"initial_ready_allowed": false,
		"progress": clamp(1.0 - remaining / total, 0.0, 1.0),
		"ready": skill_status == "ready",
		"trigger_type": "auto",
		"color": Color(0.95, 0.42, 0.30, 1.0),
	}


func _get_inferno_hud_skill() -> Dictionary:
	var skill_status: String
	var progress: float
	if inferno_active:
		skill_status = "inferno_charge" if inferno_phase == 1 else "casting"
		progress = 1.0
	elif inferno_ready:
		skill_status = "ready"
		progress = 1.0
	else:
		skill_status = "charging"
		progress = clamp(float(dragon_orb_count) / float(DRAGON_ORB_MAX), 0.0, 1.0)
	return {
		"id": "hongryun_inferno",
		"label": "홍련폭염",
		"status": skill_status,
		"render_kind": "dragon_orb_gauge",
		"gauge": dragon_orb_count,
		"gauge_max": DRAGON_ORB_MAX,
		"inferno_charge_progress": clamp(inferno_charge_timer / INFERNO_CHARGE_SEC, 0.0, 1.0) if inferno_phase == 1 else 0.0,
		"progress": progress,
		"cooldown_remaining": maxf(0.0, float(DRAGON_ORB_MAX) - dragon_orb_count),
		"cooldown_total": float(DRAGON_ORB_MAX),
		"cooldown_contract": "resource_gauge",
		"initial_ready_allowed": false,
		"ready": skill_status == "ready",
		"trigger_type": "boss_paddle_contact",
		"color": Color(1.0, 0.20, 0.20, 1.0),
	}


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


# ============================================================================
# Public accessors
# ============================================================================

func get_status() -> String:
	return status


func is_inferno_active() -> bool:
	return inferno_active


func is_inferno_ready() -> bool:
	return inferno_ready


func get_dragon_orb_count() -> int:
	return int(floor(dragon_orb_count))


func get_dragon_orb_max() -> int:
	return DRAGON_ORB_MAX


func get_ball_hijack_reason() -> String:
	return ball_hijack_reason


func drain_hongryun_orb_gauge(amount: float) -> void:
	_drain_dragon_orb_gauge(amount)


func drain_hongryun_hit_count(amount: float) -> void:
	_drain_dragon_orb_gauge(amount)


func _drain_dragon_orb_gauge(amount: float) -> void:
	if amount <= 0.0:
		return
	dragon_orb_count = max(0.0, dragon_orb_count - amount)
	if dragon_orb_count < float(DRAGON_ORB_MAX):
		inferno_ready = false


# ============================================================================
# Debug hooks (개발 메뉴 / 테스트)
# ============================================================================

func debug_set_dragon_orb_count(count: int) -> void:
	dragon_orb_count = float(clamp(count, 0, DRAGON_ORB_MAX))
	inferno_ready = dragon_orb_count >= DRAGON_ORB_MAX


func debug_force_inferno_ready() -> void:
	dragon_orb_count = float(DRAGON_ORB_MAX)
	inferno_ready = true
