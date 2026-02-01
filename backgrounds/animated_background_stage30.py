# -*- coding: utf-8 -*-
"""
Stage 30 - 고대 투기장 (Ancient Colosseum Arena)
로마 콜로세움 스타일의 투기장 배경
"""
import pygame
import math
import random
import threading
import os
import sys

def resource_path(relative_path):
    """PyInstaller 번들과 일반 실행 모두에서 작동하는 리소스 경로 반환"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    return os.path.join(base_path, relative_path)

# ============================================================
# Surface 캐시 시스템
# ============================================================
_stage30_surface_cache = {}
_stage30_cache_lock = threading.Lock()

def _get_cached_surface(width: int, height: int) -> pygame.Surface:
    """캐시된 투명 Surface 반환"""
    key = (width, height)
    with _stage30_cache_lock:
        if key not in _stage30_surface_cache:
            if len(_stage30_surface_cache) > 50:
                _stage30_surface_cache.clear()
            _stage30_surface_cache[key] = pygame.Surface((width, height), pygame.SRCALPHA)
        surface = _stage30_surface_cache[key]
        surface.fill((0, 0, 0, 0))
        return surface


class AnimatedBackgroundStage30:
    """고대 투기장 배경 - 로마 콜로세움 스타일"""

    def __init__(self, width=600, height=750):
        self.width = width
        self.height = height
        self.time = 0

        # 배경 레이어 서피스
        self.floor_surface = pygame.Surface((width, height), pygame.SRCALPHA)
        self.wall_surface = pygame.Surface((width, height), pygame.SRCALPHA)
        self.effect_surface = pygame.Surface((width, height), pygame.SRCALPHA)

        # 관중 함성 효과
        self.crowd_noise_level = 0.5
        self.crowd_wave_timer = 0

        # 횃불 데이터
        self.torches = self._init_torches()

        # 먼지 파티클
        self.dust_particles = []
        for _ in range(30):
            self.dust_particles.append(self._create_dust_particle())

        # 관중 실루엣 데이터
        self.spectators = self._init_spectators()

        # 프리렌더
        self._prerender_floor()
        self._prerender_walls()

    def _init_torches(self):
        """횃불 위치 초기화"""
        torches = []
        # 좌우 벽에 횃불 배치
        positions = [
            (30, 150), (30, 350), (30, 550),  # 왼쪽
            (570, 150), (570, 350), (570, 550),  # 오른쪽
        ]
        for x, y in positions:
            torches.append({
                'x': x, 'y': y,
                'flame_height': random.uniform(15, 25),
                'flicker_offset': random.uniform(0, math.pi * 2),
                'intensity': random.uniform(0.8, 1.0)
            })
        return torches

    def _init_spectators(self):
        """관중 실루엣 초기화"""
        spectators = []
        # 상단 관중석
        for i in range(20):
            spectators.append({
                'x': 30 + i * 28,
                'y': 20 + random.randint(-5, 5),
                'size': random.randint(12, 18),
                'wave_offset': random.uniform(0, math.pi * 2),
                'cheer_prob': random.uniform(0.01, 0.03)
            })
        return spectators

    def _create_dust_particle(self):
        """먼지 파티클 생성"""
        return {
            'x': random.randint(50, self.width - 50),
            'y': random.randint(100, self.height - 100),
            'vx': random.uniform(-0.3, 0.3),
            'vy': random.uniform(-0.2, 0.1),
            'size': random.uniform(1, 3),
            'alpha': random.randint(30, 80),
            'life': random.randint(100, 300)
        }

    def _prerender_floor(self):
        """바닥 프리렌더 - 모래 바닥"""
        self.floor_surface.fill((0, 0, 0, 0))

        # 모래 바닥 기본색
        sand_color = (194, 158, 108)
        darker_sand = (164, 128, 88)

        # 바닥 영역 (중앙 경기장)
        floor_rect = pygame.Rect(40, 80, self.width - 80, self.height - 160)
        pygame.draw.rect(self.floor_surface, sand_color, floor_rect)

        # 모래 텍스처 노이즈
        for _ in range(500):
            x = random.randint(floor_rect.x, floor_rect.right - 1)
            y = random.randint(floor_rect.y, floor_rect.bottom - 1)
            shade = random.randint(-20, 20)
            color = (
                max(0, min(255, sand_color[0] + shade)),
                max(0, min(255, sand_color[1] + shade)),
                max(0, min(255, sand_color[2] + shade))
            )
            size = random.randint(1, 3)
            pygame.draw.circle(self.floor_surface, color, (x, y), size)

        # 경기장 라인 (원형)
        center_x, center_y = self.width // 2, self.height // 2
        pygame.draw.circle(self.floor_surface, darker_sand, (center_x, center_y), 150, 3)
        pygame.draw.circle(self.floor_surface, darker_sand, (center_x, center_y), 80, 2)

        # 중앙선
        pygame.draw.line(self.floor_surface, darker_sand,
                        (floor_rect.x + 20, center_y), (floor_rect.right - 20, center_y), 2)

    def _prerender_walls(self):
        """벽 프리렌더 - 석조 벽과 아치"""
        self.wall_surface.fill((0, 0, 0, 0))

        # 벽 색상
        stone_color = (120, 110, 100)
        dark_stone = (80, 75, 70)
        highlight = (150, 140, 130)

        # 상단 관중석 영역
        top_area = pygame.Rect(0, 0, self.width, 80)
        pygame.draw.rect(self.wall_surface, dark_stone, top_area)

        # 아치 그리기 (상단)
        arch_width = 60
        for i in range(10):
            arch_x = i * arch_width
            # 아치 기둥
            pygame.draw.rect(self.wall_surface, stone_color,
                           (arch_x, 40, 10, 40))
            pygame.draw.rect(self.wall_surface, stone_color,
                           (arch_x + arch_width - 10, 40, 10, 40))
            # 아치 상단
            pygame.draw.arc(self.wall_surface, stone_color,
                          (arch_x + 5, 30, arch_width - 10, 30), 0, math.pi, 3)

        # 하단 관중석/벽 영역
        bottom_area = pygame.Rect(0, self.height - 80, self.width, 80)
        pygame.draw.rect(self.wall_surface, dark_stone, bottom_area)

        # 아치 (하단)
        for i in range(10):
            arch_x = i * arch_width
            pygame.draw.rect(self.wall_surface, stone_color,
                           (arch_x, self.height - 80, 10, 40))
            pygame.draw.rect(self.wall_surface, stone_color,
                           (arch_x + arch_width - 10, self.height - 80, 10, 40))
            pygame.draw.arc(self.wall_surface, stone_color,
                          (arch_x + 5, self.height - 60, arch_width - 10, 30),
                          math.pi, math.pi * 2, 3)

        # 좌우 벽
        left_wall = pygame.Rect(0, 80, 40, self.height - 160)
        right_wall = pygame.Rect(self.width - 40, 80, 40, self.height - 160)
        pygame.draw.rect(self.wall_surface, stone_color, left_wall)
        pygame.draw.rect(self.wall_surface, stone_color, right_wall)

        # 벽돌 패턴
        brick_h = 25
        for i in range((self.height - 160) // brick_h):
            y = 80 + i * brick_h
            offset = (i % 2) * 20
            # 왼쪽 벽
            pygame.draw.line(self.wall_surface, dark_stone, (0, y), (40, y), 1)
            pygame.draw.line(self.wall_surface, dark_stone, (offset, y), (offset, y + brick_h), 1)
            # 오른쪽 벽
            pygame.draw.line(self.wall_surface, dark_stone,
                           (self.width - 40, y), (self.width, y), 1)
            pygame.draw.line(self.wall_surface, dark_stone,
                           (self.width - 40 + offset, y), (self.width - 40 + offset, y + brick_h), 1)

    def update(self, dt, ball_x=None, ball_y=None):
        """업데이트"""
        self.time += dt

        # 관중 웨이브 타이머
        self.crowd_wave_timer += dt * 2

        # 횃불 업데이트
        for torch in self.torches:
            torch['intensity'] = 0.7 + 0.3 * math.sin(self.time * 8 + torch['flicker_offset'])
            torch['flame_height'] = 18 + 7 * math.sin(self.time * 6 + torch['flicker_offset'])

        # 먼지 파티클 업데이트
        for particle in self.dust_particles:
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            particle['life'] -= 1

            # 범위 벗어나거나 수명 끝나면 재생성
            if (particle['life'] <= 0 or
                particle['x'] < 40 or particle['x'] > self.width - 40 or
                particle['y'] < 80 or particle['y'] > self.height - 80):
                idx = self.dust_particles.index(particle)
                self.dust_particles[idx] = self._create_dust_particle()

    def set_crowd_excitement(self, level):
        """관중 흥분도 설정 (0.0 ~ 1.0)"""
        self.crowd_noise_level = max(0.0, min(1.0, level))

    def draw(self, screen, scale_x=1.0, scale_y=1.0, offset_x=0, offset_y=0):
        """배경 그리기"""
        # 바닥
        if scale_x != 1.0 or scale_y != 1.0:
            scaled_floor = pygame.transform.scale(
                self.floor_surface,
                (int(self.width * scale_x), int(self.height * scale_y))
            )
            screen.blit(scaled_floor, (offset_x, offset_y))
        else:
            screen.blit(self.floor_surface, (offset_x, offset_y))

        # 먼지 파티클
        for particle in self.dust_particles:
            px = int(particle['x'] * scale_x + offset_x)
            py = int(particle['y'] * scale_y + offset_y)
            size = max(1, int(particle['size'] * scale_x))
            color = (180, 160, 130, particle['alpha'])
            pygame.draw.circle(screen, color[:3], (px, py), size)

        # 벽
        if scale_x != 1.0 or scale_y != 1.0:
            scaled_wall = pygame.transform.scale(
                self.wall_surface,
                (int(self.width * scale_x), int(self.height * scale_y))
            )
            screen.blit(scaled_wall, (offset_x, offset_y))
        else:
            screen.blit(self.wall_surface, (offset_x, offset_y))

        # 횃불
        self._draw_torches(screen, scale_x, scale_y, offset_x, offset_y)

        # 관중
        self._draw_spectators(screen, scale_x, scale_y, offset_x, offset_y)

    def _draw_torches(self, screen, scale_x, scale_y, offset_x, offset_y):
        """횃불 그리기"""
        for torch in self.torches:
            tx = int(torch['x'] * scale_x + offset_x)
            ty = int(torch['y'] * scale_y + offset_y)

            # 횃불 받침대
            holder_color = (60, 50, 40)
            pygame.draw.rect(screen, holder_color,
                           (tx - 4, ty, 8, 20))

            # 불꽃
            flame_h = int(torch['flame_height'] * scale_y)
            intensity = torch['intensity']

            # 외부 불꽃 (주황)
            outer_color = (255, int(120 * intensity), 0)
            points = [
                (tx, ty),
                (tx - 8, ty - flame_h // 2),
                (tx, ty - flame_h),
                (tx + 8, ty - flame_h // 2)
            ]
            pygame.draw.polygon(screen, outer_color, points)

            # 내부 불꽃 (노랑)
            inner_color = (255, int(220 * intensity), int(100 * intensity))
            inner_h = flame_h * 0.6
            inner_points = [
                (tx, ty - 3),
                (tx - 4, ty - flame_h // 3),
                (tx, ty - int(inner_h)),
                (tx + 4, ty - flame_h // 3)
            ]
            pygame.draw.polygon(screen, inner_color, inner_points)

            # 글로우 효과
            glow_radius = int(30 * intensity * scale_x)
            glow_surf = pygame.Surface((glow_radius * 2, glow_radius * 2), pygame.SRCALPHA)
            for r in range(glow_radius, 0, -2):
                alpha = int(30 * (r / glow_radius) * intensity)
                pygame.draw.circle(glow_surf, (255, 150, 50, alpha),
                                 (glow_radius, glow_radius), r)
            screen.blit(glow_surf, (tx - glow_radius, ty - flame_h - glow_radius),
                       special_flags=pygame.BLEND_ADD)

    def _draw_spectators(self, screen, scale_x, scale_y, offset_x, offset_y):
        """관중 실루엣 그리기"""
        for spec in self.spectators:
            sx = int(spec['x'] * scale_x + offset_x)
            sy = int(spec['y'] * scale_y + offset_y)
            size = int(spec['size'] * scale_y)

            # 웨이브 애니메이션
            wave_offset = math.sin(self.crowd_wave_timer + spec['wave_offset']) * 3 * self.crowd_noise_level
            sy += int(wave_offset)

            # 실루엣 색상 (어두운 색)
            color = (40, 35, 30)

            # 머리
            pygame.draw.circle(screen, color, (sx, sy), size // 2)
            # 몸통
            pygame.draw.rect(screen, color, (sx - size // 3, sy + size // 2,
                                            size * 2 // 3, size))

    def draw_foreground(self, screen, scale_x=1.0, scale_y=1.0, offset_x=0, offset_y=0):
        """전경 효과 (패들/공 위에 그려짐)"""
        # 상단/하단 그림자 효과
        shadow_h = int(30 * scale_y)

        # 상단 그림자
        for i in range(shadow_h):
            alpha = int(100 * (1 - i / shadow_h))
            pygame.draw.line(screen, (0, 0, 0, alpha),
                           (offset_x, offset_y + int(80 * scale_y) + i),
                           (offset_x + int(self.width * scale_x), offset_y + int(80 * scale_y) + i))

        # 하단 그림자
        bottom_y = offset_y + int((self.height - 80) * scale_y)
        for i in range(shadow_h):
            alpha = int(100 * (i / shadow_h))
            pygame.draw.line(screen, (0, 0, 0, alpha),
                           (offset_x, bottom_y - shadow_h + i),
                           (offset_x + int(self.width * scale_x), bottom_y - shadow_h + i))
