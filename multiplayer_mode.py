# -*- coding: utf-8 -*-
"""
로컬 멀티플레이어 모드 - pingfighter.py 핵심 함수 직접 사용
기존 게임 시스템을 그대로 재사용하여 100% 동일한 품질 보장
"""

import pygame
import random
import math
import time
from typing import Dict, List, Tuple, Optional, Callable, Any

# ============================================================================
# pingfighter.py에서 핵심 함수들을 직접 가져옴
# ============================================================================
# 이 함수들은 run_multiplayer_game()에서 외부 주입받음
_draw_energy_ball = None
_create_smasher_paddle_surface = None
_get_font = None
_play_paddle_sound = None
_play_wall_sound = None
_play_dash_sound = None
_play_notification_sound = None
_bgm_manager = None

# 전역 게임 함수 참조
_pingfighter_funcs = {}

# ============================================================================
# 상수 정의 (pingfighter.py 기준 완전 동일)
# ============================================================================

# 게이지 시스템
GAUGE_MAX = 500
GAUGE_HIT_CHARGE = 60

# 콤보 보너스
COMBO_GAUGE_BONUS = {2: 5, 3: 10, 4: 15, 5: 20, 6: 25}
COMBO_MAX_BONUS = 25

# 쇼트 (Short Shot)
SHORT_SHOT_GAUGE_COST = 100
SHORT_SHOT_SPEED_MULTIPLIER = 1.3
SHORT_SHOT_KNOCKBACK_FRAMES = 24

# 드라이브 (Drive)
DRIVE_GAUGE_COST = 150
DRIVE_BASE_SPIN = 0.25
DRIVE_SPIN_CAP = 0.6
DRIVE_SPEED_BOOST = 1.015

# 파워스매싱 (Power Smashing)
POWER_SMASH_GAUGE_COST = 350
POWER_SMASH_GRAVITY = 0.035
POWER_SMASH_ARC_STRENGTH = 0.8

# 물리
BALL_BASE_SPEED = 6.0
BALL_RADIUS = 16
PADDLE_SPEED = 8
DASH_SPEED_BOOST = 32
DASH_DURATION = 8
DASH_COOLDOWN = 20

# 공 생성 애니메이션 (3초로 단축)
SPAWN_PHASE1_DURATION = 0.8  # 에너지 수집
SPAWN_PHASE2_DURATION = 1.0  # 형태 형성
SPAWN_PHASE3_DURATION = 1.2  # 완성 및 발사 대기
SPAWN_TOTAL_DURATION = SPAWN_PHASE1_DURATION + SPAWN_PHASE2_DURATION + SPAWN_PHASE3_DURATION

# 인텐시티 (공 속도에 따른 색상)
INTENSITY_COLORS = {
    0: (100, 180, 255),   # 파란색 (느림)
    1: (180, 220, 100),   # 연두색
    2: (255, 220, 100),   # 노란색
    3: (255, 160, 80),    # 주황색
    4: (255, 100, 80),    # 빨간색
    5: (255, 80, 150),    # 핑크 (매우 빠름)
}
INTENSITY_SPEED_THRESHOLDS = [8, 12, 16, 22, 28, 35]

# P1/P2 색상
P1_COLOR = (0, 150, 255)    # 파란색
P2_COLOR = (255, 100, 100)  # 빨간색

# 키 바인딩
P1_KEYS = {
    'left': pygame.K_LEFT,
    'right': pygame.K_RIGHT,
    'up': pygame.K_UP,
    'down': pygame.K_DOWN,
    'dash': pygame.K_RSHIFT,
    'skill': pygame.K_RCTRL,
}
P2_KEYS = {
    'left': pygame.K_a,
    'right': pygame.K_d,
    'up': pygame.K_w,
    'down': pygame.K_s,
    'dash': pygame.K_SPACE,
    'skill': pygame.K_LSHIFT,
}


# ============================================================================
# 에너지볼 렌더러 (pingfighter.py draw_energy_ball 기반)
# ============================================================================
class EnergyBallRenderer:
    """pingfighter.py의 draw_energy_ball과 동일한 8레이어 에너지볼"""

    def __init__(self):
        self.rotation_angle = 0
        self.pulse_phase = 0
        self.particles = []
        self.ring_particles = []
        self.max_particles = 30

    def get_intensity_level(self, speed: float) -> int:
        """속도에 따른 인텐시티 레벨 (0-5)"""
        for i, threshold in enumerate(INTENSITY_SPEED_THRESHOLDS):
            if speed < threshold:
                return i
        return 5

    def draw(self, surface: pygame.Surface, cx: int, cy: int, radius: int, speed: float = 10):
        """8레이어 에너지볼 렌더링"""
        current_time = pygame.time.get_ticks()
        self.rotation_angle = (current_time * 0.15) % 360
        self.pulse_phase = current_time * 0.005

        intensity = self.get_intensity_level(speed)
        base_color = INTENSITY_COLORS.get(intensity, (100, 180, 255))

        # 각 고리별 독립 회전
        ring1_angle = (current_time * 0.18) % 360
        ring2_angle = (360 - (current_time * 0.12) % 360)
        ring3_angle = (current_time * 0.15) % 360
        ring_angles = [ring1_angle, ring2_angle, ring3_angle]

        # 기울기 동적 변화
        ring1_tilt = 20 + math.sin(current_time * 0.002) * 10
        ring2_tilt = 45 + math.sin(current_time * 0.0015 + 1) * 12
        ring3_tilt = 70 + math.sin(current_time * 0.001 + 2) * 8
        ring_tilts = [ring1_tilt, ring2_tilt, ring3_tilt]

        # 서피스 생성
        surf_size = radius * 6 + 20
        ball_surf = pygame.Surface((surf_size, surf_size), pygame.SRCALPHA)
        center = surf_size // 2

        # 펄스 효과
        pulse = math.sin(self.pulse_phase) * 0.12 + 1.0
        pulse2 = math.sin(self.pulse_phase * 1.5) * 0.08 + 1.0

        # === Layer 1: 외부 글로우 ===
        for i in range(3):
            glow_radius = int(radius * (0.795 - i * 0.11) * pulse)
            glow_alpha = int(8 - i * 2)
            if glow_alpha > 0 and glow_radius > 0:
                pygame.draw.circle(ball_surf, (*base_color, glow_alpha),
                                 (center, center), glow_radius)

        # === Layer 2: 회전하는 외부 고리 (3개) ===
        for ring_idx in range(3):
            ring_rotation = ring_angles[ring_idx]
            ring_tilt = ring_tilts[ring_idx]
            ring_radius = radius * (1.156 + ring_idx * 0.108)

            num_points = 24
            for i in range(num_points):
                angle = math.radians(ring_rotation + i * (360 / num_points))
                tilt_rad = math.radians(ring_tilt)
                x_offset = math.cos(angle) * ring_radius
                y_offset = math.sin(angle) * ring_radius * math.cos(tilt_rad)
                z_depth = math.sin(angle) * math.sin(tilt_rad)

                depth_factor = (z_depth + 1) / 2
                px = center + x_offset
                py = center + y_offset

                point_size = max(1, int(1.7 + depth_factor * 1.3))
                point_alpha = int(15 + depth_factor * 35)

                r = int(min(255, base_color[0] * 0.3 + depth_factor * base_color[0] * 0.7 + ring_idx * 5))
                g = int(min(255, base_color[1] * 0.3 + depth_factor * base_color[1] * 0.7 + ring_idx * 10))
                b = int(min(255, base_color[2] * 0.3 + depth_factor * base_color[2] * 0.7))

                pygame.draw.circle(ball_surf, (r, g, b, point_alpha),
                                 (int(px), int(py)), point_size)

        # === Layer 3: 고리 연결선 ===
        for ring_idx in range(3):
            ring_rotation = ring_angles[ring_idx]
            ring_tilt = ring_tilts[ring_idx]
            ring_radius = radius * (1.156 + ring_idx * 0.108)

            points = []
            for i in range(36):
                angle = math.radians(ring_rotation + i * 10)
                tilt_rad = math.radians(ring_tilt)
                x_offset = math.cos(angle) * ring_radius
                y_offset = math.sin(angle) * ring_radius * math.cos(tilt_rad)
                points.append((int(center + x_offset), int(center + y_offset)))

            if len(points) > 2:
                for i in range(len(points)):
                    start = points[i]
                    end = points[(i + 1) % len(points)]
                    pygame.draw.line(ball_surf, (*base_color, 10), start, end, 1)

        # === Layer 4: 내부 에너지 구체 ===
        outer_glow = int(radius * 0.361 * pulse2)
        pygame.draw.circle(ball_surf, (*base_color, 25), (center, center), outer_glow)

        mid_glow = int(radius * 0.289 * pulse)
        mid_color = tuple(int(c * 0.8 + 50) for c in base_color)
        pygame.draw.circle(ball_surf, (*mid_color, 40), (center, center), mid_glow)

        inner_sphere = int(radius * 0.255)
        inner_color = tuple(int(min(255, c * 0.7 + 80)) for c in base_color)
        pygame.draw.circle(ball_surf, (*inner_color, 60), (center, center), inner_sphere)

        # === Layer 5: 밝은 코어 ===
        core_size = int(radius * 0.178)
        core_glow = tuple(int(min(255, c * 0.5 + 128)) for c in base_color)
        pygame.draw.circle(ball_surf, (*core_glow, 80), (center, center), core_size + 2)
        pygame.draw.circle(ball_surf, (255, 255, 255, 150), (center, center), core_size)
        pygame.draw.circle(ball_surf, (255, 255, 255, 200), (center, center), max(2, core_size // 2))

        # === Layer 6: 상단 하이라이트 ===
        highlight_x = center - int(radius * 0.11)
        highlight_y = center - int(radius * 0.11)
        highlight_size = max(1, int(radius * 0.072))
        pygame.draw.circle(ball_surf, (255, 255, 255, 80), (highlight_x, highlight_y), highlight_size)

        # === Layer 7: 떠다니는 파티클 ===
        if random.random() < 0.4:
            angle = random.uniform(0, 2 * math.pi)
            dist = radius * random.uniform(0.867, 1.445)
            self.particles.append({
                'x': math.cos(angle) * dist,
                'y': math.sin(angle) * dist,
                'vx': random.uniform(-0.5, 0.5),
                'vy': random.uniform(-1.5, -0.5),
                'life': random.randint(20, 40),
                'max_life': 40,
                'size': random.uniform(0.42, 1.02),
                'color': base_color
            })

        if len(self.particles) > self.max_particles:
            self.particles = self.particles[-self.max_particles:]

        new_particles = []
        for p in self.particles:
            p['x'] += p['vx']
            p['y'] += p['vy']
            p['life'] -= 1

            if p['life'] > 0:
                alpha = int(200 * (p['life'] / p['max_life']))
                size = int(p['size'] * (p['life'] / p['max_life']))
                if alpha > 0 and size > 0:
                    px = int(center + p['x'])
                    py = int(center + p['y'])
                    pygame.draw.circle(ball_surf, (*p['color'], alpha), (px, py), max(1, size))
                new_particles.append(p)
        self.particles = new_particles

        # === Layer 8: 인텐시티 글로우 ===
        if intensity >= 2:
            glow_alpha = 10 + intensity * 5
            glow_r = int(radius * (1.3 + intensity * 0.1))
            glow_surf = pygame.Surface((glow_r * 2, glow_r * 2), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (*base_color, glow_alpha), (glow_r, glow_r), glow_r)
            surface.blit(glow_surf, (cx - glow_r, cy - glow_r), special_flags=pygame.BLEND_ADD)

        # 최종 렌더링
        surface.blit(ball_surf, (cx - center, cy - center))


# ============================================================================
# 공 생성 애니메이션 (pingfighter.py 기반)
# ============================================================================
class BallSpawnAnimation:
    """공 생성 애니메이션 - 3페이즈"""

    def __init__(self, x: int, y: int):
        self.x = x
        self.y = y
        self.start_time = time.time()
        self.active = True
        self.completed = False
        self.particles = []

    def update(self) -> bool:
        """업데이트, 완료시 True 반환"""
        elapsed = time.time() - self.start_time
        if elapsed >= SPAWN_TOTAL_DURATION:
            self.active = False
            self.completed = True
            return True
        return False

    def draw(self, surface: pygame.Surface, ball_renderer: EnergyBallRenderer):
        """애니메이션 렌더링"""
        elapsed = time.time() - self.start_time
        progress = min(1.0, elapsed / SPAWN_TOTAL_DURATION)

        # 페이즈 1: 에너지 수집 (파티클이 중심으로 모임)
        if elapsed < SPAWN_PHASE1_DURATION:
            phase_progress = elapsed / SPAWN_PHASE1_DURATION
            self._draw_phase1(surface, phase_progress)

        # 페이즈 2: 형태 형성 (공이 점점 나타남)
        elif elapsed < SPAWN_PHASE1_DURATION + SPAWN_PHASE2_DURATION:
            phase_progress = (elapsed - SPAWN_PHASE1_DURATION) / SPAWN_PHASE2_DURATION
            self._draw_phase2(surface, phase_progress, ball_renderer)

        # 페이즈 3: 완성 (글로우 효과와 함께 대기)
        else:
            phase_progress = (elapsed - SPAWN_PHASE1_DURATION - SPAWN_PHASE2_DURATION) / SPAWN_PHASE3_DURATION
            self._draw_phase3(surface, phase_progress, ball_renderer)

    def _draw_phase1(self, surface: pygame.Surface, progress: float):
        """페이즈 1: 에너지 수집"""
        # 중심으로 모이는 파티클 생성
        num_particles = int(20 * progress)
        for i in range(num_particles):
            angle = random.uniform(0, 2 * math.pi)
            dist = 150 * (1 - progress * 0.8) + random.uniform(-20, 20)
            px = self.x + math.cos(angle) * dist
            py = self.y + math.sin(angle) * dist

            size = random.randint(2, 5)
            alpha = int(100 + progress * 155)
            color = (100, 180, 255, alpha)

            pygame.draw.circle(surface, color, (int(px), int(py)), size)

        # 중심 글로우
        glow_radius = int(20 * progress)
        if glow_radius > 0:
            glow_surf = pygame.Surface((glow_radius * 4, glow_radius * 4), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (100, 180, 255, int(50 * progress)),
                             (glow_radius * 2, glow_radius * 2), glow_radius * 2)
            surface.blit(glow_surf, (self.x - glow_radius * 2, self.y - glow_radius * 2))

    def _draw_phase2(self, surface: pygame.Surface, progress: float, ball_renderer: EnergyBallRenderer):
        """페이즈 2: 형태 형성"""
        # 공이 점점 나타남
        current_radius = int(BALL_RADIUS * progress)
        if current_radius > 2:
            # 떨림 효과
            shake_x = random.randint(-2, 2) * (1 - progress)
            shake_y = random.randint(-2, 2) * (1 - progress)

            # 에너지볼 렌더링 (알파 적용)
            ball_surf = pygame.Surface((current_radius * 8, current_radius * 8), pygame.SRCALPHA)
            ball_renderer.draw(ball_surf, current_radius * 4, current_radius * 4, current_radius, 8)

            # 알파 적용
            alpha_surf = pygame.Surface(ball_surf.get_size(), pygame.SRCALPHA)
            alpha_surf.fill((255, 255, 255, int(255 * progress)))
            ball_surf.blit(alpha_surf, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)

            surface.blit(ball_surf, (self.x - current_radius * 4 + shake_x,
                                    self.y - current_radius * 4 + shake_y))

        # 주변 에너지 파동
        wave_radius = int(50 + 30 * progress)
        wave_alpha = int(80 * (1 - progress))
        if wave_alpha > 0:
            pygame.draw.circle(surface, (100, 180, 255, wave_alpha),
                             (self.x, self.y), wave_radius, 2)

    def _draw_phase3(self, surface: pygame.Surface, progress: float, ball_renderer: EnergyBallRenderer):
        """페이즈 3: 완성"""
        # 완성된 에너지볼
        ball_renderer.draw(surface, self.x, self.y, BALL_RADIUS, 8)

        # 발사 대기 글로우 (펄스)
        pulse = math.sin(progress * math.pi * 4) * 0.3 + 1.0
        glow_radius = int(BALL_RADIUS * 2 * pulse)
        glow_surf = pygame.Surface((glow_radius * 2, glow_radius * 2), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (100, 180, 255, 30),
                         (glow_radius, glow_radius), glow_radius)
        surface.blit(glow_surf, (self.x - glow_radius, self.y - glow_radius),
                    special_flags=pygame.BLEND_ADD)


# ============================================================================
# 트레일 시스템
# ============================================================================
class TrailSystem:
    """공 잔상 시스템"""

    def __init__(self):
        self.ghost_trail = []  # 고스트 잔상
        self.max_trail = 12

    def add_trail(self, x: float, y: float, speed: float):
        """트레일 추가"""
        intensity = 0
        for i, threshold in enumerate(INTENSITY_SPEED_THRESHOLDS):
            if speed >= threshold:
                intensity = i + 1

        self.ghost_trail.append({
            'x': x,
            'y': y,
            'alpha': 150,
            'size': BALL_RADIUS,
            'color': INTENSITY_COLORS.get(intensity, (100, 180, 255))
        })

        if len(self.ghost_trail) > self.max_trail:
            self.ghost_trail.pop(0)

    def update(self):
        """트레일 업데이트"""
        new_trail = []
        for t in self.ghost_trail:
            t['alpha'] -= 15
            t['size'] *= 0.92
            if t['alpha'] > 0 and t['size'] > 2:
                new_trail.append(t)
        self.ghost_trail = new_trail

    def draw(self, surface: pygame.Surface):
        """트레일 렌더링"""
        for t in self.ghost_trail:
            color = (*t['color'], int(t['alpha']))
            pygame.draw.circle(surface, color, (int(t['x']), int(t['y'])), int(t['size']))


# ============================================================================
# 이펙트 시스템
# ============================================================================
class EffectSystem:
    """충돌/스킬 이펙트 시스템"""

    def __init__(self):
        self.particles = []
        self.impacts = []

    def spawn_hit_particles(self, x: int, y: int, color: Tuple[int, int, int], count: int = 15):
        """타격 파티클 생성"""
        for _ in range(count):
            angle = random.uniform(0, 2 * math.pi)
            speed = random.uniform(3, 8)
            self.particles.append({
                'x': x,
                'y': y,
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed,
                'life': random.randint(15, 30),
                'max_life': 30,
                'size': random.randint(2, 5),
                'color': color
            })

    def spawn_wall_impact(self, x: int, y: int, is_left: bool):
        """벽 충돌 이펙트"""
        direction = 1 if is_left else -1
        for _ in range(10):
            angle = random.uniform(-0.5, 0.5) + (0 if is_left else math.pi)
            speed = random.uniform(2, 5)
            self.particles.append({
                'x': x,
                'y': y,
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed - 1,
                'life': random.randint(10, 20),
                'max_life': 20,
                'size': random.randint(1, 3),
                'color': (200, 200, 200)
            })

    def spawn_score_effect(self, x: int, y: int, player_num: int):
        """득점 이펙트"""
        color = P1_COLOR if player_num == 1 else P2_COLOR
        for _ in range(30):
            angle = random.uniform(0, 2 * math.pi)
            speed = random.uniform(5, 12)
            self.particles.append({
                'x': x,
                'y': y,
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed,
                'life': random.randint(30, 50),
                'max_life': 50,
                'size': random.randint(3, 8),
                'color': color
            })

    def update(self):
        """이펙트 업데이트"""
        new_particles = []
        for p in self.particles:
            p['x'] += p['vx']
            p['y'] += p['vy']
            p['vy'] += 0.15  # 중력
            p['life'] -= 1

            if p['life'] > 0:
                new_particles.append(p)
        self.particles = new_particles

    def draw(self, surface: pygame.Surface):
        """이펙트 렌더링"""
        for p in self.particles:
            alpha = int(255 * (p['life'] / p['max_life']))
            size = int(p['size'] * (p['life'] / p['max_life']))
            if alpha > 0 and size > 0:
                color = (*p['color'], alpha)
                pygame.draw.circle(surface, color, (int(p['x']), int(p['y'])), size)


# ============================================================================
# 플레이어 클래스
# ============================================================================
class Player:
    """멀티플레이어용 플레이어 클래스"""

    def __init__(self, player_num: int, x: int, y: int, width: int, height: int, is_top: bool):
        self.num = player_num
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.is_top = is_top
        self.speed = PADDLE_SPEED

        # 게이지 시스템
        self.gauge = 0
        self.gauge_max = GAUGE_MAX

        # 콤보 시스템
        self.combo = 0
        self.combo_timer = 0
        self.combo_display_timer = 0

        # 대시 시스템
        self.dash_active = False
        self.dash_timer = 0
        self.dash_cooldown = 0
        self.dash_direction = 0

        # 스킬 상태
        self.short_shot_active = False
        self.short_shot_timer = 0
        self.drive_active = False
        self.drive_direction = 0
        self.power_smash_pending = False

        # 키 상태
        self.keys = P1_KEYS if player_num == 1 else P2_KEYS

        # 색상
        self.color = P1_COLOR if player_num == 1 else P2_COLOR

        # 애니메이션
        self.walking_timer = 0
        self.hit_timer = 0

        # 넉백
        self.knockback_vel = 0
        self.knockback_timer = 0

        # 점수
        self.score = 0

    @property
    def rect(self) -> pygame.Rect:
        return pygame.Rect(self.x, self.y, self.width, self.height)

    @property
    def centerx(self) -> int:
        return self.x + self.width // 2

    @property
    def centery(self) -> int:
        return self.y + self.height // 2

    def update(self, keys_pressed: dict, width: int):
        """플레이어 업데이트"""
        # 대시 쿨다운
        if self.dash_cooldown > 0:
            self.dash_cooldown -= 1

        # 넉백 처리
        if self.knockback_timer > 0:
            self.x += self.knockback_vel
            self.knockback_timer -= 1
            self.knockback_vel *= 0.85
        else:
            # 이동 처리
            move_speed = self.speed

            # 대시 처리
            if self.dash_active:
                self.dash_timer -= 1
                move_speed = DASH_SPEED_BOOST
                if self.dash_timer <= 0:
                    self.dash_active = False
            elif keys_pressed.get(self.keys['dash']) and self.dash_cooldown <= 0:
                # 대시 시작
                if keys_pressed.get(self.keys['left']):
                    self.dash_direction = -1
                    self.dash_active = True
                    self.dash_timer = DASH_DURATION
                    self.dash_cooldown = DASH_COOLDOWN
                elif keys_pressed.get(self.keys['right']):
                    self.dash_direction = 1
                    self.dash_active = True
                    self.dash_timer = DASH_DURATION
                    self.dash_cooldown = DASH_COOLDOWN

            # 이동
            if self.dash_active:
                self.x += self.dash_direction * move_speed
            else:
                if keys_pressed.get(self.keys['left']):
                    self.x -= move_speed
                    self.walking_timer = (self.walking_timer + 1) % 60
                if keys_pressed.get(self.keys['right']):
                    self.x += move_speed
                    self.walking_timer = (self.walking_timer + 1) % 60

        # 경계 제한
        self.x = max(0, min(width - self.width, self.x))

        # 콤보 타이머
        if self.combo_timer > 0:
            self.combo_timer -= 1
            if self.combo_timer <= 0:
                self.combo = 0

        if self.combo_display_timer > 0:
            self.combo_display_timer -= 1

        # 쇼트 타이머
        if self.short_shot_timer > 0:
            self.short_shot_timer -= 1
            if self.short_shot_timer <= 0:
                self.short_shot_active = False

        # 히트 타이머
        if self.hit_timer > 0:
            self.hit_timer -= 1

    def on_hit(self, base_charge: int = GAUGE_HIT_CHARGE):
        """공 타격 시"""
        # 콤보 증가
        self.combo += 1
        self.combo_timer = 120  # 2초
        self.combo_display_timer = 60

        # 게이지 충전 (콤보 보너스 적용)
        bonus = COMBO_GAUGE_BONUS.get(min(self.combo, 6), COMBO_MAX_BONUS)
        charge = int(base_charge * (1 + bonus / 100))
        self.gauge = min(self.gauge_max, self.gauge + charge)

        # 히트 애니메이션
        self.hit_timer = 10

    def apply_knockback(self, direction: int, speed: float = 8):
        """넉백 적용"""
        self.knockback_vel = direction * speed
        self.knockback_timer = SHORT_SHOT_KNOCKBACK_FRAMES

    def try_short_shot(self) -> bool:
        """쇼트샷 시도"""
        if self.gauge >= SHORT_SHOT_GAUGE_COST:
            self.gauge -= SHORT_SHOT_GAUGE_COST
            self.short_shot_active = True
            self.short_shot_timer = 30
            return True
        return False

    def try_drive(self, direction: int) -> bool:
        """드라이브 시도"""
        if self.gauge >= DRIVE_GAUGE_COST:
            self.gauge -= DRIVE_GAUGE_COST
            self.drive_active = True
            self.drive_direction = direction
            return True
        return False

    def try_power_smash(self) -> bool:
        """파워스매싱 시도"""
        if self.gauge >= POWER_SMASH_GAUGE_COST:
            self.gauge -= POWER_SMASH_GAUGE_COST
            self.power_smash_pending = True
            return True
        return False

    def draw(self, surface: pygame.Surface, create_smasher_func: Callable = None):
        """플레이어 렌더링"""
        if create_smasher_func:
            # 스매셔 스프라이트 사용
            try:
                step_phase = (self.walking_timer % 60) / 60.0
                sprite = create_smasher_func(step_phase)

                # 상단 플레이어는 뒤집기
                if self.is_top:
                    sprite = pygame.transform.flip(sprite, False, True)

                # 색상 오버레이 (P1/P2 구분)
                tint_surf = pygame.Surface(sprite.get_size(), pygame.SRCALPHA)
                tint_surf.fill((*self.color, 30))
                sprite.blit(tint_surf, (0, 0), special_flags=pygame.BLEND_RGBA_ADD)

                # 중앙 정렬
                sprite_rect = sprite.get_rect(center=(self.centerx, self.centery))
                surface.blit(sprite, sprite_rect)

            except Exception:
                # 폴백: 단순 사각형
                self._draw_simple(surface)
        else:
            self._draw_simple(surface)

        # 대시 쿨다운 표시
        if self.dash_cooldown > 0:
            cooldown_ratio = self.dash_cooldown / DASH_COOLDOWN
            bar_width = 40
            bar_x = self.centerx - bar_width // 2
            bar_y = self.y + self.height + 5 if not self.is_top else self.y - 10

            pygame.draw.rect(surface, (60, 60, 60), (bar_x, bar_y, bar_width, 4))
            pygame.draw.rect(surface, self.color, (bar_x, bar_y, int(bar_width * (1 - cooldown_ratio)), 4))

    def _draw_simple(self, surface: pygame.Surface):
        """단순 사각형 패들"""
        # 메인 바디
        pygame.draw.rect(surface, self.color, self.rect, border_radius=5)
        # 테두리
        border_color = tuple(min(255, c + 50) for c in self.color)
        pygame.draw.rect(surface, border_color, self.rect, 2, border_radius=5)

        # P1/P2 표시
        label = f"P{self.num}"
        font = pygame.font.Font(None, 20)
        text = font.render(label, True, (255, 255, 255))
        text_rect = text.get_rect(center=(self.centerx, self.centery))
        surface.blit(text, text_rect)


# ============================================================================
# 공 클래스
# ============================================================================
class Ball:
    """멀티플레이어용 공 클래스"""

    def __init__(self, x: int, y: int):
        self.x = x
        self.y = y
        self.vx = 0
        self.vy = 0
        self.radius = BALL_RADIUS
        self.active = False

        # 물리
        self.spin = 0  # 드라이브 스핀
        self.power_smash_active = False
        self.power_smash_gravity = 0

        # 트레일
        self.trail_timer = 0

    @property
    def speed(self) -> float:
        return math.sqrt(self.vx * self.vx + self.vy * self.vy)

    @property
    def rect(self) -> pygame.Rect:
        return pygame.Rect(self.x - self.radius, self.y - self.radius,
                          self.radius * 2, self.radius * 2)

    def reset(self, x: int, y: int, direction: int = 1):
        """공 리셋"""
        self.x = x
        self.y = y
        self.vx = random.uniform(-2, 2)
        self.vy = BALL_BASE_SPEED * direction
        self.active = True
        self.spin = 0
        self.power_smash_active = False
        self.power_smash_gravity = 0

    def update(self, width: int, height: int) -> Tuple[bool, int]:
        """
        공 업데이트
        Returns: (scored, scorer) - scored: 득점 여부, scorer: 득점 플레이어 번호 (1 or 2)
        """
        if not self.active:
            return False, 0

        # 스핀 적용 (드라이브)
        if self.spin != 0:
            self.vx += self.spin
            self.spin *= 0.98  # 감쇠
            if abs(self.spin) < 0.01:
                self.spin = 0

        # 파워스매싱 중력
        if self.power_smash_active:
            self.vy += self.power_smash_gravity
            self.power_smash_gravity += 0.002

        # 이동
        self.x += self.vx
        self.y += self.vy

        # 좌우 벽 충돌
        if self.x - self.radius <= 0:
            self.x = self.radius
            self.vx = abs(self.vx)
            return False, 0
        elif self.x + self.radius >= width:
            self.x = width - self.radius
            self.vx = -abs(self.vx)
            return False, 0

        # 득점 체크
        if self.y - self.radius <= 0:
            # P1 득점 (상단 벽)
            return True, 1
        elif self.y + self.radius >= height:
            # P2 득점 (하단 벽)
            return True, 2

        return False, 0

    def handle_paddle_collision(self, player: Player, keys_pressed: dict) -> bool:
        """패들 충돌 처리"""
        if not self.active:
            return False

        paddle_rect = player.rect
        ball_rect = self.rect

        # 충돌 검사
        if not ball_rect.colliderect(paddle_rect):
            return False

        # 방향 확인 (위에서 내려오는 공 vs 아래에서 올라오는 공)
        if player.is_top and self.vy < 0:
            return False  # 상단 플레이어에게 위로 가는 공은 무시
        if not player.is_top and self.vy > 0:
            return False  # 하단 플레이어에게 아래로 가는 공은 무시

        # 반사
        hit_pos = (self.x - player.x) / player.width  # 0.0 ~ 1.0
        hit_pos = max(0, min(1, hit_pos))

        # 각도 계산 (±60도)
        angle_factor = (hit_pos - 0.5) * 2  # -1 ~ 1
        max_angle = 60
        reflect_angle = angle_factor * max_angle

        # 속도 계산
        current_speed = self.speed
        new_speed = min(current_speed * 1.03, 25)  # 약간 속도 증가, 최대 제한

        # 새 속도 벡터
        angle_rad = math.radians(reflect_angle)
        direction = -1 if player.is_top else 1
        self.vx = new_speed * math.sin(angle_rad)
        self.vy = new_speed * math.cos(angle_rad) * direction

        # 스킬 체크
        up_key = player.keys['up']
        down_key = player.keys['down']
        left_key = player.keys['left']
        right_key = player.keys['right']

        # 쇼트샷 (위 키)
        if keys_pressed.get(up_key):
            if player.try_short_shot():
                self.vx *= SHORT_SHOT_SPEED_MULTIPLIER
                self.vy *= SHORT_SHOT_SPEED_MULTIPLIER

        # 드라이브 (좌/우 키)
        elif keys_pressed.get(left_key):
            if player.try_drive(-1):
                self.spin = -DRIVE_BASE_SPIN
                self.vx *= DRIVE_SPEED_BOOST
        elif keys_pressed.get(right_key):
            if player.try_drive(1):
                self.spin = DRIVE_BASE_SPIN
                self.vx *= DRIVE_SPEED_BOOST

        # 파워스매싱 (아래 키)
        elif keys_pressed.get(down_key):
            if player.try_power_smash():
                self.power_smash_active = True
                self.power_smash_gravity = POWER_SMASH_GRAVITY
                self.vy *= 1.5

        # 히트 콜백
        player.on_hit()

        # 공 위치 보정 (패들 밖으로)
        if player.is_top:
            self.y = player.y + player.height + self.radius + 1
        else:
            self.y = player.y - self.radius - 1

        return True


# ============================================================================
# UI 컴포넌트
# ============================================================================
class GaugeBar:
    """게이지 바 UI"""

    def __init__(self, player: Player, x: int, y: int, width: int = 200, height: int = 20):
        self.player = player
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.displayed_gauge = 0

    def update(self):
        """게이지 표시 스무딩"""
        diff = self.player.gauge - self.displayed_gauge
        self.displayed_gauge += diff * 0.15

    def draw(self, surface: pygame.Surface):
        """게이지 바 렌더링"""
        self.update()

        # 배경
        bg_rect = pygame.Rect(self.x, self.y, self.width, self.height)
        pygame.draw.rect(surface, (40, 40, 40), bg_rect, border_radius=3)

        # 게이지
        ratio = self.displayed_gauge / self.player.gauge_max
        gauge_width = int(self.width * ratio)
        if gauge_width > 0:
            gauge_rect = pygame.Rect(self.x, self.y, gauge_width, self.height)
            pygame.draw.rect(surface, self.player.color, gauge_rect, border_radius=3)

        # 스킬 코스트 마커
        markers = [
            (SHORT_SHOT_GAUGE_COST, "S"),
            (DRIVE_GAUGE_COST, "D"),
            (POWER_SMASH_GAUGE_COST, "P"),
        ]
        for cost, label in markers:
            marker_x = self.x + int(self.width * cost / self.player.gauge_max)
            pygame.draw.line(surface, (200, 200, 200),
                           (marker_x, self.y), (marker_x, self.y + self.height), 1)

        # 테두리
        pygame.draw.rect(surface, (100, 100, 100), bg_rect, 2, border_radius=3)

        # 게이지 수치
        font = pygame.font.Font(None, 18)
        text = font.render(f"{int(self.displayed_gauge)}/{self.player.gauge_max}", True, (255, 255, 255))
        text_rect = text.get_rect(center=(self.x + self.width // 2, self.y + self.height // 2))
        surface.blit(text, text_rect)


class ComboDisplay:
    """콤보 표시 UI"""

    def __init__(self, player: Player):
        self.player = player

    def draw(self, surface: pygame.Surface):
        """콤보 표시"""
        if self.player.combo < 2 or self.player.combo_display_timer <= 0:
            return

        # 콤보 색상
        combo_colors = {
            2: (255, 200, 100),
            3: (255, 150, 50),
            4: (255, 100, 50),
            5: (255, 50, 100),
        }
        color = combo_colors.get(min(self.player.combo, 5), (255, 50, 150))

        # 위치
        x = self.player.centerx
        y = self.player.y - 30 if not self.player.is_top else self.player.y + self.player.height + 30

        # 크기 애니메이션
        scale = 1.0 + 0.3 * (self.player.combo_display_timer / 60)
        font_size = int(28 * scale)

        font = pygame.font.Font(None, font_size)
        text = font.render(f"{self.player.combo} COMBO!", True, color)
        text_rect = text.get_rect(center=(x, y))
        surface.blit(text, text_rect)


class ScoreBoard:
    """점수판 UI"""

    def __init__(self, width: int, height: int):
        self.width = width
        self.height = height
        self.win_score = 5

    def draw(self, surface: pygame.Surface, p1_score: int, p2_score: int):
        """점수판 렌더링"""
        # 중앙 구분선
        pygame.draw.line(surface, (60, 60, 80),
                        (0, self.height // 2), (self.width, self.height // 2), 2)

        # 점선
        for x in range(0, self.width, 30):
            pygame.draw.circle(surface, (80, 80, 100), (x, self.height // 2), 3)

        # P1 점수 (하단)
        self._draw_score(surface, 1, p1_score, P1_COLOR, self.height - 60)

        # P2 점수 (상단)
        self._draw_score(surface, 2, p2_score, P2_COLOR, 30)

    def _draw_score(self, surface: pygame.Surface, player_num: int, score: int,
                   color: Tuple[int, int, int], y: int):
        """개별 점수 렌더링"""
        font = pygame.font.Font(None, 48)
        text = font.render(f"P{player_num}: {score}", True, color)
        text_rect = text.get_rect(center=(self.width // 2, y))
        surface.blit(text, text_rect)


# ============================================================================
# 메인 게임 클래스
# ============================================================================
class MultiplayerGame:
    """멀티플레이어 게임 메인 클래스"""

    def __init__(self, screen: pygame.Surface, width: int, height: int,
                 create_smasher_func: Callable = None,
                 play_sound_funcs: Dict[str, Callable] = None,
                 bgm_manager = None):
        self.screen = screen
        self.width = width
        self.height = height
        self.create_smasher_func = create_smasher_func
        self.sounds = play_sound_funcs or {}
        self.bgm_manager = bgm_manager

        # 게임 상태
        self.running = True
        self.game_over = False
        self.winner = None
        self.win_score = 5

        # 플레이어
        paddle_width = 100
        paddle_height = 20

        # P1 (하단)
        self.p1 = Player(
            player_num=1,
            x=width // 2 - paddle_width // 2,
            y=height - 80,
            width=paddle_width,
            height=paddle_height,
            is_top=False
        )

        # P2 (상단)
        self.p2 = Player(
            player_num=2,
            x=width // 2 - paddle_width // 2,
            y=60,
            width=paddle_width,
            height=paddle_height,
            is_top=True
        )

        # 공
        self.ball = Ball(width // 2, height // 2)
        self.spawn_animation = None

        # 렌더러
        self.ball_renderer = EnergyBallRenderer()
        self.trail_system = TrailSystem()
        self.effect_system = EffectSystem()

        # UI
        self.p1_gauge = GaugeBar(self.p1, 10, height - 30, 200, 16)
        self.p2_gauge = GaugeBar(self.p2, 10, 10, 200, 16)
        self.p1_combo = ComboDisplay(self.p1)
        self.p2_combo = ComboDisplay(self.p2)
        self.scoreboard = ScoreBoard(width, height)

        # 라운드 상태
        self.round_start_delay = 0
        self.round_countdown = 0

        # 시작
        self._start_new_round()

    def _start_new_round(self):
        """새 라운드 시작"""
        # 공 생성 애니메이션
        self.spawn_animation = BallSpawnAnimation(self.width // 2, self.height // 2)
        self.ball.active = False
        self.round_start_delay = 60

    def _play_sound(self, name: str):
        """사운드 재생"""
        if name in self.sounds:
            try:
                self.sounds[name]()
            except:
                pass

    def update(self):
        """게임 업데이트"""
        if self.game_over:
            return

        # 키 입력
        keys = pygame.key.get_pressed()
        keys_pressed = {k: keys[k] for k in range(len(keys))}

        # 라운드 시작 대기
        if self.round_start_delay > 0:
            self.round_start_delay -= 1
            return

        # 공 생성 애니메이션
        if self.spawn_animation and self.spawn_animation.active:
            if self.spawn_animation.update():
                # 애니메이션 완료, 공 활성화
                direction = 1 if random.random() < 0.5 else -1
                self.ball.reset(self.width // 2, self.height // 2, direction)
                self.spawn_animation = None
            return

        # 플레이어 업데이트
        self.p1.update(keys_pressed, self.width)
        self.p2.update(keys_pressed, self.width)

        # 공 업데이트
        scored, scorer = self.ball.update(self.width, self.height)

        if scored:
            # 득점
            if scorer == 1:
                self.p1.score += 1
                self.effect_system.spawn_score_effect(self.ball.x, 50, 1)
            else:
                self.p2.score += 1
                self.effect_system.spawn_score_effect(self.ball.x, self.height - 50, 2)

            self._play_sound('score')

            # 승리 체크
            if self.p1.score >= self.win_score:
                self.game_over = True
                self.winner = 1
            elif self.p2.score >= self.win_score:
                self.game_over = True
                self.winner = 2
            else:
                # 다음 라운드
                self._start_new_round()
            return

        # 패들 충돌
        if self.ball.handle_paddle_collision(self.p1, keys_pressed):
            self._play_sound('hit')
            self.effect_system.spawn_hit_particles(
                int(self.ball.x), int(self.ball.y), self.p1.color)

        if self.ball.handle_paddle_collision(self.p2, keys_pressed):
            self._play_sound('hit')
            self.effect_system.spawn_hit_particles(
                int(self.ball.x), int(self.ball.y), self.p2.color)

        # 벽 충돌 이펙트
        if self.ball.x <= self.ball.radius:
            self._play_sound('wall')
            self.effect_system.spawn_wall_impact(int(self.ball.x), int(self.ball.y), True)
        elif self.ball.x >= self.width - self.ball.radius:
            self._play_sound('wall')
            self.effect_system.spawn_wall_impact(int(self.ball.x), int(self.ball.y), False)

        # 트레일 업데이트
        if self.ball.active:
            self.trail_system.add_trail(self.ball.x, self.ball.y, self.ball.speed)
        self.trail_system.update()

        # 이펙트 업데이트
        self.effect_system.update()

    def draw(self):
        """게임 렌더링"""
        # 배경
        self.screen.fill((20, 25, 35))

        # 점수판
        self.scoreboard.draw(self.screen, self.p1.score, self.p2.score)

        # 트레일
        self.trail_system.draw(self.screen)

        # 공 생성 애니메이션
        if self.spawn_animation and self.spawn_animation.active:
            self.spawn_animation.draw(self.screen, self.ball_renderer)
        elif self.ball.active:
            # 에너지볼 렌더링
            self.ball_renderer.draw(self.screen, int(self.ball.x), int(self.ball.y),
                                   self.ball.radius, self.ball.speed)

        # 이펙트
        self.effect_system.draw(self.screen)

        # 플레이어
        self.p1.draw(self.screen, self.create_smasher_func)
        self.p2.draw(self.screen, self.create_smasher_func)

        # 콤보
        self.p1_combo.draw(self.screen)
        self.p2_combo.draw(self.screen)

        # 게이지 바
        self.p1_gauge.draw(self.screen)
        self.p2_gauge.draw(self.screen)

        # 조작법 안내
        self._draw_controls()

        # 게임 오버
        if self.game_over:
            self._draw_game_over()

        pygame.display.flip()

    def _draw_controls(self):
        """조작법 안내 렌더링"""
        font = pygame.font.Font(None, 18)

        p1_text = font.render("P1: ←→ Move | Shift+←→ Dash | ↑Shot ↓Power ←→Drive",
                             True, (120, 120, 120))
        p2_text = font.render("P2: A/D Move | Space+A/D Dash | W Shot S Power A/D Drive",
                             True, (120, 120, 120))
        esc_text = font.render("ESC: Exit", True, (120, 120, 120))

        self.screen.blit(p1_text, (10, self.height - 18))
        self.screen.blit(p2_text, (10, 2))
        self.screen.blit(esc_text, (self.width - esc_text.get_width() - 10, self.height // 2 - 10))

    def _draw_game_over(self):
        """게임 오버 화면"""
        # 반투명 오버레이
        overlay = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 180))
        self.screen.blit(overlay, (0, 0))

        # 승자 표시
        winner_color = P1_COLOR if self.winner == 1 else P2_COLOR
        font_large = pygame.font.Font(None, 72)
        font_medium = pygame.font.Font(None, 36)

        text = font_large.render(f"P{self.winner} WIN!", True, winner_color)
        text_rect = text.get_rect(center=(self.width // 2, self.height // 2 - 40))
        self.screen.blit(text, text_rect)

        score_text = font_medium.render(f"P1: {self.p1.score} - P2: {self.p2.score}",
                                        True, (200, 200, 200))
        score_rect = score_text.get_rect(center=(self.width // 2, self.height // 2 + 20))
        self.screen.blit(score_text, score_rect)

        hint_text = font_medium.render("Press any key to continue", True, (150, 150, 150))
        hint_rect = hint_text.get_rect(center=(self.width // 2, self.height // 2 + 80))
        self.screen.blit(hint_text, hint_rect)

    def run(self):
        """게임 루프 실행"""
        clock = pygame.time.Clock()

        # BGM 재생
        if self.bgm_manager:
            try:
                self.bgm_manager.play_stage_bgm(1)
            except:
                pass

        while self.running:
            # 이벤트 처리
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    self.running = False
                elif event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_ESCAPE:
                        self.running = False
                    elif self.game_over:
                        # 게임 오버 상태에서 아무 키나 누르면 종료
                        self.running = False

            # 업데이트
            self.update()

            # 렌더링
            self.draw()

            clock.tick(60)

        # BGM 정지
        if self.bgm_manager:
            try:
                self.bgm_manager.play_menu_bgm()
            except:
                pass


# ============================================================================
# 캐릭터 선택 화면
# ============================================================================
def show_character_select(screen: pygame.Surface, width: int, height: int,
                         create_smasher_func: Callable = None) -> Tuple[str, str]:
    """
    캐릭터 선택 화면
    Returns: (p1_character, p2_character) 또는 종료시 (None, None)
    """
    clock = pygame.time.Clock()

    # 현재는 스매셔만 선택 가능
    characters = ["smasher"]  # TODO: 다른 캐릭터 추가

    p1_selected = 0
    p2_selected = 0
    p1_ready = False
    p2_ready = False

    running = True
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                return None, None
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    return None, None

                # P1 선택 (방향키)
                if not p1_ready:
                    if event.key == pygame.K_LEFT:
                        p1_selected = (p1_selected - 1) % len(characters)
                    elif event.key == pygame.K_RIGHT:
                        p1_selected = (p1_selected + 1) % len(characters)
                    elif event.key == pygame.K_RETURN or event.key == pygame.K_RSHIFT:
                        p1_ready = True

                # P2 선택 (WASD)
                if not p2_ready:
                    if event.key == pygame.K_a:
                        p2_selected = (p2_selected - 1) % len(characters)
                    elif event.key == pygame.K_d:
                        p2_selected = (p2_selected + 1) % len(characters)
                    elif event.key == pygame.K_SPACE:
                        p2_ready = True

        # 둘 다 준비되면 게임 시작
        if p1_ready and p2_ready:
            return characters[p1_selected], characters[p2_selected]

        # 렌더링
        screen.fill((20, 25, 35))

        # 타이틀
        font_large = pygame.font.Font(None, 64)
        title = font_large.render("CHARACTER SELECT", True, (255, 255, 255))
        title_rect = title.get_rect(center=(width // 2, 60))
        screen.blit(title, title_rect)

        # P1 선택 영역 (왼쪽)
        p1_x = width // 4
        _draw_character_slot(screen, p1_x, height // 2, characters[p1_selected],
                            P1_COLOR, "P1", p1_ready, create_smasher_func)

        # P2 선택 영역 (오른쪽)
        p2_x = width * 3 // 4
        _draw_character_slot(screen, p2_x, height // 2, characters[p2_selected],
                            P2_COLOR, "P2", p2_ready, create_smasher_func)

        # VS 표시
        font_vs = pygame.font.Font(None, 72)
        vs_text = font_vs.render("VS", True, (255, 200, 0))
        vs_rect = vs_text.get_rect(center=(width // 2, height // 2))
        screen.blit(vs_text, vs_rect)

        # 조작법 안내
        font_small = pygame.font.Font(None, 24)
        p1_control = font_small.render("P1: ←→ Select, Enter/Shift to Ready", True, P1_COLOR)
        p2_control = font_small.render("P2: A/D Select, Space to Ready", True, P2_COLOR)
        screen.blit(p1_control, (10, height - 50))
        screen.blit(p2_control, (10, height - 25))

        pygame.display.flip()
        clock.tick(60)

    return None, None


def _draw_character_slot(screen: pygame.Surface, x: int, y: int, character: str,
                        color: Tuple[int, int, int], label: str, ready: bool,
                        create_smasher_func: Callable = None):
    """캐릭터 슬롯 렌더링"""
    # 박스
    box_width = 200
    box_height = 250
    box_rect = pygame.Rect(x - box_width // 2, y - box_height // 2, box_width, box_height)

    # 배경
    pygame.draw.rect(screen, (40, 40, 50), box_rect, border_radius=10)

    # 테두리 (준비되면 강조)
    border_color = color if ready else (80, 80, 100)
    border_width = 4 if ready else 2
    pygame.draw.rect(screen, border_color, box_rect, border_width, border_radius=10)

    # 캐릭터 이름
    font = pygame.font.Font(None, 36)
    name_text = font.render(character.upper(), True, (255, 255, 255))
    name_rect = name_text.get_rect(center=(x, y - 80))
    screen.blit(name_text, name_rect)

    # 캐릭터 스프라이트 (스매셔)
    if create_smasher_func and character == "smasher":
        try:
            sprite = create_smasher_func(0)
            sprite_rect = sprite.get_rect(center=(x, y + 20))
            screen.blit(sprite, sprite_rect)
        except:
            pass

    # 플레이어 라벨
    label_font = pygame.font.Font(None, 28)
    label_text = label_font.render(label, True, color)
    label_rect = label_text.get_rect(center=(x, y - 110))
    screen.blit(label_text, label_rect)

    # Ready 표시
    if ready:
        ready_font = pygame.font.Font(None, 32)
        ready_text = ready_font.render("READY!", True, (100, 255, 100))
        ready_rect = ready_text.get_rect(center=(x, y + 100))
        screen.blit(ready_text, ready_rect)


# ============================================================================
# 메인 진입점 (외부에서 호출)
# ============================================================================
def run_multiplayer_game(screen: pygame.Surface, width: int, height: int,
                        get_font_func: Callable = None,
                        play_sound_funcs: Dict[str, Callable] = None,
                        create_smasher_func: Callable = None,
                        bgm_manager = None):
    """
    멀티플레이어 게임 시작

    Args:
        screen: pygame 화면
        width: 화면 너비
        height: 화면 높이
        get_font_func: 폰트 함수 (사용 안 함, 호환성 유지)
        play_sound_funcs: 사운드 함수들 {'click', 'hit', 'wall', 'score', 'short_shot'}
        create_smasher_func: 스매셔 스프라이트 생성 함수
        bgm_manager: BGM 매니저
    """
    global _create_smasher_paddle_surface, _get_font, _bgm_manager
    global _play_paddle_sound, _play_wall_sound, _play_dash_sound, _play_notification_sound

    _create_smasher_paddle_surface = create_smasher_func
    _get_font = get_font_func
    _bgm_manager = bgm_manager

    if play_sound_funcs:
        _play_paddle_sound = play_sound_funcs.get('hit')
        _play_wall_sound = play_sound_funcs.get('wall')
        _play_dash_sound = play_sound_funcs.get('short_shot')
        _play_notification_sound = play_sound_funcs.get('score')

    # 캐릭터 선택 화면
    p1_char, p2_char = show_character_select(screen, width, height, create_smasher_func)

    if p1_char is None or p2_char is None:
        # 취소됨
        return

    # 게임 시작
    game = MultiplayerGame(
        screen=screen,
        width=width,
        height=height,
        create_smasher_func=create_smasher_func,
        play_sound_funcs=play_sound_funcs,
        bgm_manager=bgm_manager
    )
    game.run()


# ============================================================================
# 테스트용 (직접 실행 시)
# ============================================================================
if __name__ == "__main__":
    pygame.init()
    screen = pygame.display.set_mode((960, 720))
    pygame.display.set_caption("PingFighter - Multiplayer Mode")

    run_multiplayer_game(screen, 960, 720)

    pygame.quit()
