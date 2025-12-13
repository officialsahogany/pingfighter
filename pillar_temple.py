# -*- coding: utf-8 -*-
"""
소림사 사원 필러 배경 (스테이지 4용)
게임 화면 테두리를 고대 사원의 확장된 느낌으로 장식
- 이어지는 타일링 만다라 패턴 (음각/양각 효과)
- 연결된 기하학적 문양 (여러 열)
- 떠다니는 회전 연꽃과 별빛
- 고풍스럽고 신비로운 분위기
- 흑요석/화강암 재질의 액자 테두리
"""

import math
import random
import pygame


class TemplePillarBackground:
    """소림사 사원 스타일 필러 배경 - 이어지는 타일링 만다라 패턴 (다중 열)"""

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

        # 색상 팔레트 (고풍스러운 보라/금색)
        self.colors = {
            'bg_deep': (12, 8, 20),              # 깊은 배경
            'bg_dark': (20, 15, 35),             # 어두운 배경
            'bg_mid': (35, 28, 55),              # 중간 배경
            'shadow_dark': (8, 5, 15),           # 깊은 그림자
            'shadow_mid': (15, 10, 25),          # 중간 그림자
            'engrave_dark': (48, 36, 72),        # 음각 어두운 부분 (40% 어둡게)
            'engrave_light': (84, 72, 108),      # 음각 밝은 부분 (40% 어둡게)
            'relief_dark': (96, 84, 120),        # 양각 어두운 부분 (40% 어둡게)
            'relief_mid': (120, 108, 144),       # 양각 중간 (40% 어둡게)
            'relief_light': (138, 129, 153),     # 양각 밝은 부분 (40% 어둡게)
            'relief_highlight': (153, 147, 153), # 양각 하이라이트 (40% 어둡게)
            'gold_dark': (108, 90, 48),          # 어두운 금색 (40% 어둡게)
            'gold_mid': (138, 120, 60),          # 중간 금색 (40% 어둡게)
            'gold_light': (153, 141, 84),        # 밝은 금색 (40% 어둡게)
            'gold_highlight': (153, 150, 120),   # 금색 하이라이트 (40% 어둡게)
            'petal_pink': (140, 90, 110),        # 꽃잎 핑크 (어둡게)
            'petal_purple': (100, 70, 140),      # 꽃잎 보라 (어둡게)
            'petal_gold': (140, 115, 70),        # 꽃잎 금색 (어둡게)
            'star_white': (240, 235, 255),       # 별빛 흰색
            'star_blue': (180, 200, 255),        # 별빛 파랑
            # 흑요석/화강암 재질 색상 (액자 테두리용)
            'stone_deep': (15, 12, 18),          # 깊은 흑요석 (그림자)
            'stone_dark': (28, 25, 35),          # 어두운 돌
            'stone_mid': (45, 40, 55),           # 중간 돌
            'stone_light': (70, 65, 85),         # 밝은 돌
            'stone_highlight': (100, 95, 120),   # 돌 하이라이트
            'stone_shimmer': (130, 120, 160),    # 광택/반짝임
            'stone_vein': (60, 50, 80),          # 돌 결/무늬
        }

        # 타일 크기 (패턴 반복 단위) - 크게, 넓은 간격
        self.tile_size = 350

        # 스크롤 오프셋 (천천히 움직이는 효과)
        self.scroll_offset = 0

        # 펄스 효과용
        self.pulse_phase = 0

        # 별빛 파티클
        self.stars = []
        self._init_stars()

        # 떠다니는 회전 연꽃
        self.floating_lotuses = []
        self._init_floating_lotuses()

        # 꽃가루 파티클 (연꽃이 벽에 부딪힐 때 생성)
        self.petals = []

        # === 성능 최적화: 캐시 서피스들 ===
        # 액자 테두리 캐시 서피스
        self._frame_surface = None
        # 기본 배경 캐시 (정적)
        self._bg_cache = None
        # 타일링 패턴 캐시 (스크롤 위치별로 캐시하지 않고 간소화)
        self._pattern_cache_left = None
        self._pattern_cache_right = None
        self._pattern_cache_scroll = 0
        self._pattern_update_interval = 3  # 3프레임마다 패턴 업데이트
        self._pattern_frame_counter = 0
        # 별 렌더링용 재사용 서피스
        self._star_glow_cache = {}  # 크기별 글로우 서피스 캐시

        self._create_frame()
        self._create_bg_cache()

    def _create_frame(self):
        """사원 스타일 액자 프레임 생성"""
        self._frame_surface = pygame.Surface(
            (self.screen_width, self.screen_height), pygame.SRCALPHA
        )

        # 1. 외곽 금테두리
        self._draw_outer_frame_border(self._frame_surface)

        # 2. 내곽 금테두리 (게임 영역 주변)
        self._draw_inner_frame_border(self._frame_surface)

        # 3. 모서리 장식 (연꽃/만다라)
        self._draw_corner_ornaments(self._frame_surface)

    def _create_bg_cache(self):
        """기본 배경 캐시 생성 (정적 요소 사전 렌더링)"""
        self._bg_cache = pygame.Surface(
            (self.screen_width, self.screen_height), pygame.SRCALPHA
        )

        # 좌측 필러 그라데이션
        if self.game_x > 0:
            for y in range(0, self.screen_height, 4):
                ratio = y / self.screen_height
                center_ratio = 1 - abs(ratio - 0.5) * 0.25
                r = int(self.colors['bg_deep'][0] + (self.colors['bg_mid'][0] - self.colors['bg_deep'][0]) * center_ratio * 0.35)
                g = int(self.colors['bg_deep'][1] + (self.colors['bg_mid'][1] - self.colors['bg_deep'][1]) * center_ratio * 0.35)
                b = int(self.colors['bg_deep'][2] + (self.colors['bg_mid'][2] - self.colors['bg_deep'][2]) * center_ratio * 0.35)
                pygame.draw.rect(self._bg_cache, (r, g, b), (0, y, self.game_x, 4))

        # 우측 필러 그라데이션
        right_start = self.game_x + self.game_width
        if right_start < self.screen_width:
            width = self.screen_width - right_start
            for y in range(0, self.screen_height, 4):
                ratio = y / self.screen_height
                center_ratio = 1 - abs(ratio - 0.5) * 0.25
                r = int(self.colors['bg_deep'][0] + (self.colors['bg_mid'][0] - self.colors['bg_deep'][0]) * center_ratio * 0.35)
                g = int(self.colors['bg_deep'][1] + (self.colors['bg_mid'][1] - self.colors['bg_deep'][1]) * center_ratio * 0.35)
                b = int(self.colors['bg_deep'][2] + (self.colors['bg_mid'][2] - self.colors['bg_deep'][2]) * center_ratio * 0.35)
                pygame.draw.rect(self._bg_cache, (r, g, b), (right_start, y, width, 4))

        # 상하단
        if self.game_y > 0:
            pygame.draw.rect(self._bg_cache, self.colors['bg_deep'],
                           (self.game_x, 0, self.game_width, self.game_y))
        bottom_start = self.game_y + self.game_height
        if bottom_start < self.screen_height:
            pygame.draw.rect(self._bg_cache, self.colors['bg_deep'],
                           (self.game_x, bottom_start, self.game_width, self.screen_height - bottom_start))

    def _draw_outer_frame_border(self, surface: pygame.Surface):
        """외곽 흑요석/화강암 테두리 - 사원 스타일"""
        border_width = 12

        # 그라데이션 외곽 테두리 (흑요석/화강암 재질)
        for i in range(border_width):
            t = i / border_width
            if t < 0.2:
                color = self.colors['stone_deep']
            elif t < 0.4:
                color = self.colors['stone_dark']
            elif t < 0.7:
                color = self.colors['stone_mid']
            else:
                color = self.colors['stone_light']

            rect = pygame.Rect(i, i, self.screen_width - i * 2, self.screen_height - i * 2)
            pygame.draw.rect(surface, color, rect, 1)

        # 돌 결 효과 (수평선) - 자연스러운 돌 무늬
        for i in range(0, self.screen_height, 12):
            variation = random.randint(-8, 8)
            vein_color = (
                max(0, min(255, self.colors['stone_vein'][0] + variation)),
                max(0, min(255, self.colors['stone_vein'][1] + variation)),
                max(0, min(255, self.colors['stone_vein'][2] + variation))
            )
            # 상단 테두리 돌 결
            if i < border_width:
                pygame.draw.line(surface, vein_color, (0, i), (self.screen_width, i), 1)
            # 하단 테두리 돌 결
            if i > self.screen_height - border_width:
                pygame.draw.line(surface, vein_color, (0, i), (self.screen_width, i), 1)

        # 돌 결 효과 (좌우 수직선)
        for i in range(0, self.screen_width, 12):
            variation = random.randint(-8, 8)
            vein_color = (
                max(0, min(255, self.colors['stone_vein'][0] + variation)),
                max(0, min(255, self.colors['stone_vein'][1] + variation)),
                max(0, min(255, self.colors['stone_vein'][2] + variation))
            )
            # 좌측 테두리 돌 결
            if i < border_width:
                pygame.draw.line(surface, vein_color, (i, 0), (i, self.screen_height), 1)
            # 우측 테두리 돌 결
            if i > self.screen_width - border_width:
                pygame.draw.line(surface, vein_color, (i, 0), (i, self.screen_height), 1)

        # 외곽에 작은 장식점들 (보석/광택 스타일)
        dot_spacing = 35
        for x in range(dot_spacing, self.screen_width - dot_spacing, dot_spacing):
            # 상단 - 광택 반사 효과
            pygame.draw.circle(surface, self.colors['stone_deep'], (x + 1, 6), 3)
            pygame.draw.circle(surface, self.colors['stone_dark'], (x, 5), 3)
            pygame.draw.circle(surface, self.colors['stone_shimmer'], (x - 1, 4), 1)
            # 하단
            pygame.draw.circle(surface, self.colors['stone_deep'], (x + 1, self.screen_height - 4), 3)
            pygame.draw.circle(surface, self.colors['stone_dark'], (x, self.screen_height - 5), 3)
            pygame.draw.circle(surface, self.colors['stone_shimmer'], (x - 1, self.screen_height - 6), 1)

        for y in range(dot_spacing, self.screen_height - dot_spacing, dot_spacing):
            # 좌측
            pygame.draw.circle(surface, self.colors['stone_deep'], (6, y + 1), 3)
            pygame.draw.circle(surface, self.colors['stone_dark'], (5, y), 3)
            pygame.draw.circle(surface, self.colors['stone_shimmer'], (4, y - 1), 1)
            # 우측
            pygame.draw.circle(surface, self.colors['stone_deep'], (self.screen_width - 4, y + 1), 3)
            pygame.draw.circle(surface, self.colors['stone_dark'], (self.screen_width - 5, y), 3)
            pygame.draw.circle(surface, self.colors['stone_shimmer'], (self.screen_width - 6, y - 1), 1)

    def _draw_inner_frame_border(self, surface: pygame.Surface):
        """내곽 흑요석/화강암 테두리 (게임 영역 주변)"""
        margin = 6
        border_width = 10

        # 내곽 테두리 영역
        inner_rect = pygame.Rect(
            self.game_x - margin - border_width,
            self.game_y - margin - border_width,
            self.game_width + (margin + border_width) * 2,
            self.game_height + (margin + border_width) * 2
        )

        # 그라데이션 테두리 (역방향 - 안쪽이 밝게, 흑요석/화강암 재질)
        for i in range(border_width):
            t = i / border_width
            if t < 0.2:
                color = self.colors['stone_light']
            elif t < 0.5:
                color = self.colors['stone_mid']
            elif t < 0.8:
                color = self.colors['stone_dark']
            else:
                color = self.colors['stone_deep']

            rect = inner_rect.inflate(-i * 2, -i * 2)
            pygame.draw.rect(surface, color, rect, 1)

        # 내곽 돌 결 효과 (테두리 영역에만)
        for i in range(inner_rect.top, inner_rect.top + border_width, 4):
            variation = random.randint(-8, 8)
            vein_color = (
                max(0, min(255, self.colors['stone_vein'][0] + variation)),
                max(0, min(255, self.colors['stone_vein'][1] + variation)),
                max(0, min(255, self.colors['stone_vein'][2] + variation))
            )
            pygame.draw.line(surface, vein_color,
                           (inner_rect.left, i), (inner_rect.right, i), 1)
        for i in range(inner_rect.bottom - border_width, inner_rect.bottom, 4):
            variation = random.randint(-8, 8)
            vein_color = (
                max(0, min(255, self.colors['stone_vein'][0] + variation)),
                max(0, min(255, self.colors['stone_vein'][1] + variation)),
                max(0, min(255, self.colors['stone_vein'][2] + variation))
            )
            pygame.draw.line(surface, vein_color,
                           (inner_rect.left, i), (inner_rect.right, i), 1)

        # 연속 문양 장식 (상하좌우) - 돌 조각 스타일
        self._draw_continuous_pattern(surface, inner_rect)

    def _draw_continuous_pattern(self, surface: pygame.Surface, rect: pygame.Rect):
        """연속 돌 조각 문양 (테두리 장식)"""
        pattern_size = 15
        color = self.colors['stone_shimmer']
        dark_color = self.colors['stone_deep']

        # 상단 문양
        for x in range(rect.left + 25, rect.right - 25, pattern_size * 2):
            self._draw_stone_carving(surface, x, rect.top - 3, color, dark_color, 0.6)

        # 하단 문양
        for x in range(rect.left + 25, rect.right - 25, pattern_size * 2):
            self._draw_stone_carving(surface, x, rect.bottom + 3, color, dark_color, 0.6)

        # 좌측 문양
        for y in range(rect.top + 25, rect.bottom - 25, pattern_size * 2):
            self._draw_stone_carving(surface, rect.left - 3, y, color, dark_color, 0.6)

        # 우측 문양
        for y in range(rect.top + 25, rect.bottom - 25, pattern_size * 2):
            self._draw_stone_carving(surface, rect.right + 3, y, color, dark_color, 0.6)

    def _draw_stone_carving(self, surface: pygame.Surface, cx: int, cy: int,
                           color: tuple, dark_color: tuple, scale: float):
        """돌 조각 문양 (연꽃 모양)"""
        size = int(7 * scale)
        # 4방향 꽃잎 (돌 조각 스타일)
        for angle in [0, math.pi/2, math.pi, math.pi * 1.5]:
            px = cx + math.cos(angle) * size
            py = cy + math.sin(angle) * size
            # 그림자 (조각 깊이감)
            pygame.draw.circle(surface, dark_color, (int(px) + 1, int(py) + 1), 3)
            # 메인 조각
            pygame.draw.circle(surface, self.colors['stone_mid'], (int(px), int(py)), 3)
            # 하이라이트 (광택)
            pygame.draw.circle(surface, color, (int(px) - 1, int(py) - 1), 2)
        # 중심 (보석 스타일)
        pygame.draw.circle(surface, dark_color, (cx + 1, cy + 1), 3)
        pygame.draw.circle(surface, self.colors['stone_dark'], (cx, cy), 3)
        pygame.draw.circle(surface, color, (cx - 1, cy - 1), 1)

    def _draw_corner_ornaments(self, surface: pygame.Surface):
        """모서리 장식 - 흑요석/화강암 조각 스타일"""
        margin = 16
        corners = [
            (self.game_x - margin, self.game_y - margin),                    # 좌상
            (self.game_x + self.game_width + margin, self.game_y - margin),   # 우상
            (self.game_x - margin, self.game_y + self.game_height + margin),  # 좌하
            (self.game_x + self.game_width + margin, self.game_y + self.game_height + margin)  # 우하
        ]

        for cx, cy in corners:
            self._draw_corner_stone_carving(surface, cx, cy)

    def _draw_corner_stone_carving(self, surface: pygame.Surface, cx: int, cy: int):
        """모서리 흑요석/화강암 조각 장식"""
        # 외곽 원 (돌 조각 깊이감)
        pygame.draw.circle(surface, self.colors['stone_deep'], (cx + 3, cy + 3), 20)
        pygame.draw.circle(surface, self.colors['stone_dark'], (cx + 1, cy + 1), 19)
        pygame.draw.circle(surface, self.colors['stone_mid'], (cx, cy), 18)
        pygame.draw.circle(surface, self.colors['stone_light'], (cx - 1, cy - 1), 16)
        pygame.draw.circle(surface, self.colors['stone_shimmer'], (cx, cy), 14, 2)

        # 8방향 꽃잎 (돌 조각)
        for i in range(8):
            angle = (i / 8) * math.pi * 2
            petal_len = 14
            px = cx + math.cos(angle) * petal_len
            py = cy + math.sin(angle) * petal_len

            # 꽃잎 그림자 (조각 깊이)
            pygame.draw.circle(surface, self.colors['stone_deep'], (int(px) + 2, int(py) + 2), 5)
            # 꽃잎 베이스
            pygame.draw.circle(surface, self.colors['stone_dark'], (int(px), int(py)), 5)
            # 꽃잎 중간
            pygame.draw.circle(surface, self.colors['stone_mid'], (int(px), int(py)), 4)
            # 꽃잎 하이라이트 (광택)
            pygame.draw.circle(surface, self.colors['stone_light'], (int(px) - 1, int(py) - 1), 3)
            pygame.draw.circle(surface, self.colors['stone_shimmer'], (int(px) - 1, int(py) - 1), 1)

        # 중심 장식 (보석 스타일 - 흑요석 광택)
        pygame.draw.circle(surface, self.colors['stone_deep'], (cx + 2, cy + 2), 8)
        pygame.draw.circle(surface, self.colors['stone_dark'], (cx, cy), 7)
        pygame.draw.circle(surface, self.colors['stone_mid'], (cx, cy), 6)
        pygame.draw.circle(surface, self.colors['stone_light'], (cx - 1, cy - 1), 5)
        pygame.draw.circle(surface, self.colors['stone_shimmer'], (cx - 1, cy - 1), 3)

    def _init_stars(self):
        """별빛 파티클 초기화 (최적화: 색상 사전 결정)"""
        self.stars = []
        for _ in range(30):  # 40 -> 30개로 축소
            side = random.choice(['left', 'right'])
            if side == 'left' and self.game_x > 20:
                x = random.uniform(5, self.game_x - 5)
            elif side == 'right' and self.screen_width - self.game_x - self.game_width > 20:
                x = random.uniform(self.game_x + self.game_width + 5, self.screen_width - 5)
            else:
                continue

            # 색상 미리 결정 (렌더링 시 random 호출 방지)
            star_color = self.colors['star_white'] if random.random() > 0.3 else self.colors['star_blue']

            self.stars.append({
                'x': x,
                'y': random.uniform(20, self.screen_height - 20),
                'size': random.uniform(1, 3),
                'alpha': random.uniform(0.3, 1.0),
                'phase': random.uniform(0, math.pi * 2),
                'twinkle_speed': random.uniform(1.5, 4.0),
                'side': side,
                'color': star_color  # 사전 결정된 색상
            })

    def _init_floating_lotuses(self):
        """떠다니는 회전 연꽃 초기화"""
        self.floating_lotuses = []

        # 좌측 필러에 연꽃
        if self.game_x > 40:
            for _ in range(2):
                self.floating_lotuses.append(self._create_lotus('left'))

        # 우측 필러에 연꽃
        right_width = self.screen_width - self.game_x - self.game_width
        if right_width > 40:
            for _ in range(2):
                self.floating_lotuses.append(self._create_lotus('right'))

    def _create_lotus(self, side: str) -> dict:
        """새 연꽃 생성"""
        if side == 'left':
            x = random.uniform(20, self.game_x - 20)
            min_x, max_x = 15, self.game_x - 15
        else:
            x = random.uniform(self.game_x + self.game_width + 20, self.screen_width - 20)
            min_x = self.game_x + self.game_width + 15
            max_x = self.screen_width - 15

        return {
            'x': x,
            'y': random.uniform(100, self.screen_height - 100),
            'vx': random.uniform(-0.3, 0.3),
            'vy': random.uniform(-0.3, 0.3),
            'rotation': random.uniform(0, math.pi * 2),
            'rotation_speed': random.uniform(0.5, 1.5) * random.choice([-1, 1]),
            'size': random.uniform(18, 28),
            'side': side,
            'min_x': min_x,
            'max_x': max_x,
            'color_phase': random.uniform(0, math.pi * 2),
        }

    def _spawn_petals(self, x: float, y: float, count: int = 8):
        """꽃가루 생성 (연꽃이 벽에 부딪힐 때)"""
        for _ in range(count):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(1.5, 4.0)
            color_type = random.choice(['pink', 'purple', 'gold'])

            self.petals.append({
                'x': x,
                'y': y,
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed,
                'rotation': random.uniform(0, math.pi * 2),
                'rotation_speed': random.uniform(2, 6) * random.choice([-1, 1]),
                'size': random.uniform(3, 7),
                'alpha': 1.0,
                'life': 1.0,
                'decay': random.uniform(0.008, 0.015),
                'color_type': color_type,
            })

    def update(self, dt: float):
        """애니메이션 업데이트"""
        self.time += dt

        # 스크롤 오프셋 (매우 천천히)
        self.scroll_offset += dt * 3

        # 펄스
        self.pulse_phase += dt * 0.8

        # 별빛 트윙클 업데이트
        for star in self.stars:
            star['phase'] += dt * star['twinkle_speed']

        # 떠다니는 연꽃 업데이트
        for lotus in self.floating_lotuses:
            # 위치 업데이트
            lotus['x'] += lotus['vx'] * dt * 60
            lotus['y'] += lotus['vy'] * dt * 60
            lotus['rotation'] += lotus['rotation_speed'] * dt

            # 색상 위상 업데이트
            lotus['color_phase'] += dt * 0.5

            # 벽 충돌 체크 (좌우)
            if lotus['x'] < lotus['min_x']:
                lotus['x'] = lotus['min_x']
                lotus['vx'] = abs(lotus['vx']) * random.uniform(0.8, 1.2)
                self._spawn_petals(lotus['x'], lotus['y'])
            elif lotus['x'] > lotus['max_x']:
                lotus['x'] = lotus['max_x']
                lotus['vx'] = -abs(lotus['vx']) * random.uniform(0.8, 1.2)
                self._spawn_petals(lotus['x'], lotus['y'])

            # 상하 벽 충돌
            if lotus['y'] < 30:
                lotus['y'] = 30
                lotus['vy'] = abs(lotus['vy']) * random.uniform(0.8, 1.2)
                self._spawn_petals(lotus['x'], lotus['y'])
            elif lotus['y'] > self.screen_height - 30:
                lotus['y'] = self.screen_height - 30
                lotus['vy'] = -abs(lotus['vy']) * random.uniform(0.8, 1.2)
                self._spawn_petals(lotus['x'], lotus['y'])

            # 속도 랜덤 조정 (자연스러운 움직임)
            if random.random() < 0.01:
                lotus['vx'] += random.uniform(-0.1, 0.1)
                lotus['vy'] += random.uniform(-0.1, 0.1)
                # 속도 제한
                lotus['vx'] = max(-0.5, min(0.5, lotus['vx']))
                lotus['vy'] = max(-0.5, min(0.5, lotus['vy']))

        # 꽃가루 업데이트
        for petal in self.petals[:]:
            petal['x'] += petal['vx'] * dt * 60
            petal['y'] += petal['vy'] * dt * 60
            petal['vy'] += 0.02  # 중력
            petal['vx'] *= 0.98  # 공기 저항
            petal['vy'] *= 0.98
            petal['rotation'] += petal['rotation_speed'] * dt
            petal['life'] -= petal['decay']
            petal['alpha'] = max(0, petal['life'])

            if petal['life'] <= 0:
                self.petals.remove(petal)

    def draw(self, screen: pygame.Surface):
        """전체 렌더링 (최적화됨)"""
        # 1. 캐시된 기본 배경
        if self._bg_cache is not None:
            screen.blit(self._bg_cache, (0, 0))

        # 2. 별빛 (간소화)
        self._draw_stars_optimized(screen)

        # 3. 이어지는 타일링 만다라 패턴 (간격을 두고 업데이트)
        self._draw_tiling_pattern_optimized(screen)

        # 4. 떠다니는 연꽃
        self._draw_floating_lotuses(screen)

        # 5. 꽃가루 (개수 제한)
        self._draw_petals(screen)

        # 6. 금색 테두리 장식
        self._draw_golden_borders(screen)

        # 7. 액자 프레임 (맨 위에)
        if self._frame_surface is not None:
            screen.blit(self._frame_surface, (0, 0))

    def _draw_stars_optimized(self, screen: pygame.Surface):
        """별빛 그리기 (최적화 - 글로우 캐시 사용, 일부만 렌더링)"""
        # 매 프레임 절반의 별만 렌더링 (교대로)
        frame_parity = int(self.time * 60) % 2

        for i, star in enumerate(self.stars):
            # 교대 렌더링으로 부하 분산
            if i % 2 != frame_parity:
                continue

            # 트윙클 효과
            twinkle = (math.sin(star['phase']) + 1) / 2
            alpha = int(star['alpha'] * twinkle * 200)
            size = star['size'] * (0.7 + twinkle * 0.6)

            if alpha > 20:  # 임계값 상향
                # 별 색상 (미리 정해진 색 사용)
                color = star.get('color', self.colors['star_white'])

                # 글로우 효과 생략 (성능 향상)
                # 코어만 그리기
                pygame.draw.circle(screen, color, (int(star['x']), int(star['y'])), max(1, int(size)))

    def _draw_floating_lotuses(self, screen: pygame.Surface):
        """떠다니는 연꽃 그리기 (어둡고 투명하게)"""
        for lotus in self.floating_lotuses:
            cx, cy = int(lotus['x']), int(lotus['y'])
            size = lotus['size']
            rotation = lotus['rotation']
            color_phase = lotus['color_phase']

            # 연꽃용 투명 서피스 생성 (크기 여유있게)
            lotus_size = int(size * 2.5)
            lotus_surf = pygame.Surface((lotus_size, lotus_size), pygame.SRCALPHA)
            local_cx = lotus_size // 2
            local_cy = lotus_size // 2

            # 색상 그라데이션 (시간에 따라 변화)
            color_shift = (math.sin(color_phase) + 1) / 2

            # 8개의 꽃잎
            num_petals = 8
            for i in range(num_petals):
                angle = rotation + (i / num_petals) * math.pi * 2

                # 꽃잎 끝점
                petal_len = size * 0.9
                end_x = local_cx + math.cos(angle) * petal_len
                end_y = local_cy + math.sin(angle) * petal_len

                # 꽃잎 측면
                perp = angle + math.pi / 2
                width = size * 0.35
                mid_dist = petal_len * 0.5

                mid_x = local_cx + math.cos(angle) * mid_dist
                mid_y = local_cy + math.sin(angle) * mid_dist

                side1_x = mid_x + math.cos(perp) * width
                side1_y = mid_y + math.sin(perp) * width
                side2_x = mid_x - math.cos(perp) * width
                side2_y = mid_y - math.sin(perp) * width

                points = [(local_cx, local_cy), (side1_x, side1_y), (end_x, end_y), (side2_x, side2_y)]

                # 색상 선택 (꽃잎마다 약간 다르게)
                petal_phase = color_shift + i * 0.1
                if petal_phase % 1 < 0.33:
                    base_color = self.colors['petal_pink']
                elif petal_phase % 1 < 0.66:
                    base_color = self.colors['petal_purple']
                else:
                    base_color = self.colors['petal_gold']

                # 그림자 (더 어둡게)
                shadow_pts = [(p[0] + 2, p[1] + 2) for p in points]
                pygame.draw.polygon(lotus_surf, (10, 8, 15, 80), shadow_pts)

                # 꽃잎 베이스
                pygame.draw.polygon(lotus_surf, base_color, points)

                # 하이라이트 (더 은은하게)
                inner_pts = [
                    (local_cx, local_cy),
                    (side1_x * 0.6 + local_cx * 0.4, side1_y * 0.6 + local_cy * 0.4),
                    (end_x * 0.7 + local_cx * 0.3, end_y * 0.7 + local_cy * 0.3),
                    (side2_x * 0.6 + local_cx * 0.4, side2_y * 0.6 + local_cy * 0.4)
                ]
                highlight_color = tuple(min(255, c + 30) for c in base_color)
                pygame.draw.polygon(lotus_surf, highlight_color, inner_pts)

                # 테두리 (더 어둡게)
                border_color = tuple(min(200, c + 40) for c in base_color)
                pygame.draw.polygon(lotus_surf, border_color, points, 1)

            # 중심부 (어둡게)
            pygame.draw.circle(lotus_surf, self.colors['gold_mid'], (local_cx, local_cy), int(size * 0.25))
            pygame.draw.circle(lotus_surf, self.colors['gold_light'], (local_cx - 1, local_cy - 1), int(size * 0.15))

            # 투명도 적용 후 화면에 블릿
            lotus_surf.set_alpha(100)  # 투명하게 (255의 약 40%)
            screen.blit(lotus_surf, (cx - lotus_size // 2, cy - lotus_size // 2))

    def _draw_petals(self, screen: pygame.Surface):
        """꽃가루 그리기"""
        for petal in self.petals:
            if petal['alpha'] <= 0:
                continue

            px, py = int(petal['x']), int(petal['y'])
            size = petal['size']
            rotation = petal['rotation']
            alpha = int(petal['alpha'] * 255)

            # 색상 선택
            if petal['color_type'] == 'pink':
                color = self.colors['petal_pink']
            elif petal['color_type'] == 'purple':
                color = self.colors['petal_purple']
            else:
                color = self.colors['petal_gold']

            # 꽃잎 모양 (타원형)
            petal_surf = pygame.Surface((int(size * 2), int(size)), pygame.SRCALPHA)

            # 투명도 적용
            adjusted_color = (*color, alpha)
            pygame.draw.ellipse(petal_surf, adjusted_color, (0, 0, int(size * 2), int(size)))

            # 회전
            rotated = pygame.transform.rotate(petal_surf, math.degrees(rotation))
            rect = rotated.get_rect(center=(px, py))
            screen.blit(rotated, rect.topleft)

    def _draw_base_background(self, screen: pygame.Surface):
        """기본 배경 (깊은 그라데이션과 텍스처)"""
        # 좌측 필러
        if self.game_x > 0:
            surf = pygame.Surface((self.game_x, self.screen_height), pygame.SRCALPHA)
            for y in range(0, self.screen_height, 4):
                ratio = y / self.screen_height
                center_ratio = 1 - abs(ratio - 0.5) * 0.25
                r = int(self.colors['bg_deep'][0] + (self.colors['bg_mid'][0] - self.colors['bg_deep'][0]) * center_ratio * 0.35)
                g = int(self.colors['bg_deep'][1] + (self.colors['bg_mid'][1] - self.colors['bg_deep'][1]) * center_ratio * 0.35)
                b = int(self.colors['bg_deep'][2] + (self.colors['bg_mid'][2] - self.colors['bg_deep'][2]) * center_ratio * 0.35)
                pygame.draw.rect(surf, (r, g, b), (0, y, self.game_x, 4))
            screen.blit(surf, (0, 0))

        # 우측 필러
        right_start = self.game_x + self.game_width
        if right_start < self.screen_width:
            width = self.screen_width - right_start
            surf = pygame.Surface((width, self.screen_height), pygame.SRCALPHA)
            for y in range(0, self.screen_height, 4):
                ratio = y / self.screen_height
                center_ratio = 1 - abs(ratio - 0.5) * 0.25
                r = int(self.colors['bg_deep'][0] + (self.colors['bg_mid'][0] - self.colors['bg_deep'][0]) * center_ratio * 0.35)
                g = int(self.colors['bg_deep'][1] + (self.colors['bg_mid'][1] - self.colors['bg_deep'][1]) * center_ratio * 0.35)
                b = int(self.colors['bg_deep'][2] + (self.colors['bg_mid'][2] - self.colors['bg_deep'][2]) * center_ratio * 0.35)
                pygame.draw.rect(surf, (r, g, b), (0, y, width, 4))
            screen.blit(surf, (right_start, 0))

        # 상하단
        if self.game_y > 0:
            pygame.draw.rect(screen, self.colors['bg_deep'],
                           (self.game_x, 0, self.game_width, self.game_y))
        bottom_start = self.game_y + self.game_height
        if bottom_start < self.screen_height:
            pygame.draw.rect(screen, self.colors['bg_deep'],
                           (self.game_x, bottom_start, self.game_width, self.screen_height - bottom_start))

    def _draw_tiling_pattern_optimized(self, screen: pygame.Surface):
        """이어지는 타일링 만다라 패턴 (최적화: 캐시 + 간격 업데이트)"""
        self._pattern_frame_counter += 1
        scroll_y = int(self.scroll_offset) % self.tile_size
        pulse = math.sin(self.pulse_phase) * 0.02

        # 패턴 업데이트 필요 여부 체크 (N프레임마다 또는 캐시 없을 때)
        need_update = (self._pattern_frame_counter % self._pattern_update_interval == 0 or
                       self._pattern_cache_left is None or
                       self._pattern_cache_right is None)

        # 좌측 필러
        if self.game_x > 20:
            if need_update:
                if self._pattern_cache_left is None:
                    self._pattern_cache_left = pygame.Surface((self.game_x, self.screen_height), pygame.SRCALPHA)
                self._pattern_cache_left.fill((0, 0, 0, 0))  # 클리어
                self._draw_pillar_pattern_simplified(self._pattern_cache_left, 0, self.game_x, scroll_y, pulse, 'left')
                self._pattern_cache_left.set_alpha(12)  # 매우 은은하게

            if self._pattern_cache_left is not None:
                screen.blit(self._pattern_cache_left, (0, 0))

        # 우측 필러
        right_start = self.game_x + self.game_width
        right_width = self.screen_width - right_start
        if right_width > 20:
            if need_update:
                if self._pattern_cache_right is None:
                    self._pattern_cache_right = pygame.Surface((right_width, self.screen_height), pygame.SRCALPHA)
                self._pattern_cache_right.fill((0, 0, 0, 0))  # 클리어
                self._draw_pillar_pattern_simplified(self._pattern_cache_right, 0, right_width, -scroll_y, pulse, 'right')
                self._pattern_cache_right.set_alpha(12)  # 매우 은은하게

            if self._pattern_cache_right is not None:
                screen.blit(self._pattern_cache_right, (right_start, 0))

    def _draw_pillar_pattern_simplified(self, screen: pygame.Surface, start_x: int, width: int,
                                        scroll_y: int, pulse: float, side: str):
        """간소화된 필러 패턴 (성능 최적화)"""
        tile_size = self.tile_size

        # 열 개수 계산 (최대 1열로 제한하여 단순화)
        num_cols = 1
        col_x = start_x + width // 2

        # 수직으로 타일 반복 (간격 늘림)
        num_tiles_y = (self.screen_height // tile_size) + 2
        start_tile_y = -1

        for ty in range(start_tile_y, num_tiles_y):
            tile_y = ty * tile_size + scroll_y

            # 각 타일의 중심 위치
            cy = tile_y + tile_size // 2

            # 화면 밖 타일 스킵
            if cy < -tile_size or cy > self.screen_height + tile_size:
                continue

            # 타일 인덱스에 따라 패턴 변경
            tile_index = ty % 4

            # 간소화된 노드 그리기
            node_size = tile_size * 0.35 * (1 + pulse)
            self._draw_simple_node(screen, int(col_x), cy, int(node_size), tile_index)

            # 수직 연결 라인
            if ty > start_tile_y:
                prev_cy = tile_y - tile_size // 2
                pygame.draw.line(screen, self.colors['engrave_dark'],
                               (int(col_x), prev_cy), (int(col_x), cy), 1)

    def _draw_simple_node(self, screen: pygame.Surface, cx: int, cy: int, size: int, node_type: int):
        """간소화된 노드 (성능 최적화)"""
        if size < 3:
            return

        # 외곽 원
        pygame.draw.circle(screen, self.colors['engrave_dark'], (cx, cy), size, 2)
        pygame.draw.circle(screen, self.colors['relief_dark'], (cx, cy), size - 3, 1)

        # 간단한 내부 패턴 (노드 타입별)
        if node_type == 0:
            # 연꽃 스타일 - 4방향만
            for angle in [0, math.pi/2, math.pi, math.pi * 1.5]:
                px = cx + math.cos(angle) * (size * 0.6)
                py = cy + math.sin(angle) * (size * 0.6)
                pygame.draw.circle(screen, self.colors['relief_mid'], (int(px), int(py)), 3)
        elif node_type == 1:
            # 다이아몬드
            half = size * 0.5
            points = [(cx, cy - half), (cx + half, cy), (cx, cy + half), (cx - half, cy)]
            pygame.draw.polygon(screen, self.colors['relief_dark'], points, 1)
        elif node_type == 2:
            # 동심원
            pygame.draw.circle(screen, self.colors['relief_mid'], (cx, cy), size // 2, 1)
        else:
            # 십자
            pygame.draw.line(screen, self.colors['relief_dark'], (cx - size // 2, cy), (cx + size // 2, cy), 1)
            pygame.draw.line(screen, self.colors['relief_dark'], (cx, cy - size // 2), (cx, cy + size // 2), 1)

        # 중심점
        pygame.draw.circle(screen, self.colors['gold_mid'], (cx, cy), 2)

    def _draw_tiling_pattern(self, screen: pygame.Surface):
        """이어지는 타일링 만다라 패턴 (다중 열) - 은은하게 투명 (원본 - 미사용)"""
        scroll_y = int(self.scroll_offset) % self.tile_size
        pulse = math.sin(self.pulse_phase) * 0.02

        # 투명도를 위한 서피스 생성
        # 좌측 필러
        if self.game_x > 20:
            pattern_surf = pygame.Surface((self.game_x, self.screen_height), pygame.SRCALPHA)
            self._draw_pillar_pattern(pattern_surf, 0, self.game_x, scroll_y, pulse, 'left')
            pattern_surf.set_alpha(35)  # 은은하게 보일랑 말랑 (약 14% 투명도)
            screen.blit(pattern_surf, (0, 0))

        # 우측 필러
        right_start = self.game_x + self.game_width
        right_width = self.screen_width - right_start
        if right_width > 20:
            pattern_surf = pygame.Surface((right_width, self.screen_height), pygame.SRCALPHA)
            self._draw_pillar_pattern(pattern_surf, 0, right_width, -scroll_y, pulse, 'right')
            pattern_surf.set_alpha(35)  # 은은하게 보일랑 말랑
            screen.blit(pattern_surf, (right_start, 0))

    def _draw_pillar_pattern(self, screen: pygame.Surface, start_x: int, width: int,
                             scroll_y: int, pulse: float, side: str):
        """한쪽 필러에 타일링 패턴 그리기 (다중 열)"""
        tile_size = self.tile_size

        # 열 개수 계산 (필러 너비에 따라)
        num_cols = max(1, width // tile_size)
        col_spacing = width / (num_cols + 1)

        # 수직으로 타일 반복
        num_tiles_y = (self.screen_height // tile_size) + 3
        start_tile_y = -2

        for col in range(num_cols):
            col_x = start_x + col_spacing * (col + 1)
            col_scroll = scroll_y if col % 2 == 0 else -scroll_y  # 열마다 스크롤 방향 교차

            for ty in range(start_tile_y, num_tiles_y):
                tile_y = ty * tile_size + col_scroll

                # 각 타일의 중심 위치
                cy = tile_y + tile_size // 2

                # 화면 밖 타일 스킵
                if cy < -tile_size or cy > self.screen_height + tile_size:
                    continue

                # 타일 인덱스에 따라 패턴 변경 (열에 따라 다른 패턴)
                tile_index = (ty + col) % 4

                # 연결된 만다라 노드 그리기 (더 큰 노드)
                node_size = tile_size * 0.42 * (1 + pulse)
                self._draw_connected_node(screen, int(col_x), cy, node_size, tile_index, side)

                # 수직 연결 라인 (위아래 노드 연결)
                if ty > start_tile_y:
                    prev_cy = tile_y - tile_size // 2
                    self._draw_connection_line_simple(screen, int(col_x), prev_cy, int(col_x), cy)

            # 열 사이 수평 연결 (인접 열 연결)
            if col < num_cols - 1:
                next_col_x = start_x + col_spacing * (col + 2)
                for ty in range(start_tile_y, num_tiles_y):
                    cy = ty * tile_size + tile_size // 2 + scroll_y
                    if 0 < cy < self.screen_height:
                        self._draw_horizontal_connection(screen, int(col_x), int(next_col_x), cy)

    def _draw_connected_node(self, screen: pygame.Surface, cx: int, cy: int,
                            size: float, node_type: int, side: str):
        """연결된 만다라 노드 (다양한 타입)"""
        size = int(size)
        if size < 5:
            return

        if node_type == 0:
            self._draw_lotus_node(screen, cx, cy, size)
        elif node_type == 1:
            self._draw_diamond_node(screen, cx, cy, size)
        elif node_type == 2:
            self._draw_circle_node(screen, cx, cy, size)
        else:
            self._draw_cross_node(screen, cx, cy, size)

    def _draw_lotus_node(self, screen: pygame.Surface, cx: int, cy: int, size: int):
        """연꽃 노드 - 8방향 꽃잎이 연결되는 형태 (고품질)"""
        # 외곽 다중 원 테두리 - 깊은 음각 효과
        for i in range(3):
            offset = i * 2
            alpha_factor = 1 - i * 0.2
            pygame.draw.circle(screen, self.colors['shadow_dark'],
                             (cx + 3 - i, cy + 3 - i), size + 2 - offset, 2)

        # 외곽 원 - 다층 음각
        pygame.draw.circle(screen, self.colors['engrave_dark'], (cx, cy), size, 5)
        pygame.draw.circle(screen, self.colors['engrave_light'], (cx - 1, cy - 1), size - 1, 2)
        pygame.draw.circle(screen, self.colors['relief_dark'], (cx, cy), size - 4, 1)

        # 내부 장식 링 (여러 겹)
        ring_sizes = [0.85, 0.7, 0.55]
        for i, ring_ratio in enumerate(ring_sizes):
            ring_r = int(size * ring_ratio)
            if ring_r > 3:
                pygame.draw.circle(screen, self.colors['engrave_dark'], (cx, cy), ring_r, 1)
                # 링 사이에 작은 장식점들
                if i < len(ring_sizes) - 1:
                    num_dots = 16
                    for d in range(num_dots):
                        dot_angle = (d / num_dots) * math.pi * 2 + self.time * 0.01
                        dot_x = cx + math.cos(dot_angle) * ring_r * 0.92
                        dot_y = cy + math.sin(dot_angle) * ring_r * 0.92
                        pygame.draw.circle(screen, self.colors['relief_dark'],
                                         (int(dot_x), int(dot_y)), 1)

        # 8방향 연결 꽃잎 (양각) - 고품질
        num_petals = 8
        rotation = self.time * 0.015

        for i in range(num_petals):
            angle = (i / num_petals) * math.pi * 2 + rotation
            self._draw_connecting_petal_hq(screen, cx, cy, angle, size * 0.8)

        # 꽃잎 사이 작은 보조 꽃잎
        for i in range(8):
            angle = (i / 8) * math.pi * 2 + rotation + math.pi / 8
            self._draw_small_petal(screen, cx, cy, angle, size * 0.45)

        # 내부 장식 원 - 다층 그라데이션
        inner_size = size * 0.4
        # 그림자 층
        pygame.draw.circle(screen, self.colors['shadow_dark'], (cx + 2, cy + 2), int(inner_size) + 2, 3)
        # 기본 층들
        pygame.draw.circle(screen, self.colors['relief_dark'], (cx, cy), int(inner_size))
        pygame.draw.circle(screen, self.colors['relief_mid'], (cx, cy), int(inner_size * 0.85))
        pygame.draw.circle(screen, self.colors['relief_light'], (cx - 1, cy - 1), int(inner_size * 0.7))
        pygame.draw.circle(screen, self.colors['relief_highlight'], (cx - 1, cy - 1), int(inner_size * 0.5))

        # 내부 링 장식
        pygame.draw.circle(screen, self.colors['engrave_dark'], (cx, cy), int(inner_size * 0.75), 1)
        pygame.draw.circle(screen, self.colors['engrave_dark'], (cx, cy), int(inner_size * 0.55), 1)

        # 중심 금색 장식 - 다층
        pygame.draw.circle(screen, self.colors['gold_dark'], (cx + 1, cy + 1), int(inner_size * 0.35))
        pygame.draw.circle(screen, self.colors['gold_mid'], (cx, cy), int(inner_size * 0.3))
        pygame.draw.circle(screen, self.colors['gold_light'], (cx - 1, cy - 1), int(inner_size * 0.2))
        pygame.draw.circle(screen, self.colors['gold_highlight'], (cx - 1, cy - 1), int(inner_size * 0.1))

    def _draw_connecting_petal_hq(self, screen: pygame.Surface, cx: int, cy: int,
                                   angle: float, length: float):
        """고품질 연결형 꽃잎 (섬세한 디테일)"""
        # 꽃잎 끝점
        end_x = cx + math.cos(angle) * length
        end_y = cy + math.sin(angle) * length

        # 꽃잎 측면 - 더 유려한 곡선을 위해 여러 포인트
        perp = angle + math.pi / 2
        width = length * 0.28

        # 여러 지점에서의 너비 (곡선 효과)
        points_outer = []
        points_inner = []
        num_segments = 6

        for i in range(num_segments + 1):
            t = i / num_segments
            # 곡선 너비 프로파일 (중간이 가장 넓음)
            curve_width = math.sin(t * math.pi) * width

            px = cx + math.cos(angle) * length * t
            py = cy + math.sin(angle) * length * t

            points_outer.append((
                px + math.cos(perp) * curve_width,
                py + math.sin(perp) * curve_width
            ))
            points_inner.insert(0, (
                px - math.cos(perp) * curve_width,
                py - math.sin(perp) * curve_width
            ))

        points = points_outer + points_inner

        # 깊은 그림자 (여러 층)
        for offset in [3, 2]:
            shadow_pts = [(p[0] + offset, p[1] + offset) for p in points]
            pygame.draw.polygon(screen, self.colors['shadow_dark'], shadow_pts)

        # 베이스 레이어
        pygame.draw.polygon(screen, self.colors['relief_dark'], points)

        # 중간 하이라이트 레이어
        inner_scale = 0.75
        inner_pts = []
        for i in range(num_segments + 1):
            t = i / num_segments
            curve_width = math.sin(t * math.pi) * width * inner_scale

            px = cx + math.cos(angle) * length * t * 0.95
            py = cy + math.sin(angle) * length * t * 0.95

            inner_pts.append((
                px + math.cos(perp) * curve_width,
                py + math.sin(perp) * curve_width
            ))
        for i in range(num_segments, -1, -1):
            t = i / num_segments
            curve_width = math.sin(t * math.pi) * width * inner_scale

            px = cx + math.cos(angle) * length * t * 0.95
            py = cy + math.sin(angle) * length * t * 0.95

            inner_pts.append((
                px - math.cos(perp) * curve_width,
                py - math.sin(perp) * curve_width
            ))

        pygame.draw.polygon(screen, self.colors['relief_mid'], inner_pts)

        # 밝은 하이라이트 (상단)
        highlight_pts = []
        for i in range(num_segments + 1):
            t = i / num_segments
            curve_width = math.sin(t * math.pi) * width * 0.4

            px = cx + math.cos(angle) * length * t * 0.85 - 1
            py = cy + math.sin(angle) * length * t * 0.85 - 1

            highlight_pts.append((
                px + math.cos(perp) * curve_width,
                py + math.sin(perp) * curve_width
            ))
        for i in range(num_segments, -1, -1):
            t = i / num_segments
            curve_width = math.sin(t * math.pi) * width * 0.4

            px = cx + math.cos(angle) * length * t * 0.85 - 1
            py = cy + math.sin(angle) * length * t * 0.85 - 1

            highlight_pts.append((
                px - math.cos(perp) * curve_width,
                py - math.sin(perp) * curve_width
            ))

        pygame.draw.polygon(screen, self.colors['relief_light'], highlight_pts)

        # 테두리
        pygame.draw.polygon(screen, self.colors['relief_highlight'], points, 1)

        # 중심 정맥선 (여러 층)
        mid_len = length * 0.7
        mid_x = cx + math.cos(angle) * mid_len
        mid_y = cy + math.sin(angle) * mid_len
        pygame.draw.line(screen, self.colors['relief_mid'],
                        (cx, cy), (int(mid_x), int(mid_y)), 2)
        pygame.draw.line(screen, self.colors['relief_highlight'],
                        (cx - 1, cy - 1), (int(mid_x) - 1, int(mid_y) - 1), 1)

    def _draw_small_petal(self, screen: pygame.Surface, cx: int, cy: int,
                          angle: float, length: float):
        """작은 보조 꽃잎 (꽃잎 사이 장식)"""
        end_x = cx + math.cos(angle) * length
        end_y = cy + math.sin(angle) * length

        perp = angle + math.pi / 2
        width = length * 0.2

        mid_x = cx + math.cos(angle) * length * 0.5
        mid_y = cy + math.sin(angle) * length * 0.5

        points = [
            (cx + math.cos(angle) * length * 0.2, cy + math.sin(angle) * length * 0.2),
            (mid_x + math.cos(perp) * width, mid_y + math.sin(perp) * width),
            (end_x, end_y),
            (mid_x - math.cos(perp) * width, mid_y - math.sin(perp) * width)
        ]

        # 그림자
        shadow_pts = [(p[0] + 1, p[1] + 1) for p in points]
        pygame.draw.polygon(screen, self.colors['shadow_dark'], shadow_pts)

        # 베이스
        pygame.draw.polygon(screen, self.colors['engrave_light'], points)

        # 테두리
        pygame.draw.polygon(screen, self.colors['relief_dark'], points, 1)

    def _draw_connecting_petal(self, screen: pygame.Surface, cx: int, cy: int,
                               angle: float, length: float):
        """연결형 꽃잎 (끝이 뾰족하게 연결되는 형태) - 기본 버전"""
        # 꽃잎 끝점
        end_x = cx + math.cos(angle) * length
        end_y = cy + math.sin(angle) * length

        # 꽃잎 측면
        perp = angle + math.pi / 2
        width = length * 0.25
        mid_dist = length * 0.5

        mid_x = cx + math.cos(angle) * mid_dist
        mid_y = cy + math.sin(angle) * mid_dist

        side1_x = mid_x + math.cos(perp) * width
        side1_y = mid_y + math.sin(perp) * width
        side2_x = mid_x - math.cos(perp) * width
        side2_y = mid_y - math.sin(perp) * width

        points = [(cx, cy), (side1_x, side1_y), (end_x, end_y), (side2_x, side2_y)]

        # 그림자
        shadow_pts = [(p[0] + 2, p[1] + 2) for p in points]
        pygame.draw.polygon(screen, self.colors['shadow_dark'], shadow_pts)

        # 베이스
        pygame.draw.polygon(screen, self.colors['relief_dark'], points)

        # 하이라이트
        inner_pts = [
            (cx, cy),
            (side1_x * 0.7 + cx * 0.3, side1_y * 0.7 + cy * 0.3),
            (end_x * 0.85 + cx * 0.15, end_y * 0.85 + cy * 0.15),
            (side2_x * 0.7 + cx * 0.3, side2_y * 0.7 + cy * 0.3)
        ]
        pygame.draw.polygon(screen, self.colors['relief_mid'], inner_pts)

        # 테두리
        pygame.draw.polygon(screen, self.colors['relief_light'], points, 1)

        # 중심선
        pygame.draw.line(screen, self.colors['relief_highlight'],
                        (cx, cy), (int(mid_x), int(mid_y)), 1)

    def _draw_diamond_node(self, screen: pygame.Surface, cx: int, cy: int, size: int):
        """다이아몬드 노드 - 사각 패턴 (고품질)"""
        # 다이아몬드 포인트
        points = [
            (cx, cy - size),
            (cx + size, cy),
            (cx, cy + size),
            (cx - size, cy)
        ]

        # 다중 그림자 효과
        for offset in [4, 3, 2]:
            shadow_pts = [(p[0] + offset, p[1] + offset) for p in points]
            pygame.draw.polygon(screen, self.colors['shadow_dark'], shadow_pts)

        # 베이스 - 다층 테두리
        pygame.draw.polygon(screen, self.colors['engrave_dark'], points)
        pygame.draw.polygon(screen, self.colors['engrave_light'], points, 3)

        # 4변에 장식 라인
        for i in range(4):
            p1 = points[i]
            p2 = points[(i + 1) % 4]
            mid_x = (p1[0] + p2[0]) / 2
            mid_y = (p1[1] + p2[1]) / 2
            # 각 변의 중간에 작은 장식
            pygame.draw.circle(screen, self.colors['relief_dark'], (int(mid_x), int(mid_y)), 3)
            pygame.draw.circle(screen, self.colors['relief_light'], (int(mid_x) - 1, int(mid_y) - 1), 2)

        # 여러 겹의 내부 다이아몬드
        layer_sizes = [0.8, 0.65, 0.5, 0.35]
        layer_colors = ['relief_dark', 'relief_mid', 'relief_light', 'relief_highlight']

        for layer_size, color_key in zip(layer_sizes, layer_colors):
            inner_size = size * layer_size
            inner_points = [
                (cx, cy - inner_size),
                (cx + inner_size, cy),
                (cx, cy + inner_size),
                (cx - inner_size, cy)
            ]
            pygame.draw.polygon(screen, self.colors[color_key], inner_points)
            # 각 레이어에 테두리
            if layer_size > 0.4:
                pygame.draw.polygon(screen, self.colors['engrave_dark'], inner_points, 1)

        # 대각선 장식 라인 (4개)
        diag_size = size * 0.6
        for angle in [math.pi/4, 3*math.pi/4, 5*math.pi/4, 7*math.pi/4]:
            dx = math.cos(angle) * diag_size
            dy = math.sin(angle) * diag_size
            pygame.draw.line(screen, self.colors['engrave_dark'],
                           (cx, cy), (int(cx + dx), int(cy + dy)), 1)

        # 4방향 연결점 - 더 정교하게
        for angle in [0, math.pi/2, math.pi, math.pi*1.5]:
            px = cx + math.cos(angle) * size
            py = cy + math.sin(angle) * size

            # 연결점 그림자
            pygame.draw.circle(screen, self.colors['shadow_dark'],
                             (int(px) + 2, int(py) + 2), 5)
            # 다층 원
            pygame.draw.circle(screen, self.colors['gold_dark'], (int(px), int(py)), 5)
            pygame.draw.circle(screen, self.colors['gold_mid'], (int(px), int(py)), 4)
            pygame.draw.circle(screen, self.colors['gold_light'], (int(px) - 1, int(py) - 1), 3)
            pygame.draw.circle(screen, self.colors['gold_highlight'], (int(px) - 1, int(py) - 1), 2)

        # 중심 장식 - 다층 그라데이션
        center_sizes = [0.25, 0.2, 0.15, 0.1, 0.05]
        center_colors = ['gold_dark', 'gold_mid', 'gold_light', 'gold_highlight', 'star_white']
        for csize, ccolor in zip(center_sizes, center_colors):
            offset = -1 if csize < 0.2 else 0
            pygame.draw.circle(screen, self.colors[ccolor],
                             (cx + offset, cy + offset), int(size * csize))

        # 중심에 작은 다이아몬드
        tiny_size = size * 0.12
        tiny_points = [
            (cx, cy - tiny_size),
            (cx + tiny_size, cy),
            (cx, cy + tiny_size),
            (cx - tiny_size, cy)
        ]
        pygame.draw.polygon(screen, self.colors['relief_highlight'], tiny_points, 1)

    def _draw_circle_node(self, screen: pygame.Surface, cx: int, cy: int, size: int):
        """원형 노드 - 동심원 패턴 (고품질)"""
        # 외곽 다중 그림자
        for offset in [3, 2]:
            pygame.draw.circle(screen, self.colors['shadow_dark'],
                             (cx + offset, cy + offset), size + 2, 3)

        # 동심원들 - 더 많은 레이어와 정교한 음각/양각
        ring_configs = [
            (1.0, 'engrave_dark', 4),
            (0.92, 'engrave_light', 2),
            (0.85, 'relief_dark', 1),
            (0.75, 'engrave_dark', 3),
            (0.68, 'relief_mid', 1),
            (0.58, 'engrave_dark', 2),
            (0.52, 'relief_light', 1),
            (0.42, 'engrave_dark', 2),
            (0.38, 'relief_highlight', 1),
        ]

        for ratio, color_key, width in ring_configs:
            r = int(size * ratio)
            if r > 0:
                pygame.draw.circle(screen, self.colors[color_key], (cx, cy), r, width)

        # 8방향 방사형 장식 라인
        for i in range(8):
            angle = (i / 8) * math.pi * 2 + self.time * 0.015
            # 외곽에서 중심 방향으로 라인
            outer_x = cx + math.cos(angle) * size * 0.95
            outer_y = cy + math.sin(angle) * size * 0.95
            inner_x = cx + math.cos(angle) * size * 0.6
            inner_y = cy + math.sin(angle) * size * 0.6

            # 그림자
            pygame.draw.line(screen, self.colors['shadow_dark'],
                           (int(outer_x) + 1, int(outer_y) + 1),
                           (int(inner_x) + 1, int(inner_y) + 1), 2)
            # 메인 라인
            pygame.draw.line(screen, self.colors['relief_dark'],
                           (int(outer_x), int(outer_y)),
                           (int(inner_x), int(inner_y)), 2)
            pygame.draw.line(screen, self.colors['relief_light'],
                           (int(outer_x) - 1, int(outer_y) - 1),
                           (int(inner_x) - 1, int(inner_y) - 1), 1)

        # 12방향 연결 장식점 - 다층
        for i in range(12):
            angle = (i / 12) * math.pi * 2 + self.time * 0.02
            # 여러 거리에 점 배치
            for dist, dot_base_size in [(0.95, 4), (0.75, 3), (0.55, 2)]:
                px = cx + math.cos(angle) * size * dist
                py = cy + math.sin(angle) * size * dist

                # 교차 패턴 (짝수/홀수 다른 크기)
                actual_size = dot_base_size if i % 2 == 0 else dot_base_size - 1
                if actual_size > 0:
                    pygame.draw.circle(screen, self.colors['shadow_dark'],
                                     (int(px) + 1, int(py) + 1), actual_size)
                    pygame.draw.circle(screen, self.colors['relief_dark'],
                                     (int(px), int(py)), actual_size)
                    if actual_size > 1:
                        pygame.draw.circle(screen, self.colors['relief_light'],
                                         (int(px) - 1, int(py) - 1), actual_size - 1)

        # 중심 장식 - 다층 그라데이션
        center_r = int(size * 0.3)
        pygame.draw.circle(screen, self.colors['shadow_dark'], (cx + 2, cy + 2), center_r + 2, 2)
        pygame.draw.circle(screen, self.colors['relief_dark'], (cx, cy), center_r)
        pygame.draw.circle(screen, self.colors['relief_mid'], (cx, cy), int(center_r * 0.85))
        pygame.draw.circle(screen, self.colors['relief_light'], (cx - 1, cy - 1), int(center_r * 0.7))
        pygame.draw.circle(screen, self.colors['relief_highlight'], (cx - 1, cy - 1), int(center_r * 0.5))

        # 금색 중심점
        pygame.draw.circle(screen, self.colors['gold_dark'], (cx, cy), int(size * 0.15))
        pygame.draw.circle(screen, self.colors['gold_mid'], (cx, cy), int(size * 0.12))
        pygame.draw.circle(screen, self.colors['gold_light'], (cx - 1, cy - 1), int(size * 0.08))
        pygame.draw.circle(screen, self.colors['gold_highlight'], (cx - 1, cy - 1), int(size * 0.04))

    def _draw_cross_node(self, screen: pygame.Surface, cx: int, cy: int, size: int):
        """십자 노드 - 4방향 연결 강조 (고품질)"""
        arm_width = size * 0.35

        # 외곽 원형 테두리 (십자를 감싸는)
        for offset in [3, 2]:
            pygame.draw.circle(screen, self.colors['shadow_dark'],
                             (cx + offset, cy + offset), int(size * 1.05), 2)
        pygame.draw.circle(screen, self.colors['engrave_dark'], (cx, cy), int(size * 1.02), 2)
        pygame.draw.circle(screen, self.colors['engrave_light'], (cx, cy), int(size * 0.98), 1)

        # 4방향 팔 - 고품질
        for angle in [0, math.pi/2, math.pi, math.pi*1.5]:
            end_x = cx + math.cos(angle) * size
            end_y = cy + math.sin(angle) * size

            perp = angle + math.pi/2

            # 더 부드러운 팔 모양 (여러 포인트)
            # 시작점에서 끝점까지 너비가 변하는 형태
            num_segments = 5
            points_side1 = []
            points_side2 = []

            for i in range(num_segments + 1):
                t = i / num_segments
                # 너비 프로파일: 시작 좁음 -> 중간 넓음 -> 끝 뾰족
                if t < 0.5:
                    width_factor = 0.3 + t * 0.8
                else:
                    width_factor = 0.7 - (t - 0.5) * 1.0

                current_width = arm_width * max(0.1, width_factor)
                px = cx + math.cos(angle) * size * t
                py = cy + math.sin(angle) * size * t

                points_side1.append((
                    px + math.cos(perp) * current_width,
                    py + math.sin(perp) * current_width
                ))
                points_side2.insert(0, (
                    px - math.cos(perp) * current_width,
                    py - math.sin(perp) * current_width
                ))

            points = points_side1 + [(end_x, end_y)] + points_side2

            # 다중 그림자
            for offset in [3, 2]:
                shadow_pts = [(p[0] + offset, p[1] + offset) for p in points]
                pygame.draw.polygon(screen, self.colors['shadow_dark'], shadow_pts)

            # 베이스 레이어
            pygame.draw.polygon(screen, self.colors['relief_dark'], points)

            # 내부 하이라이트 레이어
            inner_points = []
            for i in range(num_segments + 1):
                t = i / num_segments
                if t < 0.5:
                    width_factor = 0.3 + t * 0.8
                else:
                    width_factor = 0.7 - (t - 0.5) * 1.0

                current_width = arm_width * max(0.05, width_factor * 0.6)
                px = cx + math.cos(angle) * size * t * 0.9 - 1
                py = cy + math.sin(angle) * size * t * 0.9 - 1

                inner_points.append((
                    px + math.cos(perp) * current_width,
                    py + math.sin(perp) * current_width
                ))
            for i in range(num_segments, -1, -1):
                t = i / num_segments
                if t < 0.5:
                    width_factor = 0.3 + t * 0.8
                else:
                    width_factor = 0.7 - (t - 0.5) * 1.0

                current_width = arm_width * max(0.05, width_factor * 0.6)
                px = cx + math.cos(angle) * size * t * 0.9 - 1
                py = cy + math.sin(angle) * size * t * 0.9 - 1

                inner_points.append((
                    px - math.cos(perp) * current_width,
                    py - math.sin(perp) * current_width
                ))

            pygame.draw.polygon(screen, self.colors['relief_mid'], inner_points)

            # 테두리
            pygame.draw.polygon(screen, self.colors['relief_light'], points, 1)

            # 팔 중심선 (2층)
            mid_len = size * 0.8
            mid_x = cx + math.cos(angle) * mid_len
            mid_y = cy + math.sin(angle) * mid_len
            pygame.draw.line(screen, self.colors['relief_light'],
                           (cx, cy), (int(mid_x), int(mid_y)), 2)
            pygame.draw.line(screen, self.colors['relief_highlight'],
                           (cx - 1, cy - 1), (int(mid_x) - 1, int(mid_y) - 1), 1)

            # 끝점 장식 - 다층
            pygame.draw.circle(screen, self.colors['shadow_dark'],
                             (int(end_x) + 2, int(end_y) + 2), 6)
            pygame.draw.circle(screen, self.colors['gold_dark'], (int(end_x), int(end_y)), 6)
            pygame.draw.circle(screen, self.colors['gold_mid'], (int(end_x), int(end_y)), 5)
            pygame.draw.circle(screen, self.colors['gold_light'], (int(end_x) - 1, int(end_y) - 1), 4)
            pygame.draw.circle(screen, self.colors['gold_highlight'], (int(end_x) - 1, int(end_y) - 1), 2)

        # 대각선 보조 장식 (4개)
        for angle in [math.pi/4, 3*math.pi/4, 5*math.pi/4, 7*math.pi/4]:
            diag_len = size * 0.5
            dx = math.cos(angle) * diag_len
            dy = math.sin(angle) * diag_len

            # 작은 삼각형 장식
            tip_x = cx + dx
            tip_y = cy + dy
            perp = angle + math.pi/2
            base_dist = diag_len * 0.3
            base_x = cx + math.cos(angle) * base_dist
            base_y = cy + math.sin(angle) * base_dist
            width = diag_len * 0.15

            tri_points = [
                (tip_x, tip_y),
                (base_x + math.cos(perp) * width, base_y + math.sin(perp) * width),
                (base_x - math.cos(perp) * width, base_y - math.sin(perp) * width)
            ]

            pygame.draw.polygon(screen, self.colors['engrave_light'], tri_points)
            pygame.draw.polygon(screen, self.colors['relief_dark'], tri_points, 1)

        # 중심 원 - 다층 그라데이션
        center_sizes = [(0.4, 'shadow_dark', 2, 2),
                       (0.38, 'relief_dark', 0, 0),
                       (0.32, 'relief_mid', -1, -1),
                       (0.26, 'relief_light', -1, -1),
                       (0.2, 'relief_highlight', -1, -1)]

        for ratio, color_key, ox, oy in center_sizes:
            pygame.draw.circle(screen, self.colors[color_key],
                             (cx + ox, cy + oy), int(size * ratio))

        # 중심 금색 장식
        pygame.draw.circle(screen, self.colors['gold_dark'], (cx, cy), int(size * 0.18))
        pygame.draw.circle(screen, self.colors['gold_mid'], (cx, cy), int(size * 0.14))
        pygame.draw.circle(screen, self.colors['gold_light'], (cx - 1, cy - 1), int(size * 0.1))
        pygame.draw.circle(screen, self.colors['gold_highlight'], (cx - 1, cy - 1), int(size * 0.05))

        # 중심에 작은 십자
        tiny_len = size * 0.08
        for angle in [0, math.pi/2, math.pi, math.pi*1.5]:
            tx = cx + math.cos(angle) * tiny_len
            ty = cy + math.sin(angle) * tiny_len
            pygame.draw.line(screen, self.colors['star_white'],
                           (cx, cy), (int(tx), int(ty)), 1)

    def _draw_connection_line_simple(self, screen: pygame.Surface, x1: int, y1: int,
                                      x2: int, y2: int):
        """노드 간 수직 연결 라인 (간단한)"""
        # 그림자
        pygame.draw.line(screen, self.colors['shadow_dark'],
                        (x1 + 1, y1 + 1), (x2 + 1, y2 + 1), 2)

        # 메인 라인
        pygame.draw.line(screen, self.colors['engrave_dark'], (x1, y1), (x2, y2), 2)
        pygame.draw.line(screen, self.colors['engrave_light'], (x1, y1), (x2, y2), 1)

    def _draw_horizontal_connection(self, screen: pygame.Surface, x1: int, x2: int, y: int):
        """열 간 수평 연결 라인"""
        # 그림자
        pygame.draw.line(screen, self.colors['shadow_dark'],
                        (x1 + 1, y + 1), (x2 + 1, y + 1), 2)

        # 메인 라인
        pygame.draw.line(screen, self.colors['engrave_dark'], (x1, y), (x2, y), 2)
        pygame.draw.line(screen, self.colors['engrave_light'], (x1, y), (x2, y), 1)

        # 중간 장식 점
        mid_x = (x1 + x2) // 2
        pygame.draw.circle(screen, self.colors['relief_dark'], (mid_x + 1, y + 1), 2)
        pygame.draw.circle(screen, self.colors['relief_light'], (mid_x, y), 2)

    def _draw_golden_borders(self, screen: pygame.Surface):
        """금색 테두리 장식"""
        if self.game_x > 5:
            pygame.draw.line(screen, self.colors['shadow_dark'],
                           (self.game_x - 1, self.game_y + 2),
                           (self.game_x - 1, self.game_y + self.game_height + 2), 4)
            pygame.draw.line(screen, self.colors['gold_dark'],
                           (self.game_x - 2, self.game_y),
                           (self.game_x - 2, self.game_y + self.game_height), 3)
            pygame.draw.line(screen, self.colors['gold_light'],
                           (self.game_x - 3, self.game_y),
                           (self.game_x - 3, self.game_y + self.game_height), 1)

        right_edge = self.game_x + self.game_width
        if self.screen_width - right_edge > 5:
            pygame.draw.line(screen, self.colors['shadow_dark'],
                           (right_edge + 3, self.game_y + 2),
                           (right_edge + 3, self.game_y + self.game_height + 2), 4)
            pygame.draw.line(screen, self.colors['gold_dark'],
                           (right_edge + 1, self.game_y),
                           (right_edge + 1, self.game_y + self.game_height), 3)
            pygame.draw.line(screen, self.colors['gold_light'],
                           (right_edge + 2, self.game_y),
                           (right_edge + 2, self.game_y + self.game_height), 1)

    def resize(self, screen_width: int, screen_height: int,
               game_width: int, game_height: int):
        """화면 크기 변경"""
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.game_width = game_width
        self.game_height = game_height
        self.game_x = (screen_width - game_width) // 2
        self.game_y = (screen_height - game_height) // 2

        # 연꽃과 별빛 재초기화
        self._init_stars()
        self._init_floating_lotuses()
        self.petals = []

        # 캐시 초기화 (다음 draw에서 재생성됨)
        self._pattern_cache_left = None
        self._pattern_cache_right = None

        # 액자 프레임 및 배경 캐시 재생성
        self._create_frame()
        self._create_bg_cache()

    def trigger_excitement(self, level: float = 1.5):
        """게임 이벤트에 반응 - 꽃가루 생성"""
        for lotus in self.floating_lotuses:
            self._spawn_petals(lotus['x'], lotus['y'], int(level * 5))


# 전역 인스턴스
_temple_bg = None


def init_temple_background(screen_width: int, screen_height: int,
                           game_width: int, game_height: int) -> TemplePillarBackground:
    global _temple_bg
    _temple_bg = TemplePillarBackground(screen_width, screen_height, game_width, game_height)
    return _temple_bg


def get_temple_background() -> TemplePillarBackground:
    return _temple_bg
