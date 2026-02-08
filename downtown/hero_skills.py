# downtown/hero_skills.py
# 투기장 영웅 스킬 시스템

import pygame
import math
import random
from enum import Enum
from typing import Dict, List, Optional, Tuple, Callable

# 날씨 강풍 이벤트 임포트
try:
    from events.weather_event import force_start_gust_event, force_end_weather_event, play_weather_sound, stop_weather_sound
    WEATHER_EVENT_AVAILABLE = True
except ImportError:
    WEATHER_EVENT_AVAILABLE = False

# 영웅 패들 렌더러 임포트 (그림자분신용)
try:
    from downtown.hero_paddles import HeroPaddleRenderer
    _shadow_clone_renderer = None
    def get_shadow_clone_renderer():
        global _shadow_clone_renderer
        if _shadow_clone_renderer is None:
            _shadow_clone_renderer = HeroPaddleRenderer()
        return _shadow_clone_renderer
    HERO_PADDLE_RENDERER_AVAILABLE = True
except ImportError:
    HERO_PADDLE_RENDERER_AVAILABLE = False
    def get_shadow_clone_renderer():
        return None

# 스킬 시스템 사용 가능 플래그
HERO_SKILLS_AVAILABLE = True

# ============================================================================
# 스킬 발동 조건
# ============================================================================
class SkillTrigger(Enum):
    ON_BALL_HIT = "on_ball_hit"      # 공을 칠 때 발동
    ON_COOLDOWN = "on_cooldown"      # 쿨타임 완료 시 자동 발동
    PASSIVE = "passive"              # 항상 적용되는 패시브


# ============================================================================
# 상태 이상 타입
# ============================================================================
class StatusEffect(Enum):
    STUN = "stun"                    # 스턴 (이동 불가)
    SLOW = "slow"                    # 둔화 (이동 속도 감소)
    CONFUSION = "confusion"          # 혼란 (조작 반전)
    BLIND = "blind"                  # 실명 (시야 제한)
    SHRINK = "shrink"               # 축소 (패들 크기 감소)
    KNOCKBACK = "knockback"          # 넉백 (강제 이동)
    PUPPET = "puppet"                # 조종 (상대가 내 패들 제어)


# ============================================================================
# 화면 효과 타입
# ============================================================================
class ScreenEffect(Enum):
    SHAKE = "shake"                  # 화면 흔들림
    FLASH = "flash"                  # 화면 번쩍임
    COLOR_OVERLAY = "color_overlay"  # 색상 오버레이
    DARKNESS = "darkness"            # 어둠 효과
    INK = "ink"                      # 먹물 효과
    FIRE = "fire"                    # 불꽃 효과
    TIME_STOP = "time_stop"          # 시간 정지 효과
    WIND = "wind"                    # 바람 효과


# ============================================================================
# 스킬 기본 클래스
# ============================================================================
class HeroSkill:
    def __init__(self,
                 skill_id: str,
                 name: str,
                 korean_name: str,
                 description: str,
                 trigger: SkillTrigger,
                 cooldown: float,
                 duration: float = 0,
                 hero_id: str = ""):
        self.skill_id = skill_id
        self.name = name
        self.korean_name = korean_name
        self.description = description
        self.trigger = trigger
        self.cooldown = cooldown          # 쿨타임 (초)
        self.duration = duration          # 효과 지속시간 (초)
        self.hero_id = hero_id

        # 런타임 상태
        self.current_cooldown = 0.0       # 현재 남은 쿨타임
        self.is_active = False            # 효과 활성화 중
        self.active_timer = 0.0           # 효과 남은 시간
        self.effect_data = {}             # 효과별 추가 데이터

    def can_use(self) -> bool:
        """스킬 사용 가능 여부"""
        return self.current_cooldown <= 0 and not self.is_active

    def use(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        """스킬 사용 (오버라이드 필요)"""
        if not self.can_use():
            return {}

        self.current_cooldown = self.cooldown
        if self.duration > 0:
            self.is_active = True
            self.active_timer = self.duration

        return self._apply_effect(caster_paddle, target_paddle, ball, game_state)

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        """실제 효과 적용 (서브클래스에서 오버라이드)"""
        return {}

    def update(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        """스킬 업데이트"""
        # 쿨타임 감소
        if self.current_cooldown > 0:
            self.current_cooldown -= dt

        # 활성 효과 업데이트
        if self.is_active:
            self.active_timer -= dt
            self._update_active_effect(dt, caster_paddle, target_paddle, ball, game_state)
            if self.active_timer <= 0:
                self._end_effect(caster_paddle, target_paddle, ball, game_state)
                self.is_active = False

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        """활성 효과 업데이트 (서브클래스에서 오버라이드)"""
        pass

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        """효과 종료 처리 (서브클래스에서 오버라이드)"""
        pass

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        """스킬 시각 효과 그리기 (서브클래스에서 오버라이드)"""
        pass

    def reset(self):
        """스킬 상태 리셋"""
        self.current_cooldown = 0.0
        self.is_active = False
        self.active_timer = 0.0
        self.effect_data = {}

    def reset_for_new_round(self, game_state: dict):
        """라운드 전환 시 스킬 강제 종료 및 상태 초기화
        서브클래스에서 오버라이드하여 추가 정리 작업 수행
        """
        if self.is_active:
            self.is_active = False
            self.active_timer = 0.0
            self.effect_data = {}


# ============================================================================
# 무겐 스킬 - 귀검사 (공격적)
# ============================================================================
class DarkSlash(HeroSkill):
    """달빛 베기 - 공을 사선으로 베어버리는 이펙트 + 1초 화면 정지 후 공 4배 가속"""

    # 페이즈 상수
    PHASE_NONE = 0        # 비활성
    PHASE_SLASH = 1       # 공 베기 이펙트 (0.1초)
    PHASE_FREEZE = 2      # 화면 정지 (1초)
    PHASE_RELEASE = 3     # 정지 해제 + 가속 적용
    PHASE_ACTIVE = 4      # 가속 상태 유지

    def __init__(self):
        super().__init__(
            skill_id="dark_slash",
            name="Dark Slash",
            korean_name="달빛 베기",
            description="공을 사선으로 베어 시간이 멈추고, 해제되는 순간 공이 4배 빨라진다",
            trigger=SkillTrigger.ON_BALL_HIT,
            cooldown=24.0,
            duration=2.5,
            hero_id="mugen"
        )
        # 페이즈 관리
        self.phase = self.PHASE_NONE
        self.phase_timer = 0.0

        # 슬래시 이펙트
        self.slash_progress = 0.0    # 베기 진행도 (0~1)
        self.slash_angle = 0         # 베기 각도 (라디안)
        self.slash_sparks = []       # 스파크 파티클
        self.slash_fragments = []    # 공이 갈라지는 조각 효과

        # 화면 정지
        self.freeze_duration = 1.0
        self.freeze_flash_timer = 0

        # 공 위치 (정지 중 표시용)
        self.ball_x = 0
        self.ball_y = 0

        # 공 속도 추적
        self.original_ball_speed = None
        self.original_ball_vx = 0
        self.original_ball_vy = 0
        self.dark_slash_active = False
        self.caster_is_top = False

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        # 원래 공 속도/방향 저장
        self.original_ball_speed = math.sqrt(ball.vx ** 2 + ball.vy ** 2)
        self.original_ball_vx = ball.vx
        self.original_ball_vy = ball.vy
        self.caster_is_top = caster_paddle.is_top

        # 공 위치 저장
        self.ball_x = ball.x
        self.ball_y = ball.y

        # 베기 각도 (대각선 - 우상향에서 좌하향으로)
        self.slash_angle = math.radians(-45)

        # === 페이즈 1: 베기 이펙트 시작 ===
        self.phase = self.PHASE_SLASH
        self.phase_timer = 0.0
        self.slash_progress = 0.0

        # 스파크 파티클 (베인 자리에서 튀는 불꽃)
        self.slash_sparks = []
        for _ in range(40):
            # 베기 라인을 따라 퍼지는 스파크
            spread_angle = self.slash_angle + random.uniform(-0.5, 0.5)
            speed = random.uniform(150, 500)
            offset = random.uniform(-30, 30)
            self.slash_sparks.append({
                'x': self.ball_x + math.cos(self.slash_angle + math.pi/2) * offset,
                'y': self.ball_y + math.sin(self.slash_angle + math.pi/2) * offset,
                'vx': math.cos(spread_angle + math.pi/2) * speed * random.choice([-1, 1]),
                'vy': math.sin(spread_angle + math.pi/2) * speed * random.choice([-1, 1]),
                'life': random.uniform(0.5, 1.5),
                'max_life': random.uniform(0.5, 1.5),
                'size': random.uniform(2, 5),
                'color': random.choice([
                    (255, 200, 255), (200, 100, 255), (150, 50, 200),
                    (255, 255, 200), (255, 150, 100)
                ])
            })

        # 공이 갈라지는 조각 효과
        self.slash_fragments = [
            {'offset_x': -8, 'offset_y': -8, 'target_x': -15, 'target_y': -12},  # 좌상단 조각
            {'offset_x': 8, 'offset_y': 8, 'target_x': 15, 'target_y': 12},      # 우하단 조각
        ]

        # 화면 정지 플래그 설정
        game_state['dark_slash_freeze'] = True
        game_state['dark_slash_phase'] = self.PHASE_SLASH
        return {
            'screen_effect': ScreenEffect.FLASH,
            'flash_color': (200, 100, 255),
            'flash_duration': 0.08,
            'sound': 'mooncut'
        }

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        self.phase_timer += dt

        if self.phase == self.PHASE_SLASH:
            # 베기 이펙트 진행 (0.1초)
            self.slash_progress = min(1.0, self.phase_timer / 0.1)

            # 베기 완료 → 화면 정지로
            if self.phase_timer >= 0.1:
                self.phase = self.PHASE_FREEZE
                self.phase_timer = 0.0
                game_state['dark_slash_phase'] = self.PHASE_FREEZE

        elif self.phase == self.PHASE_FREEZE:
            # 화면 정지 (1초)
            self.freeze_flash_timer += dt

            # 스파크 슬로우모션
            for spark in self.slash_sparks:
                spark['x'] += spark['vx'] * dt * 0.05
                spark['y'] += spark['vy'] * dt * 0.05
                spark['life'] -= dt * 0.2

            # 정지 해제
            if self.phase_timer >= self.freeze_duration:
                self.phase = self.PHASE_RELEASE
                self.phase_timer = 0.0
                game_state['dark_slash_freeze'] = False
                game_state['dark_slash_phase'] = self.PHASE_RELEASE

        elif self.phase == self.PHASE_RELEASE:
            # 정지 해제 - Y축 돌진 위주 가속 + 반격 (Y 방향 반전)
            # 수정: vx는 약하게, vy는 강하게 → 수직 돌진 후 커브로 꺾이는 느낌
            vy_boost = 4.5  # Y축 가속 (강함)
            vx_boost = 0.8  # X축 가속 (약함) - 벽 충돌 최소화

            # X축: 원래 방향 유지하되 약하게
            ball.vx = self.original_ball_vx * vx_boost

            # 무겐(상단)이 베면 아래로, 하단이면 위로 반격
            if self.caster_is_top:
                ball.vy = abs(self.original_ball_vy) * vy_boost  # 양수 = 아래로
            else:
                ball.vy = -abs(self.original_ball_vy) * vy_boost  # 음수 = 위로

            # 스매셔 드라이브처럼 굴곡있는 커브 효과 적용 (꺾이는 느낌)
            # 스핀 방향: 원래 vx 방향 기반 (약간 랜덤 변동)
            spin_direction = 1 if self.original_ball_vx >= 0 else -1
            if random.random() < 0.3:  # 30% 확률로 반대 방향
                spin_direction *= -1
            game_state['dark_slash_spin_strength'] = 2.2  # 더 강한 스핀으로 "꺾이는" 느낌 강화
            game_state['dark_slash_spin_direction'] = spin_direction


            self.dark_slash_active = True
            game_state['dark_slash_active'] = True
            game_state['dark_slash_caster_is_top'] = self.caster_is_top
            game_state['dark_slash_original_speed'] = self.original_ball_speed
            game_state['dark_slash_phase'] = self.PHASE_ACTIVE

            self.phase = self.PHASE_ACTIVE
            self.phase_timer = 0.0

        elif self.phase == self.PHASE_ACTIVE:
            # 스파크 정상 속도 업데이트
            for spark in self.slash_sparks:
                spark['x'] += spark['vx'] * dt
                spark['y'] += spark['vy'] * dt
                spark['life'] -= dt
            self.slash_sparks = [s for s in self.slash_sparks if s['life'] > 0]

    def on_opponent_hit(self, ball, game_state: dict):
        """상대 반격 시 원래 속도로 복귀"""
        if self.dark_slash_active and self.original_ball_speed is not None:
            current_speed = math.sqrt(ball.vx ** 2 + ball.vy ** 2)
            if current_speed > 0:
                ratio = self.original_ball_speed / current_speed
                ball.vx *= ratio
                ball.vy *= ratio

            self.dark_slash_active = False
            self.original_ball_speed = None
            game_state['dark_slash_active'] = False
            return True
        return False

    def reset(self):
        super().reset()
        self.phase = self.PHASE_NONE
        self.phase_timer = 0.0
        self.slash_sparks = []
        self.slash_fragments = []
        self.original_ball_speed = None
        self.dark_slash_active = False
        self.caster_is_top = False

    def reset_for_new_round(self, game_state: dict):
        """라운드 전환 시 달빛 베기 이펙트 초기화"""
        super().reset_for_new_round(game_state)
        self.phase = self.PHASE_NONE
        self.phase_timer = 0.0
        self.slash_sparks = []
        self.slash_fragments = []
        self.original_ball_speed = None
        self.dark_slash_active = False
        self.freeze_flash_timer = 0.0
        # game_state 플래그 초기화
        game_state['dark_slash_freeze'] = False
        game_state['dark_slash_active'] = False
        game_state['dark_slash_phase'] = self.PHASE_NONE

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        game_state['dark_slash_freeze'] = False
        game_state['dark_slash_phase'] = self.PHASE_NONE
        self.phase = self.PHASE_NONE

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        bx, by = int(self.ball_x), int(self.ball_y)

        # === 베기 & 정지 중 이펙트 ===
        if self.phase in [self.PHASE_SLASH, self.PHASE_FREEZE, self.PHASE_RELEASE]:

            # 어둠 오버레이 (정지 중)
            if self.phase == self.PHASE_FREEZE:
                darkness = pygame.Surface((760, 750), pygame.SRCALPHA)
                # 맥동하는 어둠
                pulse = 0.6 + 0.2 * math.sin(self.freeze_flash_timer * 8)
                darkness.fill((5, 0, 20, int(200 * pulse)))
                screen.blit(darkness, (0, 0))

            # === 공이 갈라지는 효과 ===
            if self.phase in [self.PHASE_FREEZE, self.PHASE_RELEASE]:
                for i, frag in enumerate(self.slash_fragments):
                    # 조각이 벌어지는 애니메이션
                    sep = min(1.0, self.phase_timer * 2) if self.phase == self.PHASE_FREEZE else 1.0
                    fx = bx + frag['offset_x'] + frag['target_x'] * sep
                    fy = by + frag['offset_y'] + frag['target_y'] * sep

                    # 반쪽 공 그리기 (반원)
                    half_surf = pygame.Surface((30, 30), pygame.SRCALPHA)
                    if i == 0:  # 좌상단 조각
                        pygame.draw.circle(half_surf, (255, 255, 255), (15, 15), 10)
                        pygame.draw.rect(half_surf, (0, 0, 0, 0), (15, 0, 15, 30))  # 우측 제거
                        pygame.draw.rect(half_surf, (0, 0, 0, 0), (0, 15, 30, 15))  # 하단 제거
                    else:  # 우하단 조각
                        pygame.draw.circle(half_surf, (255, 255, 255), (15, 15), 10)
                        pygame.draw.rect(half_surf, (0, 0, 0, 0), (0, 0, 15, 30))   # 좌측 제거
                        pygame.draw.rect(half_surf, (0, 0, 0, 0), (0, 0, 30, 15))   # 상단 제거

                    screen.blit(half_surf, (int(fx) - 15, int(fy) - 15))

            # === 베기 라인 (사선 칼날) ===
            if self.slash_progress > 0:
                # 베기 라인 길이
                slash_length = 200 * self.slash_progress

                # 시작점과 끝점 (대각선)
                start_x = bx - math.cos(self.slash_angle) * slash_length
                start_y = by - math.sin(self.slash_angle) * slash_length
                end_x = bx + math.cos(self.slash_angle) * slash_length
                end_y = by + math.sin(self.slash_angle) * slash_length

                # 글로우 레이어 (보라색/흰색)
                for glow in range(5):
                    glow_width = 12 - glow * 2
                    alpha = 200 - glow * 40
                    glow_surf = pygame.Surface((760, 750), pygame.SRCALPHA)

                    # 그라데이션 색상
                    if glow < 2:
                        color = (255, 255, 255, alpha)  # 중심은 흰색
                    else:
                        color = (180, 100, 255, alpha)  # 외곽은 보라색

                    pygame.draw.line(glow_surf, color,
                                   (start_x, start_y), (end_x, end_y), max(1, glow_width))
                    screen.blit(glow_surf, (0, 0), special_flags=pygame.BLEND_ADD)

                # 베기 끝부분 임팩트 이펙트
                if self.slash_progress > 0.5:
                    impact_size = int(20 * (1 - self.slash_progress) * 2)
                    if impact_size > 0:
                        impact_surf = pygame.Surface((impact_size * 2, impact_size * 2), pygame.SRCALPHA)
                        pygame.draw.circle(impact_surf, (255, 200, 255, 150),
                                         (impact_size, impact_size), impact_size)
                        screen.blit(impact_surf, (int(end_x) - impact_size, int(end_y) - impact_size),
                                   special_flags=pygame.BLEND_ADD)

            # === 정지 중 베기 자국 유지 ===
            if self.phase == self.PHASE_FREEZE:
                # 베기 자국 (지속)
                slash_length = 200
                start_x = bx - math.cos(self.slash_angle) * slash_length
                start_y = by - math.sin(self.slash_angle) * slash_length
                end_x = bx + math.cos(self.slash_angle) * slash_length
                end_y = by + math.sin(self.slash_angle) * slash_length

                # 잔상 글로우
                pulse = 0.7 + 0.3 * math.sin(self.freeze_flash_timer * 10)
                for glow in range(3):
                    glow_surf = pygame.Surface((760, 750), pygame.SRCALPHA)
                    alpha = max(0, min(255, int((120 - glow * 40) * pulse)))
                    pygame.draw.line(glow_surf, (200, 150, 255, alpha),
                                   (start_x, start_y), (end_x, end_y), 8 - glow * 2)
                    screen.blit(glow_surf, (0, 0), special_flags=pygame.BLEND_ADD)

        # === 스파크 파티클 ===
        for spark in self.slash_sparks:
            if spark['life'] > 0 and spark['max_life'] > 0:
                life_ratio = max(0, min(1, spark['life'] / spark['max_life']))
                alpha = max(0, min(255, int(255 * life_ratio)))
                size = max(1, int(spark['size'] * life_ratio))
                surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                pygame.draw.circle(surf, (*spark['color'][:3], alpha), (size, size), size)
                screen.blit(surf, (int(spark['x']) - size, int(spark['y']) - size),
                           special_flags=pygame.BLEND_ADD)

        # === 가속 중 공 이펙트 ===
        if self.dark_slash_active and self.phase == self.PHASE_ACTIVE:
            live_bx, live_by = int(ball.x), int(ball.y)

            # 검은 오라
            for r in range(3):
                glow_size = 18 + r * 10
                glow_surf = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (120, 50, 200, 70 - r * 20),
                                 (glow_size, glow_size), glow_size)
                screen.blit(glow_surf, (live_bx - glow_size, live_by - glow_size),
                           special_flags=pygame.BLEND_ADD)

            # 베기 자국이 공을 따라다님
            trail_length = 50
            for i in range(3):
                t = i * 0.02
                tx = live_bx - ball.vx * t
                ty = live_by - ball.vy * t
                alpha = 150 - i * 50
                pygame.draw.line(screen, (180, 100, 255),
                               (int(tx - 15), int(ty - 15)),
                               (int(tx + 15), int(ty + 15)), 2)


class DemonEye(HeroSkill):
    """귀신발걸음 - 상대 진영으로 전진 후 복귀하면 종료 + 이동속도 3배 + 패들 사이즈 20% 증가 + 오오라 이펙트"""
    def __init__(self):
        super().__init__(
            skill_id="demon_step",
            name="Ghost Step",
            korean_name="귀신발걸음",
            description="어둠의 기운을 두르고 상대 진영으로 전진 후 복귀하면 종료. 이동속도 3배, 패들 사이즈 20% 증가",
            trigger=SkillTrigger.ON_COOLDOWN,
            cooldown=25.0,
            duration=999.0,  # 시간 제한 없음 (왕복 완료 시 강제 종료)
            hero_id="mugen"
        )
        self.aura_timer = 0
        self.caster_is_top = False
        self.aura_particles = []  # 오오라 파티클

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        self.caster_is_top = caster_paddle.is_top
        self.aura_timer = 0

        # [DEBUG] 귀신발걸음 발동 시점 X좌표 확인
        _paddle_x = getattr(caster_paddle, 'x', 'N/A')
        _paddle_centerx = getattr(caster_paddle, 'centerx', 'N/A')
        # 이동속도 50% 증가 (1.5배)
        speed_key = 'top_paddle_speed_boost' if caster_paddle.is_top else 'bottom_paddle_speed_boost'
        game_state[speed_key] = 1.5  # 50% 증가 = 1.5배
        game_state['demon_eye_active'] = True
        game_state['demon_eye_caster_is_top'] = caster_paddle.is_top

        # 패들 사이즈 20% 증가
        size_key = 'top_paddle_size_boost' if caster_paddle.is_top else 'bottom_paddle_size_boost'
        game_state[size_key] = 1.2  # 20% 증가

        # 🔥 귀신발걸음 y축 이동 트리거 (game_state 플래그로 전달)
        # AIPaddleController는 직접 호출, PaddleWrapper는 플래그로 전달
        if hasattr(caster_paddle, 'start_ghost_step'):
            caster_paddle.start_ghost_step()
        else:
            # PaddleWrapper인 경우 game_state 플래그로 전달
            if caster_paddle.is_top:
                game_state['ghost_step_start_top'] = True
            else:
                game_state['ghost_step_start_bottom'] = True

        # 오오라 파티클 초기화
        self.aura_particles = []
        for _ in range(20):
            angle = random.uniform(0, math.pi * 2)
            self.aura_particles.append({
                'angle': angle,
                'radius': random.uniform(30, 50),
                'speed': random.uniform(1.5, 3.0),
                'size': random.uniform(3, 8),
                'alpha': random.randint(100, 200)
            })

        return {
            'screen_effect': ScreenEffect.FLASH,
            'flash_color': (150, 50, 200),
            'flash_duration': 0.15,
            'sound': 'ghostwalk'
        }

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        # 1회 왕복 완료로 인한 강제 종료 체크
        if game_state.get('ghost_step_force_end', False):
            game_state['ghost_step_force_end'] = False
            self.active_timer = 0  # 스킬 타이머 즉시 만료 → _end_effect 호출됨
            return

        self.aura_timer += dt

        # 오오라 파티클 업데이트 (회전)
        for p in self.aura_particles:
            p['angle'] += p['speed'] * dt
            # 반짝임 효과
            p['alpha'] = int(150 + 50 * math.sin(self.aura_timer * 5 + p['angle']))

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        # 이동속도 원래대로
        speed_key = 'top_paddle_speed_boost' if self.caster_is_top else 'bottom_paddle_speed_boost'
        game_state[speed_key] = 1.0
        # 패들 사이즈 원래대로
        size_key = 'top_paddle_size_boost' if self.caster_is_top else 'bottom_paddle_size_boost'
        game_state[size_key] = 1.0
        game_state['demon_eye_active'] = False
        self.aura_particles = []

    def reset_for_new_round(self, game_state: dict):
        """라운드 전환 시 귀신발걸음 이펙트 초기화"""
        super().reset_for_new_round(game_state)
        self.aura_timer = 0
        self.aura_particles = []
        # game_state 플래그 초기화
        game_state['top_paddle_speed_boost'] = 1.0
        game_state['bottom_paddle_speed_boost'] = 1.0
        game_state['top_paddle_size_boost'] = 1.0
        game_state['bottom_paddle_size_boost'] = 1.0
        game_state['demon_eye_active'] = False

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        if self.is_active:
            # 패들 중심 좌표
            paddle_cx = caster_paddle.centerx
            paddle_cy = caster_paddle.centery

            # === 오오라 이펙트 (패들 주변 회전하는 보라색 기운) ===
            pulse = 1 + 0.15 * math.sin(self.aura_timer * 6)

            # 외곽 글로우 (큰 원)
            glow_radius = int(60 * pulse)
            glow_surf = pygame.Surface((glow_radius * 2 + 20, glow_radius * 2 + 20), pygame.SRCALPHA)
            for r in range(glow_radius, 0, -3):
                alpha = int(80 * (r / glow_radius))
                pygame.draw.circle(glow_surf, (120, 30, 180, alpha),
                                 (glow_radius + 10, glow_radius + 10), r)
            screen.blit(glow_surf, (int(paddle_cx - glow_radius - 10),
                                   int(paddle_cy - glow_radius - 10)),
                       special_flags=pygame.BLEND_ADD)

            # 회전하는 오오라 파티클
            for p in self.aura_particles:
                px = paddle_cx + math.cos(p['angle']) * p['radius'] * pulse
                py = paddle_cy + math.sin(p['angle']) * p['radius'] * pulse

                # 파티클 글로우
                p_size = int(p['size'] * pulse)
                if p_size > 0:
                    p_surf = pygame.Surface((p_size * 4, p_size * 4), pygame.SRCALPHA)
                    p_alpha = min(255, max(0, p['alpha']))
                    pygame.draw.circle(p_surf, (180, 80, 255, p_alpha),
                                     (p_size * 2, p_size * 2), p_size * 2)
                    pygame.draw.circle(p_surf, (255, 150, 255, min(255, p_alpha + 50)),
                                     (p_size * 2, p_size * 2), p_size)
                    screen.blit(p_surf, (int(px - p_size * 2), int(py - p_size * 2)),
                               special_flags=pygame.BLEND_ADD)

            # 귀신 눈 이펙트 (패들 위/아래)
            eye_x = paddle_cx
            eye_y = paddle_cy + (35 if caster_paddle.is_top else -35)
            eye_pulse = 1 + 0.3 * math.sin(self.aura_timer * 8)

            # 눈 외곽 글로우
            eye_glow_size = int(20 * eye_pulse)
            eye_glow_surf = pygame.Surface((eye_glow_size * 2, eye_glow_size * 2), pygame.SRCALPHA)
            pygame.draw.circle(eye_glow_surf, (200, 50, 255, 120),
                             (eye_glow_size, eye_glow_size), eye_glow_size)
            screen.blit(eye_glow_surf, (int(eye_x - eye_glow_size), int(eye_y - eye_glow_size)),
                       special_flags=pygame.BLEND_ADD)

            # 눈동자
            pygame.draw.circle(screen, (180, 30, 220), (int(eye_x), int(eye_y)), int(10 * eye_pulse))
            pygame.draw.circle(screen, (255, 80, 80), (int(eye_x), int(eye_y)), int(4 * eye_pulse))


# ============================================================================
# 크라켄 스킬 - 심해의 포식자 (트릭형)
# ============================================================================
class TentacleWrap(HeroSkill):
    """촉수 휘감기 - 상대 패들 둔화 [고퀄리티 업그레이드]"""
    def __init__(self):
        super().__init__(
            skill_id="tentacle_wrap",
            name="Tentacle Wrap",
            korean_name="촉수 휘감기",
            description="촉수로 상대 패들을 휘감아 이동속도를 60% 감소시킨다",
            trigger=SkillTrigger.ON_COOLDOWN,
            cooldown=20.0,
            duration=4.0,  # 전체 스킬 지속시간 (이동 1초 + 둔화 3초)
            hero_id="kraken"
        )
        self.tentacles = []
        self.target_is_top = False
        self.caster_is_top = False
        self.phase = 'travel'  # 'travel' (이동 중) → 'wrap' (감싸는 중)
        self.travel_progress = 0  # 이동 진행도 (0~1)
        self.wrap_timer = 0  # 감싸기 지속 시간
        self.slow_applied = False  # 둔화 적용 여부
        self.slow_amount = 0.5  # 50% 감소 = 50%만 유지
        self.time = 0  # 애니메이션 시간

        # 색상 팔레트 (크라켄 hero_paddles.py와 동일)
        self.colors = {
            'tentacle_core': (30, 80, 100),       # 촉수 중심 (어두운 청록)
            'tentacle_mid': (40, 100, 120),       # 촉수 중간
            'tentacle_outer': (50, 120, 140),     # 촉수 외곽
            'tentacle_highlight': (70, 150, 170), # 촉수 하이라이트
            'sucker_base': (180, 140, 160),       # 빨판 베이스
            'sucker_inner': (140, 100, 120),      # 빨판 내부
            'sucker_highlight': (220, 180, 200),  # 빨판 하이라이트
            'biolum': (80, 255, 200),             # 생물 발광
            'biolum_soft': (60, 200, 160),        # 부드러운 발광
            'glow': (100, 200, 180),              # 글로우
            'slime': (100, 180, 150),             # 점액
        }

    def _get_hero_body_position(self, paddle, b=8):
        """영웅 이미지의 실제 몸통 위치 계산 (hero_paddles.py와 동기화)

        hero_paddles.py 기준:
        - 상단 영웅 (facing="down"): cy = y + 3.5*b, torso = cy - 1.5*b = y + 2*b
        - 하단 영웅 (facing="up"): cy = y + 2.0*b, torso = cy - 1.5*b = y + 0.5*b
        """
        # 패들 너비가 다를 수 있으므로 width/2로 중심 계산
        paddle_width = getattr(paddle, 'width', 80)
        center_x = paddle.x + paddle_width // 2

        if paddle.is_top:
            # 상단 영웅: 패들 아래쪽에 캐릭터가 있음 (화면 중앙 방향)
            cy = paddle.y + int(3.5 * b)
            torso_y = cy - int(1.5 * b)  # = paddle.y + 2*b ≈ paddle.y + 16
        else:
            # 하단 영웅: 패들 위쪽에 캐릭터가 있음 (화면 중앙 방향)
            cy = paddle.y + int(2.0 * b)
            torso_y = cy - int(1.5 * b)  # = paddle.y + 0.5*b ≈ paddle.y + 4

        return center_x, torso_y, cy, b

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        self.target_is_top = target_paddle.is_top
        self.caster_is_top = caster_paddle.is_top
        self.phase = 'travel'
        self.travel_progress = 0
        self.wrap_timer = 0
        self.slow_applied = False
        self.time = 0

        # 크라켄의 실제 몸체 위치 계산 (hero_paddles.py와 동기화)
        b = 8  # 기본 블록 단위
        caster_cx, caster_torso_y, caster_cy, _ = self._get_hero_body_position(caster_paddle, b)
        target_cx, target_torso_y, target_cy, _ = self._get_hero_body_position(target_paddle, b)

        # 촉수 생성 - 크라켄의 어깨/팔 영역에서 시작
        self.tentacles = []

        # 크라켄 어깨 위치 오프셋 (hero_paddles.py 기준: shoulder = cx ± 1.4*b, torso_y + 0.2*b)
        shoulder_offset_x = int(1.4 * b)  # ≈ 11
        shoulder_offset_y = int(0.2 * b)  # ≈ 2

        # 방향 (상단이면 아래로, 하단이면 위로 뻗어나감)
        direction = 1 if caster_paddle.is_top else -1

        # 촉수 시작 위치: 크라켄의 어깨/팔 영역
        tentacle_origins = [
            # 왼쪽 어깨/팔 촉수들
            {'base_offset_x': -shoulder_offset_x - 5, 'base_offset_y': shoulder_offset_y, 'type': 'shoulder'},
            {'base_offset_x': -shoulder_offset_x + 3, 'base_offset_y': shoulder_offset_y + 8, 'type': 'arm'},
            {'base_offset_x': -int(0.4 * b), 'base_offset_y': shoulder_offset_y + 12, 'type': 'body'},
            # 오른쪽 어깨/팔 촉수들
            {'base_offset_x': int(0.4 * b), 'base_offset_y': shoulder_offset_y + 12, 'type': 'body'},
            {'base_offset_x': shoulder_offset_x - 3, 'base_offset_y': shoulder_offset_y + 8, 'type': 'arm'},
            {'base_offset_x': shoulder_offset_x + 5, 'base_offset_y': shoulder_offset_y, 'type': 'shoulder'},
        ]

        for i, origin in enumerate(tentacle_origins):
            # 약간의 랜덤 변동으로 자연스러움 추가
            offset_x = origin['base_offset_x'] + random.uniform(-2, 2)
            offset_y = origin['base_offset_y'] * direction + random.uniform(-1, 1) * direction

            # 촉수마다 고유한 특성
            thickness_base = 7 if origin['type'] == 'shoulder' else (6 if origin['type'] == 'arm' else 5)

            self.tentacles.append({
                'start_x': caster_cx + offset_x,
                'start_y': caster_torso_y + offset_y,
                'offset_x': offset_x,
                'offset_y': offset_y,
                'caster_torso_y_offset': 0,  # torso_y 기준 오프셋
                'target_x': target_cx,
                'target_y': target_torso_y,  # 타겟 영웅의 몸통 위치!
                'progress': 0,
                'wave_offset': random.uniform(0, math.pi * 2),
                'wave_speed': random.uniform(3.5, 4.5),
                'thickness': thickness_base + random.uniform(-1, 1),
                'wrap_angle': i * (360 / 6) + random.uniform(-10, 10),
                'wrap_radius': 35 + random.uniform(-5, 10),
                'coil_turns': random.uniform(1.5, 2.5),
                'coil_progress': 0,
                'type': origin['type'],
                'sucker_count': random.randint(6, 10),
                'biolum_phase': random.uniform(0, math.pi * 2),
            })

        # 저장해둘 값들 (update에서 사용)
        self.b = b

        return {
            'status_duration': self.duration,
            'sound': 'tentacle'
        }

    def _cubic_bezier(self, t, p0, p1, p2, p3):
        """3차 베지어 곡선 계산"""
        inv_t = 1 - t
        return (inv_t ** 3 * p0 +
                3 * inv_t ** 2 * t * p1 +
                3 * inv_t * t ** 2 * p2 +
                t ** 3 * p3)

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        self.time += dt

        # caster와 target의 실제 영웅 몸통 위치 계산
        b = getattr(self, 'b', 8)
        caster_cx, caster_torso_y, _, _ = self._get_hero_body_position(caster_paddle, b)
        target_cx, target_torso_y, _, _ = self._get_hero_body_position(target_paddle, b)

        for t in self.tentacles:
            # caster 위치 업데이트 (촉수가 크라켄 몸체와 계속 연결)
            t['start_x'] = caster_cx + t['offset_x']
            t['start_y'] = caster_torso_y + t['offset_y']
            # target 위치 업데이트 (타겟 영웅의 몸통 위치)
            t['target_x'] = target_cx
            t['target_y'] = target_torso_y
            t['wave_offset'] += dt * t['wave_speed']
            t['biolum_phase'] += dt * 2

        if self.phase == 'travel':
            # 이동 단계: 촉수가 caster에서 target으로 뻗어나감
            self.travel_progress = min(1.0, self.travel_progress + dt * 1.2)  # 약 0.83초에 도달
            for t in self.tentacles:
                # 이징 함수 적용 (ease-out)
                eased_progress = 1 - (1 - self.travel_progress) ** 2
                t['progress'] = eased_progress

            # 촉수가 도달하면 wrap 단계로 전환
            if self.travel_progress >= 1.0:
                self.phase = 'wrap'
                self.wrap_timer = 0
                # 붙잡기 사운드 재생
                try:
                    import os
                    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                    grab_path = os.path.join(project_root, "sounds", "grab.wav")
                    if os.path.exists(grab_path):
                        pygame.mixer.Sound(grab_path).play()
                except Exception:
                    pass
                # 이제 둔화 적용 (60% 감소)
                if not self.slow_applied:
                    self.slow_applied = True
                    # self.target_is_top 사용하여 일관성 유지 (스킬 발동 시점의 타겟)
                    target_prefix = 'top_paddle' if self.target_is_top else 'bottom_paddle'
                    game_state[f'{target_prefix}_stunned'] = False
                    game_state['target_stunned'] = False
                    game_state[f'{target_prefix}_slowed'] = True
                    game_state[f'{target_prefix}_slow_amount'] = self.slow_amount
                    game_state[f'{target_prefix}_tentacle_slowed'] = True  # 촉수 휘감기로 인한 둔화 표시
                    game_state['target_slowed'] = True
                    game_state['slow_amount'] = self.slow_amount
                    game_state['tentacle_wrap_active'] = True
                    game_state['tentacle_wrap_target_is_top'] = self.target_is_top

        elif self.phase == 'wrap':
            self.wrap_timer += dt
            # self.target_is_top 사용하여 일관성 유지
            target_prefix = 'top_paddle' if self.target_is_top else 'bottom_paddle'
            game_state[f'{target_prefix}_stunned'] = False
            game_state['target_stunned'] = False

            for t in self.tentacles:
                # 코일링 진행도 (서서히 조여듦)
                t['coil_progress'] = min(1.0, t['coil_progress'] + dt * 0.8)
                # 감싸기 애니메이션 - 회전하면서 조여듦
                t['wrap_angle'] += dt * 80
                # 감싸는 반경 서서히 줄어듦
                if t['coil_progress'] < 1.0:
                    t['wrap_radius'] = 35 + (1 - t['coil_progress']) * 15

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        game_state['target_slowed'] = False
        game_state['slow_amount'] = 1.0
        target_prefix = 'top_paddle' if self.target_is_top else 'bottom_paddle'
        # 둔화 적용했으면 반드시 해제 (slow_applied 기준으로 확실하게 정리)
        if self.slow_applied:
            game_state[f'{target_prefix}_slowed'] = False
            game_state[f'{target_prefix}_slow_amount'] = 1.0
            game_state[f'{target_prefix}_tentacle_slowed'] = False
        game_state['tentacle_wrap_active'] = False
        self.tentacles = []
        self.phase = 'travel'
        self.slow_applied = False

    def reset_for_new_round(self, game_state: dict):
        """라운드 전환 시 촉수 및 둔화 상태 초기화"""
        # 남아있는 둔화 효과 정리
        target_prefix = 'top_paddle' if self.target_is_top else 'bottom_paddle'
        if self.slow_applied:
            game_state[f'{target_prefix}_slowed'] = False
            game_state[f'{target_prefix}_slow_amount'] = 1.0
            game_state[f'{target_prefix}_tentacle_slowed'] = False
        game_state['target_slowed'] = False
        game_state['slow_amount'] = 1.0
        game_state['tentacle_wrap_active'] = False
        self.tentacles = []
        self.phase = 'travel'
        self.slow_applied = False
        super().reset_for_new_round(game_state)

    def _draw_sucker(self, screen, x, y, size, alpha=255):
        """고퀄리티 빨판 그리기"""
        if size < 2:
            return
        # 빨판 외곽 (약간 어두운 테두리)
        pygame.draw.circle(screen, self.colors['tentacle_mid'], (int(x), int(y)), size + 1)
        # 빨판 베이스
        pygame.draw.circle(screen, self.colors['sucker_base'], (int(x), int(y)), size)
        # 빨판 내부 홈
        inner_size = max(1, size - 2)
        pygame.draw.circle(screen, self.colors['sucker_inner'], (int(x), int(y)), inner_size)
        # 빨판 하이라이트 (작은 반사광)
        if size > 3:
            highlight_size = max(1, size // 3)
            pygame.draw.circle(screen, self.colors['sucker_highlight'],
                             (int(x) - size // 3, int(y) - size // 3), highlight_size)

    def _draw_tentacle_segment(self, screen, points, thickness, progress=1.0, is_tip=False):
        """고퀄리티 촉수 세그먼트 그리기 (그라데이션 + 입체감)"""
        if len(points) < 2:
            return

        # 두께 변화 (시작이 두껍고 끝이 가늘어짐)
        for i in range(len(points) - 1):
            seg_progress = i / max(1, len(points) - 1)
            # 두께 그라데이션 (시작 -> 끝으로 갈수록 가늘어짐)
            current_thickness = int(thickness * (1.0 - seg_progress * 0.5))
            current_thickness = max(2, current_thickness)

            p1, p2 = points[i], points[i + 1]

            # 3레이어 렌더링 (그림자 -> 본체 -> 하이라이트)
            # 그림자/외곽
            pygame.draw.line(screen, self.colors['tentacle_core'], p1, p2, current_thickness + 3)
            # 본체
            pygame.draw.line(screen, self.colors['tentacle_mid'], p1, p2, current_thickness + 1)
            # 하이라이트 (상단)
            pygame.draw.line(screen, self.colors['tentacle_outer'], p1, p2, max(1, current_thickness - 1))

    def _draw_bioluminescence(self, screen, x, y, phase, intensity=1.0):
        """생물 발광 효과"""
        pulse = (math.sin(phase) + 1) * 0.5 * intensity
        if pulse < 0.3:
            return

        glow_size = int(6 + pulse * 4)
        glow_surf = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)

        # 다층 글로우 효과
        for i in range(3):
            alpha = int((80 - i * 20) * pulse)
            radius = glow_size - i * 2
            if radius > 0 and alpha > 0:
                pygame.draw.circle(glow_surf, (*self.colors['biolum'], alpha),
                                 (glow_size, glow_size), radius)

        screen.blit(glow_surf, (int(x) - glow_size, int(y) - glow_size), special_flags=pygame.BLEND_ADD)

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        # 영웅의 실제 몸통 위치 계산
        b = getattr(self, 'b', 8)
        caster_cx, caster_torso_y, _, _ = self._get_hero_body_position(caster_paddle, b)
        target_cx, target_torso_y, _, _ = self._get_hero_body_position(target_paddle, b)
        direction = 1 if caster_paddle.is_top else -1

        if self.phase == 'travel':
            # === 이동 단계: 크라켄에서 자연스럽게 뻗어나가는 촉수 ===
            for t in self.tentacles:
                if t['progress'] <= 0:
                    continue

                start_x = t['start_x']
                start_y = t['start_y']
                target_x = t['target_x']
                target_y = t['target_y']

                # 현재 촉수 끝 위치 (progress에 따라)
                current_end_x = start_x + (target_x - start_x) * t['progress']
                current_end_y = start_y + (target_y - start_y) * t['progress']

                # 3차 베지어 곡선을 위한 제어점 계산
                dist = math.sqrt((target_x - start_x)**2 + (target_y - start_y)**2)

                # 제어점 1: 시작점 근처 (크라켄 몸체와 자연스럽게 연결)
                ctrl1_x = start_x + t['offset_x'] * 0.5
                ctrl1_y = start_y + direction * 30

                # 제어점 2: 중간 지점 (물결 효과)
                mid_wave = math.sin(self.time * 3 + t['wave_offset']) * 30
                ctrl2_x = (start_x + current_end_x) / 2 + mid_wave
                ctrl2_y = (start_y + current_end_y) / 2

                # 베지어 곡선으로 촉수 경로 생성
                points = []
                segments = 30
                for i in range(segments + 1):
                    seg_t = i / segments

                    # 3차 베지어 곡선
                    x = self._cubic_bezier(seg_t, start_x, ctrl1_x, ctrl2_x, current_end_x)
                    y = self._cubic_bezier(seg_t, start_y, ctrl1_y, ctrl2_y, current_end_y)

                    # 추가 물결 효과 (촉수가 살아있는 느낌)
                    wave_amp = 8 * math.sin(seg_t * math.pi)  # 중간이 가장 강함
                    wave = math.sin(seg_t * math.pi * 3 + t['wave_offset'] + self.time * 4) * wave_amp
                    x += wave

                    points.append((int(x), int(y)))

                if len(points) > 1:
                    # 촉수 그리기
                    self._draw_tentacle_segment(screen, points, t['thickness'], t['progress'])

                    # 빨판 그리기 (촉수 안쪽 면에)
                    sucker_interval = max(3, len(points) // t['sucker_count'])
                    for j in range(sucker_interval, len(points) - 2, sucker_interval):
                        px, py = points[j]
                        seg_progress = j / len(points)
                        sucker_size = int(t['thickness'] * 0.4 * (1 - seg_progress * 0.3))
                        self._draw_sucker(screen, px, py, sucker_size)

                    # 촉수 끝 발광 효과
                    if len(points) > 0:
                        end_x, end_y = points[-1]
                        self._draw_bioluminescence(screen, end_x, end_y,
                                                  t['biolum_phase'] + self.time * 3,
                                                  intensity=0.7 + t['progress'] * 0.3)

                        # 촉수 끝 끝단 (약간 갈라진 형태)
                        for finger in range(3):
                            f_angle = (finger - 1) * 0.4 + math.sin(self.time * 5 + finger) * 0.2
                            f_len = int(8 + t['thickness'])
                            fx = end_x + int(math.cos(f_angle + math.pi/2 * direction) * f_len)
                            fy = end_y + int(direction * f_len * 0.8)
                            pygame.draw.line(screen, self.colors['tentacle_outer'],
                                           (int(end_x), int(end_y)), (int(fx), int(fy)),
                                           max(1, int(t['thickness'] * 0.3)))

        elif self.phase == 'wrap':
            # === 감싸기 단계: 타겟을 휘감는 촉수 (코일링 효과) ===
            # target_cx, target_torso_y는 이미 위에서 계산됨 (영웅 몸통 위치)
            target_x = target_cx
            target_y = target_torso_y

            for idx, t in enumerate(self.tentacles):
                start_x = t['start_x']
                start_y = t['start_y']

                # 코일링 계산 (타겟 주위를 나선형으로 감쌈)
                coil_progress = t['coil_progress']
                base_angle = math.radians(t['wrap_angle'])
                wrap_radius = t['wrap_radius']
                coil_turns = t['coil_turns']

                # 베지어 곡선 제어점
                ctrl1_x = start_x + t['offset_x'] * 0.3
                ctrl1_y = start_y + direction * 40

                # 중간 지점 (타겟 방향으로)
                mid_x = (start_x + target_x) / 2
                mid_y = (start_y + target_y) / 2

                # 촉수 경로 생성 (시작점 -> 중간 -> 타겟 주위 코일)
                points = []
                total_segments = 40

                for i in range(total_segments + 1):
                    seg_t = i / total_segments

                    if seg_t < 0.5:
                        # 전반부: 크라켄에서 타겟까지 이동
                        local_t = seg_t * 2
                        x = self._cubic_bezier(local_t, start_x, ctrl1_x, mid_x, target_x)
                        y = self._cubic_bezier(local_t, start_y, ctrl1_y, mid_y, target_y)

                        # 물결 효과
                        wave_amp = 10 * math.sin(local_t * math.pi)
                        wave = math.sin(local_t * math.pi * 2 + t['wave_offset'] + self.time * 3) * wave_amp
                        x += wave
                    else:
                        # 후반부: 타겟 주위를 코일링
                        local_t = (seg_t - 0.5) * 2 * coil_progress

                        # 나선형 각도 계산
                        coil_angle = base_angle + local_t * coil_turns * math.pi * 2
                        # 반경이 점점 줄어듦 (조여드는 효과)
                        current_radius = wrap_radius * (1 - local_t * 0.4)
                        # 높이 변화 (나선형으로 위아래로 감쌈)
                        height_offset = math.sin(local_t * coil_turns * math.pi * 2) * 15

                        x = target_x + current_radius * math.cos(coil_angle)
                        y = target_y + current_radius * 0.5 * math.sin(coil_angle) + height_offset

                        # 타겟이 움직이면 따라가는 미세한 지연
                        x += math.sin(self.time * 4 + idx) * 3

                    points.append((int(x), int(y)))

                if len(points) > 1:
                    # 촉수 그리기
                    self._draw_tentacle_segment(screen, points, t['thickness'])

                    # 빨판 (코일 부분에 더 많이)
                    for j in range(3, len(points) - 1, 4):
                        px, py = points[j]
                        seg_progress = j / len(points)
                        # 코일 부분(후반부)에서 빨판이 더 잘 보임
                        if seg_progress > 0.4:
                            sucker_size = int(t['thickness'] * 0.45)
                            self._draw_sucker(screen, px, py, sucker_size)

                    # 발광 효과 (코일 부분에서 강하게)
                    if coil_progress > 0.5:
                        coil_start_idx = int(len(points) * 0.5)
                        for j in range(coil_start_idx, len(points), 8):
                            px, py = points[j]
                            self._draw_bioluminescence(screen, px, py,
                                                      t['biolum_phase'] + j * 0.3,
                                                      intensity=0.5)

            # === 타겟 주변 구속 효과 ===
            # 조여드는 에너지 링
            ring_pulse = (math.sin(self.time * 5) + 1) * 0.5
            ring_radius = int(35 + ring_pulse * 10)

            # 다층 링 효과
            for i in range(3):
                ring_surf = pygame.Surface((ring_radius * 2 + 20, ring_radius * 2 + 20), pygame.SRCALPHA)
                ring_alpha = int((60 - i * 15) * (0.5 + ring_pulse * 0.5))
                ring_color = (*self.colors['tentacle_highlight'], ring_alpha)
                pygame.draw.ellipse(ring_surf, ring_color,
                                  (10 - i * 3, 10 - i * 3,
                                   ring_radius * 2 + i * 6, int(ring_radius * 1.2) + i * 4),
                                  2 + i)
                screen.blit(ring_surf, (target_x - ring_radius - 10, target_y - ring_radius - 10))

            # 점액 효과 (타겟에 달라붙은 느낌)
            slime_points = 8
            for i in range(slime_points):
                angle = (i / slime_points) * math.pi * 2 + self.time * 0.5
                slime_dist = 25 + math.sin(self.time * 3 + i) * 5
                slime_x = target_x + math.cos(angle) * slime_dist
                slime_y = target_y + math.sin(angle) * slime_dist * 0.6
                slime_size = int(3 + math.sin(self.time * 4 + i * 0.5) * 2)

                slime_surf = pygame.Surface((slime_size * 2 + 4, slime_size * 2 + 4), pygame.SRCALPHA)
                pygame.draw.circle(slime_surf, (*self.colors['slime'], 120),
                                 (slime_size + 2, slime_size + 2), slime_size)
                screen.blit(slime_surf, (int(slime_x) - slime_size - 2, int(slime_y) - slime_size - 2))

    def reset_for_new_round(self, game_state: dict):
        """라운드 전환 시 촉수 휘감기 스킬 강제 종료"""
        super().reset_for_new_round(game_state)
        self.tentacles = []
        self.phase = 'travel'
        self.travel_progress = 0
        self.wrap_timer = 0
        self.time = 0
        if self.slow_applied:
            target_prefix = 'top_paddle' if self.target_is_top else 'bottom_paddle'
            # 촉수 휘감기로 인한 둔화만 해제
            if game_state.get(f'{target_prefix}_tentacle_slowed', False):
                game_state[f'{target_prefix}_slowed'] = False
                game_state[f'{target_prefix}_slow_amount'] = 1.0
                game_state[f'{target_prefix}_tentacle_slowed'] = False
            self.slow_applied = False


class AbyssInk(HeroSkill):
    """심해의 먹물 - 크라켄이 먹물을 발사하여 상대방에게 혼란을 준다 [고퀄리티]"""
    def __init__(self):
        super().__init__(
            skill_id="abyss_ink",
            name="Abyss Ink",
            korean_name="심해의 먹물",
            description="심해의 먹물을 발사하여 상대의 시야를 방해하고 혼란을 준다",
            trigger=SkillTrigger.ON_BALL_HIT,
            cooldown=15.0,
            duration=3.5,
            hero_id="kraken"
        )
        self.ink_blobs = []
        self.target_is_top = False
        self.caster_is_top = False

        # 4단계 애니메이션: travel -> splash -> active -> dissolving
        self.phase = 'travel'
        self.projectile_x = 0
        self.projectile_y = 0
        self.projectile_target_x = 0
        self.projectile_target_y = 0
        self.projectile_progress = 0.0
        self.projectile_speed = 1.5

        # 발사체 안정 파티클 (미리 생성하여 프레임 간 떨림 방지)
        self._proj_blobs = []
        self._trail_particles = []
        self._proj_rotation = 0.0  # 발사체 회전 각도

        # 스플래시 관련
        self.splash_center_x = 0
        self.splash_center_y = 0
        self.splash_radius = 0
        self.splash_max_radius = 150
        self.splash_width_scale = 1.5
        self.splash_expand_speed = 400
        self.splash_timer = 0
        self.splash_duration = 0.4
        self.splash_droplets = []  # 튀는 방울 (미리 생성)
        self.active_duration = 3.0
        self.active_timer = 0

        # 고퀄리티 먹물 레이어
        self.ink_bubbles = []       # 기포
        self.ink_tendrils = []      # 먹물 가지/촉수
        self.ink_shimmer_time = 0.0  # 표면 일렁임 타이머

        # 혼란 적용 여부
        self.confusion_applied = False
        self.confusion_timer = 0
        self.confusion_duration = 3.0

        # 분해 애니메이션 (스킬 종료 후에도 지속)
        self.dissolving = False
        self.dissolve_timer = 0.0
        self.dissolve_duration = 1.5
        self.dissolve_fragments = []
        self.dissolve_wisps = []

        # 색상 팔레트 (심해 테마)
        self.colors = {
            'ink_deep': (20, 8, 45),
            'ink_core': (35, 18, 70),
            'ink_mid': (50, 28, 90),
            'ink_outer': (70, 38, 115),
            'ink_glow': (95, 55, 150),
            'ink_highlight': (125, 75, 175),
            'ink_shimmer': (155, 100, 205),
            'bubble_base': (80, 50, 130),
            'bubble_highlight': (140, 110, 200),
            'tendril': (45, 22, 80),
        }

    def _init_projectile_particles(self):
        """발사체 구성 파티클 미리 생성 (매 프레임 랜덤 방지)"""
        self._proj_blobs = []
        for _ in range(8):
            self._proj_blobs.append({
                'offset_x': random.uniform(-12, 12),
                'offset_y': random.uniform(-12, 12),
                'size': random.uniform(8, 16),
                'phase': random.uniform(0, math.pi * 2),
                'speed': random.uniform(1.5, 3.0),
            })
        self._trail_particles = []

    def _init_splash_droplets(self):
        """스플래시 시 튀는 방울 미리 생성"""
        self.splash_droplets = []
        for _ in range(16):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(100, 350)
            self.splash_droplets.append({
                'angle': angle,
                'speed': speed,
                'x': 0.0, 'y': 0.0,
                'size': random.uniform(3, 9),
                'alpha': 255,
                'gravity': random.uniform(50, 120),
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed,
            })

    def _init_ink_pool(self):
        """active 단계 먹물 웅덩이 초기화"""
        self.ink_blobs = []
        # 메인 블롭들 (큰 먹물 덩어리)
        for _ in range(10):
            angle = random.uniform(0, math.pi * 2)
            dist = random.uniform(0, 0.75)
            self.ink_blobs.append({
                'x': self.splash_center_x + math.cos(angle) * self.splash_max_radius * self.splash_width_scale * dist,
                'y': self.splash_center_y + math.sin(angle) * self.splash_max_radius * dist,
                'size': random.uniform(35, 85),
                'alpha': 220,
                'wobble': random.uniform(0, math.pi * 2),
                'wobble_speed': random.uniform(1.2, 2.5),
                'shape_seed': random.uniform(0, math.pi * 2),  # 형태 시드
                'pulse_phase': random.uniform(0, math.pi * 2),
            })
        # 작은 입자들
        for _ in range(12):
            angle = random.uniform(0, math.pi * 2)
            dist = random.uniform(0.3, 1.0)
            self.ink_blobs.append({
                'x': self.splash_center_x + math.cos(angle) * self.splash_max_radius * self.splash_width_scale * dist,
                'y': self.splash_center_y + math.sin(angle) * self.splash_max_radius * dist,
                'size': random.uniform(8, 22),
                'alpha': 180,
                'wobble': random.uniform(0, math.pi * 2),
                'wobble_speed': random.uniform(2.0, 4.0),
                'shape_seed': random.uniform(0, math.pi * 2),
                'pulse_phase': random.uniform(0, math.pi * 2),
            })

        # 기포
        self.ink_bubbles = []
        for _ in range(8):
            angle = random.uniform(0, math.pi * 2)
            dist = random.uniform(0, 0.6)
            self.ink_bubbles.append({
                'x': self.splash_center_x + math.cos(angle) * self.splash_max_radius * self.splash_width_scale * dist,
                'y': self.splash_center_y + math.sin(angle) * self.splash_max_radius * dist,
                'size': random.uniform(3, 7),
                'life': random.uniform(0.5, 1.5),
                'max_life': random.uniform(0.5, 1.5),
                'rise_speed': random.uniform(15, 35),
                'drift_x': random.uniform(-10, 10),
            })

        # 먹물 촉수/가지 (가장자리에서 뻗어나감)
        self.ink_tendrils = []
        for _ in range(6):
            angle = random.uniform(0, math.pi * 2)
            self.ink_tendrils.append({
                'angle': angle,
                'length': random.uniform(0.7, 1.1),
                'width': random.uniform(6, 14),
                'wobble': random.uniform(0, math.pi * 2),
                'wobble_speed': random.uniform(1.0, 2.0),
                'segments': random.randint(4, 7),
            })

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        self.target_is_top = target_paddle.is_top
        self.caster_is_top = caster_paddle.is_top

        self.phase = 'travel'
        self.projectile_progress = 0.0
        self._proj_rotation = 0.0
        self.confusion_applied = False
        self.confusion_timer = 0
        self.ink_blobs = []
        self.ink_bubbles = []
        self.ink_tendrils = []
        self.ink_shimmer_time = 0.0
        self.splash_radius = 0
        self.splash_timer = 0
        self.splash_droplets = []
        self.dissolving = False
        self.dissolve_timer = 0.0
        self.dissolve_fragments = []
        self.dissolve_wisps = []

        self._init_projectile_particles()

        self.projectile_x = caster_paddle.x + 40
        self.projectile_y = caster_paddle.y + (30 if caster_paddle.is_top else -30)
        self.projectile_target_x = target_paddle.x + 40
        self.projectile_target_y = 600 if caster_paddle.is_top else 150

        caster_prefix = 'top_paddle' if caster_paddle.is_top else 'bottom_paddle'
        game_state[f'{caster_prefix}_confused'] = False

        return {
            'screen_effect': ScreenEffect.INK,
            'sound': 'abyssinkshoot'
        }

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        if self.phase == 'travel':
            self.projectile_progress += dt * self.projectile_speed
            self._proj_rotation += dt * 180  # 회전

            # 발사체 파티클 유기적 움직임
            for pb in self._proj_blobs:
                pb['phase'] += dt * pb['speed']

            # 트레일 파티클 생성
            if self.projectile_progress > 0.05:
                cur_x = self.projectile_x + (self.projectile_target_x - self.projectile_x) * self.projectile_progress
                cur_y = self.projectile_y + (self.projectile_target_y - self.projectile_y) * self.projectile_progress
                self._trail_particles.append({
                    'x': cur_x + random.uniform(-8, 8),
                    'y': cur_y + random.uniform(-8, 8),
                    'size': random.uniform(4, 10),
                    'alpha': 200,
                    'life': 0.4,
                })

            # 트레일 업데이트
            for tp in self._trail_particles:
                tp['life'] -= dt
                tp['alpha'] = max(0, tp['alpha'] - dt * 500)
                tp['size'] = max(0, tp['size'] - dt * 12)
            self._trail_particles = [tp for tp in self._trail_particles if tp['life'] > 0]

            if self.projectile_progress >= 1.0:
                self.phase = 'splash'
                self.splash_center_x = self.projectile_target_x
                self.splash_center_y = self.projectile_target_y
                self.splash_radius = 20
                self.splash_timer = 0
                self._init_splash_droplets()
                self._trail_particles = []
                # 먹물 펼침 사운드 재생
                try:
                    import os
                    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                    ink_path = os.path.join(project_root, "sounds", "abyssink.wav")
                    if os.path.exists(ink_path):
                        pygame.mixer.Sound(ink_path).play()
                except Exception:
                    pass

        elif self.phase == 'splash':
            self.splash_timer += dt
            self.splash_radius = min(self.splash_max_radius,
                                     20 + self.splash_expand_speed * self.splash_timer)

            # 튀는 방울 물리 업데이트
            for drop in self.splash_droplets:
                drop['vx'] *= 0.97  # 공기저항
                drop['vy'] += drop['gravity'] * dt  # 중력
                drop['x'] += drop['vx'] * dt
                drop['y'] += drop['vy'] * dt
                drop['alpha'] = max(0, drop['alpha'] - dt * 300)
                drop['size'] = max(0, drop['size'] - dt * 3)

            if self.splash_timer >= self.splash_duration:
                self.phase = 'active'
                self._init_ink_pool()

        elif self.phase == 'active':
            self.ink_shimmer_time += dt

            # 먹물 블롭 애니메이션
            for blob in self.ink_blobs:
                blob['wobble'] += dt * blob['wobble_speed']
                blob['pulse_phase'] += dt * 1.5
                # 천천히 팽창
                blob['size'] += dt * 1.5

            # 기포 업데이트
            for bubble in self.ink_bubbles:
                bubble['y'] -= bubble['rise_speed'] * dt
                bubble['x'] += bubble['drift_x'] * dt
                bubble['life'] -= dt
                if bubble['life'] <= 0:
                    # 기포 재생성
                    angle = random.uniform(0, math.pi * 2)
                    dist = random.uniform(0, 0.6)
                    bubble['x'] = self.splash_center_x + math.cos(angle) * self.splash_max_radius * self.splash_width_scale * dist
                    bubble['y'] = self.splash_center_y + math.sin(angle) * self.splash_max_radius * dist
                    bubble['size'] = random.uniform(3, 7)
                    bubble['life'] = bubble['max_life']
                    bubble['drift_x'] = random.uniform(-10, 10)

            # 촉수 웨이브
            for tendril in self.ink_tendrils:
                tendril['wobble'] += dt * tendril['wobble_speed']

            # 혼란 판정
            target_center_x = target_paddle.x + 40
            target_center_y = target_paddle.y
            dx = target_center_x - self.splash_center_x
            dy = target_center_y - self.splash_center_y
            width_radius = self.splash_max_radius * self.splash_width_scale + 40
            height_radius = self.splash_max_radius + 40
            target_prefix = 'top_paddle' if target_paddle.is_top else 'bottom_paddle'

            ellipse_dist = (dx / width_radius) ** 2 + (dy / height_radius) ** 2
            if ellipse_dist <= 1:
                if not self.confusion_applied:
                    self.confusion_applied = True
                    self.confusion_timer = 0
                    game_state[f'{target_prefix}_confused'] = True
                    game_state['target_confused'] = True
                    game_state['confusion_type'] = 'random'

            if self.confusion_applied:
                self.confusion_timer += dt
                if self.confusion_timer >= self.confusion_duration:
                    game_state[f'{target_prefix}_confused'] = False
                    game_state['target_confused'] = False

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        # 혼란 상태 클리어
        if self.confusion_applied and self.confusion_timer < self.confusion_duration:
            game_state['target_confused'] = False
            target_prefix = 'top_paddle' if self.target_is_top else 'bottom_paddle'
            game_state[f'{target_prefix}_confused'] = False

        # 분해 애니메이션 시작 (즉시 제거하지 않음)
        self.dissolving = True
        self.dissolve_timer = 0.0
        self._init_dissolve()

        # 게임 로직 상태만 초기화
        self.confusion_applied = False
        self.confusion_timer = 0
        self.splash_radius = 0

    def _init_dissolve(self):
        """분해 파편 및 연기 초기화"""
        self.dissolve_fragments = []
        # 먹물 블롭들을 분해 파편으로 변환
        for blob in self.ink_blobs:
            if blob['alpha'] > 5:
                # 각 블롭을 2~4개 파편으로 분할
                num_frags = random.randint(2, 4)
                for _ in range(num_frags):
                    angle = random.uniform(0, math.pi * 2)
                    speed = random.uniform(15, 60)
                    self.dissolve_fragments.append({
                        'x': blob['x'] + random.uniform(-10, 10),
                        'y': blob['y'] + random.uniform(-10, 10),
                        'vx': math.cos(angle) * speed,
                        'vy': math.sin(angle) * speed - random.uniform(10, 30),
                        'size': blob['size'] / num_frags * random.uniform(0.5, 1.2),
                        'alpha': min(255, blob['alpha']),
                        'rotation': random.uniform(0, 360),
                        'rot_speed': random.uniform(-120, 120),
                        'shape_seed': random.uniform(0, math.pi * 2),
                        'shrink_rate': random.uniform(0.4, 0.8),
                    })

        # 증발 연기 생성
        self.dissolve_wisps = []
        num_wisps = 12
        for _ in range(num_wisps):
            angle = random.uniform(0, math.pi * 2)
            dist = random.uniform(0, 0.7)
            wx = self.splash_center_x + math.cos(angle) * self.splash_max_radius * self.splash_width_scale * dist
            wy = self.splash_center_y + math.sin(angle) * self.splash_max_radius * dist
            self.dissolve_wisps.append({
                'x': wx,
                'y': wy,
                'size': random.uniform(15, 40),
                'alpha': random.uniform(120, 200),
                'rise_speed': random.uniform(30, 80),
                'drift_x': random.uniform(-20, 20),
                'expand_rate': random.uniform(8, 20),
                'delay': random.uniform(0, 0.4),  # 시차를 두고 증발
            })

        # 기포도 파편으로 변환
        for bubble in self.ink_bubbles:
            self.dissolve_fragments.append({
                'x': bubble['x'], 'y': bubble['y'],
                'vx': random.uniform(-15, 15),
                'vy': -random.uniform(20, 60),
                'size': bubble['size'] * 2,
                'alpha': 180,
                'rotation': 0, 'rot_speed': 0,
                'shape_seed': 0,
                'shrink_rate': random.uniform(0.6, 1.0),
            })

        self.ink_blobs = []
        self.ink_bubbles = []
        self.ink_tendrils = []

    def update(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        """오버라이드: 분해 애니메이션을 is_active=False 이후에도 업데이트"""
        # 쿨타임 감소
        if self.current_cooldown > 0:
            self.current_cooldown -= dt

        # 활성 효과 업데이트
        if self.is_active:
            self.active_timer -= dt
            self._update_active_effect(dt, caster_paddle, target_paddle, ball, game_state)
            if self.active_timer <= 0:
                self._end_effect(caster_paddle, target_paddle, ball, game_state)
                self.is_active = False

        # 분해 애니메이션 (is_active=False 이후에도 계속)
        if self.dissolving:
            self.dissolve_timer += dt

            # 파편 업데이트
            for frag in self.dissolve_fragments:
                frag['vx'] *= 0.96  # 감속
                frag['vy'] *= 0.96
                frag['vy'] -= 8 * dt  # 미세한 상승
                frag['x'] += frag['vx'] * dt
                frag['y'] += frag['vy'] * dt
                frag['rotation'] += frag['rot_speed'] * dt
                progress = min(1.0, self.dissolve_timer / self.dissolve_duration)
                frag['alpha'] = max(0, frag['alpha'] * (1 - progress * 1.2))
                frag['size'] = max(0, frag['size'] - frag['shrink_rate'] * dt * frag['size'])

            # 연기 업데이트
            for wisp in self.dissolve_wisps:
                if self.dissolve_timer >= wisp['delay']:
                    active_time = self.dissolve_timer - wisp['delay']
                    wisp['y'] -= wisp['rise_speed'] * dt
                    wisp['x'] += wisp['drift_x'] * dt
                    wisp['size'] += wisp['expand_rate'] * dt
                    fade_progress = min(1.0, active_time / (self.dissolve_duration - wisp['delay']))
                    # ease-in 페이드: 처음엔 천천히, 나중에 빠르게 사라짐
                    wisp['alpha'] = max(0, wisp['alpha'] * (1 - fade_progress ** 1.5))

            # 분해 완료
            if self.dissolve_timer >= self.dissolve_duration:
                self.dissolving = False
                self.dissolve_fragments = []
                self.dissolve_wisps = []
                self.phase = 'travel'
                self.projectile_progress = 0.0

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        # 분해 애니메이션 그리기
        if self.dissolving:
            self._draw_dissolve(screen)
            return

        if not self.is_active:
            return

        if self.phase == 'travel':
            self._draw_travel(screen)
        elif self.phase == 'splash':
            self._draw_splash(screen)
        elif self.phase == 'active':
            self._draw_active(screen)

    def _draw_travel(self, screen):
        """1단계: 고퀄리티 발사체"""
        progress = min(1.0, self.projectile_progress)
        current_x = self.projectile_x + (self.projectile_target_x - self.projectile_x) * progress
        current_y = self.projectile_y + (self.projectile_target_y - self.projectile_y) * progress

        # 트레일 파티클
        for tp in self._trail_particles:
            if tp['alpha'] > 5 and tp['size'] > 0.5:
                s = int(tp['size'])
                ts = pygame.Surface((s * 2 + 2, s * 2 + 2), pygame.SRCALPHA)
                a = int(max(0, min(255, tp['alpha'])))
                pygame.draw.circle(ts, (*self.colors['ink_mid'], a), (s + 1, s + 1), s)
                screen.blit(ts, (int(tp['x']) - s - 1, int(tp['y']) - s - 1))

        # 외곽 글로우 (큰 반투명 원)
        glow_size = 48
        glow_surf = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (*self.colors['ink_outer'], 60), (glow_size, glow_size), glow_size)
        pygame.draw.circle(glow_surf, (*self.colors['ink_glow'], 40), (glow_size, glow_size), glow_size - 8)
        screen.blit(glow_surf, (int(current_x) - glow_size, int(current_y) - glow_size))

        # 메인 발사체 서피스
        proj_size = 44
        proj_surf = pygame.Surface((proj_size * 2, proj_size * 2), pygame.SRCALPHA)
        cx, cy = proj_size, proj_size

        # 안정적인 먹물 덩어리 (미리 생성된 파티클 사용)
        for pb in self._proj_blobs:
            ox = pb['offset_x'] + math.sin(pb['phase']) * 3
            oy = pb['offset_y'] + math.cos(pb['phase'] * 0.7) * 3
            s = int(pb['size'] + math.sin(pb['phase'] * 1.3) * 2)
            # 회전 적용
            rot_rad = math.radians(self._proj_rotation)
            rx = ox * math.cos(rot_rad) - oy * math.sin(rot_rad)
            ry = ox * math.sin(rot_rad) + oy * math.cos(rot_rad)
            pygame.draw.circle(proj_surf, (*self.colors['ink_core'], 220),
                             (int(cx + rx), int(cy + ry)), s)

        # 코어 (발광 중심)
        core_pulse = 10 + math.sin(self._proj_rotation * 0.05) * 3
        pygame.draw.circle(proj_surf, (*self.colors['ink_deep'], 255), (cx, cy), int(core_pulse))
        pygame.draw.circle(proj_surf, (*self.colors['ink_glow'], 120), (cx, cy), int(core_pulse + 4))

        screen.blit(proj_surf, (int(current_x) - proj_size, int(current_y) - proj_size))

        # 꼬리 잔상 (안정적)
        for i in range(6):
            tail_p = max(0, progress - i * 0.06)
            if tail_p > 0:
                tx = self.projectile_x + (self.projectile_target_x - self.projectile_x) * tail_p
                ty = self.projectile_y + (self.projectile_target_y - self.projectile_y) * tail_p
                a = int(150 - i * 25)
                s = int(14 - i * 2)
                if s > 0 and a > 0:
                    ts = pygame.Surface((s * 2 + 2, s * 2 + 2), pygame.SRCALPHA)
                    pygame.draw.circle(ts, (*self.colors['ink_core'], a), (s + 1, s + 1), s)
                    screen.blit(ts, (int(tx) - s - 1, int(ty) - s - 1))

    def _draw_splash(self, screen):
        """2단계: 고퀄리티 스플래시"""
        wr = int(self.splash_radius * self.splash_width_scale)
        hr = int(self.splash_radius)
        if wr < 5 or hr < 5:
            return

        surf_w = wr * 2 + 60
        surf_h = hr * 2 + 60
        splash_surf = pygame.Surface((surf_w, surf_h), pygame.SRCALPHA)
        scx, scy = surf_w // 2, surf_h // 2

        # 불규칙한 스플래시 (복수 레이어)
        for layer_i, (color, scale, alpha) in enumerate([
            (self.colors['ink_outer'], 1.05, 80),
            (self.colors['ink_mid'], 0.92, 160),
            (self.colors['ink_core'], 0.78, 210),
        ]):
            points = []
            for angle in range(0, 360, 12):
                rad = math.radians(angle)
                wobble = 0.82 + 0.18 * math.sin(rad * 5 + self.splash_timer * 12 + layer_i * 0.5)
                px = scx + int(math.cos(rad) * wr * scale * wobble)
                py = scy + int(math.sin(rad) * hr * scale * wobble)
                points.append((px, py))
            if len(points) >= 3:
                pygame.draw.polygon(splash_surf, (*color, alpha), points)

        # 테두리 (발광)
        border_points = []
        for angle in range(0, 360, 10):
            rad = math.radians(angle)
            wobble = 0.85 + 0.15 * math.sin(rad * 5 + self.splash_timer * 12)
            px = scx + int(math.cos(rad) * wr * wobble)
            py = scy + int(math.sin(rad) * hr * wobble)
            border_points.append((px, py))
        if len(border_points) >= 3:
            pygame.draw.polygon(splash_surf, (*self.colors['ink_glow'], 180), border_points, 3)

        screen.blit(splash_surf, (int(self.splash_center_x - scx), int(self.splash_center_y - scy)))

        # 튀는 방울 (물리 기반)
        for drop in self.splash_droplets:
            if drop['alpha'] > 5 and drop['size'] > 0.5:
                dx = self.splash_center_x + drop['x']
                dy = self.splash_center_y + drop['y']
                s = max(1, int(drop['size']))
                a = int(max(0, min(255, drop['alpha'])))
                ds = pygame.Surface((s * 2 + 4, s * 2 + 4), pygame.SRCALPHA)
                pygame.draw.circle(ds, (*self.colors['ink_glow'], a // 2), (s + 2, s + 2), s + 2)
                pygame.draw.circle(ds, (*self.colors['ink_core'], a), (s + 2, s + 2), s)
                screen.blit(ds, (int(dx) - s - 2, int(dy) - s - 2))

    def _draw_active(self, screen):
        """3단계: 고퀄리티 먹물 웅덩이"""
        # --- 배경 영역 글로우 ---
        wr = int(self.splash_max_radius * self.splash_width_scale)
        hr = int(self.splash_max_radius)
        glow_surf = pygame.Surface((wr * 2 + 40, hr * 2 + 40), pygame.SRCALPHA)
        gcx, gcy = wr + 20, hr + 20

        # 부드러운 외곽 글로우 (타원)
        pulse = 1.0 + 0.03 * math.sin(self.ink_shimmer_time * 2)
        pygame.draw.ellipse(glow_surf, (*self.colors['ink_outer'], 35),
                           (int(gcx - wr * pulse), int(gcy - hr * pulse),
                            int(wr * 2 * pulse), int(hr * 2 * pulse)))
        pygame.draw.ellipse(glow_surf, (*self.colors['ink_mid'], 55),
                           (int(gcx - wr * 0.85), int(gcy - hr * 0.85),
                            int(wr * 1.7), int(hr * 1.7)))
        screen.blit(glow_surf, (int(self.splash_center_x - gcx), int(self.splash_center_y - gcy)))

        # --- 먹물 촉수/가지 (가장자리에서 뻗어나옴) ---
        for tendril in self.ink_tendrils:
            self._draw_tendril(screen, tendril)

        # --- 메인 먹물 블롭들 ---
        for blob in self.ink_blobs:
            if blob['alpha'] > 5:
                pulse_mod = 1.0 + 0.06 * math.sin(blob['pulse_phase'])
                size = int(blob['size'] * pulse_mod + math.sin(blob['wobble']) * 5)
                if size < 2:
                    continue

                surf = pygame.Surface((size * 2 + 12, size * 2 + 12), pygame.SRCALPHA)
                c = size + 6

                # 불규칙한 형태 (12각형 기반)
                points_outer = []
                points_inner = []
                for angle in range(0, 360, 30):
                    rad = math.radians(angle)
                    r_out = size * (0.75 + 0.3 * math.sin(rad * 3 + blob['shape_seed'] + blob['wobble'] * 0.5))
                    r_in = r_out * 0.7
                    points_outer.append((c + int(math.cos(rad) * r_out), c + int(math.sin(rad) * r_out)))
                    points_inner.append((c + int(math.cos(rad) * r_in), c + int(math.sin(rad) * r_in)))

                a = int(max(0, min(255, blob['alpha'])))
                if len(points_outer) >= 3:
                    # 외곽 (흐릿)
                    pygame.draw.polygon(surf, (*self.colors['ink_outer'], int(a * 0.35)), points_outer)
                    # 메인
                    pygame.draw.polygon(surf, (*self.colors['ink_core'], a), points_outer)
                    # 내부 깊은 색
                    pygame.draw.polygon(surf, (*self.colors['ink_deep'], int(a * 0.8)), points_inner)

                    # 표면 반사 (작은 하이라이트)
                    shimmer_x = c + int(math.sin(self.ink_shimmer_time * 1.5 + blob['shape_seed']) * size * 0.3)
                    shimmer_y = c - int(size * 0.2)
                    shimmer_size = max(2, int(size * 0.15))
                    shimmer_a = int(40 + 25 * math.sin(self.ink_shimmer_time * 2.5 + blob['shape_seed']))
                    pygame.draw.circle(surf, (*self.colors['ink_shimmer'], shimmer_a),
                                     (shimmer_x, shimmer_y), shimmer_size)

                screen.blit(surf, (int(blob['x'] - c), int(blob['y'] - c)))

        # --- 기포 ---
        for bubble in self.ink_bubbles:
            life_ratio = max(0, bubble['life'] / bubble['max_life'])
            if life_ratio > 0:
                s = max(1, int(bubble['size'] * (0.5 + life_ratio * 0.5)))
                ba = int(180 * life_ratio)
                # 기포 본체
                bs = pygame.Surface((s * 2 + 6, s * 2 + 6), pygame.SRCALPHA)
                bc = s + 3
                pygame.draw.circle(bs, (*self.colors['bubble_base'], ba), (bc, bc), s)
                # 기포 하이라이트 (반달)
                hl_size = max(1, s - 1)
                pygame.draw.circle(bs, (*self.colors['bubble_highlight'], int(ba * 0.6)),
                                 (bc - 1, bc - 1), hl_size, 1)
                screen.blit(bs, (int(bubble['x'] - bc), int(bubble['y'] - bc)))

        # --- 혼란 적용 시 영역 표시 ---
        if self.confusion_applied:
            confusion_surf = pygame.Surface((wr * 2 + 20, hr * 2 + 20), pygame.SRCALPHA)
            ccx, ccy = wr + 10, hr + 10
            # 맥동하는 외곽선
            pulse_a = int(30 + 20 * math.sin(self.ink_shimmer_time * 3))
            pygame.draw.ellipse(confusion_surf, (*self.colors['ink_glow'], pulse_a),
                               (10, 10, wr * 2, hr * 2), 2)
            screen.blit(confusion_surf, (int(self.splash_center_x - ccx), int(self.splash_center_y - ccy)))

    def _draw_tendril(self, screen, tendril):
        """먹물 촉수/가지 하나 그리기"""
        base_angle = tendril['angle']
        length = tendril['length']
        width = tendril['width']
        wobble = tendril['wobble']

        wr = self.splash_max_radius * self.splash_width_scale
        hr = self.splash_max_radius

        prev_x = self.splash_center_x + math.cos(base_angle) * wr * 0.5
        prev_y = self.splash_center_y + math.sin(base_angle) * hr * 0.5

        for seg in range(tendril['segments']):
            t = (seg + 1) / tendril['segments']
            seg_angle = base_angle + math.sin(wobble + seg * 0.8) * 0.3
            dist = (0.5 + t * 0.5) * length
            nx = self.splash_center_x + math.cos(seg_angle) * wr * dist
            ny = self.splash_center_y + math.sin(seg_angle) * hr * dist

            seg_width = max(1, int(width * (1.0 - t * 0.7)))
            alpha = int(180 * (1.0 - t * 0.6))

            # 촉수 세그먼트
            ts = pygame.Surface((abs(int(nx - prev_x)) + seg_width * 2 + 20,
                                abs(int(ny - prev_y)) + seg_width * 2 + 20), pygame.SRCALPHA)
            ox = seg_width + 10 - min(0, int(nx - prev_x))
            oy = seg_width + 10 - min(0, int(ny - prev_y))
            p1 = (ox + max(0, int(prev_x - min(prev_x, nx))), oy + max(0, int(prev_y - min(prev_y, ny))))
            p2 = (ox + max(0, int(nx - min(prev_x, nx))), oy + max(0, int(ny - min(prev_y, ny))))

            pygame.draw.line(ts, (*self.colors['tendril'], alpha), p1, p2, seg_width)
            screen.blit(ts, (int(min(prev_x, nx)) - seg_width - 10, int(min(prev_y, ny)) - seg_width - 10))

            prev_x, prev_y = nx, ny

    def _draw_dissolve(self, screen):
        """분해 애니메이션 렌더링"""
        progress = min(1.0, self.dissolve_timer / self.dissolve_duration)

        # 1. 증발 연기 (먹물이 기화되는 효과)
        for wisp in self.dissolve_wisps:
            if self.dissolve_timer < wisp['delay']:
                continue
            a = int(max(0, min(255, wisp['alpha'])))
            if a < 3:
                continue
            s = max(1, int(wisp['size']))
            ws = pygame.Surface((s * 2 + 4, s * 2 + 4), pygame.SRCALPHA)
            wc = s + 2
            # 연기 (여러 겹 반투명 원)
            pygame.draw.circle(ws, (*self.colors['ink_outer'], int(a * 0.3)), (wc, wc), s)
            pygame.draw.circle(ws, (*self.colors['ink_mid'], int(a * 0.5)), (wc, wc), max(1, int(s * 0.7)))
            pygame.draw.circle(ws, (*self.colors['ink_core'], int(a * 0.4)), (wc, wc), max(1, int(s * 0.4)))
            screen.blit(ws, (int(wisp['x']) - wc, int(wisp['y']) - wc))

        # 2. 파편 (먹물 조각이 흩어지며 사라짐)
        for frag in self.dissolve_fragments:
            a = int(max(0, min(255, frag['alpha'])))
            s = max(1, int(frag['size']))
            if a < 3 or s < 1:
                continue

            fs = pygame.Surface((s * 2 + 6, s * 2 + 6), pygame.SRCALPHA)
            fc = s + 3

            # 불규칙 형태 회전
            points = []
            rot_rad = math.radians(frag['rotation'])
            for angle_i in range(0, 360, 45):
                rad = math.radians(angle_i)
                r = s * (0.6 + 0.4 * math.sin(rad * 2 + frag['shape_seed']))
                px = math.cos(rad + rot_rad) * r
                py = math.sin(rad + rot_rad) * r
                points.append((int(fc + px), int(fc + py)))

            if len(points) >= 3:
                pygame.draw.polygon(fs, (*self.colors['ink_core'], a), points)
                # 외곽 글로우
                pygame.draw.polygon(fs, (*self.colors['ink_glow'], int(a * 0.3)), points, max(1, s // 4))

            screen.blit(fs, (int(frag['x']) - fc, int(frag['y']) - fc))

        # 3. 전체 영역 잔상 (서서히 사라지는 영역 글로우)
        if progress < 0.7:
            wr = int(self.splash_max_radius * self.splash_width_scale)
            hr = int(self.splash_max_radius)
            fade_a = int(30 * (1 - progress / 0.7))
            if fade_a > 2:
                gs = pygame.Surface((wr * 2 + 20, hr * 2 + 20), pygame.SRCALPHA)
                gcx, gcy = wr + 10, hr + 10
                pygame.draw.ellipse(gs, (*self.colors['ink_outer'], fade_a),
                                   (10, 10, wr * 2, hr * 2))
                screen.blit(gs, (int(self.splash_center_x - gcx), int(self.splash_center_y - gcy)))

    def reset_for_new_round(self, game_state: dict):
        """라운드 전환 시 심해의 먹물 스킬 강제 종료"""
        super().reset_for_new_round(game_state)
        self.ink_blobs = []
        self.ink_bubbles = []
        self.ink_tendrils = []
        self.phase = 'travel'
        self.projectile_progress = 0.0
        self.splash_timer = 0
        self.active_timer = 0
        self._trail_particles = []
        self._proj_blobs = []
        self.splash_droplets = []
        self.dissolving = False
        self.dissolve_timer = 0.0
        self.dissolve_fragments = []
        self.dissolve_wisps = []
        if self.confusion_applied:
            target_prefix = 'top_paddle' if self.target_is_top else 'bottom_paddle'
            game_state[f'{target_prefix}_confused'] = False
            game_state['target_confused'] = False
            self.confusion_applied = False


# ============================================================================
# 키르케 스킬 - 흑마녀 여성 (수비적)
# ============================================================================
class GravityControl(HeroSkill):
    """중력가속 - 공을 무겁게 만들어 계속 아래로 끌어당김"""
    def __init__(self):
        super().__init__(
            skill_id="gravity_control",
            name="Gravity Accel",
            korean_name="중력가속",
            description="중력을 조작하여 공이 계속 아래로 끌려가게 만든다",
            trigger=SkillTrigger.ON_COOLDOWN,
            cooldown=25.0,
            duration=2.5,  # 2.5초 지속
            hero_id="chronos"
        )
        self.gravity_particles = []  # 중력 이펙트 파티클
        self.distortion_lines = []  # 왜곡선
        self.pulse_timer = 0
        self.ball_attract_strength = 35  # 공이 상대 패들 X좌표로 끌리는 힘 (px/s²)

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        # 중력 효과 활성화
        game_state['gravity_control_active'] = True
        self.pulse_timer = 0

        # 중력 방향 결정 (caster_is_top 속성 사용)
        # 상단에서 발동 → 중력 아래로 (상대 하단에게 불리)
        # 하단에서 발동 → 중력 위로 (상대 상단에게 불리)
        is_caster_top = getattr(self, 'caster_is_top', caster_paddle.is_top)
        self.gravity_direction = 1 if is_caster_top else -1  # 1=아래, -1=위

        # 초기 파티클 생성
        self.gravity_particles = []
        self.distortion_lines = []

        # 화면 전체에 중력 방향 파티클 생성
        for _ in range(40):
            # 파티클 속도: 중력 방향에 따라 아래 또는 위로
            particle_vy = random.uniform(150, 300) * self.gravity_direction
            self.gravity_particles.append({
                'x': random.uniform(80, 680),
                'y': random.uniform(-50, 750),
                'vy': particle_vy,
                'size': random.randint(2, 5),
                'alpha': random.randint(100, 200),
                'color': random.choice([
                    (100, 80, 180),   # 보라
                    (80, 60, 150),    # 진한 보라
                    (120, 100, 200),  # 연한 보라
                    (60, 40, 120),    # 어두운 보라
                ])
            })

        # 왜곡선 생성 (중력장 표현)
        for i in range(8):
            self.distortion_lines.append({
                'y': i * 100,
                'amplitude': random.uniform(5, 15),
                'frequency': random.uniform(0.02, 0.04),
                'phase': random.uniform(0, math.pi * 2),
                'alpha': random.randint(40, 80)
            })

        return {
            'screen_effect': ScreenEffect.FLASH,
            'flash_color': (100, 80, 180),  # 보라색 플래시
            'flash_duration': 0.2,
            'sound': 'gravityaccel'
        }

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        self.pulse_timer += dt

        # 중력 방향 (1=아래, -1=위)
        gravity_dir = getattr(self, 'gravity_direction', 1)

        # 🌍 핵심: 공에 중력 적용 (방향에 따라 위 또는 아래로)
        if hasattr(ball, 'vy'):
            gravity_force = 48 * dt * gravity_dir  # 중력 방향 적용 (20% 약화: 60 → 48)
            # 중력 방향으로 가는 중이면 70%, 반대면 100% 적용
            if (ball.vy > 0 and gravity_dir > 0) or (ball.vy < 0 and gravity_dir < 0):
                ball.vy += gravity_force * 0.7  # 70% 적용 (너무 빠르게 가속 방지)
            else:  # 반대 방향 - 강한 중력으로 속도 감속
                ball.vy += gravity_force  # 100% 적용 → 공이 점점 느려지다가 방향 전환

        # 🧲 공을 상대 패들의 X좌표로 끌어당기는 자력 효과
        if hasattr(ball, 'vx') and hasattr(target_paddle, 'x'):
            paddle_center_x = target_paddle.x + getattr(target_paddle, 'width', 80) // 2
            dx = paddle_center_x - ball.x
            # 거리에 비례하는 인력 (멀수록 약하게, 가까울수록 강하게)
            if abs(dx) > 5:  # 최소 거리 이상일 때만
                attract_dir = 1 if dx > 0 else -1
                # 거리가 가까울수록 강하게 (최대 200px 기준 정규화)
                proximity = min(1.0, abs(dx) / 200.0)
                attract_force = self.ball_attract_strength * attract_dir * (0.4 + 0.6 * proximity)
                ball.vx += attract_force * dt

        # 파티클 업데이트 (중력 방향으로 이동)
        for p in self.gravity_particles:
            p['y'] += p['vy'] * dt
            # 화면 밖으로 나가면 반대쪽에서 다시 생성
            if gravity_dir > 0 and p['y'] > 800:  # 아래로 중력
                p['y'] = random.uniform(-50, -10)
                p['x'] = random.uniform(80, 680)
            elif gravity_dir < 0 and p['y'] < -50:  # 위로 중력
                p['y'] = random.uniform(760, 810)
                p['x'] = random.uniform(80, 680)

        # 왜곡선 업데이트
        for line in self.distortion_lines:
            line['phase'] += dt * 3
            line['y'] += 50 * dt * gravity_dir  # 중력 방향으로 이동
            if gravity_dir > 0 and line['y'] > 800:
                line['y'] = -50
            elif gravity_dir < 0 and line['y'] < -50:
                line['y'] = 800

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        game_state['gravity_control_active'] = False
        self.gravity_particles = []
        self.distortion_lines = []

    def reset_for_new_round(self, game_state: dict):
        """라운드 전환 시 중력조절 효과 초기화"""
        super().reset_for_new_round(game_state)
        game_state['gravity_control_active'] = False
        self.gravity_particles = []
        self.distortion_lines = []
        self.pulse_timer = 0

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        if not self.is_active:
            return

        # 어두운 보라색 오버레이 (중력장 분위기)
        overlay = pygame.Surface((760, 750), pygame.SRCALPHA)
        overlay.fill((60, 40, 100, 30))
        screen.blit(overlay, (0, 0))

        # 왜곡선 그리기 (중력장 시각화)
        for line in self.distortion_lines:
            points = []
            for x in range(80, 680, 10):
                wave_y = line['y'] + math.sin(x * line['frequency'] + line['phase']) * line['amplitude']
                points.append((x, int(wave_y)))
            if len(points) > 1:
                surf = pygame.Surface((600, 30), pygame.SRCALPHA)
                for i in range(len(points) - 1):
                    px1, py1 = points[i][0] - 80, 15
                    px2, py2 = points[i + 1][0] - 80, 15
                    pygame.draw.line(surf, (120, 100, 200, line['alpha']),
                                   (px1, py1), (px2, py2), 2)
                screen.blit(surf, (80, int(line['y']) - 15))

        # 하강 파티클 그리기
        for p in self.gravity_particles:
            if 0 < p['y'] < 750:
                # 꼬리 효과 (위쪽으로 잔상)
                for i in range(3):
                    tail_y = p['y'] - i * 8
                    tail_alpha = p['alpha'] // (i + 1)
                    tail_size = max(1, p['size'] - i)
                    if tail_alpha > 20:
                        pygame.draw.circle(screen, (*p['color'][:3], tail_alpha),
                                         (int(p['x']), int(tail_y)), tail_size)

        # 공 주변 중력 오라
        if hasattr(ball, 'x') and hasattr(ball, 'y'):
            # 펄스 효과
            pulse = abs(math.sin(self.pulse_timer * 4)) * 0.5 + 0.5
            for i in range(3):
                radius = int(20 + i * 12 + pulse * 8)
                alpha = int(60 - i * 15)
                surf = pygame.Surface((radius * 2, radius * 2), pygame.SRCALPHA)
                pygame.draw.circle(surf, (100, 80, 180, alpha), (radius, radius), radius, 2)
                screen.blit(surf, (int(ball.x - radius), int(ball.y - radius)))

            # 하향 화살표 표시
            arrow_y_offset = int(math.sin(self.pulse_timer * 6) * 5)
            arrow_points = [
                (int(ball.x), int(ball.y + 25 + arrow_y_offset)),
                (int(ball.x - 8), int(ball.y + 15 + arrow_y_offset)),
                (int(ball.x + 8), int(ball.y + 15 + arrow_y_offset))
            ]
            pygame.draw.polygon(screen, (150, 120, 220), arrow_points)

        # 🧲 공 ↔ 상대 패들 자력 연결 이펙트
        if hasattr(ball, 'x') and hasattr(ball, 'y') and hasattr(target_paddle, 'x'):
            paddle_cx = target_paddle.x + getattr(target_paddle, 'width', 80) // 2
            paddle_cy = target_paddle.y + getattr(target_paddle, 'height', 20) // 2
            bx, by = int(ball.x), int(ball.y)

            # 공과 패들 사이 자력선 (보라색 에너지 줄)
            dist = math.hypot(paddle_cx - bx, paddle_cy - by)
            if dist > 10:
                num_segments = max(3, int(dist / 40))
                for i in range(num_segments):
                    t = i / num_segments
                    # 보간 위치 + 사인파 흔들림
                    mx = bx + (paddle_cx - bx) * t
                    my = by + (paddle_cy - by) * t
                    wave = math.sin(t * math.pi * 3 + self.pulse_timer * 8) * (8 + 6 * t)
                    mx += wave
                    seg_alpha = int((80 + 60 * t) * abs(math.sin(self.pulse_timer * 3 + t * 2)))
                    seg_alpha = max(20, min(200, seg_alpha))
                    seg_size = max(2, int(3 + 2 * t))
                    seg_surf = pygame.Surface((seg_size * 2, seg_size * 2), pygame.SRCALPHA)
                    pygame.draw.circle(seg_surf, (140, 100, 220, seg_alpha),
                                     (seg_size, seg_size), seg_size)
                    screen.blit(seg_surf, (int(mx - seg_size), int(my - seg_size)))

            # 상대 패들 주변 자력 오라 (공이 끌려오는 느낌)
            aura_pulse = abs(math.sin(self.pulse_timer * 4)) * 0.5 + 0.5
            for r in range(2):
                aura_r = int(25 + r * 15 + aura_pulse * 10)
                a = max(20, int(70 - r * 25))
                aura_s = pygame.Surface((aura_r * 2, aura_r * 2), pygame.SRCALPHA)
                pygame.draw.circle(aura_s, (120, 80, 200, a), (aura_r, aura_r), aura_r, 2)
                screen.blit(aura_s, (int(paddle_cx - aura_r), int(paddle_cy - aura_r)))


class DwarfMagic(HeroSkill):
    """난쟁이마술 - 보라색 빛가루로 상대 패들 축소"""
    def __init__(self):
        super().__init__(
            skill_id="dwarf_magic",
            name="Dwarf Magic",
            korean_name="난쟁이마술",
            description="보라색 빛가루를 발사해 상대 패들을 축소시킨다",
            trigger=SkillTrigger.ON_BALL_HIT,
            cooldown=12.0,
            duration=4.0,  # 4초 지속
            hero_id="chronos"
        )
        self.magic_particles = []  # 보라색 빛가루 파티클
        self.projectile_active = False
        self.projectile_x = 0
        self.projectile_y = 0
        self.projectile_vy = 0
        self.hit_target = False
        self.shrink_timer = 0
        self.shrunk_target_is_top = None  # 축소된 타겟 기억용

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        # 보라색 빛가루 투사체 발사
        self.projectile_active = True
        self.projectile_x = caster_paddle.x + caster_paddle.width // 2
        self.projectile_y = caster_paddle.y
        # 상대 방향으로 발사 (위 또는 아래) - 속도 30% 증가 (8 → 10)
        if caster_paddle.is_top:
            self.projectile_vy = 10  # 위에서 아래로
        else:
            self.projectile_vy = -10  # 아래에서 위로

        self.hit_target = False
        self.shrink_timer = 0
        self.magic_particles = []

        # 발사 시 빛가루 파티클 생성
        for _ in range(20):
            self.magic_particles.append({
                'x': self.projectile_x + random.randint(-15, 15),
                'y': self.projectile_y + random.randint(-15, 15),
                'vx': random.uniform(-2, 2),
                'vy': random.uniform(-2, 2),
                'size': random.randint(3, 8),
                'alpha': 255,
                'life': random.uniform(0.5, 1.5)
            })

        return {
            'screen_effect': ScreenEffect.FLASH,
            'flash_color': (180, 100, 220),  # 보라색 플래시
            'flash_duration': 0.15,
            'sound': 'magic_cast'
        }

    def update(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        """스킬 업데이트 - 오버라이드하여 shrink_timer를 is_active와 별개로 처리"""
        # 부모 클래스의 쿨타임 처리
        if self.current_cooldown > 0:
            self.current_cooldown -= dt

        # 활성 효과 업데이트 (투사체 이동)
        if self.is_active:
            self.active_timer -= dt
            self._update_active_effect(dt, caster_paddle, target_paddle, ball, game_state)
            if self.active_timer <= 0:
                self._end_effect(caster_paddle, target_paddle, ball, game_state)
                self.is_active = False

        # ★ 핵심: shrink_timer는 is_active와 별개로 항상 처리
        # (투사체 명중 후 is_active가 False가 되어도 축소 효과는 유지되어야 함)
        if self.hit_target and self.shrink_timer > 0:
            self.shrink_timer -= dt
            if self.shrink_timer <= 0:
                # 축소 효과 해제 - 저장된 타겟 정보 사용
                target_prefix = 'top_paddle' if self.shrunk_target_is_top else 'bottom_paddle'
                game_state[f'{target_prefix}_shrink'] = False
                game_state[f'{target_prefix}_shrink_scale'] = 1.0
                self.hit_target = False
                self.shrunk_target_is_top = None

        # 파티클 업데이트 (is_active와 관계없이)
        for p in self.magic_particles[:]:
            p['x'] += p['vx']
            p['y'] += p['vy']
            p['life'] -= dt
            p['alpha'] = max(0, int(255 * (p['life'] / 1.0)))
            if p['life'] <= 0:
                self.magic_particles.remove(p)

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        # 투사체 이동
        if self.projectile_active and not self.hit_target:
            self.projectile_y += self.projectile_vy

            # 🎯 45% 유도 효과 - 타겟 패들 방향으로 추적
            target_center_x = target_paddle.x + target_paddle.width // 2
            dx = target_center_x - self.projectile_x
            homing_strength = 0.45  # 45% 유도 (기존 30%에서 15% 증가)
            self.projectile_x += dx * homing_strength * dt * 3  # 부드럽게 추적

            # 투사체 주변에 빛가루 파티클 추가
            if random.random() < 0.5:
                self.magic_particles.append({
                    'x': self.projectile_x + random.randint(-10, 10),
                    'y': self.projectile_y + random.randint(-10, 10),
                    'vx': random.uniform(-1.5, 1.5),
                    'vy': random.uniform(-1.5, 1.5),
                    'size': random.randint(2, 6),
                    'alpha': 255,
                    'life': random.uniform(0.3, 0.8)
                })

            # 타겟 패들과 충돌 체크
            paddle_left = target_paddle.x
            paddle_right = target_paddle.x + target_paddle.width
            paddle_top = target_paddle.y
            paddle_bottom = target_paddle.y + target_paddle.height

            if (paddle_left - 15 < self.projectile_x < paddle_right + 15 and
                paddle_top - 15 < self.projectile_y < paddle_bottom + 15):
                # 명중!
                self.hit_target = True
                self.projectile_active = False
                self.shrink_timer = 4.0  # 4초 지속
                self.shrunk_target_is_top = target_paddle.is_top  # 축소된 타겟 기억

                # 타겟 패들 50% 축소 적용
                target_prefix = 'top_paddle' if target_paddle.is_top else 'bottom_paddle'
                game_state[f'{target_prefix}_shrink'] = True
                game_state[f'{target_prefix}_shrink_scale'] = 0.5  # 50% 축소

                # 명중 시 파티클 폭발
                for _ in range(30):
                    self.magic_particles.append({
                        'x': self.projectile_x,
                        'y': self.projectile_y,
                        'vx': random.uniform(-5, 5),
                        'vy': random.uniform(-5, 5),
                        'size': random.randint(4, 10),
                        'alpha': 255,
                        'life': random.uniform(0.5, 1.2)
                    })

            # 화면 밖으로 나가면 비활성화
            if self.projectile_y < 0 or self.projectile_y > 750:
                self.projectile_active = False

        # NOTE: shrink_timer와 파티클 업데이트는 update() 메서드에서 처리
        # (is_active가 False가 되어도 계속 처리되어야 하므로)

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        # 투사체, 파티클, 오라가 있으면 그리기 (is_active와 무관하게)
        has_visuals = self.projectile_active or self.magic_particles or (self.hit_target and self.shrink_timer > 0)
        if not self.is_active and not has_visuals:
            return

        # 보라색 빛가루 투사체 그리기
        if self.projectile_active:
            # 메인 투사체 (보라색 빛 덩어리)
            for r in range(3, 0, -1):
                alpha = 100 + r * 50
                size = 8 + r * 4
                surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                color = (180, 100, 220, alpha)  # 보라색
                pygame.draw.circle(surf, color, (size, size), size)
                screen.blit(surf, (int(self.projectile_x - size), int(self.projectile_y - size)))

            # 투사체 중심 (밝은 보라색)
            pygame.draw.circle(screen, (220, 180, 255),
                             (int(self.projectile_x), int(self.projectile_y)), 5)

        # 파티클 그리기
        for p in self.magic_particles:
            if p['alpha'] > 20:
                p_size = max(1, int(p['size']))
                surf = pygame.Surface((p_size * 2, p_size * 2), pygame.SRCALPHA)
                # 보라색 계열 (다양한 밝기) - 정수로 변환
                r = random.randint(150, 200)
                g = random.randint(80, 130)
                b = random.randint(180, 240)
                a = max(0, min(255, int(p['alpha'])))
                pygame.draw.circle(surf, (r, g, b, a),
                                 (p_size, p_size), p_size)
                screen.blit(surf, (int(p['x'] - p_size), int(p['y'] - p_size)))

        # 축소 효과 활성화 시 타겟에 보라색 오라
        if self.hit_target and self.shrink_timer > 0:
            aura_alpha = int(100 * (self.shrink_timer / 4.0))
            paddle_cx = target_paddle.x + target_paddle.width // 2
            paddle_cy = target_paddle.y + target_paddle.height // 2
            for i in range(3):
                size = 30 + i * 15
                surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                pygame.draw.circle(surf, (180, 100, 220, aura_alpha // (i + 1)),
                                 (size, size), size, 2)
                screen.blit(surf, (int(paddle_cx - size), int(paddle_cy - size)))

    def reset_for_new_round(self, game_state: dict):
        """라운드 전환 시 난쟁이마술 효과 초기화"""
        super().reset_for_new_round(game_state)
        # 투사체 제거
        self.magic_particles = []
        self.projectile_active = False
        self.hit_target = False
        self.shrink_timer = 0
        self.shrunk_target_is_top = None  # 타겟 정보 초기화
        # 패들 축소 효과 해제
        game_state['top_paddle_shrink'] = False
        game_state['top_paddle_shrink_scale'] = 1.0
        game_state['bottom_paddle_shrink'] = False
        game_state['bottom_paddle_shrink_scale'] = 1.0


# ============================================================================
# 오니마루 스킬 - 지옥의 요괴무사 (공격적)
# ============================================================================
class HellFire(HeroSkill):
    """도깨비불 - 1초 정지 + 도깨비 얼굴 글리치 후 공이 도깨비불처럼 변하며 자유자재로 움직임"""

    # 페이즈 상수
    PHASE_NONE = 0        # 비활성
    PHASE_FREEZE = 1      # 화면 정지 + 도깨비 얼굴 글리치 (1초)
    PHASE_RELEASE = 2     # 정지 해제 + 가속 적용
    PHASE_ACTIVE = 3      # 도깨비불 상태 유지

    def __init__(self):
        super().__init__(
            skill_id="hell_fire",
            name="Dokkaebi Fire",
            korean_name="도깨비불",
            description="공이 도깨비불로 변해 예측 불가능하게 움직인다",
            trigger=SkillTrigger.ON_BALL_HIT,
            cooldown=10.0,
            duration=4.0,  # 정지 1초 + 도깨비불 3초
            hero_id="onimaru"
        )
        # 페이즈 관리
        self.phase = self.PHASE_NONE
        self.phase_timer = 0.0
        self.freeze_duration = 1.0  # 1초 정지

        self.fire_particles = []
        self.flame_intensity = 0

        # 공 위치 (정지 중 표시용)
        self.ball_x = 0
        self.ball_y = 0

        # 공 속도 저장 (정지 전)
        self.original_ball_vx = 0
        self.original_ball_vy = 0

        # 도깨비 얼굴 글리치 효과용
        self.glitch_timer = 0.0
        self.glitch_lines = []  # 글리치 라인 오프셋
        self.face_alpha_pulse = 0.0

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        # 공 위치/속도 저장 (정지 전)
        self.ball_x = ball.x
        self.ball_y = ball.y
        self.original_ball_vx = ball.vx
        self.original_ball_vy = ball.vy
        self.caster_is_top = caster_paddle.is_top

        # === 페이즈 1: 화면 정지 시작 ===
        self.phase = self.PHASE_FREEZE
        self.phase_timer = 0.0
        self.glitch_timer = 0.0
        self.flame_intensity = 1.0

        # 화면 정지 플래그
        game_state['hell_fire_freeze'] = True
        game_state['hell_fire_phase'] = self.PHASE_FREEZE

        # 글리치 라인 초기화
        self._regenerate_glitch_lines()

        self.fire_particles = []

        print(f"[HellFire] 스킬 발동! freeze=True, phase=FREEZE, ball=({ball.x:.0f},{ball.y:.0f})")

        return {
            'screen_effect': ScreenEffect.FIRE,
            'screen_tint': (100, 200, 255),
            'sound': 'hellfire'
        }

    def _regenerate_glitch_lines(self):
        """글리치 라인 오프셋 재생성"""
        self.glitch_lines = []
        for _ in range(random.randint(4, 9)):
            self.glitch_lines.append({
                'y_offset': random.randint(-75, 75),
                'x_shift': random.randint(-36, 36),
                'height': random.randint(3, 12),
                'color_shift': random.choice([(255, 50, 50), (50, 255, 50), (50, 50, 255)]),
            })

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        self.phase_timer += dt

        if self.phase == self.PHASE_FREEZE:
            # === 화면 정지 (1초) ===
            self.glitch_timer += dt

            # 글리치 라인 주기적 재생성 (0.08초마다)
            if self.glitch_timer % 0.08 < dt:
                self._regenerate_glitch_lines()

            # 도깨비 얼굴 알파 맥동
            self.face_alpha_pulse = 0.5 + 0.3 * math.sin(self.glitch_timer * 12)
            # 간헐적 플래시 (글리치 느낌)
            if random.random() < 0.08:
                self.face_alpha_pulse = random.uniform(0.8, 1.0)

            # 정지 해제
            if self.phase_timer >= self.freeze_duration:
                self.phase = self.PHASE_RELEASE
                self.phase_timer = 0.0
                game_state['hell_fire_freeze'] = False
                game_state['hell_fire_phase'] = self.PHASE_RELEASE
                # 도깨비불 메인 사운드 재생
                try:
                    import os
                    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                    hfm_path = os.path.join(project_root, "sounds", "hellfiremain.wav")
                    if os.path.exists(hfm_path):
                        pygame.mixer.Sound(hfm_path).play()
                except Exception:
                    pass
                print(f"[HellFire] FREEZE → RELEASE 전환 (1초 정지 종료)")

        elif self.phase == self.PHASE_RELEASE:
            # === 정지 해제 - 가속 + 도깨비불 상태 적용 ===
            ball.vx = self.original_ball_vx * 1.3
            # 방향 강제: 캐스터 반대쪽으로 (재충돌 방지)
            if self.caster_is_top:
                ball.vy = abs(self.original_ball_vy) * 1.3   # 아래로 (상대 쪽)
                ball.y = max(ball.y, 80)  # 패들에서 충분히 떨어뜨리기
            else:
                ball.vy = -abs(self.original_ball_vy) * 1.3  # 위로 (상대 쪽)
                ball.y = min(ball.y, 670)  # 패들에서 충분히 떨어뜨리기
            game_state['ball_on_fire'] = True
            game_state['dokkaebi_ball'] = True
            game_state['hell_fire_phase'] = self.PHASE_ACTIVE

            self.phase = self.PHASE_ACTIVE
            self.phase_timer = 0.0
            self.dokkaebi_time = 0
            print(f"[HellFire] RELEASE → ACTIVE (vy={ball.vy:.1f}, caster_top={self.caster_is_top})")

        elif self.phase == self.PHASE_ACTIVE:
            # === 도깨비불 활성 상태 (기존 로직) ===
            self.flame_intensity = max(0, self.flame_intensity - dt * 0.3)

            self.dokkaebi_time = getattr(self, 'dokkaebi_time', 0) + dt

            # 사인파 기반 곡선 움직임
            wave_intensity = 150
            wave_speed = 8
            curve_force = math.sin(self.dokkaebi_time * wave_speed) * wave_intensity * dt
            ball.vx += curve_force

            # 간헐적 급격한 방향 전환 (10% 확률)
            if random.random() < 0.10:
                angle_change = random.uniform(-0.3, 0.3)
                cos_a = math.cos(angle_change)
                sin_a = math.sin(angle_change)
                new_vx = ball.vx * cos_a - ball.vy * sin_a
                new_vy = ball.vx * sin_a + ball.vy * cos_a
                ball.vx = new_vx
                ball.vy = new_vy

            # 불꽃 파티클
            if random.random() < 0.5:
                self.fire_particles.append({
                    'x': ball.x + random.uniform(-10, 10),
                    'y': ball.y + random.uniform(-10, 10),
                    'vx': random.uniform(-30, 30),
                    'vy': random.uniform(-80, -20),
                    'life': 0.5,
                    'size': random.uniform(4, 10)
                })

            # 파티클 업데이트
            for p in self.fire_particles:
                p['x'] += p['vx'] * dt
                p['y'] += p['vy'] * dt
                p['life'] -= dt
                p['size'] *= 0.95
            self.fire_particles = [p for p in self.fire_particles if p['life'] > 0]

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        game_state['ball_on_fire'] = False
        game_state['dokkaebi_ball'] = False
        game_state['hell_fire_freeze'] = False
        game_state['hell_fire_phase'] = self.PHASE_NONE
        self.fire_particles = []
        self.dokkaebi_time = 0
        self.phase = self.PHASE_NONE

    def reset(self):
        super().reset()
        self.phase = self.PHASE_NONE
        self.phase_timer = 0.0
        self.glitch_timer = 0.0
        self.glitch_lines = []
        self.fire_particles = []
        self.flame_intensity = 0

    def reset_for_new_round(self, game_state: dict):
        """라운드 전환 시 도깨비불 스킬 강제 종료"""
        super().reset_for_new_round(game_state)
        game_state['ball_on_fire'] = False
        game_state['dokkaebi_ball'] = False
        game_state['hell_fire_freeze'] = False
        game_state['hell_fire_phase'] = self.PHASE_NONE
        self.phase = self.PHASE_NONE
        self.fire_particles = []
        self.flame_intensity = 0
        self.dokkaebi_time = 0
        self.glitch_timer = 0.0
        self.glitch_lines = []
        print("[HellFire] 라운드 전환 - 도깨비불 초기화")

    def _draw_dokkaebi_face(self, screen: pygame.Surface, bx: int, by: int):
        """공 위에 반투명 도깨비 얼굴을 글리치하게 그리기"""
        face_size = 150  # 얼굴 크기 (3배)
        face_surf = pygame.Surface((face_size * 2, face_size * 2), pygame.SRCALPHA)
        cx, cy = face_size, face_size  # 중심

        # 도깨비 색상 (푸른 불빛)
        base_alpha = int(255 * self.face_alpha_pulse)
        face_color = (80, 200, 255, min(255, int(base_alpha * 0.4)))  # 반투명
        eye_color = (255, 100, 50, min(255, int(base_alpha * 0.7)))  # 붉은 눈
        horn_color = (100, 220, 255, min(255, int(base_alpha * 0.5)))

        # === 뿔 (2개) ===
        # 왼쪽 뿔
        pygame.draw.polygon(face_surf, horn_color, [
            (cx - 54, cy - 45),
            (cx - 72, cy - 114),
            (cx - 30, cy - 54),
        ])
        # 오른쪽 뿔
        pygame.draw.polygon(face_surf, horn_color, [
            (cx + 54, cy - 45),
            (cx + 72, cy - 114),
            (cx + 30, cy - 54),
        ])

        # === 얼굴 윤곽 (둥근 사각) ===
        pygame.draw.ellipse(face_surf, face_color,
                           (cx - 66, cy - 48, 132, 108))

        # === 눈 (무서운 삼각형 눈) ===
        # 왼쪽 눈
        pygame.draw.polygon(face_surf, eye_color, [
            (cx - 48, cy - 12),
            (cx - 18, cy - 30),
            (cx - 18, cy + 6),
        ])
        # 오른쪽 눈
        pygame.draw.polygon(face_surf, eye_color, [
            (cx + 48, cy - 12),
            (cx + 18, cy - 30),
            (cx + 18, cy + 6),
        ])

        # === 입 (크게 벌린 입 - 톱니 모양) ===
        mouth_color = (60, 180, 255, min(255, int(base_alpha * 0.6)))
        teeth_color = (255, 255, 255, min(255, int(base_alpha * 0.5)))
        # 입 배경
        pygame.draw.ellipse(face_surf, mouth_color,
                           (cx - 42, cy + 18, 84, 36))
        # 이빨 (톱니)
        for tx in range(-30, 33, 15):
            pygame.draw.polygon(face_surf, teeth_color, [
                (cx + tx - 6, cy + 18),
                (cx + tx + 6, cy + 18),
                (cx + tx, cy + 30),
            ])

        # === 글리치 효과 적용 ===
        glitched_surf = pygame.Surface((face_size * 2, face_size * 2), pygame.SRCALPHA)

        # 글리치 라인별 수평 이동
        for y_line in range(face_size * 2):
            # 기본 복사
            glitch_offset = 0
            for gl in self.glitch_lines:
                if abs(y_line - (face_size + gl['y_offset'])) < gl['height']:
                    glitch_offset = gl['x_shift']
                    break

            # 라인 복사 + 오프셋
            if glitch_offset != 0:
                for x_px in range(face_size * 2):
                    src_x = x_px - glitch_offset
                    if 0 <= src_x < face_size * 2:
                        color = face_surf.get_at((src_x, y_line))
                        if color[3] > 0:
                            glitched_surf.set_at((x_px, y_line), color)
            else:
                # 오프셋 없으면 원본 그대로
                glitched_surf.blit(face_surf, (0, y_line),
                                  (0, y_line, face_size * 2, 1))

        # === RGB 분리 효과 (크로마틱 어버레이션) ===
        if random.random() < 0.4:
            rgb_offset = random.randint(3, 9)
            rgb_surf = pygame.Surface((face_size * 2, face_size * 2), pygame.SRCALPHA)
            # 빨간 채널 오프셋
            rgb_surf.blit(glitched_surf, (rgb_offset, 0))
            rgb_surf.fill((255, 0, 0, 30), special_flags=pygame.BLEND_RGBA_MULT)
            screen.blit(rgb_surf, (bx - face_size + rgb_offset, by - face_size),
                       special_flags=pygame.BLEND_ADD)

        # 메인 얼굴 그리기
        screen.blit(glitched_surf, (bx - face_size, by - face_size),
                   special_flags=pygame.BLEND_ADD)

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        if not self.is_active:
            return

        bx, by = int(self.ball_x), int(self.ball_y)

        # === 정지 중 이펙트 ===
        if self.phase == self.PHASE_FREEZE:
            # 어두운 푸른 오버레이 (맥동)
            darkness = pygame.Surface((760, 750), pygame.SRCALPHA)
            pulse = 0.5 + 0.3 * math.sin(self.glitch_timer * 8)
            darkness.fill((0, 10, 30, int(180 * pulse)))
            screen.blit(darkness, (0, 0))

            # === 도깨비 얼굴 (공 위에, 반투명 + 글리치) ===
            self._draw_dokkaebi_face(screen, bx, by)

            # 공 주변 불꽃 아우라 (정지 중에도 희미하게)
            aura_size = 75 + int(24 * math.sin(self.glitch_timer * 6))
            aura_surf = pygame.Surface((aura_size * 2, aura_size * 2), pygame.SRCALPHA)
            aura_alpha = int(60 * pulse)
            pygame.draw.circle(aura_surf, (80, 200, 255, aura_alpha),
                              (aura_size, aura_size), aura_size)
            screen.blit(aura_surf, (bx - aura_size, by - aura_size),
                       special_flags=pygame.BLEND_ADD)

            # 간헐적 화면 글리치 라인 (화면 전체)
            if random.random() < 0.15:
                gy = random.randint(0, 750)
                gh = random.randint(1, 4)
                glitch_bar = pygame.Surface((760, gh), pygame.SRCALPHA)
                glitch_bar.fill((80, 200, 255, random.randint(20, 60)))
                screen.blit(glitch_bar, (random.randint(-5, 5), gy))

        # === 도깨비불 활성 상태 이펙트 ===
        elif self.phase == self.PHASE_ACTIVE:
            # 화면 푸른 틴트
            if self.flame_intensity > 0:
                overlay = pygame.Surface((760, 750), pygame.SRCALPHA)
                overlay.fill((50, 150, 255, int(30 * self.flame_intensity)))
                screen.blit(overlay, (0, 0))

            # 도깨비불 파티클
            for p in self.fire_particles:
                if p['size'] > 1:
                    life_ratio = p['life'] / 0.5
                    r = int(100 * life_ratio)
                    g = int(220 * life_ratio)
                    b = 255
                    alpha = int(200 * life_ratio)

                    surf = pygame.Surface((int(p['size'] * 2), int(p['size'] * 2)), pygame.SRCALPHA)
                    pygame.draw.circle(surf, (r, g, b, alpha),
                                      (int(p['size']), int(p['size'])), int(p['size']))
                    screen.blit(surf, (int(p['x'] - p['size']), int(p['y'] - p['size'])),
                               special_flags=pygame.BLEND_ADD)


class HornCharge(HeroSkill):
    """뿔 박치기 - 돌진 후 상대 넉백 + 스턴"""

    # Phase 상수
    PHASE_CHARGING = 0    # 상대에게 돌진
    PHASE_IMPACT = 1      # 충돌 + 넉백
    PHASE_RETURNING = 2   # 원래 위치로 복귀
    PHASE_STUN = 3        # 스턴 지속

    def __init__(self):
        super().__init__(
            skill_id="horn_charge",
            name="Horn Charge",
            korean_name="뿔 박치기",
            description="빠르게 돌진하여 상대를 밀어내고 스턴시킨다",
            trigger=SkillTrigger.ON_COOLDOWN,
            cooldown=25.0,
            duration=3.0,  # 돌진 0.3초 + 충돌 0.2초 + 복귀 0.5초 + 양측 스턴 1초
            hero_id="onimaru"
        )
        self.shockwave_radius = 0
        self.knockback_applied = False
        self.phase = self.PHASE_CHARGING
        self.phase_timer = 0

        # 위치 저장
        self.caster_original_y = 0
        self.caster_is_top = True
        self.target_is_top = False
        self.charge_progress = 0  # 0~1 돌진 진행도
        self.return_progress = 0  # 0~1 복귀 진행도

        # 충돌 지점
        self.impact_y = 0
        self.stun_applied = False
        self.caster_stun_applied = False  # 시전자 스턴 적용 여부

        # 돌진 잔상 효과
        self.afterimages = []

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        self.shockwave_radius = 0
        self.knockback_applied = False
        self.stun_applied = False
        self.caster_stun_applied = False
        self.phase = self.PHASE_CHARGING
        self.phase_timer = 0
        self.charge_progress = 0
        self.return_progress = 0
        self.afterimages = []
        self.impact_shockwave_triggered = False  # 착지 충격파 트리거
        self.impact_shockwave_radius = 0
        self.impact_shockwave_alpha = 255

        # 시전자 위치 정보 저장
        self.caster_is_top = getattr(self, 'caster_is_top', caster_paddle.is_top)
        self.target_is_top = not self.caster_is_top
        self.caster_original_y = caster_paddle.y
        self.caster_original_x = caster_paddle.x
        self.caster_x = caster_paddle.x

        # 타겟 위치 예측 (돌진 시간 0.3초 후 타겟이 있을 위치)
        charge_duration = 0.3  # 돌진 시간
        target_velocity_x = game_state.get('target_velocity_x', 0)  # 타겟의 X 속도

        # 현재 타겟 위치
        current_target_x = target_paddle.x + target_paddle.width // 2

        # 예측 위치 계산 (현재 위치 + 속도 * 시간)
        predicted_x = current_target_x + target_velocity_x * charge_duration

        # 게임 영역 경계 제한 (투기장: 0 ~ 760)
        GAME_LEFT = 0
        GAME_RIGHT = 760
        predicted_x = max(GAME_LEFT + target_paddle.width // 2,
                         min(GAME_RIGHT - target_paddle.width // 2, predicted_x))

        self.target_x = predicted_x  # 예측된 타겟 X 위치
        self.target_y = target_paddle.y  # 타겟 Y
        self.impact_x = predicted_x  # 착지 충격파 위치

        # 충돌 지점 계산 (타겟 패들과 정확히 겹침)
        if self.caster_is_top:
            self.impact_y = target_paddle.y  # 타겟과 정확히 같은 Y
        else:
            self.impact_y = target_paddle.y  # 타겟과 정확히 같은 Y

        # 넉백 방향 설정 (타겟이 이동 중이면 반대 방향으로)
        if target_velocity_x > 50:
            knockback_dir = -1  # 오른쪽으로 이동 중이면 왼쪽으로 넉백
        elif target_velocity_x < -50:
            knockback_dir = 1   # 왼쪽으로 이동 중이면 오른쪽으로 넉백
        else:
            knockback_dir = 1 if random.random() > 0.5 else -1
        self.knockback_dir = knockback_dir

        # game_state에 돌진 오프셋 정보 초기화
        game_state['horn_charge_active'] = True
        game_state['horn_charge_caster_is_top'] = self.caster_is_top
        game_state['horn_charge_y_offset'] = 0
        game_state['horn_charge_x_offset'] = 0  # X 오프셋 추가 (타겟 위치로 이동)
        game_state['horn_charge_apply_knockback'] = False  # 넉백 적용 신호 (착지 시 True)
        game_state['horn_charge_knockback_dir'] = 0
        game_state['horn_charge_knockback_vel'] = 0
        game_state['horn_charge_target_is_top'] = self.target_is_top
        game_state['horn_charge_impact_shockwave'] = None  # 충격파 이펙트 데이터

        return {
            'screen_effect': ScreenEffect.FLASH,
            'flash_color': (255, 100, 50),
            'flash_duration': 0.1,
            'sound': 'horncharge'
        }

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        self.phase_timer += dt

        if self.phase == self.PHASE_CHARGING:
            # 돌진 (0.43초) - 속도 30% 감소 (0.3 / 0.7 ≈ 0.43)
            charge_duration = 0.43
            self.charge_progress = min(1.0, self.phase_timer / charge_duration)

            # 🎯 타겟의 실시간 위치 추적 (매 프레임 업데이트)
            real_target_x = target_paddle.x + target_paddle.width // 2
            self.target_x = real_target_x
            self.impact_x = real_target_x
            self.impact_y = target_paddle.y

            # 이징 함수 (가속)
            eased_progress = self.charge_progress * self.charge_progress

            # Y 오프셋 계산 (game_state를 통해 전달)
            y_offset = (self.impact_y - self.caster_original_y) * eased_progress
            game_state['horn_charge_y_offset'] = y_offset

            # X 오프셋 계산 (타겟의 실시간 위치로 이동)
            x_offset = (self.target_x - self.caster_original_x) * eased_progress
            game_state['horn_charge_x_offset'] = x_offset

            current_y = self.caster_original_y + y_offset
            current_x = self.caster_original_x + x_offset

            # 돌진 완료 → 충돌 페이즈
            if self.charge_progress >= 1.0:
                # 착지 시점에 타겟의 정확한 중앙 위치로 스냅
                self.target_x = target_paddle.x + target_paddle.width // 2
                self.impact_x = self.target_x
                self.impact_y = target_paddle.y
                self.phase = self.PHASE_IMPACT
                self.phase_timer = 0
                # 🔥 화면 흔들림 강화 (다이너마이트급)
                game_state['screen_shake'] = 40
                game_state['shake_duration'] = 0.4
                # 폭발 파티클 트리거
                game_state['horn_charge_explosion'] = {
                    'x': self.target_x,
                    'y': self.impact_y,
                    'trigger': True
                }
                print(f"🐂 [HORN CHARGE] 착지 완료! target_x={self.target_x}, impact_y={self.impact_y}")

        elif self.phase == self.PHASE_IMPACT:
            # 충돌 + 넉백 (0.2초)
            self.shockwave_radius += dt * 1200  # 빠른 충격파

            # X, Y 오프셋 유지 (충돌 지점 = 타겟 위치)
            game_state['horn_charge_y_offset'] = self.impact_y - self.caster_original_y
            game_state['horn_charge_x_offset'] = self.target_x - self.caster_original_x

            # 🔥 착지 충격파 이펙트 트리거 (최초 1회) - 0.2초 안에 완료
            if not self.impact_shockwave_triggered:
                self.impact_shockwave_triggered = True
                self.impact_shockwave_radius = 0
                self.impact_shockwave_alpha = 255
                # 충격파 이펙트 데이터를 game_state에 저장 (다중 링 + 파티클)
                game_state['horn_charge_impact_shockwave'] = {
                    'x': self.target_x,
                    'y': self.impact_y,
                    'rings': [
                        {'radius': 0, 'alpha': 255, 'width': 8},   # 메인 링 (두껍게)
                        {'radius': 0, 'alpha': 220, 'width': 5},   # 서브 링 1
                        {'radius': 0, 'alpha': 180, 'width': 3},   # 서브 링 2
                    ],
                    'particles': [],
                    'active': True,
                    'timer': 0,
                    'max_radius': 120  # 최대 반경
                }
                # 충격파 파티클 생성 (빠르게 퍼짐)
                import random
                for _ in range(25):
                    angle = random.uniform(0, 6.28)
                    speed = random.uniform(8, 15)  # 더 빠른 속도
                    game_state['horn_charge_impact_shockwave']['particles'].append({
                        'x': self.target_x,
                        'y': self.impact_y,
                        'vx': math.cos(angle) * speed,
                        'vy': math.sin(angle) * speed,
                        'life': random.randint(8, 15),  # 짧은 수명 (0.2초 내)
                        'size': random.randint(4, 8)
                    })

            # 착지 충격파 애니메이션 업데이트 (0.2초 완료)
            shockwave_data = game_state.get('horn_charge_impact_shockwave', {})
            if shockwave_data.get('active'):
                shockwave_data['timer'] += dt
                max_radius = shockwave_data.get('max_radius', 120)
                # 다중 링 업데이트 (빠르게 확장 - 0.2초 내 완료)
                for i, ring in enumerate(shockwave_data.get('rings', [])):
                    delay = i * 0.02  # 각 링마다 0.02초 딜레이 (더 빠른 시차)
                    if shockwave_data['timer'] > delay:
                        ring['radius'] += dt * 800  # 매우 빠른 확장 (0.15초에 120px)
                        # 반경에 따른 페이드아웃 (최대 반경에서 완전 투명)
                        ring['alpha'] = max(0, int(255 * (1 - ring['radius'] / max_radius)))
                # 파티클 업데이트
                for p in shockwave_data.get('particles', []):
                    p['x'] += p['vx']
                    p['y'] += p['vy']
                    p['vy'] += 0.5  # 강한 중력
                    p['life'] -= 1
                # 죽은 파티클 제거
                shockwave_data['particles'] = [p for p in shockwave_data.get('particles', []) if p['life'] > 0]
                # 0.2초 경과 또는 모든 이펙트 완료 시 비활성화
                all_rings_done = all(ring['alpha'] <= 0 for ring in shockwave_data.get('rings', []))
                if shockwave_data['timer'] >= 0.25 or (all_rings_done and not shockwave_data.get('particles')):
                    shockwave_data['active'] = False

            # 넉백 즉시 적용 (다이너마이트 폭발과 동일한 방식)
            if not self.knockback_applied:
                # 넉백 신호 전달 (pingfighter.py에서 player_knockback_vel 적용)
                # 기존 104에서 30% 감소 → 73
                game_state['horn_charge_apply_knockback'] = True
                game_state['horn_charge_knockback_dir'] = self.knockback_dir
                game_state['horn_charge_knockback_vel'] = 73  # 30% 감소 (104 → 73)
                game_state['horn_charge_target_is_top'] = self.target_is_top
                self.knockback_applied = True
                print(f"🐂 [HORN CHARGE] IMPACT 페이즈 진입 - 넉백 신호 전송! dir={self.knockback_dir}, vel=73, target_is_top={self.target_is_top}")

            # 충돌 페이즈 종료 → 복귀
            if self.phase_timer >= 0.2:
                self.phase = self.PHASE_RETURNING
                self.phase_timer = 0

        elif self.phase == self.PHASE_RETURNING:
            # 복귀 (0.5초)
            return_duration = 0.5
            self.return_progress = min(1.0, self.phase_timer / return_duration)

            # 이징 함수 (감속)
            eased_progress = 1 - (1 - self.return_progress) * (1 - self.return_progress)

            # Y 오프셋 계산 (복귀)
            impact_y_offset = self.impact_y - self.caster_original_y
            y_offset = impact_y_offset * (1 - eased_progress)
            game_state['horn_charge_y_offset'] = y_offset

            # X 오프셋 계산 (복귀)
            impact_x_offset = self.target_x - self.caster_original_x
            x_offset = impact_x_offset * (1 - eased_progress)
            game_state['horn_charge_x_offset'] = x_offset

            # 복귀 완료 → 스턴 페이즈
            if self.return_progress >= 1.0:
                game_state['horn_charge_y_offset'] = 0
                game_state['horn_charge_x_offset'] = 0
                self.phase = self.PHASE_STUN
                self.phase_timer = 0

                # 스턴 적용 (타겟 + 시전자 모두)
                if not self.stun_applied:
                    target_prefix = 'top_paddle' if self.target_is_top else 'bottom_paddle'
                    game_state[f'{target_prefix}_stunned'] = True
                    self.stun_applied = True
                if not self.caster_stun_applied:
                    caster_prefix = 'top_paddle' if self.caster_is_top else 'bottom_paddle'
                    game_state[f'{caster_prefix}_stunned'] = True
                    self.caster_stun_applied = True

        elif self.phase == self.PHASE_STUN:
            # 스턴 지속 (1초) - 타겟 + 시전자 모두
            game_state['horn_charge_y_offset'] = 0  # 원위치
            if self.phase_timer >= 1.0:
                # 스턴 해제 (타겟 + 시전자)
                target_prefix = 'top_paddle' if self.target_is_top else 'bottom_paddle'
                game_state[f'{target_prefix}_stunned'] = False
                caster_prefix = 'top_paddle' if self.caster_is_top else 'bottom_paddle'
                game_state[f'{caster_prefix}_stunned'] = False

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        game_state['screen_shake'] = 0
        game_state['target_knockback'] = 0
        # 돌진 오프셋 초기화
        game_state['horn_charge_active'] = False
        game_state['horn_charge_y_offset'] = 0
        game_state['horn_charge_x_offset'] = 0
        game_state['horn_charge_apply_knockback'] = False
        # 스턴 해제 (타겟 + 시전자)
        target_prefix = 'top_paddle' if self.target_is_top else 'bottom_paddle'
        game_state[f'{target_prefix}_stunned'] = False
        caster_prefix = 'top_paddle' if self.caster_is_top else 'bottom_paddle'
        game_state[f'{caster_prefix}_stunned'] = False
        self.afterimages = []

    def reset_for_new_round(self, game_state: dict):
        """라운드 전환 시 뿔 박치기 스킬 강제 종료"""
        super().reset_for_new_round(game_state)
        game_state['screen_shake'] = 0
        game_state['target_knockback'] = 0
        game_state['horn_charge_active'] = False
        game_state['horn_charge_y_offset'] = 0
        game_state['horn_charge_x_offset'] = 0
        game_state['horn_charge_apply_knockback'] = False
        game_state['top_paddle_stunned'] = False
        game_state['bottom_paddle_stunned'] = False
        self.phase = self.PHASE_CHARGING
        self.afterimages = []

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        if not self.is_active:
            return

        # 현재 시전자 Y 위치 계산
        y_offset = game_state.get('horn_charge_y_offset', 0)
        current_caster_y = self.caster_original_y + y_offset

        # 충돌 시 충격파
        if self.phase == self.PHASE_IMPACT and self.shockwave_radius < 300:
            center_x = self.caster_x + 40
            center_y = current_caster_y + 20

            alpha = int(255 * (1 - self.shockwave_radius / 300))
            if alpha > 10:
                # 충격파 링 (더 강렬하게)
                for r_offset in [0, 15, 30, 45]:
                    radius = int(self.shockwave_radius - r_offset)
                    if radius > 0:
                        ring_alpha = max(0, int(alpha * (1 - r_offset / 60)))
                        # SRCALPHA Surface로 그리기
                        ring_surf = pygame.Surface((radius * 2 + 10, radius * 2 + 10), pygame.SRCALPHA)
                        pygame.draw.circle(ring_surf, (255, 100, 50, ring_alpha),
                                         (radius + 5, radius + 5), radius, 5)
                        screen.blit(ring_surf, (int(center_x - radius - 5), int(center_y - radius - 5)))

        # 스턴 표시 (별 아이콘)
        if self.phase == self.PHASE_STUN and self.stun_applied:
            stun_x = target_paddle.x + 40
            stun_y = target_paddle.y - 30
            stun_time = self.phase_timer * 5

            for i in range(3):
                angle = stun_time + i * (2 * math.pi / 3)
                star_x = stun_x + math.cos(angle) * 25
                star_y = stun_y + math.sin(angle) * 10
                # 별 모양
                star_surf = pygame.Surface((20, 20), pygame.SRCALPHA)
                pygame.draw.polygon(star_surf, (255, 255, 100, 200), [
                    (10, 0), (12, 7), (20, 7), (14, 12), (16, 20), (10, 15), (4, 20), (6, 12), (0, 7), (8, 7)
                ])
                screen.blit(star_surf, (int(star_x - 10), int(star_y - 10)))


# ============================================================================
# 연화 스킬 - 인형사 (트릭형)
# ============================================================================
class PuppetControl(HeroSkill):
    """꼭두각시 조종 - 실로 상대를 끌어와 뽀뽀"""

    # Phase 상수
    PHASE_EXTENDING = 0   # 실이 뻗어나가는 중
    PHASE_PULLING = 1     # 상대를 끌어당기는 중
    PHASE_KISSING = 2     # 뽀뽀 중
    PHASE_RETURNING = 3   # 원래 위치로 복귀 중

    def __init__(self):
        super().__init__(
            skill_id="puppet_control",
            name="Puppet Control",
            korean_name="꼭두각시 조종",
            description="실로 상대를 끌어와 뽀뽀한 후 돌려보낸다",
            trigger=SkillTrigger.ON_COOLDOWN,
            cooldown=35.0,
            duration=3.62,  # 총 3.62초: 뻗기 0.7초 + 끌기 1.083초 + 뽀뽀 1초 + 복귀 0.833초 (이동 20% 빠르게)
            hero_id="maria"
        )
        self.strings = []
        self.phase = self.PHASE_EXTENDING
        self.phase_timer = 0
        self.target_is_top = False

        # 위치 저장
        self.target_original_x = 0
        self.target_original_y = 0
        self.caster_x = 0
        self.caster_y = 0

        # 실 뻗어나가기 진행도 (0~1)
        self.string_extend_progress = 0

        # 뽀뽀 이펙트
        self.kiss_hearts = []
        self.kiss_sparkles = []

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        self.target_is_top = target_paddle.is_top
        self.phase = self.PHASE_EXTENDING
        self.phase_timer = 0
        self.string_extend_progress = 0

        # 위치 저장
        self.target_original_x = target_paddle.x
        self.target_original_y = target_paddle.y
        self.caster_x = caster_paddle.x
        self.caster_y = caster_paddle.y

        # 실 초기화 (5개의 실)
        self.strings = []
        for i in range(5):
            self.strings.append({
                'offset_x': -20 + i * 10,  # 연화 손에서의 오프셋
                'wave': random.uniform(0, math.pi * 2),
                'thickness': 2 + random.randint(0, 1)
            })

        # 뽀뽀 이펙트 초기화
        self.kiss_hearts = []
        self.kiss_sparkles = []

        # 연화 고정
        caster_prefix = 'top_paddle' if caster_paddle.is_top else 'bottom_paddle'
        game_state[f'{caster_prefix}_locked'] = True
        game_state[f'{caster_prefix}_locked_x'] = self.caster_x
        game_state[f'{caster_prefix}_locked_y'] = self.caster_y

        # 타겟 패들도 고정 (Y축 이동을 위해)
        target_prefix = 'top_paddle' if target_paddle.is_top else 'bottom_paddle'
        game_state[f'{target_prefix}_locked'] = True
        game_state[f'{target_prefix}_locked_x'] = self.target_original_x
        game_state[f'{target_prefix}_locked_y'] = self.target_original_y

        return {
            'target_status': StatusEffect.PUPPET,
            'status_duration': self.duration,
            'sound': 'tentacle'
        }

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        self.phase_timer += dt

        # 연화 위치 고정 (X축 및 Y축)
        caster_paddle.x = self.caster_x
        caster_paddle.y = self.caster_y

        # 타겟 패들 prefix
        target_prefix = 'top_paddle' if target_paddle.is_top else 'bottom_paddle'

        # 실 물결 업데이트
        for s in self.strings:
            s['wave'] += dt * 4

        # Phase 1: 실 뻗어나가기 (0.7초)
        if self.phase == self.PHASE_EXTENDING:
            self.string_extend_progress = min(1.0, self.phase_timer / 0.7)

            # 실이 상대에게 도달하면 다음 단계
            if self.string_extend_progress >= 1.0:
                self.phase = self.PHASE_PULLING
                self.phase_timer = 0
                game_state['target_puppeted'] = True
                # 붙잡기 사운드 재생
                try:
                    import os
                    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                    grab_path = os.path.join(project_root, "sounds", "grab.wav")
                    if os.path.exists(grab_path):
                        pygame.mixer.Sound(grab_path).play()
                except Exception:
                    pass

        # Phase 2: 상대 끌어당기기 (1.083초, 기존 1.3초에서 20% 빠르게)
        elif self.phase == self.PHASE_PULLING:
            pull_progress = min(1.0, self.phase_timer / 1.083)
            # 이징 함수로 부드럽게
            eased = 1 - (1 - pull_progress) ** 2

            # 연화 근처로 끌어옴 (Y축) - 연화 방향으로 크게 당김
            kiss_y = self.caster_y + (-60 if not caster_paddle.is_top else 60)
            new_y = self.target_original_y + (kiss_y - self.target_original_y) * eased
            target_paddle.y = new_y

            # X축도 연화 위치로
            new_x = self.target_original_x + (self.caster_x - self.target_original_x) * eased
            target_paddle.x = new_x

            # game_state에도 반영 (pingfighter.py에서 BOSS/PLAYER에 강제 적용)
            game_state[f'{target_prefix}_locked_x'] = new_x
            game_state[f'{target_prefix}_locked_y'] = new_y

            if pull_progress >= 1.0:
                self.phase = self.PHASE_KISSING
                self.phase_timer = 0
                # 뽀뽀 사운드 재생
                try:
                    import os
                    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                    kiss_path = os.path.join(project_root, "sounds", "kissing.wav")
                    if os.path.exists(kiss_path):
                        pygame.mixer.Sound(kiss_path).play()
                except Exception:
                    pass

        # Phase 3: 뽀뽀 (1초)
        elif self.phase == self.PHASE_KISSING:
            # 뽀뽀 중 타겟 위치 고정 유지
            kiss_y = self.caster_y + (-60 if not caster_paddle.is_top else 60)
            target_paddle.x = self.caster_x
            target_paddle.y = kiss_y
            game_state[f'{target_prefix}_locked_x'] = self.caster_x
            game_state[f'{target_prefix}_locked_y'] = kiss_y

            # 하트 파티클 생성
            if random.random() < 0.3:
                kiss_x = self.caster_x + 40
                particle_kiss_y = self.caster_y + (-30 if not caster_paddle.is_top else 30)
                self.kiss_hearts.append({
                    'x': kiss_x + random.uniform(-20, 20),
                    'y': particle_kiss_y + random.uniform(-15, 15),
                    'vy': random.uniform(-40, -20) if not caster_paddle.is_top else random.uniform(20, 40),
                    'size': random.uniform(6, 12),
                    'life': 1.0,
                    'wobble': random.uniform(0, math.pi * 2)
                })

            # 반짝이 파티클
            if random.random() < 0.4:
                kiss_x = self.caster_x + 40
                particle_kiss_y = self.caster_y + (-30 if not caster_paddle.is_top else 30)
                self.kiss_sparkles.append({
                    'x': kiss_x + random.uniform(-30, 30),
                    'y': particle_kiss_y + random.uniform(-20, 20),
                    'life': 0.5,
                    'size': random.uniform(2, 5)
                })

            if self.phase_timer >= 1.0:
                self.phase = self.PHASE_RETURNING
                self.phase_timer = 0

        # Phase 4: 원래 위치로 복귀 (0.833초, 기존 1초에서 20% 빠르게)
        elif self.phase == self.PHASE_RETURNING:
            return_progress = min(1.0, self.phase_timer / 0.833)
            eased = return_progress ** 2  # ease-in

            # 현재 위치에서 원래 위치로
            kiss_y = self.caster_y + (-60 if not caster_paddle.is_top else 60)
            new_y = kiss_y + (self.target_original_y - kiss_y) * eased
            new_x = self.caster_x + (self.target_original_x - self.caster_x) * eased
            target_paddle.y = new_y
            target_paddle.x = new_x
            game_state[f'{target_prefix}_locked_x'] = new_x
            game_state[f'{target_prefix}_locked_y'] = new_y

        # 하트/반짝이 업데이트
        for h in self.kiss_hearts:
            h['y'] += h['vy'] * dt
            h['wobble'] += dt * 5
            h['x'] += math.sin(h['wobble']) * 20 * dt
            h['life'] -= dt * 0.8
        self.kiss_hearts = [h for h in self.kiss_hearts if h['life'] > 0]

        for sp in self.kiss_sparkles:
            sp['life'] -= dt * 2
        self.kiss_sparkles = [sp for sp in self.kiss_sparkles if sp['life'] > 0]

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        game_state['target_puppeted'] = False

        # 연화 고정 해제
        caster_prefix = 'top_paddle' if caster_paddle.is_top else 'bottom_paddle'
        game_state[f'{caster_prefix}_locked'] = False

        # 타겟 패들 고정 해제
        target_prefix = 'top_paddle' if target_paddle.is_top else 'bottom_paddle'
        game_state[f'{target_prefix}_locked'] = False

        # 상대 원래 위치로 확실히 복귀
        target_paddle.x = self.target_original_x
        target_paddle.y = self.target_original_y

        self.strings = []
        self.kiss_hearts = []
        self.kiss_sparkles = []
        self.phase = self.PHASE_EXTENDING

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        if not self.is_active:
            return

        hand_x = self.caster_x + 40
        hand_y = self.caster_y + (-25 if not caster_paddle.is_top else 25)

        # 실 그리기
        for s in self.strings:
            string_start_x = hand_x + s['offset_x']

            # 실 끝점 계산 (phase에 따라)
            if self.phase == self.PHASE_EXTENDING:
                # 뻗어나가는 중: 진행도에 따라 끝점 계산
                end_x = string_start_x + (target_paddle.x + 40 + s['offset_x'] - string_start_x) * self.string_extend_progress
                end_y = hand_y + (target_paddle.y - hand_y) * self.string_extend_progress
            else:
                # 연결됨: 상대 패들 위치
                end_x = target_paddle.x + 40 + s['offset_x']
                end_y = target_paddle.y

            # 물결치는 실 그리기
            points = []
            segments = 20
            for i in range(segments + 1):
                prog = i / segments

                # 실이 뻗어나가는 중일 때 끝부분 물결 감소
                wave_strength = 12 * (1 - prog * 0.5)
                if self.phase == self.PHASE_EXTENDING:
                    wave_strength *= self.string_extend_progress

                wave = math.sin(prog * math.pi * 3 + s['wave']) * wave_strength

                x = string_start_x + (end_x - string_start_x) * prog + wave
                y = hand_y + (end_y - hand_y) * prog
                points.append((int(x), int(y)))

            if len(points) > 1:
                # 실 색상 (분홍-보라 그라데이션 느낌)
                color = (180, 100, 150) if self.phase < self.PHASE_KISSING else (255, 150, 180)
                pygame.draw.lines(screen, color, False, points, s['thickness'])

        # 연화 손 위치에 작은 원 (실 잡는 곳)
        pygame.draw.circle(screen, (150, 80, 120), (int(hand_x), int(hand_y)), 8)
        pygame.draw.circle(screen, (200, 120, 160), (int(hand_x), int(hand_y)), 5)

        # Phase에 따른 추가 이펙트
        if self.phase == self.PHASE_KISSING:
            # 뽀뽀 중: 하트 그리기
            for h in self.kiss_hearts:
                self._draw_heart(screen, int(h['x']), int(h['y']), h['size'], int(255 * h['life']))

            # 반짝이
            for sp in self.kiss_sparkles:
                alpha = int(255 * sp['life'])
                size = int(sp['size'])
                sparkle_surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                pygame.draw.circle(sparkle_surf, (255, 255, 200, alpha), (size, size), size)
                screen.blit(sparkle_surf, (int(sp['x']) - size, int(sp['y']) - size))

            # "CHU~" 텍스트 효과
            kiss_x = int(self.caster_x + 60)
            kiss_y = int(self.caster_y + (-50 if not caster_paddle.is_top else 50))
            font_size = 16
            try:
                font = pygame.font.Font(None, font_size)
                text = font.render("CHU~", True, (255, 150, 200))
                screen.blit(text, (kiss_x, kiss_y))
            except:
                pass

        elif self.phase == self.PHASE_PULLING:
            # 끌어당기는 중: 긴장감 있는 실 이펙트
            # 중앙에 집중선 효과
            center_x = (hand_x + target_paddle.x + 40) / 2
            center_y = (hand_y + target_paddle.y) / 2
            for _ in range(3):
                angle = random.uniform(0, math.pi * 2)
                length = random.uniform(20, 40)
                end_x = center_x + math.cos(angle) * length
                end_y = center_y + math.sin(angle) * length
                pygame.draw.line(screen, (255, 200, 220, 100),
                               (int(center_x), int(center_y)),
                               (int(end_x), int(end_y)), 1)

    def _draw_heart(self, screen, x, y, size, alpha):
        """하트 모양 그리기"""
        heart_surf = pygame.Surface((int(size * 2), int(size * 2)), pygame.SRCALPHA)
        color = (255, 100, 150, alpha)

        # 간단한 하트: 두 원 + 삼각형
        r = size * 0.5
        pygame.draw.circle(heart_surf, color, (int(size - r * 0.5), int(size - r * 0.3)), int(r))
        pygame.draw.circle(heart_surf, color, (int(size + r * 0.5), int(size - r * 0.3)), int(r))
        points = [
            (int(size - r * 1.2), int(size - r * 0.1)),
            (int(size + r * 1.2), int(size - r * 0.1)),
            (int(size), int(size + r * 1.2))
        ]
        pygame.draw.polygon(heart_surf, color, points)

        screen.blit(heart_surf, (x - int(size), y - int(size)))

    def reset_for_new_round(self, game_state: dict):
        """라운드 전환 시 꼭두각시 조종 스킬 강제 종료"""
        super().reset_for_new_round(game_state)
        # 실과 이펙트 제거
        self.strings = []
        self.phase = self.PHASE_EXTENDING
        self.phase_timer = 0
        self.string_extend_progress = 0
        self.kiss_hearts = []
        self.kiss_sparkles = []
        # 패들 고정 해제
        game_state['top_paddle_locked'] = False
        game_state['bottom_paddle_locked'] = False
        if 'top_paddle_locked_x' in game_state:
            del game_state['top_paddle_locked_x']
        if 'top_paddle_locked_y' in game_state:
            del game_state['top_paddle_locked_y']
        if 'bottom_paddle_locked_x' in game_state:
            del game_state['bottom_paddle_locked_x']
        if 'bottom_paddle_locked_y' in game_state:
            del game_state['bottom_paddle_locked_y']


class DollCurse(HeroSkill):
    """인형의 저주 - 상대 조작 반전 + 수호 인형으로 공 방어"""
    def __init__(self):
        super().__init__(
            skill_id="doll_curse",
            name="Doll Curse",
            korean_name="인형의 저주",
            description="저주받은 인형으로 상대의 조작을 반전시키고, 수호 인형이 공을 막는다",
            trigger=SkillTrigger.ON_BALL_HIT,
            cooldown=18.0,
            duration=4.0,
            hero_id="maria"
        )
        self.curse_dolls = []
        self.target_is_top = False
        # 연화 고정 위치 및 불꽃 이펙트
        self.caster_locked_x = 0
        self.caster_locked_y = 0
        self.flame_particles = []
        self.flame_timer = 0
        # 수호 인형 (연화 좌우 150px에 생성, 공을 막음)
        self.guardian_dolls = []
        self.guardian_offset = 150  # 연화로부터의 거리
        self.guardian_size = 30  # 수호 인형 충돌 반경

    def _get_hero_body_position(self, paddle, b=8):
        """영웅 이미지의 실제 몸통 위치 계산 (hero_paddles.py와 동기화)"""
        paddle_width = getattr(paddle, 'width', 80)
        center_x = paddle.x + paddle_width // 2

        if paddle.is_top:
            cy = paddle.y + int(3.5 * b)
            torso_y = cy - int(1.5 * b)
        else:
            cy = paddle.y + int(2.0 * b)
            torso_y = cy - int(1.5 * b)

        return center_x, torso_y, cy, b

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        self.target_is_top = target_paddle.is_top
        game_state['target_confused'] = True
        game_state['confusion_type'] = 'reverse'  # 조작 반전

        # 연화(caster) 제자리 고정 (X축 및 Y축 모두)
        self.caster_locked_x = caster_paddle.x
        self.caster_locked_y = caster_paddle.y
        # 캐릭터 스프라이트 중심 위치 저장 (centerx 사용)
        self.caster_centerx = getattr(caster_paddle, 'centerx', caster_paddle.x + 40)
        self.caster_is_top = caster_paddle.is_top
        caster_prefix = 'top_paddle' if caster_paddle.is_top else 'bottom_paddle'
        game_state[f'{caster_prefix}_locked'] = True
        game_state[f'{caster_prefix}_locked_x'] = self.caster_locked_x
        game_state[f'{caster_prefix}_locked_y'] = self.caster_locked_y

        # 저주 인형 이펙트 - 상대 영웅 이미지 주변에서 시작
        target_cx, target_torso_y, _, _ = self._get_hero_body_position(target_paddle)
        self.curse_dolls = []
        for i in range(3):
            angle = (i / 3) * math.pi * 2 + random.uniform(-0.3, 0.3)
            distance = random.uniform(40, 80)
            self.curse_dolls.append({
                'x': target_cx + math.cos(angle) * distance,
                'y': target_torso_y + math.sin(angle) * distance,
                'base_angle': angle,
                'distance': distance,
                'rotation': random.uniform(0, 360),
                'scale': random.uniform(0.6, 1.0),
                'wobble': random.uniform(0, math.pi * 2),
                'orbit_speed': random.uniform(0.5, 1.2),
                'float_offset': random.uniform(0, math.pi * 2)
            })

        # 연화 주변 불꽃 파티클 초기화
        self.flame_particles = []
        self.flame_timer = 0

        # 수호 인형 생성 (바닥에서 솟아오르며 연화 좌우 150px에 배치)
        self.guardian_dolls = []
        caster_center_x = self.caster_centerx
        # 연화 앞쪽 Y 좌표 (공이 오는 방향) - 목표 위치
        if caster_paddle.is_top:
            guardian_target_y = self.caster_locked_y + 60  # 상단 영웅이면 아래쪽에
            guardian_spawn_y = 750 + 50  # 화면 바닥 아래에서 시작
        else:
            guardian_target_y = self.caster_locked_y - 60  # 하단 영웅이면 위쪽에 (공이 오는 방향)
            guardian_spawn_y = -50  # 화면 상단 위에서 시작 (바닥에서 솟아오르는 느낌)

        # 왼쪽 수호 인형
        self.guardian_dolls.append({
            'x': caster_center_x - self.guardian_offset,  # X는 바로 목표 위치
            'y': guardian_spawn_y,  # Y는 바닥에서 시작
            'spawn_y': guardian_spawn_y,  # 시작 Y 위치 (바닥)
            'target_y': guardian_target_y,  # 목표 Y 위치
            'spawn_x': caster_center_x - self.guardian_offset,  # X 시작 = 목표 (좌우 이동 없음)
            'target_x': caster_center_x - self.guardian_offset,
            'spawn_progress': 0.0,  # 생성 애니메이션 진행도 (0~1)
            'wobble': 0,
            'scale': 1.2,
            'side': 'left',
            'hit_flash': 0  # 공 막았을 때 플래시 효과
        })
        # 오른쪽 수호 인형
        self.guardian_dolls.append({
            'x': caster_center_x + self.guardian_offset,
            'y': guardian_spawn_y,
            'spawn_y': guardian_spawn_y,
            'target_y': guardian_target_y,
            'spawn_x': caster_center_x + self.guardian_offset,
            'target_x': caster_center_x + self.guardian_offset,
            'spawn_progress': 0.0,
            'wobble': math.pi,  # 반대 위상으로 흔들림
            'scale': 1.2,
            'side': 'right',
            'hit_flash': 0
        })

        # game_state에 수호 인형 정보 저장 (pingfighter에서 충돌 체크용)
        game_state['doll_curse_guardians'] = self.guardian_dolls
        game_state['doll_curse_guardian_size'] = self.guardian_size
        game_state['doll_curse_active'] = True

        return {
            'target_status': StatusEffect.CONFUSION,
            'confusion_type': 'reverse',
            'status_duration': self.duration,
            'screen_effect': ScreenEffect.FLASH,
            'flash_color': (180, 50, 100),
            'sound': 'dollcurse'
        }

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        # 연화(caster) 제자리 고정 유지 (X축 및 Y축 모두)
        caster_paddle.x = self.caster_locked_x
        caster_paddle.y = self.caster_locked_y

        # 저주 인형들 상대 영웅 이미지 주변에서 천천히 공전
        for doll in self.curse_dolls:
            doll['wobble'] += dt * 3
            doll['base_angle'] += dt * doll['orbit_speed']
            doll['float_offset'] += dt * 2

            # 상대 영웅 이미지 중심 기준 공전 (hero_paddles.py와 동기화)
            target_cx, target_torso_y, _, _ = self._get_hero_body_position(target_paddle)
            float_y = math.sin(doll['float_offset']) * 8  # 위아래 둥실둥실
            doll['x'] = target_cx + math.cos(doll['base_angle']) * doll['distance']
            doll['y'] = target_torso_y + math.sin(doll['base_angle']) * doll['distance'] * 0.5 + float_y
            doll['rotation'] += math.sin(doll['wobble']) * 3

        # 수호 인형 업데이트 (바닥에서 솟아오르며 연화 좌우에서 공 막기)
        for guardian in self.guardian_dolls:
            # 생성 애니메이션 (바닥에서 솟아오름)
            if guardian['spawn_progress'] < 1.0:
                guardian['spawn_progress'] += dt * 2.0  # 0.5초에 완료 (약간 느리게)
                guardian['spawn_progress'] = min(1.0, guardian['spawn_progress'])
                # 이징 함수 (ease-out cubic - 처음 빠르고 끝에 감속)
                ease = 1 - (1 - guardian['spawn_progress']) ** 3
                # Y축 솟아오르기 애니메이션
                guardian['y'] = guardian['spawn_y'] + (guardian['target_y'] - guardian['spawn_y']) * ease
                # X축은 그대로 유지 (좌우 위치는 이미 설정됨)
                guardian['x'] = guardian['spawn_x'] + (guardian['target_x'] - guardian['spawn_x']) * ease
            else:
                # 솟아오르기 완료 후: 위아래 둥실둥실 흔들림
                guardian['wobble'] += dt * 4
                float_y = math.sin(guardian['wobble']) * 5
                guardian['y'] = guardian['target_y'] + float_y

            # 히트 플래시 감소
            if guardian['hit_flash'] > 0:
                guardian['hit_flash'] -= dt * 3

            # 공과 충돌 체크 (수호 인형이 공을 막음)
            if ball and guardian['spawn_progress'] >= 0.8:  # 거의 배치 완료 후 충돌 활성화
                dx = ball.x - guardian['x']
                dy = ball.y - guardian['y']
                dist = math.sqrt(dx * dx + dy * dy)
                collision_radius = self.guardian_size + 5  # 공 반경 포함

                if dist < collision_radius:
                    # 공 반사!
                    if dist > 0:
                        # 반사 방향 계산
                        nx = dx / dist
                        ny = dy / dist
                        # 공 속도 반사 (game_state를 통해 전달)
                        game_state['doll_guardian_ball_bounce'] = {
                            'nx': nx,
                            'ny': ny,
                            'guardian_x': guardian['x'],
                            'guardian_y': guardian['y']
                        }
                        guardian['hit_flash'] = 1.0  # 히트 이펙트

        # game_state 업데이트 (pingfighter에서 충돌 체크용)
        game_state['doll_curse_guardians'] = self.guardian_dolls

        # 연화 주변 불꽃 파티클 생성 (캐릭터 스프라이트 위치에)
        self.flame_timer += dt
        if self.flame_timer > 0.05:  # 0.05초마다 파티클 생성
            self.flame_timer = 0
            # 캐릭터 스프라이트 중심 위치 계산 (b=8 스케일 기준)
            # hero_paddles.py에서 draw_hero_paddle은 centerx를 받아서 그림
            # 상단 영웅: cy = y + 3.5*b = y + 28, 하단 영웅: cy = y + 0.5*b = y + 4
            # 캐릭터 몸통은 cy에서 그려지고, 높이는 약 6*b (48px)
            caster_center_x = self.caster_centerx
            if self.caster_is_top:
                # 상단 영웅: 캐릭터가 패들 아래에 그려짐
                # cy = y + 28, 머리~발: cy-24 ~ cy+24
                caster_center_y = self.caster_locked_y + 28  # 캐릭터 중심
            else:
                # 하단 영웅 (연화): 캐릭터가 패들 위에 그려짐
                # cy = y + 4, 머리~발: cy-24 ~ cy+24, 실제로 캐릭터 몸통은 cy - 12
                # 패들 y=710이면, cy=714, torso=702, 머리~발: 678~726
                # 캐릭터 몸통 중심은 약 y - 8 (710 - 8 = 702)
                caster_center_y = self.caster_locked_y - 8  # 캐릭터 몸통 중심
            for _ in range(3):  # 파티클 수 증가
                angle = random.uniform(0, math.pi * 2)
                dist = random.uniform(5, 25)  # 캐릭터 크기에 맞게 범위 조정
                self.flame_particles.append({
                    'x': caster_center_x + math.cos(angle) * dist,
                    'y': caster_center_y + math.sin(angle) * dist * 0.8,
                    'vx': random.uniform(-10, 10),
                    # 파티클이 캐릭터 주변에서 위아래로 흩날리도록
                    'vy': random.uniform(-25, 25),
                    'life': 1.0,
                    'size': random.uniform(5, 12),
                    'color_phase': random.uniform(0, 1)
                })

        # 불꽃 파티클 업데이트
        for p in self.flame_particles:
            p['x'] += p['vx'] * dt
            p['y'] += p['vy'] * dt
            p['life'] -= dt * 1.5
            p['size'] *= 0.97
            p['color_phase'] += dt * 2

        # 죽은 파티클 제거
        self.flame_particles = [p for p in self.flame_particles if p['life'] > 0]

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        game_state['target_confused'] = False
        # 패들별 상태 클리어
        target_prefix = 'top_paddle' if self.target_is_top else 'bottom_paddle'
        game_state[f'{target_prefix}_confused'] = False

        # 연화(caster) 고정 해제
        caster_prefix = 'top_paddle' if caster_paddle.is_top else 'bottom_paddle'
        game_state[f'{caster_prefix}_locked'] = False

        self.curse_dolls = []
        self.flame_particles = []
        self.guardian_dolls = []

        # game_state에서 수호 인형 정보 제거
        game_state['doll_curse_guardians'] = []
        game_state['doll_curse_active'] = False
        if 'doll_guardian_ball_bounce' in game_state:
            del game_state['doll_guardian_ball_bounce']

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        if self.is_active:
            # 저주 오버레이
            overlay = pygame.Surface((760, 750), pygame.SRCALPHA)
            overlay.fill((100, 30, 60, 30))
            screen.blit(overlay, (0, 0))

            # 연화 주변 이글이글 불꽃 이펙트
            for p in self.flame_particles:
                # 불꽃 색상: 빨강 -> 주황 -> 노랑 (life에 따라)
                phase = p['color_phase'] % 1.0
                if phase < 0.33:
                    color = (255, int(100 + phase * 300), 50)  # 빨강 -> 주황
                elif phase < 0.66:
                    color = (255, int(200 + (phase - 0.33) * 150), int(50 + (phase - 0.33) * 300))  # 주황 -> 노랑
                else:
                    color = (255, 255, int(150 + (phase - 0.66) * 300))  # 노랑 -> 흰노랑

                alpha = int(255 * p['life'])
                size = max(2, int(p['size']))

                # 불꽃 파티클 그리기
                flame_surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                pygame.draw.circle(flame_surf, (*color, alpha), (size, size), size)
                screen.blit(flame_surf, (int(p['x']) - size, int(p['y']) - size))

            # 연화 캐릭터 스프라이트 위에 오라 이펙트
            caster_center_x = int(self.caster_centerx)
            # 캐릭터 스프라이트 중심 위치 (캐릭터 몸 전체를 감싸도록)
            if self.caster_is_top:
                caster_center_y = int(self.caster_locked_y + 28)  # 상단 영웅
            else:
                caster_center_y = int(self.caster_locked_y - 8)  # 하단 영웅 (연화)

            # 캐릭터를 감싸는 이글이글 오라 (캐릭터 몸 전체)
            aura_w, aura_h = 70, 60  # 캐릭터 크기에 맞게
            aura_surf = pygame.Surface((aura_w, aura_h), pygame.SRCALPHA)
            # 외부 오라 (진한 빨간색, 펄스 효과)
            pulse = 0.7 + 0.3 * math.sin(pygame.time.get_ticks() * 0.008)
            alpha = int(50 * pulse)
            pygame.draw.ellipse(aura_surf, (220, 60, 100, alpha), (0, 0, aura_w, aura_h))
            # 내부 오라 (더 밝은 색)
            pygame.draw.ellipse(aura_surf, (255, 100, 130, int(60 * pulse)), (8, 6, aura_w - 16, aura_h - 12))
            screen.blit(aura_surf, (caster_center_x - aura_w // 2, caster_center_y - aura_h // 2))

            # 수호 인형들 (연화 좌우 150px에서 공을 막음) - 고퀄리티 부두 인형 스타일
            for g_idx, guardian in enumerate(self.guardian_dolls):
                gx, gy = int(guardian['x']), int(guardian['y'])
                spawn_alpha = min(1.0, guardian['spawn_progress'] * 1.5)  # 페이드인
                base_alpha = int(255 * spawn_alpha)
                time_tick = pygame.time.get_ticks()

                # 히트 플래시 효과
                flash = guardian.get('hit_flash', 0)
                if flash > 0:
                    flash_alpha = int(200 * flash)
                    flash_size = int(50 + flash * 30)
                    flash_surf = pygame.Surface((flash_size * 2, flash_size * 2), pygame.SRCALPHA)
                    # 다중 레이어 플래시
                    pygame.draw.circle(flash_surf, (255, 100, 150, int(flash_alpha * 0.3)),
                                     (flash_size, flash_size), flash_size)
                    pygame.draw.circle(flash_surf, (255, 150, 200, int(flash_alpha * 0.5)),
                                     (flash_size, flash_size), int(flash_size * 0.7))
                    pygame.draw.circle(flash_surf, (255, 200, 230, flash_alpha),
                                     (flash_size, flash_size), int(flash_size * 0.4))
                    screen.blit(flash_surf, (gx - flash_size, gy - flash_size))

                scale = guardian['scale'] * spawn_alpha
                s = scale  # 축약

                # 스폰 초기 스케일이 너무 작으면 건너뛰기 (Surface 0 크기 크래시 방지)
                if s < 0.2:
                    continue

                # === 등대 서치라이트 효과 (상대 영웅을 비춤) ===
                if spawn_alpha > 0.5:  # 인형이 어느 정도 나타난 후 빛 발사
                    # 인형 눈 위치 (머리 부분)
                    eye_x = gx
                    eye_y = gy - int(28 * s)  # 머리 Y 위치

                    # 상대 영웅 이미지 위치 (hero_paddles.py와 동기화)
                    target_cx, target_torso_y, _, _ = self._get_hero_body_position(target_paddle)
                    target_x = target_cx
                    target_y = target_torso_y

                    # 빛의 방향 계산
                    dx = target_x - eye_x
                    dy = target_y - eye_y
                    dist = math.sqrt(dx * dx + dy * dy)
                    if dist > 0:
                        # 정규화된 방향
                        nx, ny = dx / dist, dy / dist

                        # 서치라이트 빛 (그라데이션 삼각형 형태)
                        # 상대 영웅까지 충분히 도달하도록 길이 증가
                        light_length = dist + 50  # 타겟까지 + 여유분
                        beam_width_start = 8 * s  # 시작점 폭
                        beam_width_end = 60 * s  # 끝점 폭 (퍼짐)

                        # 수직 벡터 (빛의 폭을 위해)
                        perp_x, perp_y = -ny, nx

                        # 빛 끝점
                        end_x = eye_x + nx * light_length
                        end_y = eye_y + ny * light_length

                        # 서치라이트 폴리곤 (사다리꼴 형태)
                        # 시작점 좌우
                        p1 = (eye_x + perp_x * beam_width_start, eye_y + perp_y * beam_width_start)
                        p2 = (eye_x - perp_x * beam_width_start, eye_y - perp_y * beam_width_start)
                        # 끝점 좌우
                        p3 = (end_x - perp_x * beam_width_end, end_y - perp_y * beam_width_end)
                        p4 = (end_x + perp_x * beam_width_end, end_y + perp_y * beam_width_end)

                        # 빛 펄스 효과
                        light_pulse = 0.6 + 0.4 * math.sin(time_tick * 0.006 + guardian['wobble'])
                        light_alpha = int(40 * spawn_alpha * light_pulse)

                        # 빛 서피스 생성 (전체 화면 크기)
                        light_surf = pygame.Surface((760, 750), pygame.SRCALPHA)

                        # 외부 빛 (연한 빨간색)
                        points = [(int(p1[0]), int(p1[1])), (int(p2[0]), int(p2[1])),
                                 (int(p3[0]), int(p3[1])), (int(p4[0]), int(p4[1]))]
                        pygame.draw.polygon(light_surf, (255, 150, 180, light_alpha), points)

                        # 내부 빛 (더 밝고 좁은 중심선)
                        inner_width_start = beam_width_start * 0.4
                        inner_width_end = beam_width_end * 0.3
                        ip1 = (eye_x + perp_x * inner_width_start, eye_y + perp_y * inner_width_start)
                        ip2 = (eye_x - perp_x * inner_width_start, eye_y - perp_y * inner_width_start)
                        ip3 = (end_x - perp_x * inner_width_end, end_y - perp_y * inner_width_end)
                        ip4 = (end_x + perp_x * inner_width_end, end_y + perp_y * inner_width_end)
                        inner_points = [(int(ip1[0]), int(ip1[1])), (int(ip2[0]), int(ip2[1])),
                                       (int(ip3[0]), int(ip3[1])), (int(ip4[0]), int(ip4[1]))]
                        pygame.draw.polygon(light_surf, (255, 200, 220, int(light_alpha * 1.5)), inner_points)

                        screen.blit(light_surf, (0, 0))

                        # 빛 원점에서 글로우 효과
                        glow_size = int(12 * s * light_pulse)
                        glow_surf = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
                        pygame.draw.circle(glow_surf, (255, 200, 230, int(150 * spawn_alpha)),
                                         (glow_size, glow_size), glow_size)
                        pygame.draw.circle(glow_surf, (255, 255, 255, int(200 * spawn_alpha)),
                                         (glow_size, glow_size), int(glow_size * 0.5))
                        screen.blit(glow_surf, (int(eye_x) - glow_size, int(eye_y) - glow_size))

                # === 외부 마법진/보호 오라 (인형 뒤에) - 고퀄리티 업그레이드 ===
                aura_pulse = 0.7 + 0.3 * math.sin(time_tick * 0.008 + guardian['wobble'])
                magic_size = int(60 * s * aura_pulse)
                magic_surf = pygame.Surface((magic_size * 2 + 20, magic_size * 2 + 20), pygame.SRCALPHA)
                mc = magic_size + 10  # 마법진 중심

                # 1. 내부 글로우 (부드러운 그라데이션)
                for r in range(magic_size, 0, -3):
                    alpha = int(25 * spawn_alpha * (r / magic_size) * aura_pulse)
                    pygame.draw.circle(magic_surf, (200, 80, 130, alpha), (mc, mc), r)

                # 2. 외부 링 (이중 원)
                pygame.draw.circle(magic_surf, (220, 100, 150, int(70 * spawn_alpha)),
                                 (mc, mc), magic_size, 2)
                pygame.draw.circle(magic_surf, (180, 70, 120, int(50 * spawn_alpha)),
                                 (mc, mc), int(magic_size * 0.85), 2)

                # 3. 마법진 룬 심볼 (회전하는 삼각형들)
                rune_rotation = time_tick * 0.002 + guardian['wobble']
                for ri in range(6):
                    rune_angle = rune_rotation + ri * (math.pi / 3)
                    rune_dist = magic_size * 0.7
                    rx = mc + int(math.cos(rune_angle) * rune_dist)
                    ry = mc + int(math.sin(rune_angle) * rune_dist)
                    # 작은 삼각형 룬
                    tri_size = int(6 * s)
                    tri_points = []
                    for ti in range(3):
                        ta = rune_angle + ti * (math.pi * 2 / 3)
                        tri_points.append((rx + int(math.cos(ta) * tri_size),
                                         ry + int(math.sin(ta) * tri_size)))
                    pygame.draw.polygon(magic_surf, (255, 150, 180, int(100 * spawn_alpha * aura_pulse)),
                                      tri_points)
                    pygame.draw.polygon(magic_surf, (220, 100, 140, int(150 * spawn_alpha)),
                                      tri_points, 1)

                # 4. 내부 별 패턴 (오각별)
                star_points = []
                star_size = magic_size * 0.5
                for si in range(5):
                    outer_angle = -math.pi/2 + si * (math.pi * 2 / 5) + rune_rotation * 0.5
                    inner_angle = outer_angle + math.pi / 5
                    star_points.append((mc + int(math.cos(outer_angle) * star_size),
                                       mc + int(math.sin(outer_angle) * star_size)))
                    star_points.append((mc + int(math.cos(inner_angle) * star_size * 0.4),
                                       mc + int(math.sin(inner_angle) * star_size * 0.4)))
                pygame.draw.polygon(magic_surf, (255, 120, 160, int(40 * spawn_alpha * aura_pulse)),
                                  star_points)
                pygame.draw.polygon(magic_surf, (220, 90, 130, int(80 * spawn_alpha)),
                                  star_points, 1)

                # 5. 회전하는 점선 원
                num_dots = 12
                for di in range(num_dots):
                    dot_angle = rune_rotation * 1.5 + di * (math.pi * 2 / num_dots)
                    dot_dist = magic_size * 0.92
                    dot_x = mc + int(math.cos(dot_angle) * dot_dist)
                    dot_y = mc + int(math.sin(dot_angle) * dot_dist)
                    dot_size = int(3 * s * (0.7 + 0.3 * math.sin(time_tick * 0.01 + di)))
                    pygame.draw.circle(magic_surf, (255, 180, 200, int(120 * spawn_alpha)),
                                     (dot_x, dot_y), dot_size)

                screen.blit(magic_surf, (gx - mc, gy - mc))

                # === 그림자 (입체감) ===
                shadow_w, shadow_h = max(1, int(40 * s)), max(1, int(12 * s))
                shadow_surf = pygame.Surface((shadow_w, shadow_h), pygame.SRCALPHA)
                pygame.draw.ellipse(shadow_surf, (0, 0, 0, int(100 * spawn_alpha)), shadow_surf.get_rect())
                screen.blit(shadow_surf, (gx - shadow_w // 2, gy + int(38 * s)))

                # === 연화와 연결된 마법의 실 (고퀄리티 업그레이드) ===
                caster_center_x = int(self.caster_centerx)
                if self.caster_is_top:
                    thread_start_y = int(self.caster_locked_y + 28)
                else:
                    thread_start_y = int(self.caster_locked_y - 8)

                thread_end_y = gy - int(22 * s)

                # 메인 실 (3가닥, 베지어 곡선으로 부드럽게)
                for thread_i, thread_offset in enumerate([-10, 0, 10]):
                    t_start_x = caster_center_x + thread_offset
                    t_end_x = gx + thread_offset // 3

                    # 흔들림 애니메이션
                    sway1 = math.sin(time_tick * 0.003 + thread_i * 0.8) * 20
                    sway2 = math.sin(time_tick * 0.004 + thread_i * 1.2 + 1) * 15

                    # 베지어 곡선 포인트들
                    ctrl1_x = t_start_x + int(sway1)
                    ctrl1_y = thread_start_y + (thread_end_y - thread_start_y) * 0.33
                    ctrl2_x = t_end_x + int(sway2)
                    ctrl2_y = thread_start_y + (thread_end_y - thread_start_y) * 0.66

                    # 곡선 세그먼트로 그리기
                    points = []
                    for seg in range(15):
                        t = seg / 14
                        inv_t = 1 - t
                        # 3차 베지어 곡선
                        px = (inv_t**3 * t_start_x +
                              3 * inv_t**2 * t * ctrl1_x +
                              3 * inv_t * t**2 * ctrl2_x +
                              t**3 * t_end_x)
                        py = (inv_t**3 * thread_start_y +
                              3 * inv_t**2 * t * ctrl1_y +
                              3 * inv_t * t**2 * ctrl2_y +
                              t**3 * thread_end_y)
                        points.append((int(px), int(py)))

                    # 글로우 레이어 (외곽)
                    if len(points) > 1:
                        glow_color = (200, 100, 140, int(40 * spawn_alpha))
                        for i in range(len(points) - 1):
                            pygame.draw.line(screen, (180, 80, 120), points[i], points[i+1], 3)
                        # 메인 실
                        thread_color = (220, 130, 160) if thread_offset == 0 else (180, 100, 130)
                        for i in range(len(points) - 1):
                            pygame.draw.line(screen, thread_color, points[i], points[i+1], 1)

                    # 실 위의 마법 파티클 (중간 지점에)
                    if thread_offset == 0 and len(points) > 7:
                        particle_idx = 7
                        p_pulse = 0.6 + 0.4 * math.sin(time_tick * 0.008 + thread_i)
                        p_size = int(4 * p_pulse)
                        px, py = points[particle_idx]
                        p_surf = pygame.Surface((p_size * 2, p_size * 2), pygame.SRCALPHA)
                        pygame.draw.circle(p_surf, (255, 180, 200, int(150 * spawn_alpha * p_pulse)),
                                         (p_size, p_size), p_size)
                        screen.blit(p_surf, (px - p_size, py - p_size))

                # === 고퀄리티 수호 인형 (부두 인형 스타일) ===
                outline_c = (45, 28, 38) if flash <= 0 else (90, 60, 80)
                # 색상 팔레트
                cloth_base = (105, 72, 88) if flash <= 0 else (165, 130, 150)
                cloth_light = (140, 105, 125) if flash <= 0 else (210, 175, 195)
                cloth_dark = (70, 48, 58) if flash <= 0 else (120, 88, 105)
                cloth_shadow = (55, 35, 45) if flash <= 0 else (100, 70, 85)
                stitch_thread = (165, 55, 80) if flash <= 0 else (230, 110, 145)
                stitch_dark = (110, 40, 60) if flash <= 0 else (180, 80, 110)

                # --- 다리 (테이퍼드 형태 + 신발) ---
                leg_base = cloth_dark
                for leg_side in [-1, 1]:
                    leg_cx = gx + int(leg_side * 8 * s)
                    leg_top = gy + int(14 * s)
                    lw_top, lw_bot = int(7 * s), int(5 * s)
                    lh = int(26 * s)
                    # 다리 몸통 (위가 넓고 아래가 좁은 사다리꼴)
                    leg_pts = [
                        (leg_cx - lw_top, leg_top),
                        (leg_cx + lw_top, leg_top),
                        (leg_cx + lw_bot, leg_top + lh),
                        (leg_cx - lw_bot, leg_top + lh)
                    ]
                    pygame.draw.polygon(screen, leg_base, leg_pts)
                    pygame.draw.polygon(screen, outline_c, leg_pts, 2)
                    # 다리 하이라이트 (입체감)
                    hl_pts = [
                        (leg_cx - lw_top + int(2*s), leg_top + int(2*s)),
                        (leg_cx, leg_top + int(2*s)),
                        (leg_cx - int(1*s), leg_top + lh - int(3*s)),
                        (leg_cx - lw_bot + int(2*s), leg_top + lh - int(3*s))
                    ]
                    pygame.draw.polygon(screen, cloth_base, hl_pts)
                    # 다리 X자 봉제선 (2개)
                    for si in range(2):
                        sy = leg_top + int((8 + si * 10) * s)
                        sw = int(4 * s)
                        pygame.draw.line(screen, stitch_dark, (leg_cx - sw, sy - int(3*s)), (leg_cx + sw, sy + int(3*s)), 2)
                        pygame.draw.line(screen, stitch_dark, (leg_cx - sw, sy + int(3*s)), (leg_cx + sw, sy - int(3*s)), 2)
                    # 발 (둥근 반원)
                    foot_y = leg_top + lh
                    pygame.draw.ellipse(screen, cloth_shadow, (leg_cx - int(6*s), foot_y - int(2*s), int(12*s), int(8*s)))
                    pygame.draw.ellipse(screen, outline_c, (leg_cx - int(6*s), foot_y - int(2*s), int(12*s), int(8*s)), 1)

                # --- 팔 (관절 있는 형태 + 손) ---
                arm_base = cloth_dark
                arm_wobble = math.sin(time_tick * 0.003 + g_idx * 2) * 4
                for arm_side in [-1, 1]:
                    ax = gx + int(arm_side * 20 * s)
                    ay = gy - int(3 * s) + int(arm_wobble * arm_side)
                    aw, ah = int(12 * s), int(24 * s)
                    # 팔 상단 (어깨)
                    pygame.draw.ellipse(screen, arm_base, (ax - aw // 2, ay, aw, ah))
                    # 팔 하이라이트
                    pygame.draw.ellipse(screen, cloth_base, (ax - int(3*s), ay + int(3*s), int(5*s), int(12*s)))
                    pygame.draw.ellipse(screen, outline_c, (ax - aw // 2, ay, aw, ah), 2)
                    # 팔 봉제선 (가로 한 줄)
                    arm_sy = ay + ah // 2
                    pygame.draw.line(screen, stitch_dark, (ax - int(4*s), arm_sy), (ax + int(4*s), arm_sy), 1)
                    for sx_off in range(-3, 4, 2):
                        pygame.draw.line(screen, stitch_dark,
                                        (ax + int(sx_off * s), arm_sy - int(2*s)),
                                        (ax + int(sx_off * s), arm_sy + int(2*s)), 1)
                    # 손 (작은 원 + 손가락 라인)
                    hand_y = ay + ah - int(2*s)
                    pygame.draw.circle(screen, cloth_base, (ax, hand_y), int(4*s))
                    pygame.draw.circle(screen, outline_c, (ax, hand_y), int(4*s), 1)
                    # 손가락 3개 (실 같은 느낌)
                    for fi in range(-1, 2):
                        fx = ax + int(fi * 2 * s)
                        pygame.draw.line(screen, outline_c, (fx, hand_y + int(2*s)),
                                        (fx + int(arm_side * 1 * s), hand_y + int(6*s)), 1)

                # --- 몸통 (패치워크 바디) ---
                body_w, body_h = int(34 * s), int(40 * s)
                body_top = gy - int(13 * s)
                body_rect = (gx - body_w // 2, body_top, body_w, body_h)
                # 몸통 그림자
                pygame.draw.ellipse(screen, cloth_shadow, (body_rect[0] + 2, body_rect[1] + 2, body_w, body_h))
                # 몸통 베이스
                pygame.draw.ellipse(screen, cloth_base, body_rect)
                # 좌측 하이라이트 (입체)
                pygame.draw.ellipse(screen, cloth_light,
                                   (gx - body_w // 2 + int(4*s), body_top + int(4*s), int(14*s), int(20*s)))
                # 다크 패치 (수선 흔적 - 왼쪽 하단)
                patch_rect = (gx - int(10*s), gy + int(6*s), int(12*s), int(10*s))
                pygame.draw.ellipse(screen, cloth_dark, patch_rect)
                pygame.draw.ellipse(screen, stitch_dark, patch_rect, 1)
                # 다크 패치 봉제 실
                for px_off in range(-4, 5, 2):
                    py_c = gy + int(11 * s)
                    pygame.draw.line(screen, stitch_thread,
                                    (gx - int(4*s) + int(px_off * s), py_c - int(5*s)),
                                    (gx - int(4*s) + int(px_off * s), py_c + int(5*s)), 1)
                # 밝은 패치 (오른쪽 상단)
                patch2_rect = (gx + int(2*s), body_top + int(6*s), int(10*s), int(8*s))
                pygame.draw.ellipse(screen, cloth_light, patch2_rect)
                pygame.draw.ellipse(screen, stitch_dark, patch2_rect, 1)
                # 몸통 외곽선
                pygame.draw.ellipse(screen, outline_c, body_rect, 2)

                # 중앙 세로 대형 봉제선 (X자 크로스 스티치)
                for sy in range(int(body_top + 5*s), int(body_top + body_h - 5*s), max(1, int(6*s))):
                    pygame.draw.line(screen, stitch_thread, (gx - int(3*s), sy), (gx + int(3*s), sy + int(4*s)), 2)
                    pygame.draw.line(screen, stitch_thread, (gx + int(3*s), sy), (gx - int(3*s), sy + int(4*s)), 2)
                # 가로 봉제선 (중앙 허리)
                waist_y = gy + int(3 * s)
                pygame.draw.line(screen, stitch_dark, (gx - int(12*s), waist_y), (gx + int(12*s), waist_y), 2)
                # 가로 봉제선 X자 마크
                for sx in range(int(gx - 10*s), int(gx + 12*s), max(1, int(5*s))):
                    pygame.draw.line(screen, stitch_thread, (sx, waist_y - int(2*s)), (sx + int(2*s), waist_y + int(2*s)), 1)
                    pygame.draw.line(screen, stitch_thread, (sx + int(2*s), waist_y - int(2*s)), (sx, waist_y + int(2*s)), 1)

                # --- 하트 핀 (금속 핀대 + 하트 머리) ---
                heart_x, heart_y = gx + int(5*s), gy - int(1*s)
                heart_c = (210, 40, 70) if flash <= 0 else (255, 90, 120)
                heart_glow_c = (255, 60, 100)
                # 핀 글로우 (은은한 발광)
                hg_size = max(1, int(12 * s))
                hg_surf = pygame.Surface((hg_size * 2, hg_size * 2), pygame.SRCALPHA)
                hg_pulse = 0.6 + 0.4 * math.sin(time_tick * 0.005 + g_idx)
                pygame.draw.circle(hg_surf, (*heart_glow_c, int(35 * hg_pulse)),
                                  (hg_size, hg_size), hg_size)
                screen.blit(hg_surf, (heart_x - hg_size, heart_y - hg_size))
                # 금속 핀 대 (가슴을 관통)
                pin_tip_y = heart_y + int(10 * s)
                pygame.draw.line(screen, (160, 160, 170), (heart_x, heart_y + int(3*s)), (heart_x, pin_tip_y), 2)
                pygame.draw.line(screen, (200, 200, 210), (heart_x, heart_y + int(3*s)), (heart_x, pin_tip_y), 1)
                # 하트 (두 원 + 삼각형)
                hs = int(4 * s)
                pygame.draw.circle(screen, heart_c, (heart_x - int(2*s), heart_y - int(2*s)), hs)
                pygame.draw.circle(screen, heart_c, (heart_x + int(2*s), heart_y - int(2*s)), hs)
                pygame.draw.polygon(screen, heart_c, [
                    (heart_x - int(5*s), heart_y - int(1*s)),
                    (heart_x + int(5*s), heart_y - int(1*s)),
                    (heart_x, heart_y + int(6*s))
                ])
                # 하트 광택 (두 점)
                pygame.draw.circle(screen, (255, 180, 200), (heart_x - int(2*s), heart_y - int(3*s)), int(2*s))
                pygame.draw.circle(screen, (255, 220, 230), (heart_x + int(1*s), heart_y - int(4*s)), max(1, int(1*s)))

                # --- 머리 (큰 원 + 그래디언트 레이어) ---
                head_y = gy - int(28 * s)
                head_r = int(19 * s)
                # 머리 그림자
                pygame.draw.circle(screen, cloth_shadow, (gx + 2, head_y + 2), head_r)
                # 머리 베이스
                pygame.draw.circle(screen, cloth_base, (gx, head_y), head_r)
                # 머리 하이라이트 (좌상단)
                pygame.draw.circle(screen, cloth_light, (gx - int(5*s), head_y - int(5*s)), int(8*s))
                # 머리 중앙 봉제선 (세로)
                for hy in range(head_y - int(12*s), head_y + int(12*s), max(1, int(6*s))):
                    pygame.draw.line(screen, stitch_dark, (gx - int(1*s), hy), (gx + int(1*s), hy + int(3*s)), 1)
                # 머리 외곽선 (두꺼운 실선)
                pygame.draw.circle(screen, outline_c, (gx, head_y), head_r, 2)
                # 머리 외곽 봉제선 (점선 느낌)
                for ai in range(0, 24):
                    a = math.radians(ai * 15)
                    if ai % 2 == 0:
                        ox1 = gx + int(math.cos(a) * (head_r + 1))
                        oy1 = head_y + int(math.sin(a) * (head_r + 1))
                        a2 = math.radians((ai + 1) * 15)
                        ox2 = gx + int(math.cos(a2) * (head_r + 1))
                        oy2 = head_y + int(math.sin(a2) * (head_r + 1))
                        pygame.draw.line(screen, stitch_dark, (ox1, oy1), (ox2, oy2), 1)

                # --- 머리카락 (긴 실 가닥 + 곡선) ---
                hair_c = (55, 32, 42)
                hair_highlight = (85, 55, 68)
                hair_top = head_y - head_r
                # 상단 짧은 가닥 (5가닥)
                for hi in range(-2, 3):
                    hx = gx + int(hi * 5 * s)
                    sway = math.sin(time_tick * 0.004 + hi * 0.7) * 3
                    h_len = int((10 + abs(hi) * 2) * s)
                    pygame.draw.line(screen, hair_c, (hx, hair_top + int(2*s)),
                                    (int(hx + sway), hair_top - h_len), 2)
                    pygame.draw.line(screen, hair_highlight, (hx + 1, hair_top + int(2*s)),
                                    (int(hx + sway + 1), hair_top - h_len), 1)
                # 양쪽 긴 머리카락 (어깨까지 늘어지는 4가닥)
                for side in [-1, 1]:
                    for hi in range(2):
                        base_x = gx + int(side * (head_r - 3*s)) + int(hi * side * 3 * s)
                        base_y = head_y + int(3 * s)
                        sway = math.sin(time_tick * 0.003 + hi + side * 2) * 4
                        mid_x = base_x + int(side * 5 * s) + int(sway * 0.5)
                        mid_y = base_y + int(12 * s)
                        end_x = base_x + int(side * 3 * s) + int(sway)
                        end_y = base_y + int(22 * s)
                        pygame.draw.line(screen, hair_c, (base_x, base_y), (mid_x, mid_y), 2)
                        pygame.draw.line(screen, hair_c, (mid_x, mid_y), (end_x, end_y), 2)

                # --- 왼쪽 눈 (4홀 버튼 + 실 꿰맨 디테일) ---
                le_x = gx - int(7 * s)
                le_y = head_y - int(2 * s)
                btn_r = int(6 * s)
                btn_c = (40, 22, 32)
                btn_rim = (70, 45, 58)
                btn_shine = (90, 65, 78)
                # 버튼 그림자
                pygame.draw.circle(screen, (25, 12, 18), (le_x + 1, le_y + 1), btn_r)
                # 버튼 본체
                pygame.draw.circle(screen, btn_c, (le_x, le_y), btn_r)
                # 버튼 림 (테두리 디테일)
                pygame.draw.circle(screen, btn_rim, (le_x, le_y), btn_r, 2)
                pygame.draw.circle(screen, btn_shine, (le_x, le_y), btn_r - max(1, int(2*s)), 1)
                # 4홀 (깊이감 있는 구멍)
                hole_r = max(1, int(1.5 * s))
                for hox, hoy in [(-2, -2), (2, -2), (-2, 2), (2, 2)]:
                    hpx = le_x + int(hox * s)
                    hpy = le_y + int(hoy * s)
                    pygame.draw.circle(screen, (18, 8, 12), (hpx, hpy), hole_r)
                    pygame.draw.circle(screen, btn_rim, (hpx, hpy), hole_r, 1)
                # 실 (대각선 X자로 꿰맨 실)
                thread_c = stitch_thread
                pygame.draw.line(screen, thread_c, (le_x - int(2*s), le_y - int(2*s)),
                                (le_x + int(2*s), le_y + int(2*s)), 2)
                pygame.draw.line(screen, thread_c, (le_x - int(2*s), le_y + int(2*s)),
                                (le_x + int(2*s), le_y - int(2*s)), 2)
                # 실 끝 매듭 (늘어진 실)
                pygame.draw.line(screen, thread_c,
                                (le_x + int(2*s), le_y + int(2*s)),
                                (le_x + int(4*s), le_y + int(6*s)), 1)

                # --- 오른쪽 눈 (X 스티치 + 붉은 저주 글로우) ---
                re_x = gx + int(7 * s)
                re_y = head_y - int(2 * s)
                x_sz = int(5 * s)
                x_c = (220, 50, 80) if flash <= 0 else (255, 110, 145)
                # 눈 글로우 (저주 발광)
                eye_pulse = 0.6 + 0.4 * math.sin(time_tick * 0.007 + g_idx)
                eg_size = max(1, int(10 * s))
                eg_surf = pygame.Surface((eg_size * 2, eg_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(eg_surf, (255, 40, 80, int(50 * eye_pulse)),
                                  (eg_size, eg_size), eg_size)
                screen.blit(eg_surf, (re_x - eg_size, re_y - eg_size))
                # X 자 (두꺼운 실선 + 얇은 하이라이트)
                pygame.draw.line(screen, x_c, (re_x - x_sz, re_y - x_sz),
                                (re_x + x_sz, re_y + x_sz), 3)
                pygame.draw.line(screen, x_c, (re_x - x_sz, re_y + x_sz),
                                (re_x + x_sz, re_y - x_sz), 3)
                # X 스티치 매듭점 (네 끝에 작은 점)
                for kx, ky in [(-1, -1), (1, -1), (-1, 1), (1, 1)]:
                    pygame.draw.circle(screen, x_c,
                                      (re_x + int(kx * x_sz), re_y + int(ky * x_sz)), max(1, int(1.5*s)))
                # 눈물 자국 (오른쪽 눈 아래)
                tear_start_y = re_y + x_sz + int(2*s)
                tear_c = (180, 50, 80, 100)
                tear_surf = pygame.Surface((max(1, int(4*s)), max(1, int(10*s))), pygame.SRCALPHA)
                pygame.draw.ellipse(tear_surf, tear_c, tear_surf.get_rect())
                screen.blit(tear_surf, (re_x - int(2*s), tear_start_y))

                # --- 입 (꿰맨 지그재그 + 실 매듭) ---
                mouth_y = head_y + int(8 * s)
                mouth_c = stitch_thread
                # 입 라인 (지그재그)
                m_pts = []
                for mi in range(-4, 5):
                    mx = gx + int(mi * 3 * s)
                    my = mouth_y + (int(2.5*s) if mi % 2 == 0 else int(-2.5*s))
                    m_pts.append((mx, my))
                for i in range(len(m_pts) - 1):
                    pygame.draw.line(screen, mouth_c, m_pts[i], m_pts[i + 1], 2)
                # 세로 봉제 실 (각 꼭짓점에서 수직 실)
                for mi in range(-4, 5):
                    mx = gx + int(mi * 3 * s)
                    pygame.draw.line(screen, stitch_dark, (mx, mouth_y - int(4*s)), (mx, mouth_y + int(4*s)), 1)
                # 입 끝 매듭
                pygame.draw.circle(screen, mouth_c, (gx - int(12*s), mouth_y), max(1, int(1.5*s)))
                pygame.draw.circle(screen, mouth_c, (gx + int(12*s), mouth_y), max(1, int(1.5*s)))
                # 매듭에서 늘어진 실
                m_sway = math.sin(time_tick * 0.004 + g_idx) * 3
                pygame.draw.line(screen, stitch_dark, (gx - int(12*s), mouth_y),
                                (gx - int(15*s) + int(m_sway), mouth_y + int(8*s)), 1)
                pygame.draw.line(screen, stitch_dark, (gx + int(12*s), mouth_y),
                                (gx + int(15*s) - int(m_sway), mouth_y + int(8*s)), 1)

                # --- 볼 홍조 ---
                blush_alpha = int(90 * spawn_alpha)
                bw, bh = max(1, int(10*s)), max(1, int(6*s))
                blush_surf = pygame.Surface((bw, bh), pygame.SRCALPHA)
                pygame.draw.ellipse(blush_surf, (210, 90, 110, blush_alpha), blush_surf.get_rect())
                screen.blit(blush_surf, (gx - int(18*s), head_y + int(3*s)))
                screen.blit(blush_surf, (gx + int(8*s), head_y + int(3*s)))

                # --- 몸에서 늘어진 실 (찢어진 느낌) ---
                for ti in range(3):
                    t_x = gx + int((-10 + ti * 10) * s)
                    t_base_y = gy + int(24 * s)
                    t_sway = math.sin(time_tick * 0.004 + ti + g_idx) * 4
                    t_len = int((6 + ti * 3) * s)
                    pygame.draw.line(screen, stitch_dark, (t_x, t_base_y),
                                    (t_x + int(t_sway), t_base_y + t_len), 1)

                # --- 저주 파티클 (어둡고 은은한 오라) ---
                num_particles = 6
                for pi in range(num_particles):
                    p_angle = (time_tick * 0.002 + pi * (math.pi * 2 / num_particles)) % (math.pi * 2)
                    p_dist = int(48 * s) + math.sin(time_tick * 0.004 + pi * 1.3) * 10
                    px = gx + int(math.cos(p_angle) * p_dist)
                    py = gy + int(math.sin(p_angle) * p_dist * 0.6)
                    p_size = max(1, int(3 * s * (0.4 + 0.6 * math.sin(time_tick * 0.006 + pi))))
                    p_alpha = max(0, min(255, int(140 * spawn_alpha * (0.4 + 0.6 * math.sin(time_tick * 0.005 + pi)))))
                    p_surf = pygame.Surface((p_size * 2, p_size * 2), pygame.SRCALPHA)
                    p_color = [(200, 60, 110), (180, 40, 90), (220, 80, 130)][pi % 3]
                    pygame.draw.circle(p_surf, (*p_color, p_alpha), (p_size, p_size), p_size)
                    screen.blit(p_surf, (px - p_size, py - p_size))

            # 저주 인형들 (상대 영웅 주변에서 공전) - 고퀄리티 부두 인형
            time_tick = pygame.time.get_ticks()
            for doll_idx, doll in enumerate(self.curse_dolls):
                dx, dy = int(doll['x']), int(doll['y'])
                s = doll['scale']
                rot = doll['rotation']
                wobble = doll['wobble']

                # 색상 팔레트 (저주 인형용 - 더 어둡고 음산)
                c_outline = (40, 22, 32)
                c_base = (82, 52, 68)
                c_light = (115, 80, 98)
                c_dark = (55, 35, 45)
                c_shadow = (38, 22, 30)
                c_stitch = (180, 50, 75)
                c_stitch_dk = (120, 38, 55)

                # === 저주 오라 (인형 뒤, 그래디언트) ===
                aura_pulse = 0.6 + 0.4 * math.sin(time_tick * 0.006 + doll_idx)
                aura_size = int(35 * s * aura_pulse)
                if aura_size > 0:
                    aura_surf = pygame.Surface((aura_size * 2, aura_size * 2), pygame.SRCALPHA)
                    for ar in range(aura_size, 0, -3):
                        a_alpha = int(35 * (ar / aura_size) * aura_pulse)
                        pygame.draw.circle(aura_surf, (180, 40, 90, a_alpha), (aura_size, aura_size), ar)
                    screen.blit(aura_surf, (dx - aura_size, dy - aura_size))

                # === 그림자 ===
                shadow_w, shadow_h = int(24 * s), int(8 * s)
                if shadow_w > 0 and shadow_h > 0:
                    shadow_surf = pygame.Surface((shadow_w, shadow_h), pygame.SRCALPHA)
                    pygame.draw.ellipse(shadow_surf, (0, 0, 0, 60), shadow_surf.get_rect())
                    screen.blit(shadow_surf, (dx - shadow_w // 2, dy + int(20 * s)))

                # === 마리오네트 실 (머리 위로 수렴하는 3가닥) ===
                thread_top_y = dy - int(50 * s)
                for ti, tx_off in enumerate([-5, 0, 5]):
                    t_sway = math.sin(time_tick * 0.004 + ti * 1.2 + doll_idx) * 4
                    # 실 시작 (머리 상단)
                    t_start = (dx + int(tx_off * s * 0.5), dy - int(16 * s))
                    # 실 중간 (흔들림)
                    t_mid = (dx + int(t_sway), thread_top_y + int(15 * s))
                    # 실 끝 (위로 수렴)
                    t_end = (dx + int(t_sway * 0.3), thread_top_y)
                    pygame.draw.line(screen, (160, 70, 100), t_start, t_mid, 1)
                    pygame.draw.line(screen, (130, 50, 80), t_mid, t_end, 1)

                # --- 다리 (테이퍼드) ---
                leg_y_top = dy + int(7 * s)
                for leg_side in [-1, 1]:
                    lx = dx + int(leg_side * 5 * s)
                    lw_t, lw_b = int(5*s), int(4*s)
                    lh = int(18*s)
                    l_pts = [
                        (lx - lw_t, leg_y_top), (lx + lw_t, leg_y_top),
                        (lx + lw_b, leg_y_top + lh), (lx - lw_b, leg_y_top + lh)
                    ]
                    pygame.draw.polygon(screen, c_dark, l_pts)
                    pygame.draw.polygon(screen, c_outline, l_pts, 1)
                    # 다리 X 봉제선
                    l_sy = leg_y_top + lh // 2
                    sw = int(3*s)
                    pygame.draw.line(screen, c_stitch_dk, (lx - sw, l_sy - int(2*s)), (lx + sw, l_sy + int(2*s)), 1)
                    pygame.draw.line(screen, c_stitch_dk, (lx - sw, l_sy + int(2*s)), (lx + sw, l_sy - int(2*s)), 1)
                    # 발
                    pygame.draw.ellipse(screen, c_shadow,
                                       (lx - int(5*s), leg_y_top + lh - int(2*s), int(10*s), int(6*s)))

                # --- 팔 (흔들리는) ---
                arm_y_base = dy - int(4 * s)
                for arm_side in [-1, 1]:
                    a_sway = math.sin(time_tick * 0.005 + arm_side + doll_idx) * 3
                    ax = dx + int(arm_side * 11 * s)
                    aw, ah = int(7*s), int(15*s)
                    pygame.draw.ellipse(screen, c_dark,
                                       (ax - aw // 2, int(arm_y_base + a_sway), aw, ah))
                    pygame.draw.ellipse(screen, c_outline,
                                       (ax - aw // 2, int(arm_y_base + a_sway), aw, ah), 1)
                    # 손 (작은 원)
                    hand_y = int(arm_y_base + a_sway) + ah - int(1*s)
                    pygame.draw.circle(screen, c_base, (ax, hand_y), max(1, int(3*s)))
                    pygame.draw.circle(screen, c_outline, (ax, hand_y), max(1, int(3*s)), 1)

                # --- 몸통 (패치워크) ---
                body_w, body_h = int(22 * s), int(28 * s)
                body_top = dy - int(8 * s)
                body_rect = (dx - body_w // 2, body_top, body_w, body_h)
                # 그림자
                pygame.draw.ellipse(screen, c_shadow,
                                   (body_rect[0] + 1, body_rect[1] + 1, body_w, body_h))
                # 베이스
                pygame.draw.ellipse(screen, c_base, body_rect)
                # 하이라이트
                pygame.draw.ellipse(screen, c_light,
                                   (dx - int(5*s), body_top + int(3*s), int(8*s), int(12*s)))
                # 다크 패치
                patch_r = (dx - int(6*s), dy + int(2*s), int(8*s), int(6*s))
                pygame.draw.ellipse(screen, c_dark, patch_r)
                pygame.draw.ellipse(screen, c_stitch_dk, patch_r, 1)
                # 외곽선
                pygame.draw.ellipse(screen, c_outline, body_rect, 2)

                # 중앙 X자 봉제선
                for sy in range(int(body_top + 4*s), int(body_top + body_h - 4*s), max(1, int(5*s))):
                    pygame.draw.line(screen, c_stitch, (dx - int(2*s), sy), (dx + int(2*s), sy + int(3*s)), 1)
                    pygame.draw.line(screen, c_stitch, (dx + int(2*s), sy), (dx - int(2*s), sy + int(3*s)), 1)
                # 가로 봉제선
                w_y = dy + int(2 * s)
                pygame.draw.line(screen, c_stitch_dk, (dx - int(8*s), w_y), (dx + int(8*s), w_y), 1)

                # --- 하트 핀 ---
                hx, hy = dx + int(3*s), dy - int(2*s)
                h_c = (210, 40, 70)
                # 핀 대
                pygame.draw.line(screen, (150, 150, 160), (hx, hy + int(2*s)), (hx, hy + int(7*s)), 1)
                # 하트
                hr = max(1, int(2.5 * s))
                pygame.draw.circle(screen, h_c, (hx - int(1*s), hy - int(1*s)), hr)
                pygame.draw.circle(screen, h_c, (hx + int(1*s), hy - int(1*s)), hr)
                pygame.draw.polygon(screen, h_c, [
                    (hx - int(3*s), hy), (hx + int(3*s), hy), (hx, hy + int(3*s))
                ])
                # 광택
                pygame.draw.circle(screen, (255, 180, 200), (hx - int(1*s), hy - int(2*s)), max(1, int(1*s)))

                # --- 머리 ---
                head_y = dy - int(18 * s)
                head_r = int(14 * s)
                # 그림자
                pygame.draw.circle(screen, c_shadow, (dx + 1, head_y + 1), head_r)
                # 베이스
                pygame.draw.circle(screen, c_base, (dx, head_y), head_r)
                # 하이라이트
                pygame.draw.circle(screen, c_light, (dx - int(4*s), head_y - int(4*s)), int(5*s))
                # 머리 봉제선 (세로)
                for hy2 in range(head_y - int(8*s), head_y + int(8*s), max(1, int(5*s))):
                    pygame.draw.line(screen, c_stitch_dk, (dx - int(1*s), hy2), (dx + int(1*s), hy2 + int(2*s)), 1)
                # 외곽선
                pygame.draw.circle(screen, c_outline, (dx, head_y), head_r, 2)
                # 외곽 봉제 점선
                for ai in range(0, 18):
                    a = math.radians(ai * 20)
                    if ai % 2 == 0:
                        ox1 = dx + int(math.cos(a) * (head_r + 1))
                        oy1 = head_y + int(math.sin(a) * (head_r + 1))
                        a2 = math.radians((ai + 1) * 20)
                        ox2 = dx + int(math.cos(a2) * (head_r + 1))
                        oy2 = head_y + int(math.sin(a2) * (head_r + 1))
                        pygame.draw.line(screen, c_stitch_dk, (ox1, oy1), (ox2, oy2), 1)

                # --- 머리카락 (상단 + 측면 가닥) ---
                hair_c = (42, 24, 34)
                hair_hl = (70, 45, 58)
                h_top = head_y - head_r
                for hi in range(-2, 3):
                    hhx = dx + int(hi * 4 * s)
                    h_len = int((7 + abs(hi) * 1.5) * s)
                    sway = math.sin(time_tick * 0.004 + hi * 0.8 + doll_idx) * 2
                    pygame.draw.line(screen, hair_c, (hhx, h_top + int(2*s)),
                                    (int(hhx + sway), h_top - h_len), 2)
                # 측면 긴 머리
                for side in [-1, 1]:
                    b_x = dx + int(side * (head_r - 2*s))
                    b_y = head_y + int(2*s)
                    sway = math.sin(time_tick * 0.003 + side + doll_idx) * 3
                    pygame.draw.line(screen, hair_c, (b_x, b_y),
                                    (b_x + int(side * 3*s) + int(sway), b_y + int(14*s)), 2)

                # --- X 눈 (저주 글로우 + 매듭점) ---
                eye_pulse = 0.6 + 0.4 * math.sin(time_tick * 0.008 + doll_idx)
                for eye_side in [-1, 1]:
                    ex = dx + int(eye_side * 5 * s)
                    ey = head_y - int(1 * s)
                    xs = int(4 * s)
                    # 글로우
                    eg_sz = max(1, int(8 * s * eye_pulse))
                    eg_surf = pygame.Surface((eg_sz * 2, eg_sz * 2), pygame.SRCALPHA)
                    pygame.draw.circle(eg_surf, (255, 40, 80, int(55 * eye_pulse)),
                                      (eg_sz, eg_sz), eg_sz)
                    screen.blit(eg_surf, (ex - eg_sz, ey - eg_sz))
                    # X 본체 (두꺼운 선)
                    x_c = (255, 65, 105)
                    pygame.draw.line(screen, x_c, (ex - xs, ey - xs), (ex + xs, ey + xs), 2)
                    pygame.draw.line(screen, x_c, (ex - xs, ey + xs), (ex + xs, ey - xs), 2)
                    # 매듭점
                    for kx, ky in [(-1, -1), (1, 1)]:
                        pygame.draw.circle(screen, x_c,
                                          (ex + int(kx * xs), ey + int(ky * xs)), max(1, int(1*s)))

                # --- 입 (봉제 지그재그 + 실 매듭) ---
                mouth_y = head_y + int(6 * s)
                m_pts = []
                for mi in range(-3, 4):
                    mx = dx + int(mi * 2.5 * s)
                    my = mouth_y + (int(2*s) if mi % 2 == 0 else int(-2*s))
                    m_pts.append((mx, my))
                for i in range(len(m_pts) - 1):
                    pygame.draw.line(screen, c_stitch, m_pts[i], m_pts[i + 1], 2)
                # 세로 봉제 실
                for mi in range(-3, 4):
                    mx = dx + int(mi * 2.5 * s)
                    pygame.draw.line(screen, c_stitch_dk, (mx, mouth_y - int(3*s)), (mx, mouth_y + int(3*s)), 1)
                # 입 끝 매듭
                pygame.draw.circle(screen, c_stitch, (dx - int(8*s), mouth_y), max(1, int(1*s)))
                pygame.draw.circle(screen, c_stitch, (dx + int(8*s), mouth_y), max(1, int(1*s)))

                # --- 볼 홍조 ---
                b_sz = max(1, int(5 * s))
                b_h = max(1, int(3 * s))
                blush_surf = pygame.Surface((b_sz * 2, b_h), pygame.SRCALPHA)
                pygame.draw.ellipse(blush_surf, (200, 85, 105, 55), blush_surf.get_rect())
                screen.blit(blush_surf, (dx - int(11*s), head_y + int(2*s)))
                screen.blit(blush_surf, (dx + int(3*s), head_y + int(2*s)))

                # --- 늘어진 실 (몸통 하단) ---
                for ti in range(2):
                    tx = dx + int((-4 + ti * 8) * s)
                    t_base = dy + int(18 * s)
                    t_sw = math.sin(time_tick * 0.005 + ti + doll_idx) * 3
                    pygame.draw.line(screen, c_stitch_dk, (tx, t_base),
                                    (tx + int(t_sw), t_base + int(5*s)), 1)

                # --- 저주 파티클 ---
                for pi in range(4):
                    p_angle = (time_tick * 0.003 + pi * 1.57 + doll_idx) % (math.pi * 2)
                    p_dist = int(25 * s) + math.sin(time_tick * 0.005 + pi) * 5
                    px = dx + int(math.cos(p_angle) * p_dist)
                    py = dy + int(math.sin(p_angle) * p_dist * 0.6)
                    p_size = max(1, int(2 * s * (0.5 + 0.5 * math.sin(time_tick * 0.006 + pi))))
                    p_alpha = max(0, min(255, int(110 * (0.4 + 0.6 * math.sin(time_tick * 0.005 + pi)))))
                    p_surf = pygame.Surface((p_size * 2, p_size * 2), pygame.SRCALPHA)
                    pc = [(200, 50, 100), (180, 35, 85), (220, 70, 120)][pi % 3]
                    pygame.draw.circle(p_surf, (*pc, p_alpha), (p_size, p_size), p_size)
                    screen.blit(p_surf, (px - p_size, py - p_size))

    def reset_for_new_round(self, game_state: dict):
        """라운드 전환 시 인형의 저주 스킬 강제 종료"""
        super().reset_for_new_round(game_state)
        # 저주 인형과 불꽃 제거
        self.curse_dolls = []
        self.flame_particles = []
        # 수호 인형 제거
        self.guardian_dolls = []
        # 조작 반전 효과 해제
        target_prefix = 'top_paddle' if self.target_is_top else 'bottom_paddle'
        game_state[f'{target_prefix}_confused'] = False
        game_state['target_confused'] = False
        # 연화 고정 해제
        caster_prefix = 'bottom_paddle' if self.target_is_top else 'top_paddle'
        game_state[f'{caster_prefix}_locked'] = False
        # 수호 인형 game_state 정리
        game_state['doll_curse_guardians'] = []
        game_state['doll_curse_active'] = False
        if 'doll_guardian_ball_bounce' in game_state:
            del game_state['doll_guardian_ball_bounce']


# ============================================================================
# 이그니스 스킬 - 드래곤 나이트 (균형형)
# ============================================================================
class DragonBreath(HeroSkill):
    """드래곤 브레스 - 화염 투사체로 공을 타격"""
    def __init__(self):
        super().__init__(
            skill_id="dragon_breath",
            name="Dragon Breath",
            korean_name="드래곤 브레스",
            description="용의 화염을 뿜어 공을 타격하고 가속시킨다",
            trigger=SkillTrigger.ON_COOLDOWN,
            cooldown=12.0,
            duration=3.5,  # 파티클 페이드아웃 시간 포함 (발사 1.2초 + 페이드 2.3초)
            hero_id="ignis"
        )
        self.breath_particles = []
        self.breath_active = False
        self.breath_hit_ball = False  # 호환성용 (사용하지 않음)
        self.breath_hit_cooldown = 0  # 공 타격 쿨다운 타이머
        self.fire_zone_spawned = False  # 화염 지대 생성 여부 (미사용, 호환성용)
        self.spawn_phase_ended = False  # 파티클 생성 단계 종료 여부
        self.fire_zone_timer = 0  # 화염지대 생성 타이머
        self.fire_zone_positions = []  # 생성된 화염지대 위치들

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        self.breath_particles = []
        self.breath_active = True
        self.breath_hit_ball = False  # 호환성용
        self.breath_hit_cooldown = 0  # 공 타격 쿨다운 초기화
        self.fire_zone_spawned = False  # 호환성용
        self.spawn_phase_ended = False  # 파티클 생성 단계 시작
        self.fire_zone_timer = 0  # 화염지대 생성 타이머 초기화
        self.fire_zone_positions = []  # 생성된 화염지대 위치 초기화

        # 브레스 방향 (caster_is_top 속성 우선 사용)
        is_caster_top = getattr(self, 'caster_is_top', caster_paddle.is_top)
        direction = 1 if is_caster_top else -1

        # 발사 시점의 X 좌표 저장 (화염지대 생성 위치용)
        self.breath_start_x = caster_paddle.x + caster_paddle.width // 2
        self.breath_spawn_timer = 0  # 지속적인 파티클 생성용 타이머

        # 화염 파티클 대량 생성 (초기 버스트)
        for i in range(80):
            # 시간차 발사를 위한 딜레이 (0~0.3초 사이에 분산)
            delay = (i / 80) * 0.3
            base_life = random.uniform(1.0, 1.8)  # 수명 조정 (페이드아웃 시간 확보)
            init_size = random.uniform(10, 25)
            self.breath_particles.append({
                'x': caster_paddle.x + 40 + random.uniform(-25, 25),
                'y': caster_paddle.y + direction * 20,
                'vx': random.uniform(-50, 50),
                'vy': direction * random.uniform(350, 600),  # 속도 증가 (더 멀리)
                'life': base_life + delay,  # 수명 증가 (더 오래)
                'max_life': base_life,  # 페이드아웃 계산용 최대 수명
                'size': init_size,
                'max_size': init_size,  # 페이드아웃 시 크기 계산용
                'color_phase': random.uniform(0, 1),
                'delay': delay  # 발사 딜레이
            })

        return {
            'screen_effect': ScreenEffect.FIRE,
            'sound': 'firebreath'
        }

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        # 공 히트박스 생성 (rect 기반 충돌 체크용)
        ball_radius = 10  # BALL_SIZE
        ball_rect = pygame.Rect(
            ball.x - ball_radius - 5,
            ball.y - ball_radius - 5,
            ball_radius * 2 + 10,
            ball_radius * 2 + 10
        )

        # 지속적인 파티클 생성 (브레스 스트림 효과)
        is_caster_top = getattr(self, 'caster_is_top', caster_paddle.is_top)
        direction = 1 if is_caster_top else -1
        self.breath_spawn_timer = getattr(self, 'breath_spawn_timer', 0) + dt

        # 파티클 생성 단계: 처음 1.2초 동안만 (나머지 2.3초는 페이드아웃)
        # active_timer는 duration(3.5)에서 0으로 감소
        spawn_cutoff_time = 2.3  # 이 시간 이하가 되면 생성 중단
        if not self.spawn_phase_ended and self.active_timer > spawn_cutoff_time and self.breath_spawn_timer >= 0.02:
            self.breath_spawn_timer = 0
            for _ in range(3):  # 한 번에 3개씩 생성
                cont_life = random.uniform(0.6, 1.2)  # 수명 단축 (페이드아웃 시간 확보)
                cont_size = random.uniform(8, 18)
                self.breath_particles.append({
                    'x': caster_paddle.x + 40 + random.uniform(-20, 20),
                    'y': caster_paddle.y + direction * 25,
                    'vx': random.uniform(-40, 40),
                    'vy': direction * random.uniform(400, 550),
                    'life': cont_life,
                    'max_life': cont_life,
                    'size': cont_size,
                    'max_size': cont_size,
                    'color_phase': random.uniform(0, 1),
                    'delay': 0
                })
        elif self.active_timer <= spawn_cutoff_time:
            self.spawn_phase_ended = True  # 생성 단계 종료 표시

        # 공 타격 쿨다운 감소
        if self.breath_hit_cooldown > 0:
            self.breath_hit_cooldown -= dt

        for p in self.breath_particles:
            # 딜레이가 있는 파티클은 딜레이 감소
            if p.get('delay', 0) > 0:
                p['delay'] -= dt
                continue  # 딜레이 중인 파티클은 아직 움직이지 않음

            p['x'] += p['vx'] * dt
            p['y'] += p['vy'] * dt
            p['life'] -= dt
            p['size'] *= 0.985  # 더 천천히 줄어듦
            p['color_phase'] += dt

            # 공과 충돌 체크 (쿨다운 기반 다중 히트 - 이펙트 전체에 타격 판정)
            if self.breath_hit_cooldown <= 0 and p['size'] > 3:
                # 파티클 히트박스 생성
                particle_size = max(int(p['size']), 5)
                particle_rect = pygame.Rect(
                    int(p['x']) - particle_size,
                    int(p['y']) - particle_size,
                    particle_size * 2,
                    particle_size * 2
                )

                if particle_rect.colliderect(ball_rect):
                    # 공을 화염 진행 방향으로 반사 + 좌우 넉백
                    is_caster_top = getattr(self, 'caster_is_top', caster_paddle.is_top)

                    # 현재 속도 계산
                    current_speed = math.hypot(ball.vx, ball.vy)
                    if current_speed < 8.0:
                        current_speed = 10.0  # 최소 속도 보장

                    # 속도 부스트 (1.3~1.5배)
                    boosted_speed = current_speed * random.uniform(1.3, 1.5)

                    # 화염 진행 방향으로 반사 (상단→아래, 하단→위)
                    angle_offset = random.uniform(-0.3, 0.3)  # ±17도

                    if is_caster_top:
                        ball.vy = abs(boosted_speed * math.cos(angle_offset))
                    else:
                        ball.vy = -abs(boosted_speed * math.cos(angle_offset))

                    # 좌우 넉백: 파티클 → 공 방향으로 밀어냄
                    dx = ball.x - p['x']
                    knockback_strength = random.uniform(3.0, 6.0)
                    if abs(dx) > 1:
                        # 파티클 기준으로 공이 오른쪽이면 오른쪽으로, 왼쪽이면 왼쪽으로 넉백
                        knockback_dir = 1 if dx > 0 else -1
                        ball.vx = knockback_dir * knockback_strength + boosted_speed * math.sin(angle_offset)
                    else:
                        # 정중앙이면 랜덤 방향 넉백
                        ball.vx = random.choice([-1, 1]) * knockback_strength + boosted_speed * math.sin(angle_offset)

                    # 쿨다운 설정 (0.3초 후 다시 타격 가능)
                    self.breath_hit_cooldown = 0.3
                    self.breath_hit_ball = True  # 호환성용
                    game_state['ball_on_fire'] = True

        # 사라지는 파티클 위치 수집 (life가 0 이하이고 아직 완전히 사라지지 않은 것들)
        dying_particles = [p for p in self.breath_particles if -0.5 < p['life'] <= 0 and p.get('delay', 0) <= 0]

        # 파티클이 완전히 페이드아웃될 때까지 유지 (life가 -0.5 이하가 되면 제거)
        self.breath_particles = [p for p in self.breath_particles if p['life'] > -0.5 or p.get('delay', 0) > 0]

        # 🔥 0.3초마다 사라지는 파티클 위치에 화염지대 생성
        self.fire_zone_timer = getattr(self, 'fire_zone_timer', 0) + dt

        if self.fire_zone_timer >= 0.3 and len(dying_particles) > 0:
            self.fire_zone_timer = 0

            # 사라지는 파티클들의 평균 위치 계산
            avg_x = sum(p['x'] for p in dying_particles) / len(dying_particles)
            avg_y = sum(p['y'] for p in dying_particles) / len(dying_particles)

            # 이미 근처에 화염지대가 있는지 확인 (중복 방지)
            too_close = False
            for pos in getattr(self, 'fire_zone_positions', []):
                if abs(pos[0] - avg_x) < 60 and abs(pos[1] - avg_y) < 40:
                    too_close = True
                    break

            if not too_close:
                # 화염지대 생성 요청 (리스트로 전달하여 여러 개 처리)
                fire_zones_to_spawn = game_state.get('spawn_dragon_fire_zones', [])
                fire_zones_to_spawn.append({
                    'x': avg_x,
                    'y': avg_y,
                    'width': 100,  # 약간 작은 화염 지대
                    'height': 50,
                    'duration': 120,  # 2초 (개별 화염지대는 짧게)
                    'source': 'dragon_breath'
                })
                game_state['spawn_dragon_fire_zones'] = fire_zones_to_spawn

                # 생성된 위치 기록
                if not hasattr(self, 'fire_zone_positions'):
                    self.fire_zone_positions = []
                self.fire_zone_positions.append((avg_x, avg_y))

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        # 파티클은 이미 자연스럽게 페이드아웃되어 있어야 함
        # 혹시 남아있는 파티클이 있어도 다음 스킬 시작 시 초기화됨
        self.breath_active = False
        self.spawn_phase_ended = True
        game_state['ball_on_fire'] = False  # 화염 공 이펙트 해제
        # 화염 지대는 _update_active_effect에서 종료 전에 생성됨

    def reset_for_new_round(self, game_state: dict):
        """라운드 전환 시 드래곤 브레스 스킬 강제 종료"""
        super().reset_for_new_round(game_state)
        self.breath_particles = []
        self.breath_active = False
        self.breath_hit_ball = False
        self.breath_hit_cooldown = 0
        self.fire_zone_spawned = False
        self.spawn_phase_ended = False
        self.fire_zone_timer = 0
        self.fire_zone_positions = []
        game_state['ball_on_fire'] = False
        game_state['spawn_dragon_fire_zones'] = []  # 화염지대 리스트도 초기화

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        # 고퀄리티 드래곤 브레스 화염 이펙트
        for p in self.breath_particles:
            # 딜레이 중인 파티클은 그리지 않음
            if p.get('delay', 0) > 0:
                continue

            if p['size'] > 2:
                phase = p['color_phase'] % 1.0

                # 페이드아웃: max_life 기준으로 계산, 부드러운 ease-out 적용
                max_life = p.get('max_life', 1.5)
                current_life = p['life']

                # 3단계 페이드아웃:
                # 1) life > 0.4 * max_life: 완전 불투명
                # 2) 0 < life <= 0.4 * max_life: 점진적 페이드 (1.0 → 0.3)
                # 3) -0.5 < life <= 0: 최종 페이드 (0.3 → 0)
                fade_start = max_life * 0.4

                if current_life > fade_start:
                    life_ratio = 1.0
                elif current_life > 0:
                    # 0 ~ fade_start 구간: 1.0 → 0.3 으로 서서히 페이드
                    t = current_life / fade_start
                    # smoothstep으로 부드럽게
                    smooth_t = t * t * (3 - 2 * t)
                    life_ratio = 0.3 + 0.7 * smooth_t
                else:
                    # -0.5 ~ 0 구간: 0.3 → 0 으로 최종 페이드
                    t = max(0, (current_life + 0.5) / 0.5)  # -0.5에서 0, 0에서 1
                    life_ratio = 0.3 * t * t  # ease-out quadratic

                base_size = int(p['size'])

                # 다층 화염 렌더링 (5개 레이어)
                for layer in range(5):
                    layer_ratio = layer / 4.0
                    layer_size = max(2, int(base_size * (1.0 - layer_ratio * 0.6)))

                    # 레이어별 색상 변화 (내부: 밝은 흰색/노랑 → 외부: 주황/빨강)
                    if layer == 0:  # 가장 외부 - 어두운 빨강/검정 (연기)
                        r, g, b = 80, 20, 10
                        alpha = int(60 * life_ratio)
                    elif layer == 1:  # 외부 - 빨강
                        r = int(200 + 55 * math.sin(phase * math.pi))
                        g = int(40 + 30 * math.sin(phase * math.pi * 2))
                        b = 0
                        alpha = int(120 * life_ratio)
                    elif layer == 2:  # 중간 - 주황
                        r = 255
                        g = int(100 + 80 * math.sin(phase * math.pi * 1.5))
                        b = int(20 * math.sin(phase * math.pi))
                        alpha = int(180 * life_ratio)
                    elif layer == 3:  # 내부 - 밝은 노랑
                        r = 255
                        g = int(200 + 55 * math.sin(phase * math.pi * 2))
                        b = int(50 + 100 * math.sin(phase * math.pi))
                        alpha = int(200 * life_ratio)
                    else:  # 핵심 - 흰색
                        r, g, b = 255, 255, int(200 + 55 * math.sin(phase * math.pi))
                        alpha = int(220 * life_ratio)

                    # 색상값 클램핑
                    r = max(0, min(255, r))
                    g = max(0, min(255, g))
                    b = max(0, min(255, b))
                    alpha = max(0, min(255, alpha))

                    if layer_size > 1 and alpha > 5:
                        surf_size = layer_size * 2 + 4
                        surf = pygame.Surface((surf_size, surf_size), pygame.SRCALPHA)
                        center = surf_size // 2

                        # 그라데이션 원 효과
                        for gr in range(layer_size, 0, -2):
                            grad_alpha = int(alpha * (gr / layer_size) * 0.7)
                            grad_alpha = max(0, min(255, grad_alpha))
                            pygame.draw.circle(surf, (r, g, b, grad_alpha), (center, center), gr)

                        # 흔들림 효과 (레이어별 다른 흔들림)
                        wobble_x = math.sin(phase * 10 + layer) * (2 + layer * 0.5)
                        wobble_y = math.cos(phase * 8 + layer * 0.7) * (1.5 + layer * 0.3)

                        screen.blit(surf, (int(p['x'] - center + wobble_x), int(p['y'] - center + wobble_y)), special_flags=pygame.BLEND_ADD)

                # 화염 꼬리 효과 (작은 파티클 트레일)
                if life_ratio > 0.3 and base_size > 5:
                    trail_count = 3
                    for t in range(trail_count):
                        trail_offset = (t + 1) * 5
                        trail_size = max(2, int(base_size * 0.3 * (1 - t * 0.25)))
                        trail_alpha = int(80 * life_ratio * (1 - t * 0.3))

                        # 브레스 방향에 따른 꼬리 위치
                        is_caster_top = getattr(self, 'caster_is_top', True)
                        trail_y_dir = -1 if is_caster_top else 1

                        trail_surf = pygame.Surface((trail_size * 2, trail_size * 2), pygame.SRCALPHA)
                        pygame.draw.circle(trail_surf, (255, 150, 50, max(0, min(255, trail_alpha))),
                                         (trail_size, trail_size), trail_size)
                        screen.blit(trail_surf,
                                  (int(p['x'] - trail_size + random.uniform(-2, 2)),
                                   int(p['y'] + trail_y_dir * trail_offset - trail_size)),
                                  special_flags=pygame.BLEND_ADD)

                # 불꽃 스파크 효과 (랜덤 밝은 점)
                if random.random() < 0.15 * life_ratio:
                    spark_size = random.randint(1, 3)
                    spark_offset_x = random.uniform(-base_size, base_size)
                    spark_offset_y = random.uniform(-base_size, base_size)
                    spark_surf = pygame.Surface((spark_size * 2 + 2, spark_size * 2 + 2), pygame.SRCALPHA)
                    pygame.draw.circle(spark_surf, (255, 255, 200, 255),
                                     (spark_size + 1, spark_size + 1), spark_size)
                    screen.blit(spark_surf,
                              (int(p['x'] + spark_offset_x - spark_size - 1),
                               int(p['y'] + spark_offset_y - spark_size - 1)),
                              special_flags=pygame.BLEND_ADD)


class DragonWing(HeroSkill):
    """용의 날개 - 바람으로 공 궤적 변경"""
    def __init__(self):
        super().__init__(
            skill_id="dragon_wing",
            name="Dragon Wing",
            korean_name="용의 날개",
            description="용의 날갯짓으로 바람을 일으켜 공의 궤적을 바꾼다",
            trigger=SkillTrigger.ON_BALL_HIT,
            cooldown=15.0,
            duration=2.5,
            hero_id="ignis"
        )
        self.wind_direction = 0
        self.wind_particles = []

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        # 랜덤 바람 방향
        self.wind_direction = random.choice([-1, 1])
        game_state['wind_force'] = self.wind_direction * 3

        # 날씨 강풍 이벤트 시작 (스킬 종료 시 강제 종료됨)
        if WEATHER_EVENT_AVAILABLE:
            force_start_gust_event(direction=self.wind_direction, duration=99)  # 스킬 종료 시 force_end_weather_event로 종료
            play_weather_sound("gust")

        return {
            'screen_effect': ScreenEffect.WIND,
            'wind_direction': self.wind_direction,
            'sound': None  # 날씨 시스템에서 사운드 재생
        }

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        # 공에 바람 효과 적용 (변동성 추가)
        base_wind = game_state.get('wind_force', 0)

        # 1. 랜덤 변동 (-30% ~ +30%)
        wind_variation = base_wind * random.uniform(0.7, 1.3)

        # 2. 벽 근처에서 바람 감소 (벽에 갇히는 현상 방지)
        wall_margin = 50  # 벽에서 50px 이내
        left_wall = 80 + wall_margin
        right_wall = 680 - wall_margin

        if (ball.x < left_wall and base_wind < 0) or (ball.x > right_wall and base_wind > 0):
            # 벽 방향으로 밀리는 중이면 힘 대폭 감소
            wind_variation *= 0.2

        # 3. 가끔 반대 방향 돌풍 (15% 확률)
        if random.random() < 0.15:
            wind_variation *= -0.5  # 반대 방향으로 살짝 밀기

        # 4. 약간의 Y축 변동 추가 (자연스러운 움직임)
        ball.vx += wind_variation * dt * 60
        ball.vy += random.uniform(-0.3, 0.3) * abs(base_wind) * dt * 60

        # 바람 파티클 추가
        if random.random() < 0.4:
            start_x = 80 if self.wind_direction > 0 else 680
            self.wind_particles.append({
                'x': start_x,
                'y': random.uniform(100, 650),
                'vx': self.wind_direction * random.uniform(200, 400),
                'life': 1.0,
                'length': random.uniform(20, 50)
            })

        for p in self.wind_particles:
            p['x'] += p['vx'] * dt
            p['life'] -= dt
        self.wind_particles = [p for p in self.wind_particles if p['life'] > 0 and 80 < p['x'] < 680]

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        game_state['wind_force'] = 0
        self.wind_particles = []

        # 강풍 이벤트 강제 종료 (스킬 종료와 함께)
        if WEATHER_EVENT_AVAILABLE:
            force_end_weather_event()

    def reset_for_new_round(self, game_state: dict):
        """라운드 전환 시 용의 날개 스킬 강제 종료"""
        super().reset_for_new_round(game_state)
        game_state['wind_force'] = 0
        self.wind_particles = []
        self.wind_direction = 0
        # 강풍 이벤트 강제 종료
        if WEATHER_EVENT_AVAILABLE:
            force_end_weather_event()

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        if self.is_active:
            # 바람 라인 (투명도 지원을 위해 Surface 사용)
            for p in self.wind_particles:
                alpha = int(200 * p['life'])
                line_length = p['length'] * 1.5
                end_x = p['x'] + line_length * (1 if self.wind_direction > 0 else -1)

                # 바람 라인 Surface 생성
                line_width = int(abs(end_x - p['x'])) + 20
                line_height = 20
                if line_width > 0:
                    wind_surf = pygame.Surface((line_width, line_height), pygame.SRCALPHA)

                    # 그라데이션 라인 (여러 줄로 두껍게)
                    for i in range(5):
                        line_alpha = max(0, alpha - i * 30)
                        if line_alpha > 0:
                            # 청록색 ~ 흰색 그라데이션
                            r = min(255, 150 + i * 20)
                            g = min(255, 220 + i * 10)
                            b = 255
                            color = (r, g, b, line_alpha)
                            local_start = (5 if self.wind_direction > 0 else line_width - 5, 10 + i - 2)
                            local_end = (line_width - 5 if self.wind_direction > 0 else 5, 10 + i - 2)
                            pygame.draw.line(wind_surf, color, local_start, local_end, 3)

                    # 블렌드 모드로 화면에 그리기
                    blit_x = min(p['x'], end_x) - 5
                    blit_y = p['y'] - 10
                    screen.blit(wind_surf, (int(blit_x), int(blit_y)), special_flags=pygame.BLEND_ADD)


# ============================================================================
# 마리 스킬 - 스팀펑크 메카닉 여성 (수비적)
# ============================================================================
class SteamBarrier(HeroSkill):
    """스팀 배리어 - 증기 방어막 생성"""
    def __init__(self):
        super().__init__(
            skill_id="steam_barrier",
            name="Steam Barrier",
            korean_name="스팀 배리어",
            description="증기로 방어막을 만들어 공을 반사시킨다",
            trigger=SkillTrigger.ON_COOLDOWN,
            cooldown=20.0,
            duration=6.0,
            hero_id="gear"
        )
        self.barrier_y = 0
        self.steam_particles = []
        # 중복 충돌 방지용 쿨다운 (0.3초)
        self.hit_cooldown = 0.0
        self.hit_cooldown_max = 0.3
        # 성스러운 공 이펙트
        self.holy_ball_active = False
        self.holy_ball_timer = 0.0
        self.holy_ball_duration = 4.0  # 성스러운 이펙트 지속 4초
        self.holy_particles = []
        self.holy_trail = []
        # 에너지 방출 이펙트 (시전자 주변)
        self.energy_particles = []
        self.energy_rings = []  # 확산 링 이펙트
        self.caster_center_x = 0
        self.caster_center_y = 0
        # 배리어 충돌 플래시 이펙트
        self.barrier_hit_flash_timer = 0.0
        self.barrier_hit_flash_duration = 0.4
        self.barrier_hit_x = 0  # 충돌 지점 X
        self.barrier_hit_particles = []  # 충돌 스파클 파티클
        self.barrier_hit_rings = []  # 충돌 확산 링
        # 배리어 파괴(깨지는) 이펙트
        self.break_active = False
        self.break_timer = 0.0
        self.break_duration = 1.2  # 파괴 이펙트 지속 시간
        self.break_shards = []  # 배리어 파편 (직사각형 조각)
        self.break_gear_fragments = []  # 톱니바퀴 파편
        self.break_steam_burst = []  # 증기 폭발 파티클
        self.break_flash_timer = 0.0
        self.break_flash_duration = 0.35
        self.break_rings = []  # 파괴 충격파 링
        self.break_barrier_y = 0  # 파괴 시점의 배리어 Y 위치 저장

    def _spawn_barrier_hit_flash(self, ball_x):
        """배리어 충돌 시 플래시 + 스파클 파티클 생성"""
        import random
        # ë°°ë¦¬ì´ ì¶©ë ì¬ì´ë ì¬ì
        try:
            import os
            project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            hit_path = os.path.join(project_root, "sounds", "steambarriorhit.wav")
            if os.path.exists(hit_path):
                pygame.mixer.Sound(hit_path).play()
        except Exception:
            pass
        self.barrier_hit_flash_timer = self.barrier_hit_flash_duration
        self.barrier_hit_x = ball_x
        # 충돌 지점에서 스파클 파티클 생성 (12~18개)
        num_particles = random.randint(12, 18)
        for _ in range(num_particles):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(40, 160)
            self.barrier_hit_particles.append({
                'x': ball_x + random.uniform(-8, 8),
                'y': self.barrier_y + random.uniform(-4, 4),
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed,
                'life': random.uniform(0.2, 0.5),
                'max_life': 0.5,
                'size': random.uniform(2, 5),
                'color_type': random.choice(['white', 'cyan', 'gold'])
            })
        # 충돌 지점 확산 링 2개 생성
        self.barrier_hit_rings.append({
            'x': ball_x, 'y': self.barrier_y,
            'radius': 5, 'max_radius': 60,
            'life': 0.35, 'max_life': 0.35,
            'color': (220, 240, 255)
        })
        self.barrier_hit_rings.append({
            'x': ball_x, 'y': self.barrier_y,
            'radius': 3, 'max_radius': 40,
            'life': 0.25, 'max_life': 0.25,
            'color': (180, 220, 255)
        })

    def _spawn_break_effect(self):
        """배리어 파괴 시 깨지는 이펙트 생성 (파편 + 톱니바퀴 + 증기 폭발)"""
        import random
        self.break_active = True
        self.break_timer = self.break_duration
        self.break_barrier_y = self.barrier_y
        self.break_flash_timer = self.break_flash_duration

        # 파괴 사운드 재생
        try:
            import os
            project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            break_path = os.path.join(project_root, "sounds", "steambarriorbreak.wav")
            if os.path.exists(break_path):
                pygame.mixer.Sound(break_path).play()
        except Exception:
            pass

        # === 1) 배리어 파편 (직사각형 조각들이 사방으로 튕겨나감) ===
        num_shards = random.randint(28, 36)
        for i in range(num_shards):
            sx = random.uniform(10, 750)
            sy = self.barrier_y + random.uniform(-4, 4)
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(80, 280)
            vx = math.cos(angle) * speed * 0.6
            vy = math.sin(angle) * speed
            center_offset = (sx - 380) / 380
            vx += center_offset * random.uniform(40, 100)
            self.break_shards.append({
                'x': sx, 'y': sy,
                'vx': vx, 'vy': vy,
                'width': random.uniform(6, 18),
                'height': random.uniform(2, 6),
                'angle': random.uniform(0, math.pi * 2),
                'angular_vel': random.uniform(-12, 12),
                'life': random.uniform(0.7, 1.2),
                'max_life': 1.2,
                'gravity': random.uniform(200, 400),
                'color_type': random.choice(['metal', 'metal', 'metal', 'cyan', 'copper'])
            })

        # === 2) 톱니바퀴 파편 (5개 기어 위치에서 각각 3~5조각) ===
        gear_positions = [76, 228, 380, 532, 684]
        for gx in gear_positions:
            num_gear_parts = random.randint(3, 5)
            for _ in range(num_gear_parts):
                angle = random.uniform(0, math.pi * 2)
                speed = random.uniform(60, 200)
                self.break_gear_fragments.append({
                    'x': gx + random.uniform(-8, 8),
                    'y': self.barrier_y + random.uniform(-8, 8),
                    'vx': math.cos(angle) * speed,
                    'vy': math.sin(angle) * speed,
                    'size': random.uniform(4, 10),
                    'angle': random.uniform(0, math.pi * 2),
                    'angular_vel': random.uniform(-15, 15),
                    'life': random.uniform(0.8, 1.2),
                    'max_life': 1.2,
                    'gravity': random.uniform(180, 350),
                    'teeth': random.randint(4, 8)
                })

        # === 3) 증기 폭발 (대량의 증기 파티클) ===
        num_steam = random.randint(20, 30)
        for _ in range(num_steam):
            sx = random.uniform(20, 740)
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(40, 150)
            self.break_steam_burst.append({
                'x': sx,
                'y': self.barrier_y + random.uniform(-6, 6),
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed,
                'life': random.uniform(0.5, 1.0),
                'max_life': 1.0,
                'size': random.uniform(12, 30),
                'expand_rate': random.uniform(15, 40)
            })

        # === 4) 충격파 링 (3개, 좌/중/우에서 확산) ===
        for rx in [190, 380, 570]:
            self.break_rings.append({
                'x': rx, 'y': self.barrier_y,
                'radius': 5, 'max_radius': random.uniform(80, 120),
                'life': 0.5, 'max_life': 0.5,
                'color': random.choice([(220, 240, 255), (200, 220, 240), (180, 200, 220)])
            })

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        # 배리어 위치 (영웅 패들보다 벽 쪽으로 더 뒤에 배치)
        # 상단: 패들(25) - 10 = 15 (패들보다 위쪽, 벽에 더 가깝게)
        # 하단: 패들(710) + 30 = 740 (패들보다 아래쪽, 벽에 더 가깝게)
        self.barrier_y = caster_paddle.y + (-10 if caster_paddle.is_top else 30)
        self.hit_cooldown = 0.0  # 충돌 쿨다운 초기화
        game_state['barrier_active'] = True
        game_state['barrier_y'] = self.barrier_y
        game_state['barrier_owner_is_top'] = caster_paddle.is_top
        # 시전자 정지 (패들 이동 불가)
        game_state['steam_barrier_caster_frozen'] = True
        # 시전자 위치 저장 (에너지 방출 이펙트용)
        self.caster_center_x = caster_paddle.centerx
        self.caster_center_y = caster_paddle.centery
        # 에너지 파티클 초기화
        self.energy_particles = []
        self.energy_rings = []

        return {
            'sound': 'steambarrior'
        }

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        # 시전자 위치 업데이트 (에너지 이펙트 추적용)
        self.caster_center_x = caster_paddle.centerx
        self.caster_center_y = caster_paddle.centery

        # === 마지막 1초: 점진적 해동 (슬슬 움직이기 시작) ===
        thaw_duration = 1.0
        if self.active_timer <= thaw_duration:
            # 0.0(정지) → 1.0(정상속도) 선형 보간
            thaw_ratio = 1.0 - (self.active_timer / thaw_duration)
            game_state['steam_barrier_caster_frozen'] = False
            game_state['steam_barrier_thaw_speed'] = thaw_ratio
        else:
            game_state['steam_barrier_thaw_speed'] = 0.0

        # === 종료 조건 1: 공이 시전자 패들에 닿으면 즉시 종료 ===
        # (발동 후 첫 1초는 보호 시간 - 패들 충돌로 종료되지 않음)
        grace_period = 1.0
        elapsed = self.duration - self.active_timer
        if elapsed >= grace_period:
            ball_right = ball.x + getattr(ball, 'width', 10)
            ball_bottom = ball.y + getattr(ball, 'height', 10)
            paddle_right = caster_paddle.x + caster_paddle.width
            paddle_bottom = caster_paddle.y + caster_paddle.height
            if (ball.x < paddle_right and ball_right > caster_paddle.x and
                    ball.y < paddle_bottom and ball_bottom > caster_paddle.y):
                self.active_timer = 0  # 즉시 종료 트리거
                return

        # === 에너지 방출 파티클 생성 (시전자 주변) ===
        # 에너지 파티클: 시전자 캐릭터 주변에서 바깥으로 방출
        for _ in range(2):
            if random.random() < 0.7:
                angle = random.uniform(0, math.pi * 2)
                start_dist = random.uniform(5, 20)
                speed = random.uniform(30, 80)
                self.energy_particles.append({
                    'x': self.caster_center_x + math.cos(angle) * start_dist,
                    'y': self.caster_center_y + math.sin(angle) * start_dist,
                    'vx': math.cos(angle) * speed,
                    'vy': math.sin(angle) * speed,
                    'life': random.uniform(0.5, 1.0),
                    'max_life': 1.0,
                    'size': random.uniform(3, 8),
                    'color_type': random.choice(['steam', 'gear_orange', 'gear_yellow'])
                })
        # 확산 링 이펙트 (주기적)
        if random.random() < 0.08:
            self.energy_rings.append({
                'x': self.caster_center_x,
                'y': self.caster_center_y,
                'radius': 10,
                'max_radius': random.uniform(50, 80),
                'life': 0.6,
                'max_life': 0.6,
                'speed': random.uniform(80, 120)
            })
        # 에너지 파티클 업데이트
        for p in self.energy_particles:
            p['x'] += p['vx'] * dt
            p['y'] += p['vy'] * dt
            p['life'] -= dt
            p['size'] *= 0.98
        self.energy_particles = [p for p in self.energy_particles if p['life'] > 0]
        # 확산 링 업데이트
        for r in self.energy_rings:
            r['radius'] += r['speed'] * dt
            r['life'] -= dt
        self.energy_rings = [r for r in self.energy_rings if r['life'] > 0]

        # 충돌 쿨다운 감소
        if self.hit_cooldown > 0:
            self.hit_cooldown -= dt

        # 증기 파티클 (화면 전체 너비 0~760)
        if random.random() < 0.3:
            self.steam_particles.append({
                'x': random.uniform(0, 760),
                'y': self.barrier_y + random.uniform(-10, 10),
                'vx': random.uniform(-20, 20),
                'vy': random.uniform(-30, 30),
                'life': 0.8,
                'size': random.uniform(10, 25)
            })

        for p in self.steam_particles:
            p['x'] += p['vx'] * dt
            p['y'] += p['vy'] * dt
            p['life'] -= dt
            p['size'] += dt * 10
        self.steam_particles = [p for p in self.steam_particles if p['life'] > 0]

        # 성스러운 공 이펙트 업데이트
        if self.holy_ball_active:
            self.holy_ball_timer -= dt
            # 공 중심 좌표 계산 (ball.x/y는 좌상단이므로 보정)
            ball_cx = ball.x + getattr(ball, 'width', 10) / 2
            ball_cy = ball.y + getattr(ball, 'height', 10) / 2
            # 공 주변 성스러운 파티클 생성
            if random.random() < 0.6:
                angle = random.uniform(0, math.pi * 2)
                dist = random.uniform(5, 18)
                self.holy_particles.append({
                    'x': ball_cx + math.cos(angle) * dist,
                    'y': ball_cy + math.sin(angle) * dist,
                    'vx': math.cos(angle) * random.uniform(15, 40),
                    'vy': math.sin(angle) * random.uniform(15, 40) - 20,
                    'life': random.uniform(0.4, 0.8),
                    'max_life': 0.8,
                    'size': random.uniform(2, 5),
                    'color_type': random.choice(['gold', 'white', 'light_gold'])
                })
            # 십자가 모양 빛 파티클 (간헐적)
            if random.random() < 0.15:
                self.holy_particles.append({
                    'x': ball_cx + random.uniform(-8, 8),
                    'y': ball_cy + random.uniform(-8, 8),
                    'vx': 0,
                    'vy': random.uniform(-50, -20),
                    'life': random.uniform(0.5, 1.0),
                    'max_life': 1.0,
                    'size': random.uniform(3, 6),
                    'color_type': 'cross'
                })
            # 궤적 저장
            self.holy_trail.append({
                'x': ball_cx,
                'y': ball_cy,
                'life': 0.5,
                'max_life': 0.5,
                'size': 10
            })
            if self.holy_ball_timer <= 0:
                self.holy_ball_active = False
                game_state['ball_holy'] = False

        # 성스러운 파티클 업데이트
        for p in self.holy_particles:
            p['x'] += p['vx'] * dt
            p['y'] += p['vy'] * dt
            p['life'] -= dt
            p['size'] *= 0.97
        self.holy_particles = [p for p in self.holy_particles if p['life'] > 0]

        # 성스러운 궤적 업데이트
        for t in self.holy_trail:
            t['life'] -= dt
            t['size'] *= 0.95
        self.holy_trail = [t for t in self.holy_trail if t['life'] > 0]

        # 배리어 충돌 플래시 이펙트 업데이트
        if self.barrier_hit_flash_timer > 0:
            self.barrier_hit_flash_timer -= dt
        # 충돌 스파클 파티클 업데이트
        for p in self.barrier_hit_particles:
            p['x'] += p['vx'] * dt
            p['y'] += p['vy'] * dt
            p['life'] -= dt
            p['size'] *= 0.96
        self.barrier_hit_particles = [p for p in self.barrier_hit_particles if p['life'] > 0]
        # 충돌 확산 링 업데이트
        for r in self.barrier_hit_rings:
            r['life'] -= dt
            progress = 1.0 - (r['life'] / r['max_life'])
            r['radius'] = r['max_radius'] * progress
        self.barrier_hit_rings = [r for r in self.barrier_hit_rings if r['life'] > 0]

        # 공 배리어 충돌 체크 (쿨다운 중이 아닐 때만)
        is_top = game_state.get('barrier_owner_is_top', True)
        if self.hit_cooldown <= 0:
            if is_top:
                # 상단 배리어: 공이 아래에서 위로 접근 (ball.y > barrier_y)
                if ball.vy < 0 and abs(ball.y - self.barrier_y) < 20 and ball.y > self.barrier_y:
                    ball.vy = abs(ball.vy) * 1.4
                    self.hit_cooldown = self.hit_cooldown_max  # 중복 충돌 방지
                    game_state['screen_shake'] = 10
                    # 배리어 충돌 플래시 이펙트
                    self._spawn_barrier_hit_flash(ball.x + getattr(ball, 'width', 10) / 2)
                    # 성스러운 이펙트 활성화
                    self.holy_ball_active = True
                    self.holy_ball_timer = self.holy_ball_duration
                    game_state['ball_holy'] = True
            else:
                # 하단 배리어: 공이 위에서 아래로 접근 (ball.y < barrier_y)
                if ball.vy > 0 and abs(ball.y - self.barrier_y) < 20 and ball.y < self.barrier_y:
                    ball.vy = -abs(ball.vy) * 1.4
                    self.hit_cooldown = self.hit_cooldown_max  # 중복 충돌 방지
                    game_state['screen_shake'] = 10
                    # 배리어 충돌 플래시 이펙트
                    self._spawn_barrier_hit_flash(ball.x + getattr(ball, 'width', 10) / 2)
                    # 성스러운 이펙트 활성화
                    self.holy_ball_active = True
                    self.holy_ball_timer = self.holy_ball_duration
                    game_state['ball_holy'] = True

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        # 파괴 이펙트 생성 (정리 전에 호출!)
        self._spawn_break_effect()
        game_state['barrier_active'] = False
        # 시전자 정지 해제
        game_state['steam_barrier_caster_frozen'] = False
        game_state['steam_barrier_thaw_speed'] = 0.0
        self.steam_particles = []
        # 배리어 종료 시 성스러운 이펙트도 정리 (파티클은 자연 소멸)
        self.holy_ball_active = False
        self.holy_ball_timer = 0
        game_state['ball_holy'] = False
        self.holy_particles = []
        self.holy_trail = []
        # 에너지 방출 이펙트 정리
        self.energy_particles = []
        self.energy_rings = []
        # 충돌 플래시 이펙트 정리
        self.barrier_hit_flash_timer = 0.0
        self.barrier_hit_particles = []
        self.barrier_hit_rings = []

    def reset_for_new_round(self, game_state: dict):
        """라운드 전환 시 스팀 배리어 및 성스러운 이펙트 강제 종료"""
        super().reset_for_new_round(game_state)
        game_state['barrier_active'] = False
        game_state['ball_holy'] = False
        game_state['steam_barrier_caster_frozen'] = False
        game_state['steam_barrier_thaw_speed'] = 0.0
        self.steam_particles = []
        self.holy_ball_active = False
        self.holy_ball_timer = 0
        self.holy_particles = []
        self.holy_trail = []
        self.energy_particles = []
        self.energy_rings = []
        self.barrier_hit_flash_timer = 0.0
        self.barrier_hit_particles = []
        self.barrier_hit_rings = []
        # 파괴 이펙트 정리
        self.break_active = False
        self.break_timer = 0.0
        self.break_shards = []
        self.break_gear_fragments = []
        self.break_steam_burst = []
        self.break_flash_timer = 0.0
        self.break_rings = []

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        if self.is_active:
            # 마지막 0.5초 동안 신기루처럼 페이드아웃
            fade_duration = 0.5
            if self.active_timer <= fade_duration:
                fade_alpha = self.active_timer / fade_duration  # 0.5 -> 0 = 1.0 -> 0.0
            else:
                fade_alpha = 1.0

            # 배리어 라인 알파 (펄스 효과 + 페이드아웃)
            base_alpha = int(150 + 50 * math.sin(pygame.time.get_ticks() / 100))
            barrier_alpha = int(base_alpha * fade_alpha)

            # 메인 배리어 라인 (화면 전체 너비 0~760)
            if barrier_alpha > 0:
                barrier_surf = pygame.Surface((760, 8), pygame.SRCALPHA)
                pygame.draw.line(barrier_surf, (180, 200, 220, barrier_alpha),
                               (0, 4), (760, 4), 4)
                screen.blit(barrier_surf, (0, int(self.barrier_y) - 4))

            # === 배리어 충돌 플래시 이펙트 ===
            if self.barrier_hit_flash_timer > 0:
                flash_ratio = self.barrier_hit_flash_timer / self.barrier_hit_flash_duration
                # 배리어 라인 전체가 밝게 번쩍 (충돌 직후 강하게 → 빠르게 감쇄)
                flash_alpha = int(220 * flash_ratio)
                if flash_alpha > 0:
                    flash_surf = pygame.Surface((760, 14), pygame.SRCALPHA)
                    pygame.draw.line(flash_surf, (230, 245, 255, flash_alpha),
                                   (0, 7), (760, 7), 6)
                    screen.blit(flash_surf, (0, int(self.barrier_y) - 7),
                               special_flags=pygame.BLEND_ADD)
                    # 충돌 지점 주변 집중 플래시 (더 밝고 넓게)
                    cx = int(self.barrier_hit_x)
                    local_alpha = int(255 * flash_ratio)
                    local_w = 120
                    local_surf = pygame.Surface((local_w, 20), pygame.SRCALPHA)
                    pygame.draw.ellipse(local_surf, (255, 255, 255, local_alpha),
                                       (0, 0, local_w, 20))
                    screen.blit(local_surf, (cx - local_w // 2, int(self.barrier_y) - 10),
                               special_flags=pygame.BLEND_ADD)

            # 충돌 확산 링 그리기
            for r in self.barrier_hit_rings:
                ring_alpha = int(200 * (r['life'] / r['max_life']))
                ring_radius = max(1, int(r['radius']))
                if ring_alpha > 0:
                    ring_size = ring_radius * 2 + 4
                    ring_surf = pygame.Surface((ring_size, ring_size), pygame.SRCALPHA)
                    rc = ring_radius + 2
                    color = r['color']
                    pygame.draw.circle(ring_surf, (*color, ring_alpha), (rc, rc), ring_radius, 2)
                    screen.blit(ring_surf,
                               (int(r['x']) - rc, int(r['y']) - rc),
                               special_flags=pygame.BLEND_ADD)

            # 충돌 스파클 파티클 그리기
            for p in self.barrier_hit_particles:
                p_alpha = int(255 * (p['life'] / p['max_life']))
                p_size = max(1, int(p['size']))
                if p_alpha <= 0 or p_size <= 0:
                    continue
                if p['color_type'] == 'white':
                    color = (255, 255, 255, p_alpha)
                elif p['color_type'] == 'cyan':
                    color = (180, 230, 255, p_alpha)
                else:  # gold
                    color = (255, 220, 100, p_alpha)
                p_surf = pygame.Surface((p_size * 2, p_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(p_surf, color, (p_size, p_size), p_size)
                screen.blit(p_surf, (int(p['x']) - p_size, int(p['y']) - p_size),
                           special_flags=pygame.BLEND_ADD)

            # 톱니바퀴 장식 (화면 전체에 균등 배치: 5개)
            for x in [76, 228, 380, 532, 684]:
                gear_alpha = int(200 * fade_alpha)
                if gear_alpha <= 0:
                    continue
                gear_surf = pygame.Surface((30, 30), pygame.SRCALPHA)
                teeth = 8
                for i in range(teeth):
                    angle = math.radians(i * 360 / teeth + pygame.time.get_ticks() / 50)
                    inner = 8
                    outer = 12
                    x1 = 15 + math.cos(angle) * inner
                    y1 = 15 + math.sin(angle) * inner
                    x2 = 15 + math.cos(angle) * outer
                    y2 = 15 + math.sin(angle) * outer
                    pygame.draw.line(gear_surf, (140, 100, 60, gear_alpha), (x1, y1), (x2, y2), 3)
                pygame.draw.circle(gear_surf, (160, 120, 80, gear_alpha), (15, 15), 8)
                pygame.draw.circle(gear_surf, (100, 80, 50, gear_alpha), (15, 15), 4)
                screen.blit(gear_surf, (x - 15, int(self.barrier_y) - 15))

            # 증기 파티클
            for p in self.steam_particles:
                alpha = int(100 * (p['life'] / 0.8) * fade_alpha)
                if alpha <= 0:
                    continue
                surf = pygame.Surface((int(p['size'] * 2), int(p['size'] * 2)), pygame.SRCALPHA)
                pygame.draw.circle(surf, (200, 210, 220, alpha),
                                  (int(p['size']), int(p['size'])), int(p['size']))
                screen.blit(surf, (int(p['x'] - p['size']), int(p['y'] - p['size'])))

            # === 에너지 방출 이펙트 (시전자 캐릭터 주변) ===
            cx = int(self.caster_center_x)
            cy = int(self.caster_center_y)

            # 1) 확산 링 이펙트 (에너지 파동)
            for r in self.energy_rings:
                ring_alpha = int(180 * (r['life'] / r['max_life']) * fade_alpha)
                ring_radius = int(r['radius'])
                if ring_alpha > 0 and ring_radius > 0:
                    ring_surf = pygame.Surface((ring_radius * 2 + 4, ring_radius * 2 + 4), pygame.SRCALPHA)
                    rc = ring_radius + 2
                    # 외곽 증기색 링
                    pygame.draw.circle(ring_surf, (180, 200, 220, ring_alpha // 2),
                                      (rc, rc), ring_radius, 2)
                    # 내곽 주황/노란 에너지 링
                    if ring_radius > 5:
                        pygame.draw.circle(ring_surf, (220, 160, 60, ring_alpha),
                                          (rc, rc), max(1, ring_radius - 3), 2)
                    screen.blit(ring_surf, (cx - rc, cy - rc),
                               special_flags=pygame.BLEND_ADD)

            # 2) 에너지 파티클 (시전자 주변에서 방출)
            for p in self.energy_particles:
                p_alpha = int(200 * (p['life'] / p['max_life']) * fade_alpha)
                p_size = max(1, int(p['size']))
                if p_alpha <= 0 or p_size <= 0:
                    continue
                if p['color_type'] == 'steam':
                    color = (180, 200, 220, p_alpha)
                elif p['color_type'] == 'gear_orange':
                    color = (220, 150, 50, p_alpha)
                else:  # gear_yellow
                    color = (240, 210, 80, p_alpha)
                p_surf = pygame.Surface((p_size * 2, p_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(p_surf, color, (p_size, p_size), p_size)
                screen.blit(p_surf, (int(p['x']) - p_size, int(p['y']) - p_size),
                           special_flags=pygame.BLEND_ADD)

            # 3) 시전자 주변 코어 글로우 (에너지 집중 효과)
            glow_pulse = 0.7 + 0.3 * math.sin(pygame.time.get_ticks() / 120)
            core_alpha = int(80 * glow_pulse * fade_alpha)
            if core_alpha > 0:
                # 외부 주황색 오오라
                outer_size = 35 + int(8 * math.sin(pygame.time.get_ticks() / 200))
                outer_surf = pygame.Surface((outer_size * 2, outer_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(outer_surf, (200, 140, 40, core_alpha // 2),
                                  (outer_size, outer_size), outer_size)
                screen.blit(outer_surf, (cx - outer_size, cy - outer_size),
                           special_flags=pygame.BLEND_ADD)
                # 내부 밝은 글로우
                inner_size = 20 + int(4 * math.sin(pygame.time.get_ticks() / 150))
                inner_surf = pygame.Surface((inner_size * 2, inner_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(inner_surf, (240, 200, 100, core_alpha),
                                  (inner_size, inner_size), inner_size)
                screen.blit(inner_surf, (cx - inner_size, cy - inner_size),
                           special_flags=pygame.BLEND_ADD)

        # === 배리어 파괴(깨지는) 이펙트 (배리어 비활성화 후에도 지속) ===
        if self.break_active:
            dt_break = 1.0 / 60.0  # 프레임 기반 델타타임 (60fps 가정)

            # 파괴 플래시 업데이트 & 렌더링
            if self.break_flash_timer > 0:
                self.break_flash_timer -= dt_break
                flash_ratio = max(0, self.break_flash_timer / self.break_flash_duration)
                # 배리어 전체 라인 밝은 플래시 (강하게)
                flash_alpha = int(255 * flash_ratio)
                if flash_alpha > 0:
                    flash_surf = pygame.Surface((760, 20), pygame.SRCALPHA)
                    pygame.draw.line(flash_surf, (255, 255, 255, flash_alpha),
                                   (0, 10), (760, 10), 10)
                    screen.blit(flash_surf, (0, int(self.break_barrier_y) - 10),
                               special_flags=pygame.BLEND_ADD)

            # 충격파 링 업데이트 & 렌더링
            for r in self.break_rings[:]:
                r['life'] -= dt_break
                if r['life'] <= 0:
                    self.break_rings.remove(r)
                    continue
                progress = 1.0 - (r['life'] / r['max_life'])
                r['radius'] = r['max_radius'] * progress
                ring_alpha = int(200 * (r['life'] / r['max_life']))
                ring_radius = max(1, int(r['radius']))
                if ring_alpha > 0:
                    ring_size = ring_radius * 2 + 4
                    ring_surf = pygame.Surface((ring_size, ring_size), pygame.SRCALPHA)
                    rc = ring_radius + 2
                    color = r['color']
                    pygame.draw.circle(ring_surf, (*color, ring_alpha), (rc, rc), ring_radius, 2)
                    screen.blit(ring_surf,
                               (int(r['x']) - rc, int(r['y']) - rc),
                               special_flags=pygame.BLEND_ADD)

            # 배리어 파편 업데이트 & 렌더링
            for s in self.break_shards[:]:
                s['x'] += s['vx'] * dt_break
                s['y'] += s['vy'] * dt_break
                s['vy'] += s['gravity'] * dt_break  # 중력 적용
                s['angle'] += s['angular_vel'] * dt_break
                s['life'] -= dt_break
                if s['life'] <= 0:
                    self.break_shards.remove(s)
                    continue
                life_ratio = s['life'] / s['max_life']
                s_alpha = int(255 * life_ratio)
                if s_alpha <= 0:
                    continue
                # 파편 색상
                if s['color_type'] == 'metal':
                    color = (180, 200, 220, s_alpha)
                elif s['color_type'] == 'cyan':
                    color = (160, 220, 255, s_alpha)
                else:  # copper
                    color = (200, 140, 60, s_alpha)
                # 회전된 직사각형 파편 그리기
                w = max(2, int(s['width'] * (0.5 + 0.5 * life_ratio)))
                h = max(1, int(s['height'] * (0.5 + 0.5 * life_ratio)))
                shard_surf = pygame.Surface((w + 4, h + 4), pygame.SRCALPHA)
                # 중심 기준 4개 꼭짓점 회전
                cx_s, cy_s = (w + 4) / 2, (h + 4) / 2
                cos_a = math.cos(s['angle'])
                sin_a = math.sin(s['angle'])
                hw, hh = w / 2, h / 2
                points = []
                for dx, dy in [(-hw, -hh), (hw, -hh), (hw, hh), (-hw, hh)]:
                    rx = cx_s + dx * cos_a - dy * sin_a
                    ry = cy_s + dx * sin_a + dy * cos_a
                    points.append((rx, ry))
                pygame.draw.polygon(shard_surf, color, points)
                # 파편 테두리 (밝은 하이라이트)
                edge_alpha = min(255, int(s_alpha * 0.6))
                if edge_alpha > 0:
                    edge_color = (255, 255, 255, edge_alpha)
                    pygame.draw.polygon(shard_surf, edge_color, points, 1)
                screen.blit(shard_surf,
                           (int(s['x']) - (w + 4) // 2, int(s['y']) - (h + 4) // 2),
                           special_flags=pygame.BLEND_ADD)

            # 톱니바퀴 파편 업데이트 & 렌더링
            for g in self.break_gear_fragments[:]:
                g['x'] += g['vx'] * dt_break
                g['y'] += g['vy'] * dt_break
                g['vy'] += g['gravity'] * dt_break
                g['angle'] += g['angular_vel'] * dt_break
                g['life'] -= dt_break
                if g['life'] <= 0:
                    self.break_gear_fragments.remove(g)
                    continue
                life_ratio = g['life'] / g['max_life']
                g_alpha = int(220 * life_ratio)
                if g_alpha <= 0:
                    continue
                sz = max(2, int(g['size'] * (0.6 + 0.4 * life_ratio)))
                gear_surf = pygame.Surface((sz * 2 + 4, sz * 2 + 4), pygame.SRCALPHA)
                gc = sz + 2
                # 미니 톱니바퀴 그리기 (회전 적용)
                teeth = g['teeth']
                for i in range(teeth):
                    t_angle = g['angle'] + i * (math.pi * 2 / teeth)
                    inner = sz * 0.5
                    outer = sz
                    x1 = gc + math.cos(t_angle) * inner
                    y1 = gc + math.sin(t_angle) * inner
                    x2 = gc + math.cos(t_angle) * outer
                    y2 = gc + math.sin(t_angle) * outer
                    pygame.draw.line(gear_surf, (160, 120, 80, g_alpha),
                                   (x1, y1), (x2, y2), max(1, sz // 3))
                pygame.draw.circle(gear_surf, (180, 140, 90, g_alpha), (gc, gc), max(1, int(sz * 0.5)))
                pygame.draw.circle(gear_surf, (120, 90, 50, g_alpha), (gc, gc), max(1, int(sz * 0.3)))
                screen.blit(gear_surf,
                           (int(g['x']) - gc, int(g['y']) - gc))

            # 증기 폭발 파티클 업데이트 & 렌더링
            for p in self.break_steam_burst[:]:
                p['x'] += p['vx'] * dt_break
                p['y'] += p['vy'] * dt_break
                p['vx'] *= 0.96  # 감속
                p['vy'] *= 0.96
                p['size'] += p['expand_rate'] * dt_break  # 팽창
                p['life'] -= dt_break
                if p['life'] <= 0:
                    self.break_steam_burst.remove(p)
                    continue
                life_ratio = p['life'] / p['max_life']
                p_alpha = int(120 * life_ratio)
                p_size = max(1, int(p['size']))
                if p_alpha <= 0:
                    continue
                steam_surf = pygame.Surface((p_size * 2, p_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(steam_surf, (210, 220, 230, p_alpha),
                                  (p_size, p_size), p_size)
                # 내부 밝은 코어
                inner_s = max(1, p_size // 2)
                inner_alpha = min(255, int(p_alpha * 1.3))
                pygame.draw.circle(steam_surf, (240, 245, 250, inner_alpha),
                                  (p_size, p_size), inner_s)
                screen.blit(steam_surf,
                           (int(p['x']) - p_size, int(p['y']) - p_size))

            # 타이머 업데이트 및 완료 체크
            self.break_timer -= dt_break
            if (self.break_timer <= 0 and not self.break_shards
                    and not self.break_gear_fragments and not self.break_steam_burst
                    and not self.break_rings):
                self.break_active = False

        # 성스러운 공 이펙트 그리기 (배리어 활성 여부와 무관하게 지속)
        if self.holy_ball_active or self.holy_particles or self.holy_trail:
            # 성스러운 궤적 그리기 (금빛 잔상)
            for t in self.holy_trail:
                trail_alpha = int(120 * (t['life'] / t['max_life']))
                trail_size = max(1, int(t['size']))
                if trail_alpha > 0 and trail_size > 0:
                    trail_surf = pygame.Surface((trail_size * 2, trail_size * 2), pygame.SRCALPHA)
                    # 외곽 금빛 글로우
                    pygame.draw.circle(trail_surf, (255, 215, 80, trail_alpha // 3),
                                      (trail_size, trail_size), trail_size)
                    # 내부 밝은 빛
                    inner = max(1, trail_size // 2)
                    pygame.draw.circle(trail_surf, (255, 240, 180, trail_alpha),
                                      (trail_size, trail_size), inner)
                    screen.blit(trail_surf, (int(t['x']) - trail_size, int(t['y']) - trail_size),
                               special_flags=pygame.BLEND_ADD)

            # 성스러운 파티클 그리기
            for p in self.holy_particles:
                p_alpha = int(200 * (p['life'] / p['max_life']))
                p_size = max(1, int(p['size']))
                if p_alpha <= 0 or p_size <= 0:
                    continue

                if p['color_type'] == 'gold':
                    color = (255, 215, 80, p_alpha)
                elif p['color_type'] == 'white':
                    color = (255, 255, 230, p_alpha)
                elif p['color_type'] == 'light_gold':
                    color = (255, 230, 140, p_alpha)
                else:
                    # 십자가 타입 - 작은 십자 모양
                    cross_surf = pygame.Surface((p_size * 4, p_size * 4), pygame.SRCALPHA)
                    cx, cy = p_size * 2, p_size * 2
                    cross_color = (255, 240, 180, p_alpha)
                    pygame.draw.line(cross_surf, cross_color,
                                   (cx, cy - p_size), (cx, cy + p_size), max(1, p_size // 2))
                    pygame.draw.line(cross_surf, cross_color,
                                   (cx - p_size, cy), (cx + p_size, cy), max(1, p_size // 2))
                    screen.blit(cross_surf, (int(p['x']) - p_size * 2, int(p['y']) - p_size * 2),
                               special_flags=pygame.BLEND_ADD)
                    continue

                p_surf = pygame.Surface((p_size * 2, p_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(p_surf, color, (p_size, p_size), p_size)
                screen.blit(p_surf, (int(p['x']) - p_size, int(p['y']) - p_size),
                           special_flags=pygame.BLEND_ADD)

            # 공 주변 성스러운 글로우 (ball이 있을 때)
            if self.holy_ball_active and ball:
                # 공 중심 좌표 (ball.x/y는 좌상단이므로 보정)
                ball_cx = ball.x + getattr(ball, 'width', 10) / 2
                ball_cy = ball.y + getattr(ball, 'height', 10) / 2
                # 외부 금빛 오오라
                glow_size = 22 + int(4 * math.sin(pygame.time.get_ticks() / 150))
                glow_surf = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (255, 215, 80, 60),
                                  (glow_size, glow_size), glow_size)
                pygame.draw.circle(glow_surf, (255, 240, 180, 90),
                                  (glow_size, glow_size), glow_size // 2)
                screen.blit(glow_surf,
                           (int(ball_cx) - glow_size, int(ball_cy) - glow_size),
                           special_flags=pygame.BLEND_ADD)

                # 회전하는 빛의 고리
                ring_time = pygame.time.get_ticks() / 800
                for i in range(6):
                    angle = ring_time + i * (math.pi * 2 / 6)
                    rx = ball_cx + math.cos(angle) * 14
                    ry = ball_cy + math.sin(angle) * 14
                    dot_surf = pygame.Surface((6, 6), pygame.SRCALPHA)
                    pygame.draw.circle(dot_surf, (255, 230, 140, 150), (3, 3), 3)
                    screen.blit(dot_surf, (int(rx) - 3, int(ry) - 3),
                               special_flags=pygame.BLEND_ADD)


class OilSpill(HeroSkill):
    """기름 투척 - 기름 덩어리를 던져 적 진영 바닥에 웅덩이 생성 [고퀄리티]"""
    def __init__(self):
        super().__init__(
            skill_id="oil_spill",
            name="Oil Spill",
            korean_name="기름 투척",
            description="기름 덩어리 2개를 던져 적 진영 바닥에 웅덩이를 만든다. 웅덩이를 밟는 동안 30% 둔화.",
            trigger=SkillTrigger.ON_BALL_HIT,
            cooldown=15.0,
            duration=0,  # 스킬 자체는 즉시 완료, 웅덩이가 독립적으로 지속
            hero_id="gear"
        )
        # 발사체 (날아가는 기름 덩어리)
        self.oil_projectiles = []
        # 바닥에 설치된 웅덩이
        self.oil_puddles = []
        self.target_is_top = False
        self.caster_is_top = False
        # 웅덩이 지속시간 (4초)
        self.puddle_duration = 4.0

        # 기름 색상 팔레트
        self._oil_colors = {
            'deep': (22, 18, 12),          # 깊은 기름색
            'base': (35, 30, 22),          # 기본 기름색
            'mid': (50, 42, 30),           # 중간 톤
            'surface': (65, 55, 38),       # 표면
            'highlight': (90, 78, 55),     # 하이라이트
            'sheen_1': (70, 55, 80),       # 무지개빛 반사 (보라)
            'sheen_2': (55, 70, 65),       # 무지개빛 반사 (청록)
            'sheen_3': (80, 70, 45),       # 무지개빛 반사 (금)
            'bubble_base': (55, 48, 35),   # 기포 기본
            'bubble_highlight': (100, 90, 70),  # 기포 하이라이트
            'bubble_sheen': (120, 110, 90),     # 기포 반짝임
        }

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        self.target_is_top = target_paddle.is_top
        self.caster_is_top = caster_paddle.is_top

        # 적 진영 바닥 Y 좌표 (보스는 상단, 플레이어는 하단)
        if self.target_is_top:
            # 적이 상단(보스) → 상단 패들 아래 바닥 (Y = 45~55)
            # 보스 패들 Y=25, 높이=40 → 하단 65, 여유 주어서 50
            target_floor_y = 50
        else:
            # 적이 하단 → 하단 패들 위 바닥 (Y = 695~705)
            # 플레이어 패들 Y=710, 여유 주어서 700
            target_floor_y = 700

        # 기름 덩어리 2개 발사
        self.oil_projectiles = []
        start_x = caster_paddle.x + caster_paddle.width // 2
        start_y = caster_paddle.y

        for i in range(2):
            # 랜덤한 목표 X 위치 (게임 영역 내: 100~660)
            target_x = random.uniform(120, 640)

            self.oil_projectiles.append({
                'x': start_x,  # 현재 위치
                'y': start_y,
                'start_x': start_x,  # 시작 위치 저장
                'start_y': start_y,
                'target_x': target_x,
                'target_y': target_floor_y,
                'size': 8,  # 시작 크기 (작게)
                'max_size': 25,  # 최대 크기
                'progress': 0.0,  # 0~1 비행 진행도
                'speed': 1.8,  # 비행 속도 (초당 progress)
                'rotation': random.uniform(0, 360),
                'wobble': random.uniform(0, math.pi * 2)
            })

        return {
            'sound': 'shootoil'
        }

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        # 발사체 업데이트
        projectiles_to_remove = []
        for proj in self.oil_projectiles:
            proj['progress'] += proj['speed'] * dt
            proj['rotation'] += dt * 180
            proj['wobble'] += dt * 5

            # 크기 점점 커짐 (progress에 비례)
            proj['size'] = 8 + (proj['max_size'] - 8) * min(proj['progress'], 1.0)

            # 위치 보간 (포물선 궤적)
            start_x = proj['start_x']
            start_y = proj['start_y']
            t = min(proj['progress'], 1.0)

            # 포물선 계산
            proj['x'] = start_x + (proj['target_x'] - start_x) * t
            # Y는 포물선 (위로 올라갔다 내려옴)
            arc_height = 150  # 포물선 높이
            if self.caster_is_top:
                # 위에서 아래로
                proj['y'] = start_y + (proj['target_y'] - start_y) * t + math.sin(t * math.pi) * arc_height
            else:
                # 아래에서 위로
                proj['y'] = start_y + (proj['target_y'] - start_y) * t - math.sin(t * math.pi) * arc_height

            # 도착 시 웅덩이로 변환
            if proj['progress'] >= 1.0:
                projectiles_to_remove.append(proj)
                # 기름 착지 사운드 재생
                try:
                    import os
                    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                    oil_path = os.path.join(project_root, "sounds", "oil.wav")
                    if os.path.exists(oil_path):
                        pygame.mixer.Sound(oil_path).play()
                except Exception:
                    pass
                # 웅덩이 생성
                puddle_w = random.uniform(72, 108)
                self.oil_puddles.append({
                    'x': proj['target_x'],
                    'y': proj['target_y'],
                    'width': puddle_w,
                    'height': random.uniform(18, 28),
                    'wobble': random.uniform(0, math.pi * 2),
                    'life': self.puddle_duration,  # 4초
                    'max_life': self.puddle_duration,
                    'alpha': 200,
                    'splash_effect': 1.0,  # 착지 스플래시 효과
                    'shimmer_time': 0.0,   # 표면 일렁임 타이머
                    'shape_seed': random.uniform(0, math.pi * 2),  # 형태 시드
                    'bubbles': [],         # 기포 리스트
                    'bubble_timer': 0.0,   # 기포 생성 타이머
                    'ripples': [],         # 표면 파문
                })

        for proj in projectiles_to_remove:
            self.oil_projectiles.remove(proj)

        # 웅덩이 업데이트
        puddles_to_remove = []
        for puddle in self.oil_puddles:
            puddle['wobble'] += dt * 2
            puddle['life'] -= dt
            puddle['shimmer_time'] = puddle.get('shimmer_time', 0) + dt

            # 스플래시 효과 감소
            if puddle['splash_effect'] > 0:
                puddle['splash_effect'] -= dt * 3

            # 마지막 1.5초 동안 페이드아웃
            if puddle['life'] < 1.5:
                puddle['alpha'] = int(200 * (puddle['life'] / 1.5))

            # --- 기포 시스템 ---
            puddle['bubble_timer'] = puddle.get('bubble_timer', 0) + dt
            bubbles = puddle.get('bubbles', [])

            # 간간이 기포 생성 (0.3~0.8초 간격)
            if puddle['bubble_timer'] > random.uniform(0.3, 0.8) and puddle['life'] > 0.5:
                puddle['bubble_timer'] = 0
                pw = puddle['width']
                ph = puddle['height']
                # 웅덩이 타원 범위 내에서 랜덤 위치
                angle = random.uniform(0, math.pi * 2)
                dist = random.uniform(0, 0.7)
                bx = puddle['x'] + math.cos(angle) * pw * 0.45 * dist
                by = puddle['y'] + math.sin(angle) * ph * 0.35 * dist
                bubbles.append({
                    'x': bx, 'y': by,
                    'size': random.uniform(1.5, 4.5),
                    'max_size': random.uniform(3.0, 6.0),
                    'grow_speed': random.uniform(2.0, 4.0),
                    'life': 0.0,
                    'max_life': random.uniform(0.6, 1.4),
                    'drift_x': random.uniform(-3, 3),
                    'phase': 'grow',  # 'grow' -> 'idle' -> 'pop'
                    'pop_timer': 0.0,
                })

            # 기포 업데이트
            new_bubbles = []
            for b in bubbles:
                b['life'] += dt
                b['x'] += b['drift_x'] * dt

                if b['phase'] == 'grow':
                    b['size'] = min(b['max_size'], b['size'] + b['grow_speed'] * dt)
                    if b['size'] >= b['max_size'] * 0.9:
                        b['phase'] = 'idle'
                elif b['phase'] == 'idle':
                    # 약간 흔들리며 대기
                    b['size'] = b['max_size'] + math.sin(b['life'] * 6) * 0.5
                    if b['life'] >= b['max_life'] * 0.8:
                        b['phase'] = 'pop'
                        b['pop_timer'] = 0.0
                elif b['phase'] == 'pop':
                    b['pop_timer'] += dt
                    # 팽창 후 터짐 (0.15초)
                    if b['pop_timer'] < 0.15:
                        b['size'] = b['max_size'] * (1 + b['pop_timer'] / 0.15 * 0.4)
                    else:
                        continue  # 기포 제거

                if b['life'] < b['max_life']:
                    new_bubbles.append(b)
                # 기포가 터질 때 파문 생성
                elif b['phase'] != 'pop':
                    ripples = puddle.get('ripples', [])
                    ripples.append({
                        'x': b['x'], 'y': b['y'],
                        'radius': b['max_size'],
                        'max_radius': b['max_size'] * 4,
                        'alpha': 120,
                        'life': 0.0,
                    })
                    puddle['ripples'] = ripples

            puddle['bubbles'] = new_bubbles

            # 파문 업데이트
            ripples = puddle.get('ripples', [])
            new_ripples = []
            for r in ripples:
                r['life'] += dt
                r['radius'] += (r['max_radius'] - r['radius']) * dt * 4
                r['alpha'] = max(0, 120 * (1 - r['life'] / 0.5))
                if r['life'] < 0.5:
                    new_ripples.append(r)
            puddle['ripples'] = new_ripples

            # 수명 종료
            if puddle['life'] <= 0:
                puddles_to_remove.append(puddle)

        for puddle in puddles_to_remove:
            self.oil_puddles.remove(puddle)

        # 적 패들이 웅덩이를 밟고 있는지 체크
        # target_paddle이 실제 타겟 패들인지 확인 (hero_positions 변경으로 인한 불일치 방지)
        if target_paddle.is_top == self.target_is_top:
            paddle_to_check = target_paddle
        else:
            # 불일치: caster_paddle이 실제 타겟이 됨 (위치가 뒤바뀐 경우)
            paddle_to_check = caster_paddle

        is_on_puddle = False
        for puddle in self.oil_puddles:
            # 패들과 웅덩이 충돌 체크
            paddle_left = paddle_to_check.x
            paddle_right = paddle_to_check.x + paddle_to_check.width
            paddle_y = paddle_to_check.y

            puddle_left = puddle['x'] - puddle['width'] / 2
            puddle_right = puddle['x'] + puddle['width'] / 2

            # X축 겹침 확인
            if paddle_right > puddle_left and paddle_left < puddle_right:
                # Y축 근접 확인 (패들이 웅덩이 근처에 있는지)
                # 상단 패들 Y=25, 하단 패들 Y=710, 웅덩이와의 거리 체크
                if abs(paddle_y - puddle['y']) <= 50:
                    is_on_puddle = True
                    break

        # 둔화 적용/해제
        target_prefix = 'top_paddle' if self.target_is_top else 'bottom_paddle'
        if is_on_puddle:
            game_state[f'{target_prefix}_slowed'] = True
            game_state[f'{target_prefix}_slow_amount'] = 0.5  # 50% 둔화 (50% 속도)
            game_state[f'{target_prefix}_oil_slowed'] = True  # 기름 웅덩이 둔화 이펙트용
        else:
            # 기름 웅덩이로 인한 둔화만 해제 (다른 스킬의 둔화 효과는 유지)
            if game_state.get(f'{target_prefix}_oil_slowed', False):
                game_state[f'{target_prefix}_slowed'] = False
                game_state[f'{target_prefix}_slow_amount'] = 1.0
                game_state[f'{target_prefix}_oil_slowed'] = False

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        # 스킬 종료 시에는 웅덩이 유지 (웅덩이는 자체 수명으로 관리)
        pass

    def update(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        """스킬 업데이트 - 발사체와 웅덩이는 is_active와 무관하게 항상 업데이트"""
        # 쿨타임 감소
        if self.current_cooldown > 0:
            self.current_cooldown -= dt

        # 발사체나 웅덩이가 있으면 항상 업데이트
        if self.oil_projectiles or self.oil_puddles:
            self._update_active_effect(dt, caster_paddle, target_paddle, ball, game_state)
        else:
            # 웅덩이가 모두 사라진 후 - 남아있는 둔화 효과 정리
            target_prefix = 'top_paddle' if self.target_is_top else 'bottom_paddle'
            if game_state.get(f'{target_prefix}_oil_slowed', False):
                game_state[f'{target_prefix}_slowed'] = False
                game_state[f'{target_prefix}_slow_amount'] = 1.0
                game_state[f'{target_prefix}_oil_slowed'] = False

    def reset_for_new_round(self, game_state: dict):
        """라운드 전환 시 웅덩이 초기화"""
        super().reset_for_new_round(game_state)
        self.oil_projectiles = []
        self.oil_puddles = []
        # 둔화 상태 클리어
        game_state['top_paddle_slowed'] = False
        game_state['top_paddle_slow_amount'] = 1.0
        game_state['top_paddle_oil_slowed'] = False
        game_state['bottom_paddle_slowed'] = False
        game_state['bottom_paddle_slow_amount'] = 1.0
        game_state['bottom_paddle_oil_slowed'] = False

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        # 발사체 그리기 (날아가는 기름 덩어리)
        for proj in self.oil_projectiles:
            self._draw_projectile(screen, proj)

        # 웅덩이 그리기
        for puddle in self.oil_puddles:
            self._draw_puddle(screen, puddle)

    def _draw_projectile(self, screen, proj):
        """고퀄리티 기름 발사체"""
        size = int(proj['size'])
        if size < 2:
            return
        pad = 8
        surf = pygame.Surface((size * 2 + pad * 2, size * 2 + pad * 2), pygame.SRCALPHA)
        center = size + pad
        wobble_offset = math.sin(proj['wobble']) * 3

        # 글로우 (부드러운 외곽)
        pygame.draw.circle(surf, (*self._oil_colors['mid'], 60), (center, center), size + 4)

        # 메인 덩어리 (불규칙 형태)
        points = []
        for angle in range(0, 360, 25):
            rad = math.radians(angle)
            r = size * (0.8 + 0.25 * math.sin(rad * 3 + proj['wobble']))
            points.append((int(center + math.cos(rad) * r), int(center + math.sin(rad) * r)))
        if len(points) >= 3:
            pygame.draw.polygon(surf, (*self._oil_colors['base'], 230), points)
            # 깊이감
            inner = [(int(center + (p[0] - center) * 0.6 + wobble_offset),
                      int(center + (p[1] - center) * 0.6)) for p in points]
            pygame.draw.polygon(surf, (*self._oil_colors['deep'], 200), inner)

        # 하이라이트 (반사광)
        hl_x = center - int(size * 0.25)
        hl_y = center - int(size * 0.25)
        hl_size = max(2, int(size * 0.35))
        pygame.draw.circle(surf, (*self._oil_colors['highlight'], 140), (hl_x, hl_y), hl_size)
        # 작은 반짝임
        pygame.draw.circle(surf, (*self._oil_colors['bubble_sheen'], 100),
                         (hl_x - 2, hl_y - 2), max(1, hl_size // 2))

        screen.blit(surf, (int(proj['x']) - center, int(proj['y']) - center))

    def _draw_puddle(self, screen, puddle):
        """고퀄리티 기름 웅덩이"""
        shimmer = puddle.get('shimmer_time', 0)
        shape_seed = puddle.get('shape_seed', 0)
        w = int(puddle['width'] + math.sin(puddle['wobble']) * 4)
        h = int(puddle['height'])
        alpha = puddle['alpha']
        if alpha < 3:
            return

        pad = 16
        surf_w = w + pad * 2
        surf_h = h + pad * 2
        surf = pygame.Surface((surf_w, surf_h), pygame.SRCALPHA)
        cx, cy = surf_w // 2, surf_h // 2

        # --- 착지 스플래시 ---
        splash_eff = puddle.get('splash_effect', 0)
        if splash_eff > 0:
            sw = int(w * (1 + splash_eff * 0.6))
            sh = int(h * (1 + splash_eff * 0.4))
            sa = int(80 * splash_eff)
            pygame.draw.ellipse(surf, (*self._oil_colors['mid'], sa),
                              (cx - sw // 2, cy - sh // 2, sw, sh))

        # --- 불규칙한 기름 웅덩이 (다층 렌더링) ---
        # 레이어 1: 외곽 글로우
        outer_points = self._oil_shape_points(cx, cy, w * 0.55, h * 0.55, shape_seed, shimmer, 0.12)
        if len(outer_points) >= 3:
            pygame.draw.polygon(surf, (*self._oil_colors['mid'], int(alpha * 0.3)), outer_points)

        # 레이어 2: 메인 기름
        main_points = self._oil_shape_points(cx, cy, w * 0.48, h * 0.48, shape_seed, shimmer, 0.08)
        if len(main_points) >= 3:
            pygame.draw.polygon(surf, (*self._oil_colors['base'], alpha), main_points)

        # 레이어 3: 깊은 중심
        deep_points = self._oil_shape_points(cx, cy, w * 0.32, h * 0.32, shape_seed + 1.0, shimmer, 0.05)
        if len(deep_points) >= 3:
            pygame.draw.polygon(surf, (*self._oil_colors['deep'], int(alpha * 0.85)), deep_points)

        # --- 무지개빛 반사 (기름 특유의 iridescence) ---
        sheen_colors = [self._oil_colors['sheen_1'], self._oil_colors['sheen_2'], self._oil_colors['sheen_3']]
        for i, sc in enumerate(sheen_colors):
            sx_offset = math.sin(shimmer * 1.2 + i * 2.1) * w * 0.15
            sy_offset = math.cos(shimmer * 0.9 + i * 1.7) * h * 0.1
            sw_ratio = 0.25 + 0.08 * math.sin(shimmer * 1.5 + i)
            sh_ratio = 0.3 + 0.1 * math.sin(shimmer * 1.8 + i)
            sa = int(alpha * (0.15 + 0.08 * math.sin(shimmer * 2.0 + i * 0.7)))
            sw = max(4, int(w * sw_ratio))
            sh_val = max(2, int(h * sh_ratio))
            pygame.draw.ellipse(surf, (*sc, sa),
                              (int(cx + sx_offset - sw // 2), int(cy + sy_offset - sh_val // 2), sw, sh_val))

        # --- 표면 하이라이트 (큰 반사) ---
        hl_x = cx + int(math.sin(shimmer * 0.7) * w * 0.12) - int(w * 0.08)
        hl_y = cy - int(h * 0.12)
        hl_w = max(3, int(w * 0.2))
        hl_h = max(2, int(h * 0.2))
        hl_a = int(alpha * (0.2 + 0.08 * math.sin(shimmer * 1.3)))
        pygame.draw.ellipse(surf, (*self._oil_colors['highlight'], hl_a),
                          (hl_x, hl_y, hl_w, hl_h))

        # --- 가장자리 테두리 (점성 느낌) ---
        edge_points = self._oil_shape_points(cx, cy, w * 0.5, h * 0.5, shape_seed, shimmer, 0.1)
        if len(edge_points) >= 3:
            pygame.draw.polygon(surf, (*self._oil_colors['surface'], int(alpha * 0.4)), edge_points, 2)

        screen.blit(surf, (int(puddle['x'] - cx), int(puddle['y'] - cy)))

        # --- 기포 (서피스 밖에서 직접 screen에 그리기) ---
        for b in puddle.get('bubbles', []):
            self._draw_bubble(screen, b, alpha)

        # --- 파문 ---
        for r in puddle.get('ripples', []):
            if r['alpha'] > 3:
                rr = max(1, int(r['radius']))
                rs = pygame.Surface((rr * 2 + 4, rr * 2 + 4), pygame.SRCALPHA)
                rc = rr + 2
                ra = int(max(0, min(255, r['alpha'])))
                pygame.draw.circle(rs, (*self._oil_colors['surface'], ra), (rc, rc), rr, 1)
                screen.blit(rs, (int(r['x']) - rc, int(r['y']) - rc))

    def _oil_shape_points(self, cx, cy, half_w, half_h, seed, time, irregularity):
        """기름 웅덩이 불규칙 타원 꼭짓점 생성"""
        points = []
        for angle in range(0, 360, 18):
            rad = math.radians(angle)
            wobble = 1.0 + irregularity * math.sin(rad * 4 + seed + time * 0.8)
            px = cx + int(math.cos(rad) * half_w * wobble)
            py = cy + int(math.sin(rad) * half_h * wobble)
            points.append((px, py))
        return points

    def _draw_bubble(self, screen, bubble, puddle_alpha):
        """기포 하나 그리기"""
        s = max(1, int(bubble['size']))
        phase = bubble['phase']

        if phase == 'pop' and bubble['pop_timer'] >= 0.08:
            # 터지는 순간 - 작은 파편
            pop_p = bubble['pop_timer'] / 0.15
            for i in range(4):
                angle = math.pi * 2 * i / 4 + bubble['life']
                dist = s * 1.5 * pop_p
                px = int(bubble['x'] + math.cos(angle) * dist)
                py = int(bubble['y'] + math.sin(angle) * dist)
                frag_a = int(80 * (1 - pop_p))
                if frag_a > 3:
                    ps = pygame.Surface((4, 4), pygame.SRCALPHA)
                    pygame.draw.circle(ps, (*self._oil_colors['bubble_highlight'], frag_a), (2, 2), 1)
                    screen.blit(ps, (px - 2, py - 2))
            return

        ba = int(min(255, puddle_alpha * 0.9))
        pad = 4
        bs = pygame.Surface((s * 2 + pad * 2, s * 2 + pad * 2), pygame.SRCALPHA)
        bc = s + pad

        # 기포 본체 (반투명 원)
        pygame.draw.circle(bs, (*self._oil_colors['bubble_base'], int(ba * 0.6)), (bc, bc), s)
        # 테두리 (약간 밝은 테두리로 입체감)
        pygame.draw.circle(bs, (*self._oil_colors['bubble_highlight'], int(ba * 0.5)), (bc, bc), s, 1)
        # 반사 하이라이트 (좌상단 작은 점)
        if s >= 3:
            pygame.draw.circle(bs, (*self._oil_colors['bubble_sheen'], int(ba * 0.7)),
                             (bc - max(1, s // 3), bc - max(1, s // 3)), max(1, s // 3))

        screen.blit(bs, (int(bubble['x']) - bc, int(bubble['y']) - bc))


# ============================================================================
# 쿠로카게 스킬 - 그림자 닌자 (공격적)
# ============================================================================
class ShadowClone(HeroSkill):
    """그림자분신 - 아카무 리고 스타일 분신 (Stage 8 방식으로 구현)"""

    # 게임 영역 경계 (투기장: 필러 없이 전체 760px 사용)
    GAME_LEFT = 0
    GAME_RIGHT = 760

    # 분신 상수 (Stage 8과 동일하게)
    CLONE_WIDTH = 80       # 충돌 판정 너비
    CLONE_HEIGHT = 40      # 충돌 판정 높이
    EMERGE_DURATION = 0.4  # 등장 애니메이션 시간 (초)
    DEATH_DURATION = 0.7   # 소멸 애니메이션 시간 (초)

    def __init__(self):
        super().__init__(
            skill_id="shadow_clone",
            name="Shadow Clone",
            korean_name="그림자분신",
            description="그림자 분신을 소환하여 공을 반사한다",
            trigger=SkillTrigger.ON_COOLDOWN,
            cooldown=20.0,
            duration=6.0,
            hero_id="kurokage"
        )
        self.clones = []  # 활성 분신 목록
        self.dying_clones = []  # 소멸 중인 분신 목록
        self.spawn_x = 0  # 소환 시작 위치
        self.spawn_y = 0
        self.caster_is_top = False
        self.caster_facing = "down"

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        self.caster_is_top = caster_paddle.is_top
        self.spawn_x = caster_paddle.x + caster_paddle.width // 2

        # 분신을 캐스터와 동일한 Y 위치에 소환
        self.spawn_y = caster_paddle.y + caster_paddle.height // 2

        self.caster_facing = "down" if caster_paddle.is_top else "up"

        # 분신 3~4개 생성 (좌우로 벌어지며 등장)
        clone_count = random.randint(3, 4)
        if clone_count == 3:
            offsets = [-120, 0, 120]  # 3개: 좌, 중앙, 우
        else:
            offsets = [-150, -50, 50, 150]  # 4개: 좌좌, 좌, 우, 우우
        self.clones = []
        self.dying_clones = []

        for i, offset in enumerate(offsets):
            direction = -1 if offset < 0 else 1
            # 각 분신마다 독립적인 pygame.Rect 생성
            clone_rect = pygame.Rect(0, 0, self.CLONE_WIDTH, self.CLONE_HEIGHT)
            clone_rect.center = (self.spawn_x, self.spawn_y)

            clone = {
                'rect': clone_rect,
                'offset_x': offset,
                'target_x': self.spawn_x + offset,  # 최종 목표 X 위치 저장
                'vx': random.uniform(8.0, 12.0) * direction,
                'spawn_time': 0.0,
                'active': True,
                'id': i,
            }
            self.clones.append(clone)

        # 프레임 카운터 초기화
        self._frame_count = 0
        self._draw_count = 0

        game_state['has_shadow_clones'] = True

        return {
            'screen_effect': ScreenEffect.FLASH,
            'flash_color': (40, 40, 60),
            'flash_duration': 0.15,
            'sound': 'shadow'
        }

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        new_clones = []

        for clone in self.clones:

            if not clone['active']:
                continue

            clone['spawn_time'] += dt
            rect = clone['rect']

            # 등장 애니메이션: 중앙에서 좌우로 벌어짐
            if clone['spawn_time'] < self.EMERGE_DURATION:
                t = clone['spawn_time'] / self.EMERGE_DURATION
                t = 1 - (1 - t) ** 2  # Ease-out
                rect.centerx = int(self.spawn_x + clone['offset_x'] * t)
                rect.centery = self.spawn_y
                clone['emerge_complete'] = False
            else:
                # 등장 완료 시 한 번만 위치 확정
                if not clone.get('emerge_complete', False):
                    rect.centerx = clone['target_x']
                    rect.centery = self.spawn_y
                    clone['emerge_complete'] = True

                # 자유 이동: 좌우로 움직이며 벽에서 튕김
                move_amount = int(clone['vx'])
                rect.x += move_amount

                # 벽 충돌 (튕김)
                if rect.left < self.GAME_LEFT:
                    rect.left = self.GAME_LEFT
                    clone['vx'] = abs(clone['vx'])  # 오른쪽으로 튕김
                elif rect.right > self.GAME_RIGHT:
                    rect.right = self.GAME_RIGHT
                    clone['vx'] = -abs(clone['vx'])  # 왼쪽으로 튕김

                # 약간의 난수 가속
                clone['vx'] += random.uniform(-0.3, 0.3)

                # 속도 클램프 (최소 6, 최대 12)
                speed = abs(clone['vx'])
                if speed > 12.0:
                    clone['vx'] = (clone['vx'] / speed) * 12.0
                elif speed < 6.0:
                    clone['vx'] = 6.0 if clone['vx'] >= 0 else -6.0

            # 공과 충돌 체크 (등장 애니메이션 후에만) - Stage 8 방식
            if ball is not None and clone['spawn_time'] >= self.EMERGE_DURATION:
                ball_rect = pygame.Rect(int(ball.x), int(ball.y), int(ball.width), int(ball.height))

                if rect.colliderect(ball_rect):
                    # 공 반사 - 직접 ball 속도 수정 (Stage 8 방식)
                    # 타격 위치에 따른 X 방향 조정
                    hit_offset = (ball.x + ball.width / 2) - rect.centerx
                    angle_factor = hit_offset / (self.CLONE_WIDTH / 2)

                    # Y 방향 반전 (상대 방향으로)
                    if self.caster_is_top:
                        ball.vy = abs(ball.vy) * 1.1  # 아래로
                    else:
                        ball.vy = -abs(ball.vy) * 1.1  # 위로

                    # X 방향 조정
                    ball.vx = ball.vx * 0.7 + angle_factor * 4.0

                    # 소멸 애니메이션 시작
                    dying_clone = {
                        'rect': rect.copy(),
                        'death_time': 0.0,
                        'id': clone['id'],
                    }
                    self.dying_clones.append(dying_clone)
                    clone['active'] = False
                    continue

            new_clones.append(clone)

        self.clones = new_clones
        # dying_clones 업데이트는 update() 메서드에서 처리

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        game_state['has_shadow_clones'] = False
        # 남아있는 활성 분신들을 dying_clones로 이동 (소멸 애니메이션 재생)
        for clone in self.clones:
            if clone['active']:
                dying_clone = {
                    'rect': clone['rect'].copy(),
                    'death_time': 0.0,
                    'id': clone['id'],
                }
                self.dying_clones.append(dying_clone)
        self.clones = []

    def reset_for_new_round(self, game_state: dict):
        """라운드 전환 시 그림자분신 강제 초기화"""
        super().reset_for_new_round(game_state)
        self.clones = []
        self.dying_clones = []
        game_state['has_shadow_clones'] = False

    def update(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        """스킬 업데이트 - dying_clones는 is_active와 무관하게 항상 업데이트"""
        # 부모 클래스 업데이트 (쿨타임, 활성 효과 등)
        super().update(dt, caster_paddle, target_paddle, ball, game_state)

        # dying_clones는 is_active가 False여도 계속 업데이트
        if self.dying_clones:
            new_dying = []
            for dying in self.dying_clones:
                dying['death_time'] += dt
                if dying['death_time'] < self.DEATH_DURATION:
                    new_dying.append(dying)
            self.dying_clones = new_dying

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        renderer = get_shadow_clone_renderer() if HERO_PADDLE_RENDERER_AVAILABLE else None

        # 활성 분신 그리기
        for clone in self.clones:
            self._draw_clone(screen, clone, caster_paddle, renderer)

        # 소멸 중인 분신 그리기 (홀로그램 증발 효과) - is_active와 무관
        for dying in self.dying_clones:
            self._draw_dying_clone(screen, dying, caster_paddle, renderer)

    def _draw_clone(self, screen: pygame.Surface, clone: dict, caster_paddle, renderer):
        """활성 분신 렌더링 - 실제 캐릭터 이미지 사용"""
        rect = clone['rect']
        spawn_time = clone['spawn_time']

        # 등장 시 페이드인
        emerge_progress = min(1.0, spawn_time / self.EMERGE_DURATION)

        # 폴짝 모션 (위아래)
        hop = int(4 * math.sin(spawn_time * 5))

        alpha = int(200 * emerge_progress)
        x = rect.centerx
        y = rect.centery + hop

        # 바닥 그림자 먼저 그리기
        shadow_width = int(self.CLONE_WIDTH * 0.9)
        shadow_surf = pygame.Surface((shadow_width, 10), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_surf, (10, 10, 25, int(alpha * 0.5)),
                          (0, 0, shadow_width, 10))
        screen.blit(shadow_surf, (x - shadow_width // 2, y + 15))

        # HeroPaddleRenderer가 있으면 실제 캐릭터 그리기
        if renderer and HERO_PADDLE_RENDERER_AVAILABLE:
            char_width = 120
            char_height = 100
            temp_surf = pygame.Surface((char_width, char_height), pygame.SRCALPHA)

            renderer.update(1/60)
            shadow_color = (70, 60, 100)

            try:
                renderer.draw_hero_paddle(
                    temp_surf,
                    "kurokage",
                    char_width // 2,
                    char_height - 10,
                    100,
                    12,
                    self.caster_facing,
                    shadow_color,
                    "preview"
                )
                temp_surf.set_alpha(alpha)
                screen.blit(temp_surf, (x - char_width // 2, y - char_height + 15))

            except Exception as e:
                self._draw_fallback_clone(screen, x, y, alpha)
        else:
            self._draw_fallback_clone(screen, x, y, alpha)

    def _draw_fallback_clone(self, screen: pygame.Surface, x: int, y: int, alpha: int):
        """폴백 분신 렌더링 (실루엣 스타일)"""
        # 닌자 실루엣
        body_color = (50, 50, 70, alpha)
        outline_color = (80, 80, 120, alpha)

        # 몸통
        body_surf = pygame.Surface((40, 50), pygame.SRCALPHA)
        pygame.draw.ellipse(body_surf, body_color, (5, 20, 30, 30))  # 몸
        pygame.draw.circle(body_surf, body_color, (20, 12), 12)  # 머리
        pygame.draw.ellipse(body_surf, outline_color, (5, 20, 30, 30), 1)
        pygame.draw.circle(body_surf, outline_color, (20, 12), 12, 1)

        # 눈 (붉은 빛)
        pygame.draw.circle(body_surf, (200, 50, 50, alpha), (15, 10), 2)
        pygame.draw.circle(body_surf, (200, 50, 50, alpha), (25, 10), 2)

        screen.blit(body_surf, (x - 20, y - 45))

    def _draw_dying_clone(self, screen: pygame.Surface, dying: dict, caster_paddle, renderer):
        """소멸 중인 분신 렌더링 (홀로그램 증발 효과)"""
        death_progress = dying['death_time'] / self.DEATH_DURATION
        base_alpha = int(200 * (1.0 - death_progress))

        rect = dying['rect']
        x = rect.centerx
        y = rect.centery

        # 글리치 효과 (떨림 + 색상 분리)
        glitch_intensity = death_progress * 15
        glitch_x = int(math.sin(dying['death_time'] * 35) * glitch_intensity)
        glitch_y = int(math.cos(dying['death_time'] * 28) * glitch_intensity * 0.5)

        char_width = 150
        char_height = 120

        if renderer and HERO_PADDLE_RENDERER_AVAILABLE and base_alpha > 30:
            # RGB 분리 효과로 캐릭터 3번 그리기
            for color_offset, tint in [(-4, (255, 80, 80)), (0, (180, 180, 220)), (4, (80, 255, 255))]:
                temp_surf = pygame.Surface((char_width, char_height), pygame.SRCALPHA)
                try:
                    renderer.draw_hero_paddle(
                        temp_surf,
                        "kurokage",
                        char_width // 2,
                        char_height - 15,
                        self.CLONE_WIDTH,
                        12,
                        self.caster_facing,
                        tint,
                        "paddle"
                    )

                    # 스캔라인 효과 (위에서부터 사라짐)
                    scanline_y = int(char_height * death_progress)
                    if scanline_y > 0:
                        erase_rect = pygame.Rect(0, 0, char_width, scanline_y)
                        temp_surf.fill((0, 0, 0, 0), erase_rect)

                    temp_surf.set_alpha(int(base_alpha * 0.5))
                    screen.blit(temp_surf, (x - char_width // 2 + glitch_x + color_offset, y - char_height + 25 + glitch_y))

                except Exception:
                    # 폴백: 단순 타원
                    surf = pygame.Surface((50, 60), pygame.SRCALPHA)
                    pygame.draw.ellipse(surf, (*tint, base_alpha // 2), (0, 0, 50, 60))
                    screen.blit(surf, (x - 25 + glitch_x + color_offset, y - 50 + glitch_y))

        # 파티클 효과 (위로 흩어짐)
        if death_progress > 0.15:
            num_particles = int(12 * death_progress)
            for i in range(num_particles):
                px = x + random.randint(-35, 35)
                py = y - int(60 * death_progress) + random.randint(-20, 20)
                p_alpha = int(base_alpha * 0.5 * random.uniform(0.4, 1.0))
                if p_alpha > 10:
                    p_size = random.randint(2, 5)
                    p_color = random.choice([(100, 100, 180), (150, 100, 200), (80, 80, 150)])
                    pygame.draw.circle(screen, (*p_color, p_alpha), (px, py), p_size)


class IllusionShuriken(HeroSkill):
    """환영수리검 - 3개의 수리검을 순차 발사, 벽에서 튕기고 넉백 유발"""

    # 게임 영역 경계 (투기장: 필러 없이 전체 760px 사용)
    GAME_LEFT = 0
    GAME_RIGHT = 760
    GAME_TOP = 0
    GAME_BOTTOM = 750
    SHURIKEN_SIZE = 18  # 수리검 반지름

    def __init__(self):
        super().__init__(
            skill_id="illusion_shuriken",
            name="Illusion Shuriken",
            korean_name="환영수리검",
            description="3~5개의 수리검을 순차 발사하여 상대를 넉백시킨다",
            trigger=SkillTrigger.ON_BALL_HIT,
            cooldown=14.0,
            duration=999.0,  # 시간 제한 없음 - 수리검이 모두 사라질 때까지 유지
            hero_id="kurokage"
        )
        self.shurikens = []  # 활성 수리검 목록
        self.spawn_timer = 0  # 순차 발사 타이머
        self.shurikens_spawned = 0  # 발사된 수리검 수
        self.total_shurikens = 3  # 총 발사할 수리검 수 (3~5 랜덤)
        self.target_is_top = False
        self.caster_is_top = False
        self.knockback_applied = False
        self.hit_effects = []  # 히트 이펙트

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        self.target_is_top = target_paddle.is_top
        self.caster_is_top = caster_paddle.is_top
        self.shurikens = []
        self.spawn_timer = 0
        self.shurikens_spawned = 0
        self.total_shurikens = random.randint(3, 5)  # 3~5개 랜덤
        self.knockback_applied = False
        self.hit_effects = []

        # 첫 번째 수리검 즉시 발사
        self._spawn_shuriken(caster_paddle, 0)

        return {
            'sound': 'shuriken'
        }

    def _spawn_shuriken(self, caster_paddle, index: int):
        """수리검 생성 - 좌우 번갈아가며 부채꼴 형태로 발사 (3~5개)"""
        # 각도 범위: 20~60도 (0.35~1.05 rad)
        # 수리검 개수에 따라 각도를 균등 분배
        total = self.total_shurikens

        # 부채꼴 형태로 각도 분배 (-60도 ~ +60도 범위)
        # 예: 3개 → -45, 0, +45 / 4개 → -45, -15, +15, +45 / 5개 → -50, -25, 0, +25, +50
        if total == 3:
            angles_deg = [-45, 0, 45]
        elif total == 4:
            angles_deg = [-50, -17, 17, 50]
        else:  # 5개
            angles_deg = [-55, -28, 0, 28, 55]

        # 인덱스에 해당하는 각도 선택 (약간의 랜덤 추가)
        base_angle_deg = angles_deg[index] if index < len(angles_deg) else 0
        angle_deg = base_angle_deg + random.uniform(-5, 5)  # ±5도 랜덤 변화
        angle_rad = math.radians(angle_deg)

        speed = 450  # 수리검 속도

        # 방향 계산: caster_is_top이면 아래로(+Y), 아니면 위로(-Y)
        if self.caster_is_top:
            # 상단에서 하단으로 발사
            vy = speed * math.cos(angle_rad)
            vx = speed * math.sin(angle_rad)
        else:
            # 하단에서 상단으로 발사
            vy = -speed * math.cos(angle_rad)
            vx = speed * math.sin(angle_rad)

        # 패들 중앙에서 발사
        spawn_x = caster_paddle.x + caster_paddle.width // 2
        spawn_y = caster_paddle.y + (caster_paddle.height if self.caster_is_top else 0)

        self.shurikens.append({
            'x': spawn_x,
            'y': spawn_y,
            'vx': vx,
            'vy': vy,
            'rotation': 0,
            'bounces': 0,  # 튕긴 횟수
            'max_bounces': random.randint(5, 8),  # 5~8회 랜덤 소멸
            'active': True,
            'trail': []  # 잔상 효과
        })
        self.shurikens_spawned += 1

        # 수리검 투척 사운드 재생
        try:
            project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            throw_path = os.path.join(project_root, "sounds", "shurikenthrow.wav")
            if os.path.exists(throw_path):
                pygame.mixer.Sound(throw_path).play()
        except Exception:
            pass

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        # 순차 발사 (0.4초 간격)
        if self.shurikens_spawned < self.total_shurikens:
            self.spawn_timer += dt
            if self.spawn_timer >= 0.4:
                self.spawn_timer = 0
                self._spawn_shuriken(caster_paddle, self.shurikens_spawned)

        # 수리검 업데이트
        for shuriken in self.shurikens:
            if not shuriken['active']:
                continue

            # 잔상 추가
            shuriken['trail'].append({
                'x': shuriken['x'],
                'y': shuriken['y'],
                'alpha': 150,
                'rotation': shuriken['rotation']
            })
            # 잔상 최대 5개 유지
            if len(shuriken['trail']) > 5:
                shuriken['trail'].pop(0)

            # 이동
            shuriken['x'] += shuriken['vx'] * dt
            shuriken['y'] += shuriken['vy'] * dt
            shuriken['rotation'] += dt * 1200  # 회전

            # 벽 충돌 (좌우 바운스) - 수리검 크기 고려
            left_bound = self.GAME_LEFT + self.SHURIKEN_SIZE
            right_bound = self.GAME_RIGHT - self.SHURIKEN_SIZE
            if shuriken['x'] <= left_bound:
                shuriken['x'] = left_bound
                shuriken['vx'] = abs(shuriken['vx'])  # 오른쪽으로 튕김
                shuriken['bounces'] += 1
            elif shuriken['x'] >= right_bound:
                shuriken['x'] = right_bound
                shuriken['vx'] = -abs(shuriken['vx'])  # 왼쪽으로 튕김
                shuriken['bounces'] += 1

            # 상하 벽 충돌 (바운스) - 수리검 크기 고려
            top_bound = self.GAME_TOP + self.SHURIKEN_SIZE
            bottom_bound = self.GAME_BOTTOM - self.SHURIKEN_SIZE
            if shuriken['y'] <= top_bound:
                shuriken['y'] = top_bound
                shuriken['vy'] = abs(shuriken['vy'])  # 아래로 튕김
                shuriken['bounces'] += 1
            elif shuriken['y'] >= bottom_bound:
                shuriken['y'] = bottom_bound
                shuriken['vy'] = -abs(shuriken['vy'])  # 위로 튕김
                shuriken['bounces'] += 1

            # 최대 반사 횟수(5~8) 도달 시 비활성화
            if shuriken['bounces'] >= shuriken['max_bounces']:
                shuriken['active'] = False
                continue

            # 상대 패들과 충돌 체크
            paddle_left = target_paddle.x
            paddle_right = target_paddle.x + target_paddle.width
            paddle_top = target_paddle.y
            paddle_bottom = target_paddle.y + target_paddle.height

            if (paddle_left - 15 <= shuriken['x'] <= paddle_right + 15 and
                paddle_top - 15 <= shuriken['y'] <= paddle_bottom + 15):
                # 히트!
                shuriken['active'] = False

                # 수리검 히트 사운드 재생
                try:
                    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                    hit_path = os.path.join(project_root, "sounds", "shurikenhit.wav")
                    if os.path.exists(hit_path):
                        pygame.mixer.Sound(hit_path).play()
                except Exception:
                    pass

                # 넉백 방향 결정 (수리검 X 속도 방향, 0이면 랜덤)
                if abs(shuriken['vx']) < 10:
                    knockback_dir = random.choice([-1, 1])
                else:
                    knockback_dir = 1 if shuriken['vx'] > 0 else -1

                # 넉백 적용 (강한 좌/우 밀어내기)
                target_prefix = 'top_paddle' if self.target_is_top else 'bottom_paddle'
                game_state[f'{target_prefix}_knockback'] = True
                game_state[f'{target_prefix}_knockback_dir'] = knockback_dir
                game_state[f'{target_prefix}_knockback_vel'] = 120  # 넉백 속도 증가

                # 히트 이펙트 추가 (강화된 닌자 스타일)
                # 메인 파티클 (보라색 계열 - 20개)
                main_particles = [
                    {
                        'x': shuriken['x'],
                        'y': shuriken['y'],
                        'vx': random.uniform(-300, 300),
                        'vy': random.uniform(-300, 300),
                        'life': 0.5,
                        'color': random.choice([
                            (180, 120, 255),  # 밝은 보라
                            (140, 80, 200),   # 진한 보라
                            (100, 60, 180),   # 어두운 보라
                        ]),
                        'size': random.uniform(3, 7)
                    }
                    for _ in range(20)
                ]
                # 스파크 파티클 (금빛 - 12개)
                spark_particles = [
                    {
                        'x': shuriken['x'],
                        'y': shuriken['y'],
                        'vx': random.uniform(-400, 400),
                        'vy': random.uniform(-400, 400),
                        'life': 0.3,
                        'color': random.choice([
                            (255, 220, 100),  # 금색
                            (255, 180, 50),   # 주황금
                            (255, 255, 150),  # 밝은 금
                        ]),
                        'size': random.uniform(2, 4),
                        'is_spark': True
                    }
                    for _ in range(12)
                ]
                # 슬래시 자국 (X자 베임)
                slash_angle = random.uniform(0, 360)
                self.hit_effects.append({
                    'x': shuriken['x'],
                    'y': shuriken['y'],
                    'timer': 0.5,
                    'particles': main_particles + spark_particles,
                    'slash_angle': slash_angle,
                    'shockwave_radius': 0,
                    'flash_intensity': 1.0
                })
                # 화면 흔들림
                game_state['screen_shake'] = 8

        # 잔상 알파값 감소
        for shuriken in self.shurikens:
            for trail in shuriken['trail']:
                trail['alpha'] = max(0, trail['alpha'] - dt * 400)

        # 히트 이펙트 업데이트
        for effect in self.hit_effects:
            effect['timer'] -= dt
            # 충격파 확장
            effect['shockwave_radius'] = effect.get('shockwave_radius', 0) + dt * 300
            # 플래시 감쇠
            effect['flash_intensity'] = max(0, effect.get('flash_intensity', 1.0) - dt * 4)
            for p in effect['particles']:
                p['x'] += p['vx'] * dt
                p['y'] += p['vy'] * dt
                p['life'] -= dt
                # 스파크는 빠르게 감속
                if p.get('is_spark'):
                    p['vx'] *= 0.92
                    p['vy'] *= 0.92

        # 완료된 이펙트 제거
        self.hit_effects = [e for e in self.hit_effects if e['timer'] > 0]

        # 모든 수리검이 사라지면 스킬 종료 (전부 발사된 후에만 체크)
        if self.shurikens_spawned >= self.total_shurikens:
            active_shurikens = [s for s in self.shurikens if s['active']]
            if not active_shurikens:
                self.active_timer = 0  # 스킬 자동 종료 트리거

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        self.shurikens = []
        self.hit_effects = []
        # 넉백 상태 클리어
        for prefix in ['top_paddle', 'bottom_paddle']:
            if f'{prefix}_knockback' in game_state:
                game_state[f'{prefix}_knockback'] = False

    def reset_for_new_round(self, game_state: dict):
        """라운드 전환 시 환영수리검 강제 초기화"""
        super().reset_for_new_round(game_state)
        self.shurikens = []
        self.hit_effects = []
        self.shurikens_spawned = 0
        self.total_shurikens = 3
        self.spawn_timer = 0
        # 넉백 상태 클리어
        for prefix in ['top_paddle', 'bottom_paddle']:
            if f'{prefix}_knockback' in game_state:
                game_state[f'{prefix}_knockback'] = False

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        # 잔상 그리기
        for shuriken in self.shurikens:
            for trail in shuriken['trail']:
                if trail['alpha'] > 0:
                    self._draw_shuriken(screen, trail['x'], trail['y'],
                                       trail['rotation'], int(trail['alpha']))

        # 활성 수리검 그리기
        for shuriken in self.shurikens:
            if shuriken['active']:
                self._draw_shuriken(screen, shuriken['x'], shuriken['y'],
                                   shuriken['rotation'], 255)

        # 히트 이펙트 그리기 (강화된 닌자 스타일)
        for effect in self.hit_effects:
            ex, ey = int(effect['x']), int(effect['y'])
            progress = 1 - (effect['timer'] / 0.5)  # 0 → 1

            # 1. 중앙 플래시 (밝은 폭발)
            flash_intensity = effect.get('flash_intensity', 0)
            if flash_intensity > 0:
                flash_size = int(40 * flash_intensity)
                flash_surf = pygame.Surface((flash_size * 2, flash_size * 2), pygame.SRCALPHA)
                flash_alpha = int(200 * flash_intensity)
                pygame.draw.circle(flash_surf, (255, 220, 255, flash_alpha),
                                 (flash_size, flash_size), flash_size)
                pygame.draw.circle(flash_surf, (255, 255, 255, min(255, flash_alpha + 50)),
                                 (flash_size, flash_size), flash_size // 2)
                screen.blit(flash_surf, (ex - flash_size, ey - flash_size))

            # 2. 충격파 링 (다중)
            shockwave_r = effect.get('shockwave_radius', 0)
            if shockwave_r > 0 and shockwave_r < 80:
                for i, (color, offset) in enumerate([
                    ((180, 120, 255), 0),
                    ((140, 80, 200), 8),
                    ((100, 60, 180), 16)
                ]):
                    ring_r = int(shockwave_r - offset)
                    if ring_r > 0:
                        ring_alpha = int(180 * (1 - shockwave_r / 80))
                        ring_surf = pygame.Surface((ring_r * 2 + 4, ring_r * 2 + 4), pygame.SRCALPHA)
                        pygame.draw.circle(ring_surf, (*color, ring_alpha),
                                         (ring_r + 2, ring_r + 2), ring_r, 2)
                        screen.blit(ring_surf, (ex - ring_r - 2, ey - ring_r - 2))

            # 3. X자 슬래시 마크 (베인 자국)
            slash_angle = effect.get('slash_angle', 45)
            slash_alpha = int(255 * (1 - progress * 0.7))
            slash_length = 35 + progress * 15  # 점점 길어짐
            if slash_alpha > 20:
                for angle_offset in [0, 90]:  # X자 형태
                    angle_rad = math.radians(slash_angle + angle_offset)
                    x1 = ex + math.cos(angle_rad) * slash_length
                    y1 = ey + math.sin(angle_rad) * slash_length
                    x2 = ex - math.cos(angle_rad) * slash_length
                    y2 = ey - math.sin(angle_rad) * slash_length
                    # 메인 슬래시
                    slash_surf = pygame.Surface((int(slash_length * 2 + 10), int(slash_length * 2 + 10)), pygame.SRCALPHA)
                    center = int(slash_length + 5)
                    lx1 = center + math.cos(angle_rad) * slash_length
                    ly1 = center + math.sin(angle_rad) * slash_length
                    lx2 = center - math.cos(angle_rad) * slash_length
                    ly2 = center - math.sin(angle_rad) * slash_length
                    # 글로우 효과
                    pygame.draw.line(slash_surf, (180, 120, 255, slash_alpha // 2),
                                   (lx1, ly1), (lx2, ly2), 6)
                    pygame.draw.line(slash_surf, (220, 180, 255, slash_alpha),
                                   (lx1, ly1), (lx2, ly2), 3)
                    pygame.draw.line(slash_surf, (255, 255, 255, slash_alpha),
                                   (lx1, ly1), (lx2, ly2), 1)
                    screen.blit(slash_surf, (ex - center, ey - center))

            # 4. 파티클 (보라색 + 금빛 스파크)
            for p in effect['particles']:
                if p['life'] > 0:
                    max_life = 0.3 if p.get('is_spark') else 0.5
                    life_ratio = p['life'] / max_life
                    alpha = int(255 * life_ratio)
                    size = int(p.get('size', 4) * life_ratio)
                    if size > 0 and alpha > 10:
                        color = p.get('color', (150, 130, 200))
                        # 스파크는 꼬리 효과
                        if p.get('is_spark') and abs(p['vx']) + abs(p['vy']) > 50:
                            tail_length = min(15, (abs(p['vx']) + abs(p['vy'])) * 0.03)
                            tail_x = p['x'] - p['vx'] * 0.02
                            tail_y = p['y'] - p['vy'] * 0.02
                            pygame.draw.line(screen, (*color, alpha // 2),
                                           (int(p['x']), int(p['y'])),
                                           (int(tail_x), int(tail_y)), max(1, size // 2))
                        # 메인 파티클
                        surf = pygame.Surface((size * 2 + 2, size * 2 + 2), pygame.SRCALPHA)
                        pygame.draw.circle(surf, (*color, alpha), (size + 1, size + 1), size)
                        # 밝은 중심
                        if size > 2:
                            pygame.draw.circle(surf, (255, 255, 255, alpha // 2),
                                             (size + 1, size + 1), size // 2)
                        screen.blit(surf, (int(p['x'] - size - 1), int(p['y'] - size - 1)))

    def _draw_shuriken(self, screen: pygame.Surface, x: float, y: float,
                       rotation: float, alpha: int):
        """수리검 그리기"""
        shuriken_size = 18
        surf = pygame.Surface((shuriken_size * 2, shuriken_size * 2), pygame.SRCALPHA)

        center = shuriken_size
        # 4개의 날
        for i in range(4):
            angle = math.radians(rotation + i * 90)
            x1 = center + math.cos(angle) * 4
            y1 = center + math.sin(angle) * 4
            x2 = center + math.cos(angle) * shuriken_size
            y2 = center + math.sin(angle) * shuriken_size

            # 날 색상 (보라빛 금속)
            blade_color = (130, 110, 170, alpha)
            edge_color = (180, 160, 220, alpha)

            pygame.draw.polygon(surf, blade_color, [
                (center, center),
                (x1 + math.cos(angle + 0.4) * 7, y1 + math.sin(angle + 0.4) * 7),
                (x2, y2),
                (x1 + math.cos(angle - 0.4) * 7, y1 + math.sin(angle - 0.4) * 7)
            ])

            # 날 가장자리 하이라이트
            pygame.draw.line(surf, edge_color,
                           (center, center), (x2, y2), 1)

        # 중앙 원
        pygame.draw.circle(surf, (100, 80, 140, alpha), (center, center), 5)
        pygame.draw.circle(surf, (150, 130, 190, alpha), (center, center), 3)

        screen.blit(surf, (int(x - shuriken_size), int(y - shuriken_size)))


# ============================================================================
# 영웅 스킬 매핑
# ============================================================================
HERO_SKILLS: Dict[str, List[HeroSkill]] = {
    "mugen": [DarkSlash(), DemonEye()],
    "kraken": [TentacleWrap(), AbyssInk()],
    "chronos": [GravityControl(), DwarfMagic()],
    "onimaru": [HellFire(), HornCharge()],
    "maria": [PuppetControl(), DollCurse()],
    "ignis": [DragonBreath(), DragonWing()],
    "gear": [SteamBarrier(), OilSpill()],
    "kurokage": [ShadowClone(), IllusionShuriken()]
}

# 스킬 클래스 매핑 (호위무사 시스템 등에서 독립 인스턴스 생성용)
HERO_SKILL_CLASSES: Dict[str, list] = {
    "mugen": [DarkSlash, DemonEye],
    "kraken": [TentacleWrap, AbyssInk],
    "chronos": [GravityControl, DwarfMagic],
    "onimaru": [HellFire, HornCharge],
    "maria": [PuppetControl, DollCurse],
    "ignis": [DragonBreath, DragonWing],
    "gear": [SteamBarrier, OilSpill],
    "kurokage": [ShadowClone, IllusionShuriken],
}


def get_hero_skills(hero_id: str) -> List[HeroSkill]:
    """영웅 ID로 스킬 목록 반환"""
    return HERO_SKILLS.get(hero_id, [])


def reset_all_skills():
    """모든 스킬 상태 리셋"""
    for skills in HERO_SKILLS.values():
        for skill in skills:
            skill.reset()


# ============================================================================
# 스킬 매니저 (게임에서 사용)
# ============================================================================
class HeroSkillManager:
    """영웅 스킬 관리 클래스"""

    # 영웅별 스킬 사용 간격 (초) - 한 스킬 사용 후 다음 스킬까지 대기 시간
    HERO_SKILL_INTERVAL = 5.0  # 5초 간격

    def __init__(self):
        self.active_skills: Dict[str, List[HeroSkill]] = {}  # hero_id -> skills
        self.game_state: Dict = {}
        self.screen_effects: List[Dict] = []
        # 영웅별 글로벌 스킬 쿨다운 (스킬 간 간격 조절)
        self.hero_global_cooldowns: Dict[str, float] = {}

    def init_hero_skills(self, hero_id: str, is_top: bool = True):
        """영웅 스킬 초기화

        Args:
            hero_id: 영웅 ID
            is_top: 상단 영웅 여부 (기본값 True)
        """
        if hero_id not in self.active_skills:
            # 새 인스턴스 생성 (상태 독립)
            skills = []
            base_skills = HERO_SKILLS.get(hero_id, [])
            for base_skill in base_skills:
                skill_class = type(base_skill)
                new_skill = skill_class()
                # 스킬 인스턴스에 직접 caster_is_top 저장 (화염지대 위치 계산용)
                new_skill.caster_is_top = is_top
                # 초기 쿨타임 부여 (3~8초) - 게임 시작 시 동시 스킬 사용 방지
                new_skill.current_cooldown = random.uniform(3.0, 8.0)
                skills.append(new_skill)
            self.active_skills[hero_id] = skills
        else:
            # 이미 존재하는 스킬들의 caster_is_top 업데이트
            for skill in self.active_skills[hero_id]:
                skill.caster_is_top = is_top

        # 영웅 위치 정보 저장
        if 'hero_positions' not in self.game_state:
            self.game_state['hero_positions'] = {}
        self.game_state['hero_positions'][hero_id] = is_top

    def reset(self):
        """전체 리셋"""
        self.active_skills = {}
        self.game_state = {
            'ball_history': [],
            # 상태 효과 (각 패들별로 추적)
            'top_paddle_stunned': False,
            'top_paddle_slowed': False,
            'top_paddle_slow_amount': 1.0,
            'top_paddle_speed_boost': 1.0,  # 속도 증가 배율 (귀신의 눈 등)
            'top_paddle_confused': False,
            'top_paddle_shrink': False,
            'top_paddle_shrink_scale': 1.0,
            'top_paddle_gravity_drift': 0,
            'bottom_paddle_stunned': False,
            'bottom_paddle_slowed': False,
            'bottom_paddle_slow_amount': 1.0,
            'bottom_paddle_speed_boost': 1.0,  # 속도 증가 배율 (귀신의 눈 등)
            'bottom_paddle_confused': False,
            'bottom_paddle_shrink': False,
            'bottom_paddle_shrink_scale': 1.0,
            'bottom_paddle_gravity_drift': 0,
            # 일반 상태
            'target_blind': False,
            'blind_intensity': 0,
            'blind_target_is_top': False,
            'target_stunned': False,
            'target_is_top': False,  # 현재 타겟이 상단 패들인지
            'target_shrink': False,
            'shrink_scale': 1.0,
            'target_slowed': False,
            'slow_amount': 1.0,
            'target_confused': False,
            'target_puppeted': False,
            'target_knockback': 0,
            'screen_shake': 0,
            'shake_duration': 0,
            'ball_on_fire': False,
            'ball_holy': False,
            'wind_force': 0,
            'barrier_active': False,
            'barrier_owner_is_top': False,
            'steam_barrier_caster_frozen': False,
            'steam_barrier_thaw_speed': 0.0,
            'has_clones': False,
            # 귀신의 눈 관련
            'demon_eye_active': False,
            'demon_eye_caster_is_top': False
        }
        self.screen_effects = []
        # 영웅별 글로벌 쿨다운 초기화
        self.hero_global_cooldowns = {}

    def reset_active_skills_for_round(self):
        """라운드 전환 시 모든 활성 스킬 강제 종료

        스킬 발동 중 라운드가 끝나면 스킬 효과와 상태를 정리합니다.
        - 촉수 휘감기 (크라켄): 둔화 효과 해제
        - 심해의 먹물 (크라켄): 혼란 효과 해제
        - 꼭두각시 조종 (연화): 패들 고정 해제
        - 인형의 저주 (연화): 조작 반전 해제
        """
        for hero_id, skills in self.active_skills.items():
            for skill in skills:
                # 활성 스킬 또는 지속 효과가 있는 스킬 모두 초기화
                # (OilSpill의 웅덩이/발사체처럼 is_active=False여도 지속되는 효과 포함)
                has_oil_effects = (hasattr(skill, 'oil_puddles') and skill.oil_puddles) or \
                                  (hasattr(skill, 'oil_projectiles') and skill.oil_projectiles)
                # 난쟁이마술: is_active=False여도 hit_target/shrink_timer가 활성화된 경우 포함
                has_dwarf_magic_effects = (hasattr(skill, 'hit_target') and skill.hit_target) or \
                                          (hasattr(skill, 'shrink_timer') and skill.shrink_timer > 0)
                # 그림자분신: is_active=False여도 분신이 남아있는 경우 포함
                has_shadow_clones = (hasattr(skill, 'clones') and skill.clones) or \
                                    (hasattr(skill, 'dying_clones') and skill.dying_clones)
                # 환영수리검: is_active=False여도 수리검이 남아있는 경우 포함
                has_shurikens = hasattr(skill, 'shurikens') and skill.shurikens
                if skill.is_active or has_oil_effects or has_dwarf_magic_effects or has_shadow_clones or has_shurikens:
                    skill.reset_for_new_round(self.game_state)

        # 추가로 game_state의 모든 효과 상태 초기화
        self.game_state['top_paddle_stunned'] = False
        self.game_state['top_paddle_slowed'] = False
        self.game_state['top_paddle_slow_amount'] = 1.0
        self.game_state['top_paddle_confused'] = False
        self.game_state['top_paddle_locked'] = False
        self.game_state['top_paddle_gravity_drift'] = 0
        self.game_state['bottom_paddle_stunned'] = False
        self.game_state['bottom_paddle_slowed'] = False
        self.game_state['bottom_paddle_slow_amount'] = 1.0
        self.game_state['bottom_paddle_confused'] = False
        self.game_state['bottom_paddle_locked'] = False
        self.game_state['bottom_paddle_gravity_drift'] = 0
        self.game_state['target_confused'] = False
        self.game_state['target_slowed'] = False
        self.game_state['slow_amount'] = 1.0
        self.game_state['target_stunned'] = False
        self.game_state['screen_shake'] = 0
        self.game_state['shake_duration'] = 0

        # 공 이펙트 초기화 (드래곤 브레스 화염, 오니마루 도깨비불, 스팀배리어 성스러운 이펙트 등)
        self.game_state['ball_on_fire'] = False
        self.game_state['ball_holy'] = False
        self.game_state['dokkaebi_ball'] = False
        self.game_state['wind_force'] = 0

        # 무겐 스킬 관련 초기화
        self.game_state['dark_slash_freeze'] = False
        self.game_state['dark_slash_active'] = False
        self.game_state['dark_slash_phase'] = 0
        self.game_state['top_paddle_speed_boost'] = 1.0
        self.game_state['bottom_paddle_speed_boost'] = 1.0
        self.game_state['demon_eye_active'] = False

        # 난쟁이마술 (키르케) 축소 효과 초기화
        self.game_state['top_paddle_shrink'] = False
        self.game_state['top_paddle_shrink_scale'] = 1.0
        self.game_state['bottom_paddle_shrink'] = False
        self.game_state['bottom_paddle_shrink_scale'] = 1.0

        # 촉수 휘감기 (크라켄) 둔화 이펙트 초기화
        self.game_state['tentacle_wrap_active'] = False
        self.game_state['tentacle_wrap_target_is_top'] = False
        self.game_state['top_paddle_tentacle_slowed'] = False
        self.game_state['bottom_paddle_tentacle_slowed'] = False

        # 쿠로카게 그림자분신 초기화
        self.game_state['has_shadow_clones'] = False

    def update(self, dt: float, top_paddle, bottom_paddle, ball):
        """스킬 업데이트"""
        # 공 히스토리 저장
        self.game_state['ball_history'].append((ball.x, ball.y))
        if len(self.game_state['ball_history']) > 60:
            self.game_state['ball_history'] = self.game_state['ball_history'][-60:]

        # 화면 흔들림 감소
        if self.game_state.get('shake_duration', 0) > 0:
            self.game_state['shake_duration'] -= dt
            if self.game_state['shake_duration'] <= 0:
                self.game_state['screen_shake'] = 0

        # 영웅별 글로벌 쿨다운 감소
        for hero_id in list(self.hero_global_cooldowns.keys()):
            if self.hero_global_cooldowns[hero_id] > 0:
                self.hero_global_cooldowns[hero_id] -= dt
                if self.hero_global_cooldowns[hero_id] < 0:
                    self.hero_global_cooldowns[hero_id] = 0

        # 각 영웅의 스킬 업데이트
        for hero_id, skills in self.active_skills.items():
            # hero_positions에서 위치 정보 가져오기
            hero_positions = self.game_state.get('hero_positions', {})
            is_top = hero_positions.get(hero_id, True)  # 기본값 True
            caster_paddle = top_paddle if is_top else bottom_paddle
            target_paddle = bottom_paddle if is_top else top_paddle

            for skill in skills:
                skill.update(dt, caster_paddle, target_paddle, ball, self.game_state)

        # 화면 효과 업데이트
        self.screen_effects = [e for e in self.screen_effects if e.get('duration', 0) > 0]
        for effect in self.screen_effects:
            effect['duration'] -= dt

    def try_use_skill(self, hero_id: str, trigger: SkillTrigger,
                     caster_paddle, target_paddle, ball) -> Optional[Dict]:
        """스킬 사용 시도"""
        skills = self.active_skills.get(hero_id, [])

        # 영웅별 글로벌 쿨다운 체크 - 쿨다운 중이면 스킬 사용 불가
        if self.hero_global_cooldowns.get(hero_id, 0) > 0:
            return None

        for skill in skills:
            if skill.trigger == trigger and skill.can_use():
                # 타겟 패들 추적
                self.game_state['target_is_top'] = target_paddle.is_top

                result = skill.use(caster_paddle, target_paddle, ball, self.game_state)
                if result:
                    # 스킬 사용 성공 시 글로벌 쿨다운 설정
                    self.hero_global_cooldowns[hero_id] = self.HERO_SKILL_INTERVAL
                    # 상태 효과를 해당 패들에 적용
                    target_prefix = 'top_paddle' if target_paddle.is_top else 'bottom_paddle'

                    if result.get('target_status'):
                        status = result['target_status']
                        if status == StatusEffect.STUN:
                            self.game_state[f'{target_prefix}_stunned'] = True
                        elif status == StatusEffect.SLOW:
                            self.game_state[f'{target_prefix}_slowed'] = True
                            self.game_state[f'{target_prefix}_slow_amount'] = result.get('slow_amount', 0.5)
                        elif status == StatusEffect.CONFUSION:
                            self.game_state[f'{target_prefix}_confused'] = True
                        elif status == StatusEffect.SHRINK:
                            self.game_state[f'{target_prefix}_shrink'] = True
                            self.game_state[f'{target_prefix}_shrink_scale'] = result.get('shrink_amount', 0.5)
                        elif status == StatusEffect.BLIND:
                            self.game_state['blind_target_is_top'] = target_paddle.is_top

                    # 화면 효과 추가
                    if 'screen_effect' in result:
                        self.screen_effects.append({
                            'type': result['screen_effect'],
                            'duration': result.get('flash_duration', 0.3),
                            'color': result.get('flash_color', (255, 255, 255)),
                            'intensity': result.get('shake_intensity', 0)
                        })

                    # 스킬 이름 정보 추가 (말풍선용)
                    result['skill_korean_name'] = skill.korean_name
                    result['caster_is_top'] = caster_paddle.is_top

                    return result
        return None

    def draw_skills(self, screen: pygame.Surface, top_paddle, bottom_paddle, ball):
        """모든 활성 스킬 이펙트 그리기"""
        for hero_id, skills in self.active_skills.items():
            # hero_positions에서 실제 위치 확인 (init_hero_skills에서 설정됨)
            is_top = self.game_state.get('hero_positions', {}).get(hero_id, True)
            caster_paddle = top_paddle if is_top else bottom_paddle
            target_paddle = bottom_paddle if is_top else top_paddle

            for skill in skills:
                skill.draw(screen, caster_paddle, target_paddle, ball, self.game_state)

    def draw_screen_effects(self, screen: pygame.Surface):
        """화면 효과 그리기"""
        for effect in self.screen_effects:
            if effect['type'] == ScreenEffect.FLASH:
                alpha = int(150 * (effect['duration'] / 0.3))
                alpha = max(0, min(255, alpha))  # 유효 범위로 제한
                if alpha <= 0:
                    continue
                flash_surf = pygame.Surface((760, 750), pygame.SRCALPHA)
                color = effect.get('color', (255, 255, 255))
                flash_surf.fill((*color, alpha))
                screen.blit(flash_surf, (0, 0))

    def get_screen_shake(self) -> Tuple[int, int]:
        """화면 흔들림 오프셋 반환"""
        shake = self.game_state.get('screen_shake', 0)
        if shake > 0:
            return (random.randint(-int(shake), int(shake)),
                   random.randint(-int(shake), int(shake)))
        return (0, 0)

    def is_target_stunned(self, is_top: bool) -> bool:
        """대상 스턴 여부"""
        return self.game_state.get('target_stunned', False)

    def get_target_slow(self) -> float:
        """둔화 배율 (1.0 = 정상)"""
        if self.game_state.get('target_slowed', False):
            return self.game_state.get('slow_amount', 1.0)
        return 1.0

    def is_target_confused(self) -> bool:
        """혼란 여부 (조작 반전)"""
        return self.game_state.get('target_confused', False)

    def get_paddle_scale(self, is_target: bool) -> float:
        """패들 크기 배율"""
        if is_target and self.game_state.get('target_shrink', False):
            return self.game_state.get('shrink_scale', 1.0)
        return 1.0


# 전역 스킬 매니저 인스턴스
_skill_manager: Optional[HeroSkillManager] = None

def get_skill_manager() -> HeroSkillManager:
    """스킬 매니저 싱글톤 반환"""
    global _skill_manager
    if _skill_manager is None:
        _skill_manager = HeroSkillManager()
    return _skill_manager


# TOP_HEROES 임포트 (순환 참조 방지)
try:
    from downtown.colosseum_arena import TOP_HEROES, BOTTOM_HEROES
except ImportError:
    TOP_HEROES = [{"id": "mugen"}, {"id": "kraken"}, {"id": "chronos"}, {"id": "onimaru"}]
    BOTTOM_HEROES = [{"id": "maria"}, {"id": "ignis"}, {"id": "gear"}, {"id": "kurokage"}]
