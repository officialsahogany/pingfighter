# -*- coding: utf-8 -*-
"""Ball Spawn Animation - 공 생성 애니메이션 시스템 (Ultra Premium Edition)

스테이지 시작 시 공이 양자 에너지/번개 소용돌이로 응축되어 생성되는
초고퀄리티 애니메이션을 담당합니다.

애니메이션 시퀀스:
1. 에너지 응축 (4초) - 양자 자기장 + 강화된 번개 회오리 + 전기 아크
2. 공 부양 (1.5초) - 완성된 공이 제자리에서 천천히 위아래로 부양 + 에너지 링
3. 서브 이동 (2.5초) - 홀로그램 효과 + 스파크 튀김 + 전기 아크로 이동

총 8초의 애니메이션 후 게임 시작
"""

import math
import random
import pygame
from typing import List, Tuple, Optional


class QuantumParticle:
    """양자 에너지 입자"""

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
        self.size = random.uniform(2, 6)
        self.speed = random.uniform(0.02, 0.05)  # 각속도

        # 색상 (전기 블루 ~ 양자 퍼플 ~ 핑크 그라데이션)
        color_choice = random.random()
        if color_choice < 0.4:
            # 전기 블루
            self.color = (random.randint(100, 200), random.randint(180, 255), 255)
        elif color_choice < 0.7:
            # 양자 퍼플
            self.color = (random.randint(150, 220), random.randint(80, 150), 255)
        else:
            # 에너지 핑크/화이트
            self.color = (255, random.randint(150, 255), random.randint(200, 255))

        # 밝기 변화
        self.brightness_phase = random.uniform(0, math.pi * 2)
        self.brightness_speed = random.uniform(3, 8)

        # 궤적 저장 (잔상 효과용)
        self.trail: List[Tuple[float, float, float]] = []
        self.trail_length = random.randint(5, 15)

    def update(self, progress: float, dt: float):
        """입자 업데이트 - progress: 0~1 (응축 진행도)"""
        # 잔상 저장
        self.trail.append((self.x, self.y, self.size))
        if len(self.trail) > self.trail_length:
            self.trail.pop(0)

        # 소용돌이 회전 + 중심으로 수렴
        self.angle += self.speed * (1 + progress * 2)  # 진행될수록 빠르게 회전

        # 반지름 감소 (중심으로 수렴)
        target_radius = self.radius * (1 - progress * 0.95)  # 최종적으로 5%까지 수렴

        # 위치 업데이트
        self.x = self.center_x + math.cos(self.angle) * target_radius
        self.y = self.center_y + math.sin(self.angle) * target_radius

        # 크기 변화 (수렴하면서 약간 커짐)
        self.size = max(1, self.size * (1 + progress * 0.01))

        # 밝기 변화
        self.brightness_phase += self.brightness_speed * dt

    def draw(self, surface: pygame.Surface, alpha_mult: float = 1.0):
        """입자와 잔상 그리기"""
        # 밝기 계산
        brightness = 0.5 + 0.5 * math.sin(self.brightness_phase)

        # 잔상 그리기
        for i, (tx, ty, ts) in enumerate(self.trail):
            trail_alpha = int(50 * (i / len(self.trail)) * alpha_mult) if self.trail else 0
            if trail_alpha > 0:
                trail_color = tuple(int(c * 0.5) for c in self.color)
                trail_surf = pygame.Surface((int(ts * 2), int(ts * 2)), pygame.SRCALPHA)
                pygame.draw.circle(trail_surf, (*trail_color, trail_alpha),
                                   (int(ts), int(ts)), int(ts * 0.7))
                surface.blit(trail_surf, (int(tx - ts), int(ty - ts)))

        # 메인 파티클
        alpha = int(200 * brightness * alpha_mult)
        glow_color = tuple(min(255, int(c * brightness * 1.2)) for c in self.color)

        # 글로우 효과
        glow_size = int(self.size * 2)
        glow_surf = pygame.Surface((glow_size * 4, glow_size * 4), pygame.SRCALPHA)
        for r in range(glow_size * 2, 0, -2):
            glow_alpha = int(alpha * (r / (glow_size * 2)) * 0.3)
            pygame.draw.circle(glow_surf, (*glow_color, glow_alpha),
                               (glow_size * 2, glow_size * 2), r)
        surface.blit(glow_surf, (int(self.x - glow_size * 2), int(self.y - glow_size * 2)))

        # 중심 코어
        core_surf = pygame.Surface((int(self.size * 4), int(self.size * 4)), pygame.SRCALPHA)
        pygame.draw.circle(core_surf, (*glow_color, min(255, alpha + 55)),
                           (int(self.size * 2), int(self.size * 2)), int(self.size))
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
        if branch_depth < 2 and is_main:  # 최대 2단계 분기
            self._generate_branches()

        # 수명 (더 짧게 - 빠른 페이드인/아웃)
        self.lifetime = random.uniform(0.08, 0.2) if is_main else random.uniform(0.05, 0.15)
        self.max_lifetime = self.lifetime

        # 페이드인 시간 (전체 수명의 20%)
        self.fade_in_time = self.max_lifetime * 0.2

        # 색상 (밝고 투명한 느낌의 색상)
        color_base = random.choice([
            (200, 230, 255),   # 라이트 블루
            (230, 200, 255),   # 라이트 퍼플
            (255, 255, 240),   # 화이트 옐로우
            (220, 255, 255),   # 시안
            (255, 220, 255),   # 핑크
            (255, 255, 255),   # 퓨어 화이트
        ])
        self.color = color_base

        # 두께 (메인 번개가 더 두껍게)
        self.thickness = random.randint(1, 3) if is_main else random.randint(1, 2)

        # 기본 투명도 (투명한 느낌)
        self.base_opacity = random.uniform(0.4, 0.7) if is_main else random.uniform(0.3, 0.5)

    def _generate_segments(self) -> List[Tuple[float, float, float, float]]:
        """지그재그 번개 세그먼트 생성"""
        segments = []

        dx = self.end_x - self.start_x
        dy = self.end_y - self.start_y
        length = math.hypot(dx, dy)

        if length < 1:
            return [(self.start_x, self.start_y, self.end_x, self.end_y)]

        # 세그먼트 수
        num_segments = max(4, int(length / 12))

        # 수직 방향 계산
        perp_x = -dy / length
        perp_y = dx / length

        current_x = self.start_x
        current_y = self.start_y

        for i in range(num_segments):
            t = (i + 1) / num_segments

            # 기본 다음 위치
            next_x = self.start_x + dx * t
            next_y = self.start_y + dy * t

            # 마지막 세그먼트가 아니면 지그재그 추가
            if i < num_segments - 1:
                max_offset = 18 * (1 - t * 0.3)
                offset = random.uniform(-max_offset, max_offset)
                next_x += perp_x * offset
                next_y += perp_y * offset

            segments.append((current_x, current_y, next_x, next_y))
            current_x = next_x
            current_y = next_y

        return segments

    def _generate_branches(self):
        """분기 번개 생성"""
        if len(self.segments) < 2:
            return

        # 분기점 선택 (1-2개)
        num_branches = random.randint(1, 2)
        branch_indices = random.sample(range(len(self.segments) - 1),
                                       min(num_branches, len(self.segments) - 1))

        for idx in branch_indices:
            seg = self.segments[idx]
            branch_start_x = seg[2]
            branch_start_y = seg[3]

            main_angle = math.atan2(self.end_y - self.start_y, self.end_x - self.start_x)
            branch_angle = main_angle + random.uniform(-math.pi/3, math.pi/3)

            main_length = math.hypot(self.end_x - self.start_x, self.end_y - self.start_y)
            branch_length = main_length * random.uniform(0.2, 0.4)

            branch_end_x = branch_start_x + math.cos(branch_angle) * branch_length
            branch_end_y = branch_start_y + math.sin(branch_angle) * branch_length

            self.branches.append(
                EnhancedLightningBolt(branch_start_x, branch_start_y,
                                      branch_end_x, branch_end_y,
                                      self.branch_depth + 1, is_main=False)
            )

    def update(self, dt: float) -> bool:
        """업데이트 - False 반환 시 삭제"""
        self.lifetime -= dt
        # 분기 번개 업데이트
        self.branches = [b for b in self.branches if b.update(dt)]
        return self.lifetime > 0

    def _calculate_alpha(self) -> float:
        """빠른 페이드인/아웃 알파 계산"""
        elapsed = self.max_lifetime - self.lifetime

        # 페이드인 (처음 20%)
        if elapsed < self.fade_in_time:
            fade_in_ratio = max(0.0, min(1.0, elapsed / self.fade_in_time))
            return fade_in_ratio * self.base_opacity

        # 페이드아웃 (나머지 시간)
        fade_out_duration = self.max_lifetime - self.fade_in_time
        if fade_out_duration <= 0:
            return self.base_opacity
        remaining_ratio = max(0.0, min(1.0, self.lifetime / fade_out_duration))
        # 부드러운 ease-out 커브
        return self.base_opacity * math.sqrt(remaining_ratio)

    def draw(self, surface: pygame.Surface, alpha_mult: float = 1.0):
        """번개 그리기 - 투명한 그라데이션 효과"""
        alpha = self._calculate_alpha() * alpha_mult
        if alpha <= 0.01:
            return

        # 분기 번개 먼저 그리기
        for branch in self.branches:
            branch.draw(surface, alpha_mult * 0.6)

        # 번개 전체 크기 계산
        all_x = [s[0] for s in self.segments] + [self.segments[-1][2]]
        all_y = [s[1] for s in self.segments] + [self.segments[-1][3]]
        min_x, max_x = min(all_x), max(all_x)
        min_y, max_y = min(all_y), max(all_y)

        width = int(max_x - min_x) + 40
        height = int(max_y - min_y) + 40
        offset_x = int(min_x) - 20
        offset_y = int(min_y) - 20

        # 번개 서피스 생성 (투명 배경)
        lightning_surf = pygame.Surface((width, height), pygame.SRCALPHA)

        # 그라데이션 글로우 레이어 (외부에서 내부로, 투명하게)
        glow_layers = [
            (12, 0.08),  # 가장 외부 - 매우 투명
            (8, 0.15),   # 중간 외부
            (5, 0.25),   # 중간
            (3, 0.4),    # 중간 내부
        ]

        for glow_size, glow_opacity in glow_layers:
            glow_alpha = max(0, min(255, int(255 * alpha * glow_opacity)))
            # 밝은 색상 (어두운 테두리 방지)
            glow_color = tuple(min(255, c + 30) for c in self.color)

            for sx, sy, ex, ey in self.segments:
                local_sx = sx - offset_x
                local_sy = sy - offset_y
                local_ex = ex - offset_x
                local_ey = ey - offset_y

                # 글로우 라인
                pygame.draw.line(lightning_surf, (*glow_color, glow_alpha),
                                 (int(local_sx), int(local_sy)),
                                 (int(local_ex), int(local_ey)),
                                 self.thickness + glow_size)

        # 메인 번개 라인 (밝은 색)
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

        # 밝은 코어 (화이트)
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

        # 서피스 블릿
        surface.blit(lightning_surf, (offset_x, offset_y))

        # 세그먼트 끝점에 작은 글로우 스파크
        if self.is_main and random.random() < 0.2:
            for sx, sy, ex, ey in self.segments:
                if random.random() < 0.15:
                    spark_alpha = max(0, min(255, int(180 * alpha)))
                    spark_surf = pygame.Surface((16, 16), pygame.SRCALPHA)
                    # 부드러운 글로우 스파크
                    for r in range(6, 0, -1):
                        spark_glow_alpha = max(0, min(255, int(spark_alpha * (r / 6) * 0.5)))
                        pygame.draw.circle(spark_surf, (255, 255, 255, spark_glow_alpha),
                                           (8, 8), r)
                    surface.blit(spark_surf, (int(ex - 8), int(ey - 8)))


class ChainLightning:
    """체인 라이트닝 - 여러 점을 연결하는 번개"""

    def __init__(self, points: List[Tuple[float, float]]):
        self.points = points
        self.bolts: List[EnhancedLightningBolt] = []

        # 점들 사이에 번개 생성
        for i in range(len(points) - 1):
            self.bolts.append(
                EnhancedLightningBolt(points[i][0], points[i][1],
                                      points[i+1][0], points[i+1][1],
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

        # 색상
        self.color = random.choice([
            (150, 200, 255),  # 블루
            (200, 150, 255),  # 퍼플
            (255, 255, 200),  # 옐로우
            (200, 255, 255),  # 시안
        ])

        self.lifetime = random.uniform(0.3, 0.8)
        self.max_lifetime = self.lifetime
        self.thickness = random.randint(1, 3)

        # 노이즈 포인트
        self.noise_points = [random.uniform(-5, 5) for _ in range(10)]

    def update(self, dt: float, new_center: Tuple[float, float] = None) -> bool:
        self.lifetime -= dt
        self.angle += self.rotation_speed * dt

        if new_center:
            self.center_x, self.center_y = new_center

        # 노이즈 업데이트
        for i in range(len(self.noise_points)):
            self.noise_points[i] += random.uniform(-2, 2)
            self.noise_points[i] = max(-8, min(8, self.noise_points[i]))

        return self.lifetime > 0

    def draw(self, surface: pygame.Surface, alpha_mult: float = 1.0):
        life_ratio = self.lifetime / self.max_lifetime
        alpha = int(255 * life_ratio * alpha_mult)

        # 아크 세그먼트 계산
        num_segments = 15
        points = []

        for i in range(num_segments + 1):
            t = i / num_segments
            current_angle = self.angle + t * self.arc_length

            # 노이즈 적용
            noise_idx = int(t * (len(self.noise_points) - 1))
            noise = self.noise_points[noise_idx] * (1 - abs(t - 0.5) * 2)  # 중간이 더 노이즈

            r = self.radius + noise
            x = self.center_x + math.cos(current_angle) * r
            y = self.center_y + math.sin(current_angle) * r
            points.append((int(x), int(y)))

        if len(points) < 2:
            return

        # 외부 글로우
        glow_color = tuple(int(c * 0.6) for c in self.color)
        for i in range(len(points) - 1):
            pygame.draw.line(surface, glow_color, points[i], points[i+1],
                             self.thickness + 3)

        # 메인 아크
        for i in range(len(points) - 1):
            pygame.draw.line(surface, self.color, points[i], points[i+1],
                             self.thickness + 1)

        # 밝은 코어
        for i in range(len(points) - 1):
            pygame.draw.line(surface, (255, 255, 255), points[i], points[i+1],
                             max(1, self.thickness - 1))


class Spark:
    """스파크 파티클 - 공이 이동할 때 튀는 불꽃"""

    def __init__(self, x: float, y: float, direction: float = None):
        self.x = x
        self.y = y

        # 방향 (지정되지 않으면 랜덤)
        if direction is None:
            direction = random.uniform(0, math.pi * 2)

        speed = random.uniform(50, 200)
        self.vx = math.cos(direction) * speed
        self.vy = math.sin(direction) * speed

        # 중력 영향
        self.gravity = random.uniform(100, 300)

        # 색상 (밝은 전기색)
        self.color = random.choice([
            (255, 255, 200),  # 밝은 노랑
            (255, 200, 100),  # 주황
            (200, 220, 255),  # 라이트 블루
            (255, 255, 255),  # 화이트
            (255, 200, 255),  # 핑크
        ])

        self.size = random.uniform(1.5, 4)
        self.lifetime = random.uniform(0.2, 0.6)
        self.max_lifetime = self.lifetime

        # 꼬리 효과
        self.trail: List[Tuple[float, float]] = []
        self.trail_length = random.randint(3, 8)

    def update(self, dt: float) -> bool:
        self.lifetime -= dt

        # 꼬리 저장
        self.trail.append((self.x, self.y))
        if len(self.trail) > self.trail_length:
            self.trail.pop(0)

        # 물리 업데이트
        self.x += self.vx * dt
        self.y += self.vy * dt
        self.vy += self.gravity * dt

        # 속도 감소
        self.vx *= 0.98
        self.vy *= 0.98

        return self.lifetime > 0

    def draw(self, surface: pygame.Surface, alpha_mult: float = 1.0):
        life_ratio = self.lifetime / self.max_lifetime
        alpha = int(255 * life_ratio * alpha_mult)

        # 꼬리 그리기
        for i, (tx, ty) in enumerate(self.trail):
            trail_alpha = int(alpha * (i / len(self.trail)) * 0.5)
            trail_size = self.size * (i / len(self.trail))
            if trail_alpha > 0 and trail_size > 0:
                pygame.draw.circle(surface, (*self.color[:3],),
                                   (int(tx), int(ty)), int(trail_size))

        # 메인 스파크
        if alpha > 0:
            # 글로우
            glow_surf = pygame.Surface((int(self.size * 6), int(self.size * 6)), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (*self.color, int(alpha * 0.3)),
                               (int(self.size * 3), int(self.size * 3)), int(self.size * 2))
            surface.blit(glow_surf, (int(self.x - self.size * 3), int(self.y - self.size * 3)))

            # 코어
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

        # 깜빡임 효과
        self.flicker_phase = random.uniform(0, math.pi * 2)
        self.flicker_speed = random.uniform(8, 15)

        # 색상 (홀로그램 느낌)
        self.base_color = random.choice([
            (100, 200, 255),  # 시안
            (150, 100, 255),  # 퍼플
            (100, 255, 200),  # 민트
        ])

        self.thickness = random.randint(1, 2)
        self.segments = random.randint(16, 32)

        # 왜곡 효과
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

        # 왜곡 업데이트
        for i in range(len(self.distortion)):
            self.distortion[i] += random.uniform(-1, 1)
            self.distortion[i] = max(-5, min(5, self.distortion[i]))

        return self.lifetime > 0

    def draw(self, surface: pygame.Surface, alpha_mult: float = 1.0):
        life_ratio = self.lifetime / self.max_lifetime

        # 깜빡임 계산 (더 드라마틱하게)
        flicker = 0.3 + 0.7 * (0.5 + 0.5 * math.sin(self.flicker_phase))
        # 랜덤 글리치
        if random.random() < 0.1:
            flicker *= random.uniform(0.2, 1.5)

        alpha = int(200 * life_ratio * flicker * alpha_mult)
        if alpha <= 0:
            return

        # 세그먼트별로 원 그리기
        angle_step = (math.pi * 2) / self.segments

        for i in range(self.segments):
            # 일부 세그먼트 스킵 (글리치 효과)
            if random.random() < 0.05:
                continue

            start_angle = i * angle_step
            end_angle = (i + 0.8) * angle_step  # 살짝 갭

            r = self.radius + self.distortion[i]

            sx = self.center_x + math.cos(start_angle) * r
            sy = self.center_y + math.sin(start_angle) * r
            ex = self.center_x + math.cos(end_angle) * r
            ey = self.center_y + math.sin(end_angle) * r

            # 색상 변조 (홀로그램 느낌)
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

        # 색상
        self.color = random.choice([
            (100, 180, 255, 100),  # 블루
            (180, 100, 255, 100),  # 퍼플
            (255, 150, 200, 80),   # 핑크
        ])

        # 두께 및 점선 패턴
        self.thickness = random.randint(1, 3)
        self.dash_count = random.randint(8, 16)

    def update(self, progress: float, dt: float):
        """링 업데이트"""
        self.angle += self.rotation_speed * dt
        # 진행되면서 반지름 감소
        self.radius *= (1 - progress * 0.02)

    def draw(self, surface: pygame.Surface, alpha_mult: float = 1.0):
        """소용돌이 링 그리기"""
        if self.radius < 5:
            return

        # 점선 원 그리기
        dash_angle = (math.pi * 2) / self.dash_count

        for i in range(self.dash_count):
            start_angle = self.angle + i * dash_angle
            end_angle = start_angle + dash_angle * 0.5

            # 호 시작/끝점 계산
            sx = self.center_x + math.cos(start_angle) * self.radius
            sy = self.center_y + math.sin(start_angle) * self.radius
            ex = self.center_x + math.cos(end_angle) * self.radius
            ey = self.center_y + math.sin(end_angle) * self.radius

            alpha = int(self.color[3] * alpha_mult)
            color = (*self.color[:3], alpha)

            # 라인으로 호 근사
            pygame.draw.line(surface, color[:3], (int(sx), int(sy)), (int(ex), int(ey)),
                             self.thickness)


class EnergyRing:
    """에너지 링 - 공 주변 확장하는 링 효과"""

    def __init__(self, center_x: float, center_y: float, start_radius: float = 10):
        self.center_x = center_x
        self.center_y = center_y
        self.radius = start_radius
        self.max_radius = start_radius * 5

        self.color = random.choice([
            (150, 200, 255),  # 블루
            (200, 150, 255),  # 퍼플
            (255, 200, 150),  # 오렌지
            (150, 255, 200),  # 민트
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

        # 외부 글로우
        glow_surf = pygame.Surface((int(self.radius * 2 + 20), int(self.radius * 2 + 20)),
                                    pygame.SRCALPHA)
        center = int(self.radius + 10)

        for i in range(3, 0, -1):
            ring_alpha = int(alpha * 0.3 / i)
            pygame.draw.circle(glow_surf, (*self.color, ring_alpha), (center, center),
                               int(self.radius + i * 2), self.thickness + i)

        surface.blit(glow_surf,
                     (int(self.center_x - center), int(self.center_y - center)))

        # 메인 링
        pygame.draw.circle(surface, self.color,
                           (int(self.center_x), int(self.center_y)),
                           int(self.radius), self.thickness)


class BallSpawnAnimation:
    """공 생성 애니메이션 메인 클래스 (Ultra Premium Edition)

    시퀀스:
    1. Phase 1: 에너지 응축 (0-4초) - 양자 입자들이 소용돌이치며 중심으로 응축 + 강화된 번개
    2. Phase 2: 공 부양 (4-5.5초) - 완성된 공이 위아래로 부양 + 에너지 링
    3. Phase 3: 서브 이동 (5.5-8초) - 홀로그램 + 스파크 + 전기 아크로 서브 위치로 이동
    """

    # 페이즈 타이밍 (초)
    PHASE_1_DURATION = 4.0      # 에너지 응축
    PHASE_2_DURATION = 1.5      # 공 부양
    PHASE_3_DURATION = 2.5      # 서브 이동

    TOTAL_DURATION = PHASE_1_DURATION + PHASE_2_DURATION + PHASE_3_DURATION  # 8초

    # Phase 2 파티클 최대 개수 제한 (성능 최적화)
    MAX_ENERGY_RINGS_PHASE2 = 4
    MAX_ELECTRIC_ARCS_PHASE2 = 6

    def __init__(self, screen_width: int, screen_height: int):
        self.screen_width = screen_width
        self.screen_height = screen_height

        # 맵 중앙 좌표
        self.center_x = screen_width // 2
        self.center_y = screen_height // 2

        # 상태
        self.active = False
        self.completed = False  # 애니메이션 완료 플래그 추가
        self.elapsed_time = 0.0
        self.current_phase = 0

        # 서브 대상 (True=플레이어, False=보스)
        self.is_player_serve = True
        self.player_y = screen_height - 100  # 플레이어 위치
        self.boss_y = 100  # 보스 위치

        # 공 상태
        self.ball_x = self.center_x
        self.ball_y = self.center_y
        self.ball_radius = 12  # 최종 공 크기
        self.ball_visible = False
        self.ball_alpha = 0
        self.ball_scale = 0.1

        # 부양 효과
        self.levitate_offset = 0
        self.levitate_speed = 3.0

        # 파티클 시스템
        self.quantum_particles: List[QuantumParticle] = []
        self.lightning_bolts: List[EnhancedLightningBolt] = []
        self.chain_lightnings: List[ChainLightning] = []
        self.vortex_rings: List[VortexRing] = []
        self.electric_arcs: List[ElectricArc] = []
        self.sparks: List[Spark] = []
        self.hologram_rings: List[HologramRing] = []
        self.energy_rings: List[EnergyRing] = []

        # 파티클 스폰 타이머
        self.particle_spawn_timer = 0
        self.lightning_spawn_timer = 0
        self.ring_spawn_timer = 0
        self.arc_spawn_timer = 0
        self.spark_spawn_timer = 0
        self.hologram_spawn_timer = 0
        self.energy_ring_timer = 0

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

    def start(self, is_player_serve: bool, player_y: Optional[float] = None,
              boss_y: Optional[float] = None):
        """애니메이션 시작"""
        self.active = True
        self.completed = False  # 완료 플래그 리셋
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

        # 파티클 초기화
        self.quantum_particles.clear()
        self.lightning_bolts.clear()
        self.chain_lightnings.clear()
        self.vortex_rings.clear()
        self.electric_arcs.clear()
        self.sparks.clear()
        self.hologram_rings.clear()
        self.energy_rings.clear()

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

        # 타이머 리셋
        self.particle_spawn_timer = 0
        self.lightning_spawn_timer = 0
        self.ring_spawn_timer = 0
        self.arc_spawn_timer = 0
        self.spark_spawn_timer = 0
        self.hologram_spawn_timer = 0
        self.energy_ring_timer = 0

    def _spawn_initial_particles(self):
        """초기 양자 입자들 생성"""
        max_radius = min(self.screen_width, self.screen_height) * 0.4

        # 양자 입자 (80-120개로 증가)
        for _ in range(random.randint(80, 120)):
            self.quantum_particles.append(
                QuantumParticle(self.center_x, self.center_y, max_radius)
            )

        # 소용돌이 링 (7-12개로 증가)
        for i in range(random.randint(7, 12)):
            ring_radius = max_radius * (0.2 + i * 0.08)
            self.vortex_rings.append(
                VortexRing(self.center_x, self.center_y, ring_radius)
            )

    def stop(self):
        """애니메이션 중지"""
        self.active = False

    def is_active(self) -> bool:
        """애니메이션 활성 여부"""
        return self.active

    def is_complete(self) -> bool:
        """애니메이션 완료 여부 - completed 플래그로 확인"""
        # completed 플래그가 True면 애니메이션이 완료된 것
        result = self.completed
        return result

    def get_ball_position(self) -> Tuple[float, float]:
        """현재 공 위치 반환"""
        return (self.ball_x, self.ball_y)

    def update(self, dt: float):
        """애니메이션 업데이트"""
        if not self.active:
            return

        # dt가 비정상적으로 크면 제한 (게임 초기화 지연으로 인한 문제 방지)
        # 최대 33ms (약 30fps 기준)으로 제한하여 부드러운 애니메이션 보장
        original_dt = dt
        dt = min(dt, 0.033)
        if original_dt > 0.05:
            print(f"[DEBUG] dt 제한됨: {original_dt:.3f}s -> {dt:.3f}s")

        self.elapsed_time += dt

        # 페이즈 전환 체크
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
            # 애니메이션 완료
            if not self.completed:
                print(f"[DEBUG] 애니메이션 완료! elapsed={self.elapsed_time:.3f}s")
                self.completed = True  # 완료 플래그 설정
            self.active = False
            self.ball_visible = True
            self.ball_alpha = 255
            self.ball_scale = 1.0

    def _update_phase_1(self, dt: float):
        """Phase 1: 에너지 응축 (4초) - 강화된 번개 효과"""
        progress = self.elapsed_time / self.PHASE_1_DURATION

        # 양자 입자 업데이트
        for particle in self.quantum_particles:
            particle.update(progress, dt)

        # 소용돌이 링 업데이트
        for ring in self.vortex_rings:
            ring.update(progress, dt)

        # 강화된 번개 생성 (더 자주, 더 화려하게)
        self.lightning_spawn_timer += dt
        spawn_interval = max(0.03, 0.2 - progress * 0.17)  # 더 자주 생성

        if self.lightning_spawn_timer >= spawn_interval:
            self.lightning_spawn_timer = 0
            self._spawn_enhanced_lightning(progress)

        # 체인 라이트닝 (가끔)
        if random.random() < 0.02 * (1 + progress):
            self._spawn_chain_lightning()

        # 번개 업데이트
        self.lightning_bolts = [bolt for bolt in self.lightning_bolts if bolt.update(dt)]
        self.chain_lightnings = [chain for chain in self.chain_lightnings if chain.update(dt)]

        # 전기 아크 생성 (Phase 1 후반)
        if progress > 0.5:
            self.arc_spawn_timer += dt
            if self.arc_spawn_timer >= 0.3:
                self.arc_spawn_timer = 0
                arc_radius = 50 * (1 - (progress - 0.5) * 1.5)
                self.electric_arcs.append(
                    ElectricArc(self.center_x, self.center_y, max(15, arc_radius))
                )

        # 전기 아크 업데이트
        self.electric_arcs = [arc for arc in self.electric_arcs
                              if arc.update(dt, (self.center_x, self.center_y))]

        # 추가 파티클 생성 (가끔)
        self.particle_spawn_timer += dt
        if self.particle_spawn_timer >= 0.3 and len(self.quantum_particles) < 180:
            self.particle_spawn_timer = 0
            max_radius = min(self.screen_width, self.screen_height) * 0.4 * (1 - progress * 0.5)
            for _ in range(random.randint(8, 15)):
                self.quantum_particles.append(
                    QuantumParticle(self.center_x, self.center_y, max_radius)
                )

        # 중심 코어 글로우 증가
        self.core_glow_radius = 20 + progress * 40
        self.core_glow_alpha = int(100 + progress * 155)

        # Phase 1 종료 직전 플래시 효과 (더 강하게)
        if progress > 0.92:
            self.flash_alpha = int(255 * (progress - 0.92) * 12.5)
            self.flash_color = (220, 240, 255)

    def _update_phase_2(self, dt: float):
        """Phase 2: 공 부양 (1.5초) - 에너지 링 효과 추가 (최적화됨)"""
        phase_time = self.elapsed_time - self.PHASE_1_DURATION
        progress = phase_time / self.PHASE_2_DURATION

        # 공 나타남
        self.ball_visible = True
        self.ball_alpha = min(255, int(progress * 400))
        self.ball_scale = min(1.0, 0.3 + progress * 0.7)

        # 위아래 부양 효과
        self.levitate_offset = math.sin(phase_time * self.levitate_speed * 2) * 10
        self.ball_y = self.center_y + self.levitate_offset

        # 에너지 링 방출 - 최적화: 간격 늘리고 개수 제한
        self.energy_ring_timer += dt
        if self.energy_ring_timer >= 0.35 and len(self.energy_rings) < self.MAX_ENERGY_RINGS_PHASE2:
            self.energy_ring_timer = 0
            self.energy_rings.append(
                EnergyRing(self.ball_x, self.ball_y, self.ball_radius * self.ball_scale)
            )

        # 에너지 링 업데이트
        self.energy_rings = [ring for ring in self.energy_rings
                             if ring.update(dt, (self.ball_x, self.ball_y))]

        # 전기 아크 (공 주변) - 최적화: 간격 늘리고 개수 제한
        self.arc_spawn_timer += dt
        if self.arc_spawn_timer >= 0.3 and len(self.electric_arcs) < self.MAX_ELECTRIC_ARCS_PHASE2:
            self.arc_spawn_timer = 0
            self.electric_arcs.append(
                ElectricArc(self.ball_x, self.ball_y, self.ball_radius * 2 * self.ball_scale)
            )

        self.electric_arcs = [arc for arc in self.electric_arcs
                              if arc.update(dt, (self.ball_x, self.ball_y))]

        # 잔여 파티클 빠르게 제거 - 최적화: 더 빠르게 페이드아웃
        self.quantum_particles = [p for p in self.quantum_particles if random.random() > 0.12]

        # 플래시 페이드아웃
        self.flash_alpha = max(0, int(255 * (1 - progress)))

        # 코어 글로우 유지
        self.core_glow_radius = 50 - progress * 25
        self.core_glow_alpha = int(220 * (1 - progress * 0.5))

        # 페이즈 시작 시 형성 효과음
        if not self.sounds_played['formed'] and progress > 0.1:
            self.sounds_played['formed'] = True

    def _update_phase_3(self, dt: float):
        """Phase 3: 서브 이동 (2.5초) - 홀로그램 + 스파크 + 전기 아크"""
        phase_time = self.elapsed_time - self.PHASE_1_DURATION - self.PHASE_2_DURATION
        progress = phase_time / self.PHASE_3_DURATION

        # Ease-out 이동
        eased_progress = 1 - (1 - progress) ** 3

        # 목표 위치 (서브 차례에 따라)
        target_y = self.player_y if self.is_player_serve else self.boss_y

        # 이전 위치 저장 (스파크용)
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

        # 홀로그램 링 효과 (깜빡이며 따라다님)
        self.hologram_spawn_timer += dt
        if self.hologram_spawn_timer >= 0.15:
            self.hologram_spawn_timer = 0
            # 여러 크기의 홀로그램 링
            for radius_mult in [1.5, 2.5, 3.5]:
                self.hologram_rings.append(
                    HologramRing(self.ball_x, self.ball_y,
                                 self.ball_radius * radius_mult)
                )

        # 홀로그램 업데이트
        self.hologram_rings = [ring for ring in self.hologram_rings
                               if ring.update(dt, (self.ball_x, self.ball_y))]

        # 스파크 생성 (이동 중)
        speed = abs(self.ball_y - prev_ball_y) / dt if dt > 0 else 0
        self.spark_spawn_timer += dt

        if self.spark_spawn_timer >= 0.05 and speed > 10:
            self.spark_spawn_timer = 0
            # 이동 방향 반대로 스파크 튀김
            move_direction = math.pi / 2 if self.ball_y > prev_ball_y else -math.pi / 2
            for _ in range(random.randint(2, 5)):
                spark_direction = move_direction + math.pi + random.uniform(-0.8, 0.8)
                self.sparks.append(
                    Spark(self.ball_x + random.uniform(-10, 10),
                          self.ball_y + random.uniform(-5, 5),
                          spark_direction)
                )

        # 스파크 업데이트
        self.sparks = [spark for spark in self.sparks if spark.update(dt)]

        # 전기 아크 (공 주변, 계속 유지)
        self.arc_spawn_timer += dt
        if self.arc_spawn_timer >= 0.12:
            self.arc_spawn_timer = 0
            self.electric_arcs.append(
                ElectricArc(self.ball_x, self.ball_y, self.ball_radius * 2)
            )

        self.electric_arcs = [arc for arc in self.electric_arcs
                              if arc.update(dt, (self.ball_x, self.ball_y))]

        # 에너지 링 (가끔)
        self.energy_ring_timer += dt
        if self.energy_ring_timer >= 0.4:
            self.energy_ring_timer = 0
            self.energy_rings.append(
                EnergyRing(self.ball_x, self.ball_y, self.ball_radius)
            )

        self.energy_rings = [ring for ring in self.energy_rings
                             if ring.update(dt, (self.ball_x, self.ball_y))]

        # 파티클 페이드아웃
        self.quantum_particles = [p for p in self.quantum_particles
                                   if random.random() > 0.08]

        # 코어 글로우 페이드아웃
        self.core_glow_alpha = int(100 * (1 - progress))

        # 도착 직전 플래시
        if progress > 0.9:
            arrival_progress = (progress - 0.9) / 0.1
            self.flash_alpha = int(100 * arrival_progress * (1 - arrival_progress) * 4)
            self.flash_color = (255, 255, 220)

    def _spawn_enhanced_lightning(self, progress: float):
        """강화된 번개 생성"""
        # 중심으로 향하는 번개
        max_radius = min(self.screen_width, self.screen_height) * 0.4 * (1 - progress * 0.5)

        # 여러 개의 번개 동시 생성
        num_bolts = random.randint(1, 3)
        for _ in range(num_bolts):
            angle = random.uniform(0, math.pi * 2)
            start_dist = max_radius * random.uniform(0.6, 1.0)

            start_x = self.center_x + math.cos(angle) * start_dist
            start_y = self.center_y + math.sin(angle) * start_dist

            # 목표: 중심 근처
            end_dist = max(10, start_dist * (1 - progress) * random.uniform(0.2, 0.5))
            end_angle = angle + random.uniform(-0.4, 0.4)
            end_x = self.center_x + math.cos(end_angle) * end_dist
            end_y = self.center_y + math.sin(end_angle) * end_dist

            self.lightning_bolts.append(
                EnhancedLightningBolt(start_x, start_y, end_x, end_y)
            )

        # 입자 간 번개 (더 자주)
        if random.random() < 0.4 and len(self.quantum_particles) >= 2:
            p1, p2 = random.sample(self.quantum_particles, 2)
            self.lightning_bolts.append(
                EnhancedLightningBolt(p1.x, p1.y, p2.x, p2.y, branch_depth=1)
            )

    def _spawn_chain_lightning(self):
        """체인 라이트닝 생성"""
        if len(self.quantum_particles) < 4:
            return

        # 랜덤하게 3-5개 입자 선택
        num_points = random.randint(3, min(5, len(self.quantum_particles)))
        selected = random.sample(self.quantum_particles, num_points)
        points = [(p.x, p.y) for p in selected]

        self.chain_lightnings.append(ChainLightning(points))

    def draw(self, surface: pygame.Surface, ball_color: Tuple[int, int, int] = (255, 255, 255)):
        """애니메이션 렌더링"""
        if not self.active and not self.ball_visible:
            return

        # 소용돌이 링 그리기
        for ring in self.vortex_rings:
            ring.draw(surface)

        # 에너지 링 그리기
        for ring in self.energy_rings:
            ring.draw(surface)

        # 양자 입자 그리기
        for particle in self.quantum_particles:
            alpha_mult = 1.0 if self.current_phase == 1 else (1.0 - (self.current_phase - 1) * 0.4)
            particle.draw(surface, alpha_mult)

        # 체인 라이트닝 그리기
        for chain in self.chain_lightnings:
            chain.draw(surface)

        # 번개 그리기
        for bolt in self.lightning_bolts:
            bolt.draw(surface)

        # 전기 아크 그리기
        for arc in self.electric_arcs:
            arc.draw(surface)

        # 홀로그램 링 그리기
        for holo in self.hologram_rings:
            holo.draw(surface)

        # 스파크 그리기
        for spark in self.sparks:
            spark.draw(surface)

        # 중심 코어 글로우
        if self.core_glow_alpha > 0 and self.core_glow_radius > 0:
            self._draw_core_glow(surface)

        # 공 그리기
        if self.ball_visible and self.ball_alpha > 0:
            self._draw_ball(surface, ball_color)

        # 플래시 오버레이
        if self.flash_alpha > 0:
            flash_surf = pygame.Surface((self.screen_width, self.screen_height), pygame.SRCALPHA)
            flash_surf.fill((*self.flash_color, min(255, self.flash_alpha)))
            surface.blit(flash_surf, (0, 0))

    def _draw_core_glow(self, surface: pygame.Surface):
        """중심 코어 글로우 그리기 (강화됨)"""
        glow_surf = pygame.Surface((int(self.core_glow_radius * 4),
                                     int(self.core_glow_radius * 4)), pygame.SRCALPHA)
        center = int(self.core_glow_radius * 2)

        # 여러 레이어의 글로우 (더 많은 레이어)
        colors = [
            (255, 255, 255),  # 흰색 코어
            (220, 240, 255),  # 라이트 블루 1
            (200, 220, 255),  # 라이트 블루 2
            (180, 200, 255),  # 블루 1
            (160, 180, 255),  # 블루 2
            (180, 150, 255),  # 퍼플
        ]

        for i, color in enumerate(colors):
            radius = int(self.core_glow_radius * (1 - i * 0.15))
            alpha = int(self.core_glow_alpha * (1 - i * 0.15))
            if radius > 0 and alpha > 0:
                pygame.draw.circle(glow_surf, (*color, alpha), (center, center), radius)

        surface.blit(glow_surf,
                     (int(self.center_x - center), int(self.center_y - center)))

    def _draw_ball(self, surface: pygame.Surface, ball_color: Tuple[int, int, int]):
        """공 그리기 (강화된 글로우)"""
        radius = int(self.ball_radius * self.ball_scale)
        if radius <= 0:
            return

        # 공 서피스
        ball_surf = pygame.Surface((radius * 6, radius * 6), pygame.SRCALPHA)
        center = radius * 3

        # 외부 글로우 (더 넓고 강하게)
        for r in range(radius * 3, radius, -2):
            glow_alpha = int(self.ball_alpha * 0.25 * (r - radius) / (radius * 2))
            glow_color = tuple(min(255, int(c * 1.1)) for c in ball_color)
            pygame.draw.circle(ball_surf, (*glow_color, glow_alpha), (center, center), r)

        # 메인 공
        pygame.draw.circle(ball_surf, (*ball_color, self.ball_alpha), (center, center), radius)

        # 하이라이트 (더 밝게)
        highlight_pos = (center - radius // 3, center - radius // 3)
        highlight_radius = max(2, radius // 3)
        pygame.draw.circle(ball_surf, (255, 255, 255, int(self.ball_alpha * 0.9)),
                           highlight_pos, highlight_radius)

        # 작은 하이라이트
        small_highlight = (center - radius // 4, center - radius // 4)
        pygame.draw.circle(ball_surf, (255, 255, 255, int(self.ball_alpha)),
                           small_highlight, max(1, radius // 5))

        surface.blit(ball_surf, (int(self.ball_x - center), int(self.ball_y - center)))


# 전역 인스턴스
_ball_spawn_animation: Optional[BallSpawnAnimation] = None


def get_ball_spawn_animation() -> BallSpawnAnimation:
    """싱글톤 인스턴스 반환"""
    global _ball_spawn_animation
    if _ball_spawn_animation is None:
        _ball_spawn_animation = BallSpawnAnimation(800, 600)  # 기본값, 나중에 리사이즈
    return _ball_spawn_animation


def init_ball_spawn_animation(width: int, height: int):
    """애니메이션 초기화"""
    global _ball_spawn_animation
    _ball_spawn_animation = BallSpawnAnimation(width, height)


def start_ball_spawn_animation(is_player_serve: bool, player_y: float, boss_y: float):
    """공 생성 애니메이션 시작"""
    anim = get_ball_spawn_animation()
    anim.start(is_player_serve, player_y, boss_y)
    print(f"[DEBUG] 애니메이션 시작 후 상태: active={anim.active}, elapsed_time={anim.elapsed_time}, TOTAL={anim.TOTAL_DURATION}")


def update_ball_spawn_animation(dt: float):
    """애니메이션 업데이트"""
    anim = get_ball_spawn_animation()
    if anim.is_active():
        anim.update(dt)


def draw_ball_spawn_animation(surface: pygame.Surface,
                               ball_color: Tuple[int, int, int] = (255, 255, 255)):
    """애니메이션 렌더링"""
    anim = get_ball_spawn_animation()
    if anim.is_active():
        anim.draw(surface, ball_color)


def is_ball_spawn_animation_active() -> bool:
    """애니메이션 활성 여부"""
    anim = get_ball_spawn_animation()
    return anim.is_active()


def is_ball_spawn_animation_complete() -> bool:
    """애니메이션 완료 여부"""
    anim = get_ball_spawn_animation()
    return anim.is_complete()


def get_spawned_ball_position() -> Tuple[float, float]:
    """생성된 공 위치 반환"""
    anim = get_ball_spawn_animation()
    return anim.get_ball_position()
