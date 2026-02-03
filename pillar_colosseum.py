# -*- coding: utf-8 -*-
"""
원형 경기장 스타일 필러 배경 (Stage 30 - Colosseum Arena)
원형 스타디움: 게임 영역을 둘러싼 동심원 형태의 빽빽한 관중석
"""

import math
import random
import pygame


class CircularStadiumFrame:
    """원형 경기장 필러 (게임 영역을 둘러싼 동심원 관중석)"""

    # 색상 팔레트 (어두운 청회색 톤)
    COLORS = {
        'bg_dark': (25, 30, 40),          # 배경 어두운색
        'bg_medium': (35, 42, 55),        # 배경 중간색
        'seat_dark': (45, 55, 70),        # 좌석 어두운색
        'seat_medium': (60, 72, 90),      # 좌석 중간색
        'seat_light': (75, 88, 105),      # 좌석 밝은색
        'aisle': (30, 35, 45),            # 통로색
        'rail': (80, 90, 100),            # 난간색
        'rail_gold': (180, 150, 80),      # 금색 난간
        'crowd_base': (90, 75, 65),       # 관중 기본색
        'crowd_var1': (100, 85, 75),      # 관중 변형1
        'crowd_var2': (80, 70, 60),       # 관중 변형2
        'crowd_var3': (110, 90, 80),      # 관중 변형3
        'highlight': (120, 100, 85),      # 하이라이트
        'shadow': (20, 25, 35),           # 그림자
        'structure': (50, 55, 65),        # 구조물
        'structure_light': (70, 75, 85),  # 구조물 밝은색
    }

    # 관중 색상 (다양한 옷 색상)
    CROWD_COLORS = [
        (90, 75, 65),    # 베이지
        (100, 85, 75),   # 연갈색
        (80, 70, 60),    # 갈색
        (110, 90, 80),   # 밝은 갈색
        (70, 80, 100),   # 파란 옷
        (100, 70, 70),   # 빨간 옷
        (80, 100, 80),   # 초록 옷
        (110, 100, 80),  # 노란 옷
        (90, 80, 100),   # 보라 옷
        (60, 65, 75),    # 어두운 옷
        (120, 110, 100), # 밝은 옷
        (75, 70, 65),    # 회색 옷
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

        # 경기장 중심점 (게임 영역 중심)
        self.center_x = self.game_x + self.game_width // 2
        self.center_y = self.game_y + self.game_height // 2

        # 애니메이션
        self.time = 0.0

        # 응원 이벤트 상태
        self.excitement_level = 0.0
        self.excitement_timer = 0.0

        # 관중 데이터 생성 (픽셀 기반)
        self.crowd_pixels = []
        self._generate_crowd_pixels()

        # 캐시된 프레임
        self._frame_surface = None
        self._create_frame()

        # Wave 애니메이션
        self._wave_angle = 0.0
        self._wave_active = False

    def _generate_crowd_pixels(self):
        """관중 데이터 생성 (동심원 형태, 큰 사람 형태)"""
        random.seed(42)  # 일관된 결과를 위해

        # 게임 영역 바깥쪽 반경부터 화면 끝까지
        inner_radius = max(self.game_width, self.game_height) // 2 + 30
        outer_radius = int(math.sqrt(self.screen_width**2 + self.screen_height**2))

        # 관중석 층 수 (큰 관중을 위해 적게)
        num_tiers = 12
        tier_height = (outer_radius - inner_radius) // num_tiers

        for tier in range(num_tiers):
            radius = inner_radius + tier * tier_height
            # 원 둘레를 따라 관중 배치 (큰 간격)
            circumference = 2 * math.pi * radius
            num_seats = int(circumference / 25)  # 25픽셀 간격 (큰 관중)

            for i in range(num_seats):
                angle = (i / num_seats) * 2 * math.pi

                # 통로 구간 (3개 방사형 통로)
                aisle_angle = angle % (2 * math.pi / 3)
                is_aisle = aisle_angle < 0.15 or aisle_angle > (2 * math.pi / 3 - 0.15)

                if is_aisle:
                    continue

                x = self.center_x + int(radius * math.cos(angle))
                y = self.center_y + int(radius * math.sin(angle))

                # 화면 범위 체크 (관중 크기 고려)
                if -20 <= x < self.screen_width + 20 and -20 <= y < self.screen_height + 20:
                    # 게임 영역 내부는 제외 (여유 공간 포함)
                    if not (self.game_x - 15 < x < self.game_x + self.game_width + 15 and
                            self.game_y - 15 < y < self.game_y + self.game_height + 15):
                        # 관중 색상 (옷 색상)
                        body_color = random.choice(self.CROWD_COLORS)
                        # 피부색
                        skin_colors = [
                            (255, 220, 180), (240, 200, 160), (220, 180, 140),
                            (180, 140, 100), (140, 100, 70), (255, 210, 170)
                        ]
                        skin_color = random.choice(skin_colors)
                        # 머리 색상
                        hair_colors = [
                            (40, 30, 20), (60, 45, 30), (90, 60, 40),
                            (30, 25, 20), (80, 50, 30), (50, 40, 30)
                        ]
                        hair_color = random.choice(hair_colors)

                        # 거리에 따른 밝기 조절
                        brightness = 1.0 - (tier / num_tiers) * 0.4
                        body_color = tuple(int(c * brightness) for c in body_color)
                        skin_color = tuple(int(c * brightness) for c in skin_color)
                        hair_color = tuple(int(c * brightness) for c in hair_color)

                        self.crowd_pixels.append({
                            'x': x,
                            'y': y,
                            'body_color': body_color,
                            'skin_color': skin_color,
                            'hair_color': hair_color,
                            'tier': tier,
                            'angle': angle,
                            'anim_offset': random.uniform(0, math.pi * 2),
                            'size': random.randint(12, 18),  # 관중 크기 12-18px
                        })

        random.seed()

    def _create_frame(self):
        """프레임 캐시 생성"""
        self._frame_surface = pygame.Surface(
            (self.screen_width, self.screen_height), pygame.SRCALPHA
        )

        # 배경 (어두운 색)
        self._frame_surface.fill(self.COLORS['bg_dark'])

        # 동심원 좌석 구조 그리기
        self._draw_seat_structure(self._frame_surface)

        # 게임 영역 투명하게
        pygame.draw.rect(self._frame_surface, (0, 0, 0, 0),
                        (self.game_x, self.game_y, self.game_width, self.game_height))

        # 방사형 통로 그리기
        self._draw_aisles(self._frame_surface)

        # 구조물/난간 그리기
        self._draw_structures(self._frame_surface)

    def _draw_seat_structure(self, surface):
        """동심원 형태의 좌석 구조 그리기"""
        inner_radius = max(self.game_width, self.game_height) // 2 + 10
        outer_radius = int(math.sqrt(self.screen_width**2 + self.screen_height**2))

        num_tiers = 25

        for tier in range(num_tiers):
            radius = inner_radius + (tier * (outer_radius - inner_radius)) // num_tiers

            # 층마다 다른 색상
            if tier % 3 == 0:
                color = self.COLORS['seat_dark']
            elif tier % 3 == 1:
                color = self.COLORS['seat_medium']
            else:
                color = self.COLORS['seat_light']

            # 원형 좌석 줄
            pygame.draw.circle(surface, color, (self.center_x, self.center_y), radius, 3)

        # 경기장 가장자리 (게임 영역 바로 바깥)
        pygame.draw.ellipse(surface, self.COLORS['rail_gold'],
                           (self.game_x - 8, self.game_y - 8,
                            self.game_width + 16, self.game_height + 16), 4)
        pygame.draw.ellipse(surface, self.COLORS['structure_light'],
                           (self.game_x - 12, self.game_y - 12,
                            self.game_width + 24, self.game_height + 24), 2)

    def _draw_aisles(self, surface):
        """방사형 통로 그리기"""
        inner_radius = max(self.game_width, self.game_height) // 2 + 15
        outer_radius = int(math.sqrt(self.screen_width**2 + self.screen_height**2))

        # 3개의 방사형 통로 (120도 간격)
        for i in range(3):
            angle = i * (2 * math.pi / 3)  # 0, 120, 240도

            # 통로 시작점과 끝점
            start_x = self.center_x + int(inner_radius * math.cos(angle))
            start_y = self.center_y + int(inner_radius * math.sin(angle))
            end_x = self.center_x + int(outer_radius * math.cos(angle))
            end_y = self.center_y + int(outer_radius * math.sin(angle))

            # 통로 그리기 (어두운 색, 더 넓게)
            pygame.draw.line(surface, self.COLORS['aisle'],
                           (start_x, start_y), (end_x, end_y), 10)
            # 통로 가장자리 라인
            pygame.draw.line(surface, self.COLORS['structure'],
                           (start_x, start_y), (end_x, end_y), 2)

    def _draw_structures(self, surface):
        """구조물 및 난간 그리기"""
        # 동심원 난간 (일정 간격마다)
        inner_radius = max(self.game_width, self.game_height) // 2 + 30
        outer_radius = int(math.sqrt(self.screen_width**2 + self.screen_height**2))

        for i in range(5):
            radius = inner_radius + (i * (outer_radius - inner_radius)) // 5
            pygame.draw.circle(surface, self.COLORS['structure'],
                             (self.center_x, self.center_y), radius, 1)

    def trigger_excitement(self, intensity: float = 1.0, duration: float = 2.0):
        """관중 흥분 이벤트 트리거"""
        self.excitement_level = min(1.0, intensity)
        self.excitement_timer = duration

    def trigger_wave(self):
        """관중 웨이브 시작"""
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
            self._wave_angle += dt * 3  # 웨이브 속도
            if self._wave_angle > math.pi * 2 + 1:
                self._wave_active = False
                self._wave_angle = 0.0

    def draw(self, screen: pygame.Surface):
        """프레임 그리기"""
        # 캐시된 프레임 (배경)
        if self._frame_surface:
            screen.blit(self._frame_surface, (0, 0))

        # 관중 그리기 (사람 형태)
        is_excited = self.excitement_level > 0.3

        for person in self.crowd_pixels:
            x, y = person['x'], person['y']
            body_color = person['body_color']
            skin_color = person['skin_color']
            hair_color = person['hair_color']
            size = person['size']

            # 애니메이션 오프셋
            anim_offset = person['anim_offset']

            # 응원 애니메이션 (위아래 움직임)
            bounce = 0
            arm_up = False
            if is_excited:
                bounce = int(3 * math.sin(self.time * 6 + anim_offset))
                arm_up = math.sin(self.time * 4 + anim_offset) > 0.3

            # 웨이브 애니메이션
            if self._wave_active:
                angle_diff = abs(person['angle'] - self._wave_angle)
                if angle_diff < 0.4 or angle_diff > math.pi * 2 - 0.4:
                    bounce = -8  # 웨이브: 위로 점프
                    arm_up = True
                    body_color = tuple(min(255, c + 30) for c in body_color)

            # 관중 그리기 (머리 + 몸통)
            self._draw_person(screen, x, y + bounce, size, body_color, skin_color, hair_color, arm_up)

    def _draw_person(self, screen, x, y, size, body_color, skin_color, hair_color, arm_up=False):
        """관중 한 명 그리기 (머리 + 몸통 + 팔)"""
        # 크기 비율
        head_size = size // 3
        body_width = size // 2
        body_height = size - head_size

        # 몸통 (사각형)
        body_y = y
        pygame.draw.rect(screen, body_color,
                        (x - body_width // 2, body_y, body_width, body_height),
                        border_radius=2)

        # 팔 (응원 시 위로)
        arm_width = size // 6
        arm_height = size // 3
        if arm_up:
            # 왼팔 위로
            pygame.draw.rect(screen, body_color,
                            (x - body_width // 2 - arm_width, body_y - arm_height + 2, arm_width, arm_height))
            # 오른팔 위로
            pygame.draw.rect(screen, body_color,
                            (x + body_width // 2, body_y - arm_height + 2, arm_width, arm_height))
            # 손
            pygame.draw.circle(screen, skin_color,
                              (x - body_width // 2 - arm_width // 2, body_y - arm_height + 2), arm_width)
            pygame.draw.circle(screen, skin_color,
                              (x + body_width // 2 + arm_width // 2, body_y - arm_height + 2), arm_width)
        else:
            # 팔 옆으로
            pygame.draw.rect(screen, body_color,
                            (x - body_width // 2 - arm_width, body_y + 2, arm_width, arm_height))
            pygame.draw.rect(screen, body_color,
                            (x + body_width // 2, body_y + 2, arm_width, arm_height))

        # 머리 (원형)
        head_y = body_y - head_size
        pygame.draw.circle(screen, skin_color, (x, head_y), head_size)

        # 머리카락
        pygame.draw.circle(screen, hair_color, (x, head_y - 2), head_size,
                          draw_top_left=True, draw_top_right=True)

        # 응원 이펙트
        if self.excitement_level > 0.5:
            self._draw_cheer_effects(screen)

    def _draw_cheer_effects(self, screen: pygame.Surface):
        """응원 이펙트 (빛 반짝임)"""
        num_sparkles = int(30 * self.excitement_level)

        for i in range(num_sparkles):
            # 랜덤 위치 (필러 영역)
            if random.random() < 0.5:
                x = random.randint(0, self.game_x - 5)
            else:
                x = random.randint(self.game_x + self.game_width + 5, self.screen_width - 5)

            y = random.randint(20, self.screen_height - 20)

            # 반짝임
            sparkle_alpha = int(100 + 100 * math.sin(self.time * 15 + i))
            size = random.randint(1, 3)

            surf = pygame.Surface((size, size), pygame.SRCALPHA)
            surf.fill((255, 250, 200, sparkle_alpha))
            screen.blit(surf, (x, y))

    def draw_foreground(self, screen: pygame.Surface):
        """전경 효과"""
        # 게임 영역 주변 비네팅
        vignette_size = 15

        for i in range(vignette_size):
            alpha = int(30 * (1 - i / vignette_size))
            # 상단
            surf = pygame.Surface((self.game_width, 1), pygame.SRCALPHA)
            surf.fill((0, 0, 0, alpha))
            screen.blit(surf, (self.game_x, self.game_y + i))
            # 하단
            screen.blit(surf, (self.game_x, self.game_y + self.game_height - i - 1))


# 호환성을 위한 별칭
ColosseumFrame = CircularStadiumFrame
