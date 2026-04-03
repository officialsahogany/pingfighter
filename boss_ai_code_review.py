"""
=============================================================================
PingFighter (핑파이터) - Boss AI System: Code Review Document
=============================================================================

이 파일은 실제 게임에서 사용 중인 보스 AI 코드를 코드리뷰용으로 정리한 것입니다.
실행용이 아닌 리뷰/참고용 문서입니다.

게임 개요: Pygame 기반 아케이드 탁구 게임. 보스와 1v1로 대결하며,
8개 스테이지 + 투기장(Arena) 모드가 있음.
화면: 760x750, 보스 패들은 상단(Y=25), 플레이어 패들은 하단(Y=710).

AI 구조 요약:
- 리그(난이도)별로 별도 함수: junior / pro(기본) / champion / mythic
- 각 함수가 매 프레임 호출되어 보스 패들의 X 위치를 결정
- 공의 궤적을 예측하고, 난이도별 실수율/오차/반응속도를 적용
- Ultra Smooth (PID 제어) 또는 일반 Smooth 물리 엔진으로 최종 이동
=============================================================================
"""

# =============================================================================
# PART 1: 스테이지별 보스 설정 (config/stage_configs.py)
# =============================================================================
# 각 스테이지 보스의 물리 파라미터와 대쉬 설정

BOSS_CONFIGS = {
    1: {
        "name": "풍악보이",
        "accel": 0.798,           # 가속도 (35% 감소 적용됨)
        "decel": 0.798,           # 감속도
        "max_speed": 6.3175,      # 최대 이동 속도
        "instant_stop": 0.665,    # 즉시 정지 감속도
        "predict_distance": 160,  # 예측 거리
        "fail_error": 315,        # 실수 시 오차 범위(px)
        "special_skill": "whip",  # 상모돌리기
        "dash_cooldown_range": (40.0, 55.0),  # 대쉬 쿨타임(초)
        "dash_trigger_chance": 0.30,           # 대쉬 발동 확률
        "dash_stun_duration": 0.60,            # 대쉬 후 후딜(초)
        "dash_max_distance": 288,              # 대쉬 최대 거리(px)
    },
    2: {
        "name": "악어장군",
        "accel": 0.840,
        "decel": 0.840,
        "max_speed": 6.3,
        "instant_stop": 0.714,
        "fail_error": 285,
        "dash_cooldown_range": (38.0, 53.0),
        "dash_trigger_chance": 0.33,
        "dash_max_distance": 300,
    },
    3: {
        "name": "멘헤라걸",
        "accel": 0.866,
        "decel": 0.866,
        "max_speed": 6.521,
        "instant_stop": 0.768,
        "fail_error": 260,
        "dash_cooldown_range": (36.0, 51.0),
        "dash_trigger_chance": 0.36,
        "dash_max_distance": 312,
    },
    # ... 스테이지 4~8까지 점진적으로 강화 (max_speed: 6.3 → 9.4)
    8: {
        "name": "아카무 리고",
        "accel": 1.11,
        "decel": 1.11,
        "max_speed": 9.4,         # 가장 빠른 보스
        "instant_stop": 1.131,
        "fail_error": 180,        # 가장 적은 실수
        "dash_cooldown_range": (26.0, 38.0),
        "dash_max_distance": 372,
    },
}


# =============================================================================
# PART 2: 리그별 보스 능력치 보정 시스템
# =============================================================================
# 스테이지 설정 × 리그 배율 = 최종 보스 스펙

def get_league_boss_multiplier(league_mode):
    """리그별 보스 능력치 배수 반환"""
    league_multipliers = {
        "junior": 0.85,    # 주니어리그: -15%
        "champion": 1.50,  # 챔피언리그: +50%
        "mythic": 1.50     # 신화리그: +50%
    }
    return league_multipliers.get(league_mode, 1.00)

def get_league_boss_paddle_scale(league_mode):
    """리그별 보스 패들 크기 배율"""
    paddle_scales = {
        "junior": 1.00,    # 기본 크기
        "champion": 1.15,  # +15% 크기 증가
        "mythic": 1.15
    }
    return paddle_scales.get(league_mode, 1.00)

def get_junior_ball_speed_multiplier():
    """주니어리그: 공 속도 -35% 감소"""
    return 0.65 if ai_mode == "junior" else 1.0

def apply_league_boss_config(base_config, league_mode):
    """리그별 보스 설정에 능력치 보정 적용"""
    multiplier = get_league_boss_multiplier(league_mode)
    if multiplier == 1.00:
        return base_config
    modified_config = base_config.copy()
    # accel, decel, max_speed, instant_stop에 배율 적용
    return modified_config

def get_final_boss_config(stage, league_mode):
    """통합 보스 설정: 스테이지별 + 리그별 완전 연계"""
    base_config = boss_speed_config.get(stage, boss_speed_config[1])
    if stage == 50:  # 튜토리얼은 보정 없음
        return base_config
    return apply_league_boss_config(base_config, league_mode)


# =============================================================================
# PART 3: AI 추가 설정 (스테이지별 예측/실수 파라미터)
# =============================================================================
# BOSS_CONFIGS 기반으로 AI 행동 파라미터를 자동 생성

boss_speed_config = {}
for stage_num in range(1, 9):
    boss_speed_config[stage_num] = {
        "accel": BOSS_CONFIGS[stage_num]["accel"],
        "decel": BOSS_CONFIGS[stage_num]["decel"],
        "max_speed": BOSS_CONFIGS[stage_num]["max_speed"],
        "instant_stop": BOSS_CONFIGS[stage_num]["instant_stop"],
        # AI 추가 설정 (스테이지가 올라갈수록 정확해짐)
        "predict_chance": 0.45 + (stage_num - 1) * 0.05,  # 45% → 80%
        "predict_error": 95 - (stage_num - 1) * 5,         # ±95px → ±60px
        "fail_chance": 0.010 - (stage_num - 1) * 0.001,    # 1.0% → 0.3%
        "fail_error": BOSS_CONFIGS[stage_num]["fail_error"],
    }


# =============================================================================
# PART 4: 공 궤적 예측 함수
# =============================================================================

def _predict_x_with_walls(x: float, vx: float, frames: float) -> float:
    """벽 반사를 고려한 공의 예상 X 위치 계산.

    공이 좌우 벽(0, WIDTH=760)에 부딪히면 반사되므로,
    단순 선형 예측 대신 최대 4번의 벽 반사를 시뮬레이션.
    """
    WIDTH = 760
    if abs(vx) < 1e-3 or frames <= 0:
        return x

    remaining = frames
    x_min, x_max = 0.0, float(WIDTH)

    for _ in range(4):  # 최대 4번 반사
        if remaining <= 0:
            break
        if vx > 0:
            t_wall = (x_max - x) / vx if vx != 0 else float("inf")
        else:
            t_wall = (x_min - x) / vx if vx != 0 else float("inf")

        if t_wall <= 0 or t_wall >= remaining:
            x += vx * remaining
            remaining = 0
            break

        x += vx * t_wall
        remaining -= t_wall
        vx = -vx  # 벽 반사

    return max(x_min, min(x_max, x))


def predict_ball_position(frames=20):
    """단순 선형 예측 (벽 반사 미고려) - 폴백용"""
    predict_x = BALL.centerx + ball_vel[0] * frames
    predict_x = max(0, min(WIDTH, predict_x))
    return predict_x


# =============================================================================
# PART 5: 보스 긴급 대쉬 시스템
# =============================================================================
# 일반 이동으로 공을 막을 수 없을 때 발동하는 긴급 대쉬

def _boss_try_emergency_dash() -> bool:
    """보스 긴급 대쉬 시도.

    조건: 공이 보스 바로 아래 100px 이내 + 위로 향하는 중 +
          일반 이동으로 커버 불가능한 거리일 때만 발동.
    """
    now_ms = pygame.time.get_ticks()

    # 발동 불가 조건들
    if current_stage == 6:          return False  # 네메시스는 대쉬 금지
    if boss_stunned_timer > 0:      return False  # 스턴 상태
    if ball_vel[1] >= 0:            return False  # 공이 아래로 가는 중
    if boss_special_gauge < 50:     return False  # 게이지 부족

    # 쿨타임 체크
    if boss_dash_cooldown_until_ms and now_ms < boss_dash_cooldown_until_ms:
        return False

    # 공과 보스 사이의 거리/시간 계산
    dy = BALL.centery - BOSS.bottom
    if dy <= 0 or dy > 100:         return False  # 100px 이내일 때만

    time_to_boss = dy / max(1.0, abs(ball_vel[1]))
    if time_to_boss > 18.0:         return False  # 0.3초 이상 남으면 대쉬 안 씀

    # 일반 이동으로 커버 가능한 거리 계산
    cfg = get_final_boss_config(current_stage, ai_mode)
    effective_speed = cfg.get("max_speed", 6.3) * 1.5  # 가속 여유 포함
    max_travel = effective_speed * time_to_boss

    # 벽 반사 고려한 공 예상 위치
    predicted_x = _predict_x_with_walls(
        float(BALL.centerx), float(ball_vel[0]), float(time_to_boss)
    )
    predicted_x = max(BOSS.width // 2, min(WIDTH - BOSS.width // 2, predicted_x))

    required = abs(predicted_x - BOSS.centerx)

    # 일반 이동으로 커버 가능하면 대쉬 불필요
    if required <= max_travel:       return False
    if required < BOSS.width * 0.8:  return False  # 작은 보정으로 충분하면 패스

    # 스테이지별 대쉬 발동 확률 체크
    stage_cfg = BOSS_CONFIGS.get(current_stage, {})
    trigger_chance = float(stage_cfg.get("dash_trigger_chance", 0.30))
    if random.random() >= trigger_chance:
        return False

    # === 대쉬 실행 ===
    direction = 1 if predicted_x > BOSS.centerx else -1
    max_dash_distance = float(stage_cfg.get("dash_max_distance", 240))

    dash_distance = max_dash_distance  # 항상 최대 거리로 대쉬
    target_centerx = BOSS.centerx + direction * dash_distance
    target_centerx = int(max(BOSS.width // 2, min(WIDTH - BOSS.width // 2, target_centerx)))

    # 대쉬 속도/지속시간 설정 (플레이어와 동일한 40px/frame)
    boss_dash_speed = 40.0
    estimated_duration = dash_distance / 30.0
    boss_dash_duration_frames = int(max(10, min(estimated_duration, 40)))
    boss_dash_timer = boss_dash_duration_frames
    boss_dashing = True

    # 게이지 소모 + 쿨타임 설정
    boss_special_gauge -= 50

    cooldown_range = stage_cfg.get("dash_cooldown_range", (40.0, 55.0))
    min_s, max_s = cooldown_range

    # 리그별 쿨타임 감소
    league_cooldown_mult = {"junior": 1.0, "champion": 0.4, "mythic": 0.4}
    mult = league_cooldown_mult.get(ai_mode, 1.0)
    min_s *= mult
    max_s *= mult

    boss_dash_cooldown_until_ms = now_ms + random.randint(int(min_s * 1000), int(max_s * 1000))

    return True


# =============================================================================
# PART 6: 메인 디스패처 - handle_boss()
# =============================================================================
# 매 프레임 호출. 상태 효과 처리 후 리그별 AI 함수 호출.

def handle_boss():
    """보스 AI 메인 함수 (매 프레임 호출)"""
    now_ms = pygame.time.get_ticks()

    # --- 우선순위 1: 상태 효과 처리 (모든 리그 공통) ---

    # 공 생성 애니메이션 중 정지
    if ball_spawn_animation_active:
        return

    # 바이퍼 스킬 프리즈 (넉백 물리는 프리즈 중에도 적용)
    if _viper_ns_freeze_active or _viper_dmk_freeze_active:
        if abs(boss_fire_knockback_vel) > 0.3:
            _apply_knockback_physics()
        return

    # 넉백 처리 (화재/EMP/팬텀킥 등)
    if abs(boss_fire_knockback_vel) > 0.3:
        _apply_knockback_with_wall_bounce()

    # 투기장 스킬 상태 효과 (스턴, 둔화, 혼란, 패들 축소 등)
    if arena_mode_enabled and arena_skill_manager:
        _apply_arena_skill_effects()

    # 투기장 대쉬 처리 (상단/하단 영웅)
    if arena_mode_enabled:
        _handle_arena_dashes()

    # 스테이지 8 전용: 초각성/극정호신/스턴탈출
    if current_stage == 8:
        _handle_stage8_special_mechanics()

    # 넉백 모션 (라그나로크 해머, 코만도 총알 등)
    if boss_knockback_timer > 0:
        _process_knockback_motion()
        return

    # 보스 대쉬 모션 처리 (플레이어 대쉬와 유사한 속도 곡선)
    if boss_dashing and boss_dash_timer > 0:
        _process_boss_dash()
        return

    # --- 우선순위 2: 리그별 AI 호출 ---
    if ai_mode == "junior":
        handle_boss_junior()
    elif ai_mode == "champion":
        handle_boss_champion()
    elif ai_mode == "mythic":
        handle_boss_mythic()
    else:
        handle_boss_pro()  # 기본 AI

    # --- 우선순위 3: 대쉬 판단 (AI 이동 후) ---
    _boss_try_emergency_dash()

    # --- 우선순위 4: 외부 효과 적용 ---
    _apply_boss_banana_slip()   # 바나나 미끄러짐
    _track_boss_movement()      # 이동 방향 추적

    # 보스 스킬 처리 (스테이지별 게이지 시스템)
    _process_boss_skills()


# =============================================================================
# PART 7: 리그별 AI 구현 - 주니어리그 (가장 쉬움)
# =============================================================================

def handle_boss_junior():
    """주니어리그: 초보자용 AI (30% 실수율, 큰 오차)"""

    # --- 공통 상태 체크 (모든 리그 동일) ---
    if stopwatch_active and stopwatch_timer > 0:        return  # 시간 정지
    if current_stage == 2 and water_cannon_phase in ("charging", "firing"):
        boss_current_speed = 0; return                           # 물대포 시전 중
    if boss_stun_timer > 0:     boss_stun_timer -= 1; return    # 스턴
    if boss_stunned_timer > 0:  _process_stun_knockback(); return
    if head_shot_active:        _process_headshot_stun(); return
    if is_waiting_for_serve:    _process_serve_waiting(); return

    # --- 주니어리그 전용 설정 ---
    config = get_final_boss_config(current_stage, "junior")
    enhanced_max_speed = config["max_speed"]
    enhanced_acceleration = config["accel"]

    # 속도 감소 효과 적용 (레그샷, 스파이더지뢰, 빙판 등)
    _apply_slow_effects()

    # --- 예측 로직 (매우 부정확) ---
    junior_settings = {
        "predict_chance": 0.30,   # 30% 확률로만 예측
        "predict_error": 150,     # ±150px 오차
        "fail_chance": 0.30,      # 30% 실수율
    }

    predict_frame = 10

    if random.random() < junior_settings["predict_chance"]:
        future_x = BALL.centerx + ball_vel[0] * predict_frame
    else:
        future_x = BALL.centerx  # 현재 위치로만 이동

    # 큰 오차 추가
    future_x += random.randint(-150, 150)

    # 빈번한 실수 (공 속도에 비례)
    if random.random() < junior_settings["fail_chance"]:
        boss_fail_timer = 40  # 1.3초간 실패 상태
        current_speed = math.sqrt(ball_vel[0]**2 + ball_vel[1]**2)
        mistake_scale = min(200, max(100, current_speed * 8))
        future_x += random.randint(-int(mistake_scale), int(mistake_scale))

    # --- 이동 로직 ---
    target_distance = future_x - BOSS.centerx
    if abs(target_distance) < 25:          # 큰 허용 범위
        boss_current_speed *= 0.85
    elif target_distance < 0:
        boss_current_speed = max(-enhanced_max_speed, boss_current_speed - enhanced_acceleration)
    else:
        boss_current_speed = min(enhanced_max_speed, boss_current_speed + enhanced_acceleration)

    # --- 물리 엔진으로 최종 위치 결정 ---
    _apply_movement_physics(future_x, enhanced_max_speed, enhanced_acceleration)


# =============================================================================
# PART 8: 리그별 AI 구현 - 프로리그 (기본)
# =============================================================================

def handle_boss_pro():
    """프로리그: 표준 AI (25% 실수율)"""

    # (공통 상태 체크 생략 - 주니어와 동일)

    config = get_final_boss_config(current_stage, "junior")  # 프로리그는 junior 설정 기반
    config["fail_chance"] = 0.25

    predict_frame = max(10, min(30, int(FPS / max(1, abs(ball_vel[0])))))

    # --- 투기장 모드: 공이 보스 패들까지 도달하는 시간 기반 예측 ---
    if arena_mode_enabled:
        _bvy = ball_vel[1]
        if abs(_bvy) > 1e-3:
            _dist_y = BOSS.bottom - BALL.centery
            _predict_t = max(0.0, _dist_y / _bvy) if _bvy != 0 else 0
            future_x = BALL.centerx + ball_vel[0] * _predict_t
        else:
            future_x = BALL.centerx

    # --- 혼란 상태: 공을 무시하고 랜덤 이동 ---
    elif boss_confused_timer > 0:
        future_x = random.randint(BOSS.width // 2, WIDTH - BOSS.width // 2)

    # --- 실패 상태: 단순 움직임 ---
    elif boss_fail_timer > 0:
        future_x = BALL.centerx + random.randint(-50, 50)
        boss_fail_timer -= 1

    # --- 정상 상태: 기본 예측 ---
    else:
        if random.random() < config["predict_chance"]:
            future_x = BALL.centerx + ball_vel[0] * predict_frame
        else:
            future_x = BALL.centerx

        future_x += random.randint(-config["predict_error"], config["predict_error"])

        # 파워스매싱 포물선 중: 보스 집중 → 오차/실패율 감소
        if power_smashing_parabola_active and power_smashing_combo_consumed >= 3:
            config["predict_error"] = max(5, config["predict_error"] // 2)
            config["fail_chance"] *= 0.5

        if random.random() < config["fail_chance"]:
            boss_fail_timer = 30  # 0.5초간 실패 상태

    # --- 이동: 데드존 10px, 가속/감속 ---
    enhanced_max_speed = config["max_speed"]
    enhanced_acceleration = config["accel"]
    enhanced_deceleration = config["decel"]

    if future_x < BOSS.centerx - 10:
        boss_current_speed -= enhanced_acceleration
    elif future_x > BOSS.centerx + 10:
        boss_current_speed += enhanced_acceleration
    else:
        # 감속
        if boss_current_speed > 0:
            boss_current_speed = max(0, boss_current_speed - enhanced_deceleration)
        elif boss_current_speed < 0:
            boss_current_speed = min(0, boss_current_speed + enhanced_deceleration)

    # --- Ultra Smooth 물리 엔진 (PID 제어) ---
    _apply_ultra_smooth_or_fallback(future_x, enhanced_max_speed)


# =============================================================================
# PART 9: 리그별 AI 구현 - 챔피언리그 (고급)
# =============================================================================

def handle_boss_champion():
    """챔피언리그: 고급 AI (8% 실수율)"""

    # (공통 상태 체크 생략)

    config = get_final_boss_config(current_stage, "champion")
    current_speed = math.sqrt(ball_vel[0]**2 + ball_vel[1]**2)
    ball_speed = abs(ball_vel[0]) + abs(ball_vel[1])

    # --- 공 속도에 따른 동적 예측 프레임 ---
    if ball_speed > 15:
        predict_frame = 8   # 빠른 공: 짧은 예측
    elif ball_speed > 10:
        predict_frame = 12  # 중간 공
    else:
        predict_frame = 20  # 느린 공

    # --- 예측 ---
    if boss_confused_timer > 0:
        future_x = random.randint(BOSS.width // 2, WIDTH - BOSS.width // 2)
    else:
        future_x = BALL.centerx + ball_vel[0] * predict_frame

        # 벽 바운스 간단 계산
        game_left = 80   # GAME_AREA_OFFSET_X
        game_right = 680  # GAME_AREA_OFFSET_X + GAME_PLAY_WIDTH
        if future_x < game_left:
            future_x = game_left * 2 - future_x  # 반사
        elif future_x > game_right:
            future_x = game_right * 2 - future_x

        # 8% 실수율 (공 속도에 비례한 실수 크기)
        champion_mistake_chance = 0.08
        if random.random() < champion_mistake_chance:
            mistake_magnitude = min(100, max(50, current_speed * 5))
            future_x += random.randint(-int(mistake_magnitude), int(mistake_magnitude))

        # 스테이지별 정확도 추가 오차
        accuracy = 0.95 if current_stage >= 4 else 0.80 if current_stage >= 3 else 0.70
        if random.random() > accuracy:
            future_x += random.randint(-60, 60)

    # --- 이동: 가속 계수 1.2x로 약간 더 민첩 ---
    target_distance = future_x - BOSS.centerx
    enhanced_max_speed = config["max_speed"]
    enhanced_acceleration = config["accel"]

    if abs(target_distance) < 15:
        boss_current_speed *= 0.8
    elif target_distance < 0:
        boss_current_speed = max(-enhanced_max_speed, boss_current_speed - enhanced_acceleration * 1.2)
    else:
        boss_current_speed = min(enhanced_max_speed, boss_current_speed + enhanced_acceleration * 1.2)

    _apply_ultra_smooth_or_fallback(future_x, enhanced_max_speed)


# =============================================================================
# PART 10: 리그별 AI 구현 - 신화리그 (최강)
# =============================================================================

def handle_boss_mythic():
    """신화리그: 최강 AI (0.5% 실수율) - 거의 완벽한 플레이

    핵심 차별점:
    1. 다중 시나리오 시뮬레이션 (3가지 예측의 가중 평균)
    2. 물리 엔진 시뮬레이션 (벽 반사 + 적응형 감속 + 관성 보존)
    3. 플레이어 패턴 학습 (최근 타격 위치 분석 → 반대편 대비)
    4. 임팩트 부스트 예측 (퍼펙트 타이밍 확률 분석)
    5. 예측적 포지셔닝 (공이 플레이어 쪽일 때 최적 복귀 위치로 이동)
    """

    # (공통 상태 체크 생략)

    config = get_final_boss_config(current_stage, "mythic")
    current_speed = math.sqrt(ball_vel[0]**2 + ball_vel[1]**2)

    # === 1단계: 다중 시나리오 시뮬레이션 ===
    # 짧은/중간/긴 3가지 예측을 물리 엔진으로 시뮬레이션
    predictions = []
    for scenario in range(3):
        effective_speed = math.hypot(ball_vel[0], ball_vel[1])

        # 시나리오별 예측 프레임
        if scenario == 0:
            predict_frames = max(8, min(15, int(40 / max(1, effective_speed))))
        elif scenario == 1:
            predict_frames = max(12, min(25, int(60 / max(1, effective_speed))))
        else:
            predict_frames = max(20, min(35, int(80 / max(1, effective_speed))))

        # 물리 시뮬레이션
        sim_x = BALL.centerx
        sim_vel_x = ball_vel[0]
        sim_vel_y = ball_vel[1]
        sim_speed = current_speed

        for frame in range(predict_frames):
            sim_x += sim_vel_x

            # 벽 반사 시뮬레이션
            if sim_x < 0 or sim_x > WIDTH:
                sim_x = -sim_x if sim_x < 0 else WIDTH * 2 - sim_x
                sim_vel_x = -sim_vel_x
                # 관성 보존 보너스 (저속일 때만)
                if sim_speed < 12:
                    wall_bonus = min(1.4, 1.0 + (12 - sim_speed) * 0.03)
                    sim_speed *= wall_bonus

            # 적응형 감속 시스템
            if sim_speed < 10:
                adaptive_decay = 1.0 - (1.0 - 0.977) * 0.4  # 저속: 감속 완화
            elif sim_speed < 15:
                adaptive_decay = 0.977                          # 중속: 기본 감속
            else:
                speed_ratio = min((sim_speed - 15) / 20, 1.0)
                adaptive_decay = 0.977 * (1.0 + speed_ratio * 0.5)  # 고속: 강화 감속
            sim_speed *= adaptive_decay

            # 속도 벡터 정규화
            current_sim_speed = math.sqrt(sim_vel_x**2 + sim_vel_y**2)
            if current_sim_speed > 0.1:
                scale = sim_speed / current_sim_speed
                sim_vel_x *= scale
                sim_vel_y *= scale

        predictions.append(sim_x)

    # === 2단계: 가중 평균 ===
    predicted_x = (predictions[0] * 0.5 +   # 짧은 예측: 50% 가중치
                   predictions[1] * 0.3 +    # 중간 예측: 30%
                   predictions[2] * 0.2)     # 긴 예측: 20%

    # === 3단계: 플레이어 임팩트 부스트 예측 ===
    player_to_ball_distance = abs(PLAYER.centerx - BALL.centerx)
    perfect_timing_probability = 0.0

    if ball_vel[1] > 0 and abs(BALL.centery - PLAYER.top) < 150:
        if player_to_ball_distance < 30:
            perfect_timing_probability = 0.9
        elif player_to_ball_distance < 60:
            perfect_timing_probability = 0.6
        elif player_to_ball_distance < 100:
            perfect_timing_probability = 0.3

    if perfect_timing_probability > 0.5:
        if current_speed < 10:
            anticipated_boost = 1.8 + perfect_timing_probability * 0.4
        elif current_speed < 15:
            anticipated_boost = 1.3 + perfect_timing_probability * 0.3
        else:
            anticipated_boost = 1.1 + perfect_timing_probability * 0.2
        predicted_x *= anticipated_boost

    # === 4단계: 플레이어 패턴 학습 ===
    # 최근 10번의 타격 위치/오프셋을 기록하고, 편향 분석
    if len(player_hit_history) >= 3:
        recent_hits = player_hit_history[-3:]
        avg_offset = sum(h['hit_offset'] for h in recent_hits) / len(recent_hits)
        if abs(avg_offset) > 20:
            predicted_x += -avg_offset * 1.5  # 반대 방향으로 예측

    # === 5단계: 극미세 실수 (0.5% 확률) ===
    if random.random() < 0.005:
        predicted_x += random.randint(-20, 20)

    # === 6단계: 거리별 세밀한 속도 제어 ===
    enhanced_max_speed = config["max_speed"]
    enhanced_acceleration = config["accel"]
    target_distance = predicted_x - BOSS.centerx

    if abs(target_distance) < 3:          # 정확한 위치: 즉시 정지
        boss_current_speed *= 0.95
    elif abs(target_distance) < 10:       # 매우 가까움: 초정밀 제어
        boss_current_speed = math.copysign(min(3, enhanced_max_speed * 0.3), target_distance)
    elif abs(target_distance) < 25:       # 가까움: 빠른 접근 (2.0x 가속)
        boss_current_speed += math.copysign(enhanced_acceleration * 2.0, target_distance)
        boss_current_speed = max(-enhanced_max_speed * 0.7, min(enhanced_max_speed * 0.7, boss_current_speed))
    elif abs(target_distance) < 50:       # 중간 거리 (2.5x 가속)
        boss_current_speed += math.copysign(enhanced_acceleration * 2.5, target_distance)
        boss_current_speed = max(-enhanced_max_speed * 0.9, min(enhanced_max_speed * 0.9, boss_current_speed))
    else:                                  # 먼 거리: 최대 가속 (3.0x, 110% 속도)
        boss_current_speed += math.copysign(enhanced_acceleration * 3.0, target_distance)
        boss_current_speed = max(-enhanced_max_speed * 1.1, min(enhanced_max_speed * 1.1, boss_current_speed))

    # === 7단계: 예측적 포지셔닝 ===
    # 공이 플레이어 쪽에 있을 때 다음 반격을 위한 최적 위치로 미리 이동
    if ball_vel[1] > 0 and BALL.centery > HEIGHT // 2:
        game_center_x = 380  # WIDTH // 2
        optimal_return_position = game_center_x

        # 플레이어 평균 위치의 반대편으로 이동
        if len(player_move_history) >= 5:
            recent_avg = sum(player_move_history[-5:]) / 5
            if recent_avg < game_center_x:
                optimal_return_position = game_center_x + 40
            else:
                optimal_return_position = game_center_x - 40

        # 현재 예측과 복귀 위치 사이 블렌딩
        blend_factor = min(0.25, (BALL.centery - HEIGHT // 2) / (HEIGHT // 2))
        target_position = predicted_x * (1 - blend_factor) + optimal_return_position * blend_factor

        if abs(target_position - BOSS.centerx) > 15:
            boss_current_speed = math.copysign(enhanced_max_speed * 0.6, target_position - BOSS.centerx)

    # === 8단계: 위치 업데이트 + 벽 반사 ===
    proposed_x = BOSS.x + boss_current_speed

    # 벽 근처 특수 움직임: 빠른 반사 (80% 속도 유지)
    if proposed_x <= 5:
        boss_current_speed = abs(boss_current_speed) * 0.8
        BOSS.x = 5
    elif proposed_x >= WIDTH - BOSS.width - 5:
        boss_current_speed = -abs(boss_current_speed) * 0.8
        BOSS.x = WIDTH - BOSS.width - 5
    else:
        BOSS.x = proposed_x


# =============================================================================
# PART 11: Ultra Smooth 물리 엔진 (PID 제어 기반 보스 이동)
# =============================================================================
# 프로리그와 주니어리그에서 사용. 신화리그는 직접 제어.

def _apply_ultra_smooth_or_fallback(target_x, max_speed):
    """Ultra Smooth (PID) → Smooth → 기본 물리 순으로 폴백"""

    if ULTRA_SMOOTH_AVAILABLE:
        ultra_smoother = get_ultra_smooth_movement()

        # PID 파라미터 설정
        ultra_smoother.physics.max_velocity = max_speed
        ultra_smoother.physics.max_force = max_speed * 2.5
        ultra_smoother.physics.friction = 0.92

        ultra_smoother.pid.kp = 0.35   # 비례 (Proportional)
        ultra_smoother.pid.ki = 0.015  # 적분 (Integral)
        ultra_smoother.pid.kd = 0.18   # 미분 (Derivative)

        ultra_smoother.prediction_enabled = True
        ultra_smoother.adaptive_enabled = True

        # PID 기반 위치 계산
        new_position, new_velocity = ultra_smoother.update(
            BOSS.x, target_x, ball_vel[0]
        )

        # 균열(Crack) 충돌 체크
        proposed_rect = pygame.Rect(new_position, BOSS.y, BOSS.width, BOSS.height)
        collision_crack = _boss_get_crack_collision(proposed_rect)

        if collision_crack:
            boss_current_speed = 0
            BOSS.x = _slide_boss_toward_crack_edge(BOSS.x, new_position, collision_crack, BOSS.width)
        else:
            BOSS.x = new_position
            boss_current_speed = new_velocity

    elif SMOOTH_MOVEMENT_AVAILABLE:
        # 일반 스무딩 시스템 (PID 없음)
        smoother = get_smooth_movement()
        smoother.max_velocity = max_speed
        smoother.smoothing_factor = 0.08
        smoother.deadzone_radius = 20

        new_position, new_speed = smoother.calculate_smooth_position(
            BOSS.x, target_x, boss_current_speed
        )
        BOSS.x = new_position
        boss_current_speed = new_speed

    else:
        # 기본 물리: 직접 속도 적용
        BOSS.x += boss_current_speed
        BOSS.x = max(0, min(WIDTH - BOSS.width, BOSS.x))


# =============================================================================
# PART 12: 보스 스킬 시스템 (스테이지별)
# =============================================================================
# handle_boss()의 마지막 단계에서 호출. 게이지 기반 스킬 발동.

def _process_boss_skills():
    """스테이지별 보스 특수 스킬 처리 (요약)"""

    # --- 스테이지 1: 상모돌리기 ---
    if current_stage == 1:
        if boss_special_gauge >= 100 and not whip_active:
            activate_whip()  # 상모돌리기 발동

    # --- 스테이지 3: 감정 폭주 (사이코볼) ---
    elif current_stage == 3:
        if boss_special_gauge >= 100 and boss_special_ready:
            activate_emotional_overdrive()

    # --- 스테이지 4: 퐁크 ---
    if current_stage == 4:
        if current_boss_name == "인왕":
            # 인왕: 금강저 (게이지 200, 20% 확률) / 인왕문 봉쇄 (게이지 400)
            if boss_special_gauge_stage4 >= 200 and random.random() <= 0.20:
                activate_inwang_vajra()
            elif boss_special_gauge_stage4 >= 400:
                activate_inwang_gate()
        else:
            # 퐁크: 명상 발동 (게이지 150, 20% 확률)
            if boss_special_gauge_stage4 >= 150 and random.random() <= 0.20:
                activate_meditation()

    # --- 스테이지 8: 표창 + 그림자분신 + 초각성 ---
    elif current_stage == 8:
        # 표창 발사 (쿨타임 기반)
        if (boss_special_gauge >= STAGE8_SHURIKEN_COST
            and now >= stage8_shuriken_next_ready_ms
            and not stage8_shadow_casting):
            stage8_shuriken_casting = True

        # 그림자분신 (패들 히트 트리거)
        update_stage8_shadow_clones()


# =============================================================================
# PART 13: 공통 상태 효과 처리 (모든 리그 동일)
# =============================================================================

def _process_stun_knockback():
    """보스 스턴 + 넉백 처리 (화염병, 라그나로크 해머 등)"""
    boss_stunned_timer -= 1
    BOSS.x += boss_knockback_vel

    # 벽 충돌 시 멈춤
    if BOSS.x <= 0:
        BOSS.x = 0
        boss_knockback_vel = 0
    elif BOSS.x >= WIDTH - BOSS.width:
        BOSS.x = WIDTH - BOSS.width
        boss_knockback_vel = 0

    # 뿔박치기: 더 부드러운 감속 (0.92), 일반: 빠른 감속 (0.85)
    if horn_charge_boss_knockback_active:
        boss_knockback_vel *= 0.92
    else:
        boss_knockback_vel *= 0.85


def _apply_knockback_with_wall_bounce():
    """넉백 + 벽 반사 처리 (화재/EMP/팬텀킥)

    벽에 부딪히면 반대 방향으로 70% 속도로 반사.
    빙판 위에서는 감속이 적어 더 길게 미끄러짐 (0.94 vs 0.85).
    """
    new_x = BOSS.x + boss_fire_knockback_vel
    boss_min_x, boss_max_x = 0, WIDTH - BOSS.width

    if new_x <= boss_min_x:
        BOSS.x = boss_min_x
        boss_fire_knockback_vel = abs(boss_fire_knockback_vel) * 0.7   # 반사 + 30% 에너지 손실
    elif new_x >= boss_max_x:
        BOSS.x = boss_max_x
        boss_fire_knockback_vel = -abs(boss_fire_knockback_vel) * 0.7
    else:
        BOSS.x = new_x

    # 감속
    if is_ice_active():
        boss_fire_knockback_vel *= 0.94  # 빙판: 6%만 감속
    else:
        boss_fire_knockback_vel *= 0.85  # 일반: 15% 감속

    if abs(boss_fire_knockback_vel) <= 0.3:
        boss_fire_knockback_vel = 0.0


def _process_serve_waiting():
    """서브 대기 중 보스 패들 간보기 움직임

    4가지 스타일을 랜덤 선택:
    1. 사인파 미세 흔들림
    2. 간헐적 급격한 이동 (2% 확률)
    3. 느린 사인파 스윙
    4. 간헐적 중간 이동 (1.5% 확률)

    신화리그는 더 정교: 이중 사인파 + 플레이어 패들 추적 모션.
    """
    time_now = pygame.time.get_ticks()

    def fake_motion():
        style = random.randint(1, 4)
        if style == 1:
            return math.sin(time_now / 100) * 2.5
        elif style == 2 and random.random() < 0.02:
            return random.choice([-1, 1]) * random.randint(20, 30)
        elif style == 3:
            return math.sin(time_now / 300) * 4
        elif style == 4 and random.random() < 0.015:
            return random.choice([-1, 1]) * 10
        return 0

    # 보스 서브 차례: 간보기 후 서브 실행
    if not is_player_serve:
        BOSS.centerx += fake_motion()
        if time_now - waiting_start_time >= wait_delay:
            serve_result = physics_manager.serve_ball(is_player_serve, current_stage, ai_mode)
            apply_serve_result(serve_result)


# =============================================================================
# PART 14: 투기장(Arena) 전용 AI
# =============================================================================
# 투기장 모드에서는 보스와 플레이어가 동등한 능력치로 싸움.

def _handle_arena_ai():
    """투기장 모드: 보스와 플레이어 동일 능력치

    - max_speed = 6.0 (플레이어와 동일)
    - acceleration = 0.4
    - 데드존 8px
    - PID/Smooth 바이패스, 직접 물리 적용
    """
    enhanced_max_speed = 6.0
    enhanced_acceleration = 0.4
    _arena_dz = 8  # 데드존

    # 공이 보스 패들까지 도달하는 시간 기반 예측
    _bvy = ball_vel[1]
    if abs(_bvy) > 1e-3:
        _dist_y = BOSS.bottom - BALL.centery
        _predict_t = max(0.0, _dist_y / _bvy) if _bvy != 0 else 0
        future_x = BALL.centerx + ball_vel[0] * _predict_t
    else:
        future_x = BALL.centerx

    # 직접 가속/감속 (PID 없음)
    if future_x < BOSS.centerx - _arena_dz:
        boss_current_speed = max(-enhanced_max_speed, boss_current_speed - enhanced_acceleration)
    elif future_x > BOSS.centerx + _arena_dz:
        boss_current_speed = min(enhanced_max_speed, boss_current_speed + enhanced_acceleration)
    else:
        if boss_current_speed > 0:
            boss_current_speed = max(0, boss_current_speed - enhanced_acceleration)
        elif boss_current_speed < 0:
            boss_current_speed = min(0, boss_current_speed + enhanced_acceleration)

    BOSS.x = max(80, min(600, BOSS.x + boss_current_speed))  # 경계 클램핑


# =============================================================================
# PART 15: 보스 대쉬 모션 처리
# =============================================================================

def _process_boss_dash():
    """보스 대쉬 모션 (플레이어 rolling 대쉬와 유사한 속도 곡선)

    초반 20프레임: 최대 속도(40px/frame)
    이후: 선형 감속 → 정지
    잔상 이펙트 생성 (매 3프레임)
    """
    boss_dash_timer -= 1

    high_phase_frames = min(20, boss_dash_duration_frames)
    if boss_dash_timer > high_phase_frames:
        move_step = boss_dash_speed * boss_dash_direction  # 최대 속도
    else:
        decel_factor = boss_dash_timer / float(high_phase_frames) if high_phase_frames > 0 else 0
        move_step = boss_dash_speed * boss_dash_direction * decel_factor  # 감속

    BOSS.centerx += move_step
    BOSS.x = max(0, min(WIDTH - BOSS.width, BOSS.x))

    # 잔상 생성 (3프레임마다)
    if boss_dash_timer % 3 == 0:
        boss_dash_afterimages.append({
            'x': BOSS.centerx, 'y': BOSS.centery,
            'alpha': 180, 'width': BOSS.width, 'height': BOSS.height,
            'life': 15
        })

    # 대쉬 종료
    if boss_dash_timer <= 0:
        boss_dashing = False
        boss_dash_stun_timer = int(stage_cfg.get("dash_stun_duration", 0.6) * 60)


# =============================================================================
# 요약: AI 난이도별 핵심 차이
# =============================================================================
"""
| 항목              | Junior     | Pro        | Champion   | Mythic         |
|-------------------|------------|------------|------------|----------------|
| 실수율            | 30%        | 25%        | 8%         | 0.5%           |
| 예측 오차         | ±150px     | ±95px      | ±60px      | 시뮬레이션 기반 |
| 예측 방식         | 단순 선형  | 프레임 예측 | 벽반사 예측 | 3시나리오 물리  |
| 공속 적응         | 없음       | 없음       | 동적 프레임 | 적응형 감속    |
| 패턴 학습         | 없음       | 없음       | 없음       | 최근 10타 분석  |
| 속도 제어         | 2단계      | 2단계      | 3단계      | 5단계 세밀 제어 |
| 데드존            | 25px       | 10px       | 15px       | 3px            |
| 벽 반사 대응      | 없음       | 없음       | 간단 계산  | 4회 시뮬레이션  |
| 포지셔닝          | 반응형     | 반응형     | 반응형     | 예측적 복귀    |
| 가속 계수         | 1.0x       | 1.0x       | 1.2x       | 최대 3.0x      |
| 이동 물리         | PID 엔진   | PID 엔진   | PID 엔진   | 직접 제어      |
"""
