"""
=============================================================================
PingFighter (핑파이터) - Collision System: Code Review Document
=============================================================================

이 파일은 실제 게임에서 사용 중인 충돌 코드를 코드리뷰용으로 정리한 것입니다.
실행용이 아닌 리뷰/참고용 문서입니다.

게임 개요: Pygame 기반 아케이드 탁구 게임. 보스와 1v1로 대결.
화면: 760x750, 보스 패들(Y=25), 플레이어 패들(Y=710).
공은 0~760 전체 너비에서 물리 반사함 (필러 80px는 UI 오버레이일 뿐).

충돌 구조 요약:
- 모든 충돌 로직은 pingfighter.py 본체에 직접 구현 (모듈화되지 않음)
- handle_ball(): 매 프레임 호출되는 메인 물리 함수 (벽/패들/득점/아이템 전부 처리)
- calculate_bounce(paddle): 패들 충돌 시 반사 각도/부스트/드라이브/스킬 처리
- 충돌 쿨다운으로 중복 충돌 방지
- 플레이어 충돌은 handle_player()에서 1차 처리, handle_ball()에서 백업 처리
=============================================================================
"""

# =============================================================================
# PART 1: 전역 상태 변수 (충돌 관련)
# =============================================================================

# 충돌 쿨다운 시스템
player_collision_cooldown = 0   # 플레이어 패들 충돌 쿨다운 (프레임 단위)
boss_collision_cooldown = 0     # 보스 패들 충돌 쿨다운
player_collision_handled = False  # 이번 프레임에 handle_player에서 충돌 처리했는지
player_sound_cooldown = 0       # 사운드 중복 재생 방지

# 공 물리
ball_vel = [0.0, 0.0]          # [vx, vy] - 공 속도 벡터
ball_impact_boost = 1.0         # 임팩트 부스트 (패들 충돌 시 속도 배율)
ball_boost_decay_rate = 0.95    # 부스트 감쇠율 (매 프레임 곱함)
ball_min_boost = 0.70           # 부스트 최소값

# 벽 충돌 추적
wall_bounce_count = 0           # 좌우 벽 연속 충돌 카운터 (무승부 판정용)
last_wall_hit = None            # 마지막 벽 ('left' or 'right')
last_paddle_hit_time = 0        # 마지막 패들 충돌 시간 (ms)
last_wall_collision_time = 0    # 마지막 벽 충돌 시간 (관성 보존용)
horizontal_bounce_count = 0     # 수평만 튕김 카운터 (무승부 판정용)

# 무승부 판정 상수
DRAW_BOUNCE_LIMIT = 8           # 좌우 벽 왕복 8회 이상
DRAW_TIME_LIMIT = 5000          # 패들 안 친 지 5초 이상 → 둘 다 만족하면 무승부


# =============================================================================
# PART 2: handle_ball() - 메인 물리 루프 (매 프레임 호출)
# =============================================================================

def handle_ball():
    """공 물리 업데이트 + 모든 충돌 처리 (매 프레임 호출)

    실행 순서:
    1. 쿨다운 감소
    2. 보스 스킬 처리 (자기장, 명상, 화염탄 등)
    3. 서브 대기 처리
    4. 공 이동 (ball_vel 적용)
    5. 벽돌/장애물 충돌
    6. 좌우 벽 충돌
    7. 무승부 판정
    8. 보스 패들 충돌
    9. 플레이어 패들 충돌 (백업 - handle_player에서 1차 처리)
    10. 득점 판정 (상단/하단 탈출)
    11. 임팩트 부스트 감쇠
    """

    # --- 1. 쿨다운 감소 ---
    if boss_collision_cooldown > 0:
        boss_collision_cooldown -= 1
    if player_sound_cooldown > 0:
        player_sound_cooldown -= 1

    # --- 2. 보스 스킬 처리 (공 궤적을 직접 조작하는 스킬들) ---

    # Stage 4 자기장: 공이 보스 주변 반경 안이면 커브 궤적으로 끌어당김
    if current_stage == 4 and stage4_magnetic_active:
        distance = math.hypot(BALL.centerx - BOSS.centerx, BALL.centery - BOSS.centery)
        if distance < stage4_magnetic_radius:
            magnet_curve_angle += 4.1
            direction_to_player = pygame.math.Vector2(
                PLAYER.centerx - BALL.centerx,
                PLAYER.centery - BALL.centery
            ).normalize()
            curve_vector = direction_to_player.rotate(magnet_curve_angle) * 1.8
            ball_vel[0] += curve_vector.x
            ball_vel[1] += curve_vector.y
            ball_vel[0] *= 1.04  # 점진적 가속
            ball_vel[1] *= 1.04
            # 속도 상한
            current_speed = math.hypot(ball_vel[0], ball_vel[1])
            max_speed = BALL_BASE_SPEED * 2.2
            if current_speed > max_speed:
                scale = max_speed / current_speed
                ball_vel[0] *= scale
                ball_vel[1] *= scale

    # Stage 4 명상: 공이 보스 주위를 8자(무한대) 궤도로 공전
    if current_stage == 4 and meditation_active:
        meditation_angle += (720.0 / meditation_duration)  # 1.8초에 2바퀴
        rad = math.radians(meditation_angle)
        scale = 80 * 1.5  # 8자 크기
        denominator = 1 + math.sin(rad) ** 2
        # Lemniscate of Bernoulli 공식
        BALL.centerx = int(BOSS.centerx + scale * math.cos(rad) / denominator)
        BALL.centery = int(BOSS.centery + scale * math.sin(rad) * math.cos(rad) / denominator)
        if meditation_timer <= 0:
            # 명상 종료 → 플레이어 방향으로 랜덤 각도 발사
            angle_deg = random.randint(-45, 45)
            speed = BALL_BASE_SPEED * random.uniform(1.3, 1.6)
            ball_vel = [speed * math.sin(math.radians(angle_deg)),
                        abs(speed * math.cos(math.radians(angle_deg)))]
        return

    # --- 3. 서브 대기 ---
    if is_waiting_for_serve:
        if is_player_serve:
            BALL.centerx = PLAYER.centerx
            BALL.bottom = PLAYER.top - 5
        else:
            BALL.centerx = BOSS.centerx
            BALL.top = BOSS.bottom + 5
        return  # 서브 대기 중에는 물리 처리 안 함

    # --- 4. 공 이동 (임팩트 부스트 적용) ---
    BALL.x += ball_vel[0] * ball_impact_boost
    BALL.y += ball_vel[1] * ball_impact_boost

    # --- 5. 벽돌/장애물 충돌 (스테이지별) ---
    # 테트로미노(Stage 7), 모래 장애물, 거미줄 등
    # 각 장애물 유형별로 BALL.colliderect() 체크 후 반사

    # --- 6. 좌우 벽 충돌 ---
    _handle_wall_collision()

    # --- 7. 무승부 판정 ---
    _check_draw_condition()

    # --- 8. 보스 패들 충돌 ---
    _handle_boss_paddle_collision()

    # --- 9. 플레이어 패들 충돌 (백업) ---
    _handle_player_paddle_collision_backup()

    # --- 10. 득점 판정 ---
    _handle_scoring()

    # --- 11. 임팩트 부스트 감쇠 ---
    if ball_impact_boost > ball_min_boost:
        ball_impact_boost *= ball_boost_decay_rate
        if ball_impact_boost < ball_min_boost:
            ball_impact_boost = ball_min_boost


# =============================================================================
# PART 3: 좌우 벽 충돌
# =============================================================================

def _handle_wall_collision():
    """좌우 벽 충돌 처리

    - 반사: ball_vel[0] *= -1
    - 감속: 5% 감속 (0.95 배율)
    - 이펙트: 에너지볼 벽 충돌 이펙트 스폰
    - 게이지: 충전가방 아이템 보유 시 게이지 충전
    - 무승부: 좌우 벽 왕복 카운트 업데이트
    - 스테이지 2: 정글 잎사귀 파티클 생성
    """

    # --- 좌벽 충돌 ---
    if BALL.left <= 0:
        BALL.left = 0
        ball_vel[0] *= -1
        ball_vel[0] *= 0.95  # 5% X감속
        ball_vel[1] *= 0.95  # 5% Y감속
        play_wall_sound()
        spawn_wall_impact_effect(BALL.left, BALL.centery, 'left')

        # 무승부 판정: 좌우 벽 왕복 카운트
        current_time = pygame.time.get_ticks()
        if current_time - last_paddle_hit_time > 100:  # 패들 충돌 후 0.1초 경과
            if last_wall_hit == 'right':  # 이전이 우벽 → 좌우 왕복
                wall_bounce_count += 1
                time_without_paddle = current_time - last_paddle_hit_time
                if wall_bounce_count >= DRAW_BOUNCE_LIMIT and time_without_paddle >= DRAW_TIME_LIMIT:
                    go_to_next_round()  # 무승부 → 재대결
                    return
            else:
                wall_bounce_count = 0  # 같은 벽 연속이면 리셋
            last_wall_hit = 'left'

        # 충전가방: 벽 충돌 시 게이지 충전 (캐릭터별 기본 충전량의 20%)
        if chargebag_obtained:
            _apply_chargebag_bonus()

        # 관성 보존용 타임스탬프 기록
        last_wall_collision_time = pygame.time.get_ticks()

    # --- 우벽 충돌 --- (좌벽과 동일한 구조)
    elif BALL.right >= WIDTH:
        BALL.right = WIDTH
        ball_vel[0] *= -1
        ball_vel[0] *= 0.95
        ball_vel[1] *= 0.95
        play_wall_sound()
        spawn_wall_impact_effect(BALL.right, BALL.centery, 'right')
        # (좌벽과 동일한 무승부/충전가방/관성보존 로직)

    # --- 수평만 튕김 무승부 체크 ---
    if abs(ball_vel[1]) < 1 and (BALL.left <= 0 or BALL.right >= WIDTH):
        horizontal_bounce_count += 1
    else:
        horizontal_bounce_count = 0

    if horizontal_bounce_count >= 6:
        reset_round()  # 공이 거의 수평으로만 움직이면 재대결


# =============================================================================
# PART 4: 패들 충돌 - calculate_bounce(paddle)
# =============================================================================

def calculate_bounce(paddle):
    """패들 충돌 시 반사 각도/속도/부스트/스킬 처리

    이 함수는 패들(PLAYER 또는 BOSS)과 공이 충돌했을 때 호출됨.
    단순 반사가 아니라 아케이드 게임 특유의 다양한 시스템이 작동.

    처리 순서:
    1. 캐릭터별 타격 애니메이션 트리거
    2. 전설 아이템 효과 (라그나로크 스턴공, 포세이돈 해제)
    3. 패들 위 충돌 위치 계산 (rel_x: -1.0 ~ 1.0)
    4. 반사 각도 계산 (최대 ±60도)
    5. 공속도별 동적 임팩트 부스트 계산
    6. 퍼펙트 타이밍 / 드라이브 / 파워스매싱 판정
    7. 최종 속도 벡터 설정
    """

    is_player_paddle = (paddle == PLAYER)

    # === 1. 캐릭터별 타격 애니메이션 ===
    if is_player_paddle:
        hit_offset = BALL.centerx - PLAYER.centerx
        if selected_character_type == "optimus":
            # 옵티머스: 좌/우 팔 스윙 애니메이션
            if hit_offset < 0:
                optimus_arm_swing_left_timer = OPTIMUS_ARM_SWING_DURATION
            else:
                optimus_arm_swing_right_timer = OPTIMUS_ARM_SWING_DURATION
        elif selected_character_type == "smasher":
            trigger_smasher_contact_animation(hit_offset)
        elif selected_character_type == "viper":
            trigger_viper_contact_animation(hit_offset)
        elif selected_character_type == "blacksmith":
            # 발토르: 좌=방패 스윙, 우=망치 스윙
            if hit_offset < 0:
                blacksmith_shield_swing_active = True
            else:
                blacksmith_hammer_swing_active = True
        elif selected_character_type == "soldier":
            soldier_swing_active = True

    # === 2. 전설 아이템 효과 ===
    if not is_player_paddle:
        # 보스가 공을 칠 때: 포세이돈 회오리 가속 해제
        trident = legendary_manager.get_item("poseidon_trident")
        if trident and trident.active:
            trident.deactivate_water_trail()

    if is_player_paddle:
        # 라그나로크 해머: 50% 확률 스턴공 발동 (게이지 소모, 랠리당 1회)
        if legendary_active("ragnarok_hammer") and not ragnarok_stun_attempted_this_rally:
            ragnarok_stun_attempted_this_rally = True
            gauge_cost = hammer.gauge_cost  # 롤 옵션: 20~40
            if special_gauge >= gauge_cost and random.random() < 0.5:
                consume_special_gauge(gauge_cost)
                ragnarok_speed_boost_active = True

    # === 3. 패들 위 충돌 위치 계산 ===
    # rel_x: -1.0(왼쪽 끝) ~ 0(중앙) ~ 1.0(오른쪽 끝)
    paddle_centerx = paddle.centerx
    half_width = PADDLE_WIDTH / 2

    # 발토르 우산 모드: 히트박스 확장
    if selected_character_type == "blacksmith" and blacksmith_umbrella_open:
        # 우산 오프셋 + 좌우 확장된 히트박스 사용
        paddle_centerx += blacksmith_umbrella_body_offset[0]
        half_width = max(half_width, blacksmith_umbrella_hitbox_extents[1])

    rel_x = (BALL.centerx - paddle_centerx) / max(half_width, 1.0)
    rel_x = max(-1.0, min(1.0, rel_x))

    # === 4. 반사 각도 계산 ===
    angle = rel_x * (math.pi / 3)  # 최대 ±60도 (π/3 라디안)
    speed = math.hypot(ball_vel[0], ball_vel[1])

    # === 5. 공속도별 동적 임팩트 부스트 ===
    _apply_dynamic_impact_boost(speed)

    # === 6. 퍼펙트 타이밍 / 드라이브 / 파워스매싱 ===
    if is_player_paddle:
        _handle_drive_and_power_smashing(paddle, rel_x, speed, angle)

    # === 7. 최종 속도 벡터 ===
    new_speed = speed * ball_impact_boost
    ball_vel[0] = new_speed * math.sin(angle)
    if is_player_paddle:
        ball_vel[1] = -abs(new_speed * math.cos(angle))  # 항상 위로
    else:
        ball_vel[1] = abs(new_speed * math.cos(angle))    # 항상 아래로


# =============================================================================
# PART 5: 동적 임팩트 부스트 시스템
# =============================================================================

def _apply_dynamic_impact_boost(speed):
    """공속도와 각도에 따른 동적 임팩트 부스트 계산

    핵심 아이디어:
    - 수직(90도)에 가까운 공: 200% 부스트 (기본)
    - 수평(0도)에 가까운 공: 280% 부스트 (수평 타격이 더 강력)
    - 공이 빠를수록 부스트 감소 (과속 방지)
    - 주니어리그: 부스트 55%로 축소 (초보자 보호)
    """

    # --- 공의 현재 이동 각도 계산 ---
    if abs(ball_vel[0]) > 0.1:
        ball_angle_deg = math.degrees(math.atan2(abs(ball_vel[1]), abs(ball_vel[0])))
    else:
        ball_angle_deg = 90  # 거의 수직

    # --- 각도별 부스트 배율 ---
    # 90도(수직) = 2.0x → 80도 = 2.2x → 70도 = 2.4x → 60도 = 2.6x → 45도 = 2.8x
    if ball_angle_deg >= 90:
        angle_boost = 2.0
    elif ball_angle_deg >= 80:
        angle_boost = 2.0 + 0.2 * (90 - ball_angle_deg) / 10
    elif ball_angle_deg >= 70:
        angle_boost = 2.2 + 0.2 * (80 - ball_angle_deg) / 10
    elif ball_angle_deg >= 60:
        angle_boost = 2.4 + 0.2 * (70 - ball_angle_deg) / 10
    elif ball_angle_deg >= 45:
        angle_boost = 2.6 + 0.2 * (60 - ball_angle_deg) / 15
    else:
        angle_boost = 2.8  # 최대

    base_boost = angle_boost
    min_boost = 1.1  # 고속에서도 최소 110% 부스트

    # --- 주니어리그 보정 ---
    if ai_mode == "junior":
        base_boost = 1.0 + (base_boost - 1.0) * 0.55  # 부스트 55%로 축소
        min_boost = 1.05

    # --- 공속도 비율 (0~1) ---
    base_speed_threshold = 10.0   # 이 속도부터 부스트 감소 시작
    max_speed_threshold = 18.0    # 이 속도에서 최소 부스트
    if speed <= base_speed_threshold:
        speed_ratio = 0.0
    elif speed >= max_speed_threshold:
        speed_ratio = 1.0
    else:
        speed_ratio = (speed - base_speed_threshold) / (max_speed_threshold - base_speed_threshold)

    # --- 관성 보존 보너스 (저속 + 최근 벽 충돌) ---
    wall_collision_bonus = 1.0
    if last_wall_collision_time > 0 and pygame.time.get_ticks() - last_wall_collision_time < 800:
        if speed < 12:
            wall_collision_bonus = min(1.4, 1.0 + (12 - speed) * 0.06)

    # --- 최종 다이나믹 부스트 ---
    speed_ratio_softened = speed_ratio ** 0.7  # 완만한 감소 곡선
    dynamic_boost = base_boost - (base_boost - min_boost) * speed_ratio_softened

    # --- 스테이지별 부스트 상한 ---
    stage_caps = {1: 1.7, 2: 1.8, 3: 1.9}  # 4+ 스테이지는 제한 없음
    if current_stage in stage_caps:
        dynamic_boost = min(dynamic_boost, stage_caps[current_stage])

    ball_impact_boost = dynamic_boost * wall_collision_bonus

    # --- 동적 감쇠 설정 ---
    # 감쇠 프레임: 42(저속) → 35(고속), 최종 속도: 70%(저속) → 55%(고속)
    base_decay_frames = 42
    min_decay_frames = 35
    dynamic_decay_frames = base_decay_frames - (base_decay_frames - min_decay_frames) * speed_ratio

    base_min_boost = 0.70
    min_min_boost = 0.55
    dynamic_min_boost = base_min_boost - (base_min_boost - min_min_boost) * speed_ratio

    if dynamic_decay_frames > 0 and dynamic_boost > dynamic_min_boost:
        speed_penalty_factor = 1.0 + speed_ratio * 0.18
        adjusted_frames = dynamic_decay_frames / speed_penalty_factor
        ball_boost_decay_rate = (dynamic_min_boost / dynamic_boost) ** (1.0 / adjusted_frames)
    else:
        ball_boost_decay_rate = 0.95

    ball_min_boost = dynamic_min_boost


# =============================================================================
# PART 6: 인텐시티 기반 패들 충돌 넉백 시스템
# =============================================================================

# 기본 넉백 = 화재 넉백(12)의 20% = 2.4
PADDLE_HIT_KNOCKBACK_BASE = 2.4

# 인텐시티 레벨별 넉백 배율
PADDLE_HIT_KNOCKBACK_INTENSITY_SCALE = {
    0: 1.5,   # 기본 (파란색) - 150%
    1: 2.2,   # 레벨 1 (청록) - 220%
    2: 2.2,   # 레벨 2 (녹색) - 220%
    3: 3.8,   # 레벨 3 (노랑) - 380%
    4: 3.8,   # 레벨 4 (주황) - 380%
    5: 5.5,   # 레벨 5 (빨강) - 550%
}

def apply_paddle_hit_knockback_player(ball_x=None):
    """플레이어 패들 충돌 시 넉백 적용

    공이 패들 오른쪽에 맞으면 → 왼쪽으로 밀림
    공이 패들 왼쪽에 맞으면 → 오른쪽으로 밀림
    넉백 강도는 인텐시티 레벨에 비례.
    """
    intensity = get_display_intensity_level()
    scale = PADDLE_HIT_KNOCKBACK_INTENSITY_SCALE.get(intensity, 1.0)
    knockback = PADDLE_HIT_KNOCKBACK_BASE * scale

    if ball_x is not None:
        direction = -1 if ball_x > PLAYER.centerx else 1
    else:
        direction = random.choice([-1, 1])

    player_fire_knockback_vel = direction * knockback

def apply_paddle_hit_knockback_boss(ball_x=None):
    """보스 패들 충돌 시 넉백 (플레이어와 동일한 로직)"""
    # 플레이어와 동일한 구조, 대상만 BOSS


# =============================================================================
# PART 7: 보스 패들 충돌
# =============================================================================

def _handle_boss_paddle_collision():
    """보스 패들 충돌 처리

    조건:
    - BALL.colliderect(보스 확장 히트박스)
    - ball_vel[1] < 0 (공이 위로 가는 중)
    - boss_collision_cooldown <= 0
    - 서브 대기/시간 정지/스킬 시전 중 아님

    처리:
    1. calculate_bounce(BOSS) 호출
    2. 보스 게이지 충전
    3. 보스 패들 기울어짐 애니메이션
    4. 충돌 쿨다운 설정
    5. 넉백 적용 (인텐시티 기반)
    """

    boss_collision_rect = BOSS.inflate(10, 10)  # 5px 확장 히트박스

    if (BALL.colliderect(boss_collision_rect)
        and ball_vel[1] < 0
        and boss_collision_cooldown <= 0
        and not is_waiting_for_serve):

        calculate_bounce(BOSS)

        # 보스 게이지 충전 (스테이지별 상이)
        boss_special_gauge += GAUGE_PER_HIT

        # 충돌 쿨다운 설정 (10프레임 = ~0.17초)
        boss_collision_cooldown = 10

        # 위치 보정 (공이 패들 안으로 파고드는 것 방지)
        BALL.top = BOSS.bottom + 1

        # 넉백 적용
        apply_paddle_hit_knockback_boss(ball_x=BALL.centerx)

        # last_hit_by 업데이트
        last_hit_by = "boss"


# =============================================================================
# PART 8: 플레이어 패들 충돌 (이중 체크 시스템)
# =============================================================================

def _handle_player_paddle_collision():
    """플레이어 패들 충돌 (handle_player에서 1차 처리)

    handle_player()에서 매 프레임 키 입력과 함께 충돌을 1차 처리.
    여기서 처리되면 player_collision_handled = True로 설정.

    조건:
    - BALL.colliderect(플레이어 확장 히트박스)
    - player_collision_cooldown <= 0
    - ball_vel[1] > 0 (공이 아래로 가는 중) 또는 하프대쉬 활성
    """
    player_collision_rect = PLAYER.inflate(10, 10)

    if (BALL.colliderect(player_collision_rect)
        and player_collision_cooldown <= 0
        and not player_collision_handled
        and not is_waiting_for_serve):

        calculate_bounce(PLAYER)

        player_collision_handled = True
        player_collision_cooldown = 8  # 8프레임 쿨다운
        BALL.bottom = PLAYER.top - 1

        # 플레이어 게이지 충전 (캐릭터별 상이)
        _charge_player_gauge()

        # 넉백 적용
        apply_paddle_hit_knockback_player(ball_x=BALL.centerx)

        last_hit_by = "player"


def _handle_player_paddle_collision_backup():
    """플레이어 패들 충돌 백업 (handle_ball에서 2차 처리)

    handle_player에서 놓친 충돌을 handle_ball에서 한 번 더 체크.
    이중 체크로 충돌 누락 방지.

    조건: player_collision_handled == False일 때만 실행
    """
    if player_collision_handled:
        return  # 이미 처리됨

    if (BALL.colliderect(player_collision_rect)
        and player_collision_cooldown <= 0
        and not is_waiting_for_serve
        and not ball_in_kuromi):  # 쿠로미가 삼킨 상태 아닐 때

        # handle_player에서와 동일한 처리
        calculate_bounce(PLAYER)
        last_hit_by = "player"
        player_collision_cooldown = 8


# =============================================================================
# PART 9: 득점 판정
# =============================================================================

def _handle_scoring():
    """공이 화면 상단/하단으로 벗어나면 득점 처리

    상단 탈출 (BALL.bottom < 0) → 플레이어 득점
    하단 탈출 (BALL.top > HEIGHT) → 보스 득점

    예외:
    - 오딘의 눈 부활: 플레이어 실점 시 30% 확률로 부활 (공 반사)
    - 네메시스 방어막: 득점 직전 방어막이 공을 반사
    - 스테이지 6: 체력형 보스 → 체력 1 감소
    - 투기장 모드: 뼈장막 안전망 (득점 전 추가 충돌 체크)
    """

    # --- 상단 탈출: 플레이어 득점 ---
    if BALL.bottom < 0:
        # 스테이지 6 (네메시스): 체력형 보스
        if current_stage == 6 and boss_current_health > 0:
            boss_current_health -= 1
            if boss_current_health <= 0:
                round_wins += 1  # 체력 0이면 라운드 승리
            reset_ball_position()
            return

        round_wins += 1
        _handle_player_score_effects()
        go_to_next_round()

    # --- 하단 탈출: 보스 득점 ---
    elif BALL.top > HEIGHT:
        # 오딘의 눈 부활 체크
        if odins_eye_active and random.random() < odins_eye_revival_chance:
            # 부활! 공을 위로 반사
            BALL.bottom = HEIGHT - 10
            ball_vel[1] = -abs(ball_vel[1])
            odins_eye_revival_anim_active = True
            return  # 실점 무효

        round_losses += 1
        _handle_boss_score_effects()
        go_to_next_round()


# =============================================================================
# PART 10: 스테이지별 특수 충돌
# =============================================================================

def _handle_stage_specific_collisions():
    """스테이지별 특수 오브젝트 충돌 (요약)"""

    # --- Stage 1: 상모돌리기 충돌 ---
    # 회전하는 상모에 공이 닿으면 반사 + 속도 증가
    if whip_active:
        whip_rect = _get_whip_collision_rect()
        if BALL.colliderect(whip_rect):
            _reflect_ball_from_whip()

    # --- Stage 2: 지진 이벤트 ---
    # 지진 중 공 궤적에 랜덤 요동 추가

    # --- Stage 5: 화염탄 충돌 ---
    for fireball in fireballs:
        fireball_rect = pygame.Rect(fireball[0] - 8, fireball[1] - 8, 16, 16)
        if fireball_rect.colliderect(PLAYER):
            # 연막 속이면 면역, 아니면 스턴 + 넉백
            if is_player_in_smoke():
                continue  # 피해 없이 화염탄 제거
            else:
                try_apply_player_stun(0.3, source="stage5_fireball")
                player_knockback_vel = random.choice([-12, 12])

    # --- Stage 7: 테트로미노 블럭 충돌 ---
    # 공이 테트로미노 셀에 충돌하면 반사 + 블럭 파괴
    for cell in tetromino_cells:
        if BALL.colliderect(cell["rect"]):
            # 충돌 방향 판정 (상하/좌우)
            dx = BALL.centerx - cell["rect"].centerx
            dy = BALL.centery - cell["rect"].centery
            if abs(dx) > abs(dy):
                ball_vel[0] *= -1  # 좌우 충돌
            else:
                ball_vel[1] *= -1  # 상하 충돌
            cell["hp"] -= 1

    # --- Stage 8: 그림자분신 / 표창 ---
    # 분신이 공을 반사, 표창이 플레이어에게 스턴

    # --- 모래 장애물 충돌 ---
    if sand_obstacles:
        check_sand_ball_collision(sand_obstacles, BALL, ball_vel)


# =============================================================================
# 요약: 충돌 시스템 특성
# =============================================================================
"""
| 항목                | 구현 방식                                      |
|---------------------|------------------------------------------------|
| 충돌 감지           | pygame.Rect.colliderect() (AABB)              |
| 히트박스 확장       | Rect.inflate(10, 10) = 5px 패딩               |
| 중복 충돌 방지      | 쿨다운 타이머 (8~10프레임) + handled 플래그    |
| 이중 체크           | handle_player(1차) + handle_ball(백업)          |
| 반사 각도           | 패들 위 충돌 위치 기반 (-1~1) × 60도           |
| 속도 부스트         | 각도 기반 (200~280%) + 공속도 역비례 감소      |
| 벽 감속             | 5% 감속 (0.95 배율) + 관성 보존 보너스         |
| 넉백                | 인텐시티 레벨 기반 (150~550% 스케일)           |
| 무승부 판정         | 벽 왕복 8회 + 5초 무패들 / 수평 바운스 6회     |
| 득점 예외           | 오딘 부활, 네메시스 방어막, 뼈장막 안전망      |
| 터널링 방지         | 확장 히트박스 + 위치 보정 (BALL.bottom = top-1)|
| 스킬 연동           | 드라이브, 파워스매싱, 라그나로크, 포세이돈     |
| 캐릭터별 차이       | 히트박스 확장(발토르 우산), 게이지 충전량 차이 |
"""
