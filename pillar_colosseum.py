# -*- coding: utf-8 -*-
"""
고대 로마 콜로세움 스타일 필러 배경 (Stage 30 - Colosseum Arena)
베이지/갈색 톤의 석조 구조물 + 빽빽한 관중석 + 고퀄리티 디테일
"""

import math
import random
import pygame


class CircularStadiumFrame:
    """고대 로마 콜로세움 스타일 필러 (고퀄리티)"""

    # 색상 팔레트 (로마 석조 톤)
    COLORS = {
        # 석조 색상
        'stone_light': (210, 190, 160),
        'stone_medium': (180, 160, 130),
        'stone_dark': (140, 120, 95),
        'stone_shadow': (100, 85, 65),
        'stone_highlight': (230, 215, 185),
        # 장식
        'gold': (200, 160, 80),
        'gold_light': (230, 200, 120),
        'gold_dark': (160, 120, 50),
        'bronze': (160, 120, 60),
        'copper': (180, 100, 70),
        # 기둥
        'pillar': (195, 180, 155),
        'pillar_light': (215, 200, 175),
        'pillar_shadow': (145, 130, 105),
        'pillar_dark': (120, 105, 85),
        # 관중석
        'seat_light': (175, 155, 125),
        'seat_medium': (155, 135, 105),
        'seat_dark': (125, 105, 80),
        'seat_shadow': (95, 80, 60),
        # 통로/계단
        'aisle': (85, 70, 50),
        'aisle_light': (110, 95, 70),
        'step': (100, 85, 65),
        # 횃불
        'torch_flame': (255, 180, 60),
        'torch_glow': (255, 220, 150),
        'torch_holder': (80, 60, 40),
    }

    # 관중 옷 색상 (더 다양하게)
    CROWD_BODY_COLORS = [
        (180, 60, 60),    # 빨강
        (200, 80, 80),    # 연빨강
        (150, 40, 40),    # 진빨강
        (60, 80, 160),    # 파랑
        (80, 100, 180),   # 연파랑
        (40, 60, 140),    # 진파랑
        (60, 140, 80),    # 초록
        (80, 160, 100),   # 연초록
        (180, 160, 60),   # 노랑
        (200, 180, 80),   # 연노랑
        (140, 60, 140),   # 보라
        (160, 80, 160),   # 연보라
        (180, 100, 60),   # 주황
        (200, 120, 80),   # 연주황
        (100, 160, 180),  # 청록
        (180, 80, 120),   # 분홍
        (200, 100, 140),  # 연분홍
        (80, 80, 100),    # 회색
        (100, 100, 120),  # 연회색
        (120, 90, 60),    # 갈색
        (140, 110, 80),   # 연갈색
        (200, 180, 140),  # 베이지
        (220, 200, 160),  # 연베이지
        (60, 60, 80),     # 남색
        (160, 140, 100),  # 카키
        (180, 180, 180),  # 흰색 계열
        (200, 160, 120),  # 살구색
    ]

    # 피부색
    SKIN_COLORS = [
        (255, 220, 185),
        (245, 205, 165),
        (235, 190, 150),
        (220, 175, 135),
        (200, 155, 115),
        (180, 135, 100),
        (160, 115, 85),
        (140, 100, 75),
    ]

    # 머리색
    HAIR_COLORS = [
        (35, 25, 15),     # 검정
        (50, 35, 25),     # 진갈색
        (70, 50, 35),     # 갈색
        (95, 70, 50),     # 중갈색
        (120, 90, 65),    # 밝은 갈색
        (45, 35, 25),     # 어두운 갈색
        (80, 60, 45),     # 적갈색
        (60, 55, 50),     # 회갈색
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

        # 횃불 데이터
        self.torches = []
        self._generate_torches()

        # 캐시된 프레임 (석조 배경)
        self._frame_surface = None
        self._create_frame()

        # Wave 애니메이션
        self._wave_angle = 0.0
        self._wave_active = False

    def _generate_crowd(self):
        """관중 생성 (빽빽하게, 큰 크기, 다양한 특성)"""
        random.seed(42)

        inner_radius = max(self.game_width, self.game_height) // 2 + 25
        outer_radius = int(math.sqrt(self.screen_width**2 + self.screen_height**2)) + 50

        person_size = 28
        row_spacing = 30
        seat_spacing = 20

        num_rows = (outer_radius - inner_radius) // row_spacing

        for row in range(num_rows):
            radius = inner_radius + row * row_spacing
            circumference = 2 * math.pi * radius
            num_seats = int(circumference / seat_spacing)

            for i in range(num_seats):
                angle = (i / num_seats) * 2 * math.pi

                # 통로 구간 (3개)
                is_aisle = False
                for aisle_angle in [math.pi * 0.5, math.pi * 1.17, math.pi * 1.83]:
                    if abs(angle - aisle_angle) < 0.08 or abs(angle - aisle_angle - 2*math.pi) < 0.08:
                        is_aisle = True
                        break

                if is_aisle:
                    continue

                x = self.center_x + int(radius * math.cos(angle))
                y = self.center_y + int(radius * math.sin(angle))

                if -50 <= x < self.screen_width + 50 and -50 <= y < self.screen_height + 50:
                    if not (self.game_x - 20 < x < self.game_x + self.game_width + 20 and
                            self.game_y - 20 < y < self.game_y + self.game_height + 20):

                        body_color = random.choice(self.CROWD_BODY_COLORS)
                        skin_color = random.choice(self.SKIN_COLORS)
                        hair_color = random.choice(self.HAIR_COLORS)

                        distance_factor = row / max(num_rows, 1)
                        brightness = 1.0 - distance_factor * 0.35
                        size = int(person_size * (1.0 - distance_factor * 0.25))

                        body_color = tuple(int(c * brightness) for c in body_color)
                        skin_color = tuple(int(c * brightness) for c in skin_color)
                        hair_color = tuple(int(c * brightness) for c in hair_color)

                        # 개인 특성
                        has_hat = random.random() < 0.15
                        hat_color = random.choice(self.CROWD_BODY_COLORS) if has_hat else None

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
                            'idle_speed': random.uniform(0.3, 0.8),  # 평소 움직임 속도
                            'idle_amount': random.uniform(0.5, 1.5),  # 평소 움직임 양
                            'has_hat': has_hat,
                            'hat_color': hat_color,
                            'head_tilt': random.uniform(-0.2, 0.2),  # 머리 기울기
                        })

        random.seed()

    def _generate_torches(self):
        """횃불 생성"""
        random.seed(123)

        inner_radius = max(self.game_width, self.game_height) // 2 + 40

        # 8개 횃불 (통로 제외 위치)
        num_torches = 8
        for i in range(num_torches):
            angle = i * (2 * math.pi / num_torches)

            # 통로 위치 건너뛰기
            skip = False
            for aisle_angle in [math.pi * 0.5, math.pi * 1.17, math.pi * 1.83]:
                if abs(angle - aisle_angle) < 0.4:
                    skip = True
                    break
            if skip:
                continue

            x = self.center_x + int(inner_radius * math.cos(angle))
            y = self.center_y + int(inner_radius * math.sin(angle))

            if not (self.game_x - 30 < x < self.game_x + self.game_width + 30 and
                    self.game_y - 30 < y < self.game_y + self.game_height + 30):
                self.torches.append({
                    'x': x,
                    'y': y,
                    'phase': random.uniform(0, math.pi * 2),
                })

        random.seed()

    def _create_frame(self):
        """프레임 캐시 생성 (석조 배경)"""
        self._frame_surface = pygame.Surface(
            (self.screen_width, self.screen_height), pygame.SRCALPHA
        )

        # 배경
        self._frame_surface.fill(self.COLORS['stone_medium'])

        # 동심원 좌석 구조
        self._draw_seat_tiers(self._frame_surface)

        # 아치 구조
        self._draw_arches(self._frame_surface)

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
        """동심원 좌석 단 그리기 (디테일 추가)"""
        inner_radius = max(self.game_width, self.game_height) // 2 + 20
        outer_radius = int(math.sqrt(self.screen_width**2 + self.screen_height**2)) + 50

        tier_height = 32
        num_tiers = (outer_radius - inner_radius) // tier_height

        for i in range(num_tiers):
            radius = inner_radius + i * tier_height

            # 좌석 단 색상 (그라데이션)
            if i % 3 == 0:
                color = self.COLORS['seat_light']
            elif i % 3 == 1:
                color = self.COLORS['seat_medium']
            else:
                color = self.COLORS['seat_dark']

            # 원형 좌석 단
            pygame.draw.circle(surface, color, (self.center_x, self.center_y),
                             radius + tier_height, tier_height)

            # 단 경계선 (3D 효과)
            pygame.draw.circle(surface, self.COLORS['seat_shadow'],
                             (self.center_x, self.center_y), radius, 2)
            pygame.draw.circle(surface, self.COLORS['stone_highlight'],
                             (self.center_x, self.center_y), radius + tier_height - 2, 1)

    def _draw_arches(self, surface):
        """아치 구조 그리기"""
        inner_radius = max(self.game_width, self.game_height) // 2 + 60

        # 아치 (일정 간격마다)
        num_arches = 16
        arch_width = 30
        arch_height = 25

        for i in range(num_arches):
            angle = i * (2 * math.pi / num_arches)

            # 통로 위치 건너뛰기
            skip = False
            for aisle_angle in [math.pi * 0.5, math.pi * 1.17, math.pi * 1.83]:
                if abs(angle - aisle_angle) < 0.25:
                    skip = True
                    break
            if skip:
                continue

            x = self.center_x + int(inner_radius * math.cos(angle))
            y = self.center_y + int(inner_radius * math.sin(angle))

            if not (self.game_x - 20 < x < self.game_x + self.game_width + 20 and
                    self.game_y - 20 < y < self.game_y + self.game_height + 20):
                # 아치 그리기
                arch_rect = (x - arch_width // 2, y - arch_height, arch_width, arch_height * 2)
                pygame.draw.arc(surface, self.COLORS['pillar_dark'], arch_rect, 0, math.pi, 4)
                pygame.draw.arc(surface, self.COLORS['pillar_light'], arch_rect, 0, math.pi, 2)

    def _draw_pillars(self, surface):
        """기둥 구조 그리기 (고퀄리티)"""
        inner_radius = max(self.game_width, self.game_height) // 2 + 25
        outer_radius = int(math.sqrt(self.screen_width**2 + self.screen_height**2))

        num_pillars = 12
        pillar_width = 18

        for i in range(num_pillars):
            angle = i * (2 * math.pi / num_pillars)

            # 통로 위치 건너뛰기
            skip = False
            for aisle_angle in [math.pi * 0.5, math.pi * 1.17, math.pi * 1.83]:
                if abs(angle - aisle_angle) < 0.3:
                    skip = True
                    break
            if skip:
                continue

            for r in range(int(inner_radius), int(outer_radius), 75):
                px = self.center_x + int(r * math.cos(angle))
                py = self.center_y + int(r * math.sin(angle))

                if 0 <= px < self.screen_width and 0 <= py < self.screen_height:
                    if not (self.game_x < px < self.game_x + self.game_width and
                            self.game_y < py < self.game_y + self.game_height):
                        # 기둥 그림자
                        pygame.draw.rect(surface, self.COLORS['pillar_dark'],
                                        (px - pillar_width//2 + 2, py - 22, pillar_width, 48))
                        # 기둥 본체
                        pygame.draw.rect(surface, self.COLORS['pillar'],
                                        (px - pillar_width//2, py - 24, pillar_width - 2, 48),
                                        border_radius=2)
                        # 기둥 하이라이트
                        pygame.draw.rect(surface, self.COLORS['pillar_light'],
                                        (px - pillar_width//2 + 1, py - 24, 3, 48))
                        # 기둥 상단 장식 (코린트식)
                        pygame.draw.rect(surface, self.COLORS['gold'],
                                        (px - pillar_width//2 - 3, py - 28, pillar_width + 6, 5))
                        pygame.draw.rect(surface, self.COLORS['gold_light'],
                                        (px - pillar_width//2 - 3, py - 28, pillar_width + 6, 2))
                        # 기둥 하단 받침
                        pygame.draw.rect(surface, self.COLORS['stone_dark'],
                                        (px - pillar_width//2 - 2, py + 22, pillar_width + 4, 4))

    def _draw_aisles(self, surface):
        """통로 그리기 (계단 디테일)"""
        inner_radius = max(self.game_width, self.game_height) // 2 + 20
        outer_radius = int(math.sqrt(self.screen_width**2 + self.screen_height**2))

        aisle_angles = [math.pi * 0.5, math.pi * 1.17, math.pi * 1.83]

        for angle in aisle_angles:
            # 통로 바닥
            for r in range(int(inner_radius), int(outer_radius), 4):
                x1 = self.center_x + int(r * math.cos(angle - 0.06))
                y1 = self.center_y + int(r * math.sin(angle - 0.06))
                x2 = self.center_x + int(r * math.cos(angle + 0.06))
                y2 = self.center_y + int(r * math.sin(angle + 0.06))

                # 통로 색상 (계단 효과)
                if (r // 15) % 2 == 0:
                    color = self.COLORS['aisle']
                else:
                    color = self.COLORS['aisle_light']

                pygame.draw.line(surface, color, (x1, y1), (x2, y2), 4)

            # 통로 테두리
            for r in range(int(inner_radius), int(outer_radius), 8):
                x_left = self.center_x + int(r * math.cos(angle - 0.07))
                y_left = self.center_y + int(r * math.sin(angle - 0.07))
                x_right = self.center_x + int(r * math.cos(angle + 0.07))
                y_right = self.center_y + int(r * math.sin(angle + 0.07))

                pygame.draw.circle(surface, self.COLORS['stone_shadow'], (x_left, y_left), 2)
                pygame.draw.circle(surface, self.COLORS['stone_shadow'], (x_right, y_right), 2)

    def _draw_arena_border(self, surface):
        """경기장 테두리 장식 (고퀄리티)"""
        # 외곽 그림자
        pygame.draw.rect(surface, self.COLORS['stone_shadow'],
                        (self.game_x - 12, self.game_y - 12,
                         self.game_width + 24, self.game_height + 24), 8)
        # 금색 외곽선
        pygame.draw.rect(surface, self.COLORS['gold_dark'],
                        (self.game_x - 10, self.game_y - 10,
                         self.game_width + 20, self.game_height + 20), 8)
        pygame.draw.rect(surface, self.COLORS['gold'],
                        (self.game_x - 8, self.game_y - 8,
                         self.game_width + 16, self.game_height + 16), 5)
        pygame.draw.rect(surface, self.COLORS['gold_light'],
                        (self.game_x - 6, self.game_y - 6,
                         self.game_width + 12, self.game_height + 12), 2)
        # 내부 석조 테두리
        pygame.draw.rect(surface, self.COLORS['stone_light'],
                        (self.game_x - 3, self.game_y - 3,
                         self.game_width + 6, self.game_height + 6), 3)

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
            idle_speed = person['idle_speed']
            idle_amount = person['idle_amount']
            has_hat = person['has_hat']
            hat_color = person['hat_color']
            head_tilt = person['head_tilt']

            # === 평소 움직임 (항상 적용) ===
            # 몸 좌우 흔들기
            idle_sway = math.sin(self.time * idle_speed + anim_offset) * idle_amount
            # 숨쉬기 (위아래 미세 움직임)
            idle_breathe = math.sin(self.time * idle_speed * 0.7 + anim_offset) * 0.5
            # 머리 살짝 움직임
            idle_head = math.sin(self.time * idle_speed * 0.5 + anim_offset + 1) * 0.8

            # 기본 위치 조정
            draw_x = x + idle_sway
            draw_y = y + idle_breathe

            # === 흥분 시 추가 움직임 ===
            bounce = 0
            arm_up = False

            if is_excited:
                bounce = int(5 * math.sin(self.time * 5 + anim_offset))
                arm_up = math.sin(self.time * 3 + anim_offset) > 0.2
                draw_y += bounce

            # 웨이브
            if self._wave_active:
                angle_diff = abs(person['angle'] - self._wave_angle)
                if angle_diff < 0.5 or angle_diff > math.pi * 2 - 0.5:
                    draw_y -= 12
                    arm_up = True

            # 관중 그리기
            self._draw_person(screen, draw_x, draw_y, size, body_color, skin_color,
                            hair_color, arm_up, has_hat, hat_color, head_tilt + idle_head * 0.1)

        # 횃불 그리기
        self._draw_torches(screen)

    def _draw_person(self, screen, x, y, size, body_color, skin_color, hair_color,
                    arm_up=False, has_hat=False, hat_color=None, head_tilt=0):
        """관중 한 명 그리기 (고퀄리티)"""
        x = int(x)
        y = int(y)

        head_radius = size // 4
        body_width = size // 2
        body_height = int(size * 0.55)

        # 몸통 그림자
        shadow_color = tuple(max(0, c - 40) for c in body_color)
        pygame.draw.ellipse(screen, shadow_color,
                           (x - body_width // 2 + 2, y + 2, body_width, body_height))

        # 몸통
        pygame.draw.ellipse(screen, body_color,
                           (x - body_width // 2, y, body_width, body_height))

        # 몸통 하이라이트
        highlight_color = tuple(min(255, c + 25) for c in body_color)
        pygame.draw.ellipse(screen, highlight_color,
                           (x - body_width // 4, y + 2, body_width // 3, body_height // 2))

        # 팔
        arm_width = size // 5
        arm_height = size // 3

        if arm_up:
            # 팔 위로 (응원)
            pygame.draw.ellipse(screen, body_color,
                               (x - body_width // 2 - arm_width + 3, y - arm_height // 2,
                                arm_width, arm_height))
            pygame.draw.ellipse(screen, body_color,
                               (x + body_width // 2 - 3, y - arm_height // 2,
                                arm_width, arm_height))
            # 손
            pygame.draw.circle(screen, skin_color,
                              (x - body_width // 2 - arm_width // 2 + 3, y - arm_height // 2),
                              arm_width // 2 + 1)
            pygame.draw.circle(screen, skin_color,
                              (x + body_width // 2 + arm_width // 2 - 3, y - arm_height // 2),
                              arm_width // 2 + 1)
        else:
            # 팔 옆으로 (평소)
            pygame.draw.ellipse(screen, body_color,
                               (x - body_width // 2 - arm_width + 4, y + 3,
                                arm_width, arm_height))
            pygame.draw.ellipse(screen, body_color,
                               (x + body_width // 2 - 4, y + 3,
                                arm_width, arm_height))

        # 머리 위치 (기울기 적용)
        head_x = x + int(head_tilt * 3)
        head_y = y - head_radius

        # 머리 그림자
        shadow_skin = tuple(max(0, c - 30) for c in skin_color)
        pygame.draw.circle(screen, shadow_skin, (head_x + 1, head_y + 1), head_radius)

        # 머리
        pygame.draw.circle(screen, skin_color, (head_x, head_y), head_radius)

        # 머리 하이라이트
        highlight_skin = tuple(min(255, c + 20) for c in skin_color)
        pygame.draw.circle(screen, highlight_skin, (head_x - 2, head_y - 2), head_radius // 3)

        # 머리카락
        hair_rect = (head_x - head_radius, head_y - head_radius, head_radius * 2, head_radius * 2)
        pygame.draw.arc(screen, hair_color, hair_rect, 0, math.pi, max(head_radius - 1, 2))

        # 모자 (있는 경우)
        if has_hat and hat_color:
            pygame.draw.ellipse(screen, hat_color,
                               (head_x - head_radius - 2, head_y - head_radius - 2,
                                head_radius * 2 + 4, head_radius))
            pygame.draw.rect(screen, hat_color,
                            (head_x - head_radius - 4, head_y - 2, head_radius * 2 + 8, 4))

        # 눈 (크기가 충분할 때만)
        if size >= 20:
            eye_y = head_y
            eye_spacing = head_radius // 2
            eye_size = max(1, head_radius // 4)
            # 눈
            pygame.draw.circle(screen, (40, 35, 30), (head_x - eye_spacing, eye_y), eye_size)
            pygame.draw.circle(screen, (40, 35, 30), (head_x + eye_spacing, eye_y), eye_size)

    def _draw_torches(self, screen):
        """횃불 그리기"""
        for torch in self.torches:
            tx, ty = torch['x'], torch['y']
            phase = torch['phase']

            # 화면 범위 체크
            if not (0 <= tx < self.screen_width and 0 <= ty < self.screen_height):
                continue

            # 횃불 받침대
            pygame.draw.rect(screen, self.COLORS['torch_holder'],
                            (tx - 4, ty, 8, 20))

            # 불꽃 크기 변화
            flame_size = 8 + int(3 * math.sin(self.time * 8 + phase))
            flame_height = 12 + int(4 * math.sin(self.time * 10 + phase))

            # 불꽃 글로우
            glow_surf = pygame.Surface((40, 40), pygame.SRCALPHA)
            for r in range(20, 0, -2):
                alpha = int(30 * (r / 20))
                pygame.draw.circle(glow_surf, (*self.COLORS['torch_glow'][:3], alpha),
                                  (20, 20), r)
            screen.blit(glow_surf, (tx - 20, ty - flame_height - 10), special_flags=pygame.BLEND_ADD)

            # 불꽃
            flame_points = [
                (tx, ty - flame_height),
                (tx - flame_size, ty - 2),
                (tx + flame_size, ty - 2),
            ]
            pygame.draw.polygon(screen, self.COLORS['torch_flame'], flame_points)

            # 불꽃 내부
            inner_points = [
                (tx, ty - flame_height + 4),
                (tx - flame_size // 2, ty - 4),
                (tx + flame_size // 2, ty - 4),
            ]
            pygame.draw.polygon(screen, self.COLORS['torch_glow'], inner_points)

    def draw_foreground(self, screen: pygame.Surface):
        """전경 효과"""
        # 비네팅 (더 부드럽게)
        vignette_size = 25
        for i in range(vignette_size):
            alpha = int(20 * (1 - i / vignette_size))
            surf = pygame.Surface((self.game_width, 1), pygame.SRCALPHA)
            surf.fill((0, 0, 0, alpha))
            screen.blit(surf, (self.game_x, self.game_y + i))
            screen.blit(surf, (self.game_x, self.game_y + self.game_height - i - 1))


# 호환성 별칭
ColosseumFrame = CircularStadiumFrame
