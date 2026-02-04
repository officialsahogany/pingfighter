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
            # 정지 해제 - 공 4배 가속 + 반격 (Y 방향 반전)
            speed_boost = 4.0
            ball.vx = self.original_ball_vx * speed_boost
            # 무겐(상단)이 베면 아래로, 하단이면 위로 반격
            if self.caster_is_top:
                ball.vy = abs(self.original_ball_vy) * speed_boost  # 양수 = 아래로
            else:
                ball.vy = -abs(self.original_ball_vy) * speed_boost  # 음수 = 위로
            print(f"[DarkSlash] 4배 가속 + 반격! vx={ball.vx:.1f}, vy={ball.vy:.1f}, caster_is_top={self.caster_is_top}")

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
    """귀신발걸음 - 7초간 이동속도 200% 증가 (3배) + 오오라 이펙트"""
    def __init__(self):
        super().__init__(
            skill_id="demon_step",
            name="Ghost Step",
            korean_name="귀신발걸음",
            description="어둠의 기운을 두르고 이동속도가 3배로 증가한다",
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

        # 이동속도 200% 증가 (3배)
        speed_key = 'top_paddle_speed_boost' if caster_paddle.is_top else 'bottom_paddle_speed_boost'
        game_state[speed_key] = 3.0  # 200% 증가 = 3배
        game_state['demon_eye_active'] = True
        game_state['demon_eye_caster_is_top'] = caster_paddle.is_top

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

        print(f"[GhostStep] 귀신발걸음 발동! 이동속도 3배, 지속시간 7초")

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
    """촉수 휘감기 - 상대 패들 둔화"""
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

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        self.target_is_top = target_paddle.is_top
        self.caster_is_top = caster_paddle.is_top
        self.phase = 'travel'
        self.travel_progress = 0
        self.wrap_timer = 0
        self.slow_applied = False

        # 촉수 생성 - caster(크라켄) 위치에서 시작
        self.tentacles = []
        caster_center_x = caster_paddle.x + 40
        caster_center_y = caster_paddle.y + (20 if caster_paddle.is_top else -20)

        for i in range(6):
            # 각 촉수가 caster 주변에서 약간씩 다른 위치에서 시작
            offset_x = random.uniform(-30, 30)
            offset_y = random.uniform(-10, 10)
            self.tentacles.append({
                'start_x': caster_center_x + offset_x,
                'start_y': caster_center_y + offset_y,
                'offset_x': offset_x,  # caster 기준 오프셋 저장
                'offset_y': offset_y,
                'target_x': target_paddle.x + 40,
                'target_y': target_paddle.y,
                'progress': 0,
                'wave_offset': random.uniform(0, math.pi * 2),
                'thickness': random.uniform(5, 9),
                'wrap_angle': i * (360 / 6),  # 감싸기 시 각도
                'wrap_radius': random.uniform(30, 50)  # 감싸기 반경
            })

        # 둔화는 아직 적용하지 않음 (촉수가 도달해야 적용)
        return {
            'status_duration': self.duration,
            'sound': 'tentacle'
        }

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        # caster와 target 위치 실시간 업데이트
        caster_center_x = caster_paddle.x + 40
        caster_center_y = caster_paddle.y + (20 if caster_paddle.is_top else -20)

        for t in self.tentacles:
            # caster 위치 업데이트 (촉수가 크라켄과 계속 연결)
            t['start_x'] = caster_center_x + t['offset_x']
            t['start_y'] = caster_center_y + t['offset_y']
            # target 위치 업데이트
            t['target_x'] = target_paddle.x + 40
            t['target_y'] = target_paddle.y
            t['wave_offset'] += dt * 4

        if self.phase == 'travel':
            # 이동 단계: 촉수가 caster에서 target으로 뻗어나감
            self.travel_progress = min(1.0, self.travel_progress + dt * 1.5)  # 약 0.67초에 도달
            for t in self.tentacles:
                t['progress'] = self.travel_progress

            # 촉수가 도달하면 wrap 단계로 전환
            if self.travel_progress >= 1.0:
                self.phase = 'wrap'
                self.wrap_timer = 0
                # 이제 둔화 적용 (60% 감소)
                if not self.slow_applied:
                    self.slow_applied = True
                    target_prefix = 'top_paddle' if target_paddle.is_top else 'bottom_paddle'
                    # 스턴 플래그는 명시적으로 False 유지 (둔화이므로)
                    game_state[f'{target_prefix}_stunned'] = False
                    game_state['target_stunned'] = False
                    # 둔화 적용
                    game_state[f'{target_prefix}_slowed'] = True
                    game_state[f'{target_prefix}_slow_amount'] = self.slow_amount
                    game_state['target_slowed'] = True
                    game_state['slow_amount'] = self.slow_amount
                    # 촉수 휘감기 전용 플래그 (둔화 이펙트용)
                    game_state['tentacle_wrap_active'] = True
                    game_state['tentacle_wrap_target_is_top'] = target_paddle.is_top

        elif self.phase == 'wrap':
            # 감싸기 단계: 촉수가 target을 감싸면서 둔화 유지
            self.wrap_timer += dt
            # 매 프레임 스턴 플래그 False 유지 (둔화만 적용, 스턴 아님)
            target_prefix = 'top_paddle' if target_paddle.is_top else 'bottom_paddle'
            game_state[f'{target_prefix}_stunned'] = False
            game_state['target_stunned'] = False
            for t in self.tentacles:
                # 감싸기 애니메이션 - 촉수가 target 주위를 회전
                t['wrap_angle'] += dt * 120  # 회전 속도

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        game_state['target_slowed'] = False
        game_state['slow_amount'] = 1.0
        # 패들별 상태 클리어
        target_prefix = 'top_paddle' if self.target_is_top else 'bottom_paddle'
        game_state[f'{target_prefix}_slowed'] = False
        game_state[f'{target_prefix}_slow_amount'] = 1.0
        # 촉수 휘감기 전용 플래그 해제
        game_state['tentacle_wrap_active'] = False
        self.tentacles = []
        self.phase = 'travel'
        self.slow_applied = False

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        # caster 위치 (실시간)
        caster_center_x = caster_paddle.x + 40
        caster_center_y = caster_paddle.y + (20 if caster_paddle.is_top else -20)

        if self.phase == 'travel':
            # 이동 단계: caster에서 target으로 뻗어나가는 촉수
            for t in self.tentacles:
                if t['progress'] > 0:
                    # 시작점은 caster 위치 (실시간)
                    start_x = caster_center_x + t['offset_x']
                    start_y = caster_center_y + t['offset_y']

                    points = []
                    segments = 25
                    for i in range(segments + 1):
                        prog = i / segments * t['progress']
                        # 물결 효과 (시작점 근처는 약하게, 끝으로 갈수록 강하게)
                        wave_strength = 25 * math.sin(prog * math.pi)  # 중간이 가장 강함
                        wave = math.sin(prog * math.pi * 4 + t['wave_offset']) * wave_strength

                        x = start_x + (t['target_x'] - start_x) * prog + wave
                        y = start_y + (t['target_y'] - start_y) * prog
                        points.append((int(x), int(y)))

                    if len(points) > 1:
                        # 촉수 본체 (그라데이션 효과)
                        thickness = int(t['thickness'] * (1.2 - t['progress'] * 0.4))
                        pygame.draw.lines(screen, (30, 80, 100), False, points, thickness + 2)
                        pygame.draw.lines(screen, (50, 120, 140), False, points, thickness)

                        # 빨판 (촉수 끝부분에만)
                        for j, (px, py) in enumerate(points[::4]):
                            if j > 0:
                                size = int(t['thickness'] * 0.5)
                                pygame.draw.circle(screen, (70, 150, 170), (px, py), size)
                                pygame.draw.circle(screen, (40, 100, 120), (px, py), size, 1)

                        # 촉수 끝 하이라이트
                        if len(points) > 0:
                            end_x, end_y = points[-1]
                            glow_surf = pygame.Surface((20, 20), pygame.SRCALPHA)
                            pygame.draw.circle(glow_surf, (100, 200, 220, 100), (10, 10), 8)
                            screen.blit(glow_surf, (end_x - 10, end_y - 10))

        elif self.phase == 'wrap':
            # 감싸기 단계: target을 감싸는 촉수 (caster와 계속 연결)
            target_x = target_paddle.x + 40
            target_y = target_paddle.y

            for t in self.tentacles:
                # 시작점은 caster 위치 (실시간)
                start_x = caster_center_x + t['offset_x']
                start_y = caster_center_y + t['offset_y']

                # 감싸는 원형 궤도
                angle_rad = math.radians(t['wrap_angle'])
                wrap_x = target_x + t['wrap_radius'] * math.cos(angle_rad)
                wrap_y = target_y + t['wrap_radius'] * 0.6 * math.sin(angle_rad)  # 타원형

                # caster에서 wrap 위치까지 촉수 그리기
                points = []
                segments = 20
                # 중간 제어점 (caster와 target 사이)
                mid_x = (start_x + target_x) / 2
                mid_y = (start_y + target_y) / 2

                for i in range(segments + 1):
                    prog = i / segments
                    # 2차 베지어 곡선
                    inv_prog = 1 - prog
                    x = inv_prog * inv_prog * start_x + 2 * inv_prog * prog * mid_x + prog * prog * wrap_x
                    y = inv_prog * inv_prog * start_y + 2 * inv_prog * prog * mid_y + prog * prog * wrap_y

                    # 물결 효과
                    wave = math.sin(prog * math.pi * 3 + t['wave_offset']) * 15 * (1 - prog)
                    x += wave

                    points.append((int(x), int(y)))

                if len(points) > 1:
                    thickness = int(t['thickness'])
                    pygame.draw.lines(screen, (30, 80, 100), False, points, thickness + 2)
                    pygame.draw.lines(screen, (50, 120, 140), False, points, thickness)

                    # 빨판
                    for j, (px, py) in enumerate(points[::5]):
                        if j > 0:
                            size = int(t['thickness'] * 0.4)
                            pygame.draw.circle(screen, (70, 150, 170), (px, py), size)

            # 감싸기 효과 - 타겟 주변 원형 표시
            wrap_surf = pygame.Surface((120, 80), pygame.SRCALPHA)
            pygame.draw.ellipse(wrap_surf, (50, 120, 140, 80), (0, 0, 120, 80), 3)
            screen.blit(wrap_surf, (target_x - 60, target_y - 40))

    def reset_for_new_round(self, game_state: dict):
        """라운드 전환 시 촉수 휘감기 스킬 강제 종료"""
        super().reset_for_new_round(game_state)
        # 촉수 제거
        self.tentacles = []
        self.phase = 'travel'
        self.travel_progress = 0
        self.wrap_timer = 0
        # 둔화 효과 해제
        if self.slow_applied:
            target_prefix = 'top_paddle' if self.target_is_top else 'bottom_paddle'
            game_state[f'{target_prefix}_slowed'] = False
            game_state[f'{target_prefix}_slow_amount'] = 1.0
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
class TimeStop(HeroSkill):
    """시간 정지 - 상대방을 잠시 멈춤"""
    def __init__(self):
        super().__init__(
            skill_id="time_stop",
            name="Time Stop",
            korean_name="시간 정지",
            description="시간을 멈춰 상대방을 일시적으로 움직이지 못하게 한다",
            trigger=SkillTrigger.ON_COOLDOWN,
            cooldown=30.0,
            duration=2.5,
            hero_id="chronos"
        )
        self.clock_hands_angle = 0
        self.time_particles = []
        self.target_is_top = False

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        self.target_is_top = target_paddle.is_top
        game_state['target_stunned'] = True
        self.clock_hands_angle = 0

        # 시간 파티클
        self.time_particles = []
        for i in range(30):
            self.time_particles.append({
                'x': random.uniform(80, 680),
                'y': random.uniform(0, 750),
                'char': random.choice(['⏰', '⌛', '🕐', '◷', '◶']),
                'size': random.randint(12, 24),
                'alpha': 255,
                'vy': random.uniform(-20, 20)
            })

        return {
            'screen_effect': ScreenEffect.TIME_STOP,
            'target_status': StatusEffect.STUN,
            'status_duration': self.duration,
            'screen_tint': (200, 180, 100),
            'sound': 'time_stop'
        }

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        self.clock_hands_angle += dt * 720  # 빠르게 회전

        for p in self.time_particles:
            p['y'] += p['vy'] * dt
            p['alpha'] = max(0, p['alpha'] - dt * 80)

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        game_state['target_stunned'] = False
        # 패들별 상태 클리어
        target_prefix = 'top_paddle' if self.target_is_top else 'bottom_paddle'
        game_state[f'{target_prefix}_stunned'] = False
        self.time_particles = []

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        if self.is_active:
            # 세피아 톤 오버레이
            overlay = pygame.Surface((760, 750), pygame.SRCALPHA)
            overlay.fill((200, 180, 100, 60))
            screen.blit(overlay, (0, 0))

            # 상대 패들 위에 시계 이펙트
            clock_x = target_paddle.x + 40
            clock_y = target_paddle.y

            # 시계 배경
            pygame.draw.circle(screen, (200, 170, 100), (int(clock_x), int(clock_y)), 35)
            pygame.draw.circle(screen, (50, 40, 30), (int(clock_x), int(clock_y)), 35, 3)

            # 시계 바늘
            for i, length in enumerate([20, 28]):
                angle = math.radians(self.clock_hands_angle * (1 if i == 0 else 0.08) - 90)
                end_x = clock_x + math.cos(angle) * length
                end_y = clock_y + math.sin(angle) * length
                pygame.draw.line(screen, (50, 40, 30), (int(clock_x), int(clock_y)),
                               (int(end_x), int(end_y)), 3 if i == 0 else 2)

            # STOP 텍스트
            font = pygame.font.Font(None, 28)
            text = font.render("STOP", True, (200, 50, 50))
            text_rect = text.get_rect(center=(int(clock_x), int(clock_y - 50)))
            screen.blit(text, text_rect)


class TimeRewind(HeroSkill):
    """시간 역행 - 공을 이전 위치로 되돌림"""
    def __init__(self):
        super().__init__(
            skill_id="time_rewind",
            name="Time Rewind",
            korean_name="시간 역행",
            description="공의 시간을 되돌려 이전 위치로 되돌린다",
            trigger=SkillTrigger.ON_BALL_HIT,
            cooldown=12.0,
            duration=0.8,
            hero_id="chronos"
        )
        self.ball_history = []
        self.rewind_progress = 0

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        # 공 위치 히스토리 저장 (되돌릴 위치)
        self.ball_history = game_state.get('ball_history', [])[-30:]  # 최근 30프레임
        self.rewind_progress = 0

        if self.ball_history:
            # 공 방향 반전
            ball.vx = -ball.vx * 0.8
            ball.vy = -ball.vy * 0.8

        return {
            'screen_effect': ScreenEffect.FLASH,
            'flash_color': (200, 180, 100),
            'flash_duration': 0.2,
            'sound': 'rewind'
        }

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        self.rewind_progress += dt

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        if self.is_active and self.ball_history:
            # 공의 잔상 (역방향)
            for i, (bx, by) in enumerate(reversed(self.ball_history[-15:])):
                alpha = int(150 * (1 - i / 15))
                size = int(10 * (1 - i / 15 * 0.5))
                if alpha > 20 and size > 2:
                    surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                    pygame.draw.circle(surf, (200, 180, 100, alpha), (size, size), size)
                    screen.blit(surf, (int(bx - size), int(by - size)))


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
# 마리아 스킬 - 인형사 (트릭형)
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
            duration=4.0,  # 총 4초: 뻗기 0.7초 + 끌기 1.3초 + 뽀뽀 1초 + 복귀 1초
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
                'offset_x': -20 + i * 10,  # 마리아 손에서의 오프셋
                'wave': random.uniform(0, math.pi * 2),
                'thickness': 2 + random.randint(0, 1)
            })

        # 뽀뽀 이펙트 초기화
        self.kiss_hearts = []
        self.kiss_sparkles = []

        # 마리아 고정
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

        # 마리아 위치 고정 (X축 및 Y축)
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

        # Phase 2: 상대 끌어당기기 (1.3초)
        elif self.phase == self.PHASE_PULLING:
            pull_progress = min(1.0, self.phase_timer / 1.3)
            # 이징 함수로 부드럽게
            eased = 1 - (1 - pull_progress) ** 2

            # 마리아 근처로 끌어옴 (Y축) - 마리아 방향으로 크게 당김
            kiss_y = self.caster_y + (-60 if not caster_paddle.is_top else 60)
            new_y = self.target_original_y + (kiss_y - self.target_original_y) * eased
            target_paddle.y = new_y

            # X축도 마리아 위치로
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

        # Phase 4: 원래 위치로 복귀 (1초)
        elif self.phase == self.PHASE_RETURNING:
            return_progress = min(1.0, self.phase_timer / 1.0)
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

        # 마리아 고정 해제
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

        # 마리아 손 위치에 작은 원 (실 잡는 곳)
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
        # 마리아 고정 위치 및 불꽃 이펙트
        self.caster_locked_x = 0
        self.caster_locked_y = 0
        self.flame_particles = []
        self.flame_timer = 0
        # 수호 인형 (마리아 좌우 150px에 생성, 공을 막음)
        self.guardian_dolls = []
        self.guardian_offset = 150  # 마리아로부터의 거리
        self.guardian_size = 30  # 수호 인형 충돌 반경

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        self.target_is_top = target_paddle.is_top
        game_state['target_confused'] = True
        game_state['confusion_type'] = 'reverse'  # 조작 반전

        # 마리아(caster) 제자리 고정 (X축 및 Y축 모두)
        self.caster_locked_x = caster_paddle.x
        self.caster_locked_y = caster_paddle.y
        # 캐릭터 스프라이트 중심 위치 저장 (centerx 사용)
        self.caster_centerx = getattr(caster_paddle, 'centerx', caster_paddle.x + 40)
        self.caster_is_top = caster_paddle.is_top
        caster_prefix = 'top_paddle' if caster_paddle.is_top else 'bottom_paddle'
        game_state[f'{caster_prefix}_locked'] = True
        game_state[f'{caster_prefix}_locked_x'] = self.caster_locked_x
        game_state[f'{caster_prefix}_locked_y'] = self.caster_locked_y

        # 저주 인형 이펙트 - 상대 패들 주변에서 시작
        self.curse_dolls = []
        for i in range(3):
            angle = (i / 3) * math.pi * 2 + random.uniform(-0.3, 0.3)
            distance = random.uniform(40, 80)
            self.curse_dolls.append({
                'x': target_paddle.x + 40 + math.cos(angle) * distance,
                'y': target_paddle.y + math.sin(angle) * distance,
                'base_angle': angle,
                'distance': distance,
                'rotation': random.uniform(0, 360),
                'scale': random.uniform(0.6, 1.0),
                'wobble': random.uniform(0, math.pi * 2),
                'orbit_speed': random.uniform(0.5, 1.2),
                'float_offset': random.uniform(0, math.pi * 2)
            })

        # 마리아 주변 불꽃 파티클 초기화
        self.flame_particles = []
        self.flame_timer = 0

        # 수호 인형 생성 (마리아 좌우 150px에 배치)
        self.guardian_dolls = []
        caster_center_x = self.caster_centerx
        # 마리아 앞쪽 Y 좌표 (공이 오는 방향)
        if caster_paddle.is_top:
            guardian_y = self.caster_locked_y + 60  # 상단 영웅이면 아래쪽에
        else:
            guardian_y = self.caster_locked_y - 60  # 하단 영웅이면 위쪽에 (공이 오는 방향)

        # 왼쪽 수호 인형
        self.guardian_dolls.append({
            'x': caster_center_x - self.guardian_offset,
            'y': guardian_y,
            'spawn_x': caster_center_x,  # 시작 위치 (마리아 중심)
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
            'y': guardian_y,
            'spawn_x': caster_center_x,
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
        # 마리아(caster) 제자리 고정 유지 (X축 및 Y축 모두)
        caster_paddle.x = self.caster_locked_x
        caster_paddle.y = self.caster_locked_y

        # 저주 인형들 상대 패들 주변에서 천천히 공전
        for doll in self.curse_dolls:
            doll['wobble'] += dt * 3
            doll['base_angle'] += dt * doll['orbit_speed']
            doll['float_offset'] += dt * 2

            # 상대 패들 중심 기준 공전
            center_x = target_paddle.x + 40
            center_y = target_paddle.y
            float_y = math.sin(doll['float_offset']) * 8  # 위아래 둥실둥실
            doll['x'] = center_x + math.cos(doll['base_angle']) * doll['distance']
            doll['y'] = center_y + math.sin(doll['base_angle']) * doll['distance'] * 0.5 + float_y
            doll['rotation'] += math.sin(doll['wobble']) * 3

        # 수호 인형 업데이트 (마리아 좌우에서 공 막기)
        for guardian in self.guardian_dolls:
            # 생성 애니메이션 (마리아 중심에서 좌우로 이동)
            if guardian['spawn_progress'] < 1.0:
                guardian['spawn_progress'] += dt * 2.5  # 0.4초에 완료
                guardian['spawn_progress'] = min(1.0, guardian['spawn_progress'])
                # 이징 함수 (ease-out)
                ease = 1 - (1 - guardian['spawn_progress']) ** 3
                guardian['x'] = guardian['spawn_x'] + (guardian['target_x'] - guardian['spawn_x']) * ease

            # 위아래 둥실둥실 흔들림
            guardian['wobble'] += dt * 4
            float_y = math.sin(guardian['wobble']) * 5

            # Y 위치 업데이트 (기본 위치 + 흔들림)
            if self.caster_is_top:
                base_y = self.caster_locked_y + 60
            else:
                base_y = self.caster_locked_y - 60
            guardian['y'] = base_y + float_y

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

        # 마리아 주변 불꽃 파티클 생성 (캐릭터 스프라이트 위치에)
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
                # 하단 영웅 (마리아): 캐릭터가 패들 위에 그려짐
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

        # 마리아(caster) 고정 해제
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

            # 마리아 주변 이글이글 불꽃 이펙트
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

            # 마리아 캐릭터 스프라이트 위에 오라 이펙트
            caster_center_x = int(self.caster_centerx)
            # 캐릭터 스프라이트 중심 위치 (캐릭터 몸 전체를 감싸도록)
            if self.caster_is_top:
                caster_center_y = int(self.caster_locked_y + 28)  # 상단 영웅
            else:
                caster_center_y = int(self.caster_locked_y - 8)  # 하단 영웅 (마리아)

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

            # 수호 인형들 (마리아 좌우 150px에서 공을 막음) - 고퀄리티 부두 인형 스타일
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

                # === 외부 마법진/보호 오라 (인형 뒤에) ===
                aura_pulse = 0.7 + 0.3 * math.sin(time_tick * 0.008 + guardian['wobble'])
                # 외부 원형 마법진
                magic_size = int(55 * s * aura_pulse)
                magic_surf = pygame.Surface((magic_size * 2, magic_size * 2), pygame.SRCALPHA)
                # 외부 링
                pygame.draw.circle(magic_surf, (180, 80, 120, int(50 * spawn_alpha)),
                                 (magic_size, magic_size), magic_size, 2)
                # 내부 글로우
                for r in range(magic_size, 0, -5):
                    alpha = int(20 * spawn_alpha * (r / magic_size))
                    pygame.draw.circle(magic_surf, (200, 100, 150, alpha),
                                     (magic_size, magic_size), r)
                screen.blit(magic_surf, (gx - magic_size, gy - magic_size))

                # === 그림자 (입체감) ===
                shadow_w, shadow_h = int(40 * s), int(12 * s)
                shadow_surf = pygame.Surface((shadow_w, shadow_h), pygame.SRCALPHA)
                pygame.draw.ellipse(shadow_surf, (0, 0, 0, int(100 * spawn_alpha)), shadow_surf.get_rect())
                screen.blit(shadow_surf, (gx - shadow_w // 2, gy + int(38 * s)))

                # === 마리아와 연결된 실 (인형 뒤에 그리기) ===
                caster_center_x = int(self.caster_centerx)
                if self.caster_is_top:
                    thread_start_y = int(self.caster_locked_y + 28)
                else:
                    thread_start_y = int(self.caster_locked_y - 8)
                # 여러 가닥 실
                for thread_i, thread_offset in enumerate([-8, 0, 8]):
                    thread_alpha = int((120 - abs(thread_offset) * 5) * spawn_alpha)
                    t_start_x = caster_center_x + thread_offset
                    t_end_x = gx + thread_offset // 2
                    # 곡선 실 (3개 포인트)
                    mid_x = (t_start_x + t_end_x) // 2
                    sway = math.sin(time_tick * 0.003 + thread_i) * 15  # 흔들림
                    mid_y = (gy + thread_start_y) // 2 - 25 + sway
                    pygame.draw.line(screen, (150, 70, 100), (t_start_x, thread_start_y), (mid_x, int(mid_y)), 1)
                    pygame.draw.line(screen, (150, 70, 100), (mid_x, int(mid_y)), (t_end_x, gy - int(22 * s)), 1)

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
                for ly in range(int(leg_ly + 5*s), int(leg_ly + 20*s), int(6*s)):
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
                for sy in range(int(gy - 8*s), int(gy + 20*s), int(5*s)):
                    pygame.draw.line(screen, stitch_color, (gx - int(2*s), sy), (gx + int(2*s), sy + int(3*s)), 1)
                # 가로 스티치 (패치 느낌)
                pygame.draw.line(screen, stitch_color, (gx - int(10*s), gy + int(5*s)), (gx + int(10*s), gy + int(5*s)), 1)
                for sx in range(int(gx - 8*s), int(gx + 10*s), int(4*s)):
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

            # 저주 인형들 (상대 패들 주변에서 공전)
            for doll in self.curse_dolls:
                dx, dy = int(doll['x']), int(doll['y'])
                s = doll['scale']

                # 그림자
                shadow_surf = pygame.Surface((int(24 * s), int(8 * s)), pygame.SRCALPHA)
                pygame.draw.ellipse(shadow_surf, (0, 0, 0, 50), shadow_surf.get_rect())
                screen.blit(shadow_surf, (dx - int(12 * s), dy + int(20 * s)))

                # 머리
                pygame.draw.circle(screen, (60, 40, 50), (dx, dy - int(20 * s)), int(12 * s))
                # X 눈
                pygame.draw.line(screen, (200, 50, 80),
                               (dx - int(6 * s), dy - int(23 * s)),
                               (dx - int(2 * s), dy - int(19 * s)), 2)
                pygame.draw.line(screen, (200, 50, 80),
                               (dx - int(6 * s), dy - int(19 * s)),
                               (dx - int(2 * s), dy - int(23 * s)), 2)
                pygame.draw.line(screen, (200, 50, 80),
                               (dx + int(2 * s), dy - int(23 * s)),
                               (dx + int(6 * s), dy - int(19 * s)), 2)
                pygame.draw.line(screen, (200, 50, 80),
                               (dx + int(2 * s), dy - int(19 * s)),
                               (dx + int(6 * s), dy - int(23 * s)), 2)
                # 몸통
                pygame.draw.ellipse(screen, (80, 50, 70),
                                   (dx - int(10 * s), dy - int(5 * s), int(20 * s), int(30 * s)))
                # 저주 실 (인형에서 위로)
                thread_color = (150, 80, 100, 150)
                for tx in [-5, 0, 5]:
                    pygame.draw.line(screen, (150, 80, 100),
                                   (dx + int(tx * s), dy - int(32 * s)),
                                   (dx + int(tx * s), dy - int(50 * s)), 1)

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
        # 마리아 고정 해제
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
            duration=1.5,
            hero_id="ignis"
        )
        self.breath_particles = []
        self.breath_active = False
        self.breath_hit_ball = False
        self.fire_zone_spawned = False  # 화염 지대 생성 여부

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        self.breath_particles = []
        self.breath_active = True
        self.breath_hit_ball = False
        self.fire_zone_spawned = False  # 화염 지대 생성 플래그 초기화

        # 브레스 방향 (caster_is_top 속성 우선 사용)
        is_caster_top = getattr(self, 'caster_is_top', caster_paddle.is_top)
        direction = 1 if is_caster_top else -1

        # 발사 시점의 X 좌표 저장 (화염지대 생성 위치용)
        self.breath_start_x = caster_paddle.x + caster_paddle.width // 2

        # 화염 파티클 대량 생성
        for i in range(50):
            self.breath_particles.append({
                'x': caster_paddle.x + 40 + random.uniform(-20, 20),
                'y': caster_paddle.y + direction * 20,
                'vx': random.uniform(-40, 40),
                'vy': direction * random.uniform(200, 400),
                'life': random.uniform(0.8, 1.5),
                'size': random.uniform(8, 20),
                'color_phase': random.uniform(0, 1)
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

        for p in self.breath_particles:
            p['x'] += p['vx'] * dt
            p['y'] += p['vy'] * dt
            p['life'] -= dt
            p['size'] *= 0.98
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

        self.breath_particles = [p for p in self.breath_particles if p['life'] > 0]

        # 스킬 종료 0.5초 전에 화염 지대 생성 (화염병과 동일한 넉백 효과)
        if not self.fire_zone_spawned and self.active_timer <= 0.5 and target_paddle:
            self.fire_zone_spawned = True
            # caster_is_top 속성 사용 (init_hero_skills에서 설정됨)
            is_caster_top = getattr(self, 'caster_is_top', caster_paddle.is_top)

            if is_caster_top:
                # 상단에서 발사 → 하단 target의 위쪽(앞쪽)에 화염
                fire_y = target_paddle.y - 30
            else:
                # 하단에서 발사 → 상단 target의 아래쪽(앞쪽)에 화염
                fire_y = target_paddle.y + target_paddle.height + 30

            # 발사 시점의 X 좌표 사용 (breath_start_x가 없으면 target 패들 중앙 사용)
            fire_x = getattr(self, 'breath_start_x', target_paddle.x + target_paddle.width // 2)

            game_state['spawn_dragon_fire_zone'] = {
                'x': fire_x,
                'y': fire_y,
                'width': 120,  # 화염 지대 너비
                'height': 60,  # 화염 지대 높이
                'duration': 90,  # 1.5초 (60fps * 1.5)
                'source': 'dragon_breath'
            }

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        self.breath_particles = []
        self.breath_active = False
        game_state['ball_on_fire'] = False  # 화염 공 이펙트 해제
        # 화염 지대는 _update_active_effect에서 종료 0.5초 전에 생성됨

    def reset_for_new_round(self, game_state: dict):
        """라운드 전환 시 드래곤 브레스 스킬 강제 종료"""
        super().reset_for_new_round(game_state)
        self.breath_particles = []
        self.breath_active = False
        self.breath_hit_ball = False
        self.fire_zone_spawned = False
        game_state['ball_on_fire'] = False

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        for p in self.breath_particles:
            if p['size'] > 2:
                # 화염 색상 변화 (값 범위 0~255로 클램핑)
                phase = p['color_phase'] % 1.0
                if phase < 0.33:
                    r, g, b = 255, 255, int(200 * (1 - phase * 3))
                elif phase < 0.66:
                    r, g, b = 255, int(255 - 155 * (phase - 0.33) * 3), 0
                else:
                    r = int(255 - 55 * (phase - 0.66) * 3)
                    g = int(100 - 100 * (phase - 0.66) * 3)
                    b = 0

                # 색상값 클램핑 (0~255)
                r = max(0, min(255, r))
                g = max(0, min(255, g))
                b = max(0, min(255, b))

                alpha = int(200 * (p['life'] / 1.5))
                alpha = max(0, min(255, alpha))  # 알파값도 클램핑

                surf = pygame.Surface((int(p['size'] * 2), int(p['size'] * 2)), pygame.SRCALPHA)
                pygame.draw.circle(surf, (r, g, b, alpha), (int(p['size']), int(p['size'])), int(p['size']))
                screen.blit(surf, (int(p['x'] - p['size']), int(p['y'] - p['size'])), special_flags=pygame.BLEND_ADD)


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
        self.barrier_hit = False

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        # 배리어 위치 (홀리 베리어와 동일한 높이)
        # 하단: 패들(710) + 15 = 725 (홀리베리어 위치)
        # 상단: 패들(25) + 40 = 65 (보스 히트박스 하단 근처)
        self.barrier_y = caster_paddle.y + (40 if caster_paddle.is_top else 15)
        self.barrier_hit = False
        game_state['barrier_active'] = True
        game_state['barrier_y'] = self.barrier_y
        game_state['barrier_owner_is_top'] = caster_paddle.is_top

        return {
            'sound': 'steam_release'
        }

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        # 증기 파티클
        if random.random() < 0.3:
            self.steam_particles.append({
                'x': random.uniform(100, 660),
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

        # 공 배리어 충돌 체크
        is_top = game_state.get('barrier_owner_is_top', True)
        if not self.barrier_hit:
            if is_top:
                # 상단 배리어: 공이 아래에서 위로 접근 (ball.y > barrier_y)
                if ball.vy < 0 and abs(ball.y - self.barrier_y) < 20 and ball.y > self.barrier_y:
                    ball.vy = abs(ball.vy) * 1.1
                    self.barrier_hit = True
                    game_state['screen_shake'] = 10
            else:
                # 하단 배리어: 공이 위에서 아래로 접근 (ball.y < barrier_y)
                if ball.vy > 0 and abs(ball.y - self.barrier_y) < 20 and ball.y < self.barrier_y:
                    ball.vy = -abs(ball.vy) * 1.1
                    self.barrier_hit = True
                    game_state['screen_shake'] = 10

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        game_state['barrier_active'] = False
        self.steam_particles = []

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        if self.is_active:
            # 배리어 라인
            barrier_alpha = int(150 + 50 * math.sin(pygame.time.get_ticks() / 100))

            # 메인 배리어 라인
            pygame.draw.line(screen, (180, 200, 220),
                           (100, int(self.barrier_y)), (660, int(self.barrier_y)), 4)

            # 톱니바퀴 장식
            for x in [120, 280, 440, 600]:
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
                    pygame.draw.line(gear_surf, (140, 100, 60, 200), (x1, y1), (x2, y2), 3)
                pygame.draw.circle(gear_surf, (160, 120, 80, 200), (15, 15), 8)
                pygame.draw.circle(gear_surf, (100, 80, 50, 200), (15, 15), 4)
                screen.blit(gear_surf, (x - 15, int(self.barrier_y) - 15))

            # 증기 파티클
            for p in self.steam_particles:
                alpha = int(100 * (p['life'] / 0.8))
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
        is_on_puddle = False
        for puddle in self.oil_puddles:
            # 패들과 웅덩이 충돌 체크
            paddle_left = target_paddle.x
            paddle_right = target_paddle.x + target_paddle.width
            paddle_y = target_paddle.y

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
    """분신술 - 분신 패들 생성"""
    def __init__(self):
        super().__init__(
            skill_id="shadow_clone",
            name="Shadow Clone",
            korean_name="분신술",
            description="그림자 분신을 만들어 상대를 혼란시킨다",
            trigger=SkillTrigger.ON_COOLDOWN,
            cooldown=22.0,
            duration=5.0,
            hero_id="kurokage"
        )
        self.clones = []

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        # 분신 2개 생성
        self.clones = [
            {'x': caster_paddle.x - 120, 'alpha': 150, 'offset': 0},
            {'x': caster_paddle.x + 120, 'alpha': 150, 'offset': math.pi}
        ]
        game_state['has_clones'] = True

        return {
            'screen_effect': ScreenEffect.FLASH,
            'flash_color': (50, 50, 80),
            'flash_duration': 0.15,
            'sound': 'shadow'
        }

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        for clone in self.clones:
            # 분신이 본체 따라 이동
            clone['offset'] += dt * 3
            base_offset = 100 * math.sin(clone['offset'])
            clone['x'] = caster_paddle.x + base_offset
            clone['x'] = max(80, min(clone['x'], 600))

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        game_state['has_clones'] = False
        self.clones = []

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        for clone in self.clones:
            # 반투명 분신 패들
            clone_surf = pygame.Surface((80, 12), pygame.SRCALPHA)
            pygame.draw.rect(clone_surf, (50, 50, 70, int(clone['alpha'])), (0, 0, 80, 12), border_radius=3)

            # 그림자 효과
            shadow_surf = pygame.Surface((85, 15), pygame.SRCALPHA)
            pygame.draw.rect(shadow_surf, (20, 20, 30, int(clone['alpha'] * 0.5)), (0, 0, 85, 15), border_radius=3)

            screen.blit(shadow_surf, (int(clone['x']) - 2, caster_paddle.y + 3))
            screen.blit(clone_surf, (int(clone['x']), caster_paddle.y))


class FlashShuriken(HeroSkill):
    """섬광 수리검 - 조명탄 효과로 시야 방해"""
    def __init__(self):
        super().__init__(
            skill_id="flash_shuriken",
            name="Flash Shuriken",
            korean_name="섬광 수리검",
            description="섬광 수리검을 던져 상대의 눈을 멀게 한다",
            trigger=SkillTrigger.ON_BALL_HIT,
            cooldown=12.0,
            duration=2.0,
            hero_id="kurokage"
        )
        self.shuriken_x = 0
        self.shuriken_y = 0
        self.shuriken_active = False
        self.flash_intensity = 0
        self.rotation = 0
        self.target_is_top = False

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        self.target_is_top = target_paddle.is_top
        self.shuriken_x = caster_paddle.x + 40
        self.shuriken_y = caster_paddle.y
        self.shuriken_active = True
        self.flash_intensity = 0
        self.rotation = 0

        return {
            'sound': 'shuriken'
        }

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        if self.shuriken_active:
            # 수리검 이동
            direction = 1 if caster_paddle.is_top else -1
            self.shuriken_y += direction * 600 * dt
            self.rotation += dt * 1800

            # 상대 패들 근처에서 폭발
            if abs(self.shuriken_y - target_paddle.y) < 50:
                self.shuriken_active = False
                self.flash_intensity = 1.0
                game_state['target_blind'] = True
                game_state['blind_intensity'] = 1.0
                game_state['blind_target_is_top'] = self.target_is_top
        else:
            # 섬광 감소
            self.flash_intensity = max(0, self.flash_intensity - dt * 0.5)
            game_state['blind_intensity'] = self.flash_intensity

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        game_state['target_blind'] = False
        game_state['blind_intensity'] = 0
        self.shuriken_active = False

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        if self.shuriken_active:
            # 회전하는 수리검
            shuriken_size = 20
            surf = pygame.Surface((shuriken_size * 2, shuriken_size * 2), pygame.SRCALPHA)

            center = shuriken_size
            for i in range(4):
                angle = math.radians(self.rotation + i * 90)
                x1 = center + math.cos(angle) * 5
                y1 = center + math.sin(angle) * 5
                x2 = center + math.cos(angle) * shuriken_size
                y2 = center + math.sin(angle) * shuriken_size
                pygame.draw.polygon(surf, (150, 150, 170), [
                    (center, center),
                    (x1 + math.cos(angle + 0.3) * 8, y1 + math.sin(angle + 0.3) * 8),
                    (x2, y2),
                    (x1 + math.cos(angle - 0.3) * 8, y1 + math.sin(angle - 0.3) * 8)
                ])

            pygame.draw.circle(surf, (100, 100, 120), (center, center), 5)
            screen.blit(surf, (int(self.shuriken_x - shuriken_size), int(self.shuriken_y - shuriken_size)))

        # 섬광 효과
        if self.flash_intensity > 0:
            flash_surf = pygame.Surface((760, 750), pygame.SRCALPHA)
            flash_alpha = int(255 * self.flash_intensity)
            flash_surf.fill((255, 255, 255, flash_alpha))
            screen.blit(flash_surf, (0, 0))


# ============================================================================
# 영웅 스킬 매핑
# ============================================================================
HERO_SKILLS: Dict[str, List[HeroSkill]] = {
    "mugen": [DarkSlash(), DemonEye()],
    "kraken": [TentacleWrap(), AbyssInk()],
    "chronos": [TimeStop(), TimeRewind()],
    "onimaru": [HellFire(), HornCharge()],
    "maria": [PuppetControl(), DollCurse()],
    "ignis": [DragonBreath(), DragonWing()],
    "gear": [SteamBarrier(), OilSpill()],
    "kurokage": [ShadowClone(), FlashShuriken()]
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
        - 꼭두각시 조종 (마리아): 패들 고정 해제
        - 인형의 저주 (마리아): 조작 반전 해제
        """
        for hero_id, skills in self.active_skills.items():
            for skill in skills:
                # 활성 스킬 또는 지속 효과가 있는 스킬 모두 초기화
                # (OilSpill의 웅덩이/발사체처럼 is_active=False여도 지속되는 효과 포함)
                has_oil_effects = (hasattr(skill, 'oil_puddles') and skill.oil_puddles) or \
                                  (hasattr(skill, 'oil_projectiles') and skill.oil_projectiles)
                if skill.is_active or has_oil_effects:
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
