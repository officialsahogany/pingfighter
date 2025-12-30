# -*- coding: utf-8 -*-
"""
로컬 멀티플레이어 모드 - 싱글플레이어 완전 동일 퀄리티
pingfighter.py의 모든 시스템을 그대로 재현:
- 에너지볼 렌더링 (8레이어 구조)
- 공 생성 애니메이션 (3페이즈 8초)
- 타격 물리 시스템 (각도 기반 반사, 넉백)
- 스킬 시스템 (쇼트, 드라이브, 파워스매싱)
- 게이지 바 UI (캐릭터별 디자인)
- 콤보 시스템
- 트레일/이펙트 시스템
"""

import pygame
import random
import math
import time
from typing import Dict, List, Tuple, Optional, Callable, Any

# ============================================================================
# 상수 정의 (싱글플레이어 pingfighter.py 기준 완전 동일)
# ============================================================================

# 게이지 시스템
GAUGE_MAX = 500
GAUGE_HIT_CHARGE = 60  # 스매셔 기본 충전량

# 콤보 보너스 (%) - pingfighter.py 라인 8886-8899
COMBO_GAUGE_BONUS = {
    2: 5,    # 2콤보: +5%
    3: 10,   # 3콤보: +10%
    4: 15,   # 4콤보: +15%
    5: 20,   # 5콤보: +20%
    6: 25,   # 6콤보+: +25%
}
COMBO_MAX_BONUS = 25

# 쇼트 (Short Shot) - pingfighter.py 라인 1701-1715
SHORT_SHOT_GAUGE_COST = 100
SHORT_SHOT_SPEED_MULTIPLIER = 1.3
SHORT_SHOT_TOTAL_FRAMES = 36
SHORT_SHOT_VERTICAL_FRAMES = 12
SHORT_SHOT_MAX_ANGLE_DEG = 45
SHORT_SHOT_CURVE_TRIGGER_OFFSET = 48
SHORT_SHOT_KNOCKBACK_SPEED = 9.0
SHORT_SHOT_KNOCKBACK_FRAMES = 24
SHORT_SHOT_STUN_FRAMES = 30

# 드라이브 (Drive) - pingfighter.py 라인 84476-84549
DRIVE_GAUGE_COST = 150
DRIVE_BASE_SPIN = 0.25
DRIVE_SPIN_CAP = 0.6
DRIVE_SPEED_BOOST = 1.015

# 파워스매싱 (Power Smashing) - pingfighter.py 라인 8835-8857
POWER_SMASH_GAUGE_COST = 350
POWER_SMASH_GRAVITY = 0.035
POWER_SMASH_ARC_STRENGTH = 0.8

# 물리 상수 - pingfighter.py 기준
BALL_BASE_SPEED = 6.0
BALL_RADIUS = 10
PADDLE_WIDTH = 100
PADDLE_HEIGHT = 20
PADDLE_SPEED = 8
DASH_SPEED_BOOST = 4
DASH_COOLDOWN = 30

# 에너지볼 색상 - pingfighter.py 라인 26060-26150
ENERGY_BALL_CORE_COLOR = (255, 255, 255)
ENERGY_BALL_INNER_COLOR = (100, 180, 255)
ENERGY_BALL_OUTER_COLOR = (30, 100, 200)
ENERGY_BALL_RING_COLOR = (80, 160, 255)
ENERGY_BALL_PARTICLE_COLORS = [
    (150, 200, 255), (100, 180, 255), (80, 160, 255),
    (200, 230, 255), (120, 200, 255)
]

# 인텐시티 색상 - pingfighter.py 라인 26215
INTENSITY_COLORS = {
    0: [(100, 180, 255), (80, 160, 255), (60, 140, 255)],      # 파란색
    1: [(180, 220, 100), (160, 200, 80), (140, 180, 60)],      # 연두색
    2: [(255, 220, 100), (255, 200, 80), (255, 180, 60)],      # 노란색
    3: [(255, 160, 80), (255, 140, 60), (255, 120, 40)],       # 주황색
    4: [(255, 100, 80), (255, 80, 60), (255, 60, 40)],         # 빨간색
    5: [(255, 80, 150), (255, 60, 130), (255, 40, 110)],       # 핑크
}
INTENSITY_GLOW_COLORS = {
    0: (60, 100, 180, 30),
    1: (100, 150, 50, 40),
    2: (180, 150, 30, 50),
    3: (200, 100, 30, 60),
    4: (200, 50, 30, 70),
    5: (200, 40, 100, 80),
}
INTENSITY_SPEED_THRESHOLDS = [8, 12, 16, 22, 28, 35]

# 콤보 색상 - pingfighter.py 라인 32410-32419
COMBO_COLORS = {
    2: (255, 200, 100),  # 주황색
    3: (255, 150, 100),  # 더 진한 주황
    4: (255, 100, 100),  # 빨간색
    5: (255, 100, 200),  # 핑크
    6: (200, 100, 255),  # 보라색
}


# ============================================================================
# 에너지볼 렌더링 시스템 (pingfighter.py draw_energy_ball 완전 재현)
# ============================================================================

class EnergyBallRenderer:
    """
    싱글플레이어와 동일한 8레이어 에너지볼 렌더링
    pingfighter.py 라인 26893 draw_energy_ball() 완전 재현
    """

    def __init__(self):
        self.rotation_angle = 0
        self.pulse_phase = 0
        self.particles = []
        self.ring_particles = []
        self.MAX_PARTICLES = 20

    def update(self, dt: float):
        """매 프레임 애니메이션 업데이트"""
        current_time = pygame.time.get_ticks()
        self.rotation_angle = (current_time * 0.15) % 360
        self.pulse_phase = current_time * 0.005

        # 파티클 업데이트
        for particle in self.particles[:]:
            particle['life'] -= dt
            if particle['life'] <= 0:
                self.particles.remove(particle)

        # 새 파티클 생성
        if len(self.particles) < self.MAX_PARTICLES and random.random() < 0.3:
            angle = random.uniform(0, math.pi * 2)
            dist = random.uniform(5, 15)
            self.particles.append({
                'angle': angle,
                'dist': dist,
                'speed': random.uniform(0.5, 1.5),
                'size': random.uniform(1, 3),
                'life': random.uniform(0.3, 0.8),
                'color': random.choice(ENERGY_BALL_PARTICLE_COLORS)
            })

    def draw(self, surface: pygame.Surface, cx: int, cy: int, radius: int,
             intensity_level: int = 0):
        """
        8레이어 에너지볼 그리기 - pingfighter.py와 동일
        Layer 1: 외부 글로우 (3중)
        Layer 2: 회전 고리 점들 (3개 궤도)
        Layer 3: 고리 연결선
        Layer 4: 내부 에너지 구체
        Layer 5: 밝은 코어
        Layer 6: 상단 하이라이트
        Layer 7: 떠다니는 파티클
        Layer 8: 고리 위 밝은 점
        """
        # 인텐시티 기반 색상
        colors = INTENSITY_COLORS.get(intensity_level, INTENSITY_COLORS[0])
        glow_color = INTENSITY_GLOW_COLORS.get(intensity_level, INTENSITY_GLOW_COLORS[0])

        # 서피스 생성
        surf_size = radius * 6 + 20
        ball_surf = pygame.Surface((surf_size, surf_size), pygame.SRCALPHA)
        center = surf_size // 2

        # 펄스 효과
        pulse = 1.0 + math.sin(self.pulse_phase) * 0.1

        # Layer 1: 외부 글로우 (3중)
        for i, mult in enumerate([3.0, 2.2, 1.6]):
            glow_radius = int(radius * mult * pulse)
            alpha = int(30 - i * 8)
            glow_surf = pygame.Surface((glow_radius * 2, glow_radius * 2), pygame.SRCALPHA)
            for r in range(glow_radius, 0, -2):
                a = int(alpha * (r / glow_radius))
                pygame.draw.circle(glow_surf, (*glow_color[:3], a),
                                 (glow_radius, glow_radius), r)
            ball_surf.blit(glow_surf, (center - glow_radius, center - glow_radius),
                          special_flags=pygame.BLEND_ADD)

        # Layer 2 & 3: 회전 고리 (3개 궤도)
        ring_configs = [
            {'orbit': radius * 1.8, 'speed': 0.18, 'tilt': 0.3, 'points': 8},
            {'orbit': radius * 1.5, 'speed': -0.12, 'tilt': 0.5, 'points': 6},
            {'orbit': radius * 1.2, 'speed': 0.15, 'tilt': 0.2, 'points': 5},
        ]

        current_time = pygame.time.get_ticks()
        for config in ring_configs:
            base_angle = current_time * config['speed']
            tilt = math.sin(current_time * 0.001) * config['tilt']

            points = []
            for i in range(config['points']):
                angle = base_angle + (i * 2 * math.pi / config['points'])
                x = center + math.cos(angle) * config['orbit'] * math.cos(tilt)
                y = center + math.sin(angle) * config['orbit'] * (0.3 + 0.7 * abs(math.sin(tilt)))
                points.append((x, y))

                # 점 그리기
                point_size = 2 + int(math.sin(angle + base_angle) * 1)
                pygame.draw.circle(ball_surf, ENERGY_BALL_RING_COLOR,
                                 (int(x), int(y)), point_size)

            # 연결선 그리기
            if len(points) >= 2:
                pygame.draw.lines(ball_surf, (*ENERGY_BALL_RING_COLOR, 80), True,
                                [(int(p[0]), int(p[1])) for p in points], 1)

        # Layer 4: 내부 에너지 구체 (그라데이션)
        for r in range(int(radius * 1.2), 0, -1):
            ratio = r / (radius * 1.2)
            color = tuple(int(colors[0][i] * ratio + colors[1][i] * (1 - ratio))
                         for i in range(3))
            alpha = int(200 * ratio + 55)
            pygame.draw.circle(ball_surf, (*color, alpha), (center, center), r)

        # Layer 5: 밝은 코어
        core_radius = int(radius * 0.5)
        for r in range(core_radius, 0, -1):
            alpha = int(255 * (1 - r / core_radius))
            pygame.draw.circle(ball_surf, (*ENERGY_BALL_CORE_COLOR, alpha),
                             (center, center), r)

        # Layer 6: 상단 하이라이트
        highlight_offset = int(radius * 0.3)
        highlight_radius = int(radius * 0.25)
        pygame.draw.circle(ball_surf, (255, 255, 255, 180),
                          (center - highlight_offset, center - highlight_offset),
                          highlight_radius)

        # Layer 7: 떠다니는 파티클
        for particle in self.particles:
            px = center + math.cos(particle['angle'] + self.rotation_angle * 0.01) * particle['dist']
            py = center + math.sin(particle['angle'] + self.rotation_angle * 0.01) * particle['dist']
            alpha = int(255 * particle['life'])
            pygame.draw.circle(ball_surf, (*particle['color'], alpha),
                             (int(px), int(py)), int(particle['size']))

        # Layer 8: 고리 위 밝은 점 (노드)
        for i in range(4):
            angle = self.rotation_angle * 0.02 + i * math.pi / 2
            node_x = center + math.cos(angle) * radius * 1.3
            node_y = center + math.sin(angle) * radius * 1.3
            pygame.draw.circle(ball_surf, (200, 230, 255, 200),
                             (int(node_x), int(node_y)), 2)

        # 최종 블릿
        surface.blit(ball_surf, (cx - center, cy - center), special_flags=pygame.BLEND_ADD)


# ============================================================================
# 트레일 시스템 (pingfighter.py 라인 26767-27316 재현)
# ============================================================================

class TrailSystem:
    """공 트레일(잔상) 시스템"""

    def __init__(self):
        # 고스트 트레일 - pingfighter.py 라인 27146
        self.ghost_trail: List[Dict] = []
        self.GHOST_MAX_LENGTH = 5
        self.GHOST_FADE_SPEED = 0.75
        self.GHOST_MIN_DISTANCE = 6
        self.GHOST_INITIAL_ALPHA = 60

        # 레인보우 트레일 - pingfighter.py 라인 26767
        self.rainbow_trail: List[Dict] = []
        self.RAINBOW_MAX_LENGTH = 8
        self.RAINBOW_FADE_SPEED = 0.85
        self.RAINBOW_MIN_DISTANCE = 4

        # 에너지 파동 트레일 - pingfighter.py 라인 27266
        self.energy_wave_trail: List[Dict] = []
        self.ENERGY_WAVE_AMPLITUDE = 5.0
        self.ENERGY_WAVE_FREQUENCY = 0.3
        self.wave_phase = 0

        self.last_pos = (0, 0)

    def update(self, ball_x: float, ball_y: float, ball_vx: float, ball_vy: float,
               dt: float, intensity_level: int = 0):
        """트레일 업데이트"""
        # 거리 계산
        dx = ball_x - self.last_pos[0]
        dy = ball_y - self.last_pos[1]
        dist = math.sqrt(dx * dx + dy * dy)

        # 고스트 트레일 추가
        if dist >= self.GHOST_MIN_DISTANCE:
            self.ghost_trail.append({
                'x': ball_x, 'y': ball_y,
                'alpha': self.GHOST_INITIAL_ALPHA,
                'size': BALL_RADIUS,
                'age': 0
            })
            self.last_pos = (ball_x, ball_y)

        # 트레일 페이드아웃
        for trail in self.ghost_trail[:]:
            trail['alpha'] *= self.GHOST_FADE_SPEED
            trail['age'] += dt
            if trail['alpha'] < 5:
                self.ghost_trail.remove(trail)

        # 최대 길이 제한
        while len(self.ghost_trail) > self.GHOST_MAX_LENGTH:
            self.ghost_trail.pop(0)

        # 파동 페이즈 업데이트
        self.wave_phase += dt * 5

    def draw(self, surface: pygame.Surface, intensity_level: int = 0):
        """트레일 그리기"""
        colors = INTENSITY_COLORS.get(intensity_level, INTENSITY_COLORS[0])

        for i, trail in enumerate(self.ghost_trail):
            # 4레이어 그라데이션 잔상
            for layer in range(4):
                layer_mult = 1.0 - layer * 0.2
                size = int(trail['size'] * layer_mult)
                alpha = int(trail['alpha'] * layer_mult)

                if alpha > 0 and size > 0:
                    trail_surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                    color = colors[min(layer, len(colors) - 1)]
                    pygame.draw.circle(trail_surf, (*color, alpha), (size, size), size)
                    surface.blit(trail_surf, (int(trail['x'] - size), int(trail['y'] - size)),
                               special_flags=pygame.BLEND_ADD)

    def reset(self):
        """트레일 초기화"""
        self.ghost_trail.clear()
        self.rainbow_trail.clear()
        self.energy_wave_trail.clear()


# ============================================================================
# 파티클/이펙트 시스템 (pingfighter.py 라인 26559-26740 재현)
# ============================================================================

class EffectSystem:
    """에너지 폭발, 벽 충돌 등 이펙트 시스템"""

    def __init__(self):
        self.explosion_particles: List[Dict] = []
        self.wall_impacts: List[Dict] = []
        self.combo_particles: List[Dict] = []
        self.skill_effects: List[Dict] = []

        # 에너지 폭발 색상 - pingfighter.py 라인 26559
        self.EXPLOSION_COLORS = [
            (150, 200, 255), (100, 180, 255), (80, 160, 255),
            (200, 230, 255), (120, 200, 255)
        ]

    def create_energy_explosion(self, x: float, y: float, scale: float = 1.0,
                                intensity: float = 1.0):
        """패들 충돌 시 에너지 폭발 - pingfighter.py 라인 26559"""
        explosion_count = int(25 * scale * intensity)
        spark_count = int(15 * scale * intensity)

        for _ in range(explosion_count):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(2, 8) * scale
            self.explosion_particles.append({
                'x': x, 'y': y,
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed,
                'size': random.uniform(2, 5) * scale,
                'life': 1.0,
                'color': random.choice(self.EXPLOSION_COLORS),
                'type': 'explosion'
            })

        for _ in range(spark_count):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(4, 12) * scale
            self.explosion_particles.append({
                'x': x, 'y': y,
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed,
                'size': random.uniform(1, 2),
                'life': 0.5,
                'color': (255, 255, 200),
                'type': 'spark'
            })

    def create_wall_impact(self, x: float, y: float, direction: int):
        """벽 충돌 이펙트 - pingfighter.py 라인 26691"""
        self.wall_impacts.append({
            'x': x, 'y': y,
            'direction': direction,
            'flash_timer': 8,
            'particles': []
        })

        # 파티클 생성
        for _ in range(6):
            angle = random.uniform(-math.pi/3, math.pi/3)
            if direction < 0:
                angle += math.pi
            speed = random.uniform(3, 7)
            self.wall_impacts[-1]['particles'].append({
                'x': x, 'y': y,
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed,
                'life': 1.0
            })

    def create_combo_effect(self, x: float, y: float, combo: int):
        """콤보 이펙트 - pingfighter.py 라인 32454"""
        color = COMBO_COLORS.get(combo, (255, 255, 0))

        # 광선 효과 (콤보 3 이상)
        if combo >= 3:
            ray_count = min(combo * 2, 12)
            for i in range(ray_count):
                angle = (i / ray_count) * math.pi * 2
                self.combo_particles.append({
                    'x': x, 'y': y,
                    'angle': angle,
                    'length': 0,
                    'max_length': 50 + combo * 10,
                    'life': 1.0,
                    'color': color,
                    'type': 'ray'
                })

        # 파티클
        for _ in range(combo * 3):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(2, 6)
            self.combo_particles.append({
                'x': x, 'y': y,
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed,
                'size': 3 + combo // 2,
                'life': 1.0,
                'color': color,
                'type': 'particle'
            })

    def create_skill_effect(self, x: float, y: float, skill_type: str, direction: int = 0):
        """스킬 발동 이펙트"""
        if skill_type == 'short_shot':
            # 수직 광선 효과
            self.skill_effects.append({
                'x': x, 'y': y,
                'type': 'short_shot',
                'timer': 30,
                'direction': direction
            })
        elif skill_type == 'drive':
            # 커브 궤적 표시
            self.skill_effects.append({
                'x': x, 'y': y,
                'type': 'drive',
                'timer': 20,
                'direction': direction
            })
        elif skill_type == 'power_smash':
            # 파워 이펙트
            self.skill_effects.append({
                'x': x, 'y': y,
                'type': 'power_smash',
                'timer': 40,
                'direction': direction
            })

    def update(self, dt: float):
        """모든 이펙트 업데이트"""
        # 폭발 파티클 업데이트
        for particle in self.explosion_particles[:]:
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            particle['vx'] *= 0.95
            particle['vy'] *= 0.95
            particle['life'] -= dt * 2
            if particle['life'] <= 0:
                self.explosion_particles.remove(particle)

        # 벽 충돌 업데이트
        for impact in self.wall_impacts[:]:
            impact['flash_timer'] -= 1
            for p in impact['particles']:
                p['x'] += p['vx']
                p['y'] += p['vy']
                p['life'] -= dt * 3
            impact['particles'] = [p for p in impact['particles'] if p['life'] > 0]
            if impact['flash_timer'] <= 0 and not impact['particles']:
                self.wall_impacts.remove(impact)

        # 콤보 파티클 업데이트
        for particle in self.combo_particles[:]:
            if particle['type'] == 'ray':
                particle['length'] = min(particle['length'] + 10, particle['max_length'])
            else:
                particle['x'] += particle.get('vx', 0)
                particle['y'] += particle.get('vy', 0)
            particle['life'] -= dt * 1.5
            if particle['life'] <= 0:
                self.combo_particles.remove(particle)

        # 스킬 이펙트 업데이트
        for effect in self.skill_effects[:]:
            effect['timer'] -= 1
            if effect['timer'] <= 0:
                self.skill_effects.remove(effect)

    def draw(self, surface: pygame.Surface):
        """모든 이펙트 그리기"""
        # 폭발 파티클
        for particle in self.explosion_particles:
            alpha = int(255 * particle['life'])
            size = int(particle['size'] * particle['life'])
            if size > 0 and alpha > 0:
                surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                pygame.draw.circle(surf, (*particle['color'], alpha), (size, size), size)
                surface.blit(surf, (int(particle['x'] - size), int(particle['y'] - size)),
                           special_flags=pygame.BLEND_ADD)

        # 벽 충돌
        for impact in self.wall_impacts:
            if impact['flash_timer'] > 0:
                flash_alpha = int(200 * (impact['flash_timer'] / 8))
                flash_surf = pygame.Surface((40, 40), pygame.SRCALPHA)
                pygame.draw.circle(flash_surf, (255, 255, 255, flash_alpha), (20, 20), 15)
                surface.blit(flash_surf, (int(impact['x'] - 20), int(impact['y'] - 20)),
                           special_flags=pygame.BLEND_ADD)

        # 콤보 파티클
        for particle in self.combo_particles:
            alpha = int(255 * particle['life'])
            if particle['type'] == 'ray':
                # 광선 그리기
                end_x = particle['x'] + math.cos(particle['angle']) * particle['length']
                end_y = particle['y'] + math.sin(particle['angle']) * particle['length']
                pygame.draw.line(surface, (*particle['color'], alpha),
                               (int(particle['x']), int(particle['y'])),
                               (int(end_x), int(end_y)), 2)
            else:
                size = int(particle['size'] * particle['life'])
                if size > 0:
                    surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                    pygame.draw.circle(surf, (*particle['color'], alpha), (size, size), size)
                    surface.blit(surf, (int(particle['x'] - size), int(particle['y'] - size)))

        # 스킬 이펙트
        for effect in self.skill_effects:
            alpha = int(200 * (effect['timer'] / 40))
            if effect['type'] == 'short_shot':
                # 수직 광선
                surf = pygame.Surface((20, 100), pygame.SRCALPHA)
                pygame.draw.rect(surf, (100, 200, 255, alpha), (5, 0, 10, 100))
                surface.blit(surf, (int(effect['x'] - 10), int(effect['y'] - 50)))
            elif effect['type'] == 'drive':
                # 커브 표시
                color = (100, 255, 100, alpha)
                pygame.draw.arc(surface, color,
                              (int(effect['x'] - 30), int(effect['y'] - 30), 60, 60),
                              0, math.pi, 3)
            elif effect['type'] == 'power_smash':
                # 파워 링
                for i in range(3):
                    r = 20 + i * 15 + (40 - effect['timer'])
                    a = max(0, alpha - i * 50)
                    if a > 0:
                        pygame.draw.circle(surface, (255, 150, 50, a),
                                         (int(effect['x']), int(effect['y'])), r, 2)


# ============================================================================
# 공 생성 애니메이션 (pingfighter.py effects/ball_spawn_animation.py 재현)
# ============================================================================

class BallSpawnAnimation:
    """
    3페이즈 공 생성 애니메이션 (총 8초)
    Phase 1: 에너지 응축 (4초)
    Phase 2: 공 부양 (1.5초)
    Phase 3: 서브 이동 (2.5초)

    멀티플레이어에서는 간소화된 버전 사용 (3초)
    """

    def __init__(self, screen_width: int, screen_height: int):
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.active = False
        self.complete = False
        self.timer = 0
        self.total_duration = 3.0  # 멀티플레이어용 간소화 (3초)

        self.center_x = screen_width // 2
        self.center_y = screen_height // 2
        self.ball_x = self.center_x
        self.ball_y = self.center_y
        self.ball_visible = False
        self.ball_scale = 0.0
        self.ball_alpha = 0

        self.target_x = self.center_x
        self.target_y = self.center_y
        self.is_player_serve = True

        # 파티클
        self.quantum_particles: List[Dict] = []
        self.energy_rings: List[Dict] = []
        self.lightning_bolts: List[Dict] = []

    def start(self, is_player_serve: bool, player_y: float, opponent_y: float):
        """애니메이션 시작"""
        self.active = True
        self.complete = False
        self.timer = 0
        self.is_player_serve = is_player_serve

        self.ball_x = self.center_x
        self.ball_y = self.center_y
        self.ball_visible = False
        self.ball_scale = 0.0
        self.ball_alpha = 0

        # 서브 위치 설정
        if is_player_serve:
            self.target_y = player_y - 30
        else:
            self.target_y = opponent_y + 30
        self.target_x = self.center_x

        # 양자 파티클 초기화
        self.quantum_particles.clear()
        for _ in range(50):
            angle = random.uniform(0, math.pi * 2)
            dist = random.uniform(100, 200)
            self.quantum_particles.append({
                'angle': angle,
                'dist': dist,
                'speed': random.uniform(1, 3),
                'size': random.uniform(2, 4),
                'color': random.choice([
                    (100, 150, 255), (150, 100, 255), (255, 100, 200)
                ])
            })

        self.energy_rings.clear()
        self.lightning_bolts.clear()

    def update(self, dt: float) -> Tuple[float, float]:
        """애니메이션 업데이트, 현재 공 위치 반환"""
        if not self.active:
            return self.ball_x, self.ball_y

        self.timer += dt
        progress = min(1.0, self.timer / self.total_duration)

        # Phase 1: 응축 (0~1.5초)
        if progress < 0.5:
            phase_progress = progress / 0.5

            # 파티클 수렴
            for particle in self.quantum_particles:
                particle['dist'] *= (1 - phase_progress * 0.03)
                particle['angle'] += particle['speed'] * dt * (1 + phase_progress * 2)

            # 번개 생성
            if random.random() < phase_progress * 0.3:
                self._spawn_lightning()

        # Phase 2: 공 출현 (1.5~2초)
        elif progress < 0.67:
            phase_progress = (progress - 0.5) / 0.17

            self.ball_visible = True
            self.ball_scale = min(1.0, 0.3 + phase_progress * 0.7)
            self.ball_alpha = min(255, int(phase_progress * 400))

            # 부양 효과
            levitate = math.sin(self.timer * 6) * 10
            self.ball_y = self.center_y + levitate

        # Phase 3: 이동 (2~3초)
        else:
            phase_progress = (progress - 0.67) / 0.33

            self.ball_scale = 1.0
            self.ball_alpha = 255

            # 목표 위치로 이동
            self.ball_x = self.center_x + (self.target_x - self.center_x) * phase_progress
            self.ball_y = self.center_y + (self.target_y - self.center_y) * phase_progress

            # 에너지 링 방출
            if random.random() < 0.2:
                self.energy_rings.append({
                    'x': self.ball_x, 'y': self.ball_y,
                    'radius': 5, 'alpha': 200
                })

        # 에너지 링 업데이트
        for ring in self.energy_rings[:]:
            ring['radius'] += 3
            ring['alpha'] -= 5
            if ring['alpha'] <= 0:
                self.energy_rings.remove(ring)

        # 번개 업데이트
        for bolt in self.lightning_bolts[:]:
            bolt['life'] -= dt
            if bolt['life'] <= 0:
                self.lightning_bolts.remove(bolt)

        # 완료 체크
        if progress >= 1.0:
            self.complete = True
            self.active = False

        return self.ball_x, self.ball_y

    def _spawn_lightning(self):
        """번개 생성"""
        angle = random.uniform(0, math.pi * 2)
        self.lightning_bolts.append({
            'start_angle': angle,
            'segments': self._generate_lightning_segments(angle),
            'life': 0.2,
            'color': random.choice([
                (150, 200, 255), (200, 150, 255), (255, 255, 200)
            ])
        })

    def _generate_lightning_segments(self, start_angle: float) -> List[Tuple[float, float]]:
        """번개 세그먼트 생성"""
        segments = []
        x, y = self.center_x, self.center_y
        dist = random.uniform(80, 150)

        for i in range(5):
            next_x = x + math.cos(start_angle) * (dist / 5)
            next_y = y + math.sin(start_angle) * (dist / 5)
            next_x += random.uniform(-10, 10)
            next_y += random.uniform(-10, 10)
            segments.append((x, y, next_x, next_y))
            x, y = next_x, next_y

        return segments

    def draw(self, surface: pygame.Surface, ball_color: Tuple[int, int, int] = (180, 220, 255)):
        """애니메이션 그리기"""
        if not self.active:
            return

        # 양자 파티클
        for particle in self.quantum_particles:
            x = self.center_x + math.cos(particle['angle']) * particle['dist']
            y = self.center_y + math.sin(particle['angle']) * particle['dist']
            pygame.draw.circle(surface, particle['color'], (int(x), int(y)), int(particle['size']))

        # 번개
        for bolt in self.lightning_bolts:
            alpha = int(255 * (bolt['life'] / 0.2))
            for seg in bolt['segments']:
                pygame.draw.line(surface, (*bolt['color'], alpha),
                               (int(seg[0]), int(seg[1])),
                               (int(seg[2]), int(seg[3])), 2)

        # 에너지 링
        for ring in self.energy_rings:
            if ring['alpha'] > 0:
                pygame.draw.circle(surface, (100, 180, 255, ring['alpha']),
                                 (int(ring['x']), int(ring['y'])),
                                 int(ring['radius']), 2)

        # 공 (부양 중)
        if self.ball_visible:
            # 글로우
            glow_radius = int(BALL_RADIUS * 2 * self.ball_scale)
            glow_surf = pygame.Surface((glow_radius * 2, glow_radius * 2), pygame.SRCALPHA)
            for r in range(glow_radius, 0, -2):
                a = int(self.ball_alpha * 0.3 * (r / glow_radius))
                pygame.draw.circle(glow_surf, (*ball_color, a), (glow_radius, glow_radius), r)
            surface.blit(glow_surf, (int(self.ball_x - glow_radius), int(self.ball_y - glow_radius)),
                        special_flags=pygame.BLEND_ADD)

            # 공 본체
            radius = int(BALL_RADIUS * self.ball_scale)
            pygame.draw.circle(surface, ball_color, (int(self.ball_x), int(self.ball_y)), radius)

            # 하이라이트
            hl_offset = int(radius * 0.3)
            pygame.draw.circle(surface, (255, 255, 255),
                             (int(self.ball_x - hl_offset), int(self.ball_y - hl_offset)),
                             int(radius * 0.2))


# ============================================================================
# 스매셔 플레이어 클래스 (완전 재구현)
# ============================================================================

class SmasherPlayer:
    """스매셔 캐릭터 - 싱글플레이어와 동일한 스킬/물리 시스템"""

    def __init__(self, player_num: int, is_top: bool, screen_width: int, screen_height: int):
        self.num = player_num
        self.is_top = is_top
        self.screen_width = screen_width
        self.screen_height = screen_height

        # 위치/크기
        self.width = PADDLE_WIDTH
        self.height = PADDLE_HEIGHT
        self.x = screen_width // 2 - self.width // 2

        if is_top:
            self.y = 60
        else:
            self.y = screen_height - 80

        self.rect = pygame.Rect(self.x, self.y, self.width, self.height)

        # 이동
        self.speed = PADDLE_SPEED
        self.vx = 0

        # 게이지
        self.gauge = 0
        self.displayed_gauge = 0.0
        self.max_gauge = GAUGE_MAX

        # 콤보
        self.combo = 0
        self.combo_timer = 0

        # 대시
        self.dash_cooldown = 0
        self.is_dashing = False
        self.dash_timer = 0

        # 스킬 상태 - 쇼트
        self.short_shot_active = False
        self.short_shot_timer = 0
        self.short_shot_vertical_timer = 0
        self.short_shot_speed = 0.0
        self.short_shot_target_angle = 0.0
        self.short_shot_current_angle = 0.0
        self.short_shot_curve_started = False
        self.short_shot_curve_frames = 0

        # 스킬 상태 - 드라이브
        self.drive_active = False
        self.drive_direction = 0
        self.perfect_timing_active = False
        self.perfect_timing_window = 0

        # 스킬 상태 - 파워스매싱
        self.power_smash_active = False
        self.power_smash_direction = 0
        self.power_smash_timer = 0
        self.power_smash_arc_strength = 0.0

        # 넉백
        self.knockback_vel = 0.0

        # 키 바인딩
        self.keys = KeyBindings(player_num == 1, is_top)

        # 점수
        self.score = 0

        # 색상
        self.color = (0, 150, 255) if player_num == 1 else (255, 100, 100)
        self.glow_color = (30, 100, 200) if player_num == 1 else (200, 50, 50)

    def update(self, keys_pressed: Dict[int, bool], dt: float):
        """플레이어 업데이트"""
        # 게이지 애니메이션 - pingfighter.py 라인 50412-50425
        gauge_speed = 0.1
        if self.displayed_gauge < self.gauge:
            self.displayed_gauge += (self.gauge - self.displayed_gauge) * gauge_speed
            if self.displayed_gauge > self.gauge - 1:
                self.displayed_gauge = self.gauge
        elif self.displayed_gauge > self.gauge:
            self.displayed_gauge -= (self.displayed_gauge - self.gauge) * gauge_speed
            if self.displayed_gauge < self.gauge + 1:
                self.displayed_gauge = self.gauge

        # 콤보 타이머
        if self.combo_timer > 0:
            self.combo_timer -= 1
            if self.combo_timer <= 0:
                self.combo = 0

        # 대시 쿨다운
        if self.dash_cooldown > 0:
            self.dash_cooldown -= 1

        # 넉백 감쇠
        if abs(self.knockback_vel) > 0.1:
            self.x += self.knockback_vel
            self.knockback_vel *= 0.85
        else:
            self.knockback_vel = 0

        # 이동 처리
        self.vx = 0
        move_speed = self.speed

        # 대시 체크
        if keys_pressed.get(self.keys.dash, False) and self.dash_cooldown <= 0:
            self.is_dashing = True
            self.dash_timer = 10
            self.dash_cooldown = DASH_COOLDOWN
            move_speed += DASH_SPEED_BOOST

        if self.dash_timer > 0:
            self.dash_timer -= 1
            move_speed = self.speed + DASH_SPEED_BOOST
        else:
            self.is_dashing = False

        if keys_pressed.get(self.keys.left, False):
            self.vx = -move_speed
        if keys_pressed.get(self.keys.right, False):
            self.vx = move_speed

        self.x += self.vx

        # 화면 경계
        self.x = max(0, min(self.screen_width - self.width, self.x))
        self.rect.x = int(self.x)
        self.rect.y = int(self.y)

        # 퍼펙트 타이밍 윈도우 감소
        if self.perfect_timing_window > 0:
            self.perfect_timing_window -= 1
            if self.perfect_timing_window <= 0:
                self.perfect_timing_active = False

    def charge_gauge(self, amount: int, is_combo: bool = False):
        """게이지 충전 - pingfighter.py 라인 8886-8899 콤보 보너스"""
        if is_combo:
            self.combo += 1
            self.combo_timer = 180  # 3초

            # 콤보 보너스 적용
            bonus_percent = COMBO_GAUGE_BONUS.get(min(self.combo, 6), COMBO_MAX_BONUS)
            bonus = int(amount * bonus_percent / 100)
            amount += bonus

        self.gauge = min(self.max_gauge, self.gauge + amount)

    def consume_gauge(self, amount: int) -> bool:
        """게이지 소모"""
        if self.gauge >= amount:
            self.gauge -= amount
            return True
        return False

    def can_use_skill(self, cost: int) -> bool:
        """스킬 사용 가능 여부"""
        return self.gauge >= cost

    def activate_short_shot(self, ball_vx: float, ball_vy: float,
                           target_x: float, target_y: float) -> Tuple[float, float, float]:
        """
        쇼트 발동 - pingfighter.py 라인 84300-84365
        Returns: (new_vx, new_vy, speed)
        """
        if not self.can_use_skill(SHORT_SHOT_GAUGE_COST):
            return ball_vx, ball_vy, 0

        self.consume_gauge(SHORT_SHOT_GAUGE_COST)

        self.short_shot_active = True
        self.short_shot_timer = SHORT_SHOT_TOTAL_FRAMES
        self.short_shot_vertical_timer = SHORT_SHOT_VERTICAL_FRAMES
        self.short_shot_curve_started = False
        self.short_shot_curve_frames = 0

        # 현재 속도 계산
        current_speed = math.sqrt(ball_vx * ball_vx + ball_vy * ball_vy)
        self.short_shot_speed = current_speed * SHORT_SHOT_SPEED_MULTIPLIER

        # 수직 방향 (위 또는 아래)
        vertical_dir = -1 if not self.is_top else 1
        vertical_angle = math.pi / 2 * vertical_dir

        # 목표 각도 계산
        ball_x = self.rect.centerx
        ball_y = self.rect.centery + (30 * vertical_dir)

        dx = target_x - ball_x
        dy = target_y - ball_y

        if abs(dy) < 0.1:
            dy = -0.1 * vertical_dir

        raw_target_angle = math.atan2(dy, dx)

        # 각도 제한 (±45도)
        max_angle = math.radians(SHORT_SHOT_MAX_ANGLE_DEG)
        angle_diff = raw_target_angle - vertical_angle

        if abs(angle_diff) > max_angle:
            angle_diff = max_angle if angle_diff > 0 else -max_angle

        self.short_shot_target_angle = vertical_angle + angle_diff
        self.short_shot_current_angle = vertical_angle

        # 초기 속도 (수직)
        new_vx = 0
        new_vy = self.short_shot_speed * vertical_dir

        return new_vx, new_vy, self.short_shot_speed

    def update_short_shot(self, ball_vx: float, ball_vy: float,
                         ball_y: float, target_y: float) -> Tuple[float, float]:
        """쇼트 업데이트 - pingfighter.py 라인 86944-87015"""
        if not self.short_shot_active:
            return ball_vx, ball_vy

        self.short_shot_timer -= 1

        if self.short_shot_timer <= 0:
            self.short_shot_active = False
            return ball_vx, ball_vy

        # 수직 비행 페이즈
        if self.short_shot_vertical_timer > 0:
            self.short_shot_vertical_timer -= 1
            # X 감속
            ball_vx *= 0.94

        # 곡선 전환 조건
        vertical_dir = -1 if not self.is_top else 1
        trigger_y = target_y - SHORT_SHOT_CURVE_TRIGGER_OFFSET * vertical_dir

        should_curve = (vertical_dir < 0 and ball_y <= trigger_y) or \
                      (vertical_dir > 0 and ball_y >= trigger_y)

        if not self.short_shot_curve_started and should_curve:
            self.short_shot_curve_started = True
            self.short_shot_curve_frames = 0

        # 곡선 실행
        if self.short_shot_curve_started:
            self.short_shot_curve_frames += 1
            curve_duration = 12
            blend = min(1.0, self.short_shot_curve_frames / curve_duration)

            # 각도 보간
            vertical_angle = math.pi / 2 * vertical_dir
            self.short_shot_current_angle = vertical_angle * (1 - blend) + \
                                           self.short_shot_target_angle * blend

            # 속도 업데이트
            ball_vx = math.cos(self.short_shot_current_angle) * self.short_shot_speed
            ball_vy = math.sin(self.short_shot_current_angle) * self.short_shot_speed

            if self.short_shot_curve_frames >= curve_duration:
                self.short_shot_curve_started = False

        return ball_vx, ball_vy

    def activate_drive(self, direction: int) -> Tuple[float, float]:
        """
        드라이브 발동 - pingfighter.py 라인 84476-84549
        Returns: (spin_strength, spin_direction)
        """
        if not self.can_use_skill(DRIVE_GAUGE_COST):
            return 0.0, 0

        if not self.perfect_timing_active:
            return 0.0, 0

        self.consume_gauge(DRIVE_GAUGE_COST)

        self.drive_active = True
        self.drive_direction = direction

        # 스핀 계산
        spin_strength = DRIVE_BASE_SPIN
        spin_strength = min(DRIVE_SPIN_CAP, spin_strength)

        return spin_strength, direction

    def activate_power_smash(self, direction: int, ball_speed: float) -> Tuple[float, float, float]:
        """
        파워스매싱 발동 - pingfighter.py 라인 97385-97495
        Returns: (arc_strength, gravity, speed_mult)
        """
        if not self.can_use_skill(POWER_SMASH_GAUGE_COST):
            return 0.0, 0.0, 1.0

        self.consume_gauge(POWER_SMASH_GAUGE_COST)

        self.power_smash_active = True
        self.power_smash_direction = direction
        self.power_smash_timer = 120  # 2초

        # 아크 강도 설정
        if direction == -1:  # 왼쪽
            self.power_smash_arc_strength = -POWER_SMASH_ARC_STRENGTH + random.uniform(-0.1, 0.1)
        elif direction == 1:  # 오른쪽
            self.power_smash_arc_strength = POWER_SMASH_ARC_STRENGTH + random.uniform(-0.1, 0.1)
        else:
            self.power_smash_arc_strength = 0.0

        return self.power_smash_arc_strength, POWER_SMASH_GRAVITY, 2.0

    def update_power_smash(self, ball_vx: float, ball_vy: float,
                          elapsed_time: float) -> Tuple[float, float]:
        """파워스매싱 포물선 업데이트 - pingfighter.py 라인 86346-86477"""
        if not self.power_smash_active:
            return ball_vx, ball_vy

        self.power_smash_timer -= 1
        if self.power_smash_timer <= 0:
            self.power_smash_active = False
            return ball_vx, ball_vy

        # 수평 이동
        horizontal_decay = max(0.8, 1.0 - elapsed_time * 0.05)
        chaos_factor = math.sin(elapsed_time * 5.0) * 0.05
        horizontal_force = self.power_smash_arc_strength * horizontal_decay * (0.5 + chaos_factor * 0.2)
        ball_vx += horizontal_force

        # 수직 이동 (포물선)
        if elapsed_time < 1.8:  # 상승
            vertical_dir = -1 if not self.is_top else 1
            base_lift = POWER_SMASH_GRAVITY * 1.5 * (1.8 - elapsed_time) / 1.8
            ball_vy -= base_lift * vertical_dir
        else:  # 하강
            vertical_dir = 1 if not self.is_top else -1
            base_pull = POWER_SMASH_GRAVITY * 1.2 * (elapsed_time - 1.8)
            ball_vy += base_pull * vertical_dir

        return ball_vx, ball_vy

    def draw(self, surface: pygame.Surface, paddle_surface: Optional[pygame.Surface] = None):
        """플레이어 그리기"""
        # 글로우 효과
        glow_surf = pygame.Surface((self.width + 20, self.height + 20), pygame.SRCALPHA)
        for i in range(3):
            alpha = 30 - i * 8
            inflate = (3 - i) * 3
            pygame.draw.rect(glow_surf, (*self.glow_color, alpha),
                           (10 - inflate, 10 - inflate,
                            self.width + inflate * 2, self.height + inflate * 2),
                           border_radius=5)
        surface.blit(glow_surf, (self.rect.x - 10, self.rect.y - 10),
                    special_flags=pygame.BLEND_ADD)

        # 패들 본체
        if paddle_surface:
            surface.blit(paddle_surface, self.rect.topleft)
        else:
            # 그라데이션 패들
            for i in range(self.height):
                ratio = i / self.height
                color = tuple(int(self.color[j] * (1 - ratio * 0.3)) for j in range(3))
                pygame.draw.line(surface, color,
                               (self.rect.x, self.rect.y + i),
                               (self.rect.x + self.width, self.rect.y + i))

            # 테두리
            pygame.draw.rect(surface, (255, 255, 255), self.rect, 2, border_radius=3)

        # 대시 이펙트
        if self.is_dashing:
            dash_surf = pygame.Surface((self.width + 30, self.height + 10), pygame.SRCALPHA)
            pygame.draw.rect(dash_surf, (*self.color, 100),
                           (0, 5, self.width + 30, self.height))
            surface.blit(dash_surf, (self.rect.x - 15, self.rect.y - 5),
                        special_flags=pygame.BLEND_ADD)


# ============================================================================
# 공 클래스 (완전 재구현)
# ============================================================================

class Ball:
    """공 - 싱글플레이어와 동일한 물리/렌더링"""

    def __init__(self, screen_width: int, screen_height: int):
        self.screen_width = screen_width
        self.screen_height = screen_height

        self.radius = BALL_RADIUS
        self.x = screen_width // 2
        self.y = screen_height // 2
        self.vx = 0.0
        self.vy = 0.0

        self.rect = pygame.Rect(self.x - self.radius, self.y - self.radius,
                               self.radius * 2, self.radius * 2)

        # 물리
        self.base_speed = BALL_BASE_SPEED
        self.current_speed = 0.0

        # 스핀
        self.spin_strength = 0.0
        self.spin_direction = 0
        self.spin_decay = 0.98

        # 인텐시티
        self.intensity_level = 0
        self.rally_count = 0

        # 상태
        self.active = False
        self.last_hit_by = None  # 'p1' or 'p2'

        # 렌더러
        self.renderer = EnergyBallRenderer()
        self.trail = TrailSystem()

    def reset(self, serve_player: 'SmasherPlayer'):
        """공 리셋"""
        self.x = self.screen_width // 2
        self.y = serve_player.rect.centery + (30 if serve_player.is_top else -30)
        self.vx = 0
        self.vy = 0
        self.current_speed = 0
        self.active = False
        self.spin_strength = 0
        self.spin_direction = 0
        self.intensity_level = 0
        self.rally_count = 0
        self.last_hit_by = None
        self.trail.reset()
        self.update_rect()

    def serve(self, direction: int):
        """서브"""
        self.active = True
        speed = self.base_speed
        self.vx = random.uniform(-1, 1)
        self.vy = speed * direction
        self.current_speed = speed

    def update(self, dt: float):
        """공 업데이트"""
        if not self.active:
            return

        # 스핀 적용 - pingfighter.py 라인 86661-86671
        if abs(self.spin_strength) > 0.01:
            spin_force = self.spin_strength * self.spin_direction * 3.5
            self.vx += spin_force * dt * 60
            self.spin_strength *= self.spin_decay
            if abs(self.spin_strength) < 0.05:
                self.spin_strength = 0

        # 위치 업데이트
        self.x += self.vx
        self.y += self.vy

        # 현재 속도 계산
        self.current_speed = math.sqrt(self.vx * self.vx + self.vy * self.vy)

        # 인텐시티 계산 - pingfighter.py 라인 26155
        self._update_intensity()

        # 트레일 업데이트
        self.trail.update(self.x, self.y, self.vx, self.vy, dt, self.intensity_level)

        # 렌더러 업데이트
        self.renderer.update(dt)

        self.update_rect()

    def _update_intensity(self):
        """인텐시티 레벨 업데이트"""
        speed = self.current_speed
        for i, threshold in enumerate(INTENSITY_SPEED_THRESHOLDS):
            if speed < threshold:
                self.intensity_level = i
                return
        self.intensity_level = len(INTENSITY_SPEED_THRESHOLDS)

    def update_rect(self):
        """충돌 박스 업데이트"""
        self.rect.centerx = int(self.x)
        self.rect.centery = int(self.y)

    def wall_bounce(self) -> int:
        """벽 충돌 처리, 충돌 방향 반환 (-1: 왼쪽, 1: 오른쪽, 0: 없음)"""
        direction = 0

        if self.x - self.radius <= 0:
            self.x = self.radius
            self.vx = abs(self.vx)
            direction = -1
        elif self.x + self.radius >= self.screen_width:
            self.x = self.screen_width - self.radius
            self.vx = -abs(self.vx)
            direction = 1

        return direction

    def check_score(self) -> int:
        """점수 체크 (상단=1, 하단=2, 없음=0)"""
        if self.y - self.radius <= 0:
            return 1  # 상단 통과 (하단 플레이어 득점)
        elif self.y + self.radius >= self.screen_height:
            return 2  # 하단 통과 (상단 플레이어 득점)
        return 0

    def paddle_collision(self, player: SmasherPlayer, rel_x: float) -> Tuple[float, float, float]:
        """
        패들 충돌 처리 - pingfighter.py 라인 84329-84383
        rel_x: 패들 중심 기준 상대 위치 (-1.0 ~ 1.0)
        Returns: (new_vx, new_vy, boost_multiplier)
        """
        # 각도 계산 - pingfighter.py 라인 84329
        rel_x = max(-1.0, min(1.0, rel_x))
        angle = rel_x * (math.pi / 3)  # ±60도

        # 방향
        direction = -1 if not player.is_top else 1

        # 속도 계산
        speed = self.current_speed

        # 각도 기반 부스트 - pingfighter.py 라인 84366-84392
        ball_angle_deg = 90
        if abs(self.vx) > 0.1:
            ball_angle_rad = math.atan2(abs(self.vy), abs(self.vx))
            ball_angle_deg = math.degrees(ball_angle_rad)

        if ball_angle_deg >= 90:
            angle_boost = 2.0
        elif ball_angle_deg >= 80:
            angle_boost = 2.0 + 0.2 * ((90 - ball_angle_deg) / 10)
        elif ball_angle_deg >= 70:
            angle_boost = 2.2 + 0.2 * ((80 - ball_angle_deg) / 10)
        elif ball_angle_deg >= 60:
            angle_boost = 2.4 + 0.2 * ((70 - ball_angle_deg) / 10)
        elif ball_angle_deg >= 45:
            angle_boost = 2.6 + 0.2 * ((60 - ball_angle_deg) / 15)
        else:
            angle_boost = 2.8

        # 기본 가속 - pingfighter.py 라인 84633-84700
        base_mult = random.uniform(1.024, 1.084)
        speed *= base_mult

        # 방향 벡터
        vector = pygame.math.Vector2(0, direction).rotate_rad(angle)

        # 최소 발사각 보정 - pingfighter.py 라인 84739-84748
        min_angle_deg = 25
        min_vertical_ratio = math.sin(math.radians(min_angle_deg))

        vertical_ratio = abs(vector.y)
        if vertical_ratio < min_vertical_ratio:
            horizontal_ratio = math.sqrt(1.0 - min_vertical_ratio ** 2)
            vector.y = math.copysign(min_vertical_ratio, vector.y)
            vector.x = math.copysign(horizontal_ratio, vector.x) if abs(vector.x) > 0.01 else 0
            vector = vector.normalize()

        new_vx = speed * vector.x
        new_vy = speed * vector.y

        return new_vx, new_vy, base_mult

    def draw(self, surface: pygame.Surface):
        """공 그리기"""
        if not self.active:
            return

        # 트레일 먼저
        self.trail.draw(surface, self.intensity_level)

        # 에너지볼
        self.renderer.draw(surface, int(self.x), int(self.y),
                          self.radius, self.intensity_level)


# ============================================================================
# 게이지 바 UI (pingfighter.py 라인 55784-56780 재현)
# ============================================================================

class GaugeBar:
    """플레이어 게이지 바 UI"""

    def __init__(self, player: SmasherPlayer, screen_width: int, screen_height: int):
        self.player = player

        # 위치 설정
        self.width = 14
        self.height = 100

        if player.is_top:
            self.x = screen_width - 40
            self.y = 50
        else:
            self.x = screen_width - 40
            self.y = screen_height - 200

        # 색상
        self.frame_color = (40, 80, 140)
        self.bg_color = (20, 30, 50)

    def draw(self, surface: pygame.Surface, font: pygame.font.Font):
        """게이지 바 그리기 - pingfighter.py 라인 55784-56780"""
        # 프레임
        frame_rect = pygame.Rect(self.x - 3, self.y - 3, self.width + 6, self.height + 6)
        pygame.draw.rect(surface, self.frame_color, frame_rect, border_radius=3)

        # 배경
        bg_rect = pygame.Rect(self.x, self.y, self.width, self.height)
        pygame.draw.rect(surface, self.bg_color, bg_rect)

        # 게이지 채우기
        displayed = self.player.displayed_gauge
        max_gauge = self.player.max_gauge
        fill_ratio = displayed / max_gauge
        fill_height = int(self.height * fill_ratio)

        if fill_height > 0:
            # 색상 결정 - pingfighter.py 라인 56443
            if displayed < 150:
                color = (120, 120, 180)
            elif displayed < 250:
                color = (100, 150, 255)
            elif displayed < 350:
                color = (150, 200, 255)
            else:
                color = (200, 230, 255)

            # 그라데이션 채우기
            fill_rect = pygame.Rect(self.x, self.y + self.height - fill_height,
                                   self.width, fill_height)
            for i in range(fill_height):
                ratio = i / fill_height
                c = tuple(int(color[j] * (0.7 + ratio * 0.3)) for j in range(3))
                pygame.draw.line(surface, c,
                               (fill_rect.x, fill_rect.y + fill_height - i - 1),
                               (fill_rect.x + self.width, fill_rect.y + fill_height - i - 1))

        # 테두리
        pygame.draw.rect(surface, (100, 140, 200), bg_rect, 1)

        # 값 표시
        text = f"{int(displayed)}"
        text_surf = font.render(text, True, (255, 255, 255))
        text_rect = text_surf.get_rect(centerx=self.x + self.width // 2,
                                       top=self.y + self.height + 5)
        surface.blit(text_surf, text_rect)

        # 플레이어 번호
        p_text = f"P{self.player.num}"
        p_surf = font.render(p_text, True, self.player.color)
        p_rect = p_surf.get_rect(centerx=self.x + self.width // 2,
                                bottom=self.y - 5)
        surface.blit(p_surf, p_rect)


# ============================================================================
# 콤보 표시 UI (pingfighter.py 라인 32454-32602 재현)
# ============================================================================

class ComboDisplay:
    """콤보 표시 UI"""

    def __init__(self):
        self.active = False
        self.timer = 0
        self.x = 0
        self.y = 0
        self.combo = 0
        self.particles: List[Dict] = []

    def show(self, x: float, y: float, combo: int):
        """콤보 표시"""
        if combo < 2:
            return

        self.active = True
        self.timer = 60
        self.x = x
        self.y = y
        self.combo = combo

        # 파티클 생성
        color = COMBO_COLORS.get(combo, (255, 255, 0))
        for _ in range(combo * 2):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(2, 5)
            self.particles.append({
                'x': x, 'y': y,
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed,
                'life': 1.0,
                'color': color
            })

    def update(self, dt: float):
        """업데이트"""
        if not self.active:
            return

        self.timer -= 1
        if self.timer <= 0:
            self.active = False
            self.particles.clear()
            return

        for p in self.particles[:]:
            p['x'] += p['vx']
            p['y'] += p['vy']
            p['life'] -= dt * 2
            if p['life'] <= 0:
                self.particles.remove(p)

    def draw(self, surface: pygame.Surface, font: pygame.font.Font):
        """콤보 그리기 - pingfighter.py 라인 32454-32602"""
        if not self.active:
            return

        color = COMBO_COLORS.get(self.combo, (255, 255, 0))
        alpha = int(255 * (self.timer / 60))

        # 흔들림
        shake = min(self.combo - 1, 5) * 2
        offset_x = random.uniform(-shake, shake) if self.timer > 30 else 0
        offset_y = random.uniform(-shake, shake) if self.timer > 30 else 0

        # 텍스트
        text = f"{self.combo}COMBO!"
        font_size = 24 + self.combo * 2

        # 그림자
        shadow_surf = font.render(text, True, (0, 0, 0))
        shadow_rect = shadow_surf.get_rect(center=(self.x + 2 + offset_x, self.y + 2 + offset_y))
        surface.blit(shadow_surf, shadow_rect)

        # 본문
        text_surf = font.render(text, True, color)
        text_rect = text_surf.get_rect(center=(self.x + offset_x, self.y + offset_y))
        surface.blit(text_surf, text_rect)

        # 파티클
        for p in self.particles:
            a = int(255 * p['life'])
            if a > 0:
                pygame.draw.circle(surface, (*p['color'], a),
                                 (int(p['x']), int(p['y'])), 3)


# ============================================================================
# 점수판 UI (pingfighter.py 라인 653 재현)
# ============================================================================

class ScoreBoard:
    """KBO 스타일 점수판"""

    def __init__(self, screen_width: int, screen_height: int):
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.show_timer = 0
        self.fade_alpha = 0

    def show_score(self, p1_score: int, p2_score: int):
        """점수 표시"""
        self.show_timer = 90
        self.fade_alpha = 0

    def update(self):
        """업데이트"""
        if self.show_timer > 0:
            self.show_timer -= 1

            # 페이드인/아웃
            if self.show_timer > 72:  # 페이드인 (18프레임)
                self.fade_alpha = min(255, self.fade_alpha + 15)
            elif self.show_timer < 18:  # 페이드아웃
                self.fade_alpha = max(0, self.fade_alpha - 15)

    def draw(self, surface: pygame.Surface, p1_score: int, p2_score: int,
             font: pygame.font.Font, large_font: pygame.font.Font):
        """점수판 그리기"""
        if self.show_timer <= 0:
            return

        # 반투명 오버레이
        overlay = pygame.Surface((self.screen_width, self.screen_height), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, self.fade_alpha // 2))
        surface.blit(overlay, (0, 0))

        # 점수판 배경
        board_w = min(400, self.screen_width - 40)
        board_h = 200
        board_x = (self.screen_width - board_w) // 2
        board_y = (self.screen_height - board_h) // 2

        board_surf = pygame.Surface((board_w, board_h), pygame.SRCALPHA)

        # 프레임
        pygame.draw.rect(board_surf, (5, 15, 35, self.fade_alpha),
                        (0, 0, board_w, board_h), border_radius=10)
        pygame.draw.rect(board_surf, (40, 80, 140, self.fade_alpha),
                        (0, 0, board_w, board_h), 3, border_radius=10)

        # P1 로고 (파랑)
        pygame.draw.circle(board_surf, (30, 80, 180, self.fade_alpha),
                          (60, board_h // 2), 30)
        p1_text = font.render("P1", True, (255, 255, 255))
        board_surf.blit(p1_text, p1_text.get_rect(center=(60, board_h // 2)))

        # P2 로고 (빨강)
        pygame.draw.circle(board_surf, (180, 50, 50, self.fade_alpha),
                          (board_w - 60, board_h // 2), 30)
        p2_text = font.render("P2", True, (255, 255, 255))
        board_surf.blit(p2_text, p2_text.get_rect(center=(board_w - 60, board_h // 2)))

        # 점수
        score_text = f"{p1_score}  -  {p2_score}"
        score_surf = large_font.render(score_text, True, (255, 220, 100))
        score_rect = score_surf.get_rect(center=(board_w // 2, board_h // 2))
        board_surf.blit(score_surf, score_rect)

        surface.blit(board_surf, (board_x, board_y))


# ============================================================================
# 키 바인딩 클래스
# ============================================================================

class KeyBindings:
    """플레이어별 키 바인딩"""

    def __init__(self, is_p1: bool, is_top: bool):
        if is_p1:
            # P1: 방향키 + Shift
            self.left = pygame.K_LEFT
            self.right = pygame.K_RIGHT
            self.up = pygame.K_UP      # 쇼트
            self.down = pygame.K_DOWN  # 파워스매싱
            self.dash = pygame.K_RSHIFT
            self.skill = pygame.K_RCTRL  # 드라이브
        else:
            # P2: WASD + Space
            self.left = pygame.K_a
            self.right = pygame.K_d
            self.up = pygame.K_w      # 쇼트
            self.down = pygame.K_s    # 파워스매싱
            self.dash = pygame.K_SPACE
            self.skill = pygame.K_LCTRL  # 드라이브


# ============================================================================
# 메인 게임 클래스
# ============================================================================

class MultiplayerGame:
    """멀티플레이어 게임 메인 클래스"""

    def __init__(self, screen: pygame.Surface, width: int, height: int,
                 get_font_func: Callable, play_sound_funcs: Dict[str, Callable],
                 create_smasher_func: Callable, bgm_manager: Any):
        self.screen = screen
        self.width = width
        self.height = height
        self.get_font = get_font_func
        self.sounds = play_sound_funcs
        self.create_smasher_surface = create_smasher_func
        self.bgm_manager = bgm_manager

        self.clock = pygame.time.Clock()
        self.running = True
        self.game_over = False
        self.winner = None

        # 승리 점수
        self.win_score = 5

        # 플레이어 (랜덤 위치)
        p1_top = random.choice([True, False])
        self.p1 = SmasherPlayer(1, p1_top, width, height)
        self.p2 = SmasherPlayer(2, not p1_top, width, height)

        # 공
        self.ball = Ball(width, height)

        # 서브 순서
        self.serving_player = self.p1 if random.choice([True, False]) else self.p2
        self.waiting_for_serve = True
        self.serve_delay = 0

        # 공 생성 애니메이션
        self.spawn_animation = BallSpawnAnimation(width, height)
        self.spawn_animation_active = False

        # 이펙트
        self.effects = EffectSystem()

        # UI
        self.gauge_p1 = GaugeBar(self.p1, width, height)
        self.gauge_p2 = GaugeBar(self.p2, width, height)
        self.combo_display = ComboDisplay()
        self.score_board = ScoreBoard(width, height)

        # 폰트
        self.font = self.get_font(16)
        self.large_font = self.get_font(32)
        self.title_font = self.get_font(48)

        # 시간
        self.game_start_time = 0
        self.power_smash_start_time = 0

    def start_round(self):
        """라운드 시작"""
        self.waiting_for_serve = True
        self.serve_delay = 60  # 1초 대기

        # 공 생성 애니메이션 시작
        serve_player = self.serving_player
        opponent = self.p2 if serve_player == self.p1 else self.p1

        self.spawn_animation.start(
            is_player_serve=(serve_player == self.p1),
            player_y=serve_player.y,
            opponent_y=opponent.y
        )
        self.spawn_animation_active = True

        # 공 리셋
        self.ball.reset(serve_player)

    def handle_serve(self):
        """서브 처리"""
        if not self.waiting_for_serve:
            return

        # 애니메이션 완료 대기
        if self.spawn_animation_active:
            return

        if self.serve_delay > 0:
            self.serve_delay -= 1
            return

        # 서브 방향
        direction = -1 if self.serving_player.is_top else 1
        self.ball.serve(direction)
        self.ball.last_hit_by = f'p{self.serving_player.num}'

        self.waiting_for_serve = False

        if self.sounds.get('hit'):
            self.sounds['hit']()

    def handle_collision(self, player: SmasherPlayer, keys_pressed: Dict[int, bool]):
        """패들-공 충돌 처리"""
        if not self.ball.active:
            return

        if not self.ball.rect.colliderect(player.rect):
            return

        # 퍼펙트 타이밍 체크
        ball_approaching = (player.is_top and self.ball.vy < 0) or \
                          (not player.is_top and self.ball.vy > 0)

        if ball_approaching:
            player.perfect_timing_active = True
            player.perfect_timing_window = 5

        # 충돌 위치 계산
        rel_x = (self.ball.x - player.rect.centerx) / (player.width / 2)

        # 기본 충돌 처리
        new_vx, new_vy, boost = self.ball.paddle_collision(player, rel_x)
        self.ball.vx = new_vx
        self.ball.vy = new_vy

        # 게이지 충전
        player.charge_gauge(GAUGE_HIT_CHARGE, is_combo=True)

        # 콤보 표시
        if player.combo >= 2:
            self.combo_display.show(self.ball.x, self.ball.y, player.combo)
            self.effects.create_combo_effect(self.ball.x, self.ball.y, player.combo)

        # 에너지 폭발 이펙트
        self.effects.create_energy_explosion(self.ball.x, self.ball.y, 0.8, 1.0)

        # 스킬 체크
        self._check_skills(player, keys_pressed, rel_x)

        # 랠리 카운트
        self.ball.rally_count += 1
        self.ball.last_hit_by = f'p{player.num}'

        # 상대방 콤보 리셋
        opponent = self.p2 if player == self.p1 else self.p1
        opponent.combo = 0

        if self.sounds.get('hit'):
            self.sounds['hit']()

    def _check_skills(self, player: SmasherPlayer, keys_pressed: Dict[int, bool], rel_x: float):
        """스킬 발동 체크"""
        # 쇼트 - UP 키
        if keys_pressed.get(player.keys.up, False):
            opponent = self.p2 if player == self.p1 else self.p1
            new_vx, new_vy, speed = player.activate_short_shot(
                self.ball.vx, self.ball.vy,
                opponent.rect.centerx, opponent.rect.centery
            )
            if speed > 0:
                self.ball.vx = new_vx
                self.ball.vy = new_vy
                self.effects.create_skill_effect(self.ball.x, self.ball.y, 'short_shot')
                if self.sounds.get('short_shot'):
                    self.sounds['short_shot']()

        # 드라이브 - 퍼펙트 타이밍 + 좌/우
        elif player.perfect_timing_active:
            direction = 0
            if keys_pressed.get(player.keys.left, False):
                direction = -1
            elif keys_pressed.get(player.keys.right, False):
                direction = 1

            if direction != 0 and keys_pressed.get(player.keys.skill, False):
                spin, spin_dir = player.activate_drive(direction)
                if spin > 0:
                    self.ball.spin_strength = spin
                    self.ball.spin_direction = spin_dir
                    self.ball.vx *= DRIVE_SPEED_BOOST
                    self.ball.vy *= DRIVE_SPEED_BOOST
                    self.effects.create_skill_effect(self.ball.x, self.ball.y, 'drive', direction)

        # 파워스매싱 - DOWN 키
        if keys_pressed.get(player.keys.down, False):
            direction = 0
            if keys_pressed.get(player.keys.left, False):
                direction = -1
            elif keys_pressed.get(player.keys.right, False):
                direction = 1

            arc, gravity, speed_mult = player.activate_power_smash(direction, self.ball.current_speed)
            if arc != 0 or gravity != 0:
                self.ball.vx *= speed_mult
                self.ball.vy *= speed_mult
                self.power_smash_start_time = time.time()
                self.effects.create_skill_effect(self.ball.x, self.ball.y, 'power_smash', direction)

    def update(self, dt: float, keys_pressed: Dict[int, bool]):
        """게임 업데이트"""
        if self.game_over:
            return

        # 공 생성 애니메이션 업데이트
        if self.spawn_animation_active:
            ball_x, ball_y = self.spawn_animation.update(dt)
            self.ball.x = ball_x
            self.ball.y = ball_y
            self.ball.update_rect()

            if self.spawn_animation.complete:
                self.spawn_animation_active = False

        # 서브 처리
        self.handle_serve()

        # 플레이어 업데이트
        self.p1.update(keys_pressed, dt)
        self.p2.update(keys_pressed, dt)

        # 공 업데이트
        if self.ball.active:
            # 쇼트 업데이트
            if self.p1.short_shot_active:
                self.ball.vx, self.ball.vy = self.p1.update_short_shot(
                    self.ball.vx, self.ball.vy, self.ball.y, self.p2.rect.centery)
            if self.p2.short_shot_active:
                self.ball.vx, self.ball.vy = self.p2.update_short_shot(
                    self.ball.vx, self.ball.vy, self.ball.y, self.p1.rect.centery)

            # 파워스매싱 업데이트
            if self.p1.power_smash_active:
                elapsed = time.time() - self.power_smash_start_time
                self.ball.vx, self.ball.vy = self.p1.update_power_smash(
                    self.ball.vx, self.ball.vy, elapsed)
            if self.p2.power_smash_active:
                elapsed = time.time() - self.power_smash_start_time
                self.ball.vx, self.ball.vy = self.p2.update_power_smash(
                    self.ball.vx, self.ball.vy, elapsed)

            self.ball.update(dt)

            # 벽 충돌
            wall_dir = self.ball.wall_bounce()
            if wall_dir != 0:
                self.effects.create_wall_impact(self.ball.x, self.ball.y, wall_dir)
                if self.sounds.get('wall'):
                    self.sounds['wall']()

            # 패들 충돌
            self.handle_collision(self.p1, keys_pressed)
            self.handle_collision(self.p2, keys_pressed)

            # 점수 체크
            score_result = self.ball.check_score()
            if score_result != 0:
                self._handle_score(score_result)

        # 이펙트 업데이트
        self.effects.update(dt)
        self.combo_display.update(dt)
        self.score_board.update()

    def _handle_score(self, result: int):
        """점수 처리"""
        if result == 1:  # 상단 통과
            if self.p1.is_top:
                self.p2.score += 1
                self.serving_player = self.p1
            else:
                self.p1.score += 1
                self.serving_player = self.p2
        else:  # 하단 통과
            if self.p1.is_top:
                self.p1.score += 1
                self.serving_player = self.p2
            else:
                self.p2.score += 1
                self.serving_player = self.p1

        # 점수 표시
        self.score_board.show_score(self.p1.score, self.p2.score)

        if self.sounds.get('score'):
            self.sounds['score']()

        # 승리 체크
        if self.p1.score >= self.win_score:
            self.game_over = True
            self.winner = self.p1
        elif self.p2.score >= self.win_score:
            self.game_over = True
            self.winner = self.p2
        else:
            # 다음 라운드
            self.start_round()

    def draw(self):
        """게임 그리기"""
        # 배경
        self.screen.fill((10, 15, 30))

        # 중앙선
        pygame.draw.line(self.screen, (40, 50, 70),
                        (0, self.height // 2), (self.width, self.height // 2), 2)

        # 공 생성 애니메이션
        if self.spawn_animation_active:
            self.spawn_animation.draw(self.screen)

        # 플레이어
        self.p1.draw(self.screen)
        self.p2.draw(self.screen)

        # 공
        self.ball.draw(self.screen)

        # 이펙트
        self.effects.draw(self.screen)

        # UI
        self.gauge_p1.draw(self.screen, self.font)
        self.gauge_p2.draw(self.screen, self.font)
        self.combo_display.draw(self.screen, self.large_font)
        self.score_board.draw(self.screen, self.p1.score, self.p2.score,
                             self.font, self.large_font)

        # 점수 표시 (상단)
        score_text = f"P1: {self.p1.score}  -  P2: {self.p2.score}"
        score_surf = self.font.render(score_text, True, (200, 200, 200))
        score_rect = score_surf.get_rect(centerx=self.width // 2, top=10)
        self.screen.blit(score_surf, score_rect)

        # 서브 대기 표시
        if self.waiting_for_serve and not self.spawn_animation_active:
            serve_text = f"P{self.serving_player.num} SERVE"
            serve_surf = self.large_font.render(serve_text, True, (255, 220, 100))
            serve_rect = serve_surf.get_rect(center=(self.width // 2, self.height // 2))
            self.screen.blit(serve_surf, serve_rect)

    def draw_result(self):
        """결과 화면 그리기"""
        # 어두운 오버레이
        overlay = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 180))
        self.screen.blit(overlay, (0, 0))

        # 승리 텍스트
        winner_text = f"P{self.winner.num} WINS!"
        winner_surf = self.title_font.render(winner_text, True, self.winner.color)
        winner_rect = winner_surf.get_rect(center=(self.width // 2, self.height // 2 - 50))
        self.screen.blit(winner_surf, winner_rect)

        # 최종 점수
        score_text = f"{self.p1.score} - {self.p2.score}"
        score_surf = self.large_font.render(score_text, True, (255, 255, 255))
        score_rect = score_surf.get_rect(center=(self.width // 2, self.height // 2 + 20))
        self.screen.blit(score_surf, score_rect)

        # 안내
        hint_text = "Press ENTER to continue"
        hint_surf = self.font.render(hint_text, True, (150, 150, 150))
        hint_rect = hint_surf.get_rect(center=(self.width // 2, self.height // 2 + 80))
        self.screen.blit(hint_surf, hint_rect)

    def run(self) -> bool:
        """게임 실행"""
        self.game_start_time = time.time()
        self.start_round()

        while self.running:
            dt = self.clock.tick(60) / 1000.0

            # 이벤트 처리
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    self.running = False
                    return False
                elif event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_ESCAPE:
                        self.running = False
                        return True
                    elif event.key == pygame.K_RETURN and self.game_over:
                        self.running = False
                        return True

            # 키 상태
            keys = pygame.key.get_pressed()
            keys_dict = {i: keys[i] for i in range(len(keys))}

            # 업데이트
            self.update(dt, keys_dict)

            # 그리기
            self.draw()

            if self.game_over:
                self.draw_result()

            pygame.display.flip()

        return True


# ============================================================================
# 캐릭터 선택 화면
# ============================================================================

def show_character_select(screen: pygame.Surface, width: int, height: int,
                         get_font_func: Callable, play_click_sound: Callable,
                         bgm_manager: Any) -> Optional[Dict]:
    """캐릭터 선택 화면"""
    clock = pygame.time.Clock()

    font = get_font_func(16)
    large_font = get_font_func(32)
    title_font = get_font_func(48)

    characters = [
        {"name": "스매셔", "name_en": "SMASHER", "color": (0, 150, 255), "available": True},
        {"name": "코만도", "name_en": "COMMANDO", "color": (80, 120, 60), "available": False},
        {"name": "발토르", "name_en": "BALTOR", "color": (180, 120, 60), "available": False},
        {"name": "옵티머스", "name_en": "OPTIMUS", "color": (60, 200, 255), "available": False},
    ]

    p1_select = 0
    p2_select = 0
    p1_confirmed = False
    p2_confirmed = False

    while True:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                return None
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    return None

                # P1 선택 (방향키)
                if not p1_confirmed:
                    if event.key == pygame.K_LEFT:
                        p1_select = (p1_select - 1) % len(characters)
                        play_click_sound()
                    elif event.key == pygame.K_RIGHT:
                        p1_select = (p1_select + 1) % len(characters)
                        play_click_sound()
                    elif event.key == pygame.K_RETURN:
                        if characters[p1_select]["available"]:
                            p1_confirmed = True
                            play_click_sound()

                # P2 선택 (WASD)
                if not p2_confirmed:
                    if event.key == pygame.K_a:
                        p2_select = (p2_select - 1) % len(characters)
                        play_click_sound()
                    elif event.key == pygame.K_d:
                        p2_select = (p2_select + 1) % len(characters)
                        play_click_sound()
                    elif event.key == pygame.K_SPACE:
                        if characters[p2_select]["available"]:
                            p2_confirmed = True
                            play_click_sound()

        # 둘 다 확인하면 시작
        if p1_confirmed and p2_confirmed:
            return {
                "p1": characters[p1_select],
                "p2": characters[p2_select]
            }

        # 그리기
        screen.fill((15, 20, 35))

        # 타이틀
        title_surf = title_font.render("SELECT CHARACTER", True, (255, 255, 255))
        title_rect = title_surf.get_rect(centerx=width // 2, top=30)
        screen.blit(title_surf, title_rect)

        # 캐릭터 카드
        card_width = 120
        card_height = 150
        total_width = len(characters) * card_width + (len(characters) - 1) * 20
        start_x = (width - total_width) // 2

        for i, char in enumerate(characters):
            x = start_x + i * (card_width + 20)
            y = height // 2 - 100

            # 선택 상태
            is_p1_selected = (i == p1_select)
            is_p2_selected = (i == p2_select)

            # 카드 배경
            bg_color = char["color"] if char["available"] else (60, 60, 60)
            if not char["available"]:
                bg_alpha = 100
            elif is_p1_selected or is_p2_selected:
                bg_alpha = 255
            else:
                bg_alpha = 150

            card_surf = pygame.Surface((card_width, card_height), pygame.SRCALPHA)
            pygame.draw.rect(card_surf, (*bg_color, bg_alpha),
                           (0, 0, card_width, card_height), border_radius=10)

            # 테두리
            if is_p1_selected:
                pygame.draw.rect(card_surf, (0, 150, 255),
                               (0, 0, card_width, card_height), 3, border_radius=10)
            if is_p2_selected:
                pygame.draw.rect(card_surf, (255, 100, 100),
                               (0, 0, card_width, card_height), 3, border_radius=10)

            screen.blit(card_surf, (x, y))

            # 캐릭터 이름
            name_surf = font.render(char["name"], True, (255, 255, 255))
            name_rect = name_surf.get_rect(centerx=x + card_width // 2,
                                          centery=y + card_height // 2)
            screen.blit(name_surf, name_rect)

            # 영문 이름
            en_surf = font.render(char["name_en"], True, (200, 200, 200))
            en_rect = en_surf.get_rect(centerx=x + card_width // 2,
                                      centery=y + card_height // 2 + 25)
            screen.blit(en_surf, en_rect)

            # 잠금 표시
            if not char["available"]:
                lock_surf = large_font.render("LOCKED", True, (150, 150, 150))
                lock_rect = lock_surf.get_rect(centerx=x + card_width // 2,
                                              centery=y + card_height // 2 + 55)
                screen.blit(lock_surf, lock_rect)

            # P1/P2 마커
            if is_p1_selected:
                p1_marker = font.render("P1", True, (0, 150, 255))
                screen.blit(p1_marker, (x + 5, y + 5))
            if is_p2_selected:
                p2_marker = font.render("P2", True, (255, 100, 100))
                screen.blit(p2_marker, (x + card_width - 25, y + 5))

        # 확인 상태
        status_y = height // 2 + 100

        p1_status = "READY!" if p1_confirmed else "← → + ENTER"
        p1_color = (100, 255, 100) if p1_confirmed else (150, 150, 150)
        p1_surf = font.render(f"P1: {p1_status}", True, p1_color)
        screen.blit(p1_surf, (50, status_y))

        p2_status = "READY!" if p2_confirmed else "A D + SPACE"
        p2_color = (100, 255, 100) if p2_confirmed else (150, 150, 150)
        p2_surf = font.render(f"P2: {p2_status}", True, p2_color)
        screen.blit(p2_surf, (width - 200, status_y))

        # ESC 안내
        esc_surf = font.render("ESC: Back", True, (100, 100, 100))
        screen.blit(esc_surf, (10, height - 30))

        pygame.display.flip()
        clock.tick(60)


# ============================================================================
# 메인 함수
# ============================================================================

def run_multiplayer_game(screen: pygame.Surface, width: int, height: int,
                        get_font_func: Callable, play_sound_funcs: Dict[str, Callable],
                        create_smasher_func: Callable, bgm_manager: Any) -> bool:
    """
    멀티플레이어 게임 실행

    Args:
        screen: pygame 화면
        width, height: 화면 크기
        get_font_func: 폰트 가져오기 함수
        play_sound_funcs: 사운드 함수 딕셔너리
        create_smasher_func: 스매셔 스프라이트 생성 함수
        bgm_manager: BGM 관리자

    Returns:
        True: 정상 종료, False: 강제 종료
    """
    # 캐릭터 선택
    selection = show_character_select(
        screen, width, height, get_font_func,
        play_sound_funcs.get('click', lambda: None),
        bgm_manager
    )

    if selection is None:
        return True  # ESC로 취소

    # 게임 시작
    game = MultiplayerGame(
        screen, width, height,
        get_font_func, play_sound_funcs,
        create_smasher_func, bgm_manager
    )

    return game.run()
