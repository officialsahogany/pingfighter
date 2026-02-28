# downtown/hero_skills.py
# 투기장 영웅 스킬 시스템

import pygame
import math
import os
_sin = math.sin
_cos = math.cos
import random
from enum import Enum
from typing import Dict, List, Optional, Tuple, Callable
from localization.manager import get_localization_manager

def _t(key, fallback=None):
    return get_localization_manager().get_text(key, fallback)

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

# === 전체화면 Surface 캐시 (최적화) ===
# 매 프레임 pygame.Surface((760, 750), pygame.SRCALPHA) 반복 생성 방지
_fullscreen_surface = None

def _get_fullscreen_surface():
    """760x750 SRCALPHA Surface를 캐싱하여 재사용"""
    global _fullscreen_surface
    if _fullscreen_surface is None:
        _fullscreen_surface = pygame.Surface((760, 750), pygame.SRCALPHA)
    else:
        _fullscreen_surface.fill((0, 0, 0, 0))
    return _fullscreen_surface

# === 파티클/이펙트 Surface 풀링 (최적화) ===
# draw 메서드에서 매 프레임 pygame.Surface() 반복 생성 방지
_psurf_cache: Dict[Tuple[int, int, int], pygame.Surface] = {}

def _psurf(size, flags=pygame.SRCALPHA):
    """파티클/이펙트 Surface 풀링 - 크기별 캐싱 후 clear하여 재사용"""
    w = max(2, int(size[0]))
    h = max(2, int(size[1]))
    # 4px 단위 양자화로 캐시 적중률 향상
    w = ((w + 3) // 4) * 4
    h = ((h + 3) // 4) * 4
    key = (w, h, flags)
    cached = _psurf_cache.get(key)
    if cached is None:
        cached = pygame.Surface((w, h), flags)
        _psurf_cache[key] = cached
    else:
        cached.fill((0, 0, 0, 0))
    return cached

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
    # 투기장 플레이 영역 표준 상수 (모든 스킬이 상속)
    GAME_LEFT = 0
    GAME_RIGHT = 760

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
        self.activation_flash_timer = 0.0 # 발동 이펙트 타이머 (UI 초상화 깜빡임용)

    @property
    def display_name(self) -> str:
        return _t(f"hero_skill.{self.skill_id}", self.korean_name)

    @property
    def display_description(self) -> str:
        return _t(f"hero_skill.{self.skill_id}.desc", self.description)

    def can_use(self) -> bool:
        """스킬 사용 가능 여부"""
        return self.current_cooldown <= 0 and not self.is_active

    def use(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        """스킬 사용 (오버라이드 필요)"""
        if not self.can_use():
            return {}

        # 퍽 쿨타임 감소 적용 (game_state에서 상단/하단별 멀티플라이어 참조)
        is_top = getattr(self, 'caster_is_top', True)
        if is_top:
            skill_cd_mult = game_state.get('perk_skill_cd_mult_top', 1.0)
        else:
            skill_cd_mult = game_state.get('perk_skill_cd_mult_bottom', 1.0)
        self.current_cooldown = self.cooldown * skill_cd_mult
        self.activation_flash_timer = 1.5  # 발동 이펙트 1.5초
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

        # 발동 이펙트 타이머 감소
        if self.activation_flash_timer > 0:
            self.activation_flash_timer -= dt

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
        self.activation_flash_timer = 0.0

    def reset_for_new_round(self, game_state: dict):
        """라운드 전환 시 스킬 강제 종료 및 상태 초기화
        서브클래스에서 오버라이드하여 추가 정리 작업 수행
        """
        self.activation_flash_timer = 0.0
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
            description="달빛의 기운으로 공을 사선으로 강하게 베어버린다",
            trigger=SkillTrigger.ON_BALL_HIT,
            cooldown=28.0,
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

    def use(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        """서브 전에는 달빛베기 시전 불가 (공이 정지 상태이면 아직 서브 전)"""
        if ball and (abs(ball.vx) < 0.5 and abs(ball.vy) < 0.5):
            return None
        return super().use(caster_paddle, target_paddle, ball, game_state)

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
                'x': self.ball_x + _cos(self.slash_angle + math.pi/2) * offset,
                'y': self.ball_y + _sin(self.slash_angle + math.pi/2) * offset,
                'vx': _cos(spread_angle + math.pi/2) * speed * random.choice([-1, 1]),
                'vy': _sin(spread_angle + math.pi/2) * speed * random.choice([-1, 1]),
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
                darkness = _get_fullscreen_surface()
                # 맥동하는 어둠
                pulse = 0.6 + 0.2 * _sin(self.freeze_flash_timer * 8)
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
                    half_surf = _psurf((30, 30), pygame.SRCALPHA)
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
                start_x = bx - _cos(self.slash_angle) * slash_length
                start_y = by - _sin(self.slash_angle) * slash_length
                end_x = bx + _cos(self.slash_angle) * slash_length
                end_y = by + _sin(self.slash_angle) * slash_length

                # 글로우 레이어 (보라색/흰색)
                for glow in range(5):
                    glow_width = 12 - glow * 2
                    alpha = 200 - glow * 40
                    glow_surf = _get_fullscreen_surface()

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
                        impact_surf = _psurf((impact_size * 2, impact_size * 2), pygame.SRCALPHA)
                        pygame.draw.circle(impact_surf, (255, 200, 255, 150),
                                         (impact_size, impact_size), impact_size)
                        screen.blit(impact_surf, (int(end_x) - impact_size, int(end_y) - impact_size),
                                   special_flags=pygame.BLEND_ADD)

            # === 정지 중 베기 자국 유지 ===
            if self.phase == self.PHASE_FREEZE:
                # 베기 자국 (지속)
                slash_length = 200
                start_x = bx - _cos(self.slash_angle) * slash_length
                start_y = by - _sin(self.slash_angle) * slash_length
                end_x = bx + _cos(self.slash_angle) * slash_length
                end_y = by + _sin(self.slash_angle) * slash_length

                # 잔상 글로우
                pulse = 0.7 + 0.3 * _sin(self.freeze_flash_timer * 10)
                for glow in range(3):
                    glow_surf = _get_fullscreen_surface()
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
                surf = _psurf((size * 2, size * 2), pygame.SRCALPHA)
                pygame.draw.circle(surf, (*spark['color'][:3], alpha), (size, size), size)
                screen.blit(surf, (int(spark['x']) - size, int(spark['y']) - size),
                           special_flags=pygame.BLEND_ADD)

        # === 가속 중 공 이펙트 ===
        if self.dark_slash_active and self.phase == self.PHASE_ACTIVE:
            live_bx, live_by = int(ball.x), int(ball.y)

            # 검은 오라
            for r in range(3):
                glow_size = 18 + r * 10
                glow_surf = _psurf((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
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
            description="무겐이 귀신에 빙의된 채 공을 이끌고 상대에게 돌진합니다",
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
        self._is_henchman = getattr(caster_paddle, 'is_bodyguard', False)

        game_state['demon_eye_active'] = True
        game_state['demon_eye_caster_is_top'] = caster_paddle.is_top

        if self._is_henchman:
            # 하수인 귀신발걸음: 하수인 자체가 Y축 이동 (영웅 패들은 안 움직임)
            game_state['henchman_demon_eye_active'] = True
            game_state['henchman_demon_eye_is_top'] = caster_paddle.is_top
        else:
            # 호위무사/영웅 귀신발걸음: 기존 동작 (영웅 패들 이동)
            speed_key = 'top_paddle_speed_boost' if caster_paddle.is_top else 'bottom_paddle_speed_boost'
            game_state[speed_key] = 1.5
            size_key = 'top_paddle_size_boost' if caster_paddle.is_top else 'bottom_paddle_size_boost'
            game_state[size_key] = 1.2

            # Y축 이동 트리거 (영웅 패들)
            if hasattr(caster_paddle, 'start_ghost_step'):
                caster_paddle.start_ghost_step()
            else:
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
            p['alpha'] = int(150 + 50 * _sin(self.aura_timer * 5 + p['angle']))

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        if not getattr(self, '_is_henchman', False):
            # 호위무사/영웅: 패들 부스트 원래대로
            speed_key = 'top_paddle_speed_boost' if self.caster_is_top else 'bottom_paddle_speed_boost'
            game_state[speed_key] = 1.0
            size_key = 'top_paddle_size_boost' if self.caster_is_top else 'bottom_paddle_size_boost'
            game_state[size_key] = 1.0
        # 하수인/공통 플래그 정리
        game_state['demon_eye_active'] = False
        game_state.pop('henchman_demon_eye_active', None)
        game_state.pop('henchman_demon_eye_is_top', None)
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
            pulse = 1 + 0.15 * _sin(self.aura_timer * 6)

            # 외곽 글로우 (큰 원)
            glow_radius = int(60 * pulse)
            glow_surf = _psurf((glow_radius * 2 + 20, glow_radius * 2 + 20), pygame.SRCALPHA)
            for r in range(glow_radius, 0, -3):
                alpha = int(80 * (r / glow_radius))
                pygame.draw.circle(glow_surf, (120, 30, 180, alpha),
                                 (glow_radius + 10, glow_radius + 10), r)
            screen.blit(glow_surf, (int(paddle_cx - glow_radius - 10),
                                   int(paddle_cy - glow_radius - 10)),
                       special_flags=pygame.BLEND_ADD)

            # 회전하는 오오라 파티클
            for p in self.aura_particles:
                px = paddle_cx + _cos(p['angle']) * p['radius'] * pulse
                py = paddle_cy + _sin(p['angle']) * p['radius'] * pulse

                # 파티클 글로우
                p_size = int(p['size'] * pulse)
                if p_size > 0:
                    p_surf = _psurf((p_size * 4, p_size * 4), pygame.SRCALPHA)
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
            eye_pulse = 1 + 0.3 * _sin(self.aura_timer * 8)

            # 눈 외곽 글로우
            eye_glow_size = int(20 * eye_pulse)
            eye_glow_surf = _psurf((eye_glow_size * 2, eye_glow_size * 2), pygame.SRCALPHA)
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
            description="심해의 촉수가 상대를 옥죄어 발을 묶는다",
            trigger=SkillTrigger.ON_COOLDOWN,
            cooldown=20.0,
            duration=4.0,  # 전체 스킬 지속시간 (이동 1초 + 둔화 3초)
            hero_id="kraken"
        )
        self.tentacles = []
        self.target_is_top = False
        self.caster_is_top = False
        self.phase = 'travel'  # 'travel' → 'wrap' → 'retract'
        self.travel_progress = 0  # 이동 진행도 (0~1)
        self.wrap_timer = 0  # 감싸기 지속 시간
        self.slow_applied = False  # 둔화 적용 여부
        self.slow_amount = 0.4  # 60% 감소 = 40%만 유지
        self.time = 0  # 애니메이션 시간

        # 되감기(retract) 페이즈 상태 (is_active=False 이후에도 지속)
        self.retracting = False
        self.retract_timer = 0.0
        self.retract_duration = 0.7  # 되감기 총 시간 (빠르게)
        self.retract_tentacles = []  # 되감기 촉수 정보
        self.retract_break_particles = []  # 끊어질 때 튀는 파편
        self.retract_slime_drips = []  # 점액 방울 낙하

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
            'break_flash': (120, 255, 220),       # 끊어질 때 섬광
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

        # 촉수 생성 - 크라켄의 다리 촉수(발)에서 시작
        self.tentacles = []

        # 방향 (상단이면 아래로, 하단이면 위로 뻗어나감)
        direction = 1 if caster_paddle.is_top else -1

        # 촉수 시작 위치: 크라켄의 다리 촉수 끝에서 발사
        # hero_paddles.py _draw_kraken 기준:
        #   hip_y = torso_y + 1.8*b, tentacle_positions = [-1.8, -1.1, -0.4, 0.4, 1.1, 1.8]
        #   base_x = cx + int(side * 0.4 * b)
        leg_positions = [-1.8, -1.1, -0.4, 0.4, 1.1, 1.8]
        hip_offset_y = int(1.8 * b)   # 엉덩이 위치 (torso 기준)
        leg_extend_y = int(1.2 * b)   # 다리 중간~끝 발사점

        tentacle_origins = []
        for side in leg_positions:
            tentacle_origins.append({
                'base_offset_x': int(side * 0.4 * b),
                'base_offset_y': hip_offset_y + leg_extend_y,
                'type': 'leg',
            })

        for i, origin in enumerate(tentacle_origins):
            # 약간의 랜덤 변동으로 자연스러움 추가
            offset_x = origin['base_offset_x'] + random.uniform(-2, 2)
            # 다리는 항상 torso 아래에 있으므로 direction 곱하지 않음
            # (hero_paddles.py에서 다리는 facing과 무관하게 항상 아래로 그려짐)
            offset_y = origin['base_offset_y'] + random.uniform(-1, 1)

            # 촉수마다 고유한 특성 (다리 촉수: 바깥쪽이 굵고 안쪽이 가늘다)
            leg_idx = abs(i - 2.5)  # 0.5(안쪽) ~ 2.5(바깥쪽)
            thickness_base = int(5 + leg_idx * 0.8)

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
                # 마법결계 면역 체크 - 도달 시점에 면역이면 촉수 튕겨냄
                _immunity_side = 'top' if self.target_is_top else 'bottom'
                if game_state.get(f'magic_immunity_{_immunity_side}', False):
                    self.is_active = False
                    self._end_effect(caster_paddle, target_paddle, ball, game_state)
                    # 패링 이펙트 이벤트 전달
                    if 'barrier_block_events' not in game_state:
                        game_state['barrier_block_events'] = []
                    game_state['barrier_block_events'].append({
                        'skill_korean_name': self.korean_name,
                        'caster_is_top': getattr(self, 'caster_is_top', True),
                        'caster_x': caster_paddle.x + getattr(caster_paddle, 'width', 80) / 2,
                        'caster_y': caster_paddle.y + getattr(caster_paddle, 'height', 10) / 2,
                        'target_x': target_paddle.x + getattr(target_paddle, 'width', 80) / 2,
                        'target_y': target_paddle.y + getattr(target_paddle, 'height', 10) / 2,
                    })
                    return

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
        self.slow_applied = False

        # 되감기 애니메이션 시작 (즉시 사라지지 않음)
        self._init_retract(caster_paddle, target_paddle)
        self.tentacles = []
        self.phase = 'travel'

    def _init_retract(self, caster_paddle, target_paddle):
        """되감기 애니메이션 초기화 - 촉수가 끊어지며 빠르게 되돌아감"""
        self.retracting = True
        self.retract_timer = 0.0

        b = getattr(self, 'b', 8)
        caster_cx, caster_torso_y, _, _ = self._get_hero_body_position(caster_paddle, b)
        target_cx, target_torso_y, _, _ = self._get_hero_body_position(target_paddle, b)
        direction = 1 if caster_paddle.is_top else -1

        self.retract_tentacles = []
        self.retract_break_particles = []
        self.retract_slime_drips = []

        for idx, t in enumerate(self.tentacles):
            start_x = t['start_x']
            start_y = t['start_y']
            target_x = t['target_x']
            target_y = t['target_y']

            # wrap 단계의 코일 경로에서 중간 끊김점 계산 (0.4~0.6 지점)
            break_t = random.uniform(0.35, 0.55)

            # 끊김점 위치: 시작~타겟 사이 break_t 지점
            mid_x = start_x + (target_x - start_x) * break_t
            mid_y = start_y + (target_y - start_y) * break_t
            # 물결 오프셋 추가
            mid_x += _sin(self.time * 3 + t['wave_offset']) * 15

            self.retract_tentacles.append({
                'start_x': start_x,
                'start_y': start_y,
                'break_x': mid_x,
                'break_y': mid_y,
                'target_x': target_x,
                'target_y': target_y,
                'offset_x': t['offset_x'],
                'offset_y': t['offset_y'],
                'thickness': t['thickness'],
                'wave_offset': t['wave_offset'],
                'wave_speed': t['wave_speed'],
                'biolum_phase': t['biolum_phase'],
                'retract_progress': 0.0,  # 0→1: 끊김점이 시작점으로 수축
                'break_angle': random.uniform(0, math.pi * 2),
                # 타겟 쪽 잔해 (끊어진 부분이 떨어짐)
                'remnant_x': mid_x,
                'remnant_y': mid_y,
                'remnant_vx': random.uniform(-40, 40),
                'remnant_vy': random.uniform(20, 80) * direction,
                'remnant_size': t['thickness'] * 1.5,
                'remnant_alpha': 220,
                'remnant_rotation': random.uniform(0, 360),
                'remnant_rot_speed': random.uniform(-200, 200),
                'sucker_count': t.get('sucker_count', 6),
                # 되감기 탄성 (스프링 효과용)
                'spring_overshoot': random.uniform(0.05, 0.12),
                'retract_delay': idx * 0.03,  # 촉수마다 약간의 시차
            })

            # 끊어질 때 파편/파티클 생성
            for _ in range(4):
                angle = random.uniform(0, math.pi * 2)
                speed = random.uniform(60, 180)
                self.retract_break_particles.append({
                    'x': mid_x + random.uniform(-5, 5),
                    'y': mid_y + random.uniform(-5, 5),
                    'vx': _cos(angle) * speed,
                    'vy': _sin(angle) * speed,
                    'size': random.uniform(2, 6),
                    'alpha': 255,
                    'life': random.uniform(0.3, 0.6),
                    'type': random.choice(['slime', 'glow', 'fragment']),
                    'rotation': random.uniform(0, 360),
                    'rot_speed': random.uniform(-300, 300),
                })

            # 점액 방울 (끊어진 부위에서 떨어짐)
            for _ in range(2):
                self.retract_slime_drips.append({
                    'x': mid_x + random.uniform(-8, 8),
                    'y': mid_y + random.uniform(-3, 3),
                    'vy': random.uniform(30, 80),
                    'size': random.uniform(3, 7),
                    'alpha': 200,
                    'stretch': 1.0,
                })

    def update(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        """오버라이드: 되감기 애니메이션을 is_active=False 이후에도 업데이트"""
        # 쿨타임 감소
        if self.current_cooldown > 0:
            self.current_cooldown -= dt
        if self.activation_flash_timer > 0:
            self.activation_flash_timer -= dt

        # 활성 효과 업데이트
        if self.is_active:
            self.active_timer -= dt
            self._update_active_effect(dt, caster_paddle, target_paddle, ball, game_state)
            if self.active_timer <= 0:
                self._end_effect(caster_paddle, target_paddle, ball, game_state)
                self.is_active = False

        # 되감기 애니메이션 (is_active=False 이후에도 계속)
        if self.retracting:
            self.retract_timer += dt
            self.time += dt  # 물결 애니메이션 유지
            progress = min(1.0, self.retract_timer / self.retract_duration)

            # 촉수 되감기 업데이트
            for rt in self.retract_tentacles:
                delay = rt.get('retract_delay', 0)
                if self.retract_timer < delay:
                    continue
                local_time = self.retract_timer - delay
                local_progress = min(1.0, local_time / (self.retract_duration - delay))
                # ease-in-out 이징 (빠르게 시작, 끝에서 탄성 바운스)
                if local_progress < 0.8:
                    # 빠른 수축 (ease-in)
                    t = local_progress / 0.8
                    rt['retract_progress'] = t * t * (3 - 2 * t)  # smoothstep
                else:
                    # 탄성 오버슈트 (끝에서 살짝 지나갔다가 복귀)
                    overshoot = rt.get('spring_overshoot', 0.08)
                    t = (local_progress - 0.8) / 0.2
                    base = 1.0
                    bounce = _sin(t * math.pi) * overshoot * (1 - t)
                    rt['retract_progress'] = base + bounce

                # 물결 업데이트
                rt['wave_offset'] += dt * rt['wave_speed']
                rt['biolum_phase'] += dt * 3

                # 잔해(타겟 쪽 끊어진 조각) 물리
                rt['remnant_vy'] += 120 * dt  # 중력
                rt['remnant_x'] += rt['remnant_vx'] * dt
                rt['remnant_y'] += rt['remnant_vy'] * dt
                rt['remnant_alpha'] = max(0, rt['remnant_alpha'] - dt * 350)
                rt['remnant_size'] = max(0, rt['remnant_size'] - dt * 4)
                rt['remnant_rotation'] += rt['remnant_rot_speed'] * dt

            # 파편 파티클 업데이트
            for bp in self.retract_break_particles:
                bp['life'] -= dt
                bp['vx'] *= 0.94
                bp['vy'] *= 0.94
                bp['vy'] += 80 * dt  # 약한 중력
                bp['x'] += bp['vx'] * dt
                bp['y'] += bp['vy'] * dt
                bp['alpha'] = max(0, bp['alpha'] - dt * 450)
                bp['size'] = max(0, bp['size'] - dt * 5)
                bp['rotation'] += bp['rot_speed'] * dt
            self.retract_break_particles = [
                bp for bp in self.retract_break_particles if bp['life'] > 0
            ]

            # 점액 방울 낙하
            for sd in self.retract_slime_drips:
                sd['vy'] += 200 * dt  # 중력
                sd['y'] += sd['vy'] * dt
                sd['alpha'] = max(0, sd['alpha'] - dt * 200)
                sd['stretch'] = min(3.0, sd['stretch'] + dt * 4)

            # 되감기 완료
            if self.retract_timer >= self.retract_duration + 0.2:
                self.retracting = False
                self.retract_tentacles = []
                self.retract_break_particles = []
                self.retract_slime_drips = []

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
        self.retracting = False
        self.retract_timer = 0.0
        self.retract_tentacles = []
        self.retract_break_particles = []
        self.retract_slime_drips = []
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
        pulse = (_sin(phase) + 1) * 0.5 * intensity
        if pulse < 0.3:
            return

        glow_size = int(6 + pulse * 4)
        glow_surf = _psurf((glow_size * 2, glow_size * 2), pygame.SRCALPHA)

        # 다층 글로우 효과
        for i in range(3):
            alpha = int((80 - i * 20) * pulse)
            radius = glow_size - i * 2
            if radius > 0 and alpha > 0:
                pygame.draw.circle(glow_surf, (*self.colors['biolum'], alpha),
                                 (glow_size, glow_size), radius)

        screen.blit(glow_surf, (int(x) - glow_size, int(y) - glow_size), special_flags=pygame.BLEND_ADD)

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        # 되감기 애니메이션 그리기
        if self.retracting:
            self._draw_retract(screen, caster_paddle)
            return

        if not self.is_active:
            return

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
                mid_wave = _sin(self.time * 3 + t['wave_offset']) * 30
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
                    wave_amp = 8 * _sin(seg_t * math.pi)  # 중간이 가장 강함
                    wave = _sin(seg_t * math.pi * 3 + t['wave_offset'] + self.time * 4) * wave_amp
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
                            f_angle = (finger - 1) * 0.4 + _sin(self.time * 5 + finger) * 0.2
                            f_len = int(8 + t['thickness'])
                            fx = end_x + int(_cos(f_angle + math.pi/2 * direction) * f_len)
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
                        wave_amp = 10 * _sin(local_t * math.pi)
                        wave = _sin(local_t * math.pi * 2 + t['wave_offset'] + self.time * 3) * wave_amp
                        x += wave
                    else:
                        # 후반부: 타겟 주위를 코일링
                        local_t = (seg_t - 0.5) * 2 * coil_progress

                        # 나선형 각도 계산
                        coil_angle = base_angle + local_t * coil_turns * math.pi * 2
                        # 반경이 점점 줄어듦 (조여드는 효과)
                        current_radius = wrap_radius * (1 - local_t * 0.4)
                        # 높이 변화 (나선형으로 위아래로 감쌈)
                        height_offset = _sin(local_t * coil_turns * math.pi * 2) * 15

                        x = target_x + current_radius * _cos(coil_angle)
                        y = target_y + current_radius * 0.5 * _sin(coil_angle) + height_offset

                        # 타겟이 움직이면 따라가는 미세한 지연
                        x += _sin(self.time * 4 + idx) * 3

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
            ring_pulse = (_sin(self.time * 5) + 1) * 0.5
            ring_radius = int(35 + ring_pulse * 10)

            # 다층 링 효과
            for i in range(3):
                ring_surf = _psurf((ring_radius * 2 + 20, ring_radius * 2 + 20), pygame.SRCALPHA)
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
                slime_dist = 25 + _sin(self.time * 3 + i) * 5
                slime_x = target_x + _cos(angle) * slime_dist
                slime_y = target_y + _sin(angle) * slime_dist * 0.6
                slime_size = int(3 + _sin(self.time * 4 + i * 0.5) * 2)

                slime_surf = _psurf((slime_size * 2 + 4, slime_size * 2 + 4), pygame.SRCALPHA)
                pygame.draw.circle(slime_surf, (*self.colors['slime'], 120),
                                 (slime_size + 2, slime_size + 2), slime_size)
                screen.blit(slime_surf, (int(slime_x) - slime_size - 2, int(slime_y) - slime_size - 2))

    def _draw_retract(self, screen, caster_paddle):
        """되감기 애니메이션: 촉수가 끊어지며 빠르게 시전자에게 되돌아감"""
        b = getattr(self, 'b', 8)
        caster_cx, caster_torso_y, _, _ = self._get_hero_body_position(caster_paddle, b)
        direction = 1 if caster_paddle.is_top else -1
        global_progress = min(1.0, self.retract_timer / self.retract_duration)

        # === 1. 잔해 (타겟 쪽 끊어진 촉수 조각들이 떨어짐) ===
        for rt in self.retract_tentacles:
            ra = int(max(0, min(255, rt['remnant_alpha'])))
            rs = max(1, int(rt['remnant_size']))
            if ra > 3 and rs > 1:
                rem_surf = _psurf((rs * 2 + 8, rs * 2 + 8), pygame.SRCALPHA)
                rc = rs + 4
                # 불규칙 형태 (회전하는 촉수 파편)
                rot_rad = math.radians(rt['remnant_rotation'])
                points = []
                for ai in range(0, 360, 50):
                    rad = math.radians(ai)
                    r = rs * (0.5 + 0.5 * _sin(rad * 2 + rt['break_angle']))
                    px = _cos(rad + rot_rad) * r
                    py = _sin(rad + rot_rad) * r
                    points.append((int(rc + px), int(rc + py)))
                if len(points) >= 3:
                    # 외곽
                    pygame.draw.polygon(rem_surf, (*self.colors['tentacle_core'], int(ra * 0.5)),
                                       points)
                    # 메인
                    pygame.draw.polygon(rem_surf, (*self.colors['tentacle_mid'], ra), points)
                screen.blit(rem_surf, (int(rt['remnant_x']) - rc, int(rt['remnant_y']) - rc))

                # 잔해에서 점액 흘림
                if ra > 80:
                    drip_len = int(rs * 0.5 * (1 - global_progress))
                    if drip_len > 1:
                        drip_a = int(ra * 0.4)
                        pygame.draw.line(screen, (*self.colors['slime'], drip_a),
                                        (int(rt['remnant_x']), int(rt['remnant_y'])),
                                        (int(rt['remnant_x']), int(rt['remnant_y']) + drip_len), 2)

        # === 2. 시전자 쪽 촉수 되감기 ===
        for rt in self.retract_tentacles:
            delay = rt.get('retract_delay', 0)
            if self.retract_timer < delay:
                # 아직 시작 안 함 - 전체 길이로 그림 (끊김점까지)
                retract_p = 0.0
            else:
                retract_p = rt['retract_progress']

            # 시작점은 항상 크라켄 현재 위치
            start_x = caster_cx + rt['offset_x']
            start_y = caster_torso_y + rt['offset_y']

            # 끊김점이 되감기 진행도에 따라 시작점으로 수축
            cur_break_x = start_x + (rt['break_x'] - start_x) * (1.0 - min(1.0, retract_p))
            cur_break_y = start_y + (rt['break_y'] - start_y) * (1.0 - min(1.0, retract_p))

            # 두 점이 너무 가까우면 안 그림
            dx = cur_break_x - start_x
            dy = cur_break_y - start_y
            dist = math.sqrt(dx * dx + dy * dy)
            if dist < 3:
                continue

            # 촉수 경로 (베지어 곡선 + 물결)
            ctrl1_x = start_x + rt['offset_x'] * 0.5
            ctrl1_y = start_y + direction * 25
            mid_wave = _sin(self.time * 4 + rt['wave_offset']) * 15 * (1 - retract_p)
            ctrl2_x = (start_x + cur_break_x) / 2 + mid_wave
            ctrl2_y = (start_y + cur_break_y) / 2

            points = []
            segments = max(8, int(24 * (1 - retract_p * 0.5)))
            for i in range(segments + 1):
                seg_t = i / segments
                x = self._cubic_bezier(seg_t, start_x, ctrl1_x, ctrl2_x, cur_break_x)
                y = self._cubic_bezier(seg_t, start_y, ctrl1_y, ctrl2_y, cur_break_y)
                # 물결 효과 (되감기 중에는 격렬하게 흔들림, 점점 감소)
                shake_intensity = 12 * (1 - retract_p * 0.8)
                wave = _sin(seg_t * math.pi * 4 + rt['wave_offset'] + self.time * 8) * shake_intensity * _sin(seg_t * math.pi)
                x += wave
                points.append((int(x), int(y)))

            if len(points) > 1:
                # 촉수 세그먼트 그리기 (3레이어: 외곽→본체→하이라이트)
                alpha_mod = 1.0 - retract_p * 0.3  # 되감기 끝에서 약간 투명
                for i in range(len(points) - 1):
                    seg_progress = i / max(1, len(points) - 1)
                    current_thickness = int(rt['thickness'] * (1.0 - seg_progress * 0.5))
                    current_thickness = max(2, current_thickness)
                    p1, p2 = points[i], points[i + 1]
                    # 외곽/그림자
                    ea = int(255 * alpha_mod)
                    pygame.draw.line(screen, (*self.colors['tentacle_core'], ea),
                                    p1, p2, current_thickness + 3)
                    # 본체
                    pygame.draw.line(screen, (*self.colors['tentacle_mid'], ea),
                                    p1, p2, current_thickness + 1)
                    # 하이라이트
                    pygame.draw.line(screen, (*self.colors['tentacle_outer'], int(ea * 0.8)),
                                    p1, p2, max(1, current_thickness - 1))

                # 빨판 (되감기 중에도 보이되, 진행에 따라 감소)
                if retract_p < 0.7:
                    sucker_interval = max(4, len(points) // max(1, rt['sucker_count'] // 2))
                    for j in range(sucker_interval, len(points) - 1, sucker_interval):
                        px, py = points[j]
                        sucker_size = int(rt['thickness'] * 0.35 * (1 - retract_p))
                        if sucker_size > 1:
                            self._draw_sucker(screen, px, py, sucker_size)

                # 끊어진 끝부분 - 불규칙한 끝단 + 점액 흘림 + 발광
                if retract_p < 0.9 and len(points) > 0:
                    end_x, end_y = points[-1]
                    end_alpha = int(200 * (1 - retract_p))

                    # 끊어진 불규칙 끝 (갈라진 촉수 끝)
                    num_frays = 4
                    for fi in range(num_frays):
                        f_angle = (fi / num_frays) * math.pi * 2 + self.time * 3 + rt['break_angle']
                        f_len = int((6 + rt['thickness'] * 0.5) * (1 - retract_p))
                        fx = end_x + int(_cos(f_angle) * f_len)
                        fy = end_y + int(_sin(f_angle) * f_len)
                        fw = max(1, int(rt['thickness'] * 0.25 * (1 - retract_p)))
                        pygame.draw.line(screen, (*self.colors['tentacle_outer'], end_alpha),
                                        (int(end_x), int(end_y)), (fx, fy), fw)

                    # 점액 물방울 (끝에서 떨어지는 효과)
                    if retract_p < 0.5:
                        drip_length = int(8 * (1 - retract_p * 2))
                        drip_a = int(120 * (1 - retract_p * 2))
                        if drip_length > 1 and drip_a > 3:
                            pygame.draw.line(screen, (*self.colors['slime'], drip_a),
                                            (int(end_x), int(end_y)),
                                            (int(end_x), int(end_y) + drip_length), 2)
                            # 방울 끝 물방울
                            pygame.draw.circle(screen, (*self.colors['slime'], drip_a),
                                              (int(end_x), int(end_y) + drip_length + 2), 2)

                    # 끊김점 발광 펄스
                    glow_a = int(end_alpha * 0.4 * (0.5 + 0.5 * _sin(self.time * 10 + rt['break_angle'])))
                    if glow_a > 3:
                        glow_r = max(2, int(8 * (1 - retract_p)))
                        glow_surf = _psurf((glow_r * 2 + 4, glow_r * 2 + 4), pygame.SRCALPHA)
                        gc = glow_r + 2
                        pygame.draw.circle(glow_surf, (*self.colors['break_flash'], glow_a),
                                          (gc, gc), glow_r)
                        pygame.draw.circle(glow_surf, (*self.colors['biolum'], int(glow_a * 0.6)),
                                          (gc, gc), max(1, glow_r // 2))
                        screen.blit(glow_surf, (int(end_x) - gc, int(end_y) - gc))

        # === 3. 끊김 파편 파티클 ===
        for bp in self.retract_break_particles:
            ba = int(max(0, min(255, bp['alpha'])))
            bs = max(1, int(bp['size']))
            if ba < 3 or bs < 1:
                continue
            bp_surf = _psurf((bs * 2 + 4, bs * 2 + 4), pygame.SRCALPHA)
            bc = bs + 2

            if bp['type'] == 'glow':
                # 발광 파편
                pygame.draw.circle(bp_surf, (*self.colors['biolum'], ba), (bc, bc), bs)
                pygame.draw.circle(bp_surf, (*self.colors['break_flash'], int(ba * 0.5)),
                                  (bc, bc), max(1, bs + 1))
            elif bp['type'] == 'slime':
                # 점액 방울
                pygame.draw.circle(bp_surf, (*self.colors['slime'], ba), (bc, bc), bs)
            else:
                # 촉수 파편
                rot_rad = math.radians(bp['rotation'])
                pts = []
                for ai in range(0, 360, 60):
                    rad = math.radians(ai)
                    r = bs * (0.5 + 0.5 * _sin(rad * 2))
                    pts.append((int(bc + _cos(rad + rot_rad) * r),
                               int(bc + _sin(rad + rot_rad) * r)))
                if len(pts) >= 3:
                    pygame.draw.polygon(bp_surf, (*self.colors['tentacle_mid'], ba), pts)
            screen.blit(bp_surf, (int(bp['x']) - bc, int(bp['y']) - bc))

        # === 4. 점액 방울 낙하 ===
        for sd in self.retract_slime_drips:
            sa = int(max(0, min(255, sd['alpha'])))
            if sa < 3:
                continue
            ss = max(1, int(sd['size']))
            stretch = sd.get('stretch', 1.0)
            # 세로로 늘어나는 물방울
            sw = max(1, int(ss * 2 + 4))
            sh = max(1, int((ss * 2 + 4) * stretch))
            sd_surf = _psurf((sw, sh), pygame.SRCALPHA)
            scx, scy = sw // 2, sh // 2
            # 늘어진 타원형 물방울
            pygame.draw.ellipse(sd_surf, (*self.colors['slime'], sa),
                               (scx - ss, max(0, scy - int(ss * stretch)),
                                ss * 2, int(ss * 2 * stretch)))
            # 하이라이트
            if ss > 2:
                hl_a = int(sa * 0.4)
                pygame.draw.ellipse(sd_surf, (*self.colors['tentacle_highlight'], hl_a),
                                   (scx - ss // 2, max(0, scy - int(ss * stretch * 0.6)),
                                    ss, int(ss * stretch * 0.5)))
            screen.blit(sd_surf, (int(sd['x']) - scx, int(sd['y']) - scy))

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
    """심해의 먹물 - 크라켄이 먹물을 발사하여 상대방에게 혼란을 준다 [울트라 고퀄리티]"""
    def __init__(self):
        super().__init__(
            skill_id="abyss_ink",
            name="Abyss Ink",
            korean_name="심해의 먹물",
            description="칠흑의 먹물이 상대의 시야를 삼키고 혼란에 빠뜨린다",
            trigger=SkillTrigger.ON_BALL_HIT,
            cooldown=18.0,
            duration=3.0,
            hero_id="kraken"
        )
        self.ink_blobs = []
        self.target_is_top = False
        self.caster_is_top = False
        self._ink_comp_surf = None  # 합성 서피스 (캐릭터 가림 방지용)

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
        self._ribbon_trail = []  # 리본 트레일 (연속 잉크 줄기)
        self._proj_tendrils = []  # 발사체 주위 소형 촉수

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
        self.splash_shockwave = 0.0  # 충격파 반경
        self.splash_splatters = []  # 잉크 튀김 자국
        self.active_duration = 3.0
        self.active_timer = 0

        # 고퀄리티 먹물 레이어
        self.ink_bubbles = []       # 기포
        self.ink_tendrils = []      # 먹물 가지/촉수
        self.ink_shimmer_time = 0.0  # 표면 일렁임 타이머
        self.ink_currents = []      # 먹물 내부 흐름
        self.ink_mist = []          # 떠오르는 안개/연기
        self.ink_eye_phase = 0.0    # 심해의 눈 (혼란 상징) 페이즈
        self.ink_caustics = []      # 수면 빛 반사 패턴
        self.ink_vortex_angle = 0.0 # 소용돌이 회전

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
        self.dissolve_vortex_particles = []  # 소용돌이 흡수 파티클
        self.dissolve_flash_alpha = 0  # 최종 섬광

        # 전환 오버랩 (자연스러운 페이즈 연결)
        self.dissolve_overlap_duration = 0.5   # active→dissolve 크로스페이드 시간
        self._active_fade_alpha = 1.0          # 오버랩 중 active 레이어 페이드 비율
        self._pool_fade_in = 1.0               # splash→active 페이드인 진행도
        self._pool_fade_in_duration = 0.35     # 페이드인 소요 시간

        # 색상 팔레트 (심해 테마 - 확장)
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
            # 확장 팔레트
            'biolum_cyan': (60, 200, 180),     # 생물발광 시안
            'biolum_green': (40, 180, 120),    # 생물발광 그린
            'deep_black': (10, 4, 25),         # 심해 흑색
            'eye_iris': (180, 40, 200),        # 눈 홍채
            'eye_pupil': (8, 2, 18),           # 눈 동공
            'eye_glow': (200, 80, 255),        # 눈 발광
            'vortex_edge': (110, 60, 180),     # 소용돌이 가장자리
            'mist_purple': (60, 30, 100),      # 안개 보라
            'caustic_light': (120, 90, 180),   # 수면 빛
            'ribbon_trail': (55, 25, 95),      # 리본 트레일
        }

    def _init_projectile_particles(self):
        """발사체 구성 파티클 미리 생성 (매 프레임 랜덤 방지)"""
        self._proj_blobs = []
        for _ in range(12):  # 12개로 증가
            self._proj_blobs.append({
                'offset_x': random.uniform(-14, 14),
                'offset_y': random.uniform(-14, 14),
                'size': random.uniform(6, 18),
                'phase': random.uniform(0, math.pi * 2),
                'speed': random.uniform(1.5, 3.5),
                'layer': random.choice(['deep', 'mid', 'outer']),
            })
        self._trail_particles = []
        self._ribbon_trail = []
        # 발사체 주위 소형 촉수 (3~4개)
        self._proj_tendrils = []
        for _ in range(4):
            self._proj_tendrils.append({
                'angle': random.uniform(0, math.pi * 2),
                'length': random.uniform(20, 40),
                'speed': random.uniform(2.0, 4.0),
                'phase': random.uniform(0, math.pi * 2),
                'width': random.uniform(2, 5),
            })

    def _init_splash_droplets(self):
        """스플래시 시 튀는 방울 미리 생성"""
        self.splash_droplets = []
        for _ in range(24):  # 24개로 증가
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(100, 450)
            self.splash_droplets.append({
                'angle': angle,
                'speed': speed,
                'x': 0.0, 'y': 0.0,
                'size': random.uniform(2, 11),
                'alpha': 255,
                'gravity': random.uniform(50, 150),
                'vx': _cos(angle) * speed,
                'vy': _sin(angle) * speed,
                'trail': [],  # 각 방울의 잔상 트레일
            })
        # 충격파 초기화
        self.splash_shockwave = 0.0
        # 잉크 튀김 자국 (바닥에 남는 얼룩)
        self.splash_splatters = []
        for _ in range(8):
            angle = random.uniform(0, math.pi * 2)
            dist = random.uniform(0.3, 0.9)
            self.splash_splatters.append({
                'x': _cos(angle) * self.splash_max_radius * self.splash_width_scale * dist,
                'y': _sin(angle) * self.splash_max_radius * dist,
                'size': random.uniform(10, 30),
                'alpha': 0,  # 점점 나타남
                'shape_seed': random.uniform(0, math.pi * 2),
                'target_alpha': random.randint(140, 220),
            })

    def _init_ink_pool(self):
        """active 단계 먹물 웅덩이 초기화"""
        self.ink_blobs = []
        # 메인 블롭들 (큰 먹물 덩어리) - 더 많고 다양
        for _ in range(14):
            angle = random.uniform(0, math.pi * 2)
            dist = random.uniform(0, 0.75)
            self.ink_blobs.append({
                'x': self.splash_center_x + _cos(angle) * self.splash_max_radius * self.splash_width_scale * dist,
                'y': self.splash_center_y + _sin(angle) * self.splash_max_radius * dist,
                'size': random.uniform(35, 90),
                'alpha': 220,
                'wobble': random.uniform(0, math.pi * 2),
                'wobble_speed': random.uniform(1.2, 2.5),
                'shape_seed': random.uniform(0, math.pi * 2),
                'pulse_phase': random.uniform(0, math.pi * 2),
                'depth': random.choice(['deep', 'mid', 'surface']),
            })
        # 작은 입자들
        for _ in range(16):
            angle = random.uniform(0, math.pi * 2)
            dist = random.uniform(0.3, 1.0)
            self.ink_blobs.append({
                'x': self.splash_center_x + _cos(angle) * self.splash_max_radius * self.splash_width_scale * dist,
                'y': self.splash_center_y + _sin(angle) * self.splash_max_radius * dist,
                'size': random.uniform(8, 25),
                'alpha': 180,
                'wobble': random.uniform(0, math.pi * 2),
                'wobble_speed': random.uniform(2.0, 4.0),
                'shape_seed': random.uniform(0, math.pi * 2),
                'pulse_phase': random.uniform(0, math.pi * 2),
                'depth': 'surface',
            })

        # 기포 - 더 많고 상세
        self.ink_bubbles = []
        for _ in range(14):
            angle = random.uniform(0, math.pi * 2)
            dist = random.uniform(0, 0.7)
            self.ink_bubbles.append({
                'x': self.splash_center_x + _cos(angle) * self.splash_max_radius * self.splash_width_scale * dist,
                'y': self.splash_center_y + _sin(angle) * self.splash_max_radius * dist,
                'size': random.uniform(2, 8),
                'life': random.uniform(0.5, 2.0),
                'max_life': random.uniform(0.5, 2.0),
                'rise_speed': random.uniform(12, 40),
                'drift_x': random.uniform(-12, 12),
                'wobble_phase': random.uniform(0, math.pi * 2),
            })

        # 먹물 촉수/가지 (가장자리에서 뻗어나감) - 더 상세
        self.ink_tendrils = []
        for _ in range(8):
            angle = random.uniform(0, math.pi * 2)
            self.ink_tendrils.append({
                'angle': angle,
                'length': random.uniform(0.7, 1.2),
                'width': random.uniform(5, 16),
                'wobble': random.uniform(0, math.pi * 2),
                'wobble_speed': random.uniform(1.0, 2.5),
                'segments': random.randint(5, 9),
                'tip_glow': random.uniform(0, math.pi * 2),
                'branch_count': random.randint(0, 2),
            })

        # 내부 흐름 (소용돌이 스트림)
        self.ink_currents = []
        for _ in range(6):
            self.ink_currents.append({
                'start_angle': random.uniform(0, math.pi * 2),
                'arc_length': random.uniform(0.8, 2.5),
                'radius': random.uniform(0.2, 0.7),
                'width': random.uniform(2, 5),
                'speed': random.uniform(0.5, 1.5),
                'phase': random.uniform(0, math.pi * 2),
                'alpha': random.randint(40, 90),
            })

        # 수면 안개
        self.ink_mist = []
        for _ in range(10):
            angle = random.uniform(0, math.pi * 2)
            dist = random.uniform(0.2, 0.8)
            self.ink_mist.append({
                'x': self.splash_center_x + _cos(angle) * self.splash_max_radius * self.splash_width_scale * dist,
                'y': self.splash_center_y + _sin(angle) * self.splash_max_radius * dist,
                'size': random.uniform(20, 50),
                'alpha': random.uniform(20, 50),
                'drift_x': random.uniform(-8, 8),
                'drift_y': random.uniform(-15, -5),
                'expand': random.uniform(3, 8),
                'life': random.uniform(1.0, 2.5),
                'max_life': random.uniform(1.0, 2.5),
            })

        # 수면 코스틱 (빛 반사 무늬)
        self.ink_caustics = []
        for _ in range(5):
            self.ink_caustics.append({
                'angle': random.uniform(0, math.pi * 2),
                'dist': random.uniform(0.1, 0.5),
                'size': random.uniform(15, 40),
                'speed': random.uniform(0.3, 0.8),
                'phase': random.uniform(0, math.pi * 2),
            })

        self.ink_eye_phase = 0.0
        self.ink_vortex_angle = 0.0
        self._pool_fade_in = 0.0  # 페이드인 시작

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
        self.ink_currents = []
        self.ink_mist = []
        self.ink_caustics = []
        self.ink_shimmer_time = 0.0
        self.ink_eye_phase = 0.0
        self.ink_vortex_angle = 0.0
        self.splash_radius = 0
        self.splash_timer = 0
        self.splash_droplets = []
        self.splash_splatters = []
        self.splash_shockwave = 0.0
        self.dissolving = False
        self.dissolve_timer = 0.0
        self.dissolve_fragments = []
        self.dissolve_wisps = []
        self.dissolve_vortex_particles = []
        self.dissolve_flash_alpha = 0
        self._active_fade_alpha = 1.0
        self._pool_fade_in = 1.0

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
            self._proj_rotation += dt * 220  # 더 빠른 회전

            # 발사체 파티클 유기적 움직임
            for pb in self._proj_blobs:
                pb['phase'] += dt * pb['speed']

            # 발사체 촉수 업데이트
            for pt in self._proj_tendrils:
                pt['phase'] += dt * pt['speed']

            # 트레일 파티클 생성 (더 풍부)
            if self.projectile_progress > 0.03:
                cur_x = self.projectile_x + (self.projectile_target_x - self.projectile_x) * self.projectile_progress
                cur_y = self.projectile_y + (self.projectile_target_y - self.projectile_y) * self.projectile_progress
                # 기본 트레일
                for _ in range(2):
                    self._trail_particles.append({
                        'x': cur_x + random.uniform(-10, 10),
                        'y': cur_y + random.uniform(-10, 10),
                        'size': random.uniform(3, 12),
                        'alpha': random.uniform(150, 230),
                        'life': random.uniform(0.3, 0.6),
                        'layer': random.choice(['deep', 'glow']),
                    })
                # 리본 트레일 (포인트 추가)
                self._ribbon_trail.append({
                    'x': cur_x, 'y': cur_y,
                    'alpha': 200,
                    'width': random.uniform(6, 14),
                })

            # 트레일 업데이트
            for tp in self._trail_particles:
                tp['life'] -= dt
                tp['alpha'] = max(0, tp['alpha'] - dt * 400)
                tp['size'] = max(0, tp['size'] - dt * 10)
            self._trail_particles = [tp for tp in self._trail_particles if tp['life'] > 0]

            # 리본 트레일 페이드
            for rp in self._ribbon_trail:
                rp['alpha'] = max(0, rp['alpha'] - dt * 250)
                rp['width'] = max(0, rp['width'] - dt * 8)
            self._ribbon_trail = [rp for rp in self._ribbon_trail if rp['alpha'] > 3]

            if self.projectile_progress >= 1.0:
                self.phase = 'splash'
                self.splash_center_x = self.projectile_target_x
                self.splash_center_y = self.projectile_target_y
                self.splash_radius = 20
                self.splash_timer = 0
                self._init_splash_droplets()
                self._trail_particles = []
                self._ribbon_trail = []
                self._proj_tendrils = []
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

            # 충격파 팽창
            self.splash_shockwave += dt * 600
            if self.splash_shockwave > self.splash_max_radius * 2.5:
                self.splash_shockwave = self.splash_max_radius * 2.5

            # 튀는 방울 물리 업데이트 (잔상 트레일 포함)
            for drop in self.splash_droplets:
                drop['vx'] *= 0.97
                drop['vy'] += drop['gravity'] * dt
                drop['x'] += drop['vx'] * dt
                drop['y'] += drop['vy'] * dt
                drop['alpha'] = max(0, drop['alpha'] - dt * 250)
                drop['size'] = max(0, drop['size'] - dt * 2.5)
                # 방울 잔상
                if drop['alpha'] > 30 and drop['size'] > 1:
                    drop['trail'].append({'x': drop['x'], 'y': drop['y'],
                                          'alpha': drop['alpha'] * 0.4, 'size': drop['size'] * 0.6})
                    if len(drop['trail']) > 5:
                        drop['trail'].pop(0)

            # 잉크 튀김 자국 페이드 인
            for sp in self.splash_splatters:
                if sp['alpha'] < sp['target_alpha']:
                    sp['alpha'] = min(sp['target_alpha'], sp['alpha'] + dt * 500)

            if self.splash_timer >= self.splash_duration:
                self.phase = 'active'
                self._init_ink_pool()

        elif self.phase == 'active':
            self.ink_shimmer_time += dt
            self.ink_eye_phase += dt * 1.2
            self.ink_vortex_angle += dt * 30  # 소용돌이 회전

            # splash→active 페이드인
            if self._pool_fade_in < 1.0:
                self._pool_fade_in = min(1.0, self._pool_fade_in + dt / self._pool_fade_in_duration)

            # 먹물 블롭 애니메이션
            for blob in self.ink_blobs:
                blob['wobble'] += dt * blob['wobble_speed']
                blob['pulse_phase'] += dt * 1.5
                blob['size'] += dt * 1.2

            # 기포 업데이트
            for bubble in self.ink_bubbles:
                bubble['y'] -= bubble['rise_speed'] * dt
                bubble['x'] += bubble['drift_x'] * dt + _sin(bubble.get('wobble_phase', 0)) * dt * 5
                bubble['wobble_phase'] = bubble.get('wobble_phase', 0) + dt * 3
                bubble['life'] -= dt
                if bubble['life'] <= 0:
                    angle = random.uniform(0, math.pi * 2)
                    dist = random.uniform(0, 0.6)
                    bubble['x'] = self.splash_center_x + _cos(angle) * self.splash_max_radius * self.splash_width_scale * dist
                    bubble['y'] = self.splash_center_y + _sin(angle) * self.splash_max_radius * dist
                    bubble['size'] = random.uniform(2, 8)
                    bubble['life'] = bubble['max_life']
                    bubble['drift_x'] = random.uniform(-12, 12)

            # 촉수 웨이브
            for tendril in self.ink_tendrils:
                tendril['wobble'] += dt * tendril['wobble_speed']
                tendril['tip_glow'] = tendril.get('tip_glow', 0) + dt * 2.5

            # 내부 흐름 업데이트
            for current in self.ink_currents:
                current['phase'] += dt * current['speed']

            # 안개 업데이트
            for mist in self.ink_mist:
                mist['x'] += mist['drift_x'] * dt
                mist['y'] += mist['drift_y'] * dt
                mist['size'] += mist['expand'] * dt
                mist['life'] -= dt
                if mist['life'] <= 0:
                    angle = random.uniform(0, math.pi * 2)
                    dist = random.uniform(0.2, 0.8)
                    mist['x'] = self.splash_center_x + _cos(angle) * self.splash_max_radius * self.splash_width_scale * dist
                    mist['y'] = self.splash_center_y + _sin(angle) * self.splash_max_radius * dist
                    mist['size'] = random.uniform(20, 50)
                    mist['alpha'] = random.uniform(20, 50)
                    mist['life'] = mist['max_life']
                    mist['drift_x'] = random.uniform(-8, 8)
                    mist['drift_y'] = random.uniform(-15, -5)

            # 코스틱 업데이트
            for caustic in self.ink_caustics:
                caustic['phase'] += dt * caustic['speed']

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
        self.dissolve_flash_alpha = 100  # 초기 섬광 (부드러운 전환용)
        self._init_dissolve()

        # 게임 로직 상태만 초기화
        self.confusion_applied = False
        self.confusion_timer = 0
        self.splash_radius = 0

    def _init_dissolve(self):
        """분해 파편 및 연기 초기화 - 울트라 고퀄리티"""
        self.dissolve_fragments = []
        # 먹물 블롭들을 분해 파편으로 변환 (더 많은 파편)
        for blob in self.ink_blobs:
            if blob['alpha'] > 5:
                num_frags = random.randint(3, 6)
                for _ in range(num_frags):
                    angle = random.uniform(0, math.pi * 2)
                    speed = random.uniform(20, 80)
                    self.dissolve_fragments.append({
                        'x': blob['x'] + random.uniform(-10, 10),
                        'y': blob['y'] + random.uniform(-10, 10),
                        'vx': _cos(angle) * speed,
                        'vy': _sin(angle) * speed - random.uniform(10, 40),
                        'size': blob['size'] / num_frags * random.uniform(0.5, 1.2),
                        'alpha': min(255, blob['alpha']),
                        'rotation': random.uniform(0, 360),
                        'rot_speed': random.uniform(-180, 180),
                        'shape_seed': random.uniform(0, math.pi * 2),
                        'shrink_rate': random.uniform(0.4, 0.8),
                        'glow': random.random() < 0.3,  # 30% 확률로 발광 파편
                    })

        # 증발 연기 생성 (더 풍부)
        self.dissolve_wisps = []
        for _ in range(18):
            angle = random.uniform(0, math.pi * 2)
            dist = random.uniform(0, 0.8)
            wx = self.splash_center_x + _cos(angle) * self.splash_max_radius * self.splash_width_scale * dist
            wy = self.splash_center_y + _sin(angle) * self.splash_max_radius * dist
            self.dissolve_wisps.append({
                'x': wx,
                'y': wy,
                'size': random.uniform(15, 50),
                'alpha': random.uniform(120, 220),
                'rise_speed': random.uniform(25, 90),
                'drift_x': random.uniform(-25, 25),
                'expand_rate': random.uniform(8, 25),
                'delay': random.uniform(0, 0.5),
                'color_shift': random.uniform(0, 1),  # 색상 변이 (보라~시안)
            })

        # 소용돌이 흡수 파티클 (중심으로 빨려드는 효과)
        self.dissolve_vortex_particles = []
        for _ in range(20):
            angle = random.uniform(0, math.pi * 2)
            dist = random.uniform(0.4, 1.0)
            self.dissolve_vortex_particles.append({
                'angle': angle,
                'dist': dist * self.splash_max_radius * self.splash_width_scale,
                'speed': random.uniform(60, 150),
                'size': random.uniform(3, 10),
                'alpha': random.uniform(100, 200),
                'spin_speed': random.uniform(100, 250),
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
                'glow': True,
            })

        # active 컴포넌트는 오버랩 기간 동안 유지 (자연스러운 전환)
        # → update()의 dissolving 섹션에서 오버랩 종료 후 정리
        self._active_fade_alpha = 1.0

    def update(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        """오버라이드: 분해 애니메이션을 is_active=False 이후에도 업데이트"""
        # 쿨타임 감소
        if self.current_cooldown > 0:
            self.current_cooldown -= dt
        if self.activation_flash_timer > 0:
            self.activation_flash_timer -= dt

        # 활성 효과 업데이트
        if self.is_active:
            # travel/splash 단계에서는 active_timer를 감소시키지 않음
            # → 'active' 단계(먹물 웅덩이 + 혼란)에 duration 3.0초 전부 할당
            if self.phase == 'active':
                self.active_timer -= dt
            self._update_active_effect(dt, caster_paddle, target_paddle, ball, game_state)
            if self.active_timer <= 0 and self.phase == 'active':
                self._end_effect(caster_paddle, target_paddle, ball, game_state)
                self.is_active = False

        # 분해 애니메이션 (is_active=False 이후에도 계속)
        if self.dissolving:
            self.dissolve_timer += dt

            # 섬광 페이드아웃
            self.dissolve_flash_alpha = max(0, self.dissolve_flash_alpha - dt * 300)

            # 오버랩 기간: active 레이어 페이드아웃 + 애니메이션 유지
            if self.dissolve_timer < self.dissolve_overlap_duration:
                overlap_t = self.dissolve_timer / self.dissolve_overlap_duration
                self._active_fade_alpha = 1.0 - overlap_t
                # active 레이어 애니메이션 계속 (정지 방지)
                self.ink_shimmer_time += dt
                self.ink_vortex_angle += dt * 20
                for blob in self.ink_blobs:
                    blob['wobble'] += dt * blob['wobble_speed']
                    blob['pulse_phase'] += dt * 1.5
                for bubble in self.ink_bubbles:
                    bubble['y'] -= bubble['rise_speed'] * dt * 0.5
                    bubble['life'] -= dt * 2
                for tendril in self.ink_tendrils:
                    tendril['wobble'] += dt * tendril['wobble_speed']
                for mist in self.ink_mist:
                    mist['life'] -= dt * 2
                    mist['y'] += mist['drift_y'] * dt
            elif self.ink_blobs:
                # 오버랩 종료: active 컴포넌트 정리
                self.ink_blobs = []
                self.ink_bubbles = []
                self.ink_tendrils = []
                self.ink_currents = []
                self.ink_mist = []
                self.ink_caustics = []
                self._active_fade_alpha = 0.0

            # 파편 업데이트
            progress = min(1.0, self.dissolve_timer / self.dissolve_duration)
            for frag in self.dissolve_fragments:
                frag['vx'] *= 0.95
                frag['vy'] *= 0.95
                frag['vy'] -= 12 * dt  # 더 강한 상승
                frag['x'] += frag['vx'] * dt
                frag['y'] += frag['vy'] * dt
                frag['rotation'] += frag['rot_speed'] * dt
                frag['alpha'] = max(0, frag['alpha'] * (1 - progress * 1.3))
                frag['size'] = max(0, frag['size'] - frag['shrink_rate'] * dt * frag['size'])

            # 소용돌이 파티클 (중심으로 수렴)
            for vp in self.dissolve_vortex_particles:
                vp['angle'] += vp['spin_speed'] * dt * (1 + progress * 2)
                vp['dist'] = max(0, vp['dist'] - vp['speed'] * dt * (0.5 + progress))
                vp['alpha'] = max(0, vp['alpha'] * (1 - progress * 0.8))
                vp['size'] = max(0, vp['size'] * (1 - dt * 0.5))

            # 연기 업데이트
            for wisp in self.dissolve_wisps:
                if self.dissolve_timer >= wisp['delay']:
                    active_time = self.dissolve_timer - wisp['delay']
                    wisp['y'] -= wisp['rise_speed'] * dt
                    wisp['x'] += wisp['drift_x'] * dt
                    wisp['size'] += wisp['expand_rate'] * dt
                    fade_progress = min(1.0, active_time / (self.dissolve_duration - wisp['delay']))
                    wisp['alpha'] = max(0, wisp['alpha'] * (1 - fade_progress ** 1.5))

            # 분해 완료
            if self.dissolve_timer >= self.dissolve_duration:
                self.dissolving = False
                self.dissolve_fragments = []
                self.dissolve_wisps = []
                self.dissolve_vortex_particles = []
                # active 잔여 컴포넌트 확실히 정리
                self.ink_blobs = []
                self.ink_bubbles = []
                self.ink_tendrils = []
                self.ink_currents = []
                self.ink_mist = []
                self.ink_caustics = []
                self._active_fade_alpha = 0.0
                self.phase = 'travel'
                self.projectile_progress = 0.0

    # 먹물 합성 서피스 최대 불투명도 (캐릭터/소환물 가림 방지)
    _INK_MAX_OPACITY = 170

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        # 분해 애니메이션 그리기
        if self.dissolving:
            # 오버랩 기간: 페이드아웃되는 active 레이어를 dissolve 아래에 블렌딩
            if self._active_fade_alpha > 0.02 and self.ink_blobs:
                if self._ink_comp_surf is None or self._ink_comp_surf.get_size() != screen.get_size():
                    self._ink_comp_surf = pygame.Surface(screen.get_size(), pygame.SRCALPHA)
                else:
                    self._ink_comp_surf.fill((0, 0, 0, 0))
                self._draw_active(self._ink_comp_surf)
                fade_alpha = max(0, int(self._INK_MAX_OPACITY * self._active_fade_alpha))
                self._ink_comp_surf.set_alpha(fade_alpha)
                screen.blit(self._ink_comp_surf, (0, 0))
            self._draw_dissolve(screen)
            return

        if not self.is_active:
            return

        if self.phase == 'travel':
            self._draw_travel(screen)
        elif self.phase in ('splash', 'active'):
            # 합성 서피스에 먹물을 그린 뒤 최대 불투명도를 제한하여
            # 아래에 그려진 캐릭터/소환물이 보이도록 함
            if self._ink_comp_surf is None or self._ink_comp_surf.get_size() != screen.get_size():
                self._ink_comp_surf = pygame.Surface(screen.get_size(), pygame.SRCALPHA)
            else:
                self._ink_comp_surf.fill((0, 0, 0, 0))
            if self.phase == 'splash':
                self._draw_splash(self._ink_comp_surf)
            else:
                self._draw_active(self._ink_comp_surf)
            # splash→active 페이드인 적용
            if self.phase == 'active' and self._pool_fade_in < 1.0:
                alpha = max(0, int(self._INK_MAX_OPACITY * self._pool_fade_in))
            else:
                alpha = self._INK_MAX_OPACITY
            self._ink_comp_surf.set_alpha(alpha)
            screen.blit(self._ink_comp_surf, (0, 0))

    def _draw_travel(self, screen):
        """1단계: 울트라 고퀄리티 발사체 - 소용돌이 먹물 탄환"""
        progress = min(1.0, self.projectile_progress)
        current_x = self.projectile_x + (self.projectile_target_x - self.projectile_x) * progress
        current_y = self.projectile_y + (self.projectile_target_y - self.projectile_y) * progress

        # --- 리본 트레일 (연속 잉크 줄기) ---
        if len(self._ribbon_trail) >= 2:
            for i in range(1, len(self._ribbon_trail)):
                rp = self._ribbon_trail[i]
                pp = self._ribbon_trail[i - 1]
                a = int(max(0, min(255, rp['alpha'])))
                w = max(1, int(rp['width']))
                if a > 3 and w > 0:
                    # 그라데이션 리본 - 외곽 글로우 + 코어
                    surf_w = abs(int(rp['x'] - pp['x'])) + w * 2 + 10
                    surf_h = abs(int(rp['y'] - pp['y'])) + w * 2 + 10
                    if surf_w > 1 and surf_h > 1:
                        rs = _psurf((surf_w, surf_h), pygame.SRCALPHA)
                        ox = w + 5 - min(0, int(rp['x'] - pp['x']))
                        oy = w + 5 - min(0, int(rp['y'] - pp['y']))
                        p1 = (ox + max(0, int(pp['x'] - min(pp['x'], rp['x']))),
                              oy + max(0, int(pp['y'] - min(pp['y'], rp['y']))))
                        p2 = (ox + max(0, int(rp['x'] - min(pp['x'], rp['x']))),
                              oy + max(0, int(rp['y'] - min(pp['y'], rp['y']))))
                        # 외곽 글로우
                        pygame.draw.line(rs, (*self.colors['ink_outer'], int(a * 0.3)),
                                        p1, p2, w + 4)
                        # 코어
                        pygame.draw.line(rs, (*self.colors['ribbon_trail'], a),
                                        p1, p2, max(1, w))
                        # 내부 빛
                        pygame.draw.line(rs, (*self.colors['ink_glow'], int(a * 0.4)),
                                        p1, p2, max(1, w // 2))
                        screen.blit(rs, (int(min(pp['x'], rp['x'])) - w - 5,
                                        int(min(pp['y'], rp['y'])) - w - 5))

        # --- 트레일 파티클 ---
        for tp in self._trail_particles:
            if tp['alpha'] > 5 and tp['size'] > 0.5:
                s = int(tp['size'])
                ts = _psurf((s * 2 + 6, s * 2 + 6), pygame.SRCALPHA)
                a = int(max(0, min(255, tp['alpha'])))
                if tp.get('layer') == 'glow':
                    pygame.draw.circle(ts, (*self.colors['biolum_cyan'], int(a * 0.4)),
                                      (s + 3, s + 3), s + 2)
                    pygame.draw.circle(ts, (*self.colors['ink_glow'], a), (s + 3, s + 3), s)
                else:
                    pygame.draw.circle(ts, (*self.colors['ink_mid'], int(a * 0.5)),
                                      (s + 3, s + 3), s + 1)
                    pygame.draw.circle(ts, (*self.colors['ink_core'], a), (s + 3, s + 3), s)
                screen.blit(ts, (int(tp['x']) - s - 3, int(tp['y']) - s - 3))

        # --- 외곽 글로우 (다층 대기 효과) ---
        glow_size = 56
        glow_surf = _psurf((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
        # 최외곽 대기 글로우
        pygame.draw.circle(glow_surf, (*self.colors['ink_outer'], 30),
                          (glow_size, glow_size), glow_size)
        # 중간 글로우
        pygame.draw.circle(glow_surf, (*self.colors['ink_mid'], 50),
                          (glow_size, glow_size), glow_size - 10)
        # 내부 글로우
        pygame.draw.circle(glow_surf, (*self.colors['ink_glow'], 40),
                          (glow_size, glow_size), glow_size - 20)
        # 생물발광 힌트
        biolum_pulse = int(20 + 10 * _sin(self._proj_rotation * 0.08))
        pygame.draw.circle(glow_surf, (*self.colors['biolum_cyan'], biolum_pulse),
                          (glow_size, glow_size), glow_size - 15)
        screen.blit(glow_surf, (int(current_x) - glow_size, int(current_y) - glow_size))

        # --- 발사체 주위 소형 촉수 ---
        for pt in self._proj_tendrils:
            t_angle = pt['angle'] + _sin(pt['phase']) * 0.6
            rot_rad = math.radians(self._proj_rotation)
            t_angle += rot_rad * 0.3
            t_len = pt['length'] + _sin(pt['phase'] * 1.5) * 8
            segments = 5
            prev_tx = current_x
            prev_ty = current_y
            for seg in range(segments):
                t = (seg + 1) / segments
                seg_a = t_angle + _sin(pt['phase'] + seg * 0.5) * 0.4
                sx = current_x + _cos(seg_a) * t_len * t
                sy = current_y + _sin(seg_a) * t_len * t
                w = max(1, int(pt['width'] * (1 - t * 0.7)))
                a = int(160 * (1 - t * 0.5))
                pygame.draw.line(screen, (*self.colors['tendril'], a),
                                (int(prev_tx), int(prev_ty)), (int(sx), int(sy)), w)
                prev_tx, prev_ty = sx, sy
            # 촉수 끝 발광
            tip_a = int(60 + 30 * _sin(pt['phase'] * 2))
            tip_surf = _psurf((10, 10), pygame.SRCALPHA)
            pygame.draw.circle(tip_surf, (*self.colors['biolum_cyan'], tip_a), (5, 5), 4)
            screen.blit(tip_surf, (int(prev_tx) - 5, int(prev_ty) - 5))

        # --- 메인 발사체 서피스 ---
        proj_size = 50
        proj_surf = _psurf((proj_size * 2, proj_size * 2), pygame.SRCALPHA)
        cx, cy = proj_size, proj_size

        # 안정적인 먹물 덩어리 (미리 생성된 파티클 사용)
        rot_rad = math.radians(self._proj_rotation)
        for pb in self._proj_blobs:
            ox = pb['offset_x'] + _sin(pb['phase']) * 4
            oy = pb['offset_y'] + _cos(pb['phase'] * 0.7) * 4
            s = int(pb['size'] + _sin(pb['phase'] * 1.3) * 2.5)
            rx = ox * _cos(rot_rad) - oy * _sin(rot_rad)
            ry = ox * _sin(rot_rad) + oy * _cos(rot_rad)
            layer = pb.get('layer', 'mid')
            if layer == 'deep':
                color = self.colors['ink_deep']
                alpha = 240
            elif layer == 'outer':
                color = self.colors['ink_outer']
                alpha = 180
            else:
                color = self.colors['ink_core']
                alpha = 210
            # 블롭 외곽 글로우
            if s > 3:
                pygame.draw.circle(proj_surf, (*self.colors['ink_mid'], int(alpha * 0.3)),
                                  (int(cx + rx), int(cy + ry)), s + 2)
            pygame.draw.circle(proj_surf, (*color, alpha),
                             (int(cx + rx), int(cy + ry)), s)

        # 소용돌이 패턴 (코어 주위 회전 선)
        for i in range(3):
            swirl_angle = rot_rad * 2 + i * (math.pi * 2 / 3)
            for seg in range(8):
                t = seg / 8
                r = 5 + t * 12
                a_off = swirl_angle + t * 1.5
                sx = cx + int(_cos(a_off) * r)
                sy = cy + int(_sin(a_off) * r)
                sw = max(1, int(3 * (1 - t)))
                sa = int(120 * (1 - t * 0.7))
                pygame.draw.circle(proj_surf, (*self.colors['ink_glow'], sa), (sx, sy), sw)

        # 코어 (다층 발광 중심)
        core_pulse = 11 + _sin(self._proj_rotation * 0.05) * 3
        pygame.draw.circle(proj_surf, (*self.colors['deep_black'], 255), (cx, cy), int(core_pulse))
        pygame.draw.circle(proj_surf, (*self.colors['ink_deep'], 240), (cx, cy), int(core_pulse + 2))
        pygame.draw.circle(proj_surf, (*self.colors['ink_glow'], 100), (cx, cy), int(core_pulse + 6))
        # 생물발광 펄스
        biolum_r = int(core_pulse + 3 + _sin(self._proj_rotation * 0.1) * 2)
        biolum_a = int(50 + 30 * _sin(self._proj_rotation * 0.08))
        pygame.draw.circle(proj_surf, (*self.colors['biolum_cyan'], biolum_a), (cx, cy), biolum_r)

        screen.blit(proj_surf, (int(current_x) - proj_size, int(current_y) - proj_size))

        # --- 꼬리 잔상 (그라데이션 체인) ---
        for i in range(8):
            tail_p = max(0, progress - i * 0.05)
            if tail_p > 0:
                tx = self.projectile_x + (self.projectile_target_x - self.projectile_x) * tail_p
                ty = self.projectile_y + (self.projectile_target_y - self.projectile_y) * tail_p
                a = int(140 - i * 17)
                s = int(16 - i * 1.8)
                if s > 0 and a > 0:
                    ts = _psurf((s * 2 + 6, s * 2 + 6), pygame.SRCALPHA)
                    # 외곽
                    pygame.draw.circle(ts, (*self.colors['ink_outer'], int(a * 0.3)),
                                      (s + 3, s + 3), s + 2)
                    # 코어
                    pygame.draw.circle(ts, (*self.colors['ink_core'], a), (s + 3, s + 3), s)
                    screen.blit(ts, (int(tx) - s - 3, int(ty) - s - 3))

    def _draw_splash(self, screen):
        """2단계: 울트라 고퀄리티 스플래시 - 충격파 + 잉크 폭발"""
        wr = int(self.splash_radius * self.splash_width_scale)
        hr = int(self.splash_radius)
        if wr < 5 or hr < 5:
            return

        # --- 충격파 링 (가장 먼저 그림) ---
        if self.splash_shockwave > 10:
            sw_r = int(self.splash_shockwave)
            sw_wr = int(sw_r * self.splash_width_scale)
            sw_alpha = max(0, int(120 * (1 - self.splash_shockwave / (self.splash_max_radius * 2.5))))
            if sw_alpha > 3:
                sw_surf = _psurf((sw_wr * 2 + 20, sw_r * 2 + 20), pygame.SRCALPHA)
                sw_cx, sw_cy = sw_wr + 10, sw_r + 10
                # 외곽 링
                pygame.draw.ellipse(sw_surf, (*self.colors['ink_glow'], sw_alpha),
                                   (10, 10, sw_wr * 2, sw_r * 2), 3)
                # 내부 더 밝은 링
                inner_r = max(1, sw_r - 8)
                inner_wr = max(1, sw_wr - 8)
                inner_a = min(255, int(sw_alpha * 0.6))
                if inner_a > 3:
                    pygame.draw.ellipse(sw_surf, (*self.colors['biolum_cyan'], inner_a),
                                       (10 + sw_wr - inner_wr, 10 + sw_r - inner_r,
                                        inner_wr * 2, inner_r * 2), 2)
                screen.blit(sw_surf, (int(self.splash_center_x - sw_cx),
                                     int(self.splash_center_y - sw_cy)))

        # --- 잉크 튀김 자국 (바닥 얼룩) ---
        for sp in self.splash_splatters:
            if sp['alpha'] > 3:
                s = max(2, int(sp['size']))
                sa = int(max(0, min(255, sp['alpha'])))
                ss = _psurf((s * 2 + 4, s * 2 + 4), pygame.SRCALPHA)
                sc = s + 2
                points = []
                for angle_i in range(0, 360, 40):
                    rad = math.radians(angle_i)
                    r = s * (0.6 + 0.4 * _sin(rad * 3 + sp['shape_seed']))
                    points.append((int(sc + _cos(rad) * r), int(sc + _sin(rad) * r)))
                if len(points) >= 3:
                    pygame.draw.polygon(ss, (*self.colors['ink_deep'], sa), points)
                screen.blit(ss, (int(self.splash_center_x + sp['x'] - sc),
                                int(self.splash_center_y + sp['y'] - sc)))

        # --- 메인 스플래시 ---
        surf_w = wr * 2 + 80
        surf_h = hr * 2 + 80
        splash_surf = _psurf((surf_w, surf_h), pygame.SRCALPHA)
        scx, scy = surf_w // 2, surf_h // 2

        # 불규칙한 스플래시 (5레이어 → 더 풍부한 깊이감)
        for layer_i, (color, scale, alpha) in enumerate([
            (self.colors['ink_outer'], 1.1, 50),
            (self.colors['ink_mid'], 1.0, 90),
            (self.colors['ink_core'], 0.88, 170),
            (self.colors['ink_deep'], 0.72, 220),
            (self.colors['deep_black'], 0.55, 240),
        ]):
            points = []
            for angle in range(0, 360, 10):
                rad = math.radians(angle)
                wobble = 0.78 + 0.22 * _sin(rad * 5 + self.splash_timer * 14 + layer_i * 0.7)
                px = scx + int(_cos(rad) * wr * scale * wobble)
                py = scy + int(_sin(rad) * hr * scale * wobble)
                points.append((px, py))
            if len(points) >= 3:
                pygame.draw.polygon(splash_surf, (*color, alpha), points)

        # 테두리 (다중 발광 링)
        for ring_i, (ring_color, ring_scale, ring_alpha, ring_width) in enumerate([
            (self.colors['biolum_cyan'], 1.02, 60, 1),
            (self.colors['ink_glow'], 1.0, 150, 2),
            (self.colors['ink_highlight'], 0.96, 100, 1),
        ]):
            border_points = []
            for angle in range(0, 360, 8):
                rad = math.radians(angle)
                wobble = 0.82 + 0.18 * _sin(rad * 5 + self.splash_timer * 14 + ring_i * 0.3)
                px = scx + int(_cos(rad) * wr * ring_scale * wobble)
                py = scy + int(_sin(rad) * hr * ring_scale * wobble)
                border_points.append((px, py))
            if len(border_points) >= 3:
                pygame.draw.polygon(splash_surf, (*ring_color, ring_alpha),
                                   border_points, ring_width)

        # 중심 임팩트 플래시
        flash_decay = max(0, 1.0 - self.splash_timer / 0.15)
        if flash_decay > 0:
            flash_a = int(180 * flash_decay)
            flash_r = int(30 * flash_decay)
            if flash_r > 2:
                pygame.draw.circle(splash_surf, (*self.colors['ink_shimmer'], flash_a),
                                  (scx, scy), flash_r)
                pygame.draw.circle(splash_surf, (255, 220, 255, int(flash_a * 0.5)),
                                  (scx, scy), max(1, flash_r // 2))

        screen.blit(splash_surf, (int(self.splash_center_x - scx), int(self.splash_center_y - scy)))

        # --- 튀는 방울 (물리 기반 + 잔상 트레일) ---
        for drop in self.splash_droplets:
            if drop['alpha'] > 5 and drop['size'] > 0.5:
                # 잔상 트레일 먼저
                for tr in drop.get('trail', []):
                    ts = max(1, int(tr['size']))
                    ta = int(max(0, min(255, tr['alpha'])))
                    if ta > 3:
                        trs = _psurf((ts * 2 + 2, ts * 2 + 2), pygame.SRCALPHA)
                        pygame.draw.circle(trs, (*self.colors['ink_mid'], ta),
                                          (ts + 1, ts + 1), ts)
                        screen.blit(trs, (int(self.splash_center_x + tr['x']) - ts - 1,
                                         int(self.splash_center_y + tr['y']) - ts - 1))
                # 메인 방울
                dx = self.splash_center_x + drop['x']
                dy = self.splash_center_y + drop['y']
                s = max(1, int(drop['size']))
                a = int(max(0, min(255, drop['alpha'])))
                ds = _psurf((s * 2 + 6, s * 2 + 6), pygame.SRCALPHA)
                # 외곽 글로우
                pygame.draw.circle(ds, (*self.colors['ink_glow'], int(a * 0.4)),
                                  (s + 3, s + 3), s + 2)
                # 코어
                pygame.draw.circle(ds, (*self.colors['ink_core'], a), (s + 3, s + 3), s)
                # 하이라이트 스펙
                if s > 2:
                    pygame.draw.circle(ds, (*self.colors['ink_highlight'], int(a * 0.5)),
                                      (s + 2, s + 1), max(1, s // 3))
                screen.blit(ds, (int(dx) - s - 3, int(dy) - s - 3))

    def _draw_active(self, screen):
        """3단계: 울트라 고퀄리티 먹물 웅덩이 - 심해의 심연"""
        wr = int(self.splash_max_radius * self.splash_width_scale)
        hr = int(self.splash_max_radius)

        # === 1. 최하층: 대기 글로우 (다층) ===
        glow_surf = _psurf((wr * 2 + 60, hr * 2 + 60), pygame.SRCALPHA)
        gcx, gcy = wr + 30, hr + 30
        pulse = 1.0 + 0.04 * _sin(self.ink_shimmer_time * 2)
        # 최외곽 안개 글로우
        pygame.draw.ellipse(glow_surf, (*self.colors['mist_purple'], 20),
                           (int(gcx - wr * pulse * 1.15), int(gcy - hr * pulse * 1.15),
                            int(wr * 2 * pulse * 1.15), int(hr * 2 * pulse * 1.15)))
        # 중간 글로우
        pygame.draw.ellipse(glow_surf, (*self.colors['ink_outer'], 40),
                           (int(gcx - wr * pulse), int(gcy - hr * pulse),
                            int(wr * 2 * pulse), int(hr * 2 * pulse)))
        # 내부 글로우
        pygame.draw.ellipse(glow_surf, (*self.colors['ink_mid'], 60),
                           (int(gcx - wr * 0.82), int(gcy - hr * 0.82),
                            int(wr * 1.64), int(hr * 1.64)))
        screen.blit(glow_surf, (int(self.splash_center_x - gcx), int(self.splash_center_y - gcy)))

        # === 2. 먹물 촉수/가지 (분기 포함) ===
        for tendril in self.ink_tendrils:
            self._draw_tendril(screen, tendril)

        # === 3. 메인 먹물 블롭들 (깊이별 렌더링) ===
        # deep 레이어 먼저, surface 레이어 나중에
        for depth_layer in ['deep', 'mid', 'surface']:
            for blob in self.ink_blobs:
                if blob['alpha'] <= 5 or blob.get('depth', 'mid') != depth_layer:
                    continue
                pulse_mod = 1.0 + 0.06 * _sin(blob['pulse_phase'])
                size = int(blob['size'] * pulse_mod + _sin(blob['wobble']) * 5)
                if size < 2:
                    continue

                surf = _psurf((size * 2 + 16, size * 2 + 16), pygame.SRCALPHA)
                c = size + 8

                # 불규칙한 형태 (18각형 기반 - 더 부드러운 윤곽)
                points_outer = []
                points_mid = []
                points_inner = []
                for angle in range(0, 360, 20):
                    rad = math.radians(angle)
                    r_out = size * (0.72 + 0.32 * _sin(rad * 3 + blob['shape_seed'] + blob['wobble'] * 0.5))
                    r_mid = r_out * 0.8
                    r_in = r_out * 0.55
                    points_outer.append((c + int(_cos(rad) * r_out), c + int(_sin(rad) * r_out)))
                    points_mid.append((c + int(_cos(rad) * r_mid), c + int(_sin(rad) * r_mid)))
                    points_inner.append((c + int(_cos(rad) * r_in), c + int(_sin(rad) * r_in)))

                a = int(max(0, min(255, blob['alpha'])))

                # 깊이에 따른 색상 변화
                if depth_layer == 'deep':
                    outer_color = self.colors['ink_outer']
                    main_color = self.colors['ink_core']
                    inner_color = self.colors['deep_black']
                    a_mod = 0.9
                elif depth_layer == 'surface':
                    outer_color = self.colors['ink_mid']
                    main_color = self.colors['ink_outer']
                    inner_color = self.colors['ink_core']
                    a_mod = 0.7
                else:
                    outer_color = self.colors['ink_outer']
                    main_color = self.colors['ink_core']
                    inner_color = self.colors['ink_deep']
                    a_mod = 1.0

                if len(points_outer) >= 3:
                    # 외곽 소프트 글로우
                    pygame.draw.polygon(surf, (*outer_color, int(a * 0.25 * a_mod)), points_outer)
                    # 메인 바디
                    pygame.draw.polygon(surf, (*main_color, int(a * a_mod)), points_outer)
                    # 중간 그라데이션
                    if len(points_mid) >= 3:
                        pygame.draw.polygon(surf, (*inner_color, int(a * 0.7 * a_mod)), points_mid)
                    # 내부 심연
                    if len(points_inner) >= 3:
                        pygame.draw.polygon(surf, (*self.colors['deep_black'], int(a * 0.6 * a_mod)), points_inner)

                    # 표면 반사 (움직이는 하이라이트)
                    shimmer_x = c + int(_sin(self.ink_shimmer_time * 1.5 + blob['shape_seed']) * size * 0.3)
                    shimmer_y = c - int(size * 0.2) + int(_cos(self.ink_shimmer_time * 0.8) * size * 0.1)
                    shimmer_size = max(2, int(size * 0.18))
                    shimmer_a = int(35 + 30 * _sin(self.ink_shimmer_time * 2.5 + blob['shape_seed']))
                    pygame.draw.circle(surf, (*self.colors['ink_shimmer'], shimmer_a),
                                     (shimmer_x, shimmer_y), shimmer_size)
                    # 2차 반사
                    s2_x = c + int(_cos(self.ink_shimmer_time * 1.2 + blob['shape_seed'] + 1) * size * 0.2)
                    s2_y = c + int(_sin(self.ink_shimmer_time * 0.9 + blob['shape_seed']) * size * 0.15)
                    s2_size = max(1, int(size * 0.1))
                    s2_a = int(20 + 15 * _sin(self.ink_shimmer_time * 3 + blob['shape_seed'] + 2))
                    pygame.draw.circle(surf, (*self.colors['ink_highlight'], s2_a),
                                     (s2_x, s2_y), s2_size)

                screen.blit(surf, (int(blob['x'] - c), int(blob['y'] - c)))

        # === 4. 내부 흐름 (소용돌이 스트림) ===
        for current in self.ink_currents:
            phase = current['phase']
            start = current['start_angle'] + phase
            arc = current['arc_length']
            r_ratio = current['radius']
            w = max(1, int(current['width']))
            ca = current['alpha']
            segments = 12
            prev_sx = None
            prev_sy = None
            for seg in range(segments + 1):
                t = seg / segments
                ang = start + arc * t
                r_x = wr * r_ratio * (1 + 0.1 * _sin(ang * 2 + phase))
                r_y = hr * r_ratio * (1 + 0.1 * _cos(ang * 2 + phase))
                sx = self.splash_center_x + _cos(ang) * r_x
                sy = self.splash_center_y + _sin(ang) * r_y
                if prev_sx is not None:
                    seg_a = int(ca * (1 - abs(t - 0.5) * 1.6))
                    if seg_a > 3:
                        pygame.draw.line(screen, (*self.colors['ink_glow'], seg_a),
                                        (int(prev_sx), int(prev_sy)),
                                        (int(sx), int(sy)), w)
                prev_sx, prev_sy = sx, sy

        # === 5. 수면 코스틱 (빛 반사 무늬) ===
        for caustic in self.ink_caustics:
            ca_angle = caustic['angle'] + caustic['phase']
            ca_dist = caustic['dist']
            ca_size = int(caustic['size'] * (0.8 + 0.2 * _sin(caustic['phase'] * 2)))
            ca_x = self.splash_center_x + _cos(ca_angle) * wr * ca_dist
            ca_y = self.splash_center_y + _sin(ca_angle) * hr * ca_dist
            ca_alpha = int(25 + 15 * _sin(caustic['phase'] * 3))
            if ca_alpha > 3 and ca_size > 2:
                cs = _psurf((ca_size * 2 + 4, ca_size * 2 + 4), pygame.SRCALPHA)
                cc = ca_size + 2
                # 불규칙 코스틱 패턴
                points = []
                for ai in range(0, 360, 60):
                    rad = math.radians(ai)
                    r = ca_size * (0.5 + 0.5 * _sin(rad * 2 + caustic['phase']))
                    points.append((int(cc + _cos(rad) * r), int(cc + _sin(rad) * r)))
                if len(points) >= 3:
                    pygame.draw.polygon(cs, (*self.colors['caustic_light'], ca_alpha), points)
                screen.blit(cs, (int(ca_x - cc), int(ca_y - cc)))

        # === 6. 기포 (상세 렌더링) ===
        for bubble in self.ink_bubbles:
            life_ratio = max(0, bubble['life'] / bubble['max_life'])
            if life_ratio > 0:
                s = max(1, int(bubble['size'] * (0.5 + life_ratio * 0.5)))
                ba = int(200 * life_ratio)
                bs = _psurf((s * 2 + 8, s * 2 + 8), pygame.SRCALPHA)
                bc = s + 4
                # 기포 외곽 글로우
                pygame.draw.circle(bs, (*self.colors['ink_glow'], int(ba * 0.2)), (bc, bc), s + 2)
                # 기포 본체
                pygame.draw.circle(bs, (*self.colors['bubble_base'], ba), (bc, bc), s)
                # 기포 내부 (반투명)
                if s > 2:
                    pygame.draw.circle(bs, (*self.colors['bubble_highlight'], int(ba * 0.3)),
                                      (bc, bc), max(1, s - 1))
                # 하이라이트 스펙 (반달 모양)
                if s > 3:
                    hl_x = bc - int(s * 0.3)
                    hl_y = bc - int(s * 0.3)
                    pygame.draw.circle(bs, (*self.colors['bubble_highlight'], int(ba * 0.7)),
                                      (hl_x, hl_y), max(1, s // 3))
                    # 작은 빛점
                    pygame.draw.circle(bs, (220, 200, 255, int(ba * 0.5)),
                                      (hl_x + 1, hl_y - 1), max(1, s // 5))
                screen.blit(bs, (int(bubble['x'] - bc), int(bubble['y'] - bc)))

        # === 7. 안개/연기 (떠오르는 입자) ===
        for mist in self.ink_mist:
            life_ratio = max(0, mist['life'] / mist['max_life'])
            if life_ratio > 0:
                ms = max(2, int(mist['size']))
                ma = int(max(0, min(255, mist['alpha'] * life_ratio)))
                if ma > 3:
                    ms_surf = _psurf((ms * 2 + 4, ms * 2 + 4), pygame.SRCALPHA)
                    mc = ms + 2
                    pygame.draw.circle(ms_surf, (*self.colors['mist_purple'], int(ma * 0.5)),
                                      (mc, mc), ms)
                    pygame.draw.circle(ms_surf, (*self.colors['ink_outer'], int(ma * 0.3)),
                                      (mc, mc), max(1, int(ms * 0.6)))
                    screen.blit(ms_surf, (int(mist['x'] - mc), int(mist['y'] - mc)))

        # === 8. 심해의 눈 (혼란 상징 - 중앙 소용돌이 눈) ===
        if self.confusion_applied:
            eye_open = min(1.0, self.confusion_timer / 0.5)  # 0.5초에 걸쳐 눈 뜸
            eye_size = int(28 * eye_open)
            if eye_size > 3:
                eye_surf = _psurf((eye_size * 2 + 20, eye_size * 2 + 20), pygame.SRCALPHA)
                ec = eye_size + 10

                # 눈 외곽 글로우
                glow_a = int(60 + 30 * _sin(self.ink_eye_phase * 3))
                pygame.draw.circle(eye_surf, (*self.colors['eye_glow'], glow_a),
                                  (ec, ec), eye_size + 6)

                # 눈 바깥 링 (동공 테두리)
                pygame.draw.circle(eye_surf, (*self.colors['eye_iris'], int(180 * eye_open)),
                                  (ec, ec), eye_size)

                # 홍채 (내부 고리)
                iris_size = max(2, int(eye_size * 0.7))
                iris_color = (
                    int(180 + 40 * _sin(self.ink_eye_phase * 2)),
                    int(40 + 20 * _sin(self.ink_eye_phase * 1.5 + 1)),
                    int(200 + 30 * _cos(self.ink_eye_phase * 2.5)),
                )
                pygame.draw.circle(eye_surf, (*iris_color, int(200 * eye_open)),
                                  (ec, ec), iris_size)

                # 홍채 패턴 (방사상 선)
                for ri in range(8):
                    r_ang = ri * (math.pi / 4) + self.ink_eye_phase * 0.5
                    r_inner = iris_size * 0.3
                    r_outer = iris_size * 0.95
                    lx1 = ec + int(_cos(r_ang) * r_inner)
                    ly1 = ec + int(_sin(r_ang) * r_inner)
                    lx2 = ec + int(_cos(r_ang) * r_outer)
                    ly2 = ec + int(_sin(r_ang) * r_outer)
                    pygame.draw.line(eye_surf, (*self.colors['eye_glow'], int(80 * eye_open)),
                                    (lx1, ly1), (lx2, ly2), 1)

                # 동공 (수축/확장)
                pupil_size = max(2, int(iris_size * (0.35 + 0.1 * _sin(self.ink_eye_phase * 4))))
                pygame.draw.circle(eye_surf, (*self.colors['eye_pupil'], int(240 * eye_open)),
                                  (ec, ec), pupil_size)

                # 동공 내 빛점 (반사)
                spec_x = ec - int(pupil_size * 0.3)
                spec_y = ec - int(pupil_size * 0.3)
                pygame.draw.circle(eye_surf, (255, 220, 255, int(150 * eye_open)),
                                  (spec_x, spec_y), max(1, pupil_size // 3))

                screen.blit(eye_surf, (int(self.splash_center_x - ec),
                                      int(self.splash_center_y - ec)))

            # 소용돌이 링
            vortex_surf = _psurf((wr * 2 + 30, hr * 2 + 30), pygame.SRCALPHA)
            vcx, vcy = wr + 15, hr + 15
            for ring_i in range(3):
                ring_offset = self.ink_vortex_angle + ring_i * 120
                ring_a = int(25 + 15 * _sin(self.ink_shimmer_time * 3 + ring_i))
                ring_points = []
                for ai in range(0, 360, 8):
                    rad = math.radians(ai + ring_offset)
                    dist_mod = 0.85 + 0.15 * _sin(rad * 3 + self.ink_shimmer_time * 2)
                    rx = vcx + int(_cos(rad) * wr * dist_mod)
                    ry = vcy + int(_sin(rad) * hr * dist_mod)
                    ring_points.append((rx, ry))
                if len(ring_points) >= 3:
                    pygame.draw.polygon(vortex_surf, (*self.colors['vortex_edge'], ring_a),
                                       ring_points, 2)
            screen.blit(vortex_surf, (int(self.splash_center_x - vcx),
                                     int(self.splash_center_y - vcy)))

    def _draw_tendril(self, screen, tendril):
        """먹물 촉수/가지 하나 그리기 - 고퀄리티 (분기 + 빛 팁)"""
        base_angle = tendril['angle']
        length = tendril['length']
        width = tendril['width']
        wobble = tendril['wobble']
        tip_glow = tendril.get('tip_glow', 0)
        branch_count = tendril.get('branch_count', 0)

        wr = self.splash_max_radius * self.splash_width_scale
        hr = self.splash_max_radius

        prev_x = self.splash_center_x + _cos(base_angle) * wr * 0.5
        prev_y = self.splash_center_y + _sin(base_angle) * hr * 0.5

        segment_positions = [(prev_x, prev_y)]

        for seg in range(tendril['segments']):
            t = (seg + 1) / tendril['segments']
            seg_angle = base_angle + _sin(wobble + seg * 0.8) * 0.35
            dist = (0.5 + t * 0.5) * length
            nx = self.splash_center_x + _cos(seg_angle) * wr * dist
            ny = self.splash_center_y + _sin(seg_angle) * hr * dist

            seg_width = max(1, int(width * (1.0 - t * 0.7)))
            alpha = int(190 * (1.0 - t * 0.5))

            # 3층 촉수 세그먼트 (외곽글로우 + 본체 + 하이라이트)
            surf_w = abs(int(nx - prev_x)) + seg_width * 2 + 24
            surf_h = abs(int(ny - prev_y)) + seg_width * 2 + 24
            if surf_w > 1 and surf_h > 1:
                ts = _psurf((surf_w, surf_h), pygame.SRCALPHA)
                ox = seg_width + 12 - min(0, int(nx - prev_x))
                oy = seg_width + 12 - min(0, int(ny - prev_y))
                p1 = (ox + max(0, int(prev_x - min(prev_x, nx))),
                      oy + max(0, int(prev_y - min(prev_y, ny))))
                p2 = (ox + max(0, int(nx - min(prev_x, nx))),
                      oy + max(0, int(ny - min(prev_y, ny))))

                # 외곽 글로우
                pygame.draw.line(ts, (*self.colors['ink_outer'], int(alpha * 0.3)),
                                p1, p2, seg_width + 4)
                # 본체
                pygame.draw.line(ts, (*self.colors['tendril'], alpha), p1, p2, seg_width)
                # 하이라이트 (중심선)
                if seg_width > 2:
                    hl_w = max(1, seg_width // 3)
                    pygame.draw.line(ts, (*self.colors['ink_mid'], int(alpha * 0.5)),
                                    p1, p2, hl_w)

                screen.blit(ts, (int(min(prev_x, nx)) - seg_width - 12,
                                int(min(prev_y, ny)) - seg_width - 12))

            segment_positions.append((nx, ny))
            prev_x, prev_y = nx, ny

        # 촉수 끝 생물발광 팁
        tip_a = int(80 + 50 * _sin(tip_glow * 2))
        tip_size = max(2, int(width * 0.4))
        tip_surf = _psurf((tip_size * 2 + 8, tip_size * 2 + 8), pygame.SRCALPHA)
        tc = tip_size + 4
        pygame.draw.circle(tip_surf, (*self.colors['biolum_cyan'], int(tip_a * 0.4)),
                          (tc, tc), tip_size + 3)
        pygame.draw.circle(tip_surf, (*self.colors['biolum_cyan'], tip_a),
                          (tc, tc), tip_size)
        pygame.draw.circle(tip_surf, (*self.colors['biolum_green'], int(tip_a * 0.6)),
                          (tc, tc), max(1, tip_size // 2))
        screen.blit(tip_surf, (int(prev_x - tc), int(prev_y - tc)))

        # 분기 촉수 (짧은 가지)
        if branch_count > 0 and len(segment_positions) > 3:
            for bi in range(branch_count):
                branch_idx = min(len(segment_positions) - 2,
                                max(1, len(segment_positions) // 2 + bi))
                bx, by = segment_positions[branch_idx]
                branch_angle = base_angle + (0.6 if bi % 2 == 0 else -0.6) + _sin(wobble + bi) * 0.2
                branch_len = length * 0.3
                b_prev_x, b_prev_y = bx, by
                for bs in range(3):
                    bt = (bs + 1) / 3
                    ba = branch_angle + _sin(wobble + bs * 0.5 + bi) * 0.3
                    bd = 0.3 * bt * branch_len
                    bnx = bx + _cos(ba) * wr * bd
                    bny = by + _sin(ba) * hr * bd
                    bw = max(1, int(width * 0.4 * (1 - bt * 0.8)))
                    b_alpha = int(120 * (1 - bt * 0.7))
                    pygame.draw.line(screen, (*self.colors['tendril'], b_alpha),
                                    (int(b_prev_x), int(b_prev_y)),
                                    (int(bnx), int(bny)), bw)
                    b_prev_x, b_prev_y = bnx, bny

    def _draw_dissolve(self, screen):
        """분해 애니메이션 렌더링 - 울트라 고퀄리티 (소용돌이 흡수 + 섬광)"""
        progress = min(1.0, self.dissolve_timer / self.dissolve_duration)

        # 0. 초기 섬광 (먹물 폭발/소멸 시작)
        if self.dissolve_flash_alpha > 3:
            fa = int(max(0, min(255, self.dissolve_flash_alpha)))
            flash_r = int(self.splash_max_radius * 0.6)
            flash_wr = int(flash_r * self.splash_width_scale)
            fs = _psurf((flash_wr * 2 + 20, flash_r * 2 + 20), pygame.SRCALPHA)
            fc = flash_wr + 10
            fr = flash_r + 10
            pygame.draw.ellipse(fs, (*self.colors['eye_glow'], int(fa * 0.4)),
                               (10, 10, flash_wr * 2, flash_r * 2))
            pygame.draw.ellipse(fs, (*self.colors['ink_shimmer'], int(fa * 0.6)),
                               (int(fc - flash_wr * 0.5), int(fr - flash_r * 0.5),
                                flash_wr, flash_r))
            screen.blit(fs, (int(self.splash_center_x - fc),
                            int(self.splash_center_y - fr)))

        # 1. 전체 영역 잔상 (서서히 사라지는 영역 글로우)
        if progress < 0.8:
            wr = int(self.splash_max_radius * self.splash_width_scale)
            hr = int(self.splash_max_radius)
            fade_a = int(40 * (1 - progress / 0.8))
            if fade_a > 2:
                gs = _psurf((wr * 2 + 30, hr * 2 + 30), pygame.SRCALPHA)
                gcx, gcy = wr + 15, hr + 15
                pygame.draw.ellipse(gs, (*self.colors['ink_outer'], fade_a),
                                   (15, 15, wr * 2, hr * 2))
                pygame.draw.ellipse(gs, (*self.colors['mist_purple'], int(fade_a * 0.5)),
                                   (int(gcx - wr * 0.7), int(gcy - hr * 0.7),
                                    int(wr * 1.4), int(hr * 1.4)))
                screen.blit(gs, (int(self.splash_center_x - gcx),
                                int(self.splash_center_y - gcy)))

        # 2. 소용돌이 흡수 파티클 (중심으로 빨려드는 효과)
        for vp in self.dissolve_vortex_particles:
            if vp['alpha'] < 3 or vp['size'] < 0.5:
                continue
            vx = self.splash_center_x + _cos(math.radians(vp['angle'])) * vp['dist']
            vy = self.splash_center_y + _sin(math.radians(vp['angle'])) * vp['dist']
            vs = max(1, int(vp['size']))
            va = int(max(0, min(255, vp['alpha'])))
            v_surf = _psurf((vs * 2 + 6, vs * 2 + 6), pygame.SRCALPHA)
            vc = vs + 3
            # 생물발광 파티클
            pygame.draw.circle(v_surf, (*self.colors['biolum_cyan'], int(va * 0.3)),
                              (vc, vc), vs + 2)
            pygame.draw.circle(v_surf, (*self.colors['ink_glow'], va), (vc, vc), vs)
            screen.blit(v_surf, (int(vx - vc), int(vy - vc)))

        # 3. 증발 연기 (색상 변이 포함 - 보라 → 시안 그라데이션)
        for wisp in self.dissolve_wisps:
            if self.dissolve_timer < wisp['delay']:
                continue
            a = int(max(0, min(255, wisp['alpha'])))
            if a < 3:
                continue
            s = max(1, int(wisp['size']))
            ws = _psurf((s * 2 + 6, s * 2 + 6), pygame.SRCALPHA)
            wc = s + 3

            # 색상 변이 (보라 → 시안으로 전이)
            color_shift = wisp.get('color_shift', 0)
            shift = color_shift * progress  # 시간이 지날수록 시안으로
            outer_r = int(self.colors['ink_outer'][0] * (1 - shift) + self.colors['biolum_cyan'][0] * shift)
            outer_g = int(self.colors['ink_outer'][1] * (1 - shift) + self.colors['biolum_cyan'][1] * shift)
            outer_b = int(self.colors['ink_outer'][2] * (1 - shift) + self.colors['biolum_cyan'][2] * shift)
            outer_r = max(0, min(255, outer_r))
            outer_g = max(0, min(255, outer_g))
            outer_b = max(0, min(255, outer_b))

            # 다층 연기
            pygame.draw.circle(ws, (outer_r, outer_g, outer_b, int(a * 0.3)), (wc, wc), s)
            pygame.draw.circle(ws, (*self.colors['ink_mid'], int(a * 0.5)),
                              (wc, wc), max(1, int(s * 0.7)))
            pygame.draw.circle(ws, (*self.colors['ink_core'], int(a * 0.35)),
                              (wc, wc), max(1, int(s * 0.4)))
            screen.blit(ws, (int(wisp['x']) - wc, int(wisp['y']) - wc))

        # 4. 파편 (먹물 조각이 흩어지며 사라짐 - 발광 파편 포함)
        for frag in self.dissolve_fragments:
            a = int(max(0, min(255, frag['alpha'])))
            s = max(1, int(frag['size']))
            if a < 3 or s < 1:
                continue

            fs = _psurf((s * 2 + 8, s * 2 + 8), pygame.SRCALPHA)
            fc = s + 4

            # 불규칙 형태 회전
            points = []
            rot_rad = math.radians(frag['rotation'])
            for angle_i in range(0, 360, 40):
                rad = math.radians(angle_i)
                r = s * (0.55 + 0.45 * _sin(rad * 2 + frag['shape_seed']))
                px = _cos(rad + rot_rad) * r
                py = _sin(rad + rot_rad) * r
                points.append((int(fc + px), int(fc + py)))

            if len(points) >= 3:
                if frag.get('glow', False):
                    # 발광 파편
                    pygame.draw.polygon(fs, (*self.colors['biolum_cyan'], int(a * 0.3)), points)
                    pygame.draw.polygon(fs, (*self.colors['ink_glow'], a), points)
                else:
                    # 일반 파편
                    pygame.draw.polygon(fs, (*self.colors['ink_core'], a), points)
                    # 외곽 글로우
                    pygame.draw.polygon(fs, (*self.colors['ink_glow'], int(a * 0.25)),
                                       points, max(1, s // 4))

            screen.blit(fs, (int(frag['x']) - fc, int(frag['y']) - fc))

        # 5. 최종 중심 소멸 점 (마지막 빛)
        if progress > 0.5 and progress < 0.95:
            final_a = int(80 * (1 - (progress - 0.5) / 0.45))
            final_r = max(2, int(8 * (1 - (progress - 0.5) / 0.45)))
            if final_a > 3:
                final_s = _psurf((final_r * 2 + 8, final_r * 2 + 8), pygame.SRCALPHA)
                fcc = final_r + 4
                pygame.draw.circle(final_s, (*self.colors['biolum_cyan'], int(final_a * 0.5)),
                                  (fcc, fcc), final_r + 3)
                pygame.draw.circle(final_s, (*self.colors['eye_glow'], final_a),
                                  (fcc, fcc), final_r)
                screen.blit(final_s, (int(self.splash_center_x - fcc),
                                     int(self.splash_center_y - fcc)))

    def reset_for_new_round(self, game_state: dict):
        """라운드 전환 시 심해의 먹물 스킬 강제 종료"""
        super().reset_for_new_round(game_state)
        self.ink_blobs = []
        self.ink_bubbles = []
        self.ink_tendrils = []
        self.ink_currents = []
        self.ink_mist = []
        self.ink_caustics = []
        self.ink_eye_phase = 0.0
        self.ink_vortex_angle = 0.0
        self.phase = 'travel'
        self.projectile_progress = 0.0
        self.splash_timer = 0
        self.active_timer = 0
        self._trail_particles = []
        self._proj_blobs = []
        self._ribbon_trail = []
        self._proj_tendrils = []
        self.splash_droplets = []
        self.splash_splatters = []
        self.splash_shockwave = 0.0
        self.dissolving = False
        self.dissolve_timer = 0.0
        self.dissolve_fragments = []
        self.dissolve_wisps = []
        self.dissolve_vortex_particles = []
        self.dissolve_flash_alpha = 0
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
            description="시공의 힘으로 중력을 왜곡시켜 공을 끌어내린다",
            trigger=SkillTrigger.ON_COOLDOWN,
            cooldown=20.0,
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
        overlay = _get_fullscreen_surface()
        overlay.fill((60, 40, 100, 30))
        screen.blit(overlay, (0, 0))

        # 왜곡선 그리기 (중력장 시각화)
        for line in self.distortion_lines:
            points = []
            for x in range(80, 680, 10):
                wave_y = line['y'] + _sin(x * line['frequency'] + line['phase']) * line['amplitude']
                points.append((x, int(wave_y)))
            if len(points) > 1:
                surf = _psurf((600, 30), pygame.SRCALPHA)
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
            pulse = abs(_sin(self.pulse_timer * 4)) * 0.5 + 0.5
            for i in range(3):
                radius = int(20 + i * 12 + pulse * 8)
                alpha = int(60 - i * 15)
                surf = _psurf((radius * 2, radius * 2), pygame.SRCALPHA)
                pygame.draw.circle(surf, (100, 80, 180, alpha), (radius, radius), radius, 2)
                screen.blit(surf, (int(ball.x - radius), int(ball.y - radius)))

            # 하향 화살표 표시
            arrow_y_offset = int(_sin(self.pulse_timer * 6) * 5)
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
                    wave = _sin(t * math.pi * 3 + self.pulse_timer * 8) * (8 + 6 * t)
                    mx += wave
                    seg_alpha = int((80 + 60 * t) * abs(_sin(self.pulse_timer * 3 + t * 2)))
                    seg_alpha = max(20, min(200, seg_alpha))
                    seg_size = max(2, int(3 + 2 * t))
                    seg_surf = _psurf((seg_size * 2, seg_size * 2), pygame.SRCALPHA)
                    pygame.draw.circle(seg_surf, (140, 100, 220, seg_alpha),
                                     (seg_size, seg_size), seg_size)
                    screen.blit(seg_surf, (int(mx - seg_size), int(my - seg_size)))

            # 상대 패들 주변 자력 오라 (공이 끌려오는 느낌)
            aura_pulse = abs(_sin(self.pulse_timer * 4)) * 0.5 + 0.5
            for r in range(2):
                aura_r = int(25 + r * 15 + aura_pulse * 10)
                a = max(20, int(70 - r * 25))
                aura_s = _psurf((aura_r * 2, aura_r * 2), pygame.SRCALPHA)
                pygame.draw.circle(aura_s, (120, 80, 200, a), (aura_r, aura_r), aura_r, 2)
                screen.blit(aura_s, (int(paddle_cx - aura_r), int(paddle_cy - aura_r)))


class DwarfMagic(HeroSkill):
    """난쟁이마술 - 보라색 빛가루로 상대 패들 축소"""
    def __init__(self):
        super().__init__(
            skill_id="dwarf_magic",
            name="Dwarf Magic",
            korean_name="난쟁이마술",
            description="신비로운 빛가루가 상대의 몸을 작게 오므라들게 한다",
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
        # 축소/복원 애니메이션 상태
        self.SHRINK_ANIM_DURATION = 0.3  # 축소 애니메이션 시간
        self.RESTORE_ANIM_DURATION = 0.3  # 복원 애니메이션 시간
        self.shrink_anim_timer = 0.0  # 축소 애니메이션 진행 타이머
        self.restore_anim_timer = 0.0  # 복원 애니메이션 진행 타이머
        self.is_shrinking = False  # 축소 애니메이션 중
        self.is_restoring = False  # 복원 애니메이션 중

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
        game_state['chronos_cast_pose_timer'] = 0.5  # 0.5초간 시전 포즈

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
            'sound': 'smallboyshoot'
        }

    def update(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        """스킬 업데이트 - 오버라이드하여 shrink_timer를 is_active와 별개로 처리"""
        # 부모 클래스의 쿨타임 처리
        if self.current_cooldown > 0:
            self.current_cooldown -= dt
        if self.activation_flash_timer > 0:
            self.activation_flash_timer -= dt

        # 활성 효과 업데이트 (투사체 이동)
        if self.is_active:
            self.active_timer -= dt
            self._update_active_effect(dt, caster_paddle, target_paddle, ball, game_state)
            if self.active_timer <= 0:
                self._end_effect(caster_paddle, target_paddle, ball, game_state)
                self.is_active = False

        # ★ 핵심: shrink_timer는 is_active와 별개로 항상 처리
        # (투사체 명중 후 is_active가 False가 되어도 축소 효과는 유지되어야 함)
        if self.hit_target:
            target_prefix = 'top_paddle' if self.shrunk_target_is_top else 'bottom_paddle'

            # 축소 애니메이션 (명중 직후 0.3초)
            if self.is_shrinking:
                self.shrink_anim_timer += dt
                t = min(1.0, self.shrink_anim_timer / self.SHRINK_ANIM_DURATION)
                # Ease-out 커브: 빠르게 줄어들다 천천히 마무리
                t_ease = 1 - (1 - t) ** 2
                scale = 1.0 - 0.5 * t_ease  # 1.0 → 0.5
                game_state[f'{target_prefix}_shrink_scale'] = scale
                if t >= 1.0:
                    self.is_shrinking = False
                    game_state[f'{target_prefix}_shrink_scale'] = 0.5

            # 축소 유지 기간 (shrink_timer 카운트다운)
            if not self.is_shrinking and not self.is_restoring and self.shrink_timer > 0:
                self.shrink_timer -= dt
                if self.shrink_timer <= 0:
                    # 복원 애니메이션 시작
                    self.is_restoring = True
                    self.restore_anim_timer = 0.0

            # 복원 애니메이션 (효과 종료 후 0.3초)
            if self.is_restoring:
                self.restore_anim_timer += dt
                t = min(1.0, self.restore_anim_timer / self.RESTORE_ANIM_DURATION)
                # Ease-in 커브: 천천히 시작해서 빠르게 원래 크기로
                t_ease = t ** 2
                scale = 0.5 + 0.5 * t_ease  # 0.5 → 1.0
                game_state[f'{target_prefix}_shrink_scale'] = scale
                if t >= 1.0:
                    # 복원 완료
                    self.is_restoring = False
                    game_state[f'{target_prefix}_shrink'] = False
                    game_state[f'{target_prefix}_shrink_scale'] = 1.0
                    self.hit_target = False
                    self.shrunk_target_is_top = None

        # 파티클 업데이트 (is_active와 관계없이)
        for p in self.magic_particles[:]:
            p['x'] += p['vx'] * dt * 60
            p['y'] += p['vy'] * dt * 60
            p['life'] -= dt
            p['alpha'] = max(0, int(255 * (p['life'] / 1.0)))
            if p['life'] <= 0:
                self.magic_particles.remove(p)

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        # 투사체 이동
        if self.projectile_active and not self.hit_target:
            self.projectile_y += self.projectile_vy * dt * 60

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
                # 마법결계 면역 체크 - 면역 상태면 축소 효과 차단
                _immunity_side = 'top' if target_paddle.is_top else 'bottom'
                if game_state.get(f'magic_immunity_{_immunity_side}', False):
                    self.projectile_active = False
                    # 패링 이펙트 이벤트 전달
                    if 'barrier_block_events' not in game_state:
                        game_state['barrier_block_events'] = []
                    game_state['barrier_block_events'].append({
                        'skill_korean_name': self.korean_name,
                        'caster_is_top': getattr(self, 'caster_is_top', True),
                        'caster_x': caster_paddle.x + getattr(caster_paddle, 'width', 80) / 2,
                        'caster_y': caster_paddle.y + getattr(caster_paddle, 'height', 10) / 2,
                        'target_x': target_paddle.x + getattr(target_paddle, 'width', 80) / 2,
                        'target_y': target_paddle.y + getattr(target_paddle, 'height', 10) / 2,
                    })
                    return

                # 명중!
                self.hit_target = True
                self.projectile_active = False
                self.shrink_timer = 4.0  # 4초 지속
                self.shrunk_target_is_top = target_paddle.is_top  # 축소된 타겟 기억

                # 타겟 패들 축소 애니메이션 시작 (0.3초에 걸쳐 점진적으로)
                target_prefix = 'top_paddle' if target_paddle.is_top else 'bottom_paddle'
                game_state[f'{target_prefix}_shrink'] = True
                game_state[f'{target_prefix}_shrink_scale'] = 1.0  # 애니메이션 시작: 원래 크기
                self.is_shrinking = True
                self.shrink_anim_timer = 0.0
                self.is_restoring = False
                self.restore_anim_timer = 0.0

                # 명중 시 사운드 재생
                try:
                    if not hasattr(DwarfMagic, '_hit_sound'):
                        hit_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "sounds", "smallboyhit.wav")
                        DwarfMagic._hit_sound = pygame.mixer.Sound(hit_path) if os.path.exists(hit_path) else None
                    if DwarfMagic._hit_sound:
                        DwarfMagic._hit_sound.play()
                except Exception:
                    pass

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
                surf = _psurf((size * 2, size * 2), pygame.SRCALPHA)
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
                surf = _psurf((p_size * 2, p_size * 2), pygame.SRCALPHA)
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
                surf = _psurf((size * 2, size * 2), pygame.SRCALPHA)
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
        # 축소/복원 애니메이션 초기화
        self.shrink_anim_timer = 0.0
        self.restore_anim_timer = 0.0
        self.is_shrinking = False
        self.is_restoring = False
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
            description="공이 요사스러운 도깨비불로 변해 종잡을 수 없이 날뛴다",
            trigger=SkillTrigger.ON_COOLDOWN,
            cooldown=26.0,
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
            self.face_alpha_pulse = 0.5 + 0.3 * _sin(self.glitch_timer * 12)
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

        elif self.phase == self.PHASE_RELEASE:
            # === 정지 해제 - 도깨비불 상태 적용 (Y축 완만하게) ===
            ball.vx = self.original_ball_vx * 1.2
            # 방향 강제: 캐스터 반대쪽으로 (Y속도는 완만하게 - 궤도 감상 시간 확보)
            if self.caster_is_top:
                ball.vy = abs(self.original_ball_vy) * 0.7   # 아래로 (느리게)
                ball.y = max(ball.y, 80)
            else:
                ball.vy = -abs(self.original_ball_vy) * 0.7  # 위로 (느리게)
                ball.y = min(ball.y, 670)
            game_state['ball_on_fire'] = True
            game_state['dokkaebi_ball'] = True
            game_state['hell_fire_phase'] = self.PHASE_ACTIVE

            self.phase = self.PHASE_ACTIVE
            self.phase_timer = 0.0
            self.dokkaebi_time = 0

        elif self.phase == self.PHASE_ACTIVE:
            # === 도깨비불 활성 상태 - 도깨비가 장난치는 듯한 불규칙 궤도 ===
            self.flame_intensity = max(0, self.flame_intensity - dt * 0.3)

            self.dokkaebi_time = getattr(self, 'dokkaebi_time', 0) + dt
            t = self.dokkaebi_time

            # 초반 0.5초는 보호 시간 (상대쪽으로 직진 후 점점 장난 시작)
            ramp = min(1.0, t / 0.5)  # 0→1 (0.5초에 걸쳐 점진적 전환)

            # 현재 공 속력 보존 (궤도만 변경, 속력은 유지)
            speed = math.sqrt(ball.vx ** 2 + ball.vy ** 2)
            if speed < 1:
                speed = 200

            # --- 패턴 1: ∞ 팔자(리사주) 궤도 ---
            lissajous_fx = _sin(t * 4.0) * 200 * dt * ramp
            lissajous_fy = _sin(t * 8.0) * 80 * dt * ramp
            ball.vx += lissajous_fx
            ball.vy += lissajous_fy

            # --- 패턴 2: 빙글빙글 나선 회전 ---
            spin_speed = (1.5 + _sin(t * 1.3) * 1.0) * ramp  # ramp로 점진적 시작
            spin_angle = spin_speed * dt
            cos_s = _cos(spin_angle)
            sin_s = _sin(spin_angle)
            vx_rot = ball.vx * cos_s - ball.vy * sin_s
            vy_rot = ball.vx * sin_s + ball.vy * cos_s
            ball.vx = vx_rot
            ball.vy = vy_rot

            # --- 패턴 3: 돌발 장난 (보호 시간 이후에만) ---
            if ramp >= 1.0:
                if random.random() < 0.04:
                    big_angle = random.uniform(0.8, 1.6)  # ~45~90도
                    if random.random() < 0.5:
                        big_angle = -big_angle
                    cos_b = _cos(big_angle)
                    sin_b = _sin(big_angle)
                    old_vx = ball.vx
                    ball.vx = old_vx * cos_b - ball.vy * sin_b
                    ball.vy = old_vx * sin_b + ball.vy * cos_b
                elif random.random() < 0.03:
                    burst = random.uniform(1.2, 1.5)
                    ball.vx *= burst
                    ball.vy *= burst

            # === 인게임 호위무사: 초반 1초만 상대 방향 보호, 이후 자유 이동 ===
            if game_state.get('is_ingame_bodyguard', False) and t < 1.0:
                desired_vy_sign = 1.0 if self.caster_is_top else -1.0
                if ball.vy * desired_vy_sign < 0:
                    ball.vy = abs(ball.vy) * desired_vy_sign * 0.3

            # Y축 속도 감쇠 (도깨비불이 X축으로 노는 느낌, Y축은 천천히 진행)
            abs_vx = abs(ball.vx)
            abs_vy = abs(ball.vy)
            if abs_vy > abs_vx * 1.2:
                ball.vy *= (1.0 - 0.8 * dt)  # vy 감쇠

            # 속력 범위 제한
            cur_speed = math.sqrt(ball.vx ** 2 + ball.vy ** 2)
            min_speed = speed * 0.7
            max_speed = speed * 1.5
            if cur_speed > max_speed and cur_speed > 0:
                scale = max_speed / cur_speed
                ball.vx *= scale
                ball.vy *= scale
            elif cur_speed < min_speed and cur_speed > 0:
                scale = min_speed / cur_speed
                ball.vx *= scale
                ball.vy *= scale

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

        # === 정지 중 이펙트 (Ultra Premium) ===
        if self.phase == self.PHASE_FREEZE:
            t = self.glitch_timer
            pulse = 0.5 + 0.3 * _sin(t * 8)

            # 어두운 푸른 오버레이 (맥동 + 비네팅)
            darkness = _get_fullscreen_surface()
            darkness.fill((0, 8, 25, int(190 * pulse)))
            screen.blit(darkness, (0, 0))

            # 방사형 에너지 파동 (공 중심에서 퍼져나감)
            for wave_i in range(3):
                wave_phase = (t * 1.5 + wave_i * 0.4) % 1.5
                if wave_phase < 1.2:
                    wave_r = int(40 + wave_phase * 250)
                    wave_a = int(40 * (1.0 - wave_phase / 1.2))
                    if wave_a > 0:
                        wave_surf = _psurf((wave_r * 2, wave_r * 2), pygame.SRCALPHA)
                        pygame.draw.circle(wave_surf, (70, 180, 255, wave_a),
                                          (wave_r, wave_r), wave_r, max(1, 3 - wave_i))
                        screen.blit(wave_surf, (bx - wave_r, by - wave_r),
                                   special_flags=pygame.BLEND_ADD)

            # === 도깨비 얼굴 (고퀄리티 + 글리치) ===
            self._draw_dokkaebi_face(screen, bx, by)

            # 공 주변 다층 불꽃 아우라
            for aura_layer in range(3):
                aura_size = 65 + aura_layer * 18 + int(20 * _sin(t * 6 + aura_layer * 1.5))
                aura_surf = _psurf((aura_size * 2, aura_size * 2), pygame.SRCALPHA)
                aura_alpha = int((50 - aura_layer * 12) * pulse)
                ar = int(60 + 40 * _sin(t * 4.0 + aura_layer))
                ag = int(170 + 50 * _sin(t * 5.5 + aura_layer * 0.8))
                if aura_alpha > 0:
                    pygame.draw.circle(aura_surf, (ar, ag, 255, aura_alpha),
                                      (aura_size, aura_size), aura_size)
                    screen.blit(aura_surf, (bx - aura_size, by - aura_size),
                               special_flags=pygame.BLEND_ADD)

            # 간헐적 화면 글리치 라인 (개선 - 색상 다양화)
            if random.random() < 0.2:
                gy = random.randint(0, 750)
                gh = random.randint(1, 5)
                glitch_bar = _psurf((760, gh), pygame.SRCALPHA)
                g_color = random.choice([
                    (80, 200, 255, random.randint(25, 70)),
                    (255, 80, 50, random.randint(15, 40)),
                    (120, 255, 200, random.randint(15, 35)),
                ])
                glitch_bar.fill(g_color)
                screen.blit(glitch_bar, (random.randint(-8, 8), gy))

            # 화면 모서리 어둡게 (비네팅 효과)
            corner_size = 120
            for corner_x, corner_y in [(0, 0), (760 - corner_size, 0), (0, 750 - corner_size), (760 - corner_size, 750 - corner_size)]:
                vignette = _psurf((corner_size, corner_size), pygame.SRCALPHA)
                vignette.fill((0, 5, 15, int(60 * pulse)))
                screen.blit(vignette, (corner_x, corner_y))

        # === 도깨비불 활성 상태 이펙트 (Ultra Premium) ===
        elif self.phase == self.PHASE_ACTIVE:
            # 화면 푸른 틴트 (미세한 맥동)
            if self.flame_intensity > 0:
                dokkaebi_t = getattr(self, 'dokkaebi_time', 0)
                overlay = _get_fullscreen_surface()
                tint_pulse = 0.7 + 0.3 * _sin(dokkaebi_t * 3.0)
                overlay.fill((40, 130, 240, int(25 * self.flame_intensity * tint_pulse)))
                screen.blit(overlay, (0, 0))

            # 도깨비불 파티클 (고퀄리티 - 다층 발광 + 꼬리)
            for p in self.fire_particles:
                if p['size'] > 1:
                    life_ratio = max(0, p['life'] / 0.5)
                    # 색상 그라디언트 (수명에 따라 변화)
                    r = int(80 + 120 * (1.0 - life_ratio))
                    g = int(200 * life_ratio)
                    b = 255
                    alpha = int(220 * life_ratio)
                    sz = int(p['size'])

                    if alpha > 0 and sz > 0:
                        # 외곽 글로우 (큰 반투명 원)
                        glow_sz = sz + 4
                        glow_surf = _psurf((glow_sz * 2, glow_sz * 2), pygame.SRCALPHA)
                        pygame.draw.circle(glow_surf, (r // 2, g // 2, b, alpha // 4),
                                          (glow_sz, glow_sz), glow_sz)
                        screen.blit(glow_surf, (int(p['x'] - glow_sz), int(p['y'] - glow_sz)),
                                   special_flags=pygame.BLEND_ADD)

                        # 메인 파티클
                        main_surf = _psurf((sz * 2, sz * 2), pygame.SRCALPHA)
                        pygame.draw.circle(main_surf, (r, g, b, alpha),
                                          (sz, sz), sz)
                        screen.blit(main_surf, (int(p['x'] - sz), int(p['y'] - sz)),
                                   special_flags=pygame.BLEND_ADD)

                        # 코어 하이라이트 (밝은 중심)
                        if sz > 3:
                            core_sz = max(1, sz // 3)
                            core_surf = _psurf((core_sz * 2, core_sz * 2), pygame.SRCALPHA)
                            pygame.draw.circle(core_surf, (200, 250, 255, min(255, int(alpha * 1.2))),
                                              (core_sz, core_sz), core_sz)
                            screen.blit(core_surf, (int(p['x'] - core_sz), int(p['y'] - core_sz)),
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
            description="맹렬한 돌진으로 상대를 들이받아 기절시킨다",
            trigger=SkillTrigger.ON_COOLDOWN,
            cooldown=28.0,
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
        predicted_x = max(self.GAME_LEFT + target_paddle.width // 2,
                         min(self.GAME_RIGHT - target_paddle.width // 2, predicted_x))

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
                        'vx': _cos(angle) * speed,
                        'vy': _sin(angle) * speed,
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
                    p['x'] += p['vx'] * dt * 60
                    p['y'] += p['vy'] * dt * 60
                    p['vy'] += 0.5 * dt * 60  # 강한 중력
                    p['life'] -= dt * 60
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
            game_state['horn_charge_x_offset'] = 0  # X 오프셋도 명시적으로 0
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
        game_state['horn_charge_impact_shockwave'] = None  # 착지 충격파 이펙트 초기화
        game_state['horn_charge_explosion'] = None  # 폭발 파티클 초기화
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
                        ring_surf = _psurf((radius * 2 + 10, radius * 2 + 10), pygame.SRCALPHA)
                        pygame.draw.circle(ring_surf, (255, 100, 50, ring_alpha),
                                         (radius + 5, radius + 5), radius, 5)
                        screen.blit(ring_surf, (int(center_x - radius - 5), int(center_y - radius - 5)))

        # 스턴 별 표시는 pingfighter.py의 _draw_arena_stun_stars() / 일반 스턴 별로 통합 처리


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
            description="보이지 않는 실로 상대를 끌어당겨 달콤한 입맞춤을 선사한다",
            trigger=SkillTrigger.ON_COOLDOWN,
            cooldown=27.0,
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
            h['x'] += _sin(h['wobble']) * 20 * dt
            h['life'] -= dt * 0.8
        self.kiss_hearts = [h for h in self.kiss_hearts if h['life'] > 0]

        for sp in self.kiss_sparkles:
            sp['life'] -= dt * 2
        self.kiss_sparkles = [sp for sp in self.kiss_sparkles if sp['life'] > 0]

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        game_state['target_puppeted'] = False

        # 연화 고정 해제 (None 안전)
        if caster_paddle is not None:
            caster_prefix = 'top_paddle' if caster_paddle.is_top else 'bottom_paddle'
        else:
            caster_prefix = 'top_paddle' if getattr(self, 'caster_is_top', True) else 'bottom_paddle'
        game_state[f'{caster_prefix}_locked'] = False

        # 타겟 패들 고정 해제 (None 안전)
        if target_paddle is not None:
            target_prefix = 'top_paddle' if target_paddle.is_top else 'bottom_paddle'
        else:
            target_prefix = 'bottom_paddle' if getattr(self, 'caster_is_top', True) else 'top_paddle'
        game_state[f'{target_prefix}_locked'] = False

        # 상대 원래 위치로 확실히 복귀
        if target_paddle is not None:
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

                wave = _sin(prog * math.pi * 3 + s['wave']) * wave_strength

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
                sparkle_surf = _psurf((size * 2, size * 2), pygame.SRCALPHA)
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
                end_x = center_x + _cos(angle) * length
                end_y = center_y + _sin(angle) * length
                pygame.draw.line(screen, (255, 200, 220, 100),
                               (int(center_x), int(center_y)),
                               (int(end_x), int(end_y)), 1)

    def _draw_heart(self, screen, x, y, size, alpha):
        """하트 모양 그리기"""
        heart_surf = _psurf((int(size * 2), int(size * 2)), pygame.SRCALPHA)
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
            description="저주받은 인형이 상대의 감각을 뒤집고, 수호 인형이 공을 가로막는다",
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
                'x': target_cx + _cos(angle) * distance,
                'y': target_torso_y + _sin(angle) * distance,
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
            float_y = _sin(doll['float_offset']) * 8  # 위아래 둥실둥실
            doll['x'] = target_cx + _cos(doll['base_angle']) * doll['distance']
            doll['y'] = target_torso_y + _sin(doll['base_angle']) * doll['distance'] * 0.5 + float_y
            doll['rotation'] += _sin(doll['wobble']) * 3

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
                float_y = _sin(guardian['wobble']) * 5
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
                        # 벽 충돌 사운드 재생
                        try:
                            if not hasattr(DollCurse, '_wall_sound'):
                                wall_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "sounds", "wall_hit.wav")
                                DollCurse._wall_sound = pygame.mixer.Sound(wall_path) if os.path.exists(wall_path) else None
                            if DollCurse._wall_sound:
                                DollCurse._wall_sound.play()
                        except Exception:
                            pass

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
                    'x': caster_center_x + _cos(angle) * dist,
                    'y': caster_center_y + _sin(angle) * dist * 0.8,
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

        # 연화(caster) 고정 해제 (None 안전)
        if caster_paddle is not None:
            caster_prefix = 'top_paddle' if caster_paddle.is_top else 'bottom_paddle'
        else:
            caster_prefix = 'top_paddle' if getattr(self, 'caster_is_top', True) else 'bottom_paddle'
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
            overlay = _get_fullscreen_surface()
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
                flame_surf = _psurf((size * 2, size * 2), pygame.SRCALPHA)
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
            aura_surf = _psurf((aura_w, aura_h), pygame.SRCALPHA)
            # 외부 오라 (진한 빨간색, 펄스 효과)
            pulse = 0.7 + 0.3 * _sin(pygame.time.get_ticks() * 0.008)
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
                    flash_surf = _psurf((flash_size * 2, flash_size * 2), pygame.SRCALPHA)
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
                        light_pulse = 0.6 + 0.4 * _sin(time_tick * 0.006 + guardian['wobble'])
                        light_alpha = int(40 * spawn_alpha * light_pulse)

                        # 빛 서피스 생성 (전체 화면 크기, 캐시 재사용)
                        light_surf = _get_fullscreen_surface()

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
                        glow_surf = _psurf((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
                        pygame.draw.circle(glow_surf, (255, 200, 230, int(150 * spawn_alpha)),
                                         (glow_size, glow_size), glow_size)
                        pygame.draw.circle(glow_surf, (255, 255, 255, int(200 * spawn_alpha)),
                                         (glow_size, glow_size), int(glow_size * 0.5))
                        screen.blit(glow_surf, (int(eye_x) - glow_size, int(eye_y) - glow_size))

                # === 외부 마법진/보호 오라 (인형 뒤에) - 고퀄리티 업그레이드 ===
                aura_pulse = 0.7 + 0.3 * _sin(time_tick * 0.008 + guardian['wobble'])
                magic_size = int(60 * s * aura_pulse)
                magic_surf = _psurf((magic_size * 2 + 20, magic_size * 2 + 20), pygame.SRCALPHA)
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
                    rx = mc + int(_cos(rune_angle) * rune_dist)
                    ry = mc + int(_sin(rune_angle) * rune_dist)
                    # 작은 삼각형 룬
                    tri_size = int(6 * s)
                    tri_points = []
                    for ti in range(3):
                        ta = rune_angle + ti * (math.pi * 2 / 3)
                        tri_points.append((rx + int(_cos(ta) * tri_size),
                                         ry + int(_sin(ta) * tri_size)))
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
                    star_points.append((mc + int(_cos(outer_angle) * star_size),
                                       mc + int(_sin(outer_angle) * star_size)))
                    star_points.append((mc + int(_cos(inner_angle) * star_size * 0.4),
                                       mc + int(_sin(inner_angle) * star_size * 0.4)))
                pygame.draw.polygon(magic_surf, (255, 120, 160, int(40 * spawn_alpha * aura_pulse)),
                                  star_points)
                pygame.draw.polygon(magic_surf, (220, 90, 130, int(80 * spawn_alpha)),
                                  star_points, 1)

                # 5. 회전하는 점선 원
                num_dots = 12
                for di in range(num_dots):
                    dot_angle = rune_rotation * 1.5 + di * (math.pi * 2 / num_dots)
                    dot_dist = magic_size * 0.92
                    dot_x = mc + int(_cos(dot_angle) * dot_dist)
                    dot_y = mc + int(_sin(dot_angle) * dot_dist)
                    dot_size = int(3 * s * (0.7 + 0.3 * _sin(time_tick * 0.01 + di)))
                    pygame.draw.circle(magic_surf, (255, 180, 200, int(120 * spawn_alpha)),
                                     (dot_x, dot_y), dot_size)

                screen.blit(magic_surf, (gx - mc, gy - mc))

                # === 그림자 (입체감) ===
                shadow_w, shadow_h = max(1, int(40 * s)), max(1, int(12 * s))
                shadow_surf = _psurf((shadow_w, shadow_h), pygame.SRCALPHA)
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
                    sway1 = _sin(time_tick * 0.003 + thread_i * 0.8) * 20
                    sway2 = _sin(time_tick * 0.004 + thread_i * 1.2 + 1) * 15

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
                        p_pulse = 0.6 + 0.4 * _sin(time_tick * 0.008 + thread_i)
                        p_size = int(4 * p_pulse)
                        px, py = points[particle_idx]
                        p_surf = _psurf((p_size * 2, p_size * 2), pygame.SRCALPHA)
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
                arm_wobble = _sin(time_tick * 0.003 + g_idx * 2) * 4
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
                hg_surf = _psurf((hg_size * 2, hg_size * 2), pygame.SRCALPHA)
                hg_pulse = 0.6 + 0.4 * _sin(time_tick * 0.005 + g_idx)
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
                        ox1 = gx + int(_cos(a) * (head_r + 1))
                        oy1 = head_y + int(_sin(a) * (head_r + 1))
                        a2 = math.radians((ai + 1) * 15)
                        ox2 = gx + int(_cos(a2) * (head_r + 1))
                        oy2 = head_y + int(_sin(a2) * (head_r + 1))
                        pygame.draw.line(screen, stitch_dark, (ox1, oy1), (ox2, oy2), 1)

                # --- 머리카락 (긴 실 가닥 + 곡선) ---
                hair_c = (55, 32, 42)
                hair_highlight = (85, 55, 68)
                hair_top = head_y - head_r
                # 상단 짧은 가닥 (5가닥)
                for hi in range(-2, 3):
                    hx = gx + int(hi * 5 * s)
                    sway = _sin(time_tick * 0.004 + hi * 0.7) * 3
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
                        sway = _sin(time_tick * 0.003 + hi + side * 2) * 4
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
                eye_pulse = 0.6 + 0.4 * _sin(time_tick * 0.007 + g_idx)
                eg_size = max(1, int(10 * s))
                eg_surf = _psurf((eg_size * 2, eg_size * 2), pygame.SRCALPHA)
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
                tear_surf = _psurf((max(1, int(4*s)), max(1, int(10*s))), pygame.SRCALPHA)
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
                m_sway = _sin(time_tick * 0.004 + g_idx) * 3
                pygame.draw.line(screen, stitch_dark, (gx - int(12*s), mouth_y),
                                (gx - int(15*s) + int(m_sway), mouth_y + int(8*s)), 1)
                pygame.draw.line(screen, stitch_dark, (gx + int(12*s), mouth_y),
                                (gx + int(15*s) - int(m_sway), mouth_y + int(8*s)), 1)

                # --- 볼 홍조 ---
                blush_alpha = int(90 * spawn_alpha)
                bw, bh = max(1, int(10*s)), max(1, int(6*s))
                blush_surf = _psurf((bw, bh), pygame.SRCALPHA)
                pygame.draw.ellipse(blush_surf, (210, 90, 110, blush_alpha), blush_surf.get_rect())
                screen.blit(blush_surf, (gx - int(18*s), head_y + int(3*s)))
                screen.blit(blush_surf, (gx + int(8*s), head_y + int(3*s)))

                # --- 몸에서 늘어진 실 (찢어진 느낌) ---
                for ti in range(3):
                    t_x = gx + int((-10 + ti * 10) * s)
                    t_base_y = gy + int(24 * s)
                    t_sway = _sin(time_tick * 0.004 + ti + g_idx) * 4
                    t_len = int((6 + ti * 3) * s)
                    pygame.draw.line(screen, stitch_dark, (t_x, t_base_y),
                                    (t_x + int(t_sway), t_base_y + t_len), 1)

                # --- 저주 파티클 (어둡고 은은한 오라) ---
                num_particles = 6
                for pi in range(num_particles):
                    p_angle = (time_tick * 0.002 + pi * (math.pi * 2 / num_particles)) % (math.pi * 2)
                    p_dist = int(48 * s) + _sin(time_tick * 0.004 + pi * 1.3) * 10
                    px = gx + int(_cos(p_angle) * p_dist)
                    py = gy + int(_sin(p_angle) * p_dist * 0.6)
                    p_size = max(1, int(3 * s * (0.4 + 0.6 * _sin(time_tick * 0.006 + pi))))
                    p_alpha = max(0, min(255, int(140 * spawn_alpha * (0.4 + 0.6 * _sin(time_tick * 0.005 + pi)))))
                    p_surf = _psurf((p_size * 2, p_size * 2), pygame.SRCALPHA)
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
                aura_pulse = 0.6 + 0.4 * _sin(time_tick * 0.006 + doll_idx)
                aura_size = int(35 * s * aura_pulse)
                if aura_size > 0:
                    aura_surf = _psurf((aura_size * 2, aura_size * 2), pygame.SRCALPHA)
                    for ar in range(aura_size, 0, -3):
                        a_alpha = int(35 * (ar / aura_size) * aura_pulse)
                        pygame.draw.circle(aura_surf, (180, 40, 90, a_alpha), (aura_size, aura_size), ar)
                    screen.blit(aura_surf, (dx - aura_size, dy - aura_size))

                # === 그림자 ===
                shadow_w, shadow_h = int(24 * s), int(8 * s)
                if shadow_w > 0 and shadow_h > 0:
                    shadow_surf = _psurf((shadow_w, shadow_h), pygame.SRCALPHA)
                    pygame.draw.ellipse(shadow_surf, (0, 0, 0, 60), shadow_surf.get_rect())
                    screen.blit(shadow_surf, (dx - shadow_w // 2, dy + int(20 * s)))

                # === 마리오네트 실 (머리 위로 수렴하는 3가닥) ===
                thread_top_y = dy - int(50 * s)
                for ti, tx_off in enumerate([-5, 0, 5]):
                    t_sway = _sin(time_tick * 0.004 + ti * 1.2 + doll_idx) * 4
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
                    a_sway = _sin(time_tick * 0.005 + arm_side + doll_idx) * 3
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
                        ox1 = dx + int(_cos(a) * (head_r + 1))
                        oy1 = head_y + int(_sin(a) * (head_r + 1))
                        a2 = math.radians((ai + 1) * 20)
                        ox2 = dx + int(_cos(a2) * (head_r + 1))
                        oy2 = head_y + int(_sin(a2) * (head_r + 1))
                        pygame.draw.line(screen, c_stitch_dk, (ox1, oy1), (ox2, oy2), 1)

                # --- 머리카락 (상단 + 측면 가닥) ---
                hair_c = (42, 24, 34)
                hair_hl = (70, 45, 58)
                h_top = head_y - head_r
                for hi in range(-2, 3):
                    hhx = dx + int(hi * 4 * s)
                    h_len = int((7 + abs(hi) * 1.5) * s)
                    sway = _sin(time_tick * 0.004 + hi * 0.8 + doll_idx) * 2
                    pygame.draw.line(screen, hair_c, (hhx, h_top + int(2*s)),
                                    (int(hhx + sway), h_top - h_len), 2)
                # 측면 긴 머리
                for side in [-1, 1]:
                    b_x = dx + int(side * (head_r - 2*s))
                    b_y = head_y + int(2*s)
                    sway = _sin(time_tick * 0.003 + side + doll_idx) * 3
                    pygame.draw.line(screen, hair_c, (b_x, b_y),
                                    (b_x + int(side * 3*s) + int(sway), b_y + int(14*s)), 2)

                # --- X 눈 (저주 글로우 + 매듭점) ---
                eye_pulse = 0.6 + 0.4 * _sin(time_tick * 0.008 + doll_idx)
                for eye_side in [-1, 1]:
                    ex = dx + int(eye_side * 5 * s)
                    ey = head_y - int(1 * s)
                    xs = int(4 * s)
                    # 글로우
                    eg_sz = max(1, int(8 * s * eye_pulse))
                    eg_surf = _psurf((eg_sz * 2, eg_sz * 2), pygame.SRCALPHA)
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
                blush_surf = _psurf((b_sz * 2, b_h), pygame.SRCALPHA)
                pygame.draw.ellipse(blush_surf, (200, 85, 105, 55), blush_surf.get_rect())
                screen.blit(blush_surf, (dx - int(11*s), head_y + int(2*s)))
                screen.blit(blush_surf, (dx + int(3*s), head_y + int(2*s)))

                # --- 늘어진 실 (몸통 하단) ---
                for ti in range(2):
                    tx = dx + int((-4 + ti * 8) * s)
                    t_base = dy + int(18 * s)
                    t_sw = _sin(time_tick * 0.005 + ti + doll_idx) * 3
                    pygame.draw.line(screen, c_stitch_dk, (tx, t_base),
                                    (tx + int(t_sw), t_base + int(5*s)), 1)

                # --- 저주 파티클 ---
                for pi in range(4):
                    p_angle = (time_tick * 0.003 + pi * 1.57 + doll_idx) % (math.pi * 2)
                    p_dist = int(25 * s) + _sin(time_tick * 0.005 + pi) * 5
                    px = dx + int(_cos(p_angle) * p_dist)
                    py = dy + int(_sin(p_angle) * p_dist * 0.6)
                    p_size = max(1, int(2 * s * (0.5 + 0.5 * _sin(time_tick * 0.006 + pi))))
                    p_alpha = max(0, min(255, int(110 * (0.4 + 0.6 * _sin(time_tick * 0.005 + pi)))))
                    p_surf = _psurf((p_size * 2, p_size * 2), pygame.SRCALPHA)
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
            description="맹렬한 용의 화염이 공을 집어삼키며 불태운다",
            trigger=SkillTrigger.ON_COOLDOWN,
            cooldown=20.0,
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
                        ball.vy = abs(boosted_speed * _cos(angle_offset))
                    else:
                        ball.vy = -abs(boosted_speed * _cos(angle_offset))

                    # 좌우 넉백: 파티클 → 공 방향으로 밀어냄
                    dx = ball.x - p['x']
                    knockback_strength = random.uniform(3.0, 6.0)
                    if abs(dx) > 1:
                        # 파티클 기준으로 공이 오른쪽이면 오른쪽으로, 왼쪽이면 왼쪽으로 넉백
                        knockback_dir = 1 if dx > 0 else -1
                        ball.vx = knockback_dir * knockback_strength + boosted_speed * _sin(angle_offset)
                    else:
                        # 정중앙이면 랜덤 방향 넉백
                        ball.vx = random.choice([-1, 1]) * knockback_strength + boosted_speed * _sin(angle_offset)

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
                        r = int(200 + 55 * _sin(phase * math.pi))
                        g = int(40 + 30 * _sin(phase * math.pi * 2))
                        b = 0
                        alpha = int(120 * life_ratio)
                    elif layer == 2:  # 중간 - 주황
                        r = 255
                        g = int(100 + 80 * _sin(phase * math.pi * 1.5))
                        b = int(20 * _sin(phase * math.pi))
                        alpha = int(180 * life_ratio)
                    elif layer == 3:  # 내부 - 밝은 노랑
                        r = 255
                        g = int(200 + 55 * _sin(phase * math.pi * 2))
                        b = int(50 + 100 * _sin(phase * math.pi))
                        alpha = int(200 * life_ratio)
                    else:  # 핵심 - 흰색
                        r, g, b = 255, 255, int(200 + 55 * _sin(phase * math.pi))
                        alpha = int(220 * life_ratio)

                    # 색상값 클램핑
                    r = max(0, min(255, r))
                    g = max(0, min(255, g))
                    b = max(0, min(255, b))
                    alpha = max(0, min(255, alpha))

                    if layer_size > 1 and alpha > 5:
                        surf_size = layer_size * 2 + 4
                        surf = _psurf((surf_size, surf_size), pygame.SRCALPHA)
                        center = surf_size // 2

                        # 그라데이션 원 효과
                        for gr in range(layer_size, 0, -2):
                            grad_alpha = int(alpha * (gr / layer_size) * 0.7)
                            grad_alpha = max(0, min(255, grad_alpha))
                            pygame.draw.circle(surf, (r, g, b, grad_alpha), (center, center), gr)

                        # 흔들림 효과 (레이어별 다른 흔들림)
                        wobble_x = _sin(phase * 10 + layer) * (2 + layer * 0.5)
                        wobble_y = _cos(phase * 8 + layer * 0.7) * (1.5 + layer * 0.3)

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

                        trail_surf = _psurf((trail_size * 2, trail_size * 2), pygame.SRCALPHA)
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
                    spark_surf = _psurf((spark_size * 2 + 2, spark_size * 2 + 2), pygame.SRCALPHA)
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
            description="거대한 날갯짓이 폭풍을 일으켜 공의 궤적을 뒤흔든다",
            trigger=SkillTrigger.ON_BALL_HIT,
            cooldown=15.0,
            duration=2.5,
            hero_id="ignis"
        )
        self.wind_direction = 0
        self.wind_particles = []
        self.flying_dragon = None  # 날아가는 드래곤 엔티티

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        # 랜덤 바람 방향
        self.wind_direction = random.choice([-1, 1])
        game_state['wind_force'] = self.wind_direction * 3

        # 날씨 강풍 이벤트 시작 (스킬 종료 시 강제 종료됨)
        if WEATHER_EVENT_AVAILABLE:
            force_start_gust_event(direction=self.wind_direction, duration=99)  # 스킬 종료 시 force_end_weather_event로 종료
            play_weather_sound("gust")

        # 🐉 날아가는 드래곤 생성 - 바람 방향으로 맵의 끝에서 끝으로 횡단
        is_caster_top = getattr(self, 'caster_is_top', caster_paddle.is_top)
        if is_caster_top:
            dragon_y = random.uniform(200, 350)
        else:
            dragon_y = random.uniform(400, 550)

        dragon_start_x = 20.0 if self.wind_direction == 1 else 740.0
        self.flying_dragon = {
            'x': dragon_start_x,
            'y': float(dragon_y),
            'base_y': float(dragon_y),
            'vx': self.wind_direction * 330.0,  # 약 1.8초에 맵 횡단 (50% 빠르게)
            'wing_time': 0.0,
            'direction': self.wind_direction,    # 비행 방향 = 바람 방향
            'hit_cooldown': 0.0,
            'active': True,
            'caster_is_top': is_caster_top,      # 시전자 진영 (충돌 판정용)
        }

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

        # 🐉 날아가는 드래곤 업데이트
        if self.flying_dragon and self.flying_dragon.get('active'):
            dragon = self.flying_dragon
            dragon['x'] += dragon['vx'] * dt
            dragon['wing_time'] += dt
            # Y축 부드러운 파도 움직임 (base_y 기준 ±8px 진동)
            dragon['y'] = dragon['base_y'] + _sin(dragon['wing_time'] * 2.5) * 8

            # 맵 밖으로 나가면 비활성화
            if dragon['x'] < -120 or dragon['x'] > 880:
                dragon['active'] = False

            # 공과 충돌 체크
            if dragon['hit_cooldown'] > 0:
                dragon['hit_cooldown'] -= dt

            # 드래곤 히트박스 (에인션트 드래곤 크기에 맞춤)
            dragon_half_w, dragon_half_h = 65, 35
            dx = abs(ball.x - dragon['x'])
            dy = abs(ball.y - dragon['y'])
            hit_dist = dx < dragon_half_w and dy < dragon_half_h

            if dragon['hit_cooldown'] <= 0 and hit_dist:
                # 시전자측 공 판별: 시전자 방향으로 날아가는 공은 무시
                caster_top = dragon.get('caster_is_top', False)
                ball_going_to_caster = (caster_top and ball.vy < 0) or (not caster_top and ball.vy > 0)

                if not ball_going_to_caster:
                    pass  # 시전자가 공격 중인 공 (상대를 향해 날아감) → 무시
                else:
                    # 상대가 시전자를 향해 보낸 공 → 충돌! 상대쪽으로 튕겨냄
                    current_speed = math.hypot(ball.vx, ball.vy)
                    if current_speed < 8.0:
                        current_speed = 10.0
                    boosted_speed = current_speed * random.uniform(1.4, 1.7)

                    # 공을 상대 방향(시전자 반대쪽)으로 튕겨냄
                    toward_opponent_vy = 1.0 if caster_top else -1.0
                    ball.vx = dragon['direction'] * abs(boosted_speed) * 0.5
                    ball.vy = toward_opponent_vy * abs(boosted_speed) * 0.85
                    dragon['hit_cooldown'] = 0.5
                    # 벽 충돌 사운드 재생 (에너지볼 벽 충돌음)
                    try:
                        if not hasattr(DragonWing, '_wall_sound'):
                            wall_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "sounds", "wall_hit.wav")
                            DragonWing._wall_sound = pygame.mixer.Sound(wall_path) if os.path.exists(wall_path) else None
                        if DragonWing._wall_sound:
                            DragonWing._wall_sound.play()
                    except Exception:
                        pass

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
        self.flying_dragon = None
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
                    wind_surf = _psurf((line_width, line_height), pygame.SRCALPHA)

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

        # 🐉 날아가는 드래곤 그리기 (스킬 비활성 상태에서도 드래곤은 계속 날아감)
        if self.flying_dragon and self.flying_dragon.get('active'):
            # 스킬 종료 후에도 드래곤 위치 업데이트 (draw는 매 프레임 호출됨)
            if not self.is_active:
                dragon = self.flying_dragon
                dt = 1 / 60.0  # 60fps 기준
                dragon['x'] += dragon['vx'] * dt
                dragon['wing_time'] += dt
                dragon['y'] = dragon['base_y'] + _sin(dragon['wing_time'] * 2.5) * 8
                if dragon['x'] < -120 or dragon['x'] > 880:
                    dragon['active'] = False
            self._draw_flying_dragon(screen)

    def _draw_flying_dragon(self, screen):
        """에인션트 드래곤 - 고대 용의 위엄, 갑옷 비늘, 룬 문양, 거대한 날개"""
        d = self.flying_dragon
        cx, cy = d['x'], d['y']
        facing = d['direction']
        wt = d['wing_time']
        wf = _sin(wt * 7.5)        # 날갯짓
        wf2 = _sin(wt * 7.5 + 0.8) # 날갯짓 (약간 위상차)
        breath_pulse = 0.5 + 0.5 * _sin(wt * 3)  # 숨쉬기 맥동

        # === 에인션트 색상 팔레트 ===
        C_OBSIDIAN = (38, 28, 22)         # 가장 어두운 아웃라인
        C_DK = (72, 48, 28)               # 어두운 갑옷색
        C_BODY = (128, 82, 38)            # 주 몸통색 (풍화된 청동)
        C_LT = (178, 128, 62)             # 밝은 하이라이트
        C_GOLD = (218, 175, 78)           # 골드 하이라이트
        C_BELLY = (195, 168, 118)         # 배 부분 (낡은 상아색)
        C_BELLY_LINE = (165, 140, 95)     # 배 줄무늬
        C_SCALE_DK = (88, 55, 22)         # 비늘 어두운면
        C_SCALE_LT = (155, 108, 48)       # 비늘 밝은면
        C_PLATE = (98, 65, 30)            # 갑옷판
        C_PLATE_EDGE = (148, 105, 50)     # 갑옷판 테두리
        C_WING_BONE = (115, 72, 35)       # 날개 뼈
        C_WING_BONE_LT = (165, 118, 58)   # 날개 뼈 하이라이트
        C_WING_MEM = (108, 68, 32, 165)   # 날개 막 (반투명)
        C_WING_MEM_LT = (148, 98, 45, 140) # 날개 막 밝은부분
        C_WING_MEM_DK = (72, 42, 20, 190) # 날개 막 어두운부분
        C_HORN = (82, 58, 32)             # 뿔 (풍화된 뼈)
        C_HORN_LT = (135, 108, 65)        # 뿔 하이라이트
        C_HORN_TIP = (168, 142, 95)       # 뿔 끝 (밝은)
        C_CLAW = (58, 38, 18)             # 발톱 (흑요석)
        C_TOOTH = (228, 218, 195)         # 이빨 (오래된 상아)
        C_TOOTH_ROOT = (180, 165, 138)    # 이빨 뿌리
        C_EYE_OUTER = (42, 18, 8)         # 눈 외곽
        C_EYE_IRIS = (255, 178, 25)       # 눈 홍채 (황금)
        C_EYE_PUPIL = (120, 35, 5)        # 눈 동공
        C_EYE_GLOW = (255, 220, 80)       # 눈 발광
        C_RUNE = (255, 185, 55, 90)       # 룬 문양 (은은한 빛)
        C_RUNE_BRIGHT = (255, 215, 95, 130) # 룬 밝은부분
        C_EMBER = (255, 120, 20)          # 숨결 불씨
        C_FIRE_CORE = (255, 235, 180)     # 화염 중심
        C_FIRE_MID = (255, 165, 40)       # 화염 중간
        C_FIRE_OUTER = (200, 80, 15)      # 화염 외곽
        C_SMOKE = (60, 45, 35, 80)        # 연기

        SW, SH = 340, 260
        BY = 140  # Y 기준선 (더 큰 캔버스에 맞춤)
        ds = _psurf((SW, SH), pygame.SRCALPHA)

        # ============================================================
        # 1) 척추 포인트 (꼬리끝 → 목끝) - 70개 세밀 포인트
        # ============================================================
        spine = []
        # 꼬리 (35pts) - S자 물결, 가늘게 시작 → 굵어짐
        for i in range(35):
            t = i / 34.0
            x = 12 + t * 110
            wave1 = _sin(wt * 3.0 + (1 - t) * 5.0) * (12 * (1 - t))
            wave2 = _sin(wt * 4.5 + (1 - t) * 3.0) * (4 * (1 - t))
            y = BY + 4 + wave1 + wave2
            w = 1.5 + t * 16.0
            spine.append((x, y, w))

        # 몸통 (20pts) - 두꺼운 중앙부, 숨쉬기 맥동
        for i in range(20):
            t = i / 19.0
            x = 122 + t * 72
            y = BY - t * 8 - _sin(t * 3.14159) * 3
            base_w = 17.5 + _sin(t * 3.14159) * 6
            w = base_w + breath_pulse * 1.2  # 숨쉬기로 미세하게 팽창
            spine.append((x, y, w))

        # 목 (15pts) - 우아한 S자 곡선
        for i in range(15):
            t = i / 14.0
            x = 194 + t * 48
            scurve = _sin(t * 2.2) * 5 + _cos(t * 1.5) * 2
            neck_bob = _sin(wt * 1.8) * 1.5 * t  # 미세한 머리 끄덕임
            y = BY - 8 - t * 38 + scurve + neck_bob
            w = 15.5 - t * 7.5
            spine.append((x, y, w))

        # === 다리 기준 좌표 ===
        body_back_x = spine[40][0]
        body_back_y = spine[40][1]
        body_front_x = spine[50][0]
        body_front_y = spine[50][1]

        # ============================================================
        # 2) 뒷다리 (몸통 뒤쪽, 바디 아래) - 3관절 다리
        # ============================================================
        for lx_base, ly_base, ph in [(body_back_x - 6, body_back_y, 0.0),
                                      (body_back_x + 10, body_back_y, 1.8)]:
            sw = _sin(wt * 4.5 + ph) * 4
            # 허벅지
            kx, ky = lx_base + sw * 0.3, ly_base + 20
            pygame.draw.line(ds, C_OBSIDIAN, (int(lx_base), int(ly_base + 11)), (int(kx), int(ky)), 9)
            pygame.draw.line(ds, C_DK, (int(lx_base), int(ly_base + 11)), (int(kx), int(ky)), 7)
            pygame.draw.line(ds, C_BODY, (int(lx_base), int(ly_base + 11)), (int(kx), int(ky)), 5)
            pygame.draw.line(ds, C_LT, (int(lx_base + 1), int(ly_base + 12)), (int(kx + 1), int(ky)), 2)
            # 무릎 관절
            pygame.draw.circle(ds, C_DK, (int(kx), int(ky)), 5)
            pygame.draw.circle(ds, C_PLATE, (int(kx), int(ky)), 4)
            pygame.draw.circle(ds, C_PLATE_EDGE, (int(kx), int(ky)), 2)
            # 정강이
            fx, fy = kx + sw * 0.2, ky + 16
            pygame.draw.line(ds, C_OBSIDIAN, (int(kx), int(ky)), (int(fx), int(fy)), 7)
            pygame.draw.line(ds, C_DK, (int(kx), int(ky)), (int(fx), int(fy)), 5)
            pygame.draw.line(ds, C_BODY, (int(kx), int(ky)), (int(fx), int(fy)), 3)
            # 발 + 발톱
            pygame.draw.ellipse(ds, C_OBSIDIAN, (int(fx - 8), int(fy - 3), 16, 8))
            pygame.draw.ellipse(ds, C_DK, (int(fx - 7), int(fy - 2), 14, 7))
            pygame.draw.ellipse(ds, C_PLATE, (int(fx - 5), int(fy - 1), 10, 5))
            for co in [-6, -2, 2, 6]:
                claw_len = 8 + abs(co) * 0.3
                pygame.draw.line(ds, C_CLAW, (int(fx + co), int(fy + 3)),
                                 (int(fx + co + 1), int(fy + claw_len)), 2)
                pygame.draw.line(ds, C_HORN_LT, (int(fx + co + 1), int(fy + claw_len - 2)),
                                 (int(fx + co + 1), int(fy + claw_len)), 1)

        # ============================================================
        # 3) 바디 렌더링 (원 오버랩 = 완전 심리스) + 갑옷 비늘
        # ============================================================
        # 아웃라인
        for sx, sy, w in spine:
            pygame.draw.circle(ds, C_OBSIDIAN, (int(sx), int(sy)), int(w) + 3)
        # 메인 바디
        for sx, sy, w in spine:
            pygame.draw.circle(ds, C_DK, (int(sx), int(sy)), int(w) + 1)
        for sx, sy, w in spine:
            pygame.draw.circle(ds, C_BODY, (int(sx), int(sy)), int(w))
        # 상단 하이라이트 (등 빛)
        for sx, sy, w in spine:
            r = max(1, int(w * 0.5))
            pygame.draw.circle(ds, C_LT, (int(sx), int(sy - w * 0.35)), r)
        for sx, sy, w in spine:
            r = max(1, int(w * 0.25))
            pygame.draw.circle(ds, C_GOLD, (int(sx), int(sy - w * 0.45)), r)
        # 배 부분 (하단)
        for i, (sx, sy, w) in enumerate(spine):
            if i > 10:
                r = max(1, int(w * 0.42))
                pygame.draw.circle(ds, C_BELLY, (int(sx), int(sy + w * 0.32)), r)

        # === 갑옷판 비늘 (다이아몬드형 큰 비늘) ===
        for i in range(10, len(spine) - 4, 2):
            sx, sy, w = spine[i]
            if w < 6:
                continue
            sc_size = max(3, int(w * 0.28))
            for row_off in [-0.35, -0.05, 0.2]:
                py_sc = sy + w * row_off
                # 다이아몬드 갑옷판
                pts = [
                    (int(sx), int(py_sc - sc_size)),
                    (int(sx + sc_size * 0.7), int(py_sc)),
                    (int(sx), int(py_sc + sc_size)),
                    (int(sx - sc_size * 0.7), int(py_sc)),
                ]
                pygame.draw.polygon(ds, C_SCALE_DK, pts)
                # 비늘 내부 하이라이트
                inner = [
                    (int(sx), int(py_sc - sc_size + 2)),
                    (int(sx + sc_size * 0.4), int(py_sc)),
                    (int(sx), int(py_sc + sc_size - 2)),
                    (int(sx - sc_size * 0.4), int(py_sc)),
                ]
                pygame.draw.polygon(ds, C_SCALE_LT, inner)
                # 비늘 테두리
                pygame.draw.polygon(ds, C_PLATE_EDGE, pts, 1)

        # === 배 줄무늬 (수평 주름) ===
        for i in range(14, len(spine) - 6, 2):
            sx, sy, w = spine[i]
            by_pos = sy + w * 0.33
            bw = max(3, int(w * 0.35))
            pygame.draw.line(ds, C_BELLY_LINE,
                             (int(sx - bw), int(by_pos)),
                             (int(sx + bw), int(by_pos)), 1)

        # === 룬 문양 (고대 마법 각인 - 은은하게 빛남) ===
        rune_phase = wt * 1.2
        for i in range(18, len(spine) - 8, 5):
            sx, sy, w = spine[i]
            if w < 10:
                continue
            rune_alpha = int(55 + 35 * _sin(rune_phase + i * 0.7))
            rune_r = max(3, int(w * 0.3))
            rs = _psurf((rune_r * 2 + 4, rune_r * 2 + 4), pygame.SRCALPHA)
            # 룬 원형
            pygame.draw.circle(rs, (255, 185, 55, rune_alpha), (rune_r + 2, rune_r + 2), rune_r, 1)
            # 룬 십자
            pygame.draw.line(rs, (255, 215, 95, rune_alpha + 15),
                             (rune_r + 2, 2), (rune_r + 2, rune_r * 2 + 2), 1)
            pygame.draw.line(rs, (255, 215, 95, rune_alpha + 15),
                             (2, rune_r + 2), (rune_r * 2 + 2, rune_r + 2), 1)
            # 대각선
            pygame.draw.line(rs, (255, 195, 65, rune_alpha - 10),
                             (4, 4), (rune_r * 2, rune_r * 2), 1)
            pygame.draw.line(rs, (255, 195, 65, rune_alpha - 10),
                             (rune_r * 2, 4), (4, rune_r * 2), 1)
            ds.blit(rs, (int(sx - rune_r - 2), int(sy - rune_r - 2)))

        # ============================================================
        # 4) 등 돌기 (고대 뿔 줄기 - 크고 날카로운)
        # ============================================================
        for i in range(6, len(spine) - 3, 2):
            sx, sy, w = spine[i]
            spike_h = max(4, int(w * 0.6)) + _sin(wt * 2.0 + i * 0.3) * 1.5
            base_w = max(3, int(w * 0.28))
            # 큰 스파이크 메인
            pts = [
                (int(sx - base_w), int(sy - w + 1)),
                (int(sx - 1), int(sy - w - spike_h)),
                (int(sx + base_w), int(sy - w + 1)),
            ]
            pygame.draw.polygon(ds, C_HORN, pts)
            pygame.draw.polygon(ds, C_OBSIDIAN, pts, 1)
            # 하이라이트
            pygame.draw.line(ds, C_HORN_LT,
                             (int(sx - 1), int(sy - w - spike_h)),
                             (int(sx + base_w - 1), int(sy - w + 1)), 1)
            # 보조 작은 스파이크
            if i % 4 == 0 and w > 8:
                small_h = spike_h * 0.5
                for side in [-1, 1]:
                    sx2 = sx + side * base_w * 0.8
                    pygame.draw.polygon(ds, C_SCALE_DK, [
                        (int(sx2 - 1), int(sy - w + 2)),
                        (int(sx2), int(sy - w - small_h + 2)),
                        (int(sx2 + 1), int(sy - w + 2)),
                    ])

        # === 꼬리 끝 (삼엽 갈고리 - 고대 무기형) ===
        tx, ty = spine[0][0], spine[0][1]
        tw2 = _sin(wt * 3.5 + 4.5) * 3
        # 중앙 블레이드
        pygame.draw.polygon(ds, C_OBSIDIAN, [
            (int(tx + 2), int(ty)),
            (int(tx - 22), int(ty - 2 + tw2)),
            (int(tx - 16), int(ty + tw2 * 0.2)),
            (int(tx - 22), int(ty + 2 + tw2)),
        ])
        pygame.draw.polygon(ds, C_HORN, [
            (int(tx + 1), int(ty)),
            (int(tx - 20), int(ty - 1 + tw2)),
            (int(tx - 15), int(ty + tw2 * 0.2)),
            (int(tx - 20), int(ty + 1 + tw2)),
        ])
        # 상하 갈고리
        for vy_dir in [-1, 1]:
            pygame.draw.polygon(ds, C_OBSIDIAN, [
                (int(tx - 8), int(ty + tw2 * 0.3)),
                (int(tx - 18), int(ty + vy_dir * 12 + tw2)),
                (int(tx - 12), int(ty + vy_dir * 4 + tw2 * 0.3)),
            ])
            pygame.draw.polygon(ds, C_HORN, [
                (int(tx - 7), int(ty + tw2 * 0.3)),
                (int(tx - 16), int(ty + vy_dir * 11 + tw2)),
                (int(tx - 11), int(ty + vy_dir * 4 + tw2 * 0.3)),
            ])
        # 꼬리 끝 룬 빛
        tail_glow_a = int(40 + 25 * _sin(wt * 2.5))
        tg = _psurf((16, 16), pygame.SRCALPHA)
        pygame.draw.circle(tg, (255, 185, 55, tail_glow_a), (8, 8), 6)
        ds.blit(tg, (int(tx - 18), int(ty + tw2 - 8)))

        # ============================================================
        # 5) 날개 (거대한 에인션트 날개 - 7개 뼈대, 넓은 막)
        # ============================================================
        wb_x, wb_y = spine[46][0], spine[46][1] - spine[46][2]

        # 날갯짓 애니메이션 (뼈대별 차별화)
        wy = [wf * 42, wf * 38, wf2 * 32, wf2 * 26, wf * 20, wf * 14, wf2 * 8]

        bones = [
            (wb_x + 32, wb_y - 68 - wy[0]),    # 가장 앞쪽 (긴)
            (wb_x + 18, wb_y - 78 - wy[1]),     # 두번째
            (wb_x + 2,  wb_y - 76 - wy[2]),     # 세번째
            (wb_x - 16, wb_y - 68 - wy[3]),     # 중앙
            (wb_x - 32, wb_y - 56 - wy[4]),     # 네번째
            (wb_x - 48, wb_y - 40 - wy[5]),     # 다섯번째
            (wb_x - 60, wb_y - 22 - wy[6]),     # 가장 뒤쪽 (짧은)
        ]

        # 날개 막 폴리곤 (전체 실루엣)
        wpoly = [(int(wb_x), int(wb_y))]
        for i in range(len(bones)):
            wpoly.append((int(bones[i][0]), int(bones[i][1])))
            # 뼈 사이 처진 막 (자연스러운 곡선)
            if i < len(bones) - 1:
                mx = (bones[i][0] + bones[i + 1][0]) * 0.5
                my = (bones[i][1] + bones[i + 1][1]) * 0.5 + 6 + i * 0.8
                wpoly.append((int(mx), int(my)))
        wpoly.append((int(wb_x - 55), int(wb_y + 16)))
        wpoly.append((int(wb_x), int(wb_y)))

        # 어두운 외곽 (아웃라인)
        outline_poly = [(p[0], p[1]) for p in wpoly]
        pygame.draw.polygon(ds, C_OBSIDIAN, outline_poly)

        # 날개 막 메인
        inner_wpoly = [(int(wb_x + 1), int(wb_y + 1))]
        for i in range(len(bones)):
            inner_wpoly.append((int(bones[i][0]), int(bones[i][1] + 2)))
            if i < len(bones) - 1:
                mx = (bones[i][0] + bones[i + 1][0]) * 0.5
                my = (bones[i][1] + bones[i + 1][1]) * 0.5 + 5 + i * 0.8
                inner_wpoly.append((int(mx), int(my)))
        inner_wpoly.append((int(wb_x - 52), int(wb_y + 15)))
        inner_wpoly.append((int(wb_x + 1), int(wb_y + 1)))
        pygame.draw.polygon(ds, C_WING_MEM_DK, inner_wpoly)

        # 밝은 막 (안쪽 레이어)
        light_wpoly = [(int(wb_x + 3), int(wb_y + 3))]
        for i in range(len(bones)):
            light_wpoly.append((int(bones[i][0]), int(bones[i][1] + 6)))
            if i < len(bones) - 1:
                mx = (bones[i][0] + bones[i + 1][0]) * 0.5
                my = (bones[i][1] + bones[i + 1][1]) * 0.5 + 8 + i * 0.8
                light_wpoly.append((int(mx), int(my)))
        light_wpoly.append((int(wb_x - 48), int(wb_y + 14)))
        light_wpoly.append((int(wb_x + 3), int(wb_y + 3)))
        pygame.draw.polygon(ds, C_WING_MEM_LT, light_wpoly)

        # 날개 혈관 네트워크 (세밀한 혈관)
        for i in range(len(bones)):
            for j in range(1, 6):
                vt = j / 6.0
                vx = wb_x + (bones[i][0] - wb_x) * vt
                vy = wb_y + (bones[i][1] - wb_y) * vt
                # 옆 뼈로 가는 혈관
                if i < len(bones) - 1:
                    nx = wb_x + (bones[i + 1][0] - wb_x) * vt
                    ny = wb_y + (bones[i + 1][1] - wb_y) * vt
                    v_alpha = max(30, int(80 - j * 8))
                    pygame.draw.line(ds, (128, 78, 35, v_alpha),
                                     (int(vx), int(vy)), (int(nx), int(ny)), 1)
                # 가지형 소혈관
                if j % 2 == 0 and i < len(bones) - 1:
                    branch_x = vx + random.uniform(-4, 4) * 0.3  # 고정 시드 아님 → OK (매프레임 약간 진동)
                    branch_y = vy + 4
                    pygame.draw.line(ds, (118, 72, 32, 50),
                                     (int(vx), int(vy)), (int(branch_x), int(branch_y)), 1)

        # 뼈대 (두꺼운 고대 뼈)
        for i, (bx, by_b) in enumerate(bones):
            th = 5 if i <= 2 else 4 if i <= 4 else 3
            # 아웃라인
            pygame.draw.line(ds, C_OBSIDIAN, (int(wb_x), int(wb_y)), (int(bx), int(by_b)), th + 3)
            # 메인 뼈
            pygame.draw.line(ds, C_WING_BONE, (int(wb_x), int(wb_y)), (int(bx), int(by_b)), th + 1)
            # 하이라이트
            pygame.draw.line(ds, C_WING_BONE_LT, (int(wb_x), int(wb_y)), (int(bx), int(by_b)), max(1, th - 1))
            # 관절 마디 (뼈 중간)
            for kt in [0.3, 0.6]:
                knot_x = wb_x + (bx - wb_x) * kt
                knot_y = wb_y + (by_b - wb_y) * kt
                pygame.draw.circle(ds, C_WING_BONE, (int(knot_x), int(knot_y)), th)
                pygame.draw.circle(ds, C_WING_BONE_LT, (int(knot_x), int(knot_y)), max(1, th - 1))
            # 뼈 끝 발톱
            pygame.draw.circle(ds, C_DK, (int(bx), int(by_b)), 4)
            pygame.draw.circle(ds, C_WING_BONE, (int(bx), int(by_b)), 3)
            claw_dx = 3 if i < 3 else -1
            pygame.draw.line(ds, C_CLAW, (int(bx), int(by_b)),
                             (int(bx + claw_dx), int(by_b - 8)), 2)
            pygame.draw.line(ds, C_HORN_TIP, (int(bx + claw_dx), int(by_b - 8)),
                             (int(bx + claw_dx), int(by_b - 6)), 1)

        # 날개 어깨 관절 (크고 장갑형)
        pygame.draw.circle(ds, C_OBSIDIAN, (int(wb_x), int(wb_y)), 10)
        pygame.draw.circle(ds, C_DK, (int(wb_x), int(wb_y)), 8)
        pygame.draw.circle(ds, C_PLATE, (int(wb_x), int(wb_y)), 6)
        pygame.draw.circle(ds, C_PLATE_EDGE, (int(wb_x), int(wb_y)), 4)
        pygame.draw.circle(ds, C_GOLD, (int(wb_x), int(wb_y)), 2)

        # ============================================================
        # 6) 앞다리 (근육질, 갑옷 패드 부착)
        # ============================================================
        for lx_base, ly_base, ph in [(body_front_x, body_front_y, 0.8),
                                      (body_front_x + 14, body_front_y, 2.5)]:
            sw = _sin(wt * 4.5 + ph) * 3
            # 어깨 갑옷 패드
            pad_pts = [
                (int(lx_base - 4), int(ly_base + 4)),
                (int(lx_base + 8), int(ly_base + 2)),
                (int(lx_base + 10), int(ly_base + 10)),
                (int(lx_base - 2), int(ly_base + 12)),
            ]
            pygame.draw.polygon(ds, C_PLATE, pad_pts)
            pygame.draw.polygon(ds, C_PLATE_EDGE, pad_pts, 1)
            # 허벅지
            kx, ky = lx_base + 5 + sw * 0.2, ly_base + 18
            pygame.draw.line(ds, C_OBSIDIAN, (int(lx_base), int(ly_base + 9)), (int(kx), int(ky)), 8)
            pygame.draw.line(ds, C_DK, (int(lx_base), int(ly_base + 9)), (int(kx), int(ky)), 6)
            pygame.draw.line(ds, C_BODY, (int(lx_base), int(ly_base + 9)), (int(kx), int(ky)), 4)
            pygame.draw.line(ds, C_LT, (int(lx_base + 1), int(ly_base + 10)), (int(kx + 1), int(ky)), 2)
            # 무릎
            pygame.draw.circle(ds, C_DK, (int(kx), int(ky)), 5)
            pygame.draw.circle(ds, C_PLATE, (int(kx), int(ky)), 4)
            # 정강이
            fx, fy = kx + sw * 0.15 + 2, ky + 14
            pygame.draw.line(ds, C_OBSIDIAN, (int(kx), int(ky)), (int(fx), int(fy)), 6)
            pygame.draw.line(ds, C_DK, (int(kx), int(ky)), (int(fx), int(fy)), 4)
            pygame.draw.line(ds, C_BODY, (int(kx), int(ky)), (int(fx), int(fy)), 3)
            # 발
            pygame.draw.ellipse(ds, C_OBSIDIAN, (int(fx - 9), int(fy - 3), 18, 9))
            pygame.draw.ellipse(ds, C_DK, (int(fx - 8), int(fy - 2), 16, 8))
            pygame.draw.ellipse(ds, C_PLATE, (int(fx - 6), int(fy - 1), 12, 6))
            # 발톱 4개
            for co in [-6, -2, 2, 6]:
                claw_len = 9 + abs(co) * 0.4
                pygame.draw.line(ds, C_CLAW, (int(fx + co), int(fy + 3)),
                                 (int(fx + co + 1), int(fy + claw_len)), 2)
                pygame.draw.line(ds, C_HORN_TIP, (int(fx + co + 1), int(fy + claw_len - 2)),
                                 (int(fx + co + 1), int(fy + claw_len)), 1)

        # ============================================================
        # 7) 머리 (고대 용의 위엄 - 큰 뿔관, 갑옷판, 위압적 턱)
        # ============================================================
        nk_end_x, nk_end_y, nk_end_w = spine[-1]
        hx, hy = int(nk_end_x) + 14, int(nk_end_y) - 3
        neck_bob = _sin(wt * 1.8) * 1.5

        # --- 머리 뼈대 (다층 구조) ---
        # 아웃라인
        pygame.draw.ellipse(ds, C_OBSIDIAN, (hx - 19, hy - 16, 38, 34))
        # 메인
        pygame.draw.ellipse(ds, C_DK, (hx - 17, hy - 14, 34, 30))
        pygame.draw.ellipse(ds, C_BODY, (hx - 15, hy - 13, 30, 28))
        # 하이라이트
        pygame.draw.ellipse(ds, C_LT, (hx - 11, hy - 12, 22, 18))
        pygame.draw.ellipse(ds, C_GOLD, (hx - 7, hy - 10, 14, 10))

        # --- 머리 갑옷판 (이마 ~ 코) ---
        plate_pts = [
            (hx - 8, hy - 12), (hx + 4, hy - 14),
            (hx + 16, hy - 8), (hx + 20, hy - 2),
            (hx + 16, hy + 2), (hx - 4, hy + 2),
        ]
        pygame.draw.polygon(ds, C_PLATE, plate_pts)
        pygame.draw.polygon(ds, C_PLATE_EDGE, plate_pts, 1)
        # 이마 중앙 돌기
        pygame.draw.polygon(ds, C_HORN, [
            (hx + 3, hy - 14), (hx + 6, hy - 18), (hx + 9, hy - 14)])
        pygame.draw.polygon(ds, C_HORN_LT, [
            (hx + 4, hy - 14), (hx + 6, hy - 17), (hx + 8, hy - 14)])

        # --- 주둥이 (길고 위압적) ---
        snout_x, snout_y = hx + 30, hy + 1
        # 윗턱 (두께감)
        pygame.draw.polygon(ds, C_OBSIDIAN, [
            (hx + 14, hy - 9), (snout_x + 4, snout_y - 4),
            (snout_x + 4, snout_y + 3), (hx + 14, hy + 6)])
        pygame.draw.polygon(ds, C_DK, [
            (hx + 14, hy - 8), (snout_x + 2, snout_y - 3),
            (snout_x + 2, snout_y + 2), (hx + 14, hy + 5)])
        pygame.draw.polygon(ds, C_BODY, [
            (hx + 14, hy - 7), (snout_x, snout_y - 2),
            (snout_x, snout_y + 1), (hx + 14, hy + 4)])
        pygame.draw.polygon(ds, C_LT, [
            (hx + 14, hy - 6), (snout_x - 2, snout_y - 1),
            (snout_x - 2, snout_y), (hx + 14, hy + 1)])
        # 콧구멍 (두 개)
        pygame.draw.circle(ds, C_OBSIDIAN, (snout_x - 1, snout_y - 4), 3)
        pygame.draw.circle(ds, C_DK, (snout_x - 1, snout_y - 4), 2)
        pygame.draw.circle(ds, C_OBSIDIAN, (snout_x - 5, snout_y - 5), 2)
        # 코 연기 파티클
        smoke_a = int(40 + 20 * _sin(wt * 4))
        for si in range(2):
            smk_x = snout_x + 2 + si * 4 + _sin(wt * 5 + si) * 2
            smk_y = snout_y - 6 - si * 3
            smk_s = _psurf((8, 8), pygame.SRCALPHA)
            pygame.draw.circle(smk_s, (60, 45, 35, smoke_a - si * 15), (4, 4), 3)
            ds.blit(smk_s, (int(smk_x - 4), int(smk_y - 4)))

        # --- 아랫턱 (크게 벌린 입) ---
        jaw_open = 5.5 + _sin(wt * 2) * 2
        # 아웃라인
        pygame.draw.polygon(ds, C_OBSIDIAN, [
            (hx + 12, hy + 7), (snout_x - 1, int(snout_y + jaw_open + 5)),
            (hx + 6, int(hy + 12 + jaw_open * 0.5))])
        # 턱뼈
        pygame.draw.polygon(ds, C_DK, [
            (hx + 11, hy + 6), (snout_x - 2, int(snout_y + jaw_open + 4)),
            (hx + 7, int(hy + 11 + jaw_open * 0.5))])
        pygame.draw.polygon(ds, C_BODY, [
            (hx + 11, hy + 5), (snout_x - 3, int(snout_y + jaw_open + 3)),
            (hx + 8, int(hy + 10 + jaw_open * 0.5))])

        # --- 입 안쪽 (깊은 빨강) ---
        pygame.draw.polygon(ds, (90, 18, 8), [
            (hx + 13, hy + 4), (snout_x - 4, snout_y + 1),
            (snout_x - 4, int(snout_y + jaw_open + 1)),
            (hx + 9, int(hy + 8 + jaw_open * 0.4))])
        # 입 안쪽 밝은 부분 (목구멍 불빛)
        throat_glow_a = int(60 + 40 * _sin(wt * 3))
        thr = _psurf((20, 14), pygame.SRCALPHA)
        pygame.draw.ellipse(thr, (255, 100, 20, throat_glow_a), (2, 2, 16, 10))
        ds.blit(thr, (hx + 10, hy + 2))

        # --- 이빨 (크고 불규칙한 고대 이빨) ---
        # 윗 이빨 (6개, 크기 불규칙)
        tooth_sizes = [4.5, 6.0, 7.5, 7.0, 5.5, 4.0]
        for ti in range(6):
            tooth_x = hx + 14 + ti * 4
            tooth_len = tooth_sizes[ti]
            # 이빨 뿌리
            pygame.draw.polygon(ds, C_TOOTH_ROOT, [
                (tooth_x - 2, hy + 4), (tooth_x, int(hy + 3 + tooth_len * 0.4)),
                (tooth_x + 2, hy + 4)])
            # 이빨 본체
            pygame.draw.polygon(ds, C_TOOTH, [
                (tooth_x - 1, int(hy + 3 + tooth_len * 0.3)),
                (tooth_x, int(hy + 4 + tooth_len)),
                (tooth_x + 1, int(hy + 3 + tooth_len * 0.3))])
            # 이빨 하이라이트
            pygame.draw.line(ds, (255, 252, 240),
                             (tooth_x, int(hy + 3 + tooth_len * 0.3)),
                             (tooth_x, int(hy + 4 + tooth_len - 1)), 1)

        # 아랫 이빨 (5개)
        btooth_sizes = [3.5, 5.0, 6.0, 5.0, 3.5]
        for ti in range(5):
            tooth_x = hx + 15 + ti * 4
            tooth_y = int(hy + 5 + jaw_open * 0.3)
            tooth_len = btooth_sizes[ti]
            pygame.draw.polygon(ds, C_TOOTH_ROOT, [
                (tooth_x - 2, tooth_y + 1), (tooth_x, int(tooth_y + 1 - tooth_len * 0.3)),
                (tooth_x + 2, tooth_y + 1)])
            pygame.draw.polygon(ds, C_TOOTH, [
                (tooth_x - 1, int(tooth_y + 1 - tooth_len * 0.3)),
                (tooth_x, int(tooth_y - tooth_len)),
                (tooth_x + 1, int(tooth_y + 1 - tooth_len * 0.3))])

        # --- 눈 (크고 고대스러운 황금 눈 + 발광) ---
        ex, ey = hx + 1, hy - 6
        # 눈 아웃라인
        pygame.draw.circle(ds, C_OBSIDIAN, (ex, ey), 8)
        # 눈 외곽
        pygame.draw.circle(ds, C_EYE_OUTER, (ex, ey), 7)
        # 홍채 (황금)
        pygame.draw.circle(ds, C_EYE_IRIS, (ex, ey), 6)
        # 내부 그라데이션
        pygame.draw.circle(ds, C_EYE_GLOW, (ex, ey), 4)
        # 슬릿 동공 (세로)
        pygame.draw.line(ds, C_EYE_PUPIL, (ex, ey - 5), (ex, ey + 5), 3)
        pygame.draw.line(ds, C_OBSIDIAN, (ex, ey - 4), (ex, ey + 4), 2)
        # 동공 가운데 밝은 점
        pygame.draw.line(ds, (180, 80, 20), (ex, ey - 1), (ex, ey + 1), 1)
        # 눈 하이라이트 (반사광)
        pygame.draw.circle(ds, (255, 255, 240), (ex - 2, ey - 3), 2)
        pygame.draw.circle(ds, (255, 255, 255), (ex + 2, ey - 1), 1)
        # 눈 발광 오라 (은은하게)
        eye_glow_a = int(35 + 20 * _sin(wt * 3))
        eg = _psurf((24, 24), pygame.SRCALPHA)
        pygame.draw.circle(eg, (255, 200, 60, eye_glow_a), (12, 12), 10)
        ds.blit(eg, (ex - 12, ey - 12))

        # --- 눈 위 보호 돌기 (브라우 혼) ---
        pygame.draw.polygon(ds, C_PLATE, [
            (ex - 6, ey - 6), (ex - 10, ey - 12), (ex - 2, ey - 6)])
        pygame.draw.polygon(ds, C_PLATE_EDGE, [
            (ex - 6, ey - 6), (ex - 10, ey - 12), (ex - 2, ey - 6)], 1)
        pygame.draw.polygon(ds, C_PLATE, [
            (ex + 2, ey - 6), (ex + 6, ey - 11), (ex + 8, ey - 5)])
        pygame.draw.polygon(ds, C_PLATE_EDGE, [
            (ex + 2, ey - 6), (ex + 6, ey - 11), (ex + 8, ey - 5)], 1)

        # --- 뿔 (대형 곡선 뿔 2쌍 + 왕관형 소뿔) ---
        horn_configs = [
            # (x_off, y_off, length, curve, thickness)
            (-9, -13, 30, -6, 5),   # 주뿔 왼쪽
            (3, -12, 26, -3, 4),    # 주뿔 오른쪽
            (-14, -9, 18, -8, 3),   # 보조뿔 왼쪽
            (7, -8, 15, -1, 3),     # 보조뿔 오른쪽
        ]
        for hx_off, hy_off, h_len, h_curve, h_thick in horn_configs:
            hbx, hby = hx + hx_off, hy + hy_off
            htx, hty = hbx + h_curve, hby - h_len
            # 뿔 뿌리 (두꺼운)
            pygame.draw.line(ds, C_OBSIDIAN, (hbx, hby), (htx, hty), h_thick + 3)
            pygame.draw.line(ds, C_HORN, (hbx, hby), (htx, hty), h_thick + 1)
            pygame.draw.line(ds, C_HORN_LT, (hbx, hby), (htx, hty), max(1, h_thick - 1))
            # 뿔 끝 (밝은)
            pygame.draw.line(ds, C_HORN_TIP, (htx, hty),
                             (int(htx + h_curve * 0.3), hty - 4), max(1, h_thick - 2))
            # 뿔 마디 (나이테 느낌)
            for ri in range(1, 5):
                rt = ri / 5.0
                rx = hbx + (htx - hbx) * rt
                ry = hby + (hty - hby) * rt
                ring_r = max(1, int(h_thick * (1 - rt * 0.4)))
                pygame.draw.circle(ds, C_HORN, (int(rx), int(ry)), ring_r + 1)
                pygame.draw.circle(ds, C_HORN_LT, (int(rx), int(ry)), ring_r)

        # 뒤통수 왕관형 장식
        for dx_h, dy_h, h in [(-12, -5, 12), (-8, -7, 15), (-4, -8, 13), (0, -7, 11), (4, -5, 9)]:
            bx_c, by_c = hx + dx_h, hy + dy_h
            pygame.draw.polygon(ds, C_HORN, [
                (bx_c - 2, by_c), (bx_c, by_c - h), (bx_c + 2, by_c)])
            pygame.draw.polygon(ds, C_HORN_LT, [
                (bx_c - 1, by_c), (bx_c, by_c - h + 2), (bx_c + 1, by_c)])
            pygame.draw.polygon(ds, C_OBSIDIAN, [
                (bx_c - 2, by_c), (bx_c, by_c - h), (bx_c + 2, by_c)], 1)

        # 턱 수염 (용의 수염 - 2가닥)
        for beard_off, beard_ph in [(4, 0), (8, 1.5)]:
            bx_b = hx + 12 + beard_off
            by_b = int(hy + 8 + jaw_open * 0.3)
            bend = _sin(wt * 2.5 + beard_ph) * 3
            # 수염 줄기
            for seg in range(4):
                t1 = seg / 4.0
                t2 = (seg + 1) / 4.0
                sx1 = bx_b + bend * t1 + t1 * 6
                sy1 = by_b + t1 * 18
                sx2 = bx_b + bend * t2 + t2 * 6
                sy2 = by_b + t2 * 18
                thick = max(1, 3 - seg)
                pygame.draw.line(ds, C_HORN, (int(sx1), int(sy1)), (int(sx2), int(sy2)), thick)
                pygame.draw.line(ds, C_HORN_LT, (int(sx1), int(sy1)), (int(sx2), int(sy2)), max(1, thick - 1))

        # ============================================================
        # 8) 화염 브레스 (고대 화염 - 다층 불꽃 + 불씨 + 연기)
        # ============================================================
        fb_x, fb_y = snout_x + 12, int(snout_y + jaw_open * 0.3)

        # 연기 (화염 뒤쪽)
        for si in range(3):
            smk_dist = 18 + si * 8
            smk_x = fb_x + smk_dist + _sin(wt * 6 + si * 2) * 3
            smk_y = fb_y + _sin(wt * 4 + si) * 4 - si * 2
            smk_r = 5 + si * 2
            smk_a = max(20, 50 - si * 15)
            smk = _psurf((smk_r * 2 + 2, smk_r * 2 + 2), pygame.SRCALPHA)
            pygame.draw.circle(smk, (60, 45, 35, smk_a), (smk_r + 1, smk_r + 1), smk_r)
            ds.blit(smk, (int(smk_x - smk_r - 1), int(smk_y - smk_r - 1)))

        # 화염 코어 (여러 겹)
        for r_f in range(14, 0, -2):
            f_t = (14 - r_f) / 14.0
            f_a = min(255, int(60 + f_t * 195))
            # 외곽 → 코어 : 빨강 → 주황 → 노랑 → 하양
            f_r = 255
            f_g = min(255, int(80 + f_t * 175))
            f_b = min(255, int(5 + f_t * 170))
            fs = _psurf((r_f * 2 + 4, r_f * 2 + 4), pygame.SRCALPHA)
            pygame.draw.circle(fs, (f_r, f_g, f_b, f_a), (r_f + 2, r_f + 2), r_f)
            ds.blit(fs, (fb_x - r_f - 2, fb_y - r_f - 2))

        # 불꽃 파티클 (퍼지는 불씨)
        for _ in range(6):
            px = fb_x + random.uniform(-5, 22)
            py = fb_y + random.uniform(-12, 12)
            pr = random.randint(2, 7)
            pa = random.randint(120, 230)
            pg = random.randint(100, 220)
            pb = random.randint(10, 50)
            ps = _psurf((pr * 2, pr * 2), pygame.SRCALPHA)
            pygame.draw.circle(ps, (255, pg, pb, pa), (pr, pr), pr)
            ds.blit(ps, (int(px - pr), int(py - pr)))

        # 불씨 꼬리 (작은 점들)
        for _ in range(4):
            spark_x = fb_x + random.uniform(5, 30)
            spark_y = fb_y + random.uniform(-8, 8)
            spark_r = random.randint(1, 2)
            spark_a = random.randint(150, 255)
            spark_s = _psurf((4, 4), pygame.SRCALPHA)
            pygame.draw.circle(spark_s, (255, random.randint(200, 255), random.randint(60, 140), spark_a), (2, 2), spark_r)
            ds.blit(spark_s, (int(spark_x - 2), int(spark_y - 2)))

        # ============================================================
        # 좌우 반전 + 화면 그리기
        # ============================================================
        if facing == -1:
            ds = pygame.transform.flip(ds, True, False)
        screen.blit(ds, (int(cx - SW // 2), int(cy - BY)))

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
            description="뜨거운 증기가 철벽을 이루어 공을 튕겨낸다",
            trigger=SkillTrigger.ON_COOLDOWN,
            cooldown=28.0,
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
        # 배리어 메인 사운드 (종료 시 정지용)
        self._barrier_sound = None

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
                'vx': _cos(angle) * speed,
                'vy': _sin(angle) * speed,
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
            vx = _cos(angle) * speed * 0.6
            vy = _sin(angle) * speed
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
                    'vx': _cos(angle) * speed,
                    'vy': _sin(angle) * speed,
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
                'vx': _cos(angle) * speed,
                'vy': _sin(angle) * speed,
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

        # 배리어 사운드 직접 재생 (종료 시 정지 가능하도록)
        try:
            if self._barrier_sound is None:
                import os
                project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                snd_path = os.path.join(project_root, "sounds", "steambarrior.wav")
                if os.path.exists(snd_path):
                    self._barrier_sound = pygame.mixer.Sound(snd_path)
            if self._barrier_sound:
                self._barrier_sound.play()
        except Exception:
            pass

        return {
            'sound': None  # 직접 재생하므로 외부 재생 불필요
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

        # === 종료 조건 1: 공이 시전자 패들에 반사된 후 즉시 종료 ===
        # (발동 후 첫 1초는 보호 시간 - 패들 충돌로 종료되지 않음)
        # 공이 단순히 패들 근처에 있는 것이 아니라, 패들에 맞고 반사되어
        # 멀어지는 방향(vy)일 때만 배리어를 해제한다.
        grace_period = 1.0
        elapsed = self.duration - self.active_timer
        if elapsed >= grace_period:
            is_top = game_state.get('barrier_owner_is_top', True)
            ball_right = ball.x + getattr(ball, 'width', 10)
            ball_bottom = ball.y + getattr(ball, 'height', 10)
            paddle_right = caster_paddle.x + caster_paddle.width
            paddle_bottom = caster_paddle.y + caster_paddle.height
            if (ball.x < paddle_right and ball_right > caster_paddle.x and
                    ball.y < paddle_bottom and ball_bottom > caster_paddle.y):
                # 공이 패들에서 반사되어 멀어지고 있을 때만 종료
                # 상단 패들(is_top): 반사 후 공이 아래로 이동 (vy > 0)
                # 하단 패들: 반사 후 공이 위로 이동 (vy < 0)
                ball_reflected = (is_top and ball.vy > 0) or (not is_top and ball.vy < 0)
                if ball_reflected:
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
                    'x': self.caster_center_x + _cos(angle) * start_dist,
                    'y': self.caster_center_y + _sin(angle) * start_dist,
                    'vx': _cos(angle) * speed,
                    'vy': _sin(angle) * speed,
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
                    'x': ball_cx + _cos(angle) * dist,
                    'y': ball_cy + _sin(angle) * dist,
                    'vx': _cos(angle) * random.uniform(15, 40),
                    'vy': _sin(angle) * random.uniform(15, 40) - 20,
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
        # 스윕 충돌 감지: 빠른 공이 한 프레임에 배리어를 통과하는 것을 방지
        is_top = game_state.get('barrier_owner_is_top', True)
        if self.hit_cooldown <= 0:
            if is_top:
                # 상단 배리어: 공이 아래에서 위로 접근
                if ball.vy < 0:
                    next_y = ball.y + ball.vy
                    # 예측 충돌: 공이 배리어 아래에 있고 다음 프레임에 배리어에 도달/통과
                    will_cross = ball.y >= self.barrier_y and next_y <= self.barrier_y + 5
                    # 안전망: 이전 프레임에서 배리어를 이미 통과한 경우
                    already_past = ball.y < self.barrier_y and ball.y > self.barrier_y - abs(ball.vy) - 5
                    # 기존 근접 감지 (저속 공용)
                    proximity = abs(ball.y - self.barrier_y) < 20 and ball.y > self.barrier_y
                    if will_cross or already_past or proximity:
                        ball.y = self.barrier_y + 2  # 배리어 아래로 위치 보정
                        ball.vy = abs(ball.vy) * 1.4
                        self.hit_cooldown = self.hit_cooldown_max  # 중복 충돌 방지
                        game_state['screen_shake'] = 10
                        game_state['shake_duration'] = 0.3
                        # 배리어 충돌 플래시 이펙트
                        self._spawn_barrier_hit_flash(ball.x + getattr(ball, 'width', 10) / 2)
                        # 성스러운 이펙트 활성화
                        self.holy_ball_active = True
                        self.holy_ball_timer = self.holy_ball_duration
                        game_state['ball_holy'] = True
            else:
                # 하단 배리어: 공이 위에서 아래로 접근
                if ball.vy > 0:
                    next_y = ball.y + ball.vy
                    # 예측 충돌: 공이 배리어 위에 있고 다음 프레임에 배리어에 도달/통과
                    will_cross = ball.y <= self.barrier_y and next_y >= self.barrier_y - 5
                    # 안전망: 이전 프레임에서 배리어를 이미 통과한 경우
                    already_past = ball.y > self.barrier_y and ball.y < self.barrier_y + abs(ball.vy) + 5
                    # 기존 근접 감지 (저속 공용)
                    proximity = abs(ball.y - self.barrier_y) < 20 and ball.y < self.barrier_y
                    if will_cross or already_past or proximity:
                        ball.y = self.barrier_y - 2  # 배리어 위로 위치 보정
                        ball.vy = -abs(ball.vy) * 1.4
                        self.hit_cooldown = self.hit_cooldown_max  # 중복 충돌 방지
                        game_state['screen_shake'] = 10
                        game_state['shake_duration'] = 0.3
                        # 배리어 충돌 플래시 이펙트
                        self._spawn_barrier_hit_flash(ball.x + getattr(ball, 'width', 10) / 2)
                        # 성스러운 이펙트 활성화
                        self.holy_ball_active = True
                        self.holy_ball_timer = self.holy_ball_duration
                        game_state['ball_holy'] = True

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        # 배리어 사운드 정지
        if self._barrier_sound:
            self._barrier_sound.stop()
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
        # 배리어 사운드 정지
        if self._barrier_sound:
            self._barrier_sound.stop()
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
            base_alpha = int(150 + 50 * _sin(pygame.time.get_ticks() / 100))
            barrier_alpha = int(base_alpha * fade_alpha)

            # 메인 배리어 라인 (화면 전체 너비 0~760)
            if barrier_alpha > 0:
                barrier_surf = _psurf((760, 8), pygame.SRCALPHA)
                pygame.draw.line(barrier_surf, (180, 200, 220, barrier_alpha),
                               (0, 4), (760, 4), 4)
                screen.blit(barrier_surf, (0, int(self.barrier_y) - 4))

            # === 배리어 충돌 플래시 이펙트 ===
            if self.barrier_hit_flash_timer > 0:
                flash_ratio = self.barrier_hit_flash_timer / self.barrier_hit_flash_duration
                # 배리어 라인 전체가 밝게 번쩍 (충돌 직후 강하게 → 빠르게 감쇄)
                flash_alpha = int(220 * flash_ratio)
                if flash_alpha > 0:
                    flash_surf = _psurf((760, 14), pygame.SRCALPHA)
                    pygame.draw.line(flash_surf, (230, 245, 255, flash_alpha),
                                   (0, 7), (760, 7), 6)
                    screen.blit(flash_surf, (0, int(self.barrier_y) - 7),
                               special_flags=pygame.BLEND_ADD)
                    # 충돌 지점 주변 집중 플래시 (더 밝고 넓게)
                    cx = int(self.barrier_hit_x)
                    local_alpha = int(255 * flash_ratio)
                    local_w = 120
                    local_surf = _psurf((local_w, 20), pygame.SRCALPHA)
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
                    ring_surf = _psurf((ring_size, ring_size), pygame.SRCALPHA)
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
                p_surf = _psurf((p_size * 2, p_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(p_surf, color, (p_size, p_size), p_size)
                screen.blit(p_surf, (int(p['x']) - p_size, int(p['y']) - p_size),
                           special_flags=pygame.BLEND_ADD)

            # 톱니바퀴 장식 (화면 전체에 균등 배치: 5개)
            for x in [76, 228, 380, 532, 684]:
                gear_alpha = int(200 * fade_alpha)
                if gear_alpha <= 0:
                    continue
                gear_surf = _psurf((30, 30), pygame.SRCALPHA)
                teeth = 8
                for i in range(teeth):
                    angle = math.radians(i * 360 / teeth + pygame.time.get_ticks() / 50)
                    inner = 8
                    outer = 12
                    x1 = 15 + _cos(angle) * inner
                    y1 = 15 + _sin(angle) * inner
                    x2 = 15 + _cos(angle) * outer
                    y2 = 15 + _sin(angle) * outer
                    pygame.draw.line(gear_surf, (140, 100, 60, gear_alpha), (x1, y1), (x2, y2), 3)
                pygame.draw.circle(gear_surf, (160, 120, 80, gear_alpha), (15, 15), 8)
                pygame.draw.circle(gear_surf, (100, 80, 50, gear_alpha), (15, 15), 4)
                screen.blit(gear_surf, (x - 15, int(self.barrier_y) - 15))

            # 증기 파티클
            for p in self.steam_particles:
                alpha = int(100 * (p['life'] / 0.8) * fade_alpha)
                if alpha <= 0:
                    continue
                surf = _psurf((int(p['size'] * 2), int(p['size'] * 2)), pygame.SRCALPHA)
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
                    ring_surf = _psurf((ring_radius * 2 + 4, ring_radius * 2 + 4), pygame.SRCALPHA)
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
                p_surf = _psurf((p_size * 2, p_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(p_surf, color, (p_size, p_size), p_size)
                screen.blit(p_surf, (int(p['x']) - p_size, int(p['y']) - p_size),
                           special_flags=pygame.BLEND_ADD)

            # 3) 시전자 주변 코어 글로우 (에너지 집중 효과)
            glow_pulse = 0.7 + 0.3 * _sin(pygame.time.get_ticks() / 120)
            core_alpha = int(80 * glow_pulse * fade_alpha)
            if core_alpha > 0:
                # 외부 주황색 오오라
                outer_size = 35 + int(8 * _sin(pygame.time.get_ticks() / 200))
                outer_surf = _psurf((outer_size * 2, outer_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(outer_surf, (200, 140, 40, core_alpha // 2),
                                  (outer_size, outer_size), outer_size)
                screen.blit(outer_surf, (cx - outer_size, cy - outer_size),
                           special_flags=pygame.BLEND_ADD)
                # 내부 밝은 글로우
                inner_size = 20 + int(4 * _sin(pygame.time.get_ticks() / 150))
                inner_surf = _psurf((inner_size * 2, inner_size * 2), pygame.SRCALPHA)
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
                    flash_surf = _psurf((760, 20), pygame.SRCALPHA)
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
                    ring_surf = _psurf((ring_size, ring_size), pygame.SRCALPHA)
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
                shard_surf = _psurf((w + 4, h + 4), pygame.SRCALPHA)
                # 중심 기준 4개 꼭짓점 회전
                cx_s, cy_s = (w + 4) / 2, (h + 4) / 2
                cos_a = _cos(s['angle'])
                sin_a = _sin(s['angle'])
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
                gear_surf = _psurf((sz * 2 + 4, sz * 2 + 4), pygame.SRCALPHA)
                gc = sz + 2
                # 미니 톱니바퀴 그리기 (회전 적용)
                teeth = g['teeth']
                for i in range(teeth):
                    t_angle = g['angle'] + i * (math.pi * 2 / teeth)
                    inner = sz * 0.5
                    outer = sz
                    x1 = gc + _cos(t_angle) * inner
                    y1 = gc + _sin(t_angle) * inner
                    x2 = gc + _cos(t_angle) * outer
                    y2 = gc + _sin(t_angle) * outer
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
                steam_surf = _psurf((p_size * 2, p_size * 2), pygame.SRCALPHA)
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
                    trail_surf = _psurf((trail_size * 2, trail_size * 2), pygame.SRCALPHA)
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
                    cross_surf = _psurf((p_size * 4, p_size * 4), pygame.SRCALPHA)
                    cx, cy = p_size * 2, p_size * 2
                    cross_color = (255, 240, 180, p_alpha)
                    pygame.draw.line(cross_surf, cross_color,
                                   (cx, cy - p_size), (cx, cy + p_size), max(1, p_size // 2))
                    pygame.draw.line(cross_surf, cross_color,
                                   (cx - p_size, cy), (cx + p_size, cy), max(1, p_size // 2))
                    screen.blit(cross_surf, (int(p['x']) - p_size * 2, int(p['y']) - p_size * 2),
                               special_flags=pygame.BLEND_ADD)
                    continue

                p_surf = _psurf((p_size * 2, p_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(p_surf, color, (p_size, p_size), p_size)
                screen.blit(p_surf, (int(p['x']) - p_size, int(p['y']) - p_size),
                           special_flags=pygame.BLEND_ADD)

            # 공 주변 성스러운 글로우 (ball이 있을 때)
            if self.holy_ball_active and ball:
                # 공 중심 좌표 (ball.x/y는 좌상단이므로 보정)
                ball_cx = ball.x + getattr(ball, 'width', 10) / 2
                ball_cy = ball.y + getattr(ball, 'height', 10) / 2
                # 외부 금빛 오오라
                glow_size = 22 + int(4 * _sin(pygame.time.get_ticks() / 150))
                glow_surf = _psurf((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
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
                    rx = ball_cx + _cos(angle) * 14
                    ry = ball_cy + _sin(angle) * 14
                    dot_surf = _psurf((6, 6), pygame.SRCALPHA)
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
            description="끈적한 기름 웅덩이가 적 진영을 뒤덮어 발을 묶는다",
            trigger=SkillTrigger.ON_BALL_HIT,
            cooldown=12.0,
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
                proj['y'] = start_y + (proj['target_y'] - start_y) * t + _sin(t * math.pi) * arc_height
            else:
                # 아래에서 위로
                proj['y'] = start_y + (proj['target_y'] - start_y) * t - _sin(t * math.pi) * arc_height

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
                bx = puddle['x'] + _cos(angle) * pw * 0.45 * dist
                by = puddle['y'] + _sin(angle) * ph * 0.35 * dist
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
                    b['size'] = b['max_size'] + _sin(b['life'] * 6) * 0.5
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
        if self.activation_flash_timer > 0:
            self.activation_flash_timer -= dt

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
        surf = _psurf((size * 2 + pad * 2, size * 2 + pad * 2), pygame.SRCALPHA)
        center = size + pad
        wobble_offset = _sin(proj['wobble']) * 3

        # 글로우 (부드러운 외곽)
        pygame.draw.circle(surf, (*self._oil_colors['mid'], 60), (center, center), size + 4)

        # 메인 덩어리 (불규칙 형태)
        points = []
        for angle in range(0, 360, 25):
            rad = math.radians(angle)
            r = size * (0.8 + 0.25 * _sin(rad * 3 + proj['wobble']))
            points.append((int(center + _cos(rad) * r), int(center + _sin(rad) * r)))
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
        w = int(puddle['width'] + _sin(puddle['wobble']) * 4)
        h = int(puddle['height'])
        alpha = puddle['alpha']
        if alpha < 3:
            return

        pad = 16
        surf_w = w + pad * 2
        surf_h = h + pad * 2
        surf = _psurf((surf_w, surf_h), pygame.SRCALPHA)
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
            sx_offset = _sin(shimmer * 1.2 + i * 2.1) * w * 0.15
            sy_offset = _cos(shimmer * 0.9 + i * 1.7) * h * 0.1
            sw_ratio = 0.25 + 0.08 * _sin(shimmer * 1.5 + i)
            sh_ratio = 0.3 + 0.1 * _sin(shimmer * 1.8 + i)
            sa = int(alpha * (0.15 + 0.08 * _sin(shimmer * 2.0 + i * 0.7)))
            sw = max(4, int(w * sw_ratio))
            sh_val = max(2, int(h * sh_ratio))
            pygame.draw.ellipse(surf, (*sc, sa),
                              (int(cx + sx_offset - sw // 2), int(cy + sy_offset - sh_val // 2), sw, sh_val))

        # --- 표면 하이라이트 (큰 반사) ---
        hl_x = cx + int(_sin(shimmer * 0.7) * w * 0.12) - int(w * 0.08)
        hl_y = cy - int(h * 0.12)
        hl_w = max(3, int(w * 0.2))
        hl_h = max(2, int(h * 0.2))
        hl_a = int(alpha * (0.2 + 0.08 * _sin(shimmer * 1.3)))
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
                rs = _psurf((rr * 2 + 4, rr * 2 + 4), pygame.SRCALPHA)
                rc = rr + 2
                ra = int(max(0, min(255, r['alpha'])))
                pygame.draw.circle(rs, (*self._oil_colors['surface'], ra), (rc, rc), rr, 1)
                screen.blit(rs, (int(r['x']) - rc, int(r['y']) - rc))

    def _oil_shape_points(self, cx, cy, half_w, half_h, seed, time, irregularity):
        """기름 웅덩이 불규칙 타원 꼭짓점 생성"""
        points = []
        for angle in range(0, 360, 18):
            rad = math.radians(angle)
            wobble = 1.0 + irregularity * _sin(rad * 4 + seed + time * 0.8)
            px = cx + int(_cos(rad) * half_w * wobble)
            py = cy + int(_sin(rad) * half_h * wobble)
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
                px = int(bubble['x'] + _cos(angle) * dist)
                py = int(bubble['y'] + _sin(angle) * dist)
                frag_a = int(80 * (1 - pop_p))
                if frag_a > 3:
                    ps = _psurf((4, 4), pygame.SRCALPHA)
                    pygame.draw.circle(ps, (*self._oil_colors['bubble_highlight'], frag_a), (2, 2), 1)
                    screen.blit(ps, (px - 2, py - 2))
            return

        ba = int(min(255, puddle_alpha * 0.9))
        pad = 4
        bs = _psurf((s * 2 + pad * 2, s * 2 + pad * 2), pygame.SRCALPHA)
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
            description="어둠 속에서 분신이 나타나 공을 되받아친다",
            trigger=SkillTrigger.ON_COOLDOWN,
            cooldown=18.0,
            duration=8.0,
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

        # 분신 3~5개 생성 (좌우로 벌어지며 등장)
        clone_count = random.randint(3, 5)
        if clone_count == 3:
            offsets = [-120, 0, 120]  # 3개: 좌, 중앙, 우
        elif clone_count == 4:
            offsets = [-150, -50, 50, 150]  # 4개: 좌좌, 좌, 우, 우우
        else:
            offsets = [-160, -80, 0, 80, 160]  # 5개: 좌좌, 좌, 중앙, 우, 우우
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
                # 이동 애니메이션 상태 (개별 관절 모션)
                'anim_state': {
                    "last_x": self.spawn_x,
                    "velocity": 0.0,
                    "lean": 0.0,
                    "step_phase": random.uniform(0, math.pi * 2),  # 분신마다 다른 위상
                    "shoulder_phase": 0.0,
                    "arm_swing": 0.0,
                    "head_tilt": 0.0,
                    "body_bob": 0.0,
                    "move_dir": 0.0,
                    "side_blend": 0.0,
                    "weapon_swing_timer": 0.0,
                    "weapon_swing_duration": 0.25,
                },
            }
            self.clones.append(clone)

        # 프레임 카운터 초기화
        self._frame_count = 0
        self._draw_count = 0

        game_state['has_shadow_clones'] = True

        # 그림자분신 발동 사운드 재생
        try:
            import os
            project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            sound_path = os.path.join(project_root, "sounds", "kurokake.wav")
            if os.path.exists(sound_path):
                pygame.mixer.Sound(sound_path).play()
        except Exception:
            pass

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

            # 분신 이동 애니메이션 상태 업데이트
            anim_state = clone['anim_state']
            current_x = float(rect.centerx)
            anim_velocity = (current_x - anim_state["last_x"]) / max(dt, 0.001)
            anim_state["velocity"] = anim_velocity * 0.3 + anim_state["velocity"] * 0.7

            target_lean = max(-1.0, min(1.0, anim_state["velocity"] / 200.0))
            anim_state["lean"] = anim_state["lean"] * 0.85 + target_lean * 0.15

            move_speed = abs(anim_state["velocity"])
            if move_speed > 25:
                target_dir = 1.0 if anim_state["velocity"] > 0 else -1.0
            else:
                target_dir = 0.0
            anim_state["move_dir"] = anim_state["move_dir"] * 0.82 + target_dir * 0.18
            target_side = min(1.0, move_speed / 160.0)
            anim_state["side_blend"] = anim_state["side_blend"] * 0.88 + target_side * 0.12

            side_factor = anim_state["side_blend"]
            if move_speed > 5:
                step_speed = 12.0 + side_factor * 4.0
                anim_state["step_phase"] += dt * step_speed
                anim_state["shoulder_phase"] += dt * step_speed
                speed_factor = min(1.0, move_speed / 150.0)
                anim_state["body_bob"] = _sin(anim_state["step_phase"] * 2) * speed_factor * (0.3 + side_factor * 0.25)
                arm_amp = min(1.0, move_speed / 100.0) * (1.0 + side_factor * 0.25)
                anim_state["arm_swing"] = _sin(anim_state["step_phase"]) * arm_amp
                anim_state["head_tilt"] = _sin(anim_state["step_phase"] * 1.5) * 0.3 * speed_factor
            else:
                anim_state["body_bob"] *= 0.9
                anim_state["arm_swing"] *= 0.9
                anim_state["head_tilt"] *= 0.9

            anim_state["last_x"] = current_x

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

                    # 분신 소멸 사운드 재생
                    try:
                        import os
                        project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                        sound_path = os.path.join(project_root, "sounds", "kurokakeout.wav")
                        if os.path.exists(sound_path):
                            pygame.mixer.Sound(sound_path).play()
                    except Exception:
                        pass

                    continue

            new_clones.append(clone)

        self.clones = new_clones
        # dying_clones 업데이트는 update() 메서드에서 처리

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        game_state['has_shadow_clones'] = False
        # 남아있는 활성 분신들을 dying_clones로 이동 (소멸 애니메이션 재생)
        had_active = False
        for clone in self.clones:
            if clone['active']:
                dying_clone = {
                    'rect': clone['rect'].copy(),
                    'death_time': 0.0,
                    'id': clone['id'],
                }
                self.dying_clones.append(dying_clone)
                had_active = True
        self.clones = []

        # 분신 소멸 사운드 재생 (활성 분신이 있었을 때만)
        if had_active:
            try:
                import os
                project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                sound_path = os.path.join(project_root, "sounds", "kurokakeout.wav")
                if os.path.exists(sound_path):
                    pygame.mixer.Sound(sound_path).play()
            except Exception:
                pass

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
        hop = int(4 * _sin(spawn_time * 5))

        alpha = int(200 * emerge_progress)
        x = rect.centerx
        y = rect.centery + hop

        # 바닥 그림자 먼저 그리기
        shadow_width = int(self.CLONE_WIDTH * 0.9)
        shadow_surf = _psurf((shadow_width, 10), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_surf, (10, 10, 25, int(alpha * 0.5)),
                          (0, 0, shadow_width, 10))
        screen.blit(shadow_surf, (x - shadow_width // 2, y + 15))

        # HeroPaddleRenderer가 있으면 실제 캐릭터 그리기
        if renderer and HERO_PADDLE_RENDERER_AVAILABLE:
            char_width = 120
            char_height = 100
            temp_surf = _psurf((char_width, char_height), pygame.SRCALPHA)

            renderer.update(1/60)
            shadow_color = (70, 60, 100)

            try:
                # 분신 개별 이동 애니메이션: 렌더러 상태를 임시 교체
                original_state = renderer.hero_states.get("kurokage")
                renderer.hero_states["kurokage"] = clone['anim_state']

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

                # 렌더러 상태 복원
                if original_state is not None:
                    renderer.hero_states["kurokage"] = original_state
                else:
                    renderer.hero_states.pop("kurokage", None)

                temp_surf.set_alpha(alpha)
                screen.blit(temp_surf, (x - char_width // 2, y - char_height + 15))

            except Exception as e:
                # 에러 시 렌더러 상태 복원
                if original_state is not None:
                    renderer.hero_states["kurokage"] = original_state
                else:
                    renderer.hero_states.pop("kurokage", None)
                self._draw_fallback_clone(screen, x, y, alpha)
        else:
            self._draw_fallback_clone(screen, x, y, alpha)

    def _draw_fallback_clone(self, screen: pygame.Surface, x: int, y: int, alpha: int):
        """폴백 분신 렌더링 (실루엣 스타일)"""
        # 닌자 실루엣
        body_color = (50, 50, 70, alpha)
        outline_color = (80, 80, 120, alpha)

        # 몸통
        body_surf = _psurf((40, 50), pygame.SRCALPHA)
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
        glitch_x = int(_sin(dying['death_time'] * 35) * glitch_intensity)
        glitch_y = int(_cos(dying['death_time'] * 28) * glitch_intensity * 0.5)

        char_width = 150
        char_height = 120

        if renderer and HERO_PADDLE_RENDERER_AVAILABLE and base_alpha > 30:
            # RGB 분리 효과로 캐릭터 3번 그리기
            for color_offset, tint in [(-4, (255, 80, 80)), (0, (180, 180, 220)), (4, (80, 255, 255))]:
                temp_surf = _psurf((char_width, char_height), pygame.SRCALPHA)
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
                    surf = _psurf((50, 60), pygame.SRCALPHA)
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

    GAME_TOP = 0
    GAME_BOTTOM = 750
    SHURIKEN_SIZE = 18  # 수리검 반지름

    def __init__(self):
        super().__init__(
            skill_id="illusion_shuriken",
            name="Illusion Shuriken",
            korean_name="환영수리검",
            description="연속으로 쏟아지는 수리검이 상대를 밀어낸다",
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
        self.total_shurikens = random.randint(4, 6)  # 4~6개 랜덤
        self.knockback_applied = False
        self.hit_effects = []

        # 첫 번째 수리검 즉시 발사
        self._spawn_shuriken(caster_paddle, 0)
        game_state['kurokage_weapon_swing'] = True

        return {
            'sound': 'shuriken'
        }

    def _spawn_shuriken(self, caster_paddle, index: int):
        """수리검 생성 - 좌우 번갈아가며 부채꼴 형태로 발사 (3~5개)"""
        # 각도 범위: 20~60도 (0.35~1.05 rad)
        # 수리검 개수에 따라 각도를 균등 분배
        total = self.total_shurikens

        # 부채꼴 형태로 각도 분배 (-60도 ~ +60도 범위)
        if total == 4:
            angles_deg = [-50, -17, 17, 50]
        elif total == 5:
            angles_deg = [-55, -28, 0, 28, 55]
        else:  # 6개
            angles_deg = [-58, -35, -12, 12, 35, 58]

        # 인덱스에 해당하는 각도 선택 (약간의 랜덤 추가)
        base_angle_deg = angles_deg[index] if index < len(angles_deg) else 0
        angle_deg = base_angle_deg + random.uniform(-5, 5)  # ±5도 랜덤 변화
        angle_rad = math.radians(angle_deg)

        speed = 450  # 수리검 속도

        # 방향 계산: caster_is_top이면 아래로(+Y), 아니면 위로(-Y)
        if self.caster_is_top:
            # 상단에서 하단으로 발사
            vy = speed * _cos(angle_rad)
            vx = speed * _sin(angle_rad)
        else:
            # 하단에서 상단으로 발사
            vy = -speed * _cos(angle_rad)
            vx = speed * _sin(angle_rad)

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
            import os
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
            if self.spawn_timer >= 0.2:
                self.spawn_timer = 0
                self._spawn_shuriken(caster_paddle, self.shurikens_spawned)
                game_state['kurokage_weapon_swing'] = True

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

                # 마법결계 면역 체크 - 면역 상태면 넉백/스턴 차단
                _immunity_side = 'top' if self.target_is_top else 'bottom'
                if game_state.get(f'magic_immunity_{_immunity_side}', False):
                    # 수리검은 소멸하지만 넉백/스턴은 적용하지 않음
                    # 패링 이펙트 이벤트 전달
                    if 'barrier_block_events' not in game_state:
                        game_state['barrier_block_events'] = []
                    game_state['barrier_block_events'].append({
                        'skill_korean_name': self.korean_name,
                        'caster_is_top': getattr(self, 'caster_is_top', True),
                        'caster_x': caster_paddle.x + getattr(caster_paddle, 'width', 80) / 2,
                        'caster_y': caster_paddle.y + getattr(caster_paddle, 'height', 10) / 2,
                        'target_x': target_paddle.x + getattr(target_paddle, 'width', 80) / 2,
                        'target_y': target_paddle.y + getattr(target_paddle, 'height', 10) / 2,
                    })
                    continue

                # 수리검 히트 사운드 재생
                try:
                    import os
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
                game_state['screen_shake'] = 3
                game_state['shake_duration'] = 0.2

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
                flash_surf = _psurf((flash_size * 2, flash_size * 2), pygame.SRCALPHA)
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
                        ring_surf = _psurf((ring_r * 2 + 4, ring_r * 2 + 4), pygame.SRCALPHA)
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
                    x1 = ex + _cos(angle_rad) * slash_length
                    y1 = ey + _sin(angle_rad) * slash_length
                    x2 = ex - _cos(angle_rad) * slash_length
                    y2 = ey - _sin(angle_rad) * slash_length
                    # 메인 슬래시
                    slash_surf = _psurf((int(slash_length * 2 + 10), int(slash_length * 2 + 10)), pygame.SRCALPHA)
                    center = int(slash_length + 5)
                    lx1 = center + _cos(angle_rad) * slash_length
                    ly1 = center + _sin(angle_rad) * slash_length
                    lx2 = center - _cos(angle_rad) * slash_length
                    ly2 = center - _sin(angle_rad) * slash_length
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
                        surf = _psurf((size * 2 + 2, size * 2 + 2), pygame.SRCALPHA)
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
        surf = _psurf((shuriken_size * 2, shuriken_size * 2), pygame.SRCALPHA)

        center = shuriken_size
        # 4개의 날
        for i in range(4):
            angle = math.radians(rotation + i * 90)
            x1 = center + _cos(angle) * 4
            y1 = center + _sin(angle) * 4
            x2 = center + _cos(angle) * shuriken_size
            y2 = center + _sin(angle) * shuriken_size

            # 날 색상 (보라빛 금속)
            blade_color = (130, 110, 170, alpha)
            edge_color = (180, 160, 220, alpha)

            pygame.draw.polygon(surf, blade_color, [
                (center, center),
                (x1 + _cos(angle + 0.4) * 7, y1 + _sin(angle + 0.4) * 7),
                (x2, y2),
                (x1 + _cos(angle - 0.4) * 7, y1 + _sin(angle - 0.4) * 7)
            ])

            # 날 가장자리 하이라이트
            pygame.draw.line(surf, edge_color,
                           (center, center), (x2, y2), 1)

        # 중앙 원
        pygame.draw.circle(surf, (100, 80, 140, alpha), (center, center), 5)
        pygame.draw.circle(surf, (150, 130, 190, alpha), (center, center), 3)

        screen.blit(surf, (int(x - shuriken_size), int(y - shuriken_size)))


# ============================================================================
# 벤시 스킬 - 유령 여왕 (트릭형)
# ============================================================================
# 호위무사 좌표 상수 (colosseum_arena 순환 import 방지)
TOP_PADDLE_Y = 25
BOTTOM_PADDLE_Y = 710

class Charm(HeroSkill):
    """매혹 - 자력 에너지를 발사하여 상대 호위무사를 끌어들임 (10~20초)

    4단계 연출:
    1) projectile: 자력 에너지 탄을 상대 호위무사에게 발사
    2) pulling:    에너지가 호위무사를 감싸고 시전자 진영으로 견인
    3) active:     매혹된 호위무사가 아군으로 순찰·스킬 사용
    4) returning:  지속시간 종료 후 원래 진영으로 복귀
    """

    def __init__(self):
        super().__init__(
            skill_id="charm",
            name="Charm",
            korean_name="매혹",
            description="요염한 마력이 적의 호위무사를 홀려 아군으로 끌어들인다",
            trigger=SkillTrigger.ON_COOLDOWN,
            cooldown=38.0,
            duration=15.0,
            hero_id="banshee"
        )
        # === 매혹 상태 ===
        self.charmed_guard = None
        self.charm_source_is_top = True
        self._charm_applied = False

        # === 4단계 페이즈 ===
        self.charm_phase = "idle"  # idle / projectile / pulling / active / returning
        self.phase_timer = 0.0

        # --- Phase 1: 발사체 ---
        self.proj_x = 0.0
        self.proj_y = 0.0
        self.proj_target_x = 0.0
        self.proj_target_y = 0.0
        self.proj_progress = 0.0
        self.proj_speed = 2.0        # progress/초  (약 0.5초 비행)
        self.proj_rotation = 0.0
        self.proj_trail = []         # 자력 에너지 잔상
        self.proj_orbs = []          # 발사체 주위 궤도 구슬

        # --- Phase 2: 견인 ---
        self.pull_start_x = 0.0
        self.pull_start_y = 0.0
        self.pull_end_x = 0.0
        self.pull_end_y = 0.0
        self.pull_progress = 0.0
        self.pull_speed = 1.2        # progress/초  (약 0.8초 견인)
        self.pull_chain_particles = []

        # --- Phase 3: 활동 ---
        self.charm_aura_timer = 0.0
        self.charm_particles = []
        self.charm_elapsed = 0.0     # 활동 페이즈 경과 시간 (base active_timer와 충돌 방지)

        # --- Phase 4: 복귀 ---
        self.return_start_x = 0.0
        self.return_start_y = 0.0
        self.return_end_x = 0.0
        self.return_end_y = 0.0
        self.return_progress = 0.0
        self.return_speed = 1.5      # progress/초  (약 0.7초 복귀)

        # === 차원의 문 모드 (스토리모드 전용) ===
        self._dimensional_mode = False
        self._dim_phase = "idle"          # idle/portal_opening/summoned_active/portal_closing/done
        self._dim_timer = 0.0
        self._dim_portal_x = 0.0
        self._dim_portal_y = 0.0
        self._dim_summoned_hero_id = None
        self._dim_portal_particles = []   # 소용돌이 파티클
        self._dim_portal_angle = 0.0      # 소용돌이 회전각
        self._dim_portal_scale = 0.0      # 포탈 열림 스케일 (0→1)
        self._dim_duration = 30.0         # 소환 지속시간
        self._dim_elapsed = 0.0
        self._dim_lightning_arcs = []     # 전기 아크 이펙트

    # ------------------------------------------------------------------
    #  can_use
    # ------------------------------------------------------------------
    def can_use(self) -> bool:
        if self.current_cooldown > 0 or self.is_active:
            return False
        return True

    # ------------------------------------------------------------------
    #  update (오버라이드: 복귀 페이즈에서 is_active가 꺼지는 것을 방지)
    # ------------------------------------------------------------------
    def update(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        # 쿨타임 감소 (base 로직 동일)
        if self.current_cooldown > 0:
            self.current_cooldown -= dt
        if self.activation_flash_timer > 0:
            self.activation_flash_timer -= dt

        if self.is_active:
            self.active_timer -= dt
            self._update_active_effect(dt, caster_paddle, target_paddle, ball, game_state)
            if self.active_timer <= 0:
                self._end_effect(caster_paddle, target_paddle, ball, game_state)
                # _end_effect에서 returning/portal_closing 페이즈로 전환하며
                # is_active=True, active_timer를 설정할 수 있음 → 그때는 꺼지면 안됨
                if (self.charm_phase != "returning"
                        and self._dim_phase not in ("portal_closing", "portal_return_opening")):
                    self.is_active = False

    # ------------------------------------------------------------------
    #  _apply_effect  (Phase 1 시작)
    # ------------------------------------------------------------------
    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        # ─── 스토리모드(호위무사) → 차원의 문 소환 ───
        if game_state.get('is_ingame_bodyguard'):
            return self._apply_dimensional_gate(caster_paddle, target_paddle, ball, game_state)

        # 매혹 지속시간 10~20초 랜덤
        self.duration = random.uniform(10.0, 20.0)
        self.active_timer = self.duration
        self.charm_source_is_top = getattr(self, 'caster_is_top', True)
        self._charm_applied = False
        self.charmed_guard = None
        self.charm_particles = []
        self.charm_aura_timer = 0.0
        self.charm_elapsed = 0.0

        # 시전자 좌표
        caster = caster_paddle if self.charm_source_is_top else target_paddle
        cx = caster.x + (caster.width // 2 if hasattr(caster, 'width') else 40)
        cy = 50 if self.charm_source_is_top else 700

        # 상대 호위무사 좌표를 game_state에서 가져옴
        # caster_is_top이면 상대는 bottom, 아니면 top
        enemy_side = 'bottom' if self.charm_source_is_top else 'top'
        guard_info = game_state.get(f'_guard_info_{enemy_side}', None)
        if guard_info:
            self.proj_target_x = guard_info.get('x', 380)
            self.proj_target_y = guard_info.get('y', (BOTTOM_PADDLE_Y if self.charm_source_is_top else TOP_PADDLE_Y))
        else:
            # 폴백: 상대 패들 쪽 중앙
            self.proj_target_x = 380
            self.proj_target_y = BOTTOM_PADDLE_Y if self.charm_source_is_top else TOP_PADDLE_Y

        self.proj_x = cx
        self.proj_y = cy
        self.proj_progress = 0.0
        self.proj_rotation = 0.0
        self.proj_trail = []

        # 궤도 구슬 초기화 (6개)
        self.proj_orbs = []
        for i in range(6):
            self.proj_orbs.append({
                'angle': (math.pi * 2 / 6) * i,
                'dist': random.uniform(12, 20),
                'speed': random.uniform(4.0, 7.0),
                'size': random.uniform(2, 4),
            })

        # Phase 1 시작
        self.charm_phase = "projectile"
        self.phase_timer = 0.0

        # 매혹 페이즈 시작을 GuardWarriorSystem에 알림
        game_state['charm_phase_request'] = {
            'caster_is_top': self.charm_source_is_top,
            'phase': 'projectile',
        }

        # 매혹 발사 사운드
        try:
            project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            love_path = os.path.join(project_root, "sounds", "bencylove.wav")
            if os.path.exists(love_path):
                love_snd = pygame.mixer.Sound(love_path)
                love_snd.set_volume(0.8)
                love_snd.play()
        except Exception:
            pass

        return {
            'screen_effect': ScreenEffect.FLASH,
            'flash_color': (100, 60, 180),
        }

    # ------------------------------------------------------------------
    #  _init_pull_chain  (Phase 2 초기화)
    # ------------------------------------------------------------------
    def _init_pull_chain(self):
        """견인 체인 파티클 초기화"""
        self.pull_chain_particles = []
        for i in range(12):
            self.pull_chain_particles.append({
                'offset': random.uniform(-8, 8),
                'phase': random.uniform(0, math.pi * 2),
                'speed': random.uniform(3, 6),
                'size': random.uniform(2, 5),
            })

    # ------------------------------------------------------------------
    #  _update_active_effect
    # ------------------------------------------------------------------
    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        # ─── 차원의 문 모드 ───
        if self._dimensional_mode:
            self._update_dimensional(dt, caster_paddle, target_paddle, ball, game_state)
            return

        self.phase_timer += dt
        self.charm_aura_timer += dt

        # === Phase 1: 발사체 비행 ===
        if self.charm_phase == "projectile":
            self.proj_progress += dt * self.proj_speed
            self.proj_rotation += dt * 360

            # 현재 발사체 위치
            cur_x = self.proj_x + (self.proj_target_x - self.proj_x) * self.proj_progress
            cur_y = self.proj_y + (self.proj_target_y - self.proj_y) * self.proj_progress

            # 궤도 구슬 업데이트
            for orb in self.proj_orbs:
                orb['angle'] += dt * orb['speed']

            # 트레일 파티클
            if self.proj_progress > 0.05:
                self.proj_trail.append({
                    'x': cur_x + random.uniform(-5, 5),
                    'y': cur_y + random.uniform(-5, 5),
                    'size': random.uniform(3, 8),
                    'life': 0.5,
                    'max_life': 0.5,
                    'color_type': random.choice(['magenta', 'cyan', 'purple']),
                })

            # 트레일 업데이트
            alive = []
            for t in self.proj_trail:
                t['life'] -= dt
                if t['life'] > 0:
                    alive.append(t)
            self.proj_trail = alive

            # 도착 → Phase 2 전환
            if self.proj_progress >= 1.0:
                self.charm_phase = "pulling"
                self.phase_timer = 0.0
                self.proj_trail = []

                # 견인 시작/끝 좌표 설정
                self.pull_start_x = self.proj_target_x
                self.pull_start_y = self.proj_target_y
                # 시전자 쪽 하단/상단 순찰 위치로 이동
                self.pull_end_x = self.proj_target_x  # X는 비슷하게 유지
                if self.charm_source_is_top:
                    self.pull_end_y = TOP_PADDLE_Y  # 상단 시전 → 상단으로 끌어옴
                else:
                    self.pull_end_y = BOTTOM_PADDLE_Y  # 하단 시전 → 하단으로 끌어옴
                self.pull_progress = 0.0
                self._init_pull_chain()

                # GuardWarriorSystem에 '견인' 알림 → 적 호위무사 빼앗기
                game_state['charm_phase_request'] = {
                    'caster_is_top': self.charm_source_is_top,
                    'phase': 'pulling',
                }

        # === Phase 2: 견인 (호위무사를 아군 진영으로 끌어옴) ===
        elif self.charm_phase == "pulling":
            self.pull_progress += dt * self.pull_speed

            # 체인 파티클 웨이브
            for cp in self.pull_chain_particles:
                cp['phase'] += dt * cp['speed']

            # ease-out 커브로 부드럽게
            t = min(1.0, self.pull_progress)
            ease_t = 1 - (1 - t) ** 3  # cubic ease-out

            # 견인 중 호위무사 위치를 game_state에 알려줌
            pull_cur_x = self.pull_start_x + (self.pull_end_x - self.pull_start_x) * ease_t
            pull_cur_y = self.pull_start_y + (self.pull_end_y - self.pull_start_y) * ease_t
            game_state['charm_pull_position'] = {
                'x': pull_cur_x,
                'y': pull_cur_y,
                'progress': ease_t,
            }

            # 견인 완료 → Phase 3 전환
            if self.pull_progress >= 1.0:
                self.charm_phase = "active"
                self.phase_timer = 0.0
                self.charm_elapsed = 0.0
                self.pull_chain_particles = []

                # GuardWarriorSystem에 '활동' 알림 → 아군 순찰 시작
                game_state['charm_phase_request'] = {
                    'caster_is_top': self.charm_source_is_top,
                    'phase': 'active',
                }
                game_state.pop('charm_pull_position', None)

        # === Phase 3: 활동 (매혹된 호위무사가 아군으로 행동) ===
        elif self.charm_phase == "active":
            self.charm_elapsed += dt

            # 아군 행동은 GuardWarriorSystem이 관리
            # 여기서는 시각 이펙트만 관리
            caster = caster_paddle if self.charm_source_is_top else target_paddle
            cx = caster.x + (caster.width // 2 if hasattr(caster, 'width') else 40)

            # 매혹 파티클 (하트/유령빛)
            if random.random() < 0.25:
                base_y = 50 if self.charm_source_is_top else 700
                self.charm_particles.append({
                    'x': cx + random.uniform(-50, 50),
                    'y': base_y + random.uniform(-15, 15),
                    'vy': random.uniform(-25, -50) if self.charm_source_is_top else random.uniform(25, 50),
                    'vx': random.uniform(-10, 10),
                    'life': random.uniform(0.8, 1.5),
                    'max_life': 1.5,
                    'size': random.uniform(2, 5),
                    'is_heart': random.random() < 0.3,
                })

            # 파티클 업데이트
            alive = []
            for p in self.charm_particles:
                p['x'] += p['vx'] * dt
                p['y'] += p['vy'] * dt
                p['life'] -= dt
                if p['life'] > 0:
                    alive.append(p)
            self.charm_particles = alive

            game_state['charm_active'] = True
            game_state['charm_caster_is_top'] = self.charm_source_is_top

        # === Phase 4: 복귀 (지속시간 종료, _end_effect에서 시작) ===
        elif self.charm_phase == "returning":
            self.return_progress += dt * self.return_speed

            t = min(1.0, self.return_progress)
            ease_t = 1 - (1 - t) ** 3

            # 복귀 중 호위무사 위치
            ret_x = self.return_start_x + (self.return_end_x - self.return_start_x) * ease_t
            ret_y = self.return_start_y + (self.return_end_y - self.return_start_y) * ease_t
            game_state['charm_return_position'] = {
                'x': ret_x,
                'y': ret_y,
                'progress': ease_t,
            }

            if self.return_progress >= 1.0:
                self.charm_phase = "idle"
                game_state.pop('charm_return_position', None)
                # 완전 복귀 → GuardWarriorSystem에 최종 반환 (복귀 위치 전달)
                game_state['charm_phase_request'] = {
                    'caster_is_top': self.charm_source_is_top,
                    'phase': 'returned',
                    'return_x': self.return_end_x,
                }

    # ------------------------------------------------------------------
    #  _end_effect  (Phase 4 시작 - 복귀)
    # ------------------------------------------------------------------
    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        # ─── 차원의 문 모드: 지속시간 종료 처리 ───
        if self._dimensional_mode:
            if self._dim_phase == "summoned_active":
                # 소환 활동 종료 → 복귀 포탈 열기 + 호위무사 상승 시작
                self._dim_phase = "portal_return_opening"
                self._dim_timer = 1.0
                self._dim_portal_scale = 0.0
                self._dim_portal_particles = []
                self._dim_lightning_arcs = []
                self.is_active = True
                self.active_timer = 2.0  # return_opening(1.0) + closing(1.0)
                # 호위무사에게 포탈로 상승 시작 요청
                game_state['dimensional_summon_request'] = {'phase': 'ascend'}
                try:
                    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                    snd_path = os.path.join(project_root, "sounds", "bencylove.wav")
                    if os.path.exists(snd_path):
                        snd = pygame.mixer.Sound(snd_path)
                        snd.set_volume(0.7)
                        snd.play()
                except Exception:
                    pass
            elif self._dim_phase in ("portal_closing", "portal_return_opening"):
                # 이미 닫기/열기 진행 중 → 타이머가 알아서 처리하므로 무시
                self.is_active = True
                self.active_timer = max(0.1, self._dim_timer + 1.0)
            else:
                # 예외적 종료 (라운드 끝 등)
                if self._dim_summoned_hero_id:
                    game_state['dimensional_summon_request'] = {'phase': 'dismiss'}
                self._dim_phase = "idle"
                self._dimensional_mode = False
                self.is_active = False
            return

        game_state['charm_active'] = False
        self.charm_particles = []

        if self.charm_phase == "active":
            # 활동 중이었다면 → 복귀 페이즈
            self.charm_phase = "returning"
            self.phase_timer = 0.0
            self.return_progress = 0.0

            # 현재 호위무사 위치에서 원래 진영으로
            guard_pos = game_state.get('_charmed_guard_pos', None)
            if guard_pos:
                self.return_start_x = guard_pos.get('x', 380)
                self.return_start_y = guard_pos.get('y', BOTTOM_PADDLE_Y)
            else:
                self.return_start_x = 380
                self.return_start_y = TOP_PADDLE_Y if self.charm_source_is_top else BOTTOM_PADDLE_Y

            # 원래 진영 위치
            if self.charm_source_is_top:
                self.return_end_y = BOTTOM_PADDLE_Y  # 상단이 빌려왔으니 하단으로 복귀
            else:
                self.return_end_y = TOP_PADDLE_Y     # 하단이 빌려왔으니 상단으로 복귀
            self.return_end_x = self.return_start_x

            # 매혹 해제 사운드 재생
            try:
                project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                love_path = os.path.join(project_root, "sounds", "bencylove.wav")
                if os.path.exists(love_path):
                    love_snd = pygame.mixer.Sound(love_path)
                    love_snd.set_volume(0.8)
                    love_snd.play()
            except Exception:
                pass

            # GuardWarriorSystem에 '복귀 시작' 알림
            game_state['charm_phase_request'] = {
                'caster_is_top': self.charm_source_is_top,
                'phase': 'returning',
            }

            # duration을 강제로 약간 연장 (복귀 애니메이션 재생 시간)
            self.is_active = True
            self.active_timer = 1.0  # 복귀에 ~0.7초 필요
        else:
            # 발사/견인 중 종료(라운드 끝 등) → 즉시 정리
            game_state['charm_end_request'] = {
                'caster_is_top': self.charm_source_is_top,
            }
            self.charm_phase = "idle"
            self.charmed_guard = None
            self._charm_applied = False

    # ------------------------------------------------------------------
    #  draw  (시각 효과 렌더링)
    # ------------------------------------------------------------------
    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        if not self.is_active:
            return

        # ─── 차원의 문 모드 ───
        if self._dimensional_mode:
            self._draw_dimensional(screen, game_state)
            return

        # === Phase 1: 자력 에너지 탄 ===
        if self.charm_phase == "projectile":
            self._draw_projectile(screen)

        # === Phase 2: 견인 체인 ===
        elif self.charm_phase == "pulling":
            self._draw_pull_chain(screen, game_state)

        # === Phase 3: 활동 중 매혹 오라 ===
        elif self.charm_phase == "active":
            self._draw_active_aura(screen, game_state)

        # === Phase 4: 복귀 이펙트 ===
        elif self.charm_phase == "returning":
            self._draw_return_effect(screen, game_state)

    def _draw_projectile(self, screen):
        """Phase 1: 자력 에너지 발사체 렌더링"""
        t = min(1.0, self.proj_progress)
        cur_x = self.proj_x + (self.proj_target_x - self.proj_x) * t
        cur_y = self.proj_y + (self.proj_target_y - self.proj_y) * t

        # 트레일 파티클 렌더링
        for tr in self.proj_trail:
            ratio = tr['life'] / tr['max_life']
            alpha = int(180 * ratio)
            sz = max(1, int(tr['size'] * ratio))
            if tr['color_type'] == 'magenta':
                c = (220, 80, 180, alpha)
            elif tr['color_type'] == 'cyan':
                c = (80, 200, 240, alpha)
            else:
                c = (140, 60, 200, alpha)
            s = _psurf((sz * 2, sz * 2), pygame.SRCALPHA)
            pygame.draw.circle(s, c, (sz, sz), sz)
            screen.blit(s, (int(tr['x'] - sz), int(tr['y'] - sz)), special_flags=pygame.BLEND_ADD)

        # 외곽 글로우
        glow_r = 22
        glow_s = _psurf((glow_r * 2, glow_r * 2), pygame.SRCALPHA)
        pulse = (math.sin(self.charm_aura_timer * 8) + 1) * 0.5
        glow_alpha = int(60 + 40 * pulse)
        pygame.draw.circle(glow_s, (180, 60, 220, glow_alpha), (glow_r, glow_r), glow_r)
        screen.blit(glow_s, (int(cur_x - glow_r), int(cur_y - glow_r)), special_flags=pygame.BLEND_ADD)

        # 궤도 구슬
        for orb in self.proj_orbs:
            ox = cur_x + math.cos(orb['angle']) * orb['dist']
            oy = cur_y + math.sin(orb['angle']) * orb['dist']
            sz = max(1, int(orb['size']))
            orb_s = _psurf((sz * 2, sz * 2), pygame.SRCALPHA)
            pygame.draw.circle(orb_s, (200, 100, 255, 200), (sz, sz), sz)
            screen.blit(orb_s, (int(ox - sz), int(oy - sz)), special_flags=pygame.BLEND_ADD)

        # 코어 (밝은 핑크+화이트)
        core_r = 8
        pygame.draw.circle(screen, (255, 180, 240), (int(cur_x), int(cur_y)), core_r)
        pygame.draw.circle(screen, (255, 240, 255), (int(cur_x), int(cur_y)), 4)

    def _draw_pull_chain(self, screen, game_state):
        """Phase 2: 견인 체인 + 에너지 필드 렌더링"""
        pull_pos = game_state.get('charm_pull_position', None)
        if not pull_pos:
            return
        px, py = pull_pos['x'], pull_pos['y']
        progress = pull_pos['progress']

        # 시전자 위치
        caster_y = 50 if self.charm_source_is_top else 700

        # 에너지 체인 라인 (시전자 → 호위무사)
        chain_points = 12
        for i in range(chain_points):
            frac = i / (chain_points - 1)
            bx = px + (self.pull_end_x - px) * frac * 0.3
            by = caster_y + (py - caster_y) * (1 - frac)

            if i < len(self.pull_chain_particles):
                cp = self.pull_chain_particles[i]
                wave = math.sin(cp['phase']) * cp['offset'] * (1 - progress * 0.5)
                bx += wave
            alpha = int(120 + 80 * (1 - frac))
            sz = max(1, int(3 + 2 * math.sin(self.charm_aura_timer * 4 + i)))
            cs = _psurf((sz * 2, sz * 2), pygame.SRCALPHA)
            pygame.draw.circle(cs, (180, 80, 220, alpha), (sz, sz), sz)
            screen.blit(cs, (int(bx - sz), int(by - sz)), special_flags=pygame.BLEND_ADD)

        # 호위무사 주위 매혹 필드 (견인 중)
        field_r = int(25 + 10 * math.sin(self.charm_aura_timer * 5))
        field_s = _psurf((field_r * 2, field_r * 2), pygame.SRCALPHA)
        field_alpha = int(50 + 30 * (1 - progress))
        pygame.draw.circle(field_s, (200, 80, 240, field_alpha), (field_r, field_r), field_r)
        screen.blit(field_s, (int(px - field_r), int(py - field_r)), special_flags=pygame.BLEND_ADD)

        # 나선형 에너지 링
        ring_count = 3
        for r in range(ring_count):
            angle = self.charm_aura_timer * (3 + r) + r * (math.pi * 2 / ring_count)
            ring_r = 15 + r * 5
            rx = px + math.cos(angle) * ring_r
            ry = py + math.sin(angle) * ring_r * 0.6
            dot_s = _psurf((6, 6), pygame.SRCALPHA)
            pygame.draw.circle(dot_s, (255, 150, 220, 180), (3, 3), 3)
            screen.blit(dot_s, (int(rx - 3), int(ry - 3)), special_flags=pygame.BLEND_ADD)

    def _draw_active_aura(self, screen, game_state):
        """Phase 3: 활동 중 매혹 오라 + 파티클"""
        # 매혹 파티클 렌더링 (핑크+시안)
        for p in self.charm_particles:
            ratio = p['life'] / p['max_life']
            alpha = int(200 * ratio)
            sz = max(1, int(p['size'] * ratio))

            if p.get('is_heart'):
                # 하트 모양 (작은 점 두 개 + 아래 삼각형으로 근사)
                heart_s = _psurf((sz * 3, sz * 3), pygame.SRCALPHA)
                hc = (255, 100, 180, alpha)
                hs = max(1, sz)
                pygame.draw.circle(heart_s, hc, (hs, hs), hs)
                pygame.draw.circle(heart_s, hc, (hs * 2, hs), hs)
                pygame.draw.polygon(heart_s, hc, [(0, hs), (hs * 3, hs), (hs + hs // 2, hs * 3)])
                screen.blit(heart_s, (int(p['x'] - hs), int(p['y'] - hs)), special_flags=pygame.BLEND_ADD)
            else:
                if int(p['x'] * 7) % 2 == 0:
                    c = (200, 100, 180, alpha)
                else:
                    c = (100, 200, 240, alpha)
                ps = _psurf((sz * 2, sz * 2), pygame.SRCALPHA)
                pygame.draw.circle(ps, c, (sz, sz), sz)
                screen.blit(ps, (int(p['x'] - sz), int(p['y'] - sz)), special_flags=pygame.BLEND_ADD)

        # 매혹 오라 바 (화면 가장자리)
        pulse = (math.sin(self.charm_aura_timer * 3) + 1) * 0.5
        bar_alpha = int(25 + 20 * pulse)
        bar_h = 6
        bar_s = _psurf((760, bar_h), pygame.SRCALPHA)
        bar_s.fill((180, 80, 220, bar_alpha))
        if self.charm_source_is_top:
            screen.blit(bar_s, (0, 0))
        else:
            screen.blit(bar_s, (0, 750 - bar_h))

        # 매혹된 호위무사 주위 오라 링
        guard_pos = game_state.get('_charmed_guard_pos', None)
        if guard_pos:
            gx, gy = guard_pos['x'], guard_pos['y']
            ring_r = int(20 + 5 * math.sin(self.charm_aura_timer * 4))
            ring_s = _psurf((ring_r * 2, ring_r * 2), pygame.SRCALPHA)
            pygame.draw.circle(ring_s, (200, 80, 240, 40), (ring_r, ring_r), ring_r)
            pygame.draw.circle(ring_s, (200, 80, 240, 80), (ring_r, ring_r), ring_r, 2)
            screen.blit(ring_s, (int(gx - ring_r), int(gy - ring_r)), special_flags=pygame.BLEND_ADD)

    def _draw_return_effect(self, screen, game_state):
        """Phase 4: 복귀 이펙트"""
        ret_pos = game_state.get('charm_return_position', None)
        if not ret_pos:
            return
        rx, ry = ret_pos['x'], ret_pos['y']
        progress = ret_pos['progress']

        # 해방 파티클 (감소하는 에너지)
        dissipate_alpha = int(120 * (1 - progress))
        field_r = int(20 * (1 - progress * 0.5))
        if field_r > 0:
            fs = _psurf((field_r * 2, field_r * 2), pygame.SRCALPHA)
            pygame.draw.circle(fs, (140, 80, 200, dissipate_alpha), (field_r, field_r), field_r)
            screen.blit(fs, (int(rx - field_r), int(ry - field_r)), special_flags=pygame.BLEND_ADD)

        # 잔여 에너지 스파크
        spark_count = max(1, int(4 * (1 - progress)))
        for i in range(spark_count):
            angle = self.charm_aura_timer * 5 + i * (math.pi * 2 / spark_count)
            sd = 12 + 8 * (1 - progress)
            sx = rx + math.cos(angle) * sd
            sy = ry + math.sin(angle) * sd * 0.6
            ss = _psurf((4, 4), pygame.SRCALPHA)
            pygame.draw.circle(ss, (220, 120, 255, dissipate_alpha), (2, 2), 2)
            screen.blit(ss, (int(sx - 2), int(sy - 2)), special_flags=pygame.BLEND_ADD)

    # ------------------------------------------------------------------
    #  reset / reset_for_new_round
    # ------------------------------------------------------------------
    def reset(self):
        super().reset()
        self.charmed_guard = None
        self.charm_particles = []
        self._charm_applied = False
        self.charm_aura_timer = 0.0
        self.charm_phase = "idle"
        self.phase_timer = 0.0
        self.proj_trail = []
        self.proj_orbs = []
        self.pull_chain_particles = []
        self.charm_elapsed = 0.0
        # 차원의 문 리셋
        self._dimensional_mode = False
        self._dim_phase = "idle"
        self._dim_timer = 0.0
        self._dim_portal_particles = []
        self._dim_summoned_hero_id = None
        self._dim_portal_scale = 0.0
        self._dim_elapsed = 0.0
        self._dim_lightning_arcs = []

    def reset_for_new_round(self, game_state: dict):
        """라운드 전환 시 매혹/차원소환 모두 유지 (초기화하지 않음!)"""
        # 차원의 문 모드: 라운드 넘어가도 소환 유지
        pass

    # ------------------------------------------------------------------
    #  차원의 문 (스토리모드 전용) - apply / update / draw
    # ------------------------------------------------------------------
    def _apply_dimensional_gate(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        """차원의 문 소환 발동 (스토리모드 전용)"""
        self._dimensional_mode = True
        self._dim_phase = "portal_opening"
        self._dim_timer = 1.5     # 포탈 열리는 시간
        self._dim_elapsed = 0.0
        self._dim_portal_scale = 0.0
        self._dim_portal_angle = 0.0
        self._dim_portal_particles = []
        self._dim_lightning_arcs = []

        # 포탈 위치: 보스 진영 중앙 상단
        self._dim_portal_x = 380.0
        self._dim_portal_y = 80.0

        # 랜덤 영웅 선택 (밴시, 현재 호위무사 제외)
        self._dim_summoned_hero_id = self._pick_random_hero(game_state)

        # 총 지속시간: 포탈열림(1.5) + 도착닫힘(1.0) + 활동(30) + 복귀열림(1.0) + 최종닫힘(1.0)
        self.duration = 1.5 + 1.0 + self._dim_duration + 1.0 + 1.0
        self.active_timer = 1.5 + 1.0 + self._dim_duration  # _end_effect에서 portal_return_opening 시작
        self.cooldown = 40.0
        self.charm_aura_timer = 0.0

        # 포탈 사운드
        try:
            project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            snd_path = os.path.join(project_root, "sounds", "bencylove.wav")
            if os.path.exists(snd_path):
                snd = pygame.mixer.Sound(snd_path)
                snd.set_volume(0.8)
                snd.play()
        except Exception:
            pass

        return {
            'screen_effect': ScreenEffect.FLASH,
            'flash_color': (60, 40, 160),
        }

    def _pick_random_hero(self, game_state: dict) -> str:
        """소환할 랜덤 영웅 선택 (밴시 + 현재 호위무사 제외)"""
        from downtown.hero_skills import HERO_SKILL_CLASSES
        exclude = {'banshee'}
        bodyguard_id = game_state.get('_bodyguard_hero_id')
        if bodyguard_id:
            exclude.add(bodyguard_id)
        candidates = [hid for hid in HERO_SKILL_CLASSES if hid not in exclude]
        return random.choice(candidates) if candidates else 'knight'

    def _update_dimensional(self, dt, caster_paddle, target_paddle, ball, game_state):
        """차원의 문 phase 별 업데이트

        Phase 흐름:
        portal_opening(1.5s) → portal_arrival_closing(1.0s) → summoned_active(38s)
        → portal_return_opening(1.0s) → portal_closing(1.0s)
        """
        self.charm_aura_timer += dt
        self._dim_portal_angle += dt * 3.0  # 소용돌이 회전

        # === portal_opening: 포탈 열리는 중 (1.5초) ===
        if self._dim_phase == "portal_opening":
            self._dim_timer -= dt
            # 스케일 0→1 (ease-out)
            progress = 1.0 - max(0.0, self._dim_timer / 1.5)
            self._dim_portal_scale = 1.0 - (1.0 - progress) ** 2

            self._spawn_dim_swirl_particles(0.6)
            self._spawn_dim_lightning(0.3)
            self._update_dim_particles(dt)

            if self._dim_timer <= 0:
                # 포탈 완전 열림 → 소환 + 닫기 시작
                self._dim_phase = "portal_arrival_closing"
                self._dim_timer = 1.0
                self._dim_portal_scale = 1.0
                game_state['dimensional_summon_request'] = {
                    'phase': 'summon',
                    'hero_id': self._dim_summoned_hero_id,
                    'portal_x': self._dim_portal_x,
                    'portal_y': self._dim_portal_y,
                }
                print(f"[Charm/DimensionalGate] 소환 요청: {self._dim_summoned_hero_id}")

        # === portal_arrival_closing: 하수인 등장 후 포탈 서서히 닫힘 (1.0초) ===
        elif self._dim_phase == "portal_arrival_closing":
            self._dim_timer -= dt
            # 스케일 1→0 (ease-in)
            progress = max(0.0, self._dim_timer / 1.0)
            self._dim_portal_scale = progress ** 2  # ease-in: 처음 천천히, 끝에 빠르게

            # 닫히면서 에너지 흩어짐
            self._spawn_dim_swirl_particles(0.3 * progress)
            self._spawn_dim_lightning(0.2 * progress)
            self._update_dim_particles(dt)

            if self._dim_timer <= 0:
                # 포탈 닫힘 → 활동 모드
                self._dim_phase = "summoned_active"
                self._dim_elapsed = 0.0
                self._dim_portal_scale = 0.0
                self._dim_portal_particles = []
                self._dim_lightning_arcs = []
                print("[Charm/DimensionalGate] 포탈 닫힘, 활동 시작")

        # === summoned_active: 소환된 호위무사 활동 중 ===
        elif self._dim_phase == "summoned_active":
            self._dim_elapsed += dt
            # 포탈 닫혀있음 - 아주 미세한 잔향만
            self._dim_portal_scale = 0.0
            self._update_dim_particles(dt)

        # === portal_return_opening: 복귀 포탈 열리는 중 (1.0초) ===
        elif self._dim_phase == "portal_return_opening":
            self._dim_timer -= dt
            # 스케일 0→1 (ease-out)
            progress = 1.0 - max(0.0, self._dim_timer / 1.0)
            self._dim_portal_scale = 1.0 - (1.0 - progress) ** 2

            self._spawn_dim_swirl_particles(0.6)
            self._spawn_dim_lightning(0.4)
            self._update_dim_particles(dt)

            if self._dim_timer <= 0:
                # 포탈 완전 열림 → 호위무사 해제 + 닫기
                self._dim_phase = "portal_closing"
                self._dim_timer = 1.0
                self._dim_portal_scale = 1.0
                game_state['dimensional_summon_request'] = {'phase': 'dismiss'}
                print("[Charm/DimensionalGate] 복귀 포탈 열림, 호위무사 복귀")

        # === portal_closing: 포탈 닫히는 중 (1.0초) ===
        elif self._dim_phase == "portal_closing":
            self._dim_timer -= dt
            # 스케일 1→0 (ease-in)
            progress = max(0.0, self._dim_timer / 1.0)
            self._dim_portal_scale = progress ** 2

            # 닫히면서 파티클 폭발
            self._spawn_dim_swirl_particles(0.5 * progress)
            self._spawn_dim_lightning(0.5 * progress)
            self._update_dim_particles(dt)

            if self._dim_timer <= 0:
                self._dim_phase = "idle"
                self._dimensional_mode = False
                self.is_active = False
                print("[Charm/DimensionalGate] 포탈 닫힘 완료")

    def _spawn_dim_swirl_particles(self, chance):
        """차원의 문 소용돌이 파티클 생성"""
        if random.random() < chance:
            angle = random.uniform(0, math.pi * 2)
            dist = random.uniform(25, 55)
            self._dim_portal_particles.append({
                'x': self._dim_portal_x + math.cos(angle) * dist,
                'y': self._dim_portal_y + math.sin(angle) * dist * 0.7,
                'angle': angle,
                'dist': dist,
                'speed': random.uniform(2.0, 4.0),
                'life': random.uniform(0.4, 0.8),
                'max_life': 0.8,
                'size': random.uniform(2, 5),
            })

    def _spawn_dim_lightning(self, chance):
        """차원의 문 전기 아크 생성"""
        if random.random() < chance and self._dim_portal_scale > 0.15:
            arc_angle = random.uniform(0, math.pi * 2)
            self._dim_lightning_arcs.append({
                'angle': arc_angle,
                'length': random.uniform(8, 22),
                'life': random.uniform(0.05, 0.15),
                'max_life': 0.15,
                'segments': random.randint(2, 4),
            })

    def _update_dim_particles(self, dt):
        """차원의 문 파티클 업데이트"""
        # 소용돌이 파티클: 중심으로 수렴
        alive = []
        for p in self._dim_portal_particles:
            p['life'] -= dt
            if p['life'] > 0:
                # 중심으로 나선 수렴
                p['angle'] += dt * p['speed']
                p['dist'] = max(0, p['dist'] - dt * 40)
                p['x'] = self._dim_portal_x + math.cos(p['angle']) * p['dist']
                p['y'] = self._dim_portal_y + math.sin(p['angle']) * p['dist'] * 0.7
                alive.append(p)
        self._dim_portal_particles = alive

        # 전기 아크 업데이트
        alive_arcs = []
        for arc in self._dim_lightning_arcs:
            arc['life'] -= dt
            if arc['life'] > 0:
                alive_arcs.append(arc)
        self._dim_lightning_arcs = alive_arcs

    def _draw_dimensional(self, screen, game_state):
        """차원의 문 포탈 렌더링 (디아블로 스타일)"""
        if self._dim_phase == "idle":
            return

        cx = int(self._dim_portal_x)
        cy = int(self._dim_portal_y)
        scale = self._dim_portal_scale
        if scale < 0.01:
            return

        pw = int(45 * scale)    # 포탈 너비 (가로)
        ph = int(65 * scale)    # 포탈 높이 (세로 타원)
        if pw < 2 or ph < 2:
            return

        # 1) 바닥 글로우 (보라빛)
        glow_w = pw * 3
        glow_h = ph * 3
        if glow_w > 0 and glow_h > 0:
            glow_surf = _psurf((glow_w, glow_h), pygame.SRCALPHA)
            pulse = (math.sin(self.charm_aura_timer * 4) + 1) * 0.5
            glow_alpha = int(30 + 25 * pulse)
            pygame.draw.ellipse(glow_surf, (80, 40, 180, glow_alpha), (0, 0, glow_w, glow_h))
            screen.blit(glow_surf, (cx - glow_w // 2, cy - glow_h // 2),
                        special_flags=pygame.BLEND_ADD)

        # 2) 검은 코어 (공허)
        core_surf = _psurf((pw * 2, ph * 2), pygame.SRCALPHA)
        pygame.draw.ellipse(core_surf, (8, 2, 18, 230), (0, 0, pw * 2, ph * 2))
        screen.blit(core_surf, (cx - pw, cy - ph))

        # 3) 에너지 링 (다중 레이어, 파란→보라)
        for i in range(4):
            ring_w = pw + i * 3 + 2
            ring_h = ph + i * 3 + 2
            pulse_offset = math.sin(self.charm_aura_timer * (5 + i) + i * 0.8) * 0.3 + 0.7
            alpha = int((160 - i * 30) * pulse_offset)
            if alpha < 10:
                continue
            ring_surf = _psurf((ring_w * 2 + 4, ring_h * 2 + 4), pygame.SRCALPHA)
            # 파란→보라 그라데이션
            r = min(255, 70 + i * 40)
            g = min(255, 40 + i * 15)
            b = min(255, 200 + i * 15)
            pygame.draw.ellipse(ring_surf, (r, g, b, alpha),
                                (0, 0, ring_w * 2 + 4, ring_h * 2 + 4), max(2, 3 - i))
            screen.blit(ring_surf, (cx - ring_w - 2, cy - ring_h - 2),
                        special_flags=pygame.BLEND_ADD)

        # 4) 소용돌이 파티클 (타원 궤도)
        num_swirl = 16
        for j in range(num_swirl):
            angle = self._dim_portal_angle + j * (math.pi * 2 / num_swirl)
            # 시간에 따라 반경 변화
            r_mult = 0.55 + 0.15 * math.sin(self.charm_aura_timer * 3 + j * 0.5)
            px = cx + int(math.cos(angle) * pw * r_mult)
            py = cy + int(math.sin(angle) * ph * r_mult)
            sz = max(1, int(2 + 1.5 * math.sin(self.charm_aura_timer * 6 + j)))
            # 파란/보라/시안 교대
            if j % 3 == 0:
                color = (100, 140, 255, 200)
            elif j % 3 == 1:
                color = (160, 80, 240, 180)
            else:
                color = (80, 200, 255, 160)
            dot_s = _psurf((sz * 2, sz * 2), pygame.SRCALPHA)
            pygame.draw.circle(dot_s, color, (sz, sz), sz)
            screen.blit(dot_s, (px - sz, py - sz), special_flags=pygame.BLEND_ADD)

        # 5) 내부 소용돌이 (작은 원호)
        inner_count = 8
        for k in range(inner_count):
            angle = -self._dim_portal_angle * 1.5 + k * (math.pi * 2 / inner_count)
            r_mult = 0.3 + 0.1 * math.sin(self.charm_aura_timer * 5 + k)
            ix = cx + int(math.cos(angle) * pw * r_mult)
            iy = cy + int(math.sin(angle) * ph * r_mult)
            alpha = int(120 + 60 * math.sin(self.charm_aura_timer * 4 + k * 0.7))
            color = (60, 80, 200, alpha)
            dot_s = _psurf((4, 4), pygame.SRCALPHA)
            pygame.draw.circle(dot_s, color, (2, 2), 2)
            screen.blit(dot_s, (ix - 2, iy - 2), special_flags=pygame.BLEND_ADD)

        # 6) 전기 아크 (번개선)
        for arc in self._dim_lightning_arcs:
            ratio = arc['life'] / arc['max_life']
            arc_alpha = int(220 * ratio)
            start_angle = arc['angle']
            arc_len = arc['length'] * scale
            # 시작점: 포탈 가장자리
            sx = cx + int(math.cos(start_angle) * pw)
            sy = cy + int(math.sin(start_angle) * ph)
            # 번개 세그먼트
            points = [(sx, sy)]
            for seg in range(arc['segments']):
                frac = (seg + 1) / arc['segments']
                nx = sx + int(math.cos(start_angle) * arc_len * frac)
                ny = sy + int(math.sin(start_angle) * arc_len * frac)
                nx += random.randint(-4, 4)
                ny += random.randint(-4, 4)
                points.append((nx, ny))
            if len(points) >= 2:
                arc_color = (150, 180, 255, arc_alpha)
                arc_s = _psurf((int(pw * 3), int(ph * 3)), pygame.SRCALPHA)
                offset_x = cx - int(pw * 1.5)
                offset_y = cy - int(ph * 1.5)
                adj_points = [(p[0] - offset_x, p[1] - offset_y) for p in points]
                try:
                    pygame.draw.lines(arc_s, arc_color, False, adj_points, 1)
                except Exception:
                    pass
                screen.blit(arc_s, (offset_x, offset_y), special_flags=pygame.BLEND_ADD)

        # 7) 흩어지는 파티클
        for p in self._dim_portal_particles:
            ratio = p['life'] / p['max_life']
            alpha = int(180 * ratio)
            sz = max(1, int(p['size'] * ratio))
            c = (100, 120, 255, alpha) if int(p['angle'] * 10) % 2 == 0 else (160, 80, 220, alpha)
            ps = _psurf((sz * 2, sz * 2), pygame.SRCALPHA)
            pygame.draw.circle(ps, c, (sz, sz), sz)
            screen.blit(ps, (int(p['x'] - sz), int(p['y'] - sz)), special_flags=pygame.BLEND_ADD)

        # 8) summoned_active 상태: 미니 포탈 잔상 텍스트 효과 없음 (포탈이 작아진 상태)


class DeadPossession(HeroSkill):
    """수수께끼 묘기 - 투기장 영웅의 모든 스킬 중 랜덤 1개를 즉시 발동

    - 쿨타임 완료 시 자동 발동
    - 현재 존재하는 모든 영웅 스킬 풀에서 무작위 1개 선택
    - 선택된 스킬의 _apply_effect를 그대로 실행
    - 시각적으로 묘기 연출 (랜덤박스 + 선택된 스킬 아이콘 표시)
    """

    def __init__(self):
        super().__init__(
            skill_id="riddle_trick",
            name="Riddle Trick",
            korean_name="수수께끼 묘기",
            description="예측 불가능한 묘기로 어떤 스킬이든 꺼내 보인다",
            trigger=SkillTrigger.ON_COOLDOWN,
            cooldown=20.0,
            duration=0,  # 즉발 (빙의된 스킬의 duration 사용)
            hero_id="joker"
        )
        self.possessed_skill = None      # 빙의된 스킬 인스턴스
        self.possession_flash = 0.0      # 빙의 플래시 타이머
        self.possession_name = ""        # 빙의된 스킬 이름 (UI용)
        self.ghost_particles = []        # 유령 파티클

    def can_use(self) -> bool:
        """쿨타임 완료 + 빙의 스킬이 없을 때"""
        return self.current_cooldown <= 0 and self.possessed_skill is None

    def _possessed_has_ongoing_effects(self) -> bool:
        """빙의된 스킬이 is_active=False여도 지속되는 효과가 있는지 확인"""
        if not self.possessed_skill:
            return False
        # OilSpill: 발사체 또는 웅덩이가 남아있으면 지속 중
        if hasattr(self.possessed_skill, 'oil_projectiles') and self.possessed_skill.oil_projectiles:
            return True
        if hasattr(self.possessed_skill, 'oil_puddles') and self.possessed_skill.oil_puddles:
            return True
        # BoneBarrier: 장벽이 남아있으면 지속 중 (라운드 넘겨도 유지)
        if hasattr(self.possessed_skill, 'barriers') and self.possessed_skill.barriers:
            return True
        return False

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        """랜덤 스킬 선택 및 즉시 발동"""
        # 자신의 스킬(balloon_wall, riddle_trick)은 제외하고 모든 영웅 스킬 풀에서 선택
        all_skill_classes = []
        exclude_ids = {"balloon_wall", "riddle_trick"}

        for hero_id, skill_classes in HERO_SKILL_CLASSES.items():
            if hero_id in ("joker",):
                continue  # 조커 자신 제외
            for cls in skill_classes:
                # 인스턴스를 만들어서 skill_id 확인
                temp = cls()
                if temp.skill_id not in exclude_ids:
                    all_skill_classes.append(cls)

        if not all_skill_classes:
            return {}

        # 랜덤 선택
        chosen_cls = random.choice(all_skill_classes)
        self.possessed_skill = chosen_cls()
        self.possessed_skill.caster_is_top = getattr(self, 'caster_is_top', True)
        # 빙의 스킬은 조건 무시하고 강제 발동 (예: 야생의 포효의 _ball_in_range)
        if hasattr(self.possessed_skill, '_ball_in_range'):
            self.possessed_skill._ball_in_range = True
        # 빙의 스킬의 use() 오버라이드 조건 체크 우회 플래그
        # (예: SolarBolt의 _check_ball_conditions 공 방향 체크 무시)
        self.possessed_skill._possessed_force = True
        self.possession_name = self.possessed_skill.korean_name
        self.possession_flash = 1.5  # 1.5초 플래시 표시

        # 유령 파티클 생성
        self.ghost_particles = []
        caster = caster_paddle
        cx = caster.x + caster.width // 2 if hasattr(caster, 'width') else caster.x
        cy = 50 if getattr(self, 'caster_is_top', True) else 700
        for _ in range(20):
            self.ghost_particles.append({
                'x': cx + random.uniform(-60, 60),
                'y': cy + random.uniform(-40, 40),
                'vx': random.uniform(-80, 80),
                'vy': random.uniform(-100, -30) if getattr(self, 'caster_is_top', True) else random.uniform(30, 100),
                'life': random.uniform(0.5, 1.2),
                'max_life': 1.2,
                'size': random.uniform(3, 8),
            })

        # 빙의된 스킬 발동
        result = self.possessed_skill.use(caster_paddle, target_paddle, ball, game_state)

        # 빙의 스킬이 지속형이면 추적
        if self.possessed_skill.is_active and self.possessed_skill.duration > 0:
            self.is_active = True
            self.active_timer = self.possessed_skill.duration + 0.5  # 여유 시간
        elif self._possessed_has_ongoing_effects():
            # OilSpill 등 is_active=False지만 발사체/웅덩이가 지속되는 스킬
            self.is_active = True
            self.active_timer = 8.0  # 발사체 비행 + 웅덩이 지속 + 여유
        else:
            # 즉발 스킬이면 짧은 표시 후 정리
            self.is_active = True
            self.active_timer = 1.5  # 플래시 표시 시간

        # 결과에 빙의 정보 추가
        if result is None:
            result = {}
        result['possession_skill_name'] = self.possession_name
        result['screen_effect'] = ScreenEffect.FLASH
        result['flash_color'] = (60, 180, 220)

        return result

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        """빙의 스킬 효과 업데이트"""
        # 빙의된 스킬 업데이트 (OilSpill 등 is_active=False여도 update 필요한 스킬 지원)
        if self.possessed_skill:
            self.possessed_skill.update(dt, caster_paddle, target_paddle, ball, game_state)
            # 빙의 스킬의 모든 효과가 끝났으면 우리도 종료
            has_ongoing = self.possessed_skill.is_active or self._possessed_has_ongoing_effects()
            if not has_ongoing:
                self.active_timer = min(self.active_timer, 0.5)

        # 플래시 타이머
        if self.possession_flash > 0:
            self.possession_flash -= dt

        # 유령 파티클 업데이트
        alive = []
        for p in self.ghost_particles:
            p['x'] += p['vx'] * dt
            p['y'] += p['vy'] * dt
            p['life'] -= dt
            if p['life'] > 0:
                alive.append(p)
        self.ghost_particles = alive

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        """빙의 종료"""
        if self.possessed_skill:
            # is_active 스킬 또는 지속 효과(OilSpill 웅덩이 등) 정리
            if self.possessed_skill.is_active or self._possessed_has_ongoing_effects():
                try:
                    self.possessed_skill._end_effect(caster_paddle, target_paddle, ball, game_state)
                except Exception:
                    pass
                self.possessed_skill.is_active = False
                # OilSpill 웅덩이/발사체 정리
                if hasattr(self.possessed_skill, 'oil_projectiles'):
                    self.possessed_skill.oil_projectiles = []
                if hasattr(self.possessed_skill, 'oil_puddles'):
                    self.possessed_skill.oil_puddles = []
        self.possessed_skill = None
        self.ghost_particles = []
        self.possession_name = ""

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        """빙의 시각 효과"""
        # 빙의된 스킬의 draw 호출 (OilSpill 등 is_active=False여도 그리기 필요)
        if self.possessed_skill:
            self.possessed_skill.draw(screen, caster_paddle, target_paddle, ball, game_state)

        # 유령 파티클
        for p in self.ghost_particles:
            alpha = int(180 * (p['life'] / p['max_life']))
            size = max(1, int(p['size'] * (p['life'] / p['max_life'])))
            particle_surf = _psurf((size * 2, size * 2), pygame.SRCALPHA)
            pygame.draw.circle(particle_surf, (80, 200, 255, alpha), (size, size), size)
            screen.blit(particle_surf, (int(p['x'] - size), int(p['y'] - size)),
                       special_flags=pygame.BLEND_ADD)

        # 빙의 스킬명 플래시 표시
        if self.possession_flash > 0 and self.possession_name:
            flash_alpha = int(min(255, self.possession_flash * 200))
            # 화면 중앙에 스킬명 표시
            try:
                font = pygame.font.SysFont("malgungothic", 20, bold=True)
                text = f"수수께끼 묘기: {self.possession_name}"
                text_surf = font.render(text, True, (255, 220, 100))
                text_alpha_surf = _psurf(text_surf.get_size(), pygame.SRCALPHA)
                text_alpha_surf.blit(text_surf, (0, 0))
                text_alpha_surf.set_alpha(flash_alpha)
                text_x = 380 - text_surf.get_width() // 2
                text_y = 375 - text_surf.get_height() // 2
                screen.blit(text_alpha_surf, (text_x, text_y))
            except Exception:
                pass

    def reset(self):
        """전체 리셋"""
        super().reset()
        if self.possessed_skill:
            self.possessed_skill = None
        self.ghost_particles = []
        self.possession_flash = 0.0
        self.possession_name = ""

    def reset_for_new_round(self, game_state: dict):
        """라운드 전환 시 빙의 스킬도 정리 (뼈 장막 등 지속 효과는 유지)"""
        if self.possessed_skill:
            if self.possessed_skill.is_active:
                self.possessed_skill.reset_for_new_round(game_state)
            # 빙의 스킬이 라운드 넘김 후에도 효과가 지속되면 유지 (예: 뼈 장막)
            if self.possessed_skill.is_active or self._possessed_has_ongoing_effects():
                self.is_active = True
                self.active_timer = self.possessed_skill.active_timer
                self.ghost_particles = []
                self.possession_flash = 0.0
                return
        self.possessed_skill = None
        self.is_active = False
        self.active_timer = 0.0
        self.ghost_particles = []
        self.possession_flash = 0.0


# ============================================================================
# 네크로 (Necro) - 강령술사 스킬
# ============================================================================

class GhostSummon(HeroSkill):
    """유령소환 - 맵 중앙에 유령 패들 2개를 소환하여 공을 상대에게 쳐낸다"""

    GHOST_WIDTH = 80
    GHOST_HEIGHT = 40
    EMERGE_DURATION = 0.8   # 등장 애니메이션 - 캐스터→목표 비행 (초)
    DEATH_DURATION = 0.6    # 소멸 애니메이션 (초)

    # 유령 소환 Y 위치 (맵 중앙 부근)
    GHOST_Y_POSITIONS = [325, 425]

    # 공 먹기 관련 상수
    EAT_DURATION = 1.5          # 공을 먹고 있는 시간 (초)
    EAT_GROW_INTERVAL = 0.1     # 성장 간격 (초)
    EAT_GROW_RATE = 0.03        # 성장률 (3%)
    TELEPORT_DISAPPEAR_DUR = 0.3  # 순간이동 사라지는 시간
    TELEPORT_APPEAR_DUR = 0.4     # 순간이동 나타나는 시간
    CONSECUTIVE_CATCH_WINDOW = 0.5  # 연속 포획 판정 시간 (초)

    def __init__(self):
        super().__init__(
            skill_id="ghost_summon",
            name="Ghost Summon",
            korean_name="유령소환",
            description="저승의 유령 패들을 소환하여 공을 상대에게 쳐낸다",
            trigger=SkillTrigger.ON_COOLDOWN,
            cooldown=22.0,
            duration=5.0,
            hero_id="necro"
        )
        self.ghosts = []
        self.dying_ghosts = []
        self.caster_is_top = False
        self.caster_facing = "down"
        self._ghost_particles = []  # 유령 파티클
        self._eating_ball = False   # 유령이 공을 먹고 있는 중인지
        self._eating_ghost_id = -1  # 공을 먹고 있는 유령 ID
        self._saved_ball_vx = 0.0   # 먹기 전 공 속도 보존
        self._saved_ball_vy = 0.0
        self._teleport_effects = []  # 순간이동 이펙트 파티클
        self._time_since_ghost_release = 999.0  # 마지막 유령 공 발사 이후 경과 시간
        self._ghost_ambient_sound = None  # 유령 앰비언트 사운드 채널

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        self.caster_is_top = caster_paddle.is_top
        self.caster_facing = "down" if caster_paddle.is_top else "up"

        # 캐스터 위치 저장 (유령이 몸에서 뿜어져 나오는 연출용)
        self.caster_spawn_x = caster_paddle.x + getattr(caster_paddle, 'width', 80) // 2
        self.caster_spawn_y = caster_paddle.y

        self.ghosts = []
        self.dying_ghosts = []
        self._ghost_particles = []
        self._eating_ball = False
        self._eating_ghost_id = -1
        self._teleport_effects = []
        self._time_since_ghost_release = 999.0

        # 유령 2개를 캐스터 위치에서 출발 → 맵 중앙으로 이동
        for i, ghost_y in enumerate(self.GHOST_Y_POSITIONS):
            target_x = random.randint(100, 660)
            direction = random.choice([-1, 1])

            # 초기 위치: 캐스터 몸에서 시작
            ghost_rect = pygame.Rect(0, 0, self.GHOST_WIDTH, self.GHOST_HEIGHT)
            ghost_rect.center = (int(self.caster_spawn_x), int(self.caster_spawn_y))

            ghost = {
                'rect': ghost_rect,
                'target_x': target_x,       # 목표 X
                'target_y': ghost_y,         # 목표 Y
                'start_x': float(self.caster_spawn_x),  # 출발 X (캐스터)
                'start_y': float(self.caster_spawn_y),   # 출발 Y (캐스터)
                'vx': random.uniform(6.0, 10.0) * direction,
                'spawn_time': 0.0,
                'active': True,
                'id': i,
                'hit_cooldown': 0.0,  # 연속 충돌 방지
                'knockback_vx': 0.0,  # 넉백 X 속도
                'knockback_vy': 0.0,  # 넉백 Y 속도
                'headbutt_timer': 0.0,  # 박치기 애니메이션 타이머
                # 공 먹기 상태
                'eating': False,            # 공을 먹고 있는 중
                'eat_timer': 0.0,           # 먹기 타이머
                'eat_scale': 1.0,           # 먹기 스케일 (점점 커짐)
                'eat_grow_acc': 0.0,        # 성장 누적 시간
                'eat_bulge_phase': 0.0,     # 울퉁불퉁 애니메이션 위상
                'swallow_sound_played': False,  # 삼키기 사운드 재생 여부
                # 순간이동 상태
                'teleporting': False,       # 순간이동 중
                'teleport_phase': '',       # 'disappear' | 'appear' | 'release'
                'teleport_timer': 0.0,      # 순간이동 타이머
                'teleport_target_x': 0.0,   # 순간이동 목표 X
                'pre_teleport_x': 0.0,      # 순간이동 전 X (이펙트용)
                'pre_teleport_y': 0.0,      # 순간이동 전 Y (이펙트용)
            }
            self.ghosts.append(ghost)

        game_state['has_ghost_summon'] = True

        # 유령 소환 사운드 (1회 재생)
        try:
            project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            ambient_path = os.path.join(project_root, "sounds", "bencyghost.wav")
            if os.path.exists(ambient_path):
                self._ghost_ambient_sound = pygame.mixer.Sound(ambient_path)
                self._ghost_ambient_sound.set_volume(0.45)
                self._ghost_ambient_sound.play()
        except Exception:
            pass

        return {
            'screen_effect': ScreenEffect.FLASH,
            'flash_color': (60, 120, 100),
            'flash_duration': 0.15,
        }

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        self._time_since_ghost_release += dt
        new_ghosts = []

        for ghost in self.ghosts:
            if not ghost['active']:
                continue

            ghost['spawn_time'] += dt

            # 연속 충돌 방지 쿨다운 감소
            if ghost['hit_cooldown'] > 0:
                ghost['hit_cooldown'] -= dt

            rect = ghost['rect']

            # ============================================================
            # 순간이동 처리 (공 먹기 완료 후)
            # ============================================================
            if ghost['teleporting']:
                ghost['teleport_timer'] += dt
                phase = ghost['teleport_phase']

                if phase == 'disappear':
                    # 사라지는 중 - 파티클 생성
                    t = ghost['teleport_timer'] / self.TELEPORT_DISAPPEAR_DUR
                    if random.random() < 0.8:
                        angle = random.uniform(0, math.pi * 2)
                        dist = random.uniform(5, 35) * (1.0 - t)
                        self._teleport_effects.append({
                            'x': ghost['pre_teleport_x'] + math.cos(angle) * dist,
                            'y': ghost['pre_teleport_y'] + math.sin(angle) * dist,
                            'vx': math.cos(angle) * -2.0,  # 안쪽으로 수렴
                            'vy': math.sin(angle) * -2.0 - 1.0,
                            'alpha': random.randint(150, 230),
                            'size': random.randint(3, 7),
                            'life': random.uniform(0.3, 0.6),
                            'age': 0.0,
                            'color': random.choice([
                                (80, 200, 180), (60, 160, 140), (120, 240, 210), (40, 120, 100)
                            ]),
                            'type': 'disappear',
                        })
                    if ghost['teleport_timer'] >= self.TELEPORT_DISAPPEAR_DUR:
                        # 사라짐 완료 → 새 위치로 이동
                        ghost['teleport_phase'] = 'appear'
                        ghost['teleport_timer'] = 0.0
                        rect.centerx = int(ghost['teleport_target_x'])
                        # Y는 원래 target_y 유지

                elif phase == 'appear':
                    # 나타나는 중 - 파티클 생성
                    t = ghost['teleport_timer'] / self.TELEPORT_APPEAR_DUR
                    if random.random() < 0.8:
                        angle = random.uniform(0, math.pi * 2)
                        dist = random.uniform(0, 40) * t
                        self._teleport_effects.append({
                            'x': float(rect.centerx) + math.cos(angle) * dist,
                            'y': float(rect.centery) + math.sin(angle) * dist,
                            'vx': math.cos(angle) * 3.0,  # 바깥으로 퍼짐
                            'vy': math.sin(angle) * 3.0 - 1.5,
                            'alpha': random.randint(150, 240),
                            'size': random.randint(3, 8),
                            'life': random.uniform(0.4, 0.8),
                            'age': 0.0,
                            'color': random.choice([
                                (100, 220, 200), (80, 200, 180), (140, 255, 230), (60, 180, 160)
                            ]),
                            'type': 'appear',
                        })
                    if ghost['teleport_timer'] >= self.TELEPORT_APPEAR_DUR:
                        # 나타남 완료 → 공 발사
                        ghost['teleport_phase'] = 'release'
                        ghost['teleport_timer'] = 0.0

                elif phase == 'release':
                    # 공 발사! - game_state를 통해 실제 공 위치/속도 변경 요청
                    if ball is not None:
                        release_angle = random.uniform(-0.8, 0.8)
                        base_speed = max(6.0, math.hypot(self._saved_ball_vx, self._saved_ball_vy))
                        release_dir = 1 if self.caster_is_top else -1  # 상대 방향
                        new_vx = base_speed * math.sin(release_angle)
                        new_vy = base_speed * math.cos(release_angle) * release_dir
                        # 최소 Y 속도 보장
                        if abs(new_vy) < 4.0:
                            new_vy = 4.0 * release_dir
                        # BallWrapper에 속도 직접 설정 (pingfighter에서 ball_vel로 동기화됨)
                        ball.vx = new_vx
                        ball.vy = new_vy
                        # 위치 변경은 game_state를 통해 전달 (BallWrapper 위치 변경은 동기화 안됨)
                        game_state['ghost_summon_ball_release'] = {
                            'ball_x': float(rect.centerx),
                            'ball_y': float(rect.centery),
                        }

                    # 공 숨김 해제
                    game_state['ghost_summon_ball_hidden'] = False

                    # 순간이동 종료, 정상 상태로 복귀
                    ghost['teleporting'] = False
                    ghost['teleport_phase'] = ''
                    ghost['eating'] = False
                    ghost['eat_scale'] = 1.0
                    ghost['eat_timer'] = 0.0
                    ghost['hit_cooldown'] = 0.5  # 발사 후 잠깐 쿨다운
                    self._eating_ball = False
                    self._time_since_ghost_release = 0.0  # 연속 포획 판정용
                    self._eating_ghost_id = -1

                    # 발사 사운드 (ghostwalk.wav 제거 - 무겐 귀신발걸음과 혼동됨)

                new_ghosts.append(ghost)
                continue

            # ============================================================
            # 공 먹기 처리
            # ============================================================
            if ghost['eating']:
                ghost['eat_timer'] += dt
                ghost['eat_bulge_phase'] += dt * 12.0  # 울퉁불퉁 애니메이션 속도

                # 0.1초마다 3%씩 성장
                ghost['eat_grow_acc'] += dt
                while ghost['eat_grow_acc'] >= self.EAT_GROW_INTERVAL:
                    ghost['eat_grow_acc'] -= self.EAT_GROW_INTERVAL
                    ghost['eat_scale'] += self.EAT_GROW_RATE

                # 먹기 중 이동 정지 (약간의 떨림만)
                ghost['vx'] *= 0.85

                # 삼키기 사운드 (먹기 0.7초 시점)
                if ghost['eat_timer'] >= 0.7 and not ghost.get('swallow_sound_played', False):
                    ghost['swallow_sound_played'] = True
                    try:
                        project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                        swallow_path = os.path.join(project_root, "sounds", "kuromiswallow.wav")
                        if os.path.exists(swallow_path):
                            sw = pygame.mixer.Sound(swallow_path)
                            sw.set_volume(0.5)
                            sw.play()
                    except Exception:
                        pass

                # 먹기 중 파티클 (소화 이펙트)
                if random.random() < 0.4:
                    self._ghost_particles.append({
                        'x': rect.centerx + random.randint(-20, 20),
                        'y': rect.centery + random.randint(-15, 15),
                        'vy': random.uniform(-2.0, -0.5),
                        'alpha': random.randint(140, 220),
                        'size': random.randint(2, 5),
                        'life': random.uniform(0.3, 0.8),
                        'age': 0.0,
                    })

                # 1.5초 후 순간이동 시작
                if ghost['eat_timer'] >= self.EAT_DURATION:
                    ghost['teleporting'] = True
                    ghost['teleport_phase'] = 'disappear'
                    ghost['teleport_timer'] = 0.0
                    ghost['pre_teleport_x'] = float(rect.centerx)
                    ghost['pre_teleport_y'] = float(rect.centery)
                    # 랜덤 X 위치 (현재 위치에서 최소 100px 이상 떨어진 곳)
                    min_x = self.GAME_LEFT + 60
                    max_x = self.GAME_RIGHT - 60
                    attempts = 0
                    while attempts < 20:
                        new_x = random.randint(int(min_x), int(max_x))
                        if abs(new_x - rect.centerx) >= 100:
                            break
                        attempts += 1
                    ghost['teleport_target_x'] = float(new_x)

                    # 사라지는 사운드 (ghostwalk.wav 제거 - 무겐 귀신발걸음과 혼동됨)

                new_ghosts.append(ghost)
                continue

            # ============================================================
            # 일반 이동 & 충돌 (등장 이후)
            # ============================================================

            # 등장 애니메이션: 캐스터 몸에서 목표 위치로 날아감
            if ghost['spawn_time'] < self.EMERGE_DURATION:
                t = ghost['spawn_time'] / self.EMERGE_DURATION
                # ease-out 곡선 (처음 빠르게, 끝에 감속)
                ease_t = 1.0 - (1.0 - t) ** 2.5
                lerp_x = ghost['start_x'] + (ghost['target_x'] - ghost['start_x']) * ease_t
                lerp_y = ghost['start_y'] + (ghost['target_y'] - ghost['start_y']) * ease_t
                rect.center = (int(lerp_x), int(lerp_y))

                # 소환 궤적 파티클 (몸에서 뿜어져 나오는 느낌)
                if random.random() < 0.6:
                    trail_t = random.uniform(0, t)
                    px = ghost['start_x'] + (ghost['target_x'] - ghost['start_x']) * trail_t
                    py = ghost['start_y'] + (ghost['target_y'] - ghost['start_y']) * trail_t
                    self._ghost_particles.append({
                        'x': px + random.randint(-12, 12),
                        'y': py + random.randint(-8, 8),
                        'vy': random.uniform(-1.0, -2.5),
                        'alpha': random.randint(120, 200),
                        'size': random.randint(2, 5),
                        'life': random.uniform(0.3, 0.7),
                        'age': 0.0,
                    })
            else:
                # 공 추적 이동 (공이 있고 숨겨지지 않았으면 공의 X 방향으로 이동)
                _ball_hidden = game_state.get('ghost_summon_ball_hidden', False)
                if ball is not None and not _ball_hidden:
                    _bw = getattr(ball, 'width', 0)
                    ball_cx = ball.x + _bw / 2 if _bw > 1 else ball.x
                    ghost_cx = float(rect.centerx)
                    dx = ball_cx - ghost_cx

                    # 공 방향으로 가속 (부드럽게)
                    if abs(dx) > 5:
                        accel = 0.4 if dx > 0 else -0.4
                        ghost['vx'] += accel
                    else:
                        # 공 바로 아래/위면 감속
                        ghost['vx'] *= 0.92
                else:
                    # 공이 없거나 안 보이면 약간의 난수 이동
                    ghost['vx'] += random.uniform(-0.2, 0.2)

                # 좌우 이동
                move_amount = int(ghost['vx'])
                rect.x += move_amount

                # 벽 충돌 (바운스)
                if rect.left < self.GAME_LEFT:
                    rect.left = self.GAME_LEFT
                    ghost['vx'] = abs(ghost['vx']) * 0.5
                elif rect.right > self.GAME_RIGHT:
                    rect.right = self.GAME_RIGHT
                    ghost['vx'] = -abs(ghost['vx']) * 0.5

                # 속도 제한
                speed = abs(ghost['vx'])
                if speed > 10.0:
                    ghost['vx'] = (ghost['vx'] / speed) * 10.0

            # 넉백 물리 적용 (공 타격 후 밀려남)
            if abs(ghost.get('knockback_vy', 0)) > 0.5 or abs(ghost.get('knockback_vx', 0)) > 0.5:
                rect.x += int(ghost['knockback_vx'] * dt)
                rect.y += int(ghost['knockback_vy'] * dt)
                # 감쇠
                ghost['knockback_vx'] *= 0.88
                ghost['knockback_vy'] *= 0.88
                # 목표 Y로 복귀하는 힘
                target_y = ghost['target_y']
                rect.centery += int((target_y - rect.centery) * 0.05)
            else:
                ghost['knockback_vx'] = 0.0
                ghost['knockback_vy'] = 0.0

            # 박치기 타이머 감소
            if ghost.get('headbutt_timer', 0) > 0:
                ghost['headbutt_timer'] -= dt
                if ghost['headbutt_timer'] < 0:
                    ghost['headbutt_timer'] = 0.0

            # 공과 충돌 체크 (등장 완료 후, 쿨다운 없을 때, 다른 유령이 먹고 있지 않을 때)
            _ball_hidden = game_state.get('ghost_summon_ball_hidden', False)
            _can_check = (ball is not None and ghost['spawn_time'] >= self.EMERGE_DURATION
                    and ghost['hit_cooldown'] <= 0 and not self._eating_ball
                    and not _ball_hidden)
            if _can_check:
                # BallWrapper는 width/height를 가짐, ArenaBall은 없음 → getattr로 폴백
                bw = getattr(ball, 'width', 20)
                bh = getattr(ball, 'height', 20)
                # BallWrapper.x/y는 좌상단, ArenaBall.x/y는 중심 → width가 있으면 좌상단 기준
                if bw > 1:
                    # BallWrapper (좌상단 기준) - 중심 좌표로 변환
                    ball_cx = ball.x + bw / 2
                    ball_cy = ball.y + bh / 2
                else:
                    # ArenaBall (중심 기준)
                    ball_cx = ball.x
                    ball_cy = ball.y
                    bw, bh = 20, 20
                ball_rect = pygame.Rect(int(ball_cx) - bw // 2, int(ball_cy) - bh // 2, bw, bh)

                if rect.colliderect(ball_rect):
                    # 연속 포획 판정: 다른 유령이 방금 공을 발사한 직후인지 확인
                    is_consecutive = self._time_since_ghost_release < self.CONSECUTIVE_CATCH_WINDOW

                    # 공 속도 저장 후 숨김 (game_state 통해 pingfighter에 전달)
                    self._saved_ball_vx = ball.vx
                    self._saved_ball_vy = ball.vy
                    ball.vx = 0.0
                    ball.vy = 0.0
                    game_state['ghost_summon_ball_hidden'] = True
                    self._eating_ball = True
                    self._eating_ghost_id = ghost['id']

                    if is_consecutive:
                        # 연속 포획! 먹기 단계 생략 → 즉시 순간이동 후 발사
                        ghost['eating'] = True
                        ghost['eat_timer'] = 0.0
                        ghost['eat_scale'] = 1.0
                        ghost['eat_grow_acc'] = 0.0
                        ghost['eat_bulge_phase'] = 0.0
                        ghost['hit_cooldown'] = 99.0
                        ghost['teleporting'] = True
                        ghost['teleport_phase'] = 'disappear'
                        ghost['teleport_timer'] = 0.0
                        ghost['pre_teleport_x'] = float(rect.centerx)
                        ghost['pre_teleport_y'] = float(rect.centery)
                        min_x = self.GAME_LEFT + 60
                        max_x = self.GAME_RIGHT - 60
                        attempts = 0
                        new_x = random.randint(int(min_x), int(max_x))
                        while abs(new_x - rect.centerx) < 100 and attempts < 20:
                            new_x = random.randint(int(min_x), int(max_x))
                            attempts += 1
                        ghost['teleport_target_x'] = float(new_x)
                    else:
                        # 일반 포획: 먹기 → 순간이동 → 발사 (정상 사이클)
                        ghost['eating'] = True
                        ghost['eat_timer'] = 0.0
                        ghost['eat_scale'] = 1.0
                        ghost['eat_grow_acc'] = 0.0
                        ghost['eat_bulge_phase'] = 0.0
                        ghost['hit_cooldown'] = 99.0

                    # 먹기 사운드 (쿠로미 혀 내밀기)
                    try:
                        project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                        sound_path = os.path.join(project_root, "sounds", "kuromitongue.wav")
                        if os.path.exists(sound_path):
                            s = pygame.mixer.Sound(sound_path)
                            s.set_volume(0.5)
                            s.play()
                    except Exception:
                        pass
                    ghost['swallow_sound_played'] = False

            # 유령 파티클 생성 (가끔)
            if random.random() < 0.15:
                self._ghost_particles.append({
                    'x': rect.centerx + random.randint(-30, 30),
                    'y': rect.centery + random.randint(-10, 10),
                    'vy': random.uniform(-1.5, -0.5),
                    'alpha': random.randint(100, 180),
                    'size': random.randint(2, 4),
                    'life': random.uniform(0.5, 1.2),
                    'age': 0.0,
                })

            new_ghosts.append(ghost)

        self.ghosts = new_ghosts

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        game_state['has_ghost_summon'] = False

        # 유령 앰비언트 사운드 정지
        if self._ghost_ambient_sound:
            self._ghost_ambient_sound.fadeout(600)
            self._ghost_ambient_sound = None

        # 유령 소멸 사운드 재생
        try:
            project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            out_path = os.path.join(project_root, "sounds", "bencyghostout.wav")
            if os.path.exists(out_path):
                out_snd = pygame.mixer.Sound(out_path)
                out_snd.set_volume(0.5)
                out_snd.play()
        except Exception:
            pass

        # 공을 먹고 있는 유령이 있으면 공을 복원
        if self._eating_ball and ball is not None:
            # 마지막으로 먹고 있던 유령 위치에서 발사
            release_x = 380.0
            release_y = 375.0
            for ghost in self.ghosts:
                if ghost['id'] == self._eating_ghost_id:
                    release_x = float(ghost['rect'].centerx)
                    release_y = float(ghost['rect'].centery)
                    break
            release_dir = 1 if self.caster_is_top else -1
            ball.vx = self._saved_ball_vx * 0.5
            ball.vy = abs(self._saved_ball_vy) * release_dir
            if abs(ball.vy) < 4.0:
                ball.vy = 4.0 * release_dir
            # game_state를 통해 위치 변경 + 숨김 해제
            game_state['ghost_summon_ball_release'] = {
                'ball_x': release_x,
                'ball_y': release_y,
            }
            game_state['ghost_summon_ball_hidden'] = False
            self._eating_ball = False
            self._eating_ghost_id = -1

        # 남은 유령을 dying_ghosts로 이동
        for ghost in self.ghosts:
            if ghost['active']:
                self.dying_ghosts.append({
                    'rect': ghost['rect'].copy(),
                    'death_time': 0.0,
                    'id': ghost['id'],
                })
        self.ghosts = []

    def reset_for_new_round(self, game_state: dict):
        super().reset_for_new_round(game_state)
        # 유령 앰비언트 사운드 정지
        if self._ghost_ambient_sound:
            self._ghost_ambient_sound.stop()
            self._ghost_ambient_sound = None
        self.ghosts = []
        self.dying_ghosts = []
        self._ghost_particles = []
        self._teleport_effects = []
        self._eating_ball = False
        self._eating_ghost_id = -1
        self._time_since_ghost_release = 999.0
        game_state['has_ghost_summon'] = False
        game_state['ghost_summon_ball_hidden'] = False
        game_state.pop('ghost_summon_ball_release', None)

    def update(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        super().update(dt, caster_paddle, target_paddle, ball, game_state)
        # dying_ghosts는 is_active 관계없이 항상 업데이트
        if self.dying_ghosts:
            new_dying = []
            for dying in self.dying_ghosts:
                dying['death_time'] += dt
                if dying['death_time'] < self.DEATH_DURATION:
                    new_dying.append(dying)
            self.dying_ghosts = new_dying
        # 순간이동 이펙트도 is_active 관계없이 업데이트
        if self._teleport_effects:
            new_tp = []
            for p in self._teleport_effects:
                p['age'] += dt
                p['x'] += p['vx'] * dt
                p['y'] += p['vy'] * dt
                ratio = max(0, 1.0 - p['age'] / p['life'])
                p['alpha'] = int(p['alpha'] * ratio)
                if p['age'] < p['life'] and p['alpha'] > 5:
                    new_tp.append(p)
            self._teleport_effects = new_tp
        # 유령 파티클도 is_active 관계없이 항상 업데이트 (잔류 방지)
        if self._ghost_particles:
            new_particles = []
            for p in self._ghost_particles:
                p['age'] += dt
                p['y'] += p['vy']
                p['alpha'] = int(p['alpha'] * max(0, 1.0 - p['age'] / p['life']))
                if p['age'] < p['life'] and p['alpha'] > 5:
                    new_particles.append(p)
            self._ghost_particles = new_particles

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        renderer = get_shadow_clone_renderer() if HERO_PADDLE_RENDERER_AVAILABLE else None

        # 활성 유령 그리기
        for ghost in self.ghosts:
            self._draw_ghost(screen, ghost, renderer)

        # 소멸 중인 유령 그리기
        for dying in self.dying_ghosts:
            self._draw_dying_ghost(screen, dying, renderer)

        # 파티클 그리기
        for p in self._ghost_particles:
            if p['alpha'] > 5:
                color = (100, 200, 180, int(p['alpha']))
                pygame.draw.circle(screen, color, (int(p['x']), int(p['y'])), p['size'])

        # 순간이동 이펙트 파티클 그리기
        for p in self._teleport_effects:
            if p['alpha'] > 5:
                c = p['color']
                alpha = int(min(255, p['alpha']))
                size = max(1, p['size'])
                surf = _psurf((size * 2, size * 2), pygame.SRCALPHA)
                pygame.draw.circle(surf, (*c, alpha), (size, size), size)
                screen.blit(surf, (int(p['x']) - size, int(p['y']) - size))

    def _draw_ghost(self, screen: pygame.Surface, ghost: dict, renderer):
        """활성 유령 렌더링 - 반투명 유령 캐릭터"""
        rect = ghost['rect']
        spawn_time = ghost['spawn_time']

        # ============================================================
        # 순간이동 중 렌더링
        # ============================================================
        if ghost['teleporting']:
            phase = ghost['teleport_phase']
            timer = ghost['teleport_timer']

            if phase == 'disappear':
                # 사라지는 중: 점점 작아지며 투명해짐
                t = min(1.0, timer / self.TELEPORT_DISAPPEAR_DUR)
                alpha = int(180 * (1.0 - t))
                shrink_scale = ghost['eat_scale'] * (1.0 - t * 0.8)
                x = int(ghost['pre_teleport_x'])
                y = int(ghost['pre_teleport_y'])
                if alpha > 10:
                    # 소용돌이 회전 효과
                    rotate_offset_x = int(8 * _sin(timer * 25) * (1.0 - t))
                    rotate_offset_y = int(8 * math.cos(timer * 25) * (1.0 - t))
                    self._draw_fallback_ghost(screen, x + rotate_offset_x,
                                            y + rotate_offset_y, alpha, shrink_scale)
                return

            elif phase == 'appear':
                # 나타나는 중: 점점 커지며 나타남
                t = min(1.0, timer / self.TELEPORT_APPEAR_DUR)
                # 탄성 바운스 이징
                if t < 0.6:
                    ease_t = (t / 0.6) ** 0.5
                else:
                    overshoot = (t - 0.6) / 0.4
                    ease_t = 1.0 + 0.15 * _sin(overshoot * math.pi)
                alpha = int(180 * min(1.0, t * 1.5))
                appear_scale = 0.2 + 0.8 * ease_t
                x = rect.centerx
                y = rect.centery
                if alpha > 10:
                    self._draw_fallback_ghost(screen, x, y, alpha, appear_scale)
                return

            elif phase == 'release':
                # 발사 직후 - 일반 렌더링으로 넘어감
                pass

        # ============================================================
        # 공 먹기 중 렌더링
        # ============================================================
        if ghost['eating']:
            emerge_progress = min(1.0, spawn_time / self.EMERGE_DURATION)
            alpha = int(180 * emerge_progress)
            x = rect.centerx
            y = rect.centery

            eat_scale = ghost['eat_scale']
            bulge_phase = ghost['eat_bulge_phase']

            # 울퉁불퉁 애니메이션: sin 파형으로 X/Y 스케일 비대칭 변화
            bulge_x = eat_scale * (1.0 + 0.06 * _sin(bulge_phase))
            bulge_y = eat_scale * (1.0 + 0.06 * _sin(bulge_phase + 1.5))

            # 약간의 떨림 (소화 중)
            shake_x = int(2 * _sin(bulge_phase * 3.7))
            shake_y = int(1.5 * math.cos(bulge_phase * 2.9))

            # 바닥 그림자 (먹기 스케일에 맞게)
            shadow_width = int(self.GHOST_WIDTH * 0.8 * eat_scale)
            shadow_alpha = int(alpha * 0.35)
            shadow_y_base = rect.centery + 20
            shadow_surf = _psurf((shadow_width, 8), pygame.SRCALPHA)
            pygame.draw.ellipse(shadow_surf, (10, 20, 18, shadow_alpha),
                              (0, 0, shadow_width, 8))
            screen.blit(shadow_surf, (x - shadow_width // 2, shadow_y_base))

            # 울퉁불퉁한 유령 렌더링
            self._draw_eating_ghost(screen, x + shake_x, y + shake_y,
                                   alpha, bulge_x, bulge_y, ghost['eat_timer'])
            return

        # ============================================================
        # 일반 렌더링
        # ============================================================

        # 등장 시 페이드인
        emerge_progress = min(1.0, spawn_time / self.EMERGE_DURATION)

        # 둥실둥실 부유 모션 (크게 위아래로 + 2차 진동)
        hover_main = 14 * _sin(spawn_time * 2.2 + ghost['id'] * math.pi)
        hover_sub = 5 * _sin(spawn_time * 3.8 + ghost['id'] * 2.1)
        hover = int(hover_main + hover_sub)

        alpha = int(180 * emerge_progress)
        x = rect.centerx
        y = rect.centery + hover

        # 박치기 애니메이션 오프셋
        headbutt_timer = ghost.get('headbutt_timer', 0)
        headbutt_offset_y = 0
        headbutt_scale = 1.0
        if headbutt_timer > 0:
            # 0.3초 중: 앞 0.1초는 돌진, 뒤 0.2초는 반동 복귀
            t = headbutt_timer / 0.3
            if t > 0.67:
                # 돌진 (상대 쪽으로 빠르게 전진)
                lunge = (1.0 - t) / 0.33  # 0→1
                lunge_dir = -1 if self.caster_is_top else 1  # 상대 방향
                headbutt_offset_y = int(lunge_dir * lunge * -18)
                headbutt_scale = 1.0 + lunge * 0.15  # 살짝 커짐
            else:
                # 반동 (원래 위치로 탄성 복귀)
                recoil = t / 0.67  # 1→0
                recoil_dir = 1 if self.caster_is_top else -1  # 캐스터 쪽으로
                headbutt_offset_y = int(recoil_dir * _sin(recoil * math.pi) * 10)
                headbutt_scale = 1.0 + recoil * 0.05

        y += headbutt_offset_y

        # 바닥 그림자 (부유 높이에 따라 크기/투명도 변화)
        shadow_scale = 1.0 - abs(hover_main) / 25.0
        shadow_width = int(self.GHOST_WIDTH * 0.8 * max(0.5, shadow_scale))
        shadow_alpha = int(alpha * 0.35 * max(0.3, shadow_scale))
        shadow_y_base = rect.centery + 20
        shadow_surf = _psurf((shadow_width, 8), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_surf, (10, 20, 18, shadow_alpha),
                          (0, 0, shadow_width, 8))
        screen.blit(shadow_surf, (x - shadow_width // 2, shadow_y_base))

        # 유령 캐릭터 렌더링 (항상 유령 모습)
        self._draw_fallback_ghost(screen, x, y, alpha, headbutt_scale)

    def _draw_fallback_ghost(self, screen: pygame.Surface, x: int, y: int, alpha: int, scale: float = 1.0):
        """유령 렌더링 - 박치기 시 스케일 변화"""
        ghost_color = (80, 180, 160, alpha)
        eye_color = (140, 255, 230, alpha)

        base_w, base_h = 50, 60
        surf_w = int(base_w * scale)
        surf_h = int(base_h * scale)
        body_surf = _psurf((surf_w, surf_h), pygame.SRCALPHA)

        s = scale  # 스케일 축약
        # 유령 몸체
        pygame.draw.ellipse(body_surf, ghost_color,
                          (int(5*s), int(5*s), int(40*s), int(35*s)))
        # 아래쪽 물결 모양
        for i in range(4):
            wave_x = int((8 + i * 10) * s)
            wave_h = int(15*s) + int(3 * _sin(pygame.time.get_ticks() * 0.005 + i))
            pygame.draw.ellipse(body_surf, ghost_color,
                              (wave_x - int(5*s), int(30*s), int(10*s), wave_h))
        # 눈 (빛나는 청록)
        eye_size = max(2, int(3*s))
        pygame.draw.circle(body_surf, eye_color, (int(18*s), int(18*s)), eye_size)
        pygame.draw.circle(body_surf, eye_color, (int(32*s), int(18*s)), eye_size)
        # 눈 하이라이트
        pygame.draw.circle(body_surf, (200, 255, 245, alpha), (int(17*s), int(17*s)), 1)
        pygame.draw.circle(body_surf, (200, 255, 245, alpha), (int(31*s), int(17*s)), 1)

        # 박치기 시 눈 글로우
        if scale > 1.05:
            bright_alpha = min(255, int(alpha * 1.5))
            bright_eye = (200, 255, 240, bright_alpha)
            pygame.draw.circle(body_surf, bright_eye, (int(18*s), int(18*s)), eye_size + 2)
            pygame.draw.circle(body_surf, bright_eye, (int(32*s), int(18*s)), eye_size + 2)

        screen.blit(body_surf, (x - surf_w // 2, y - surf_h + int(10*s)))

    def _draw_eating_ghost(self, screen: pygame.Surface, x: int, y: int,
                           alpha: int, scale_x: float, scale_y: float, eat_timer: float):
        """공을 먹고 있는 유령 렌더링 - 울퉁불퉁한 비대칭 스케일"""
        ghost_color = (80, 180, 160, alpha)
        eye_color = (140, 255, 230, alpha)

        base_w, base_h = 50, 60
        surf_w = int(base_w * scale_x) + 4
        surf_h = int(base_h * scale_y) + 4
        body_surf = _psurf((surf_w, surf_h), pygame.SRCALPHA)

        sx, sy = scale_x, scale_y
        ticks = pygame.time.get_ticks() * 0.001

        # 유령 몸체 (비대칭 스케일로 울퉁불퉁한 느낌)
        body_w = int(40 * sx)
        body_h = int(35 * sy)
        pygame.draw.ellipse(body_surf, ghost_color,
                          (int(5 * sx), int(5 * sy), body_w, body_h))

        # 볼록한 부분 (공이 배 안에서 움직이는 느낌)
        bulge_x_offset = int(8 * _sin(eat_timer * 6.0))
        bulge_y_offset = int(5 * math.cos(eat_timer * 4.5))
        bulge_r = int(8 * min(sx, sy))
        bulge_cx = int(25 * sx) + bulge_x_offset
        bulge_cy = int(22 * sy) + bulge_y_offset
        bulge_color = (90, 195, 175, min(255, int(alpha * 1.1)))
        pygame.draw.circle(body_surf, bulge_color, (bulge_cx, bulge_cy), bulge_r)

        # 아래쪽 물결 모양 (더 격하게 출렁거림)
        for i in range(4):
            wave_x = int((8 + i * 10) * sx)
            wave_h = int(15 * sy) + int(5 * _sin(ticks * 8 + i * 1.5 + eat_timer * 4))
            pygame.draw.ellipse(body_surf, ghost_color,
                              (wave_x - int(5 * sx), int(30 * sy), int(10 * sx), wave_h))

        # 눈 (먹는 중 - 만족스러운 표정, 초승달 눈)
        eye_y = int(16 * sy)
        left_eye_x = int(18 * sx)
        right_eye_x = int(32 * sx)
        eye_sz = max(2, int(3.5 * min(sx, sy)))

        # 먹는 동안 눈을 초승달 모양으로 (행복한 표정)
        # 아래쪽 반원을 검정으로 덮어서 초승달 효과
        pygame.draw.circle(body_surf, eye_color, (left_eye_x, eye_y), eye_sz)
        pygame.draw.circle(body_surf, eye_color, (right_eye_x, eye_y), eye_sz)
        # 눈 아래쪽 가리기 (초승달)
        cover_color = ghost_color
        pygame.draw.circle(body_surf, cover_color, (left_eye_x, eye_y + 2), eye_sz)
        pygame.draw.circle(body_surf, cover_color, (right_eye_x, eye_y + 2), eye_sz)

        # 입 (크게 벌린 O자 모양 → 씹는 모션)
        mouth_x = int(25 * sx)
        mouth_y = int(25 * sy)
        chew_phase = _sin(eat_timer * 8.0)
        mouth_h = max(2, int((4 + 3 * abs(chew_phase)) * min(sx, sy)))
        mouth_w = max(3, int((6 + 2 * chew_phase) * min(sx, sy)))
        mouth_color = (40, 80, 70, min(255, int(alpha * 1.2)))
        pygame.draw.ellipse(body_surf, mouth_color,
                          (mouth_x - mouth_w // 2, mouth_y - mouth_h // 2,
                           mouth_w, mouth_h))

        # 눈 글로우 (먹는 중 밝게)
        glow_alpha = min(255, int(alpha * 1.3))
        glow_color = (160, 255, 235, glow_alpha)
        pygame.draw.circle(body_surf, glow_color, (left_eye_x, eye_y - 1), max(1, eye_sz - 1))
        pygame.draw.circle(body_surf, glow_color, (right_eye_x, eye_y - 1), max(1, eye_sz - 1))

        screen.blit(body_surf, (x - surf_w // 2, y - surf_h + int(10 * sy)))

    def _draw_dying_ghost(self, screen: pygame.Surface, dying: dict, renderer):
        """소멸 중인 유령 (위로 떠오르며 사라짐)"""
        death_progress = dying['death_time'] / self.DEATH_DURATION
        base_alpha = int(180 * (1.0 - death_progress))

        rect = dying['rect']
        x = rect.centerx
        # 위로 떠오름
        y = rect.centery - int(40 * death_progress)

        if base_alpha <= 10:
            return

        # 유령 소멸 이펙트 (위로 흩어지는 파티클)
        num_particles = int(8 * death_progress)
        for i in range(num_particles):
            px = x + random.randint(-30, 30)
            py = y - int(30 * death_progress) + random.randint(-15, 15)
            p_alpha = int(base_alpha * 0.5 * random.uniform(0.3, 1.0))
            if p_alpha > 10:
                p_size = random.randint(2, 5)
                p_color = random.choice([
                    (80, 200, 170), (100, 220, 190), (60, 180, 150)
                ])
                pygame.draw.circle(screen, (*p_color, p_alpha), (px, py), p_size)

        # 잔상 (폴백 스타일)
        self._draw_fallback_ghost(screen, x, y, base_alpha)


# ============================================================================
# 네크로 (Necro) - 해골 궁수 스킬
# ============================================================================

class SkeletonArcher(HeroSkill):
    """해골 궁수 - 내 진영에 해골 궁수를 소환. 공에 맞으면 죽고, 적을 향해 화살 발사"""

    GAME_TOP = 0
    GAME_BOTTOM = 750

    ARCHER_WIDTH = 30
    ARCHER_HEIGHT = 50
    ARCHER_SPEED = 3.0          # 궁수 이동 속도
    ARROW_SPEED = 12.0          # 화살 속도
    ARROW_LENGTH = 16           # 화살 길이
    ARROW_DRAW_TIME = 1.0       # 시위 당기기 애니메이션 시간
    ARROW_COOLDOWN_MIN = 1.0    # 화살 발사 쿨타임 최소
    ARROW_COOLDOWN_MAX = 3.0    # 화살 발사 쿨타임 최대
    EMERGE_DURATION = 1.2       # 등장 애니메이션 (뼈 조립)
    DEATH_DURATION = 0.7        # 사망 애니메이션 (뼈 파편)

    # 넉백 (쿠로카게 수리검과 동일)
    KNOCKBACK_VEL = 150

    def __init__(self):
        super().__init__(
            skill_id="skeleton_archer",
            name="Skeleton Archer",
            korean_name="해골 궁수",
            description="망자의 궁수를 불러내어 적에게 저주의 화살을 퍼붓는다",
            trigger=SkillTrigger.ON_COOLDOWN,
            cooldown=9.0,
            duration=999999.0,  # 사실상 무제한 (공에 맞아야 사라짐)
            hero_id="necro"
        )
        self.archers = []           # 활성 궁수 목록
        self.dying_archers = []     # 사망 애니메이션 중인 궁수
        self.arrows = []            # 비행 중인 화살
        self.arrow_particles = []   # 화살 히트 파티클
        self.caster_is_top = False
        self._next_archer_id = 0
        self._summon_sound = None
        self._sounds_loaded = False

    def _load_sounds(self):
        if self._sounds_loaded:
            return
        self._sounds_loaded = True
        try:
            project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            path = os.path.join(project_root, "sounds", "bonemake2.wav")
            if os.path.exists(path):
                self._summon_sound = pygame.mixer.Sound(path)
                self._summon_sound.set_volume(0.6)
        except Exception:
            pass

    def can_use(self) -> bool:
        """중복 소환 허용 - is_active 체크 안 함"""
        return self.current_cooldown <= 0

    def use(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        """스킬 사용 - 중복 소환 허용"""
        if not self.can_use():
            return {}

        self.caster_is_top = getattr(caster_paddle, 'is_top', False)

        # 쿨타임 적용 (퍽 멀티플라이어)
        if self.caster_is_top:
            skill_cd_mult = game_state.get('perk_skill_cd_mult_top', 1.0)
        else:
            skill_cd_mult = game_state.get('perk_skill_cd_mult_bottom', 1.0)
        self.current_cooldown = self.cooldown * skill_cd_mult
        self.activation_flash_timer = 1.5  # 발동 이펙트 1.5초

        # 항상 활성 상태 유지 (궁수가 살아있는 동안)
        self.is_active = True
        self.active_timer = self.duration

        return self._apply_effect(caster_paddle, target_paddle, ball, game_state)

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        self.caster_is_top = getattr(caster_paddle, 'is_top', False)
        _is_guard = getattr(caster_paddle, 'is_bodyguard', False)

        # 궁수 소환 위치: 내 진영 (캐스터 근처)
        spawn_x = random.randint(self.GAME_LEFT + 40, self.GAME_RIGHT - 40)
        if self.caster_is_top:
            patrol_y_min = 100
            patrol_y_max = 220
            spawn_y = caster_paddle.y + 70
        else:
            patrol_y_min = 570
            patrol_y_max = 690
            spawn_y = caster_paddle.y - 30

        # 20% 확률로 황금 해골궁수 소환
        is_golden = random.random() < 0.2

        archer = {
            'id': self._next_archer_id,
            'x': float(spawn_x),
            'y': float(spawn_y),
            'target_x': float(spawn_x),
            'patrol_y_min': patrol_y_min,
            'patrol_y_max': patrol_y_max,
            'vx': random.choice([-1, 1]) * self.ARCHER_SPEED,
            'spawn_time': 0.0,
            'alive': True,
            'is_golden': is_golden,  # 황금 궁수 여부
            # 화살 관련
            'arrow_cooldown': random.uniform(self.ARROW_COOLDOWN_MIN, self.ARROW_COOLDOWN_MAX),
            'is_drawing': False,     # 시위 당기는 중
            'draw_timer': 0.0,       # 시위 당기기 진행 시간
            'draw_target_x': 0.0,    # 시위 당기기 시작 시 적 위치 저장
            'draw_target_y': 0.0,
            # 애니메이션
            'body_bob': 0.0,
            'step_phase': random.uniform(0, math.pi * 2),
        }
        self.archers.append(archer)
        self._next_archer_id += 1

        self._load_sounds()
        if self._summon_sound:
            try:
                self._summon_sound.play()
            except Exception:
                pass

        flash_color = (255, 215, 50) if is_golden else (160, 180, 120)
        return {
            'screen_effect': ScreenEffect.FLASH,
            'flash_color': flash_color,
            'flash_duration': 0.15 if is_golden else 0.1,
        }

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        # --- 궁수 업데이트 ---
        new_archers = []
        for archer in self.archers:
            if not archer['alive']:
                continue

            archer['spawn_time'] += dt

            # 등장 애니메이션 중에는 이동/공격 안 함
            if archer['spawn_time'] < self.EMERGE_DURATION:
                new_archers.append(archer)
                continue

            # === 공과 충돌 체크 (상대가 친 공에만 즉사) ===
            if ball is not None:
                # 인게임 호위무사: 플레이어가 소환 → 보스가 친 공(vy>0)에만 즉사
                if game_state.get('is_ingame_bodyguard', False):
                    ball_from_opponent = (ball.vy > 0)
                else:
                    # 투기장: 내가 친 공은 무시
                    ball_from_opponent = (
                        (not self.caster_is_top and ball.vy > 0) or
                        (self.caster_is_top and ball.vy < 0)
                    )
                ax, ay = archer['x'], archer['y']
                bx = ball.x + ball.width / 2
                by = ball.y + ball.height / 2
                dist = math.sqrt((ax - bx) ** 2 + (ay - by) ** 2)
                if ball_from_opponent and dist < (self.ARCHER_WIDTH / 2 + ball.width / 2):
                    # 궁수 사망!
                    archer['alive'] = False
                    # 뼈 파편 생성 (사방으로 튀어나감)
                    bone_fragments = []
                    for bi in range(12):
                        frag_angle = (bi / 12) * math.pi * 2 + random.uniform(-0.3, 0.3)
                        frag_speed = random.uniform(60, 180)
                        bone_fragments.append({
                            'x': ax, 'y': ay,
                            'vx': math.cos(frag_angle) * frag_speed,
                            'vy': math.sin(frag_angle) * frag_speed - 50,
                            'rot': random.uniform(0, math.pi * 2),
                            'rot_speed': random.uniform(-15, 15),
                            'length': random.randint(4, 10),
                            'is_bow': bi == 0,  # 첫 번째는 활 파편
                        })
                    self.dying_archers.append({
                        'x': ax, 'y': ay,
                        'death_time': 0.0,
                        'fragments': bone_fragments,
                    })
                    # 사망 사운드
                    try:
                        project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                        sound_path = os.path.join(project_root, "sounds", "skulldead.wav")
                        if os.path.exists(sound_path):
                            s = pygame.mixer.Sound(sound_path)
                            s.set_volume(0.3)
                            s.play()
                    except Exception:
                        pass
                    continue

            # === 화살 발사 로직 ===
            if archer['is_drawing']:
                # 시위 당기는 중 - 제자리 고정
                archer['draw_timer'] += dt
                if archer['draw_timer'] >= self.ARROW_DRAW_TIME:
                    # 발사 직전 적 영웅 최종 위치 갱신 (시위 당기는 동안 이동한 적 추적)
                    enemy_key = 'hero_paddle_bottom' if self.caster_is_top else 'hero_paddle_top'
                    hero_info = game_state.get(enemy_key)
                    if hero_info:
                        archer['draw_target_x'] = float(hero_info['x'] + hero_info['width'] / 2)
                        archer['draw_target_y'] = float(hero_info['y'] + hero_info['height'] / 2)
                    # 발사!
                    self._fire_arrow(archer, game_state)
                    archer['is_drawing'] = False
                    archer['draw_timer'] = 0.0
                    archer['arrow_cooldown'] = random.uniform(
                        self.ARROW_COOLDOWN_MIN, self.ARROW_COOLDOWN_MAX
                    )
            else:
                # 쿨타임 감소
                archer['arrow_cooldown'] -= dt
                if archer['arrow_cooldown'] <= 0:
                    # 시위 당기기 시작 - game_state에서 적 영웅 패들 위치 직접 참조
                    # (target_paddle이 호위무사일 수 있으므로, 영웅 위치만 사용)
                    enemy_key = 'hero_paddle_bottom' if self.caster_is_top else 'hero_paddle_top'
                    hero_info = game_state.get(enemy_key)
                    if hero_info:
                        archer['is_drawing'] = True
                        archer['draw_timer'] = 0.0
                        archer['draw_target_x'] = float(hero_info['x'] + hero_info['width'] / 2)
                        archer['draw_target_y'] = float(hero_info['y'] + hero_info['height'] / 2)
                    elif target_paddle is not None and not getattr(target_paddle, 'is_bodyguard', False):
                        # 폴백: game_state에 없으면 target_paddle 사용
                        archer['is_drawing'] = True
                        archer['draw_timer'] = 0.0
                        archer['draw_target_x'] = float(target_paddle.x + target_paddle.width / 2)
                        archer['draw_target_y'] = float(target_paddle.y + target_paddle.height / 2)
                    else:
                        archer['arrow_cooldown'] = 0.5  # 대상 없음, 재시도

                # 이동 (시위 당기는 중에는 이동 안 함, 배속 적용)
                archer['x'] += archer['vx'] * dt * 60
                archer['step_phase'] += dt * 6.0
                archer['body_bob'] = _sin(archer['step_phase']) * 2.0

                # 좌우 벽 반사
                if archer['x'] < self.GAME_LEFT + 20:
                    archer['x'] = self.GAME_LEFT + 20
                    archer['vx'] = abs(archer['vx'])
                elif archer['x'] > self.GAME_RIGHT - 20:
                    archer['x'] = self.GAME_RIGHT - 20
                    archer['vx'] = -abs(archer['vx'])

                # 가끔 방향 전환
                if random.random() < 0.005:
                    archer['vx'] = -archer['vx']

            new_archers.append(archer)

        self.archers = new_archers

        # --- 화살 업데이트 ---
        new_arrows = []
        for arrow in self.arrows:
            arrow['x'] += arrow['vx'] * dt * 60
            arrow['y'] += arrow['vy'] * dt * 60
            arrow['age'] += dt

            # 화면 밖 제거
            if (arrow['x'] < self.GAME_LEFT - 20 or arrow['x'] > self.GAME_RIGHT + 20 or
                arrow['y'] < self.GAME_TOP - 20 or arrow['y'] > self.GAME_BOTTOM + 20):
                continue

            # 수명 초과 (5초)
            if arrow['age'] > 5.0:
                continue

            # 적 영웅 패들 충돌 체크 - game_state에서 영웅 위치 직접 참조 (호위무사 무시)
            enemy_key = 'hero_paddle_bottom' if self.caster_is_top else 'hero_paddle_top'
            hero_info = game_state.get(enemy_key)
            if hero_info:
                paddle_cx = hero_info['x'] + hero_info['width'] / 2
                paddle_cy = hero_info['y'] + hero_info['height'] / 2
                dist = math.sqrt((arrow['x'] - paddle_cx) ** 2 + (arrow['y'] - paddle_cy) ** 2)

                if dist < (hero_info['width'] / 2 + 8):
                    # 화살 명중! → 넉백 (수리검과 동일) - 영웅만 타격
                    self._apply_arrow_hit(arrow, target_paddle, game_state)
                    continue
            elif target_paddle is not None and not getattr(target_paddle, 'is_bodyguard', False):
                # 폴백: game_state에 없으면 target_paddle 사용
                paddle_cx = target_paddle.x + target_paddle.width / 2
                paddle_cy = target_paddle.y + target_paddle.height / 2
                dist = math.sqrt((arrow['x'] - paddle_cx) ** 2 + (arrow['y'] - paddle_cy) ** 2)

                if dist < (target_paddle.width / 2 + 8):
                    self._apply_arrow_hit(arrow, target_paddle, game_state)
                    continue

            new_arrows.append(arrow)

        self.arrows = new_arrows

        # --- 히트 파티클 업데이트 ---
        new_particles = []
        for p in self.arrow_particles:
            p['age'] += dt
            p['x'] += p['vx'] * dt
            p['y'] += p['vy'] * dt
            p['alpha'] = int(200 * max(0, 1.0 - p['age'] / p['life']))
            if p['age'] < p['life'] and p['alpha'] > 5:
                new_particles.append(p)
        self.arrow_particles = new_particles

        # --- 사망 애니메이션 업데이트 ---
        new_dying = []
        for dying in self.dying_archers:
            dying['death_time'] += dt
            if dying['death_time'] < self.DEATH_DURATION:
                new_dying.append(dying)
        self.dying_archers = new_dying

        # 궁수가 전부 죽었고, 화살/파티클도 없으면 스킬 비활성화
        if not self.archers and not self.arrows and not self.dying_archers and not self.arrow_particles:
            self.is_active = False
            self.active_timer = 0.0

    def _fire_arrow(self, archer: dict, game_state: dict):
        """화살 발사 - 황금 궁수는 멀티플샷 3발 동시 발사"""
        dx = archer['draw_target_x'] - archer['x']
        dy = archer['draw_target_y'] - archer['y']
        dist = math.sqrt(dx ** 2 + dy ** 2)
        if dist < 1.0:
            return

        # 정규화된 방향
        base_angle = math.atan2(dy, dx)
        is_golden = archer.get('is_golden', False)

        if is_golden:
            # 황금 궁수: 멀티플샷 3발 (중앙, +20도, -20도) - 고정 각도
            angles = [base_angle, base_angle + math.radians(20), base_angle - math.radians(20)]
        else:
            # 일반 궁수: 1발 + 오차범위 ±15도
            spread = math.radians(random.uniform(-15, 15))
            angles = [base_angle + spread]

        for angle in angles:
            nx = math.cos(angle)
            ny = math.sin(angle)
            arrow = {
                'x': archer['x'],
                'y': archer['y'],
                'vx': nx * self.ARROW_SPEED,
                'vy': ny * self.ARROW_SPEED,
                'angle': angle,
                'age': 0.0,
                'archer_id': archer['id'],
                'is_golden': is_golden,  # 황금 화살 여부
            }
            self.arrows.append(arrow)

        # 발사 사운드
        try:
            project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            sound_path = os.path.join(project_root, "sounds", "arrow.wav")
            if os.path.exists(sound_path):
                s = pygame.mixer.Sound(sound_path)
                s.set_volume(0.7)
                s.play()
        except Exception:
            pass

    def _apply_arrow_hit(self, arrow: dict, target_paddle, game_state: dict):
        """화살 명중 시 넉백 적용 (쿠로카게 수리검과 동일)"""
        # 넉백 방향 (화살 X 속도 방향)
        if abs(arrow['vx']) < 1:
            knockback_dir = random.choice([-1, 1])
        else:
            knockback_dir = 1 if arrow['vx'] > 0 else -1

        target_is_top = getattr(target_paddle, 'is_top', not self.caster_is_top)
        target_prefix = 'top_paddle' if target_is_top else 'bottom_paddle'
        game_state[f'{target_prefix}_knockback'] = True
        game_state[f'{target_prefix}_knockback_dir'] = knockback_dir
        game_state[f'{target_prefix}_knockback_vel'] = self.KNOCKBACK_VEL

        # 히트 사운드 (코만도 권총 피격음)
        try:
            project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            sound_path = os.path.join(project_root, "sounds", "bullethit.wav")
            if os.path.exists(sound_path):
                s = pygame.mixer.Sound(sound_path)
                s.set_volume(0.7)
                s.play()
        except Exception:
            pass

        # 히트 파티클 (뼈 파편 스타일)
        for _ in range(12):
            self.arrow_particles.append({
                'x': arrow['x'],
                'y': arrow['y'],
                'vx': random.uniform(-200, 200),
                'vy': random.uniform(-200, 200),
                'alpha': 200,
                'life': random.uniform(0.3, 0.6),
                'age': 0.0,
                'size': random.uniform(2, 5),
                'color': random.choice([
                    (220, 210, 180),  # 뼈 색
                    (180, 170, 140),  # 어두운 뼈
                    (200, 255, 200),  # 독 초록
                ]),
            })

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        pass  # 궁수가 다 죽으면 자동 비활성화

    def reset_for_new_round(self, game_state: dict):
        """라운드 전환 시 궁수는 유지, 화살/파티클만 정리"""
        # 궁수는 라운드가 넘어가도 필드에 계속 남아있음
        # is_active와 쿨타임만 리셋 (부모 호출 대신 직접 처리)
        self.active_timer = self.duration if self.archers else 0.0
        self.is_active = bool(self.archers)
        # 비행 중 화살과 파티클만 정리
        self.arrows = []
        self.arrow_particles = []
        self.dying_archers = []
        # 시위 당기는 중이면 취소
        for archer in self.archers:
            archer['is_drawing'] = False
            archer['draw_timer'] = 0.0
            archer['arrow_cooldown'] = random.uniform(
                self.ARROW_COOLDOWN_MIN, self.ARROW_COOLDOWN_MAX
            )

    def update(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        """스킬 업데이트 - 쿨타임 + 궁수/화살 동시 관리"""
        # 쿨타임 감소
        if self.current_cooldown > 0:
            self.current_cooldown -= dt
        if self.activation_flash_timer > 0:
            self.activation_flash_timer -= dt

        # 활성 효과 업데이트 (궁수가 존재하는 한)
        if self.is_active:
            self._update_active_effect(dt, caster_paddle, target_paddle, ball, game_state)
            # active_timer는 무시 (_update_active_effect에서 자체 비활성화)

        # dying_archers는 is_active 관계없이 업데이트
        if self.dying_archers and not self.is_active:
            new_dying = []
            for dying in self.dying_archers:
                dying['death_time'] += dt
                if dying['death_time'] < self.DEATH_DURATION:
                    new_dying.append(dying)
            self.dying_archers = new_dying

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        # --- 활성 궁수 그리기 ---
        for archer in self.archers:
            self._draw_archer(screen, archer)

        # --- 사망 궁수 그리기 ---
        for dying in self.dying_archers:
            self._draw_dying_archer(screen, dying)

        # --- 화살 그리기 ---
        for arrow in self.arrows:
            self._draw_arrow(screen, arrow)

        # --- 히트 파티클 그리기 ---
        for p in self.arrow_particles:
            if p['alpha'] > 5:
                pygame.draw.circle(screen, (*p['color'], int(p['alpha'])),
                                 (int(p['x']), int(p['y'])), int(p['size']))

    def _draw_archer(self, screen: pygame.Surface, archer: dict):
        """해골 궁수 Ultra Premium 렌더링 - 활을 상/하 방향으로 겨냥"""
        x = int(archer['x'])
        y = int(archer['y'] + archer['body_bob']) + 14

        t = archer['spawn_time']
        emerge_progress = min(1.0, t / self.EMERGE_DURATION)
        if emerge_progress < 1.0:
            alpha = int(240 * min(1.0, emerge_progress * 1.5))
        else:
            alpha = 240

        is_bottom = not self.caster_is_top
        aim_dir = -1 if is_bottom else 1

        surf_w, surf_h = 80, 100
        surf = _psurf((surf_w, surf_h), pygame.SRCALPHA)
        cx = surf_w // 2
        cy = 65

        # === 색상 정의 ===
        is_golden = archer.get('is_golden', False)
        if is_golden:
            bone_bright = (255, 235, 140, alpha)
            bone_color = (240, 210, 90, alpha)
            bone_shadow = (190, 160, 50, alpha)
            bone_dark = (150, 120, 30, alpha)
            bone_cream = (255, 245, 180, alpha)
            eye_glow = (255, 200, 50, alpha)
            eye_core = (255, 255, 180, alpha)
            soul_color = (255, 220, 80)
        else:
            bone_bright = (225, 218, 195, alpha)
            bone_color = (200, 195, 170, alpha)
            bone_shadow = (155, 145, 118, alpha)
            bone_dark = (120, 110, 90, alpha)
            bone_cream = (235, 228, 210, alpha)
            eye_glow = (80, 255, 120, alpha)
            eye_core = (180, 255, 200, alpha)
            soul_color = (100, 255, 130)

        def _assemble_offset(part_idx, total_parts=9):
            if emerge_progress >= 1.0:
                return 0, 0
            part_start = (part_idx / total_parts) * 0.4
            part_progress = max(0.0, min(1.0, (emerge_progress - part_start) / 0.6))
            ease = 1.0 - (1.0 - part_progress) ** 3
            angle = (part_idx / total_parts) * math.pi * 2 + part_idx * 1.3
            start_dist = 40 + part_idx * 8
            ox = int(math.cos(angle) * start_dist * (1.0 - ease))
            oy = int(math.sin(angle) * start_dist * (1.0 - ease))
            return ox, oy

        # === 후드/망토 (고퀄리티 - 천 질감 + 찢어진 가장자리) ===
        if is_golden:
            cloak_color = (100, 70, 20, int(alpha * 0.7))
            cloak_mid = (120, 85, 25, int(alpha * 0.5))
            cloak_edge = (140, 100, 30, int(alpha * 0.5))
        else:
            cloak_color = (50, 45, 35, int(alpha * 0.7))
            cloak_mid = (60, 55, 42, int(alpha * 0.55))
            cloak_edge = (70, 60, 45, int(alpha * 0.5))
        co = _assemble_offset(8)
        cloak_sway = int(3 * _sin(t * 2.5))
        cloak_sway2 = int(2 * _sin(t * 3.2 + 1.0))
        # 메인 망토
        pygame.draw.polygon(surf, cloak_color, [
            (cx - 9 + co[0], cy - 29 + co[1]),
            (cx + 9 + co[0], cy - 29 + co[1]),
            (cx + 13 + cloak_sway + co[0], cy + 10 + co[1]),
            (cx - 13 - cloak_sway + co[0], cy + 10 + co[1]),
        ])
        # 망토 내부 밝은 면 (주름 표현)
        pygame.draw.polygon(surf, cloak_mid, [
            (cx - 4 + co[0], cy - 27 + co[1]),
            (cx + 4 + co[0], cy - 27 + co[1]),
            (cx + 6 + cloak_sway2 + co[0], cy + 6 + co[1]),
            (cx - 6 - cloak_sway2 + co[0], cy + 6 + co[1]),
        ])
        # 찢어진 하단 (불규칙 패턴)
        for i in range(7):
            tear_x = cx - 12 + i * 4 + int(2 * _sin(t * 3 + i * 0.8)) + co[0]
            tear_base = cy + 8 + co[1]
            tear_len = 2 + (i % 3) * 2 + int(1 * _sin(t * 2.0 + i))
            pygame.draw.line(surf, cloak_edge, (tear_x, tear_base), (tear_x, tear_base + tear_len), 1)
        # 망토 테두리
        pygame.draw.line(surf, cloak_edge, (cx - 13 - cloak_sway + co[0], cy + 10 + co[1]),
                        (cx + 13 + cloak_sway + co[0], cy + 10 + co[1]), 1)

        # === 골반 (디테일 추가) ===
        po = _assemble_offset(4)
        pygame.draw.ellipse(surf, bone_shadow, (cx - 7 + po[0], cy + 1 + po[1], 14, 6))
        pygame.draw.ellipse(surf, bone_color, (cx - 6 + po[0], cy + 2 + po[1], 12, 4))
        pygame.draw.circle(surf, bone_bright, (cx + po[0], cy + 3 + po[1]), 1)

        # === 다리 (관절 디테일 강화) ===
        walk_phase = archer['step_phase'] if not archer['is_drawing'] else 0
        for side_idx, side in enumerate([-1, 1]):
            lo = _assemble_offset(5 + side_idx)
            hip_x = cx + side * 4 + lo[0]
            hip_y = cy + 5 + lo[1]
            leg_swing = _sin(walk_phase + (0 if side == 1 else math.pi)) * 4
            knee_x = hip_x + side * 2 + int(leg_swing * 0.5)
            knee_y = hip_y + 10
            foot_x = knee_x + int(leg_swing)
            foot_y = knee_y + 10
            # 대퇴골 (두꺼운 뼈 + 그림자)
            pygame.draw.line(surf, bone_shadow, (hip_x + 1, hip_y + 1), (knee_x + 1, knee_y + 1), 3)
            pygame.draw.line(surf, bone_color, (hip_x, hip_y), (knee_x, knee_y), 3)
            pygame.draw.line(surf, bone_cream, (hip_x, hip_y), ((hip_x + knee_x) // 2, (hip_y + knee_y) // 2), 1)
            # 경골
            pygame.draw.line(surf, bone_shadow, (knee_x + 1, knee_y + 1), (foot_x + 1, foot_y + 1), 2)
            pygame.draw.line(surf, bone_color, (knee_x, knee_y), (foot_x, foot_y), 2)
            # 무릎 관절 (돌기)
            pygame.draw.circle(surf, bone_bright, (knee_x, knee_y), 3)
            pygame.draw.circle(surf, bone_shadow, (knee_x, knee_y), 3, 1)
            pygame.draw.circle(surf, bone_cream, (knee_x - side, knee_y - 1), 1)
            # 발 (발가락 뼈)
            pygame.draw.line(surf, bone_color, (foot_x, foot_y), (foot_x + side * 3, foot_y + 1), 2)
            pygame.draw.line(surf, bone_shadow, (foot_x + side * 3, foot_y + 1), (foot_x + side * 5, foot_y), 1)

        # === 척추 (추체 + 극돌기 디테일) ===
        so = _assemble_offset(2)
        spine_top = cy - 28 + so[1]
        spine_bot = cy + 3 + so[1]
        spine_x = cx + so[0]
        # 척추 그림자
        pygame.draw.line(surf, bone_shadow, (spine_x + 1, spine_top + 1), (spine_x + 1, spine_bot + 1), 3)
        pygame.draw.line(surf, bone_color, (spine_x, spine_top), (spine_x, spine_bot), 3)
        # 하이라이트
        pygame.draw.line(surf, bone_cream, (spine_x - 1, spine_top), (spine_x - 1, spine_bot), 1)
        for i in range(6):
            vy = spine_top + (spine_bot - spine_top) * i / 5
            # 추체
            pygame.draw.circle(surf, bone_bright, (spine_x, int(vy)), 2)
            pygame.draw.circle(surf, bone_shadow, (spine_x, int(vy)), 2, 1)
            # 극돌기 (등쪽 돌출)
            pygame.draw.line(surf, bone_shadow, (spine_x, int(vy)), (spine_x + 3, int(vy) - 1), 1)

        # === 갈비뼈 (곡선형 + 음영) ===
        ro = _assemble_offset(3)
        rib_ys = [cy - 24, cy - 19, cy - 14, cy - 9]
        rib_widths = [9, 12, 11, 8]
        for i, (ry, rw) in enumerate(zip(rib_ys, rib_widths)):
            for side in [-1, 1]:
                p1 = (cx + side * 1 + ro[0], ry + ro[1])
                p2 = (cx + side * (rw - 2) + ro[0], ry + 2 + ro[1])
                p3 = (cx + side * rw + ro[0], ry + 4 + ro[1])
                # 갈비뼈 그림자
                pygame.draw.line(surf, bone_shadow, (p1[0] + 1, p1[1] + 1), (p2[0] + 1, p2[1] + 1), 2)
                pygame.draw.line(surf, bone_shadow, (p2[0] + 1, p2[1] + 1), (p3[0] + 1, p3[1] + 1), 1)
                # 갈비뼈 본체
                pygame.draw.line(surf, bone_color, p1, p2, 2)
                pygame.draw.line(surf, bone_color, p2, p3, 1)
                # 하이라이트 (윗면)
                if side == -1:
                    pygame.draw.line(surf, bone_cream, p1, ((p1[0] + p2[0]) // 2, (p1[1] + p2[1]) // 2), 1)

        # === 쇄골 ===
        pygame.draw.line(surf, bone_shadow, (cx - 10 + ro[0] + 1, cy - 25 + ro[1]),
                        (cx + 10 + ro[0] + 1, cy - 25 + ro[1]), 2)
        pygame.draw.line(surf, bone_bright, (cx - 10 + ro[0], cy - 26 + ro[1]),
                        (cx + 10 + ro[0], cy - 26 + ro[1]), 2)
        # 견갑 관절
        for side in [-1, 1]:
            pygame.draw.circle(surf, bone_bright, (cx + side * 10 + ro[0], cy - 26 + ro[1]), 2)

        # === 두개골 (고퀄리티 - 봉합선 + 균열 + 광대뼈) ===
        ho = _assemble_offset(0)
        skull_y = cy - 36 + ho[1]
        skull_x = cx + ho[0]
        # 두개골 그림자
        pygame.draw.ellipse(surf, bone_shadow, (skull_x - 10, skull_y - 9, 20, 17))
        # 두개골 본체
        pygame.draw.ellipse(surf, bone_color, (skull_x - 9, skull_y - 9, 18, 16))
        # 이마 하이라이트
        pygame.draw.ellipse(surf, bone_bright, (skull_x - 7, skull_y - 8, 10, 7))
        # 두개골 윤곽
        pygame.draw.ellipse(surf, bone_shadow, (skull_x - 9, skull_y - 9, 18, 16), 1)
        # 봉합선 (두개골 고유 패턴)
        suture_a = int(alpha * 0.3)
        pygame.draw.line(surf, (*bone_shadow[:3], suture_a), (skull_x, skull_y - 8), (skull_x, skull_y - 3), 1)
        pygame.draw.line(surf, (*bone_shadow[:3], suture_a), (skull_x - 4, skull_y - 5), (skull_x + 4, skull_y - 5), 1)
        # 광대뼈 돌출
        for side in [-1, 1]:
            pygame.draw.line(surf, bone_bright, (skull_x + side * 7, skull_y + 1),
                            (skull_x + side * 9, skull_y + 3), 1)

        # 눈구멍 (고퀄리티 - 깊은 구멍 + 발광 눈동자)
        for side in [-1, 1]:
            ex = skull_x + side * 4
            ey = skull_y - 1
            # 깊은 눈구멍
            pygame.draw.circle(surf, bone_dark, (ex, ey), 4)
            pygame.draw.circle(surf, (int(bone_dark[0] * 0.6), int(bone_dark[1] * 0.6), int(bone_dark[2] * 0.6), alpha), (ex, ey), 3)
            # 발광 눈동자
            pulse = 0.6 + 0.4 * _sin(t * 3.5 + side * 1.2)
            glow_r = int(2.5 * pulse)
            # 외곽 글로우
            glow_a = int(alpha * 0.3 * pulse)
            pygame.draw.circle(surf, (*eye_glow[:3], glow_a), (ex, ey), glow_r + 2)
            # 메인 글로우
            pygame.draw.circle(surf, eye_glow, (ex, ey), max(1, glow_r))
            # 코어 하이라이트
            if pulse > 0.7:
                pygame.draw.circle(surf, eye_core, (ex, ey - 1), 1)

        # 코구멍
        pygame.draw.circle(surf, bone_dark, (skull_x - 1, skull_y + 3), 1)
        pygame.draw.circle(surf, bone_dark, (skull_x + 1, skull_y + 3), 1)
        # 이빨 (불규칙)
        jaw_y = skull_y + 5
        tooth_heights = [1, 2, 3, 2, 3, 2, 1]
        for ti, th in enumerate(tooth_heights):
            tx = skull_x - 3 + ti
            pygame.draw.line(surf, bone_bright, (tx, jaw_y), (tx, jaw_y + th), 1)
        # 턱 라인
        pygame.draw.line(surf, bone_shadow, (skull_x - 5, jaw_y), (skull_x + 5, jaw_y), 1)
        pygame.draw.line(surf, bone_dark, (skull_x - 4, jaw_y + 1), (skull_x + 4, jaw_y + 2), 1)

        # === 후드 (디테일 강화 - 주름 + 봉제선) ===
        if is_golden:
            hood_color = (110, 80, 25, int(alpha * 0.8))
            hood_edge_color = (150, 110, 35, int(alpha * 0.6))
            hood_inner = (90, 65, 20, int(alpha * 0.5))
        else:
            hood_color = (55, 50, 38, int(alpha * 0.8))
            hood_edge_color = (80, 70, 50, int(alpha * 0.6))
            hood_inner = (42, 38, 28, int(alpha * 0.5))
        # 후드 본체
        pygame.draw.polygon(surf, hood_color, [
            (skull_x - 12, skull_y - 4), (skull_x + 12, skull_y - 4),
            (skull_x + 9, skull_y - 13), (skull_x, skull_y - 16), (skull_x - 9, skull_y - 13),
        ])
        # 후드 내부 (깊이감)
        pygame.draw.polygon(surf, hood_inner, [
            (skull_x - 9, skull_y - 5), (skull_x + 9, skull_y - 5),
            (skull_x + 6, skull_y - 11), (skull_x, skull_y - 13), (skull_x - 6, skull_y - 11),
        ])
        # 후드 테두리
        pygame.draw.lines(surf, hood_edge_color, False, [
            (skull_x - 12, skull_y - 4), (skull_x - 9, skull_y - 13),
            (skull_x, skull_y - 16), (skull_x + 9, skull_y - 13), (skull_x + 12, skull_y - 4),
        ], 1)
        # 후드 주름 라인
        pygame.draw.line(surf, hood_inner, (skull_x - 3, skull_y - 14), (skull_x - 5, skull_y - 5), 1)
        pygame.draw.line(surf, hood_inner, (skull_x + 3, skull_y - 14), (skull_x + 5, skull_y - 5), 1)

        # === 활과 팔 (Ultra Premium) ===
        if is_golden:
            bow_wood = (220, 180, 60, alpha)
            bow_dark = (180, 140, 30, alpha)
            bow_highlight = (255, 220, 100, alpha)
            bow_grip = (160, 120, 25, alpha)
            string_color = (255, 240, 170, alpha)
            string_glow = (255, 250, 200, int(alpha * 0.4))
            arrow_shaft = (240, 210, 100, alpha)
            arrowhead_color = (255, 200, 50, alpha)
            energy_color = (255, 220, 80)
        else:
            bow_wood = (160, 110, 55, alpha)
            bow_dark = (120, 80, 40, alpha)
            bow_highlight = (190, 140, 70, alpha)
            bow_grip = (100, 70, 35, alpha)
            string_color = (210, 200, 170, alpha)
            string_glow = (180, 220, 170, int(alpha * 0.3))
            arrow_shaft = (200, 190, 160, alpha)
            arrowhead_color = (140, 180, 120, alpha)
            energy_color = (80, 255, 120)

        ao = _assemble_offset(1)

        if archer['is_drawing'] and emerge_progress >= 1.0:
            draw_progress = min(1.0, archer['draw_timer'] / self.ARROW_DRAW_TIME)
            bow_side = 1 if archer['vx'] >= 0 else -1

            # 활 잡는 팔
            shoulder_x = cx + bow_side * 5
            shoulder_y = cy - 24
            hand_x = cx + bow_side * 8
            hand_y = cy - 28 + aim_dir * (-14)
            elbow_x = (shoulder_x + hand_x) // 2 + bow_side * 3
            elbow_y = (shoulder_y + hand_y) // 2

            pygame.draw.line(surf, bone_shadow, (shoulder_x + 1, shoulder_y + 1), (elbow_x + 1, elbow_y + 1), 2)
            pygame.draw.line(surf, bone_color, (shoulder_x, shoulder_y), (elbow_x, elbow_y), 2)
            pygame.draw.line(surf, bone_shadow, (elbow_x + 1, elbow_y + 1), (hand_x + 1, hand_y + 1), 2)
            pygame.draw.line(surf, bone_color, (elbow_x, elbow_y), (hand_x, hand_y), 2)
            pygame.draw.circle(surf, bone_bright, (elbow_x, elbow_y), 2)
            pygame.draw.circle(surf, bone_shadow, (elbow_x, elbow_y), 2, 1)

            # === 활 (Ultra Premium - 곡선 + 그립 + 장식 + 룬) ===
            bow_half = 15
            bow_top_y = hand_y - bow_half
            bow_bot_y = hand_y + bow_half
            bow_curve = bow_side * 9

            # 활 곡선 포인트 (더 부드럽게 - 13포인트)
            points_bow = []
            for bi in range(13):
                bt = bi / 12.0
                by_pos = bow_top_y + (bow_bot_y - bow_top_y) * bt
                curve_val = _sin(bt * math.pi)
                # 활의 양쪽 끝이 안쪽으로 살짝 휘는 리커브 형태
                recurve = 0
                if bt < 0.15 or bt > 0.85:
                    recurve = -bow_side * 2 * (1.0 - min(bt, 1.0 - bt) / 0.15)
                bx_pos = hand_x + int(bow_curve * curve_val) + int(recurve)
                points_bow.append((bx_pos, int(by_pos)))

            if len(points_bow) > 2:
                # 활 그림자
                shadow_pts = [(p[0] + 1, p[1] + 1) for p in points_bow]
                pygame.draw.lines(surf, bone_shadow, False, shadow_pts, 4)
                # 활 외곽 (진한)
                pygame.draw.lines(surf, bow_dark, False, points_bow, 3)
                # 활 본체
                pygame.draw.lines(surf, bow_wood, False, points_bow, 2)
                # 활 하이라이트 (안쪽 면)
                inner_pts = [(p[0] - bow_side, p[1]) for p in points_bow[2:-2]]
                if len(inner_pts) >= 2:
                    pygame.draw.lines(surf, bow_highlight, False, inner_pts, 1)

            # 그립 감기 (손잡이 부분)
            grip_center = len(points_bow) // 2
            for gi in range(-2, 3):
                gi_idx = grip_center + gi
                if 0 <= gi_idx < len(points_bow):
                    gx, gy = points_bow[gi_idx]
                    pygame.draw.line(surf, bow_grip, (gx - bow_side, gy - 1), (gx + bow_side, gy + 1), 1)

            # 활 끝 장식 (뿔/뼈 장식)
            for tip_idx in [0, -1]:
                tx, ty = points_bow[tip_idx]
                pygame.draw.circle(surf, bow_highlight, (tx, ty), 3)
                pygame.draw.circle(surf, bow_dark, (tx, ty), 3, 1)
                pygame.draw.circle(surf, bow_highlight, (tx, ty), 1)

            # 활 룬 마크 (에너지 문양)
            if draw_progress > 0.3:
                rune_a = int(alpha * 0.3 * draw_progress)
                for ri in range(3):
                    ri_idx = 3 + ri * 3
                    if ri_idx < len(points_bow):
                        rx, ry = points_bow[ri_idx]
                        pygame.draw.circle(surf, (*energy_color, rune_a), (rx, ry), 1)

            # === 시위 (에너지 충전 글로우 포함) ===
            pull_dist = int(14 * draw_progress)
            pull_x = hand_x - bow_side * pull_dist
            pull_y = hand_y

            # 시위 글로우 (에너지 충전 시)
            if draw_progress > 0.4:
                glow_a = int(alpha * 0.2 * (draw_progress - 0.4) / 0.6)
                pygame.draw.line(surf, string_glow, points_bow[0], (pull_x, pull_y), 2)
                pygame.draw.line(surf, string_glow, points_bow[-1], (pull_x, pull_y), 2)
            # 시위 본체
            pygame.draw.line(surf, string_color, points_bow[0], (pull_x, pull_y), 1)
            pygame.draw.line(surf, string_color, points_bow[-1], (pull_x, pull_y), 1)

            # 시위 당기는 팔
            pull_shoulder_x = cx - bow_side * 3
            pull_shoulder_y = cy - 22
            pull_elbow_x = pull_shoulder_x
            pull_elbow_y = (pull_shoulder_y + pull_y) // 2
            pygame.draw.line(surf, bone_shadow, (pull_shoulder_x + 1, pull_shoulder_y + 1), (pull_elbow_x + 1, pull_elbow_y + 1), 2)
            pygame.draw.line(surf, bone_color, (pull_shoulder_x, pull_shoulder_y), (pull_elbow_x, pull_elbow_y), 2)
            pygame.draw.line(surf, bone_color, (pull_elbow_x, pull_elbow_y), (pull_x, pull_y), 2)
            pygame.draw.circle(surf, bone_bright, (pull_elbow_x, pull_elbow_y), 2)
            pygame.draw.circle(surf, bone_color, (pull_x, pull_y), 2)

            # === 화살 (Ultra Premium - 시위에 얹힌 상태) ===
            if draw_progress > 0.15:
                arrow_tip_x = hand_x
                arrow_tip_y = hand_y + aim_dir * 20
                # 화살대 그림자
                pygame.draw.line(surf, bone_shadow, (pull_x + 1, pull_y + 1), (arrow_tip_x + 1, arrow_tip_y + 1), 2)
                # 화살대 본체
                pygame.draw.line(surf, arrow_shaft, (pull_x, pull_y), (arrow_tip_x, arrow_tip_y), 2)
                # 화살대 하이라이트
                mid_ax = (pull_x + arrow_tip_x) // 2
                mid_ay = (pull_y + arrow_tip_y) // 2
                pygame.draw.line(surf, bone_cream, (pull_x, pull_y), (mid_ax, mid_ay), 1)
                # 화살촉 (더 날카롭게)
                pygame.draw.polygon(surf, arrowhead_color, [
                    (arrow_tip_x, arrow_tip_y + aim_dir * 6),
                    (arrow_tip_x - 3, arrow_tip_y - aim_dir * 1),
                    (arrow_tip_x + 3, arrow_tip_y - aim_dir * 1),
                ])
                # 화살촉 하이라이트
                pygame.draw.line(surf, bow_highlight, (arrow_tip_x, arrow_tip_y + aim_dir * 5),
                                (arrow_tip_x - 1, arrow_tip_y), 1)
                # 깃털 (3장 - 더 디테일하게)
                feather_colors = [
                    (80, 70, 55, alpha),
                    (70, 62, 48, int(alpha * 0.8)),
                    (90, 78, 60, int(alpha * 0.7)),
                ]
                for fi, fc in enumerate(feather_colors):
                    fx_off = [-3, 0, 3][fi]
                    fy_off = [0, -1, 0][fi]
                    pygame.draw.line(surf, fc,
                                   (pull_x + fx_off, pull_y + fy_off),
                                   (pull_x + fx_off - bow_side, pull_y - aim_dir * 5 + fy_off), 1)
                # 독/에너지 파티클
                if draw_progress > 0.5 and random.random() < 0.35:
                    for _ in range(2):
                        pygame.draw.circle(surf, (*energy_color, int(alpha * 0.5)),
                                         (arrow_tip_x + random.randint(-3, 3),
                                          arrow_tip_y + aim_dir * random.randint(1, 5)), 1)
                # 에너지 충전 이펙트 (화살촉 주변)
                if draw_progress > 0.7:
                    charge_a = int(alpha * 0.3 * (draw_progress - 0.7) / 0.3)
                    pygame.draw.circle(surf, (*energy_color, charge_a),
                                     (arrow_tip_x, arrow_tip_y + aim_dir * 3), 4)
        else:
            # === 대기 포즈 (디테일 강화) ===
            dir_sign = 1 if archer['vx'] >= 0 else -1
            shoulder_x = cx + dir_sign * 3 + ao[0]
            shoulder_y = cy - 24 + ao[1]
            hand_x = cx + dir_sign * 10 + ao[0]
            hand_y = cy - 10 + ao[1]
            # 팔
            pygame.draw.line(surf, bone_shadow, (shoulder_x + 1, shoulder_y + 1), (hand_x + 1, hand_y + 1), 2)
            pygame.draw.line(surf, bone_color, (shoulder_x, shoulder_y), (hand_x, hand_y), 2)
            # 활 (세로로 들고 있음 - 디테일 추가)
            bow_rest_top = hand_y - 16
            bow_rest_bot = hand_y + 8
            # 활 그림자
            pygame.draw.line(surf, bow_dark, (hand_x + 1, bow_rest_top + 1), (hand_x + 1, bow_rest_bot + 1), 3)
            # 활 본체
            pygame.draw.line(surf, bow_wood, (hand_x, bow_rest_top), (hand_x, bow_rest_bot), 2)
            # 활 하이라이트
            pygame.draw.line(surf, bow_highlight, (hand_x - 1, bow_rest_top + 2), (hand_x - 1, bow_rest_bot - 2), 1)
            # 시위
            pygame.draw.line(surf, string_color, (hand_x - dir_sign * 2, bow_rest_top), (hand_x - dir_sign * 2, bow_rest_bot), 1)
            # 활 끝 장식
            pygame.draw.circle(surf, bow_highlight, (hand_x, bow_rest_top), 2)
            pygame.draw.circle(surf, bow_highlight, (hand_x, bow_rest_bot), 2)
            # 반대팔
            other_x = cx - dir_sign * 3 + ao[0]
            other_hx = cx - dir_sign * 6 + ao[0]
            other_hy = cy - 8 + ao[1]
            pygame.draw.line(surf, bone_color, (other_x, shoulder_y), (other_hx, other_hy), 2)

        # === 바닥 그림자 (더 부드럽게) ===
        shadow_w = 32
        shadow_h = 10
        shadow_surf = _psurf((shadow_w, shadow_h), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_surf, (12, 16, 10, int(alpha * 0.2)), (0, 0, shadow_w, shadow_h))
        pygame.draw.ellipse(shadow_surf, (18, 22, 14, int(alpha * 0.12)), (3, 2, shadow_w - 6, shadow_h - 4))
        screen.blit(shadow_surf, (x - shadow_w // 2, int(archer['y']) + 30))

        # === 궁수 블릿 ===
        screen.blit(surf, (x - surf_w // 2, y - 65))

        # === 조립 중 초록 에너지 이펙트 (강화) ===
        if emerge_progress < 1.0:
            num_sparks = int(16 * (1.0 - emerge_progress))
            for i in range(num_sparks):
                spark_angle = (i / max(1, num_sparks)) * math.pi * 2 + t * 8
                spark_dist = int(35 * (1.0 - emerge_progress))
                sx = x + int(math.cos(spark_angle) * spark_dist)
                sy = y - 20 + int(math.sin(spark_angle) * spark_dist)
                spark_alpha = int(200 * (1.0 - emerge_progress))
                s_size = random.randint(1, 3)
                pygame.draw.circle(screen, (*soul_color, spark_alpha), (sx, sy), s_size)
                # 스파크 글로우
                if s_size >= 2:
                    pygame.draw.circle(screen, (*soul_color, spark_alpha // 3), (sx, sy), s_size + 2)
            # 수렴 라인
            if emerge_progress > 0.3:
                for i in range(6):
                    la = i * math.pi / 3 + t * 3
                    ldist = int(30 * (1.0 - emerge_progress))
                    lx = x + int(math.cos(la) * ldist)
                    ly = y - 20 + int(math.sin(la) * ldist)
                    line_alpha = int(140 * (1.0 - emerge_progress))
                    pygame.draw.line(screen, (*soul_color, line_alpha), (lx, ly), (x, y - 20), 1)
            # 마법진 (바닥에 소환진)
            if emerge_progress > 0.1 and emerge_progress < 0.8:
                circle_a = int(100 * (1.0 - abs(emerge_progress - 0.4) / 0.4))
                circle_r = int(20 * min(1.0, emerge_progress * 3))
                pygame.draw.circle(screen, (*soul_color, circle_a), (x, int(archer['y']) + 32), circle_r, 1)

        # === 소울 파티클 (완성 후 상시 - 강화) ===
        if emerge_progress >= 1.0:
            # 눈에서 나오는 소울 파티클
            if random.random() < 0.25:
                eye_side = random.choice([-1, 1])
                px = x + eye_side * 4 + random.randint(-2, 2)
                py = y - 38 + random.randint(-6, 0)
                p_alpha = random.randint(50, 120)
                p_size = random.randint(1, 3)
                pygame.draw.circle(screen, (*soul_color, p_alpha), (px, py), p_size)
                if p_size >= 2:
                    pygame.draw.circle(screen, (*soul_color, p_alpha // 3), (px, py), p_size + 2)
            # 몸 주위 떠다니는 소울
            if random.random() < 0.1:
                px = x + random.randint(-14, 14)
                py = y - random.randint(10, 50)
                pygame.draw.circle(screen, (*soul_color, random.randint(30, 90)),
                                 (px, py), random.randint(1, 2))
            # 바닥 네크로 에너지
            if random.random() < 0.06:
                gx = x + random.randint(-12, 12)
                gy = int(archer['y']) + 28 + random.randint(-2, 4)
                pygame.draw.circle(screen, (*soul_color, random.randint(20, 50)),
                                 (gx, gy), random.randint(1, 2))
            # 황금 궁수 전용: 빛나는 오라
            if is_golden and random.random() < 0.18:
                glow_angle = random.uniform(0, math.pi * 2)
                glow_dist = random.randint(8, 20)
                gx = x + int(math.cos(glow_angle) * glow_dist)
                gy = y - 25 + int(math.sin(glow_angle) * glow_dist)
                g_a = random.randint(35, 80)
                pygame.draw.circle(screen, (255, 215, 50, g_a), (gx, gy), random.randint(1, 3))
                pygame.draw.circle(screen, (255, 215, 50, g_a // 3), (gx, gy), random.randint(3, 5))

    def _draw_dying_archer(self, screen: pygame.Surface, dying: dict):
        """사망 애니메이션 - 뼈 파편이 물리 기반으로 사방에 흩어짐 + 영혼 이탈"""
        progress = dying['death_time'] / self.DEATH_DURATION
        alpha = int(240 * (1.0 - progress))
        x = int(dying['x'])
        y = int(dying['y']) + 14
        dt_frame = 1.0 / 60.0  # 프레임 기반 물리

        if alpha <= 10:
            return

        fragments = dying.get('fragments', [])

        # === 뼈 파편 물리 업데이트 + 렌더링 ===
        for frag in fragments:
            # 물리 업데이트 (간단한 중력 + 감쇠)
            frag['x'] += frag['vx'] * dt_frame
            frag['y'] += frag['vy'] * dt_frame
            frag['vy'] += 200 * dt_frame  # 중력
            frag['vx'] *= 0.98  # 공기 저항
            frag['rot'] += frag['rot_speed'] * dt_frame

            bx = int(frag['x'])
            by = int(frag['y'])
            bone_len = frag['length']
            rot = frag['rot']

            ex = bx + int(math.cos(rot) * bone_len)
            ey = by + int(math.sin(rot) * bone_len)

            if frag.get('is_bow'):
                # 활 파편 (갈색)
                color = (140, 100, 60, alpha)
                pygame.draw.line(screen, color, (bx, by), (ex, ey), 2)
                # 시위 조각
                mid_x = (bx + ex) // 2 + int(3 * _sin(rot))
                mid_y = (by + ey) // 2
                pygame.draw.line(screen, (200, 200, 170, int(alpha * 0.6)),
                               (bx, by), (mid_x, mid_y), 1)
            else:
                # 뼈 파편
                pygame.draw.line(screen, (200, 195, 170, alpha), (bx, by), (ex, ey), 2)
                # 관절 점
                pygame.draw.circle(screen, (225, 218, 195, int(alpha * 0.7)), (bx, by), 2)
                # 뼈 하이라이트
                pygame.draw.line(screen, (230, 225, 205, int(alpha * 0.5)), (bx, by), (ex, ey), 1)

        # === 충격파 (사망 순간) ===
        if progress < 0.3:
            wave_r = int(40 * progress / 0.3)
            wave_alpha = int(150 * (1.0 - progress / 0.3))
            pygame.draw.circle(screen, (100, 255, 130, wave_alpha),
                             (x, y - 20), wave_r, 2)

        # === 두개골 잔해 (중앙에서 느리게 위로) ===
        if progress < 0.8:
            skull_y_off = int(20 * progress)
            skull_alpha = int(alpha * (1.0 - progress / 0.8))
            skull_rot = progress * 5
            skull_x = x + int(5 * _sin(skull_rot))
            skull_y_pos = y - 30 - skull_y_off
            # 깨진 두개골
            pygame.draw.arc(screen, (200, 195, 170, skull_alpha),
                          (skull_x - 6, skull_y_pos - 6, 12, 12),
                          0, math.pi, 2)
            # 한쪽 눈만 남은 초록 빛
            eye_alpha = int(skull_alpha * 0.8)
            if eye_alpha > 10:
                pygame.draw.circle(screen, (80, 255, 120, eye_alpha),
                                 (skull_x - 2, skull_y_pos - 1), 2)

        # === 초록 영혼 이탈 (위로 떠오르며 소멸) ===
        num_souls = int(8 + 12 * progress)
        for j in range(num_souls):
            soul_angle = j * 0.55 + progress * 6
            soul_dist = int(8 + 15 * progress + 5 * _sin(soul_angle))
            sx = x + int(math.cos(soul_angle) * soul_dist * 0.7) + random.randint(-2, 2)
            sy = y - 20 - int(50 * progress) + int(8 * _sin(soul_angle * 2)) + random.randint(-2, 2)
            soul_alpha = int(alpha * 0.5 * (0.5 + 0.5 * _sin(j + progress * 10)))
            if soul_alpha > 5:
                size = random.randint(1, 3)
                pygame.draw.circle(screen, (100, 255, 130, soul_alpha), (sx, sy), size)

        # === 뼈 먼지 (바닥 근처) ===
        if progress > 0.3:
            dust_count = int(6 * (progress - 0.3))
            for di in range(dust_count):
                dx = x + random.randint(-25, 25)
                dy = y + random.randint(-5, 10)
                dust_alpha = int(80 * (1.0 - progress))
                if dust_alpha > 5:
                    pygame.draw.circle(screen, (180, 170, 140, dust_alpha), (dx, dy), 1)

    def _draw_arrow(self, screen: pygame.Surface, arrow: dict):
        """화살 렌더링 - 길쭉하고 날렵한 화살 디자인"""
        x = int(arrow['x'])
        y = int(arrow['y'])
        angle = arrow['angle']
        cos_a = math.cos(angle)
        sin_a = math.sin(angle)
        perp_cos = math.cos(angle + math.pi / 2)
        perp_sin = math.sin(angle + math.pi / 2)
        is_golden = arrow.get('is_golden', False)
        t_now = pygame.time.get_ticks() / 1000.0

        if is_golden:
            shaft_dark = (200, 170, 50)
            shaft_mid = (230, 200, 75)
            shaft_light = (255, 230, 100)
            head_outer = (220, 180, 40)
            head_inner = (255, 220, 80)
            head_edge = (180, 150, 30)
            feather_colors = [(160, 120, 25), (200, 160, 40), (220, 180, 50)]
            trail_color = (255, 200, 50)
            drip_color = (255, 220, 80)
            energy_color = (255, 230, 100)
        else:
            shaft_dark = (170, 162, 140)
            shaft_mid = (190, 182, 158)
            shaft_light = (210, 200, 178)
            head_outer = (90, 150, 80)
            head_inner = (120, 190, 100)
            head_edge = (70, 120, 60)
            feather_colors = [(60, 52, 42), (80, 70, 55), (90, 80, 65)]
            trail_color = (80, 220, 100)
            drip_color = (80, 220, 100)
            energy_color = (100, 255, 130)

        # 화살 전체 길이 계산 (긴 비율)
        shaft_len = self.ARROW_LENGTH  # 화살대 길이
        head_len = 6                    # 화살촉 길이
        # 화살촉 끝 좌표
        tip_x = x + int(cos_a * head_len)
        tip_y = y + int(sin_a * head_len)
        # 화살대 끝(꼬리) 좌표
        tail_x = x - int(cos_a * shaft_len)
        tail_y = y - int(sin_a * shaft_len)

        # === 에너지 트레일 (가느다란 줄기형) ===
        for i in range(6):
            trail_t = (i + 1) * 0.15
            tx = int(arrow['x'] - arrow['vx'] * trail_t)
            ty = int(arrow['y'] - arrow['vy'] * trail_t)
            trail_alpha = 90 - i * 14
            if trail_alpha > 0:
                pygame.draw.circle(screen, (*trail_color, trail_alpha), (tx, ty), 1)

        # === 바람 효과 라인 (얇고 짧은 공기 흐름) ===
        for wi in range(2):
            w_off = (2 + wi) * (1 if wi % 2 == 0 else -1)
            w_sx = x - int(cos_a * (6 + wi * 5)) + int(perp_cos * w_off)
            w_sy = y - int(sin_a * (6 + wi * 5)) + int(perp_sin * w_off)
            w_ex = w_sx - int(cos_a * 5)
            w_ey = w_sy - int(sin_a * 5)
            pygame.draw.line(screen, (*energy_color, 40), (w_sx, w_sy), (w_ex, w_ey), 1)

        # === 화살대 (가느다란 1~2px 라인) ===
        # 그림자 (1px 오프셋)
        pygame.draw.line(screen, shaft_dark,
                         (tail_x + 1, tail_y + 1), (x + 1, y + 1), 1)
        # 본체 (2px - 날렵한 화살대)
        pygame.draw.line(screen, shaft_mid, (tail_x, tail_y), (x, y), 2)
        # 하이라이트 (중앙 1px 밝은 선)
        hl_start_x = tail_x + int(cos_a * 2)
        hl_start_y = tail_y + int(sin_a * 2)
        hl_end_x = x - int(cos_a * 1)
        hl_end_y = y - int(sin_a * 1)
        pygame.draw.line(screen, shaft_light, (hl_start_x, hl_start_y), (hl_end_x, hl_end_y), 1)

        # === 화살촉 (좁고 날카로운 삼각형) ===
        # 촉 좌우 폭 = ±2.5px (매우 날렵)
        wing_w = 2.5
        wing_back = 1  # 뒤로 살짝 꺾임
        left_x = x + int(perp_cos * wing_w) - int(cos_a * wing_back)
        left_y = y + int(perp_sin * wing_w) - int(sin_a * wing_back)
        right_x = x - int(perp_cos * wing_w) - int(cos_a * wing_back)
        right_y = y - int(perp_sin * wing_w) - int(sin_a * wing_back)
        # 촉 본체 (날카로운 삼각형)
        pygame.draw.polygon(screen, head_outer, [
            (tip_x, tip_y), (left_x, left_y), (right_x, right_y)
        ])
        # 촉 하이라이트 (한쪽 면)
        pygame.draw.polygon(screen, head_inner, [
            (tip_x, tip_y),
            (left_x, left_y),
            (x, y),
        ])
        # 촉 테두리 (날카로움 강조)
        pygame.draw.lines(screen, head_edge, True, [
            (tip_x, tip_y), (left_x, left_y), (right_x, right_y)
        ], 1)
        # 촉 중앙 능선
        pygame.draw.line(screen, head_inner, (x, y), (tip_x, tip_y), 1)

        # === 깃털 (2장 - 좁고 날렵한 V자 배치) ===
        for side in [-1, 1]:
            # 깃털: 꼬리에서 뒤쪽-옆으로 뻗는 얇은 삼각형
            f_base_x = tail_x + int(cos_a * 1)
            f_base_y = tail_y + int(sin_a * 1)
            f_tip_x = tail_x - int(cos_a * 5) + int(perp_cos * side * 2.5)
            f_tip_y = tail_y - int(sin_a * 5) + int(perp_sin * side * 2.5)
            f_edge_x = tail_x - int(cos_a * 3) + int(perp_cos * side * 0.5)
            f_edge_y = tail_y - int(sin_a * 3) + int(perp_sin * side * 0.5)
            # 깃털 면
            f_col = feather_colors[0] if side == -1 else feather_colors[1]
            pygame.draw.polygon(screen, f_col, [
                (f_base_x, f_base_y), (f_edge_x, f_edge_y), (f_tip_x, f_tip_y)
            ])
            # 깃대 (중심선)
            pygame.draw.line(screen, feather_colors[2],
                           (f_base_x, f_base_y), (f_tip_x, f_tip_y), 1)

        # 노크 (화살 끝 작은 점)
        pygame.draw.circle(screen, shaft_dark, (tail_x, tail_y), 1)

        # === 황금 화살 글로우 ===
        if is_golden:
            glow_surf = _psurf((20, 20), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (255, 220, 80, 25), (10, 10), 10)
            pygame.draw.circle(glow_surf, (255, 240, 120, 15), (10, 10), 5)
            screen.blit(glow_surf, (x - 10, y - 10), special_flags=pygame.BLEND_ADD)

        # === 독/에너지 방울 (촉에서 한 방울) ===
        if random.random() < 0.15:
            drip_x = tip_x + random.randint(-1, 1)
            drip_y = tip_y + random.randint(1, 3)
            pygame.draw.circle(screen, (*drip_color, 120), (drip_x, drip_y), 1)


# ============================================================================
# 네크로 (Necro) - 뼈 장막 스킬
# ============================================================================

class BoneBarrier(HeroSkill):
    """뼈 장막 - 내 진영에 날카로운 뼈 장벽을 건설한다.
    건설 3초, 건설 중 공에 맞으면 파괴(반사 없음), 완성 후 공 1회 반사 후 파괴.
    라운드를 넘겨도 유지, 겹쳐서 건설 불가(간격 필요).
    """

    BARRIER_WIDTH = 120
    BARRIER_HEIGHT = 12
    BUILD_TIME = 3.0
    DEATH_DURATION = 0.6
    MIN_SPACING = 110       # 장벽 간 최소 거리

    def __init__(self):
        super().__init__(
            skill_id="bone_barrier",
            name="Bone Barrier",
            korean_name="뼈 장막",
            description="날카로운 뼈의 장벽이 진영을 감싸 공을 되돌려보낸다",
            trigger=SkillTrigger.ON_COOLDOWN,
            cooldown=21.0,
            duration=999999.0,
            hero_id="necro"
        )
        self.barriers = []
        self.dying_barriers = []
        self.caster_is_top = False
        self._next_id = 0

    # ------------------------------------------------------------------
    def can_use(self) -> bool:
        return self.current_cooldown <= 0

    def use(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        if not self.can_use():
            return {}
        self.caster_is_top = getattr(caster_paddle, 'is_top', False)
        if self.caster_is_top:
            skill_cd_mult = game_state.get('perk_skill_cd_mult_top', 1.0)
        else:
            skill_cd_mult = game_state.get('perk_skill_cd_mult_bottom', 1.0)
        self.current_cooldown = self.cooldown * skill_cd_mult
        self.activation_flash_timer = 1.5  # 발동 이펙트 1.5초
        self.is_active = True
        self.active_timer = self.duration
        return self._apply_effect(caster_paddle, target_paddle, ball, game_state)

    # ------------------------------------------------------------------
    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        self.caster_is_top = getattr(caster_paddle, 'is_top', False)

        # 뒷벽 Y 좌표 (영웅 뒤쪽 벽 = 공이 넘어가면 실점하는 벽)
        if self.caster_is_top:
            new_y = 8   # 천장 쪽 (상단 영웅 뒷벽)
        else:
            new_y = 738  # 바닥 쪽 (하단 영웅 뒷벽)

        # 겹침 방지: 기존 장벽과 X축 간격 확인하며 위치 탐색
        placed = False
        new_x = 0
        for _ in range(30):
            nx = random.randint(self.GAME_LEFT + 10, self.GAME_RIGHT - self.BARRIER_WIDTH - 10)
            too_close = False
            for b in self.barriers:
                if b['alive']:
                    dx = abs((nx + self.BARRIER_WIDTH / 2) - (b['x'] + b['width'] / 2))
                    if dx < self.MIN_SPACING:
                        too_close = True
                        break
            if not too_close:
                new_x = nx
                placed = True
                break

        if not placed:
            new_x = random.randint(self.GAME_LEFT + 10, self.GAME_RIGHT - self.BARRIER_WIDTH - 10)

        # 뼈 조각 생성 (조립 애니메이션용)
        num_bones = random.randint(10, 14)
        bone_segments = []
        for i in range(num_bones):
            final_x = new_x + (i / max(1, num_bones - 1)) * self.BARRIER_WIDTH
            final_y = new_y
            scatter_angle = random.uniform(0, math.pi * 2)
            scatter_dist = random.uniform(50, 120)
            bone_segments.append({
                'start_x': final_x + math.cos(scatter_angle) * scatter_dist,
                'start_y': final_y + math.sin(scatter_angle) * scatter_dist,
                'final_x': final_x,
                'final_y': final_y,
                'start_rot': random.uniform(0, math.pi * 2),
                'final_rot': random.uniform(-0.15, 0.15),
                'length': random.randint(8, 14),
                'delay': i * 0.04 + random.uniform(0, 0.15),
            })

        # 완성 시 스파이크 높이 미리 계산 (draw 시 일관성)
        num_spikes = self.BARRIER_WIDTH // 14
        spike_heights = [random.randint(5, 10) for _ in range(num_spikes)]

        barrier = {
            'id': self._next_id,
            'x': float(new_x),
            'y': float(new_y),
            'width': self.BARRIER_WIDTH,
            'height': self.BARRIER_HEIGHT,
            'build_timer': 0.0,
            'built': False,
            'alive': True,
            'bone_segments': bone_segments,
            'spike_heights': spike_heights,
            'is_top': self.caster_is_top,
        }
        self.barriers.append(barrier)
        self._next_id += 1

        # 뼈 장막 건설 시작 사운드
        try:
            project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            sound_path = os.path.join(project_root, "sounds", "bonemake3.wav")
            if os.path.exists(sound_path):
                s = pygame.mixer.Sound(sound_path)
                s.set_volume(0.7)
                s.play()
        except Exception:
            pass

        return {
            'screen_effect': ScreenEffect.FLASH,
            'flash_color': (180, 170, 130),
            'flash_duration': 0.1,
        }

    # ------------------------------------------------------------------
    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        new_barriers = []

        for barrier in self.barriers:
            if not barrier['alive']:
                continue

            barrier['build_timer'] += dt

            # 건설 완료 체크
            if not barrier['built'] and barrier['build_timer'] >= self.BUILD_TIME:
                barrier['built'] = True

            # 공 충돌 체크
            if ball is not None:
                bx = int(ball.x)
                by = int(ball.y)
                bw = int(ball.width)
                bh = int(ball.height)
                ball_rect = pygame.Rect(bx, by, bw, bh)
                br_x = int(barrier['x'])
                br_y = int(barrier['y'] - barrier['height'] / 2)
                barrier_rect = pygame.Rect(br_x, br_y, int(barrier['width']), int(barrier['height']))

                if ball_rect.colliderect(barrier_rect):
                    if barrier['built']:
                        # 완성된 장벽: 공 반사 후 파괴
                        ball_cy = ball.y + ball.height / 2
                        barrier_cy = barrier['y']
                        if ball_cy < barrier_cy:
                            ball.vy = -abs(ball.vy) * 1.05
                        else:
                            ball.vy = abs(ball.vy) * 1.05
                        # 약간의 X 편향
                        hit_offset = (ball.x + ball.width / 2) - (barrier['x'] + barrier['width'] / 2)
                        ball.vx += hit_offset * 0.03

                        barrier['alive'] = False
                        self._spawn_death_fragments(barrier)
                        try:
                            project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                            sound_path = os.path.join(project_root, "sounds", "bonebreak.wav")
                            if os.path.exists(sound_path):
                                snd = pygame.mixer.Sound(sound_path)
                                snd.set_volume(0.7)
                                snd.play()
                        except Exception:
                            pass
                        continue
                    else:
                        # 건설 중: 반사 없이 파괴
                        barrier['alive'] = False
                        self._spawn_death_fragments(barrier)
                        try:
                            project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                            sound_path = os.path.join(project_root, "sounds", "shurikenhit.wav")
                            if os.path.exists(sound_path):
                                snd = pygame.mixer.Sound(sound_path)
                                snd.set_volume(0.3)
                                snd.play()
                        except Exception:
                            pass
                        continue

            new_barriers.append(barrier)

        self.barriers = new_barriers

        # 파괴 애니메이션 업데이트
        new_dying = []
        for d in self.dying_barriers:
            d['death_time'] += dt
            if d['death_time'] < self.DEATH_DURATION:
                new_dying.append(d)
        self.dying_barriers = new_dying

    # ------------------------------------------------------------------
    def _spawn_death_fragments(self, barrier):
        frags = []
        for _ in range(12):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(60, 180)
            frags.append({
                'x': barrier['x'] + random.uniform(0, barrier['width']),
                'y': barrier['y'],
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed - 50,
                'rot': random.uniform(0, math.pi * 2),
                'rot_speed': random.uniform(-12, 12),
                'length': random.randint(4, 10),
            })
        self.dying_barriers.append({
            'x': barrier['x'],
            'y': barrier['y'],
            'width': barrier['width'],
            'death_time': 0.0,
            'fragments': frags,
        })

    # ------------------------------------------------------------------
    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        pass  # 장벽은 파괴될 때까지 유지

    def reset_for_new_round(self, game_state: dict):
        """라운드 넘겨도 장벽 유지, 파괴 애니메이션만 정리"""
        self.dying_barriers = []
        self.is_active = bool(self.barriers)
        self.active_timer = self.duration if self.barriers else 0.0

    def update(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        if self.current_cooldown > 0:
            self.current_cooldown -= dt
        if self.activation_flash_timer > 0:
            self.activation_flash_timer -= dt
        if self.is_active:
            self._update_active_effect(dt, caster_paddle, target_paddle, ball, game_state)
            # 모든 장벽이 파괴되면 스킬 발동 상태 해제 (초상화 UI 깜빡임 방지)
            if not self.barriers:
                self.is_active = False
        # 파괴 애니메이션은 is_active 관계없이
        if self.dying_barriers and not self.is_active:
            new_dying = []
            for d in self.dying_barriers:
                d['death_time'] += dt
                if d['death_time'] < self.DEATH_DURATION:
                    new_dying.append(d)
            self.dying_barriers = new_dying

    # ------------------------------------------------------------------
    #  렌더링
    # ------------------------------------------------------------------
    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        for barrier in self.barriers:
            self._draw_barrier(screen, barrier)
        for dying in self.dying_barriers:
            self._draw_dying_barrier(screen, dying)

    def _draw_barrier(self, screen, barrier):
        """뼈 장막 고퀄리티 렌더링 (Ultra Premium)"""
        x = int(barrier['x'])
        y = int(barrier['y'])
        w = barrier['width']
        h = barrier['height']
        build_progress = min(1.0, barrier['build_timer'] / self.BUILD_TIME)
        t_now = pygame.time.get_ticks() / 1000.0

        bone_c = (210, 200, 175)
        bone_dk = (160, 150, 120)
        bone_br = (230, 225, 200)
        bone_sh = (120, 110, 85)
        bone_cream = (235, 228, 210)
        spike_c = (200, 190, 160)
        spike_br = (225, 218, 195)
        necro_glow = (80, 255, 120)

        if not barrier['built']:
            # === 건설 중: 뼈 조각들이 사방에서 날아와 조립 (고퀄리티) ===
            for seg in barrier['bone_segments']:
                delay_norm = seg['delay'] / self.BUILD_TIME
                adj = max(0.0, min(1.0, (build_progress - delay_norm) / max(0.01, 1.0 - delay_norm)))
                ease = 1.0 - (1.0 - adj) ** 3

                cur_x = seg['start_x'] + (seg['final_x'] - seg['start_x']) * ease
                cur_y = seg['start_y'] + (seg['final_y'] - seg['start_y']) * ease
                cur_rot = seg['start_rot'] + (seg['final_rot'] - seg['start_rot']) * ease
                alpha = int(230 * min(1.0, adj * 2.5))
                if alpha < 10:
                    continue

                half = seg['length'] / 2
                x1 = int(cur_x + _cos(cur_rot) * half)
                y1 = int(cur_y + _sin(cur_rot) * half)
                x2 = int(cur_x - _cos(cur_rot) * half)
                y2 = int(cur_y - _sin(cur_rot) * half)

                # 뼈 그림자
                line_w = 3 if adj > 0.5 else 2
                pygame.draw.line(screen, (*bone_sh, int(alpha * 0.4)), (x1 + 1, y1 + 1), (x2 + 1, y2 + 1), line_w + 1)
                # 뼈 본체
                pygame.draw.line(screen, (*bone_c, alpha), (x1, y1), (x2, y2), line_w)
                # 뼈 하이라이트
                mx, my = (x1 + x2) // 2, (y1 + y2) // 2
                pygame.draw.line(screen, (*bone_br, int(alpha * 0.6)), (x1, y1), (mx, my), max(1, line_w - 1))
                # 관절
                pygame.draw.circle(screen, (*bone_br, alpha), (x1, y1), 2)
                pygame.draw.circle(screen, (*bone_dk, alpha), (x2, y2), 2)

            # 조립 스파크
            if build_progress > 0.3:
                spark_intensity = (build_progress - 0.3) / 0.7
                spark_n = int(8 * spark_intensity)
                for si in range(spark_n):
                    sx = x + random.randint(0, w)
                    sy = y + random.randint(-8, 8)
                    pygame.draw.circle(screen, (200, 220, 180, random.randint(40, 100)), (sx, sy), 1)
        else:
            # === 완성된 뼈 장벽 (Ultra Premium) ===
            is_top = barrier.get('is_top', False)
            pulse = 0.85 + 0.15 * _sin(t_now * 3.0)

            # ── 그림자 ──
            pygame.draw.rect(screen, bone_sh,
                           (x + 2, y - h // 2 + 2, w, h), border_radius=3)

            # ── 본체 (3층 그라디언트) ──
            pygame.draw.rect(screen, bone_dk,
                           (x, y - h // 2, w, h), border_radius=3)
            pygame.draw.rect(screen, bone_c,
                           (x + 1, y - h // 2 + 1, w - 2, h - 2), border_radius=2)
            # 내부 밝은 면
            inner_h = max(1, h - 4)
            pygame.draw.rect(screen, bone_cream,
                           (x + 3, y - inner_h // 2, w - 6, inner_h), border_radius=1)

            # ── 뼈 세그먼트 텍스처 (관절 + 골수 + 균열) ──
            seg_count = max(1, w // 10)
            for i in range(seg_count):
                lx = x + 5 + int(i * (w - 10) / max(1, seg_count - 1)) if seg_count > 1 else x + w // 2
                # 세그먼트 분리선
                pygame.draw.line(screen, bone_dk, (lx, y - h // 2 + 1), (lx, y + h // 2 - 1), 1)
                # 관절 돌기
                joint_pulse = 0.8 + 0.2 * _sin(t_now * 2.0 + i * 0.8)
                pygame.draw.circle(screen, bone_br, (lx, y), 3)
                pygame.draw.circle(screen, bone_c, (lx, y), 3, 1)
                # 관절 중심 점
                pygame.draw.circle(screen, bone_dk, (lx, y), 1)
                # 골수 표시 (관절 사이)
                if i < seg_count - 1:
                    next_lx = x + 5 + int((i + 1) * (w - 10) / max(1, seg_count - 1))
                    mid_x = (lx + next_lx) // 2
                    marrow_a = int(40 * joint_pulse)
                    pygame.draw.line(screen, (*bone_cream, marrow_a),
                                   (lx + 3, y), (next_lx - 3, y), 1)
                # 미세 균열 (일부 세그먼트)
                if i % 3 == 1:
                    crack_y = y - h // 2 + 2
                    pygame.draw.line(screen, bone_sh, (lx + 2, crack_y), (lx + 4, crack_y + 3), 1)

            # ── 가시 스파이크 (고퀄리티 - 그림자 + 하이라이트 + 독기) ──
            spike_heights = barrier.get('spike_heights', [])
            num_spikes = len(spike_heights) if spike_heights else w // 14
            for i in range(num_spikes):
                sx = x + int((i + 0.5) * w / max(1, num_spikes))
                sh = spike_heights[i] if i < len(spike_heights) else 7
                spike_wobble = int(1 * _sin(t_now * 4.0 + i * 1.5))

                if is_top:
                    base_y = y + h // 2
                    tip_y = base_y + sh + spike_wobble
                    # 가시 그림자
                    pygame.draw.polygon(screen, bone_sh, [
                        (sx - 3, base_y + 1), (sx + 1, tip_y + 1), (sx + 4, base_y + 1)])
                    # 가시 본체
                    pygame.draw.polygon(screen, spike_c, [
                        (sx - 3, base_y), (sx, tip_y), (sx + 3, base_y)])
                    # 가시 하이라이트 (밝은 면)
                    pygame.draw.polygon(screen, spike_br, [
                        (sx - 2, base_y), (sx, tip_y), (sx, base_y)])
                    # 가시 능선
                    pygame.draw.line(screen, bone_dk, (sx, base_y), (sx, tip_y), 1)
                    # 독기 파티클
                    if random.random() < 0.04:
                        pygame.draw.circle(screen, (*necro_glow, random.randint(40, 80)),
                                         (sx + random.randint(-2, 2), tip_y + random.randint(1, 4)), 1)
                else:
                    base_y = y - h // 2
                    tip_y = base_y - sh - spike_wobble
                    pygame.draw.polygon(screen, bone_sh, [
                        (sx - 3, base_y - 1), (sx + 1, tip_y - 1), (sx + 4, base_y - 1)])
                    pygame.draw.polygon(screen, spike_c, [
                        (sx - 3, base_y), (sx, tip_y), (sx + 3, base_y)])
                    pygame.draw.polygon(screen, spike_br, [
                        (sx - 2, base_y), (sx, tip_y), (sx, base_y)])
                    pygame.draw.line(screen, bone_dk, (sx, base_y), (sx, tip_y), 1)
                    if random.random() < 0.04:
                        pygame.draw.circle(screen, (*necro_glow, random.randint(40, 80)),
                                         (sx + random.randint(-2, 2), tip_y - random.randint(1, 4)), 1)

            # ── 상단/하단 하이라이트 ──
            pygame.draw.line(screen, bone_br,
                           (x + 3, y - h // 2 + 1), (x + w - 3, y - h // 2 + 1), 1)
            # 하단 그림자 라인
            pygame.draw.line(screen, bone_sh,
                           (x + 3, y + h // 2 - 1), (x + w - 3, y + h // 2 - 1), 1)


    def _draw_dying_barrier(self, screen, dying):
        """뼈 장막 파괴 애니메이션 (고퀄리티)"""
        t = dying['death_time']
        progress = t / self.DEATH_DURATION
        if progress >= 1.0:
            return

        alpha = max(0, int(255 * (1.0 - progress)))
        necro_glow = (80, 255, 120)

        # 충격파 (파괴 순간)
        if progress < 0.35:
            wave_ratio = progress / 0.35
            wave_r = int(30 * wave_ratio)
            wave_a = int(120 * (1.0 - wave_ratio))
            pygame.draw.circle(screen, (*necro_glow, wave_a),
                             (int(dying['x']), int(dying['y'])), wave_r, 2)

        for frag in dying['fragments']:
            fx = frag['x'] + frag['vx'] * t
            fy = frag['y'] + frag['vy'] * t + 120 * t * t
            rot = frag['rot'] + frag['rot_speed'] * t

            half = frag['length'] / 2
            x1 = int(fx + _cos(rot) * half)
            y1 = int(fy + _sin(rot) * half)
            x2 = int(fx - _cos(rot) * half)
            y2 = int(fy - _sin(rot) * half)

            fade = max(0.2, 1.0 - progress)
            # 뼈 그림자
            sh_c = (int(120 * fade), int(110 * fade), int(85 * fade))
            pygame.draw.line(screen, sh_c, (x1 + 1, y1 + 1), (x2 + 1, y2 + 1), 2)
            # 뼈 본체
            c = (int(210 * fade), int(200 * fade), int(175 * fade))
            pygame.draw.line(screen, c, (x1, y1), (x2, y2), 2)
            # 뼈 하이라이트
            br_c = (int(230 * fade), int(225 * fade), int(200 * fade))
            mx, my = (x1 + x2) // 2, (y1 + y2) // 2
            pygame.draw.line(screen, br_c, (x1, y1), (mx, my), 1)
            # 관절점
            pygame.draw.circle(screen, br_c, (x1, y1), 1)
            # 초록 잔여 에너지
            if progress < 0.5 and random.random() < 0.15:
                g_a = int(80 * (1.0 - progress * 2))
                pygame.draw.circle(screen, (*necro_glow, g_a), (x1, y1), 2)

        # 뼈 먼지
        if progress > 0.2:
            dust_n = int(5 * (progress - 0.2) / 0.8)
            for di in range(dust_n):
                dx = int(dying['x']) + random.randint(-40, 40)
                dy = int(dying['y']) + random.randint(-4, 4)
                d_a = int(60 * (1.0 - progress))
                if d_a > 5:
                    pygame.draw.circle(screen, (190, 180, 150, d_a), (dx, dy), 1)


# ============================================================================
# 조커 (Joker) - 광대 스킬
# ============================================================================

class BalloonWall(HeroSkill):
    """익살스런파티 - 화면 중앙에 풍선 장벽을 띄워 공의 궤적을 바꾼다"""

    def __init__(self):
        super().__init__(
            skill_id="balloon_wall",
            name="Balloon Wall",
            korean_name="익살스런파티",
            description="화려한 풍선 장벽이 공의 궤적을 엉뚱하게 바꿔놓는다",
            trigger=SkillTrigger.ON_COOLDOWN,
            cooldown=20.0,
            duration=4.5,
            hero_id="joker"
        )
        self.balloons = []
        self.pop_effects = []  # 터지는 이펙트
        self.caster_is_top = False

    # 풍선 색상 팔레트
    BALLOON_COLORS = [
        (230, 70, 70),     # 빨강
        (255, 200, 50),    # 노랑
        (80, 200, 120),    # 초록
        (70, 140, 230),    # 파랑
        (200, 100, 220),   # 보라
        (255, 140, 60),    # 주황
        (255, 120, 180),   # 분홍
    ]

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        self.caster_is_top = caster_paddle.is_top
        self.balloons = []
        self.pop_effects = []

        # 풍선 5~7개를 중앙 영역에 배치
        balloon_count = random.randint(5, 7)

        for i in range(balloon_count):
            color = random.choice(self.BALLOON_COLORS)
            bx = random.randint(80, 680)
            by = random.randint(250, 500)
            size = random.randint(18, 28)

            balloon = {
                'x': float(bx),
                'y': float(by),
                'base_x': float(bx),
                'base_y': float(by),
                'size': size,
                'color': color,
                'phase': random.uniform(0, math.pi * 2),
                'alive': True,
                'spawn_time': 0.0,
                'string_sway': random.uniform(0, math.pi * 2),
                # 떠다니기 속성
                'drift_angle': random.uniform(0, math.pi * 2),
                'drift_speed': random.uniform(12, 25),
                'drift_wobble': random.uniform(0, math.pi * 2),
                # 터짐 애니메이션
                'popping': False,
                'pop_timer': 0.0,
                'pop_delay': 0.0,
            }
            self.balloons.append(balloon)

        game_state['has_balloon_wall'] = True

        # 풍선 등장 사운드
        try:
            project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            sound_path = os.path.join(project_root, "sounds", "selectswing.wav")
            if os.path.exists(sound_path):
                s = pygame.mixer.Sound(sound_path)
                s.set_volume(0.4)
                s.play()
        except Exception:
            pass

        return {
            'screen_effect': ScreenEffect.FLASH,
            'flash_color': (255, 220, 100),
            'flash_duration': 0.12,
        }

    def _create_pop_effect(self, balloon):
        """풍선 터짐 이펙트 생성 (고퀄리티 - 다양한 파편 + 방사형 스파클)"""
        frag_count = 10
        base_color = balloon['color']
        pop = {
            'x': balloon['x'],
            'y': balloon['y'],
            'color': base_color,
            'size': balloon['size'],
            'time': 0.0,
            'fragments': [
                {
                    'x': balloon['x'],
                    'y': balloon['y'],
                    'vx': random.uniform(-6, 6),
                    'vy': random.uniform(-7, 2),
                    'size': random.randint(3, 7),
                    'color': base_color if random.random() > 0.3 else
                             tuple(min(255, c + random.randint(30, 80)) for c in base_color),
                    'rotation': random.uniform(0, math.pi * 2),
                    'rot_speed': random.uniform(-8, 8),
                    'shape': random.choice(['circle', 'circle', 'strip', 'triangle']),
                }
                for _ in range(frag_count)
            ],
            'ring_particles': [
                {
                    'angle': i * (2 * math.pi / 8),
                    'speed': random.uniform(2.5, 5),
                    'color': base_color,
                    'size': random.randint(2, 4),
                }
                for i in range(8)
            ],
        }
        self.pop_effects.append(pop)

    def _play_pop_sound(self):
        """풍선 터짐 사운드 재생"""
        try:
            project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            sound_path = os.path.join(project_root, "sounds", "balloonboom.wav")
            if os.path.exists(sound_path):
                s = pygame.mixer.Sound(sound_path)
                s.set_volume(0.35)
                s.play()
        except Exception:
            pass

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        for balloon in self.balloons:
            if not balloon['alive'] or balloon.get('popping'):
                continue

            balloon['spawn_time'] += dt

            # 유유히 떠다니는 움직임 (drift)
            balloon['drift_wobble'] += dt * 0.8
            balloon['drift_angle'] += _sin(balloon['drift_wobble']) * 0.6 * dt
            dx = math.cos(balloon['drift_angle']) * balloon['drift_speed'] * dt
            dy = math.sin(balloon['drift_angle']) * balloon['drift_speed'] * 0.5 * dt
            balloon['base_x'] += dx
            balloon['base_y'] += dy

            # 게임 영역 경계 반사
            if balloon['base_x'] < 100:
                balloon['base_x'] = 100
                balloon['drift_angle'] = math.pi - balloon['drift_angle']
            elif balloon['base_x'] > 660:
                balloon['base_x'] = 660
                balloon['drift_angle'] = math.pi - balloon['drift_angle']
            if balloon['base_y'] < 230:
                balloon['base_y'] = 230
                balloon['drift_angle'] = -balloon['drift_angle']
            elif balloon['base_y'] > 520:
                balloon['base_y'] = 520
                balloon['drift_angle'] = -balloon['drift_angle']

            # 둥실둥실 부유 (base 위치 위에 bob 애니메이션)
            balloon['x'] = balloon['base_x'] + _sin(balloon['spawn_time'] * 1.5 + balloon['phase']) * 6
            balloon['y'] = balloon['base_y'] + _sin(balloon['spawn_time'] * 2.0 + balloon['phase']) * 8
            balloon['string_sway'] += dt * 1.5

            # 공과 충돌 체크
            if ball is not None and balloon['spawn_time'] > 0.3:
                ball_cx = ball.x + ball.width / 2
                ball_cy = ball.y + ball.height / 2
                dist = math.sqrt((ball_cx - balloon['x']) ** 2 + (ball_cy - balloon['y']) ** 2)

                if dist < balloon['size'] + ball.width / 2:
                    speed = math.sqrt(ball.vx ** 2 + ball.vy ** 2)
                    speed = max(speed, 5.0)

                    if random.random() < 0.80:
                        target_angle = math.pi / 2 if self.caster_is_top else -math.pi / 2
                        angle = target_angle + random.uniform(-math.pi / 4, math.pi / 4)
                    else:
                        angle = math.atan2(ball_cy - balloon['y'], ball_cx - balloon['x'])
                        angle += random.uniform(-0.5, 0.5)

                    ball.vx = math.cos(angle) * speed * 1.50
                    ball.vy = math.sin(angle) * speed * 1.50

                    # 풍선 터짐
                    balloon['alive'] = False
                    self._create_pop_effect(balloon)
                    self._play_pop_sound()

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        game_state['has_balloon_wall'] = False
        # 남은 풍선들을 시간차로 터지게 설정 (흔들리다가 터지는 애니메이션)
        alive_balloons = [b for b in self.balloons if b['alive'] and not b.get('popping')]
        for i, balloon in enumerate(alive_balloons):
            balloon['popping'] = True
            balloon['pop_timer'] = 0.0
            balloon['pop_delay'] = i * 0.12  # 0.12초 간격으로 시간차 터짐

    def reset_for_new_round(self, game_state: dict):
        super().reset_for_new_round(game_state)
        self.balloons = []
        self.pop_effects = []
        game_state['has_balloon_wall'] = False

    def update(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        super().update(dt, caster_paddle, target_paddle, ball, game_state)

        # 터짐 대기 중인 풍선 처리 (스킬 종료 후에도 동작)
        for balloon in self.balloons:
            if not balloon['alive']:
                continue
            if balloon.get('popping'):
                # bob 애니메이션 계속
                balloon['spawn_time'] += dt
                balloon['x'] = balloon.get('base_x', balloon['x']) + _sin(balloon['spawn_time'] * 1.5 + balloon['phase']) * 6
                balloon['y'] = balloon['base_y'] + _sin(balloon['spawn_time'] * 2.0 + balloon['phase']) * 8
                balloon['string_sway'] += dt * 1.5

                if balloon.get('pop_delay', 0) > 0:
                    balloon['pop_delay'] -= dt
                else:
                    balloon['pop_timer'] += dt
                    # 0.25초간 흔들리다가 터짐
                    if balloon['pop_timer'] >= 0.25:
                        balloon['alive'] = False
                        self._create_pop_effect(balloon)
                        self._play_pop_sound()

        # 터지는 이펙트 업데이트 (is_active와 무관)
        if self.pop_effects:
            new_pops = []
            for pop in self.pop_effects:
                pop['time'] += dt
                for frag in pop['fragments']:
                    frag['x'] += frag['vx']
                    frag['y'] += frag['vy']
                    frag['vy'] += 8 * dt  # 중력
                    frag['rotation'] = frag.get('rotation', 0) + frag.get('rot_speed', 0) * dt
                if pop['time'] < 0.8:
                    new_pops.append(pop)
            self.pop_effects = new_pops

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        # 살아있는 풍선 그리기
        for balloon in self.balloons:
            if not balloon['alive']:
                continue

            bx = int(balloon['x'])
            by = int(balloon['y'])
            size = balloon['size']
            color = balloon['color']
            spawn_t = balloon['spawn_time']

            # 등장 스케일 (팡 하고 커지는 느낌)
            if spawn_t < 0.3:
                scale = spawn_t / 0.3
                scale = 1 - (1 - scale) ** 3  # ease-out cubic
                size = int(size * scale)
                if size < 2:
                    continue

            # 터지기 직전 흔들림 & 부풀어오름
            if balloon.get('popping') and balloon.get('pop_delay', 0) <= 0:
                pt = balloon['pop_timer']
                wobble_freq = 25 + pt * 50
                wobble_amp = 2 + pt * 12
                bx += int(_sin(pt * wobble_freq) * wobble_amp)
                inflate = 1.0 + pt * 1.2
                size = int(size * inflate)

            if size < 2:
                continue

            # === 글로우 (풍선 뒤에 은은한 빛) ===
            glow_r = size + 8
            glow_surf = _psurf((glow_r * 2, glow_r * 2), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (*color[:3], 18), (glow_r, glow_r), glow_r)
            screen.blit(glow_surf, (bx - glow_r, by - glow_r))

            # === 풍선 본체 (고퀄리티 렌더링) ===
            surf_w = size * 2 + 8
            surf_h = int(size * 2.6) + 8
            balloon_surf = _psurf((surf_w, surf_h), pygame.SRCALPHA)
            cx = surf_w // 2
            cy = int(size * 1.2) + 3
            bw = size
            bh = int(size * 1.2)

            # 1. 그림자 (아래쪽 오프셋)
            shadow_color = tuple(max(0, c - 70) for c in color)
            pygame.draw.ellipse(balloon_surf, (*shadow_color, 45),
                              (cx - bw + 2, cy - bh + 3, bw * 2, bh * 2))

            # 2. 메인 바디
            pygame.draw.ellipse(balloon_surf, color,
                              (cx - bw, cy - bh, bw * 2, bh * 2))

            # 3. 하단 그라데이션 (어두운 영역 - 입체감)
            darker = tuple(max(0, c - 35) for c in color)
            grad_h = max(2, bh)
            pygame.draw.ellipse(balloon_surf, (*darker, 60),
                              (cx - bw + 3, cy, bw * 2 - 6, grad_h))

            # 4. 상단 하이라이트 (넓은 광택)
            lighter = tuple(min(255, c + 50) for c in color)
            hl_w = int(bw * 1.3)
            hl_h = int(bh * 0.65)
            pygame.draw.ellipse(balloon_surf, (*lighter, 75),
                              (cx - hl_w // 2, cy - bh + 2, hl_w, hl_h))

            # 5. 메인 반사광 (밝은 타원)
            spec_x = cx - int(size * 0.2)
            spec_y = cy - int(size * 0.5)
            spec_w = max(4, int(size * 0.45))
            spec_h = max(3, int(size * 0.3))
            pygame.draw.ellipse(balloon_surf, (255, 255, 255, 170),
                              (spec_x - spec_w // 2, spec_y - spec_h // 2, spec_w, spec_h))

            # 6. 작은 스페큘러 포인트 (강한 반짝임)
            tiny_x = cx - int(size * 0.35)
            tiny_y = cy - int(size * 0.7)
            tiny_r = max(1, size // 6)
            pygame.draw.circle(balloon_surf, (255, 255, 255, 220), (tiny_x, tiny_y), tiny_r)

            # 7. 외곽선
            outline_color = tuple(max(0, c - 45) for c in color)
            pygame.draw.ellipse(balloon_surf, (*outline_color, 70),
                              (cx - bw, cy - bh, bw * 2, bh * 2), 1)

            # 8. 꼭지 (역삼각형)
            knot_y_surf = cy + bh
            knot_sz = max(2, size // 5)
            knot_color = tuple(max(0, c - 40) for c in color)
            pygame.draw.polygon(balloon_surf, knot_color, [
                (cx - knot_sz, knot_y_surf),
                (cx + knot_sz, knot_y_surf),
                (cx, knot_y_surf + knot_sz + 1),
            ])

            screen.blit(balloon_surf, (bx - cx, by - cy))

            # === 풍선 줄 (3구간 곡선, 자연스러운 흔들림) ===
            string_sway = _sin(balloon['string_sway']) * 5
            string_sway2 = _sin(balloon['string_sway'] * 1.3 + 1.0) * 3
            str_top_y = by + int(size * 0.2) + knot_sz
            str_len = int(size * 1.6)
            p0 = (bx, str_top_y)
            p1 = (bx + int(string_sway), str_top_y + str_len // 3)
            p2 = (bx + int(string_sway2), str_top_y + 2 * str_len // 3)
            p3 = (bx - int(string_sway * 0.3), str_top_y + str_len)
            pygame.draw.line(screen, (200, 200, 200), p0, p1, 1)
            pygame.draw.line(screen, (190, 190, 190), p1, p2, 1)
            pygame.draw.line(screen, (180, 180, 180), p2, p3, 1)

        # === 터지는 이펙트 그리기 (고퀄리티) ===
        for pop in self.pop_effects:
            progress = pop['time'] / 0.8
            if progress >= 1.0:
                continue
            alpha = int(255 * (1.0 - progress))
            px, py = int(pop['x']), int(pop['y'])

            # 1. 중앙 플래시 (초기 순간 - 밝은 섬광)
            if progress < 0.12:
                flash_alpha = int(220 * (1 - progress / 0.12))
                flash_r = int(pop['size'] * 1.8)
                if flash_r > 0:
                    flash_surf = _psurf((flash_r * 2, flash_r * 2), pygame.SRCALPHA)
                    pygame.draw.circle(flash_surf, (255, 255, 255, flash_alpha),
                                     (flash_r, flash_r), flash_r)
                    screen.blit(flash_surf, (px - flash_r, py - flash_r))

            # 2. 확장 버스트 링
            ring_r = int(pop['size'] * (1.0 + progress * 3.5))
            ring_alpha = int(alpha * 0.3)
            if ring_alpha > 5 and ring_r > 0:
                ring_surf = _psurf((ring_r * 2, ring_r * 2), pygame.SRCALPHA)
                ring_thick = max(1, 3 - int(progress * 4))
                pygame.draw.circle(ring_surf, (*pop['color'], ring_alpha),
                                 (ring_r, ring_r), ring_r, ring_thick)
                screen.blit(ring_surf, (px - ring_r, py - ring_r))

            # 3. 파편 (다양한 모양 - 원, 길쭉한 조각, 삼각형)
            for frag in pop['fragments']:
                frag_alpha = int(alpha * 0.8)
                if frag_alpha <= 5:
                    continue
                fx, fy = int(frag['x']), int(frag['y'])
                frag_size = max(1, int(frag['size'] * (1 - progress * 0.6)))
                fc = (*frag['color'][:3], frag_alpha)
                shape = frag.get('shape', 'circle')

                if shape == 'strip' and frag_size > 1:
                    sw = frag_size * 3
                    sh = max(1, frag_size)
                    frag_surf = _psurf((sw + 2, sh + 2), pygame.SRCALPHA)
                    pygame.draw.rect(frag_surf, fc, (1, 1, sw, sh))
                    rot_angle = math.degrees(frag.get('rotation', 0))
                    rotated = pygame.transform.rotate(frag_surf, rot_angle)
                    screen.blit(rotated, (fx - rotated.get_width() // 2,
                                         fy - rotated.get_height() // 2))
                elif shape == 'triangle' and frag_size > 1:
                    ts = frag_size + 1
                    t_surf = _psurf((ts * 2 + 2, ts * 2 + 2), pygame.SRCALPHA)
                    tc = ts + 1
                    pygame.draw.polygon(t_surf, fc, [
                        (tc, tc - ts), (tc - ts, tc + ts), (tc + ts, tc + ts),
                    ])
                    screen.blit(t_surf, (fx - tc, fy - tc))
                else:
                    if frag_size > 0:
                        c_surf = _psurf((frag_size * 2 + 2, frag_size * 2 + 2), pygame.SRCALPHA)
                        pygame.draw.circle(c_surf, fc,
                                         (frag_size + 1, frag_size + 1), frag_size)
                        screen.blit(c_surf, (fx - frag_size - 1, fy - frag_size - 1))

            # 4. 방사형 스파클 (8방향 작은 입자)
            if progress < 0.4:
                sparkle_alpha = int(160 * (1 - progress / 0.4))
                for rp in pop.get('ring_particles', []):
                    dist = rp['speed'] * pop['time'] * 50
                    sx = px + int(math.cos(rp['angle']) * dist)
                    sy = py + int(math.sin(rp['angle']) * dist)
                    s_size = max(1, int(rp['size'] * (1 - progress * 2)))
                    if s_size > 0:
                        sp_surf = _psurf((s_size * 2 + 2, s_size * 2 + 2), pygame.SRCALPHA)
                        pygame.draw.circle(sp_surf, (*rp['color'][:3], sparkle_alpha),
                                         (s_size + 1, s_size + 1), s_size)
                        screen.blit(sp_surf, (sx - s_size - 1, sy - s_size - 1))


class BombSurprise(HeroSkill):
    """폭탄 서프라이즈 - 시한폭탄을 공에 부착, 패들↔공 사이를 오가다 폭발 시 넉백+스턴"""

    EXPLOSION_RADIUS = 350  # 폭발 범위 (다이너마이트 동일)
    KNOCKBACK_FORCE = 600   # 넉백 강도 (px/s, 다이너마이트급)
    STUN_DURATION = 3.0     # 스턴 시간 (다이너마이트 동일)

    # 자폭(시전자에게 폭발) 시 약화 수치
    SELF_KNOCKBACK_SCALE = 0.30   # 넉백 30% (70% 감소)
    SELF_STUN_DURATION = 0.8      # 스턴 0.8초
    SELF_SCREEN_SHAKE = 12        # 화면 흔들림 약화 (정상: 35)
    SELF_SHAKE_DURATION = 0.3     # 흔들림 시간 약화 (정상: 0.67)

    def __init__(self):
        super().__init__(
            skill_id="bomb_surprise",
            name="Bomb Surprise",
            korean_name="폭탄 서프라이즈",
            description="공에 시한폭탄을 몰래 심어 뜻밖의 폭발을 선사한다",
            trigger=SkillTrigger.ON_BALL_HIT,
            cooldown=22.0,
            duration=30.0,  # 폭발 시 직접 종료 (충분히 긴 지속시간)
            hero_id="joker"
        )
        self.bomb_active = False
        self.bomb_timer = 0.0
        self.bomb_max_time = 6.0      # 랜덤 4~8초
        self.bomb_location = 'ball'   # 'ball', 'top', 'bottom'
        self.last_ball_vy_sign = 0    # 공 vy 부호 추적
        self.caster_is_top = False
        self.explosion_effects = []
        self._tick_sound_cd = 0.0
        self._sound_loaded = False
        self._attach_sound = None
        self._transfer_sound = None   # 폭탄 이동 시 효과음 (spiderminesetup)
        self._tick_sound = None
        self._tick_sound2 = None
        self._tick_toggle = False  # False=ticking1, True=ticking2
        self._tick_sound3 = None       # 폭발 0.5초 전 긴박감 사운드
        self._ticking3_channel = None  # ticking3 재생 채널 (폭발 시 정지용)
        self._ticking3_playing = False
        self._explode_sound = None
        self._self_explode_sound = None  # 자폭 전용 사운드 (weakexplosion)
        # 넉백/스턴 상태
        self._knockback_target = None   # 'top' or 'bottom'
        self._stun_applied = False
        self._stun_timer = 0.0
        # 활성화 직후 vy 감지 유예 (호위무사 발동 시 프레임 간 레이스 컨디션 방지)
        self._vy_grace_timer = 0.0

    def _load_sounds(self):
        if self._sound_loaded:
            return
        self._sound_loaded = True
        try:
            project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            path1 = os.path.join(project_root, "sounds", "boomstart.wav")
            if os.path.exists(path1):
                self._attach_sound = pygame.mixer.Sound(path1)
                self._attach_sound.set_volume(0.35)
            path1b = os.path.join(project_root, "sounds", "spiderminesetup.wav")
            if os.path.exists(path1b):
                self._transfer_sound = pygame.mixer.Sound(path1b)
                self._transfer_sound.set_volume(0.3)
            path2 = os.path.join(project_root, "sounds", "ticking1.wav")
            if os.path.exists(path2):
                self._tick_sound = pygame.mixer.Sound(path2)
                self._tick_sound.set_volume(0.15)
            path2b = os.path.join(project_root, "sounds", "ticking2.wav")
            if os.path.exists(path2b):
                self._tick_sound2 = pygame.mixer.Sound(path2b)
                self._tick_sound2.set_volume(0.15)
            path2c = os.path.join(project_root, "sounds", "ticking3.wav")
            if os.path.exists(path2c):
                self._tick_sound3 = pygame.mixer.Sound(path2c)
                self._tick_sound3.set_volume(0.45)
            path3 = os.path.join(project_root, "sounds", "grenade.wav")
            if os.path.exists(path3):
                self._explode_sound = pygame.mixer.Sound(path3)
                self._explode_sound.set_volume(0.8)
            path3b = os.path.join(project_root, "sounds", "weakexplosion.wav")
            if os.path.exists(path3b):
                self._self_explode_sound = pygame.mixer.Sound(path3b)
                self._self_explode_sound.set_volume(0.8)
        except Exception:
            pass

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        self.caster_is_top = caster_paddle.is_top
        self.bomb_active = True
        self.bomb_timer = 0.0
        self.bomb_max_time = random.uniform(4.0, 8.0)  # 매번 랜덤 쿨타임
        self.bomb_location = 'ball'   # 처음엔 공에 부착
        self.explosion_effects = []
        self._tick_sound_cd = 0.0
        self._tick_toggle = False
        self._ticking3_playing = False
        self._ticking3_channel = None
        self._knockback_target = None
        self._stun_applied = False
        self._stun_timer = 0.0

        # 공 vy 부호 추적 시작
        if ball:
            self.last_ball_vy_sign = 1 if ball.vy > 0 else (-1 if ball.vy < 0 else 0)

        # 호위무사가 쿨타임 기반으로 발동할 때, 스킬 활성화와 첫 업데이트 사이에
        # 메인 루프에서 공-패들 충돌이 처리되어 ball.vy 부호가 바뀔 수 있음.
        # 이 유예 시간 동안은 vy 부호 변화를 무시하고 현재 값만 동기화하여
        # 폭탄이 활성화 즉시 패들로 이동하는 버그를 방지함.
        self._vy_grace_timer = 0.15  # 0.15초 유예

        game_state['bomb_surprise_active'] = True

        self._load_sounds()
        if self._attach_sound:
            try:
                self._attach_sound.play()
            except Exception:
                pass

        return {
            'screen_effect': ScreenEffect.FLASH,
            'flash_color': (255, 100, 50),
            'flash_duration': 0.12,
        }

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        # 넉백은 game_state 시그널로 아레나에서 처리 (bomb_kb_active)

        # 스턴 타이머 관리
        if self._stun_applied:
            self._stun_timer -= dt
            if self._stun_timer <= 0:
                # 스턴 해제
                prefix = 'top_paddle' if self._knockback_target == 'top' else 'bottom_paddle'
                game_state[f'{prefix}_stunned'] = False
                self._stun_applied = False

        if not self.bomb_active:
            # 폭발 후 이펙트/스턴만 남은 상태
            prefix_kb = 'top_paddle' if self._knockback_target == 'top' else 'bottom_paddle'
            kb_still_active = game_state.get(f'{prefix_kb}_bomb_kb_active', False)
            if not self.explosion_effects and not kb_still_active and not self._stun_applied:
                self.is_active = False
                self.active_timer = 0
            return

        self.bomb_timer += dt

        # 공과 패들 충돌 감지 (공 vy 부호 변화로)
        if ball:
            current_vy_sign = 1 if ball.vy > 0 else (-1 if ball.vy < 0 else 0)

            # 유예 시간 중에는 vy 부호만 동기화 (전환 감지 안 함)
            if self._vy_grace_timer > 0:
                self._vy_grace_timer -= dt
                self.last_ball_vy_sign = current_vy_sign
            elif current_vy_sign != 0 and self.last_ball_vy_sign != 0 and current_vy_sign != self.last_ball_vy_sign:
                # vy 부호가 바뀜 = 패들에 맞음
                if current_vy_sign > 0:
                    # 위에서 아래로 전환 → 상단 패들이 공을 침
                    hit_paddle = 'top'
                else:
                    # 아래에서 위로 전환 → 하단 패들이 공을 침
                    hit_paddle = 'bottom'

                if self.bomb_location == 'ball':
                    # 공에 붙은 폭탄 → 받아친 패들로 이동
                    self.bomb_location = hit_paddle
                    self._play_attach_sound()
                elif self.bomb_location == hit_paddle:
                    # 폭탄이 붙은 패들이 공을 침 → 공으로 이동
                    self.bomb_location = 'ball'
                    self._play_attach_sound()

            if self._vy_grace_timer <= 0:
                self.last_ball_vy_sign = current_vy_sign

        # 틱 사운드 (점점 빨라짐, ticking1/ticking2 번갈아 재생)
        self._tick_sound_cd -= dt
        tick_interval = max(0.12, 0.7 - (self.bomb_timer / self.bomb_max_time) * 0.58)
        if self._tick_sound_cd <= 0:
            self._tick_sound_cd = tick_interval
            snd = self._tick_sound2 if self._tick_toggle else self._tick_sound
            if snd:
                try:
                    vol = 0.1 + 0.2 * (self.bomb_timer / self.bomb_max_time)
                    snd.set_volume(min(0.4, vol))
                    snd.play()
                except Exception:
                    pass
            self._tick_toggle = not self._tick_toggle

        # 폭발 0.5초 전 긴박감 사운드
        remaining = self.bomb_max_time - self.bomb_timer
        if remaining <= 0.5 and not self._ticking3_playing and self._tick_sound3:
            try:
                self._ticking3_channel = self._tick_sound3.play()
                self._ticking3_playing = True
            except Exception:
                pass

        # 폭발!
        if self.bomb_timer >= self.bomb_max_time:
            self._explode(caster_paddle, target_paddle, ball, game_state)

    def _play_attach_sound(self):
        """폭탄 이동 시 효과음"""
        if self._transfer_sound:
            try:
                self._transfer_sound.play()
            except Exception:
                pass

    def _explode(self, caster_paddle, target_paddle, ball, game_state):
        """폭발 처리 (다이너마이트급 범위/넉백/화면흔들림, 자폭 시 약화)"""
        self.bomb_active = False
        game_state['bomb_surprise_active'] = False

        # ticking3 사운드 즉시 정지
        if self._ticking3_channel:
            try:
                self._ticking3_channel.stop()
            except Exception:
                pass
        self._ticking3_playing = False
        self._ticking3_channel = None

        # 폭발 위치와 피해 대상 결정
        if self.bomb_location == 'ball' and ball:
            ball_cy = ball.y + ball.height / 2
            explode_target = 'top' if ball_cy < 375 else 'bottom'
            exp_x = float(ball.x + ball.width / 2)
            exp_y = float(ball.y + ball.height / 2)
        elif self.bomb_location in ('top', 'bottom'):
            explode_target = self.bomb_location
            paddle = caster_paddle if (caster_paddle.is_top and explode_target == 'top') or \
                     (not caster_paddle.is_top and explode_target == 'bottom') else target_paddle
            exp_x = float(paddle.x + getattr(paddle, 'width', 80) // 2)
            exp_y = float(paddle.y)
        else:
            return

        # 자폭 판별: 시전자(조커) 쪽에서 폭발했는가?
        is_self_explosion = (
            (self.caster_is_top and explode_target == 'top') or
            (not self.caster_is_top and explode_target == 'bottom')
        )

        # 자폭 vs 상대폭발에 따른 수치 결정
        if is_self_explosion:
            stun_dur = self.SELF_STUN_DURATION         # 1.5초
            kb_vel = 52.0 * self.SELF_KNOCKBACK_SCALE  # 15.6 (70% 감소)
            kb_frames = 10                              # 프레임도 축소
            shake_amt = self.SELF_SCREEN_SHAKE          # 12
            shake_dur = self.SELF_SHAKE_DURATION        # 0.3초
        else:
            stun_dur = self.STUN_DURATION               # 3.0초
            kb_vel = 52.0                               # 풀 넉백
            kb_frames = 18
            shake_amt = 35
            shake_dur = 0.67

        # 스턴 적용
        prefix = 'top_paddle' if explode_target == 'top' else 'bottom_paddle'
        game_state[f'{prefix}_stunned'] = True
        self._stun_applied = True
        self._stun_timer = stun_dur
        self._knockback_target = explode_target

        # 넉백 (game_state 시그널 → 아레나에서 처리)
        target_p = caster_paddle if (caster_paddle.is_top and explode_target == 'top') or \
                   (not caster_paddle.is_top and explode_target == 'bottom') else target_paddle
        paddle_cx = target_p.x + getattr(target_p, 'width', 80) // 2
        dx = paddle_cx - exp_x
        if abs(dx) < 5:
            kb_dir = random.choice([-1, 1])
        else:
            kb_dir = 1 if dx > 0 else -1
        game_state[f'{prefix}_bomb_kb_active'] = True
        game_state[f'{prefix}_bomb_kb_dir'] = kb_dir
        game_state[f'{prefix}_bomb_kb_vel'] = kb_vel
        game_state[f'{prefix}_bomb_kb_frames'] = kb_frames
        tag = "SELF" if is_self_explosion else "ENEMY"
        self._knockback_target = explode_target

        # 화면 흔들림
        game_state['screen_shake'] = shake_amt
        game_state['shake_duration'] = shake_dur

        # 폭발 이펙트 생성 (자폭 시 축소)
        if is_self_explosion:
            n_particles = 35
            n_sparks = 12
            n_smoke = 5
            particle_speed_range = (6, 18)
            spark_speed_range = (12, 28)
            smoke_dist_range = (10, 30)
            exp_max_time = 0.35
            exp_radius_cap = 180
            secondary_waves = [
                {'radius': 0, 'speed': 15, 'delay': 0},
            ]
        else:
            n_particles = 100
            n_sparks = 40
            n_smoke = 15
            particle_speed_range = (12, 35)
            spark_speed_range = (25, 50)
            smoke_dist_range = (20, 60)
            exp_max_time = 0.6
            exp_radius_cap = self.EXPLOSION_RADIUS
            secondary_waves = [
                {'radius': 0, 'speed': 25, 'delay': 0},
                {'radius': 0, 'speed': 20, 'delay': 3},
                {'radius': 0, 'speed': 15, 'delay': 6},
            ]

        particles = []
        for _ in range(n_particles):
            angle = random.uniform(0, 2 * math.pi)
            speed = random.uniform(*particle_speed_range)
            particles.append({
                'x': exp_x, 'y': exp_y,
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed - 5,
                'size': random.uniform(2, 10) if is_self_explosion else random.uniform(3, 14),
                'color_type': random.choice(['fire', 'fire', 'spark', 'ember']),
                'life': random.randint(10, 20) if is_self_explosion else random.randint(15, 30),
                'max_life': 20 if is_self_explosion else 30,
            })
        sparks = []
        for _ in range(n_sparks):
            angle = random.uniform(0, 2 * math.pi)
            speed = random.uniform(*spark_speed_range)
            sparks.append({
                'x': exp_x, 'y': exp_y,
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed - 8,
                'life': random.randint(6, 12) if is_self_explosion else random.randint(10, 20),
                'max_life': 12 if is_self_explosion else 20,
            })
        smoke_clouds = []
        for _ in range(n_smoke):
            angle = random.uniform(0, 2 * math.pi)
            dist = random.uniform(*smoke_dist_range)
            smoke_clouds.append({
                'x': exp_x + math.cos(angle) * dist,
                'y': exp_y + math.sin(angle) * dist,
                'vx': math.cos(angle) * 2,
                'vy': -random.uniform(1, 3),
                'size': random.uniform(12, 25) if is_self_explosion else random.uniform(20, 40),
                'life': random.randint(12, 22) if is_self_explosion else random.randint(20, 36),
                'max_life': 22 if is_self_explosion else 36,
            })

        self.explosion_effects = [{
            'x': exp_x, 'y': exp_y,
            'time': 0.0, 'max_time': exp_max_time,
            'target': explode_target,
            'shockwave_radius': 0,
            'shockwave_cap': exp_radius_cap,
            'is_self_explosion': is_self_explosion,
            'particles': particles,
            'sparks': sparks,
            'smoke_clouds': smoke_clouds,
            'secondary_waves': secondary_waves,
            'kb_dir': kb_dir,
        }]

        # 폭발 사운드 (자폭 시 weakexplosion 사운드 사용)
        try:
            if is_self_explosion and self._self_explode_sound:
                self._self_explode_sound.play()
            elif self._explode_sound:
                self._explode_sound.set_volume(0.8)
                self._explode_sound.play()
        except Exception:
            pass

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        self.bomb_active = False
        game_state['bomb_surprise_active'] = False
        # 스턴은 타이머로 관리하므로 여기서 강제 해제하지 않음

    def reset_for_new_round(self, game_state: dict):
        super().reset_for_new_round(game_state)
        self.bomb_active = False
        self.bomb_timer = 0.0
        self.explosion_effects = []
        if self._stun_applied and self._knockback_target:
            prefix = 'top_paddle' if self._knockback_target == 'top' else 'bottom_paddle'
            game_state[f'{prefix}_stunned'] = False
            game_state[f'{prefix}_bomb_kb_active'] = False
        self._stun_applied = False
        self._stun_timer = 0.0
        self._vy_grace_timer = 0.0
        game_state['bomb_surprise_active'] = False
        # 양쪽 넉백 시그널 정리
        game_state['top_paddle_bomb_kb_active'] = False
        game_state['bottom_paddle_bomb_kb_active'] = False

    def update(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        super().update(dt, caster_paddle, target_paddle, ball, game_state)
        # 폭발 이펙트 (다이너마이트급 파티클 물리)
        if self.explosion_effects:
            new_exp = []
            for exp in self.explosion_effects:
                exp['time'] += dt
                max_time = exp.get('max_time', 0.6)
                progress = min(1.0, exp['time'] / max_time)

                # 쇼크웨이브 확장 (자폭 시 축소된 cap 사용)
                cap = exp.get('shockwave_cap', self.EXPLOSION_RADIUS)
                if exp.get('shockwave_radius', 0) < cap:
                    exp['shockwave_radius'] = exp.get('shockwave_radius', 0) + 30

                # 2차 쇼크웨이브
                frames_elapsed = int(exp['time'] * 60)
                for wave in exp.get('secondary_waves', []):
                    if frames_elapsed >= wave['delay'] and wave['radius'] < cap:
                        wave['radius'] += wave['speed']

                # 메인 파티클 물리
                for p in exp.get('particles', [])[:]:
                    p['x'] += p['vx']
                    p['y'] += p['vy']
                    p['vy'] += 0.4
                    p['vx'] *= 0.95
                    p['vy'] *= 0.97
                    p['life'] -= 1
                    p['size'] = max(0.5, p['size'] - 0.3)
                    if p['life'] <= 0:
                        exp['particles'].remove(p)

                # 스파크 물리
                for s in exp.get('sparks', [])[:]:
                    s['x'] += s['vx']
                    s['y'] += s['vy']
                    s['vy'] += 0.8
                    s['vx'] *= 0.92
                    s['life'] -= 1
                    if s['life'] <= 0:
                        exp['sparks'].remove(s)

                # 연기 구름
                for c in exp.get('smoke_clouds', [])[:]:
                    c['x'] += c['vx']
                    c['y'] += c['vy']
                    c['size'] += 0.8
                    c['life'] -= 1
                    if c['life'] <= 0:
                        exp['smoke_clouds'].remove(c)

                if exp['time'] < max_time:
                    new_exp.append(exp)
            self.explosion_effects = new_exp

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        remaining = max(0, self.bomb_max_time - self.bomb_timer)
        countdown_int = int(math.ceil(remaining))  # 5,4,3,2,1

        if self.bomb_active:
            # 공에 붙은 폭탄만 여기서 그림 (패들 부착 폭탄은 draw_overlay에서 처리)
            if self.bomb_location == 'ball' and ball:
                bx = int(ball.x + ball.width / 2)
                by = int(ball.y + ball.height / 2)
                self._draw_bomb(screen, bx, by, countdown_int, remaining)

        # 폭발 이펙트
        for exp in self.explosion_effects:
            self._draw_explosion(screen, exp)

    def draw_overlay(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        """패들에 부착된 폭탄을 영웅 이미지 위에 그리기 (draw_objects에서 영웅 패들 렌더링 후 호출)"""
        if not self.bomb_active:
            return
        if self.bomb_location not in ('top', 'bottom'):
            return
        remaining = max(0, self.bomb_max_time - self.bomb_timer)
        countdown_int = int(math.ceil(remaining))
        if self.bomb_location == 'top':
            paddle = caster_paddle if caster_paddle.is_top else target_paddle
        else:
            paddle = target_paddle if not target_paddle.is_top else caster_paddle
        bx = int(paddle.x + getattr(paddle, 'width', 80) // 2)
        by = int(paddle.y - 8)
        self._draw_bomb(screen, bx, by, countdown_int, remaining)

    def _draw_bomb(self, screen, bx, by, countdown_int, remaining):
        """시한폭탄 렌더링 (타이머 텍스트 포함)"""
        progress = self.bomb_timer / self.bomb_max_time
        bomb_size = 12

        # 경고 글로우 (점점 커지고 빨개짐)
        warn_r = bomb_size + 6 + int(8 * progress)
        warn_alpha = int(25 + 50 * progress)
        red_int = int(120 + 135 * progress)
        warn_surf = _psurf((warn_r * 2, warn_r * 2), pygame.SRCALPHA)
        pygame.draw.circle(warn_surf, (red_int, 30, 15, warn_alpha),
                         (warn_r, warn_r), warn_r)
        screen.blit(warn_surf, (bx - warn_r, by - warn_r))

        # 폭탄 몸체 (검은 원)
        pygame.draw.circle(screen, (50, 45, 40), (bx, by), bomb_size)
        pygame.draw.circle(screen, (90, 85, 75), (bx, by), bomb_size, 1)
        # 하이라이트
        pygame.draw.circle(screen, (80, 75, 70), (bx - 3, by - 3), bomb_size // 3)

        # 도화선
        fuse_tip_x = bx + int(bomb_size * 0.5)
        fuse_tip_y = by - int(bomb_size * 0.9)
        pygame.draw.line(screen, (160, 120, 60),
                        (bx + int(bomb_size * 0.3), by - int(bomb_size * 0.55)),
                        (fuse_tip_x, fuse_tip_y), 2)

        # 도화선 불꽃 (점멸)
        if int(self.bomb_timer * 10) % 2 == 0:
            spark_cols = [(255, 220, 60), (255, 150, 30), (255, 255, 120)]
            sc = spark_cols[int(self.bomb_timer * 6) % 3]
            pygame.draw.circle(screen, sc, (fuse_tip_x, fuse_tip_y - 2), 4)
            pygame.draw.circle(screen, (255, 255, 210), (fuse_tip_x, fuse_tip_y - 2), 2)

        # 카운트다운 숫자 (폭탄 중앙에 크게)
        if countdown_int > 0:
            timer_str = str(min(countdown_int, 9))
            try:
                font_size = 22 if remaining > 1.5 else 26
                font = pygame.font.Font(None, font_size)
                # 색상: 여유있으면 흰색, 급하면 빨강 점멸
                if remaining > 2.0:
                    text_color = (255, 255, 255)
                elif remaining > 1.0:
                    text_color = (255, 200, 80)
                else:
                    blink = int(self.bomb_timer * 8) % 2
                    text_color = (255, 60, 40) if blink else (255, 200, 80)
                text_surf = font.render(timer_str, True, text_color)
                # 그림자
                shadow_surf = font.render(timer_str, True, (0, 0, 0))
                screen.blit(shadow_surf, (bx - shadow_surf.get_width() // 2 + 1,
                                          by - shadow_surf.get_height() // 2 + 1))
                screen.blit(text_surf, (bx - text_surf.get_width() // 2,
                                        by - text_surf.get_height() // 2))
            except Exception:
                pass

        # 마지막 1.5초: 깜빡이는 경고 링
        if remaining < 1.5:
            blink = int(self.bomb_timer * 14) % 2
            if blink:
                ring_r = bomb_size + 3 + int(5 * _sin(self.bomb_timer * 22))
                pygame.draw.circle(screen, (255, 50, 25), (bx, by), ring_r, 2)

    def _draw_explosion(self, screen: pygame.Surface, exp: dict):
        """폭발 이펙트 렌더링 (자폭 시 약화된 버전)"""
        ex = int(exp['x'])
        ey = int(exp['y'])
        max_time = exp.get('max_time', 0.6)
        progress = min(1.0, exp['time'] / max_time)
        shockwave_radius = int(exp.get('shockwave_radius', 0))
        radius_cap = exp.get('shockwave_cap', self.EXPLOSION_RADIUS)

        # 연기 구름 (배경)
        for cloud in exp.get('smoke_clouds', []):
            life_ratio = cloud['life'] / cloud['max_life']
            size = int(cloud['size'])
            c_alpha = int(120 * life_ratio)
            if size > 0 and c_alpha > 0:
                cs = _psurf((size * 2, size * 2), pygame.SRCALPHA)
                for i in range(3):
                    r = size - i * size // 3
                    if r > 0:
                        gray = 60 + i * 25
                        a = c_alpha // (i + 1)
                        pygame.draw.circle(cs, (gray, gray, gray, a), (size, size), r)
                screen.blit(cs, (int(cloud['x']) - size, int(cloud['y']) - size))

        # 2차 쇼크웨이브 링
        for wave in exp.get('secondary_waves', []):
            wr = int(wave['radius'])
            if 0 < wr < radius_cap:
                wa = int(150 * (1 - wr / radius_cap))
                if wa > 0:
                    ws = _psurf((wr * 2 + 10, wr * 2 + 10), pygame.SRCALPHA)
                    pygame.draw.circle(ws, (255, 180, 80, wa),
                                     (wr + 5, wr + 5), wr, max(2, 8 - int(wr / 40)))
                    screen.blit(ws, (ex - wr - 5, ey - wr - 5))

        # 메인 쇼크웨이브 (굵고 화려)
        if shockwave_radius > 0 and progress < 0.6:
            wave_alpha = int(220 * (1 - progress / 0.6))
            wave_width = max(4, int(20 * (1 - progress)))
            ws = _psurf((shockwave_radius * 2 + 30, shockwave_radius * 2 + 30), pygame.SRCALPHA)
            center = shockwave_radius + 15
            pygame.draw.circle(ws, (255, 100, 30, wave_alpha // 3),
                             (center, center), shockwave_radius + 8, wave_width + 8)
            pygame.draw.circle(ws, (255, 150, 50, wave_alpha),
                             (center, center), shockwave_radius, wave_width)
            inner_r = max(1, shockwave_radius - 30)
            pygame.draw.circle(ws, (255, 230, 120, wave_alpha),
                             (center, center), inner_r, max(2, wave_width - 5))
            screen.blit(ws, (ex - shockwave_radius - 15, ey - shockwave_radius - 15))

        # 중심 플래시 (밝고 빠르게)
        if progress < 0.25:
            fp = progress / 0.25
            fr = int(150 * (1 - fp * 0.7))
            fa = int(255 * (1 - fp))
            fs = _psurf((fr * 2 + 30, fr * 2 + 30), pygame.SRCALPHA)
            fc = fr + 15
            pygame.draw.circle(fs, (255, 150, 50, fa // 2), (fc, fc), fr)
            pygame.draw.circle(fs, (255, 220, 100, fa), (fc, fc), int(fr * 0.7))
            pygame.draw.circle(fs, (255, 255, 240, min(255, fa + 30)), (fc, fc), int(fr * 0.35))
            screen.blit(fs, (ex - fr - 15, ey - fr - 15))

        # 스파크 (빠른 불꽃)
        for spark in exp.get('sparks', []):
            life_ratio = spark['life'] / spark['max_life']
            intensity = 0.7 + 0.3 * math.sin(spark['life'] * 0.8)
            sr, sg, sb = int(255 * intensity), int(220 * intensity), int(150 * intensity)
            sa = int(255 * life_ratio)
            if sa > 0:
                sx, sy = int(spark['x']), int(spark['y'])
                ss = _psurf((10, 10), pygame.SRCALPHA)
                pygame.draw.circle(ss, (sr, sg, sb, sa), (5, 5), 2)
                screen.blit(ss, (sx - 5, sy - 5))

        # 메인 파티클 (불꽃)
        for p in exp.get('particles', []):
            life_ratio = p['life'] / p.get('max_life', 30)
            size = max(1, int(p['size']))
            ct = p['color_type']
            if ct == 'fire':
                pr, pg, pb = 255, int(120 + 100 * life_ratio), int(30 * life_ratio)
            elif ct == 'spark':
                pr, pg, pb = 255, int(230 + 25 * life_ratio), int(180 + 75 * life_ratio)
            elif ct == 'ember':
                pr, pg, pb = int(200 + 55 * life_ratio), int(60 + 60 * life_ratio), int(20 * life_ratio)
            else:
                pr, pg, pb = 255, int(150 * life_ratio), int(50 * life_ratio)
            pa = int(255 * life_ratio * life_ratio)
            if size > 0 and pa > 0:
                ps = _psurf((size * 2 + 4, size * 2 + 4), pygame.SRCALPHA)
                pc = size + 2
                if size > 2:
                    pygame.draw.circle(ps, (pr, pg // 2, pb // 2, pa // 3), (pc, pc), size + 2)
                pygame.draw.circle(ps, (pr, pg, pb, pa), (pc, pc), size)
                screen.blit(ps, (int(p['x']) - size - 2, int(p['y']) - size - 2))


# ============================================================================
# 안드로이드 스킬 - 개틀링 버스트 (기관포 연사)
# ============================================================================
class GatlingBurst(HeroSkill):
    """개틀링 버스트 - 1초 견착 후 3초간 기관포 연사, 발사 중 이동속도 50% 감소"""

    GAME_TOP = 0
    GAME_BOTTOM = 750

    MOUNT_DURATION = 1.0      # 변신 준비 시간 (초) - 안드로이드 → 탱크
    FIRE_DURATION = 3.0       # 실제 발사 시간 (초)
    DISMOUNT_DURATION = 1.0   # 복귀 변환 시간 (초) - 탱크 → 안드로이드
    BULLET_SPEED = 620        # 총알 속도
    FIRE_RATE = 0.067         # 발사 간격 (초) - 초당 약 15발 (50% 증가)
    BULLET_LENGTH = 8         # 탄환 길이 (픽셀)
    BULLET_WIDTH = 3          # 탄환 폭
    KNOCKBACK_VEL = 120       # 넉백 속도
    SPREAD_ANGLE = 10         # 탄 퍼짐 (도)
    MUZZLE_FLASH_DURATION = 0.08  # 머즐 플래쉬 지속
    TRAIL_STEPS = 5           # 트레일 단계 수
    TRAIL_STEP_DT = 0.012     # 트레일 간격 (속도 기반 역추적)
    MOVE_SLOW_AMOUNT = 0.5    # 발사 중 이동속도 배율 (50% 감소)

    def __init__(self):
        super().__init__(
            skill_id="gatling_burst",
            name="Gatling Burst",
            korean_name="개틀링 버스트",
            description="무자비한 기관포 세례가 상대를 향해 쏟아진다",
            trigger=SkillTrigger.ON_BALL_HIT,
            cooldown=22.0,
            duration=5.0,   # 1초 변신 + 3초 발사 + 1초 복귀
            hero_id="android"
        )
        self.bullets = []
        self.fire_timer = 0.0
        self.caster_is_top = False
        self.hit_particles = []
        self.muzzle_flashes = []
        self.shell_casings = []    # 탄피
        self.smoke_puffs = []      # 총구 연기
        self.total_fired = 0
        self._hit_sound = None
        self._fire_sound = None
        self._recoil_offset = 0.0  # 반동 오프셋 (hero_paddles 연동)
        self._phase = 'idle'       # 'idle', 'mounting', 'firing', 'dismounting'
        self._phase_timer = 0.0    # 현재 페이즈 경과 시간
        self._gatling_loop_sound = None  # 개틀링 루프 사운드

    def _get_cannon_tip(self, caster_paddle, game_state=None):
        """탱크 모드 캐논 총구 끝 위치 계산 (aim angle 반영, hero_paddles 기하학 동일)"""
        pw = caster_paddle.width
        b = max(4, int(8 * pw / 130.0))
        cx = caster_paddle.x + pw // 2

        # 캐논 마운트 Y 위치 계산
        if self.caster_is_top:
            cy = caster_paddle.y + 28
            torso_y = cy - int(1.5 * b)
            turret_bottom = torso_y - int(1.6 * b) + int(1.4 * b)
            cannon_mount_y = turret_bottom + int(0.1 * b)
        else:
            cy = caster_paddle.y + int(2.0 * 8) - 30
            torso_y = cy - int(1.5 * b)
            turret_top = torso_y - int(1.6 * b)
            cannon_mount_y = turret_top - int(0.1 * b)

        # 조준 각도 (game_state에서 읽기, 없으면 직선 방향)
        side = 'top' if self.caster_is_top else 'bottom'
        default_angle = math.pi / 2 if self.caster_is_top else -math.pi / 2
        aim_angle = default_angle
        if game_state:
            aim_angle = game_state.get(
                f'gatling_aim_angle_{side}', default_angle)

        # 포신(1.8b) + 배럴(1.6b) = 총 3.4b 길이를 조준 방향으로 연장
        total_len = int(1.8 * b) + int(1.6 * b)
        tip_x = cx + math.cos(aim_angle) * total_len
        tip_y = cannon_mount_y + math.sin(aim_angle) * total_len

        return int(tip_x), int(tip_y)

    def _load_sounds(self):
        """사운드 로드"""
        if self._fire_sound is None:
            try:
                project_root = os.path.dirname(
                    os.path.dirname(os.path.abspath(__file__)))
                fire_path = os.path.join(
                    project_root, "sounds", "smallboyshoot.wav")
                if os.path.exists(fire_path):
                    self._fire_sound = pygame.mixer.Sound(fire_path)
                    self._fire_sound.set_volume(0.15)
                hit_path = os.path.join(
                    project_root, "sounds", "bullethit.wav")
                if os.path.exists(hit_path):
                    self._hit_sound = pygame.mixer.Sound(hit_path)
                    self._hit_sound.set_volume(0.2)
            except Exception:
                pass

    def _apply_effect(self, caster_paddle, target_paddle, ball,
                      game_state: dict) -> dict:
        self.caster_is_top = getattr(caster_paddle, 'is_top', False)
        self.bullets = []
        self.hit_particles = []
        self.muzzle_flashes = []
        self.shell_casings = []
        self.smoke_puffs = []
        self.fire_timer = 0.0
        self.total_fired = 0
        self._recoil_offset = 0.0
        self._phase = 'mounting'
        self._phase_timer = 0.0
        self._load_sounds()

        # 견착 단계 시작 - 아직 발사하지 않음
        side = 'top' if self.caster_is_top else 'bottom'
        game_state[f'gatling_mounting_{side}'] = True
        game_state[f'gatling_mount_progress_{side}'] = 0.0
        game_state[f'gatling_burst_active_{side}'] = False
        game_state[f'gatling_dismounting_{side}'] = False
        game_state[f'gatling_dismount_progress_{side}'] = 0.0

        # 탱크 변신 사운드
        try:
            project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            snd_path = os.path.join(project_root, "sounds", "tanktransform.wav")
            if os.path.exists(snd_path):
                s = pygame.mixer.Sound(snd_path)
                s.set_volume(0.7)
                s.play()
        except Exception:
            pass

        return {
            'screen_effect': ScreenEffect.FLASH,
            'flash_color': (200, 180, 120),
            'flash_duration': 0.05,
        }

    def _fire_bullet(self, caster_paddle, target_paddle, game_state):
        """총알 한 발 발사 - 탱크 캐논 총구 끝에서 발사"""
        # 탱크 캐논 총구 끝 위치에서 발사 (조준 각도 반영)
        spawn_x, spawn_y = self._get_cannon_tip(caster_paddle, game_state)

        # 적 패들 방향으로 조준 + 랜덤 퍼짐
        enemy_key = ('hero_paddle_bottom' if self.caster_is_top
                     else 'hero_paddle_top')
        hero_info = game_state.get(enemy_key)
        if hero_info:
            target_x = hero_info['x'] + hero_info['width'] / 2
            target_y = hero_info['y'] + hero_info['height'] / 2
        elif target_paddle is not None:
            target_x = target_paddle.x + target_paddle.width / 2
            target_y = target_paddle.y + target_paddle.height / 2
        else:
            target_x = spawn_x
            target_y = (self.GAME_BOTTOM if self.caster_is_top
                        else self.GAME_TOP)

        dx = target_x - spawn_x
        dy = target_y - spawn_y
        dist = math.sqrt(dx * dx + dy * dy)
        if dist < 1:
            dist = 1

        # AK-47 스타일 스프레이 (연속 발사 시 퍼짐 증가)
        burst_spread = min(self.SPREAD_ANGLE * 1.5,
                           self.SPREAD_ANGLE * (1.0 + self.total_fired * 0.02))
        spread = math.radians(
            random.uniform(-burst_spread, burst_spread))
        base_angle = math.atan2(dy, dx)
        final_angle = base_angle + spread

        vx = math.cos(final_angle) * self.BULLET_SPEED
        vy = math.sin(final_angle) * self.BULLET_SPEED

        # 트레이서탄 여부 (5발에 1발)
        is_tracer = (self.total_fired % 5 == 0)

        self.bullets.append({
            'x': float(spawn_x),
            'y': float(spawn_y),
            'vx': vx,
            'vy': vy,
            'active': True,
            'age': 0.0,
            'angle': final_angle,
            'tracer': is_tracer,
        })
        self.total_fired += 1

        # 반동 (발사마다 살짝 뒤로)
        self._recoil_offset = 3.5

        # 머즐 플래쉬 / 총구 연기는 탱크 내장 렌더러(hero_paddles)가 처리

        # 탄피 배출 (좌우 랜덤)
        eject_side = random.choice([-1, 1])
        self.shell_casings.append({
            'x': float(spawn_x),
            'y': float(spawn_y),
            'vx': eject_side * random.uniform(80, 160),
            'vy': random.uniform(-100, -30),
            'gravity': 500,
            'age': 0.0,
            'life': 0.5,
            'rotation': random.uniform(0, math.pi * 2),
            'rot_speed': random.uniform(8, 20),
        })

        # 발사 사운드 (3발에 1번)
        if self._fire_sound and self.total_fired % 3 == 1:
            self._fire_sound.play()

    def _update_active_effect(self, dt: float, caster_paddle,
                              target_paddle, ball, game_state: dict):
        side = 'top' if self.caster_is_top else 'bottom'
        caster_prefix = f'{side}_paddle'
        self._phase_timer += dt

        # === 조준 각도 계산 (탱크 캐논 회전용) ===
        if self._phase in ('mounting', 'firing', 'dismounting'):
            cx = caster_paddle.x + caster_paddle.width // 2
            cy = caster_paddle.y
            enemy_key = ('hero_paddle_bottom' if self.caster_is_top
                         else 'hero_paddle_top')
            hero_info = game_state.get(enemy_key)
            if hero_info:
                tx = hero_info['x'] + hero_info['width'] / 2
                ty = hero_info['y'] + hero_info['height'] / 2
            elif target_paddle is not None:
                tx = target_paddle.x + target_paddle.width / 2
                ty = target_paddle.y + target_paddle.height / 2
            else:
                tx = cx
                ty = (self.GAME_BOTTOM if self.caster_is_top
                      else self.GAME_TOP)
            game_state[f'gatling_aim_angle_{side}'] = math.atan2(
                ty - cy, tx - cx)

        # === 견착 단계 (1초) ===
        if self._phase == 'mounting':
            progress = min(1.0, self._phase_timer / self.MOUNT_DURATION)
            game_state[f'gatling_mount_progress_{side}'] = progress

            # 견착 중 이동속도 점진적 감소 (0% → 50% 감소)
            game_state[f'{caster_prefix}_slowed'] = True
            game_state[f'{caster_prefix}_slow_amount'] = 1.0 - (0.5 * progress)

            if self._phase_timer >= self.MOUNT_DURATION:
                # 견착 완료 → 발사 단계 전환
                self._phase = 'firing'
                self._phase_timer = 0.0
                game_state[f'gatling_mounting_{side}'] = False
                game_state[f'gatling_burst_active_{side}'] = True
                # 발사 시작 플래시
                game_state['screen_shake'] = 3
                game_state['shake_duration'] = 0.15
                # 개틀링 루프 사운드 시작
                try:
                    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                    snd_path = os.path.join(project_root, "sounds", "gatling.wav")
                    if os.path.exists(snd_path):
                        self._gatling_loop_sound = pygame.mixer.Sound(snd_path)
                        self._gatling_loop_sound.set_volume(0.7)
                        self._gatling_loop_sound.play(-1)  # 무한 반복
                except Exception:
                    pass
            return  # 견착 중에는 총알 발사 안함

        # === 해체/복귀 단계 (1초) - 탱크 → 안드로이드 역변환 ===
        if self._phase == 'dismounting':
            progress = min(1.0, self._phase_timer / self.DISMOUNT_DURATION)
            game_state[f'gatling_dismount_progress_{side}'] = progress
            # 해체 중에도 기존 이펙트는 계속 업데이트 (아래 공통 코드로 진행)

        # === 발사 단계 (3초) - 발사 전용 코드 ===
        if self._phase == 'firing':
            # 발사 중 이동속도 50% 감소
            game_state[f'{caster_prefix}_slowed'] = True
            game_state[f'{caster_prefix}_slow_amount'] = self.MOVE_SLOW_AMOUNT

            # 발사 타이머
            self.fire_timer += dt
            if self.fire_timer >= self.FIRE_RATE:
                self.fire_timer -= self.FIRE_RATE
                self._fire_bullet(caster_paddle, target_paddle, game_state)

            # 반동 감쇠
            if self._recoil_offset > 0:
                self._recoil_offset = max(0, self._recoil_offset - dt * 35)

            # 반동 값을 game_state에 전달 (hero_paddles.py 연동)
            game_state[f'gatling_recoil_{side}'] = self._recoil_offset

            # 발사 시간 초과 → 해체/복귀 단계 전환
            if self._phase_timer >= self.FIRE_DURATION:
                self._phase = 'dismounting'
                self._phase_timer = 0.0
                game_state[f'gatling_burst_active_{side}'] = False
                game_state[f'gatling_dismounting_{side}'] = True
                game_state[f'gatling_dismount_progress_{side}'] = 0.0
                game_state[f'{caster_prefix}_slowed'] = False
                game_state[f'{caster_prefix}_slow_amount'] = 1.0
                game_state[f'gatling_recoil_{side}'] = 0
                # 개틀링 루프 사운드 즉시 정지
                if self._gatling_loop_sound:
                    self._gatling_loop_sound.stop()
                    self._gatling_loop_sound = None
                # 탱크 해체 사운드
                try:
                    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                    snd_path = os.path.join(project_root, "sounds", "tanktransform.wav")
                    if os.path.exists(snd_path):
                        s = pygame.mixer.Sound(snd_path)
                        s.set_volume(0.7)
                        s.play()
                except Exception:
                    pass

        # === 총알 & 이펙트 업데이트 (발사/해체 공통) ===

        # 총알 업데이트
        new_bullets = []
        for bullet in self.bullets:
            if not bullet['active']:
                continue

            bullet['x'] += bullet['vx'] * dt
            bullet['y'] += bullet['vy'] * dt
            bullet['age'] += dt

            # 화면 밖 제거
            if (bullet['x'] < self.GAME_LEFT - 20
                    or bullet['x'] > self.GAME_RIGHT + 20
                    or bullet['y'] < self.GAME_TOP - 20
                    or bullet['y'] > self.GAME_BOTTOM + 20):
                continue

            # 수명 초과
            if bullet['age'] > 2.0:
                continue

            # 적 패들 충돌 체크
            target_is_top = not self.caster_is_top
            enemy_key = ('hero_paddle_top' if target_is_top
                         else 'hero_paddle_bottom')
            hero_info = game_state.get(enemy_key)

            hit = False
            if hero_info:
                paddle_cx = hero_info['x'] + hero_info['width'] / 2
                paddle_cy = hero_info['y'] + hero_info['height'] / 2
                hit_dist = math.sqrt(
                    (bullet['x'] - paddle_cx) ** 2
                    + (bullet['y'] - paddle_cy) ** 2)
                if hit_dist < (hero_info['width'] / 2 + 10):
                    hit = True
            elif (target_paddle is not None
                  and not getattr(target_paddle, 'is_bodyguard', False)):
                paddle_cx = (target_paddle.x
                            + target_paddle.width / 2)
                paddle_cy = (target_paddle.y
                            + target_paddle.height / 2)
                hit_dist = math.sqrt(
                    (bullet['x'] - paddle_cx) ** 2
                    + (bullet['y'] - paddle_cy) ** 2)
                if hit_dist < (target_paddle.width / 2 + 10):
                    hit = True

            if hit:
                # 마법결계 면역 체크
                _imm_side = 'top' if target_is_top else 'bottom'
                if game_state.get(
                        f'magic_immunity_{_imm_side}', False):
                    # 패링 이펙트 이벤트 전달 (중복 방지: 프레임당 1회만)
                    _block_events = game_state.get('barrier_block_events', [])
                    _already_has = any(e.get('skill_korean_name') == self.korean_name for e in _block_events)
                    if not _already_has:
                        if 'barrier_block_events' not in game_state:
                            game_state['barrier_block_events'] = []
                        game_state['barrier_block_events'].append({
                            'skill_korean_name': self.korean_name,
                            'caster_is_top': self.caster_is_top,
                            'caster_x': caster_paddle.x + getattr(caster_paddle, 'width', 80) / 2,
                            'caster_y': caster_paddle.y + getattr(caster_paddle, 'height', 10) / 2,
                            'target_x': target_paddle.x + getattr(target_paddle, 'width', 80) / 2,
                            'target_y': target_paddle.y + getattr(target_paddle, 'height', 10) / 2,
                        })
                else:
                    knockback_dir = (1 if bullet['vx'] > 0
                                    else -1)
                    if abs(bullet['vx']) < 10:
                        knockback_dir = random.choice([-1, 1])

                    # 벽 반사 넉백: 벽에 몰려있으면 반대로 튕겨냄
                    if target_paddle is not None:
                        _wall_margin = 15
                        _near_left = (target_paddle.x
                                      <= 80 + _wall_margin)
                        _near_right = (target_paddle.x
                                       + target_paddle.width
                                       >= 680 - _wall_margin)
                        if _near_left and knockback_dir == -1:
                            knockback_dir = 1  # 왼쪽 벽 → 오른쪽으로 튕김
                        elif _near_right and knockback_dir == 1:
                            knockback_dir = -1  # 오른쪽 벽 → 왼쪽으로 튕김

                    target_prefix = ('top_paddle' if target_is_top
                                     else 'bottom_paddle')
                    game_state[
                        f'{target_prefix}_knockback'] = True
                    game_state[
                        f'{target_prefix}_knockback_dir'
                    ] = knockback_dir
                    game_state[
                        f'{target_prefix}_knockback_vel'
                    ] = self.KNOCKBACK_VEL

                # 히트 스파크 (금속 충돌감)
                hit_angle = bullet['angle']
                for _ in range(8):
                    spread_a = hit_angle + math.pi + random.uniform(-1.2, 1.2)
                    spd = random.uniform(100, 300)
                    self.hit_particles.append({
                        'x': bullet['x'],
                        'y': bullet['y'],
                        'vx': math.cos(spread_a) * spd,
                        'vy': math.sin(spread_a) * spd,
                        'life': random.uniform(0.15, 0.35),
                        'age': 0.0,
                        'size': random.uniform(1.5, 4),
                        'type': random.choice(['spark', 'spark', 'ember']),
                    })

                # 히트 사운드 (5발에 1번)
                if self._hit_sound and self.total_fired % 5 == 0:
                    self._hit_sound.play()

                continue  # 총알 소멸

            new_bullets.append(bullet)

        self.bullets = new_bullets

        # 머즐 플래쉬 업데이트
        self.muzzle_flashes = [
            f for f in self.muzzle_flashes
            if (f.__setitem__('timer', f['timer'] - dt) or True)
            and f['timer'] > 0
        ]

        # 히트 파티클 업데이트
        new_particles = []
        for p in self.hit_particles:
            p['age'] += dt
            p['x'] += p['vx'] * dt
            p['y'] += p['vy'] * dt
            p['vy'] += 200 * dt  # 약간의 중력
            if p['age'] < p['life']:
                new_particles.append(p)
        self.hit_particles = new_particles

        # 탄피 업데이트
        new_casings = []
        for c in self.shell_casings:
            c['age'] += dt
            c['x'] += c['vx'] * dt
            c['y'] += c['vy'] * dt
            c['vy'] += c['gravity'] * dt
            c['rotation'] += c['rot_speed'] * dt
            c['vx'] *= 0.97  # 공기 저항
            if c['age'] < c['life']:
                new_casings.append(c)
        self.shell_casings = new_casings

        # 연기 업데이트
        new_smoke = []
        for s in self.smoke_puffs:
            s['age'] += dt
            s['x'] += s['vx'] * dt
            s['y'] += s['vy'] * dt
            s['vx'] *= 0.92
            s['vy'] *= 0.92
            s['size'] += dt * 12  # 연기 확산
            if s['age'] < s['life']:
                new_smoke.append(s)
        self.smoke_puffs = new_smoke

    def _end_effect(self, caster_paddle, target_paddle, ball,
                    game_state: dict):
        side = 'top' if self.caster_is_top else 'bottom'
        caster_prefix = f'{side}_paddle'
        game_state[f'gatling_burst_active_{side}'] = False
        game_state[f'gatling_mounting_{side}'] = False
        game_state[f'gatling_mount_progress_{side}'] = 0.0
        game_state[f'gatling_dismounting_{side}'] = False
        game_state[f'gatling_dismount_progress_{side}'] = 0.0
        game_state[f'gatling_recoil_{side}'] = 0
        # 이동속도 감소 해제
        game_state[f'{caster_prefix}_slowed'] = False
        game_state[f'{caster_prefix}_slow_amount'] = 1.0
        self._phase = 'idle'
        self._phase_timer = 0.0
        # 개틀링 루프 사운드 정지
        if self._gatling_loop_sound:
            self._gatling_loop_sound.stop()
            self._gatling_loop_sound = None
        # 모든 이펙트 즉시 제거 (잔류 방지)
        self.bullets = []
        self.hit_particles = []
        self.muzzle_flashes = []
        self.shell_casings = []
        self.smoke_puffs = []

    def reset_for_new_round(self, game_state: dict):
        super().reset_for_new_round(game_state)
        # 개틀링 루프 사운드 정지
        if self._gatling_loop_sound:
            self._gatling_loop_sound.stop()
            self._gatling_loop_sound = None
        self.bullets = []
        self.hit_particles = []
        self.muzzle_flashes = []
        self.shell_casings = []
        self.smoke_puffs = []
        self.fire_timer = 0.0
        self.total_fired = 0
        self._recoil_offset = 0.0
        self._phase = 'idle'
        self._phase_timer = 0.0
        for side in ['top', 'bottom']:
            game_state[f'gatling_burst_active_{side}'] = False
            game_state[f'gatling_mounting_{side}'] = False
            game_state[f'gatling_mount_progress_{side}'] = 0.0
            game_state[f'gatling_dismounting_{side}'] = False
            game_state[f'gatling_dismount_progress_{side}'] = 0.0
            game_state[f'gatling_recoil_{side}'] = 0

    def draw(self, screen: pygame.Surface, caster_paddle,
             target_paddle, ball, game_state: dict):
        if (not self.is_active and not self.bullets
                and not self.hit_particles and not self.shell_casings
                and not self.smoke_puffs):
            return

        # --- 견착 단계 게이지 바 (탱크 변신 비주얼은 hero_paddles에서 처리) ---
        if self._phase == 'mounting':
            side = 'top' if self.caster_is_top else 'bottom'
            progress = game_state.get(f'gatling_mount_progress_{side}', 0.0)
            # 캐논 총구 끝 위치 기준으로 게이지 바 표시
            tip_x, tip_y = self._get_cannon_tip(caster_paddle, game_state)

            # "LOADING" 게이지 바
            bar_w = 40
            bar_h = 4
            bar_x = tip_x - bar_w // 2
            bar_y = tip_y + (12 if self.caster_is_top else -12)
            # 배경
            bar_bg = _psurf((bar_w + 2, bar_h + 2), pygame.SRCALPHA)
            pygame.draw.rect(bar_bg, (0, 0, 0, 120), (0, 0, bar_w + 2, bar_h + 2), border_radius=2)
            screen.blit(bar_bg, (bar_x - 1, bar_y - 1))
            # 게이지
            fill_w = int(bar_w * progress)
            if fill_w > 0:
                # 색상: 빨강 → 주황 → 초록
                if progress < 0.5:
                    gc = (255, int(100 + 155 * progress * 2), 50)
                else:
                    gc = (int(255 * (1 - (progress - 0.5) * 2)), 255, 50)
                bar_fill = _psurf((fill_w, bar_h), pygame.SRCALPHA)
                pygame.draw.rect(bar_fill, (*gc, 200), (0, 0, fill_w, bar_h), border_radius=1)
                screen.blit(bar_fill, (bar_x, bar_y))

        # --- 총구 연기 / 머즐 플래쉬는 탱크 내장 렌더러(hero_paddles)가 처리 ---

        # --- 총알 (속도 기반 트레일 - 저장 없이 즉석 계산) ---
        for bullet in self.bullets:
            if not bullet['active']:
                continue

            bx, by = bullet['x'], bullet['y']
            vx, vy = bullet['vx'], bullet['vy']
            angle = bullet['angle']
            cos_a = math.cos(angle)
            sin_a = math.sin(angle)
            is_tracer = bullet.get('tracer', False)

            # 트레일 (속도 역추적 방식 - 잔류 버그 없음)
            for i in range(self.TRAIL_STEPS):
                t = (i + 1) * self.TRAIL_STEP_DT
                tx = bx - vx * t
                ty = by - vy * t
                trail_alpha = int((100 - i * 20) * (0.8 if not is_tracer else 1.0))
                trail_w = max(1, self.BULLET_WIDTH - i)
                if trail_alpha > 0 and trail_w > 0:
                    ts = _psurf(
                        (trail_w * 2 + 2, trail_w * 2 + 2), pygame.SRCALPHA)
                    color = (255, 180, 60, trail_alpha) if not is_tracer \
                        else (255, 100, 100, trail_alpha)
                    pygame.draw.circle(ts, color,
                        (trail_w + 1, trail_w + 1), trail_w)
                    screen.blit(ts,
                        (int(tx) - trail_w - 1, int(ty) - trail_w - 1))

            # 총알 본체 (길쭉한 탄환 형태)
            ibx, iby = int(bx), int(by)
            tip_x = ibx + int(cos_a * self.BULLET_LENGTH // 2)
            tip_y = iby + int(sin_a * self.BULLET_LENGTH // 2)
            tail_x = ibx - int(cos_a * self.BULLET_LENGTH // 2)
            tail_y = iby - int(sin_a * self.BULLET_LENGTH // 2)

            # 탄환 글로우 (SRCALPHA 서페이스)
            glow_r = 8 if is_tracer else 6
            gs = _psurf(
                (glow_r * 2, glow_r * 2), pygame.SRCALPHA)
            glow_color = (255, 120, 80, 80) if is_tracer \
                else (255, 200, 100, 60)
            pygame.draw.circle(gs, glow_color,
                (glow_r, glow_r), glow_r)
            screen.blit(gs, (ibx - glow_r, iby - glow_r),
                special_flags=pygame.BLEND_ADD)

            # 탄환 본체 (라인)
            if is_tracer:
                # 트레이서탄: 붉은 광선
                pygame.draw.line(screen, (255, 100, 80),
                    (tail_x, tail_y), (tip_x, tip_y),
                    self.BULLET_WIDTH + 1)
                pygame.draw.line(screen, (255, 200, 180),
                    (tail_x, tail_y), (tip_x, tip_y),
                    max(1, self.BULLET_WIDTH - 1))
            else:
                # 일반탄: 노란 금속탄
                pygame.draw.line(screen, (200, 170, 80),
                    (tail_x, tail_y), (tip_x, tip_y),
                    self.BULLET_WIDTH + 1)
                pygame.draw.line(screen, (255, 240, 180),
                    (tail_x, tail_y), (tip_x, tip_y),
                    max(1, self.BULLET_WIDTH - 1))
            # 탄두 하이라이트
            pygame.draw.circle(screen, (255, 255, 230),
                (tip_x, tip_y), max(1, self.BULLET_WIDTH // 2))

        # --- 탄피 ---
        for c in self.shell_casings:
            ratio = 1.0 - c['age'] / c['life']
            if ratio > 0:
                cx_i, cy_i = int(c['x']), int(c['y'])
                alpha = int(180 * ratio)
                rot = c['rotation']
                # 작은 금색 탄피 (회전하는 사각형)
                casing_len = 4
                casing_w = 2
                dx = int(math.cos(rot) * casing_len)
                dy = int(math.sin(rot) * casing_len)
                cs_surf = _psurf((12, 12), pygame.SRCALPHA)
                pygame.draw.line(cs_surf, (220, 180, 60, alpha),
                    (6 - dx, 6 - dy), (6 + dx, 6 + dy), casing_w)
                pygame.draw.circle(cs_surf, (255, 220, 100, min(255, alpha + 40)),
                    (6 + dx, 6 + dy), 1)
                screen.blit(cs_surf, (cx_i - 6, cy_i - 6))

        # --- 히트 스파크 (금속 충돌) ---
        for p in self.hit_particles:
            ratio = 1.0 - p['age'] / p['life']
            if ratio <= 0:
                continue
            px, py = int(p['x']), int(p['y'])
            sz = max(1, int(p['size'] * ratio))
            alpha = int(255 * ratio)

            if p.get('type') == 'ember':
                # 잔불 (어두운 주황, 느리게 사라짐)
                es = _psurf((sz * 2 + 2, sz * 2 + 2), pygame.SRCALPHA)
                pygame.draw.circle(es, (255, 120, 30, min(255, alpha)),
                    (sz + 1, sz + 1), sz)
                screen.blit(es, (px - sz - 1, py - sz - 1),
                    special_flags=pygame.BLEND_ADD)
            else:
                # 금속 스파크 (밝은 선형 궤적)
                prev_x = px - int(p['vx'] * 0.02)
                prev_y = py - int(p['vy'] * 0.02)
                spark_colors = [(255, 240, 180), (255, 200, 100), (255, 255, 220)]
                sc = spark_colors[hash((px, py)) % len(spark_colors)]
                pygame.draw.line(screen, sc,
                    (prev_x, prev_y), (px, py),
                    max(1, sz))


# ============================================================================
# 세트 스킬 - 사막의 환술사 (트릭키)
# ============================================================================
class SandPrison(HeroSkill):
    """모래감옥 - 상대의 이동 범위를 200~300px(랜덤)로 제한하는 사각형 모래 감옥 (건설/해체 애니메이션)"""

    PRISON_HALF_RANGE_MIN = 100  # 최소 ±100px = 200px
    PRISON_HALF_RANGE_MAX = 150  # 최대 ±150px = 300px

    BUILD_DURATION = 1.0      # 건설 애니메이션 (초)
    ACTIVE_DURATION = 2.0     # 실제 이동 제한 시간
    DISSOLVE_DURATION = 1.0   # 해체 애니메이션 (초)

    def __init__(self):
        # 총 duration = 건설 + 활성 + 해체
        total_dur = self.BUILD_DURATION + self.ACTIVE_DURATION + self.DISSOLVE_DURATION
        super().__init__(
            skill_id="sand_prison",
            name="Sand Prison",
            korean_name="모래감옥",
            description="사막의 모래가 상대를 가두어 움직임을 봉쇄한다",
            trigger=SkillTrigger.ON_COOLDOWN,
            cooldown=20.0,
            duration=total_dur,
            hero_id="mirage"
        )
        self.prison_center_x = 380
        self.prison_half_range = self.PRISON_HALF_RANGE_MAX  # 발동 시 랜덤 결정
        self.prison_y_top = 0
        self.prison_y_bot = 100
        self.sand_particles = []
        self.body_particles = []   # 시전자 몸 → 감옥 방향 모래 가루
        self.wall_alpha = 0
        self.target_is_top = False
        self._sound_loaded = False
        self._sound = None
        self.elapsed = 0.0      # 경과 시간
        self.phase = 'idle'     # 'building', 'active', 'dissolving', 'idle'

    def _load_sound(self):
        if self._sound_loaded:
            return
        self._sound_loaded = True
        try:
            import os
            project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            sound_path = os.path.join(project_root, "sounds", "prisonopen.wav")
            if os.path.exists(sound_path):
                self._sound = pygame.mixer.Sound(sound_path)
                self._sound.set_volume(0.5)
        except Exception:
            pass

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        """감옥 활성화 - 상대 현재 위치 중심으로 200~300px 랜덤 제한 (건설 시작)"""
        self.target_is_top = target_paddle.is_top

        # 발동마다 감옥 크기 랜덤 결정 (200~300px)
        self.prison_half_range = random.randint(self.PRISON_HALF_RANGE_MIN, self.PRISON_HALF_RANGE_MAX)

        opp_x = target_paddle.x + getattr(target_paddle, 'width', 80) // 2
        self.prison_center_x = opp_x

        # 경계 클램핑
        self.prison_center_x = max(self.GAME_LEFT + self.prison_half_range,
                                    min(self.GAME_RIGHT - self.prison_half_range,
                                        self.prison_center_x))

        target_y = getattr(target_paddle, 'y', 375)
        if target_paddle.is_top:
            self.prison_y_top = max(0, target_y - 50)
            self.prison_y_bot = target_y + 80
        else:
            self.prison_y_top = target_y - 50
            self.prison_y_bot = min(750, target_y + 80)

        self.sand_particles = []
        self.body_particles = []
        self.wall_alpha = 0
        self.elapsed = 0.0
        self.phase = 'building'

        # 건설 중에는 아직 이동 제한 안 함 (game_state는 building 완료 후 설정)

        # 사운드
        self._load_sound()
        if self._sound:
            try:
                self._sound.play()
            except Exception:
                pass

        return {'screen_effect': ScreenEffect.SHAKE}

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        """감옥 건설/유지/해체 - 페이즈별 업데이트"""
        self.elapsed += dt

        left_wall = self.prison_center_x - self.prison_half_range
        right_wall = self.prison_center_x + self.prison_half_range

        # ── 페이즈 전환 ──
        if self.elapsed < self.BUILD_DURATION:
            self.phase = 'building'
            build_progress = self.elapsed / self.BUILD_DURATION
            # ease-out
            self._build_progress = 1.0 - (1.0 - build_progress) ** 2.5
            self.wall_alpha = min(200, int(200 * self._build_progress))

            # 건설 중 이동 제한: 50% 이상 건설되면 시작
            if self._build_progress >= 0.5:
                self._set_prison_state(game_state, True)
                self._clamp_paddle(target_paddle, left_wall, right_wall)

            # 건설 파티클: 바닥에서 모래가 솟구침
            py_bot = self.prison_y_bot
            for _ in range(3):
                spawn_x = random.uniform(left_wall, right_wall)
                self.sand_particles.append({
                    'x': spawn_x,
                    'y': py_bot + random.uniform(-5, 5),
                    'vy': random.uniform(-60, -120) * self._build_progress,
                    'alpha': random.randint(150, 240),
                    'size': random.uniform(2, 6),
                    'life': random.uniform(0.5, 1.0),
                })
            # 벽 기둥 건설 파티클
            if random.random() < 0.5:
                for wall_x in [left_wall, right_wall]:
                    self.sand_particles.append({
                        'x': wall_x + random.uniform(-6, 6),
                        'y': py_bot - random.uniform(0, (py_bot - self.prison_y_top) * self._build_progress),
                        'vy': random.uniform(-30, -70),
                        'alpha': random.randint(130, 220),
                        'size': random.uniform(3, 5),
                        'life': random.uniform(0.4, 0.8),
                    })

            # ── 시전자 몸에서 감옥 방향으로 흐르는 모래 가루 ──
            caster_cx = caster_paddle.x + getattr(caster_paddle, 'width', 80) // 2
            caster_cy = getattr(caster_paddle, 'y', 375)
            prison_mid_y = (self.prison_y_top + py_bot) * 0.5
            # 건설 초반에 더 많이, 후반에 줄어듦
            spawn_count = max(1, int(4 * (1.0 - self._build_progress * 0.6)))
            for _ in range(spawn_count):
                # 몸 주변 랜덤 오프셋에서 출발
                start_x = caster_cx + random.uniform(-12, 12)
                start_y = caster_cy + random.uniform(-8, 8)
                # 도착점: 감옥 벽 또는 감옥 내부 랜덤 지점
                if random.random() < 0.6:
                    # 벽 쪽으로
                    dest_x = random.choice([left_wall, right_wall]) + random.uniform(-6, 6)
                else:
                    # 감옥 영역 내부
                    dest_x = random.uniform(left_wall, right_wall)
                dest_y = random.uniform(self.prison_y_top, py_bot)
                # 이동 시간
                travel_time = random.uniform(0.5, 0.9)
                dx = dest_x - start_x
                dy = dest_y - start_y
                init_alpha = random.randint(160, 240)
                self.body_particles.append({
                    'x': start_x,
                    'y': start_y,
                    'vx': dx / travel_time,
                    'vy': dy / travel_time,
                    'alpha': init_alpha,
                    'init_alpha': init_alpha,
                    'size': random.uniform(1.5, 4.0),
                    'life': travel_time,
                    'max_life': travel_time,
                })

        elif self.elapsed < self.BUILD_DURATION + self.ACTIVE_DURATION:
            self.phase = 'active'
            self._build_progress = 1.0
            if self.wall_alpha < 200:
                self.wall_alpha = 200

            self._set_prison_state(game_state, True)
            self._clamp_paddle(target_paddle, left_wall, right_wall)

            # 활성 파티클 (벽면 + 바닥)
            py_top = self.prison_y_top
            py_bot = self.prison_y_bot
            if random.random() < 0.4:
                for wall_x in [left_wall, right_wall]:
                    self.sand_particles.append({
                        'x': wall_x + random.uniform(-4, 4),
                        'y': random.uniform(py_top, py_bot),
                        'vy': random.uniform(-30, -60),
                        'alpha': random.randint(120, 220),
                        'size': random.uniform(2, 5),
                        'life': 1.0,
                    })
            if random.random() < 0.2:
                self.sand_particles.append({
                    'x': random.uniform(left_wall, right_wall),
                    'y': random.uniform(py_bot - 10, py_bot),
                    'vy': random.uniform(-20, -50),
                    'alpha': random.randint(80, 150),
                    'size': random.uniform(3, 6),
                    'life': 0.8,
                })

        else:
            self.phase = 'dissolving'
            dissolve_elapsed = self.elapsed - self.BUILD_DURATION - self.ACTIVE_DURATION
            dissolve_progress = min(1.0, dissolve_elapsed / self.DISSOLVE_DURATION)
            # ease-in (처음 느리다가 빨라짐)
            self._dissolve_progress = dissolve_progress ** 2.0
            self.wall_alpha = max(0, int(200 * (1.0 - self._dissolve_progress)))

            # 해체 시 이동 제한 해제
            self._set_prison_state(game_state, False)

            # 해체 파티클: 벽이 바닥으로 흘러내리는 모래
            py_bot = self.prison_y_bot
            visible_h = (self.prison_y_bot - self.prison_y_top) * (1.0 - self._dissolve_progress)
            if visible_h > 5:
                for _ in range(2):
                    for wall_x in [left_wall, right_wall]:
                        self.sand_particles.append({
                            'x': wall_x + random.uniform(-8, 8),
                            'y': py_bot - visible_h + random.uniform(-5, 5),
                            'vy': random.uniform(20, 60),  # 아래로 흘러내림
                            'alpha': random.randint(100, 200),
                            'size': random.uniform(2, 5),
                            'life': random.uniform(0.4, 0.8),
                        })
                # 바닥에 쌓이는 모래 파티클
                if random.random() < 0.4:
                    self.sand_particles.append({
                        'x': random.uniform(left_wall, right_wall),
                        'y': py_bot + random.uniform(-3, 3),
                        'vy': random.uniform(-5, 5),
                        'alpha': random.randint(80, 140),
                        'size': random.uniform(3, 7),
                        'life': random.uniform(0.6, 1.2),
                    })

        # 파티클 업데이트
        for p in self.sand_particles:
            p['y'] += p['vy'] * dt
            p['life'] -= dt * 0.9
            p['alpha'] = max(0, int(p['alpha'] * max(0, p['life'])))
        self.sand_particles = [p for p in self.sand_particles if p['life'] > 0]

        # 몸 → 감옥 파티클 업데이트
        for p in self.body_particles:
            p['x'] += p['vx'] * dt
            p['y'] += p['vy'] * dt
            p['life'] -= dt
            # 도착에 가까워질수록 서서히 투명해짐
            progress = 1.0 - max(0, p['life'] / p['max_life'])
            # 출발 시 밝아지다가 → 중간 유지 → 도착 즈음 사라짐
            if progress < 0.2:
                fade = progress / 0.2
            elif progress > 0.75:
                fade = (1.0 - progress) / 0.25
            else:
                fade = 1.0
            p['alpha'] = max(0, int(p['init_alpha'] * fade))
            # 도착 근처에서 크기 줄어듦
            if progress > 0.8:
                p['size'] = max(0.5, p['size'] * 0.95)
        self.body_particles = [p for p in self.body_particles if p['life'] > 0]

    def _set_prison_state(self, game_state: dict, active: bool):
        """game_state 감옥 플래그 설정/해제"""
        target_prefix = 'top_paddle' if self.target_is_top else 'bottom_paddle'
        game_state[f'{target_prefix}_sand_prison'] = active
        if active:
            game_state['sand_prison_center_x'] = self.prison_center_x
            game_state['sand_prison_range'] = self.prison_half_range
            game_state['sand_prison_target_is_top'] = self.target_is_top
        else:
            game_state.pop('sand_prison_center_x', None)
            game_state.pop('sand_prison_range', None)
            game_state.pop('sand_prison_target_is_top', None)

    def _clamp_paddle(self, target_paddle, left_wall, right_wall):
        """패들 위치 강제 클램핑"""
        paddle_width = getattr(target_paddle, 'width', 80)
        if target_paddle.x < left_wall:
            target_paddle.x = left_wall
        elif target_paddle.x > right_wall - paddle_width:
            target_paddle.x = right_wall - paddle_width

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        """감옥 해제 (duration 만료)"""
        self._set_prison_state(game_state, False)
        self.sand_particles = []
        self.body_particles = []
        self.wall_alpha = 0
        self.phase = 'idle'
        self.elapsed = 0.0

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        """모래 감옥 시각 효과 (건설/해체 애니메이션 포함)"""
        if not self.is_active:
            return

        left_wall = self.prison_center_x - self.prison_half_range
        right_wall = self.prison_center_x + self.prison_half_range
        py_top = self.prison_y_top
        py_bot = self.prison_y_bot
        full_h = py_bot - py_top
        alpha = int(self.wall_alpha)
        floor_w = int(self.prison_half_range * 2)

        # 건설/해체 진행도에 따른 가시 높이 계산
        if self.phase == 'building':
            visible_ratio = getattr(self, '_build_progress', 0.0)
        elif self.phase == 'dissolving':
            visible_ratio = 1.0 - getattr(self, '_dissolve_progress', 0.0)
        else:
            visible_ratio = 1.0

        visible_h = max(0, int(full_h * visible_ratio))
        if visible_h < 2 and alpha < 5:
            # 파티클만 그리기
            self._draw_body_particles(screen)
            self._draw_particles(screen)
            return

        # 벽은 바닥(py_bot)에서 위로 올라옴
        draw_top = py_bot - visible_h
        draw_h = visible_h

        # 감옥 영역 바닥 (연한 모래색)
        if draw_h > 0:
            floor_alpha = max(0, min(40, int(22 * visible_ratio)))
            floor_surf = _psurf((floor_w, draw_h), pygame.SRCALPHA)
            floor_surf.fill((210, 180, 100, floor_alpha))
            screen.blit(floor_surf, (int(left_wall), int(draw_top)))

        # 모래 벽 (양쪽)
        if draw_h > 3:
            for wall_x in [left_wall, right_wall]:
                wall_surf = _psurf((8, draw_h), pygame.SRCALPHA)
                for y in range(0, draw_h, 3):
                    r = random.randint(185, 220)
                    g = random.randint(155, 180)
                    bv = random.randint(80, 110)
                    h = random.randint(2, 4)
                    pygame.draw.rect(wall_surf, (r, g, bv, alpha), (1, y, 6, h))
                screen.blit(wall_surf, (int(wall_x) - 4, int(draw_top)))

                # 벽 글로우
                if draw_h > 20:
                    glow_h = min(30, draw_h - 5)
                    glow_surf = _psurf((24, glow_h), pygame.SRCALPHA)
                    for gy in range(glow_h):
                        ga = int(alpha * 0.3 * (1 - gy / glow_h))
                        pygame.draw.line(glow_surf, (220, 190, 120, ga), (0, gy), (24, gy))
                    screen.blit(glow_surf, (int(wall_x) - 12, int(draw_top + draw_h // 2 - glow_h // 2)))

        # 상단/하단 장식 바
        if draw_h > 5:
            bar_positions = []
            if visible_ratio > 0.9:
                bar_positions.append(draw_top)  # 상단 바 (거의 완성 시만)
            bar_positions.append(py_bot - 5)    # 하단 바 (항상)
            for bar_y in bar_positions:
                bar_surf = _psurf((floor_w + 8, 5), pygame.SRCALPHA)
                for bx in range(0, floor_w + 8, 3):
                    r = random.randint(185, 220)
                    g = random.randint(155, 180)
                    bv = random.randint(80, 110)
                    pygame.draw.rect(bar_surf, (r, g, bv, alpha), (bx, 0, 3, 5))
                screen.blit(bar_surf, (int(left_wall) - 4, int(bar_y)))

        # 모서리 장식
        if visible_ratio > 0.8:
            corner_r = 6
            corner_alpha = int(alpha * 0.7 * min(1.0, (visible_ratio - 0.8) / 0.2))
            for cx_pos in [left_wall, right_wall]:
                for cy_pos in [draw_top, py_bot]:
                    cs = _psurf((corner_r * 2, corner_r * 2), pygame.SRCALPHA)
                    pygame.draw.circle(cs, (200, 170, 90, corner_alpha),
                                     (corner_r, corner_r), corner_r)
                    screen.blit(cs, (int(cx_pos) - corner_r, int(cy_pos) - corner_r))

        # 몸 → 감옥 모래 가루 파티클
        self._draw_body_particles(screen)

        # 파티클
        self._draw_particles(screen)

    def _draw_particles(self, screen):
        """모래 파티클 렌더링"""
        for p in self.sand_particles:
            a = max(0, min(255, int(p['alpha'])))
            if a > 10:
                sz = max(1, int(p['size']))
                ps = _psurf((sz * 2, sz * 2), pygame.SRCALPHA)
                pygame.draw.circle(ps, (215, 185, 105, a), (sz, sz), sz)
                screen.blit(ps, (int(p['x'] - sz), int(p['y'] - sz)))

    def _draw_body_particles(self, screen):
        """시전자 몸 → 감옥 방향 모래 가루 파티클 렌더링"""
        for p in self.body_particles:
            a = max(0, min(255, int(p['alpha'])))
            if a > 10:
                sz = max(1, int(p['size']))
                progress = 1.0 - max(0, p['life'] / p['max_life'])
                # 색상: 밝은 금모래에서 어두운 모래색으로 변화
                r = int(230 - 30 * progress)
                g = int(200 - 25 * progress)
                bv = int(110 - 20 * progress)
                ps = _psurf((sz * 2, sz * 2), pygame.SRCALPHA)
                pygame.draw.circle(ps, (r, g, bv, a), (sz, sz), sz)
                screen.blit(ps, (int(p['x'] - sz), int(p['y'] - sz)))
                # 꼬리 잔상 (이동 방향 반대편에 작은 점)
                if sz > 1 and progress < 0.8:
                    tail_sz = max(1, sz - 1)
                    tail_a = max(0, a // 3)
                    ts = _psurf((tail_sz * 2, tail_sz * 2), pygame.SRCALPHA)
                    pygame.draw.circle(ts, (r, g, bv, tail_a), (tail_sz, tail_sz), tail_sz)
                    # 꼬리 위치 = 속도 반대 방향으로 약간 뒤
                    spd = (p['vx'] ** 2 + p['vy'] ** 2) ** 0.5
                    if spd > 1:
                        tail_off_x = -p['vx'] / spd * sz * 1.5
                        tail_off_y = -p['vy'] / spd * sz * 1.5
                        screen.blit(ts, (int(p['x'] + tail_off_x - tail_sz),
                                         int(p['y'] + tail_off_y - tail_sz)))

    def reset_for_new_round(self, game_state: dict):
        super().reset_for_new_round(game_state)
        self.sand_particles = []
        self.body_particles = []
        self.wall_alpha = 0
        self.phase = 'idle'
        self.elapsed = 0.0
        game_state['top_paddle_sand_prison'] = False
        game_state['bottom_paddle_sand_prison'] = False
        game_state.pop('sand_prison_center_x', None)
        game_state.pop('sand_prison_range', None)
        game_state.pop('sand_prison_target_is_top', None)


class SandVortex(HeroSkill):
    """모래회오리 - 2개의 거대한 모래폭풍을 발사하여 상대 공을 끌어당기고 커브 발사"""

    GAME_TOP = 0
    GAME_BOTTOM = 750

    PULL_RADIUS = 200      # 끌어당김 범위 (기본값, 성장에 따라 증가) - 140→200 확대
    CAPTURE_RADIUS = 36    # 완전 포획 범위 (기본값, 성장에 따라 증가)
    VORTEX_SPEED = 180     # 이동 속도
    LAUNCH_SPEED_MULT = 1.43  # 포획 후 발사 속도 = 공 현재 속도 × 배율 (기존 1.1 → 30% 증가)
    LAUNCH_SPEED_MIN = 8     # 최소 발사 속도 (px/frame, 기존 6 → 30% 증가)
    LAUNCH_SPEED_MAX = 18    # 최대 발사 속도 (px/frame, 기존 14 → 30% 증가)
    WOBBLE_AMPLITUDE = 80  # 지그재그 좌우 진폭
    VORTEX_LIFETIME = 4.0  # 소용돌이 수명 (초)
    FADE_DURATION = 1.2    # 소멸 페이드 시간 (초)
    CURVE_DURATION = 2.5   # 커브 효과 지속시간 (초, 기존 1.5 → 대폭 증가)
    CURVE_ROTATION_SPEED = 3.0  # 커브 회전 속도 (rad/s) - 0.85→3.0 U턴급 강화
    CAPTURE_BOOST = 1.6    # 포획 시 공 임팩트 부스트 (ball_impact_boost에 적용)
    GROWTH_RATE = 0.20     # 초당 크기/범위 성장률 (20%)

    def __init__(self):
        super().__init__(
            skill_id="sand_vortex",
            name="Sand Vortex",
            korean_name="모래회오리",
            description="모래 회오리가 몰아치며 공을 집어삼킨다",
            trigger=SkillTrigger.ON_COOLDOWN,
            cooldown=22.0,
            duration=7.0,
            hero_id="mirage"
        )
        self.vortexes = []
        self.vortex_particles = []
        self.caster_is_bottom = True
        self._sound_loaded = False
        self._sound = None
        self._capture_sound_loaded = False
        self._capture_sound = None
        # 커브 효과 추적 (발사 후 공에 횡방향 힘 적용)
        self.curve_effects = []  # [{'timer': float, 'curve_dir': 1 or -1}]

    def _load_sounds(self):
        if self._sound_loaded:
            return
        self._sound_loaded = True
        try:
            import os
            project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            path1 = os.path.join(project_root, "sounds", "windstorm.wav")
            if os.path.exists(path1):
                self._sound = pygame.mixer.Sound(path1)
                self._sound.set_volume(0.8)
            path2 = os.path.join(project_root, "sounds", "grab.wav")
            if os.path.exists(path2):
                self._capture_sound = pygame.mixer.Sound(path2)
                self._capture_sound.set_volume(0.6)
        except Exception:
            pass

    def _is_ball_from_caster(self, ball) -> bool:
        """캐스터가 방금 친 공인지 판별 (캐스터 방향으로 날아가는 공 = 캐스터가 친 공)"""
        ball_vy = getattr(ball, 'vy', None) or getattr(ball, 'speed_y', 0)
        if self.caster_is_bottom:
            # 캐스터가 하단 → 공이 위로 올라감(vy < 0) = 캐스터가 친 공
            return ball_vy < 0
        else:
            # 캐스터가 상단 → 공이 아래로 내려감(vy > 0) = 캐스터가 친 공
            return ball_vy > 0

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        """소용돌이 2개 발사 - 패들 중심에서 좌우 30도"""
        self.caster_is_bottom = not caster_paddle.is_top
        caster_cx = caster_paddle.x + getattr(caster_paddle, 'width', 80) // 2
        caster_y = caster_paddle.y

        self.vortexes = []
        self.vortex_particles = []
        self.curve_effects = []

        # 기본 방향: 상대 쪽으로
        base_angle = -math.pi / 2 if self.caster_is_bottom else math.pi / 2

        for angle_offset in [-math.pi / 6, math.pi / 6]:  # ±30도
            angle = base_angle + angle_offset
            self.vortexes.append({
                'x': float(caster_cx),
                'y': float(caster_y),
                'base_vx': math.cos(angle) * self.VORTEX_SPEED,
                'base_vy': math.sin(angle) * self.VORTEX_SPEED,
                'wobble_phase': random.uniform(0, math.pi * 2),
                'wobble_speed': random.uniform(3.0, 4.5),
                # 랜덤 X축 움직임용 추가 파라미터
                'drift_vx': 0.0,                        # 현재 랜덤 드리프트 속도
                'drift_target': random.uniform(-80, 80), # 목표 드리프트
                'drift_timer': 0.0,                      # 드리프트 전환 타이머
                'drift_interval': random.uniform(0.3, 0.7),  # 드리프트 변경 간격
                'jitter_x': 0.0,                         # 미세 떨림
                'rotation': random.uniform(0, 360),
                'spin_speed': random.uniform(280, 400),
                'base_size': 44,       # 초기 크기 (성장 기준)
                'size': 44,
                'growth_scale': 1.0,   # 현재 성장 배율 (1.0 = 100%)
                'alpha': 255,
                'age': 0.0,
                'dead': False,
                'fading': False,       # 소멸 페이드 중
                'has_captured': False,  # 이 소용돌이가 이미 공을 포획했는지
                'capture_cooldown': 0.0,  # 포획 후 재포획 방지 쿨다운
            })

        # 사운드
        self._load_sounds()
        if self._sound:
            try:
                self._sound.play()
            except Exception:
                pass

        game_state['has_sand_vortex'] = True
        return {}

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        """소용돌이 이동 + 예측불가 랜덤 X축 + 상대 공만 끌어당김 + 커브 발사"""
        any_alive = False

        for vortex in self.vortexes:
            if vortex['dead']:
                continue
            any_alive = True
            vortex['age'] += dt

            # ── 크기 성장: 초당 20%씩 커짐 ──
            vortex['growth_scale'] = 1.0 + self.GROWTH_RATE * vortex['age']
            grown_size = vortex['base_size'] * vortex['growth_scale']

            # ── 수명 관리: 4초 후 페이드 아웃 ──
            fade_start = self.VORTEX_LIFETIME - self.FADE_DURATION
            if vortex['age'] >= self.VORTEX_LIFETIME:
                vortex['dead'] = True
                continue
            elif vortex['age'] >= fade_start:
                vortex['fading'] = True
                fade_progress = (vortex['age'] - fade_start) / self.FADE_DURATION
                vortex['alpha'] = max(0, int(255 * (1 - fade_progress)))
                # 페이드 중 회전 감속 + 크기 수축 (성장한 크기 기준)
                vortex['spin_speed'] *= (1 - 0.8 * dt)
                vortex['size'] = max(8, grown_size * (1 - fade_progress * 0.6))
            else:
                # 페이드 전: 성장한 크기 적용
                vortex['size'] = grown_size

            # 포획 쿨다운 감소
            if vortex['capture_cooldown'] > 0:
                vortex['capture_cooldown'] -= dt

            # ── 예측불가 랜덤 X축 움직임 ──
            vortex['drift_timer'] += dt
            if vortex['drift_timer'] >= vortex['drift_interval']:
                vortex['drift_timer'] = 0.0
                vortex['drift_interval'] = random.uniform(0.2, 0.6)
                vortex['drift_target'] = random.uniform(-120, 120)

            lerp_speed = 4.0 * dt
            vortex['drift_vx'] += (vortex['drift_target'] - vortex['drift_vx']) * lerp_speed
            vortex['jitter_x'] = random.uniform(-25, 25)
            vortex['wobble_phase'] += vortex['wobble_speed'] * dt
            wobble_offset = math.sin(vortex['wobble_phase']) * self.WOBBLE_AMPLITUDE

            # 페이드 중이면 움직임 감속
            speed_mult = 1.0
            if vortex['fading']:
                fade_progress = (vortex['age'] - fade_start) / self.FADE_DURATION
                speed_mult = max(0.1, 1 - fade_progress * 0.7)

            final_x_move = (vortex['base_vx'] + wobble_offset + vortex['drift_vx'] + vortex['jitter_x']) * speed_mult
            vortex['x'] += final_x_move * dt
            vortex['y'] += vortex['base_vy'] * dt * speed_mult

            # 회전
            vortex['rotation'] += vortex['spin_speed'] * dt

            # 좌우 벽 바운스
            if vortex['x'] < self.GAME_LEFT + vortex['size']:
                vortex['x'] = self.GAME_LEFT + vortex['size']
                vortex['base_vx'] = abs(vortex['base_vx'])
                vortex['drift_vx'] = abs(vortex['drift_vx'])
                vortex['drift_target'] = abs(vortex['drift_target'])
            elif vortex['x'] > self.GAME_RIGHT - vortex['size']:
                vortex['x'] = self.GAME_RIGHT - vortex['size']
                vortex['base_vx'] = -abs(vortex['base_vx'])
                vortex['drift_vx'] = -abs(vortex['drift_vx'])
                vortex['drift_target'] = -abs(vortex['drift_target'])

            # 화면 밖 제거
            if vortex['y'] < -60 or vortex['y'] > 810:
                vortex['dead'] = True
                continue

            # ── 공과의 상호작용 (캐스터가 친 공은 무시, 페이드 중/쿨다운 중이면 포획 안함) ──
            # 성장에 따라 끌어당김/포획 범위도 비례 증가
            scaled_pull_radius = self.PULL_RADIUS * vortex['growth_scale']
            scaled_capture_radius = self.CAPTURE_RADIUS * vortex['growth_scale']
            can_capture = not vortex['has_captured'] and not vortex['fading'] and vortex['capture_cooldown'] <= 0
            if ball and can_capture:
                if not self._is_ball_from_caster(ball):
                    ball_x = getattr(ball, 'x', 0)
                    ball_y = getattr(ball, 'y', 0)

                    dx = vortex['x'] - ball_x
                    dy = vortex['y'] - ball_y
                    dist = math.sqrt(dx * dx + dy * dy)

                    if dist < scaled_pull_radius and dist > 1:
                        # 끌어당김 (성장된 범위 기준) - U턴급 강력한 흡인력
                        pull_factor = (1 - dist / scaled_pull_radius) ** 0.8  # 지수 1.5→0.8: 먼 거리에서도 강한 흡인
                        pull_strength = pull_factor * 700 * dt  # 350→700: 구심력 2배 강화
                        nx = dx / dist
                        ny = dy / dist

                        if hasattr(ball, 'vx'):
                            ball.vx += nx * pull_strength
                            ball.vy += ny * pull_strength
                        elif hasattr(ball, 'speed_x'):
                            ball.speed_x += nx * pull_strength
                            ball.speed_y += ny * pull_strength

                        # 접선 방향 힘 (공이 소용돌이 주변을 U턴하도록 강한 궤도 회전)
                        ball_vx_cur = getattr(ball, 'vx', 0) or getattr(ball, 'speed_x', 0)
                        ball_vy_cur = getattr(ball, 'vy', 0) or getattr(ball, 'speed_y', 0)
                        # 외적으로 공의 자연스러운 공전 방향 결정
                        cross = ball_vx_cur * ny - ball_vy_cur * nx
                        spin_dir = 1 if cross >= 0 else -1
                        # 반지름 방향에 수직인 접선 벡터
                        tx = -ny * spin_dir
                        ty = nx * spin_dir
                        tangent_strength = pull_factor * 600 * dt  # 180→600: 접선력 3.3배 강화 (U턴 궤적)
                        if hasattr(ball, 'vx'):
                            ball.vx += tx * tangent_strength
                            ball.vy += ty * tangent_strength
                        elif hasattr(ball, 'speed_x'):
                            ball.speed_x += tx * tangent_strength
                            ball.speed_y += ty * tangent_strength

                        # 포획 → 커브 발사 (소용돌이는 사라지지 않음!)
                        if dist < scaled_capture_radius:
                            vortex['has_captured'] = True
                            vortex['capture_cooldown'] = 2.0  # 2초 재포획 방지

                            # 공 현재 속도 측정 → 상대 속도 기반 발사
                            cur_vx = getattr(ball, 'vx', 0) or getattr(ball, 'speed_x', 0)
                            cur_vy = getattr(ball, 'vy', 0) or getattr(ball, 'speed_y', 0)
                            cur_speed = math.sqrt(cur_vx ** 2 + cur_vy ** 2)
                            launch_speed = max(self.LAUNCH_SPEED_MIN,
                                             min(self.LAUNCH_SPEED_MAX,
                                                 cur_speed * self.LAUNCH_SPEED_MULT))

                            # 상대 방향으로 커브 발사 (더 넓은 각도 범위)
                            if self.caster_is_bottom:
                                launch_angle = -math.pi / 2 + random.uniform(-0.4, 0.4)
                            else:
                                launch_angle = math.pi / 2 + random.uniform(-0.4, 0.4)

                            launch_vx = math.cos(launch_angle) * launch_speed
                            launch_vy = math.sin(launch_angle) * launch_speed

                            # 커브 방향: 소용돌이의 현재 X 움직임 방향으로 휘어짐
                            curve_dir = 1 if (vortex['base_vx'] + vortex['drift_vx']) >= 0 else -1

                            if hasattr(ball, 'vx'):
                                ball.x = vortex['x']
                                ball.y = vortex['y']
                                ball.vx = launch_vx
                                ball.vy = launch_vy
                            elif hasattr(ball, 'speed_x'):
                                ball.x = vortex['x']
                                ball.y = vortex['y']
                                ball.speed_x = launch_vx
                                ball.speed_y = launch_vy

                            # ★ game_state를 통해 실제 BALL 객체에 위치/속도/부스트 반영
                            game_state['sand_vortex_ball_captured'] = {
                                'ball_x': vortex['x'],
                                'ball_y': vortex['y'],
                                'launch_vx': launch_vx,
                                'launch_vy': launch_vy,
                                'boost': self.CAPTURE_BOOST,
                                'curve_dir': curve_dir,
                            }

                            # 커브 효과 등록 (이후 프레임에서 횡방향 힘 적용)
                            self.curve_effects.append({
                                'timer': self.CURVE_DURATION,
                                'curve_dir': curve_dir,
                            })

                            # 포획 사운드
                            if self._capture_sound:
                                try:
                                    self._capture_sound.play()
                                except Exception:
                                    pass

                            # 포획 이펙트 파티클 버스트
                            for _ in range(25):
                                angle = random.uniform(0, math.pi * 2)
                                spd = random.uniform(50, 200)
                                self.vortex_particles.append({
                                    'x': vortex['x'],
                                    'y': vortex['y'],
                                    'vx': math.cos(angle) * spd,
                                    'vy': math.sin(angle) * spd,
                                    'alpha': 255,
                                    'size': random.uniform(4, 10),
                                    'life': 0.8,
                                    'max_life': 0.8,
                                    'burst': True,
                                    'color_type': random.choice(['gold', 'sand', 'dust']),
                                })

            # ── 모래폭풍 파티클 (페이드 중이면 파티클 감소) ──
            particle_count = 1 if vortex['fading'] else 4
            for _ in range(particle_count):
                angle = random.uniform(0, math.pi * 2)
                dist_p = random.uniform(4, vortex['size'] * 1.2)
                orbit_speed = random.uniform(60, 140)
                p_alpha = max(20, int(random.randint(120, 220) * (vortex['alpha'] / 255.0)))
                self.vortex_particles.append({
                    'x': vortex['x'] + math.cos(angle) * dist_p,
                    'y': vortex['y'] + math.sin(angle) * dist_p,
                    'vx': math.cos(angle + math.pi / 2) * orbit_speed + random.uniform(-20, 20),
                    'vy': math.sin(angle + math.pi / 2) * orbit_speed * 0.5 + vortex['base_vy'] * 0.3,
                    'alpha': p_alpha,
                    'size': random.uniform(2, 6),
                    'life': random.uniform(0.4, 0.9),
                    'max_life': 0.9,
                    'burst': False,
                    'color_type': random.choice(['sand', 'dust', 'dark']),
                })

            # 큰 먼지 덩어리
            dust_chance = 0.1 if vortex['fading'] else 0.35
            if random.random() < dust_chance:
                angle = random.uniform(0, math.pi * 2)
                dist_p = random.uniform(vortex['size'] * 0.5, vortex['size'] * 1.5)
                self.vortex_particles.append({
                    'x': vortex['x'] + math.cos(angle) * dist_p,
                    'y': vortex['y'] + math.sin(angle) * dist_p,
                    'vx': random.uniform(-40, 40),
                    'vy': vortex['base_vy'] * 0.2 + random.uniform(-15, 15),
                    'alpha': max(20, int(random.randint(80, 160) * (vortex['alpha'] / 255.0))),
                    'size': random.uniform(6, 12),
                    'life': random.uniform(0.5, 1.0),
                    'max_life': 1.0,
                    'burst': False,
                    'color_type': 'cloud',
                })

        # ── 커브 효과 적용 (속도 벡터 회전으로 호 궤적 생성 - 소용돌이 휘감기) ──
        if ball and self.curve_effects:
            for curve in self.curve_effects:
                curve['timer'] -= dt
                if curve['timer'] > 0:
                    # 시간에 따라 회전력 감소 (시전자 방향 ~30도 차이 호 궤적)
                    fade = curve['timer'] / self.CURVE_DURATION
                    rotation_rate = self.CURVE_ROTATION_SPEED * curve['curve_dir'] * fade * dt
                    cur_vx = getattr(ball, 'vx', 0) or getattr(ball, 'speed_x', 0)
                    cur_vy = getattr(ball, 'vy', 0) or getattr(ball, 'speed_y', 0)
                    cos_r = math.cos(rotation_rate)
                    sin_r = math.sin(rotation_rate)
                    new_vx = cur_vx * cos_r - cur_vy * sin_r
                    new_vy = cur_vx * sin_r + cur_vy * cos_r
                    if hasattr(ball, 'vx'):
                        ball.vx = new_vx
                        ball.vy = new_vy
                    elif hasattr(ball, 'speed_x'):
                        ball.speed_x = new_vx
                        ball.speed_y = new_vy
            self.curve_effects = [c for c in self.curve_effects if c['timer'] > 0]

        # 파티클 업데이트
        for p in self.vortex_particles:
            p['x'] += p['vx'] * dt
            p['y'] += p['vy'] * dt
            p['life'] -= dt
            ratio = max(0, p['life'] / p['max_life'])
            p['alpha'] = int(p['alpha'] * ratio) if p.get('burst') else int(180 * ratio)

        self.vortex_particles = [p for p in self.vortex_particles if p['life'] > 0]

        # 모든 소용돌이 소멸 시 조기 종료
        self.vortexes = [v for v in self.vortexes if not v['dead']]
        if not any_alive and not self.vortex_particles and not self.curve_effects:
            self.is_active = False
            self.active_timer = 0
            game_state['has_sand_vortex'] = False

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        """효과 종료"""
        game_state['has_sand_vortex'] = False
        self.vortexes = []
        self.vortex_particles = []
        self.curve_effects = []

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        """모래폭풍 비주얼 렌더링"""
        if not self.is_active and not self.vortex_particles and not self.curve_effects:
            return

        # 소용돌이 본체 (모래폭풍 스타일)
        for vortex in self.vortexes:
            if vortex.get('dead'):
                continue

            x, y = int(vortex['x']), int(vortex['y'])
            size = vortex['size']
            rot = vortex['rotation']
            alpha = vortex['alpha']

            surf_size = int(size * 3.5)
            vortex_surf = _psurf((surf_size * 2, surf_size * 2), pygame.SRCALPHA)
            cx, cy = surf_size, surf_size

            # ── 1) 바깥쪽 모래구름 (반투명 대형 원들) ──
            for i in range(8):
                cloud_angle = math.radians(rot * 0.5 + i * 45 + vortex['age'] * 60)
                cloud_dist = size * (0.6 + 0.4 * math.sin(vortex['age'] * 2 + i))
                cloud_x = cx + math.cos(cloud_angle) * cloud_dist
                cloud_y = cy + math.sin(cloud_angle) * cloud_dist
                cloud_r = int(size * random.uniform(0.35, 0.6))
                cloud_alpha = max(0, min(255, int(alpha * 0.25)))
                # 따뜻한 모래색 변화
                r_c = min(255, 180 + int(30 * math.sin(i * 0.7)))
                g_c = min(255, 145 + int(20 * math.sin(i * 1.1)))
                b_c = max(40, 70 + int(15 * math.sin(i * 0.5)))
                pygame.draw.circle(vortex_surf, (r_c, g_c, b_c, cloud_alpha),
                                 (int(cloud_x), int(cloud_y)), cloud_r)

            # ── 2) 중간층 빠른 회전 나선 (여러 겹) ──
            for layer in range(8):
                radius = size - layer * 4
                if radius < 4:
                    break
                layer_alpha = max(0, min(255, int(alpha * 0.7) - layer * 20))
                # 사막 색상 그라데이션 (바깥 = 밝은 황토, 안쪽 = 진한 갈색)
                r_c = min(255, 200 + layer * 6)
                g_c = max(90, 155 - layer * 7)
                b_c = max(35, 75 - layer * 6)
                color = (r_c, g_c, b_c, layer_alpha)

                # 나선 궤적 (더 촘촘하고 두꺼운 선)
                points = []
                angle_start = math.radians(rot * 1.3 + layer * 40)
                for a_deg in range(0, 420, 8):
                    rad = math.radians(a_deg) + angle_start
                    r = radius * (1 - a_deg / 1400)
                    if r < 2:
                        break
                    px = cx + math.cos(rad) * r
                    py = cy + math.sin(rad) * r
                    points.append((int(px), int(py)))

                if len(points) > 2:
                    line_w = max(1, 4 - layer // 2)
                    pygame.draw.lines(vortex_surf, color, False, points, line_w)

            # ── 3) 내부 밝은 코어 ──
            # 밝은 모래색 코어 (큰 글로우)
            core_alpha = max(0, min(255, int(alpha * 0.5)))
            pygame.draw.circle(vortex_surf, (230, 200, 130, core_alpha), (cx, cy), int(size * 0.35))
            pygame.draw.circle(vortex_surf, (245, 225, 165, max(0, min(255, int(alpha * 0.7)))), (cx, cy), int(size * 0.2))
            # 중심 밝은 점
            pygame.draw.circle(vortex_surf, (255, 240, 190, min(255, int(alpha * 0.9))), (cx, cy), 6)

            # ── 4) 표면 노이즈 점들 (모래알갱이 느낌) ──
            for _ in range(12):
                grain_angle = random.uniform(0, math.pi * 2)
                grain_dist = random.uniform(4, size * 0.9)
                gx = cx + math.cos(grain_angle) * grain_dist
                gy = cy + math.sin(grain_angle) * grain_dist
                grain_alpha = max(0, min(255, int(alpha * random.uniform(0.3, 0.7))))
                grain_size = random.randint(1, 3)
                pygame.draw.circle(vortex_surf, (210, 175, 95, grain_alpha),
                                 (int(gx), int(gy)), grain_size)

            screen.blit(vortex_surf, (x - surf_size, y - surf_size))

            # 끌어당김 범위 (매우 연한 원 - 모래색, 성장에 따라 커짐)
            scaled_pr = int(self.PULL_RADIUS * vortex.get('growth_scale', 1.0))
            pull_surf = _psurf((scaled_pr * 2, scaled_pr * 2), pygame.SRCALPHA)
            pygame.draw.circle(pull_surf, (210, 180, 100, 10),
                             (scaled_pr, scaled_pr), scaled_pr, 1)
            screen.blit(pull_surf, (x - scaled_pr, y - scaled_pr))

        # 파티클
        for p in self.vortex_particles:
            a = max(0, min(255, int(p['alpha'])))
            if a > 8:
                sz = max(1, int(p['size']))
                color_type = p.get('color_type', 'sand')
                if p.get('burst'):
                    # 포획 버스트
                    if color_type == 'gold':
                        col = (255, 220, 100, a)
                    elif color_type == 'dust':
                        col = (220, 190, 120, a)
                    else:
                        col = (240, 200, 110, a)
                else:
                    # 모래폭풍 파티클
                    if color_type == 'dark':
                        col = (160, 120, 60, a)
                    elif color_type == 'cloud':
                        col = (195, 170, 110, min(a, 140))
                    elif color_type == 'dust':
                        col = (220, 190, 120, a)
                    else:
                        col = (210, 180, 105, a)
                ps = _psurf((sz * 2, sz * 2), pygame.SRCALPHA)
                pygame.draw.circle(ps, col, (sz, sz), sz)
                screen.blit(ps, (int(p['x'] - sz), int(p['y'] - sz)))

    def reset_for_new_round(self, game_state: dict):
        super().reset_for_new_round(game_state)
        self.vortexes = []
        self.vortex_particles = []
        self.curve_effects = []
        game_state['has_sand_vortex'] = False


# ============================================================================
# 라 (Ra) - 태양의 매 전용 스킬
# ============================================================================
class SolarBolt(HeroSkill):
    """천둥 낙뢰 - 공이 자신에게 향할 때 번개로 타격하여 반사시킨다 (디바인쉴드 번개 요격과 동일)

    자동 발동 (쿨타임 15초). 공이 시전자 쪽으로 내려오고 있을 때 발동되며,
    번개가 시전자 패들에서 공까지 이어지며 공을 상대 방향으로 반사시킨다.
    """

    LIGHTNING_DISPLAY = 0.20    # 번개 표시 시간 (초)
    EXPLOSION_DISPLAY = 0.38    # 폭발 표시 시간 (초)
    EFFECT_DURATION = 0.7       # 전체 이펙트 지속 시간 (초)
    SPARK_COUNT = 22            # 스파크 파티클 수

    # 4레이어 번개 컬러 (외곽→내부 순서)
    GLOW_WIDE = (255, 180, 30, 35)      # 넓은 글로우 (반투명 오렌지)
    GLOW_MID = (255, 210, 60, 80)       # 중간 글로우 (금빛)
    CORE_OUTER = (255, 240, 140)        # 외곽 코어 (밝은 금)
    CORE_INNER = (255, 255, 240)        # 내부 코어 (거의 백색)

    # 분기 컬러
    BRANCH_GLOW = (200, 180, 255, 60)   # 분기 글로우 (연보라)
    BRANCH_CORE = (220, 220, 255)       # 분기 코어 (백청)

    # 폭발 컬러
    EXPLOSION_FLASH = (255, 255, 230)    # 중심 플래시
    EXPLOSION_CORE = (255, 240, 150)     # 코어
    EXPLOSION_INNER = (255, 255, 220)    # 내부
    EXPLOSION_RING = (255, 200, 80)      # 링
    EXPLOSION_ARC = (180, 210, 255)      # 방사형 아크

    # 스파크 컬러 팔레트
    SPARK_COLORS = [
        (255, 255, 255), (255, 255, 200), (255, 230, 100),
        (200, 220, 255), (255, 240, 160),
    ]

    def __init__(self):
        super().__init__(
            skill_id="solar_bolt",
            name="Solar Bolt",
            korean_name="천둥 낙뢰",
            description="태양신의 번개가 공을 내리쳐 맹렬하게 되돌려보낸다",
            trigger=SkillTrigger.ON_COOLDOWN,
            cooldown=12.0,
            duration=self.EFFECT_DURATION,
            hero_id="ra"
        )
        self._sound_loaded = False
        self._sound = None
        # 이펙트 데이터
        self.lightning_path = None
        self.lightning_branches = []
        self.lightning_ttl = 0.0
        self.explosion_ttl = 0.0
        self.explosion_center = (0, 0)
        self.sparks = []

    def _load_sound(self):
        if self._sound_loaded:
            return
        self._sound_loaded = True
        try:
            project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            sound_path = os.path.join(project_root, "sounds", "devinethunder.wav")
            if os.path.exists(sound_path):
                self._sound = pygame.mixer.Sound(sound_path)
                self._sound.set_volume(0.5)
        except Exception:
            pass

    def _check_ball_conditions(self, caster_paddle, ball) -> bool:
        """공이 시전자 쪽으로 향하고 있는지 확인"""
        is_top = getattr(self, 'caster_is_top', True)
        ball_cy = ball.y + getattr(ball, 'height', 10) / 2
        if is_top:
            # 상단 시전자: 공이 위로 향하고(vy < 0) 상단 절반에 있을 때
            return ball.vy < 0 and ball_cy <= 375
        else:
            # 하단 시전자: 공이 아래로 향하고(vy > 0) 하단 절반에 있을 때
            return ball.vy > 0 and ball_cy >= 375

    def use(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        """조건 충족 시에만 발동 (공이 시전자에게 향하고 있을 때)"""
        if not self.can_use():
            return {}
        # 호위무사(is_bodyguard) 또는 빙의(_possessed_force)일 때는 조건 체크 없이 바로 발동
        is_guard = getattr(caster_paddle, 'is_bodyguard', False)
        is_possessed = getattr(self, '_possessed_force', False)
        if not is_guard and not is_possessed and not self._check_ball_conditions(caster_paddle, ball):
            # 공이 시전자 쪽으로 향하고 있지 않으면 발동하지 않음 (쿨타임 소모 안 함)
            return {}
        # 조건 충족 → 부모 use() 호출 (쿨타임 설정 + _apply_effect)
        return super().use(caster_paddle, target_paddle, ball, game_state)

    def _gen_lightning(self, start_xy, end_xy):
        """고퀄리티 프로시저럴 번개 경로 생성 - 다중 분기 + 세밀한 디테일"""
        sx, sy = start_xy
        ex, ey = end_xy
        total_dist = math.hypot(ex - sx, ey - sy)
        pts = [(int(sx), int(sy)), (int(ex), int(ey))]

        def subdivide(points, disp, min_disp=4):
            if disp < min_disp:
                return points
            out = [points[0]]
            for i in range(len(points) - 1):
                x1, y1 = points[i]
                x2, y2 = points[i + 1]
                mx = (x1 + x2) / 2
                my = (y1 + y2) / 2
                dx = x2 - x1
                dy = y2 - y1
                length = math.hypot(dx, dy) or 1.0
                nx = -dy / length
                ny = dx / length
                offset = random.uniform(-disp, disp)
                mx += nx * offset
                my += ny * offset
                out.append((int(mx), int(my)))
                out.append((x2, y2))
            return subdivide(out, disp * 0.52, min_disp)

        # 메인 볼트: 더 높은 디테일 (기존 0.08 → 0.12)
        main = subdivide(pts, max(16.0, total_dist * 0.12), min_disp=3)

        # 분기: 3~5개 (기존 1~2개)
        branches = []
        if len(main) > 4:
            branch_count = random.randint(3, 5)
            used_indices = set()
            for _ in range(branch_count):
                # 메인 경로 전체에서 분기 (앞쪽에서도 분기 가능)
                idx = random.randrange(max(1, len(main) // 4), len(main) - 1)
                if idx in used_indices:
                    continue
                used_indices.add(idx)
                bx, by = main[idx]
                dirx = ex - bx
                diry = ey - by
                # 분기 길이: 전체 거리의 15~35%
                blen = max(20, int(total_dist * random.uniform(0.15, 0.35)))
                ang = math.atan2(diry, dirx) + random.uniform(-0.9, 0.9)
                ex2 = int(bx + _cos(ang) * blen)
                ey2 = int(by + _sin(ang) * blen)
                branch = subdivide([(bx, by), (ex2, ey2)], max(10.0, blen * 0.15), min_disp=4)
                branches.append(branch)

                # 서브 분기 (분기에서 갈라지는 작은 가지, 40% 확률)
                if random.random() < 0.4 and len(branch) > 3:
                    sub_idx = random.randrange(len(branch) // 2, len(branch) - 1)
                    sbx, sby = branch[sub_idx]
                    sub_len = max(10, int(blen * 0.4))
                    sub_ang = ang + random.uniform(-1.2, 1.2)
                    sex = int(sbx + _cos(sub_ang) * sub_len)
                    sey = int(sby + _sin(sub_ang) * sub_len)
                    branches.append(subdivide([(sbx, sby), (sex, sey)], max(6.0, sub_len * 0.12), min_disp=5))
        return main, branches

    def _spawn_sparks(self, x, y):
        """번개 충돌 스파크 생성 - 다양한 타입"""
        for _ in range(self.SPARK_COUNT):
            ang = random.uniform(0, math.tau)
            spd = random.uniform(2.5, 9.0)
            spark_type = random.choice(['streak', 'dot', 'flash'])
            self.sparks.append({
                'x': float(x), 'y': float(y),
                'vx': _cos(ang) * spd,
                'vy': _sin(ang) * spd,
                'life': random.uniform(0.25, 0.55),
                'max_life': 0.55,
                'size': random.uniform(1.5, 4.0) if spark_type != 'flash' else random.uniform(4.0, 7.0),
                'type': spark_type,
                'color': random.choice(self.SPARK_COLORS),
            })

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        """번개로 공을 타격하여 반사"""
        self._load_sound()

        # 시전자 패들 중심 좌표
        cx = caster_paddle.x + getattr(caster_paddle, 'width', 80) / 2
        cy = caster_paddle.y + getattr(caster_paddle, 'height', 10) / 2
        # 공 중심 좌표
        bx = ball.x + getattr(ball, 'width', 10) / 2
        by = ball.y + getattr(ball, 'height', 10) / 2

        # 번개 경로 생성
        main, branches = self._gen_lightning((int(cx), int(cy)), (int(bx), int(by)))
        self.lightning_path = main
        self.lightning_branches = branches
        self.lightning_ttl = self.LIGHTNING_DISPLAY
        self.explosion_ttl = self.EXPLOSION_DISPLAY
        self.explosion_center = (int(bx), int(by))
        self._spawn_sparks(bx, by)

        # 사운드 재생
        if self._sound:
            try:
                self._sound.play()
            except Exception:
                pass

        # 공 반사 (디바인쉴드와 동일한 로직)
        is_top = getattr(self, 'caster_is_top', True)
        step_speed = max(1.0, math.hypot(ball.vx, ball.vy))
        if is_top:
            # 상단 시전자 → 공을 아래로 반사
            base_angle = math.pi / 2
        else:
            # 하단 시전자 → 공을 위로 반사
            base_angle = -math.pi / 2
        rand_offset = random.uniform(-math.pi / 4, math.pi / 4)
        nvx = _cos(base_angle + rand_offset) * step_speed
        nvy = _sin(base_angle + rand_offset) * step_speed

        # 최소 속도 보장
        if is_top:
            if nvy <= 1.0:
                nvy = 1.0
        else:
            if nvy >= -1.0:
                nvy = -1.0

        ball.vx = nvx
        ball.vy = nvy

        return {
            'screen_effect': ScreenEffect.FLASH,
            'flash_duration': 0.15,
            'flash_color': (255, 230, 100),
            'shake_intensity': 6,
        }

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        """이펙트 타이머 및 파티클 업데이트"""
        # 번개 TTL
        if self.lightning_ttl > 0:
            self.lightning_ttl = max(0.0, self.lightning_ttl - dt)
            if self.lightning_ttl <= 0:
                self.lightning_path = None
                self.lightning_branches = []
        # 폭발 TTL
        if self.explosion_ttl > 0:
            self.explosion_ttl = max(0.0, self.explosion_ttl - dt)
        # 스파크 물리 업데이트
        kept = []
        for p in self.sparks:
            p['x'] += p['vx']
            p['y'] += p['vy']
            p['vy'] += 0.08  # 중력
            p['life'] -= dt
            if p['life'] > 0:
                kept.append(p)
        self.sparks = kept

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        """이펙트 종료 정리"""
        self.lightning_path = None
        self.lightning_branches = []
        self.lightning_ttl = 0.0
        self.explosion_ttl = 0.0
        self.sparks = []

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        """고퀄리티 번개 + 폭발 + 스파크 렌더링 (4레이어 + 플리커 + 다중 충격파)"""
        # ══════════════════════════════════════════════════
        # 번개 렌더링 (4레이어 + 플리커)
        # ══════════════════════════════════════════════════
        if self.lightning_ttl > 0 and self.lightning_path and len(self.lightning_path) >= 2:
            flicker = random.random() < 0.85
            fade = min(1.0, self.lightning_ttl / 0.06)

            all_pts = list(self.lightning_path)
            for br in self.lightning_branches:
                all_pts.extend(br)
            if all_pts and flicker:
                min_x = min(p[0] for p in all_pts)
                max_x = max(p[0] for p in all_pts)
                min_y = min(p[1] for p in all_pts)
                max_y = max(p[1] for p in all_pts)
                margin = 30
                w = max(2, (max_x - min_x) + margin * 2)
                h = max(2, (max_y - min_y) + margin * 2)
                offx, offy = min_x - margin, min_y - margin
                def _off(pts):
                    return [(px - offx, py - offy) for (px, py) in pts]

                # 레이어 1: 글로우 (6px, BLEND_ADD)
                g1 = _psurf((w, h), pygame.SRCALPHA)
                a1 = int(self.GLOW_WIDE[3] * fade)
                c1 = (self.GLOW_WIDE[0], self.GLOW_WIDE[1], self.GLOW_WIDE[2], a1)
                pygame.draw.lines(g1, c1, False, _off(self.lightning_path), 6)
                for br in self.lightning_branches:
                    if len(br) >= 2:
                        pygame.draw.lines(g1, c1, False, _off(br), 4)
                screen.blit(g1, (offx, offy), special_flags=pygame.BLEND_ADD)

                # 레이어 2: 코어 (2px)
                pygame.draw.lines(screen, self.CORE_OUTER, False, self.lightning_path, 2)
                for br in self.lightning_branches:
                    if len(br) >= 2:
                        pygame.draw.lines(screen, self.BRANCH_CORE, False, br, 1)

                # 레이어 3: 내부 코어 (1px, 백색)
                pygame.draw.lines(screen, self.CORE_INNER, False, self.lightning_path, 1)

                # 분기 갈림점 빛점
                for br in self.lightning_branches:
                    if br:
                        bx, by = br[0]
                        gr = random.randint(2, 3)
                        gs = _psurf((gr * 2, gr * 2), pygame.SRCALPHA)
                        pygame.draw.circle(gs, (255, 255, 230, int(160 * fade)), (gr, gr), gr)
                        screen.blit(gs, (bx - gr, by - gr), special_flags=pygame.BLEND_ADD)

        # ══════════════════════════════════════════════════
        # 폭발 렌더링 (다중 충격파 + 방사형 아크 + 중심 플래시)
        # ══════════════════════════════════════════════════
        if self.explosion_ttl > 0:
            cx, cy = self.explosion_center
            progress = 1.0 - (self.explosion_ttl / self.EXPLOSION_DISPLAY)
            life_ratio = 1.0 - progress

            # 중심 플래시 (초반 강렬)
            if progress < 0.3:
                fa = int(255 * (1.0 - progress / 0.3))
                fr = int(12 + progress * 30)
                fs = _psurf((fr * 2, fr * 2), pygame.SRCALPHA)
                pygame.draw.circle(fs, (255, 255, 240, fa), (fr, fr), fr)
                pygame.draw.circle(fs, (255, 255, 255, min(255, fa + 30)), (fr, fr), max(1, fr // 2))
                screen.blit(fs, (cx - fr, cy - fr), special_flags=pygame.BLEND_ADD)

            # 코어 글로우
            cr = int(6 + progress * 40)
            ca = int(200 * life_ratio)
            if ca > 0 and cr > 0:
                cs = _psurf((cr * 2, cr * 2), pygame.SRCALPHA)
                pygame.draw.circle(cs, (self.EXPLOSION_CORE[0], self.EXPLOSION_CORE[1], self.EXPLOSION_CORE[2], ca),
                                   (cr, cr), int(cr * 0.6))
                pygame.draw.circle(cs, (self.EXPLOSION_INNER[0], self.EXPLOSION_INNER[1], self.EXPLOSION_INNER[2], int(ca * 0.5)),
                                   (cr, cr), int(cr * 0.3))
                screen.blit(cs, (cx - cr, cy - cr), special_flags=pygame.BLEND_ADD)

            # 다중 충격파 링 (3중 시간차)
            for ri in range(3):
                rd = ri * 0.1
                rp = max(0.0, progress - rd) / max(0.01, 1.0 - rd)
                if rp <= 0 or rp > 1.0:
                    continue
                rr = int(self.EXPLOSION_DISPLAY * 60 * rp * (ri + 1) * 0.25)
                ra = int((160 - ri * 40) * (1.0 - rp))
                if ra > 0 and rr > 4:
                    rs = _psurf((rr * 2 + 6, rr * 2 + 6), pygame.SRCALPHA)
                    th = max(1, 3 - ri)
                    pygame.draw.circle(rs, (self.EXPLOSION_RING[0], self.EXPLOSION_RING[1], self.EXPLOSION_RING[2], ra),
                                       (rr + 3, rr + 3), rr, th)
                    screen.blit(rs, (cx - rr - 3, cy - rr - 3))

            # 방사형 번개 아크
            if progress < 0.7:
                ac = 5 + int(progress * 8)
                for i in range(ac):
                    a = (i / ac) * math.tau + random.uniform(-0.2, 0.2)
                    ir = 4 + progress * 15
                    orr = ir + random.uniform(15, 35) * (1.0 + progress)
                    sx = cx + int(_cos(a) * ir)
                    sy = cy + int(_sin(a) * ir)
                    ex = cx + int(_cos(a) * orr)
                    ey = cy + int(_sin(a) * orr)
                    mx = (sx + ex) // 2 + random.randint(-6, 6)
                    my = (sy + ey) // 2 + random.randint(-6, 6)
                    col = random.choice([self.EXPLOSION_ARC, (255, 240, 180), (220, 230, 255)])
                    pygame.draw.lines(screen, col, False, [(sx, sy), (mx, my), (ex, ey)], 1)

        # ══════════════════════════════════════════════════
        # 스파크 렌더링 (다양한 타입 + 글로우)
        # ══════════════════════════════════════════════════
        for p in self.sparks:
            pxi, pyi = int(p['x']), int(p['y'])
            lr = p['life'] / p.get('max_life', 0.55)
            am = min(1.0, lr * 2.0)
            col = p.get('color', (255, 255, 200))
            s = max(1, int(p['size'] * am))

            if p.get('type') == 'streak':
                spd = max(0.1, math.hypot(p['vx'], p['vy']))
                tl = max(1.0, spd * 0.8)
                tex = int(p['x'] - p['vx'] / spd * tl)
                tey = int(p['y'] - p['vy'] / spd * tl)
                pygame.draw.line(screen, col, (pxi, pyi), (tex, tey), max(1, s // 2))
                pygame.draw.circle(screen, (255, 255, 255), (pxi, pyi), max(1, s // 3))
            elif p.get('type') == 'flash':
                a = int(180 * am)
                gs = _psurf((s * 2, s * 2), pygame.SRCALPHA)
                pygame.draw.circle(gs, (col[0], col[1], col[2], a), (s, s), s)
                pygame.draw.circle(gs, (255, 255, 255, min(255, int(a * 0.7))), (s, s), max(1, s // 2))
                screen.blit(gs, (pxi - s, pyi - s), special_flags=pygame.BLEND_ADD)
            else:
                pygame.draw.circle(screen, col, (pxi, pyi), max(1, s // 2))
                if s > 2:
                    pygame.draw.circle(screen, (255, 255, 255), (pxi, pyi), max(1, s // 4))

    def reset_for_new_round(self, game_state: dict):
        """라운드 전환 시 이펙트 정리"""
        super().reset_for_new_round(game_state)
        self.lightning_path = None
        self.lightning_branches = []
        self.lightning_ttl = 0.0
        self.explosion_ttl = 0.0
        self.sparks = []


class ThunderOrb(HeroSkill):
    """천둥 뇌구 - 강력한 번개 구체를 발사, 상대 진영에서 폭발하여 범위 내 감전(스턴)

    자동 발동 (쿨타임 16초). 시전자 패들에서 번개 구체를 발사하며,
    상대 진영에 도달 시 폭발(170px). 범위 내 상대가 있으면 2초 감전.
    감전 이펙트는 번개의 분노와 동일 (전류 아크 + 분기 전류 + 스파크).
    """

    # 구체 상수 (에너지볼과 동일 사이즈/속도)
    ORB_SPEED = 605             # 구체 이동 속도 (px/sec) - 504 * 1.2 (20% 증가)
    ORB_RADIUS = 10             # 구체 물리 반지름 - BALL_SIZE = 10
    ORB_VISUAL_RADIUS = 30      # 구체 시각 반지름 (에너지볼 렌더링용)
    EXPLOSION_RADIUS = 170      # 폭발 범위 (px)
    EXPLOSION_DURATION = 0.2    # 폭발 애니메이션 지속 (초) - 2배 빠르게
    STUN_DURATION = 2.0         # 감전(스턴) 시간 (초)
    TOTAL_DURATION = 6.0        # 스킬 최대 지속 시간 (안전장치)

    # 상대 진영 Y 기준
    TARGET_Y_TOP = 65           # 상단 진영 (보스 히트박스 하단)
    TARGET_Y_BOTTOM = 690       # 하단 진영 (플레이어 패들 근처)

    # 페이즈
    PHASE_IDLE = 'idle'
    PHASE_TRAVELING = 'traveling'
    PHASE_EXPLODING = 'exploding'
    PHASE_STUN = 'stun'

    # 에너지볼 색상 (라이트닝 마스터 전기 투사체와 동일)
    ORB_CORE_COLOR = (255, 255, 255)        # 밝은 흰색 코어
    ORB_INNER_COLOR = (200, 230, 255)       # 하얀빛 내부 (흰색에 가까운 연한 블루)
    ORB_OUTER_COLOR = (30, 100, 200)        # 진한 파란색 외부
    ORB_RING_COLOR = (80, 160, 255)         # 회전 고리 색상
    ORB_PARTICLE_COLORS = [
        (200, 230, 255), (150, 200, 255),
        (100, 180, 255), (255, 255, 255),
    ]
    EXPLOSION_COLOR = (100, 180, 255, 100)
    EXPLOSION_RING_COLOR = (80, 160, 255)

    # 감전 이펙트 색상 (번개의 분노와 동일)
    ARC_COLORS_CORE = [(255, 255, 255), (255, 255, 230), (255, 250, 200)]
    ARC_COLORS_OUTER = [
        (120, 180, 255), (80, 140, 255), (160, 200, 255),
        (255, 240, 120), (255, 220, 80),
    ]

    def __init__(self):
        super().__init__(
            skill_id="thunder_orb",
            name="Thunder Orb",
            korean_name="천둥 뇌구",
            description="번개의 구체가 적진에서 작렬하며 감전시킨다",
            trigger=SkillTrigger.ON_COOLDOWN,
            cooldown=16.0,
            duration=self.TOTAL_DURATION,
            hero_id="ra"
        )
        self._sound_loaded = False
        self._sound = None
        self._explode_sound = None       # 폭발 사운드
        self._electric_shock_sound = None
        self._electric_shock_channel = None  # 감전 사운드 채널 (정지용)
        # 런타임 상태
        self.phase = self.PHASE_IDLE
        self.orb_x = 0.0
        self.orb_y = 0.0
        self.orb_vy = 0.0           # 이동 방향 (+아래, -위)
        self.target_y = 0.0         # 폭발 기준 Y
        self.explosion_timer = 0.0
        self.explosion_x = 0.0
        self.explosion_y = 0.0
        self.stun_timer = 0.0
        self.stun_target_is_top = False
        self.stun_target_rect = None  # 감전 대상 패들 rect
        self.orb_trail = []          # 궤적 파티클
        self.orb_sparks = []         # 구체 주변 스파크
        self.energy_particles = []   # 에너지볼 떠다니는 파티클
        self.explosion_particles = []  # 폭발 파티클
        self.orb_rotation = 0.0      # 구체 회전 각도 (도)
        self.orb_rotation_speed = 280.0  # 회전 속도 (도/초)
        # 급감속 시스템: 3.6배속 → 0.8초 동안 급감속 → 0.05배속 크롤링
        self.decel_timer = 0.0           # 감속 경과 시간
        self.decel_duration = 0.8        # 감속 지속 시간 (초)
        self.speed_mult_start = 3.6      # 초기 속도 배율 (4.5 * 0.8 = 3.6배속)
        self.speed_mult_end = 0.05       # 최종 속도 배율 (극저속 ~30px/s)
        self.base_orb_vy = 0.0           # 방향 포함 기본 속도 (ORB_SPEED * ±1)

    def _load_sound(self):
        if self._sound_loaded:
            return
        self._sound_loaded = True
        try:
            project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            # 발사 사운드
            sound_path = os.path.join(project_root, "sounds", "thunderbolt.wav")
            if os.path.exists(sound_path):
                self._sound = pygame.mixer.Sound(sound_path)
                self._sound.set_volume(0.4)
            # 폭발 사운드
            explode_path = os.path.join(project_root, "sounds", "thunderboltboom.wav")
            if os.path.exists(explode_path):
                self._explode_sound = pygame.mixer.Sound(explode_path)
                self._explode_sound.set_volume(0.5)
            # 감전 사운드
            shock_path = os.path.join(project_root, "sounds", "electricshock.wav")
            if os.path.exists(shock_path):
                self._electric_shock_sound = pygame.mixer.Sound(shock_path)
                self._electric_shock_sound.set_volume(0.45)
        except Exception:
            pass

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        """번개 구체 발사"""
        self._load_sound()
        self.phase = self.PHASE_TRAVELING

        # 시전자 패들 중심에서 발사
        cx = caster_paddle.x + getattr(caster_paddle, 'width', 80) / 2
        cy = caster_paddle.y + getattr(caster_paddle, 'height', 10) / 2

        is_top = getattr(self, 'caster_is_top', True)
        if is_top:
            # 상단 → 아래로 발사
            self.base_orb_vy = self.ORB_SPEED
            self.target_y = self.TARGET_Y_BOTTOM
        else:
            # 하단 → 위로 발사
            self.base_orb_vy = -self.ORB_SPEED
            self.target_y = self.TARGET_Y_TOP

        # 급감속: 초기 3배속으로 발사
        self.orb_vy = self.base_orb_vy * self.speed_mult_start
        self.decel_timer = 0.0

        self.orb_x = cx
        self.orb_y = cy
        self.stun_target_is_top = not is_top
        self.orb_trail = []
        self.orb_sparks = []
        self.energy_particles = []
        self.explosion_particles = []
        self.explosion_timer = 0.0
        self.stun_timer = 0.0

        # 사운드
        if self._sound:
            try:
                self._sound.play()
            except Exception:
                pass

        return {
            'screen_effect': ScreenEffect.FLASH,
            'flash_duration': 0.1,
            'flash_color': (255, 230, 100),
            'shake_intensity': 3,
        }

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        """페이즈별 업데이트"""
        if self.phase == self.PHASE_TRAVELING:
            self._update_traveling(dt, target_paddle, game_state)
        elif self.phase == self.PHASE_EXPLODING:
            self._update_exploding(dt, target_paddle, game_state)
        elif self.phase == self.PHASE_STUN:
            self._update_stun(dt, target_paddle, game_state)

    def _update_traveling(self, dt, target_paddle, game_state):
        """구체 이동 + 회전 + 궤적/에너지 파티클 (급감속 적용)"""
        # 급감속 시스템: ease-out, 0.5초 이후 감속율 50% 감소
        if self.decel_timer < self.decel_duration:
            self.decel_timer += dt
            t = min(self.decel_timer / self.decel_duration, 1.0)
            # ease-out (1-(1-t)^2): 발사 직후부터 급격히 감속
            eased = 1.0 - (1.0 - t) * (1.0 - t)
            # 0.5초 이후 감속율 50% 완화 (너무 느려지는 것 방지)
            if self.decel_timer > 0.5:
                t_half = 0.5 / self.decel_duration
                eased_half = 1.0 - (1.0 - t_half) * (1.0 - t_half)
                eased = eased_half + (eased - eased_half) * 0.5
            mult = self.speed_mult_start + (self.speed_mult_end - self.speed_mult_start) * eased
            self.orb_vy = self.base_orb_vy * mult

        self.orb_y += self.orb_vy * dt
        self.orb_rotation = (self.orb_rotation + self.orb_rotation_speed * dt) % 360

        # 궤적 파티클 생성 (파란색 에너지 테마)
        if random.random() < 0.8:
            self.orb_trail.append({
                'x': self.orb_x + random.uniform(-5, 5),
                'y': self.orb_y + random.uniform(-5, 5),
                'life': 0.3,
                'size': random.uniform(1.5, 4),
            })
        # 구체 주변 전기 스파크
        if random.random() < 0.5:
            ang = random.uniform(0, math.tau)
            vr = self.ORB_VISUAL_RADIUS
            dist = random.uniform(vr * 0.6, vr * 1.1)
            self.orb_sparks.append({
                'x': self.orb_x + _cos(ang) * dist,
                'y': self.orb_y + _sin(ang) * dist,
                'ex': self.orb_x + _cos(ang) * (dist + random.uniform(4, 10)),
                'ey': self.orb_y + _sin(ang) * (dist + random.uniform(4, 10)),
                'life': 0.08,
            })
        # 에너지볼 떠다니는 파티클 생성
        if random.random() < 0.4:
            vr = self.ORB_VISUAL_RADIUS
            ang = random.uniform(0, math.tau)
            d = vr * random.uniform(0.9, 1.5)
            self.energy_particles.append({
                'rx': _cos(ang) * d, 'ry': _sin(ang) * d,
                'vx': random.uniform(-0.5, 0.5),
                'vy': random.uniform(-1.5, -0.5),
                'life': random.randint(20, 40), 'max_life': 40,
                'size': random.uniform(0.4, 1.0),
                'color': random.choice(self.ORB_PARTICLE_COLORS),
            })

        # 궤적/스파크/에너지 파티클 업데이트
        self.orb_trail = [p for p in self.orb_trail if (p.__setitem__('life', p['life'] - dt) or True) and p['life'] > 0]  # noqa
        for p in self.orb_trail:
            p['size'] *= 0.95
        self.orb_sparks = [s for s in self.orb_sparks if (s.__setitem__('life', s['life'] - dt) or True) and s['life'] > 0]
        new_ep = []
        for p in self.energy_particles:
            p['rx'] += p['vx']
            p['ry'] += p['vy']
            p['life'] -= 1
            if p['life'] > 0:
                new_ep.append(p)
        self.energy_particles = new_ep[-20:]  # 최대 20개

        # 상대 진영 도달 체크
        reached = False
        if self.orb_vy < 0 and self.orb_y <= self.target_y:
            reached = True
        elif self.orb_vy > 0 and self.orb_y >= self.target_y:
            reached = True

        if reached:
            self._start_explosion(target_paddle, game_state)

    def _start_explosion(self, target_paddle, game_state):
        """폭발 시작"""
        self.phase = self.PHASE_EXPLODING
        self.explosion_timer = self.EXPLOSION_DURATION
        self.explosion_x = self.orb_x
        self.explosion_y = self.orb_y
        game_state['screen_shake'] = 9
        game_state['shake_duration'] = 0.5  # 폭발 시 0.5초 화면 흔들림
        # 폭발 사운드 재생
        if self._explode_sound:
            try:
                self._explode_sound.play()
            except Exception:
                pass
        # 폭발 파티클 생성 (방사형 - 대형 + 소형)
        self.explosion_particles = []
        # 대형 파티클 (밝은 에너지 파편)
        for _ in range(20):
            ang = random.uniform(0, math.tau)
            spd = random.uniform(200, 600)
            self.explosion_particles.append({
                'x': self.orb_x, 'y': self.orb_y,
                'vx': _cos(ang) * spd, 'vy': _sin(ang) * spd,
                'life': random.uniform(0.2, 0.45),
                'size': random.uniform(2, 5),
                'color': random.choice([(200, 230, 255), (255, 255, 255), (150, 210, 255)]),
            })
        # 소형 스파크 파티클
        for _ in range(35):
            ang = random.uniform(0, math.tau)
            spd = random.uniform(300, 800)
            self.explosion_particles.append({
                'x': self.orb_x, 'y': self.orb_y,
                'vx': _cos(ang) * spd, 'vy': _sin(ang) * spd,
                'life': random.uniform(0.1, 0.3),
                'size': random.uniform(1, 2.5),
                'color': random.choice(self.ORB_PARTICLE_COLORS),
            })

    def _update_exploding(self, dt, target_paddle, game_state):
        """폭발 애니메이션 + 범위 판정"""
        self.explosion_timer -= dt
        if self.explosion_timer <= 0:
            # 폭발 종료 → 범위 판정
            tx = target_paddle.x + getattr(target_paddle, 'width', 80) / 2
            ty = target_paddle.y + getattr(target_paddle, 'height', 10) / 2
            dist = math.hypot(tx - self.explosion_x, ty - self.explosion_y)

            if dist <= self.EXPLOSION_RADIUS:
                # 범위 내 → 감전 시작
                self.phase = self.PHASE_STUN
                self.stun_timer = self.STUN_DURATION
                # 스턴 적용
                prefix = 'top_paddle' if self.stun_target_is_top else 'bottom_paddle'
                game_state[f'{prefix}_stunned'] = True
                # 감전 이펙트용 game_state 플래그
                game_state[f'{prefix}_electric_stun'] = True
                self.stun_target_rect = pygame.Rect(
                    int(target_paddle.x), int(target_paddle.y),
                    int(getattr(target_paddle, 'width', 80)),
                    int(getattr(target_paddle, 'height', 10))
                )
                # 감전 사운드 루프 재생
                if self._electric_shock_sound:
                    try:
                        self._electric_shock_channel = self._electric_shock_sound.play(-1)
                    except Exception:
                        pass
            else:
                # 범위 밖 → 스킬 종료
                self.phase = self.PHASE_IDLE
                self.is_active = False
                self.active_timer = 0

    def _update_stun(self, dt, target_paddle, game_state):
        """감전 상태 업데이트"""
        self.stun_timer -= dt
        # 타겟 패들 위치 실시간 추적 (떨림 효과 위치용)
        self.stun_target_rect = pygame.Rect(
            int(target_paddle.x), int(target_paddle.y),
            int(getattr(target_paddle, 'width', 80)),
            int(getattr(target_paddle, 'height', 10))
        )
        if self.stun_timer <= 0:
            # 감전 종료
            prefix = 'top_paddle' if self.stun_target_is_top else 'bottom_paddle'
            game_state[f'{prefix}_stunned'] = False
            game_state[f'{prefix}_electric_stun'] = False
            # 감전 사운드 정지
            self._stop_electric_shock_sound()
            self.phase = self.PHASE_IDLE
            self.is_active = False
            self.active_timer = 0

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        """전체 비주얼 렌더링"""
        if self.phase == self.PHASE_TRAVELING:
            self._draw_orb(screen)
        elif self.phase == self.PHASE_EXPLODING:
            self._draw_explosion(screen)
        elif self.phase == self.PHASE_STUN:
            self._draw_electric_stun(screen)

    def _draw_orb(self, screen):
        """육각형 프레임 + 중앙 에너지볼 + 번개 아크 스타일 렌더링"""
        ox, oy = int(self.orb_x), int(self.orb_y)
        vr = self.ORB_VISUAL_RADIUS  # 시각 반지름 (30)
        t = pygame.time.get_ticks()

        # ── 궤적 파티클 (파란색) ──
        for p in self.orb_trail:
            alpha = int(180 * (p['life'] / 0.3))
            sz = max(1, int(p['size']))
            ts = _psurf((sz * 2, sz * 2), pygame.SRCALPHA)
            pygame.draw.circle(ts, (100, 180, 255, alpha), (sz, sz), sz)
            screen.blit(ts, (int(p['x']) - sz, int(p['y']) - sz))

        # ── 전기 스파크 ──
        for sp in self.orb_sparks:
            col = random.choice(self.ARC_COLORS_CORE)
            pygame.draw.line(screen, col,
                             (int(sp['x']), int(sp['y'])),
                             (int(sp['ex']), int(sp['ey'])), 1)

        # ── 서피스 크기 ──
        surf_size = vr * 6 + 20
        ball_surf = _psurf((surf_size, surf_size), pygame.SRCALPHA)
        center = surf_size // 2

        # 펄스 효과
        pulse = _sin(t * 0.005) * 0.10 + 1.0

        hex_r = vr * 1.15  # 육각형 외접원 반지름

        # === 육각형 꼭짓점 좌표 (번개 아크 끝점용) ===
        hex_pts = []
        for i in range(6):
            ang = math.radians(60 * i - 90)
            hx = center + _cos(ang) * hex_r
            hy = center + _sin(ang) * hex_r
            hex_pts.append((int(hx), int(hy)))

        # 꼭짓점 밝은 점
        for hx, hy in hex_pts:
            pygame.draw.circle(ball_surf, (180, 220, 255, 200), (hx, hy), 3)
            pygame.draw.circle(ball_surf, (255, 255, 255, 160), (hx, hy), 1)

        # === Layer 3: 중앙 에너지 구체 ===
        orb_r = vr * 0.40 * pulse
        # 외부 글로우
        pygame.draw.circle(ball_surf, (*self.ORB_INNER_COLOR, 50), (center, center), int(orb_r * 1.6))
        pygame.draw.circle(ball_surf, (*self.ORB_INNER_COLOR, 80), (center, center), int(orb_r * 1.2))
        # 구체 본체
        mid_col = tuple(int(min(255, c * 0.8 + 50)) for c in self.ORB_INNER_COLOR)
        inner_col = tuple(int(min(255, c * 0.7 + 80)) for c in self.ORB_INNER_COLOR)
        pygame.draw.circle(ball_surf, (*self.ORB_INNER_COLOR, 160), (center, center), int(orb_r))
        pygame.draw.circle(ball_surf, (*mid_col, 190), (center, center), int(orb_r * 0.75))
        pygame.draw.circle(ball_surf, (*inner_col, 220), (center, center), int(orb_r * 0.5))
        # 밝은 코어
        core_sz = max(2, int(orb_r * 0.35))
        pygame.draw.circle(ball_surf, (*self.ORB_CORE_COLOR, 240), (center, center), core_sz)
        pygame.draw.circle(ball_surf, (255, 255, 255, 250), (center, center), max(1, core_sz // 2))

        # === Layer 4: 구체→꼭짓점 번개 아크 6개 ===
        orb_surface_r = orb_r * 0.9
        for i in range(6):
            ang = math.radians(60 * i - 90)
            # 구체 표면 시작점
            sx = center + _cos(ang) * orb_surface_r
            sy = center + _sin(ang) * orb_surface_r
            # 꼭짓점 끝점
            ex_f, ey_f = float(hex_pts[i][0]), float(hex_pts[i][1])
            # 중간 지그재그 (약간 어긋남 + 시간에 따라 흔들림)
            jitter = _sin(t * 0.008 + i * 1.1) * 5
            mid_ang = math.radians(60 * i - 90 + 10 + jitter)
            mid_r = hex_r * 0.55
            mx = center + _cos(mid_ang) * mid_r
            my = center + _sin(mid_ang) * mid_r
            # 아크 글로우 (두꺼운 반투명 파란선)
            pygame.draw.line(ball_surf, (60, 130, 255, 90),
                             (int(sx), int(sy)), (int(mx), int(my)), 3)
            pygame.draw.line(ball_surf, (60, 130, 255, 90),
                             (int(mx), int(my)), (int(ex_f), int(ey_f)), 3)
            # 아크 코어 (가는 밝은 선)
            pygame.draw.line(ball_surf, (200, 230, 255, 220),
                             (int(sx), int(sy)), (int(mx), int(my)), 1)
            pygame.draw.line(ball_surf, (200, 230, 255, 220),
                             (int(mx), int(my)), (int(ex_f), int(ey_f)), 1)

        # === Layer 5: 떠다니는 에너지 파티클 ===
        for p in self.energy_particles:
            if p['life'] > 0:
                alpha = int(200 * (p['life'] / p['max_life']))
                sz = int(p['size'] * (p['life'] / p['max_life']))
                if alpha > 0 and sz > 0:
                    px = int(center + p['rx'])
                    py = int(center + p['ry'])
                    if 0 < px < surf_size and 0 < py < surf_size:
                        pygame.draw.circle(ball_surf, (*p['color'], alpha), (px, py), max(1, sz))

        # 서피스를 회전 후 화면에 블릿
        rotated = pygame.transform.rotate(ball_surf, self.orb_rotation)
        rr = rotated.get_rect(center=(ox, oy))
        screen.blit(rotated, rr)

        # === Layer 6: 전기 아크 (프레임 바깥, 직접 screen에) ===
        for _ in range(random.randint(2, 4)):
            a = random.uniform(0, math.tau)
            sr = random.uniform(vr * 0.8, vr * 1.3)
            sx = ox + int(_cos(a) * sr)
            sy = oy + int(_sin(a) * sr)
            a2 = a + random.uniform(-0.6, 0.6)
            er = sr + random.uniform(5, 12)
            ex_s = ox + int(_cos(a2) * er)
            ey_s = oy + int(_sin(a2) * er)
            col = random.choice(self.ARC_COLORS_OUTER)
            pygame.draw.line(screen, col, (sx, sy), (ex_s, ey_s), 1)

    def _draw_explosion(self, screen):
        """폭발 이펙트 렌더링 (강력한 전기 폭발)"""
        progress = 1.0 - (self.explosion_timer / self.EXPLOSION_DURATION)
        cx, cy = int(self.explosion_x), int(self.explosion_y)
        current_r = int(self.EXPLOSION_RADIUS * progress)
        dt = 1.0 / 60.0

        # 폭발 파티클 업데이트 & 렌더링
        new_ep = []
        for p in self.explosion_particles:
            p['x'] += p['vx'] * dt
            p['y'] += p['vy'] * dt
            p['vx'] *= 0.97  # 감속
            p['vy'] *= 0.97
            p['life'] -= dt
            if p['life'] > 0:
                new_ep.append(p)
                life_ratio = p['life'] / 0.45
                alpha = min(255, int(255 * life_ratio))
                sz = max(1, int(p['size'] * max(0.3, life_ratio)))
                if alpha > 0 and sz > 0:
                    ps = _psurf((sz * 2 + 4, sz * 2 + 4), pygame.SRCALPHA)
                    pc = sz + 2
                    # 파티클 글로우
                    pygame.draw.circle(ps, (*p['color'][:3], alpha // 3), (pc, pc), sz + 2)
                    pygame.draw.circle(ps, (*p['color'][:3], alpha), (pc, pc), sz)
                    screen.blit(ps, (int(p['x']) - pc, int(p['y']) - pc))
        self.explosion_particles = new_ep

        if current_r <= 0:
            return

        # === 초기 플래시 (progress < 0.4) - 더 크고 밝게 ===
        if progress < 0.4:
            flash_f = 1.0 - progress / 0.4
            # 외곽 넓은 글로우
            flash_r_outer = int(current_r * 0.9)
            flash_a_outer = int(80 * flash_f)
            if flash_r_outer > 0 and flash_a_outer > 0:
                fs = _psurf((flash_r_outer * 2, flash_r_outer * 2), pygame.SRCALPHA)
                pygame.draw.circle(fs, (100, 180, 255, flash_a_outer), (flash_r_outer, flash_r_outer), flash_r_outer)
                screen.blit(fs, (cx - flash_r_outer, cy - flash_r_outer))
            # 중심 백색 플래시
            flash_r = int(current_r * 0.5)
            flash_a = int(220 * flash_f)
            if flash_r > 0 and flash_a > 0:
                fs = _psurf((flash_r * 2, flash_r * 2), pygame.SRCALPHA)
                pygame.draw.circle(fs, (255, 255, 255, flash_a), (flash_r, flash_r), flash_r)
                screen.blit(fs, (cx - flash_r, cy - flash_r))

        # === 다중 충격파 링 (5개, 시간차) - 더 두껍고 밝게 ===
        ring_colors = [
            (100, 180, 255), (150, 210, 255), (80, 160, 255),
            (180, 220, 255), (60, 140, 240),
        ]
        for ring_idx in range(5):
            ring_delay = ring_idx * 0.07
            ring_prog = max(0.0, progress - ring_delay)
            if ring_prog <= 0:
                continue
            ring_r = int(self.EXPLOSION_RADIUS * min(1.0, ring_prog * 1.4))
            ring_a = int((220 - ring_idx * 30) * (1.0 - min(1.0, ring_prog)))
            ring_w = max(1, 4 - ring_idx)
            if ring_r > 0 and ring_a > 0:
                rs = _psurf((ring_r * 2 + 10, ring_r * 2 + 10), pygame.SRCALPHA)
                rc = ring_colors[ring_idx % len(ring_colors)]
                rsc = ring_r + 5
                # 글로우 링 (두꺼운 외곽)
                if ring_w >= 2:
                    pygame.draw.circle(rs, (*rc, ring_a // 3), (rsc, rsc), ring_r + 2, ring_w + 2)
                # 메인 링
                pygame.draw.circle(rs, (*rc, ring_a), (rsc, rsc), ring_r, ring_w)
                screen.blit(rs, (cx - rsc, cy - rsc))

        # === 내부 에너지 필드 (다층 채우기) ===
        # 외곽 글로우
        fill_a1 = int(50 * (1.0 - progress))
        if fill_a1 > 0:
            fill_r1 = int(current_r * 0.9)
            if fill_r1 > 0:
                fs = _psurf((fill_r1 * 2, fill_r1 * 2), pygame.SRCALPHA)
                pygame.draw.circle(fs, (20, 80, 180, fill_a1), (fill_r1, fill_r1), fill_r1)
                screen.blit(fs, (cx - fill_r1, cy - fill_r1))
        # 내부 밝은 영역
        fill_a2 = int(90 * (1.0 - progress))
        if fill_a2 > 0:
            fill_r2 = int(current_r * 0.5)
            if fill_r2 > 0:
                fs = _psurf((fill_r2 * 2, fill_r2 * 2), pygame.SRCALPHA)
                pygame.draw.circle(fs, (60, 140, 230, fill_a2), (fill_r2, fill_r2), fill_r2)
                screen.blit(fs, (cx - fill_r2, cy - fill_r2))

        # === 번개 웹 패턴 (방사형 + 원형 연결) - 더 많고 굵게 ===
        arc_count = 12 + int(progress * 10)
        web_pts = []
        for i in range(arc_count):
            a = (i / arc_count) * math.tau + random.uniform(-0.15, 0.15)
            inner_r = current_r * 0.1
            outer_r = current_r * random.uniform(0.85, 1.15)
            sx = cx + int(_cos(a) * inner_r)
            sy = cy + int(_sin(a) * inner_r)
            ex = cx + int(_cos(a) * outer_r)
            ey = cy + int(_sin(a) * outer_r)
            # 지그재그 중간점 3개
            pts = [(sx, sy)]
            for seg in range(3):
                f = (seg + 1) / 4.0
                jitter = int(14 * (1.0 - f * 0.3))
                mx = int(sx + (ex - sx) * f + random.randint(-jitter, jitter))
                my = int(sy + (ey - sy) * f + random.randint(-jitter, jitter))
                pts.append((mx, my))
            pts.append((ex, ey))
            # 외부 글로우 (두꺼운 파란색)
            glow_col = random.choice(self.ARC_COLORS_OUTER)
            pygame.draw.lines(screen, (*glow_col[:3], 100) if len(glow_col) == 3 else glow_col, False, pts, 4)
            # 중간 밝은 선
            mid_col = random.choice(self.ARC_COLORS_CORE)
            pygame.draw.lines(screen, mid_col, False, pts, 2)
            # 코어 (밝은 흰색)
            pygame.draw.lines(screen, (255, 255, 255), False, pts, 1)
            web_pts.append((ex, ey))

        # 외곽 점들 원형 연결 (번개 웹) - 더 많은 연결
        if len(web_pts) >= 3:
            for i in range(len(web_pts)):
                if random.random() < 0.7:
                    p1 = web_pts[i]
                    p2 = web_pts[(i + 1) % len(web_pts)]
                    mx = (p1[0] + p2[0]) // 2 + random.randint(-8, 8)
                    my = (p1[1] + p2[1]) // 2 + random.randint(-8, 8)
                    col = random.choice(self.ARC_COLORS_CORE)
                    pygame.draw.lines(screen, col, False, [p1, (mx, my), p2], 2)
                    pygame.draw.lines(screen, (255, 255, 255, 180), False, [p1, (mx, my), p2], 1)

        # === 중심 코어 글로우 (밝고 크게) ===
        core_f = 1.0 - progress
        core_a = int(255 * core_f)
        if core_a > 0:
            # 외곽 글로우
            core_r3 = max(3, int(18 * core_f))
            pygame.draw.circle(screen, (80, 160, 255, core_a // 2), (cx, cy), core_r3)
            # 내부 밝은 코어
            core_r2 = max(2, int(12 * core_f))
            pygame.draw.circle(screen, (200, 230, 255, core_a), (cx, cy), core_r2)
            # 중심 백색
            core_r1 = max(1, int(6 * core_f))
            pygame.draw.circle(screen, (255, 255, 255, min(255, core_a + 30)), (cx, cy), core_r1)

    def _draw_electric_stun(self, screen):
        """감전 이펙트 - 번개의 분노와 동일"""
        if not self.stun_target_rect:
            return
        rect = self.stun_target_rect
        cx, cy = rect.centerx, rect.centery
        # 오프셋 (캐릭터 몸체 중심으로)
        offset_y = 20 if self.stun_target_is_top else -20
        cy += offset_y
        hw = rect.width // 2 + 5
        hh = 28

        # ── 1. 주요 전류 아크 ──
        for _ in range(1):
            sx = cx + random.randint(-hw // 3, hw // 3)
            sy = cy + random.randint(-hh // 2, hh // 2)
            arc_len = random.randint(12, 22)
            a = random.uniform(0, math.tau)
            ex = sx + int(_cos(a) * arc_len)
            ey = sy + int(_sin(a) * arc_len)
            segs = random.randint(3, 4)
            pts = [(int(sx), int(sy))]
            for j in range(1, segs):
                frac = j / segs
                mx = sx + (ex - sx) * frac + random.uniform(-2.5, 2.5)
                my = sy + (ey - sy) * frac + random.uniform(-2, 2)
                pts.append((int(mx), int(my)))
            pts.append((int(ex), int(ey)))
            if len(pts) >= 2:
                pygame.draw.lines(screen, random.choice(self.ARC_COLORS_OUTER), False, pts, 2)
                pygame.draw.lines(screen, random.choice(self.ARC_COLORS_CORE), False, pts, 1)

        # ── 2. 분기 전류 ──
        branch_count = random.randint(4, 7)
        for _ in range(branch_count):
            bx = cx + random.randint(-hw, hw)
            by = cy + random.randint(-hh, hh)
            b_angle = random.uniform(0, math.tau)
            b_len = random.uniform(8, 18)
            pts = [(int(bx), int(by))]
            segs = random.randint(2, 4)
            for j in range(1, segs + 1):
                frac = j / segs
                nx = bx + _cos(b_angle) * b_len * frac + random.uniform(-4, 4)
                ny = by + _sin(b_angle) * b_len * frac + random.uniform(-4, 4)
                pts.append((int(nx), int(ny)))
            col = random.choice(self.ARC_COLORS_OUTER + self.ARC_COLORS_CORE)
            if len(pts) >= 2:
                pygame.draw.lines(screen, col, False, pts, 1)

        # ── 3. 스파크 포인트 ──
        spark_count = random.randint(1, 2)
        for _ in range(spark_count):
            sp_x = cx + random.randint(-hw, hw)
            sp_y = cy + random.randint(-hh, hh)
            sp_size = random.randint(1, 2)
            sp_col = random.choice([(255, 255, 255), (255, 255, 200), (200, 230, 255)])
            pygame.draw.circle(screen, sp_col, (sp_x, sp_y), sp_size)

    def _stop_electric_shock_sound(self):
        """감전 사운드 정지"""
        try:
            if self._electric_shock_channel and self._electric_shock_channel.get_busy():
                self._electric_shock_channel.stop()
            self._electric_shock_channel = None
        except Exception:
            self._electric_shock_channel = None

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        """스킬 종료 정리"""
        # 감전 상태 해제
        if self.phase == self.PHASE_STUN:
            prefix = 'top_paddle' if self.stun_target_is_top else 'bottom_paddle'
            game_state[f'{prefix}_stunned'] = False
            game_state[f'{prefix}_electric_stun'] = False
        self._stop_electric_shock_sound()  # 감전 사운드 정지
        self.phase = self.PHASE_IDLE
        self.orb_trail = []
        self.orb_sparks = []
        self.energy_particles = []
        self.explosion_particles = []
        self.stun_target_rect = None

    def reset_for_new_round(self, game_state: dict):
        """라운드 전환 시 정리"""
        # 감전 해제
        if self.phase == self.PHASE_STUN:
            prefix = 'top_paddle' if self.stun_target_is_top else 'bottom_paddle'
            game_state[f'{prefix}_stunned'] = False
            game_state[f'{prefix}_electric_stun'] = False
        self._stop_electric_shock_sound()  # 감전 사운드 정지
        super().reset_for_new_round(game_state)
        self.phase = self.PHASE_IDLE
        self.orb_trail = []
        self.orb_sparks = []
        self.energy_particles = []
        self.explosion_particles = []
        self.stun_timer = 0.0
        self.explosion_timer = 0.0
        self.stun_target_rect = None


# ============================================================================
# 원숭이왕 (monkeyking) 스킬
# ============================================================================
class BananaSlice(HeroSkill):
    """바나나 슬라이스 - 바나나를 던져 상대가 밟으면 미끄러진다 (액티브 아이템 바나나와 동일 효과)"""

    THROW_SPEED = 1200          # px/s (원본 20px/frame * 60fps)
    SLIP_DURATION = 0.8         # 미끄러짐 지속 (초) - 스테이지2 바나나와 동일
    SLIP_SPEED = 15             # 미끄러짐 속도 (px/frame) - 스테이지2 바나나와 동일 선형 감속
    LAND_DURATION = 3.0         # 착지 후 유지 (초)
    PREPARE_TIME = 0.3          # 준비 동작 (초, 원본 18프레임)
    TOP_LAND_Y = 45             # 상단 착지 Y
    BOTTOM_LAND_Y = 710         # 하단 착지 Y

    def __init__(self):
        super().__init__(
            skill_id="banana_slice",
            name="Banana Slice",
            korean_name="바나나 슬라이스",
            description="교활한 바나나 껍질이 상대의 발밑을 노린다",
            trigger=SkillTrigger.ON_BALL_HIT,
            cooldown=18.0,
            duration=999.0,
            hero_id="monkeyking"
        )
        self.caster_is_top = False
        self.target_is_top = False
        self.preparing = False
        self.prepare_timer = 0.0
        self.prepare_display_x = 0.0
        self.prepare_display_y = 0.0
        self._pending_target_xs = [380.0]
        self.projectiles = []
        self.landed_bananas = []
        self.target_slipping = False
        self.slip_timer = 0.0
        self.slip_direction = 0
        self.burst_particles = []
        self._throw_sound = None
        self._slip_sound = None
        self._sounds_loaded = False

    def _load_sounds(self):
        if self._sounds_loaded:
            return
        self._sounds_loaded = True
        try:
            project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            throw_path = os.path.join(project_root, "sounds", "throwingbanana.wav")
            if os.path.exists(throw_path):
                self._throw_sound = pygame.mixer.Sound(throw_path)
                self._throw_sound.set_volume(0.6)
            slip_path = os.path.join(project_root, "sounds", "bananastep.wav")
            if os.path.exists(slip_path):
                self._slip_sound = pygame.mixer.Sound(slip_path)
                self._slip_sound.set_volume(0.7)
        except Exception:
            pass

    def _play_throw_sound(self):
        if self._throw_sound:
            try:
                self._throw_sound.play()
            except Exception:
                pass

    def _play_slip_sound(self):
        if self._slip_sound:
            try:
                self._slip_sound.play()
            except Exception:
                pass

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        self.caster_is_top = caster_paddle.is_top
        self.target_is_top = target_paddle.is_top
        self.projectiles = []
        self.landed_bananas = []
        self.burst_particles = []
        self.target_slipping = False
        self.slip_timer = 0.0
        self.slip_direction = 0
        self.preparing = True
        self.prepare_timer = self.PREPARE_TIME
        self.prepare_display_x = caster_paddle.x + caster_paddle.width // 2
        if self.caster_is_top:
            self.prepare_display_y = caster_paddle.y + caster_paddle.height + 10
        else:
            self.prepare_display_y = caster_paddle.y - 10
        # 상대 진영 x축 0~760 중 랜덤 2곳에 바나나 투척
        self._pending_target_xs = self._generate_random_landing_positions(2)
        self._load_sounds()
        return {}

    def _generate_random_landing_positions(self, count: int) -> list:
        """게임 영역(0~760) 내 랜덤 착지 위치 생성 (최소 간격 보장)"""
        margin = 40
        min_gap = 120  # 두 바나나 사이 최소 간격
        positions = []
        for _ in range(count):
            for _attempt in range(20):
                x = random.randint(margin, self.GAME_RIGHT - margin)
                if all(abs(x - px) >= min_gap for px in positions):
                    break
            positions.append(x)
        return positions

    def _execute_throw(self, caster_paddle):
        """준비 동작 완료 후 바나나 2개 투척 (각각 랜덤 위치, 시차 발사)"""
        start_x = self.prepare_display_x
        start_y = self.prepare_display_y
        vel_y = self.THROW_SPEED if self.caster_is_top else -self.THROW_SPEED
        for i, target_x in enumerate(self._pending_target_xs):
            dx = target_x - start_x
            if abs(dx) > 1:
                vel_x = (dx / abs(dx)) * min(abs(dx) * 2, self.THROW_SPEED * 0.3)
            else:
                vel_x = 0.0
            # 두 번째 바나나는 약간의 발사 딜레이 (시각적 구분)
            delay_offset = i * 0.15  # 0.15초 간격
            self.projectiles.append({
                'x': float(start_x), 'y': float(start_y),
                'vel_x': vel_x, 'vel_y': vel_y,
                'rotation': 0.0,
                'rotation_speed': random.uniform(480, 900) * random.choice([-1, 1]),
                'active': True,
                'delay': delay_offset,  # 발사 딜레이
            })
        print(f"[BananaSlice] 🍌 바나나 {len(self._pending_target_xs)}개 투척! 목표 X: {self._pending_target_xs}")
        self._play_throw_sound()

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        # 준비 동작
        if self.preparing:
            self.prepare_timer -= dt
            self.prepare_display_x = caster_paddle.x + caster_paddle.width // 2
            if self.caster_is_top:
                self.prepare_display_y = caster_paddle.y + caster_paddle.height + 10
            else:
                self.prepare_display_y = caster_paddle.y - 10
            if self.prepare_timer <= 0:
                self.preparing = False
                self._execute_throw(caster_paddle)

        land_y = self.TOP_LAND_Y if self.target_is_top else self.BOTTOM_LAND_Y

        # 투척체 업데이트
        for proj in self.projectiles[:]:
            if not proj['active']:
                self.projectiles.remove(proj)
                continue
            # 발사 딜레이 처리 (딜레이 중에는 대기)
            if proj.get('delay', 0) > 0:
                proj['delay'] -= dt
                continue
            proj['x'] += proj['vel_x'] * dt
            proj['y'] += proj['vel_y'] * dt
            proj['rotation'] += proj['rotation_speed'] * dt
            # 좌우 벽 충돌
            if proj['x'] <= self.GAME_LEFT + 10:
                proj['x'] = self.GAME_LEFT + 10
                proj['vel_x'] = abs(proj['vel_x']) * 0.7
            elif proj['x'] >= self.GAME_RIGHT - 10:
                proj['x'] = self.GAME_RIGHT - 10
                proj['vel_x'] = -abs(proj['vel_x']) * 0.7
            # 타겟 진영 도달
            if self.target_is_top and proj['vel_y'] < 0 and proj['y'] <= land_y:
                self._land_banana(proj, land_y)
                continue
            elif not self.target_is_top and proj['vel_y'] > 0 and proj['y'] >= land_y:
                self._land_banana(proj, land_y)
                continue
            if proj['y'] < -50 or proj['y'] > 800:
                proj['active'] = False

        # 착지한 바나나 업데이트
        for landed in self.landed_bananas[:]:
            if not landed['active']:
                self.landed_bananas.remove(landed)
                continue
            landed['timer'] -= dt
            if not landed['slip_triggered']:
                if target_paddle.is_top == self.target_is_top:
                    ptc = target_paddle
                else:
                    ptc = caster_paddle
                p_w = getattr(ptc, 'width', 80)
                p_h = getattr(ptc, 'height', 20)
                paddle_rect = pygame.Rect(ptc.x, ptc.y, p_w, p_h)
                banana_rect = pygame.Rect(int(landed['x']) - 40, int(landed['y']) - 25, 80, 50)
                if paddle_rect.colliderect(banana_rect):
                    # 마법결계 면역 체크 - 면역 상태면 슬립 차단
                    _immunity_side = 'top' if self.target_is_top else 'bottom'
                    if game_state.get(f'magic_immunity_{_immunity_side}', False):
                        landed['slip_triggered'] = True
                        landed['active'] = False
                        self._create_burst_particles(landed['x'], landed['y'])
                        # 패링 이펙트 이벤트 전달
                        if 'barrier_block_events' not in game_state:
                            game_state['barrier_block_events'] = []
                        game_state['barrier_block_events'].append({
                            'skill_korean_name': self.korean_name,
                            'caster_is_top': getattr(self, 'caster_is_top', True),
                            'caster_x': caster_paddle.x + getattr(caster_paddle, 'width', 80) / 2,
                            'caster_y': caster_paddle.y + getattr(caster_paddle, 'height', 10) / 2,
                            'target_x': target_paddle.x + getattr(target_paddle, 'width', 80) / 2,
                            'target_y': target_paddle.y + getattr(target_paddle, 'height', 10) / 2,
                        })
                        continue
                    landed['slip_triggered'] = True
                    landed['active'] = False
                    self.target_slipping = True
                    self.slip_timer = self.SLIP_DURATION
                    paddle_cx = ptc.x + p_w // 2
                    if abs(paddle_cx - landed['x']) < 10:
                        self.slip_direction = random.choice([-1, 1])
                    else:
                        self.slip_direction = -1 if paddle_cx > landed['x'] else 1
                    self._create_burst_particles(landed['x'], landed['y'])
                    # 스테이지2 바나나와 동일한 선형 감속 슬립 (넉백 시스템 미사용)
                    target_prefix = 'top_paddle' if self.target_is_top else 'bottom_paddle'
                    game_state[f'{target_prefix}_banana_slip_active'] = True
                    game_state['screen_shake'] = 5
                    game_state['shake_duration'] = 0.2
                    self._play_slip_sound()
                    continue
            if landed['timer'] <= 0:
                landed['active'] = False

        # 미끄러짐 상태 관리 (스테이지2 바나나와 동일한 선형 감속)
        if self.target_slipping:
            self.slip_timer -= dt
            target_prefix = 'top_paddle' if self.target_is_top else 'bottom_paddle'
            # 선형 감속: 시작 시 최대 속도, 끝날 때 0 (스테이지2 get_slip_offset과 동일)
            strength = self.slip_timer / self.SLIP_DURATION  # 1.0 → 0.0
            slip_offset = self.slip_direction * self.SLIP_SPEED * strength
            game_state[f'{target_prefix}_banana_slip_offset'] = slip_offset
            game_state[f'{target_prefix}_banana_slip_active'] = True
            if self.slip_timer <= 0:
                self.target_slipping = False
                self.slip_direction = 0
                game_state[f'{target_prefix}_banana_slip_active'] = False
                game_state[f'{target_prefix}_banana_slip_offset'] = 0

        # 파티클 업데이트
        for p in self.burst_particles[:]:
            p['x'] += p['vx'] * dt
            p['y'] += p['vy'] * dt
            p['vy'] += 1200 * dt
            p['life'] -= dt
            if p['life'] <= 0:
                self.burst_particles.remove(p)

        # 종료 체크
        if (not self.preparing and not self.projectiles and
                not self.landed_bananas and not self.target_slipping and
                not self.burst_particles):
            self.active_timer = 0

    def _land_banana(self, proj, land_y):
        landed_x = max(30, min(730, proj['x']))
        self.landed_bananas.append({
            'x': landed_x, 'y': land_y,
            'timer': self.LAND_DURATION, 'active': True, 'slip_triggered': False,
        })
        proj['active'] = False

    def _create_burst_particles(self, x: float, y: float):
        colors = [(255, 225, 50), (227, 189, 52), (198, 156, 41),
                  (255, 255, 200), (139, 90, 43)]
        for _ in range(12):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(180, 480)
            self.burst_particles.append({
                'x': x, 'y': y,
                'vx': _cos(angle) * speed, 'vy': _sin(angle) * speed - 180,
                'size': random.randint(3, 7), 'color': random.choice(colors),
                'life': random.uniform(0.33, 0.67),
            })

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        self.projectiles = []
        self.landed_bananas = []
        self.burst_particles = []
        self.preparing = False
        self.target_slipping = False
        for prefix in ['top_paddle', 'bottom_paddle']:
            game_state[f'{prefix}_banana_slip_active'] = False
            game_state[f'{prefix}_banana_slip_offset'] = 0

    def reset_for_new_round(self, game_state: dict):
        super().reset_for_new_round(game_state)
        self.projectiles = []
        self.landed_bananas = []
        self.burst_particles = []
        self.preparing = False
        self.prepare_timer = 0.0
        self.target_slipping = False
        self.slip_timer = 0.0
        self.slip_direction = 0
        for prefix in ['top_paddle', 'bottom_paddle']:
            game_state[f'{prefix}_banana_slip_active'] = False
            game_state[f'{prefix}_banana_slip_offset'] = 0

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        # 준비 동작 중 바나나
        if self.preparing:
            x, y = int(self.prepare_display_x), int(self.prepare_display_y)
            progress = 1.0 - (self.prepare_timer / self.PREPARE_TIME)
            offset_y = int(20 * progress) if self.caster_is_top else int(-20 * progress)
            banana_surf = self._create_banana_surface(64)
            rotation = -15 + progress * 30
            rotated = pygame.transform.rotate(banana_surf, rotation)
            rect = rotated.get_rect(center=(x, y + offset_y))
            screen.blit(rotated, rect)

        # 비행 중 바나나
        for proj in self.projectiles:
            if not proj['active'] or proj.get('delay', 0) > 0:
                continue
            banana_surf = self._create_banana_surface(64)
            rotated = pygame.transform.rotate(banana_surf, proj['rotation'])
            rect = rotated.get_rect(center=(int(proj['x']), int(proj['y'])))
            screen.blit(rotated, rect)

        # 착지한 바나나
        for landed in self.landed_bananas:
            if not landed['active']:
                continue
            x, y = int(landed['x']), int(landed['y'])
            if landed['timer'] < 1.0 and int(landed['timer'] * 12) % 2 == 0:
                continue
            banana_surf = self._create_banana_surface(72)
            rotated = pygame.transform.rotate(banana_surf, 15)
            rect = rotated.get_rect(center=(x, y))
            screen.blit(rotated, rect)
            if not landed['slip_triggered']:
                warning_surf = _psurf((60, 20), pygame.SRCALPHA)
                pygame.draw.ellipse(warning_surf, (255, 255, 0, 80), (0, 5, 60, 10))
                screen.blit(warning_surf, (x - 30, y + 5))

        # 터지는 파티클
        for p in self.burst_particles:
            life_ratio = max(0, p['life'] / 0.67)
            size = max(1, int(p['size'] * life_ratio))
            alpha = int(255 * life_ratio)
            if size > 0 and alpha > 0:
                ps = _psurf((size * 2, size * 2), pygame.SRCALPHA)
                pygame.draw.circle(ps, (*p['color'], alpha), (size, size), size)
                screen.blit(ps, (int(p['x']) - size, int(p['y']) - size))

    @staticmethod
    def _create_banana_surface(size: int) -> pygame.Surface:
        """바나나 서피스 (액티브 아이템과 동일한 초승달 모양)"""
        surf = _psurf((size, size), pygame.SRCALPHA)
        cx, cy = size // 2, size // 2
        peel_dark = (198, 156, 41)
        peel_mid = (227, 189, 52)
        peel_light = (247, 220, 89)
        stem_green = (154, 165, 67)
        tip_dark = (89, 60, 31)
        scale = size / 48
        body_points = []
        for i in range(15):
            t = i / 14
            x = cx - 15 * scale + t * 30 * scale
            curve = -10 * scale * _sin(t * math.pi)
            y = cy + curve
            body_points.append((x, y))
        for i in range(14, -1, -1):
            t = i / 14
            x = cx - 15 * scale + t * 30 * scale
            curve = -5 * scale * _sin(t * math.pi) + 6 * scale
            y = cy + curve
            body_points.append((x, y))
        if len(body_points) >= 3:
            pygame.draw.polygon(surf, peel_dark, body_points)
            inner_points = [(p[0], p[1] - scale) for p in body_points]
            pygame.draw.polygon(surf, peel_mid, inner_points)
            hl_pts = []
            for i in range(8):
                t = i / 7
                x = cx - 10 * scale + t * 20 * scale
                y = cy - 7 * scale * _sin(t * math.pi)
                hl_pts.append((x, y))
            for i in range(7, -1, -1):
                t = i / 7
                x = cx - 10 * scale + t * 20 * scale
                y = cy - 4 * scale * _sin(t * math.pi) + 2 * scale
                hl_pts.append((x, y))
            if len(hl_pts) >= 3:
                pygame.draw.polygon(surf, peel_light, hl_pts)
        stem_x = cx - 16 * scale
        stem_y = cy
        pygame.draw.ellipse(surf, stem_green,
                            (stem_x - 3 * scale, stem_y - 2 * scale, 5 * scale, 4 * scale))
        tip_x = cx + 16 * scale
        tip_y = cy + 2 * scale
        pygame.draw.ellipse(surf, tip_dark,
                            (tip_x - 2 * scale, tip_y - 2 * scale, 4 * scale, 3 * scale))
        return surf


class WildRoar(HeroSkill):
    """야생의 포효 - 충격파를 펼쳐 공이 닿으면 260% 가속 반사"""

    SHOCKWAVE_RADIUS = 252      # 충격파 최대 반경 (px) (-30% 축소)
    SHOCKWAVE_GROW_TIME = 0.09  # 충격파 확장 시간 (초) (2x 더 빠르게)
    BALL_SPEED_BOOST = 3.6      # 공 속도 배율 (260% 증가) - 가장 가까울 때 기준
    ROAR_FREEZE_TIME = 0.6      # 포효 시 이동 불가 시간 (초)
    TRIGGER_DIST_MIN = 150      # 발동 최소 거리 (px) - 가까울수록 공속 빠름
    TRIGGER_DIST_MAX = 230      # 발동 최대 거리 (px) - 멀수록 공속 -70%

    def __init__(self):
        super().__init__(
            skill_id="wild_roar",
            name="Wild Roar",
            korean_name="야생의 포효",
            description="대지를 뒤흔드는 포효가 공을 폭풍처럼 가속시킨다",
            trigger=SkillTrigger.ON_COOLDOWN,
            cooldown=27.0,
            duration=1.8,
            hero_id="monkeyking"
        )
        self.caster_is_top = False
        self.shockwave_timer = 0.0
        self.shockwave_radius = 0.0
        self.ball_reflected = False
        self._ball_in_range = False
        self._cx = 380.0
        self._cy = 375.0
        self.ring_effects = []
        self.impact_particles = []
        self.roar_freeze_timer = 0.0   # 포효 중 이동 불가 타이머
        self._freeze_applied = False    # 스턴 적용 여부
        self._trigger_distance = 0.0   # 이번 사이클 랜덤 발동 거리
        self._actual_boost = self.BALL_SPEED_BOOST  # 거리 기반 실제 부스트
        self._roar_sound = None
        self._hit_sound = None
        self._sounds_loaded = False

    def _load_sounds(self):
        if self._sounds_loaded:
            return
        self._sounds_loaded = True
        try:
            project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            roar_path = os.path.join(project_root, "sounds", "monkeyshouting.wav")
            if os.path.exists(roar_path):
                self._roar_sound = pygame.mixer.Sound(roar_path)
                self._roar_sound.set_volume(0.7)
            self._hit_sound = None  # 충격파 반사 시 피격음 없음
        except Exception:
            pass

    # ------------------------------------------------------------------
    # 발동 조건: 쿨타임 완료 + 공이 접근 중일 때만
    # ------------------------------------------------------------------
    def can_use(self) -> bool:
        return (self.current_cooldown <= 0 and not self.is_active
                and getattr(self, '_ball_in_range', False))

    def update(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        # 공 접근 감지 (활성화 전에만 체크)
        if ball and not self.is_active and self.current_cooldown <= 0:
            # 쿨타임 완료 직후 랜덤 발동 거리 결정 (한 사이클에 한 번)
            if self._trigger_distance <= 0:
                self._trigger_distance = random.uniform(
                    self.TRIGGER_DIST_MIN, self.TRIGGER_DIST_MAX)

            # 패들~공 사이 거리 계산 (X축 + Y축 모두 감지)
            ball_cx = ball.x + getattr(ball, 'width', 10) / 2
            ball_cy = ball.y + getattr(ball, 'height', 10) / 2
            paddle_cx = caster_paddle.x + caster_paddle.width // 2
            if self.caster_is_top:
                paddle_edge = caster_paddle.y + caster_paddle.height
                approaching = ball.vy < 0
                dist_to_ball = ball_cy - paddle_edge
            else:
                paddle_edge = caster_paddle.y
                approaching = ball.vy > 0
                dist_to_ball = paddle_edge - ball_cy

            # X축 거리도 충격파 반경 이내인지 확인 (반사 실패 방지)
            dx = abs(ball_cx - paddle_cx)
            in_x_range = dx <= self.SHOCKWAVE_RADIUS

            if approaching and 0 < dist_to_ball <= self._trigger_distance and in_x_range:
                self._ball_in_range = True
                # 거리 기반 부스트: 가까움 3.6x(260%) ↔ 멀음 2.6x(160%)
                t = max(0, min(1, (self._trigger_distance - self.TRIGGER_DIST_MIN)
                               / (self.TRIGGER_DIST_MAX - self.TRIGGER_DIST_MIN)))
                self._actual_boost = self.BALL_SPEED_BOOST - t * (self.BALL_SPEED_BOOST - 2.6)
            else:
                self._ball_in_range = False
        else:
            self._ball_in_range = False
        super().update(dt, caster_paddle, target_paddle, ball, game_state)

    # ------------------------------------------------------------------
    # 스킬 발동
    # ------------------------------------------------------------------
    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        self.caster_is_top = caster_paddle.is_top
        self.shockwave_timer = 0.0
        self.shockwave_radius = 0.0
        self.ball_reflected = False
        self._ball_in_range = False
        self.ring_effects = []
        self.impact_particles = []
        self.flash_alpha = 200        # 발동 시 플래시 효과
        self.energy_sparks = []       # 확장 중 에너지 스파크
        # 다음 쿨타임 사이클에서 새 랜덤 거리 결정하도록 리셋
        self._trigger_distance = 0.0

        self._cx = caster_paddle.x + caster_paddle.width // 2
        if self.caster_is_top:
            self._cy = caster_paddle.y + caster_paddle.height
        else:
            self._cy = caster_paddle.y

        # 6개 링 (cleanse 스타일 다중 레이어)
        for i in range(6):
            self.ring_effects.append({
                'radius': 0.0,
                'max_radius': self.SHOCKWAVE_RADIUS * (0.35 + i * 0.13),
                'alpha': 255 - i * 30,
                'delay': i * 0.025,   # 더 빠른 연쇄
                'timer': 0.0,
                'thickness': max(2, 5 - i),
                'fade_alpha': 1.0,          # 개별 페이드 (1.0=보임, 0.0=사라짐)
                'reached_max': False,       # 최대 반경 도달 여부
                'linger_timer': 0.0,        # 최대 반경 후 유지 시간
                'linger_delay': 0.05 + i * 0.04,  # 빠른 순차 페이드 (잔존 방지)
            })

        # 초기 에너지 스파크 생성
        for _ in range(16):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(300, 900)
            self.energy_sparks.append({
                'x': self._cx, 'y': self._cy,
                'vx': _cos(angle) * speed,
                'vy': _sin(angle) * speed,
                'size': random.uniform(2, 5),
                'life': random.uniform(0.15, 0.35),
                'color': random.choice([
                    (255, 220, 60), (255, 180, 30), (255, 255, 150),
                    (255, 140, 20), (255, 200, 100),
                ]),
            })

        # 포효 중 0.6초 이동 불가 + 포효 포즈
        self.roar_freeze_timer = self.ROAR_FREEZE_TIME
        self._freeze_applied = True
        caster_prefix = 'top_paddle' if self.caster_is_top else 'bottom_paddle'
        game_state[f'{caster_prefix}_stunned'] = True

        # 포효 포즈 플래그 (양팔 벌리고 무릎 굽힘)
        game_state['monkeyking_roar_pose'] = True

        self._load_sounds()
        if self._roar_sound:
            try:
                self._roar_sound.play()
            except Exception:
                pass

        # ── 즉시 반사: 발동 순간 바로 공 반사 (프레임 딜레이 없음) ──
        if ball:
            ball_cx = ball.x + getattr(ball, 'width', 10) / 2
            ball_cy = ball.y + getattr(ball, 'height', 10) / 2
            dx = ball_cx - self._cx
            dy = ball_cy - self._cy
            dist = math.sqrt(dx * dx + dy * dy)

            if dist < self.SHOCKWAVE_RADIUS and dist > 1:
                self.ball_reflected = True
                boost = self._actual_boost
                speed = math.sqrt(ball.vx ** 2 + ball.vy ** 2)
                # 법선벡터 기반 반사 + ±30도 랜덤
                nx = dx / dist
                ny = dy / dist
                dot = ball.vx * nx + ball.vy * ny
                rvx = ball.vx - 2 * dot * nx
                rvy = ball.vy - 2 * dot * ny
                r_len = math.sqrt(rvx ** 2 + rvy ** 2)
                if r_len > 0:
                    angle = math.atan2(rvy, rvx)
                    angle += random.uniform(-0.523, 0.523)
                    # 안전장치: 공이 시전자 쪽으로 향하면 방향 보정
                    if self.caster_is_top and _sin(angle) < 0:
                        angle = -angle
                    elif not self.caster_is_top and _sin(angle) > 0:
                        angle = -angle
                    ball.vx = _cos(angle) * speed * boost
                    ball.vy = _sin(angle) * speed * boost
                else:
                    ball.vy = -ball.vy * boost
                    ball.vx = ball.vx * boost
                # 최종 안전장치: 공이 시전자 골대로 향하면 vy 반전
                if self.caster_is_top and ball.vy < 0:
                    ball.vy = -ball.vy
                elif not self.caster_is_top and ball.vy > 0:
                    ball.vy = -ball.vy
                self._create_impact(ball_cx, ball_cy)
                if self._hit_sound:
                    try:
                        self._hit_sound.play()
                    except Exception:
                        pass

        game_state['screen_shake'] = 12 if not self.ball_reflected else 20
        game_state['shake_duration'] = 0.4 if not self.ball_reflected else 0.5
        return {'reflected': self.ball_reflected}

    # ------------------------------------------------------------------
    # 업데이트
    # ------------------------------------------------------------------
    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        self.shockwave_timer += dt

        # 플래시 페이드
        if hasattr(self, 'flash_alpha') and self.flash_alpha > 0:
            self.flash_alpha = max(0, self.flash_alpha - dt * 800)

        # 포효 이동 불가 타이머
        if self.roar_freeze_timer > 0:
            self.roar_freeze_timer -= dt
            if self.roar_freeze_timer <= 0:
                self.roar_freeze_timer = 0
                caster_prefix = 'top_paddle' if self.caster_is_top else 'bottom_paddle'
                game_state[f'{caster_prefix}_stunned'] = False
                self._freeze_applied = False
                # 포효 포즈 해제
                game_state['monkeyking_roar_pose'] = False

        # 충격파 중심 (패들 따라감)
        self._cx = caster_paddle.x + caster_paddle.width // 2
        if self.caster_is_top:
            self._cy = caster_paddle.y + caster_paddle.height
        else:
            self._cy = caster_paddle.y

        # 충격파 확장
        grow = min(1.0, self.shockwave_timer / self.SHOCKWAVE_GROW_TIME)
        self.shockwave_radius = self.SHOCKWAVE_RADIUS * grow

        # 링 이펙트 확장 + 빠른 페이드아웃 (충돌 없음 - 비주얼 전용)
        all_faded = True
        for ring in self.ring_effects:
            ring['timer'] += dt
            elapsed = ring['timer'] - ring['delay']
            if elapsed > 0:
                progress = min(1.0, elapsed / 0.2)
                ring['radius'] = ring['max_radius'] * progress
                if progress >= 1.0:
                    ring['reached_max'] = True
            # 최대 반경 도달 후 즉시 빠르게 페이드 (잔존 방지)
            if ring['reached_max']:
                ring['linger_timer'] += dt
                # 안쪽 링부터 빠르게 페이드 (0.08초 대기 후 0.15초 소멸)
                if ring['linger_timer'] > ring.get('linger_delay', 0.08):
                    ring['fade_alpha'] = max(0, ring['fade_alpha'] - dt / 0.15)
            if ring['fade_alpha'] > 0:
                all_faded = False

        # 에너지 스파크 업데이트
        if hasattr(self, 'energy_sparks'):
            for sp in self.energy_sparks[:]:
                sp['x'] += sp['vx'] * dt
                sp['y'] += sp['vy'] * dt
                sp['life'] -= dt
                if sp['life'] <= 0:
                    self.energy_sparks.remove(sp)

        # 임팩트 파티클 업데이트
        for p in self.impact_particles[:]:
            p['x'] += p['vx'] * dt
            p['y'] += p['vy'] * dt
            p['life'] -= dt
            if p['life'] <= 0:
                self.impact_particles.remove(p)

        # 스킬 종료: 모든 링 페이드 완료 + 파티클 없음
        if all_faded and not self.impact_particles:
            self.active_timer = 0

    def _create_impact(self, x: float, y: float):
        """반사 임팩트 파티클 (cleanse 스타일 강화)"""
        colors = [
            (255, 220, 60), (255, 180, 30), (255, 255, 120),
            (255, 130, 20), (255, 255, 200), (255, 240, 80),
        ]
        # 메인 폭발 파티클 (40개)
        for _ in range(40):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(300, 1000)
            self.impact_particles.append({
                'x': x, 'y': y,
                'vx': _cos(angle) * speed,
                'vy': _sin(angle) * speed,
                'size': random.uniform(3, 9),
                'color': random.choice(colors),
                'life': random.uniform(0.3, 0.8),
            })
        # 임팩트 플래시
        self.flash_alpha = 255

    # ------------------------------------------------------------------
    # 종료 / 리셋
    # ------------------------------------------------------------------
    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        self.ring_effects = []
        self.impact_particles = []
        self.energy_sparks = []
        self.flash_alpha = 0
        # 스턴 + 포즈 안전 해제
        if self._freeze_applied:
            caster_prefix = 'top_paddle' if self.caster_is_top else 'bottom_paddle'
            game_state[f'{caster_prefix}_stunned'] = False
            self._freeze_applied = False
        self.roar_freeze_timer = 0
        game_state['monkeyking_roar_pose'] = False
        # 화면 흔들림 안전 해제
        game_state['screen_shake'] = 0
        game_state['shake_duration'] = 0

    def reset_for_new_round(self, game_state: dict):
        super().reset_for_new_round(game_state)
        self.shockwave_timer = 0.0
        self.shockwave_radius = 0.0
        self.ball_reflected = False
        self._ball_in_range = False
        self.ring_effects = []
        self.impact_particles = []
        self.energy_sparks = []
        self.flash_alpha = 0
        if self._freeze_applied:
            game_state['top_paddle_stunned'] = False
            game_state['bottom_paddle_stunned'] = False
            self._freeze_applied = False
        self.roar_freeze_timer = 0
        self._trigger_distance = 0.0
        self._actual_boost = self.BALL_SPEED_BOOST
        game_state['monkeyking_roar_pose'] = False

    # ------------------------------------------------------------------
    # 렌더링
    # ------------------------------------------------------------------
    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        if not self.is_active:
            return

        cx, cy = int(self._cx), int(self._cy)

        # ── 발동 플래시 (화면 전체 번쩍) ──
        flash_a = int(getattr(self, 'flash_alpha', 0))
        if flash_a > 5:
            flash_surf = _psurf(screen.get_size(), pygame.SRCALPHA)
            flash_surf.fill((255, 240, 180, min(flash_a, 120)))
            screen.blit(flash_surf, (0, 0))

        # ── 충격파 영역 (반투명 금색 원 + 에너지 방사 라인) ──
        if self.shockwave_radius > 10 and not self.ball_reflected:
            # 가장 바깥 링의 fade_alpha를 사용
            outer_fade = 1.0
            if self.ring_effects:
                outer_fade = self.ring_effects[-1].get('fade_alpha', 1.0)
            if outer_fade > 0.01:
                r = int(self.shockwave_radius)
                zone_surf = _psurf((r * 2, r * 2), pygame.SRCALPHA)
                af = outer_fade
                for gi, ga in [(r, 25), (int(r * 0.7), 35), (int(r * 0.4), 45)]:
                    if gi > 0:
                        pygame.draw.circle(zone_surf, (255, 200, 50, int(ga * af)),
                                           (r, r), gi)
                for angle_deg in range(0, 360, 15):
                    rad = math.radians(angle_deg)
                    inner_r = int(r * 0.15)
                    outer_r = int(r * 0.95)
                    lx1 = r + int(_cos(rad) * inner_r)
                    ly1 = r + int(_sin(rad) * inner_r)
                    lx2 = r + int(_cos(rad) * outer_r)
                    ly2 = r + int(_sin(rad) * outer_r)
                    pygame.draw.line(zone_surf, (255, 220, 100, int(30 * af)),
                                     (lx1, ly1), (lx2, ly2), 2)
                screen.blit(zone_surf, (cx - r, cy - r))

        # ── 충격파 링 (개별 페이드아웃 적용) ──
        for ring in self.ring_effects:
            r = int(ring['radius'])
            if r < 5:
                continue
            rf = ring.get('fade_alpha', 1.0)
            if rf <= 0.01:
                continue
            alpha = int(ring['alpha'] * rf)
            if alpha <= 0:
                continue
            thickness = ring.get('thickness', 3)
            pad = thickness + 8
            ring_surf = _psurf((r * 2 + pad * 2, r * 2 + pad * 2), pygame.SRCALPHA)
            rc = r + pad
            # 외부 글로우 (넓은 반투명)
            if r > 8:
                pygame.draw.circle(ring_surf, (255, 200, 50, alpha // 4),
                                   (rc, rc), r + 3, thickness + 4)
            # 메인 링
            pygame.draw.circle(ring_surf, (255, 210, 60, alpha),
                               (rc, rc), r, thickness)
            # 내부 밝은 코어 라인
            pygame.draw.circle(ring_surf, (255, 250, 150, min(255, alpha + 40)),
                               (rc, rc), r, max(1, thickness - 2))
            screen.blit(ring_surf, (cx - rc, cy - rc))

        # ── 에너지 스파크 (확장 시 불꽃) ──
        if hasattr(self, 'energy_sparks'):
            for sp in self.energy_sparks:
                life_ratio = max(0, sp['life'] / 0.35)
                size = max(1, int(sp['size'] * life_ratio))
                alpha = int(255 * life_ratio)
                if size > 0 and alpha > 0:
                    ss = _psurf((size * 2 + 4, size * 2 + 4), pygame.SRCALPHA)
                    sc = size + 2
                    # 글로우
                    pygame.draw.circle(ss, (*sp['color'][:3], alpha // 3), (sc, sc), size + 2)
                    # 코어
                    pygame.draw.circle(ss, (*sp['color'][:3], alpha), (sc, sc), size)
                    screen.blit(ss, (int(sp['x']) - sc, int(sp['y']) - sc))

        # ── 반사 시 공 주변 글로우 (강화) ──
        if self.ball_reflected and ball and self.impact_particles:
            bx = int(ball.x + getattr(ball, 'width', 10) / 2)
            by = int(ball.y + getattr(ball, 'height', 10) / 2)
            glow_surf = _psurf((100, 100), pygame.SRCALPHA)
            glow_alpha = min(180, int(255 * len(self.impact_particles) / 40))
            # 다중 글로우 레이어
            pygame.draw.circle(glow_surf, (255, 200, 50, glow_alpha // 3), (50, 50), 45)
            pygame.draw.circle(glow_surf, (255, 220, 80, glow_alpha // 2), (50, 50), 30)
            pygame.draw.circle(glow_surf, (255, 240, 120, glow_alpha), (50, 50), 18)
            screen.blit(glow_surf, (bx - 50, by - 50))

        # ── 임팩트 파티클 (글로우 추가) ──
        for p in self.impact_particles:
            life_ratio = max(0, p['life'] / 0.8)
            size = max(1, int(p['size'] * life_ratio))
            alpha = int(255 * life_ratio)
            if size > 0 and alpha > 0:
                ps = _psurf((size * 2 + 4, size * 2 + 4), pygame.SRCALPHA)
                pc = size + 2
                # 글로우 후광
                pygame.draw.circle(ps, (*p['color'], alpha // 3), (pc, pc), size + 2)
                # 메인 파티클
                pygame.draw.circle(ps, (*p['color'], alpha), (pc, pc), size)
                screen.blit(ps, (int(p['x']) - pc, int(p['y']) - pc))


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
    "kurokage": [ShadowClone(), IllusionShuriken()],
    "banshee": [Charm(), GhostSummon()],
    "necro": [BoneBarrier(), SkeletonArcher()],
    "joker": [BalloonWall(), DeadPossession()],
    "mirage": [SandPrison(), SandVortex()],
    "android": [BombSurprise(), GatlingBurst()],
    "ra": [SolarBolt(), ThunderOrb()],  # 천둥 낙뢰 + 천둥 뇌구
    "monkeyking": [BananaSlice(), WildRoar()],  # 원숭이왕: 바나나 슬라이스 + 야생의 포효
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
    "banshee": [Charm, GhostSummon],
    "necro": [BoneBarrier, SkeletonArcher],
    "joker": [BalloonWall, DeadPossession],
    "mirage": [SandPrison, SandVortex],
    "android": [BombSurprise, GatlingBurst],
    "ra": [SolarBolt, ThunderOrb],  # 천둥 낙뢰 + 천둥 뇌구
    "monkeyking": [BananaSlice, WildRoar],  # 원숭이왕: 바나나 슬라이스 + 야생의 포효
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

    def init_hero_skills(self, hero_id: str, is_top: bool = True, selected_skill_index: int = -1):
        """영웅 스킬 초기화

        Args:
            hero_id: 영웅 ID
            is_top: 상단 영웅 여부 (기본값 True)
            selected_skill_index: 스킬 랜덤 선택 인덱스 (0 또는 1이면 해당 스킬만 활성화, -1이면 모든 스킬)
        """
        if hero_id not in self.active_skills:
            # 새 인스턴스 생성 (상태 독립)
            skills = []
            base_skills = HERO_SKILLS.get(hero_id, [])
            for i, base_skill in enumerate(base_skills):
                # selected_skill_index가 지정되면 해당 스킬만 활성화
                if selected_skill_index >= 0 and i != selected_skill_index:
                    continue
                skill_class = type(base_skill)
                new_skill = skill_class()
                # 스킬 인스턴스에 직접 caster_is_top 저장 (화염지대 위치 계산용)
                new_skill.caster_is_top = is_top
                # 초기 쿨타임 부여 (3~8초) - 게임 시작 시 동시 스킬 사용 방지
                new_skill.current_cooldown = random.uniform(3.0, 8.0)
                skills.append(new_skill)
            self.active_skills[hero_id] = skills
            # 듀얼 스킬 페널티: 2개 이상 보유 시 모든 스킬 쿨타임 30% 증가
            if len(skills) > 1:
                for sk in skills:
                    sk.cooldown *= 1.3
                print(f"[Skill] {hero_id} 듀얼 스킬 페널티 적용: 모든 스킬 쿨타임 30% 증가")
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
            # 세트 관련
            'has_sand_vortex': False,
            'top_paddle_sand_prison': False,
            'bottom_paddle_sand_prison': False,
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
                # 모래회오리: is_active=False여도 소용돌이가 남아있는 경우 포함
                has_vortexes = hasattr(skill, 'vortexes') and skill.vortexes
                # 유령소환: 공을 먹고 있는 중이면 라운드 리셋 시 공 복원 필요
                has_ghost_eating = hasattr(skill, '_eating_ball') and skill._eating_ball
                # 천둥 뇌구: is_active=False여도 감전 사운드 채널이 남아있는 경우 포함
                has_electric_shock = hasattr(skill, '_electric_shock_channel') and skill._electric_shock_channel
                # 개틀링 버스트: is_active=False여도 루프 사운드가 남아있는 경우 포함
                has_gatling_loop = hasattr(skill, '_gatling_loop_sound') and skill._gatling_loop_sound
                if skill.is_active or has_oil_effects or has_dwarf_magic_effects or has_shadow_clones or has_shurikens or has_vortexes or has_ghost_eating or has_electric_shock or has_gatling_loop:
                    skill.reset_for_new_round(self.game_state)

        # 🔥 기사회생 퍽: perk_skill_cd_mult 값 보존 (라운드 전환 시 유실 방지)
        _preserved_perk_cd_top = self.game_state.get('perk_skill_cd_mult_top', 1.0)
        _preserved_perk_cd_bottom = self.game_state.get('perk_skill_cd_mult_bottom', 1.0)
        _preserved_instant_cd_top = self.game_state.get('instant_cooldown_chance_top', 0.0)
        _preserved_instant_cd_bottom = self.game_state.get('instant_cooldown_chance_bottom', 0.0)
        _preserved_magic_imm_chance_top = self.game_state.get('magic_immunity_chance_top', 0.0)
        _preserved_magic_imm_chance_bottom = self.game_state.get('magic_immunity_chance_bottom', 0.0)

        # 추가로 game_state의 모든 효과 상태 초기화
        self.game_state['top_paddle_stunned'] = False
        self.game_state['top_paddle_slowed'] = False
        self.game_state['top_paddle_slow_amount'] = 1.0
        self.game_state['top_paddle_confused'] = False
        self.game_state['top_paddle_locked'] = False
        self.game_state['top_paddle_gravity_drift'] = 0
        self.game_state['top_paddle_electric_stun'] = False
        self.game_state['bottom_paddle_stunned'] = False
        self.game_state['bottom_paddle_slowed'] = False
        self.game_state['bottom_paddle_slow_amount'] = 1.0
        self.game_state['bottom_paddle_confused'] = False
        self.game_state['bottom_paddle_locked'] = False
        self.game_state['bottom_paddle_gravity_drift'] = 0
        self.game_state['bottom_paddle_electric_stun'] = False
        self.game_state['top_paddle_sand_prison'] = False
        self.game_state['bottom_paddle_sand_prison'] = False
        self.game_state['has_sand_vortex'] = False
        self.game_state.pop('sand_prison_center_x', None)
        self.game_state.pop('sand_prison_range', None)
        self.game_state.pop('sand_prison_target_is_top', None)
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

        # 오니마루 뿔 박치기 착지 충격파/폭발 이펙트 초기화
        self.game_state['horn_charge_impact_shockwave'] = None
        self.game_state['horn_charge_explosion'] = None

        # 🔥 기사회생 퍽: 보존된 perk 값 복원 (라운드 전환으로 인한 유실 방지)
        self.game_state['perk_skill_cd_mult_top'] = _preserved_perk_cd_top
        self.game_state['perk_skill_cd_mult_bottom'] = _preserved_perk_cd_bottom
        self.game_state['instant_cooldown_chance_top'] = _preserved_instant_cd_top
        self.game_state['instant_cooldown_chance_bottom'] = _preserved_instant_cd_bottom
        self.game_state['magic_immunity_chance_top'] = _preserved_magic_imm_chance_top
        self.game_state['magic_immunity_chance_bottom'] = _preserved_magic_imm_chance_bottom

    def update(self, dt: float, top_paddle, bottom_paddle, ball):
        """스킬 업데이트"""
        # 영웅 패들 위치 저장 (해골궁수 등에서 호위무사 대신 영웅만 타겟하기 위해 사용)
        self.game_state['hero_paddle_top'] = {
            'x': top_paddle.x, 'y': top_paddle.y,
            'width': top_paddle.width, 'height': top_paddle.height,
        }
        self.game_state['hero_paddle_bottom'] = {
            'x': bottom_paddle.x, 'y': bottom_paddle.y,
            'width': bottom_paddle.width, 'height': bottom_paddle.height,
        }

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
        self.screen_effects[:] = [e for e in self.screen_effects if e.get('duration', 0) > 0]
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
                # 마법결계: 타겟에 마법 면역이 활성 상태면 스킬 차단
                _target_side = 'top' if target_paddle.is_top else 'bottom'
                if self.game_state.get(f'magic_immunity_{_target_side}', False):
                    # 스킬 쿨다운 소모 (헛발)
                    self.hero_global_cooldowns[hero_id] = self.HERO_SKILL_INTERVAL
                    skill.current_cooldown = skill.cooldown
                    return {
                        'blocked_by_immunity': True,
                        'skill_korean_name': skill.korean_name,
                        'caster_is_top': caster_paddle.is_top
                    }

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
                    # 망자빙의 등 빙의 스킬은 발동된 스킬 이름을 표시
                    if 'possession_skill_name' in result:
                        result['skill_korean_name'] = result['possession_skill_name']
                    else:
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

    def draw_skills_overlay(self, screen: pygame.Surface, top_paddle, bottom_paddle, ball):
        """영웅 패들 위에 그려야 하는 스킬 오버레이 이펙트 (패들 부착 폭탄 등)"""
        for hero_id, skills in self.active_skills.items():
            is_top = self.game_state.get('hero_positions', {}).get(hero_id, True)
            caster_paddle = top_paddle if is_top else bottom_paddle
            target_paddle = bottom_paddle if is_top else top_paddle
            for skill in skills:
                if hasattr(skill, 'draw_overlay'):
                    skill.draw_overlay(screen, caster_paddle, target_paddle, ball, self.game_state)

    def draw_screen_effects(self, screen: pygame.Surface):
        """화면 효과 그리기"""
        for effect in self.screen_effects:
            if effect['type'] == ScreenEffect.FLASH:
                alpha = int(150 * (effect['duration'] / 0.3))
                alpha = max(0, min(255, alpha))  # 유효 범위로 제한
                if alpha <= 0:
                    continue
                flash_surf = _get_fullscreen_surface()
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
    BOTTOM_HEROES = [{"id": "maria"}, {"id": "ignis"}, {"id": "gear"}, {"id": "kurokage"}, {"id": "banshee"}, {"id": "android"}]
