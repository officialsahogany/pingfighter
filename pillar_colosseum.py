# -*- coding: utf-8 -*-
"""
고대 로마 콜로세움 스타일 필러 배경 (Stage 30 - Colosseum Arena)
베이지/갈색 톤의 석조 구조물 + 빽빽한 관중석
"""

import math
import random
import pygame


class CircularStadiumFrame:
    """고대 로마 콜로세움 스타일 필러"""

    # 색상 팔레트 (로마 석조 톤)
    COLORS = {
        # 석조 색상
        'stone_light': (210, 190, 160),     # 밝은 석조
        'stone_medium': (180, 160, 130),    # 중간 석조
        'stone_dark': (140, 120, 95),       # 어두운 석조
        'stone_shadow': (100, 85, 65),      # 그림자
        # 장식
        'gold': (200, 160, 80),             # 금색 장식
        'bronze': (160, 120, 60),           # 청동색
        'pillar': (190, 175, 150),          # 기둥 색
        'pillar_shadow': (150, 135, 110),   # 기둥 그림자
        # 관중석
        'seat_light': (170, 150, 120),      # 밝은 좌석
        'seat_dark': (130, 110, 85),        # 어두운 좌석
        'aisle': (90, 75, 55),              # 통로
    }

    # 관중 옷 색상 (다양하고 밝은 색)
    CROWD_BODY_COLORS = [
        (180, 60, 60),    # 빨강
        (60, 80, 160),    # 파랑
        (60, 140, 80),    # 초록
        (180, 160, 60),   # 노랑
        (140, 60, 140),   # 보라
        (180, 100, 60),   # 주황
        (100, 160, 180),  # 청록
        (180, 80, 120),   # 분홍
        (80, 80, 100),    # 회색
        (120, 90, 60),    # 갈색
        (200, 180, 140),  # 베이지
        (60, 60, 80),     # 남색
        (160, 140, 100),  # 카키
        (200, 100, 100),  # 연빨강
        (100, 140, 200),  # 연파랑
    ]

    # 피부색
    SKIN_COLORS = [
        (255, 220, 180),  # 밝은 피부
        (240, 200, 160),  # 중간 밝은
        (220, 180, 140),  # 올리브
        (190, 150, 110),  # 중간
        (160, 120, 90),   # 어두운
        (130, 95, 70),    # 더 어두운
    ]

    # 머리색
    HAIR_COLORS = [
        (40, 30, 20),     # 검정
        (60, 45, 30),     # 진갈색
        (90, 65, 45),     # 갈색
        (120, 90, 60),    # 밝은 갈색
        (50, 40, 30),     # 어두운 갈색
        (30, 25, 20),     # 흑발
    ]

    def __init__(self, screen_width: int, screen_height: int,
                 game_width: int, game_height: int,
                 offset_x: int = None, offset_y: int = None,
                 original_game_width: int = None, original_game_height: int = None):
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.game_width = game_width
        self.game_height = game_height

        self.original_game_width = original_game_width if original_game_width else game_width
        self.original_game_height = original_game_height if original_game_height else game_height

        self.scale_factor = game_width / self.original_game_width if self.original_game_width > 0 else 1.0

        self.game_x = offset_x if offset_x is not None else (screen_width - game_width) // 2
        self.game_y = offset_y if offset_y is not None else (screen_height - game_height) // 2

        # 경기장 중심점
        self.center_x = self.game_x + self.game_width // 2
        self.center_y = self.game_y + self.game_height // 2

        # 애니메이션
        self.time = 0.0

        # 응원 이벤트 상태
        self.excitement_level = 0.0
        self.excitement_timer = 0.0

        # 관중 데이터 생성
        self.crowd_list = []
        self._generate_crowd()

        # 캐시된 프레임 (석조 배경)
        self._frame_surface = None
        self._create_frame()

        # Wave 애니메이션
        self._wave_angle = 0.0
        self._wave_active = False

    def _generate_crowd(self):
        """관중 생성 (빽빽하게, 큰 크기)"""
        random.seed(42)

        # 게임 영역 바깥쪽부터
        inner_radius = max(self.game_width, self.game_height) // 2 + 25
        outer_radius = int(math.sqrt(self.screen_width**2 + self.screen_height**2)) + 50

        # 관중 크기 (큰 사이즈)
        person_size = 28  # 관중 한 명 크기
        row_spacing = 32  # 줄 간격
        seat_spacing = 22  # 좌석 간격

        # 관중석 줄 수
        num_rows = (outer_radius - inner_radius) // row_spacing

        for row in range(num_rows):
            radius = inner_radius + row * row_spacing
            circumference = 2 * math.pi * radius
            num_seats = int(circumference / seat_spacing)

            for i in range(num_seats):
                angle = (i / num_seats) * 2 * math.pi

                # 통로 구간 (3개, 더 좁게)
                # 상단, 좌하단, 우하단에 통로
                is_aisle = False
                for aisle_angle in [math.pi * 0.5, math.pi * 1.17, math.pi * 1.83]:
                    if abs(angle - aisle_angle) < 0.08 or abs(angle - aisle_angle - 2*math.pi) < 0.08:
                        is_aisle = True
                        break

                if is_aisle:
                    continue

                x = self.center_x + int(radius * math.cos(angle))
                y = self.center_y + int(radius * math.sin(angle))

                # 화면 범위 체크
                if -50 <= x < self.screen_width + 50 and -50 <= y < self.screen_height + 50:
                    # 게임 영역 내부 제외
                    if not (self.game_x - 20 < x < self.game_x + self.game_width + 20 and
                            self.game_y - 20 < y < self.game_y + self.game_height + 20):

                        # 색상 선택
                        body_color = random.choice(self.CROWD_BODY_COLORS)
                        skin_color = random.choice(self.SKIN_COLORS)
                        hair_color = random.choice(self.HAIR_COLORS)

                        # 거리에 따른 밝기/크기 조절
                        distance_factor = row / num_rows
                        brightness = 1.0 - distance_factor * 0.3
                        size = int(person_size * (1.0 - distance_factor * 0.2))

                        body_color = tuple(int(c * brightness) for c in body_color)
                        skin_color = tuple(int(c * brightness) for c in skin_color)
                        hair_color = tuple(int(c * brightness) for c in hair_color)

                        self.crowd_list.append({
                            'x': x,
                            'y': y,
                            'body_color': body_color,
                            'skin_color': skin_color,
                            'hair_color': hair_color,
                            'size': size,
                            'row': row,
                            'angle': angle,
                            'anim_offset': random.uniform(0, math.pi * 2),
                        })

        random.seed()

    def _create_frame(self):
        """프레임 캐시 생성 (석조 배경)"""
        self._frame_surface = pygame.Surface(
            (self.screen_width, self.screen_height), pygame.SRCALPHA
        )

        # 배경 (베이지 석조)
        self._frame_surface.fill(self.COLORS['stone_medium'])

        # 동심원 좌석 구조
        self._draw_seat_tiers(self._frame_surface)

        # 기둥 구조
        self._draw_pillars(self._frame_surface)

        # 통로
        self._draw_aisles(self._frame_surface)

        # 게임 영역 투명
        pygame.draw.rect(self._frame_surface, (0, 0, 0, 0),
                        (self.game_x, self.game_y, self.game_width, self.game_height))

        # 경기장 테두리 장식
        self._draw_arena_border(self._frame_surface)

    def _draw_seat_tiers(self, surface):
        """동심원 좌석 단 그리기"""
        inner_radius = max(self.game_width, self.game_height) // 2 + 20
        outer_radius = int(math.sqrt(self.screen_width**2 + self.screen_height**2)) + 50

        tier_height = 35
        num_tiers = (outer_radius - inner_radius) // tier_height

        for i in range(num_tiers):
            radius = inner_radius + i * tier_height

            # 좌석 단 색상 (번갈아가며)
            if i % 2 == 0:
                color = self.COLORS['seat_light']
            else:
                color = self.COLORS['seat_dark']

            # 원형 좌석 단
            pygame.draw.circle(surface, color, (self.center_x, self.center_y), radius + tier_height, tier_height)

            # 단 경계선
            pygame.draw.circle(surface, self.COLORS['stone_shadow'],
                             (self.center_x, self.center_y), radius, 2)

    def _draw_pillars(self, surface):
        """기둥 구조 그리기"""
        inner_radius = max(self.game_width, self.game_height) // 2 + 25
        outer_radius = int(math.sqrt(self.screen_width**2 + self.screen_height**2))

        # 주요 기둥 (12개)
        num_pillars = 12
        pillar_width = 20
        pillar_spacing = 2 * math.pi / num_pillars

        for i in range(num_pillars):
            angle = i * pillar_spacing

            # 통로 위치 건너뛰기
            skip = False
            for aisle_angle in [math.pi * 0.5, math.pi * 1.17, math.pi * 1.83]:
                if abs(angle - aisle_angle) < 0.3:
                    skip = True
                    break
            if skip:
                continue

            # 기둥 그리기 (안쪽부터 바깥쪽까지)
            for r in range(int(inner_radius), int(outer_radius), 80):
                px = self.center_x + int(r * math.cos(angle))
                py = self.center_y + int(r * math.sin(angle))

                # 화면 범위 체크
                if 0 <= px < self.screen_width and 0 <= py < self.screen_height:
                    # 게임 영역 체크
                    if not (self.game_x < px < self.game_x + self.game_width and
                            self.game_y < py < self.game_y + self.game_height):
                        # 기둥 본체
                        pygame.draw.rect(surface, self.COLORS['pillar'],
                                        (px - pillar_width//2, py - 25, pillar_width, 50),
                                        border_radius=3)
                        # 기둥 그림자
                        pygame.draw.rect(surface, self.COLORS['pillar_shadow'],
                                        (px - pillar_width//2, py - 25, 4, 50))
                        # 기둥 상단 장식
                        pygame.draw.rect(surface, self.COLORS['gold'],
                                        (px - pillar_width//2 - 2, py - 28, pillar_width + 4, 6))

    def _draw_aisles(self, surface):
        """통로 그리기"""
        inner_radius = max(self.game_width, self.game_height) // 2 + 20
        outer_radius = int(math.sqrt(self.screen_width**2 + self.screen_height**2))

        # 3개 통로 (상단, 좌하단, 우하단)
        aisle_angles = [math.pi * 0.5, math.pi * 1.17, math.pi * 1.83]
        aisle_width = 25

        for angle in aisle_angles:
            # 통로 양쪽 좌표
            for r in range(int(inner_radius), int(outer_radius), 5):
                x1 = self.center_x + int(r * math.cos(angle - 0.05))
                y1 = self.center_y + int(r * math.sin(angle - 0.05))
                x2 = self.center_x + int(r * math.cos(angle + 0.05))
                y2 = self.center_y + int(r * math.sin(angle + 0.05))

                # 통로 색상
                pygame.draw.line(surface, self.COLORS['aisle'], (x1, y1), (x2, y2), 3)

    def _draw_arena_border(self, surface):
        """경기장 테두리 장식"""
        # 금색 외곽선
        pygame.draw.rect(surface, self.COLORS['gold'],
                        (self.game_x - 8, self.game_y - 8,
                         self.game_width + 16, self.game_height + 16), 6)
        # 내부 석조 테두리
        pygame.draw.rect(surface, self.COLORS['stone_light'],
                        (self.game_x - 4, self.game_y - 4,
                         self.game_width + 8, self.game_height + 8), 3)

    def trigger_excitement(self, intensity: float = 1.0, duration: float = 2.0):
        """관중 흥분 이벤트"""
        self.excitement_level = min(1.0, intensity)
        self.excitement_timer = duration

    def trigger_wave(self):
        """관중 웨이브"""
        self._wave_active = True
        self._wave_angle = 0.0

    def update(self, dt: float, player_rect=None):
        """업데이트"""
        self.time += dt

        # 흥분 상태 감소
        if self.excitement_timer > 0:
            self.excitement_timer -= dt
            if self.excitement_timer <= 0:
                self.excitement_level = max(0, self.excitement_level - dt * 0.5)
        else:
            self.excitement_level = max(0, self.excitement_level - dt * 0.3)

        # 웨이브 애니메이션
        if self._wave_active:
            self._wave_angle += dt * 2.5
            if self._wave_angle > math.pi * 2 + 1:
                self._wave_active = False
                self._wave_angle = 0.0

    def draw(self, screen: pygame.Surface):
        """프레임 그리기"""
        # 캐시된 석조 배경
        if self._frame_surface:
            screen.blit(self._frame_surface, (0, 0))

        # 관중 그리기
        is_excited = self.excitement_level > 0.3

        for person in self.crowd_list:
            x, y = person['x'], person['y']
            body_color = person['body_color']
            skin_color = person['skin_color']
            hair_color = person['hair_color']
            size = person['size']
            anim_offset = person['anim_offset']

            # 애니메이션
            bounce = 0
            arm_up = False

            if is_excited:
                bounce = int(4 * math.sin(self.time * 5 + anim_offset))
                arm_up = math.sin(self.time * 3 + anim_offset) > 0.2

            # 웨이브
            if self._wave_active:
                angle_diff = abs(person['angle'] - self._wave_angle)
                if angle_diff < 0.5 or angle_diff > math.pi * 2 - 0.5:
                    bounce = -10
                    arm_up = True

            # 관중 그리기
            self._draw_person(screen, x, y + bounce, size, body_color, skin_color, hair_color, arm_up)

    def _draw_person(self, screen, x, y, size, body_color, skin_color, hair_color, arm_up=False):
        """관중 한 명 그리기"""
        # 크기 비율
        head_radius = size // 4
        body_width = size // 2
        body_height = int(size * 0.6)

        # 몸통
        body_y = y
        pygame.draw.ellipse(screen, body_color,
                           (x - body_width // 2, body_y, body_width, body_height))

        # 팔
        arm_width = size // 5
        arm_height = size // 3

        if arm_up:
            # 팔 위로
            pygame.draw.ellipse(screen, body_color,
                               (x - body_width // 2 - arm_width + 2, body_y - arm_height // 2,
                                arm_width, arm_height))
            pygame.draw.ellipse(screen, body_color,
                               (x + body_width // 2 - 2, body_y - arm_height // 2,
                                arm_width, arm_height))
            # 손
            pygame.draw.circle(screen, skin_color,
                              (x - body_width // 2 - arm_width // 2 + 2, body_y - arm_height // 2),
                              arm_width // 2)
            pygame.draw.circle(screen, skin_color,
                              (x + body_width // 2 + arm_width // 2 - 2, body_y - arm_height // 2),
                              arm_width // 2)
        else:
            # 팔 옆으로
            pygame.draw.ellipse(screen, body_color,
                               (x - body_width // 2 - arm_width + 3, body_y + 2,
                                arm_width, arm_height))
            pygame.draw.ellipse(screen, body_color,
                               (x + body_width // 2 - 3, body_y + 2,
                                arm_width, arm_height))

        # 머리
        head_y = body_y - head_radius
        pygame.draw.circle(screen, skin_color, (x, head_y), head_radius)

        # 머리카락 (반원)
        hair_rect = (x - head_radius, head_y - head_radius, head_radius * 2, head_radius * 2)
        pygame.draw.arc(screen, hair_color, hair_rect, 0, math.pi, head_radius)

    def draw_foreground(self, screen: pygame.Surface):
        """전경 효과"""
        # 비네팅
        vignette_size = 20
        for i in range(vignette_size):
            alpha = int(25 * (1 - i / vignette_size))
            surf = pygame.Surface((self.game_width, 1), pygame.SRCALPHA)
            surf.fill((0, 0, 0, alpha))
            screen.blit(surf, (self.game_x, self.game_y + i))
            screen.blit(surf, (self.game_x, self.game_y + self.game_height - i - 1))


# 호환성 별칭
ColosseumFrame = CircularStadiumFrame
