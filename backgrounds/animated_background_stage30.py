# -*- coding: utf-8 -*-
"""
Stage 30 - 고대 투기장 (Ancient Colosseum Arena)
로마 콜로세움 스타일의 투기장 배경 - 심플하고 멋스러운 디자인
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
        self.arena_surface = pygame.Surface((width, height), pygame.SRCALPHA)
        self.effect_surface = pygame.Surface((width, height), pygame.SRCALPHA)

        # 관중 함성 효과
        self.crowd_noise_level = 0.5
        self.crowd_wave_timer = 0

        # 색상 팔레트 - 로마 콜로세움 테마 (어두운 톤)
        self.colors = {
            'sand': (155, 130, 95),           # 모래 바닥 (어둡게)
            'sand_dark': (125, 105, 75),      # 어두운 모래
            'sand_light': (175, 150, 115),    # 밝은 모래
            'stone': (140, 130, 115),         # 석조
            'stone_dark': (100, 90, 80),      # 어두운 석조
            'stone_light': (170, 160, 145),   # 밝은 석조
            'gold': (212, 175, 85),           # 금색 장식
            'gold_light': (232, 200, 120),    # 밝은 금색
            'line': (230, 210, 170),          # 라인 색상 (밝은 베이지)
            'line_glow': (255, 235, 190),     # 라인 글로우
        }

        # 횃불 데이터
        self.torches = self._init_torches()

        # 먼지 파티클
        self.dust_particles = []
        for _ in range(20):
            self.dust_particles.append(self._create_dust_particle())

        # 관중 실루엣 데이터
        self.spectators = self._init_spectators()

        # 프리렌더
        self._prerender_floor()
        self._prerender_arena()

    def _init_torches(self):
        """횃불 위치 초기화 - 양쪽 가장자리에 대칭 배치"""
        torches = []
        # 좌우 벽에 횃불 배치 (X: 30 / 570 정확히 대칭, Y: 중앙 375 기준 ±225)
        positions = [
            (30, 150), (30, 375), (30, 600),   # 왼쪽
            (570, 150), (570, 375), (570, 600),  # 오른쪽
        ]
        for x, y in positions:
            torches.append({
                'x': x, 'y': y,
                'flame_height': random.uniform(18, 28),
                'flicker_offset': random.uniform(0, math.pi * 2),
                'intensity': random.uniform(0.8, 1.0)
            })
        return torches

    def _init_spectators(self):
        """관중 실루엣 초기화 - 비활성화"""
        return []  # 관중 실루엣 제거

    def _create_dust_particle(self):
        """먼지 파티클 생성"""
        return {
            'x': random.randint(60, self.width - 60),
            'y': random.randint(100, self.height - 100),
            'vx': random.uniform(-0.2, 0.2),
            'vy': random.uniform(-0.1, 0.1),
            'size': random.uniform(1, 2.5),
            'alpha': random.randint(20, 50),
            'life': random.randint(150, 400)
        }

    def _prerender_floor(self):
        """바닥 프리렌더 - 모래 아레나"""
        self.floor_surface.fill((0, 0, 0, 0))

        # 메인 모래 바닥
        sand = self.colors['sand']

        # 경기장 영역 (테두리 안쪽)
        arena_rect = pygame.Rect(45, 60, self.width - 90, self.height - 120)
        pygame.draw.rect(self.floor_surface, sand, arena_rect)

        # 모래 텍스처 - 미세한 노이즈
        for _ in range(400):
            x = random.randint(arena_rect.x + 5, arena_rect.right - 5)
            y = random.randint(arena_rect.y + 5, arena_rect.bottom - 5)
            shade = random.randint(-15, 15)
            color = (
                max(0, min(255, sand[0] + shade)),
                max(0, min(255, sand[1] + shade)),
                max(0, min(255, sand[2] + shade))
            )
            size = random.randint(1, 2)
            pygame.draw.circle(self.floor_surface, color, (x, y), size)

        # 경기장 외곽 테두리 (석조 느낌)
        stone = self.colors['stone']
        stone_dark = self.colors['stone_dark']

        # 상단 석조 프레임
        pygame.draw.rect(self.floor_surface, stone, (0, 0, self.width, 60))
        pygame.draw.rect(self.floor_surface, stone_dark, (0, 55, self.width, 5))

        # 하단 석조 프레임
        pygame.draw.rect(self.floor_surface, stone, (0, self.height - 60, self.width, 60))
        pygame.draw.rect(self.floor_surface, stone_dark, (0, self.height - 60, self.width, 5))

        # 좌우 석조 프레임
        pygame.draw.rect(self.floor_surface, stone, (0, 60, 45, self.height - 120))
        pygame.draw.rect(self.floor_surface, stone, (self.width - 45, 60, 45, self.height - 120))

        # 내부 테두리 라인
        pygame.draw.rect(self.floor_surface, stone_dark, (40, 55, self.width - 80, 3))
        pygame.draw.rect(self.floor_surface, stone_dark, (40, self.height - 58, self.width - 80, 3))
        pygame.draw.rect(self.floor_surface, stone_dark, (40, 55, 3, self.height - 110))
        pygame.draw.rect(self.floor_surface, stone_dark, (self.width - 43, 55, 3, self.height - 110))

    def _prerender_arena(self):
        """경기장 라인 프리렌더 - 중앙선과 중앙원"""
        self.arena_surface.fill((0, 0, 0, 0))

        center_x = self.width // 2
        center_y = self.height // 2

        line_color = self.colors['line']
        gold = self.colors['gold']

        # ===== 중앙선 =====
        # 메인 중앙선 (굵은 선)
        pygame.draw.line(self.arena_surface, line_color,
                        (50, center_y), (self.width - 50, center_y), 3)

        # 중앙선 장식 (얇은 이중선)
        pygame.draw.line(self.arena_surface, gold,
                        (50, center_y - 6), (self.width - 50, center_y - 6), 1)
        pygame.draw.line(self.arena_surface, gold,
                        (50, center_y + 6), (self.width - 50, center_y + 6), 1)

        # ===== 중앙원 =====
        # 큰 원 (외곽)
        pygame.draw.circle(self.arena_surface, line_color, (center_x, center_y), 85, 3)

        # 작은 원 (내부)
        pygame.draw.circle(self.arena_surface, gold, (center_x, center_y), 50, 2)

        # 중앙 장식 원
        pygame.draw.circle(self.arena_surface, line_color, (center_x, center_y), 8, 2)

        # ===== 코너 장식 (로마 스타일) =====
        corner_size = 25
        corners = [
            (55, 70),                              # 좌상
            (self.width - 55, 70),                 # 우상
            (55, self.height - 70),                # 좌하
            (self.width - 55, self.height - 70)    # 우하
        ]

        for cx, cy in corners:
            # L자 장식
            pygame.draw.line(self.arena_surface, gold,
                           (cx - corner_size, cy), (cx, cy), 2)
            pygame.draw.line(self.arena_surface, gold,
                           (cx, cy - corner_size), (cx, cy), 2)

        # 코너 반전 (우상, 우하)
        # 우상
        pygame.draw.line(self.arena_surface, gold,
                        (self.width - 55, 70), (self.width - 55 + corner_size, 70), 2)
        # 우하
        pygame.draw.line(self.arena_surface, gold,
                        (self.width - 55, self.height - 70),
                        (self.width - 55 + corner_size, self.height - 70), 2)

    def update(self, dt, ball_x=None, ball_y=None):
        """업데이트"""
        self.time += dt

        # 관중 웨이브 타이머
        self.crowd_wave_timer += dt * 2

        # 횃불 업데이트
        for torch in self.torches:
            torch['intensity'] = 0.7 + 0.3 * math.sin(self.time * 8 + torch['flicker_offset'])
            torch['flame_height'] = 20 + 8 * math.sin(self.time * 6 + torch['flicker_offset'])

        # 먼지 파티클 업데이트
        for i, particle in enumerate(self.dust_particles):
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            particle['life'] -= 1

            # 범위 벗어나거나 수명 끝나면 재생성
            if (particle['life'] <= 0 or
                particle['x'] < 50 or particle['x'] > self.width - 50 or
                particle['y'] < 70 or particle['y'] > self.height - 70):
                self.dust_particles[i] = self._create_dust_particle()

    def set_crowd_excitement(self, level):
        """관중 흥분도 설정 (0.0 ~ 1.0)"""
        self.crowd_noise_level = max(0.0, min(1.0, level))

    def draw(self, screen, scale_x=1.0, scale_y=1.0, offset_x=0, offset_y=0):
        """배경 그리기"""
        # 바닥 (모래 + 석조 프레임)
        if scale_x != 1.0 or scale_y != 1.0:
            scaled_floor = pygame.transform.scale(
                self.floor_surface,
                (int(self.width * scale_x), int(self.height * scale_y))
            )
            screen.blit(scaled_floor, (offset_x, offset_y))
        else:
            screen.blit(self.floor_surface, (offset_x, offset_y))

        # 먼지 파티클 (바닥 위, 라인 아래)
        for particle in self.dust_particles:
            px = int(particle['x'] * scale_x + offset_x)
            py = int(particle['y'] * scale_y + offset_y)
            size = max(1, int(particle['size'] * scale_x))
            alpha = int(particle['alpha'] * (particle['life'] / 400))
            color = (200, 175, 140)
            pygame.draw.circle(screen, color, (px, py), size)

        # 경기장 라인 (중앙선, 중앙원)
        if scale_x != 1.0 or scale_y != 1.0:
            scaled_arena = pygame.transform.scale(
                self.arena_surface,
                (int(self.width * scale_x), int(self.height * scale_y))
            )
            screen.blit(scaled_arena, (offset_x, offset_y))
        else:
            screen.blit(self.arena_surface, (offset_x, offset_y))

        # 횃불
        self._draw_torches(screen, scale_x, scale_y, offset_x, offset_y)

    def _draw_torches(self, screen, scale_x, scale_y, offset_x, offset_y):
        """횃불 그리기"""
        for torch in self.torches:
            tx = int(torch['x'] * scale_x + offset_x)
            ty = int(torch['y'] * scale_y + offset_y)

            # 횃불 받침대
            holder_color = (70, 55, 40)
            pygame.draw.rect(screen, holder_color,
                           (tx - 3, ty, 6, 18))
            # 받침대 상단 장식
            pygame.draw.rect(screen, (90, 75, 55),
                           (tx - 5, ty - 3, 10, 5))

            # 불꽃
            flame_h = int(torch['flame_height'] * scale_y)
            intensity = torch['intensity']

            # 외부 불꽃 (주황)
            outer_color = (255, int(140 * intensity), 20)
            points = [
                (tx, ty - 2),
                (tx - 7, ty - flame_h // 2),
                (tx - 2, ty - flame_h * 0.7),
                (tx, ty - flame_h),
                (tx + 2, ty - flame_h * 0.7),
                (tx + 7, ty - flame_h // 2)
            ]
            pygame.draw.polygon(screen, outer_color, points)

            # 내부 불꽃 (노랑)
            inner_color = (255, int(230 * intensity), int(80 * intensity))
            inner_h = flame_h * 0.6
            inner_points = [
                (tx, ty - 4),
                (tx - 3, ty - flame_h // 3),
                (tx, ty - int(inner_h)),
                (tx + 3, ty - flame_h // 3)
            ]
            pygame.draw.polygon(screen, inner_color, inner_points)

            # 글로우 효과
            glow_radius = int(25 * intensity * scale_x)
            glow_surf = pygame.Surface((glow_radius * 2, glow_radius * 2), pygame.SRCALPHA)
            for r in range(glow_radius, 0, -3):
                alpha = int(25 * (r / glow_radius) * intensity)
                pygame.draw.circle(glow_surf, (255, 160, 60, alpha),
                                 (glow_radius, glow_radius), r)
            screen.blit(glow_surf, (tx - glow_radius, ty - flame_h // 2 - glow_radius),
                       special_flags=pygame.BLEND_ADD)

    def _draw_spectators(self, screen, scale_x, scale_y, offset_x, offset_y):
        """관중 실루엣 그리기"""
        for spec in self.spectators:
            sx = int(spec['x'] * scale_x + offset_x)
            sy = int(spec['y'] * scale_y + offset_y)
            size = int(spec['size'] * scale_y)

            # 웨이브 애니메이션
            wave_offset = math.sin(self.crowd_wave_timer + spec['wave_offset']) * 2 * self.crowd_noise_level
            sy += int(wave_offset)

            # 실루엣 색상 (어두운 석조색 계열)
            color = (50, 45, 40)

            # 머리
            pygame.draw.circle(screen, color, (sx, sy), size // 2)
            # 몸통
            pygame.draw.ellipse(screen, color, (sx - size // 3, sy + size // 3,
                                            size * 2 // 3, size))

    def draw_foreground(self, screen, scale_x=1.0, scale_y=1.0, offset_x=0, offset_y=0):
        """전경 효과 (패들/공 위에 그려짐) - 비네트 효과"""
        # 미세한 비네트 효과 (모서리 어둡게)
        vignette_size = 60

        # 상단 그라데이션
        for i in range(vignette_size):
            alpha = int(40 * (1 - i / vignette_size))
            if alpha > 0:
                pygame.draw.line(screen, (20, 15, 10),
                               (offset_x, offset_y + int(60 * scale_y) + i),
                               (offset_x + int(self.width * scale_x), offset_y + int(60 * scale_y) + i))

        # 하단 그라데이션
        bottom_start = offset_y + int((self.height - 60) * scale_y) - vignette_size
        for i in range(vignette_size):
            alpha = int(40 * (i / vignette_size))
            if alpha > 0:
                pygame.draw.line(screen, (20, 15, 10),
                               (offset_x, bottom_start + i),
                               (offset_x + int(self.width * scale_x), bottom_start + i))
