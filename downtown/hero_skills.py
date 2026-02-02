# downtown/hero_skills.py
# 투기장 영웅 스킬 시스템

import pygame
import math
import random
from enum import Enum
from typing import Dict, List, Optional, Tuple, Callable

# 날씨 강풍 이벤트 임포트
try:
    from events.weather_event import force_start_gust_event, play_weather_sound, stop_weather_sound
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


# ============================================================================
# 무겐 스킬 - 귀검사 (공격적)
# ============================================================================
class DarkSlash(HeroSkill):
    """암흑 베기 - 공을 칠 때 검기 이펙트 + 공 가속"""
    def __init__(self):
        super().__init__(
            skill_id="dark_slash",
            name="Dark Slash",
            korean_name="암흑 베기",
            description="검은 검기로 공을 강타하여 속도를 크게 증가시킨다",
            trigger=SkillTrigger.ON_BALL_HIT,
            cooldown=8.0,
            duration=0.5,
            hero_id="mugen"
        )
        self.slash_particles = []

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        # 공 가속
        speed_boost = 1.4
        ball.vx *= speed_boost
        ball.vy *= speed_boost

        # 검기 파티클 생성
        self.slash_particles = []
        paddle_center_x = caster_paddle.x + 40
        paddle_y = caster_paddle.y

        for i in range(15):
            angle = math.radians(random.uniform(-30, 30))
            speed = random.uniform(200, 400)
            self.slash_particles.append({
                'x': paddle_center_x + random.uniform(-30, 30),
                'y': paddle_y,
                'vx': math.sin(angle) * speed,
                'vy': -speed if caster_paddle.is_top else speed,
                'life': 0.5,
                'size': random.uniform(3, 8),
                'color': (120 + random.randint(0, 60), 30, 180 + random.randint(0, 75))
            })

        return {
            'screen_effect': ScreenEffect.FLASH,
            'flash_color': (150, 50, 200),
            'flash_duration': 0.1,
            'sound': 'slash'
        }

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        # 파티클 업데이트
        for p in self.slash_particles:
            p['x'] += p['vx'] * dt
            p['y'] += p['vy'] * dt
            p['life'] -= dt
            p['size'] *= 0.95
        self.slash_particles = [p for p in self.slash_particles if p['life'] > 0]

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        for p in self.slash_particles:
            if p['size'] > 1:
                alpha = int(255 * (p['life'] / 0.5))
                surf = pygame.Surface((int(p['size'] * 2), int(p['size'] * 4)), pygame.SRCALPHA)
                color = (*p['color'], alpha)
                pygame.draw.ellipse(surf, color, surf.get_rect())
                screen.blit(surf, (int(p['x'] - p['size']), int(p['y'] - p['size'] * 2)))


class DemonEye(HeroSkill):
    """귀신의 눈 - 상대방 시야를 제한하는 어둠 효과"""
    def __init__(self):
        super().__init__(
            skill_id="demon_eye",
            name="Demon Eye",
            korean_name="귀신의 눈",
            description="어둠의 기운으로 상대의 시야를 가린다",
            trigger=SkillTrigger.ON_COOLDOWN,
            cooldown=25.0,
            duration=4.0,
            hero_id="mugen"
        )
        self.eye_animation_timer = 0
        self.target_is_top = False

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        self.target_is_top = target_paddle.is_top
        self.eye_animation_timer = 0
        game_state['target_blind'] = True
        game_state['blind_intensity'] = 0.8
        game_state['blind_target_is_top'] = target_paddle.is_top

        return {
            'screen_effect': ScreenEffect.DARKNESS,
            'target_status': StatusEffect.BLIND,
            'status_duration': self.duration,
            'sound': 'dark_magic'
        }

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        self.eye_animation_timer += dt
        # 맥동 효과
        game_state['blind_intensity'] = 0.6 + 0.2 * math.sin(self.eye_animation_timer * 5)

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        game_state['target_blind'] = False
        game_state['blind_intensity'] = 0

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        if self.is_active:
            # 상대 진영에 어둠 효과
            darkness_surf = pygame.Surface((600, 375), pygame.SRCALPHA)
            intensity = int(200 * game_state.get('blind_intensity', 0.8))

            # 그라데이션 어둠
            if caster_paddle.is_top:
                # 하단에 어둠 적용
                for y in range(375):
                    alpha = int(intensity * (y / 375))
                    pygame.draw.line(darkness_surf, (20, 0, 40, alpha), (0, y), (600, y))
                screen.blit(darkness_surf, (80, 375))
            else:
                # 상단에 어둠 적용
                for y in range(375):
                    alpha = int(intensity * (1 - y / 375))
                    pygame.draw.line(darkness_surf, (20, 0, 40, alpha), (0, y), (600, y))
                screen.blit(darkness_surf, (80, 0))

            # 귀신 눈 이펙트
            eye_x = caster_paddle.x + 40
            eye_y = caster_paddle.y + (30 if caster_paddle.is_top else -30)
            pulse = 1 + 0.2 * math.sin(self.eye_animation_timer * 8)

            # 눈 글로우
            glow_size = int(25 * pulse)
            glow_surf = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (180, 50, 255, 100), (glow_size, glow_size), glow_size)
            screen.blit(glow_surf, (int(eye_x - glow_size), int(eye_y - glow_size)), special_flags=pygame.BLEND_ADD)

            # 눈동자
            pygame.draw.circle(screen, (200, 50, 255), (int(eye_x), int(eye_y)), int(12 * pulse))
            pygame.draw.circle(screen, (255, 100, 100), (int(eye_x), int(eye_y)), int(5 * pulse))


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
                    print(f"[AbyssInk] 혼란 적용! target={target_prefix}, ellipse_dist={ellipse_dist:.2f}")

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
    """뿔 박치기 - 충격파로 상대 넉백 + 화면 흔들림"""
    def __init__(self):
        super().__init__(
            skill_id="horn_charge",
            name="Horn Charge",
            korean_name="뿔 박치기",
            description="강력한 충격파로 상대를 밀어내고 화면을 흔든다",
            trigger=SkillTrigger.ON_COOLDOWN,
            cooldown=25.0,
            duration=0.5,
            hero_id="onimaru"
        )
        self.shockwave_radius = 0
        self.knockback_applied = False

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        self.shockwave_radius = 0
        self.knockback_applied = False

        # 넉백 방향 설정
        knockback_dir = 1 if random.random() > 0.5 else -1
        game_state['target_knockback'] = knockback_dir * 150  # 150픽셀 넉백
        game_state['screen_shake'] = 20  # 화면 흔들림 강도
        game_state['shake_duration'] = 0.5

        return {
            'screen_effect': ScreenEffect.SHAKE,
            'shake_intensity': 20,
            'shake_duration': 0.5,
            'target_status': StatusEffect.KNOCKBACK,
            'knockback_force': knockback_dir * 150,
            'sound': 'impact'
        }

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        self.shockwave_radius += dt * 800

        # 넉백 적용
        if not self.knockback_applied and game_state.get('target_knockback'):
            target_paddle.x += game_state['target_knockback'] * dt * 5
            # 경계 체크
            target_paddle.x = max(80, min(target_paddle.x, 600))
            if self.shockwave_radius > 200:
                self.knockback_applied = True
                game_state['target_knockback'] = 0

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        game_state['screen_shake'] = 0
        game_state['target_knockback'] = 0

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        if self.is_active and self.shockwave_radius < 400:
            # 충격파 원
            center_x = caster_paddle.x + 40
            center_y = caster_paddle.y

            alpha = int(200 * (1 - self.shockwave_radius / 400))
            if alpha > 10:
                # 충격파 링
                for r_offset in [0, 20, 40]:
                    radius = int(self.shockwave_radius - r_offset)
                    if radius > 0:
                        ring_alpha = int(alpha * (1 - r_offset / 60))
                        pygame.draw.circle(screen, (255, 100, 50, ring_alpha),
                                         (int(center_x), int(center_y)), radius, 4)


# ============================================================================
# 마리아 스킬 - 인형사 (트릭형)
# ============================================================================
class PuppetControl(HeroSkill):
    """꼭두각시 조종 - 상대 패들을 잠시 조종"""
    def __init__(self):
        super().__init__(
            skill_id="puppet_control",
            name="Puppet Control",
            korean_name="꼭두각시 조종",
            description="실로 상대를 조종하여 원하는 대로 움직이게 한다",
            trigger=SkillTrigger.ON_COOLDOWN,
            cooldown=35.0,
            duration=2.0,
            hero_id="maria"
        )
        self.strings = []
        self.puppet_target_x = 0
        self.target_is_top = False

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        self.target_is_top = target_paddle.is_top
        game_state['target_puppeted'] = True
        # 패들을 가장자리로 조종 (실점 유도)
        ball_going_left = ball.vx < 0
        self.puppet_target_x = 600 if ball_going_left else 100

        # 실 생성
        self.strings = []
        for i in range(5):
            self.strings.append({
                'attach_x': target_paddle.x + 10 + i * 15,
                'wave': random.uniform(0, math.pi * 2)
            })

        return {
            'target_status': StatusEffect.PUPPET,
            'puppet_target': self.puppet_target_x,
            'status_duration': self.duration,
            'sound': 'strings'
        }

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        # 패들 강제 이동
        diff = self.puppet_target_x - target_paddle.x
        target_paddle.x += diff * dt * 3

        # 실 업데이트
        for s in self.strings:
            s['attach_x'] = target_paddle.x + 10 + self.strings.index(s) * 15
            s['wave'] += dt * 5

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        game_state['target_puppeted'] = False
        self.strings = []

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        if self.is_active:
            # 조종 실 그리기
            hand_x = caster_paddle.x + 40
            hand_y = caster_paddle.y + (40 if caster_paddle.is_top else -40)

            for s in self.strings:
                # 물결치는 실
                points = []
                segments = 15
                for i in range(segments + 1):
                    prog = i / segments
                    wave = math.sin(prog * math.pi * 2 + s['wave']) * 15 * (1 - prog)

                    x = hand_x + (s['attach_x'] - hand_x) * prog + wave
                    y = hand_y + (target_paddle.y - hand_y) * prog
                    points.append((int(x), int(y)))

                if len(points) > 1:
                    pygame.draw.lines(screen, (180, 100, 150), False, points, 2)

            # 십자가 컨트롤러
            pygame.draw.line(screen, (120, 60, 90), (hand_x - 30, hand_y), (hand_x + 30, hand_y), 4)
            pygame.draw.line(screen, (120, 60, 90), (hand_x, hand_y - 20), (hand_x, hand_y + 10), 4)


class DollCurse(HeroSkill):
    """인형의 저주 - 상대 조작 반전"""
    def __init__(self):
        super().__init__(
            skill_id="doll_curse",
            name="Doll Curse",
            korean_name="인형의 저주",
            description="저주받은 인형으로 상대의 조작을 반전시킨다",
            trigger=SkillTrigger.ON_BALL_HIT,
            cooldown=18.0,
            duration=4.0,
            hero_id="maria"
        )
        self.curse_dolls = []
        self.target_is_top = False

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        self.target_is_top = target_paddle.is_top
        game_state['target_confused'] = True
        game_state['confusion_type'] = 'reverse'  # 조작 반전

        # 저주 인형 이펙트
        self.curse_dolls = []
        for i in range(3):
            self.curse_dolls.append({
                'x': target_paddle.x + random.uniform(-50, 130),
                'y': target_paddle.y + random.uniform(-80, 80),
                'rotation': random.uniform(0, 360),
                'scale': random.uniform(0.5, 1.0),
                'wobble': random.uniform(0, math.pi * 2)
            })

        return {
            'target_status': StatusEffect.CONFUSION,
            'confusion_type': 'reverse',
            'status_duration': self.duration,
            'screen_effect': ScreenEffect.FLASH,
            'flash_color': (180, 50, 100),
            'sound': 'curse'
        }

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        for doll in self.curse_dolls:
            doll['wobble'] += dt * 3
            doll['rotation'] += math.sin(doll['wobble']) * 2

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        game_state['target_confused'] = False
        # 패들별 상태 클리어
        target_prefix = 'top_paddle' if self.target_is_top else 'bottom_paddle'
        game_state[f'{target_prefix}_confused'] = False
        self.curse_dolls = []

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        if self.is_active:
            # 저주 오버레이
            overlay = pygame.Surface((760, 750), pygame.SRCALPHA)
            overlay.fill((100, 30, 60, 30))
            screen.blit(overlay, (0, 0))

            # 저주 인형들
            for doll in self.curse_dolls:
                # 간단한 인형 형태
                dx, dy = int(doll['x']), int(doll['y'])
                s = doll['scale']

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
        for p in self.breath_particles:
            p['x'] += p['vx'] * dt
            p['y'] += p['vy'] * dt
            p['life'] -= dt
            p['size'] *= 0.98
            p['color_phase'] += dt

            # 공과 충돌 체크
            if not self.breath_hit_ball:
                dist = math.hypot(p['x'] - ball.x, p['y'] - ball.y)
                if dist < 30:
                    # 공 가속
                    ball.vx *= 1.4
                    ball.vy *= 1.4
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
                'duration': 180,  # 3초 (60fps * 3)
                'source': 'dragon_breath'
            }

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        self.breath_particles = []
        self.breath_active = False
        # 화염 지대는 _update_active_effect에서 종료 0.5초 전에 생성됨

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        for p in self.breath_particles:
            if p['size'] > 2:
                # 화염 색상 변화
                phase = p['color_phase'] % 1.0
                if phase < 0.33:
                    color = (255, 255, int(200 * (1 - phase * 3)))
                elif phase < 0.66:
                    color = (255, int(255 - 155 * (phase - 0.33) * 3), 0)
                else:
                    color = (int(255 - 55 * (phase - 0.66) * 3), int(100 - 100 * (phase - 0.66) * 3), 0)

                alpha = int(200 * (p['life'] / 1.5))
                surf = pygame.Surface((int(p['size'] * 2), int(p['size'] * 2)), pygame.SRCALPHA)
                pygame.draw.circle(surf, (*color, alpha), (int(p['size']), int(p['size'])), int(p['size']))
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

        # 날씨 강풍 이벤트 시작 및 바람 사운드 재생
        if WEATHER_EVENT_AVAILABLE:
            force_start_gust_event(direction=self.wind_direction, duration=3)  # 3라운드 지속
            play_weather_sound("gust")

        return {
            'screen_effect': ScreenEffect.WIND,
            'wind_direction': self.wind_direction,
            'sound': None  # 날씨 시스템에서 사운드 재생
        }

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        # 공에 바람 효과 적용
        ball.vx += game_state.get('wind_force', 0) * dt * 60

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

        # 바람 사운드 정지
        if WEATHER_EVENT_AVAILABLE:
            stop_weather_sound()

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
        # 배리어 위치 (패들 앞쪽)
        self.barrier_y = caster_paddle.y + (60 if caster_paddle.is_top else -60)
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
                if ball.vy < 0 and abs(ball.y - self.barrier_y) < 20 and ball.y < self.barrier_y:
                    ball.vy = abs(ball.vy) * 1.1
                    self.barrier_hit = True
                    game_state['screen_shake'] = 10
            else:
                if ball.vy > 0 and abs(ball.y - self.barrier_y) < 20 and ball.y > self.barrier_y:
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
    """기름 투척 - 상대 진영에 기름으로 둔화"""
    def __init__(self):
        super().__init__(
            skill_id="oil_spill",
            name="Oil Spill",
            korean_name="기름 투척",
            description="기름을 뿌려 상대의 움직임을 둔화시킨다",
            trigger=SkillTrigger.ON_BALL_HIT,
            cooldown=15.0,
            duration=5.0,
            hero_id="gear"
        )
        self.oil_puddles = []
        self.target_is_top = False

    def _apply_effect(self, caster_paddle, target_paddle, ball, game_state: dict) -> dict:
        self.target_is_top = target_paddle.is_top
        game_state['target_slowed'] = True
        game_state['slow_amount'] = 0.5  # 50% 둔화

        # 기름 웅덩이 생성
        target_area_y = target_paddle.y
        self.oil_puddles = []
        for i in range(5):
            self.oil_puddles.append({
                'x': target_paddle.x + random.uniform(-80, 160),
                'y': target_area_y + random.uniform(-30, 30),
                'width': random.uniform(40, 80),
                'height': random.uniform(15, 25),
                'wobble': random.uniform(0, math.pi * 2)
            })

        return {
            'target_status': StatusEffect.SLOW,
            'slow_amount': 0.5,
            'status_duration': self.duration,
            'sound': 'splash'
        }

    def _update_active_effect(self, dt: float, caster_paddle, target_paddle, ball, game_state: dict):
        for puddle in self.oil_puddles:
            puddle['wobble'] += dt * 2

    def _end_effect(self, caster_paddle, target_paddle, ball, game_state: dict):
        game_state['target_slowed'] = False
        game_state['slow_amount'] = 1.0
        # 패들별 상태 클리어
        target_prefix = 'top_paddle' if self.target_is_top else 'bottom_paddle'
        game_state[f'{target_prefix}_slowed'] = False
        game_state[f'{target_prefix}_slow_amount'] = 1.0
        self.oil_puddles = []

    def draw(self, screen: pygame.Surface, caster_paddle, target_paddle, ball, game_state: dict):
        for puddle in self.oil_puddles:
            # 기름 웅덩이 (타원 + 반사광)
            w = int(puddle['width'] + math.sin(puddle['wobble']) * 5)
            h = int(puddle['height'])
            x = int(puddle['x'] - w / 2)
            y = int(puddle['y'] - h / 2)

            surf = pygame.Surface((w, h), pygame.SRCALPHA)
            pygame.draw.ellipse(surf, (30, 25, 20, 180), (0, 0, w, h))
            # 반사광
            pygame.draw.ellipse(surf, (60, 50, 40, 100), (w // 4, h // 4, w // 3, h // 3))
            screen.blit(surf, (x, y))


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
            'top_paddle_confused': False,
            'top_paddle_shrink': False,
            'top_paddle_shrink_scale': 1.0,
            'bottom_paddle_stunned': False,
            'bottom_paddle_slowed': False,
            'bottom_paddle_slow_amount': 1.0,
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
            'has_clones': False
        }
        self.screen_effects = []
        # 영웅별 글로벌 쿨다운 초기화
        self.hero_global_cooldowns = {}

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
