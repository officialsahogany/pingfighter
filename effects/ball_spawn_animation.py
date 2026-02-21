# -*- coding: utf-8 -*-
"""Ball Spawn Animation - 공 생성 애니메이션 시스템 (Ultra Premium HD Edition)

스테이지 시작 시 공이 양자 에너지/번개 소용돌이로 응축되어 생성되는
초고퀄리티 애니메이션을 담당합니다.

애니메이션 시퀀스:
1. 에너지 응축 (4초) - 우주 먼지 + 양자 자기장 + 플라즈마 촉수 + 강화된 번개 회오리 + 전기 아크
2. 공 부양 (1.5초) - 완성된 공이 제자리에서 천천히 위아래로 부양 + 궤도 구체 + 에너지 링
3. 서브 이동 (2.5초) - 잔상 효과 + 홀로그램 효과 + 스파크 튀김 + 충격파 링 + 전기 아크로 이동

총 8초의 애니메이션 후 게임 시작
"""

import math
import random
import pygame
from typing import List, Tuple, Optional


# ─────────────────────────────────────────────
# 새 효과 클래스: CosmicDust (우주 먼지 배경)
# ─────────────────────────────────────────────
class CosmicDust:
    """우주 먼지 입자 - 은하/성운 느낌의 미세 반짝임 배경"""

    def __init__(self, screen_width: int, screen_height: int, center_x: float, center_y: float):
        # 화면 내 랜덤 위치
        angle = random.uniform(0, math.pi * 2)
        dist = random.uniform(30, max(screen_width, screen_height) * 0.5)
        self.x = center_x + math.cos(angle) * dist
        self.y = center_y + math.sin(angle) * dist
        self.center_x = center_x
        self.center_y = center_y

        # 느린 회전 궤도
        self.angle = angle
        self.orbit_radius = dist
        self.orbit_speed = random.uniform(0.005, 0.02) * random.choice([-1, 1])

        # 깜빡임
        self.twinkle_phase = random.uniform(0, math.pi * 2)
        self.twinkle_speed = random.uniform(2, 6)
        self.base_brightness = random.uniform(0.2, 0.8)

        # 크기 (매우 작은 먼지)
        self.size = random.uniform(0.5, 2.5)

        # 색상 (차가운 우주 색상 팔레트)
        palette = random.random()
        if palette < 0.3:
            self.color = (180, 200, 255)   # 아이스 블루
        elif palette < 0.5:
            self.color = (200, 180, 255)   # 라벤더
        elif palette < 0.65:
            self.color = (255, 220, 240)   # 소프트 핑크
        elif palette < 0.8:
            self.color = (220, 255, 250)   # 민트
        else:
            self.color = (255, 255, 240)   # 웜 화이트

    def update(self, progress: float, dt: float):
        self.twinkle_phase += self.twinkle_speed * dt
        self.angle += self.orbit_speed * dt

        # 진행하면서 중심으로 약간 당겨짐
        pull = 1 - progress * 0.3
        current_r = self.orbit_radius * pull
        self.x = self.center_x + math.cos(self.angle) * current_r
        self.y = self.center_y + math.sin(self.angle) * current_r

    def draw(self, surface: pygame.Surface, alpha_mult: float = 1.0):
        brightness = self.base_brightness * (0.5 + 0.5 * math.sin(self.twinkle_phase))
        alpha = int(180 * brightness * alpha_mult)
        if alpha < 10:
            return

        ix, iy = int(self.x), int(self.y)

        if self.size >= 1.5:
            # 큰 먼지는 글로우 포함
            glow_r = int(self.size * 3)
            glow_surf = pygame.Surface((glow_r * 2, glow_r * 2), pygame.SRCALPHA)
            for r in range(glow_r, 0, -1):
                a = int(alpha * 0.15 * (r / glow_r))
                pygame.draw.circle(glow_surf, (*self.color, a), (glow_r, glow_r), r)
            surface.blit(glow_surf, (ix - glow_r, iy - glow_r))

        # 코어 점
        pygame.draw.circle(surface, (*self.color[:3],), (ix, iy), max(1, int(self.size)))


# ─────────────────────────────────────────────
# 새 효과 클래스: PlasmaTendril (플라즈마 촉수)
# ─────────────────────────────────────────────
class PlasmaTendril:
    """플라즈마 촉수 - 유기적 에너지 촉수가 중심으로 흡수됨"""

    def __init__(self, center_x: float, center_y: float, max_radius: float):
        self.center_x = center_x
        self.center_y = center_y

        # 시작 각도/거리
        self.base_angle = random.uniform(0, math.pi * 2)
        self.length = max_radius * random.uniform(0.5, 0.9)

        # 제어점 (베지에 커브용)
        self.num_segments = random.randint(12, 20)
        self.control_offsets = [random.uniform(-25, 25) for _ in range(self.num_segments)]
        self.wave_phases = [random.uniform(0, math.pi * 2) for _ in range(self.num_segments)]
        self.wave_speeds = [random.uniform(2, 5) for _ in range(self.num_segments)]

        # 색상
        c = random.random()
        if c < 0.35:
            self.color = (120, 180, 255)   # 일렉트릭 블루
        elif c < 0.65:
            self.color = (180, 120, 255)   # 바이올렛
        else:
            self.color = (255, 140, 220)   # 일렉트릭 핑크

        self.thickness = random.randint(2, 4)
        self.lifetime = random.uniform(1.0, 3.0)
        self.max_lifetime = self.lifetime
        self.pulse_phase = random.uniform(0, math.pi * 2)
        self.pulse_speed = random.uniform(4, 8)

    def update(self, progress: float, dt: float) -> bool:
        self.lifetime -= dt
        self.pulse_phase += self.pulse_speed * dt

        # 파동 업데이트
        for i in range(self.num_segments):
            self.wave_phases[i] += self.wave_speeds[i] * dt

        return self.lifetime > 0

    def draw(self, surface: pygame.Surface, draw_progress: float, alpha_mult: float = 1.0):
        life_ratio = self.lifetime / self.max_lifetime
        pulse = 0.6 + 0.4 * math.sin(self.pulse_phase)
        alpha = int(200 * life_ratio * pulse * alpha_mult)
        if alpha < 10:
            return

        # 촉수 포인트 계산
        points = []
        effective_length = self.length * (1 - draw_progress * 0.8)

        for i in range(self.num_segments + 1):
            t = i / self.num_segments
            dist = effective_length * (1 - t)  # 끝에서 중심으로
            angle = self.base_angle

            # 파동 오프셋
            if i < self.num_segments:
                wave = math.sin(self.wave_phases[min(i, len(self.wave_phases) - 1)]) * self.control_offsets[min(i, len(self.control_offsets) - 1)] * (1 - t)
            else:
                wave = 0

            # 수직 방향 오프셋
            perp_angle = angle + math.pi / 2
            px = self.center_x + math.cos(angle) * dist + math.cos(perp_angle) * wave
            py = self.center_y + math.sin(angle) * dist + math.sin(perp_angle) * wave
            points.append((int(px), int(py)))

        if len(points) < 2:
            return

        # 외부 글로우
        glow_color = tuple(min(255, c + 40) for c in self.color)
        glow_alpha = max(0, int(alpha * 0.25))
        for i in range(len(points) - 1):
            pygame.draw.line(surface, (*glow_color[:3],), points[i], points[i + 1],
                             self.thickness + 4)

        # 메인 촉수
        for i in range(len(points) - 1):
            # 두께 그라데이션 (끝이 가늘어짐)
            seg_t = i / max(1, len(points) - 1)
            seg_thick = max(1, int(self.thickness * (1 - seg_t * 0.6)))
            pygame.draw.line(surface, self.color, points[i], points[i + 1], seg_thick + 1)

        # 밝은 코어
        core_color = tuple(min(255, c + 80) for c in self.color)
        for i in range(len(points) - 1):
            seg_t = i / max(1, len(points) - 1)
            seg_thick = max(1, int((self.thickness - 1) * (1 - seg_t * 0.7)))
            pygame.draw.line(surface, core_color, points[i], points[i + 1], seg_thick)

        # 끝점 글로우
        if len(points) > 0:
            tip = points[0]
            tip_glow_size = int(self.thickness * 2.5)
            tip_surf = pygame.Surface((tip_glow_size * 2, tip_glow_size * 2), pygame.SRCALPHA)
            for r in range(tip_glow_size, 0, -1):
                a = int(alpha * 0.4 * (r / tip_glow_size))
                pygame.draw.circle(tip_surf, (*self.color, a), (tip_glow_size, tip_glow_size), r)
            surface.blit(tip_surf, (tip[0] - tip_glow_size, tip[1] - tip_glow_size))


# ─────────────────────────────────────────────
# 새 효과 클래스: OrbitingOrb (궤도 에너지 구체)
# ─────────────────────────────────────────────
class OrbitingOrb:
    """궤도 구체 - 형성 중인 공 주위를 도는 작은 에너지 구"""

    def __init__(self, center_x: float, center_y: float, orbit_radius: float):
        self.center_x = center_x
        self.center_y = center_y
        self.orbit_radius = orbit_radius
        self.angle = random.uniform(0, math.pi * 2)
        self.speed = random.uniform(3, 6) * random.choice([-1, 1])
        self.size = random.uniform(3, 7)

        # 타원 궤도 (3D 느낌)
        self.tilt = random.uniform(0.3, 0.8)  # Y축 압축 비율
        self.tilt_offset = random.uniform(0, math.pi * 2)

        # 색상
        c = random.random()
        if c < 0.3:
            self.color = (100, 200, 255)   # 시안 블루
        elif c < 0.6:
            self.color = (200, 140, 255)   # 퍼플
        elif c < 0.8:
            self.color = (255, 180, 220)   # 핑크
        else:
            self.color = (180, 255, 220)   # 민트 그린

        self.trail: List[Tuple[float, float, float]] = []
        self.trail_length = 12
        self.pulse_phase = random.uniform(0, math.pi * 2)

    def update(self, dt: float, new_center: Tuple[float, float] = None):
        if new_center:
            self.center_x, self.center_y = new_center

        self.angle += self.speed * dt
        self.pulse_phase += 5 * dt

        # 위치 계산 (타원 궤도)
        x = self.center_x + math.cos(self.angle) * self.orbit_radius
        y = self.center_y + math.sin(self.angle) * self.orbit_radius * self.tilt

        # 잔상 저장
        self.trail.append((x, y, self.size))
        if len(self.trail) > self.trail_length:
            self.trail.pop(0)

        self.x = x
        self.y = y

    def draw(self, surface: pygame.Surface, alpha_mult: float = 1.0):
        pulse = 0.6 + 0.4 * math.sin(self.pulse_phase)
        alpha = int(220 * pulse * alpha_mult)

        # 잔상 그리기
        for i, (tx, ty, ts) in enumerate(self.trail):
            t_ratio = i / max(1, len(self.trail))
            trail_alpha = int(60 * t_ratio * alpha_mult)
            if trail_alpha > 5:
                trail_size = max(1, int(ts * t_ratio * 0.6))
                trail_color = tuple(min(255, c + 40) for c in self.color)
                trail_surf = pygame.Surface((trail_size * 4, trail_size * 4), pygame.SRCALPHA)
                pygame.draw.circle(trail_surf, (*trail_color, trail_alpha),
                                   (trail_size * 2, trail_size * 2), trail_size)
                surface.blit(trail_surf, (int(tx - trail_size * 2), int(ty - trail_size * 2)))

        # 글로우
        glow_size = int(self.size * 3)
        glow_surf = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
        for r in range(glow_size, 0, -1):
            a = int(alpha * 0.2 * (r / glow_size))
            glow_color = tuple(min(255, c + 30) for c in self.color)
            pygame.draw.circle(glow_surf, (*glow_color, a), (glow_size, glow_size), r)
        surface.blit(glow_surf, (int(self.x - glow_size), int(self.y - glow_size)))

        # 코어
        pygame.draw.circle(surface, self.color, (int(self.x), int(self.y)), int(self.size))
        # 하이라이트
        hl_size = max(1, int(self.size * 0.4))
        pygame.draw.circle(surface, (255, 255, 255),
                           (int(self.x - self.size * 0.2), int(self.y - self.size * 0.2)),
                           hl_size)


# ─────────────────────────────────────────────
# 새 효과 클래스: ShockwaveRing (충격파 링)
# ─────────────────────────────────────────────
class ShockwaveRing:
    """충격파 링 - 에너지 폭발 충격파"""

    def __init__(self, center_x: float, center_y: float, max_radius: float = 200):
        self.center_x = center_x
        self.center_y = center_y
        self.radius = 5
        self.max_radius = max_radius
        self.expansion_speed = random.uniform(200, 400)

        # 두께 (확장하면서 얇아짐)
        self.initial_thickness = random.randint(4, 8)

        # 색상
        c = random.random()
        if c < 0.4:
            self.color = (180, 220, 255)   # 아이스 블루
        elif c < 0.7:
            self.color = (220, 180, 255)   # 라벤더
        else:
            self.color = (255, 220, 255)   # 소프트 핑크

        self.lifetime = random.uniform(0.4, 0.8)
        self.max_lifetime = self.lifetime

        # 왜곡 효과
        self.distortion_points = random.randint(24, 48)
        self.distortion = [random.uniform(-3, 3) for _ in range(self.distortion_points)]

    def update(self, dt: float, new_center: Tuple[float, float] = None) -> bool:
        self.lifetime -= dt
        self.radius += self.expansion_speed * dt

        if new_center:
            self.center_x, self.center_y = new_center

        # 왜곡 업데이트
        for i in range(len(self.distortion)):
            self.distortion[i] += random.uniform(-1.5, 1.5)
            self.distortion[i] = max(-6, min(6, self.distortion[i]))

        return self.lifetime > 0 and self.radius < self.max_radius

    def draw(self, surface: pygame.Surface, alpha_mult: float = 1.0):
        life_ratio = self.lifetime / self.max_lifetime
        alpha = int(200 * life_ratio * alpha_mult)
        if alpha < 5:
            return

        thickness = max(1, int(self.initial_thickness * life_ratio))

        # 왜곡된 원 포인트 계산
        points = []
        for i in range(self.distortion_points):
            angle = (i / self.distortion_points) * math.pi * 2
            d = self.distortion[i] * (1 - life_ratio * 0.5)
            r = self.radius + d
            px = self.center_x + math.cos(angle) * r
            py = self.center_y + math.sin(angle) * r
            points.append((int(px), int(py)))

        if len(points) < 3:
            return

        # 외부 글로우 레이어
        glow_color = tuple(min(255, c + 40) for c in self.color)

        # 서피스 크기 계산
        r_int = int(self.radius + 20)
        size = r_int * 2 + 40
        cx_local = r_int + 20
        cy_local = r_int + 20

        if size < 4:
            return

        ring_surf = pygame.Surface((size, size), pygame.SRCALPHA)

        # 오프셋된 포인트
        offset_points = [(p[0] - int(self.center_x) + cx_local,
                          p[1] - int(self.center_y) + cy_local) for p in points]

        # 글로우 레이어 (3단계)
        for glow_offset, glow_opacity in [(6, 0.08), (3, 0.15), (1, 0.25)]:
            ga = max(0, int(alpha * glow_opacity))
            if ga > 0:
                pygame.draw.polygon(ring_surf, (*glow_color, ga), offset_points, thickness + glow_offset)

        # 메인 링
        main_alpha = max(0, int(alpha * 0.6))
        pygame.draw.polygon(ring_surf, (*self.color, main_alpha), offset_points, thickness)

        # 밝은 코어 라인
        core_alpha = max(0, int(alpha * 0.8))
        core_color = tuple(min(255, c + 80) for c in self.color)
        if thickness > 1:
            pygame.draw.polygon(ring_surf, (*core_color, core_alpha), offset_points, max(1, thickness - 1))

        surface.blit(ring_surf, (int(self.center_x) - cx_local, int(self.center_y) - cy_local))


# ─────────────────────────────────────────────
# 새 효과 클래스: AfterImage (잔상 효과)
# ─────────────────────────────────────────────
class AfterImage:
    """잔상 효과 - 공 이동 시 반투명 고스트 복사"""

    def __init__(self, x: float, y: float, radius: float, ball_color: Tuple[int, int, int]):
        self.x = x
        self.y = y
        self.radius = radius
        self.color = ball_color
        self.lifetime = 0.4
        self.max_lifetime = 0.4
        self.scale = 1.0

    def update(self, dt: float) -> bool:
        self.lifetime -= dt
        self.scale = 0.7 + 0.3 * (self.lifetime / self.max_lifetime)
        return self.lifetime > 0

    def draw(self, surface: pygame.Surface, alpha_mult: float = 1.0):
        life_ratio = self.lifetime / self.max_lifetime
        alpha = int(120 * life_ratio * alpha_mult)
        if alpha < 5:
            return

        r = int(self.radius * self.scale)
        if r <= 0:
            return

        # 글로우
        glow_size = r * 3
        glow_surf = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
        for gr in range(glow_size, r, -2):
            a = int(alpha * 0.15 * (gr - r) / (glow_size - r)) if glow_size > r else 0
            glow_color = tuple(min(255, c + 40) for c in self.color)
            pygame.draw.circle(glow_surf, (*glow_color, a), (glow_size, glow_size), gr)
        surface.blit(glow_surf, (int(self.x - glow_size), int(self.y - glow_size)))

        # 고스트 공
        pygame.draw.circle(surface, (*self.color[:3],), (int(self.x), int(self.y)), r)


# ─────────────────────────────────────────────
# 새 효과 클래스: ChromaticRay (색채 광선)
# ─────────────────────────────────────────────
class ChromaticRay:
    """색채 광선 - 중심에서 방사되는 무지개빛 광선"""

    def __init__(self, center_x: float, center_y: float, angle: float, length: float):
        self.center_x = center_x
        self.center_y = center_y
        self.angle = angle
        self.length = length
        self.width = random.uniform(1.5, 4)

        # 무지개 스펙트럼 색상
        hue = random.uniform(0, 1)
        self.color = self._hue_to_rgb(hue)

        self.lifetime = random.uniform(0.15, 0.4)
        self.max_lifetime = self.lifetime
        self.flicker_speed = random.uniform(10, 20)
        self.flicker_phase = random.uniform(0, math.pi * 2)

    @staticmethod
    def _hue_to_rgb(hue: float) -> Tuple[int, int, int]:
        """HSV -> RGB (S=0.6, V=1.0) for soft pastel rainbow"""
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
        self.flicker_phase += self.flicker_speed * dt
        return self.lifetime > 0

    def draw(self, surface: pygame.Surface, alpha_mult: float = 1.0):
        life_ratio = self.lifetime / self.max_lifetime
        flicker = 0.5 + 0.5 * math.sin(self.flicker_phase)
        alpha = int(150 * life_ratio * flicker * alpha_mult)
        if alpha < 8:
            return

        # 광선 끝점
        end_x = self.center_x + math.cos(self.angle) * self.length
        end_y = self.center_y + math.sin(self.angle) * self.length

        # 글로우 레이어
        glow_color = tuple(min(255, c + 50) for c in self.color)
        # 외부 글로우
        pygame.draw.line(surface, (*glow_color[:3],),
                         (int(self.center_x), int(self.center_y)),
                         (int(end_x), int(end_y)),
                         int(self.width + 3))
        # 메인
        pygame.draw.line(surface, self.color,
                         (int(self.center_x), int(self.center_y)),
                         (int(end_x), int(end_y)),
                         int(self.width + 1))
        # 코어
        pygame.draw.line(surface, (255, 255, 255),
                         (int(self.center_x), int(self.center_y)),
                         (int(end_x), int(end_y)),
                         max(1, int(self.width - 1)))


# ─────────────────────────────────────────────
# 새 효과 클래스: EnergyNebula (에너지 성운)
# ─────────────────────────────────────────────
class EnergyNebula:
    """에너지 성운 - 부드러운 성운/구름 같은 에너지 덩어리"""

    def __init__(self, center_x: float, center_y: float, max_radius: float):
        angle = random.uniform(0, math.pi * 2)
        dist = max_radius * random.uniform(0.2, 0.8)
        self.x = center_x + math.cos(angle) * dist
        self.y = center_y + math.sin(angle) * dist
        self.center_x = center_x
        self.center_y = center_y
        self.angle = angle
        self.dist = dist

        self.size = random.uniform(15, 40)
        self.drift_speed = random.uniform(0.01, 0.03) * random.choice([-1, 1])

        # 색상 (투명한 네뷸라 색상)
        c = random.random()
        if c < 0.3:
            self.color = (80, 120, 200)     # 딥 블루
        elif c < 0.5:
            self.color = (120, 60, 180)     # 딥 퍼플
        elif c < 0.7:
            self.color = (180, 60, 120)     # 마젠타
        else:
            self.color = (60, 140, 160)     # 틸

        self.pulse_phase = random.uniform(0, math.pi * 2)
        self.pulse_speed = random.uniform(1.5, 3.5)

    def update(self, progress: float, dt: float):
        self.pulse_phase += self.pulse_speed * dt
        self.angle += self.drift_speed * dt

        # 중심으로 수렴
        effective_dist = self.dist * (1 - progress * 0.7)
        self.x = self.center_x + math.cos(self.angle) * effective_dist
        self.y = self.center_y + math.sin(self.angle) * effective_dist

        # 크기도 줄어듦
        self.size *= (1 - progress * 0.005)

    def draw(self, surface: pygame.Surface, alpha_mult: float = 1.0):
        pulse = 0.5 + 0.5 * math.sin(self.pulse_phase)
        base_alpha = 35 * pulse * alpha_mult

        if base_alpha < 3 or self.size < 3:
            return

        size_int = int(self.size)
        nebula_surf = pygame.Surface((size_int * 2, size_int * 2), pygame.SRCALPHA)

        # 다중 레이어 구름 효과
        layers = [
            (1.0, 0.15),
            (0.7, 0.25),
            (0.4, 0.4),
            (0.2, 0.6),
        ]

        for radius_mult, opacity_mult in layers:
            r = int(size_int * radius_mult)
            if r < 1:
                continue
            a = int(base_alpha * opacity_mult)
            a = max(0, min(255, a))
            if a > 0:
                pygame.draw.circle(nebula_surf, (*self.color, a), (size_int, size_int), r)

        surface.blit(nebula_surf, (int(self.x - size_int), int(self.y - size_int)))


# ─────────────────────────────────────────────
# 기존 클래스 (강화됨)
# ─────────────────────────────────────────────

class QuantumParticle:
    """양자 에너지 입자 (HD 강화)"""

    def __init__(self, center_x: float, center_y: float, max_radius: float):
        # 시작 위치 (외곽에서 시작)
        angle = random.uniform(0, math.pi * 2)
        dist = max_radius * random.uniform(0.8, 1.2)
        self.x = center_x + math.cos(angle) * dist
        self.y = center_y + math.sin(angle) * dist
        self.center_x = center_x
        self.center_y = center_y

        # 속성
        self.angle = angle
        self.radius = dist
        self.size = random.uniform(2, 7)
        self.speed = random.uniform(0.02, 0.06)  # 각속도

        # 색상 (전기 블루 ~ 양자 퍼플 ~ 핑크 그라데이션 - 더 다채로운 팔레트)
        color_choice = random.random()
        if color_choice < 0.25:
            # 전기 블루
            self.color = (random.randint(100, 200), random.randint(180, 255), 255)
        elif color_choice < 0.45:
            # 양자 퍼플
            self.color = (random.randint(150, 220), random.randint(80, 150), 255)
        elif color_choice < 0.6:
            # 에너지 핑크/화이트
            self.color = (255, random.randint(150, 255), random.randint(200, 255))
        elif color_choice < 0.75:
            # 시안/민트
            self.color = (random.randint(80, 150), 255, random.randint(200, 255))
        elif color_choice < 0.88:
            # 골든 화이트
            self.color = (255, random.randint(230, 255), random.randint(180, 220))
        else:
            # 퓨어 화이트
            self.color = (255, 255, random.randint(240, 255))

        # 밝기 변화
        self.brightness_phase = random.uniform(0, math.pi * 2)
        self.brightness_speed = random.uniform(3, 8)

        # 궤적 저장 (잔상 효과용 - 더 긴 잔상)
        self.trail: List[Tuple[float, float, float]] = []
        self.trail_length = random.randint(8, 20)

    def update(self, progress: float, dt: float):
        """입자 업데이트 - progress: 0~1 (응축 진행도)"""
        # 잔상 저장
        self.trail.append((self.x, self.y, self.size))
        if len(self.trail) > self.trail_length:
            self.trail.pop(0)

        # 소용돌이 회전 + 중심으로 수렴
        self.angle += self.speed * (1 + progress * 2.5)  # 더 가속

        # 반지름 감소 (중심으로 수렴)
        target_radius = self.radius * (1 - progress * 0.95)

        # 위치 업데이트
        self.x = self.center_x + math.cos(self.angle) * target_radius
        self.y = self.center_y + math.sin(self.angle) * target_radius

        # 크기 변화 (수렴하면서 약간 커짐)
        self.size = max(1, self.size * (1 + progress * 0.012))

        # 밝기 변화
        self.brightness_phase += self.brightness_speed * dt

    def draw(self, surface: pygame.Surface, alpha_mult: float = 1.0):
        """입자와 잔상 그리기 (HD 강화)"""
        # 밝기 계산
        brightness = 0.5 + 0.5 * math.sin(self.brightness_phase)

        # 잔상 그리기 (그라데이션 강화)
        for i, (tx, ty, ts) in enumerate(self.trail):
            trail_ratio = i / max(1, len(self.trail))
            trail_alpha = int(70 * trail_ratio * alpha_mult)
            if trail_alpha > 0 and ts > 0.5:
                trail_color = tuple(min(255, int(c * (0.4 + 0.3 * trail_ratio))) for c in self.color)
                trail_size = max(1, int(ts * (0.5 + 0.5 * trail_ratio)))
                trail_surf = pygame.Surface((trail_size * 4, trail_size * 4), pygame.SRCALPHA)
                # 소프트 글로우
                for r in range(trail_size * 2, 0, -1):
                    a = int(trail_alpha * (r / (trail_size * 2)) * 0.4)
                    pygame.draw.circle(trail_surf, (*trail_color, a),
                                       (trail_size * 2, trail_size * 2), r)
                surface.blit(trail_surf, (int(tx - trail_size * 2), int(ty - trail_size * 2)))

        # 메인 파티클
        alpha = int(220 * brightness * alpha_mult)
        glow_color = tuple(min(255, int(c * brightness * 1.2)) for c in self.color)

        # 글로우 효과 (더 넓은 글로우)
        glow_size = int(self.size * 2.5)
        glow_surf = pygame.Surface((glow_size * 4, glow_size * 4), pygame.SRCALPHA)

        # 다중 레이어 글로우
        for r in range(glow_size * 2, 0, -1):
            glow_alpha = int(alpha * (r / (glow_size * 2)) * 0.25)
            # 색상 그라데이션 (외부는 더 연한색)
            blend = r / (glow_size * 2)
            blended_color = tuple(min(255, int(c * (0.6 + 0.4 * blend) + 40 * blend)) for c in glow_color)
            pygame.draw.circle(glow_surf, (*blended_color, glow_alpha),
                               (glow_size * 2, glow_size * 2), r)
        surface.blit(glow_surf, (int(self.x - glow_size * 2), int(self.y - glow_size * 2)))

        # 중심 코어 (더 밝게)
        core_surf = pygame.Surface((int(self.size * 4), int(self.size * 4)), pygame.SRCALPHA)
        core_color = tuple(min(255, c + 60) for c in glow_color)
        pygame.draw.circle(core_surf, (*core_color, min(255, alpha + 55)),
                           (int(self.size * 2), int(self.size * 2)), int(self.size))
        # 초밝은 중심점
        pygame.draw.circle(core_surf, (255, 255, 255, min(255, alpha + 30)),
                           (int(self.size * 2), int(self.size * 2)), max(1, int(self.size * 0.4)))
        surface.blit(core_surf, (int(self.x - self.size * 2), int(self.y - self.size * 2)))


class EnhancedLightningBolt:
    """강화된 번개 효과 - 빠른 페이드인/아웃, 투명한 느낌, 그라데이션 테두리"""

    def __init__(self, start_x: float, start_y: float, end_x: float, end_y: float,
                 branch_depth: int = 0, is_main: bool = True):
        self.start_x = start_x
        self.start_y = start_y
        self.end_x = end_x
        self.end_y = end_y
        self.branch_depth = branch_depth
        self.is_main = is_main

        # 번개 세그먼트 생성
        self.segments = self._generate_segments()

        # 분기 번개들
        self.branches: List['EnhancedLightningBolt'] = []
        if branch_depth < 2 and is_main:
            self._generate_branches()

        # 수명
        self.lifetime = random.uniform(0.08, 0.2) if is_main else random.uniform(0.05, 0.15)
        self.max_lifetime = self.lifetime

        # 페이드인 시간
        self.fade_in_time = self.max_lifetime * 0.2

        # 색상 (밝고 투명한 느낌)
        color_base = random.choice([
            (200, 230, 255),   # 라이트 블루
            (230, 200, 255),   # 라이트 퍼플
            (255, 255, 240),   # 화이트 옐로우
            (220, 255, 255),   # 시안
            (255, 220, 255),   # 핑크
            (255, 255, 255),   # 퓨어 화이트
        ])
        self.color = color_base

        # 두께
        self.thickness = random.randint(1, 3) if is_main else random.randint(1, 2)

        # 기본 투명도
        self.base_opacity = random.uniform(0.4, 0.7) if is_main else random.uniform(0.3, 0.5)

    def _generate_segments(self) -> List[Tuple[float, float, float, float]]:
        segments = []
        dx = self.end_x - self.start_x
        dy = self.end_y - self.start_y
        length = math.hypot(dx, dy)

        if length < 1:
            return [(self.start_x, self.start_y, self.end_x, self.end_y)]

        num_segments = max(4, int(length / 10))  # 더 세밀한 세그먼트
        perp_x = -dy / length
        perp_y = dx / length

        current_x = self.start_x
        current_y = self.start_y

        for i in range(num_segments):
            t = (i + 1) / num_segments
            next_x = self.start_x + dx * t
            next_y = self.start_y + dy * t

            if i < num_segments - 1:
                max_offset = 20 * (1 - t * 0.3)
                offset = random.uniform(-max_offset, max_offset)
                next_x += perp_x * offset
                next_y += perp_y * offset

            segments.append((current_x, current_y, next_x, next_y))
            current_x = next_x
            current_y = next_y

        return segments

    def _generate_branches(self):
        if len(self.segments) < 2:
            return

        num_branches = random.randint(1, 3)  # 더 많은 분기
        branch_indices = random.sample(range(len(self.segments) - 1),
                                       min(num_branches, len(self.segments) - 1))

        for idx in branch_indices:
            seg = self.segments[idx]
            branch_start_x = seg[2]
            branch_start_y = seg[3]

            main_angle = math.atan2(self.end_y - self.start_y, self.end_x - self.start_x)
            branch_angle = main_angle + random.uniform(-math.pi / 3, math.pi / 3)

            main_length = math.hypot(self.end_x - self.start_x, self.end_y - self.start_y)
            branch_length = main_length * random.uniform(0.2, 0.45)

            branch_end_x = branch_start_x + math.cos(branch_angle) * branch_length
            branch_end_y = branch_start_y + math.sin(branch_angle) * branch_length

            self.branches.append(
                EnhancedLightningBolt(branch_start_x, branch_start_y,
                                      branch_end_x, branch_end_y,
                                      self.branch_depth + 1, is_main=False)
            )

    def update(self, dt: float) -> bool:
        self.lifetime -= dt
        self.branches = [b for b in self.branches if b.update(dt)]
        return self.lifetime > 0

    def _calculate_alpha(self) -> float:
        elapsed = self.max_lifetime - self.lifetime

        if elapsed < self.fade_in_time:
            fade_in_ratio = max(0.0, min(1.0, elapsed / self.fade_in_time))
            return fade_in_ratio * self.base_opacity

        fade_out_duration = self.max_lifetime - self.fade_in_time
        if fade_out_duration <= 0:
            return self.base_opacity
        remaining_ratio = max(0.0, min(1.0, self.lifetime / fade_out_duration))
        return self.base_opacity * math.sqrt(remaining_ratio)

    def draw(self, surface: pygame.Surface, alpha_mult: float = 1.0):
        alpha = self._calculate_alpha() * alpha_mult
        if alpha <= 0.01:
            return

        for branch in self.branches:
            branch.draw(surface, alpha_mult * 0.6)

        all_x = [s[0] for s in self.segments] + [self.segments[-1][2]]
        all_y = [s[1] for s in self.segments] + [self.segments[-1][3]]
        min_x, max_x = min(all_x), max(all_x)
        min_y, max_y = min(all_y), max(all_y)

        width = int(max_x - min_x) + 40
        height = int(max_y - min_y) + 40
        offset_x = int(min_x) - 20
        offset_y = int(min_y) - 20

        if width < 2 or height < 2:
            return

        lightning_surf = pygame.Surface((width, height), pygame.SRCALPHA)

        # 그라데이션 글로우 레이어 (5단계로 증가)
        glow_layers = [
            (14, 0.05),
            (10, 0.1),
            (7, 0.18),
            (4, 0.3),
            (2, 0.45),
        ]

        for glow_size, glow_opacity in glow_layers:
            glow_alpha = max(0, min(255, int(255 * alpha * glow_opacity)))
            glow_color = tuple(min(255, c + 30) for c in self.color)

            for sx, sy, ex, ey in self.segments:
                local_sx = sx - offset_x
                local_sy = sy - offset_y
                local_ex = ex - offset_x
                local_ey = ey - offset_y
                pygame.draw.line(lightning_surf, (*glow_color, glow_alpha),
                                 (int(local_sx), int(local_sy)),
                                 (int(local_ex), int(local_ey)),
                                 self.thickness + glow_size)

        # 메인 번개
        main_alpha = max(0, min(255, int(255 * alpha * 0.7)))
        for sx, sy, ex, ey in self.segments:
            local_sx = sx - offset_x
            local_sy = sy - offset_y
            local_ex = ex - offset_x
            local_ey = ey - offset_y
            pygame.draw.line(lightning_surf, (*self.color, main_alpha),
                             (int(local_sx), int(local_sy)),
                             (int(local_ex), int(local_ey)),
                             self.thickness + 1)

        # 밝은 코어
        core_alpha = max(0, min(255, int(255 * alpha * 0.9)))
        for sx, sy, ex, ey in self.segments:
            local_sx = sx - offset_x
            local_sy = sy - offset_y
            local_ex = ex - offset_x
            local_ey = ey - offset_y
            pygame.draw.line(lightning_surf, (255, 255, 255, core_alpha),
                             (int(local_sx), int(local_sy)),
                             (int(local_ex), int(local_ey)),
                             max(1, self.thickness - 1))

        surface.blit(lightning_surf, (offset_x, offset_y))

        # 세그먼트 끝점 스파크
        if self.is_main and random.random() < 0.25:
            for sx, sy, ex, ey in self.segments:
                if random.random() < 0.18:
                    spark_alpha = max(0, min(255, int(180 * alpha)))
                    spark_surf = pygame.Surface((20, 20), pygame.SRCALPHA)
                    for r in range(8, 0, -1):
                        spark_glow_alpha = max(0, min(255, int(spark_alpha * (r / 8) * 0.5)))
                        pygame.draw.circle(spark_surf, (255, 255, 255, spark_glow_alpha),
                                           (10, 10), r)
                    surface.blit(spark_surf, (int(ex - 10), int(ey - 10)))


class ChainLightning:
    """체인 라이트닝 - 여러 점을 연결하는 번개"""

    def __init__(self, points: List[Tuple[float, float]]):
        self.points = points
        self.bolts: List[EnhancedLightningBolt] = []

        for i in range(len(points) - 1):
            self.bolts.append(
                EnhancedLightningBolt(points[i][0], points[i][1],
                                      points[i + 1][0], points[i + 1][1],
                                      branch_depth=1, is_main=True)
            )

        self.lifetime = random.uniform(0.2, 0.4)
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


class ElectricArc:
    """전기 아크 - 공 주변을 감싸는 전기 효과"""

    def __init__(self, center_x: float, center_y: float, radius: float):
        self.center_x = center_x
        self.center_y = center_y
        self.radius = radius
        self.angle = random.uniform(0, math.pi * 2)
        self.arc_length = random.uniform(math.pi / 4, math.pi / 2)
        self.rotation_speed = random.uniform(3, 8) * random.choice([-1, 1])

        self.color = random.choice([
            (150, 200, 255),
            (200, 150, 255),
            (255, 255, 200),
            (200, 255, 255),
        ])

        self.lifetime = random.uniform(0.3, 0.8)
        self.max_lifetime = self.lifetime
        self.thickness = random.randint(1, 3)

        self.noise_points = [random.uniform(-5, 5) for _ in range(12)]

    def update(self, dt: float, new_center: Tuple[float, float] = None) -> bool:
        self.lifetime -= dt
        self.angle += self.rotation_speed * dt

        if new_center:
            self.center_x, self.center_y = new_center

        for i in range(len(self.noise_points)):
            self.noise_points[i] += random.uniform(-2, 2)
            self.noise_points[i] = max(-8, min(8, self.noise_points[i]))

        return self.lifetime > 0

    def draw(self, surface: pygame.Surface, alpha_mult: float = 1.0):
        life_ratio = self.lifetime / self.max_lifetime
        if life_ratio < 0.05:
            return

        num_segments = 18
        points = []

        for i in range(num_segments + 1):
            t = i / num_segments
            current_angle = self.angle + t * self.arc_length

            noise_idx = int(t * (len(self.noise_points) - 1))
            noise = self.noise_points[noise_idx] * (1 - abs(t - 0.5) * 2)

            r = self.radius + noise
            x = self.center_x + math.cos(current_angle) * r
            y = self.center_y + math.sin(current_angle) * r
            points.append((int(x), int(y)))

        if len(points) < 2:
            return

        # 생명 비율에 따른 색상 페이드
        fade = life_ratio * alpha_mult

        # 외부 글로우
        glow_color = tuple(max(0, int(c * 0.6 * fade)) for c in self.color)
        for i in range(len(points) - 1):
            pygame.draw.line(surface, glow_color, points[i], points[i + 1],
                             self.thickness + 4)

        # 메인 아크
        main_color = tuple(max(0, int(c * fade)) for c in self.color)
        for i in range(len(points) - 1):
            pygame.draw.line(surface, main_color, points[i], points[i + 1],
                             self.thickness + 1)

        # 밝은 코어
        core_brightness = int(255 * fade)
        for i in range(len(points) - 1):
            pygame.draw.line(surface, (core_brightness, core_brightness, core_brightness),
                             points[i], points[i + 1],
                             max(1, self.thickness - 1))


class Spark:
    """스파크 파티클 - 공이 이동할 때 튀는 불꽃"""

    def __init__(self, x: float, y: float, direction: float = None):
        self.x = x
        self.y = y

        if direction is None:
            direction = random.uniform(0, math.pi * 2)

        speed = random.uniform(50, 200)
        self.vx = math.cos(direction) * speed
        self.vy = math.sin(direction) * speed

        self.gravity = random.uniform(100, 300)

        self.color = random.choice([
            (255, 255, 200),
            (255, 200, 100),
            (200, 220, 255),
            (255, 255, 255),
            (255, 200, 255),
        ])

        self.size = random.uniform(1.5, 4)
        self.lifetime = random.uniform(0.2, 0.6)
        self.max_lifetime = self.lifetime

        self.trail: List[Tuple[float, float]] = []
        self.trail_length = random.randint(4, 10)

    def update(self, dt: float) -> bool:
        self.lifetime -= dt

        self.trail.append((self.x, self.y))
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
        alpha = int(255 * life_ratio * alpha_mult)

        # 꼬리
        for i, (tx, ty) in enumerate(self.trail):
            trail_alpha = int(alpha * (i / max(1, len(self.trail))) * 0.5)
            trail_size = self.size * (i / max(1, len(self.trail)))
            if trail_alpha > 0 and trail_size > 0:
                pygame.draw.circle(surface, self.color[:3],
                                   (int(tx), int(ty)), int(trail_size))

        if alpha > 0:
            glow_surf = pygame.Surface((int(self.size * 6), int(self.size * 6)), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (*self.color, int(alpha * 0.3)),
                               (int(self.size * 3), int(self.size * 3)), int(self.size * 2))
            surface.blit(glow_surf, (int(self.x - self.size * 3), int(self.y - self.size * 3)))

            pygame.draw.circle(surface, self.color, (int(self.x), int(self.y)), int(self.size))
            pygame.draw.circle(surface, (255, 255, 255), (int(self.x), int(self.y)),
                               int(self.size * 0.5))


class HologramRing:
    """홀로그램 링 - 깜빡이는 원형 홀로그램 효과"""

    def __init__(self, center_x: float, center_y: float, radius: float):
        self.center_x = center_x
        self.center_y = center_y
        self.radius = radius
        self.target_radius = radius

        self.flicker_phase = random.uniform(0, math.pi * 2)
        self.flicker_speed = random.uniform(8, 15)

        self.base_color = random.choice([
            (100, 200, 255),
            (150, 100, 255),
            (100, 255, 200),
        ])

        self.thickness = random.randint(1, 2)
        self.segments = random.randint(16, 32)

        self.distortion = [random.uniform(-3, 3) for _ in range(self.segments)]

        self.lifetime = random.uniform(0.5, 1.5)
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
            self.distortion[i] += random.uniform(-1, 1)
            self.distortion[i] = max(-5, min(5, self.distortion[i]))

        return self.lifetime > 0

    def draw(self, surface: pygame.Surface, alpha_mult: float = 1.0):
        life_ratio = self.lifetime / self.max_lifetime

        flicker = 0.3 + 0.7 * (0.5 + 0.5 * math.sin(self.flicker_phase))
        if random.random() < 0.1:
            flicker *= random.uniform(0.2, 1.5)

        alpha = int(200 * life_ratio * flicker * alpha_mult)
        if alpha <= 0:
            return

        angle_step = (math.pi * 2) / self.segments

        for i in range(self.segments):
            if random.random() < 0.05:
                continue

            start_angle = i * angle_step
            end_angle = (i + 0.8) * angle_step

            r = self.radius + self.distortion[i]

            sx = self.center_x + math.cos(start_angle) * r
            sy = self.center_y + math.sin(start_angle) * r
            ex = self.center_x + math.cos(end_angle) * r
            ey = self.center_y + math.sin(end_angle) * r

            color_shift = math.sin(self.flicker_phase + i * 0.5) * 30
            color = tuple(max(0, min(255, int(c + color_shift))) for c in self.base_color)

            pygame.draw.line(surface, color, (int(sx), int(sy)), (int(ex), int(ey)),
                             self.thickness)


class VortexRing:
    """소용돌이 링 효과"""

    def __init__(self, center_x: float, center_y: float, radius: float):
        self.center_x = center_x
        self.center_y = center_y
        self.radius = radius
        self.angle = random.uniform(0, math.pi * 2)
        self.rotation_speed = random.uniform(1, 3) * random.choice([-1, 1])

        self.color = random.choice([
            (100, 180, 255, 100),
            (180, 100, 255, 100),
            (255, 150, 200, 80),
        ])

        self.thickness = random.randint(1, 3)
        self.dash_count = random.randint(8, 16)

    def update(self, progress: float, dt: float):
        self.angle += self.rotation_speed * dt
        self.radius *= (1 - progress * 0.02)

    def draw(self, surface: pygame.Surface, alpha_mult: float = 1.0):
        if self.radius < 5:
            return

        dash_angle = (math.pi * 2) / self.dash_count

        for i in range(self.dash_count):
            start_angle = self.angle + i * dash_angle
            end_angle = start_angle + dash_angle * 0.5

            sx = self.center_x + math.cos(start_angle) * self.radius
            sy = self.center_y + math.sin(start_angle) * self.radius
            ex = self.center_x + math.cos(end_angle) * self.radius
            ey = self.center_y + math.sin(end_angle) * self.radius

            pygame.draw.line(surface, self.color[:3], (int(sx), int(sy)), (int(ex), int(ey)),
                             self.thickness)


class EnergyRing:
    """에너지 링 - 공 주변 확장하는 링 효과"""

    def __init__(self, center_x: float, center_y: float, start_radius: float = 10):
        self.center_x = center_x
        self.center_y = center_y
        self.radius = start_radius
        self.max_radius = start_radius * 5

        self.color = random.choice([
            (150, 200, 255),
            (200, 150, 255),
            (255, 200, 150),
            (150, 255, 200),
        ])

        self.thickness = 2
        self.lifetime = random.uniform(0.3, 0.6)
        self.max_lifetime = self.lifetime
        self.expansion_speed = random.uniform(100, 200)

    def update(self, dt: float, new_center: Tuple[float, float] = None) -> bool:
        self.lifetime -= dt
        self.radius += self.expansion_speed * dt

        if new_center:
            self.center_x, self.center_y = new_center

        return self.lifetime > 0 and self.radius < self.max_radius

    def draw(self, surface: pygame.Surface, alpha_mult: float = 1.0):
        life_ratio = self.lifetime / self.max_lifetime
        alpha = int(200 * life_ratio * alpha_mult)

        if alpha <= 0 or self.radius <= 0:
            return

        r_int = int(self.radius)
        surf_size = r_int + 12
        if surf_size < 2:
            return

        glow_surf = pygame.Surface((surf_size * 2, surf_size * 2), pygame.SRCALPHA)
        center = surf_size

        for i in range(3, 0, -1):
            ring_alpha = int(alpha * 0.3 / i)
            pygame.draw.circle(glow_surf, (*self.color, ring_alpha), (center, center),
                               min(center - 1, r_int + i * 2), self.thickness + i)

        surface.blit(glow_surf,
                     (int(self.center_x - center), int(self.center_y - center)))

        pygame.draw.circle(surface, self.color,
                           (int(self.center_x), int(self.center_y)),
                           r_int, self.thickness)


# ─────────────────────────────────────────────
# 메인 애니메이션 컨트롤러 (Ultra Premium HD)
# ─────────────────────────────────────────────

class BallSpawnAnimation:
    """공 생성 애니메이션 메인 클래스 (Ultra Premium HD Edition)

    시퀀스:
    1. Phase 1: 에너지 응축 (0-4초) - 우주먼지+성운+양자입자+플라즈마+번개+색채광선
    2. Phase 2: 공 부양 (4-5.5초) - 궤도 구체 + 에너지 링 + 충격파
    3. Phase 3: 서브 이동 (5.5-8초) - 잔상 + 홀로그램 + 스파크 + 전기 아크 + 충격파
    """

    # 페이즈 타이밍 (초)
    PHASE_1_DURATION = 4.0      # 에너지 응축
    PHASE_2_DURATION = 1.5      # 공 부양
    PHASE_3_DURATION = 2.5      # 서브 이동

    TOTAL_DURATION = PHASE_1_DURATION + PHASE_2_DURATION + PHASE_3_DURATION  # 8초

    # 성능 최적화 제한
    MAX_ENERGY_RINGS_PHASE2 = 4
    MAX_ELECTRIC_ARCS_PHASE2 = 6
    MAX_COSMIC_DUST = 80
    MAX_PLASMA_TENDRILS = 8
    MAX_ORBITING_ORBS = 6
    MAX_NEBULAE = 12
    MAX_CHROMATIC_RAYS = 15

    def __init__(self, screen_width: int, screen_height: int):
        self.screen_width = screen_width
        self.screen_height = screen_height

        # 맵 중앙 좌표
        self.center_x = screen_width // 2
        self.center_y = screen_height // 2

        # 상태
        self.active = False
        self.completed = False
        self.elapsed_time = 0.0
        self.current_phase = 0

        # 서브 대상
        self.is_player_serve = True
        self.player_y = screen_height - 100
        self.boss_y = 100

        # 공 상태
        self.ball_x = self.center_x
        self.ball_y = self.center_y
        self.ball_radius = 12
        self.ball_visible = False
        self.ball_alpha = 0
        self.ball_scale = 0.1

        # 부양 효과
        self.levitate_offset = 0
        self.levitate_speed = 3.0

        # ── 기존 파티클 시스템 ──
        self.quantum_particles: List[QuantumParticle] = []
        self.lightning_bolts: List[EnhancedLightningBolt] = []
        self.chain_lightnings: List[ChainLightning] = []
        self.vortex_rings: List[VortexRing] = []
        self.electric_arcs: List[ElectricArc] = []
        self.sparks: List[Spark] = []
        self.hologram_rings: List[HologramRing] = []
        self.energy_rings: List[EnergyRing] = []

        # ── 새로운 HD 파티클 시스템 ──
        self.cosmic_dust: List[CosmicDust] = []
        self.plasma_tendrils: List[PlasmaTendril] = []
        self.orbiting_orbs: List[OrbitingOrb] = []
        self.shockwave_rings: List[ShockwaveRing] = []
        self.after_images: List[AfterImage] = []
        self.chromatic_rays: List[ChromaticRay] = []
        self.energy_nebulae: List[EnergyNebula] = []

        # 파티클 스폰 타이머
        self.particle_spawn_timer = 0
        self.lightning_spawn_timer = 0
        self.ring_spawn_timer = 0
        self.arc_spawn_timer = 0
        self.spark_spawn_timer = 0
        self.hologram_spawn_timer = 0
        self.energy_ring_timer = 0
        self.tendril_spawn_timer = 0
        self.ray_spawn_timer = 0
        self.afterimage_timer = 0

        # 효과음 플래그
        self.sounds_played = {
            'condensing': False,
            'formed': False,
            'moving': False
        }

        # 화면 플래시 효과
        self.flash_alpha = 0
        self.flash_color = (255, 255, 255)

        # 중심 코어 글로우
        self.core_glow_radius = 0
        self.core_glow_alpha = 0

        # 맥동 효과 (HD 추가)
        self.pulse_phase = 0
        self.pulse_speed = 2.5

    def start(self, is_player_serve: bool, player_y: Optional[float] = None,
              boss_y: Optional[float] = None):
        """애니메이션 시작"""
        self.active = True
        self.completed = False
        self.elapsed_time = 0.0
        self.current_phase = 1

        self.is_player_serve = is_player_serve
        if player_y is not None:
            self.player_y = player_y
        if boss_y is not None:
            self.boss_y = boss_y

        # 초기화
        self.ball_x = self.center_x
        self.ball_y = self.center_y
        self.ball_visible = False
        self.ball_alpha = 0
        self.ball_scale = 0.1
        self.levitate_offset = 0

        # 기존 파티클 초기화
        self.quantum_particles.clear()
        self.lightning_bolts.clear()
        self.chain_lightnings.clear()
        self.vortex_rings.clear()
        self.electric_arcs.clear()
        self.sparks.clear()
        self.hologram_rings.clear()
        self.energy_rings.clear()

        # 새 파티클 초기화
        self.cosmic_dust.clear()
        self.plasma_tendrils.clear()
        self.orbiting_orbs.clear()
        self.shockwave_rings.clear()
        self.after_images.clear()
        self.chromatic_rays.clear()
        self.energy_nebulae.clear()

        # 초기 파티클 생성
        self._spawn_initial_particles()

        # 플래그 리셋
        self.sounds_played = {
            'condensing': False,
            'formed': False,
            'moving': False
        }
        self.flash_alpha = 0
        self.core_glow_radius = 0
        self.core_glow_alpha = 0
        self.pulse_phase = 0

        # 타이머 리셋
        self.particle_spawn_timer = 0
        self.lightning_spawn_timer = 0
        self.ring_spawn_timer = 0
        self.arc_spawn_timer = 0
        self.spark_spawn_timer = 0
        self.hologram_spawn_timer = 0
        self.energy_ring_timer = 0
        self.tendril_spawn_timer = 0
        self.ray_spawn_timer = 0
        self.afterimage_timer = 0

    def _spawn_initial_particles(self):
        """초기 파티클 생성 (HD 강화)"""
        max_radius = min(self.screen_width, self.screen_height) * 0.4

        # 양자 입자 (80-120개)
        for _ in range(random.randint(80, 120)):
            self.quantum_particles.append(
                QuantumParticle(self.center_x, self.center_y, max_radius)
            )

        # 소용돌이 링 (7-12개)
        for i in range(random.randint(7, 12)):
            ring_radius = max_radius * (0.2 + i * 0.08)
            self.vortex_rings.append(
                VortexRing(self.center_x, self.center_y, ring_radius)
            )

        # [HD] 우주 먼지 (최대 80개)
        for _ in range(self.MAX_COSMIC_DUST):
            self.cosmic_dust.append(
                CosmicDust(self.screen_width, self.screen_height, self.center_x, self.center_y)
            )

        # [HD] 에너지 성운 (8-12개)
        for _ in range(random.randint(8, self.MAX_NEBULAE)):
            self.energy_nebulae.append(
                EnergyNebula(self.center_x, self.center_y, max_radius)
            )

        # [HD] 초기 플라즈마 촉수 (4-6개)
        for _ in range(random.randint(4, 6)):
            self.plasma_tendrils.append(
                PlasmaTendril(self.center_x, self.center_y, max_radius)
            )

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

        # dt 제한 (max 33ms)
        original_dt = dt
        dt = min(dt, 0.033)
        if original_dt > 0.05:
            print(f"[DEBUG] dt 제한됨: {original_dt:.3f}s -> {dt:.3f}s")

        self.elapsed_time += dt
        self.pulse_phase += self.pulse_speed * dt

        # 페이즈 전환
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
        """Phase 1: 에너지 응축 (4초) - HD 강화"""
        progress = self.elapsed_time / self.PHASE_1_DURATION

        # ── 기존 효과 업데이트 ──

        # 양자 입자 업데이트
        for particle in self.quantum_particles:
            particle.update(progress, dt)

        # 소용돌이 링 업데이트
        for ring in self.vortex_rings:
            ring.update(progress, dt)

        # 강화된 번개 생성
        self.lightning_spawn_timer += dt
        spawn_interval = max(0.03, 0.2 - progress * 0.17)

        if self.lightning_spawn_timer >= spawn_interval:
            self.lightning_spawn_timer = 0
            self._spawn_enhanced_lightning(progress)

        # 체인 라이트닝
        if random.random() < 0.02 * (1 + progress):
            self._spawn_chain_lightning()

        # 번개 업데이트
        self.lightning_bolts = [bolt for bolt in self.lightning_bolts if bolt.update(dt)]
        self.chain_lightnings = [chain for chain in self.chain_lightnings if chain.update(dt)]

        # 전기 아크 (Phase 1 후반)
        if progress > 0.5:
            self.arc_spawn_timer += dt
            if self.arc_spawn_timer >= 0.3:
                self.arc_spawn_timer = 0
                arc_radius = 50 * (1 - (progress - 0.5) * 1.5)
                self.electric_arcs.append(
                    ElectricArc(self.center_x, self.center_y, max(15, arc_radius))
                )

        self.electric_arcs = [arc for arc in self.electric_arcs
                              if arc.update(dt, (self.center_x, self.center_y))]

        # 추가 파티클 생성
        self.particle_spawn_timer += dt
        if self.particle_spawn_timer >= 0.3 and len(self.quantum_particles) < 180:
            self.particle_spawn_timer = 0
            max_radius = min(self.screen_width, self.screen_height) * 0.4 * (1 - progress * 0.5)
            for _ in range(random.randint(8, 15)):
                self.quantum_particles.append(
                    QuantumParticle(self.center_x, self.center_y, max_radius)
                )

        # ── HD 새 효과 업데이트 ──

        # 우주 먼지 업데이트
        for dust in self.cosmic_dust:
            dust.update(progress, dt)

        # 에너지 성운 업데이트
        for nebula in self.energy_nebulae:
            nebula.update(progress, dt)

        # 플라즈마 촉수 업데이트 & 스폰
        self.plasma_tendrils = [t for t in self.plasma_tendrils if t.update(progress, dt)]
        self.tendril_spawn_timer += dt
        if self.tendril_spawn_timer >= 0.8 and len(self.plasma_tendrils) < self.MAX_PLASMA_TENDRILS:
            self.tendril_spawn_timer = 0
            max_radius = min(self.screen_width, self.screen_height) * 0.4 * (1 - progress * 0.3)
            self.plasma_tendrils.append(
                PlasmaTendril(self.center_x, self.center_y, max_radius)
            )

        # 색채 광선 (Phase 1 중반 이후)
        if progress > 0.3:
            self.ray_spawn_timer += dt
            ray_interval = max(0.05, 0.2 - (progress - 0.3) * 0.2)
            if self.ray_spawn_timer >= ray_interval and len(self.chromatic_rays) < self.MAX_CHROMATIC_RAYS:
                self.ray_spawn_timer = 0
                angle = random.uniform(0, math.pi * 2)
                length = random.uniform(40, 120) * (1 - progress * 0.3)
                self.chromatic_rays.append(
                    ChromaticRay(self.center_x, self.center_y, angle, length)
                )

        self.chromatic_rays = [r for r in self.chromatic_rays if r.update(dt)]

        # 중심 코어 글로우
        pulse = 0.8 + 0.2 * math.sin(self.pulse_phase * 3)
        self.core_glow_radius = (20 + progress * 45) * pulse
        self.core_glow_alpha = int((100 + progress * 155) * pulse)

        # Phase 1 종료 직전 플래시
        if progress > 0.92:
            self.flash_alpha = int(255 * (progress - 0.92) * 12.5)
            self.flash_color = (220, 240, 255)

    def _update_phase_2(self, dt: float):
        """Phase 2: 공 부양 (1.5초) - HD 강화"""
        phase_time = self.elapsed_time - self.PHASE_1_DURATION
        progress = phase_time / self.PHASE_2_DURATION

        # 공 나타남
        self.ball_visible = True
        self.ball_alpha = min(255, int(progress * 400))
        self.ball_scale = min(1.0, 0.3 + progress * 0.7)

        # 위아래 부양 효과
        self.levitate_offset = math.sin(phase_time * self.levitate_speed * 2) * 10
        self.ball_y = self.center_y + self.levitate_offset

        # 에너지 링 방출
        self.energy_ring_timer += dt
        if self.energy_ring_timer >= 0.35 and len(self.energy_rings) < self.MAX_ENERGY_RINGS_PHASE2:
            self.energy_ring_timer = 0
            self.energy_rings.append(
                EnergyRing(self.ball_x, self.ball_y, self.ball_radius * self.ball_scale)
            )

        self.energy_rings = [ring for ring in self.energy_rings
                             if ring.update(dt, (self.ball_x, self.ball_y))]

        # 전기 아크
        self.arc_spawn_timer += dt
        if self.arc_spawn_timer >= 0.3 and len(self.electric_arcs) < self.MAX_ELECTRIC_ARCS_PHASE2:
            self.arc_spawn_timer = 0
            self.electric_arcs.append(
                ElectricArc(self.ball_x, self.ball_y, self.ball_radius * 2 * self.ball_scale)
            )

        self.electric_arcs = [arc for arc in self.electric_arcs
                              if arc.update(dt, (self.ball_x, self.ball_y))]

        # ── HD 새 효과 ──

        # [HD] 궤도 구체 생성 (Phase 2 시작 시)
        if progress < 0.3 and len(self.orbiting_orbs) < self.MAX_ORBITING_ORBS:
            for orbit_r in [25, 35, 45, 55]:
                if len(self.orbiting_orbs) < self.MAX_ORBITING_ORBS:
                    self.orbiting_orbs.append(
                        OrbitingOrb(self.ball_x, self.ball_y, orbit_r)
                    )

        # 궤도 구체 업데이트
        for orb in self.orbiting_orbs:
            orb.update(dt, (self.ball_x, self.ball_y))

        # [HD] Phase 2 시작 충격파
        if progress < 0.1:
            if len(self.shockwave_rings) == 0:
                self.shockwave_rings.append(
                    ShockwaveRing(self.center_x, self.center_y, 180)
                )

        self.shockwave_rings = [sw for sw in self.shockwave_rings
                                if sw.update(dt, (self.ball_x, self.ball_y))]

        # 우주 먼지 페이드아웃
        if progress > 0.5:
            fade_rate = int(len(self.cosmic_dust) * 0.05)
            for _ in range(min(fade_rate, len(self.cosmic_dust))):
                if self.cosmic_dust:
                    self.cosmic_dust.pop(random.randint(0, len(self.cosmic_dust) - 1))

        # 성운 페이드아웃
        if progress > 0.3:
            fade_rate = int(len(self.energy_nebulae) * 0.08)
            for _ in range(min(fade_rate, len(self.energy_nebulae))):
                if self.energy_nebulae:
                    self.energy_nebulae.pop(random.randint(0, len(self.energy_nebulae) - 1))

        # 잔여 파티클 제거
        self.quantum_particles = [p for p in self.quantum_particles if random.random() > 0.12]
        self.plasma_tendrils = [t for t in self.plasma_tendrils if random.random() > 0.15]
        self.chromatic_rays = [r for r in self.chromatic_rays if r.update(dt)]

        # 플래시 페이드아웃
        self.flash_alpha = max(0, int(255 * (1 - progress)))

        # 코어 글로우
        self.core_glow_radius = 50 - progress * 25
        self.core_glow_alpha = int(220 * (1 - progress * 0.5))

        if not self.sounds_played['formed'] and progress > 0.1:
            self.sounds_played['formed'] = True

    def _update_phase_3(self, dt: float):
        """Phase 3: 서브 이동 (2.5초) - HD 강화"""
        phase_time = self.elapsed_time - self.PHASE_1_DURATION - self.PHASE_2_DURATION
        progress = phase_time / self.PHASE_3_DURATION

        # Ease-out 이동
        eased_progress = 1 - (1 - progress) ** 3

        # 목표 위치
        target_y = self.player_y if self.is_player_serve else self.boss_y

        # 이전 위치 저장
        prev_ball_y = self.ball_y

        # 위치 보간
        self.ball_y = self.center_y + (target_y - self.center_y) * eased_progress

        # 부양 효과 감소
        levitate_amp = 8 * (1 - eased_progress)
        self.levitate_offset = math.sin(phase_time * self.levitate_speed * 2) * levitate_amp
        self.ball_y += self.levitate_offset

        # 공 완전 표시
        self.ball_alpha = 255
        self.ball_scale = 1.0

        # ── 기존 효과 ──

        # 홀로그램 링
        self.hologram_spawn_timer += dt
        if self.hologram_spawn_timer >= 0.15:
            self.hologram_spawn_timer = 0
            for radius_mult in [1.5, 2.5, 3.5]:
                self.hologram_rings.append(
                    HologramRing(self.ball_x, self.ball_y,
                                 self.ball_radius * radius_mult)
                )

        self.hologram_rings = [ring for ring in self.hologram_rings
                               if ring.update(dt, (self.ball_x, self.ball_y))]

        # 스파크
        speed = abs(self.ball_y - prev_ball_y) / dt if dt > 0 else 0
        self.spark_spawn_timer += dt

        if self.spark_spawn_timer >= 0.05 and speed > 10:
            self.spark_spawn_timer = 0
            move_direction = math.pi / 2 if self.ball_y > prev_ball_y else -math.pi / 2
            for _ in range(random.randint(2, 5)):
                spark_direction = move_direction + math.pi + random.uniform(-0.8, 0.8)
                self.sparks.append(
                    Spark(self.ball_x + random.uniform(-10, 10),
                          self.ball_y + random.uniform(-5, 5),
                          spark_direction)
                )

        self.sparks = [spark for spark in self.sparks if spark.update(dt)]

        # 전기 아크
        self.arc_spawn_timer += dt
        if self.arc_spawn_timer >= 0.12:
            self.arc_spawn_timer = 0
            self.electric_arcs.append(
                ElectricArc(self.ball_x, self.ball_y, self.ball_radius * 2)
            )

        self.electric_arcs = [arc for arc in self.electric_arcs
                              if arc.update(dt, (self.ball_x, self.ball_y))]

        # 에너지 링
        self.energy_ring_timer += dt
        if self.energy_ring_timer >= 0.4:
            self.energy_ring_timer = 0
            self.energy_rings.append(
                EnergyRing(self.ball_x, self.ball_y, self.ball_radius)
            )

        self.energy_rings = [ring for ring in self.energy_rings
                             if ring.update(dt, (self.ball_x, self.ball_y))]

        # ── HD 새 효과 ──

        # [HD] 잔상 효과
        self.afterimage_timer += dt
        if self.afterimage_timer >= 0.06 and speed > 5:
            self.afterimage_timer = 0
            ball_color = (180, 220, 255)
            self.after_images.append(
                AfterImage(self.ball_x, self.ball_y, self.ball_radius, ball_color)
            )

        self.after_images = [ai for ai in self.after_images if ai.update(dt)]

        # [HD] 궤도 구체 따라다님 (점차 흡수)
        for orb in self.orbiting_orbs:
            orb.orbit_radius = max(5, orb.orbit_radius * (1 - dt * 0.8))
            orb.update(dt, (self.ball_x, self.ball_y))

        # 궤도 반지름이 너무 작아지면 제거
        self.orbiting_orbs = [o for o in self.orbiting_orbs if o.orbit_radius > 5]

        # [HD] 출발/도착 충격파
        if progress < 0.05 and len(self.shockwave_rings) == 0:
            self.shockwave_rings.append(
                ShockwaveRing(self.ball_x, self.ball_y, 150)
            )

        if progress > 0.92 and len(self.shockwave_rings) == 0:
            self.shockwave_rings.append(
                ShockwaveRing(self.ball_x, self.ball_y, 120)
            )

        self.shockwave_rings = [sw for sw in self.shockwave_rings
                                if sw.update(dt, (self.ball_x, self.ball_y))]

        # 파티클 페이드아웃
        self.quantum_particles = [p for p in self.quantum_particles
                                   if random.random() > 0.08]
        self.cosmic_dust = [d for d in self.cosmic_dust if random.random() > 0.06]

        # 코어 글로우 페이드아웃
        self.core_glow_alpha = int(100 * (1 - progress))

        # 도착 직전 플래시
        if progress > 0.9:
            arrival_progress = (progress - 0.9) / 0.1
            self.flash_alpha = int(120 * arrival_progress * (1 - arrival_progress) * 4)
            self.flash_color = (255, 255, 230)

    def _spawn_enhanced_lightning(self, progress: float):
        """강화된 번개 생성"""
        max_radius = min(self.screen_width, self.screen_height) * 0.4 * (1 - progress * 0.5)

        num_bolts = random.randint(1, 3)
        for _ in range(num_bolts):
            angle = random.uniform(0, math.pi * 2)
            start_dist = max_radius * random.uniform(0.6, 1.0)

            start_x = self.center_x + math.cos(angle) * start_dist
            start_y = self.center_y + math.sin(angle) * start_dist

            end_dist = max(10, start_dist * (1 - progress) * random.uniform(0.2, 0.5))
            end_angle = angle + random.uniform(-0.4, 0.4)
            end_x = self.center_x + math.cos(end_angle) * end_dist
            end_y = self.center_y + math.sin(end_angle) * end_dist

            self.lightning_bolts.append(
                EnhancedLightningBolt(start_x, start_y, end_x, end_y)
            )

        # 입자 간 번개
        if random.random() < 0.4 and len(self.quantum_particles) >= 2:
            p1, p2 = random.sample(self.quantum_particles, 2)
            self.lightning_bolts.append(
                EnhancedLightningBolt(p1.x, p1.y, p2.x, p2.y, branch_depth=1)
            )

    def _spawn_chain_lightning(self):
        """체인 라이트닝 생성"""
        if len(self.quantum_particles) < 4:
            return

        num_points = random.randint(3, min(5, len(self.quantum_particles)))
        selected = random.sample(self.quantum_particles, num_points)
        points = [(p.x, p.y) for p in selected]

        self.chain_lightnings.append(ChainLightning(points))

    def draw(self, surface: pygame.Surface, ball_color: Tuple[int, int, int] = (255, 255, 255)):
        """애니메이션 렌더링 (HD 레이어 순서 최적화)"""
        if not self.active and not self.ball_visible:
            return

        # ── 레이어 1: 배경 효과 (가장 뒤) ──

        # 에너지 성운 (가장 뒤 레이어)
        for nebula in self.energy_nebulae:
            nebula.draw(surface)

        # 우주 먼지
        for dust in self.cosmic_dust:
            dust.draw(surface)

        # 소용돌이 링
        for ring in self.vortex_rings:
            ring.draw(surface)

        # ── 레이어 2: 중간 효과 ──

        # 에너지 링
        for ring in self.energy_rings:
            ring.draw(surface)

        # 충격파 링
        for sw in self.shockwave_rings:
            sw.draw(surface)

        # 플라즈마 촉수
        progress = min(1.0, self.elapsed_time / self.PHASE_1_DURATION) if self.current_phase == 1 else 1.0
        for tendril in self.plasma_tendrils:
            tendril.draw(surface, progress)

        # 양자 입자
        for particle in self.quantum_particles:
            alpha_mult = 1.0 if self.current_phase == 1 else max(0.1, 1.0 - (self.current_phase - 1) * 0.4)
            particle.draw(surface, alpha_mult)

        # ── 레이어 3: 번개/아크 효과 ──

        # 색채 광선
        for ray in self.chromatic_rays:
            ray.draw(surface)

        # 체인 라이트닝
        for chain in self.chain_lightnings:
            chain.draw(surface)

        # 번개
        for bolt in self.lightning_bolts:
            bolt.draw(surface)

        # 전기 아크
        for arc in self.electric_arcs:
            arc.draw(surface)

        # ── 레이어 4: 코어/공 효과 ──

        # 홀로그램 링
        for holo in self.hologram_rings:
            holo.draw(surface)

        # 중심 코어 글로우
        if self.core_glow_alpha > 0 and self.core_glow_radius > 0:
            self._draw_core_glow(surface)

        # 궤도 구체
        for orb in self.orbiting_orbs:
            orb.draw(surface)

        # 잔상 (공 뒤에)
        for ai in self.after_images:
            ai.draw(surface)

        # 공
        if self.ball_visible and self.ball_alpha > 0:
            self._draw_ball(surface, ball_color)

        # ── 레이어 5: 전경 효과 (가장 앞) ──

        # 스파크
        for spark in self.sparks:
            spark.draw(surface)

        # 플래시 오버레이
        if self.flash_alpha > 0:
            flash_surf = pygame.Surface((self.screen_width, self.screen_height), pygame.SRCALPHA)
            flash_surf.fill((*self.flash_color, min(255, self.flash_alpha)))
            surface.blit(flash_surf, (0, 0))

    def _draw_core_glow(self, surface: pygame.Surface):
        """중심 코어 글로우 (HD 강화 - 맥동 + 다층)"""
        pulse = 0.85 + 0.15 * math.sin(self.pulse_phase * 3)
        effective_radius = self.core_glow_radius * pulse

        if effective_radius < 2:
            return

        glow_surf = pygame.Surface((int(effective_radius * 4),
                                     int(effective_radius * 4)), pygame.SRCALPHA)
        center = int(effective_radius * 2)

        # 다층 글로우 (더 풍부한 색상 그라데이션)
        colors = [
            (255, 255, 255),   # 퓨어 화이트 코어
            (240, 250, 255),   # 거의 화이트
            (220, 240, 255),   # 라이트 블루 1
            (200, 220, 255),   # 라이트 블루 2
            (180, 200, 255),   # 블루 1
            (160, 180, 255),   # 블루 2
            (180, 150, 255),   # 퍼플 1
            (160, 120, 240),   # 딥 퍼플
        ]

        for i, color in enumerate(colors):
            radius = int(effective_radius * (1 - i * 0.11))
            alpha = int(self.core_glow_alpha * (1 - i * 0.11))
            if radius > 0 and alpha > 0:
                pygame.draw.circle(glow_surf, (*color, alpha), (center, center), radius)

        surface.blit(glow_surf,
                     (int(self.center_x - center), int(self.center_y - center)))

    def _draw_ball(self, surface: pygame.Surface, ball_color: Tuple[int, int, int]):
        """공 그리기 (HD 강화 - 더 넓은 글로우 + 반사광)"""
        radius = int(self.ball_radius * self.ball_scale)
        if radius <= 0:
            return

        ball_surf = pygame.Surface((radius * 8, radius * 8), pygame.SRCALPHA)
        center = radius * 4

        # 외부 글로우 (더 넓고 부드럽게)
        for r in range(radius * 4, radius, -2):
            ratio = (r - radius) / (radius * 3)
            glow_alpha = int(self.ball_alpha * 0.2 * ratio * ratio)
            # 색상 그라데이션 (외부로 갈수록 퍼플리시)
            glow_r = min(255, int(ball_color[0] * (0.7 + 0.3 * ratio) + 40 * ratio))
            glow_g = min(255, int(ball_color[1] * (0.6 + 0.2 * ratio)))
            glow_b = min(255, int(ball_color[2] * (0.8 + 0.2 * ratio) + 20 * ratio))
            pygame.draw.circle(ball_surf, (glow_r, glow_g, glow_b, glow_alpha),
                               (center, center), r)

        # 중간 글로우 레이어
        for r in range(int(radius * 1.8), radius, -1):
            mid_alpha = int(self.ball_alpha * 0.4 * ((r - radius) / (radius * 0.8)))
            mid_color = tuple(min(255, c + 30) for c in ball_color)
            pygame.draw.circle(ball_surf, (*mid_color, mid_alpha), (center, center), r)

        # 메인 공
        pygame.draw.circle(ball_surf, (*ball_color, self.ball_alpha), (center, center), radius)

        # 내부 그라데이션 (위쪽 밝게)
        for r in range(radius, 0, -1):
            ratio = r / radius
            grad_alpha = int(40 * (1 - ratio))
            pygame.draw.circle(ball_surf, (255, 255, 255, grad_alpha),
                               (center, center - int(radius * 0.1)), r)

        # 메인 하이라이트
        highlight_pos = (center - radius // 3, center - radius // 3)
        highlight_radius = max(2, radius // 3)
        pygame.draw.circle(ball_surf, (255, 255, 255, int(self.ball_alpha * 0.9)),
                           highlight_pos, highlight_radius)

        # 보조 하이라이트 (더 작은 반사)
        small_highlight = (center - radius // 4, center - radius // 4)
        pygame.draw.circle(ball_surf, (255, 255, 255, int(self.ball_alpha)),
                           small_highlight, max(1, radius // 5))

        # 림라이트 (가장자리 빛)
        rim_alpha = int(self.ball_alpha * 0.3)
        pygame.draw.circle(ball_surf, (200, 220, 255, rim_alpha),
                           (center, center), radius, 1)

        surface.blit(ball_surf, (int(self.ball_x - center), int(self.ball_y - center)))


# ─────────────────────────────────────────────
# 전역 API (변경 없음)
# ─────────────────────────────────────────────

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
