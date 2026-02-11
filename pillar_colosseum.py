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

        # 관중 서피스 캐시 (idle / arms_up 2종)
        self._crowd_cache = []
        self._prerender_crowd()

        # 횃불 데이터
        self.torches = []
        self._generate_torches()

        # 횃불 glow 서피스 캐시 (매 프레임 생성 방지)
        self._torch_glow_surface = pygame.Surface((40, 40), pygame.SRCALPHA)
        for r in range(20, 0, -2):
            alpha = int(30 * (r / 20))
            pygame.draw.circle(self._torch_glow_surface, (*self.COLORS['torch_glow'][:3], alpha),
                              (20, 20), r)

        # 캐시된 프레임 (석조 배경)
        self._frame_surface = None
        self._create_frame()

        # foreground 비네트 캐시
        self._vignette_surface = None
        self._prerender_vignette()

        # Wave 애니메이션
        self._wave_angle = 0.0
        self._wave_active = False

    def _generate_crowd(self):
        """관중 생성 (4~5줄만, 경기장 가까이에만 배치)"""
        random.seed(42)

        inner_radius = max(self.game_width, self.game_height) // 2 + 25

        person_size = 30  # 더 크게
        row_spacing = 28
        seat_spacing = 18  # 더 빽빽하게

        num_rows = 5  # 4~5줄만

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

    def _prerender_crowd(self):
        """관중 개별 서피스 프리렌더 (idle / arms_up 2종 캐시)"""
        self._crowd_cache = []
        for person in self.crowd_list:
            size = person['size']
            # 서피스 크기 (여유 포함)
            sw = size + 20
            sh = size + 20
            center_x = sw // 2
            center_y = sh // 2 + 4  # 약간 아래로 (머리 위 여유)

            idle_surf = pygame.Surface((sw, sh), pygame.SRCALPHA)
            self._draw_person_to_surface(idle_surf, center_x, center_y, person, arm_up=False)

            excited_surf = pygame.Surface((sw, sh), pygame.SRCALPHA)
            self._draw_person_to_surface(excited_surf, center_x, center_y, person, arm_up=True)

            self._crowd_cache.append({
                'idle': idle_surf,
                'excited': excited_surf,
                'offset_x': sw // 2,
                'offset_y': sh // 2 + 4,
            })

    def _draw_person_to_surface(self, surf, x, y, person, arm_up=False):
        """관중 1명을 서피스에 그리기 (프리렌더용)"""
        body_color = person['body_color']
        skin_color = person['skin_color']
        hair_color = person['hair_color']
        size = person['size']
        has_hat = person['has_hat']
        hat_color = person['hat_color']
        head_tilt = person['head_tilt']

        head_radius = int(size * 0.28)
        neck_width = int(size * 0.15)
        neck_height = int(size * 0.08)
        shoulder_width = int(size * 0.6)
        body_width = int(size * 0.45)
        body_height = int(size * 0.5)

        shadow_body = tuple(max(0, c - 45) for c in body_color)
        highlight_body = tuple(min(255, c + 30) for c in body_color)
        shadow_skin = tuple(max(0, c - 35) for c in skin_color)
        highlight_skin = tuple(min(255, c + 25) for c in skin_color)
        hair_dark = tuple(max(0, c - 20) for c in hair_color)

        # 몸통
        pygame.draw.ellipse(surf, shadow_body,
                           (x - shoulder_width // 2 + 2, y + 2, shoulder_width, body_height))
        pygame.draw.ellipse(surf, body_color,
                           (x - shoulder_width // 2, y, shoulder_width, body_height))
        pygame.draw.ellipse(surf, highlight_body,
                           (x - body_width // 4, y + 3, body_width // 2, body_height // 2))

        collar_color = tuple(min(255, c + 15) for c in body_color)
        pygame.draw.ellipse(surf, collar_color,
                           (x - neck_width - 2, y - 2, neck_width * 2 + 4, neck_height + 6))

        # 팔
        arm_width = int(size * 0.18)
        arm_height = int(size * 0.35)

        if arm_up:
            pygame.draw.ellipse(surf, shadow_body,
                               (x - shoulder_width // 2 - arm_width + 5, y - arm_height // 2 + 2,
                                arm_width, arm_height))
            pygame.draw.ellipse(surf, body_color,
                               (x - shoulder_width // 2 - arm_width + 4, y - arm_height // 2,
                                arm_width, arm_height))
            pygame.draw.ellipse(surf, body_color,
                               (x + shoulder_width // 2 - 4, y - arm_height // 2,
                                arm_width, arm_height))
            hand_size = arm_width // 2 + 2
            pygame.draw.circle(surf, skin_color,
                              (x - shoulder_width // 2 - arm_width // 2 + 4, y - arm_height // 2 - 2),
                              hand_size)
            pygame.draw.circle(surf, skin_color,
                              (x + shoulder_width // 2 + arm_width // 2 - 4, y - arm_height // 2 - 2),
                              hand_size)
        else:
            pygame.draw.ellipse(surf, shadow_body,
                               (x - shoulder_width // 2 - arm_width + 6, y + 4,
                                arm_width, arm_height))
            pygame.draw.ellipse(surf, body_color,
                               (x - shoulder_width // 2 - arm_width + 5, y + 2,
                                arm_width, arm_height))
            pygame.draw.ellipse(surf, body_color,
                               (x + shoulder_width // 2 - 5, y + 2,
                                arm_width, arm_height))

        # 목
        pygame.draw.rect(surf, shadow_skin,
                        (x - neck_width // 2 + 1, y - neck_height + 1, neck_width, neck_height + 4))
        pygame.draw.rect(surf, skin_color,
                        (x - neck_width // 2, y - neck_height, neck_width, neck_height + 4))

        # 머리
        head_x = x + int(head_tilt * 4)
        head_y = y - neck_height - head_radius + 2

        ear_size = head_radius // 3
        pygame.draw.ellipse(surf, shadow_skin,
                           (head_x - head_radius - ear_size // 2, head_y - ear_size // 2,
                            ear_size, ear_size * 2))
        pygame.draw.ellipse(surf, skin_color,
                           (head_x + head_radius - ear_size // 2, head_y - ear_size // 2,
                            ear_size, ear_size * 2))
        pygame.draw.circle(surf, shadow_skin, (head_x + 2, head_y + 2), head_radius)
        pygame.draw.circle(surf, skin_color, (head_x, head_y), head_radius)
        pygame.draw.circle(surf, highlight_skin, (head_x - head_radius // 3, head_y - head_radius // 4),
                          head_radius // 3)

        # 머리카락
        hair_rect = (head_x - head_radius - 1, head_y - head_radius - 2,
                    head_radius * 2 + 2, head_radius + head_radius // 2)
        pygame.draw.ellipse(surf, hair_color, hair_rect)
        pygame.draw.arc(surf, hair_dark,
                       (head_x - head_radius, head_y - head_radius, head_radius * 2, head_radius * 2),
                       0.3, math.pi - 0.3, 2)

        # 모자
        if has_hat and hat_color:
            hat_dark = tuple(max(0, c - 30) for c in hat_color)
            pygame.draw.ellipse(surf, hat_color,
                               (head_x - head_radius - 1, head_y - head_radius - 4,
                                head_radius * 2 + 2, head_radius))
            pygame.draw.ellipse(surf, hat_dark,
                               (head_x - head_radius - 5, head_y - 3,
                                head_radius * 2 + 10, 6))
            pygame.draw.ellipse(surf, hat_color,
                               (head_x - head_radius - 4, head_y - 4,
                                head_radius * 2 + 8, 5))

        # 얼굴 디테일
        if size >= 22:
            eye_y = head_y - 1
            eye_spacing = head_radius // 2
            eye_size = max(2, head_radius // 4)

            pygame.draw.ellipse(surf, (250, 250, 250),
                               (head_x - eye_spacing - eye_size, eye_y - eye_size // 2,
                                eye_size * 2, eye_size))
            pygame.draw.ellipse(surf, (250, 250, 250),
                               (head_x + eye_spacing - eye_size, eye_y - eye_size // 2,
                                eye_size * 2, eye_size))
            pygame.draw.circle(surf, (35, 30, 25),
                              (head_x - eye_spacing, eye_y), eye_size // 2 + 1)
            pygame.draw.circle(surf, (35, 30, 25),
                              (head_x + eye_spacing, eye_y), eye_size // 2 + 1)
            pygame.draw.circle(surf, (255, 255, 255),
                              (head_x - eye_spacing - 1, eye_y - 1), 1)
            pygame.draw.circle(surf, (255, 255, 255),
                              (head_x + eye_spacing - 1, eye_y - 1), 1)

            nose_y = head_y + head_radius // 4
            pygame.draw.line(surf, shadow_skin,
                           (head_x, eye_y + 2), (head_x, nose_y), 1)
            pygame.draw.circle(surf, shadow_skin, (head_x, nose_y), 2)

            mouth_y = head_y + head_radius // 2
            mouth_width = head_radius // 2
            pygame.draw.arc(surf, (150, 80, 80),
                           (head_x - mouth_width, mouth_y - 2, mouth_width * 2, 6),
                           0.2, math.pi - 0.2, 1)

    def _prerender_vignette(self):
        """foreground 비네트 프리렌더"""
        self._vignette_surface = pygame.Surface((self.game_width, self.game_height), pygame.SRCALPHA)
        vignette_size = 25
        for i in range(vignette_size):
            alpha = int(20 * (1 - i / vignette_size))
            # 상단
            pygame.draw.line(self._vignette_surface, (0, 0, 0, alpha),
                           (0, i), (self.game_width - 1, i))
            # 하단
            pygame.draw.line(self._vignette_surface, (0, 0, 0, alpha),
                           (0, self.game_height - i - 1), (self.game_width - 1, self.game_height - i - 1))

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

        # 배경 (어두운 석조)
        self._frame_surface.fill(self.COLORS['stone_dark'])

        # 외곽 스타디움 구조 (관중석 뒤)
        self._draw_stadium_backdrop(self._frame_surface)

        # 동심원 좌석 구조 (관중석 영역만)
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

        # 코너 석상 얼굴 (45도 회전, 필러 바깥쪽)
        self._draw_corner_statues(self._frame_surface)

    def _draw_stadium_backdrop(self, surface):
        """관중석 뒤 스타디움 배경 그리기 (고퀄리티)"""
        crowd_end_radius = max(self.game_width, self.game_height) // 2 + 25 + 5 * 28 + 20
        outer_radius = int(math.sqrt(self.screen_width**2 + self.screen_height**2)) + 50

        # === 1. 석조 벽면 층 (그라데이션 + 텍스처) ===
        tier_height = 35
        num_backdrop_tiers = (outer_radius - crowd_end_radius) // tier_height

        for i in range(num_backdrop_tiers):
            radius = crowd_end_radius + i * tier_height

            # 층마다 점점 어두워지는 색상
            darkness = min(0.5, i * 0.04)
            base_color = self.COLORS['stone_medium']
            color = tuple(int(c * (1 - darkness)) for c in base_color)
            color_light = tuple(min(255, int(c * (1.1 - darkness))) for c in base_color)
            color_dark = tuple(int(c * (0.85 - darkness)) for c in base_color)

            # 원형 층 (메인)
            pygame.draw.circle(surface, color, (self.center_x, self.center_y),
                             radius + tier_height, tier_height)

            # 층 상단 하이라이트
            pygame.draw.circle(surface, color_light,
                             (self.center_x, self.center_y), radius + tier_height - 3, 2)

            # 층 하단 그림자
            pygame.draw.circle(surface, color_dark,
                             (self.center_x, self.center_y), radius + 2, 3)

            # 벽돌 패턴 (일부 층에만)
            if i % 2 == 0:
                pygame.draw.circle(surface, self.COLORS['stone_shadow'],
                                 (self.center_x, self.center_y), radius + tier_height // 2, 1)

        # === 2. 대형 아치 구조 (고퀄리티) ===
        num_big_arches = 16
        for i in range(num_big_arches):
            angle = i * (2 * math.pi / num_big_arches)

            skip = False
            for aisle_angle in [math.pi * 0.5, math.pi * 1.17, math.pi * 1.83]:
                if abs(angle - aisle_angle) < 0.25:
                    skip = True
                    break
            if skip:
                continue

            # 여러 반경에 아치 배치
            for r in range(int(crowd_end_radius) + 25, int(outer_radius), 70):
                ax = self.center_x + int(r * math.cos(angle))
                ay = self.center_y + int(r * math.sin(angle))

                if 0 <= ax < self.screen_width and 0 <= ay < self.screen_height:
                    if not (self.game_x - 30 < ax < self.game_x + self.game_width + 30 and
                            self.game_y - 30 < ay < self.game_y + self.game_height + 30):
                        # 아치 크기 (거리에 따라)
                        arch_w = 28
                        arch_h = 40

                        # 아치 배경 (깊은 그림자)
                        pygame.draw.ellipse(surface, (50, 40, 30),
                                          (ax - arch_w//2 + 2, ay - arch_h//2 + 2, arch_w, arch_h))
                        pygame.draw.ellipse(surface, self.COLORS['stone_shadow'],
                                          (ax - arch_w//2, ay - arch_h//2, arch_w, arch_h))

                        # 아치 프레임 (두꺼운 테두리)
                        pygame.draw.ellipse(surface, self.COLORS['stone_dark'],
                                          (ax - arch_w//2 - 3, ay - arch_h//2 - 3, arch_w + 6, arch_h + 6), 4)
                        pygame.draw.ellipse(surface, self.COLORS['pillar'],
                                          (ax - arch_w//2 - 2, ay - arch_h//2 - 2, arch_w + 4, arch_h + 4), 2)

                        # 아치 상단 키스톤 (장식)
                        pygame.draw.polygon(surface, self.COLORS['gold_dark'],
                                          [(ax, ay - arch_h//2 - 8),
                                           (ax - 6, ay - arch_h//2),
                                           (ax + 6, ay - arch_h//2)])

                        # 아치 양쪽 기둥 장식
                        pygame.draw.rect(surface, self.COLORS['pillar_shadow'],
                                        (ax - arch_w//2 - 5, ay - 5, 4, 20))
                        pygame.draw.rect(surface, self.COLORS['pillar_shadow'],
                                        (ax + arch_w//2 + 1, ay - 5, 4, 20))

        # === 3. 장식 라인 및 코니스 ===
        for r in range(int(crowd_end_radius) + 40, int(outer_radius), 55):
            # 금색 장식 밴드
            pygame.draw.circle(surface, self.COLORS['gold_dark'],
                             (self.center_x, self.center_y), r, 3)
            pygame.draw.circle(surface, self.COLORS['gold'],
                             (self.center_x, self.center_y), r - 1, 1)

        # === 4. 조각상/방패 장식 (일부 위치에) ===
        num_decorations = 8
        deco_radius = crowd_end_radius + 100
        for i in range(num_decorations):
            angle = i * (2 * math.pi / num_decorations) + 0.2

            skip = False
            for aisle_angle in [math.pi * 0.5, math.pi * 1.17, math.pi * 1.83]:
                if abs(angle - aisle_angle) < 0.4:
                    skip = True
                    break
            if skip:
                continue

            dx = self.center_x + int(deco_radius * math.cos(angle))
            dy = self.center_y + int(deco_radius * math.sin(angle))

            if 0 <= dx < self.screen_width and 0 <= dy < self.screen_height:
                if not (self.game_x - 40 < dx < self.game_x + self.game_width + 40 and
                        self.game_y - 40 < dy < self.game_y + self.game_height + 40):
                    # 방패 장식
                    pygame.draw.ellipse(surface, self.COLORS['bronze'],
                                      (dx - 12, dy - 15, 24, 30))
                    pygame.draw.ellipse(surface, self.COLORS['gold'],
                                      (dx - 10, dy - 13, 20, 26), 2)
                    pygame.draw.ellipse(surface, self.COLORS['copper'],
                                      (dx - 6, dy - 8, 12, 16))

    def _draw_seat_tiers(self, surface):
        """동심원 좌석 단 그리기 (관중석 영역만, 5줄)"""
        inner_radius = max(self.game_width, self.game_height) // 2 + 20

        # 5줄만 좌석
        tier_height = 28
        num_tiers = 6  # 관중석 배경용

        for i in range(num_tiers):
            radius = inner_radius + i * tier_height

            # 좌석 단 색상
            if i % 2 == 0:
                color = self.COLORS['seat_light']
            else:
                color = self.COLORS['seat_medium']

            # 원형 좌석 단
            pygame.draw.circle(surface, color, (self.center_x, self.center_y),
                             radius + tier_height, tier_height)

            # 단 경계선 (3D 효과)
            pygame.draw.circle(surface, self.COLORS['seat_shadow'],
                             (self.center_x, self.center_y), radius, 2)
            pygame.draw.circle(surface, self.COLORS['stone_highlight'],
                             (self.center_x, self.center_y), radius + tier_height - 2, 1)

    def _draw_arches(self, surface):
        """아치 구조 그리기 (관중석 바로 뒤)"""
        # 관중석 끝나는 위치 바로 뒤
        arch_radius = max(self.game_width, self.game_height) // 2 + 25 + 5 * 28 + 10

        num_arches = 16
        arch_width = 35
        arch_height = 30

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

            x = self.center_x + int(arch_radius * math.cos(angle))
            y = self.center_y + int(arch_radius * math.sin(angle))

            if not (self.game_x - 20 < x < self.game_x + self.game_width + 20 and
                    self.game_y - 20 < y < self.game_y + self.game_height + 20):
                # 아치 배경
                pygame.draw.ellipse(surface, self.COLORS['stone_shadow'],
                                   (x - arch_width // 2, y - arch_height, arch_width, arch_height * 2))
                # 아치 테두리
                arch_rect = (x - arch_width // 2, y - arch_height, arch_width, arch_height * 2)
                pygame.draw.arc(surface, self.COLORS['pillar'], arch_rect, 0, math.pi, 5)
                pygame.draw.arc(surface, self.COLORS['pillar_light'], arch_rect, 0, math.pi, 2)
                # 아치 장식
                pygame.draw.arc(surface, self.COLORS['gold'], arch_rect, 0.2, math.pi - 0.2, 2)

    def _draw_pillars(self, surface):
        """기둥 구조 그리기 (관중석 뒤에만)"""
        # 관중석 끝나는 위치부터
        crowd_end_radius = max(self.game_width, self.game_height) // 2 + 25 + 5 * 28 + 25
        outer_radius = int(math.sqrt(self.screen_width**2 + self.screen_height**2))

        num_pillars = 12
        pillar_width = 22

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

            # 관중석 뒤부터 기둥 배치
            for r in range(int(crowd_end_radius), int(outer_radius), 70):
                px = self.center_x + int(r * math.cos(angle))
                py = self.center_y + int(r * math.sin(angle))

                if 0 <= px < self.screen_width and 0 <= py < self.screen_height:
                    if not (self.game_x < px < self.game_x + self.game_width and
                            self.game_y < py < self.game_y + self.game_height):
                        # 기둥 그림자
                        pygame.draw.rect(surface, self.COLORS['pillar_dark'],
                                        (px - pillar_width//2 + 3, py - 28, pillar_width, 60))
                        # 기둥 본체
                        pygame.draw.rect(surface, self.COLORS['pillar'],
                                        (px - pillar_width//2, py - 30, pillar_width - 2, 60),
                                        border_radius=3)
                        # 기둥 하이라이트
                        pygame.draw.rect(surface, self.COLORS['pillar_light'],
                                        (px - pillar_width//2 + 1, py - 30, 4, 60))
                        # 기둥 상단 장식 (코린트식)
                        pygame.draw.rect(surface, self.COLORS['gold'],
                                        (px - pillar_width//2 - 4, py - 35, pillar_width + 8, 6))
                        pygame.draw.rect(surface, self.COLORS['gold_light'],
                                        (px - pillar_width//2 - 4, py - 35, pillar_width + 8, 2))
                        # 기둥 하단 받침
                        pygame.draw.rect(surface, self.COLORS['stone_dark'],
                                        (px - pillar_width//2 - 3, py + 28, pillar_width + 6, 5))

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

    def _draw_corner_statues(self, surface):
        """4개 코너에 이집트 파라오 석상 얼굴 (45도 회전, 필러 바깥쪽 배치)"""
        # 석상 크기 (회전 전)
        face_size = 50

        # 게임 영역 4 코너 위치 + 회전 각도
        # 각 석상은 게임 영역 꼭지점에서 대각선 바깥으로 배치
        corners = [
            # (x, y, rotation_angle) - 머리가 바깥 대각선을 향함
            (self.game_x - 8, self.game_y - 8, 45),          # 좌상: 머리→좌상
            (self.game_x + self.game_width + 8, self.game_y - 8, -45),   # 우상: 머리→우상
            (self.game_x - 8, self.game_y + self.game_height + 8, 135),  # 좌하: 머리→좌하
            (self.game_x + self.game_width + 8, self.game_y + self.game_height + 8, -135),  # 우하: 머리→우하
        ]

        for cx, cy, angle in corners:
            face_surf = self._create_pharaoh_face(face_size)
            # 회전
            rotated = pygame.transform.rotate(face_surf, angle)
            # 회전 후 크기가 달라지므로 중심 맞추기
            rot_rect = rotated.get_rect(center=(cx, cy))
            surface.blit(rotated, rot_rect.topleft)

    def _create_pharaoh_face(self, size):
        """이집트 파라오 석상 얼굴 서피스 생성 (정면, 회전 전)"""
        surf = pygame.Surface((size, size), pygame.SRCALPHA)
        cx = size // 2
        cy = size // 2

        # 색상
        stone = (170, 155, 135)
        stone_light = (195, 180, 160)
        shadow = (120, 105, 85)
        dark = (90, 75, 60)
        gold = self.COLORS['gold']
        gold_light = self.COLORS['gold_light']
        gold_dark = self.COLORS['gold_dark']
        eye_glow = (210, 180, 80)

        s = size / 50.0  # 스케일 팩터

        # ── 네메스 두건 (전체 실루엣) ──
        # 두건 양쪽 날개 (아래로 늘어짐)
        nemes_pts = [
            (cx - int(18 * s), cy + int(20 * s)),     # 왼쪽 날개 끝
            (cx - int(16 * s), cy - int(5 * s)),      # 왼쪽 머리 옆
            (cx - int(10 * s), cy - int(18 * s)),     # 왼쪽 이마
            (cx, cy - int(22 * s)),                    # 정수리
            (cx + int(10 * s), cy - int(18 * s)),     # 오른쪽 이마
            (cx + int(16 * s), cy - int(5 * s)),      # 오른쪽 머리 옆
            (cx + int(18 * s), cy + int(20 * s)),     # 오른쪽 날개 끝
        ]
        pygame.draw.polygon(surf, shadow, nemes_pts)
        pygame.draw.polygon(surf, dark, nemes_pts, 1)

        # 두건 줄무늬 (가로선)
        for stripe_y in range(int(-15 * s), int(18 * s), int(4 * s)):
            y = cy + stripe_y
            # 줄무늬 범위 (두건 폴리곤 안)
            stripe_half_w = int((16 - abs(stripe_y / s) * 0.3) * s)
            if stripe_half_w > 2:
                pygame.draw.line(surf, dark,
                               (cx - stripe_half_w, y), (cx + stripe_half_w, y), 1)

        # ── 얼굴 (타원) ──
        face_w = int(22 * s)
        face_h = int(26 * s)
        face_rect = (cx - face_w // 2, cy - face_h // 2 - int(2 * s), face_w, face_h)
        pygame.draw.ellipse(surf, stone, face_rect)
        pygame.draw.ellipse(surf, shadow, face_rect, 1)

        # 얼굴 하이라이트 (왼쪽 볼)
        pygame.draw.ellipse(surf, stone_light,
                          (cx - face_w // 3, cy - face_h // 4, face_w // 3, face_h // 3))

        # ── 이마 밴드 (금색) ──
        band_y = cy - int(10 * s)
        band_h = int(4 * s)
        pygame.draw.rect(surf, gold,
                        (cx - int(12 * s), band_y, int(24 * s), band_h))
        pygame.draw.rect(surf, gold_dark,
                        (cx - int(12 * s), band_y, int(24 * s), band_h), 1)
        # 밴드 중앙 장식
        pygame.draw.rect(surf, gold_light,
                        (cx - int(3 * s), band_y, int(6 * s), band_h))

        # ── 우라에우스 (코브라) ──
        cobra_y = band_y - int(2 * s)
        # 코브라 몸
        pygame.draw.line(surf, gold, (cx, band_y), (cx, cobra_y - int(4 * s)), int(2 * s))
        # 코브라 머리 (부채꼴)
        cobra_head_y = cobra_y - int(5 * s)
        pygame.draw.circle(surf, gold_light, (cx, cobra_head_y), int(3 * s))
        pygame.draw.circle(surf, eye_glow, (cx - int(1 * s), cobra_head_y), int(1 * s))
        pygame.draw.circle(surf, eye_glow, (cx + int(1 * s), cobra_head_y), int(1 * s))

        # ── 눈 (이집트 아이라인 스타일) ──
        eye_y = cy - int(1 * s)
        eye_spacing = int(5 * s)
        eye_w = int(5 * s)
        eye_h = int(3 * s)

        for eye_x in [cx - eye_spacing, cx + eye_spacing]:
            # 눈 윤곽 (아몬드 형태)
            eye_pts = [
                (eye_x - eye_w // 2, eye_y),
                (eye_x, eye_y - eye_h // 2),
                (eye_x + eye_w // 2, eye_y),
                (eye_x, eye_y + eye_h // 2),
            ]
            pygame.draw.polygon(surf, (250, 245, 235), eye_pts)  # 흰자
            pygame.draw.polygon(surf, dark, eye_pts, 1)
            # 눈동자
            pygame.draw.circle(surf, dark, (eye_x, eye_y), max(1, int(1.5 * s)))
            # 금빛 하이라이트
            pygame.draw.circle(surf, eye_glow, (eye_x, eye_y), max(1, int(1 * s)))

            # 이집트 아이라인 꼬리 (바깥쪽으로)
            tail_dir = 1 if eye_x > cx else -1
            pygame.draw.line(surf, dark,
                           (eye_x + eye_w // 2 * tail_dir, eye_y),
                           (eye_x + int(eye_w * 0.8) * tail_dir, eye_y + int(2 * s)), 1)

        # ── 코 ──
        nose_y = cy + int(3 * s)
        pygame.draw.line(surf, shadow, (cx, eye_y + int(2 * s)), (cx, nose_y), 1)
        pygame.draw.line(surf, shadow, (cx - int(1.5 * s), nose_y), (cx + int(1.5 * s), nose_y), 1)

        # ── 입 ──
        mouth_y = cy + int(7 * s)
        pygame.draw.line(surf, dark, (cx - int(4 * s), mouth_y), (cx + int(4 * s), mouth_y), 1)
        # 입술 하이라이트
        pygame.draw.line(surf, shadow,
                        (cx - int(3 * s), mouth_y + 1), (cx + int(3 * s), mouth_y + 1), 1)

        # ── 턱선 강조 ──
        chin_y = cy + int(10 * s)
        pygame.draw.arc(surf, shadow,
                       (cx - int(8 * s), chin_y - int(4 * s), int(16 * s), int(8 * s)),
                       0.3, math.pi - 0.3, 1)

        # ── 받침대 (목 아래 석조) ──
        base_y = cy + int(16 * s)
        base_w = int(20 * s)
        base_h = int(6 * s)
        base_pts = [
            (cx - base_w // 2, base_y + base_h),
            (cx + base_w // 2, base_y + base_h),
            (cx + base_w // 2 - int(2 * s), base_y),
            (cx - base_w // 2 + int(2 * s), base_y),
        ]
        pygame.draw.polygon(surf, dark, base_pts)
        pygame.draw.polygon(surf, shadow, base_pts, 1)

        return surf

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

        # 관중 그리기 (캐시된 서피스 blit)
        is_excited = self.excitement_level > 0.3

        for i, person in enumerate(self.crowd_list):
            x, y = person['x'], person['y']
            anim_offset = person['anim_offset']
            idle_speed = person['idle_speed']
            idle_amount = person['idle_amount']

            # 평소 움직임
            idle_sway = math.sin(self.time * idle_speed + anim_offset) * idle_amount
            idle_breathe = math.sin(self.time * idle_speed * 0.7 + anim_offset) * 0.5

            draw_x = x + idle_sway
            draw_y = y + idle_breathe

            # 흥분 / 웨이브
            arm_up = False
            if is_excited:
                draw_y += int(5 * math.sin(self.time * 5 + anim_offset))
                arm_up = math.sin(self.time * 3 + anim_offset) > 0.2

            if self._wave_active:
                angle_diff = abs(person['angle'] - self._wave_angle)
                if angle_diff < 0.5 or angle_diff > math.pi * 2 - 0.5:
                    draw_y -= 12
                    arm_up = True

            # 캐시된 서피스 blit (1회 draw call)
            cache = self._crowd_cache[i]
            surf = cache['excited'] if arm_up else cache['idle']
            screen.blit(surf, (int(draw_x) - cache['offset_x'],
                               int(draw_y) - cache['offset_y']))

        # 횃불 그리기
        self._draw_torches(screen)

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

            # 불꽃 글로우 (캐시된 서피스 재사용)
            screen.blit(self._torch_glow_surface, (tx - 20, ty - flame_height - 10), special_flags=pygame.BLEND_ADD)

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
        """전경 효과 (캐시된 비네트 blit)"""
        if self._vignette_surface:
            screen.blit(self._vignette_surface, (self.game_x, self.game_y))


# 호환성 별칭
ColosseumFrame = CircularStadiumFrame
