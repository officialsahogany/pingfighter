"""
스테이지 33 - 네온 아케이드 배경
패널티킥 핑퐁 모드 전용 배경
"""

import pygame
import math
import random

# ============================================================
# Surface 캐시 시스템
# ============================================================
_stage33_surface_cache = {}


def _get_cached_surface(width: int, height: int) -> pygame.Surface:
    key = (width, height)
    if key not in _stage33_surface_cache:
        if len(_stage33_surface_cache) > 50:
            _stage33_surface_cache.clear()
        _stage33_surface_cache[key] = pygame.Surface((width, height), pygame.SRCALPHA)
    surface = _stage33_surface_cache[key]
    surface.fill((0, 0, 0, 0))
    return surface


class AnimatedBackgroundStage33:
    """네온 아케이드 배경 - 패널티킥 핑퐁 전용"""

    # 네온 아케이드 컬러 팔레트
    COLOR_BG = (12, 8, 22)
    COLOR_BG_GRADIENT = (18, 12, 35)
    COLOR_NEON_CYAN = (0, 255, 255)
    COLOR_NEON_MAGENTA = (255, 0, 255)
    COLOR_NEON_PINK = (255, 50, 150)
    COLOR_NEON_BLUE = (50, 100, 255)
    COLOR_NEON_PURPLE = (150, 50, 255)
    COLOR_GRID = (30, 20, 60)
    COLOR_GRID_BRIGHT = (50, 30, 90)

    def __init__(self, width, height):
        self.width = width
        self.height = height
        self.time = 0.0

        # 배경 서피스 (캐시)
        self.bg_surface = pygame.Surface((width, height))
        self._draw_static_bg()

        # 그리드 스크롤
        self.grid_offset_y = 0.0
        self.grid_speed = 0.3

        # 네온 파티클
        self.particles = []
        for _ in range(15):
            self.particles.append(self._spawn_particle())

        # 사이드 네온 바
        self.bar_pulse = 0.0

        # 상단/하단 네온 라인 글로우
        self.glow_surface = pygame.Surface((width, height), pygame.SRCALPHA)

        # 코너 장식
        self.corner_flash = 0.0

    def _draw_static_bg(self):
        """정적 배경 (그라데이션)"""
        for y in range(self.height):
            t = y / self.height
            r = int(self.COLOR_BG[0] * (1 - t) + self.COLOR_BG_GRADIENT[0] * t)
            g = int(self.COLOR_BG[1] * (1 - t) + self.COLOR_BG_GRADIENT[1] * t)
            b = int(self.COLOR_BG[2] * (1 - t) + self.COLOR_BG_GRADIENT[2] * t)
            pygame.draw.line(self.bg_surface, (r, g, b), (0, y), (self.width, y))

    def _spawn_particle(self):
        return {
            'x': random.randint(0, self.width),
            'y': random.randint(0, self.height),
            'speed_y': random.uniform(-0.5, -0.2),
            'speed_x': random.uniform(-0.3, 0.3),
            'size': random.randint(1, 3),
            'color': random.choice([
                self.COLOR_NEON_CYAN,
                self.COLOR_NEON_MAGENTA,
                self.COLOR_NEON_PINK,
                self.COLOR_NEON_BLUE,
            ]),
            'alpha': random.randint(80, 200),
            'life': random.uniform(0, math.pi * 2),
        }

    def update(self, dt=1/60):
        """매 프레임 업데이트"""
        self.time += dt

        # 그리드 스크롤
        self.grid_offset_y = (self.grid_offset_y + self.grid_speed) % 40

        # 네온 바 펄스
        self.bar_pulse = (math.sin(self.time * 2.0) + 1) * 0.5

        # 코너 플래시
        self.corner_flash = (math.sin(self.time * 3.0) + 1) * 0.5

        # 파티클 업데이트
        for p in self.particles:
            p['y'] += p['speed_y']
            p['x'] += p['speed_x']
            p['life'] += dt
            if p['y'] < -10 or p['x'] < -10 or p['x'] > self.width + 10:
                new_p = self._spawn_particle()
                new_p['y'] = self.height + 5
                p.update(new_p)

    def draw(self, screen, offset_x=0, offset_y=0):
        """배경 그리기"""
        # 1. 정적 배경
        screen.blit(self.bg_surface, (offset_x, offset_y))

        # 2. 원근 그리드 (바닥 느낌)
        self._draw_perspective_grid(screen, offset_x, offset_y)

        # 3. 사이드 네온 바
        self._draw_side_neon_bars(screen, offset_x, offset_y)

        # 4. 상단/하단 네온 라인
        self._draw_neon_lines(screen, offset_x, offset_y)

        # 5. 네온 파티클
        self._draw_particles(screen, offset_x, offset_y)

        # 6. 코너 장식
        self._draw_corner_decorations(screen, offset_x, offset_y)

        # 7. 중앙선 네온
        self._draw_center_line(screen, offset_x, offset_y)

    def _draw_perspective_grid(self, screen, ox, oy):
        """원근감 있는 그리드"""
        grid_spacing = 40
        # 수평선 (스크롤)
        alpha = 25
        for i in range(self.height // grid_spacing + 2):
            y = int(i * grid_spacing + self.grid_offset_y) + oy
            if 0 <= y < self.height:
                # 중앙에서 멀수록 어두워짐
                dist = abs(y - self.height // 2) / (self.height // 2)
                line_alpha = int(alpha * (1 - dist * 0.5))
                color = (self.COLOR_GRID_BRIGHT[0], self.COLOR_GRID_BRIGHT[1],
                         self.COLOR_GRID_BRIGHT[2])
                pygame.draw.line(screen, color, (ox, y), (self.width + ox, y), 1)

        # 수직선 (고정)
        for i in range(self.width // grid_spacing + 1):
            x = i * grid_spacing + ox
            pygame.draw.line(screen, self.COLOR_GRID, (x, oy), (x, self.height + oy), 1)

    def _draw_side_neon_bars(self, screen, ox, oy):
        """좌우 사이드 네온 바"""
        bar_width = 4
        pulse = self.bar_pulse

        # 좌측 바 (시안)
        cyan_alpha = int(100 + 155 * pulse)
        left_color = (0, min(255, int(200 + 55 * pulse)), min(255, int(200 + 55 * pulse)))
        pygame.draw.rect(screen, left_color,
                         (ox + 76, oy + 10, bar_width, self.height - 20))

        # 우측 바 (마젠타)
        right_color = (min(255, int(200 + 55 * pulse)), 0, min(255, int(200 + 55 * pulse)))
        pygame.draw.rect(screen, right_color,
                         (ox + self.width - 80, oy + 10, bar_width, self.height - 20))

        # 글로우 (반투명)
        glow_surf = _get_cached_surface(12, self.height - 20)
        glow_surf.fill((0, 255, 255, int(20 * pulse)))
        screen.blit(glow_surf, (ox + 72, oy + 10))

        glow_surf2 = _get_cached_surface(12, self.height - 20)
        glow_surf2.fill((255, 0, 255, int(20 * pulse)))
        screen.blit(glow_surf2, (ox + self.width - 84, oy + 10))

    def _draw_neon_lines(self, screen, ox, oy):
        """상단/하단 네온 라인"""
        # 상단
        top_y = oy + 5
        pygame.draw.line(screen, self.COLOR_NEON_CYAN,
                         (ox + 80, top_y), (ox + self.width - 80, top_y), 2)

        # 하단
        bot_y = oy + self.height - 5
        pygame.draw.line(screen, self.COLOR_NEON_MAGENTA,
                         (ox + 80, bot_y), (ox + self.width - 80, bot_y), 2)

    def _draw_particles(self, screen, ox, oy):
        """네온 파티클"""
        for p in self.particles:
            flicker = (math.sin(p['life'] * 4.0) + 1) * 0.5
            alpha = int(p['alpha'] * (0.5 + 0.5 * flicker))
            if alpha < 10:
                continue
            surf = _get_cached_surface(p['size'] * 2 + 2, p['size'] * 2 + 2)
            color_with_alpha = (*p['color'], min(255, alpha))
            pygame.draw.circle(surf, color_with_alpha,
                               (p['size'] + 1, p['size'] + 1), p['size'])
            screen.blit(surf, (int(p['x'] + ox - p['size'] - 1),
                               int(p['y'] + oy - p['size'] - 1)))

    def _draw_corner_decorations(self, screen, ox, oy):
        """코너 네온 장식"""
        flash = self.corner_flash
        size = 15
        brightness = int(150 + 105 * flash)

        corners = [
            (ox + 80, oy + 5),
            (ox + self.width - 80, oy + 5),
            (ox + 80, oy + self.height - 5),
            (ox + self.width - 80, oy + self.height - 5),
        ]
        colors = [
            (0, brightness, brightness),
            (brightness, 0, brightness),
            (brightness, 0, brightness),
            (0, brightness, brightness),
        ]

        for (cx, cy), color in zip(corners, colors):
            pygame.draw.circle(screen, color, (cx, cy), 4)
            # 글로우
            glow = _get_cached_surface(size * 2, size * 2)
            glow_color = (*color, int(40 * flash))
            pygame.draw.circle(glow, glow_color, (size, size), size)
            screen.blit(glow, (cx - size, cy - size))

    def _draw_center_line(self, screen, ox, oy):
        """중앙선 네온 점선"""
        center_y = oy + self.height // 2
        dash_len = 12
        gap = 8
        x = ox + 85
        pulse = (math.sin(self.time * 1.5) + 1) * 0.5
        color_r = int(100 + 80 * pulse)
        color_b = int(200 + 55 * pulse)
        color = (color_r, 50, color_b)

        while x < ox + self.width - 85:
            end_x = min(x + dash_len, ox + self.width - 85)
            pygame.draw.line(screen, color, (x, center_y), (end_x, center_y), 1)
            x += dash_len + gap
