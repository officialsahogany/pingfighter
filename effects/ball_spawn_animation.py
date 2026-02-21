# -*- coding: utf-8 -*-
"""Ball Spawn Animation - 공 생성 애니메이션 시스템 (Ultra Premium HD - Performance Optimized)

스테이지 시작 시 공이 양자 에너지/번개 소용돌이로 응축되어 생성되는
초고퀄리티 애니메이션을 담당합니다.

★ 성능 최적화 핵심:
- 매 프레임 pygame.Surface 생성 완전 제거 (사전 할당 레이어 재사용)
- 글로우 텍스처 캐시 (GlowCache) - 동일 크기/색상 재사용
- 파티클 glow → pygame.draw.circle 직접 호출
- 번개 per-bolt Surface 제거 → 공유 레이어에 직접 그리기

애니메이션 시퀀스:
1. 에너지 응축 (4초) - 우주 먼지 + 양자 자기장 + 플라즈마 촉수 + 번개 + 전기 아크
2. 공 부양 (1.5초) - 완성된 공이 부양 + 궤도 구체 + 에너지 링
3. 서브 이동 (2.5초) - 잔상 + 홀로그램 + 스파크 + 충격파 + 전기 아크

총 8초 애니메이션
"""

import math
import random
import pygame
from typing import List, Tuple, Optional


# ═══════════════════════════════════════════════
# 글로우 텍스처 캐시 (성능 핵심)
# ═══════════════════════════════════════════════
class GlowCache:
    """Pre-rendered glow texture cache - 동일 (size, color) 조합 재사용"""
    _cache = {}
    _max_cache = 64  # 메모리 제한

    @classmethod
    def get(cls, radius: int, color: Tuple[int, int, int], layers: int = 3) -> pygame.Surface:
        """캐시된 글로우 텍스처 반환. 없으면 생성 후 캐시."""
        radius = max(2, min(radius, 60))  # 크기 제한
        key = (radius, color, layers)
        if key not in cls._cache:
            if len(cls._cache) >= cls._max_cache:
                # LRU 대신 전체 클리어 (단순하지만 효과적)
                cls._cache.clear()
            size = radius * 2
            surf = pygame.Surface((size, size), pygame.SRCALPHA)
            center = radius
            step = max(1, radius // layers)
            for r in range(radius, 0, -step):
                a = max(0, min(255, int(180 * (r / radius) * 0.3)))
                pygame.draw.circle(surf, (*color, a), (center, center), r)
            cls._cache[key] = surf
        return cls._cache[key]

    @classmethod
    def clear(cls):
        cls._cache.clear()


# ═══════════════════════════════════════════════
# CosmicDust (우주 먼지 - 초경량)
# ═══════════════════════════════════════════════
class CosmicDust:
    """우주 먼지 입자 - 최소 비용 렌더링 (Surface 생성 제로)"""

    def __init__(self, screen_width: int, screen_height: int, center_x: float, center_y: float):
        angle = random.uniform(0, math.pi * 2)
        dist = random.uniform(30, max(screen_width, screen_height) * 0.45)
        self.x = center_x + math.cos(angle) * dist
        self.y = center_y + math.sin(angle) * dist
        self.center_x = center_x
        self.center_y = center_y
        self.angle = angle
        self.orbit_radius = dist
        self.orbit_speed = random.uniform(0.005, 0.02) * random.choice([-1, 1])
        self.twinkle_phase = random.uniform(0, math.pi * 2)
        self.twinkle_speed = random.uniform(2, 6)
        self.base_brightness = random.uniform(0.3, 0.9)
        self.size = random.randint(1, 2)

        palette = random.random()
        if palette < 0.3:
            self.color = (180, 200, 255)
        elif palette < 0.5:
            self.color = (200, 180, 255)
        elif palette < 0.65:
            self.color = (255, 220, 240)
        elif palette < 0.8:
            self.color = (220, 255, 250)
        else:
            self.color = (255, 255, 240)

    def update(self, progress: float, dt: float):
        self.twinkle_phase += self.twinkle_speed * dt
        self.angle += self.orbit_speed * dt
        pull = 1 - progress * 0.3
        current_r = self.orbit_radius * pull
        self.x = self.center_x + math.cos(self.angle) * current_r
        self.y = self.center_y + math.sin(self.angle) * current_r

    def draw(self, surface: pygame.Surface, alpha_mult: float = 1.0):
        brightness = self.base_brightness * (0.5 + 0.5 * math.sin(self.twinkle_phase))
        if brightness * alpha_mult < 0.15:
            return
        # 직접 circle 하나만 그림 (Surface 생성 없음)
        pygame.draw.circle(surface, self.color, (int(self.x), int(self.y)), self.size)


# ═══════════════════════════════════════════════
# PlasmaTendril (플라즈마 촉수 - 경량화)
# ═══════════════════════════════════════════════
class PlasmaTendril:
    """플라즈마 촉수 - 라인 기반 직접 렌더링"""

    def __init__(self, center_x: float, center_y: float, max_radius: float):
        self.center_x = center_x
        self.center_y = center_y
        self.base_angle = random.uniform(0, math.pi * 2)
        self.length = max_radius * random.uniform(0.5, 0.85)
        self.num_segments = random.randint(10, 16)
        self.control_offsets = [random.uniform(-20, 20) for _ in range(self.num_segments)]
        self.wave_phases = [random.uniform(0, math.pi * 2) for _ in range(self.num_segments)]
        self.wave_speeds = [random.uniform(2, 5) for _ in range(self.num_segments)]

        c = random.random()
        if c < 0.35:
            self.color = (120, 180, 255)
        elif c < 0.65:
            self.color = (180, 120, 255)
        else:
            self.color = (255, 140, 220)

        self.core_color = tuple(min(255, c + 80) for c in self.color)
        self.thickness = random.randint(2, 3)
        self.lifetime = random.uniform(1.0, 3.0)
        self.max_lifetime = self.lifetime
        self.pulse_phase = random.uniform(0, math.pi * 2)
        self.pulse_speed = random.uniform(4, 8)

    def update(self, progress: float, dt: float) -> bool:
        self.lifetime -= dt
        self.pulse_phase += self.pulse_speed * dt
        for i in range(self.num_segments):
            self.wave_phases[i] += self.wave_speeds[i] * dt
        return self.lifetime > 0

    def draw(self, surface: pygame.Surface, draw_progress: float, alpha_mult: float = 1.0):
        life_ratio = self.lifetime / self.max_lifetime
        pulse = 0.6 + 0.4 * math.sin(self.pulse_phase)
        if life_ratio * pulse * alpha_mult < 0.08:
            return

        # 촉수 포인트 계산
        points = []
        effective_length = self.length * (1 - draw_progress * 0.8)
        angle = self.base_angle
        perp_angle = angle + math.pi / 2

        for i in range(self.num_segments + 1):
            t = i / self.num_segments
            dist = effective_length * (1 - t)
            if i < self.num_segments:
                wave = math.sin(self.wave_phases[i]) * self.control_offsets[i] * (1 - t)
            else:
                wave = 0
            px = self.center_x + math.cos(angle) * dist + math.cos(perp_angle) * wave
            py = self.center_y + math.sin(angle) * dist + math.sin(perp_angle) * wave
            points.append((int(px), int(py)))

        if len(points) < 2:
            return

        # 직접 라인 그리기 (Surface 생성 없음)
        # 외부 글로우
        for i in range(len(points) - 1):
            pygame.draw.line(surface, self.color, points[i], points[i + 1], self.thickness + 2)
        # 밝은 코어
        for i in range(len(points) - 1):
            seg_thick = max(1, self.thickness - 1)
            pygame.draw.line(surface, self.core_color, points[i], points[i + 1], seg_thick)


# ═══════════════════════════════════════════════
# OrbitingOrb (궤도 구체 - 경량화)
# ═══════════════════════════════════════════════
class OrbitingOrb:
    """궤도 구체 - Surface 할당 최소화"""

    def __init__(self, center_x: float, center_y: float, orbit_radius: float):
        self.center_x = center_x
        self.center_y = center_y
        self.orbit_radius = orbit_radius
        self.angle = random.uniform(0, math.pi * 2)
        self.speed = random.uniform(3, 6) * random.choice([-1, 1])
        self.size = random.randint(3, 6)
        self.tilt = random.uniform(0.3, 0.8)
        self.x = center_x
        self.y = center_y

        c = random.random()
        if c < 0.3:
            self.color = (100, 200, 255)
        elif c < 0.6:
            self.color = (200, 140, 255)
        elif c < 0.8:
            self.color = (255, 180, 220)
        else:
            self.color = (180, 255, 220)

        # 잔상은 간단한 위치 리스트만 유지
        self.trail: List[Tuple[int, int]] = []
        self.trail_length = 8
        self.pulse_phase = random.uniform(0, math.pi * 2)

    def update(self, dt: float, new_center: Tuple[float, float] = None):
        if new_center:
            self.center_x, self.center_y = new_center
        self.angle += self.speed * dt
        self.pulse_phase += 5 * dt
        self.x = self.center_x + math.cos(self.angle) * self.orbit_radius
        self.y = self.center_y + math.sin(self.angle) * self.orbit_radius * self.tilt

        self.trail.append((int(self.x), int(self.y)))
        if len(self.trail) > self.trail_length:
            self.trail.pop(0)

    def draw(self, surface: pygame.Surface, alpha_mult: float = 1.0):
        # 잔상 - 직접 circle (Surface 생성 없음)
        for i, (tx, ty) in enumerate(self.trail):
            t_ratio = (i + 1) / max(1, len(self.trail))
            trail_size = max(1, int(self.size * t_ratio * 0.5))
            pygame.draw.circle(surface, self.color, (tx, ty), trail_size)

        # 메인 구체
        ix, iy = int(self.x), int(self.y)
        pygame.draw.circle(surface, self.color, (ix, iy), self.size)
        # 하이라이트
        hl_size = max(1, self.size // 3)
        pygame.draw.circle(surface, (255, 255, 255),
                           (ix - self.size // 4, iy - self.size // 4), hl_size)


# ═══════════════════════════════════════════════
# ShockwaveRing (충격파 - 경량화)
# ═══════════════════════════════════════════════
class ShockwaveRing:
    """충격파 링 - pygame.draw.circle 직접 사용"""

    def __init__(self, center_x: float, center_y: float, max_radius: float = 200):
        self.center_x = center_x
        self.center_y = center_y
        self.radius = 5.0
        self.max_radius = max_radius
        self.expansion_speed = random.uniform(200, 350)
        self.initial_thickness = random.randint(3, 6)

        c = random.random()
        if c < 0.4:
            self.color = (180, 220, 255)
        elif c < 0.7:
            self.color = (220, 180, 255)
        else:
            self.color = (255, 220, 255)

        self.lifetime = random.uniform(0.4, 0.7)
        self.max_lifetime = self.lifetime

    def update(self, dt: float, new_center: Tuple[float, float] = None) -> bool:
        self.lifetime -= dt
        self.radius += self.expansion_speed * dt
        if new_center:
            self.center_x, self.center_y = new_center
        return self.lifetime > 0 and self.radius < self.max_radius

    def draw(self, surface: pygame.Surface, alpha_mult: float = 1.0):
        life_ratio = self.lifetime / self.max_lifetime
        if life_ratio < 0.05:
            return
        thickness = max(1, int(self.initial_thickness * life_ratio))
        r = int(self.radius)
        if r < 3:
            return
        # 직접 원 그리기 (Surface 생성 없음)
        # 외부 글로우
        glow_color = tuple(max(0, int(c * 0.5 * life_ratio)) for c in self.color)
        pygame.draw.circle(surface, glow_color,
                           (int(self.center_x), int(self.center_y)), r, thickness + 3)
        # 메인 링
        main_color = tuple(max(0, int(c * life_ratio)) for c in self.color)
        pygame.draw.circle(surface, main_color,
                           (int(self.center_x), int(self.center_y)), r, thickness)
        # 밝은 코어
        core_v = int(255 * life_ratio)
        pygame.draw.circle(surface, (core_v, core_v, core_v),
                           (int(self.center_x), int(self.center_y)), r, max(1, thickness - 1))


# ═══════════════════════════════════════════════
# AfterImage (잔상 - 초경량)
# ═══════════════════════════════════════════════
class AfterImage:
    """잔상 효과 - 단순 circle 기반"""

    def __init__(self, x: float, y: float, radius: float, ball_color: Tuple[int, int, int]):
        self.x = x
        self.y = y
        self.radius = radius
        self.color = ball_color
        self.lifetime = 0.35
        self.max_lifetime = 0.35

    def update(self, dt: float) -> bool:
        self.lifetime -= dt
        return self.lifetime > 0

    def draw(self, surface: pygame.Surface, alpha_mult: float = 1.0):
        life_ratio = self.lifetime / self.max_lifetime
        if life_ratio < 0.1:
            return
        r = max(1, int(self.radius * (0.7 + 0.3 * life_ratio)))
        # 직접 그리기
        fade_color = tuple(max(0, int(c * life_ratio * 0.5)) for c in self.color)
        pygame.draw.circle(surface, fade_color, (int(self.x), int(self.y)), r)


# ═══════════════════════════════════════════════
# ChromaticRay (색채 광선 - 경량화)
# ═══════════════════════════════════════════════
class ChromaticRay:
    """색채 광선 - 단순 라인 기반"""

    def __init__(self, center_x: float, center_y: float, angle: float, length: float):
        self.center_x = center_x
        self.center_y = center_y
        self.angle = angle
        self.length = length
        self.width = random.randint(1, 3)

        hue = random.uniform(0, 1)
        self.color = self._hue_to_rgb(hue)
        self.core_color = tuple(min(255, c + 60) for c in self.color)

        self.lifetime = random.uniform(0.12, 0.35)
        self.max_lifetime = self.lifetime

    @staticmethod
    def _hue_to_rgb(hue: float) -> Tuple[int, int, int]:
        h = hue * 6
        c = 0.6
        x = c * (1 - abs(h % 2 - 1))
        m = 0.4
        if h < 1:
            r, g, b = c, x, 0
        elif h < 2:
            r, g, b = x, c, 0
        elif h < 3:
            r, g, b = 0, c, x
        elif h < 4:
            r, g, b = 0, x, c
        elif h < 5:
            r, g, b = x, 0, c
        else:
            r, g, b = c, 0, x
        return (int((r + m) * 255), int((g + m) * 255), int((b + m) * 255))

    def update(self, dt: float) -> bool:
        self.lifetime -= dt
        return self.lifetime > 0

    def draw(self, surface: pygame.Surface, alpha_mult: float = 1.0):
        life_ratio = self.lifetime / self.max_lifetime
        if life_ratio < 0.1:
            return
        end_x = self.center_x + math.cos(self.angle) * self.length
        end_y = self.center_y + math.sin(self.angle) * self.length
        start = (int(self.center_x), int(self.center_y))
        end = (int(end_x), int(end_y))
        # 글로우 + 메인 + 코어 (3 라인, Surface 없음)
        pygame.draw.line(surface, self.color, start, end, self.width + 2)
        pygame.draw.line(surface, self.core_color, start, end, self.width)
        pygame.draw.line(surface, (255, 255, 255), start, end, max(1, self.width - 1))


# ═══════════════════════════════════════════════
# EnergyNebula (에너지 성운 - 캐시 기반)
# ═══════════════════════════════════════════════
class EnergyNebula:
    """에너지 성운 - GlowCache 사용으로 Surface 생성 최소화"""

    def __init__(self, center_x: float, center_y: float, max_radius: float):
        angle = random.uniform(0, math.pi * 2)
        dist = max_radius * random.uniform(0.2, 0.8)
        self.x = center_x + math.cos(angle) * dist
        self.y = center_y + math.sin(angle) * dist
        self.center_x = center_x
        self.center_y = center_y
        self.angle = angle
        self.dist = dist
        self.size = random.randint(12, 30)
        self.drift_speed = random.uniform(0.01, 0.03) * random.choice([-1, 1])

        c = random.random()
        if c < 0.3:
            self.color = (80, 120, 200)
        elif c < 0.5:
            self.color = (120, 60, 180)
        elif c < 0.7:
            self.color = (180, 60, 120)
        else:
            self.color = (60, 140, 160)

        self.pulse_phase = random.uniform(0, math.pi * 2)
        self.pulse_speed = random.uniform(1.5, 3.5)

    def update(self, progress: float, dt: float):
        self.pulse_phase += self.pulse_speed * dt
        self.angle += self.drift_speed * dt
        effective_dist = self.dist * (1 - progress * 0.7)
        self.x = self.center_x + math.cos(self.angle) * effective_dist
        self.y = self.center_y + math.sin(self.angle) * effective_dist
        self.size = max(3, self.size - progress * 0.05)

    def draw(self, surface: pygame.Surface, alpha_mult: float = 1.0):
        pulse = 0.5 + 0.5 * math.sin(self.pulse_phase)
        if pulse * alpha_mult < 0.15:
            return
        size_int = int(self.size)
        if size_int < 3:
            return
        # GlowCache 사용 (Surface 재생성 없음)
        glow = GlowCache.get(size_int, self.color, layers=3)
        surface.blit(glow, (int(self.x - size_int), int(self.y - size_int)))


# ═══════════════════════════════════════════════
# QuantumParticle (양자 입자 - 성능 최적화)
# ═══════════════════════════════════════════════
class QuantumParticle:
    """양자 에너지 입자 - Surface 할당 제거, 직접 circle 렌더링"""

    def __init__(self, center_x: float, center_y: float, max_radius: float):
        angle = random.uniform(0, math.pi * 2)
        dist = max_radius * random.uniform(0.8, 1.2)
        self.x = center_x + math.cos(angle) * dist
        self.y = center_y + math.sin(angle) * dist
        self.center_x = center_x
        self.center_y = center_y
        self.angle = angle
        self.radius = dist
        self.size = random.uniform(2, 6)
        self.speed = random.uniform(0.02, 0.06)

        color_choice = random.random()
        if color_choice < 0.25:
            self.color = (random.randint(120, 200), random.randint(200, 255), 255)
        elif color_choice < 0.45:
            self.color = (random.randint(160, 220), random.randint(100, 160), 255)
        elif color_choice < 0.6:
            self.color = (255, random.randint(180, 255), random.randint(220, 255))
        elif color_choice < 0.75:
            self.color = (random.randint(100, 160), 255, random.randint(220, 255))
        elif color_choice < 0.88:
            self.color = (255, random.randint(240, 255), random.randint(200, 230))
        else:
            self.color = (255, 255, random.randint(245, 255))

        self.brightness_phase = random.uniform(0, math.pi * 2)
        self.brightness_speed = random.uniform(3, 8)

        # 잔상: 위치만 기록 (크기/색상 계산 제거)
        self.trail: List[Tuple[int, int]] = []
        self.trail_length = random.randint(5, 10)

    def update(self, progress: float, dt: float):
        # 잔상 저장 (int 변환 미리)
        self.trail.append((int(self.x), int(self.y)))
        if len(self.trail) > self.trail_length:
            self.trail.pop(0)

        self.angle += self.speed * (1 + progress * 2.5)
        target_radius = self.radius * (1 - progress * 0.95)
        self.x = self.center_x + math.cos(self.angle) * target_radius
        self.y = self.center_y + math.sin(self.angle) * target_radius
        self.size = max(1, self.size * (1 + progress * 0.01))
        self.brightness_phase += self.brightness_speed * dt

    def draw(self, surface: pygame.Surface, alpha_mult: float = 1.0):
        brightness = 0.5 + 0.5 * math.sin(self.brightness_phase)
        if brightness * alpha_mult < 0.15:
            return

        # 잔상 - 직접 circle (Surface 생성 없음)
        trail_color = tuple(max(0, c >> 1) for c in self.color)  # 비트시프트로 절반 밝기
        trail_len = len(self.trail)
        for i in range(0, trail_len, 2):  # 2개씩 건너뛰어 성능 향상
            t_ratio = i / max(1, trail_len)
            ts = max(1, int(self.size * (0.3 + 0.3 * t_ratio)))
            pygame.draw.circle(surface, trail_color, self.trail[i], ts)

        # 메인 파티클 - 직접 circle (글로우 Surface 제거!)
        ix, iy = int(self.x), int(self.y)
        s = int(self.size)

        # 글로우 (큰 원 1개로 대체)
        glow_size = s * 2
        glow_color = tuple(max(0, min(255, int(c * brightness * 0.4))) for c in self.color)
        pygame.draw.circle(surface, glow_color, (ix, iy), glow_size)

        # 코어
        core_color = tuple(min(255, int(c * brightness * 1.1)) for c in self.color)
        pygame.draw.circle(surface, core_color, (ix, iy), s)

        # 중심 밝은점
        if s >= 2:
            pygame.draw.circle(surface, (255, 255, 255), (ix, iy), max(1, s >> 1))


# ═══════════════════════════════════════════════
# EnhancedLightningBolt (번개 - 성능 최적화)
# ═══════════════════════════════════════════════
class EnhancedLightningBolt:
    """번개 효과 - 공유 레이어에 직접 그리기 (per-bolt Surface 제거)"""

    def __init__(self, start_x: float, start_y: float, end_x: float, end_y: float,
                 branch_depth: int = 0, is_main: bool = True):
        self.start_x = start_x
        self.start_y = start_y
        self.end_x = end_x
        self.end_y = end_y
        self.branch_depth = branch_depth
        self.is_main = is_main

        self.segments = self._generate_segments()

        self.branches: List['EnhancedLightningBolt'] = []
        if branch_depth < 2 and is_main:
            self._generate_branches()

        self.lifetime = random.uniform(0.08, 0.18) if is_main else random.uniform(0.05, 0.12)
        self.max_lifetime = self.lifetime
        self.fade_in_time = self.max_lifetime * 0.2

        color_base = random.choice([
            (200, 230, 255),
            (230, 200, 255),
            (220, 255, 255),
            (255, 220, 255),
            (255, 255, 255),
        ])
        self.color = color_base
        self.glow_color = tuple(max(0, c - 30) for c in self.color)
        self.thickness = random.randint(1, 2) if is_main else 1
        self.base_opacity = random.uniform(0.4, 0.65) if is_main else random.uniform(0.3, 0.5)

    def _generate_segments(self) -> List[Tuple[int, int, int, int]]:
        dx = self.end_x - self.start_x
        dy = self.end_y - self.start_y
        length = math.hypot(dx, dy)

        if length < 1:
            return [(int(self.start_x), int(self.start_y), int(self.end_x), int(self.end_y))]

        num_segments = max(3, int(length / 15))  # 세그먼트 수 줄임
        perp_x = -dy / length
        perp_y = dx / length

        current_x = self.start_x
        current_y = self.start_y
        segments = []

        for i in range(num_segments):
            t = (i + 1) / num_segments
            next_x = self.start_x + dx * t
            next_y = self.start_y + dy * t

            if i < num_segments - 1:
                max_offset = 18 * (1 - t * 0.3)
                offset = random.uniform(-max_offset, max_offset)
                next_x += perp_x * offset
                next_y += perp_y * offset

            segments.append((int(current_x), int(current_y), int(next_x), int(next_y)))
            current_x = next_x
            current_y = next_y

        return segments

    def _generate_branches(self):
        if len(self.segments) < 2:
            return
        num_branches = random.randint(1, 2)
        indices = random.sample(range(len(self.segments) - 1),
                                min(num_branches, len(self.segments) - 1))
        for idx in indices:
            seg = self.segments[idx]
            main_angle = math.atan2(self.end_y - self.start_y, self.end_x - self.start_x)
            branch_angle = main_angle + random.uniform(-math.pi / 3, math.pi / 3)
            main_length = math.hypot(self.end_x - self.start_x, self.end_y - self.start_y)
            branch_length = main_length * random.uniform(0.2, 0.4)
            self.branches.append(
                EnhancedLightningBolt(seg[2], seg[3],
                                      seg[2] + math.cos(branch_angle) * branch_length,
                                      seg[3] + math.sin(branch_angle) * branch_length,
                                      self.branch_depth + 1, is_main=False)
            )

    def update(self, dt: float) -> bool:
        self.lifetime -= dt
        self.branches = [b for b in self.branches if b.update(dt)]
        return self.lifetime > 0

    def _calc_fade(self) -> float:
        elapsed = self.max_lifetime - self.lifetime
        if elapsed < self.fade_in_time:
            return (elapsed / self.fade_in_time) * self.base_opacity
        fade_out = self.max_lifetime - self.fade_in_time
        if fade_out <= 0:
            return self.base_opacity
        return self.base_opacity * math.sqrt(max(0, self.lifetime / fade_out))

    def draw(self, surface: pygame.Surface, alpha_mult: float = 1.0):
        fade = self._calc_fade() * alpha_mult
        if fade < 0.03:
            return

        for branch in self.branches:
            branch.draw(surface, alpha_mult * 0.5)

        # 직접 라인 그리기 (Surface 생성 없음!)
        # 글로우 레이어 (2단계로 축소, 원래 5단계)
        glow_c = tuple(max(0, min(255, int(c * fade * 0.4))) for c in self.glow_color)
        main_c = tuple(max(0, min(255, int(c * fade * 0.7))) for c in self.color)
        core_v = max(0, min(255, int(255 * fade * 0.85)))
        core_c = (core_v, core_v, core_v)

        for sx, sy, ex, ey in self.segments:
            # 글로우
            pygame.draw.line(surface, glow_c, (sx, sy), (ex, ey), self.thickness + 4)
            # 메인
            pygame.draw.line(surface, main_c, (sx, sy), (ex, ey), self.thickness + 1)
            # 코어
            pygame.draw.line(surface, core_c, (sx, sy), (ex, ey), max(1, self.thickness))


# ═══════════════════════════════════════════════
# ChainLightning
# ═══════════════════════════════════════════════
class ChainLightning:
    def __init__(self, points: List[Tuple[float, float]]):
        self.bolts: List[EnhancedLightningBolt] = []
        for i in range(len(points) - 1):
            self.bolts.append(
                EnhancedLightningBolt(points[i][0], points[i][1],
                                      points[i + 1][0], points[i + 1][1],
                                      branch_depth=1, is_main=True)
            )
        self.lifetime = random.uniform(0.15, 0.35)
        self.max_lifetime = self.lifetime

    def update(self, dt: float) -> bool:
        self.lifetime -= dt
        for bolt in self.bolts:
            bolt.update(dt)
        return self.lifetime > 0

    def draw(self, surface: pygame.Surface, alpha_mult: float = 1.0):
        life_ratio = self.lifetime / self.max_lifetime
        for bolt in self.bolts:
            bolt.draw(surface, alpha_mult * life_ratio)


# ═══════════════════════════════════════════════
# ElectricArc (전기 아크 - 최적화)
# ═══════════════════════════════════════════════
class ElectricArc:
    def __init__(self, center_x: float, center_y: float, radius: float):
        self.center_x = center_x
        self.center_y = center_y
        self.radius = radius
        self.angle = random.uniform(0, math.pi * 2)
        self.arc_length = random.uniform(math.pi / 4, math.pi / 2)
        self.rotation_speed = random.uniform(3, 8) * random.choice([-1, 1])

        self.color = random.choice([
            (150, 200, 255), (200, 150, 255),
            (255, 255, 200), (200, 255, 255),
        ])
        self.glow_color = tuple(max(0, int(c * 0.6)) for c in self.color)

        self.lifetime = random.uniform(0.3, 0.7)
        self.max_lifetime = self.lifetime
        self.thickness = random.randint(1, 2)
        self.noise_points = [random.uniform(-5, 5) for _ in range(8)]

    def update(self, dt: float, new_center: Tuple[float, float] = None) -> bool:
        self.lifetime -= dt
        self.angle += self.rotation_speed * dt
        if new_center:
            self.center_x, self.center_y = new_center
        for i in range(len(self.noise_points)):
            self.noise_points[i] += random.uniform(-2, 2)
            self.noise_points[i] = max(-7, min(7, self.noise_points[i]))
        return self.lifetime > 0

    def draw(self, surface: pygame.Surface, alpha_mult: float = 1.0):
        life_ratio = self.lifetime / self.max_lifetime
        if life_ratio < 0.05:
            return

        points = []
        num_seg = 12  # 18 → 12 축소
        for i in range(num_seg + 1):
            t = i / num_seg
            ca = self.angle + t * self.arc_length
            ni = int(t * (len(self.noise_points) - 1))
            noise = self.noise_points[ni] * (1 - abs(t - 0.5) * 2)
            r = self.radius + noise
            points.append((int(self.center_x + math.cos(ca) * r),
                           int(self.center_y + math.sin(ca) * r)))

        if len(points) < 2:
            return

        fade = life_ratio * alpha_mult
        gc = tuple(max(0, int(c * fade * 0.5)) for c in self.color)
        mc = tuple(max(0, int(c * fade)) for c in self.color)
        cv = max(0, min(255, int(255 * fade)))

        for i in range(len(points) - 1):
            pygame.draw.line(surface, gc, points[i], points[i + 1], self.thickness + 3)
            pygame.draw.line(surface, mc, points[i], points[i + 1], self.thickness + 1)
            pygame.draw.line(surface, (cv, cv, cv), points[i], points[i + 1],
                             max(1, self.thickness))


# ═══════════════════════════════════════════════
# Spark (스파크 - 최적화)
# ═══════════════════════════════════════════════
class Spark:
    def __init__(self, x: float, y: float, direction: float = None):
        self.x = x
        self.y = y
        if direction is None:
            direction = random.uniform(0, math.pi * 2)
        speed = random.uniform(60, 180)
        self.vx = math.cos(direction) * speed
        self.vy = math.sin(direction) * speed
        self.gravity = random.uniform(100, 250)
        self.color = random.choice([
            (255, 255, 200), (255, 200, 100),
            (200, 220, 255), (255, 255, 255),
        ])
        self.size = random.randint(1, 3)
        self.lifetime = random.uniform(0.15, 0.5)
        self.max_lifetime = self.lifetime
        self.trail: List[Tuple[int, int]] = []
        self.trail_length = random.randint(3, 6)

    def update(self, dt: float) -> bool:
        self.lifetime -= dt
        self.trail.append((int(self.x), int(self.y)))
        if len(self.trail) > self.trail_length:
            self.trail.pop(0)
        self.x += self.vx * dt
        self.y += self.vy * dt
        self.vy += self.gravity * dt
        self.vx *= 0.98
        self.vy *= 0.98
        return self.lifetime > 0

    def draw(self, surface: pygame.Surface, alpha_mult: float = 1.0):
        life_ratio = self.lifetime / self.max_lifetime
        if life_ratio < 0.1:
            return
        # 잔상 - 직접 circle
        for tx, ty in self.trail:
            pygame.draw.circle(surface, self.color, (tx, ty), max(1, self.size - 1))
        # 메인
        pygame.draw.circle(surface, self.color, (int(self.x), int(self.y)), self.size)
        pygame.draw.circle(surface, (255, 255, 255), (int(self.x), int(self.y)),
                           max(1, self.size >> 1))


# ═══════════════════════════════════════════════
# HologramRing (홀로그램 - 최적화)
# ═══════════════════════════════════════════════
class HologramRing:
    def __init__(self, center_x: float, center_y: float, radius: float):
        self.center_x = center_x
        self.center_y = center_y
        self.radius = radius
        self.target_radius = radius
        self.flicker_phase = random.uniform(0, math.pi * 2)
        self.flicker_speed = random.uniform(8, 15)
        self.base_color = random.choice([
            (100, 200, 255), (150, 100, 255), (100, 255, 200),
        ])
        self.thickness = 1
        self.segments = random.randint(12, 20)  # 32 → 20 축소
        self.distortion = [random.uniform(-3, 3) for _ in range(self.segments)]
        self.lifetime = random.uniform(0.4, 1.2)
        self.max_lifetime = self.lifetime

    def update(self, dt: float, new_center: Tuple[float, float] = None,
               new_radius: float = None) -> bool:
        self.lifetime -= dt
        self.flicker_phase += self.flicker_speed * dt
        if new_center:
            self.center_x, self.center_y = new_center
        if new_radius:
            self.target_radius = new_radius
            self.radius += (self.target_radius - self.radius) * 0.1
        for i in range(len(self.distortion)):
            self.distortion[i] += random.uniform(-0.8, 0.8)
            self.distortion[i] = max(-4, min(4, self.distortion[i]))
        return self.lifetime > 0

    def draw(self, surface: pygame.Surface, alpha_mult: float = 1.0):
        life_ratio = self.lifetime / self.max_lifetime
        flicker = 0.3 + 0.7 * (0.5 + 0.5 * math.sin(self.flicker_phase))
        if random.random() < 0.08:
            flicker *= random.uniform(0.2, 1.5)
        if life_ratio * flicker * alpha_mult < 0.1:
            return

        angle_step = (math.pi * 2) / self.segments
        for i in range(self.segments):
            if random.random() < 0.04:
                continue
            sa = i * angle_step
            ea = (i + 0.7) * angle_step
            r = self.radius + self.distortion[i]
            sx = int(self.center_x + math.cos(sa) * r)
            sy = int(self.center_y + math.sin(sa) * r)
            ex = int(self.center_x + math.cos(ea) * r)
            ey = int(self.center_y + math.sin(ea) * r)

            shift = int(math.sin(self.flicker_phase + i * 0.5) * 25)
            color = tuple(max(0, min(255, c + shift)) for c in self.base_color)
            pygame.draw.line(surface, color, (sx, sy), (ex, ey), self.thickness)


# ═══════════════════════════════════════════════
# VortexRing (소용돌이 링)
# ═══════════════════════════════════════════════
class VortexRing:
    def __init__(self, center_x: float, center_y: float, radius: float):
        self.center_x = center_x
        self.center_y = center_y
        self.radius = radius
        self.angle = random.uniform(0, math.pi * 2)
        self.rotation_speed = random.uniform(1, 3) * random.choice([-1, 1])
        self.color = random.choice([
            (100, 180, 255), (180, 100, 255), (255, 150, 200),
        ])
        self.thickness = random.randint(1, 2)
        self.dash_count = random.randint(6, 12)  # 16 → 12 축소

    def update(self, progress: float, dt: float):
        self.angle += self.rotation_speed * dt
        self.radius *= (1 - progress * 0.02)

    def draw(self, surface: pygame.Surface, alpha_mult: float = 1.0):
        if self.radius < 5:
            return
        dash_angle = (math.pi * 2) / self.dash_count
        for i in range(self.dash_count):
            sa = self.angle + i * dash_angle
            ea = sa + dash_angle * 0.5
            sx = int(self.center_x + math.cos(sa) * self.radius)
            sy = int(self.center_y + math.sin(sa) * self.radius)
            ex = int(self.center_x + math.cos(ea) * self.radius)
            ey = int(self.center_y + math.sin(ea) * self.radius)
            pygame.draw.line(surface, self.color, (sx, sy), (ex, ey), self.thickness)


# ═══════════════════════════════════════════════
# EnergyRing (에너지 링 - 최적화)
# ═══════════════════════════════════════════════
class EnergyRing:
    def __init__(self, center_x: float, center_y: float, start_radius: float = 10):
        self.center_x = center_x
        self.center_y = center_y
        self.radius = start_radius
        self.max_radius = start_radius * 4
        self.color = random.choice([
            (150, 200, 255), (200, 150, 255),
            (255, 200, 150), (150, 255, 200),
        ])
        self.thickness = 2
        self.lifetime = random.uniform(0.3, 0.5)
        self.max_lifetime = self.lifetime
        self.expansion_speed = random.uniform(100, 180)

    def update(self, dt: float, new_center: Tuple[float, float] = None) -> bool:
        self.lifetime -= dt
        self.radius += self.expansion_speed * dt
        if new_center:
            self.center_x, self.center_y = new_center
        return self.lifetime > 0 and self.radius < self.max_radius

    def draw(self, surface: pygame.Surface, alpha_mult: float = 1.0):
        life_ratio = self.lifetime / self.max_lifetime
        if life_ratio < 0.05:
            return
        r = int(self.radius)
        if r < 2:
            return
        # 직접 원 (Surface 생성 없음)
        fade_color = tuple(max(0, int(c * life_ratio)) for c in self.color)
        pygame.draw.circle(surface, fade_color,
                           (int(self.center_x), int(self.center_y)), r, self.thickness)


# ═══════════════════════════════════════════════════════════
# 메인 애니메이션 컨트롤러 (Performance Optimized HD)
# ═══════════════════════════════════════════════════════════

class BallSpawnAnimation:
    """공 생성 애니메이션 (Ultra Premium HD - Performance Optimized)

    ★ 성능 최적화:
    - 사전 할당 공유 레이어 Surface (매 프레임 재사용)
    - 파티클별 Surface 생성 완전 제거
    - GlowCache로 텍스처 재사용
    - 파티클 수 적정화 (시각적 품질 유지)

    시퀀스:
    1. Phase 1: 에너지 응축 (4초)
    2. Phase 2: 공 부양 (1.5초)
    3. Phase 3: 서브 이동 (2.5초)
    """

    PHASE_1_DURATION = 4.0
    PHASE_2_DURATION = 1.5
    PHASE_3_DURATION = 2.5
    TOTAL_DURATION = PHASE_1_DURATION + PHASE_2_DURATION + PHASE_3_DURATION  # 8초

    # 파티클 수 제한 (성능/품질 균형)
    MAX_QUANTUM_PARTICLES = 100
    MAX_COSMIC_DUST = 50
    MAX_PLASMA_TENDRILS = 5
    MAX_NEBULAE = 8
    MAX_ORBITING_ORBS = 4
    MAX_CHROMATIC_RAYS = 8
    MAX_ENERGY_RINGS = 3
    MAX_ELECTRIC_ARCS = 4

    def __init__(self, screen_width: int, screen_height: int):
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.center_x = screen_width // 2
        self.center_y = screen_height // 2

        # 상태
        self.active = False
        self.completed = False
        self.elapsed_time = 0.0
        self.current_phase = 0

        # 서브
        self.is_player_serve = True
        self.player_y = screen_height - 100
        self.boss_y = 100

        # 공 상태
        self.ball_x = float(self.center_x)
        self.ball_y = float(self.center_y)
        self.ball_radius = 12
        self.ball_visible = False
        self.ball_alpha = 0
        self.ball_scale = 0.1
        self.levitate_offset = 0.0
        self.levitate_speed = 3.0

        # ★ 사전 할당 공유 Surface (코어 글로우 + 공 렌더링용)
        # 작은 고정 크기 (최대 코어 글로우 반경 * 4)
        self._core_surf_size = 280
        self._core_surf = pygame.Surface((self._core_surf_size, self._core_surf_size), pygame.SRCALPHA)
        self._ball_surf_size = 120
        self._ball_surf = pygame.Surface((self._ball_surf_size, self._ball_surf_size), pygame.SRCALPHA)
        # 플래시용 (화면 크기)
        self._flash_surf = pygame.Surface((screen_width, screen_height), pygame.SRCALPHA)

        # 파티클 시스템
        self.quantum_particles: List[QuantumParticle] = []
        self.lightning_bolts: List[EnhancedLightningBolt] = []
        self.chain_lightnings: List[ChainLightning] = []
        self.vortex_rings: List[VortexRing] = []
        self.electric_arcs: List[ElectricArc] = []
        self.sparks: List[Spark] = []
        self.hologram_rings: List[HologramRing] = []
        self.energy_rings: List[EnergyRing] = []
        self.cosmic_dust: List[CosmicDust] = []
        self.plasma_tendrils: List[PlasmaTendril] = []
        self.orbiting_orbs: List[OrbitingOrb] = []
        self.shockwave_rings: List[ShockwaveRing] = []
        self.after_images: List[AfterImage] = []
        self.chromatic_rays: List[ChromaticRay] = []
        self.energy_nebulae: List[EnergyNebula] = []

        # 스폰 타이머
        self.particle_spawn_timer = 0.0
        self.lightning_spawn_timer = 0.0
        self.arc_spawn_timer = 0.0
        self.spark_spawn_timer = 0.0
        self.hologram_spawn_timer = 0.0
        self.energy_ring_timer = 0.0
        self.tendril_spawn_timer = 0.0
        self.ray_spawn_timer = 0.0
        self.afterimage_timer = 0.0

        # 효과음 플래그
        self.sounds_played = {'condensing': False, 'formed': False, 'moving': False}

        # 시각 효과 상태
        self.flash_alpha = 0
        self.flash_color = (255, 255, 255)
        self.core_glow_radius = 0.0
        self.core_glow_alpha = 0
        self.pulse_phase = 0.0
        self.pulse_speed = 2.5

    def start(self, is_player_serve: bool, player_y: Optional[float] = None,
              boss_y: Optional[float] = None):
        self.active = True
        self.completed = False
        self.elapsed_time = 0.0
        self.current_phase = 1

        self.is_player_serve = is_player_serve
        if player_y is not None:
            self.player_y = player_y
        if boss_y is not None:
            self.boss_y = boss_y

        self.ball_x = float(self.center_x)
        self.ball_y = float(self.center_y)
        self.ball_visible = False
        self.ball_alpha = 0
        self.ball_scale = 0.1
        self.levitate_offset = 0.0

        # 모든 파티클 클리어
        for lst in [self.quantum_particles, self.lightning_bolts, self.chain_lightnings,
                    self.vortex_rings, self.electric_arcs, self.sparks, self.hologram_rings,
                    self.energy_rings, self.cosmic_dust, self.plasma_tendrils,
                    self.orbiting_orbs, self.shockwave_rings, self.after_images,
                    self.chromatic_rays, self.energy_nebulae]:
            lst.clear()

        self._spawn_initial_particles()

        self.sounds_played = {'condensing': False, 'formed': False, 'moving': False}
        self.flash_alpha = 0
        self.core_glow_radius = 0.0
        self.core_glow_alpha = 0
        self.pulse_phase = 0.0

        # 타이머 리셋
        self.particle_spawn_timer = 0.0
        self.lightning_spawn_timer = 0.0
        self.arc_spawn_timer = 0.0
        self.spark_spawn_timer = 0.0
        self.hologram_spawn_timer = 0.0
        self.energy_ring_timer = 0.0
        self.tendril_spawn_timer = 0.0
        self.ray_spawn_timer = 0.0
        self.afterimage_timer = 0.0

    def _spawn_initial_particles(self):
        max_radius = min(self.screen_width, self.screen_height) * 0.4

        # 양자 입자 (60-80개, 이전 80-120)
        for _ in range(random.randint(60, 80)):
            self.quantum_particles.append(
                QuantumParticle(self.center_x, self.center_y, max_radius))

        # 소용돌이 링 (5-8개)
        for i in range(random.randint(5, 8)):
            self.vortex_rings.append(
                VortexRing(self.center_x, self.center_y, max_radius * (0.2 + i * 0.1)))

        # 우주 먼지 (50개)
        for _ in range(self.MAX_COSMIC_DUST):
            self.cosmic_dust.append(
                CosmicDust(self.screen_width, self.screen_height, self.center_x, self.center_y))

        # 성운 (6개)
        for _ in range(random.randint(5, self.MAX_NEBULAE)):
            self.energy_nebulae.append(
                EnergyNebula(self.center_x, self.center_y, max_radius))

        # 플라즈마 촉수 (3개)
        for _ in range(3):
            self.plasma_tendrils.append(
                PlasmaTendril(self.center_x, self.center_y, max_radius))

    def stop(self):
        self.active = False

    def is_active(self) -> bool:
        return self.active

    def is_complete(self) -> bool:
        return self.completed

    def get_ball_position(self) -> Tuple[float, float]:
        return (self.ball_x, self.ball_y)

    def update(self, dt: float):
        if not self.active:
            return

        original_dt = dt
        dt = min(dt, 0.033)
        if original_dt > 0.05:
            print(f"[DEBUG] dt 제한됨: {original_dt:.3f}s -> {dt:.3f}s")

        self.elapsed_time += dt
        self.pulse_phase += self.pulse_speed * dt

        if self.elapsed_time < self.PHASE_1_DURATION:
            self.current_phase = 1
            self._update_phase_1(dt)
        elif self.elapsed_time < self.PHASE_1_DURATION + self.PHASE_2_DURATION:
            self.current_phase = 2
            self._update_phase_2(dt)
        elif self.elapsed_time < self.TOTAL_DURATION:
            self.current_phase = 3
            self._update_phase_3(dt)
        else:
            if not self.completed:
                self.completed = True
            self.active = False
            self.ball_visible = True
            self.ball_alpha = 255
            self.ball_scale = 1.0

    def _update_phase_1(self, dt: float):
        progress = self.elapsed_time / self.PHASE_1_DURATION

        for p in self.quantum_particles:
            p.update(progress, dt)
        for ring in self.vortex_rings:
            ring.update(progress, dt)

        # 번개
        self.lightning_spawn_timer += dt
        interval = max(0.05, 0.25 - progress * 0.2)
        if self.lightning_spawn_timer >= interval:
            self.lightning_spawn_timer = 0
            self._spawn_lightning(progress)

        if random.random() < 0.015 * (1 + progress):
            self._spawn_chain_lightning()

        self.lightning_bolts = [b for b in self.lightning_bolts if b.update(dt)]
        self.chain_lightnings = [c for c in self.chain_lightnings if c.update(dt)]

        # 전기 아크 (후반)
        if progress > 0.5:
            self.arc_spawn_timer += dt
            if self.arc_spawn_timer >= 0.4 and len(self.electric_arcs) < self.MAX_ELECTRIC_ARCS:
                self.arc_spawn_timer = 0
                r = max(15, 50 * (1 - (progress - 0.5) * 1.5))
                self.electric_arcs.append(ElectricArc(self.center_x, self.center_y, r))

        self.electric_arcs = [a for a in self.electric_arcs
                              if a.update(dt, (self.center_x, self.center_y))]

        # 추가 파티클
        self.particle_spawn_timer += dt
        if self.particle_spawn_timer >= 0.5 and len(self.quantum_particles) < self.MAX_QUANTUM_PARTICLES:
            self.particle_spawn_timer = 0
            mr = min(self.screen_width, self.screen_height) * 0.4 * (1 - progress * 0.5)
            for _ in range(random.randint(5, 10)):
                self.quantum_particles.append(QuantumParticle(self.center_x, self.center_y, mr))

        # HD 효과
        for d in self.cosmic_dust:
            d.update(progress, dt)
        for n in self.energy_nebulae:
            n.update(progress, dt)

        self.plasma_tendrils = [t for t in self.plasma_tendrils if t.update(progress, dt)]
        self.tendril_spawn_timer += dt
        if self.tendril_spawn_timer >= 1.0 and len(self.plasma_tendrils) < self.MAX_PLASMA_TENDRILS:
            self.tendril_spawn_timer = 0
            mr = min(self.screen_width, self.screen_height) * 0.4 * (1 - progress * 0.3)
            self.plasma_tendrils.append(PlasmaTendril(self.center_x, self.center_y, mr))

        # 색채 광선 (중반 이후)
        if progress > 0.35:
            self.ray_spawn_timer += dt
            if self.ray_spawn_timer >= 0.15 and len(self.chromatic_rays) < self.MAX_CHROMATIC_RAYS:
                self.ray_spawn_timer = 0
                angle = random.uniform(0, math.pi * 2)
                length = random.uniform(40, 100) * (1 - progress * 0.3)
                self.chromatic_rays.append(ChromaticRay(self.center_x, self.center_y, angle, length))

        self.chromatic_rays = [r for r in self.chromatic_rays if r.update(dt)]

        # 코어 글로우
        pulse = 0.85 + 0.15 * math.sin(self.pulse_phase * 3)
        self.core_glow_radius = (18 + progress * 40) * pulse
        self.core_glow_alpha = int((90 + progress * 140) * pulse)

        if progress > 0.93:
            self.flash_alpha = int(255 * (progress - 0.93) * 14.3)
            self.flash_color = (220, 240, 255)

    def _update_phase_2(self, dt: float):
        phase_time = self.elapsed_time - self.PHASE_1_DURATION
        progress = phase_time / self.PHASE_2_DURATION

        self.ball_visible = True
        self.ball_alpha = min(255, int(progress * 400))
        self.ball_scale = min(1.0, 0.3 + progress * 0.7)

        self.levitate_offset = math.sin(phase_time * self.levitate_speed * 2) * 10
        self.ball_y = self.center_y + self.levitate_offset

        # 에너지 링
        self.energy_ring_timer += dt
        if self.energy_ring_timer >= 0.4 and len(self.energy_rings) < self.MAX_ENERGY_RINGS:
            self.energy_ring_timer = 0
            self.energy_rings.append(EnergyRing(self.ball_x, self.ball_y, self.ball_radius * self.ball_scale))

        self.energy_rings = [r for r in self.energy_rings if r.update(dt, (self.ball_x, self.ball_y))]

        # 전기 아크
        self.arc_spawn_timer += dt
        if self.arc_spawn_timer >= 0.35 and len(self.electric_arcs) < self.MAX_ELECTRIC_ARCS:
            self.arc_spawn_timer = 0
            self.electric_arcs.append(
                ElectricArc(self.ball_x, self.ball_y, self.ball_radius * 2 * self.ball_scale))

        self.electric_arcs = [a for a in self.electric_arcs if a.update(dt, (self.ball_x, self.ball_y))]

        # 궤도 구체
        if progress < 0.3 and len(self.orbiting_orbs) < self.MAX_ORBITING_ORBS:
            for orbit_r in [25, 40, 55]:
                if len(self.orbiting_orbs) < self.MAX_ORBITING_ORBS:
                    self.orbiting_orbs.append(OrbitingOrb(self.ball_x, self.ball_y, orbit_r))

        for orb in self.orbiting_orbs:
            orb.update(dt, (self.ball_x, self.ball_y))

        # 충격파
        if progress < 0.08 and len(self.shockwave_rings) == 0:
            self.shockwave_rings.append(ShockwaveRing(self.center_x, self.center_y, 160))

        self.shockwave_rings = [s for s in self.shockwave_rings if s.update(dt, (self.ball_x, self.ball_y))]

        # 페이드아웃
        if progress > 0.4:
            # 우주먼지/성운 빠르게 제거
            remove_count = max(1, int(len(self.cosmic_dust) * 0.08))
            for _ in range(remove_count):
                if self.cosmic_dust:
                    self.cosmic_dust.pop(random.randint(0, len(self.cosmic_dust) - 1))
            remove_count = max(1, int(len(self.energy_nebulae) * 0.1))
            for _ in range(remove_count):
                if self.energy_nebulae:
                    self.energy_nebulae.pop(random.randint(0, len(self.energy_nebulae) - 1))

        self.quantum_particles = [p for p in self.quantum_particles if random.random() > 0.12]
        self.plasma_tendrils = [t for t in self.plasma_tendrils if random.random() > 0.15]
        self.chromatic_rays = [r for r in self.chromatic_rays if r.update(dt)]

        self.flash_alpha = max(0, int(255 * (1 - progress)))
        self.core_glow_radius = 45 - progress * 22
        self.core_glow_alpha = int(200 * (1 - progress * 0.5))

        if not self.sounds_played['formed'] and progress > 0.1:
            self.sounds_played['formed'] = True

    def _update_phase_3(self, dt: float):
        phase_time = self.elapsed_time - self.PHASE_1_DURATION - self.PHASE_2_DURATION
        progress = phase_time / self.PHASE_3_DURATION

        eased = 1 - (1 - progress) ** 3
        target_y = self.player_y if self.is_player_serve else self.boss_y
        prev_ball_y = self.ball_y

        self.ball_y = self.center_y + (target_y - self.center_y) * eased
        levitate_amp = 8 * (1 - eased)
        self.levitate_offset = math.sin(phase_time * self.levitate_speed * 2) * levitate_amp
        self.ball_y += self.levitate_offset

        self.ball_alpha = 255
        self.ball_scale = 1.0

        # 홀로그램
        self.hologram_spawn_timer += dt
        if self.hologram_spawn_timer >= 0.2:
            self.hologram_spawn_timer = 0
            for rm in [1.5, 2.5, 3.5]:
                self.hologram_rings.append(HologramRing(self.ball_x, self.ball_y, self.ball_radius * rm))

        self.hologram_rings = [h for h in self.hologram_rings if h.update(dt, (self.ball_x, self.ball_y))]

        # 스파크
        speed = abs(self.ball_y - prev_ball_y) / dt if dt > 0 else 0
        self.spark_spawn_timer += dt
        if self.spark_spawn_timer >= 0.07 and speed > 10:
            self.spark_spawn_timer = 0
            move_dir = math.pi / 2 if self.ball_y > prev_ball_y else -math.pi / 2
            for _ in range(random.randint(1, 3)):
                sd = move_dir + math.pi + random.uniform(-0.8, 0.8)
                self.sparks.append(Spark(self.ball_x + random.uniform(-8, 8),
                                         self.ball_y + random.uniform(-4, 4), sd))

        self.sparks = [s for s in self.sparks if s.update(dt)]

        # 전기 아크
        self.arc_spawn_timer += dt
        if self.arc_spawn_timer >= 0.15 and len(self.electric_arcs) < self.MAX_ELECTRIC_ARCS:
            self.arc_spawn_timer = 0
            self.electric_arcs.append(ElectricArc(self.ball_x, self.ball_y, self.ball_radius * 2))

        self.electric_arcs = [a for a in self.electric_arcs if a.update(dt, (self.ball_x, self.ball_y))]

        # 에너지 링
        self.energy_ring_timer += dt
        if self.energy_ring_timer >= 0.45 and len(self.energy_rings) < self.MAX_ENERGY_RINGS:
            self.energy_ring_timer = 0
            self.energy_rings.append(EnergyRing(self.ball_x, self.ball_y, self.ball_radius))

        self.energy_rings = [r for r in self.energy_rings if r.update(dt, (self.ball_x, self.ball_y))]

        # 잔상
        self.afterimage_timer += dt
        if self.afterimage_timer >= 0.08 and speed > 5:
            self.afterimage_timer = 0
            self.after_images.append(AfterImage(self.ball_x, self.ball_y, self.ball_radius, (180, 220, 255)))

        self.after_images = [a for a in self.after_images if a.update(dt)]

        # 궤도 구체 흡수
        for orb in self.orbiting_orbs:
            orb.orbit_radius = max(5, orb.orbit_radius * (1 - dt * 0.8))
            orb.update(dt, (self.ball_x, self.ball_y))
        self.orbiting_orbs = [o for o in self.orbiting_orbs if o.orbit_radius > 5]

        # 충격파
        if progress < 0.04 and len(self.shockwave_rings) == 0:
            self.shockwave_rings.append(ShockwaveRing(self.ball_x, self.ball_y, 130))
        if progress > 0.93 and len(self.shockwave_rings) == 0:
            self.shockwave_rings.append(ShockwaveRing(self.ball_x, self.ball_y, 100))

        self.shockwave_rings = [s for s in self.shockwave_rings if s.update(dt, (self.ball_x, self.ball_y))]

        # 페이드아웃
        self.quantum_particles = [p for p in self.quantum_particles if random.random() > 0.08]
        if self.cosmic_dust and random.random() < 0.1:
            self.cosmic_dust.pop(random.randint(0, len(self.cosmic_dust) - 1))

        self.core_glow_alpha = int(80 * (1 - progress))

        if progress > 0.9:
            ap = (progress - 0.9) / 0.1
            self.flash_alpha = int(100 * ap * (1 - ap) * 4)
            self.flash_color = (255, 255, 230)

    def _spawn_lightning(self, progress: float):
        mr = min(self.screen_width, self.screen_height) * 0.4 * (1 - progress * 0.5)
        num = random.randint(1, 2)
        for _ in range(num):
            angle = random.uniform(0, math.pi * 2)
            sd = mr * random.uniform(0.6, 1.0)
            sx = self.center_x + math.cos(angle) * sd
            sy = self.center_y + math.sin(angle) * sd
            ed = max(10, sd * (1 - progress) * random.uniform(0.2, 0.5))
            ea = angle + random.uniform(-0.4, 0.4)
            ex = self.center_x + math.cos(ea) * ed
            ey = self.center_y + math.sin(ea) * ed
            self.lightning_bolts.append(EnhancedLightningBolt(sx, sy, ex, ey))

        if random.random() < 0.3 and len(self.quantum_particles) >= 2:
            p1, p2 = random.sample(self.quantum_particles, 2)
            self.lightning_bolts.append(
                EnhancedLightningBolt(p1.x, p1.y, p2.x, p2.y, branch_depth=1))

    def _spawn_chain_lightning(self):
        if len(self.quantum_particles) < 4:
            return
        n = random.randint(3, min(4, len(self.quantum_particles)))
        selected = random.sample(self.quantum_particles, n)
        points = [(p.x, p.y) for p in selected]
        self.chain_lightnings.append(ChainLightning(points))

    def draw(self, surface: pygame.Surface, ball_color: Tuple[int, int, int] = (255, 255, 255)):
        if not self.active and not self.ball_visible:
            return

        # ── 레이어 1: 배경 ──
        for n in self.energy_nebulae:
            n.draw(surface)
        for d in self.cosmic_dust:
            d.draw(surface)
        for ring in self.vortex_rings:
            ring.draw(surface)

        # ── 레이어 2: 중간 효과 ──
        for r in self.energy_rings:
            r.draw(surface)
        for sw in self.shockwave_rings:
            sw.draw(surface)

        progress = min(1.0, self.elapsed_time / self.PHASE_1_DURATION) if self.current_phase == 1 else 1.0
        for t in self.plasma_tendrils:
            t.draw(surface, progress)

        alpha_mult = 1.0 if self.current_phase == 1 else max(0.1, 1.0 - (self.current_phase - 1) * 0.4)
        for p in self.quantum_particles:
            p.draw(surface, alpha_mult)

        # ── 레이어 3: 번개/아크 ──
        for r in self.chromatic_rays:
            r.draw(surface)
        for c in self.chain_lightnings:
            c.draw(surface)
        for b in self.lightning_bolts:
            b.draw(surface)
        for a in self.electric_arcs:
            a.draw(surface)

        # ── 레이어 4: 코어/공 ──
        for h in self.hologram_rings:
            h.draw(surface)

        if self.core_glow_alpha > 0 and self.core_glow_radius > 2:
            self._draw_core_glow(surface)

        for orb in self.orbiting_orbs:
            orb.draw(surface)
        for ai in self.after_images:
            ai.draw(surface)

        if self.ball_visible and self.ball_alpha > 0:
            self._draw_ball(surface, ball_color)

        # ── 레이어 5: 전경 ──
        for s in self.sparks:
            s.draw(surface)

        if self.flash_alpha > 0:
            self._flash_surf.fill((0, 0, 0, 0))
            self._flash_surf.fill((*self.flash_color, min(255, self.flash_alpha)))
            surface.blit(self._flash_surf, (0, 0))

    def _draw_core_glow(self, surface: pygame.Surface):
        """코어 글로우 - 사전 할당 Surface 재사용"""
        pulse = 0.85 + 0.15 * math.sin(self.pulse_phase * 3)
        r = int(self.core_glow_radius * pulse)
        if r < 2:
            return

        # 캐시 사용
        glow = GlowCache.get(min(r, 60), (200, 220, 255), layers=4)
        gw, gh = glow.get_size()
        surface.blit(glow, (int(self.center_x - gw // 2), int(self.center_y - gh // 2)))

    def _draw_ball(self, surface: pygame.Surface, ball_color: Tuple[int, int, int]):
        """공 그리기 - 사전 할당 Surface 재사용"""
        radius = int(self.ball_radius * self.ball_scale)
        if radius <= 0:
            return

        # 사전 할당 _ball_surf 재사용
        self._ball_surf.fill((0, 0, 0, 0))
        half = self._ball_surf_size // 2

        # 외부 글로우 (2단계로 축소)
        for r in range(min(radius * 3, half - 1), radius, -3):
            ratio = (r - radius) / max(1, radius * 2)
            a = int(self.ball_alpha * 0.15 * ratio)
            gc = tuple(min(255, c + 20) for c in ball_color)
            pygame.draw.circle(self._ball_surf, (*gc, a), (half, half), r)

        # 메인 공
        pygame.draw.circle(self._ball_surf, (*ball_color, self.ball_alpha), (half, half), radius)

        # 하이라이트
        hl_pos = (half - radius // 3, half - radius // 3)
        hl_r = max(2, radius // 3)
        pygame.draw.circle(self._ball_surf, (255, 255, 255, int(self.ball_alpha * 0.9)),
                           hl_pos, hl_r)
        # 작은 하이라이트
        pygame.draw.circle(self._ball_surf, (255, 255, 255, self.ball_alpha),
                           (half - radius // 4, half - radius // 4), max(1, radius // 5))

        # 림라이트
        pygame.draw.circle(self._ball_surf, (200, 220, 255, int(self.ball_alpha * 0.3)),
                           (half, half), radius, 1)

        surface.blit(self._ball_surf, (int(self.ball_x - half), int(self.ball_y - half)))


# ═══════════════════════════════════════════════
# 전역 API (변경 없음)
# ═══════════════════════════════════════════════

_ball_spawn_animation: Optional[BallSpawnAnimation] = None


def get_ball_spawn_animation() -> BallSpawnAnimation:
    global _ball_spawn_animation
    if _ball_spawn_animation is None:
        _ball_spawn_animation = BallSpawnAnimation(800, 600)
    return _ball_spawn_animation


def init_ball_spawn_animation(width: int, height: int):
    global _ball_spawn_animation
    _ball_spawn_animation = BallSpawnAnimation(width, height)


def start_ball_spawn_animation(is_player_serve: bool, player_y: float, boss_y: float):
    anim = get_ball_spawn_animation()
    anim.start(is_player_serve, player_y, boss_y)


def update_ball_spawn_animation(dt: float):
    anim = get_ball_spawn_animation()
    if anim.is_active():
        anim.update(dt)


def draw_ball_spawn_animation(surface: pygame.Surface,
                               ball_color: Tuple[int, int, int] = (255, 255, 255)):
    anim = get_ball_spawn_animation()
    if anim.is_active():
        anim.draw(surface, ball_color)


def is_ball_spawn_animation_active() -> bool:
    anim = get_ball_spawn_animation()
    return anim.is_active()


def is_ball_spawn_animation_complete() -> bool:
    anim = get_ball_spawn_animation()
    return anim.is_complete()


def get_spawned_ball_position() -> Tuple[float, float]:
    anim = get_ball_spawn_animation()
    return anim.get_ball_position()


def get_ball_spawn_animation_elapsed_time() -> float:
    anim = get_ball_spawn_animation()
    if anim.is_active():
        return anim.elapsed_time
    return 0.0


def get_ball_spawn_animation_total_duration() -> float:
    anim = get_ball_spawn_animation()
    return anim.TOTAL_DURATION
