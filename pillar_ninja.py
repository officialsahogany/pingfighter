# -*- coding: utf-8 -*-
"""
스테이지 8 닌자 저택 필러 배경
- 일본 전통 저택 느낌의 나무 프레임 및 장지문(쇼지) 패턴
- 고품질 대나무 숲 (다층 깊이감) - 캐시 최적화
- 등불 효과
- 떨어지는 벚꽃잎
- 초승달 (좌측 상단)
- 하단 안개 효과
"""

import math
import random
import pygame
from typing import List, Tuple, Optional, Dict


class NinjaPillarBackground:
    """닌자 저택 스타일 필러 배경 - 최적화 버전"""

    def __init__(self, screen_width: int, screen_height: int,
                 game_width: int, game_height: int):
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.game_width = game_width
        self.game_height = game_height

        # 게임 영역 위치 (중앙)
        self.game_x = (screen_width - game_width) // 2
        self.game_y = (screen_height - game_height) // 2

        # 애니메이션 시간
        self.time = 0.0

        # 색상 팔레트
        self.colors = {
            # 테두리 액자 색상 (녹슨 황동빛)
            'wood_deep': (45, 35, 18),
            'wood_dark': (85, 65, 32),
            'wood_mid': (120, 95, 48),
            'wood_light': (155, 125, 65),
            'wood_highlight': (185, 155, 85),

            # 배경 색상
            'bg_deep': (12, 10, 8),
            'bg_dark': (22, 18, 14),
            'bg_mid': (35, 28, 22),

            # 등불/빛 색상
            'lantern_glow': (180, 120, 60),
            'lantern_core': (255, 200, 100),

            # 벚꽃 색상
            'sakura_light': (255, 200, 210),
            'sakura_mid': (230, 150, 170),
            'sakura_dark': (180, 100, 130),

            # 대나무 색상
            'bamboo_far': (20, 30, 18),
            'bamboo_mid_back': (35, 52, 30),
            'bamboo_mid': (45, 65, 38),
            'bamboo_front': (65, 92, 52),
            'bamboo_highlight': (85, 115, 68),
            'bamboo_node_light': (75, 100, 60),
            'bamboo_leaf_mid': (40, 60, 35),
            'bamboo_leaf_light': (55, 80, 48),

            # 달 색상
            'moon_bright': (255, 252, 240),
            'moon_mid': (230, 225, 200),
            'moon_dark': (180, 175, 155),
            'moon_glow': (200, 195, 170),

            # 안개 색상
            'mist': (60, 55, 45),

            # 족자/액자 색상
            'scroll_bg': (35, 30, 25),         # 족자 배경
            'scroll_paper': (220, 210, 185),   # 족자 종이
            'scroll_paper_dark': (180, 170, 145),
            'scroll_border': (60, 45, 25),     # 족자 테두리
            'scroll_gold': (180, 150, 80),     # 금색 장식
            'scroll_red': (140, 45, 35),       # 빨간 인장
            'ink_black': (20, 18, 15),         # 먹색
            'ink_gray': (60, 55, 50),          # 연한 먹색
        }

        # === 동적 요소들 ===
        # 벚꽃잎
        self.sakura_petals: List[Dict] = []
        self._init_sakura_petals()

        # 등불
        self.lanterns: List[Dict] = []
        self._init_lanterns()

        # 떨어지는 대나무 잎
        self.falling_bamboo_leaves: List[Dict] = []
        self._init_falling_leaves()

        # === 캐시 서피스 ===
        self._frame_surface: Optional[pygame.Surface] = None
        self._bg_cache: Optional[pygame.Surface] = None
        self._bamboo_cache_left: Optional[pygame.Surface] = None
        self._bamboo_cache_right: Optional[pygame.Surface] = None
        self._shoji_cache: Optional[pygame.Surface] = None
        self._moon_cache: Optional[pygame.Surface] = None  # 달 캐시
        self._mist_cache: Optional[pygame.Surface] = None  # 안개 캐시

        # 캐시 생성
        self._create_all_caches()

    def _init_sakura_petals(self):
        """벚꽃잎 초기화"""
        self.sakura_petals = []
        for _ in range(12):
            side = random.choice(['left', 'right'])
            if side == 'left' and self.game_x > 20:
                x = random.uniform(5, self.game_x - 5)
            elif side == 'right' and self.screen_width - self.game_x - self.game_width > 20:
                x = random.uniform(self.game_x + self.game_width + 5, self.screen_width - 5)
            else:
                continue

            self.sakura_petals.append({
                'x': x, 'y': random.uniform(-50, self.screen_height),
                'speed_y': random.uniform(15, 35),
                'sway_phase': random.uniform(0, math.pi * 2),
                'sway_speed': random.uniform(1.2, 2.5),
                'sway_amount': random.uniform(20, 45),
                'size': random.randint(4, 7),
                'alpha': random.randint(120, 200),
                'side': side,
                'color_type': random.choice(['light', 'mid', 'dark'])
            })

    def _init_lanterns(self):
        """등불 초기화"""
        self.lanterns = []
        # 좌측 등불
        if self.game_x > 50:
            self.lanterns.append({
                'x': self.game_x // 2, 'y': 80,
                'phase': random.uniform(0, math.pi * 2),
                'intensity': 1.0,
                'flicker_speed': random.uniform(3.0, 5.0),
            })
            self.lanterns.append({
                'x': self.game_x // 2, 'y': self.screen_height - 80,
                'phase': random.uniform(0, math.pi * 2),
                'intensity': 1.0,
                'flicker_speed': random.uniform(3.0, 5.0),
            })

        # 우측 등불
        right_start = self.game_x + self.game_width
        right_width = self.screen_width - right_start
        if right_width > 50:
            self.lanterns.append({
                'x': right_start + right_width // 2, 'y': 80,
                'phase': random.uniform(0, math.pi * 2),
                'intensity': 1.0,
                'flicker_speed': random.uniform(3.0, 5.0),
            })
            self.lanterns.append({
                'x': right_start + right_width // 2, 'y': self.screen_height - 80,
                'phase': random.uniform(0, math.pi * 2),
                'intensity': 1.0,
                'flicker_speed': random.uniform(3.0, 5.0),
            })

    def _init_falling_leaves(self):
        """떨어지는 대나무 잎 초기화"""
        self.falling_bamboo_leaves = []
        for _ in range(6):
            side = random.choice(['left', 'right'])
            if side == 'left' and self.game_x > 20:
                x = random.uniform(5, self.game_x - 5)
            elif side == 'right' and self.screen_width - self.game_x - self.game_width > 20:
                x = random.uniform(self.game_x + self.game_width + 5, self.screen_width - 5)
            else:
                continue

            self.falling_bamboo_leaves.append({
                'x': x, 'y': random.uniform(-30, self.screen_height),
                'speed_y': random.uniform(25, 50),
                'sway_phase': random.uniform(0, math.pi * 2),
                'sway_speed': random.uniform(2, 4),
                'sway_amount': random.uniform(30, 60),
                'rotation': random.uniform(0, math.pi * 2),
                'rot_speed': random.uniform(1, 3),
                'length': random.randint(12, 22),
                'alpha': random.randint(100, 180),
                'side': side,
            })

    def _create_all_caches(self):
        """모든 캐시 생성"""
        self._create_frame()
        self._create_bg_cache()
        self._create_shoji_cache()
        self._create_bamboo_caches()
        self._create_moon_cache()
        self._create_mist_cache()

    def _create_frame(self):
        """프레임 캐시 생성"""
        self._frame_surface = pygame.Surface(
            (self.screen_width, self.screen_height), pygame.SRCALPHA
        )
        self._draw_wood_frame(self._frame_surface)
        self._draw_inner_frame(self._frame_surface)
        self._draw_corner_marks(self._frame_surface)

    def _draw_wood_frame(self, surface: pygame.Surface):
        """나무 프레임"""
        border_width = 10
        for i in range(border_width):
            t = i / border_width
            if t < 0.3:
                color = self.colors['wood_deep']
            elif t < 0.6:
                color = self.colors['wood_dark']
            else:
                color = self.colors['wood_mid']
            rect = pygame.Rect(i, i, self.screen_width - i * 2, self.screen_height - i * 2)
            pygame.draw.rect(surface, color, rect, 1)

    def _draw_inner_frame(self, surface: pygame.Surface):
        """내곽 프레임"""
        margin, border_width = 5, 8
        inner_rect = pygame.Rect(
            self.game_x - margin - border_width,
            self.game_y - margin - border_width,
            self.game_width + (margin + border_width) * 2,
            self.game_height + (margin + border_width) * 2
        )
        for i in range(border_width):
            t = i / border_width
            if t < 0.3:
                color = self.colors['wood_light']
            elif t < 0.6:
                color = self.colors['wood_mid']
            else:
                color = self.colors['wood_dark']
            rect = inner_rect.inflate(-i * 2, -i * 2)
            pygame.draw.rect(surface, color, rect, 1)

        # 격자
        for x in range(inner_rect.left + 20, inner_rect.right - 20, 25):
            pygame.draw.line(surface, self.colors['wood_highlight'],
                           (x, inner_rect.top), (x, inner_rect.top + 6), 1)
            pygame.draw.line(surface, self.colors['wood_highlight'],
                           (x, inner_rect.bottom - 6), (x, inner_rect.bottom), 1)

    def _draw_corner_marks(self, surface: pygame.Surface):
        """모서리 장식"""
        margin = 15
        corners = [
            (self.game_x - margin, self.game_y - margin),
            (self.game_x + self.game_width + margin, self.game_y - margin),
            (self.game_x - margin, self.game_y + self.game_height + margin),
            (self.game_x + self.game_width + margin, self.game_y + self.game_height + margin)
        ]
        for cx, cy in corners:
            size = 12
            pygame.draw.circle(surface, self.colors['wood_dark'], (cx, cy), size + 2)
            pygame.draw.circle(surface, self.colors['wood_mid'], (cx, cy), size)
            for i in range(3):
                angle = (i / 3) * math.pi * 2 - math.pi / 2
                px = cx + math.cos(angle) * (size - 4)
                py = cy + math.sin(angle) * (size - 4)
                pygame.draw.line(surface, self.colors['bamboo_mid'],
                               (cx, cy), (int(px), int(py)), 2)
            pygame.draw.circle(surface, self.colors['bamboo_front'], (cx, cy), 3)

    def _create_bg_cache(self):
        """배경 캐시"""
        self._bg_cache = pygame.Surface(
            (self.screen_width, self.screen_height), pygame.SRCALPHA
        )
        # 전체 화면을 배경색으로 채움 (모서리 포함)
        pygame.draw.rect(self._bg_cache, self.colors['bg_deep'],
                        (0, 0, self.screen_width, self.screen_height))

    def _create_shoji_cache(self):
        """장지문 패턴 캐시"""
        self._shoji_cache = pygame.Surface(
            (self.screen_width, self.screen_height), pygame.SRCALPHA
        )
        cell_size, alpha = 50, 25  # alpha를 12에서 25로 올림
        # 좌측
        if self.game_x > 30:
            for gx in range(10, self.game_x - 10, cell_size):
                pygame.draw.line(self._shoji_cache, (*self.colors['wood_mid'], alpha),
                               (gx, 10), (gx, self.screen_height - 10), 1)
            for gy in range(10, self.screen_height - 10, cell_size):
                pygame.draw.line(self._shoji_cache, (*self.colors['wood_mid'], alpha),
                               (10, gy), (self.game_x - 10, gy), 1)
        # 우측
        right_start = self.game_x + self.game_width
        right_width = self.screen_width - right_start
        if right_width > 30:
            for gx in range(right_start + 10, self.screen_width - 10, cell_size):
                pygame.draw.line(self._shoji_cache, (*self.colors['wood_mid'], alpha),
                               (gx, 10), (gx, self.screen_height - 10), 1)
            for gy in range(10, self.screen_height - 10, cell_size):
                pygame.draw.line(self._shoji_cache, (*self.colors['wood_mid'], alpha),
                               (right_start + 10, gy), (self.screen_width - 10, gy), 1)

    def _create_bamboo_caches(self):
        """대나무 캐시"""
        if self.game_x > 25:
            self._bamboo_cache_left = pygame.Surface(
                (self.game_x, self.screen_height), pygame.SRCALPHA
            )
            self._draw_bamboo_forest(self._bamboo_cache_left, self.game_x)

        right_start = self.game_x + self.game_width
        right_width = self.screen_width - right_start
        if right_width > 25:
            self._bamboo_cache_right = pygame.Surface(
                (right_width, self.screen_height), pygame.SRCALPHA
            )
            self._draw_bamboo_forest(self._bamboo_cache_right, right_width)

    def _draw_bamboo_forest(self, surface: pygame.Surface, width: int):
        """대나무 숲 그리기"""
        layers = [
            {'color': self.colors['bamboo_far'], 'thickness': 3, 'alpha': 60, 'count': 3},
            {'color': self.colors['bamboo_mid_back'], 'thickness': 5, 'alpha': 100, 'count': 3},
            {'color': self.colors['bamboo_mid'], 'thickness': 7, 'alpha': 150, 'count': 2},
            {'color': self.colors['bamboo_front'], 'thickness': 10, 'alpha': 200, 'count': 2},
        ]
        for layer in layers:
            for _ in range(layer['count']):
                x = random.randint(5, width - 5)
                height = random.randint(int(self.screen_height * 0.5),
                                       int(self.screen_height * 0.95))
                self._draw_simple_bamboo(surface, x, height,
                                        layer['thickness'], layer['color'], layer['alpha'])

    def _draw_simple_bamboo(self, surface: pygame.Surface, x: int, height: int,
                            thickness: int, color: tuple, alpha: int):
        """간소화된 대나무"""
        y_start = self.screen_height
        node_spacing = 45 + thickness * 2

        # 줄기
        pygame.draw.line(surface, (*color, alpha),
                        (x, y_start), (x, y_start - height), thickness)
        # 하이라이트
        pygame.draw.line(surface, (*self.colors['bamboo_highlight'], alpha // 3),
                        (x - thickness // 3, y_start),
                        (x - thickness // 3, y_start - height), 1)
        # 마디
        for seg in range(node_spacing, height, node_spacing):
            node_y = y_start - seg
            pygame.draw.ellipse(surface, (*self.colors['bamboo_node_light'], alpha),
                              (x - thickness // 2 - 2, node_y - 3, thickness + 4, 6))
        # 잎
        num_clusters = max(1, height // 150)
        for c in range(num_clusters):
            cluster_y = y_start - height * (0.2 + c * 0.25)
            direction = random.choice([-1, 1])
            for i in range(3):
                angle = direction * (0.3 + i * 0.2)
                leaf_len = 12 + thickness - i * 2
                end_x = x + math.cos(angle) * leaf_len * direction
                end_y = cluster_y + math.sin(angle) * leaf_len - i * 5
                pygame.draw.line(surface, (*self.colors['bamboo_leaf_mid'], alpha),
                               (x, cluster_y - i * 5), (int(end_x), int(end_y)), 2)

    def _create_moon_cache(self):
        """달 캐시 생성 - 좌측 상단에만 배치"""
        self._moon_cache = pygame.Surface(
            (self.screen_width, self.screen_height), pygame.SRCALPHA
        )

        # 좌측 필러 상단에만 초승달 배치
        if self.game_x > 60:
            moon_x = self.game_x // 2
            moon_y = 50
            moon_radius = min(25, self.game_x // 4)

            # 달빛 글로우 (여러 레이어)
            for i in range(4):
                glow_radius = moon_radius + 10 + i * 8
                glow_alpha = 15 - i * 3
                if glow_alpha > 0:
                    pygame.draw.circle(self._moon_cache,
                                     (*self.colors['moon_glow'], glow_alpha),
                                     (moon_x, moon_y), glow_radius)

            # 달 본체
            pygame.draw.circle(self._moon_cache, self.colors['moon_bright'],
                             (moon_x, moon_y), moon_radius)
            # 달 그림자 (초승달 효과)
            shadow_offset = moon_radius // 3
            pygame.draw.circle(self._moon_cache, self.colors['bg_deep'],
                             (moon_x + shadow_offset, moon_y - shadow_offset // 2),
                             moon_radius - 3)

    def _create_mist_cache(self):
        """안개 캐시 생성"""
        self._mist_cache = pygame.Surface(
            (self.screen_width, self.screen_height), pygame.SRCALPHA
        )

        mist_height = int(self.screen_height * 0.25)
        mist_y_start = self.screen_height - mist_height

        # 좌측 안개
        if self.game_x > 20:
            for y in range(mist_height):
                # 아래로 갈수록 진해지는 그라데이션
                progress = y / mist_height
                alpha = int(25 * progress * progress)  # 제곱으로 더 자연스럽게
                if alpha > 0:
                    pygame.draw.line(self._mist_cache,
                                   (*self.colors['mist'], alpha),
                                   (0, mist_y_start + y),
                                   (self.game_x, mist_y_start + y), 1)

        # 우측 안개
        right_start = self.game_x + self.game_width
        right_width = self.screen_width - right_start
        if right_width > 20:
            for y in range(mist_height):
                progress = y / mist_height
                alpha = int(25 * progress * progress)
                if alpha > 0:
                    pygame.draw.line(self._mist_cache,
                                   (*self.colors['mist'], alpha),
                                   (right_start, mist_y_start + y),
                                   (self.screen_width, mist_y_start + y), 1)

    def update(self, dt: float):
        """애니메이션 업데이트"""
        self.time += dt

        # 벚꽃잎
        for petal in self.sakura_petals:
            petal['y'] += petal['speed_y'] * dt
            petal['x'] += math.sin(self.time * petal['sway_speed'] + petal['sway_phase']) * \
                         petal['sway_amount'] * dt
            if petal['y'] > self.screen_height + 30:
                petal['y'] = -30
                if petal['side'] == 'left' and self.game_x > 20:
                    petal['x'] = random.uniform(5, self.game_x - 5)
                else:
                    petal['x'] = random.uniform(self.game_x + self.game_width + 5,
                                               self.screen_width - 5)

        # 떨어지는 잎
        for leaf in self.falling_bamboo_leaves:
            leaf['y'] += leaf['speed_y'] * dt
            leaf['x'] += math.sin(self.time * leaf['sway_speed'] + leaf['sway_phase']) * \
                        leaf['sway_amount'] * dt
            leaf['rotation'] += leaf['rot_speed'] * dt
            if leaf['y'] > self.screen_height + 30:
                leaf['y'] = -30
                if leaf['side'] == 'left' and self.game_x > 20:
                    leaf['x'] = random.uniform(5, self.game_x - 5)
                else:
                    leaf['x'] = random.uniform(self.game_x + self.game_width + 5,
                                              self.screen_width - 5)

        # 등불
        for lantern in self.lanterns:
            lantern['intensity'] = 0.7 + 0.3 * math.sin(
                self.time * lantern['flicker_speed'] + lantern['phase'])

    def draw(self, screen: pygame.Surface):
        """렌더링"""
        # 1. 배경
        if self._bg_cache:
            screen.blit(self._bg_cache, (0, 0))

        # 2. 달 (대나무 뒤)
        if self._moon_cache:
            screen.blit(self._moon_cache, (0, 0))

        # 3. 장지문
        if self._shoji_cache:
            screen.blit(self._shoji_cache, (0, 0))

        # 4. 대나무
        if self._bamboo_cache_left:
            screen.blit(self._bamboo_cache_left, (0, 0))
        if self._bamboo_cache_right:
            screen.blit(self._bamboo_cache_right, (self.game_x + self.game_width, 0))

        # 5. 안개 (대나무 위)
        if self._mist_cache:
            screen.blit(self._mist_cache, (0, 0))

        # 6. 떨어지는 잎
        self._draw_falling_leaves(screen)

        # 7. 벚꽃잎
        self._draw_sakura_petals(screen)

        # 8. 등불
        self._draw_lanterns(screen)

        # 9. 테두리
        self._draw_wood_borders(screen)

        # 10. 프레임
        if self._frame_surface:
            screen.blit(self._frame_surface, (0, 0))

    def _draw_falling_leaves(self, screen: pygame.Surface):
        """떨어지는 잎"""
        for leaf in self.falling_bamboo_leaves:
            x, y = int(leaf['x']), int(leaf['y'])
            length, rot, alpha = leaf['length'], leaf['rotation'], leaf['alpha']
            end_x = x + math.cos(rot) * length
            end_y = y + math.sin(rot) * length
            pygame.draw.line(screen, (*self.colors['bamboo_leaf_light'], alpha),
                           (x, y), (int(end_x), int(end_y)), 2)

    def _draw_sakura_petals(self, screen: pygame.Surface):
        """벚꽃잎"""
        for petal in self.sakura_petals:
            px, py = int(petal['x']), int(petal['y'])
            size, alpha = petal['size'], petal['alpha']
            if petal['color_type'] == 'light':
                color = self.colors['sakura_light']
            elif petal['color_type'] == 'mid':
                color = self.colors['sakura_mid']
            else:
                color = self.colors['sakura_dark']
            pygame.draw.circle(screen, (*color, alpha), (px, py), size)

    def _draw_lanterns(self, screen: pygame.Surface):
        """등불"""
        for lantern in self.lanterns:
            lx, ly = lantern['x'], lantern['y']
            intensity = lantern['intensity']

            # 글로우
            for layer in range(2):
                radius = 25 + layer * 15
                glow_alpha = int(30 * intensity - layer * 10)
                if glow_alpha > 0:
                    glow_surf = pygame.Surface((radius * 2, radius * 2), pygame.SRCALPHA)
                    glow_color = (
                        int(self.colors['lantern_glow'][0] * intensity),
                        int(self.colors['lantern_glow'][1] * intensity),
                        int(self.colors['lantern_glow'][2] * intensity),
                        glow_alpha
                    )
                    pygame.draw.circle(glow_surf, glow_color, (radius, radius), radius)
                    screen.blit(glow_surf, (lx - radius, ly - radius))

            # 본체
            lantern_rect = pygame.Rect(lx - 10, ly - 15, 20, 30)
            pygame.draw.rect(screen, self.colors['wood_dark'], lantern_rect, 2)
            inner_color = (
                int(self.colors['lantern_core'][0] * intensity),
                int(self.colors['lantern_core'][1] * intensity),
                int(self.colors['lantern_core'][2] * intensity)
            )
            pygame.draw.rect(screen, inner_color, lantern_rect.inflate(-4, -4))

    def _draw_wood_borders(self, screen: pygame.Surface):
        """테두리"""
        if self.game_x > 3:
            pygame.draw.line(screen, self.colors['wood_dark'],
                           (self.game_x - 2, self.game_y),
                           (self.game_x - 2, self.game_y + self.game_height), 3)
        right_edge = self.game_x + self.game_width
        if self.screen_width - right_edge > 3:
            pygame.draw.line(screen, self.colors['wood_dark'],
                           (right_edge + 2, self.game_y),
                           (right_edge + 2, self.game_y + self.game_height), 3)

    def resize(self, screen_width: int, screen_height: int,
               game_width: int, game_height: int):
        """화면 크기 변경"""
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.game_width = game_width
        self.game_height = game_height
        self.game_x = (screen_width - game_width) // 2
        self.game_y = (screen_height - game_height) // 2

        self._init_sakura_petals()
        self._init_lanterns()
        self._init_falling_leaves()
        self._create_all_caches()

    def trigger_excitement(self, level: float = 1.5):
        """이벤트 반응"""
        for _ in range(int(level * 2)):
            side = random.choice(['left', 'right'])
            if side == 'left' and self.game_x > 20:
                x = random.uniform(5, self.game_x - 5)
            elif side == 'right' and self.screen_width - self.game_x - self.game_width > 20:
                x = random.uniform(self.game_x + self.game_width + 5, self.screen_width - 5)
            else:
                continue

            self.sakura_petals.append({
                'x': x, 'y': random.uniform(-30, 0),
                'speed_y': random.uniform(30, 60),
                'sway_phase': random.uniform(0, math.pi * 2),
                'sway_speed': random.uniform(2.0, 4.0),
                'sway_amount': random.uniform(20, 40),
                'size': random.randint(4, 8),
                'alpha': random.randint(150, 220),
                'side': side,
                'color_type': random.choice(['light', 'mid', 'dark'])
            })


# 전역 인스턴스
_ninja_bg: Optional[NinjaPillarBackground] = None


def init_ninja_background(screen_width: int, screen_height: int,
                          game_width: int, game_height: int) -> NinjaPillarBackground:
    global _ninja_bg
    _ninja_bg = NinjaPillarBackground(screen_width, screen_height, game_width, game_height)
    return _ninja_bg


def get_ninja_background() -> Optional[NinjaPillarBackground]:
    return _ninja_bg
