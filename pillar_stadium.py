# -*- coding: utf-8 -*-
"""
조선시대 스타일 액자 필러 배경 (Stage 1)
게임 화면 주변을 전통 한국 자수/단청 스타일의 액자 테두리로 장식
"""

import math
import random
import pygame


class TraditionalFrame:
    """조선시대 스타일 액자 테두리"""

    # 전통 색상 팔레트
    COLORS = {
        'red': (235, 220, 195),       # 연한 베이지색 (한지 느낌)
        'deep_red': (210, 195, 170),  # 진한 베이지
        'gold': (200, 160, 80),       # 금색
        'bright_gold': (230, 190, 100),
        'dark_gold': (160, 120, 50),
        'green': (60, 100, 60),       # 녹색
        'blue': (50, 80, 130),        # 청색
        'cream': (245, 235, 210),     # 미색
        'brown': (100, 70, 45),       # 갈색
        'black': (30, 25, 20),        # 먹색
        'white': (250, 245, 235),     # 백색
    }

    def __init__(self, screen_width: int, screen_height: int,
                 game_width: int, game_height: int):
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.game_width = game_width
        self.game_height = game_height

        # 게임 영역 위치
        self.game_x = (screen_width - game_width) // 2
        self.game_y = (screen_height - game_height) // 2

        # 애니메이션
        self.time = 0.0

        # 나비 애니메이션
        self.butterflies = []
        self._create_butterflies()

        # 꽃잎 파티클
        self.petals = []

        # 캐시된 프레임
        self._frame_surface = None
        self._create_frame()

        # 나비 -> 플레이어 흡수 시스템
        self._player_rect = None  # 플레이어 위치 (게임 좌표)
        self._butterfly_flying_to_player = None  # 플레이어에게 날아가는 나비
        self._butterfly_absorbed = False  # 나비가 흡수되었는지
        self._butterfly_cooldown = random.uniform(20.0, 40.0)  # 첫 나비는 20~40초 후 등장
        self._butterfly_cooldown_max = 40.0  # 쿨타임 20~40초 사이 랜덤
        self._absorption_particles = []  # 흡수 빛 파티클
        self._gauge_recovered = False  # 게이지 회복 완료 플래그 (pingfighter.py에서 확인)
        self._butterflies_absorbed_count = 0  # 흡수된 나비 수 (최대 4마리)
        # 나비 흡수 애니메이션 (1초간 신비한 빛)
        self._absorbing_butterfly = None  # 흡수 중인 나비 정보
        self._absorbing_timer = 0.0  # 흡수 애니메이션 타이머 (1초)
        self._absorbing_duration = 1.0  # 흡수 애니메이션 지속 시간

    def _create_butterflies(self):
        """나비 생성"""
        num_butterflies = 4
        positions = [
            (self.game_x // 2, self.screen_height // 3),
            (self.game_x // 2, self.screen_height * 2 // 3),
            (self.screen_width - self.game_x // 2, self.screen_height // 3),
            (self.screen_width - self.game_x // 2, self.screen_height * 2 // 3),
        ]

        # [DEBUG] 나비 생성 디버그
        print(f"[나비생성] screen: {self.screen_width}x{self.screen_height}, game: {self.game_width}x{self.game_height}, offset: ({self.game_x}, {self.game_y})")

        for i, (x, y) in enumerate(positions):
            if self.game_x > 80:  # 충분한 공간이 있을 때만
                self.butterflies.append({
                    'x': x,
                    'y': y,
                    'base_x': x,
                    'base_y': y,
                    'phase': random.uniform(0, math.pi * 2),
                    'wing_speed': random.uniform(8, 12),
                    'color': random.choice(['blue', 'gold', 'red']),
                    'size': random.uniform(0.8, 1.2),
                })
            else:
                print(f"[나비생성] 실패! game_x={self.game_x} <= 80 (공간 부족)")

        print(f"[나비생성] 완료: {len(self.butterflies)}마리 생성됨")

    def _create_frame(self):
        """전통 액자 프레임 생성"""
        self._frame_surface = pygame.Surface(
            (self.screen_width, self.screen_height), pygame.SRCALPHA
        )

        # 배경 (주홍색 비단)
        self._draw_silk_background(self._frame_surface)

        # 외곽 금테
        self._draw_outer_gold_border(self._frame_surface)

        # 내곽 금테 (게임 영역 주변)
        self._draw_inner_gold_border(self._frame_surface)

        # 모서리 장식 (전통 문양)
        self._draw_corner_ornaments(self._frame_surface)

        # 꽃 자수 장식
        self._draw_flower_embroidery(self._frame_surface)

        # 나뭇가지 장식
        self._draw_branch_decoration(self._frame_surface)

    def _draw_silk_background(self, surface: pygame.Surface):
        """한지(韓紙) 질감 배경"""
        # 한지 기본 색상 (어두운 베이지)
        base_color = (130, 115, 95)  # 더 어두운 한지색

        # 전체 채우기
        surface.fill((*base_color, 255))

        # 게임 영역은 투명하게 (나중에 게임이 그려짐)
        game_rect = pygame.Rect(self.game_x, self.game_y, self.game_width, self.game_height)
        pygame.draw.rect(surface, (0, 0, 0, 0), game_rect)

    def _draw_outer_gold_border(self, surface: pygame.Surface):
        """외곽 금테두리"""
        border_width = 12
        gold = self.COLORS['gold']
        bright_gold = self.COLORS['bright_gold']
        dark_gold = self.COLORS['dark_gold']

        # 외곽 테두리 (그라데이션 효과)
        for i in range(border_width):
            t = i / border_width
            if t < 0.3:
                color = dark_gold
            elif t < 0.7:
                color = gold
            else:
                color = bright_gold

            rect = pygame.Rect(i, i, self.screen_width - i * 2, self.screen_height - i * 2)
            pygame.draw.rect(surface, (*color, 255), rect, 1)

        # 금박 점 장식
        for i in range(0, self.screen_width, 25):
            pygame.draw.circle(surface, (*bright_gold, 200), (i, 6), 2)
            pygame.draw.circle(surface, (*bright_gold, 200), (i, self.screen_height - 6), 2)

        for i in range(0, self.screen_height, 25):
            pygame.draw.circle(surface, (*bright_gold, 200), (6, i), 2)
            pygame.draw.circle(surface, (*bright_gold, 200), (self.screen_width - 6, i), 2)

    def _draw_inner_gold_border(self, surface: pygame.Surface):
        """내곽 금테두리 (게임 영역 주변)"""
        margin = 8
        border_width = 10

        gold = self.COLORS['gold']
        bright_gold = self.COLORS['bright_gold']
        dark_gold = self.COLORS['dark_gold']

        # 내곽 테두리
        inner_rect = pygame.Rect(
            self.game_x - margin - border_width,
            self.game_y - margin - border_width,
            self.game_width + (margin + border_width) * 2,
            self.game_height + (margin + border_width) * 2
        )

        # 그라데이션 테두리
        for i in range(border_width):
            t = i / border_width
            if t < 0.3:
                color = bright_gold
            elif t < 0.7:
                color = gold
            else:
                color = dark_gold

            rect = inner_rect.inflate(-i * 2, -i * 2)
            pygame.draw.rect(surface, (*color, 255), rect, 1)

        # 금박 연속 문양 (번개 문양 스타일)
        self._draw_thunder_pattern(surface, inner_rect)

    def _draw_thunder_pattern(self, surface: pygame.Surface, rect: pygame.Rect):
        """번개 문양 (뇌문)"""
        gold = self.COLORS['bright_gold']
        pattern_size = 15

        # 상단
        for x in range(rect.left + 20, rect.right - 20, pattern_size * 2):
            self._draw_single_thunder(surface, x, rect.top - 5, gold, 0.7)

        # 하단
        for x in range(rect.left + 20, rect.right - 20, pattern_size * 2):
            self._draw_single_thunder(surface, x, rect.bottom - 5, gold, 0.7)

        # 좌측
        for y in range(rect.top + 20, rect.bottom - 20, pattern_size * 2):
            self._draw_single_thunder(surface, rect.left - 5, y, gold, 0.7, vertical=True)

        # 우측
        for y in range(rect.top + 20, rect.bottom - 20, pattern_size * 2):
            self._draw_single_thunder(surface, rect.right - 5, y, gold, 0.7, vertical=True)

    def _draw_single_thunder(self, surface: pygame.Surface, x: int, y: int,
                             color: tuple, scale: float, vertical: bool = False):
        """단일 번개 문양"""
        s = int(8 * scale)

        if not vertical:
            points = [
                (x, y), (x + s, y), (x + s, y + s//2),
                (x + s//2, y + s//2), (x + s//2, y + s),
                (x, y + s), (x, y + s//2), (x + s//2, y + s//2),
                (x + s//2, y)
            ]
        else:
            points = [
                (x, y), (x, y + s), (x + s//2, y + s),
                (x + s//2, y + s//2), (x + s, y + s//2),
                (x + s, y), (x + s//2, y), (x + s//2, y + s//2),
                (x, y + s//2)
            ]

        if len(points) >= 3:
            pygame.draw.polygon(surface, (*color, 180), points, 1)

    def _draw_corner_ornaments(self, surface: pygame.Surface):
        """모서리 장식 (전통 문양)"""
        gold = self.COLORS['bright_gold']
        ornament_size = min(60, self.game_x - 30, self.game_y - 30)

        if ornament_size < 20:
            return

        corners = [
            (self.game_x - 15, self.game_y - 15, 0),           # 좌상
            (self.game_x + self.game_width + 15, self.game_y - 15, 90),  # 우상
            (self.game_x - 15, self.game_y + self.game_height + 15, 270),  # 좌하
            (self.game_x + self.game_width + 15, self.game_y + self.game_height + 15, 180),  # 우하
        ]

        for cx, cy, rotation in corners:
            self._draw_corner_flower(surface, cx, cy, ornament_size, gold, rotation)

    def _draw_corner_flower(self, surface: pygame.Surface, cx: int, cy: int,
                            size: int, color: tuple, rotation: int):
        """모서리 꽃 문양"""
        # 중심 원
        pygame.draw.circle(surface, (*color, 220), (cx, cy), size // 4)
        pygame.draw.circle(surface, (*self.COLORS['red'], 200), (cx, cy), size // 6)

        # 꽃잎 (8방향)
        for i in range(8):
            angle = math.radians(rotation + i * 45)
            petal_x = cx + int(size * 0.4 * math.cos(angle))
            petal_y = cy + int(size * 0.4 * math.sin(angle))

            # 꽃잎 (타원)
            petal_surface = pygame.Surface((size // 2, size // 3), pygame.SRCALPHA)
            pygame.draw.ellipse(petal_surface, (*color, 180),
                              (0, 0, size // 2, size // 3))

            # 회전 및 배치
            rotated = pygame.transform.rotate(petal_surface, -math.degrees(angle))
            rect = rotated.get_rect(center=(petal_x, petal_y))
            surface.blit(rotated, rect)

        # 외곽 고리
        pygame.draw.circle(surface, (*color, 150), (cx, cy), size // 2, 2)

    def _draw_flower_embroidery(self, surface: pygame.Surface):
        """꽃 자수 장식"""
        # 좌우 필러에 꽃 배치
        if self.game_x < 80:
            return

        flower_positions = []

        # 좌측 꽃들
        left_center = self.game_x // 2
        flower_positions.extend([
            (left_center, self.game_y + 100),
            (left_center - 20, self.game_y + self.game_height // 2),
            (left_center + 15, self.game_y + self.game_height - 150),
        ])

        # 우측 꽃들
        right_center = self.screen_width - self.game_x // 2
        flower_positions.extend([
            (right_center, self.game_y + 150),
            (right_center + 20, self.game_y + self.game_height // 2 + 50),
            (right_center - 15, self.game_y + self.game_height - 100),
        ])

        for x, y in flower_positions:
            self._draw_embroidery_flower(surface, x, y)

    def _draw_embroidery_flower(self, surface: pygame.Surface, x: int, y: int):
        """자수 스타일 꽃"""
        # 꽃 크기
        size = random.randint(25, 40)

        # 꽃잎 색상 (연보라, 분홍 계열)
        petal_colors = [
            (200, 180, 210),  # 연보라
            (220, 190, 200),  # 연분홍
            (210, 200, 220),  # 회보라
        ]
        petal_color = random.choice(petal_colors)

        # 5개 꽃잎
        for i in range(5):
            angle = math.radians(i * 72 - 90)
            px = x + int(size * 0.5 * math.cos(angle))
            py = y + int(size * 0.5 * math.sin(angle))

            # 꽃잎 (원)
            pygame.draw.circle(surface, (*petal_color, 230), (px, py), size // 3)

            # 꽃잎 테두리 (자수 느낌)
            pygame.draw.circle(surface, (petal_color[0] - 30, petal_color[1] - 30, petal_color[2] - 30, 200),
                             (px, py), size // 3, 1)

            # 꽃잎 중심선
            inner_x = x + int(size * 0.25 * math.cos(angle))
            inner_y = y + int(size * 0.25 * math.sin(angle))
            pygame.draw.line(surface, (petal_color[0] - 40, petal_color[1] - 40, petal_color[2] - 40, 150),
                           (x, y), (inner_x, inner_y), 1)

        # 꽃 중심 (노란색)
        pygame.draw.circle(surface, (*self.COLORS['gold'], 255), (x, y), size // 5)
        pygame.draw.circle(surface, (*self.COLORS['bright_gold'], 200), (x, y), size // 7)

    def _draw_branch_decoration(self, surface: pygame.Surface):
        """나뭇가지 장식"""
        if self.game_x < 60:
            return

        brown = self.COLORS['brown']
        green = self.COLORS['green']
        gold = self.COLORS['dark_gold']

        # 좌측 나뭇가지
        self._draw_branch(surface, 30, self.game_y + 50, self.game_x - 40,
                         self.game_height // 2, brown, green, gold, flip=False)

        # 우측 나뭇가지
        self._draw_branch(surface, self.screen_width - 30, self.game_y + 80,
                         -(self.game_x - 40), self.game_height // 2 - 30,
                         brown, green, gold, flip=True)

    def _draw_branch(self, surface: pygame.Surface, start_x: int, start_y: int,
                    width: int, height: int, branch_color: tuple,
                    leaf_color: tuple, accent_color: tuple, flip: bool = False):
        """개별 나뭇가지"""
        # 메인 가지
        points = []
        segments = 8
        for i in range(segments + 1):
            t = i / segments
            x = start_x + int(width * t * (1 if not flip else 1))
            y = start_y + int(height * t) + int(math.sin(t * math.pi * 2) * 20)
            points.append((x, y))

        # 가지 그리기
        if len(points) >= 2:
            pygame.draw.lines(surface, (*branch_color, 230), False, points, 3)

            # 잎사귀
            for i, (px, py) in enumerate(points[1:-1]):
                if random.random() < 0.6:
                    leaf_angle = random.uniform(-0.5, 0.5) + (0.3 if not flip else -0.3)
                    self._draw_leaf(surface, px, py, leaf_color, leaf_angle)

    def _draw_leaf(self, surface: pygame.Surface, x: int, y: int,
                  color: tuple, angle: float):
        """잎사귀"""
        leaf_length = random.randint(12, 20)
        leaf_width = leaf_length // 3

        # 잎 모양 (타원)
        leaf_surf = pygame.Surface((leaf_length, leaf_width * 2), pygame.SRCALPHA)
        pygame.draw.ellipse(leaf_surf, (*color, 200), (0, 0, leaf_length, leaf_width * 2))

        # 잎맥
        pygame.draw.line(leaf_surf, (color[0] - 20, color[1] + 20, color[2] - 10, 150),
                        (2, leaf_width), (leaf_length - 2, leaf_width), 1)

        # 회전
        rotated = pygame.transform.rotate(leaf_surf, math.degrees(angle))
        rect = rotated.get_rect(center=(x, y))
        surface.blit(rotated, rect)

    def _draw_butterfly(self, surface: pygame.Surface, butterfly: dict, time: float):
        """나비 그리기"""
        x = butterfly['x']
        y = butterfly['y']
        phase = butterfly['phase']
        wing_speed = butterfly['wing_speed']
        size = butterfly['size']
        color_name = butterfly['color']

        # 날개 펄럭임
        wing_angle = math.sin(time * wing_speed + phase) * 0.4

        # 색상
        if color_name == 'blue':
            wing_color = (60, 100, 160)
            accent = (80, 130, 200)
        elif color_name == 'gold':
            wing_color = (200, 160, 80)
            accent = (230, 190, 100)
        else:
            wing_color = (180, 80, 80)
            accent = (220, 120, 100)

        wing_size = int(18 * size)
        body_length = int(12 * size)

        # 왼쪽 날개
        left_wing = pygame.Surface((wing_size, wing_size), pygame.SRCALPHA)
        pygame.draw.ellipse(left_wing, (*wing_color, 220), (0, 0, wing_size, wing_size * 0.7))
        pygame.draw.ellipse(left_wing, (*accent, 180), (wing_size // 4, wing_size // 6, wing_size // 2, wing_size // 3))

        # 오른쪽 날개
        right_wing = pygame.transform.flip(left_wing, True, False)

        # 날개 회전
        left_rotated = pygame.transform.rotate(left_wing, math.degrees(wing_angle) * 30)
        right_rotated = pygame.transform.rotate(right_wing, -math.degrees(wing_angle) * 30)

        # 배치
        surface.blit(left_rotated, (x - wing_size - 2, y - wing_size // 2))
        surface.blit(right_rotated, (x + 2, y - wing_size // 2))

        # 몸통
        pygame.draw.ellipse(surface, (40, 35, 30, 255),
                           (x - 3, y - body_length // 2, 6, body_length))

        # 더듬이
        pygame.draw.line(surface, (40, 35, 30, 200),
                        (x - 1, y - body_length // 2),
                        (x - 6, y - body_length // 2 - 8), 1)
        pygame.draw.line(surface, (40, 35, 30, 200),
                        (x + 1, y - body_length // 2),
                        (x + 6, y - body_length // 2 - 8), 1)

    def _spawn_petal(self):
        """꽃잎 파티클 생성"""
        if random.random() < 0.02 and len(self.petals) < 15:
            # 좌측 또는 우측 필러에서 생성
            if random.random() < 0.5 and self.game_x > 50:
                x = random.randint(20, self.game_x - 20)
            elif self.game_x > 50:
                x = random.randint(self.game_x + self.game_width + 20, self.screen_width - 20)
            else:
                return

            self.petals.append({
                'x': x,
                'y': random.randint(-20, 0),
                'vx': random.uniform(-0.5, 0.5),
                'vy': random.uniform(0.8, 1.5),
                'rotation': random.uniform(0, 360),
                'rot_speed': random.uniform(-2, 2),
                'size': random.randint(6, 10),
                'color': random.choice([
                    (255, 200, 210),
                    (255, 220, 225),
                    (250, 210, 220),
                ])
            })

    def set_player_rect(self, player_rect):
        """플레이어 위치 설정 (게임 좌표 -> 전체화면 좌표 변환)"""
        self._player_rect = player_rect
        # [DEBUG] 플레이어 위치 확인
        if player_rect and hasattr(player_rect, 'centerx'):
            if random.random() < 0.01:  # 1% 확률로 출력
                print(f"[플레이어위치] x={player_rect.centerx}, y={player_rect.centery}, game_w={self.game_width}, game_h={self.game_height}")

    def check_gauge_recovered(self) -> bool:
        """게이지 회복이 완료되었는지 확인하고 플래그 리셋"""
        if self._gauge_recovered:
            self._gauge_recovered = False
            return True
        return False

    def _select_butterfly_for_flight(self):
        """플레이어에게 날아갈 나비 선택"""
        if not self.butterflies:
            return None
        # 랜덤으로 나비 하나 선택
        return random.choice(self.butterflies)

    def _create_absorption_particles(self, x: float, y: float):
        """흡수 빛 파티클 생성"""
        for _ in range(12):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(30, 80)
            self._absorption_particles.append({
                'x': x,
                'y': y,
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed,
                'life': 1.0,
                'color': random.choice([
                    (255, 255, 200),  # 밝은 노랑
                    (255, 220, 150),  # 금빛
                    (200, 255, 255),  # 하늘색
                    (255, 200, 255),  # 분홍
                ])
            })

    def _create_mystical_light_particle(self, x: float, y: float):
        """신비한 빛 파티클 생성 (흡수 애니메이션용)"""
        # 랜덤 방향으로 천천히 퍼지는 파티클
        angle = random.uniform(0, math.pi * 2)
        speed = random.uniform(20, 60)
        self._absorption_particles.append({
            'x': x + random.uniform(-10, 10),
            'y': y + random.uniform(-10, 10),
            'vx': math.cos(angle) * speed,
            'vy': math.sin(angle) * speed,
            'life': random.uniform(0.6, 1.0),
            'color': random.choice([
                (255, 255, 220),  # 밝은 금빛
                (220, 255, 255),  # 신비한 하늘색
                (255, 230, 180),  # 따뜻한 노랑
                (200, 220, 255),  # 신비한 파랑
                (255, 210, 255),  # 신비한 분홍
            ])
        })

    def update(self, dt: float):
        """업데이트"""
        self.time += dt

        # 나비 흡수 쿨타임 감소
        if self._butterfly_cooldown > 0:
            self._butterfly_cooldown -= dt

        # 흡수 애니메이션 업데이트 (1초간 신비한 빛)
        if self._absorbing_butterfly is not None:
            self._absorbing_timer -= dt
            # 애니메이션 중 지속적으로 빛 파티클 생성
            if random.random() < 0.5:  # 50% 확률로 파티클 추가
                self._create_mystical_light_particle(
                    self._absorbing_butterfly['x'],
                    self._absorbing_butterfly['y']
                )
            # 애니메이션 완료
            if self._absorbing_timer <= 0:
                self._absorbing_butterfly = None
                # 아직 남은 나비가 있으면 쿨타임 설정 (20~40초 랜덤)
                if len(self.butterflies) > 0:
                    self._butterfly_cooldown = random.uniform(20.0, 40.0)
                    self._butterfly_cooldown_max = self._butterfly_cooldown

        # 나비 -> 플레이어 흡수 로직
        if self._butterfly_flying_to_player is not None:
            # 플레이어 위치로 날아가기 (전체화면 좌표로 변환)
            if self._player_rect is not None:
                # 플레이어 위치 유효성 검사 (게임 영역 내에 있는지)
                player_cx = self._player_rect.centerx
                player_cy = self._player_rect.centery

                # 플레이어가 유효한 위치에 있는지 확인 (게임 영역 내)
                if player_cx < 0 or player_cx > self.game_width or player_cy < 0 or player_cy > self.game_height:
                    # 플레이어 위치가 비정상 - 나비 비행 취소
                    self._butterfly_flying_to_player = None
                    self._butterfly_cooldown = 1.0  # 1초 후 재시도
                    return

                # 전체화면 좌표로 변환
                target_x = self.game_x + player_cx
                target_y = self.game_y + player_cy

                butterfly = self._butterfly_flying_to_player
                dx = target_x - butterfly['x']
                dy = target_y - butterfly['y']
                dist = math.sqrt(dx * dx + dy * dy)

                if dist > 10:
                    # 빠르게 플레이어에게 이동 (일정 속도)
                    speed = 300  # 초당 300픽셀로 고정
                    move_x = (dx / dist) * speed * dt
                    move_y = (dy / dist) * speed * dt
                    butterfly['x'] += move_x
                    butterfly['y'] += move_y
                    # 날개 펄럭임 가속 (거리가 가까울수록 빠르게)
                    butterfly['wing_speed'] = 12 + max(0, (1.0 - dist / 500) * 8)
                else:
                    # 플레이어에 도달 - 흡수 애니메이션 시작
                    self._butterfly_absorbed = True
                    self._gauge_recovered = True  # 게이지 회복 트리거
                    self._butterflies_absorbed_count += 1  # 흡수된 나비 카운트 증가
                    # 흡수 애니메이션 시작 (1초간)
                    self._absorbing_butterfly = {
                        'x': butterfly['x'],
                        'y': butterfly['y'],
                        'phase': butterfly['phase'],
                        'wing_speed': butterfly['wing_speed'],
                        'size': butterfly['size'],
                        'color': butterfly['color'],
                    }
                    self._absorbing_timer = self._absorbing_duration
                    # 초기 빛 파티클 폭발
                    self._create_absorption_particles(butterfly['x'], butterfly['y'])
                    # 나비 제거 (재생성하지 않음)
                    if butterfly in self.butterflies:
                        self.butterflies.remove(butterfly)
                    self._butterfly_flying_to_player = None
        elif self._absorbing_butterfly is None:
            # 쿨타임이 끝나면 새 나비 선택 (흡수 애니메이션 중이 아닐 때만)
            if self._butterfly_cooldown <= 0 and self._player_rect is not None and len(self.butterflies) > 0:
                # 플레이어가 유효한 위치에 있는지 확인 (여유 있게 체크)
                player_cx = self._player_rect.centerx
                player_cy = self._player_rect.centery
                # 플레이어가 게임 영역 근처에만 있으면 OK (±50픽셀 여유)
                if -50 <= player_cx <= self.game_width + 50 and -50 <= player_cy <= self.game_height + 50:
                    self._butterfly_flying_to_player = self._select_butterfly_for_flight()
                    if self._butterfly_flying_to_player:
                        self._butterfly_absorbed = False
                        print(f"[나비비행] 시작! 플레이어: ({player_cx}, {player_cy}), 나비: ({self._butterfly_flying_to_player['x']:.0f}, {self._butterfly_flying_to_player['y']:.0f})")

        # 흡수 파티클 업데이트
        for p in self._absorption_particles[:]:
            p['x'] += p['vx'] * dt
            p['y'] += p['vy'] * dt
            p['vx'] *= 0.95  # 감속
            p['vy'] *= 0.95
            p['life'] -= dt * 2
            if p['life'] <= 0:
                self._absorption_particles.remove(p)

        # 일반 나비 움직임 (날아가는 나비 제외)
        for b in self.butterflies:
            if b != self._butterfly_flying_to_player:
                b['x'] = b['base_x'] + math.sin(self.time * 0.5 + b['phase']) * 15
                b['y'] = b['base_y'] + math.cos(self.time * 0.3 + b['phase']) * 10

        # 꽃잎 파티클
        self._spawn_petal()
        for p in self.petals[:]:
            p['x'] += p['vx'] + math.sin(self.time * 2 + p['rotation'] * 0.1) * 0.3
            p['y'] += p['vy']
            p['rotation'] += p['rot_speed']

            if p['y'] > self.screen_height + 20:
                self.petals.remove(p)

    def _respawn_butterfly(self, old_butterfly: dict):
        """나비 다시 생성 (기존 위치에)"""
        self.butterflies.append({
            'x': old_butterfly['base_x'],
            'y': old_butterfly['base_y'],
            'base_x': old_butterfly['base_x'],
            'base_y': old_butterfly['base_y'],
            'phase': random.uniform(0, math.pi * 2),
            'wing_speed': random.uniform(8, 12),
            'color': random.choice(['blue', 'gold', 'red']),
            'size': random.uniform(0.8, 1.2),
        })

    def _draw_petal(self, surface: pygame.Surface, petal: dict):
        """꽃잎 파티클 그리기"""
        petal_surf = pygame.Surface((petal['size'] * 2, petal['size']), pygame.SRCALPHA)
        pygame.draw.ellipse(petal_surf, (*petal['color'], 200),
                           (0, 0, petal['size'] * 2, petal['size']))

        rotated = pygame.transform.rotate(petal_surf, petal['rotation'])
        rect = rotated.get_rect(center=(int(petal['x']), int(petal['y'])))
        surface.blit(rotated, rect)

    def _draw_absorption_particle(self, surface: pygame.Surface, particle: dict):
        """흡수 빛 파티클 그리기"""
        alpha = int(255 * particle['life'])
        size = int(6 * particle['life'] + 2)
        color = particle['color']

        # 빛나는 효과
        glow_surf = pygame.Surface((size * 4, size * 4), pygame.SRCALPHA)
        for i in range(3):
            glow_alpha = int(alpha * (0.3 - i * 0.1))
            if glow_alpha > 0:
                pygame.draw.circle(glow_surf, (*color, glow_alpha),
                                 (size * 2, size * 2), size + i * 2)
        pygame.draw.circle(glow_surf, (*color, alpha), (size * 2, size * 2), size)

        rect = glow_surf.get_rect(center=(int(particle['x']), int(particle['y'])))
        surface.blit(glow_surf, rect)

    def _draw_flying_butterfly_trail(self, surface: pygame.Surface, butterfly: dict):
        """날아가는 나비의 빛나는 꼬리 그리기"""
        if butterfly is None:
            return

        # 나비 좌표 검증
        try:
            bx = butterfly.get('x', 0)
            by = butterfly.get('y', 0)
            if bx is None or by is None:
                return
            bx = int(bx)
            by = int(by)
            # 화면 범위 검증
            if not (-1000 < bx < 10000 and -1000 < by < 10000):
                return
        except (TypeError, ValueError):
            return

        # 빛나는 꼬리 효과
        trail_colors = [
            (255, 255, 200, 100),
            (255, 220, 150, 80),
            (200, 255, 255, 60),
        ]
        for i, color in enumerate(trail_colors):
            offset = (i + 1) * 8
            trail_x = bx - int(offset * 0.5)
            trail_y = by
            size = 10 - i * 2
            if size <= 0:
                continue
            trail_surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
            pygame.draw.circle(trail_surf, color, (size, size), size)
            surface.blit(trail_surf, (trail_x - size, trail_y - size))

    def _draw_absorbing_butterfly(self, surface: pygame.Surface):
        """흡수 중인 나비 그리기 (1초간 신비한 빛과 함께 사라짐)"""
        if self._absorbing_butterfly is None:
            return

        # 남은 시간 비율 (1.0 -> 0.0)
        progress = self._absorbing_timer / self._absorbing_duration
        if progress <= 0:
            return

        butterfly = self._absorbing_butterfly
        x = int(butterfly['x'])
        y = int(butterfly['y'])
        phase = butterfly['phase']
        wing_speed = butterfly['wing_speed']
        size = butterfly['size']
        color_name = butterfly['color']

        # 날개 펄럭임 (점점 빨라짐)
        accelerated_wing_speed = wing_speed * (2.0 - progress)  # 빨라지는 날개
        wing_angle = math.sin(self.time * accelerated_wing_speed + phase) * 0.4

        # 색상
        if color_name == 'blue':
            wing_color = (60, 100, 160)
            accent = (80, 130, 200)
        elif color_name == 'gold':
            wing_color = (200, 160, 80)
            accent = (230, 190, 100)
        else:
            wing_color = (180, 80, 80)
            accent = (220, 120, 100)

        # 페이드아웃 알파값 (점점 투명해짐)
        alpha = int(255 * progress)

        wing_size = int(18 * size)
        body_length = int(12 * size)

        # 신비한 빛 후광 효과 (여러 레이어)
        glow_colors = [
            (255, 255, 220),  # 밝은 금빛
            (220, 255, 255),  # 신비한 하늘색
            (255, 230, 180),  # 따뜻한 노랑
        ]

        # 맥동하는 빛 효과 (점점 커지면서 사라짐)
        pulse = 1.0 + math.sin(self.time * 10) * 0.2  # 빠른 맥동
        glow_size = int(40 * (2.0 - progress) * pulse)  # 점점 커지는 후광

        for i, glow_color in enumerate(glow_colors):
            layer_size = glow_size + i * 15
            glow_alpha = int(alpha * (0.4 - i * 0.1))
            if glow_alpha > 0 and layer_size > 0:
                glow_surf = pygame.Surface((layer_size * 2, layer_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (*glow_color, glow_alpha),
                                 (layer_size, layer_size), layer_size)
                surface.blit(glow_surf, (x - layer_size, y - layer_size))

        # 회전하는 빛 입자들
        num_light_particles = 8
        for i in range(num_light_particles):
            angle = (self.time * 3 + i * (math.pi * 2 / num_light_particles))
            radius = 25 * (2.0 - progress)  # 점점 커지는 반경
            px = x + int(math.cos(angle) * radius)
            py = y + int(math.sin(angle) * radius)
            particle_size = int(4 * progress)
            if particle_size > 0:
                particle_alpha = int(200 * progress)
                particle_surf = pygame.Surface((particle_size * 2, particle_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(particle_surf, (255, 255, 255, particle_alpha),
                                 (particle_size, particle_size), particle_size)
                surface.blit(particle_surf, (px - particle_size, py - particle_size))

        # 나비 본체 (페이드아웃)
        # 왼쪽 날개
        left_wing = pygame.Surface((wing_size, wing_size), pygame.SRCALPHA)
        pygame.draw.ellipse(left_wing, (*wing_color, alpha), (0, 0, wing_size, int(wing_size * 0.7)))
        pygame.draw.ellipse(left_wing, (*accent, int(alpha * 0.8)), (wing_size // 4, wing_size // 6, wing_size // 2, wing_size // 3))

        # 오른쪽 날개
        right_wing = pygame.transform.flip(left_wing, True, False)

        # 날개 회전
        left_rotated = pygame.transform.rotate(left_wing, math.degrees(wing_angle) * 30)
        right_rotated = pygame.transform.rotate(right_wing, -math.degrees(wing_angle) * 30)

        # 배치
        surface.blit(left_rotated, (x - wing_size - 2, y - wing_size // 2))
        surface.blit(right_rotated, (x + 2, y - wing_size // 2))

        # 몸통
        body_surf = pygame.Surface((10, body_length + 4), pygame.SRCALPHA)
        pygame.draw.ellipse(body_surf, (40, 35, 30, alpha), (2, 2, 6, body_length))
        surface.blit(body_surf, (x - 5, y - body_length // 2 - 2))

    def draw(self, surface: pygame.Surface):
        """전체 렌더링"""
        # 캐시된 프레임
        if self._frame_surface:
            surface.blit(self._frame_surface, (0, 0))

        # 꽃잎 파티클
        for petal in self.petals:
            self._draw_petal(surface, petal)

        # 나비 애니메이션
        for butterfly in self.butterflies:
            self._draw_butterfly(surface, butterfly, self.time)

        # 날아가는 나비의 빛나는 꼬리
        if self._butterfly_flying_to_player is not None:
            self._draw_flying_butterfly_trail(surface, self._butterfly_flying_to_player)

        # 흡수 중인 나비 (신비한 빛과 함께 사라짐)
        self._draw_absorbing_butterfly(surface)

        # 흡수 빛 파티클
        for particle in self._absorption_particles:
            self._draw_absorption_particle(surface, particle)

        # 게임 영역 테두리 광택
        self._draw_game_border_shine(surface)

    def _draw_game_border_shine(self, surface: pygame.Surface):
        """게임 영역 테두리 광택 효과"""
        shine = int(30 + 15 * math.sin(self.time * 2))
        gold = self.COLORS['bright_gold']

        # 금테 광택
        for i in range(3):
            alpha = shine - i * 10
            if alpha > 0:
                rect = pygame.Rect(
                    self.game_x - 8 - i,
                    self.game_y - 8 - i,
                    self.game_width + 16 + i * 2,
                    self.game_height + 16 + i * 2
                )
                pygame.draw.rect(surface, (*gold, alpha), rect, 1)

    def resize(self, screen_width: int, screen_height: int,
               game_width: int, game_height: int):
        """화면 크기 변경"""
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.game_width = game_width
        self.game_height = game_height

        self.game_x = (screen_width - game_width) // 2
        self.game_y = (screen_height - game_height) // 2

        self.butterflies = []
        self._create_butterflies()

        self._frame_surface = None
        self._create_frame()

    def trigger_excitement(self, level: float = 1.5):
        """효과 트리거 (득점 시)"""
        # 꽃잎 대량 생성
        for _ in range(8):
            self._spawn_petal()

    def get_flying_butterfly_for_ingame(self):
        """게임 화면에 그릴 날아가는 나비 정보 반환 (게임 좌표계)

        Returns:
            dict or None: 나비 정보 (게임 좌표로 변환됨) 또는 None
        """
        if self._butterfly_flying_to_player is None:
            return None

        butterfly = self._butterfly_flying_to_player
        # 전체화면 좌표 -> 게임 좌표로 변환
        game_x = butterfly['x'] - self.game_x
        game_y = butterfly['y'] - self.game_y

        # 게임 영역 안에 들어왔을 때만 반환
        if game_x >= -50 and game_x <= self.game_width + 50:
            return {
                'x': game_x,
                'y': game_y,
                'phase': butterfly['phase'],
                'wing_speed': butterfly['wing_speed'],
                'size': butterfly['size'],
                'color': butterfly['color'],
            }
        return None

    def draw_flying_butterfly_ingame(self, screen, game_width, game_height):
        """게임 화면에 날아가는 나비 그리기 (게임 좌표계)

        Args:
            screen: 게임 화면 surface
            game_width: 게임 영역 너비
            game_height: 게임 영역 높이
        """
        butterfly_info = self.get_flying_butterfly_for_ingame()
        if butterfly_info is None:
            return

        x = butterfly_info['x']
        y = butterfly_info['y']

        # 화면 밖이면 그리지 않음
        if x < -50 or x > game_width + 50 or y < -50 or y > game_height + 50:
            return

        # 나비 그리기
        phase = butterfly_info['phase']
        wing_speed = butterfly_info['wing_speed']
        size = butterfly_info['size']
        color_name = butterfly_info['color']

        # 날개 펄럭임
        wing_angle = math.sin(self.time * wing_speed + phase) * 0.4

        # 색상
        if color_name == 'blue':
            wing_color = (60, 100, 160)
            accent = (80, 130, 200)
        elif color_name == 'gold':
            wing_color = (200, 160, 80)
            accent = (230, 190, 100)
        else:
            wing_color = (180, 80, 80)
            accent = (220, 120, 100)

        wing_size = int(18 * size)
        body_length = int(12 * size)

        # 왼쪽 날개
        left_wing = pygame.Surface((wing_size, wing_size), pygame.SRCALPHA)
        pygame.draw.ellipse(left_wing, (*wing_color, 220), (0, 0, wing_size, wing_size * 0.7))
        pygame.draw.ellipse(left_wing, (*accent, 180), (wing_size // 4, wing_size // 6, wing_size // 2, wing_size // 3))

        # 오른쪽 날개
        right_wing = pygame.transform.flip(left_wing, True, False)

        # 날개 회전
        left_rotated = pygame.transform.rotate(left_wing, math.degrees(wing_angle) * 30)
        right_rotated = pygame.transform.rotate(right_wing, -math.degrees(wing_angle) * 30)

        # 빛나는 꼬리 효과
        trail_colors = [
            (255, 255, 200, 100),
            (255, 220, 150, 80),
            (200, 255, 255, 60),
        ]
        for i, color in enumerate(trail_colors):
            offset = (i + 1) * 8
            trail_x = int(x) - int(offset * 0.5)
            trail_y = int(y)
            trail_size = 10 - i * 2
            if trail_size > 0:
                trail_surf = pygame.Surface((trail_size * 2, trail_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(trail_surf, color, (trail_size, trail_size), trail_size)
                screen.blit(trail_surf, (trail_x - trail_size, trail_y - trail_size))

        # 나비 배치
        screen.blit(left_rotated, (int(x) - wing_size - 2, int(y) - wing_size // 2))
        screen.blit(right_rotated, (int(x) + 2, int(y) - wing_size // 2))

        # 몸통
        pygame.draw.ellipse(screen, (40, 35, 30, 255),
                           (int(x) - 3, int(y) - body_length // 2, 6, body_length))

        # 더듬이
        pygame.draw.line(screen, (40, 35, 30, 200),
                        (int(x) - 1, int(y) - body_length // 2),
                        (int(x) - 6, int(y) - body_length // 2 - 8), 1)
        pygame.draw.line(screen, (40, 35, 30, 200),
                        (int(x) + 1, int(y) - body_length // 2),
                        (int(x) + 6, int(y) - body_length // 2 - 8), 1)

    def get_absorption_particles_for_ingame(self):
        """게임 화면에 그릴 흡수 파티클 정보 반환 (게임 좌표계)

        Returns:
            list: 파티클 정보 리스트 (게임 좌표로 변환됨)
        """
        particles = []
        for p in self._absorption_particles:
            game_x = p['x'] - self.game_x
            game_y = p['y'] - self.game_y
            particles.append({
                'x': game_x,
                'y': game_y,
                'life': p['life'],
                'color': p['color'],
            })
        return particles

    def draw_absorption_particles_ingame(self, screen):
        """게임 화면에 흡수 파티클 그리기 (게임 좌표계)"""
        for p in self.get_absorption_particles_for_ingame():
            alpha = int(255 * p['life'])
            size = int(6 * p['life'] + 2)
            color = p['color']

            if size <= 0 or alpha <= 0:
                continue

            # 빛나는 효과
            glow_surf = pygame.Surface((size * 4, size * 4), pygame.SRCALPHA)
            for i in range(3):
                glow_alpha = int(alpha * (0.3 - i * 0.1))
                if glow_alpha > 0:
                    pygame.draw.circle(glow_surf, (*color, glow_alpha),
                                     (size * 2, size * 2), size + i * 2)
            pygame.draw.circle(glow_surf, (*color, alpha), (size * 2, size * 2), size)

            rect = glow_surf.get_rect(center=(int(p['x']), int(p['y'])))
            screen.blit(glow_surf, rect)

    def get_absorbing_butterfly_for_ingame(self):
        """게임 화면에 그릴 흡수 중인 나비 정보 반환 (게임 좌표계)

        Returns:
            dict or None: 흡수 중인 나비 정보 (게임 좌표로 변환됨) 또는 None
        """
        if self._absorbing_butterfly is None:
            return None

        butterfly = self._absorbing_butterfly
        # 전체화면 좌표 -> 게임 좌표로 변환
        game_x = butterfly['x'] - self.game_x
        game_y = butterfly['y'] - self.game_y

        return {
            'x': game_x,
            'y': game_y,
            'phase': butterfly['phase'],
            'wing_speed': butterfly['wing_speed'],
            'size': butterfly['size'],
            'color': butterfly['color'],
            'progress': self._absorbing_timer / self._absorbing_duration,
        }

    def draw_absorbing_butterfly_ingame(self, screen, game_width, game_height):
        """게임 화면에 흡수 중인 나비 그리기 (게임 좌표계, 신비한 빛과 함께)

        Args:
            screen: 게임 화면 surface
            game_width: 게임 영역 너비
            game_height: 게임 영역 높이
        """
        butterfly_info = self.get_absorbing_butterfly_for_ingame()
        if butterfly_info is None:
            return

        progress = butterfly_info['progress']
        if progress <= 0:
            return

        x = int(butterfly_info['x'])
        y = int(butterfly_info['y'])
        phase = butterfly_info['phase']
        wing_speed = butterfly_info['wing_speed']
        size = butterfly_info['size']
        color_name = butterfly_info['color']

        # 화면 밖이면 그리지 않음
        if x < -100 or x > game_width + 100 or y < -100 or y > game_height + 100:
            return

        # 날개 펄럭임 (점점 빨라짐)
        accelerated_wing_speed = wing_speed * (2.0 - progress)
        wing_angle = math.sin(self.time * accelerated_wing_speed + phase) * 0.4

        # 색상
        if color_name == 'blue':
            wing_color = (60, 100, 160)
            accent = (80, 130, 200)
        elif color_name == 'gold':
            wing_color = (200, 160, 80)
            accent = (230, 190, 100)
        else:
            wing_color = (180, 80, 80)
            accent = (220, 120, 100)

        # 페이드아웃 알파값 (점점 투명해짐)
        alpha = int(255 * progress)

        wing_size = int(18 * size)
        body_length = int(12 * size)

        # 신비한 빛 후광 효과 (여러 레이어)
        glow_colors = [
            (255, 255, 220),  # 밝은 금빛
            (220, 255, 255),  # 신비한 하늘색
            (255, 230, 180),  # 따뜻한 노랑
        ]

        # 맥동하는 빛 효과 (점점 커지면서 사라짐)
        pulse = 1.0 + math.sin(self.time * 10) * 0.2
        glow_size = int(40 * (2.0 - progress) * pulse)

        for i, glow_color in enumerate(glow_colors):
            layer_size = glow_size + i * 15
            glow_alpha = int(alpha * (0.4 - i * 0.1))
            if glow_alpha > 0 and layer_size > 0:
                glow_surf = pygame.Surface((layer_size * 2, layer_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (*glow_color, glow_alpha),
                                 (layer_size, layer_size), layer_size)
                screen.blit(glow_surf, (x - layer_size, y - layer_size))

        # 회전하는 빛 입자들
        num_light_particles = 8
        for i in range(num_light_particles):
            angle = (self.time * 3 + i * (math.pi * 2 / num_light_particles))
            radius = 25 * (2.0 - progress)
            px = x + int(math.cos(angle) * radius)
            py = y + int(math.sin(angle) * radius)
            particle_size = int(4 * progress)
            if particle_size > 0:
                particle_alpha = int(200 * progress)
                particle_surf = pygame.Surface((particle_size * 2, particle_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(particle_surf, (255, 255, 255, particle_alpha),
                                 (particle_size, particle_size), particle_size)
                screen.blit(particle_surf, (px - particle_size, py - particle_size))

        # 나비 본체 (페이드아웃)
        # 왼쪽 날개
        left_wing = pygame.Surface((wing_size, wing_size), pygame.SRCALPHA)
        pygame.draw.ellipse(left_wing, (*wing_color, alpha), (0, 0, wing_size, int(wing_size * 0.7)))
        pygame.draw.ellipse(left_wing, (*accent, int(alpha * 0.8)), (wing_size // 4, wing_size // 6, wing_size // 2, wing_size // 3))

        # 오른쪽 날개
        right_wing = pygame.transform.flip(left_wing, True, False)

        # 날개 회전
        left_rotated = pygame.transform.rotate(left_wing, math.degrees(wing_angle) * 30)
        right_rotated = pygame.transform.rotate(right_wing, -math.degrees(wing_angle) * 30)

        # 배치
        screen.blit(left_rotated, (x - wing_size - 2, y - wing_size // 2))
        screen.blit(right_rotated, (x + 2, y - wing_size // 2))

        # 몸통
        body_surf = pygame.Surface((10, body_length + 4), pygame.SRCALPHA)
        pygame.draw.ellipse(body_surf, (40, 35, 30, alpha), (2, 2, 6, body_length))
        screen.blit(body_surf, (x - 5, y - body_length // 2 - 2))


# 호환성을 위한 클래스 별칭
StadiumPillarBackground = TraditionalFrame


# 전역 인스턴스
_stadium_bg = None


def init_stadium_background(screen_width: int, screen_height: int,
                            game_width: int, game_height: int) -> TraditionalFrame:
    global _stadium_bg
    _stadium_bg = TraditionalFrame(screen_width, screen_height, game_width, game_height)
    return _stadium_bg


def get_stadium_background() -> TraditionalFrame:
    return _stadium_bg
