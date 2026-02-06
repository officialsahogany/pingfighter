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
    """암흑 베기 - 공을 사선으로 베어버리는 이펙트 + 1초 화면 정지 후 공 4배 가속"""

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
            korean_name="암흑 베기",
            description="공을 사선으로 베어 시간이 멈추고, 해제되는 순간 공이 4배 빨라진다",
            trigger=SkillTrigger.ON_BALL_HIT,
            cooldown=8.0,
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
        print(f"[DarkSlash] 스킬 발동! freeze=True, phase=SLASH, ball=({ball.x:.0f},{ball.y:.0f})")

        return {
            'screen_effect': ScreenEffect.FLASH,
            'flash_color': (200, 100, 255),
            'flash_duration': 0.08,
            'sound': 'slash'
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
                print(f"[DarkSlash] SLASH → FREEZE 전환 (1초 정지 시작)")

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
                print(f"[DarkSlash] FREEZE → RELEASE 전환 (1초 정지 종료, freeze=False)")

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

            print(f"[DarkSlash] Y축 돌진 + 커브! vx={ball.vx:.1f}, vy={ball.vy:.1f}, spin={spin_direction}, caster_is_top={self.caster_is_top}")

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
        """라운드 전환 시 암흑 베기 이펙트 초기화"""
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
        print("[DarkSlash] 라운드 전환 - 암흑 베기 초기화")

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
    """귀신발걸음 - 7초간 이동속도 200% 증가 (3배) + 패들 사이즈 20% 증가 + 오오라 이펙트"""
    def __init__(self):
        super().__init__(
            skill_id="demon_step",
            name="Ghost Step",
            korean_name="귀신발걸음",
            description="어둠의 기운을 두르고 이동속도가 3배, 패들 사이즈가 20% 증가한다",
            trigger=SkillTrigger.ON_COOLDOWN,
            cooldown=25.0,
            duration=7.0,  # 7초 지속
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
        print(f"[GhostStep ACTIVATE] is_top={caster_paddle.is_top}, paddle.x={_paddle_x}, paddle.centerx={_paddle_centerx}")

        # 이동속도 200% 증가 (3배)
        speed_key = 'top_paddle_speed_boost' if caster_paddle.is_top else 'bottom_paddle_speed_boost'
        game_state[speed_key] = 3.0  # 200% 증가 = 3배
        game_state['demon_eye_active'] = True
        game_state['demon_eye_caster_is_top'] = caster_paddle.is_top

        # 패들 사이즈 20% 증가
        size_key = 'top_paddle_size_boost' if caster_paddle.is_top else 'bottom_paddle_size_boost'
        game_state[size_key] = 1.2  # 20% 증가

        # 🔥 귀신발걸음 y축 이동 트리거 (game_state 플래그로 전달)
        # AIPaddleController는 직접 호출, PaddleWrapper는 플래그로 전달
        if hasattr(caster_paddle, 'start_ghost_step'):
            caster_paddle.start_ghost_step()
            print(f"[GhostStep] 귀신발걸음 y축 이동 직접 호출 성공!")
        else:
            # PaddleWrapper인 경우 game_state 플래그로 전달
            if caster_paddle.is_top:
                game_state['ghost_step_start_top'] = True
                print(f"[GhostStep] 상단 귀신발걸음 플래그 설정!")
            else:
                game_state['ghost_step_start_bottom'] = True
                print(f"[GhostStep] 하단 귀신발걸음 플래그 설정!")

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

        print(f"[GhostStep] 귀신발걸음 발동! 이동속도 3배 + 패들 20% 확대, 지속시간 7초")

        return {
            'screen_effect': ScreenEffect.FLASH,
            'flash_color': (150, 50, 200),
            'flash_duration': 0.15,
            'sound': 'dark_magic'
        }

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
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
        print(f"[GhostStep] 귀신발걸음 종료")

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
        print("[GhostStep] 라운드 전환 - 귀신발걸음 초기화")

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
        self.slow_amount = 0.6  # 40% 감소 = 60%만 유지
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
        # 촉수 휘감기로 인한 둔화만 해제 (다른 스킬의 둔화 효과는 유지)
        if game_state.get(f'{target_prefix}_tentacle_slowed', False):
            game_state[f'{target_prefix}_slowed'] = False
            game_state[f'{target_prefix}_slow_amount'] = 1.0
            game_state[f'{target_prefix}_tentacle_slowed'] = False
        game_state['tentacle_wrap_active'] = False
        self.tentacles = []
        self.phase = 'travel'
        self.slow_applied = False

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
    """심해의 먹물 - 크라켄이 먹물을 발사하여 상대방에게 혼란을 준다"""
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

        # 3단계 애니메이션 변수
        self.phase = 'travel'  # 'travel' -> 'splash' -> 'active'
        self.projectile_x = 0
        self.projectile_y = 0
        self.projectile_target_x = 0
        self.projectile_target_y = 0
        self.projectile_progress = 0.0
        self.projectile_speed = 1.5  # 이동 속도 (기존 3.0에서 50% 감소)

        # 스플래시 관련
        self.splash_center_x = 0
        self.splash_center_y = 0
        self.splash_radius = 0
        self.splash_max_radius = 150  # 최대 스플래시 반경 (세로)
        self.splash_width_scale = 1.5  # 가로 범위 스케일 (50% 증가)
        self.splash_expand_speed = 400  # 확장 속도
        self.splash_timer = 0
        self.splash_duration = 0.4  # 스플래시 확장 시간
        self.active_duration = 3.0  # 먹물 유지 시간 (active 단계)
        self.active_timer = 0

        # 혼란 적용 여부
        self.confusion_applied = False
        self.confusion_timer = 0
        self.confusion_duration = 3.0  # 혼란 지속 시간 (3초)

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        self.target_is_top = target_paddle.is_top
        self.caster_is_top = caster_paddle.is_top

        # 초기화: 발사 단계
        self.phase = 'travel'
        self.projectile_progress = 0.0
        self.confusion_applied = False
        self.confusion_timer = 0
        self.ink_blobs = []
        self.splash_radius = 0
        self.splash_timer = 0
        # active_timer는 HeroSkill.use()에서 duration으로 설정되므로 여기서 건드리지 않음

        # 발사 시작점: 크라켄 입 위치
        self.projectile_x = caster_paddle.x + 40
        self.projectile_y = caster_paddle.y + (30 if caster_paddle.is_top else -30)

        # 목표 지점: 타겟 진영 중앙
        self.projectile_target_x = target_paddle.x + 40
        self.projectile_target_y = 600 if caster_paddle.is_top else 150  # 하단 또는 상단 진영


        # caster의 혼란 상태는 명시적으로 False 유지
        caster_prefix = 'top_paddle' if caster_paddle.is_top else 'bottom_paddle'
        game_state[f'{caster_prefix}_confused'] = False

        return {
            'screen_effect': ScreenEffect.INK,
            'sound': 'splash'
        }

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        if self.phase == 'travel':
            # 1단계: 먹물 발사체 이동
            self.projectile_progress += dt * self.projectile_speed

            if self.projectile_progress >= 1.0:
                # 목표 지점 도달 - 스플래시 단계로 전환
                self.phase = 'splash'
                self.splash_center_x = self.projectile_target_x
                self.splash_center_y = self.projectile_target_y
                self.splash_radius = 20
                self.splash_timer = 0

        elif self.phase == 'splash':
            # 2단계: 먹물 확산
            self.splash_timer += dt
            self.splash_radius = min(self.splash_max_radius,
                                     20 + self.splash_expand_speed * self.splash_timer)

            # 먹물 방울 생성 (확산 중에 생성) - 타원형 분포
            if len(self.ink_blobs) < 15 and random.random() < 0.3:
                angle = random.uniform(0, math.pi * 2)
                dist = random.uniform(0, 0.8)
                self.ink_blobs.append({
                    'x': self.splash_center_x + math.cos(angle) * self.splash_radius * self.splash_width_scale * dist,
                    'y': self.splash_center_y + math.sin(angle) * self.splash_radius * dist,
                    'size': random.uniform(30, 80),
                    'alpha': 220,
                    'wobble': random.uniform(0, math.pi * 2)
                })

            if self.splash_timer >= self.splash_duration:
                # 스플래시 완료 - active 단계로 전환
                self.phase = 'active'
                # active_timer는 건드리지 않음 (HeroSkill.use()에서 설정한 duration 사용)

        elif self.phase == 'active':
            # 3단계: 먹물 유지 - 범위 내 영웅에게 혼란 적용

            # 먹물 방울 애니메이션
            for blob in self.ink_blobs:
                blob['wobble'] += dt * 2
                blob['alpha'] = max(0, blob['alpha'] - dt * 30)
                blob['size'] += dt * 2

            # 타겟이 스플래시 범위 내에 있는지 지속적으로 체크 (타원형)
            target_center_x = target_paddle.x + 40
            target_center_y = target_paddle.y

            # 타원 내부 판정: (dx/a)^2 + (dy/b)^2 <= 1
            dx = target_center_x - self.splash_center_x
            dy = target_center_y - self.splash_center_y
            width_radius = self.splash_max_radius * self.splash_width_scale + 40  # 패들 크기 고려
            height_radius = self.splash_max_radius + 40

            target_prefix = 'top_paddle' if target_paddle.is_top else 'bottom_paddle'

            # 타원 내부 판정
            ellipse_dist = (dx / width_radius) ** 2 + (dy / height_radius) ** 2
            if ellipse_dist <= 1:
                if not self.confusion_applied:
                    # 범위 내 진입 - 혼란 시작 (3초)
                    self.confusion_applied = True
                    self.confusion_timer = 0
                    game_state[f'{target_prefix}_confused'] = True
                    game_state['target_confused'] = True
                    game_state['confusion_type'] = 'random'

            # 혼란 타이머 관리 (3초 후 해제)
            if self.confusion_applied:
                self.confusion_timer += dt
                if self.confusion_timer >= self.confusion_duration:
                    # 3초 경과 - 혼란 해제
                    game_state[f'{target_prefix}_confused'] = False
                    game_state['target_confused'] = False

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        # 혼란 상태 클리어 (아직 3초가 안 지났으면 해제)
        if self.confusion_applied and self.confusion_timer < self.confusion_duration:
            game_state['target_confused'] = False
            target_prefix = 'top_paddle' if self.target_is_top else 'bottom_paddle'
            game_state[f'{target_prefix}_confused'] = False

        # 상태 초기화
        self.ink_blobs = []
        self.phase = 'travel'
        self.projectile_progress = 0.0
        self.confusion_applied = False
        self.confusion_timer = 0
        self.splash_radius = 0
        self.active_timer = 0

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        # 스킬이 활성화되지 않았으면 그리지 않음
        if not self.is_active:
            return

        if self.phase == 'travel':
            # 1단계: 발사체 그리기
            # 현재 위치 계산
            current_x = self.projectile_x + (self.projectile_target_x - self.projectile_x) * self.projectile_progress
            current_y = self.projectile_y + (self.projectile_target_y - self.projectile_y) * self.projectile_progress

            # 먹물 발사체 (여러 방울이 뭉쳐서 날아감) - 더 눈에 띄는 보라색 계열
            ink_surf = pygame.Surface((80, 80), pygame.SRCALPHA)

            # 외곽 글로우 (보라색 후광)
            pygame.draw.circle(ink_surf, (80, 40, 120, 120), (40, 40), 35)
            pygame.draw.circle(ink_surf, (100, 50, 150, 100), (40, 40), 30)

            # 메인 먹물 덩어리 (진한 보라/남색)
            for i in range(7):
                offset_x = random.uniform(-10, 10)
                offset_y = random.uniform(-10, 10)
                size = random.randint(10, 18)
                pygame.draw.circle(ink_surf, (40, 20, 80, 230),
                                  (40 + int(offset_x), 40 + int(offset_y)), size)

            # 코어 (밝은 중심)
            pygame.draw.circle(ink_surf, (60, 30, 100, 255), (40, 40), 12)

            screen.blit(ink_surf, (int(current_x) - 40, int(current_y) - 40))

            # 꼬리 효과 (이전 위치들) - 보라색 계열
            for i in range(5):
                tail_progress = max(0, self.projectile_progress - i * 0.08)
                if tail_progress > 0:
                    tail_x = self.projectile_x + (self.projectile_target_x - self.projectile_x) * tail_progress
                    tail_y = self.projectile_y + (self.projectile_target_y - self.projectile_y) * tail_progress
                    alpha = int(180 - i * 35)
                    size = int(18 - i * 3)
                    if size > 0 and alpha > 0:
                        tail_surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                        pygame.draw.circle(tail_surf, (60, 30, 100, alpha), (size, size), size)
                        screen.blit(tail_surf, (int(tail_x) - size, int(tail_y) - size))

        elif self.phase == 'splash':
            # 2단계: 스플래시 효과 (타원형 - 가로가 더 넓음)
            width_radius = int(self.splash_radius * self.splash_width_scale)
            height_radius = int(self.splash_radius)
            splash_surf = pygame.Surface((width_radius * 2 + 40, height_radius * 2 + 40), pygame.SRCALPHA)
            center_x = width_radius + 20
            center_y = height_radius + 20

            # 불규칙한 스플래시 형태 - 보라색 계열 (타원형)
            points = []
            for angle in range(0, 360, 15):
                rad = math.radians(angle)
                wobble = 0.85 + 0.15 * math.sin(rad * 5 + self.splash_timer * 10)
                px = center_x + int(math.cos(rad) * width_radius * wobble)
                py = center_y + int(math.sin(rad) * height_radius * wobble)
                points.append((px, py))

            if len(points) >= 3:
                # 외곽 글로우
                pygame.draw.polygon(splash_surf, (80, 40, 120, 100), points)
                # 메인 색상
                inner_points = [(center_x + int((p[0] - center_x) * 0.85), center_y + int((p[1] - center_y) * 0.85)) for p in points]
                pygame.draw.polygon(splash_surf, (50, 25, 90, 200), inner_points)
                # 테두리
                pygame.draw.polygon(splash_surf, (100, 50, 150, 220), points, 4)

            screen.blit(splash_surf, (int(self.splash_center_x - center_x), int(self.splash_center_y - center_y)))

            # 튀는 먹물 입자 - 보라색 계열 (타원형 분포)
            for i in range(10):
                angle = random.uniform(0, math.pi * 2)
                dist = random.uniform(0.5, 1.2)
                px = self.splash_center_x + math.cos(angle) * width_radius * dist
                py = self.splash_center_y + math.sin(angle) * height_radius * dist
                particle_size = random.randint(4, 10)
                pygame.draw.circle(screen, (70, 35, 110), (int(px), int(py)), particle_size)
                pygame.draw.circle(screen, (100, 50, 150), (int(px), int(py)), particle_size - 2)

        elif self.phase == 'active':
            # 3단계: 먹물 방울 유지 - 보라색 계열
            for blob in self.ink_blobs:
                if blob['alpha'] > 10:
                    size = int(blob['size'] + math.sin(blob['wobble']) * 10)
                    surf = pygame.Surface((size * 2 + 10, size * 2 + 10), pygame.SRCALPHA)
                    center = size + 5

                    # 불규칙한 먹물 형태
                    points = []
                    for angle in range(0, 360, 30):
                        rad = math.radians(angle)
                        r = size * (0.8 + 0.3 * math.sin(rad * 3 + blob['wobble']))
                        px = center + int(math.cos(rad) * r)
                        py = center + int(math.sin(rad) * r)
                        points.append((px, py))

                    # 외곽 글로우
                    if len(points) >= 3:
                        pygame.draw.polygon(surf, (80, 40, 120, int(blob['alpha'] * 0.4)), points)
                        # 메인 색상
                        pygame.draw.polygon(surf, (50, 25, 90, int(blob['alpha'])), points)
                    screen.blit(surf, (int(blob['x'] - center), int(blob['y'] - center)))

            # 혼란 적용 시 시각적 표시 - 보라색 계열 (타원형)
            if self.confusion_applied:
                # 스플래시 영역 잔여 표시 (타원형)
                width_radius = int(self.splash_max_radius * self.splash_width_scale)
                height_radius = int(self.splash_max_radius)
                remain_surf = pygame.Surface((width_radius * 2 + 20, height_radius * 2 + 20), pygame.SRCALPHA)
                center_x = width_radius + 10
                center_y = height_radius + 10
                # 외곽 글로우 (타원)
                pygame.draw.ellipse(remain_surf, (80, 40, 120, 40),
                                   (10, 10, width_radius * 2, height_radius * 2))
                # 내부 (타원)
                inner_w = int(width_radius * 0.8)
                inner_h = int(height_radius * 0.8)
                pygame.draw.ellipse(remain_surf, (50, 25, 90, 70),
                                   (center_x - inner_w, center_y - inner_h, inner_w * 2, inner_h * 2))
                screen.blit(remain_surf, (int(self.splash_center_x - center_x),
                                         int(self.splash_center_y - center_y)))

    def reset_for_new_round(self, game_state: dict):
        """라운드 전환 시 심해의 먹물 스킬 강제 종료"""
        super().reset_for_new_round(game_state)
        # 먹물 제거
        self.ink_blobs = []
        self.phase = 'travel'
        self.projectile_progress = 0.0
        self.splash_timer = 0
        self.active_timer = 0
        # 혼란 효과 해제
        if self.confusion_applied:
            target_prefix = 'top_paddle' if self.target_is_top else 'bottom_paddle'
            game_state[f'{target_prefix}_confused'] = False
            game_state['target_confused'] = False
            self.confusion_applied = False


# ============================================================================
# 크로노스 스킬 - 시간술사 (수비적)
# ============================================================================
class GravityControl(HeroSkill):
    """중력조절 - 공을 무겁게 만들어 계속 아래로 끌어당김"""
    def __init__(self):
        super().__init__(
            skill_id="gravity_control",
            name="Gravity Control",
            korean_name="중력조절",
            description="중력을 조작하여 공이 계속 아래로 끌려가게 만든다",
            trigger=SkillTrigger.ON_COOLDOWN,
            cooldown=25.0,
            duration=1.5,  # 1.5초 지속
            hero_id="chronos"
        )
        self.gravity_particles = []  # 중력 이펙트 파티클
        self.distortion_lines = []  # 왜곡선
        self.pulse_timer = 0

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
            'sound': 'gravity_shift'
        }

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        self.pulse_timer += dt

        # 중력 방향 (1=아래, -1=위)
        gravity_dir = getattr(self, 'gravity_direction', 1)

        # 🌍 핵심: 공에 중력 적용 (방향에 따라 위 또는 아래로)
        if hasattr(ball, 'vy'):
            gravity_force = 60 * dt * gravity_dir  # 중력 방향 적용
            # 중력 방향으로 가는 중이면 70%, 반대면 100% 적용
            if (ball.vy > 0 and gravity_dir > 0) or (ball.vy < 0 and gravity_dir < 0):
                ball.vy += gravity_force * 0.7  # 70% 적용 (너무 빠르게 가속 방지)
            else:  # 반대 방향 - 강한 중력으로 속도 감속
                ball.vy += gravity_force  # 100% 적용 → 공이 점점 느려지다가 방향 전환

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
    """도깨비불 - 공이 도깨비불처럼 변하며 자유자재로 움직임"""
    def __init__(self):
        super().__init__(
            skill_id="hell_fire",
            name="Dokkaebi Fire",
            korean_name="도깨비불",
            description="공이 도깨비불로 변해 예측 불가능하게 움직인다",
            trigger=SkillTrigger.ON_BALL_HIT,
            cooldown=10.0,
            duration=3.0,
            hero_id="onimaru"
        )
        self.fire_particles = []
        self.flame_intensity = 0

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        # 공 가속 및 도깨비불 상태
        ball.vx *= 1.3
        ball.vy *= 1.3
        game_state['ball_on_fire'] = True
        game_state['dokkaebi_ball'] = True  # 도깨비불 이미지 활성화
        self.flame_intensity = 1.0

        # 불꽃 파티클
        self.fire_particles = []

        return {
            'screen_effect': ScreenEffect.FIRE,
            'screen_tint': (100, 200, 255),  # 도깨비불은 푸른빛
            'sound': 'fire_burst'
        }

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        self.flame_intensity = max(0, self.flame_intensity - dt * 0.3)

        # 🔥 도깨비불 효과: 공이 자유자재로 움직임 (불규칙한 곡선 경로)
        # 시간 기반 사인파 + 랜덤 변동으로 예측 불가능한 움직임 생성
        self.dokkaebi_time = getattr(self, 'dokkaebi_time', 0) + dt

        # 사인파 기반 곡선 움직임 (좌우로 흔들림)
        wave_intensity = 150  # 흔들림 강도
        wave_speed = 8  # 흔들림 속도
        curve_force = math.sin(self.dokkaebi_time * wave_speed) * wave_intensity * dt

        # 공의 X 속도에 곡선 힘 적용
        ball.vx += curve_force

        # 간헐적으로 급격한 방향 전환 (10% 확률)
        if random.random() < 0.10:
            # 속도 벡터를 약간 회전
            angle_change = random.uniform(-0.3, 0.3)  # 라디안
            cos_a = math.cos(angle_change)
            sin_a = math.sin(angle_change)
            new_vx = ball.vx * cos_a - ball.vy * sin_a
            new_vy = ball.vx * sin_a + ball.vy * cos_a
            ball.vx = new_vx
            ball.vy = new_vy

        # 공 주변 불꽃 파티클 추가
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
        game_state['dokkaebi_ball'] = False  # 도깨비불 이미지 비활성화
        self.fire_particles = []
        self.dokkaebi_time = 0  # 타이머 리셋

    def reset_for_new_round(self, game_state: dict):
        """라운드 전환 시 지옥불 스킬 강제 종료"""
        super().reset_for_new_round(game_state)
        game_state['ball_on_fire'] = False
        game_state['dokkaebi_ball'] = False
        self.fire_particles = []
        self.flame_intensity = 0
        self.dokkaebi_time = 0

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        if self.is_active:
            # 화면 푸른 틴트 (도깨비불)
            if self.flame_intensity > 0:
                overlay = pygame.Surface((760, 750), pygame.SRCALPHA)
                overlay.fill((50, 150, 255, int(30 * self.flame_intensity)))  # 푸른색
                screen.blit(overlay, (0, 0))

            # 도깨비불 파티클 (푸른색/청록색)
            for p in self.fire_particles:
                if p['size'] > 1:
                    # 도깨비불 색상 (하늘색 -> 청록색 -> 연두색)
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
            duration=3.0,  # 돌진 0.3초 + 충돌 0.2초 + 복귀 0.5초 + 스턴 2초
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

        # 돌진 잔상 효과
        self.afterimages = []

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        self.shockwave_radius = 0
        self.knockback_applied = False
        self.stun_applied = False
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

        # 게임 영역 경계 제한 (80 ~ 680)
        GAME_LEFT = 80
        GAME_RIGHT = 680
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
            'sound': 'charge'
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

                # 스턴 적용
                if not self.stun_applied:
                    target_prefix = 'top_paddle' if self.target_is_top else 'bottom_paddle'
                    game_state[f'{target_prefix}_stunned'] = True
                    self.stun_applied = True

        elif self.phase == self.PHASE_STUN:
            # 스턴 지속 (1.5초)
            game_state['horn_charge_y_offset'] = 0  # 원위치
            if self.phase_timer >= 1.5:
                # 스턴 해제
                target_prefix = 'top_paddle' if self.target_is_top else 'bottom_paddle'
                game_state[f'{target_prefix}_stunned'] = False

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        game_state['screen_shake'] = 0
        game_state['target_knockback'] = 0
        # 돌진 오프셋 초기화
        game_state['horn_charge_active'] = False
        game_state['horn_charge_y_offset'] = 0
        game_state['horn_charge_x_offset'] = 0
        game_state['horn_charge_apply_knockback'] = False
        # 스턴 해제
        target_prefix = 'top_paddle' if self.target_is_top else 'bottom_paddle'
        game_state[f'{target_prefix}_stunned'] = False
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
            'sound': 'strings'
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
            'sound': 'curse'
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
            for guardian in self.guardian_dolls:
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
                shadow_w, shadow_h = int(40 * s), int(12 * s)
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

                # === 다리 (인형 몸통 아래) ===
                leg_color = (90, 60, 70) if flash <= 0 else (140, 100, 120)
                leg_outline = (60, 40, 50)
                # 왼쪽 다리
                leg_lx = gx - int(8 * s)
                leg_ly = gy + int(15 * s)
                pygame.draw.ellipse(screen, leg_color, (leg_lx - int(6*s), leg_ly, int(12*s), int(25*s)))
                pygame.draw.ellipse(screen, leg_outline, (leg_lx - int(6*s), leg_ly, int(12*s), int(25*s)), 1)
                # 오른쪽 다리
                leg_rx = gx + int(8 * s)
                pygame.draw.ellipse(screen, leg_color, (leg_rx - int(6*s), leg_ly, int(12*s), int(25*s)))
                pygame.draw.ellipse(screen, leg_outline, (leg_rx - int(6*s), leg_ly, int(12*s), int(25*s)), 1)
                # 다리 스티치
                for ly in range(int(leg_ly + 5*s), int(leg_ly + 20*s), max(1, int(6*s))):
                    pygame.draw.line(screen, (120, 80, 100), (leg_lx - int(4*s), ly), (leg_lx + int(4*s), ly), 1)
                    pygame.draw.line(screen, (120, 80, 100), (leg_rx - int(4*s), ly), (leg_rx + int(4*s), ly), 1)

                # === 팔 (인형 몸통 옆) ===
                arm_color = (100, 70, 80) if flash <= 0 else (150, 110, 130)
                # 왼쪽 팔 (약간 위로 들린 자세)
                arm_lx = gx - int(22 * s)
                arm_ly = gy - int(5 * s)
                pygame.draw.ellipse(screen, arm_color, (arm_lx, arm_ly, int(14*s), int(22*s)))
                pygame.draw.ellipse(screen, leg_outline, (arm_lx, arm_ly, int(14*s), int(22*s)), 1)
                # 오른쪽 팔
                arm_rx = gx + int(8 * s)
                pygame.draw.ellipse(screen, arm_color, (arm_rx, arm_ly, int(14*s), int(22*s)))
                pygame.draw.ellipse(screen, leg_outline, (arm_rx, arm_ly, int(14*s), int(22*s)), 1)

                # === 몸통 (메인 바디) ===
                body_color = (120, 85, 100) if flash <= 0 else (180, 140, 160)
                body_highlight = (150, 110, 130) if flash <= 0 else (220, 180, 200)
                body_w, body_h = int(32 * s), int(38 * s)
                body_rect = (gx - body_w // 2, gy - int(12 * s), body_w, body_h)
                # 몸통 베이스
                pygame.draw.ellipse(screen, body_color, body_rect)
                # 몸통 하이라이트 (입체감)
                highlight_rect = (gx - body_w // 2 + int(4*s), gy - int(10*s), int(12*s), int(18*s))
                pygame.draw.ellipse(screen, body_highlight, highlight_rect)
                # 몸통 외곽선
                pygame.draw.ellipse(screen, leg_outline, body_rect, 2)

                # === 몸통 스티치 (봉제선) ===
                stitch_color = (80, 50, 60)
                # 중앙 세로 스티치
                for sy in range(int(gy - 8*s), int(gy + 20*s), max(1, int(5*s))):
                    pygame.draw.line(screen, stitch_color, (gx - int(2*s), sy), (gx + int(2*s), sy + int(3*s)), 1)
                # 가로 스티치 (패치 느낌)
                pygame.draw.line(screen, stitch_color, (gx - int(10*s), gy + int(5*s)), (gx + int(10*s), gy + int(5*s)), 1)
                for sx in range(int(gx - 8*s), int(gx + 10*s), max(1, int(4*s))):
                    pygame.draw.line(screen, stitch_color, (sx, gy + int(3*s)), (sx, gy + int(7*s)), 1)

                # === 하트 핀 (가슴에 박힌 핀) ===
                heart_x, heart_y = gx + int(5*s), gy
                heart_size = int(6 * s)
                # 핀 머리 (하트 모양)
                heart_color = (220, 50, 80) if flash <= 0 else (255, 100, 130)
                # 하트 그리기 (두 원 + 삼각형)
                pygame.draw.circle(screen, heart_color, (heart_x - int(2*s), heart_y - int(2*s)), int(4*s))
                pygame.draw.circle(screen, heart_color, (heart_x + int(2*s), heart_y - int(2*s)), int(4*s))
                pygame.draw.polygon(screen, heart_color, [
                    (heart_x - int(5*s), heart_y - int(1*s)),
                    (heart_x + int(5*s), heart_y - int(1*s)),
                    (heart_x, heart_y + int(6*s))
                ])
                # 핀 광택
                pygame.draw.circle(screen, (255, 200, 210), (heart_x - int(1*s), heart_y - int(3*s)), int(2*s))

                # === 머리 ===
                head_color = (130, 95, 110) if flash <= 0 else (190, 150, 170)
                head_y = gy - int(28 * s)
                head_radius = int(18 * s)
                # 머리 베이스
                pygame.draw.circle(screen, head_color, (gx, head_y), head_radius)
                # 머리 하이라이트
                pygame.draw.circle(screen, body_highlight, (gx - int(5*s), head_y - int(5*s)), int(6*s))
                # 머리 외곽선
                pygame.draw.circle(screen, leg_outline, (gx, head_y), head_radius, 2)

                # === 헝클어진 머리카락/실 ===
                hair_color = (70, 45, 55)
                hair_top = head_y - head_radius
                for hi in range(-3, 4):
                    hx = gx + int(hi * 4 * s)
                    hair_len = int((8 + abs(hi) * 2) * s)
                    sway = math.sin(time_tick * 0.005 + hi * 0.5) * 3
                    # 머리카락 곡선
                    pygame.draw.line(screen, hair_color, (hx, hair_top + int(2*s)),
                                   (hx + int(sway), hair_top - hair_len), 2)

                # === 왼쪽 눈 (버튼) ===
                left_eye_x = gx - int(7 * s)
                left_eye_y = head_y - int(2 * s)
                button_radius = int(5 * s)
                # 버튼 베이스
                button_color = (50, 30, 40)
                pygame.draw.circle(screen, button_color, (left_eye_x, left_eye_y), button_radius)
                pygame.draw.circle(screen, (80, 50, 60), (left_eye_x, left_eye_y), button_radius, 1)
                # 버튼 구멍 (4개)
                hole_color = (30, 15, 25)
                hole_r = int(1.5 * s)
                for hox, hoy in [(-2, -2), (2, -2), (-2, 2), (2, 2)]:
                    pygame.draw.circle(screen, hole_color,
                                     (left_eye_x + int(hox*s), left_eye_y + int(hoy*s)), hole_r)
                # 버튼 실 (X 모양)
                pygame.draw.line(screen, (100, 60, 80),
                               (left_eye_x - int(2*s), left_eye_y - int(2*s)),
                               (left_eye_x + int(2*s), left_eye_y + int(2*s)), 1)
                pygame.draw.line(screen, (100, 60, 80),
                               (left_eye_x - int(2*s), left_eye_y + int(2*s)),
                               (left_eye_x + int(2*s), left_eye_y - int(2*s)), 1)

                # === 오른쪽 눈 (X 스티치 - 꿰맨 눈) ===
                right_eye_x = gx + int(7 * s)
                right_eye_y = head_y - int(2 * s)
                x_size = int(5 * s)
                x_color = (200, 60, 90) if flash <= 0 else (255, 120, 150)
                pygame.draw.line(screen, x_color,
                               (right_eye_x - x_size, right_eye_y - x_size),
                               (right_eye_x + x_size, right_eye_y + x_size), 2)
                pygame.draw.line(screen, x_color,
                               (right_eye_x - x_size, right_eye_y + x_size),
                               (right_eye_x + x_size, right_eye_y - x_size), 2)

                # === 입 (꿰맨 지그재그) ===
                mouth_y = head_y + int(8 * s)
                mouth_color = (180, 70, 100)
                # 지그재그 입
                mouth_points = []
                for mi in range(-4, 5):
                    mx = gx + int(mi * 3 * s)
                    my = mouth_y + (int(2*s) if mi % 2 == 0 else int(-2*s))
                    mouth_points.append((mx, my))
                for i in range(len(mouth_points) - 1):
                    pygame.draw.line(screen, mouth_color, mouth_points[i], mouth_points[i+1], 2)
                # 입 스티치 (세로선)
                for mi in range(-3, 4):
                    mx = gx + int(mi * 3 * s)
                    pygame.draw.line(screen, (120, 60, 80), (mx, mouth_y - int(3*s)), (mx, mouth_y + int(3*s)), 1)

                # === 볼 터치 (홍조) ===
                blush_alpha = int(80 * spawn_alpha)
                blush_surf = pygame.Surface((int(12*s), int(8*s)), pygame.SRCALPHA)
                pygame.draw.ellipse(blush_surf, (200, 100, 120, blush_alpha), blush_surf.get_rect())
                screen.blit(blush_surf, (gx - int(18*s), head_y + int(2*s)))
                screen.blit(blush_surf, (gx + int(6*s), head_y + int(2*s)))

                # === 떠다니는 저주 파티클 ===
                num_particles = 5
                for pi in range(num_particles):
                    p_angle = (time_tick * 0.002 + pi * (math.pi * 2 / num_particles)) % (math.pi * 2)
                    p_dist = int(45 * s) + math.sin(time_tick * 0.005 + pi) * 8
                    px = gx + int(math.cos(p_angle) * p_dist)
                    py = gy + int(math.sin(p_angle) * p_dist * 0.6)
                    p_size = int(3 * s * (0.5 + 0.5 * math.sin(time_tick * 0.008 + pi)))
                    p_alpha = int(150 * spawn_alpha * (0.5 + 0.5 * math.sin(time_tick * 0.006 + pi)))
                    p_surf = pygame.Surface((p_size * 2, p_size * 2), pygame.SRCALPHA)
                    pygame.draw.circle(p_surf, (200, 80, 130, p_alpha), (p_size, p_size), p_size)
                    screen.blit(p_surf, (px - p_size, py - p_size))

            # 저주 인형들 (상대 영웅 주변에서 공전) - 고퀄리티 부두 인형
            time_tick = pygame.time.get_ticks()
            for doll_idx, doll in enumerate(self.curse_dolls):
                dx, dy = int(doll['x']), int(doll['y'])
                s = doll['scale']
                rot = doll['rotation']
                wobble = doll['wobble']

                # === 저주 오라 (인형 뒤) ===
                aura_pulse = 0.6 + 0.4 * math.sin(time_tick * 0.006 + doll_idx)
                aura_size = int(35 * s * aura_pulse)
                aura_surf = pygame.Surface((aura_size * 2, aura_size * 2), pygame.SRCALPHA)
                for ar in range(aura_size, 0, -4):
                    a_alpha = int(30 * (ar / aura_size) * aura_pulse)
                    pygame.draw.circle(aura_surf, (180, 60, 100, a_alpha), (aura_size, aura_size), ar)
                screen.blit(aura_surf, (dx - aura_size, dy - aura_size))

                # === 그림자 ===
                shadow_w, shadow_h = int(28 * s), int(10 * s)
                shadow_surf = pygame.Surface((shadow_w, shadow_h), pygame.SRCALPHA)
                pygame.draw.ellipse(shadow_surf, (0, 0, 0, 70), shadow_surf.get_rect())
                screen.blit(shadow_surf, (dx - shadow_w // 2, dy + int(22 * s)))

                # === 저주 실 (머리 위로 올라가는 실) ===
                thread_base_y = dy - int(28 * s)
                for ti, tx_off in enumerate([-4, 0, 4]):
                    thread_sway = math.sin(time_tick * 0.004 + ti + doll_idx) * 5
                    thread_alpha = 180 - abs(tx_off) * 20
                    t_start = (dx + int(tx_off * s), thread_base_y)
                    t_mid = (dx + int(tx_off * s * 0.5) + int(thread_sway), thread_base_y - int(20 * s))
                    t_end = (dx + int(thread_sway * 0.5), thread_base_y - int(40 * s))
                    pygame.draw.line(screen, (180, 90, 120), t_start, t_mid, 1)
                    pygame.draw.line(screen, (150, 70, 100), t_mid, t_end, 1)

                # === 다리 ===
                leg_color = (70, 45, 55)
                leg_highlight = (100, 70, 85)
                leg_y = dy + int(8 * s)
                for leg_side in [-1, 1]:
                    leg_x = dx + int(leg_side * 6 * s)
                    # 다리 베이스
                    pygame.draw.ellipse(screen, leg_color,
                                       (leg_x - int(5*s), leg_y, int(10*s), int(18*s)))
                    pygame.draw.ellipse(screen, (50, 30, 40),
                                       (leg_x - int(5*s), leg_y, int(10*s), int(18*s)), 1)
                    # 다리 스티치
                    for ly in range(int(leg_y + 4*s), int(leg_y + 15*s), max(1, int(5*s))):
                        pygame.draw.line(screen, (120, 70, 90),
                                       (leg_x - int(3*s), ly), (leg_x + int(3*s), ly), 1)

                # === 팔 ===
                arm_color = (75, 50, 60)
                arm_y = dy - int(5 * s)
                for arm_side in [-1, 1]:
                    arm_sway = math.sin(time_tick * 0.005 + arm_side + doll_idx) * 3
                    arm_x = dx + int(arm_side * 12 * s)
                    # 팔 베이스
                    pygame.draw.ellipse(screen, arm_color,
                                       (arm_x - int(4*s), arm_y + int(arm_sway), int(8*s), int(16*s)))
                    pygame.draw.ellipse(screen, (50, 30, 40),
                                       (arm_x - int(4*s), arm_y + int(arm_sway), int(8*s), int(16*s)), 1)

                # === 몸통 ===
                body_color = (85, 55, 70)
                body_light = (110, 75, 95)
                body_dark = (60, 40, 50)
                body_w, body_h = int(22 * s), int(28 * s)
                body_rect = (dx - body_w // 2, dy - int(8 * s), body_w, body_h)
                # 몸통 그림자
                pygame.draw.ellipse(screen, body_dark,
                                   (body_rect[0] + 2, body_rect[1] + 2, body_w, body_h))
                # 몸통 베이스
                pygame.draw.ellipse(screen, body_color, body_rect)
                # 몸통 하이라이트
                pygame.draw.ellipse(screen, body_light,
                                   (dx - int(6*s), dy - int(6*s), int(10*s), int(14*s)))
                # 몸통 외곽선
                pygame.draw.ellipse(screen, (50, 30, 40), body_rect, 2)

                # === 몸통 스티치 (봉제선) ===
                stitch_color = (120, 70, 90)
                # 세로 스티치
                for sy in range(int(dy - 4*s), int(dy + 14*s), max(1, int(5*s))):
                    pygame.draw.line(screen, stitch_color,
                                   (dx - int(2*s), sy), (dx + int(2*s), sy + int(2*s)), 1)
                # 가로 패치 스티치
                pygame.draw.line(screen, stitch_color,
                               (dx - int(8*s), dy + int(4*s)), (dx + int(8*s), dy + int(4*s)), 1)

                # === 하트 핀 (가슴) ===
                heart_x, heart_y = dx + int(3*s), dy - int(2*s)
                heart_s = int(4 * s)
                heart_color = (220, 50, 80)
                pygame.draw.circle(screen, heart_color, (heart_x - int(1.5*s), heart_y - int(1*s)), heart_s // 2)
                pygame.draw.circle(screen, heart_color, (heart_x + int(1.5*s), heart_y - int(1*s)), heart_s // 2)
                pygame.draw.polygon(screen, heart_color, [
                    (heart_x - int(3*s), heart_y),
                    (heart_x + int(3*s), heart_y),
                    (heart_x, heart_y + int(4*s))
                ])

                # === 머리 ===
                head_color = (90, 60, 75)
                head_light = (115, 85, 100)
                head_y = dy - int(18 * s)
                head_r = int(14 * s)
                # 머리 그림자
                pygame.draw.circle(screen, body_dark, (dx + 1, head_y + 1), head_r)
                # 머리 베이스
                pygame.draw.circle(screen, head_color, (dx, head_y), head_r)
                # 머리 하이라이트
                pygame.draw.circle(screen, head_light, (dx - int(4*s), head_y - int(4*s)), int(5*s))
                # 머리 외곽선
                pygame.draw.circle(screen, (50, 30, 40), (dx, head_y), head_r, 2)

                # === 헝클어진 머리카락 ===
                hair_color = (50, 30, 40)
                hair_top = head_y - head_r
                for hi in range(-2, 3):
                    hx = dx + int(hi * 4 * s)
                    hair_len = int((6 + abs(hi)) * s)
                    sway = math.sin(time_tick * 0.004 + hi + doll_idx) * 2
                    pygame.draw.line(screen, hair_color,
                                   (hx, hair_top + int(2*s)),
                                   (int(hx + sway), hair_top - hair_len), 2)

                # === X 눈 (빛나는 저주의 눈) ===
                eye_glow_pulse = 0.7 + 0.3 * math.sin(time_tick * 0.008 + doll_idx)
                for eye_side in [-1, 1]:
                    eye_x = dx + int(eye_side * 5 * s)
                    eye_y = head_y - int(1 * s)
                    x_size = int(4 * s)
                    # X 눈 글로우
                    glow_size = int(8 * s * eye_glow_pulse)
                    glow_surf = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
                    pygame.draw.circle(glow_surf, (255, 80, 120, int(60 * eye_glow_pulse)),
                                     (glow_size, glow_size), glow_size)
                    screen.blit(glow_surf, (eye_x - glow_size, eye_y - glow_size))
                    # X 눈 본체
                    x_color = (255, 80, 120)
                    pygame.draw.line(screen, x_color,
                                   (eye_x - x_size, eye_y - x_size),
                                   (eye_x + x_size, eye_y + x_size), 2)
                    pygame.draw.line(screen, x_color,
                                   (eye_x - x_size, eye_y + x_size),
                                   (eye_x + x_size, eye_y - x_size), 2)

                # === 입 (꿰맨 지그재그) ===
                mouth_y = head_y + int(6 * s)
                mouth_color = (200, 80, 110)
                mouth_points = []
                for mi in range(-3, 4):
                    mx = dx + int(mi * 2.5 * s)
                    my = mouth_y + (int(1.5*s) if mi % 2 == 0 else int(-1.5*s))
                    mouth_points.append((mx, my))
                for i in range(len(mouth_points) - 1):
                    pygame.draw.line(screen, mouth_color, mouth_points[i], mouth_points[i+1], 2)

                # === 볼 터치 (홍조) ===
                blush_size = int(6 * s)
                blush_surf = pygame.Surface((blush_size * 2, blush_size), pygame.SRCALPHA)
                pygame.draw.ellipse(blush_surf, (200, 100, 120, 60), blush_surf.get_rect())
                screen.blit(blush_surf, (dx - int(12*s), head_y + int(2*s)))
                screen.blit(blush_surf, (dx + int(4*s), head_y + int(2*s)))

                # === 저주 파티클 (인형 주변) ===
                for pi in range(4):
                    p_angle = (time_tick * 0.003 + pi * 1.57 + doll_idx) % (math.pi * 2)
                    p_dist = int(25 * s) + math.sin(time_tick * 0.006 + pi) * 5
                    px = dx + int(math.cos(p_angle) * p_dist)
                    py = dy + int(math.sin(p_angle) * p_dist * 0.6)
                    p_size = int(2 * s * (0.6 + 0.4 * math.sin(time_tick * 0.007 + pi)))
                    p_alpha = int(120 * (0.5 + 0.5 * math.sin(time_tick * 0.005 + pi)))
                    p_surf = pygame.Surface((p_size * 2, p_size * 2), pygame.SRCALPHA)
                    pygame.draw.circle(p_surf, (220, 100, 150, p_alpha), (p_size, p_size), p_size)
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
        self.breath_hit_ball = False
        self.fire_zone_spawned = False  # 화염 지대 생성 여부 (미사용, 호환성용)
        self.spawn_phase_ended = False  # 파티클 생성 단계 종료 여부
        self.fire_zone_timer = 0  # 화염지대 생성 타이머
        self.fire_zone_positions = []  # 생성된 화염지대 위치들

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        self.breath_particles = []
        self.breath_active = True
        self.breath_hit_ball = False
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
            'sound': 'dragon_roar'
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

            # 공과 충돌 체크 (rect 기반 - 오딘의 늪과 동일 방식)
            if not self.breath_hit_ball and p['size'] > 3:
                # 파티클 히트박스 생성
                particle_size = max(int(p['size']), 5)
                particle_rect = pygame.Rect(
                    int(p['x']) - particle_size,
                    int(p['y']) - particle_size,
                    particle_size * 2,
                    particle_size * 2
                )

                if particle_rect.colliderect(ball_rect):
                    # 공을 화염 진행 방향으로 반사 (오딘의 늪 가시와 유사)
                    is_caster_top = getattr(self, 'caster_is_top', caster_paddle.is_top)

                    # 현재 속도 계산
                    current_speed = math.hypot(ball.vx, ball.vy)
                    if current_speed < 8.0:
                        current_speed = 10.0  # 최소 속도 보장

                    # 속도 부스트 (1.3~1.5배)
                    boosted_speed = current_speed * random.uniform(1.3, 1.5)

                    # 화염 진행 방향으로 반사 (상단→아래, 하단→위)
                    # 약간의 X축 랜덤 편차 추가
                    angle_offset = random.uniform(-0.3, 0.3)  # ±17도

                    if is_caster_top:
                        # 상단에서 발사 → 공을 아래로 반사
                        ball.vy = abs(boosted_speed * math.cos(angle_offset))
                        ball.vx = boosted_speed * math.sin(angle_offset)
                    else:
                        # 하단에서 발사 → 공을 위로 반사
                        ball.vy = -abs(boosted_speed * math.cos(angle_offset))
                        ball.vx = boosted_speed * math.sin(angle_offset)

                    self.breath_hit_ball = True
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
# 기어 스킬 - 스팀펑크 메카닉 (수비적)
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
            duration=4.0,
            hero_id="gear"
        )
        self.barrier_y = 0
        self.steam_particles = []
        # 중복 충돌 방지용 쿨다운 (0.3초)
        self.hit_cooldown = 0.0
        self.hit_cooldown_max = 0.3

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        # 배리어 위치 (홀리 베리어와 동일한 높이)
        # 하단: 패들(710) + 15 = 725 (홀리베리어 위치)
        # 상단: 패들(25) + 40 = 65 (보스 히트박스 하단 근처)
        self.barrier_y = caster_paddle.y + (40 if caster_paddle.is_top else 15)
        self.hit_cooldown = 0.0  # 충돌 쿨다운 초기화
        game_state['barrier_active'] = True
        game_state['barrier_y'] = self.barrier_y
        game_state['barrier_owner_is_top'] = caster_paddle.is_top

        return {
            'sound': 'steam_release'
        }

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
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

        # 공 배리어 충돌 체크 (쿨다운 중이 아닐 때만)
        is_top = game_state.get('barrier_owner_is_top', True)
        if self.hit_cooldown <= 0:
            if is_top:
                # 상단 배리어: 공이 아래에서 위로 접근 (ball.y > barrier_y)
                if ball.vy < 0 and abs(ball.y - self.barrier_y) < 20 and ball.y > self.barrier_y:
                    ball.vy = abs(ball.vy) * 1.1
                    self.hit_cooldown = self.hit_cooldown_max  # 중복 충돌 방지
                    game_state['screen_shake'] = 10
            else:
                # 하단 배리어: 공이 위에서 아래로 접근 (ball.y < barrier_y)
                if ball.vy > 0 and abs(ball.y - self.barrier_y) < 20 and ball.y < self.barrier_y:
                    ball.vy = -abs(ball.vy) * 1.1
                    self.hit_cooldown = self.hit_cooldown_max  # 중복 충돌 방지
                    game_state['screen_shake'] = 10

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        game_state['barrier_active'] = False
        self.steam_particles = []

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


class OilSpill(HeroSkill):
    """기름 투척 - 기름 덩어리를 던져 적 진영 바닥에 웅덩이 생성"""
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
            'sound': 'splash'
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
                # 웅덩이 생성
                self.oil_puddles.append({
                    'x': proj['target_x'],
                    'y': proj['target_y'],
                    'width': random.uniform(72, 108),  # 20% 증가 (60-90 → 72-108)
                    'height': random.uniform(18, 28),
                    'wobble': random.uniform(0, math.pi * 2),
                    'life': self.puddle_duration,  # 4초
                    'max_life': self.puddle_duration,
                    'alpha': 200,
                    'splash_effect': 1.0  # 착지 스플래시 효과
                })

        for proj in projectiles_to_remove:
            self.oil_projectiles.remove(proj)

        # 웅덩이 업데이트
        puddles_to_remove = []
        for puddle in self.oil_puddles:
            puddle['wobble'] += dt * 2
            puddle['life'] -= dt

            # 스플래시 효과 감소
            if puddle['splash_effect'] > 0:
                puddle['splash_effect'] -= dt * 3

            # 마지막 1.5초 동안 페이드아웃
            if puddle['life'] < 1.5:
                puddle['alpha'] = int(200 * (puddle['life'] / 1.5))

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
            game_state[f'{target_prefix}_slow_amount'] = 0.7  # 30% 둔화 (70% 속도)
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
            size = int(proj['size'])
            surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)

            # 기름 덩어리 본체 (불규칙한 원형)
            center = size
            wobble_offset = math.sin(proj['wobble']) * 3

            # 메인 덩어리
            pygame.draw.circle(surf, (40, 35, 25, 220), (center, center), size)
            # 하이라이트
            highlight_offset = int(size * 0.3)
            pygame.draw.circle(surf, (70, 60, 45, 150),
                             (center - highlight_offset, center - highlight_offset),
                             int(size * 0.4))
            # 그림자/깊이
            pygame.draw.circle(surf, (25, 20, 15, 180),
                             (center + int(wobble_offset), center),
                             int(size * 0.7))

            screen.blit(surf, (int(proj['x'] - size), int(proj['y'] - size)))

        # 웅덩이 그리기
        for puddle in self.oil_puddles:
            w = int(puddle['width'] + math.sin(puddle['wobble']) * 5)
            h = int(puddle['height'])
            x = int(puddle['x'] - w / 2)
            y = int(puddle['y'] - h / 2)
            alpha = puddle['alpha']

            surf = pygame.Surface((w + 20, h + 20), pygame.SRCALPHA)

            # 스플래시 효과 (착지 직후)
            if puddle['splash_effect'] > 0:
                splash_size = int(w * (1 + puddle['splash_effect'] * 0.5))
                splash_alpha = int(100 * puddle['splash_effect'])
                pygame.draw.ellipse(surf, (50, 45, 35, splash_alpha),
                                  (10 - (splash_size - w) // 2, 10 - (splash_size - w) // 4,
                                   splash_size, int(h * 1.3)))

            # 기름 웅덩이 본체
            pygame.draw.ellipse(surf, (30, 25, 20, alpha), (10, 10, w, h))
            # 반사광 (기름 특유의 무지개빛)
            pygame.draw.ellipse(surf, (60, 50, 40, int(alpha * 0.5)),
                              (10 + w // 4, 10 + h // 4, w // 3, h // 3))
            # 가장자리 하이라이트
            pygame.draw.ellipse(surf, (80, 70, 50, int(alpha * 0.3)),
                              (10 + w // 6, 10 + h // 6, w // 4, h // 4))

            screen.blit(surf, (x - 10, y - 10))


# ============================================================================
# 쿠로카게 스킬 - 그림자 닌자 (공격적)
# ============================================================================
class ShadowClone(HeroSkill):
    """그림자분신 - 아카무 리고 스타일 분신 (Stage 8 방식으로 구현)"""

    # 게임 영역 경계
    GAME_LEFT = 80
    GAME_RIGHT = 680

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

        # 소멸 중인 분신 업데이트
        new_dying = []
        for dying in self.dying_clones:
            dying['death_time'] += dt
            if dying['death_time'] < self.DEATH_DURATION:
                new_dying.append(dying)
        self.dying_clones = new_dying

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        game_state['has_shadow_clones'] = False
        self.clones = []
        self.dying_clones = []

    def reset_for_new_round(self, game_state: dict):
        """라운드 전환 시 그림자분신 강제 초기화"""
        super().reset_for_new_round(game_state)
        self.clones = []
        self.dying_clones = []
        game_state['has_shadow_clones'] = False

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        renderer = get_shadow_clone_renderer() if HERO_PADDLE_RENDERER_AVAILABLE else None

        # 활성 분신 그리기
        for clone in self.clones:
            self._draw_clone(screen, clone, caster_paddle, renderer)

        # 소멸 중인 분신 그리기 (홀로그램 증발 효과)
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

    # 게임 영역 경계 (760x750 화면, 게임 플레이 영역: 80~680)
    GAME_LEFT = 80
    GAME_RIGHT = 680
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
            'active': True,
            'trail': []  # 잔상 효과
        })
        self.shurikens_spawned += 1

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        # 순차 발사 (0.2초 간격)
        if self.shurikens_spawned < self.total_shurikens:
            self.spawn_timer += dt
            if self.spawn_timer >= 0.2:
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

            # 최대 8번 튕기면 비활성화
            if shuriken['bounces'] >= 8:
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

                # 히트 이펙트 추가
                self.hit_effects.append({
                    'x': shuriken['x'],
                    'y': shuriken['y'],
                    'timer': 0.3,
                    'particles': [
                        {
                            'x': shuriken['x'],
                            'y': shuriken['y'],
                            'vx': random.uniform(-200, 200),
                            'vy': random.uniform(-200, 200),
                            'life': 0.4
                        }
                        for _ in range(8)
                    ]
                })

        # 잔상 알파값 감소
        for shuriken in self.shurikens:
            for trail in shuriken['trail']:
                trail['alpha'] = max(0, trail['alpha'] - dt * 400)

        # 히트 이펙트 업데이트
        for effect in self.hit_effects:
            effect['timer'] -= dt
            for p in effect['particles']:
                p['x'] += p['vx'] * dt
                p['y'] += p['vy'] * dt
                p['life'] -= dt

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

        # 히트 이펙트 그리기
        for effect in self.hit_effects:
            # 임팩트 플래시
            flash_alpha = int(200 * (effect['timer'] / 0.3))
            pygame.draw.circle(screen, (180, 150, 255),
                             (int(effect['x']), int(effect['y'])),
                             int(30 * (1 - effect['timer'] / 0.3)), 2)

            # 파티클
            for p in effect['particles']:
                if p['life'] > 0:
                    alpha = int(255 * (p['life'] / 0.4))
                    size = int(4 * (p['life'] / 0.4))
                    if size > 0:
                        surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                        pygame.draw.circle(surf, (150, 130, 200, alpha), (size, size), size)
                        screen.blit(surf, (int(p['x'] - size), int(p['y'] - size)))

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
            'bottom_paddle_stunned': False,
            'bottom_paddle_slowed': False,
            'bottom_paddle_slow_amount': 1.0,
            'bottom_paddle_speed_boost': 1.0,  # 속도 증가 배율 (귀신의 눈 등)
            'bottom_paddle_confused': False,
            'bottom_paddle_shrink': False,
            'bottom_paddle_shrink_scale': 1.0,
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
            'wind_force': 0,
            'barrier_active': False,
            'barrier_owner_is_top': False,
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
        self.game_state['bottom_paddle_stunned'] = False
        self.game_state['bottom_paddle_slowed'] = False
        self.game_state['bottom_paddle_slow_amount'] = 1.0
        self.game_state['bottom_paddle_confused'] = False
        self.game_state['bottom_paddle_locked'] = False
        self.game_state['target_confused'] = False
        self.game_state['target_slowed'] = False
        self.game_state['slow_amount'] = 1.0
        self.game_state['target_stunned'] = False
        self.game_state['screen_shake'] = 0
        self.game_state['shake_duration'] = 0

        # 공 이펙트 초기화 (드래곤 브레스 화염, 오니마루 도깨비불 등)
        self.game_state['ball_on_fire'] = False
        self.game_state['dokkaebi_ball'] = False
        self.game_state['wind_force'] = 0

        # 무겐 스킬 관련 초기화
        self.game_state['dark_slash_freeze'] = False
        self.game_state['dark_slash_active'] = False
        self.game_state['dark_slash_phase'] = 0
        self.game_state['top_paddle_speed_boost'] = 1.0
        self.game_state['bottom_paddle_speed_boost'] = 1.0
        self.game_state['demon_eye_active'] = False

        # 난쟁이마술 (크로노스) 축소 효과 초기화
        self.game_state['top_paddle_shrink'] = False
        self.game_state['top_paddle_shrink_scale'] = 1.0
        self.game_state['bottom_paddle_shrink'] = False
        self.game_state['bottom_paddle_shrink_scale'] = 1.0

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
