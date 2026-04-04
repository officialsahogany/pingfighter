"""
=============================================================================
PingFighter (핑파이터) - Ball Physics Engine: Code Review Document
=============================================================================

이 파일은 실제 게임에서 사용 중인 공 물리 엔진 코드를 코드리뷰용으로 정리한 것입니다.
실행용이 아닌 리뷰/참고용 문서입니다.

게임 개요: Pygame 기반 60fps 고정 아케이드 탁구 게임.
화면: 760x750, 공 반지름 22px, 패들 높이 40px.
물리: 프레임 기반 (dt 미사용, 60fps 전제).

물리 엔진 특징:
- 단순 반사가 아닌 "임팩트 부스트 + 적응형 감속" 이중 구조
- 패들 충돌 위치에 따른 반사 각도 (최대 ±60도)
- 공 속도에 따라 부스트/감속률이 동적으로 변화
- 스핀(커브), 파워스매싱(포물선), 자기장(나선) 등 특수 물리
- Sub-stepping으로 고속 공의 터널링 방지
=============================================================================
"""

# =============================================================================
# PART 1: 핵심 전역 변수
# =============================================================================

# 공 기본 상태
BALL_BASE_SPEED = 9              # 기본 속도 (서브 시 초기 속도)
BALL_RADIUS = 22                 # 공 반지름 (px)
ball_vel = [0.0, 0.0]           # [vx, vy] - 매 프레임 업데이트되는 속도 벡터
ball_angle = 0                   # 시각적 회전 각도 (물리에 직접 영향 없음)

# 임팩트 부스트 시스템 (패들 충돌 후 순간 가속 → 점진 감속)
ball_impact_boost = 1.0          # 현재 부스트 배율 (1.0 = 기본, 2.8 = 최대)
ball_boost_decay_rate = 0.975    # 부스트 감쇠율 (매 프레임 곱함, 동적 조정됨)
ball_min_boost = 0.70            # 부스트 최소값 (감속 후 최종 속도 비율)

# 스핀/커브 시스템
ball_spin_strength = 0.0         # 스핀 세기 (0 = 없음, 0.6+ = 강한 커브)
ball_spin_direction = 0          # -1: 왼쪽 커브, 0: 없음, 1: 오른쪽 커브
ball_spin_decay = 0.98           # 스핀 매 프레임 감쇠율

# 속도 제한
MAX_BALL_VELOCITY = 100          # 글로벌 최대 속도 (특수 스킬 제외)

# 수평 정체 방지
horizontal_movement_timer = 0    # Y속도가 거의 0인 프레임 카운터
horizontal_threshold = 1.0       # Y속도 이 미만이면 정체 판정
max_horizontal_time = 200        # 200프레임(~3.3초) 이상 정체 시 보정 시작
angle_correction_strength = 1.5  # 보정 힘 (중앙 향해 점진 적용)


# =============================================================================
# PART 2: 공 이동 - 매 프레임 물리 업데이트
# =============================================================================

def _ball_movement_per_frame():
    """공 이동의 핵심 수식 (handle_ball 내부)

    실제 이동량 = ball_vel × ball_impact_boost

    ball_vel: 방향+기본속도 (패들 충돌 시 설정)
    ball_impact_boost: 순간 가속 배율 (매 프레임 감쇠)

    이 분리 구조 덕분에:
    - 패들 충돌 직후: 높은 부스트로 빠른 공
    - 시간 경과: 부스트 감쇠로 자연스러운 감속
    - 벽 반사: ball_vel만 반전, 부스트는 유지
    """

    # Sub-stepping: 빠른 공은 여러 단계로 나눠 이동 (터널링 방지)
    total_vel_x = ball_vel[0] * ball_impact_boost
    total_vel_y = ball_vel[1] * ball_impact_boost
    total_speed = math.sqrt(total_vel_x**2 + total_vel_y**2)

    max_step_distance = 12  # 한 스텝 최대 이동 거리 (px)

    if total_speed > max_step_distance:
        num_steps = int(math.ceil(total_speed / max_step_distance))
    else:
        num_steps = 1

    step_vel_x = total_vel_x / num_steps
    step_vel_y = total_vel_y / num_steps

    for step in range(num_steps):
        BALL.x += step_vel_x
        BALL.y += step_vel_y
        # 각 스텝마다 벽/장애물 충돌 체크


# =============================================================================
# PART 3: 임팩트 부스트 시스템 (핵심 물리)
# =============================================================================

def _calculate_impact_boost_on_paddle_hit(speed):
    """패들 충돌 시 임팩트 부스트 계산

    핵심 아이디어: "수평 타격이 수직 타격보다 강하다"
    → 수평에 가까운 공을 받아치면 더 큰 부스트
    → 고속 공은 부스트가 줄어들어 과속 방지

    [입력] 현재 공 속도, 공의 이동 각도
    [출력] ball_impact_boost, ball_boost_decay_rate, ball_min_boost 설정
    """

    # --- 1. 공의 이동 각도 계산 ---
    # 90도 = 수직 (위아래), 0도 = 수평 (좌우)
    if abs(ball_vel[0]) > 0.1:
        ball_angle_deg = math.degrees(math.atan2(abs(ball_vel[1]), abs(ball_vel[0])))
    else:
        ball_angle_deg = 90

    # --- 2. 각도 기반 부스트 배율 ---
    # 수직(90°) = 2.0x, 수평(45°이하) = 2.8x (10도 단위 선형 보간)
    angle_boost_table = {
        90: 2.0,   # 수직
        80: 2.2,
        70: 2.4,
        60: 2.6,
        45: 2.8,   # 수평 (최대)
    }
    base_boost = _interpolate_from_table(ball_angle_deg, angle_boost_table)
    min_boost = 1.1  # 고속에서도 최소 110%

    # --- 3. 주니어리그 보정 ---
    if ai_mode == "junior":
        base_boost = 1.0 + (base_boost - 1.0) * 0.55  # 부스트 55%로 축소
        min_boost = 1.05

    # --- 4. 공속도 비율 (과속 방지) ---
    # 속도 10 이하: 부스트 100% 적용
    # 속도 10~18: 점진적 감소
    # 속도 18 이상: 최소 부스트만 적용
    if speed <= 10.0:
        speed_ratio = 0.0
    elif speed >= 18.0:
        speed_ratio = 1.0
    else:
        speed_ratio = (speed - 10.0) / 8.0

    # --- 5. 관성 보존 보너스 ---
    # 벽 충돌 후 800ms 이내 + 저속(<12)이면 보너스
    wall_bonus = 1.0
    if pygame.time.get_ticks() - last_wall_collision_time < 800 and speed < 12:
        wall_bonus = min(1.4, 1.0 + (12 - speed) * 0.06)

    # --- 6. 최종 부스트 계산 ---
    speed_ratio_softened = speed_ratio ** 0.7  # 완만한 감소 곡선
    dynamic_boost = base_boost - (base_boost - min_boost) * speed_ratio_softened

    # 스테이지별 상한: Stage 1=1.7x, Stage 2=1.8x, Stage 3=1.9x
    stage_caps = {1: 1.7, 2: 1.8, 3: 1.9}
    if current_stage in stage_caps:
        dynamic_boost = min(dynamic_boost, stage_caps[current_stage])

    ball_impact_boost = dynamic_boost * wall_bonus

    # --- 7. 감쇠 파라미터 동적 설정 ---
    # 저속: 42프레임(0.7초)에 걸쳐 70%까지 감속
    # 고속: 35프레임(0.58초)에 걸쳐 55%까지 감속
    decay_frames = 42 - (42 - 35) * speed_ratio   # 42 → 35
    min_final = 0.70 - (0.70 - 0.55) * speed_ratio  # 0.70 → 0.55

    if decay_frames > 0 and dynamic_boost > min_final:
        penalty = 1.0 + speed_ratio * 0.18  # 고속 패널티
        adjusted_frames = decay_frames / penalty
        ball_boost_decay_rate = (min_final / dynamic_boost) ** (1.0 / adjusted_frames)
    else:
        ball_boost_decay_rate = 0.95

    ball_min_boost = min_final


# =============================================================================
# PART 4: 적응형 감속 시스템 (매 프레임)
# =============================================================================

def _adaptive_deceleration():
    """패들 충돌 후 매 프레임 부스트를 감쇠시키는 시스템

    공 속도에 따라 감속 강도가 달라짐:
    - 저속(<10): 감속 60% 완화 → 저속 공이 너무 빨리 멈추지 않게
    - 중속(10~15): 기본 감속률 적용
    - 고속(15~25): 감속 강화 (최대 1.2x 패널티)
    - 초고속(30+): 추가 5% 감속
    - 포세이돈 효과: 속도 20+ 일 때 추가 8% 감속
    """
    current_speed = math.sqrt(ball_vel[0]**2 + ball_vel[1]**2)

    if ball_impact_boost > ball_min_boost:
        if current_speed < 10:
            # 저속: 감속 60% 완화 (공이 천천히 움직이는 걸 유지)
            adaptive_rate = 1.0 - (1.0 - ball_boost_decay_rate) * 0.4
        elif current_speed < 15:
            # 중속: 기본 감속률
            adaptive_rate = ball_boost_decay_rate
        else:
            # 고속: 속도에 비례한 감속 강화
            ratio = min(current_speed / 25.0, 1.0)
            penalty = 1.0 + ratio * 1.2
            adaptive_rate = 1.0 - (1.0 - ball_boost_decay_rate) * penalty
            if current_speed > 30:
                adaptive_rate *= 0.95  # 초고속 추가 감속

        # 포세이돈 삼지창 효과
        if is_water_affected and current_speed > 20:
            adaptive_rate *= 0.92  # 물회오리 추가 감속

        ball_impact_boost *= adaptive_rate
        ball_impact_boost = max(ball_impact_boost, ball_min_boost)


# =============================================================================
# PART 5: 서브 (Serve) 물리
# =============================================================================

def serve_ball(is_player_serve, current_stage, league_mode):
    """공 서브 속도 계산

    기본 속도: BALL_BASE_SPEED(9) × 1.2 (서브 보너스)
    스테이지 배율: 1.0 + (stage - 1) × 0.03 (스테이지당 3%, 최대 1.5x)
    주니어리그: × 0.65 (-35% 감속)

    X 속도: ±3 (랜덤 좌/우) × 스테이지 배율
    Y 속도: base_speed × speed_scale (플레이어: 위로, 보스: 아래로)
    최대 서브 속도: base_speed × 1.6 × speed_scale
    """
    base_speed = BALL_BASE_SPEED  # 9
    speed_scale = 1.2             # 서브 20% 빠르게
    stage_mult = 1.0 + min((current_stage - 1) * 0.03, 0.5)

    vx = random.choice([-3, 3]) * stage_mult
    vy = base_speed * speed_scale * stage_mult
    if is_player_serve:
        vy = -vy  # 위로

    # 주니어리그 감속
    if league_mode == "junior":
        vx *= 0.65
        vy *= 0.65

    return {"ball_vel": [vx, vy], "ball_impact_boost": 1.0}


# =============================================================================
# PART 6: 패들 충돌 반사 각도 (calculate_bounce 핵심)
# =============================================================================

def _reflection_angle(paddle):
    """패들 위 충돌 위치로 반사 각도 결정

    rel_x = (공 중심 - 패들 중심) / 패들 반너비
    rel_x: -1.0(왼쪽 끝) ~ 0(중앙) ~ 1.0(오른쪽 끝)

    반사 각도 = rel_x × 60도 (최대 ±60도)
    → 패들 끝에 맞을수록 급격한 각도
    → 패들 중앙에 맞으면 수직 반사

    최종 속도:
    vx = speed × sin(angle)
    vy = -|speed × cos(angle)|  (플레이어: 항상 위로)
    vy = +|speed × cos(angle)|  (보스: 항상 아래로)
    """
    rel_x = (BALL.centerx - paddle.centerx) / max(paddle.width / 2, 1.0)
    rel_x = max(-1.0, min(1.0, rel_x))

    angle = rel_x * (math.pi / 3)  # 최대 ±60도

    speed = math.hypot(ball_vel[0], ball_vel[1])
    new_speed = speed * ball_impact_boost

    ball_vel[0] = new_speed * math.sin(angle)
    if paddle == PLAYER:
        ball_vel[1] = -abs(new_speed * math.cos(angle))
    else:
        ball_vel[1] = abs(new_speed * math.cos(angle))


# =============================================================================
# PART 7: 패들 충돌 후 속도 증가 시스템
# =============================================================================

def _speed_increase_after_bounce():
    """패들에 맞을 때마다 미세한 속도 증가 (랠리가 길어질수록 빨라짐)

    기본: 2~7% 증가 (random)
    보스 추가: 1.2~5.4% 증가
    중앙 히트 (±5%): 3% 보너스
    엣지 히트 (>75%): 1.5~5% 보너스 + 커브
    주니어리그: 모든 배율 20% 감소
    투기장: 2.24x 고정 배율
    """
    pass


# =============================================================================
# PART 8: 드라이브 (스핀/커브) 물리
# =============================================================================

def _drive_spin_physics():
    """드라이브 스킬 활성 시 공에 커브(스핀) 적용

    스핀 적용 (매 프레임):
    spin_force = ball_spin_strength × ball_spin_direction × 3.5
    ball_vel[0] += spin_force  (X 방향 힘)
    ball_spin_strength *= 0.98  (매 프레임 2% 감쇠)

    스핀 종료: ball_spin_strength < 0.01이면 drive_ball_active = False

    스핀 세기 결정 (calculate_bounce에서):
    - 기본: 0.25 (비스매셔) / 0.155 (스매셔)
    - 속도 비례: +speed × 0.015
    - 스핀 상한: 0.6 (콤보로 증가 가능)
    - 콤보 보너스: +0.08/콤보 (최대 +0.48)
    - 커브 각도: ±22.5도
    """
    if ball_spin_strength > 0.01:
        spin_force = ball_spin_strength * ball_spin_direction * 3.5
        ball_vel[0] += spin_force
        ball_spin_strength *= ball_spin_decay  # 0.98
    else:
        ball_spin_strength = 0.0
        ball_spin_direction = 0
        if drive_ball_active:
            drive_ball_active = False


# =============================================================================
# PART 9: 파워스매싱 (포물선 궤적)
# =============================================================================

def _power_smashing_physics():
    """파워스매싱: 공이 포물선을 그리며 이동

    1단계 - 초기 부스트 (0~500ms):
      직선: 1.72x → 1.0x (선형 보간)
      사선: 1.90x → 1.0x
      → 발동 직후 강한 가속, 0.5초에 걸쳐 감소

    2단계 - 상승 (0~1.8초):
      수직 힘: base_lift = 0.035 × 1.5 × (1.8 - elapsed) / 1.8
      ball_vel[1] -= vertical_lift (위로 끌어올림)
      수평 감쇠: × max(0.8, 1.0 - elapsed × 0.05)

    3단계 - 하강 (1.8초+):
      수직 힘: base_pull = 0.035 × 1.2 × (elapsed - 1.8)
      ball_vel[1] += vertical_pull (아래로 끌어내림)

    호(Arc) 강도:
      직선 (direction=0): arc_strength = 0.0
      좌/우: ±(0.6 ± 0.15) (랜덤)
      고콤보: ±0.8 (고정)

    카오스 요소: 사인파 + 랜덤 미세 변동 (5~20%)
    """
    pass


# =============================================================================
# PART 10: 벽 반사 물리
# =============================================================================

def _wall_bounce_physics():
    """좌우 벽 충돌 시 물리 처리

    반사: ball_vel[0] *= -1 (X 방향 반전)
    감속: × 0.95 (X, Y 각각 5% 감속)

    관성 보존 시스템:
    - last_wall_collision_time 기록
    - 다음 패들 충돌 시 800ms 이내면 관성 보너스 (1.0~1.4x)
    - 저속(<12)일수록 높은 보너스

    수직 정체 방지:
    - |vy| < 1.0인 상태가 200프레임(~3.3초) 지속되면
    - 점진적으로 Y 방향 힘 추가 (1초에 걸쳐 보정)
    - 공이 화면 상단이면 아래로, 하단이면 위로
    """
    pass


# =============================================================================
# PART 11: 스테이지별 특수 물리
# =============================================================================

def _stage_specific_physics():
    """스테이지별 공 궤적을 직접 조작하는 보스 스킬들"""

    # --- Stage 3: 쿠로미 공 먹기 ---
    # 공이 쿠로미 영역에 진입하면 ball_vel 무시, 공 위치 고정
    # 씹기 애니메이션 후 랜덤 각도로 발사 (드라이브 자동 적용)

    # --- Stage 4: 명상 8자 궤도 (Lemniscate of Bernoulli) ---
    # ball_vel 무시, 공 좌표를 직접 계산
    # x = boss.cx + scale × cos(t) / (1 + sin²(t))
    # y = boss.cy + scale × sin(t)×cos(t) / (1 + sin²(t))
    # 1.8초에 2바퀴 회전
    # 종료 시: ±45도 랜덤 발사 (1.3~1.6x 기본속도)

    # --- Stage 4: 자기장 (나선 끌어당김) ---
    # 보스 주변 반경 안이면:
    # curve_vector = 플레이어 방향.rotate(각도) × 1.8
    # ball_vel += curve_vector (매 프레임 누적)
    # ball_vel *= 1.04 (점진 가속)
    # 속도 상한: BALL_BASE_SPEED × 2.2

    # --- Stage 5: 홍련폭염 ---
    # 2초간 공 궤적을 flame_trail_positions에 기록
    # 물리 자체는 변하지 않고, 궤적을 따라 �� 렌더링만 추가

    # --- Stage 7: 테트로미노 블럭 반사 ---
    # AABB 충돌 후 방향 판정 (|dx| vs |dy|)
    # |dx| > |dy|: ball_vel[0] *= -1 (좌우 반사)
    # |dx| < |dy|: ball_vel[1] *= -1 (상하 반사)


# =============================================================================
# PART 12: 시간 정지 (스톱워치)
# =============================================================================

def _stopwatch_physics():
    """스톱워치 아이템: 2초 시간 정지 + 1초 복귀

    활성화 시:
    - stopwatch_original_ball_vel에 현재 속도 백업
    - ball_vel = [0, 0] (완전 정지)
    - 2초(120프레임) 동안 모든 물리 스킵

    복귀 시:
    - 1초에 걸쳐 점진 복귀
    - ball_vel = original × (1.0 + recovery_progress)
    - 부드러운 속도 회복으로 갑작스러운 전환 방지
    """
    pass


# =============================================================================
# PART 13: 속도 제한 시스템
# =============================================================================

def _speed_limiter():
    """공 최대 속도 제한 (특수 스킬 사용 중 제외)

    MAX_BALL_VELOCITY = 100 (물회오리 효과 위해 높게 설정)

    제외 조건 (속도 제한 미적용):
    - 파워스매싱 활성
    - 고스트샷 활성
    - 상모돌리기 활성
    - 드라이브 활성
    - 사이코볼 활성
    - 기타 special_active

    적용 방식:
    current_speed = hypot(vx, vy)
    if current_speed > MAX:
        ratio = MAX / current_speed
        ball_vel[0] *= ratio
        ball_vel[1] *= ratio
    → 방향 유지, 속도만 클램핑
    """
    pass


# =============================================================================
# PART 14: 날씨 효과 (돌풍)
# =============================================================================

def _weather_effects():
    """날씨 이벤트가 공에 미치는 영향

    돌풍(Gust) 활성 시:
    - weather_ball_dx, weather_ball_dy 값을 ball_vel에 매 프레임 추가
    - 공이 바람 방향으로 밀림
    - 패들에도 동일한 힘 적용 (보스/플레이어 모두)
    """
    if is_weather_active():
        dx, dy = apply_weather_effects_to_ball(ball_vel)
        ball_vel[0] += dx
        ball_vel[1] += dy


# =============================================================================
# 요약: 물리 엔진 구조
# =============================================================================
"""
매 프레임 실행 순서 (handle_ball 내부):
1. 쿨다운 감소
2. 스테이지별 특수 물리 (자기장, 명상 등)
3. 서브 대기 처리
4. 적응형 감속 (ball_impact_boost 감쇠)
5. 스핀/커브 적용 (ball_vel[0] += spin_force)
6. 날씨 효과 적용
7. 수평 정체 방지
8. 속도 제한 (MAX_BALL_VELOCITY)
9. Sub-stepping 이동 + 충돌 체크
10. 벽/패들/득점 판정

패들 충돌 시 (calculate_bounce):
1. 캐릭터별 타격 애니메이션
2. 전설 아이템 효과 (라그나로크, 포세이돈)
3. 충돌 위치 → 반사 각도 (±60도)
4. 각도+속도 기반 임팩트 부스트 계산
5. 퍼펙트 타이밍 / 드라이브 / 파워스매싱 판정
6. 최종 속도 벡터 설정

핵심 수식:
| 수식 | 설명 |
|------|------|
| actual_vel = ball_vel × ball_impact_boost | 실제 이동량 |
| ball_impact_boost *= adaptive_decay | 매 프레임 감쇠 |
| angle = rel_x × π/3 | 패들 위치 → 반사 각도 |
| boost = angle_boost - (angle_boost - min_boost) × speed_ratio^0.7 | 동적 부스트 |
| spin_force = strength × direction × 3.5 | 커브 힘 |
| momentum = min(1.4, 1.0 + (12 - speed) × 0.06) | 관성 보존 |

속도 흐름 (일반적인 랠리):
서브(9) → 패들 히트(부스트 2.0x → 속도 ~18) → 감쇠(0.7초간 → 속도 ~11)
→ 벽 반사(×0.95 → 속도 ~10.5) → 상대 패들 히트(부스트 → 속도 ~17) → 반복

특수 상황:
- 드라이브: +커브 + 약간의 속도 증가 (1.015x)
- 파워스매싱: 포물선 궤적 + 초기 1.72~1.90x 부스트
- 자기장: 나선 가속 (매 프레임 ×1.04, 상한 2.2x)
- 명상: ball_vel 무시, 좌표 직접 제어
- 스톱워치: 2초 정지 → 1초 점진 복귀
"""
