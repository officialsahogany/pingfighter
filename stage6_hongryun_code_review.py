"""
=============================================================================
PingFighter (핑파이터) - Stage 6 홍련 (Chinese Fire): Code Review Document
=============================================================================

이 파일은 실제 게임에서 사용 중인 스테이지 6 홍련 관련 코드를 코드리뷰용으로 정리한 것입니다.
실행용이 아닌 리뷰/참고용 문서입니다.

주의: 역사적 이유로 코드 변수명과 실제 스테이지 번호가 뒤바뀌어 있음!
- 코드에서 stage5 / animated_bg_stage5 = 실제 스테이지 6 홍련 (Chinese Fire)
- 코드에서 stage6 / animated_bg_stage6 = 실제 스테이지 5 네메시스 (Ocean)

스테이지 개요:
- 테마: 중국 전통시장 + 화염
- 보스: 홍련 (Hongryun) - 화염 기반 보스
- 특수 스킬: 카오스볼 → 홍련폭염 (화염 용 궤적)
- 필러 배경: 어두운 마룬/크림슨 톤, 뱀 화염탄 발사
- 이벤트: 10~20초마다 바닥에서 용 기계 등장 → 화염 지대 생성
=============================================================================
"""

# =============================================================================
# PART 1: 파일 구조 및 역할
# =============================================================================
"""
홍련 관련 파일 15개+:

| 파일 | 역할 |
|------|------|
| config/stage_configs.py | BOSS_CONFIGS[5] - 홍련 보스 스펙 |
| ui/stage5_chinese_market.py | 중국 전통시장 UI (화염 이펙트, 제3의 눈, 등롱) |
| backgrounds/animated_background_stage5.py | 배경 애니메이션 (매화, 화염 파티클) |
| pillar_hongryeon.py | 필러 배경 + 뱀 화염탄 시스템 |
| events/stage5_fire_machine_event.py | 용 기계 이벤트 (화염 지대 생성) |
| events/stage5_event_integration.py | 이벤트 타이머 관리 (10~20초 간격) |
| pingfighter.py | 홍련폭염 스킬, 화염탄, 게이지, 렌더링 |
"""


# =============================================================================
# PART 2: 보스 설정 (config/stage_configs.py)
# =============================================================================

BOSS_CONFIGS_STAGE5 = {
    "name": "홍련",
    "color": (255, 80, 0),        # 밝은 주황 (화염)
    "accel": 0.973,
    "decel": 0.973,
    "max_speed": 7.571,            # 스테이지 중 두 번째로 빠름
    "instant_stop": 0.859,
    "predict_distance": 130,
    "skill_power": 0.2,
    "fail_error": 245,
    "special_skill": "chaos_ball",  # 카오스볼 → 홍련폭염
    "dash_cooldown_range": (32.0, 46.0),
    "dash_enabled": True,
    "dash_max_distance": 336,
}


# =============================================================================
# PART 3: 홍련폭염 (카오스볼) 스킬 시스템
# =============================================================================

# --- 전역 변수 ---
hongryun_hit_count = 0    # 현재 구슬 게이지 (화염탄이 플레이어에 맞을 때 +1)
hongryun_ready = False     # 게이지 꽉 참 → 보스 패들 히트 시 발동
HONGRYUN_MAX_HITS = 5      # 최대 구슬 수 (5개 모이면 발동 가능)

flame_trail_active = False   # 홍련폭염 활성 상태
flame_trail_timer = 0        # 지속 시간 타이머 (2초 = 120프레임)
flame_trail_phase = 0
flame_trail_positions = []   # 공 궤적 [(x, y)] - 용 몸체 렌더링용
flame_trail_rng = None       # 전용 난수 발생기 (예측 일관성 보장)


def _hongryun_gauge_system():
    """홍련폭염 게이지 시스템

    충전 방식: 화염탄이 플레이어에 맞을 때마다 hongryun_hit_count += 1
    발동 조건: hongryun_hit_count >= HONGRYUN_MAX_HITS (5) 이고 보스가 공을 칠 때
    지속 시간: 2초 (TWO_SECONDS_FRAMES = 120프레임)

    게이지 감소 메커니즘:
    - 플라즈마 구체(아이템): 프레임당 0.5씩 구슬 게이지 감소
    - 라운드 전환: hongryun_hit_count -= 1 (1구슬씩 감소)
    """

    # 보스 패들에 공이 맞았을 때 (pingfighter.py:149922)
    if current_stage == 5 and hongryun_ready:
        flame_trail_active = True
        flame_trail_timer = 120  # 2초
        flame_trail_phase = 0
        flame_trail_rng = random.Random(random.randrange(1 << 30))
        flame_trail_positions.clear()
        show_hongryun_explosion()  # 화면 전체 붉은빛 플래시 연출
        hongryun_ready = False
        hongryun_hit_count = 0    # 게이지 초기화


def show_hongryun_explosion():
    """홍련폭염 발동 시 화면 연출

    1. 붉은빛 오버레이 페이드인 (0→200 알파, 10단계)
    2. "홍련폭염!!" 텍스트 표시
    3. 붉은빛 페이드아웃 (200→0)
    """
    overlay = pygame.Surface((WIDTH, HEIGHT))
    overlay.fill((255, 60, 30))
    for alpha in range(0, 200, 20):      # 페이드인
        overlay.set_alpha(alpha)
        SCREEN.blit(overlay, (0, 0))
        pygame.display.flip()
        pygame.time.delay(16)            # ~1프레임
    show_fade_text("홍련폭염!!")
    for alpha in range(200, 0, -20):     # 페이드아웃
        overlay.set_alpha(alpha)
        SCREEN.blit(overlay, (0, 0))
        pygame.display.flip()
        pygame.time.delay(16)


# =============================================================================
# PART 4: 화염 용 궤적 렌더링 (홍련폭염 비주얼)
# =============================================================================

def _draw_flame_dragon():
    """홍련폭염 활성 시 공을 따라다니는 화염 용 렌더링

    공의 궤적(flame_trail_positions)을 따라 용의 몸체를 그림.
    매 프레임 공 위치를 리스트에 추가하고, 리스트를 순회하며 용 파츠를 렌더링.

    용 구조:
    - 꼬리(리스트 시작): 가늘고 어두운 붉은색 (두께 3px)
    - 몸체(중간): 점점 굵어짐 + 비늘 효과 + 6방향 화염
    - 머리(리스트 끝 = 공 위치): 원형 + 눈(빛나는) + 뿔 + 화염 숨결
    """
    if not flame_trail_active:
        return
    if len(flame_trail_positions) <= 2:
        return

    time_now = pygame.time.get_ticks()

    for i in range(len(flame_trail_positions) - 1):
        x1, y1 = flame_trail_positions[i]
        x2, y2 = flame_trail_positions[i + 1]

        # 위치 비율 (0=꼬리, 1=머리)
        progress = i / max(1, len(flame_trail_positions) - 1)

        # 소용돌이 효과 (사인/코사인파)
        wave_offset = math.sin(time_now * 0.01 + i * 0.5) * 10
        spiral_offset = math.cos(time_now * 0.008 + i * 0.3) * 8

        # 용 몸체 두께 (꼬리 3px → 머리 15px)
        thickness = int(3 + progress * 12)

        # 색상 그라데이션 (꼬리: 어두운 붉은색 → 머리: 밝은 주황)
        r = int(150 + progress * 105)
        g = int(20 + progress * 100)
        b = int(10 + progress * 20)
        body_color = (min(255, r), min(255, g), min(255, b))

        center_x = x1 + wave_offset
        center_y = y1 + spiral_offset

        # 몸체 메인
        pygame.draw.circle(screen, body_color, (int(center_x), int(center_y)), thickness)

        # 비늘 효과 (3프레임마다)
        if i % 3 == 0:
            scale_color = (min(255, r + 50), min(255, g + 30), b)
            pygame.draw.circle(screen, scale_color,
                             (int(center_x + thickness/2), int(center_y)), max(2, thickness//3))

        # 화염 외곽 (몸체 중간부터)
        if progress > 0.3:
            for angle in range(0, 360, 60):  # 6방향
                flame_x = center_x + math.cos(math.radians(angle + time_now * 0.5)) * (thickness + 4)
                flame_y = center_y + math.sin(math.radians(angle + time_now * 0.5)) * (thickness + 4)
                flame_size = max(1, int(2 + progress * 3))
                pygame.draw.circle(screen, (255, 200, 100), (int(flame_x), int(flame_y)), flame_size)

    # === 용 머리 (공 위치) ===
    if flame_trail_positions:
        head_x, head_y = flame_trail_positions[-1]
        pygame.draw.circle(screen, (255, 150, 50), (int(head_x), int(head_y)), 15)
        pygame.draw.circle(screen, (255, 200, 100), (int(head_x), int(head_y)), 10)

        # 빛나는 눈
        eye_glow = int(abs(math.sin(time_now * 0.01)) * 100 + 155)
        pygame.draw.circle(screen, (eye_glow, eye_glow, 0), (int(head_x - 5), int(head_y - 3)), 3)
        pygame.draw.circle(screen, (eye_glow, eye_glow, 0), (int(head_x + 5), int(head_y - 3)), 3)

        # 뿔
        pygame.draw.line(screen, (200, 50, 50),
                        (int(head_x - 8), int(head_y - 10)), (int(head_x - 12), int(head_y - 18)), 3)
        pygame.draw.line(screen, (200, 50, 50),
                        (int(head_x + 8), int(head_y - 10)), (int(head_x + 12), int(head_y - 18)), 3)

        # 화염 숨결 (60% 확률)
        if random.random() < 0.6:
            for _ in range(5):
                breath_angle = math.radians(random.randint(160, 200))  # 아래쪽
                breath_dist = random.randint(10, 25)
                breath_x = head_x + math.cos(breath_angle) * breath_dist
                breath_y = head_y + math.sin(breath_angle) * breath_dist
                pygame.draw.circle(screen, (255, random.randint(100, 200), 0),
                                 (int(breath_x), int(breath_y)), random.randint(2, 4))


# =============================================================================
# PART 5: 화염탄 시스템
# =============================================================================

def _fireball_system():
    """보스가 발사하는 화염탄 (스테이지 5 전용)

    발동 조건: 쿨타임 3.5~5초 + 라운드 시작 2.5초 후
    발사 개수: 1~3개 (40% 확률로 2~3개)
    속도: fireball_speed (상수)
    방향: 보스 → 플레이어 방향 + ±20도 랜덤 오프셋

    충돌 효과:
    - 플레이어 히트: 0.3초 스턴 + 랜덤 넉백(±12) + 폭발 이펙트
    - 연막 속: 면역 (피해 없이 화염탄 제거)
    - 게이지 충전: hongryun_hit_count += 1 (폭염 게이지)
    """
    now = pygame.time.get_ticks()

    # 발사
    if now - fireball_last_cast > fireball_cooldown and not is_waiting_for_serve:
        fireball_last_cast = now
        fireball_cooldown = random.randint(3500, 5000)
        num_fireballs = random.randint(2, 3) if random.random() < 0.4 else 1

        play_sound_with_volume(SOUND_FIREBALL)
        for i in range(num_fireballs):
            pos = [BOSS.centerx, BOSS.bottom]
            offset_angle = random.uniform(-20, 20)
            dir_vec = pygame.math.Vector2(
                PLAYER.centerx - BOSS.centerx,
                PLAYER.centery - BOSS.centery
            ).normalize().rotate(offset_angle)
            vel = [dir_vec.x * fireball_speed, dir_vec.y * fireball_speed]
            fireballs.append([pos, vel])

    # 이동 + 충돌
    for pos, vel in fireballs:
        pos[0] += vel[0]
        pos[1] += vel[1]
        fireball_rect = pygame.Rect(pos[0]-8, pos[1]-8, 16, 16)

        if fireball_rect.colliderect(PLAYER):
            if is_player_in_smoke():
                continue  # 연막 면역
            else:
                try_apply_player_stun(0.3, source="stage5_fireball")
                player_knockback_vel = random.choice([-12, 12])
                hongryun_hit_count += 1  # 폭염 게이지 충전
                if hongryun_hit_count >= HONGRYUN_MAX_HITS:
                    hongryun_ready = True


# =============================================================================
# PART 6: 필러 뱀 화염탄 시스템 (pillar_hongryeon.py)
# =============================================================================

class PillarFireball:
    """필러 영역에서 게임 영역으로 이동하는 화염탄

    뱀이 발사 → 필러 내에서 시작 → 게임 영역 경계에 도달하면
    실제 게임 화염탄으로 변환 (fire_callback 호출).

    특징:
    - Surface 재사용 풀로 매 프레임 Surface 생성 방지
    - 내부 좌표계 ↔ 실제 스크린 좌표계 변환
    - 광폭화 시 뱀 2마리 (좌우 필러 각각)

    시각 효과:
    - core: 밝은 중심 (255, 255, 200)
    - inner: 주황 내부 (255, 180, 50)
    - outer: 빨간 외부 (255, 80, 30)
    - trail: 잔상 (200, 50, 20)
    """
    pass


# Surface 재사용 풀 (모듈 레벨)
_hongryeon_surface_pool = {}

def _get_pooled_surface(w, h):
    """재사용 가능한 SRCALPHA Surface 반환 (매 프레임 생성 방지)"""
    key = (w, h)
    if key not in _hongryeon_surface_pool:
        _hongryeon_surface_pool[key] = pygame.Surface((w, h), pygame.SRCALPHA)
    surf = _hongryeon_surface_pool[key]
    surf.fill((0, 0, 0, 0))  # 투명으로 초기화 후 반환
    return surf


# =============================================================================
# PART 7: 화염 기계 이벤트 (events/stage5_fire_machine_event.py)
# =============================================================================

class Stage5FireMachineEvent:
    """바닥에서 용 기계가 올라와 화염을 방사하는 이벤트

    상태 머신 (Phase):
    idle → door_opening → door_open_wait → machine_rising → machine_rise_wait
    → spraying → spraying_wait → machine_lowering → machine_lower_wait → door_closing → idle

    타이밍 (60fps 기준):
    | Phase | 프레임 | 시간 |
    |-------|--------|------|
    | 문 열림 | 60 | 1초 |
    | 대기 | 30 | 0.5초 |
    | 기계 상승 | 90 | 1.5초 |
    | 대기 | 90 | 1.5초 |
    | 화염 방사 | 120 | 2초 |
    | 대기 | 60 | 1초 |
    | 기계 하강 | 90 | 1.5초 |
    | 대기 | 30 | 0.5초 |
    | 문 닫힘 | 60 | 1초 |

    화염 지대:
    - 크기: 80x32px (화염병과 동일)
    - 지속: 2.5초 (150프레임)
    - 최대 동시: 1개 (광폭화 시 2개)
    - 효과: 대쉬로만 통과 가능 (화염병과 동일)

    광폭화 모드:
    - 용 머리 1개 → 2개
    - 화염 지대 최대 1개 → 2개
    """
    pass


# =============================================================================
# PART 8: 이벤트 타이머 관리 (events/stage5_event_integration.py)
# =============================================================================

class Stage5EventManager:
    """스테이지 5 이벤트 자동 트리거 시스템

    10~20초 간격으로 화염 기계 이벤트를 자동 발동.
    타이머는 스테이지 5 진입 시 시작.

    구조:
    - start_timer(): 스테이지 진입 시 1회 호출
    - check_timer_event(): 매 프레임 호출, 타이머 만료 시 True 반환
    - check_events(): 타이머 기반 체크 (외부 인터페이스)
    - check_events_deuce(): 듀스 모드에서도 동일하게 동작
    """

    MIN_INTERVAL = 600    # 10초 (60fps × 10)
    MAX_INTERVAL = 1200   # 20초 (60fps × 20)

    def check_timer_event(self, current_stage):
        if not self.timer_active or current_stage != 5:
            return False
        if self.event_timer <= 0:
            if self.fire_machine.should_trigger(current_stage):
                self.event_timer = random.randint(self.MIN_INTERVAL, self.MAX_INTERVAL)
                return True
        return False


# =============================================================================
# PART 9: 중국 전통시장 UI (ui/stage5_chinese_market.py)
# =============================================================================

class Stage5ChineseMarket:
    """중국 전통시장 + 화염 테마 UI 관리

    색상 팔레트:
    - CHINA_RED: (220, 38, 38) - 중국 붉은색
    - GOLD: (255, 215, 0) - 금색
    - DARK_RED: (139, 0, 0) - 진한 붉은색
    - FIRE_GRADIENT: [(255,0,0), (255,100,0), (255,200,0), (255,255,100)]

    주요 시스템:
    1. 불타는 스타디움 라인: 맥동하는 화염 파티클
    2. 불꽃탄 충돌 이펙트: impact_fire_zones (충돌 지점 화염)
    3. 홍련꽃 홀로그램: 나선 회전 효과 (화염탄 발사 시 트리거)
    4. 제3의 눈 애니메이션: 홍련폭염 발동 시 보스 이마에 눈 열림
    5. 영적 고리 (Spiritual Rings): 제3의 눈 발동 시 생성
    6. 인페르노 모드: 홍련폭염 활성 시 배경 강화 효과

    성능 최적화:
    - _glow_cache: 화염 글로우 서피스 캐시 (key: size, color, alpha)
    """

    def trigger_spiral_burst(self, inferno=False):
        """화염탄 발사 시 나선 회전 효과 트리거"""
        self.spiral_burst_timer = self.spiral_burst_max_timer  # 1.3초
        self.spiral_burst_intensity = 1.0
        if inferno:
            self.spiral_burst_max_timer = 1800  # 인페르노 시 더 길게

    def set_inferno_mode(self, active):
        """홍련폭염 활성/비활성 시 배경 모드 전환"""
        self.is_inferno_mode = active
        if active:
            self.third_eye_opening = 0  # 제3의 눈 열기 시작


# =============================================================================
# PART 10: 홍련 면역 시스템 (특수 상호작용)
# =============================================================================

def _hongryun_immunities():
    """홍련은 자신의 화염에 면역

    pingfighter.py에서 화염병(Molotov) 효과 적용 시:
    - current_stage == 5이면 화재 효과 스킵
    - 속도 감소 없음
    - 넉백 없음
    - 화염 지대 피해 없음

    이유: 홍련이 화염 테마 보스이므로 자기 속성에 면역
    """
    if current_stage == 5:
        return  # 화재 효과 전부 면역


# =============================================================================
# PART 11: 게이지 감소 메커니즘
# =============================================================================

def _hongryun_gauge_decay():
    """홍련 구슬 게이지가 줄어드는 상황들

    1. 플라즈마 구체 아이템 (프레임당):
       - plasma_gauge_drain_accumulator += 0.5
       - hongryun_hit_count = max(0, hongryun_hit_count - drained)
       - 초당 약 30 게이지 감소

    2. 라운드 전환 시:
       - hongryun_hit_count = max(0, hongryun_hit_count - 1)
       - 1구슬씩 감소 (전부 리셋이 아님)

    3. 홍련폭염 발동 시:
       - hongryun_hit_count = 0 (완전 초기화)
       - hongryun_ready = False
    """
    pass


# =============================================================================
# 요약: 홍련 시스템 구성
# =============================================================================
"""
| 시스템 | 파일 | 핵심 로직 |
|--------|------|-----------|
| 보스 스펙 | config/stage_configs.py | max_speed=7.571, dash_enabled=True |
| 구슬 게이지 | pingfighter.py | 화염탄 히트 5회 → 폭염 발동 가능 |
| 홍련폭염 스킬 | pingfighter.py | 보스 패들 히트 시 발동, 2초 지속 |
| 화염 용 렌더링 | pingfighter.py:115285 | 공 궤적 따라 용 몸체/머리/화염 |
| 화염탄 발사 | pingfighter.py | 3.5~5초 쿨타임, 1~3발, 스턴+넉백 |
| 필러 뱀 | pillar_hongryeon.py | 필러→게임영역 화염탄 변환 |
| 용 기계 이벤트 | stage5_fire_machine_event.py | 10단계 상태머신, 화염 지대 생성 |
| 이벤트 타이머 | stage5_event_integration.py | 10~20초 랜덤 간격 |
| UI 이펙트 | stage5_chinese_market.py | 나선 효과, 제3의 눈, 인페르노 모드 |
| 면역 시스템 | pingfighter.py | 홍련은 화재 효과 면역 |
| 게이지 감소 | pingfighter.py | 플라즈마/라운드 전환/발동 시 감소 |

홍련 스킬 발동 체인:
화염탄 히트×5 → hongryun_ready=True → 보스 패들에 공 맞음
→ flame_trail_active=True → show_hongryun_explosion() 연출
→ 2초간 공 궤적을 따라 화염 용 렌더링 → 타이머 종료 → 비활성화

변수명 주의사항:
- 코드에서 current_stage == 5 → 실제 게임의 스테이지 6 (홍련)
- 코드에서 stage5_events → 실제 스테이지 6의 이벤트
- 코드에서 animated_bg_stage5 → 실제 스테이지 6의 배경
"""
